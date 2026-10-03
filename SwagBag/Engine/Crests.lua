-- SwagBag season data (spec 7.3 "crest", 13.2 item 4; week 7, user pick 2): what files into
-- "Keystone & Crests" besides the keystone, and what the footer's crests entry shows. Per season,
-- updated with patches: a new season (12.2) is an edit of this file only.
--   ids            item IDs filed under Keystone & Crests (upgrade-currency items), by ID
--   words          lower-case name words for the rest of those items (never matched on gear, so a
--                  cloak named "...Crest..." stays in Gear)
--   currencyWords  lower-case name words of the season's currencies: while `currencies` is empty the
--                  footer shows every owned currency whose name has one of them
--   currencies     currency IDs of the season's crests, confirmed in game (empty: the words decide)
--   items          bag items the footer shows next to the crests, with how many the bags hold
-- An item the user drops on the Keystone & Crests header joins it whatever this file says (spec
-- AC4.3). /swagbag report's "Season data" line names what the game has, so Claude can move confirmed
-- IDs here when the user pastes it.
local _, SB = ...

-- Ascendant Venomstone (12.1.5, live 2026-10-13): item 280562 on the 12.1.5 PTR (Wowhead and
-- warcraft.wiki.gg: stacks to 100, binds when picked up). Should the live game make it a currency
-- instead, "venomstone" in currencyWords finds it in the Currency tab's list. Confirmed in game with
-- the report's "Season data" line (session SN1).
local VENOMSTONE = 280562

SB.Crests = {
	ids = { [VENOMSTONE] = true },
	words = { "crest", "valorstone" },
	currencyWords = { "crest", "valorstone", "venomstone" },
	currencies = {},
	items = { VENOMSTONE },
}
