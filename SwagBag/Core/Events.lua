-- SwagBag event bus, out-of-combat queue and debounce.
--   SB.On(event, fn, window)   fn(event, ...) runs inside ErrorTrap.Run(label, window)
--   SB.Emit(event, ...)        dispatch now (used for internal "SB_*" messages)
--   SB.OutOfCombat(fn, label, window)  run now, or once combat ends (deduped by label)
--   SB.Debounce(key, delay, fn, window) run fn once, `delay` s after the LAST call
-- Events whose names start with "SB_" are internal and never registered with WoW.
local _, SB = ...

local handlers = {} -- event -> list of { fn, window, label }
local frame = CreateFrame("Frame")
SB.eventFrame = frame

local function isInternal(event)
	return event:sub(1, 3) == "SB_"
end

-- Returns false if WoW refused the event (e.g. removed by a patch); true otherwise.
function SB.On(event, fn, window)
	local list = handlers[event]
	if not list then
		if not isInternal(event) then
			local ok = pcall(frame.RegisterEvent, frame, event)
			if not ok then
				return false
			end
		end
		list = {}
		handlers[event] = list
	end
	list[#list + 1] = { fn = fn, window = window, label = "event:" .. event }
	return true
end

function SB.Emit(event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		local h = list[i]
		SB.ErrorTrap.Run(h.label, h.window, h.fn, event, ...)
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	SB.Emit(event, ...)
end)

---------------------------------------------------------------------------
-- Out-of-combat queue
---------------------------------------------------------------------------
local queue = {}

-- Returns true if fn ran now, false if it was queued for PLAYER_REGEN_ENABLED.
function SB.OutOfCombat(fn, label, window)
	label = label or "outOfCombat"
	if not SB.Adapter.InCombat() then
		SB.ErrorTrap.Run(label, window, fn)
		return true
	end
	for i = 1, #queue do
		if queue[i].label == label then
			queue[i] = { fn = fn, label = label, window = window }
			return false
		end
	end
	queue[#queue + 1] = { fn = fn, label = label, window = window }
	return false
end

function SB.OutOfCombatPending()
	return #queue
end

SB.On("PLAYER_REGEN_ENABLED", function()
	local q = queue
	queue = {}
	for i = 1, #q do
		SB.ErrorTrap.Run(q[i].label, q[i].window, q[i].fn)
	end
end, "none")

---------------------------------------------------------------------------
-- Debounce (trailing): only the last call within `delay` seconds runs.
---------------------------------------------------------------------------
local generations = {}

function SB.Debounce(key, delay, fn, window)
	local gen = (generations[key] or 0) + 1
	generations[key] = gen
	SB.Adapter.After(delay, function()
		if generations[key] == gen then
			SB.ErrorTrap.Run("debounce:" .. key, window, fn)
		end
	end)
end
