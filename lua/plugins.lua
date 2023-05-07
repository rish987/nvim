local fn = vim.fn
local packer_bootstrap
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

-- Put this at the end after all plugins
if packer_bootstrap then
  require('packer').sync()
end

function Set (list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

local localized_repos =
Set {
  "nvim-lspconfig",
  "nvim-cmp",
  "lean.nvim",
  "leap.nvim",
  "toggleterm.nvim",
  "resession.nvim",
  "friendly-snippets",
  "LuaSnip",
  "telescope.nvim",
}

return require('packer').startup(function(use)
  -- set to true when using local development repos
  local use_local = true

  local my_use = function(arg)
    local is_table = type(arg) == "table"

    local path = is_table and arg[1] or arg
    local split_path = vim.fn.split(path, "/")

    local author = split_path[1]
    local repo = split_path[2]

    local prefix = use_local and localized_repos[repo] and "~" or author
    path = prefix .. "/" .. repo

    if is_table then
      arg[1] = path
    else
      arg = path
    end

    return use(arg)
  end

  -- core
  my_use "wbthomason/packer.nvim" -- Have packer manage itself
  my_use "nvim-lua/plenary.nvim"
  my_use {
    "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  my_use "neovim/nvim-lspconfig"

  -- navigation
  my_use "nvim-telescope/telescope.nvim"
    -- telescope extensions
    my_use "jvgrootveld/telescope-zoxide"
    my_use "LukasPietzschmann/telescope-tabs"
  my_use "ggandor/leap.nvim"
  my_use "ggandor/flit.nvim"

  -- git
  my_use "lewis6991/gitsigns.nvim"
  my_use { 'sindrets/diffview.nvim', requires = 'nvim-lua/plenary.nvim' }

  -- completion
  my_use "hrsh7th/nvim-cmp"
  my_use "hrsh7th/cmp-nvim-lsp"
  my_use "hrsh7th/cmp-buffer" -- buffer completions
  my_use "hrsh7th/cmp-path" -- path completions
  my_use "hrsh7th/cmp-cmdline" -- cmdline completions
  my_use "saadparwaiz1/cmp_luasnip" -- snippet completions
  my_use "uga-rosa/cmp-dictionary" -- dictionary completions

  -- snippets
  use { "L3MON4D3/LuaSnip", run = "make install_jsregexp" }
  my_use "rafamadriz/friendly-snippets" -- collection of my_useful snippets

  -- language-specific
  my_use "Julian/lean.nvim"
  my_use "lervag/vimtex"

  -- syntax highlighting
  my_use "bakpakin/fennel.vim"

  -- UI
  my_use 'nanozuki/tabby.nvim'
  my_use { "catppuccin/nvim", as = "catppuccin" }
  my_use {
    'nvim-lualine/lualine.nvim',
    requires = { 'nvim-tree/nvim-web-devicons', opt = true }
  }

  -- misc
  my_use "akinsho/toggleterm.nvim"
  my_use "andymass/vim-matchup"
  my_use "kylechui/nvim-surround"
  my_use "hkupty/nvimux"
  my_use "TimUntersberger/neogit"
  my_use "folke/neodev.nvim"
  my_use "gbrlsnchs/winpick.nvim"
  my_use "stevearc/resession.nvim"
  my_use {
    'glacambre/firenvim',
    run = function() vim.fn['firenvim#install'](0) end
  }
  my_use 'karb94/neoscroll.nvim'
  my_use 'windwp/nvim-autopairs'


  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
