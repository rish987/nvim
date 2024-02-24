return {
  {
    'nvim-lualine/lualine.nvim',
    lazy = false,
    config = function (_, opts)
      require"lualine".setup(opts) -- FIXME should't this be done automatically?
    end,
    dependencies = {
      "folke/noice.nvim"
    },
    opts = function ()
      return {
        sections = {
          lualine_c = {{'filename', path = 1}},
          lualine_x = {
            {
              require("lazy.status").updates,
              cond = require("lazy.status").has_updates,
              color = { fg = "#ff9e64" },
            },
            {
              require("noice").api.status.message.get_hl,
              cond = require("noice").api.status.message.has,
            },
            {
              require("noice").api.status.command.get,
              cond = require("noice").api.status.command.has,
              color = { fg = "#ff9e64" },
            },
            {
              require("noice").api.status.mode.get,
              cond = require("noice").api.status.mode.has,
              color = { fg = "#ff9e64" },
            },
            {
              require("noice").api.status.search.get,
              cond = require("noice").api.status.search.has,
              color = { fg = "#ff9e64" },
            },
          },
        },
        lualine_y = {
          { require("recorder").displaySlots },
        },
        lualine_z = {
          { require("recorder").recordingStatus },
        },
      }
    end,
  }
}
