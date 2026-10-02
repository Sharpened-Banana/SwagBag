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

	-- Ruling W4-15 (supersedes W3-16): Pawn's "no opinion" (nil) leaves the arrow to the item-level
	-- rule. Mutation: in Ov.Context's ctx.pawn, `return A.PawnUpgrade(record.bag, record.slot) == true`.
	it("with Use Pawn, an item Pawn has no opinion on gets the item-level rule; Pawn's no hides the arrow", function()
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		A.pawn = {}
		SB.Config.Set("overlays.usePawn", true)
		local _, r = draw(0, 3)
		assert.truthy(r.arrow.shown, "no opinion: 285 beats 270")
		A.pawn = { ["0:3"] = false }
		_, r = draw(0, 3)
		assert.falsy(r.arrow.shown, "Pawn says no")
	end)

	-- Ruling W4-15, O1 steps 3-5 and 10. Mutations: delete the SetFont call in text(); Ov.ARROW_SIZE = 14.
	it("legibility: larger outlined text, a larger arrow, a coin with an outline, all inside the button", function()
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		local _, r = draw(0, 3)
		assert.same({ Ov.FONT, 13, "THICKOUTLINE" }, r.topLeft.calls.SetFont)
		assert.same({ Ov.FONT, 11, "THICKOUTLINE" }, r.bind.calls.SetFont)
		assert.same({ 16, 16 }, { r.arrow.w, r.arrow.h })
		assert.equal(Ov.TEXT_WIDTH, r.bottomLeft.w)
		assert.truthy(2 + Ov.TEXT_WIDTH <= 37, "text is clipped inside a 37 px button")
		local _, j = draw(0, 6)
		assert.truthy(j.junk.shown and j.junkShadow.shown)
		assert.same({ 16, 16 }, { j.junk.w, j.junk.h })
		assert.same({ 19, 19 }, { j.junkShadow.w, j.junkShadow.h })
		assert.same(Ov.JUNK_TINT, j.junk.calls.SetVertexColor)
	end)

	-- Mutation: in Ov.Apply, `local corner = top == "" and "TOPLEFT" or "BOTTOMLEFT"` → `local corner = "TOPLEFT"`.
	it("gray gear shows its item level top left and the coin bottom left, so both stay visible", function()
		A.AddItem(900001, { name = "Rusty Sword", classID = A.ITEM_CLASS.Weapon, subclassID = 0,
			equipLoc = "INVTYPE_WEAPON", quality = 0, ilvl = 5, maxStack = 1, bind = "none" })
		A.Put(0, 7, 900001, 1)
		local _, r = draw(0, 7)
		assert.equal("5", r.topLeft.text)
		assert.truthy(r.junk.shown)
		assert.equal("BOTTOMLEFT", r.junk.points[#r.junk.points][1])
	end)

	-- A pooled button is reused for another item: the coin goes back to the top left.
	-- Mutation: in Ov.Apply, delete `r.junkCorner = corner` (the corner is then never moved back).
	it("a button that showed gray gear's coin bottom left puts the next gray item's coin back top left", function()
		A.AddItem(900001, { name = "Rusty Sword", classID = A.ITEM_CLASS.Weapon, subclassID = 0,
			equipLoc = "INVTYPE_WEAPON", quality = 0, ilvl = 5, maxStack = 1, bind = "none" })
		A.Put(0, 7, 900001, 1)
		local b = Fake.New("ItemButton")
		Ov.Apply(b, SB.Items.Describe(0, 7), 0)
		local r = Ov.regions[b]
		assert.equal("BOTTOMLEFT", r.junk.points[#r.junk.points][1])
		Ov.Apply(b, SB.Items.Describe(0, 6), 0) -- the junk fixture: gray, no item level
		assert.equal("", r.topLeft.text)
		assert.truthy(r.junk.shown and r.junkShadow.shown)
		assert.same({ "TOPLEFT", b, "TOPLEFT", 2, -2 }, r.junk.points[#r.junk.points])
	end)

	it("/swagbag overlays title off switches the item level in the bags title off at once", function()
		local refreshed = 0
		SB.BagsWindow = { IsOpen = function() return false end, RefreshTitle = function() refreshed = refreshed + 1 end }
		SB.Slash.Dispatch("overlays title off")
		assert.equal(false, SB.Config.Get("bags.showIlvl"))
		assert.equal(1, refreshed)
		assert.same({ "Overlay title is now off." }, A.Lines())
	end)

	it("one pass over many buttons while a slot is unknown reads the equipment once and schedules one retry", function()
		A.equipped[11] = { unknown = true, equipLoc = "INVTYPE_FINGER" }
		local reads, timers = 0, 0
		local equippedItems, after = A.EquippedItems, A.After
		A.EquippedItems = function() reads = reads + 1 return equippedItems() end
		A.After = function(...) timers = timers + 1 return after(...) end
		for _ = 1, 50 do
			draw(0, 3)
		end
		assert.equal(1, reads)
		assert.equal(1, timers)
		Ov.context = nil -- e.g. an equipment event while the retry is still pending
		for _ = 1, 50 do
			draw(0, 3)
		end
		assert.equal(2, reads)
		assert.equal(1, timers, "no second retry while one is pending")
	end)

	it("an unknown worn item level is read again 1 s later and the open window re-drawn (W3-19)", function()
		A.equipped[11] = { unknown = true, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		local b, r = draw(0, 3)
		assert.falsy(r.arrow.shown, "unknown: no arrow")
		local record = SB.Items.Describe(0, 3)
		SB.BagsWindow = { IsOpen = function() return true end,
			ForEachSlot = function(fn) fn(b, record, 0, 3) end }
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		A.Advance(1)
		assert.truthy(r.arrow.shown, "the retry reads the now-known level")
	end)

	it("the unknown retry fires at most 10 times per episode, and a clean read resets the count", function()
		A.equipped[11] = { unknown = true, equipLoc = "INVTYPE_FINGER" }
		local b = draw(0, 3)
		local record = SB.Items.Describe(0, 3)
		local firings = 0
		SB.BagsWindow = { IsOpen = function() return true end,
			ForEachSlot = function(fn) firings = firings + 1 fn(b, record, 0, 3) end }
		for _ = 1, 15 do
			A.Advance(1)
		end
		assert.equal(10, firings)
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		Ov.context = nil
		Ov.Context() -- a clean read: the count starts again
		A.equipped[11] = { unknown = true, equipLoc = "INVTYPE_FINGER" }
		Ov.context = nil
		firings = 0
		Ov.Context()
		for _ = 1, 3 do
			A.Advance(1)
		end
		assert.equal(3, firings, "a new episode retries again")
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

	it("a gear change re-draws the open bank and guild bank windows too", function()
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		local bankButton, bank = draw(0, 3)
		local guildButton, guild = draw(0, 3)
		local record = SB.Items.Describe(0, 3)
		local function window(button)
			return { IsOpen = function() return true end,
				view = { ForEachSlot = function(fn) fn(button, record, 0, 3) end } }
		end
		SB.BankWindow, SB.GuildBankWindow = window(bankButton), window(guildButton)
		A.equipped[11] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 11)
		A.Advance(0.1)
		assert.same({ false, false }, { bank.arrow.shown, guild.arrow.shown })
	end)

	it("one RefreshAll over bags, bank and guild bank reads the equipment once", function()
		local b1, b2, b3 = Fake.New("ItemButton"), Fake.New("ItemButton"), Fake.New("ItemButton")
		local record = SB.Items.Describe(0, 3)
		local function slots(button)
			return function(fn) fn(button, record, 0, 3) end
		end
		SB.BagsWindow = { IsOpen = function() return true end, ForEachSlot = slots(b1) }
		SB.BankWindow = { IsOpen = function() return true end, view = { ForEachSlot = slots(b2) } }
		SB.GuildBankWindow = { IsOpen = function() return true end, view = { ForEachSlot = slots(b3) } }
		local reads = 0
		local equippedItems = A.EquippedItems
		A.EquippedItems = function() reads = reads + 1 return equippedItems() end
		Ov.context = nil
		Ov.RefreshAll()
		assert.equal(1, reads)
		assert.truthy(Ov.regions[b3])
	end)

	it("Use Pawn never asks Pawn about a guild bank slot; the item-level rule decides there", function()
		A.equipped[11] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.pawn = { ["101:3"] = true }
		SB.Config.Set("overlays.usePawn", true)
		local g = Fake.New("ItemButton")
		Ov.Apply(g, SB.Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = "item:" .. Fixtures.BOE_RING, count = 1 },
			101, 3, 1), 101)
		assert.falsy(Ov.regions[g].arrow.shown, "285 does not beat 300")
	end)
end)
