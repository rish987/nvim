return {
  {
    'jonatan-branting/nvim-better-n',
    lazy = false,
    config = function(opts)
      require"better-n".setup(opts)
    end,

    init = function ()
      local r = require"better-n"
      local mappings = {
        [']d'] = {previous = '[d', next = ']d'},
        ['[d'] = {previous = '[d', next = ']d'},
      }

      for key, opts in pairs(mappings) do
        local f = r.create({ key = key, next = opts.next, previous = opts.previous })
        vim.keymap.set({ "n", "x" }, f.key, f.passthrough, { expr = true, silent = true })
      end
    end,

    dependencies = { 'nvim-tree/nvim-web-devicons' }
  }
}
