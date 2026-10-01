-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / Guide.lua
-- Step-by-step on-screen guide so a non-programmer can run every spike.
-- Each step: plain-English instructions, a few action buttons, and an
-- automatic "DONE" detector. Back / Skip / Next navigate. The current
-- step survives /reload.
-- =====================================================================
local _, ns = ...

local Pool = ns.Pool

local function C(spike, name)
	local run = ns.Run()
	local s = run and run.spikes[spike]
	local c = s and s.checks and s.checks[name]
	if c then return c.pass, true end
	return nil, false
end
local function Has(spike, name) local _, has = C(spike, name) return has end
local function HasData(spike, key)
	local run = ns.Run()
	local s = run and run.spikes[spike]
	return s and s.data and s.data[key] ~= nil
end

local A = {} -- reusable actions
A.showBag = { "Show / hide spike bag", function() Pool.Toggle() end }
A.grid = { "Grid view", function() Pool.Show(); Pool.LayoutGrid("user") end }
A.sections = { "Sections view", function() Pool.Show(); ns.Layout.Full("user") end }
A.reflow = { "Reflow", function() ns.Layout.Reflow() end }
A.a2 = { "Show / hide A2 strip", function() Pool.ToggleAttrStrip() end }
A.sortBags = { "Sort bags", function() ns.Sort.Bags() end }
A.safeOn = { "Hide Blizzard bags", function() if not ns.Safe_.enabled then ns.Safe_.SetEnabled(true) end end }
A.safeOff = { "Restore Blizzard bags", function() if ns.Safe_.enabled then ns.Safe_.SetEnabled(false) end end }
A.pick = { "Pick test items", function() Pool.Show(); ns.Bank.PickCandidates(); ns.GuideRefresh(true) end }
A.tinyOn = { "Tiny mode ON", function() ns.Bank.SetTiny(true) end }
A.tinyOff = { "Tiny mode OFF", function() ns.Bank.SetTiny(false) end }
A.sortChar = { "Sort character bank", function() ns.Sort.BankCharacter() end }
A.sortAcct = { "Sort warband bank", function() ns.Sort.BankAccount() end }
A.probe = { "Taint probe", function() ns.Bank.TaintProbe() end }
A.reload = { "Reload UI now (saves results)", function() if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end end }
A.status = { "Print results in chat", function() ns.commands.status.fn() end }

