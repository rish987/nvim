return {
  "abeldekat/lazyflex.nvim",
  priority = 10001,
  version = "*",
  cond = true,
  import = "lazyflex.hook",
  opts = {
    -- kw = {"lspconfig", "overseer", "telescope", "resession", "lean", "noice", "plenary", "nui", "nvim-treesitter", "luasnip", "lualine", "yanky",
    -- }
  },
  -- your plugins:
  -- { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  -- { import = "plugins" },
}
