-- Checks SwagBag/SwagBag.toc against the files on disk (spec 11.2).
-- Usage (from the repo root): luajit scripts/toc_check.lua
local TOC = "SwagBag/SwagBag.toc"
local REQUIRED = {
	"## Interface: 120100, 120105",
	"## SavedVariables: SwagBagDB",
	"## SavedVariablesPerCharacter: SwagBagCharDB",
	"## OptionalDeps: Auctionator, Syndicator, ElvUI",
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
local headers, seen, count, version = {}, {}, 0, nil
for raw in toc:lines() do
	local line = raw:gsub("\r$", "")
	if line:match("^##") then
		headers[line] = true
		version = version or line:match("^## Version:%s*(%S+)")
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
print(("TOC OK (%d files)"):format(count))
