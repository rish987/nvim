return {
  {
    'glacambre/firenvim',
    build = function() vim.fn['firenvim#install'](0) end,
    lazy = false,
    config = function ()
      if not vim.g.started_by_firenvim == true then return end

      local util = require"config_util"

      util.nmap("<leader>q", ":w<cr>:qa!<cr>")

      vim.api.nvim_create_autocmd({'BufEnter'}, {
        pattern = "github.com_*.txt",
        command = "set filetype=markdown"
      })

      -- vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
      --   callback = function(e)
      --     if vim.g.timer_started == true then
      --       return
      --     end
      --     vim.g.timer_started = true
      --     vim.fn.timer_start(1000, function()
      --       vim.g.timer_started = false
      --       vim.cmd.write()
      --     end)
      --   end
      -- })

      -- FIXME does not work
      --vim.api.nvim_create_autocmd('BufEnter', {
      --    pattern = "www.google.com_.*.txt",
      --    command = [[inoremap <CR> <Esc>:w<CR>:call firenvim#press_keys("<LT>CR>")<CR>]],
      --})

      vim.g.firenvim_config = {
        globalSettings = {
          -- ['<C-s>'] = 'noop',
        },
        localSettings = {
          ["https://www.mail.google.com/*"] = {
            takeover = "never"
          },
          ["https://www.google.com/*"] = {
            takeover = "never"
          },
          [".*"] = {
            cmdline  = "neovim",
            content  = "text",
            priority = 0,
            --selector = "textarea",
            takeover = "never"
          }
        }
      }

      vim.o.spell = true
      vim.o.spelllang = "en_us"
      vim.b.catppuccin_dark = true
      vim.cmd.colorscheme "catppuccin-mocha"

      vim.keymap.set("n", "<C-x>", function()
        vim.b.catppuccin_dark = not vim.b.catppuccin_dark
        if vim.b.catppuccin_dark then
          vim.cmd.colorscheme "catppuccin-mocha"
        else
          vim.cmd.colorscheme "catppuccin-latte"
        end
      end)
    end
  }
}
