-- Checks SwagBag/SwagBag.toc against the files on disk (spec 11.2).
-- Usage (from the repo root): luajit scripts/toc_check.lua
local I = dofile("scripts/interfaces.lua")
local FOREVER_READY = false -- Stage B sets this after the in-game checks
local TOC = "SwagBag/SwagBag.toc"
local REQUIRED = {
	"## Interface: 120100, 120105",
	"## SavedVariables: SwagBagDB",
	"## SavedVariablesPerCharacter: SwagBagCharDB",
	"## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster, Masque",
	"## X-License: All Rights Reserved",
}

local problems = {}
local function problem(msg)
	problems[#problems + 1] = msg
end

local toc = io.open(TOC, "r")
if not toc then
	print("TOC check FAILED: " .. TOC .. " not found")
	os.exit(1)
end
local headers, seen, count, version, interfaces = {}, {}, 0, nil, nil
for raw in toc:lines() do
	local line = raw:gsub("\r$", "")
	if line:match("^##") then
		headers[line] = true
		version = version or line:match("^## Version:%s*(%S+)")
		interfaces = interfaces or line:match("^## Interface:%s*(.-)%s*$")
	elseif line:match("%S") and not line:match("^#") then
		local path = line:match("^%s*(.-)%s*$")
		if seen[path] then
			problem("listed twice: " .. path)
		end
		seen[path] = true
		count = count + 1
		local f = io.open("SwagBag/" .. path, "r")
		if f then
			f:close()
		else
			problem("listed but missing: " .. path)
		end
	end
end
toc:close()

for _, h in ipairs(REQUIRED) do
	if not headers[h] then
		problem("missing header: " .. h)
	end
end

-- Every Interface number is Retail or WoW Forever; Forever stays out of the TOC until Stage B's checks pass.
local names = {}
for _, e in ipairs(I.Parse(interfaces)) do
	names[#names + 1] = e.name
	if e.type == "unknown" then
		problem(("## Interface %d is neither Retail nor WoW Forever"):format(e.iface))
	elseif e.type == "forever" and not FOREVER_READY then
		problem(("## Interface %d is WoW Forever, which waits for the Stage B in-game checks"):format(e.iface))
	end
end

-- One TOC only: a second one (SwagBag_Mainline.toc and the like) would change which file a client loads.
local tp = io.popen("find SwagBag -maxdepth 1 -name '*.toc' | sort")
for line in tp:lines() do
	if line ~= TOC then
		problem("second TOC file: " .. line)
	end
end
tp:close()

local init = io.open("SwagBag/Core/Init.lua", "r")
local codeVersion = init and init:read("*a"):match("SB%.VERSION = \"([^\"]+)\"")
if init then
	init:close()
end
if version ~= codeVersion then
	problem(("## Version %s does not match SB.VERSION %s"):format(tostring(version), tostring(codeVersion)))
end

local p = io.popen("cd SwagBag && find . -name '*.lua' | sort")
for line in p:lines() do
	local path = line:gsub("^%./", "")
	if not seen[path] then
		problem("not listed in the TOC: " .. path)
	end
end
p:close()

if #problems > 0 then
	for _, m in ipairs(problems) do
		print("TOC: " .. m)
	end
	print("TOC check FAILED")
	os.exit(1)
end
print(("TOC OK (%d files; %s)"):format(count, table.concat(names, ", ")))
