local M = {}

-- Comprehensive cache for project metadata to avoid repeated filesystem lookups
local project_cache = {
  root = {}, -- Project root paths
  metadata = {}, -- Project metadata (is_web, csproj_path, etc.)
}

-- Helper: Get current file context
local function get_current_context()
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir = vim.fn.fnamemodify(current_file, ":p:h")
  return current_file, current_dir
end

-- Helper: Get cache key for current buffer
local function get_cache_key()
  local _, current_dir = get_current_context()
  return current_dir
end

-- Find the root directory of a .NET project by searching for .csproj files
function M.find_project_root_by_csproj(start_path)
  -- Check cache first
  if project_cache.root[start_path] then
    return project_cache.root[start_path]
  end

  local Path = require("plenary.path")
  local path = Path:new(start_path)

  while true do
    local csproj_files = vim.fn.glob(path:absolute() .. "/*.csproj", false, true)
    if #csproj_files > 0 then
      local root = path:absolute()
      project_cache.root[start_path] = root -- Cache result
      return root
    end

    local parent = path:parent()
    if parent:absolute() == path:absolute() then
      return nil
    end

    path = parent
  end
end

-- Find the highest version of the netX.Y folder within a given path.
function M.get_highest_net_folder(bin_debug_path)
  local dirs = vim.fn.glob(bin_debug_path .. "/net*", false, true)

  if #dirs == 0 then
    error("No netX.Y folders found in " .. bin_debug_path)
  end

  table.sort(dirs, function(a, b)
    -- Extract version from folder name (e.g., "net8.0" -> 8.0)
    local name_a = vim.fn.fnamemodify(a, ":t")
    local name_b = vim.fn.fnamemodify(b, ":t")

    local major_a, minor_a = name_a:match("net(%d+)%.?(%d*)")
    local major_b, minor_b = name_b:match("net(%d+)%.?(%d*)")

    major_a = tonumber(major_a) or 0
    major_b = tonumber(major_b) or 0
    minor_a = tonumber(minor_a) or 0
    minor_b = tonumber(minor_b) or 0

    if major_a ~= major_b then
      return major_a > major_b
    end
    return minor_a > minor_b
  end)

  return dirs[1]
end

-- Get or initialize project metadata (cached)
local function get_project_metadata()
  local cache_key = get_cache_key()

  -- Return cached metadata if available
  if project_cache.metadata[cache_key] then
    return project_cache.metadata[cache_key]
  end

  local _, current_dir = get_current_context()
  local project_root = M.find_project_root_by_csproj(current_dir)

  if not project_root then
    return nil
  end

  -- Find .csproj file
  local csproj_files = vim.fn.glob(project_root .. "/*.csproj", false, true)
  if #csproj_files == 0 then
    return nil
  end

  local csproj_path = csproj_files[1]
  local project_name = vim.fn.fnamemodify(csproj_path, ":t:r")

  -- Read .csproj content once
  local file = io.open(csproj_path, "r")
  if not file then
    return nil
  end

  local csproj_content = file:read("*all")
  file:close()

  -- Detect project type
  local is_web = csproj_content:match('Sdk%s*=%s*"Microsoft%.NET%.Sdk%.Web"') ~= nil

  -- If not detected as web, check for launchSettings.json
  if not is_web then
    local launch_settings_path = project_root .. "/Properties/launchSettings.json"
    local launch_file = io.open(launch_settings_path, "r")
    if launch_file then
      launch_file:close()
      is_web = true
    end
  end

  -- Cache all metadata
  local metadata = {
    project_root = project_root,
    csproj_path = csproj_path,
    project_name = project_name,
    is_web = is_web,
    launch_settings = {}, -- Will be populated when needed
  }

  project_cache.metadata[cache_key] = metadata
  return metadata
end

-- Return the full path to the .dll file for debugging.
function M.build_dll_path()
  local metadata = get_project_metadata()
  if not metadata then
    error("Could not find project root (no .csproj found)")
  end

  local bin_debug_path = metadata.project_root .. "/bin/Debug"
  local highest_net_folder = M.get_highest_net_folder(bin_debug_path)
  local dll_path = highest_net_folder .. "/" .. metadata.project_name .. ".dll"

  print("Launching: " .. dll_path)
  return dll_path
end

