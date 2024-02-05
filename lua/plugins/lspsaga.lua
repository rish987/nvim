return {
    'nvimdev/lspsaga.nvim',
    config = function()
        require('lspsaga').setup({})
    end,
    init = function ()
      vim.keymap.set('n', 'gk', '<cmd>Lspsaga hover_doc ++keep<CR>')
    end,
    dependencies = {
        'nvim-treesitter/nvim-treesitter', -- optional
        'nvim-tree/nvim-web-devicons'     -- optional
    }
}
