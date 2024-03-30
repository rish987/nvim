return {
  'gorbit99/codewindow.nvim',
  opts = {
    auto_enable = false,
    exclude_filetypes = require"config_util".exclude_filetypes, -- Choose certain filetypes to not show minimap on
  },
  init = function()
    local codewindow = require('codewindow')
    codewindow.apply_default_keybinds()
  end,
}
