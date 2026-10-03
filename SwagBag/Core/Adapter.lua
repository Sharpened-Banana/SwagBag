-- SwagBag Adapter: the ONLY file allowed to name C_* namespaces or Enum
-- (scripts/check.sh fails the build otherwise). Everything else calls SB.Adapter.*.
-- Load-time code here must stay safe outside WoW: tests load this file and then
-- replace the WoW-calling functions with fakes (spec/mock_adapter.lua).
local _, SB = ...

local A = {}
SB.Adapter = A

local function isSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
A.IsSecret = isSecret

---------------------------------------------------------------------------
-- Basics: chat, clock, timers, combat, diagnostics
---------------------------------------------------------------------------
function A.ChatPrint(text)
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

function A.Now()
	return GetTime()
end

function A.ProfileMs()
	return debugprofilestop()
end

function A.After(seconds, fn)
	C_Timer.After(seconds, fn)
end

function A.InCombat()
	return InCombatLockdown() == true
end

function A.Stack()
	return debugstack(3, 8, 0) or ""
end

function A.Date(fmt)
	return date(fmt)
end

-- Seconds since the epoch (snapshot stamps).
function A.Time()
	return time()
end

-- "Name-Realm" of the logged-in character (the snapshot key, spec 8.2).
function A.CharKey()
	return tostring(UnitName("player")) .. "-" .. tostring(GetRealmName())
end

function A.CharInfo()
	local _, class = UnitClass("player")
	return { class = class, level = UnitLevel("player") }
end

function A.BuildInfo()
	local version, build, _, toc = GetBuildInfo()
	return { version = version, build = build, toc = toc, locale = GetLocale() }
end

-- Resolve a dotted path such as "C_Container.SortBags" without erroring.
function A.Resolve(path)
	local cur = _G
	for part in path:gmatch("[^%.]+") do
		if type(cur) ~= "table" then
			return nil
		end
		local ok, nxt = pcall(function()
			return cur[part]
		end)
		if not ok or nxt == nil then
			return nil
		end
		cur = nxt
	end
	return cur
end

-- Returns loaded (boolean), version (string or nil) for another addon.
function A.AddOnState(name)
	if not (C_AddOns and C_AddOns.IsAddOnLoaded) then
		return false, nil
	end
	local loaded = C_AddOns.IsAddOnLoaded(name) == true
	local version = C_AddOns.GetAddOnMetadata(name, "Version")
	return loaded, version
end

---------------------------------------------------------------------------
-- Containers and items
---------------------------------------------------------------------------
A.BAG_CAPACITY = 38 -- buttons pre-created per bag (largest bag size)
A.BANK_TAB_CAPACITY = 98 -- buttons pre-created per purchased bank tab

-- Item class / subclass IDs. Numbers are the 12.1 values; Enum overrides them
-- when present so a renumbering patch is picked up automatically.
A.ITEM_CLASS = {
	Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5,
	Tradegoods = 7, Recipe = 9, Questitem = 12, Key = 13, Miscellaneous = 15,
	Battlepet = 17, Profession = 19, Housing = 20,
}
A.CONSUMABLE_SUB = { Potion = 1, Elixir = 2, Flask = 3, FoodDrink = 5, VantusRune = 9 }
A.TRADEGOODS_SUB = { Cloth = 5, Leather = 6, MetalStone = 7, Cooking = 8, Herb = 9, Enchanting = 12 }
A.MISC_SUB = { Junk = 0, CompanionPet = 2, Mount = 5 }
A.ARMOR_SUB = { Cosmetic = 5 }

local function overrideFromEnum(target, enumTable)
	if type(enumTable) ~= "table" then
		return
	end
	for name in pairs(target) do
		if type(enumTable[name]) == "number" then
			target[name] = enumTable[name]
		end
	end
end
if Enum then
	overrideFromEnum(A.ITEM_CLASS, Enum.ItemClass)
	overrideFromEnum(A.CONSUMABLE_SUB, Enum.ItemConsumableSubclass)
	overrideFromEnum(A.TRADEGOODS_SUB, Enum.ItemTradegoodsSubclass)
	overrideFromEnum(A.MISC_SUB, Enum.ItemMiscellaneousSubclass)
	overrideFromEnum(A.ARMOR_SUB, Enum.ItemArmorSubclass)
end

-- Bind type number -> SwagBag bind kind. Names come from Enum.ItemBind when present.
local BIND_BY_ENUM_NAME = {
	None = "none", OnAcquire = "pickup", OnEquip = "equip", OnUse = "use", Quest = "quest",
	ToWoWAccount = "account", ToBnetAccount = "warbound", ToBnetAccountUntilEquipped = "wue",
}
local BIND_FALLBACK = { [0] = "none", [1] = "pickup", [2] = "equip", [3] = "use", [4] = "quest",
	[7] = "account", [8] = "warbound", [9] = "wue" }
local bindMap

function A.BindKind(bindType)
	if bindType == nil then
		return nil
	end
	if not bindMap then
		bindMap = {}
		for k, v in pairs(BIND_FALLBACK) do
			bindMap[k] = v
		end
		local enum = Enum and Enum.ItemBind
		if type(enum) == "table" then
			for name, value in pairs(enum) do
				if BIND_BY_ENUM_NAME[name] then
					bindMap[value] = BIND_BY_ENUM_NAME[name]
				end
			end
		end
	end
	return bindMap[bindType] or "none"
end

-- Bag ID ranges from Enum.BagIndex (verified 12.1): 0 backpack, 1-4 bags,
-- 5 reagent bag, 6-11 character bank tabs, 12-16 warband bank tabs.
-- Returns location kind and, for bank tabs, the tab number (1-based).
function A.BagKind(bag)
	if bag == 0 then
		return "backpack", nil
	elseif bag >= 1 and bag <= 4 then
		return "bags", nil
	elseif bag == 5 then
		return "reagentbag", nil
	elseif bag >= 6 and bag <= 11 then
		return "bank", bag - 5
	elseif bag >= 12 and bag <= 16 then
		return "warband", bag - 11
	end
	return nil, nil
end

-- Which empty slots belong together (the free tile, plan D19): "reagent" for the reagent bag
-- (only reagents fit), "family<N>" for a bag whose GetContainerNumFreeSlots family N is not 0
-- (a profession bag: only its items fit), else "any". Feature-detected: "any" without the API.
function A.BagFamily(bag)
	if A.BagKind(bag) == "reagentbag" then
		return "reagent"
	end
	if C_Container and C_Container.GetContainerNumFreeSlots then
		local ok, _, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
		if ok and type(family) == "number" and not isSecret(family) and family ~= 0 then
			return "family" .. family
		end
	end
	return "any"
end

