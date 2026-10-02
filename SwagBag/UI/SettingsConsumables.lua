-- SwagBag settings: the Consumables page (spec 6.6, AC11.2). The warning on or off, each watched
-- entry with its threshold (- and +) and Remove, a drop target to watch another item (drag an
-- item onto it, or click it while holding one), Check now, and Reset to default.
-- Every refusal is worded by Consumables.ReasonText; the cursor is read and cleared only through
-- the Adapter, and cleared only after a successful Add, so a refused item stays on the cursor.
local _, SB = ...

local L = SB.L

local function rows()
	local C, A = SB.Consumables, SB.Adapter
	local out = {
		{ kind = "choice", label = L.SET_WATCH_WARN, get = function()
			return SB.Config.Get("consumables.warn")
		end, choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			local _, feedback = SB.Slash.Run(v and "consumables on" or "consumables off")
			return feedback
		end },
		{ kind = "note", label = L.SET_WATCH_WHEN },
	}
	for i, e in ipairs(C.List()) do
		local name = C.Name(e)
		local function change(n)
			return function()
				local ok, why = C.SetThreshold(i, n)
				if not ok then
					return C.ReasonText(why)
				end
				return L.SET_WATCH_NEED:format(name, C.List()[i].threshold)
			end
		end
		out[#out + 1] = { kind = "actions", label = L.SET_WATCH_ROW:format(name, e.threshold), actions = {
			{ text = L.SET_LESS, width = 40, run = change(e.threshold - 1) },
			{ text = L.SET_MORE, width = 40, run = change(e.threshold + 1) },
			{ text = L.SET_REMOVE, width = 80, run = function()
				local ok, why = C.Remove(i)
				if not ok then
					return C.ReasonText(why)
				end
				return L.SET_WATCH_REMOVED:format(name)
			end },
		} }
	end
	out[#out + 1] = { kind = "drop", label = L.SET_WATCH_ADD, text = L.SET_WATCH_DROP, onDrop = function()
		local itemID = A.CursorItem()
		if not itemID then
			return L.SET_WATCH_DROP_EMPTY
		end
		local ok, why = C.Add(itemID)
		if not ok then
			return C.ReasonText(why)
		end
		A.ClearCursor() -- only now: a refused item stays on the cursor
		return L.SET_WATCH_ADDED:format(C.Name({ itemID = itemID }))
	end }
	out[#out + 1] = { kind = "actions", label = L.SET_WATCH_TOOLS, actions = {
		{ text = L.SET_CHECK_NOW, run = function()
			C.Check("manual", true)
			return L.SET_WATCH_CHECKED
		end },
		{ text = L.SET_RESET_DEFAULT, run = function()
			if not C.Reset() then
				return L.SETTINGS_READONLY
			end
			return L.CONSUMABLES_RESET:format(C.Summary())
		end },
	} }
	return out
end

SB.SettingsWindow.AddPage({ id = "consumables", title = L.SET_PAGE_CONSUMABLES, rows = rows })
