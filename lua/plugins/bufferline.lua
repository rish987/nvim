return {
  'akinsho/bufferline.nvim',
  config = function (_, opts)
    require("bufferline").setup(opts)
  end,
  init = function ()
    -- vim.keymap.set('n', 'Q', "q")
    -- vim.keymap.set('n', '<leader>q', "Q")
    vim.keymap.set('n', 'q', require("bufferline").pick)
    vim.api.nvim_create_autocmd({"DirChanged"},
    {
      callback = function (info) require("bufferline.tabpages").rename_tab(vim.api.nvim_get_current_tabpage(), vim.fn.fnamemodify(info.file, ":t"))  end,
    })
    vim.api.nvim_create_autocmd({"TabEnter", "VimEnter"},
    {
      callback = function () require("bufferline.tabpages").rename_tab(vim.api.nvim_get_current_tabpage(), vim.fn.fnamemodify(vim.loop.cwd(), ":t"))  end,
    })
    local exclude_subdirs = {".lake"}
    vim.api.nvim_create_autocmd({"BufEnter"},
    {
      callback = function (info)
          local ignore = not info.file:match(vim.loop.cwd())
          if not ignore then
            for _, dir in ipairs(exclude_subdirs) do
              if info.file:match(vim.loop.cwd() .. "/" .. dir) then
                ignore = true
                break
              end
            end
          end
          if ignore then vim.api.nvim_buf_set_option(0, "buflisted", false) end
        end,
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
  dependencies = {'nvim-tree/nvim-web-devicons', 'nvim-lua/plenary.nvim'}
}
