:set expandtab tabstop=4 shiftwidth=4 softtabstop=4

syntax on
set background=dark
filetype indent plugin on
set encoding=utf-8

:set incsearch

inoremap jk <ESC>
vnoremap . :norm.<CR>

" Use tabs in golang source files
au BufNewFile,BufRead *.go setlocal noet ts=4 sw=4 sts=4

" Highlight golang syntax
set rtp+=$GOROOT/misc/vim

" Reload vim config after every file write
au BufWritePost ~/.vimrc :source ~/.vimrc
