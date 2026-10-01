-- SwagBag test runner: a tiny, dependency-free stand-in for busted.
-- Usage (from the repo root):  luajit spec/runner.lua spec/a_spec.lua spec/b_spec.lua ...
-- Provides globals: describe, it, before_each, after_each, assert (callable table
-- with equal, same, truthy, falsy, is_nil, has_error).

local results = { passed = 0, failed = 0, failures = {} }
local blocks = {} -- stack of describe blocks: { name, before = {}, after = {} }
local currentFile = "?"

local function fullName(name)
	local parts = {}
	for i = 1, #blocks do
		parts[#parts + 1] = blocks[i].name
	end
	parts[#parts + 1] = name
	return table.concat(parts, " > ")
end

local function fail(name, err)
	results.failed = results.failed + 1
	results.failures[#results.failures + 1] = { file = currentFile, name = name, err = tostring(err) }
end

function describe(name, fn)
	blocks[#blocks + 1] = { name = name, before = {}, after = {} }
	local ok, err = pcall(fn)
	if not ok then
		fail(fullName("(describe body)"), err)
	end
	blocks[#blocks] = nil
end

function before_each(fn)
	local top = blocks[#blocks]
	top.before[#top.before + 1] = fn
end

function after_each(fn)
	local top = blocks[#blocks]
	top.after[#top.after + 1] = fn
end

function it(name, fn)
	local full = fullName(name)
	local ok, err = pcall(function()
		for i = 1, #blocks do
			for _, b in ipairs(blocks[i].before) do
				b()
			end
		end
		fn()
	end)
	for i = #blocks, 1, -1 do
		for _, a in ipairs(blocks[i].after) do
			local okA, errA = pcall(a)
			if ok and not okA then
				ok, err = false, errA
			end
		end
	end
	if ok then
		results.passed = results.passed + 1
	else
		fail(full, err)
	end
end

---------------------------------------------------------------------------
-- Assertions
---------------------------------------------------------------------------
local function show(v, depth)
	depth = depth or 0
	if type(v) == "string" then
		return string.format("%q", v)
	end
	if type(v) ~= "table" then
		return tostring(v)
	end
	if depth > 3 then
		return "{...}"
	end
	local keys = {}
	for k in pairs(v) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, k in ipairs(keys) do
		parts[#parts + 1] = tostring(k) .. "=" .. show(v[k], depth + 1)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function prefix(msg)
	return msg and (tostring(msg) .. ": ") or ""
end

local A = {}

function A.equal(expected, actual, msg)
	if expected ~= actual then
		error(prefix(msg) .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
	end
end

function A.same(expected, actual, msg)
	if not deepEqual(expected, actual) then
		error(prefix(msg) .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
	end
end

function A.truthy(v, msg)
	if not v then
		error(prefix(msg) .. "expected a truthy value, got " .. show(v), 2)
	end
end

function A.falsy(v, msg)
	if v then
		error(prefix(msg) .. "expected a falsy value, got " .. show(v), 2)
	end
end

function A.is_nil(v, msg)
	if v ~= nil then
		error(prefix(msg) .. "expected nil, got " .. show(v), 2)
	end
end

function A.has_error(fn, needle, msg)
	local ok, err = pcall(fn)
	if ok then
		error(prefix(msg) .. "expected an error, but the function returned normally", 2)
	end
	if needle and not tostring(err):find(needle, 1, true) then
		error(prefix(msg) .. "error " .. show(tostring(err)) .. " does not contain " .. show(needle), 2)
	end
end

assert = setmetatable(A, {
	__call = function(_, v, msg, ...)
		if not v then
			error(msg or "assertion failed!", 2)
		end
		return v, msg, ...
	end,
})

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------
if #arg == 0 then
	print("usage: luajit spec/runner.lua spec/*_spec.lua")
	os.exit(2)
end

for i = 1, #arg do
	currentFile = arg[i]
	local chunk, loadErr = loadfile(currentFile)
	if not chunk then
		fail("(load)", loadErr)
	else
		local ok, err = pcall(chunk)
		if not ok then
			fail("(file body)", err)
		end
	end
end

for _, f in ipairs(results.failures) do
	print("FAIL " .. f.file .. " :: " .. f.name)
	print("     " .. f.err)
end
print(string.format("%d passed, %d failed", results.passed, results.failed))
os.exit(results.failed == 0 and 0 or 1)
