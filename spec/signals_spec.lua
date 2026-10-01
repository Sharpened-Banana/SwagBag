-- Signals (spec 6.2): WoW events -> Focus signals, through the mock Adapter. Checks V5-V8 in
-- unit form: M+ (and its fallback), raid, delve, fishing (channel and loot), gathering (the
-- allowlist; chests and archaeology never), professions, vendor / auction house / bank.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Focus.lua",
	"SwagBag/Engine/FocusData.lua", "SwagBag/Engine/Signals.lua",
}

describe("Signals", function()
	local SB, A, F, S
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- slot 5 holds a keystone
		F, S = SB.Focus, SB.Signals
		SB.Emit("SB_LOGIN")
	end)

	local function fire(event, ...)
		SB.eventFrame:Fire(event, ...)
		SB.unitFrame:Fire(event, ...) -- the client delivers per registration; the stub filters by unit
	end

	local function bagUpdate()
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function enter(instanceType, difficultyID)
		A.instance = { instanceType = instanceType, difficultyID = difficultyID }
		fire("PLAYER_ENTERING_WORLD")
	end

	it("registers every event it listens to", function()
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "SCENARIO_UPDATE", "CHALLENGE_MODE_START",
			"CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "ADDON_RESTRICTION_STATE_CHANGED",
			"LOOT_READY", "SKILL_LINES_CHANGED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "AUCTION_HOUSE_SHOW",
			"AUCTION_HOUSE_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED" }) do
			assert.truthy(SB.eventFrame.events[e], e)
		end
		for _, e in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED" }) do
			assert.equal("player", SB.unitFrame.unitEvents[e], e)
			assert.falsy(SB.eventFrame.events[e], e .. " must not be registered for every unit")
		end
	end)

	-- Mutation (W4-11): register the spellcast events through SB.On instead of SB.OnUnit.
	it("W4-11: a nameplate's or party member's cast never reaches the handler", function()
		local calls = 0
		SB.OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function()
			calls = calls + 1
		end, "bags")
		fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "guid", 2366)
		fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "guid", 2366)
		assert.equal(0, calls)
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366)
		assert.equal(1, calls)
	end)

	-- Mutation: drop the `unit == "player"` part of the handler check AND register through SB.On.
	it("a party member's gathering spell followed by node loot turns no mode on", function()
		A.lootSource = "GameObject"
		fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "guid", 2366)
		fire("LOOT_READY")
		assert.same({}, F.Active())
		assert.same({}, S.recent)
	end)

	it("ADDON_RESTRICTION_STATE_CHANGED re-reads the zone only for the ChallengeMode restriction", function()
		local reads = 0
		local read = S.ReadZone
		S.ReadZone = function()
			reads = reads + 1
			return read()
		end
		fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 1)
		assert.equal(0, reads)
		fire("ADDON_RESTRICTION_STATE_CHANGED", 2, 1)
		assert.equal(1, reads)
	end)

	it("a client without the ADDON_RESTRICTION_STATE_CHANGED event loads Signals without error", function()
		local files = {}
		for i = 1, #FILES - 1 do
			files[i] = FILES[i]
		end
		local SB2 = Loader.New(files)
		Loader.Stub.unknownEvents.ADDON_RESTRICTION_STATE_CHANGED = true
		local ok, err = pcall(Loader.LoadFile, SB2, "SwagBag/Engine/Signals.lua")
		assert.truthy(ok, err)
		assert.falsy(SB2.eventFrame.events.ADDON_RESTRICTION_STATE_CHANGED)
		assert.truthy(SB2.eventFrame.events.PLAYER_ENTERING_WORLD)
	end)

	-- Mutation: drop the flag clearing in the PLAYER_ENTERING_WORLD handler.
	it("a new world (PLAYER_ENTERING_WORLD) clears the vendor, auction house and bank flags", function()
		fire("MERCHANT_SHOW")
		fire("AUCTION_HOUSE_SHOW")
		fire("BANKFRAME_OPENED")
		assert.same({ "market" }, F.Active())
		fire("PLAYER_ENTERING_WORLD")
		assert.same({}, F.Active())
		assert.equal(false, F.signals.merchantOpen)
		assert.equal(false, F.signals.auctionOpen)
		assert.equal(false, F.signals.bankOpen)
	end)

	it("nothing fires before login: settings are not loaded yet", function()
		local SB2 = Loader.New(FILES)
		SB2.Config.Get = function() error("Config read before login") end
		SB2.Adapter.challengeMode = true
		SB2.eventFrame:Fire("PLAYER_ENTERING_WORLD")
		assert.is_nil(SB2.Focus.signals.challengeMode)
		assert.same({}, SB2.ErrorTrap.Recent())
	end)

	-- Mutation: drop `s.challengeMode = A.ChallengeModeActive() == true` from ReadZone.
	it("V5: the key starts (CHALLENGE_MODE_START) -> M+; the key ends and the player leaves -> no mode", function()
		enter("party", nil) -- difficulty unreadable: only the challenge-mode signal can say M+
		A.challengeMode = true
		fire("CHALLENGE_MODE_START")
		assert.same({ "mplus" }, F.Active())
		A.challengeMode = false
		A.Clear(0, 5) -- keystone handed in
		bagUpdate()
		enter(nil, nil)
		assert.same({}, F.Active())
	end)

	-- Mutation: make HasKeystone always return false.
	it("V5 fallback: a Mythic party dungeon with a keystone in the bags is M+ before the key starts", function()
		A.challengeMode = nil -- the client cannot tell
		enter("party", 23)
		assert.same({ "mplus" }, F.Active())
		enter("party", 2) -- heroic
		assert.same({}, F.Active())
	end)

	it("the keystone signal follows the bags while in a party dungeon", function()
		A.Clear(0, 5)
		bagUpdate()
		enter("party", 23)
		assert.same({}, F.Active())
		A.Put(0, 5, Fixtures.KEYSTONE, 1, { link = "|Hkeystone:180653:503:12|h[Keystone]|h" })
		bagUpdate()
		assert.same({ "mplus" }, F.Active())
	end)

	it("raid and delve (V7) come from the zone", function()
		enter("raid", 16)
		assert.same({ "raid" }, F.Active())
		A.delve = true
		enter("scenario", 208)
		assert.same({ "delves" }, F.Active())
	end)

	-- Mutation: compare `unit == "target"` in the channel handler.
	it("V6: a fishing channel by the player turns Fishing on; it decays 90 s after the last cast", function()
		A.spellNames[131474] = "fishing"
		fire("UNIT_SPELLCAST_CHANNEL_START", "party1", "guid", 131474)
		assert.same({}, F.Active(), "another player's cast")
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
		assert.same({ "fishing" }, F.Active())
		A.Advance(60)
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
		A.Advance(89)
		assert.same({ "fishing" }, F.Active(), "still within 90 s of the last cast")
		A.Advance(2)
		assert.same({}, F.Active())
	end)

	it("V6 backups: a fishing spell found by name, and fishing loot without any cast", function()
		A.spellNames[999001] = "fishing"
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 999001)
		assert.same({ "fishing" }, F.Active())
		A.Advance(91)
		A.fishingLoot = true
		fire("LOOT_READY")
		assert.same({ "fishing" }, F.Active())
	end)

	-- Mutation: drop the `A.Now() - at > Sig.GATHER_WINDOW` test.
	it("V8: loot from a node within 6 s of Herb Gathering turns Gathering on; it decays after 120 s", function()
		A.lootSource = "GameObject"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366)
		A.Advance(2)
		fire("LOOT_READY")
		assert.same({ "gathering" }, F.Active())
		A.Advance(121)
		assert.same({}, F.Active())
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366)
		A.Advance(7)
		fire("LOOT_READY")
		assert.same({}, F.Active(), "loot more than 6 s after the cast")
	end)

	-- Mutation: let any spell name match (return true at the end of FocusData.Matches).
	it("AC8.6: opening a chest or digging (archaeology) never turns Gathering on", function()
		A.lootSource = "GameObject"
		A.spellNames[3365] = "opening"
		A.spellNames[80451] = "survey"
		A.spellNames[73979] = "digging"
		for _, spell in ipairs({ 3365, 80451, 73979 }) do
			fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", spell)
			fire("LOOT_READY")
		end
		assert.same({}, F.Active())
	end)

	it("a gathering spell of a later expansion is found by its name; skinning loots a creature", function()
		A.spellNames[423395] = "herb gathering"
		A.lootSource = "GameObject"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 423395)
		fire("LOOT_READY")
		assert.same({ "gathering" }, F.Active())
		A.Advance(121)
		A.spellNames[440977] = "skinning"
		A.lootSource = "Creature"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 440977)
		fire("LOOT_READY")
		assert.same({ "gathering" }, F.Active())
	end)

	it("loot from a player's corpse or an item after a gathering spell is not gathering", function()
		A.lootSource = "Player"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2575)
		fire("LOOT_READY")
		assert.same({}, F.Active())
	end)

	it("the report keeps the last 5 spells cast before loot", function()
		for _, spell in ipairs({ 1, 2, 3, 4, 5, 6 }) do
			fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", spell)
			fire("LOOT_READY")
		end
		assert.same({ 2, 3, 4, 5, 6 }, S.recent)
	end)

	it("the recent-spell list holds the last 5 DISTINCT spell IDs: repeated casts do not fill it", function()
		for _, spell in ipairs({ 1, 2, 3, 3, 3, 3, 3, 3 }) do
			fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", spell)
			fire("LOOT_READY")
		end
		assert.same({ 1, 2, 3 }, S.recent)
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1)
		fire("LOOT_READY")
		assert.same({ 2, 3, 1 }, S.recent, "a repeat moves to the newest end")
	end)

	-- Mutation (W4-3): remove the `IsSecret(spellID)` guard at the top of FocusData.Matches.
	it("W4-3: a secret spell ID matches nothing, errors nothing and turns no mode on", function()
		A.spellNames[131474] = "fishing"
		A.spellNames[2366] = "herb gathering"
		A.IsSecret = function()
			return true
		end
		assert.equal(false, SB.FocusData.Matches(SB.FocusData.fishing, 131474))
		assert.equal(false, SB.FocusData.Matches(SB.FocusData.gathering, 2366))
		A.lootSource = "GameObject"
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366)
		fire("LOOT_READY")
		assert.same({}, F.Active())
		assert.same({}, SB.ErrorTrap.Recent())
		assert.is_nil(A.spellNameCalls[131474], "a secret ID is never looked up")
	end)

	-- Mutation (W4-3): remove the name cache in FocusData.Matches.
	it("W4-3: the name of a repeated spell ID is looked up once", function()
		A.spellNames[999001] = "fishing"
		for _ = 1, 5 do
			fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 999001)
		end
		assert.same({ "fishing" }, F.Active())
		assert.equal(1, A.spellNameCalls[999001])
		assert.equal(true, SB.FocusData.Matches(SB.FocusData.fishing, 999001))
		assert.equal(false, SB.FocusData.Matches(SB.FocusData.gathering, 999001))
		assert.equal(1, A.spellNameCalls[999001], "a second list reuses the cached name")
	end)

	it("Gathering opens only the materials of the professions read at login and on SKILL_LINES_CHANGED", function()
		A.professions = { ore = true }
		fire("SKILL_LINES_CHANGED")
		assert.same({ "c_ore", "c_tools" }, F.Sections("gathering"))
	end)

	it("vendor, auction house and bank open and close the AH/Vendor/Bank mode", function()
		fire("MERCHANT_SHOW")
		assert.same({ "market" }, F.Active())
		fire("MERCHANT_CLOSED")
		fire("AUCTION_HOUSE_SHOW")
		assert.same({ "market" }, F.Active())
		fire("AUCTION_HOUSE_CLOSED")
		fire("BANKFRAME_OPENED")
		assert.truthy(F.signals.bankOpen)
		fire("BANKFRAME_CLOSED")
		assert.same({}, F.Active())
	end)

	it("an error in a signal handler is trapped with the bags window's label", function()
		A.InstanceInfo = function() error("zone broke") end
		fire("ZONE_CHANGED_NEW_AREA")
		local e = SB.ErrorTrap.Recent()[1]
		assert.equal("event:ZONE_CHANGED_NEW_AREA", e.label)
		assert.equal("bags", e.window)
	end)

	it("a handler costs well under 0.1 ms on average (spec 6.5)", function()
		A.lootSource = "GameObject"
		local t0 = os.clock()
		for i = 1, 2000 do
			fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366 + (i % 2))
			fire("LOOT_READY")
		end
		local avg = (os.clock() - t0) * 1000 / 4000
		assert.truthy(avg < 0.1, ("%.4f ms per handler"):format(avg))
	end)
end)

describe("Report focus lines", function()
	it("names the mode, the resolve setting, the signals and the spells cast before loot", function()
		local SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
			"SwagBag/Core/Config.lua", "SwagBag/Core/Slash.lua", "SwagBag/Core/Checks.lua", "SwagBag/Core/Blocked.lua",
			"SwagBag/Core/Report.lua",
			"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Focus.lua",
			"SwagBag/Engine/FocusData.lua", "SwagBag/Engine/Signals.lua" })
		local A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		SB.Emit("SB_LOGIN")
		A.instance = { instanceType = "party", difficultyID = 8 }
		A.challengeMode = true
		SB.eventFrame:Fire("CHALLENGE_MODE_START")
		SB.unitFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 3365)
		SB.eventFrame:Fire("LOOT_READY")
		local text = SB.Report.Build()
		assert.truthy(text:find("Focus: M+ (merge); zone party, collapsing yes; M+ yes, keystone yes, delve no, fishing no, "
			.. "gathering no", 1, true), text)
		assert.truthy(text:find("Spells before loot (last 5): 3365", 1, true), text)
	end)
end)
