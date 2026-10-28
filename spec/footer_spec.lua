-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- luacheck: globals GetMoney GetMoneyString GetCoinTextureString C_CurrencyInfo issecretvalue
-- The bags footer (ruling W4-14): gold, backpack currencies, crests, keystone and free slots, in
-- the user's order; wraps instead of overlapping; refreshes on events, debounced, while open.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local KEYSTONE_LINK = "|cffa335ee|Hkeystone:180653:503:12:10:9:0:0|h[Keystone: Ara-Kara]|h|r"

describe("Footer (ruling W4-14)", function()
	local SB, A, F, W, resized
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Crests.lua"
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- 16 slots, 6 items (the keystone in slot 5): 10 free
		SB.Inventory.ScanAll()
		Fake.Install()
		resized = 0
		-- The bags window as the footer uses it.
		W = { frame = Fake.New("Frame", UIParent), size = { 495, 300 }, FOOTER = 6, open = true }
		function W.IsOpen()
			return W.open
		end
		function W.Resize()
			resized = resized + 1
		end
		SB.BagsWindow = W
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua") -- SW.RunCommand, as in the TOC
		Loader.LoadFile(SB, "SwagBag/UI/Footer.lua")
		F = SB.Footer
		F.TextWidth = function(fs) -- 8 px per character, so the wrap is easy to check by hand
			return 8 * #(fs.text or "")
		end
		A.money = 1234567
		A.backpack = { { id = 3056, name = "Kej", quantity = 500, icon = 1 } }
		A.currencies = { { id = 3107, name = "Weathered Ethereal Crest", quantity = 45, icon = 2 },
			{ id = 3108, name = "Carved Ethereal Crest", quantity = 0, icon = 3 },
			{ id = 2815, name = "Resonance Crystals", quantity = 900, icon = 4 } }
		A.dungeons[503] = "Ara-Kara, City of Echoes"
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function texts()
		local out = {}
		for i, item in ipairs(F.items) do
			out[i] = item.text
		end
		return out
	end

	-- Mutation: in Footer.Crests, drop `c.quantity > 0` (a crest the character does not own shows as 0).
	it("default: every entry on, in the order gold, currencies, crests, keystone, free; only owned crests", function()
		assert.same({ { id = "gold", on = true }, { id = "currencies", on = true }, { id = "crests", on = true },
			{ id = "keystone", on = true }, { id = "free", on = true } }, F.Entries())
		F.Refresh()
		assert.same({ "123", "500", "45", "AKCE +12", "10 free" }, texts(), "gold: the whole gold pieces (week 6)")
		assert.equal(1, resized, "the window fits the new footer")
	end)

	-- Mutation: in Footer.Crests, ignore SB.Crests.currencies (always match by name).
	it("crests come from the season's confirmed currency IDs when Engine/Crests.lua has them", function()
		SB.Crests.currencies = { 2815 }
		F.Refresh()
		assert.same({ "123", "500", "900", "AKCE +12", "10 free" }, texts())
	end)

	-- Week 7 (user pick 2). Mutation: in Footer.Items, drop the F.SeasonItems() loop.
	it("crests: the Venomstones in the bags show after the crest currencies, counted over every stack", function()
		A.AddItem(280562, { name = "Ascendant Venomstone", classID = A.ITEM_CLASS.Consumable, subclassID = 8, quality = 4,
			maxStack = 100, bind = "pickup" })
		A.Put(0, 7, 280562, 6)
		A.SetBagSize(1, 10)
		A.Put(1, 2, 280562, 4)
		SB.Inventory.ScanAll()
		F.Refresh()
		assert.same({ "123", "500", "45", "10", "AKCE +12", "18 free" }, texts())
		assert.same({ entry = "crests", text = "10", icon = 280562, tip = { kind = "item", id = 280562 } }, F.items[4])
		Fake.Fire(F.widgets[4], "OnEnter")
		assert.same({ 280562 }, GameTooltip.calls.SetItemByID, "the item's own tooltip")
		A.Clear(0, 7)
		A.Clear(1, 2)
		SB.Inventory.ScanAll()
		F.Refresh()
		assert.same({ "123", "500", "45", "AKCE +12", "20 free" }, texts(), "none carried: nothing shows")
	end)

	-- Week 7: should the live game make Venomstones a currency, the season words find it. Mutation: drop
	-- "venomstone" from SB.Crests.currencyWords.
	it("crests: a currency named like the season's (Venomstone) shows when no currency IDs are confirmed", function()
		A.currencies[#A.currencies + 1] = { id = 3400, name = "Ascendant Venomstone", quantity = 30, icon = 5 }
		F.Refresh()
		assert.same({ "123", "500", "45", "30", "AKCE +12", "10 free" }, texts())
	end)

	-- Week 7. Mutation: in the Inventory listener, drop `or (Inv.Has(mask, Inv.R.COUNT) and seasonCount(changes))`.
	it("a Venomstone stack that grows refreshes the footer; other count changes still do not (W4-26)", function()
		A.AddItem(280562, { name = "Ascendant Venomstone", classID = A.ITEM_CLASS.Consumable, subclassID = 8, quality = 4,
			maxStack = 100, bind = "pickup" })
		A.Put(0, 7, 280562, 6)
		SB.Inventory.ScanAll()
		F.Refresh()
		local reads, items = 0, F.Items
		F.Items = function()
			reads = reads + 1
			return items()
		end
		local Inv = SB.Inventory
		Inv.Notify(Inv.R.COUNT, { { bag = 0, slot = 1, reasons = Inv.R.COUNT } })
		A.Advance(0.2)
		assert.equal(0, reads, "a potion used: no refresh")
		Inv.Notify(Inv.R.COUNT, { { bag = 0, slot = 7, reasons = Inv.R.COUNT } })
		A.Advance(0.2)
		assert.equal(1, reads, "a Venomstone looted onto its stack")
	end)

	-- Mutation: in Footer.SeasonText, skip the currencies loop.
	it("SeasonText names the season's currencies (with IDs) and its items' counts, for the report", function()
		A.AddItem(280562, { name = "Ascendant Venomstone", classID = A.ITEM_CLASS.Consumable, subclassID = 8, quality = 4,
			maxStack = 100, bind = "pickup" })
		A.Put(0, 7, 280562, 12)
		SB.Inventory.ScanAll()
		local currencies, items = F.SeasonText()
		assert.equal("Weathered Ethereal Crest (3107) 45, Carved Ethereal Crest (3108) 0", currencies)
		assert.equal("Ascendant Venomstone (280562) 12", items)
		A.currencies = {}
		SB.Crests.items = {}
		assert.same({ "none", "none" }, { F.SeasonText() })
	end)

	-- Mutation: in Footer.Flow, `if x > 0 and x + w > maxWidth then` → `if false then`.
	it("entries that do not fit the width wrap to the next row, never overlap, and the height follows", function()
		W.size[1] = 100
		F.Refresh()
		local rows = 0
		for i, p in ipairs(F.places) do
			rows = math.max(rows, p.row)
			assert.truthy(p.x + F.widths[i] <= 100, "item " .. i .. " inside the bar")
			for j = 1, i - 1 do
				local q = F.places[j]
				if q.row == p.row then
					assert.truthy(q.x + F.widths[j] <= p.x, "items " .. j .. " and " .. i .. " do not overlap")
				end
			end
		end
		assert.equal(4, rows)
		assert.equal(4 * F.ROW + 3 * F.ROW_GAP + F.PAD, F.height)
		assert.equal(1, resized)
		assert.equal(F.ROW + F.PAD, F.Layout(1008), "a wide window: one row")
	end)

	-- P2. Mutation: in the footer command, return nothing after F.Move (no "is now number" line).
	it("/swagbag footer lists the entries, switches and moves one, and answers each time", function()
		F.Refresh()
		SB.Slash.Dispatch("footer")
		SB.Slash.Dispatch("footer crests off")
		SB.Slash.Dispatch("footer free up")
		SB.Slash.Dispatch("footer gold up")
		SB.Slash.Dispatch("footer sparkles on")
		assert.same({ "Footer, left to right: Gold on, Backpack currencies on, Crests on, Keystone on, Free slots on",
			"Footer: Crests is now off.", "Footer: Free slots is now number 4.",
			"Footer: Gold cannot move further that way.", SB.L.FOOTER_USAGE }, A.Lines())
		assert.equal("gold,currencies,-crests,free,keystone", SB.Config.Get("bags.footer.entries"))
		assert.same({ "123", "500", "10 free", "AKCE +12" }, texts())
	end)

	-- Final review. Mutation: answering FOREVER_LEFT_OUT on Retail (Allows ignored).
	it("on Retail /swagbag footer crests with no verb answers the usage", function()
		SB.Slash.Dispatch("footer crests")
		assert.same({ SB.L.FOOTER_USAGE }, A.Lines())
	end)

	-- Mutation: in Footer's save(), ignore SB.Config.Set's result (`SB.Config.Set(...) return true`).
	it("read-only settings: the command refuses with the reason and changes nothing", function()
		SB.Config.readOnly = true
		SB.Slash.Dispatch("footer gold off")
		SB.Slash.Dispatch("footer keystone up")
		assert.same({ SB.L.SETTINGS_READONLY, SB.L.SETTINGS_READONLY }, A.Lines())
		assert.equal("gold,currencies,crests,keystone,free", SB.Config.Get("bags.footer.entries"))
	end)

	-- Mutation: in Footer.Tooltip, the currency branch calls T:SetText(item.text) instead of SetCurrencyByID.
	-- M5. Mutation: in OnLeave, drop the `GameTooltip:IsOwned(self)` check (always Hide).
	it("hovering an entry shows its standard tooltip; leaving hides it", function()
		function GameTooltip.IsOwned(t, owner)
			return t.calls.SetOwner ~= nil and t.calls.SetOwner[1] == owner
		end
		F.Refresh()
		Fake.Fire(F.widgets[1], "OnEnter")
		assert.equal(SB.L.FOOTER_GOLD, GameTooltip.text)
		Fake.Fire(F.widgets[2], "OnEnter")
		assert.same({ 3056 }, GameTooltip.calls.SetCurrencyByID)
		Fake.Fire(F.widgets[4], "OnEnter")
		assert.same({ KEYSTONE_LINK }, GameTooltip.calls.SetHyperlink)
		Fake.Fire(F.widgets[5], "OnEnter")
		assert.equal(SB.L.FOOTER_FREE_TITLE, GameTooltip.text)
		GameTooltip:Show()
		Fake.Fire(F.widgets[4], "OnLeave")
		assert.truthy(GameTooltip.shown, "leaving another entry leaves someone else's tooltip alone")
		Fake.Fire(F.widgets[5], "OnLeave")
		assert.falsy(GameTooltip.shown)
	end)

	-- Mutation: in Footer.Items, `if not shown[c.id] then` -> `if true then`.
	it("a crest ticked 'Show on backpack' shows once, under currencies; crests adds nothing", function()
		A.backpack = { { id = 3056, name = "Kej", quantity = 500, icon = 1 },
			{ id = 3107, name = "Weathered Ethereal Crest", quantity = 45, icon = 2 } }
		F.Refresh()
		assert.same({ "123", "500", "45", "AKCE +12", "10 free" }, texts())
		assert.equal("currencies", F.items[3].entry)
		for _, item in ipairs(F.items) do
			assert.truthy(item.entry ~= "crests", "no crest entry")
		end
	end)

	-- Mutations: in Footer.Entries, drop the loop that adds missing ids; drop `not seen[id]`; drop
	-- `KNOWN[id]`.
	it("saved text: spaces, unknown ids, repeats and broken parts are cleaned up; missing ids added", function()
		SB.Config.Set("bags.footer.entries", " -free ,gold,sparkles,gold,--crests")
		assert.same({ { id = "free", on = false }, { id = "gold", on = true }, { id = "currencies", on = true },
			{ id = "crests", on = true }, { id = "keystone", on = true } }, F.Entries())
	end)

	-- Ruling W4-23. Mutation: in Footer.Entries, `table.insert(out, at + 1, ...)` -> `out[#out + 1] = ...`.
	it("an entry missing from saved text (a later release) joins at its default place, on", function()
		SB.Config.Set("bags.footer.entries", "keystone,-gold,free")
		assert.same({ { id = "keystone", on = true }, { id = "gold", on = false }, { id = "currencies", on = true },
			{ id = "crests", on = true }, { id = "free", on = true } }, F.Entries())
		SB.Config.Set("bags.footer.entries", "free,crests")
		assert.same({ "gold", "currencies", "free", "crests", "keystone" }, (function()
			local ids = {}
			for i, e in ipairs(F.Entries()) do
				ids[i] = e.id
			end
			return ids
		end)())
	end)

	-- M3. Mutation: in Footer.Items, `add("gold", A.MoneyText(A.Money() or 0), ...)` (no last-known).
	it("gold the client will not tell (secret or missing) shows the last known amount, never a false 0", function()
		A.money = nil
		F.Refresh()
		assert.same({ "500", "45", "AKCE +12", "10 free" }, texts(), "nothing known yet: no gold entry")
		A.money = 1234567
		F.Refresh()
		assert.equal("123", texts()[1])
		A.money = nil
		F.Refresh()
		assert.equal("123", texts()[1], "the last known amount")
	end)

	-- Week 6, D22 (FT1, O1: the gold needs a proper coin). Mutations: add the gold entry with no
	-- icon; in GoldText, drop the separator loop; the money tooltip shows item.text (gold only).
	it("gold: a full-size coin, the whole gold with thousands separators; silver and copper in its tooltip", function()
		A.money = 12345678901 -- 1,234,567 gold 89 silver 1 copper
		local asked
		A.MoneyText = function(copper)
			asked = copper
			return "1,234,567g 89s 1c"
		end
		F.Refresh()
		assert.equal("1,234,567", F.items[1].text)
		assert.equal(F.GOLD_ICON, F.items[1].icon)
		assert.truthy(F.widgets[1].icon.shown)
		assert.equal(F.widgets[2].icon.w, F.widgets[1].icon.w, "the coin is as big as the currency icons")
		Fake.Fire(F.widgets[1], "OnEnter")
		assert.equal(SB.L.FOOTER_GOLD, GameTooltip.text)
		assert.same({ "1,234,567g 89s 1c", 1, 1, 1 }, GameTooltip.calls.AddLine)
		assert.equal(12345678901, asked, "the full amount, silver and copper too")
		assert.same({ "0", "0", "1", "999", "1,000", "10,000,000" }, { F.GoldText(0), F.GoldText(9999), F.GoldText(10000),
			F.GoldText(9990000), F.GoldText(10000000), F.GoldText(100000000000) })
	end)

	-- Task 0.17-3 (alt gold). Mutations: drop the warband line; sort the lines poorest first; skip the blank line.
	local function recordLines()
		local lines = {}
		GameTooltip.SetText = function(_, t) lines[#lines + 1] = { t } end
		GameTooltip.AddLine = function(_, t, r, g, b) lines[#lines + 1] = { t, r, g, b } end
		GameTooltip.AddDoubleLine = function(_, l, r) lines[#lines + 1] = { l, r, double = true } end
		return lines
	end
	local function loadWealth()
		for _, path in ipairs({ "SwagBag/Engine/Snapshots.lua", "SwagBag/Engine/AltData.lua", "SwagBag/Engine/Wealth.lua" }) do
			Loader.LoadFile(SB, path)
		end
		SB.Config.Init(nil, nil)
		local db = SB.Snapshots.DB()
		db.chars["Ann-Tichondrius"] = { class = "MAGE", money = 90000000 }
		db.chars["Ann-Argent Dawn"] = { class = "PRIEST", money = 50000000, currencies = { [3056] = 40 } }
		db.chars["Cy-Argent Dawn"] = { class = "ROGUE", money = 0, currencies = { [3056] = 0 } }
		A.WarbandMoney = function() return 10000000 end
		A.ClassColour = function(c) return c == "MAGE" and "|cff3fc7eb" or nil end
	end

	it("the gold tooltip adds every character, the warband bank and the total", function()
		loadWealth()
		A.money = 20000000
		F.Refresh()
		local lines = recordLines()
		Fake.Fire(F.widgets[1], "OnEnter")
		assert.same({ SB.L.FOOTER_GOLD }, lines[1])
		assert.same({ A.MoneyText(20000000), 1, 1, 1 }, lines[2])
		assert.equal(" ", lines[3][1], "a blank line")
		assert.same({ "|cff3fc7ebAnn-Tichondrius|r", "9,000g" }, { lines[4][1], lines[4][2] })
		assert.same({ "Ann-Argent Dawn", "5,000g" }, { lines[5][1], lines[5][2] })
		assert.same({ "|cff3fc7ebSwagger|r", "2,000g" }, { lines[6][1], lines[6][2] })
		assert.same({ SB.L.FOOTER_WARBAND_GOLD, "1,000g" }, { lines[7][1], lines[7][2] })
		assert.same({ SB.L.FOOTER_TOTAL, "17,000g" }, { lines[8][1], lines[8][2] })
		assert.equal(8, #lines)
	end)

	it("with no alt saved the tooltip says how to add them", function()
		loadWealth()
		SB.Snapshots.DB().chars = {}
		A.WarbandMoney = function() return nil end
		F.Refresh()
		local lines = recordLines()
		Fake.Fire(F.widgets[1], "OnEnter")
		assert.same({ SB.L.FOOTER_GOLD }, lines[1])
		assert.equal(SB.L.FOOTER_ALTS_NONE, lines[#lines][1])
		assert.equal("Log in on your other characters once to add them here.", SB.L.FOOTER_ALTS_NONE)
		assert.falsy(lines[#lines][2] == SB.L.FOOTER_TOTAL)
	end)

	it("the currency tooltip lists each character's quantity of that currency", function()
		loadWealth()
		F.Refresh()
		local lines = recordLines()
		for i, it in ipairs(F.items) do
			if it.tip.kind == "currency" and it.tip.id == 3056 then
				Fake.Fire(F.widgets[i], "OnEnter")
			end
		end
		assert.same({ 3056 }, GameTooltip.calls.SetCurrencyByID)
		assert.same({ "Ann-Argent Dawn", "40" }, { lines[#lines][1], lines[#lines][2] })
	end)

	-- M2. Mutation: delete the SB_BAGS_CLOSED handler in Footer.lua.
	it("closing the bags marks the footer to be re-read on the next open", function()
		F.Refresh()
		assert.falsy(F.dirty)
		SB.Emit("SB_BAGS_CLOSED")
		assert.truthy(F.dirty)
	end)

	-- Final fix M4. Mutation: drop the SB_THEME_CHANGED listener.
	it("a theme switch re-reads the footer, debounced", function()
		F.Refresh()
		local reads, items = 0, F.Items
		F.Items = function()
			reads = reads + 1
			return items()
		end
		SB.Emit("SB_THEME_CHANGED", "plain")
		assert.equal(0, reads)
		A.Advance(0.2)
		assert.equal(1, reads)
	end)

	-- Spec 6.5 spirit (no polling). Mutation: make soon() call F.Refresh() at once (no SB.Debounce).
	it("money, currency and bag events refresh once, debounced, and only while the bags are open", function()
		F.Refresh()
		local reads, items = 0, F.Items
		F.Items = function()
			reads = reads + 1
			return items()
		end
		SB.eventFrame:Fire("PLAYER_MONEY")
		SB.eventFrame:Fire("CURRENCY_DISPLAY_UPDATE")
		A.Put(0, 7, Fixtures.HERB, 5)
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		assert.equal(0, reads)
		A.Advance(0.2)
		assert.equal(1, reads)
		assert.equal("9 free", F.items[5].text)
		W.open = false
		SB.eventFrame:Fire("PLAYER_MONEY")
		A.Advance(0.2)
		assert.equal(1, reads, "closed: nothing is read until the bags open")
		assert.truthy(F.dirty)
		for _, w in ipairs(F.widgets) do
			assert.is_nil(w.scripts.OnUpdate)
		end
	end)

	-- Ruling W4-26: cooldown and lock changes (every cast in a key) change nothing the footer shows.
	-- Mutation: drop the ITEM/SIZE guard in the footer's inventory listener.
	it("W4-26: cooldown-only and lock-only changes never start a footer refresh", function()
		F.Refresh()
		local reads, items = 0, F.Items
		F.Items = function()
			reads = reads + 1
			return items()
		end
		local Inv = SB.Inventory
		Inv.Notify(Inv.R.COOLDOWN, {})
		Inv.Notify(Inv.R.LOCK, { { bag = 0, slot = 1, reasons = Inv.R.LOCK } })
		Inv.Notify(Inv.R.COUNT + Inv.R.LOCK, { { bag = 0, slot = 1, reasons = Inv.R.COUNT + Inv.R.LOCK } })
		assert.equal(0, #A.timers, "no refresh timer was started")
		A.Advance(0.2)
		assert.equal(0, reads)
		Inv.Notify(Inv.R.ITEM + Inv.R.LOCK, { { bag = 0, slot = 7, reasons = Inv.R.ITEM } })
		A.Advance(0.2)
		assert.equal(1, reads, "an item change still refreshes")
		Inv.Notify(Inv.R.SIZE, {})
		A.Advance(0.2)
		assert.equal(2, reads, "a size change still refreshes")
	end)

	-- P1, D17. Mutation: in the Footer page's apply, always run "footer <id> on".
	it("Settings > Footer: Show (default, first) / Hide and Move up / Move down run /swagbag footer", function()
		local SW = SB.SettingsWindow
		SW.Show("footer")
		assert.same({ "Show", "Hide", "Move up", "Move down" },
			{ SW.buttons[1].text, SW.buttons[2].text, SW.buttons[3].text, SW.buttons[4].text })
		assert.truthy(SW.selected[SW.buttons[1]])
		Fake.Fire(SW.buttons[2], "OnClick")
		assert.equal("Footer: Gold is now off.", SW.lastStatus)
		assert.truthy(SW.selected[SW.buttons[2]])
		Fake.Fire(SW.buttons[7], "OnClick") -- row 2, Backpack currencies: Move up
		assert.equal("Footer: Backpack currencies is now number 1.", SW.lastStatus)
		assert.equal("currencies,-gold,crests,keystone,free", SB.Config.Get("bags.footer.entries"))
	end)

	it("is built in combat from plain frames only (never an item or secure button)", function()
		A.combat = true
		F.Refresh()
		SB.SettingsWindow.Show("footer")
		assert.truthy(#F.widgets >= 5)
		for _, f in ipairs(Fake.created) do
			assert.truthy(f.kind == "Frame" or f.kind == "Button" or f.kind == "ScrollFrame", f.kind)
			assert.falsy(tostring(f.template):find("Secure"), tostring(f.template))
		end
	end)
end)

describe("Footer load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Get = function()
			error("Config.Get called while loading")
		end
		Fake.Install()
		SB.BagsWindow = { frame = Fake.New("Frame"), size = { 100, 100 }, FOOTER = 6 }
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/Footer.lua")
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)

describe("Adapter: money and currencies (the real Adapter)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Locale/enUS.lua"))("SwagBag", SB)
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		GetMoney, GetMoneyString, GetCoinTextureString, C_CurrencyInfo, issecretvalue = nil, nil, nil, nil, nil
	end)

	-- Mutation: A.MoneyText skips GetMoneyString (goes straight to the plain fallback).
	it("Money and MoneyText use the client's money and coin text, and fall back without them", function()
		assert.is_nil(A.Money(), "no client function: unknown, not 0")
		assert.equal("12g", A.MoneyText(123456))
		GetMoney = function()
			return 123456
		end
		GetMoneyString = function(copper, separate)
			return "coins:" .. copper .. ":" .. tostring(separate)
		end
		assert.equal(123456, A.Money())
		issecretvalue = function(v)
			return v == 123456
		end
		assert.is_nil(A.Money(), "a secret amount is unknown, not 0")
		issecretvalue = nil
		assert.equal("coins:123456:true", A.MoneyText(123456))
	end)

	-- Mutation: in currencyEntry, drop the isSecret(info.quantity) check.
	it("currencies: the backpack list in order, one by ID, and the Currency tab list without headers", function()
		assert.same({}, A.BackpackCurrencies())
		assert.same({}, A.CurrencyList())
		local back = { { name = "Kej", quantity = 500, iconFileID = 1, currencyTypesID = 3056 },
			{ name = "Hidden", quantity = 777, iconFileID = 2, currencyTypesID = 9 } }
		local list = { { name = "Dungeon and Raid", isHeader = true },
			{ name = "Weathered Ethereal Crest", quantity = 45, iconFileID = 3, maxQuantity = 90 } }
		issecretvalue = function(v)
			return v == 777
		end
		C_CurrencyInfo = {
			GetBackpackCurrencyInfo = function(i)
				return back[i]
			end,
			GetCurrencyInfo = function(id)
				return id == 3107 and list[2] or nil
			end,
			GetCurrencyListSize = function()
				return #list
			end,
			GetCurrencyListInfo = function(i)
				return list[i]
			end,
			GetCurrencyListLink = function(i)
				return "currency:" .. (i == 2 and 3107 or 0)
			end,
			GetCurrencyIDFromLink = function(link)
				return tonumber(link:match("currency:(%d+)"))
			end,
		}
		local crest = { id = 3107, name = "Weathered Ethereal Crest", quantity = 45, icon = 3, max = 90 }
		assert.same({ { id = 3056, name = "Kej", quantity = 500, icon = 1 } }, A.BackpackCurrencies())
		assert.same(crest, A.CurrencyInfo(3107))
		assert.same({ crest }, A.CurrencyList())
	end)

	-- M3 (final review): a currency whose name the client keeps secret is left out, never shown or
	-- matched by name words. Mutation: in currencyEntry, drop the isSecret(info.name) check.
	it("a currency with a secret name is skipped in every list", function()
		local back = { { name = "Kej", quantity = 500, iconFileID = 1, currencyTypesID = 3056 },
			{ name = "Secret", quantity = 5, iconFileID = 2, currencyTypesID = 9 } }
		issecretvalue = function(v)
			return v == "Secret"
		end
		C_CurrencyInfo = {
			GetBackpackCurrencyInfo = function(i)
				return back[i]
			end,
			GetCurrencyInfo = function(id)
				return id == 9 and back[2] or nil
			end,
			GetCurrencyListSize = function()
				return 1
			end,
			GetCurrencyListInfo = function()
				return back[2]
			end,
			GetCurrencyListLink = function()
				return "currency:9"
			end,
			GetCurrencyIDFromLink = function()
				return 9
			end,
		}
		assert.same({ { id = 3056, name = "Kej", quantity = 500, icon = 1 } }, A.BackpackCurrencies())
		assert.is_nil(A.CurrencyInfo(9))
		assert.same({}, A.CurrencyList())
	end)
end)

-- Forever Stage A, Task 3: no crests and no keystone entry on WoW Forever, drawn, listed or offered.
describe("Footer on WoW Forever", function()
	local SB, A, F
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Crests.lua"
		SB = Loader.New(files, { flavor = "forever" })
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- the keystone in slot 5
		SB.Inventory.ScanAll()
		Fake.Install()
		local W = { frame = Fake.New("Frame", UIParent), size = { 495, 300 }, FOOTER = 6, open = true }
		function W.IsOpen() return W.open end
		function W.Resize() end
		SB.BagsWindow = W
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Footer.lua")
		F = SB.Footer
		F.TextWidth = function(fs) return 8 * #(fs.text or "") end
		A.money = 1234567
		A.backpack = { { id = 3056, name = "Kej", quantity = 500, icon = 1 } }
		A.currencies = { { id = 3107, name = "Weathered Ethereal Crest", quantity = 45, icon = 2 } }
		A.dungeons[503] = "Ara-Kara, City of Echoes"
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function shownIds()
		local out = {}
		for i, e in ipairs(F.Shown()) do
			out[i] = e.id
		end
		return out
	end

	-- Mutation: F.Items iterating F.Entries() instead of F.Shown().
	it("on Forever the footer shows no crests or keystone", function()
		local entries = {}
		for _, item in ipairs(F.Items()) do
			entries[#entries + 1] = item.entry
		end
		assert.same({ "gold", "currencies", "free" }, entries)
	end)

	-- Mutation: the slash listing walks F.Entries().
	it("on Forever /swagbag footer lists gold, currencies and free only", function()
		SB.Slash.Dispatch("footer")
		assert.same({ "Footer, left to right: Gold on, Backpack currencies on, Free slots on" }, A.Lines())
	end)

	-- Mutation: SetEntry without the Allows check (the command saves "-crests").
	it("on Forever /swagbag footer crests on answers left out", function()
		SB.Slash.Dispatch("footer crests off")
		SB.Slash.Dispatch("footer keystone up")
		assert.same({ SB.L.FOREVER_LEFT_OUT:format("Crests"), SB.L.FOREVER_LEFT_OUT:format("Keystone") }, A.Lines())
		assert.same({ false, "unavailable" }, { F.SetEntry("crests", true) })
		assert.same({ false, "unavailable" }, { F.Move("keystone", 1) })
		assert.equal("gold,currencies,crests,keystone,free", SB.Config.Get("bags.footer.entries"))
	end)

	-- Final review. Mutation: the verb check before the Allows check in /swagbag footer.
	it("on Forever /swagbag footer crests with no verb answers left out", function()
		SB.Slash.Dispatch("footer crests")
		SB.Slash.Dispatch("footer keystone maybe")
		assert.same({ SB.L.FOREVER_LEFT_OUT:format("Crests"), SB.L.FOREVER_LEFT_OUT:format("Keystone") }, A.Lines())
	end)

	-- Mutation: F.Move swapping with the next saved entry (a hidden one) instead of the next shown one.
	it("on Forever moving currencies down passes the hidden crests", function()
		SB.Slash.Dispatch("footer currencies down")
		assert.same({ "gold", "free", "currencies" }, shownIds())
		assert.same({ "Footer: Backpack currencies is now number 3." }, A.Lines())
		local saved = SB.Config.Get("bags.footer.entries")
		assert.truthy(saved:find("crests,keystone", 1, true), saved)
		assert.equal(5, #F.Entries(), "a hidden entry keeps its saved place")
	end)

	-- Mutation: footerRows walking F.Entries().
	it("on Forever Settings > Footer has three rows and the note", function()
		local L, labels = SB.L, {}
		for _, row in ipairs(SB.SettingsWindow.byId.footer.rows()) do
			labels[#labels + 1] = row.label
		end
		assert.same({ L.FOOTER_ROW:format(1, "Gold"), L.FOOTER_ROW:format(2, "Backpack currencies"),
			L.FOOTER_ROW:format(3, "Free slots"), L.FOOTER_NOTE }, labels)
	end)
end)
