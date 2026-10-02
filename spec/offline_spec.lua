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
		-- the ring is bind-on-equip, but saved: it may be bound by now (W5-10), so it is plain Gear
		assert.same({ "- Consumables (1)", "- Gear (1)", "- Junk (1)", "- Ore (1)", "- Consumables (1)",
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
		-- nothing can be picked up or dropped (review fix 3). Mutation: in DisplayButtons create,
		-- add b:RegisterForDrag("LeftButton") or an OnDragStart/OnReceiveDrag script.
		for _, f in ipairs(Fake.created) do
			if f.kind == "ItemButton" then
				assert.is_nil(f.scripts.OnDragStart)
				assert.is_nil(f.scripts.OnReceiveDrag)
				assert.is_nil(f.calls.RegisterForDrag)
			end
		end
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
		assert.same({ "- Consumables (1)", "- Gear (2)", "- Junk (1)", "- Ore (1)", "- Consumables (1)",
			"- Herbs (1)" }, sectionHeaders())
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	-- F22 + P5: a relayout never moves a button under the mouse. Mutation: in OfflineWindow's
	-- loaded relayout, call OW.view.Layout instead of OW.view.RequestLayout.
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

	-- F22 + P5, the cursor case. Mutation: as above (OW.view.Layout instead of RequestLayout).
	it("a load that would relayout waits while an item is on the cursor, then lays out", function()
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "9:item:" .. Fixtures.UNLOADED .. ";1\n"
		OW.Open("Abby-ArgentDawn")
		A.cursor = { itemID = 211880, link = "item:211880" }
		A.items[Fixtures.UNLOADED] = { name = "Chest of Tests", classID = A.ITEM_CLASS.Armor, subclassID = 4,
			equipLoc = "INVTYPE_CHEST", quality = 3, ilvl = 270, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		A.Advance(OW.LOADED_DELAY)
		A.Advance(SB.GroupView.RETRY)
		assert.equal("- New (1)", sectionHeaders()[1], "held while an item is on the cursor")
		A.cursor = nil
		A.Advance(SB.GroupView.RETRY)
		assert.equal("- Gear (2)", sectionHeaders()[2], "laid out once the cursor is empty")
	end)

	-- Review fix 4. Mutation: in the OnHide handler, drop the OW.pending reset.
	it("closing forgets the items it was waiting on", function()
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "9:item:" .. Fixtures.UNLOADED .. ";1\n"
		OW.Open("Abby-ArgentDawn")
		assert.truthy(OW.pending[Fixtures.UNLOADED])
		OW.Close()
		assert.same({}, OW.pending)
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

	-- Ruling W5-10: a saved bind-on-equip item may have been bound since. Mutation: in
	-- Items.DescribeLink, drop the bindUnknown branch (the ring is BoE gear with a badge, AH-priced).
	it("a saved BoE item outside a guild bank has an unknown bind: no badge, no boe match, vendor-priced", function()
		A.items[Fixtures.BOE_RING].sellPrice = 500
		SB.Prices.RegisterProvider({ name = "AH", priority = 10, available = function()
			return true
		end, value = function()
			return 990000
		end })
		OW.Open("Abby-ArgentDawn")
		local record = OW.view.Record(0, 2)
		assert.is_nil(record.bind)
		assert.truthy(record.bindUnknown)
		assert.equal("", SB.Overlays.regions[DB.Get(0, 2)].bind.text, "no BoE badge")
		assert.equal(500, SB.Sort.Value(record), "priced as bound: the vendor's price")
		OW.searchBox.editBox:SetText("boe")
		OW.searchBox.Run()
		assert.equal(0.2, DB.Get(0, 2).alpha, "boe does not match it")
	end)

	-- Final fix W5-11. Mutation: drop the static-bind branch in Items.DescribeLink.
	it("a saved bind-on-pickup item is bound and vendor-priced; warbound too; wue is WUE; a guild item is unchanged", function()
		A.items[Fixtures.BOE_RING].bind = "pickup"
		A.items[Fixtures.BOE_RING].sellPrice = 500
		SB.Prices.RegisterProvider({ name = "AH", priority = 10, available = function()
			return true
		end, value = function()
			return 990000
		end })
		OW.Open("Abby-ArgentDawn")
		local record = OW.view.Record(0, 2)
		assert.equal(true, record.isBound)
		assert.equal(500, SB.Sort.Value(record), "priced at vendor, as in the live bags")
		for _, bind in ipairs({ "account", "warbound" }) do
			A.items[Fixtures.BOE_RING].bind = bind
			local r = SB.Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = "x", count = 1 }, 0, 2, nil, "bags")
			assert.equal(true, r.isBound, bind)
		end
		A.items[Fixtures.BOE_RING].bind = "wue"
		local w = SB.Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = "x", count = 1 }, 0, 2, nil, "bags")
		assert.equal(true, w.isWUE)
		assert.equal(false, w.isBound)
		local g = SB.Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = "x", count = 1 }, 101, 6, 1)
		assert.equal(false, g.isBound)
		assert.equal(false, g.isWUE)
	end)

	-- Ruling W5-10, the guild case. Mutation: apply the unknown bind to guild records too.
	it("a BoE item in a saved guild bank stays BoE (never bound there), beside the same ring in the bags", function()
		local tab = SB.Snapshots.DB().guilds["Tidewatch-Argent Dawn"].snapshot.containers[1]
		tab.s = tab.s .. "6:item:225001;1\n"
		OW.Open("Abby-ArgentDawn")
		local record = OW.view.Record(101, 6)
		assert.equal("equip", record.bind)
		assert.equal(false, record.isBound)
		assert.falsy(record.bindUnknown)
		assert.equal(SB.L.BADGE_BOE, SB.Overlays.regions[DB.Get(101, 6)].bind.text)
		assert.same({ "- Consumables (1)", "- Gear (1)", "- Junk (1)", "- Ore (1)", "- Consumables (1)",
			"- BoE gear (1)", "- Herbs (1)" }, sectionHeaders(), "same link, two bind states: two memo keys")
	end)

	-- Review fix 5. Mutation: in find, return the first name match.
	it("a name saved on two realms lists both and opens neither; Name-Realm in any spelling opens one", function()
		SB.Snapshots.DB().chars["Abby-Silvermoon"] = { class = "MAGE", lastSeen = A.Time(),
			bags = { v = 1, at = A.Time(), containers = { [0] = { size = 16, s = "1:item:211880;2\n" } } } }
		SB.Slash.Dispatch("alts abby")
		assert.same({ "More than one saved character is named \"abby\": Abby-ArgentDawn, Abby-Silvermoon. Type one of these." },
			A.Lines())
		assert.falsy(OW.IsOpen())
		SB.Slash.Dispatch("alts abby-argent dawn")
		assert.truthy(OW.IsOpen())
		assert.equal("Abby-ArgentDawn", OW.key)
	end)

	-- Review fix 6. Mutation: in Overlays.RefreshAll, drop the alt viewer.
	it("Overlays.RefreshAll redraws the alt viewer's buttons", function()
		OW.Open("Abby-ArgentDawn")
		local ring = DB.Get(0, 2)
		assert.equal("285", SB.Overlays.regions[ring].topLeft.text)
		SB.Config.Set("overlays.ilvl", false)
		SB.Overlays.RefreshAll()
		assert.equal("", SB.Overlays.regions[ring].topLeft.text)
	end)

	-- Review fix 7. Mutation: in kindOf, map the reagent bag to "bags".
	it("the saved reagent bag is where the reagentbag keyword looks", function()
		local c = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers
		c[5] = { size = 36, s = "3:item:210796;12\n" }
		OW.Open("Abby-ArgentDawn")
		assert.equal("reagentbag", OW.view.Record(5, 3).location)
		assert.equal("backpack", OW.view.Record(0, 1).location)
		OW.searchBox.editBox:SetText("reagentbag")
		OW.searchBox.Run()
		assert.equal(1, DB.Get(5, 3).alpha)
		assert.equal(0.2, DB.Get(0, 1).alpha)
		OW.searchBox.editBox:SetText("bags")
		OW.searchBox.Run()
		assert.equal(1, DB.Get(5, 3).alpha, "the reagent bag is one of the bags")
		assert.equal(0.2, DB.Get(6, 5).alpha)
	end)

	-- Review fix 8: the pool. Mutation: in DisplayButtons.Get, always create a new button.
	it("display buttons are kept: reopening and switching characters make none for slots already made", function()
		SB.Snapshots.Save("bags")
		OW.Open("Abby-ArgentDawn")
		local n = DB.count
		OW.Close()
		OW.Open("Abby-ArgentDawn")
		assert.equal(n, DB.count, "reopen")
		OW.Open("Swagger-ArgentDawn")
		local m = DB.count
		OW.Open("Abby-ArgentDawn")
		OW.Open("Swagger-ArgentDawn")
		assert.equal(m, DB.count, "switch back and forth")
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

describe("Alt viewer: the character picker and the ways in", function()
	local SB, A, OW
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Env.PaintGlobals()
		OW = loadOffline(SB)
		SB.Inventory.ScanAll()
		SB.Categories.Load()
		SB.Snapshots.Save("bags")
		SB.Snapshots.DB().chars["Abby-Argent Dawn"] = { class = "PRIEST", lastSeen = A.Time() - 2 * 86400,
			bags = { v = 1, at = A.Time() - 2 * 86400, containers = { [0] = { size = 16, s = "1:item:211880;20\n" } } } }
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
	end)

	local function menuTexts()
		local out = {}
		for _, b in ipairs(OW.menuButtons) do
			if b.shown then
				out[#out + 1] = b.text
			end
		end
		return out
	end

	-- AC13.2 "via the character dropdown". Mutation: in the menu buttons' OnClick, drop OW.Open(self.key).
	it("the picker lists every saved character (this one first, with ages); a click shows that one", function()
		OW.Open()
		assert.equal("Character: Swagger", OW.pickButton.text)
		Fake.Fire(OW.pickButton, "OnClick")
		assert.truthy(OW.menu.shown)
		assert.same({ "Swagger (Argent Dawn) - just now", "Abby (Argent Dawn) - 2 days ago" }, menuTexts())
		Fake.Fire(OW.menuButtons[2], "OnClick")
		assert.falsy(OW.menu.shown)
		assert.equal("SwagBag — Abby (saved)", OW.frame.title.text)
		assert.equal("Character: Abby", OW.pickButton.text)
		assert.equal(20, SB.DisplayButtons.Get(0, 1).count)
	end)

	-- Mutation: delete the `#all == 0` return in OW.ToggleMenu (a blank menu opens).
	it("with no saved character the picker shows no menu and says so", function()
		SB.AltData.Characters = function() return {} end
		OW.Open()
		assert.falsy(OW.ToggleMenu())
		assert.falsy(OW.menu.shown)
		assert.equal(SB.L.OFFLINE_NONE_SAVED, OW.frame.title.text)
	end)

	-- Mutation: drop the `list[#list] = c` swap (the shown character falls off the list), or the
	-- `> OW.MENU_MAX` overflow line.
	it("a long list stops at MENU_MAX, keeps the shown character in it and says how many more", function()
		local chars = {}
		for i = 1, 35 do
			chars[i] = { key = "C" .. i .. "-Realm", name = "C" .. i, realm = "Realm" }
		end
		SB.AltData.Characters = function() return chars end
		OW.Open("C33-Realm")
		OW.ToggleMenu()
		local texts = menuTexts()
		assert.equal(OW.MENU_MAX, #texts)
		assert.equal("C33 (Realm)", texts[OW.MENU_MAX])
		assert.equal("+5 more, type /swagbag alts <name>", OW.menuMore.text)
		assert.truthy(OW.menuMore.shown)
		OW.ToggleMenu()
		chars[2] = nil
		for i = 3, 35 do chars[i] = nil end
		OW.ToggleMenu()
		assert.falsy(OW.menuMore.shown)
	end)

	-- Mutation: drop the LockHighlight branch in OW.ToggleMenu.
	it("the shown character's row is highlighted, the others not", function()
		OW.Open()
		OW.ToggleMenu()
		assert.truthy(OW.menuButtons[1].calls.LockHighlight)
		assert.falsy(OW.menuButtons[2].calls.LockHighlight)
		assert.truthy(OW.menuButtons[2].calls.UnlockHighlight)
	end)

	-- Mutation: drop `menu:Hide()` from OW.Open.
	it("opening another character closes the list", function()
		OW.Open()
		OW.ToggleMenu()
		OW.Open("Abby-ArgentDawn")
		assert.falsy(OW.menu.shown)
	end)

	-- Review fix: the source line stops at the picker. Mutation: drop the RIGHT anchor.
	it("the source line is bound to the picker and the window is at least MIN_WIDTH wide", function()
		OW.Open()
		local bound
		for _, p in ipairs(OW.frame.source.points) do
			if p[1] == "RIGHT" and p[2] == OW.pickButton and p[3] == "LEFT" then
				bound = true
			end
		end
		assert.truthy(bound)
		assert.truthy(OW.frame.w >= OW.MIN_WIDTH)
	end)

	-- Mutation: drop classColoured from the menu button's SetText.
	it("the picker colours each name by class through the Adapter", function()
		_G.RAID_CLASS_COLORS = { PRIEST = { colorStr = "fffffffe" } }
		OW.Open()
		OW.ToggleMenu()
		_G.RAID_CLASS_COLORS = nil
		assert.equal("|cfffffffeAbby (Argent Dawn) - 2 days ago|r", OW.menuButtons[2].text)
	end)

	-- F23. Mutation: anchor the picker back at TOPRIGHT -10, -30.
	it("the picker sits on the source line, clear of the search box's error line", function()
		local p = OW.pickButton.points[1]
		assert.equal("TOPRIGHT", p[1])
		assert.equal(-56, p[5])
		-- the error line hangs from y -26 for two lines of small text (about 12 px each): its lowest edge is -50
		assert.truthy(p[5] <= -26 - 2 * 12, "the picker's top is below the error line")
	end)

	it("a second click closes the list; reopening reuses its buttons; hiding the window hides it", function()
		OW.Open()
		OW.ToggleMenu()
		local n = #Fake.created
		OW.ToggleMenu()
		assert.falsy(OW.menu.shown)
		OW.ToggleMenu()
		assert.equal(n, #Fake.created, "no new frames")
		OW.Close()
		assert.falsy(OW.menu.shown)
	end)

	it("with Syndicator answering, its characters are listed (no stamp: name and realm only)", function()
		SB.AltData.RegisterProvider({ name = "Syndicator", priority = 10, available = function() return true end,
			characters = function() return { { key = "Zed-ArgentDawn", name = "Zed", realm = "Argent Dawn" } } end })
		OW.Open("Zed-ArgentDawn")
		OW.ToggleMenu()
		assert.same({ "Zed (Argent Dawn)" }, menuTexts())
	end)

	-- Task 9 deferred minor. Mutation: in GroupView.RequestLayout, drop the onUpdated call after commit.
	it("a held loaded relayout re-applies the search when its retry lands", function()
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "9:item:" .. Fixtures.UNLOADED .. ";1\n"
		OW.Open("Abby-ArgentDawn")
		OW.searchBox.editBox:SetText("zzzz")
		OW.searchBox.Run()
		local potion = SB.DisplayButtons.Get(0, 1)
		potion.mouseOver = true
		A.items[Fixtures.UNLOADED] = { name = "Chest of Tests", classID = A.ITEM_CLASS.Armor, subclassID = 4,
			equipLoc = "INVTYPE_CHEST", quality = 3, ilvl = 270, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("GET_ITEM_INFO_RECEIVED", Fixtures.UNLOADED, true)
		A.Advance(OW.LOADED_DELAY)
		potion.mouseOver = false
		local chest = SB.DisplayButtons.Get(0, 9)
		chest.alpha = 1 -- what a layout leaves on a button it draws
		A.Advance(SB.GroupView.RETRY)
		assert.equal(0.2, chest.alpha, "the landed layout was searched again")
	end)

	it("Settings > Alt data opens the alt viewer through /swagbag alts", function()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/TooltipCounts.lua")
		local SW = SB.SettingsWindow
		SW.Show("alts")
		for i = 1, SW.used.buttons do
			if SW.buttons[i].text == SB.L.SET_ALTS_OPEN then
				Fake.Fire(SW.buttons[i], "OnClick")
			end
		end
		assert.truthy(OW.IsOpen())
		assert.equal("Showing the saved items of Swagger.", SW.lastStatus)
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	-- Mutation: drop the offline window from Overlays.RefreshAll.
	it("switching an overlay redraws the alt viewer's items too", function()
		OW.Open("Swagger-ArgentDawn")
		local ring = SB.DisplayButtons.Get(0, 3)
		assert.equal("285", SB.Overlays.regions[ring].topLeft.text)
		SB.Slash.Dispatch("overlays ilvl off")
		assert.equal("", SB.Overlays.regions[ring].topLeft.text)
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
