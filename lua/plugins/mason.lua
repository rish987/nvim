return {
  {
    "williamboman/mason.nvim",
    priority = 10000,
    build = ":MasonUpdate", -- :MasonUpdate updates registry contents
    lazy = false,
    init = function ()
      require"mason".setup {}
      require"neodev".setup {}

      local lspconfig = require "lspconfig"

      local library = vim.api.nvim_get_runtime_file('lua', true)
      -- local library = vim.api.nvim_get_runtime_file("", true)
      -- vim.list_extend(library, {"~/.local/share/nvim/lazy/plenary.nvim/lua"})

      local settings_override = {
        ["lua_ls"] = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            runtime = {
              -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
              version = 'LuaJIT',
              -- Setup your lua path
              path = vim.split(package.path, ';')
            },
            diagnostics = {
              disable = {"duplicate-set-field", "duplicate-doc-field", "missing-fields", "need-check-nil"},
              -- Get the language server to recognize the `vim` global
              globals = {
                'vim',
                'require'
              },
            },
            -- Do not send telemetry data containing a randomized but unique identifier
            telemetry = {
              enable = false,
            },
            workspace = {
              -- Make the server aware of Neovim runtime files
              library = library,
              checkThirdParty = false,
            },
          }
        },

        -- ["fennel_language_server"] = {
        --   fennel = {
        --     workspace = {
        --       -- If you are using hotpot.nvim or aniseed,
        --       -- make the server aware of neovim runtime files.
        --       library = vim.api.nvim_list_runtime_paths(),
        --     },
        --   }
        -- },
      }

      local servers = { "lua_ls", "rust_analyzer", "clangd", "clojure_lsp", "texlab", "fennel_ls"}
      for _, server in ipairs(servers) do
        local opts = {}

        local override = settings_override[server]
        if override then opts.settings = override end

        opts.on_attach = require "lsp_config".on_attach
        opts.capabilities = require('cmp_nvim_lsp').default_capabilities()

        lspconfig[server].setup(opts)
      end
    end,
    dependencies = {
      "neovim/nvim-lspconfig"
    }
  },
  {
    "folke/neodev.nvim",
    opts = {
      library = {
        enabled = true, -- when not enabled, neodev will not change any settings to the LSP server
        -- these settings will be used for your Neovim config directory
        runtime = true, -- runtime path
        types = true, -- full signature, docs and completion of vim.api, vim.treesitter, vim.lsp and others
        plugins = true, -- installed opt or start plugins in packpath
        -- you can also specify the list of plugins to make available as a workspace library
        -- plugins = { "nvim-treesitter", "plenary.nvim", "telescope.nvim" },
      },
    }
  }
}
