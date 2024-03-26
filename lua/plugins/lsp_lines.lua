return {
  "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
  init = function ()
    vim.keymap.set(
      "",
      "<Leader>dl",
      require("lsp_lines").toggle,
      { desc = "Toggle lsp_lines" }
    )
  end,
  opts = {}
}
