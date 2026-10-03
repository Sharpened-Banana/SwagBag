-- SwagBag settings: the Vendor page (week 7, user pick 4). Auto-sell junk On (default) / Off, and the
-- repair: Your gold (default) / Guild bank first / Off. Every click runs the chat command, so the
-- window and the command never disagree (P2: the status line answers).
local _, SB = ...

local L = SB.L

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
	}
end

SB.SettingsWindow.AddPage({ id = "vendor", title = L.SET_PAGE_VENDOR, rows = rows })
