local M = {}

-- use a different session-saving directory for nested instances
local dir = vim.g.StartedByNvimTask and "nvim-task-nested" or "nvim-task"
local root_dir = vim.fn.stdpath("data") .. "/" .. dir
vim.fn.mkdir(root_dir, "p")

local sessiondir = dir .. "/sessions"
local testdir = root_dir .. "/tests"
vim.fn.mkdir(testdir, "p")

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
          "--cmd", ('let g:NvimTaskSess = "%s"'):format(params.sess),
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

local finished_playback = false
local finished_playback_restart = false

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
      finished_playback = false
      finished_playback_restart = false

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
  trace_picker = test_leader .. "t",
  edit_test = test_leader .. "e",
}

local function maybe_play_recording()
  if finished_playback_restart then
    M.restart()
    return
  end
  if finished_playback then
    print(("playback finished, restart test or press '%s' again to replay"):format(test_mappings.play_recording_shortcut))
    finished_playback_restart = true
    return
  end
  local sess_data = curr_test_data()
  if sess_data and vim.fn.reg_recording() == "" and sess_data.recording then
    finished_playback = require"recorder".playRecording()
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
  vim.keymap.set("t", test_mappings.edit_test, function () M.abort_curr_task(function () M.edit_curr_test() end) end, {buffer = buf})
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
      -- run_child("require'nvim-task.config'.enable_calltrace()")
    end
  end
})

local sessionload_fmt = [[resession.load(%s, { dir = %s })]] -- session name, directory
local spyon_fmt = [[spy.on(%s, "%s")]] -- table, entry
local spyassert_fmt = [[    assert.spy(%s).was_called_with(%s)]] -- function name, arg list
local feedkeys_fmt = [[    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("%s", true, true, true))]] -- keys from recording

local testfile_fmt = [[
local spy = require('luassert.spy')
local resession = require"resession"

-- load session
%s

-- set all spies
%s

describe("auto-generated test", function()
  it("'%s'", function()
    -- feed keys from recording
%s

    -- test that spies were called
%s
  end)
end)
]]

function M.get_funcpath(obj)
  local modulestr = ([[require"%s"]]):format(obj.module)
  local modulepath = #obj.submodules > 0 and modulestr .. "." .. vim.fn.join(obj.submodules, ".") or modulestr
  return modulepath .. "." .. obj.func, modulepath
end

local function generate_spyons(calltrace, generated)
  for _, obj in ipairs(calltrace) do
    local funcpath, modulepath = M.get_funcpath(obj)
    if not generated[funcpath] then
      generated[funcpath] = spyon_fmt:format(modulepath, obj.func)
    end
    generate_spyons(obj.called, generated)
  end
  return generated
end

local function generate_spyasserts(calltrace, generated, depth)
  for _, obj in ipairs(calltrace) do
    local funcpath = M.get_funcpath(obj)
    local args_string = ""
    for i, arg in ipairs(obj.args) do
      local a_str = vim.inspect(arg) -- TODO make sure that this works if a is a string containing single/double quote characters
      if i ~= #obj.args then
        args_string = args_string .. a_str .. ", "
      else
        args_string = args_string .. a_str
      end
    end
    table.insert(generated, spyassert_fmt:format(funcpath, args_string))
    if depth == 0 then
      table.insert(generated, "") -- insert newline between top-level calls
    end
    generate_spyasserts(obj.called, generated, depth + 1)
  end
  return generated
end

function M.edit_curr_test()
  if not curr_test then return end
  local test_filepath = testdir .. ("/%s_spec.lua"):format(curr_test)

  if nvt_conf.file_exists(test_filepath) then
    vim.cmd("edit " .. test_filepath)
  else
    vim.notify(("No test file for test '%s' exists"):format(curr_test))
  end
end

local function make_test(test)
  local data = tests_data[test]
  local calltrace = nvt_conf.unpatch(data.calltrace)

  local sessionload_str = sessionload_fmt:format(data.sess, sessiondir)
  local spyon_strs = {}
  for _, str in pairs(generate_spyons(calltrace, {})) do
    table.insert(spyon_strs, str)
  end
  local spyon_str = vim.fn.join(spyon_strs, "\n")

  local spyassert_strs = {}
  for _, str in pairs(generate_spyasserts(calltrace, {}, 0)) do
    table.insert(spyassert_strs, str)
  end
  local spyassert_str = vim.fn.join(spyassert_strs, "\n")

  local feedkeys_str = feedkeys_fmt:format(data.recording)

  local test_str = testfile_fmt:format(sessionload_str, spyon_str, test, feedkeys_str, spyassert_str)

  local test_filepath = testdir .. ("/%s_spec.lua"):format(test)
  vim.fn.writefile(vim.fn.split(test_str, "\n"), test_filepath)
  print("wrote", test_filepath)
