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
--   Prices.WorthThreshold(values, mode, gold, percent) -> copper | nil   the worth-money glow's line (week 7,
--                                      user pick 7): "fixed" gold x 10000; "top" the stack value of the
--                                      last item in the top `percent` of `values` (stack values above 0);
--                                      nil for "off" or when nothing has a value
--   Prices.Invalidate()
-- Week 9 (user pick 10): Providers/TSM.lua adds "TSM" (priority 5, TradeSkillMaster's price string from the
-- prices.tsm setting). prices.source picks who answers: "auto" (the default: Auctionator, else TSM, else the
-- vendor, by priority) | "auctionator" | "tsm" | "vendor" (that one, the vendor for what it has no price for,
-- or for everything while it is not loaded). Header totals, the list's Value column and the gold glow ask
-- Prices.Value, so they follow the choice.
--   Prices.AuctionValue(link, itemID) -> copper | nil   ruling R0: the highest price any loaded auction source
--                                      (Auctionator, TSM) gives, whatever prices.source says; the vendor's
--                                      "gray BoE worth more than twice at auction" rule and Sell all's Auction
--                                      House sentence ask it, so a gold-maker who shows vendor prices keeps them
--   Prices.Choice() -> provider name | nil (auto);  Prices.TSMString() -> one of Adapter.TSM_PRICES
--   Prices.SourceText() -> "Auctionator" | "TSM (DBMarket)" | "Vendor"   for /swagbag price and the report
-- A change of either setting drops the cache and refreshes the open windows' totals once. A provider with
-- missAge (TSM: its data may still be loading after login) has its "no price" kept missAge seconds only
-- (MISS_AGE, 30), not the cache's 10 minutes.
local _, SB = ...

local P = { providers = {}, cache = {}, boundCache = {}, ahCache = {}, cached = 0, filledAt = nil, active = nil,
	auction = nil, errors = {}, off = {}, MAX_AGE = 600, MISS_AGE = 30, REFRESH_DELAY = 0.5, MAX_ERRORS = 3 }
SB.Prices = P

