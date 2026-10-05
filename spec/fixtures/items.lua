-- Shared item fixtures (Midnight-squished item levels). Install(m) adds them to a
-- mock Adapter; class/subclass numbers come from the real Adapter constants.
local Fixtures = {}

Fixtures.HEALING_POTION = 211880
Fixtures.FLASK = 212283
Fixtures.HERB = 210796
Fixtures.ORE = 210930
Fixtures.BOE_RING = 225001
Fixtures.SOULBOUND_HELM = 225002
Fixtures.JUNK = 156654
Fixtures.KEYSTONE = 180653
Fixtures.PET_CAGE = 82800
Fixtures.TOY = 188680
Fixtures.QUEST = 230001
Fixtures.UNLOADED = 239999
Fixtures.BAG = 194017

function Fixtures.Install(m)
	local C, CS, TS, MS = m.ITEM_CLASS, m.CONSUMABLE_SUB, m.TRADEGOODS_SUB, m.MISC_SUB
	m.AddItem(Fixtures.HEALING_POTION, { name = "Algari Healing Potion", classID = C.Consumable, subclassID = CS.Potion,
		quality = 1, ilvl = 300, reqLevel = 71, maxStack = 20, bind = "none", usable = true })
	m.AddItem(Fixtures.FLASK, { name = "Flask of Alchemical Chaos", classID = C.Consumable, subclassID = CS.Flask,
		quality = 3, ilvl = 300, reqLevel = 71, maxStack = 20, bind = "none", usable = true })
	m.AddItem(Fixtures.HERB, { name = "Mycobloom", classID = C.Tradegoods, subclassID = TS.Herb, quality = 1,
		ilvl = 1, maxStack = 1000, bind = "none", isCraftingReagent = true })
	m.AddItem(Fixtures.ORE, { name = "Bismuth", classID = C.Tradegoods, subclassID = TS.MetalStone, quality = 1,
		ilvl = 1, maxStack = 1000, bind = "none", isCraftingReagent = true })
	m.AddItem(Fixtures.BOE_RING, { name = "Band of the Fallen", classID = C.Armor, subclassID = 0,
		equipLoc = "INVTYPE_FINGER", quality = 4, ilvl = 285, reqLevel = 80, maxStack = 1, bind = "equip" })
	m.AddItem(Fixtures.SOULBOUND_HELM, { name = "Helm of Tests", classID = C.Armor, subclassID = 4,
		equipLoc = "INVTYPE_HEAD", quality = 3, ilvl = 270, reqLevel = 80, maxStack = 1, bind = "pickup" })
	m.AddItem(Fixtures.JUNK, { name = "Broken Tooth", classID = C.Miscellaneous, subclassID = MS.Junk, quality = 0,
		ilvl = 1, maxStack = 200, bind = "none" })
	m.AddItem(Fixtures.KEYSTONE, { name = "Mythic Keystone", classID = C.Reagent, subclassID = 1, quality = 4,
		ilvl = 1, maxStack = 1, bind = "pickup" })
	m.AddItem(Fixtures.PET_CAGE, { name = "Pet Cage", classID = C.Battlepet, subclassID = 0, quality = 3,
		ilvl = 1, maxStack = 1, bind = "none" })
	m.AddItem(Fixtures.TOY, { name = "Toy Train", classID = C.Miscellaneous, subclassID = 4, quality = 3,
		ilvl = 1, maxStack = 1, bind = "pickup", toy = true })
	m.AddItem(Fixtures.QUEST, { name = "Strange Letter", classID = C.Questitem, subclassID = 0, quality = 1,
		ilvl = 1, maxStack = 1, bind = "quest" })
	m.AddItem(Fixtures.UNLOADED, { classID = C.Armor, subclassID = 0, equipLoc = "INVTYPE_CHEST", pending = true })
	m.AddItem(Fixtures.BAG, { name = "Wildercloth Bag", classID = C.Container, subclassID = 0, equipLoc = "INVTYPE_BAG",
		quality = 1, ilvl = 1, maxStack = 1, bind = "equip" })
end

-- A small backpack: 16 slots, 6 items. The helm is in no equipment set (week 7: a set piece has its
-- own section); a test that needs one puts { inSet = true } on its own slot.
function Fixtures.SmallBags(m)
	Fixtures.Install(m)
	m.SetBagSize(0, 16)
	m.Put(0, 1, Fixtures.HEALING_POTION, 5)
	m.Put(0, 2, Fixtures.FLASK, 2, { onCooldown = true })
	m.Put(0, 3, Fixtures.BOE_RING, 1, { upgrade = true, link = "item:225001::upgradable" })
	m.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true })
	m.Put(0, 5, Fixtures.KEYSTONE, 1, { isBound = true, link = "|cffa335ee|Hkeystone:180653:503:12:10:9:0:0|h[Keystone: Ara-Kara]|h|r" })
	m.Put(0, 6, Fixtures.JUNK, 3)
end

-- Hotfix 0.11.1: after SB_LOGIN (or Inventory.ScanAll), the world loads and the bags settle; only then do items
-- arrive (Inventory's header). A whole number of seconds keeps later timer sums exact.
function Fixtures.Settle(SB)
	SB.eventFrame:Fire("PLAYER_ENTERING_WORLD", true, false)
	SB.Adapter.Advance(SB.Inventory.SETTLE_QUIET + 1)
end

return Fixtures
