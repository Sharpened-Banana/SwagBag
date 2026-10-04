-- Week 11 (spec F6, AC6.3): a Baganator (Syndicator) search pasted in, read into SwagBag's query language by
-- Engine/Query/Paste.lua: passed through, translated, noted, or refused whole with the reason. Never run.
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Query/Paste.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
}

describe("Paste a Baganator search (week 11)", function()
	local SB, P
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		P = SB.QueryPaste
	end)

	-- The notes as "KIND" or "KIND=value", in order.
	local function kinds(result)
		local out = {}
		for i, n in ipairs(result.notes) do
			out[i] = n.kind .. (n.value and ("=" .. n.value) or "")
		end
		return out
	end

	-- Mutation: in Paste.Translate, `addNote(notes, seen, "ILVL")` -> `addNote(notes, seen, "GOLD")`.
	it("what both languages share passes through as it was pasted", function()
		for _, text in ipairs({ "#boe | #bwe", "(potion|flask)&!junk", "herb|cloth", "#tradeable loot | #tradable loot" }) do
			local r = P.Translate(text)
			assert.equal(text, r.query)
			assert.same({}, r.notes, text)
		end
		local r = P.Translate("  #gear & <536\n")
		assert.equal("#gear & <536", r.query)
		assert.same({ "ILVL" }, kinds(r))
		assert.same({ "ILVL" }, kinds(P.Translate("110-140")))
		assert.same({ "DIFFERENT=bop" }, kinds(P.Translate("~boe || bop")))
	end)

	-- Mutation: in Paste.lua, `local INCLUSIVE = { ["<"] = "<=", [">"] = ">=", ...` -> `{ ["<"] = "<", [">"] = ">", ...`.
	it("gold terms become value comparisons, < and > including the amount as in Baganator", function()
		local cases = {
			{ ">100g", "value>=100" }, { "<50s", "value<=0.5" }, { "=5c", "value=0.0005" }, { "25g", "value=25" },
			{ "10g-5g", "(value>=5 & value<=10)" }, { "#tradegoods & >10g", "#tradegoods & value>=10" },
			{ "!>5g", "!value>=5" }, { "(5s-1g | boe)", "((value>=0.05 & value<=1) | boe)" },
		}
		for _, c in ipairs(cases) do
			local r = P.Translate(c[1])
			assert.equal(c[2], r.query, c[1])
			assert.same({ "GOLD" }, kinds(r), c[1])
			assert.truthy(SB.Query.Compile(r.query).fn, c[1])
		end
		assert.same({ "5g potion", { "NAME=5g potion" } }, { P.Translate("5g potion").query, kinds(P.Translate("5g potion")) })
	end)

	-- Mutation: in Paste.Translate, `out = out .. string.rep(")", depth)` -> `out = out` (an open ( is refused).
	it("!! and ~~ are one Not and a ( left open at the end is closed, as Baganator reads them", function()
		assert.same({ "!boe", { "NOTS" } }, { P.Translate("!!boe").query, kinds(P.Translate("!!boe")) })
		assert.equal("!boe", P.Translate("~~~boe").query)
		assert.same({ "(boe | wue)", { "PARENS" } }, { P.Translate("(boe | wue").query, kinds(P.Translate("(boe | wue")) })
		assert.equal("((gear & epic))", P.Translate("((gear & epic").query)
	end)

	-- Mutations: in Paste.Translate, `err.position = math.min(original(edits, err.position), #text + 1)` ->
	-- `err.position = err.position` (the position is in SwagBag's text, not in what was pasted); or drop
	-- `elseif escapeCode(text) then return nil, "CODE"` (a link is let through).
	it("refused whole, with the reason and where: quotes, chat codes, too long, empty, what SwagBag can't read", function()
		assert.same({ nil, "QUOTE", 7 }, { P.Translate("potion\"s") })
		assert.same({ nil, "CODE" }, { P.Translate("|cffff0000red|r") })
		assert.same({ nil, "CODE" }, { P.Translate("|Hitem:1|h") })
		assert.same({ nil, "LONG", 501 }, { P.Translate(string.rep("a", 501)) })
		assert.same({ nil, "EMPTY" }, { P.Translate(" \n\t ") })
		assert.same({ nil, "EMPTY" }, { P.Translate(nil) })
		assert.same({ nil, "ERROR", "Expected & or | but found \")\" at character 4" }, { P.Translate("boe)") })
		assert.same({ nil, "ERROR", "Expected a value but found \"&\" at character 8" }, { P.Translate(">10g & & potion") })
		assert.same({ nil, "ERROR", "Put & between a name and a comparison (at character 1)" }, { P.Translate("a b >5") })
		assert.same({ nil, "ERROR", "Expected a value after \"|\" at character 6" }, { P.Translate("boe |") })
	end)

	-- Mutations: in Paste.Translate's walk, drop the `elseif node.type == "exact" and not (...) then addNote(..."UNKNOWN"...)`
	-- branch (an unknown #keyword is passed on with no word about it); or drop the `elseif node.type == "word" and
	-- #Paste.Prefixed(value) > 0 then ⏎ addNote(notes, seen, "ALSO", node.value)` branch (key no longer finds keystones,
	-- silently).
	it("every difference is named, never hidden: unknown #keywords, name words, other meanings, prefixes, item levels", function()
		local r = P.Translate("#elemental | pot | upgrade | <600 | #elemental | key | bag | #key")
		assert.same({ "UNKNOWN=elemental", "NAME=pot", "DIFFERENT=upgrade", "ILVL", "ALSO=key", "ALSO=bag" }, kinds(r))
		assert.same({ "potion" }, P.Prefixed("pot"))
		assert.same({ "keystone" }, P.Prefixed("key"), "a whole keyword is not its own prefix")
		assert.same({}, P.Prefixed("zzz"))
	end)

	-- Mutations: in Paste.Translate, drop the last `if #out > Paste.MAX then return nil, "GROWN", #out end` (gold
	-- terms grow a string past what a category may hold); or `return nil, "GROWN", #out` -> `return nil, "LONG", #out`
	-- (the answer says 799 characters of a 299-character paste).
	it("nothing pasted is ever run, and whatever is pasted it never errors; a string it reads always compiles", function()
		local hostile = { "os.exit()", "loadstring('x')()", "]]..error()..[[", "%s%d%n", string.rep("(", 300) .. "a",
			"|Kq1|k", "|T123:0|t", "a" .. string.rep(" & a", 120), string.rep("5g|", 99) .. "5g" }
		local pieces = { "!", "~", "&", "|", "||", "(", ")", "<", ">", "=", "#", "5g", "1s-2g", "400-450", "536", "boe",
			"pot", "a b", "-", "g", " " }
		local seed = 99
		local function rnd(n)
			seed = seed * 16807 % 2147483647
			return seed % n + 1
		end
		for _ = 1, 1500 do
			local parts = {}
			for i = 1, rnd(7) do
				parts[i] = pieces[rnd(#pieces)]
			end
			hostile[#hostile + 1] = table.concat(parts, rnd(2) == 1 and " " or "")
		end
		local read = 0
		for _, text in ipairs(hostile) do
			local ok, r, why = pcall(P.Translate, text)
			assert.truthy(ok, text)
			if r then
				read = read + 1
				assert.truthy(SB.Query.Compile(r.query).fn, text)
				assert.truthy(#r.query <= P.MAX, text)
			else
				assert.truthy(why == "ERROR" or why == "LONG" or why == "GROWN" or why == "CODE" or why == "EMPTY", text)
			end
		end
		assert.truthy(read > 150, "too few readable strings: " .. read)
		assert.same({ nil, "GROWN", 799 }, { P.Translate(string.rep("5g|", 99) .. "5g") }, "299 pasted, 799 read")
	end)

	-- Mutation: in Paste.lua's amount(), `if digits and #digits <= 9 then` -> `if digits then` (a huge amount prints as
	-- 1e+12, which is no number SwagBag reads back).
	it("the published Baganator strings of the grammar research read as expected", function()
		local cases = {
			{ "#key", {} }, { "#tradeable loot | #tradable loot", {} }, { "#toy", {} }, { "#gear & <536", { "ILVL" } },
			{ "#gear&<80", { "ILVL" } }, { "#armor", {} }, { "#profession", {} }, { "#elemental", { "UNKNOWN=elemental" } },
			{ "#finishing reagents | #optional reagents | #crafting reagent | #reagent", { "UNKNOWN=finishing reagents",
				"UNKNOWN=optional reagents", "UNKNOWN=crafting reagent" } },
			{ "#food", {} }, { "!gear & (#leather | #leatherworking)", { "UNKNOWN=leatherworking" } },
			{ "#battle pet | #battle pets", {} }, { "#open", { "UNKNOWN=open" } }, { "#cooking | #fish ", { "UNKNOWN=fish" } },
			{ "#boe | #bwe", {} }, { "#consumable | #recipe | #gem | #weapon", {} },
			{ "#herb | #alchemy | #inscription", { "UNKNOWN=alchemy", "UNKNOWN=inscription" } },
			{ "soulbound", {} }, { "boa", {} }, { "boe", {} }, { "open", { "NAME=open" } }, { "#tradeskill | #reagent", {} },
			{ "#weapon | #off-hand", {} }, { "#tabard | #shirt", {} }, { "#quest | #junk | #trinket | #wue | #housing", {} },
			{ "hearthstone", { "NAME=hearthstone" } },
		}
		for _, c in ipairs(cases) do
			local r, why, detail = P.Translate(c[1])
			assert.truthy(r, c[1] .. " " .. tostring(why) .. " " .. tostring(detail))
			assert.same(c[2], kinds(r), c[1])
		end
		assert.same({ nil, "ERROR", "Expected a number but found \"1000000000000g\" at character 2" },
			{ P.Translate(">1000000000000g") })
	end)
end)
