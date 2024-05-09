local M = {}

local dir = vim.g.StartedByNvimTask and "nvim-task-nested" or "nvim-task"
local root_dir = vim.fn.stdpath("data") .. "/" .. dir
vim.fn.mkdir(root_dir, "p")

local get_sessiondir = function()
  return dir .. "/sessions"
end

local state_file = root_dir .. "/nvim-task-state.json"

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
--

local curr_test
local data_file = root_dir .. "/nvim-task.json"
local tests_data = vim.fn.filereadable(data_file) ~= 0 and vim.fn.json_decode(vim.fn.readfile(data_file)) or {}
-- TODO save/load from file

local function set_test_data(test, value)
  local curr_data = tests_data[test] or {}

  curr_data = vim.tbl_extend("keep", value, curr_data)
  tests_data[test] = curr_data

  local json = vim.fn.json_encode(tests_data)
  vim.fn.writefile({json}, data_file)
end

local function del_test_data(test)
  tests_data[test] = nil

  local json = vim.fn.json_encode(tests_data)
  vim.fn.writefile({json}, data_file)
end

local templates = {
  ["nvim"] = {
    builder = function(params)
      return {
        cmd = { "nvim" },
        args = {
          "--cmd", 'let g:StartedByNvimTask = "true"',
          "--cmd", ('let g:NvimTaskStateFile = "%s"'):format(state_file),
          "--cmd", ('let g:NvimTaskSessionDir = "%s"'):format(params.dir),
          "--cmd", ('let g:NvimTaskSession = "%s"'):format(params.sess),
        },
        strategy = "toggleterm",
        components = {
          "default",
        },
      }
    end,
  },
}

local curr_task

local a = require"plenary.async"
local a_util = require"plenary.async.util"

local function _wait_for_autocmd(cmds, callback)
	vim.api.nvim_create_autocmd(cmds, { callback = callback, once = true })
end

local wait_for_autocmd = a.wrap(_wait_for_autocmd, 2)

local function curr_test_data()
  local test_data = tests_data[curr_test]
  return test_data
end

local function get_curr_test_win()
  if not curr_task then return nil end

  local win = curr_task.strategy.term.window
  -- the session may currently be un-toggled
  if not vim.api.nvim_win_is_valid(win) then return nil end

  return win
end


local function test_is_open()
  return vim.api.nvim_get_current_win() == get_curr_test_win() and vim.fn.mode() == "t"
end

local recording_to_save

--- TODO make async
M.abort_curr_task = function (cb)
  if curr_task then
    a.run(function()
      local was_open = test_is_open()
      curr_task:stop()
      curr_task:dispose()
      local term = curr_task.strategy.term
      curr_task = nil

      print"task aborted"

      -- FIXME somehow properly wait for the task above to actually exit
      a_util.scheduler()
      term:close()
      if was_open then
        a_util.sleep(50)
      end
      -- the old task may have saved a new session, if so update curr_session to use that one next time
      local reset_sess = nvt_conf.read_data(state_file).reset_sess
      if reset_sess then
        curr_test = reset_sess -- name the test after whatever the session was named under
        set_test_data(curr_test, {sess = reset_sess, recording = recording_to_save})
      end

      nvt_conf.erase_data(state_file, "reset_sess")

      require"recorder".abortPlayback(true)
      recording_to_save = nil

      if cb then cb() end
    end, function() end)
    return true
  end
  return false
end

vim.api.nvim_create_autocmd("QuitPre", { -- makes sure that the last session state is saved before quitting
  callback = function(_)
    M.abort_curr_task()
  end,
})
-- vim.keymap.set("n", "<leader><leader>", function()
--   vim.cmd.rshada({bang = true})
--   print("reset sess value:", vim.g.NVIM_TASK_RESET_SESS)
-- end)
local sess_leader = vim.g.StartedByNvimTask and "<C-A-x>" or "<C-x>"
local sess_mappings = {
  play_recording_shortcut = "<tab>",
  restart_session = sess_leader .. "r",
  exit_session = sess_leader .. "x",
  duplicate_session = sess_leader .. "d",
  delete_session = sess_leader .. "D",
}

local function maybe_play_recording()
  local sess_data = curr_test_data()
  if sess_data and vim.fn.reg_recording() == "" and sess_data.recording then
    require"recorder".playRecording()
    return
  end
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(sess_mappings.play_recording_shortcut, true, true, true), "n")
end

-- TODO status line indicator for current recording and keymap to clear recording

