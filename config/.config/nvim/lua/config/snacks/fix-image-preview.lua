--------------------------------------------------------------------------------
-- Fix: Image preview renders at wrong position in WezTerm/WSL/tmux
--------------------------------------------------------------------------------
-- CONTEXT & PROBLEM:
-- When using WezTerm in WSL with LazyVim's snacks.nvim image preview,
-- images consistently render at the wrong position (always at top-left 0,0)
-- instead of the calculated window position.
--
-- IMAGE PREVIEW FLOW:
-- 1. lua/snacks/image/placement.lua: update() is called
-- 2. Calls self:render_fallback(state) for non-placeholder terminals
-- 3. render_fallback() executes TWO SEPARATE operations:
--    a) terminal.set_cursor(cursor_pos)  -- Move cursor to target position
--    b) terminal.request({...})          -- Display image at cursor position
-- 4. Both commands go through lua/snacks/image/terminal.lua: M.write()
-- 5. Finally: io.stdout:write(data) sends to terminal
--
-- OBSERVED ISSUE:
-- The current implementation sends cursor movement and image display as
-- TWO SEPARATE write operations, which:
--
-- Works without tmux:
--   - Cursor: \027[7;108H
--   - Image:  \027_Ga=p,r=19,i=2899999,q=2,p=11,c=82,C=1\027\\
--
-- Doesn't work with tmux:
--   - Cursor: ^[Ptmux;^[^[[7;108H^[\
--   - Image:  ^[Ptmux;^[^[_Ga=p,r=19,i=2899999,q=2,p=11,c=82,C=1^[^[\\^[\
--   Guess:
--     • Terminal may not process them as a coordinated sequence
--     • Cursor position may not be correctly applied to image placement
--
-- SOLUTION:
-- Combine both commands into a SINGLE write operation:
--   ^[Ptmux;^[^[[7;108H^[^[_Ga=p,r=19,i=2899999,q=2,p=11,c=82,C=1^[^[\\^[\
--   └─────┬────┘└─────┬─────┘└──────────────────┬──────────────────────┘
--    tmux start     cursor           image command (both in ONE wrap)
--
-- This ensures:
--   ✓ Cursor movement and image display sent as single sequence
--   ✓ Terminal receives them together without interleaving
--   ✓ Works correctly in WezTerm/WSL/tmux environments
--   ✓ Image renders at the correct calculated position
--
-- USAGE:
--   require("config.snacks.fix-image-preview")()
--------------------------------------------------------------------------------

return function()
  local terminal = require("snacks.image.terminal")
  local Placement = require("snacks.image.placement")

  -- ============================================================================
  -- PATCH 1: Override terminal.request() to support atomic operations
  -- ============================================================================
  -- Extends terminal.request() to accept an optional 'cursor_pos' parameter.
  -- When provided, cursor movement (ESC[row;colH) is concatenated with the
  -- Kitty graphics command (ESC_G...ESC\) BEFORE calling write(), ensuring
  -- both are wrapped together in tmux passthrough and sent as one operation.
  --
  -- Original behavior: terminal.request({a="p", i=123, ...})
  --   → Only sends image command
  --
  -- New behavior: terminal.request({a="p", i=123, ..., cursor_pos={row, col}})
  --   → Sends cursor movement + image command in single write()
  -- ============================================================================
  terminal.request = function(request_opts)
    request_opts.q = request_opts.q ~= false and (request_opts.q or 2) or nil
    local msg = {}
    for k, v in pairs(request_opts) do
      if k ~= "data" and k ~= "cursor_pos" then
        table.insert(msg, string.format("%s=%s", k, v))
      end
    end
    msg = { table.concat(msg, ",") }
    if request_opts.data then
      msg[#msg + 1] = ";"
      msg[#msg + 1] = tostring(request_opts.data)
    end
    local data = "\27_G" .. table.concat(msg) .. "\27\\"

    if Snacks.image.config.debug.request and request_opts.m ~= 1 then
      Snacks.debug.inspect(request_opts)
    end

    -- Combine cursor movement with image command for single write operation
    -- This is the KEY FIX: concatenate escape sequences before write()
    if request_opts.cursor_pos then
      -- Build CSI cursor positioning command: ESC[row;colH
      -- Note: Terminal uses 1-based indexing, so we add 1 to column
      local cursor_data = "\27[" .. request_opts.cursor_pos[1] .. ";" .. (request_opts.cursor_pos[2] + 1) .. "H"
      -- Concatenate cursor + image data, then write as ONE operation
      -- This ensures both commands are sent together to the terminal
      terminal.write(cursor_data .. data)
    else
      terminal.write(data)
    end
  end

  -- ============================================================================
  -- PATCH 2: Override render_fallback() to use single write operation
  -- ============================================================================
  -- Modifies render_fallback() to calculate cursor position but NOT call
  -- terminal.set_cursor() separately. Instead, passes cursor_pos to
  -- terminal.request() which handles combining both commands.
  --
  -- Original flow (doesn't work in WezTerm/WSL/tmux):
  --   1. Calculate cursor_pos
  --   2. terminal.set_cursor(cursor_pos)  ← Write #1
  --   3. terminal.request({...})          ← Write #2 (separate!)
  --
  -- Fixed flow:
  --   1. Calculate cursor_pos
  --   2. terminal.request({..., cursor_pos=cursor_pos})  ← Single write
  --
  -- This eliminates issues where two separate writes don't coordinate
  -- correctly, ensuring the image appears at the intended position.
  -- ============================================================================
  Placement.render_fallback = function(self, state)
    if not self.opts.inline then
      vim.api.nvim_buf_clear_namespace(self.buf, Placement.ns, 0, -1)
    end

    for _, win in ipairs(state.wins) do
      self:debug("render_fallback", win)
      local border = setmetatable({ opts = vim.api.nvim_win_get_config(win) }, { __index = Snacks.win }):border_size()
      local pos = vim.api.nvim_win_get_position(win)

      -- Calculate cursor position based on window position and borders
      -- This accounts for:
      --   - Window position in the editor (pos)
      --   - Border offsets (border.top, border.left)
      --   - Tab line offset when applicable
      -- Note: We DON'T call terminal.set_cursor() here anymore
      local cursor_pos
      if
        (Snacks.config.styles.snacks_image.relative ~= "editor")
        and ((vim.o.showtabline == 2) or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") > 1))
      then
        -- Custom: Add 1 extra row to move image preview down for personal config
        cursor_pos = { pos[1] + border.top + 1, pos[2] + border.left }
      else
        cursor_pos = { pos[1] + 1 + border.top, pos[2] + border.left }
      end

      -- Send image request with cursor position for atomic rendering
      -- The cursor_pos parameter triggers PATCH 1's atomic write logic
      -- Parameters:
      --   a="p"    : action = put/display image
      --   i        : image ID (from loaded image)
      --   p        : placement ID (unique per image instance)
      --   C=1      : cursor movement policy (do not move cursor after image)
      --   c        : columns (image width in character cells)
      --   r        : rows (image height in character cells)
      --   cursor_pos: {row, col} triggers atomic cursor+image write
      terminal.request({
        a = "p",
        i = self.img.id,
        p = self.id,
        C = 1,
        c = state.loc.width,
        r = state.loc.height,
        cursor_pos = cursor_pos, -- KEY: Enables atomic rendering
      })
    end
  end
end
