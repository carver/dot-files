---- render-markdown.nvim: in-buffer markdown rendering

local ok, rm = pcall(require, 'render-markdown')
if not ok then return end

rm.setup({
  -- render in normal/command modes; show raw text while in insert mode
  render_modes = { 'n', 'c', 't' },
  -- plain markers so it still looks fine without a Nerd Font installed
  heading = { icons = { '# ', '## ', '### ', '#### ', '##### ', '###### ' } },
  checkbox = { unchecked = { icon = '[ ]' }, checked = { icon = '[x]' } },
  code = { language_icon = false },
})
