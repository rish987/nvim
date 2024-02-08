return {
  'nvimdev/lspsaga.nvim',
  config = function(_, opts)
      require('lspsaga').setup(opts)
  end,
  init = function ()
    vim.keymap.set('n', '<leader>k', '<cmd>Lspsaga hover_doc ++keep<CR>')
  end,
  opts = {
    lightbulb = {
      enable = false,
      virtual_text = false,
      enable_in_insert = false
    }
  },
}
