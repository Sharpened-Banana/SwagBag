-- Week 12 (spec AC8.7, 6.3): focus modes of the user's own (Engine/Focus.lua): a name, a trigger (manual, or one of
-- the built-in signals) and a section set; switched on and off by hand when manual; merge and strict priority with
-- the built-ins; delete; stored modes read defensively; /swagbag mode on / off / list.
local Loader = dofile("spec/helpers/loader.lua")
local Env = dofile("spec/helpers/uienv.lua")

local ORDER = { "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
	"c_junk", "c_other", "free" }

describe("Focus modes of your own (week 12)", function()
	local SB, F, C, L, events
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		F, C, L = SB.Focus, SB.Config, SB.L
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason)
			events[#events + 1] = reason
		end)
	end)

	-- AC8.7. Mutation: in Focus.LoadCustom, the manual trigger `return Focus.manual[mid] == true` -> `return false`.
	it("AC8.7: a manual mode: made with a name, off until switched on; then its sections move up; off again", function()
		local id = F.CreateMode("Farming")
		assert.equal("m_farming", id)
		assert.same({ name = "Farming", trigger = "manual", n = 1 }, C.db.modes[id])
		assert.same({ true, "" }, { C.db.settings.focus.on[id], C.db.settings.focus.sections[id] },
			"its switch and sections are explicit from the start (This character only can copy them)")
		assert.truthy(F.SetSections(id, { "c_herbs", "c_ore" }))
		assert.same({}, F.Active())
		assert.same({ true, true }, { F.SetManual(id, true) })
		assert.same({ id }, F.Active())
		assert.equal("Farming", F.Label())
		assert.same({ "new", "c_herbs", "c_ore", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_junk",
			"c_other", "free" }, F.SectionOrder(ORDER))
		assert.same({ true, false }, { F.SetManual(id, true) }, "already on: nothing changes")
		F.SetManual(id, false)
		assert.same({}, F.Active())
		assert.equal(ORDER, F.SectionOrder(ORDER))
		assert.same({ "settings", "settings", "signal", "signal" }, events, "made, sections set, on, off")
	end)

	-- Mutation: in Focus.TRIGGERS, the pvp test `return s.instanceType == "pvp" or s.instanceType == "arena"` ->
	-- `return s.instanceType == "pvp"`.
	it("each built-in signal a mode can use switches it on exactly while that signal holds", function()
		local when = {
			mplus = { challengeMode = true }, dungeon = { instanceType = "party" }, raid = { instanceType = "raid" },
			delve = { delve = true }, pvp = { instanceType = "arena" }, fishing = { fishing = true },
			gathering = { gathering = true }, vendor = { merchantOpen = true }, auction = { auctionOpen = true },
			bank = { bankOpen = true },
		}
		local ids = {}
		for _, t in ipairs(F.TRIGGERS) do
			assert.truthy(rawget(L, t.name), t.name)
			if t.id ~= "manual" then
				ids[t.id] = F.CreateMode("Mine " .. t.id, t.id)
				assert.truthy(ids[t.id], t.id)
			end
		end
		for trig, signals in pairs(when) do
			F.signals = {}
			for k, v in pairs(signals) do
				F.signals[k] = v
			end
			F.Recompute("signal")
			local mine = {}
			for _, id in ipairs(F.Active()) do
				if F.IsCustom(id) then
					mine[#mine + 1] = id
				end
			end
			assert.same({ ids[trig] }, mine, trig)
		end
	end)

	-- AC8.4 with modes of your own. Mutation: in CLASS_RANK, `manual = 4` -> `manual = 0`.
	it("merge opens the union with the built-ins; strict priority: a manual mode you switched on decides first", function()
		local farm = F.CreateMode("Farm")
		local dump = F.CreateMode("Vendor dump", "vendor")
		F.SetSections(farm, { "c_herbs" })
		F.SetSections(dump, { "c_junk" })
		F.SetSignal("challengeMode", true)
		F.SetManual(farm, true)
		assert.same({ "mplus", farm }, F.Active())
		assert.equal("M+ + Farm", F.Label())
		C.Set("focus.resolve", "priority")
		assert.equal("Farm", F.Label())
		assert.same({ "c_herbs" }, F.Front())
		F.SetManual(farm, false)
		F.SetSignal("challengeMode", false)
		F.SetSignal("instanceType", "raid")
		F.SetSignal("merchantOpen", true)
		assert.equal("Raid", F.Label(), "activity beats location")
		F.SetSignal("instanceType", nil)
		assert.equal("AH/Vendor/Bank", F.Label(), "same class: the built-in first")
		C.Set("focus.resolve", "merge")
		assert.equal("AH/Vendor/Bank + Vendor dump", F.Label())
	end)

	-- Mutation: in Focus.Active, `(auto or m.class == "manual")` -> `auto`.
	it("with Switch by themselves off, only a manual mode you switched on applies; Pause stops it too", function()
		local farm = F.CreateMode("Farm")
		F.CreateMode("Vendor dump", "vendor")
		C.Set("focus.auto", false)
		F.SetSignal("merchantOpen", true)
		F.SetManual(farm, true)
		assert.same({ farm }, F.Active())
		F.Pause()
		assert.equal(L.FOCUS_PAUSED, F.Label())
		assert.is_nil(F.Front())
	end)

	-- Mutation: in Focus.CheckName, drop the `if low == SB.L[m.name]:lower() or low == m.id then` check.
	it("names: refused when empty, too long, a chat code, a built-in mode's name (any case), or another of yours", function()
		assert.same({ nil, "empty" }, { F.CreateMode("   ") })
		assert.same({ nil, "long" }, { F.CreateMode(string.rep("a", 25)) })
		assert.truthy(F.CreateMode(string.rep("a", 24)))
		assert.same({ nil, "code" }, { F.CreateMode("Red|cffff0000") })
		assert.same({ nil, "builtin" }, { F.CreateMode("raid") })
		assert.same({ nil, "builtin" }, { F.CreateMode("ah/vendor/bank") })
		assert.same({ nil, "builtin" }, { F.CreateMode("mplus") })
		local id = F.CreateMode("  Farming ")
		assert.equal("Farming", F.NameOf(id))
		assert.same({ nil, "taken" }, { F.CreateMode("FARMING") })
		assert.same({ nil, "trigger" }, { F.CreateMode("Other", "always") })
		assert.same({ false, "taken" }, { F.RenameMode(F.CreateMode("Second"), "farming") })
		assert.truthy(F.RenameMode(id, "farming"), "its own name in another case")
		assert.equal("farming", F.NameOf(id))
		assert.equal(id, F.FindMode(" FARMING "))
		assert.equal("raid", F.FindMode("Raid"))
	end)

	-- Mutation: in Focus.CreateMode, drop the `elseif #Focus.custom >= Focus.MAX_CUSTOM then return nil, "full"` check.
	it("at most ten modes of your own; ids follow the name and are never given twice", function()
		for i = 1, 10 do
			assert.truthy(F.CreateMode("Mode " .. i))
		end
		assert.same({ nil, "full" }, { F.CreateMode("Eleven") })
		assert.truthy(F.DeleteMode("m_mode_1"))
		assert.equal("m_mode_1_2", F.CreateMode("Mode 1"), "a deleted mode's id stays taken")
		F.DeleteMode("m_mode_2")
		assert.equal("m_mode", F.CreateMode("???"), "a name with no letters still gets an id")
	end)

	-- Mutation: in Focus.DeleteMode, drop `C.charDB.overrides["focus." .. kind .. "." .. id] = nil`.
	it("delete: the mode, its switch and its sections go (the account's and this character's); it is no longer on", function()
		local id = F.CreateMode("Farm")
		F.SetSections(id, { "c_herbs" })
		F.SetEnabled(id, true)
		C.CharOverride("focus.sections." .. id, true)
		F.SetSections(id, { "c_ore" })
		C.CharOverride("focus.on." .. id, true)
		F.SetManual(id, true)
		events = {}
		assert.truthy(F.DeleteMode(id))
		assert.equal(false, C.db.modes[id])
		assert.is_nil(C.db.settings.focus.sections[id])
		assert.is_nil(C.db.settings.focus.on[id])
		assert.is_nil(C.charDB.overrides["focus.sections." .. id])
		assert.is_nil(C.charDB.overrides["focus.on." .. id])
		assert.same({}, F.Active())
		assert.is_nil(F.Mode(id))
		assert.same({ "settings" }, events, "the open bags follow once")
		assert.same({ false, "unknown" }, { F.DeleteMode(id) })
		assert.same({ false, "unknown" }, { F.SetManual(id, true) })
	end)

	-- Mutation: in Categories.Delete, drop the `for mode in pairs(account) do` loop (a mode of yours would keep the id).
	it("deleting a category takes it out of your own modes' sections too, the account's and this character's", function()
		SB.Categories.Load()
		local cat = SB.Categories.Create("Pots", "potion")
		local id = F.CreateMode("Farm")
		local other = F.CreateMode("Other")
		F.SetSections(id, { cat, "c_herbs" })
		C.CharOverride("focus.sections." .. other, true)
		F.SetSections(other, { "c_ore", cat })
		assert.truthy(SB.Categories.Delete(cat))
		assert.same({ "c_herbs" }, F.Sections(id))
		assert.same({ "c_ore" }, F.Sections(other))
	end)

	-- Mutation: in manualCommand, drop the `if not ok then return L.MODE_MANUAL_AUTO:format(name)` branch.
	it("/swagbag mode on <name> and off: every form answers once; a mode that switches by itself is not switched here", function()
		local id = F.CreateMode("Farming")
		F.CreateMode("Vendor dump", "vendor")
		local function run(line)
			return select(2, SB.Slash.Run(line))
		end
		assert.equal(L.MODE_MANUAL_USAGE:format("Farming"), run("mode on"))
		assert.equal(L.MODE_MANUAL_ON:format("Farming"), run("mode on farming"))
		assert.truthy(F.ManualOn(id))
		assert.equal(L.MODE_MANUAL_ALREADY_ON:format("Farming"), run("mode on Farming"))
		assert.equal(L.MODE_MANUAL_AUTO:format("Vendor dump"), run("mode on vendor dump"))
		assert.equal(L.MODE_MANUAL_AUTO:format("Raid"), run("mode off raid"))
		assert.equal(L.MODE_MANUAL_UNKNOWN:format("fish", "Farming"), run("mode on fish"))
		assert.equal(L.MODE_MANUAL_ALL_OFF:format("Farming"), run("mode off"))
		assert.equal(L.MODE_MANUAL_NONE_ON, run("mode off"))
		assert.equal(L.MODE_MANUAL_ALREADY_OFF:format("Farming"), run("mode off farming"))
		F.Pause()
		assert.same({ L.MODE_MANUAL_ON:format("Farming"), L.MODE_MANUAL_PAUSED }, run("mode on farming"))
		assert.truthy(L.MODE_USAGE:find("on <your mode>", 1, true))
	end)

	-- Mutation: in Focus.ListLines, iterate `Focus.MODES` instead of `Focus.All()`.
	it("/swagbag mode list names your own modes after the built-ins, a manual one as such", function()
		local id = F.CreateMode("Farming")
		F.SetSections(id, { "c_herbs" })
		F.CreateMode("Vendor dump", "vendor")
		F.SetManual(id, true)
		local lines = F.ListLines()
		assert.equal(8, #lines)
		assert.equal(L.MODE_LIST_LINE:format("Farming (you switch it)", L.OVERLAY_ON, L.MODE_ACTIVE, "Herbs"), lines[7])
		assert.equal(L.MODE_LIST_LINE:format("Vendor dump", L.OVERLAY_ON, "", L.REPORT_NONE), lines[8])
	end)

	-- Mutation: in Focus.LoadCustom, drop `and cleanName(def.name) == def.name` (a damaged name would be shown).
	it("stored modes are read defensively: damaged entries skipped, an unknown trigger is manual, ten at most", function()
		local modes = {
			m_ok = { name = "Okay", trigger = "bank", n = 2 }, m_first = { name = "First", trigger = "weird", n = 1 },
			bad = { name = "No prefix", trigger = "bank" }, m_junk = "junk", m_code = { name = "a|Hlink", trigger = "bank" },
			m_gone = false, m_blank = { name = "", trigger = "manual" },
		}
		for i = 1, 12 do
			modes["m_extra" .. i] = { name = "Extra " .. i, n = 10 + i }
		end
		C.Init({ schemaVersion = 2, settings = {}, modes = modes }, nil)
		assert.equal(10, #F.custom)
		assert.same({ "m_first", "m_ok" }, { F.custom[1].id, F.custom[2].id })
		assert.equal("manual", F.custom[1].triggerId)
		assert.equal("location", F.custom[2].class)
		C.Init({ schemaVersion = 2, settings = {}, modes = "damaged" }, nil)
		assert.same({}, F.custom)
		C.Init({ schemaVersion = 2, settings = { focus = { auto = true } } }, nil)
		assert.same({}, F.custom, "a week-11 save: no modes of your own, nothing written")
		assert.is_nil(C.db.modes)
	end)

	-- Mutation: in ownMode, drop the `elseif SB.Config.readOnly then return "readonly"` branch.
	it("read-only settings: every writer refuses and changes nothing", function()
		local id = F.CreateMode("Farm")
		C.readOnly = true
		assert.same({ nil, "readonly" }, { F.CreateMode("Other") })
		assert.same({ false, "readonly" }, { F.RenameMode(id, "Other") })
		assert.same({ false, "readonly" }, { F.SetTrigger(id, "bank") })
		assert.same({ false, "readonly" }, { F.DeleteMode(id) })
		assert.same({ false, "readonly" }, { F.SetSections(id, { "c_ore" }) })
		C.readOnly = false
		assert.equal("Farm", F.NameOf(id))
		assert.equal("manual", F.Mode(id).triggerId)
	end)

	it("Recompute with the six built-ins and ten modes of your own stays well under 0.5 ms (spec 6.5)", function()
		for i = 1, 10 do
			F.CreateMode("Mode " .. i, i % 2 == 0 and "fishing" or "manual")
		end
		local t0 = os.clock()
		for i = 1, 1000 do
			F.SetSignal("fishing", i % 2 == 0)
		end
		local perCall = (os.clock() - t0) * 1000 / 1000
		assert.truthy(perCall < 0.5, ("%.3f ms per Recompute"):format(perCall))
	end)

	-- Y3. Mutation: in Focus.Active, `(manual or Focus.IsEnabled(m.id))` -> `Focus.IsEnabled(m.id)`.
	it("a manual mode ignores its On switch: switching it on always does something; a triggered one obeys it", function()
		local farm = F.CreateMode("Farm")
		local dump = F.CreateMode("Vendor dump", "vendor")
		F.SetEnabled(farm, false)
		F.SetEnabled(dump, false)
		F.SetSignal("merchantOpen", true)
		assert.same({ "market" }, F.Active(), "a triggered mode switched Off does not apply")
		assert.same({ true, true }, { F.SetManual(farm, true) })
		assert.same({ "market", farm }, F.Active(), "the manual one applies though its switch is Off")
	end)

	-- Y10. Mutation: in Focus.LoadCustom, drop `if not taken[low] then` (keep every stored mode).
	it("stored modes whose names are taken are skipped: a duplicate of yours, or a built-in's name or id, any case", function()
		C.Init({ schemaVersion = 2, settings = {}, modes = {
			m_a = { name = "Farm", trigger = "manual", n = 1 }, m_b = { name = "FARM", trigger = "bank", n = 2 },
			m_c = { name = "raid", trigger = "manual", n = 3 }, m_d = { name = "MPLUS", trigger = "manual", n = 4 },
			m_e = { name = "Other", trigger = "manual", n = 5 },
		} }, nil)
		assert.same({ "m_a", "m_e" }, { F.custom[1].id, F.custom[2].id })
		assert.equal(2, #F.custom)
	end)

	-- Mutation: in Categories.Delete, drop the `for path in pairs(Cfg.charDB.overrides) do` loop.
	it("deleting a category also cleans a character-only sections override of a mode that is gone from the account", function()
		SB.Categories.Load()
		local cat = SB.Categories.Create("Pots", "potion")
		C.charDB.overrides["focus.sections.m_gone"] = "c_ore," .. cat
		assert.truthy(SB.Categories.Delete(cat))
		assert.equal("c_ore", C.charDB.overrides["focus.sections.m_gone"])
	end)

	-- P2. Mutation: in Focus.SetManual, `Focus.Recompute("signal", true)` -> `Focus.Recompute("signal")`; and in
	-- manualCommand, drop the `Focus.manual[m.id] = nil` bulk clear in favour of SetManual per mode.
	it("with Mode changes in chat on, /swagbag mode on and a bulk off each say one line, and off re-stacks once", function()
		C.Set("focus.announce", true)
		local a, b = F.CreateMode("Farm"), F.CreateMode("Fish")
		local lines = {}
		SB.Print = function(text)
			lines[#lines + 1] = text
		end
		local function run(line)
			lines = {}
			local _, answer = SB.Slash.Run(line)
			return answer
		end
		assert.equal(L.MODE_MANUAL_ON:format("Farm"), run("mode on farm"))
		assert.same({}, lines, "no Focus mode: line on top of the answer")
		run("mode on fish")
		events = {}
		assert.equal(L.MODE_MANUAL_ALL_OFF:format("Farm, Fish"), run("mode off"))
		assert.same({}, lines)
		assert.same({ "signal" }, events, "one change, one re-stack")
		assert.same({}, F.Active())
		assert.truthy(a and b)
	end)
end)
