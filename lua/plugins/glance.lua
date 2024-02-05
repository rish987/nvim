return {
  'dnlhc/glance.nvim',
  init = function ()
    vim.keymap.set('n', 'Zd', '<CMD>Glance definitions<CR>')
    vim.keymap.set('n', 'ZD', '<CMD>Glance type_definitions<CR>')
  end
}
