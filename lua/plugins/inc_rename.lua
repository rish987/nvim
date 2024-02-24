return {
  "smjonas/inc-rename.nvim",
  opts = {},
  init = function ()
    vim.keymap.set("n", "<leader>r", ":IncRename ")
  end
}
