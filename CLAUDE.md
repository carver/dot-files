# dot-files

Personal config, symlinked into `$HOME` by `install.sh`. README.md covers what each file does.

## Every change is test-driven

Load `/tdd` before touching anything. The loop is red then green: a failing test in `tests/`
first, then the smallest change to the repo file that makes it pass, one slice at a time. A
change without a red test first is not finished, whichever file it lands in.

The seams are agreed. Test at these and nowhere deeper:

- **Shell startup**: what a shell sees after the repo files run. Environment variables, PATH,
  aliases, functions, PS1, in the three modes `Shell` in `tests/conftest.py` runs: script,
  interactive, login.
- **install.sh**: what it leaves behind in a throwaway HOME (`install()`, `snapshot()`), and
  under `--system` what it leaves on the machine: nvim, sudoers, `/root`.
- **neovim**: options, maps, autocmd groups, filetypes, diagnostics, as `Nvim.lua()` reports them
  from an isolated XDG tree. The lua modules are tested through nvim, never imported directly.

A change that needs a new seam is a conversation first, not a test.

One test file per repo file, named after it. Expected values are literals from the spec or a
worked example, never recomputed the way the code does it.

## Two runs

- `pytest`: the fast suite. Runs before every commit.
- `pytest --system`: also runs `install.sh` for real and provisions the machine it runs on. Required
  for any change at or below the `DOTFILES_SKIP_PACKAGES` gate in `install.sh`. Fine in a
  sandbox, where `sandbox-setup` already runs `install.sh`.

CI runs `--system` on a snapd runner and in ubuntu 24.04 and 26.04 containers, so both nvim
install branches are covered on every push.

## Writing

Comments, commit messages and README text go through `/unslop`. Commits are small and isolated:
one behaviour per commit, tests in the same commit as the change they drive.
