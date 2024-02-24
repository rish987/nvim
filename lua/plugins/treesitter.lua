return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function ()
      local configs = require("nvim-treesitter.configs")

      configs.setup({
        ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "fennel" },
        sync_install = false,
        highlight = { enable = true},
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "gnn", -- set to `false` to disable one of the mappings
            node_incremental = "grn",
            scope_incremental = "grc",
            node_decremental = "grm",
          },
        },
        textobjects = {
          select = {
            enable = true,

            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,

            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["al"] = "@loop.outer",
              ["il"] = "@loop.inner",
              ["aa"] = "@assignment.outer",
              ["ia"] = "@assignment.inner",
              ["sl"] = "@assignment.lhs",
              ["sr"] = "@assignment.rhs",
              ["at"] = "@conditional.outer",
              ["it"] = { query = "@conditional.inner", desc = "Select inner part of a conditional" },
              ["ac"] = "@call.outer",
              ["ic"] = "@call.inner",
            },
            -- You can choose the select mode (default is charwise 'v')
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * method: eg 'v' or 'o'
            -- and should return the mode ('v', 'V', or '<c-v>') or a table
            -- mapping query_strings to modes.
            selection_modes = {
              -- ['@parameter.outer'] = 'v', -- charwise
              -- ['@function.outer'] = 'V', -- linewise
              -- ['@class.outer'] = '<c-v>', -- blockwise
            },
            -- If you set this to `true` (default is `false`) then any textobject is
            -- extended to include preceding or succeeding whitespace. Succeeding
            -- whitespace has priority in order to act similarly to eg the built-in
            -- `ap`.
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * selection_mode: eg 'v'
            -- and should return true of false
            -- include_surrounding_whitespace = true,
          }
        },
        additional_vim_regex_highlighting = false,
      })
    end,
    lazy = false,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
  },
  {
    "ziontee113/syntax-tree-surfer",
    opts = {},
    init = function ()
      local opts = {noremap = true, silent = true}

      -- Normal Mode Swapping:
      -- Swap The Master Node relative to the cursor with it's siblings, Dot Repeatable
      vim.keymap.set("n", "zs", function()
        vim.opt.opfunc = "v:lua.STSSwapUpNormal_Dot"
        return "g@l"
      end, { silent = true, expr = true })
      vim.keymap.set("n", "zS", function()
        vim.opt.opfunc = "v:lua.STSSwapDownNormal_Dot"
        return "g@l"
      end, { silent = true, expr = true })

      -- -- Swap Current Node at the Cursor with it's siblings, Dot Repeatable
      -- vim.keymap.set("n", "zd", function()
      --   vim.opt.opfunc = "v:lua.STSSwapCurrentNodeNextNormal_Dot"
      --   return "g@l"
      -- end, { silent = true, expr = true })
      -- vim.keymap.set("n", "vu", function()
      --   vim.opt.opfunc = "v:lua.STSSwapCurrentNodePrevNormal_Dot"
      --   return "g@l"
      -- end, { silent = true, expr = true })

      --> If the mappings above don't work, use these instead (no dot repeatable)
      -- vim.keymap.set("n", "vd", '<cmd>STSSwapCurrentNodeNextNormal<cr>', opts)
      -- vim.keymap.set("n", "vu", '<cmd>STSSwapCurrentNodePrevNormal<cr>', opts)
      -- vim.keymap.set("n", "vD", '<cmd>STSSwapDownNormal<cr>', opts)
      -- vim.keymap.set("n", "vU", '<cmd>STSSwapUpNormal<cr>', opts)

      -- Visual Selection from Normal Mode
      vim.keymap.set("n", "zb", '<cmd>STSSelectMasterNode<cr>', opts)
      vim.keymap.set("n", "zm", '<cmd>STSSelectCurrentNode<cr>', opts)

      -- Select Nodes in Visual Mode
      vim.keymap.set("x", "zb", '<cmd>STSSelectPrevSiblingNode<cr>', opts)
      vim.keymap.set("x", "zm", '<cmd>STSSelectNextSiblingNode<cr>', opts)
      vim.keymap.set("x", "H", '<cmd>STSSelectParentNode<cr>', opts)
      vim.keymap.set("x", "L", '<cmd>STSSelectChildNode<cr>', opts)

      -- -- Swapping Nodes in Visual Mode
      -- vim.keymap.set("x", "<A-j>", '<cmd>STSSwapNextVisual<cr>', opts)
      -- vim.keymap.set("x", "<A-k>", '<cmd>STSSwapPrevVisual<cr>', opts)
    end,
    lazy = false
  },
}
