local db = require("nvim-task.db")
local nvt_conf = require("nvim-task.config")
local trace = require("nvim-task.trace")
local runner = require("nvim-task.runner")

local task_stack = {}

local function _wait_for_autocmd(cmds, callback)
	vim.api.nvim_create_autocmd(cmds, { callback = callback, once = true })
end

local wait_for_autocmd = function(autocmd)
  return require"plenary.async".wrap(_wait_for_autocmd, 2)(autocmd)
end

local IRunner = {}

-- TODO make configurable
local play_recording_shortcut = vim.g.StartedByNvimTask and "<C-tab>" or "<tab>"
local startstop_recording     = vim.g.StartedByNvimTask and "<C-A-f>" or "<C-f>"
local breakpoint_key          = vim.g.StartedByNvimTask and "<C-A-e>" or "<C-e>"
local manual_breakpoint_key   = vim.g.StartedByNvimTask and "<C-A-q>" or "<C-q>"
local restart_key             = vim.g.StartedByNvimTask and "<C-A-x>r" or "<C-x>r"
local abort_key               = vim.g.StartedByNvimTask and "<C-A-x>x" or "<C-x>x"
local toggle_key              = vim.g.StartedByNvimTask and "<C-A-l>" or "<A-l>"

local normalizeKeycodes = function(mapping)
	return vim.fn.keytrans(vim.api.nvim_replace_termcodes(mapping, true, true, true))
end

function IRunner.new(name, opts)
  local new = {
    name = name,
    bufnr = nil,
    msg_bufnr = nil,
    info_bufnr = nil,
    paused_recording = nil,
    opts = opts,
    term = nil,
    runner = nil,
  }

  return setmetatable(new, { __index = IRunner })
end

local function bp_split(recording, bp_keys)
  local split_recording = {}
  local bp_key = bp_keys[1].key
  local manual = bp_keys[1].manual

  local split = vim.split(recording, normalizeKeycodes(bp_key), {plain = true})
  for i, keys in ipairs(split) do
    if bp_keys[2] then
      vim.list_extend(split_recording, bp_split(keys, {unpack(bp_keys, 2)}))
    elseif keys ~= "" then
      table.insert(split_recording, {
        type = "raw",
        keys = keys,
      })
    end

    if i ~= #split then
      table.insert(split_recording, {
        type = "breakpoint",
        manual = manual,
      })
    end
  end

  return split_recording
end

local bp_keys = {
  {
    key = breakpoint_key,
    manual = false
  },
  {
    key = manual_breakpoint_key,
    manual = true
  },
}

function IRunner:_reset() -- FIXME rename (not async)
  self.data = db.get_tests_data()[self.name] or {sess = self.name}
  self.layout = nil
  self.msg_popup = nil
  self.info_popup = nil
  self.paused_recording = nil
  self.nvim_popup = nil
  self.curr_split_recording = nil
  self.is_open = false
  self.win_before = nil
  self.runner = nil
end

function IRunner:reset()
  self:_reset()
end

function IRunner:get_bufnr()
  return self.bufnr
end

local log = require"vim.lsp.log"

function IRunner:is_recording()
  return self.curr_split_recording ~= nil
end

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
		require"plenary.async.util".scheduler()
		normal(cmdStr)
		vim.cmd.startinsert()

    local tries = 0
    while tries < 100 do
      local _mode = vim.fn.mode()
      if _mode == "i" or _mode == "t" then
        break
      end
      require"plenary.async.util".sleep(50)
      tries = tries + 1
    end
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

function IRunner:set_data(data)
  self.data = db.set_test_data(self.name, data)
end

function IRunner:get_win()
  local win = self.window -- TODO set window
  -- the session may currently be un-toggled
  if not vim.api.nvim_win_is_valid(win) then return nil end

  return win
end

local _input = function(opts)
  return require"plenary.async".wrap(vim.ui.input, 2)(opts)
end

function IRunner:_start_record_term()
  a_normal("q" .. tempreg)
end

