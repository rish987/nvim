return {
  {
    'jonatan-branting/nvim-better-n',
    lazy = false,
    config = function(opts)
      require"better-n".setup(opts)
    end,

    init = function ()

    end,

    dependencies = { 'nvim-tree/nvim-web-devicons' }
  }
}
