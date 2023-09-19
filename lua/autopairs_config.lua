local npairs = require("nvim-autopairs")
local Rule = require("nvim-autopairs.rule")
local cond = require("nvim-autopairs.conds")

npairs.setup {}
npairs.remove_rule('`')

npairs.add_rules({
    Rule("$", "$", {"tex", "latex"})
    -- move right when repeating $
    :with_move(cond.done())
    -- disable adding a newline when you press <cr>
    :with_cr(cond.none()),
})

-- TODO count number of closing delimiters and jump accordingly
vim.keymap.set({"i"}, "<C-l>", function () vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, true, true)) end)
