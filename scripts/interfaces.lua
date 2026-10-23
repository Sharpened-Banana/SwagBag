-- Maps the TOC's "## Interface:" numbers to a client type and a version name (pure Lua 5.1).
--   dofile("scripts/interfaces.lua") returns M (toc_check.lua and the specs).
--   luajit scripts/interfaces.lua "120100, 16001" prints one "<type> <name>" line per number and exits 1
--   on an unknown one (scripts/release.sh).
-- Retail numbers have six digits (120105); WoW Forever numbers are 16000-16999 (the packager's 16???).
local M = {}

function M.Parse(list)
	local out = {}
	for part in tostring(list or ""):gmatch("[^,]+") do
		local digits = part:gsub("%s", "")
		local n = digits:match("^%d+$") and tonumber(digits)
		if n then
			local kind = "unknown"
			if n >= 16000 and n <= 16999 then
				kind = "forever"
			elseif n >= 100000 then
				kind = "retail"
			end
			out[#out + 1] = {
				iface = n,
				name = ("%d.%d.%d"):format(math.floor(n / 10000), math.floor(n / 100) % 100, n % 100),
				type = kind,
			}
		elseif digits ~= "" then
			out[#out + 1] = { iface = digits, name = digits, type = "unknown" } -- not a number: reported, never dropped
		end
	end
	return out
end

function M.Lines(list)
	local lines, ok = {}, true
	for _, e in ipairs(M.Parse(list)) do
		lines[#lines + 1] = e.type .. " " .. e.name
		if e.type == "unknown" then
			ok = false
		end
	end
	return lines, ok
end

-- Command line: only when a script argument was given to THIS chunk. A dofile from toc_check or the spec runner
-- passes none (and the global `arg` there holds other files), so it never reads `arg`.
if select("#", ...) > 0 then
	local lines, ok = M.Lines((...))
	for _, l in ipairs(lines) do
		print(l)
	end
	if not ok then
		io.stderr:write("unknown Interface number in: " .. tostring((...)) .. "\n")
		os.exit(1)
	end
	os.exit(0)
end

return M
