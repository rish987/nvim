local nvt_conf = require"nvim-task.config"

local M = {}
local tracedisp_format_sub = [["%s".%s.%s]]
local tracedisp_format = [["%s".%s]]
local function modfn_to_str(modname, submodnames, fnname)
  if #submodnames == 0 then
    return tracedisp_format:format(modname, fnname)
  end
  return tracedisp_format_sub:format(modname, vim.fn.join(submodnames, "."), fnname)
end

local function trace_previewer()
  return require"telescope.previewers".new_buffer_previewer({
    define_preview = function(self, entry)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, true, vim.split("", "\n"))
    end,
  })
end

local function modfn_picker(results, title, attach_mappings)
  -- TODO async delay until socket is connected

  local finders = require "telescope.finders"
  local pickers = require "telescope.pickers"
  local conf = require("telescope.config").values

  if vim.tbl_isempty(results) then
    vim.notify("No traceable functions", vim.log.levels.WARN)
    return
  end

  local opts = {}

  return pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table {
        results = results,
        entry_maker = function(entry)
          local disp = modfn_to_str(entry.modname, entry.submodnames, entry.fnname)
          return {
            value = entry,
            display = disp,
            ordinal = disp,
          }
        end
      },
      -- sorter = conf.generic_sorter(opts),
      -- previewer = conf.grep_previewer(opts),
      attach_mappings = attach_mappings,
      sorter = conf.generic_sorter(opts),
      previewer = trace_previewer()
    })
end

local function __trace_picker_subcall(results, traced_calls, key, cb)
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  return modfn_picker(string.format("Choose subcalls to trace for %s",
    key),
    function(prompt_bufnr, map)
      map("n", "<Esc>", function()
        actions.close(prompt_bufnr)
        cb()
      end)
      map("n", "K", function()
        local selection = action_state.get_selected_entry()
        traced_calls[selection.value] = true
      end)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        traced_calls[selection.value] = true
        actions.close(prompt_bufnr)
        cb()
      end)
      return true
    end)
end

local function __trace_picker_toplevel(results, traced_calls, cb)
  traced_calls = traced_calls or {}
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  local picker = modfn_picker(results, string.format("Choose functions to trace"),
    function(prompt_bufnr, map)
    map("n", "<Esc>", function()
      actions.close(prompt_bufnr)
      cb(traced_calls)
    end)
    actions.select_default:replace(function()
      local selection = action_state.get_selected_entry()
      vim.schedule(function()
        traced_calls[selection.value] = {}
        local subcall_picker = __trace_picker_subcall(traced_calls[selection.value],
          nvt_conf.modfun_key(selection.value.modname, selection.value.submodnames, selection.value.fnname, true),
          function ()
            __trace_picker_toplevel(traced_calls, cb)
          end)
        if subcall_picker then
          subcall_picker:find()
        end
      end)
    end)
    return true
  end)
  if picker then
    picker:find()
  else
    cb({})
  end
end

-- M._trace_picker_toplevel = require"plenary.async".wrap(__trace_picker_toplevel, 3)

return M
