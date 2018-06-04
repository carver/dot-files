:set expandtab tabstop=2 shiftwidth=2 softtabstop=2

syntax on
set background=dark
filetype indent plugin on
set encoding=utf-8

:set incsearch
:set smartcase

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

" Highlight characters past 100
highlight OverLength ctermbg=darkred ctermfg=white guibg=#592929
match OverLength /\%101v.\+/

" Load vim-plug plugins
call plug#begin()

Plug 'tomlion/vim-solidity'
Plug 'vim-syntastic/syntastic'
Plug 'ctrlpvim/ctrlp.vim'

call plug#end()

" Shows document path and title in the terminal title
set title

" Remap commands for when I hold the shift key too long
" comment out until remove existing command -- :command W w

" Syntastic
let g:syntastic_check_on_open = 1
let g:syntastic_python_checkers = ['flake8']
let g:syntastic_python_flake8_args = "--ignore=E501"

" Remove trailing whitespace on save
autocmd BufWritePre *.py :%s/\s\+$//e

" The Silver Searcher
if executable('ag')
  " Use ag over grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'

  " ag is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0
endif

" Use system clipboard for everything
set clipboard=unnamed " Default to system clipboard.

" Set 7 line buffer around cursor
set so=7

" Auto-wrap text at 100 characters
setlocal formatoptions+=t textwidth=100
