local M = {}

function M.log_entry(file_path, msg)
  if not file_path then
    return
  end
  local f = io.open(file_path, "a")
  if f then
    f:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), msg))
    f:close()
  end
end

return M
