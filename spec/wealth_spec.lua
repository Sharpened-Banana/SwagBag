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
end)
