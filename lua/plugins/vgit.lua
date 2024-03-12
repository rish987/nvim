return {
  "tanvirtin/vgit.nvim",
  opts = {
    keymaps = {
      ['n <leader>dh'] = function() require('vgit').buffer_hunk_preview() end,
      ['n <leader>db'] = function() require('vgit').buffer_blame_preview() end,
    },
    settings = {
      live_blame = {
        enabled = false
      },
      live_gutter = {
        enabled = false
      }
    }
  }
}
