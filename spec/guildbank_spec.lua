-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- luacheck: globals SetItemButtonTexture SetItemButtonCount SetItemButtonQuality SetItemButtonDesaturated
-- The guild bank window (check G1): tiny mode, re-hosted tabs, withdraw / pickup / drop
-- through Blizzard's own guild bank functions, the read-only selected tab, view mode.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = { "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
	"SwagBag/Core/Config.lua", "SwagBag/Core/Slash.lua", "SwagBag/Engine/GridLayout.lua" }

local function paintGlobals()
	SetItemButtonTexture = function(b, icon) b.icon = icon end
	SetItemButtonCount = function(b, n) b.count = n end
	SetItemButtonQuality = function(b, q) b.quality = q end
	SetItemButtonDesaturated = function(b, d) b.desaturated = d end
end

local function clearPaintGlobals()
	SetItemButtonTexture, SetItemButtonCount, SetItemButtonQuality, SetItemButtonDesaturated = nil, nil, nil, nil
end

-- Blizzard's guild bank as Blizzard shows it, with two tab buttons on its right edge.
-- All five frames are STRICT fakes (ruling W3-2): every method SwagBag calls on them is logged.
local function blizzardGuildBank(A)
	local gf = Fake.New("Frame", UIParent)
	gf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	local tabs = {}
	for i = 1, 2 do
		local t = Fake.New("Frame", gf)
		t.Button = Fake.New("CheckButton", t)
		if i == 1 then
			t:SetPoint("TOPLEFT", gf, "TOPRIGHT", -1, -17)
		else
			t:SetPoint("TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -17)
		end
		tabs[i] = t
	end
	Fake.Strict(gf)
	for i = 1, 2 do
		Fake.Strict(tabs[i])
		Fake.Strict(tabs[i].Button)
	end
	A.frames.GuildBankFrame = gf
	A.guildTabFrames = tabs
	return gf, tabs
end

-- Ruling W3-2: the only writes SwagBag may make on Blizzard's guild bank. GuildBankFrame gets
-- a new parent (tiny mode; never its anchors) and an OnShow hook; a tab container is moved
-- (parent and anchors, the re-host); a tab button gets an OnClick hook. Getters (Get*, Is*)
-- are reads. Anything else in the log is a write SwagBag must not make.
local FRAME_ALLOWED = { SetParent = true, HookScript = true }
local TAB_ALLOWED = { SetParent = true, ClearAllPoints = true, SetPoint = true }
local BUTTON_ALLOWED = { HookScript = true }

local function writesOn(f, who, allowed, out)
	for _, c in ipairs(f.log) do
		if not (c.name:find("^Get") or c.name:find("^Is") or allowed[c.name]) then
			out[#out + 1] = who .. ":" .. c.name
		end
	end
	return out
end

local function blizzardWrites(gf, tabs)
	local out = {}
	writesOn(gf, "GuildBankFrame", FRAME_ALLOWED, out)
	for i, t in ipairs(tabs) do
		writesOn(t, "tab" .. i, TAB_ALLOWED, out)
		writesOn(t.Button, "tab" .. i .. ".Button", BUTTON_ALLOWED, out)
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

describe("GuildBankWindow (check G1)", function()
	local SB, A, GW, gf, tabs
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		paintGlobals()
		gf, tabs = blizzardGuildBank(A)
		A.guild.tabs = {
			{ tab = 1, name = "Mats", withdrawals = 5 },
			{ tab = 2, name = "Gear", withdrawals = 0 },
			{ tab = 3, name = "Officers", viewable = false },
		}
		A.guild.slots = { [1] = { [1] = { itemID = Fixtures.HERB, count = 20 }, [2] = { itemID = Fixtures.ORE, count = 5 } },
			[2] = { [1] = { itemID = Fixtures.BOE_RING } } }
		A.guild.current = 1
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GuildButtons.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GuildBankWindow.lua")
		GW = SB.GuildBankWindow
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
		clearPaintGlobals()
	end)

	local function openVault()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
	end

	local function closeVault()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "GuildBanker")
	end

	-- The client answers each query with GUILDBANKBAGSLOTS_CHANGED.
	local function answerQueries()
		for _ = 1, 4 do
			SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
			A.Advance(0.06)
		end
	end

	local function button(tab, slot)
		return SB.GuildButtons.Get(tab, slot)
	end

	it("opens at the vault; Blizzard's guild bank stays shown in the 0.001 parent, its tabs on our right edge", function()
		openVault()
		assert.truthy(GW.IsOpen())
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.equal(true, gf.shown, "still shown: the visit stays open")
		assert.equal(GW.frame, tabs[1].parent)
		assert.same({ "TOPLEFT", GW.frame, "TOPRIGHT", 0, -16 }, tabs[1].points[1])
		assert.same({ "TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -6 }, tabs[2].points[1])
	end)

	-- Ruling W3-2: the STRICT fakes log every call, modelled or not (SetScript, SetAlpha, Show,
	-- Hide, SetShown, SetID, ...). Mutations: add gf:UpdateTabs() (an unmodelled method) or
	-- gf:SetAlpha(1) (a modelled one) before `if host.Shrink(gf) then` in GW.ApplyMode.
	it("never writes Blizzard's guild bank state: no call on its frame or tabs besides moving and hooking them", function()
		openVault()
		answerQueries()
		Fake.Fire(tabs[2].Button, "OnClick")
		A.Advance(0)
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(1, 2), "OnClick", "LeftButton")
		Fake.Fire(button(1, 2), "OnDragStart")
		Fake.Fire(button(1, 9), "OnReceiveDrag")
		Fake.Fire(GW.blizzardButton, "OnClick")
		Fake.Fire(GW.blizzardButton, "OnClick")
		SB.Slash.Dispatch("guild view")
		SB.Slash.Dispatch("guild full")
		A.combat = true
		Fake.Fire(gf, "OnShow") -- a second OnShow for the same visit, in combat
		SB.Slash.Dispatch("guild view")
		Fake.Fire(GW.blizzardButton, "OnClick")
		closeVault()
		openVault()
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		SB.Config.Set("guildBank.mode", "full")
		SB.SafeMode.Enable("bank", "manual")
		SB.SafeMode.Disable("bank")
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		openVault()
		GW.frame:Hide()
		closeVault()
		A.Advance(5)
		assert.truthy(#gf.log > 0 and #tabs[1].log > 0 and #tabs[1].Button.log > 0, "the strict fakes saw the calls")
		assert.same({}, blizzardWrites(gf, tabs))
		local tiny = SB.TinyHost.Parent()
		for _, p in ipairs(parentsSet(gf)) do
			assert.truthy(p == tiny or p == UIParent, "GuildBankFrame only goes to the tiny parent and back")
		end
		for i = 1, 2 do
			for _, p in ipairs(parentsSet(tabs[i])) do
				assert.truthy(p == GW.frame or p == gf, "the tabs only go to our window and back")
			end
		end
		assert.same({}, gf.calls)
		for i = 1, 2 do
			assert.same({}, tabs[i].calls)
			assert.same({}, tabs[i].Button.calls)
		end
		assert.equal(true, gf.shown)
		assert.equal(UIParent, gf.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }, gf.points, "its anchors were never touched")
		assert.equal(gf, tabs[1].parent)
		assert.same({ { "TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -17 } }, tabs[2].points)
	end)

	-- Ruling W3-1: a second signal for the same visit (Blizzard's frame shown again, the older
	-- GUILDBANKFRAME_OPENED) while the guild frame is already tiny stays full and only puts our
	-- window back at its own position. Mutation: delete the host.IsActive() branch in GW.ApplyMode.
	it("a second OnShow in combat while Blizzard's guild bank is tiny stays full (ruling W3-1)", function()
		openVault()
		A.combat = true
		Fake.Fire(gf, "OnShow")
		SB.eventFrame:Fire("GUILDBANKFRAME_OPENED")
		assert.truthy(GW.IsOpen())
		assert.equal("full", GW.VisitMode())
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.equal(GW.frame, tabs[1].parent)
		assert.same({ "TOPLEFT", UIParent, "TOPLEFT", 60, -120 }, GW.frame.points[#GW.frame.points])
		assert.equal(SB.L.GUILD_TITLE, GW.frame.title.text, "no 'stays visible' flash")
	end)

	it("a second OnShow out of combat stays full and only restores our position (ruling W3-1)", function()
		openVault()
		GW.frame:ClearAllPoints()
		GW.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		Fake.Fire(gf, "OnShow")
		assert.equal("full", GW.VisitMode())
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 60, -120 } }, GW.frame.points)
	end)

	-- Mutation: drop the InCombat() test from the host.IsActive() branch in GW.ApplyMode.
	it("/swagbag guild view in combat during a full visit saves the setting but keeps this visit full (W3-1)", function()
		openVault()
		A.combat = true
		SB.Slash.Dispatch("guild view")
		assert.equal("view", SB.Config.Get("guildBank.mode"))
		assert.same({ SB.L.GUILD_MODE_SAVED_NEXT }, A.Lines())
		assert.equal("full", GW.VisitMode())
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.equal(GW.frame, tabs[1].parent)
		assert.same({ "TOPLEFT", UIParent, "TOPLEFT", 60, -120 }, GW.frame.points[#GW.frame.points])
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(SB.TinyHost.Parent(), gf.parent, "no restore was waiting for combat")
		closeVault()
		openVault()
		assert.equal("view", GW.VisitMode(), "the next visit uses the new setting")
		assert.equal(UIParent, gf.parent)
	end)

	-- Mutations: drop host.Keep() from the host.IsActive() branch in GW.ApplyMode; or make
	-- GuildButtons.Ensure return false in combat even when every button exists.
	it("a vault closed and reopened inside one fight stays full after combat (W3-1)", function()
		openVault()
		A.combat = true
		closeVault()
		openVault()
		assert.truthy(GW.IsOpen(), "the buttons exist already: nothing to create in combat")
		assert.equal("full", GW.VisitMode())
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(SB.TinyHost.Parent(), gf.parent, "the restore queued at the close was cancelled")
		assert.equal(GW.frame, tabs[1].parent)
		closeVault()
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
	end)

	-- Ruling W3-5: a withdrawal changes a slot (GUILDBANKBAGSLOTS_CHANGED); the withdrawals left
	-- are re-read then too, not only on GUILDBANK_UPDATE_TABS. Mutation: drop GW.ReadTabs() from
	-- the GUILDBANKBAGSLOTS_CHANGED handler.
	it("withdrawals left are re-read on every guild slot change (W3-5)", function()
		openVault()
		answerQueries()
		assert.equal("Mats - 5 withdrawals left today  - deposits go here", GW.labels[1].text)
		A.guild.tabs[1].withdrawals = 4
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		assert.equal("Mats - 4 withdrawals left today  - deposits go here", GW.labels[1].text)
		A.guild.tabs[1].withdrawals = 0
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ "No withdrawals left today from Mats." }, A.Lines())
	end)

	it("lists every viewable tab with its withdrawals left; a tab the player cannot view is left out", function()
		openVault()
		assert.same({ 1, 2 }, GW.order)
		assert.equal("Mats - 5 withdrawals left today (loading...)  - deposits go here", GW.labels[1].text)
		answerQueries()
		assert.equal("Mats - 5 withdrawals left today  - deposits go here", GW.labels[1].text)
		assert.equal("Gear - no withdrawals left today", GW.labels[2].text)
		assert.is_nil(GW.labels[3])
		assert.is_nil(button(3, 1), "no buttons for a tab that is not shown")
		A.guild.tabs[1].withdrawals = -1
		SB.eventFrame:Fire("GUILDBANK_UPDATE_TABS")
		assert.equal("Mats - unlimited withdrawals  - deposits go here", GW.labels[1].text)
	end)

	it("queries the selected tab first, then the others one at a time, and shows what arrived", function()
		A.guild.current = 2
		openVault()
		assert.same({ 2 }, A.guild.queried)
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		A.Advance(0.06)
		assert.same({ 2, 1 }, A.guild.queried)
		answerQueries()
		assert.same({ 2, 1 }, A.guild.queried, "tab 3 is not viewable and never queried")
		assert.equal(Fixtures.HERB, button(1, 1).icon)
		assert.equal(20, button(1, 1).count)
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon)
		assert.is_nil(rawget(button(1, 3), "icon"))
	end)

	it("a query that gets no answer moves on after QUERY_GAP", function()
		openVault()
		A.Advance(GW.QUERY_GAP + 0.01)
		assert.same({ 1, 2 }, A.guild.queried)
	end)

	it("a reopen shows the session's cached contents at once, then asks again", function()
		openVault()
		answerQueries()
		closeVault()
		A.guild.queried = {}
		openVault()
		assert.equal(Fixtures.HERB, button(1, 1).icon, "cached")
		assert.same({ 1 }, A.guild.queried)
	end)

	it("a right-click withdraws to the bags, from any tab by default", function()
		A.guild.tabs[2].withdrawals = 3
		openVault()
		answerQueries()
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({ { 1, 1 }, { 2, 1 } }, A.guild.withdrawn)
		assert.same({}, A.Lines())
	end)

	it("with withdrawAnyTab off, a right-click in a tab Blizzard has not selected says which tab to click", function()
		A.guild.tabs[2].withdrawals = 3
		SB.Config.Set("guildBank.withdrawAnyTab", false)
		openVault()
		answerQueries()
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ "Click the Gear tab on the right first, then right-click the item again." }, A.Lines())
	end)

	it("a tab with no withdrawals left refuses with a message and calls nothing (AC16.2)", function()
		openVault()
		answerQueries()
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ "No withdrawals left today from Gear." }, A.Lines())
	end)

	it("a right-click on an empty slot does nothing", function()
		openVault()
		answerQueries()
		assert.equal("empty", GW.ClickSlot(1, 50, "RightButton"))
		assert.same({}, A.guild.withdrawn)
	end)

	it("left-click and drag pick the stack up; a drop puts the cursor's item into that slot", function()
		openVault()
		answerQueries()
		Fake.Fire(button(1, 2), "OnClick", "LeftButton")
		Fake.Fire(button(1, 1), "OnDragStart")
		Fake.Fire(button(1, 9), "OnReceiveDrag")
		assert.same({ { 1, 2 }, { 1, 1 }, { 1, 9 } }, A.guild.picked)
	end)

	it("a modified click (shift: link to chat) is Blizzard's and does nothing else", function()
		openVault()
		answerQueries()
		A.modified = true
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({}, A.guild.picked)
	end)

	it("hovering shows Blizzard's guild bank tooltip for that slot", function()
		openVault()
		Fake.Fire(button(1, 2), "OnEnter")
		assert.same({ owner = button(1, 2), tab = 1, slot = 2 }, A.tooltip)
		Fake.Fire(button(1, 2), "OnLeave")
		assert.is_nil(A.tooltip)
	end)

	it("deposits go to the tab Blizzard has selected, read on the frame after a tab click", function()
		openVault()
		answerQueries()
		assert.equal("Deposits go to Mats - switch with the tabs on the right", GW.frame.deposit.text)
		A.guild.current = 2
		Fake.Fire(tabs[2].Button, "OnClick")
		A.Advance(0)
		assert.equal("Deposits go to Gear - switch with the tabs on the right", GW.frame.deposit.text)
		assert.equal("Gear - no withdrawals left today  - deposits go here", GW.labels[2].text)
		assert.equal("Mats - 5 withdrawals left today", GW.labels[1].text)
	end)

	it("view mode (the setting): Blizzard's guild bank stays as it is and ours is read-only beside it", function()
		SB.Config.Set("guildBank.mode", "view")
		openVault()
		answerQueries()
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
		assert.same({ "TOPLEFT", gf, "TOPRIGHT", 8, 0 }, GW.frame.points[#GW.frame.points])
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(1, 1), "OnDragStart")
		assert.same({}, A.guild.withdrawn)
		assert.same({}, A.guild.picked)
		assert.same({ SB.L.GUILD_VIEW_ONLY, SB.L.GUILD_VIEW_ONLY }, A.Lines())
	end)

	it("the Blizzard guild bank button shows Blizzard's frame for this visit and hides it again", function()
		openVault()
		Fake.Fire(GW.blizzardButton, "OnClick")
		assert.equal(UIParent, gf.parent)
		assert.equal("view", GW.VisitMode())
		assert.equal("full", SB.Config.Get("guildBank.mode"))
		Fake.Fire(GW.blizzardButton, "OnClick")
		assert.equal(SB.TinyHost.Parent(), gf.parent)
	end)

	it("closing the vault puts Blizzard's frame and its tabs back exactly", function()
		openVault()
		closeVault()
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }, gf.points)
		assert.equal(gf, tabs[2].parent)
		assert.same({ { "TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -17 } }, tabs[2].points)
	end)

	it("Esc hides only SwagBag's window; Blizzard's frame keeps the visit open", function()
		openVault()
		assert.equal("SwagBagGuildBankWindow", UISpecialFrames[1])
		GW.frame:Hide()
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.same({}, gf.calls)
	end)

	it("works when Blizzard's guild bank UI loads on demand during the visit", function()
		A.frames.GuildBankFrame = nil
		gf.shown = false
		SB.eventFrame:Fire("ADDON_LOADED", "Blizzard_GuildBankUI") -- not there yet: nothing to hook
		openVault()
		assert.truthy(GW.IsOpen())
		A.frames.GuildBankFrame = gf
		SB.eventFrame:Fire("ADDON_LOADED", "Blizzard_GuildBankUI")
		gf:Show()
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.equal(1, #gf.hooks.OnShow)
	end)

	it("a visit that starts in combat creates no buttons and leaves Blizzard's guild bank as it is", function()
		A.combat = true
		openVault()
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.is_nil(button(1, 1))
		assert.same({ SB.L.GUILD_COMBAT_WAIT }, A.Lines())
	end)

	it("Safe Mode for the bank also hands the guild bank to Blizzard", function()
		openVault()
		SB.SafeMode.Enable("bank", "manual")
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
	end)

	it("/swagbag guild view|full saves the setting and applies it now", function()
		openVault()
		SB.Slash.Dispatch("guild view")
		assert.equal("view", SB.Config.Get("guildBank.mode"))
		assert.equal(UIParent, gf.parent)
		SB.Slash.Dispatch("guild nonsense")
		assert.same({ SB.L.GUILD_MODE_VIEW, "Use /swagbag guild full or /swagbag guild view (now: view)." }, A.Lines())
	end)

	it("an error in a slot click switches only the bank to Safe Mode and hands the guild bank back", function()
		openVault()
		answerQueries()
		A.GuildWithdraw = function() error("boom") end
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal(UIParent, gf.parent)
	end)

	-- Ruling W3-6: errors in this window's handlers trap with the owning window ("bank").
	it("an error in a tab-click hook switches only the bank to Safe Mode and hands the guild bank back", function()
		openVault()
		A.GuildCurrentTab = function() error("boom") end
		Fake.Fire(tabs[1].Button, "OnClick")
		A.Advance(0)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
	end)
end)

describe("GuildBankWindow load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(FILES)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GuildButtons.lua")
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/GuildBankWindow.lua")
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
