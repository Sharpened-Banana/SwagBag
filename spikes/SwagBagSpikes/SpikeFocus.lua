-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / SpikeFocus.lua
-- Spike F2 (new, for "focus modes"): can SwagBag cheaply tell what the
-- player is doing (M+ key, raid/dungeon, fishing, gathering)?
-- Passive logger, runs all session. Every handler is timed so we can
-- prove it is cheap. Nothing is changed in the game.
-- Signals:
--   M+      : C_ChallengeMode.IsChallengeModeActive(), CHALLENGE_MODE_*,
--             C_RestrictedActions.IsAddOnRestrictionActive(ChallengeMode)
--   instance: IsInInstance(), GetInstanceInfo()
--   fishing : channel spell == Fishing (name match), IsFishingLoot()
--   gather  : LOOT_READY whose source GUID is a GameObject (node) and the
--             spell cast just before it (recorded so we learn gather IDs)
-- =====================================================================
local _, ns = ...

ns.RegisterSpike("F_FOCUS", "Activity detection for focus modes (M+, fishing, gathering)", "new (user request)",
	"Whether focus modes can switch automatically, and from which signals")

local F = { cost = { n = 0, total = 0, worst = 0 }, lastSpell = nil, lastChannel = nil }
ns.Focus = F
local FISHING_SPELL_ID = 131474 -- assumption: modern "Fishing" cast; we also match by name

local function Timed(fn)
	return function(...)
		local t0 = debugprofilestop()
		fn(...)
		local dt = debugprofilestop() - t0
		local c = F.cost
		c.n = c.n + 1
		c.total = c.total + dt
		if dt > c.worst then c.worst = dt end
	end
end

local function RestrictionState()
	local out = {}
	local api = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
	local E = Enum and Enum.AddOnRestrictionType
	if api and E then
		for k, v in pairs(E) do
			local ok, active = pcall(api, v)
			-- keep the error text: it tells us the real signature
			if ok then out[k] = active else out[k] = "error: " .. tostring(active) end
		end
	end
	return out
end

function F.Snapshot()
	local s = {}
	local ok1, inInst, instType = pcall(IsInInstance)
	s.inInstance, s.instanceType = ok1 and inInst, ok1 and instType
	local ok2, name, _, difficultyID, difficultyName = pcall(GetInstanceInfo)
	if ok2 then s.instanceName, s.difficultyID, s.difficultyName = name, difficultyID, difficultyName end
	if C_ChallengeMode then
		local okA, active = pcall(C_ChallengeMode.IsChallengeModeActive)
		s.challengeModeActive = okA and active
		local okM, mapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
		s.challengeMapID = okM and mapID
		local okK, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
		s.keystoneLevel = okK and level
	end
	s.restrictions = RestrictionState()
	if C_Map and C_Map.GetBestMapForUnit then
		local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
		s.uiMapID = okMap and mapID
	end
	return ns.Safe(s)
end

function F.Guess(s)
	s = s or F.Snapshot()
	if s.challengeModeActive == true or (s.restrictions and s.restrictions.ChallengeMode == true) then return "mplus" end
	if s.instanceType == "raid" then return "raid" end
	if s.instanceType == "party" then return "dungeon" end
	if s.instanceType == "pvp" or s.instanceType == "arena" then return "pvp" end
	if s.instanceType == "scenario" then return "scenario/delve" end
	if F.lastChannel and F.lastChannel.fishing and GetTime() - F.lastChannel.t < 30 then return "fishing" end
	if F.lastGather and GetTime() - F.lastGather < 60 then return "gathering" end
	return "world"
end

local function LogCtx(trigger)
	local s = F.Snapshot()
	s.trigger = trigger
	s.guess = F.Guess(s)
	ns.Log("focusContext", s)
	local d = ns.Spike("F_FOCUS").data
	d.contexts = d.contexts or {}
	if #d.contexts < 60 then table.insert(d.contexts, s) end
	return s
end

