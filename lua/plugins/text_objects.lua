return {
  "chrisgrieser/nvim-various-textobjs",
	lazy = false,
	opts = {
    useDefaultKeymaps = true,
    disabledKeymaps = { "g;", "gc", "r", "R" },
  },
  init = function ()
    vim.keymap.set({ "o", "x" }, "gp", "<cmd>lua require('various-textobjs').lastChange()<CR>")
    vim.keymap.set("n", "dsi", function()
      -- select outer indentation
      require("various-textobjs").indentation("outer", "outer")

      -- plugin only switches to visual mode when a textobj has been found
      local indentationFound = vim.fn.mode():find("V")
      if not indentationFound then return end

      -- dedent indentation
      vim.cmd.normal { "<", bang = true }

      -- delete surrounding lines
      local endBorderLn = vim.api.nvim_buf_get_mark(0, ">")[1]
      local startBorderLn = vim.api.nvim_buf_get_mark(0, "<")[1]
      vim.cmd(tostring(endBorderLn) .. " delete") -- delete end first so line index is not shifted
      vim.cmd(tostring(startBorderLn) .. " delete")
    end, { desc = "Delete Surrounding Indentation" })

    vim.keymap.set("n", "ysii", function()
      local startPos = vim.api.nvim_win_get_cursor(0)

      -- identify start- and end-border
      require("various-textobjs").indentation("outer", "outer")
      local indentationFound = vim.fn.mode():find("V")
      if not indentationFound then return end
      vim.cmd.normal { "V", bang = true } -- leave visual mode so the `'<` `'>` marks are set

      -- copy them into the + register
      local startLn = vim.api.nvim_buf_get_mark(0, "<")[1] - 1
      local endLn = vim.api.nvim_buf_get_mark(0, ">")[1] - 1
      local startLine = vim.api.nvim_buf_get_lines(0, startLn, startLn + 1, false)[1]
      local endLine = vim.api.nvim_buf_get_lines(0, endLn, endLn + 1, false)[1]
      vim.fn.setreg("+", startLine .. "\n" .. endLine .. "\n")

      -- highlight yanked text
      local ns = vim.api.nvim_create_namespace("ysi")
      vim.highlight.range(0, ns, "IncSearch", { startLn, 0 }, { startLn, -1 })
      vim.highlight.range(0, ns, "IncSearch", { endLn, 0 }, { endLn, -1 })
      vim.defer_fn(function() vim.api.nvim_buf_clear_namespace(0, ns, 0, -1) end, 1000)

      -- restore cursor position
      vim.api.nvim_win_set_cursor(0, startPos)
    end, { desc = "Yank surrounding indentation" })
  end
}
