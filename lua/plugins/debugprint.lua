return {
  "andrewferrier/debugprint.nvim",
  -- Dependency only needed for NeoVim 0.8
  dependencies = {
    "nvim-treesitter/nvim-treesitter"
  },
  create_keymaps = false,
  init = function()
    vim.keymap.set({"n"}, "<leader>DD", ":DeleteDebugPrints<CR>")
  end,
  -- Remove the following line to use development versions,
  -- not just the formal releases
  opts = {
    print_tag = "DBG",
    keymaps = {
      normal = {
        plain_below = "<leader>dd",
        plain_above = "<leader>dD",
        variable_below = "<leader>dq",
        variable_above = "<leader>dQ",
        variable_below_alwaysprompt = nil,
        variable_above_alwaysprompt = nil,
      },
      visual = {
        variable_below = "<Leader>dv",
        variable_above = "<Leader>dV",
      },
    },
    commands = {
        delete_debug_prints = "DeleteDebugPrints",
    },
  },
}
