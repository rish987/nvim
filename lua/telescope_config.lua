local util = require"config_util"
local telescope = require("telescope")
local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local action_state = require "telescope.actions.state"

require("telescope-tabs").setup {
    entry_formatter = function(tab_id, buffer_ids, file_names, file_paths, is_current)
        local tab_name = require("tabby.feature.tab_name").get(tab_id)
        return string.format("%d: %s%s ", tab_id, tab_name, is_current and " <" or "")
    end,
    entry_ordinal = function(tab_id, buffer_ids, file_names, file_paths, is_current)
       return require("tabby.feature.tab_name").get(tab_id)
    end
}

telescope.setup {
  defaults = {
    -- ....
  },
  pickers = {
    oldfiles = {
      mappings = {
        n = {
        }
      }
    },
  },
  extensions = {
    zoxide = {
      mappings = {
        default = {
          action = function(selection)
            vim.cmd.tcd(selection.path)
          end
        },
        ["<C-t>"] = {
          action = function(selection)
            vim.cmd.tabnew()
            vim.cmd.tcd(selection.path)
          end,
        },
      },
    },
  },
}

telescope.load_extension('zoxide')

vim.keymap.set("n", "<leader>fp", function() builtin.planets() end)
vim.keymap.set("n", "<leader>ff", function() builtin.find_files() end)
vim.keymap.set("n", "<leader>fg", function() builtin.live_grep() end)
vim.keymap.set("n", "<leader>fb", function() builtin.buffers() end)
vim.keymap.set("n", "<leader>fh", function() builtin.help_tags() end)
vim.keymap.set("n", "<leader>fc", function() builtin.command_history() end)
vim.keymap.set("n", "<leader>f/", function() builtin.search_history() end)
vim.keymap.set("n", "<leader>fo", function() builtin.oldfiles() end)
vim.keymap.set("n", "<leader>fs", function() builtin.lsp_dynamic_workspace_symbols() end)

vim.keymap.set("n", "<leader>fz", telescope.extensions.zoxide.list)
vim.keymap.set("n", "<leader>ft", telescope.extensions["telescope-tabs"].list_tabs)
