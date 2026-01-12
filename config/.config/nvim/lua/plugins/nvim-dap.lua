return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")
      if not dap.adapters["netcoredbg"] then
        require("dap").adapters["netcoredbg"] = {
          type = "executable",
          command = vim.fn.exepath("netcoredbg"),
          args = { "--interpreter=vscode" },
          options = {
            detached = false,
          },
        }
      end

      local dotnet_langs = { "cs", "fsharp", "vb" }
      for _, lang in ipairs(dotnet_langs) do
        if not dap.configurations[lang] then
          local dotnet = require("config.dap.dotnet")

          -- Base configuration factory
          -- Note: is_web_project() is called at runtime (when config is used)
          -- This allows switching between projects without restarting Neovim
          local function create_config(name, profile)
            return {
              type = "netcoredbg",
              name = name,
              request = "launch",
              ---@diagnostic disable-next-line: redundant-parameter
              program = function()
                dotnet.build_project() -- Build before debugging
                return dotnet.build_dll_path()
              end,
              cwd = function()
                return dotnet.get_project_cwd()
              end,
              env = function()
                local env = {
                  ASPNETCORE_ENVIRONMENT = "Development",
                }
                -- Check at runtime if it's a web project
                -- This allows the same config to work for different project types
                local is_web = dotnet.is_web_project()
                if is_web and profile then
                  local app_url = dotnet.get_application_url(profile)
                  if app_url then
                    env.ASPNETCORE_URLS = app_url
                  end
                end
                return env
              end,
            }
          end

          -- Create all possible configurations
          -- The appropriate ones will be used based on project type at runtime
          dap.configurations[lang] = {
            create_config("Launch file", nil),
            create_config("Launch file (http)", "http"),
            create_config("Launch file (https)", "https"),
          }
        end
      end

      vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

      for name, sign in pairs(LazyVim.config.icons.dap) do
        sign = type(sign) == "table" and sign or { sign }
        vim.fn.sign_define(
          "Dap" .. name,
          { text = sign[1], texthl = sign[2] or "DiagnosticSignHint", linehl = sign[3], numhl = sign[3] }
        )
      end
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio", "nvim-lua/plenary.nvim" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      -- default configuration
      dapui.setup()
    end,
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    requires = {
      "nvim-treesitter/nvim-treesitter",
      "mfussenegger/nvim-dap",
    },
    config = function()
      require("nvim-dap-virtual-text").setup({})
    end,
  },
}
