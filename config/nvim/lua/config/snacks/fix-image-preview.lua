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
-- ADDITIONAL FIX: tmux pane offset
-- nvim_win_get_position() returns coordinates within Neovim's editor grid
-- (0-indexed from the top-left of the Neovim UI), but terminal cursor escape
-- sequences (ESC[row;colH) address the FULL terminal screen.
-- In tmux, the Neovim pane may not start at screen (0,0) — for example,
-- in a vertical split the right pane starts at column N, not column 0.
-- Without accounting for this, images always render at the wrong column.
-- Fix: query tmux for #{pane_top} and #{pane_left} and add them to cursor_pos.
--
-- USAGE:
--   require("config.snacks.fix-image-preview")()
--------------------------------------------------------------------------------

return function()
  local terminal = require("snacks.image.terminal")
  local Placement = require("snacks.image.placement")

  -- ============================================================================
  -- HELPER: Get tmux pane offset (cached)
  -- ============================================================================
  -- In tmux, Neovim runs inside a pane whose top-left corner can be anywhere
  -- on the terminal screen (e.g. the right pane of a vertical split starts at
  -- column N). nvim_win_get_position() returns coordinates relative to Neovim's
  -- own editor grid, not the terminal screen. Since terminal cursor escape
  -- sequences use full screen coordinates, we must add the pane's offset.
  --
  -- We query tmux once and cache the result — the offset doesn't change while
  -- Neovim is running in the same pane.
  --
  -- Example: Neovim window at editor pos {0, 0} inside a right pane at col 82
  --   Without offset: ESC[1;1H  → image appears at top-left of screen  (wrong)
  --   With offset:    ESC[1;83H → image appears at top-left of the pane (correct)
  -- ============================================================================
  local _pane_offset = nil ---@type {[1]: number, [2]: number}?
  local function get_pane_offset()
    if _pane_offset then
      return _pane_offset
    end
    _pane_offset = { 0, 0 } -- default: no offset when not in tmux
    if vim.env.TMUX then
      -- #{pane_top} and #{pane_left} are the 0-based row/col of the pane's
      -- top-left corner on the full terminal screen
      local ok, out = pcall(vim.fn.system, { "tmux", "display-message", "-p", "#{pane_top},#{pane_left}" })
      if ok and out then
        local row, col = out:match("^(%d+),(%d+)")
        if row and col then
          _pane_offset = { tonumber(row), tonumber(col) }
        end
      end
    end
    return _pane_offset
  end

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
  -- PATCH 2: Override render_fallback() to use single atomic write operation
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
  --   1. Calculate cursor_pos (with tmux pane offset applied)
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

      -- Calculate cursor position in full terminal screen coordinates.
      -- Components:
      --   pane_offset : tmux pane's top-left on the terminal screen (0-based)
      --   pos         : Neovim window's top-left within the editor grid (0-based)
      --   border.*    : border thickness offsets
      --   +1 row      : terminal cursor is 1-based; also accounts for tabline
      -- Note: We DON'T call terminal.set_cursor() here anymore — cursor movement
      -- is bundled into terminal.request() via cursor_pos for atomic delivery.
      local pane_offset = get_pane_offset()
      local cursor_pos
      if
        (Snacks.config.styles.snacks_image.relative ~= "editor")
        and ((vim.o.showtabline == 2) or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") > 1))
      then
        -- Custom: Add 2 extra row to move image preview down for personal config
        cursor_pos = { pane_offset[1] + pos[1] + border.top + 2, pane_offset[2] + pos[2] + border.left }
      else
        cursor_pos = { pane_offset[1] + pos[1] + 2 + border.top, pane_offset[2] + pos[2] + border.left }
      end

      -- Send image request with cursor position for atomic rendering.
      -- The cursor_pos parameter triggers PATCH 1's atomic write logic.
      -- Parameters:
      --   a="p"      : action = put/display image
      --   i          : image ID (from loaded image)
      --   p          : placement ID (unique per image instance)
      --   C=1        : cursor movement policy (do not move cursor after image)
      --   c          : columns (image width in character cells)
      --   r          : rows (image height in character cells)
      --   z=-1       : z-index (< 0 means render below text)
      --   cursor_pos : {row, col} in screen coords — triggers atomic write
      terminal.request({
        a = "p",
        i = self.img.id,
        p = self.id,
        C = 1,
        c = state.loc.width,
        r = state.loc.height,
        z = -1,
        cursor_pos = cursor_pos, -- KEY: Enables atomic cursor+image rendering
      })
    end
  end
end
