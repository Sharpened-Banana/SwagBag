-- luacheck: globals CreateFrame
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

-- Permissive fake frame; remembers text, shown state, scripts and hooks.
local function newFake()
	local f = { shown = true, text = "", hooks = {}, points = {}, calls = {} }
	return setmetatable(f, {
		__index = function(_, name)
			if name == "SetText" then
				return function(self, s)
					self.text = s
					if self.hooks.OnTextChanged then
						self.hooks.OnTextChanged(self, false)
					end
				end
			elseif name == "GetText" then
				return function(self) return self.text end
			elseif name == "HookScript" then
				return function(self, n, fn) self.hooks[n] = fn end
			elseif name == "Show" then
				return function(self) self.shown = true end
			elseif name == "Hide" then
				return function(self) self.shown = false end
			elseif name == "IsShown" then
				return function(self) return self.shown end
			elseif name == "GetStringWidth" then
				return function(self) return #(self.text or "") * 5 end
			elseif name == "GetTextInsets" then
				return function() return 16 end
			elseif name == "SetPoint" then
				return function(self, ...) self.points[#self.points + 1] = { ... } end
			elseif name == "CreateFontString" or name == "CreateTexture" then
				return function(self)
					local fs = newFake()
					local list = rawget(self, "created")
					if not list then
						list = {}
						rawset(self, "created", list)
					end
					list[#list + 1] = fs
					return fs
				end
			end
			return function(self, ...)
				self.calls[name] = { ... }
			end
		end,
	})
end

describe("SearchBox", function()
	local SB, Box, window, slots, dimmed, printed

	local function open()
		window.open = true
		SB.Emit("SB_BAGS_LAYOUT", "open")
	end

	before_each(function()
		SB = Loader.New({
			"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
			"SwagBag/Core/Slash.lua",
			"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
			"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua",
		})
		Fixtures.SmallBags(SB.Adapter)
		slots = {}
		for slot = 1, 6 do
			slots[slot] = { button = "b" .. slot, record = SB.Items.Describe(0, slot) }
		end
		dimmed = {}
		window = { open = false, frame = newFake() }
		function window.IsOpen() return window.open end
		function window.ForEachSlot(fn)
			for _, s in ipairs(slots) do
				fn(s.button, s.record)
			end
		end
		function window.SetDimmed(button, d) -- the bags window dims the button (and a list row) through this
			SB.Buttons.SetDimmed(button, d)
		end
		window.relit = 0
		function window.RelightStacks() -- afterApply (0.14.0): a grouped icon whose hidden stack matches is relit
			window.relit = window.relit + 1
		end
		SB.BagsWindow = window
		SB.Buttons = { SetDimmed = function(button, d) dimmed[button] = d end }
		CreateFrame = function() return newFake() end
		printed = {}
		SB.Print = function(msg) printed[#printed + 1] = msg end
		Loader.LoadFile(SB, "SwagBag/UI/SearchBox.lua")
		Box = SB.SearchBox
	end)

	local function dimCount()
		local n = 0
		for _, d in pairs(dimmed) do
			if d then n = n + 1 end
		end
		return n
	end

	it("typing applies the search 150 ms after the last keystroke, not before", function()
		open()
		Box.editBox:SetText("potion")
		SB.Adapter.Advance(0.1)
		assert.equal(0, dimCount())
		SB.Adapter.Advance(0.06)
		assert.truthy(dimCount() > 0)
	end)

	it("re-applies the current dimming when the window reopens (ruling P1)", function()
		open()
		Box.editBox:SetText("potion")
		SB.Adapter.Advance(0.2)
		local dimmedBefore = dimCount()
		assert.truthy(dimmedBefore > 0)
		window.open = false
		dimmed = {} -- reopened buttons come back undimmed
		open()
		assert.equal(dimmedBefore, dimCount())
	end)

	it("re-applies on slot updates (e.g. LOADED re-check)", function()
		open()
		Box.editBox:SetText("potion")
		SB.Adapter.Advance(0.2)
		dimmed = {}
		SB.Emit("SB_BAGS_UPDATED")
		assert.truthy(dimCount() > 0)
	end)

	-- Week 7 (ruling R21): a `locked` search follows a lock or unlock at once. Mutation: SearchBox listens to
	-- `SB_LOCKS_CHANGED_X` instead of `SB_LOCKS_CHANGED`.
	it("re-applies when a lock changes (a locked search follows the lock at once)", function()
		open()
		Box.editBox:SetText("potion")
		SB.Adapter.Advance(0.2)
		dimmed = {}
		SB.Emit("SB_LOCKS_CHANGED")
		assert.truthy(dimCount() > 0)
	end)

	it("a parse error keeps the previous search applied and shows the error inline", function()
		open()
		Box.editBox:SetText("potion")
		SB.Adapter.Advance(0.2)
		local before = dimCount()
		Box.editBox:SetText("potion &")
		SB.Adapter.Advance(0.2)
		assert.truthy(SB.Search.lastError)
		assert.equal("potion", SB.Search.text)
		assert.equal(before, dimCount())
	end)

	it("/swagbag search reports counts, errors, and clears", function()
		SB.Slash.Dispatch("search potion")
		assert.truthy(printed[1]:find("Open your bags", 1, true))
		open()
		SB.Slash.Dispatch("search gear")
		assert.truthy(printed[2]:find("slots match", 1, true))
		SB.Slash.Dispatch("search boe &")
		assert.truthy(printed[3]:find("Search error:", 1, true))
		SB.Slash.Dispatch("search")
		assert.equal("Search cleared.", printed[4])
	end)

	it("an unknown #keyword is a soft warning: the search still applies and the line says why", function()
		open()
		SB.Slash.Dispatch("search #potin")
		assert.equal(2, #printed)
		assert.truthy(printed[1]:find("slots match", 1, true))
		assert.equal("Unknown keyword \"#potin\" matches nothing (character 1)", printed[2])
		local errorLine
		for _, fs in ipairs(window.frame.created) do
			if fs.calls.SetWordWrap then
				errorLine = fs
			end
		end
		assert.equal(printed[2], errorLine.text)
		assert.equal(6, dimCount())
	end)

	it("a warning is drawn in a different colour from an error", function()
		open()
		local function line()
			local found
			for _, fs in ipairs(window.frame.created) do
				if fs.calls.SetWordWrap then
					found = fs
				end
			end
			return found
		end
		SB.Slash.Dispatch("search #potin")
		local warn = line().calls.SetTextColor
		assert.truthy(warn)
		SB.Slash.Dispatch("search boe &")
		local err = line().calls.SetTextColor
		assert.truthy(err)
		assert.falsy(warn[1] == err[1] and warn[2] == err[2] and warn[3] == err[3])
	end)

	it("a failing keyword does not break the window and reports the problem", function()
		open()
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("x") end })
		SB.Slash.Dispatch("search boom")
		assert.equal(SB.L.SEARCH_EVAL_FAILED, printed[1])
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)
	-- 0.14.0 stack grouping. Mutation: drop the o.afterApply call in Box.Apply.
	it("after each search that applies, the bags window relights its grouped icons; a failed one does not", function()
		open()
		local before = window.relit
		assert.truthy(before >= 1, "the open's apply relit")
		Box.editBox:SetText("potion")
		SB.Adapter.Advance(0.2)
		assert.equal(before + 1, window.relit, "after the dimming, once")
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("x") end })
		SB.Slash.Dispatch("search boom")
		assert.equal(before + 1, window.relit, "a search that failed relights nothing")
	end)

	it("the search error line wraps to two lines instead of being cut off", function()
		local errorLine
		for _, fs in ipairs(window.frame.created) do
			if fs.calls.SetWordWrap then
				errorLine = fs
			end
		end
		assert.truthy(errorLine)
		assert.equal(true, errorLine.calls.SetWordWrap[1])
		assert.equal(2, errorLine.calls.SetMaxLines[1])
	end)

	it("another window's box has its own search: typing there never changes the bags window's", function()
		open()
		Box.editBox:SetText("potion")
		SB.Adapter.Advance(0.2)
		local bankFrame, bankDimmed, bankOpen = newFake(), {}, true
		local bankSlots = { { button = "k1", record = slots[3].record }, { button = "k2", record = slots[1].record } }
		local bank = Box.New({
			parent = bankFrame, name = "SwagBagBankSearchBox", search = SB.SearchState.New(), window = "bank",
			debounceKey = "search.bank",
			isOpen = function() return bankOpen end,
			forEachSlot = function(fn)
				for _, s in ipairs(bankSlots) do
					fn(s.button, s.record)
				end
			end,
			setDimmed = function(button, d) bankDimmed[button] = d end,
		})
		bank.editBox:SetText("gear")
		SB.Adapter.Advance(0.2)
		assert.same({ k1 = false, k2 = true }, bankDimmed, "the ring matches gear, the potion does not")
		assert.equal("potion", SB.Search.text, "the bags search is unchanged")
		assert.equal("gear", bank.search.text)
		assert.falsy(dimmed.k1, "the bags window never dimmed bank buttons")
		bank.editBox:SetText("gear &")
		SB.Adapter.Advance(0.2)
		assert.truthy(bank.search.lastError)
		assert.is_nil(SB.Search.lastError, "the error belongs to the bank box only")
	end)

	it("typing in two windows' boxes in the same 150 ms applies both (debounce keys are separate)", function()
		open()
		local bankDimmed = {}
		local bankSlots = { { button = "k1", record = slots[3].record }, { button = "k2", record = slots[1].record } }
		local bank = Box.New({
			parent = newFake(), name = "SwagBagBankSearchBox", search = SB.SearchState.New(), window = "bank",
			debounceKey = "search.bank",
			isOpen = function() return true end,
			forEachSlot = function(fn)
				for _, s in ipairs(bankSlots) do
					fn(s.button, s.record)
				end
			end,
			setDimmed = function(button, d) bankDimmed[button] = d end,
		})
		Box.editBox:SetText("potion")
		bank.editBox:SetText("gear")
		SB.Adapter.Advance(0.2)
		assert.equal("potion", SB.Search.text)
		assert.equal("gear", bank.search.text)
		assert.truthy(dimCount() > 0, "the bags search applied")
		assert.same({ k1 = false, k2 = true }, bankDimmed, "the bank search applied")
	end)

	it("the error line is top-aligned right of the box and never stretches over the items", function()
		local errorLine
		for _, fs in ipairs(window.frame.created) do
			if fs.calls.SetWordWrap then
				errorLine = fs
			end
		end
		assert.equal(2, #errorLine.points)
		assert.same({ "TOPLEFT", Box.editBox, "TOPRIGHT", 8, 4 }, errorLine.points[1])
		assert.same({ "TOPRIGHT", window.frame, "TOPRIGHT", -62, -26 }, errorLine.points[2], "clear of the Lock button (week 7)")
		assert.equal("TOP", errorLine.calls.SetJustifyV[1])
	end)

	-- Week 11. Mutation: in SearchBox.lua's new(), `local box = SB.TextBox(CreateFrame("EditBox", o.name, o.parent,
	-- "SearchBoxTemplate"))` -> `local box = CreateFrame("EditBox", o.name, o.parent, "SearchBoxTemplate")`.
	it("combat start makes the search box let the keyboard go, so ability keys work in a pull (week 11)", function()
		Box.editBox.calls.ClearFocus = nil
		SB.Emit("PLAYER_REGEN_DISABLED")
		assert.truthy(Box.editBox.calls.ClearFocus)
	end)
end)