function P.RegisterProvider(p)
	P.providers[#P.providers + 1] = p
	P.Invalidate()
end

function P.Invalidate()
	P.cache, P.boundCache, P.cached, P.filledAt, P.active = {}, {}, 0, nil, nil
	P.ahCache, P.auction = {}, nil -- ruling R0's own cache (P.AuctionValue)
end

local function byPriority(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end
	return a.name < b.name
end

P.CHOICES = { auctionator = "Auctionator", tsm = "TSM", vendor = "Vendor" }

function P.Choice()
	return P.CHOICES[SB.Config.Get("prices.source")]
end

function P.TSMString()
	local want = SB.Config.Get("prices.tsm")
	for _, name in ipairs(SB.Adapter.TSM_PRICES) do
		if name == want then
			return name
		end
	end
	return SB.Adapter.TSM_PRICES[1]
end

-- The available providers, best first (worked out once per cache fill): every one ("auto"), or the chosen one
-- and the vendor.
local function active()
	if not P.active then
		local list, choice = {}, P.Choice()
		for _, p in ipairs(P.providers) do
			if not P.off[p.name] and (choice == nil or p.name == choice or p.name == "Vendor") then
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

function P.SourceText()
	local source = P.Source()
	if source == "TSM" then
		return source .. " (" .. P.TSMString() .. ")"
	end
	return source
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

-- The answer, its provider, and how long a "no price" on the way may be kept (missAge; nil: the cache's age).
local function lookup(link, itemID, bound)
	local missAge
	for _, p in ipairs(active()) do
		if not bound or p.name == "Vendor" then
			local ok, v = pcall(p.value, link, itemID)
			if not ok then
				failed(p, v)
			elseif type(v) == "number" then
				return v, p.name, missAge
			elseif p.missAge then
				missAge = math.min(missAge or p.missAge, p.missAge)
			end
		end
	end
	return nil, nil, missAge
end

-- Now, after dropping a cache older than MAX_AGE.
local function fresh()
	local now = SB.Adapter.Now()
	if P.filledAt and now - P.filledAt > P.MAX_AGE then
		P.Invalidate()
	end
	return now
end

function P.Bound(record)
	return record.isBound == true or record.isWUE == true or record.bindUnknown == true
end

function P.Value(link, itemID, bound)
	if SB.Adapter.IsSecret(link) then
		link = nil -- a secret value is never a table key: price by itemID
	end
	local now = fresh()
	local key = link or itemID
	local store = bound and P.boundCache or P.cache
	local hit = key ~= nil and store[key]
	if hit and (hit[3] == nil or now <= hit[3]) then
		return hit[1] or nil, hit[2]
	end
	local v, source, missAge = lookup(link, itemID, bound)
	if key ~= nil then
		store[key] = { v or false, source, missAge and now + missAge or nil }
	end
	P.cached = P.cached + 1
	P.filledAt = P.filledAt or now
	return v, source
end

-- Ruling R0: every auction source that is loaded (every provider but the vendor), whatever prices.source says.
local function auctionSources()
	if not P.auction then
		local list = {}
		for _, p in ipairs(P.providers) do
			if p.name ~= "Vendor" and not P.off[p.name] then
				local ok, yes = pcall(p.available)
				if ok and yes then
					list[#list + 1] = p
				end
			end
		end
		P.auction = list
	end
	return P.auction
end

function P.AuctionValue(link, itemID)
	if SB.Adapter.IsSecret(link) then
		link = nil
	end
	if SB.Adapter.IsSecret(itemID) then
		itemID = nil
	end
	local key = link or itemID
	if key == nil then
		return nil
	end
	local now = fresh()
	local hit = P.ahCache[key]
	if hit and (hit[2] == nil or now <= hit[2]) then
		return hit[1] or nil
	end
	local best, missAge
	for _, p in ipairs(auctionSources()) do
		local ok, v = pcall(p.value, link, itemID)
		if not ok then
			failed(p, v)
		elseif type(v) == "number" then
			best = math.max(best or v, v)
		elseif p.missAge then
			missAge = math.min(missAge or p.missAge, p.missAge)
		end
	end
	P.ahCache[key] = { best or false, missAge and now + missAge or nil }
	P.filledAt = P.filledAt or now
	return best
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

function P.WorthThreshold(values, mode, gold, percent)
	if mode == "fixed" then
		return (tonumber(gold) or 0) * 10000
	elseif mode ~= "top" then
		return nil
	end
	local list = {}
	for _, v in ipairs(values) do
		if v > 0 then
			list[#list + 1] = v
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, function(a, b)
		return a > b
	end)
	return list[math.max(1, math.ceil(#list * (tonumber(percent) or 0) / 100))]
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

local function refreshSoon()
	-- The windows refresh their header totals in place, once, after the burst.
	SB.Debounce("prices.refresh", P.REFRESH_DELAY, function()
		SB.Emit("SB_PRICES_CHANGED")
	end, "none")
end

-- Week 9: a new source or TSM price string asks the providers again; everything may have changed (nil: a
-- profile load, a reset) drops the cache too (SB.FollowSettings refreshes the windows then).
SB.On("SB_CONFIG_CHANGED", function(_, path)
	if path == nil then
		P.Invalidate()
	elseif path == "prices.source" or path == "prices.tsm" then
		P.Invalidate()
		refreshSoon()
	end
end, "none")

-- /swagbag price                       where prices come from
-- /swagbag price auto|auctionator|tsm|vendor
-- /swagbag price tsm <price>          TSM, with one of Adapter.TSM_PRICES (any case)
-- /swagbag price string <price>       TSM's price only; where prices come from stays (the Settings row)
local function choiceText(choice)
	local L = SB.L
	if choice == "tsm" then
		return L.PRICE_CHOICE_TSM:format(P.TSMString())
	end
	return (choice == "auctionator" and L.PRICE_CHOICE_AUCTIONATOR) or (choice == "vendor" and L.PRICE_CHOICE_VENDOR)
		or L.PRICE_CHOICE_AUTO
end

-- One of Adapter.TSM_PRICES by its lower-case word, or nil.
local function tsmName(word)
	for _, name in ipairs(SB.Adapter.TSM_PRICES) do
		if name:lower() == word then
			return name
		end
	end
	return nil
end

SB.Slash.Register("price", SB.L.HELP_PRICE, function(arg)
	local L, C = SB.L, SB.Config
	local a, b = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	if a == "" then
		return L.PRICE_STATE:format(choiceText(C.Get("prices.source")), tostring(P.SourceText() or L.REPORT_NONE))
	elseif a == "string" then
		local name = tsmName(b)
		if not name then
			return L.PRICE_USAGE
		end
		if not C.Set("prices.tsm", name) then
			return L.SETTINGS_READONLY
		end
		return L.PRICE_TSM_SET:format(name)
	end
	local priceString
	if a == "tsm" and b ~= "" then
		priceString = tsmName(b)
		if not priceString then
			return L.PRICE_USAGE
		end
	elseif b ~= "" or not (a == "auto" or P.CHOICES[a]) then
		return L.PRICE_USAGE
	end
	if not C.Set("prices.source", a) or (priceString and not C.Set("prices.tsm", priceString)) then
		return L.SETTINGS_READONLY
	end
	local text = L.PRICE_SET:format(choiceText(a))
	local name = P.CHOICES[a]
	if name and name ~= "Vendor" and P.Source() ~= name then
		text = text .. " " .. L.PRICE_NOT_LOADED:format(name)
	end
	return text
end)

-- Providers that can say "prices changed" drop the cache when they do.
SB.On("SB_LOGIN", function()
	for _, p in ipairs(P.providers) do
		if p.onUpdate then
			pcall(p.onUpdate, SB.ErrorTrap.Guard("prices.update", function()
				P.Invalidate()
				refreshSoon()
			end, "none"))
		end
	end
end, "none")
