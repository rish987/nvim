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
      if not vim.g.started_by_firenvim == true and not vim.g.StartedByNvimTask then
        vim.api.nvim_create_autocmd({"TabNew", "VimEnter"},
        {
          callback = function ()
            if not require"nvim-tree.view".is_visible() then
              require"nvim-tree.api".tree.toggle({focus = false})
            end
          end,
        })
      end
      -- autoclose tree
      vim.api.nvim_create_autocmd("QuitPre", {
        callback = function()
          local tree_wins = {}
          local floating_wins = {}
          local wins = vim.api.nvim_tabpage_list_wins(0)
          for _, w in ipairs(wins) do
            local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
            if bufname:match("NvimTree_") ~= nil then
              table.insert(tree_wins, w)
            end
            if vim.api.nvim_win_get_config(w).relative ~= '' then
              table.insert(floating_wins, w)
            end
          end
          -- print( #wins , #floating_wins , #tree_wins )
          if 1 == #wins - #floating_wins - #tree_wins then
            -- Should quit, so we close all invalid windows.
            for _, w in ipairs(tree_wins) do
              vim.api.nvim_win_close(w, true)
            end
          end
        end
      })
      -- vim.api.nvim_create_autocmd({"BufEnter"},
      -- {
      --   callback = function () require"nvim-tree.api".tree.collapse_all(true) end,
      -- })
      vim.api.nvim_create_autocmd({"DirChanged"},
      {
        callback = function (info)
            require"nvim-tree.api".tree.change_root(info.file)
          end,
      })
    end
  }
}
