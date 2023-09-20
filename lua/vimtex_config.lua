vim.g.vimtex_compiler_latexmk = {
  ['options'] = {
    '-verbose',
    '-file-line-error',
    '-xelatex',
    '-synctex=1',
    '-interaction=nonstopmode',
  },
}

vim.g.vimtex_view_method = "sioyek"
vim.g.vimtex_view_enabled = true
vim.g.vimtex_view_general_options = "--new-window"
vim.g.vimtex_quickfix_open_on_warning = false
vim.g.vimtex_quickfix_ignore_filters = {
       'LaTeX Font Warning',
       'Overfull',
      }
