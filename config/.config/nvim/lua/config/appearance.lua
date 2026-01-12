-- UI/Appearance configuration
-- Single source of truth for visual preferences
local M = {}

-- Core setting
M.transparent_background = true

-- Derived settings based on transparency
M.border_style = M.transparent_background and "rounded" or nil

return M
