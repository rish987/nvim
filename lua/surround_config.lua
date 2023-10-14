require("nvim-surround").setup({
  -- Configuration here, or leave empty to use defaults
  keymaps = {
      insert = "<C-g>s",
      insert_line = "<C-g>S",
      normal = "ys",
      normal_cur = "yss",
      normal_line = "yS",
      normal_cur_line = "ySS",
      visual = "s",
      visual_line = "gS",
      delete = "dx",
      change = "cx",
  },
})

--require('flit').setup {
--  keys = { f = 'f', F = 'F', t = 't', T = 'T' },
--  -- A string like "nv", "nvo", "o", etc.
--  labeled_modes = "v",
--  multiline = true,
--  -- Like `leap`s similar argument (call-specific overrides).
--  -- E.g.: opts = { equivalence_classes = {} }
--  opts = {}
--}
