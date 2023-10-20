local check_next_delim = function(line, col)
  for _, rule in ipairs(require("nvim-autopairs").get_buf_rules(vim.api.nvim_get_current_buf())) do
    if rule.start_pair then
      local delim = rule.end_pair
      if line:find(delim, col, true) == col then return delim end
    end
  end
end

local skip_delims = function()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')

  local next_delim = check_next_delim(line, col)
  while next_delim do
    for _ = 1, vim.fn.strdisplaywidth(next_delim) do
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, true, true))
    end

    col = col + #next_delim
    if col > #line then return end

    next_delim = check_next_delim(line, col)
  end
end

-- vim.keymap.set("i", "<Tab>", skip_delims)

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

local multifun = function(_actions)
  return function()
    local color_idx = 1
    local set_virt_text = function (action)
      if not action.virt_text then -- set both text and hl
        action.virt_text = {" ", hls[color_idx]}
        color_idx = color_idx + 1
      elseif type(action.virt_text) == "string" then -- set only hl
        action.virt_text = {action.virt_text, hls[color_idx]}
        color_idx = color_idx + 1
      end
    end

    local actions
    if type(_actions) == "function" then
      actions = _actions()
    else
      actions = _actions
    end

    for _, action in ipairs(actions) do
      if action[1] then -- is a list of equal-priority actions
        for _, _action in ipairs(action) do
          set_virt_text(_action)
        end
      else
        set_virt_text(action)
      end
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

    -- for _, action in ipairs(conflicting_actions) do
    --   print(action.desc)
    -- end

    for i, action in ipairs(conflicting_actions) do
      if i == #conflicting_actions then
        action.cb()
        return
      end

      local row, col = unpack(vim.api.nvim_win_get_cursor(0))

      local virt_text = {}
      table.insert(virt_text, {" ", "Normal"})

      for _, _action in ipairs({unpack(conflicting_actions, i, #conflicting_actions)}) do
        table.insert(virt_text, _action.virt_text)
      end

      vim.api.nvim_buf_set_extmark(0, mfns, row - 1, col, {virt_text = virt_text, virt_text_pos = "overlay", priority = 10000})
      vim.cmd.redraw()

      local key
      local timed_out = timeout(function (cb) key = vim.fn.getcharstr() cb() end, 1000) -- wait for another tabkey

      vim.api.nvim_buf_clear_namespace(0, mfns, 0, -1) -- clear extmark
      if timed_out then
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, true, true))
        action.cb()
        return
      elseif key ~= vim.api.nvim_replace_termcodes("<Tab>", true, true, true) then
        action.cb()
        vim.fn.feedkeys(key) -- re-feed the original key if not tab
        return
      end
    end
  end
end

local tab_actions = function()
  local luasnip = require('luasnip')
  local cmp = require("cmp")

  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')

  return {
    {cb = luasnip.expand, cond = luasnip.expandable, desc = "luasnip expand", virt_text = "e"},
    {cb = function() luasnip.jump(1) end, cond = function() return luasnip.jumpable(1) end, desc = "luasnip jump", virt_text = "j"},
    {
      cb = function()
              cmp.mapping.confirm({ select = true })(function () end)
           end,
      cond = function() return cmp.core.view:visible() end,
      desc = "confirm first completion",
      virt_text = "c"
    },
    {
      {
        cb = function()
          local next_delim = check_next_delim(line, col)
          while next_delim do
            for _ = 1, vim.fn.strdisplaywidth(next_delim) do
              vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, true, true))
            end

            col = col + #next_delim

            next_delim = col <= #line and check_next_delim(line, col)
          end
        end,
        cond = function() return check_next_delim(line, col) end,
        desc = "jump over ending pairs",
        virt_text = "p"
      },
      {
        cb = function()
          vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-o>$", true, true, true))
        end,
        cond = function() return col ~= #line + 1 end,
        desc = "jump to end of line",
        virt_text = "l"
      },
      {
        cb = function()
          vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, true, true))
        end,
        cond = function() return col == #line + 1 end,
        desc = "new line",
        virt_text = "n"
      },
    },
  }
end

local tab_complete = function()
  local luasnip = require('luasnip')
  local cmp = require("cmp")
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')

  if check_next_delim(line, col) then
    local skip = false

    if cmp.core.view:visible() then -- require double-tabpress if autocomplete open
      local timed_out = timeout(function (cb) vim.fn.getcharstr() cb() end, 1000) -- wait for another tabkey
      if timed_out then
        skip = true
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, true, true))
      end
    end

    if not skip then
      local next_delim = check_next_delim(line, col)
      while next_delim do
        for _ = 1, vim.fn.strdisplaywidth(next_delim) do
          vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, true, true))
        end

        col = col + #next_delim

        next_delim = col <= #line and check_next_delim(line, col)
      end
      return
    end
  end

  if luasnip and luasnip.expand_or_jumpable() then
    luasnip.expand_or_jump()
    return
  end

  if cmp.core.view:visible() then
    cmp.mapping.confirm({ select = true })(function () end)
    return
  end

  if col ~= #line + 1 then
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-o>$", true, true, true))
    return
  end

  vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, true, true))
end

return {
  "rafamadriz/friendly-snippets", -- collection of my_useful snippets
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
    build = "make install_jsregexp",
    init = function ()
      -- vim.keymap.set("i", "<C-u>", function() if luasnip then print(luasnip.jumpable(-1)) luasnip.jump(-1) end end, {})
      vim.keymap.set("i", "<Tab>", require'plenary.async'.void(multifun(tab_actions)))
      vim.keymap.set("i", "<C-j>", function() require"luasnip".jump(1) end, {})

      vim.api.nvim_create_autocmd('ModeChanged', {
        pattern = '*',
        callback = function()
          if ((vim.v.event.old_mode == 's' and vim.v.event.new_mode == 'n') or vim.v.event.old_mode == 'i')
            and require('luasnip').session.current_nodes[vim.api.nvim_get_current_buf()]
            and not require('luasnip').session.jump_active
            then
              require('luasnip').unlink_current()
            end
          end
        })
    end,
    config = function (_, _)
      require("luasnip.loaders.from_vscode").lazy_load()
    end
  }
}
