-- Array of file names indicating root directory. Modify to your liking.
local root_names = { '.git' }
local excluded_root_names = { '.lake' }
local ignore_filetypes = require"config_util".exclude_filetypes
local ignore_buftypes = { 'nofile', 'prompt', 'popup', 'terminal' }

-- Cache to use for speed up (at cost of possibly outdated results)
local root_cache = {}

-- whether each tab has already had its current directory set
local tcd_set = {}

local set_root = function()
  if tcd_set[vim.api.nvim_get_current_tabpage()] then return end -- don't set tabpage directory more than once
  if vim.tbl_contains(ignore_buftypes, vim.bo.buftype) or vim.tbl_contains(ignore_filetypes, vim.bo.filetype) then
    return
  end

  -- Get directory path to start search from
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then return end
  path = vim.fs.dirname(path) .. "/"

  -- Try cache and resort to searching upward for root directory
  local root = root_cache[path]
  if root == nil then
    for _, dir in ipairs(excluded_root_names) do
      if path:match(dir .. "/") then
        return
      end
    end
    local root_file = vim.fs.find(root_names, { path = path, upward = true })[1]
    if root_file == nil then return end
    root = vim.fs.dirname(root_file)
    root_cache[path] = root
  end

  -- Set current directory
  vim.cmd.tcd(root)
  print("cwd:", root)
  tcd_set[vim.api.nvim_get_current_tabpage()] = true
end

vim.api.nvim_create_autocmd({"VimEnter","BufReadPost","BufEnter"}, { nested = true, callback = set_root })
