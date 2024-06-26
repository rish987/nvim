local M = {}

function M.map(mode, shortcut, command)
  vim.api.nvim_set_keymap(mode, shortcut, command, { noremap = true, silent = true })
end

function M.nmap(shortcut, command)
  M.map('n', shortcut, command)
end

function M.imap(shortcut, command)
  M.map('i', shortcut, command)
end

function M.vmap(shortcut, command)
  M.map('v', shortcut, command)
end

function M.cmap(shortcut, command)
  M.map('c', shortcut, command)
end

function M.tmap(shortcut, command)
  M.map('t', shortcut, command)
end

M.exclude_filetypes = {"help", "NvimTree", "Codewindow", "NvimTaskMsgView"}

M.lazypluginpath = vim.fn.stdpath("data") .. "/lazy"
M.lazypath = M.lazypluginpath .. "/lazy.nvim"
M.devpluginpath = vim.loop.os_homedir() .. "/plugins"

return M
