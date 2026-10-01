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

	it("a failing keyword does not break the window and reports the problem", function()
		open()
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("x") end })
		SB.Slash.Dispatch("search boom")
		assert.equal(SB.L.SEARCH_EVAL_FAILED, printed[1])
		assert.falsy(SB.SafeMode.IsOn("bags"))
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
end)
