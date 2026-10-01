-- SwagBag feature checks (spec 10.3). The list of paths lives in Adapter.CHECKS so
-- that no other file names a C_* API. A failed REQUIRED check turns on Safe Mode
-- for its window before anything is shown; optional checks only degrade features.
local _, SB = ...

local Checks = {}
SB.Checks = Checks

-- Returns an ordered list of { name, pass, detail, required, window }.
function Checks.Run()
	local A, L = SB.Adapter, SB.L
	local results = {}
	for i, c in ipairs(A.CHECKS) do
		local v = A.Resolve(c.path)
		local pass, detail
		if c.value ~= nil then
			pass = v == c.value
			detail = pass and tostring(v) or L.CHECK_EXPECTED:format(tostring(c.value), tostring(v))
		else
			pass = v ~= nil
			detail = pass and L.CHECK_PRESENT or L.CHECK_MISSING
		end
		results[i] = { name = c.path, pass = pass, detail = detail, required = c.required, window = c.window }
	end
	Checks.last = results
	return results
end

-- Failed results, optionally only required ones and/or one window.
function Checks.Failed(results, requiredOnly, window)
	local out = {}
	for _, r in ipairs(results or Checks.last or {}) do
		if not r.pass and (not requiredOnly or r.required) and (window == nil or r.window == window) then
			out[#out + 1] = r
		end
	end
	return out
end

-- Turn on Safe Mode for each window with a failed required check.
-- Returns the list of windows that were switched.
function Checks.Apply(results)
	local switched = {}
	for _, window in ipairs(SB.SafeMode.WINDOWS) do
		if #Checks.Failed(results, true, window) > 0 and SB.SafeMode.Enable(window, "check") then
			switched[#switched + 1] = window
		end
	end
	return switched
end

-- Chat lines for /swagbag check: one PASS/FAIL line per check, then a summary.
function Checks.Lines(results)
	local L = SB.L
	local lines, passed, failed, failedRequired = {}, 0, 0, 0
	for _, r in ipairs(results) do
		if r.pass then
			passed = passed + 1
			lines[#lines + 1] = L.CHECK_PASS_LINE:format(r.name)
		else
			failed = failed + 1
			if r.required then
				failedRequired = failedRequired + 1
			end
			lines[#lines + 1] = L.CHECK_FAIL_LINE:format(r.name, r.detail, r.required and "" or L.CHECK_OPTIONAL)
		end
	end
	lines[#lines + 1] = L.CHECK_SUMMARY:format(passed, failed, failedRequired)
	return lines
end
