return {
  'akinsho/bufferline.nvim',
  config = function (_, opts)
    require("bufferline").setup(opts)
  end,
  init = function ()
    vim.keymap.set('n', 'Q', "q")
    vim.keymap.set('n', '<leader>q', "Q")
    vim.keymap.set('n', 'q', require("bufferline").pick)
    vim.api.nvim_create_autocmd({"DirChanged"},
    {
      callback = function (info) require("bufferline.tabpages").rename_tab(vim.api.nvim_get_current_tabpage(), vim.fn.fnamemodify(info.file, ":t"))  end,
    })
    vim.api.nvim_create_autocmd({"TabEnter", "VimEnter"},
    {
      callback = function () require("bufferline.tabpages").rename_tab(vim.api.nvim_get_current_tabpage(), vim.fn.fnamemodify(vim.loop.cwd(), ":t"))  end,
    })
  end,
  opts = {
    highlights = {
      tab_selected = {
        fg = "White"
      }
    },
    options = {
      offsets = {
        {
          filetype = "NvimTree",
          text = "File Explorer",
          text_align = "left",
          separator = true
        }
      },
    }
  },
  version = "*",
  dependencies = 'nvim-tree/nvim-web-devicons'
}
