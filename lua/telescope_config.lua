local util = require"config_util"
util.nmap("<leader>fp", ":lua require('telescope.builtin').planets()<CR>")
util.nmap("<leader>ff", ":lua require('telescope.builtin').find_files()<CR>")
util.nmap("<leader>fg", ":lua require('telescope.builtin').live_grep()<CR>")
util.nmap("<leader>fb", ":lua require('telescope.builtin').buffers()<CR>")
util.nmap("<leader>fh", ":lua require('telescope.builtin').help_tags()<CR>")
