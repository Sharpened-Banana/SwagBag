-- Builds a fresh SwagBag namespace for one test: WoW stubs, Init, Locale, the mock
-- Adapter (real Adapter.lua + fakes), then the requested module files in order.
-- Usage:  local SB = Loader.New({ "SwagBag/Core/SafeMode.lua", ... })
--         Loader.New(files, { flavor = "forever" }) puts the mock in WoW Forever mode before loading files
--         (UI files read flavor-dependent lists at load).
local Stub = dofile("spec/helpers/wow_stub.lua")
local Mock = dofile("spec/mock_adapter.lua")
require("spec.helpers.format51") -- %s as strict as WoW's Lua 5.1 (week 5); spec/runner.lua already did it, so this is a no-op

local Loader = { Stub = Stub }

function Loader.LoadFile(SB, path)
	local chunk, err = loadfile(path)
	if not chunk then
		error(err, 2)
	end
	chunk("SwagBag", SB)
end

function Loader.New(files, opts)
	Stub.Install()
	local SB = {}
	Loader.LoadFile(SB, "SwagBag/Core/Init.lua")
	Loader.LoadFile(SB, "SwagBag/Locale/enUS.lua")
	Mock.New(SB)
	if opts and opts.flavor == "forever" then
		Mock.Forever(SB.Adapter)
	end
	for _, path in ipairs(files or {}) do
		Loader.LoadFile(SB, path)
	end
	return SB
end

return Loader
