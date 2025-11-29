-- evkey integration for Windows and WSL
-- Optimized version with caching and async support

local M = {}

-- Cache for platform detection
local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
local in_wsl = false

-- Detect WSL (cached after first check)
if not is_windows then
  local ok, version = pcall(vim.fn.readfile, "/proc/version")
  if ok and version and #version > 0 then
    in_wsl = string.match(version[1]:lower(), "microsoft") ~= nil
  end
end

-- Early exit if not Windows/WSL
-- if not is_windows and not in_wsl then
if not is_windows then
  return M
end

-- Configuration
local toggle_key = "^+" -- Ctrl + Shift
local powershell_exe = in_wsl and "powershell.exe" or "powershell"

-- State
M.evkey_ini_path = nil
local type_cache = nil -- Cache the last read Type value
local cache_time = 0
local CACHE_TTL = 1000 -- Cache TTL in milliseconds

-- Optimized PowerShell execution (reusable command table)
local ps_base_args = {
  powershell_exe,
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-Command",
}

local function run_powershell_cmd(ps_cmd)
  local cmd = vim.list_extend(vim.deepcopy(ps_base_args), { ps_cmd })
  local out = vim.fn.systemlist(cmd)

  if vim.v.shell_error ~= 0 then
    return nil, "ps-error"
  end

  if #out == 0 or (#out == 1 and out[1] == "") then
    return {}, nil
  end

  return out, nil
end

-- Async PowerShell execution (non-blocking)
local function run_powershell_async(ps_cmd, callback)
  local cmd = vim.list_extend(vim.deepcopy(ps_base_args), { ps_cmd })

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        callback(data, nil)
      else
        callback({}, nil)
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        callback(nil, "ps-error: " .. table.concat(data, "\n"))
      end
    end,
  })
end

-- Discover setting.ini (optimized PowerShell script)
function M.discover_setting_ini()
  -- Consolidated PowerShell script (single exit, faster)
  local ps_find = [[
    try {
      $lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\evkey64.lnk"
      if (-not (Test-Path $lnk)) { exit 1 }
 
      $shell = New-Object -ComObject WScript.Shell
      $shortcut = $shell.CreateShortcut($lnk)
      if (-not $shortcut.TargetPath) { exit 2 }
 
      $ini = Join-Path (Split-Path $shortcut.TargetPath) "setting.ini"
      if (Test-Path $ini) {
        Write-Output $ini
        exit 0
      }
      exit 3
    } catch {
      exit 99
    }
  ]]

  local out, err = run_powershell_cmd(ps_find)

  if err then
    return nil, "ps-failed"
  end

  if vim.v.shell_error == 1 then
    return nil, "no-lnk"
  elseif vim.v.shell_error == 2 then
    return nil, "no-target"
  elseif vim.v.shell_error == 3 then
    return nil, "no-ini"
  elseif vim.v.shell_error == 99 then
    return nil, "ps-exception"
  end

  if out and #out > 0 then
    local path = out[1]:gsub("%s+$", ""):gsub("\r", "")
    return path, nil
  end

  return nil, "no-output"
end

-- Convert Windows path to WSL path
local function to_wsl_path(win_path)
  if not in_wsl or not win_path:match("^[A-Z]:") then
    return win_path
  end

  local path = win_path:gsub("\\", "/")
  local drive = path:match("^([A-Z]):")

  if drive then
    return "/mnt/" .. drive:lower() .. path:sub(3)
  end

  return path
end

-- Read Type from setting.ini (with caching)
local function read_type_from_ini(path, force)
  if not path then
    return nil
  end

  -- Return cached value if still valid
  local now = vim.uv.now()
  if not force and type_cache ~= nil and (now - cache_time) < CACHE_TTL then
    return type_cache
  end

  local read_path = to_wsl_path(path)

  if vim.fn.filereadable(read_path) == 0 then
    return nil
  end

  local ok, lines = pcall(vim.fn.readfile, read_path)
  if not ok then
    return nil
  end

  for _, line in ipairs(lines) do
    local value = line:match("^%s*Type%s*=%s*(%d)%s*$")
    if value then
      local type_val = tonumber(value)
      -- Update cache
      type_cache = type_val
      cache_time = now
      return type_val
    end
  end

  return nil