-- Return the project root directory (where .csproj is located)
-- This is used as the working directory so appsettings.json can be found
function M.get_project_cwd()
  local metadata = get_project_metadata()
  if not metadata then
    error("Could not find project root (no .csproj found)")
  end

  -- Return the bin/Debug/netX.Y folder where the DLL is located
  -- This is where .NET looks for appsettings.json when running the DLL directly
  local bin_debug_path = metadata.project_root .. "/bin/Debug"
  local highest_net_folder = M.get_highest_net_folder(bin_debug_path)

  print("Working directory: " .. highest_net_folder)
  return highest_net_folder
end

-- Parse launchSettings.json to get the applicationUrl from a specific profile
function M.get_application_url(profile_name)
  profile_name = profile_name or "http" -- Default to 'http' profile

  local cache_key = get_cache_key()
  local metadata = project_cache.metadata[cache_key]
  if not metadata then
    return nil
  end

  -- Check if we have cached launch settings
  if metadata.launch_settings and metadata.launch_settings[profile_name] then
    return metadata.launch_settings[profile_name]
  end

  local launch_settings_path = metadata.project_root .. "/Properties/launchSettings.json"
  local file = io.open(launch_settings_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*all")
  file:close()

  -- Try to use vim.json.decode if available (Neovim 0.5+)
  local ok, json_data = pcall(vim.json.decode, content)
  if ok and json_data and json_data.profiles then
    -- Cache all profiles for future use
    metadata.launch_settings = {}
    for profile, data in pairs(json_data.profiles) do
      if data.applicationUrl then
        local first_url = data.applicationUrl:match("([^;]+)")
        metadata.launch_settings[profile] = first_url
      end
    end

    local url = metadata.launch_settings[profile_name]
    if url then
      print("Using applicationUrl: " .. url)
      return url
    end
  else
    -- Fallback to pattern matching if JSON parsing fails
    local profile_pattern = '"' .. profile_name .. '"%s*:%s*%b{}'
    local profile_block = content:match(profile_pattern)

    if profile_block then
      local app_url = profile_block:match('"applicationUrl"%s*:%s*"([^"]+)"')
      if app_url then
        local first_url = app_url:match("([^;]+)")
        print("Using applicationUrl: " .. first_url)
        return first_url
      end
    end
  end

  return nil
end

-- Detect if the project is a web project by checking the SDK type in .csproj
function M.is_web_project()
  local metadata = get_project_metadata()
  return metadata and metadata.is_web or false
end

-- Build the .NET project before debugging
function M.build_project()
  local metadata = get_project_metadata()
  if not metadata then
    vim.notify("Could not find project root (no .csproj found)", vim.log.levels.ERROR)
    error("Could not find project root (no .csproj found)")
  end

  local project_root = metadata.project_root

  -- Try to use fidget for progress, fall back to vim.notify
  local fidget_ok, fidget = pcall(require, "fidget")
  local progress_handle

  if fidget_ok and fidget.progress then
    -- Use fidget progress API
    progress_handle = fidget.progress.handle.create({
      title = ".NET Build",
      message = "Building project...",
      lsp_client = { name = "dotnet" },
    })
  else
    -- Fallback to vim.notify
    vim.notify("🔨 Building .NET project...", vim.log.levels.INFO)
  end

  -- Use vim.system for async build (Neovim 0.10+)
  local build_error = nil
  local done = false

  vim.system(
    { "dotnet", "build", project_root, "--configuration", "Debug" },
    {
      text = true,
      cwd = project_root,
    },
    vim.schedule_wrap(function(obj)
      done = true
      if obj.code ~= 0 then
        build_error = (obj.stdout or "") .. (obj.stderr or "")
      else
        -- build_output = obj.stdout or ""
      end
    end)
  )

  -- Wait for build to complete with progress updates
  local timeout = 60000 -- 60 seconds
  local elapsed = 0
  local poll_interval = 100 -- 100ms
  local dot_count = 0
  local last_update = 0

  while not done and elapsed < timeout do
    -- Use vim.wait with predicate function for better efficiency
    vim.wait(poll_interval, function()
      return done
    end)

    if done then
      break
    end

    elapsed = elapsed + poll_interval

    -- Update progress animation every 500ms
    if progress_handle and (elapsed - last_update) >= 500 then
      dot_count = (dot_count + 1) % 4
      local dots = string.rep(".", dot_count == 0 and 3 or dot_count)
      progress_handle:report({ message = "Building" .. dots })
      last_update = elapsed
    end
  end

  -- Handle timeout
  if not done then
    if progress_handle then
      progress_handle:finish()
    end
    vim.notify("❌ Build timeout (60s)", vim.log.levels.ERROR)
    error("Build timeout")
  end

  -- Handle build failure
  if build_error then
    if progress_handle then
      progress_handle:finish()
    end

    vim.notify("❌ Build failed! Opening output window...", vim.log.levels.ERROR)

    -- Open a split window to show build output
    vim.cmd("split")
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(build_error, "\n"))
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "log"
    vim.api.nvim_buf_set_name(buf, "Build Output (Failed)")

    error("Build failed:\n" .. build_error)
  end

  -- Handle success
  if progress_handle then
    progress_handle:report({ message = "Build successful! ✓" })
    -- Keep success message visible for 1.5 seconds
    vim.defer_fn(function()
      progress_handle:finish()
    end, 1500)
  else
    vim.notify("✅ Build successful! Starting debugger...", vim.log.levels.INFO)
  end

  return true
