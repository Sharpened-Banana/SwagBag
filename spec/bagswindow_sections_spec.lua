-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown GameTooltip
-- The bags window's category view, end to end over the real engine (Inventory, Items,
-- Keywords, Categories, Categorizer, Layout, SectionHeaders) with fake frames and buttons.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/OverlayData.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua",
}

-- Fake frame: shown state, scripts (Hide fires OnHide like the client), points, text, mouse-over.
local function newFake(kind)
	local f = { kind = kind, shown = false, scale = 1, vscroll = 0, w = 0, h = 0, scripts = {}, points = {}, calls = {} }
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
		SetSize = function(self, w, h)
			-- Like the client: a bottom anchor keeps the bottom edge, so the top edge moves with the height.
			self.w, self.h = w, h
		end,
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
		GetPoint = function(self, i)
			local p = self.points[i]
			if p then
				return p[1], p[2], p[3], p[4], p[5]
			end
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

-- Fake button pool: records placement, paint and dimming; placeholders as plain tables.
local function fakeButtons()
	local B = { created = true, buttons = {}, placeholders = {}, released = 0 }
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
		if info then -- like the real pool: a filled button never shows a free tile's number
			button.freeCount = nil
		end
	end
	function B.SetFreeCount(button, n) button.freeCount = n end
	function B.KindOf(bag) return bag <= 5 and "bags" or "bank" end
	function B.SetParentFor() end
	function B.SetDimmed(button, d) button.dimmed = d end
	function B.AcquirePlaceholder(_, icon, _, x, y)
		local p = { icon = icon, x = x, y = y }
		B.placeholders[#B.placeholders + 1] = p
		return p
	end
	function B.ReleasePlaceholders()
		B.placeholders = {}
		B.released = B.released + 1
	end
	return B
end

describe("BagsWindow category view", function()
	local SB, A, W, B
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- backpack 16 slots: potion, flask, BoE ring, soulbound helm, keystone, junk
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Overlays.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
	end)

	local function headers()
		local out = {}
		for i, h in ipairs(SB.SectionHeaders.inUse) do
			out[i] = h.text.text
		end
		return out
	end

	-- Counts header Acquire/ReleaseAll calls from now on (the pool hands the same frames back, so
	-- identity alone cannot tell a redraw from an in-place update).
	local function countChurn()
		local H, n = SB.SectionHeaders, { acquired = 0, released = 0 }
		local acquire, release = H.Acquire, H.ReleaseAll
		H.Acquire = function(...) n.acquired = n.acquired + 1 return acquire(...) end
		H.ReleaseAll = function(...) n.released = n.released + 1 return release(...) end
		return n
	end

	local function header(id)
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId == id then
				return h
			end
		end
	end

	local function at(bag, slot)
		local b = B.Get(bag, slot)
		return { b.x, b.y }
	end

	-- The tests that pin Free's cells one by one show every free slot (bags.freeTile = false, the
	-- alternative to the free tile, plan D19). The free tile has its own tests below.
	local function everyFreeSlot()
		SB.Config.Set("bags.freeTile", false)
	end

	it("opens in the category view: sections in display order, New reserved on top, Free last", function()
		assert.truthy(W.Open())
		assert.same({ "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "- BoE gear (1)",
			"- Junk (1)", "- Free (10)" }, headers())
		-- New's header at y=-4 and its two reserved rows; Keystone's header at -108, its cell at -128 ...
		assert.same({ 4, -128 }, at(0, 5), "keystone: first cell under its header")
		assert.same({ 4, -191 }, at(0, 1), "potion: first cell of Consumables")
		assert.same({ 45, -191 }, at(0, 2), "flask: second cell of Consumables")
		assert.equal(16, #W.cells)
	end)

	it("shows every slot button exactly once, each at its own cell", function()
		everyFreeSlot()
		W.Open()
		local seen = {}
		for slot = 1, 16 do
			local b = B.Get(0, slot)
			assert.truthy(b.shown, "slot " .. slot)
			local key = b.x .. "," .. b.y
			assert.is_nil(seen[key], "two buttons at " .. key)
			seen[key] = true
		end
	end)

	it("collapsing hides a section, re-stacks the rest, is saved per character, and expanding restores the cells", function()
		W.Open()
		local before = { at(0, 1), at(0, 3), at(0, 7) }
		header("c_consumables").scripts.OnClick(header("c_consumables"))
		assert.equal(true, SB.Config.UI().collapsed.bags.c_consumables)
		assert.falsy(B.Get(0, 1).shown)
		assert.equal("+ Consumables (2)", header("c_consumables").text.text)
		assert.equal(before[2][2] + 37, at(0, 3)[2], "Gear moved up by Consumables' row")
		header("c_consumables").scripts.OnClick(header("c_consumables"))
		assert.is_nil(SB.Config.UI().collapsed.bags.c_consumables)
		assert.same(before, { at(0, 1), at(0, 3), at(0, 7) })
	end)

	it("collapse state survives closing and reopening", function()
		W.Open()
		W.ToggleSection("c_gear")
		W.Close()
		W.Open()
		assert.equal("+ Gear (1)", header("c_gear").text.text)
		assert.falsy(B.Get(0, 4).shown)
	end)

	it("the header button switches to the grid and back without /reload, also in combat (AC3.1)", function()
		W.Open()
		A.combat = true
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("grid", SB.Config.Get("bags.view"))
		assert.equal(SB.L.VIEW_TO_SECTIONS, W.viewButton.text)
		assert.equal(SB.L.VIEW_GRID, W.frame.title.text)
		assert.same({ 4, -4 }, at(0, 1), "grid: physical order")
		assert.same({}, headers())
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("sections", SB.Config.Get("bags.view"))
		assert.same({ 4, -191 }, at(0, 1))
		assert.equal(7, #headers())
	end)

	it("a collapse waits while a button that would move is under the mouse", function()
		W.Open()
		local helm = B.Get(0, 4)
		helm.mouseOver = true
		W.ToggleSection("c_consumables")
		local y = helm.y
		assert.truthy(B.Get(0, 1).shown, "not applied yet")
		A.Advance(0.3)
		assert.equal(y, helm.y)
		helm.mouseOver = false
		A.Advance(0.3)
		assert.falsy(B.Get(0, 1).shown)
		assert.truthy(helm.y > y)
	end)

	it("closing forgets the layout and releases placeholders", function()
		W.Open()
		local released = B.released
		W.Close()
		assert.is_nil(W.state)
		assert.truthy(B.released > released)
	end)

	-- Change the mock bags, then deliver the events the client would send.
	local function bagUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag or 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function lastPoint()
		return W.frame.points[#W.frame.points]
	end

	it("a collapse that changes the height keeps the top-left corner fixed (C1)", function()
		SB.Config.UI().positions.bags = { "BOTTOMLEFT", "BOTTOMLEFT", 100, 200 } -- old format, bottom anchor
		W.Open()
		local left, top, height = W.frame:GetLeft(), W.frame:GetTop(), W.frame.h
		header("c_consumables").scripts.OnClick(header("c_consumables"))
		assert.truthy(W.frame.h ~= height, "the collapse changed the height")
		assert.same({ left, top }, { W.frame:GetLeft(), W.frame:GetTop() })
		assert.equal("TOPLEFT", lastPoint()[1])
	end)

	it("an ApplyChanges that adds a Free row keeps the top-left corner fixed (C1)", function()
		everyFreeSlot()
		SB.Config.UI().positions.bags = { "BOTTOMLEFT", "BOTTOMLEFT", 100, 200 }
		W.Open()
		local left, top, height = W.frame:GetLeft(), W.frame:GetTop(), W.frame.h
		A.SetBagSize(1, 30) -- a bag equipped while open: Free grows by more than a row
		bagUpdate(1)
		assert.truthy(W.frame.h ~= height, "the height changed")
		assert.same({ left, top }, { W.frame:GetLeft(), W.frame:GetTop() })
		assert.equal("TOPLEFT", lastPoint()[1])
	end)

	it("the open path restores a saved position, also in the old point+offset format (C1)", function()
		SB.Config.UI().positions.bags = { "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 40 }
		assert.truthy(W.Open())
		local p = W.frame.points[1]
		assert.same({ "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 40 }, { p[1], p[2], p[3], p[4], p[5] })
		assert.equal(1, #W.frame.points, "open did not re-anchor")
		W.Close()
		SB.Config.UI().positions.bags = { "TOPLEFT", "BOTTOMLEFT", 100, 900 }
		assert.truthy(W.Open())
		p = W.frame.points[1]
		assert.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 100, 900 }, { p[1], p[2], p[3], p[4], p[5] })
	end)

	it("Ctrl+wheel scaling keeps the top-left corner on screen (C1)", function()
		SB.Config.UI().positions.bags = { "TOPLEFT", "BOTTOMLEFT", 100, 900 }
		W.Open()
		IsControlKeyDown = function() return true end
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		local p = lastPoint()
		assert.equal("TOPLEFT", p[1])
		assert.truthy(math.abs(p[4] * 1.05 - 100) < 1e-6 and math.abs(p[5] * 1.05 - 900) < 1e-6,
			"screen position unchanged after the scale change")
	end)

	it("a Ctrl+wheel scale change saves the new corner; a second notch from 120 % keeps it on screen", function()
		SB.Config.Set("bags.scale", 1.2)
		SB.Config.UI().positions.bags = { "TOPLEFT", "BOTTOMLEFT", 100, 900 }
		W.Open()
		IsControlKeyDown = function() return true end
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		assert.truthy(math.abs(SB.Config.Get("bags.scale") - 1.3) < 1e-9)
		local saved = SB.Config.UI().positions.bags
		assert.equal("TOPLEFT", saved[1])
		assert.truthy(math.abs(saved[3] * 1.3 - 100 * 1.2) < 1e-6 and math.abs(saved[4] * 1.3 - 900 * 1.2) < 1e-6,
			"the saved corner is the same screen spot, in the new scale")
		W.Close()
		W.Open()
		local p = W.frame.points[1]
		assert.same({ "TOPLEFT", "BOTTOMLEFT" }, { p[1], p[3] })
		assert.truthy(math.abs(p[4] * 1.3 - 120) < 1e-6, "a reopen lands where the window was")
	end)

	it("while the window is dragged a scale change does not re-anchor it; the drop saves the corner", function()
		SB.Config.UI().positions.bags = { "TOPLEFT", "BOTTOMLEFT", 100, 900 }
		W.Open()
		W.frame.scripts.OnDragStart(W.frame)
		local setPoints, realSetPoint = 0, W.frame.SetPoint
		W.frame.SetPoint = function(self, ...)
			setPoints = setPoints + 1
			return realSetPoint(self, ...)
		end
		IsControlKeyDown = function() return true end
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		assert.equal(1.05, W.frame.scale)
		assert.equal(0, setPoints, "no SetPoint during the drag")
		W.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 300, 700) -- where the client moved it
		W.frame.scripts.OnDragStop(W.frame)
		assert.same({ "TOPLEFT", "BOTTOMLEFT", 300, 700 }, SB.Config.UI().positions.bags)
	end)

	it("Ctrl+wheel scaling only resizes; it does not regroup", function()
		W.Open()
		IsControlKeyDown = function() return true end
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		assert.equal(1.05, SB.Config.Get("bags.scale"))
		assert.equal("open", W.stats.lastLayoutReason)
	end)

	it("collapse state survives a fresh Config.Init on the same saved tables", function()
		W.Open()
		W.ToggleSection("c_gear")
		local db, charDB = SB.Config.db, SB.Config.charDB
		SB.Config.Init(db, charDB)
		assert.equal(true, W.Collapsed().c_gear)
		W.Close()
		W.Open()
		assert.equal("+ Gear (1)", header("c_gear").text.text)
	end)

	it("the OnHide IsShown guard comes first: a hide while still shown (Alt+Z) emits nothing", function()
		W.Open()
		local closed = 0
		SB.On("SB_BAGS_CLOSED", function() closed = closed + 1 end)
		W.frame.scripts.OnHide(W.frame) -- frame still shown
		assert.equal(0, closed)
		assert.truthy(W.state)
		W.Close()
		assert.equal(1, closed)
	end)

	it("a toggle that reopens the window mid-frame leaves a clean, fully laid out view", function()
		W.Open()
		SB.On("SB_BAGS_CLOSED", function() W.Open() end)
		W.Close()
		assert.truthy(W.IsOpen())
		assert.truthy(W.state)
		assert.equal(7, #headers())
		assert.equal(16, #W.cells)
	end)

	it("the view toggle in the grid works in combat and the button label follows the saved view on Open", function()
		SB.Config.Set("bags.view", "grid")
		W.Open()
		assert.equal(SB.L.VIEW_TO_SECTIONS, W.viewButton.text)
		A.combat = true
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal(7, #headers())
		assert.equal(SB.L.VIEW_TO_GRID, W.viewButton.text)
	end)

	local function placedCounts()
		local out = {}
		for slot = 1, 16 do
			out[slot] = B.Get(0, slot).placed
		end
		return out
	end

	it("using up an item leaves a placeholder with its icon; its button goes to Free; nothing else moves", function()
		everyFreeSlot()
		W.Open()
		local potionAt, counts = at(0, 1), placedCounts()
		A.Clear(0, 1)
		bagUpdate()
		assert.equal(1, #B.placeholders)
		assert.same({ Fixtures.HEALING_POTION, potionAt[1], potionAt[2] },
			{ B.placeholders[1].icon, B.placeholders[1].x, B.placeholders[1].y })
		assert.equal(counts[1] + 1, B.Get(0, 1).placed, "the emptied button moved once")
		for slot = 2, 16 do
			assert.equal(counts[slot], B.Get(0, slot).placed, "slot " .. slot .. " did not move")
		end
		assert.equal("- Free (11)", header("free").text.text)
		assert.truthy(W.state.needsReflow)
	end)

	it("a drag to an empty slot and a stack split in one update: one placeholder, both show in New (Review Focus 1)",
		function()
			everyFreeSlot()
			W.Open()
			local counts = placedCounts()
			local ringAt = at(0, 3)
			A.Clear(0, 3) -- the ring is dragged ...
			A.Put(0, 7, Fixtures.BOE_RING, 1) -- ... to an empty slot
			A.Put(0, 1, Fixtures.HEALING_POTION, 3) -- two potions are split off ...
			A.Put(0, 8, Fixtures.HEALING_POTION, 2) -- ... into another empty slot
			bagUpdate()
			assert.equal(1, #B.placeholders)
			assert.same(ringAt, { B.placeholders[1].x, B.placeholders[1].y })
			assert.same({ 4, -24 }, at(0, 7), "the ring shows first in New")
			assert.same({ 45, -24 }, at(0, 8), "the split stack second")
			for _, slot in ipairs({ 1, 2, 4, 5, 6, 9, 10 }) do
				assert.equal(counts[slot], B.Get(0, slot).placed, "slot " .. slot .. " did not move")
			end
		end)

	it("a looted item goes to New; New's header counts it", function()
		W.Open()
		A.Put(0, 10, Fixtures.HERB, 20)
		bagUpdate()
		assert.same({ 4, -24 }, at(0, 10), "first cell of New")
		assert.equal("- New (1)", header("new").text.text)
		assert.equal(0, #B.placeholders, "it came from Free: no placeholder")
	end)

	it("a live change touches only the moved button's frame, not every slot (incremental render)", function()
		W.Open()
		local gets, realGet = 0, B.Get
		B.Get = function(bag, slot)
			gets = gets + 1
			return realGet(bag, slot)
		end
		A.Clear(0, 1)
		bagUpdate()
		B.Get = realGet
		assert.equal(1, #B.placeholders)
		-- the changed slot's repaint, its overlay, the one button that moved and the free tile's number
		assert.truthy(gets <= 5, "Buttons.Get called " .. gets .. " times for one change in 16 slots")
		assert.equal(16, #W.cells, "search still sees every slot")
	end)

	it("a slot past the bag's size is never shown again while its removal is held back", function()
		everyFreeSlot() -- with the free tile, bag 1's empty slots would be hidden spares anyway
		A.SetBagSize(1, 4)
		SB.Inventory.ScanAll()
		W.Open()
		A.cursor = { itemID = Fixtures.FLASK } -- holds every move
		A.SetBagSize(1, 0)
		bagUpdate(1)
		assert.equal(4, #W.state.deferred, "the removals wait")
		W.Render()
		for slot = 1, 4 do
			assert.falsy(B.Get(1, slot).shown, "slot " .. slot)
		end
		assert.equal(16, #W.cells, "only the backpack is searchable")
		A.cursor = nil
		A.Advance(0.3)
		assert.equal(0, #W.state.deferred)
		assert.falsy(B.Get(1, 4).shown)
	end)

	it("section headers show each category's total value, marked vendor without Auctionator (F10)", function()
		A.items[Fixtures.HEALING_POTION].sellPrice = 2500 -- 5 potions: 1g 25s at a vendor
		A.items[Fixtures.FLASK].sellPrice = 60000 -- 2 flasks: 12g
		W.Open()
		assert.equal("- Consumables (2) - 13g vendor", header("c_consumables").text.text)
		assert.equal("- Gear (1)", header("c_gear").text.text, "nothing worth anything: no value")
		A.auctionator = { prices = { ["item:" .. Fixtures.FLASK] = 12400000 } } -- 1,240g each
		SB.Prices.Invalidate()
		W.Close()
		W.Open()
		assert.equal("- Consumables (2) - 2,481g", header("c_consumables").text.text, "AH flasks plus vendor potions")
		SB.Config.Set("prices.headerTotals", false)
		W.Close()
		W.Open()
		assert.equal("- Consumables (2)", header("c_consumables").text.text)
	end)

	-- Mutation: delete the `W.RefreshHeaders()` call in the BAG_UPDATE handler.
	it("a stack's count changing with no button moving updates its section's total (F10)", function()
		A.items[Fixtures.HEALING_POTION].sellPrice = 2500
		W.Open()
		assert.equal("- Consumables (2) - 1g vendor", header("c_consumables").text.text)
		local oldPos, frameBefore, pool = W.pos, header("c_consumables"), #SB.SectionHeaders.pool
		local churn = countChurn()
		A.Put(0, 1, Fixtures.HEALING_POTION, 9) -- 9 x 25s = 2g 25s
		bagUpdate(0)
		assert.equal(oldPos, W.pos, "no layout ran, nothing moved")
		assert.equal("- Consumables (2) - 2g vendor", header("c_consumables").text.text)
		assert.equal(frameBefore, header("c_consumables"), "the same header frame, set in place")
		assert.equal(pool, #SB.SectionHeaders.pool, "nothing released or acquired")
		assert.same({ acquired = 0, released = 0 }, churn)
	end)

	-- Mutation: make W.RefreshHeaders call renderExtras(W.pos) again.
	it("new Auctionator prices update the open window's header totals in place (W3-36)", function()
		A.items[Fixtures.FLASK].sellPrice = 60000
		W.Open()
		assert.equal("- Consumables (2) - 12g vendor", header("c_consumables").text.text)
		local oldPos, frameBefore, pool = W.pos, header("c_consumables"), #SB.SectionHeaders.pool
		local churn = countChurn()
		A.auctionator = { prices = { ["item:" .. Fixtures.FLASK] = 12400000 } }
		A.auctionatorCallback()
		A.Advance(0.5)
		assert.equal("- Consumables (2) - 2,480g", header("c_consumables").text.text)
		assert.equal(oldPos, W.pos, "no layout ran")
		assert.equal(frameBefore, header("c_consumables"))
		assert.equal(pool, #SB.SectionHeaders.pool)
		assert.same({ acquired = 0, released = 0 }, churn)
	end)

	it("a warbound-until-equipped item is worth its vendor price, like a bound one (W3-35)", function()
		A.items[Fixtures.FLASK].sellPrice = 60000
		A.auctionator = { prices = { ["item:" .. Fixtures.FLASK] = 12400000 } }
		SB.Prices.Invalidate()
		A.Put(0, 2, Fixtures.FLASK, 2, { onCooldown = true, isWUE = true })
		W.Open()
		assert.equal("- Consumables (2) - 12g", header("c_consumables").text.text, "2 flasks at vendor, Auctionator wins nothing")
	end)

	it("bag items get their overlays; an empty reagent-bag slot is tinted in Free", function()
		A.SetBagSize(5, 2)
		SB.Inventory.ScanAll()
		W.Open()
		local ring = SB.Overlays.regions[B.Get(0, 3)]
		assert.same({ "285", "BoE" }, { ring.topLeft.text, ring.bind.text })
		assert.truthy(SB.Overlays.regions[B.Get(5, 1)].reagent.shown)
		assert.is_nil(SB.Overlays.regions[B.Get(0, 16)], "an ordinary empty slot gets nothing")
		A.Clear(0, 3)
		bagUpdate()
		assert.equal("", ring.topLeft.text, "the emptied slot's overlays are cleared")
	end)

	it("an item whose data loads while open gets its overlays at once (it moves only on the next open)", function()
		W.Open()
		A.Put(0, 10, Fixtures.UNLOADED, 1)
		bagUpdate()
		assert.equal("", SB.Overlays.regions[B.Get(0, 10)].topLeft.text)
		A.items[Fixtures.UNLOADED] = { name = "Robe", classID = A.ITEM_CLASS.Armor, subclassID = 0, quality = 3,
			equipLoc = "INVTYPE_CHEST", ilvl = 280, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		assert.equal("280", SB.Overlays.regions[B.Get(0, 10)].topLeft.text)
	end)

	-- The free tile's number on a slot button (nil: none).
	local function number(bag, slot)
		return rawget(B.Get(bag, slot), "freeCount")
	end

	-- Plan D19 (the user's request W3-12): the free tile. Mutation: `freeTile = false` in
	-- layoutSections' Build options.
	it("Free shows one tile per bag family with its number of free slots; the other empty slots are hidden", function()
		A.SetBagSize(5, 2)
		SB.Inventory.ScanAll()
		W.Open()
		assert.equal("- Free (12)", header("free").text.text)
		assert.same({ true, 10 }, { B.Get(0, 7).shown, number(0, 7) }, "the backpack's first empty slot")
		assert.same({ true, 2 }, { B.Get(5, 1).shown, number(5, 1) }, "the reagent bag has its own tile")
		for slot = 8, 16 do
			assert.falsy(B.Get(0, slot).shown, "slot " .. slot)
		end
		assert.falsy(B.Get(5, 2).shown)
		assert.equal(18, #W.cells, "search still sees every slot")
		assert.truthy(SB.Overlays.regions[B.Get(5, 1)].reagent.shown, "the reagent tile keeps its green tint")
	end)

	-- Mutation: `if button and t.shown then` in paintTiles (no "really empty" check): the number
	-- shows on the dropped item when another change redraws while the mouse is still on it.
	it("a drop on the tile: the item stays under the mouse with no number; then the next empty slot takes its place",
		function()
			W.Open()
			local tile, tileAt = B.Get(0, 7), at(0, 7)
			tile.mouseOver = true
			A.Put(0, 7, Fixtures.HERB, 5)
			bagUpdate()
			assert.same(tileAt, at(0, 7), "nothing moves under the mouse")
			assert.is_nil(number(0, 7), "the item shows, not the number")
			assert.falsy(B.Get(0, 8).shown)
			A.Clear(0, 2) -- the flask is used meanwhile: a redraw while the drop still waits
			bagUpdate()
			assert.same(tileAt, at(0, 7))
			assert.is_nil(number(0, 7))
			tile.mouseOver = false
			A.Advance(0.3)
			assert.same({ 4, -24 }, at(0, 7), "the dropped item is first in New")
			assert.same({ true, 10 }, { B.Get(0, 8).shown, number(0, 8) }, "10 - 1 + the flask's slot")
			assert.same(tileAt, at(0, 8), "the next empty slot is where the tile was")
			assert.equal("- Free (10)", header("free").text.text)
		end)

	it("with an item on the cursor the tile keeps its place and number until the item is put down", function()
		W.Open()
		local tileAt = at(0, 7)
		A.cursor = { itemID = Fixtures.FLASK }
		A.Clear(0, 1)
		A.Put(0, 7, Fixtures.HEALING_POTION, 5) -- the potion stack dragged onto the tile
		bagUpdate()
		assert.same(tileAt, at(0, 7))
		assert.truthy(B.Get(0, 1).shown, "the emptied potion slot waits too")
		A.cursor = nil
		A.Advance(0.3)
		assert.falsy(B.Get(0, 1).shown, "the emptied slot is a hidden free slot now")
		assert.same(tileAt, at(0, 8))
		assert.equal(10, number(0, 8))
		assert.equal(1, #B.placeholders)
	end)

	-- Mutations: delete the SB_FREE_TILE_CHANGED handler; delete paintTiles(nil) in layoutGrid.
	it("/swagbag free all regroups once the mouse leaves; the grid view never has a tile (AC3.6)", function()
		W.Open()
		SB.Config.Set("bags.freeTile", false)
		W.scroll.mouseOver = true
		SB.Emit("SB_FREE_TILE_CHANGED")
		assert.falsy(B.Get(0, 8).shown, "waits while the mouse is over the items")
		W.scroll.mouseOver = false
		A.Advance(0.3)
		for slot = 7, 16 do
			assert.truthy(B.Get(0, slot).shown, "slot " .. slot)
		end
		assert.is_nil(number(0, 7))
		SB.Config.Set("bags.freeTile", true)
		SB.Emit("SB_FREE_TILE_CHANGED")
		assert.equal(10, number(0, 7))
		W.SetView("grid")
		for slot = 7, 16 do
			assert.truthy(B.Get(0, slot).shown, "grid: slot " .. slot)
		end
		assert.is_nil(number(0, 7), "the grid is the physical order: no tile")
	end)

	-- W3-21: a herb bag swapped for a plain bag of the same size changes no slot count, so only
	-- BAG_CONTAINER_UPDATE tells the window. Mutation: delete the BAG_CONTAINER_UPDATE handler:
	-- bag 1 keeps its own tile until the next full layout.
	it("a bag swapped for another of the same size regroups Free once the mouse leaves (W3-21)", function()
		local family = { [1] = "family8" }
		A.BagFamily = function(bag) return family[bag] or (bag == 5 and "reagent" or "any") end
		A.SetBagSize(1, 4)
		SB.Inventory.ScanAll()
		W.Open()
		assert.same({ true, 4 }, { B.Get(1, 1).shown, number(1, 1) }, "the herb bag's own tile")
		assert.equal(10, number(0, 7))
		family[1] = "any" -- swapped for a plain bag with the same number of slots
		W.scroll.mouseOver = true
		SB.eventFrame:Fire("BAG_CONTAINER_UPDATE")
		A.Advance(0.1)
		assert.equal(4, number(1, 1), "waits while the mouse is over the items")
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.same({ false, nil }, { B.Get(1, 1).shown, number(1, 1) }, "now a hidden free slot of the bags")
		assert.equal(14, number(0, 7))
	end)

	-- Review fix 5: a drop on the tile that is picked back up while the mouse is still on it shows
	-- the number again at once. Mutation: delete paintTiles(W.pos) in the inventory handler.
	it("a held drop on the tile that is picked back up shows the number again under the mouse", function()
		W.Open()
		local tile, tileAt = B.Get(0, 7), at(0, 7)
		tile.mouseOver = true
		A.Put(0, 7, Fixtures.HERB, 5)
		bagUpdate()
		assert.is_nil(number(0, 7))
		A.Clear(0, 7) -- picked back up
		bagUpdate()
		assert.same(tileAt, at(0, 7), "still nothing moves under the mouse")
		assert.equal(10, number(0, 7), "the empty tile shows its number while the mouse is on it")
		tile.mouseOver = false
		A.Advance(0.3)
		-- the held changes replay in order (arrived, then left): the next empty slot holds the cell
		assert.same({ tileAt, 10 }, { at(0, 8), number(0, 8) })
		assert.equal("- Free (10)", header("free").text.text)
	end)

	it("a stack count change only repaints", function()
		W.Open()
		local counts = placedCounts()
		A.Put(0, 1, Fixtures.HEALING_POTION, 2)
		bagUpdate()
		assert.same(counts, placedCounts())
		assert.equal(0, #B.placeholders)
	end)

	it("a button under the mouse does not move; it moves 300 ms after the mouse leaves", function()
		everyFreeSlot()
		W.Open()
		local potion = B.Get(0, 1)
		local before = at(0, 1)
		potion.mouseOver = true
		A.Clear(0, 1)
		bagUpdate()
		assert.same(before, at(0, 1))
		A.Advance(0.3)
		assert.same(before, at(0, 1), "still under the mouse")
		potion.mouseOver = false
		A.Advance(0.3)
		assert.truthy(at(0, 1)[2] < before[2], "moved down to Free")
		assert.equal(1, #B.placeholders)
	end)

	it("an item on the cursor holds every move until it is put down", function()
		everyFreeSlot()
		W.Open()
		A.cursor = { itemID = Fixtures.FLASK }
		local before = at(0, 1)
		A.Clear(0, 1)
		bagUpdate()
		assert.same(before, at(0, 1))
		A.cursor = nil
		A.Advance(0.3)
		assert.truthy(at(0, 1)[2] < before[2])
	end)

	it("closing while a move is held back under the mouse is safe; the next open is clean (Review Focus 3)", function()
		W.Open()
		B.Get(0, 1).mouseOver = true
		A.Clear(0, 1)
		bagUpdate()
		assert.equal(1, #W.state.deferred, "exactly one change is held back")
		assert.equal(0, #B.placeholders, "nothing was placed yet")
		W.Close()
		assert.is_nil(W.state)
		B.Get(0, 1).mouseOver = false
		A.Advance(1)
		assert.equal(0, #B.placeholders)
		assert.equal(0, #SB.ErrorTrap.Recent())
		W.Open()
		assert.equal("- Consumables (1)", header("c_consumables").text.text)
	end)

	it("an item whose data loads stays in New until the next open, then joins its section", function()
		W.Open()
		A.Put(0, 10, Fixtures.UNLOADED, 1)
		bagUpdate()
		assert.same({ 4, -24 }, at(0, 10))
		A.items[Fixtures.UNLOADED] = { name = "Robe", classID = A.ITEM_CLASS.Armor, subclassID = 0, quality = 3,
			equipLoc = "INVTYPE_CHEST", ilvl = 280, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		assert.same({ 4, -24 }, at(0, 10), "loaded: still in New while open")
		W.Close()
		W.Open()
		assert.equal("- BoE gear (2)", header("c_boe").text.text)
	end)

	it("closing after changes releases the placeholders; reopening regroups everything", function()
		W.Open()
		A.Clear(0, 1)
		bagUpdate()
		assert.equal(1, #B.placeholders)
		W.Close()
		assert.equal(0, #B.placeholders)
		W.Open()
		assert.equal(0, #B.placeholders)
		assert.equal("- Consumables (1)", header("c_consumables").text.text)
		assert.falsy(W.state.needsReflow)
	end)

	it("a cooldown search stays correct: cooldown events refresh only while the search uses cooldown", function()
		W.Open()
		local updated = 0
		SB.On("SB_BAGS_UPDATED", function() updated = updated + 1 end)
		SB.Search.SetText("potion")
		A.slots[0][1].onCooldown = true
		SB.eventFrame:Fire("BAG_UPDATE_COOLDOWN")
		assert.equal(false, W.records[0][1].onCooldown, "no refresh for a search without cooldown")
		assert.equal(0, updated)
		SB.Search.SetText("cooldown")
		SB.eventFrame:Fire("BAG_UPDATE_COOLDOWN")
		assert.equal(true, W.records[0][1].onCooldown)
		assert.equal(1, updated)
	end)

	it("a new item matches the `new` search as soon as it arrives", function()
		W.Open()
		A.Put(0, 10, Fixtures.HERB, 20)
		bagUpdate()
		assert.equal(true, SB.Query.Eval(SB.Query.Compile("new"), W.records[0][10]))
	end)

	it("a bag equipped while open adds its slots at the end of Free", function()
		everyFreeSlot()
		W.Open()
		local counts = placedCounts()
		A.SetBagSize(1, 4)
		bagUpdate(1)
		assert.equal("- Free (14)", header("free").text.text)
		assert.truthy(B.Get(1, 4).shown)
		assert.same(counts, placedCounts(), "nothing in the backpack moved")
		assert.equal("open", W.stats.lastLayoutReason, "no full regroup")
	end)

	it("a refresh for a cooldown search never moves a button or relayouts while open (P5)", function()
		W.Open()
		SB.Search.SetText("cooldown")
		local counts, released = placedCounts(), B.released
		A.slots[0][1].onCooldown = true
		SB.eventFrame:Fire("BAG_UPDATE_COOLDOWN")
		assert.same(counts, placedCounts())
		assert.equal(released, B.released, "no re-render")
		assert.equal("open", W.stats.lastLayoutReason)
		assert.falsy(W.state.needsReflow)
	end)

	it("a bag change in the grid view waits while the mouse is over the window (rule 5)", function()
		SB.Config.Set("bags.view", "grid")
		W.Open()
		W.scroll.mouseOver = true
		A.SetBagSize(1, 4)
		bagUpdate(1)
		assert.equal("open", W.stats.lastLayoutReason)
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.equal("size", W.stats.lastLayoutReason)
	end)

	it("New's +N more below follows an overflow arrival and its departure while New is collapsed", function()
		W.Open()
		W.ToggleSection("new")
		A.Put(0, 10, Fixtures.HERB, 20)
		bagUpdate()
		assert.equal("+ New (0)  +1 more below", header("new").text.text)
		A.Clear(0, 10)
		bagUpdate()
		assert.equal("+ New (0)", header("new").text.text)
	end)

	it("a lock event before the flush does not blank the placeholder icon", function()
		W.Open()
		local icon = W.records[0][3].icon
		assert.truthy(icon)
		A.Clear(0, 3)
		A.Put(0, 7, Fixtures.BOE_RING, 1)
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("ITEM_LOCK_CHANGED", 0, 3)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
		assert.equal(1, #B.placeholders)
		assert.equal(icon, B.placeholders[1].icon)
	end)

	it("a keystone whose link changes (same itemID) stays in place; nothing moves (W12)", function()
		W.Open()
		local counts, before = placedCounts(), at(0, 5)
		A.Put(0, 5, Fixtures.KEYSTONE, 1, { isBound = true,
			link = "|cffa335ee|Hkeystone:180653:503:13:10:9:0:0|h[Keystone: Ara-Kara]|h|r" })
		bagUpdate()
		assert.equal(0, #B.placeholders)
		assert.same(before, at(0, 5))
		assert.same(counts, placedCounts())
		assert.equal(13, tonumber(W.records[0][5].link:match("keystone:%d+:%d+:(%d+)")))
	end)

	it("a retry that changes nothing does not emit SB_BAGS_UPDATED", function()
		W.Open()
		B.Get(0, 1).mouseOver = true
		A.Clear(0, 1)
		bagUpdate()
		local updated = 0
		SB.On("SB_BAGS_UPDATED", function() updated = updated + 1 end)
		A.Advance(0.3)
		assert.equal(0, updated)
		B.Get(0, 1).mouseOver = false
		A.Advance(0.3)
		assert.equal(1, updated)
	end)

	it("a bag taken off while open leaves holes: its buttons hide and nothing else moves", function()
		A.SetBagSize(1, 4)
		SB.Inventory.ScanAll() -- the bag was already equipped when the session started
		W.Open()
		local counts = placedCounts()
		assert.equal("- Free (14)", header("free").text.text)
		A.SetBagSize(1, 0)
		bagUpdate(1)
		assert.falsy(B.Get(1, 4).shown)
		assert.equal("- Free (10)", header("free").text.text)
		assert.same(counts, placedCounts())
		assert.equal("open", W.stats.lastLayoutReason)
		assert.equal(0, #SB.ErrorTrap.Recent())
	end)

	it("dropping an item on a header adds it to that section, confirms, and moves it on Reflow (AC4.3)", function()
		A.Put(0, 10, Fixtures.HERB, 20)
		W.Open()
		local counts = placedCounts()
		A.cursor = { itemID = Fixtures.HERB, link = "|cffffffff|Hitem:210796|h[Mycobloom]|h|r" }
		header("c_consumables").scripts.OnReceiveDrag(header("c_consumables"))
		assert.same({ "Added Mycobloom to Consumables. It moves there when you reopen your bags or press Reflow." },
			A.Lines())
		assert.equal(1, A.cleared, "the item went back to its slot")
		assert.same({ itemList = { include = { [Fixtures.HERB] = true } } }, SB.Config.db.userEdits.c_consumables)
		assert.same(counts, placedCounts(), "nothing moves while the window is open")
		W.reflowButton.scripts.OnClick(W.reflowButton)
		assert.equal("- Consumables (3)", header("c_consumables").text.text)
		assert.is_nil(header("c_herbs"))
	end)

	it("clicking a header while holding an item drops it instead of collapsing", function()
		W.Open()
		A.cursor = { itemID = Fixtures.JUNK }
		header("c_gear").scripts.OnClick(header("c_gear"))
		assert.is_nil(SB.Config.UI().collapsed.bags.c_gear)
		assert.truthy(SB.Categories.Get("c_gear").itemList.include[Fixtures.JUNK])
		assert.equal(1, A.cleared)
	end)

	it("click-pickup then click-drop on a header: the drop runs once and never toggles collapse", function()
		W.Open()
		A.cursor = { itemID = Fixtures.JUNK, link = "|Hitem:156654|h[Broken Tooth]|h" }
		local h = header("c_gear")
		-- The client sends the drop, then the click of the same mouse press.
		h.scripts.OnReceiveDrag(h)
		h.scripts.OnClick(h)
		assert.equal(1, #A.Lines(), "one confirmation")
		assert.equal(1, A.cleared)
		assert.is_nil(SB.Config.UI().collapsed.bags.c_gear, "the empty cursor after the drop did not collapse it")
		A.Advance(0.5)
		h.scripts.OnClick(h) -- a later plain click collapses as usual
		assert.equal(true, SB.Config.UI().collapsed.bags.c_gear)
	end)

	it("a refused drop keeps the item on the cursor and the click that follows does not repeat the message", function()
		W.Open()
		A.cursor = { itemID = Fixtures.JUNK }
		local h = header("new")
		h.scripts.OnReceiveDrag(h)
		h.scripts.OnClick(h)
		assert.same({ "Items can't be added to New. Drop them on a category header." }, A.Lines())
		assert.same({}, SB.Config.db.userEdits)
		assert.truthy(A.cursor, "the user keeps the item")
		assert.equal(0, A.cleared)
		A.printed = {}
		A.Advance(0.5)
		header("free").scripts.OnReceiveDrag(header("free"))
		assert.same({ "Items can't be added to Free. Drop them on a category header." }, A.Lines())
		assert.truthy(A.cursor)
	end)

	it("click first, then the drop of the same press: a refused drop reports once (guard on onDrop)", function()
		W.Open()
		A.cursor = { itemID = Fixtures.JUNK } -- a refused drop keeps the item, so only the guard can stop a repeat
		local h = header("new")
		h.scripts.OnClick(h)
		h.scripts.OnReceiveDrag(h)
		assert.same({ "Items can't be added to New. Drop them on a category header." }, A.Lines())
		assert.truthy(A.cursor)
	end)

	it("dropping on a collapsed header writes the list and leaves it collapsed", function()
		W.Open()
		W.ToggleSection("c_gear")
		A.cursor = { itemID = Fixtures.JUNK }
		header("c_gear").scripts.OnReceiveDrag(header("c_gear"))
		assert.truthy(SB.Categories.Get("c_gear").itemList.include[Fixtures.JUNK])
		assert.equal(true, SB.Config.UI().collapsed.bags.c_gear)
		assert.equal("+ Gear (1)", header("c_gear").text.text)
	end)

	it("closing the window clears the drop guard", function()
		W.Open()
		A.cursor = { itemID = Fixtures.JUNK }
		header("c_gear").scripts.OnReceiveDrag(header("c_gear"))
		W.Close()
		W.Open()
		header("c_gear").scripts.OnClick(header("c_gear"))
		assert.equal(true, SB.Config.UI().collapsed.bags.c_gear, "a click right after reopening is a real click")
	end)

	it("a cooldown-only update does not arm the sort settle", function()
		W.Open()
		W.sortButton.scripts.OnClick(W.sortButton)
		A.Advance(1)
		SB.eventFrame:Fire("BAG_UPDATE_COOLDOWN")
		A.Advance(0.2)
		assert.equal(false, W.sortSawUpdate)
		A.Advance(0.4)
		assert.equal("open", W.stats.lastLayoutReason, "no regroup from a cooldown event")
	end)

	it("a second Sort during a settle does not lose the first sort's regroup", function()
		W.Open()
		W.sortButton.scripts.OnClick(W.sortButton)
		A.Clear(0, 1)
		bagUpdate()
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(2, A.sorts)
		A.Advance(W.SORT_TIMEOUT + 0.1)
		assert.equal("sort", W.stats.lastLayoutReason)
		assert.equal(false, W.sortPending)
		assert.equal(0, #B.placeholders)
	end)

	-- Week-3 carry-over (final review M8). Mutation: ignore SB.Config.Set's result in W.SetView.
	it("the view toggle with read-only settings says so and changes nothing", function()
		W.Open()
		local text, reason = W.viewButton.text, W.stats.lastLayoutReason
		SB.Config.readOnly = true
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal(SB.L.SETTINGS_READONLY, W.frame.title.text)
		assert.equal("sections", SB.Config.Get("bags.view"))
		assert.equal(text, W.viewButton.text)
		assert.equal(reason, W.stats.lastLayoutReason)
	end)

	it("a read-only config refuses the drop with its reason and keeps the item on the cursor", function()
		W.Open()
		SB.Config.readOnly = true
		A.cursor = { itemID = Fixtures.JUNK }
		header("c_gear").scripts.OnReceiveDrag(header("c_gear"))
		assert.same({ SB.L.DROP_READONLY }, A.Lines())
		assert.truthy(A.cursor)
		assert.equal(0, A.cleared)
		assert.same({}, SB.Config.db.userEdits)
	end)

	it("an invalid item is refused with a reason and stays on the cursor", function()
		W.Open()
		A.cursor = { itemID = 0 }
		header("c_gear").scripts.OnReceiveDrag(header("c_gear"))
		assert.same({ SB.L.DROP_INVALID }, A.Lines())
		assert.truthy(A.cursor)
		assert.equal(0, A.cleared)
	end)

	it("dropping with an empty cursor does nothing", function()
		W.Open()
		assert.falsy(W.DropOnSection("c_gear"))
		assert.same({}, A.Lines())
	end)

	it("the sort button sorts, then regroups once the bags settle", function()
		W.Open()
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(1, A.sorts)
		assert.equal(SB.L.SORT_STARTED, W.frame.title.text)
		A.Put(0, 1, Fixtures.JUNK, 3) -- the sort swaps the potion and the junk
		A.Put(0, 6, Fixtures.HEALING_POTION, 5)
		bagUpdate()
		assert.equal(2, #B.placeholders, "while sorting, spec 4.3 holds as usual")
		A.Advance(0.3)
		assert.equal("sort", W.stats.lastLayoutReason)
		assert.equal(0, #B.placeholders)
		assert.same({ 45, -191 }, at(0, 6), "the potion is Consumables' second item now")
		assert.equal(false, W.sortPending)
	end)

	it("the regroup after a sort waits while the mouse is over the items (rule 5)", function()
		W.Open()
		W.sortButton.scripts.OnClick(W.sortButton)
		A.Clear(0, 1)
		bagUpdate()
		W.scroll.mouseOver = true
		A.Advance(0.6)
		assert.equal(1, #B.placeholders)
		assert.equal("open", W.stats.lastLayoutReason)
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.equal("sort", W.stats.lastLayoutReason)
		assert.equal(0, #B.placeholders)
	end)

	it("a sort that changes nothing clears sortPending, so a later bag update does not regroup (W3)", function()
		W.Open()
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(true, W.sortPending)
		A.Advance(W.SORT_TIMEOUT + 0.1)
		assert.equal(false, W.sortPending)
		assert.equal("open", W.stats.lastLayoutReason)
		A.Advance(120)
		A.Clear(0, 1)
		bagUpdate()
		A.Advance(1)
		assert.equal("open", W.stats.lastLayoutReason, "no regroup")
		assert.equal(1, #B.placeholders)
	end)

	it("sorting in combat shows feedback and does nothing, now or after combat (W11)", function()
		W.Open()
		A.combat = true
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(0, A.sorts)
		assert.equal(SB.L.SORT_AFTER_COMBAT, W.frame.title.text)
		assert.equal(false, W.sortPending)
		assert.equal(0, SB.OutOfCombatPending(), "nothing queued")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(5)
		assert.equal(0, A.sorts, "no automatic sort")
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(1, A.sorts, "pressing Sort again sorts")
	end)

	it("a failing sort shows the failure, records the error, and never says it started", function()
		W.Open()
		A.SortBags = function() return false, "boom" end
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(SB.L.SORT_UNAVAILABLE, W.frame.title.text)
		assert.equal(false, W.sortPending)
		assert.equal(1, SB.ErrorTrap.count)
		assert.equal("boom", SB.ErrorTrap.Recent()[1].message)
		assert.equal(false, SB.SafeMode.IsOn("bags"), "recorded only")
	end)

	it("Reflow waits while the mouse is over the items, then regroups", function()
		W.Open()
		A.Clear(0, 1)
		bagUpdate()
		W.scroll.mouseOver = true
		W.reflowButton.scripts.OnClick(W.reflowButton)
		assert.equal(SB.L.REFLOW_WAITING, W.frame.title.text)
		assert.equal(1, #B.placeholders)
		A.Advance(0.3)
		assert.equal(1, #B.placeholders)
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.equal(0, #B.placeholders)
		assert.equal("reflow", W.stats.lastLayoutReason)
	end)

	it("the grid view only repaints: no placeholders, nothing moves", function()
		SB.Config.Set("bags.view", "grid")
		W.Open()
		local counts = placedCounts()
		A.Clear(0, 1)
		bagUpdate()
		assert.equal(0, #B.placeholders)
		assert.same(counts, placedCounts())
	end)
end)

describe("BagsWindow focus modes (spec 6)", function()
	local SB, A, W, B, F
	before_each(function()
		local files = { unpack(FILES) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- potion, flask, BoE ring, soulbound helm, keystone, junk
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W, F = SB.BagsWindow, SB.Focus
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
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

	local function bagUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag or 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local M_PLUS = { "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "+ BoE gear (1)",
		"+ Junk (1)", "+ Free (10)" }

	local function click(id, mouseButton)
		header(id).scripts.OnClick(header(id), mouseButton or "LeftButton")
	end


	-- Mutation: return own (the saved set) from W.EffectiveCollapsed.
	it("a key starting while the bag is open collapses all but the M+ sections; leaving restores the user's own", function()
		W.Open()
		W.ToggleSection("c_junk") -- the user's own choice, saved
		F.SetSignal("challengeMode", true)
		assert.same(M_PLUS, headers())
		assert.falsy(B.Get(0, 3).shown, "BoE ring hidden")
		assert.truthy(B.Get(0, 5).shown, "keystone shown")
		assert.same({ c_junk = true }, SB.Config.UI().collapsed.bags, "a mode never writes the saved set")
		F.SetSignal("challengeMode", false)
		assert.same({ "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "- BoE gear (1)",
			"+ Junk (1)", "- Free (10)" }, headers())
	end)

	-- Mutation: Restack calls render() instead of renderMoved(oldPos, pos).
	it("a mode switch touches only the buttons that move or hide (Restack is incremental)", function()
		W.Open()
		local shows = {}
		for slot = 1, 16 do
			local b = B.Get(0, slot)
			local show = b.Show
			b.Show = function(self)
				shows[slot] = (shows[slot] or 0) + 1
				return show(self)
			end
		end
		F.SetSignal("challengeMode", true)
		assert.falsy(B.Get(0, 3).shown, "the switch happened: the BoE ring hides") -- preflight d1
		assert.is_nil(shows[1], "the potion keeps its cell: no frame call")
		assert.is_nil(shows[5], "the keystone keeps its cell: no frame call")
	end)

	-- Mutation: delete the Layout.Moves hover check in W.Restack (anyBusy).
	it("W10 and P5: no button moves relative to its own header, and none moves under the mouse", function()
		W.Open()
		local junk = B.Get(0, 6)
		local offset = junk.y - header("c_junk").points[1][5]
		local gear = B.Get(0, 4)
		gear.mouseOver = true -- Keystone and Consumables collapse above it and Gear itself hides: it would move
		F.SetSignal("merchantOpen", true) -- opens BoE gear, Trade Goods, Junk: Gear and Consumables collapse
		local ring = B.Get(0, 3)
		assert.equal("SwagBag — AH/Vendor/Bank", W.frame.title.text, "the title changes at once")
		assert.truthy(gear.shown, "held: the hovered helm is still shown")
		A.Advance(0.3)
		assert.truthy(gear.shown, "still held while the mouse stays")
		gear.mouseOver = false
		A.Advance(0.3)
		assert.falsy(gear.shown)
		assert.truthy(ring.shown)
		assert.equal(offset, junk.y - header("c_junk").points[1][5], "Junk's button kept its offset to its header")
	end)

	-- Ruling W4-1 (preflight F-1): loot while a switch is held under the mouse lays out with the view
	-- that is drawn, so nothing jumps under the mouse. Mutation: ApplyChanges uses W.EffectiveCollapsed().
	it("loot during a held switch moves nothing under the mouse; the switch applies once the mouse leaves", function()
		W.Open()
		local ring = B.Get(0, 3)
		local x, y = ring.x, ring.y
		ring.mouseOver = true -- the ring would hide under M+
		F.SetSignal("challengeMode", true)
		assert.truthy(ring.shown, "held")
		A.Put(0, 10, Fixtures.HERB, 20) -- an arrival: ApplyChanges runs
		bagUpdate()
		assert.equal("- New (1)", header("new").text.text, "the arrival was drawn")
		assert.truthy(ring.shown, "the hovered ring is still shown")
		assert.same({ x, y }, { ring.x, ring.y }, "the hovered ring has not moved")
		assert.equal("- BoE gear (1)", header("c_boe").text.text, "the old sections are still drawn")
		assert.equal("- Junk (1)", header("c_junk").text.text)
		ring.mouseOver = false
		A.Advance(0.3)
		assert.falsy(ring.shown, "the switch applied")
		assert.equal("+ BoE gear (1)", header("c_boe").text.text)
		assert.equal("+ Junk (1)", header("c_junk").text.text)
	end)

	-- Ruling W4-1, the same hole for the user's own header click: a collapse of New held under the
	-- mouse must not send loot to Free. Mutation: Layout.Apply in ApplyChanges gets
	-- W.EffectiveCollapsed() instead of W.view.
	it("loot during a held collapse of New still lands in New (the drawn view decides)", function()
		W.Open()
		local keystone = B.Get(0, 5)
		keystone.mouseOver = true -- collapsing New would move every section below it
		W.ToggleSection("new")
		assert.equal("- New (0)", header("new").text.text, "held")
		A.Put(0, 10, Fixtures.HERB, 20)
		bagUpdate()
		assert.equal("- New (1)", header("new").text.text, "the herb is in New, as drawn")
		assert.same({ 4, -24 }, { B.Get(0, 10).x, B.Get(0, 10).y }, "first cell of New")
		keystone.mouseOver = false
		A.Advance(0.3)
		assert.equal("+ New (1)", header("new").text.text, "the collapse applied once the mouse left")
	end)

	-- Ruling W4-13: a switch the world starts (not the user's click) also waits while the mouse is
	-- anywhere over the items (a header, a placeholder, a gap), so nothing slides under a right-click
	-- at a merchant. Mutation: drop the scroll:IsMouseOver() area check from W.Restack.
	it("a world-started switch waits while the mouse is anywhere over the items, then applies", function()
		W.Open()
		W.scroll.mouseOver = true -- over a header or a gap; no button is hovered
		F.SetSignal("challengeMode", true)
		assert.equal("SwagBag — M+", W.frame.title.text, "the title changes at once")
		assert.truthy(B.Get(0, 3).shown, "held: the ring is still shown")
		assert.equal("- BoE gear (1)", header("c_boe").text.text)
		A.Advance(0.3)
		assert.truthy(B.Get(0, 3).shown, "still held while the mouse stays over the items")
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.falsy(B.Get(0, 3).shown, "applied once the mouse left")
		assert.equal("+ BoE gear (1)", header("c_boe").text.text)
	end)

	it("a header click still re-stacks with the mouse over the items (only a button that would move holds it)",
		function()
		W.Open()
		W.scroll.mouseOver = true -- the click is on a header, inside the items area
		W.ToggleSection("c_junk")
		assert.falsy(B.Get(0, 6).shown, "applied at once")
	end)

	-- Mutation: in W.Restack, `area = area == true or W.areaHeld` -> `area = area == true`.
	it("a header click while a world-started switch waits does not draw it under the mouse", function()
		W.Open()
		W.scroll.mouseOver = true
		F.SetSignal("challengeMode", true)
		W.ToggleSection("c_consumables")
		assert.truthy(B.Get(0, 3).shown, "the switch still waits")
		assert.equal("- BoE gear (1)", header("c_boe").text.text)
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.falsy(B.Get(0, 3).shown, "applied once the mouse left")
	end)

	it("pause wins during a held switch: the retry draws the user's own view, titled Paused", function()
		W.Open()
		W.ToggleSection("c_junk") -- the user's own state
		local ring = B.Get(0, 3)
		ring.mouseOver = true
		F.SetSignal("challengeMode", true)
		assert.truthy(ring.shown, "held")
		F.Pause()
		ring.mouseOver = false
		A.Advance(0.3)
		assert.same({ "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "- BoE gear (1)",
			"+ Junk (1)", "- Free (10)" }, headers())
		assert.truthy(ring.shown)
		assert.equal("SwagBag — Paused", W.frame.title.text)
	end)

	it("an item on the cursor holds the switch; it applies once the item is put down", function()
		W.Open()
		A.cursor = { itemID = 1 }
		F.SetSignal("challengeMode", true)
		assert.truthy(B.Get(0, 6).shown)
		A.cursor = nil
		A.Advance(0.3)
		assert.falsy(B.Get(0, 6).shown)
	end)

	it("a switch in combat applies at once (moving buttons is legal in combat)", function()
		W.Open()
		A.combat = true
		F.SetSignal("challengeMode", true)
		assert.same(M_PLUS, headers())
	end)

	it("a switch while the bag is closed is applied on the next open", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		assert.same(M_PLUS, headers())
	end)

	it("in the grid view a switch changes only the title", function()
		SB.Config.Set("bags.view", "grid")
		W.Open()
		F.SetSignal("challengeMode", true)
		assert.equal("SwagBag — M+", W.frame.title.text)
		assert.truthy(B.Get(0, 6).shown)
	end)

	-- Mutation: make Focus.Pause leave the overrides and the paused flag alone (no-op).
	it("pausing while a switch waits under the mouse: the retry draws the paused state, never the mode", function()
		W.Open()
		local ring = B.Get(0, 3)
		ring.mouseOver = true
		F.SetSignal("challengeMode", true) -- would hide the ring: held
		assert.truthy(ring.shown)
		W.modeButton.scripts.OnClick(W.modeButton)
		ring.mouseOver = false
		A.Advance(0.3)
		assert.truthy(ring.shown, "paused: the user's own (all open) state")
		assert.equal("SwagBag — Paused", W.frame.title.text)
	end)

	-- Mutation: in W.ToggleSection, always toggle the saved set.
	it("AC8.3: a click on a collapsed header peeks it until the bag closes; the saved set is untouched", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		click("c_junk")
		assert.equal("- Junk (1)  (peek - right-click keeps it open)", header("c_junk").text.text)
		assert.truthy(B.Get(0, 6).shown)
		assert.same({}, SB.Config.UI().collapsed.bags)
		W.Close()
		W.Open()
		assert.equal("+ Junk (1)", header("c_junk").text.text)
	end)

	-- Mutation: in SectionHeaders' OnClick, drop the mouseButton argument.
	it("a right-click keeps a section open until the mode changes; it survives closing the bag", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		click("c_junk", "RightButton")
		assert.equal("- Junk (1)  (kept open)", header("c_junk").text.text)
		assert.same({}, SB.Config.UI().collapsed.bags, "a pin never writes the saved set")
		W.Close()
		W.Open()
		assert.equal("- Junk (1)  (kept open)", header("c_junk").text.text)
		F.SetSignal("merchantOpen", true)
		assert.equal("- Junk (1)", header("c_junk").text.text, "the mode set changed: the pin is gone")
	end)

	it("a click on an open section in a mode closes it for this opening only", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		click("c_gear")
		assert.equal("+ Gear (1)", header("c_gear").text.text)
		assert.same({}, SB.Config.UI().collapsed.bags, "a close never writes the saved set")
		W.Close()
		W.Open()
		assert.equal("- Gear (1)", header("c_gear").text.text)
	end)

	it("without a mode a right-click collapses like a left-click", function()
		W.Open()
		click("c_gear", "RightButton")
		assert.equal("+ Gear (1)", header("c_gear").text.text)
		assert.same({ c_gear = true }, SB.Config.UI().collapsed.bags)
	end)

	it("an item on the cursor dropped on a header in a mode is still a drop (AC4.3), not a peek", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		click("c_junk")
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		assert.truthy(SB.Categories.Get("c_junk").itemList.include[Fixtures.FLASK])
	end)

	it("the Pause button: one click pauses (chat, title, button), the next resumes", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		assert.equal("Pause", W.modeButton.text)
		W.modeButton.scripts.OnClick(W.modeButton)
		assert.equal("Resume", W.modeButton.text)
		assert.equal("SwagBag — Paused", W.frame.title.text)
		assert.equal("- Junk (1)", header("c_junk").text.text)
		assert.equal(SB.L.MODE_PAUSED, A.Lines()[#A.Lines()])
		W.modeButton.scripts.OnClick(W.modeButton)
		assert.equal("Pause", W.modeButton.text)
		assert.equal("SwagBag — M+", W.frame.title.text)
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		assert.equal(SB.L.MODE_RESUMED, A.Lines()[#A.Lines()])
	end)

	-- Ruling (Task 3 review, g-v): every header click in a mode answers in the title (P2), also
	-- when its re-stack waits. Mutation: delete the W.Flash call in W.ClickSection.
	it("every header click in a mode answers with a title flash (peek, close, pin, unpin)", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		click("c_junk")
		assert.equal(SB.L.HEADER_FLASH_PEEK:format("Junk"), W.frame.title.text)
		click("c_gear")
		assert.equal(SB.L.HEADER_FLASH_CLOSED:format("Gear"), W.frame.title.text)
		click("c_boe", "RightButton")
		assert.equal(SB.L.HEADER_FLASH_KEPT:format("BoE gear"), W.frame.title.text)
		click("c_boe", "RightButton")
		assert.equal(SB.L.HEADER_FLASH_UNPINNED:format("BoE gear"), W.frame.title.text)
		A.Advance(1.5)
		assert.equal("SwagBag — M+", W.frame.title.text)
	end)

	it("with \"Keep open until the mode changes\" a left-click on a collapsed header pins at once", function()
		SB.Config.Set("focus.peek", "keep")
		F.SetSignal("challengeMode", true)
		W.Open()
		click("c_junk")
		assert.equal("- Junk (1)  (kept open)", header("c_junk").text.text)
		assert.equal(SB.L.HEADER_FLASH_KEPT:format("Junk"), W.frame.title.text)
	end)

	-- Ruling (Task 3 review, g-iii): "collapsed now" is what is drawn. While a world-started switch
	-- waits, the drawn view is the old one: a click on a header drawn open closes it (it does not
	-- peek it because the waiting mode would collapse it). Mutation: compute collapsedNow from
	-- W.EffectiveCollapsed()[id] instead of W.view[id].
	it("a click decides peek or close from the drawn header, not from a switch still waiting", function()
		W.Open()
		W.scroll.mouseOver = true
		F.SetSignal("challengeMode", true) -- Junk would collapse; held, still drawn open
		assert.equal("- Junk (1)", header("c_junk").text.text)
		click("c_junk")
		assert.equal("closed", F.OverrideOf("c_junk"), "drawn open: the click closes it")
		assert.equal(SB.L.HEADER_FLASH_CLOSED:format("Junk"), W.frame.title.text)
	end)

	-- Ruling W4-1 for a peek: the user's peek waits while a button that would move is under the
	-- mouse; loot in that time is laid out with the view that is drawn, so nothing moves under the
	-- mouse. Mutation: ApplyChanges uses W.EffectiveCollapsed() for Layout.Position.
	it("loot during a held peek moves nothing under the mouse; the peek applies once the mouse leaves", function()
		F.SetSignal("merchantOpen", true) -- Consumables collapse; BoE gear and Junk open below them
		W.Open()
		assert.equal("+ Consumables (2)", header("c_consumables").text.text)
		local ring = B.Get(0, 3)
		local x, y = ring.x, ring.y
		ring.mouseOver = true -- below Consumables: a peek would move it down
		click("c_consumables")
		assert.equal("+ Consumables (2)", header("c_consumables").text.text, "held")
		assert.equal(SB.L.HEADER_FLASH_PEEK:format("Consumables"), W.frame.title.text, "the click answered")
		A.Put(0, 10, Fixtures.HERB, 20) -- an arrival: ApplyChanges runs
		bagUpdate()
		assert.equal("- New (1)", header("new").text.text, "the arrival was drawn")
		assert.same({ x, y }, { ring.x, ring.y }, "the hovered ring has not moved")
		assert.equal("+ Consumables (2)", header("c_consumables").text.text, "the peek still waits")
		assert.same({}, SB.Config.UI().collapsed.bags, "the saved set is untouched")
		ring.mouseOver = false
		A.Advance(0.3)
		assert.equal("- Consumables (2)  (peek - right-click keeps it open)", header("c_consumables").text.text)
		assert.truthy(B.Get(0, 1).shown)
	end)

	-- Ruling (Task 3 review, g-vii): a peek or pin re-stack holds like a world-started switch (mouse
	-- anywhere over the items) only when the clicked header itself would move, here because an
	-- earlier peek above it still waits. Mutation: in W.ClickSection, call W.Restack() instead of
	-- W.Restack(id).
	it("a peek whose own header would move waits while the mouse is over the items", function()
		F.SetSignal("merchantOpen", true)
		W.Open()
		local ring = B.Get(0, 3)
		ring.mouseOver = true
		click("c_consumables") -- held: the ring would move
		ring.mouseOver = false
		W.scroll.mouseOver = true -- now on the Gear header, below Consumables
		local gearY = header("c_gear").points[1][5]
		click("c_gear") -- its header would move down with the waiting peek above it
		assert.equal(gearY, header("c_gear").points[1][5], "the clicked header did not move under the mouse")
		assert.equal("+ Consumables (2)", header("c_consumables").text.text, "still waiting")
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.equal("- Consumables (2)  (peek - right-click keeps it open)", header("c_consumables").text.text)
		assert.equal("- Gear (1)  (peek - right-click keeps it open)", header("c_gear").text.text)
	end)

	it("a peek whose own header does not move applies at once with the mouse over the items", function()
		F.SetSignal("merchantOpen", true)
		W.Open()
		W.scroll.mouseOver = true -- the click is on a header, inside the items area
		click("c_consumables")
		assert.equal("- Consumables (2)  (peek - right-click keeps it open)", header("c_consumables").text.text)
	end)

	-- Ruling W4-16. Mutation: in W.ToggleSection, `set[id] = (not drawn) or nil` -> `not set[id] or nil`.
	it("mode ends while held; a click on a header drawn '+' saves it open", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		W.scroll.mouseOver = true
		F.SetSignal("challengeMode", false) -- the user's own (all open) state waits for the mouse
		assert.equal("+ Junk (1)", header("c_junk").text.text, "held")
		click("c_junk")
		assert.same({}, SB.Config.UI().collapsed.bags, "drawn '+': the click opens it")
		assert.equal(SB.L.HEADER_FLASH_OPEN:format("Junk"), W.frame.title.text, "a held click answers")
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.equal("- Junk (1)", header("c_junk").text.text)
	end)

	it("pause while held; a click on a header drawn '-' saves it collapsed and answers", function()
		W.Open()
		local ring = B.Get(0, 3)
		ring.mouseOver = true
		F.SetSignal("challengeMode", true) -- held
		F.Pause() -- still held: the drawn view is the user's own, all open
		click("c_gear")
		assert.same({ c_gear = true }, SB.Config.UI().collapsed.bags)
		assert.equal(SB.L.HEADER_FLASH_COLLAPSED:format("Gear"), W.frame.title.text)
		ring.mouseOver = false
		A.Advance(0.3)
		assert.equal("+ Gear (1)", header("c_gear").text.text)
	end)

	it("a left-click while paused writes the user's own saved set", function()
		F.SetSignal("challengeMode", true)
		F.Pause()
		W.Open()
		click("c_junk")
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		assert.same({ c_junk = true }, SB.Config.UI().collapsed.bags)
		assert.is_nil(F.OverrideOf("c_junk"))
	end)

	it("/swagbag mode with an unknown word answers with the status and the usage", function()
		F.SetSignal("challengeMode", true)
		SB.Slash.Dispatch("mode fly")
		assert.same({ "Focus mode now: M+. Type /swagbag mode pause, resume or list.", SB.L.MODE_USAGE }, A.Lines())
	end)

	it("AC8.5: the title names the mode, before the item level", function()
		A.avgIlvl = 279.44
		F.SetSignal("fishing", true)
		W.Open()
		assert.equal("SwagBag — Fishing — ilvl 279.4", W.frame.title.text)
	end)

	-- Mutation: ignore mouseButton in the mode button's click (always pause).
	it("AC8.5: a right-click on the Pause button opens the settings at the active mode's sections", function()
		local edited = {}
		SB.SettingsFocus = { Edit = function(id) edited[#edited + 1] = id end }
		F.SetSignal("fishing", true)
		W.Open()
		W.modeButton.scripts.OnClick(W.modeButton, "RightButton")
		assert.same({ "fishing" }, edited)
		assert.falsy(F.IsPaused(), "a right-click does not pause")
		W.modeButton.scripts.OnClick(W.modeButton, "LeftButton")
		assert.truthy(F.IsPaused(), "a left-click still pauses")
	end)

	-- W4-5. Mutation: run the right-click without ErrorTrap.Run "none" (call Edit directly).
	it("an error while opening the settings flashes L.SETTINGS_FAILED and never takes the bags to Safe Mode", function()
		SB.SettingsFocus = { Edit = function() error("page builder broke") end }
		W.Open()
		W.modeButton.scripts.OnClick(W.modeButton, "RightButton")
		assert.equal(SB.L.SETTINGS_FAILED, W.frame.title.text)
		assert.equal(1, SB.ErrorTrap.count, "recorded for the report")
		assert.equal(false, SB.SafeMode.IsOn("bags"))
	end)

	-- Mutation: delete the `not ok` flash when SettingsFocus is missing.
	it("a right-click with no settings page flashes L.SETTINGS_FAILED and does not pause", function()
		SB.SettingsFocus = nil
		W.Open()
		W.modeButton.scripts.OnClick(W.modeButton, "RightButton")
		assert.equal(SB.L.SETTINGS_FAILED, W.frame.title.text)
		assert.falsy(F.IsPaused())
	end)

	-- Mutation: delete the AddLine for the right-click.
	it("the Pause tooltip names both clicks", function()
		local lines = {}
		GameTooltip = { SetOwner = function() end, SetText = function(_, t) lines[#lines + 1] = t end,
			AddLine = function(_, t) lines[#lines + 1] = t end, Show = function() end, Hide = function() end }
		W.Open()
		W.modeButton.scripts.OnEnter(W.modeButton)
		GameTooltip = nil
		assert.same({ SB.L.MODE_TIP_TITLE, SB.L.MODE_TIP_LEFT, SB.L.MODE_TIP_RIGHT }, lines)
	end)

	it("/swagbag mode answers every form (P2)", function()
		SB.Categories.Load()
		F.SetSignal("challengeMode", true)
		SB.Slash.Dispatch("mode")
		SB.Slash.Dispatch("mode pause")
		SB.Slash.Dispatch("mode pause")
		SB.Slash.Dispatch("mode resume")
		SB.Slash.Dispatch("mode resume")
		local lines = A.Lines()
		assert.same({ "Focus mode now: M+. Type /swagbag mode pause, resume or list.", SB.L.MODE_PAUSED,
			SB.L.MODE_ALREADY_PAUSED, SB.L.MODE_RESUMED, SB.L.MODE_NOT_PAUSED }, lines)
		SB.Slash.Dispatch("mode list")
		lines = A.Lines()
		assert.equal("M+: on, active now - opens Consumables, Keystone & Crests, Gear", lines[6])
		assert.equal("AH/Vendor/Bank: on - opens Junk, Trade Goods, BoE gear", lines[11])
	end)

	it("a flash is not cut short by a mode switch, and ends on the mode title", function()
		A.avgIlvl = 279.44
		W.Open()
		W.Flash("Sorted")
		F.SetSignal("challengeMode", true)
		assert.equal("Sorted", W.frame.title.text, "the flash stays up")
		A.Advance(1.5)
		assert.equal("SwagBag — M+ — ilvl 279.4", W.frame.title.text)
	end)

	-- Spec 6.5 "Apply with the window open <= 5 ms" (preflight e2), over the bags of the 1,290-slot
	-- fixture (212 bag slots; the rest are bank tabs, which a mode never collapses).
	it("a mode switch on the big fixture re-stacks within 5 ms", function()
		local Big = dofile("spec/fixtures/big.lua")
		Big.Install(A)
		W.Open()
		assert.equal(212, #W.cells)
		local worst = 0
		for _, on in ipairs({ true, false, true, false }) do
			local t0 = os.clock()
			F.SetSignal("challengeMode", on)
			worst = math.max(worst, (os.clock() - t0) * 1000)
		end
		assert.truthy(worst <= 5, ("a mode switch took %.2f ms"):format(worst))
	end)
end)

describe("BagsWindow load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(FILES)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UISpecialFrames = {}
		SB.Buttons = fakeButtons()
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/BagsWindow.lua")
		UIParent, UISpecialFrames = nil, nil
		assert.truthy(ok, tostring(err))
	end)
end)
