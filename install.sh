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
# A machine's existing .bashrc is kept as ~/.bashrc.noninteractive.local rather
# than backed up into oblivion. The repo .bashrc sources that before its
# interactive-only guard, so every line in it keeps running for every shell,
# exactly as it did when it was ~/.bashrc -- the safe default if nobody acts on
# the notice below. An untouched Ubuntu default has nothing worth keeping.
if [ -f ~/.bashrc ] && [ ! -L ~/.bashrc ]; then
  if [ -f /etc/skel/.bashrc ] && cmp -s ~/.bashrc /etc/skel/.bashrc; then
    rm ~/.bashrc
  elif [ -e ~/.bashrc.noninteractive.local ]; then
    echo "error: ~/.bashrc is not managed yet and ~/.bashrc.noninteractive.local already exists;" >&2
    echo "  merge them by hand" >&2
    exit 1
  else
    mv ~/.bashrc ~/.bashrc.noninteractive.local
    echo "moved existing ~/.bashrc to ~/.bashrc.noninteractive.local, which the repo .bashrc"
    echo "  sources for every shell, interactive or not -- nothing stops running. To make"
    echo "  non-interactive shells cheaper, delete from it whatever the repo .bashrc now"
    echo "  covers (often: all of it) and move the interactive-only rest -- prompt, aliases,"
    echo "  completions, slow toolchain init -- to ~/.bashrc.local, which is sourced last."
  fi
fi
link "$DOTFILE_REPO/.bashrc" ~/.bashrc
link "$DOTFILE_REPO/.bash_aliases" ~/.bash_aliases
link "$DOTFILE_REPO/.inputrc" ~/.inputrc

# ~/.profile is what makes a *login* shell read ~/.bashrc at all -- without it an
# `ssh host`, a console login or a desktop session gets none of the above. Same
# migration rule as .bashrc: whatever was there keeps loading, from a .local file.
if [ -f ~/.profile ] && [ ! -L ~/.profile ]; then
  if [ -f /etc/skel/.profile ] && cmp -s ~/.profile /etc/skel/.profile; then
    rm ~/.profile
  elif [ -e ~/.profile.local ]; then
    echo "error: ~/.profile is not managed yet and ~/.profile.local already exists; merge them by hand" >&2
    exit 1
  else
    mv ~/.profile ~/.profile.local
    echo "moved existing ~/.profile to ~/.profile.local (sourced at the end of the repo .profile)"
  fi
fi
link "$DOTFILE_REPO/.profile" ~/.profile

# bash reads either of these *instead of* ~/.profile, so one lying around silently
# shadows the link just made.
for shadowing in ~/.bash_profile ~/.bash_login; do
  if [ -e "$shadowing" ]; then
    echo "warning: $shadowing exists; bash reads it instead of ~/.profile, so the repo" >&2
    echo "  .profile will not run. Merge it into ~/.profile.local and delete it." >&2
  fi
done

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
sudo apt-get install -y python3-pip-whl curl openssh-server flake8 xclip wl-clipboard
sudo snap install nvim --classic
# Install/refresh vim-plug plugins non-interactively
nvim --headless +'PlugInstall --sync' +qall
# rust-analyzer for neovim's rust LSP. rustup is per-user, so there's no apt package;
# skip quietly on machines without rust.
if command -v rustup >/dev/null 2>&1; then
  rustup component add rust-analyzer rust-src || echo "warning: could not install rust-analyzer" >&2
fi
# nano outranks nvim in the alternatives priorities, so pick nvim explicitly
sudo update-alternatives --set editor /usr/bin/nvim
