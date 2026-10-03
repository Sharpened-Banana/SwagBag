-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The bank window's frame handling (check V2): tiny mode, beside, the read-only deposit
-- target, Esc, Safe Mode. The bank contents are covered by spec/bankwindow_groups_spec.lua.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

local FILES = Env.ENGINE

-- Blizzard's bank as Blizzard shows it: parented to UIParent, two real tabs underneath.
-- All four are STRICT fakes (ruling W3-2): every method SwagBag calls on them is logged.
local function blizzardBank()
	local bf = Fake.New("Frame", UIParent)
	bf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	bf.TabSystem = Fake.New("Frame", bf)
	bf.TabSystem:SetPoint("TOPLEFT", bf, "BOTTOMLEFT", 22, 2)
	bf.TabSystem.tabs = { Fake.New("Button", bf.TabSystem), Fake.New("Button", bf.TabSystem) }
	Fake.Strict(bf)
	Fake.Strict(bf.TabSystem)
	Fake.Strict(bf.TabSystem.tabs[1])
	Fake.Strict(bf.TabSystem.tabs[2])
	return bf
end

-- Tiny mode may only move Blizzard's frames: parent and anchors. Tabs may also be hooked.
-- Getters (Get*, Is*) are reads. Anything else in the log is a write SwagBag must not make.
local MOVES = { SetParent = true, ClearAllPoints = true, SetPoint = true }
-- Fix round 1: BankFrame itself only ever gets a new parent; its anchors stay Blizzard's.
local PARENT_ONLY = { SetParent = true }
local HOOK = { HookScript = true }

