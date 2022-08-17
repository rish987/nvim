local util = require"config_util"

require"hop".setup({
  keys = 'asdfjklrughqwetyiopzxcvbnm'
})
vim.cmd("hi HopCursor ctermbg=Green")

util.nmap("sl", ":HopWordAC<CR>")
util.nmap("sh", ":HopWordBC<CR>")
