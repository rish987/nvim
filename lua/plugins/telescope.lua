local util = require"config_util"
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
      vim.keymap.set("n", "<leader>f?", function() require("telescope.builtin").planets({show_pluto = true, show_moon = true}) end)
      vim.keymap.set("n", "<leader>ff", function() require("telescope.builtin").find_files() end)
      vim.keymap.set("n", "<leader>fg", function() require("telescope").extensions.egrepify.egrepify {} end)
      vim.keymap.set("n", "<leader>fG", function() require("telescope").extensions.egrepify.egrepify {search_dirs = {util.lazypluginpath, util.devpluginpath}} end)
      vim.keymap.set("n", "<leader>fb", function() require("telescope.builtin").buffers() end)
      vim.keymap.set("n", "<leader>fh", function() require("telescope.builtin").help_tags({
        -- attach_mappings = function(_)
        --   local actions = require "telescope.actions"
        --   local action_state = require "telescope.actions.state"
        --   actions.select_default:replace(function()
        --     local selection = action_state.get_selected_entry()
        --     vim.cmd("FloatingHelp " .. selection.display)
        --   end)
        --
        --   return true
        -- end,
      }) end)
      vim.keymap.set("n", "<leader>f:", function() require("telescope.builtin").command_history() end)
      vim.keymap.set("n", "<leader>f/", function() require("telescope.builtin").search_history() end)
      vim.keymap.set("n", "<leader>fo", function() require("telescope.builtin").oldfiles({cwd_only = true}) end)
      vim.keymap.set("n", "<leader>fO", function() require("telescope.builtin").oldfiles({cwd_only = false}) end)
      vim.keymap.set("n", "<leader>fs", function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end)
      vim.keymap.set("n", "<leader>f<Tab>", function() require("telescope.builtin").resume() end)
      vim.keymap.set("n", "<leader>fp", function() require("telescope.builtin").pickers() end)
      vim.keymap.set("n", "<leader>fr", function() require'telescope'.extensions.repo.list{} end)
      vim.keymap.set("n", "<leader>fn", "<Cmd>Noice telescope<CR>")
      vim.keymap.set("n", "<leader>fl", function() require'telescope'.extensions.repo.list
        {
          search_dirs = {
            util.lazypluginpath,
          },
        } end)
      vim.keymap.set("n", "<leader>fu", function() require'telescope'.extensions.undo.undo{
        side_by_side = true,
        diff_context_lines = 5,
        mappings = {
          normal = {
            ["<cr>"] = require("telescope-undo.actions").restore,
          }
        }
      } end)

      vim.keymap.set("n", "<leader>fm", "<Cmd>Noice telescope<CR>")

      vim.keymap.set("n", "<leader>fz", require("telescope").extensions.zoxide.list)
      vim.keymap.set("n", "<leader>ft", require("telescope").extensions["telescope-tabs"].list_tabs)
      vim.keymap.set("n", "<leader>fy", require("telescope").extensions.yank_history.yank_history)
    end,
    config = function (_, opts)
      local telescope = require"telescope"
      telescope.setup(opts)

      telescope.load_extension'zoxide'
      telescope.load_extension'egrepify'
      telescope.load_extension'repo'
      telescope.load_extension'noice'
      telescope.load_extension'yank_history'
    end,
    opts = function ()
      local actions = require"telescope.actions"
      return {
        defaults = {
          cache_picker = {
            num_pickers = 100,
          },
          mappings = {
            n = {
              ["K"] = function() actions.select_default() end,
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
                    actions.select_default(prompt_bufnr)
                  end
                }
              end,

              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,

              ["<C-u>"] = actions.preview_scrolling_up,
              ["<C-d>"] = actions.preview_scrolling_down,

              ["<C-p>"] = actions.results_scrolling_up,
              ["<C-n>"] = actions.results_scrolling_down,
            },
            i = {
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,

              ["<C-u>"] = actions.preview_scrolling_up,
              ["<C-d>"] = actions.preview_scrolling_down,

              ["<C-p>"] = actions.results_scrolling_up,
              ["<C-n>"] = actions.results_scrolling_down,
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
          repo = {
            list = {
              -- fd_opts = {
              --   "--no-ignore-vcs",
              -- },
              search_dirs = {
                "~/projects",
                "~/plugins",
                "~/.config",
              },
            },
          },
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
    end,
  },
  {
    "LukasPietzschmann/telescope-tabs",
    opts = {
      -- entry_formatter = function(tab_id, buffer_ids, file_names, file_paths, is_current)
      --   local tab_name = require("tabby.feature.tab_name").get(tab_id)
      --   return string.format("%d: %s%s ", tab_id, tab_name, is_current and " <" or "")
      -- end,
      -- entry_ordinal = function(tab_id, buffer_ids, file_names, file_paths, is_current)
      --   return require("tabby.feature.tab_name").get(tab_id)
      -- end
    }
  },
  "jvgrootveld/telescope-zoxide",
  "cljoly/telescope-repo.nvim",
  "debugloop/telescope-undo.nvim",
}
