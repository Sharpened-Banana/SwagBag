-- luacheck: globals CreateFrame UIParent UISpecialFrames IsControlKeyDown GameTooltip
-- 0.17 (user request: "a sidebar that goes over all of the categories (and amount in each). Once clicked it
-- brings up that category and that's it"): a slim list beside the bags and bank windows. A click unfolds the
-- section if it is folded and scrolls its header to the top; nothing else changes, and nothing moves under
-- the mouse. Over the real engine with fake frames and buttons.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/OverlayData.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/PerBag.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
	"SwagBag/Engine/Query/Query.lua", "SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua",
	"SwagBag/Engine/CategoryDefaults.lua", "SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua",
	"SwagBag/Engine/Layout.lua", "SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua",
	"SwagBag/Engine/Sort.lua", "SwagBag/Engine/Focus.lua",
}

-- Fake frame (as the bags window specs use): shown state, scripts (Hide fires OnHide like the client),
-- points, text, size, mouse-over; every other method is a recorded no-op.
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
		SetShown = function(self, v)
			if v then
				self:Show()
			else
				self:Hide()
			end
		end,
		IsMouseOver = function(self) return self.mouseOver == true end,
		SetScale = function(self, s) self.scale = s end,
		GetScale = function(self) return self.scale end,
		SetAlpha = function(self, a) self.alpha = a end,
		SetSize = function(self, w, h) self.w, self.h = w, h end,
		SetWidth = function(self, w) self.w = w end,
		SetHeight = function(self, h) self.h = h end,
		GetWidth = function(self) return self.w end,
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

