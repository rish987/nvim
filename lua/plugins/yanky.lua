return {
  "gbprod/yanky.nvim",
  init = function ()
    vim.keymap.set({"n","x"}, "y", "<Plug>(YankyYank)")
    -- vim.keymap.set({ "o", "x" }, "lp", function()
    --   require("yanky.textobj").last_put()
    -- end, {})
  end,
  opts = {
    highlight = {
      on_put = true,
      on_yank = true,
      timer = 500,
    },
    preserve_cursor_position = {
      enabled = true,
    },
  }
}