-- kind: "bags" | "bank" | "warband". Bank kinds return PURCHASED tab IDs only.
function A.GetBagIDs(kind)
	if kind == "bags" then
		return { 0, 1, 2, 3, 4, 5 }
	end
	local bt = Enum and Enum.BankType
	local bankType = bt and ((kind == "bank" and bt.Character) or (kind == "warband" and bt.Account))
	if bankType == nil or not (C_Bank and C_Bank.FetchPurchasedBankTabIDs) then
		return {}
	end
	local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
	local out = {}
	if ok and type(ids) == "table" then
		for i = 1, #ids do
			if not isSecret(ids[i]) then
				out[#out + 1] = ids[i]
			end
		end
	end
	return out
end

function A.NumSlots(bag)
	local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
	if ok and type(n) == "number" and not isSecret(n) then
		return n
	end
	return 0
end

-- Normalized slot record, or nil for an empty slot.
function A.GetSlot(bag, slot)
	local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
	if not ok or type(info) ~= "table" or info.itemID == nil or isSecret(info.itemID) then
		return nil
	end
	return {
		bag = bag,
		slot = slot,
		itemID = info.itemID,
		link = info.hyperlink,
		count = info.stackCount or 1,
		quality = info.quality,
		icon = info.iconFileID,
		isLocked = info.isLocked == true,
		isBound = info.isBound == true,
		name = info.itemName,
		hasNoValue = info.hasNoValue == true,
		hasLoot = info.hasLoot == true, -- a container to open (a cache, a lockbox): week 7, the "learn" glow
	}
end

-- Instant (always cached) item facts.
function A.GetItemInstant(item)
	local ok, itemID, _, _, equipLoc, icon, classID, subclassID = pcall(C_Item.GetItemInfoInstant, item)
	if not ok or not itemID then
		return nil
	end
	return { itemID = itemID, equipLoc = equipLoc or "", icon = icon, classID = classID, subclassID = subclassID }
end

-- Full item facts, or nil while the client has not loaded the item yet.
function A.GetItemInfo(item)
	local ok, name, _, quality, baseIlvl, reqLevel, _, _, maxStack, _, _, sellPrice, _, _, bindType,
		expansionID, _, isCraftingReagent = pcall(C_Item.GetItemInfo, item)
	if not ok or name == nil then
		return nil
	end
	return {
		name = name,
		quality = quality,
		baseIlvl = baseIlvl,
		reqLevel = reqLevel,
		maxStack = maxStack,
		sellPrice = sellPrice,
		bind = A.BindKind(bindType),
		expansionID = expansionID,
		isCraftingReagent = isCraftingReagent == true,
	}
end

local function location(bag, slot)
	return ItemLocation:CreateFromBagAndSlot(bag, slot)
end

function A.GetIlvl(bag, slot)
	local ok, v = pcall(function()
		return C_Item.GetCurrentItemLevel(location(bag, slot))
	end)
	if ok and type(v) == "number" and not isSecret(v) then
		return v
	end
	return nil
end

-- Item level of an item link (guild bank items have no bag slot), or nil.
function A.GetLinkIlvl(link)
	if type(link) ~= "string" or not (C_Item and C_Item.GetDetailedItemLevelInfo) then
		return nil
	end
	local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
	if ok and type(v) == "number" and not isSecret(v) then
		return v
	end
	return nil
end

function A.IsWarboundUntilEquip(bag, slot)
	if not (C_Item and C_Item.IsBoundToAccountUntilEquip) then
		return false
	end
	local ok, v = pcall(function()
		return C_Item.IsBoundToAccountUntilEquip(location(bag, slot))
	end)
	return ok and not isSecret(v) and v == true
end

-- Upgrade track of an item link: returns { track = "Hero", level = 3, max = 6 } or nil, then
-- hasTrack (true when the item has any upgrade track at all). One client call per item. Real API
-- only; no tooltip reading (spec P7). Missing API: nil, false.
function A.UpgradeInfo(link)
	if type(link) ~= "string" or not (C_Item and C_Item.GetItemUpgradeInfo) then
		return nil, false
	end
	local ok, info = pcall(C_Item.GetItemUpgradeInfo, link)
	if not ok or type(info) ~= "table" then
		return nil, false
	end
	local track, level, max = info.trackString, info.currentLevel, info.maxLevel or info.maxUpgradeLevel
	local hasTrack = (max or 0) > 0 or (type(track) == "string" and track ~= "")
	if type(track) ~= "string" or track == "" or isSecret(track) or type(level) ~= "number" or type(max) ~= "number" then
		return nil, hasTrack
	end
	return { track = track, level = level, max = max }, hasTrack
end

-- Name of a Mythic+ dungeon (keystone link map ID), or nil.
function A.DungeonName(mapID)
	if not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then
		return nil
	end
	local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
	if ok and type(name) == "string" and not isSecret(name) then
		return name
	end
	return nil
end

-- What the character wears: [inventory slot 1-17] = { ilvl, equipLoc } (nil = empty slot).
function A.EquippedItems()
	local out = {}
	for slot = 1, 17 do
		local okL, link = pcall(GetInventoryItemLink, "player", slot)
		if okL and type(link) == "string" and not isSecret(link) then
			local inst = A.GetItemInstant(link)
			local okI, ilvl = pcall(function()
				return C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot))
			end)
			local equipLoc = inst and inst.equipLoc or ""
			if okI and type(ilvl) == "number" and not isSecret(ilvl) then
				out[slot] = { ilvl = ilvl, equipLoc = equipLoc }
			else
				-- A worn item whose level cannot be read is "unknown", never 0 (an empty slot is absent).
				out[slot] = { ilvl = nil, unknown = true, equipLoc = equipLoc }
			end
		end
	end
	return out
end

-- True unless the client says this character cannot use the item (feature-detected).
function A.CanUse(itemID)
	if not (C_PlayerInfo and C_PlayerInfo.CanUseItem) then
		return true
	end
	local ok, yes = pcall(C_PlayerInfo.CanUseItem, itemID)
	return not ok or yes ~= false
end