function IRunner:_get_record_term(key)
	a_normal("q")

	local norm_macro = vim.api.nvim_replace_termcodes(vim.fn.keytrans(getMacro(tempreg)), true, true, true)
  if key then
    local decodedToggleKey = vim.api.nvim_replace_termcodes(key, true, true, true)
    norm_macro = norm_macro:sub(1, -1 * (#decodedToggleKey + 1))
  end

  -- FIXME only replace termcodes in parts that were actually changed by keytrans (to handle edge case where "<...>" is entered in insert mode)
  local recording = vim.fn.keytrans(norm_macro)

  if self.paused_recording then
    recording = self.paused_recording .. recording
    self.paused_recording = nil
  end

  return recording
end

function IRunner:_pause_record_term(key)
  self.paused_recording = self:_get_record_term(key)
end

function IRunner:_end_record_term(key)
  local recorded = self:_get_record_term(key)

  if recorded ~= "" then
    self.curr_split_recording = bp_split(recorded, bp_keys)
  end
end

local function get_recording_string(split_recording, pos)
  local recording_string = ""
  for i, data in ipairs(split_recording) do
    local str = pos == i and '|' or '' -- TODO highlight to better distinguish
    if data.type == "raw" then
      str = str .. data.keys
    elseif data.type == "breakpoint" then
      str = str .. "╳"
    end
    -- if i ~= #split_recording then
    --   str = str .. " "
    -- end
    recording_string = recording_string .. str
  end
  return recording_string
end

-- TODO add a way to auto-pause recording when terminal mode/window is left,
-- and auto-restart (with a notification) after re-entering
function IRunner:_record_toggle(key)
	if not self:is_recording() then
    if not self.data.split_recording then
      self.curr_split_recording = {}
      self:update_info()
      self:run_child_notify("require'nvim-task.config'.save_session()")

      self:_start_record_term()
      vim.notify("Started recording…")
    else
      vim.notify(("TODO implement recording override"))
    end
		return
  end

  self:_end_record_term(key)
  local split_recording = self.curr_split_recording

  local name = self.name
  if name == require"nvim-task.config".temp_test_name then
    name = _input({ prompt = "Test name: " })
  end

  if name then
    local get_session_file = require"resession.util".get_session_file
    local saved_file = get_session_file(nvt_conf.saved_test_name, db.sessiondir)
    local new_file = get_session_file(name, db.sessiondir) -- name the session after the test
    -- TODO check and confirm override if name/session already exists
    vim.notify(("renaming session: %s to %s" ):format(saved_file, new_file))
    vim.loop.fs_rename(saved_file, new_file)
    self:run_child_notify(("require'nvim-task.config'.record_finish(%s)"):format(name))
    self.name = name

    self:set_data({sess = name, split_recording = split_recording})
    print('Recorded: ' .. get_recording_string(split_recording))

    vim.notify(("press '%s' to restart"):format(play_recording_shortcut))
  end

  vim.cmd.startinsert()

  self:_continue_recording()
end

function IRunner:record_toggle(key)
  require"plenary.async".run(function()
    self:_record_toggle(key)
  end, function() end)
end

function IRunner:play_recording()
  -- if self.trace_playback and not self.already_tracing then
  --   self:run_child("require'nvim-task.config'.calltrace_start()")
  --   self.already_tracing = true
  -- end

  local keys_data = self.rem_recording[1]
  table.remove(self.rem_recording, 1)

  self:update_info()

  -- TODO does this work properly with '<' character in recording?
  if keys_data.type == "raw" then
    if keys_data.keys ~= "" then
      self:run_child("vim.api.nvim_input(...)", keys_data.keys)
    end
  -- TODO API call case
  else
    return keys_data
  end
  -- local to_send = vim.api.nvim_replace_termcodes(keys, true, true, true)
  -- vim.fn.chansend(self.chan_id, to_send)
  -- vim.fn.feedkeys(to_send)
end

function IRunner:_continue_recording()
  -- TODO telescope in to find the last type=raw data, set that as the current level
  if self.data.split_recording then
    self.curr_split_recording = {unpack(self.data.split_recording, 1, #self.data.split_recording - 1)}
    self.paused_recording = self.data.split_recording[#self.data.split_recording].keys
  else
    self.curr_split_recording = {}
    self.paused_recording = ""
  end
  self:update_info()
  self:_start_record_term()
end

function IRunner:add_breakpoint(key)
	if self:is_recording() then
    vim.notify(key)
    if key == manual_breakpoint_key then
      vim.notify("added manual breakpoint")
    else
      vim.notify("added breakpoint")
    end
	else
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), "n")
	end
end

function IRunner:spawn()
  require"plenary.async".run(function()
    self.bufnr = vim.api.nvim_create_buf(false, false)
    self.msg_bufnr = vim.api.nvim_create_buf(false, true)
    self.info_bufnr = vim.api.nvim_create_buf(false, true)
    self:ui_start()
    self:update_info()
    self.runner = runner.new(self.data, {bufnr = self.bufnr})
    if self.data.split_recording then
      self:_playback()
      self:_continue_recording()

      if self.runner.error_msg then print("got error message:\n", self.error_msg) end
    end
  end, function() end)
end

function IRunner:update_info()
  if self.opts.headless then return end

  local status = self:is_recording() and "recording..." or "-"
  local status_str = ("status: %s"):format(status)

  local breakpoint_str = ("%s"):format(get_recording_string(self.split_recording,
    #self.split_recording - #self.rem_recording + 1))
  vim.api.nvim_buf_set_text(self.info_bufnr, 0, 0, -1, -1, {status_str, breakpoint_str})
end

function IRunner:open()
  if self.opts.headless then
    print("TODO open headless instance?")
    return
  end

  self.win_before = vim.api.nvim_get_current_win()
  if not self.layout then
    local Popup = require("nui.popup")
    local Layout = require("nui.layout")

    self.nvim_popup = Popup({
      enter = true,
      border = "double",
      bufnr = self.bufnr
    })
    self.msg_popup = Popup({
      border = "single",
      bufnr = self.msg_bufnr
    })
    self.info_popup = Popup({
      border = "single",
      bufnr = self.info_bufnr
    })

    local layout = Layout(
      {
        anchor = "NW",
        relative = "editor",
        position = {
          row = "50%",
          col = 1
        },
        size = {
          height = "95%",
          width = "95%"
        },
      },
      vim.g.StartedByNvimTask and
        Layout.Box({
          Layout.Box(self.nvim_popup, { size = "75%" }),
          Layout.Box({
            Layout.Box(self.info_popup, { size = "30%" }),
            Layout.Box(self.msg_popup, { size = "70%" }),
          }, { size = "25%",  dir = "col" }),
        }, { dir = "row" })
      or
        Layout.Box({
          Layout.Box({
            Layout.Box(self.info_popup, { size = "30%" }),
            Layout.Box(self.msg_popup, { size = "70%" }),
          }, { size = "25%",  dir = "col" }),
          Layout.Box(self.nvim_popup, { size = "75%" }),
        }, { dir = "row" })
    )

    layout:mount()

    self.layout = layout

    -- self.win = nvim_popup.winid
  else
    self.layout:show()
  end

  vim.defer_fn(function ()
    if self.is_open then
      vim.cmd.startinsert()
    end
  end, 300) -- FIXME
  -- vim.cmd.startinsert()

  self.msg_win = self.msg_popup.winid

  self.is_open = true

  -- TODO make this function async and wait for terminal mode to be entered first?
  if self:is_recording() then
    require"plenary.async".run(function ()
      self:_start_record_term()
    end, function() end)
  end
end

function IRunner:_close(key)
  if not self.is_open then return end -- FIXME
  self.is_open = false

  if self:is_recording() then
    self:_pause_record_term(key) -- FIXME make async?
  end

  self.layout:hide()

  if vim.api.nvim_win_is_valid(self.win_before) then
    vim.api.nvim_set_current_win(self.win_before)
  end
  -- self.win = nvim_popup.winid
  -- self.msg_win = msg_popup.winid
end

function IRunner:close(key)
  require"plenary.async".run(function()
    self:_close(key)
  end, function() end)
end

function IRunner:toggle(key)
  if self.is_open then
    self:close(key)
    return
  end

  self:open()
end

function IRunner:start()
  self:_reset()

  -- tts.start(self, task)
  self:spawn()

  table.insert(task_stack, self)

  db.set_test_metadata({curr_test = self.name})
  db.set_test_metadata({curr_opts = self.opts})
end

function IRunner:ui_start()
  self:open()
  -- TODO check that task.cmd string starts with `nvim`

  local buf = self.bufnr
  vim.keymap.set("t", startstop_recording, function() self:record_toggle(startstop_recording) end, {buffer = buf})
  vim.keymap.set("t", breakpoint_key, function() self:add_breakpoint(breakpoint_key) end, {buffer = buf})
  vim.keymap.set("t", manual_breakpoint_key, function() self:add_breakpoint(manual_breakpoint_key) end, {buffer = buf})
  vim.keymap.set("t", restart_key, function() self:restart() end, {buffer = buf})
  vim.keymap.set("t", abort_key, function() self:stop() end, {buffer = buf})
  vim.keymap.set("t", toggle_key, function() self:toggle(toggle_key) end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.exit_test, function () M.abort_curr_task() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.restart_test, function () M.restart() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.blank_test, function () M.blank_sess() end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.edit_test, function () M.abort_curr_task(function () M.edit_curr_test() end) end, {buffer = buf})
  -- vim.keymap.set("t", self.opts.trace_test, function () M.restart_trace() end, {buffer = buf})
end

function IRunner.get_task_stack()
  return task_stack
end

function IRunner.last_task()
  return task_stack[#task_stack]
end

function IRunner.abort_last_task()
  local task = IRunner.last_task()
  if task then
    print('aborting last task...')
    task:stop()
    return
  end
  vim.notify(('no tasks currently running'))
end

function IRunner.restart_last_task()
  local task = IRunner.last_task()
  if task then
    task:restart()
    vim.notify(('restarted task "%s"'):format(task.name))
    return
  end
  vim.notify(('no tasks currently running'))
end

function IRunner:_stop()
  if self.stopped then return end -- FIXME figure out why this is called multiple times
  self.stopped = true

  self:_close()

  for i, _ in ipairs(task_stack) do
    if task_stack[i] == self then
      table.remove(task_stack, i)
      break
    end
  end

  if self.layout then -- FIXME
    self.layout:unmount()
    self.layout = nil
  end

  self.msg_popup = nil
  self.nvim_popup = nil

  if self.chan_id then
    exit_handlers[self.chan_id] = function ()
      vim.api.nvim_buf_delete(self.bufnr, {})
      vim.api.nvim_buf_delete(self.msg_bufnr, {})
      vim.api.nvim_buf_delete(self.info_bufnr, {})
    end

    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end

  -- self.term:close() 
  -- tts.stop(self) -- TODO close windows, delete bufs and vim.fn.stopjob()
  -- vim.notify(('aborted task "%s"'):format(self.name))
end

function IRunner:stop()
  if self.stopped then return end
  require"plenary.async".run(function()
    self:_stop()
  end, function() end)
end

function IRunner:_restart()
  -- FIXME this is a workaround for:
  -- require"overseer".run_action(self.task, "restart")
  -- since we need to wait for the toggleterm to properly close
  -- so as to avoid the issue where it opens in normal mode
  local was_open = self.is_open

  self:_stop() -- FIXME implement more robust async solution so that the call to self:stop() knows to use the async version
  self:reset()

  vim.defer_fn(function() -- FIXME still need to defer?
    self:start()
  end, was_open and 100 or 0)
end

-- FIXME use a queue for waiting async functions so that no two async runs can happen at the same time
-- FIXME auto-generate these from async-marked functions via metatable's __index field
function IRunner:restart()
  require"plenary.async".run(function()
    self:_restart()
  end, function() end)
end

function IRunner.run(name, opts)
  local runner = IRunner.new(name, opts)
  runner:start()
  return runner
end

return IRunner
