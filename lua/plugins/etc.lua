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
  -- {
  --   "airblade/vim-rooter",
  --   config = function ()
  --     vim.g.rooter_cd_cmd = 'tcd'
  --     vim.g.rooter_patterns = {'!^.lake', '.git'}
  --   end,
  -- },
  {
    "tiagovla/scope.nvim",
    init = function() require"scope".setup{} end
  },
  {
    "famiu/bufdelete.nvim"
  },
  { "tenxsoydev/karen-yank.nvim",
    enabled = false,
    config = function ()
      require"karen-yank".setup({
        mappings = {
          karen = "y",
          invert = true
        }
      })
      vim.api.nvim_create_augroup("KarenYank", {clear = true})
    end },
  {
    "ton/vim-bufsurf",
    init = function ()
      vim.keymap.set("n", "<C-S-h>", "<Plug>(buf-surf-back)")
      vim.keymap.set("n", "<C-S-l>", "<Plug>(buf-surf-forward)")
    end
  },
  -- {
  --   "git@github.com:AckslD/messages.nvim.git",
  --   config = true
  -- },
  {
    "ariel-frischer/bmessages.nvim",
    lazy = false,
    priority = 1000,
		config = function()
      require"bmessages".setup()
      if vim.g.StartedByNvimTask then
      end
		end,
    opts = {}
  },
  {
    "sindrets/winshift.nvim",
    config = true
  },
}
