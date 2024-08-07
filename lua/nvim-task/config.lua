local M = {}

M.saved_test_name = "NvimTask_saved"
M.temp_test_name = "NvimTask_curr"

function M.file_exists(filename)
  local stat = vim.loop.fs_stat(filename)
  return stat ~= nil and stat.type ~= nil
end

M.session_exists = function(sessname, sessdir)
  local sess_filename = require"resession.util".get_session_file(sessname, sessdir)
  return M.file_exists(sess_filename)
end

local log = require"vim.lsp.log"

function M.unpatch(arg)
  if type(arg) == "table" then
    if arg["_patched"] then
      for key, val in pairs(arg["_patched"]) do
        arg[val] = arg[key]
        arg[key] = nil
      end
      arg["_patched"] = nil
    end
    for key, val in pairs(arg) do
      arg[key] = M.unpatch(val)
    end
  end

  return arg
end

local function _foreach_modfn(modname, submodnames, mod, seen_mods, wl, cb)
  -- modules can be recursively nested, so this prevents an infinite loop
  seen_mods[mod] = true
  for val_name, val in pairs(mod) do
    local this_wl = wl
    if type(wl) == "table" then
      this_wl = wl[val_name]
    end
    if this_wl then
      if type(val) == "function" then
        cb(modname, submodnames, mod, val_name, val)
      elseif type(val) == "table" and not seen_mods[val] then
        local new_submodnames = vim.deepcopy(submodnames)
        table.insert(new_submodnames, val_name)
        _foreach_modfn(modname, new_submodnames, val, seen_mods, this_wl, cb)
      end
    end
  end
end

local blacklist = {
  ["_G"] = true,
  ["vim.shared"] = true
}

function M.foreach_modfn(cb, wl)
  for modname, module in pairs(package.loaded) do
    local seen_mods = {}
    if type(module) == "table" and modname ~= "package" and not blacklist[modname] then
      -- TODO handle metatable (and __index field in particular)
      local this_wl = wl
      if type(wl) == "table" then
        this_wl = wl[modname]
      end
      _foreach_modfn(modname, {}, module, seen_mods, this_wl, cb)
    else
      -- print(mod_name, type(module))
    end
  end
end

function M.get_traceable_fns()
  local ret = {}
  M.foreach_modfn(function(modname, submodnames, _, valname, _)
    table.insert(ret, {modname = modname, submodnames = submodnames, fnname = valname})
  end, true)
  return ret
end

function M.modfun_key(modname, submodnames, fnname, quote)
  if quote then modname = '"modname"' end
  return #submodnames > 0 and modname .. "." .. vim.fn.join(submodnames, ".") or modname .. "." .. fnname
end

if not vim.g.StartedByNvimTask then return M end

M.sockfile = vim.g.NvimTaskChildSockfile

M.parent_sock = vim.fn.sockconnect("pipe", vim.g.NvimTaskParentSock, {rpc = true})

vim.o.swapfile = false

M.ns = vim.api.nvim_create_namespace("nvim-task")

local keymap_orig = vim.keymap.set
-- local keymap_id = 0
vim.keymap.set = function(mode, lhs, rhs, opts)
  if type(rhs) == "function" then
    keymap_orig(mode, lhs, function ()
      -- vim.fn.rpcrequest(M.parent_sock, "nvim_exec_lua", "require'overseer.strategy.nvt'.register_keymap(...)", {M.sockfile, lhs})
      local ret = rhs()
      return ret -- TODO what to do with return value?
    end, opts)
  else
    keymap_orig(mode, lhs, rhs, opts)
  end
end


vim.keymap.set("n", "<leader>xn", function ()
  print("HERE")
end)

local sessiondir = vim.g.NvimTaskSessionDir

local sess

function M.save_session () -- save to default slot
  -- FIXME do this without setting any "state" w.r.t the current session
  require"resession".save(M.saved_test_name, { dir = sessiondir })
  sess = nil
end

-- vim.keymap.set("n", "<leader>A", function ()
--   require"resession".load(nil, { dir = sessiondir })
-- end)

local ns = vim.api.nvim_create_namespace"NvimTask"
local parent_notify = function(call, args)
  vim.fn.rpcnotify(M.parent_sock, "nvim_exec_lua", "require'nvim-task.runner'." .. call, args)
end