-- Average item level of what the character wears (GetAverageItemLevel's second value), or
-- nil when the client lacks the function or gives no number (spec addition D18).
function A.EquippedItemLevel()
	local fn = _G.GetAverageItemLevel
	if type(fn) ~= "function" then
		return nil
	end
	local ok, _, equipped = pcall(fn)
	if not ok or type(equipped) ~= "number" or isSecret(equipped) then
		return nil
	end
	return equipped
end

-- Pawn (optional; ruling W4-15): ready once PawnIsReady() says so. Pawn 2.13 has no container API,
-- so the verdict comes from the item link. PawnShouldItemLinkHaveUpgradeArrow is never called
-- (Pawn throttles it with a budget).
function A.HasPawn()
	local ready = _G.PawnIsReady
	if type(ready) ~= "function" or type(_G.PawnIsItemDefinitivelyAnUpgrade) ~= "function" then
		return false
	end
	local ok, yes = pcall(ready)
	return ok and yes == true
end

-- Pawn's verdict for a bag or bank slot (spec AC9.3): true (an upgrade), false (not one), or nil
-- when Pawn is missing, not ready, the slot is empty, or Pawn has no opinion (the item-level rule
-- then decides; supersedes W3-16's nil -> false). checkLevel true: Pawn also checks the level.
function A.PawnUpgrade(bag, slot)
	if not A.HasPawn() then
		return nil
	end
	local s = A.GetSlot(bag, slot)
	local link = s and s.link
	if type(link) ~= "string" or isSecret(link) then
		return nil
	end
	local ok, yes = pcall(_G.PawnIsItemDefinitivelyAnUpgrade, link, true)
	if not ok or isSecret(yes) then
		return nil
	end
	if yes == true then
		return true
	elseif yes == false then
		return false
	end
	return nil
end

-- Blizzard's client-side "new item" flag (newglow-diagnosis.md): it drives the template's blue
-- glow and survives /reload. Blizzard's bags clear it per slot on hover and when they close;
-- SwagBag does the same through these. Per slot, never ClearAll. Nil-safe; errors are swallowed.
function A.ClearNewItem(bag, slot)
	local N = C_NewItems
	if N and N.RemoveNewItem then
		pcall(N.RemoveNewItem, bag, slot)
	end
end

function A.ClearNewItems(bagIDs)
	local N = C_NewItems
	if not (N and N.RemoveNewItem) then
		return
	end
	for _, bag in ipairs(bagIDs) do
		for slot = 1, A.NumSlots(bag) do
			pcall(N.RemoveNewItem, bag, slot)
		end
	end
end

---------------------------------------------------------------------------
-- Money and currencies (the bags footer, UI/Footer.lua; ruling W4-14)
---------------------------------------------------------------------------
-- The character's gold in copper, or nil when the client gives no readable number (missing,
-- failed or secret): the footer then keeps the last known amount, never a false 0.
function A.Money()
	local fn = _G.GetMoney
	if type(fn) ~= "function" then
		return nil
	end
	local ok, copper = pcall(fn)
	if ok and type(copper) == "number" and not isSecret(copper) then
		return copper
	end
	return nil
end

-- Gold as the client writes it, with coin icons; plain "123g" without the client's functions.
function A.MoneyText(copper)
	local fn = _G.GetMoneyString
	if type(fn) == "function" then
		local ok, text = pcall(fn, copper, true)
		if ok and type(text) == "string" and not isSecret(text) then
			return text
		end
	end
	fn = _G.GetCoinTextureString
	if type(fn) == "function" then
		local ok, text = pcall(fn, copper)
		if ok and type(text) == "string" and not isSecret(text) then
			return text
		end
	end
	return SB.L.FOOTER_GOLD_PLAIN:format(math.floor(copper / 10000))
end

local function currencyEntry(id, info)
	if type(info) ~= "table" or type(id) ~= "number" or isSecret(id) or type(info.quantity) ~= "number"
		or isSecret(info.quantity) or isSecret(info.name) then -- a secret name: the entry is skipped (M3)
		return nil
	end
	return { id = id, name = info.name, quantity = info.quantity, icon = info.iconFileID, max = info.maxQuantity }
end

-- The currencies ticked "Show on backpack" in Blizzard's Currency tab, in Blizzard's order:
-- { { id, name, quantity, icon, max } }. Empty without the API.
A.MAX_BACKPACK_CURRENCIES = 10
function A.BackpackCurrencies()
	local C, out = C_CurrencyInfo, {}
	if not (C and C.GetBackpackCurrencyInfo) then
		return out
	end
	for i = 1, A.MAX_BACKPACK_CURRENCIES do
		local ok, info = pcall(C.GetBackpackCurrencyInfo, i)
		if not ok or type(info) ~= "table" then
			break
		end
		out[#out + 1] = currencyEntry(info.currencyTypesID, info)
	end
	return out
end

-- One currency by ID, or nil.
function A.CurrencyInfo(id)
	local C = C_CurrencyInfo
	if not (C and C.GetCurrencyInfo) then
		return nil
	end
	local ok, info = pcall(C.GetCurrencyInfo, id)
	return ok and currencyEntry(id, info) or nil
end

-- Every currency in the Currency tab's list that is not a header, as the list shows it (a header
-- the user collapsed hides its currencies; confirmed IDs in Engine/Crests.lua do not depend on it).
function A.CurrencyList()
	local C, out = C_CurrencyInfo, {}
	if not (C and C.GetCurrencyListSize and C.GetCurrencyListInfo and C.GetCurrencyListLink
		and C.GetCurrencyIDFromLink) then
		return out
	end
	local okN, n = pcall(C.GetCurrencyListSize)
	if not okN or type(n) ~= "number" or isSecret(n) then
		return out
	end
	for i = 1, n do
		local ok, info = pcall(C.GetCurrencyListInfo, i)
		-- a secret header flag counts as a header (skipped): its line cannot be told (week-4 deferred)
		if ok and type(info) == "table" and not isSecret(info.isHeader) and not info.isHeader then
			local okL, link = pcall(C.GetCurrencyListLink, i)
			local okI, id = false, nil
			if okL and type(link) == "string" then
				okI, id = pcall(C.GetCurrencyIDFromLink, link)
			end
			out[#out + 1] = okI and currencyEntry(id, info) or nil
		end
	end
	return out
end

function A.IsOnCooldown(bag, slot)
	local ok, start, duration, enable = pcall(C_Container.GetContainerItemCooldown, bag, slot)
	if not ok or isSecret(start) or isSecret(duration) then
		return false
	end
	return enable ~= 0 and enable ~= false and (start or 0) > 0 and (duration or 0) > 1.5
end

function A.InEquipmentSet(bag, slot)
	local ok, isInSet = pcall(C_Container.GetContainerItemEquipmentSetInfo, bag, slot)
	return ok and isInSet == true
end

function A.IsUsable(itemID)
	local ok, usable = pcall(C_Item.IsUsableItem, itemID)
	return ok and usable == true
end

function A.IsToy(itemID)
	if not (C_ToyBox and C_ToyBox.GetToyInfo) then
		return false
	end
	local ok, toyID = pcall(C_ToyBox.GetToyInfo, itemID)
	return ok and toyID ~= nil
end

---------------------------------------------------------------------------
-- Collections (week 7, user picks 3 and 9): is this toy, mount, pet or decor item already the
-- account's? true = collected, false = not yet, nil = the client cannot say or the item is not that
-- kind (then no glow and no marker: never a wrong one). A secret answer is nil. Real APIs only (P7).
---------------------------------------------------------------------------
local function known(ok, v)
	if not ok or isSecret(v) or type(v) ~= "boolean" then
		return nil
	end
	return v
end

function A.ToyKnown(itemID)
	local fn = _G.PlayerHasToy
	if type(fn) ~= "function" then
		return nil
	end
	return known(pcall(fn, itemID))
end

function A.MountKnown(itemID)
	local J = C_MountJournal
	if not (J and J.GetMountFromItem and J.GetMountInfoByID) then
		return nil
	end
	local ok, mountID = pcall(J.GetMountFromItem, itemID)
	if not ok or type(mountID) ~= "number" or isSecret(mountID) then
		return nil -- not a mount item
	end
	return known(pcall(function()
		return (select(11, J.GetMountInfoByID(mountID))) -- isCollected
	end))
end

-- A caged pet's species is in its link (battlepet:<species>); a pet item asks the journal for it.
function A.PetKnown(itemID, link)
	local J = C_PetJournal
	if not (J and J.GetNumCollectedInfo) then
		return nil
	end
	local species = type(link) == "string" and not isSecret(link) and tonumber(link:match("battlepet:(%d+)")) or nil
	if not species and J.GetPetInfoByItemID then
		local ok, s = pcall(function()
			return (select(13, J.GetPetInfoByItemID(itemID))) -- speciesID
		end)
		species = ok and type(s) == "number" and not isSecret(s) and s or nil
	end
	if not species then
		return nil
	end
	local ok, n = pcall(J.GetNumCollectedInfo, species)
	if not ok or type(n) ~= "number" or isSecret(n) then
		return nil
	end
	return n > 0
end

-- Decor counts as collected once the account has one placed, in storage, or still to redeem.
function A.DecorKnown(itemID)
	local H = C_HousingCatalog
	if not (H and H.GetCatalogEntryInfoByItem) then
		return nil
	end
	local ok, info = pcall(H.GetCatalogEntryInfoByItem, itemID)
	if not ok or type(info) ~= "table" then
		return nil
	end
	local owned, seen = 0, false
	for _, field in ipairs({ "totalNumPlaced", "remainingRedeemable", "totalNumStored" }) do
		local v = info[field]
		if type(v) == "number" and not isSecret(v) then
			owned, seen = owned + v, true
		end
	end
	if not seen then
		return nil
	end
	return owned > 0
end

function A.IsQuestItem(bag, slot)
	local ok, info = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
	return ok and type(info) == "table" and (info.isQuestItem == true or info.questID ~= nil)
end

function A.RequestLoad(itemID)
	pcall(C_Item.RequestLoadItemDataByID, itemID)
end

---------------------------------------------------------------------------
-- Cursor and sorting (week 2: drag onto a section header, sort button)
---------------------------------------------------------------------------
-- itemID, link of the item on the cursor; nil when the cursor holds no item.
function A.CursorItem()
	if not GetCursorInfo then
		return nil
	end
	local ok, kind, itemID, link = pcall(GetCursorInfo)
	if ok and kind == "item" and type(itemID) == "number" and not isSecret(itemID) then
		return itemID, link
	end
	return nil
end

-- Puts a picked-up item back where it came from.
function A.ClearCursor()
	if ClearCursor then
		pcall(ClearCursor)
	end
end

-- Blizzard's own bag sort. Returns ok, err: ok is true if the call did not throw.
function A.SortBags()
	if not (C_Container and C_Container.SortBags) then
		return false
	end
	return pcall(C_Container.SortBags)
end

-- Blizzard's own bank sort for "bank" (character bank) or "warband" (spec 5.5). ok, err.
function A.SortBank(kind)
	local BT = Enum and Enum.BankType
	local bankType = BT and ((kind == "bank" and BT.Character) or (kind == "warband" and BT.Account))
	if bankType == nil or not (C_Container and C_Container.SortBank) then
		return false
	end
	return pcall(C_Container.SortBank, bankType)
end

---------------------------------------------------------------------------
-- Selling, repairing and moving items (week 7, user picks 4 and 6). C_Container.UseContainerItem is what
-- a right-click on a bag item runs: at an open vendor it sells the item, at an open bank it moves the
-- item into that bank. Addons call it out of combat (Baganator's transfers, EnhanceQoL's vendor and
-- warband bank; names read only); SwagBag calls it out of combat only (Engine/Mover.lua checks).
---------------------------------------------------------------------------
function A.SellItem(bag, slot)
	if not (C_Container and C_Container.UseContainerItem) then
		return false
	end
	return pcall(C_Container.UseContainerItem, bag, slot)
end

-- Move a bag item into the bank of that kind: "bank" (character) | "warband". The bank type is the
-- call's own argument (11.0+), so Blizzard's selected tab and bank type are neither read nor set.
function A.MoveToBank(bag, slot, kind)
	local BT = Enum and Enum.BankType
	local bankType = BT and ((kind == "bank" and BT.Character) or (kind == "warband" and BT.Account))
	if bankType == nil or not (C_Container and C_Container.UseContainerItem) then
		return false
	end
	return pcall(C_Container.UseContainerItem, bag, slot, nil, bankType, false)
end

-- A copper amount the client gives only when a yes/no question allows it (the repair cost, the guild's
-- repair money): nil without the API, on a "no", or on a secret.
local function copperIf(canName, amountName)
	local can, amount = _G[canName], _G[amountName]
	if type(can) ~= "function" or type(amount) ~= "function" then
		return nil
	end
	local okC, yes = pcall(can)
	if not okC or isSecret(yes) or not yes then
		return nil
	end
	local ok, copper = pcall(amount)
	if not ok or type(copper) ~= "number" or isSecret(copper) then
		return nil
	end
	return copper
end

-- What repairing everything costs at this vendor, in copper (0: nothing to repair); nil when this
-- vendor does not repair or the client cannot say.
function A.RepairCost()
	return copperIf("CanMerchantRepair", "GetRepairAllCost")
end

-- Repair everything; guild = true pays from the guild bank. true when the call went through.
function A.Repair(guild)
	local fn = _G.RepairAllItems
	if type(fn) ~= "function" then
		return false
	end
	return (pcall(fn, guild == true))
end

-- Copper the guild lets this character spend on repairs today (-1: no limit), or nil when it may not.
function A.GuildRepairMoney()
	return copperIf("CanGuildBankRepair", "GetGuildBankWithdrawMoney")
end

-- Copper in the guild bank (what the guild can actually pay), or nil when the client cannot say or it is secret.
function A.GuildBankMoney()
	local fn = _G.GetGuildBankMoney
	if type(fn) ~= "function" then
		return nil
	end
	local ok, copper = pcall(fn)
	if not ok or type(copper) ~= "number" or isSecret(copper) then
		return nil
	end
	return copper
end

---------------------------------------------------------------------------
-- Blizzard frames and the bank (week 3). SwagBag only READS Blizzard's bank state
-- (spec 5.2, 5.3): it never selects a tab or a bank type and never closes the bank.
---------------------------------------------------------------------------
-- A Blizzard frame by its global name (BankFrame, GuildBankFrame, ...), or nil.
function A.Frame(name)
	return _G[name]
end

-- One of Blizzard's font objects by its global name (GameFontHighlight, ...), or nil (themes).
function A.FontObject(name)
	local object = _G[name]
	return type(object) == "table" and object or nil
end

-- ElvUI's look, for the "Matches ElvUI" theme (UI/Themes.lua), or nil while ElvUI is not loaded.
-- Read only, from ElvUI's public globals: ElvUI[1] is its engine; engine.media.normFont (font
-- file), .blankTex (flat texture), .bordercolor, .backdropcolor, .backdropfadecolor (colours with
-- r, g, b, a, also at [1]..[4]); engine.db.general.fontSize. Read again on every theme change.
-- Returns { font, size, blank, border, backdrop, fade } (colours as { r, g, b, a }), or nil when
-- anything required is missing, of the wrong type or secret.
local function elvNumber(v)
	return type(v) == "number" and not isSecret(v)
end

local function elvColour(c, alpha)
	if type(c) ~= "table" or isSecret(c) then
		return nil
	end
	local r, g, b, a = c.r or c[1], c.g or c[2], c.b or c[3], c.a or c[4]
	if not (elvNumber(r) and elvNumber(g) and elvNumber(b)) then
		return nil
	end
	return { r, g, b, elvNumber(a) and a or alpha or 1 }
end

function A.ElvUIMedia()
	local ok, out = pcall(function()
		local elv = _G.ElvUI
		local engine = type(elv) == "table" and elv[1]
		local media = type(engine) == "table" and engine.media
		if type(media) ~= "table" then
			return nil
		end
		local font, blank = media.normFont, media.blankTex
		if type(font) ~= "string" or isSecret(font) or type(blank) ~= "string" or isSecret(blank) then
			return nil
		end
		local general = type(engine.db) == "table" and engine.db.general
		local size = type(general) == "table" and general.fontSize
		if not elvNumber(size) or size < 6 or size > 32 then
			size = 12
		end
		local border, backdrop = elvColour(media.bordercolor), elvColour(media.backdropcolor)
		local fade = elvColour(media.backdropfadecolor, 0.8)
		if not (border and backdrop and fade) then
			return nil
		end
		return { font = font, size = size, blank = blank, border = border, backdrop = backdrop, fade = fade }
	end)
	return ok and out or nil
end

-- "bank" (character bank) | "warband" | nil: the bank type Blizzard's bank frame has
-- selected, which is where a right-clicked bag item goes. Read only.
function A.ActiveBankType()
	local f = _G.BankFrame
	if not (f and f.GetActiveBankType) then
		return nil
	end
	local ok, bankType = pcall(f.GetActiveBankType, f)
	local BT = Enum and Enum.BankType
	if not ok or bankType == nil or isSecret(bankType) or not BT then
		return nil
	end
	if bankType == BT.Character then
		return "bank"
	elseif bankType == BT.Account then
		return "warband"
	end
	return nil
end

---------------------------------------------------------------------------
-- Deposit all warbound items (week 6, user request 3). C_Bank.AutoDepositItemsIntoBank is the call
-- Blizzard's own "Deposit All Warbound Items" button (BankPanel.AutoDepositFrame.DepositButton) makes;
-- here it is given the warband bank type explicitly, so Blizzard's selected bank type is never read
-- for it nor set. It is a C function: it writes no Lua field of Blizzard's frames, so it cannot taint
-- them the way calling the bank frame's own tab method did in the week-1 spike (that Lua method wrote
-- the frame's own state, which Blizzard's secure item click then read). Not protected: Baganator 833, TradeSkillMaster,
-- ElvUI, EllesmereUI and EnhanceQoL call it from addon code on Interface 120100 (names read only).
-- Blizzard's button asks before a deposit would end an item's refund; SwagBag checks first and
-- leaves those cases to Blizzard's button (RefundableForWarband).
---------------------------------------------------------------------------
local function warbandType()
	local BT = Enum and Enum.BankType
	return BT and BT.Account
