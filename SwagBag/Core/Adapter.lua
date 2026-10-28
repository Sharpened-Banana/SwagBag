-- SwagBag Adapter: the ONLY file allowed to name C_* namespaces, Enum or the WOW_PROJECT_* constants
-- (scripts/check.sh fails the build otherwise). Everything else calls SB.Adapter.*.
-- Client flavor (Forever Stage A): A.Flavor() tells Retail from WoW Forever by the project constant, then by a
-- Forever-only API; never by the Interface number. What each client may show lives only in A.FEATURES: UI files
-- ask A.Has(feature) or A.Allows(surface, id), never A.Flavor(). On Retail both answer true for everything.
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

-- Week 9 (user pick 11b): other bag replacements that fight SwagBag over the same bags, by the folder name
-- C_AddOns reports them loaded under (A.AddOnState), and ElvUI only while its own bags module is on
-- (ElvUI[1].private.bags.enable; ElvUI without its bags is fine). Read only: SwagBag never disables an addon.
A.OTHER_BAG_ADDONS = { "Baganator", "Bagnon", "Combuctor", "AdiBags", "ArkInventory", "BetterBags", "LiteBag",
	"Sorted", "GudaBags", "Inventorian", "EllesmereUIBags", "EnhanceQoLBags" }

function A.ElvUIBagsOn()
	local ok, on = pcall(function()
		local E = A.Resolve("ElvUI")
		E = type(E) == "table" and E[1]
		local private = type(E) == "table" and E.private
		local bags = type(private) == "table" and private.bags
		return type(bags) == "table" and bags.enable == true
	end)
	return ok and on == true
end

