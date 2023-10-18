return {
  "TimUntersberger/neogit",
  opts = {},
  init = function ()
    vim.keymap.set("n", "<leader>g", function() require"neogit".open() end)
  end
}
