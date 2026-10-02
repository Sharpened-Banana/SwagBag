-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip ItemRefTooltip TooltipDataProcessor Enum
-- luacheck: globals RAID_CLASS_COLORS issecretvalue
-- Tooltip counts (UI/TooltipCounts.lua, spec AC13.3): lines per character, the warband bank and
-- guilds under item tooltips, from Engine/AltData.lua; a setting; a hook that never breaks bags.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Tooltip counts", function()
	local SB, A, TC, lines
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/Engine/Snapshots.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/AltData.lua")
		SB.Inventory.ScanAll()
		lines = {}
		A.TooltipLine = function(_, left, right) lines[#lines + 1] = { left, right } end
		A.ClassColour = function() return nil end
		A.HookItemTooltip = function(fn) A.tooltipHook = fn return true end
		SB.BagsWindow = { View = function() return "sections" end }
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/TooltipCounts.lua")
		TC = SB.TooltipCounts
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function abby(bags, bank)
		SB.Snapshots.DB().chars["Abby-Argent Dawn"] = { class = "PRIEST",
			bags = { v = 1, containers = { [0] = { size = 16, s = bags or "" } } },
			bank = { v = 1, containers = { [6] = { size = 98, s = bank or "" } } } }
	end

	-- Mutation: in TC.Lines, drop the warband line.
	it("lines: the total, one per character with where, the warband bank and guild banks", function()
		local out = TC.Lines({ chars = {
			{ name = "Swagger", current = true, bags = 5, bank = 0 },
			{ name = "Abby", bags = 20, bank = 100, mail = 2, auctions = 1 },
		}, warband = 7, guilds = { { name = "Tidewatch", count = 3 } } })
		assert.same({
			{ "SwagBag: 138 in all" },
			{ "Swagger (this character)", "Bags 5" },
			{ "Abby", "Bags 20, Bank 100, Mail 2, Auctions 1" },
			{ "Warband bank", "7" },
			{ "Tidewatch (guild bank)", "3" },
		}, out)
	end)

	-- Mutation: in TC.Lines, drop the "elsewhere" check (always show).
	it("nothing is added when the only place is this character's bags, or when there is nothing", function()
		assert.same({}, TC.Lines({ chars = { { name = "Swagger", current = true, bags = 5, bank = 0 } }, warband = 0,
			guilds = {} }))
		assert.same({}, TC.Lines({ chars = {}, warband = 0, guilds = {} }))
		assert.same({}, TC.Lines(nil))
		assert.equal(2, #TC.Lines({ chars = { { name = "Swagger", current = true, bags = 5, bank = 2 } } }),
			"this character's bank counts as elsewhere")
	end)

	it("an item only in this character's bags gets no lines through the hook either", function()
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.same({}, lines)
	end)

	it("at most eight characters, then how many more", function()
		local chars = {}
		for i = 1, 10 do
			chars[i] = { name = "Alt" .. i, bags = 1 }
		end
		local out = TC.Lines({ chars = chars })
		assert.equal(10, #out)
		assert.same({ "...and 2 more characters" }, out[10])
	end)

	it("a character's name takes its class colour when the client has one", function()
		A.ClassColour = function(class) return class == "PRIEST" and "|cffffffff" or nil end
		local out = TC.Lines({ chars = { { name = "Abby", class = "PRIEST", bags = 1 } } })
		assert.equal("|cffffffffAbby|r", out[2][1])
	end)

	it("the hook adds the lines for the hovered item from the alt data", function()
		abby("1:item:211880;20\n")
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.same({ "SwagBag: 25 in all" }, lines[1])
		assert.same({ "Swagger (this character)", "Bags 5" }, lines[2])
		assert.same({ "Abby", "Bags 20" }, lines[3])
	end)

	-- A pet cage is counted by its item ID (Own decodes battle pet links to it).
	it("a pet cage in another character's bags is counted", function()
		abby("1:battlepet:1234:25:3;2\n")
		A.tooltipHook("tooltip", Fixtures.PET_CAGE)
		assert.same({ "SwagBag: 2 in all" }, lines[1])
		assert.same({ "Abby", "Bags 2" }, lines[2])
	end)

	-- F21. Mutation: drop the memo (always call AltData.Counts).
	it("a second refresh of the same tooltip does no AltData work", function()
		abby("1:item:211880;20\n")
		local calls, real = 0, SB.AltData.Counts
		SB.AltData.Counts = function(id) calls = calls + 1 return real(id) end
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		local first = #lines
		assert.equal(1, calls)
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.equal(1, calls, "the memo answered")
		assert.equal(first * 2, #lines, "the lines are added again")
	end)

	-- F21. Mutation: drop one of the Forget listeners.
	it("the memo is dropped on bag changes, saved snapshots, Syndicator changes and settings", function()
		local calls, real = 0, SB.AltData.Counts
		SB.AltData.Counts = function(id) calls = calls + 1 return real(id) end
		local n = 0
		local function hover()
			A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
			n = n + 1
		end
		hover()
		hover()
		assert.equal(1, calls)
		for _, forget in ipairs({
			function() SB.Emit("BAG_UPDATE_DELAYED") end,
			function() SB.Inventory.Notify(0, {}) end,
			function() SB.Emit("SB_SNAPSHOT_SAVED", "bags", "Abby-Argent Dawn") end,
			function() SB.Emit("SB_ALTDATA_CHANGED", "Syndicator") end,
			function() SB.Config.Set("tooltip.counts", "on") end,
		}) do
			local before = calls
			forget()
			hover()
			assert.equal(before + 1, calls)
			hover()
			assert.equal(before + 1, calls)
		end
	end)

	-- F20 is in the Adapter (below): the hook is only called for the main and link tooltips.

	-- P6. Mutation: hook TC.Add directly instead of through ErrorTrap.Guard.
	it("an error while counting is recorded as 'none' and never takes the bags to Safe Mode", function()
		SB.AltData.Counts = function() error("counts broke") end
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.equal("tooltip.counts", SB.ErrorTrap.Recent()[1].label)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	-- Mutation: in TC.Showing, ignore whether Syndicator is loaded.
	it("auto: not shown while Syndicator is loaded (it writes its own); on: always; off: never", function()
		abby("1:item:211880;20\n")
		A.addons.Syndicator = "284"
		local calls, real = 0, SB.AltData.Counts
		SB.AltData.Counts = function(id) calls = calls + 1 return real(id) end
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.same({}, lines)
		assert.equal(0, calls, "no AltData work either")
		SB.Config.Set("tooltip.counts", "on")
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.truthy(#lines > 0)
		lines = {}
		SB.Config.Set("tooltip.counts", "off")
		A.addons.Syndicator = nil
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.same({}, lines)
	end)

	it("auto without Syndicator shows the lines", function()
		abby("1:item:211880;20\n")
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.truthy(#lines > 0)
	end)

	it("/swagbag tooltip answers every form; read-only refuses", function()
		SB.Slash.Dispatch("tooltip")
		SB.Slash.Dispatch("tooltip off")
		SB.Slash.Dispatch("tooltip maybe")
		assert.same({ "Tooltip counts: shown unless Syndicator shows them. Use /swagbag tooltip auto, on or off.",
			"Tooltip counts: hidden.", "Tooltip counts: hidden. Use /swagbag tooltip auto, on or off." }, A.Lines())
		SB.Config.readOnly = true
		SB.Slash.Dispatch("tooltip on")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[4])
		assert.equal("off", TC.Mode())
	end)

	it("Settings > Alt data: shown first and selected; a click runs /swagbag tooltip; the note names the source", function()
		local SW = SB.SettingsWindow
		SW.Show("alts")
		assert.equal(SB.L.SET_TIP_AUTO, SW.buttons[1].text)
		assert.truthy(SW.selected[SW.buttons[1]])
		Fake.Fire(SW.buttons[3], "OnClick")
		assert.equal("off", TC.Mode())
		assert.equal("Tooltip counts: hidden.", SW.lastStatus)
		local note = SW.labels[SW.used.labels].text
		assert.truthy(note:find("SwagBag's own saved bags", 1, true), note)
	end)

	it("Settings > Alt data in read-only mode refuses with the read-only line", function()
		local SW = SB.SettingsWindow
		SW.Show("alts")
		SB.Config.readOnly = true
		Fake.Fire(SW.buttons[2], "OnClick")
		assert.equal(SB.L.SETTINGS_READONLY, SW.lastStatus)
		assert.equal("auto", TC.Mode())
	end)
end)

describe("Tooltip counts load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(Env.ENGINE)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/Engine/Snapshots.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/AltData.lua")
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.BagsWindow = { View = function() return "sections" end }
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/TooltipCounts.lua")
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)

describe("Adapter.HookItemTooltip (the real Adapter.lua)", function()
	local A
	before_each(function()
		local SB = {}
		Fake.Install()
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		TooltipDataProcessor, Enum, RAID_CLASS_COLORS, issecretvalue, ItemRefTooltip = nil, nil, nil, nil, nil
		Fake.Uninstall()
	end)

	-- Mutation: drop countsTooltip's check in the post-call.
	it("uses TooltipDataProcessor's item post-call and passes the item ID; a secret ID is skipped", function()
		local post
		TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) assert.equal(0, kind) post = fn end }
		Enum = { TooltipDataType = { Item = 0 } }
		local seen = {}
		assert.truthy(A.HookItemTooltip(function(_, id) seen[#seen + 1] = id end))
		post(GameTooltip, { id = 211880 })
		post(GameTooltip, {})
		issecretvalue = function(v) return v == 5 end
		post(GameTooltip, { id = 5 })
		assert.same({ 211880 }, seen)
	end)

	-- F20. Mutation: remove the tooltip check (call fn for every tooltip).
	it("only the main and the link tooltip get counts, never comparison or embedded tooltips", function()
		local post
		TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) post = fn end }
		Enum = { TooltipDataType = { Item = 0 } }
		ItemRefTooltip = Fake.New("GameTooltip")
		local shopping, embedded = Fake.New("GameTooltip"), Fake.New("Frame")
		local seen = {}
		A.HookItemTooltip(function(tooltip) seen[#seen + 1] = tooltip end)
		post(GameTooltip, { id = 1 })
		post(ItemRefTooltip, { id = 1 })
		post(shopping, { id = 1 })
		post(embedded, { id = 1 })
		post(nil, { id = 1 })
		assert.same({ GameTooltip, ItemRefTooltip }, seen)
	end)

	it("falls back to OnTooltipSetItem on the main and the link tooltip without the processor", function()
		ItemRefTooltip = Fake.New("GameTooltip")
		assert.truthy(A.HookItemTooltip(function() end))
		assert.equal(1, #GameTooltip.hooks.OnTooltipSetItem)
		assert.equal(1, #ItemRefTooltip.hooks.OnTooltipSetItem)
	end)

	it("ClassColour reads the client's class colours", function()
		assert.is_nil(A.ClassColour("MAGE"))
		RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
		assert.equal("|cff3fc7eb", A.ClassColour("MAGE"))
	end)
end)
