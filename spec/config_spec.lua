local Loader = dofile("spec/helpers/loader.lua")

describe("Config", function()
	local SB, Config
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/Config.lua" })
		Config = SB.Config
	end)

	it("creates fresh tables at schema 2 when nothing is saved", function()
		assert.equal("new", Config.Init(nil, nil))
		assert.equal(2, Config.db.schemaVersion)
		assert.equal(2, Config.charDB.schemaVersion)
		assert.same({}, Config.db.errors)
		assert.same({}, Config.db.categories)
		assert.same({}, Config.db.userEdits)
		assert.is_nil(Config.db.categoryOrder)
		assert.same({ positions = {}, collapsed = {} }, Config.UI())
	end)

	it("defaults to the category view with two New rows and the reagent bag mixed in", function()
		Config.Init(nil, nil)
		assert.equal("sections", Config.Get("bags.view"))
		assert.equal(2, Config.Get("bags.newRows"))
		assert.equal(false, Config.Get("bags.reagentSeparate"))
	end)

	it("v1 -> v2 adds empty category tables, keeps settings, and gives the character collapse state", function()
		local db = { schemaVersion = 1, settings = { bags = { columns = 8 } }, errors = {}, backups = {} }
		local char = { schemaVersion = 1, overrides = {}, ui = { positions = { bags = { "CENTER" } } }, backups = {} }
		assert.equal("migrated", Config.Init(db, char))
		assert.equal(2, db.schemaVersion)
		assert.same({}, db.categories)
		assert.same({}, db.userEdits)
		assert.equal(8, Config.Get("bags.columns"))
		assert.equal(2, char.schemaVersion)
		assert.same({ positions = { bags = { "CENTER" } }, collapsed = {} }, Config.UI())
	end)

	it("v1 -> v2 repairs damaged category values instead of failing", function()
		local db = { schemaVersion = 1, settings = {}, errors = {}, backups = {}, categories = "x", categoryOrder = 5 }
		assert.equal("migrated", Config.Init(db, nil))
		assert.same({}, db.categories)
		assert.is_nil(db.categoryOrder)
		assert.is_nil(db.backups.v1)
	end)

	it("v1 -> v2 is additive: a v1 DB that already has some v2 fields keeps all user data", function()
		local db = {
			schemaVersion = 1, settings = {}, errors = {}, backups = {},
			categories = { mine = { name = "Mine" } },
			userEdits = { potions = { hidden = true } },
			categoryOrder = { "mine", "potions" },
		}
		local char = { schemaVersion = 1, overrides = {}, backups = {},
			ui = { positions = {}, collapsed = { bags = { mine = true } } } }
		assert.equal("migrated", Config.Init(db, char))
		assert.same({ mine = { name = "Mine" } }, db.categories)
		assert.same({ potions = { hidden = true } }, db.userEdits)
		assert.same({ "mine", "potions" }, db.categoryOrder)
		assert.same({ bags = { mine = true } }, Config.UI().collapsed)
		assert.is_nil(db.backups.v1)
	end)

	it("the v2 migrations are idempotent when run twice", function()
		local db = { schemaVersion = 1, settings = {}, errors = {}, backups = {} }
		Config.migrations[2](db)
		db.categories.a = { name = "A" }
		db.userEdits.b = { x = 1 }
		Config.migrations[2](db)
		assert.same({ a = { name = "A" } }, db.categories)
		assert.same({ b = { x = 1 } }, db.userEdits)
		local c = { ui = { positions = {} } }
		Config.charMigrations[2](c)
		c.ui.collapsed.bags = { s = true }
		Config.charMigrations[2](c)
		assert.same({ bags = { s = true } }, c.ui.collapsed)
	end)

	it("migrates a real week-1 v1 table and keeps its errors and backups", function()
		local db = {
			schemaVersion = 1,
			settings = { bags = { columns = 9, scale = 0.9 }, safeMode = { bags = true, bank = false } },
			errors = { { msg = "boom", count = 3 } },
			backups = { reset = { settings = { bags = { columns = 4 } } } },
		}
		local char = {
			schemaVersion = 1,
			overrides = { ["bags.columns"] = 6 },
			ui = { positions = { bags = { "CENTER", 0, 0 } } },
			backups = { v0 = { old = true } },
		}
		assert.equal("migrated", Config.Init(db, char))
		assert.equal(2, db.schemaVersion)
		assert.same({ { msg = "boom", count = 3 } }, db.errors)
		assert.same({ reset = { settings = { bags = { columns = 4 } } } }, db.backups)
		assert.equal(0.9, Config.Get("bags.scale"))
		assert.equal(true, Config.Get("safeMode.bags"))
		assert.equal(6, Config.Get("bags.columns"))
		assert.equal("sections", Config.Get("bags.view"))
		assert.same({ v0 = { old = true } }, char.backups)
		assert.same({ bags = { "CENTER", 0, 0 } }, Config.UI().positions)
		assert.same({}, Config.UI().collapsed)
		assert.is_nil(Config.lastError)
	end)

	it("a week-1 build (CURRENT = 1) refuses a schema 2 DB: read-only, nothing touched", function()
		Config.CURRENT = 1
		local db = { schemaVersion = 2, settings = {}, errors = {}, backups = {}, categories = { a = {} }, userEdits = {} }
		local char = { schemaVersion = 2, overrides = {}, ui = { positions = {}, collapsed = {} }, backups = {} }
		assert.equal("newer", Config.Init(db, char))
		assert.truthy(Config.readOnly)
		assert.falsy(Config.Set("bags.columns", 3))
		assert.equal(2, db.schemaVersion)
		assert.equal(2, char.schemaVersion)
		assert.same({ a = {} }, db.categories)
		assert.same({ positions = {}, collapsed = {} }, char.ui)
		assert.same({}, db.backups)
	end)

	it("a week-1 build refuses when only the character DB is schema 2", function()
		Config.CURRENT = 1
		local db = { schemaVersion = 1, settings = {}, errors = {}, backups = {} }
		local char = { schemaVersion = 2, overrides = {}, ui = { positions = {}, collapsed = {} }, backups = {} }
		assert.equal("newer", Config.Init(db, char))
		assert.same({ schemaVersion = 1, settings = {}, errors = {}, backups = {} }, db)
	end)

	it("a failed migration keeps the DB's existing backups (account and character)", function()
		Config.migrations[2] = function() error("acct boom") end
		Config.charMigrations[2] = function() error("char boom") end
		local db = { schemaVersion = 1, settings = { a = 1 }, errors = {}, backups = { reset = { marker = true } } }
		local char = { schemaVersion = 1, overrides = {}, ui = { positions = {} }, backups = { reset = { marker = true } } }
		assert.equal("reset", Config.Init(db, char))
		assert.same({ marker = true }, Config.db.backups.reset)
		assert.equal(1, Config.db.backups.v1.settings.a)
		assert.same({ marker = true }, Config.charDB.backups.reset)
		assert.truthy(Config.charDB.backups.v1)
	end)

	it("a v2 migration that throws backs up the v1 table and resets", function()
		Config.migrations[2] = function(d) d.categories = {}; error("v2 exploded") end
		local saved = { schemaVersion = 1, settings = { bags = { columns = 7 } }, errors = {}, backups = {} }
		assert.equal("reset", Config.Init(saved, nil))
		assert.equal(2, Config.db.schemaVersion)
		assert.equal(7, Config.db.backups.v1.settings.bags.columns)
		assert.truthy(Config.lastError:find("v2 exploded", 1, true))
		assert.same({}, Config.db.userEdits)
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
		assert.equal(2, Config.db.schemaVersion)
		assert.equal(8, Config.Get("bags.columns"))
		assert.same({ "CENTER" }, Config.UI().positions.bags)
	end)

	it("runs migrations in order (synthetic v2 -> v3)", function()
		Config.CURRENT = 3
		local order = {}
		local v1, v2 = Config.migrations[1], Config.migrations[2]
		Config.migrations[1] = function(db) order[#order + 1] = 1; v1(db) end
		Config.migrations[2] = function(db) order[#order + 1] = 2; v2(db) end
		Config.migrations[3] = function(db) order[#order + 1] = 3; db.settings.newThing = true end
		Config.charMigrations[3] = function() end
		assert.equal("migrated", Config.Init({}, nil))
		assert.same({ 1, 2, 3 }, order)
		assert.equal(3, Config.db.schemaVersion)
		assert.equal(true, Config.db.settings.newThing)
		assert.same({}, Config.db.userEdits)
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
		assert.equal(2, db.schemaVersion)
		assert.equal(5, db.backups.reset.settings.bags.columns)
		assert.is_nil(charDB.backups.reset)
		assert.truthy(Config.Set("bags.columns", 9))
	end)

	it("account DB v99 does not migrate character DB v0", function()
		local saved_db = { schemaVersion = 99, settings = { bags = { columns = 5 } } }
		local saved_char = { schemaVersion = 0, ui = { positions = { bags = { "CENTER" } } } }
		assert.equal("newer", Config.Init(saved_db, saved_char))
		-- Verify the character table is unchanged (no backups added)
		assert.same({ schemaVersion = 0, ui = { positions = { bags = { "CENTER" } } } }, saved_char)
	end)

	it("character DB v99 does not migrate account DB v0", function()
		local saved_db = { schemaVersion = 0, settings = { bags = { columns = 7 } } }
		local saved_char = { schemaVersion = 99, ui = { positions = {} } }
		assert.equal("newer", Config.Init(saved_db, saved_char))
		-- Verify the account table is unchanged (no backups added)
		assert.same({ schemaVersion = 0, settings = { bags = { columns = 7 } } }, saved_db)
	end)

	it("after failed migration, Reset preserves v<N> backup and adds reset backup", function()
		Config.CURRENT = 2
		Config.migrations[2] = function() error("broken step") end
		local saved = { schemaVersion = 1, settings = { bags = { columns = 7 } }, errors = {}, backups = {} }
		assert.equal("reset", Config.Init(saved, nil))
		-- Verify we have v1 backup from migration failure (preserves original data)
		assert.equal(7, Config.db.backups.v1.settings.bags.columns)
		-- Now Reset (both db and charDB returned)
		local db, charDB = Config.Reset()
		-- Verify schemaVersion matches Config.CURRENT (which is 2 in this test)
		assert.equal(2, charDB.schemaVersion)
		-- Verify v<N> backup from migration failure is preserved
		assert.equal(7, db.backups.v1.settings.bags.columns)
		-- Verify reset backup exists
		assert.truthy(db.backups.reset)
	end)

	it("after new Init, Set, then Reset, backups.reset has the set value", function()
		Config.Init(nil, nil)
		assert.truthy(Config.Set("bags.columns", 9))
		local db, charDB = Config.Reset()
		-- Verify charDB has the correct schema version
		assert.equal(2, charDB.schemaVersion)
		assert.equal(9, db.backups.reset.settings.bags.columns)
	end)
end)