-- The names of the other bag addons that are on now, in A.OTHER_BAG_ADDONS order, then "ElvUI".
function A.OtherBagAddons()
	local out = {}
	for _, name in ipairs(A.OTHER_BAG_ADDONS) do
		if A.AddOnState(name) then
			out[#out + 1] = name
		end
	end
	if A.ElvUIBagsOn() then
		out[#out + 1] = "ElvUI"
	end
	return out
end

---------------------------------------------------------------------------
-- Client flavor and capabilities (Forever Stage A)
---------------------------------------------------------------------------
-- "retail" or "forever". Gate on the project constant, then on the feature; never on the Interface number.
-- Not cached, so tests can switch it. An unknown project that is not Retail takes the restricted profile.
function A.Flavor()
	local id = _G.WOW_PROJECT_ID
	local forever = _G.WOW_PROJECT_FOREVER or _G.WOW_PROJECT_CAMELOT
	local mainline = _G.WOW_PROJECT_MAINLINE
	if id ~= nil and forever ~= nil and id == forever then
		return "forever"
	end
	if id ~= nil and mainline ~= nil and id ~= mainline then
		return "forever"
	end
	if mainline == nil and C_Bank and C_Bank.ShouldUsePlayerBagsInBank ~= nil then
		return "forever" -- no MAINLINE to compare with, but the Forever API: uncertain means Forever (report section 3)
	end
	return "retail"
end

-- The one table of Retail-only features. forever = true only once a feature is verified on WoW Forever;
-- surfaces lists the entry points (overlay, footer, mode, trigger, style, setting ids) each feature owns.
A.FEATURES = {
	-- No Challenges UI, no Mythic+, no crests.
	keystones = { forever = false, surfaces = {
		overlay = { "keystone" }, footer = { "crests", "keystone" }, mode = { "mplus" }, trigger = { "mplus" },
		style = { "mplus" }, setting = { "overlays.keystone", "focus.on.mplus" },
	} },
	-- The Delves UI is standard only.
	delves = { forever = false, surfaces = { mode = { "delves" }, trigger = { "delve" }, setting = { "focus.on.delves" } } },
	-- Retail's upgrade system.
	upgradeTracks = { forever = false, surfaces = { overlay = { "track" }, setting = { "overlays.track" } } },
	-- Housing is standard only (data only: DecorKnown).
	housing = { forever = false, surfaces = {} },
	-- Whether the warband bank is enabled is unverified (data only: warband tabs, WuE, warband snapshots).
	warband = { forever = false, surfaces = {} },
	-- Forever's bank-bag bank is unverified (Boot's Safe Mode).
	bankWindow = { forever = false, surfaces = {} },
	-- 0.16.0 search: whether Forever's items carry Retail's expansion IDs is unverified (the expansion keywords).
	expansion = { forever = false, surfaces = { keyword = { "expansion", "classic", "tbc", "wrath", "cata", "mop", "wod",
		"legion", "bfa", "shadowlands", "dragonflight", "tww", "midnight" } } },
}

-- Is a declared feature on for this client? An undeclared name is off on both clients.
function A.Has(feature)
	local f = A.FEATURES[feature]
	if f == nil then
		return false
	end
	if A.Flavor() ~= "forever" then
		return true
	end
	return f.forever == true
end

-- surface -> id -> { feature names that list it }, built once from A.FEATURES on first use.
local surfaceIndex
function A.Allows(surface, id)
	if surfaceIndex == nil then
		surfaceIndex = {}
		for name, f in pairs(A.FEATURES) do
			for s, ids in pairs(f.surfaces) do
				surfaceIndex[s] = surfaceIndex[s] or {}
				for _, i in ipairs(ids) do
					local owners = surfaceIndex[s][i] or {}
					owners[#owners + 1] = name
					surfaceIndex[s][i] = owners
				end
			end
		end
	end
	local owners = surfaceIndex[surface] and surfaceIndex[surface][id]
	if owners then
		for _, name in ipairs(owners) do
			if not A.Has(name) then
				return false
			end
		end
	end
	return true
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
A.ARMOR_SUB = {
	Generic = 0, Cloth = 1, Leather = 2, Mail = 3, Plate = 4, Cosmetic = 5, Shield = 6, Libram = 7, Idol = 8,
	Totem = 9, Sigil = 10, Relic = 11,
}
-- Expansion numbers (GetItemInfo's expansionID); the LE_EXPANSION_* globals override them when present.
A.EXPANSION = {
	Classic = 0, BurningCrusade = 1, Wrath = 2, Cataclysm = 3, Pandaria = 4, Draenor = 5, Legion = 6,
	BattleForAzeroth = 7, Shadowlands = 8, Dragonflight = 9, WarWithin = 10, Midnight = 11,
}
local EXPANSION_GLOBALS = {
	Classic = "LE_EXPANSION_CLASSIC", BurningCrusade = "LE_EXPANSION_BURNING_CRUSADE",
	Wrath = "LE_EXPANSION_WRATH_OF_THE_LICH_KING", Cataclysm = "LE_EXPANSION_CATACLYSM",
	Pandaria = "LE_EXPANSION_MISTS_OF_PANDARIA", Draenor = "LE_EXPANSION_WARLORDS_OF_DRAENOR",
	Legion = "LE_EXPANSION_LEGION", BattleForAzeroth = "LE_EXPANSION_BATTLE_FOR_AZEROTH",
	Shadowlands = "LE_EXPANSION_SHADOWLANDS", Dragonflight = "LE_EXPANSION_DRAGONFLIGHT",
	WarWithin = "LE_EXPANSION_WAR_WITHIN", Midnight = "LE_EXPANSION_MIDNIGHT",
}
for name, global in pairs(EXPANSION_GLOBALS) do
	if type(_G[global]) == "number" then
		A.EXPANSION[name] = _G[global]
	end
end

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

-- Blizzard's Retail 12.1.5 Enum.BagIndex (Gethe/wow-ui-source, live branch, BagIndexConstantsDocumentation.lua),
-- copied verbatim: the only bag-ID literals in SwagBag, and the whole-table fallback.
A.RETAIL_BAG_INDEX = {
	Accountbanktab = -3, Characterbanktab = -2, Keyring = -1,
	Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
	CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, CharacterBankTab_3 = 8, CharacterBankTab_4 = 9,
	CharacterBankTab_5 = 10, CharacterBankTab_6 = 11,
	AccountBankTab_1 = 12, AccountBankTab_2 = 13, AccountBankTab_3 = 14, AccountBankTab_4 = 15,
	AccountBankTab_5 = 16,
}

-- The bag layout from an Enum.BagIndex table (pure; reads only the names below):
-- { bags = { ids }, reagent = id | nil, bank = { first, last }, warband = { first, last },
--   kind = { [id] = "backpack" | "bags" | "reagentbag" | "bank" | "warband" }, tab = { [id] = n } }.
-- A range runs while each name is the previous ID plus 1, so a gap ends it. nil when Backpack, Bag_1,
-- CharacterBankTab_1 or AccountBankTab_1 is not a number, or when an ID would belong to two kinds.
-- Every other name (Keyring, Characterbanktab, Accountbanktab, Bank...) is ignored.
function A.LayoutFromBagIndex(bi)
	if type(bi) ~= "table" then
		return nil
	end
	local function num(name)
		local v = bi[name]
		if type(v) == "number" then
			return v
		end
		return nil
	end
	local backpack, bag1 = num("Backpack"), num("Bag_1")
	local bank1, warband1 = num("CharacterBankTab_1"), num("AccountBankTab_1")
	if not (backpack and bag1 and bank1 and warband1) or bag1 ~= backpack + 1 then
		return nil
	end
	-- A run must not have a gap: once it ends at prefix..n, no higher prefix..k may exist.
	local function gapAfter(prefix, n)
		for k = n + 1, n + 32 do
			if bi[prefix .. k] ~= nil then
				return true
			end
		end
		return false
	end
	local layout = { bags = {}, kind = {}, tab = {} }
	local ok = true
	local function claim(id, kind, tab)
		if layout.kind[id] ~= nil then
			ok = false
			return
		end
		layout.kind[id], layout.tab[id] = kind, tab
	end
	layout.bags[1] = backpack
	claim(backpack, "backpack")
	local prev, i = backpack, 1
	while num("Bag_" .. i) == prev + 1 do
		prev = prev + 1
		layout.bags[#layout.bags + 1] = prev
		claim(prev, "bags")
		i = i + 1
	end
	if gapAfter("Bag_", i - 1) then
		return nil
	end
	local reagent = num("ReagentBag")
	if reagent then
		if reagent ~= prev + 1 then
			return nil
		end
		layout.reagent = reagent
		layout.bags[#layout.bags + 1] = reagent
		claim(reagent, "reagentbag")
	end
	local function range(prefix, first, kind)
		local last, n = first, 1
		claim(first, kind, 1)
		while num(prefix .. (n + 1)) == last + 1 do
			last, n = last + 1, n + 1
			claim(last, kind, n)
		end
		if gapAfter(prefix, n) then
			ok = false
		end
		return { first = first, last = last }
	end
	layout.bank = range("CharacterBankTab_", bank1, "bank")
	layout.warband = range("AccountBankTab_", warband1, "warband")
	if not ok then
		return nil
	end
	return layout
end

A.RETAIL_LAYOUT = A.LayoutFromBagIndex(A.RETAIL_BAG_INDEX)

-- The live layout, from Enum.BagIndex: derived again only when the client's table changes (identity),
-- else cached. Falls back whole to A.RETAIL_LAYOUT when there is no table or it does not derive.
local layoutIndex, layoutCached
function A.BagLayout()
	local bi = Enum and Enum.BagIndex
	if type(bi) ~= "table" then
		return A.RETAIL_LAYOUT
	end
	if bi ~= layoutIndex then
		layoutIndex = bi
		layoutCached = A.LayoutFromBagIndex(bi) or A.RETAIL_LAYOUT
	end
	return layoutCached
end

-- Bag ID ranges derived from Enum.BagIndex names (Retail 6-11 / 12-16, Forever 6-14 / 15-23); the 12.1.5
-- table is the fallback. 0 backpack, then the bags and the reagent bag, then character bank and warband tabs.
-- Returns location kind and, for bank tabs, the tab number (1-based); nothing for an unknown bag.
function A.BagKind(bag)
	local layout = A.BagLayout()
	return layout.kind[bag], layout.tab[bag]
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
	if kind == "warband" and not A.Has("warband") then
		return {} -- WoW Forever: the warband bank is never read
	end
	if kind == "bags" then
		local out = {}
		for i, id in ipairs(A.BagLayout().bags) do
			out[i] = id
		end
		return out
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

-- A bag's name for the per-bag view: bag 0 is L.PERBAG_BACKPACK; any other bag asks the game. nil when the
-- game has no name (no bag equipped), the name is not text or is secret, or the call fails (the caller falls
-- back to L.PERBAG_BAG).
function A.BagName(bag)
	if bag == 0 then
		return SB.L.PERBAG_BACKPACK
	end
	if not (C_Container and C_Container.GetBagName) then
		return nil
	end
	local ok, name = pcall(C_Container.GetBagName, bag)
	if ok and type(name) == "string" and name ~= "" and not isSecret(name) then
		return name
	end
	return nil
end

-- Names of the purchased bank tabs: { [tabID] = name }. kind: "bank" | "warband". A tab with no readable
-- name (missing, empty, secret) is absent; the caller falls back to L.PERBAG_TAB.
function A.BankTabNames(kind)
	local bt = Enum and Enum.BankType
	local bankType = bt and ((kind == "bank" and bt.Character) or (kind == "warband" and bt.Account))
	local out = {}
	if not bankType or not (C_Bank and C_Bank.FetchPurchasedBankTabData) then
		return out
	end
	local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
	if ok and type(tabs) == "table" then
		for _, t in ipairs(tabs) do
			if type(t) == "table" then
				local id, name = t.ID, t.name
				if type(id) == "number" and not isSecret(id) and type(name) == "string" and name ~= ""
					and not isSecret(name) then
					out[id] = name
				end
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

-- True when the slot holds an item whose ID (or whose whole record) is a secret value (Midnight, in an instance):
-- GetSlot reads that slot as empty, but it is not (hotfix 0.11.1: the Inventory keeps its last known item).
function A.SlotIsSecret(bag, slot)
	local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
	if not ok or info == nil then
		return false
	end
	if isSecret(info) then
		return true
	end
	return type(info) == "table" and info.itemID ~= nil and isSecret(info.itemID)
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
		expansionID, setID, isCraftingReagent = pcall(C_Item.GetItemInfo, item)
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
		setID = setID,
		isCraftingReagent = isCraftingReagent == true,
	}
end

-- The client's stat names -> SwagBag's. A combined primary stat (ITEM_MOD_STRENGTH_AGILITY_INTELLECT_SHORT) counts
-- for each primary stat it names; EMPTY_SOCKET_* add up to emptySockets.
local STAT_NAMES = {
	ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_HASTE_RATING_SHORT = "haste",
	ITEM_MOD_MASTERY_RATING_SHORT = "mastery", ITEM_MOD_VERSATILITY = "vers", ITEM_MOD_CR_LIFESTEAL_SHORT = "leech",
	ITEM_MOD_CR_AVOIDANCE_SHORT = "avoidance", ITEM_MOD_CR_SPEED_SHORT = "speed", ITEM_MOD_STAMINA_SHORT = "stam",
	ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}
local PRIMARY_PARTS = { STRENGTH = "str", AGILITY = "agi", INTELLECT = "int" }

-- An item link's stats (0.16.0 search): { crit, haste, mastery, vers, leech, avoidance, speed, str, agi, int, stam,
-- dps = number (only the stats it has), emptySockets = number }. false: no stats API on this client; nil: no answer
-- yet (not loaded, a broken call) or a secret value.
function A.ItemStats(link)
	local api = (C_Item and C_Item.GetItemStats) or _G.GetItemStats
	if type(link) ~= "string" or api == nil then
		return false
	end
	local ok, raw = pcall(api, link)
	if not ok or type(raw) ~= "table" or isSecret(raw) then
		return nil
	end
	local out = { emptySockets = 0 }
	for key, v in pairs(raw) do
		if isSecret(key) or isSecret(v) or type(v) ~= "number" then
			return nil
		end
		if STAT_NAMES[key] then
			out[STAT_NAMES[key]] = v
		elseif key:find("^EMPTY_SOCKET_") then
			out.emptySockets = out.emptySockets + v
		elseif key:find("^ITEM_MOD_") then
			for part, name in pairs(PRIMARY_PARTS) do
				if key:find(part, 1, true) then
					out[name] = math.max(out[name] or 0, v)
				end
			end
		end
	end
	return out
end

-- The colon-separated fields of a link's item string (field 1 is the item ID), or nil when it has none.
local function itemFields(link)
	local s = type(link) == "string" and link:match("item:([^|]*)")
	if not s then
		return nil
	end
	local fields = {}
	for f in (s .. ":"):gmatch("([^:]*):") do
		fields[#fields + 1] = f
	end
	return fields
end

-- Filled sockets: the four gem fields of the item string (fields 3-6) that hold a gem. nil: not an item link.
function A.LinkGemCount(link)
	local fields = itemFields(link)
	if not fields then
		return nil
	end
	local n = 0
	for i = 3, 6 do
		if tonumber(fields[i] or "") then
			n = n + 1
		end
	end
	return n
end

-- The bonus IDs of an item link: field 13 holds their count and the IDs follow. {} for none; nil: not an item link.
function A.LinkBonusIDs(link)
	local fields = itemFields(link)
	if not fields then
		return nil
	end
	local out = {}
	for i = 1, tonumber(fields[13] or "") or 0 do
		local id = tonumber(fields[13 + i] or "")
		if id then
			out[#out + 1] = id
		end
	end
	return out
end

-- An item's tooltip text (0.16.0 search, the recorded P7 exception: only `text:` and the damage phrases read it):
-- every left and right line, lower-cased, from C_TooltipInfo for a bag slot, else for the link (guild and alt items).
-- false: no tooltip API; nil: no answer yet, a broken call or a secret line.
function A.TooltipLines(bag, slot, link)
	local api = C_TooltipInfo
	if api == nil then
		return false
	end
	local ok, data
	if bag ~= nil and slot ~= nil and api.GetBagItem then
		ok, data = pcall(api.GetBagItem, bag, slot)
	elseif type(link) == "string" and api.GetHyperlink then
		ok, data = pcall(api.GetHyperlink, link)
	else
		return false
	end
	if not ok or type(data) ~= "table" or isSecret(data) or type(data.lines) ~= "table" then
		return nil
	end
	local out = {}
	for _, line in ipairs(data.lines) do
		for _, key in ipairs({ "leftText", "rightText" }) do
			local t = type(line) == "table" and line[key]
			if t ~= nil and t ~= false then
				if isSecret(t) then
					return nil
				end
				if type(t) == "string" and t ~= "" then
					out[#out + 1] = t:lower()
				end
			end
		end
	end
	if #out == 0 then
		return nil
	end
	return out
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
	if not A.Has("warband") then
		return false
	end
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
-- only; no tooltip reading (spec P7). Missing API, or no upgrade tracks on this client: nil, false.
function A.UpgradeInfo(link)
	if not A.Has("upgradeTracks") then
		return nil, false
	end
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
	if not A.Has("keystones") then
		return nil
	end
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
	if not A.Has("housing") then
		return nil
	end
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

-- Whether the account has collected an item's appearance (week 7, user pick 9). Four answers:
--   true       collected
--   false      a look the account can collect and has not
--   "cannot"   the client says the account cannot collect it (nothing to protect, no star)
--   nil        unknown: no appearance source, the client has no data yet, a secret, or no API
-- Read from C_TransmogCollection only (no armor-type rule of SwagBag's own: 12.2.5 lifts those restrictions).
function A.AppearanceKnown(link)
	local T = C_TransmogCollection
	if type(link) ~= "string" or isSecret(link) or not (T and T.GetItemInfo and T.PlayerHasTransmogItemModifiedAppearance) then
		return nil
	end
	local ok, _, sourceID = pcall(T.GetItemInfo, link)
	if not ok or type(sourceID) ~= "number" or isSecret(sourceID) then
		return nil
	end
	if T.AccountCanCollectSource then
		local okC, hasData, canCollect = pcall(T.AccountCanCollectSource, sourceID)
		if not okC or isSecret(hasData) or isSecret(canCollect) or hasData ~= true then
			return nil
		end
		if canCollect ~= true then
			return "cannot"
		end
	end
	return known(pcall(T.PlayerHasTransmogItemModifiedAppearance, sourceID))
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

-- Week 9 (P5): anything at all on the cursor: an item (even one whose ID is secret), a merchant's item, money,
-- a spell, a macro. CursorItem above sees only an item with a readable ID; moves wait while this is true.
local function cursorHeld()
	if not GetCursorInfo then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return ok and kind ~= nil
end

-- Final review (item 2): a spell waiting for its target (the targeting hand: GetCursorInfo says nothing) counts
-- too, since a click on a slot would cast it on that item.
local function spellTargeting()
	if not SpellIsTargeting then
		return false
	end
	local ok, yes = pcall(SpellIsTargeting)
	return ok and yes == true
end

function A.CursorBusy()
	return cursorHeld() or spellTargeting()
end

-- Week 10 (UI/LockWarnings.lua): a spell waits for its target (Disenchant, Milling, Prospecting, an enchant...), so
-- the next click on an item casts it there. Read only, to warn: SwagBag never cancels or changes the spell.
function A.SpellTargeting()
	return spellTargeting()
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

-- Week 9 (user pick 8, Engine/Stacker.lua): one stack onto another, as a player does it: a click on the stack
-- (C_Container.PickupContainerItem) and a click on the target. The game merges as many as fit onto a stack of
-- the same item, or swaps the two; what is left on the cursor goes back where it came from, so nothing ever
-- stays held. Never starts while the cursor holds anything (A.CursorBusy). Out of combat only (the stacker
-- checks). ok, err.
function A.MoveStack(fromBag, fromSlot, toBag, toSlot)
	if not (C_Container and C_Container.PickupContainerItem) or A.CursorBusy() then
		return false
	end
	local ok, err = pcall(C_Container.PickupContainerItem, fromBag, fromSlot)
	if ok then
		ok, err = pcall(C_Container.PickupContainerItem, toBag, toSlot)
	end
	if cursorHeld() then
		pcall(C_Container.PickupContainerItem, fromBag, fromSlot)
	end
	if cursorHeld() then
		A.ClearCursor()
	end
	return ok, err
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

-- true / false: whether the bank of that kind takes the bag item; nil when the client cannot say.
function A.AllowedInBank(bag, slot, kind)
	local BT = Enum and Enum.BankType
	local bankType = BT and ((kind == "bank" and BT.Character) or (kind == "warband" and BT.Account))
	if bankType == nil or not (C_Bank and C_Bank.IsItemAllowedInBankType) then
		return nil
	end
	local ok, yes = pcall(function()
		return C_Bank.IsItemAllowedInBankType(bankType, location(bag, slot))
	end)
	if not ok or isSecret(yes) or type(yes) ~= "boolean" then
		return nil
	end
	return yes
end

-- true while Shift is held (the section actions' Shift+right-click, week 7).
function A.ShiftDown()
	local fn = _G.IsShiftKeyDown
	if type(fn) ~= "function" then
		return false
	end
	local ok, yes = pcall(fn)
	return ok and yes == true
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

-- The links in the vendor's buyback tab (the last 12 items sold), oldest first; empty without the API.
function A.BuybackLinks()
	local num, link, out = _G.GetNumBuybackItems, _G.GetBuybackItemLink, {}
	if type(num) ~= "function" or type(link) ~= "function" then
		return out
	end
	local ok, n = pcall(num)
	if not ok or type(n) ~= "number" or isSecret(n) then
		return out
	end
	for i = 1, math.min(n, 12) do
		local okL, l = pcall(link, i)
		if okL and type(l) == "string" and not isSecret(l) then
			out[#out + 1] = l
		end
	end
	return out
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
-- Warband gold (0.14.2). SwagBag shows the Warband bank's gold and opens Blizzard's own "BANK_MONEY_DEPOSIT" /
-- "BANK_MONEY_WITHDRAW" popups, as Blizzard's bank buttons do (and ElvUI, BetterBags, Baganator): Blizzard's
-- OnAccept reads the typed amount and makes the call. SwagBag never calls C_Bank.DepositMoney or WithdrawMoney itself.
-- Only the Warband (Account) bank type is ever asked: the character bank holds no gold since 11.2.
---------------------------------------------------------------------------
-- A yes/no question to C_Bank about the Warband bank: true only for a plain true (missing, failing or secret: false).
local function warbandAsk(name, account)
	local fn = C_Bank and C_Bank[name]
	if type(fn) ~= "function" then
		return false
	end
	local ok, yes = pcall(fn, account)
	return ok and not isSecret(yes) and yes == true
end

-- canDeposit, canWithdraw, supported: whether the Warband bank moves gold at all (supported) and each way now.
function A.WarbandMoneyState()
	local account = warbandType()
	if account == nil or not warbandAsk("DoesBankTypeSupportMoneyTransfer", account) then
		return false, false, false
	end
	return warbandAsk("CanDepositMoney", account), warbandAsk("CanWithdrawMoney", account), true
end

-- The Warband bank's gold in copper, or nil when it holds none it can move, or the client cannot say (missing,
-- failing or secret).
function A.WarbandMoney()
	local account = warbandType()
	if account == nil or not (C_Bank and C_Bank.FetchDepositedMoney) then
		return nil
	end
	if not warbandAsk("DoesBankTypeSupportMoneyTransfer", account) then
		return nil
	end
	local ok, copper = pcall(C_Bank.FetchDepositedMoney, account)
	if not ok or type(copper) ~= "number" or isSecret(copper) then
		return nil
	end
	return copper
end

local MONEY_POPUPS = { deposit = "BANK_MONEY_DEPOSIT", withdraw = "BANK_MONEY_WITHDRAW" }

-- Whether Blizzard's popup named which is shown (false when the client cannot say).
local function popupShown(which)
	local visible = _G.StaticPopup_Visible or _G.StaticPopup_FindVisible
	if not which or type(visible) ~= "function" then
		return false
	end
	local ok, open = pcall(visible, which)
	return ok and open ~= nil and open ~= false
end

-- true while Blizzard's gold popup of kind "deposit" | "withdraw" is shown.
function A.WarbandMoneyPopupShown(kind)
	return popupShown(MONEY_POPUPS[kind])
end

-- Open Blizzard's popup for kind "deposit" | "withdraw" with the Warband bank type, as Blizzard's own button does:
-- the other popup hides first, and this one, already shown, hides instead (a toggle). true when the popup opened
-- or was toggled off; false when this client has no such popup or would not show it.
function A.ShowWarbandMoneyPopup(kind)
	local which, account = MONEY_POPUPS[kind], warbandType()
	local show, hide, dialogs = _G.StaticPopup_Show, _G.StaticPopup_Hide, _G.StaticPopupDialogs
	if not which or account == nil or type(show) ~= "function" or type(dialogs) ~= "table" or dialogs[which] == nil then
		return false
	end
	local other = MONEY_POPUPS[kind == "deposit" and "withdraw" or "deposit"]
	if type(hide) == "function" then
		pcall(hide, other)
		if popupShown(which) then
			pcall(hide, which)
			return true
		end
	end
	-- a table constructor (never a write to a frame's bankType field): the popup's data, read by Blizzard's OnAccept
	local ok, dialog = pcall(show, which, nil, nil, { bankType = account })
	return ok and dialog ~= nil
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

-- Week 10: one red warning line, wrapped (UI/LockWarnings.lua). Errors are not caught here either.
function A.TooltipWarning(tooltip, text)
	tooltip:AddLine(text, 1, 0.27, 0.27, true)
end

-- Week 10: Blizzard's delete box, while one of its four kinds is shown (StaticPopup_FindVisible), else nil. Read
-- only: UI/LockWarnings.lua anchors its own note above it and never calls anything on the box.
A.DELETE_POPUPS = { "DELETE_ITEM", "DELETE_GOOD_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_QUEST_ITEM" }
function A.DeletePopup()
	local find = _G.StaticPopup_FindVisible
	if type(find) ~= "function" then
		return nil
	end
	for _, which in ipairs(A.DELETE_POPUPS) do
		local ok, box = pcall(find, which)
		if ok and box then
			return box
		end
	end
	return nil
end

-- Week 10: the scrapper, in PLAYER_INTERACTION_MANAGER_FRAME_SHOW / _HIDE.
function A.IsScrapper(interactionType)
	local PIT = Enum and Enum.PlayerInteractionType
	return PIT ~= nil and PIT.ScrappingMachine ~= nil and interactionType == PIT.ScrappingMachine
end

-- Week 10: the item IDs in the scrapper's slots (Blizzard numbers them from 0), read only: SwagBag never adds,
-- removes or scraps anything. A slot that is empty, fails or holds a secret ID is skipped.
A.SCRAP_SLOTS = 9
function A.ScrapperItemIDs()
	local S = _G.C_ScrappingMachineUI
	local out = {}
	if not (S and S.GetCurrentPendingScrapItemLocationByIndex and C_Item and C_Item.GetItemID) then
		return out
	end
	for index = 0, A.SCRAP_SLOTS - 1 do
		local ok, loc = pcall(S.GetCurrentPendingScrapItemLocationByIndex, index)
		if ok and loc then
			local okID, id = pcall(C_Item.GetItemID, loc)
			if okID and type(id) == "number" and not isSecret(id) then
				out[#out + 1] = id
			end
		end
	end
	return out
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
-- TradeSkillMaster (optional price source, week 9, user pick 10; Providers/TSM.lua). Only its public addon
-- API: TSM_API.ToItemString(link) -> TSM's item string, and TSM_API.GetCustomPriceValue(priceString,
-- itemString) -> copper or nil. TSM_API raises an error on a name it does not have, so every read is
-- pcall'd (A.Resolve is). TSM offers no "prices changed" callback in that API: the price cache's 10-minute
-- age (Engine/Prices.lua) is what refreshes TSM prices. Only the price strings below are ever asked
-- (a share string cannot make SwagBag evaluate a custom formula).
---------------------------------------------------------------------------
A.TSM_PRICES = { "DBMarket", "DBMinBuyout", "DBRegionMarketAvg", "DBRegionSaleAvg" }
local TSM_PRICE_OK = {}
for _, name in ipairs(A.TSM_PRICES) do
	TSM_PRICE_OK[name] = true
end

local function tsm()
	local okR, api = pcall(A.Resolve, "TSM_API")
	if not okR or type(api) ~= "table" or isSecret(api) then
		return nil
	end
	local okF, toItem, value = pcall(function()
		return api.ToItemString, api.GetCustomPriceValue
	end)
	if okF and type(toItem) == "function" and type(value) == "function" then
		return { toItem = toItem, value = value }
	end
	return nil
end

-- Resolved when availability is asked (once per price-cache fill), as for Auctionator, or at the first price
-- asked before that (lazily, so a price never depends on the call order).
local tsmApi

function A.TSMAvailable()
	tsmApi = tsm()
	return tsmApi ~= nil
end

-- Copper per unit by one of A.TSM_PRICES, or nil (no price, not loaded, a secret link, an error, 0 or less).
function A.TSMPrice(link, priceString)
	tsmApi = tsmApi or tsm()
	local api = tsmApi
	if not api or type(link) ~= "string" or isSecret(link) or not TSM_PRICE_OK[priceString] then
		return nil
	end
	local okS, itemString = pcall(api.toItem, link)
	if not okS or type(itemString) ~= "string" or isSecret(itemString) then
		return nil
	end
	local ok, v = pcall(api.value, priceString, itemString)
	if ok and type(v) == "number" and not isSecret(v) and v == v and v > 0 and v < math.huge then
		return math.floor(v)
	end
	return nil
end

---------------------------------------------------------------------------
-- Masque (optional button skins, week 9, user pick 11; UI/Skins.lua). Only its public API:
-- LibStub("Masque", true) (silent: nil when Masque is not there), Masque:Group("SwagBag", name) and
-- group:AddButton(button, nil, "Item") (Masque finds the item button's own regions). One group per name, made
-- once. Every call is pcall'd: an error inside Masque is no skin, never an error. UI/Skins.lua calls this out
-- of combat only.
---------------------------------------------------------------------------
local masqueGroups = {}

local function masque()
	local okL, lib = pcall(A.Resolve, "LibStub")
	if not okL or (type(lib) ~= "table" and type(lib) ~= "function") or isSecret(lib) then
		return nil
	end
	local ok, msq = pcall(lib, "Masque", true)
	if ok and type(msq) == "table" and not isSecret(msq) then
		return msq
	end
	return nil
end

function A.MasqueAvailable()
	return masque() ~= nil
end

-- true when the button joined Masque's group of that name.
function A.MasqueAdd(groupName, button)
	local group = masqueGroups[groupName]
	if not group then
		local msq = masque()
		if not msq then
			return false
		end
		local ok, g = pcall(function()
			return msq:Group("SwagBag", groupName)
		end)
		if not ok or type(g) ~= "table" then
			return false
		end
		group = g
		masqueGroups[groupName] = g
	end
	return (pcall(function()
		group:AddButton(button, nil, "Item")
	end))
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

-- The folder name Syndicator loads under (ADDON_LOADED's argument): it may load mid-session (week 8).
A.SYNDICATOR_ADDON = "Syndicator"
function A.IsSyndicatorAddon(name)
	return name == A.SYNDICATOR_ADDON
end

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
-- fallback, a Mythic party dungeon with a keystone in the bags (check V5). false on a client without Mythic+.
function A.ChallengeModeActive()
	if not A.Has("keystones") then
		return false
	end
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
-- difficulty (check V7). info: an InstanceInfo() result (read again when nil). false on a client without Delves.
function A.InDelve(info)
	if not A.Has("delves") then
		return false
	end
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
-- foreverValue: the exact value expected on WoW Forever instead of value (A.CheckExpected).
---------------------------------------------------------------------------
A.CHECKS = {
	{ path = "C_Container.GetContainerNumSlots", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemInfo", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemCooldown", window = "bags", required = true },
	{ path = "C_Container.GetContainerNumFreeSlots", window = "bags", required = false },
	{ path = "C_Container.GetBagName", window = "bags", required = false },
	{ path = "C_Container.GetContainerItemEquipmentSetInfo", window = "bags", required = false },
	{ path = "C_Container.GetContainerItemQuestInfo", window = "bags", required = false },
	{ path = "C_Container.SortBags", window = "bags", required = false },
	{ path = "C_Container.SortBank", window = "bank", required = false },
	{ path = "C_Container.UseContainerItem", window = "bags", required = false },
	{ path = "C_Container.PickupContainerItem", window = "bags", required = false },
	{ path = "CanMerchantRepair", window = "bags", required = false },
	{ path = "GetRepairAllCost", window = "bags", required = false },
	{ path = "RepairAllItems", window = "bags", required = false },
	{ path = "CanGuildBankRepair", window = "bags", required = false },
	{ path = "GetGuildBankWithdrawMoney", window = "bags", required = false },
	{ path = "GetNumBuybackItems", window = "bags", required = false },
	{ path = "IsShiftKeyDown", window = "bags", required = false },
	{ path = "GetBuybackItemLink", window = "bags", required = false },
	{ path = "GetGuildBankMoney", window = "bags", required = false },
	{ path = "GetCursorInfo", window = "bags", required = false },
	{ path = "ClearCursor", window = "bags", required = false },
	{ path = "SpellIsTargeting", window = "bags", required = false },
	{ path = "StaticPopup_FindVisible", window = "bags", required = false },
	{ path = "C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex", window = "bags", required = false },
	{ path = "C_Item.GetItemID", window = "bags", required = false },
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
	{ path = "C_TransmogCollection.GetItemInfo", window = "bags", required = false },
	{ path = "C_TransmogCollection.AccountCanCollectSource", window = "bags", required = false },
	{ path = "C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance", window = "bags", required = false },
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
	{ path = "Enum.BagIndex.AccountBankTab_1", value = 12, foreverValue = 15, window = "bank", required = true },
	{ path = "Enum.BankType.Character", value = 0, window = "bank", required = true },
	{ path = "Enum.BankType.Account", value = 2, window = "bank", required = true },
	{ path = "C_Bank.FetchPurchasedBankTabIDs", window = "bank", required = true },
	{ path = "C_Bank.FetchPurchasedBankTabData", window = "bank", required = false },
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
	{ path = "C_Bank.FetchDepositedMoney", window = "bank", required = false },
	{ path = "C_Bank.DoesBankTypeSupportMoneyTransfer", window = "bank", required = false },
	{ path = "C_Bank.CanDepositMoney", window = "bank", required = false },
	{ path = "C_Bank.CanWithdrawMoney", window = "bank", required = false },
	{ path = "StaticPopup_Show", window = "bank", required = false },
	{ path = "StaticPopupDialogs.BANK_MONEY_DEPOSIT", window = "bank", required = false },
	{ path = "StaticPopupDialogs.BANK_MONEY_WITHDRAW", window = "bank", required = false },
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

-- The exact value a check expects on this client: foreverValue on WoW Forever when it has one, else value
-- (nil for a presence-only check). Keeps the flavor read inside the Adapter for Core/Checks.lua.
function A.CheckExpected(c)
	if c.foreverValue ~= nil and A.Flavor() == "forever" then
		return c.foreverValue
	end
	return c.value
end
