-- luacheck: ignore 122
-- WoW runs Lua 5.1, whose string.format takes only a string or a number for %s (and %q). LuaJIT, which runs
-- these tests, also takes a boolean or nil and would hide that bug (ruling W4-18). spec/runner.lua
-- requires this once before any spec loads (require caches it), so every spec formats as strictly
-- as WoW does, the Adapter specs included (F1). Returns the real string.format.
local real = string.format
string.format = function(fmt, ...)
	if type(fmt) ~= "string" then
		return real(fmt, ...) -- a number or an error: the real format answers as it always did
	end
	local args, i = { ... }, 0
	-- A literal %% takes no argument and would shift the count; the flags are - + space # and 0.
	for spec in fmt:gsub("%%%%", ""):gmatch("%%[%-%+ #%d%.]*(%a)") do
		i = i + 1
		if (spec == "s" or spec == "q") and type(args[i]) ~= "string" and type(args[i]) ~= "number" then
			error("bad argument #" .. (i + 1) .. " to 'format' (string expected, got " .. type(args[i]) .. ")", 2)
		end
	end
	return real(fmt, ...)
end
return real
