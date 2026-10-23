-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip SwagBagDB SwagBagCharDB
-- Forever Stage A, Task 4: the windows under the WoW Forever mock, logged in through Boot. The bags are
-- SwagBag's; the bank and guild bank stay Blizzard's (Safe Mode reason "forever"), said once per session at
-- the first visit, never at login. /swagbag safe bank is the Stage B opt-in, for one session.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Globals = dofile("spec/helpers/globals.lua")

-- Blizzard's bank as Blizzard shows it; STRICT fakes, so every call SwagBag makes on them is logged.
local function blizzardBank()
	local bf = Fake.New("Frame", UIParent)
	bf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	bf.TabSystem = Fake.New("Frame", bf)
	bf.TabSystem.tabs = { Fake.New("Button", bf.TabSystem), Fake.New("Button", bf.TabSystem) }
	Fake.Strict(bf)
	Fake.Strict(bf.TabSystem)
	return bf
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

-- The TOC's order for the files these tests need: the bags window with its footer, the bank window, then Boot
-- (one load each: no Env.LoadBank on top of the bags window, which would load the button pool twice).
local UI_FILES = {
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Commands.lua", "SwagBag/Engine/Crests.lua",
	"SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/ListRows.lua", "SwagBag/UI/BagsWindow.lua",
	"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua",
	"SwagBag/UI/BankMenu.lua", "SwagBag/UI/Overlays.lua", "SwagBag/UI/Footer.lua", "SwagBag/Core/Boot.lua",
}