local STEPS = {
	-- Station 1: anywhere safe (a city)
	{ id = "start", station = "1. Anywhere (out of combat)",
		text = "Welcome! This is a THROWAWAY test kit for SwagBag. Some tests already ran by themselves when you logged in.\n\nFor each step: read it, do it, and click Next. A green DONE appears when the addon detects you did it. If you can't do a step, click Skip. Nothing here deletes or sells items.",
		done = function() return true end },
	{ id = "show_bag", station = "1. Anywhere (out of combat)",
		text = "Click 'Show / hide spike bag'. A window called 'SBS spike bag' opens with all your bag slots. Hover over a few items: their normal tooltips should appear.",
		actions = { A.showBag }, done = function() return Pool.win:IsShown() end },
	{ id = "use_ooc", station = "1. Anywhere (out of combat)",
		text = "In the SPIKE bag, RIGHT-CLICK something you can use: food, drink, a potion, an elixir, or your Hearthstone (if you use the Hearthstone, just move your character to cancel the cast).\n\nIf a red 'blocked' message shows up, that's a valid result. Click Next.",
		actions = { A.showBag }, done = function() return Has("A_USE", "use_pool_outOfCombat") end },
	{ id = "use_attr", station = "1. Anywhere (out of combat)",
		text = "Click 'Show / hide A2 strip'. A small row of up to 12 usable items appears above the spike bag (these buttons are built a second way). RIGHT-CLICK one of them, e.g. food or Hearthstone (move to cancel).",
		actions = { A.a2 }, done = function() return Has("A_USE", "use_attr_outOfCombat") end },
	{ id = "sections", station = "1. Anywhere (out of combat)",
		text = "Click 'Sections view'. The spike bag regroups into New / Usable / Other / Junk / Free.\n\nNow DRAG any item from the Usable/Other/Junk area onto an empty slot in 'Free' at the bottom. Expected: the item jumps to 'New' at the top, a faded placeholder stays where it was, and nothing else moves.",
		actions = { A.sections, A.grid }, done = function() return Has("D_LAYOUT", "movesOutOfCombatWork") end },
	{ id = "placeholder", station = "1. Anywhere (out of combat)",
		text = "Click once on a faded placeholder icon: nothing should happen. Then click 'Reflow': everything regroups and the placeholders disappear.",
		actions = { A.reflow }, done = function() return Has("D_LAYOUT", "placeholderClickIsHarmless") end },
	{ id = "sort_bags", station = "1. Anywhere (out of combat)",
		text = "Click 'Sort bags'. The game sorts your bags (same as Blizzard's broom button). Wait about 6 seconds until chat says the result.",
		actions = { A.sortBags }, done = function() return HasData("C_SORT", "SortBags") end },
	{ id = "safe_on", station = "1. Anywhere (out of combat)",
		text = "Click 'Hide Blizzard bags'. Then press B (your open-all-bags key). You should see the SPIKE bag, not Blizzard's. Press B again to close it.",
		actions = { A.safeOn }, done = function() return Has("S_SAFEMODE", "suppressedOutOfCombat_hide") end },
	{ id = "safe_off", station = "1. Anywhere (out of combat)",
		text = "Click 'Restore Blizzard bags'. Press B: Blizzard's normal bags should appear. Press B again to close them.",
		actions = { A.safeOff }, done = function() return Has("S_SAFEMODE", "restoredOutOfCombat_hide") end },

	-- Station 2: training dummy
	{ id = "dummy", station = "2. Training dummy (combat)",
		text = "Go to a training dummy (most capital cities have them). Open the spike bag in Sections view, then ATTACK the dummy and keep fighting it. The addon runs some tests by itself when combat starts (watch chat).",
		actions = { A.showBag, A.sections }, done = function() return Has("A_COMBAT", "battery_noErrors") end },
	{ id = "use_combat", station = "2. Training dummy (combat)",
		text = "While still in combat: RIGHT-CLICK a potion (or healthstone, or anything usable in combat) in the SPIKE bag. If you also have one in the A2 strip, right-click it there too.\n\nNo potion? Click Skip.",
		actions = { A.a2 }, done = function() return Has("A_USE", "use_pool_inCombat") end },
	{ id = "move_combat", station = "2. Training dummy (combat)",
		text = "Still in combat: in Sections view, DRAG an item onto an empty 'Free' slot. Expected: it jumps to 'New' and leaves a placeholder, even in combat.",
		actions = { A.sections }, done = function() return Has("D_LAYOUT", "movesInCombatWork") end },
	{ id = "toggle_combat", station = "2. Training dummy (combat)",
		text = "Still in combat: click 'Grid view', then 'Sections view' (switching views during a fight).",
		actions = { A.grid, A.sections }, done = function() return Has("D_LAYOUT", "toggleViewInCombat") end },
	{ id = "safe_combat", station = "2. Training dummy (combat)",
		text = "Still in combat:\n1) click 'Hide Blizzard bags', press B (spike bag should appear), press B again;\n2) click 'Restore Blizzard bags', press B (Blizzard bags should appear);\n3) RIGHT-CLICK a potion in the BLIZZARD bag (skip this part if you have none).",
		actions = { A.safeOn, A.safeOff }, done = function() return Has("A_USE", "use_blizzard_inCombat") or Has("S_SAFEMODE", "restoredInCombat_hide") end },
	{ id = "leave_combat", station = "2. Training dummy (combat)",
		text = "Stop attacking and step away until you are out of combat (a few seconds).",
		done = function() return not InCombatLockdown() and Has("A_COMBAT", "battery_noErrors") end },

	-- Station 3: bank
	{ id = "bank_prep", station = "3. Bank",
		text = function()
			return "Next: the bank. Click 'Pick test items': the addon CHOOSES 3 cheap items (gray junk or cheap trade goods) and marks them 1, 2, 3. Nothing moves yet - in the next steps YOU right-click them one at a time.\n\n" .. ns.Bank.CandidateText()
				.. "\n\nMake sure your bank AND warband bank each have a free slot. If you don't want this, Skip the bank steps."
		end,
		actions = { A.pick }, done = function() return #ns.Bank.candidates > 0 end },
	{ id = "bank_open", station = "3. Bank",
		text = "Go to a banker and open the bank. Keep the spike bag open in GRID view (the bank tabs appear at the bottom of it).",
		actions = { A.showBag, A.grid }, done = function() return ns.bankOpen end },
	{ id = "bank_dep_warband", station = "3. Bank", expectLanding = "Account",
		text = "In BLIZZARD's bank window, click the 'Warband Bank' tab at the bottom.\nThen RIGHT-CLICK ONLY test item 1 (yellow number 1) in the SPIKE bag. It should go into the warband bank. Leave items 2 and 3 alone for now.",
		actions = { A.grid }, done = function() return Has("B_BANK", "step_bank_dep_warband") end },
	{ id = "bank_dep_char", station = "3. Bank", expectLanding = "Character",
		text = "In Blizzard's bank window, click the 'Bank' tab (your character's bank).\nThen RIGHT-CLICK test item 2 in the SPIKE bag. It should go into your character bank.",
		done = function() return Has("B_BANK", "step_bank_dep_char") end },
	{ id = "bank_tiny", station = "3. Bank", expectLanding = "Account",
		text = "Click 'Tiny mode ON'. Blizzard's bank window disappears, but the bank stays open, and a small window 'Blizzard bank tabs' appears near the bottom of the screen.\nClick 'Warband Bank' in that small window, then RIGHT-CLICK test item 3 in the spike bag.\nThen click 'Tiny mode OFF'.",
		-- re-pick so a test item is guaranteed to still be in the bags
		onEnter = function()
			ns.Bank.PickCandidates()
			if #ns.Bank.candidates == 0 then ns.Print("No cheap test item left in your bags - take one out of the bank first.") end
		end,
		actions = { A.tinyOn, A.tinyOff }, done = function() return Has("B_BANK", "step_bank_tiny") end },
	{ id = "bank_sort", station = "3. Bank",
		text = "Click 'Sort character bank', wait ~6 seconds, then click 'Sort warband bank' and wait ~6 seconds. (This tidies your bank the same way Blizzard's broom does.)",
		actions = { A.sortChar, A.sortAcct }, done = function() return HasData("C_SORT", "SortBank_Character") and HasData("C_SORT", "SortBank_Account") end },
	{ id = "bank_withdraw", station = "3. Bank",
		text = "In the SPIKE bag, scroll down to the 'Warband bank tab' section and RIGHT-CLICK test item 1 to take it back out.",
		actions = { A.grid }, done = function() return Has("B_BANK", "withdrawViaSpikeButtons") end },
	{ id = "bank_esc", station = "3. Bank",
		text = "With the bank and the spike bag still open, press ESC once. The bank should close completely.",
		onEnter = function() ns.Bank.StartEscWatch() end,
		done = function() return Has("B_BANK", "escClosesBankInteraction") end },
	{ id = "hearth", station = "3. Bank",
		text = "Walk a few steps away from the banker. Open the spike bag and RIGHT-CLICK your Hearthstone (or any food), then move to cancel. This checks the bank tests didn't break item use.",
		actions = { A.showBag }, done = function() return Has("B_BANK", "itemUseAfterBankTests") end },
	{ id = "bank_reopen", station = "3. Bank (optional)",
		text = "Optional: open the bank once more and check Blizzard's bank window looks normal. Then close it.",
		done = function() return Has("B_BANK", "blizzardBankNormalAfterRestore") end },

	-- Station 4: optional
	{ id = "fishing", station = "4. Optional",
		text = "Optional: if you have Fishing, cast it once and catch something. Otherwise Skip.",
		done = function() return Has("F_FOCUS", "fishingDetectedByChannel") or Has("F_FOCUS", "fishingDetectedByLoot") end },
	{ id = "gather", station = "4. Optional",
		text = "Optional: if you are an herbalist or miner, gather one node. Otherwise Skip.",
		done = function() return Has("F_FOCUS", "gatheringDetected") end },
	{ id = "taint_probe", station = "4. Optional (advanced)",
		text = "Optional, last: at a bank, click 'Taint probe'. It deliberately does something we think is forbidden. Then RIGHT-CLICK any test item in the spike bag, walk away and right-click your Hearthstone in the spike bag. An 'Interface action failed because of an AddOn' message is an expected, useful result. Afterwards do the final step (reload).",
		actions = { A.probe }, done = function() return Has("B_BANK", "itemUseAfterTaintProbe") end },
	{ id = "finish", station = "Finish",
		text = "All done - thank you!\n\nClick 'Reload UI now' (or type /reload, or log out). That writes the results file. Then tell Claude: 'spikes done'.\n\nTip: if you run a Mythic+ key this week with this addon still enabled, it records extra data by itself.",
		actions = { A.status, A.reload }, done = function() return false end },
}

local byId = {}
for i, s in ipairs(STEPS) do s.index = i; byId[s.id] = s end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local g = ns.MakeWindow("SwagBagSpikesGuide", "SwagBag Spikes - guide", 470, 320)
g:ClearAllPoints()
g:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -140)

