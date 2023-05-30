require "mason".setup {}
local lspconfig = require "lspconfig"

require("neodev").setup({
  -- add any options here, or leave empty to use the default settings
})

local servers = { "lua_ls", "rust_analyzer", "clangd", "clojure_lsp", "texlab", "fennel_language_server"}
for _, server in ipairs(servers) do
  local opts = {}

  if server == "lua_ls" then
    opts.settings = {
      Lua = {
        completion = {
          callSnippet = 'Replace',
        },
      },
    }
  elseif server == "fennel_language_server" then
    opts.settings = {
      fennel = {
        workspace = {
          -- If you are using hotpot.nvim or aniseed,
          -- make the server aware of neovim runtime files.
          library = vim.api.nvim_list_runtime_paths(),
        },
      },
    }
  end

  opts.on_attach = require "lsp_config".on_attach
  opts.capabilities = require('cmp_nvim_lsp').default_capabilities()

  lspconfig[server].setup(opts)
end
