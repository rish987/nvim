local resession = require('resession')
resession.setup({
  buf_filter = function(bufnr)
    return not vim.startswith(vim.api.nvim_buf_get_name(bufnr), "lean")
  end,
  autosave = {
    enabled = true,
    interval = 60,
    notify = false,
  },
})
-- Resession does NOTHING automagically, so we have to set up some keymaps
vim.keymap.set('n', '<leader>sss', resession.save)
vim.keymap.set('n', '<leader>ssl', resession.load)
vim.keymap.set('n', '<leader>ssd', resession.delete)
