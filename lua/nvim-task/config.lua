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

function M.read_data(data_file)
  if vim.fn.filereadable(data_file) ~= 0 then
    local ret = {}
    local readfn = function ()
      ret = vim.fn.json_decode(vim.fn.readfile(data_file))
    end
    local success = false
    for _ = 1, 1000 do
      success, _ = pcall(readfn)
      if success then break end
    end

    if not success then print("error reading json file") return {} end
    -- log.error( data_file .. "reading: " .. vim.inspect(ret))
    return ret
  else
    return {}
  end
end

function M.erase_data(data_file, key)
  local data = M.read_data(data_file)
  data[key] = nil

  local json = vim.fn.json_encode(data)
  vim.fn.writefile({json}, data_file)
end

function M.write_data(data_file, new_data)
  local data = vim.tbl_extend("keep", new_data, M.read_data(data_file))

  -- log.error( data_file .. " writing: " .. vim.inspect(data))
  local json = vim.fn.json_encode(data)
  vim.fn.writefile({json}, data_file)
end

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

function M.foreach_modfn(cb, wl)
  for modname, module in pairs(package.loaded) do
    local seen_mods = {}
    if type(module) == "table" and modname ~= "package" and modname ~= "_G" then
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

local parent_sock = vim.fn.sockconnect("pipe", vim.g.NvimTaskParentSock, {rpc = true})
vim.fn.rpcnotify(parent_sock, "nvim_exec_lua", "require'nvim-task'.set_child_sock()", {})

vim.o.swapfile = false

M.ns = vim.api.nvim_create_namespace("nvim-task")

local msgview_enabled = false

function M.msgview_enable()
  if msgview_enabled then return end
	require("bmessages").toggle({ split_type = "vsplit", keep_focus = true, split_size_vsplit = 80, split_direction = "botright"})
  msgview_enabled = true
end

vim.keymap.set("n", "<leader>xn", function ()
  print("HERE")
end)

local sessiondir = vim.g.NvimTaskSessionDir

local sess = vim.g.NvimTaskSess

function M.save_session () -- save to default slot
  -- FIXME do this without setting any "state" w.r.t the current session
  require"resession".save(M.saved_test_name, { dir = sessiondir })
  sess = nil
end

-- vim.keymap.set("n", "<leader>A", function ()
--   require"resession".load(nil, { dir = sessiondir })
-- end)

vim.api.nvim_create_autocmd("VimEnter", {
  callback = vim.schedule_wrap(function()
    if M.session_exists(sess, sessiondir) then
      require"resession".load(sess, { dir = sessiondir, silence_errors = true })
    else
      sess = M.temp_test_name
    end
    M.msgview_enable()
  end),
})

-- vim.keymap.set("n", "<leader>Xn", function ()
--   vim.fn.feedkeys(keymap_str:format("n"))
-- end)
--
-- vim.keymap.set("n", "<leader>Xi", function ()
--   vim.fn.feedkeys(keymap_str:format("i"))
-- end)

-- resession-generic

local abort_temp_save = false

function M.abort_temp_save()
  abort_temp_save = true
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if sess == M.temp_test_name and not abort_temp_save then -- auto-save temporary session
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

function M.enable_calltrace()
  disable = false
end

function M.disable_calltrace()
  disable = true
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
  local curr_objs = call_objs
  call_objs = {}
  M.patch(curr_objs)
  -- print('DBG[1]: config.lua:254: curr_objs=' .. vim.inspect(curr_objs))
  -- has_fn(curr_objs)
  -- vim.fn.json_encode(curr_objs)
  return curr_objs
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
local traced_calls = {
  ["alternate.test"] = {["vim._editor.api.nvim_list_wins"] = true}
}

local function find_parent_fn(vari, varname, cb)
  local parent_i = 3
  while true do
    if not debug.getinfo(parent_i) then break end
    local n, v = debug.getlocal(parent_i, vari)
    if n and n == varname then
      cb(n, v)
      break
    end
    parent_i = parent_i + 1
  end
end

local function trace_wrap(modname, submodnames, mod, fnname, fn)
  local key = M.modfun_key(modname, submodnames, fnname)
  local wrapped = function (...)
    disable = true
    local args = {...}

    local call_obj = {module = modname, submodules = submodnames, func = fnname, key = key, args = args, called = {}}

    local toplevel = traced_calls[key] ~= nil
    find_parent_fn(2, "call_obj", function(_, v)
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
      find_parent_fn(1, "nvt_mapping", function(_, v)
        call_obj.mapping = v
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

function M.set_traced_calls(traced_calls_raw)
  local whitelist = {}
  for toplevel, traceds in pairs(traced_calls_raw) do
    extend_wl_fn(whitelist, toplevel.modname, toplevel.submodnames, toplevel.fnname)
    local key = M.modfun_key(toplevel.modname, toplevel.submodnames, toplevel.fnname)
    for _, traced in ipairs(traceds) do
      traced_calls[key] = traced_calls[key] or {}
      traced_calls[key][M.modfun_key(traced.modname, traced.submodnames, traced.fnname)] = true
      extend_wl_fn(whitelist, traced.modname, traced.submodnames, traced.fnname)
    end
  end

  disable = true
  M.foreach_modfn(trace_wrap, whitelist)
  disable = false
end

M.set_traced_calls({
  [{
    modname = "alternate",
    submodnames = {},
    fnname = "test"
  }] = {
    {
      modname = "vim._editor",
      submodnames = {"api"},
      fnname = "nvim_list_wins"
    }
  }
})

vim.keymap.set(
  { "n", "o", "x" },
  "<C-p>",
  function ()
    -- local tbl = vim.F.pack_len("a", nil, "c")
    -- vim.F.unpack_len(tbl)
    require('alternate').test()
    print"HERE"
  end
)

return M
-- TODO incremental recordings scoped to session?