end

-- true when the warband bank takes items now; otherwise false and why: "locked" (any
-- locked reason, for example another character of the account has it open) or "unavailable" (no API, no tab, not at a banker).
function A.WarbandDepositState()
	local account = warbandType()
	if account == nil or not (C_Bank and C_Bank.AutoDepositItemsIntoBank) then
		return false, "unavailable"
	end
	if C_Bank.FetchBankLockedReason then
		local ok, reason = pcall(C_Bank.FetchBankLockedReason, account)
		if not ok or isSecret(reason) then
			return false, "unavailable"
		elseif reason ~= nil then
			return false, "locked"
		end
	end
	if C_Bank.CanUseBank then
		local ok, can = pcall(C_Bank.CanUseBank, account)
		if not ok or isSecret(can) or can ~= true then
			return false, "unavailable"
		end
	end
	return true
end

-- true when an item in bags = { { bag, size } } that the warband bank would take can still be
-- refunded (the deposit would end that refund); false when none; nil when it cannot be told.
function A.RefundableForWarband(bags)
	local account = warbandType()
	if account == nil or not (C_Item and C_Item.CanBeRefunded and C_Item.DoesItemExist and C_Bank
		and C_Bank.IsItemAllowedInBankType) then
		return nil
	end
	local ok, found = pcall(function()
		for _, b in ipairs(bags) do
			for slot = 1, b.size do
				local loc = location(b.bag, slot)
				local exists = C_Item.DoesItemExist(loc)
				if isSecret(exists) then
					error("secret")
				end
				if exists then
					local allowed, refund = C_Bank.IsItemAllowedInBankType(account, loc), C_Item.CanBeRefunded(loc)
					if isSecret(allowed) or isSecret(refund) then
						error("secret")
					end
					if allowed and refund then
						return true
					end
				end
			end
		end
		return false
	end)
	if not ok then
		return nil
	end
	return found
