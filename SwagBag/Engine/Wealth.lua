-- SwagBag wealth (0.17): each character's gold and currencies, saved so the footer tooltips can
-- show every character (spec 2). Pure Lua over the Adapter; the data lives on the character's
-- own table in SwagBagDB.chars (Engine/Snapshots.lua), read back through AltData.Wealth.
--   Wealth.Save() -> bool   writes c.money (copper) and c.currencies ({ [currencyID] = quantity })
--       on the current character; the currencies are the union by id of the backpack list and the
--       Currency tab list, a quantity of 0 leaves the id out; lists that come back empty leave the
--       saved ones as they were. Gold the game cannot say leaves
--       money as it was. Read-only settings: nothing written, false
--   Wealth.MAX_LINES   the most character lines a tooltip lists; the rest become one { more = n } entry
--   Wealth.GoldLines(list, warband) -> lines, total   pure, over AltData.Wealth entries: { { name, copper,
--       class } } richest first (ties by name), money > 0 only, "-realm" only where another entry shares
--       the name, capped with a last { more = n }; total = every character's gold + warband (nil: 0)
--   Wealth.CurrencyLines(list, currencyID) -> lines   the same with quantity, most first
--   Wealth.RefreshWarband() -> copper|nil   the Warband bank's gold when the client says, saved in
--       SwagBagDB.warbandMoney (not while read-only); else the saved amount. Also on BANKFRAME_OPENED
--   Wealth.lastWarband() -> copper|nil   the saved warband gold
--   Wealth.DELAY   seconds the saves after PLAYER_MONEY / CURRENCY_DISPLAY_UPDATE wait for the last
--       one (SB.Debounce); PLAYER_ENTERING_WORLD saves the same way, PLAYER_LOGOUT at once
local _, SB = ...

local Wealth = { DELAY = 2, MAX_LINES = 20 }
SB.Wealth = Wealth

local function quantityOf(c)
	local q = c and c.quantity
	if type(q) == "number" and not SB.Adapter.IsSecret(q) and q > 0 then
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
	local currencies, any = {}, false
	for _, list in ipairs({ A.BackpackCurrencies() or {}, A.CurrencyList() or {} }) do
		for _, cur in ipairs(list) do
			local q = quantityOf(cur)
			if type(cur.id) == "number" and q then
				currencies[cur.id] = q
				any = true
			end
		end
	end
	if any then -- both lists empty means the client has not loaded them yet: keep what was saved
		c.currencies = currencies
	end
	return true
end

-- Lines of { name, <field>, class } for the entries whose value(of) is a number above 0, most first;
-- the total is over every such entry (the cap hides lines, not gold).
local function lines(list, value, field)
	local shared = {}
	for _, e in ipairs(list) do
		shared[e.name] = (shared[e.name] or 0) + 1
	end
	local rows, total = {}, 0
	for _, e in ipairs(list) do
		local v = value(e)
		if type(v) == "number" and v > 0 then
			total = total + v
			local name = shared[e.name] > 1 and e.realm and (e.name .. "-" .. e.realm) or e.name
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
	local v = SB.Snapshots.DB().warbandMoney
	return type(v) == "number" and v or nil
end

function Wealth.RefreshWarband()
	local A = SB.Adapter
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
