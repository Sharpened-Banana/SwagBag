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
end)
