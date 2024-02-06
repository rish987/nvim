return {
  {
    'nvim-tree/nvim-tree.lua',
    -- OR setup with some options
    opts = {
      sort_by = "case_sensitive",
      view = {
        width = 80,
      },
      renderer = {
        group_empty = true,
      },
      filters = {
        dotfiles = true,
        -- git_ignored = false,
      },
      update_focused_file = {
        enable = true
      },
    },
    init = function ()
      vim.api.nvim_create_autocmd({"TabNew", "VimEnter"},
      {
        callback = function () require"nvim-tree.api".tree.toggle({focus = false}) end,
      })
      -- vim.api.nvim_create_autocmd({"BufEnter"},
      -- {
      --   callback = function () require"nvim-tree.api".tree.collapse_all(true) end,
      -- })
      vim.api.nvim_create_autocmd({"DirChanged"},
      {
        callback = function (info) require"nvim-tree.api".tree.change_root(info.file) end,
      })
    end
  }
}
