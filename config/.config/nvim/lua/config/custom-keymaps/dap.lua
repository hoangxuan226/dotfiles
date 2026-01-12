-- DAP (Debug Adapter Protocol) keymaps

local dap_keymaps = {
  -- mode, key, action, description, show_in_popup
  {
    "n",
    "<F5>",
    function()
      require("dap").continue()
    end,
    "Continue/Start Debugging",
    true,
  },
  {
    "n",
    "<F6>",
    function()
      require("dap").restart()
    end,
    "Restart Debugging",
    true,
  },
  {
    "n",
    "<F7>",
    function()
      require("dap").terminate()
    end,
    "Terminate Debugging",
    true,
  },
  {
    "n",
    "<F9>",
    function()
      require("dap").toggle_breakpoint()
    end,
    "Toggle Breakpoint",
    true,
  },
  {
    "n",
    "<F10>",
    function()
      require("dap").step_over()
    end,
    "Step Over",
    true,
  },
  {
    "n",
    "<F11>",
    function()
      require("dap").step_into()
    end,
    "Step Into",
    true,
  },
  {
    "n",
    "<F12>",
    function()
      require("dap").step_out()
    end,
    "Step Out",
    true,
  },
  {
    "n",
    "<Leader>db",
    function()
      require("dap").toggle_breakpoint()
    end,
    "Toggle breakpoint",
    false,
  },
  {
    "n",
    "<Leader>dB",
    function()
      require("dap").set_breakpoint()
    end,
    "Set breakpoint",
    false,
  },
  {
    "n",
    "<Leader>dC",
    function()
      require("dap").clear_breakpoints()
    end,
    "Clear all breakpoints",
    false,
  },
  {
    "n",
    "<leader>dl",
    function()
      require("dap").run_last()
    end,
    "Run last debug session",
    false,
  },
  {
    "n",
    "<leader>dw",
    function()
      require("dapui").toggle()
    end,
    "Toggle DAP UI",
    false,
  },
  {
    "n",
    "<leader>de",
    function()
      require("dapui").eval()
    end,
    "Evaluate expression",
    false,
  },
}

for _, km in ipairs(dap_keymaps) do
  local mode, key, action, desc = km[1], km[2], km[3], km[4]
  vim.keymap.set(mode, key, action, { noremap = true, silent = true, desc = desc })
end

-- Keymaps helper popup
vim.keymap.set("n", "<leader>d?", function()
  local popup = require("plenary.popup")
  local lines = {}
  for _, km in ipairs(dap_keymaps) do
    local _, key, _, desc, show_in_popup = unpack(km)
    if show_in_popup then
      table.insert(lines, string.format("%-8s: %s", key, desc))
    end
  end
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end
  local win_id = popup.create(lines, {
    title = "DAP Keymaps",
    highlight = "Normal",
    line = math.floor((vim.o.lines - #lines) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    minwidth = width,
    minheight = #lines,
    border = {},
  })
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<cmd>bd!<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", "<cmd>bd!<CR>", { noremap = true, silent = true })
end, { desc = "Show DAP keymaps" })
