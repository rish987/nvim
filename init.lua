local util = require"config_util"

vim.g.mapleader = " "
vim.g.maplocalleader = "  "

vim.o.completeopt = "menu,menuone,noselect"
vim.o.hidden = true
vim.o.cursorline = true
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
vim.o.mouse = ""

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

require"winpick_config"

require"resession_config"

require"tabby_config"

require"firenvim_config"

require"vimtex_config"

require"neoscroll_config"

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
util.nmap("<leader>yy", ":call writefile(getreg('\"', 1, 1), \"/home/gcloud/temp\", \"S\")<CR>")
util.nmap("<leader>cp", ":let @\" = expand(\"%\")<CR>")

vim.cmd.colorscheme "catppuccin"

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
  
  set termguicolors

  nnoremap gp `[v`]
]])
