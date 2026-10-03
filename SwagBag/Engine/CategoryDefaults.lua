-- SwagBag default categories (spec 7.6, first-run set). Pure data.
-- Built-ins are NEVER written to SavedVariables: a user's change to one is stored as a
-- diff in SwagBagDB.userEdits[id] (spec 8.5), so a new default set in an update applies
-- cleanly and "reset to default" just removes the diff.
--   priority      higher wins when several rules match (ties: lower id first)
--   displayOrder  section order on screen (separate from priority, spec AC4.2)
--   itemList      manual lists, keyed by itemID: include wins over every rule
--   setting       the category only exists while that Config setting is true
--   fallback      the category for items no rule claims ("Other")
--   after         a built-in added in an update joins a SAVED category order right after this one
--                 (not at the end); without a saved order displayOrder places it as usual
-- New and Free are not categories: the layout adds them (spec 7.6, 4.3).
-- Queries use only registered keywords except Fish & Lures, which matches item names
-- ("fish", "lure", "bait"); users file other fish by dragging one onto the header.
local _, SB = ...

local L = SB.L

SB.CategoryDefaults = {
	{ id = "c_keystone", name = L.CAT_KEYSTONE, query = "keystone | crest", priority = 95, displayOrder = 10 },
	{ id = "c_consumables", name = L.CAT_CONSUMABLES, query = "consumable", priority = 65, displayOrder = 20 },
	{ id = "c_gear", name = L.CAT_GEAR, query = "gear", priority = 70, displayOrder = 30 },
	-- Week 7 (user pick 1): items in any of the character's equipment sets (the "equipped" keyword,
	-- Items.inEquipmentSet). Priority 92: above Junk (90), BoE gear (75) and Gear (70), so a set piece
	-- is never filed as junk or as gear to sell; below Keystone & Crests (95) and Reagents (100).
	{ id = "c_sets", name = L.CAT_SETS, query = "equipped", priority = 92, displayOrder = 35, after = "c_gear" },
	{ id = "c_boe", name = L.CAT_BOE, query = "gear & boe", priority = 75, displayOrder = 40 },
	-- Week 6 (user request 2): gear that is warbound until equipped, next to BoE gear. Above Gear (70)
	-- so WuE gear lands here; "wue" and "boe" never match the same item (Engine/Keywords.lua).
	{ id = "c_wue", name = L.CAT_WUE, query = "gear & wue", priority = 74, displayOrder = 45, after = "c_boe" },
	{ id = "c_tradegoods", name = L.CAT_TRADEGOODS, query = "tradegoods | reagent", priority = 50, displayOrder = 50 },
	{ id = "c_herbs", name = L.CAT_HERBS, query = "herb", priority = 55, displayOrder = 60 },
	{ id = "c_ore", name = L.CAT_ORE, query = "ore", priority = 54, displayOrder = 70 },
	{ id = "c_leathercloth", name = L.CAT_LEATHERCLOTH, query = "leather | cloth", priority = 53, displayOrder = 80 },
	{ id = "c_enchanting", name = L.CAT_ENCHANTING, query = "enchanting", priority = 52, displayOrder = 90 },
	{ id = "c_cooking", name = L.CAT_COOKING, query = "cooking", priority = 51, displayOrder = 100 },
	{ id = "c_fish", name = L.CAT_FISH, query = "fish | lure | bait", priority = 60, displayOrder = 110 },
	{ id = "c_quest", name = L.CAT_QUEST, query = "questitem", priority = 85, displayOrder = 120 },
	{ id = "c_housing", name = L.CAT_HOUSING, query = "housing", priority = 45, displayOrder = 130 },
	{ id = "c_collect", name = L.CAT_COLLECT, query = "pet | mount | toy", priority = 40, displayOrder = 140 },
	{ id = "c_tools", name = L.CAT_TOOLS, query = "profession tool | profession gear", priority = 80, displayOrder = 150,
		-- Hearthstone, Dalaran Hearthstone, Garrison Hearthstone (not toys, no keyword)
		itemList = { include = { [6948] = true, [140192] = true, [110560] = true } } },
	{ id = "c_reagents", name = L.CAT_REAGENTS, query = "reagentbag", priority = 100, displayOrder = 160,
		setting = "bags.reagentSeparate" },
	{ id = "c_junk", name = L.CAT_JUNK, query = "junk", priority = 90, displayOrder = 170 },
	{ id = "c_other", name = L.CAT_OTHER, query = "", priority = 0, displayOrder = 180, fallback = true },
}
