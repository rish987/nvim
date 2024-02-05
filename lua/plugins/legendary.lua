return {
  'mrjones2014/legendary.nvim',
  -- since legendary.nvim handles all your keymaps/commands,
  -- its recommended to load legendary.nvim before other plugins
  priority = 10000,
  lazy = false,
  -- sqlite is only needed if you want to use frecency sorting
  -- dependencies = { 'kkharji/sqlite.lua' }
  opts = {
    include_builtin = true,
    keymaps = {
      {"<leader>l", ":Legendary<cr>"},

      {"<leader>Q", ":qa!<cr>"},
      {"<leader>E", ":edit<cr>"},
      {"<leader>w", ":w<cr>"},
      {"<leader>cl", ":ccl<cr>"},
      {"<leader>xx", ":q<cr>"},
      {"<leader>p", ":set paste<CR>"},
      {"<leader>np", ":set nopaste<CR>"},
      {"<leader>m", ":setlo nomodifiable<CR>"},
      {"<leader>M", ":setlo modifiable<CR>"},
      {"<leader>L", ":LspInfo<CR>"},
      {"<leader>sc", ":ToggleTermContextClear<CR>"},
      {"<leader>sl", ":ToggleTermLast<CR>"},
      {"<leader>sn", ":ToggleTermNew<CR>"},
      -- {"<leader>Tt", ":tabnew<CR>"},
      -- {"<leader>pp", ':let @" = join(readfile("/home/gcloud/temp"), "\\n")<CR>'},
      -- {"<leader>yy", ":call writefile(getreg('\"', 1, 1), \"/home/pugobat11144/temp\", \"S\")<CR>"},
      -- {"<leader>cp", ":let @\" = expand(\"%\")<CR>"},
      {"<leader>o", ":mes<CR>"},
      {"<leader>k", ":set winfixheight<CR>"},
      {"<leader>h", ":set winfixwidth<CR>"},
      {"<C-j>", "<C-d>"},
      {"<C-t>", "g,"},
      {"<C-f>", "g;"},
      {"<C-k>", "<C-u>"},
      {"<C-j>", "<C-d>"},
      {"<C-k>", "<C-u>"},
      {'Z', 'z'},
      {'ZZ', 'zz'},
      {'GG', 'G'},
      {"<C-h>", "<C-^>"},
      {"<leader>D", ":bd<CR>"},
    }
  }
}
