"""The tmux config, read by a server on its own socket."""

from conftest import REPO


def test_config_loads_without_errors(tmux):
    """A server started with -f keeps config errors for the first client to attach. Sourcing
    the file again from a client reports them, and exits 1, right there."""
    r = tmux.run("source-file", str(REPO / ".tmux.conf"), check=False)
    assert (r.returncode, r.stdout, r.stderr) == (0, "", "")


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


def test_escape_waits_ten_milliseconds(tmux):
    assert tmux.out("show-options", "-sv", "escape-time") == "10"


def test_true_color_and_the_tmux_terminfo(tmux):
    assert tmux.out("show-options", "-gv", "default-terminal") == "tmux-256color"
    assert "*:RGB" in tmux.lines("show-options", "-sv", "terminal-features")


def test_the_mouse_works(tmux):
    assert tmux.out("show-options", "-gv", "mouse") == "on"


def test_scrollback_keeps_fifty_thousand_lines(tmux):
    assert tmux.out("show-options", "-gv", "history-limit") == "50000"


def test_the_tabs_sit_at_the_top(tmux):
    assert tmux.out("show-options", "-gv", "status-position") == "top"


def test_minus_and_underscore_split_the_pane_in_the_current_directory(tmux):
    assert tmux.out("list-keys", "-T", "prefix", "-").split() == \
        ["bind-key", "-T", "prefix", "-", "split-window", "-h", "-c", "\"#{pane_current_path}\""]
    assert tmux.out("list-keys", "-T", "prefix", "_").split() == \
        ["bind-key", "-T", "prefix", "_", "split-window", "-v", "-c", "\"#{pane_current_path}\""]


def test_alt_n_jumps_to_tab_n(tmux):
    for n in range(1, 10):
        assert tmux.out("list-keys", "-T", "root", f"M-{n}").split() == \
            ["bind-key", "-T", "root", f"M-{n}", "select-window", "-t", str(n)]


def test_ctrl_t_is_the_prefix_and_ctrl_b_is_not(tmux):
    """The .screenrc that came before used Ctrl-t. Ctrl-t twice sends a Ctrl-t through, as
    tmux does for its default Ctrl-b."""
    assert tmux.out("show-options", "-gv", "prefix") == "C-t"
    assert tmux.out("list-keys", "-T", "prefix", "C-t").split() == \
        ["bind-key", "-T", "prefix", "C-t", "send-prefix"]
    assert tmux.run("list-keys", "-T", "prefix", "C-b", check=False).returncode == 1
