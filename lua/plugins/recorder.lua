return {
	"chrisgrieser/nvim-recorder",
	dependencies = "rcarriga/nvim-notify", -- optional
	opts = {
    slots = { "a", "b" },

    mapping = {
      startStopRecording = "<C-q>",
      playMacro = "Q",
      switchSlot = "<leader>q",
      editMacro = "cq",
      deleteAllMacros = "dq",
      yankMacro = "yq",
      -- ⚠️ this should be a string you don't use in insert mode during a macro
      addBreakPoint = "##",
    },
  }, -- required even with default settings, since it calls `setup()`
}
