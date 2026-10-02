-- SwagBag signals (spec 6.2): WoW events -> Focus.SetSignal. Every read goes through the
-- Adapter, feature-detected (see Core/Adapter.lua for each fallback). Handlers are O(1) table
-- writes plus one Focus.Recompute; nothing polls and nothing runs while nothing happens (6.5).
--   zone        instanceType, mythic (Mythic dungeon difficulty), delve, challengeMode, keystone:
--               PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, SCENARIO_UPDATE, CHALLENGE_MODE_*,
--               ADDON_RESTRICTION_STATE_CHANGED (the ChallengeMode restriction; skipped by SB.On on
--               a client without the event)
--   keystone    a keystone in the bags; re-read on bag changes while in a party dungeon
--   fishing     the player channels a fishing spell, or fishing loot opens; off 90 s after the last
--   gathering   loot from a node or a skinned creature within 6 s of a gathering spell (the
--               allowlist in Engine/FocusData.lua); off 120 s after the last
--   professions the gathering professions (Gathering opens only theirs): login, SKILL_LINES_CHANGED
--   merchantOpen, auctionOpen, bankOpen   MERCHANT_*, AUCTION_HOUSE_*, BANKFRAME_*
-- Not wired in v1.0 (no v1.0 mode uses them, so they would only cost events): combat,
-- encounter, pvpMatch, mapRestricted, tradeSkillOpen.
-- Signals.recent: the last 5 distinct spells cast before a loot window opened (for /swagbag report, so
-- missing gathering IDs can be added; spec 13.1).
local _, SB = ...

local Sig = { ready = false, lastSpell = nil, lastSpellAt = nil, recent = {}, RECENT = 5,
	GATHER_WINDOW = 6, FISHING_DECAY = 90, GATHER_DECAY = 120 }
SB.Signals = Sig

function Sig.HasKeystone()
	for _, _, s in SB.Inventory.Iterate("bags") do
		if s and type(s.link) == "string" and s.link:find("keystone:", 1, true) then
			return true
		end
	end
	return false
end

-- Read every place-bound signal, then decide once.
function Sig.ReadZone()
	local A, F = SB.Adapter, SB.Focus
	local info = A.InstanceInfo()
	local s = F.signals
	s.instanceType = info.instanceType
	s.mythic = A.MYTHIC_DUNGEON_DIFFICULTY[info.difficultyID] == true
	s.delve = A.InDelve(info)
	s.challengeMode = A.ChallengeModeActive() == true
	s.keystone = Sig.HasKeystone()
	return F.Recompute("signal")
end

-- A decaying signal: on now, off `decay` seconds after the last time it was seen.
local function pulse(name, decay)
	SB.Focus.SetSignal(name, true)
	SB.Debounce("signals." .. name, decay, function()
		SB.Focus.SetSignal(name, false)
	end, "bags")
end

function Sig.Fishing()
	pulse("fishing", Sig.FISHING_DECAY)
end

function Sig.Gathering()
	pulse("gathering", Sig.GATHER_DECAY)
end

-- Distinct IDs only: a spell cast again moves to the newest end, so repeats cannot fill the list.
local function remember(spellID)
	local list = Sig.recent
	for i = #list, 1, -1 do
		if list[i] == spellID then
			table.remove(list, i)
		end
	end
	list[#list + 1] = spellID
	while #list > Sig.RECENT do
		table.remove(list, 1)
	end
end

-- Every handler waits for SB_LOGIN: settings are not loaded before it.
local function on(event, fn)
	SB.On(event, function(...)
		if Sig.ready then
			fn(...)
		end
	end, "bags")
end

for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "SCENARIO_UPDATE",
	"CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET" }) do
	on(event, function()
		Sig.ReadZone()
	end)
end

-- A new world (login, loading screen) closes every window: the open-flags cannot outlive it.
on("PLAYER_ENTERING_WORLD", function()
	local F = SB.Focus
	F.signals.merchantOpen, F.signals.auctionOpen, F.signals.bankOpen = false, false, false
	Sig.ReadZone()
end)

-- Only the ChallengeMode restriction matters (skipped by SB.On on a client without the event).
on("ADDON_RESTRICTION_STATE_CHANGED", function(_, kind)
	if SB.Adapter.IsChallengeModeRestriction(kind) then
		Sig.ReadZone()
	end
end)

-- Player casts only: RegisterUnitEvent keeps other units' casts out of Lua (W4-11); the unit
-- check stays as a guard.
local function onPlayer(event, fn)
	SB.OnUnit(event, "player", function(...)
		if Sig.ready then
			fn(...)
		end
	end, "bags")
end

onPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
	if unit == "player" and SB.FocusData.Matches(SB.FocusData.fishing, spellID) then
		Sig.Fishing()
	end
end)

onPlayer("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
	if unit == "player" and type(spellID) == "number" and not SB.Adapter.IsSecret(spellID) then
		Sig.lastSpell, Sig.lastSpellAt = spellID, SB.Adapter.Now()
	end
end)

on("LOOT_READY", function()
	local A = SB.Adapter
	if A.IsFishingLoot() then
		Sig.Fishing()
		return
	end
	local spell, at = Sig.lastSpell, Sig.lastSpellAt
	if not spell or A.Now() - at > Sig.GATHER_WINDOW then
		return
	end
	remember(spell)
	local source = A.LootSourceType()
	if (source == nil or source == "GameObject" or source == "Creature")
		and SB.FocusData.Matches(SB.FocusData.gathering, spell) then
		Sig.Gathering()
	end
end)

local function readProfessions()
	SB.Focus.signals.professions = SB.Adapter.GatheringProfessions()
	SB.Focus.Recompute("signal")
end
on("SKILL_LINES_CHANGED", readProfessions)

local function flag(showEvent, closeEvent, name)
	on(showEvent, function()
		SB.Focus.SetSignal(name, true)
	end)
	on(closeEvent, function()
		SB.Focus.SetSignal(name, false)
	end)
end
flag("MERCHANT_SHOW", "MERCHANT_CLOSED", "merchantOpen")
flag("AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "auctionOpen")
flag("BANKFRAME_OPENED", "BANKFRAME_CLOSED", "bankOpen")

-- A keystone looted or handed in changes the M+ fallback, but only matters in a party dungeon.
-- Only an item arriving, leaving or changing its link, or a bag's size, can change it: cooldown and
-- lock changes (every cast in a key) never scan the bags (ruling W4-26).
SB.Inventory.OnChanged(SB.ErrorTrap.Guard("signals.inventory", function(mask)
	local Inv = SB.Inventory
	if not (Inv.Has(mask, Inv.R.ITEM) or Inv.Has(mask, Inv.R.SIZE)) then
		return
	end
	if Sig.ready and SB.Focus.signals.instanceType == "party" then
		SB.Focus.SetSignal("keystone", Sig.HasKeystone())
	end
end, "bags"))

SB.On("SB_LOGIN", function()
	Sig.ready = true
	SB.Focus.signals.professions = SB.Adapter.GatheringProfessions()
	Sig.ReadZone()
end, "bags")