local function msgview_enable()
  -- TODO recall that noice is a dependency because cmdline also uses the message view
  vim.ui_attach(ns, {ext_messages = true}, function(event, kind, content, _)
    if event ~= "msg_show" then return end
    local is_error =
      kind == "emsg" or
      kind == "echoerr" or
      kind == "lua_error" or
      kind == "rpc_error"

    if kind == "return_prompt" then
      vim.api.nvim_input("<cr>")
      return
    end

    local str = ""
    for i, val in ipairs(content) do
      if i > 1 then
        str = str .. "\n" .. val[2]
      else
        str = str .. val[2]
      end
    end

    log.warn(sessiondir, str)
    parent_notify("new_child_msg(...)", {M.sockfile, str, is_error})
  end)
end


if vim.v.vim_did_enter then
  parent_notify("set_child_sock(...)", {M.sockfile})
else
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = vim.schedule_wrap(function()
      parent_notify("set_child_sock(...)", {M.sockfile})
      -- now, wait for M.load_session to be called by the parent instance (after it has connected)
    end),
  })
end

function M.load_session(_sess)
  local startup_msgs = vim.api.nvim_cmd({ cmd = "messages" }, { output = true })
  msgview_enable()
  print(startup_msgs)
  sess = _sess
  if M.session_exists(sess, sessiondir) then
    require"resession".load(sess, { dir = sessiondir, silence_errors = true })
  else
    sess = M.temp_test_name
  end

  parent_notify("child_loaded_notify(...)", {M.sockfile})
  -- log.warn"HERE 8"
  -- M.msgview_enable()
end

-- vim.keymap.set("n", "<leader>Xn", function ()
--   vim.fn.feedkeys(keymap_str:format("n"))
-- end)
--
-- vim.keymap.set("n", "<leader>Xi", function ()
--   vim.fn.feedkeys(keymap_str:format("i"))
-- end)

-- resession-generic

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if sess == M.temp_test_name then -- auto-save temporary session
      require"resession".save(sess, { dir = sessiondir, notify = false })
    end
  end,
})

-- list of modules that are used in the function override,
-- and must therefore be temporarily reset to the originals when used in the function
-- in order to avoid inifinite looping
-- local blacklist = { "_G", "vim.inspect", }

-- local orig_bmods = {}
-- for _, mod_name in ipairs(blacklist) do
--   orig_bmods[mod_name] = require(mod_name)
-- end
--
-- local _pairs = pairs

-- TODO how to deal with lazy-loading?
--
-- TODO why is vim.api not captured by this?

local disable = true
local call_objs = {}

function M.calltrace_start()
  disable = false
end

function M.calltrace_end()
  disable = true
  local curr_objs = call_objs
  call_objs = {}
  M.patch(curr_objs)
  -- has_fn(curr_objs)
  -- vim.fn.json_encode(curr_objs)
  return curr_objs
end

local function patch_arg(arg, seen_tbl_args)
  seen_tbl_args = seen_tbl_args or {}
  if type(arg) == "function" then
    return "<erased fn>"
  elseif type(arg) == "userdata" then
    return "<erased userdata>"
  elseif type(arg) == "thread" then
    return "<erased thread>"
  elseif type(arg) == "string" then
    local success = pcall(vim.fn.json_encode, arg)
    if success then
      return arg
    else
      return "<erased invalid string>"
    end
  elseif type(arg) == "table" then
    if not seen_tbl_args[arg] then
      seen_tbl_args[arg] = true
      local new_tbl = {}
      local has_num_key
      local has_str_key
      for key, _ in pairs(arg) do
        if type(key) == "number" then
          has_num_key = true
          if has_str_key then break end
        elseif type(key) == "string" then
          has_str_key = true
          if has_num_key then break end
        end
      end
      local should_patch = has_str_key and has_num_key
      for key, val in pairs(arg) do
        local new_key
        if type(key) == "number" and should_patch then
          new_key = "_patched" .. key

          new_tbl["_patched"] = new_tbl["_patched"] or {}
          new_tbl["_patched"][new_key] = key
        elseif type(key) == "number" or type(key) == "string" then -- (ignore keys of other types)
          new_key = key
        end
        if new_key then
          new_tbl[new_key] = patch_arg(val, seen_tbl_args)
        end
      end
      return new_tbl
    else
      return "<erased recursive reference>"
    end
  end

  return arg
end

function M.patch(objs)
  for _, obj in ipairs(objs) do
    for key, arg in pairs(obj.args) do
      obj.args[key] = patch_arg(arg)
    end
    -- TODO call patch_arg on return values as well
    -- local new_called = {}
    -- for _, call in ipairs(obj.called) do
    --   table.insert(new_called, patch(call))
    -- end
    M.patch(obj.called)
  end
end

-- local function has_fn(objs)
--   for _, obj in ipairs(objs) do
--     for key, arg in pairs(obj.args) do
--       if type(arg) == "function" then print"FOUND" end
--     end
--     has_fn(obj.called)
--   end
-- end