-- Fake button pool: records placement and paint; placeholders as plain tables.
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
	function B.AcquirePlaceholder(_, icon, _, x, y)
		local p = { icon = icon, x = x, y = y }
		B.placeholders[#B.placeholders + 1] = p
		return p
	end
	function B.ReleasePlaceholders()
		B.placeholders = {}
	end
	return B
end

-- The texts of the sidebar's shown lines, top to bottom.
local function texts(sb)
	local out = {}
	for _, row in ipairs(sb.rows) do
		if row.shown then
			out[#out + 1] = row.text.text
		end
	end
	return out
end

-- The shown line that reads text.
local function line(sb, text)
	for _, row in ipairs(sb.rows) do
		if row.shown and row.text.text == text then
			return row
		end
	end
	error("no sidebar line " .. text)
end

local function click(row)
	(row.scripts.OnClick or Fake.Fire)(row, "LeftButton")
end

describe("CategorySidebar (pure)", function()
	local S
	before_each(function()
		local SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		Loader.LoadFile(SB, "SwagBag/UI/CategorySidebar.lua")
		S = SB.CategorySidebar
	end)

	-- Mutation: in S.Label, drop the "+ " for a folded section.
	it("a line is the section's name and count, like its header; a folded one starts with +", function()
		assert.equal("Consumables (12)", S.Label("Consumables", 12, false))
		assert.equal("+ Consumables (12)", S.Label("Consumables", 12, true))
	end)

	-- Mutation: in S.Side, `left < width` -> `left < 0`.
	it("left of the window; right when the left has no room or something of Blizzard's is there", function()
		assert.equal("LEFT", S.Side(400, 150, false))
		assert.equal("RIGHT", S.Side(100, 150, false), "too near the screen's left edge")
		assert.equal("RIGHT", S.Side(400, 150, true), "Blizzard's bank on the left")
		assert.equal("LEFT", S.Side(nil, 150, false), "no position known yet")
	end)
end)

describe("CategorySidebar on the bags window", function()
	local SB, A, W, sb, B
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- backpack 16 slots: potion, flask, BoE ring, soulbound helm, keystone, junk
		SB.Config.Set("bags.newAlways", true) -- New drawn while empty, as the bags window specs are written
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h, UIParent.w = 2000, 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/CategorySidebar.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W = SB.BagsWindow
		sb = W.sidebar
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
	end)

	after_each(function()
		CreateFrame, UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil, nil
	end)

	local function headerY(id)
		for _, h in ipairs(W.pos.headers) do
			if h.id == id then
				return h.y
			end
		end
	end

	local ALL = { "New (0)", "Keystone & Crests (1)", "Consumables (2)", "Gear (1)", "BoE gear (1)", "Junk (1)", "Free (10)" }

	-- Mutation: in the bags window's renderExtras, drop the sidebar update.
	it("lists every section in the order drawn, with its header's count", function()
		W.Open()
		assert.truthy(sb.frame.shown)
		assert.same(ALL, texts(sb))
	end)

	-- Counts and folds change in place: the same line objects, no line moves (P5).
	it("a section folded with its header reads + in the sidebar, on the same line", function()
		W.Open()
		local gear = line(sb, "Gear (1)")
		W.ToggleSection("c_gear")
		assert.equal("+ Gear (1)", gear.text.text)
		assert.equal(4, #texts(sb) - 3, "nothing added or removed")
	end)

	-- Week 6 front style: a mode moves its sections up; the sidebar follows what is drawn.
	it("follows a focus mode's order", function()
		SB.Config.Set("focus.auto", true) -- modes switch by themselves only when asked (0.14.3)
		W.Open()
		SB.Focus.SetSignal("merchantOpen", true)
		assert.same({ "New (0)", "Junk (1)" }, { texts(sb)[1], texts(sb)[2] }, "Junk right after New")
	end)

	-- The user: Categories and List views only.
	it("shows in the categories and list views; hides in the grid and bags views", function()
		W.Open()
		W.SetView("list", true)
		assert.truthy(sb.frame.shown, "list")
		assert.same(ALL, texts(sb))
		W.SetView("grid", true)
		assert.falsy(sb.frame.shown, "grid")
		W.SetView("bags", true)
		assert.falsy(sb.frame.shown, "per-bag")
		W.SetView("sections", true)
		assert.truthy(sb.frame.shown, "categories again")
		assert.same(ALL, texts(sb))
	end)

	-- Mutation: in the bags window's sidebar click, drop the unfold (only scroll).
	it("a click on a folded section unfolds it and scrolls its header to the top", function()
		W.Collapsed().c_junk = true
		W.Open()
		click(line(sb, "+ Junk (1)"))
		assert.is_nil(W.Collapsed().c_junk, "unfolded, as a header click does (saved)")
		assert.truthy(B.Get(0, 6).shown, "the junk shows")
		assert.equal("Junk (1)", texts(sb)[6])
		local y = headerY("c_junk")
		assert.truthy(-y > 0)
		assert.equal(-y, W.scroll.vscroll, "Junk's header at the top")
	end)

	-- "That's it": an open section is never folded by the sidebar.
	it("a click on an open section only scrolls to it", function()
		W.Open()
		click(line(sb, "Consumables (2)"))
		assert.is_nil(W.Collapsed().c_consumables)
		assert.equal(-headerY("c_consumables"), W.scroll.vscroll)
	end)

	-- AC8.3: in a mode, a click on a section the mode folded is a peek (the saved set is never written).
	it("in a focus mode, a click on a section the mode folded peeks it", function()
		SB.Config.Set("focus.auto", true)
		SB.Config.Set("focus.style", "collapse")
		W.Open()
		SB.Focus.SetSignal("challengeMode", true)
		click(line(sb, "+ Junk (1)"))
		assert.equal("peek", SB.Focus.OverrideOf("c_junk"))
		assert.is_nil(W.Collapsed().c_junk, "the saved set is untouched")
		assert.truthy(B.Get(0, 6).shown)
	end)

	-- Spec 4.2 rule 5: nothing moves while an item is on the cursor.
	it("with an item on the cursor a click does nothing", function()
		W.Collapsed().c_junk = true
		W.Open()
		A.cursor = { itemID = Fixtures.HERB }
		click(line(sb, "+ Junk (1)"))
		A.Advance(1)
		assert.equal(true, W.Collapsed().c_junk)
		assert.equal(0, W.scroll.vscroll)
	end)

	-- P5: a line never jumps under the mouse. Mutation: in sb.Update, drop the IsMouseOver hold.
	it("a change to the list of sections waits while the mouse is over the sidebar", function()
		W.Open()
		sb.frame.mouseOver = true
		SB.Config.Set("bags.newAlways", false)
		W.Layout("reflow") -- New (empty) is no longer drawn
		assert.same(ALL, texts(sb), "held")
		A.Advance(W.RETRY)
		assert.same(ALL, texts(sb), "still held")
		sb.frame.mouseOver = false
		A.Advance(W.RETRY)
		assert.equal("Keystone & Crests (1)", texts(sb)[1], "drawn once the mouse left")
	end)

	-- Mutation: in the shrink handle's click, drop the saved flag.
	it("the handle shrinks it to a strip, remembered per character; a click on the strip brings it back", function()
		W.Open()
		click(sb.handle)
		assert.equal(true, SB.Config.UI().sidebarShrunk.bags)
		assert.same({}, texts(sb))
		assert.equal(SB.CategorySidebar.SHRUNK, sb.frame.w)
		W.Close()
		W.Open()
		assert.same({}, texts(sb), "still a strip after reopening")
		click(sb.handle)
		assert.is_nil(SB.Config.UI().sidebarShrunk.bags)
		assert.same(ALL, texts(sb))
		assert.equal(SB.CategorySidebar.WIDTH, sb.frame.w)
	end)

	-- The one setting for both windows (bags.sidebar, on by default), and its chat command.
	it("/swagbag sidebar off hides it, on brings it back; a bare command says the state", function()
		assert.equal(true, SB.Config.Get("bags.sidebar"), "on by default")
		W.Open()
		local ok, said = SB.Slash.Run("sidebar off")
		assert.truthy(ok)
		assert.equal(SB.L.SIDEBAR_OFF, said)
		assert.equal(false, SB.Config.Get("bags.sidebar"))
		assert.falsy(sb.frame.shown)
		W.Close()
		W.Open()
		assert.falsy(sb.frame.shown, "stays off")
		SB.Slash.Run("sidebar on")
		assert.truthy(sb.frame.shown)
		assert.same(ALL, texts(sb))
		local _, state = SB.Slash.Run("sidebar")
		assert.equal(SB.L.SIDEBAR_STATE:format(SB.L.OVERLAY_ON), state)
	end)

	it("sits left of the window; on the right when the window opens too near the screen's left edge", function()
		W.Open()
		assert.same({ "TOPRIGHT", W.frame, "TOPLEFT", 0, 0 }, sb.frame.points[1])
		W.Close()
		SB.Config.UI().positions.bags = { "TOPLEFT", "BOTTOMLEFT", 20, 1500 }
		W.Open()
		assert.same({ "TOPLEFT", W.frame, "TOPRIGHT", 0, 0 }, sb.frame.points[1])
	end)

	-- Ruling W4-25 with the sidebar: the sidebar hangs on the window, so a grow that moves the top edge would
	-- move the line under the mouse. Mutation: in sizeFrame, drop the sidebar from the "under the pointer" test.
	it("an unfold that makes the window taller never moves it while the mouse is on the sidebar", function()
		SB.Config.UI().positions.bags = { "BOTTOMLEFT", "BOTTOMLEFT", 300, 0 }
		W.Collapsed().c_consumables = true
		W.Open()
		local top = W.frame:GetTop()
		sb.frame.mouseOver = true
		click(line(sb, "+ Consumables (2)"))
		assert.equal(top, W.frame:GetTop(), "nothing moved under the mouse")
		sb.frame.mouseOver = false
		A.Advance(W.RETRY)
		assert.truthy(W.frame:GetTop() > top, "grown once the mouse left")
	end)
end)

describe("CategorySidebar on the bank window", function()
	local SB, A, BW, sb, bf
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		Fake.Install()
		Env.PaintGlobals()
		bf = Fake.New("Frame", UIParent)
		bf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
		bf.TabSystem = Fake.New("Frame", bf)
		bf.TabSystem.tabs = { Fake.New("Button", bf.TabSystem), Fake.New("Button", bf.TabSystem) }
		A.frames.BankFrame = bf
		A.activeBankType = "bank" -- right-clicks deposit into the character bank: the warband bank is folded
		Loader.LoadFile(SB, "SwagBag/UI/CategorySidebar.lua")
		BW = Env.LoadBank(SB)
		sb = BW.sidebar
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.Put(6, 1, Fixtures.HEALING_POTION, 5)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(12, 1, Fixtures.ORE, 10)
		A.Put(12, 2, Fixtures.BOE_RING, 1)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openBank()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	local function headerY(gid, sid)
		for _, h in ipairs(BW.view.pos.headers) do
			if h.group == gid and h.id == sid then
				return h.y
			end
		end
	end

	local BOTH = { "Character bank (2)", "Consumables (1)", "Herbs (1)", "Free (6)",
		"+ Warband bank (2)", "BoE gear (1)", "Ore (1)", "Free (6)" }

	-- The user: both banks, all categories, also those of the bank "one bank at a time" folds.
	-- Mutation: in GroupView's positionAll, drop pos.folded.
	it("lists each bank as a heading with its categories under it, the folded bank's too", function()
		openBank()
		assert.truthy(sb.frame.shown)
		assert.same(BOTH, texts(sb))
		assert.truthy(line(sb, "+ Warband bank (2)").entry.heading)
		assert.truthy(line(sb, "Ore (1)").entry.indent)
	end)

	-- Mutation: in the bank's sidebar click, drop the group open.
	it("a click on a category of the folded bank opens that bank, as its header does, and scrolls to it", function()
		openBank()
		click(line(sb, "Ore (1)"))
		assert.equal(false, BW.Folded("warband"), "opened for this visit (a peek, nothing saved)")
		local y = headerY("warband", "c_ore")
		assert.truthy(y and -y > 0)
		assert.equal(-y, BW.scroll.vscroll, "Ore's header at the top")
		assert.equal("Warband bank (2)", texts(sb)[5])
	end)

	it("a click on a folded category unfolds it, saved as a header click saves it", function()
		SB.Config.Set("bank.show", "both")
		BW.view.Collapsed("bank").c_herbs = true
		openBank()
		click(line(sb, "+ Herbs (1)"))
		assert.is_nil(BW.view.Collapsed("bank").c_herbs)
		assert.equal(-headerY("bank", "c_herbs"), BW.scroll.vscroll)
	end)

	it("a click on a bank's heading opens it and scrolls to its header", function()
		openBank()
		click(line(sb, "+ Warband bank (2)"))
		assert.equal(false, BW.Folded("warband"))
		local g
		for _, h in ipairs(BW.view.pos.groupHeaders) do
			if h.id == "warband" then
				g = h
			end
		end
		assert.equal(-g.y, BW.scroll.vscroll)
	end)

	it("with an item on the cursor a click does nothing", function()
		openBank()
		A.cursor = { itemID = Fixtures.HERB }
		click(line(sb, "Ore (1)"))
		A.Advance(1)
		assert.equal(true, BW.Folded("warband"))
		assert.equal(0, BW.scroll.vscroll)
	end)

	it("hides in the grid and bags views", function()
		SB.Config.Set("bank.view", "grid")
		openBank()
		assert.falsy(sb.frame.shown, "grid")
		SB.Config.Set("bank.view", "bags")
		BW.view.Layout("view")
		assert.falsy(sb.frame.shown, "per-tab")
		SB.Config.Set("bank.view", "list")
		BW.view.Layout("view")
		assert.truthy(sb.frame.shown, "list")
		assert.same(BOTH, texts(sb))
	end)

	-- Blizzard's bank is on the left in the "shown" mode (spec 5.4).
	it("sits on the right while Blizzard's bank is shown beside it, else on the left", function()
		openBank()
		assert.same({ "TOPRIGHT", BW.frame, "TOPLEFT", 0, 0 }, sb.frame.points[1])
		BW.Close()
		SB.Config.Set("bank.blizzardFrame", "beside")
		BW.Open()
		assert.same({ "TOPLEFT", BW.frame, "TOPRIGHT", 0, 0 }, sb.frame.points[1])
	end)

	it("its strip is remembered apart from the bags' one", function()
		openBank()
		click(sb.handle)
		assert.equal(true, SB.Config.UI().sidebarShrunk.bank)
		assert.is_nil(SB.Config.UI().sidebarShrunk.bags)
	end)
end)