end

-- Deposit every item the warband bank takes; reagents too when Blizzard's "Include reagents" box is
-- ticked (the game reads it). Returns true, or false and the error (nil when the API is missing).
function A.DepositWarband()
	local account = warbandType()
	if account == nil or not (C_Bank and C_Bank.AutoDepositItemsIntoBank) then
		return false
	end
	return pcall(C_Bank.AutoDepositItemsIntoBank, account)
end

-- Blizzard's "Include reagents" choice for that deposit: the bankAutoDepositReagents setting its own
-- check box reads and writes. true | false | nil (unknown).
function A.DepositReagents()
	if not (C_CVar and C_CVar.GetCVarBool) then
		return nil
	end
	local ok, on = pcall(C_CVar.GetCVarBool, "bankAutoDepositReagents")
	if not ok or isSecret(on) or type(on) ~= "boolean" then
		return nil
	end
	return on
end

-- Set that choice, as Blizzard's own check box does. Returns true when it took.
function A.SetDepositReagents(on)
	if not (C_CVar and C_CVar.SetCVar) then
		return false
	end
	local want = on and true or false
	if not pcall(C_CVar.SetCVar, "bankAutoDepositReagents", want and "1" or "0") then
		return false
	end
	return A.DepositReagents() == want
end

---------------------------------------------------------------------------
-- Guild bank (week 3, spec F16). Blizzard's guild bank functions are plain globals; the
-- guild bank UI (GuildBankFrame) is load-on-demand, so nothing here may assume it exists.
-- SwagBag never selects a guild bank tab: Blizzard's own tab buttons do (spec AC16.7).
---------------------------------------------------------------------------
A.GUILD_SLOTS = 98 -- slots per guild bank tab

-- { { tab, name, icon, viewable, canDeposit, withdrawals } } for each tab the guild owns.
-- withdrawals: stacks the player may still take from that tab today; -1 = unlimited.
function A.GuildTabs()
	if not (GetNumGuildBankTabs and GetGuildBankTabInfo) then
		return {}
	end
	local okN, n = pcall(GetNumGuildBankTabs)
	if not okN or type(n) ~= "number" or isSecret(n) then
		return {}
	end
	local out = {}
	for tab = 1, n do
		local ok, name, icon, viewable, canDeposit, _, remaining = pcall(GetGuildBankTabInfo, tab)
		if ok and not isSecret(name) then
			out[#out + 1] = { tab = tab, name = name, icon = icon, viewable = viewable == true,
				canDeposit = canDeposit == true,
				withdrawals = (type(remaining) == "number" and not isSecret(remaining)) and remaining or 0 }
		end
	end
	return out
end

-- Normalized guild slot { itemID, link, count, icon, quality, isLocked }, or nil when empty
-- (or not loaded yet: QueryGuildBankTab loads a tab).
function A.GuildSlot(tab, slot)
	local ok, icon, count, locked, _, quality = pcall(GetGuildBankItemInfo, tab, slot)
	if not ok or icon == nil or isSecret(icon) then
		return nil
	end
	local okL, link = pcall(GetGuildBankItemLink, tab, slot)
	if not okL or type(link) ~= "string" or isSecret(link) then
		return nil
	end
	local inst = A.GetItemInstant(link)
	if not inst then
		return nil
	end
	return { itemID = inst.itemID, link = link, count = count or 1, icon = icon, quality = quality,
		isLocked = locked == true }
end

function A.GuildQuery(tab)
	if QueryGuildBankTab then
		pcall(QueryGuildBankTab, tab)
	end
end

-- The tab Blizzard's guild bank has selected (where a right-clicked bag item goes). Read only.
function A.GuildCurrentTab()
	if not GetCurrentGuildBankTab then
		return nil
	end
	local ok, tab = pcall(GetCurrentGuildBankTab)
	if ok and type(tab) == "number" and not isSecret(tab) then
		return tab
	end
	return nil
end

-- Withdraw a stack to the bags (what a right-click does in Blizzard's guild bank).
function A.GuildWithdraw(tab, slot)
	return pcall(AutoStoreGuildBankItem, tab, slot)
end

-- Pick up the stack, or put the cursor's item into that slot (deposit or move).
function A.GuildPickup(tab, slot)
	return pcall(PickupGuildBankItem, tab, slot)
end

-- "Guild Name-Realm" for the player's guild, or nil without a guild.
function A.GuildKey()
	if not GetGuildInfo then
		return nil
	end
	local ok, name, _, _, realm = pcall(GetGuildInfo, "player")
	if not ok or type(name) ~= "string" or isSecret(name) then
		return nil
	end
	return name .. "-" .. tostring(realm or (GetRealmName and GetRealmName()) or "")
end

-- true / false when the client is certain whether the player is in a guild, nil when it can't say.
function A.IsInGuild()
	if not IsInGuild then
		return nil
	end
	local ok, yes = pcall(IsInGuild)
	if not ok or type(yes) ~= "boolean" then
		return nil
	end
	return yes
end

function A.GuildTooltip(owner, tab, slot)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetGuildBankItem, GameTooltip, tab, slot)
	GameTooltip:Show()
