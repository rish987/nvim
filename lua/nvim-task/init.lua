local overseer = require("overseer")
local actions = require "telescope.actions"
-- local sorters = require "telescope.sorters"
local action_state = require "telescope.actions.state"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
-- local utils = require "telescope.utils"
local conf = require("telescope.config").values
local resession = require"resession"
local recorder = require"recorder"

local dir = vim.g.StartedByNvimTask and "nvim-task-nested" or "nvim-task"
local root_dir = vim.fn.stdpath("data") .. "/" .. dir
vim.fn.mkdir(root_dir, "p")

local get_sessiondir = function(_dir)
  return dir .. "/sessions/" .. _dir
end

local state_file = root_dir .. "/nvim-task-state.json"

local nvt_conf = require "nvim-task.config"

-- local get_source_files = function()
--   local files = vim.split(vim.fn.glob("**/*.lua"), "\n")
--
--   return files
-- end

-- local function is_win()
--   return package.config:sub(1, 1) == '\\'
-- end
--
-- local function get_path_separator()
--   if is_win() then
--     return '\\'
--   end
--   return '/'
-- end
--
-- local function script_path()
--   local str = debug.getinfo(2, 'S').source:sub(2)
--   if is_win() then
--     str = str:gsub('/', '\\')
--   end
--   return str:match('(.*' .. get_path_separator() .. ')')
-- end
--
-- local config_file = script_path() .. get_path_separator() .. "config.lua"
--

local function get_dir_prefix()
  return (vim.fn.getcwd()):sub(2):gsub("/", "_")
end

local data_file = root_dir .. "/nvim-task.json"
local curr_session = vim.fn.filereadable(data_file) ~= 0 and vim.fn.json_decode(vim.fn.readfile(data_file)) or {}
-- TODO save/load from file

local function _set_curr_session(key, value)
  local curr_data = curr_session[key] or {}
  -- REMOVEME: back-compat
  if type(curr_data) == "string" then
    curr_data = {sess = curr_data}
  end

  curr_data = vim.tbl_extend("keep", value, curr_data)
  curr_session[key] = curr_data

  local json = vim.fn.json_encode(curr_session)
  vim.fn.writefile({json}, data_file)
end

local function set_curr_session(value)
  _set_curr_session(get_dir_prefix(), value)
end

local templates = {
  ["nvim"] = {
    builder = function(params)
      return {
        cmd = { "nvim" },
        args = {
          "--cmd", 'let g:StartedByNvimTask = "true"',
          "--cmd", ('let g:NvimTaskStateFile = "%s"'):format(state_file),
          "--cmd", ('let g:NvimTaskSessionDir = "%s"'):format(params.dir),
          "--cmd", ('let g:NvimTaskSession = "%s"'):format(params.sess),
        },
        strategy = "toggleterm",
        components = {
          "default",
        },
      }
    end,
  },
}

local curr_task, curr_task_dir

local abort_curr_task = function (cb)
  if curr_task then
    curr_task:stop()
    curr_task:dispose()
    curr_task = nil
    local aborted_task_dir = curr_task_dir
    curr_task_dir = nil

    print"task aborted"

    -- FIXME somehow properly wait for the task above to actually exit
    vim.schedule(function ()
      -- the old task may have saved a new session, if so update curr_session to use that one next time
      local reset_sess = nvt_conf.read_data(state_file).reset_sess
      if reset_sess then
        _set_curr_session(aborted_task_dir, {sess = reset_sess})
      end

      nvt_conf.erase_data(state_file, "reset_sess")

      if cb then cb() end
    end)
    return true
  end
  return false
end

vim.api.nvim_create_autocmd("QuitPre", { -- makes sure that the last session state is saved before quitting
  callback = function(_)
    abort_curr_task()
  end,
})

local function curr_sess()
  local sess_data = curr_session[get_dir_prefix()]
  if sess_data and type(sess_data) == "string" then
    sess_data = {sess = sess_data}
    set_curr_session(sess_data)
  end
  return sess_data
end

local function curr_sessname()
  local sess_data = curr_sess()
  return sess_data and sess_data.sess
end

local function get_curr_sess_win()
  if not curr_task then return nil end

  local win = curr_task.strategy.term.window
  -- the session may currently be un-toggled
  if not vim.api.nvim_win_is_valid(win) then return nil end

  return win
end

local function sess_is_open()
  return vim.api.nvim_get_current_win() == get_curr_sess_win() and vim.fn.mode() == "t"
end

-- vim.keymap.set("n", "<leader><leader>", function()
--   vim.cmd.rshada({bang = true})
--   print("reset sess value:", vim.g.NVIM_TASK_RESET_SESS)
-- end)
local play_recording_shortcut = "<tab>"
local _play_recording_shortcut = vim.api.nvim_replace_termcodes(play_recording_shortcut, true, true, true)

