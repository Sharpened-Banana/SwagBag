local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Snapshots.lua",
}

local PET = "|cff0070dd|Hbattlepet:1387:25:3:1725:276:244:0000000000000000:82800|h[Lil' Tarecgosa]|h|r"
local KEY = "|cffa335ee|Hkeystone:180653:503:12:10:9:0:0|h[Keystone: Ara-Kara]|h|r"

describe("Snapshots (spec 8.3 format, 5.7 timing, 8.4 budget)", function()
	local SB, A, Snap
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Snap = SB.Snapshots
		Fixtures.Install(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(0, 8)
		A.Put(0, 1, Fixtures.HEALING_POTION, 5, { link = "|cffffffff|Hitem:211880::::::::80:::::|h[Algari Healing Potion]|h|r" })
		A.Put(0, 7, Fixtures.PET_CAGE, 1, { link = PET })
		A.Put(0, 8, Fixtures.KEYSTONE, 1, { link = KEY })
	end)

	local function bankVisit()
		A.SetBagSize(6, 4)
		A.SetBagSize(12, 4)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(12, 1, Fixtures.ORE, 10)
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	it("one string per container: slot:link;count lines in slot order, links verbatim, empties skipped", function()
		local c = Snap.Serialize({ [1] = { link = "item:1", count = 5 }, [3] = { link = PET, count = 1 } }, 4)
		assert.same({ size = 4, s = "1:item:1;5\n3:" .. PET .. ";1\n" }, c)
	end)

	it("round-trips caged pets, keystones and a link that contains a semicolon", function()
		local odd = "|Hitem:1|h[Odd;Name]|h"
		local slots = { [2] = { link = PET, count = 1 }, [5] = { link = KEY, count = 1 }, [9] = { link = odd, count = 20 } }
		assert.same(slots, Snap.Deserialize(Snap.Serialize(slots, 10)))
		assert.same({}, Snap.Deserialize({ s = "garbage\n12:x\n" }), "damaged lines are skipped")
		assert.same({}, Snap.Deserialize("not a table"))
	end)

	it("logging out saves the bags snapshot with the character's class, level and last-seen time", function()
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		local c = SB.Config.db.chars["Swagger-Argent Dawn"]
		assert.same({ "MAGE", 90, A.epoch }, { c.class, c.level, c.lastSeen })
		assert.equal(1, c.bags.v)
		assert.equal(A.epoch, c.bags.at)
		assert.equal(8, c.bags.containers[0].size)
		assert.equal(PET, Snap.Deserialize(c.bags.containers[0])[7].link)
		assert.is_nil(c.bank, "no bank without a banker visit")
	end)

	it("a bag update saves the bags 5 s after the last one, not before", function()
		SB.Inventory.ScanAll()
		A.Put(0, 2, Fixtures.FLASK, 1)
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(4)
		A.Put(0, 3, Fixtures.JUNK, 1)
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(4.9)
		assert.is_nil(SB.Config.db.chars, "debounced")
		A.Advance(0.2)
		local slots = Snap.Deserialize(SB.Config.db.chars["Swagger-Argent Dawn"].bags.containers[0])
		assert.equal("item:" .. Fixtures.JUNK, slots[3].link)
	end)

	it("a bank visit saves the character bank and the warband bank 0.3 s after opening", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.Advance(0.2)
		assert.is_nil(SB.Config.db.chars)
		A.Advance(0.2)
		local c = SB.Config.db.chars["Swagger-Argent Dawn"]
		assert.equal("item:" .. Fixtures.HERB, Snap.Deserialize(c.bank.containers[6])[2].link)
		assert.equal(4, c.bank.containers[6].size)
		assert.equal("item:" .. Fixtures.ORE, Snap.Deserialize(SB.Config.db.warband.containers[12])[1].link)
	end)

	it("bank updates during the visit save again (1 s debounce); the close saves the last state", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.Advance(0.5)
		A.Put(6, 3, Fixtures.FLASK, 2)
		SB.eventFrame:Fire("BAG_UPDATE", 6)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(1.1)
		assert.equal(2, Snap.Deserialize(SB.Config.db.chars["Swagger-Argent Dawn"].bank.containers[6])[3].count)
		A.Put(6, 4, Fixtures.JUNK, 1)
		SB.eventFrame:Fire("BAG_UPDATE", 6)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.truthy(Snap.Deserialize(SB.Config.db.chars["Swagger-Argent Dawn"].bank.containers[6])[4])
	end)

	it("away from a banker, bank-bag events never overwrite the bank snapshot", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.Advance(0.5)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		local saved = SB.Config.db.chars["Swagger-Argent Dawn"].bank
		A.SetBagSize(6, 0) -- the client reads 0 slots away from a banker
		SB.eventFrame:Fire("BAG_UPDATE", 6)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(10)
		assert.equal(saved, SB.Config.db.chars["Swagger-Argent Dawn"].bank)
		assert.equal(4, saved.containers[6].size)
	end)

	it("nothing is written in combat; the save happens when combat ends (spec 9)", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.combat = true
		A.Advance(0.5)
		assert.is_nil(SB.Config.db.chars)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.truthy(SB.Config.db.chars["Swagger-Argent Dawn"].bank)
	end)

	it("a newer (read-only) schema is never written", function()
		SB.Config.readOnly = true
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		bankVisit()
		A.Advance(1)
		assert.is_nil(SB.Config.db.chars)
	end)

	it("damaged saved snapshot tables never break a save", function()
		SB.Config.db.chars = "oops"
		SB.Config.db.warband = 7
		SB.Config.db.guilds = { ["X-Y"] = "bad" }
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		assert.truthy(SB.Config.db.chars["Swagger-Argent Dawn"].bags)
		assert.is_nil(SB.Config.db.warband)
		assert.equal(0, #SB.ErrorTrap.Recent())
		assert.same({ 1, 0 }, { Snap.Count() })
	end)

	it("over 1.5 MB, other characters' bank snapshots go first, seen longest ago first, ties by name", function()
		local big = { v = 1, at = 1, containers = { [6] = { size = 98, s = string.rep("x", 400 * 1024) } } }
		SB.Config.db.chars = {
			-- written in an order that disagrees with both lastSeen and name order
			["Zed-Realm"] = { lastSeen = 100, bank = big },
			["Amy-Realm"] = { lastSeen = 300, bank = big },
			["Bob-Realm"] = { lastSeen = 100, bank = big },
			["Cat-Realm"] = { lastSeen = 200, bank = big },
			["Swagger-Argent Dawn"] = { lastSeen = 1, bank = big },
		}
		local dropped = Snap.Enforce()
		assert.same({ "Bob-Realm", "Zed-Realm" }, dropped, "lastSeen 100 twice: Bob before Zed")
		assert.truthy(SB.Config.db.chars["Swagger-Argent Dawn"].bank, "the current character is never trimmed")
		assert.truthy(SB.Config.db.chars["Cat-Realm"].bank)
		assert.truthy(Snap.Bytes() <= Snap.HARD_CAP)
		assert.same({ "Saved bank snapshots went over 1.5 MB; dropped the oldest: Bob-Realm, Zed-Realm." }, A.Lines())
		SB.Config.db.chars["Amy-Realm"].bags = { v = 1, containers = { [0] = { size = 1, s = string.rep("y", 600 * 1024) } } }
		Snap.Enforce()
		assert.equal(1, #A.Lines(), "one chat line per session")
	end)

	it("a guild snapshot is saved per guild with its tab names", function()
		Snap.SaveGuild("Tidewatch-Argent Dawn", { [2] = { name = "Gear", slots = { [5] = { link = "item:1", count = 1 } } } })
		local g = SB.Config.db.guilds["Tidewatch-Argent Dawn"]
		assert.equal("Gear", g.tabs[2])
		assert.equal(A.epoch, g.lastSeen)
		assert.equal(98, g.snapshot.containers[2].size)
		assert.equal("5:item:1;1\n", g.snapshot.containers[2].s)
		assert.falsy(Snap.SaveGuild(nil, {}), "no guild, nothing saved")
	end)

	it("/swagbag snapshot prints how old each snapshot is", function()
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		A.Advance(3 * 3600)
		SB.Slash.Dispatch("snapshot")
		assert.same({ "Bags: 3 h ago", "Bank: not saved yet (visit a banker)", "Warband bank: not saved yet (visit a banker)",
			"Saved: 1 characters, 0 KB in all" }, A.Lines())
		assert.same({ "just now", "59 min ago", "1 h ago", "2 days ago" },
			{ Snap.Age(59), Snap.Age(3599), Snap.Age(3600), Snap.Age(2 * 86400 + 5) })
	end)

	it("bank close in combat writes what the bank held AT CLOSE, not what the model holds later (W3-9)", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.combat = true
		A.Advance(0.5)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.is_nil(SB.Config.db.chars, "nothing written in combat")
		-- before combat ends the inventory model's bank slots change, then clear
		A.Put(6, 3, Fixtures.FLASK, 9)
		A.SetBagSize(6, 4)
		SB.Inventory.ScanBag(6)
		SB.Inventory.ScanBag(12)
		A.SetBagSize(6, 0)
		A.SetBagSize(12, 0)
		SB.Inventory.ScanBag(6)
		SB.Inventory.ScanBag(12)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		local c = SB.Config.db.chars["Swagger-Argent Dawn"]
		assert.equal(4, c.bank.containers[6].size)
		assert.same({ [2] = { link = "item:" .. Fixtures.HERB, count = 20 } }, Snap.Deserialize(c.bank.containers[6]))
		assert.same({ [1] = { link = "item:" .. Fixtures.ORE, count = 10 } }, Snap.Deserialize(SB.Config.db.warband.containers[12]))
	end)

	it("two captures of one kind in combat: the newest wins (keyed per kind)", function()
		SB.Inventory.ScanAll()
		A.combat = true
		Snap.Save("bags")
		A.Put(0, 2, Fixtures.FLASK, 3)
		SB.Inventory.ScanBag(0)
		Snap.Save("bags")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(3, Snap.Deserialize(SB.Config.db.chars["Swagger-Argent Dawn"].bags.containers[0])[2].count)
	end)

	it("a bank timer that fires after the close does not save a blanked model", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.Advance(0.1)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		A.SetBagSize(6, 0)
		SB.Inventory.ScanBag(6)
		A.Advance(2)
		assert.equal(4, SB.Config.db.chars["Swagger-Argent Dawn"].bank.containers[6].size)
	end)
end)
