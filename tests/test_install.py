"""install.sh's link and migration logic, run against throwaway homes with packages skipped."""

import os
from pathlib import Path

import pytest

from conftest import REPO, install, snapshot

LINKS = {
    ".bashrc": REPO / ".bashrc",
    ".bash_aliases": REPO / ".bash_aliases",
    ".inputrc": REPO / ".inputrc",
    ".profile": REPO / ".profile",
    ".config/nvim": REPO / "nvim",
    ".tmux.conf": REPO / ".tmux.conf",
}
REPO_KEY = (REPO / "authorized_keys").read_text().strip()


def ok(home, **env):
    r = install(home, **env)
    assert r.returncode == 0, r.stdout + r.stderr
    return r


def test_fresh_home_gets_every_link(home):
    r = ok(home)
    for name, target in LINKS.items():
        p = home / name
        assert p.is_symlink() and Path(os.readlink(p)) == target, name
    assert "skipping packages" in r.stdout


def test_second_run_changes_nothing_and_says_nothing(home):
    ok(home)
    before = snapshot(home)
    r = ok(home)
    assert snapshot(home) == before
    assert not any(w in r.stdout + r.stderr for w in ("moved", "removed", "installed", "warning", "error"))


def test_real_file_is_moved_to_bak(home):
    (home / ".inputrc").write_text("set editing-mode vi\n")
    r = ok(home)
    assert (home / ".inputrc").is_symlink()
    assert (home / ".inputrc.bak").read_text() == "set editing-mode vi\n"
    assert "moved existing" in r.stdout


def test_existing_bak_stops_the_script(home):
    (home / ".inputrc").write_text("one\n")
    (home / ".inputrc.bak").write_text("two\n")
    r = install(home)
    assert r.returncode != 0
    assert "sort them out by hand" in r.stderr
    assert (home / ".inputrc").read_text() == "one\n"
    assert (home / ".inputrc.bak").read_text() == "two\n"


def test_foreign_symlink_is_replaced_without_backup(home):
    (home / ".inputrc").symlink_to("/etc/inputrc")
    ok(home)
    assert Path(os.readlink(home / ".inputrc")) == REPO / ".inputrc"
    assert not (home / ".inputrc.bak").exists()


def test_untouched_ubuntu_bashrc_is_dropped(home):
    skel = Path("/etc/skel/.bashrc")
    if not skel.exists():
        pytest.skip("no /etc/skel/.bashrc here")
    (home / ".bashrc").write_bytes(skel.read_bytes())
    ok(home)
    assert (home / ".bashrc").is_symlink()
    assert not (home / ".bashrc.noninteractive.local").exists()
    assert not (home / ".bashrc.bak").exists()


def test_custom_bashrc_keeps_running_for_every_shell(home):
    (home / ".bashrc").write_text("export MINE=1\n")
    r = ok(home)
    assert (home / ".bashrc").is_symlink()
    assert (home / ".bashrc.noninteractive.local").read_text() == "export MINE=1\n"
    assert "moved existing ~/.bashrc to ~/.bashrc.noninteractive.local" in r.stdout


def test_bashrc_and_local_both_present_is_an_error(home):
    (home / ".bashrc").write_text("a\n")
    (home / ".bashrc.noninteractive.local").write_text("b\n")
    r = install(home)
    assert r.returncode == 1
    assert "merge them by hand" in r.stderr
    assert not (home / ".bashrc").is_symlink()


def test_untouched_ubuntu_profile_is_dropped(home):
    skel = Path("/etc/skel/.profile")
    if not skel.exists():
        pytest.skip("no /etc/skel/.profile here")
    (home / ".profile").write_bytes(skel.read_bytes())
    ok(home)
    assert (home / ".profile").is_symlink()
    assert not (home / ".profile.local").exists()


def test_custom_profile_moves_to_profile_local(home):
    (home / ".profile").write_text("export MINE=1\n")
    r = ok(home)
    assert (home / ".profile").is_symlink()
    assert (home / ".profile.local").read_text() == "export MINE=1\n"
    assert "moved existing ~/.profile to ~/.profile.local" in r.stdout


def test_profile_and_local_both_present_is_an_error(home):
    (home / ".profile").write_text("a\n")
    (home / ".profile.local").write_text("b\n")
    r = install(home)
    assert r.returncode == 1
    assert "merge them by hand" in r.stderr


@pytest.mark.parametrize("shadow", [".bash_profile", ".bash_login"])
def test_shadowing_login_file_gets_a_warning(home, shadow):
    (home / shadow).write_text("\n")
    r = ok(home)
    assert f"warning: {home}/{shadow} exists" in r.stderr
    assert (home / ".profile").is_symlink()


def test_dangling_vimrc_link_is_removed(home):
    (home / ".vimrc").symlink_to(home / "gone")
    r = ok(home)
    assert not (home / ".vimrc").is_symlink()
    assert "removed stale link" in r.stdout


def test_vimrc_link_into_the_repo_is_removed(home):
    (home / ".vimrc").symlink_to(REPO / "README.md")
    ok(home)
    assert not (home / ".vimrc").exists()


def test_foreign_vimrc_is_left_alone(home):
    (home / ".vimrc").write_text("set nocompatible\n")
    other = home / "elsewhere"
    other.write_text("x\n")
    (home / ".screenrc").symlink_to(other)
    r = ok(home)
    assert (home / ".vimrc").read_text() == "set nocompatible\n"
    assert (home / ".screenrc").is_symlink()
    assert "removed" not in r.stdout


def test_leftover_vim_state_gets_a_note(home):
    (home / ".viminfo").write_text("\n")
    r = ok(home)
    assert "rm -rf ~/.vim ~/.viminfo" in r.stdout


def test_authorized_key_is_added_once(home):
    ok(home)
    keys = (home / ".ssh" / "authorized_keys").read_text().splitlines()
    assert keys.count(REPO_KEY) == 1
    ok(home)
    assert (home / ".ssh" / "authorized_keys").read_text().splitlines().count(REPO_KEY) == 1


def test_existing_keys_are_kept(home):
    (home / ".ssh").mkdir()
    (home / ".ssh" / "authorized_keys").write_text("ssh-ed25519 AAAAexisting other@host\n")
    ok(home)
    keys = (home / ".ssh" / "authorized_keys").read_text().splitlines()
    assert keys == ["ssh-ed25519 AAAAexisting other@host", REPO_KEY]
