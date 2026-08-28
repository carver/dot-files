"""readline settings from .inputrc."""

from conftest import REPO, Shell


def test_completion_ignores_case(home):
    out = Shell(home).out("bind -v", mode="interactive", rc=None, env={"INPUTRC": str(REPO / ".inputrc")})
    assert "set completion-ignore-case on" in out.split("\n")
