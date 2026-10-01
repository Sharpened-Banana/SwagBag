-- SwagBag Items: one "item record" per occupied slot. The record is the ONLY
-- input the query engine sees (Engine/Keywords.lua reads these fields).
--
-- Items.Describe(bag, slot) -> record, or nil + "empty"
-- record = {
--   bag, slot, itemID, link, count, icon,
--   name            string | nil (nil while the item is still loading)
--   quality         number 0-8 | nil
--   classID, subclassID, equipLoc ("" when not equippable)
--   ilvl            number | nil (nil while loading)
--   reqLevel, maxStack                  number | nil (nil while loading)
--   bind            "none"|"pickup"|"equip"|"use"|"quest"|"account"|"warbound"|"wue" | nil
--   isCraftingReagent boolean | nil (nil while loading)
--   isBound, isWUE, isLocked, onCooldown, inEquipmentSet, hasUpgradeTrack,
--   isUsable, isToy, isQuestItem, isKeystone, isCagedPet, isNew    booleans
--   location        "backpack"|"bags"|"reagentbag"|"bank"|"warband"
--   tab             bank tab number (1-based) | nil
--   pending         true while C_Item has not loaded the item's data
-- }
local _, SB = ...

local Items = {}
SB.Items = Items

function Items.Describe(bag, slot)
	local A = SB.Adapter
	local s = A.GetSlot(bag, slot)
	if not s then
		return nil, "empty"
	end
	local inst = A.GetItemInstant(s.itemID) or {}
	local info = A.GetItemInfo(s.itemID)
	local location, tab = A.BagKind(bag)
	local link = s.link or ""
	local inv = SB.Inventory
	local r = {
		bag = bag,
		slot = slot,
		itemID = s.itemID,
		link = s.link,
		count = s.count or 1,
		icon = s.icon,
		name = s.name,
		quality = s.quality,
		classID = inst.classID,
		subclassID = inst.subclassID,
		equipLoc = inst.equipLoc or "",
		isBound = s.isBound == true,
		isLocked = s.isLocked == true,
		isWUE = A.IsWarboundUntilEquip(bag, slot),
		onCooldown = A.IsOnCooldown(bag, slot),
		inEquipmentSet = A.InEquipmentSet(bag, slot),
		hasUpgradeTrack = A.HasUpgradeTrack(bag, slot),
		isUsable = A.IsUsable(s.itemID),
		isToy = A.IsToy(s.itemID),
		isQuestItem = A.IsQuestItem(bag, slot) or inst.classID == A.ITEM_CLASS.Questitem,
		isKeystone = link:find("keystone:", 1, true) ~= nil,
		isCagedPet = link:find("battlepet:", 1, true) ~= nil,
		isNew = inv ~= nil and inv.IsNew(bag, slot) or false,
		location = location,
		tab = tab,
		pending = info == nil,
	}
	if info then
		r.name = r.name or info.name
		if r.quality == nil then
			r.quality = info.quality
		end
		r.reqLevel = info.reqLevel
		r.maxStack = info.maxStack
		r.bind = info.bind
		r.isCraftingReagent = info.isCraftingReagent
		r.ilvl = A.GetIlvl(bag, slot) or info.baseIlvl
	else
		r.name = nil
		A.RequestLoad(s.itemID)
		if inv then
			inv.MarkPending(s.itemID)
		end
	end
	return r
end

-- Memo key for a record by cache class (spec 7.8):
--   static -> itemID; instance -> full link + bound suffix; volatile -> nil (never memoized)
function Items.Key(record, class)
	if class == "static" then
		return record.itemID
	elseif class == "instance" then
		return (record.link or tostring(record.itemID)) .. (record.isBound and "#b" or "#u")
	end
	return nil
end
