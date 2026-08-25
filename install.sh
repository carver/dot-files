#!/bin/bash
# Idempotent: safe to re-run after pulling changes.

set -o errexit
set -o pipefail
set -o nounset

DOTFILE_REPO="$( readlink -f "$( dirname "$0")")"

# link SRC DEST: create/refresh a symlink, but never clobber a real file or dir.
link() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "error: $dest exists and is not a symlink; move it aside first" >&2
    return 1
  fi
  ln -sfn "$src" "$dest"
}

link "$DOTFILE_REPO/.inputrc" ~/.inputrc
mkdir -p ~/.config
link "$DOTFILE_REPO/nvim" ~/.config/nvim

# Append only the keys that aren't already present.
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
while IFS= read -r key; do
  [ -n "$key" ] || continue
  grep -qxF -- "$key" ~/.ssh/authorized_keys || echo "$key" >>~/.ssh/authorized_keys
done <"$DOTFILE_REPO/authorized_keys"

sudo apt-get update
sudo apt-get install -y python3-pip-whl neovim curl openssh-server
# Install/refresh vim-plug plugins (render-markdown.nvim etc.) non-interactively
nvim --headless +PlugInstall +qall
sudo update-alternatives --set editor /usr/bin/nvim