end

-- An item's tooltip from its link (the alt viewer's saved items).
function A.LinkTooltip(owner, link)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetHyperlink, GameTooltip, link)
	GameTooltip:Show()
end

function A.HideTooltip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

-- The tooltips that get count lines: the main tooltip and the item link (chat) tooltip. Never the
-- comparison tooltips (ShoppingTooltip1/2) or embedded ones (quest rewards), which the Item post-call
-- also fires for (F20).
local function countsTooltip(tooltip)
	return tooltip ~= nil and (tooltip == _G.GameTooltip or tooltip == _G.ItemRefTooltip)
end

-- Item tooltips the client fills (bags, bank, auction house, chat links): fn(tooltip, itemID) runs
-- after it, to add lines (the alt counts, UI/TooltipCounts.lua), for GameTooltip and ItemRefTooltip
-- only. Taint-free: through TooltipDataProcessor.AddTooltipPostCall for Enum.TooltipDataType.Item.
-- A secret or missing item ID is skipped. Returns true when hooked, else false (the caller says so).
function A.HookItemTooltip(fn)
	local TDP = _G.TooltipDataProcessor
	local kind = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
	if type(TDP) == "table" and type(TDP.AddTooltipPostCall) == "function" and kind ~= nil then
		return (pcall(TDP.AddTooltipPostCall, kind, function(tooltip, data)
			if not countsTooltip(tooltip) then
				return
			end
			local id = type(data) == "table" and data.id or nil
			if type(id) == "number" and not isSecret(id) then
				fn(tooltip, id)
			end
		end))
	end
	return false
end

-- One line on a tooltip: left in gold, right (optional) in white. Errors are not caught here: the
-- caller's ErrorTrap.Guard records them.
function A.TooltipLine(tooltip, left, right)
	if right then
		tooltip:AddDoubleLine(left, right, 1, 0.82, 0, 1, 1, 1)
	else
		tooltip:AddLine(left, 1, 0.82, 0)
	end
end

-- "|cffRRGGBB" for a class file name ("MAGE") from the client's class colours, or nil.
function A.ClassColour(class)
	local colours = _G.RAID_CLASS_COLORS
	local c = type(colours) == "table" and type(class) == "string" and colours[class]
	if type(c) == "table" and type(c.colorStr) == "string" then
		return "|c" .. c.colorStr
	end
	return nil
end

-- A bag or bank slot's item tooltip (the list view's rows), with an optional white hint line.
function A.SlotTooltip(owner, bag, slot, hint)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetBagItem, GameTooltip, bag, slot)
	if hint then
		GameTooltip:AddLine(hint, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- The colour of an item quality (0-8) as r, g, b (0-1), or nil when this client has no such colour.
-- Feature-detected: ColorManager's item quality data (12.x), else ITEM_QUALITY_COLORS.
function A.QualityColor(quality)
	if type(quality) ~= "number" then
		return nil
	end
	local ok, r, g, b = pcall(function()
		local get = A.Resolve("ColorManager.GetColorDataForItemQuality")
		local data = get and get(quality)
		if data and data.color then
			return data.color:GetRGB()
		end
		return nil
	end)
	if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return r, g, b
	end
	ok, r, g, b = pcall(function()
		local colors = A.Resolve("ITEM_QUALITY_COLORS")
		local c = colors and colors[quality]
		if c then
			return c.r, c.g, c.b
		end
		return nil
	end)
	if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return r, g, b
	end
	return nil
end

-- Shift/Ctrl-click on an item link (chat link, dressing room). True when Blizzard handled it.
function A.ModifiedClick(link)
	if not (IsModifiedClick and HandleModifiedItemClick) or not IsModifiedClick() then
		return false
	end
	local ok, handled = pcall(HandleModifiedItemClick, link)
	return ok and handled ~= false
end

-- True for the guild vault in PLAYER_INTERACTION_MANAGER_FRAME_SHOW / _HIDE.
function A.IsGuildBanker(interactionType)
	local PIT = Enum and Enum.PlayerInteractionType
	return PIT ~= nil and PIT.GuildBanker ~= nil and interactionType == PIT.GuildBanker
end

-- Blizzard's guild bank tab buttons (to re-host on SwagBag's window), top to bottom.
function A.GuildTabFrames()
	local gf = _G.GuildBankFrame
	local list = {}
	if not gf then
		return list
	end
	if type(gf.BankTabs) == "table" then
		for i, t in ipairs(gf.BankTabs) do
			list[i] = t
		end
	else
		for i = 1, 8 do
			local t = _G["GuildBankTab" .. i]
			if t then
				list[#list + 1] = t
			end
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Auctionator (optional price source, spec F10). Only its public API v1 is used.
---------------------------------------------------------------------------
local function auctionator()
	local api = A.Resolve("Auctionator.API.v1")
	if type(api) == "table" and type(api.GetAuctionPriceByItemLink) == "function" then
		return api
	end
	return nil
end

-- Resolved when availability is asked (once per price-cache fill), not on every price lookup.
local auctionatorApi

function A.AuctionatorAvailable()
	auctionatorApi = auctionator()
	return auctionatorApi ~= nil
end

-- Copper per unit, or nil when Auctionator has no price. Errors are the caller's to count.
function A.AuctionatorPrice(link)
	local api = auctionatorApi
	if not api then
		return nil
	end
	local v = api.GetAuctionPriceByItemLink("SwagBag", link)
	if type(v) == "number" and not isSecret(v) and v == v and v >= 0 and v < math.huge then
		return v
	end
	return nil
end

-- cb runs whenever Auctionator's price database changes (when the API offers that).
function A.AuctionatorOnUpdate(cb)
	local api = auctionator()
	if api and type(api.RegisterForDBUpdate) == "function" then
		pcall(api.RegisterForDBUpdate, "SwagBag", cb)
	end
end

---------------------------------------------------------------------------
-- Syndicator (optional alt data, spec 3.3; Providers/Syndicator.lua). Read only, through its
-- public API: Syndicator.API.IsReady, .GetAllCharacters, .GetByCharacterFullName, .GetWarband,
-- .GetInventoryInfoByItemID, and Syndicator.CallbackRegistry:RegisterCallback(event, fn, owner).
-- No Syndicator code is used; only these public names. This is the only file that names
-- Syndicator's globals: every read is feature-detected, pcall'd and checked for secret values.
---------------------------------------------------------------------------
local SYNDICATOR_NEEDS = { "IsReady", "GetAllCharacters", "GetByCharacterFullName", "GetWarband",
	"GetInventoryInfoByItemID" }
A.SYNDICATOR_EVENTS = { "BagCacheUpdate", "WarbandBankCacheUpdate", "GuildCacheUpdate", "Ready", "MailCacheUpdate",
	"EquippedCacheUpdate", "AuctionsCacheUpdate", "VoidCacheUpdate", "CharacterDeleted", "GuildDeleted" }

-- Syndicator's API table while Syndicator is loaded, has every function above and says it is
-- ready; nil otherwise (then SwagBag's own snapshots answer). Never errors.
function A.SyndicatorAPI()
	local okR, api = pcall(A.Resolve, "Syndicator.API")
	if not okR or type(api) ~= "table" or isSecret(api) then
		return nil
	end
	for _, name in ipairs(SYNDICATOR_NEEDS) do
		local okF, fn = pcall(function()
			return api[name]
		end)
		if not okF or type(fn) ~= "function" or isSecret(fn) then
			return nil
		end
	end
	local ok, ready = pcall(api.IsReady)
	if ok and not isSecret(ready) and ready == true then
		return api
	end
	return nil
end

-- Syndicator's own key for the character playing now ("Name-Realm", or "Name-PvE" with regional
-- names), or nil. Syndicator.API.GetCurrentCharacter, optional: older builds lack it.
function A.SyndicatorCurrentKey()
	local api = A.SyndicatorAPI()
	if not api then
		return nil
	end
	local okF, fn = pcall(function()
		return api.GetCurrentCharacter
	end)
	if not okF or type(fn) ~= "function" or isSecret(fn) then
		return nil
	end
	local ok, key = pcall(fn)
	if ok and type(key) == "string" and not isSecret(key) and key ~= "" then
		return key
	end
	return nil
end

-- cb runs when Syndicator's saved data changes (bags, warband bank, guild) or becomes ready.
-- Returns false when Syndicator has no callback registry (or none could be registered).
function A.SyndicatorOnUpdate(cb)
	local okR, reg = pcall(A.Resolve, "Syndicator.CallbackRegistry")
	if not okR or type(reg) ~= "table" or isSecret(reg) then
		return false
	end
	local okF, register = pcall(function()
		return reg.RegisterCallback
	end)
	if not okF or type(register) ~= "function" or isSecret(register) then
		return false
	end
	local any = false
	for _, event in ipairs(A.SYNDICATOR_EVENTS) do
		if pcall(register, reg, event, cb, A) then
			any = true
		end
	end
	return any
end

---------------------------------------------------------------------------
-- Focus-mode signals (week 4, spec 6.2). Every read is feature-detected: a missing function
-- gives the fallback named next to it, never an error.
---------------------------------------------------------------------------
-- Difficulty IDs (12.1): 8 Mythic Keystone and 23 Mythic dungeon; 208 Delves.
A.MYTHIC_DUNGEON_DIFFICULTY = { [8] = true, [23] = true }
A.DELVE_DIFFICULTY = { [208] = true }

-- { instanceType = "party" | "raid" | "pvp" | "arena" | "scenario" | nil, difficultyID = n | nil }.
-- Outside an instance (or without IsInInstance) both are nil.
function A.InstanceInfo()
	local out = {}
	local inInstance, info = _G.IsInInstance, _G.GetInstanceInfo
	if type(inInstance) ~= "function" then
		return out
	end
	local ok, inside, kind = pcall(inInstance)
	if not ok or isSecret(inside) or not inside or type(kind) ~= "string" or isSecret(kind) or kind == "none" then
		return out
	end
	out.instanceType = kind
	if type(info) == "function" then
		local okI, _, _, difficultyID = pcall(info)
		if okI and type(difficultyID) == "number" and not isSecret(difficultyID) then
			out.difficultyID = difficultyID
		end
	end
	return out
end

-- true / false: a Mythic+ key is running. Read from the challenge-mode API, else from the
-- client's ChallengeMode add-on restriction. nil when neither exists: the M+ mode then uses its
-- fallback, a Mythic party dungeon with a keystone in the bags (check V5).
function A.ChallengeModeActive()
	if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
		local ok, v = pcall(C_ChallengeMode.IsChallengeModeActive)
		if ok and not isSecret(v) then
			return v == true
		end
	end
	local R, E = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
	if R and R.IsAddOnRestrictionActive and E and E.ChallengeMode ~= nil then
		local ok, v = pcall(R.IsAddOnRestrictionActive, E.ChallengeMode)
		if ok and not isSecret(v) then
			return v == true
		end
	end
	return nil
end

-- true when an ADDON_RESTRICTION_STATE_CHANGED payload `kind` is the ChallengeMode restriction.
-- Without the enum the client cannot tell, so every restriction change counts (the zone is re-read).
function A.IsChallengeModeRestriction(kind)
	local E = Enum and Enum.AddOnRestrictionType
	if not (E and E.ChallengeMode ~= nil) or type(kind) ~= "number" or isSecret(kind) then
		return true
	end
	return kind == E.ChallengeMode
end

-- true inside a delve: the party API when the client has it, else a scenario at the delve
-- difficulty (check V7). info: an InstanceInfo() result (read again when nil).
function A.InDelve(info)
	if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
		local ok, v = pcall(C_PartyInfo.IsDelveInProgress)
		if ok and not isSecret(v) then
			return v == true
		end
	end
	info = info or A.InstanceInfo()
	return info.instanceType == "scenario" and A.DELVE_DIFFICULTY[info.difficultyID] == true
end

-- The lower-case name of a spell (name matching backs up the spell-ID lists), or nil.
function A.SpellName(spellID)
	if type(spellID) ~= "number" or isSecret(spellID) or not (C_Spell and C_Spell.GetSpellName) then
		return nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, spellID)
	if ok and type(name) == "string" and not isSecret(name) then
		return name:lower()
	end
	return nil
