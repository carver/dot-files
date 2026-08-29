"""Fixtures and helpers shared by every test.

Each test drives a real bash or a real nvim against the files in this repo, inside a
throwaway HOME or XDG tree, so the machine's own config is never read or written. The
exceptions are marked `system` and only run with --system.
"""

import atexit
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
IN_CI = os.environ.get("CI") == "true"

# Lines bash prints on stderr when it is told to be interactive without a terminal.
INTERACTIVE_NOISE = ("cannot set terminal process group", "no job control in this shell")


def pytest_addoption(parser):
    parser.addoption("--system", action="store_true",
                     help="also run the tests that execute install.sh for real")


def pytest_configure(config):
    config.addinivalue_line(
        "markers", "system: runs install.sh against the real machine; needs sudo and network")


def pytest_collection_modifyitems(config, items):
    if config.getoption("--system"):
        return
    skip = pytest.mark.skip(reason="pass --system to run")
    for item in items:
        if "system" in item.keywords:
            item.add_marker(skip)


def require(tool):
    """Return the path of a tool the test needs. On a dev box without it the test is
    skipped. In CI install.sh is supposed to have provided it, so there it is a failure."""
    path = shutil.which(tool)
    if path:
        return path
    if IN_CI:
        pytest.fail(f"{tool} is missing, and CI ran install.sh")
    pytest.skip(f"{tool} is not installed")


def path_without(*tools):
    """PATH with the named tools hidden. A directory that holds one is swapped for a shim
    directory of symlinks to everything else in it, so its other tools stay available and
    launchers that find helpers through PATH, like /snap/bin/nvim, keep working."""
    shims = Path(tempfile.mkdtemp(prefix="path-without-"))
    atexit.register(shutil.rmtree, shims, ignore_errors=True)
    parts = []
    for i, d in enumerate(os.environ["PATH"].split(":")):
        directory = Path(d)
        if not d or not any((directory / t).exists() for t in tools):
            parts.append(d)
            continue
        shim = shims / str(i)
        shim.mkdir()
        for entry in directory.iterdir():
            if entry.name not in tools:
                (shim / entry.name).symlink_to(entry)
        parts.append(str(shim))
    return ":".join(parts)


def clean_env(home, path=None):
    return {
        "HOME": str(home),
        "PATH": path or os.environ["PATH"],
        "TERM": "xterm-256color",
        "LANG": "C.UTF-8",
    }


def stderr_without_noise(text):
    return "\n".join(l for l in text.splitlines() if not any(n in l for n in INTERACTIVE_NOISE))


class Shell:
    """Run a script in bash the three ways bash reaches its startup files.

    script:      non-interactive, the repo .bashrc sourced first (`ssh host cmd`, cron)
    interactive: bash -i with the repo .bashrc as the rc file (a terminal)
    login:       bash --login, which reads ~/.profile, so HOME must be installed first
    """

    def __init__(self, home, path=None):
        self.home = Path(home)
        self.path = path

    def run(self, script, *, mode="script", rc=REPO / ".bashrc", env=None, check=True):
        e = clean_env(self.home, self.path)
        e.update(env or {})
        if mode == "script":
            prelude = f"source {rc}\n" if rc else ""
            cmd = ["bash", "--norc", "-c", prelude + script]
        elif mode == "interactive":
            cmd = ["bash", "--rcfile", str(rc), "-i", "-c", script] if rc \
                else ["bash", "--norc", "-i", "-c", script]
        elif mode == "login":
            cmd = ["bash", "--login", "-c", script]
        else:
            raise ValueError(mode)
        r = subprocess.run(cmd, env=e, cwd=self.home, capture_output=True, text=True)
        r.stderr = stderr_without_noise(r.stderr)
        if check and r.returncode != 0:
            raise AssertionError(f"bash exited {r.returncode}\nstdout:\n{r.stdout}\nstderr:\n{r.stderr}")
        return r

    def out(self, script, **kw):
        return self.run(script, **kw).stdout.strip()


def install(home, path=None, **env):
    """Run install.sh against `home` with the package section skipped."""
    e = clean_env(home, path)
    e["DOTFILES_SKIP_PACKAGES"] = "1"
    e.update(env)
    return subprocess.run([str(REPO / "install.sh")], env=e, cwd=home,
                          capture_output=True, text=True)


def snapshot(root):
    """Every path under root with what it is, so two runs can be compared exactly."""
    result = {}
    for p in sorted(Path(root).rglob("*")):
        rel = str(p.relative_to(root))
        if p.is_symlink():
            result[rel] = ("link", os.readlink(p))
        elif p.is_dir():
            result[rel] = ("dir",)
        else:
            result[rel] = ("file", p.read_bytes())
    return result


