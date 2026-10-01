local Loader = dofile("spec/helpers/loader.lua")
local Globals = dofile("spec/helpers/globals.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Boot.lua",
}

describe("Boot", function()
	local SB, A, loginSeen
	before_each(function()
		SwagBagDB, SwagBagCharDB = nil, nil
		SB = Loader.New(FILES)
		A = SB.Adapter
		A.globals = Globals.AllPresent(A)
		loginSeen = false
		SB.On("SB_LOGIN", function() loginSeen = true end)
	end)

	after_each(function()
		SwagBagDB, SwagBagCharDB = nil, nil
	end)

	it("ADDON_LOADED for another addon is ignored", function()
		SB.eventFrame:Fire("ADDON_LOADED", "Auctionator")
		assert.is_nil(SwagBagDB)
	end)

	it("creates the saved tables and attaches the error ring", function()
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		assert.equal(1, SwagBagDB.schemaVersion)
		assert.equal(SwagBagDB.errors, SB.ErrorTrap.buffer)
	end)

	it("a new install hands the fresh tables to the saved globals", function()
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		assert.equal(SB.Config.db, SwagBagDB)
		assert.equal(SB.Config.charDB, SwagBagCharDB)
		assert.equal("new", SB.Config.status)
	end)

	it("a reset after a failed migration hands the reset tables to the saved globals", function()
		SB.Config.CURRENT = 2
		SB.Config.migrations[2] = function() error("bad step") end
		SB.Config.charMigrations[2] = function() end
		local old = { schemaVersion = 1, settings = {}, errors = {}, backups = {} }
		SwagBagDB = old
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		assert.equal(SB.Config.db, SwagBagDB)
		assert.truthy(SwagBagDB ~= old)
		assert.equal(SB.Config.charDB, SwagBagCharDB)
	end)

	it("login runs checks, prints the loaded line, and emits SB_LOGIN", function()
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.same({ "v" .. SB.VERSION .. " loaded. Type /swagbag help for commands." }, A.Lines())
		assert.truthy(loginSeen)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("a failed required check at login puts that window in Safe Mode", function()
		A.globals.ContainerFrameCombinedBags = nil
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.equal("check", SB.SafeMode.state.bags.reason)
	end)

	it("a newer schema is left untouched, both windows go to Safe Mode, one warning", function()
		local saved = { schemaVersion = 7 }
		SwagBagDB = saved
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.equal(saved, SwagBagDB)
		assert.same({ schemaVersion = 7 }, saved)
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.equal(SB.L.NEWER_SCHEMA, A.Lines()[1])
	end)

	it("a remembered manual Safe Mode is restored at login", function()
		SwagBagDB = { schemaVersion = 1, settings = { safeMode = { bank = true } }, errors = {}, backups = {} }
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.equal("manual", SB.SafeMode.state.bank.reason)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("a failed migration is reported in chat and recorded for /swagbag report", function()
		SB.Config.CURRENT = 2
		SB.Config.migrations[2] = function() error("bad step") end
		SB.Config.charMigrations[2] = function() end
		SwagBagDB = { schemaVersion = 1, settings = {}, errors = {}, backups = {} }
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.equal(SB.L.MIGRATION_FAILED, A.Lines()[1])
		assert.equal("Config.migrate", SB.ErrorTrap.Recent()[1].label)
		assert.truthy(SwagBagDB.backups.v1)
	end)
	it("an error during login switches both windows to Safe Mode (it is not silent)", function()
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.Checks.Run = function() error("checks broke") end
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.equal("both", SB.ErrorTrap.Recent()[1].window)
	end)
end)
