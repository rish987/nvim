return {
	"chrisgrieser/nvim-recorder",
  -- enabled = false,
	dependencies = "rcarriga/nvim-notify", -- optional
	opts = {
    slots = { "a", "b" },

    mapping = {
      startStopRecording = "<leader>q",
      playMacro = "<C-n>",
      insertPlayMacro = "<C-n>",
      switchSlot = "<leader>Q",
      editMacro = "cq",
      deleteAllMacros = "dq",
      yankMacro = "yq",
      -- ⚠️ this should be a string you don't use in insert mode during a macro
      addBreakPoint = "<C-e>",
      insertAddBreakPoint = "<C-e>",
    },
  }, -- required even with default settings, since it calls `setup()`
  init = function ()
    -- local lualineZ = require("lualine").get_config().sections.lualine_z or {}
    -- local lualineY = require("lualine").get_config().sections.lualine_y or {}
    -- table.insert(lualineZ, { require("recorder").recordingStatus })
    -- table.insert(lualineY, { require("recorder").displaySlots })
    --
    -- require("lualine").setup {
    --   tabline = {
    --     lualine_y = lualineY,
    --     lualine_z = lualineZ,
    --   },
    -- }
  end,
}
