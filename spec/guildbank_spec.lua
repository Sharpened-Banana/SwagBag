-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The guild bank window (spec F16, check G1): tiny mode, re-hosted tabs, withdraw / pickup /
-- drop through Blizzard's own guild bank functions, the read-only selected tab, view mode,
-- one group per tab with its own sections, on-demand queries, the session cache, live
-- changes, its own search, and the per-guild snapshot.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

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
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		Env.PaintGlobals()
		gf, tabs = blizzardGuildBank(A)
		A.guild.tabs = {
			{ tab = 1, name = "Mats", withdrawals = 5 },
			{ tab = 2, name = "Gear", withdrawals = 0 },
			{ tab = 3, name = "Officers", viewable = false },
		}
		A.guild.slots = { [1] = { [1] = { itemID = Fixtures.HERB, count = 20 }, [2] = { itemID = Fixtures.ORE, count = 5 } },
			[2] = { [1] = { itemID = Fixtures.BOE_RING } } }
		A.guild.current = 1
		GW = Env.LoadGuild(SB)
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
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

	local function header(id)
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId == id then
				return h
			end
		end
	end

	local function at(b)
		local p = b.points[#b.points]
		return { p[4], p[5] }
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
		assert.equal("- Mats (2) - 5 withdrawals left today  - deposits go here", header("#tab1").text.text)
		A.guild.tabs[1].withdrawals = 4
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		assert.equal("- Mats (2) - 4 withdrawals left today  - deposits go here", header("#tab1").text.text)
		A.guild.tabs[1].withdrawals = 0
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ "No withdrawals left today from Mats." }, A.Lines())
	end)

	it("lists every viewable tab with its withdrawals left; a tab the player cannot view is left out", function()
		openVault()
		assert.equal("- Mats (0) - 5 withdrawals left today (loading...)  - deposits go here", header("#tab1").text.text)
		answerQueries()
		assert.equal("- Mats (2) - 5 withdrawals left today  - deposits go here", header("#tab1").text.text)
		assert.equal("- Gear (1) - no withdrawals left today", header("#tab2").text.text)
		assert.is_nil(header("#tab3"))
		assert.is_nil(button(3, 1), "no buttons for a tab that is not shown")
		A.guild.tabs[1].withdrawals = -1
		SB.eventFrame:Fire("GUILDBANK_UPDATE_TABS")
		assert.equal("- Mats (2) - unlimited withdrawals  - deposits go here", header("#tab1").text.text)
	end)

	it("each tab is a group with its own sections: the tab's items sit in their categories", function()
		openVault()
		answerQueries()
		assert.truthy(header("tab1:c_herbs"))
		assert.truthy(header("tab1:c_ore"))
		assert.truthy(header("tab2:c_boe"))
		assert.equal("load", GW.view.stats.lastLayoutReason)
		assert.truthy(at(button(2, 1))[2] < at(button(1, 98))[2], "tab 2 below tab 1")
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

	it("a query that gets no answer moves on after QUERY_GAP and is asked once more at the end", function()
		openVault()
		A.Advance(GW.QUERY_GAP + 0.01)
		assert.same({ 1, 2 }, A.guild.queried)
		A.Advance(3 * GW.QUERY_GAP)
		assert.same({ 1, 2, 1, 2 }, A.guild.queried)
		A.Advance(5)
		assert.equal(4, #A.guild.queried, "only once more")
	end)

	it("a reopen shows the session's cached contents at once; a tab whose answer is on its way is not read", function()
		openVault()
		answerQueries()
		closeVault()
		A.guild.queried = {}
		A.guild.slots[2] = {} -- what the client returns for tab 2 before its new answer arrives
		openVault()
		assert.equal(Fixtures.HERB, button(1, 1).icon, "cached")
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon, "cached")
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED") -- tab 1's answer
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon, "tab 2 has not answered yet: not read")
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		assert.same({ 1 }, A.guild.queried)
	end)

	it("while open, an item taken by someone else leaves a placeholder; a deposit goes to that tab's New", function()
		openVault()
		answerQueries()
		local herbAt = at(button(1, 1))
		A.guild.slots[1][1] = nil
		A.guild.slots[1][7] = { itemID = Fixtures.FLASK, count = 3 }
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		assert.equal(1, #SB.Buttons.placeholdersInUse)
		assert.same(herbAt, { SB.Buttons.placeholdersInUse[1].points[1][4], SB.Buttons.placeholdersInUse[1].points[1][5] })
		assert.equal(header("tab1:new").points[1][5] - 20, at(button(1, 7))[2], "the deposit is first in New")
	end)

	-- Ruling W3-10: off until check G1 proves the client withdraws from the tab it is given.
	-- Mutation: default guildBank.withdrawAnyTab = true in Config.Defaults.
	it("withdrawAnyTab is off by default: a right-click withdraws from the tab Blizzard has selected", function()
		assert.equal(false, SB.Config.Get("guildBank.withdrawAnyTab"))
		openVault()
		answerQueries()
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.same({ { 1, 1 } }, A.guild.withdrawn)
		assert.same({}, A.Lines())
	end)

	it("/swagbag guild anytab on: a right-click withdraws from any tab; off turns it back off", function()
		A.guild.tabs[2].withdrawals = 3
		SB.Slash.Dispatch("guild anytab on")
		assert.equal(true, SB.Config.Get("guildBank.withdrawAnyTab"))
		openVault()
		answerQueries()
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({ { 1, 1 }, { 2, 1 } }, A.guild.withdrawn)
		SB.Slash.Dispatch("guild anytab off")
		assert.equal(false, SB.Config.Get("guildBank.withdrawAnyTab"))
		SB.Slash.Dispatch("guild anytab maybe")
		assert.same({ SB.L.GUILD_ANYTAB_ON, SB.L.GUILD_ANYTAB_OFF,
			"Use /swagbag guild anytab on or /swagbag guild anytab off (now: off)." }, A.Lines())
	end)

	-- Mutation: delete the A.GuildWithdraw / A.GuildPickup result checks in ClickSlot and DragSlot.
	it("a withdraw or pickup the client refuses says so in chat (P2)", function()
		openVault()
		answerQueries()
		A.GuildWithdraw = function() return false end
		A.GuildPickup = function() return false end
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(1, 2), "OnDragStart")
		assert.same({ SB.L.GUILD_ACTION_FAILED, SB.L.GUILD_ACTION_FAILED }, A.Lines())
	end)

	it("with withdrawAnyTab off, a right-click in a tab Blizzard has not selected says which tab to click", function()
		A.guild.tabs[2].withdrawals = 3
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

	it("deposits go to the tab Blizzard has selected, read on the frame after a tab click; its header says so", function()
		openVault()
		answerQueries()
		assert.equal("Deposits go to Mats - switch with the tabs on the right", GW.frame.deposit.text)
		A.guild.current = 2
		Fake.Fire(tabs[2].Button, "OnClick")
		A.Advance(0)
		assert.equal("Deposits go to Gear - switch with the tabs on the right", GW.frame.deposit.text)
		assert.equal("- Gear (1) - no withdrawals left today  - deposits go here", header("#tab2").text.text)
		assert.equal("- Mats (2) - 5 withdrawals left today", header("#tab1").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#tab2").bg.calls.SetColorTexture)
	end)

	it("the guild bank's search box dims guild slots only", function()
		openVault()
		answerQueries()
		GW.searchBox.editBox:SetText("herb")
		Fake.Fire(GW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
		assert.equal(1, button(1, 1).alpha)
		assert.equal(SB.Buttons.DIM_ALPHA, button(1, 2).alpha)
		assert.equal("", SB.Search.text)
	end)

	it("a snapshot of the tabs read is saved per guild after an answer and when the vault closes (AC16.4)", function()
		openVault()
		answerQueries()
		A.Advance(1.1)
		local g = SB.Config.db.guilds["Tidewatch-Argent Dawn"]
		assert.same({ "Mats", "Gear" }, { g.tabs[1], g.tabs[2] })
		assert.equal("1:item:" .. Fixtures.HERB .. ";20\n2:item:" .. Fixtures.ORE .. ";5\n", g.snapshot.containers[1].s)
		A.guild.slots[1][3] = { itemID = Fixtures.JUNK, count = 2 }
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		closeVault()
		assert.truthy(g.snapshot.containers[1].s:find("3:item:" .. Fixtures.JUNK .. ";2", 1, true))
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

	it("closing the vault puts Blizzard's frame and its tabs back exactly and forgets the layout", function()
		openVault()
		answerQueries()
		closeVault()
		assert.falsy(GW.IsOpen())
		assert.falsy(GW.view.IsOpen())
		assert.falsy(button(1, 1).shown)
		assert.equal(UIParent, gf.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }, gf.points)
		assert.equal(gf, tabs[2].parent)
		assert.same({ { "TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -17 } }, tabs[2].points)
	end)

	-- Fix round 1: a hidden SwagBag window must not leave an invisible open vault that eats bag
	-- right-clicks. Mutation: delete the host.Restore() in the OnHide handler.
	it("Esc or the X hides SwagBag's window and makes Blizzard's guild bank visible again (visit still open)", function()
		openVault()
		assert.equal("SwagBagGuildBankWindow", UISpecialFrames[#UISpecialFrames])
		GW.frame:Hide()
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
		assert.equal(true, gf.shown)
		assert.same({}, gf.calls)
		Fake.Fire(gf, "OnShow") -- a later signal for the same visit does not shrink it again
		assert.equal(UIParent, gf.parent)
		assert.falsy(GW.IsOpen())
	end)

	it("hiding SwagBag's window in combat makes Blizzard's guild bank visible as soon as combat ends", function()
		openVault()
		A.combat = true
		GW.frame:Hide()
		assert.equal(SB.TinyHost.Parent(), gf.parent, "parents never change in combat")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(UIParent, gf.parent)
	end)

	-- Ruling W3-3: Safe Mode for the bank keeps every guild visit Blizzard's, whichever signal
	-- arrives first. Mutation: delete the frame:IsShown() / Safe Mode guard at the top of GW.ApplyMode.
	it("Safe Mode on before the visit: OnShow and the vault event leave Blizzard's guild bank as it is", function()
		SB.SafeMode.Enable("bank", "manual")
		Fake.Fire(gf, "OnShow")
		openVault()
		SB.eventFrame:Fire("GUILDBANKFRAME_OPENED")
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
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

	it("nothing moves while Blizzard's guild bank frame is still hidden; it is shrunk once Blizzard shows it", function()
		gf.shown = false
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
		assert.truthy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
		gf:Show()
		assert.equal(SB.TinyHost.Parent(), gf.parent)
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

	-- Fix round 1 (rulings W3-30 .. W3-34, controller items 6-8).
	local KEY = "Tidewatch-Argent Dawn"
	local function fire()
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
	end

	local function loadingText(id)
		return header(id).text.text:find(SB.L.GUILD_TAB_LOADING, 1, true) ~= nil
	end

	-- Ruling W3-30. Mutation: in GW.OnQueryEvent, mark the tab answered on every event
	-- (`if true then GW.answered[tab] = true`).
	it("W3-30: a foreign event while tab 2 is queried, tab 2 still reading empty, is not tab 2's answer", function()
		local gear = A.guild.slots[2]
		A.guild.slots[2] = {}
		openVault()
		fire() -- tab 1's answer
		A.Advance(0.06)
		assert.same({ 1, 2 }, A.guild.queried)
		fire() -- someone else's change; tab 2's answer is still on its way
		assert.truthy(loadingText("#tab2"), "tab 2 still says loading")
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		GW.SaveSnapshot()
		local g = SB.Config.db.guilds[KEY]
		assert.truthy(g.snapshot.containers[1])
		assert.is_nil(g.snapshot.containers[2], "nothing saved for tab 2")
		A.guild.slots[2] = gear
		fire() -- tab 2's real answer
		assert.falsy(loadingText("#tab2"))
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		assert.equal(header("tab2:c_boe").points[1][5] - 20, at(button(2, 1))[2], "the ring sits in its category")
		assert.equal("- New (0)", header("tab2:new").text.text, "not in New")
	end)

	-- Mutation: in GW.OnQueryEvent, never accept an empty read (`elseif false then`).
	it("W3-30: a truly empty tab is known empty once its own retry reads empty too", function()
		A.guild.slots[2] = {}
		openVault()
		fire()
		A.Advance(0.06)
		fire() -- tab 2's answer: empty, not believed yet
		assert.truthy(loadingText("#tab2"))
		A.Advance(GW.QUERY_GAP)
		assert.same({ 1, 2, 2 }, A.guild.queried, "asked once more")
		fire() -- the retry's answer: empty again
		assert.equal("- Gear (0) - no withdrawals left today", header("#tab2").text.text)
		assert.equal(0, #SB.Buttons.placeholdersInUse)
	end)

	-- Ruling W3-31. Mutation: in GW.OnQueryEvent, believe the first empty read
	-- (`elseif true then` for the known-empty branch).
	it("W3-31: an unconfirmed empty read never replaces a cached tab with items, nor its saved snapshot", function()
		openVault()
		answerQueries()
		closeVault()
		local g = SB.Config.db.guilds[KEY]
		local saved = g.snapshot.containers[2].s
		assert.truthy(saved:find("item:" .. Fixtures.BOE_RING, 1, true))
		A.guild.slots[2] = {}
		openVault()
		fire()
		A.Advance(0.06)
		fire() -- tab 2 reads empty: unconfirmed
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon)
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		closeVault()
		A.Advance(2)
		assert.equal(saved, g.snapshot.containers[2].s)
	end)

	-- Mutation: delete the `new and not hasItem(new) and hasItem(GW.cache[tab]) ...` guard in GW.Refresh.
	it("W3-31: a tab that answered and later reads empty is asked again; only a confirmed empty read empties it", function()
		openVault()
		answerQueries()
		A.guild.queried = {}
		A.guild.slots[2] = {}
		fire()
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon, "kept")
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		assert.same({ 2 }, A.guild.queried, "asked again")
		fire() -- its answer: empty, not believed yet
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		A.Advance(GW.QUERY_GAP)
		assert.same({ 2, 2 }, A.guild.queried)
		fire() -- the retry reads empty too: the ring really left
		assert.equal(1, #SB.Buttons.placeholdersInUse)
	end)

	-- Ruling W3-32. Mutations: delete the `key ~= GW.cacheKey` clear in GW.Open; or save under
	-- SB.Adapter.GuildKey() instead of GW.cacheKey in GW.SaveSnapshot.
	it("W3-32: after a guild switch nothing of the old guild is shown or saved under the new one", function()
		openVault()
		answerQueries()
		closeVault()
		A.guild.key = "Other-Realm"
		A.Advance(2) -- the snapshot timer of the old visit runs out after the switch
		assert.is_nil(SB.Config.db.guilds["Other-Realm"], "the old guild's tabs are not saved under the new one")
		A.guild.slots = { [1] = { [3] = { itemID = Fixtures.JUNK, count = 2 } }, [2] = { [4] = { itemID = Fixtures.FLASK } } }
		openVault()
		for _, b in ipairs({ button(1, 1), button(1, 2), button(2, 1) }) do
			assert.is_nil(rawget(b, "icon"))
		end
		assert.truthy(loadingText("#tab1"))
		answerQueries()
		assert.equal(Fixtures.JUNK, button(1, 3).icon)
		assert.is_nil(rawget(button(1, 1), "icon"))
		closeVault()
		A.Advance(2)
		local other = SB.Config.db.guilds["Other-Realm"]
		assert.truthy(other.snapshot.containers[1].s:find("item:" .. Fixtures.JUNK, 1, true))
		for _, c in pairs(other.snapshot.containers) do
			for _, id in ipairs({ Fixtures.HERB, Fixtures.ORE, Fixtures.BOE_RING }) do
				assert.falsy(c.s:find("item:" .. id .. ";", 1, true))
			end
		end
	end)

	-- Mutation: delete the PLAYER_GUILD_UPDATE handler's GW.ClearCache(nil) while closed.
	it("W3-32: PLAYER_GUILD_UPDATE forgets the cached contents", function()
		openVault()
		answerQueries()
		closeVault()
		SB.eventFrame:Fire("PLAYER_GUILD_UPDATE")
		openVault()
		assert.is_nil(rawget(button(1, 1), "icon"))
		assert.truthy(loadingText("#tab1"))
	end)

	-- Ruling W3-33. Mutation: make `loading(tab)` return false.
	it("W3-33: right-click, left-click, drag and drop on a tab that has not answered refuse with a chat line", function()
		openVault() -- tab 1 is asked; no answer yet
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(1, 1), "OnClick", "LeftButton")
		Fake.Fire(button(1, 2), "OnDragStart")
		Fake.Fire(button(1, 9), "OnReceiveDrag")
		assert.same({}, A.guild.withdrawn)
		assert.same({}, A.guild.picked)
		local line = "Still loading Mats - try again in a moment."
		assert.same({ line, line, line, line }, A.Lines())
	end)

	it("W3-33: a reopened tab that shows cached items refuses a withdraw until its answer arrives", function()
		A.guild.tabs[2].withdrawals = 3
		SB.Slash.Dispatch("guild anytab on")
		openVault()
		answerQueries()
		closeVault()
		openVault()
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon, "cached")
		local n = #A.Lines()
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.equal("Still loading Gear - try again in a moment.", A.Lines()[n + 1])
		answerQueries()
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({ { 2, 1 } }, A.guild.withdrawn)
	end)

	-- Mutation: delete the `not sameItem(info, A.GuildSlot(tab, slot))` check in GW.ClickSlot.
	it("W3-33: a right-click withdraws only if the slot still holds what is shown; else it refreshes and says so", function()
		openVault()
		answerQueries()
		A.guild.slots[1][1] = { itemID = Fixtures.ORE, count = 1 } -- changed; its event has not arrived
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ SB.L.GUILD_SLOT_CHANGED }, A.Lines())
		assert.equal(Fixtures.ORE, button(1, 1).icon, "refreshed")
		A.guild.slots[1][2] = nil -- taken; its event has not arrived
		Fake.Fire(button(1, 2), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ SB.L.GUILD_SLOT_CHANGED, SB.L.GUILD_SLOT_CHANGED }, A.Lines())
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.same({ { 1, 1 } }, A.guild.withdrawn, "it matches what is shown now")
	end)

	-- Ruling W3-34. Mutation: iterate `pairs(GW.cache)` in GW.SaveSnapshot with no answered / order test.
	it("W3-34: a tab that did not answer this visit keeps its saved snapshot", function()
		openVault()
		answerQueries()
		closeVault()
		local g = SB.Config.db.guilds[KEY]
		g.snapshot.containers[2] = { s = "earlier" }
		openVault()
		fire() -- tab 1 only
		closeVault()
		A.Advance(2)
		assert.equal("earlier", g.snapshot.containers[2].s)
		assert.truthy(g.snapshot.containers[1].s:find("item:" .. Fixtures.HERB, 1, true))
	end)

	it("W3-34: a tab that is no longer viewable is left out of the snapshot", function()
		openVault()
		answerQueries()
		GW.SaveSnapshot()
		local g = SB.Config.db.guilds[KEY]
		g.snapshot.containers[2] = { s = "earlier" }
		A.guild.tabs[2].viewable = false
		SB.eventFrame:Fire("GUILDBANK_UPDATE_TABS")
		closeVault()
		A.Advance(2)
		assert.equal("earlier", g.snapshot.containers[2].s)
	end)

	-- Mutation: delete the A.GuildPickup result check in GW.ClickSlot (the left-click path).
	it("a left-click pickup the client refuses says so in chat (P2)", function()
		openVault()
		answerQueries()
		A.GuildPickup = function() return false end
		Fake.Fire(button(1, 2), "OnClick", "LeftButton")
		assert.same({ SB.L.GUILD_ACTION_FAILED }, A.Lines())
	end)

	-- Spec 4.3 rule 5 / D17. Mutation: GW.view.RequestLayout("load") -> GW.view.Layout("load") in GW.Refresh.
	it("a tab read for the first time is laid out only once the mouse has left the items (300 ms retry)", function()
		openVault()
		GW.scroll.mouseOver = true
		fire() -- tab 1's answer
		assert.equal("open", GW.view.stats.lastLayoutReason)
		assert.is_nil(header("tab1:c_herbs"))
		A.Advance(0.29)
		assert.equal("open", GW.view.stats.lastLayoutReason, "held while the mouse is over")
		GW.scroll.mouseOver = false
		A.Advance(0.02)
		assert.equal("load", GW.view.stats.lastLayoutReason)
		assert.truthy(header("tab1:c_herbs"))
	end)
end)

describe("GuildBankWindow load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		local ok, err = pcall(Env.LoadGuild, SB)
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
