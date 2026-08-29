# dot-files

My personal config, symlinked into `$HOME` by `./install.sh`. Re-run it after pulling; it is
idempotent.

| File | Linked to | Notes |
| --- | --- | --- |
| `.bashrc` | `~/.bashrc` | Portable. Every toolchain block checks that the tool exists first. Sources two machine-specific files that stay out of the repo, `~/.bashrc.noninteractive.local` before the interactive-only guard and `~/.bashrc.local` last. See below for which to use. |
| `.profile` | `~/.profile` | Makes a login shell read `~/.bashrc`. Bash only does that on its own for interactive non-login shells. Sources `~/.profile.local` last. |
| `.bash_aliases` | `~/.bash_aliases` | Aliases and small functions such as `..`, `mcd`, `n`, `serve` and `freq`. |
| `.inputrc` | `~/.inputrc`, and a copy at `/root/.inputrc` | Case-insensitive tab completion, in root's shells too. |
| `nvim/` | `~/.config/nvim` | Neovim config. `init.vim` plus one `lua/carver/` module per feature, plugins via vim-plug. |
| `.tmux.conf` | `~/.tmux.conf` | tmux config. `install.sh` installs tmux itself. |
| `authorized_keys` | appended to `~/.ssh/authorized_keys` | Only the keys not already there. |

## tmux

Windows are the tabs, along the top of the screen, numbered from 1 so that window N sits under key N, and renumbered when
one closes so there is never a gap. Panes count from 1 too.
A new tab (`prefix c`) starts in the current tab's directory. So does a split: `prefix -` puts
the new pane beside this one, `prefix _` below it. `prefix %` and `prefix "` still work.
`Ctrl-PageUp` and `Ctrl-PageDown` move between tabs with no prefix, the same keys GNOME
Terminal uses for its own tabs.
Copy mode (`prefix [`) and the command prompt (`prefix :`) use vi keys.
Scrollback keeps 50000 lines per pane.
The mouse works: click a tab, wheel to scroll back, drag a pane border.
True color reaches nvim through `TERM=tmux-256color` and `terminal-features` `*:RGB`.
Esc inside nvim is not delayed; `escape-time` is 10ms (tmux 3.4 defaults to half a second).

`make-ctags.sh` builds a `tags` file for a project and skips the usual junk directories.

## Machine-specific bash settings

Two optional files, both untracked:

- `~/.bashrc.noninteractive.local` runs before the `case $- in *i*` guard, so every shell reads
  it, including `ssh host cmd`, scripts, and anything an editor or agent spawns. This is the
  default home for machine-specific settings, and where `install.sh` puts a pre-existing
  `~/.bashrc`. A setting missing from non-interactive shells fails silently and confusingly; one
  extra file costs a few milliseconds.
- `~/.bashrc.local` runs at the very end, so only interactive shells read it. Move things here
  once you know they are interactive-only and worth keeping out of scripts. The prompt, aliases,
  completions and slow toolchain init all belong here.

## First run on a machine

`install.sh` moves any real file it would replace to `<name>.bak`. The exception is `~/.bashrc`,
which moves to `~/.bashrc.noninteractive.local` so that every line in it keeps running for exactly
the shells it used to. Then trim it down to what the repo `.bashrc` does not already cover, often
nothing, and move the interactive-only remainder to `~/.bashrc.local`.

One ordering caveat when you leave things in `~/.bashrc.noninteractive.local`. It runs before the
repo `.bashrc`'s own interactive settings, so if the migrated file sets a `PS1` or an alias that
the repo also sets, the repo wins. Move those lines to `~/.bashrc.local` to get the last word back.

`~/.profile` gets the same treatment. An existing one moves to `~/.profile.local`, which the repo
`.profile` sources at its end. Put things there only if they really are login-only. A login shell
reads `~/.profile` and, through it, `~/.bashrc`, so `~/.bashrc.noninteractive.local` is the wider
net. If `~/.bash_profile` or `~/.bash_login` exists, bash reads that instead of `~/.profile` and
the repo file never runs; `install.sh` warns when it sees one.

