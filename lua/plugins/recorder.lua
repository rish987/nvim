return {
	"chrisgrieser/nvim-recorder",
	dependencies = "rcarriga/nvim-notify", -- optional
	opts = {
    slots = { "a", "b" },

    mapping = {
      startStopRecording = "<leader>q",
      playMacro = "<C-n>",
      switchSlot = "<leader>Q",
      editMacro = "cq",
      deleteAllMacros = "dq",
      yankMacro = "yq",
      -- ⚠️ this should be a string you don't use in insert mode during a macro
      addBreakPoint = "<C-e>",
    },
  }, -- required even with default settings, since it calls `setup()`
  init = function ()
    vim.keymap.set("i", "<C-e>", function ()
      -- no-op
    end)
  end,
}