end

-- true while the open loot window is fishing loot; false otherwise or without the function.
function A.IsFishingLoot()
	local fn = _G.IsFishingLoot
	if type(fn) ~= "function" then
		return false
	end
	local ok, v = pcall(fn)
	return ok and not isSecret(v) and v == true
end

-- The GUID type of the first loot slot's source ("GameObject" for a node, "Creature" for
-- skinning), or nil when the client cannot tell (the gathering signal then trusts the spell).
function A.LootSourceType()
	local fn = _G.GetLootSourceInfo
	if type(fn) ~= "function" then
		return nil
	end
	local ok, guid = pcall(fn, 1)
	if not ok or type(guid) ~= "string" or isSecret(guid) then
		return nil
	end
	return guid:match("^(%a+)%-")
end

-- The character's gathering professions: { herb = true, ore = true, skin = true } (those it
-- has), or nil when the client cannot tell (Gathering then opens all three materials sections).
-- Skill lines: 182 Herbalism, 186 Mining, 393 Skinning.
local GATHER_SKILL_LINES = { [182] = "herb", [186] = "ore", [393] = "skin" }
function A.GatheringProfessions()
	local list, info = _G.GetProfessions, _G.GetProfessionInfo
	if type(list) ~= "function" or type(info) ~= "function" then
		return nil
	end
	local ok, first, second = pcall(list)
	if not ok then
		return nil
	end
	local out = {}
	for _, index in pairs({ first, second }) do
		local okI, _, _, _, _, _, _, skillLine = pcall(info, index)
		if okI and type(skillLine) == "number" and not isSecret(skillLine) and GATHER_SKILL_LINES[skillLine] then
			out[GATHER_SKILL_LINES[skillLine]] = true
		end
	end
	return out
end

-- One line in the middle of the screen (where "Not enough rage" shows), for the consumables
-- warning. Without UIErrorsFrame nothing shows there; chat still gets the line.
function A.ScreenMessage(text)
	local f = _G.UIErrorsFrame
	if f and f.AddMessage then
		pcall(f.AddMessage, f, text, 1.0, 0.82, 0.0)
	end
