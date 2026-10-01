local Loader = dofile("spec/helpers/loader.lua")

local FILES = { "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua" }

-- Test keywords over tiny hand-made records (independent of Engine/Keywords.lua).
local function registerTestKeywords(Q)
	Q.RegisterKeyword({ name = "boe", class = "instance", eval = function(r)
		if r.bind == nil then return nil end
		return r.bind == "equip" and not r.isBound
	end })
	Q.RegisterKeyword({ name = "potion", class = "static", eval = function(r) return r.kind == "potion" end })
	Q.RegisterKeyword({ name = "trade goods", aliases = { "tradegoods" }, class = "static",
		eval = function(r) return r.kind == "tradegoods" end })
	Q.RegisterKeyword({ name = "gear", class = "static",
		eval = function(r) return r.kind == "gear" end,
		value = function(r)
			if r.kind ~= "gear" then return false end
			return r.ilvl
		end })
	Q.RegisterKeyword({ name = "ilvl", class = "instance", value = function(r)
		if r.kind ~= "gear" then return false end
		return r.ilvl
	end })
	Q.RegisterKeyword({ name = "count", class = "volatile", value = function(r) return r.count end })
	Q.RegisterKeyword({ name = "mystery", class = "instance", eval = function() return nil end })
end

local POTION = { kind = "potion", name = "Algari Healing Potion", bind = "none", count = 5 }
local RING = { kind = "gear", name = "Band of the Fallen", bind = "equip", isBound = false, ilvl = 285, count = 1 }
local HELM = { kind = "gear", name = "Helm of Tests", bind = "pickup", isBound = true, ilvl = 270, count = 1 }
local LOADING = { kind = "gear", count = 1 } -- name, bind and ilvl not loaded yet
local HERB = { kind = "tradegoods", name = "Mycobloom", bind = "none", count = 40 }

