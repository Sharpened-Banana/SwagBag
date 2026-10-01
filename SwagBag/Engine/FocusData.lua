-- SwagBag focus-mode spell data (spec 6.2, 6.6, 13.2 item 3). Pure data, updated with patches.
-- A spell matches a list when its ID is in `ids`, or its lower-case name (Adapter.SpellName) is
-- one of `names` or starts with one of `prefixes`. Name matching is English (the client
-- language at launch) and backs up the IDs until in-game checks confirm them.
--   fishing    the Fishing channel (check V6). 131474 was seen in the 12.1 spike.
--   gathering  herb, ore and skin gathering (check V8). The IDs are the long-standing base
--              spells; each expansion adds its own, so names back them up. Chests ("Opening")
--              and archaeology ("Survey", "Digging") are deliberately not listed (AC8.6).
--   teleports  Mythic+ dungeon teleports (check V11): all are named "Path of ...".
-- /swagbag report lists the last spells cast before loot, so Claude can add confirmed IDs.
local _, SB = ...

local FD = {
	fishing = { ids = { [131474] = true }, names = { "fishing" }, prefixes = {} },
	gathering = { ids = { [2366] = true, [2575] = true, [8613] = true },
		names = { "herb gathering", "mining", "skinning" }, prefixes = {} },
	teleports = { ids = {}, names = {}, prefixes = { "path of " } },
}
SB.FocusData = FD

-- Spell names found so far, by spellID (W4-3): name matching must not call the Adapter on every
-- combat cast. Only names are cached, so a name the client could not give yet is asked again.
FD.names = {}

-- True when spellID belongs to list (one of the tables above). A secret or non-number ID never
-- matches and is never indexed (W4-3).
function FD.Matches(list, spellID)
	if type(spellID) ~= "number" or SB.Adapter.IsSecret(spellID) then
		return false
	end
	if list.ids[spellID] then
		return true
	end
	local name = FD.names[spellID]
	if not name then
		name = SB.Adapter.SpellName(spellID)
		if not name then
			return false
		end
		FD.names[spellID] = name
	end
	for _, n in ipairs(list.names) do
		if name == n then
			return true
		end
	end
	for _, p in ipairs(list.prefixes) do
		if name:sub(1, #p) == p then
			return true
		end
	end
	return false
end
