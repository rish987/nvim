return {
  "rafamadriz/friendly-snippets", -- collection of my_useful snippets
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
    build = "make install_jsregexp",
    init = function ()
      -- vim.keymap.set("i", "<C-u>", function() if luasnip then print(luasnip.jumpable(-1)) luasnip.jump(-1) end end, {})
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
