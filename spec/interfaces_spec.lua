-- Forever Stage A, Task 5: the TOC Interface number -> client type mapping that release.sh and toc_check.lua share.
local I = dofile("scripts/interfaces.lua")

local function tocInterfaces()
	local f = assert(io.open("SwagBag/SwagBag.toc", "r"))
	local text = f:read("*a")
	f:close()
	return text:match("## Interface:%s*([^\r\n]+)")
end

describe("scripts/interfaces.lua", function()
	it("120105 is Retail 12.1.5 and 120100 is 12.1.0", function()
		local list = I.Parse("120100, 120105")
		assert.equal(2, #list)
		assert.equal("12.1.0", list[1].name)
		assert.equal("retail", list[1].type)
		assert.equal(120100, list[1].iface)
		assert.equal("12.1.5", list[2].name)
		assert.equal("retail", list[2].type)
	end)

	it("16001 is WoW Forever 1.60.1", function()
		local list = I.Parse("16001")
		assert.equal("1.60.1", list[1].name)
		assert.equal("forever", list[1].type)
	end)

	it("a five-digit number outside the packager's 16??? range is not Forever", function()
		assert.equal("unknown", I.Parse("20504")[1].type)
	end)

	it("16000 and 16999 are Forever; 17000 and 15999 are not", function()
		assert.equal("forever", I.Parse("16000")[1].type)
		assert.equal("forever", I.Parse("16999")[1].type)
		assert.equal("unknown", I.Parse("17000")[1].type)
		assert.equal("unknown", I.Parse("15999")[1].type)
	end)

	it("11509 (Classic Era) is unknown", function()
		local e = I.Parse("11509")[1]
		assert.equal("unknown", e.type)
		assert.equal("1.15.9", e.name)
	end)

	it("a list keeps its order and drops spaces and blanks", function()
		local list = I.Parse("120100, 120105,,16001 ")
		assert.equal(3, #list)
		assert.equal(120100, list[1].iface)
		assert.equal(120105, list[2].iface)
		assert.equal(16001, list[3].iface)
	end)

	it("Lines prints type and name, and says not ok on an unknown number", function()
		local lines, ok = I.Lines("120100,16001")
		assert.truthy(ok)
		assert.same({ "retail 12.1.0", "forever 1.60.1" }, lines)
		local lines2, ok2 = I.Lines("120105,11509")
		assert.falsy(ok2)
		assert.equal("unknown 1.15.9", lines2[2])
	end)

	-- Mutation: Parse skipping a token that is not all digits.
	it("a token that is not a number (12x0100) is reported as unknown, not dropped", function()
		local list = I.Parse("120100, 12x0100")
		assert.equal(2, #list)
		assert.equal("unknown", list[2].type)
		local lines, ok = I.Lines("120100,12x0100")
		assert.falsy(ok)
		assert.equal(2, #lines)
		assert.truthy(lines[2]:find("^unknown"), lines[2])
		local code = os.execute("luajit scripts/interfaces.lua '120100, 12x0100' >/dev/null 2>&1")
		assert.truthy(code ~= 0 and code ~= true, "the CLI exits 1")
	end)

	it("today's TOC Interface line is Retail only", function()
		local list = I.Parse(tocInterfaces())
		assert.truthy(#list >= 1)
		for _, e in ipairs(list) do
			assert.equal("retail", e.type)
		end
	end)

	it("there is no second TOC in SwagBag/", function()
		local found = {}
		local p = io.popen("find SwagBag -maxdepth 1 -name '*.toc' | sort")
		for line in p:lines() do
			found[#found + 1] = line
		end
		p:close()
		assert.same({ "SwagBag/SwagBag.toc" }, found)
	end)
end)
