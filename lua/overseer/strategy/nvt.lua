local db = require("nvim-task.db")
local nvt_conf = require("nvim-task.config")
local trace = require("nvim-task.trace")

local task_stack = {}

local function _wait_for_autocmd(cmds, callback)
	vim.api.nvim_create_autocmd(cmds, { callback = callback, once = true })
end

local wait_for_autocmd = function(autocmd)
  return require"plenary.async".wrap(_wait_for_autocmd, 2)(autocmd)
end

local sockfiles_to_strats = {}

local NVTStrategy = {}

-- TODO make configurable
local play_recording_shortcut = vim.g.StartedByNvimTask and "<C-tab>" or "<tab>"
local startstop_recording = vim.g.StartedByNvimTask and "<C-A-f>" or "<C-f>"
local breakpoint_key = vim.g.StartedByNvimTask and "<C-A-e>" or "<C-e>"
local restart_key = vim.g.StartedByNvimTask and "<C-A-x>r" or "<C-x>r"
local abort_key = vim.g.StartedByNvimTask and "<C-A-x>x" or "<C-x>x"
local toggle_key = vim.g.StartedByNvimTask and "<C-A-Esc>" or "<A-l>"

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
    paused_recording = nil,
    curr_split_recording = nil,
    error_msg = nil,
    chan_id = nil,
    opts = opts,
    term = nil,
    stopped = false,
  }

  -- new = vim.tbl_extend("error", new, to_merge)
  -- setmetatable(new, {__index = NVTStrategy})

  sockfiles_to_strats[opts.sockfile] = new
  return setmetatable(new, { __index = NVTStrategy })
end

function NVTStrategy:_reset() -- FIXME rename (not async)
  self.sock = nil
  self.data = db.get_tests_data()[self.sname] or {sess = self.sname}
  self.split_recording = self.data.split_recording or (self.data.recording and vim.split(self.data.recording, normalizeKeycodes(breakpoint_key), {plain = true}) or {})
  -- TODO remove back-compat
  local new_split_recording = {}
  local any_string = false
  for i, keys in ipairs(self.split_recording) do
    local keys_data
    if type(keys) == "string" then
      any_string = true
      keys_data = {
        type = "raw",
        keys = keys,
      }
    else
      keys_data = keys
    end
    table.insert(new_split_recording, keys_data)
    if any_string and i ~= #self.split_recording then
      table.insert(new_split_recording, {type = "breakpoint"})
    end
  end
  self.split_recording = new_split_recording
  -- TODO remove back-compat
  if not self.data.split_recording and self.data.recording then
    self:set_data({split_recording = self.split_recording})
  end
  self.rem_recording = vim.fn.copy(self.split_recording)
  self.finished_playback_restart = false
  self.chan_id = nil
  self.layout = nil
  self.msg_popup = nil
  self.error_msg = nil
  self.paused_recording = nil
  self.nvim_popup = nil
  self.curr_split_recording = nil
  self.is_open = false
  self.win_before = nil
  self.sock_waiters = {}
  self.messages = {}
  self.child_loaded = false
  self.stopped = false
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
  return self.bufnr
end

local log = require"vim.lsp.log"

