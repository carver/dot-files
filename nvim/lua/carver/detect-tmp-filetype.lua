---- Detect file types in /tmp, like when running `sudo -e`
--
-- sudoedit copies /etc/ssh/sshd_config to /var/tmp/sshd_config.XXXXXXXX, which hides the
-- name neovim would recognise. A file that already has an extension keeps it, as in
-- nginxXXXXXXXX.conf, so the extension rules handle that case before this one runs.
--
-- Registered as a pattern with the lowest priority, so it runs inside neovim's own
-- detection after every filename and extension rule, whatever order this module loads in.

local function without_random_suffix(path, bufnr)
  local base = vim.fs.basename(path):match("^(.*)%.%w+$")
  if not base then return nil end
  return vim.filetype.match({ filename = base, buf = bufnr })
end

vim.filetype.add({
  pattern = {
    ["/var/tmp/.*"] = { without_random_suffix, { priority = -math.huge } },
    ["/tmp/.*"] = { without_random_suffix, { priority = -math.huge } },
  },
})
