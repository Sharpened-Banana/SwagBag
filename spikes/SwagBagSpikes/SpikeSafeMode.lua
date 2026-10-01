-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / SpikeSafeMode.lua
-- Spike S (critique B, "frame suppression" half): hide Blizzard's bag
-- frames and route the bag keys to the spike bag, then restore Blizzard
-- bags WITHOUT /reload - in and out of combat.
-- Two methods (switch with /sbs safemethod hide|reparent):
--   hide     : HookScript(OnShow) on ContainerFrame1..N and
--              ContainerFrameCombinedBags -> immediately :Hide() them.
--   reparent : SetParent() those frames to a hidden frame (Bagnon style),
--              restore original parent on disable.
-- Bag keys: hooksecurefunc on ToggleAllBags / ToggleBackpack / OpenAllBags
-- / CloseAllBags; the hooks only act while suppression is on. We never
-- call OpenAllBags()/ToggleAllBags() ourselves.
-- =====================================================================
local _, ns = ...

ns.RegisterSpike("S_SAFEMODE", "Hide/restore Blizzard bags without /reload", "B (frames half)",
	"Whether 'Safe Mode' (fall back to Blizzard bags live) is feasible in and out of combat")

local S = { enabled = false, method = "hide", origParents = {}, toggles = 0, everToggled = false }
ns.Safe_ = S
local hidden = CreateFrame("Frame")
hidden:Hide()

local function BlizzFrames()
	local t = {}
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		local f = _G["ContainerFrame" .. i]
		if f then t[#t + 1] = f end
	end
	if ContainerFrameCombinedBags then t[#t + 1] = ContainerFrameCombinedBags end
	return t
end

local function AnyBlizzVisible()
	for _, f in ipairs(BlizzFrames()) do
		if f:IsVisible() then return true, f:GetName() end
	end
	return false
end

function S.SetEnabled(on)
	local start = GetTime()
	local t0 = debugprofilestop()
	ns.Mark("safe:" .. (on and "suppressBlizzard" or "restoreBlizzard") .. ":" .. S.method)
	local errors = {}
	for _, f in ipairs(BlizzFrames()) do
		local ok, err = pcall(function()
			if S.method == "reparent" then
				if on then
					S.origParents[f] = S.origParents[f] or f:GetParent()
					f:SetParent(hidden)
				elseif S.origParents[f] then
					f:SetParent(S.origParents[f])
				end
			else
				if on and f:IsShown() then f:Hide() end
			end
		end)
		if not ok then errors[#errors + 1] = tostring(err) end
	end
	S.enabled = on
	S.toggles = S.toggles + 1
	S.everToggled = true
	ns.context.safeModeToggled = true
	ns.context.safeModeOn = on
	if not on then ns.Pool.Hide() end
	local ms = debugprofilestop() - t0
	local inCombat = ns.InCombat()
	local rec = { on = on, method = S.method, combat = inCombat, ms = ms, errors = errors }
	local d = ns.Spike("S_SAFEMODE").data
	d.toggles = d.toggles or {}
	table.insert(d.toggles, ns.Safe(rec))
	ns.Print(("Safe Mode: Blizzard bags %s (method %s)%s"):format(on and "|cffff8800HIDDEN|r - press B for the spike bag" or "|cff44ff44RESTORED|r - press B for Blizzard bags",
		S.method, inCombat and " [in combat]" or ""))
	C_Timer.After(1, function()
		local blocked = ns.BlockedMineSince(start)
		local name = (inCombat and "toggleInCombat" or "toggleOutOfCombat") .. "_" .. S.method
		ns.Check("S_SAFEMODE", name, #errors == 0 and blocked == 0, { errors = errors, blocked = blocked, ms = ms })
	end)
end

-- Bag-key hooks. Debounce so ToggleAllBags->internal calls count once per frame.
local lastToggle = 0
local function OnBagKey(source)
	-- record what happened after Blizzard's own code ran (next frame)
	C_Timer.After(0, function()
		local blizzVisible, which = AnyBlizzVisible()
		local ourShown = ns.Pool.win:IsShown()
		local rec = { source = source, suppress = S.enabled, method = S.method, combat = ns.InCombat(),
			blizzVisible = blizzVisible, blizzFrame = which, spikeBagShown = ourShown }
		ns.Log("bagKey", rec)
		local d = ns.Spike("S_SAFEMODE").data
		d.bagKeys = d.bagKeys or {}
		if #d.bagKeys < 60 then table.insert(d.bagKeys, ns.Safe(rec)) end
		local ctx = (ns.InCombat() and "InCombat" or "OutOfCombat") .. "_" .. S.method
		if S.enabled then
			-- correct when Blizzard bags stay hidden (ours may be opening or closing)
			ns.Check("S_SAFEMODE", "suppressed" .. ctx, not blizzVisible, rec)
		elseif S.everToggled and blizzVisible then
			ns.Check("S_SAFEMODE", "restored" .. ctx, true, rec)
		end
	end)
	if not S.enabled then return end
	local now = GetTime()
	if now == lastToggle then return end
	lastToggle = now
	ns.Pool.Toggle()
end

local function InstallHooks()
	hooksecurefunc("ToggleAllBags", function() ns.Try("hook:ToggleAllBags", OnBagKey, "ToggleAllBags") end)
	hooksecurefunc("ToggleBackpack", function() ns.Try("hook:ToggleBackpack", OnBagKey, "ToggleBackpack") end)
	hooksecurefunc("OpenAllBags", function()
		if S.enabled then ns.Try("hook:OpenAllBags", ns.Pool.Show) end
	end)
	hooksecurefunc("CloseAllBags", function()
		if S.enabled then ns.Try("hook:CloseAllBags", ns.Pool.Hide) end
	end)
	for _, f in ipairs(BlizzFrames()) do
		f:HookScript("OnShow", function(self)
			if S.enabled and S.method == "hide" then
				local ok = pcall(self.Hide, self)
				if not ok then ns.Log("blizzHideFailed", { frame = self:GetName() }) end
			end
		end)
	end
	ns.Data("S_SAFEMODE", "hookedFrames", #BlizzFrames())
end
ns.OnLogin(function() ns.Try("SafeMode.InstallHooks", InstallHooks) end)

function S.Toggle() S.SetEnabled(not S.enabled) end

ns.Command("safe", "toggle Safe-Mode test: hide/restore Blizzard bags (spike S)", function() S.Toggle() end)
ns.commands.s = ns.commands.safe
ns.Command("safemethod", "set suppression method: hide | reparent", function(arg)
	arg = (arg or ""):lower()
	if arg ~= "hide" and arg ~= "reparent" then ns.Print("use: /sbs safemethod hide  OR  /sbs safemethod reparent") return end
	if S.enabled then S.SetEnabled(false) end
	S.method = arg
	ns.Print("Safe Mode method = " .. arg)
end)
