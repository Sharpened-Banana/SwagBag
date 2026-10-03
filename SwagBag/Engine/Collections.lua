-- SwagBag collections (week 7, user picks 3 and 9): what an item in the bags is to the collection.
--   Collections.Learn(record) -> "open" | "learn" | nil
--     open    a container the client says holds loot (record.hasLoot: caches, bags of goods, lockboxes)
--     learn   a toy, mount, pet or decor item the account has not collected yet, or a profession
--             knowledge item (Engine/Crests.lua `knowledge`)
--   Collections.Invalidate()   drop the cached answers (something was learned, or an item left the bags)
-- Every answer comes from the client's collection APIs through the Adapter (spec P7: no tooltip
-- reading); one the client cannot give (nil, or secret) means "nothing to do", so an item never glows
-- by mistake. Answers are cached per item (a caged pet: per species) until something is learned or an
-- item leaves the bags, so drawing costs a table lookup. Nothing runs per frame and nothing polls.
local _, SB = ...

local Coll = { cache = {}, REFRESH = 0.2 }
SB.Collections = Coll

local UNKNOWN = "?" -- a cached "the client cannot say"

function Coll.Invalidate()
	Coll.cache = {}
end

-- A cached true / false / nil from ask().
local function cached(key, ask)
	local v = Coll.cache[key]
	if v == nil then
		v = ask()
		if v == nil then
			v = UNKNOWN
		end
		Coll.cache[key] = v
	end
	if v == UNKNOWN then
		return nil
	end
	return v
end

local function isGear(r)
	local C = SB.Adapter.ITEM_CLASS
	return r.classID == C.Armor or r.classID == C.Weapon
end

local function knowledge(r)
	local K = SB.Crests and SB.Crests.knowledge
	if not K then
		return false
	end
	if K.ids[r.itemID] then
		return true
	end
	if r.name == nil or isGear(r) then
		return false
	end
	local name = r.name:lower()
	for _, word in ipairs(K.words) do
		if name:find(word, 1, true) then
			return true
		end
	end
	return false
end

function Coll.Learn(r)
	if not r or r.offline then
		return nil -- an alt's saved item: not this character's to click
	end
	if r.hasLoot then
		return "open"
	end
	local A = SB.Adapter
	local C, MS = A.ITEM_CLASS, A.MISC_SUB
	local id, missing = r.itemID, nil
	if r.isToy then
		missing = cached("toy:" .. id, function()
			return A.ToyKnown(id)
		end) == false
	elseif r.classID == C.Miscellaneous and r.subclassID == MS.Mount then
		missing = cached("mount:" .. id, function()
			return A.MountKnown(id)
		end) == false
	elseif r.isCagedPet or r.classID == C.Battlepet or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet) then
		local species = type(r.link) == "string" and r.link:match("battlepet:(%d+)")
		missing = cached("pet:" .. (species and ("s" .. species) or id), function()
			return A.PetKnown(id, r.link)
		end) == false
	elseif r.classID == C.Housing then
		missing = cached("decor:" .. id, function()
			return A.DecorKnown(id)
		end) == false
	end
	if missing or knowledge(r) then
		return "learn"
	end
	return nil
end

-- Something was learned: drop the answers and re-draw the open windows once, after the burst. An item
-- that left the bags (learned items are used up) only drops the answers: the next draw asks again.
local function learned()
	Coll.Invalidate()
	SB.Debounce("collections.refresh", Coll.REFRESH, function()
		if SB.Overlays then
			SB.Overlays.RefreshAll()
		end
	end, "none")
end

for _, event in ipairs({ "NEW_TOY_ADDED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED" }) do
	SB.On(event, learned, "none")
end

-- P6: Inventory.Notify runs its listeners inside a "bags" trap; this one has its own "none" trap, so a
-- failure here is recorded and never switches the bags to Safe Mode (it only drops cached answers).
SB.Inventory.OnChanged(SB.ErrorTrap.Guard("collections.inventory", function(mask)
	if SB.Inventory.Has(mask, SB.Inventory.R.ITEM) then
		Coll.Invalidate()
	end
end, "none"))
