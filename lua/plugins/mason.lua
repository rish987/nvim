return {
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate", -- :MasonUpdate updates registry contents
    lazy = false,
    init = function ()
      require"mason".setup {}

      local lspconfig = require "lspconfig"

      local settings_override = {
        ["lua_ls"] = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            diagnostics = {
              disable = {"duplicate-set-field", "duplicate-doc-field"}
            },
            workspace = {
              checkThirdParty = false,
            },
          }
        },
        ["fennel_language_server"] = {
          fennel = {
            workspace = {
              -- If you are using hotpot.nvim or aniseed,
              -- make the server aware of neovim runtime files.
              library = vim.api.nvim_list_runtime_paths(),
            },
          }
        },
      }

      local servers = { "lua_ls", "rust_analyzer", "clangd", "clojure_lsp", "texlab", "fennel_language_server"}
      for _, server in ipairs(servers) do
        local opts = {}

        local override = settings_override[server]
        if override then opts.settings = override end

        opts.on_attach = require "lsp_config".on_attach
        opts.capabilities = require('cmp_nvim_lsp').default_capabilities()

        lspconfig[server].setup(opts)
      end
      require"mason"
    end,
    dependencies = {
      "neovim/nvim-lspconfig"
    }
  },
  "folke/neodev.nvim",
}
