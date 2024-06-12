local jobs = require("overseer.strategy._jobs")
local tts = require("overseer.strategy.toggleterm")
local shell = require("overseer.shell")
local db = require("nvim-task.db")
local nvt_conf = require("nvim-task.config")
local trace = require("nvim-task.trace")

local terminal = require("toggleterm.terminal")

local a = require"plenary.async"
local a_util = require"plenary.async.util"

local task_stack = {}

local function _wait_for_autocmd(cmds, callback)
	vim.api.nvim_create_autocmd(cmds, { callback = callback, once = true })
end

local wait_for_autocmd = a.wrap(_wait_for_autocmd, 2)

local sockfiles_to_strats = {}

local NVTStrategy = {}

-- TODO make configurable
local play_recording_shortcut = vim.g.StartedByNvimTask and "<C-tab>" or "<tab>"
local startstop_recording = vim.g.StartedByNvimTask and "<C-A-f>" or "<C-f>"
local breakpoint_key = vim.g.StartedByNvimTask and "<C-A-e>" or "<C-e>"
local restart_key = vim.g.StartedByNvimTask and "<C-A-x>r" or "<C-x>r"
local abort_key = vim.g.StartedByNvimTask and "<C-A-x>x" or "<C-x>x"

local normalizeKeycodes = function(mapping)
	return vim.fn.keytrans(vim.api.nvim_replace_termcodes(mapping, true, true, true))
end

function NVTStrategy.new(opts)
  local new = tts.new(opts)

  local to_merge = {
    sock_waiters = {},
    sname = opts.sname
  }
  new = vim.tbl_extend("error", new, to_merge)
  setmetatable(new, {__index = NVTStrategy})

  sockfiles_to_strats[opts.sockfile] = new
  return new
end

function NVTStrategy:_reset()
  self.sock = nil
  self.data = db.get_tests_data()[self.sname] or {sess = self.sname}
  self.split_recording = self.data.recording and vim.split(self.data.recording, normalizeKeycodes(breakpoint_key), {plain = true}) or {}
  -- TODO the recording should come pre-split by the nvim-task.recorder module
  self.rem_recording = vim.fn.copy(self.split_recording)
  self.finished_playback = false
  self.finished_playback_restart = false
end

function NVTStrategy:run_child(code, ...)
  if not self.sock then return end
  return vim.fn.rpcrequest(self.sock, "nvim_exec_lua", code, {...})
end

function NVTStrategy:run_child_notify(code, ...)
  if not self.sock then print"ERROR: sock not set yet" return end
  vim.fn.rpcnotify(self.sock, "nvim_exec_lua", code, {...})
end

function NVTStrategy:reset()
  tts.reset(self)

  self:_reset()
end

function NVTStrategy:get_bufnr()
  return tts.get_bufnr(self)
end

function NVTStrategy:restart()
  -- FIXME this is a workaround for:
  -- require"overseer".run_action(self.task, "restart")
  -- since we need to wait for the toggleterm to properly close
  -- so as to avoid the issue where it opens in normal mode
  local was_open = self.term:is_open()

  self.task:stop()
  self.task:reset()

  vim.defer_fn(function()
    self.task:start()
  end, was_open and 100 or 100)
end

function NVTStrategy:abort()
  self.task:stop()
  self.task:dispose()
end

function NVTStrategy.set_child_sock(sockfile)
  local self = sockfiles_to_strats[sockfile]
  if not self then return end

  print('DBG[28]: nvt.lua:101 (after if not self then return end)')
  self.sock = vim.fn.sockconnect("pipe", sockfile, {rpc = true})
  print('DBG[29]: nvt.lua:103 (after self.sock = vim.fn.sockconnect(pipe, soc…)')

  self:run_child_notify("require'nvim-task.config'.load_session(...)", self.sname)
  -- for _, cb in ipairs(self.sock_waiters) do
  --   cb(self.sock)
  -- end
  -- self.sock_waiters = {}
