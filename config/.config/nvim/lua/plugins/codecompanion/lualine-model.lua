local M = require("lualine.component"):extend()

function M:init(options)
  M.super.init(self, options)
end

function M:update_status()
  local ok, codecompanion = pcall(require, "codecompanion")
  if not ok then
    return nil
  end

  -- Get the current buffer number
  local bufnr = vim.api.nvim_get_current_buf()

  -- Check if buf_get_chat function exists and call it safely
  if codecompanion.buf_get_chat then
    local success, chat = pcall(codecompanion.buf_get_chat, bufnr)

    if success and chat and chat.adapter then
      local adapter_name = chat.adapter.name or ""
      local model_name = ""

      -- Safely access the model name
      if chat.adapter.schema and chat.adapter.schema.model then
        model_name = chat.adapter.schema.model.default or ""
      end

      if adapter_name ~= "" and model_name ~= "" then
        return string.format("🤖 %s %s", adapter_name, model_name)
      end
    end
  end

  return nil
end

return M
