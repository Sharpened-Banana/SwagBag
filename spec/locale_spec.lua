local Loader = dofile("spec/helpers/loader.lua")

local function sourceFiles()
	local list = {}
	local p = io.popen("find SwagBag -name '*.lua' | sort")
	for line in p:lines() do
		list[#list + 1] = line
	end
	p:close()
	return list
end

describe("Locale", function()
	local SB
	before_each(function()
		SB = Loader.New()
	end)

	it("falls back to the key for a missing string", function()
		assert.equal("NOT_A_REAL_KEY", SB.L.NOT_A_REAL_KEY)
	end)

	it("defines every L.KEY and L[\"KEY\"] used anywhere in SwagBag/", function()
		local missing = {}
		for _, path in ipairs(sourceFiles()) do
			local f = assert(io.open(path, "r"))
			local text = f:read("*a")
			f:close()
			for key in text:gmatch("%f[%w_]L%.([%a_][%w_]*)") do
				if rawget(SB.L, key) == nil then
					missing[#missing + 1] = path .. ": " .. key
				end
			end
			for key in text:gmatch("%f[%w_]L%[\"([^\"]+)\"%]") do
				if rawget(SB.L, key) == nil then
					missing[#missing + 1] = path .. ": " .. key
				end
			end
		end
		assert.same({}, missing)
	end)

	it("defines the keys that are built dynamically", function()
		for _, reason in ipairs({ "MANUAL", "AUTO", "CHECK", "SCHEMA" }) do
			assert.truthy(rawget(SB.L, "SAFE_REASON_" .. reason), reason)
		end
		for _, code in ipairs({ "VALUE", "NUMBER", "RPAREN", "QUOTE", "KEYWORD", "NUMERIC", "OPERATOR" }) do
			assert.truthy(rawget(SB.L, "QUERY_EXPECT_" .. code), code)
		end
	end)
end)

-- Forever Stage A, Task 4: SM.Describe builds L["SAFE_REASON_" .. reason:upper()] for the reason "forever".
describe("Locale for WoW Forever", function()
	it("defines the Forever Safe Mode reason", function()
		local SB = Loader.New()
		assert.equal("WoW Forever", rawget(SB.L, "SAFE_REASON_FOREVER"))
	end)
end)
