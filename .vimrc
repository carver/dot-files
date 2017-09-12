:set expandtab tabstop=2 shiftwidth=2 softtabstop=2

syntax on
set background=dark
filetype indent plugin on
set encoding=utf-8

:set incsearch

inoremap jk <ESC>
vnoremap . :norm.<CR>

"Load vim-plug
if empty(glob("~/.vim/autoload/plug.vim"))
    execute '!curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.github.com/junegunn/vim-plug/master/plug.vim'
endif

" Use tabs in golang source files
au BufNewFile,BufRead *.go setlocal noet ts=4 sw=4 sts=4

" Highlight golang syntax
set rtp+=$GOROOT/misc/vim

" Switch tabs to 2 spaces for html/javascript
au BufNewFile,BufRead *.{html,js,jsx} setlocal sw=2 sts=2 et

" Reload vim config after every file write
au BufWritePost ~/.vimrc :source ~/.vimrc

" Load vim-plug plugins
call plug#begin()

Plug 'tomlion/vim-solidity'

call plug#end()
