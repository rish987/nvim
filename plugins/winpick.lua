return {
  {
    "gbrlsnchs/winpick.nvim",
    init = function ()
      vim.keymap.set("n", "<C-w><C-w>", "<C-w><C-p>")

      vim.keymap.set("n", "<C-w>q", function()
        local winid =  require"winpick".select()

        if winid then
          vim.api.nvim_set_current_win(winid)
        end
      end)
    end,
    opts = function ()
      return {
          border = "double",
          filter = nil, -- doesn't ignore any window by default
          prompt = "Pick a window: ",
          format_label = require"winpick".defaults.format_label, -- formatted as "<label>: <buffer name>"
          chars = nil,
        }
    end
  },
}
