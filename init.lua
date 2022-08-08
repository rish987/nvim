local util = require"config_util"

vim.g.mapleader = "'"
vim.g.maplocalleader = "''"

vim.o.completeopt = "menu,menuone,noselect"
vim.o.hidden = true
vim.o.hlsearch = true
vim.o.number = true
vim.o.cindent = true
vim.o.expandtab = true
vim.o.timeout = false
vim.o.history = 1000
vim.o.jumpoptions = "stack"
vim.o.softtabstop=4
vim.o.tabstop=4
vim.o.shiftwidth=4

require"plugins"

require"lsp_installer"

require"lsp_config"

require"lean_config"

require"nvimux_config"

require"gitsigns_config"

require"completion_config"

require"telescope_config"

require"surround_config"

require"hop_config"

require"luasnip_config"

require"toggleterm_config"

require"neogit_config"

--require"vim.lsp.log".set_level("debug")

util.nmap("<leader>q", ":qa!<cr>")
util.nmap("<leader>w", ":w<cr>")
util.nmap("<leader>c", ":ccl<cr>")
util.nmap("<leader>xx", ":q<cr>")
util.nmap("<leader>L", ":bn<cr>")
util.nmap("<leader>H", ":bp<cr>")
util.nmap("<leader>p", ":set paste<CR>")
util.nmap("<leader>np", ":set nopaste<CR>")
util.nmap("<leader>m", ":setlo nomodifiable<CR>")
util.nmap("<leader>M", ":setlo modifiable<CR>")
util.nmap("<leader>ll", ":LspInfo<CR>")
util.nmap("<leader>lr", ":LspRestart<CR>")
util.nmap("<leader>lR", ":LspRestart!<CR>")
util.nmap("<leader>ls", ":LspStop<CR>")
util.nmap("<leader>lS", ":LspStop!<CR>")
util.nmap("<leader>lt", ":LspStart<CR>")
util.nmap("<leader>lT", ":LspStart!<CR>")

vim.cmd([[
  autocmd FileType lean3 set shiftwidth=2
  autocmd FileType lean3 set tabstop=2
  autocmd FileType lua set shiftwidth=2
  autocmd FileType lua set tabstop=2
  autocmd FileType rust set shiftwidth=2
  autocmd FileType rust set tabstop=2

  autocmd TermOpen * setlocal nonumber
  
  colorscheme elflord
]])
