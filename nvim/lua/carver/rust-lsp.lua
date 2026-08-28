---- rust: rust-analyzer through neovim's built-in LSP client, no plugin needed

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
