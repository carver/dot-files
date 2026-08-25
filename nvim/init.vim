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

" ---- nvim-lint: flake8 on open and on save ----------------------------------
"   :Errors   - list the current buffer's diagnostics (like syntastic's :Errors)
lua << LUA
  local ok, lint = pcall(require, 'lint')
  if ok then
    lint.linters_by_ft = { python = { 'flake8' } }
    -- same flag syntastic was given: line length is handled by 'textwidth'
    table.insert(lint.linters.flake8.args, 1, '--ignore=E501')
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
      group = vim.api.nvim_create_augroup('vimrc_lint', { clear = true }),
      -- ignore_errors: stay quiet when flake8 isn't installed
      callback = function() lint.try_lint(nil, { ignore_errors = true }) end,
    })
  end
  -- show the message next to the offending line, not just a gutter sign
  vim.diagnostic.config({ virtual_text = true })
LUA
command! Errors lua vim.diagnostic.setloclist()

" ---- rust: rust-analyzer through neovim's built-in LSP client ---------------
"   <C-]> / gd   - jump to definition (tags-style, but nothing to regenerate)
"   K            - hover docs
"   grr grn gra  - references / rename / code action (neovim 0.11+ defaults)
" Needs `rustup component add rust-analyzer rust-src`; install.sh does that when rustup is present.
lua << LUA
  local function cargo_root(file)
    local manifest = vim.fs.find('Cargo.toml', { upward = true, path = vim.fs.dirname(file) })[1]
    local root = manifest and vim.fs.dirname(manifest) or vim.fs.dirname(file)
    -- in a cargo workspace, run one server for the whole workspace, not one per member crate
    if manifest and vim.fn.executable('cargo') == 1 then
      local ok, meta = pcall(vim.json.decode, vim.fn.system({
        'cargo', 'metadata', '--no-deps', '--format-version', '1', '--manifest-path', manifest }))
      if ok and type(meta) == 'table' and meta.workspace_root then root = meta.workspace_root end
    end
    return root
  end

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'rust',
    group = vim.api.nvim_create_augroup('vimrc_rust_lsp', { clear = true }),
    callback = function(ev)
      if vim.fn.executable('rust-analyzer') == 0 then
        if not vim.g.warned_rust_analyzer then
          vim.g.warned_rust_analyzer = true
          vim.notify('rust-analyzer not found; run: rustup component add rust-analyzer rust-src',
                     vim.log.levels.WARN)
        end
        return
      end
      vim.lsp.start({
        name = 'rust-analyzer',
        cmd = { 'rust-analyzer' },
        root_dir = cargo_root(vim.api.nvim_buf_get_name(ev.buf)),
      })
    end,
  })

  -- buffer-local keys once a language server attaches (works back to neovim 0.9)
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('vimrc_lsp_keys', { clear = true }),
    callback = function(ev)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = ev.buf })
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = ev.buf })
    end,
  })
LUA

" ---- render-markdown.nvim ---------------------------------------------------
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
