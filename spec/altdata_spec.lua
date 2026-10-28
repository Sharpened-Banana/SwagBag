-- Alt data (Engine/AltData.lua, spec 3.3, F13): providers by priority, the built-in "Own" over
-- SwagBag's snapshots, live bags for the current character, per-container count index.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Snapshots.lua",
	"SwagBag/Engine/AltData.lua",
}

describe("AltData", function()
	local SB, A, AD, Snap
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- this character's bags: potion x5, flask x2, ring, helm, keystone, junk x3
		SB.Inventory.ScanAll()
		AD, Snap = SB.AltData, SB.Snapshots
	end)

	-- An alt saved with the given bags and bank lines ("slot:link;count\n").
	local function alt(key, bags, bank, extra)
		local c = extra or {}
		c.class, c.level, c.lastSeen = c.class or "PRIEST", 80, A.Time() - 3600
		c.bags = bags and { v = 1, at = A.Time() - 3600, containers = { [0] = { size = 16, s = bags } } } or nil
		c.bank = bank and { v = 1, at = A.Time() - 7200, containers = { [6] = { size = 98, s = bank } } } or nil
		Snap.DB().chars[key] = c
		return c
	end

	it("Canon removes spaces and hyphens from the realm, as Syndicator writes it", function()
		assert.equal("Swagger-ArgentDawn", AD.Canon("Swagger-Argent Dawn"))
		assert.equal("Alt-AzjolNerub", AD.Canon("Alt-Azjol-Nerub"))
		assert.equal("Alt-ArgentDawn", AD.Canon("Alt-ArgentDawn"))
	end)

	it("ItemID reads item, keystone and battle pet links", function()
		assert.equal(211880, AD.ItemID("|cffffffff|Hitem:211880::::::::80:::::|h[Potion]|h|r"))
		assert.equal(180653, AD.ItemID("|cffa335ee|Hkeystone:180653:503:12:10:9:0:0|h[Keystone]|h|r"))
		assert.equal(82800, AD.ItemID("|cff0070dd|Hbattlepet:1234:25:3:1400:250:250:0|h[Pet]|h|r"))
		assert.is_nil(AD.ItemID(nil))
	end)

	it("Own lists saved characters with canonical keys, the current one first, then by name", function()
		Snap.Save("bags")
		alt("Zed-Argent Dawn", "1:item:210796;20\n")
		alt("Abby-Argent Dawn", nil, nil, { class = "MAGE", guild = "Tidewatch-Argent Dawn" })
		local list, source = AD.Characters()
		assert.equal("Own", source)
		assert.same({ "Swagger-ArgentDawn", "Abby-ArgentDawn", "Zed-ArgentDawn" }, { list[1].key, list[2].key, list[3].key })
		assert.truthy(list[1].current)
		assert.equal("Abby", list[2].name)
		assert.equal("Argent Dawn", list[2].realm)
		assert.equal("MAGE", list[2].class)
		assert.equal("Tidewatch-Argent Dawn", list[2].guild)
	end)

	it("Own wealth lists saved characters; a 0.16 character with neither field is left out", function()
		A.money = 4200
		alt("Alt-Realm", nil, nil, { money = 900, currencies = { [3008] = 3 } })
		alt("Old-Realm")
		local list, source = AD.Wealth()
		assert.equal("Own", source)
		assert.equal(2, #list)
		assert.equal(true, list[1].current)
		assert.equal(4200, list[1].money)
		assert.same({ name = "Alt", realm = "Realm", class = "PRIEST", key = "Alt-Realm", money = 900,
			currencies = { [3008] = 3 }, current = false }, list[2])
	end)

	it("Own wealth lists the current character when its table exists but has no money or currencies yet", function()
		Snap.Save("bags") -- creates chars[me] with class and level only
		A.money = 777
		local list = AD.Wealth()
		assert.equal(1, #list)
		assert.equal(true, list[1].current)
		assert.equal(777, list[1].money)
	end)

	it("Own containers: bags, bank, the warband bank and the character's guild bank, decoded", function()
		alt("Abby-Argent Dawn", "1:item:210796;20\n3:item:211880;2\n", "5:item:210930;100\n",
			{ guild = "Tidewatch-Argent Dawn" })
		Snap.DB().warband = { v = 1, at = A.Time(), containers = { [12] = { size = 98, s = "2:item:156654;7\n" } } }
		Snap.DB().guilds["Tidewatch-Argent Dawn"] = { tabs = { [1] = "Mats" },
			snapshot = { v = 1, at = A.Time(), containers = { [1] = { size = 98, s = "4:item:212283;3\n" } } } }
		local bags = AD.Container("Abby-ArgentDawn", "bags")
		assert.same({ link = "item:211880", count = 2 }, bags.containers[0].slots[3])
		assert.equal(16, bags.containers[0].size)
		assert.same({ link = "item:210930", count = 100 }, AD.Container("Abby-ArgentDawn", "bank").containers[6].slots[5])
		assert.same({ link = "item:156654", count = 7 }, AD.Container("Abby-ArgentDawn", "warband").containers[12].slots[2])
		local guild = AD.Container("Abby-ArgentDawn", "guild")
		assert.equal("Tidewatch", guild.title)
		assert.equal("Mats", guild.names[1])
		assert.same({ link = "item:212283", count = 3 }, guild.containers[1].slots[4])
		assert.is_nil(AD.Container("Nobody-ArgentDawn", "bags"))
		assert.is_nil(AD.Container("Abby-ArgentDawn", "nothing"))
	end)

	-- Mutation: count the current character's bags from its snapshot instead of liveBags.
	it("Own counts: alts from their snapshots, this character's bags live, the warband bank and guilds", function()
		Snap.Save("bags") -- this character is saved too (potion x5)
		alt("Abby-Argent Dawn", "1:item:211880;20\n", "5:item:211880;100\n")
		Snap.DB().warband = { v = 1, containers = { [12] = { size = 98, s = "2:item:211880;7\n" } } }
		Snap.DB().guilds["Tidewatch-Argent Dawn"] = { snapshot = { v = 1, containers = { [1] = { size = 98,
			s = "4:item:211880;3\n" } } } }
		local c = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal(2, #c.chars)
		assert.same({ key = "Swagger-ArgentDawn", name = "Swagger", class = "MAGE", current = true, bags = 5, bank = 0 },
			c.chars[1])
		assert.same({ key = "Abby-ArgentDawn", name = "Abby", class = "PRIEST", current = false, bags = 20, bank = 100 },
			c.chars[2])
		assert.equal(7, c.warband)
		assert.same({ { key = "Tidewatch-Argent Dawn", name = "Tidewatch", count = 3 } }, c.guilds)
		A.Put(0, 1, Fixtures.HEALING_POTION, 9)
		SB.Inventory.ScanAll()
		assert.equal(9, AD.Counts(Fixtures.HEALING_POTION).chars[1].bags, "live: no snapshot needed")
	end)

	it("Own counts leave out characters without the item", function()
		alt("Abby-Argent Dawn", "1:item:210796;20\n")
		local c = AD.Counts(Fixtures.FLASK)
		assert.equal(1, #c.chars)
		assert.equal("Swagger", c.chars[1].name)
		assert.same({}, AD.Counts(999999).chars)
	end)

	-- Spec 8.4: the index is derived, per container, and rebuilt only for what was saved again.
	-- Mutations: in the SB_SNAPSHOT_SAVED listener, do nothing; or wipe the whole index (index = {}).
	it("the index is built once per container and dropped when that container is saved again", function()
		alt("Abby-Argent Dawn", "1:item:211880;20\n")
		Snap.DB().chars["Swagger-Argent Dawn"] = { class = "MAGE", bank = { v = 1, containers = { [6] = { size = 98,
			s = "5:item:211880;4\n" } } } }
		AD.Counts(Fixtures.HEALING_POTION)
		assert.truthy(AD.Index()["bags:Abby-Argent Dawn"])
		assert.truthy(AD.Index()["bank:Swagger-Argent Dawn"])
		assert.truthy(AD.Index()["bags:Swagger-Argent Dawn"] == nil, "this character's bags are live, not indexed")
		SB.Emit("SB_SNAPSHOT_SAVED", "bank", "Swagger-Argent Dawn") -- only that container's index goes
		assert.is_nil(AD.Index()["bank:Swagger-Argent Dawn"])
		assert.truthy(AD.Index()["bags:Abby-Argent Dawn"], "other containers keep their index")
		Snap.DB().chars["Abby-Argent Dawn"].bags.containers[0].s = "1:item:211880;50\n"
		SB.Emit("SB_SNAPSHOT_SAVED", "bags", "Abby-Argent Dawn")
		assert.equal(50, AD.Counts(Fixtures.HEALING_POTION).chars[2].bags)
	end)

	it("Snapshots remember the character's guild and announce every save", function()
		local seen = {}
		SB.On("SB_SNAPSHOT_SAVED", function(_, kind, owner) seen[#seen + 1] = kind .. ":" .. tostring(owner) end)
		Snap.Save("bags")
		Snap.SaveGuild("Tidewatch-Argent Dawn", { [1] = { name = "Mats", slots = {} } })
		assert.equal("Tidewatch-Argent Dawn", Snap.DB().chars["Swagger-Argent Dawn"].guild)
		assert.same({ "bags:Swagger-Argent Dawn", "guild:Tidewatch-Argent Dawn" }, seen)
	end)

	-- F15. Mutation: in Snap.Char, `c.guild = A.GuildKey()` (a transient nil erases the link).
	it("a save right after login (guild not known yet) keeps the saved guild link", function()
		Snap.Save("bags")
		assert.equal("Tidewatch-Argent Dawn", Snap.DB().chars["Swagger-Argent Dawn"].guild)
		A.guild.key, A.guild.inGuild = nil, true -- GetGuildInfo is nil for a few seconds after login
		Snap.Save("bags")
		assert.equal("Tidewatch-Argent Dawn", Snap.DB().chars["Swagger-Argent Dawn"].guild)
	end)

	it("a save by a character that is certainly in no guild clears the link", function()
		Snap.Save("bags")
		A.guild.key, A.guild.inGuild = nil, false
		SB.Emit("PLAYER_GUILD_UPDATE") -- the client has told us its guild situation (W5-6)
		Snap.Save("bags")
		assert.is_nil(Snap.DB().chars["Swagger-Argent Dawn"].guild)
	end)

	-- W5-6. Mutation: drop the `Snap.guildUpdated and` condition.
	it("IsInGuild false before PLAYER_GUILD_UPDATE is not believed; unknown (nil) never clears", function()
		Snap.Save("bags")
		A.guild.key, A.guild.inGuild = nil, false
		Snap.Save("bags")
		assert.equal("Tidewatch-Argent Dawn", Snap.DB().chars["Swagger-Argent Dawn"].guild)
		SB.Emit("PLAYER_GUILD_UPDATE")
		A.guild.inGuild = nil -- the client can't say
		Snap.Save("bags")
		assert.equal("Tidewatch-Argent Dawn", Snap.DB().chars["Swagger-Argent Dawn"].guild)
	end)

	it("the guild name of a key splits at the first hyphen: a realm with a hyphen", function()
		Snap.DB().guilds["Tidewatch-Azjol-Nerub"] = { snapshot = { v = 1, containers = { [1] = { size = 98,
			s = "4:item:211880;3\n" } } } }
		assert.same({ { key = "Tidewatch-Azjol-Nerub", name = "Tidewatch", count = 3 } },
			AD.Counts(Fixtures.HEALING_POTION).guilds)
		alt("Abby-Argent Dawn", nil, nil, { guild = "Tidewatch-Azjol-Nerub" })
		assert.equal("Tidewatch", AD.Container("Abby-ArgentDawn", "guild").title)
	end)

	it("the current character's row carries its class from the client", function()
		assert.equal("MAGE", AD.Counts(Fixtures.HEALING_POTION).chars[1].class)
	end)

	it("an available() that throws counts toward the switch-off, with a stack in the ring", function()
		AD.RegisterProvider({ name = "Shaky", priority = 10, available = function() error("nope") end,
			characters = function() return {} end })
		for _ = 1, 2 do
			assert.equal("Own", select(2, AD.Characters()))
		end
		assert.same({}, A.Lines())
		AD.Characters()
		assert.same({ SB.L.ALTDATA_PROVIDER_OFF:format("Shaky") }, A.Lines())
		local e = SB.ErrorTrap.Recent()[1]
		assert.equal("altdata:Shaky", e.label)
		assert.equal("none", e.window)
		assert.truthy(e.stack ~= nil)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("Own is never switched off; each of its errors is recorded", function()
		local real = AD.Own.characters
		AD.Own.characters = function() error("own broke") end
		for _ = 1, 5 do
			AD.Characters()
		end
		AD.Own.characters = real
		assert.same({}, A.Lines())
		assert.equal("Own", AD.Source())
		assert.equal("altdata:Own", SB.ErrorTrap.Recent()[1].label)
		assert.truthy(#SB.ErrorTrap.Recent() >= 5)
		assert.equal("Own", select(2, AD.Characters()))
	end)

	-- W5-7. Mutation: Prebuild does nothing / runs without the OutOfCombat wrapper.
	it("the index is prebuilt 5 s after login out of combat, so the first tooltip builds nothing", function()
		alt("Abby-Argent Dawn", "1:item:211880;20\n", "5:item:211880;100\n")
		SB.Emit("SB_LOGIN")
		A.Advance(4.9)
		assert.is_nil(AD.Index()["bags:Abby-Argent Dawn"])
		A.Advance(0.2)
		assert.truthy(AD.Index()["bags:Abby-Argent Dawn"])
		assert.truthy(AD.Index()["bank:Abby-Argent Dawn"])
		local calls, real = 0, Snap.Deserialize
		Snap.Deserialize = function(...) calls = calls + 1 return real(...) end
		assert.equal(20, AD.Counts(Fixtures.HEALING_POTION).chars[2].bags)
		Snap.Deserialize = real
		assert.equal(0, calls, "the first count did no build work")
	end)

	it("the prebuild waits for the end of combat", function()
		alt("Abby-Argent Dawn", "1:item:211880;20\n")
		A.combat = true
		SB.Emit("SB_LOGIN")
		A.Advance(6)
		assert.is_nil(AD.Index()["bags:Abby-Argent Dawn"])
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.truthy(AD.Index()["bags:Abby-Argent Dawn"])
	end)

	-- F16. Mutation: Enforce trims without emitting.
	it("Enforce announces each bank snapshot it trims, so the index drops its counts", function()
		alt("Old-Argent Dawn", nil, "1:item:211880;20\n")
		Snap.DB().chars["Old-Argent Dawn"].lastSeen = 1
		AD.Counts(Fixtures.HEALING_POTION)
		assert.truthy(AD.Index()["bank:Old-Argent Dawn"])
		local seen = {}
		SB.On("SB_SNAPSHOT_SAVED", function(_, kind, owner) seen[#seen + 1] = kind .. ":" .. tostring(owner) end)
		Snap.TRIGGER = 0
		Snap.Enforce()
		assert.same({ "bank:Old-Argent Dawn" }, seen)
		assert.is_nil(AD.Index()["bank:Old-Argent Dawn"])
		assert.equal(1, #AD.Counts(Fixtures.HEALING_POTION).chars, "only this character is left")
	end)

	it("a better provider wins; one that answers nil hands the call to the next", function()
		local answer = { { key = "X-Y", name = "X" } }
		AD.RegisterProvider({ name = "Better", priority = 10, available = function() return true end,
			characters = function() return answer end, counts = function() return nil end })
		local list, source = AD.Characters()
		assert.equal(answer, list)
		assert.equal("Better", source)
		local _, countSource = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal("Own", countSource)
		assert.equal("Better", AD.Source())
	end)

	it("an unavailable provider is skipped", function()
		AD.RegisterProvider({ name = "Gone", priority = 10, available = function() return false end,
			characters = function() error("never asked") end })
		local _, source = AD.Characters()
		assert.equal("Own", source)
		assert.equal("Own", AD.Source())
	end)

	-- Spec 3.3. Mutation: in failed(), switch the provider off at the first error.
	it("a provider that throws three times is switched off with one chat line and one recorded error", function()
		AD.RegisterProvider({ name = "Broken", priority = 10, available = function() return true end,
			characters = function() error("broke") end })
		for _ = 1, 2 do
			local _, source = AD.Characters()
			assert.equal("Own", source, "the next provider answers meanwhile")
		end
		assert.same({}, A.Lines())
		AD.Characters()
		AD.Characters()
		assert.same({ SB.L.ALTDATA_PROVIDER_OFF:format("Broken") }, A.Lines())
		assert.equal("altdata:Broken", SB.ErrorTrap.Recent()[1].label)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("Counts of a non-number is nil (a tooltip with no item ID)", function()
		assert.is_nil(AD.Counts(nil))
	end)

	-- Review Focus 4 (many alts, a tooltip on every hover). Mutation: in mapOf, never store the map.
	it("25 saved characters: the first count builds the index in under 50 ms; then a count takes under 1 ms", function()
		local lines = {}
		for slot = 1, 98 do
			lines[#lines + 1] = slot .. ":item:" .. (200000 + slot) .. ";" .. slot .. "\n"
		end
		local s = table.concat(lines)
		for i = 1, 25 do
			alt("Alt" .. i .. "-Argent Dawn", s, s)
		end
		local t0 = os.clock()
		AD.Counts(200001)
		local first = (os.clock() - t0) * 1000
		assert.truthy(first < 50, ("first count took %.1f ms"):format(first))
		t0 = os.clock()
		for id = 200001, 200098 do
			AD.Counts(id)
		end
		local each = (os.clock() - t0) * 1000 / 98
		assert.truthy(each < 1, ("a count took %.2f ms"):format(each))
		assert.equal(25, #AD.Counts(200050).chars)
	end)
end)
