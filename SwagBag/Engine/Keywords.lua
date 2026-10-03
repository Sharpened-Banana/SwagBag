-- SwagBag v1.0 keyword table, week-1 families (spec 7.3): type, slot, quality,
-- binding, numeric (ilvl, lvl/level, gear, count, stack, tab), state, location.
-- Every keyword reads ONLY the item record from Engine/Items.lua.
-- Aliases include Syndicator's English spellings used by published Baganator category
-- strings (desk spike F, docs/research/2026-10-syndicator-grammar-diff.md).
-- Not yet registered (need later modules): expansion, crafting quality, collection.
local _, SB = ...

local K = {}
SB.Keywords = K

local function has(list)
	local set = {}
	for _, v in ipairs(list) do
		set[v] = true
	end
	return set
end

function K.RegisterAll()
	local Q, A = SB.Query, SB.Adapter
	local C, CS, TS, MS, AS = A.ITEM_CLASS, A.CONSUMABLE_SUB, A.TRADEGOODS_SUB, A.MISC_SUB, A.ARMOR_SUB

	local function kw(name, class, eval, aliases)
		Q.RegisterKeyword({ name = name, class = class, eval = eval, aliases = aliases })
	end
	local function num(name, class, value, aliases)
		Q.RegisterKeyword({ name = name, class = class, value = value, aliases = aliases })
	end
	local function classIs(id)
		return function(r)
			return id ~= nil and r.classID == id
		end
	end
	local function subIs(classID, subID)
		return function(r)
			return r.classID == classID and subID ~= nil and r.subclassID == subID
		end
	end
	local function isGear(r)
		return r.classID == C.Armor or r.classID == C.Weapon
	end
	-- Shared by `gear<N` and `ilvl`: false = not gear (no item level), nil = still loading.
	local function itemLevel(r)
		if not isGear(r) then
			return false
		end
		return r.ilvl
	end

	-- Type (static: item class/subclass from the instant item info) -----------
	kw("armor", "static", classIs(C.Armor))
	kw("weapon", "static", classIs(C.Weapon))
	Q.RegisterKeyword({
		name = "gear",
		class = "instance",
		eval = isGear,
		value = itemLevel, -- gear<210: equippable gear under an item level
		aliases = { "equipment" },
	})
	kw("consumable", "static", classIs(C.Consumable))
	kw("potion", "static", subIs(C.Consumable, CS.Potion))
	kw("flask", "static", subIs(C.Consumable, CS.Flask))
	kw("food", "static", subIs(C.Consumable, CS.FoodDrink), { "drink" })
	kw("elixir", "static", subIs(C.Consumable, CS.Elixir))
	kw("rune", "static", subIs(C.Consumable, CS.VantusRune))
	kw("reagent", "static", function(r)
		if r.classID == C.Reagent then
			return not r.isKeystone
		end
		if r.pending then
			return nil
		end
		return r.isCraftingReagent == true
	end)
	kw("tradegoods", "static", classIs(C.Tradegoods), { "trade goods", "tradeskill" })
	kw("herb", "static", subIs(C.Tradegoods, TS.Herb))
	kw("ore", "static", subIs(C.Tradegoods, TS.MetalStone))
	kw("leather", "static", subIs(C.Tradegoods, TS.Leather))
	kw("cloth", "static", subIs(C.Tradegoods, TS.Cloth))
	kw("enchanting", "static", subIs(C.Tradegoods, TS.Enchanting))
	kw("cooking", "static", subIs(C.Tradegoods, TS.Cooking))
	kw("gem", "static", classIs(C.Gem))
	kw("recipe", "static", classIs(C.Recipe))
	kw("questitem", "static", function(r)
		return r.isQuestItem == true
	end, { "quest" })
	kw("key", "static", classIs(C.Key))
	kw("keystone", "instance", function(r)
		return r.isKeystone == true
	end)
	-- Crests and other upgrade currency items (spec 7.3): the season's item IDs, else a name
	-- word from the data file (Engine/Crests.lua). Gear is never a crest. A loading item with an
	-- unknown ID is "not a crest" rather than "unknown": the rule sits in Keystone & Crests
	-- (priority 95), and an unknown there would hold every loading item in New (spec 7.7 D3).
	kw("crest", "static", function(r)
		local list = SB.Crests or { ids = {}, words = {} }
		if list.ids[r.itemID] then
			return true
		end
		if isGear(r) or r.name == nil then
			return false
		end
		local name = r.name:lower()
		for _, word in ipairs(list.words) do
			if name:find(word, 1, true) then
				return true
			end
		end
		return false
	end, { "upgrade currency" })
	kw("pet", "instance", function(r)
		return r.isCagedPet == true or r.classID == C.Battlepet
			or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet)
	end, { "battle pet", "battle pets" })
	kw("mount", "static", subIs(C.Miscellaneous, MS.Mount))
	kw("toy", "static", function(r)
		return r.isToy == true
	end)
	kw("housing", "static", classIs(C.Housing), { "decor" })
	kw("cosmetic", "static", subIs(C.Armor, AS.Cosmetic))
	kw("container", "static", classIs(C.Container))
	kw("miscellaneous", "static", classIs(C.Miscellaneous))
	kw("junk", "static", function(r)
		if r.quality == nil then
			return nil
		end
		return r.quality == 0
	end, { "trash" })
	kw("profession tool", "static", function(r)
		return r.equipLoc == "INVTYPE_PROFESSION_TOOL"
	end)
	kw("profession gear", "static", function(r)
		return r.equipLoc == "INVTYPE_PROFESSION_GEAR"
	end, { "profession equipment" })
	kw("profession", "static", classIs(C.Profession))

	-- Slot (static, equip location) -------------------------------------------
	local SLOTS = {
		head = { "INVTYPE_HEAD" }, neck = { "INVTYPE_NECK" }, shoulder = { "INVTYPE_SHOULDER" },
		back = { "INVTYPE_CLOAK" }, chest = { "INVTYPE_CHEST", "INVTYPE_ROBE" }, wrist = { "INVTYPE_WRIST" },
		hands = { "INVTYPE_HAND" }, waist = { "INVTYPE_WAIST" }, legs = { "INVTYPE_LEGS" },
		feet = { "INVTYPE_FEET" }, finger = { "INVTYPE_FINGER" }, trinket = { "INVTYPE_TRINKET" },
		mainhand = { "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPON" },
		offhand = { "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" },
		twohand = { "INVTYPE_2HWEAPON" }, ranged = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" },
		shirt = { "INVTYPE_BODY" }, tabard = { "INVTYPE_TABARD" }, bag = { "INVTYPE_BAG" },
		["one-hand"] = { "INVTYPE_WEAPON" },
	}
	local SLOT_ALIASES = {
		head = { "helm" }, back = { "cloak" }, wrist = { "bracers" }, hands = { "gloves" }, waist = { "belt" },
		feet = { "boots" }, mainhand = { "main hand" }, offhand = { "off-hand", "off hand", "held in off-hand" },
		twohand = { "two-hand" },
	}
	for name, locs in pairs(SLOTS) do
		local set = has(locs)
		kw(name, "static", function(r)
			return set[r.equipLoc] == true
		end, SLOT_ALIASES[name])
	end

	-- Quality (instance, from the link) ---------------------------------------
	local QUALITY = {
		{ "poor", 0, { "gray", "grey" } }, { "common", 1, { "white" } }, { "uncommon", 2, { "green" } },
		{ "rare", 3, { "blue" } }, { "epic", 4, { "purple" } }, { "legendary", 5, { "orange" } },
		{ "artifact", 6 }, { "heirloom", 7 },
	}
	for _, q in ipairs(QUALITY) do
		local value = q[2]
		kw(q[1], "instance", function(r)
			if r.quality == nil then
				return nil
			end
			return r.quality == value
		end, q[3])
	end

	-- Binding (instance) -------------------------------------------------------
	local ACCOUNT = has({ "account", "warbound" })
	-- A saved item's bind that cannot be known (record.bindUnknown, ruling W5-10) matches no bind
	-- keyword: false, not nil, so it is still categorised (never left waiting in New).
	local function bindKnown(test)
		return function(r)
			if r.bindUnknown then
				return false
			end
			if r.bind == nil then
				return nil
			end
			return test(r)
		end
	end
	kw("boe", "instance", bindKnown(function(r)
		return not r.isBound and not r.isWUE and r.bind == "equip"
	end), { "bwe" })
	kw("bop", "instance", bindKnown(function(r)
		return r.bind == "pickup"
	end))
	kw("warbound", "instance", bindKnown(function(r)
		return ACCOUNT[r.bind] == true or (r.isWUE == true and not r.isBound)
	end), { "boa", "account bound" })
	kw("wue", "instance", function(r)
		return r.isWUE == true or (r.bind == "wue" and not r.isBound)
	end, { "warbound until equipped" })
	kw("bound", "instance", function(r)
		return r.isBound == true
	end)
	kw("soulbound", "instance", bindKnown(function(r)
		return r.isBound == true and not ACCOUNT[r.bind]
	end))
	-- Tradeable = can be given to another player / listed on the AH: not bound, not
	-- warbound-until-equipped, not account/warbound, not a quest item.
	kw("tradeable", "instance", function(r)
		if r.isBound or r.isWUE or r.isQuestItem or r.bindUnknown then
			return false
		end
		if r.bind == nil then
			return nil
		end
		return not (ACCOUNT[r.bind] or r.bind == "wue" or r.bind == "quest")
	end, { "tradeable loot", "tradable loot" })

	-- Numeric -------------------------------------------------------------------
	num("ilvl", "instance", itemLevel)
	num("level", "instance", function(r)
		if r.pending then
			return nil
		end
		return r.reqLevel or false
	end, { "lvl" })
	num("count", "volatile", function(r)
		return r.count
	end)
	num("stack", "volatile", function(r)
		if r.pending then
			return nil
		end
		return r.maxStack or false
	end)
	num("tab", "volatile", function(r)
		return r.tab or false
	end)
	-- value>50: price per unit in gold (spec 7.3), from Engine/Prices.lua (AH, else vendor).
	num("value", "volatile", function(r)
		if r.pending then
			return nil
		end
		local copper = SB.Prices and SB.Prices.Value(r.link, r.itemID, SB.Prices.Bound(r))
		return copper and copper / 10000 or false
	end, { "gold" })

	-- State (volatile) ---------------------------------------------------------
	local function flag(field)
		return function(r)
			return r[field] == true
		end
	end
	kw("new", "volatile", flag("isNew"))
	-- Week 7 (user pick 5): `locked` is the user's own lock (Engine/Locks.lua). The client's lock on an
	-- item being moved, traded or sold right now (spec 7.3's old `locked`) is `inuse`.
	kw("locked", "volatile", function(r)
		return SB.Locks ~= nil and SB.Locks.Has(r.itemID)
	end)
	kw("inuse", "volatile", flag("isLocked"))
	-- Week 7 (user pick 9, spec 7.3 "uncollected"): an appearance, toy, mount or pet the account lacks.
	kw("uncollected", "volatile", function(r)
		return SB.Collections ~= nil and SB.Collections.Uncollected(r) ~= nil
	end)
	kw("cooldown", "volatile", flag("onCooldown"))
	kw("usable", "volatile", flag("isUsable"))
	kw("equipped", "volatile", flag("inEquipmentSet"))
	kw("upgrade", "volatile", flag("hasUpgradeTrack"))
	kw("partial", "volatile", function(r)
		if r.pending then
			return nil
		end
		local max = r.maxStack
		if max == nil or r.count == nil then
			return nil
		end
		return max > 1 and r.count < max
	end)

	-- Location (volatile, slot-bound) -----------------------------------------
	local BAGS = has({ "backpack", "bags", "reagentbag" })
	kw("bags", "volatile", function(r)
		return BAGS[r.location] == true
	end)
	kw("backpack", "volatile", function(r)
		return r.location == "backpack"
	end)
	kw("reagentbag", "volatile", function(r)
		return r.location == "reagentbag"
	end)
	kw("bank", "volatile", function(r)
		return r.location == "bank"
	end)
	kw("warband", "volatile", function(r)
		return r.location == "warband"
	end)
end

K.RegisterAll()
