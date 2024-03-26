return {
	"chrisgrieser/nvim-recorder",
  -- enabled = false,
	dependencies = "rcarriga/nvim-notify", -- optional
	opts = {
    slots = { "a", "b" },

    mapping = {
      startStopRecording       = vim.g.StartedByNvimTask and "<C-A-f>" or "<C-f>",
      insertStartStopRecording = vim.g.StartedByNvimTask and "<C-A-f>" or "<C-f>",
      playMacro                = vim.g.StartedByNvimTask and "<C-A-n>" or "<C-n>",
      insertPlayMacro          = vim.g.StartedByNvimTask and "<C-A-n>" or "<C-n>",
      switchSlot               = "<leader><c-q>",
      editMacro                = "cq",
      deleteAllMacros          = "dq",
      yankMacro                = "yq",
      addBreakPoint            = vim.g.StartedByNvimTask and "<C-A-e>" or "<C-e>", -- ⚠️ this should be a string you don't use in insert mode during a macro
      insertAddBreakPoint      = vim.g.StartedByNvimTask and "<C-A-e>" or "<C-e>", -- ⚠️ this should be a string you don't use in insert mode during a macro
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
