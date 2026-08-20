" Neovim entrypoint: reuse the shared ~/.vimrc (and ~/.vim plugins via vim-plug).
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
