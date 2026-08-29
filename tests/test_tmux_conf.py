"""The tmux config, read by a server on its own socket."""


def test_windows_and_panes_count_from_one(tmux):
    tmux.run("new-window")
    assert tmux.lines("list-windows", "-F", "#I") == ["1", "2"]
    assert tmux.lines("list-panes", "-F", "#P") == ["1"]
