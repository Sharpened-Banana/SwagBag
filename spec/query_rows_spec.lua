-- Week 11 (spec F6, AC6.1): a category's query as editable rows (Engine/Query/Rows.lua) and back to text,
-- losslessly. Every built-in query, a list of shapes, the shapes the rows cannot show, and a fuzz over random rows.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Query/Rows.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
	"SwagBag/Engine/CategoryDefaults.lua",
}

describe("Rule rows (week 11)", function()
	local SB, Q, Rows
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		Q, Rows = SB.Query, SB.QueryRows
	end)

	local function pretty(text)
		return Q.Pretty(Q.Compile(text).ast)
	end

	-- Mutation: in Rows.lua's asBlock, `return { join = node.type, ...` -> `return { join = "and", ...`.
	it("every built-in category query turns into rows and back into the same query", function()
		assert.truthy(#SB.CategoryDefaults >= 20)
		for _, def in ipairs(SB.CategoryDefaults) do
			local rules, why = Rows.FromText(def.query)
			assert.truthy(rules, def.id .. " " .. tostring(why))
			assert.equal(def.query == "" and "" or pretty(def.query), Rows.ToText(rules), def.id)
			assert.same(rules, Rows.FromText(Rows.ToText(rules)), def.id)
		end
		assert.same({ join = "and", blocks = { { join = "or", negate = false, rows = {
			{ kind = "word", value = "keystone", negate = false }, { kind = "word", value = "crest", negate = false } } } } },
			Rows.FromText("keystone | crest"))
	end)

	-- Mutations: in Rows.lua's blockText, `return "!(" .. s .. ")"` -> `return "!" .. s`; or in asRow,
	-- `return { kind = t, value = node.value, negate = negate }` -> `... negate = false }` (a "!" row loses its "!").
	it("rows -> text -> rows is lossless for every shape the rows can show", function()
		local shapes = {
			"boe", "!boe", "gear & ilvl>=600", "potion | flask | food", "(potion | flask) & !junk", "a & b | c",
			"!(a & b) | c", "#trade goods", "\"healing potion\" | lure", "<536", ">150", "=480", "536", "400-450",
			"gear & 400-450", "ilvl>5 & !ilvl>600", "(a | b) | c", "(a & b) & c", "~boe || bop", "!\"x y\" & #rune",
			"gear & (ilvl>=400 | uncollected) & !bound", "epic & boe | rare & boe | !(junk | trash)", "value>=100.5",
			"gray", "fish | lure | bait",
		}
		for _, text in ipairs(shapes) do
			local rules, why = Rows.FromText(text)
			assert.truthy(rules, text .. " " .. tostring(why))
			local back = Rows.ToText(rules)
			assert.equal(pretty(text), back, text)
			assert.same(rules, Rows.FromText(back), text)
		end
		local r = Rows.FromText("(potion | flask) & !(junk & poor) & ilvl>5")
		assert.equal("and", r.join)
		assert.same({ "or", "and", "and" }, { r.blocks[1].join, r.blocks[2].join, r.blocks[3].join })
		assert.same({ false, true, false }, { r.blocks[1].negate, r.blocks[2].negate, r.blocks[3].negate })
		assert.same({ kind = "num", name = "ilvl", op = ">", raw = "5", negate = false }, r.blocks[3].rows[1])
		assert.same({ join = "and", blocks = {} }, Rows.FromText("  "))
		assert.equal("", Rows.ToText({ join = "or", blocks = { { join = "and", negate = false, rows = {} } } }))
	end)

	-- Mutation: in Rows.FromText, drop the `if n > Rows.MAX_ROWS or ...` check (a 41-row query opens as rows).
	it("queries the rows can't show open as text only, and say why", function()
		assert.same({ nil, "deep" }, { Rows.FromText("a & (b | (c & d))") })
		assert.same({ nil, "deep" }, { Rows.FromText("!!boe") })
		assert.same({ nil, "deep" }, { Rows.FromText("!(a | !(b & c))") })
		local rows40, rows41 = {}, {}
		for i = 1, 41 do
			rows41[i] = "w" .. i
			if i <= 40 then
				rows40[i] = "w" .. i
			end
		end
		assert.truthy(Rows.FromText(table.concat(rows40, " | ")))
		assert.same({ nil, "long" }, { Rows.FromText(table.concat(rows41, " | ")) })
		local groups = {}
		for i = 1, 11 do
			groups[i] = "(a" .. i .. " & b)"
		end
		assert.same({ nil, "long" }, { Rows.FromText(table.concat(groups, " | ")) })
		assert.same({ nil, "toolong" }, { Rows.FromText(string.rep("a", Rows.MAX_TEXT + 1)) })
		local none, why, err = Rows.FromText("boe &")
		assert.is_nil(none)
		assert.equal("error", why)
		assert.equal("VALUE", err.expected)
	end)

	-- Mutation: in Rows.lua's blockText, `if inside and (inside == b.join or b.join == "or") then` ->
	-- `if inside and inside == b.join then` (precedence changes which items match).
	it("fuzz: 400 random rule sets print as text that reads back the same and matches the same items", function()
		Fixtures.SmallBags(SB.Adapter)
		SB.Adapter.Put(0, 7, Fixtures.HERB, 40)
		SB.Adapter.Put(0, 8, Fixtures.UNLOADED, 1)
		SB.Adapter.Put(0, 9, Fixtures.TOY, 1)
		local records = {}
		for slot = 1, 9 do
			records[#records + 1] = SB.Items.Describe(0, slot)
		end
		local seed = 4242
		local function rnd(n)
			seed = seed * 16807 % 2147483647
			return seed % n + 1
		end
		local flags, numbers = {}, {}
		for _, fam in ipairs(Rows.FAMILIES) do
			for _, w in ipairs(fam.words) do
				if fam.numbers then
					numbers[#numbers + 1] = w
				else
					flags[#flags + 1] = w
				end
			end
		end
		local names = { "potion", "Healing", "of the", "tooth", "x y" }
		local function row()
			local k = rnd(5)
			local r
			if k == 1 then
				r = Rows.NewRow(names[rnd(#names)])
			elseif k == 2 then
				r = Rows.NewRow(nil)
				r.value = names[rnd(#names)]
			elseif k == 3 then
				r = { kind = "exact", value = flags[rnd(#flags)], negate = false }
			elseif k == 4 then
				r = Rows.NewRow(numbers[rnd(#numbers)], true)
				r.op, r.raw = Rows.NUMBER_OPS[rnd(5)], tostring(rnd(400))
			else
				r = Rows.NewRow(flags[rnd(#flags)])
			end
			r.negate = rnd(3) == 1
			return r
		end
		local function kleene(join, values, n)
			local out = join == "and"
			for i = 1, n do -- not ipairs: an unknown (nil) answer is a value here
				local v = values[i]
				if v == (join ~= "and") then
					return v
				elseif v == nil then
					out = nil
				end
			end
			return out
		end
		local function no(v, negate)
			if v == nil or not negate then
				return v
			end
			return not v
		end
		-- The reference: each row's own query, joined here, independent of ToText's parentheses.
		local function expect(rules, rec)
			local blocks = {}
			for i, b in ipairs(rules.blocks) do
				local vals = {}
				for j, r in ipairs(b.rows) do
					local single = Rows.ToText({ join = "and", blocks = { { join = "and", negate = false,
						rows = { { kind = r.kind, value = r.value, name = r.name, op = r.op, raw = r.raw, negate = false } } } } })
					local v = Q.Eval(Q.Compile(single), rec)
					vals[j] = no(v, r.negate)
				end
				local v = kleene(b.join, vals, #b.rows)
				blocks[i] = no(v, b.negate)
			end
			return kleene(rules.join, blocks, #rules.blocks)
		end
		local shown = 0
		for _ = 1, 400 do
			local rules = { join = rnd(2) == 1 and "and" or "or", blocks = {} }
			for i = 1, rnd(3) do
				local b = { join = rnd(2) == 1 and "and" or "or", negate = rnd(4) == 1, rows = {} }
				for j = 1, rnd(3) do
					b.rows[j] = row()
				end
				rules.blocks[i] = b
			end
			local text = Rows.ToText(rules)
			local again, why = Rows.FromText(text)
			assert.truthy(again, text .. " " .. tostring(why))
			assert.equal(text, Rows.ToText(again), text)
			assert.same(again, Rows.FromText(Rows.ToText(again)), text)
			local compiled = Q.Compile(text)
			assert.truthy(compiled.fn, text)
			for _, rec in ipairs(records) do
				local want = expect(rules, rec)
				assert.equal(want, Q.Eval(compiled, rec), text .. " on " .. tostring(rec.name))
				if want then
					shown = shown + 1
				end
			end
		end
		assert.truthy(shown > 300, "too few matches to mean anything: " .. shown)
	end)

	-- Mutation: in Rows.FAMILIES, drop "tab" from the numbers family.
	it("the keyword lists name every registered keyword once, each where it can be used", function()
		local listed, seen = {}, {}
		for _, fam in ipairs(Rows.FAMILIES) do
			assert.truthy(rawget(SB.L, fam.label), fam.label)
			for _, w in ipairs(fam.words) do
				local key = w .. (fam.numbers and "#" or "")
				assert.falsy(seen[key], "listed twice: " .. w)
				seen[key] = true
				local kind = Rows.KindOf(w)
				assert.truthy(kind, "not a keyword: " .. w)
				if fam.numbers then
					assert.truthy(kind == "number" or kind == "both", w)
				else
					assert.truthy(kind == "flag" or kind == "both", w)
				end
				listed[w] = true
			end
		end
		for name, kw in pairs(Q.keywords) do
			if kw.name == name then
				assert.truthy(listed[name], "missing from the lists: " .. name)
			end
		end
		assert.is_nil(Rows.KindOf("fish"))
		assert.equal("both", Rows.KindOf("gear"))
		assert.equal("flag", Rows.KindOf("GRAY"))
	end)

	-- Mutation: in Rows.Problem, drop the `elseif v:find("\"", 1, true) then return "QUOTE"` branch.
	it("a new row, and what keeps a row from being saved", function()
		assert.same({ kind = "word", value = "boe", negate = false }, Rows.NewRow("boe"))
		assert.same({ kind = "num", name = "ilvl", op = ">=", raw = "", negate = false }, Rows.NewRow("ilvl", true))
		assert.same({ kind = "text", value = "", negate = false }, Rows.NewRow(nil))
		assert.equal("NUMBER", Rows.Problem(Rows.NewRow("ilvl", true)))
		assert.is_nil(Rows.Problem({ kind = "num", name = "ilvl", op = ">=", raw = "600" }))
		assert.is_nil(Rows.Problem({ kind = "num", name = "value", op = ">", raw = "2.5" }))
		assert.equal("NUMBER", Rows.Problem({ kind = "num", name = "ilvl", op = ">=", raw = "6x" }))
		assert.equal("EMPTY", Rows.Problem(Rows.NewRow(nil)))
		assert.equal("QUOTE", Rows.Problem({ kind = "text", value = "say \"hi\"" }))
		assert.is_nil(Rows.Problem({ kind = "text", value = "Metal & Stone (rare)" }))
		assert.equal("WORD", Rows.Problem({ kind = "word", value = "a&b" }))
		assert.equal("WORD", Rows.Problem({ kind = "word", value = "536" }))
		assert.equal("WORD", Rows.Problem({ kind = "word", value = "a  b" }))
		assert.is_nil(Rows.Problem({ kind = "word", value = "trade goods" }))
	end)
end)
