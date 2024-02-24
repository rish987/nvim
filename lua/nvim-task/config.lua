local M = {}

M.get_sessiondir = function(dir)
  return "nvim-task/" .. dir
end

M.saved_sessname = "NvimTask_saved"
M.curr_sessname = "NvimTask_curr"

if not vim.g.StartedByNvimTask then return M end

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

local function file_exists(filename)
    local stat = vim.loop.fs_stat(filename)
    return stat ~= nil and stat.type ~= nil
end

local function session_exists(sessname)
  local sess_filename = require"resession.util".get_session_file(sessname, sessiondir)
  return file_exists(sess_filename)
end

local function get_session_name()
  local curr_sessname = resession.get_current()
  if curr_sessname then return curr_sessname end

  if vim.g.NvimTaskSession == "NvimTaskDefault" then
    if session_exists(M.saved_sessname) then return M.saved_sessname end
    return M.curr_sessname
  end

  return vim.g.NvimTaskSession
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local sess = get_session_name()
    if session_exists(sess) then
      resession.load(sess, { dir = sessiondir, silence_errors = true })
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local sess = get_session_name()
    if sess == M.curr_sessname then -- only auto-save "curr" session
      resession.save(sess, { dir = sessiondir, notify = false })
    end
  end,
})

return M
-- TODO incremental recordings scoped to session?
