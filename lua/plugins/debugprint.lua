return {
  "andrewferrier/debugprint.nvim",
  opts = {
    print_tag = "DBG"
  },
  -- Dependency only needed for NeoVim 0.8
  dependencies = {
    "nvim-treesitter/nvim-treesitter"
  },
  create_keymaps = false,
  -- Remove the following line to use development versions,
  -- not just the formal releases
  version = "*",
  init = function ()
    vim.keymap.set("n", "<Leader>dd", function()
      -- Note: setting `expr=true` and returning the value are essential
      vim.fn.feedkeys(require('debugprint').debugprint())
    end)
    vim.keymap.set("n", "<Leader>Dd", function()
      -- Note: setting `expr=true` and returning the value are essential
      vim.fn.feedkeys(require('debugprint').debugprint({ above = true }))
    end)
    vim.keymap.set("n", "<Leader>dq", function()
      -- Note: setting `expr=true` and returning the value are essential
      vim.fn.feedkeys(require('debugprint').debugprint({ variable = true }))
    end)
    vim.keymap.set("n", "<Leader>Dq", function()
      -- Note: setting `expr=true` and returning the value are essential
      vim.fn.feedkeys(require('debugprint').debugprint({ above = true, variable = true }))
    end)
    vim.keymap.set("n", "<Leader>dv", function()
      -- Note: setting `expr=true` and returning the value are essential
      vim.fn.feedkeys(require('debugprint').debugprint({ ignore_treesitter = true, variable = true }))
    end)
    vim.keymap.set("n", "<Leader>do", function()
      -- Note: setting `expr=true` and returning the value are essential
      -- It's also important to use motion = true for operator-pending motions
      return require('debugprint').debugprint({ motion = true })
    end, {
        expr = true,
      })
    vim.keymap.set("n", "<Leader>dD", function(opts)
      return require('debugprint').deleteprints(opts)
    end)
    vim.keymap.set("v", "<Leader>d", function()
      vim.fn.feedkeys(require('debugprint').debugprint({variable = true}))
    end)
  end
}
