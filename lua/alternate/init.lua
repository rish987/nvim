local M = {}

local excluded_filetypes = { "NvimTree" }
local altwin
vim.api.nvim_create_autocmd("WinLeave", {
  callback = function(_)
    if not vim.tbl_contains(excluded_filetypes, vim.o.ft) then
      altwin = vim.api.nvim_get_current_win()
    end
  end,
})

function M.get_altwin()
  if altwin and vim.api.nvim_win_is_valid(altwin) then return altwin end

  -- choose any other valid window as the alternate
  for _, win in vim.api.nvim_tabpage_list_wins(0) do
    if win ~= vim.api.nvim_get_current_win() and not vim.tbl_contains(excluded_filetypes, vim.o.ft) then
      altwin = win
      return altwin
    end
  end
end

function M.alt_action(cmd)
  return function ()
    M.get_altwin()
    if not altwin then return end

    vim.api.nvim_win_call(altwin, function()
      vim.cmd(cmd)
    end)
  end
end

function M.alt_scroll(direction, speed)
  return function ()
    M.get_altwin()
    if not altwin then return end

    speed = speed or vim.api.nvim_win_get_height(altwin) / 2

    local dist = math.floor(speed * direction)
    local input = direction > 0 and [[]] or [[]]

    M.alt_action([[normal! ]] .. dist .. input)()
  end
end

vim.keymap.set("n", "<C-S-j>", M.alt_scroll(1))
vim.keymap.set("n", "<C-S-k>", M.alt_scroll(-1))

return M
