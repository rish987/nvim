vim.g.vimtex_compiler_latexmk = {
  ['options'] = {
    '-verbose',
    '-file-line-error',
    '-xelatex',
    '-synctex=1',
    '-interaction=nonstopmode',
  },
}

vim.g.vimtex_view_method = "zathura"
vim.g.vimtex_view_enabled = true
vim.g.vimtex_view_general_options = "--mode fullscreen @pdf"
