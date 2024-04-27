local check_next_delim = function(line, col)
  for _, rule in ipairs(require("nvim-autopairs").get_buf_rules(vim.api.nvim_get_current_buf())) do
    if rule.start_pair then
      local delim = rule.end_pair
      if line:find(delim, col, true) == col then return delim end
    end
  end
end

local get_jump_col = function(line, col)
  local next_delim = check_next_delim(line, col)
  while next_delim do
    col = col + #next_delim

    next_delim = col <= #line and check_next_delim(line, col)
  end
  return col
end

-- TODO fix a.util.timeout function? (which uses a.wrap instead)
local timeout = require'plenary.async'.wrap(function(fn, ms, callback)
  -- make sure that the callback isn't called twice, or else the coroutine can be dead
  local done = false

  local timeout_callback = function(...)
    if not done then
      done = true
      callback(false, ...) -- false because it has run normally
    end
  end

  vim.defer_fn(function()
    if not done then
      done = true
      callback(true) -- true because it has timed out
    end
  end, ms)

  require('plenary.async_lib').run(fn, timeout_callback)
end, 3)

-- local check_back_space = function()
--   local col = vim.fn.col('.') - 1
--   if col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
--     return true
--   else
--     return false
--   end
-- end

local mfns = vim.api.nvim_create_namespace('multifun')
local colors = {
  {"Red",          "White"},
  {"Green",        "White"},
  {"Blue",         "White"},
  {"Cyan",         "Black"},
  {"Magenta",      "White"},
  {"Yellow",       "Black"},
  {"Gray",         "Black"},
  {"Orange",       "Black"},
  {"LightRed",     "Black"},
  {"LightGreen",   "Black"},
  {"LightBlue",    "Black"},
  {"LightCyan",    "Black"},
  {"LightMagenta", "Black"},
  {"LightYellow",  "Black"},
  {"LightGray",    "Black"},
  {"Purple",       "White"},
}
local hls = {}

for _, color in ipairs(colors) do
  local hlname = string.format("MF%s", color[1])
  vim.cmd(string.format("highlight %s guibg=%s guifg=%s", hlname, color[1], color[2]))
  table.insert(hls, hlname)
end

local curr_action_i = nil
local curr_actions = {}

local function get_actions(_actions)
  local actions
  if type(_actions) == "function" then
    actions = _actions()
  else
    actions = _actions
  end

  local conflicting_actions = {}
  for _, action in ipairs(actions) do
    if action[1] then -- is a list of equal-priority actions
      for _, _action in ipairs(action) do
        if _action.cond() then -- do the first possible action
          table.insert(conflicting_actions, _action)
          break
        end
      end
    elseif action.cond() then
      table.insert(conflicting_actions, action)
    end
  end

  if #conflicting_actions > 0 then
    curr_action_i = 1
    curr_actions = conflicting_actions
  end
end

local hint_disable = false