end

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
---------------------------------------------------------------------------
A.CHECKS = {
	{ path = "C_Container.GetContainerNumSlots", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemInfo", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemCooldown", window = "bags", required = true },
	{ path = "C_Container.GetContainerNumFreeSlots", window = "bags", required = false },
	{ path = "C_Container.GetContainerItemEquipmentSetInfo", window = "bags", required = false },
	{ path = "C_Container.GetContainerItemQuestInfo", window = "bags", required = false },
	{ path = "C_Container.SortBags", window = "bags", required = false },
	{ path = "C_Container.SortBank", window = "bank", required = false },
	{ path = "C_Container.UseContainerItem", window = "bags", required = false },
	{ path = "CanMerchantRepair", window = "bags", required = false },
	{ path = "GetRepairAllCost", window = "bags", required = false },
	{ path = "RepairAllItems", window = "bags", required = false },
	{ path = "CanGuildBankRepair", window = "bags", required = false },
	{ path = "GetGuildBankWithdrawMoney", window = "bags", required = false },
	{ path = "GetGuildBankMoney", window = "bags", required = false },
	{ path = "GetCursorInfo", window = "bags", required = false },
	{ path = "ClearCursor", window = "bags", required = false },
	{ path = "GameTooltip", window = "bags", required = false },
	{ path = "C_Item.GetItemInfoInstant", window = "bags", required = true },
	{ path = "C_Item.GetItemInfo", window = "bags", required = true },
	{ path = "C_Item.GetCurrentItemLevel", window = "bags", required = true },
	{ path = "C_Item.RequestLoadItemDataByID", window = "bags", required = true },
	{ path = "C_Item.IsUsableItem", window = "bags", required = false },
	{ path = "C_Item.IsBoundToAccountUntilEquip", window = "bags", required = false },
	{ path = "C_Item.GetItemUpgradeInfo", window = "bags", required = false },
	{ path = "C_Item.GetDetailedItemLevelInfo", window = "bank", required = false },
	{ path = "C_ToyBox.GetToyInfo", window = "bags", required = false },
	{ path = "PlayerHasToy", window = "bags", required = false },
	{ path = "C_MountJournal.GetMountFromItem", window = "bags", required = false },
	{ path = "C_MountJournal.GetMountInfoByID", window = "bags", required = false },
	{ path = "C_PetJournal.GetPetInfoByItemID", window = "bags", required = false },
	{ path = "C_PetJournal.GetNumCollectedInfo", window = "bags", required = false },
	{ path = "C_HousingCatalog.GetCatalogEntryInfoByItem", window = "bags", required = false },
	{ path = "C_Timer.After", window = "bags", required = true },
	{ path = "C_AddOns.IsAddOnLoaded", window = "bags", required = false },
	{ path = "ItemLocation.CreateFromBagAndSlot", window = "bags", required = true },
	{ path = "ContainerFrameItemButtonMixin", window = "bags", required = true },
	{ path = "SetItemButtonTexture", window = "bags", required = true },
	{ path = "SetItemButtonCount", window = "bags", required = true },
	{ path = "SetItemButtonQuality", window = "bags", required = true },
	{ path = "SetItemButtonDesaturated", window = "bags", required = true },
	{ path = "ToggleAllBags", window = "bags", required = true },
	{ path = "ToggleBackpack", window = "bags", required = true },
	{ path = "ToggleBag", window = "bags", required = false },
	{ path = "OpenAllBags", window = "bags", required = true },
	{ path = "CloseAllBags", window = "bags", required = true },
	{ path = "ContainerFrame1", window = "bags", required = true },
	{ path = "ContainerFrameCombinedBags", window = "bags", required = true },
	{ path = "UISpecialFrames", window = "bags", required = true },
	{ path = "Enum.BagIndex.Backpack", value = 0, window = "bags", required = true },
	{ path = "Enum.BagIndex.ReagentBag", value = 5, window = "bags", required = true },
	{ path = "Enum.BagIndex.CharacterBankTab_1", value = 6, window = "bank", required = true },
	{ path = "Enum.BagIndex.AccountBankTab_1", value = 12, window = "bank", required = true },
	{ path = "Enum.BankType.Character", value = 0, window = "bank", required = true },
	{ path = "Enum.BankType.Account", value = 2, window = "bank", required = true },
	{ path = "C_Bank.FetchPurchasedBankTabIDs", window = "bank", required = true },
	{ path = "BankFrame", window = "bank", required = true },
	{ path = "BankFrame.GetActiveBankType", window = "bank", required = true },
	{ path = "BankFrame.TabSystem", window = "bank", required = true },
	{ path = "C_Bank.AutoDepositItemsIntoBank", window = "bank", required = false },
	{ path = "C_Bank.FetchBankLockedReason", window = "bank", required = false },
	{ path = "C_Bank.CanUseBank", window = "bank", required = false },
	{ path = "C_Bank.IsItemAllowedInBankType", window = "bank", required = false },
	{ path = "C_Item.CanBeRefunded", window = "bank", required = false },
	{ path = "C_Item.DoesItemExist", window = "bank", required = false },
	{ path = "C_CVar.GetCVarBool", window = "bank", required = false },
	{ path = "C_CVar.SetCVar", window = "bank", required = false },
	{ path = "Enum.ItemClass", window = "bags", required = false },
	{ path = "Enum.ItemBind", window = "bags", required = false },
	{ path = "Enum.AddOnRestrictionType", window = "bags", required = false },
	{ path = "C_ChallengeMode.IsChallengeModeActive", window = "bags", required = false },
	{ path = "C_ChallengeMode.GetMapUIInfo", window = "bags", required = false },
	{ path = "C_PlayerInfo.CanUseItem", window = "bags", required = false },
	{ path = "C_Item.GetCurrentItemLevel", window = "bags", required = false },
	{ path = "ItemLocation.CreateFromEquipmentSlot", window = "bags", required = false },
	{ path = "GetInventoryItemLink", window = "bags", required = false },
	{ path = "GetAverageItemLevel", window = "bags", required = false },
	{ path = "C_RestrictedActions.IsAddOnRestrictionActive", window = "bags", required = false },
	{ path = "GetGuildBankItemInfo", window = "bank", required = false },
	{ path = "GetGuildBankItemLink", window = "bank", required = false },
	{ path = "GetGuildBankTabInfo", window = "bank", required = false },
	{ path = "QueryGuildBankTab", window = "bank", required = false },
	{ path = "AutoStoreGuildBankItem", window = "bank", required = false },
	{ path = "PickupGuildBankItem", window = "bank", required = false },
	{ path = "Enum.PlayerInteractionType.GuildBanker", window = "bank", required = false },
	{ path = "IsInInstance", window = "bags", required = false },
	{ path = "GetInstanceInfo", window = "bags", required = false },
	{ path = "C_PartyInfo.IsDelveInProgress", window = "bags", required = false },
	{ path = "C_Spell.GetSpellName", window = "bags", required = false },
	{ path = "IsFishingLoot", window = "bags", required = false },
	{ path = "GetLootSourceInfo", window = "bags", required = false },
	{ path = "GetProfessions", window = "bags", required = false },
	{ path = "GetProfessionInfo", window = "bags", required = false },
	{ path = "UIErrorsFrame", window = "bags", required = false },
	{ path = "C_NewItems.RemoveNewItem", window = "bags", required = false },
	{ path = "GetMoney", window = "bags", required = false },
	{ path = "C_CurrencyInfo.GetBackpackCurrencyInfo", window = "bags", required = false },
	{ path = "C_CurrencyInfo.GetCurrencyInfo", window = "bags", required = false },
	{ path = "C_CurrencyInfo.GetCurrencyListInfo", window = "bags", required = false },
	{ path = "C_CurrencyInfo.GetCurrencyListSize", window = "bags", required = false },
	{ path = "C_CurrencyInfo.GetCurrencyListLink", window = "bags", required = false },
	{ path = "C_CurrencyInfo.GetCurrencyIDFromLink", window = "bags", required = false },
	{ path = "GetMoneyString", window = "bags", required = false },
	{ path = "GetCoinTextureString", window = "bags", required = false },
}
