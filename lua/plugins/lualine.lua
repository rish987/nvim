return {
  {
    'nvim-lualine/lualine.nvim',
    lazy = false,
    config = true,
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
        inactive_sections = {
          lualine_x = {
            {
              function () -- FIXME trigger more frequent alternate resets
                return "ALT"
              end,
              cond = function ()
                -- require"vim.lsp.log".error(vim.inspect(require"alternate".curr_altwin()) .. ", " .. vim.api.nvim_get_current_win())
                if require"alternate".curr_altwin() == vim.api.nvim_get_current_win() then
                  return true
                end
                return false
              end,
              color = { fg = "#000000", bg = "#fc51ed" },
            },
          }
        }
      }
    end,
  }
}
