-- luacheck: globals GameTooltip SetItemButtonTexture SetItemButtonCount SetItemButtonQuality SetItemButtonDesaturated
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

	it("re-parents a reused placeholder to the parent it is acquired with", function()
		local A, B = fakeFrame("Frame"), fakeFrame("Frame")
		local a = SB.Buttons.AcquirePlaceholder(A, 1, 37, 0, 0)
		SB.Buttons.ReleasePlaceholders()
		local b = SB.Buttons.AcquirePlaceholder(B, 1, 37, 0, 0)
		assert.equal(a, b)
		assert.equal(B, b.calls.SetParent[1])
	end)

	-- Ruling W3-23 (spec P6). Mutation: "bags" instead of placeholderWindow[self] in the
	-- placeholder scripts. (A reused placeholder takes its window from Acquire.)
	it("a bank placeholder's tooltip errors are trapped as the bank window's; reused, it is the bags'", function()
		local p = SB.Buttons.AcquirePlaceholder(fakeFrame("Frame"), 1, 37, 0, 0, "bank")
		GameTooltip.SetOwner = function() error("tooltip broke") end
		p.scripts.OnEnter(p)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"), "the bags window keeps working")
		SB.SafeMode.Disable("bank")
		p.scripts.OnMouseDown(p)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		SB.SafeMode.Disable("bank")
		GameTooltip.Hide = function() error("hide broke") end
		p.scripts.OnLeave(p)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		SB.SafeMode.Disable("bank")
		SB.Buttons.ReleasePlaceholders()
		local q = SB.Buttons.AcquirePlaceholder(fakeFrame("Frame"), 1, 37, 0, 0)
		assert.equal(p, q)
		q.scripts.OnEnter(q)
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	-- Week 8 ruling. Mutation: in Buttons.lua placeholderTip, `placeholderText[self] or ` -> ``.
	it("a window's own tooltip text rides along; a reused placeholder goes back to the bags' text", function()
		local p = SB.Buttons.AcquirePlaceholder(fakeFrame("Frame"), 1, 37, 0, 0, "bank", "moved: close the bank")
		p.scripts.OnEnter(p)
		assert.equal("moved: close the bank", tip.text)
		SB.Buttons.ReleasePlaceholders()
		local q = SB.Buttons.AcquirePlaceholder(fakeFrame("Frame"), 1, 37, 0, 0)
		assert.equal(p, q)
		q.scripts.OnEnter(q)
		assert.equal(SB.L.PLACEHOLDER_TIP, tip.text)
	end)

	it("OnEnter shows the tooltip, and does nothing without GameTooltip", function()
		local p = SB.Buttons.AcquirePlaceholder(fakeFrame("Frame"), 1, 37, 0, 0)
		p.scripts.OnEnter(p)
		assert.truthy(tip.shown)
		assert.equal(SB.L.PLACEHOLDER_TIP, tip.text)
		GameTooltip = nil
		p.scripts.OnEnter(p)
		p.scripts.OnLeave(p)
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

	it("clears sectionId on release and re-parents a reused header", function()
		local A, B = fakeFrame("Frame"), fakeFrame("Frame")
		local h = H.Acquire(A, "x", "x", 0, 0, 10)
		H.ReleaseAll()
		assert.is_nil(rawget(h, "sectionId"))
		assert.equal(h, H.Acquire(B, "y", "y", 0, 0, 10))
		assert.equal(B, h.calls.SetParent[1])
	end)
end)

describe("Button pool growth, parents and bank tabs (week-1 ledger)", function()
	local Fake = dofile("spec/helpers/fakeframe.lua")
	local SB, A, B
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		B = SB.Buttons
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	it("growth asked for during combat keeps the largest request, in either order", function()
		A.combat = true
		B.EnsureCapacity(0, 40)
		B.EnsureCapacity(0, 20)
		B.EnsureCapacity(1, 12)
		B.EnsureCapacity(1, 30)
		assert.equal(0, B.Count(0), "nothing is created in combat")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(40, B.Count(0))
		assert.equal(30, B.Count(1))
	end)

	it("a login that failed half-way creates the rest when bags Safe Mode is switched off", function()
		A.SetBagSize(0, 16)
		local made = 0
		CreateFrame = function(kind, ...)
			if kind == "ItemButton" then
				made = made + 1
				if made == 50 then
					error("client hiccup")
				end
			end
			return Fake.CreateFrame(kind, ...)
		end
		SB.Emit("SB_LOGIN")
		assert.falsy(B.created)
		assert.truthy(SB.SafeMode.IsOn("bags"))
		CreateFrame = Fake.CreateFrame
		SB.SafeMode.Disable("bags")
		assert.truthy(B.created)
		for bag = 0, 5 do
			assert.equal(38, B.Count(bag), "bag " .. bag)
		end
	end)

	it("SetParentFor moves bag frames made earlier onto the new parent; their buttons stay on them", function()
		B.EnsureCapacity(6, 2)
		B.EnsureCapacity(0, 1)
		local holder, bagsParent = B.frames[6].parent, B.frames[0].parent
		local child = Fake.New("Frame")
		B.SetParentFor("bank", child)
		assert.equal(child, B.frames[6].parent)
		assert.equal(child, B.frames[6].allPoints)
		assert.equal(B.frames[6], B.Get(6, 1).parent, "the item button was not reparented")
		assert.equal(bagsParent, B.frames[0].parent, "other kinds are untouched")
		assert.truthy(holder ~= child)
	end)

	it("SetParentFor in combat moves the bag frames when combat ends", function()
		B.EnsureCapacity(12, 1)
		local child = Fake.New("Frame")
		A.combat = true
		B.SetParentFor("warband", child)
		assert.truthy(B.frames[12].parent ~= child)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(child, B.frames[12].parent)
	end)

	it("a bank tab bought after login gets its 98 buttons when the bank opens", function()
		A.bagIDs.bank = { 6 }
		SB.Emit("SB_LOGIN")
		assert.equal(98, B.Count(6))
		assert.equal(0, B.Count(7))
		A.bagIDs.bank = { 6, 7 }
		A.SetBagSize(7, 98)
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.equal(98, B.Count(7))
		assert.equal(98, B.Count(6), "nothing extra for the old tab")
	end)

	-- Ruling W3-22 (spec P6). Mutation: "bags" instead of the kind check in EnsureCapacity's
	-- OutOfCombat call.
	it("queued bank-tab growth that fails is trapped as the bank window's; the bags stay out of Safe Mode", function()
		A.combat = true
		B.EnsureCapacity(6, 2)
		CreateFrame = function(kind, ...)
			if kind == "ItemButton" then
				error("client hiccup")
			end
			return Fake.CreateFrame(kind, ...)
		end
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		CreateFrame = Fake.CreateFrame
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("queued bag growth that fails is still trapped as the bags window's", function()
		A.combat = true
		B.EnsureCapacity(1, 2)
		CreateFrame = function(kind, ...)
			if kind == "ItemButton" then
				error("client hiccup")
			end
			return Fake.CreateFrame(kind, ...)
		end
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		CreateFrame = Fake.CreateFrame
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	-- Ruling W3-22. Mutation: "bags" instead of the kind check in SetParentFor's OutOfCombat call.
	it("a bank or warband bag frame move that fails is trapped as the bank window's", function()
		B.EnsureCapacity(12, 1)
		B.frames[12].SetParent = function() error("no parent") end
		B.SetParentFor("warband", Fake.New("Frame"))
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("ReleasePlaceholders(parent) releases only the placeholders inside that parent", function()
		local bagsChild, bankChild = Fake.New("Frame"), Fake.New("Frame")
		local a = B.AcquirePlaceholder(bagsChild, 1, 37, 0, 0)
		local b = B.AcquirePlaceholder(bankChild, 2, 37, 0, 0)
		B.ReleasePlaceholders(bagsChild)
		assert.falsy(a.shown)
		assert.truthy(b.shown)
		assert.same({ b }, B.placeholdersInUse)
		B.ReleasePlaceholders()
		assert.falsy(b.shown)
	end)
end)

describe("Section headers per window", function()
	local Fake = dofile("spec/helpers/fakeframe.lua")
	local SB, H
	before_each(function()
		SB = Loader.New(FILES)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		H = SB.SectionHeaders
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	it("an owner's onClick and onDrop handle its headers; headers without an owner use the bags window's", function()
		local bagsClicks, bankClicks, bankDrops = {}, {}, {}
		H.onClick = function(id) bagsClicks[#bagsClicks + 1] = id end
		local owner = { onClick = function(id) bankClicks[#bankClicks + 1] = id end,
			onDrop = function(id) bankDrops[#bankDrops + 1] = id end }
		local mine = H.Acquire(Fake.New("Frame"), "bank:c_gear", "x", 0, 0, 10, owner)
		local bags = H.Acquire(Fake.New("Frame"), "c_gear", "x", 0, 0, 10)
		Fake.Fire(mine, "OnClick")
		Fake.Fire(mine, "OnReceiveDrag")
		Fake.Fire(bags, "OnClick")
		assert.same({ "bank:c_gear" }, bankClicks)
		assert.same({ "bank:c_gear" }, bankDrops)
		assert.same({ "c_gear" }, bagsClicks)
	end)

	-- Ruling W3-22 (spec P6). Mutation: "bags" instead of owner.window in either guard.
	it("an error in a bank-owned header's click or drop is trapped as the bank window's", function()
		local owner = { window = "bank", onClick = function() error("click broke") end }
		local h = H.Acquire(Fake.New("Frame"), "bank:c_gear", "x", 0, 0, 10, owner)
		Fake.Fire(h, "OnClick")
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"), "the bags window keeps working")
		SB.SafeMode.Disable("bank")
		owner.onDrop = function() error("drop broke") end
		Fake.Fire(h, "OnReceiveDrag")
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("an error in a header without an owner window is trapped as the bags window's", function()
		H.onClick = function() error("bags click broke") end
		local h = H.Acquire(Fake.New("Frame"), "c_gear", "x", 0, 0, 10, { onClick = H.onClick })
		Fake.Fire(h, "OnClick")
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	it("ReleaseAll(parent) releases only that window's headers, and a reused header forgets its owner", function()
		local bagsChild, bankChild = Fake.New("Frame"), Fake.New("Frame")
		local clicks = 0
		local a = H.Acquire(bankChild, "x", "x", 0, 0, 10, { onClick = function() clicks = clicks + 1 end })
		local b = H.Acquire(bagsChild, "y", "y", 0, 0, 10)
		H.ReleaseAll(bankChild)
		assert.falsy(a.shown)
		assert.truthy(b.shown)
		local reused = H.Acquire(bagsChild, "z", "z", 0, 0, 10)
		assert.equal(a, reused)
		Fake.Fire(reused, "OnClick")
		assert.equal(0, clicks, "the old owner is gone")
	end)
end)

describe("The free tile's number (plan D19)", function()
	local SB
	before_each(function()
		SB = Loader.New(FILES)
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		SetItemButtonTexture, SetItemButtonCount = function() end, function() end
		SetItemButtonQuality, SetItemButtonDesaturated = function() end, function() end
	end)

	after_each(function()
		SetItemButtonTexture, SetItemButtonCount, SetItemButtonQuality, SetItemButtonDesaturated = nil, nil, nil, nil
	end)

	-- Mutation: delete `if info then Buttons.SetFreeCount(button, nil) end` in Buttons.Paint.
	it("SetFreeCount shows a large number on the button; nil hides it; painting an item hides it too", function()
		local button = fakeFrame("ItemButton")
		SB.Buttons.SetFreeCount(button, 12)
		local fs = SB.Buttons.freeCounts[button]
		assert.same({ "12", true }, { tostring(fs.text), fs.shown })
		assert.same({ "CENTER", button, "CENTER", 0, 0 }, fs.points[1])
		SB.Buttons.SetFreeCount(button, nil)
		assert.falsy(fs.shown)
		SB.Buttons.SetFreeCount(button, 11)
		SB.Buttons.Paint(button, nil)
		assert.truthy(fs.shown, "an empty slot keeps its number")
		SB.Buttons.Paint(button, { itemID = 5, icon = 1, count = 1 })
		assert.falsy(fs.shown, "an item never shows the number")
		assert.is_nil(SB.Buttons.freeCounts[fakeFrame("ItemButton")], "no region until a button needs one")
	end)
end)
