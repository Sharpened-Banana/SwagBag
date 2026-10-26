-- 0.16.0 (user answer Q14): bare cloth and leather now also find cloth and leather armor. At the first login with
-- this version, one chat note names the user's saved rules that use either word bare; nothing is rewritten.
local Loader = dofile("spec/helpers/loader.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Search notes (0.16.0)", function()
	local SB, A, N
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/SearchNotes.lua"
		SB = Loader.New(files)
		A, N = SB.Adapter, SB.SearchNotes
		SB.Config.Init(nil, nil)
	end)

	it("BareClothLeather finds the words used bare, never inside a phrase, a name or a quote", function()
		assert.equal(true, N.BareClothLeather("herb | cloth"))
		assert.equal(true, N.BareClothLeather("!LEATHER & bound"))
		assert.equal(true, N.BareClothLeather("#cloth"))
		assert.equal(false, N.BareClothLeather("cloth material | leather armor"))
		assert.equal(false, N.BareClothLeather("\"Runecloth\" | wildercloth | \"cloth\""))
		assert.equal(false, N.BareClothLeather("cloth &"), "a broken rule")
		assert.equal(false, N.BareClothLeather(nil))
	end)

	-- Mutations: drop the `if d.notes.clothLeather then` check (a note at every login); or name every category.
	it("first login with this version: one note naming the saved rules, never again", function()
		local d = SB.Config.db
		d.categories.u_x = { name = "Mats", query = "cloth | herb", priority = 58, displayOrder = 55 }
		d.categories.u_y = { name = "Ore stuff", query = "ore", priority = 57, displayOrder = 56 }
		d.userEdits.c_leathercloth = { query = "leather | cloth" }
		SB.Emit("SB_LOGIN")
		SB.Emit("SB_LOGIN")
		local lines = A.Lines()
		assert.equal(1, #lines)
		assert.truthy(lines[1]:find("Mats", 1, true), lines[1])
		assert.truthy(lines[1]:find(SB.L.CAT_LEATHERCLOTH, 1, true), lines[1])
		assert.falsy(lines[1]:find("Ore stuff", 1, true))
		assert.truthy(d.notes.clothLeather)
	end)

	it("no saved rule uses the words: no note, and the check is not made again", function()
		SB.Emit("SB_LOGIN")
		assert.same({}, A.Lines())
		assert.truthy(SB.Config.db.notes.clothLeather)
	end)

	it("a watch-list search counts too, named by its search", function()
		SB.Config.Set("consumables.watch", { { query = "leather", threshold = 5 } })
		SB.Emit("SB_LOGIN")
		assert.truthy(A.Lines()[1]:find("leather", 1, true))
	end)

	-- Q14: the built-in Leather & Cloth category keeps meaning the materials only.
	it("the default Leather & Cloth category uses the material keywords", function()
		for _, def in ipairs(SB.CategoryDefaults) do
			if def.id == "c_leathercloth" then
				assert.equal(false, N.BareClothLeather(def.query))
				assert.equal("leather material | cloth material", def.query)
			end
		end
	end)
end)
