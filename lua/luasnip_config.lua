local luasnip = require('luasnip')
local cmp = require("cmp")

require("luasnip.loaders.from_vscode").lazy_load()

local t = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local delims = {
  ["}"] = true,
  ["]"] = true,
  ["'"] = true,
  ["\""] = true,
  ["$"] = true,
  [")"] = true
}

local check_next_delim = function(line, col)
  if col <= (#line + 1) then
    local char = line:sub(col, col)
    if delims[char] then
      return true
    end

    return false
  else
    return false
  end
end

-- local check_back_space = function()
--   local col = vim.fn.col('.') - 1
--   if col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
--     return true
--   else
--     return false
--   end
-- end
--
_G.tab_complete = function()
  if luasnip and luasnip.jumpable(1) then
    return t("<Plug>luasnip-expand-or-jump")
  else
    local col = vim.fn.col('.')
    local line = vim.fn.getline('.')
    if check_next_delim(line, col) then
      while check_next_delim(line, col) do
        col = col + 1
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, true, true))
      end
      return ""
    else
      if luasnip.expandable() then
        return t("<Plug>luasnip-expand-or-jump")
      else
        local ret = ""
        cmp.mapping.confirm({ select = true })(function () ret = t "<Tab>" end)
        return ret
      end
    end
  end
end
_G.s_tab_complete = function()
  if luasnip and luasnip.jumpable(-1) then
    return t("<Plug>luasnip-jump-prev")
  end

  return t "<S-Tab>"
end

vim.api.nvim_set_keymap("i", "<Tab>", "v:lua.tab_complete()", {expr = true})
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
