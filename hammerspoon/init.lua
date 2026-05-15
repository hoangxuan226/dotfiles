-- require("lua.vim-in-place")
local logger = require("lua.logger")
local log = logger.new("Init", "info")

-- Hotkey
hs.hotkey.bind({}, "F19", require("lua.vim-overlay").Show)
hs.hotkey.bind({}, "F18", require("lua.click-hints").Draw)

hs.hotkey.bind({}, "F17", function()
	local cmd = "/Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal"
	local task = hs.task.new(os.getenv("SHELL"), function(code)
		log.d("kitten quick-access-terminal task exited, code: " .. tostring(code))
	end, { "-c", cmd })

	if not task:start() then
		log.d("ERROR: Failed to start the task!")
	end
end)

_G.clear = hs.console.clearConsole
_G.logger = {
	get = logger.listModules,
	set = logger.setLogLevel,
}
