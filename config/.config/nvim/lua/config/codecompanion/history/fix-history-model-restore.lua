-- Problem:
-- When using `codecompanion-history` to restore a saved chat, the specific model
-- used in that chat (e.g., `gpt-5-mini` via copilot) is correctly parsed from the
-- history JSON into `chat.settings.model`. However, the core `CodeCompanion`
-- chat instantiation does not propagate this to `adapter.schema.model.default`.
-- As a result, the chat buffer UI and subsequent requests fall back to the
-- adapter's default model (e.g., `gpt-4.1`).
--
-- Solution:
-- Monkey-patch the `UI.create_chat` function of the history extension.
-- After the original `create_chat` initializes the chat object, we explicitly
-- trigger `chat:change_model()` to force the adapter and UI to synchronize
-- with the correctly restored model from the chat history.

return function()
  local ok, history_ui = pcall(require, "codecompanion._extensions.history.ui")
  if not ok then
    return
  end

  -- Save a reference to the original function
  local original_create_chat = history_ui.create_chat

  -- Override with our patched wrapper
  history_ui.create_chat = function(self, chat_data)
    -- 1. Call the original function to instantiate the chat object
    local chat = original_create_chat(self, chat_data)

    -- 2. Hot-fix: Explicitly restore the exact model if it exists in the saved settings
    if chat and chat_data and chat_data.settings and chat_data.settings.model then
      chat:change_model({ model = chat_data.settings.model })
    end

    return chat
  end
end
