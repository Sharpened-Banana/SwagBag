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

	function m.GuildTooltip(owner, tab, slot)
		m.tooltip = { owner = owner, tab = tab, slot = slot }
	end

	function m.HideTooltip()
		m.tooltip = nil
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
			hasNoValue = false,
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
			sellPrice = 0,
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

	function m.IsWarboundUntilEquip(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.isWUE == true
	end

	function m.HasUpgradeTrack(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.upgrade == true
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
