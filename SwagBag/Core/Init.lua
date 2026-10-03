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
