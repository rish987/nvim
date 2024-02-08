return {
  'Tyler-Barham/floating-help.nvim',
  config = function ()
    local fh = require('floating-help')

    fh.setup({
      -- Defaults
      width = 80,   -- Whole numbers are columns/rows
      height = 0.9, -- Decimals are a percentage of the editor
      position = 'C',   -- NW,N,NW,W,C,E,SW,S,SE (C==center)
    })

    -- Create a keymap for toggling the help window
    -- vim.keymap.set('n', '<C-f>', fh.toggle)
  end
}
