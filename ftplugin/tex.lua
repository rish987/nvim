-- source: https://github.com/benbrastmckie/.config/blob/master/nvim/after/ftplugin/tex.lua

require("nvim-surround").buffer_setup({
  surrounds = {
    ["c"] = {
      add = function()
        local cmd = require("nvim-surround.config").get_input "Command: "
        return { { "\\" .. cmd .. "{" }, { "}" } }
      end,
    },
    ["e"] = {
      add = function()
        local env = require("nvim-surround.config").get_input "Environment: "
        return { { "\\begin{" .. env .. "}" }, { "\\end{" .. env .. "}" } }
      end,
    },
    ["Q"] = {
      add = { "``", "''" },
      find = "%b``.-''",
      delete = "^(``)().-('')()$",
    },
    ["q"] = {
      add = { "`", "'" },
      find = "`.-'",
      delete = "^(`)().-(')()$",
    },
    ["b"] = {
      add = { "\\textbf{", "}" },
      -- add = function()
      --   if vim.fn["vimtex#syntax#in_mathzone"]() == 1 then
      --     return { { "\\mathbf{" }, { "}" } }
      --   end
      --   return { { "\\textbf{" }, { "}" } }
      -- end,
      find = "\\%a-bf%b{}",
      delete = "^(\\%a-bf{)().-(})()$",
    },
    ["i"] = {
      add = { "\\textit{", "}" },
      -- add = function()
      --   if vim.fn["vimtex#syntax#in_mathzone"]() == 1 then
      --     return { { "\\mathit{" }, { "}" } }
      --   end
      --   return { { "\\textit{" }, { "}" } }
      -- end,
      find = "\\%a-it%b{}",
      delete = "^(\\%a-it{)().-(})()$",
    },
    ["s"] = {
      add = { "\\textsc{", "}" },
      find = "\\textsc%b{}",
      delete = "^(\\textsc{)().-(})()$",
    },
    ["t"] = {
      add = { "\\texttt{", "}" },
      -- add = function()
      --   if vim.fn["vimtex#syntax#in_mathzone"]() == 1 then
      --     return { { "\\mathtt{" }, { "}" } }
      --   end
      --   return { { "\\texttt{" }, { "}" } }
      -- end,
      find = "\\%a-tt%b{}",
      delete = "^(\\%a-tt{)().-(})()$",
    },
    ["4"] = {
      add = { "$", "$" },
      -- find = "%b$.-$",
      -- delete = "^($)().-($)()$",
    },
  },
})