end

local function isRecording() return vim.fn.reg_recording() ~= "" end

local function normal(cmdStr) vim.cmd.normal { cmdStr, bang = true } end

local function a_normal(cmdStr)
	local mode = vim.fn.mode()
	if mode == "i" or mode == "t" then
		vim.cmd.stopinsert()
		if mode == "i" then
			wait_for_autocmd({"InsertLeave"})
		else
			wait_for_autocmd({"TermLeave"})
		end
		a_util.scheduler()
		normal(cmdStr)
		vim.cmd.startinsert()
	else
		normal(cmdStr)
	end
end

local getMacro = function(reg)
	-- Some keys (e.g. <C-F>) have different representations when they are recorded
	-- versus when they are a result of vim.api.nvim_replace_termcodes (for example).
	-- This ensures that whenever we are manually doing something with register contents,
	-- they are always consistent.
	return vim.api.nvim_replace_termcodes(vim.fn.keytrans(vim.fn.getreg(reg)), true, true, true)
end

-- TODO make configurable (and use a better default)
local tempreg = "t"

function NVTStrategy:set_data(data)
  self.data = db.set_test_data(self.sname, data)
end

function NVTStrategy:get_win()
  local win = self.term.window
  -- the session may currently be un-toggled
  if not vim.api.nvim_win_is_valid(win) then return nil end

  return win
end

local _input = a.wrap(vim.ui.input, 2)

