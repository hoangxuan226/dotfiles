-- Neotest keymaps

local test_keymaps = {
  -- mode, key, action, description

  -- Running tests
  {
    "n",
    "<leader>tr",
    function()
      require("neotest").run.run()
    end,
    "Run nearest test",
  },
  {
    "n",
    "<leader>tf",
    function()
      require("neotest").run.run(vim.fn.expand("%"))
    end,
    "Run current test file",
  },
  {
    "n",
    "<leader>ta",
    function()
      require("neotest").run.run(vim.fn.getcwd())
    end,
    "Run all tests in project",
  },
  {
    "n",
    "<leader>tl",
    function()
      require("neotest").run.run_last()
    end,
    "Run last test",
  },
  {
    "n",
    "<leader>tS",
    function()
      require("neotest").run.stop()
    end,
    "Stop nearest test",
  },

  -- Debugging tests
  {
    "n",
    "<leader>td",
    function()
      require("neotest").run.run({ strategy = "dap" })
    end,
    "Debug nearest test",
  },
  {
    "n",
    "<leader>tD",
    function()
      require("neotest").run.run({ vim.fn.expand("%"), strategy = "dap" })
    end,
    "Debug current test file",
  },

  -- Test UI/Output
  {
    "n",
    "<leader>ts",
    function()
      require("neotest").summary.toggle()
    end,
    "Toggle test summary",
  },
  {
    "n",
    "<leader>to",
    function()
      require("neotest").output.open({ enter = true })
    end,
    "Show test output",
  },
  {
    "n",
    "<leader>tO",
    function()
      require("neotest").output_panel.toggle()
    end,
    "Toggle test output panel",
  },
  {
    "n",
    "<leader>tw",
    function()
      require("neotest").watch.toggle()
    end,
    "Toggle test watch mode",
  },
  {
    "n",
    "<leader>tW",
    function()
      require("neotest").watch.toggle(vim.fn.expand("%"))
    end,
    "Toggle watch current file",
  },
}

-- Register <leader>t group name for which-key or similar
vim.keymap.set("n", "<leader>t", "<Nop>", { noremap = true, silent = true, desc = "Tests" })

for _, km in ipairs(test_keymaps) do
  local mode, key, action, desc = km[1], km[2], km[3], km[4]
  vim.keymap.set(mode, key, action, { noremap = true, silent = true, desc = desc })
end