g.station = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
g.station:SetPoint("TOPLEFT", 8, -24)
g.body = g:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
g.body:SetPoint("TOPLEFT", 10, -42)
g.body:SetPoint("RIGHT", -10, 0)
g.body:SetJustifyH("LEFT")
g.body:SetJustifyV("TOP")
g.body:SetSpacing(2)
g.state = g:CreateFontString(nil, "OVERLAY", "GameFontNormal")
g.state:SetPoint("BOTTOMLEFT", 10, 64)

g.actions = {}
for i = 1, 3 do
	local b = ns.MakeButton(g, "", 148, function(self) if self.fn then self.fn() end ns.GuideRefresh(true) end)
	b:SetPoint("BOTTOMLEFT", 8 + (i - 1) * 152, 36)
	g.actions[i] = b
end

local current = 1
local function Run() return ns.Run() end

local function Enter(i)
	current = math.max(1, math.min(#STEPS, i))
	if SwagBagSpikesDB then SwagBagSpikesDB.guideIndex = current end
	local step = STEPS[current]
	local run = Run()
	if run then
		run.guide[step.id] = run.guide[step.id] or {}
		run.guide[step.id].enteredAt = run.guide[step.id].enteredAt or date("%H:%M:%S")
	end
	ns.Mark("guide:" .. step.id)
	if step.onEnter then ns.Try("guide.onEnter", step.onEnter) end
	ns.GuideRefresh(true)
end

local bBack = ns.MakeButton(g, "Back", 70, function() Enter(current - 1) end)
bBack:SetPoint("BOTTOMLEFT", 8, 8)
local bSkip = ns.MakeButton(g, "Skip", 70, function()
	local step = STEPS[current]
	local run = Run()
	if run then
		run.guide[step.id] = run.guide[step.id] or {}
		run.guide[step.id].skipped = true
	end
	Enter(current + 1)
end)
bSkip:SetPoint("BOTTOMRIGHT", -90, 8)
local bNext = ns.MakeButton(g, "Next", 76, function() Enter(current + 1) end)
bNext:SetPoint("BOTTOMRIGHT", -8, 8)

function ns.GuideCurrentStep() return STEPS[current] end

function ns.GuideMarkDone(id)
	local run = Run()
	if run and byId[id] then
		run.guide[id] = run.guide[id] or {}
		run.guide[id].doneAt = run.guide[id].doneAt or date("%H:%M:%S")
	end
	ns.GuideRefresh()
end

function ns.GuideRefresh(full)
	if not g:IsShown() and not full then return end
	local step = STEPS[current]
	if not step then return end
	if full then
		g.title:SetText(("SwagBag Spikes - step %d of %d"):format(current, #STEPS))
		g.station:SetText("|cffaaaaaa" .. step.station .. "|r")
		local text = type(step.text) == "function" and step.text() or step.text
		g.body:SetText(text)
		for i, b in ipairs(g.actions) do
			local a = step.actions and step.actions[i]
			if a then b:SetText(a[1]); b.fn = a[2]; b:Show() else b.fn = nil; b:Hide() end
		end
		bBack:SetEnabled(current > 1)
	end
	local ok, isDone = pcall(step.done or function() return false end)
	isDone = ok and isDone
	local run = Run()
	if isDone and run then
		run.guide[step.id] = run.guide[step.id] or {}
		run.guide[step.id].doneAt = run.guide[step.id].doneAt or date("%H:%M:%S")
	end
	if isDone then
		g.state:SetText("|cff44ff44DONE - detected. Click Next.|r")
	elseif InCombatLockdown() then
		g.state:SetText("|cffffaa00Waiting... (you are in combat)|r")
	else
		g.state:SetText("|cffaaaaaaWaiting for you to do this step (or Skip).|r")
	end
end

g:SetScript("OnShow", function() ns.GuideRefresh(true) end)

-- periodic light refresh while the guide is open (status line only)
local ticker
g:HookScript("OnShow", function()
	if ticker then ticker:Cancel() end
	ticker = C_Timer.NewTicker(1, function() ns.GuideRefresh() end)
end)
g:HookScript("OnHide", function() if ticker then ticker:Cancel() ticker = nil end end)

ns.OnLogin(function()
	local saved = SwagBagSpikesDB and SwagBagSpikesDB.guideIndex
	current = (type(saved) == "number" and STEPS[saved]) and saved or 1
	C_Timer.After(3, function()
		g:Show()
		ns.GuideRefresh(true)
	end)
end)

ns.Command("guide", "open the step-by-step guide", function() if g:IsShown() then g:Hide() else g:Show() end end)
ns.Command("step", "jump to guide step by number, e.g. /sbs step 16", function(arg)
	-- accept "6", "#6", "step6" or a step id like "bank_tiny"
	local n = tonumber((arg or ""):match("%d+") or "")
	if not n then
		for i, s in ipairs(STEPS) do if s.id == arg then n = i end end
	end
	if not n then
		ns.Print(("Usage: /sbs step 6  (a number from 1 to %d). You typed: '%s'"):format(#STEPS, tostring(arg)))
		return
	end
	g:Show(); Enter(n)
	ns.GuideRefresh(true)
	ns.Print(("Jumped to step %d of %d: %s"):format(current, #STEPS, STEPS[current].id))
end)
