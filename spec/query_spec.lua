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

	it("#word forces a keyword; an unknown #word is a warning that matches nothing (spec 7.5 #3)", function()
		assert.equal(true, run("#potion", POTION))
		local c = Q.Compile("boe | #potin")
		assert.truthy(c.fn)
		assert.same({}, c.errors)
		assert.same({ { kind = "unknown_keyword", value = "potin", position = 7 } }, c.warnings)
		assert.equal(false, Q.Eval(c, POTION))
		assert.equal(true, Q.Eval(c, RING))
		assert.equal("Unknown keyword \"#potin\" matches nothing (character 7)", Q.FormatWarning(c.warnings[1]))
		assert.same(c.warnings, Q.Validate(c).warnings)
	end)

	it("bare item levels compare like Syndicator: < and > include the number, N-M is inclusive", function()
		assert.equal(true, run("<285", RING))
		assert.equal(true, run(">285", RING))
		assert.equal(false, run("<284", RING))
		assert.equal(true, run("285", RING))
		assert.equal(true, run("280-290", RING))
		assert.equal(true, run("285-285", RING))
		assert.equal(false, run("290-300", RING))
		assert.equal(false, run("<300", POTION), "no item level: false")
		assert.is_nil(run("<300", LOADING), "not loaded yet: nil")
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

	it("AND, OR and NOT give the full tri-state truth tables", function()
		Q.RegisterKeyword({ name = "tt", class = "static", eval = function() return true end })
		Q.RegisterKeyword({ name = "ff", class = "static", eval = function() return false end })
		Q.RegisterKeyword({ name = "uu", class = "static", eval = function() return nil end })
		local vals = { tt = true, ff = false, uu = "nil" }
		local names = { "tt", "ff", "uu" }
		local function andOf(a, b)
			if a == false or b == false then return false end
			if a == true and b == true then return true end
			return "nil"
		end
		local function orOf(a, b)
			if a == true or b == true then return true end
			if a == false and b == false then return false end
			return "nil"
		end
		local function got(text)
			local v = run(text, POTION)
			if v == nil then return "nil" end
			return v
		end
		for _, x in ipairs(names) do
			for _, y in ipairs(names) do
				assert.equal(andOf(vals[x], vals[y]), got(x .. " & " .. y), x .. " & " .. y)
				assert.equal(orOf(vals[x], vals[y]), got(x .. " | " .. y), x .. " | " .. y)
			end
		end
		assert.equal(false, got("!tt"))
		assert.equal(true, got("!ff"))
		assert.equal("nil", got("!uu"))
	end)

	it("normalises keyword results to strict booleans", function()
		Q.RegisterKeyword({ name = "sloppy", class = "static", eval = function() return 1 end })
		Q.RegisterKeyword({ name = "sloppyval", class = "static", value = function() return 5 end })
		assert.equal(true, run("sloppy", POTION))
		assert.equal(false, run("!sloppy", POTION))
	end)

	it("propagates errors thrown by a keyword eval instead of hiding them", function()
		Q.RegisterKeyword({ name = "boom", class = "static", eval = function() error("kaboom", 0) end })
		assert.has_error(function() run("boom", POTION) end, "kaboom")
	end)

	it("an empty quoted string matches every item with a name", function()
		assert.equal(true, run("\"\"", POTION))
		assert.equal(true, run("\"\"", RING))
		assert.is_nil(run("\"\"", LOADING))
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

	-- 0.16.0: bonus=N. Mutation: compare only the first number of a list.
	it("a value may be a list of numbers: a comparison is true when any of them passes", function()
		Q.RegisterKeyword({ name = "bonus", class = "instance", value = function(r) return r.bonus or false end })
		local r = { name = "x", bonus = { 10, 1540, 6652 } }
		assert.equal(true, run("bonus=6652", r))
		assert.equal(true, run("bonus<11", r))
		assert.equal(false, run("bonus=1", r))
		assert.equal(false, run("bonus=1", { name = "y" }))
	end)

	it("text: is an instance-class tooltip search that says so", function()
		local c = Q.Compile("potion & text:fire")
		assert.same({}, c.errors)
		assert.equal("instance", c.cacheClass)
		assert.equal(true, c.tooltip)
		assert.falsy(Q.Compile("potion").tooltip)
		assert.equal(false, Q.Eval(Q.Compile("text:fire"), POTION), "no ItemFacts loaded: no tooltip to read")
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
		assert.equal("Expected a known keyword but found \"&\" at character 3", Q.FormatError(Q.Compile("# & boe").errors[1]))
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
		assert.equal("text:\"fire damage\" & !text:\"x\"", p("tip:fire damage & !TEXT:x"))
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
			"!(a | b) & !c", "trade goods & count<=5 | tab=2", "#gear & <536", "400-450 | ~boe", "a || b",
			"text:fire & !tip:\"deals 50\"", "tip:fire damage | text: frost",
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
		assert.equal("Expected fewer nested (, ! and ~ (at most 100 levels) but found \"!\" at character 101",
			Q.FormatError(tooDeep.errors[1]))
		assert.equal("Put & between a name and a comparison (at character 1)",
			Q.FormatError(Q.Compile("a b ilvl>5").errors[1]))
	end)

	it("Compile and Eval never throw on the new syntax, and ~ obeys the depth limit", function()
		local pieces = { "||", "|", "&", "~", "!", "(", ")", "\"", "<", "<=", ">", ">=", "=", "#", "1", "285", "99999999999999999999", "5-9",
			"9-5", "-", "0x10", "a", "boe", "gear", "potion", "ilvl", "a b", "Ara-Kara", "1-2-3", "x", " " }
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
		local seed = 777
		local function rnd(n)
			seed = seed * 16807 % 2147483647 -- Park-Miller, exact in doubles
			return seed % n + 1
		end
		local distinct, nDistinct, parsed = {}, 0, 0
		for _ = 1, 2000 do
			local parts = {}
			for i = 1, rnd(8) do
				parts[i] = pieces[rnd(#pieces)]
			end
			local text = table.concat(parts, rnd(2) == 1 and " " or "")
			if not distinct[text] then
				distinct[text] = true
				nDistinct = nDistinct + 1
			end
			local ok, c = pcall(Q.Compile, text)
			assert.truthy(ok, text)
			for _, rec in ipairs({ RING, POTION, LOADING }) do
				local okEval, v = pcall(Q.Eval, c, rec)
				assert.truthy(okEval, text)
				assert.truthy(v == true or v == false or v == nil, text)
			end
			assert.truthy(pcall(Q.Validate, c), text)
			if c.ast then
				parsed = parsed + 1
				local again = Q.Compile(Q.Pretty(c.ast))
				assert.truthy(again.ast and same(c.ast, again.ast), text)
			else
				local e = c.errors[1]
				assert.truthy(e and e.position >= 1 and e.position <= #text + 1, text)
			end
		end
		assert.truthy(nDistinct > 1000, "generator is degenerate: " .. nDistinct)
		assert.truthy(parsed > 200, "too few parseable inputs: " .. parsed)
		local deep = Q.Compile(string.rep("~", 101) .. "a")
		assert.is_nil(deep.fn)
		assert.equal("SHALLOWER", deep.errors[1].expected)
		assert.truthy(Q.Compile(string.rep("~", 100) .. "boe").fn)
	end)

	it("RegisterKeyword rejects bad definitions", function()
		assert.has_error(function() Q.RegisterKeyword({ name = "x", eval = function() end }) end, "class")
		assert.has_error(function() Q.RegisterKeyword({ name = "x", class = "static" }) end, "eval or value")
		assert.has_error(function() Q.RegisterKeyword({ class = "static", eval = function() end }) end, "name")
	end)
end)

-- 0.13.6 (the user: "trinket finds trinkets, trink does not"): a search box passes { prefix = true }, and a bare
-- word of 3+ characters then also matches any keyword or alias that starts with it. Rules never pass it.
describe("Query compile with opts.prefix (0.13.6)", function()
	local Q
	local P = { prefix = true }
	local TRINKET = { kind = "gear", name = "Charm of X", equipLoc = "INVTYPE_TRINKET" }
	local WRIST = { kind = "gear", name = "Cuffs", equipLoc = "INVTYPE_WRIST" }
	local FINGER = { kind = "gear", name = "Band of the Fallen", equipLoc = "INVTYPE_FINGER" }
	before_each(function()
		Q = Loader.New(FILES).Query
		registerTestKeywords(Q)
		local function slot(name, loc, aliases)
			Q.RegisterKeyword({ name = name, aliases = aliases, class = "static",
				eval = function(r) return r.equipLoc == loc end })
		end
		slot("trinket", "INVTYPE_TRINKET")
		slot("wrist", "INVTYPE_WRIST", { "bracers" })
		slot("finger", "INVTYPE_FINGER")
		slot("fingerless", "INVTYPE_FINGERLESS")
	end)

	local function match(text, record, opts)
		return Q.Eval(Q.Compile(text, opts), record)
	end

	-- Mutation: the prefix branch is not added (the word stays a name match only).
	-- 0.16.0 (Q4): a keyword that reads tooltips never joins the expansion. Mutation: drop the tooltip check.
	it("tooltip keywords are never reached by a typed word's expansion", function()
		Q.RegisterKeyword({ name = "fire damage", class = "instance", tooltip = true, eval = function() return true end })
		local c = Q.Compile("fire", { prefix = true })
		assert.same({}, c.keywords)
		assert.equal(true, Q.Eval(Q.Compile("fire damage", { prefix = true }), {}))
	end)

	it("trink and trinke find the trinket by keyword and not the ring", function()
		assert.equal(true, match("trink", TRINKET, P))
		assert.equal(true, match("trinke", TRINKET, P))
		assert.equal(false, match("trink", FINGER, P))
	end)

	-- Mutation: PREFIX_MIN is 4, or the length test is > instead of >=.
	it("three characters are enough; two match the name only", function()
		assert.equal(3, Q.PREFIX_MIN)
		assert.equal(true, match("tri", TRINKET, P))
		assert.equal(false, match("tr", { equipLoc = "INVTYPE_TRINKET", name = "Charm" }, P))
	end)

	-- Mutation: an exact keyword is widened too (fingerless would light up with "finger").
	it("an exact keyword behaves exactly as without the option", function()
		assert.equal(true, match("trinket", TRINKET, P))
		local plain, withPrefix = Q.Compile("finger"), Q.Compile("finger", P)
		assert.same(plain.keywords, withPrefix.keywords)
		assert.same({ "finger" }, withPrefix.keywords)
		assert.equal(true, Q.Eval(withPrefix, { equipLoc = "INVTYPE_FINGER" }))
		assert.equal(false, Q.Eval(withPrefix, { equipLoc = "INVTYPE_FINGERLESS" }))
	end)

	-- Mutation: the prefix branch replaces the name match instead of adding to it.
	it("a prefix still matches names", function()
		assert.equal(true, match("ban", FINGER, P))
		assert.equal(true, match("cha", TRINKET, P), "Charm of X by name")
		assert.equal(false, match("ban", TRINKET, P))
	end)

	-- Mutation: only keyword names are scanned, aliases are not.
	it("an alias prefix matches: brac finds wrist items through bracers", function()
		assert.equal(true, match("brac", WRIST, P))
		assert.equal(false, match("brac", FINGER, P))
	end)

	-- Mutation: only the first matching keyword is used (or the same entry is counted twice).
	it("keywords sharing a prefix: either one matches, and an entry named twice is used once", function()
		local c = Q.Compile("fing", P)
		assert.equal(true, Q.Eval(c, FINGER))
		assert.equal(true, Q.Eval(c, { equipLoc = "INVTYPE_FINGERLESS", name = "Glove" }))
		assert.equal(false, Q.Eval(c, TRINKET))
		table.sort(c.keywords)
		assert.same({ "finger", "fingerless" }, c.keywords)
		local w = Q.Compile("wri", P)
		assert.same({ "wrist" }, w.keywords)
		assert.same({ "wrist" }, Q.Compile("brac", P).keywords)
	end)

	-- Mutation: combine with AND semantics, or turn nil into false.
	it("nil: an unknown keyword with false name results gives nil; a true name still wins", function()
		assert.is_nil(match("myst", HELM, P))
		assert.is_nil(match("myst", LOADING, P), "name not loaded either")
		assert.equal(true, match("myst", { name = "Mystic Robe" }, P))
		assert.equal(false, match("trink", HELM, P))
	end)

	-- Mutation: cacheClass is taken from the last (or first) matched keyword instead of the highest.
	it("cacheClass is the highest class among the matched keywords; value-only keywords are not matched", function()
		Q.RegisterKeyword({ name = "zed1", class = "static", eval = function() return false end })
		Q.RegisterKeyword({ name = "zed2", class = "volatile", eval = function() return false end })
		Q.RegisterKeyword({ name = "zed3", class = "instance", eval = function() return false end })
		Q.RegisterKeyword({ name = "zedvalue", class = "volatile", value = function() return 1 end })
		local c = Q.Compile("zed", P)
		assert.equal("volatile", c.cacheClass)
		assert.same({ "zed1", "zed2", "zed3" }, (function() table.sort(c.keywords) return c.keywords end)())
		assert.equal("static", Q.Compile("zed1", P).cacheClass)
		assert.equal("static", Q.Compile("zed", {}).cacheClass)
	end)

	-- Mutation: Compile always widens (the option is ignored).
	it("without the option trink matches by name only", function()
		assert.equal(false, match("trink", TRINKET))
		assert.equal(false, match("trink", TRINKET, {}))
		assert.same({}, Q.Compile("trink").keywords)
		assert.equal(true, match("trink", { name = "Trinket Box" }))
	end)

	-- Mutation: exact and quoted nodes get the prefix branch too.
	it("#word, quoted text and numeric terms are unchanged", function()
		local c = Q.Compile("#trink", P)
		assert.equal(false, Q.Eval(c, TRINKET))
		assert.equal("unknown_keyword", c.warnings[1].kind)
		assert.equal(false, match("\"trink\"", TRINKET, P))
		assert.equal(true, match("\"trink\"", { name = "Trinket Box" }, P))
		assert.equal(true, match("ilvl>250", RING, P))
		assert.is_nil(Q.Compile("ilv>250", P).fn, "a numeric keyword is not completed")
	end)

	-- Mutation: orMatcher tests `v == true` (a truthy non-boolean eval then counts as false, unlike a plain keyword).
	it("a keyword eval returning a truthy non-boolean is a match, as build normalises it", function()
		Q.RegisterKeyword({ name = "sloppy", class = "static", eval = function() return 1 end })
		assert.equal(true, Q.Eval(Q.Compile("sloppy"), HELM))
		assert.equal(true, Q.Eval(Q.Compile("slop", P), HELM))
	end)

	-- Mutation: the keyword table is scanned per record (emptying it after Compile would change the result).
	it("the keyword scan happens at compile time, not per record", function()
		local c = Q.Compile("trink", P)
		Q.keywords = {}
		assert.equal(true, Q.Eval(c, TRINKET))
		assert.equal(false, Q.Eval(c, FINGER))
	end)
end)