local function maybe_play_recording()
  local sess_data = curr_sess()
  if vim.fn.reg_recording() == "" and sess_data.recording then
    require"recorder".playRecording()
    return
  end
  vim.fn.feedkeys(_play_recording_shortcut)
end

-- TODO status line indicator for current recording and keymap to clear recording

local function task_cb (task)
  curr_task = task
  curr_task_dir = get_dir_prefix()
  vim.keymap.set("t", play_recording_shortcut, maybe_play_recording, {buffer = task.strategy.term.buffer})

  nvt_conf.erase_data(state_file, "abort_temp_save")
end

-- recording started in terminal?
local started_recording = false

local reg_override = "t"

vim.api.nvim_create_autocmd("User", {
  pattern = "NvimRecorderPlay",
  callback = function (_)
    if sess_is_open() then
      local sess_data = curr_sess()
      if sess_data.recording then
        vim.fn.setreg(reg_override, sess_data.recording, "c")
        recorder.setRegOverride(reg_override)
      end
    end
  end
})

vim.api.nvim_create_autocmd("User", {
  pattern = "NvimRecorderRecordStart",
  callback = function (_)
    if sess_is_open() then
      started_recording = true
      recorder.setRegOverride(reg_override)
    end
  end
})

vim.api.nvim_create_autocmd("User", {
  pattern = "NvimRecorderRecordEnd",
  callback = function (data)
    if started_recording --[[ and sess_is_open() ]] then
      set_curr_session({recording = data.data.recording})
    end
    started_recording = false
  end
})

local function _new_nvim_task(sess)
  if not sess then sess = curr_sessname() or nvt_conf.temp_sessname end

  set_curr_session({sess = sess}) -- probably not necessary
  print("loading task session:", sess)

  overseer.run_template({name = "nvim", params = {sess = sess, dir = get_sessiondir(get_dir_prefix())}}, task_cb)
end

local function new_nvim_task(sess)
  if not abort_curr_task(function() _new_nvim_task(sess) end) then
    _new_nvim_task(sess)
  end
end

local function sess_picker()
  local results = {}

  local sessions = resession.list({ dir = get_sessiondir(get_dir_prefix()) })
  if vim.tbl_isempty(sessions) then
    vim.notify("No saved sessions for this directory", vim.log.levels.WARN)
    return
  end

  for _, session in ipairs(sessions) do
    if session ~= nvt_conf.temp_sessname then
      table.insert(results, session)
    end
  end

  local opts = {}

  return pickers
    .new({}, {
      prompt_title = string.format("Choose session (curr: %s)", curr_sessname() or "[NONE]"),
      finder = finders.new_table {
        results = results,
        entry_maker = make_entry.gen_from_file(),
      },
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()

          actions.close(prompt_bufnr)
          new_nvim_task(selection.value)
        end)

        return true
      end,
    })
end

for name, template in pairs(templates) do
  template.name = name
  overseer.register_template(template)
end

local function restart()
  new_nvim_task()
end

local function save_restart()
  vim.cmd("write")
  restart()
end

local function blank_sess()
  nvt_conf.write_data(state_file, {abort_temp_save = true})

  if nvt_conf.session_exists(nvt_conf.temp_sessname, get_sessiondir(get_dir_prefix())) then
    resession.delete(nvt_conf.temp_sessname, { dir = get_sessiondir(get_dir_prefix()) })
  end

  new_nvim_task(nvt_conf.temp_sessname)
end

vim.keymap.set("n", "<leader>W", function () save_restart() end)
vim.keymap.set("n", "<leader>X", function () restart() end)
vim.keymap.set("n", "<leader>xx", function () abort_curr_task() end)
vim.keymap.set("n", "<leader>xf", function () sess_picker():find() end)
vim.keymap.set("n", "<leader>xb", function () blank_sess() end)

-- TODO mapping to open telescope to select explicitly saved sessions (under cwd)
-- TODO mapping to clear saved session

-- vim.keymap.set("n", "<leader>tc", function () run_template("check", {}) end)
-- vim.keymap.set("n", "<leader>to", function () run_only(vim.fn.input("enter constant names (comma-separated, no whitespace): ")) end)
-- vim.keymap.set("v", "<leader>to", function () run_only(region_to_text()) end)
-- vim.keymap.set("n", "<leader>tO", function () only_picker():find() end)
-- vim.keymap.set("n", "<leader>tf", function () transfile_picker():find() end)
-- vim.keymap.set("n", "<leader>tq", function () abort_curr_task() end)
-- vim.keymap.set("n", "<leader>t<Tab>", function () resume_prev_template() end)
