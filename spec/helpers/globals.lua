-- Fake _G builders for tests that run Checks.
local Globals = {}

-- A fake _G in which every path in Adapter.CHECKS resolves (exact values where given).
function Globals.AllPresent(A)
	local g = {}
	for _, c in ipairs(A.CHECKS) do
		local t = g
		local parts = {}
		for p in c.path:gmatch("[^%.]+") do
			parts[#parts + 1] = p
		end
		for i = 1, #parts - 1 do
			if type(t[parts[i]]) ~= "table" then
				t[parts[i]] = {}
			end
			t = t[parts[i]]
		end
		local leaf = parts[#parts]
		if c.value ~= nil then
			t[leaf] = c.value
		elseif t[leaf] == nil then
			t[leaf] = {}
		end
	end
	return g
end

return Globals
