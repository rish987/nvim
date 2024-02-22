local M = {}

local excluded_filetypes = { "NvimTree" }
local altwin
vim.api.nvim_create_autocmd("WinLeave", {
  callback = function()
    if not vim.tbl_contains(excluded_filetypes, vim.o.ft) then
      altwin = vim.api.nvim_get_current_win()
    end
  end,
})

-- TODO remember altwins on a per-tabpage basis
function M.get_altwin()
  if altwin and vim.api.nvim_win_is_valid(altwin) and vim.api.nvim_win_get_tabpage(altwin) == vim.api.nvim_get_current_tabpage() then return altwin end

  -- choose any other valid window as the alternate
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local floating = vim.api.nvim_win_get_config(win).relative ~= ''
    local excluded = vim.tbl_contains(excluded_filetypes, vim.bo[vim.api.nvim_win_get_buf(win)].ft)
    if win ~= vim.api.nvim_get_current_win() and not excluded and not floating then
      altwin = win
      return altwin
    end
  end
end

function M.alt_cmd(cmd)
  return function ()
    M.get_altwin()
    if not altwin then return end

    vim.api.nvim_win_call(altwin, function()
      vim.cmd(cmd)
    end)
  end
end

function M.alt_feedkeys(keys)
  return function ()
    M.get_altwin()
    if not altwin then return end

    vim.api.nvim_win_call(altwin, function()
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true))
    end)
  end
end

function M.alt_wincmd(cmd)
  return function ()
    M.get_altwin()
    if not altwin then return end

    vim.api.nvim_win_call(altwin, function()
      vim.cmd.wincmd(cmd)
    end)
  end
end

function M.alt_goto()
  M.get_altwin()
  if not altwin then return end

  vim.api.nvim_set_current_win(altwin)
end

function M.alt_scroll(direction, speed)
  return function ()
    M.get_altwin()
    if not altwin then return end

    speed = speed or vim.api.nvim_win_get_height(altwin) / 2

    local dist = math.floor(speed * direction)
    local input = direction > 0 and [[]] or [[]]

    M.alt_cmd([[normal! ]] .. dist .. input)()
  end
end

vim.keymap.set("n", "<C-w><C-w>", M.alt_goto)

vim.keymap.set("n", "<C-S-j>", M.alt_scroll(1))
vim.keymap.set("n", "<C-S-k>", M.alt_scroll(-1))
vim.keymap.set("n", "<C-S-w>c", M.alt_wincmd("c"))

return M
