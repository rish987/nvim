-- source: https://github.com/benbrastmckie/.config/blob/master/nvim/after/ftplugin/tex.lua

require("nvim-surround").buffer_setup({
  surrounds = {
    ["c"] = {
      add = { "(;", ";)" },
      find = "%(;.-;%)",
      delete = "^(%(;)().-(;%))()$",
    },
  },
})

