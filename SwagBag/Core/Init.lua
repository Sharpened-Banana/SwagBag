-- SwagBag: addon namespace. Loaded first (see SwagBag.toc).
-- Every file starts with `local ADDON, SB = ...` and hangs its module off SB.
local ADDON, SB = ...

SB.name = ADDON
SB.VERSION = "0.7.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "

-- Print one chat line. Output goes through the Adapter so tests can capture it.
function SB.Print(msg)
	SB.Adapter.ChatPrint(SB.CHAT_PREFIX .. tostring(msg))
end

-- Week 7: is a bank visit open right now (UI/BankWindow.lua's `interaction`, between BANKFRAME_OPENED and
-- _CLOSED)? The section actions and the gold glow at the bank both ask here (ruling R12: one definition).
function SB.AtBank()
	return SB.BankWindow ~= nil and SB.BankWindow.interaction == true
end

-- Week 7: after settings changed in one go (quick setup, a profile load, import, reset or undo) the open
-- windows follow at once: categories, section totals, overlays, the bags' layout and title. One definition
-- for UI/QuickSetup.lua and Engine/Profiles.lua (ruling R12).
function SB.FollowSettings(reason)
	if SB.Categories then
		SB.Categories.Load()
	end
	SB.Emit("SB_PRICES_CHANGED")
	if SB.Overlays then
		SB.Overlays.context = nil
		SB.Overlays.RefreshAll()
	end
	local W = SB.BagsWindow
	if W and W.IsOpen and W.IsOpen() then
		W.RequestLayout(reason)
		W.RefreshTitle()
	end
end
