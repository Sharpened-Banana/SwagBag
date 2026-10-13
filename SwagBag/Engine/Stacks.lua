-- SwagBag stack grouping (0.14.0). Pure Lua: no frames, no WoW calls, no Config at load.
-- Several stacks of one item can show as ONE icon with the total. This is display only: nothing here
-- moves, splits or merges an item, and the real stacks stay where they are.
--   Stacks.Key(record) -> string | nil     what makes two stacks "the same item" (nil: never groups)
--   Stacks.Totals(slots, keyOf) -> { [key] = count }
--   Stacks.CountText(n) -> string          the total as it is drawn on the icon
--   Stacks.Line(counts) -> string          the tooltip line: "3 stacks: 45 + 7 + 2"
--   Stacks.Of(entry, recordOf) -> { total, counts } | nil
--   Stacks.Enabled() -> bool               the bags.stacks setting
--   Stacks.Paint(entries, prev, recordOf, buttonOf, setStack, paintRow) -> now   a window's repaint of its
--                                           groups (the bags window and GroupView); pure, through callbacks
--   Stacks.Relight(entries, buttonOf, isDimmed, light)   after a search: a grouped icon stays lit while a
--                                           hidden stack matches
local _, SB = ...

local L = SB.L
local Stacks = { MAX_LISTED = 6 }
SB.Stacks = Stacks

-- The item string: the |Hitem:...|h part of a link, or the link itself when it is one already.
local function itemString(link)
	if link:sub(1, 5) == "item:" then
		return link
	end
	return link:match("|H(item:[^|]+)|h")
end

-- Blank two fields that describe the viewer, not the item: linkLevel and specializationID.
-- item:itemID:enchant:gem1:gem2:gem3:gem4:suffixID:uniqueID:linkLevel:specializationID:...
-- Counting "item" as field 1, they are fields 10 and 11 (ruling S1: by position in this layout).
local LINK_LEVEL, SPEC_ID = 10, 11
local function normalise(str)
	local fields, pos = {}, 1
	while true do
		local at = str:find(":", pos, true)
		if not at then
			fields[#fields + 1] = str:sub(pos)
			break
		end
		fields[#fields + 1] = str:sub(pos, at - 1)
		pos = at + 1
	end
	if fields[LINK_LEVEL] then
		fields[LINK_LEVEL] = ""
	end
	if fields[SPEC_ID] then
		fields[SPEC_ID] = ""
	end
	return table.concat(fields, ":")
end

function Stacks.Key(record)
	if record.pending or (record.maxStack or 0) <= 1 or record.isKeystone or record.isCagedPet then
		return nil
	end
	local A = SB.Adapter
	if A.IsSecret(record.link) or A.IsSecret(record.itemID) then
		return nil
	end
	local str = record.link and itemString(record.link) or tostring(record.itemID)
	if not str then
		return nil
	end
	return normalise(str) .. SB.Items.BindSuffix(record)
end

-- keyOf(slot) returns a key or nil; slots may be nil (holes).
function Stacks.Totals(slots, keyOf)
	local totals = {}
	for _, s in pairs(slots) do
		local key = keyOf(s)
		if key then
			totals[key] = (totals[key] or 0) + (s.record and s.record.count or 0)
		end
	end
	return totals
end

function Stacks.CountText(n)
	if n <= 9999 then
		return tostring(n)
	end
	return math.floor(n / 1000) .. "k"
end

function Stacks.Line(counts)
	local shown = {}
	if #counts > Stacks.MAX_LISTED then
		for i = 1, Stacks.MAX_LISTED - 1 do
			shown[i] = tostring(counts[i])
		end
		shown[#shown + 1] = L.STACKS_TIP_MORE:format(#counts - (Stacks.MAX_LISTED - 1))
	else
		for i, n in ipairs(counts) do
			shown[i] = tostring(n)
		end
	end
	return L.STACKS_TIP:format(#counts, table.concat(shown, " + "))
end

-- entry: a pos.stacks entry { bag, slot, members = { { bag, slot } } }; recordOf(bag, slot) -> record | nil.
function Stacks.Of(entry, recordOf)
	local first = recordOf(entry.bag, entry.slot)
	if not first then
		return nil
	end
	local counts, total = { first.count }, first.count
	for _, m in ipairs(entry.members) do
		local r = recordOf(m.bag, m.slot)
		if r then
			counts[#counts + 1] = r.count
			total = total + r.count
		end
	end
	if #counts < 2 then
		return nil
	end
	return { total = total, counts = counts }
end

-- entries: pos.stacks (nil: none); prev: [button] = entry, what the last call returned. Each shown group's
-- icon gets setStack(button, { total, counts }) and paintRow(button, entry, total); each button in prev no
-- longer grouped gets setStack(button, nil) and paintRow(button, entry, nil). paintRow is optional (a list's
-- row). Returns the new [button] = entry set. O(groups); nothing moves.
function Stacks.Paint(entries, prev, recordOf, buttonOf, setStack, paintRow)
	local now = {}
	for _, e in ipairs(entries or {}) do
		local s = e.shown and Stacks.Of(e, recordOf)
		local button = s and buttonOf(e.bag, e.slot)
		if button then
			setStack(button, s)
			now[button] = e
			if paintRow then
				paintRow(button, e, s.total)
			end
		end
	end
	for button, e in pairs(prev) do
		if not now[button] then
			setStack(button, nil)
			if paintRow then
				paintRow(button, e, nil)
			end
		end
	end
	return now
end

-- A shown icon the search dimmed is lit again (light(button)) while any of its hidden stacks' buttons is
-- not dimmed (`count<10` finds the 7 under the 45's icon).
function Stacks.Relight(entries, buttonOf, isDimmed, light)
	for _, e in ipairs(entries or {}) do
		local rep = e.shown and buttonOf(e.bag, e.slot)
		if rep and isDimmed(rep) then
			for _, m in ipairs(e.members) do
				local member = buttonOf(m.bag, m.slot)
				if member and not isDimmed(member) then
					light(rep)
					break
				end
			end
		end
	end
end

function Stacks.Enabled()
	return SB.Config.Get("bags.stacks") == "one"
end
