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

function A.IsWarboundUntilEquip(bag, slot)
	if not (C_Item and C_Item.IsBoundToAccountUntilEquip) then
		return false
	end
	local ok, v = pcall(function()
		return C_Item.IsBoundToAccountUntilEquip(location(bag, slot))
	end)
	return ok and v == true
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

function A.HasPawn()
	return type(_G.PawnIsContainerItemAnUpgrade) == "function"
end

-- Pawn's verdict for a bag item: true / false, or nil without Pawn (spec AC9.3).
function A.PawnUpgrade(bag, slot)
	local fn = _G.PawnIsContainerItemAnUpgrade
	if type(fn) ~= "function" then
		return nil
	end
	local ok, yes = pcall(fn, bag, slot)
	if not ok then
		return nil
	end
	-- Pawn's nil also means "not an upgrade", so it folds to false here.
	return yes and true or false
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

---------------------------------------------------------------------------
-- Blizzard frames and the bank (week 3). SwagBag only READS Blizzard's bank state
-- (spec 5.2, 5.3): it never selects a tab or a bank type and never closes the bank.
---------------------------------------------------------------------------
-- A Blizzard frame by its global name (BankFrame, GuildBankFrame, ...), or nil.
function A.Frame(name)
	return _G[name]
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

function A.GuildTooltip(owner, tab, slot)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetGuildBankItem, GameTooltip, tab, slot)
	GameTooltip:Show()
end

function A.HideTooltip()
	if GameTooltip then
		GameTooltip:Hide()
	end
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
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
---------------------------------------------------------------------------
A.CHECKS = {
	{ path = "C_Container.GetContainerNumSlots", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemInfo", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemCooldown", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemEquipmentSetInfo", window = "bags", required = false },
	{ path = "C_Container.GetContainerItemQuestInfo", window = "bags", required = false },
	{ path = "C_Container.SortBags", window = "bags", required = false },
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
	{ path = "C_ToyBox.GetToyInfo", window = "bags", required = false },
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
}
