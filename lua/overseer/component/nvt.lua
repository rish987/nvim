-- FIXME namespace to nvt (nest this file in "overseer/component/nvt/" directory) and give a better name
---@type overseer.ComponentFileDefinition
local comp = {
  desc = "Write task output to :messages",
  params = {
  },
  constructor = function(_)
    return {
      on_output = function(_, _, data)
        local msg_text = vim.fn.join(data, "\n")
        print(msg_text)
      end,
    }
  end,
}

return comp
