return {
  "folke/noice.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    lsp = {
      -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
      },
    },
    messages = {
      enabled = true
    },
    cmdline = {
      enabled = true
    },
    notify = {
      enabled = true
    },
    -- you can enable a preset for easier configuration
    presets = {
      bottom_search = true, -- use a classic bottom cmdline for search
      command_palette = true, -- position the cmdline and popupmenu together
      long_message_to_split = true, -- long messages will be sent to a split
      inc_rename = true, -- enables an input dialog for inc-rename.nvim
      lsp_doc_border = false, -- add a border to hover docs and signature help
    },
    commands = {
      history = {
        -- options for the message history that you get with `:Noice`
        view = "split",
        opts = { enter = true, format = "details" },
        filter = {
          event = "msg_show",
        },
      },
    }
  },
  dependencies = {
    -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
    "MunifTanjim/nui.nvim",
  }
}
