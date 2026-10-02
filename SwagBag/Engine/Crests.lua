-- SwagBag crest data (spec 7.3 "crest", 13.2 item 4): what files into "Keystone & Crests"
-- besides the keystone. Per season, updated with patches.
--   ids    item IDs of the season's upgrade-currency items, confirmed in game
--   words  lower-case name words for the rest (never matched on gear, so a cloak named
--          "...Crest..." stays in Gear)
-- An item the user drops on the Keystone & Crests header joins it whatever this file says
-- (spec AC4.3); Claude moves confirmed IDs into `ids` when the user reports them.
local _, SB = ...

-- currencies: currency IDs of the season's crests, for the bags footer (UI/Footer.lua). Empty until
-- confirmed in game: the footer then shows every owned currency whose name has one of `words`.
SB.Crests = {
	ids = {},
	words = { "crest", "valorstone" },
	currencies = {},
}
