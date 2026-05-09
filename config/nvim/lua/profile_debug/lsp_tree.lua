local logger = require("profile_debug.logger")

local M = {}

function M.setup(log_file_path)
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      -- 1. Get the PID of the core (--embed)
      local embed_pid = vim.fn.getpid()

      -- 2. Find the parent PID (TUI nvim) via 'ps' shell command
      local ppid = vim.fn.system("ps -o ppid= -p " .. embed_pid):gsub("%s+", "")

      local init_profile = vim.env.MYVIMRC or (vim.fn.stdpath("config") .. "/init.lua")
      local argv = vim.v.argv
      for idx, arg in ipairs(argv) do
        if arg == "-u" and argv[idx + 1] then
          init_profile = argv[idx + 1]
          break
        end
      end

      -- 3. Get LSP clients
      local clients = vim.lsp.get_clients()
      if #clients > 0 then
        local tree_msg =
          string.format("Init profile: %s\n%s nvim (TUI)\n└── %d nvim --embed", init_profile, ppid, embed_pid)
        for i, client in ipairs(clients) do
          -- Get the exact PID of the LSP process

          local lsp_pid = "unknown"
          ---@diagnostic disable-next-line: undefined-field
          if client.rpc and type(client.rpc.pid) == "number" then
            ---@diagnostic disable-next-line: undefined-field
            lsp_pid = client.rpc.pid
          elseif client.rpc and type(client.rpc.is_closing) == "function" then
            local j = 1
            while true do
              local n, v = debug.getupvalue(client.rpc.is_closing, j)
              if not n then
                break
              end
              if n == "client" and type(v) == "table" and v.transport and v.transport.sysobj then
                ---@diagnostic disable-next-line: undefined-field
                lsp_pid = v.transport.sysobj.pid
                break
              end
              j = j + 1
            end
          end
          local prefix = (i == #clients) and "    └── " or "    ├── "
          tree_msg = tree_msg .. string.format("\n%s%s: %s", prefix, lsp_pid, client.name)
        end
        log_file_path = log_file_path or "/tmp/nvim_leave.log"
        logger.log_entry(log_file_path, tree_msg)
      end
    end,
  })
end

return M
