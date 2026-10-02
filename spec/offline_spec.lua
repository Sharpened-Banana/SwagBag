-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The alt viewer (UI/OfflineWindow.lua, UI/DisplayButtons.lua; spec Views.Offline, AC13.2): a saved
-- character's bags, bank, the warband bank and its guild bank as read-only groups with search.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local function loadOffline(SB)
	Env.FakeBags(SB)
	for _, path in ipairs({ "SwagBag/Engine/Snapshots.lua", "SwagBag/Engine/AltData.lua", "SwagBag/UI/Buttons.lua",
		"SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/SearchBox.lua", "SwagBag/UI/GroupView.lua",
		"SwagBag/UI/DisplayButtons.lua", "SwagBag/UI/OfflineWindow.lua", "SwagBag/UI/Overlays.lua" }) do
		Loader.LoadFile(SB, path)
	end
	return SB.OfflineWindow
end

describe("Alt viewer", function()
	local SB, A, OW, DB
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Env.PaintGlobals()
		OW = loadOffline(SB)
		SB.Inventory.ScanAll()
		DB = SB.DisplayButtons
		SB.Categories.Load()
		local db = SB.Snapshots.DB()
		db.chars["Abby-Argent Dawn"] = { class = "PRIEST", lastSeen = A.Time() - 7200, guild = "Tidewatch-Argent Dawn",
			bags = { v = 1, at = A.Time() - 2 * 86400, containers = { [0] = { size = 16,
				s = "1:item:211880;20\n2:item:225001;1\n4:item:156654;3\n" } } },
			bank = { v = 1, at = A.Time() - 3600, containers = { [6] = { size = 98, s = "5:item:210930;100\n" } } } }
		db.warband = { v = 1, at = A.Time() - 600, containers = { [12] = { size = 98, s = "2:item:212283;7\n" } } }
		db.guilds["Tidewatch-Argent Dawn"] = { tabs = { [1] = "Mats" }, snapshot = { v = 1, at = A.Time() - 60,
			containers = { [1] = { size = 98, s = "4:item:210796;50\n" } } } }
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
	end)

	local function groupHeaders()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId:sub(1, 1) == "#" then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	local function sectionHeaders()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId:sub(1, 1) ~= "#" then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	-- AC13.2. Mutation: in OW.Load, drop the "guild" kind from OW.KINDS.
	it("/swagbag alts <name> shows the character's bags, bank, the warband bank and its guild bank, with ages", function()
		SB.Slash.Dispatch("alts abby")
		assert.truthy(OW.IsOpen())
		assert.same({ "Showing the saved items of Abby." }, A.Lines())
		assert.equal("SwagBag — Abby (saved)", OW.frame.title.text)
		assert.same({ "- Bags (3) - 2 days ago", "- Bank (1) - 1 h ago", "- Warband bank (1) - 10 min ago",
			"- Guild bank: Tidewatch (1) - 1 min ago" }, groupHeaders())
		assert.same({ "- Consumables (1)", "- BoE gear (1)", "- Junk (1)", "- Ore (1)", "- Consumables (1)",
			"- Herbs (1)" }, sectionHeaders())
	end)

	-- Item safety: these are never item buttons. Mutation: create them with "ContainerFrameItemButtonTemplate".
	it("items are SwagBag's own plain display buttons, made only for saved items, never a template", function()
		OW.Open("Abby-ArgentDawn")
		local made = 0
		for _, f in ipairs(Fake.created) do
			if f.kind == "ItemButton" then
				made = made + 1
				assert.is_nil(rawget(f, "template"), "no template, nothing secure")
			end
		end
		assert.equal(6, made, "one per saved item, none for empty saved slots")
		local potion = DB.Get(0, 1)
		assert.truthy(potion.shown)
		assert.equal(20, potion.count)
	end)

	-- P2. Mutation: in OW.ClickSlot, return without the flash.
	it("a click answers that saved items cannot be used; a modified click links the item instead", function()
		OW.Open("Abby-ArgentDawn")
		local potion = DB.Get(0, 1)
		Fake.Fire(potion, "OnClick", "RightButton")
		assert.equal(SB.L.OFFLINE_READONLY, OW.frame.title.text)
		A.Advance(1.6)
		assert.equal("SwagBag — Abby (saved)", OW.frame.title.text)
		A.modified = true
		assert.equal("link", OW.ClickSlot(0, 1))
	end)

	it("hovering shows the item's tooltip from its saved link", function()
		local shown
		A.LinkTooltip = function(owner, link) shown = { owner, link } end
		OW.Open("Abby-ArgentDawn")
		local potion = DB.Get(0, 1)
		Fake.Fire(potion, "OnEnter")
		assert.same({ potion, "item:211880" }, shown)
	end)

	-- AC5.1 in the alt viewer. Mutation: in OW.Layout, drop searchBox.Apply().
	it("its own search dims what does not match, and keywords see where a saved item is", function()
		OW.Open("Abby-ArgentDawn")
		OW.searchBox.editBox:SetText("bank")
		OW.searchBox.Run()
		assert.equal(1, DB.Get(6, 5).alpha, "the bank's ore matches 'bank'")
		assert.equal(0.2, DB.Get(0, 1).alpha, "the bags' potion is dimmed")
		SB.Snapshots.Save("bags")
		OW.Open("Swagger-ArgentDawn")
		assert.equal(0.2, DB.Get(0, 6).alpha, "a button new to this layout is dimmed too: the search applies again")
	end)

	-- Mutation: in OverlayData.CanCompare, drop the record.offline check.
	it("a saved item never shows the upgrade arrow (it may be another character's)", function()
		A.equipped = { [11] = { ilvl = 100, equipLoc = "INVTYPE_FINGER" }, [12] = { ilvl = 100, equipLoc = "INVTYPE_FINGER" } }
		OW.Open("Abby-ArgentDawn")
		local ring = DB.Get(0, 2)
		assert.falsy(SB.Overlays.regions[ring].arrow.shown)
		assert.equal("285", SB.Overlays.regions[ring].topLeft.text, "other overlays still show")
	end)

	it("this character by default; nothing saved yet says so and still opens", function()
		SB.Slash.Dispatch("alts")
		assert.same({ "Showing the saved items of Swagger." }, A.Lines())
		assert.equal(SB.L.OFFLINE_NOTHING:format("Swagger"), OW.frame.source.text)
		assert.same({ "- Warband bank (1) - 10 min ago" }, groupHeaders(), "the warband bank is the account's")
	end)

	it("an unknown name lists the saved characters", function()
		SB.Snapshots.Save("bags")
		SB.Slash.Dispatch("alts zed")
		assert.same({ "No saved character named \"zed\". Saved: Swagger, Abby." }, A.Lines())
		assert.falsy(OW.IsOpen())
	end)

	-- P2: every form answers. Mutation: in the alts command, return nothing for an unknown name.
	it("an unknown name with no characters saved at all still answers", function()
		SB.Snapshots.DB().chars = {}
		SB.Slash.Dispatch("alts zed")
		assert.same({ "No saved character named \"zed\". Saved: none." }, A.Lines())
		assert.falsy(OW.IsOpen())
	end)

	-- Review Focus 5. Mutation: in OW.Load, keep slots whose OW.Info is nil.
	it("a damaged saved line or a link with no item ID is skipped: no button, no error", function()
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "3:garbage;1\n7:|cff00ccff|Hcurrency:3008|h[Crest]|h|r;5\nnot a line\n"
		OW.Open("Abby-ArgentDawn")
		assert.same({ "- Bags (3) - 2 days ago", "- Bank (1) - 1 h ago", "- Warband bank (1) - 10 min ago",
			"- Guild bank: Tidewatch (1) - 1 min ago" }, groupHeaders())
		assert.is_nil(DB.buttons[0][3])
		assert.is_nil(DB.buttons[0][7])
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	it("another character replaces the first: its buttons hide, the new ones show", function()
		SB.Snapshots.Save("bags")
		OW.Open("Abby-ArgentDawn")
		local abbyPotion = DB.Get(0, 1)
		OW.Open("Swagger-ArgentDawn")
		assert.equal("SwagBag — Swagger (saved)", OW.frame.title.text)
		assert.truthy(abbyPotion.shown, "slot 0:1 holds Swagger's potion now")
		assert.equal(5, abbyPotion.count)
		assert.falsy(DB.Get(6, 5).shown, "Abby's bank item is gone")
	end)

	it("Esc or the X hides it and clears the view; reopening lays it out again", function()
		OW.Open("Abby-ArgentDawn")
		OW.Close()
		assert.falsy(DB.Get(0, 1).shown)
		assert.falsy(OW.view.IsOpen())
		assert.truthy(UISpecialFrames[#UISpecialFrames] == "SwagBagOfflineWindow")
		OW.Open("Abby-ArgentDawn")
		assert.truthy(DB.Get(0, 1).shown)
	end)

	-- P6: "none". Mutation: give DisplayButtons' OnClick the window "bags".
	it("an error in a click is recorded as 'none' and never takes the bags or bank to Safe Mode", function()
		OW.Open("Abby-ArgentDawn")
		DB.onClick = function() error("click broke") end
		Fake.Fire(DB.Get(0, 1), "OnClick", "LeftButton")
		assert.equal("offline.click", SB.ErrorTrap.Recent()[1].label)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	-- F22: after a patch the item cache is empty. Mutation: in OfflineWindow, drop the
	-- SB.On("ITEM_DATA_LOAD_RESULT", ...) registration (the item stays in New).
	it("an item whose data has not loaded waits in New and moves to its category once it loads", function()
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "9:item:" .. Fixtures.UNLOADED .. ";1\n"
		OW.Open("Abby-ArgentDawn")
		assert.equal("- New (1)", sectionHeaders()[1], "pending: New, never Free")
		local chest = DB.Get(0, 9)
		assert.truthy(chest.shown)
		A.items[Fixtures.UNLOADED] = { name = "Chest of Tests", classID = A.ITEM_CLASS.Armor, subclassID = 4,
			equipLoc = "INVTYPE_CHEST", quality = 3, ilvl = 270, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		assert.equal("- New (1)", sectionHeaders()[1], "debounced: not yet")
		A.Advance(OW.LOADED_DELAY)
		assert.same({ "- Consumables (1)", "- BoE gear (2)", "- Junk (1)", "- Ore (1)", "- Consumables (1)",
			"- Herbs (1)" }, sectionHeaders())
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	-- F22 + P5: a relayout never moves a button under the mouse. Mutation: in OfflineWindow's
	-- loaded relayout, drop the busy() hold.
	it("a load that would relayout waits while the mouse is over a saved item, then lays out", function()
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "9:item:" .. Fixtures.UNLOADED .. ";1\n"
		OW.Open("Abby-ArgentDawn")
		local potion = DB.Get(0, 1)
		potion.mouseOver = true
		A.items[Fixtures.UNLOADED] = { name = "Chest of Tests", classID = A.ITEM_CLASS.Armor, subclassID = 4,
			equipLoc = "INVTYPE_CHEST", quality = 3, ilvl = 270, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("GET_ITEM_INFO_RECEIVED", Fixtures.UNLOADED, true)
		A.Advance(OW.LOADED_DELAY)
		assert.equal("- New (1)", sectionHeaders()[1], "held under the mouse")
		potion.mouseOver = false
		A.Advance(OW.LOADED_DELAY)
		assert.falsy(sectionHeaders()[1] == "- New (1)", "laid out once the mouse left")
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("item data for an item it is not waiting on, or while it is closed, lays nothing out", function()
		OW.Open("Abby-ArgentDawn")
		local n = OW.view.stats.lastLayoutReason
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", 211880, true)
		A.Advance(OW.LOADED_DELAY)
		assert.equal(n, OW.view.stats.lastLayoutReason)
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "9:item:" .. Fixtures.UNLOADED .. ";1\n"
		OW.Open("Abby-ArgentDawn")
		OW.Close()
		A.items[Fixtures.UNLOADED].pending = nil
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		A.Advance(OW.LOADED_DELAY)
		assert.falsy(OW.view.IsOpen(), "a closed viewer stays cleared")
	end)

	-- Plan decision: the viewer shows what was saved when it opened. Mutation: make the
	-- loaded relayout re-read AltData (OW.Load) -- the new save would show.
	it("a loaded-item relayout keeps the data it opened with (no later saves)", function()
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "9:item:" .. Fixtures.UNLOADED .. ";1\n"
		OW.Open("Abby-ArgentDawn")
		bags.s = bags.s .. "10:item:211880;3\n"
		A.items[Fixtures.UNLOADED].pending = nil
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		A.Advance(OW.LOADED_DELAY)
		assert.is_nil(DB.buttons[0][10])
	end)

	it("opens in combat; only plain frames are made", function()
		A.combat = true
		OW.Open("Abby-ArgentDawn")
		for _, f in ipairs(Fake.created) do
			assert.falsy(tostring(f.template):find("Secure"), tostring(f.template))
			assert.falsy(tostring(f.template):find("ContainerFrameItemButton"), tostring(f.template))
		end
	end)
end)

describe("Alt viewer load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		local ok, err = pcall(loadOffline, SB)
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)

describe("GroupView hideEmptyNew", function()
	it("hides each group's New while it is empty when the window asks", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(SB.Adapter)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GroupView.lua")
		SB.Categories.Load()
		local buttons = {}
		local function cfg(hide)
			return { key = "t", child = Fake.New("Frame"), scroll = Fake.New("ScrollFrame"),
				button = function(_, slot)
					buttons[slot] = buttons[slot] or Fake.New("ItemButton")
					return slot <= 2 and buttons[slot] or nil
				end,
				describe = function(bag, slot) return SB.Items.Describe(bag, slot) end,
				groups = function() return { { id = "g", bags = { { bag = 0, size = 2 } } } } end,
				groupLabel = function() return "g" end, view = function() return "sections" end,
				columns = function() return 10 end, newRows = function() return 2 end, onResize = function() end,
				hideEmptyNew = hide }
		end
		local function ids(v)
			local out = {}
			for _, h in ipairs(v.pos.headers) do
				out[#out + 1] = h.id
			end
			return out
		end
		local shown = SB.GroupView.New(cfg(nil))
		shown.Layout("open")
		assert.same({ "new", "c_consumables" }, ids(shown))
		local hidden = SB.GroupView.New(cfg(true))
		hidden.Layout("open")
		assert.same({ "c_consumables" }, ids(hidden))
		Fake.Uninstall()
	end)
end)
