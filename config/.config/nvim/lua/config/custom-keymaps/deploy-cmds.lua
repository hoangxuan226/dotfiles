local terminals = {} -- 👈 New table to store your terminals

local function get_commands()
  local commands = {
    {
      name = "Deploy Frontend",
      icon = "󰜈",
      icon_hl = "DiagnosticInfo",
      cmd = "docker compose build frontend-staging && docker push hsms68/frontend-staging:latest",
      -- cmd = "pnpm dev",
      -- id = "frontend_term", -- 👈 Add a fixed ID
    },
    {
      name = "Deploy Backend",
      icon = "󰌛",
      icon_hl = "DiagnosticOk",
      cmd = "docker build -f Dockerfile -t hsms68/backend-dev:latest . && docker push hsms68/backend-dev:latest",
      -- id = "backend_term", -- 👈 Add a fixed ID
    },
  }
  return commands
end

vim.keymap.set("n", "<leader>D", function()
  local Snacks = require("snacks")
  local cmds = get_commands()
  return Snacks.picker({
    finder = function()
      local items = {}
      for i, item in ipairs(cmds) do
        table.insert(items, {
          idx = i,
          text = item.name .. " " .. item.cmd, -- Add searchable text field
          name = item.name,
          icon = item.icon,
          icon_hl = item.icon_hl,
          cmd = item.cmd,
          -- id = item.id,
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
          title = "Deploy Commands",
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

      local term_id = item.idx
      -- vim.notify("Running: " .. vim.inspect(item))

      -- 1. CHECK IF TERMINAL ALREADY EXISTS AND IS VALID
      if terminals[term_id] and terminals[term_id]:buf_valid() then
        -- 2. TERMINAL EXISTS: Toggle its visibility
        terminals[term_id]:toggle()
        return
      end

      -- 3. TERMINAL DOES NOT EXIST OR IS INVALID: Create a new one
      local term = Snacks.terminal.open(nil, {
        win = {
          position = "float",
          border = "rounded",
          title = " " .. item.icon .. " " .. item.name .. " ",
          title_pos = "center",
          width = 0.8,
          height = 0.8,
        },
      })

      -- 4. STORE THE NEW TERMINAL INSTANCE
      terminals[term_id] = term

      -- Optional: Add a cleanup hook to remove it from your table when it's wiped out (like :bd)
      term:on("BufWipeout", function()
        terminals[term_id] = nil
      end, { buf = true })

      -- Get the channel ID of the opened terminal buffer
      local chan = vim.bo[term.buf].channel

      -- Send a command to the terminal after a short delay
      vim.defer_fn(function()
        vim.api.nvim_chan_send(chan, item.cmd)
      end, 100)
    end,
  })
end, { desc = "Deploy Commands" })
