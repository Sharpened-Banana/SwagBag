-- 1,290-slot fixture (spec 3.4, 11.1): bags 0-4 x36 + reagent bag x32 (212 slots), six
-- character bank tabs and five warband tabs x98 (1,078 slots). Every fifth slot is empty;
-- the rest cycle through the shared item fixtures with 7 link variants per item.
local Fixtures = dofile("spec/fixtures/items.lua")

local Big = { SLOTS = 1290 }

Big.BAGS = { { 0, 36 }, { 1, 36 }, { 2, 36 }, { 3, 36 }, { 4, 36 }, { 5, 32 } }
for bag = 6, 16 do
	Big.BAGS[#Big.BAGS + 1] = { bag, 98 }
end

local CYCLE = {
	Fixtures.HEALING_POTION, Fixtures.FLASK, Fixtures.HERB, Fixtures.ORE, Fixtures.BOE_RING, Fixtures.SOULBOUND_HELM,
	Fixtures.JUNK, Fixtures.PET_CAGE, Fixtures.TOY, Fixtures.QUEST, Fixtures.BAG, Fixtures.UNLOADED,
}

-- Fill a mock Adapter. Returns the number of slots.
function Big.Install(m)
	Fixtures.Install(m)
	m.bagIDs = { bags = { 0, 1, 2, 3, 4, 5 }, bank = { 6, 7, 8, 9, 10, 11 }, warband = { 12, 13, 14, 15, 16 } }
	local n = 0
	for _, b in ipairs(Big.BAGS) do
		m.SetBagSize(b[1], b[2])
		for slot = 1, b[2] do
			n = n + 1
			if n % 5 ~= 0 then
				local id = CYCLE[n % #CYCLE + 1]
				m.Put(b[1], slot, id, 1, { link = "item:" .. id .. "::" .. (n % 7) })
			end
		end
	end
	return n
end

return Big
