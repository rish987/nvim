local fn = vim.fn
local packer_bootstrap
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

return require('packer').startup(function(use)
  -- core
  use "wbthomason/packer.nvim" -- Have packer manage itself
  use "nvim-lua/plenary.nvim"
  use "~/nvim-lspconfig"
  use "williamboman/nvim-lsp-installer"

  -- buffer management
  use "nvim-telescope/telescope.nvim"

  -- git
  use "lewis6991/gitsigns.nvim"

  -- completion
  use "hrsh7th/nvim-cmp"
  use "hrsh7th/cmp-nvim-lsp"
  use "hrsh7th/cmp-buffer" -- buffer completions
  use "hrsh7th/cmp-path" -- path completions
  use "hrsh7th/cmp-cmdline" -- cmdline completions
  use "saadparwaiz1/cmp_luasnip" -- snippet completions

  -- snippets
  use "L3MON4D3/LuaSnip" --snippet engine
  use "rafamadriz/friendly-snippets"

  -- language-specific
  use "Julian/lean.nvim"

  -- misc
  use "phaazon/hop.nvim"
  use "akinsho/toggleterm.nvim"
  use "andymass/vim-matchup"
  use "ur4ltz/surround.nvim"
  use "hkupty/nvimux"
  use "TimUntersberger/neogit"

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
