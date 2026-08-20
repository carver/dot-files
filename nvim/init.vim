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
let s:plug = stdpath('data') . '/site/autoload/plug.vim'
if empty(glob(s:plug))
    execute '!curl -fLo ' . s:plug . ' --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
endif

" Use tabs in golang source files
au BufNewFile,BufRead *.go setlocal noet ts=4 sw=4 sts=4

" Highlight golang syntax
set rtp+=$GOROOT/misc/vim

" Switch tabs to 2 spaces for html/javascript
au BufNewFile,BufRead *.{html,js,jsx} setlocal sw=2 sts=2 et

" Reload config after every file write
au BufWritePost $MYVIMRC :source $MYVIMRC

" Highlight characters past 100
highlight OverLength ctermbg=darkred ctermfg=white guibg=#592929
match OverLength /\%101v.\+/

" Load vim-plug plugins
call plug#begin()

Plug 'tomlion/vim-solidity'
Plug 'vim-syntastic/syntastic'
Plug 'ctrlpvim/ctrlp.vim'
" In-buffer markdown rendering (uses neovim's built-in treesitter parsers)
Plug 'MeanderingProgrammer/render-markdown.nvim'

call plug#end()

" render-markdown.nvim
"   :RenderMarkdown toggle   - rendered view in-place (raw on cursor line / insert mode)
"   :RenderMarkdown preview  - side-by-side: raw on left, rendered on right
"   <leader>m / <leader>M    - shortcuts for the above
lua << LUA
  local ok, rm = pcall(require, 'render-markdown')
  if ok then
    rm.setup({
      -- render in normal/command modes; show raw text while in insert mode
      render_modes = { 'n', 'c', 't' },
      -- plain markers so it still looks fine without a Nerd Font installed
      heading = { icons = { '# ', '## ', '### ', '#### ', '##### ', '###### ' } },
      checkbox = { unchecked = { icon = '[ ]' }, checked = { icon = '[x]' } },
      code = { language_icon = false },
    })
  end
LUA
nnoremap <leader>m :RenderMarkdown toggle<CR>
nnoremap <leader>M :RenderMarkdown preview<CR>

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

" Ignore rust build folders in Ctrl-P
set wildignore+=*/target/*

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
