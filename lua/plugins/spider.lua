return {
  "chrisgrieser/nvim-spider",
  init = function ()
    vim.keymap.set(
      { "n", "o", "x" },
      "<C-S-w>",
      "<cmd>lua require('spider').motion('w')<CR>",
      { desc = "Spider-w" }
    )
    vim.keymap.set(
      { "n", "o", "x" },
      "<C-S-e>",
      "<cmd>lua require('spider').motion('e')<CR>",
      { desc = "Spider-e" }
    )
    vim.keymap.set(
      { "n", "o", "x" },
      "<C-S-b>",
      "<cmd>lua require('spider').motion('b')<CR>",
      { desc = "Spider-b" }
    )
    vim.keymap.set("i", "<C-f>", "<Esc>l<cmd>lua require('spider').motion('w')<CR>i")
    vim.keymap.set("i", "<C-b>", "<Esc><cmd>lua require('spider').motion('b')<CR>i")
    vim.keymap.set("n", "cw", "cw", { remap = false })
    vim.keymap.set("n", "dw", "dw", { remap = false })
  end,
  dependencies = {
    	"theHamsta/nvim_rocks",
    	build = "pip3 install --user hererocks && python3 -mhererocks . -j2.1.0-beta3 -r3.0.0 && cp nvim_rocks.lua lua",
    	config = function() require("nvim_rocks").ensure_installed("luautf8") end,
    },
}
