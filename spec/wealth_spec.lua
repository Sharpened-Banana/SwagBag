-- Wealth (Engine/Wealth.lua): this character's gold and currencies saved for the footer tooltips.
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Snapshots.lua",
	"SwagBag/Engine/AltData.lua", "SwagBag/Engine/Wealth.lua",
}

describe("Wealth", function()
	local SB, A, W
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		W = SB.Wealth
	end)

	local function me()
		return SB.Snapshots.DB().chars["Swagger-Argent Dawn"]
	end

	it("saves gold and the currencies with a quantity, union of backpack and list", function()
		A.money = 1234567
		A.backpack = { { id = 3008, name = "Valorstones", quantity = 50 } }
		A.currencies = { { id = 3008, name = "Valorstones", quantity = 50 }, { id = 2815, name = "Resonance", quantity = 0 },
			{ id = 3100, name = "Other", quantity = 7 } }
		assert.equal(true, W.Save())
		local c = me()
		assert.same({ [3008] = 50, [3100] = 7 }, c.currencies)
		assert.equal(1234567, c.money)
	end)

	it("keeps the last gold when the game cannot say", function()
		A.money = 500
		W.Save()
		A.money = nil
		W.Save()
		assert.equal(500, me().money)
	end)

	it("keeps the saved currencies when the game lists none yet", function()
		A.money = 10
		A.backpack = { { id = 3008, name = "Valorstones", quantity = 50 } }
		W.Save()
		A.backpack, A.currencies = {}, {}
		W.Save()
		assert.same({ [3008] = 50 }, me().currencies)
	end)

	-- Review fix (PR #1). Mutation: Save starts from an empty table again (or skips the ask-by-id loop).
	it("a currency under a collapsed Currency-tab header keeps its saved amount, asked again by id", function()
		A.money = 1
		A.currencies = { { id = 3008, name = "Valorstones", quantity = 50 }, { id = 3100, name = "Other", quantity = 7 } }
		W.Save()
		A.currencies = { { id = 3008, name = "Valorstones", quantity = 60 } } -- the header holding 3100 is collapsed
		local real = A.CurrencyInfo
		A.CurrencyInfo = function(id)
			if id == 3100 then
				return { id = 3100, name = "Other", quantity = 9 }
			end
			return real(id)
		end
		W.Save()
		assert.same({ [3008] = 60, [3100] = 9 }, me().currencies)
		A.CurrencyInfo = function() return nil end -- the client cannot answer by id: the saved amount stays
		A.currencies = { { id = 3008, name = "Valorstones", quantity = 61 } }
		W.Save()
		assert.same({ [3008] = 61, [3100] = 9 }, me().currencies)
	end)

	-- Review fix (PR #1). Mutation: quantityOf refuses 0 again (a spent currency keeps its old amount).
	it("spending the last of a currency is saved: it leaves the list, even when it was the only one", function()
		A.money = 1
		A.backpack = { { id = 3008, name = "Valorstones", quantity = 40 } }
		W.Save()
		assert.same({ [3008] = 40 }, me().currencies)
		A.backpack = { { id = 3008, name = "Valorstones", quantity = 0 } }
		W.Save()
		assert.same({}, me().currencies)
		A.backpack = { { id = 3008, name = "Valorstones", quantity = 40 } }
		W.Save()
		A.backpack, A.currencies = {}, { { id = 3008, name = "Valorstones", quantity = 0 } } -- gone from the backpack list
		W.Save()
		assert.same({}, me().currencies)
	end)

	it("writes nothing while the settings are read-only", function()
		A.money = 500
		SB.Config.readOnly = true
		assert.equal(false, W.Save())
		assert.is_nil(me() and me().money)
	end)

	it("saves at logout and, debounced, after PLAYER_MONEY", function()
		A.money = 100
		SB.eventFrame:Fire("PLAYER_MONEY")
		assert.is_nil(me() and me().money)
		A.Advance(W.DELAY + 0.1)
		assert.equal(100, me().money)
		A.money = 250
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		assert.equal(250, me().money)
	end)

	local function entry(name, realm, money, currencies)
		return { key = name .. "-" .. realm, name = name, realm = realm, class = "MAGE", money = money, currencies = currencies }
	end
	local function names(lines)
		local out = {}
		for i, l in ipairs(lines) do
			out[i] = l.name
		end
		return out
	end

	it("gold lines: richest first, zero left out, realm only for a shared name, total with the warband", function()
		local list = { entry("Ann", "A", 500), entry("Bob", "A", 0), entry("Ann", "B", 900), entry("Cy", "A", 900),
			entry("Old", "A", nil) }
		local lines, total = W.GoldLines(list, 100)
		assert.same({ "Ann-B", "Cy", "Ann-A" }, names(lines))
		assert.equal(900, lines[1].copper)
		assert.equal("MAGE", lines[1].class)
		assert.equal(2400, total)
		local _, noWarband = W.GoldLines(list, nil)
		assert.equal(2300, noWarband)
	end)

	it("caps at 20 lines and says how many more", function()
		local list, sum = {}, 0
		for i = 1, 23 do
			list[i] = entry(string.format("C%02d", i), "A", i * 10)
			sum = sum + i * 10
		end
		local lines, total = W.GoldLines(list, nil)
		assert.equal(W.MAX_LINES + 1, #lines)
		assert.same({ more = 3 }, lines[#lines])
		assert.equal("C23", lines[1].name)
		assert.equal(sum, total, "the total is not capped")
	end)

	it("currency lines use the saved quantity of that currency only", function()
		local list = { entry("Ann", "A", 1, { [3008] = 50, [2815] = 900 }), entry("Bob", "A", 1, { [3008] = 70 }),
			entry("Cy", "A", 1, { [2815] = 5 }), entry("Dee", "A", 1, { [3008] = 0 }), entry("Old", "A", nil) }
		local lines = W.CurrencyLines(list, 3008)
		assert.same({ "Bob", "Ann" }, names(lines))
		assert.equal(70, lines[1].quantity)
		assert.same({}, W.CurrencyLines(list, 1))
	end)

	it("keeps the last warband gold across a relog, and writes none while read-only", function()
		assert.is_nil(W.lastWarband())
		A.gold = nil
		A.WarbandMoney = function() return 777 end
		assert.equal(777, W.RefreshWarband())
		assert.equal(777, SB.Snapshots.DB().warbandMoney)
		A.WarbandMoney = function() return nil end
		assert.equal(777, W.RefreshWarband(), "unknown keeps the saved amount")
		assert.equal(777, W.lastWarband())
		A.WarbandMoney = function() return 5 end
		SB.Config.readOnly = true
		assert.equal(5, W.RefreshWarband(), "the live amount is still answered")
		assert.equal(777, SB.Snapshots.DB().warbandMoney, "nothing written")
		SB.Config.readOnly = false
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.equal(5, SB.Snapshots.DB().warbandMoney)
	end)

	-- Final review. Mutation: no gate in RefreshWarband (Forever reads and saves a warband it does not have).
	it("on WoW Forever the warband gold is never read or saved", function()
		local F = Loader.New(FILES, { flavor = "forever" })
		F.Config.Init(nil, nil)
		local reads = 0
		F.Adapter.WarbandMoney = function() reads = reads + 1 return 777 end
		assert.is_nil(F.Wealth.RefreshWarband())
		assert.equal(0, reads)
		assert.is_nil(F.Snapshots.DB().warbandMoney)
		assert.is_nil(F.Wealth.lastWarband())
	end)

	-- Mutation: Save reads only the two lists (a currency under a collapsed header is dropped).
	it("saves a crest currency the Currency tab list leaves out", function()
		SB.Crests = { currencies = { 3100, 3101 } }
		A.money = 1
		A.backpack = {}
		A.currencies = { { id = 3008, name = "Valorstones", quantity = 5 } }
		local real = A.CurrencyInfo
		A.CurrencyInfo = function(id)
			if id == 3100 then
				return { id = 3100, name = "Crest", quantity = 12 }
			end
			return real(id)
		end
		W.Save()
		assert.same({ [3008] = 5, [3100] = 12 }, me().currencies)
	end)

	-- Review fix (PR #1). Mutation: count the namesakes over the whole list again.
	it("a namesake with none of the currency adds no realm suffix", function()
		local list = { entry("Bob", "Silvermoon", 100, { [3008] = 5 }), entry("Bob", "Ravencrest", 200, {}) }
		assert.equal("Bob", W.CurrencyLines(list, 3008)[1].name)
		local gold = W.GoldLines(list, nil)
		assert.same({ "Bob-Ravencrest", "Bob-Silvermoon" }, { gold[1].name, gold[2].name })
	end)

	-- Mutation: lines() indexes e.name unguarded.
	it("an entry with no name never errors", function()
		local rows = W.GoldLines({ { key = "x", money = 50 }, { money = 70 } }, nil)
		assert.equal(2, #rows)
		assert.equal("?", rows[1].name)
		assert.equal("x", rows[2].name)
	end)
end)
