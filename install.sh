#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

DOTFILE_REPO="$( readlink -f $( dirname "$0"))"

ln -s $DOTFILE_REPO/.screenrc ~/.screenrc
ln -s $DOTFILE_REPO/.vimrc ~/.vimrc
ln -s $DOTFILE_REPO/.inputrc ~/.inputrc
mkdir -p ~/.vim
ln -s $DOTFILE_REPO/vimconfig/ftplugin ~/.vim/ftplugin
mkdir -p ~/.ssh
cat $DOTFILE_REPO/authorized_keys >>~/.ssh/authorized_keys
sudo apt-get update
sudo apt-get install -y python-pip-whl vim curl screen openssh-server
sudo pip install -r $DOTFILE_REPO/requirements.txt

