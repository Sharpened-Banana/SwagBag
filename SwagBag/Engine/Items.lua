-- SwagBag Items: one "item record" per occupied slot. The record is the ONLY
-- input the query engine sees (Engine/Keywords.lua reads these fields).
--
-- Items.Describe(bag, slot[, s]) -> record, or nil + "empty". s: the slot as the caller already read
--   it with Adapter.GetSlot (false: read as empty), so the slot is not read twice (week 6, D20)
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
--   location        "backpack"|"bags"|"reagentbag"|"bank"|"warband"|"guild"
--   tab             bank tab number (1-based) | nil
--   track           { track, level, max } upgrade track | nil (overlays)
--   hasNoValue      boolean: a vendor pays nothing for it
--   pending         true while the item's data has not loaded
-- }
local _, SB = ...

local Items = {}
SB.Items = Items

function Items.Describe(bag, slot, s)
	local A = SB.Adapter
	if s == nil then
		s = A.GetSlot(bag, slot)
	end
	if not s then
		return nil, "empty"
	end
	local inst = A.GetItemInstant(s.itemID) or {}
	local info = A.GetItemInfo(s.itemID)
	local location, tab = A.BagKind(bag)
	local link = s.link or ""
	local track, hasTrack = A.UpgradeInfo(s.link)
	local inv = SB.Inventory
	local r = {
		bag = bag,
		slot = slot,
		itemID = s.itemID,
		link = s.link,
		count = s.count or 1,
		icon = s.icon,
		name = s.name,
		quality = s.quality, -- may be set while pending (from slot)
		classID = inst.classID,
		subclassID = inst.subclassID,
		equipLoc = inst.equipLoc or "",
		isBound = s.isBound == true,
		isLocked = s.isLocked == true,
		isWUE = A.IsWarboundUntilEquip(bag, slot),
		onCooldown = A.IsOnCooldown(bag, slot),
		inEquipmentSet = A.InEquipmentSet(bag, slot),
		hasUpgradeTrack = hasTrack,
		track = track,
		hasNoValue = s.hasNoValue == true,
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

-- A record for an item that is not in a container slot (a guild bank slot), built from its
-- link: info = Adapter.GuildSlot result { itemID, link, count, icon, quality, isLocked }.
-- bag is the caller's slot key (guild tab N uses bag 100 + N); location is "guild" unless given
-- (the alt viewer passes "backpack", "bags", "reagentbag", "bank" or "warband" for saved items, so location keywords
-- search them). Such items are never on cooldown and never new. A guild bank item is never bound.
-- A saved item elsewhere (ruling W5-10) may have been bound since it was saved: a bind-on-equip
-- item's bind is unknown (bind = nil, bindUnknown = true: no BoE badge, no bind keyword matches)
-- and it is priced as bound, at its vendor value (Prices.Bound).
function Items.DescribeLink(info, bag, slot, tab, location)
	local A = SB.Adapter
	local inst = A.GetItemInstant(info.itemID) or {}
	local data = A.GetItemInfo(info.itemID)
	local link = info.link or ""
	local track, hasTrack = A.UpgradeInfo(info.link)
	local r = {
		bag = bag,
		slot = slot,
		itemID = info.itemID,
		link = info.link,
		count = info.count or 1,
		icon = info.icon,
		quality = info.quality,
		classID = inst.classID,
		subclassID = inst.subclassID,
		equipLoc = inst.equipLoc or "",
		isBound = false,
		isLocked = info.isLocked == true,
		isWUE = false,
		onCooldown = false,
		inEquipmentSet = false,
		hasUpgradeTrack = hasTrack == true,
		track = track,
		hasNoValue = false,
		isUsable = A.IsUsable(info.itemID),
		isToy = A.IsToy(info.itemID),
		isQuestItem = inst.classID == A.ITEM_CLASS.Questitem,
		isKeystone = link:find("keystone:", 1, true) ~= nil,
		isCagedPet = link:find("battlepet:", 1, true) ~= nil,
		isNew = false,
		location = location or "guild",
		tab = tab,
		pending = data == nil,
	}
	if data then
		r.name = data.name
		if r.quality == nil then
			r.quality = data.quality
		end
		r.reqLevel = data.reqLevel
		r.maxStack = data.maxStack
		r.bind = data.bind
		if r.bind == "equip" and location ~= nil and location ~= "guild" then
			r.bind, r.bindUnknown = nil, true
		elseif location ~= nil and location ~= "guild" then
			-- static binds of a saved item (W5-11): bound now, as in the live bags (Prices.Bound)
			if r.bind == "pickup" or r.bind == "account" or r.bind == "warbound" then
				r.isBound = true
			elseif r.bind == "wue" then
				r.isWUE = true
			end
		end
		r.isCraftingReagent = data.isCraftingReagent
		r.ilvl = A.GetLinkIlvl(info.link) or data.baseIlvl
	else
		A.RequestLoad(info.itemID)
	end
	return r
end

-- Re-read the facts that change without a bag update: cooldown, usability, "new".
-- Three cheap lookups, no item-info calls. Returns the same record.
function Items.RefreshVolatile(record)
	local A = SB.Adapter
	record.onCooldown = A.IsOnCooldown(record.bag, record.slot)
	record.isUsable = A.IsUsable(record.itemID)
	local inv = SB.Inventory
	record.isNew = inv ~= nil and inv.IsNew(record.bag, record.slot) or false
	return record
end

-- Memo key for a record by cache class (spec 7.8):
--   static -> itemID; instance -> full link + bound/WuE suffix (#b, #uw, #u, #? bind unknown); volatile -> nil
function Items.Key(record, class)
	if class == "static" then
		return record.itemID
	elseif class == "instance" then
		-- #? a saved item whose bind is unknown (W5-10): never shares a memo with the same link known unbound
		return (record.link or tostring(record.itemID))
			.. (record.isBound and "#b" or (record.isWUE and "#uw" or (record.bindUnknown and "#?" or "#u")))
	end
	return nil
end
