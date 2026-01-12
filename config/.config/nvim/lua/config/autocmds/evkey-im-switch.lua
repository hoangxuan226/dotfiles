-- evkey integration for Windows
-- Optimized version with caching and async support

local M = {}

-- Early exit if not Windows
if vim.fn.has("win32") == 0 and vim.fn.has("win64") == 0 then
  return M
end

-- Configuration
local toggle_key = "^+" -- Ctrl + Shift
local CACHE_TTL = 1000 -- Cache TTL in milliseconds

-- State
M.evkey_ini_path = nil
local type_cache = nil
local cache_time = 0

-- PowerShell base arguments
local ps_base_args = {
  "powershell",
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-Command",
}

-- Execute PowerShell command synchronously
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

-- Execute PowerShell command asynchronously
local function run_powershell_async(ps_cmd, callback)
  local cmd = vim.list_extend(vim.deepcopy(ps_base_args), { ps_cmd })

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      callback(data and #data > 0 and data or {}, nil)
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        callback(nil, "ps-error: " .. table.concat(data, "\n"))
      end
    end,
  })
end

-- Discover setting.ini path
function M.discover_setting_ini()
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

  local exit_codes = {
    [1] = "no-lnk",
    [2] = "no-target",
    [3] = "no-ini",
    [99] = "ps-exception",
  }

  local err_msg = exit_codes[vim.v.shell_error]
  if err_msg then
    return nil, err_msg
  end

  if out and #out > 0 then
    return out[1]:gsub("%s+$", ""):gsub("\r", ""), nil
  end

  return nil, "no-output"
end

-- Read Type value from setting.ini with caching
local function read_type_from_ini(path, force)
  if not path then
    return nil
  end

  -- Return cached value if valid
  local now = vim.uv.now()
  if not force and type_cache and (now - cache_time) < CACHE_TTL then
    return type_cache
  end

  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end

  for _, line in ipairs(lines) do
    local value = line:match("^%s*Type%s*=%s*(%d)%s*$")
    if value then
      type_cache = tonumber(value)
      cache_time = now
      return type_cache
    end
  end

  return nil
end

-- Send toggle key command
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
    run_powershell_cmd(ps_send)
  end
end

-- Check current Type and send toggle if Vietnamese
function M.check_and_send_if_viet(ini_path, async)
  ini_path = ini_path or M.evkey_ini_path
  if not ini_path then
    return false, "no-ini"
  end

  local type_val = read_type_from_ini(ini_path)
  if not type_val then
    return false, "no-type"
  end

  if type_val == 1 then
    if async then
      send_toggle_key(function()
        type_cache = nil
      end)
    else
      send_toggle_key()
      type_cache = nil
    end
    return true, "sent"
  end

  return false, "already-en"
end

-- Manual toggle
function M.toggle()
  if not M.evkey_ini_path then
    vim.notify("EVKey: not initialized", vim.log.levels.WARN)
    return
  end
  send_toggle_key()
  type_cache = nil
  vim.notify("EVKey: manual toggle sent", vim.log.levels.INFO)
end

-- Quiet mode for suppressing notifications
M.quiet = false

local function notify(msg, level)
  if not M.quiet then
    vim.notify(msg, level)
  end
end

-- Setup autocmds
local function setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("EVKeyIntegration", { clear = true })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup,
    callback = function()
      local path, err = M.discover_setting_ini()

      if path then
        M.evkey_ini_path = path
        vim.g.evkey_setting_ini = path
        notify("EVKey: initialized (" .. path .. ")", vim.log.levels.INFO)

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

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function()
      if M.evkey_ini_path then
        M.check_and_send_if_viet(M.evkey_ini_path, true)
      end
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = augroup,
    callback = function()
      if not M.evkey_ini_path then
        return
      end

      local mode = vim.api.nvim_get_mode().mode
      if mode ~= "i" and mode ~= "ic" then
        M.check_and_send_if_viet(M.evkey_ini_path, true)
      end
    end,
  })
end

-- Initialize
setup_autocmds()

-- User commands
vim.api.nvim_create_user_command("EVKeyToggle", M.toggle, {
  desc = "Manually toggle EVKey input method",
})

vim.api.nvim_create_user_command("EVKeyStatus", function()
  if not M.evkey_ini_path then
    print("EVKey: not initialized")
    return
  end

  local type_val = read_type_from_ini(M.evkey_ini_path, true)
  local status = type_val == 1 and "Vietnamese" or "English"
  print(string.format("EVKey: %s (Type=%s)", status, tostring(type_val)))
end, { desc = "Show EVKey current status" })

-- Expose for debugging
_G._evkey_integration = M

return M
