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

local msgview_buf, msgview_win

function M.open_messageview()
  if msgview_buf then return end

  local orig_win = vim.api.nvim_get_current_win()
  msgview_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[msgview_buf].ft = "NvimTaskMsgView"
  -- FIXME use vim.api.nvim_open_win instead (recent feature)
  vim.cmd("rightbelow vsplit")
  vim.api.nvim_win_set_buf(0, msgview_buf)
  msgview_win = vim.api.nvim_get_current_win()
  vim.cmd("set winfixwidth")
  vim.cmd("set winfixwidth")
  vim.cmd("vertical resize 80")
  vim.api.nvim_set_current_win(orig_win)
end

M.ns = vim.api.nvim_create_namespace("nvim-task")
local ui_opts = {
  ext_messages = true,
  ext_cmdline = true,
  ext_popupmenu = true
}

local msgview_enabled = false

function M.msgview_enable()
  if msgview_enabled then return end
  vim.ui_attach(M.ns, ui_opts, function(event, kind, msg_data, _)
    if event ~= "msg_show" then return end
    if not msgview_win then M.open_messageview() end

    local msgs_text = vim.api.nvim_buf_get_text(msgview_buf, 0, 0, -1, -1, {})
    local num_lines = #msgs_text
    local last_line_length = #msgs_text[num_lines]

    local cursorpos = vim.api.nvim_win_get_cursor(msgview_win)
    local at_bottom = cursorpos[1] == num_lines

    local msg_text = msg_data[1][2]
    msg_text = vim.fn.join(vim.tbl_map(function(value) return "  " .. value end, vim.split(msg_text, "\n")), "\n")
    local msg = vim.split(("(%s, %s):\n%s"):format(event, kind or "[nil]", msg_text), "\n")

    local new_text = last_line_length == 0 and msg or {"", unpack(msg)}
    vim.api.nvim_buf_set_text(msgview_buf, num_lines - 1, last_line_length, num_lines - 1, last_line_length, new_text)

    -- autoscroll
    if at_bottom then
      vim.fn.win_execute(msgview_win, "normal! G")
    end
  end)
  msgview_enabled = true
end

if vim.v.vim_did_enter == 0 then
  -- Schedule loading after VimEnter. Get the UI up and running first.
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = M.msgview_enable
,
  })
else
  -- Schedule on the event loop
  vim.schedule(M.msgview_enable)
end

-- vim.keymap.set("n", "<leader>x", function ()
--   print("HERE")
-- end)
-- vim.keymap.set("n", "<leader>X", function ()
--   prin("HERE")
-- end)

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
local set_map = {}

vim.api.nvim_create_autocmd("RecordingLeave", {
  callback = function()
    recorded_register = vim.fn.reg_recording()
  end,
})

local keymap_str = ':lua require"nvim-task.config".set_keymap("%s", "<c-x>", [[  ]])' .. vim.api.nvim_replace_termcodes("<C-f>bh", true, true, true)

function M.set_keymap(mode, map, str)
  vim.keymap.set(mode, "<c-x>", loadstring(str))
  set_map[mode] = str
end

vim.keymap.set("n", "<leader>Xn", function ()
  vim.fn.feedkeys(keymap_str:format("n"))
end)

vim.keymap.set("n", "<leader>Xi", function ()
  vim.fn.feedkeys(keymap_str:format("i"))
end)

local log = require"vim.lsp.log"
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
  print(filename, vim.inspect{data["nvim-task"]})
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
  if recorded_register then
    task_data.registers = {[recorded_register] = vim.fn.getreg(recorded_register)}
  end
  if next(set_map) then
    task_data.map = set_map
  end
  if next(task_data) then
    modify_data(task_data)
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local abort_temp_save = M.read_data().abort_temp_save

    local sess = get_session_name()
    M.write_data({reset_sess = sess})

    if sess == M.temp_sessname and not abort_temp_save then -- only auto-save temporary session
      resession.save(sess, { dir = sessiondir, notify = false })
    end

    update_task_data()
  end,
})

return M
-- TODO incremental recordings scoped to session?