-- TODO add a way to auto-pause recording when terminal mode/window is left,
-- and auto-restart (with a notification) after re-entering
function NVTStrategy:_record_toggle()
	if not isRecording() then
		-- NOTE: above autocmd may have set regOverride
		a_normal("q" .. tempreg)
		print("Recording to [" .. tempreg .. "]…")
    self:run_child_notify("require'nvim-task.config'.save_session()")
		return
  end

	a_normal("q")

	local decodedToggleKey = vim.api.nvim_replace_termcodes(startstop_recording, true, true, true)
  -- FIXME only replace termcodes in parts that were actually changed by keytrans (to handle edge case where "<...>" is entered in insert mode)
	local norm_macro = vim.api.nvim_replace_termcodes(vim.fn.keytrans(getMacro(tempreg)), true, true, true)
	local recording = norm_macro:sub(1, -1 * (#decodedToggleKey + 1))

  local name = self.sname
  if name == require"nvim-task.config".temp_test_name then
    name = _input({ prompt = "Test name: " })
  end

  if name then
    local get_session_file = require"resession.util".get_session_file
    local saved_file = get_session_file(nvt_conf.saved_test_name, db.sessiondir)
    local new_file = get_session_file(name, db.sessiondir) -- name the session after the test
    -- TODO check and confirm override if name/session already exists
    print("renaming session:", saved_file, new_file)
    vim.loop.fs_rename(saved_file, new_file)
    self:run_child_notify(("require'nvim-task.config'.record_finish(%s)"):format(name))
    self.sname = name

    self:set_data({sess = name, recording = vim.fn.keytrans(recording)})

    self.finished_playback_restart = true
    print(("press '%s' to restart"):format(play_recording_shortcut))
  end
end

function NVTStrategy:record_toggle()
  a.run(function()
    self:_record_toggle()
  end, function() end)
end

function NVTStrategy:play_recording()
  if #self.rem_recording == 0 then
    print("no recording to play!")
    return
  end

  if self.trace_playback and not self.already_tracing then
    self:run_child("require'nvim-task.config'.calltrace_start()")
    self.already_tracing = true
  end

  local keys = self.rem_recording[1]
  table.remove(self.rem_recording, 1)

  self:run_child("vim.api.nvim_input(...)", keys)
  -- local to_send = vim.api.nvim_replace_termcodes(keys, true, true, true)
  -- vim.fn.chansend(self.chan_id, to_send)
  -- vim.fn.feedkeys(to_send)

  return #self.rem_recording == 0
end

function NVTStrategy:maybe_play_recording()
  if isRecording() then goto feed end

  if self.finished_playback_restart then
    self:restart()
    return
  end

  if self.finished_playback then
    self.finished_playback_restart = true
    if self.trace_playback then
      local calltrace_data = self:run_child("return require'nvim-task.config'.calltrace_end()")
      self:set_data({calltrace = calltrace_data})
      -- make_test(curr_test)
    end

    print(("press '%s' again to restart"):format(play_recording_shortcut))
    return
  end

  if self.rem_recording and #self.rem_recording > 0 then
    self.finished_playback = self:play_recording()
    if self.finished_playback then
      if self.trace_playback then
        print(("playback finished, press '%s' again to capture trace"):format(play_recording_shortcut))
      else
        print("playback finished")
      end
    else
      print(("hit breakpoint (%d remaining)"):format(#self.rem_recording))
    end
    return
  end

  ::feed::
  self:run_child("vim.fn.feedkeys(vim.api.nvim_replace_termcodes(..., true, true, true))", play_recording_shortcut)
end

function NVTStrategy:addBreakPoint(key)
	if isRecording() and vim.fn.reg_recording() == tempreg then
		-- INFO nothing happens, but the key is still recorded in the macro
		print("Macro breakpoint added.")
	else
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), "n")
	end
end

function NVTStrategy:pick_trace()
  a.run(function()
    local results = self:run_child("return require'nvim-task.config'.get_traceable_fns()")
    local traced_calls = trace._trace_picker_toplevel(results, self.data.traced_calls or {})
    self:set_data({traced_calls = traced_calls})
    self:run_child("return require'nvim-task.config'.add_trace_wrappers(...)", nvt_conf.get_whitelist(traced_calls))
    self.term:open()
  end, function() end)
end

function NVTStrategy:start(task)
  self:_reset()

  tts.start(self, task)
  -- TODO check that task.cmd string starts with `nvim`

  local buf = self.term.bufnr
  self.task = task
  table.insert(task_stack, task)
  vim.keymap.set("t", play_recording_shortcut, function() self:maybe_play_recording() end, {buffer = buf})
  vim.keymap.set("t", startstop_recording, function() self:record_toggle() end, {buffer = buf})
  vim.keymap.set("t", breakpoint_key, function() self:addBreakPoint(breakpoint_key) end, {buffer = buf})
  vim.keymap.set("t", restart_key, function() self:restart() end, {buffer = buf})
  vim.keymap.set("t", abort_key, function() self:abort() end, {buffer = buf})

  db.set_test_metadata({curr_test = self.sname})
  -- vim.keymap.set("t", self.opts.exit_test, function () M.abort_curr_task() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.restart_test, function () M.restart() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.blank_test, function () M.blank_sess() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.edit_test, function () M.abort_curr_task(function () M.edit_curr_test() end) end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.trace_test, function () M.restart_trace() end, {buffer = buf})
end

function NVTStrategy.get_task_stack()
  return task_stack
end

function NVTStrategy.last_task()
  return task_stack[#task_stack]
end

function NVTStrategy.abort_last_task()
  local task = NVTStrategy.last_task()
  if task then
    task:stop()
    return
  end
  print(('no tasks currently running'))
end

function NVTStrategy.restart_last_task()
  local task = NVTStrategy.last_task()
  if task then
    task.strategy:restart()
    print(('restarted task "%s"'):format(task.strategy.sname))
    return
  end
  print(('no tasks currently running'))
end

function NVTStrategy:stop()
  for i, _ in ipairs(task_stack) do
    if task_stack[i] == self.task then
      table.remove(task_stack, i)
      break
    end
  end
  self.term:close()
  tts.stop(self)
  print(('aborted task "%s"'):format(self.sname))
end

function NVTStrategy:dispose()
  tts.dispose(self)
end

return NVTStrategy
