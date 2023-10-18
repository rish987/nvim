return {
  {
    "hrsh7th/nvim-cmp",
    lazy = false,
    config = function (_, _)
      local cmp = require"cmp"

      local opts = {
        snippet = {
          -- REQUIRED - you must specify a snippet engine
          expand = function(args)
            require'luasnip'.lsp_expand(args.body)
          end,
        },
        mapping = {
          ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
          ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
          ['<C-b>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
          ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
          ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
          ['<C-y>'] = cmp.config.disable, -- Specify `cmp.config.disable` if you want to remove the default `<C-y>` mapping.
          ['<C-e>'] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
          }),
          ['<C-u>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
        },
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
          --{
          --  name = "dictionary",
          --  keyword_length = 2,
          --},
        }),
        experimental = {
          ghost_text = true -- this feature conflict with copilot.vim's preview.
        },
        formatting = {
          format = require"lspkind".cmp_format(),
        }
      }
      cmp.setup(opts)

      -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline('/', {
        sources = {
          { name = 'buffer' }
        }
      })

      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(':', {
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          { name = 'cmdline' }
        })
      })

      -- If you want insert `(` after select function or method item
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      cmp.event:on(
        'confirm_done',
        cmp_autopairs.on_confirm_done()
      )
    end,
    -- event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer", -- buffer completions
      "hrsh7th/cmp-path", -- path completions
      "hrsh7th/cmp-cmdline", -- cmdline completions
      "saadparwaiz1/cmp_luasnip", -- snippet completions
      "uga-rosa/cmp-dictionary", -- dictionary completions
    }
  },
}
