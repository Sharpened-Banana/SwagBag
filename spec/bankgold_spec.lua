-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- 0.14.2: Warband gold in SwagBag's bank window. A slim footer row (the balance, Deposit and Withdraw) and two "..."
-- menu entries; every click opens Blizzard's own popup through Adapter.ShowWarbandMoneyPopup (SwagBag never moves
-- the gold itself).
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Warband gold in the bank window (0.14.2)", function()
	local SB, A, BW, BM, L, bf
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
		SB.SettingsWindow = { Show = function() end }
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openBank()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	local function menuTexts()
		local out = {}
		for i, e in ipairs(BM.Entries()) do
			out[i] = e.text
		end
		return out
	end

	local function entry(text)
		for _, e in ipairs(BM.Entries()) do
			if e.text == text then
				return e
			end
		end
		return nil
	end

	local function lastPoint(f, name)
		local found
		for _, p in ipairs(f.points) do
			if p[1] == name then
				found = p
			end
		end
		return found
	end

	local function copy(t)
		local out = {}
		for i, p in ipairs(t) do
			out[i] = { unpack(p) }
		end
		return out
	end

	-- Mutation: show the row without the balance (or with A.Money(), the character's own gold).
	it("the row shows the Warband balance as the client writes it", function()
		A.money = 50000
		openBank()
		assert.truthy(BW.goldRow.shown)
		assert.equal(L.BANK_GOLD_LABEL, BW.goldRow.label.text)
		assert.equal("Warband gold:", L.BANK_GOLD_LABEL)
		assert.equal(A.MoneyText(1234560000), BW.goldRow.amount.text)
		assert.equal("Deposit", BW.goldDeposit.text)
		assert.equal("Withdraw", BW.goldWithdraw.text)
	end)

	-- Mutation: drop the ACCOUNT_MONEY (or PLAYER_MONEY) listener.
	it("the balance follows ACCOUNT_MONEY and PLAYER_MONEY", function()
		openBank()
		A.gold.copper = 70000
		SB.eventFrame:Fire("ACCOUNT_MONEY")
		assert.equal(A.MoneyText(70000), BW.goldRow.amount.text)
		A.gold.canDeposit = false
		SB.eventFrame:Fire("PLAYER_MONEY")
		assert.same({ false }, BW.goldDeposit.calls.SetEnabled)
	end)

	-- Mutation: let the listener throw past the ErrorTrap (no window), or name window "bags".
	it("a failing gold refresh is trapped for the bank", function()
		openBank()
		A.WarbandMoney = function() error("gold broke") end
		SB.eventFrame:Fire("ACCOUNT_MONEY")
		assert.equal("bank", SB.ErrorTrap.Recent()[1].window)
	end)

	-- Mutation: swap the kinds of the two buttons.
	it("Deposit and Withdraw open Blizzard's popups of their kind; a second click toggles there", function()
		openBank()
		Fake.Fire(BW.goldDeposit, "OnClick")
		Fake.Fire(BW.goldWithdraw, "OnClick")
		Fake.Fire(BW.goldWithdraw, "OnClick")
		assert.same({ "deposit", "withdraw", "withdraw" }, A.goldPopups)
		assert.equal(L.BANK_TITLE, BW.frame.title.text, "the popup is the answer: no flash")
	end)

	-- Mutation: drop the SetEnabled calls (or enable both whatever the state says).
	it("buttons follow the state, and a disabled one's tooltip says why", function()
		A.gold.canWithdraw = false
		openBank()
		assert.same({ true }, BW.goldDeposit.calls.SetEnabled)
		assert.same({ false }, BW.goldWithdraw.calls.SetEnabled)
		Fake.Fire(BW.goldWithdraw, "OnEnter")
		assert.equal(L.BTN_GOLD_WITHDRAW, GameTooltip.text)
		assert.equal(L.TIP_GOLD_UNAVAILABLE, GameTooltip.calls.AddLine[1])
		Fake.Fire(BW.goldDeposit, "OnEnter")
		assert.equal(L.TIP_GOLD_DEPOSIT, GameTooltip.calls.AddLine[1])
		Fake.Fire(BW.goldDeposit, "OnLeave")
		assert.falsy(GameTooltip.shown)
	end)

	-- P2. Mutation: return quietly when the popup cannot open.
	it("a click that cannot open the popup says so once", function()
		A.gold.popupOK = false
		openBank()
		Fake.Fire(BW.goldDeposit, "OnClick")
		assert.equal(L.GOLD_UNAVAILABLE, BW.frame.title.text)
		A.gold.popupOK, A.gold.canWithdraw = true, false
		assert.equal(false, BW.MoveGold("withdraw"))
		assert.same({ "deposit" }, A.goldPopups, "a refused withdraw never asks for the popup")
		assert.equal(L.GOLD_UNAVAILABLE, BW.frame.title.text)
	end)

	-- Mutation: add an InCombat refusal to BW.MoveGold.
	it("gold moves in combat too (Blizzard's popup, plain frames)", function()
		openBank()
		A.combat = true
		assert.equal(true, BW.MoveGold("deposit"))
		assert.same({ "deposit" }, A.goldPopups)
	end)

	-- Mutation: show the row (or the entries) without testing `supported`.
	it("unsupported: no row and no menu entries", function()
		A.gold.supported = false
		openBank()
		assert.falsy(BW.goldRow.shown)
		assert.is_nil(entry(L.BANK_MENU_GOLD_DEPOSIT))
		assert.is_nil(entry(L.BANK_MENU_GOLD_WITHDRAW))
	end)

	-- Mutation: put the entries after Bank settings, or point them at the other kind.
	it("the menu entries sit after Deposit all warbound items and run the same actions", function()
		openBank()
		local texts = menuTexts()
		local at
		for i, t in ipairs(texts) do
			if t == L.BANK_MENU_DEPOSIT then
				at = i
			end
		end
		assert.equal(L.BANK_MENU_GOLD_DEPOSIT, texts[at + 1])
		assert.equal(L.BANK_MENU_GOLD_WITHDRAW, texts[at + 2])
		assert.equal(L.TIP_GOLD_DEPOSIT, entry(L.BANK_MENU_GOLD_DEPOSIT).tip)
		assert.equal(L.TIP_GOLD_WITHDRAW, entry(L.BANK_MENU_GOLD_WITHDRAW).tip)
		entry(L.BANK_MENU_GOLD_WITHDRAW).run()
		entry(L.BANK_MENU_GOLD_DEPOSIT).run()
		assert.same({ "withdraw", "deposit" }, A.goldPopups)
		A.gold.canDeposit = false
		assert.equal(L.TIP_GOLD_UNAVAILABLE, entry(L.BANK_MENU_GOLD_DEPOSIT).tip)
		entry(L.BANK_MENU_GOLD_DEPOSIT).run()
		assert.equal(L.GOLD_UNAVAILABLE, BW.frame.title.text)
	end)

	-- Mutation: ignore bank.gold in BW.GoldShown.
	it("bank.gold off hides the row; /swagbag bank gold on|off sets it", function()
		openBank()
		assert.equal(true, SB.Config.Get("bank.gold"))
		assert.equal(L.BANK_GOLD_OFF, (select(2, SB.Slash.Run("bank gold off"))))
		assert.equal(false, SB.Config.Get("bank.gold"))
		assert.falsy(BW.goldRow.shown)
		assert.equal(L.BANK_GOLD_ON, (select(2, SB.Slash.Run("bank gold on"))))
		assert.truthy(BW.goldRow.shown)
		SB.Slash.Dispatch("bank")
		assert.truthy(A.Lines()[1]:find("gold on or off", 1, true), "the usage line mentions it")
		assert.truthy(L.HELP_BANK:find("bank gold on|off", 1, true))
	end)

	-- Mutation: add BW.GOLD_FOOTER to the height whatever the row says (or never).
	it("the window's height has the footer only while the row shows; nothing above it moves", function()
		SB.Config.Set("bank.gold", false)
		openBank()
		local h0, w0 = BW.frame.h, BW.frame.w
		local top0 = lastPoint(BW.scroll, "TOPLEFT")
		local framePoints = copy(BW.frame.points)
		assert.same({ "BOTTOMRIGHT", BW.frame, "BOTTOMRIGHT", -4, BW.FOOTER }, lastPoint(BW.scroll, "BOTTOMRIGHT"))
		SB.Slash.Run("bank gold on")
		assert.equal(h0 + BW.GOLD_FOOTER - BW.FOOTER, BW.frame.h)
		assert.equal(w0, BW.frame.w)
		assert.same(top0, lastPoint(BW.scroll, "TOPLEFT"), "the scroll area's top stays")
		assert.same(framePoints, BW.frame.points, "the window's anchor stays")
		assert.same({ "BOTTOMRIGHT", BW.frame, "BOTTOMRIGHT", -4, BW.GOLD_FOOTER }, lastPoint(BW.scroll, "BOTTOMRIGHT"))
		-- the row appearing mid-visit (the API answers later) grows the window the same way
		SB.Slash.Run("bank gold off")
		assert.equal(h0, BW.frame.h)
		A.gold.supported = false
		SB.Slash.Run("bank gold on")
		assert.equal(h0, BW.frame.h)
		A.gold.supported = true
		SB.eventFrame:Fire("ACCOUNT_MONEY")
		assert.equal(h0 + BW.GOLD_FOOTER - BW.FOOTER, BW.frame.h)
		assert.same(top0, lastPoint(BW.scroll, "TOPLEFT"))
	end)

	-- Mutation: hide the row in beside mode.
	it("the row stays in beside mode", function()
		SB.Config.Set("bank.blizzardFrame", "beside")
		openBank()
		assert.equal("beside", BW.VisitMode())
		assert.truthy(BW.goldRow.shown)
		BW.ToggleVisit()
		assert.truthy(BW.goldRow.shown)
	end)

	-- Mutation: drop ["bank.gold"] from Profiles.LABELS, or `gold = true` from the defaults.
	it("bank.gold is shareable in profiles, by its settings name", function()
		local Pr = SB.Profiles
		if not Pr then
			Loader.LoadFile(SB, "SwagBag/Engine/Profiles.lua")
			Pr = SB.Profiles
		end
		SB.Config.Set("bank.gold", false)
		local data = assert(Pr.Parse(Pr.Export(false)))
		assert.equal(false, data.settings["bank.gold"])
		assert.equal(L.SET_BANK_GOLD, Pr.Label("bank.gold"))
	end)
end)
