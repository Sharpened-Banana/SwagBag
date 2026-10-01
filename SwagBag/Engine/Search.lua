-- SwagBag search state (spec F5), pure. The search box (UI/SearchBox.lua) feeds text
-- in; Apply dims every slot that is not a definite match. Search never moves items.
-- A text with errors is rejected and the previous valid search stays applied (AC5.3).
-- A keyword that fails while evaluating is trapped per pass: the previous dimming
-- stays and the search is reported as invalid (lastEvalError).
local _, SB = ...

-- lastWarning: a soft message for an applied search (an unknown #keyword matches nothing).
local S = { active = nil, text = "", lastError = nil, lastWarning = nil, lastEvalError = nil, stats = {} }
SB.Search = S

-- Returns true, or false + formatted error message.
function S.SetText(text)
	text = text or ""
	if S.active and text == S.text then
		S.lastError = nil -- unchanged valid query: no recompile
		return true
	end
	local compiled = SB.Query.Compile(text)
	if not compiled.fn then
		S.lastError = compiled.errors[1]
		return false, SB.Query.FormatError(S.lastError)
	end
	S.active, S.text, S.lastError = compiled, text, nil
	local w = compiled.warnings and compiled.warnings[1]
	S.lastWarning = w and SB.Query.FormatWarning(w) or nil
	return true
end

function S.IsActive()
	return S.active ~= nil and not S.active.empty
end

-- Byte range (first, last) of the characters to underline for a parse error.
-- Error positions are byte offsets; a trailing-operator error points one past the
-- end of the text, so it underlines the token before it. last < first means nothing
-- to underline (empty text). Never extends past the end of the text.
function S.ErrorSpan(text, err)
	local n = #text
	local first = math.max(1, math.min(err.position or 1, n + 1))
	if err.got and err.got ~= "" and first <= n then
		return first, math.min(n, first + #err.got - 1)
	end
	local last = #text:sub(1, first - 1):gsub("%s+$", "")
	if last == 0 then
		return 1, 0
	end
	local after = err.after
	if after and after ~= "" and last - #after + 1 >= 1 and text:sub(last - #after + 1, last) == after then
		return last - #after + 1, last
	end
	local start = text:sub(1, last):find("%S+$")
	return start or last, last
end

-- forEach(fn) calls fn(button, record-or-nil) for every slot in the window;
-- setDimmed(button, dimmed). Unknown (nil) results and empty slots are dimmed
-- while a search is active. Returns matches, total, milliseconds. If evaluation
-- fails, nothing is dimmed or undimmed and it returns nil, nil, ms, message.
function S.Apply(forEach, setDimmed)
	local A = SB.Adapter
	local t0 = A.ProfileMs()
	local c = S.IsActive() and S.active or nil
	local results, count, matches = {}, 0, 0
	local ok = SB.ErrorTrap.Run("search.eval", "none", function()
		forEach(function(button, record)
			count = count + 1
			local match = c == nil or (record ~= nil and SB.Query.Eval(c, record) == true)
			if match then
				matches = matches + 1
			end
			results[count] = { button, match }
		end)
	end)
	local ms = A.ProfileMs() - t0
	S.stats.lastMs = ms
	if not ok then
		S.lastEvalError = SB.L.SEARCH_EVAL_FAILED
		return nil, nil, ms, S.lastEvalError
	end
	S.lastEvalError = nil
	for i = 1, count do
		setDimmed(results[i][1], not results[i][2])
	end
	S.stats.lastMatches, S.stats.lastTotal = matches, count
	return matches, count, ms
end
