-- Minimal WoW API stub for unit tests. Only what pure modules touch at load time:
-- CreateFrame (event frames). Everything else goes through the mock Adapter.
local Stub = {}

-- Events listed here make RegisterEvent throw, like an event removed by a patch.
Stub.unknownEvents = {}

local Frame = {}
Frame.__index = Frame

function Frame:RegisterEvent(event)
	if Stub.unknownEvents[event] then
		error("Attempt to register unknown event \"" .. event .. "\"")
	end
	self.events[event] = true
end

-- Test fake: a unit event is delivered only when its first argument is the registered unit.
function Frame:RegisterUnitEvent(event, unit)
	if Stub.unknownEvents[event] then
		error("Attempt to register unknown event \"" .. event .. "\"")
	end
	self.unitEvents[event] = unit
end

function Frame:UnregisterEvent(event)
	self.events[event] = nil
end

function Frame:SetScript(name, fn)
	self.scripts[name] = fn
end

function Frame:GetScript(name)
	return self.scripts[name]
end

-- Test helper: deliver a WoW event the way the client would.
function Frame:Fire(event, ...)
	if self.scripts.OnEvent then
		local unit = self.unitEvents[event]
		if self.events[event] or (unit ~= nil and unit == (...)) then
			self.scripts.OnEvent(self, event, ...)
		end
	end
end

function Stub.CreateFrame()
	local f = setmetatable({ events = {}, unitEvents = {}, scripts = {} }, Frame)
	Stub.frames[#Stub.frames + 1] = f
	return f
end

function Stub.Install()
	Stub.frames = {}
	Stub.unknownEvents = {}
	CreateFrame = Stub.CreateFrame
end

return Stub
