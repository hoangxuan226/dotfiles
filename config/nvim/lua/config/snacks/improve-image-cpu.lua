--------------------------------------------------------------------------------
-- Fix: High CPU usage when previewing images rapidly
--------------------------------------------------------------------------------
-- CONTEXT & PROBLEM:
-- When scrolling quickly through files in the picker, multiple image placements
-- are created and destroyed rapidly. Two issues cause CPU spikes:
--
-- ISSUE 1: progress() timer accumulation
--   Each unloaded image placement starts an 80ms repeating timer to animate
--   the loading spinner. If you scroll past 10 images before any loads, you
--   get 10 concurrent timers firing 12 times/sec, each hammering:
--     - vim.api.nvim_buf_clear_namespace()
--     - vim.api.nvim_buf_set_extmark()
--   These are all on the main thread with no concurrency cap.
--
--   Original flow:
--     placement A created → progress() starts timer A (runs forever until ready)
--     placement B created → progress() starts timer B (runs forever until ready)
--     ...N placements → N timers × 12/sec = N × 2 nvim API calls/sec
--
--   Fixed flow:
--     Each placement ID maps to at most ONE active timer.
--     Starting a new timer for the same placement stops the previous one first.
--
-- ISSUE 2: update() debounce too short (10ms)
--   The debounced update() is set to 10ms, which is too short to absorb rapid
--   window events (WinEnter, WinResized, BufWinEnter). Each update() call:
--     - Recomputes state (win dimensions, image fit, etc.)
--     - Writes to stdout (terminal escape sequences)
--   Increasing to 100ms significantly reduces call frequency during fast scroll
--   without any noticeable visual degradation.
--
--   NOTE: We patch M.new to override the debounce AFTER the original sets it,
--   since the debounce wrapper is applied at the end of M.new().
--
-- USAGE:
--   require("config.snacks.fix-image-cpu")()
--------------------------------------------------------------------------------

return function()
  local Placement = require("snacks.image.placement")
  local uv = vim.uv or vim.loop

  -- ============================================================================
  -- PATCH 1: Prevent progress() timer accumulation
  -- ============================================================================
  -- We keep a registry of active progress timers keyed by placement ID.
  -- Before starting a new timer, we stop and close any existing one for that
  -- placement. This ensures at most ONE spinner timer exists per placement,
  -- no matter how many times progress() is called.
  -- ============================================================================
  local _progress_timers = {} ---@type table<number, uv_timer_t>

  Placement.progress = function(self)
    -- Stop and clean up any existing timer for this placement
    local existing = _progress_timers[self.id]
    if existing then
      if not existing:is_closing() then
        existing:stop()
        existing:close()
      end
      _progress_timers[self.id] = nil
    end

    -- If already ready or inline, let original handle the early-exit
    if self.opts.inline or self:ready() then
      return
    end

    -- Replicate original progress() logic but register the timer so we can
    -- stop it externally if another progress() call comes in for the same id
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {})
    vim.bo[self.buf].modifiable = false

    local timer = assert(uv.new_timer())
    _progress_timers[self.id] = timer -- register before start

    timer:start(
      0,
      80,
      vim.schedule_wrap(function()
        if self:ready() or self.img:failed() or not vim.api.nvim_buf_is_valid(self.buf) then
          timer:stop()
          if not timer:is_closing() then
            timer:close()
          end
          _progress_timers[self.id] = nil
          return
        end
        vim.api.nvim_buf_clear_namespace(self.buf, Placement.ns, 0, -1)
        vim.api.nvim_buf_set_extmark(self.buf, Placement.ns, 0, 0, {
          virt_text = {
            { Snacks.util.spinner(), "SnacksImageSpinner" },
            { " " },
            { self.img._convert:current().name .. " loading …", "SnacksImageLoading" },
          },
        })
      end)
    )
  end

  -- Also clean up the registry when a placement is closed
  local original_close = Placement.close
  Placement.close = function(self)
    local existing = _progress_timers[self.id]
    if existing then
      if not existing:is_closing() then
        existing:stop()
        existing:close()
      end
      _progress_timers[self.id] = nil
    end
    original_close(self)
  end

  -- ============================================================================
  -- PATCH 2: Increase update() debounce from 10ms → 100ms
  -- ============================================================================
  -- The original M.new() wraps update() with a 10ms debounce at the very end.
  -- We wrap M.new() to replace that debounce with a 100ms one after the fact.
  --
  -- We capture the raw (non-debounced) update method from the metatable BEFORE
  -- wrapping M.new, so we can re-debounce it cleanly without double-wrapping.
  --
  -- Why 100ms:
  --   - Fast scroll in picker triggers events every ~16ms (one per frame)
  --   - 10ms debounce barely filters anything: nearly every event fires update()
  --   - 100ms debounce absorbs a full scroll burst, firing update() only once
  --     after the user pauses, with no perceptible delay for normal usage
  -- ============================================================================
  local raw_update = Placement.update -- capture the real method before M.new wraps it

  local original_new = Placement.new
  Placement.new = function(buf, src, opts)
    local self = original_new(buf, src, opts)
    if self then
      -- M.new() has already replaced self.update with a 10ms debounce.
      -- We replace it again with a 100ms debounce over the raw method.
      self.update = Snacks.util.debounce(function()
        raw_update(self)
      end, { ms = 100 })
    end
    return self
  end
end