end

-- Send toggle key (async version to avoid blocking)
local function send_toggle_key(callback)
  local ps_send = string.format(
    [[Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('%s'); exit 0]],
    toggle_key
  )

  if callback then
    run_powershell_async(ps_send, function(_, err)
      if err then
        vim.schedule(function()
          vim.notify("EVKey: failed to send toggle", vim.log.levels.WARN)
        end)
      end
      callback()
    end)
  else
    -- Synchronous fallback
    run_powershell_cmd(ps_send)
  end
end

-- Check and send if Vietnamese (with optional async)
function M.check_and_send_if_viet(ini_path, async)
  ini_path = ini_path or M.evkey_ini_path
  if not ini_path then
    return false, "no-ini"
  end

  local type_val = read_type_from_ini(ini_path)
  if type_val == nil then
    return false, "no-type"
  end

  if type_val == 1 then
    if async then
      send_toggle_key(function()
        -- Invalidate cache after toggle
        type_cache = nil
      end)
    else
      send_toggle_key()
      type_cache = nil -- Invalidate cache
    end
    return true, "sent"
  end

  return false, "already-en"
end

-- Manual toggle command
function M.toggle()
  if not M.evkey_ini_path then
    vim.notify("EVKey: not initialized", vim.log.levels.WARN)
    return
  end
  send_toggle_key()
  type_cache = nil -- Invalidate cache
  vim.notify("EVKey: manual toggle sent", vim.log.levels.INFO)
end

-- Quiet mode toggle (suppress notifications)
M.quiet = false

local function notify(msg, level)
  if not M.quiet then
    vim.notify(msg, level)
  end
end

-- Setup autocmds
local function setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("EVKeyIntegration", { clear = true })

  -- VimEnter: discover and initialize
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup,
    callback = function()
      local path, err = M.discover_setting_ini()

      if path then
        M.evkey_ini_path = path
        vim.g.evkey_setting_ini = path
        notify("EVKey: initialized (" .. path .. ")", vim.log.levels.INFO)

        -- Initial check (async to avoid blocking startup)
        vim.defer_fn(function()
          local ok = M.check_and_send_if_viet(path, true)
          if ok then
            notify("EVKey: switched to English on startup", vim.log.levels.INFO)
          end
        end, 100)
      else
        notify("EVKey: disabled (" .. tostring(err) .. ")", vim.log.levels.WARN)
      end
    end,
  })

  -- InsertLeave: ensure English (async, non-blocking)
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function()
      if M.evkey_ini_path then
        M.check_and_send_if_viet(M.evkey_ini_path, true)
      end
    end,
  })

  -- FocusGained: ensure English when not in insert mode
  vim.api.nvim_create_autocmd("FocusGained", {
    group = augroup,
    callback = function()
      if not M.evkey_ini_path then
        return
      end

      local mode = vim.api.nvim_get_mode().mode
      if mode == "i" or mode == "ic" then
        return
      end

      M.check_and_send_if_viet(M.evkey_ini_path, true)
    end,
  })
end

-- Initialize
setup_autocmds()

-- User commands
vim.api.nvim_create_user_command("EVKeyToggle", function()
  M.toggle()
end, { desc = "Manually toggle EVKey input method" })

vim.api.nvim_create_user_command("EVKeyStatus", function()
  if not M.evkey_ini_path then
    print("EVKey: not initialized")
    return
  end

  local type_val = read_type_from_ini(M.evkey_ini_path, true)
  local status = type_val == 1 and "Vietnamese" or "English"
  print(string.format("EVKey: %s (Type=%s)", status, tostring(type_val)))
end, { desc = "Show EVKey current status" })

-- Expose module for debugging
_G._evkey_integration = M

return M
