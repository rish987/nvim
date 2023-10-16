return {
  {
    'nvim-lualine/lualine.nvim',
    lazy = false,
    config = function (_, opts)
      require"lualine".setup(opts) -- FIXME should't this be done automatically?
    end,
    opts = {
      sections = {
        lualine_x = {
          {
            require("lazy.status").updates,
            cond = require("lazy.status").has_updates,
            color = { fg = "#ff9e64" },
          },
        },
      },
    },
    dependencies = { 'nvim-tree/nvim-web-devicons' }
  }
}
