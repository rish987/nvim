local util = require"config_util"

-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.mapleader = " "
vim.g.maplocalleader = "  "

-- set termguicolors to enable highlight groups
vim.o.termguicolors = true

vim.o.completeopt = "menu,menuone,noselect"
vim.o.hidden = true
vim.o.cursorline = true
vim.o.hlsearch = true
vim.o.number = true
-- vim.o.cindent = true
vim.o.expandtab = true
vim.o.timeout = false
vim.o.history = 1000
vim.o.jumpoptions = "stack"
vim.o.softtabstop=2
vim.o.tabstop=2
vim.o.shiftwidth=2
vim.o.mouse = ""
vim.o.exrc = true

-- local keymap = vim.keymap.set
-- vim.keymap.set = function(mode, lhs, rhs, opts)
--   local new_rhs = rhs
--   if type(rhs) == "function" then
--     new_rhs = function() vim.schedule(rhs) end
--   end
--   keymap(mode, lhs, new_rhs, opts)
-- end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("rooter")

require("lazy").setup("plugins",
  {
    dev = {
      -- directory where you store your local plugin projects
      path = "~/plugins",
      ---@type string[] plugins that match these patterns will use your local versions instead of being fetched from GitHub
      patterns = {
        -- "hrsh7th/nvim-cmp",
        -- "hrsh7th/cmp-buffer",
        "ggandor/leap.nvim",
        -- "Julian/lean.nvim",
        -- "jonatan-branting/nvim-better-n",
        "stevearc/overseer.nvim",
        "akinsho/bufferline.nvim",
      }, -- For example {"folke"}
      fallback = false, -- Fallback to git when local plugin doesn't exist
    },
    change_detection = {
      -- automatically check for config file changes and reload the ui
      enabled = true,
      notify = false, -- get a notification when changes are found
    },
  })

vim.api.nvim_create_autocmd("WinClosed", {
  nested = true,
  callback = function(args)
    if vim.api.nvim_get_current_win() ~= tonumber(args.match) then return end
    vim.cmd.wincmd "p"
  end,
})

-- -- auto-close quickfix/location after leaving it
-- au("WinLeave", function(_)
--   local winid = vim.api.nvim_get_current_win()
--   local wininfo = vim.fn.getwininfo(winid)[1]
--
--   if wininfo.loclist == 0 and wininfo.quickfix == 0 then
--     return
--   end
--   vim.api.nvim_win_close(winid, true)
-- end)

--require"vim.lsp.log".set_level("debug")
require("multifun")

require("alternate")

require("jump-textobj")

local locations_to_items = vim.lsp.util.locations_to_items
vim.lsp.util.locations_to_items = function (locations, offset_encoding)
  local newLocations = {}
  local lines = {}
  local loc_i = 1
  for _, loc in ipairs(vim.deepcopy(locations)) do
    local uri = loc.uri or loc.targetUri
    local range = loc.range or loc.targetSelectionRange
    if not lines[uri .. range.start.line] then
      table.insert(newLocations, loc)
      loc_i = loc_i + 1
    else -- already have a location on this line
      table.remove(locations, loc_i) -- also remove from the original list
    end
    lines[uri .. range.start.line] = true
  end

  return locations_to_items(newLocations, offset_encoding)
end

local ran_local_cfg = {}

-- TODO override default exrc behavior to this
vim.api.nvim_create_autocmd("BufRead", {
  callback = function ()
    local cfgs = vim.fs.find('.nvim.lua', {
      upward = true,
      stop = vim.loop.os_homedir(),
      path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
    })
    if #cfgs == 0 then return end
    local config = cfgs[1]

    local dir = vim.fn.fnamemodify(config, ":h")

    if ran_local_cfg[dir] then return end
    if config ~= "" then
      local orig_map = vim.keymap.set
      vim.keymap.set = function (mode, lhs, rhs, opts)
        local bufs_set = {}
        local set_map_buf =
          function ()
            local file = vim.api.nvim_buf_get_name(0)
            if file:match(dir) then -- FIXME better match
              if bufs_set[file] then return end
              -- print("CUSTOM MAP: ", lhs, file, bufs_set[file])
              opts = opts or {}
              opts.buffer = true
              orig_map(mode, lhs, rhs, opts)
              bufs_set[file] = true
            end
          end

        -- set for the buffer that invoked the config
        set_map_buf()

        -- set for any newly opened buffers under this directory
        vim.api.nvim_create_autocmd("BufRead", {
          callback = set_map_buf
        })
      end

      vim.cmd("luafile " .. config)

      vim.keymap.set = orig_map
    end
    ran_local_cfg[dir] = true
  end
})

local help_open = false

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function (_)
    if vim.o.ft == "help" and not help_open then
      vim.cmd.wincmd"L"
      vim.cmd("vert resize 80")
      vim.cmd("set winfixwidth")
      -- require"nvim-tree.api".tree.close()
      help_open = true
    end
  end
})

vim.api.nvim_create_autocmd("WinClosed", {
    nested = true,
    callback = function(args)
      if vim.api.nvim_get_current_win() ~= tonumber(args.match) then return end
      vim.cmd.wincmd "p"
    end,
  })

-- vim.api.nvim_create_autocmd("BufWinLeave", {
--   callback = function (_)
--     print(vim.o.ft)
--     if vim.o.ft == "help" and help_open then
--       require"nvim-tree.api".tree.open()
--       help_open = false
--     end
--   end
-- })

-- vim.cmd.colorscheme "catppuccin"

vim.keymap.set("n", "<leader>v", function ()
  for _, file in ipairs(vim.v.oldfiles) do
    local file_stat = vim.loop.fs_stat(file)
    if file_stat and file_stat.type == "file" then
      vim.cmd.edit(file)
      return
    end
  end
end)

vim.o.shada = "!,'1000,<1000,s10,h"

vim.cmd([[
  autocmd FileType lean3 set shiftwidth=2
  autocmd FileType lean3 set tabstop=2
  autocmd FileType lean set nocindent
  autocmd FileType lua set shiftwidth=2
  autocmd FileType lua set tabstop=2
  autocmd FileType rust set shiftwidth=2
  autocmd FileType rust set tabstop=2
  autocmd FileType tex set shiftwidth=2
  autocmd FileType tex set tabstop=2

  autocmd TermOpen * setlocal nonumber

  " Return to last edit position when opening files (You want this!)
  autocmd BufReadPost *
       \ if line("'\"") > 0 && line("'\"") <= line("$") |
       \   exe "normal! g`\"" |
       \ endif
  
  set guifont=DejaVuSansM\ Nerd\ Font:h8:i

  set mouse=a
  set undofile

  " nnoremap gp `[v`]
]])
