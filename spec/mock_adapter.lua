-- Mock Adapter for unit tests. Loads the REAL SwagBag/Core/Adapter.lua (so its
-- constants and pure helpers are tested too), then replaces every function that
-- would call WoW with an in-memory fake.
local M = {}

function M.New(SB)
	local chunk = assert(loadfile("SwagBag/Core/Adapter.lua"))
	chunk("SwagBag", SB)
	local m = SB.Adapter

	m.clock = 0 -- seconds, advanced only by m.Advance
	m.timers = {}
	m.timerSeq = 0
	m.printed = {}
	m.combat = false
	m.globals = {} -- what Resolve() can see
	m.addons = {} -- name -> version string (loaded) or false (installed, not loaded)

	function m.ChatPrint(text)
		m.printed[#m.printed + 1] = text
	end

	-- Printed lines with the "SwagBag: " chat prefix removed.
	function m.Lines()
		local out = {}
		for i, text in ipairs(m.printed) do
			out[i] = (text:gsub("^|cff33ff99SwagBag|r: ", ""))
		end
		return out
	end

	function m.Now()
		return m.clock
	end

	function m.ProfileMs()
		return m.clock * 1000
	end

	function m.After(seconds, fn)
		m.timerSeq = m.timerSeq + 1
		m.timers[#m.timers + 1] = { at = m.clock + seconds, seq = m.timerSeq, fn = fn }
	end

	-- Move the clock forward, running due timers in time order (ties: creation order).
	function m.Advance(seconds)
		local target = m.clock + seconds
		while true do
			local bestIndex, best
			for i, t in ipairs(m.timers) do
				if t.at <= target and (best == nil or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then
					bestIndex, best = i, t
				end
			end
			if not best then
				break
			end
			table.remove(m.timers, bestIndex)
			m.clock = best.at
			best.fn()
		end
		m.clock = target
	end

	function m.InCombat()
		return m.combat
	end

	function m.IsSecret()
		return false
	end

	function m.Stack()
		return "[stack]"
	end

	local DATE_PARTS = { Y = "2026", m = "10", d = "01", H = "21", M = "03", S = "07" }
	function m.Date(fmt)
		return (fmt:gsub("%%(%a)", DATE_PARTS))
	end

	function m.BuildInfo()
		return { version = "12.1.0", build = "69933", toc = 120100, locale = "enUS" }
	end

	function m.Resolve(path)
		local cur = m.globals
		for part in path:gmatch("[^%.]+") do
			if type(cur) ~= "table" then
				return nil
			end
			cur = cur[part]
			if cur == nil then
				return nil
			end
		end
		return cur
	end

	function m.AddOnState(name)
		local v = m.addons[name]
		if v == nil or v == false then
			return false, nil
		end
		return true, v
	end

	return m
end

return M
