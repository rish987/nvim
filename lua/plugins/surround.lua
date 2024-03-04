return {
  {
    "kylechui/nvim-surround",
    opts = {
      -- Configuration here, or leave empty to use defaults
      keymaps = {
        insert = false,
        insert_line = false,
        normal = "ys",
        normal_cur = "yss",
        normal_line = "yS",
        normal_cur_line = "ySS",
        visual = "s",
        visual_line = "gS",
        delete = "dx",
        change = "cx",
      },
    }
  }
}
