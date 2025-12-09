local M = {}

local battery_status = ""
local last_read_time = 0
local cache_duration = 30 -- Cache for 30 seconds to avoid excessive file reads

local function get_battery_status()
  local now = os.time()

  -- Return cached value if still fresh
  if battery_status ~= "" and (now - last_read_time) < cache_duration then
    return battery_status
  end

  -- Read battery info
  local capacity_file = "/sys/class/power_supply/BAT1/capacity"
  local ac_online_file = "/sys/class/power_supply/AC1/online"

  -- Check if battery files exist
  local ok1, capacity_data = pcall(vim.fn.readfile, capacity_file)
  local ok2, ac_data = pcall(vim.fn.readfile, ac_online_file)

  if not ok1 or not ok2 or #capacity_data == 0 or #ac_data == 0 then
    battery_status = ""
    return battery_status
  end

  local capacity = tonumber(capacity_data[1]) or 0
  local ac_online = tonumber(vim.trim(ac_data[1])) or 0

  -- Format: {charging_icon} {percentage}
  local charging_icon = ac_online == 1 and "[ 󰂄" or "[ 󰂁"

  -- Escape % as %% for statusline
  battery_status = charging_icon .. " " .. capacity .. "%% ]"

  last_read_time = now
  return battery_status
end

M.get_battery_status = get_battery_status

return M
