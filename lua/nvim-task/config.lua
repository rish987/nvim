local M = {}

M.get_sessiondir = function(dir)
  return "nvim-task/" .. dir
end

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

local data_file = vim.fn.stdpath("data") .. "/" .. "nvim-task-state.json"

function M.read_data()
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
    -- print('DBG[2]: config.lua:30: txt=' .. vim.inspect(txt))
    return ret
  else
    return {}
  end
end

function M.erase_data(key)
  local data = M.read_data()
  data[key] = nil

  local json = vim.fn.json_encode(data)
  vim.fn.writefile({json}, data_file)
end

function M.write_data(new_data)
  local data = vim.tbl_extend("keep", new_data, M.read_data())

  local json = vim.fn.json_encode(data)
  vim.fn.writefile({json}, data_file)
end

if not vim.g.StartedByNvimTask then return M end

vim.o.swapfile = false

local resession = require"resession"

local sessiondir = M.get_sessiondir(vim.g.NvimTaskDir)

vim.keymap.set("n", "<leader>S", function () -- save to default slot
  resession.save(M.saved_sessname, { dir = sessiondir })
end)

vim.keymap.set("n", "<leader>F", function () -- save a new session
  resession.save(nil, { dir = sessiondir })
end)

vim.keymap.set("n", "<leader>A", function ()
  require"resession".load(nil, { dir = sessiondir })
end)

-- Gets the current session name, reading vim.g.NvimTaskSession if no session is loaded yet.
local function get_session_name()
  local curr_sessname = resession.get_current()
  if curr_sessname then return curr_sessname end

  return vim.g.NvimTaskSession
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local sess = get_session_name()
    if M.session_exists(sess, sessiondir) then
      resession.load(sess, { dir = sessiondir, silence_errors = true })
    end
  end,
})

local recorded_register

vim.api.nvim_create_autocmd("RecordingLeave", {
  callback = function()
    recorded_register = vim.fn.reg_recording()
  end,
})

vim.keymap.set("n", "<leader>X", function ()
  local sess = get_session_name()
  M.write_data({reset_sess = sess})
end)

local log = require"vim.lsp.log"

local function modify_data(name, opts, modify_fn)
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

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local abort_temp_save = M.read_data().abort_temp_save

    local sess = get_session_name()
    M.write_data({reset_sess = sess})

    if recorded_register then
      modify_data(nil, {dir = sessiondir},
        function (data)
          data["nvim-task"] = {registers = {[recorded_register] = vim.fn.getreg(recorded_register)}}
          return data
        end
      )
    end

    if sess == M.temp_sessname and not abort_temp_save then -- only auto-save temporary session
      resession.save(sess, { dir = sessiondir, notify = false })
    end
  end,
})

return M
-- TODO incremental recordings scoped to session?
