-- SwagBag: addon namespace. Loaded first (see SwagBag.toc).
-- Every file starts with `local ADDON, SB = ...` and hangs its module off SB.
local ADDON, SB = ...

SB.name = ADDON
SB.VERSION = "0.3.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "

-- Print one chat line. Output goes through the Adapter so tests can capture it.
function SB.Print(msg)
	SB.Adapter.ChatPrint(SB.CHAT_PREFIX .. tostring(msg))
end
