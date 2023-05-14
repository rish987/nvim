local npairs = require("nvim-autopairs")
local Rule = require("nvim-autopairs.rule")
local cond = require("nvim-autopairs.conds")

npairs.setup {}

npairs.add_rules({
    Rule("$", "$", {"tex", "latex"})
    -- move right when repeating $
    :with_move(cond.done())
    -- disable adding a newline when you press <cr>
    :with_cr(cond.none()),
})
