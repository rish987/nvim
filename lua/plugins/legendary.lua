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
      -- {"<leader>l", "<Cmd>Legendary<cr>"},

      {"<leader>Q", "<Cmd>qa!<cr>"},
      {"<leader>E", "<Cmd>edit<cr>"},
      {"<leader>w", "<Cmd>w<CR>"},
      {"<leader>cl", "<Cmd>ccl<CR>"},
      {"<leader>p", "<Cmd>set paste<CR>"},
      {"<leader>P", "<Cmd>set nopaste<CR>"},
      {"<leader>m", "<Cmd>setlo nomodifiable<CR>"},
      {"<leader>M", "<Cmd>setlo modifiable<CR>"},
      {"<leader>L", "<Cmd>LspInfo<CR>"},
      {"<leader>R", "<Cmd>LspRestart<CR>"},
      {"<leader>sc", "<Cmd>ToggleTermContextClear<CR>"},
      {"<leader>sl", "<Cmd>ToggleTermLast<CR>"},
      {"<leader>sn", "<Cmd>ToggleTermNew<CR>"},
      -- {"<leader>Tt", "<Cmd>tabnew<CR>"},
      -- {"<leader>pp", '<Cmd>let @" = join(readfile("/home/gcloud/temp"), "\\n")<CR>'},
      -- {"<leader>yy", "<Cmd>call writefile(getreg('\"', 1, 1), \"/home/pugobat11144/temp\", \"S\")<CR>"},
      -- {"<leader>cp", "<Cmd>let @\" = expand(\"%\")<CR>"},
      {"<leader>o", "<Cmd>mes<CR>"},
      -- {"<leader>N", "<Cmd>Noice<CR>"},
      -- {"<leader>k", "<Cmd>set winfixheight<CR>"},
      {"<leader>h", "<Cmd>set winfixwidth<CR>"},
      {"<C-j>", "<C-d>"},
      {"<C-i>", "<C-i>"},
      {"<C-t>", "g,"},
      {"<C-g>", "g;"},
      {"<C-k>", "<C-u>"},
      {"<C-j>", "<C-d>"},
      {"<C-k>", "<C-u>"},
      {"<c-A-q>", "q"},
      {'Z', 'z'},
      {'ZZ', 'zz'},
      {'GG', 'G'},
      {"<C-h>", "<C-^>"},
      {"gh", "g<Tab>"},
      {"<leader>D", "<Cmd>Bdelete<CR>"},
      {"<leader>n", "/<C-p><CR>"}, -- to get around better-n when necessary
      {"<leader>N", "?<C-p><CR>"}, -- to get around better-n when necessary
      {"<C-Tab>", "<Cmd>bn<CR>"},
      {"<C-b>", "<Cmd>bp<CR>"},
    }
  }
}
