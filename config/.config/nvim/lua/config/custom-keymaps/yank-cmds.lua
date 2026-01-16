local dap_helper = require("config.dap.dotnet")

local cmds = {
  -- Project Creation
  {
    name = "Create a C# console application",
    icon = "󰌛",
    icon_hl = "DiagnosticOk",
    cmd = "dotnet new console",
  },
  {
    name = "Create a C# RESTful web API",
    icon = "󰌛",
    icon_hl = "DiagnosticOk",
    cmd = "dotnet new webapi",
  },
  -- {
  --   name = "Create Blazor WebAssembly app",
  --   icon = "󰌛",
  --   icon_hl = "DiagnosticOk",
  --   cmd = "dotnet new blazorwasm",
  -- },
  -- {
  --   name = "Create ASP.NET MVC app",
  --   icon = "󰌛",
  --   icon_hl = "DiagnosticOk",
  --   cmd = "dotnet new mvc",
  -- },
  -- {
  --   name = "Create Blazor Server app",
  --   icon = "󰌛",
  --   icon_hl = "DiagnosticOk",
  --   cmd = "dotnet new blazorserver",
  -- },
  {
    name = "Create a class library",
    icon = "",
    icon_hl = "DiagnosticInfo",
    cmd = "dotnet new classlib",
  },

  -- Test Projects
  {
    name = "Create xUnit test project",
    icon = "󰇉",
    icon_hl = "DiagnosticHint",
    cmd = "dotnet new xunit -n <test-project-name>",
  },
  {
    name = "Create NUnit test project",
    icon = "󰇉",
    icon_hl = "DiagnosticHint",
    cmd = "dotnet new nunit -n <test-project-name>",
  },
  {
    name = "Create MSTest test project",
    icon = "󰇉",
    icon_hl = "DiagnosticHint",
    cmd = "dotnet new mstest -n <test-project-name>",
  },

  -- Solution Management
  {
    name = "Create a solution file",
    icon = "",
    icon_hl = "DiagnosticInfo",
    cmd = "dotnet new sln",
  },
  {
    name = "Add project to solution",
    icon = "󱪝",
    icon_hl = "DiagnosticOk",
    cmd = "dotnet sln add <path-to-csproj>",
  },
  {
    name = "Remove project from solution",
    icon = "󱪟",
    icon_hl = "DiagnosticWarn",
    cmd = "dotnet sln remove <path-to-csproj>",
  },
  {
    name = "List solution projects",
    icon = "󰒺",
    icon_hl = "DiagnosticInfo",
    cmd = "dotnet sln list",
  },
}

