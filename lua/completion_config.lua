-- Setup nvim-cmp.
local cmp = require'cmp'

cmp.setup({
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
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
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
  }
})

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
local cmp = require('cmp')
cmp.event:on(
  'confirm_done',
  cmp_autopairs.on_confirm_done()
)

--local dict = require("cmp_dictionary")
--
--dict.setup({
--  exact = 1,
--  first_case_insensitive = true,
--  document = false,
--  document_command = "wn %s -over",
--  async = true,
--  sqlite = false,
--  max_items = -1,
--  capacity = 5,
--  debug = false,
--})
--
--dict.switcher({
--  filetype = {
--    --lua = "/path/to/lua.dict",
--    --javascript = { "/path/to/js.dict", "/path/to/js2.dict" },
--    --txt = "/usr/share/dict/en.dict",
--    --md = "/usr/share/dict/en.dict",
--    --tex = "/usr/share/dict/en.dict",
--  },
--  filepath = {
--    --[".*xmake.lua"] = { "/path/to/xmake.dict", "/path/to/lua.dict" },
--    --["%.tmux.*%.conf"] = { "/path/to/js.dict", "/path/to/js2.dict" },
--  },
--  spelllang = {
--    en = "/usr/share/dict/words",
--  },
--})