local multifun = function()
    -- local color_idx = 1
    -- local set_virt_text = function (action)
    --   if not action.virt_text then -- set both text and hl
    --     action.virt_text = {" ", hls[color_idx]}
    --     color_idx = color_idx + 1
    --   elseif type(action.virt_text) == "string" then -- set only hl
    --     action.virt_text = {action.virt_text, hls[color_idx]}
    --     color_idx = color_idx + 1
    --   end
    -- end
    --
    -- local actions
    -- if type(_actions) == "function" then
    --   actions = _actions()
    -- else
    --   actions = _actions
    -- end
    --
    -- for _, action in ipairs(actions) do
    --   if action[1] then -- is a list of equal-priority actions
    --     for _, _action in ipairs(action) do
    --       set_virt_text(_action)
    --     end
    --   else
    --     set_virt_text(action)
    --   end
    -- end
    --
    -- local conflicting_actions = {}
    -- for _, action in ipairs(actions) do
    --   if action[1] then -- is a list of equal-priority actions
    --     for _, _action in ipairs(action) do
    --       if _action.cond() then -- do the first possible action
    --         table.insert(conflicting_actions, _action)
    --         break
    --       end
    --     end
    --   elseif action.cond() then
    --     table.insert(conflicting_actions, action)
    --   end
    -- end
    local action = curr_action_i and curr_actions[curr_action_i]
    if action then
      hint_disable = true
      action.cb()
      hint_disable = false
    end

    -- for _, action in ipairs(conflicting_actions) do
    --   print(action.desc)
    -- end

    -- for i, action in ipairs(conflicting_actions) do
      -- if i == #conflicting_actions then
      --   action.cb()
      --   return
      -- end
      --
      -- local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      --
      -- local virt_text = {}
      -- table.insert(virt_text, {" ", "Normal"})
      --
      -- for _, _action in ipairs({unpack(conflicting_actions, i, #conflicting_actions)}) do
      --   table.insert(virt_text, _action.virt_text)
      -- end
      --
      -- table.insert(virt_text, 3, {" ", "Normal"}) -- separate currently selected action from alternatives
      --
      -- vim.api.nvim_buf_set_extmark(0, mfns, row - 1, col, {virt_text = virt_text, virt_text_pos = "overlay", priority = 10000})
      -- vim.cmd.redraw()
      --
      -- local key
      -- local timed_out = timeout(function (cb) key = vim.fn.getcharstr() cb() end, 1000) -- wait for another tabkey
      --
      -- vim.api.nvim_buf_clear_namespace(0, mfns, 0, -1) -- clear extmark
      -- if timed_out then
      --   vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, true, true))
      --   action.cb()
      --   return
      -- elseif key ~= vim.api.nvim_replace_termcodes("<Tab>", true, true, true) then
      --   action.cb()
      --   vim.fn.feedkeys(key) -- re-feed the original key if not tab
      --   return
      -- end
    -- end
end
local _clear = function()
  vim.api.nvim_buf_clear_namespace(0, mfns, 0, -1) -- clear any extmarks
end

local clear = function()
  _clear()
  curr_action_i = nil
  curr_actions = {}
end

local _hint = function ()
  _clear()
  local action = curr_action_i and curr_actions[curr_action_i]
  if action and action.hint then
    local virt_text = {}
    local hint = type(action.hint) == "function" and action.hint() or action.hint
    local row, col = unpack(hint)
    local line = vim.fn.getline(row)
    local char = col + 1 <= #line and line:sub(col+1, col+1) or " "
    table.insert(virt_text, {char, "MFLightRed"})
    vim.api.nvim_buf_set_extmark(0, mfns, row - 1, col, {virt_text = virt_text, virt_text_pos = "overlay", priority = nil})
  end
end

local multifun_alternate = function()
  if not curr_action_i then return end

  curr_action_i = (curr_action_i % #curr_actions) + 1
  _hint()
end

local hint = function (mode, _actions)
  if vim.api.nvim_get_mode().mode ~= mode or hint_disable then return end
  clear()
  get_actions(_actions)
  _hint()
end

local tab_actions = function()
  local luasnip = require('luasnip')
  local cmp = require("cmp")

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1
  local line = vim.fn.getline('.')

  local luasnip_expand = {cb = luasnip.expand, cond = luasnip.expandable, desc = "luasnip expand", virt_text = "e"}
  local luasnip_jump = {cb = function() luasnip.jump(1) end, cond = function() return luasnip.jumpable(1) end, desc = "luasnip jump", virt_text = "j"}
  local cmp_confirm = {
    cb = function()
           cmp.mapping.confirm({ select = true })(function () end)
         end,
    cond = function() return cmp.core.view:visible() end,
    desc = "confirm first completion",
    virt_text = "c"
  }
  local jump_endpairs = {
    cb = function()
      vim.api.nvim_win_set_cursor(0, {row, get_jump_col(line, col) - 1})
    end,
    cond = function() return check_next_delim(line, col) end,
    hint = {row, get_jump_col(line, col) - 1},
    desc = "jump over ending pairs",
    virt_text = "p"
  }
  local jump_endline = {
    cb = function()
      vim.api.nvim_win_set_cursor(0, {row, #line})
    end,
    cond = function() return col ~= #line + 1 end,
    hint = {row, #line},
    desc = "jump to end of line",
    virt_text = "l"
  }
  local newline = {
    cb = function()
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, true, true))
    end,
    cond = function() return col == #line + 1 end,
    desc = "new line",
    virt_text = "n"
  }

  return {
    jump_endpairs,
    luasnip_expand,
    luasnip_jump,
    cmp_confirm,
    jump_endline,
    newline,
  }
end

vim.api.nvim_create_autocmd({"InsertLeave"},
  {
    callback = function(info) clear() end
  })

local event = (require"cmp".event)
event:on("menu_opened",
function (_)
  vim.cmd([[doautocmd <nomodeline> User CmpMenuOpened]])
end
)
event:on("menu_closed",
function (_)
  vim.cmd([[doautocmd <nomodeline> User CmpMenuClosed]])
end
)

vim.api.nvim_create_autocmd({"TextChangedI", "CursorMovedI", "InsertEnter"},
  {
    callback = function (info) --[[ print(info.event) ]] hint("i", tab_actions) end,
  })
vim.api.nvim_create_autocmd({"User"},
  {
    callback = function (info) hint("i", tab_actions) end,
    pattern = {"CmpMenuClosed", "CmpMenuOpened"}
  })

local primary = "<Tab>"
local alternate = "<C-Q>"

vim.keymap.set("i", primary, multifun)
vim.keymap.set("i", alternate, multifun_alternate)