end

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
          -- TODO check and confirm override if session already exists
          print("renaming session:", saved_file, new_file)
          vim.loop.fs_rename(saved_file, new_file)
          local calltrace_data = run_child(("return require'nvim-task.config'.record_finish(%s)"):format(name))

          set_curr_test(name)
          set_test_data(curr_test, {sess = name, recording = vim.fn.keytrans(data.data.recording), calltrace = calltrace_data})

          make_test(name)
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
  local data = test == nvt_conf.temp_test_name and {sess = nvt_conf.temp_test_name} or tests_data[test]

  print("loading test:", test)
  set_curr_test(test)

  if not templates_registered then
    for name, template in pairs(templates) do
      template.name = name
      overseer.register_template(template)
    end

    templates_registered = true
  end

  overseer.run_template({name = "nvim", params = {sess = data.sess}}, task_cb)
end

local function new_nvim_task(test)
  if not M.abort_curr_task(function() _new_nvim_task(test) end) then
    _new_nvim_task(test)
  end
end

local tracedisp_format_sub = [["%s".%s.%s]]
local tracedisp_format = [["%s".%s]]
local function modfn_to_str(modname, submodnames, fnname)
  if #submodnames == 0 then
    return tracedisp_format:format(modname, fnname)
  end
  return tracedisp_format_sub:format(modname, vim.fn.join(submodnames, "."), fnname)
end

function trace_previewer()
  return require"telescope.previewers".new_buffer_previewer({
    define_preview = function(self, entry)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, true, vim.split("", "\n"))
    end,
  })
end

local function modfn_picker(title, attach_mappings)
  if not curr_task then
    vim.notify("No task is currently running", vim.log.levels.WARN)
    return
  end
  -- TODO async delay until socket is connected

  local finders = require "telescope.finders"
  local pickers = require "telescope.pickers"
  local conf = require("telescope.config").values

  local results = run_child(("return require'nvim-task.config'.get_traceable_fns()"))

  if vim.tbl_isempty(results) then
    vim.notify("No traceable functions", vim.log.levels.WARN)
    return
  end

  local opts = {}

  return pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table {
        results = results,
        entry_maker = function(entry)
          local disp = modfn_to_str(entry.modname, entry.submodnames, entry.fnname)
          return {
            value = entry,
            display = disp,
            ordinal = disp,
          }
        end
      },
      mappings = {
        ["J"] = function() print"HERE" end,
      },
      -- sorter = conf.generic_sorter(opts),
      -- previewer = conf.grep_previewer(opts),
      attach_mappings = attach_mappings,
      sorter = conf.generic_sorter(opts),
      previewer = trace_previewer()
    })
end

local function trace_picker_subcall(toplevel)
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  return modfn_picker(string.format("Choose subcalls to trace for %s",
    nvt_conf.modfun_key(toplevel.modname, toplevel.submodnames, toplevel.fnname, true)),
    function(_, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        print('In subcall picker')
      end)
      return true
    end)
end

function M.trace_picker_toplevel()
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  return modfn_picker(string.format("Choose functions to trace"),
    function(_, map)
    map("n", "K", function()
    end)
    actions.select_default:replace(function()
      local selection = action_state.get_selected_entry()
      vim.schedule(function()
        local subcall_picker = trace_picker_subcall(selection.value)
        if subcall_picker then
          subcall_picker:find()
        end
      end)
    end)
    return true
  end)
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

function M.pick_trace()
  local picker = M.trace_picker_toplevel()
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
vim.keymap.set("n", test_mappings.edit_test, M.edit_curr_test)
vim.keymap.set("n", test_mappings.trace_picker, M.pick_trace)

return M

-- vim.keymap.set("n", "<leader>tc", function () run_template("check", {}) end)
-- vim.keymap.set("n", "<leader>to", function () run_only(vim.fn.input("enter constant names (comma-separated, no whitespace): ")) end)
-- vim.keymap.set("v", "<leader>to", function () run_only(region_to_text()) end)
-- vim.keymap.set("n", "<leader>tO", function () only_picker():find() end)
-- vim.keymap.set("n", "<leader>tf", function () transfile_picker():find() end)
-- vim.keymap.set("n", "<leader>tq", function () abort_curr_task() end)
-- vim.keymap.set("n", "<leader>t<Tab>", function () resume_prev_template() end)
