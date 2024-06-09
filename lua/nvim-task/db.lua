local nvt_conf = require "nvim-task.config"

local M = {}

-- use a different session-saving directory for nested instances
local dir = vim.g.StartedByNvimTask and "nvim-task-nested" or "nvim-task"
M.root_dir = vim.fn.stdpath("data") .. "/" .. dir
vim.fn.mkdir(M.root_dir, "p")

M.sessiondir = dir .. "/sessions"
M.testdir = M.root_dir .. "/tests"
vim.fn.mkdir(M.testdir, "p")

M.metadata_key = "__NvimTaskData"

M.data_file = M.root_dir .. "/nvim-task.json"

local tests_data = vim.fn.filereadable(M.data_file) ~= 0 and vim.fn.json_decode(vim.fn.readfile(M.data_file)) or {[M.metadata_key] = {}}

function M.set_test_data(test, value)
  local curr_data = tests_data[test] or {}

  curr_data = vim.tbl_extend("keep", value, curr_data)
  tests_data[test] = curr_data

  local json = vim.fn.json_encode(tests_data)
  vim.fn.writefile({json}, M.data_file)
end

function M.set_test_metadata(value)
  M.set_test_data(M.metadata_key, value)
end

function M.del_test_data(test)
  tests_data[test] = nil

  local json = vim.fn.json_encode(tests_data)
  vim.fn.writefile({json}, M.data_file)
end

function M.get_tests_data()
  return tests_data
end

function M.get_tests_metadata()
  return tests_data[M.metadata_key]
end


return M
