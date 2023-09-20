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

require"luasnip_config"

require"telescope_config"

require"surround_config"

require"hop_config"

require"toggleterm_config"

require"neogit_config"

require"winpick_config"

require"resession_config"

require"tabby_config"

require"firenvim_config"

require"vimtex_config"

require"neoscroll_config"

require"lualine_config"

require"autopairs_config"

--require"qf_config"

require"comment_config"

require"tree_config"

require"devicons_config"

require"diffview_config"

--require"vgit_config"

require"easyalign_config"

local au = function(events, callback, opts)
  opts = opts or {}
  opts.callback = callback
  vim.api.nvim_create_autocmd(events, opts)
end

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
