"""install.sh for real: packages, the editor, sudoers. Only with --system, and meant for
CI or a machine you are happy to have provisioned. Everything here is idempotent."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

from conftest import REPO, snapshot

pytestmark = pytest.mark.system

HOME = Path.home()
MANAGED = [".bashrc", ".bash_aliases", ".inputrc", ".profile", ".config/nvim", ".ssh/authorized_keys"]


def run_install():
    return subprocess.run([str(REPO / "install.sh")], cwd=REPO, capture_output=True, text=True)


def sudo(*args):
    return subprocess.run(["sudo", *args], capture_output=True, text=True)


def test_install_provisions_the_machine():
    r = run_install()
    assert r.returncode == 0, r.stdout + r.stderr
    nvim = shutil.which("nvim")
    assert nvim in ("/snap/bin/nvim", "/usr/local/bin/nvim"), nvim
    if nvim == "/usr/local/bin/nvim":
        assert Path(nvim).resolve() == Path("/opt/nvim/bin/nvim")
    assert subprocess.run(["dpkg", "-s", "neovim"], capture_output=True).returncode != 0, "apt neovim still installed"
    assert subprocess.run(["nvim", "--version"], capture_output=True).returncode == 0
    for tool in ("flake8", "curl", "xclip", "wl-copy"):
        assert shutil.which(tool), tool


def sudo_is_sudo_rs():
    return "sudo-rs" in subprocess.run(["sudo", "--version"], capture_output=True, text=True).stdout


def test_sudo_knows_the_editor():
    nvim = shutil.which("nvim")
    content = sudo("cat", "/etc/sudoers.d/10-editor")
    assert content.returncode == 0, content.stderr
    # sudo-rs has no sudoedit_follow, so only the editor line lands there
    expected = [f"Defaults editor={nvim}"]
    if not sudo_is_sudo_rs():
        expected.insert(0, "Defaults sudoedit_follow")
    assert content.stdout.splitlines() == expected
    assert sudo("visudo", "-cqf", "/etc/sudoers.d/10-editor").returncode == 0
    mode = oct(Path("/etc/sudoers.d/10-editor").stat().st_mode & 0o777) if os.access("/etc/sudoers.d/10-editor", os.R_OK) else None
    assert mode in (None, "0o440")
    if not sudo_is_sudo_rs():  # sudo-rs lists commands only, no Defaults
        listing = sudo("-l").stdout
        assert "sudoedit_follow" in listing and f"editor={nvim}" in listing


def test_root_completion_ignores_case():
    assert sudo("cat", "/root/.inputrc").stdout == (REPO / ".inputrc").read_text()
    r = sudo("-H", "bash", "--norc", "-i", "-c", "bind -v")
    assert "set completion-ignore-case on" in r.stdout.splitlines()


def test_real_config_loads_with_plugins():
    r = subprocess.run(["nvim", "--headless", "+qa"], capture_output=True, text=True)
    assert r.returncode == 0 and r.stderr == "", r.stderr
    plugged = subprocess.run(
        ["nvim", "--headless", "+lua io.stdout:write(vim.fn.stdpath('data'))", "+qa"],
        capture_output=True, text=True).stdout
    assert {p.name for p in (Path(plugged) / "plugged").iterdir()} >= {
        "ctrlp.vim", "nvim-lint", "render-markdown.nvim", "vim-solidity"}


def test_second_run_is_quiet_and_changes_nothing():
    run_install()
    before = {m: snapshot(HOME / m) if (HOME / m).is_dir() else os.readlink(HOME / m) if (HOME / m).is_symlink()
              else (HOME / m).read_bytes() for m in MANAGED}
    opt_mtime = Path("/opt/nvim").stat().st_mtime if Path("/opt/nvim").exists() else None
    r = run_install()
    assert r.returncode == 0, r.stdout + r.stderr
    own_lines = ("installed neovim", "installed /etc/sudoers.d", "installed /root/.inputrc",
                 "moved existing", "removed stale link")
    assert not any(w in r.stdout for w in own_lines), r.stdout
    after = {m: snapshot(HOME / m) if (HOME / m).is_dir() else os.readlink(HOME / m) if (HOME / m).is_symlink()
             else (HOME / m).read_bytes() for m in MANAGED}
    assert after == before
    if opt_mtime is not None:
        assert Path("/opt/nvim").stat().st_mtime == opt_mtime, "tarball was re-downloaded"
