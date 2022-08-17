local bin_name = 'lean-language-server'
local args = { '--stdio', '--', '-M', '16384', '-T', '100000' }
local cmd = { bin_name, unpack(args) }

require('lean').setup{
  -- Abbreviation support
  abbreviations = {
      -- Set one of the following to true to enable abbreviations
      builtin = true, -- built-in expander
      compe = false, -- nvim-compe source
      -- additional abbreviations:
      extra = {
          -- Add a \wknight abbreviation to insert ♘
          --
          -- Note that the backslash is implied, and that you of
          -- course may also use a snippet engine directly to do
          -- this if so desired.
          wknight = '♘',
      },
      -- change if you don't like the backslash
      -- (comma is a popular choice on French keyboards)
      leader = '\\',
  },
  ft = { default = "lean" },
  -- Enable suggested mappings?
  --
  -- false by default, true to enable
  mappings = true,
  -- Enable the infauxview?
  infoview = {
      -- Clip the infoview to a maximum width
      support_hop = true,
      width = 55,
      autoopen = true,
      indicators = "always",
      separate_tab = false
  },
  -- Enable the Lean3(lsp3)/Lean4(lsp) language servers?
  --
  -- false to disable, otherwise should be a table of options to pass to
  --  `leanls`. See https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md#leanls
  -- for details though lean-language-server actually doesn't support all
  -- the options mentioned there yet.
  lsp3 = {
    cmd = cmd,
    on_attach = require"lsp_config".on_attach,
    capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
  },

  lsp = {
    on_attach = require"lsp_config".on_attach,
    capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
  }
}
