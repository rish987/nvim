return {
  "smjonas/inc-rename.nvim",
  config = function()
    require("inc_rename").setup()
  end,
  init = function ()
    vim.keymap.set("n", "<leader>r", ":IncRename ")
  end
}
