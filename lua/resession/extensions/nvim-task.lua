local M = {}

---Get the saved data for this extension
---@param opts resession.Extension.OnSaveOpts Information about the session being saved
---@return any
M.on_save = function(opts)
  return {}
end

-- ---Restore the extension state
-- ---@param data _ the value returned from on_save
-- M.on_pre_load = function(data)
--   -- This is run before the buffers, windows, and tabs are restored
-- end

---Restore the extension state
---@param data _ the value returned from on_save
M.on_post_load = function(data)
  if data then
    -- if data.registers then
    --   for reg, value in pairs(data.registers) do
    --     vim.fn.setreg(reg, value)
    --   end
    -- end
    if data.map then
      for mode, str in pairs(data.map) do
        require"nvim-task.config".set_keymap(mode, "<c-x>", str)
      end
    end
  end
  -- This is run after the buffers, windows, and tabs are restored
end

-- ---Called when resession gets configured
-- ---This function is optional
-- ---@param data table the configuration data passed in the config
-- M.config = function(data)
--   --
-- end
--
-- ---Check if a window is supported by this extension
-- ---This function is optional, but if provided save_win and load_win must
-- ---also be present.
-- ---@param winid integer
-- ---@param bufnr integer
-- ---@return boolean
-- M.is_win_supported = function(winid, bufnr)
--   return true
-- end
--
-- ---Save data for a window
-- ---@param winid integer
-- ---@return any
-- M.save_win = function(winid)
--   -- This is used to save the data for a specific window that contains a non-file buffer (e.g. a filetree).
--   return {}
-- end
--
-- ---Called with the data from save_win
-- ---@param winid integer
-- ---@param config any
-- ---@return integer|nil If the original window has been replaced, return the new ID that should replace it
-- M.load_win = function(winid, config)
--   -- Restore the window from the config
-- end

return M
