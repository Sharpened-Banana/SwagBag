-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / SpikePrice.lua
-- Spike P: is Auctionator's price API usable from another addon?
--   Auctionator.API.v1.GetAuctionPriceByItemLink(callerID, itemLink)
-- (signature verified against Auctionator source mirrors, 2026-09-30)
-- Runs automatically 10 s after login, read-only. Also peeks at TSM_API.
-- =====================================================================
local ADDON, ns = ...

ns.RegisterSpike("P_PRICE", "Auctionator price API availability + speed", "new (user request)",
	"Whether SwagBag can show AH value / 'value' sort keys via Auctionator (optional dependency)")

local function Run()
	local okL, loaded = pcall(C_AddOns.IsAddOnLoaded, "Auctionator")
	local api = ns.Resolve("Auctionator.API.v1")
	local fnLink = api and api.GetAuctionPriceByItemLink
	local fnID = api and api.GetAuctionPriceByItemID
	local apiNames = {}
	if type(api) == "table" then
		for k, v in pairs(api) do if type(v) == "function" then apiNames[#apiNames + 1] = k end end
		table.sort(apiNames)
	end
	ns.Data("P_PRICE", "auctionatorLoaded", okL and loaded or false)
	ns.Data("P_PRICE", "apiV1Functions", apiNames)
	if type(fnLink) ~= "function" then
		ns.Check("P_PRICE", "auctionatorApiPresent", false, { loaded = okL and loaded })
		ns.Summary("P_PRICE", "Auctionator API not found")
		return
	end
	ns.Check("P_PRICE", "auctionatorApiPresent", true, "GetAuctionPriceByItemLink found")

	local seen, links = {}, {}
	for _, bag in ipairs(ns.BAGS) do
		for slot = 1, ns.NumSlots(bag) do
			local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if ok and info and info.hyperlink and not seen[info.hyperlink] and #links < 200 then
				seen[info.hyperlink] = true
				links[#links + 1] = info.hyperlink
			end
		end
	end
	local priced, nilCount, errs, samples = 0, 0, 0, {}
	local total, worst = 0, 0
	for _, link in ipairs(links) do
		local t0 = debugprofilestop()
		local ok, price = pcall(fnLink, ADDON, link)
		local dt = debugprofilestop() - t0
		total = total + dt
		if dt > worst then worst = dt end
		if not ok then
			errs = errs + 1
			if errs == 1 then ns.Data("P_PRICE", "firstError", tostring(price)) end
		elseif type(price) == "number" then
			priced = priced + 1
			if #samples < 6 then samples[#samples + 1] = { link = link, copper = price } end
		else
			nilCount = nilCount + 1
		end
	end
	local avgMs = #links > 0 and total / #links or 0
	ns.Data("P_PRICE", "result", { items = #links, priced = priced, noPrice = nilCount, errors = errs,
		avgMs = avgMs, worstMs = worst, totalMs = total, samples = samples })
	ns.Check("P_PRICE", "pricesReturned", priced > 0 and errs == 0, ("%d/%d items priced, %d errors"):format(priced, #links, errs))
	ns.Check("P_PRICE", "fastEnough", avgMs < 0.2, ("avg %.3f ms, worst %.3f ms per call"):format(avgMs, worst))
	if type(fnID) == "function" then
		local okI, p = pcall(fnID, ADDON, 6948) -- Hearthstone: expected nil (not sellable)
		ns.Data("P_PRICE", "byItemID_hearthstone", { ok = okI, value = ns.Safe(p) })
	end

	-- TSM (optional, just presence + one call)
	local tsm = ns.Resolve("TSM_API.GetCustomPriceValue")
	if type(tsm) == "function" and links[1] then
		local itemString = ns.Resolve("TSM_API.ToItemString")
		local okS, istr = pcall(itemString or function() return nil end, links[1])
		local okP, v = pcall(tsm, "dbmarket", okS and istr or links[1])
		ns.Data("P_PRICE", "tsm", { present = true, ok = okP, sample = ns.Safe(v) })
	else
		ns.Data("P_PRICE", "tsm", { present = type(tsm) == "function" })
	end
	ns.Summary("P_PRICE", ("Auctionator: %d/%d priced, avg %.3f ms/call"):format(priced, #links, avgMs))
end

ns.OnLogin(function() C_Timer.After(10, function() ns.Try("Price.Run", Run) end) end)
ns.Command("price", "re-run the Auctionator price test", function() Run() ns.Print("price test done (see /sbs status)") end)
ns.commands.p = ns.commands.price
