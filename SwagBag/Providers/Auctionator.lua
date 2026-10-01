-- SwagBag price provider "Auctionator" (spec F10, 3.3). Optional (P4): it answers only while
-- Auctionator's public API is loaded; otherwise the built-in "Vendor" provider answers and
-- section totals say "vendor". Calls go through the Adapter
-- (Auctionator.API.v1.GetAuctionPriceByItemLink("SwagBag", link)).
local _, SB = ...

SB.Prices.RegisterProvider({
	name = "Auctionator",
	priority = 10,
	available = function()
		return SB.Adapter.AuctionatorAvailable()
	end,
	value = function(link)
		if type(link) ~= "string" then
			return nil
		end
		return SB.Adapter.AuctionatorPrice(link)
	end,
	onUpdate = function(callback)
		SB.Adapter.AuctionatorOnUpdate(callback)
	end,
})
