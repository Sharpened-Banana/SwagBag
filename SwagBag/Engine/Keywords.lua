-- SwagBag v1.0 keyword table, week-1 families (spec 7.3): type, slot, quality,
-- binding, numeric (ilvl, lvl/level, gear, count, stack, tab), state, location.
-- Every keyword reads ONLY the item record from Engine/Items.lua.
-- Not yet registered (need later modules): expansion, gold/value, crafting quality,
-- collection, crest / upgrade currency.
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
	})
	kw("consumable", "static", classIs(C.Consumable))
	kw("potion", "static", subIs(C.Consumable, CS.Potion))
	kw("flask", "static", subIs(C.Consumable, CS.Flask))
	kw("food", "static", subIs(C.Consumable, CS.FoodDrink), { "drink" })
	kw("elixir", "static", subIs(C.Consumable, CS.Elixir))
	kw("rune", "static", subIs(C.Consumable, CS.VantusRune))
	kw("reagent", "static", function(r)
		if r.classID == C.Reagent then
			return true
		end
		if r.pending then
			return nil
		end
		return r.isCraftingReagent == true
	end)
	kw("tradegoods", "static", classIs(C.Tradegoods), { "trade goods" })
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
	kw("pet", "instance", function(r)
		return r.isCagedPet == true or r.classID == C.Battlepet
			or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet)
	end)
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
	end)
	kw("profession tool", "static", function(r)
		return r.equipLoc == "INVTYPE_PROFESSION_TOOL"
	end)
	kw("profession gear", "static", function(r)
		return r.equipLoc == "INVTYPE_PROFESSION_GEAR"
	end)

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
	}
	for name, locs in pairs(SLOTS) do
		local set = has(locs)
		kw(name, "static", function(r)
			return set[r.equipLoc] == true
		end)
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
	local ACCOUNT = has({ "account", "warbound", "wue" })
	local function bindKnown(test)
		return function(r)
			if r.bind == nil then
				return nil
			end
			return test(r)
		end
	end
	kw("boe", "instance", bindKnown(function(r)
		return not r.isBound and not r.isWUE and r.bind == "equip"
	end))
	kw("bop", "instance", bindKnown(function(r)
		return r.bind == "pickup"
	end))
	kw("warbound", "instance", bindKnown(function(r)
		return ACCOUNT[r.bind] == true or r.isWUE == true
	end), { "boa" })
	kw("wue", "instance", function(r)
		return r.isWUE == true or (r.bind == "wue" and not r.isBound)
	end)
	kw("bound", "instance", function(r)
		return r.isBound == true
	end)
	kw("soulbound", "instance", bindKnown(function(r)
		return r.isBound == true and not ACCOUNT[r.bind]
	end))
	kw("tradeable", "instance", function(r)
		return not r.isBound
	end)

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

	-- State (volatile) ---------------------------------------------------------
	local function flag(field)
		return function(r)
			return r[field] == true
		end
	end
	kw("new", "volatile", flag("isNew"))
	kw("locked", "volatile", flag("isLocked"))
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
