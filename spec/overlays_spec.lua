-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Overlays drawn on item buttons (spec F9), with fake buttons; and in the open bags window.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/OverlayData.lua",
}

describe("Overlays (spec F9)", function()
	local SB, A, Ov
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Overlays.lua")
		Ov = SB.Overlays
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function draw(bag, slot)
		local b = Fake.New("ItemButton")
		Ov.Apply(b, SB.Items.Describe(bag, slot), bag)
		return b, Ov.regions[b]
	end

	it("gear: item level top left, track bottom left, BoE badge, upgrade arrow", function()
		A.tracks["item:225001::upgradable"] = { track = "Champion", level = 2, max = 8 }
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 290, equipLoc = "INVTYPE_FINGER" }
		local _, r = draw(0, 3)
		assert.same({ "285", "C2/8", "BoE", true, false },
			{ r.topLeft.text, r.bottomLeft.text, r.bind.text, r.arrow.shown, r.junk.shown })
	end)

	it("a keystone shows +level and its dungeon's short name", function()
		A.dungeons[503] = "Ara-Kara, City of Echoes"
		local _, r = draw(0, 5)
		assert.same({ "+12", "AKCE", "" }, { r.topLeft.text, r.bottomLeft.text, r.bind.text })
	end)

	it("a junk coin on gray items; nothing on a potion", function()
		local _, junk = draw(0, 6)
		assert.truthy(junk.junk.shown)
		local _, potion = draw(0, 1)
		assert.same({ "", "", "", false, false },
			{ potion.topLeft.text, potion.bottomLeft.text, potion.bind.text, potion.arrow.shown, potion.junk.shown })
	end)

	it("a slot that empties clears its overlays; an empty slot that never had an item makes no regions", function()
		local b = draw(0, 3)
		Ov.Apply(b, nil, 0)
		local r = Ov.regions[b]
		assert.same({ "", "", false }, { r.topLeft.text, r.bind.text, r.arrow.shown })
		local empty = Fake.New("ItemButton")
		Ov.Apply(empty, nil, 0)
		assert.is_nil(Ov.regions[empty])
	end)

	it("an empty reagent-bag slot is tinted so it stands out in Free; an item there is not", function()
		A.SetBagSize(5, 4)
		local b = Fake.New("ItemButton")
		Ov.Apply(b, nil, 5)
		assert.truthy(Ov.regions[b].reagent.shown)
		A.Put(5, 1, Fixtures.HERB, 5)
		Ov.Apply(b, SB.Items.Describe(5, 1), 5)
		assert.falsy(Ov.regions[b].reagent.shown)
		local other = Fake.New("ItemButton")
		Ov.Apply(other, SB.Items.Describe(0, 1), 0)
		Ov.Apply(other, nil, 0)
		assert.falsy(Ov.regions[other].reagent.shown)
	end)

	it("each overlay has its own switch; /swagbag overlays lists and switches them", function()
		SB.Config.Set("overlays.ilvl", false)
		local _, r = draw(0, 3)
		assert.equal("", r.topLeft.text)
		assert.equal("BoE", r.bind.text)
		SB.Slash.Dispatch("overlays bind off")
		SB.Slash.Dispatch("overlays")
		SB.Slash.Dispatch("overlays sparkles on")
		assert.same({ "Overlay bind is now off.",
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, pawn off, title on",
			SB.L.OVERLAYS_USAGE }, A.Lines())
		assert.equal(false, SB.Config.Get("overlays.bind"))
	end)

	it("a gear change re-draws the arrows of the open windows, once after the last slot event", function()
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		local b, r = draw(0, 3)
		assert.truthy(r.arrow.shown)
		local record = SB.Items.Describe(0, 3)
		local passes = 0
		SB.BagsWindow = { IsOpen = function() return true end,
			ForEachSlot = function(fn) passes = passes + 1 fn(b, record, 0, 3) end }
		A.equipped[11] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 11)
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 12)
		assert.truthy(r.arrow.shown, "not yet")
		A.Advance(0.1)
		assert.falsy(r.arrow.shown)
		assert.equal(1, passes)
	end)

	it("with Use Pawn, Pawn decides the arrow for bag items", function()
		A.equipped[11] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.pawn = { ["0:3"] = true }
		SB.Slash.Dispatch("overlays pawn on")
		local _, r = draw(0, 3)
		assert.truthy(r.arrow.shown, "Pawn says upgrade, although 285 does not beat 300")
		assert.same({ "Overlay pawn is now on." }, A.Lines())
		A.pawn = nil
		A.printed = {}
		SB.Slash.Dispatch("overlays pawn on")
		assert.same({ "Overlay pawn is now on.", SB.L.OVERLAYS_NO_PAWN }, A.Lines())
	end)

	it("/swagbag overlays title off switches the item level in the bags title off at once", function()
		local refreshed = 0
		SB.BagsWindow = { IsOpen = function() return false end, RefreshTitle = function() refreshed = refreshed + 1 end }
		SB.Slash.Dispatch("overlays title off")
		assert.equal(false, SB.Config.Get("bags.showIlvl"))
		assert.equal(1, refreshed)
		assert.same({ "Overlay title is now off." }, A.Lines())
	end)

	it("a context with an unknown worn item level is never kept: it is read again 1 s later (W3-19)", function()
		A.equipped[11] = { unknown = true, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		local b, r = draw(0, 3)
		assert.falsy(r.arrow.shown, "unknown: no arrow")
		local record = SB.Items.Describe(0, 3)
		SB.BagsWindow = { IsOpen = function() return true end,
			ForEachSlot = function(fn) fn(b, record, 0, 3) end }
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		Ov.Apply(b, record, 0)
		assert.truthy(r.arrow.shown, "the unknown read was not kept: the next draw sees the known level")
		r.arrow:Hide()
		A.Advance(1)
		assert.truthy(r.arrow.shown, "the retry also re-draws the open window")
	end)

	it("the unknown retry stops after 10 passes per episode, and a clean read resets the count", function()
		A.equipped[11] = { unknown = true, equipLoc = "INVTYPE_FINGER" }
		local b = draw(0, 3)
		local record = SB.Items.Describe(0, 3)
		local passes = 0
		SB.BagsWindow = { IsOpen = function() return true end,
			ForEachSlot = function(fn) passes = passes + 1 fn(b, record, 0, 3) end }
		for _ = 1, 15 do
			A.Advance(1)
		end
		assert.equal(10, passes)
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		Ov.context = nil
		Ov.Context() -- a clean read: the counter starts again
		Ov.context = nil
		A.equipped[11] = { unknown = true, equipLoc = "INVTYPE_FINGER" }
		passes = 0
		Ov.Context()
		for _ = 1, 3 do
			A.Advance(1)
		end
		assert.truthy(passes >= 3, "a new episode retries again")
	end)

	it("a missing atlas falls back to a flat colour; a found atlas does not", function()
		local function button(found)
			local b = Fake.New("ItemButton")
			b.CreateTexture = function(self)
				local t = Fake.New("Texture", self)
				t.SetAtlas = function() return found end
				return t
			end
			return b
		end
		local missing, found = button(false), button(true)
		Ov.Apply(missing, SB.Items.Describe(0, 3), 0)
		Ov.Apply(found, SB.Items.Describe(0, 3), 0)
		assert.truthy(Ov.regions[missing].arrow.calls.SetColorTexture)
		assert.is_nil(Ov.regions[found].arrow.calls.SetColorTexture)
	end)

	it("/swagbag overlays says so when the saved settings are read-only", function()
		SB.Config.readOnly = true
		SB.Slash.Dispatch("overlays bind off")
		assert.same({ SB.L.SETTINGS_READONLY }, A.Lines())
	end)
end)
