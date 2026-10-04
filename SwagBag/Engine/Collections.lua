-- SwagBag collections (week 7, user picks 3 and 9): what an item in the bags is to the collection.
--   Collections.Learn(record) -> "open" | "learn" | nil
--     open    a container the client says holds loot (record.hasLoot: caches, bags of goods, lockboxes)
--     learn   a toy, mount, pet or decor item the account has not collected yet, or a profession
--             knowledge item (Engine/Crests.lua `knowledge`)
--   Collections.Uncollected(record) -> "appearance" | "toy" | "mount" | "pet" | nil   (user pick 9)
--     appearance  gear whose look the account has not collected (Adapter.AppearanceKnown)
--     toy / mount / pet   an item that teaches one the account does not have yet
--   Collections.LookUnknown(record, cached) -> bool   gray gear whose look the client cannot say (the sell
--     path: such a piece is protected; the answer is never cached there, so the next sale asks again).
--     Rings, necklaces and trinkets have no look at all: "cannot collect", never unknown (week 8). cached =
--     true (the overlays' junk coin, week 8): the answer Uncollected already cached for the link, so a
--     draw costs a table lookup, never a collection call
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

-- Equipment slots with no appearance (week 8): a gray ring, necklace or trinket has no look to collect.
Coll.NO_LOOK = { INVTYPE_FINGER = true, INVTYPE_NECK = true, INVTYPE_TRINKET = true }

-- A text the draw path may use: a string the client did not make secret (it may in M+ and raids;
-- spec 9); a secret is no answer, never an error (week 8, the week-7 final review's T3 item).
local function plain(v)
	return type(v) == "string" and not SB.Adapter.IsSecret(v) and v or nil
end

local function knowledge(r)
	local K = SB.Crests and SB.Crests.knowledge
	if not K then
		return false
	end
	if K.ids[r.itemID] then
		return true
	end
	local name = plain(r.name)
	if name == nil or isGear(r) then
		return false
	end
	name = name:lower()
	for _, word in ipairs(K.words) do
		if name:find(word, 1, true) then
			return true
		end
	end
	return false
end

local function teaches(r)
	local A = SB.Adapter
	local C, MS = A.ITEM_CLASS, A.MISC_SUB
	local id = r.itemID
	if r.isToy then
		return "toy", cached("toy:" .. id, function()
			return A.ToyKnown(id)
		end)
	elseif r.classID == C.Miscellaneous and r.subclassID == MS.Mount then
		return "mount", cached("mount:" .. id, function()
			return A.MountKnown(id)
		end)
	elseif r.isCagedPet or r.classID == C.Battlepet or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet) then
		local link = plain(r.link)
		local species = link and link:match("battlepet:(%d+)")
		return "pet", cached("pet:" .. (species and ("s" .. species) or id), function()
			return A.PetKnown(id, link)
		end)
	elseif r.classID == C.Housing then
		return "decor", cached("decor:" .. id, function()
			return A.DecorKnown(id)
		end)
	end
	return nil, nil
end

function Coll.Uncollected(r)
	if not r or r.offline or r.pending then
		return nil
	end
	if isGear(r) then
		local link = plain(r.link)
		if link and cached("look:" .. link, function()
			return SB.Adapter.AppearanceKnown(link)
		end) == false then
			return "appearance"
		end
		return nil
	end
	local kind, collected = teaches(r)
	if collected == false and kind ~= "decor" then
		return kind
	end
	return nil
end

-- For SELLING only (Vendor.Protected): a gray piece of gear whose look the client cannot say (no source,
-- no data yet, a secret) might be an uncollected look, so it stays. "Cannot collect" is an answer
-- ("cannot"), not an unknown. Asked fresh each time: an unknown is never cached on this path.
function Coll.LookUnknown(r, fast)
	if not r or r.offline or r.pending or r.quality ~= 0 or not isGear(r) or Coll.NO_LOOK[r.equipLoc or ""] then
		return false
	end
	local link = plain(r.link)
	if not link then
		return true
	end
	if fast then -- the draw path: the answer Uncollected cached for this link (asked once per link)
		return cached("look:" .. link, function()
			return SB.Adapter.AppearanceKnown(link)
		end) == nil
	end
	return SB.Adapter.AppearanceKnown(link) == nil
end

function Coll.Learn(r)
	if not r or r.offline then
		return nil -- an alt's saved item: not this character's to click
	end
	if r.hasLoot then
		return "open"
	end
	local _, collected = teaches(r)
	if collected == false or knowledge(r) then
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

for _, event in ipairs({ "NEW_TOY_ADDED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "TRANSMOG_COLLECTION_UPDATED" }) do
	SB.On(event, learned, "none")
end

-- P6: Inventory.Notify runs its listeners inside a "bags" trap; this one has its own "none" trap, so a
-- failure here is recorded and never switches the bags to Safe Mode (it only drops cached answers).
SB.Inventory.OnChanged(SB.ErrorTrap.Guard("collections.inventory", function(mask)
	if SB.Inventory.Has(mask, SB.Inventory.R.ITEM) then
		Coll.Invalidate()
	end
end, "none"))
