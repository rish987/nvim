local M = {}

-- use a different session-saving directory for nested instances
local dir = vim.g.StartedByNvimTask and "nvim-task-nested" or "nvim-task"
local root_dir = vim.fn.stdpath("data") .. "/" .. dir
vim.fn.mkdir(root_dir, "p")

local sessiondir = dir .. "/sessions"

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

local metadata_key = "__NvimTaskData"

local data_file = root_dir .. "/nvim-task.json"
local tests_data = vim.fn.filereadable(data_file) ~= 0 and vim.fn.json_decode(vim.fn.readfile(data_file)) or {[metadata_key] = {}}
local curr_test = tests_data[metadata_key].curr_test

local function set_test_data(test, value)
  local curr_data = tests_data[test] or {}

  curr_data = vim.tbl_extend("keep", value, curr_data)
  tests_data[test] = curr_data

  local json = vim.fn.json_encode(tests_data)
  vim.fn.writefile({json}, data_file)
end

local function set_test_metadata(value)
  set_test_data(metadata_key, value)
end

local function del_test_data(test)
  tests_data[test] = nil

  local json = vim.fn.json_encode(tests_data)
  vim.fn.writefile({json}, data_file)
end

local socket_i = 0
local child_sock = "/tmp/nvimtasksocketchild" .. socket_i
while vim.fn.filereadable(child_sock) ~= 0 do
  socket_i = socket_i + 1
  child_sock = "/tmp/nvimtasksocketchild" .. socket_i
end

local sock = vim.call("serverstart")