## Neovim

`install.sh` installs neovim from upstream's release build, because the apt package is too old
for render-markdown. With snapd that means the snap. Without it, as in docker sandboxes, the same
tarball goes into `/opt/nvim` with a link from `/usr/local/bin/nvim`. `install.sh` also writes
`/etc/sudoers.d/10-editor`, so `visudo` and `sudo crontab -e` open nvim even though sudo drops
`EDITOR`; `sudo -e` reads `SUDO_EDITOR` from your own environment and needs no help. The file
also sets `sudoedit_follow`, except under sudo-rs, the default sudo since Ubuntu 25.10, which
does not know that setting. The clipboard providers are `xclip`, always, and `wl-clipboard`
only where a Wayland socket exists under `XDG_RUNTIME_DIR`. nvim reaches for `wl-copy` whenever
`WAYLAND_DISPLAY` is set, and a docker sandbox inherits that variable from the host with nothing
behind it, so on such a machine `install.sh` removes `wl-clipboard` again and every yank stops
failing with a clipboard error. Plugins are
installed by `install.sh` with `nvim --headless +PlugInstall +qall`; `init.vim` bootstraps
vim-plug itself on first launch.

- Line numbers show the absolute number on the current line and the distance on every other
  line, so the count for a `j`, `k`, `d` or `y` reads straight off the gutter.
- Undo history persists on disk, so `u` still works after closing and reopening a file.
- Space is the leader key, so `<leader>m` below means Space then `m`.
- `Ctrl-A` in normal mode selects the whole file. Increment a number with `Ctrl-A` in visual
  mode instead.
- `Ctrl-C` in normal or visual mode saves the file. In insert mode it still leaves insert mode.
- `p` over a selection replaces it without the replaced text taking over the clipboard, so
  the same text pastes again.
- `ctrlp.vim`, fuzzy file finder, backed by `rg`, which `install.sh` installs, or `ag` when present
- `nvim-lint` runs `flake8 --ignore=E501` on python files on open and save. Results show as
  built-in diagnostics; `:Errors` lists them.
- `render-markdown.nvim`, `<leader>m` toggles in-place rendering, `<leader>M` opens a side-by-side
  preview
- `vim-solidity` for syntax highlighting
- rust: `rust-analyzer` through the built-in LSP client, no plugin. `<C-]>` or `gd` for
  definition, `K` for hover, and on 0.11+ `grr`, `grn` and `gra` for references, rename and code
  action. Needs `rustup component add rust-analyzer rust-src`; `install.sh` runs that when rustup
  exists.
- `sudo -e` temp files such as `/var/tmp/sshd_config.XXXXXXXX` get the filetype of the name under
  the random suffix.

## Testing

```
pytest            # every feature, against throwaway homes and an isolated nvim
pytest --system   # also runs install.sh for real and checks what it left on the machine
```

The plain run leaves the machine's own config alone. `install.sh` runs with
`DOTFILES_SKIP_PACKAGES=1` against temp homes, neovim runs in its own XDG tree with plugins
cached under `~/.cache/dotfiles-tests`, and tmux starts a server on its own socket. It needs `python3-pytest`, plus `nvim` and `flake8` for
the neovim tests, `tmux` for the tmux tests and `universal-ctags` for the `make-ctags.sh` test. A missing tool skips its
tests locally and fails them in CI, where `install.sh` should have provided it.

`--system` adds the tests that run `install.sh` unmodified and check the result. nvim comes from
the snap or the tarball, `/etc/sudoers.d/10-editor` is valid and points at it, apt neovim is gone,
and a second run changes nothing. CI runs those on an ubuntu-24.04 runner, where snapd works, and
inside ubuntu 24.04 and 26.04 containers, where it does not, so every push exercises both install
paths.

Every change here starts with a failing test. CLAUDE.md lists the seams.
