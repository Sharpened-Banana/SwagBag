-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 13 Task 5: the bank window's slim title row (Sort, "...", close) and the "..." menu that
-- holds every other bank action (UI/BankMenu.lua).
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("the bank window's header and its ... menu (week 13)", function()
	local SB, A, BW, BM, L, bf, settingsShown
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		bf = Fake.New("Frame", UIParent)
		bf.TabSystem = Fake.New("Frame", bf)
		bf.TabSystem.tabs = {}
		A.frames.BankFrame = bf
		A.activeBankType = "bank"
		Env.PaintGlobals()
		BW = Env.LoadBank(SB)
		BM, L = SB.BankMenu, SB.L
		settingsShown = {}
		SB.SettingsWindow = { Show = function(page) settingsShown[#settingsShown + 1] = page end }
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openBank()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	local function closeBank()
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
	end

	-- Open the menu and press the row whose text is `text`.
	local function pick(text)
		BM.Toggle(BW.moreButton)
		for _, r in ipairs(BM.rows) do
			if r.shown and r.text == text then
				Fake.Fire(r, "OnClick")
				return r
			end
		end
		error("no menu row: " .. text)
	end

	-- Mutation: leave any old title button (sortBankButton, sortWarbandButton, reflowButton, viewButton,
	-- blizzardButton) on the window.
	it("the title row has only Sort, ... and close", function()
		for _, name in ipairs({ "sortBankButton", "sortWarbandButton", "reflowButton", "viewButton", "blizzardButton" }) do
			assert.is_nil(BW[name], name)
		end
		openBank()
		assert.truthy(BW.sortButton and BW.moreButton)
		assert.truthy(BW.sortButton.shown and BW.moreButton.shown)
		assert.equal(L.BTN_SORT, BW.sortButton.text)
		assert.equal("...", BW.moreButton.text)
		assert.equal(52, BW.sortButton.w)
		assert.equal(30, BW.moreButton.w)
	end)

	-- Mutation: in BW.SortKind, return "bank" always (or sort `BW.target` without the "bank" default).
	it("Sort sorts the bank you deposit into", function()
		A.activeBankType = "warband"
		openBank()
		Fake.Fire(BW.sortButton, "OnClick")
		assert.same({ "warband" }, A.bankSorts)
		closeBank()
		A.activeBankType = nil
		openBank()
		assert.equal("bank", BW.SortKind())
		Fake.Fire(BW.sortButton, "OnClick")
		assert.same({ "warband", "bank" }, A.bankSorts)
	end)

	-- Mutation: in the OnEnter, name groupName("bank") whatever the target.
	it("Sort's tooltip names that bank", function()
		A.activeBankType = "warband"
		openBank()
		Fake.Fire(BW.sortButton, "OnEnter")
		assert.equal(L.BTN_SORT, GameTooltip.text)
		assert.equal(L.TIP_BANK_SORT:format(L.BANK_GROUP_WARBAND), GameTooltip.calls.AddLine[1])
		assert.equal(BW.sortButton, GameTooltip.calls.SetOwner[1])
		Fake.Fire(BW.sortButton, "OnLeave")
		assert.falsy(GameTooltip.shown)
	end)

	-- Final review fix 4. Mutation: the OnEnter always uses TIP_BANK_SORT.
	it("Sort's tooltip with no known target says it sorts the Character bank and where the other is", function()
		A.activeBankType = nil
		openBank()
		Fake.Fire(BW.sortButton, "OnEnter")
		assert.equal(L.TIP_BANK_SORT_NONE:format(L.BANK_GROUP_BANK), GameTooltip.calls.AddLine[1])
		assert.equal("Sorts your Character bank. The ... menu sorts either bank.", GameTooltip.calls.AddLine[1])
	end)

	it("the ... button's tooltip lists what the menu holds", function()
		openBank()
		Fake.Fire(BW.moreButton, "OnEnter")
		assert.equal(L.TIP_BANK_MORE, GameTooltip.calls.AddLine[1])
		assert.equal(BW.moreButton, GameTooltip.calls.SetOwner[1])
	end)

	-- Mutation: Toggle always shows; or leave "SwagBagBankMenu" out of UISpecialFrames.
	it("... opens and closes the menu; Esc closes it", function()
		openBank()
		Fake.Fire(BW.moreButton, "OnClick")
		assert.truthy(BM.frame.shown)
		Fake.Fire(BW.moreButton, "OnClick")
		assert.falsy(BM.frame.shown)
		assert.equal("SwagBagBankMenu", BM.frame.name)
		local found = false
		for _, n in ipairs(UISpecialFrames) do
			found = found or n == "SwagBagBankMenu"
		end
		assert.truthy(found, "Esc closes it")
		assert.equal(true, BM.Toggle(BW.moreButton))
		assert.equal(false, BM.Toggle(BW.moreButton))
	end)

	-- Mutation: swap two entries in Entries().
	it("the menu lists every bank action in order", function()
		openBank()
		local texts = {}
		for i, e in ipairs(BM.Entries()) do
			texts[i] = e.text
		end
		assert.same({
			L.BANK_MENU_VIEW:format(L.BANK_MENU_NOW:format(L.BANK_MENU_VIEW_SECTIONS)),
			L.BANK_MENU_VIEW:format(L.BANK_MENU_VIEW_LIST),
			L.BANK_MENU_VIEW:format(L.BANK_MENU_VIEW_GRID),
			L.BANK_MENU_SORT:format(L.BANK_GROUP_BANK),
			L.BANK_MENU_SORT:format(L.BANK_GROUP_WARBAND),
			L.BANK_MENU_REGROUP,
			L.BANK_MENU_SHOW_BLIZZARD,
			L.BANK_MENU_DEPOSIT,
			L.BANK_MENU_SETTINGS,
		}, texts)
	end)

	it("the rows are the entries, rebuilt at every open (the view mark moves)", function()
		openBank()
		BM.Toggle(BW.moreButton)
		assert.equal(9, #BM.rows)
		assert.equal(L.BANK_MENU_VIEW:format(L.BANK_MENU_NOW:format(L.BANK_MENU_VIEW_SECTIONS)), BM.rows[1].text)
		BM.Hide()
		SB.Config.Set("bank.view", "grid")
		BM.Toggle(BW.moreButton)
		assert.equal(L.BANK_MENU_VIEW:format(L.BANK_MENU_VIEW_SECTIONS), BM.rows[1].text)
		assert.equal(L.BANK_MENU_VIEW:format(L.BANK_MENU_NOW:format(L.BANK_MENU_VIEW_GRID)), BM.rows[3].text)
		assert.same({ "TOPRIGHT", BW.moreButton, "BOTTOMRIGHT", 0, -2 }, BM.frame.points[1])
	end)

	-- Mutation: in BW.SetView, skip the Config.Set; or leave the menu shown after a pick.
	it("picking a view saves it, answers once and hides the menu", function()
		openBank()
		pick(L.BANK_MENU_VIEW:format(L.BANK_MENU_VIEW_LIST))
		assert.equal("list", SB.Config.Get("bank.view"))
		assert.equal(L.BANK_VIEW_LIST, BW.frame.title.text)
		assert.equal("list", BW.view.drawn)
		assert.falsy(BM.frame.shown)
	end)

	-- Mutation: point a Sort row at the other bank.
	it("each Sort row sorts its own bank", function()
		openBank()
		pick(L.BANK_MENU_SORT:format(L.BANK_GROUP_WARBAND))
		assert.same({ "warband" }, A.bankSorts)
		assert.equal(L.SORT_STARTED, BW.frame.title.text)
		pick(L.BANK_MENU_SORT:format(L.BANK_GROUP_BANK))
		assert.same({ "warband", "bank" }, A.bankSorts)
		assert.falsy(BM.frame.shown)
	end)

	-- Mutation: drop the BW.Reflow call from the Regroup row.
	it("Regroup now regroups and answers as the old Reflow button did", function()
		openBank()
		pick(L.BANK_MENU_REGROUP)
		assert.equal(L.REFLOW_DONE, BW.frame.title.text)
		assert.equal("reflow", BW.view.stats.lastLayoutReason)
	end)

	-- Mutation: drop the BW.DepositWarband call from the deposit row.
	it("Deposit all warbound items runs the deposit, and refuses in combat as the header button does", function()
		A.SetBagSize(0, 16)
		openBank()
		pick(L.BANK_MENU_DEPOSIT)
		assert.equal(1, A.warbandDeposits)
		assert.equal(L.DEPOSIT_STARTED, BW.frame.title.text)
		A.combat = true
		pick(L.BANK_MENU_DEPOSIT)
		assert.equal(1, A.warbandDeposits)
		assert.equal(L.DEPOSIT_AFTER_COMBAT, BW.frame.title.text)
	end)

	-- Mutation: call SB.SettingsWindow.Show() without the page.
	it("Bank settings... opens the Bank & guild page", function()
		openBank()
		pick(L.BANK_MENU_SETTINGS)
		assert.same({ "bank" }, settingsShown)
		assert.falsy(BM.frame.shown)
	end)

	-- Mutation: read BW.Mode() instead of BW.VisitMode() for the words.
	it("Blizzard's bank entry flips its words", function()
		openBank()
		assert.equal(L.BANK_MENU_SHOW_BLIZZARD, BM.Entries()[7].text)
		pick(L.BANK_MENU_SHOW_BLIZZARD)
		assert.equal("beside", BW.VisitMode())
		assert.equal(L.BANK_MENU_HIDE_BLIZZARD, BM.Entries()[7].text)
		BM.Toggle(BW.moreButton)
		assert.equal(L.BANK_MENU_HIDE_BLIZZARD, BM.rows[7].text)
		Fake.Fire(BM.rows[7], "OnClick")
		assert.equal("tiny", BW.VisitMode())
		assert.equal(L.BANK_MENU_SHOW_BLIZZARD, BM.Entries()[7].text)
	end)

	-- Mutation: drop the InCombat refusal in BW.ToggleVisit.
	it("Blizzard's bank entry refuses in combat", function()
		openBank()
		A.combat = true
		pick(L.BANK_MENU_SHOW_BLIZZARD)
		assert.equal(L.BANK_NOT_IN_COMBAT, BW.frame.title.text)
		assert.equal("tiny", BW.VisitMode())
		assert.equal(L.BANK_MENU_SHOW_BLIZZARD, BM.Entries()[7].text)
	end)

	-- Mutation: give an entry a tip of "" or a literal string.
	it("every menu row has a tooltip, and hovering a row shows it", function()
		openBank()
		local isL = {}
		for _, v in pairs(L) do
			isL[v] = true
		end
		for i, e in ipairs(BM.Entries()) do
			assert.truthy(e.tip ~= "" and isL[e.tip], "entry " .. i)
		end
		BM.Toggle(BW.moreButton)
		Fake.Fire(BM.rows[8], "OnEnter")
		assert.equal(L.BANK_MENU_DEPOSIT, GameTooltip.text)
		assert.equal(L.TIP_MENU_DEPOSIT, GameTooltip.calls.AddLine[1])
		Fake.Fire(BM.rows[8], "OnLeave")
		assert.falsy(GameTooltip.shown)
	end)

	-- Mutation: drop BankMenu.Hide() from the window's OnHide, or from OnBankClosed.
	it("the menu closes with the bank", function()
		openBank()
		BM.Toggle(BW.moreButton)
		closeBank()
		assert.falsy(BM.frame.shown)
		openBank()
		BM.Toggle(BW.moreButton)
		BW.frame:Hide()
		assert.falsy(BM.frame.shown)
	end)

	-- Mutation: restore "Bank still open", or take the click off BW.Open.
	it("Show bank brings the window back", function()
		assert.equal("Show bank", L.BANK_STILL_OPEN)
		assert.equal(L.BANK_STILL_OPEN, BW.stillOpenButton.text)
		assert.equal(80, BW.stillOpenButton.w)
		openBank()
		BW.frame:Hide()
		assert.truthy(BW.stillOpenButton.shown)
		Fake.Fire(BW.stillOpenButton, "OnClick")
		assert.truthy(BW.frame.shown)
	end)

	it("the menu is plain frames, so it opens in combat", function()
		openBank()
		A.combat = true
		assert.equal(true, BM.Toggle(BW.moreButton))
		assert.truthy(BM.frame.shown)
	end)
end)
