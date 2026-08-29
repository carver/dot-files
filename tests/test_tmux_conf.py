"""The tmux config, read by a server on its own socket."""


def test_windows_and_panes_count_from_one(tmux):
    tmux.run("new-window")
    assert tmux.lines("list-windows", "-F", "#I") == ["1", "2"]
    assert tmux.lines("list-panes", "-F", "#P") == ["1"]


def test_copy_mode_and_the_command_prompt_use_vi_keys(tmux):
    assert tmux.out("show-window-options", "-gv", "mode-keys") == "vi"
    assert tmux.out("show-options", "-gv", "status-keys") == "vi"


def test_closing_a_window_closes_the_gap_in_the_numbering(tmux):
    tmux.run("new-window")
    tmux.run("new-window")
    tmux.run("kill-window", "-t", "2")
    assert tmux.lines("list-windows", "-F", "#I") == ["1", "2"]


def test_ctrl_pageup_and_pagedown_switch_tabs_without_the_prefix(tmux):
    # PPage and NPage are tmux's own names for PageUp and PageDown
    assert tmux.out("list-keys", "-T", "root", "C-PageUp").split() == \
        ["bind-key", "-T", "root", "C-PPage", "previous-window"]
    assert tmux.out("list-keys", "-T", "root", "C-PageDown").split() == \
        ["bind-key", "-T", "root", "C-NPage", "next-window"]


def test_a_new_tab_opens_in_the_current_directory(tmux):
    assert tmux.out("list-keys", "-T", "prefix", "c").split() == \
        ["bind-key", "-T", "prefix", "c", "new-window", "-c", '"#{pane_current_path}"']
