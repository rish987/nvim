local util = require"config_util"
local telescope = require("telescope")
local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local action_state = require "telescope.actions.state"

local gd = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  local dir = require"lspconfig".util.find_git_ancestor(selection.path) or vim.fn.fnamemodify(selection.path, ":p:h")
  print("changed directory to " .. dir)
  --require("telescope.actions").close(prompt_bufnr)
  -- Depending on what you want put `cd`, `lcd`, `tcd`
  vim.cmd(string.format("silent tcd %s", dir))
end

telescope.setup {
  defaults = {
    -- ....
  },
  pickers = {
    oldfiles = {
      mappings = {
        n = {
          ["gd"] = gd,
          ["cd"] = function(prompt_bufnr)
            local selection = require("telescope.actions.state").get_selected_entry()
            local dir = vim.fn.fnamemodify(selection.path, ":p:h")
            --require("telescope.actions").close(prompt_bufnr)
            -- Depending on what you want put `cd`, `lcd`, `tcd`
            vim.cmd(string.format("silent tcd %s", dir))
          end
        }
      }
    },
  }
}
vim.keymap.set("n", "<leader>fp", function() builtin.planets() end)
vim.keymap.set("n", "<leader>ff", function() builtin.find_files() end)
vim.keymap.set("n", "<leader>fg", function() builtin.live_grep() end)
vim.keymap.set("n", "<leader>fb", function() builtin.buffers() end)
vim.keymap.set("n", "<leader>fh", function() builtin.help_tags() end)
vim.keymap.set("n", "<leader>fc", function() builtin.command_history() end)
vim.keymap.set("n", "<leader>f/", function() builtin.search_history() end)
vim.keymap.set("n", "<leader>fo", function() builtin.oldfiles() end)
vim.keymap.set("n", "<leader>fs", function() builtin.lsp_dynamic_workspace_symbols() end)

-- create a new tab, open oldfiles picker, :tcd to git directory of file, and open a new terminal for the tab
vim.keymap.set("n", "<leader>Tf", function()
  vim.cmd"tabnew"
  builtin.oldfiles({
  attach_mappings = function(prompt_bufnr, map)
    actions.select_default:enhance({
      post = function(prompt_bufnr)
          gd(prompt_bufnr)
          vim.cmd"ToggleTermNew"
          vim.cmd"ToggleTerm"
        end})
    return true
  end
}) end)

local z_utils = require("telescope._extensions.zoxide.utils")

-- Configure the extension
telescope.setup({
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
})

-- Load the extension
telescope.load_extension('zoxide')

-- Add a mapping
vim.keymap.set("n", "<leader>fz", telescope.extensions.zoxide.list)
