local theme = {
  fill = 'TabLineFill',
  -- Also you can do this: fill = { fg='#f2e9de', bg='#907aa9', style='italic' }
  head = 'TabLine',
  current_tab = 'TabLineSel',
  tab = 'TabLine',
  win = 'TabLine',
  tail = 'TabLine',
}

--require('tabby.tabline').set(function(line)
--    local cwd = ' ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t') .. ' '
--    return {
--        {
--            { cwd, hl = theme.head },
--            line.sep('x', theme.head, theme.line),
--        },
--        ".....",
--    }
--end, {})

local function get_tab_name(tabid)
  local cwd = ' ' .. vim.fn.fnamemodify(vim.fn.getcwd(0, vim.api.nvim_tabpage_get_number(tabid)), ':t') .. ' '
  return cwd
end

require('tabby.tabline').set(function(line)
  return {
    {
      --{ ' | ', hl = theme.head },
      line.sep('|', theme.head, theme.fill),
    },
    line.tabs().foreach(function(tab)
      require("tabby.feature.tab_name").set(tab.id, get_tab_name(tab.id))
      local hl = tab.is_current() and theme.current_tab or theme.tab
      return {
        line.sep('|', hl, theme.fill),
        not tab.is_current() and '◎' or '◉',
        tab.number(),
        tab.name(),
        --tab.close_btn(''),
        line.sep('|', hl, theme.fill),
        hl = hl,
        margin = ' ',
      }
    end),
    line.spacer(),
    line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
      return {
        line.sep('|', theme.win, theme.fill),
        not win.is_current() and '◎' or '◉',
        win.buf_name(),
        line.sep('|', theme.win, theme.fill),
        hl = theme.win,
        margin = ' ',
      }
    end),
    {
      line.sep('|', theme.tail, theme.fill),
      { '  ', hl = theme.tail },
    },
    hl = theme.fill,
  }
end,
{
  tab_name = {
    name_fallback = get_tab_name
  },
  buf_name = {
      mode = "shorten",
  }
}

)