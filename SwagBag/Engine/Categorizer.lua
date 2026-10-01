-- SwagBag categorizer (spec 7.7, 7.8). Pure: item record -> category id.
--   Categorizer.Assign(record) -> id, how     how = "manual" | "rule" | "fallback"
--                              -> nil, "pending"   a rule could not decide yet (goes to New)
--   Categorizer.AssignAll(records) -> groups { [id] = { records in bag/slot order } }, pending list
--   Categorizer.Invalidate()   drop every memo (automatic whenever any category changes)
--   Categorizer.stats          { hits, misses, evictions } for /swagbag perf (later week)
-- Order (spec 7.7): exclude lists first (an excluded item never lands in that category),
-- then include lists by priority, then rules by priority (ties by id). The first rule
-- that says true wins. A rule that says nil (item data not loaded) STOPS the search: the
-- item waits in New instead of being mis-filed by a lower rule. No rule: Other.
-- Error isolation (spec 7.10): each rule runs inside pcall. A rule that throws is marked
-- failed (Categories.MarkFailed), recorded ONCE in the error ring with window "none"
-- (no Safe Mode, no chat line), and skipped from then on. Other categories carry on.
-- Memo (spec 7.8), per category, by the rule's cache class: static -> itemID, instance ->
-- Items.Key (link + bind suffix), volatile -> never. Only definite (true/false) results
-- of loaded records are kept. At most MAX_MEMO entries in all; the oldest go first.
local _, SB = ...

local Z = { MAX_MEMO = 4000, memo = {}, memoCount = 0, version = -1, stats = { hits = 0, misses = 0, evictions = 0 } }
SB.Categorizer = Z

local TRUE, FALSE = 1, 0
local queueId, queueKey, head, tail = {}, {}, 1, 0

function Z.Invalidate()
	Z.memo, Z.memoCount = {}, 0
	queueId, queueKey, head, tail = {}, {}, 1, 0
end

local function sync()
	local C = SB.Categories
	C.Ensure()
	if C.version ~= Z.version then
		Z.Invalidate()
		Z.version = C.version
	end
end

local function remember(id, key, value)
	while Z.memoCount >= Z.MAX_MEMO and head <= tail do
		local oldId, oldKey = queueId[head], queueKey[head]
		queueId[head], queueKey[head] = nil, nil
		head = head + 1
		local m = Z.memo[oldId]
		if m and m[oldKey] ~= nil then
			m[oldKey] = nil
			Z.memoCount = Z.memoCount - 1
			Z.stats.evictions = Z.stats.evictions + 1
		end
	end
	local m = Z.memo[id]
	if not m then
		m = {}
		Z.memo[id] = m
	end
	m[key] = value
	Z.memoCount = Z.memoCount + 1
	tail = tail + 1
	queueId[tail], queueKey[tail] = id, key
end

local function fail(c, err)
	local message = tostring(err)
	if SB.Categories.MarkFailed(c.id, message) then
		pcall(SB.ErrorTrap.OnError, "category:" .. c.id, "none", message, "")
	end
end

-- One category's rule for one record: true | false | nil. Never throws.
local function rule(c, record)
	local class = c.compiled.cacheClass
	local key
	if class ~= "volatile" and not record.pending then
		key = SB.Items.Key(record, class)
	end
	if key ~= nil then
		local m = Z.memo[c.id]
		local v = m and m[key]
		if v ~= nil then
			Z.stats.hits = Z.stats.hits + 1
			return v == TRUE
		end
	end
	Z.stats.misses = Z.stats.misses + 1
	local ok, v = pcall(SB.Query.Eval, c.compiled, record)
	if not ok then
		fail(c, v)
		return false
	end
	if key ~= nil and v ~= nil then
		remember(c.id, key, v and TRUE or FALSE)
	end
	return v
end

local function usable(c)
	return c.enabled and not c.runtimeError
end

function Z.Assign(record)
	sync()
	local C = SB.Categories
	local list = C.byPriority
	local itemID = record.itemID
	for i = 1, #list do
		local c = list[i]
		if usable(c) and c.itemList.include[itemID] and not c.itemList.exclude[itemID] then
			return c.id, "manual"
		end
	end
	for i = 1, #list do
		local c = list[i]
		if usable(c) and c.hasRule and not c.itemList.exclude[itemID] then
			local v = rule(c, record)
			if v == true then
				return c.id, "rule"
			elseif v == nil then
				return nil, "pending"
			end
		end
	end
	return C.OTHER, "fallback"
end

local function bySlot(a, b)
	if a.bag ~= b.bag then
		return a.bag < b.bag
	end
	return a.slot < b.slot
end

function Z.AssignAll(records)
	local groups, pending = {}, {}
	for _, r in ipairs(records) do
		local id = Z.Assign(r)
		if id == nil then
			pending[#pending + 1] = r
		else
			groups[id] = groups[id] or {}
			table.insert(groups[id], r)
		end
	end
	for _, g in pairs(groups) do
		table.sort(g, bySlot)
	end
	table.sort(pending, bySlot)
	return groups, pending
end
