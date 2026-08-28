---- Detect file types in /tmp, like when running `sudo -e`

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "/var/tmp/*", "/tmp/*" },
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "" then return end
    local base = vim.fn.expand("%:t"):match("^(.*)%.[%w]+$")
    if not base then return end
    local ft = vim.filetype.match({ filename = base, buf = args.buf })
    if ft then vim.bo[args.buf].filetype = ft end
  end,
})