ns.OnLogin(function()
	local profs = {}
	if GetProfessions and GetProfessionInfo then
		local list = { GetProfessions() }
		for i = 1, 5 do
			local idx = list[i]
			if idx then
				local ok, name, _, rank, maxRank, _, _, skillLine = pcall(GetProfessionInfo, idx)
				if ok then profs[#profs + 1] = { name = name, rank = rank, maxRank = maxRank, skillLine = skillLine } end
			end
		end
	end
	ns.Data("F_FOCUS", "professions", profs)
	local okN, fishName = pcall(C_Spell.GetSpellName, FISHING_SPELL_ID)
	F.fishingName = okN and fishName or nil
	ns.Data("F_FOCUS", "fishingSpellName", F.fishingName)
	LogCtx("login")
end)

ns.On("PLAYER_ENTERING_WORLD", Timed(function() LogCtx("PLAYER_ENTERING_WORLD") end))
ns.On("ZONE_CHANGED_NEW_AREA", Timed(function() LogCtx("ZONE_CHANGED_NEW_AREA") end))
ns.On("ENCOUNTER_START", Timed(function() LogCtx("ENCOUNTER_START") end))

ns.On("CHALLENGE_MODE_START", Timed(function()
	local s = LogCtx("CHALLENGE_MODE_START")
	ns.Check("F_FOCUS", "mplusDetected", s.challengeModeActive == true or (s.restrictions and s.restrictions.ChallengeMode == true), s)
	-- does the M+ addon restriction block our harmless frame ops?
	if ns.Pool and ns.Pool.created then
		local start = GetTime()
		local ok = pcall(function()
			local b = ns.Pool.all[#ns.Pool.all]
			b:ClearAllPoints(); b:SetPoint("TOPLEFT", ns.Pool.child, "TOPLEFT", 0, 0); b:Show(); b:Hide()
		end)
		C_Timer.After(1, function()
			ns.Check("F_FOCUS", "frameOpsAllowedDuringMplus", ok and ns.BlockedMineSince(start) == 0, { ok = ok })
		end)
	end
end))
ns.On("CHALLENGE_MODE_COMPLETED", Timed(function() LogCtx("CHALLENGE_MODE_COMPLETED") end))
ns.On("CHALLENGE_MODE_RESET", Timed(function() LogCtx("CHALLENGE_MODE_RESET") end))
ns.On("ADDON_RESTRICTION_STATE_CHANGED", Timed(function(_, rtype, state)
	ns.Log("restrictionChanged", { type = rtype, state = state })
	local d = ns.Spike("F_FOCUS").data
	d.restrictionChanges = (d.restrictionChanges or 0) + 1
	d.restrictionTypesSeen = d.restrictionTypesSeen or {}
	if not ns.IsSecret(rtype) then d.restrictionTypesSeen[tostring(rtype)] = true end
end))

ns.On("UNIT_SPELLCAST_CHANNEL_START", Timed(function(_, _, _, spellID)
	local secret = ns.IsSecret(spellID)
	local name
	if not secret then
		local ok, n = pcall(C_Spell.GetSpellName, spellID)
		name = ok and n or nil
	end
	local fishing = (not secret) and (spellID == FISHING_SPELL_ID or (name ~= nil and name == F.fishingName))
	F.lastChannel = { t = GetTime(), spellID = secret and "<secret>" or spellID, name = name, fishing = fishing }
	if fishing then
		ns.Check("F_FOCUS", "fishingDetectedByChannel", true, F.lastChannel)
	end
	local d = ns.Spike("F_FOCUS").data
	d.channels = d.channels or {}
	if #d.channels < 30 then table.insert(d.channels, ns.Safe(F.lastChannel)) end
end), "player")

ns.On("UNIT_SPELLCAST_SUCCEEDED", Timed(function(_, _, _, spellID)
	F.lastSpell = { t = GetTime(), spellID = ns.IsSecret(spellID) and "<secret>" or spellID }
end), "player")

ns.On("LOOT_READY", Timed(function()
	local rec = { t = GetTime() }
	if IsFishingLoot then
		local ok, v = pcall(IsFishingLoot)
		rec.isFishingLoot = ok and v
	end
	if GetLootSourceInfo then
		local ok, guid = pcall(GetLootSourceInfo, 1)
		if ok and type(guid) == "string" and not ns.IsSecret(guid) then
			rec.sourceType = guid:match("^(%a+)%-")
		end
	end
	if F.lastSpell and GetTime() - F.lastSpell.t < 6 then
		rec.spellBefore = F.lastSpell.spellID
		if type(F.lastSpell.spellID) == "number" then
			local ok, n = pcall(C_Spell.GetSpellName, F.lastSpell.spellID)
			rec.spellBeforeName = ok and n or nil
		end
	end
	local d = ns.Spike("F_FOCUS").data
	d.loots = d.loots or {}
	if #d.loots < 40 then table.insert(d.loots, ns.Safe(rec)) end
	if rec.isFishingLoot then
		ns.Check("F_FOCUS", "fishingDetectedByLoot", true, rec)
	elseif rec.sourceType == "GameObject" then
		F.lastGather = GetTime()
		ns.Check("F_FOCUS", "gatheringDetected", true, rec)
	end
end))

-- cost check on logout/reload (PLAYER_LOGOUT fires before SavedVariables are written)
ns.On("PLAYER_LOGOUT", function()
	local c = F.cost
	ns.Data("F_FOCUS", "handlerCost", { calls = c.n, totalMs = c.total, avgMs = c.n > 0 and c.total / c.n or 0, worstMs = c.worst })
	if c.n > 0 then
		local s = ns.Spike("F_FOCUS")
		s.checks.cheap = { pass = (c.total / c.n) < 0.1 and c.worst < 2, detail = ("avg %.3f ms, worst %.3f ms over %d calls"):format(c.total / c.n, c.worst, c.n) }
		if s.status == "NOT RUN" or s.status == "INFO" then s.status = s.checks.cheap.pass and "PASS" or "FAIL" end
	end
end)

ns.Command("focus", "print what activity the addon thinks you are doing", function()
	local s = LogCtx("command")
	ns.Print(("context guess: %s  (instance: %s, M+ active: %s)"):format(s.guess, tostring(s.instanceType), tostring(s.challengeModeActive)))
end)
ns.commands.f = ns.commands.focus
