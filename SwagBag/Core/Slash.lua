-- SwagBag slash commands. P2: every command gives feedback. A command function
-- returns its feedback text, and "Done." is printed if it returns nothing.
-- P4: prologue (parsing and command lookup) runs inside ErrorTrap.
local _, SB = ...

local Slash = { commands = {}, order = {} }
SB.Slash = Slash

-- window: Safe Mode window an error in this command may flip; default "none".
function Slash.Register(name, help, fn, window)
	name = name:lower()
	if not Slash.commands[name] then
		Slash.order[#Slash.order + 1] = name
	end
	Slash.commands[name] = { help = help, fn = fn, window = window or "none" }
end

local function say(feedback)
	if type(feedback) == "table" then
		for _, line in ipairs(feedback) do
			SB.Print(line)
		end
	elseif feedback ~= nil then
		SB.Print(feedback)
	else
		SB.Print(SB.L.CMD_DONE)
	end
end

function Slash.Dispatch(msg)
	local L = SB.L
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" then
		SB.Print(L.NO_SETTINGS_YET)
		return
	end
	local c = Slash.commands[cmd]
	if not c then
		SB.Print(L.UNKNOWN_COMMAND:format(cmd))
		return
	end
	local ok, feedback = SB.ErrorTrap.Run("slash:" .. cmd, c.window, c.fn, rest)
	if not ok then
		SB.Print(L.CMD_FAILED)
		return
	end
	say(feedback)
end

Slash.Register("help", SB.L.HELP_HELP, function()
	local L = SB.L
	local lines = { L.HELP_HEADER }
	for _, name in ipairs(Slash.order) do
		lines[#lines + 1] = L.HELP_LINE:format(name, Slash.commands[name].help)
	end
	return lines
end)

if SlashCmdList then
	SLASH_SWAGBAG1 = "/swagbag"
	SlashCmdList.SWAGBAG = function(msg)
		-- P4: prologue (parsing/lookup) runs inside ErrorTrap; P6: WoW entry point inside trap
		local ok = SB.ErrorTrap.Run("slash:dispatcher", "none", function()
			Slash.Dispatch(msg)
		end)
		if not ok then
			SB.Print(SB.L.CMD_FAILED)
		end
	end
end
