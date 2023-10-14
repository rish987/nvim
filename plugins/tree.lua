return {
  {
    'nvim-tree/nvim-tree.lua',
    -- OR setup with some options
    opts = {
      sort_by = "case_sensitive",
      view = {
        width = 30,
      },
      renderer = {
        group_empty = true,
      },
      filters = {
        dotfiles = true,
      },
    },
  }
}
