local tts = require("overseer.strategy.toggleterm")
local db = require("nvim-task.db")
local nvt_conf = require("nvim-task.config")
local trace = require("nvim-task.trace")

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
local toggle_key = vim.g.StartedByNvimTask and "<C-A-Esc>" or "<C-Esc>"

local normalizeKeycodes = function(mapping)
	return vim.fn.keytrans(vim.api.nvim_replace_termcodes(mapping, true, true, true))
end

function NVTStrategy.new(opts)
  if opts.headless then opts.auto = true end

  local new = {
    sock_waiters = {},
    child_loaded = false,
    tries = 0,
    sname = opts.sname,
    headless = opts.headless,
    bufnr = nil,
    messages = {},
    msg_bufnr = nil,
    chan_id = nil,
    opts = opts,
    term = nil,
  }

  -- new = vim.tbl_extend("error", new, to_merge)
  -- setmetatable(new, {__index = NVTStrategy})

  sockfiles_to_strats[opts.sockfile] = new
  return setmetatable(new, { __index = NVTStrategy })
end

function NVTStrategy:_reset()
  self.sock = nil
  self.data = db.get_tests_data()[self.sname] or {sess = self.sname}
  self.split_recording = self.data.recording and vim.split(self.data.recording, normalizeKeycodes(breakpoint_key), {plain = true}) or {}
  -- TODO the recording should come pre-split by the nvim-task.recorder module
  self.rem_recording = vim.fn.copy(self.split_recording)
  self.finished_playback = false
  self.finished_playback_restart = false
  self.chan_id = nil
  self.layout = nil
  self.msg_popup = nil
  self.nvim_popup = nil
  self.is_open = false
  self.win_before = nil
  self.sock_waiters = {}
  self.messages = {}
  self.child_loaded = false
end

function NVTStrategy:run_child(code, ...)
  if not self.sock then print("ERROR: socket not set") return end
  return vim.fn.rpcrequest(self.sock, "nvim_exec_lua", code, {...})
end

function NVTStrategy:run_child_notify(code, ...)
  if not self.sock then vim.notify"ERROR: sock not set yet" return end
  vim.fn.rpcnotify(self.sock, "nvim_exec_lua", code, {...})
end

function NVTStrategy:reset()
  -- tts.reset(self)

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
  local was_open = self.is_open

  self.task:stop()
  self.task:reset()

  vim.defer_fn(function() -- FIXME still need to defer?
    self.task:start()
  end, was_open and 100 or 0)
end

local log = require"vim.lsp.log"

function NVTStrategy.set_child_sock(sockfile)
  a.run(function ()
    local self = sockfiles_to_strats[sockfile]
    if not self then return end

    local num_tries = 0
    while num_tries < 10 do
      a_util.sleep(300)

      local success, sock = pcall(vim.fn.sockconnect, "pipe", sockfile, {rpc = true})
      if success then
        self.sock = sock
        break
      end

      num_tries = num_tries + 1
    end

    if self.sock then
      self:run_child("require'nvim-task.config'.load_session(...)", self.sname)
      if not self.headless then
        self:ui_start()
      end
      self.tries = 0
    elseif self.tries < 5 then
      self.tries = self.tries + 1
      self:restart()
    else
      print"ERROR: maximum RPC connection retries failed"
    end
  end, function() end)
end

function NVTStrategy.child_loaded_notify(sockfile)
  local self = sockfiles_to_strats[sockfile]
  if not self then return end
  self.child_loaded = true

  for _, cb in ipairs(self.sock_waiters) do
    cb()
  end
  self.sock_waiters = {}
end

function NVTStrategy:add_msg(msg)
  table.insert(self.messages, msg)
end

function NVTStrategy.new_child_msg(sockfile, msg, error)
  local self = sockfiles_to_strats[sockfile]
  if not self then return end
  -- self:new_msg(msg)

  -- self.task:dispatch("on_output", msg)  -- FIXME why does this get stuck?
  -- self.task:dispatch("on_output_lines", vim.split(msg, "\n"))

  self:add_msg(msg)
  if self.headless then return end

  -- TODO move to its own component
  local msgs_text = vim.api.nvim_buf_get_text(self.msg_bufnr, 0, 0, -1, -1, {})
  local num_lines = #msgs_text
  local last_line_length = #msgs_text[num_lines]
  local msgwin = self.msg_popup.winid

  local cursorpos
  if msgwin then
    cursorpos = vim.api.nvim_win_get_cursor(msgwin)
  end

  local split_msg = vim.split(msg, "\n")

  local new_text = last_line_length == 0 and split_msg or {"", unpack(split_msg)}
  vim.api.nvim_buf_set_text(self.msg_bufnr, num_lines - 1, last_line_length, num_lines - 1, last_line_length, new_text)

  if msgwin then
    local at_bottom = cursorpos[1] == num_lines

    -- autoscroll
    if at_bottom then
      vim.fn.win_execute(msgwin, "normal! G")
    end
  end
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
  local win = self.window -- TODO set window
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
		vim.notify("Recording to [" .. tempreg .. "]…")
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

  vim.cmd.startinsert()

  if name then
    local get_session_file = require"resession.util".get_session_file
    local saved_file = get_session_file(nvt_conf.saved_test_name, db.sessiondir)
    local new_file = get_session_file(name, db.sessiondir) -- name the session after the test
    -- TODO check and confirm override if name/session already exists
    vim.notify(("renaming session: %s to %s" ):format(saved_file, new_file))
    vim.loop.fs_rename(saved_file, new_file)
    self:run_child_notify(("require'nvim-task.config'.record_finish(%s)"):format(name))
    self.sname = name

    self:set_data({sess = name, recording = vim.fn.keytrans(recording)})

    self.finished_playback_restart = true
    vim.notify(("press '%s' to restart"):format(play_recording_shortcut))
  end
