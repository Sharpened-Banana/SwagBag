local Loader = dofile("spec/helpers/loader.lua")

describe("Config", function()
	local SB, Config
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/Config.lua" })
		Config = SB.Config
	end)

	it("creates fresh tables at schema 1 when nothing is saved", function()
		assert.equal("new", Config.Init(nil, nil))
		assert.equal(1, Config.db.schemaVersion)
		assert.equal(1, Config.charDB.schemaVersion)
		assert.same({}, Config.db.errors)
		assert.same({ positions = {} }, Config.UI())
	end)

	it("Get falls back to the defaults", function()
		Config.Init(nil, nil)
		assert.equal(12, Config.Get("bags.columns"))
		assert.equal(false, Config.Get("safeMode.bank"))
		assert.is_nil(Config.Get("bags.nope"))
	end)

	it("Set stores account-wide and Get reads it back", function()
		Config.Init(nil, nil)
		assert.truthy(Config.Set("bags.columns", 10))
		assert.equal(10, Config.Get("bags.columns"))
		assert.equal(10, Config.db.settings.bags.columns)
	end)

	it("a character override wins, takes Set, and falls back when removed", function()
		Config.Init(nil, nil)
		Config.Set("bags.columns", 10)
		Config.CharOverride("bags.columns", true)
		assert.truthy(Config.IsCharOverride("bags.columns"))
		Config.Set("bags.columns", 16)
		assert.equal(16, Config.Get("bags.columns"))
		assert.equal(10, Config.db.settings.bags.columns)
		Config.CharOverride("bags.columns", false)
		assert.equal(10, Config.Get("bags.columns"))
	end)

	it("an override of false is respected", function()
		Config.Init(nil, nil)
		Config.Set("safeMode.bags", true)
		Config.CharOverride("safeMode.bags", true)
		Config.Set("safeMode.bags", false)
		assert.equal(false, Config.Get("safeMode.bags"))
	end)

	it("migrates a v0 table (no schemaVersion) and keeps its settings", function()
		local old = { settings = { bags = { columns = 8 } } }
		assert.equal("migrated", Config.Init(old, { ui = { positions = { bags = { "CENTER" } } } }))
		assert.equal(1, Config.db.schemaVersion)
		assert.equal(8, Config.Get("bags.columns"))
		assert.same({ "CENTER" }, Config.UI().positions.bags)
	end)

	it("runs migrations in order (synthetic v1 -> v2)", function()
		Config.CURRENT = 2
		local order = {}
		local v1 = Config.migrations[1]
		Config.migrations[1] = function(db) order[#order + 1] = 1; v1(db) end
		Config.migrations[2] = function(db) order[#order + 1] = 2; db.settings.newThing = true end
		Config.charMigrations[2] = function() end
		assert.equal("migrated", Config.Init({}, nil))
		assert.same({ 1, 2 }, order)
		assert.equal(2, Config.db.schemaVersion)
		assert.equal(true, Config.db.settings.newThing)
	end)

	it("a failing migration keeps a backup and resets to defaults", function()
		Config.CURRENT = 2
		Config.migrations[2] = function() error("broken step") end
		local saved = { schemaVersion = 1, settings = { bags = { columns = 7 } }, errors = {}, backups = {} }
		assert.equal("reset", Config.Init(saved, nil))
		assert.equal(2, Config.db.schemaVersion)
		assert.equal(12, Config.Get("bags.columns"))
		assert.equal(7, Config.db.backups.v1.settings.bags.columns)
		assert.truthy(Config.lastError:find("broken step", 1, true))
	end)

	it("refuses a newer schema: read-only, saved table untouched", function()
		local saved = { schemaVersion = 99, settings = { bags = { columns = 5 } } }
		assert.equal("newer", Config.Init(saved, nil))
		assert.truthy(Config.readOnly)
		assert.falsy(Config.Set("bags.columns", 3))
		assert.equal(12, Config.Get("bags.columns"))
		assert.same({ schemaVersion = 99, settings = { bags = { columns = 5 } } }, saved)
	end)

	it("Reset backs up what was saved and starts fresh", function()
		local saved = { schemaVersion = 99, settings = { bags = { columns = 5 } } }
		Config.Init(saved, nil)
		local db, charDB = Config.Reset()
		assert.falsy(Config.readOnly)
		assert.equal(1, db.schemaVersion)
		assert.equal(5, db.backups.reset.settings.bags.columns)
		assert.is_nil(charDB.backups.reset)
		assert.truthy(Config.Set("bags.columns", 9))
	end)
end)