describe("SwagBag on WoW Forever (Stage A)", function()
	local SB, A, L, W, BW, B, bf
	before_each(function()
		SwagBagDB, SwagBagCharDB = nil, nil
		SB = Loader.New(Env.ENGINE, { flavor = "forever" })
		A, L = SB.Adapter, SB.L
		Fake.Install()
		Env.PaintGlobals()
		bf = blizzardBank()
		A.frames.BankFrame = bf
		A.activeBankType = "bank"
		for _, path in ipairs(UI_FILES) do
			Loader.LoadFile(SB, path)
		end
		W, BW, B = SB.BagsWindow, SB.BankWindow, SB.Buttons
		A.globals = Globals.AllPresent(A)
		A.globals.Enum.BagIndex.AccountBankTab_1 = 15 -- Forever's own number: the checks pass, only Forever gates the bank
		Fixtures.SmallBags(A)
		A.SetBagSize(2, 4)
		A.Put(2, 1, Fixtures.HERB, 20)
		A.SetBagSize(5, 4)
		A.Put(5, 1, Fixtures.ORE, 10)
		A.money = 1234567
		A.backpack = { { id = 3056, name = "Kej", quantity = 500, icon = 1 } }
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
		SwagBagDB, SwagBagCharDB = nil, nil
	end)

	local function login()
		SB.eventFrame:Fire("PLAYER_LOGIN")
		Fixtures.Settle(SB)
	end

	local function count(lines, text)
		local n = 0
		for _, line in ipairs(lines) do
			if line == text then
				n = n + 1
			end
		end
		return n
	end

	local function loadGuild()
		for _, path in ipairs({ "SwagBag/Engine/Snapshots.lua", "SwagBag/UI/GuildButtons.lua",
			"SwagBag/UI/GuildBankWindow.lua" }) do
			Loader.LoadFile(SB, path)
		end
		return SB.GuildBankWindow
	end

	local function search(t)
		BW.searchBox.editBox:SetText(t)
		Fake.Fire(BW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
	end

	it("the bags window opens on Forever with the bags and the reagent bag", function()
		login()
		assert.falsy(SB.SafeMode.IsOn("bags"))
		W.Open()
		assert.truthy(W.IsOpen())
		local where = W.state.where
		assert.equal("c_herbs", where[SB.Layout.Key(2, 1)].section, "bag 2 is a bag")
		local reagent = where[SB.Layout.Key(5, 1)].section
		assert.equal("c_ore", reagent)
		local held = {}
		for _, c in ipairs(W.SectionSlots(reagent)) do
			held[#held + 1] = c.bag .. "," .. c.slot
		end
		assert.same({ "5,1" }, held, "the reagent bag's item is laid out in its section")
		assert.truthy(B.Get(5, 1).shown)
		local entries = {}
		for _, item in ipairs(SB.Footer.Items()) do
			entries[#entries + 1] = item.entry
		end
		assert.same({ "gold", "currencies", "free" }, entries)
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	-- Mutation: BW.Open ignoring Safe Mode.
	it("a Forever bank visit leaves Blizzard's bank alone and says so once", function()
		login()
		W.Open()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.falsy(BW.IsOpen())
		assert.same({}, parentsSet(bf), "BankFrame keeps its parent")
		assert.same({}, parentsSet(bf.TabSystem), "its tabs are never hosted")
		assert.equal(1, count(A.Lines(), L.FOREVER_BANK_OFF))
		assert.falsy(BW.stillOpenButton:IsShown(), "no Show bank button")
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	-- Mutation: Boot printing L.FOREVER_BANK_OFF after enabling the reason.
	it("the notice is not printed at login", function()
		login()
		assert.same({ "v" .. SB.VERSION .. " loaded. Type /swagbag help for commands." }, A.Lines())
		assert.equal("forever", SB.SafeMode.Reason("bank"))
	end)

	-- Mutation: the notice in the GUILDBANKFRAME_OPENED handler instead of GW.OnOpened (the interaction event
	-- is how Midnight-based clients open the guild bank).
	it("a Forever guild bank visit is Blizzard's too, with no second notice", function()
		local GW = loadGuild()
		login()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
		assert.falsy(GW.IsOpen())
		assert.equal(1, count(A.Lines(), L.FOREVER_BANK_OFF), "the guild bank visit first says it")
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "GuildBanker")
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
		assert.falsy(GW.IsOpen())
		assert.falsy(BW.IsOpen())
		assert.equal(1, count(A.Lines(), L.FOREVER_BANK_OFF))
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	-- Mutation: the bank or guild command without the Forever answer (it saves the setting).
	it("/swagbag bank and /swagbag guild say the bank is Blizzard's on Forever", function()
		loadGuild()
		login()
		A.printed = {}
		SB.Slash.Dispatch("bank beside")
		SB.Slash.Dispatch("guild view")
		assert.same({ L.FOREVER_BANK_OFF, L.FOREVER_BANK_OFF }, A.Lines())
		assert.equal("tiny", SB.Config.Get("bank.blizzardFrame"))
		assert.equal("full", SB.Config.Get("guildBank.mode"))
	end)

	-- Review Focus 1. Mutation: literal Retail ranges in BagKind (bag 13 reads as warband).
	it("with the opt-in, the Forever bank shows bag 13 in the Character bank group", function()
		login()
		SB.Slash.Dispatch("safe bank")
		assert.falsy(SB.SafeMode.IsOn("bank"))
		A.bagIDs.bank, A.bagIDs.warband = { 6, 13 }, {}
		A.SetBagSize(6, 8)
		A.SetBagSize(13, 8)
		A.Put(13, 1, Fixtures.HERB, 20)
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.truthy(BW.IsOpen())
		assert.truthy(B.Get(13, 1).shown)
		assert.equal("bank", BW.view.GroupOf(13))
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			assert.falsy(h.shown and h.sectionId:find("^warband:"), "no Warband group content: " .. h.sectionId)
		end
		search("warband")
		assert.equal(0, BW.found.bank + BW.found.warband)
		search("bank")
		assert.equal(1, BW.found.bank)
		assert.equal(0, BW.found.warband)
	end)

	-- Review Focus 5. Mutation: Boot switching a window off at login when its saved safeMode is off.
	it("the opt-in lasts one session", function()
		login()
		SB.Slash.Dispatch("safe bank")
		assert.falsy(SB.SafeMode.IsOn("bank"))
		SB.SafeMode.state.bank = { on = false } -- a new session: Safe Mode state is not saved
		SB.SafeMode.foreverTold = nil
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.equal("forever", SB.SafeMode.Reason("bank"))
	end)
end)
