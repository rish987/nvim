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
  { 'onsails/lspkind.nvim', },
  "andymass/vim-matchup",
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
  {
    "fdschmidt93/telescope-egrepify.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" }
  },
  {
    "airblade/vim-rooter",
    config = function ()
      vim.g.rooter_cd_cmd = 'tcd'
      vim.g.rooter_patterns = {'.git'}
    end,
  },
  {
    "tiagovla/scope.nvim",
    init = function() require"scope".setup{} end
  },
}
