-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown
-- The bags window's category view, end to end over the real engine (Inventory, Items,
-- Keywords, Categories, Categorizer, Layout, SectionHeaders) with fake frames and buttons.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
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
		SetSize = function(self, w, h) self.w, self.h = w, h end,
		GetHeight = function(self) return self.h end,
		SetScript = function(self, n, fn) self.scripts[n] = fn end,
		SetVerticalScroll = function(self, v) self.vscroll = v end,
		GetVerticalScroll = function(self) return self.vscroll end,
		ClearAllPoints = function(self) self.points = {} end,
		SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
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
	function B.Paint(button, info) button.itemID = info and info.itemID or nil end
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

	-- Change the mock bags, then deliver the events the client would send.
	local function bagUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag or 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function placedCounts()
		local out = {}
		for slot = 1, 16 do
			out[slot] = B.Get(0, slot).placed
		end
		return out
	end

	it("using up an item leaves a placeholder with its icon; its button goes to Free; nothing else moves", function()
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

	it("a stack count change only repaints", function()
		W.Open()
		local counts = placedCounts()
		A.Put(0, 1, Fixtures.HEALING_POTION, 2)
		bagUpdate()
		assert.same(counts, placedCounts())
		assert.equal(0, #B.placeholders)
	end)

	it("a button under the mouse does not move; it moves 300 ms after the mouse leaves", function()
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