function M.record_finish(testname)
  sess = testname
end

-- local whitelist = {
--   -- ["overseer"] = true,
--   ["alternate"] = true,
--   -- ["alternate"] = {test = true},
--   -- ["vim._editor"] = true,
--   ["vim._editor"] = {
--     ["api"] = {
--       ["nvim_list_wins"] = true
--     },
--   },
--   -- ["nvim-task"] = true,
--   -- ["nvim-task.config"] = true,
--   -- ["vim.keymap"] = true,
--   -- ["table"] = true,
--   -- ["string"] = true,
--   -- ["debug"] = true,
-- }

-- TODO preprocess whitelist into more programmatic format

-- if true then return M end

local _unpack = unpack
local _select = select
local _pack = function(...) return { n = _select("#", ...), ... } end

-- local submodstring = function(modname, submodnames)
--   return modname .. "." .. vim.fn.join(submodnames, ".")
-- end
local traced_calls = nil

local function find_parent_fn(varname, _vari,  cb)
  local vari = _vari or 1
  local parent_i = 3
  while true do
    if not debug.getinfo(parent_i) then break end
    local n, v = debug.getlocal(parent_i, vari)
    if n and n == varname then
      cb(n, v)
      break
    end
    if not _vari and n then
      vari = vari + 1
    else
      parent_i = parent_i + 1
    end
  end
end

local function trace_wrap(modname, submodnames, mod, fnname, fn)
  local key = M.modfun_key(modname, submodnames, fnname)
  local wrapped = function (...)
    disable = true
    local args = {...}

    local call_obj = {module = modname, submodules = submodnames, func = fnname, key = key, args = args, called = {}}

    local toplevel = traced_calls[key] ~= nil
    find_parent_fn("call_obj", 2, function(_, v)
      if traced_calls[v.key] and traced_calls[v.key][key] then
        toplevel = false
        table.insert(v.called, call_obj)
      end
    end)

    disable = false

    -- if true then return val(...) end -- FIXME for some reason we lose access to the full stack doing this

    local ret = _pack(fn(...))

    disable = true

    if toplevel then
      find_parent_fn("nvt_mapping", nil, function(_, v)
        call_obj.mapping = vim.fn.keytrans(vim.api.nvim_replace_termcodes(v, true, true, true))
      end)
      table.insert(call_objs, call_obj)
    end

    disable = false

    return _unpack(ret, 1, ret.n)
  end
  mod[fnname] = function (...)
    if disable then
      return fn(...)
    else
      return wrapped(...)
    end
  end
end

local function extend_wl_fn(whitelist, modname, submodnames, fnname)
  local wl = whitelist
  wl[modname] = wl[modname] or {}
  wl = wl[modname]
  for _, submodname in ipairs(submodnames) do
    wl[submodname] = wl[submodname] or {}
    wl = wl[submodname]
  end
  wl[fnname] = true
end

function M.get_whitelist(traced_calls_raw)
  local whitelist = {}
  local new_traced_calls = {}
  for toplevel, traceds in pairs(traced_calls_raw) do
    extend_wl_fn(whitelist, toplevel.modname, toplevel.submodnames, toplevel.fnname)
    local key = M.modfun_key(toplevel.modname, toplevel.submodnames, toplevel.fnname)
    for traced, _ in pairs(traceds) do
      new_traced_calls[key] = new_traced_calls[key] or {}
      new_traced_calls[key][M.modfun_key(traced.modname, traced.submodnames, traced.fnname)] = true
      extend_wl_fn(whitelist, traced.modname, traced.submodnames, traced.fnname)
    end
  end
  return whitelist, new_traced_calls
end

function M.add_trace_wrappers(whitelist, new_traced_calls)
  traced_calls = new_traced_calls
  M.foreach_modfn(trace_wrap, whitelist)
end

-- M.add_trace_wrappers(M.get_whitelist({
--   [{
--     modname = "alternate",
--     submodnames = {},
--     fnname = "test"
--   }] = {
--       [{
--         modname = "vim._editor",
--         submodnames = {"api"},
--         fnname = "nvim_list_wins"
--       }] = true
--     }
-- }))
--
-- vim.keymap.set(
--   { "n", "o", "x" },
--   "<C-p>",
--   function ()
--     -- local tbl = vim.F.pack_len("a", nil, "c")
--     -- vim.F.unpack_len(tbl)
--     -- require('alternate').test()
--     print"HERE 3!"
--   end
-- )

return M
-- TODO incremental recordings scoped to session?
