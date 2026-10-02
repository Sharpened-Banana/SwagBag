-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The list view's rows (UI/ListRows.lua): texts per column, one plain row per slot button,
-- placed and hidden by the window, dimmed with its button, and a tooltip that points at the icon.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("ListRows", function()
	local SB, A, LR, rows, parent, flashed
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/Engine/Sort.lua")
		SB.Buttons = { DIM_ALPHA = 0.2, PLACEHOLDER_ALPHA = 0.5 }
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		LR = SB.ListRows
		parent = Fake.New("Frame", UIParent)
		flashed = {}
		rows = LR.New(parent, "bags", function(text) flashed[#flashed + 1] = text end)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function record(slot)
		return SB.Items.Describe(0, slot)
	end

	it("texts: name, count (blank for one), item level for gear only, value of the stack", function()
		A.items[Fixtures.HEALING_POTION].sellPrice = 200
		local t = LR.Texts(record(1))
		assert.same({ name = "Algari Healing Potion", count = "5", ilvl = "", value = "10s" }, t)
		local ring = LR.Texts(record(3))
		assert.equal("", ring.count)
		assert.equal("285", ring.ilvl)
	end)

	it("texts: with no quality colour from the client the name takes its link's |c colour; a loading item shows its link's name", function()
		local r = { name = "Band", link = "|cffa335ee|Hitem:225001::|h[Band]|h|r", count = 1 }
		assert.equal("|cffa335eeBand|r", LR.Texts(r).name)
		assert.equal("|cffa335eeLate|r", LR.Texts({ link = "|cffa335ee|Hitem:1|h[Late]|h|r", pending = true }).name)
		assert.equal(SB.L.LIST_LOADING, LR.Texts({ count = 1, pending = true }).name)
		assert.equal("Plain", LR.Texts({ name = "Plain", link = "|Hitem:1|h[Plain]|h", count = 1 }).name)
	end)

	-- F5. Mutation: in coloured(), use the link's colour before record.quality.
	it("texts: the name's colour comes from record.quality through the Adapter, before the link's", function()
		A.qualityColors[4] = { 163 / 255, 53 / 255, 238 / 255 }
		local r = { name = "Band", quality = 4, link = "|cff0070dd|Hitem:225001::|h[Band]|h|r", count = 1 }
		assert.equal("|cffa335eeBand|r", LR.Texts(r).name)
		A.qualityColors[4] = { 1, 1, 1 }
		assert.equal("|cffffffffBand|r", LR.Texts(r).name)
		A.qualityColors[4] = { 0, 0, 0 }
		assert.equal("|cff000000Band|r", LR.Texts(r).name)
	end)

	-- F5: 12.x links colour with |cnIQ<n>:, which has no hex to parse. Mutation: drop the |cnIQ branch.
	it("texts: a |cnIQ<n>: link with no record.quality still gets its quality colour; none known, plain", function()
		A.qualityColors[4] = { 163 / 255, 53 / 255, 238 / 255 }
		local link = "|cnIQ4:|Hitem:225001::|h[Band]|h|r"
		assert.equal("|cffa335eeBand|r", LR.Texts({ link = link, count = 1 }).name)
		assert.equal("|cffa335eeBand|r", LR.Texts({ name = "Band", quality = 4, link = link, count = 1 }).name)
		A.qualityColors[4] = nil
		assert.equal("Band", LR.Texts({ link = link, count = 1 }).name)
	end)

	it("texts: an empty slot, and the free tile with its number", function()
		assert.equal(SB.L.LIST_EMPTY, LR.Texts(nil).name)
		assert.equal(SB.L.LIST_FREE:format(10), LR.Texts(nil, 10).name)
	end)

	it("columns fill the row: name on the left, count, item level and value on the right", function()
		local c = LR.Columns(440)
		assert.equal(0, c.name.x)
		assert.equal(440, c.value.x + c.value.width)
		assert.truthy(c.count.x > c.name.width)
	end)

	-- Mutation: in R.Place, create a new row on every call instead of reusing R.rows[button].
	it("one row per slot button, made on first use, placed where the window says and hidden when not shown", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		local row = rows.rows[button]
		assert.truthy(row.shown)
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 32, -40 }, row.points[1])
		assert.equal("Algari Healing Potion", row.name.text)
		local n = #Fake.created
		rows.Place(button, 32, -66, 400, 24, true)
		assert.equal(n, #Fake.created, "no new frame for a row that exists")
		rows.Place(button, 32, -66, 400, 24, false)
		assert.falsy(row.shown)
	end)

	-- AC5.1 in the list view. Mutation: in R.Place, always SetAlpha(1).
	it("a dimmed row stays dimmed when it is placed again; undimming restores it", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		rows.SetDimmed(button, true)
		assert.equal(0.2, rows.rows[button].alpha)
		rows.Place(button, 32, -66, 400, 24, true)
		assert.equal(0.2, rows.rows[button].alpha)
		rows.SetDimmed(button, false)
		assert.equal(1, rows.rows[button].alpha)
	end)

	it("IsMouseOver is true only for a shown row under the mouse", function()
		local button = Fake.New("ItemButton", parent)
		assert.falsy(rows.IsMouseOver(button))
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		rows.rows[button].mouseOver = true
		assert.truthy(rows.IsMouseOver(button))
		rows.Place(button, 32, -40, 400, 24, false)
		assert.falsy(rows.IsMouseOver(button))
	end)

	it("ghost rows for placeholders are pooled, and the extra ones hide; HideAll hides every row", function()
		rows.Ghosts({ { x = 32, y = -40 }, { x = 32, y = -66 } }, 400, 24)
		assert.equal(2, #rows.ghosts)
		assert.equal(SB.L.LIST_GONE, rows.ghosts[1].name.text)
		rows.Ghosts({ { x = 32, y = -40 } }, 400, 24)
		assert.truthy(rows.ghosts[1].shown)
		assert.falsy(rows.ghosts[2].shown)
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		rows.HideAll()
		assert.falsy(rows.rows[button].shown)
		assert.falsy(rows.ghosts[1].shown)
	end)

	-- P2: hovering a row answers. Mutation: in itemTip, drop the hint argument.
	it("hovering a row shows the item's tooltip with a line pointing at the icon; an empty row says what it is", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		Fake.Fire(rows.rows[button], "OnEnter")
		assert.same({ owner = rows.rows[button], bag = 0, slot = 1, hint = SB.L.LIST_ROW_TIP }, A.slotTip)
		local empty = Fake.New("ItemButton", parent)
		rows.Paint(empty, 0, 9, nil)
		rows.Place(empty, 32, -66, 400, 24, true)
		Fake.Fire(rows.rows[empty], "OnEnter")
		assert.equal(SB.L.LIST_EMPTY_TIP, GameTooltip.text)
	end)

	-- F3 (D23 precedent): a hover is cosmetic, so one glitch never takes the bags away.
	-- Mutation: trap the row scripts under the window argument ("bags").
	it("an error in a row's tooltip is trapped as \"none\", whatever the window (never a Lua error)", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		A.SlotTooltip = function() error("tooltip broke") end
		Fake.Fire(rows.rows[button], "OnEnter")
		assert.equal("list.rowTip", SB.ErrorTrap.Recent()[1].label)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		A.SlotTooltip = function() end
		GameTooltip.Hide = function() error("hide broke") end
		Fake.Fire(rows.rows[button], "OnLeave")
		local recent = SB.ErrorTrap.Recent()
		assert.equal("list.rowTipHide", recent[#recent].label)
		assert.equal("none", recent[#recent].window)
	end)

	-- F24 (P2): a click on a row's text answers. Mutation: drop the OnMouseUp script.
	it("a click on a row's text flashes where to click, and never touches the button", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		Fake.Fire(rows.rows[button], "OnMouseUp", "RightButton")
		assert.same({ SB.L.LIST_ROW_CLICK }, flashed)
		assert.equal("Click the icon on the left to use the item.", SB.L.LIST_ROW_CLICK)
		local empty = Fake.New("ItemButton", parent)
		rows.Paint(empty, 0, 9, nil)
		rows.Place(empty, 32, -66, 400, 24, true)
		Fake.Fire(rows.rows[empty], "OnMouseUp", "LeftButton")
		assert.equal(SB.L.LIST_EMPTY_TIP, flashed[2])
	end)

	it("a click on a row's text is trapped as \"none\" when the window's flash errors; no callback is fine", function()
		local button = Fake.New("ItemButton", parent)
		local bad = LR.New(parent, "bags", function() error("flash broke") end)
		bad.Paint(button, 0, 1, record(1))
		bad.Place(button, 32, -40, 400, 24, true)
		Fake.Fire(bad.rows[button], "OnMouseUp", "LeftButton")
		assert.equal("list.rowClick", SB.ErrorTrap.Recent()[1].label)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		local quiet = LR.New(parent, "bags")
		quiet.Paint(button, 0, 1, record(1))
		quiet.Place(button, 32, -40, 400, 24, true)
		Fake.Fire(quiet.rows[button], "OnMouseUp", "LeftButton")
	end)

	it("creates only plain frames (never an item or secure button), also in combat", function()
		A.combat = true
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		rows.Ghosts({ { x = 32, y = -66 } }, 400, 24)
		for _, f in ipairs(Fake.created) do
			assert.equal("Frame", f.kind)
		end
	end)
end)
