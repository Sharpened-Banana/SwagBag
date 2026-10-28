-- SwagBag wealth (0.17): each character's gold and currencies, saved so the footer tooltips can
-- show every character (spec 2). Pure Lua over the Adapter; the data lives on the character's
-- own table in SwagBagDB.chars (Engine/Snapshots.lua), read back through AltData.Wealth.
--   Wealth.Save() -> bool   writes c.money (copper) and c.currencies ({ [currencyID] = quantity })
--       on the current character; the currencies are the union by id of the backpack list and the
--       Currency tab list, a quantity of 0 leaves the id out. Gold the game cannot say leaves
--       money as it was. Read-only settings: nothing written, false
--   Wealth.DELAY   seconds the saves after PLAYER_MONEY / CURRENCY_DISPLAY_UPDATE wait for the last
--       one (SB.Debounce); PLAYER_ENTERING_WORLD saves the same way, PLAYER_LOGOUT at once
local _, SB = ...

local Wealth = { DELAY = 2 }
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
	local currencies = {}
	for _, list in ipairs({ A.BackpackCurrencies() or {}, A.CurrencyList() or {} }) do
		for _, cur in ipairs(list) do
			local q = quantityOf(cur)
			if type(cur.id) == "number" and q then
				currencies[cur.id] = q
			end
		end
	end
	c.currencies = currencies
	return true
end

local function later()
	SB.Debounce("wealth.save", Wealth.DELAY, Wealth.Save, "none")
end

SB.On("PLAYER_ENTERING_WORLD", later, "none")
SB.On("PLAYER_MONEY", later, "none")
SB.On("CURRENCY_DISPLAY_UPDATE", later, "none")
SB.On("PLAYER_LOGOUT", function()
	Wealth.Save()
end, "none")
