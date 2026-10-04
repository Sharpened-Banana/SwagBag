-- SwagBag display order (spec 3.2 "Sort": display order as data). Pure Lua. The list view
-- (UI/BagsWindow.lua) sorts the slots it lays out with it before Engine/Layout.lua groups them
-- into sections, so every section lists its items in this order. The physical sort stays
-- Blizzard's own (the Sort button, Adapter.SortBags).
--   Sort.COLUMNS                     { "name", "count", "ilvl", "value" }: the list view's columns
--   Sort.Spec() -> { by, desc }      the saved order (bags.list.sort, bags.list.desc), checked
--   Sort.Save(by, desc) -> ok        false (nothing written) while the settings are read-only; saved:
--                                    SB_LIST_SORTED(by, desc), so every list (the bags, the bank and the
--                                    guild bank: one shared order, week 8) redraws its bar and regroups
--   Sort.Next(spec, by) -> spec      a click on a column: the same column flips the direction;
--                                    another column starts at its natural one (names A to Z,
--                                    numbers highest first)
--   Sort.Ilvl(record) -> n | nil     the item level the list shows: equippable gear only (as the overlay)
--   Sort.Value(record) -> copper | nil   the stack's value: Prices per unit x count. A bound or
--                                    warbound-until-equipped item is worth its vendor price (D11, W3-35)
--   Sort.DisplayOrder(slots, spec, valueOf) -> list
--       slots: { { bag, slot, record } } in physical order (record nil = an empty slot). The filled
--       slots come first, sorted by spec.by; an item with no value for that column (a potion's item
--       level, an unpriced item) goes last whatever the direction; ties by name, then physical
--       order, so the result never depends on the input's table order. The empty slots follow in
--       physical order (the free tile is the first empty slot, as in every view).
local _, SB = ...

local Sort = { COLUMNS = { "name", "count", "ilvl", "value" } }
SB.Sort = Sort

local KNOWN = { name = true, count = true, ilvl = true, value = true }

function Sort.Spec()
	local by = SB.Config.Get("bags.list.sort")
	if not KNOWN[by] then
		by = "value"
	end
	local desc = SB.Config.Get("bags.list.desc")
	if type(desc) ~= "boolean" then
		desc = by ~= "name" -- a damaged saved direction: the column's natural one
	end
	return { by = by, desc = desc }
end

function Sort.Save(by, desc)
	if not KNOWN[by] then
		return false
	end
	if not (SB.Config.Set("bags.list.sort", by) and SB.Config.Set("bags.list.desc", desc == true)) then
		return false
	end
	SB.Emit("SB_LIST_SORTED", by, desc == true)
	return true
end

function Sort.Next(spec, by)
	if spec and spec.by == by then
		return { by = by, desc = not spec.desc }
	end
	return { by = by, desc = by ~= "name" }
end

function Sort.Ilvl(record)
	local O = SB.OverlayData
	if record and O and O.SLOTS[record.equipLoc or ""] and type(record.ilvl) == "number" then
		return record.ilvl
	end
	return nil
end

function Sort.Value(record)
	if not record or record.pending or not SB.Prices then
		return nil
	end
	local v = SB.Prices.Value(record.link, record.itemID, SB.Prices.Bound(record))
	if type(v) ~= "number" then
		return nil
	end
	return v * (record.count or 1)
end

local function nameOf(record)
	local name = record.name
	if type(name) ~= "string" and type(record.link) == "string" then
		name = record.link:match("%[(.-)%]")
	end
	return type(name) == "string" and name:lower() or nil
end

local function keyOf(record, by, valueOf)
	local key = Sort.rawKey(record, by, valueOf)
	if key ~= key then
		return nil -- NaN would break the comparator's ordering
	end
	return key
end

function Sort.rawKey(record, by, valueOf)
	if by == "name" then
		return nameOf(record)
	elseif by == "count" then
		return record.count or 1
	elseif by == "ilvl" then
		return Sort.Ilvl(record)
	end
	return valueOf(record)
end

function Sort.DisplayOrder(slots, spec, valueOf)
	spec = spec or { by = "value", desc = true }
	valueOf = valueOf or Sort.Value
	local filled, empty = {}, {}
	for i, s in ipairs(slots) do
		if s.record then
			filled[#filled + 1] = { s = s, i = i, key = keyOf(s.record, spec.by, valueOf), name = nameOf(s.record) or "" }
		else
			empty[#empty + 1] = s
		end
	end
	table.sort(filled, function(a, b)
		if a.key ~= b.key then
			if a.key == nil then
				return false
			elseif b.key == nil then
				return true
			end
			if spec.desc then
				return a.key > b.key
			end
			return a.key < b.key
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.i < b.i
	end)
	local out = {}
	for _, f in ipairs(filled) do
		out[#out + 1] = f.s
	end
	for _, s in ipairs(empty) do
		out[#out + 1] = s
	end
	return out
end
