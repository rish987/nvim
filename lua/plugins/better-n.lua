return {
  {
    'jonatan-branting/nvim-better-n',
    lazy = false,
    config = function (_, opts)
      require"better-n".setup(opts)

      vim.keymap.set("n", "n", require("better-n").n, {nowait = true})
      vim.keymap.set("n", "<s-n>", require("better-n").shift_n, {nowait = true})
    end,
    opts = {
      callbacks = {
        mapping_executed = function(_mode, _key)
          -- Clear highlighting, indicating that `n` will not goto the next
          -- highlighted search-term
          vim.cmd [[ nohl ]]
        end
      },
      mappings = {
        [']d'] = {previous = '[d', next = ']d'},
        ['[d'] = {previous = '[d', next = ']d'},
      }
    },
    dependencies = { 'nvim-tree/nvim-web-devicons' }
  }
}
