require"nvim-lsp-installer".setup {}
local lspconfig = require"lspconfig"

local servers = {"sumneko_lua", "rust_analyzer", "clangd", "clojure_lsp"}
for _, server in ipairs(servers) do
  local opts = {}

  if server == "sumneko_lua" then
    opts = require("lua-dev").setup({ lspconfig = opts })
  end
  opts.on_attach = require"lsp_config".on_attach
  opts.capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

  lspconfig[server].setup(opts)
end
