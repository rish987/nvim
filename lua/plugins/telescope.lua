local function get_telescope_targets(prompt_bufnr)
  local pick = require"telescope.actions.state".get_current_picker(prompt_bufnr)
  local scroller = require "telescope.pickers.scroller"

  local wininfo = vim.fn.getwininfo(pick.results_win)

  local first = math.max(scroller.top(pick.sorting_strategy, pick.max_results, pick.manager:num_results()), wininfo[1].topline - 1)
  local last = wininfo[1].botline - 1

  local targets = {}
  for row=last,first,-1 do
    local target = {
      wininfo = wininfo[1],
      pos = {row + 1, 1},
      row = row,
      pick = pick
    }
    table.insert(targets, target)
  end
  return targets
end

return {
  {
    "nvim-telescope/telescope.nvim",
    init = function (_)
      vim.keymap.set("n", "<leader>fp", function() require("telescope.builtin").planets() end)
      vim.keymap.set("n", "<leader>ff", function() require("telescope.builtin").find_files() end)
      vim.keymap.set("n", "<leader>fg", function() require("telescope.builtin").live_grep() end)
      vim.keymap.set("n", "<leader>fb", function() require("telescope.builtin").buffers() end)
      vim.keymap.set("n", "<leader>fh", function() require("telescope.builtin").help_tags() end)
      vim.keymap.set("n", "<leader>f:", function() require("telescope.builtin").command_history() end)
      vim.keymap.set("n", "<leader>f/", function() require("telescope.builtin").search_history() end)
      vim.keymap.set("n", "<leader>fo", function() require("telescope.builtin").oldfiles({cwd_only = true}) end)
      vim.keymap.set("n", "<leader>fs", function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end)

      vim.keymap.set("n", "<leader>fz", require("telescope").extensions.zoxide.list)
      vim.keymap.set("n", "<leader>ft", require("telescope").extensions["telescope-tabs"].list_tabs)
    end,
    config = function (_, opts)
      require"telescope".setup(opts)

      require"telescope".load_extension('zoxide')
    end,
    opts = {
      defaults = {
        mappings = {
          n = {
            ["K"] = function() require"telescope.actions".select_default() end,
            ["S"] = function (prompt_bufnr)
              require('leap').leap {
                targets = get_telescope_targets(prompt_bufnr),
                action = function (target)
                  target.pick:set_selection(target.row)
                end
              }
            end,
            ["s"] = function (prompt_bufnr)
              require('leap').leap {
                targets = get_telescope_targets(prompt_bufnr),
                action = function (target)
                  target.pick:set_selection(target.row)
                  require"telescope.actions".select_default(prompt_bufnr)
                end
              }
            end
          }
        },
        color_devicons=true,
        initial_mode = "normal"
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
  },
  {
    "LukasPietzschmann/telescope-tabs",
    opts = {
      entry_formatter = function(tab_id, buffer_ids, file_names, file_paths, is_current)
        local tab_name = require("tabby.feature.tab_name").get(tab_id)
        return string.format("%d: %s%s ", tab_id, tab_name, is_current and " <" or "")
      end,
      entry_ordinal = function(tab_id, buffer_ids, file_names, file_paths, is_current)
        return require("tabby.feature.tab_name").get(tab_id)
      end
    }
  },
  "jvgrootveld/telescope-zoxide",
}