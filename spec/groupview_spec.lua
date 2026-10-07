-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The group view (bank and guild bank contents) over the real engine with fake frames:
-- stacked groups, per-group sections, collapse, spec 4.3 changes, the hover guard across
-- groups, the grid view, and the 1,290-slot budget.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Big = dofile("spec/fixtures/big.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/CategoryDefaults.lua", "SwagBag/Engine/Categories.lua",
	"SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
}

-- A view over bank tab 6 ("bank") and warband tab 12 ("warband"), with fake buttons.
local function newView(SB, opts)
	opts = opts or {}
	local child = Fake.New("Frame")
	local scroll = Fake.New("ScrollFrame")
	local buttons, gets, resized = {}, { n = 0 }, {}
	local tint = {}
	local cfg = {
		key = "bank", window = "bank", child = child, scroll = scroll,
		button = function(bag, slot)
			gets.n = gets.n + 1
			if slot > (opts.capacity or 98) then
				return nil
			end
			buttons[bag] = buttons[bag] or {}
			local b = buttons[bag][slot]
			if not b then
				b = Fake.New("ItemButton", child)
				b.bag, b.slot = bag, slot
				buttons[bag][slot] = b
			end
			return b
		end,
		describe = function(bag, slot)
			return SB.Items.Describe(bag, slot)
		end,
		groups = function()
			local out = {}
			for _, def in ipairs(opts.groups or { { "bank", "bank" }, { "warband", "warband" } }) do
				local bags = {}
				for _, bag in ipairs(SB.Adapter.GetBagIDs(def[2])) do
					bags[#bags + 1] = { bag = bag, size = SB.Adapter.NumSlots(bag) }
				end
				out[#out + 1] = { id = def[1], bags = bags }
			end
			return out
		end,
		groupLabel = function(id, collapsed, count)
			return (collapsed and "+ " or "- ") .. id .. " (" .. count .. ")"
		end,
		groupTint = function(id) return tint[id] end,
		view = function() return opts.view or "sections" end,
		columns = function() return opts.columns or 4 end,
		newRows = function() return 1 end,
		freeTile = opts.freeTile and function() return true end or nil,
		onResize = function(w, h, keepTop) resized[#resized + 1] = { w, h, keepTop } end,
	}
	local v = SB.GroupView.New(cfg)
	return v, { buttons = buttons, gets = gets, child = child, scroll = scroll, resized = resized, tint = tint, cfg = cfg }
end

local function at(b)
	local p = b.points[#b.points]
	return { p[4], p[5] }
end

describe("GroupView", function()
	local SB, A, v, f
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GroupView.lua")
		SB.Categories.Load()
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.Put(6, 1, Fixtures.HEALING_POTION, 5)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(6, 3, Fixtures.FLASK, 1)
		A.Put(12, 1, Fixtures.ORE, 10)
		A.Put(12, 2, Fixtures.BOE_RING, 1)
		v, f = newView(SB)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function labels()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			out[#out + 1] = h.sectionId .. "=" .. h.text.text
		end
		return out
	end

	local function header(id)
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId == id then
				return h
			end
		end
	end

	local function btn(bag, slot)
		return f.buttons[bag][slot]
	end

	it("stacks the groups top to bottom, each with its header and its own New, categories and Free", function()
		v.Layout("open")
		assert.same({
			"#bank=- bank (3)", "#warband=- warband (2)",
			"bank:new=- New (0)", "bank:c_consumables=- Consumables (2)", "bank:c_herbs=- Herbs (1)",
			"bank:free=- Free (5)",
			"warband:new=- New (0)", "warband:c_boe=- BoE gear (1)", "warband:c_ore=- Ore (1)",
			"warband:free=- Free (6)",
		}, labels())
		assert.equal(0, header("#bank").points[1][5])
		assert.truthy(header("#warband").points[1][5] < at(btn(6, 8))[2], "warband starts below bank's Free")
		assert.equal(16, #v.cells)
		assert.equal("open", v.stats.lastLayoutReason)
		assert.same({ v.pos.width, v.pos.height, false }, f.resized[1])
	end)

	it("collapsing a group hides its slots and lifts the groups below; expanding restores every cell", function()
		v.Layout("open")
		local before = { at(btn(12, 1)), at(btn(12, 2)), at(btn(6, 1)) }
		header("#bank").scripts.OnClick(header("#bank"))
		assert.equal(true, SB.Config.UI().collapsed["bank:#"].bank)
		assert.falsy(btn(6, 1).shown)
		assert.equal("- bank (3)", header("#bank").text.text:gsub("^%+", "-"))
		assert.truthy(at(btn(12, 1))[2] > before[1][2], "warband moved up")
		assert.is_nil(header("bank:new"), "a collapsed group shows no section headers")
		header("#bank").scripts.OnClick(header("#bank"))
		assert.same(before, { at(btn(12, 1)), at(btn(12, 2)), at(btn(6, 1)) })
		assert.truthy(btn(6, 1).shown)
	end)

	it("collapse state is kept per window, per group and per section", function()
		v.Layout("open")
		header("warband:c_ore").scripts.OnClick(header("warband:c_ore"))
		assert.equal(true, SB.Config.UI().collapsed["bank:warband"].c_ore)
		assert.is_nil(SB.Config.UI().collapsed["bank:bank"].c_ore)
		assert.falsy(btn(12, 1).shown)
		v.Clear()
		v.Layout("open")
		assert.falsy(btn(12, 1).shown, "still collapsed after a reopen")
		assert.equal("+ Ore (1)", header("warband:c_ore").text.text)
	end)

	it("an item taken from a group leaves a placeholder; its button goes to that group's Free", function()
		v.Layout("open")
		local potionAt = at(btn(6, 1))
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		assert.equal(1, #SB.Buttons.placeholdersInUse)
		assert.truthy(at(btn(6, 1))[2] < potionAt[2], "moved down into Free")
		assert.equal("bank:free=- Free (6)", labels()[6])
	end)

	it("a deposit goes to that group's New and nothing else moves", function()
		v.Layout("open")
		local before = {}
		for slot = 1, 8 do
			before[slot] = at(btn(12, slot))
		end
		A.Put(6, 5, Fixtures.JUNK, 1)
		v.Changes("bank", { { bag = 6, slot = 5, kind = "arrived" } })
		v.SetRecord(6, 5, SB.Items.Describe(6, 5))
		assert.equal(header("bank:new").points[1][5] - 20, at(btn(6, 5))[2], "first cell of New")
		for slot = 1, 8 do
			assert.same(before[slot], at(btn(12, slot)), "warband slot " .. slot)
		end
	end)

	it("a group that grows a row pushes the groups below, but not while one of them is under the mouse", function()
		A.Put(6, 4, Fixtures.JUNK, 1) -- bank Free has 4 cells: one more starts a new row
		v.Layout("open")
		local ore = btn(12, 1)
		local oreAt = at(ore)
		ore.mouseOver = true
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		assert.same(oreAt, at(ore), "held: the ore is under the mouse")
		assert.equal(1, v.stats.heldRedraws)
		A.Advance(0.3)
		assert.same(oreAt, at(ore), "still under the mouse")
		ore.mouseOver = false
		A.Advance(0.3)
		assert.truthy(at(ore)[2] < oreAt[2], "pushed down once the mouse left")
		assert.equal(1, #SB.Buttons.placeholdersInUse)
	end)

	it("an item on the cursor holds every move and every push", function()
		v.Layout("open")
		local potionAt = at(btn(6, 1))
		A.cursor = { itemID = Fixtures.FLASK }
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		A.Advance(0.6)
		assert.same(potionAt, at(btn(6, 1)))
		A.cursor = nil
		A.Advance(0.3)
		assert.truthy(at(btn(6, 1))[2] < potionAt[2])
	end)

	-- Week 10 (P5, week-9 deferred). Mutation: in GroupView's busyCheck, `local cursor = SB.Adapter.CursorBusy()` ->
	-- `local cursor = SB.Adapter.CursorItem() ~= nil`.
	it("a spell waiting for its target holds every move and every push too", function()
		v.Layout("open")
		local potionAt = at(btn(6, 1))
		A.cursorOther = "targeting"
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		A.Advance(0.6)
		assert.same(potionAt, at(btn(6, 1)))
		A.cursorOther = nil
		A.Advance(0.3)
		assert.truthy(at(btn(6, 1))[2] < potionAt[2])
	end)

	-- Plan D19 (Task 9 turns it on for the bank window). Mutations: drop `freeTile = ...` from
	-- v.Layout's Build options; delete paintTiles(pos) in renderMoved.
	it("with cfg.freeTile each group's Free is one tile with its number; a drop on it swaps after the mouse leaves",
		function()
			v, f = newView(SB, { freeTile = true })
			v.Layout("open")
			assert.same({ "bank:free=- Free (5)", "warband:free=- Free (6)" },
				{ labels()[6], labels()[10] }, "Free's header still counts every free slot")
			local fc = SB.Buttons.freeCounts
			assert.same({ true, "5" }, { btn(6, 4).shown, tostring(fc[btn(6, 4)].text) })
			assert.same({ true, "6" }, { btn(12, 3).shown, tostring(fc[btn(12, 3)].text) })
			for slot = 5, 8 do
				assert.falsy(btn(6, slot).shown, "bank slot " .. slot)
			end
			local tileAt = at(btn(6, 4))
			btn(6, 4).mouseOver = true
			A.Put(6, 4, Fixtures.ORE, 1)
			v.SetRecord(6, 4, SB.Items.Describe(6, 4))
			v.Changes("bank", { { bag = 6, slot = 4, kind = "arrived" } })
			assert.same(tileAt, at(btn(6, 4)), "nothing moves under the mouse")
			assert.falsy(btn(6, 5).shown)
			btn(6, 4).mouseOver = false
			A.Advance(0.3)
			assert.same(tileAt, at(btn(6, 5)), "the next empty slot takes the tile's place")
			assert.same({ true, "4" }, { btn(6, 5).shown, tostring(fc[btn(6, 5)].text) })
			assert.falsy(fc[btn(6, 4)].shown, "the filled slot shows no number")
		end)

	-- Review fix 1 (P5). Mutation: `if anyBusy(SB.Layout.Moves(v.pos, pos)) then` -> `if false then`
	-- in v.Restack.
	it("a collapse or expand waits while a button it would move is under the mouse", function()
		v.Layout("open")
		local ore = btn(12, 1)
		local oreAt = at(ore)
		local shown = {}
		for slot = 1, 8 do
			shown[slot] = btn(6, slot).shown
		end
		ore.mouseOver = true
		assert.equal(false, v.ToggleSection("bank", "c_consumables"))
		assert.equal(false, v.ToggleGroup("bank"))
		assert.same(oreAt, at(ore), "held: the ore is under the mouse")
		for slot = 1, 8 do
			assert.equal(shown[slot], btn(6, slot).shown, "bank slot " .. slot)
		end
		ore.mouseOver = false
		A.Advance(0.3)
		assert.truthy(at(ore)[2] > oreAt[2], "warband lifted once the mouse left")
		for slot = 1, 8 do
			assert.falsy(btn(6, slot).shown, "bank slot " .. slot .. " hidden")
		end
		assert.equal("+ bank (3)", header("#bank").text.text)
		for _, c in ipairs(v.pos.cells) do
			if c.shown then
				assert.same({ c.x, c.y }, at(f.buttons[c.bag][c.slot]))
			end
		end
	end)

	-- Review fix 1 (P5). Same mutation as above.
	it("a collapse or expand waits while an item is on the cursor", function()
		v.Layout("open")
		local ore = btn(12, 1)
		local oreAt = at(ore)
		local shown = {}
		for slot = 1, 8 do
			shown[slot] = btn(6, slot).shown
		end
		A.cursor = { itemID = Fixtures.FLASK }
		assert.equal(false, v.ToggleSection("bank", "c_consumables"))
		assert.equal(false, v.ToggleGroup("bank"))
		A.Advance(0.3)
		assert.same(oreAt, at(ore), "still held: the item is on the cursor")
		for slot = 1, 8 do
			assert.equal(shown[slot], btn(6, slot).shown, "bank slot " .. slot)
		end
		A.cursor = nil
		A.Advance(0.3)
		assert.truthy(at(ore)[2] > oreAt[2], "warband lifted once the cursor was empty")
		for slot = 1, 8 do
			assert.falsy(btn(6, slot).shown, "bank slot " .. slot .. " hidden")
		end
	end)

	-- Review fix 3. Mutation: delete `paintTiles(v.pos)` in v.Changes.
	it("with cfg.freeTile a drop held under the mouse hides the number, and picking it back up shows it again",
		function()
			v, f = newView(SB, { freeTile = true })
			v.Layout("open")
			local fc = SB.Buttons.freeCounts
			local tile = btn(6, 4)
			local tileAt = at(tile)
			tile.mouseOver = true
			A.Put(6, 4, Fixtures.ORE, 1)
			v.SetRecord(6, 4, SB.Items.Describe(6, 4))
			v.Changes("bank", { { bag = 6, slot = 4, kind = "arrived" } })
			assert.falsy(fc[tile].shown, "the held item shows no number")
			A.Clear(6, 4)
			v.SetRecord(6, 4, nil)
			v.Changes("bank", { { bag = 6, slot = 4, kind = "left", icon = Fixtures.ORE } })
			assert.same({ true, "5" }, { fc[tile].shown, tostring(fc[tile].text) }, "picked back up: the number is back")
			tile.mouseOver = false
			A.Advance(0.3)
			-- The held changes replay in order: the next empty slot took the tile, then 6:4 emptied
			-- again as a spare. The tile's place still shows the number.
			local t = v.pos.tiles[1]
			local now = btn(t.bag, t.slot)
			assert.same(tileAt, at(now), "the tile's place did not move")
			assert.same({ true, "5" }, { fc[now].shown, tostring(fc[now].text) })
			if now ~= tile then
				assert.falsy(fc[tile].shown, "a spare shows no number")
			end
		end)

	-- Ruling W3-24. Mutation: `if SB.Adapter.CursorItem() then` (without the section test) in
	-- owner.onClick, or drop the group-header test in owner.onDrop.
	it("a group header is not a drop target: a click with an item on the cursor collapses the group", function()
		local dropped = {}
		f.cfg.onDrop = function(sid) dropped[#dropped + 1] = sid end
		v.Layout("open")
		A.cursor = { itemID = Fixtures.JUNK }
		local h = header("#bank")
		h.scripts.OnReceiveDrag(h)
		h.scripts.OnClick(h)
		assert.equal(true, SB.Config.UI().collapsed["bank:#"].bank)
		assert.same({}, dropped)
		A.cursor = nil
		A.Advance(0.3)
		assert.falsy(btn(6, 1).shown, "collapsed once the cursor was empty")
	end)

	-- W3-24 through the right-button path (headers take right-clicks since week 4, a11).
	it("a right-click with an item on the cursor on a group header collapses it, never drops", function()
		local dropped = {}
		f.cfg.onDrop = function(sid) dropped[#dropped + 1] = sid end
		v.Layout("open")
		A.cursor = { itemID = Fixtures.JUNK }
		local h = header("#bank")
		h.scripts.OnClick(h, "RightButton")
		assert.equal(true, SB.Config.UI().collapsed["bank:#"].bank)
		assert.same({}, dropped)
	end)

	-- Ruling W3-23. Mutation: drop `window` from GroupView's AcquirePlaceholder call.
	it("an error in a group view placeholder's tooltip is trapped as the view's window", function()
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		local p = SB.Buttons.placeholdersInUse[1]
		GameTooltip.SetOwner = function() error("tooltip broke") end
		p.scripts.OnEnter(p)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("the grid view shows each group's slots in physical order under its header", function()
		v, f = newView(SB, { view = "grid" })
		v.Layout("open")
		assert.same({ "#bank=- bank (3)", "#warband=- warband (2)" }, labels())
		assert.same({ 4, -26 }, at(btn(6, 1)))
		assert.same({ 45, -26 }, at(btn(6, 2)))
		assert.same({ 4, -67 }, at(btn(6, 5)))
		assert.truthy(at(btn(12, 1))[2] < at(btn(6, 8))[2])
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left" } })
		assert.same({ 4, -26 }, at(btn(6, 1)), "the grid never moves a button")
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		v.ToggleGroup("bank")
		assert.falsy(btn(6, 2).shown, "a collapsed group hides its grid")
		assert.equal(-56, at(btn(12, 1))[2], "warband moved up: bank header, gap, warband header")
	end)

	it("dropping an item on a section header calls onDrop once; the click of the same press does not collapse", function()
		local dropped = {}
		f.cfg.onDrop = function(sid) dropped[#dropped + 1] = sid end
		v.Layout("open")
		A.cursor = { itemID = Fixtures.JUNK }
		local h = header("bank:c_herbs")
		h.scripts.OnReceiveDrag(h)
		A.cursor = nil -- the drop put it in the category list and the item back in its slot
		h.scripts.OnClick(h)
		assert.same({ "c_herbs" }, dropped)
		assert.is_nil(SB.Config.UI().collapsed["bank:bank"].c_herbs)
		A.Advance(0.5)
		h.scripts.OnClick(h)
		assert.equal(true, SB.Config.UI().collapsed["bank:bank"].c_herbs, "a later click collapses")
	end)

	-- Ruling W3-22 (spec P6). Mutation: drop `window = window` from GroupView's owner.
	it("an error in a group view header's drop is trapped as the view's window, not the bags", function()
		f.cfg.onDrop = function() error("drop broke") end
		v.Layout("open")
		A.cursor = { itemID = Fixtures.JUNK }
		local h = header("bank:c_herbs")
		h.scripts.OnReceiveDrag(h)
		A.cursor = nil
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("a view without cfg.window traps its header errors as the bank window's", function()
		f.cfg.window = nil
		v = SB.GroupView.New(f.cfg)
		f.cfg.onDrop = function() error("drop broke") end
		v.Layout("open")
		local h = header("bank:c_herbs")
		h.scripts.OnReceiveDrag(h)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("Clear hides every button and releases only this view's placeholders and headers", function()
		local other = Fake.New("Frame")
		local foreign = SB.SectionHeaders.Acquire(other, "c_gear", "x", 0, 0, 10)
		local foreignP = SB.Buttons.AcquirePlaceholder(other, 1, 37, 0, 0)
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		v.Clear()
		for slot = 1, 8 do
			assert.falsy(btn(6, slot).shown)
		end
		assert.truthy(foreign.shown)
		assert.truthy(foreignP.shown)
		assert.same({ foreign }, SB.SectionHeaders.inUse)
		assert.falsy(v.IsOpen())
	end)

	-- W3-38: the same guard as a redraw or a re-stack. Mutation: in v.RequestLayout, hold on
	-- `cfg.scroll:IsMouseOver()` instead of on the buttons that would move (the next test fails).
	it("a full layout request waits while a button that would move is under the mouse or an item is on the cursor", function()
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		f.scroll.mouseOver = true
		btn(6, 1).mouseOver = true -- in Free's end now; the full layout puts it back in order
		assert.falsy(v.RequestLayout("sort"))
		A.Advance(0.3)
		assert.equal("open", v.stats.lastLayoutReason)
		btn(6, 1).mouseOver = false
		A.cursor = { itemID = 1 }
		A.Advance(0.3)
		assert.equal("open", v.stats.lastLayoutReason)
		A.cursor = nil
		A.Advance(0.3)
		assert.equal("sort", v.stats.lastLayoutReason)
	end)

	-- Week 5 Task 10 review. Mutations: call cfg.onUpdated before the hold test in v.RequestLayout (the
	-- first count fails); drop the call after commit (the second fails).
	it("onUpdated is not called while a full layout is held, and once when it lands", function()
		local n = 0
		f.cfg.onUpdated = function() n = n + 1 end
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		n = 0
		btn(6, 1).mouseOver = true
		assert.falsy(v.RequestLayout("sort"))
		A.Advance(0.3)
		assert.equal(0, n, "held")
		btn(6, 1).mouseOver = false
		A.Advance(0.3)
		assert.equal("sort", v.stats.lastLayoutReason)
		assert.equal(1, n, "landed once")
	end)

	-- Week-3 carry-over. Mutation: drop the v.heldKey re-check in v.RequestLayout (every retry
	-- reads every slot again).
	it("a held full layout re-arms without reading the slots again while the same button stays busy", function()
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		btn(6, 1).mouseOver = true
		local reads = 0
		local describe = f.cfg.describe
		f.cfg.describe = function(...)
			reads = reads + 1
			return describe(...)
		end
		assert.falsy(v.RequestLayout("sort"))
		local first = reads
		assert.truthy(first > 0, "the first request reads the slots once")
		A.Advance(0.3)
		A.Advance(0.3)
		A.Advance(0.3)
		assert.equal(first, reads, "three retries under the same button: no reads")
		btn(6, 1).mouseOver = false
		A.Advance(0.3)
		assert.equal("sort", v.stats.lastLayoutReason)
	end)

	-- P5 after a re-arm: once the held button is free, the layout is checked again in full.
	-- Mutation: skip the Layout.Moves loop whenever v.heldKey was set (commit as soon as the
	-- held button frees).
	it("a held full layout whose button frees still waits while another button that would move is busy", function()
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		btn(6, 1).mouseOver = true
		assert.falsy(v.RequestLayout("sort"))
		btn(6, 1).mouseOver = false
		local others = {}
		for slot = 2, SB.Adapter.NumSlots(6) do
			local b = btn(6, slot)
			if b and b:IsShown() then
				b.mouseOver = true
				others[#others + 1] = b
			end
		end
		assert.truthy(#others > 0)
		A.Advance(0.3)
		assert.equal("open", v.stats.lastLayoutReason, "another moving button is under the mouse")
		for _, b in ipairs(others) do
			b.mouseOver = false
		end
		A.Advance(0.3)
		assert.equal("sort", v.stats.lastLayoutReason)
	end)

	it("W3-38: the mouse over the items but over no button that would move does not hold a full layout", function()
		v.Layout("open")
		f.scroll.mouseOver = true
		btn(6, 2).mouseOver = true -- nothing changed: no button moves
		assert.truthy(v.RequestLayout("sort"))
		assert.equal("sort", v.stats.lastLayoutReason)
	end)

	-- W3-38: a held full layout draws nothing and keeps the old records until it runs.
	it("W3-38: a held full layout leaves the drawn layout and the records as they were", function()
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		local before = at(btn(6, 1))
		local resizes = #f.resized
		btn(6, 1).mouseOver = true
		A.Put(6, 4, Fixtures.ORE, 3)
		assert.falsy(v.RequestLayout("sort"))
		assert.same(before, at(btn(6, 1)))
		assert.is_nil(v.Record(6, 4))
		assert.equal(resizes, #f.resized)
		btn(6, 1).mouseOver = false
		A.Advance(0.3)
		assert.equal("sort", v.stats.lastLayoutReason)
		assert.truthy(v.Record(6, 4))
	end)

	it("the deposit target's group header is tinted", function()
		f.tint.warband = true
		v.Layout("open")
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
		assert.same({ 1, 1, 1, 0.06 }, header("#bank").bg.calls.SetColorTexture)
	end)

	it("a group that disappears between layouts hides its buttons", function()
		v.Layout("open")
		f.cfg.groups = function()
			return { { id = "bank", bags = { { bag = 6, size = 8 } } } }
		end
		v.Layout("reflow")
		assert.falsy(btn(12, 1).shown)
		assert.equal(8, #v.cells)
	end)

	it("1,078 bank slots of the 1,290-slot fixture: a full layout stays inside the first-bank-open budget; "
		.. "a live change touches a few buttons", function()
		Big.Install(A)
		v, f = newView(SB, { columns = 14 })
		local t0 = os.clock()
		v.Layout("open")
		local ms = (os.clock() - t0) * 1000
		assert.equal(1078, #v.cells)
		assert.truthy(ms <= 80, ("layout of 1,078 bank slots took %.1f ms"):format(ms))
		f.gets.n = 0
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		assert.equal(1, #SB.Buttons.placeholdersInUse)
		assert.truthy(f.gets.n <= 4, "Buttons looked up " .. f.gets.n .. " times for one change")
	end)

	-- Review fix 4. Mutation: `render(pos)` instead of `renderMoved(v.pos, pos)` in redraw.
	it("1,078 bank slots with the free tile: a live change still touches a few buttons", function()
		Big.Install(A)
		v, f = newView(SB, { columns = 14, freeTile = true })
		v.Layout("open")
		assert.truthy(#v.pos.tiles >= 2, "a tile per group")
		f.gets.n = 0
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		assert.equal(1, #SB.Buttons.placeholdersInUse)
		assert.truthy(f.gets.n <= 4, "Buttons looked up " .. f.gets.n .. " times for one change")
	end)

	-- Review fix 4 (spec 9: incremental update <= 5 ms). A budget guard: a slower redraw (for
	-- example a full layout per change) fails it; `render(pos)` alone stays under 5 ms in LuaJIT.
	it("1,078 bank slots: a change that adds a Free row and pushes the warband stays inside 5 ms", function()
		Big.Install(A)
		v, f = newView(SB, { columns = 14 })
		v.Layout("open")
		local pushedMs
		for slot = 1, 98 do
			if A.slots[6][slot] then
				local top = v.pos.groupHeaders[2].y
				local icon = A.slots[6][slot].itemID
				A.Clear(6, slot)
				local t0 = os.clock()
				v.Changes("bank", { { bag = 6, slot = slot, kind = "left", icon = icon } })
				local ms = (os.clock() - t0) * 1000
				if v.pos.groupHeaders[2].y ~= top then
					pushedMs = ms
					break
				end
			end
		end
		assert.truthy(pushedMs, "no change pushed the warband group")
		assert.truthy(pushedMs <= 5, ("the push took %.2f ms"):format(pushedMs))
	end)

	-- Week 13: optional hooks a window uses to own its folds, give headers room, tips and controls.
	describe("window hooks", function()
		it("groupClosed decides a fold without touching the saved set", function()
			-- mutation: positionAll ignores cfg.groupClosed
			f.cfg.groupClosed = function(gid) return gid == "warband" end
			v.Layout("open")
			assert.falsy(btn(12, 1).shown)
			assert.falsy(btn(12, 2).shown)
			assert.truthy(btn(6, 1).shown)
			assert.is_nil(next(v.Collapsed("#")))
		end)

		it("groupClosed nil falls back to the saved set", function()
			-- mutation: nil is treated as false
			f.cfg.groupClosed = function() return nil end
			v.Collapsed("#").warband = true
			v.Layout("open")
			assert.falsy(btn(12, 1).shown)
			assert.truthy(btn(6, 1).shown)
		end)

		it("groupClosed false opens a group the saved set folds", function()
			f.cfg.groupClosed = function() return false end
			v.Collapsed("#").warband = true
			v.Layout("open")
			assert.truthy(btn(12, 1).shown)
		end)

		it("a header click the window handles restacks without saving", function()
			-- mutation: the click also toggles the saved set
			local folded, asked = false, {}
			f.cfg.groupClosed = function(gid) return gid == "warband" and folded end
			f.cfg.toggleGroup = function(gid)
				asked[#asked + 1] = gid
				folded = not folded
				return true
			end
			v.Layout("open")
			assert.truthy(btn(12, 1).shown)
			header("#warband").scripts.OnClick(header("#warband"))
			assert.same({ "warband" }, asked)
			assert.is_nil(next(v.Collapsed("#")))
			assert.falsy(btn(12, 1).shown, "the restack drew the fold")
			header("#warband").scripts.OnClick(header("#warband"))
			assert.truthy(btn(12, 1).shown)
		end)

		it("a header click the window declines toggles the saved set", function()
			local asked = 0
			f.cfg.toggleGroup = function() asked = asked + 1 return false end
			v.Layout("open")
			header("#warband").scripts.OnClick(header("#warband"))
			assert.equal(1, asked)
			assert.equal(true, v.Collapsed("#").warband)
			assert.falsy(btn(12, 1).shown)
		end)

		it("a section header click never asks the window", function()
			local asked = 0
			f.cfg.toggleGroup = function() asked = asked + 1 return true end
			v.Layout("open")
			header("warband:c_ore").scripts.OnClick(header("warband:c_ore"))
			assert.equal(0, asked)
			assert.equal(true, SB.Config.UI().collapsed["bank:warband"].c_ore)
		end)

		it("groupInset narrows that header only", function()
			-- mutation: the inset is ignored, or applied to every header
			f.cfg.groupInset = function(gid) return gid == "warband" and 200 or 0 end
			v.Layout("open")
			assert.equal(header("#bank").w - 200, header("#warband").w)
		end)

		it("onHeaders gets every group header after each draw", function()
			local calls = {}
			f.cfg.onHeaders = function(list) calls[#calls + 1] = list end
			v.Layout("open")
			assert.equal(1, #calls)
			assert.equal(2, #calls[1])
			assert.equal("bank", calls[1][1].id)
			assert.equal("warband", calls[1][2].id)
			assert.truthy(calls[1][2].y < 0)
			assert.equal(calls[1], v.GroupHeaders())
			v.ToggleSection("bank", "c_herbs")
			assert.equal(2, #calls)
			assert.equal(2, #calls[2])
			v.Clear()
			assert.equal(3, #calls)
			assert.same({}, calls[3])
			assert.same({}, v.GroupHeaders())
		end)

		it("GroupHeaders is empty before any draw", function()
			assert.same({}, v.GroupHeaders())
		end)

		it("groupTip runs on enter and the tooltip hides on leave", function()
			-- mutation: OnLeave never hides, or hides a tooltip another frame owns
			local tipped = {}
			f.cfg.groupTip = function(gid, h) tipped[#tipped + 1] = { gid, h } end
			v.Layout("open")
			local h = header("#warband")
			h.scripts.OnEnter(h)
			assert.equal("warband", tipped[1][1])
			assert.equal(h, tipped[1][2])
			GameTooltip.GetOwner = function() return h end
			GameTooltip.shown = true
			h.scripts.OnLeave(h)
			assert.falsy(GameTooltip.shown)
			GameTooltip.GetOwner = function() return header("#bank") end
			GameTooltip.shown = true
			h.scripts.OnLeave(h)
			assert.truthy(GameTooltip.shown, "another frame's tooltip stays")
			local s = header("warband:c_ore")
			assert.equal(1, #tipped)
			s.scripts.OnEnter(s)
			assert.equal(1, #tipped, "a section header has no group tip")
		end)

		it("a groupTip error is trapped as this window", function()
			f.cfg.groupTip = function() error("tip boom") end
			v.Layout("open")
			local h = header("#bank")
			h.scripts.OnEnter(h)
			assert.truthy(true)
		end)

		it("the guild bank's views are unchanged", function()
			v.Layout("open")
			assert.equal(v.pos.width - 2 * SB.GroupView.PAD, header("#bank").w)
			assert.equal(v.pos.width - 2 * SB.GroupView.PAD, header("#warband").w)
			assert.is_nil(header("#bank").scripts.OnEnter(header("#bank")))
			header("#bank").scripts.OnClick(header("#bank"))
			assert.equal(true, v.Collapsed("#").bank)
		end)
	end)
end)

describe("GroupView randomized (Park-Miller): hover holds across groups, section truth after every drain", function()
	local SB, A
	local POOL = { Fixtures.HEALING_POTION, Fixtures.FLASK, Fixtures.HERB, Fixtures.ORE, Fixtures.BOE_RING,
		Fixtures.SOULBOUND_HELM, Fixtures.JUNK }

	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GroupView.lua")
		SB.Categories.Load()
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(6, 12)
		A.SetBagSize(12, 12)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	it("never moves a hovered button, and after each drain every category cell holds its own item", function()
		local seed = 20261015
		local function rand(n)
			seed = seed * 16807 % 2147483647 -- Park-Miller, exact in doubles
			return seed % n + 1
		end
		local count = { left = 0, arrived = 0, drains = 0, holds = 0, pushes = 0 }
		for run = 1, 12 do
			for _, bag in ipairs({ 6, 12 }) do
				for slot = 1, 12 do
					if rand(3) ~= 1 then
						A.Put(bag, slot, POOL[rand(#POOL)], 1)
					else
						A.Clear(bag, slot)
					end
				end
			end
			local v, f = newView(SB, { columns = 4 })
			v.Layout("open")
			local function check(where)
				local seen = {}
				for _, g in ipairs(v.groups) do
					for id, sec in pairs(g.state.sections) do
						for i = 1, sec.size do
							local cell = sec.cells[i]
							if cell and not cell.placeholder and id ~= "new" and id ~= "free" then
								local r = SB.Items.Describe(cell.bag, cell.slot)
								assert.truthy(r and SB.Categorizer.Assign(r) == id,
									where .. ": " .. cell.bag .. ":" .. cell.slot .. " is not a " .. id)
							end
						end
					end
				end
				for _, c in ipairs(v.pos.cells) do
					local b = f.buttons[c.bag][c.slot]
					if c.shown then
						assert.same({ c.x, c.y }, at(b), where .. ": drawn where the layout says")
						local k = c.x .. "," .. c.y
						assert.is_nil(seen[k], where .. ": two buttons at " .. k)
						seen[k] = true
					end
				end
				assert.falsy(v.redrawPending, where)
			end
			check("run " .. run .. " open")
			for step = 1, 40 do
				local where = ("run %d step %d"):format(run, step)
				local hovered = {}
				for _ = 1, rand(3) - 1 do
					local b = f.buttons[rand(2) == 1 and 6 or 12][rand(12)]
					if b.shown then
						b.mouseOver = true
						hovered[#hovered + 1] = { b, at(b) }
					end
				end
				local bag, slot = rand(2) == 1 and 6 or 12, rand(12)
				local had = A.slots[bag][slot]
				local change
				if had and rand(2) == 1 then
					A.Clear(bag, slot)
					change = { bag = bag, slot = slot, kind = "left", icon = had.itemID }
					count.left = count.left + 1
				else
					local i = rand(#POOL)
					local id = POOL[i]
					if had and had.itemID == id then
						id = POOL[i % #POOL + 1] -- a different item, so the slot really changes
					end
					A.Put(bag, slot, id, 1)
					change = { bag = bag, slot = slot, kind = "arrived", icon = had and had.itemID }
					count.arrived = count.arrived + 1
				end
				local held = v.stats.heldRedraws or 0
				local warbandTop = v.pos.groupHeaders[2].y
				v.SetRecord(bag, slot, SB.Items.Describe(bag, slot))
				v.Changes(bag == 6 and "bank" or "warband", { change })
				if (v.stats.heldRedraws or 0) > held then
					count.holds = count.holds + 1
				end
				for _, h in ipairs(hovered) do
					assert.same(h[2], at(h[1]), where .. ": a hovered button moved")
				end
				if v.pos.groupHeaders[2].y ~= warbandTop then
					count.pushes = count.pushes + 1 -- the bank grew or shrank and the warband followed
				end
				if rand(4) == 1 or step == 40 then
					for _, h in ipairs(hovered) do
						h[1].mouseOver = false
					end
					A.Advance(1)
					count.drains = count.drains + 1
					check(where .. " drained")
				else
					for _, h in ipairs(hovered) do
						h[1].mouseOver = false
					end
				end
			end
			v.Clear()
		end
		assert.truthy(count.left >= 150, "lefts " .. count.left)
		assert.truthy(count.arrived >= 150, "arrivals " .. count.arrived)
		assert.truthy(count.drains >= 100, "drains " .. count.drains)
		assert.truthy(count.holds >= 5, "held pushes " .. count.holds)
		assert.truthy(count.pushes >= 5, "warband pushed by the bank growing " .. count.pushes)
	end)
end)