describe("Query compile and eval", function()
	local Q
	before_each(function()
		Q = Loader.New(FILES).Query
		registerTestKeywords(Q)
	end)

	local function run(text, record)
		return Q.Eval(Q.Compile(text), record)
	end

	it("an empty search matches everything", function()
		local c = Q.Compile("   ")
		assert.truthy(c.empty)
		assert.same({}, c.errors)
		assert.equal(true, Q.Eval(c, POTION))
	end)

	it("a registered bare word is a keyword; any other word matches item names", function()
		assert.equal(true, run("potion", POTION))
		assert.equal(false, run("potion", RING))
		assert.equal(true, run("band", RING))
		assert.equal(true, run("BAND", RING))
		assert.equal(false, run("band", HELM))
	end)

	it("a multi-word phrase can be a keyword, and aliases work", function()
		assert.equal(true, run("trade goods", HERB))
		assert.equal(true, run("tradegoods", HERB))
		assert.equal(true, run("healing potion", POTION))
		assert.equal(false, run("healing potion", HERB))
	end)

	it("quoted text is always a name match, even when it equals a keyword", function()
		assert.equal(true, run("\"Potion\"", POTION))
		assert.equal(false, run("\"potion\"", { kind = "potion", name = "Flask" }))
	end)

	it("#word forces a keyword and an unknown #word is a positioned error", function()
		assert.equal(true, run("#potion", POTION))
		local c = Q.Compile("boe | #potin")
		assert.is_nil(c.fn)
		assert.same({ { position = 7, expected = "KEYWORD", got = "potin" } }, c.errors)
		assert.is_nil(Q.Eval(c, POTION))
	end)

	it("compares numbers with = < <= > >=", function()
		assert.equal(true, run("ilvl>280", RING))
		assert.equal(false, run("ilvl>285", RING))
		assert.equal(true, run("ilvl>=285", RING))
		assert.equal(true, run("ilvl<=285", RING))
		assert.equal(true, run("ilvl<300", RING))
		assert.equal(true, run("ilvl=285", RING))
		assert.equal(true, run("count>=5", POTION))
	end)

	it("a numeric test on an item without the field is false; on an unloaded item it is nil", function()
		assert.equal(false, run("ilvl>1", POTION))
		assert.is_nil(run("ilvl>1", LOADING))
		assert.equal(true, run("gear<280", HELM))
		assert.equal(false, run("gear<280", POTION))
	end)

	it("a number on a keyword that takes none is a positioned error", function()
		local c = Q.Compile("potion>3")
		assert.same({ { position = 1, expected = "NUMERIC", got = "potion" } }, c.errors)
	end)

	it("AND/OR/NOT follow tri-state rules", function()
		assert.equal(false, run("mystery & potion", RING), "false dominates AND")
		assert.is_nil(run("mystery & potion", POTION), "nil & true is nil")
		assert.equal(true, run("mystery | potion", POTION), "true dominates OR")
		assert.is_nil(run("mystery | potion", RING), "nil | false is nil")
		assert.is_nil(run("!mystery", RING))
		assert.equal(false, run("!potion", POTION))
	end)

	it("name text on an unloaded item is nil", function()
		assert.is_nil(run("band", LOADING))
		assert.is_nil(run("boe", LOADING))
	end)

	it("matches name text literally, including pattern characters, apostrophes and hyphens", function()
		local odd = { kind = "misc", name = "Kyveza's Ara-Kara Sack [50%]", count = 1 }
		assert.equal(true, run("\"[50%]\"", odd))
		assert.equal(true, run("kyveza's", odd))
		assert.equal(true, run("ara-kara", odd))
		assert.equal(false, run("\"(50%)\"", odd))
	end)

	it("matches pattern characters in bare query text literally", function()
		local odd = { kind = "misc", name = "Sack [50%] (big) a-b", count = 1 }
		assert.equal(true, run("[50%]", odd))
		assert.equal(true, run("\"(big)\"", odd))
		assert.equal(true, run("\"a-b\"", odd))
		assert.equal(false, run("\"a.b\"", odd))
		assert.equal(false, run("\"%w%w%w\"", odd))
		assert.equal(false, run("\"[a-z]\"", odd))
	end)

	it("matches the quoted phrase from the spec examples against names", function()
		assert.equal(true, run("\"Healing Potion\"", POTION))
		assert.equal(false, run("\"Healing Potion\"", HERB))
	end)

	it("takes the strongest cache class of the keywords used", function()
		assert.equal("static", Q.Compile("potion").cacheClass)
		assert.equal("static", Q.Compile("band").cacheClass)
		assert.equal("instance", Q.Compile("potion & boe").cacheClass)
		assert.equal("volatile", Q.Compile("boe | count>1").cacheClass)
	end)

	it("lists the keywords used, once each, in order", function()
		assert.same({ "boe", "potion", "ilvl" }, Q.Compile("boe & (potion | boe) & ilvl>1 & band").keywords)
	end)

	it("gives every successful compile its own id", function()
		local a, b = Q.Compile("boe"), Q.Compile("boe")
		assert.truthy(a.id ~= b.id)
	end)

	it("evaluates a gear, item level and boe combination", function()
		local c = Q.Compile("gear & ilvl>280 & !boe")
		assert.equal(false, Q.Eval(c, RING))
		assert.equal(false, Q.Eval(c, HELM))
		local c2 = Q.Compile("gear & ilvl>280 & boe")
		assert.equal(true, Q.Eval(c2, RING))
	end)
end)