local function writesOn(f, who, allowed, out)
	for _, c in ipairs(f.log) do
		if not (c.name:find("^Get") or c.name:find("^Is") or allowed[c.name]) then
			out[#out + 1] = who .. ":" .. c.name
		end
	end
	return out
end

local function blizzardWrites(bf)
	local out = {}
	writesOn(bf, "BankFrame", PARENT_ONLY, out)
	writesOn(bf.TabSystem, "TabSystem", MOVES, out)
	for i, tab in ipairs(bf.TabSystem.tabs) do
		writesOn(tab, "tab" .. i, HOOK, out)
	end
	return out
end

-- Every parent SwagBag gave a Blizzard frame.
local function parentsSet(f)
	local out = {}
	for _, c in ipairs(f.log) do
		if c.name == "SetParent" then
			out[#out + 1] = c.args[1]
		end
	end
	return out
end

describe("BankWindow frames (check V2)", function()
	local SB, A, BW, bf
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		bf = blizzardBank()
		A.frames.BankFrame = bf
		A.activeBankType = "bank"
		Env.PaintGlobals()
		BW = Env.LoadBank(SB)
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

	-- Ruling W3-26. Mutation: delete the title's RIGHT anchor in BankWindow.lua.
	it("the title ends left of the title buttons, on one line, so a long flash never runs under them", function()
		local right
		for _, p in ipairs(BW.frame.title.points) do
			if p[1] == "RIGHT" then
				right = p
			end
		end
		assert.same({ "RIGHT", BW.sortBankButton, "LEFT", -6, 0 }, right)
		assert.equal(false, BW.frame.title.calls.SetWordWrap[1])
	end)

	it("opens at the banker; Blizzard's bank stays shown inside the 0.001 parent, its tabs under our window", function()
		openBank()
		assert.truthy(BW.IsOpen())
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		assert.equal(true, bf.shown, "still shown: the bank visit stays open")
		assert.equal(BW.frame, bf.TabSystem.parent)
		assert.same({ "TOPLEFT", BW.frame, "BOTTOMLEFT", 12, 2 }, bf.TabSystem.points[1])
	end)

	-- Ruling W3-2: a STRICT fake logs every call, modelled or not (SetScript, SetAlpha, SetScale,
	-- Show, Hide, SetShown, SetID, ...). Mutation: add bf:SetScript("OnHide", nil) in BW.ApplyMode.
	it("never writes Blizzard's bank state: no call on BankFrame or its tabs besides moving them", function()
		openBank()
		Fake.Fire(bf.TabSystem.tabs[2], "OnClick")
		A.Advance(0)
		Fake.Fire(BW.blizzardButton, "OnClick")
		Fake.Fire(BW.blizzardButton, "OnClick")
		SB.Slash.Dispatch("bank beside")
		SB.Slash.Dispatch("bank tiny")
		BW.frame:Hide()
		Fake.Fire(BW.stillOpenButton, "OnClick")
		A.combat = true
		Fake.Fire(BW.blizzardButton, "OnClick")
		BW.frame:Hide()
		Fake.Fire(BW.stillOpenButton, "OnClick")
		closeBank()
		openBank()
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		SB.SafeMode.Enable("bank", "manual")
		SB.SafeMode.Disable("bank")
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		openBank()
		BW.frame:Hide()
		closeBank()
		A.Advance(5)
		assert.truthy(#bf.log > 0, "the strict fake saw the calls")
		assert.same({}, blizzardWrites(bf))
		local tiny = SB.TinyHost.Parent()
		for _, p in ipairs(parentsSet(bf)) do
			assert.truthy(p == tiny or p == UIParent, "BankFrame only goes to the tiny parent and back")
		end
		for _, p in ipairs(parentsSet(bf.TabSystem)) do
			assert.truthy(p == BW.frame or p == bf, "the tabs only go to our window and back")
		end
		assert.same({}, bf.calls)
		assert.same({}, bf.TabSystem.calls)
		assert.is_nil(rawget(bf, "bankType"))
		assert.equal(true, bf.shown)
		assert.equal(UIParent, bf.parent)
		assert.equal(bf, bf.TabSystem.parent)
	end)

	-- Ruling W3-1: re-applying the window while Blizzard's bank is already tiny stays tiny and
	-- only restores our own position. Mutation: delete the host.IsActive() branch in BW.ApplyMode.
	it("'Bank still open' in combat while Blizzard's bank is tiny stays tiny (ruling W3-1)", function()
		openBank()
		A.combat = true
		BW.frame:Hide() -- in combat the restore waits, so Blizzard's bank is still tiny
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		Fake.Fire(BW.stillOpenButton, "OnClick")
		assert.truthy(BW.IsOpen())
		assert.equal("tiny", BW.VisitMode())
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		assert.equal(BW.frame, bf.TabSystem.parent)
		assert.same({ "TOPLEFT", UIParent, "TOPLEFT", 60, -120 }, BW.frame.points[#BW.frame.points])
		assert.equal(SB.L.BANK_TITLE, BW.frame.title.text)
	end)

	it("in combat /swagbag bank tiny and /swagbag bank beside say the setting is saved for the next visit", function()
		A.combat = true
		SB.Slash.Dispatch("bank beside")
		SB.Slash.Dispatch("bank tiny")
		assert.same({ SB.L.BANK_MODE_SAVED_NEXT, SB.L.BANK_MODE_SAVED_NEXT }, A.Lines())
		assert.equal("tiny", SB.Config.Get("bank.blizzardFrame"))
	end)

	it("/swagbag bank beside in combat during a tiny visit saves the setting but keeps this visit tiny (W3-1)", function()
		openBank()
		A.combat = true
		SB.Slash.Dispatch("bank beside")
		assert.equal("beside", SB.Config.Get("bank.blizzardFrame"))
		assert.equal(SB.L.BANK_MODE_SAVED_NEXT, A.Lines()[#A.Lines()])
		assert.equal("tiny", BW.VisitMode())
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		assert.same({ "TOPLEFT", UIParent, "TOPLEFT", 60, -120 }, BW.frame.points[#BW.frame.points])
		assert.equal(SB.L.BANK_NOT_IN_COMBAT, BW.frame.title.text)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(SB.TinyHost.Parent(), bf.parent, "no restore was waiting for combat")
		closeBank()
		openBank()
		assert.equal("beside", BW.VisitMode(), "the next visit uses the new setting")
		assert.equal(UIParent, bf.parent)
	end)

	-- Mutation: drop host.Keep() from the host.IsActive() branch in BW.ApplyMode.
	it("a bank closed and reopened inside one fight stays tiny after combat (W3-1)", function()
		openBank()
		A.combat = true
		closeBank()
		openBank()
		assert.equal("tiny", BW.VisitMode())
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(SB.TinyHost.Parent(), bf.parent, "the restore queued at the close was cancelled")
		assert.equal(BW.frame, bf.TabSystem.parent)
		closeBank()
		assert.equal(UIParent, bf.parent)
		assert.equal(bf, bf.TabSystem.parent)
	end)

	it("shows where deposits go, read from Blizzard's selected tab on the frame after a tab click", function()
		A.activeBankType = "warband"
		local seen = {}
		SB.On("SB_BANK_TARGET", function(_, target) seen[#seen + 1] = target end)
		openBank()
		assert.equal("Deposits go to Warband bank - switch with the tabs below", BW.frame.deposit.text)
		A.activeBankType = "bank"
		Fake.Fire(bf.TabSystem.tabs[1], "OnClick")
		assert.equal("Deposits go to Warband bank - switch with the tabs below", BW.frame.deposit.text,
			"Blizzard's click handler has not run yet")
		A.Advance(0)
		assert.equal("Deposits go to Character bank - switch with the tabs below", BW.frame.deposit.text)
		assert.same({ "warband", "bank" }, seen)
	end)

	it("hooks each Blizzard tab once, however many visits", function()
		openBank()
		closeBank()
		openBank()
		assert.equal(1, #bf.TabSystem.tabs[1].hooks.OnClick)
	end)

	it("closing the bank puts Blizzard's bank and its tabs back exactly where they were", function()
		openBank()
		closeBank()
		assert.falsy(BW.IsOpen())
		assert.equal(UIParent, bf.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }, bf.points)
		assert.equal(bf, bf.TabSystem.parent)
		assert.same({ { "TOPLEFT", bf, "BOTTOMLEFT", 22, 2 } }, bf.TabSystem.points)
	end)

	it("a bank closed in combat is put back as soon as combat ends", function()
		openBank()
		A.combat = true
		closeBank()
		assert.equal(SB.TinyHost.Parent(), bf.parent, "parents never change in combat")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(UIParent, bf.parent)
		assert.equal(bf, bf.TabSystem.parent)
		assert.same({ { "TOPLEFT", bf, "BOTTOMLEFT", 22, 2 } }, bf.TabSystem.points)
	end)

	it("a visit that starts in combat leaves Blizzard's bank visible and puts ours beside it", function()
		A.combat = true
		openBank()
		assert.truthy(BW.IsOpen())
		assert.equal(UIParent, bf.parent)
		assert.equal("beside", BW.VisitMode())
		assert.same({ "TOPLEFT", bf, "TOPRIGHT", 8, 0 }, BW.frame.points[#BW.frame.points])
		assert.equal(SB.L.BANK_COMBAT_BESIDE, BW.frame.title.text)
	end)

	it("the beside setting leaves Blizzard's bank alone and puts ours to its right (spec 5.4)", function()
		SB.Config.Set("bank.blizzardFrame", "beside")
		openBank()
		assert.equal(UIParent, bf.parent)
		assert.equal(bf, bf.TabSystem.parent)
		assert.same({ "TOPLEFT", bf, "TOPRIGHT", 8, 0 }, BW.frame.points[#BW.frame.points])
		assert.equal("Deposits go to Character bank - switch with the tabs below", BW.frame.deposit.text)
	end)

	it("the Blizzard bank button shows Blizzard's bank for this visit only, and hides it again", function()
		openBank()
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.equal(UIParent, bf.parent)
		assert.equal(SB.L.BANK_SHOWING_BLIZZARD, BW.frame.title.text)
		assert.equal("tiny", SB.Config.Get("bank.blizzardFrame"), "the setting is unchanged")
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		Fake.Fire(BW.blizzardButton, "OnClick")
		closeBank()
		openBank()
		assert.equal("tiny", BW.VisitMode(), "the next visit uses the setting again")
		assert.equal(SB.TinyHost.Parent(), bf.parent)
	end)

	it("the Blizzard bank button does nothing in combat and says so", function()
		openBank()
		A.combat = true
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		assert.equal(SB.L.BANK_NOT_IN_COMBAT, BW.frame.title.text)
	end)

	it("/swagbag bank beside saves the setting and applies it to the open bank; other text prints the usage", function()
		openBank()
		SB.Slash.Dispatch("bank beside")
		assert.equal("beside", SB.Config.Get("bank.blizzardFrame"))
		assert.equal(UIParent, bf.parent)
		SB.Slash.Dispatch("bank tiny")
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		SB.Slash.Dispatch("bank")
		assert.same({ SB.L.BANK_MODE_BESIDE, SB.L.BANK_MODE_TINY,
			"Use /swagbag bank tiny or /swagbag bank beside (now: tiny)." }, A.Lines())
	end)

	-- Final review M2. Mutation: delete the bags.BoundTitle call in BW.RefreshStillOpen (the
	-- bags title stays bounded by Sort and runs under "Bank still open").
	it("'Bank still open' showing or hiding re-bounds the bags title to the leftmost shown button", function()
		local bags = SB.BagsWindow
		openBank()
		BW.frame:Hide() -- "Bank still open" shows on the bags window
		assert.truthy(BW.stillOpenButton.shown)
		assert.equal(BW.stillOpenButton, bags.titleBound)
		Fake.Fire(BW.stillOpenButton, "OnClick")
		assert.falsy(BW.stillOpenButton.shown)
		assert.equal(false, bags.titleBound)
	end)

	-- Final review M8. Mutation: ignore SB.Config.Set's result in BW.ToggleView.
	it("the view toggle with read-only settings says so and changes nothing", function()
		openBank()
		local text, reason = BW.viewButton.text, BW.view.stats.lastLayoutReason
		SB.Config.readOnly = true
		Fake.Fire(BW.viewButton, "OnClick")
		assert.equal(SB.L.SETTINGS_READONLY, BW.frame.title.text)
		assert.equal("sections", SB.Config.Get("bank.view"))
		assert.equal(text, BW.viewButton.text)
		assert.equal(reason, BW.view.stats.lastLayoutReason)
	end)

	it("the X button hides only SwagBag's window; the bags window offers 'Bank still open', which reopens it", function()
		openBank()
		assert.equal("SwagBagBankWindow", UISpecialFrames[1])
		assert.falsy(BW.stillOpenButton.shown)
		BW.frame:Hide() -- what the X button does
		assert.equal(UIParent, bf.parent, "Blizzard's bank is visible again: no invisible deposit target")
		assert.equal(true, bf.shown, "the bank visit is still open")
		assert.truthy(BW.stillOpenButton.shown)
		assert.equal(SB.BagsWindow.frame, BW.stillOpenButton.parent)
		Fake.Fire(BW.stillOpenButton, "OnClick")
		assert.truthy(BW.IsOpen())
		assert.equal(SB.TinyHost.Parent(), bf.parent, "tiny again")
		assert.falsy(BW.stillOpenButton.shown)
		BW.frame:Hide()
		closeBank()
		assert.falsy(BW.stillOpenButton.shown, "the visit is over")
	end)

	-- Fix round 1: hiding SwagBag's bank window mid-visit must not leave an invisible bank that
	-- takes bag right-clicks. Mutation: delete the host.Restore() in the OnHide handler.
	it("hiding SwagBag's bank window mid-visit makes Blizzard's bank visible again (now, or when combat ends)", function()
		openBank()
		BW.frame:Hide()
		assert.equal(UIParent, bf.parent)
		assert.equal(bf, bf.TabSystem.parent)
		assert.same({ { "TOPLEFT", bf, "BOTTOMLEFT", 22, 2 } }, bf.TabSystem.points)
		Fake.Fire(BW.stillOpenButton, "OnClick")
		A.combat = true
		BW.frame:Hide()
		assert.equal(SB.TinyHost.Parent(), bf.parent, "parents never change in combat")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(UIParent, bf.parent)
	end)

	it("OnHide while the window is still shown (Alt+Z hiding UIParent) does nothing", function()
		openBank()
		local closed = 0
		SB.On("SB_BANK_CLOSED", function() closed = closed + 1 end)
		Fake.Fire(BW.frame, "OnHide")
		assert.equal(0, closed)
		assert.falsy(BW.stillOpenButton.shown)
		BW.Close()
		assert.equal(1, closed)
	end)

	it("Safe Mode for the bank: nothing moves and the window stays closed; off mid-visit takes over, on hands back", function()
		SB.SafeMode.Enable("bank", "manual")
		openBank()
		assert.falsy(BW.IsOpen())
		assert.equal(UIParent, bf.parent)
		assert.falsy(BW.stillOpenButton.shown)
		SB.SafeMode.Disable("bank")
		assert.truthy(BW.IsOpen())
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		SB.SafeMode.Enable("bank", "auto")
		assert.falsy(BW.IsOpen())
		assert.equal(UIParent, bf.parent)
	end)

	it("logging out during a visit puts Blizzard's bank back (spec 8.6)", function()
		openBank()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		assert.equal(UIParent, bf.parent)
	end)

	-- Week 6, user request 3. Mutations: drop the A.DepositWarband() call in BW.DepositWarband; or add
	-- bf:Show() there (a Blizzard write the strict fake logs).
	it("Deposit warbound runs the game's warband deposit and answers; Blizzard's bank is not touched", function()
		A.SetBagSize(0, 16)
		openBank()
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(1, A.warbandDeposits)
		assert.equal(SB.L.DEPOSIT_STARTED, BW.frame.title.text)
		assert.same({}, blizzardWrites(bf), "only the tiny-mode moves, nothing else")
		assert.equal("bank", A.activeBankType, "the selected bank type is never set")
		assert.same({ { bag = 0, size = 16 } }, A.refundChecks[1], "the refund check read the bags")
	end)

	-- Item safety and P2. Mutation: in BW.DepositWarband, `if refundable then` (an unknown answer deposits).
	it("it refuses in combat, while the warband bank is busy, and when a refund could be lost; each says why", function()
		openBank()
		A.combat = true
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_AFTER_COMBAT, BW.frame.title.text)
		A.combat = false
		A.warband.usable, A.warband.reason = false, "locked"
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_LOCKED, BW.frame.title.text)
		A.warband.reason = "unavailable"
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_UNAVAILABLE, BW.frame.title.text)
		A.warband.usable, A.warband.refundable = true, true
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_REFUNDABLE, BW.frame.title.text)
		A.warband.refundable = nil
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_UNSURE, BW.frame.title.text)
		assert.equal(0, A.warbandDeposits, "nothing was deposited")
	end)

	-- Never invisible but clickable. Mutation: create the button on Blizzard's bank (parent bf).
	it("the deposit button is on SwagBag's window in tiny and beside mode, so it hides with that window", function()
		openBank()
		assert.equal(BW.frame, BW.depositButton.parent)
		assert.equal(SB.TinyHost.Parent(), bf.parent, "tiny: Blizzard's bank is invisible, our button is not")
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.equal(UIParent, bf.parent, "beside")
		assert.equal(BW.frame, BW.depositButton.parent)
		assert.truthy(BW.frame.shown and BW.depositButton.shown)
	end)

	-- Mutation: the box's OnClick flashes without calling A.SetDepositReagents.
	it("With reagents shows Blizzard's include-reagents choice, switches it and answers", function()
		openBank()
		assert.same({ false }, BW.reagentsBox.calls.SetChecked)
		Fake.Fire(BW.reagentsBox, "OnClick")
		assert.equal(true, A.warband.reagents)
		assert.equal(SB.L.DEPOSIT_REAGENTS_ON, BW.frame.title.text)
		assert.same({ true }, BW.reagentsBox.calls.SetChecked)
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_STARTED_REAGENTS, BW.frame.title.text)
		A.DepositReagents = function() return nil end -- the game cannot say: no box
		BW.RefreshReagents()
		assert.falsy(BW.reagentsBox.shown)
	end)

	-- P2 (the bags window's D27). Mutation: drop the SB.Print in BW.Flash.
	it("a long answer cut short in the bank title also goes to chat", function()
		openBank()
		BW.frame.title.IsTruncated = function() return true end
		A.warband.refundable = true
		Fake.Fire(BW.depositButton, "OnClick")
		assert.same({ SB.L.DEPOSIT_REFUNDABLE }, A.Lines())
	end)

	it("an error in a tab-click hook switches only the bank to Safe Mode", function()
		openBank()
		A.ActiveBankType = function() error("boom") end
		Fake.Fire(bf.TabSystem.tabs[1], "OnClick")
		A.Advance(0)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal(UIParent, bf.parent, "Safe Mode handed the bank back")
	end)
end)

describe("BankWindow load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(FILES)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		local ok, err = pcall(Env.LoadBank, SB)
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
