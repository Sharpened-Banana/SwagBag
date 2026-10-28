-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Overlays drawn on item buttons (spec F9), with fake buttons; and in the open bags window.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/OverlayData.lua", "SwagBag/Engine/IlvlColors.lua",
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
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		A.tracks["item:225001::upgradable"] = { track = "Champion", level = 2, max = 8 }
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 290, equipLoc = "INVTYPE_FINGER" }
		local _, r = draw(0, 3)
		assert.same({ "285", "C2/8", "BoE", true, false },
			{ r.topLeft.text, r.bottomLeft.text, r.bind.text, r.arrow.shown, r.junk.shown })
	end)

	-- Week 6, user request 2: too cluttered with the item level, the track and the badge. Only a value the
	-- user saved is stored, so the new default reaches everyone who never touched it.
	-- Mutation: Config.Defaults overlays.bind = true.
	it("the BoE/WuE badge is off by default; a user who saved it on keeps it", function()
		local _, r = draw(0, 3)
		assert.equal("", r.bind.text)
		SB.Config.Init({ schemaVersion = SB.Config.CURRENT, settings = { overlays = { bind = true } } }, nil)
		local _, saved = draw(0, 3)
		assert.equal("BoE", saved.bind.text)
	end)

	-- Week 6: the badge sat between the two left corners, so with it off nothing needs the space back.
	-- Pins the week-4 Task 11 places and sizes (no code change this week).
	it("with the badge off, the item level and the track keep their corners and sizes", function()
		A.tracks["item:225001::upgradable"] = { track = "Champion", level = 2, max = 8 }
		local _, r = draw(0, 3)
		assert.same({ "285", "C2/8", "" }, { r.topLeft.text, r.bottomLeft.text, r.bind.text })
		local tl, bl = r.topLeft.points[1], r.bottomLeft.points[1]
		assert.same({ "TOPLEFT", 2, -2, "BOTTOMLEFT", 2, 2 }, { tl[1], tl[4], tl[5], bl[1], bl[4], bl[5] })
		assert.same({ 13, 11, 33 }, { Ov.FONT_SIZE, Ov.BIND_SIZE, Ov.TEXT_WIDTH })
		assert.equal(Ov.FONT_SIZE, r.topLeft.calls.SetFont[2])
	end)

	it("a keystone shows +level and its dungeon's short name", function()
		A.dungeons[503] = "Ara-Kara, City of Echoes"
		local _, r = draw(0, 5)
		assert.same({ "+12", "AKCE", "" }, { r.topLeft.text, r.bottomLeft.text, r.bind.text })
	end)

	-- 0.17 item-level colors. Mutation: drop the white reset (a pooled button keeps the last color), or color
	-- the keystone's "+12" as an item level.
	it("the item level takes its step's color; a keystone level stays white", function()
		A.dungeons[503] = "Ara-Kara, City of Echoes"
		SB.Config.Set("overlays.ilvlColors", true)
		SB.Config.Set("overlays.ilvlSteps", "280:green,300:purple")
		local b, r = draw(0, 3) -- the ring, 285
		assert.same({ 0.12, 1, 0 }, r.topLeft.calls.SetTextColor)
		SB.Config.Set("overlays.ilvlSteps", "290:green") -- below the lowest step: white again, same button
		Ov.Apply(b, SB.Items.Describe(0, 3), 0)
		assert.same({ 1, 1, 1 }, Ov.regions[b].topLeft.calls.SetTextColor)
		SB.Config.Set("overlays.ilvlSteps", "1:orange")
		local _, k = draw(0, 5) -- the keystone
		assert.equal("+12", k.topLeft.text)
		assert.same({ 1, 1, 1 }, k.topLeft.calls.SetTextColor)
		SB.Config.Set("overlays.ilvlColors", false)
		local _, off = draw(0, 3)
		assert.same({ 1, 1, 1 }, off.topLeft.calls.SetTextColor)
	end)

	it("changing the colors or the steps re-draws the open windows", function()
		local b, r = draw(0, 3)
		local record = SB.Items.Describe(0, 3)
		SB.BagsWindow = { IsOpen = function() return true end,
			ForEachSlot = function(fn) fn(b, record, 0, 3) end }
		SB.Config.Set("overlays.ilvlSteps", "280:blue")
		SB.Config.Set("overlays.ilvlColors", true)
		assert.same({ 0, 0.44, 0.87 }, r.topLeft.calls.SetTextColor)
		SB.Config.Set("overlays.ilvlSteps", "280:orange")
		assert.same({ 1, 0.5, 0 }, r.topLeft.calls.SetTextColor)
	end)

	-- Final review: a color change re-draws icons (RefreshAll) and asks a layout only where list rows are drawn.
	-- Mutation: request the layout unconditionally (a Categories view regroups for a color change).
	local function fakeWindows(bagsDrawn, bankDrawn, guildDrawn)
		local calls = {}
		local function win(name, drawn, viaView)
			local w = { IsOpen = function() return true end, ForEachSlot = function() end, drawn = drawn,
				RequestLayout = function(why) calls[#calls + 1] = name .. ":" .. why end }
			if viaView then
				return { IsOpen = w.IsOpen, view = w }
			end
			return w
		end
		SB.BagsWindow = win("bags", bagsDrawn)
		SB.BankWindow = win("bank", bankDrawn, true)
		SB.GuildBankWindow = win("guild", guildDrawn, true)
		SB.BankWindow.view.ForEachSlot = function() end
		SB.GuildBankWindow.view.ForEachSlot = function() end
		return calls
	end

	it("an item-level color change asks no layout while categories or sections are drawn", function()
		local calls = fakeWindows("categories", "sections", "grid")
		SB.Config.Set("overlays.ilvlColors", true)
		SB.Config.Set("overlays.ilvlSteps", "280:blue")
		assert.same({}, calls)
	end)

	it("an item-level color change asks a layout from each window drawn as a list", function()
		local calls = fakeWindows("list", "list", "list")
		SB.Config.Set("overlays.ilvlColors", true)
		table.sort(calls)
		assert.same({ "bags:ilvlcolors", "bank:ilvlcolors", "guild:ilvlcolors" }, calls)
	end)

	it("another setting asks no layout, even with lists drawn", function()
		local calls = fakeWindows("list", "list", "list")
		SB.Config.Set("overlays.bind", true)
		assert.same({}, calls)
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
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		SB.Config.Set("overlays.ilvl", false)
		local _, r = draw(0, 3)
		assert.equal("", r.topLeft.text)
		assert.equal("BoE", r.bind.text)
		SB.Slash.Dispatch("overlays bind off")
		SB.Slash.Dispatch("overlays")
		SB.Slash.Dispatch("overlays sparkles on")
		assert.same({ "Overlay bind is now off.",
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, learn on, lock on, uncollected on, pawn"
				.. " off, title on",
			SB.L.OVERLAYS_USAGE }, A.Lines())
		assert.equal(false, SB.Config.Get("overlays.bind"))
	end)

	it("ilvlcolors on fills the steps from the equipped level; off keeps them", function()
		A.avgIlvl = 684.7
		SB.Slash.Dispatch("ilvlcolors on")
		assert.equal(true, SB.Config.Get("overlays.ilvlColors"))
		assert.equal("684:green,694:blue,704:purple", SB.Config.Get("overlays.ilvlSteps"))
		SB.Slash.Dispatch("ilvlcolors off")
		assert.equal(false, SB.Config.Get("overlays.ilvlColors"))
		assert.equal("684:green,694:blue,704:purple", SB.Config.Get("overlays.ilvlSteps"))
		A.avgIlvl = 700
		SB.Slash.Dispatch("ilvlcolors on")
		assert.equal("684:green,694:blue,704:purple", SB.Config.Get("overlays.ilvlSteps"), "not refilled")
		SB.Slash.Dispatch("ilvlcolors maybe")
		assert.same({ SB.L.ILVLCOLORS_ON, SB.L.ILVLCOLORS_OFF, SB.L.ILVLCOLORS_ON, SB.L.ILVLCOLORS_USAGE }, A.Lines())
	end)

	it("ilvlcolors on with no equipped level leaves the steps empty and says to set them by hand", function()
		A.avgIlvl = nil
		SB.Slash.Dispatch("ilvlcolors on")
		assert.equal(true, SB.Config.Get("overlays.ilvlColors"))
		assert.equal("", SB.Config.Get("overlays.ilvlSteps"))
		assert.same({ SB.L.ILVLCOLORS_ON, SB.L.ILVLCOLORS_SET_BY_HAND }, A.Lines())
	end)

	it("read-only: ilvlcolors changes nothing and says so", function()
		A.avgIlvl = 684
		SB.Config.readOnly = true
		SB.Slash.Dispatch("ilvlcolors on")
		assert.same({ SB.L.SETTINGS_READONLY }, A.Lines())
		assert.equal(false, SB.Config.Get("overlays.ilvlColors"))
		assert.equal("", SB.Config.Get("overlays.ilvlSteps"))
	end)

	-- Week 7 (user pick 3). Mutations: in Overlays.Apply, `local glow = on("learn") and d.learn ~= nil` ->
	-- `d.learn ~= nil` (the switch is ignored); or drop `learn = SB.Collections and ...` from the context.
	it("a green glow on an item to open or learn; overlays learn off hides it; an empty slot never glows", function()
		SB.Collections = { Learn = function(r)
			return r.slot == 1 and "open" or nil
		end }
		local _, r = draw(0, 1)
		assert.truthy(r.glow.shown)
		assert.same({ 0.35, 1, 0.35 }, r.glow.calls.SetVertexColor)
		local _, plain = draw(0, 2)
		assert.falsy(plain.glow.shown, "a flask: nothing to open or learn")
		SB.Slash.Dispatch("overlays learn off")
		local _, off = draw(0, 1)
		assert.falsy(off.glow.shown)
		local b = Fake.New("ItemButton")
		SB.Slash.Dispatch("overlays learn on")
		Ov.Apply(b, SB.Items.Describe(0, 1), 0)
		Ov.Apply(b, nil, 0)
		assert.falsy(Ov.regions[b].glow.shown, "the slot emptied: no glow")
	end)

	-- Week 7 (user pick 5). Mutation: in Overlays.Apply, `show(r.lock, on("lock") and d.locked)` -> `d.locked`.
	it("a small lock on an item the user locked; overlays lock off hides it", function()
		SB.Locks = { Has = function(id) return id == Fixtures.FLASK end }
		local _, flask = draw(0, 2)
		local _, potion = draw(0, 1)
		assert.same({ true, false }, { flask.lock.shown, potion.lock.shown })
		assert.same({ "LEFT", 10 }, { flask.lock.points[1][1], flask.lock.w })
		SB.Slash.Dispatch("overlays lock off")
		local _, off = draw(0, 2)
		assert.falsy(off.lock.shown)
	end)

	-- Week 7 (user pick 7). Mutations: Ov.IsWorth ignores Ov.worthMin (always nil: no glow); or the
	-- BANKFRAME_CLOSED handler keeps Ov.worthMin.
	it("at the bank items worth 100g or more glow gold (their stack value); closing the bank ends it", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Prices.lua")
		A.items[Fixtures.HEALING_POTION].sellPrice = 300000 -- 30g each, 5 in the stack: 150g
		A.items[Fixtures.FLASK].sellPrice = 400000 -- 40g each, 2: 80g
		local drawn = {}
		SB.BankWindow = { interaction = true, IsOpen = function() return false end }
		SB.BagsWindow = { IsOpen = function() return true end, RefreshTitle = function() end, ForEachSlot = function(fn)
			for slot = 1, 2 do
				drawn[slot] = drawn[slot] or Fake.New("ItemButton")
				fn(drawn[slot], SB.Items.Describe(0, slot), 0, slot)
			end
		end }
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		A.Advance(Ov.WORTH_DELAY)
		assert.equal(1000000, Ov.worthMin)
		assert.same({ true, false }, { Ov.regions[drawn[1]].glow.shown, Ov.regions[drawn[2]].glow.shown })
		assert.same({ 1, 0.82, 0 }, Ov.regions[drawn[1]].glow.calls.SetVertexColor)
		SB.BankWindow.interaction = false
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.falsy(Ov.regions[drawn[1]].glow.shown)
	end)

	-- Week 7. Mutation: in Overlays.Apply, the tint `worth and Ov.WORTH_TINT or Ov.LEARN_TINT` ->
	-- `d.learn and Ov.LEARN_TINT or Ov.WORTH_TINT` (green would win at the bank).
	it("gold at the bank wins over green; a price the game will not give (secret, missing) never glows", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Prices.lua")
		SB.Collections = { Learn = function() return "learn" end }
		A.items[Fixtures.HEALING_POTION].sellPrice = 300000
		Ov.worthMin = 1000000
		local _, potion = draw(0, 1)
		assert.same({ true, { 1, 0.82, 0 } }, { potion.glow.shown, potion.glow.calls.SetVertexColor })
		local _, flask = draw(0, 2)
		assert.same({ true, { 0.35, 1, 0.35 } }, { flask.glow.shown, flask.glow.calls.SetVertexColor }, "no price: green")
		Ov.worthMin = nil
		local _, after = draw(0, 1)
		assert.same({ 0.35, 1, 0.35 }, after.glow.calls.SetVertexColor)
	end)

	-- P2. Mutation: /swagbag worth top accepts 0 (no item would ever be the top 0%).
	it("/swagbag worth shows, sets a gold amount, a top percent or off; wrong forms and read-only refuse", function()
		SB.Slash.Dispatch("worth")
		SB.Slash.Dispatch("worth 250")
		SB.Slash.Dispatch("worth top 5")
		SB.Slash.Dispatch("worth top 0")
		SB.Slash.Dispatch("worth lots")
		SB.Slash.Dispatch("worth off")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("worth 100")
		local L = SB.L
		assert.same({ L.WORTH_STATE:format("items worth 100g or more a stack"), "Gold glow at the bank: items worth 250g or"
			.. " more a stack.", "Gold glow at the bank: your most valuable 5% of items.", L.WORTH_USAGE, L.WORTH_USAGE,
			"Gold glow at the bank: off.", L.SETTINGS_READONLY }, A.Lines())
		assert.same({ "off", 250, 5 }, { SB.Config.Get("prices.worth"), SB.Config.Get("prices.worthGold"),
			SB.Config.Get("prices.worthTop") })
	end)

	-- Week 7 (user pick 9). Mutations: in Overlays.Apply, `or (d.uncollected ~= nil and not green)` ->
	-- `or d.uncollected ~= nil` (a toy would show the star and the glow); or `show(r.star, on("uncollected") and
	-- star)` -> `show(r.star, star)`; or (ruling R10) `local green = glow and not worth` -> `local green =
	-- on("learn") and d.learn ~= nil` (under the gold glow at the bank the toy would show no star).
	it("a star on gear whose look is not collected; on a toy, mount or pet only while the green glow is not drawn", function()
		SB.Collections = { Learn = function(r)
			return r.slot == 2 and "learn" or nil
		end, Uncollected = function(r)
			return (r.slot == 3 and "appearance") or (r.slot == 2 and "toy") or nil
		end }
		local _, ring = draw(0, 3)
		local _, toy = draw(0, 2)
		local _, potion = draw(0, 1)
		assert.same({ true, false, false }, { ring.star.shown, toy.star.shown, potion.star.shown })
		assert.same({ "RIGHT", "*" }, { ring.star.points[1][1], ring.star.text })
		Loader.LoadFile(SB, "SwagBag/Engine/Prices.lua")
		A.items[Fixtures.FLASK].sellPrice = 100
		Ov.worthMin = 1 -- at the bank the toy's stack is worth money: it glows gold, not green, so the star shows too
		local _, toyAtBank = draw(0, 2)
		assert.same({ true, { 1, 0.82, 0 }, true },
			{ toyAtBank.glow.shown, toyAtBank.glow.calls.SetVertexColor, toyAtBank.star.shown })
		Ov.worthMin = nil
		SB.Slash.Dispatch("overlays learn off")
		local _, toyNoGlow = draw(0, 2)
		assert.truthy(toyNoGlow.star.shown, "the glow is off: the star says it instead")
		SB.Slash.Dispatch("overlays uncollected off")
		local _, off = draw(0, 3)
		assert.falsy(off.star.shown)
	end)

	-- Fix round 1. Mutation: in Overlays.Apply's region setup, put the lock back at ("TOP", button, "TOP", 0, -1)
	-- with size 14 (it then covers the item level and the upgrade arrow).
	it("the lock sits where no other corner overlay is (37 px button, rects in pixels from its top left)", function()
		SB.Locks = { Has = function() return true end }
		local _, r = draw(0, 3)
		local W = 37
		-- A rect {x1, y1, x2, y2} (y down) for a region anchored at one of the button's points.
		local function rect(region, w, h)
			local pt, _, _, x, y = unpack(region.points[1])
			local x1 = ({ LEFT = 0, TOPLEFT = 0, BOTTOMLEFT = 0, TOPRIGHT = W - w, BOTTOMRIGHT = W - w })[pt] + x
			local y1 = ({ LEFT = (W - h) / 2, TOPLEFT = 0, TOPRIGHT = 0, BOTTOMLEFT = W - h, BOTTOMRIGHT = W - h })[pt] - y
			return { x1, y1, x1 + w, y1 + h }
		end
		local function hit(a, b)
			return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
		end
		local lock = rect(r.lock, r.lock.w, r.lock.h)
		-- Text boxes: 3 digits of the 13 px font is ~22 px wide, ~11 px of glyph high (the line's spare room is empty).
		local others = {
			ilvl = rect(r.topLeft, 22, 11), track = rect(r.bottomLeft, 22, 11), arrow = rect(r.arrow, r.arrow.w, r.arrow.h),
			-- Blizzard's own stack count: bottom right, two digits.
			count = { W - 2 - 14, W - 2 - 11, W - 2, W - 2 },
			-- The junk coin never shows on a locked item (ruling R11), so it is not in this list.
		}
		for name, o in pairs(others) do
			assert.falsy(hit(lock, o), "the lock overlaps the " .. name)
		end
		assert.truthy(lock[1] >= 0 and lock[3] <= W and lock[2] >= 0 and lock[4] <= W, "inside the button")
	end)

	-- Final review fix 3. Mutation: in Overlays, STAR_SIZE back to 18 and STAR_Y to 0 (the star then sits across
	-- the upgrade arrow and the stack count).
	it("the star sits where no other overlay is: not on the upgrade arrow, the stack count, the lock or the corner texts", function()
		SB.Collections = { Uncollected = function() return "appearance" end }
		SB.Locks = { Has = function() return true end }
		local _, r = draw(0, 3)
		local W = 37
		local function rect(region, w, h)
			local pt, _, _, x, y = unpack(region.points[1])
			local x1 = ({ LEFT = 0, TOPLEFT = 0, BOTTOMLEFT = 0, RIGHT = W - w, TOPRIGHT = W - w, BOTTOMRIGHT = W - w })[pt] + x
			local y1 = ({ LEFT = (W - h) / 2, RIGHT = (W - h) / 2, TOPLEFT = 0, TOPRIGHT = 0, BOTTOMLEFT = W - h,
				BOTTOMRIGHT = W - h })[pt] - y
			return { x1, y1, x1 + w, y1 + h }
		end
		local function hit(a, b)
			return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
		end
		-- The star glyph: about as wide as its font size and 0.6 of it high (an asterisk fills the top of its line).
		local star = rect(r.star, Ov.STAR_SIZE, Ov.STAR_SIZE * 0.6)
		local others = {
			ilvl = rect(r.topLeft, 22, 11), track = rect(r.bottomLeft, 22, 11), arrow = rect(r.arrow, r.arrow.w, r.arrow.h),
			count = { W - 2 - 14, W - 2 - 11, W - 2, W - 2 },
			lock = rect(r.lock, r.lock.w, r.lock.h),
		}
		for name, o in pairs(others) do
			assert.falsy(hit(star, o), "the star overlaps the " .. name)
		end
		assert.truthy(star[1] >= 0 and star[3] <= W and star[2] >= 0 and star[4] <= W, "inside the button")
	end)

	-- Final review fix 4 (wiring). Mutation: in Overlays.Context, `protected` always returns false.
	it("the junk coin follows the vendor's rule: hidden while Vendor.Protected says yes", function()
		local _, shown = draw(0, 6)
		assert.truthy(shown.junk.shown, "the Broken Tooth is gray junk")
		SB.Vendor = { Protected = function() return true end }
		local _, hidden = draw(0, 6)
		assert.falsy(hidden.junk.shown)
	end)

	-- Week 8. Mutation: in Overlays.Context, call SB.Vendor.Protected(record) without `true`.
	it("the junk coin asks the vendor's rule in its cached form (no collection call per draw)", function()
		local fast
		SB.Vendor = { Protected = function(_, f) fast = f return false end }
		draw(0, 6)
		assert.equal(true, fast)
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

-- Forever Stage A, Task 3: no upgrade track and no keystone overlay on WoW Forever, drawn or offered.
describe("Overlays on WoW Forever", function()
	local SB, A, Ov
	before_each(function()
		SB = Loader.New(FILES, { flavor = "forever" })
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
		return Ov.regions[b]
	end

	-- Mutation: no Allows in Overlays' on().
	it("on Forever a keystone and an upgrade track draw nothing", function()
		A.tracks["item:225001::upgradable"] = { track = "Champion", level = 2, max = 8 }
		A.dungeons[503] = "Ara-Kara, City of Echoes"
		local gear = draw(0, 3)
		assert.same({ "285", "" }, { gear.topLeft.text, gear.bottomLeft.text })
		local key = draw(0, 5)
		assert.same({ "", "" }, { key.topLeft.text, key.bottomLeft.text })
	end)

	-- Mutation: the slash listing walks Ov.NAMES.
	it("on Forever /swagbag overlays lists no track or keystone", function()
		SB.Slash.Dispatch("overlays")
		assert.same({ "Overlays: ilvl on, upgrade on, junk on, bind off, learn on, lock on, uncollected on, pawn off,"
			.. " title on" }, A.Lines())
		assert.same({ "ilvl", "upgrade", "junk", "bind", "learn", "lock", "uncollected" }, Ov.Names())
	end)

	-- Mutation: the slash command checks only that the name is known.
	it("on Forever /swagbag overlays track on answers left out and saves nothing", function()
		SB.Config.Set("overlays.track", false)
		SB.Slash.Dispatch("overlays track on")
		SB.Slash.Dispatch("overlays keystone off")
		assert.same({ SB.L.FOREVER_LEFT_OUT:format("track"), SB.L.FOREVER_LEFT_OUT:format("keystone") }, A.Lines())
		assert.equal(false, SB.Config.Get("overlays.track"))
		assert.equal(true, SB.Config.Get("overlays.keystone"))
	end)
end)
