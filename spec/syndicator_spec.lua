-- luacheck: globals Syndicator C_CurrencyInfo issecretvalue
-- The Syndicator alt data provider (Providers/Syndicator.lua, spec 3.3): used only while Syndicator
-- is loaded and ready; replaces Own for characters, containers and counts, adds mail/equipped/auction
-- counts; guild banks stay SwagBag's own; errors switch it off and Own carries on.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Snapshots.lua",
	"SwagBag/Engine/AltData.lua", "SwagBag/Providers/Syndicator.lua",
}

-- A stand-in for Syndicator's public API (names only, as the provider reads them).
local function fakeSyndicator()
	local chars = {
		["Swagger-ArgentDawn"] = { details = { character = "Swagger", realm = "Argent Dawn", realmNormalized = "ArgentDawn",
			className = "MAGE", show = { inventory = true } },
			bags = { { [1] = { itemID = 211880, itemCount = 5, itemLink = "item:211880" }, [2] = {} } }, bankTabs = {} },
		["Abby-ArgentDawn"] = { details = { character = "Abby", realm = "Argent Dawn", realmNormalized = "ArgentDawn",
			className = "PRIEST", show = { inventory = true } },
			bags = { { [1] = { itemLink = "item:210796", itemCount = 20 }, [2] = {} }, {}, {}, {}, {}, {} },
			bankTabs = { { slots = { [1] = {}, [2] = { itemLink = "item:210930", itemCount = 100 } } } } },
		["Hidden-ArgentDawn"] = { details = { character = "Hidden", className = "ROGUE", show = { inventory = false } },
			bags = {} },
	}
	local api = { ready = true, calls = 0, chars = chars, current = "Swagger-ArgentDawn" }
	function api.IsReady() return api.ready end
	function api.GetAllCharacters()
		api.listCalls = (api.listCalls or 0) + 1
		local keys = {}
		for k in pairs(chars) do
			keys[#keys + 1] = k
		end
		table.sort(keys)
		return keys
	end
	function api.GetByCharacterFullName(k) return chars[k] end
	function api.GetCurrentCharacter() return api.current end
	function api.GetWarband() return { bank = { { slots = { [3] = { itemLink = "item:156654", itemCount = 7 } } } } } end
	function api.GetInventoryInfoByItemID(id)
		api.calls = api.calls + 1
		if api.broken then
			error("syndicator broke")
		end
		if id ~= 211880 then
			return { characters = {}, guilds = {}, warband = { 0 } } -- v284's real answer for an unknown item
		end
		return { characters = {
			{ character = "Swagger", realmNormalized = "ArgentDawn", className = "MAGE", bags = 5, bank = 0, mail = 0,
				equipped = 0, auctions = 0, void = 0 },
			{ character = "Abby", realmNormalized = "ArgentDawn", className = "PRIEST", bags = 20, bank = 0, mail = 2,
				equipped = 0, auctions = 1, void = 0 },
			{ character = "Empty", realmNormalized = "ArgentDawn", bags = 0, bank = 0 },
		}, guilds = { { guild = "Tidewatch", realmNormalized = "ArgentDawn", bank = 3 } }, warband = { 7 } }
	end
	local reg = { events = {} }
	function reg:RegisterCallback(event, fn, owner)
		self.events[event] = function(...) return fn(owner, ...) end
	end
	return api, reg
end

describe("Syndicator provider", function()
	local SB, A, AD, api, reg
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		SB.Inventory.ScanAll()
		AD = SB.AltData
		api, reg = fakeSyndicator()
		A.globals.Syndicator = { API = api, CallbackRegistry = reg }
	end)

	-- P4. Mutation: in Adapter.SyndicatorAPI, skip the IsReady check.
	it("answers only while Syndicator is loaded, complete and ready; Own answers otherwise", function()
		assert.equal("Syndicator", AD.Source())
		api.ready = false
		assert.equal("Own", AD.Source())
		api.ready = true
		api.GetWarband = nil
		assert.equal("Own", AD.Source(), "an API missing a function SwagBag reads is not used")
		A.globals.Syndicator = nil
		assert.equal("Own", AD.Source())
	end)

	it("lists Syndicator's characters with canonical keys, the current one first, hidden ones left out", function()
		local list, source = AD.Characters()
		assert.equal("Syndicator", source)
		assert.equal(2, #list)
		assert.same({ key = "Swagger-ArgentDawn", name = "Swagger", realm = "Argent Dawn", class = "MAGE", current = true },
			list[1])
		assert.equal("Abby-ArgentDawn", list[2].key)
	end)

	-- Mutation: map bags[i] to bag i instead of i - 1.
	it("containers: bags[i] is bag i - 1, bank tab i is bag 5 + i, warband tab i is bag 11 + i", function()
		local bags = AD.Container("Abby-ArgentDawn", "bags")
		assert.same({ link = "item:210796", count = 20 }, bags.containers[0].slots[1])
		assert.equal(2, bags.containers[0].size)
		assert.is_nil(bags.containers[1], "an empty bag is left out")
		local bank = AD.Container("Abby-ArgentDawn", "bank")
		assert.same({ link = "item:210930", count = 100 }, bank.containers[6].slots[2])
		local warband, source = AD.Container("Abby-ArgentDawn", "warband")
		assert.equal("Syndicator", source)
		assert.same({ link = "item:156654", count = 7 }, warband.containers[12].slots[3])
	end)

	it("the guild bank, and a character Syndicator does not have, come from SwagBag's own snapshots", function()
		SB.Snapshots.DB().chars["Abby-Argent Dawn"] = { guild = "Tidewatch-Argent Dawn" }
		SB.Snapshots.DB().guilds["Tidewatch-Argent Dawn"] = { tabs = { [1] = "Mats" },
			snapshot = { v = 1, containers = { [1] = { size = 98, s = "4:item:212283;3\n" } } } }
		local guild, source = AD.Container("Abby-ArgentDawn", "guild")
		assert.equal("Own", source)
		assert.equal("Tidewatch", guild.title)
		SB.Snapshots.DB().chars["Ghost-Argent Dawn"] = { bags = { v = 1, containers = { [0] = { size = 16,
			s = "1:item:211880;1\n" } } } }
		local _, ghostSource = AD.Container("Ghost-ArgentDawn", "bags")
		assert.equal("Own", ghostSource)
	end)

	-- Mutation: drop mail from the counted fields.
	it("counts: per character with mail and auctions (what only Syndicator tracks), the warband bank and guilds", function()
		local c, source = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal("Syndicator", source)
		assert.equal(2, #c.chars, "a character with none is left out")
		assert.truthy(c.chars[1].current)
		assert.same({ key = "Abby-ArgentDawn", name = "Abby", class = "PRIEST", current = false, bags = 20, bank = 0, mail = 2,
			equipped = 0, auctions = 1, void = 0 }, c.chars[2])
		assert.equal(7, c.warband)
		assert.same({ { key = "Tidewatch-ArgentDawn", name = "Tidewatch", count = 3 } }, c.guilds)
	end)

	it("an item Syndicator knows nothing about is counted by SwagBag's own data", function()
		local c, source = AD.Counts(Fixtures.FLASK)
		assert.equal("Own", source)
		assert.equal(2, c.chars[1].bags)
	end)

	-- Spec 3.3. Mutation: in Providers/Syndicator.lua, pcall GetInventoryInfoByItemID and return nil.
	it("three errors switch Syndicator off for the session, with one line; SwagBag's own data answers", function()
		api.broken = true
		for _ = 1, 3 do
			local _, source = AD.Counts(Fixtures.HEALING_POTION)
			assert.equal("Own", source)
		end
		assert.same({ SB.L.ALTDATA_PROVIDER_OFF:format("Syndicator") }, A.Lines())
		api.broken = false
		local _, source = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal("Own", source, "stays off this session")
		assert.equal(3, api.calls)
	end)

	-- Mutation: in the SB_LOGIN handler, emit without SB.Debounce.
	it("Syndicator's updates announce SB_ALTDATA_CHANGED once, after the burst, trapped as 'none'", function()
		local n = 0
		SB.On("SB_ALTDATA_CHANGED", function() n = n + 1 end)
		SB.Emit("SB_LOGIN")
		assert.truthy(reg.events.BagCacheUpdate and reg.events.WarbandBankCacheUpdate and reg.events.GuildCacheUpdate
			and reg.events.Ready)
		reg.events.BagCacheUpdate("x")
		reg.events.WarbandBankCacheUpdate()
		A.Advance(0.6)
		assert.equal(1, n)
	end)

	-- Week 8 (week-5 deferred). Mutation: delete the provider's SB.On("ADDON_LOADED", ...) registration.
	it("Syndicator loaded after login: its callbacks are registered then, and the switch is announced at once",
		function()
			A.globals.Syndicator = nil
			local n = 0
			SB.On("SB_ALTDATA_CHANGED", function() n = n + 1 end)
			SB.Emit("SB_LOGIN")
			assert.equal("Own", AD.Source())
			A.globals.Syndicator = { API = api, CallbackRegistry = reg }
			SB.eventFrame:Fire("ADDON_LOADED", "SomethingElse")
			assert.is_nil(reg.events.BagCacheUpdate)
			SB.eventFrame:Fire("ADDON_LOADED", "Syndicator")
			assert.truthy(reg.events.BagCacheUpdate and reg.events.Ready)
			assert.equal("Syndicator", AD.Source())
			A.Advance(0.6)
			assert.equal(1, n, "tooltip counts and the alt viewer hear of the switch without waiting")
			reg.events.BagCacheUpdate("x")
			A.Advance(0.6)
			assert.equal(2, n, "and of Syndicator's later updates")
		end)

	-- Week 8 (final review). Mutation: delete the SB.Debounce("syndicator.hook", ...) retry (or drop `P.retried`
	-- so it tries on every ADDON_LOADED of Syndicator forever).
	it("a hook that fails at Syndicator's ADDON_LOADED is tried once more a moment later, once only", function()
		A.globals.Syndicator = nil
		SB.Emit("SB_LOGIN")
		A.globals.Syndicator = { API = api } -- the registry is not there yet
		SB.eventFrame:Fire("ADDON_LOADED", "Syndicator")
		assert.falsy(SB.SyndicatorProvider and SB.SyndicatorProvider.hooked)
		assert.is_nil(reg.events.BagCacheUpdate)
		A.globals.Syndicator = { API = api, CallbackRegistry = reg }
		A.Advance(1.1)
		assert.truthy(reg.events.BagCacheUpdate and reg.events.Ready, "the retry hooked it")
		A.Advance(0.6)
		assert.equal("Syndicator", AD.Source())
	end)

	it("the hook retry runs once: after a second failure no further try is armed", function()
		A.globals.Syndicator = nil
		SB.Emit("SB_LOGIN")
		A.globals.Syndicator = { API = api }
		SB.eventFrame:Fire("ADDON_LOADED", "Syndicator")
		A.Advance(1.1) -- the one retry fails too
		SB.eventFrame:Fire("ADDON_LOADED", "Syndicator") -- fails again: no new retry is armed
		A.globals.Syndicator = { API = api, CallbackRegistry = reg }
		A.Advance(5)
		assert.is_nil(reg.events.BagCacheUpdate)
	end)

	-- Mutation: in P.Hook, drop `if P.hooked then return true end` (every ADDON_LOADED would register again).
	it("Syndicator's callbacks are registered once: at login, never again on a later ADDON_LOADED", function()
		local registered = 0
		local register = reg.RegisterCallback
		reg.RegisterCallback = function(...)
			registered = registered + 1
			return register(...)
		end
		SB.Emit("SB_LOGIN")
		local once = registered
		assert.truthy(once > 0)
		SB.eventFrame:Fire("ADDON_LOADED", "Syndicator")
		assert.equal(once, registered)
	end)

	-- F18. Mutation: drop the AltData.OwnGuildCounts append in P.counts.
	it("counts: guilds only SwagBag has seen are appended; a guild Syndicator reported is not counted twice", function()
		local G = SB.Snapshots.DB().guilds
		G["Vault-Argent Dawn"] = { snapshot = { v = 1, containers = { [1] = { size = 98, s = "4:item:211880;5\n" } } } }
		G["Tidewatch-Argent Dawn"] = { snapshot = { v = 1, containers = { [1] = { size = 98, s = "4:item:211880;9\n" } } } }
		local c, source = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal("Syndicator", source)
		assert.same({ { key = "Tidewatch-ArgentDawn", name = "Tidewatch", count = 3 },
			{ key = "Vault-ArgentDawn", name = "Vault", count = 5 } }, c.guilds)
	end)

	-- F19. Mutation: remove the SB_ALTDATA_CHANGED listener in Engine/AltData.lua.
	it("SB_ALTDATA_CHANGED bumps AltData.Generation and makes every provider drop its cache", function()
		local dropped = 0
		SB.SyndicatorProvider.invalidate = function() dropped = dropped + 1 end
		local before = AD.Generation()
		SB.Emit("SB_ALTDATA_CHANGED", "Syndicator")
		assert.equal(before + 1, AD.Generation())
		assert.equal(1, dropped)
		SB.SyndicatorProvider.invalidate = function() error("cache gone wrong") end
		SB.Emit("SB_ALTDATA_CHANGED", "Syndicator") -- trapped: nothing escapes
		assert.equal(before + 2, AD.Generation())
	end)

	it("the provider's name cache finds a character Syndicator learns after it was filled", function()
		assert.truthy(AD.Container("Abby-ArgentDawn", "bags"))
		api.chars["Newbie-ArgentDawn"] = { details = { character = "Newbie", realm = "Argent Dawn", show = { inventory = true } },
			bags = { { [1] = { itemLink = "item:211880", itemCount = 1 } } } }
		local c, source = AD.Container("Newbie-ArgentDawn", "bags")
		assert.equal("Syndicator", source)
		assert.equal(1, c.containers[0].size)
	end)

	it("a secret link or count from Syndicator is left out, never read", function()
		A.IsSecret = function(v) return v == "item:210796" end
		local bags = AD.Container("Abby-ArgentDawn", "bags")
		assert.is_nil(bags.containers[0].slots[1], "the secret link is dropped")
		assert.equal(2, bags.containers[0].size)
	end)

	it("a Syndicator problem is recorded under 'none' and never puts the bags in Safe Mode", function()
		api.broken = true
		for _ = 1, 3 do
			AD.Counts(Fixtures.HEALING_POTION)
		end
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	-- Ruling W5-8. Mutation: drop the empty -> nil check in P.counts.
	it("an item Syndicator reports as empty (its real answer for an unknown item) is counted by Own", function()
		local id = Fixtures.FLASK
		local info = api.GetInventoryInfoByItemID(id)
		assert.equal(0, #info.characters)
		local c, source = AD.Counts(id)
		assert.equal("Own", source)
		assert.equal(2, c.chars[1].bags)
	end)

	it("an empty Syndicator answer still lets Own's guild banks be counted, and a pet cage goes to Own", function()
		SB.Snapshots.DB().guilds["Vault-Argent Dawn"] = { snapshot = { v = 1, containers = { [1] = { size = 98,
			s = "4:item:" .. Fixtures.FLASK .. ";5\n" } } } }
		local c, source = AD.Counts(Fixtures.FLASK)
		assert.equal("Own", source)
		assert.equal(5, c.guilds[1].count)
		local before = api.calls
		local _, petSource = AD.Counts(AD.PET_CAGE)
		assert.equal("Own", petSource)
		assert.equal(before, api.calls, "Syndicator is not asked about a caged pet")
	end)

	-- Ruling W5-9. Mutation: mark current by SwagBag's key only.
	it("the current character is found through Syndicator's own key when it is regional (Name-PvE)", function()
		api.chars["Swagger-PvE"] = api.chars["Swagger-ArgentDawn"]
		api.chars["Swagger-ArgentDawn"] = nil
		api.current = "Swagger-PvE"
		local list = AD.Characters()
		assert.equal("Swagger-PvE", list[1].key)
		assert.equal(true, list[1].current)
		assert.equal(false, list[2].current)
		assert.equal("Swagger-PvE", A.SyndicatorCurrentKey())
		api.GetCurrentCharacter = nil
		assert.is_nil(A.SyndicatorCurrentKey())
	end)

	it("a key Syndicator never has rebuilds the name cache once, not on every call", function()
		AD.Container("Abby-ArgentDawn", "bags")
		local start = api.listCalls
		for _ = 1, 4 do
			AD.Container("Nobody-ArgentDawn", "bags")
		end
		assert.equal(start + 1, api.listCalls)
	end)

	it("a failure in Syndicator's callback is recorded under 'none', never Safe Mode", function()
		SB.Emit("SB_LOGIN")
		SB.Debounce = function() error("boom") end
		reg.events.MailCacheUpdate()
		local last = SB.ErrorTrap.Recent()
		last = last[#last] or last[1]
		assert.equal("none", last.window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	-- F18 with a hyphenated realm: Own's "Vault-Azjol-Nerub" and Syndicator's "AzjolNerub" are one guild.
	it("counts: a hyphenated realm names the same guild in both sources", function()
		local G = SB.Snapshots.DB().guilds
		G["Tidewatch-Azjol-Nerub"] = { snapshot = { v = 1, containers = { [1] = { size = 98, s = "4:item:211880;9\n" } } } }
		G["Vault-Azjol-Nerub"] = { snapshot = { v = 1, containers = { [1] = { size = 98, s = "4:item:211880;5\n" } } } }
		local old = api.GetInventoryInfoByItemID
		api.GetInventoryInfoByItemID = function(id)
			local info = old(id)
			info.guilds = { { guild = "Tidewatch", realmNormalized = "AzjolNerub", bank = 3 } }
			return info
		end
		local c = AD.Counts(Fixtures.HEALING_POTION)
		assert.same({ { key = "Tidewatch-AzjolNerub", name = "Tidewatch", count = 3 },
			{ key = "Vault-AzjolNerub", name = "Vault", count = 5 } }, c.guilds)
	end)

	it("the report names the alt data source and how many characters it has", function()
		Loader.LoadFile(SB, "SwagBag/Core/Checks.lua")
		Loader.LoadFile(SB, "SwagBag/Core/Report.lua")
		assert.truthy(SB.Report.Build():find("Alt data: Syndicator, 2 characters", 1, true))
		A.globals.Syndicator = nil
		assert.truthy(SB.Report.Build():find("Alt data: Own, 0 characters", 1, true))
	end)

	it("wealth comes from Syndicator's saved money and currencies", function()
		api.chars["Swagger-ArgentDawn"].money = 10000
		api.chars["Swagger-ArgentDawn"].currencies = { [3008] = 4 }
		api.chars["Abby-ArgentDawn"].money = 50
		local list, source = AD.Wealth()
		assert.equal("Syndicator", source)
		assert.equal(2, #list) -- the hidden character is left out
		assert.same({ key = "Swagger-ArgentDawn", name = "Swagger", realm = "Argent Dawn", class = "MAGE", current = true,
			money = 10000, currencies = { [3008] = 4 } }, list[1])
		assert.equal("Abby-ArgentDawn", list[2].key)
		assert.equal(50, list[2].money)
		assert.equal(false, list[2].current)
	end)

	it("wealth leaves out a character with no money and no currencies; keeps one with currencies only", function()
		api.chars["Swagger-ArgentDawn"].money = 10000
		api.chars["Zed-ArgentDawn"] = { details = { character = "Zed", realm = "Argent Dawn", className = "ROGUE",
			show = { inventory = true } }, currencies = { [3008] = 9 } }
		local list, source = AD.Wealth()
		assert.equal("Syndicator", source)
		assert.equal(2, #list) -- Abby has neither: left out, never shown as 0
		assert.equal("Swagger-ArgentDawn", list[1].key)
		assert.equal("Zed-ArgentDawn", list[2].key)
		assert.is_nil(list[2].money)
		assert.same({ [3008] = 9 }, list[2].currencies)
	end)

	-- Final review. Mutation: P.wealth lists only Syndicator's shown characters (a hidden current one vanishes).
	it("wealth adds the current character with its live gold when Syndicator hides it", function()
		api.chars["Swagger-ArgentDawn"].details.show.inventory = false
		api.chars["Abby-ArgentDawn"].money = 50
		A.money = 999
		local list, source = AD.Wealth()
		assert.equal("Syndicator", source)
		local mine
		for _, e in ipairs(list) do
			if e.current then
				mine = e
			end
		end
		assert.truthy(mine)
		assert.equal(999, mine.money)
		assert.equal("Swagger", mine.name)
		assert.equal(2, #list)
	end)

	it("a Syndicator without money hands wealth to Own", function()
		local _, source = AD.Wealth()
		assert.equal("Own", source)
	end)

	it("a secret or non-number currency is skipped", function()
		local d = api.chars["Swagger-ArgentDawn"]
		d.money = 5
		d.currencies = { [3008] = "x", [3009] = 7, [3010] = 2 }
		A.IsSecret = function(v) return v == 2 end
		local list = AD.Wealth()
		assert.is_nil(list[1].currencies[3008])
		assert.is_nil(list[1].currencies[3010])
		assert.equal(7, list[1].currencies[3009])
	end)
end)

describe("Adapter: Syndicator and currency reads (the real Adapter.lua)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		Syndicator, C_CurrencyInfo, issecretvalue = nil, nil, nil
	end)

	it("SyndicatorAPI reads only Syndicator's public names and never errors", function()
		assert.is_nil(A.SyndicatorAPI())
		local api = fakeSyndicator()
		Syndicator = { API = api }
		assert.equal(api, A.SyndicatorAPI())
		api.IsReady = function() error("not yet") end
		assert.is_nil(A.SyndicatorAPI())
	end)

	it("SyndicatorOnUpdate registers for every event, or says there is no registry", function()
		assert.equal(false, A.SyndicatorOnUpdate(function() end))
		local _, reg = fakeSyndicator()
		Syndicator = { CallbackRegistry = reg }
		assert.equal(true, A.SyndicatorOnUpdate(function() end))
		for _, event in ipairs(A.SYNDICATOR_EVENTS) do
			assert.truthy(reg.events[event], event)
		end
	end)

	-- Week-4 deferred. Mutation: drop the isSecret(info.isHeader) check in CurrencyList.
	it("CurrencyList skips a line whose header flag is secret", function()
		issecretvalue = function(v) return v == false end -- the first row's flag reads false, but secret
		local rows = { { name = "Header", isHeader = false, quantity = 1 }, { name = "Crest", quantity = 4 } }
		C_CurrencyInfo = {
			GetCurrencyListSize = function() return #rows end,
			GetCurrencyListInfo = function(i) return rows[i] end,
			GetCurrencyListLink = function(i) return "currency:" .. i end,
			GetCurrencyIDFromLink = function(link) return tonumber(link:match("%d+")) + 3000 end,
		}
		local list = A.CurrencyList()
		assert.equal(1, #list)
		assert.equal("Crest", list[1].name)
	end)
end)
