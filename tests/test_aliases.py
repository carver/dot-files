"""Aliases and functions from .bash_aliases, in the interactive shell that loads them."""

import os

from conftest import Shell, path_without, require


def test_dotdot_climbs_the_given_number_of_levels(installed_home):
    deep = installed_home / "a" / "b" / "c"
    deep.mkdir(parents=True)
    out = Shell(installed_home).out(f"cd {deep}\n.. 2\npwd\ncd - >/dev/null\npwd", mode="interactive")
    assert out.split("\n") == [str(installed_home / "a"), str(deep)]


def test_dotdot_defaults_to_one_level(installed_home):
    deep = installed_home / "a" / "b"
    deep.mkdir(parents=True)
    assert Shell(installed_home).out(f"cd {deep}\n..\npwd", mode="interactive") == str(installed_home / "a")


def test_mcd_creates_and_enters(installed_home):
    target = installed_home / "new" / "dir"
    assert Shell(installed_home).out(f"mcd {target}\npwd", mode="interactive") == str(target)
    assert target.is_dir()


def test_nvim_aliases_present_with_nvim(installed_home):
    require("nvim")
    out = Shell(installed_home).out("alias n vi vim", mode="interactive")
    assert out.split("\n") == ["alias n='nvim'", "alias vi='nvim'", "alias vim='nvim'"]


def test_nvim_aliases_absent_without_nvim(installed_home):
    sh = Shell(installed_home, path=path_without("nvim"))
    r = sh.run("alias n vi vim", mode="interactive", check=False)
    assert r.returncode != 0
    assert r.stdout == ""


def test_alert_names_the_command_and_its_status(installed_home, tmp_path):
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    notify = fake_bin / "notify-send"
    notify.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\necho --\n')
    notify.chmod(0o755)
    sh = Shell(installed_home, path=f"{fake_bin}:{os.environ['PATH']}")
    out = sh.out(
        'history -s "sleep 10; alert"\ntrue\nalert\n'
        'history -s "make; alert"\nfalse\nalert\n', mode="interactive")
    assert out.split("\n") == [
        "--urgency=normal", "-i", "terminal", "sleep 10", "--",
        "--urgency=normal", "-i", "error", "make", "--",
    ]


def test_everyday_aliases_exist(installed_home):
    out = Shell(installed_home).out("alias serve freq ll la l gl gsh", mode="interactive")
    names = [line.split("=")[0] for line in out.split("\n")]
    assert names == ["alias serve", "alias freq", "alias ll", "alias la", "alias l", "alias gl", "alias gsh"]


def test_ls_and_grep_get_color(installed_home):
    if not os.access("/usr/bin/dircolors", os.X_OK):
        return
    out = Shell(installed_home).out("alias ls grep", mode="interactive")
    assert out.split("\n") == ["alias ls='ls --color=auto'", "alias grep='grep --color=auto'"]
