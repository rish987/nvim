local nvt_conf = require "nvim-task.config"
local db = require "nvim-task.db"

local sock = vim.call("serverstart")

local function get_child_sock()
  local socket_i = 0
  local child_sock = "/tmp/nvimtasksocketchild" .. socket_i
  while vim.fn.filereadable(child_sock) ~= 0 do
    socket_i = socket_i + 1
    child_sock = "/tmp/nvimtasksocketchild" .. socket_i
  end
  return child_sock
end

return {
  name = "nvt",
  builder = function(params)
    local sockfile = get_child_sock()
    local args = {
      "--cmd", 'let g:StartedByNvimTask = "true"',
      "--cmd", ('let g:NvimTaskSessionDir = "%s"'):format(db.sessiondir), -- use parent sessiondir
      "--cmd", ('let g:NvimTaskParentSock = "%s"'):format(sock),
      "--cmd", ('let g:NvimTaskChildSockfile = "%s"'):format(sockfile),
      "--listen", sockfile
    }
    local components = {
      "default",
    }
    -- if params.headless then
    --   vim.list_extend(args, {"--embed"})
    -- end
    -- if params.headless then
    --   vim.list_extend(components, {"nvt"})
    -- end
    return {
      cmd = { "nvim" },
      args = args,
      strategy = {"nvt", sname = params.sname, auto = params.auto, headless = params.headless, sockfile = sockfile},
      components = components,
    }
  end,
}
