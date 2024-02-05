return {
  'rmagatti/goto-preview',
  opts = {
    focus_on_open = false
  },
  init = function ()
    vim.keymap.set('n', 'Gd', require('goto-preview').goto_preview_definition)
    vim.keymap.set('n', 'GD', require('goto-preview').goto_preview_type_definition)
    vim.keymap.set('n', 'gx', require('goto-preview').close_all_win)
  end
}
