# dot-files

My personal config, symlinked into `$HOME` by `./install.sh`.
Re-run it after pulling; it is idempotent.

| File | Linked to | Notes |
| --- | --- | --- |
| `.bashrc` | `~/.bashrc` | Portable: every toolchain block is guarded by an existence check. Sources `~/.bashrc.local` last for machine-specific bits. |
| `.bash_aliases` | `~/.bash_aliases` | Aliases and small functions (`..`, `mcd`, `n`, `serve`, `freq`, …). |
| `.inputrc` | `~/.inputrc` | Case-insensitive tab completion. |
| `nvim/` | `~/.config/nvim` | Neovim config (`init.vim`) and plugins via vim-plug. |
| `authorized_keys` | appended to `~/.ssh/authorized_keys` | Only keys not already present. |

`make-ctags.sh` builds a `tags` file for a project, skipping the usual junk directories.

## First run on a machine

`install.sh` moves any real file it would replace to `<name>.bak`, except `~/.bashrc`, which it
moves to `~/.bashrc.local` so that whatever was in it keeps loading. Trim `~/.bashrc.local` down
to what the repo `.bashrc` doesn't already cover (often: nothing).

## Neovim

Plugins are installed by `install.sh` (`nvim --headless +PlugInstall +qall`); vim-plug itself is
bootstrapped by `init.vim` on first launch.

- `ctrlp.vim` – fuzzy file finder, backed by `ag` or `rg` when available
- `nvim-lint` – runs `flake8 --ignore=E501` on python files on open and save, results shown as
  built-in diagnostics; `:Errors` lists them
- `render-markdown.nvim` – `<leader>m` toggles in-place rendering, `<leader>M` a side-by-side preview
- `vim-solidity` – syntax highlighting
- rust: `rust-analyzer` via the built-in LSP client, no plugin. `<C-]>`/`gd` definition, `K` hover,
  `grr`/`grn`/`gra` references/rename/code action (0.11+). Needs
  `rustup component add rust-analyzer rust-src` (install.sh does it when rustup exists).