-- Function to get dynamic build commands from current project
local function get_dynamic_build_commands()
  local dynamic_cmds = {}

  -- Try to get project-specific commands
  local build_cmd = dap_helper.get_build_command()
  if build_cmd then
    table.insert(dynamic_cmds, {
      name = "Build current project (Debug)",
      icon = "",
      icon_hl = "DiagnosticInfo",
      cmd = build_cmd,
    })

    local build_release_cmd = dap_helper.get_build_command_release()
    if build_release_cmd then
      table.insert(dynamic_cmds, {
        name = "Build current project (Release)",
        icon = "",
        icon_hl = "DiagnosticHint",
        cmd = build_release_cmd,
      })
    end

    local clean_cmd = dap_helper.get_clean_command()
    if clean_cmd then
      table.insert(dynamic_cmds, {
        name = "Clean current project",
        icon = "󰃨",
        icon_hl = "DiagnosticWarn",
        cmd = clean_cmd,
      })
    end

    local restore_cmd = dap_helper.get_restore_command()
    if restore_cmd then
      table.insert(dynamic_cmds, {
        name = "Restore current project dependencies",
        icon = "󰦛",
        icon_hl = "DiagnosticOk",
        cmd = restore_cmd,
      })
    end

    local run_cmd = dap_helper.get_run_command()
    if run_cmd then
      table.insert(dynamic_cmds, {
        name = "Run current project",
        icon = "",
        icon_hl = "DiagnosticOk",
        cmd = run_cmd,
      })
    end

    local test_cmd = dap_helper.get_test_command()
    if test_cmd then
      table.insert(dynamic_cmds, {
        name = "Run tests in current project",
        icon = "",
        icon_hl = "DiagnosticHint",
        cmd = test_cmd,
      })
    end

    local publish_cmd = dap_helper.get_publish_command()
    if publish_cmd then
      table.insert(dynamic_cmds, {
        name = "Publish current project",
        icon = "󰚧",
        icon_hl = "DiagnosticWarn",
        cmd = publish_cmd,
      })
    end
  end

  -- NuGet Package Management
  local add_package_cmd = dap_helper.get_add_package_command()
  if add_package_cmd then
    table.insert(dynamic_cmds, {
      name = "Add NuGet package to current project",
      icon = "󰏖",
      icon_hl = "DiagnosticOk",
      cmd = add_package_cmd,
    })
  end

  local remove_package_cmd = dap_helper.get_remove_package_command()
  if remove_package_cmd then
    table.insert(dynamic_cmds, {
      name = "Remove NuGet package from current project",
      icon = "󰆴",
      icon_hl = "DiagnosticWarn",
      cmd = remove_package_cmd,
    })
  end

  local list_packages_cmd = dap_helper.get_list_packages_command()
  if list_packages_cmd then
    table.insert(dynamic_cmds, {
      name = "List packages in current project",
      icon = "󰒺",
      icon_hl = "DiagnosticInfo",
      cmd = list_packages_cmd,
    })
  end

  -- Project References
  local add_reference_cmd = dap_helper.get_add_reference_command()
  if add_reference_cmd then
    table.insert(dynamic_cmds, {
      name = "Add project reference to current project",
      icon = "",
      icon_hl = "DiagnosticOk",
      cmd = add_reference_cmd,
    })
  end

  local list_references_cmd = dap_helper.get_list_references_command()
  if list_references_cmd then
    table.insert(dynamic_cmds, {
      name = "List project references",
      icon = "󰒺",
      icon_hl = "DiagnosticInfo",
      cmd = list_references_cmd,
    })
  end

  -- Watch Mode (Hot Reload)
  -- local watch_cmd = dap_helper.get_watch_command()
  -- if watch_cmd then
  --   table.insert(dynamic_cmds, {
  --     name = "Run current project with hot reload (watch)",
  --     icon = "󰑐",
  --     icon_hl = "DiagnosticOk",
  --     cmd = watch_cmd,
  --   })
  -- end

  -- Solution-level commands (only if .sln exists)
  local sln_build_cmd = dap_helper.get_sln_build_command()
  if sln_build_cmd then
    table.insert(dynamic_cmds, {
      name = "Build entire solution",
      icon = "",
      icon_hl = "DiagnosticInfo",
      cmd = sln_build_cmd,
    })
  end

  local sln_test_cmd = dap_helper.get_sln_test_command()
  if sln_test_cmd then
    table.insert(dynamic_cmds, {
      name = "Run all tests in solution",
      icon = "󰇉",
      icon_hl = "DiagnosticHint",
      cmd = sln_test_cmd,
    })
  end

  local sln_add_cmd = dap_helper.get_sln_add_command()
  if sln_add_cmd then
    table.insert(dynamic_cmds, {
      name = "Add project to solution",
      icon = "󱪝",
      icon_hl = "DiagnosticOk",
      cmd = sln_add_cmd,
    })
  end

  local sln_list_cmd = dap_helper.get_sln_list_command()
  if sln_list_cmd then
    table.insert(dynamic_cmds, {
      name = "List projects in solution",
      icon = "󰒺",
      icon_hl = "DiagnosticInfo",
      cmd = sln_list_cmd,
    })
  end

  return dynamic_cmds
end

vim.keymap.set("n", "<leader>C", function()
  local Snacks = require("snacks")
  return Snacks.picker({
    finder = function()
      -- Merge static and dynamic commands
      local dynamic_cmds = get_dynamic_build_commands()
      local all_cmds = vim.list_extend(vim.deepcopy(dynamic_cmds), cmds)

      local items = {}
      for i, item in ipairs(all_cmds) do
        table.insert(items, {
          idx = i,
          text = item.name .. " " .. item.cmd, -- Add searchable text field
          name = item.name,
          icon = item.icon,
          icon_hl = item.icon_hl,
          cmd = item.cmd,
        })
      end
      return items
    end,
    layout = {
      layout = {
        box = "horizontal",
        width = 0.5,
        height = 0.5,
        {
          box = "vertical",
          border = "rounded",
          title = "Commands",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
      },
    },
    format = function(item, _)
      local ret = {}
      local a = Snacks.picker.util.align
      ret[#ret + 1] = { a(item.icon, 3), item.icon_hl }
      ret[#ret + 1] = { " " }
      ret[#ret + 1] = { a(item.name, 20) }
      ret[#ret + 1] = { " " }
      ret[#ret + 1] = { item.cmd, "Comment" }
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      vim.fn.setreg("+", item.cmd)
      vim.notify("Yanked: " .. item.cmd)
    end,
  })
end, { desc = "Yank commands" })
