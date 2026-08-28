"""The repo .bashrc, reached the ways bash reaches it: a plain script, an interactive shell."""

import os
import shutil

from conftest import REPO, Shell, path_without, require


def test_editor_vars_are_the_absolute_nvim_path(home):
    nvim = require("nvim")
    out = Shell(home).out('echo "$SUDO_EDITOR" "$EDITOR" "$VISUAL"')
    assert out.split() == [nvim] * 3
    assert nvim.startswith("/")


def test_editor_vars_stay_unset_without_nvim(home):
    sh = Shell(home, path=path_without("nvim"))
    assert sh.out('echo "${SUDO_EDITOR-unset} ${EDITOR-unset} ${VISUAL-unset}"') == "unset unset unset"


def test_helpers_do_not_leak(home):
    out = Shell(home).out('echo "${_nvim-unset}"; declare -F _path_add || echo no-function')
    assert out.split("\n") == ["unset", "no-function"]


def test_local_bin_leads_path(home):
    parts = Shell(home).out('echo "$PATH"').split(":")
    assert parts[0] == f"{home}/.local/bin"
    assert parts[-1] == f"{home}/go/bin"


def test_path_has_no_duplicates_when_sourced_twice(home):
    """A login shell reads .bashrc through .profile and again directly."""
    parts = Shell(home).out(f'source {REPO}/.bashrc\necho "$PATH"').split(":")
    assert len(parts) == len(set(parts)), parts


def test_home_bin_only_when_present(home):
    assert f"{home}/bin" not in Shell(home).out('echo "$PATH"').split(":")
    (home / "bin").mkdir()
    assert Shell(home).out('echo "$PATH"').split(":")[0] == f"{home}/bin"


def test_virtiofs_cache_is_off(home):
    assert Shell(home).out('echo "$DOCKER_SANDBOXES_ENABLE_VIRTIOFS_CACHE"') == "0"


def test_script_shell_stops_at_the_interactive_guard(home):
    out = Shell(home).out(
        'alias | wc -l; echo "${HISTCONTROL-unset}"; shopt -q histappend && echo on || echo off')
    assert out.split("\n") == ["0", "unset", "off"]


def test_noninteractive_local_reaches_scripts(home):
    (home / ".bashrc.noninteractive.local").write_text("export FROM_EVERY_SHELL=1\n")
    assert Shell(home).out('echo "${FROM_EVERY_SHELL-unset}"') == "1"


def test_interactive_local_is_interactive_only(home):
    (home / ".bashrc.local").write_text("export FROM_TERMINAL=1\n")
    sh = Shell(home)
    assert sh.out('echo "${FROM_TERMINAL-unset}"') == "unset"
    assert sh.out('echo "${FROM_TERMINAL-unset}"', mode="interactive") == "1"


def test_interactive_local_has_the_last_word(home):
    (home / ".bashrc.local").write_text("PS1='mine$ '\n")
    assert Shell(home).run('printf %s "$PS1"', mode="interactive").stdout == "mine$ "


def test_noninteractive_local_loses_ps1_to_the_repo(home):
    """The README warns about this ordering; the test pins it down."""
    (home / ".bashrc.noninteractive.local").write_text("PS1='mine$ '\n")
    assert Shell(home).out('printf %s "$PS1"', mode="interactive") != "mine$ "


def test_interactive_history_settings(home):
    out = Shell(home).out(
        'echo "$HISTCONTROL $HISTSIZE $HISTFILESIZE"; shopt -q histappend && echo on', mode="interactive")
    assert out.split("\n") == ["ignoreboth 10000 20000", "on"]


def test_prompt_is_colored_on_a_color_terminal(home):
    ps1 = Shell(home).out('printf %s "$PS1"', mode="interactive")
    assert r"\u@\h" in ps1 and r"\w" in ps1
    assert r"\033[01;32m" in ps1
    assert ps1.startswith(r"\[\e]0;"), "xterm title escape comes first"


def test_prompt_is_plain_on_a_dumb_terminal(home):
    ps1 = Shell(home).run('printf %s "$PS1"', mode="interactive", env={"TERM": "vt100"}).stdout
    assert ps1 == r"${debian_chroot:+($debian_chroot)}\u@\h:\w\$ "


def test_interactive_shell_loads_aliases(installed_home):
    assert Shell(installed_home).out("alias ll", mode="interactive") == "alias ll='ls -alF'"


def test_rustflags_follow_rustc(home, tmp_path):
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    rustc = fake_bin / "rustc"
    rustc.write_text("#!/bin/sh\n")
    rustc.chmod(0o755)
    with_rustc = Shell(home, path=f"{fake_bin}:{path_without('rustc')}")
    assert with_rustc.out('echo "$RUSTFLAGS"', mode="interactive") == "-D warnings"
    without = Shell(home, path=path_without("rustc"))
    assert without.out('echo "${RUSTFLAGS-unset}"', mode="interactive") == "unset"
