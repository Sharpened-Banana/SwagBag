-- SwagBag button skins (week 9, user pick 11). When Masque is loaded, SwagBag's item buttons join Masque groups
-- "SwagBag: Bags", "Bank" (character and warband), "Guild bank" and "Alt viewer", so they follow the skin the user
-- picks in Masque's own options (where each group can also be switched off). A list row's icon is the slot's
-- own button, scaled (week 5), so the list follows too. SwagBag only hands each button to Masque, once, and
-- only out of combat: Masque restyles the button's textures, and the bags' and the bank's buttons are Blizzard's
-- secure item buttons, so a button made during combat joins when combat ends. SwagBag never reparents, re-IDs or
-- sets an attribute on a button for this (spec 4.1). Without Masque nothing is asked and nothing changes; whether
-- it is there is asked once per session, at the first button.
--   Skins.Add(kind, button)   kind: "bags" | "bank" | "warband" | "guild" | "alts"
--   Skins.Available() -> bool;  Skins.count: buttons skinned (for /swagbag report)
local _, SB = ...

local Sk = { added = setmetatable({}, { __mode = "k" }), pending = {}, count = 0, available = nil,
	GROUPS = { bags = "Bags", bank = "Bank", warband = "Bank", guild = "Guild bank", alts = "Alt viewer" } }
SB.Skins = Sk

function Sk.Available()
	if Sk.available == nil then
		Sk.available = SB.Adapter.MasqueAvailable() == true
	end
	return Sk.available
end

local function flush()
	local list = Sk.pending
	Sk.pending = {}
	for _, e in ipairs(list) do
		Sk.Add(e[1], e[2])
	end
end

function Sk.Add(kind, button)
	if Sk.added[button] or not Sk.Available() then
		return
	end
	if SB.Adapter.InCombat() then
		Sk.pending[#Sk.pending + 1] = { kind, button }
		SB.OutOfCombat(flush, "skins.add", "none")
		return
	end
	if SB.Adapter.MasqueAdd(Sk.GROUPS[kind] or Sk.GROUPS.bags, button) then
		Sk.added[button] = true
		Sk.count = Sk.count + 1
	end
end