function NVTStrategy.set_child_sock(sockfile)
  require"plenary.async".run(function ()
    local self = sockfiles_to_strats[sockfile]
    if not self then return end

    local num_tries = 0
    while num_tries < 10 do
      require"plenary.async.util".sleep(300)

      local success, sock = pcall(vim.fn.sockconnect, "pipe", sockfile, {rpc = true})
      if success then
        self.sock = sock
        break
      end

      num_tries = num_tries + 1
    end

    if self.sock then
      self:run_child_notify("require'nvim-task.config'.load_session(...)", self.sname)
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

  if error then
    self.error_msg = msg
  end

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

function NVTStrategy:is_recording()
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

function NVTStrategy:set_data(data)
  self.data = db.set_test_data(self.sname, data)
end

function NVTStrategy:get_win()
  local win = self.window -- TODO set window
  -- the session may currently be un-toggled
  if not vim.api.nvim_win_is_valid(win) then return nil end

  return win
end

local _input = function(opts)
  return require"plenary.async".wrap(vim.ui.input, 2)(opts)
end

function NVTStrategy:_start_record_term()
  a_normal("q" .. tempreg)
end

function NVTStrategy:_get_record_term(key)
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

function NVTStrategy:_pause_record_term(key)
  self.paused_recording = self:_get_record_term(key)
end

function NVTStrategy:_end_record_term(key)
  local recorded = self:_get_record_term(key)

  if recorded ~= "" then
    local split_recorded = vim.split(recorded, normalizeKeycodes(breakpoint_key), {plain = true}) or {}
    for i, split in ipairs(split_recorded) do
      if split ~= "" then
        table.insert(self.curr_split_recording, {
          type = "raw",
          keys = split
        })
      end

      if i ~= #split_recorded then
        table.insert(self.curr_split_recording, {
          type = "breakpoint",
        })
      end
    end
  end
end

local function get_recording_string(split_recording)
  local recording_string = ""
  for i, data in ipairs(split_recording) do
    local str
    if data.type == "raw" then
      str = data.keys
    elseif data.type == "breakpoint" then
      str = "╳"
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
function NVTStrategy:_record_toggle(key)
	if not self:is_recording() then
    if not self.data.split_recording then
      self.curr_split_recording = {}
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

  local name = self.sname
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
    self.sname = name

    self:set_data({sess = name, split_recording = split_recording})
    print('Recorded: ' .. get_recording_string(split_recording))

    self.finished_playback_restart = true
    vim.notify(("press '%s' to restart"):format(play_recording_shortcut))
  end

  vim.cmd.startinsert()

  self:_continue_recording()
end

function NVTStrategy:record_toggle(key)
  require"plenary.async".run(function()
    self:_record_toggle(key)
  end, function() end)
end

function NVTStrategy:play_recording()
  -- if self.trace_playback and not self.already_tracing then
  --   self:run_child("require'nvim-task.config'.calltrace_start()")
  --   self.already_tracing = true
  -- end

  local keys_data = self.rem_recording[1]
  table.remove(self.rem_recording, 1)

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

function NVTStrategy:_continue_recording()
   -- TODO telescope in to find the last type=raw data, set that as the current level
  if self.data.split_recording then
    self.curr_split_recording = {unpack(self.data.split_recording, 1, #self.data.split_recording - 1)}
    self.paused_recording = self.data.split_recording[#self.data.split_recording].keys
  else
    self.curr_split_recording = {}
    self.paused_recording = ""
  end
  self:_start_record_term()
end
function NVTStrategy:finished_playback()
  return not self.rem_recording or #self.rem_recording == 0
end

function NVTStrategy:maybe_play_recording()
  if self.finished_playback_restart then
    self:restart()
    return
  end

  if self:finished_playback() then
    self.finished_playback_restart = true
    if self.trace_playback then
      local calltrace_data = self:run_child("return require'nvim-task.config'.calltrace_end()")
      self:set_data({calltrace = calltrace_data})
      -- make_test(curr_test)
    end

    vim.notify(("press '%s' again to restart"):format(play_recording_shortcut))
    return
  end

  if self:is_recording() then
    self:run_child("vim.api.nvim_input(...)", play_recording_shortcut)
    return
  end

  while not self:finished_playback() do
    local data = self:play_recording()
    if data then
      if data.type == "breakpoint" then
        vim.notify(("hit breakpoint (TODO remaining)"):format(#self.rem_recording)) -- TODO show remaining number of breakpoints
        return
      end
    end
  end

  if self.trace_playback then
    vim.notify(("playback finished, press '%s' again to capture trace"):format(play_recording_shortcut))
  else
    vim.notify("playback finished")
  end

  -- TODO put in play_recording after async refactor
  require"plenary.async".run(function()
    self:_continue_recording()
  end, function() end)
end

function NVTStrategy:add_breakpoint(key)
	if self:is_recording() then
    vim.notify("added breakpoint")
	else
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), "n")
	end
end

function NVTStrategy:pick_trace()
  require"plenary.async".run(function()
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


  local called = false

  local new_cb = function()
    called = true
    return cb(true)
  end

  table.insert(self.sock_waiters, new_cb)

  vim.defer_fn(
    function()
      if not called then -- timeout error
        cb(false)
      end
    end,
    1000
  )
end

NVTStrategy._sock_wait = function(self)
  return require"plenary.async".wrap(NVTStrategy.__sock_wait, 2)(self)
end

function NVTStrategy:spawn(task)
  require"plenary.async".run(function()
    if self.headless then
      self:__spawn(task, true)
    else
      self.bufnr = vim.api.nvim_create_buf(false, false)
      self.msg_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_call(self.bufnr, function() self:__spawn(task) end)
    end
    if not self:_sock_wait() then
      vim.notify"ERROR: rpc socket connection timeout. Aborting task..."
      -- TODO give user the option to open test session to see error
      self:stop()
      return
    end
    if not self.headless then
      self:ui_start()
    end
    if self.opts.auto and self.data.split_recording then
      print("playing: ".. get_recording_string(self.data.split_recording))
      while not self:finished_playback() do
        if self.error_msg then break end

        local data = self:play_recording()
        if data then
          if data.type == "breakpoint" then
            require"plenary.async.util".sleep(300)
          end
        end
      end
      self:_continue_recording()

      require"plenary.async.util".sleep(300)
      if self.headless then
        if #self.messages > 0 then
          vim.notify("test messages:\n" .. vim.fn.join(self.messages, "\n") .. "\n---")
        end
        if self.error_msg then
          if #self.rem_recording > 0 then
            print("aborted playback because of error message:\n", self.error_msg)
          else
            print("got error message:\n", self.error_msg)
          end
        end
        self:stop()
      else
        if self.error_msg then print("got error message:\n", self.error_msg) end
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

  -- TODO make this function async and wait for terminal mode to be entered first?
  if self:is_recording() then
    require"plenary.async".run(function ()
      self:_start_record_term()
    end, function() end)
  end
end

function NVTStrategy:_close(key)
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

function NVTStrategy:close(key)
  require"plenary.async".run(function()
    self:_close(key)
  end, function() end)
end

function NVTStrategy:toggle(key)
  if self.is_open then
    self:close(key)
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
  db.set_test_metadata({curr_params = self.opts.params})
end

function NVTStrategy:ui_start()
  self:open()
  -- TODO check that task.cmd string starts with `nvim`

  local buf = self.bufnr
  vim.keymap.set("t", play_recording_shortcut, function() self:maybe_play_recording() end, {buffer = buf})
  vim.keymap.set("t", startstop_recording, function() self:record_toggle(startstop_recording) end, {buffer = buf})
  vim.keymap.set("t", breakpoint_key, function() self:add_breakpoint(breakpoint_key) end, {buffer = buf})
  vim.keymap.set("t", restart_key, function() self:restart() end, {buffer = buf})
  vim.keymap.set("t", abort_key, function() self:dispose() end, {buffer = buf})
  vim.keymap.set("t", toggle_key, function() self:toggle(toggle_key) end, {buffer = buf})
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

function NVTStrategy:_stop()
  if self.stopped then return end -- FIXME figure out why this is called multiple times
  self.stopped = true

  self:_close()

  for i, _ in ipairs(task_stack) do
    if task_stack[i] == self.task then
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
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
  -- self.term:close() 
  -- tts.stop(self) -- TODO close windows, delete bufs and vim.fn.stopjob()
  -- vim.notify(('aborted task "%s"'):format(self.sname))
end

function NVTStrategy:stop()
  if self.stopped then return end
  require"plenary.async".run(function()
    self:_stop()
  end, function() end)
end

function NVTStrategy:_restart()
  -- FIXME this is a workaround for:
  -- require"overseer".run_action(self.task, "restart")
  -- since we need to wait for the toggleterm to properly close
  -- so as to avoid the issue where it opens in normal mode
  local was_open = self.is_open

  self:_stop() -- FIXME implement more robust async solution so that the call to self:stop() knows to use the async version
  self.task:stop()
  self.task:reset()

  vim.defer_fn(function() -- FIXME still need to defer?
    self.task:start()
  end, was_open and 100 or 0)
end

-- FIXME use a queue for waiting async functions so that no two async runs can happen at the same time
-- FIXME auto-generate these from async-marked functions via metatable's __index field
function NVTStrategy:restart()
  require"plenary.async".run(function()
    self:_restart()
  end, function() end)
end


function NVTStrategy:dispose()
  self:stop()
  -- tts.dispose(self)
end

return NVTStrategy
