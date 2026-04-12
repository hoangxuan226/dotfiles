--------------------------------------------------------------------------------
-- Fix: Ghost image when opening image file from picker
--------------------------------------------------------------------------------
-- PROBLEM:
--   When pressing Enter on an image file in picker, TWO images appear:
--   1. Preview image (ghost) at preview location
--   2. New buffer image at correct location
--
-- ROOT CAUSE:
--   Race condition - buffer opens BEFORE preview cleanup completes:
--     picker:close() → vim.schedule(cleanup) → buffer opens → render new image
--     → (later) cleanup runs → delete old preview (too late!)
--
-- SOLUTION:
--   Clean up preview images SYNCHRONOUSLY before calling original close(),
--   so terminal receives delete command BEFORE new buffer renders.
--
-- USAGE:
--   require("config.snacks.fix-picker-ghost-image")()
--------------------------------------------------------------------------------

return function()
  local Picker = require("snacks.picker.core.picker")
  local original_close = Picker.close

  -- Wrap original close() to inject synchronous cleanup
  Picker.close = function(self)
    -- KEY FIX: Clean up preview images BEFORE calling original close
    -- This ensures terminal receives delete command synchronously,
    -- preventing ghost images when new buffer opens and renders
    if self.preview and self.preview.win and self.preview.win.buf then
      local ok, placement = pcall(require, "snacks.image.placement")
      if ok and vim.api.nvim_buf_is_valid(self.preview.win.buf) then
        placement.clean(self.preview.win.buf)
      end
    end

    -- Call original close() to handle all other cleanup
    original_close(self)
  end
end
