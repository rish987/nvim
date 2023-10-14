return {
  {
    "stevearc/resession.nvim",
    opts = {
      buf_filter = function(bufnr)
        -- filter out infoview windows that start with "lean:"
        return not vim.startswith(vim.api.nvim_buf_get_name(bufnr), "lean:")
      end,
      -- good periodically save your sessions for the time being since this plugin tends to freeze
      -- while editing Lean 4 files :(
      autosave = {
        enabled = false,
        interval = 60,
        notify = false,
      },
    },
    init = function ()
      vim.keymap.set('n', '<leader>sss', require"resession".save)
      vim.keymap.set('n', '<leader>ssl', require"resession".load)
      vim.keymap.set('n', '<leader>ssd', require"resession".delete)
    end
  }
}
