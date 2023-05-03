local util = require"config_util"
if not vim.g.started_by_firenvim == true then return end

util.nmap("<leader>q", ":w<cr>:qa!<cr>")

vim.api.nvim_create_autocmd({'BufEnter'}, {
  pattern = "github.com_*.txt",
  command = "set filetype=markdown"
})

vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    callback = function(e)
        if vim.g.timer_started == true then
            return
        end
        vim.g.timer_started = true
        vim.fn.timer_start(1000, function()
            vim.g.timer_started = false
            vim.cmd.write()
        end)
    end
})

-- FIXME does not work
vim.api.nvim_create_autocmd('BufEnter', {
    pattern = "www.google.com_.*.txt",
    command = [[inoremap <CR> <Esc>:w<CR>:call firenvim#press_keys("<LT>CR>")<CR>]],
})

vim.g.firenvim_config = {
  globalSettings = {
    --['<C-w>'] = 'noop',
    --['<C-j>'] = 'noop',
    --['<C-k>'] = 'noop',
    --['<C-n>'] = 'noop',
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
      takeover = "once"
    }
  }
}
