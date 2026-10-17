-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown
-- The bags window's GRID view and window basics. The category view is covered by
-- spec/bagswindow_sections_spec.lua.
local Loader = dofile("spec/helpers/loader.lua")

-- A permissive fake frame: remembers the few things the window logic depends on,
-- and treats every other frame method as a no-op.
local function newFake()
	local f = { shown = false, scale = 1, vscroll = 0, w = 0, h = 0, scripts = {}, points = {} }
	return setmetatable(f, {
		__index = function(_, name)
			if name == "IsShown" then
				return function(self) return self.shown end
			elseif name == "Show" then
				return function(self) self.shown = true end
			elseif name == "Hide" then
				return function(self) self.shown = false end
			elseif name == "SetScale" then
				return function(self, s) self.scale = s end
			elseif name == "GetScale" then
				return function(self) return self.scale end
			elseif name == "SetSize" then
				return function(self, w, h) self.w, self.h = w, h end
			elseif name == "GetHeight" then
				return function(self) return self.h end
			elseif name == "SetScript" then
				return function(self, n, fn) self.scripts[n] = fn end
			elseif name == "SetVerticalScroll" then
				return function(self, v) self.vscroll = v end
			elseif name == "GetVerticalScroll" then
				return function(self) return self.vscroll end
			elseif name == "ClearAllPoints" then
				return function(self) self.points = {} end
			elseif name == "SetPoint" then
				return function(self, ...) self.points[#self.points + 1] = { ... } end
			elseif name == "GetPoint" then
				return function(self, i)
					local p = self.points[i]
					if p then return p[1], p[2], p[3], p[4], p[5] end
				end
			elseif name == "SetText" then
				return function(self, s) self.text = s end
			elseif name == "SetDontSavePosition" then
				return function(self, v) self.dontSave = v end
			elseif name == "CreateFontString" then
				return function() return newFake() end
			end
			return function() end
		end,
	})
end

describe("BagsWindow", function()
	local SB, W, A, fake

	local function buttonFor()
		local cache = {}
		return function(_, slot)
			cache[slot] = cache[slot] or newFake()
			return cache[slot]
		end
	end

	before_each(function()
		SB = Loader.New({
			"SwagBag/Core/Events.lua",
			"SwagBag/Core/ErrorTrap.lua",
			"SwagBag/Core/SafeMode.lua",
			"SwagBag/Core/Config.lua",
			"SwagBag/Core/Slash.lua",
			"SwagBag/Engine/GridLayout.lua",
		})
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		SB.Config.Set("bags.view", "grid")
		fake = { pools = {}, changed = nil }
		CreateFrame = function() return newFake() end
		UIParent = newFake()
		UIParent.h = 1000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		SB.Buttons = {
			created = true,
			SetParentFor = function() end,
			Count = function(bag) return fake.pools[bag] and fake.pools[bag].n or 0 end,
			EnsureCapacity = function(bag, n) fake.pools[bag] = { n = n, get = buttonFor() } end,
			Get = function(bag, slot)
				local p = fake.pools[bag]
				if p and slot <= p.n then return p.get(bag, slot) end
			end,
			Place = function() end,
			Paint = function() end,
			KindOf = function() return "bags" end,
			ReleasePlaceholders = function() end,
		}
		SB.SectionHeaders = { ReleaseAll = function() end }
		SB.Inventory = { R = { SIZE = 1, COOLDOWN = 2 }, Has = function() return false end }
		SB.Inventory.OnChanged = function(cb) fake.changed = cb end
		SB.Items = { Describe = function(bag, slot) return { bag = bag, slot = slot } end }
		A.sizes[0], A.sizes[1] = 16, 0
		Loader.LoadFile(SB, "SwagBag/Engine/Sort.lua") -- TOC order: Sort and ListRows before BagsWindow
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W = SB.BagsWindow
	end)

	after_each(function() -- do not leak WoW globals into other spec files
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
	end)

	it("opts out of the client's saved window position (SwagBag keeps its own)", function()
		assert.equal(true, W.frame.dontSave)
	end)

	-- Final review M2 (W3-26 parity). Mutation: delete the title's RIGHT anchor in W.BoundTitle.
	it("the title ends left of the leftmost shown title button; BoundTitle moves that end", function()
		local function right()
			for _, p in ipairs(W.frame.title.points) do
				if p[1] == "RIGHT" then
					return p
				end
			end
		end
		assert.same({ "RIGHT", W.sortButton, "LEFT", -6, 0 }, right())
		local still = newFake()
		W.BoundTitle(still) -- "Bank still open" shown left of Sort
		assert.same({ "RIGHT", still, "LEFT", -6, 0 }, right())
		assert.same({ "TOPLEFT", 10, -8 }, W.frame.title.points[1])
		W.BoundTitle(nil)
		assert.same({ "RIGHT", W.sortButton, "LEFT", -6, 0 }, right())
		assert.same({ "TOPLEFT", 10, -8 }, W.frame.title.points[1])
	end)

	it("is registered for Esc", function()
		assert.equal("SwagBagBagsWindow", UISpecialFrames[1])
	end)

	it("refuses to open in Safe Mode or before the pool exists", function()
		SB.SafeMode.Enable("bags", "manual")
		assert.falsy(W.Open())
		SB.SafeMode.Disable("bags")
		SB.Buttons.created = false
		assert.falsy(W.Open())
		assert.falsy(W.IsOpen())
	end)

	it("fires SB_BAGS_LAYOUT after the window is shown (P1)", function()
		local seenShown, count
		SB.On("SB_BAGS_LAYOUT", function()
			count = (count or 0) + 1
			seenShown = W.IsOpen()
		end)
		assert.truthy(W.Open())
		assert.equal(1, count)
		assert.truthy(seenShown)
	end)

	it("clamps the scroll offset when the content shrinks", function()
		A.sizes[0] = 160
		W.Open()
		W.scroll.h = 200 -- the client sizes the scroll frame from its anchors
		W.scroll.vscroll = 10000
		W.ClampScroll()
		assert.truthy(W.scroll.vscroll < 10000)
		A.sizes[0] = 4
		W.scroll.vscroll = 10000
		W.Layout("size")
		assert.equal(0, W.scroll.vscroll)
	end)

	it("clamps and saves the scale, and restores the title via a guarded timer", function()
		W.Open()
		W.SetScale(5)
		assert.equal(2.0, SB.Config.Get("bags.scale"))
		assert.equal(2.0, W.frame.scale)
		W.SetScale(0.1)
		assert.equal(0.5, W.frame.scale)
		assert.equal("SwagBag 50%", W.frame.title.text)
		A.Advance(2)
		assert.equal(SB.L.BAGS_TITLE, W.frame.title.text)
	end)

	it("the title shows the average equipped item level with one decimal (D18)", function()
		A.avgIlvl = 279.44
		W.Open()
		assert.equal("SwagBag — ilvl 279.4", W.frame.title.text)
	end)

	it("the item level in the title follows gear swaps while open, and is read again on open", function()
		A.avgIlvl = 279.44
		W.Open()
		A.avgIlvl = 281.06
		SB.eventFrame:Fire("PLAYER_AVG_ITEM_LEVEL_UPDATE")
		assert.equal("SwagBag — ilvl 281.1", W.frame.title.text)
		A.avgIlvl = 283
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 1)
		assert.equal("SwagBag — ilvl 283.0", W.frame.title.text)
		W.frame:Hide()
		A.avgIlvl = 284.5
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 1)
		assert.equal("SwagBag — ilvl 283.0", W.frame.title.text, "closed: nothing is read")
		W.Open()
		assert.equal("SwagBag — ilvl 284.5", W.frame.title.text)
	end)

	it("a flash keeps the title until it ends, then the item-level title comes back up to date", function()
		A.avgIlvl = 279.44
		W.Open()
		W.SetScale(0.5)
		A.avgIlvl = 280.02
		SB.eventFrame:Fire("PLAYER_AVG_ITEM_LEVEL_UPDATE")
		assert.equal("SwagBag 50%", W.frame.title.text, "the flash is not cut short")
		A.Advance(1.5)
		assert.equal("SwagBag — ilvl 280.0", W.frame.title.text)
	end)

	it("no item level from the client, or bags.showIlvl off: the plain title, no error", function()
		A.avgIlvl = nil
		W.Open()
		assert.equal("SwagBag", W.frame.title.text)
		SB.eventFrame:Fire("PLAYER_AVG_ITEM_LEVEL_UPDATE")
		assert.equal("SwagBag", W.frame.title.text)
		assert.equal(0, #SB.ErrorTrap.Recent())
		A.avgIlvl = 279.44
		SB.Config.Set("bags.showIlvl", false)
		W.RefreshTitle()
		assert.equal("SwagBag", W.frame.title.text)
	end)

	it("Ctrl+wheel changes the scale and plain wheel scrolls", function()
		A.sizes[0] = 160
		W.Open()
		IsControlKeyDown = function() return true end
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		assert.equal(1.05, SB.Config.Get("bags.scale"))
		IsControlKeyDown = function() return false end
		W.scroll.vscroll = 100
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		assert.truthy(W.scroll.vscroll < 100)
	end)

	it("saves the position on drag stop and restores it", function()
		W.frame.GetLeft = function() return 30 end
		W.frame.GetTop = function() return 700 end
		W.frame.scripts.OnDragStop()
		assert.same({ "TOPLEFT", "BOTTOMLEFT", 30, 700 }, SB.Config.UI().positions.bags)
		W.RestorePosition()
		assert.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 30, 700 }, W.frame.points[1])
	end)

	it("emits SB_BAGS_UPDATED after a partial repaint while open", function()
		W.Open()
		local updated = 0
		SB.On("SB_BAGS_UPDATED", function() updated = updated + 1 end)
		fake.changed(0, { { bag = 0, slot = 2 } })
		assert.equal(1, updated)
		W.Close()
		fake.changed(0, { { bag = 0, slot = 2 } })
		assert.equal(1, updated)
	end)

	it("hiding the window (Esc, X or Close) emits SB_BAGS_CLOSED", function()
		local closed = 0
		SB.On("SB_BAGS_CLOSED", function() closed = closed + 1 end)
		W.Open()
		W.Close()
		W.frame.scripts.OnHide(W.frame)
		assert.equal(1, closed)
	end)

	-- Mutation: delete the SetVerticalScroll(0) in the OnHide handler.
	it("closing the window scrolls it back to the top for the next open", function()
		A.sizes[0] = 160
		W.Open()
		W.scroll.h = 200
		W.scroll.vscroll = 100
		W.Close()
		W.frame.scripts.OnHide(W.frame)
		assert.equal(0, W.scroll.vscroll)
		W.Open()
		assert.equal(0, W.scroll.vscroll)
	end)

	it("OnHide while the frame is still shown (Alt+Z hiding UIParent) emits nothing", function()
		local closed = 0
		SB.On("SB_BAGS_CLOSED", function() closed = closed + 1 end)
		W.Open()
		W.frame.scripts.OnHide(W.frame)
		assert.equal(0, closed)
	end)

	it("runs its handlers inside the error trap", function()
		W.Open()
		SB.Items.Describe = function() error("boom") end
		fake.changed(0, { { bag = 0, slot = 2 } })
		assert.equal(1, #SB.ErrorTrap.Recent())
	end)
end)
