#!/bin/bash
# Idempotent: safe to re-run after pulling changes. Also run inside sbx sandboxes
# by sandbox-setup/setup.py, so it must cope with a home directory it didn't set up.

set -o errexit
set -o pipefail
set -o nounset

DOTFILE_REPO="$( readlink -f "$( dirname "$0")")"

# link SRC DEST: create/refresh a symlink. A real file already at DEST is moved
# to DEST.bak first (never overwriting an earlier backup).
link() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if [ -e "$dest.bak" ]; then
      echo "error: $dest is not a symlink and $dest.bak already exists; sort them out by hand" >&2
      return 1
    fi
    mv "$dest" "$dest.bak"
    echo "moved existing $dest to $dest.bak"
  fi
  ln -sfn "$src" "$dest"
}

# unlink_stale DEST: remove a symlink left behind by an older version of this
# script, i.e. one that is dangling or that points into this repo.
unlink_stale() {
  local dest="$1"
  [ -L "$dest" ] || return 0
  local target
  target="$(readlink -f "$dest" || true)"
  if [ ! -e "$dest" ] || [[ "$target" == "$DOTFILE_REPO"/* ]]; then
    rm "$dest"
    echo "removed stale link $dest"
  fi
}

# ---- bash ------------------------------------------------------------------
# The repo .bashrc sources ~/.bashrc.local last, so a machine's existing
# .bashrc is kept there instead of being backed up into oblivion. An untouched
# Ubuntu default has nothing worth keeping.
if [ -f ~/.bashrc ] && [ ! -L ~/.bashrc ]; then
  if [ -f /etc/skel/.bashrc ] && cmp -s ~/.bashrc /etc/skel/.bashrc; then
    rm ~/.bashrc
  elif [ -e ~/.bashrc.local ]; then
    echo "error: ~/.bashrc is not managed yet and ~/.bashrc.local already exists; merge them by hand" >&2
    exit 1
  else
    mv ~/.bashrc ~/.bashrc.local
    echo "moved existing ~/.bashrc to ~/.bashrc.local (sourced at the end of the repo .bashrc);"
    echo "  delete from it whatever the repo .bashrc now covers"
  fi
fi
link "$DOTFILE_REPO/.bashrc" ~/.bashrc
link "$DOTFILE_REPO/.bash_aliases" ~/.bash_aliases
link "$DOTFILE_REPO/.inputrc" ~/.inputrc

# ---- neovim ----------------------------------------------------------------
mkdir -p ~/.config
link "$DOTFILE_REPO/nvim" ~/.config/nvim

# Leftovers from when this repo managed vim and screen (commit 7e9e29d and earlier).
unlink_stale ~/.vimrc
unlink_stale ~/.vim/ftplugin
unlink_stale ~/.screenrc
if [ -e ~/.vim ] || [ -e ~/.viminfo ]; then
  echo "note: vim is no longer managed here; its old plugins and state can go:  rm -rf ~/.vim ~/.viminfo"
fi

# ---- ssh -------------------------------------------------------------------
# Append only the keys that aren't already present.
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
while IFS= read -r key; do
  [ -n "$key" ] || continue
  grep -qxF -- "$key" ~/.ssh/authorized_keys || echo "$key" >>~/.ssh/authorized_keys
done <"$DOTFILE_REPO/authorized_keys"

# ---- packages --------------------------------------------------------------
# flake8: linter run by nvim-lint.  xclip + wl-clipboard: clipboard providers
# for neovim's 'clipboard' option on X11 and Wayland respectively.
sudo apt-get update
sudo apt-get install -y python3-pip-whl neovim curl openssh-server flake8 xclip wl-clipboard
# Install/refresh vim-plug plugins non-interactively
nvim --headless +'PlugInstall --sync' +qall
# nano outranks nvim in the alternatives priorities, so pick nvim explicitly
sudo update-alternatives --set editor /usr/bin/nvim