local function task_cb (task)
  curr_task = task
  local buf = task.strategy.term.buffer
  vim.keymap.set("t", sess_mappings.play_recording_shortcut, maybe_play_recording, {buffer = buf})
  vim.keymap.set("t", sess_mappings.exit_session, function () M.abort_curr_task() end, {buffer = buf})
  vim.keymap.set("t", sess_mappings.restart_session, function () M.restart() end, {buffer = buf})
  -- vim.keymap.set("n", sess_mappings.duplicate_session, function () vim.cmd"startinsert" end, {buffer = buf})

  nvt_conf.erase_data(state_file, "abort_temp_save")
end

-- recording started in terminal?
local started_recording = false

local reg_override = "t"

vim.api.nvim_create_autocmd("User", {
  pattern = "NvimRecorderPlay",
  callback = function (_)
    if test_is_open() then
      local sess_data = curr_test_data()
      if sess_data.recording then
        vim.fn.setreg(reg_override, vim.api.nvim_replace_termcodes(sess_data.recording, true, true, true), "c")
        require"recorder".setRegOverride(reg_override)
      end
    end
  end
})

vim.api.nvim_create_autocmd("User", {
  pattern = "NvimRecorderRecordStart",
  callback = function (_)
    if test_is_open() then
      started_recording = true
      require"recorder".setRegOverride(reg_override)
    end
  end
})

vim.api.nvim_create_autocmd("User", {
  pattern = "NvimRecorderRecordEnd",
  callback = function (data)
    if started_recording --[[ and sess_is_open() ]] then
      recording_to_save = data.data.recording
    end
    started_recording = false
  end
})

local templates_registered = false

local function _new_nvim_task(test)
  local overseer = require("overseer")
  if not test then test = curr_test or nvt_conf.temp_sessname end

  curr_test = test
  print("loading test:", test)

  if not templates_registered then
    for name, template in pairs(templates) do
      template.name = name
      overseer.register_template(template)
    end

    templates_registered = true
  end

  overseer.run_template({name = "nvim", params = {sess = test, dir = get_sessiondir()}}, task_cb)
end

local function new_nvim_task(sess)
  if not M.abort_curr_task(function() _new_nvim_task(sess) end) then
    _new_nvim_task(sess)
  end
end

function M.sess_picker()
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local finders = require "telescope.finders"
  local make_entry = require "telescope.make_entry"
  local pickers = require "telescope.pickers"
  local conf = require("telescope.config").values

  local results = {}

  for test, _ in pairs(tests_data) do
    if test ~= nvt_conf.temp_sessname then
      table.insert(results, test)
    end
  end

  if vim.tbl_isempty(results) then
    vim.notify("No saved tests", vim.log.levels.WARN)
    return
  end

  local opts = {}

  return pickers
    .new({}, {
      prompt_title = string.format("Choose test (curr: %s)", curr_test or "[NONE]"),
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
          new_nvim_task(selection.value)
        end)

        return true
      end,
    })
end

function M.restart()
  new_nvim_task()
end

function M.save_restart()
  vim.cmd("write")
  M.restart()
end

function M.blank_sess()
  nvt_conf.write_data(state_file, {abort_temp_save = true})

  if nvt_conf.session_exists(nvt_conf.temp_sessname, get_sessiondir()) then
    require"resession".delete(nvt_conf.temp_sessname, { dir = get_sessiondir() })
    del_test_data(nvt_conf.temp_sessname)
  end

  new_nvim_task(nvt_conf.temp_sessname)
end

vim.keymap.set("n", "<leader>W", function () M.save_restart() end)
vim.keymap.set("n", "<leader>X", function () M.restart() end)
vim.keymap.set("n", "<leader>xx", function () M.abort_curr_task() end)
vim.keymap.set("n", "<leader>xf", function () M.sess_picker():find() end)
vim.keymap.set("n", "<leader>xb", function () M.blank_sess() end)

return M

-- TODO mapping to open telescope to select explicitly saved sessions (under cwd)
-- TODO mapping to clear saved session

-- vim.keymap.set("n", "<leader>tc", function () run_template("check", {}) end)
-- vim.keymap.set("n", "<leader>to", function () run_only(vim.fn.input("enter constant names (comma-separated, no whitespace): ")) end)
-- vim.keymap.set("v", "<leader>to", function () run_only(region_to_text()) end)
-- vim.keymap.set("n", "<leader>tO", function () only_picker():find() end)
-- vim.keymap.set("n", "<leader>tf", function () transfile_picker():find() end)
-- vim.keymap.set("n", "<leader>tq", function () abort_curr_task() end)
-- vim.keymap.set("n", "<leader>t<Tab>", function () resume_prev_template() end)
