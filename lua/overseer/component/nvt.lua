-- FIXME namespace to nvt (nest this file in "overseer/component/nvt/" directory) and give a bettter name
---@type overseer.ComponentFileDefinition
local comp = {
  desc = "Write task output to buffer",
  params = {
  },
  constructor = function(params)
    return {
      on_init = function(self)
        self.buf = vim.api.nvim_create_buf(false, true)
        vim.bo[self.buf].ft = "NvimTaskOut"
        local pardir = vim.fs.dirname(params.filename)
        vim.fn.mkdir(pardir, "p")
      end,
      on_reset = function(self)
        vim.api.nvim_buf_set_text(self.buf, 0, 0, -1, -1, {""})
      end,
      on_output = function(self, task, data)
        local msgs_text = vim.api.nvim_buf_get_text(self.buf, 0, 0, -1, -1, {})
        local num_lines = #msgs_text
        local last_line_length = #msgs_text[num_lines]

        local msg_text = vim.fn.join(data, "\n")
        local msg = vim.split(msg_text, "\n")

        local new_text = last_line_length == 0 and msg or {"", unpack(msg)}
        vim.api.nvim_buf_set_text(self.buf, num_lines - 1, last_line_length, num_lines - 1, last_line_length, new_text)
      end,
      on_dispose = function(self)
        vim.api.nvim_buf_delete(self.buf, {})
      end,
    }
  end,
}

return comp
