return {
  "nvim-lua/plenary.nvim",
  {"YohananDiamond/fennel.vim", branch="remove-dot-and-colon-from-keywords"},
  { "catppuccin/nvim", name = "catppuccin",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      -- load the colorscheme here
      vim.cmd.colorscheme"catppuccin"
    end,
  },
  'onsails/lspkind.nvim',
  "andymass/vim-matchup",
  'lukas-reineke/indent-blankline.nvim',
}
