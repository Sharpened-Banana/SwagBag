-- SwagBag wealth (0.17): each character's gold and currencies, saved so the footer tooltips can
-- show every character (spec 2). Pure Lua over the Adapter; the data lives on the character's
-- own table in SwagBagDB.chars (Engine/Snapshots.lua), read back through AltData.Wealth.
--   Wealth.Save() -> bool   writes c.money (copper) and c.currencies ({ [currencyID] = quantity })
--       on the current character. The currencies are merged into what was saved: every id in the backpack
--       list, the Currency tab list and SB.Crests.currencies takes its quantity, and every id saved before
--       but in none of those lists (a collapsed Currency-tab header hides its currencies) is asked again by
--       id; an id the client does not answer for keeps its saved quantity. A quantity of 0 removes the id,
--       so spending the last of a currency is saved. Gold the game cannot say leaves money as it was.
--       Read-only settings: nothing written, false
--   Wealth.MAX_LINES   the most character lines a tooltip lists; the rest become one { more = n } entry
--   Wealth.GoldLines(list, warband) -> lines, total   pure, over AltData.Wealth entries: { { name, copper,
--       class } } richest first (ties by name), money > 0 only, "-realm" only where another listed line
--       shares the name, capped with a last { more = n }; total = every character's gold + warband (nil: 0)
--   Wealth.CurrencyLines(list, currencyID) -> lines   the same with quantity, most first
--   Wealth.RefreshWarband() -> copper|nil   the Warband bank's gold when the client says, saved in
--       SwagBagDB.warbandMoney (not while read-only); else the saved amount. Also on BANKFRAME_OPENED.
--       nil without the "warband" capability (WoW Forever): never read, never saved
--   Wealth.lastWarband() -> copper|nil   the saved warband gold
--   Wealth.DELAY   seconds the saves after PLAYER_MONEY / CURRENCY_DISPLAY_UPDATE wait for the last
--       one (SB.Debounce); PLAYER_ENTERING_WORLD saves the same way, PLAYER_LOGOUT at once
local _, SB = ...

local Wealth = { DELAY = 2, MAX_LINES = 20 }
SB.Wealth = Wealth

-- The quantity the client gave (0 included), or nil when it cannot be told.
local function quantityOf(c)
	local q = c and c.quantity
	if type(q) == "number" and not SB.Adapter.IsSecret(q) and q >= 0 then
		return q
	end
	return nil
end

function Wealth.Save()
	if SB.Config.readOnly or not SB.Config.db then
		return false
	end
	local A = SB.Adapter
	local c = SB.Snapshots.Char()
	local money = A.Money()
	if type(money) == "number" and not A.IsSecret(money) then
		c.money = money
	end
	local currencies, seen = {}, {}
	if type(c.currencies) == "table" then
		for id, q in pairs(c.currencies) do
			currencies[id] = q
		end
	end
	local lists = { A.BackpackCurrencies() or {}, A.CurrencyList() or {} }
	-- the Currency tab list hides what a collapsed header holds: the season's crests are read by id too
	local crestIds = SB.Crests and SB.Crests.currencies
	if type(crestIds) == "table" and #crestIds > 0 then
		local extra = {}
		for _, id in ipairs(crestIds) do
			extra[#extra + 1] = A.CurrencyInfo(id)
		end
		lists[#lists + 1] = extra
	end
	local function take(cur)
		local q = quantityOf(cur)
		if type(cur.id) == "number" and q then
			currencies[cur.id] = q > 0 and q or nil
			seen[cur.id] = true
		end
	end
	for _, list in ipairs(lists) do
		for _, cur in ipairs(list) do
			take(cur)
		end
	end
	-- Saved before but not listed now (under a collapsed header, or spent to 0 and gone from the backpack list):
	-- asked by id. No answer (the client has not loaded its currencies yet) keeps the saved quantity.
	for id in pairs(type(c.currencies) == "table" and c.currencies or {}) do
		if not seen[id] then
			local cur = A.CurrencyInfo(id)
			if cur then
				take(cur)
			end
		end
	end
	c.currencies = currencies
	return true
end

-- Lines of { name, <field>, class } for the entries whose value(of) is a number above 0, most first;
-- the total is over every such entry (the cap hides lines, not gold).
local function lines(list, value, field)
	local shared = {}
	local function nameOf(e)
		return e.name or e.key or "?"
	end
	local function shown(e)
		local v = value(e)
		return type(v) == "number" and v > 0 and v or nil
	end
	for _, e in ipairs(list) do
		if shown(e) then -- only the lines the tooltip shows: a namesake with none of this value adds no "-realm"
			shared[nameOf(e)] = (shared[nameOf(e)] or 0) + 1
		end
	end
	local rows, total = {}, 0
	for _, e in ipairs(list) do
		local v = shown(e)
		if v then
			total = total + v
			local name = nameOf(e)
			name = shared[name] > 1 and e.realm and (name .. "-" .. e.realm) or name
			rows[#rows + 1] = { name = name, [field] = v, class = e.class }
		end
	end
	table.sort(rows, function(a, b)
		if a[field] ~= b[field] then
			return a[field] > b[field]
		end
		return a.name < b.name
	end)
	if #rows > Wealth.MAX_LINES then
		local more = #rows - Wealth.MAX_LINES
		for i = #rows, Wealth.MAX_LINES + 1, -1 do
			rows[i] = nil
		end
		rows[#rows + 1] = { more = more }
	end
	return rows, total
end

function Wealth.GoldLines(list, warband)
	local rows, total = lines(list, function(e)
		return e.money
	end, "copper")
	return rows, total + (type(warband) == "number" and warband or 0)
end

function Wealth.CurrencyLines(list, currencyID)
	return (lines(list, function(e)
		return type(e.currencies) == "table" and e.currencies[currencyID] or nil
	end, "quantity"))
end

function Wealth.lastWarband()
	if not SB.Adapter.Has("warband") then
		return nil
	end
	local v = SB.Snapshots.DB().warbandMoney
	return type(v) == "number" and v or nil
end

function Wealth.RefreshWarband()
	local A = SB.Adapter
	if not A.Has("warband") then
		return nil -- WoW Forever has no Warband bank: nothing read, nothing saved, no line
	end
	local live = A.WarbandMoney()
	if type(live) ~= "number" or A.IsSecret(live) then
		return Wealth.lastWarband()
	end
	if not SB.Config.readOnly and SB.Config.db then
		SB.Snapshots.DB().warbandMoney = live
	end
	return live
end

local function later()
	SB.Debounce("wealth.save", Wealth.DELAY, Wealth.Save, "none")
end

SB.On("PLAYER_ENTERING_WORLD", later, "none")
SB.On("PLAYER_MONEY", later, "none")
SB.On("CURRENCY_DISPLAY_UPDATE", later, "none")
SB.On("BANKFRAME_OPENED", function()
	Wealth.RefreshWarband()
end, "none")
SB.On("PLAYER_LOGOUT", function()
	Wealth.Save()
end, "none")
