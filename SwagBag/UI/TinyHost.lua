-- SwagBag tiny mode (spec 5.2, F16). Blizzard's bank frame must stay SHOWN while SwagBag
-- shows the bank: hiding it ends the bank visit, and its "active bank type" (where a
-- right-clicked bag item goes) only exists while it is shown. So SwagBag parents it to a
-- 1x1 frame at scale 0.001: still shown, but invisible. Blizzard's own tab buttons are
-- moved onto SwagBag's window, so a tab click still runs Blizzard's own code.
-- SwagBag changes only parents and anchors, and Restore puts every frame back exactly as
-- it was (parent and every anchor point). Parents change out of combat only: Shrink and
-- Rehost refuse in combat; Restore waits for combat to end (spec 13.2 item 5).
--   local host = SB.TinyHost.New(label, window)
--   host.Shrink(frame) -> true | false     keep frame shown but invisible
--   host.Rehost(frame, onto, place) -> true | false   move frame onto `onto`, place(frame) anchors it
--   host.Restore() -> true (done now) | false (waits for combat to end)
--   host.Keep()    cancel a Restore that is still waiting for combat to end (moves nothing)
--   host.IsActive() -> true while anything is moved
local _, SB = ...

local TinyHost = {}
SB.TinyHost = TinyHost

local tinyParent

-- The shared invisible parent (a plain frame, created on first use).
function TinyHost.Parent()
	if not tinyParent then
		tinyParent = CreateFrame("Frame", nil, UIParent)
		tinyParent:SetSize(1, 1)
		tinyParent:SetScale(0.001)
		tinyParent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	end
	return tinyParent
end

local function savePoints(f)
	local points = {}
	for i = 1, f:GetNumPoints() or 0 do
		local point, relativeTo, relativePoint, x, y = f:GetPoint(i)
		points[i] = { point, relativeTo, relativePoint, x, y }
	end
	return points
end

local function restorePoints(f, points)
	f:ClearAllPoints()
	for _, p in ipairs(points) do
		f:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
end

-- label names the restore job (one per host); window is the ErrorTrap window.
function TinyHost.New(label, window)
	local h = { entries = {}, byFrame = {}, gen = 0 }

	-- Remember where a frame lives, once (a second move must not save SwagBag's own parent).
	local function remember(frame)
		if not h.byFrame[frame] then
			local e = { frame = frame, parent = frame:GetParent(), points = savePoints(frame) }
			h.entries[#h.entries + 1] = e
			h.byFrame[frame] = e
		end
	end

	function h.Shrink(frame)
		if not frame or SB.Adapter.InCombat() then
			return false
		end
		remember(frame)
		if frame:GetParent() ~= TinyHost.Parent() then
			frame:SetParent(TinyHost.Parent())
		end
		return true
	end

	function h.Rehost(frame, onto, place)
		if not frame or SB.Adapter.InCombat() then
			return false
		end
		remember(frame)
		frame:SetParent(onto)
		frame:ClearAllPoints()
		place(frame)
		return true
	end

	function h.IsActive()
		return #h.entries > 0
	end

	-- A bank closed and reopened inside one fight must stay tiny (ruling W3-1): Keep() makes
	-- the Restore queued at the close do nothing when combat ends.
	function h.Keep()
		h.gen = h.gen + 1
	end

	function h.Restore()
		local gen = h.gen
		return SB.OutOfCombat(function()
			if gen ~= h.gen then
				return
			end
			for i = #h.entries, 1, -1 do
				local e = h.entries[i]
				e.frame:SetParent(e.parent)
				restorePoints(e.frame, e.points)
				h.entries[i] = nil
				h.byFrame[e.frame] = nil
			end
		end, "tinyHost.restore." .. label, window)
	end

	return h
end
