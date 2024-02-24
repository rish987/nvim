local overseer = require("overseer")
local actions = require "telescope.actions"
local sorters = require "telescope.sorters"
local action_state = require "telescope.actions.state"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
-- local utils = require "telescope.utils"
local conf = require("telescope.config").values

local nvt_conf = require "nvim-task.config"

-- local get_source_files = function()
--   local files = vim.split(vim.fn.glob("**/*.lua"), "\n")
--
--   return files
-- end

-- local function is_win()
--   return package.config:sub(1, 1) == '\\'
-- end
--
-- local function get_path_separator()
--   if is_win() then
--     return '\\'
--   end
--   return '/'
-- end
--
-- local function script_path()
--   local str = debug.getinfo(2, 'S').source:sub(2)
--   if is_win() then
--     str = str:gsub('/', '\\')
--   end
--   return str:match('(.*' .. get_path_separator() .. ')')
-- end
--
-- local config_file = script_path() .. get_path_separator() .. "config.lua"

local function get_dir_prefix()
  return (vim.fn.getcwd()):sub(2):gsub("/", "_")
end

local curr_session

local templates = {
  ["nvim"] = {
    builder = function(params)
      return {
        cmd = { "nvim" },
        args = {
          "--cmd", 'let g:StartedByNvimTask = "true"',
          "--cmd", ('let g:NvimTaskDir = "%s"'):format(get_dir_prefix()),
          "--cmd", ('let g:NvimTaskSession = "%s"'):format(curr_session or "NvimTaskDefault"),
        },
        strategy = "toggleterm",
        components = {
          "default",
        },
      }
    end,
  },
}

local function sess_picker()
  local results = {}

  for _, file in ipairs(vim.fn.split(vim.fn.glob("fixtures/**/*"), "\n")) do
    file = vim.loop.fs_realpath(file)
    table.insert(results, file)
  end

  pickers
    .new({}, {
      prompt_title = string.format("Choose session (curr: %s)", ),
      finder = finders.new_table {
        results = results,
        entry_maker = make_entry.gen_from_file(),
      },
      sorter = sorters.Sorter:new {
        discard = true,

        scoring_function = function(_, _, line)
          return prev_trans[line] and -prev_trans[line] or 0
        end,
      },
      previewer = conf.grep_previewer(),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()

          only_info.file = selection.value
          actions.close(prompt_bufnr)

          run()
        end)

        return true
      end,
    }):find()
end

local curr_task, curr_task_dir

local abort_curr_task = function ()
  if curr_task then
    curr_task:stop()
    curr_task:dispose()
    curr_task = nil
    curr_task_dir = nil
  end
end

local function task_split (task)
  abort_curr_task()

  curr_task = task
  curr_task_dir = vim.fn.getcwd()
end

for name, template in pairs(templates) do
  template.name = name
  overseer.register_template(template)
end

local function start_or_restart()
  if not curr_task or vim.fn.getcwd() ~= curr_task_dir then
    overseer.run_template({name = "nvim"}, task_split)
  else
    curr_task:restart(true)
  end
end

local function save_start_or_restart()
  vim.cmd("write")
  start_or_restart()
end

vim.keymap.set("n", "<leader>W", function () save_start_or_restart() end)
vim.keymap.set("n", "<leader>X", function () start_or_restart() end)
vim.keymap.set("n", "<leader>xx", function () abort_curr_task() end)
vim.keymap.set("n", "<leader>fw", function () sess_picker():find() end)
vim.keymap.set("n", "<leader>xs", function () clear_saved() end)
-- TODO mapping to open telescope to select explicitly saved sessions (under cwd)
-- TODO mapping to clear saved session

-- vim.keymap.set("n", "<leader>tc", function () run_template("check", {}) end)
-- vim.keymap.set("n", "<leader>to", function () run_only(vim.fn.input("enter constant names (comma-separated, no whitespace): ")) end)
-- vim.keymap.set("v", "<leader>to", function () run_only(region_to_text()) end)
-- vim.keymap.set("n", "<leader>tO", function () only_picker():find() end)
-- vim.keymap.set("n", "<leader>tf", function () transfile_picker():find() end)
-- vim.keymap.set("n", "<leader>tq", function () abort_curr_task() end)
-- vim.keymap.set("n", "<leader>t<Tab>", function () resume_prev_template() end)
