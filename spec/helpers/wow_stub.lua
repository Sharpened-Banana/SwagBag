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
	if self.events[event] and self.scripts.OnEvent then
		self.scripts.OnEvent(self, event, ...)
	end
end

function Stub.CreateFrame()
	local f = setmetatable({ events = {}, scripts = {} }, Frame)
	Stub.frames[#Stub.frames + 1] = f
	return f
end

function Stub.Install()
	Stub.frames = {}
	Stub.unknownEvents = {}
	CreateFrame = Stub.CreateFrame
end

return Stub
