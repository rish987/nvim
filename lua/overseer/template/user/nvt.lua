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
    return {
      cmd = { "nvim" },
      args = {
        "--cmd", 'let g:StartedByNvimTask = "true"',
        "--cmd", ('let g:NvimTaskSessionDir = "%s"'):format(db.sessiondir), -- use parent sessiondir
        "--cmd", ('let g:NvimTaskParentSock = "%s"'):format(sock),
        "--cmd", ('let g:NvimTaskChildSockfile = "%s"'):format(sockfile),
        "--listen", sockfile
      },
      strategy = {"nvt", sname = params.sname, sockfile = sockfile},
      components = {
        -- "nvt",
        "default",
      },
    }
  end,
}