end

function NVTStrategy:record_toggle()
  a.run(function()
    self:_record_toggle()
  end, function() end)
end

function NVTStrategy:play_recording()
  if #self.rem_recording == 0 then
    vim.notify("no recording to play!")
    return
  end

  if self.trace_playback and not self.already_tracing then
    self:run_child("require'nvim-task.config'.calltrace_start()")
    self.already_tracing = true
  end

  local keys = self.rem_recording[1]
  table.remove(self.rem_recording, 1)

  -- TODO does this work properly with '<' character in recording?
  self:run_child("vim.api.nvim_input(...)", keys)
  -- local to_send = vim.api.nvim_replace_termcodes(keys, true, true, true)
  -- vim.fn.chansend(self.chan_id, to_send)
  -- vim.fn.feedkeys(to_send)

  return #self.rem_recording == 0
end

function NVTStrategy:_maybe_play_recording()
  if self.rem_recording and #self.rem_recording > 0 then
    self.finished_playback = self:play_recording()
    return true
  end

  self.finished_playback = true

  return false
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

    vim.notify(("press '%s' again to restart"):format(play_recording_shortcut))
    return
  end

  if not isRecording() and self:_maybe_play_recording() then
    if self.finished_playback then
      if self.trace_playback then
        vim.notify(("playback finished, press '%s' again to capture trace"):format(play_recording_shortcut))
      else
        vim.notify("playback finished")
      end
    else
      vim.notify(("hit breakpoint (%d remaining)"):format(#self.rem_recording))
    end
    return
  end

  self:run_child("vim.fn.feedkeys(vim.api.nvim_replace_termcodes(..., true, true, true))", play_recording_shortcut)
end

function NVTStrategy:addBreakPoint(key)
	if isRecording() and vim.fn.reg_recording() == tempreg then
		-- INFO nothing happens, but the key is still recorded in the macro
		vim.notify("Macro breakpoint added.")
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
    -- self.term:open() -- TODO
  end, function() end)
end

function NVTStrategy:__spawn(task, headless)
  local cmd = task.cmd
  if type(cmd) == "table" then
    cmd = require"overseer.shell".escape_cmd(cmd, "strong")
  end
  local dir = task.cwd
  if dir then
    dir = vim.fn.expand(dir)
  else
    dir = vim.loop.cwd()
  end
  if headless then
    self.chan_id = vim.fn.jobstart(cmd, { --vim.fn.split(cmd, " "), {
      cwd = dir,
      -- on_exit = __handle_exit(self),
      -- on_stdout = self:__make_output_handler(self.on_stdout),
      -- on_stderr = self:__make_output_handler(self.on_stderr),
      env = task.env,
      pty = true,
      -- clear_env = self.clear_env,
    })
  else
    self.chan_id = vim.fn.termopen(cmd, {
      detach = 1,
      cwd = dir,
      -- on_exit = __handle_exit(self),
      -- on_stdout = self:__make_output_handler(self.on_stdout),
      -- on_stderr = self:__make_output_handler(self.on_stderr),
      env = task.env,
      -- pty = true
      rpc = true
      -- clear_env = self.clear_env,
    })
  end
end

function NVTStrategy:__sock_wait(cb)
  -- already connected
  if self.child_loaded then
    cb()
    return
  end

  table.insert(self.sock_waiters, cb)
end

NVTStrategy._sock_wait = a.wrap(NVTStrategy.__sock_wait, 2)

function NVTStrategy:spawn(task)
  a.run(function()
    if self.headless then
      self:__spawn(task, true)
    else
      self.bufnr = vim.api.nvim_create_buf(false, false)
      self.msg_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_call(self.bufnr, function() self:__spawn(task) end)
    end
    if self.opts.auto then
      self:_sock_wait()
      local first = true
      while true do
        -- TODO check for error and abort if so
        if not first then
          a_util.sleep(300)
        else
          first = false
        end

        self:_maybe_play_recording()
        if self.finished_playback then break end
      end

      if self.headless then
        a_util.sleep(300)
        if #self.messages > 0 then
          vim.notify("test messages:\n" .. vim.fn.join(self.messages, "\n") .. "\n---")
        end
        self:stop()
      end
    end
  end, function() end)
end

-- function NVTStrategy:__check_wins()
--   if self.win then
--     if not vim.api.nvim_win_is_valid(self.win) then
--       self.win = nil
--     end
--   end
--
--   if self.msg_win then
--     if not vim.api.nvim_win_is_valid(self.msg_win) then
--       self.msg_win = nil
--     end
--   end
-- end
--
-- function NVTStrategy:__check_bufnrs()
--   if self.bufnr then
--     if not vim.api.nvim_bufnr_is_valid(self.bufnr) then
--       self.bufnr = nil
--     end
--   end
--
--   if self.msg_bufnr then
--     if not vim.api.nvim_bufnr_is_valid(self.msg_bufnr) then
--       self.msg_bufnr = nil
--     end
--   end
-- end
--

function NVTStrategy:open()
  if self.headless then
    print("TODO open headless instance?")
    return
  end

  self.win_before = vim.api.nvim_get_current_win()
  if not self.layout then
    local Popup = require("nui.popup")
    local Layout = require("nui.layout")

    self.nvim_popup, self.msg_popup = Popup({
      enter = true,
      border = "double",
      bufnr = self.bufnr
    }), Popup({
      border = "single",
      bufnr = self.msg_bufnr
    })

    local layout = Layout(
      {
        anchor = "NW",
        relative = "editor",
        position = vim.g.StartedByNvimTask and "50%" or {
          row = "50%",
          col = 85
        },
        size = vim.g.StartedByNvimTask and "90%" or {
          height = "90%",
          width = "75%" -- FIXME negative column offset?
        },
      },
      Layout.Box({
        Layout.Box(self.nvim_popup, { size = "70%" }),
        Layout.Box(self.msg_popup, { size = "30%" }),
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
end

function NVTStrategy:close()
  if not self.layout then return end

  self.layout:hide()
  self.is_open = false

  if vim.api.nvim_win_is_valid(self.win_before) then
    vim.api.nvim_set_current_win(self.win_before)
  end
  -- self.win = nvim_popup.winid
  -- self.msg_win = msg_popup.winid
end

function NVTStrategy:toggle()
  if self.is_open then
    self:close()
    return
  end

  self:open()
end

function NVTStrategy:start(task)
  self:_reset()

  -- tts.start(self, task)
  self:spawn(task)

  self.task = task
  table.insert(task_stack, task)

  db.set_test_metadata({curr_test = self.sname})
end

function NVTStrategy:ui_start(task)
  self:open()
  -- TODO check that task.cmd string starts with `nvim`

  local buf = self.bufnr
  vim.keymap.set("t", play_recording_shortcut, function() self:maybe_play_recording() end, {buffer = buf})
  vim.keymap.set("t", startstop_recording, function() self:record_toggle() end, {buffer = buf})
  vim.keymap.set("t", breakpoint_key, function() self:addBreakPoint(breakpoint_key) end, {buffer = buf})
  vim.keymap.set("t", restart_key, function() self:restart() end, {buffer = buf})
  vim.keymap.set("t", abort_key, function() self:dispose() end, {buffer = buf})
  vim.keymap.set("t", toggle_key, function() self:toggle() end, {buffer = buf})
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
    print('aborting last task...')
    task:stop()
    return
  end
  vim.notify(('no tasks currently running'))
end

function NVTStrategy.restart_last_task()
  local task = NVTStrategy.last_task()
  if task then
    task.strategy:restart()
    vim.notify(('restarted task "%s"'):format(task.strategy.sname))
    return
  end
  vim.notify(('no tasks currently running'))
end

function NVTStrategy:stop()
  for i, _ in ipairs(task_stack) do
    if task_stack[i] == self.task then
      table.remove(task_stack, i)
      break
    end
  end
  if self.layout then
    self.layout:unmount() -- FIXME this can be nil? saw error when aborting task
    self.layout = nil
  end
  self.msg_popup = nil
  self.nvim_popup = nil

  if self.chan_id then
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
  -- self.term:close() 
  -- tts.stop(self) -- TODO close windows, delete bufs and vim.fn.stopjob()
  vim.notify(('aborted task "%s"'):format(self.sname))
end

function NVTStrategy:dispose()
  self:stop()
  -- tts.dispose(self)
end

return NVTStrategy
