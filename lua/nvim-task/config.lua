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

local test = vim.g.NvimTaskTest
local named_test = false -- whether some particular test was loaded/saved (i.e. not using M.temp_test_name)

function M.save_session () -- save to default slot
  -- FIXME do this without setting any "state" w.r.t the current session
  require"resession".save(M.saved_test_name, { dir = sessiondir })
  named_test = true
end

-- vim.keymap.set("n", "<leader>A", function ()
--   require"resession".load(nil, { dir = sessiondir })
-- end)

vim.api.nvim_create_autocmd("VimEnter", {
  callback = vim.schedule_wrap(function()
    if M.session_exists(test, sessiondir) then
      if test ~= M.temp_test_name then named_test = true end
      require"resession".load(test, { dir = sessiondir, silence_errors = true })
    end
    M.msgview_enable()
  end),
})

local set_map = {}

local keymap_str = ':lua require"nvim-task.config".set_keymap("%s", "<c-x>", [[  ]])' .. vim.api.nvim_replace_termcodes("<C-f>bh", true, true, true)

function M.set_keymap(mode, map, str)
  vim.keymap.set(mode, "<c-x>", loadstring(str))
  set_map[mode] = str
end

-- vim.keymap.set("n", "<leader>Xn", function ()
--   vim.fn.feedkeys(keymap_str:format("n"))
-- end)
--
-- vim.keymap.set("n", "<leader>Xi", function ()
--   vim.fn.feedkeys(keymap_str:format("i"))
-- end)

-- resession-generic
local function _modify_data(name, opts, modify_fn)
  if not name then
    -- If no name, default to the current session
    name = require"resession".get_current()
  end
  opts = opts or {}
  local files = require"resession.files"
  local util = require"resession.util"
  local filename = util.get_session_file(name, opts.dir)
  local data = modify_fn(files.load_json_file(filename))
  files.write_json_file(filename, data)
end

local function modify_data(new_task_data)
  _modify_data(nil, {dir = sessiondir},
    function (data)
      local task_data = data["nvim-task"] or {}
      task_data = vim.tbl_extend("keep", new_task_data, task_data)
      data["nvim-task"] = task_data
      return data
    end)
end

local function update_task_data()
  local task_data = {}
  if next(set_map) then
    task_data.map = set_map
  end
  if next(task_data) then
    modify_data(task_data)
  end
end

local abort_temp_save = false

function M.abort_temp_save()
  abort_temp_save = true
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if not named_test and not abort_temp_save then -- auto-save temporary session
      require"resession".save(test, { dir = sessiondir, notify = false })
    end

    update_task_data()
  end,
})

-- require("spider")
-- vim.keymap.set(
--   { "n", "o", "x" },
--   "<C-A-w>",
--   "<cmd>lua require('spider').motion('w', {})<CR>",
--   { desc = "Spider-w" }
-- )

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

for mod_name, module in pairs(package.loaded) do
  if type(module) == "table" then
    local new_module = {}
    -- TODO handle metatable (and __index field in particular)
    for val_name, val in pairs(module) do
      if type(val) == "function" then
        new_module[val_name] = function (...)
          local args_string = ""
          local args = {...}
          for i, a in ipairs(args) do
            local a_str = vim.inspect(a) -- TODO make sure that this works if a is a string containing single/double quote characters
            if i ~= #args then
              args_string = args_string .. a_str .. ", "
            else
              args_string = args_string .. a_str
            end
          end
          -- print(('require"%s".%s(%s)'):format(mod_name, val_name, args_string))

          return val(...)
        end
      else
        new_module[val_name] = val
      end
    end

    setmetatable(new_module, getmetatable(module))

    package.loaded[mod_name] = new_module
  else
    -- print(mod_name, type(module))
  end

  ::continue::
end
return M
-- TODO incremental recordings scoped to session?
