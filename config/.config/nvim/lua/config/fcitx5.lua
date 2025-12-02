local M = {}

M.closed = false

local function all_trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function determine_os()
  if vim.fn.has("wsl") == 1 then
    return "WSL"
  end
  return nil -- Not WSL
end

local function is_supported()
  local os = determine_os()
  if os ~= "WSL" then
    return false
  end
  return vim.fn.executable("fcitx5-remote") == 1
end

-- local config
local C = {
  default_command = { "fcitx5-remote" },
  default_method_selected = "keyboard-us",
  set_default_events = { "InsertLeave", "CmdlineLeave" },
  set_previous_events = { "InsertEnter" },
  async_switch_im = true,
}

local function get_current_select()
  local command = { "fcitx5-remote", "-n" }
  return all_trim(vim.fn.system(command))
end

local function change_im_select(cmd, method)
  local args = { "-s", method }
  local handle
  local uv = vim.uv or vim.loop
  handle = uv.spawn(
    cmd[1],
    ---@diagnostic disable-next-line: missing-fields
    { args = args, detach = true },
    vim.schedule_wrap(function(_, _)
      if handle and not handle:is_closing() then
        handle:close()
      end
      M.closed = true
    end)
  )
  if not handle then
    vim.notify("[im-select]: Failed to spawn process for " .. cmd[1], vim.log.levels.ERROR)
  end
  if not C.async_switch_im then
    vim.wait(5000, function()
      return M.closed
    end, 200)
  end
end

local function restore_default_im()
  local current = get_current_select()
  vim.api.nvim_set_var("im_select_saved_state", current)
  if current ~= C.default_method_selected then
    vim.notify("[fcitx5] Switching to default IM: " .. C.default_method_selected, vim.log.levels.INFO)
    change_im_select(C.default_command, C.default_method_selected)
  end
end

local function restore_previous_im()
  local current = get_current_select()
  local saved = vim.g["im_select_saved_state"]
  if current ~= saved then
    vim.notify("[fcitx5] Switching to previous IM: " .. saved, vim.log.levels.INFO)
    change_im_select(C.default_command, saved)
  end
end

M.setup = function()
  if not is_supported() then
    vim.notify("[fcitx5] Not running on WSL or fcitx5-remote not found", vim.log.levels.WARN)
    return
  end
  vim.notify("[fcitx5] IM switching enabled for WSL", vim.log.levels.INFO)
  -- Minimal opts handling if needed (omitted for reduction)
  -- set autocmd
  local group_id = vim.api.nvim_create_augroup("im-select", { clear = true })
  if #C.set_previous_events > 0 then
    vim.api.nvim_create_autocmd(C.set_previous_events, {
      callback = restore_previous_im,
      group = group_id,
    })
  end
  if #C.set_default_events > 0 then
    vim.api.nvim_create_autocmd(C.set_default_events, {
      callback = restore_default_im,
      group = group_id,
    })
  end
end

return M
