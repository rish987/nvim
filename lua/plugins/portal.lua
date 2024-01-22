return {
    "cbochs/portal.nvim",
    -- Optional dependencies
    init = function()
      vim.keymap.set("n", "<leader>;", "<cmd>Portal changelist backward<cr>")
      vim.keymap.set("n", "<leader>:", "<cmd>Portal changelist forward<cr>")
      vim.keymap.set("n", "<leader>o", "<cmd>Portal jumplist backward<cr>")
      vim.keymap.set("n", "<leader>i", "<cmd>Portal jumplist forward<cr>")
    end,
    dependencies = {
        -- "cbochs/grapple.nvim",
        -- "ThePrimeagen/harpoon"
    },
}