end

-- Generate build command for the current project
function M.get_build_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet build " .. vim.fn.shellescape(metadata.project_root) .. " --configuration Debug"
end

-- Generate build command with release configuration
function M.get_build_command_release()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet build " .. vim.fn.shellescape(metadata.project_root) .. " --configuration Release"
end

-- Generate clean command
function M.get_clean_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet clean " .. vim.fn.shellescape(metadata.project_root)
end

-- Generate restore command
function M.get_restore_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet restore " .. vim.fn.shellescape(metadata.project_root)
end

-- Generate run command
function M.get_run_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet run --project " .. vim.fn.shellescape(metadata.project_root)
end

-- Generate test command
function M.get_test_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet test " .. vim.fn.shellescape(metadata.project_root)
end

-- Generate publish command
function M.get_publish_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet publish " .. vim.fn.shellescape(metadata.project_root) .. " --configuration Release"
end

-- Generate add package command with parameter placeholder
function M.get_add_package_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet add " .. vim.fn.shellescape(metadata.project_root) .. " package <package-name>"
end

-- Generate remove package command with parameter placeholder
function M.get_remove_package_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet remove " .. vim.fn.shellescape(metadata.project_root) .. " package <package-name>"
end

-- Generate list packages command
function M.get_list_packages_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet list " .. vim.fn.shellescape(metadata.project_root) .. " package"
end

-- Generate add project reference command with parameter placeholder
function M.get_add_reference_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet add " .. vim.fn.shellescape(metadata.project_root) .. " reference <path-to-csproj>"
end

-- Generate list references command
function M.get_list_references_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet list " .. vim.fn.shellescape(metadata.project_root) .. " reference"
end

-- Generate watch command (for hot reload)
function M.get_watch_command()
  local metadata = get_project_metadata()
  if not metadata then
    return nil
  end
  return "dotnet watch --project " .. vim.fn.shellescape(metadata.project_root)
end

-- Find .sln file in current directory or parent directories
local function find_solution_file(start_path)
  local Path = require("plenary.path")
  local path = Path:new(start_path)

  while true do
    local sln_files = vim.fn.glob(path:absolute() .. "/*.sln", false, true)
    if #sln_files > 0 then
      return sln_files[1]
    end

    local parent = path:parent()
    if parent:absolute() == path:absolute() then
      return nil
    end

    path = parent
  end
end

-- Generate solution-related commands (dynamic if .sln exists)
function M.get_sln_add_command()
  local _, current_dir = get_current_context()
  local sln_file = find_solution_file(current_dir)

  if sln_file then
    return "dotnet sln " .. vim.fn.shellescape(sln_file) .. " add <path-to-csproj>"
  end
  return nil
end

function M.get_sln_list_command()
  local _, current_dir = get_current_context()
  local sln_file = find_solution_file(current_dir)

  if sln_file then
    return "dotnet sln " .. vim.fn.shellescape(sln_file) .. " list"
  end
  return nil
end

function M.get_sln_build_command()
  local _, current_dir = get_current_context()
  local sln_file = find_solution_file(current_dir)

  if sln_file then
    return "dotnet build " .. vim.fn.shellescape(sln_file)
  end
  return nil
end

function M.get_sln_test_command()
  local _, current_dir = get_current_context()
  local sln_file = find_solution_file(current_dir)

  if sln_file then
    return "dotnet test " .. vim.fn.shellescape(sln_file)
  end
  return nil
end

return M
