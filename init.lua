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
      }, -- For example {"folke"}
      fallback = false, -- Fallback to git when local plugin doesn't exist
    },
    change_detection = {
      -- automatically check for config file changes and reload the ui
      enabled = true,
      notify = false, -- get a notification when changes are found
    },
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

-- vim.cmd.colorscheme "catppuccin"

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

  autocmd! FileType help :wincmd H | :vert resize 90 " open help window vertically

  autocmd TermOpen * setlocal nonumber

  " Return to last edit position when opening files (You want this!)
  autocmd BufReadPost *
       \ if line("'\"") > 0 && line("'\"") <= line("$") |
       \   exe "normal! g`\"" |
       \ endif
  
  set guifont=DejaVuSansM\ Nerd\ Font\ Mono:h8:i
  set mouse=a

  nnoremap gp `[v`]
]])
