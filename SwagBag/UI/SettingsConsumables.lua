-- SwagBag settings: the Consumables page (spec 6.6, AC11.2). The warning on or off, each watched
-- entry with its threshold (- and +) and Remove, a drop target to watch another item (drag an
-- item onto it, or click it while holding one), Check now, and Reset to default.
-- Every refusal is worded by Consumables.ReasonText; the cursor is read and cleared only through
-- the Adapter, and cleared only after a successful Add, so a refused item stays on the cursor.
local _, SB = ...

local L = SB.L
local SW = SB.SettingsWindow

local DROP_ECHO = 0.2 -- a real click can fire OnClick and OnReceiveDrag together
local lastDrop

local function rows()
	local C, A = SB.Consumables, SB.Adapter
	local out = {
		{ kind = "choice", label = L.SET_WATCH_WARN, get = function()
			return SB.Config.Get("consumables.warn")
		end, choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			return SB.SettingsWindow.RunCommand(v and "consumables on" or "consumables off")
		end },
		{ kind = "note", label = L.SET_WATCH_WHEN },
	}
	if #C.List() == 0 then
		out[#out + 1] = { kind = "note", label = L.CONSUMABLES_NONE }
	end
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
			if lastDrop and A.Now() - lastDrop < DROP_ECHO then
				return SW.lastStatus -- the second half of one click: keep the success line
			end
			return L.SET_WATCH_DROP_EMPTY
		end
		local ok, why = C.Add(itemID)
		if not ok then
			return C.ReasonText(why) .. " " .. L.SET_WATCH_KEPT
		end
		A.ClearCursor() -- only now: a refused item stays on the cursor
		lastDrop = A.Now()
		return L.SET_WATCH_ADDED:format(C.Name({ itemID = itemID }))
	end }
	out[#out + 1] = { kind = "actions", label = L.SET_WATCH_TOOLS, actions = {
		{ text = L.SET_CHECK_NOW, run = function()
			C.Check("manual", true)
			return L.SET_WATCH_CHECKED
		end },
		{ text = L.SET_RESET_DEFAULT, run = function()
			local ok, why = C.Reset()
			if not ok then
				return C.ReasonText(why)
			end
			return L.CONSUMABLES_RESET:format(C.Summary())
		end },
	} }
	return out
end

SB.SettingsWindow.AddPage({ id = "consumables", title = L.SET_PAGE_CONSUMABLES, rows = rows })
