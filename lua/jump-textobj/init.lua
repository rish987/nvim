local M = {}

M._jump = function(dir)
  return function (_)
    local spos, epos = vim.api.nvim_buf_get_mark(0, '['), vim.api.nvim_buf_get_mark(0, ']')

    if vim.fn.mode():find("o") ~= nil then
      vim.cmd.normal { "v", bang = true }
    end

    if dir == "start" then
      vim.api.nvim_win_set_cursor(0, spos)
    else
      vim.api.nvim_win_set_cursor(0, epos)
    end
  end
end

M.jump = function (dir)
  vim.o.operatorfunc = ("v:lua.require'jump-textobj'._jump'%s'"):format(dir)
  vim.fn.feedkeys "g@"
end

vim.keymap.set({"n", "o"}, "<leader>l", [[<cmd>lua require"jump-textobj".jump("end")<CR>]])
vim.keymap.set({"n", "o"}, "<leader>h", [[<cmd>lua require"jump-textobj".jump("start")<CR>]])

return M
