"""~/.profile: the login-shell entry point, and POSIX sh compatible."""

import subprocess

from conftest import REPO, Shell, clean_env, require


def test_login_shell_reaches_bashrc(installed_home):
    nvim = require("nvim")
    assert Shell(installed_home).out('echo "$EDITOR"', mode="login") == nvim


def test_login_shell_path_has_no_duplicates(installed_home):
    parts = Shell(installed_home).out('echo "$PATH"', mode="login").split(":")
    assert len(parts) == len(set(parts)), parts


def test_profile_local_runs_last(installed_home):
    require("nvim")
    (installed_home / ".profile.local").write_text('export SEEN_EDITOR="$EDITOR"\n')
    out = Shell(installed_home).out('echo "$SEEN_EDITOR"', mode="login")
    assert out.endswith("/nvim"), "profile.local ran before .bashrc had set EDITOR"


def test_profile_is_posix_sh(installed_home):
    dash = require("dash")
    (installed_home / ".profile.local").write_text("export FROM_PROFILE_LOCAL=1\n")
    r = subprocess.run(
        [dash, "-c", f'. {REPO}/.profile; echo "${{EDITOR-unset}} ${{FROM_PROFILE_LOCAL-unset}}"'],
        env=clean_env(installed_home), capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert r.stderr == ""
    # dash is not bash, so .bashrc is skipped, but the .local file still runs
    assert r.stdout.strip() == "unset 1"
