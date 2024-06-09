local nvt_conf = require "nvim-task.config"
local db = require "nvim-task.db"

local M = {}

local sessionload_fmt = [[resession.load("%s", { dir = "%s" })]] -- session name, directory
local spyon_fmt = [[spy.on(%s, "%s")]] -- table, entry
local spyassert_fmt = [[    assert.spy(%s).was_called_with(%s)]] -- function name, arg list
local call_fmt = [[    %s(%s)]] -- function name, arg list
local feedkeys_fmt = [[    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("%s", true, true, true))]] -- keys from recording
local feedkeys_fmt_noreplace = [[    vim.fn.feedkeys("%s")]] -- keys from recording

local testfile_fmt = [[
local spy = require('luassert.spy')
local resession = require"resession"

-- load session
%s

-- set all spies
%s

describe("auto-generated test", function()
  it("'%s'", function()
%s
  end)
end)
]]

function M.get_funcpath(obj)
  local modulestr = ([[require"%s"]]):format(obj.module)
  local modulepath = #obj.submodules > 0 and modulestr .. "." .. vim.fn.join(obj.submodules, ".") or modulestr
  return modulepath .. "." .. obj.func, modulepath
end

local function generate_spyons(calltrace, generated)
  for _, obj in ipairs(calltrace) do
    local funcpath, modulepath = M.get_funcpath(obj)
    if not generated[funcpath] then
      generated[funcpath] = spyon_fmt:format(modulepath, obj.func)
    end
    generate_spyons(obj.called, generated)
  end
  return generated
end

local function generate_args_string(obj)
  local args_string = ""
  for i, arg in ipairs(obj.args) do
    local a_str = vim.inspect(arg) -- TODO make sure that this works if a is a string containing single/double quote characters
    if i ~= #obj.args then
      args_string = args_string .. a_str .. ", "
    else
      args_string = args_string .. a_str
    end
  end
  return args_string
end

local function generate_call(obj)
  return call_fmt:format(M.get_funcpath(obj), generate_args_string(obj))
end

local function generate_spyassert(obj)
  return spyassert_fmt:format(M.get_funcpath(obj), generate_args_string(obj))
end

local function generate_feedkeys(map)
  if vim.api.nvim_replace_termcodes(map, true, true, true) == map then
    return feedkeys_fmt_noreplace:format(map)
  end
  return feedkeys_fmt:format(map)
end

local function generate_spyasserts(calltrace, generated, depth)
  for i, obj in ipairs(calltrace) do
    table.insert(generated, generate_spyassert(obj))
    generate_spyasserts(obj.called, generated, depth + 1)
  end
  return generated
end

function M.make_test(test, data)
  local calltrace = nvt_conf.unpatch(data.calltrace)

  local sessionload_str = sessionload_fmt:format(data.sess, db.sessiondir)
  local spyon_strs = {}
  for _, str in pairs(generate_spyons(calltrace, {})) do
    table.insert(spyon_strs, str)
  end
  local spyon_str = vim.fn.join(spyon_strs, "\n")

  local remaining_recording = data.recording
  local pending_test_strs = {}

  local test_strs = {}
  for i, obj in ipairs(calltrace) do
    local tbl = pending_test_strs
    if obj.mapping then
      tbl = test_strs
      local map_pos_start, map_pos_end = remaining_recording:find(obj.mapping, nil, true)
      local recording_before_map = remaining_recording:sub(1, map_pos_start - 1)
      if #recording_before_map > 0 then
        table.insert(tbl, generate_feedkeys(recording_before_map))
        for _, str in ipairs(pending_test_strs) do
          table.insert(tbl, str)
        end
        table.insert(tbl, "")
        pending_test_strs = {}
      end
      remaining_recording = remaining_recording:sub(map_pos_end + 1)
      table.insert(tbl, generate_call(obj))
    else
      table.insert(tbl, generate_spyassert(obj))
    end

    for _, str in ipairs(generate_spyasserts(obj.called, {}, 0)) do
      table.insert(tbl, str)
    end

    if i ~= #calltrace or #remaining_recording > 0 then
      table.insert(tbl, "")
    end
  end

  if #remaining_recording > 0 then
    table.insert(test_strs, generate_feedkeys(remaining_recording))
    if #pending_test_strs > 0 then table.insert(test_strs, "") end
    for _, str in ipairs(pending_test_strs) do
      table.insert(test_strs, str)
    end
    pending_test_strs = {}
  end

  local test_str = vim.fn.join(test_strs, "\n")

  local testfile_str = testfile_fmt:format(sessionload_str, spyon_str, test, test_str)

  local test_filepath = db.testdir .. ("/%s_spec.lua"):format(test)
  vim.fn.writefile(vim.fn.split(testfile_str, "\n"), test_filepath)
  print("wrote", test_filepath)
end
