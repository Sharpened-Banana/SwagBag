-- SwagBag ItemFacts (0.16.0 search): the item facts that cost a client call each, read only when a query uses a
-- keyword that needs them, and kept per item instance (Items.Key "instance": the link and the bind state).
--   ItemFacts.Stats(record) -> Adapter.ItemStats table | false (not gear, or no stats API) | nil (not loaded yet)
--   ItemFacts.Tooltip(record) -> lower-cased tooltip lines | false (no tooltip API) | nil (not loaded yet, a secret)
--   ItemFacts.Invalidate()   forget every answer
-- An unknown answer (nil) is never kept, so the next search asks again: results fill in as items load. The
-- cache starts over once it holds MAX answers.
local _, SB = ...

local F = { MAX = 4000 }
SB.ItemFacts = F

local cache, size = {}, 0

function F.Invalidate()
	cache, size = {}, 0
end

local function remembered(kind, record, read)
	if record.pending then
		return nil
	end
	local key = kind .. SB.Items.Key(record, "instance")
	local v = cache[key]
	if v ~= nil then
		return v
	end
	v = read()
	if v ~= nil then
		if size >= F.MAX then
			F.Invalidate()
		end
		cache[key], size = v, size + 1
	end
	return v
end

local function isGear(r)
	local C = SB.Adapter.ITEM_CLASS
	return r.classID == C.Armor or r.classID == C.Weapon
end

function F.Stats(record)
	if not isGear(record) then
		return false
	end
	return remembered("s:", record, function()
		return SB.Adapter.ItemStats(record.link)
	end)
end

function F.Tooltip(record)
	return remembered("t:", record, function()
		if record.fromLink then
			return SB.Adapter.TooltipLines(nil, nil, record.link)
		end
		return SB.Adapter.TooltipLines(record.bag, record.slot, record.link)
	end)
end