local templates = {
  ["nvim"] = {
    builder = function(params)
      return {
        cmd = { "nvim" },
        args = {
          "--cmd", 'let g:StartedByNvimTask = "true"',
          "--cmd", ('let g:NvimTaskSessionDir = "%s"'):format(sessiondir), -- use parent sessiondir
          "--cmd", ('let g:NvimTaskTest = "%s"'):format(params.test),
          "--cmd", ('let g:NvimTaskParentSock = "%s"'):format(sock),
          "--listen", child_sock
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

local function set_curr_test(test)
  curr_test = test
  set_test_metadata({curr_test = curr_test})
end

--- TODO make async
M.abort_curr_task = function (cb)
  if curr_task then
    a.run(function()
      -- vim.fn.chanclose(curr_task.sock)
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

      require"recorder".abortPlayback(true)

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
local test_leader = vim.g.StartedByNvimTask and "<C-A-x>" or "<C-x>"
local test_mappings = {
  play_recording_shortcut = "<tab>",
  restart_test = test_leader .. "r",
  exit_test = test_leader .. "x",
  blank_test = test_leader .. "b",
  duplicate_test = test_leader .. "d",
  delete_test = test_leader .. "D",
  find_test = test_leader .. "f",
}

local function maybe_play_recording()
  local sess_data = curr_test_data()
  if sess_data and vim.fn.reg_recording() == "" and sess_data.recording then
    require"recorder".playRecording()
    return
  end
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(test_mappings.play_recording_shortcut, true, true, true), "n")
end

function M.set_child_sock()
  curr_task.sock = vim.fn.sockconnect("pipe", child_sock, {rpc = true})
  -- print("child sock:", curr_task.sock)
end

-- TODO status line indicator for current recording and keymap to clear recording
local function run_child(code, args)
  args = args or {}
  return vim.fn.rpcrequest(curr_task.sock, "nvim_exec_lua", code, args)
end

local function task_cb (task)
  curr_task = task
  local buf = task.strategy.term.bufnr
  vim.keymap.set("t", test_mappings.play_recording_shortcut, maybe_play_recording, {buffer = buf})
  vim.keymap.set("t", test_mappings.exit_test, function () M.abort_curr_task() end, {buffer = buf})
  vim.keymap.set("t", test_mappings.restart_test, function () M.restart() end, {buffer = buf})
  vim.keymap.set("t", test_mappings.blank_test, function () M.blank_sess() end, {buffer = buf})
  -- vim.keymap.set("t", test_mappings.duplicate_test, function () run_child(print"HERE") end, {buffer = buf})
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
      run_child("require'nvim-task.config'.save_session()")
      run_child("require'nvim-task.config'.enable_calltrace()")
    end
  end
})

vim.api.nvim_create_autocmd("User", {
  pattern = "NvimRecorderRecordEnd",
  callback = function (data)
    if started_recording --[[ and sess_is_open() ]] then
      run_child("require'nvim-task.config'.disable_calltrace()")
      vim.ui.input({ prompt = "Test name" }, function(name)
        if name then
          local get_session_file = require"resession.util".get_session_file
          local saved_file = get_session_file(nvt_conf.saved_test_name, sessiondir)
          local new_file = get_session_file(name, sessiondir) -- name the session after the test
          print("renaming session:", saved_file, new_file)
          vim.loop.fs_rename(saved_file, new_file)
          vim.print(run_child(("return require'nvim-task.config'.record_finish(%s)"):format(name)))

          set_curr_test(name)
          set_test_data(curr_test, {sess = name, recording = vim.fn.keytrans(data.data.recording)})
        end
      end)
    end
    started_recording = false
  end
})

local templates_registered = false

local function _new_nvim_task(test)
  local overseer = require("overseer")
  if not test then test = curr_test or nvt_conf.temp_test_name end

  print("loading test:", test)
  set_curr_test(test)

  if not templates_registered then
    for name, template in pairs(templates) do
      template.name = name
      overseer.register_template(template)
    end

    templates_registered = true
  end

  overseer.run_template({name = "nvim", params = {test = test}}, task_cb)
end

local function new_nvim_task(test)
  if not M.abort_curr_task(function() _new_nvim_task(test) end) then
    _new_nvim_task(test)
  end
end

function M.test_picker()
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local finders = require "telescope.finders"
  local make_entry = require "telescope.make_entry"
  local pickers = require "telescope.pickers"
  local conf = require("telescope.config").values

  local results = {}

  for test, _ in pairs(tests_data) do
    if test ~= nvt_conf.temp_test_name and test ~= metadata_key then
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

function M.pick_test()
  local picker = M.test_picker()
  if picker then picker:find() end
end

function M.restart()
  new_nvim_task()
end

function M.save_restart()
  vim.cmd("write")
  M.restart()
end

function M.blank_sess()
  if curr_task then
    run_child("require'nvim-task.config'.abort_temp_save()")
  end

  if nvt_conf.session_exists(nvt_conf.temp_test_name, sessiondir) then
    require"resession".delete(nvt_conf.temp_test_name, { dir = sessiondir })
    del_test_data(nvt_conf.temp_test_name)
  end

  new_nvim_task(nvt_conf.temp_test_name)
end

vim.keymap.set("n", "<leader>W", M.save_restart)
vim.keymap.set("n", test_mappings.restart_test, M.restart)
vim.keymap.set("n", test_mappings.exit_test, M.abort_curr_task)
vim.keymap.set("n", test_mappings.find_test, M.pick_test)
vim.keymap.set("n", test_mappings.blank_test, M.blank_sess)

return M

-- vim.keymap.set("n", "<leader>tc", function () run_template("check", {}) end)
-- vim.keymap.set("n", "<leader>to", function () run_only(vim.fn.input("enter constant names (comma-separated, no whitespace): ")) end)
-- vim.keymap.set("v", "<leader>to", function () run_only(region_to_text()) end)
-- vim.keymap.set("n", "<leader>tO", function () only_picker():find() end)
-- vim.keymap.set("n", "<leader>tf", function () transfile_picker():find() end)
-- vim.keymap.set("n", "<leader>tq", function () abort_curr_task() end)
-- vim.keymap.set("n", "<leader>t<Tab>", function () resume_prev_template() end)
