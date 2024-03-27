return {
  {
    "stevearc/resession.nvim",
    opts = {
      buf_filter = function(bufnr)
        -- filter out infoview windows that start with "lean:"
        if vim.startswith(vim.api.nvim_buf_get_name(bufnr), "lean:") then return false end
        for _, ft in ipairs(require"config_util".exclude_filetypes) do
          if vim.bo[bufnr].ft == ft then return false end
        end
        return true
      end,
      -- good periodically save your sessions for the time being since this plugin tends to freeze
      -- while editing Lean 4 files :(
      autosave = {
        enabled = false,
        interval = 60,
        notify = false,
      },
      extensions = {
        ["nvim-task"] = {
          -- these args will get passed in to M.config()
        },
      },
    },
    init = function ()
      if not vim.g.StartedByNvimTask  then
        require"resession".add_hook("post_load", function ()
          if not require"nvim-tree.view".is_visible()then
            require"nvim-tree.api".tree.toggle({focus = false})
          end
        end)
      else
        -- require"nvim-task".open_messageview()
      end

      vim.keymap.set('n', '<leader>sss', require"resession".save)
      vim.keymap.set('n', '<leader>ssl', require"resession".load)
      vim.keymap.set('n', '<leader>ssd', require"resession".delete)
    end
  }
}
