local jobs = require("overseer.strategy._jobs")
local tts = require("overseer.strategy.toggleterm")
local shell = require("overseer.shell")
local db = require("overseer.db")
local nvt_conf = require("nvim-task.config")
local trace = require("nvim-task.trace")

local terminal = require("toggleterm.terminal")

local a = require"plenary.async"
local a_util = require"plenary.async.util"

local function _wait_for_autocmd(cmds, callback)
	vim.api.nvim_create_autocmd(cmds, { callback = callback, once = true })
end

local wait_for_autocmd = a.wrap(_wait_for_autocmd, 2)

local socknames_to_strats = {}

local NVTStrategy = {}

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

-- TODO make configurable
local play_recording_shortcut = vim.g.StartedByNvimTask and "<C-tab>" or "<tab>"
local startstop_recording = vim.g.StartedByNvimTask and "<C-A-f>" or "<C-f>"
local breakpoint_key = vim.g.StartedByNvimTask and "<C-A-e>" or "<C-e>"

local normalizeKeycodes = function(mapping)
	return vim.fn.keytrans(vim.api.nvim_replace_termcodes(mapping, true, true, true))
end

function NVTStrategy.new(opts)
  local new = tts.new(opts)
  setmetatable(tts, {__index = NVTStrategy})

  local data = opts.data
  -- TODO the recording should come pre-split by the nvim-task.recorder module
  local rem_recording = split(data.recording, normalizeKeycodes(breakpoint_key))

  local to_merge = {
    data = data,
    rem_recording = rem_recording,
    sock_waiters = {},
    name = data.sess
  }
  new = vim.tbl_extend("error", new, to_merge)

  socknames_to_strats[opts.sockname] = new
  return new
end

function NVTStrategy:reset()
  tts.reset(self)
end

function NVTStrategy:get_bufnr()
  return tts.get_bufnr(self)
end

function NVTStrategy:restart()
  print("FIXME implement restart")
end

function NVTStrategy.set_child_sock(sockfile)
  local self = socknames_to_strats[sockfile]
  if not self then return end

  self.sock = vim.fn.sockconnect("pipe", sockfile, {rpc = true})
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
  db.set_test_data(self.name, data)
end

function NVTStrategy:get_win()
  local win = self.strategy.term.window
  -- the session may currently be un-toggled
  if not vim.api.nvim_win_is_valid(win) then return nil end

  return win
end

-- TODO add a way to auto-pause recording when terminal mode/window is left,
-- and auto-restart (with a notification) after re-entering
function NVTStrategy:record_toggle()
	if not isRecording() then
		-- NOTE: above autocmd may have set regOverride
		a_normal("q" .. tempreg)
		print("Recording to [" .. tempreg .. "]…")
    self:run_child_notify("require'nvim-task.config'.save_session()")
		return
  end

	a_normal("q")

  local recording = getMacro(tempreg)

  vim.ui.input({ prompt = "Test name (empty to override): " }, function(name)
    if name then
      local get_session_file = require"resession.util".get_session_file
      local saved_file = get_session_file(nvt_conf.saved_test_name, db.sessiondir)
      local new_file = get_session_file(name, self.opts.sessiondir) -- name the session after the test
      -- TODO check and confirm override if name/session already exists
      print("renaming session:", saved_file, new_file)
      vim.loop.fs_rename(saved_file, new_file)
      self:run_child_notify(("require'nvim-task.config'.record_finish(%s)"):format(name))
      self.name = name

      self:set_data({sess = name, recording = vim.fn.keytrans(recording)})
    end
  end)
end

function NVTStrategy:run_child(code, ...)
  if not self.sock then return end
  return vim.fn.rpcrequest(self.sock, "nvim_exec_lua", code, {...})
end

function NVTStrategy:run_child_notify(code, ...)
  if not self.sock then return end
  vim.fn.rpcnotify(self.sock, "nvim_exec_lua", code, {...})
end

function NVTStrategy:play_recording()
  if #self.rem_recording == 0 then return end

  if self.trace_playback and not self.already_tracing then
    self:run_child("require'nvim-task.config'.calltrace_start()")
    self.already_tracing = true
  end

  local keys = self.rem_recording[1]
  table.remove(self.rem_recording, 1)

  vim.api.nvim_chan_send(self.chan_id, vim.api.nvim_replace_termcodes(keys, true, true, true))

  return #self.rem_recording == 1
end

function NVTStrategy:maybe_play_recording()
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

    print(("press '%s' again to replay"):format(play_recording_shortcut))
    return
  end

  if self.rem_recording and #self.rem_recording > 0 then
    self.finished_playback = self:play_recording()
    if self.finished_playback and self.trace_playback then
      print(("playback finished, press '%s' again to capture trace"):format(play_recording_shortcut))
    else
      print("playback finished")
    end
    return
  end

  local raw = vim.api.nvim_replace_termcodes(play_recording_shortcut, true, true, true)
  vim.api.nvim_chan_send(self.chan_id, raw)
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
  tts.start(self, task)
  -- TODO check that task.cmd string starts with `nvim`

  local buf = task.strategy.term.bufnr
  vim.keymap.set("t", play_recording_shortcut, function() self:maybe_play_recording() end, {buffer = buf})
  vim.keymap.set("t", startstop_recording, function() self:record_toggle() end, {buffer = buf})
  vim.keymap.set("t", breakpoint_key, function() self:addBreakPoint(breakpoint_key) end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.exit_test, function () M.abort_curr_task() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.restart_test, function () M.restart() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.blank_test, function () M.blank_sess() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.edit_test, function () M.abort_curr_task(function () M.edit_curr_test() end) end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.trace_test, function () M.restart_trace() end, {buffer = buf})
end

function NVTStrategy:stop()
  tts.stop(self)
end

function NVTStrategy:dispose()
  tts.dispose(self)
  self.strategy.term:close()
end

return NVTStrategy
