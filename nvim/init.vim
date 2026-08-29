" Neovim config, linked to ~/.config/nvim by install.sh.
"
" Not here because neovim already does them by default:
"   syntax on, filetype plugin indent on, set encoding=utf-8, set incsearch

set expandtab tabstop=2 shiftwidth=2 softtabstop=2
set background=dark

" Case-insensitive search, unless the pattern contains a capital letter
set ignorecase smartcase

" Line numbers: the absolute number on the current line, distances on the rest, so a
" count for j, k, d or y can be read straight off the gutter
set number relativenumber

" Keep undo history on disk (under stdpath('state')), so u still works after reopening a file
set undofile

" Space is the leader; every <leader> map below is Space plus a key. Set before any of them.
let mapleader = " "

inoremap jk <ESC>
vnoremap . :norm.<CR>

" Ctrl-A selects the whole file, as everywhere outside vim. The number increment it replaces
" is still there as Ctrl-X's opposite in visual mode.
nnoremap <C-a> ggVG

" Ctrl-C saves, outside insert mode. From visual mode leave the selection first: a plain :w
" there is :'<,'>w, which writes the selected lines alone.
nnoremap <C-c> :w<CR>
xnoremap <C-c> <Esc>:w<CR>

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

" ---------------------------------------------------------------------------
" Plugins (vim-plug). install.sh runs :PlugInstall; plug.vim itself is
" bootstrapped here on first launch.
" ---------------------------------------------------------------------------
let s:plug = stdpath('data') . '/site/autoload/plug.vim'
if empty(glob(s:plug))
  execute '!curl -fLo ' . shellescape(s:plug)
        \ . ' --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  " neovim cached the runtimepath before site/autoload existed, so load it by hand this once
  execute 'source' fnameescape(s:plug)
endif

call plug#begin()

" Solidity syntax (nothing built in for it)
Plug 'tomlion/vim-solidity'
" Fuzzy file finder
Plug 'ctrlpvim/ctrlp.vim'
" Runs external linters (flake8) into neovim's built-in diagnostics; replaces syntastic
Plug 'mfussenegger/nvim-lint'
" In-buffer markdown rendering (uses neovim's built-in treesitter parsers)
Plug 'MeanderingProgrammer/render-markdown.nvim'

call plug#end()

" ---- ctrlp / grep -----------------------------------------------------------
if executable('ag')
  " The Silver Searcher: fast, respects .gitignore, so ctrlp needs no cache
  set grepprg=ag\ --nogroup\ --nocolor
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'
  let g:ctrlp_use_caching = 0
elseif executable('rg')
  set grepprg=rg\ --vimgrep
  let g:ctrlp_user_command = 'rg %s --files --color=never'
  let g:ctrlp_use_caching = 0
endif

" ---- diagnostics (fed by both nvim-lint and the LSP client) -----------------
" show the message next to the offending line, not just a gutter sign
lua vim.diagnostic.config({ virtual_text = true })

" ---- nvim-lint: flake8 on open and on save ----------------------------------
"   :Errors   - list the current buffer's diagnostics (like syntastic's :Errors)
lua require('carver.python-lint')
command! Errors lua vim.diagnostic.setloclist()

" ---- rust: rust-analyzer through neovim's built-in LSP client ---------------
"   <C-]> / gd   - jump to definition (tags-style, but nothing to regenerate)
"   K            - hover docs
"   grr grn gra  - references / rename / code action (neovim 0.11+ defaults)
" Needs `rustup component add rust-analyzer rust-src`; install.sh does that when rustup is present.
lua require('carver.rust-lsp')

" ---- render-markdown.nvim ---------------------------------------------------
"   :RenderMarkdown toggle   - rendered view in-place (raw on cursor line / insert mode)
"   :RenderMarkdown preview  - side-by-side: raw on left, rendered on right
"   <leader>m / <leader>M    - shortcuts for the above
lua require('carver.markdown-render')
nnoremap <leader>m :RenderMarkdown toggle<CR>
nnoremap <leader>M :RenderMarkdown preview<CR>

" ---- Detect file types in /tmp, like when running `sudo -e`
lua require('carver.detect-tmp-filetype')
