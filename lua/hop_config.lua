--local util = require"config_util"

require('leap').add_default_mappings()

local function get_line_starts(winid, forward, empty, beginning)
  local wininfo =  vim.fn.getwininfo(winid)[1]
  local cur_line = vim.api.nvim_win_get_cursor(winid)[1]
  local buf_text = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winid), 0, -1, false)

  -- Get targets.
  local targets = {}
  local lnum = wininfo.topline
  while lnum <= wininfo.botline do
    local fold_end = vim.fn.foldclosedend(lnum)
    -- Skip folded ranges.
    if fold_end ~= -1 then
      lnum = fold_end + 1
    else
      local line = buf_text[lnum]
      local line_empty = #line == 0
      local selected_line = (forward and lnum > cur_line) or (not forward and lnum < cur_line)
      local selected_line_contents = line_empty and empty or (not line_empty) and (not empty)
      if selected_line and selected_line_contents then
        local first_col = string.find(line, "%S") or 1
        local col = beginning and first_col or #line
        table.insert(targets, { pos = { lnum, col } })
      end
      lnum = lnum + 1
    end
  end
  -- Sort them by vertical screen distance from cursor.
  local cur_screen_row = vim.fn.screenpos(winid, cur_line, 1)['row']
  local function screen_rows_from_cur(t)
    local t_screen_row = vim.fn.screenpos(winid, t.pos[1], t.pos[2])['row']
    return math.abs(cur_screen_row - t_screen_row)
  end
  table.sort(targets, function (t1, t2)
    return screen_rows_from_cur(t1) < screen_rows_from_cur(t2)
  end)

  if #targets >= 1 then
    return targets
  end
end

local function leap_to_line(forward, empty, beginning)
  local winid = vim.api.nvim_get_current_win()
  require('leap').leap {
    target_windows = { winid },
    targets = get_line_starts(winid, forward, empty, beginning),
  }
end

vim.keymap.set({"n", "v"}, "zk", function () return leap_to_line(false, false, true) end)
vim.keymap.set({"n", "v"}, "zj", function () return leap_to_line(true, false, true) end)
vim.keymap.set({"n", "v"}, "Zk", function () return leap_to_line(false, false, false) end)
vim.keymap.set({"n", "v"}, "Zj", function () return leap_to_line(true, false, false) end)
vim.keymap.set({"n", "v"}, "zK", function () return leap_to_line(false, true, true) end)
vim.keymap.set({"n", "v"}, "zJ", function () return leap_to_line(true, true, true) end)

--require"hop".setup({
--  keys = 'asdfjklrughqwetyiopzxcvbnm'
--})
--vim.cmd("hi HopCursor ctermbg=Green")
--
--util.nmap("sl", ":HopWordAC<CR>")
--util.nmap("sh", ":HopWordBC<CR>")
