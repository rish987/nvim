return {
  {
    "Julian/lean.nvim",
    ft = {"lean", "lean3"}, -- TODO unnecessary? will this just be done when loading the filetype file?
    opts = function()
      local bin_name = 'lean-language-server'
      local args = { '--stdio', '--', '-M', '16384', '-T', '100000' }
      local cmd = { bin_name, unpack(args) }
      return {
        progress_bars = {
          -- Enable the progress bars?
          enable = false,
          -- What character should be used for the bars?
          character = '│',
          -- Use a different priority for the signs
          priority = 10,
        },
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
            --width = 120,
            width = 60,
            autoopen = false,
            indicators = "auto",
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
          capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())
        },

        lsp = {
          on_attach = require"lsp_config".on_attach,
          capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())
        },

        -- Redirect Lean's stderr messages somehwere (to a buffer by default)   
        stderr = {
          enable = true,
          height = 20,
          -- a callback which will be called with (multi-line) stderr output    
          -- e.g., use:                                                         
          --   on_lines = function(lines) vim.notify(lines) end                 
          -- if you want to redirect stderr to `vim.notify`.                    
          -- The default implementation will redirect to a dedicated stderr     
          -- window.                                                            
          on_lines = nil,
        },
      }
    end
  }
}
