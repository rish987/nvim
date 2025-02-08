return {
  {
    "akinsho/toggleterm.nvim",
    init = function ()
      -- -- copied from https://github.com/akinsho/toggleterm.nvim/pull/368
      -- local function neighbor_float_term(terminal_chooser)
      --   if not require"toggleterm.ui".find_open_windows() then return end
      --   local terms = require("toggleterm.terminal")
      --
      --   local terminals = terms.get_all()
      --   local focused_term_index
      --   for index, terminal in ipairs(terminals) do
      --     if terminal:is_focused() then focused_term_index = index end
      --   end
      --
      --   if not focused_term_index or not terminals[focused_term_index]:is_float() then return end
      --
      --   local focused_term = terminals[focused_term_index]
      --
      --   local next_terminal_index = terminal_chooser(focused_term_index, #terminals)
      --
      --   local next_terminal = terminals[next_terminal_index]
      --
      --   focused_term:close()
      --   terms.get_or_create_term(next_terminal.id):open()
      -- end
      --
      -- local function open_alt_float_term()
      --   neighbor_float_term(function(focused_index, terminals_number) return focused_index == 1 and terminals_number or focused_index - 1 end)
      -- end
      vim.keymap.set("t", "<C-a><C-d>", "<C-\\><C-n>")
      vim.keymap.set("t", "<C-a><C-k>", "<C-\\><C-n><C-u>M")
      -- vim.keymap.set("<C-d>", open_alt_float_term())
    end,
    opts = {
      -- size can be a number or function which is passed the current terminal
      --size = 20 | function(term)
      --  if term.direction == "horizontal" then
      --    return 15
      --  elseif term.direction == "vertical" then
      --    return vim.o.columns * 0.4
      --  end
      --end,
      open_mapping = vim.g.StartedByNvimTask and [[<C-A-s>]] or [[<C-s>]],
      --on_open = fun(t: Terminal), -- function to run when the terminal opens
      --on_close = fun(t: Terminal), -- function to run when the terminal closes
      --on_stdout = fun(t: Terminal, job: number, data: string[], name: string) -- callback for processing output on stdout
      --on_stderr = fun(t: Terminal, job: number, data: string[], name: string) -- callback for processing output on stderr
      --on_exit = fun(t: Terminal, job: number, exit_code: number, name: string) -- function to run when terminal process exits
      --hide_numbers = true, -- hide the number column in toggleterm buffers
      --shade_filetypes = {},
      shade_terminals = true,
      shading_factor = '1', -- the degree by which to darken to terminal colour, default: 1 for dark backgrounds, 3 for light
      --start_in_insert = false,
      --insert_mappings = true, -- whether or not the open mapping applies in insert mode
      --terminal_mappings = true, -- whether or not the open mapping applies in the opened terminals
      persist_size = false,
      persist_mode = true,
      direction = 'float',
      --close_on_exit = true, -- close the terminal window when the process exits
      --shell = vim.o.shell, -- change the default shell
      auto_scroll = false, -- automatically scroll to the bottom on terminal output
      get_ctx = function()
        return vim.api.nvim_get_current_tabpage()
      end,
      -- This field is only relevant if direction is set to 'float'
      float_opts = {
        -- The border key is *almost* the same as 'nvim_open_win'
        -- see :h nvim_open_win for details on borders however
        -- the 'curved' border is a custom border type
        -- not natively supported but implemented in this plugin.
        --border = 'single' | 'double' | 'shadow' | 'curved' | ... other options supported by win open
        border = 'single',
        --width = <value>,
        --height = <value>,
        winblend = 0,
        col = not vim.g.StartedByNvimTask and 85,
        width = not vim.g.StartedByNvimTask and function ()
          return vim.o.columns - 20 - 80
        end,
        highlights = {
          border = "Normal",
          background = "Black",
        }
      }
    }
  },
}

-- local toggleterm = require'toggleterm'
-- local strategies = toggleterm.toggle_strategies
-- local cmd = vim.api.nvim_create_user_command
--
-- cmd("TermGitPush", function(opts) toggleterm.exec("git push", opts.count, 12) end, {count = 1})
-- cmd("TermGitPushF", function(opts) toggleterm.exec("git push -f", opts.count, 12) end, {count = 1})
-- cmd("ToggleTermTab", function(opts) toggleterm.toggle_command(opts.args, strategies["by_tabpage"]()) end, {})
