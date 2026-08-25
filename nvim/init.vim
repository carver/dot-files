" Neovim config, linked to ~/.config/nvim by install.sh.
"
" Not here because neovim already does them by default:
"   syntax on, filetype plugin indent on, set encoding=utf-8, set incsearch

set expandtab tabstop=2 shiftwidth=2 softtabstop=2
set background=dark

" Case-insensitive search, unless the pattern contains a capital letter
set ignorecase smartcase

inoremap jk <ESC>
vnoremap . :norm.<CR>

" Show the file path in the terminal title
set title

" Keep 7 lines visible around the cursor
set scrolloff=7

" Use the system clipboard for everything (needs xclip / wl-clipboard: see install.sh)
set clipboard=unnamed

" Auto-wrap at 100 characters ('t' is in neovim's default 'formatoptions')
set textwidth=100

" Highlight characters past column 100
highlight OverLength ctermbg=darkred ctermfg=white guibg=#592929

" Ignore rust build folders and compiled python in Ctrl-P, :find, etc.
set wildignore+=*/target/*,*.pyc

augroup vimrc
  autocmd!
  " :match is per-window, so re-apply it whenever a buffer shows up in a window
  autocmd BufWinEnter * match OverLength /\%101v.\+/
  " Remove trailing whitespace on save
  autocmd BufWritePre *.py :%s/\s\+$//e
  " Reload this config after every write, whether edited via ~/.config or the repo path
  let s:rc_paths = uniq(sort([$MYVIMRC, resolve($MYVIMRC)]))
  execute 'autocmd BufWritePost' join(map(s:rc_paths, 'fnameescape(v:val)'), ',') 'source $MYVIMRC'
augroup END

"Load vim-plug
let s:plug = stdpath('data') . '/site/autoload/plug.vim'
if empty(glob(s:plug))
    execute '!curl -fLo ' . s:plug . ' --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
endif

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

" Remap commands for when I hold the shift key too long
" comment out until remove existing command -- :command W w

" Syntastic
let g:syntastic_check_on_open = 1
let g:syntastic_python_checkers = ['flake8']
let g:syntastic_python_flake8_args = "--ignore=E501"

" The Silver Searcher
if executable('ag')
  " Use ag over grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'

  " ag is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0
endif
