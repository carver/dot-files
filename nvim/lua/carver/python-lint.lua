---- nvim-lint: run flake8 on python buffers on open and on save

local ok, lint = pcall(require, 'lint')
if not ok then return end

lint.linters_by_ft = { python = { 'flake8' } }
-- same flag syntastic was given: line length is handled by 'textwidth'
table.insert(lint.linters.flake8.args, 1, '--ignore=E501')
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
  group = vim.api.nvim_create_augroup('vimrc_lint', { clear = true }),
  -- ignore_errors: stay quiet when flake8 isn't installed
  callback = function() lint.try_lint(nil, { ignore_errors = true }) end,
})