describe("Query errors, Validate, Pretty, registry", function()
	local Q
	before_each(function()
		Q = Loader.New(FILES).Query
		registerTestKeywords(Q)
	end)

	it("formats positioned error messages", function()
		assert.equal("Expected a value after \"&\" at character 6", Q.FormatError(Q.Compile("boe &").errors[1]))
		assert.equal("Expected a number after \">\" at character 6", Q.FormatError(Q.Compile("ilvl>").errors[1]))
		assert.equal("Expected a closing ) after \"boe\" at character 5", Q.FormatError(Q.Compile("(boe").errors[1]))
		assert.equal("Expected & or | but found \")\" at character 4", Q.FormatError(Q.Compile("boe)").errors[1]))
		assert.equal("Expected a known keyword but found \"potin\" at character 1", Q.FormatError(Q.Compile("#potin").errors[1]))
	end)

	it("Validate accepts a good query and warns about name-text words", function()
		local report = Q.Validate(Q.Compile("(potin | boe) & !ilvl>3"))
		assert.equal(true, report.ok)
		assert.same({}, report.problems)
		assert.same({ { kind = "text", value = "potin", position = 2 } }, report.warnings)
	end)

	it("Validate reports compile errors as problems", function()
		local report = Q.Validate(Q.Compile("boe & & potion"))
		assert.equal(false, report.ok)
		assert.equal("error", report.problems[1].kind)
		assert.equal(7, report.problems[1].position)
	end)

	it("Pretty prints a canonical form", function()
		local function p(text) return Q.Pretty((Q.Compile(text)).ast) end
		assert.equal("a | b & c", p("a|b&c"))
		assert.equal("(a | b) & c", p("(a|b)&c"))
		assert.equal("!(a & b)", p("!(a&b)"))
		assert.equal("a & (b & c)", p("a&(b&c)"))
		assert.equal("#rune | \"x y\" | ilvl>=250", p("#rune|\"x y\"|ilvl >= 250"))
		assert.equal("!!healing potion", p("! ! healing   potion"))
	end)

	it("Pretty round-trips: parsing the pretty text gives the same tree", function()
		local function strip(node)
			if type(node) ~= "table" then return node end
			local out = {}
			for k, v in pairs(node) do
				if k ~= "s" and k ~= "e" then out[k] = strip(v) end
			end
			return out
		end
		local queries = {
			"gear & ilvl>280 & !bound", "(potion | flask | food) & lvl>=80", "keystone | crest",
			"junk | (gray & !quest)", "\"Healing Potion\"", "#rune", "a & (b | (c & !d)) | e",
			"!(a | b) & !c", "trade goods & count<=5 | tab=2",
		}
		for _, q in ipairs(queries) do
			local ast = Q.Compile(q).ast
			local again = Q.Compile(Q.Pretty(ast)).ast
			assert.same(strip(ast), strip(again), q)
		end
	end)

	it("Pretty round-trips quoted phrases with pattern characters and the depth limit", function()
		local function same(a, b)
			if type(a) ~= "table" then return a == b end
			for k, v in pairs(a) do
				if k ~= "s" and k ~= "e" and not same(v, b[k]) then return false end
			end
			for k in pairs(b) do
				if k ~= "s" and k ~= "e" and a[k] == nil then return false end
			end
			return true
		end
		local texts = { "\"[50%] (x) a-b\" | #potion", "\"\"", string.rep("!", 100) .. "a" }
		local nested = "a"
		for i = 1, 100 do nested = "(" .. nested .. (i % 2 == 0 and " & " or " | ") .. "b)" end
		texts[#texts + 1] = nested
		for _, q in ipairs(texts) do
			local ast = Q.Compile(q).ast
			assert.truthy(ast, q)
			local again = Q.Compile(Q.Pretty(ast))
			assert.same({}, again.errors, q)
			assert.truthy(same(ast, again.ast), q)
		end
		local tooDeep = Q.Compile(string.rep("!", 101) .. "a")
		assert.equal("SHALLOWER", tooDeep.errors[1].expected)
		assert.truthy(Q.FormatError(tooDeep.errors[1]))
		assert.truthy(Q.FormatError(Q.Compile("a b ilvl>5").errors[1]))
	end)

	it("RegisterKeyword rejects bad definitions", function()
		assert.has_error(function() Q.RegisterKeyword({ name = "x", eval = function() end }) end, "class")
		assert.has_error(function() Q.RegisterKeyword({ name = "x", class = "static" }) end, "eval or value")
		assert.has_error(function() Q.RegisterKeyword({ class = "static", eval = function() end }) end, "name")
	end)
end)
