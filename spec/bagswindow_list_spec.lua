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

	-- AC8.2 in the list view: same sections, same mode sets (the collapse style, week 4).
	it("a focus mode collapses the same sections as in the category view", function()
		SB.Config.Set("focus.style", "collapse")
		W.Open()
		SB.Focus.SetSignal("challengeMode", true)
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		assert.equal("- Consumables (2) - 25s vendor", header("c_consumables").text.text)
		assert.falsy(row(6).shown, "junk's row is hidden with its section")
		assert.truthy(row(1).shown)
	end)

	-- Week 6, the "front" style in the list: the same re-order, and each row stays beside its button.
	-- Mutation: in W.Restack, position(W.state, view) without the order.
	it("a mode in the front style moves its sections up in the list too; every row follows its button", function()
		W.Open()
		SB.Focus.SetSignal("merchantOpen", true)
		assert.equal("- Junk (1)", headers()[1])
		assert.equal("- Gear (1)", headers()[5])
		assert.truthy(row(6).shown and row(4).shown, "nothing collapses")
		assert.equal(B.Get(0, 6).y, rowY(6), "Junk's row moved with its button")
		assert.truthy(rowY(6) > rowY(5), "Junk is above Keystone now")
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

	local function lastTopLeft(f)
		local found
		for _, p in ipairs(f.points) do
			if p[1] == "TOPLEFT" then
				found = p
			end
		end
		return found
	end

	it("the column bar shows above the list only, and the items start under it", function()
		W.Open()
		assert.truthy(W.columnsBar.shown)
		assert.equal(-(W.HEADER + W.COLUMNS_H), lastTopLeft(W.scroll)[5])
		assert.equal(W.child.h + W.HEADER + W.COLUMNS_H + W.foot, W.frame.h, "the bar is part of the window")
		assert.equal("Value v", W.columnButtons.value.label.text, "the sorted column carries a marker")
		assert.equal("Name", W.columnButtons.name.label.text)
		W.SetView("grid")
		assert.falsy(W.columnsBar.shown)
		assert.equal(-W.HEADER, lastTopLeft(W.scroll)[5])
	end)

	-- Preflight a2: each header sits exactly over its column of row texts (same left edge, width and
	-- justification, in the window's units). Mutation: place the bar at 4 + W.PAD + W.LIST_ROW (drop
	-- W.ROW_TEXT_GAP).
	it("each column header lines up with its column of row texts", function()
		W.Open()
		local r = row(1)
		local barX = lastTopLeft(W.columnsBar)[4]
		local rowX = lastTopLeft(W.scroll)[4] + r.points[1][4] -- the scroll child sits at the scroll frame's corner
		for _, id in ipairs(SB.Sort.COLUMNS) do
			local b, fs = W.columnButtons[id], r[id]
			assert.equal(rowX + fs.points[1][4], barX + b.points[1][4], id .. ": the same left edge")
			assert.equal(fs.calls.SetWidth[1], b.w, id .. ": the same width")
			assert.equal(fs.calls.SetJustifyH[1], b.label.calls.SetJustifyH[1], id .. ": the same justification")
		end
		assert.equal(-W.HEADER, lastTopLeft(W.columnsBar)[5], "the bar sits right under the search row")
	end)

	-- W4-1: the bar follows the DRAWN view, not the setting. Mutation: in W.HeaderHeight, read
	-- W.View() instead of W.drawn.
	it("the column bar follows the drawn view while a view change is held under the mouse", function()
		W.Open()
		local h = W.frame.h
		W.scroll.mouseOver = true
		W.SetView("grid")
		W.Resize()
		assert.truthy(W.columnsBar.shown, "held: the list and its bar stay")
		assert.equal(h, W.frame.h, "the header room stays")
		assert.equal(-(W.HEADER + W.COLUMNS_H), lastTopLeft(W.scroll)[5])
		W.scroll.mouseOver = false
		A.Advance(W.RETRY)
		assert.equal("grid", W.drawn)
		assert.falsy(W.columnsBar.shown)
		assert.equal(-W.HEADER, lastTopLeft(W.scroll)[5])
	end)

	-- F6 + W4-1: a list that falls back to categories draws no column bar. Mutation: in W.Layout, show
	-- the bar before the scale check (keyed on the setting's view).
	it("a list that falls back to categories (F6) has no column bar", function()
		SB.Config.Set("bags.view", "sections")
		W.Open()
		for slot = 1, 16 do
			B.Get(0, slot).SetScale = function() end
		end
		W.SetView("list")
		assert.equal("sections", W.drawn)
		assert.falsy(W.columnsBar.shown)
		assert.equal(-W.HEADER, lastTopLeft(W.scroll)[5])
	end)

	-- Mutation: in W.SortList, drop the W.RequestLayout("listsort") call.
	it("a click on the sorted column flips it: saved, answered in the title, and the list regroups", function()
		W.Open()
		W.columnButtons.value.scripts.OnClick(W.columnButtons.value)
		assert.same({ by = "value", desc = false }, SB.Sort.Spec())
		assert.equal("Sorted by Value, lowest first", W.frame.title.text)
		assert.equal("Value ^", W.columnButtons.value.label.text)
		assert.truthy(B.Get(0, 1).y > B.Get(0, 2).y, "potion (500) above flask (2000) now")
	end)

	it("a click on another column sorts by it in its natural direction (names A to Z)", function()
		W.Open()
		W.columnButtons.name.scripts.OnClick(W.columnButtons.name)
		assert.same({ by = "name", desc = false }, SB.Sort.Spec())
		assert.equal("Sorted by Name, A to Z", W.frame.title.text)
		assert.equal("Name ^", W.columnButtons.name.label.text)
		assert.equal("Value", W.columnButtons.value.label.text)
	end)

	-- P5: re-sorting never moves a row under the mouse. Mutation: in W.SortList, call W.Layout
	-- instead of W.RequestLayout.
	it("a re-sort waits while the mouse is over the items or an item is on the cursor", function()
		W.Open()
		local potion, flask = B.Get(0, 1), B.Get(0, 2)
		local py, fy = potion.y, flask.y
		W.scroll.mouseOver = true
		W.SortList("value")
		assert.equal(py, potion.y, "held while the mouse is over the items")
		assert.equal(fy, flask.y)
		W.scroll.mouseOver = false
		A.cursor = { itemID = Fixtures.HERB }
		A.Advance(W.RETRY)
		assert.equal(py, potion.y, "held while an item is on the cursor")
		A.cursor = nil
		A.Advance(W.RETRY)
		assert.equal(fy, potion.y, "swapped once both are clear")
	end)

	-- Mutation: in W.SortList, ignore Sort.Save's result.
	it("read-only settings: a column click refuses with the reason and the order stays", function()
		W.Open()
		local y = B.Get(0, 1).y
		SB.Config.readOnly = true
		W.columnButtons.name.scripts.OnClick(W.columnButtons.name)
		assert.equal(SB.L.SETTINGS_READONLY, W.frame.title.text)
		assert.same({ by = "value", desc = true }, SB.Sort.Spec())
		assert.equal(y, B.Get(0, 1).y)
	end)

	it("/swagbag list shows and sets the order, and answers every form (P2)", function()
		W.Open()
		SB.Slash.Dispatch("list")
		SB.Slash.Dispatch("list name")
		SB.Slash.Dispatch("list count asc")
		SB.Slash.Dispatch("list weight")
		assert.same({ "List view: sorted by Value, highest first.", "Sorted by Name, A to Z", "Sorted by Count, lowest first",
			SB.L.LIST_USAGE }, A.Lines())
		assert.same({ by = "count", desc = false }, SB.Sort.Spec())
		W.SetView("grid")
		SB.Slash.Dispatch("list ilvl")
		assert.equal(SB.L.LIST_NOT_SHOWN, A.Lines()[6])
	end)

	-- The Settings rows run this command through Slash.Run. Mutation: in the list command, ignore
	-- W.SortList's result.
	it("/swagbag list (and so the Settings rows) refuses with read-only settings and changes nothing", function()
		W.Open()
		SB.Config.readOnly = true
		SB.Slash.Dispatch("list name")
		assert.same({ SB.L.SETTINGS_READONLY }, A.Lines())
		local ok, feedback = SB.Slash.Run("list count asc")
		assert.truthy(ok)
		assert.equal(SB.L.SETTINGS_READONLY, feedback)
		assert.same({ by = "value", desc = true }, SB.Sort.Spec())
	end)

	-- D27 without a double line: the command already answers in chat, so its title flash never adds
	-- a second chat line. Mutation: in the list command, call W.SortList without its quiet flag.
	it("/swagbag list answers once in chat even when its title flash is cut short", function()
		W.Open()
		W.frame.title.truncated = true
		SB.Slash.Dispatch("list name")
		assert.same({ "Sorted by Name, A to Z" }, A.Lines())
		assert.equal("Sorted by Name, A to Z", W.frame.title.text, "the title still answers")
	end)

	-- Ruling W5-4: a caller that answers itself passes quiet, so a cut-short flash adds no chat line.
	-- Mutation: the view command calls W.SetView(arg) without quiet.
	it("/swagbag view answers once in chat even when its title flash is cut short", function()
		W.Open()
		W.frame.title.truncated = true
		SB.Slash.Dispatch("view grid")
		assert.same({ SB.L.VIEW_GRID }, A.Lines())
		assert.equal(SB.L.VIEW_GRID, W.frame.title.text, "the title still answers")
	end)

	-- The real Settings pages over the real bags window (ruling W5-4).
	local function openSettings()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		local SW = SB.SettingsWindow
		SW.Show("bags")
		return SW, function(text)
			for i = 1, SW.used.buttons do
				local b = SW.buttons[i]
				if b.text == text then
					b.scripts.OnClick(b)
					return
				end
			end
			error("no button " .. text)
		end
	end

	-- Mutation: the Settings view row calls W.SetView(v) without quiet.
	it("the Settings view row answers once, in the status line, even when the title flash is cut short", function()
		W.Open()
		local SW, click = openSettings()
		W.frame.title.truncated = true
		click("Grid")
		assert.equal("grid", W.View())
		assert.equal(SB.L.VIEW_GRID, SW.lastStatus)
		assert.same({}, A.Lines(), "no chat line besides the status line")
	end)

	-- Mutation: the Settings scale row calls W.SetScale(v) without quiet.
	it("the Settings scale row answers once, in the status line, even when the title flash is cut short", function()
		W.Open()
		local SW, click = openSettings()
		W.frame.title.truncated = true
		click("125%")
		assert.equal(1.25, SB.Config.Get("bags.scale"))
		assert.equal("SwagBag 125%", SW.lastStatus)
		assert.same({}, A.Lines(), "no chat line besides the status line")
	end)

	it("the Settings list rows answer once, in the status line, even when the title flash is cut short", function()
		W.Open()
		local SW, click = openSettings()
		W.frame.title.truncated = true
		click("Name")
		assert.equal("Sorted by Name, A to Z", SW.lastStatus)
		assert.same({}, A.Lines(), "no chat line besides the status line")
	end)

	local function positions()
		local out = {}
		for slot = 1, 16 do
			local b = B.Get(0, slot)
			out[slot] = { b.x, b.y, b.placed, b.shown }
		end
		return out
	end

	-- Fix round 1, item 3: the order is saved, but only a drawn list regroups. Mutation: in W.SortList,
	-- request the layout whenever the window is shown (drop the isList() check).
	it("a sort change while the list is not drawn (grid, or an F6 fallback) requests no layout and moves nothing", function()
		local layouts = 0
		SB.On("SB_BAGS_LAYOUT", function() layouts = layouts + 1 end)
		W.Open()
		W.SetView("grid")
		local at, n = positions(), layouts
		W.columnButtons.name.scripts.OnClick(W.columnButtons.name)
		SB.Slash.Dispatch("list count")
		A.Advance(W.RETRY)
		assert.equal(n, layouts, "grid: no layout")
		assert.same(at, positions(), "grid: nothing moved")
		assert.same({ by = "count", desc = true }, SB.Sort.Spec(), "the order is saved")
		-- F6: the setting says list, the drawn view is categories
		for slot = 1, 16 do
			B.Get(0, slot).SetScale = function() end
		end
		W.SetView("list")
		assert.equal("sections", W.drawn)
		at, n = positions(), layouts
		W.columnButtons.value.scripts.OnClick(W.columnButtons.value)
		SB.Slash.Dispatch("list name")
		A.Advance(W.RETRY)
		assert.equal(n, layouts, "fallback: no layout")
		assert.same(at, positions(), "fallback: nothing moved")
		assert.same({ by = "name", desc = false }, SB.Sort.Spec())
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

	-- F6 for a bag equipped while the list is open, with the free tile: the new slots are hidden
	-- spares, so nothing full-size shows; the next full layout draws as categories. Mutation: in
	-- W.Layout, drop the listFailed call.
	it("a slot added to the open list whose scale does not take is never shown in a row; the next layout falls back", function()
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
		for slot = 1, 4 do
			assert.falsy(B.Get(1, slot).shown, "slot " .. slot)
		end
		W.Reflow()
		assert.equal("sections", W.drawn)
		assert.equal(1, B.Get(0, 1).scale, "every button back at full size")
		assert.same({ SB.L.LIST_SCALE_FALLBACK }, A.Lines())
	end)

	-- Ruling W5-1: never a full-size button in a list row, also while the fallback layout is held
	-- under the mouse. Mutation: remove the scaleIs guard in showAt.
	it("a slot whose scale does not take stays hidden, row and all, until the fallback layout runs", function()
		SB.Config.Set("bags.freeTile", false) -- every empty slot is shown, so the new ones would be drawn
		W.Open()
		local ensure = B.EnsureCapacity
		B.EnsureCapacity = function(bag, n)
			ensure(bag, n)
			for _, b in ipairs(B.buttons[bag]) do
				b.SetScale = function() end
			end
		end
		local delays, debounce = {}, SB.Debounce
		SB.Debounce = function(key, delay, ...)
			if key == "bags.scale" then
				delays[#delays + 1] = delay
			end
			return debounce(key, delay, ...)
		end
		W.scroll.mouseOver = true
		A.SetBagSize(1, 4)
		bagUpdate(1)
		A.Advance(0)
		assert.equal("list", W.drawn, "the fallback waits for the mouse")
		-- Ruling W5-3. Mutation: the showAt guard's debounce at 0 (a broken fallback would ask every frame).
		assert.truthy(#delays > 0)
		for _, d in ipairs(delays) do
			assert.equal(W.RETRY, d, "the fallback is asked for at most every 300 ms")
		end
		for slot = 1, 4 do
			assert.falsy(B.Get(1, slot).shown, "slot " .. slot .. " is not drawn at full size in a row")
			local r = W.rows.rows[B.Get(1, slot)]
			assert.truthy(r == nil or not r.shown, "and has no row")
		end
		W.scroll.mouseOver = false
		A.Advance(W.RETRY)
		assert.equal("sections", W.drawn)
		assert.truthy(B.Get(1, 1).shown)
		assert.same({ SB.L.LIST_SCALE_FALLBACK }, A.Lines())
	end)

	-- Fix round 1, item 3. Mutation: the wheel steps by W.SLOT + W.GAP in the list.
	it("the mouse wheel scrolls three rows per notch in the list", function()
		W.Open()
		W.scroll.scripts.OnMouseWheel(W.scroll, -1)
		assert.equal((W.LIST_ROW + W.LIST_GAP) * 3, W.scroll.vscroll)
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

describe("BagsWindow week-4 carry-overs (title flash, drop, default place)", function()
	local SB, A, W, B, F
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		SB.Config.Set("focus.style", "collapse") -- the grow tests need a mode that collapses (week 4)
		Fixtures.SmallBags(A)
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W, F = SB.BagsWindow, SB.Focus
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
	end)

	local function viewHeight()
		return W.frame.h - W.HEADER - W.foot
	end

	-- Week-4 deferred M4. Mutation: in W.Flash, drop the SB.Print when the title is truncated.
	it("a flash cut short by the title's room also goes to chat; one that fits does not", function()
		W.Open()
		W.Flash("short")
		assert.same({}, A.Lines())
		W.frame.title.truncated = true
		W.Flash("Sorted by Value, lowest first")
		assert.same({ "Sorted by Value, lowest first" }, A.Lines())
	end)

	-- Week-4 deferred: a drag stopped the W4-25 grow retry and the drop did not fit the window again.
	-- Mutation: in OnDragStop, drop the W.Resize() call.
	it("a drop fits the window again: a grow that waited during the drag applies once the pointer leaves", function()
		SB.Config.UI().positions.bags = { "BOTTOMLEFT", "BOTTOMLEFT", 100, 0 }
		F.SetSignal("challengeMode", true)
		W.Open()
		local top = W.frame:GetTop()
		W.frame.mouseOver = true
		W.TogglePause()
		assert.equal(top, W.frame:GetTop(), "capped under the mouse")
		W.frame.scripts.OnDragStart(W.frame)
		A.Advance(W.RETRY)
		W.frame.scripts.OnDragStop(W.frame)
		assert.equal(top, W.frame:GetTop(), "the drop moved nothing under the mouse")
		W.frame.mouseOver = false
		A.Advance(W.RETRY)
		assert.truthy(W.frame:GetTop() > top, "grown up once the pointer left")
		assert.equal(W.size[2], viewHeight())
		assert.equal(0, W.frame:GetTop() - W.frame.h, "the bottom edge stays on the screen")
	end)

	-- Week-4 deferred: no test opened the window at its default place (bottom right, 100 up).
	it("at the default place, Pause with the mouse away grows the window to the whole bag, on the screen", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		assert.equal(100, W.frame:GetTop() - W.frame.h, "preflight: the default place, 100 above the bottom")
		W.TogglePause()
		assert.equal(W.size[2], viewHeight(), "the view is as tall as the bag")
		assert.truthy(W.frame:GetTop() - W.frame.h >= 0, "the bottom edge is on the screen")
		assert.truthy(W.frame:GetTop() <= UIParent.h, "the top edge is on the screen")
	end)
end)

describe("BagsWindow look (themes)", function()
	local SB, A, W
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.FontObject = function(name) return { fontObject = name } end
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		SB.Buttons = fakeButtons()
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
	end)

	-- AC14.1 and the live switch. Mutation: in BagsWindow.lua, drop SB.Theme.Window(frame, "main").
	it("the window, its title, column labels, headers and list rows follow the look, live and back", function()
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, W.frame.calls.SetBackdropColor, "the Blizzard look as before")
		SB.Config.Set("bags.view", "list")
		W.Open()
		local row = W.rows.rows[SB.Buttons.Get(0, 1)]
		assert.falsy(row.bg.shown)
		assert.truthy(SB.Theme.Apply("flat", false))
		assert.same({ 0.09, 0.09, 0.1, 0.92 }, W.frame.calls.SetBackdropColor)
		assert.same({ { fontObject = "GameFontHighlight" } }, W.frame.title.calls.SetFontObject)
		assert.same({ { fontObject = "GameFontHighlightSmall" } }, W.columnButtons.value.label.calls.SetFontObject)
		assert.truthy(row.bg.shown, "list rows get the flat stripe")
		assert.same({ { fontObject = "GameFontHighlightSmall" } }, row.name.calls.SetFontObject)
		assert.same({ 1, 1, 1, 0.03 }, SB.SectionHeaders.inUse[1].bg.calls.SetColorTexture)
		SB.Theme.Apply("blizzard", false)
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, W.frame.calls.SetBackdropColor)
		assert.falsy(row.bg.shown)
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
