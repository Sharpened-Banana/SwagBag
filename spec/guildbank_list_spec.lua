-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 8: the guild bank window's list view over the real engine and GroupView: one group per tab, one row per
-- slot beside SwagBag's own guild slot button (scaled, never made for it), each tab's empty slots as one free
-- row, the guild slot's tooltip, the shared column order, search and F6.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("GuildBankWindow list view (week 8)", function()
	local SB, A, GW, GV
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		SB.Config.Set("bags.newAlways", true) -- these tests were written with New always drawn (0.13.1: it hides while empty by default)
		Fixtures.Install(A)
		Fake.Install()
		Env.PaintGlobals()
		A.frames.GuildBankFrame = Fake.New("Frame", UIParent)
		A.guild.tabs = { { tab = 1, name = "Mats", withdrawals = 5 }, { tab = 2, name = "Pots", withdrawals = 5 } }
		A.items[Fixtures.HEALING_POTION].sellPrice = 100 -- the stack of 5: 500
		A.items[Fixtures.FLASK].sellPrice = 1000 -- one: 1000
		A.guild.slots = { [1] = { [1] = { itemID = Fixtures.HERB, count = 20 }, [2] = { itemID = Fixtures.ORE, count = 5 } },
			[2] = { [1] = { itemID = Fixtures.HEALING_POTION, count = 5 }, [2] = { itemID = Fixtures.FLASK, count = 1 } } }
		A.guild.current = 1
		GW = Env.LoadGuild(SB)
		GV = SB.GroupView
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openVault()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
		for _ = 1, 4 do -- the client answers each tab's query
			SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
			A.Advance(0.06)
		end
		A.Advance(GV.RETRY)
	end

	local function button(tab, slot)
		return SB.GuildButtons.Get(tab, slot)
	end

	local function row(tab, slot)
		return GW.rows.rows[button(tab, slot)]
	end

	local function y(tab, slot)
		local b = button(tab, slot)
		local p = b.points[#b.points]
		return math.floor(p[5] * b.scale * 1000 + 0.5) / 1000
	end

	local function labels()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	-- Mutation: in the guild window's GroupView cfg, freeTile returns false (98-slot tabs: one row per empty slot).
	it("each tab's sections, one row per slot beside its button at row size; a tab's empty slots are one free row",
		function()
			SB.Config.Set("guildBank.view", "list")
			openVault()
			assert.equal("list", GW.view.drawn)
			assert.same({ "- New (0)", "- Herbs (1)", "- Ore (1)", "- Free (96)" }, { unpack(labels(), 3, 6) })
			assert.equal(GV.LIST_ROW / GV.SLOT, button(1, 1).scale)
			assert.equal(y(1, 1), row(1, 1).points[1][5])
			assert.same({ "Mycobloom", "20" }, { row(1, 1).name.text, row(1, 1).count.text })
			assert.equal(SB.L.LIST_FREE:format(96), row(1, 3).name.text, "the first empty slot is the free row")
			assert.falsy(button(1, 4).shown, "every other empty slot is a hidden spare")
			assert.truthy(GW.columnsBar.frame.shown)
		end)

	-- Mutation: in GuildBankWindow.lua, drop the rows' `tip = function ... end` (the row would ask for a bag slot's
	-- tooltip at bag 101).
	it("a row's tooltip is the guild slot's; a click on its text says to right-click the icon", function()
		SB.Config.Set("guildBank.view", "list")
		openVault()
		Fake.Fire(row(1, 2), "OnEnter")
		assert.same({ 1, 2 }, { A.tooltip.tab, A.tooltip.slot })
		assert.is_nil(A.slotTip)
		Fake.Fire(row(1, 2), "OnMouseUp")
		assert.equal(SB.L.LIST_GUILD_ROW_CLICK, GW.frame.title.text)
	end)

	-- Mutation: in GuildBankWindow.lua, VIEW_NEXT's `sections = "list"` -> `sections = "grid"`.
	it("the view button shows categories, list and grid in turn; a list sorts by a column click (one shared order)",
		function()
			openVault()
			assert.equal(SB.L.VIEW_TO_LIST, GW.viewButton.text)
			Fake.Fire(GW.viewButton, "OnClick")
			assert.same({ "list", SB.L.GUILD_VIEW_LIST, SB.L.VIEW_TO_GRID },
				{ GW.view.drawn, GW.frame.title.text, GW.viewButton.text })
			assert.truthy(y(2, 2) > y(2, 1), "flask (1000) above potion (500)")
			Fake.Fire(GW.columnsBar.buttons.name, "OnClick")
			assert.equal("Sorted by Name, A to Z", GW.frame.title.text)
			assert.truthy(y(2, 1) > y(2, 2), "Algari Healing Potion above Flask of Alchemical Chaos")
			Fake.Fire(GW.viewButton, "OnClick")
			assert.same({ "grid", 1 }, { GW.view.drawn, button(2, 1).scale })
			assert.falsy(GW.columnsBar.frame.shown)
		end)

	-- Spec 4.3. Mutation: in GuildBankWindow.lua, drop `gone = L.LIST_GUILD_GONE` (the ghost would name the bag).
	it("a withdrawal leaves a ghost row that says the guild bank regroups when closed; search dims rows", function()
		SB.Config.Set("guildBank.view", "list")
		openVault()
		local herb = y(1, 1)
		A.guild.slots[1][1] = nil
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		A.Advance(0.06)
		local ghost = GW.rows.ghosts[1]
		assert.same({ SB.L.LIST_GUILD_GONE, herb }, { ghost.name.text, ghost.points[1][5] })
		GW.searchBox.editBox:SetText("ore")
		Fake.Fire(GW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
		assert.same({ SB.Buttons.DIM_ALPHA, 1 }, { row(2, 1).alpha, row(1, 2).alpha })
	end)

	-- F6. Mutation: in the guild window's onListFailed, drop `SB.Print(L.LIST_SCALE_FALLBACK_GUILD)`.
	it("F6: a guild button whose scale does not take: categories, said once per opening", function()
		openVault()
		button(2, 2).SetScale = function() end
		Fake.Fire(GW.viewButton, "OnClick")
		assert.same({ "sections", 1 }, { GW.view.drawn, button(1, 1).scale })
		GW.Reflow("reflow")
		assert.same({ SB.L.LIST_SCALE_FALLBACK_GUILD }, A.Lines())
		assert.equal("guild.listScale", SB.ErrorTrap.Recent()[1].label)
		assert.falsy(SB.SafeMode.IsOn("bank"))
		assert.falsy(GW.columnsBar.frame.shown)
	end)

	-- Week 8 (final review). The title says what is drawn. Mutation: in GW.ToggleView, flash
	-- VIEW_FLASH[view] (the list's title) whatever the layout drew.
	it("F6: the guild view button's title says categories when the list could not be drawn", function()
		openVault()
		button(2, 2).SetScale = function() end
		Fake.Fire(GW.viewButton, "OnClick")
		assert.equal(SB.L.GUILD_VIEW_SECTIONS, GW.frame.title.text)
	end)

	-- Week 8 ruling Q4. Mutation: drop `GW.scaleWarned` from the reset in the guild window's OnHide.
	it("F6: the fallback is said once per opening, so a second opening says it again", function()
		openVault()
		button(2, 2).SetScale = function() end
		Fake.Fire(GW.viewButton, "OnClick")
		assert.same({ true, 1 }, { GW.scaleWarned, #A.Lines() })
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "GuildBanker")
		assert.falsy(GW.scaleWarned)
		openVault()
		assert.equal("sections", GW.view.drawn)
		assert.equal(2, #A.Lines(), "a new opening says it again")
	end)

	-- Week 8 (Task 2 review). A guild button is scaled to row size in the list; a right-click on it still
	-- withdraws that row's own item. Mutation: in GuildButtons.lua's OnClick pass 1 instead of self.slot.
	it("a right-click on a scaled guild button in the list withdraws that row's own item", function()
		SB.Config.Set("guildBank.view", "list")
		openVault()
		assert.equal(GV.LIST_ROW / GV.SLOT, button(1, 2).scale)
		Fake.Fire(button(1, 2), "OnClick", "RightButton")
		assert.same({ { 1, 2 } }, A.guild.withdrawn)
		assert.same({}, A.Lines())
	end)

	-- Week 8 ruling Q9. Mutation: in GuildBankWindow.lua drop `goneTip = L.LIST_GUILD_GONE_TIP,` from GW.rows.
	it("a ghost row's tooltip and click answer say the guild bank, not the bag or the bank", function()
		SB.Config.Set("guildBank.view", "list")
		openVault()
		A.guild.slots[1][1] = nil
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		A.Advance(0.06)
		local ghost = GW.rows.ghosts[1]
		Fake.Fire(ghost, "OnEnter")
		assert.equal(SB.L.LIST_GUILD_GONE_TIP, GameTooltip.text)
		Fake.Fire(ghost, "OnMouseUp", "LeftButton")
		assert.equal(SB.L.LIST_GUILD_GONE_TIP, GW.frame.title.text)
	end)

	-- Week 8 ruling Q9. Mutation: in GuildBankWindow.lua drop `goneTip = L.LIST_GUILD_GONE_TIP, -- a placeholder's`
	-- from the GroupView cfg (the placeholder icon would say "close the bag").
	it("a placeholder icon's tooltip says the guild bank", function()
		SB.Config.Set("guildBank.view", "list")
		openVault()
		A.guild.slots[1][1] = nil
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		A.Advance(0.06)
		local p = SB.Buttons.placeholdersInUse[1]
		Fake.Fire(p, "OnEnter")
		assert.equal(SB.L.LIST_GUILD_GONE_TIP, GameTooltip.text)
	end)

	-- Week 8 ruling Q12 (the helper is shared with the bank window). Mutation: in GroupView.lua, GV.SortList's
	-- `SB.Sort.Save(spec.by, spec.desc)` -> `true`.
	it("a column click through the shared helper saves, answers in the title, and again reverses", function()
		SB.Sort.Save("name", false)
		assert.truthy(GW.SortList("value"))
		assert.same({ "value", true }, { SB.Sort.Spec().by, SB.Sort.Spec().desc })
		assert.equal("Sorted by Value, highest first", GW.frame.title.text)
		GW.SortList("value")
		assert.same({ "value", false }, { SB.Sort.Spec().by, SB.Sort.Spec().desc })
		local N = SB.GroupView.VIEW_NEXT
		assert.same({ "list", "grid", "sections" }, { N.sections, N.list, N.grid })
	end)
end)
