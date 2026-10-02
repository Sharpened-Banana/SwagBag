-- luacheck: ignore 122
-- The low-consumables warning (spec 6.6, F11; check V11): counting, the three triggers, the
-- 60 s rate limit, the watch list (defaults, edits, read-only, damaged saved data), and
-- /swagbag consumables.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Crests.lua", "SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Focus.lua",
	"SwagBag/Engine/FocusData.lua", "SwagBag/Engine/Signals.lua", "SwagBag/Engine/Consumables.lua",
}

describe("Consumables", function()
	local SB, A, C
	-- %s is as strict as WoW's Lua 5.1 here too: spec/runner.lua installs spec/helpers/format51.lua (W4-18).
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- 5 healing potions, 2 flasks, no food; a keystone
		C = SB.Consumables
		SB.Emit("SB_LOGIN")
	end)

	local function fire(event, ...)
		SB.eventFrame:Fire(event, ...)
		SB.unitFrame:Fire(event, ...) -- the stub filters unit events by unit
	end

	local function bagUpdate()
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	it("defaults: flask 1, potions 5, food 5, and the warning is on", function()
		assert.equal(true, SB.Config.Get("consumables.warn"))
		assert.equal("Flask 1, Potions 5, Food 5", C.Summary())
	end)

	-- Mutation: count 1 per slot instead of the stack size (`n = n + 1`).
	it("counts whole stacks in the bags by keyword and by item", function()
		assert.equal(2, C.Count({ query = "flask", threshold = 1 }))
		assert.equal(5, C.Count({ query = "potion", threshold = 5 }))
		assert.equal(5, C.Count({ itemID = Fixtures.HEALING_POTION, threshold = 5 }))
		assert.equal(0, C.Count({ query = "food", threshold = 5 }))
	end)

	-- Mutation: compare `have <= e.threshold` in Low.
	it("V11: a key starting with too little food prints one line on screen and in chat", function()
		fire("CHALLENGE_MODE_START")
		assert.same({ "Low: Food (0/5)" }, A.screen)
		assert.same({ "Low: Food (0/5)" }, A.Lines())
	end)

	it("nothing prints when every threshold is met", function()
		SB.Config.Set("consumables.watch", { { query = "flask", threshold = 2 }, { query = "potion", threshold = 5 } })
		fire("CHALLENGE_MODE_START")
		assert.same({}, A.screen)
		assert.same({}, A.Lines())
	end)

	-- Mutation: drop the teleports Matches test (warn on any spell).
	it("V11: a dungeon teleport (\"Path of ...\") warns; another spell does not", function()
		A.spellNames[445417] = "path of the ruined city"
		A.spellNames[8690] = "hearthstone"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8690)
		assert.same({}, A.screen)
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 445417)
		assert.same({ "Low: Food (0/5)" }, A.screen)
	end)

	it("zoning into a Mythic dungeon with a keystone warns; a heroic dungeon does not", function()
		A.instance = { instanceType = "party", difficultyID = 2 }
		fire("PLAYER_ENTERING_WORLD")
		assert.same({}, A.screen)
		A.instance = { instanceType = "party", difficultyID = 23 }
		fire("PLAYER_ENTERING_WORLD")
		assert.same({ "Low: Food (0/5)" }, A.screen)
	end)

	-- Mutation: compare `now - Cons.last[trigger] < 0` (no rate limit).
	it("at most once per 60 s per trigger; each trigger has its own clock", function()
		fire("CHALLENGE_MODE_START")
		fire("CHALLENGE_MODE_START")
		assert.equal(1, #A.screen)
		A.spellNames[445417] = "path of the ruined city"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 445417)
		assert.equal(2, #A.screen)
		A.Advance(61)
		fire("CHALLENGE_MODE_START")
		assert.equal(3, #A.screen)
	end)

	it("switched off: no trigger warns; /swagbag consumables check still answers", function()
		SB.Slash.Dispatch("consumables off")
		fire("CHALLENGE_MODE_START")
		assert.same({}, A.screen)
		SB.Slash.Dispatch("consumables check")
		assert.same({ SB.L.CONSUMABLES_OFF, "Low: Food (0/5)" }, A.Lines())
	end)

	it("a check with everything stocked says so when asked by hand", function()
		SB.Config.Set("consumables.watch", { { query = "flask", threshold = 1 } })
		SB.Slash.Dispatch("consumables check")
		assert.same({ SB.L.CONSUMABLES_OK }, A.Lines())
	end)

	it("an entry whose query does not compile counts nothing and never errors", function()
		assert.equal(0, C.Count({ query = "flask &", threshold = 1 }))
	end)

	it("counts follow the bags: using a flask lowers the count", function()
		A.Put(0, 2, Fixtures.FLASK, 1)
		bagUpdate()
		assert.equal(1, C.Count({ query = "flask", threshold = 1 }))
	end)

	it("Add watches an item once (threshold 1); Remove and SetThreshold edit the saved list", function()
		assert.truthy(C.Add(Fixtures.HEALING_POTION))
		assert.same({ false, "known" }, { C.Add(Fixtures.HEALING_POTION) })
		assert.equal("Flask 1, Potions 5, Food 5, Algari Healing Potion 1", C.Summary())
		assert.truthy(C.SetThreshold(4, 8))
		assert.truthy(C.Remove(3))
		assert.equal("Flask 1, Potions 5, Algari Healing Potion 8", C.Summary())
		assert.truthy(C.SetThreshold(1, 999))
		assert.equal(200, C.List()[1].threshold, "thresholds are kept between 1 and 200")
		assert.same({ false, "invalid" }, { C.Remove(9) })
		assert.same({ false, "invalid" }, { C.Add(0) })
	end)

	it("Reset brings the default list back and stores nothing", function()
		C.Add(Fixtures.HEALING_POTION)
		SB.Slash.Dispatch("consumables reset")
		assert.is_nil(SB.Config.db.settings.consumables.watch)
		assert.same({ "The consumables watch list is back to the default: Flask 1, Potions 5, Food 5." }, A.Lines())
	end)

	-- Mutation: return true from save() without calling Config.Set.
	it("read-only settings (a newer schema): every edit refuses and changes nothing", function()
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { C.Add(Fixtures.HEALING_POTION) })
		assert.same({ false, "readonly" }, { C.SetThreshold(1, 3) })
		assert.same({ false, "readonly" }, { C.Remove(1) })
		assert.same({ false, "readonly" }, { C.Reset() })
		SB.Slash.Dispatch("consumables off")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[1])
		assert.equal("Flask 1, Potions 5, Food 5", C.Summary())
	end)

	it("damaged saved entries are skipped, never an error", function()
		SB.Config.Set("consumables.watch", { { query = "flask", threshold = 0 }, "x", { itemID = -3, threshold = 2 },
			{ itemID = Fixtures.FLASK, threshold = 2.5 }, { query = "potion", threshold = 3 } })
		assert.equal("potion 3", C.Summary(), "an entry without a name shows its search text")
		SB.Config.Set("consumables.watch", "broken")
		assert.equal("Flask 1, Potions 5, Food 5", C.Summary())
	end)

	it("the saved list survives a migration (v1 -> v2) and a failed one keeps it in the backup", function()
		local list = { { itemID = Fixtures.FLASK, threshold = 3 } }
		local db = { schemaVersion = 1, settings = { consumables = { watch = list } }, errors = {}, backups = {} }
		assert.equal("migrated", SB.Config.Init(db, nil))
		assert.equal("Flask of Alchemical Chaos 3", C.Summary())
		SB.Config.migrations[2] = function() error("boom") end
		local db2 = { schemaVersion = 1, settings = { consumables = { watch = list } }, errors = {}, backups = {} }
		assert.equal("reset", SB.Config.Init(db2, nil))
		assert.equal(3, SB.Config.db.backups.v1.settings.consumables.watch[1].threshold)
	end)

	it("/swagbag consumables lists the watch list; an unknown word shows the usage", function()
		SB.Slash.Dispatch("consumables")
		SB.Slash.Dispatch("consumables maybe")
		assert.same({ "Consumables warning on. Watching: Flask 1, Potions 5, Food 5", SB.L.CONSUMABLES_USAGE }, A.Lines())
	end)

	-- Mutation (W4-3): remove the `IsSecret(spellID)` guard at the top of FocusData.Matches.
	it("W4-3: a secret spell ID on the teleport path errors nothing and warns nothing", function()
		A.spellNames[445417] = "path of the ruined city"
		A.IsSecret = function()
			return true
		end
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 445417)
		assert.same({}, A.screen)
		assert.same({}, A.Lines())
		assert.same({}, SB.ErrorTrap.Recent())
		assert.is_nil(A.spellNameCalls[445417], "a secret ID is never looked up")
	end)

	-- Mutation (W4-11): register with SB.On instead of SB.OnUnit; another unit's cast then warns.
	it("W4-11: the teleport handler is a player-only unit registration; another unit's cast does not warn", function()
		assert.equal("player", SB.unitFrame.unitEvents["UNIT_SPELLCAST_SUCCEEDED"])
		A.spellNames[445417] = "path of the ruined city"
		fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "guid", 445417)
		assert.same({}, A.screen)
		SB.eventFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 445417) -- not the unit frame
		assert.same({}, A.screen, "the plain event bus never carries unit events to the handler")
		SB.unitFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 445417)
		assert.equal(1, #A.screen)
	end)

	-- Mutation: map "invalid" to L.DROP_INVALID (or to nothing).
	it("a12: a refused Add maps to its own lines, not the drop-on-category line", function()
		local _, reason = C.Add(0)
		assert.equal(SB.L.SET_WATCH_INVALID, C.ReasonText(reason))
		assert.equal("That item can't be watched.", C.ReasonText("invalid"))
		assert.equal(SB.L.SET_WATCH_KNOWN, C.ReasonText("known"))
		assert.equal(SB.L.SETTINGS_READONLY, C.ReasonText("readonly"))
		assert.truthy(SB.L.SET_WATCH_INVALID ~= SB.L.DROP_INVALID)
	end)

	-- Mutation (W4-18): in List(), keep `name = e.name` unchecked.
	it("W4-18: a damaged saved name (a boolean, an unknown key) falls back to the query and never errors", function()
		SB.Config.Set("consumables.watch", { { query = "food", threshold = 5, name = true },
			{ query = "flask", threshold = 5, name = "BOGUS" }, { query = "potion", threshold = 9, name = {} } })
		fire("CHALLENGE_MODE_START")
		assert.same({ "Low: food (0/5), flask (2/5), potion (5/9)" }, A.screen)
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	-- Mutation (W4-19): remove the `excludes` check in FocusData.Matches.
	it("W4-19: Path of Frost (Death Knight) is not a dungeon teleport", function()
		A.spellNames[3714] = "path of frost"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 3714)
		assert.same({}, A.screen)
	end)

	-- Mutation (W4-20): remove the isReload test in the PLAYER_ENTERING_WORLD handler.
	it("W4-20: a /reload inside a running key does not warn; a real zone-in during a key does", function()
		A.instance = { instanceType = "party", difficultyID = 8 }
		A.challengeMode = true
		fire("PLAYER_ENTERING_WORLD", false, true)
		assert.same({}, A.screen)
		fire("PLAYER_ENTERING_WORLD", false, false)
		assert.same({ "Low: Food (0/5)" }, A.screen)
	end)

	it("a Mythic dungeon without a keystone in the bags does not warn", function()
		A.Put(0, 5, nil, 0)
		A.instance = { instanceType = "party", difficultyID = 23 }
		fire("PLAYER_ENTERING_WORLD", false, false)
		assert.same({}, A.screen)
	end)

	it("/swagbag consumables on answers with the on line", function()
		SB.Slash.Dispatch("consumables on")
		assert.same({ SB.L.CONSUMABLES_ON }, A.Lines())
	end)

	it("an item in the bank is not counted", function()
		A.bagIDs.bank = { 6 }
		A.SetBagSize(6, 4)
		A.Put(6, 1, Fixtures.HEALING_POTION, 10)
		assert.equal(5, C.Count({ query = "potion", threshold = 5 }))
		assert.equal(5, C.Count({ itemID = Fixtures.HEALING_POTION, threshold = 5 }))
	end)

	it("an empty watch list says nothing is watched, by list and by check", function()
		SB.Config.Set("consumables.watch", {})
		SB.Slash.Dispatch("consumables")
		SB.Slash.Dispatch("consumables check")
		assert.same({ SB.L.CONSUMABLES_NONE, SB.L.CONSUMABLES_NONE }, A.Lines())
	end)

	-- Mutation (d6): drop the unchanged-value test in SetThreshold.
	it("d6: SetThreshold with the same (clamped) value saves nothing", function()
		assert.same({ false, "same" }, { C.SetThreshold(1, 1) })
		assert.same({ false, "same" }, { C.SetThreshold(2, 5.7) })
		assert.is_nil(SB.Config.Get("consumables.watch"))
		assert.truthy(C.SetThreshold(2, 6))
	end)

	it("one pass: each bag slot is described once however many entries are watched", function()
		local n, real = 0, SB.Items.Describe
		SB.Items.Describe = function(...)
			n = n + 1
			return real(...)
		end
		C.Low()
		SB.Items.Describe = real
		assert.equal(6, n, "six filled slots, one description each")
	end)
end)
