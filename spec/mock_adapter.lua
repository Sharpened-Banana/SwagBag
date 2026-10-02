-- Mock Adapter for unit tests. Loads the REAL SwagBag/Core/Adapter.lua for
-- isSecret and Resolve load-time code, then replaces every function that
-- would call WoW with an in-memory fake.
local M = {}

function M.New(SB)
	local chunk = assert(loadfile("SwagBag/Core/Adapter.lua"))
	chunk("SwagBag", SB)
	local m = SB.Adapter

	m.clock = 0 -- seconds, advanced only by m.Advance
	m.timers = {}
	m.timerSeq = 0
	m.printed = {}
	m.combat = false
	m.globals = {} -- what Resolve() can see
	m.addons = {} -- name -> version string (loaded) or false (installed, not loaded)

	function m.ChatPrint(text)
		m.printed[#m.printed + 1] = text
	end

	-- Printed lines with the "SwagBag: " chat prefix removed.
	function m.Lines()
		local out = {}
		for i, text in ipairs(m.printed) do
			out[i] = (text:gsub("^|cff33ff99SwagBag|r: ", ""))
		end
		return out
	end

	function m.Now()
		return m.clock
	end

	function m.ProfileMs()
		return m.clock * 1000
	end

	function m.After(seconds, fn)
		m.timerSeq = m.timerSeq + 1
		m.timers[#m.timers + 1] = { at = m.clock + seconds, seq = m.timerSeq, fn = fn }
	end

	-- Move the clock forward, running due timers in time order (ties: creation order).
	function m.Advance(seconds)
		local target = m.clock + seconds
		while true do
			local bestIndex, best
			for i, t in ipairs(m.timers) do
				if t.at <= target and (best == nil or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then
					bestIndex, best = i, t
				end
			end
			if not best then
				break
			end
			table.remove(m.timers, bestIndex)
			m.clock = best.at
			best.fn()
		end
		m.clock = target
	end

	function m.InCombat()
		return m.combat
	end

	function m.IsSecret()
		return false
	end

	function m.Stack()
		return "[stack]"
	end

	local DATE_PARTS = { Y = "2026", m = "10", d = "01", H = "21", M = "03", S = "07" }
	function m.Date(fmt)
		return (fmt:gsub("%%(%a)", DATE_PARTS))
	end

	m.epoch = 1791000000 -- seconds since the epoch at clock 0
	m.charKey = "Swagger-Argent Dawn"
	function m.Time()
		return m.epoch + math.floor(m.clock)
	end

	function m.CharKey()
		return m.charKey
	end

	function m.CharInfo()
		return { class = "MAGE", level = 90 }
	end

	function m.BuildInfo()
		return { version = "12.1.0", build = "69933", toc = 120100, locale = "enUS" }
	end

	function m.Resolve(path)
		local cur = m.globals
		for part in path:gmatch("[^%.]+") do
			if type(cur) ~= "table" then
				return nil
			end
			cur = cur[part]
			if cur == nil then
				return nil
			end
		end
		return cur
	end

	function m.AddOnState(name)
		local v = m.addons[name]
		if v == nil or v == false then
			return false, nil
		end
		return true, v
	end

	-- Cursor and sort: set m.cursor = { itemID, link } to simulate a picked-up item.
	m.cursor = nil
	m.cleared = 0
	m.sorts = 0
	function m.CursorItem()
		if m.cursor then
			return m.cursor.itemID, m.cursor.link
		end
		return nil
	end

	function m.ClearCursor()
		m.cursor = nil
		m.cleared = m.cleared + 1
	end

	function m.SortBags()
		m.sorts = m.sorts + 1
		return true
	end

	m.bankSorts = {}
	function m.SortBank(kind)
		m.bankSorts[#m.bankSorts + 1] = kind
		return true
	end

	-- Blizzard frames by global name, and Blizzard's selected bank type (week 3).
	m.frames = {}
	m.activeBankType = nil
	function m.Frame(name)
		return m.frames[name]
	end

	function m.ActiveBankType()
		return m.activeBankType
	end

	-- Guild bank: m.guild.tabs = { { tab, name, viewable, canDeposit, withdrawals } },
	-- m.guild.slots[tab][slot] = { itemID, count, link?, isLocked? }; calls are recorded.
	m.guild = { tabs = {}, slots = {}, current = 1, key = "Tidewatch-Argent Dawn", queried = {}, withdrawn = {},
		picked = {} }
	m.modified = false
	m.tooltip = nil
	m.guildTabFrames = {}
	function m.GuildTabs()
		local out = {}
		for i, t in ipairs(m.guild.tabs) do
			out[i] = { tab = t.tab, name = t.name, icon = t.icon, viewable = t.viewable ~= false,
				canDeposit = t.canDeposit ~= false, withdrawals = t.withdrawals or -1 }
		end
		return out
	end

	function m.GuildSlot(tab, slot)
		local s = m.guild.slots[tab] and m.guild.slots[tab][slot]
		if not s then
			return nil
		end
		local it = m.items[s.itemID] or {}
		return { itemID = s.itemID, link = s.link or ("item:" .. s.itemID), count = s.count or 1, icon = s.itemID,
			quality = it.quality, isLocked = s.isLocked == true }
	end

	function m.GuildQuery(tab)
		m.guild.queried[#m.guild.queried + 1] = tab
	end

	function m.GuildCurrentTab()
		return m.guild.current
	end

	function m.GuildWithdraw(tab, slot)
		m.guild.withdrawn[#m.guild.withdrawn + 1] = { tab, slot }
		return true
	end

	function m.GuildPickup(tab, slot)
		m.guild.picked[#m.guild.picked + 1] = { tab, slot }
		return true
	end

	function m.GuildKey()
		return m.guild.key
	end

	-- nil (the client can't say) unless a test sets m.guild.inGuild to true or false
	function m.IsInGuild()
		return m.guild.inGuild
	end

	function m.GuildTooltip(owner, tab, slot)
		m.tooltip = { owner = owner, tab = tab, slot = slot }
	end

	function m.LinkTooltip(owner, link)
		m.tooltip = { owner = owner, link = link }
	end

	function m.HideTooltip()
		m.tooltip = nil
	end

	-- The list view's row tooltips: m.slotTip = { owner, bag, slot, hint }.
	function m.SlotTooltip(owner, bag, slot, hint)
		m.slotTip = { owner = owner, bag = bag, slot = slot, hint = hint }
	end

	-- A row's name colour: m.qualityColors[quality] = { r, g, b } (none by default, like a client without it).
	m.qualityColors = {}
	function m.QualityColor(quality)
		local c = m.qualityColors[quality]
		if c then
			return c[1], c[2], c[3]
		end
		return nil
	end

	function m.ModifiedClick()
		return m.modified
	end

	function m.IsGuildBanker(interactionType)
		return interactionType == "GuildBanker"
	end

	function m.GuildTabFrames()
		return m.guildTabFrames
	end

	-- Auctionator: m.auctionator = { prices = { [link] = copper } } while "loaded"; nil otherwise.
	m.auctionator = nil
	m.auctionatorCalls = 0
	function m.AuctionatorAvailable()
		return m.auctionator ~= nil
	end

	function m.AuctionatorPrice(link)
		m.auctionatorCalls = m.auctionatorCalls + 1
		if m.auctionator and m.auctionator.fail then
			error("Auctionator broke")
		end
		return m.auctionator and m.auctionator.prices[link] or nil
	end

	function m.AuctionatorOnUpdate(cb)
		m.auctionatorCallback = cb
	end

	-- Focus signals (week 4): m.instance = { instanceType, difficultyID }; m.challengeMode true |
	-- false | nil (no API); m.delve; m.spellNames[spellID] = lower-case name; m.fishingLoot;
	-- m.lootSource ("GameObject", "Creature", ... or nil); m.professions ({ herb, ore, skin } or nil).
	-- m.spellNameCalls counts SpellName lookups per spellID.
	m.instance, m.challengeMode, m.delve, m.spellNames = {}, nil, false, {}
	m.fishingLoot, m.lootSource, m.professions, m.spellNameCalls = false, nil, nil, {}
	function m.InstanceInfo()
		return { instanceType = m.instance.instanceType, difficultyID = m.instance.difficultyID }
	end
	function m.ChallengeModeActive()
		return m.challengeMode
	end
	m.restrictionKind = 2 -- the payload value that means ChallengeMode
	function m.IsChallengeModeRestriction(kind)
		return kind == m.restrictionKind
	end
	function m.InDelve()
		return m.delve == true
	end
	function m.SpellName(spellID)
		m.spellNameCalls[spellID] = (m.spellNameCalls[spellID] or 0) + 1
		return m.spellNames[spellID]
	end
	function m.IsFishingLoot()
		return m.fishingLoot == true
	end
	function m.LootSourceType()
		return m.lootSource
	end
	function m.GatheringProfessions()
		return m.professions
	end

	-- On-screen lines (the consumables warning): m.screen = { text, ... }
	m.screen = {}
	function m.ScreenMessage(text)
		m.screen[#m.screen + 1] = text
	end

	M.AddContainers(m)
	return m
end

-- Fake bags and items. Fixture helpers:
--   m.AddItem(itemID, { name, classID, subclassID, equipLoc, quality, ilvl, reqLevel,
--                       maxStack, bind, isCraftingReagent, usable, toy, pending })
--   m.SetBagSize(bag, n)
--   m.Put(bag, slot, itemID, count, { link, isLocked, isBound, isWUE, onCooldown,
--                                    inSet, upgrade, quest, ilvl })
--   m.Clear(bag, slot)
function M.AddContainers(m)
	m.bagIDs = { bags = { 0, 1, 2, 3, 4, 5 }, bank = {}, warband = {} }
	m.sizes = {}
	m.slots = {}
	m.items = {}
	m.loadRequests = {}

	function m.AddItem(itemID, def)
		m.items[itemID] = def
	end

	function m.SetBagSize(bag, n)
		m.sizes[bag] = n
		m.slots[bag] = m.slots[bag] or {}
	end

	function m.Put(bag, slot, itemID, count, extra)
		local s = extra or {}
		s.itemID = itemID
		s.count = count or 1
		if s.upgrade then
			m.upgradeLinks[s.link or ("item:" .. itemID)] = true
		end
		m.slots[bag] = m.slots[bag] or {}
		m.slots[bag][slot] = s
	end

	function m.Clear(bag, slot)
		if m.slots[bag] then
			m.slots[bag][slot] = nil
		end
	end

	local function slotOf(bag, slot)
		return m.slots[bag] and m.slots[bag][slot]
	end

	local function itemOf(itemID)
		return m.items[itemID] or {}
	end

	function m.GetBagIDs(kind)
		local out = {}
		for i, id in ipairs(m.bagIDs[kind] or {}) do
			out[i] = id
		end
		return out
	end

	function m.NumSlots(bag)
		return m.sizes[bag] or 0
	end

	function m.GetSlot(bag, slot)
		local s = slotOf(bag, slot)
		if not s then
			return nil
		end
		local it = itemOf(s.itemID)
		return {
			bag = bag,
			slot = slot,
			itemID = s.itemID,
			link = s.link or ("item:" .. s.itemID),
			count = s.count,
			quality = it.quality,
			icon = s.itemID,
			isLocked = s.isLocked == true,
			isBound = s.isBound == true,
			name = (not it.pending) and it.name or nil,
			hasNoValue = s.hasNoValue == true,
		}
	end

	function m.GetItemInstant(itemID)
		local it = m.items[itemID]
		if not it then
			return nil
		end
		return { itemID = itemID, equipLoc = it.equipLoc or "", icon = itemID, classID = it.classID, subclassID = it.subclassID }
	end

	function m.GetItemInfo(itemID)
		local it = m.items[itemID]
		if not it or it.pending then
			return nil
		end
		return {
			name = it.name,
			quality = it.quality,
			baseIlvl = it.ilvl,
			reqLevel = it.reqLevel or 0,
			maxStack = it.maxStack or 1,
			sellPrice = it.sellPrice or 0,
			bind = it.bind or "none",
			expansionID = 0,
			isCraftingReagent = it.isCraftingReagent == true,
		}
	end

	function m.GetIlvl(bag, slot)
		local s = slotOf(bag, slot)
		if not s then
			return nil
		end
		local it = itemOf(s.itemID)
		if it.pending then
			return nil
		end
		return s.ilvl or it.ilvl
	end

	-- Links in fixtures carry the itemID ("item:<id>..."); the item level is the fixture's.
	function m.GetLinkIlvl(link)
		local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
		local it = id and m.items[id]
		return it and not it.pending and it.ilvl or nil
	end

	-- Overlays: m.tracks[link] = { track, level, max }; m.dungeons[mapID] = name;
	-- m.equipped[invSlot] = { ilvl, equipLoc }; m.cannotUse[itemID] = true; m.pawn[bag .. ":" .. slot] = bool.
	m.tracks, m.dungeons, m.equipped, m.cannotUse, m.pawn = {}, {}, {}, {}, nil
	-- m.upgradeLinks[link] = true: the item has an upgrade track but no readable one. Put(..., { upgrade = true })
	-- sets it for that slot's link, so give such a slot its own link when another slot holds the same item.
	m.upgradeLinks = {}
	function m.UpgradeInfo(link)
		return m.tracks[link], m.tracks[link] ~= nil or m.upgradeLinks[link] == true
	end

	function m.DungeonName(mapID)
		return m.dungeons[mapID]
	end

	function m.EquippedItems()
		local out = {}
		for slot, e in pairs(m.equipped) do
			out[slot] = { ilvl = e.ilvl, equipLoc = e.equipLoc, unknown = e.unknown }
		end
		return out
	end

	function m.CanUse(itemID)
		return not m.cannotUse[itemID]
	end

	-- m.avgIlvl: the average equipped item level (nil = the client gives none).
	function m.EquippedItemLevel()
		return m.avgIlvl
	end

	-- The bags footer (W4-14): m.money in copper; m.backpack (Blizzard's "Show on backpack" list) and
	-- m.currencies (the Currency tab list) = { { id, name, quantity, icon } }. MoneyText is plain "12g".
	m.money, m.backpack, m.currencies = 0, {}, {}
	local function copyList(list)
		local out = {}
		for i, c in ipairs(list) do
			out[i] = { id = c.id, name = c.name, quantity = c.quantity, icon = c.icon }
		end
		return out
	end

	function m.Money()
		return m.money
	end

	function m.MoneyText(copper)
		return tostring(math.floor(copper / 10000)) .. "g"
	end

	function m.BackpackCurrencies()
		return copyList(m.backpack)
	end

	function m.CurrencyList()
		return copyList(m.currencies)
	end

	function m.CurrencyInfo(id)
		for _, list in ipairs({ m.backpack, m.currencies }) do
			for _, c in ipairs(copyList(list)) do
				if c.id == id then
					return c
				end
			end
		end
		return nil
	end

	function m.HasPawn()
		return m.pawn ~= nil
	end

	-- m.pawn[bag .. ":" .. slot] = true | false; a slot with no entry is Pawn's "no opinion" (nil,
	-- ruling W4-15: the item-level rule decides it).
	function m.PawnUpgrade(bag, slot)
		if m.pawn == nil then
			return nil
		end
		local v = m.pawn[bag .. ":" .. slot]
		if v == nil then
			return nil
		end
		return v == true
	end

	-- Blizzard's new-item flag (ruling W4-15): m.newCleared = { "bag:slot" } per slot cleared,
	-- m.newClearedBags = { { bag IDs } } per ClearNewItems call.
	m.newCleared, m.newClearedBags = {}, {}
	function m.ClearNewItem(bag, slot)
		m.newCleared[#m.newCleared + 1] = bag .. ":" .. slot
	end

	function m.ClearNewItems(bagIDs)
		m.newClearedBags[#m.newClearedBags + 1] = { unpack(bagIDs) }
	end

	function m.IsWarboundUntilEquip(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.isWUE == true
	end

	function m.IsOnCooldown(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.onCooldown == true
	end

	function m.InEquipmentSet(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.inSet == true
	end

	function m.IsUsable(itemID)
		return itemOf(itemID).usable == true
	end

	function m.IsToy(itemID)
		return itemOf(itemID).toy == true
	end

	function m.IsQuestItem(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.quest == true
	end

	function m.RequestLoad(itemID)
		m.loadRequests[#m.loadRequests + 1] = itemID
	end
end

return M
