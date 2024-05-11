local M = {}

M.saved_sessname = "NvimTask_saved"
M.temp_sessname = "NvimTask_curr"

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

function M.save_session () -- save to default slot
  -- FIXME do this without setting any "state" w.r.t the current session
  require"resession".save(M.saved_sessname, { dir = sessiondir })
end

vim.keymap.set("n", "<leader>S", M.save_session)

vim.keymap.set("n", "<leader>F", function () -- save a new session
  vim.ui.input({ prompt = "Session name" }, function(name)
    if name then
      require"resession".save(name, { dir = sessiondir })
    end
  end)
end)

vim.keymap.set("n", "<leader>A", function ()
  require"resession".load(nil, { dir = sessiondir })
end)

-- Gets the current session name, reading vim.g.NvimTaskSession if no session is loaded yet.
local function get_session_name()
  local curr_sessname = require"resession".get_current()
  if curr_sessname then return curr_sessname end

  return vim.g.NvimTaskSession
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = vim.schedule_wrap(function()
    local sess = get_session_name()
    if M.session_exists(sess, sessiondir) then
      require"resession".load(sess, { dir = sessiondir, silence_errors = true })
      M.msgview_enable()
    end
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
    local sess = get_session_name()
    if sess == M.temp_sessname and not abort_temp_save then -- auto-save temporary session
      require"resession".save(sess, { dir = sessiondir, notify = false })
    end

    update_task_data()
  end,
})

return M
-- TODO incremental recordings scoped to session?
