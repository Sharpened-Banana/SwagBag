-- SwagBag settings: the Vendor page (week 7, user pick 4). Auto-sell junk On (default) / Off, and the
-- repair: Your gold (default) / Guild bank first / Off. Every click runs the chat command, so the
-- window and the command never disagree (P2: the status line answers). Item locks (user pick 5): a drop
-- target that locks or unlocks the item on the cursor (as the bags' Lock button), and Unlock all. Week 10: the
-- warnings before a locked item is destroyed, On (default) / Off.
local _, SB = ...

local L = SB.L

local DROP_ECHO = 0.2 -- one press can fire OnReceiveDrag and OnClick together (as on the Consumables page)
local lastDrop

local function lockDrop()
	local A = SB.Adapter
	if not A.CursorItem() and lastDrop and A.Now() - lastDrop < DROP_ECHO then
		return SB.SettingsWindow.lastStatus -- the second half of one press: keep the answer
	end
	local line = SB.LockButton and SB.LockButton.Drop()
	if not line then
		return L.SET_WATCH_DROP_EMPTY
	end
	lastDrop = A.Now()
	return line
end

local function rows()
	local run = SB.SettingsWindow.RunCommand
	return {
		{ kind = "choice", label = L.SET_VENDOR_SELL, tip = L.SET_VENDOR_SELL_TIP, get = function()
			return SB.Config.Get("vendor.autoSell")
		end, choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			return run(v and "sell on" or "sell off")
		end },
		{ kind = "choice", label = L.SET_VENDOR_REPAIR, tip = L.SET_VENDOR_REPAIR_TIP, width = 130, get = function()
			return SB.Config.Get("vendor.repair")
		end, choices = { { value = "own", text = L.SET_VENDOR_REPAIR_OWN }, { value = "guild", text = L.SET_VENDOR_REPAIR_GUILD },
			{ value = "off", text = L.SET_OFF } },
		apply = function(v)
			return run("repair " .. v)
		end },
		{ kind = "note", label = L.SET_VENDOR_NOTE },
		{ kind = "drop", label = L.SET_LOCK_DROP_LABEL, text = L.SET_LOCK_DROP, tip = L.LOCK_TIP_BODY, onDrop = lockDrop },
		{ kind = "actions", label = L.SET_LOCK_COUNT:format(SB.Locks and #SB.Locks.List() or 0), actions = {
			{ text = L.SET_LOCK_LIST, run = function()
				return run("lock list")
			end },
			{ text = L.SET_LOCK_CLEAR, run = function()
				return run("lock clear")
			end },
		} },
		-- Week 10: warnings before a locked item is destroyed (UI/LockWarnings.lua); runs /swagbag lock warn.
		{ kind = "choice", label = L.SET_LOCK_WARN, tip = L.SET_LOCK_WARN_TIP, get = function()
			return SB.Config.Get("locks.warn")
		end, choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			return run(v and "lock warn on" or "lock warn off")
		end },
	}
end

SB.SettingsWindow.AddPage({ id = "vendor", title = L.SET_PAGE_VENDOR, rows = rows })

-- "Locked items: N" follows a lock or unlock made anywhere (the bags' Lock button, a command) while the
-- window is open (ruling R17); a click on the page re-draws it anyway.
SB.On("SB_LOCKS_CHANGED", function()
	local SW = SB.SettingsWindow
	if SW.IsOpen() then
		SW.Render()
	end
end, "none")
