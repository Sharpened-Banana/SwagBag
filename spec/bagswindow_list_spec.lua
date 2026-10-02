-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown GameTooltip
-- The bags window's list view (spec 2.2 v1.3), end to end over the real engine with fake frames
-- and buttons: one row per slot, the slot's own button at the row's left edge, the same sections,
-- New, Free, placeholders, focus modes and hover guard as the category view.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/OverlayData.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/Sort.lua",
	"SwagBag/Engine/Focus.lua",
}

-- Fake frame: shown state, scripts (Hide fires OnHide like the client), points, text, scale, mouse-over.
local function newFake(kind)
	local f = { kind = kind, shown = false, scale = 1, alpha = 1, vscroll = 0, w = 0, h = 0, scripts = {}, points = {},
		calls = {} }
	local methods = {
		IsShown = function(self) return self.shown end,
		Show = function(self) self.shown = true end,
		Hide = function(self)
			local was = self.shown
			self.shown = false
			if was and self.scripts.OnHide then
				self.scripts.OnHide(self)
			end
		end,
		IsMouseOver = function(self) return self.mouseOver == true end,
		SetScale = function(self, s) self.scale = s end,
		GetScale = function(self) return self.scale end,
		SetAlpha = function(self, a) self.alpha = a end,
		SetSize = function(self, w, h) self.w, self.h = w, h end,
		GetHeight = function(self) return self.h end,
		SetScript = function(self, n, fn) self.scripts[n] = fn end,
		SetVerticalScroll = function(self, v) self.vscroll = v end,
		GetVerticalScroll = function(self) return self.vscroll end,
		ClearAllPoints = function(self) self.points = {} end,
		SetPoint = function(self, ...)
			self.points[#self.points + 1] = { ... }
			local p = { ... }
			if p[3] == "BOTTOMLEFT" and (p[1] == "TOPLEFT" or p[1] == "BOTTOMLEFT") then
				self.anchor, self.left, self.edgeY = p[1], p[4], p[5]
			end
		end,
		GetLeft = function(self) return self.left end,
		GetTop = function(self)
			if self.anchor == "BOTTOMLEFT" then
				return self.edgeY + self.h
			end
			return self.edgeY
		end,
		SetText = function(self, s) self.text = s end,
		CreateFontString = function() return newFake("FontString") end,
		CreateTexture = function() return newFake("Texture") end,
	}
	return setmetatable(f, {
		__index = function(_, name)
			return methods[name] or function(self, ...) self.calls[name] = { ... } end
		end,
	})
end

-- Fake button pool: records placement (in the parent's units, as Buttons.Place promises), paint,
-- scale and dimming; placeholders as plain tables.
local function fakeButtons()
	local B = { created = true, buttons = {}, placeholders = {}, DIM_ALPHA = 0.2, PLACEHOLDER_ALPHA = 0.5 }
	function B.EnsureCapacity(bag, n)
		B.buttons[bag] = B.buttons[bag] or {}
		for slot = #B.buttons[bag] + 1, n do
			local b = newFake("ItemButton")
			b.bag, b.slot, b.placed = bag, slot, 0
			B.buttons[bag][slot] = b
		end
	end
	function B.Count(bag) return #(B.buttons[bag] or {}) end
	function B.Get(bag, slot) return B.buttons[bag] and B.buttons[bag][slot] end
	function B.Place(button, x, y)
		button.x, button.y = x, y
		button.placed = button.placed + 1
	end
	function B.Paint(button, info)
		button.itemID = info and info.itemID or nil
		if info then
			button.freeCount = nil
		end
	end
	function B.SetFreeCount(button, n) button.freeCount = n end
	function B.KindOf(bag) return bag <= 5 and "bags" or "bank" end
	function B.SetParentFor() end
	function B.SetDimmed(button, d) button.dimmed = d end
	function B.AcquirePlaceholder(_, icon, size, x, y)
		local p = { icon = icon, size = size, x = x, y = y }
		B.placeholders[#B.placeholders + 1] = p
		return p
	end
	function B.ReleasePlaceholders()
		B.placeholders = {}
	end
	return B
end

describe("BagsWindow list view", function()
	local SB, A, W, B
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- backpack 16 slots: potion x5, flask x2, BoE ring, soulbound helm, keystone, junk x3
		A.items[Fixtures.HEALING_POTION].sellPrice = 100 -- the stack of 5: 500
		A.items[Fixtures.FLASK].sellPrice = 1000 -- the stack of 2: 2000
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		GameTooltip = newFake("GameTooltip")
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SearchBox.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
		SB.Config.Set("bags.view", "list")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown, GameTooltip = nil, nil, nil, nil
	end)

	local function headers()
		local out = {}
		for i, h in ipairs(SB.SectionHeaders.inUse) do
			out[i] = h.text.text
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

	local function row(slot)
		return W.rows.rows[B.Get(0, slot)]
	end

	-- Change the mock bags, then deliver the events the client would send.
	local function bagUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag or 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function rowY(slot)
		return row(slot).points[1][5]
	end

	it("one row per slot: the same sections, the slot's button at the row's left edge, at row size", function()
		assert.truthy(W.Open())
		assert.same({ "- Keystone & Crests (1)", "- Consumables (2) - 25s vendor", "- Gear (1)", "- BoE gear (1)",
			"- Junk (1)", "- Free (10)" }, headers())
		local potion, flask = B.Get(0, 1), B.Get(0, 2)
		assert.equal(W.PAD, potion.x, "every button sits at the left edge")
		assert.equal(W.PAD, flask.x)
		assert.equal(W.LIST_ROW / W.SLOT, potion.scale, "drawn at the row's height")
		assert.equal(W.LIST_ROW + W.LIST_GAP, math.abs(potion.y - flask.y), "one row apart")
		assert.equal(potion.y, rowY(1), "the row's texts sit beside the button")
		assert.equal(W.PAD + W.LIST_ROW + W.ROW_TEXT_GAP, row(1).points[1][4])
		assert.equal(W.LIST_WIDTH, W.child.w, "the list is LIST_WIDTH wide")
		assert.equal("Algari Healing Potion", row(1).name.text)
		assert.equal("5", row(1).count.text)
		assert.equal("285", row(3).ilvl.text, "item level for gear")
		assert.equal("", row(1).ilvl.text, "none for a potion")
	end)

	-- Mutation: in layoutSections, drop the SB.Sort.DisplayOrder call.
	it("each section lists its items in the saved order: value, highest first, by default", function()
		W.Open()
		assert.truthy(B.Get(0, 2).y > B.Get(0, 1).y, "flask (2000) above potion (500)")
		assert.equal("20s", row(2).value.text)
		SB.Sort.Save("name", false)
		W.Close()
		W.Open()
		assert.truthy(B.Get(0, 1).y > B.Get(0, 2).y, "Algari Healing Potion above Flask of Alchemical Chaos")
	end)

	it("the free tile's row says how many slots are free; spares have no row", function()
		W.Open()
		local tile = B.Get(0, 7)
		assert.equal(10, tile.freeCount)
		assert.equal(SB.L.LIST_FREE:format(10), W.rows.rows[tile].name.text)
		assert.falsy(B.Get(0, 8).shown)
		assert.is_nil(W.rows.rows[B.Get(0, 8)], "a hidden spare never got a row")
	end)

	-- Mutation: in setScale, never call SetScale (the buttons stay at row size in the grid).
	it("switching to the grid or the categories draws the buttons at full size again and hides the rows", function()
		W.Open()
		local potion = B.Get(0, 1)
		W.SetView("grid")
		assert.equal(1, potion.scale)
		assert.same({ 4, -4 }, { potion.x, potion.y })
		assert.falsy(row(1).shown)
		W.SetView("sections")
		assert.equal(1, potion.scale)
		assert.falsy(row(1).shown)
		W.SetView("list")
		assert.equal(W.LIST_ROW / W.SLOT, potion.scale)
		assert.truthy(row(1).shown)
	end)

	it("a count change repaints the row in place; nothing moves", function()
		W.Open()
		local potion = B.Get(0, 1)
		local y, placed = potion.y, potion.placed
		A.Put(0, 1, Fixtures.HEALING_POTION, 3)
		bagUpdate()
		assert.equal("3", row(1).count.text)
		assert.equal(y, potion.y)
		assert.equal(placed, potion.placed)
	end)

	-- Spec 4.3 in the list view. Mutation: in renderExtras, drop the W.rows.Ghosts call.
	it("an item that leaves leaves a row-size placeholder and a ghost row; its button goes to Free", function()
		W.Open()
		local junkY = B.Get(0, 6).y
		A.Clear(0, 6)
		bagUpdate()
		assert.equal(1, #B.placeholders)
		assert.equal(W.LIST_ROW, B.placeholders[1].size)
		assert.equal(junkY, B.placeholders[1].y)
		assert.equal(SB.L.LIST_GONE, W.rows.ghosts[1].name.text)
		assert.equal(junkY, W.rows.ghosts[1].points[1][5])
		assert.truthy(W.rows.ghosts[1].shown)
	end)

	-- P5 for rows. Mutation: in buttonBusy, drop the W.rows.IsMouseOver check.
	it("a collapse waits while the mouse is on the row (not the icon) of a button that would move", function()
		W.Open()
		local junk = B.Get(0, 6)
		local y = junk.y
		row(6).mouseOver = true
		W.ToggleSection("c_consumables")
		assert.equal(y, junk.y, "nothing moved under the row")
		row(6).mouseOver = false
		A.Advance(W.RETRY)
		assert.truthy(junk.y > y, "applied once the mouse left the row")
	end)

	-- AC8.2 in the list view: same sections, same mode sets.
	it("a focus mode collapses the same sections as in the category view", function()
		W.Open()
		SB.Focus.SetSignal("challengeMode", true)
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		assert.equal("- Consumables (2) - 25s vendor", header("c_consumables").text.text)
		assert.falsy(row(6).shown, "junk's row is hidden with its section")
		assert.truthy(row(1).shown)
	end)

	-- AC5.1. Mutation: in W.SetDimmed, drop the W.rows.SetDimmed call.
	it("search dims a non-matching row together with its button", function()
		W.Open()
		SB.Slash.Dispatch("search potion")
		assert.equal(0.2, row(6).alpha)
		assert.truthy(B.Get(0, 6).dimmed)
		assert.equal(1, row(1).alpha)
	end)

	-- Item safety (spec 4.1): rows are plain frames; slot buttons are only scaled and placed, never made,
	-- reparented or re-ID'd, also in combat. Mutation: in ListRows' create(), make the row an "ItemButton".
	it("the list view makes only plain frames and never reparents or re-IDs a slot button, also in combat", function()
		local kinds, create = {}, CreateFrame
		CreateFrame = function(kind, ...)
			kinds[#kinds + 1] = kind
			return create(kind, ...)
		end
		A.combat = true
		W.Open()
		W.SetView("sections")
		W.SetView("list")
		assert.truthy(#kinds > 0, "rows were made")
		for _, kind in ipairs(kinds) do
			assert.truthy(kind == "Frame" or kind == "Button", kind) -- rows; pooled section headers
		end
		assert.equal("Frame", row(1).kind)
		for slot = 1, 16 do
			local b = B.Get(0, slot)
			assert.is_nil(b.calls.SetParent, "slot " .. slot)
			assert.is_nil(b.calls.SetID, "slot " .. slot)
		end
	end)

	it("the view button and /swagbag view switch in combat and answer; the label names the next view", function()
		A.combat = true
		W.Open()
		assert.equal(SB.L.VIEW_TO_GRID, W.viewButton.text)
		SB.Slash.Dispatch("view grid")
		assert.equal("grid", W.View())
		assert.equal(SB.L.VIEW_GRID, A.Lines()[1])
		SB.Slash.Dispatch("view")
		assert.equal(SB.L.VIEW_USAGE:format("grid"), A.Lines()[2])
		SB.Slash.Dispatch("view list")
		assert.equal("list", W.View())
		assert.truthy(row(1).shown)
	end)

	it("/swagbag view refuses with read-only settings and changes nothing", function()
		W.Open()
		SB.Config.readOnly = true
		SB.Slash.Dispatch("view grid")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[1])
		assert.equal("list", W.View())
	end)

	it("a layout held under the mouse keeps drawing the old view's geometry until it runs", function()
		SB.Config.Set("bags.newAlways", true) -- New shown, so loot under the mouse lands at once (W4-15)
		W.Open()
		W.scroll.mouseOver = true
		W.SetView("grid")
		assert.equal("list", W.drawn, "held: still the list")
		A.Put(0, 9, Fixtures.HERB, 2)
		bagUpdate()
		assert.equal(W.PAD, B.Get(0, 9).x, "loot arrives as a row")
		W.scroll.mouseOver = false
		A.Advance(W.RETRY)
		assert.equal("grid", W.drawn)
		assert.equal(1, B.Get(0, 9).scale)
	end)

	-- F24 (Task 1 carry): the window passes its title flash to the rows. Mutation: create the rows
	-- with SB.ListRows.New(child, "bags") (no flash: the answer goes to chat instead).
	it("a click on a row's text answers in the title", function()
		W.Open()
		row(1).scripts.OnMouseUp(row(1), "LeftButton")
		assert.equal(SB.L.LIST_ROW_CLICK, W.frame.title.text)
		assert.equal(0, #A.Lines(), "no chat line: the title answered")
	end)

	-- F6 (item safety): a button left at full size in a list row would overlap the next row, so a
	-- click there could use or sell the wrong item. Mutation: in W.Layout, drop the fallback (keep
	-- W.drawn = "list" when scaleAll fails).
	it("if a button's scale does not take, the layout draws as categories and says so once in chat", function()
		SB.Config.Set("bags.view", "sections")
		W.Open()
		local keystone = B.Get(0, 5)
		local at = { keystone.x, keystone.y }
		for slot = 1, 16 do
			B.Get(0, slot).SetScale = function() end -- the client ignores the scale
		end
		W.SetView("list")
		assert.equal("sections", W.drawn, "drawn as categories")
		assert.equal("list", W.View(), "the setting is kept")
		assert.equal(1, B.Get(0, 1).scale)
		assert.same(at, { keystone.x, keystone.y }, "the category view's geometry")
		assert.is_nil(W.rows.rows[B.Get(0, 1)], "no list rows were drawn")
		assert.same({ SB.L.LIST_SCALE_FALLBACK }, A.Lines())
		W.Reflow()
		assert.equal("sections", W.drawn)
		assert.equal(1, #A.Lines(), "one chat line per opening of the bag")
	end)

	it("a scale that takes within float rounding counts as taken", function()
		SB.Config.Set("bags.view", "sections")
		W.Open()
		for slot = 1, 16 do
			B.Get(0, slot).SetScale = function(self, s) self.scale = s + 1e-7 end -- WoW keeps a float
		end
		W.SetView("list")
		assert.equal("list", W.drawn)
		assert.equal(0, #A.Lines())
	end)

	-- F6 for a bag equipped while the list is open. Mutation: in sizeChanges, ignore setScale's result.
	it("a slot added to the open list whose scale does not take regroups the bag as categories", function()
		W.Open()
		local ensure = B.EnsureCapacity
		B.EnsureCapacity = function(bag, n)
			ensure(bag, n)
			for _, b in ipairs(B.buttons[bag]) do
				b.SetScale = function() end
			end
		end
		A.SetBagSize(1, 4)
		bagUpdate(1)
		A.Advance(0)
		assert.equal("sections", W.drawn)
		assert.equal(1, B.Get(0, 1).scale, "every button back at full size")
		assert.same({ SB.L.LIST_SCALE_FALLBACK }, A.Lines())
	end)

	-- F7: New keeps 8 rows in the list, so a dungeon's loot stays under New. Mutation: LIST_NEW_ROWS = 4.
	it("New holds eight rows of loot; the ninth goes to Free with a hint", function()
		W.Open()
		for slot = 7, 15 do
			A.Put(0, slot, Fixtures.HERB, 1)
		end
		bagUpdate()
		assert.equal(8, W.LIST_NEW_ROWS)
		assert.equal("- New (8)  +1 more below", header("new").text.text)
	end)

	-- F8: the Value column follows a price change in place, like the header totals. Mutation: drop
	-- the rows repaint from the SB_PRICES_CHANGED handler.
	it("a price change repaints the Value column in place; nothing re-sorts or moves", function()
		W.Open()
		local potion, flask = B.Get(0, 1), B.Get(0, 2)
		local y, placed = potion.y, potion.placed
		A.items[Fixtures.HEALING_POTION].sellPrice = 10000 -- the stack of 5: 5g, now above the flask
		SB.Prices.Invalidate()
		SB.Emit("SB_PRICES_CHANGED")
		assert.equal(SB.Prices.Money(50000), row(1).value.text)
		assert.equal(y, potion.y, "the potion stays where it is")
		assert.equal(placed, potion.placed)
		assert.truthy(flask.y > potion.y, "no re-sort until a full layout")
	end)

	-- Re-sorting only happens in a full layout. Mutation: a count change requests a layout.
	it("a count change that would change the order never re-sorts", function()
		W.Open()
		local potion, flask = B.Get(0, 1), B.Get(0, 2)
		local y = potion.y
		A.Put(0, 1, Fixtures.HEALING_POTION, 50) -- 5000 copper, above the flask's 2000
		bagUpdate()
		assert.equal("50", row(1).count.text)
		assert.equal(y, potion.y)
		assert.truthy(flask.y > potion.y)
		W.Reflow()
		assert.truthy(potion.y > flask.y, "a full layout sorts it up")
	end)

	-- F9: the reagent bag's tile row says it takes reagents. Mutation: in paintTiles, drop t.tile
	-- from the W.rows.Paint call.
	it("the reagent bag's free row says it is for reagents", function()
		A.SetBagSize(5, 2)
		SB.Inventory.ScanAll()
		W.Open()
		assert.equal(SB.L.LIST_FREE_REAGENT:format(2), W.rows.rows[B.Get(5, 1)].name.text)
		assert.equal(SB.L.LIST_FREE:format(10), W.rows.rows[B.Get(0, 7)].name.text)
	end)
end)

describe("Buttons.Place at a scale", function()
	it("offsets a scaled button by x / scale and y / scale, so it lands on the same spot", function()
		local SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua" })
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		local parent = Fake.New("Frame")
		local b = Fake.New("ItemButton", parent)
		b:SetScale(0.5)
		SB.Buttons.Place(b, 40, -60)
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 80, -120 }, b.points[1])
		b:SetScale(1)
		SB.Buttons.Place(b, 40, -60)
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 40, -60 }, b.points[1])
		Fake.Uninstall()
	end)
end)
