-- SwagBag prices (spec F10, 3.3). Item values come from providers; the available provider
-- with the highest priority that knows a price answers (ties: name order). Built in:
-- "Vendor" (priority 0, the sell price). Providers/Auctionator.lua adds "Auctionator"
-- (priority 10) while Auctionator is loaded. SwagBag never scans the auction house itself.
-- Lookups are cached per link for the session. The cache is dropped when a provider reports
-- new prices (onUpdate) and at the first lookup 10 minutes after it was filled (no timer).
-- A provider that throws three times in a session is switched off, with one chat line and one
-- error-ring entry; the others carry on (spec 3.3).
--   Prices.RegisterProvider(p)   p = { name, priority, available() -> bool,
--                                      value(link, itemID) -> copper | nil, onUpdate(cb) optional }
--   Prices.Value(link, itemID, bound) -> copper | nil, providerName   per unit; a bound item
--                                      is worth its vendor price only (it cannot be sold on the AH)
--   Prices.Bound(record) -> bool   priced as bound: bound, warbound until equipped, or a saved
--                                      item whose bind is unknown (record.bindUnknown, ruling W5-10)
--   Prices.Source() -> "Auctionator" | "Vendor" | ...   the provider that answers first
--   Prices.SectionTotals(state, recordOf) -> { [sectionId] = copper }   value x count per
--                                      layout section (Engine/Layout.lua state), placeholders skipped
--   Prices.Money(copper) -> "1,240g" | "35s" | "12c"
--   Prices.Invalidate()
local _, SB = ...

local P = { providers = {}, cache = {}, boundCache = {}, cached = 0, filledAt = nil, active = nil, errors = {}, off = {},
	MAX_AGE = 600, REFRESH_DELAY = 0.5, MAX_ERRORS = 3 }
SB.Prices = P

function P.RegisterProvider(p)
	P.providers[#P.providers + 1] = p
	P.Invalidate()
end

function P.Invalidate()
	P.cache, P.boundCache, P.cached, P.filledAt, P.active = {}, {}, 0, nil, nil
end

local function byPriority(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end
	return a.name < b.name
end

-- The available providers, best first (worked out once per cache fill).
local function active()
	if not P.active then
		local list = {}
		for _, p in ipairs(P.providers) do
			if not P.off[p.name] then
				local ok, yes = pcall(p.available)
				if ok and yes then
					list[#list + 1] = p
				end
			end
		end
		table.sort(list, byPriority)
		P.active = list
	end
	return P.active
end

function P.Source()
	local first = active()[1]
	return first and first.name or nil
end

local function failed(p, message)
	P.errors[p.name] = (P.errors[p.name] or 0) + 1
	if P.errors[p.name] >= P.MAX_ERRORS and not P.off[p.name] then
		P.off[p.name] = true
		P.Invalidate()
		pcall(SB.ErrorTrap.OnError, "prices:" .. p.name, "none", tostring(message), "")
		SB.Print(SB.L.PRICES_PROVIDER_OFF:format(p.name))
	end
end

local function lookup(link, itemID, bound)
	for _, p in ipairs(active()) do
		if not bound or p.name == "Vendor" then
			local ok, v = pcall(p.value, link, itemID)
			if not ok then
				failed(p, v)
			elseif type(v) == "number" then
				return v, p.name
			end
		end
	end
	return nil, nil
end

function P.Bound(record)
	return record.isBound == true or record.isWUE == true or record.bindUnknown == true
end

function P.Value(link, itemID, bound)
	local now = SB.Adapter.Now()
	if P.filledAt and now - P.filledAt > P.MAX_AGE then
		P.Invalidate()
	end
	local key = link or itemID
	local store = bound and P.boundCache or P.cache
	local hit = key ~= nil and store[key]
	if hit then
		return hit[1] or nil, hit[2]
	end
	local v, source = lookup(link, itemID, bound)
	if key ~= nil then
		store[key] = { v or false, source }
	end
	P.cached = P.cached + 1
	P.filledAt = P.filledAt or now
	return v, source
end

function P.SectionTotals(state, recordOf)
	local totals = {}
	for id, sec in pairs(state.sections) do
		local sum = 0
		for i = 1, sec.size do
			local cell = sec.cells[i]
			if cell and cell.bag and not cell.placeholder then
				local r = recordOf(cell.bag, cell.slot)
				if r and not r.pending then
					local v = P.Value(r.link, r.itemID, P.Bound(r))
					if v then
						sum = sum + v * (r.count or 1)
					end
				end
			end
		end
		totals[id] = sum
	end
	return totals
end

local function thousands(n)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function P.Money(copper)
	local L = SB.L
	copper = math.floor(copper or 0)
	if copper >= 10000 then
		return L.MONEY_GOLD:format(thousands(math.floor(copper / 10000)))
	elseif copper >= 100 then
		return L.MONEY_SILVER:format(math.floor(copper / 100))
	end
	return L.MONEY_COPPER:format(copper)
end

-- The built-in fallback: what a vendor pays.
P.RegisterProvider({
	name = "Vendor",
	priority = 0,
	available = function()
		return true
	end,
	value = function(_, itemID)
		local info = itemID and SB.Adapter.GetItemInfo(itemID)
		return info and info.sellPrice or nil
	end,
})

-- Providers that can say "prices changed" drop the cache when they do.
SB.On("SB_LOGIN", function()
	for _, p in ipairs(P.providers) do
		if p.onUpdate then
			pcall(p.onUpdate, SB.ErrorTrap.Guard("prices.update", function()
				P.Invalidate()
				-- The windows refresh their header totals in place, once, after the burst.
				SB.Debounce("prices.refresh", P.REFRESH_DELAY, function()
					SB.Emit("SB_PRICES_CHANGED")
				end, "none")
			end, "none"))
		end
	end
end, "none")