@pytest.fixture
def home(tmp_path):
    h = tmp_path / "home"
    h.mkdir()
    return h


@pytest.fixture
def installed_home(home):
    """A HOME that install.sh has already linked, so ~/.bashrc and friends exist."""
    r = install(home)
    assert r.returncode == 0, r.stdout + r.stderr
    return home


def cache_dir():
    base = os.environ.get("DOTFILES_TEST_CACHE") or os.environ.get("XDG_CACHE_HOME") \
        or Path.home() / ".cache"
    d = Path(base) / "dotfiles-tests"
    d.mkdir(parents=True, exist_ok=True)
    return d


class Nvim:
    """nvim --headless with the repo config in an isolated XDG tree."""

    def __init__(self, env):
        self.env = env
        self.config = Path(env["XDG_CONFIG_HOME"]) / "nvim"

    def with_env(self, **over):
        return Nvim({**self.env, **over})

    def run(self, *args, check=True, timeout=120):
        r = subprocess.run(["nvim", "--headless", *args], env=self.env,
                           capture_output=True, text=True, timeout=timeout)
        if check and r.returncode != 0:
            raise AssertionError(f"nvim exited {r.returncode}\nstdout:\n{r.stdout}\nstderr:\n{r.stderr}")
        return r

    def lua(self, expr, *, file=None, before=(), after=()):
        """The value of a lua expression, JSON-decoded, evaluated after startup and after
        `file` has been loaded. `before` are --cmd strings run before the config, `after`
        are +cmd strings run just before the expression."""
        args = []
        for c in before:
            args += ["--cmd", c]
        for c in after:
            args.append("+" + c)
        args.append("+lua io.stdout:write(vim.json.encode((function() return " + expr + " end)()))")
        args.append("+qa!")
        if file:
            args.append(str(file))
        r = self.run(*args)
        try:
            return json.loads(r.stdout)
        except json.JSONDecodeError:
            raise AssertionError(f"no JSON from nvim\nstdout:\n{r.stdout}\nstderr:\n{r.stderr}")


class Tmux:
    """A tmux server on its own socket, started from the repo .tmux.conf, so the machine's
    own config and sessions are never touched."""

    def __init__(self, socket_name, cwd):
        self.socket = socket_name
        self.cwd = cwd

    def run(self, *args, check=True):
        env = clean_env(self.cwd)
        r = subprocess.run(["tmux", "-L", self.socket, *args], env=env, cwd=self.cwd,
                           capture_output=True, text=True)
        if check and r.returncode != 0:
            raise AssertionError(f"tmux exited {r.returncode}\nstdout:\n{r.stdout}\nstderr:\n{r.stderr}")
        return r

    def out(self, *args):
        return self.run(*args).stdout.strip()

    def lines(self, *args):
        return self.out(*args).splitlines()


@pytest.fixture
def tmux(tmp_path):
    """A detached session in a fresh server that has read only the repo .tmux.conf."""
    require("tmux")
    t = Tmux(f"dotfiles-test-{os.getpid()}-{tmp_path.name}", tmp_path)
    t.run("-f", str(REPO / ".tmux.conf"), "new-session", "-d", "-s", "main", "-x", "80", "-y", "24")
    try:
        yield t
    finally:
        t.run("kill-server", check=False)


@pytest.fixture(scope="session")
def nvim(tmp_path_factory):
    """One isolated nvim for the whole session. The config is a copy of the repo's nvim/
    directory, so a test may write init.vim; plugins go to a cache dir that survives runs."""
    require("nvim")
    root = tmp_path_factory.mktemp("nvim")
    config = root / "config"
    config.mkdir()
    shutil.copytree(REPO / "nvim", config / "nvim", symlinks=True)
    home = root / "home"
    home.mkdir()
    env = clean_env(home)
    env.update({
        "XDG_CONFIG_HOME": str(config),
        "XDG_DATA_HOME": str(cache_dir() / "nvim-data"),
        "XDG_STATE_HOME": str(root / "state"),
    })
    # rustup's rust-analyzer is a proxy that looks under $HOME for the toolchain, and
    # HOME is scratch here. Point it at the real install when there is one.
    for var, default in (("RUSTUP_HOME", Path.home() / ".rustup"), ("CARGO_HOME", Path.home() / ".cargo")):
        value = os.environ.get(var, str(default))
        if Path(value).exists():
            env[var] = value
    n = Nvim(env)
    n.run("+PlugInstall --sync", "+qa")
    return n
