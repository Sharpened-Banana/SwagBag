-- SwagBag overlay data (spec F9: AC9.1, AC9.3). Pure: an item record in, what to draw on its
-- button out. UI/Overlays.lua draws it and applies the per-overlay settings. Everything
-- comes from the record (Items.lua: real APIs, no tooltip reading).
--   OverlayData.For(record, ctx) -> {
--     ilvl      number | nil    equippable gear only
--     track     "H3/6" | nil    upgrade track initial, level / max
--     keystone  { level, dungeon } | nil   from the keystone link; dungeon = short name
--     junk      boolean         poor quality and a vendor pays for it
--     bind      "BoE" | "WuE" | nil   bind on equip / warbound until equipped, not yet bound
--     upgrade   boolean         the arrow (AC9.3, see IsUpgrade) }
--   ctx = { equipped = { [invSlot] = { ilvl, equipLoc } }, canUse = fn(itemID) -> bool,
--           dungeonName = fn(mapID) -> name | nil, pawn = fn(record) -> true | false | nil }
--   OverlayData.IsUpgrade(record, equipped, canUse) -> boolean
--   OverlayData.Short(name) -> short dungeon name ("Darkflame Cleft" -> "DC")
local _, SB = ...

local O = {}
SB.OverlayData = O

-- Equip location -> the inventory slots it can go in (spec AC9.3 "matching slot(s)").
O.SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_RANGED = { 16 },
	INVTYPE_RANGEDRIGHT = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
}
local TWO_HAND = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local ONE_HAND_WEAPON = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }
local MAIN, OFF = 16, 17

local function ilvlAt(equipped, slot)
	local e = equipped[slot]
	return e and e.ilvl or 0
end

-- AC9.3: higher than the lowest-ilvl item equipped in the matching slot(s); an empty slot
-- counts as 0. Rings and trinkets compare with both slots. A two-hander replaces the main and
-- off hand, so it compares by summed item level (2 x its level against both). A one-hander
-- also compares with the off hand when the off hand holds a one-hand weapon (dual wield).
-- An off-hand item never beats a two-hander (it would leave the main hand empty).
function O.IsUpgrade(record, equipped, canUse)
	local A = SB.Adapter
	local ilvl = record.ilvl
	local slots = O.SLOTS[record.equipLoc or ""]
	if not slots or record.pending or type(ilvl) ~= "number" then
		return false
	end
	if record.classID ~= A.ITEM_CLASS.Armor and record.classID ~= A.ITEM_CLASS.Weapon then
		return false
	end
	if canUse and not canUse(record.itemID) then
		return false
	end
	local main, off = equipped[MAIN], equipped[OFF]
	local mainIsTwoHand = main and TWO_HAND[main.equipLoc] or false
	if TWO_HAND[record.equipLoc] then
		if off then
			return ilvl * 2 > ilvlAt(equipped, MAIN) + ilvlAt(equipped, OFF)
		end
		return ilvl > ilvlAt(equipped, MAIN)
	end
	if slots[1] == OFF then
		if mainIsTwoHand then
			return false
		end
		return ilvl > ilvlAt(equipped, OFF)
	end
	local lowest = math.huge
	for _, slot in ipairs(slots) do
		lowest = math.min(lowest, ilvlAt(equipped, slot))
	end
	if record.equipLoc == "INVTYPE_WEAPON" and off and ONE_HAND_WEAPON[off.equipLoc] then
		lowest = math.min(lowest, ilvlAt(equipped, OFF))
	end
	return ilvl > lowest
end

local SMALL = { ["of"] = true, ["the"] = true, ["and"] = true }

-- Initials of the meaningful words (up to 4), or the first 3 letters of a one-word name.
function O.Short(name)
	if type(name) ~= "string" then
		return nil
	end
	local words = {}
	for w in name:gmatch("[^%s%-,:']+") do
		if not SMALL[w:lower()] then
			words[#words + 1] = w
		end
	end
	if #words == 0 then
		return nil
	elseif #words == 1 then
		return words[1]:sub(1, 3)
	end
	local out = {}
	for i = 1, math.min(4, #words) do
		out[i] = words[i]:sub(1, 1):upper()
	end
	return table.concat(out)
end

local function isGear(r)
	local C = SB.Adapter.ITEM_CLASS
	return r.classID == C.Armor or r.classID == C.Weapon
end

function O.For(record, ctx)
	local out = { junk = false, upgrade = false }
	if not record then
		return out
	end
	ctx = ctx or {}
	local L = SB.L
	if isGear(record) and O.SLOTS[record.equipLoc or ""] and type(record.ilvl) == "number" then
		out.ilvl = record.ilvl
	end
	local t = record.track
	if t and t.track and t.level and t.max then
		out.track = L.OVERLAY_TRACK:format(t.track:sub(1, 1), t.level, t.max)
	end
	if record.isKeystone and record.link then
		local mapID, level = record.link:match("keystone:%d+:(%d+):(%d+)")
		if level then
			local name = ctx.dungeonName and ctx.dungeonName(tonumber(mapID))
			out.keystone = { level = tonumber(level), dungeon = O.Short(name) }
		end
	end
	out.junk = record.quality == 0 and not record.hasNoValue
	if not record.isBound then
		if record.isWUE then
			out.bind = L.BADGE_WUE
		elseif record.bind == "equip" then
			out.bind = L.BADGE_BOE
		end
	end
	local verdict = ctx.pawn and ctx.pawn(record)
	if verdict ~= nil then
		out.upgrade = verdict and true or false
	else
		out.upgrade = O.IsUpgrade(record, ctx.equipped or {}, ctx.canUse)
	end
	return out
end
