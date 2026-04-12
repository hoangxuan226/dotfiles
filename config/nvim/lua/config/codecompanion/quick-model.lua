-- A tiny helper to open CodeCompanion chats from quick adapter:model presets

local M = {}

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function parse_choice(s)
  -- expected "adapter:model"
  local a, m = s:match("^%s*([^:]+)%s*:%s*(.+)%s*$")
  if a and m then
    return trim(a), trim(m)
  end
  return nil, nil
end

local function select_from_choices(choices)
  if not choices or type(choices) ~= "table" or vim.tbl_isempty(choices) then
    vim.notify("quick-model: no choices provided", vim.log.levels.ERROR)
    return
  end

  vim.ui.select(choices, { prompt = "CodeCompanion quick preset:" }, function(choice)
    if not choice then
      return
    end

    local adapter, model = parse_choice(choice)
    if not adapter or not model then
      vim.notify("Invalid preset format (expected adapter:model)", vim.log.levels.WARN)
      return
    end

    -- Open chat with adapter+model
    require("codecompanion").chat({
      params = {
        adapter = adapter,
        model = model,
      },
    })
  end)
end

--- Public API
-- open(choices: table<string>) -> shows the picker for the provided adapter:model choices
function M.open(choices)
  if type(choices) ~= "table" or vim.tbl_isempty(choices) then
    error("quick-model.open expects a non-empty table of 'adapter:model' strings")
  end
  select_from_choices(choices)
end

return M
