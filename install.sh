#!/bin/bash

DOTFILE_REPO="$( readlink -f $( dirname "$0"))"

ln -s $DOTFILE_REPO/.screenrc ~/.screenrc
ln -s $DOTFILE_REPO/.vimrc ~/.vimrc
ln -s $DOTFILE_REPO/.inputrc ~/.inputrc

