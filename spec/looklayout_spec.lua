-- luacheck: globals CreateFrame UIParent UISpecialFrames IsControlKeyDown GameTooltip
-- 0.18 (user request: "I want the swagbag to look like EllesmereUI's bags ... and do all the layout ones too"):
-- the "Like EllesmereUI" look gives the bags window a portrait, a centred title with the slot count, round icon
-- buttons on the search row, sections padded to full rows with a "+" drop tile, and the category list inside the
-- window; any other look takes every one of them back. Over the real engine with fake frames and buttons.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

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
		GetFrameLevel = function() return 1 end,
		GetScript = function(self, n) return self.scripts[n] end,
		HookScript = function(self, n, fn)
			local hooks = rawget(self, "hooks") or {}
			rawset(self, "hooks", hooks)
			hooks[n] = fn
		end,
		GetText = function(self) return self.text end,
		GetStringWidth = function(self) return #(self.text or "") * 5 end,
		GetTextInsets = function() return 16 end,
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

describe("Like EllesmereUI layout (bags window)", function()
	local SB, A, W, T, sb
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- backpack 16 slots: potion, flask, BoE ring, soulbound helm, keystone, junk
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h, UIParent.w = 2000, 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		GameTooltip = newFake("GameTooltip")
		A.FontObject = function(name) return { fontObject = name } end
		SB.Buttons = fakeButtons()
		for _, path in ipairs({ "SwagBag/UI/Theme.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/CategorySidebar.lua",
			"SwagBag/UI/ListRows.lua", "SwagBag/UI/BagsWindow.lua", "SwagBag/UI/SearchBox.lua", "SwagBag/UI/Themes.lua",
			"SwagBag/UI/LookLayout.lua" }) do
			Loader.LoadFile(SB, path)
		end
		W, T = SB.BagsWindow, SB.Theme
		sb = W.sidebar
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
	end)

	after_each(function()
		CreateFrame, UIParent, UISpecialFrames, IsControlKeyDown, GameTooltip = nil, nil, nil, nil, nil
	end)

	local function shownPads()
		local out = {}
		for _, f in ipairs(W.pads) do
			if f.shown then
				out[#out + 1] = f
			end
		end
		return out
	end

	-- Mutation: in LookLayout.Apply skip placeButtons, showPortrait or the RequestLayout; in sizeFrame drop the inset.
	it("applies the portrait, centred title, slot count, icon buttons, pads and inside sidebar; Blizzard takes them back", function()
		W.Open()
		local width = W.frame.w
		local sortW = W.sortButton.w
		assert.truthy(T.Apply("ellesmere", false))
		local LL = SB.LookLayout
		assert.truthy(LL.portrait and LL.portrait.shown, "portrait")
		assert.same({ "TOPLEFT", W.TITLE_INSET, -8 }, W.frame.title.points[1], "title centred")
		assert.truthy(LL.slots.shown)
		assert.equal(SB.L.LOOK_SLOTS:format(6, 16), LL.slots.text)
		assert.same({ 24, 24 }, { W.sortButton.w, W.sortButton.h }, "an icon button")
		assert.truthy(LL.icons[W.sortButton].icon.shown)
		local box = SB.SearchBox.editBox
		assert.equal("RIGHT", box.points[2][1], "the search box stretches to the icons")
		assert.equal(W.sortButton, box.points[2][2])
		local pads = shownPads()
		assert.truthy(#pads > 0, "sections padded to full rows")
		assert.truthy(pads[1].plus.shown, "the first pad of a section is the + tile")
		assert.truthy(sb.frame.shown)
		assert.same({ "TOPLEFT", W.frame, "TOPLEFT", 4, -W.HeaderHeight() }, sb.frame.points[1], "the list inside")
		assert.equal(width + sb.frame.w + W.INSIDE_GAP, W.frame.w, "the window makes room for it")

		assert.truthy(T.Apply("blizzard", false))
		assert.falsy(LL.portrait.shown)
		assert.falsy(LL.slots.shown)
		assert.same({ "TOPLEFT", 10, -8 }, W.frame.title.points[1])
		assert.same({ sortW, 18 }, { W.sortButton.w, W.sortButton.h })
		assert.falsy(LL.icons[W.sortButton].icon.shown)
		assert.equal(0, #shownPads())
		assert.equal(0, #SB.ErrorTrap.Recent(), "nothing trapped")
		assert.equal("TOPRIGHT", sb.frame.points[1][1], "beside the window again")
		assert.equal(width, W.frame.w)
	end)

	-- Mutation: in LookLayout's onMessage, never hide the title row.
	it("a search error takes the title row while it says something", function()
		W.Open()
		T.Apply("ellesmere", false)
		local Box, LL = SB.SearchBox, SB.LookLayout
		Box.editBox:SetText("((")
		Box.Run()
		assert.falsy(W.frame.title.shown)
		assert.falsy(LL.slots.shown)
		assert.equal("TOPLEFT", Box.errorLine.points[1][1])
		assert.equal(W.frame, Box.errorLine.points[1][2], "in the title row")
		Box.editBox:SetText("potion")
		Box.Run()
		assert.truthy(W.frame.title.shown)
		assert.truthy(LL.slots.shown)
	end)

	-- Mutation: in the bags window, drop the sidebar's onToggled.
	it("turning the inside list off gives its room back at once", function()
		W.Open()
		local width = W.frame.w
		T.Apply("ellesmere", false)
		assert.truthy(W.frame.w > width)
		SB.Slash.Dispatch("sidebar off")
		assert.falsy(sb.frame.shown)
		assert.equal(width, W.frame.w)
	end)

	-- Mutation: in a pad's drop, skip W.DropOnSection.
	it("an item dropped on a pad joins that section, as on its header", function()
		W.Open()
		T.Apply("ellesmere", false)
		local dropped
		W.DropOnSection = function(id) dropped = id end
		A.CursorItem = function() return 12345, "item:12345" end
		local pad = shownPads()[1]
		pad.scripts.OnReceiveDrag(pad)
		assert.equal(pad.section, dropped)
	end)
end)
