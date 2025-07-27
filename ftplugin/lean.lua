require("nvim-surround").buffer_setup({
  surrounds = {
    ["c"] = {
      add = { "⌜", "⌝" },
      find = "⌜.-⌝",
      delete = "^(⌜)().-(⌝)()$",
    },
    ["<"] = {
      add = { "⟨", "⟩" },
      find = "⟨.-⟩",
      delete = "^(⟨)().-(⟩)()$",
    },
  },
})

