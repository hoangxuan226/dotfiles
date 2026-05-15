local logger = {}

-- Define supported log levels
local LEVELS = {
	nothing = 0,
	info = 1,
	debug = 2,
}

logger.defaultLogLevel = "info"

-- Keep track of all created logger instances
local instances = {}

-- Helper to safely convert a string level to a number
local function getLevelNumber(lvl)
	return LEVELS[lvl] or LEVELS[logger.defaultLogLevel]
end

--- Function: setLogLevel(lvl, moduleName)
--- If moduleName is provided, updates only that module. Otherwise, updates all.
function logger.setLogLevel(lvl, moduleName)
	local numLvl = getLevelNumber(lvl)
	local count = 0
	for inst, _ in pairs(instances) do
		if moduleName == nil or inst.name == moduleName then
			inst.level = numLvl
			count = count + 1
		end
	end

	if moduleName then
		print(string.format("Set log level to '%s' for module '%s' (%d updated)", lvl, moduleName, count))
	else
		print(string.format("Set log level to '%s' for ALL modules (%d updated)", lvl, count))
	end
end

--- Function: listModules()
--- Lists all registered logger modules and their current log levels
function logger.listModules()
	print("--- Registered Logger Modules ---")
	local count = 0
	for inst, _ in pairs(instances) do
		local levelName = "unknown"
		for k, v in pairs(LEVELS) do
			if v == inst.level then
				levelName = k
				break
			end
		end
		print(string.format("- %s (level: %s)", inst.name, levelName))
		count = count + 1
	end
	if count == 0 then
		print("No modules registered yet.")
	end
	return count
end

--- Function: new(moduleName, loglevel)
--- Creates a new logger instance
function logger.new(moduleName, logLevel)
	local initialLevel = logLevel or logger.defaultLogLevel

	local logObj = {
		name = moduleName,
		level = getLevelNumber(initialLevel),
	}

	function logObj.i(msg)
		if logObj.level >= LEVELS.info then
			print("[" .. logObj.name .. "] " .. tostring(msg))
		end
	end

	function logObj.d(msg)
		if logObj.level >= LEVELS.debug then
			print("[" .. logObj.name .. "] " .. tostring(msg))
		end
	end

	-- Track this instance
	instances[logObj] = true

	return logObj
end

return logger
