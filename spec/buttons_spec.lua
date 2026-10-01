-- luacheck: globals GameTooltip
local Loader = dofile("spec/helpers/loader.lua")

-- Permissive fake frame: records scripts, points, text and every other call.
local function fakeFrame(kind)
	local f = { kind = kind, scripts = {}, shown = true, points = {}, calls = {} }
	return setmetatable(f, {
		__index = function(_, name)
			if name == "SetScript" then
				return function(self, n, fn) self.scripts[n] = fn end
			elseif name == "Show" then
				return function(self) self.shown = true end
			elseif name == "Hide" then
				return function(self) self.shown = false end
			elseif name == "SetPoint" then
				return function(self, ...) self.points[#self.points + 1] = { ... } end
			elseif name == "ClearAllPoints" then
				return function(self) self.points = {} end
			elseif name == "CreateTexture" or name == "CreateFontString" then
				return function() return fakeFrame("region") end
			elseif name == "SetText" then
				return function(self, t) self.text = t end
			end
			return function(self, ...) self.calls[name] = { ... } end
		end,
	})
end

local FILES = { "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua" }

describe("Placeholders (spec 4.2 rule 3, check V4)", function()
	local SB, created, tip
	before_each(function()
		SB = Loader.New(FILES)
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		created = {}
		CreateFrame = function(kind)
			local f = fakeFrame(kind)
			created[#created + 1] = f
			return f
		end
		tip = { shown = false }
		GameTooltip = {
			SetOwner = function(_, owner) tip.owner = owner end,
			SetText = function(_, text) tip.text = text end,
			Show = function() tip.shown = true end,
			Hide = function() tip.shown = false end,
		}
	end)

	after_each(function()
		GameTooltip = nil
	end)

	it("is a plain Frame showing the old icon, desaturated, at the given cell", function()
		local parent = fakeFrame("Frame")
		local p = SB.Buttons.AcquirePlaceholder(parent, 12345, 37, 41, -20)
		assert.equal("Frame", p.kind)
		assert.equal(12345, p.icon.calls.SetTexture[1])
		assert.equal(true, p.icon.calls.SetDesaturated[1])
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 41, -20 }, p.points[1])
		assert.same({ 37, 37 }, p.calls.SetSize)
		assert.truthy(p.shown)
	end)

	it("clicking it only shows a tooltip: it has no click, drag or drop handler (V4)", function()
		local p = SB.Buttons.AcquirePlaceholder(fakeFrame("Frame"), 1, 37, 0, 0)
		local names = {}
		for name in pairs(p.scripts) do
			names[#names + 1] = name
		end
		table.sort(names)
		assert.same({ "OnEnter", "OnLeave", "OnMouseDown" }, names)
		p.scripts.OnMouseDown(p, "RightButton")
		assert.truthy(tip.shown)
		assert.equal(SB.L.PLACEHOLDER_TIP, tip.text)
		assert.equal(p, tip.owner)
		p.scripts.OnLeave(p)
		assert.falsy(tip.shown)
	end)

	it("is pooled: released placeholders hide and are reused", function()
		local parent = fakeFrame("Frame")
		local a = SB.Buttons.AcquirePlaceholder(parent, 1, 37, 0, 0)
		SB.Buttons.ReleasePlaceholders()
		assert.falsy(a.shown)
		assert.equal(a, SB.Buttons.AcquirePlaceholder(parent, 2, 37, 0, 0))
		assert.equal(1, #created)
	end)
end)

describe("Section headers", function()
	local SB, H
	before_each(function()
		SB = Loader.New(FILES)
		CreateFrame = function(kind) return fakeFrame(kind) end
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		H = SB.SectionHeaders
	end)

	it("labels show the collapse marker, name, count and New's overflow", function()
		assert.equal("- Consumables (12)", H.Label("Consumables", 12, false, 0))
		assert.equal("+ Gear (3)", H.Label("Gear", 3, true))
		assert.equal("- New (8)  +3 more below", H.Label("New", 8, false, 3))
	end)

	it("are pooled plain Buttons whose click and drop call the window's actions with the section id", function()
		local clicks, drops = {}, {}
		H.onClick = function(id) clicks[#clicks + 1] = id end
		H.onDrop = function(id) drops[#drops + 1] = id end
		local parent = fakeFrame("Frame")
		local h = H.Acquire(parent, "c_gear", "- Gear (3)", 4, -30, 300)
		assert.equal("Button", h.kind)
		assert.equal("- Gear (3)", h.text.text)
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 4, -30 }, h.points[1])
		h.scripts.OnClick(h)
		h.scripts.OnReceiveDrag(h)
		assert.same({ "c_gear" }, clicks)
		assert.same({ "c_gear" }, drops)
		H.ReleaseAll()
		assert.falsy(h.shown)
		assert.equal(h, H.Acquire(parent, "new", "x", 0, 0, 10))
		assert.equal("new", h.sectionId)
	end)
end)
