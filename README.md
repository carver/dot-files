# dot-files

My personal config, symlinked into `$HOME` by `./install.sh`.
Re-run it after pulling; it is idempotent.

| File | Linked to | Notes |
| --- | --- | --- |
| `.bashrc` | `~/.bashrc` | Portable: every toolchain block is guarded by an existence check. Sources two machine-specific files that are not in the repo: `~/.bashrc.noninteractive.local` before the interactive-only guard, `~/.bashrc.local` last. See below for which to use. |
| `.profile` | `~/.profile` | Makes a **login** shell read `~/.bashrc` (bash only reads it for interactive non-login shells otherwise). Sources `~/.profile.local` last. |
| `.bash_aliases` | `~/.bash_aliases` | Aliases and small functions (`..`, `mcd`, `n`, `serve`, `freq`, …). |
| `.inputrc` | `~/.inputrc` | Case-insensitive tab completion. |
| `nvim/` | `~/.config/nvim` | Neovim config, `init.vim` plus one `lua/carver/` module per feature, and plugins via vim-plug. |
| `authorized_keys` | appended to `~/.ssh/authorized_keys` | Only keys not already present. |

`make-ctags.sh` builds a `tags` file for a project, skipping the usual junk directories.

## Machine-specific bash settings

Two optional files, both untracked:

- `~/.bashrc.noninteractive.local` is sourced before the `case $- in *i*` guard, so it runs for
  **every** shell — `ssh host cmd`, scripts, anything an editor or agent spawns. **This is the
  default home for machine-specific settings**, and where `install.sh` puts a pre-existing
  `~/.bashrc`: the failure mode of a setting being missing from non-interactive shells is silent
  and confusing, while the cost of one extra file being read is a few milliseconds.
- `~/.bashrc.local` is sourced at the very end, and so only ever runs for interactive shells.
  Move things here once you know they're interactive-only and worth not paying for in scripts:
  the prompt, aliases, completions, slow toolchain init.

## First run on a machine

`install.sh` moves any real file it would replace to `<name>.bak`, except `~/.bashrc`, which it
moves to `~/.bashrc.noninteractive.local` so that every line in it keeps running for exactly the
shells it used to. Then trim it down to what the repo `.bashrc` doesn't already cover (often:
nothing), and move the interactive-only remainder to `~/.bashrc.local`.

One ordering caveat when you leave things in `~/.bashrc.noninteractive.local`: it is sourced
*before* the repo `.bashrc`'s own interactive settings, so if the file you migrated sets `PS1` or
an alias that the repo also sets, the repo now wins. Move those lines to `~/.bashrc.local` to get
the last word back.

`~/.profile` gets the same treatment — an existing one moves to `~/.profile.local`, sourced at the
end of the repo `.profile`. Put things there only if they are genuinely login-only; a login shell
reads `~/.profile` *and* (through it) `~/.bashrc`, so `~/.bashrc.noninteractive.local` is the wider
net. If `~/.bash_profile` or `~/.bash_login` exists, bash reads that **instead of** `~/.profile` and
the repo file never runs; `install.sh` warns when it sees one.

## Testing

```
pytest            # every feature, against throwaway homes and an isolated nvim
pytest --system   # also runs install.sh for real and checks what it left on the machine
```

The plain run never touches the machine's own config: `install.sh` runs with
`DOTFILES_SKIP_PACKAGES=1` against temp homes, and neovim runs with its own XDG tree, plugins
cached under `~/.cache/dotfiles-tests`. It needs `python3-pytest`, plus `nvim` and `flake8` for the
neovim tests and `universal-ctags` for the `make-ctags.sh` test; tests skip when a tool is missing
locally, and fail in CI where `install.sh` is supposed to have provided it.

`--system` adds the tests that run `install.sh` unmodified: nvim from the snap or the tarball,
`/etc/sudoers.d/10-editor` valid and pointing at it, apt neovim gone, and a second run that changes
nothing. CI runs those on an ubuntu-24.04 runner, where snapd works, and inside ubuntu 24.04 and
26.04 containers, where it doesn't, so both install paths get exercised on every push.

## Neovim

`install.sh` installs neovim from upstream's release build, since the apt package is too old for
render-markdown. With snapd that is the snap. Without it, the same tarball goes into `/opt/nvim`,
linked from `/usr/local/bin/nvim`, which is how docker sandboxes get it. Plugins are installed by `install.sh`
(`nvim --headless +PlugInstall +qall`); vim-plug itself is bootstrapped by `init.vim` on first launch.

- `ctrlp.vim` – fuzzy file finder, backed by `ag` or `rg` when available
- `nvim-lint` – runs `flake8 --ignore=E501` on python files on open and save, results shown as
  built-in diagnostics; `:Errors` lists them
- `render-markdown.nvim` – `<leader>m` toggles in-place rendering, `<leader>M` a side-by-side preview
- `vim-solidity` – syntax highlighting
- rust: `rust-analyzer` via the built-in LSP client, no plugin. `<C-]>`/`gd` definition, `K` hover,
  `grr`/`grn`/`gra` references/rename/code action (0.11+). Needs
  `rustup component add rust-analyzer rust-src` (install.sh does it when rustup exists).
