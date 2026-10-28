-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown GameTooltip
-- The bags window's per-bag view (0.17, spec 4): one section per equipped bag, slots in physical order,
-- end to end over the real engine with fake frames and buttons. It behaves like the grid view (no New,
-- no Free, no stack grouping, no focus, live updates in place) with a collapsible header per bag.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/OverlayData.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/PerBag.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/Sort.lua",
	"SwagBag/Engine/Stacks.lua", "SwagBag/Engine/Focus.lua",
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
			elseif p[1] == "BOTTOMRIGHT" and p[3] == "BOTTOMRIGHT" then -- the default place (RestorePosition)
				self.anchor, self.right, self.edgeY = "BOTTOMRIGHT", p[4], p[5]
			end
		end,
		GetLeft = function(self)
			if self.anchor == "BOTTOMRIGHT" then
				return (UIParent.w or 0) + self.right - self.w
			end
			return self.left
		end,
		GetTop = function(self)
			if self.anchor == "BOTTOMLEFT" or self.anchor == "BOTTOMRIGHT" then
				return self.edgeY + self.h
			end
			return self.edgeY
		end,
		IsTruncated = function(self) return self.truncated == true end,
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
	function B.SetStack(button, s) button.stack = s end
	function B.StackOf(button) return rawget(button, "stack") end
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
describe("BagsWindow per-bag view", function()
	local SB, A, W, B
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		-- The backpack: 16 slots, 13 filled (3 free); two stacks of the potion (stack grouping would make them one).
		A.SetBagSize(0, 16)
		A.Put(0, 1, Fixtures.HEALING_POTION, 5)
		A.Put(0, 2, Fixtures.HEALING_POTION, 7)
		A.Put(0, 3, Fixtures.FLASK, 2)
		A.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true })
		for slot = 5, 13 do
			A.Put(0, slot, Fixtures.JUNK, 1)
		end
		-- Bag 1: a 20-slot Wildercloth Bag holding 2 items (18 free).
		A.SetBagSize(1, 20)
		A.bagNames[1] = "Wildercloth Bag"
		A.Put(1, 1, Fixtures.HERB, 10)
		A.Put(1, 5, Fixtures.ORE, 4)
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
		Loader.LoadFile(SB, "SwagBag/UI/Overlays.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
		SB.Config.Set("bags.view", "bags")
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

	local function bagUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag or 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function layouts()
		local n = { count = 0 }
		SB.On("SB_BAGS_LAYOUT", function() n.count = n.count + 1 end)
		return n
	end

	it("the view button cycles categories, list, grid, bags, categories", function()
		SB.Config.Set("bags.view", "sections")
		W.Open()
		assert.equal(SB.L.VIEW_TO_LIST, W.viewButton.text)
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("list", W.View())
		assert.equal(SB.L.VIEW_TO_GRID, W.viewButton.text)
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("grid", W.View())
		assert.equal(SB.L.VIEW_TO_BAGS, W.viewButton.text)
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("bags", W.View())
		assert.equal("bags", W.drawn)
		assert.equal(SB.L.VIEW_TO_SECTIONS, W.viewButton.text)
		assert.equal(SB.L.VIEW_BAGS, W.frame.title.text)
		assert.equal("Bags", SB.L.VIEW_TO_BAGS)
		assert.equal("SwagBag - bag view", SB.L.VIEW_BAGS)
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("sections", W.View())
		assert.equal(SB.L.VIEW_TO_LIST, W.viewButton.text)
		assert.same({ "sections", "list", "grid", "bags" }, W.VIEWS)
	end)

	it("the bags view draws one header per equipped bag with its name, slots and free slots", function()
		W.Open()
		assert.same({ "- Backpack · 16 slots · 3 free", "- Wildercloth Bag · 20 slots · 18 free" }, headers())
		-- Physical order, empty slots in place: the backpack's first row under its header, bag 1 under its own.
		local h0, h1 = header("bag:0"), header("bag:1")
		assert.equal(-W.PAD, h0.points[1][5])
		assert.same({ W.PAD, -W.PAD - W.SECTION_HEADER }, { B.Get(0, 1).x, B.Get(0, 1).y })
		assert.same({ W.PAD + W.SLOT + W.GAP, -W.PAD - W.SECTION_HEADER }, { B.Get(0, 2).x, B.Get(0, 2).y })
		assert.truthy(B.Get(0, 16).shown, "an empty slot is shown in place")
		local y1 = h1.points[1][5]
		assert.equal(y1 - W.SECTION_HEADER, B.Get(1, 1).y)
		for slot = 1, 20 do
			assert.truthy(B.Get(1, slot).shown, "bag 1 slot " .. slot)
			assert.equal(1, B.Get(1, slot).scale)
		end
	end)

	it("a bag whose name cannot be read is 'Bag N'", function()
		A.bagNames[1] = nil
		W.Open()
		assert.equal("- Bag 1 · 20 slots · 18 free", header("bag:1").text.text)
	end)

	it("no New, no Free, no stack grouping in the bags view", function()
		SB.Config.Set("bags.stacks", "one")
		W.Open()
		assert.is_nil(header("new"))
		assert.is_nil(header("free"))
		assert.is_nil(header(SB.Layout.NEW))
		assert.is_nil(header(SB.Categories.FREE))
		assert.is_nil(W.state, "no Layout state: no New, no Free, no focus")
		assert.truthy(B.Get(0, 1).shown)
		assert.truthy(B.Get(0, 2).shown, "the second stack has its own button")
		assert.is_nil(rawget(B.Get(0, 1), "stack"))
		assert.is_nil(rawget(B.Get(0, 2), "stack"))
		assert.is_nil(W.StackKey({ itemID = Fixtures.HEALING_POTION, bag = 0, slot = 1 }))
		for slot = 14, 16 do
			assert.is_nil(rawget(B.Get(0, slot), "freeCount"), "no free tile")
		end
	end)

	it("a header click folds that bag, saved per character", function()
		W.Open()
		local h1 = header("bag:1")
		h1.scripts.OnClick(h1, "LeftButton")
		assert.equal(true, SB.Config.UI().collapsed.bags["bag:1"])
		assert.equal("+ Wildercloth Bag · 20 slots · 18 free", header("bag:1").text.text)
		for slot = 1, 20 do
			assert.falsy(B.Get(1, slot).shown, "bag 1 slot " .. slot)
		end
		assert.truthy(B.Get(0, 1).shown)
		W.Close()
		W.Open()
		assert.equal("+ Wildercloth Bag · 20 slots · 18 free", header("bag:1").text.text, "kept across a reopen")
		header("bag:1").scripts.OnClick(header("bag:1"), "LeftButton")
		assert.is_nil(SB.Config.UI().collapsed.bags["bag:1"])
		assert.truthy(B.Get(1, 1).shown)
	end)

	it("a header click waits while the mouse is over the items, then folds", function()
		W.Open()
		W.scroll.mouseOver = true
		header("bag:1").scripts.OnClick(header("bag:1"), "LeftButton")
		assert.truthy(B.Get(1, 1).shown, "held: nothing moves under the mouse")
		assert.equal(SB.L.HEADER_FLASH_COLLAPSED:format("Wildercloth Bag"), W.frame.title.text)
		A.Advance(W.RETRY)
		assert.truthy(B.Get(1, 1).shown)
		W.scroll.mouseOver = false
		A.Advance(W.RETRY)
		assert.falsy(B.Get(1, 1).shown)
	end)

	it("a 'bag:' header right-click / drop / Shift+right-click does nothing", function()
		local calls = {}
		SB.SectionActions = {
			Open = function() calls[#calls + 1] = "actions" end,
			Hint = function() calls[#calls + 1] = "hint" end,
		}
		W.Open()
		for _, name in ipairs({ "ClickSection", "PinSection", "DropOnSection", "ToggleSection" }) do
			W[name] = function() calls[#calls + 1] = name end
		end
		local n = layouts()
		local h = header("bag:1")
		h.scripts.OnClick(h, "RightButton")
		A.shift = true
		h.scripts.OnClick(h, "RightButton")
		A.shift = false
		A.cursor = { itemID = Fixtures.JUNK }
		h.scripts.OnReceiveDrag(h)
		h.scripts.OnClick(h, "LeftButton")
		A.cursor = nil
		h.scripts.OnEnter(h)
		A.Advance(1)
		assert.same({}, calls)
		assert.equal(0, n.count, "no layout")
		assert.is_nil(SB.Config.UI().collapsed.bags["bag:1"])
		assert.equal(0, #SB.ErrorTrap.Recent())
	end)

	it("a bag update in the bags view repaints in place (no full layout)", function()
		W.Open()
		local n = layouts()
		local placed = B.Get(0, 14).placed
		local updated = 0
		SB.On("SB_BAGS_UPDATED", function() updated = updated + 1 end)
		A.Put(0, 14, Fixtures.FLASK, 1)
		bagUpdate(0)
		assert.equal(0, n.count, "no full layout")
		assert.equal(Fixtures.FLASK, B.Get(0, 14).itemID, "painted in place")
		assert.equal(placed, B.Get(0, 14).placed, "nothing moved")
		assert.equal("- Backpack · 16 slots · 2 free", header("bag:0").text.text, "the free count follows")
		assert.truthy(updated > 0)
		A.Clear(0, 1)
		bagUpdate(0)
		assert.equal(0, n.count)
		assert.is_nil(rawget(B.Get(0, 1), "itemID"), "an emptied slot stays where it is, empty")
		assert.truthy(B.Get(0, 1).shown)
		assert.equal(0, #B.placeholders, "no placeholder")
		assert.equal("- Backpack · 16 slots · 3 free", header("bag:0").text.text)
	end)

	it("a bag that changes size lays the view out again, as the grid does", function()
		W.Open()
		local n = layouts()
		A.SetBagSize(1, 24)
		bagUpdate(1)
		A.Advance(W.RETRY)
		assert.truthy(n.count >= 1)
		assert.equal("- Wildercloth Bag · 24 slots · 22 free", header("bag:1").text.text)
	end)

	it("switching to the bags view under the mouse waits until the mouse leaves", function()
		SB.Config.Set("bags.view", "sections")
		W.Open()
		B.Get(0, 1).mouseOver = true
		W.scroll.mouseOver = true
		W.SetView("bags")
		assert.equal("sections", W.drawn, "still drawn as before")
		A.Advance(W.RETRY)
		assert.equal("sections", W.drawn)
		B.Get(0, 1).mouseOver = false
		W.scroll.mouseOver = false
		A.Advance(W.RETRY)
		assert.equal("bags", W.drawn)
		assert.equal("- Backpack · 16 slots · 3 free", headers()[1])
	end)

	it("/swagbag view bags sets the view; the Settings view choice offers it", function()
		W.Open()
		SB.Config.Set("bags.view", "grid")
		SB.Slash.Dispatch("view bags")
		assert.equal("bags", W.View())
		assert.equal(SB.L.VIEW_BAGS, A.Lines()[1])
		SB.Slash.Dispatch("view")
		assert.equal(SB.L.VIEW_USAGE:format("bags"), A.Lines()[2])
		assert.truthy(SB.L.VIEW_USAGE:find("/swagbag view bags", 1, true))
		assert.truthy(SB.L.HELP_VIEW:find("bags", 1, true))
		SB.Config.Set("bags.view", "sections")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		local SW = SB.SettingsWindow
		SW.Show("bags")
		local found
		for i = 1, SW.used.buttons do
			local b = SW.buttons[i]
			if b.text == SB.L.VIEW_TO_BAGS and b.shown then
				found = b
			end
		end
		assert.truthy(found, "the Settings view row offers Bags")
		found.scripts.OnClick(found)
		assert.equal(SB.L.VIEW_BAGS, SW.lastStatus)
		assert.equal("bags", W.View())
	end)

end)
