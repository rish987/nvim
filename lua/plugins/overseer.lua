return {
  'stevearc/overseer.nvim',
  opts = {},
  lazy = false, -- FIXME this is so that exrc shim doesn't make the mapping below buffer-local;
                -- need some flag to detect if within lazy require call (and abort vim.keymap override if so)
  keys = {
    { "<leader>T", "<cmd>OverseerToggle<cr>", desc = "" },
  }
}
