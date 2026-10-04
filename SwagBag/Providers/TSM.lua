-- SwagBag price provider "TSM" (week 9, user pick 10; spec F10, 3.3). Optional (P4): it answers only while
-- TradeSkillMaster's public addon API is loaded, by the price string the prices.tsm setting names (DBMarket by
-- default; Engine/Prices.lua, Prices.TSMString). Priority 5: below Auctionator (10), above the vendor (0), so
-- "auto" asks Auctionator first. Calls go through the Adapter (Adapter.TSMAvailable, Adapter.TSMPrice). TSM's
-- data may still be loading after login, so its "no price" is kept Prices.MISS_AGE (30 s) only (missAge).
local _, SB = ...

SB.Prices.RegisterProvider({
	name = "TSM",
	priority = 5,
	missAge = SB.Prices.MISS_AGE,
	available = function()
		return SB.Adapter.TSMAvailable()
	end,
	value = function(link)
		if type(link) ~= "string" then
			return nil
		end
		return SB.Adapter.TSMPrice(link, SB.Prices.TSMString())
	end,
})
