local M = {}

M.saved_test_name = "NvimTask_saved"
M.temp_test_name = "NvimTask_curr"

local function file_exists(filename)
    local stat = vim.loop.fs_stat(filename)
    return stat ~= nil and stat.type ~= nil
end

M.session_exists = function(sessname, sessdir)
  local sess_filename = require"resession.util".get_session_file(sessname, sessdir)
  return file_exists(sess_filename)
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

vim.keymap.set(
  { "n", "o", "x" },
  "<C-p>",
  function ()
    require('alternate').test()
    print"HERE"
  end
)

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

local function patch(objs)
  local new_objs = {}
  for _, obj in pairs(objs) do
    local new_args = {}
    for _, arg in ipairs(obj.args) do
      if type(arg) == "function" then
        -- must erase functions because they cannot be passed via RPC/JSON encoded
        table.insert(new_args, "<erased fn>")
      else
        table.insert(new_args, arg)
      end
    end
    obj.args = new_args
    -- local new_called = {}
    -- for _, call in ipairs(obj.called) do
    --   table.insert(new_called, patch(call))
    -- end
    obj.called = patch(obj.called)

    table.insert(new_objs, obj)
  end
  return new_objs
end

function M.record_finish(testname)
  sess = testname
  local curr_objs = call_objs
  call_objs = {}
  return patch(curr_objs)
end

local whitelist = {
  -- ["overseer"] = true,
  ["alternate"] = true,
  ["vim._editor"] = {
    ["schedule"] = true,
    ["F"] = {["unpack_len"] = true}
  },
  -- ["nvim-task"] = true,
  -- ["nvim-task.config"] = true,
  -- ["vim.keymap"] = true,
  -- ["table"] = true,
  -- ["string"] = true,
  -- ["debug"] = true,
}

-- TODO preprocess whitelist into more programmatic format

local ignore_whitelist = false

-- vim.keymap.set(
--   { "n", "o", "x" },
--   "<C-p>",
--   function ()
--     test()
--   end
-- )

-- if true then return M end

local _unpack = unpack
local _select = select
local _pack = function(...) return { n = _select("#", ...), ... } end

-- local submodstring = function(modname, submodnames)
--   return modname .. "." .. vim.fn.join(submodnames, ".")
-- end

local wrapped_mods = {}

local function is_whitelisted(modname, submodnames, fnname)
end

-- return of false indicates that this module is not whitelisted
-- return of nil indicates that this module completely whitelisted
-- return of table indicates that this module completely whitelisted
local function get_submod_whitelist(modname, submodnames, fnname)
  if ignore_whitelist then return true end
  if not whitelist[modname] then return false end
  if whitelist[modname] == true then return true end
  local wl = whitelist[modname]
  -- if not(type(whitelist[modname])) == "table" then return false end
  for _, submodname in ipairs(submodnames) do
    if not wl[submodname] then return false end
    if wl[submodname] == true then return true end
    wl = wl[submodname]
  end

  if not wl[fnname] then return false end
  return true
end

local function trace_wrap(modname, submodnames, mod, wl)
  -- modules can be recursively nested, so this prevents an infinite loop
  wrapped_mods[mod] = true
  for val_name, val in pairs(mod) do
    local this_wl = wl
    if type(wl) == "table" then
      this_wl = wl[val_name]
    end
    if this_wl then
      if type(val) == "function" then
        if type(wl) == "table" then
          -- print(val_name) -- function specified in whitelist
        end
        local wrapped = function (...)
          disable = true
          local args = {...}
          -- for i, a in ipairs(args) do
          --   local a_str = vim.inspect(a) -- TODO make sure that this works if a is a string containing single/double quote characters
          --   if i ~= #args then
          --     args_string = args_string .. a_str .. ", "
          --   else
          --     args_string = args_string .. a_str
          --   end
          -- end
          -- local call_string = ('require"%s".%s(%s)'):format(mod_name, val_name, args_string)

          local call_obj = {module = modname, submodules = submodnames, func = val_name, args = args, called = {}}

          local parent_i = 2
          local has_parent = false
          while true do
            if not debug.getinfo(parent_i) then break end
            local n, v = debug.getlocal(parent_i, 2)
            if n and n == "call_obj" then
              has_parent = true
              table.insert(v.called, call_obj)
            end
            parent_i = parent_i + 1
          end

          disable = false

          -- if true then return val(...) end -- FIXME for some reason we lose access to the full stack doing this

          local ret = _pack(val(...))

          disable = true

          if not has_parent then
            table.insert(call_objs, call_obj)
          end

          disable = false

          return _unpack(ret, 1, ret.n)
        end
        mod[val_name] = function (...)
          if disable then
            return val(...)
          else
            return wrapped(...)
          end
        end
      elseif type(val) == "table" and not wrapped_mods[val] then
        local new_submodnames = vim.deepcopy(submodnames)
        table.insert(new_submodnames, val_name)
        trace_wrap(modname, new_submodnames, val, this_wl)
      end
    end
  end
end

disable = true
for modname, module in pairs(package.loaded) do
  -- if modname:match("vim") then
  --   print(modname)
  -- end

  if type(module) == "table" and modname ~= "package" then
    -- TODO handle metatable (and __index field in particular)
    local this_wl = whitelist
    if type(whitelist) == "table" then
      this_wl = whitelist[modname]
    end
    trace_wrap(modname, {}, module, this_wl)

    -- setmetatable(new_module, getmetatable(module))
    --
    -- -- if mod_name == "alternate" then
    -- --   print("replacing", module, "with", new_module)
    -- -- end
    -- package.loaded[mod_name] = new_module
  else
    -- print(mod_name, type(module))
  end

  ::continue::
end
disable = false

return M
-- TODO incremental recordings scoped to session?
