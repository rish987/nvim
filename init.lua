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
vim.o.softtabstop=4
vim.o.tabstop=4
vim.o.shiftwidth=4
vim.o.mouse = ""

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
        "hrsh7th/nvim-cmp",
        "hrsh7th/cmp-buffer",
        "ggandor/leap.nvim",
      }, -- For example {"folke"}
      fallback = false, -- Fallback to git when local plugin doesn't exist
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

util.nmap("<leader>Q", ":qa!<cr>")
util.nmap("<leader>E", ":edit<cr>")
util.nmap("<leader>w", ":w<cr>")
util.nmap("<leader>cl", ":ccl<cr>")
util.nmap("<leader>xx", ":q<cr>")
util.nmap("<leader>p", ":set paste<CR>")
util.nmap("<leader>np", ":set nopaste<CR>")
util.nmap("<leader>m", ":setlo nomodifiable<CR>")
util.nmap("<leader>M", ":setlo modifiable<CR>")
util.nmap("<leader>L", ":LspInfo<CR>")
util.nmap("<leader>sc", ":ToggleTermContextClear<CR>")
util.nmap("<leader>sl", ":ToggleTermLast<CR>")
util.nmap("<leader>sn", ":ToggleTermNew<CR>")
util.nmap("<leader>Tt", ":tabnew<CR>")
util.nmap("<leader>pp", ':let @" = join(readfile("/home/gcloud/temp"), "\\n")<CR>')
util.nmap("<leader>yy", ":call writefile(getreg('\"', 1, 1), \"/home/pugobat11144/temp\", \"S\")<CR>")
util.nmap("<leader>cp", ":let @\" = expand(\"%\")<CR>")
util.nmap("<leader>o", ":mes<CR>")
util.nmap("<leader>k", ":set winfixheight<CR>")
util.nmap("<leader>h", ":set winfixwidth<CR>")
util.nmap("<C-j>", "<C-d>")
util.nmap("<C-k>", "<C-u>")
util.vmap("<C-j>", "<C-d>")
util.vmap("<C-k>", "<C-u>")

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
