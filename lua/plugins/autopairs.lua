return {
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = function(_, _)
      local npairs = require("nvim-autopairs")
      npairs.setup{}
      local Rule = require("nvim-autopairs.rule")
      local cond = require("nvim-autopairs.conds")

      npairs.remove_rule('`')

      npairs.add_rules({
        Rule("→", "→", {"tex", "latex"}),
        Rule("$", "$", {"tex", "latex"})
        -- move right when repeating $
        :with_move(cond.done())
        -- disable adding a newline when you press <cr>
        :with_cr(cond.none()),
      })
    end
  }
}
