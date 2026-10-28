-- SwagBag alt data provider "Syndicator" (spec 3.3, v1.2 pulled forward). Optional (P4): it answers
-- only while Syndicator is loaded and ready (Adapter.SyndicatorAPI, the only code that names
-- Syndicator's globals); otherwise SwagBag's own snapshots ("Own", Engine/AltData.lua) answer, and
-- nothing else changes. While it answers it REPLACES Own for the character list, every character's
-- bags and bank, the warband bank and the tooltip counts (Syndicator also knows characters SwagBag
-- never saw), and ADDS what only Syndicator tracks: mail, equipped, auctions and void storage
-- counts. Guild banks stay SwagBag's own (D11): container "guild" answers nil here, so Own answers,
-- and counts() appends Own's guild entries for any guild Syndicator did not report (F18).
-- SwagBag keeps saving its own snapshots either way, so removing Syndicator loses nothing.
-- It also answers wealth (every character's gold and currencies) while it has saved money.
-- Slot data read (names only): bags[i] (bag i - 1), bankTabs[i].slots (bag 5 + i), the warband's
-- bank[i].slots (bag 11 + i); a slot is { itemLink, itemCount }. Details: character, realm,
-- realmNormalized, className, show.inventory (false: the user hid the character in Syndicator).
-- Wealth reads money and currencies ({ [currencyID] = quantity }) from the character data itself, not details.
-- Everything it reads is checked for secret values (never expected: it is saved data). An error
-- here is AltData's to count (three switch the provider off) and trap under "none".
local _, SB = ...

local AD = SB.AltData
local P = { name = "Syndicator", priority = 10, DEBOUNCE = 0.5 }
SB.SyndicatorProvider = P

local function api()
	return SB.Adapter.SyndicatorAPI()
end

local function secret(v)
	return SB.Adapter.IsSecret(v)
end

local function n(v)
	return type(v) == "number" and not secret(v) and v or 0
end

local function str(v)
	return type(v) == "string" and not secret(v) and v or nil
end

local function shown(data)
	local d = type(data) == "table" and not secret(data) and data.details
	if type(d) ~= "table" then
		return nil
	end
	if type(d.show) == "table" and d.show.inventory == false then
		return nil
	end
	return d
end

function P.available()
	return api() ~= nil
end

-- canonical key -> Syndicator's own key, built once and dropped on SB_ALTDATA_CHANGED (invalidate);
-- a key it does not hold is looked up again once, so a character Syndicator learns later is found.
local names, missed
function P.invalidate()
	names, missed = nil, nil
end

local function fullName(S, key)
	if names and names[key] then
		return names[key]
	end
	if names and missed[key] then
		return nil -- rebuilt once and still not there: no rebuild per call for a key Syndicator never has
	end
	names, missed = {}, names and missed or {}
	for _, full in ipairs(S.GetAllCharacters() or {}) do
		if str(full) then
			names[AD.Canon(full)] = full
		end
	end
	if not names[key] then
		missed[key] = true
	end
	return names[key]
end

local function byCurrent(a, b)
	if a.current ~= b.current then
		return a.current
	end
	return a.key < b.key
end

-- Every shown character as { key, name, realm, class, current, data = its character data }, current first.
local function shownList(S)
	local me, list = AD.Canon(SB.Adapter.CharKey()), {}
	local cur = SB.Adapter.SyndicatorCurrentKey() -- a regional key ("Name-PvE") is not Name-Realm (F17)
	for _, full in ipairs(S.GetAllCharacters() or {}) do
		local data = str(full) and S.GetByCharacterFullName(full)
		local d = data and shown(data)
		if d then
			local key = AD.Canon(full)
			list[#list + 1] = { key = key, name = str(d.character) or full:match("^[^%-]+"),
				realm = str(d.realm) or str(d.realmNormalized), class = str(d.className),
				current = full == cur or key == me, data = data }
		end
	end
	table.sort(list, byCurrent)
	return list
end

function P.characters()
	local S = api()
	if not S then
		return nil
	end
	local list = shownList(S)
	for _, e in ipairs(list) do
		e.data = nil
	end
	return list
end

-- Gold and currencies of every shown character that has either (Own's rule: a character with neither is
-- left out, never shown as 0; money is nil when not a number). nil when none qualifies (an older Syndicator
-- that does not save them), so Own answers. Currencies keep numbers only.
function P.wealth()
	local S = api()
	if not S then
		return nil
	end
	local out = {}
	for _, e in ipairs(shownList(S)) do
		local d = e.data
		e.data = nil
		e.money = type(d.money) == "number" and not secret(d.money) and d.money or nil
		e.currencies = {}
		if type(d.currencies) == "table" and not secret(d.currencies) then
			for id, q in pairs(d.currencies) do
				if type(id) == "number" and type(q) == "number" and not secret(q) then
					e.currencies[id] = q
				end
			end
		end
		if e.money or next(e.currencies) then
			out[#out + 1] = e
		end
	end
	return #out > 0 and out or nil
end

-- One Syndicator container (a list of slots) as { size, slots = { [slot] = { link, count } } }.
local function container(slotList)
	local out = { size = 0, slots = {} }
	if type(slotList) ~= "table" or secret(slotList) then
		return out
	end
	for slot, s in pairs(slotList) do
		if type(slot) == "number" then
			local link = type(s) == "table" and not secret(s) and str(s.itemLink)
			if link then
				out.slots[slot] = { link = link, count = n(s.itemCount) > 0 and s.itemCount or 1 }
				out.size = math.max(out.size, slot)
			elseif type(s) == "table" then
				out.size = math.max(out.size, slot)
			end
		end
	end
	return out
end

-- kind "bags" | "bank" | "warband"; "guild" is SwagBag's own (nil here). nil when Syndicator has
-- nothing for it, so Own answers.
function P.container(key, kind)
	local S = api()
	if not S or kind == "guild" then
		return nil
	end
	local out, any = { containers = {} }, false
	local function add(bag, list)
		local c = container(list)
		if c.size > 0 then
			out.containers[bag] = c
			any = true
		end
	end
	if kind == "warband" then
		local w = S.GetWarband(1)
		for i, tab in ipairs(type(w) == "table" and type(w.bank) == "table" and w.bank or {}) do
			add(11 + i, type(tab) == "table" and tab.slots)
		end
		return any and out or nil
	end
	local full = fullName(S, key)
	local data = full and S.GetByCharacterFullName(full)
	if not shown(data) then
		return nil
	end
	if kind == "bags" then
		for i, list in ipairs(type(data.bags) == "table" and data.bags or {}) do
			add(i - 1, list)
		end
	elseif kind == "bank" then
		for i, tab in ipairs(type(data.bankTabs) == "table" and data.bankTabs or {}) do
			add(5 + i, type(tab) == "table" and tab.slots)
		end
	end
	return any and out or nil
end

function P.counts(itemID)
	local S = api()
	if not S or itemID == AD.PET_CAGE then -- v284 does not count caged pets
		return nil
	end
	local info = S.GetInventoryInfoByItemID(itemID, false, false)
	if type(info) ~= "table" or secret(info) then
		return nil
	end
	local me, cur = AD.Canon(SB.Adapter.CharKey()), SB.Adapter.SyndicatorCurrentKey()
	cur = cur and AD.Canon(cur)
	local out = { chars = {}, warband = n(type(info.warband) == "table" and info.warband[1]), guilds = {} }
	local seen = {}
	for _, c in ipairs(type(info.characters) == "table" and info.characters or {}) do
		if type(c) == "table" and str(c.character) then
			local key = AD.Canon(c.character .. "-" .. (str(c.realmNormalized) or ""))
			local e = { key = key, name = c.character, class = str(c.className), current = key == me or key == cur, bags = n(c.bags),
				bank = n(c.bank), mail = n(c.mail), equipped = n(c.equipped), auctions = n(c.auctions), void = n(c.void) }
			if e.bags + e.bank + e.mail + e.equipped + e.auctions + e.void > 0 then
				out.chars[#out.chars + 1] = e
			end
		end
	end
	for _, g in ipairs(type(info.guilds) == "table" and info.guilds or {}) do
		if type(g) == "table" and str(g.guild) and n(g.bank) > 0 then
			local key = AD.Canon(g.guild .. "-" .. (str(g.realmNormalized) or ""))
			seen[key] = true
			out.guilds[#out.guilds + 1] = { key = key, name = g.guild, count = g.bank }
		end
	end
	-- Once set up, v284 answers an unknown item with { characters = {}, guilds = {}, warband = { 0 } }, never
	-- nil: nothing counted means Syndicator has nothing, so Own answers with its own data.
	if #out.chars == 0 and out.warband == 0 and #out.guilds == 0 then
		return nil
	end
	-- Guild banks stay SwagBag's own (D11): add the guilds only SwagBag has seen (F18).
	for _, g in ipairs(AD.OwnGuildCounts(itemID)) do
		local key = AD.Canon(g.key)
		if not seen[key] then
			out.guilds[#out.guilds + 1] = { key = key, name = g.name, count = g.count }
		end
	end
	table.sort(out.chars, byCurrent)
	table.sort(out.guilds, function(a, b)
		return a.key < b.key
	end)
	return out
end

AD.RegisterProvider(P)

-- Syndicator's data changed: one SB_ALTDATA_CHANGED after the burst (AltData drops the provider's
-- cache and moves its generation; the alt viewer and tooltip memos follow it). The callback is
-- Syndicator's call into SwagBag, so it runs under ErrorTrap ("none": record only, never Safe Mode).
local function announce()
	SB.Debounce("altdata.changed", P.DEBOUNCE, function()
		SB.Emit("SB_ALTDATA_CHANGED", "Syndicator")
	end, "none")
end

-- Register Syndicator's callbacks once (P.hooked): at login, or when Syndicator loads later in the
-- session (week 8: another addon loads it, or it is enabled and loaded without a /reload). A late hook
-- also announces at once: the answering provider may have switched, so the tooltip counts and an open
-- alt viewer follow without waiting for Syndicator's next update.
P.hooked = false
function P.Hook(late)
	if P.hooked then
		return true
	end
	P.hooked = SB.Adapter.SyndicatorOnUpdate(SB.ErrorTrap.Guard("altdata.syndicator", announce, "none")) == true
	if P.hooked and late then
		announce()
	end
	return P.hooked
end

SB.On("SB_LOGIN", function()
	P.Hook(false)
end, "none")

-- If Syndicator's registry is not ready at its own ADDON_LOADED, one more try a moment later (once only).
P.RETRY = 1
P.retried = false
SB.On("ADDON_LOADED", function(_, name)
	if SB.Adapter.IsSyndicatorAddon(name) and not P.Hook(true) and not P.retried then
		P.retried = true
		SB.Debounce("syndicator.hook", P.RETRY, function()
			P.Hook(true)
		end, "none")
	end
end, "none")
