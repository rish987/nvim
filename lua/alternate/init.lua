local M = {}

local excluded_filetypes = { "NvimTree" }
local prevwin
local altwin

vim.api.nvim_create_autocmd("WinLeave", {
  callback = function()
    prevwin = vim.api.nvim_get_current_win()
  end,
})

vim.api.nvim_create_autocmd({"WinLeave", "WinEnter", "WinNew", "BufWinEnter", "VimEnter"}, {
  callback = function()
    M.refresh_altwin()
  end
})

function M.curr_altwin()
  return altwin
end

function M.set_altwin(new_altwin)
  altwin = new_altwin
  require"lualine".refresh()
end

local function is_valid_altwin(win)
  if not win or not vim.api.nvim_win_is_valid(win) then return false end
  local excluded = vim.tbl_contains(excluded_filetypes, vim.bo[vim.api.nvim_win_get_buf(win)].ft)
  local in_curr_tab = vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage()
  local is_curr_win = vim.api.nvim_get_current_win() == win
  return in_curr_tab and not excluded and not is_curr_win
end

-- TODO remember altwins on a per-tabpage basis
function M.refresh_altwin()
  local _prevwin = prevwin
  prevwin = nil

  if is_valid_altwin(altwin) then return altwin end
  if is_valid_altwin(_prevwin) then M.set_altwin(_prevwin) end

  altwin = nil

  -- choose any other valid window as the alternate
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local floating = vim.api.nvim_win_get_config(win).relative ~= ''
    if is_valid_altwin(win) and not floating then
      M.set_altwin(win)
      return altwin
    end
  end
end

vim.keymap.set("n", "<space>j", M.refresh_altwin)

function M.alt_cmd(cmd)
  return function ()
    M.refresh_altwin()
    if not altwin then return end

    vim.api.nvim_win_call(altwin, function()
      vim.cmd(cmd)
    end)
  end
end

function M.alt_feedkeys(keys)
  return function ()
    M.refresh_altwin()
    if not altwin then return end

    vim.api.nvim_win_call(altwin, function()
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true))
    end)
  end
end

function M.alt_wincmd(cmd)
  return function ()
    M.refresh_altwin()
    if not altwin then return end

    vim.api.nvim_win_call(altwin, function()
      vim.cmd.wincmd(cmd)
    end)
  end
end

function M.alt_goto()
  M.refresh_altwin()
  if not altwin then return end

  vim.api.nvim_set_current_win(altwin)
end

function M.alt_scroll(direction, speed)
  return function ()
    M.refresh_altwin()
    if not altwin then return end

    speed = speed or vim.api.nvim_win_get_height(altwin) / 2

    local dist = math.floor(speed * direction)
    local input = direction > 0 and [[]] or [[]]

    M.alt_cmd([[normal! ]] .. dist .. input)()
  end
end

function M.alt_setview()
  M.refresh_altwin()
  if not altwin then return end

  local buf = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)

  vim.api.nvim_win_call(altwin, function()
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, pos)
    vim.cmd.normal("zz")
  end)
end

function M._test()
  local _testvar = 5
  vim.api.nvim_list_wins()
  -- vim.print(M.curr_altwin())
end

function M.test()
  local testvar = 5
  M._test()
  return testvar
end

vim.keymap.set("n", "<C-w><C-w>", M.alt_goto)

vim.keymap.set("n", "<C-A-j>", M.alt_scroll(1))
vim.keymap.set("n", "<C-A-k>", M.alt_scroll(-1))
vim.keymap.set("n", "<C-A-l>", M.alt_setview)
vim.keymap.set("n", "<C-A-g><C-A-g>", M.alt_cmd([[normal! gg]]))
vim.keymap.set("n", "<C-A-e>", M.alt_cmd([[LeanRefreshFileDependencies]]))
vim.keymap.set("n", "<C-A-g>g", M.alt_cmd([[normal! G]]))
vim.keymap.set("n", "<C-A-w>c", M.alt_wincmd("c"))
vim.keymap.set("n", "<C-A-w>c", M.alt_wincmd("c"))

return M
