local luasnip = require('luasnip')
local npairs = require("nvim-autopairs")
local cmp = require("cmp")
local a = require('plenary.async_lib')
local async = require('plenary.async')

require("luasnip.loaders.from_vscode").lazy_load()

local t = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local check_next_delim = function(line, col)
  for _, rule in ipairs(npairs.get_buf_rules(vim.api.nvim_get_current_buf())) do
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
local timeout = async.wrap(function(fn, ms, callback)
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

  a.run(fn, timeout_callback)
end, 3)

-- local check_back_space = function()
--   local col = vim.fn.col('.') - 1
--   if col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
--     return true
--   else
--     return false
--   end
-- end
--
local tab_complete = function()
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

_G.s_tab_complete = function()
  if luasnip and luasnip.jumpable(-1) then
    return t("<Plug>luasnip-jump-prev")
  end

  return t "<S-Tab>"
end

vim.keymap.set("i", "<Tab>", async.void(tab_complete))
vim.api.nvim_set_keymap("s", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("i", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
vim.api.nvim_set_keymap("i", "<C-n>", "<Plug>luasnip-next-choice", {})
vim.api.nvim_set_keymap("s", "<C-n>", "<Plug>luasnip-next-choice", {})
vim.api.nvim_set_keymap("i", "<C-p>", "<Plug>luasnip-prev-choice", {})
vim.api.nvim_set_keymap("s", "<C-p>", "<Plug>luasnip-prev-choice", {})

vim.keymap.set("i", "<C-j>", function() if luasnip then luasnip.jump(1) end end, {})
vim.keymap.set("i", "<C-u>", function() if luasnip then print(luasnip.jumpable(-1)) luasnip.jump(-1) end end, {})

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
