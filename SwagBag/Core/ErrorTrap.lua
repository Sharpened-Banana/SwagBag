-- SwagBag ErrorTrap: every entry point from WoW into SwagBag runs through
-- ErrorTrap.Run / ErrorTrap.Guard. An error is recorded in a 10-entry ring
-- buffer (mirrored into SwagBagDB.errors) and switches the affected window to
-- Safe Mode with exactly one chat line. We never call seterrorhandler, so
-- BugGrabber/BugSack keep working untouched.
local _, SB = ...

local unpack = unpack

local ET = { MAX = 10, STILL_FAILING_SECONDS = 10, buffer = {}, count = 0 }
SB.ErrorTrap = ET

local function pack(...)
	return { n = select("#", ...), ... }
end

local function clean(err)
	if SB.Adapter.IsSecret(err) then
		return "<secret>"
	end
	return tostring(err)
end

function ET.Trim()
	while #ET.buffer > ET.MAX do
		table.remove(ET.buffer, 1)
	end
end

function ET.Record(entry)
	ET.buffer[#ET.buffer + 1] = entry
	ET.Trim()
end

-- Adopt the saved list (SwagBagDB.errors) as the ring; keeps entries caught earlier.
function ET.Attach(list)
	for _, entry in ipairs(ET.buffer) do
		list[#list + 1] = entry
	end
	ET.buffer = list
	ET.Trim()
end

-- Oldest first. Returns a copy.
function ET.Recent()
	local out = {}
	for i, entry in ipairs(ET.buffer) do
		out[i] = entry
	end
	return out
end

-- window: "bags" | "bank" | nil (both) | "none" (record only, never Safe Mode).
function ET.OnError(label, window, message, stack)
	local A = SB.Adapter
	ET.count = ET.count + 1
	ET.Record({
		time = A.Date("%Y-%m-%d %H:%M:%S"),
		label = label,
		window = window or "both",
		message = message,
		stack = stack,
		version = SB.VERSION,
		combat = A.InCombat(),
	})
	if window == "none" then
		return
	end
	local SM = SB.SafeMode
	local targets = window and { window } or SM.WINDOWS
	local switched, stillFailing = false, false
	for _, w in ipairs(targets) do
		if not SM.IsOn(w) then
			if SM.RecentlyDisabled(w, ET.STILL_FAILING_SECONDS) then
				stillFailing = true
			end
			SM.Enable(w, "auto")
			switched = true
		end
	end
	if stillFailing then
		SB.Print(SB.L.ERROR_STILL_FAILING)
	elseif switched then
		SB.Print(SB.L.ERROR_SWITCHED)
	end
end

-- Run fn(...) now. Returns true, fn's results on success; false on error.
function ET.Run(label, window, fn, ...)
	local args = pack(...)
	local caught
	local r = pack(xpcall(function()
		return fn(unpack(args, 1, args.n))
	end, function(err)
		caught = { message = clean(err), stack = SB.Adapter.Stack() }
		return caught
	end))
	if r[1] then
		return true, unpack(r, 2, r.n)
	end
	ET.OnError(label, window, caught.message, caught.stack)
	return false
end

-- Wrap fn for use as a hook/script/timer callback. Returns fn's results, or nothing on error.
function ET.Guard(label, fn, window)
	return function(...)
		return select(2, ET.Run(label, window, fn, ...))
	end
end
