local winpick = require"winpick"

winpick.setup({
  border = "double",
  filter = nil, -- doesn't ignore any window by default
  prompt = "Pick a window: ",
  format_label = winpick.defaults.format_label, -- formatted as "<label>: <buffer name>"
  chars = nil,
})

vim.keymap.set("n", "<C-w><C-w>", function()
  local winid = winpick.select()

  if winid then
    vim.api.nvim_set_current_win(winid)
  end
end)
