#!/bin/bash

DOTFILE_REPO="$( readlink -f $( dirname "$0"))"

ln -s $DOTFILE_REPO/.screenrc ~/.screenrc
ln -s $DOTFILE_REPO/.vimrc ~/.vimrc
ln -s $DOTFILE_REPO/.inputrc ~/.inputrc
mkdir ~/.vim
ln -s $DOTFILE_REPO/vimconfig/ftplugin ~/.vim/ftplugin
sudo apt-get update
sudo apt-get install -y python-pip vim curl
sudo pip install -r $DOTFILE_REPO/requirements.txt

