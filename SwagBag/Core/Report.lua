-- SwagBag report (spec 10.4): the text the user pastes into Claude Code.
-- Report.Build() is pure (reads module state through SB.*); UI/ReportBox.lua shows it.
local _, SB = ...

local Report = {}
SB.Report = Report

Report.ADDONS_ALWAYS = { "Auctionator", "Syndicator" }
Report.ADDONS_IF_LOADED = {
	"Baganator", "Bagnon", "AdiBags", "ArkInventory", "BetterBags", "Sorted", "ElvUI",
	"EllesmereUIBags", "EnhanceQoLBags", "TradeSkillMaster", "Pawn", "CanIMogIt",
}

local function serialize(v, out)
	if type(v) == "table" then
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		out[#out + 1] = "{"
		for _, k in ipairs(keys) do
			out[#out + 1] = tostring(k) .. "="
			serialize(v[k], out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = tostring(v)
	end
end

-- 8-hex-digit djb2 hash of a value, independent of table key order.
function Report.Hash(v)
	local parts = {}
	serialize(v, parts)
	local s = table.concat(parts)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 4294967296
	end
	return string.format("%08x", h)
end

local function addonList()
	local A, L = SB.Adapter, SB.L
	local out = {}
	for _, name in ipairs(Report.ADDONS_ALWAYS) do
		local loaded, version = A.AddOnState(name)
		out[#out + 1] = loaded and (name .. " " .. tostring(version or "?")) or L.REPORT_NOT_LOADED:format(name)
	end
	for _, name in ipairs(Report.ADDONS_IF_LOADED) do
		local loaded, version = A.AddOnState(name)
		if loaded then
			out[#out + 1] = name .. " " .. tostring(version or "?")
		end
	end
	return out
end

function Report.Build()
	local A, L = SB.Adapter, SB.L
	local build = A.BuildInfo()
	local lines = {}
	lines[#lines + 1] = L.REPORT_HEADER:format(SB.VERSION, tostring(build.version), tostring(build.build),
		tostring(build.locale), A.Date("%Y-%m-%d %H:%M"))
	lines[#lines + 1] = L.REPORT_SAFE:format(SB.SafeMode.Describe("bags"), SB.SafeMode.Describe("bank"))

	local failed = {}
	for _, r in ipairs(SB.Checks.Failed(SB.Checks.last or {})) do
		failed[#failed + 1] = r.name .. " (" .. r.detail .. ")"
	end
	lines[#lines + 1] = L.REPORT_FAILED_CHECKS:format(#failed > 0 and table.concat(failed, ", ") or L.REPORT_NONE)

	local errors = SB.ErrorTrap.Recent()
	lines[#lines + 1] = L.REPORT_ERRORS:format(SB.ErrorTrap.MAX)
	if #errors == 0 then
		lines[#lines + 1] = " " .. L.REPORT_NONE
	end
	for _, e in ipairs(errors) do
		lines[#lines + 1] = L.REPORT_ERROR_LINE:format(tostring(e.time), tostring(e.window), e.combat and L.REPORT_IN_COMBAT or "",
			tostring(e.label), tostring(e.message))
		for stackLine in tostring(e.stack or ""):gmatch("[^\n]+") do
			lines[#lines + 1] = "    " .. stackLine
		end
	end

	local blocked = {}
	for _, b in ipairs(SB.Blocked and SB.Blocked.list or {}) do
		blocked[#blocked + 1] = L.REPORT_BLOCKED_ITEM:format(b.func, b.time, b.combat and L.REPORT_IN_COMBAT or "")
	end
	lines[#lines + 1] = L.REPORT_BLOCKED:format(#blocked > 0 and table.concat(blocked, ", ") or L.REPORT_NONE)
	lines[#lines + 1] = L.REPORT_ADDONS:format(table.concat(addonList(), ", "))
	local db = SB.Config.db or {}
	local stats = SB.Buttons and SB.Buttons.stats or {}
	lines[#lines + 1] = L.REPORT_SETTINGS:format(Report.Hash(db.settings or {}), db.schemaVersion or 0, stats.count or 0,
		math.floor(stats.createMs or 0))
	if SB.Categories and SB.Categories.loaded then
		local total, edited, broken = SB.Categories.Counts()
		lines[#lines + 1] = L.REPORT_CATEGORIES:format(total, edited, #broken > 0 and table.concat(broken, ", ") or L.REPORT_NONE)
	end
	local bags = SB.BagsWindow and SB.BagsWindow.stats
	if bags and bags.lastLayoutMs then -- spec 9: first open <= 25 ms, warm open <= 10 ms
		lines[#lines + 1] = L.REPORT_LAYOUT:format(bags.lastLayoutMs, tostring(bags.lastLayoutReason))
	end
	local bank = SB.BankWindow
	if bank then
		lines[#lines + 1] = L.REPORT_BANK:format(bank.Mode(), tostring(bank.lastVisit or L.REPORT_NONE),
			bank.target and bank.GroupName(bank.target) or L.REPORT_NONE)
		local bankStats = bank.view and bank.view.stats
		if bankStats and bankStats.lastLayoutMs then -- spec 9: first bank open <= 80 ms
			lines[#lines + 1] = L.REPORT_BANK_LAYOUT:format(bankStats.lastLayoutMs, tostring(bankStats.lastLayoutReason))
		end
	end
	if SB.Snapshots and SB.Config.db then -- spec 8.4 budgets, check V10
		local chars, guilds = SB.Snapshots.Count()
		lines[#lines + 1] = L.REPORT_SNAPSHOTS:format(chars, guilds, math.floor(SB.Snapshots.Bytes() / 1024 + 0.5))
	end
	local guild = SB.GuildBankWindow
	if guild then
		lines[#lines + 1] = L.REPORT_GUILD:format(guild.Mode(), tostring(guild.lastVisit or L.REPORT_NONE))
	end
	return table.concat(lines, "\n")
end
