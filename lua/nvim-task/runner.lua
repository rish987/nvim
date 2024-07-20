local db = require("nvim-task.db")

local sockfiles_to_runners = {}

local Runner = {}

local function get_child_sock()
  local socket_i = 0
  local child_sock = "/tmp/nvimtasksocketchild" .. socket_i
  while vim.fn.filereadable(child_sock) ~= 0 do
    socket_i = socket_i + 1
    child_sock = "/tmp/nvimtasksocketchild" .. socket_i
  end
  return child_sock
end

function Runner.new(data, opts)
  local sockfile = get_child_sock()

  local new = {
    sock_waiters = {},
    child_loaded = false,
    tries = 0,
    data = data,
    messages = {},
    opts = opts,
    error_msg = nil,
    chan_id = nil,
    stopped = false,
    playing_back = false,
    sockfile = sockfile,
  }

  -- new = vim.tbl_extend("error", new, to_merge)
  -- setmetatable(new, {__index = NVTStrategy})

  sockfiles_to_runners[sockfile] = new
  return setmetatable(new, { __index = Runner })
end

function Runner:_reset() -- FIXME rename (not async)
  self.sock = nil
  self.rem_recording = vim.fn.copy(self.data.split_recording)
  self.finished_playback_restart = false
  self.chan_id = nil
  self.error_msg = nil
  self.sock_waiters = {}
  self.messages = {}
  self.child_loaded = false
  self.stopped = false
  self.playing_back = false
end

function Runner:run_child(code, ...)
  if not self.sock then print("ERROR: socket not set") return end
  return vim.fn.rpcrequest(self.sock, "nvim_exec_lua", code, {...})
end

function Runner:run_child_notify(code, ...)
  if not self.sock then vim.notify"ERROR: sock not set yet" return end
  vim.fn.rpcnotify(self.sock, "nvim_exec_lua", code, {...})
end

function Runner:reset()
  -- tts.reset(self)

  self:_reset()
end

local log = require"vim.lsp.log"

function Runner.set_child_sock(sockfile)
  require"plenary.async".run(function ()
    local self = sockfiles_to_runners[sockfile]
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
      self:run_child_notify("require'nvim-task.config'.load_session(...)", self.data.sess)
      self.tries = 0
    elseif self.tries < 5 then
      self.tries = self.tries + 1
      self:restart()
    else
      print"ERROR: maximum RPC connection retries failed"
    end
  end, function() end)
end

function Runner.child_loaded_notify(sockfile)
  local self = sockfiles_to_runners[sockfile]
  if not self then return end
  self.child_loaded = true

  for _, cb in ipairs(self.sock_waiters) do
    cb()
  end
  self.sock_waiters = {}
end

function Runner:add_msg(msg)
  table.insert(self.messages, msg)
end

function Runner.new_child_msg(sockfile, msg, error)
  local self = sockfiles_to_runners[sockfile]
  if not self then return end
  -- self:new_msg(msg)

  -- self.task:dispatch("on_output", msg)  -- FIXME why does this get stuck?
  -- self.task:dispatch("on_output_lines", vim.split(msg, "\n"))

  if error then
    self.error_msg = msg
  end

  self:add_msg(msg)
end

function Runner:set_data(data)
  self.data = db.set_test_data(self.name, data)
end

function Runner:get_win()
  local win = self.window -- TODO set window
  -- the session may currently be un-toggled
  if not vim.api.nvim_win_is_valid(win) then return nil end

  return win
end

function Runner:play_recording()
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

function Runner:finished_playback()
  return not self.rem_recording or #self.rem_recording == 0
end

local exit_handlers = {}

local sock = vim.call("serverstart")

function Runner:__spawn()
  local cmd = "nvim"
  local args = {
    "--cmd", [["let g:StartedByNvimTask = 'true'"]],
    "--cmd", ([["let g:NvimTaskSessionDir = '%s'"]]):format(db.sessiondir), -- use parent sessiondir
    "--cmd", ([["let g:NvimTaskParentSock = '%s'"]]):format(sock),
    "--cmd", ([["let g:NvimTaskChildSockfile = '%s'"]]):format(self.sockfile),
    "--listen", self.sockfile
  }
  for _, arg in ipairs(args) do
    cmd = cmd .. " " .. arg
  end
  local dir = vim.loop.cwd() -- FIXME get from data?
  if self.opts.bufnr then
    vim.api.nvim_buf_call(self.opts.bufnr, function()
      self.chan_id = vim.fn.termopen(cmd, {
        detach = 1,
        cwd = dir,
        -- on_exit = __handle_exit(self),
        -- on_stdout = self:__make_output_handler(self.on_stdout),
        -- on_stderr = self:__make_output_handler(self.on_stderr),
        -- env = self.opts.env,
        -- pty = true
        rpc = true
        -- clear_env = self.clear_env,
      })
    end)
  else
    self.chan_id = vim.fn.jobstart(cmd, { --vim.fn.split(cmd, " "), {
      cwd = dir,
      -- on_exit = __handle_exit(self),
      -- on_stdout = self:__make_output_handler(self.on_stdout),
      -- on_stderr = self:__make_output_handler(self.on_stderr),
      -- env = self.opts.env,
      pty = true,
      on_exit = function()
        local handler = exit_handlers[self.chan_id]
        if handler then
          handler()
        end
      end
      -- clear_env = self.clear_env,
    })
  end
end

function Runner:__sock_wait(cb)
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

Runner._sock_wait = function(self)
  return require"plenary.async".wrap(Runner.__sock_wait, 2)(self)
end

function Runner:_playback()
  if self.playing_back then return end
  self.playing_back = true
  while not self:finished_playback() do
    if self.error_msg then break end

    local data = self:play_recording()
    if data then
      if data.type == "breakpoint" then
        require"plenary.async.util".sleep(300)
      end
    end
  end
  self.playing_back = false
end

function Runner:playback()
  require"plenary.async".run(function()
    self:_playback()
  end, function() end)
end

function Runner:spawn()
  require"plenary.async".run(function()
    self:__spawn()
    if not self:_sock_wait() then
      vim.notify"ERROR: rpc socket connection timeout. Aborting task..."
      -- TODO give user the option to open test session to see error
      self:stop()
      return
    end
    if self.data.split_recording then
      self:_playback()
    end
  end, function() end)
end

function Runner:start()
  self:_reset()

  self:spawn()
end

function Runner:_stop()
  if self.stopped then return end -- FIXME figure out why this is called multiple times
  self.stopped = true

  if self.chan_id then
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
end

function Runner:stop()
  if self.stopped then return end
  require"plenary.async".run(function()
    self:_stop()
  end, function() end)
end

function Runner:_restart()
  self:_stop() -- FIXME implement more robust async solution so that the call to self:stop() knows to use the async version
  self:reset()
  self:start()
end

-- FIXME use a queue for waiting async functions so that no two async runs can happen at the same time
-- FIXME auto-generate these from async-marked functions via metatable's __index field
function Runner:restart()
  require"plenary.async".run(function()
    self:_restart()
  end, function() end)
end

function Runner.run(name)
  local runner = Runner.new(name)
  runner:start()
  return runner
end

return Runner
