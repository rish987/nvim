local M = {}

-- use a different session-saving directory for nested instances
local dir = vim.g.StartedByNvimTask and "nvim-task-nested" or "nvim-task"
local root_dir = vim.fn.stdpath("data") .. "/" .. dir
vim.fn.mkdir(root_dir, "p")

local nvt_conf = require "nvim-task.config"
local db = require "nvim-task.db"

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

local a = require"plenary.async"
local strat = require"overseer.strategy.nvt"

local test_leader = vim.g.StartedByNvimTask and "<C-A-x>" or "<C-x>"
local test_leader_manual = test_leader .. test_leader
local test_mappings = {
  restart_test = test_leader .. "r",
  restart_test_auto = test_leader .. "R",
  restart_test_manual = test_leader_manual .. "r",
  restart_test_headless = test_leader .. "<C-r>",
  exit_test = test_leader .. "x",
  blank_test = test_leader .. "b",
  delete_test = test_leader .. "D",
  find_test = test_leader .. "f", -- TODO make mappings in telescope instead to choose between auto/manual/headless
  find_test_auto = test_leader .. "F",
  find_test_manual = test_leader_manual .. "f",
  find_test_headless = test_leader .. "<C-f>",
  trace_picker = test_leader .. "t",
  edit_test = test_leader .. "e",
  -- trace_test = test_leader .. "a",
  toggle = vim.g.StartedByNvimTask and "<C-A-Esc>" or "<A-l>"
}

local def_params = {
  auto = true,
  headless = false,
}

-- TODO status line indicator for current recording and keymap to clear recording

function M.edit_curr_test()
  local curr_test = db.get_tests_metadata().curr_test
  local test_filepath = db.testdir .. ("/%s_spec.lua"):format(curr_test)

  if nvt_conf.file_exists(test_filepath) then
    vim.cmd("edit " .. test_filepath)
  else
    vim.notify(("No test file for test '%s' exists"):format(curr_test))
  end
end

-- local _run_template = a.wrap(require"overseer".run_template, 2)
-- local _wait_sock = a.wrap(function(cb)
--   table.insert(sock_waiters, cb)
-- end, 1)

local function _new_nvt(sname, _params)
  if not sname then
    local meta = db.get_tests_metadata()
    sname = meta.curr_test
    if not _params then
      _params = meta.curr_params
    end
  end

  local params = vim.tbl_extend("keep", _params or {}, def_params)

  params.sname = sname

  if sname == "" then
    print("loading blank test")
  else
    if db.get_tests_data()[sname] then
      print("loading test:", sname)
    else
      if sname ~= nvt_conf.temp_test_name then
        print(("WARNING: test '%s' not found; defaulting to auto-saved test session"):format(sname, nvt_conf.temp_test_name))
      else
        print("loading auto-saved test session")
      end
      sname = nvt_conf.temp_test_name
    end
  end

  require"overseer".run_template({name = "nvt", params = params})
  -- _wait_sock()
end

local function _new_nvim_task(test, params)
  _new_nvt(test, params)
end

local function new_nvim_task(test, params)
  a.run(function()
    _new_nvim_task(test, params)
  end, function() end)
end

function M.test_picker(task_params)
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local finders = require "telescope.finders"
  local make_entry = require "telescope.make_entry"
  local pickers = require "telescope.pickers"
  local conf = require("telescope.config").values

  local results = {}

  for test, _ in pairs(db.get_tests_data()) do
    if test ~= nvt_conf.temp_test_name and test ~= db.metadata_key then
      table.insert(results, test)
    end
  end

  if vim.tbl_isempty(results) then
    vim.notify("No saved tests", vim.log.levels.WARN)
    return
  end

  local opts = {}

  local curr_test = db.get_tests_metadata().curr_test

  return pickers
    .new({}, {
      prompt_title = string.format("Choose test (curr: %s)", curr_test),
      finder = finders.new_table {
        results = results,
        entry_maker = make_entry.gen_from_file(),
      },
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()

          actions.close(prompt_bufnr)
          new_nvim_task(selection.value, task_params)
        end)

        return true
      end,
    })
end

function M.pick_test(params)
  local picker = M.test_picker(params)
  if picker then picker:find() end
end

function M.blank_sess()
  if nvt_conf.session_exists(nvt_conf.temp_test_name, db.sessiondir) then
    require"resession".delete(nvt_conf.temp_test_name, { dir = db.sessiondir })
    db.del_test_data(nvt_conf.temp_test_name)
  end

  new_nvim_task(nvt_conf.temp_test_name)
end

-- vim.keymap.set("n", test_mappings.restart_test, M.restart)
vim.keymap.set("n", test_mappings.exit_test, strat.abort_last_task)
vim.keymap.set("n", test_mappings.find_test, M.pick_test)
vim.keymap.set("n", test_mappings.find_test_manual,
  function ()
    M.pick_test({auto = false})
  end
)
vim.keymap.set("n", test_mappings.blank_test, M.blank_sess)
vim.keymap.set("n", test_mappings.edit_test, M.edit_curr_test)

local last_params

-- vim.keymap.set("n", test_mappings.trace_picker, M.pick_trace)
M.restart = function(params)
  -- TODO get task with the same name (don't want to replace unrelated tasks)
  local task = strat.last_task()
  if not params then
    if task then
      strat.restart_last_task()
    else
      new_nvim_task(nil, last_params)
    end
  else
    if task then
      task:stop()
    end
    new_nvim_task(nil, params)
  end
  last_params = params
end

vim.keymap.set("n", test_mappings.restart_test, M.restart)
vim.keymap.set("n", test_mappings.restart_test_manual,
  function ()
    M.restart({auto = false})
  end
)
vim.keymap.set("n", test_mappings.restart_test_auto,
  function ()
    M.restart({auto = true})
  end
)
vim.keymap.set("n", test_mappings.restart_test_headless,
  function ()
    M.restart({headless = true})
  end
)
M.save_restart = function(params)
  vim.cmd.write()
  M.restart(params)
end
vim.keymap.set("n", "<leader>W", M.save_restart)

function M.toggle_curr_test()
  local task = strat.last_task()
  if task then
    task.strategy:toggle()
  else
    vim.notify(('no tasks currently running'))
  end
end

vim.keymap.set("n", test_mappings.toggle, M.toggle_curr_test)

vim.keymap.set(
  { "n", "o", "x" },
  "<C-n>",
  function ()
    print"HERE 1!"
  end
)

vim.keymap.set(
  { "n", "o", "x" },
  "<C-p>",
  function ()
    -- require('alternate').test()
    print"HERE 2!"
  end
)

return M

-- vim.keymap.set("n", "<leader>tc", function () run_template("check", {}) end)
-- vim.keymap.set("n", "<leader>to", function () run_only(vim.fn.input("enter constant names (comma-separated, no whitespace): ")) end)
-- vim.keymap.set("v", "<leader>to", function () run_only(region_to_text()) end)
-- vim.keymap.set("n", "<leader>tO", function () only_picker():find() end)
-- vim.keymap.set("n", "<leader>tf", function () transfile_picker():find() end)
-- vim.keymap.set("n", "<leader>tq", function () abort_curr_task() end)
-- vim.keymap.set("n", "<leader>t<Tab>", function () resume_prev_template() end)
