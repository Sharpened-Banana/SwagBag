-- Focus modes engine (spec 6): signals -> active modes -> open sections; merge and strict
-- priority; peek, pin and close; pause; labels; section sets from the settings.
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua",
	"SwagBag/Engine/Focus.lua",
}

local ORDER = { "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
	"c_leathercloth", "c_fish", "c_cooking", "c_tools", "c_junk", "c_other", "free" }

describe("Focus", function()
	local SB, F, events
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		SB.Config.Set("focus.auto", true) -- focus modes switch by themselves only when asked (0.14.3)
		-- These tests pin the "collapse" style (week 4's behaviour, now the alternative); the default
		-- "front" style has its own block below. Set before the listener, so no event is counted.
		SB.Config.Set("focus.style", "collapse")
		F = SB.Focus
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason)
			events[#events + 1] = reason
		end)
	end)

	local function openIds()
		local view = F.CollapsedView({})
		local out = {}
		for _, id in ipairs(ORDER) do
			if view[id] ~= true then
				out[#out + 1] = id
			end
		end
		return out
	end

	it("no signal: no mode, nothing collapsed by Focus, the user's own set is used as it is", function()
		local user = { c_gear = true }
		assert.same({}, F.Active())
		assert.equal(user, F.CollapsedView(user))
		assert.is_nil(F.Label())
		assert.same({}, events)
	end)

	-- Mutation: return false from the mplus trigger's challengeMode branch.
	it("M+ (AC8.2): a running key opens Consumables, Keystone & Crests, Gear and New, nothing else", function()
		assert.truthy(F.SetSignal("challengeMode", true))
		assert.same({ "mplus" }, F.Active())
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear" }, openIds())
		assert.equal("M+", F.Label())
		assert.same({ "signal" }, events)
	end)

	it("M+ fallback (V5): a Mythic party dungeon with a keystone in the bags, before the key starts", function()
		F.SetSignal("instanceType", "party")
		F.SetSignal("mythic", true)
		assert.same({}, F.Active(), "no keystone yet")
		F.SetSignal("keystone", true)
		assert.same({ "mplus" }, F.Active())
		F.SetSignal("mythic", false)
		assert.same({}, F.Active(), "heroic dungeon")
	end)

	it("leaving restores the user's own state (AC8.2)", function()
		local user = { c_junk = true }
		F.SetSignal("challengeMode", true)
		F.SetSignal("challengeMode", false)
		assert.equal(user, F.CollapsedView(user))
		assert.same({ "signal", "signal" }, events)
	end)

	it("raid, delves and fishing open their own sets", function()
		F.SetSignal("instanceType", "raid")
		assert.same({ "new", "c_consumables", "c_gear" }, openIds())
		F.SetSignal("instanceType", "scenario")
		F.SetSignal("delve", true)
		assert.same({ "delves" }, F.Active())
		assert.same({ "new", "c_consumables", "c_gear" }, openIds())
		F.SetSignal("delve", false)
		F.SetSignal("fishing", true)
		assert.same({ "new", "c_fish", "c_cooking" }, openIds())
	end)

	-- Mutation: drop the professions filter in Focus.Sections.
	it("gathering opens only the materials of the character's gathering professions, plus Tools", function()
		F.SetSignal("gathering", true)
		assert.same({ "new", "c_herbs", "c_ore", "c_leathercloth", "c_tools" }, openIds(), "professions unknown")
		assert.truthy(F.SetSignal("professions", { herb = true }), "a profession change is a view change")
		assert.falsy(F.Recompute(), "already recomputed by SetSignal")
		assert.same({ "new", "c_herbs", "c_tools" }, openIds())
	end)

	-- Mutation: drop the view part of the change key in Recompute (viewKeyOf returns "").
	it("W4-8: market active, bankOpen true changes the view: emits once, keeps peeks and pins", function()
		F.SetSignal("merchantOpen", true)
		F.HeaderClick("c_gear", true)
		events = {}
		assert.truthy(F.SetSignal("bankOpen", true))
		assert.same({ "signal" }, events)
		assert.falsy(F.Applies())
		assert.equal("peek", F.OverrideOf("c_gear"))
		assert.truthy(F.SetSignal("bankOpen", false))
		assert.truthy(F.Applies())
		assert.equal("peek", F.OverrideOf("c_gear"))
	end)

	it("W4-8: gathering active, a professions change emits and keeps pins", function()
		F.SetSignal("gathering", true)
		F.Pin("c_junk")
		events = {}
		assert.truthy(F.SetSignal("professions", { ore = true }))
		assert.same({ "signal" }, events)
		assert.equal("pin", F.OverrideOf("c_junk"))
		assert.same({ "new", "c_ore", "c_tools", "c_junk" }, openIds())
	end)

	-- Mutation: remove the invalidate in Resume.
	it("Resume drops the cached view: Applies() is true again", function()
		F.SetSignal("challengeMode", true)
		F.Pause()
		assert.is_nil(F.Expanded())
		F.Resume()
		assert.truthy(F.Applies())
	end)

	-- Mutation: drop the SB_CONFIG_CHANGED listener in Focus.lua.
	it("a character override or a reset of a focus setting updates the view (W4-10)", function()
		F.SetSignal("challengeMode", true)
		assert.truthy(F.Applies())
		SB.Config.Set("focus.on.mplus", false) -- direct Set, no Focus writer
		assert.falsy(F.Applies())
		SB.Config.CharOverride("focus.on.mplus", true) -- the override takes the current value (false)
		SB.Config.Set("focus.on.mplus", true)
		assert.truthy(F.Applies())
		SB.Config.CharOverride("focus.on.mplus", false) -- back to the account value (false)
		assert.falsy(F.Applies())
		SB.Config.Set("focus.on.mplus", true)
		assert.truthy(F.Applies())
		SB.Config.Set("focus.sections.mplus", "c_junk")
		assert.same({ "new", "c_junk" }, openIds())
		SB.Config.Reset() -- the defaults again: the "front" style, and M+'s own sections in front
		SB.Config.Set("focus.auto", true) -- Reset also puts "Switch by themselves" back to off (0.14.3)
		assert.falsy(F.Applies(), "front collapses nothing")
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Front())
	end)

	it("the collapsed view is read-only", function()
		F.SetSignal("challengeMode", true)
		local view = F.CollapsedView({})
		assert.has_error(function()
			view.c_junk = false
		end)
	end)

	-- Mutation: write into userSet inside CollapsedView.
	it("the user's saved set is never written by a mode, peek, pin, close or pause", function()
		local user = { c_junk = true, c_tools = true }
		local copy = { c_junk = true, c_tools = true }
		F.SetSignal("challengeMode", true)
		F.CollapsedView(user)
		F.HeaderClick("c_junk", true)
		F.CollapsedView(user)
		F.Pin("c_tools")
		F.CollapsedView(user)
		F.HeaderClick("c_gear", false)
		F.CollapsedView(user)
		F.Pause()
		assert.equal(user, F.CollapsedView(user))
		F.Resume()
		F.CollapsedView(user)
		assert.same(copy, user)
	end)

	it("HeaderClick and Pin do nothing and return false when no mode applies", function()
		assert.falsy(F.HeaderClick("c_junk", true))
		assert.falsy(F.Pin("c_junk"))
		F.SetSignal("challengeMode", true)
		F.Pause()
		assert.falsy(F.HeaderClick("c_junk", true))
		assert.falsy(F.Pin("c_junk"))
		F.Resume()
		F.SetSignal("bankOpen", true)
		assert.falsy(F.HeaderClick("c_junk", true))
		assert.is_nil(F.OverrideOf("c_junk"))
	end)

	it("writers say why they refused", function()
		local ok, why = F.SetSections("nope", {})
		assert.falsy(ok)
		assert.equal("unknown", why)
		why = select(2, F.SetEnabled("nope", true))
		assert.equal("unknown", why)
		why = select(2, F.ResetSections("nope"))
		assert.equal("unknown", why)
		SB.Config.readOnly = true
		why = select(2, F.SetSections("mplus", {}))
		assert.equal("readonly", why)
		why = select(2, F.SetEnabled("mplus", false))
		assert.equal("readonly", why)
		why = select(2, F.ResetSections("mplus"))
		assert.equal("readonly", why)
	end)

	-- Mutation: make Sections ignore its `raw` argument.
	it("Sections(id, true) is the stored list unfiltered; only the effective view filters by professions (W4-2)", function()
		F.SetSignal("gathering", true)
		F.SetSignal("professions", { ore = true })
		F.Recompute()
		local raw = F.Sections("gathering", true)
		local function has(list, id)
			for _, v in ipairs(list) do
				if v == id then
					return true
				end
			end
			return false
		end
		assert.truthy(has(raw, "c_herbs"))
		assert.truthy(has(raw, "c_leathercloth"))
		assert.falsy(has(F.Sections("gathering"), "c_herbs"))
		assert.same({ "new", "c_ore", "c_tools" }, openIds())
	end)

	it("vendor and auction house open Junk, Trade Goods and BoE gear; the bank opens everything (spec 6.3)", function()
		F.SetSignal("merchantOpen", true)
		assert.same({ "new", "c_boe", "c_tradegoods", "c_junk" }, openIds())
		F.SetSignal("merchantOpen", false)
		F.SetSignal("auctionOpen", true)
		assert.equal("AH/Vendor/Bank", F.Label())
		F.SetSignal("auctionOpen", false)
		F.SetSignal("bankOpen", true)
		assert.same({ "market" }, F.Active())
		local user = { c_gear = true }
		assert.equal(user, F.CollapsedView(user), "at the bank the user's own state is shown")
		assert.equal("AH/Vendor/Bank", F.Label())
	end)

	-- Week 6: Warbound until equipped sits next to BoE gear, so every built-in mode opens it exactly when it
	-- opens BoE gear (collapse and front styles read the same sets). Mutation: drop c_wue from the market set.
	it("every built-in mode opens Warbound until equipped exactly when it opens BoE gear", function()
		local has = function(list, id)
			for _, v in ipairs(list) do
				if v == id then
					return true
				end
			end
			return false
		end
		local n, withBoe = 0, 0
		for mode in pairs(SB.Config.Defaults.settings.focus.sections) do
			n = n + 1
			local set = F.Sections(mode)
			assert.equal(has(set, "c_boe"), has(set, "c_wue"), mode)
			if has(set, "c_boe") then
				withBoe = withBoe + 1
			end
		end
		assert.equal(6, n)
		assert.equal(1, withBoe, "only the market mode opens BoE gear")
	end)

	-- Week 7 (user pick 1): the modes that open Gear also open Equipment sets; the market mode never
	-- does (a set piece is never for sale). Mutation: drop c_sets from the raid default.
	it("M+, Raid and Delves open Equipment sets; AH/Vendor/Bank, Gathering and Fishing do not", function()
		local function has(mode)
			for _, v in ipairs(F.Sections(mode)) do
				if v == "c_sets" then
					return true
				end
			end
			return false
		end
		for _, mode in ipairs({ "mplus", "raid", "delves" }) do
			assert.truthy(has(mode), mode)
		end
		for _, mode in ipairs({ "market", "gathering", "fishing" }) do
			assert.falsy(has(mode), mode)
		end
	end)

	-- Mutation: make deciding() always return the strongest mode (strict) even under merge.
	it("overlapping modes merge by default (AC8.4): the union is open and the title names both", function()
		F.SetSignal("fishing", true)
		F.SetSignal("merchantOpen", true)
		assert.same({ "new", "c_boe", "c_tradegoods", "c_fish", "c_cooking", "c_junk" }, openIds())
		assert.equal("Fishing + AH/Vendor/Bank", F.Label())
	end)

	-- Mutation: compare CLASS_RANK with < instead of >.
	it("strict priority (AC8.4) keeps only the strongest class: activity beats location", function()
		SB.Config.Set("focus.resolve", "priority")
		F.SetSignal("merchantOpen", true)
		F.SetSignal("fishing", true)
		assert.same({ "new", "c_fish", "c_cooking" }, openIds())
		assert.equal("Fishing", F.Label())
	end)

	it("strict priority within a class follows the mode order (M+ before Fishing)", function()
		SB.Config.Set("focus.resolve", "priority")
		F.SetSignal("fishing", true)
		F.SetSignal("challengeMode", true)
		assert.equal("M+", F.Label())
	end)

	it("merge: a bank visit during another mode opens everything (the bank expands all)", function()
		F.SetSignal("fishing", true)
		F.SetSignal("bankOpen", true)
		local user = {}
		assert.equal(user, F.CollapsedView(user))
	end)

	it("a disabled mode never triggers; switching modes off entirely stops all of them", function()
		assert.truthy(F.SetEnabled("fishing", false))
		F.SetSignal("fishing", true)
		assert.same({}, F.Active())
		F.SetSignal("challengeMode", true)
		assert.same({ "mplus" }, F.Active())
		SB.Config.Set("focus.auto", false)
		F.Refresh("settings")
		assert.same({}, F.Active())
		assert.is_nil(F.Label())
	end)

	-- Mutation: remove `Focus.overrides = {}` from Recompute.
	it("peek (AC8.3): a click on a collapsed header opens it; a change of mode ends the peek", function()
		F.SetSignal("challengeMode", true)
		assert.equal("peek", F.HeaderClick("c_junk", true))
		assert.equal("peek", F.OverrideOf("c_junk"))
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_junk" }, openIds())
		F.SetSignal("merchantOpen", true)
		assert.is_nil(F.OverrideOf("c_junk"))
	end)

	-- Mutation: clear pins in WindowClosed too.
	it("a peek ends when the bag closes; a pin stays until the mode changes", function()
		F.SetSignal("challengeMode", true)
		F.HeaderClick("c_junk", true)
		F.Pin("c_tools")
		F.WindowClosed()
		assert.is_nil(F.OverrideOf("c_junk"))
		assert.equal("pin", F.OverrideOf("c_tools"))
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_tools" }, openIds())
		F.SetSignal("challengeMode", false)
		F.SetSignal("challengeMode", true)
		assert.is_nil(F.OverrideOf("c_tools"))
	end)

	it("with \"Keep open until mode changes\" a click pins at once", function()
		SB.Config.Set("focus.peek", "keep")
		F.SetSignal("challengeMode", true)
		F.HeaderClick("c_junk", true)
		F.WindowClosed()
		assert.equal("pin", F.OverrideOf("c_junk"))
	end)

	it("a click on an open section closes it for this bag opening; a second right-click unpins", function()
		F.SetSignal("challengeMode", true)
		assert.equal("close", F.HeaderClick("c_gear", false))
		assert.same({ "new", "c_keystone", "c_consumables" }, openIds())
		assert.equal("pin", F.Pin("c_gear"))
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear" }, openIds())
		assert.equal("unpin", F.Pin("c_gear"))
		assert.is_nil(F.OverrideOf("c_gear"))
	end)

	it("New is never collapsed by a mode, even when it is missing from the section set", function()
		SB.Config.Set("focus.sections.mplus", "c_gear")
		F.SetSignal("challengeMode", true)
		assert.is_nil(F.CollapsedView({})["new"])
	end)

	-- Mutation: make Pause leave Focus.paused false.
	it("pause (spec 6.1): no mode applies, the title says Paused, resume brings the mode back", function()
		F.SetSignal("challengeMode", true)
		F.HeaderClick("c_junk", true)
		assert.truthy(F.Pause())
		assert.falsy(F.Pause(), "already paused")
		local user = {}
		assert.equal(user, F.CollapsedView(user))
		assert.equal("Paused", F.Label())
		assert.is_nil(F.OverrideOf("c_junk"), "a pause ends peeks")
		F.SetSignal("fishing", true) -- signals still follow the world while paused
		assert.truthy(F.Resume())
		assert.equal("M+ + Fishing", F.Label())
		assert.same({ "signal", "pause", "signal", "resume" }, events)
	end)

	it("announce (off by default) prints one line per change of the active set", function()
		F.SetSignal("challengeMode", true)
		assert.same({}, SB.Adapter.Lines())
		SB.Config.Set("focus.announce", true)
		F.SetSignal("challengeMode", false)
		F.SetSignal("fishing", true)
		assert.same({ "Focus mode: no mode", "Focus mode: Fishing" }, SB.Adapter.Lines())
	end)

	it("a signal that does not change the active set changes nothing and emits nothing", function()
		F.SetSignal("instanceType", "party")
		assert.same({}, events)
		F.SetSignal("instanceType", "party")
		assert.falsy(F.SetSignal("instanceType", "party"))
	end)

	it("section sets are stored as text; reset removes the stored set so a new default applies", function()
		assert.truthy(F.SetSections("mplus", { "c_consumables", "c_junk" }))
		assert.equal("c_consumables,c_junk", SB.Config.db.settings.focus.sections.mplus)
		assert.same({ "c_consumables", "c_junk" }, F.Sections("mplus"))
		assert.same({ "settings" }, events)
		assert.truthy(F.ResetSections("mplus"))
		assert.is_nil(SB.Config.db.settings.focus.sections.mplus)
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Sections("mplus"))
	end)

	-- Mutation: in ResetSections, always Set(path, nil) (that removes the character override).
	it("with a character override, reset puts the default into the override and keeps it", function()
		SB.Config.CharOverride("focus.sections.mplus", true)
		F.SetSections("mplus", { "c_junk" })
		assert.truthy(F.ResetSections("mplus"))
		assert.truthy(SB.Config.IsCharOverride("focus.sections.mplus"))
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Sections("mplus"))
	end)

	it("read-only settings: SetEnabled, SetSections and ResetSections refuse and change nothing", function()
		SB.Config.readOnly = true
		assert.falsy(F.SetEnabled("mplus", false))
		assert.falsy(F.SetSections("mplus", { "c_junk" }))
		assert.falsy(F.ResetSections("mplus"))
		assert.truthy(F.IsEnabled("mplus"))
		assert.same({}, events)
	end)

	it("Recompute for 30 modes stays well under 0.5 ms per call (spec 6.5)", function()
		for i = 1, 24 do
			F.MODES[#F.MODES + 1] = { id = "x" .. i, class = "activity", name = "MODE_RAID", trigger = function(s)
				return s.fishing == true and s.never == true
			end }
			F.byId["x" .. i] = F.MODES[#F.MODES]
		end
		local t0 = os.clock()
		for i = 1, 1000 do
			F.SetSignal("fishing", i % 2 == 0)
		end
		local perCall = (os.clock() - t0) * 1000 / 1000
		assert.truthy(perCall < 0.5, ("%.3f ms per Recompute"):format(perCall))
	end)
end)

-- Week 6, user request 1: the "front" style (the default). An active mode collapses nothing; its
-- sections are drawn first, right after New, in the mode's order. The "collapse" style above is the
-- alternative.
describe("Focus front style (week 6)", function()
	local SB, F, events
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		SB.Config.Set("focus.auto", true) -- focus modes switch by themselves only when asked (0.14.3)
		F = SB.Focus
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason)
			events[#events + 1] = reason
		end)
	end)

	-- Mutation: in Config.Defaults, focus.style = "collapse".
	it("is the default: a running key collapses nothing and moves M+'s sections up, right after New", function()
		local user = { c_junk = true }
		F.SetSignal("challengeMode", true)
		assert.equal("front", F.Style())
		assert.falsy(F.Applies())
		assert.equal(user, F.CollapsedView(user), "the user's own collapse set, as it is")
		assert.same({ "new", "c_consumables", "c_keystone", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
			"c_leathercloth", "c_fish", "c_cooking", "c_tools", "c_junk", "c_other", "free" }, F.SectionOrder(ORDER))
		assert.equal("M+", F.Label(), "the title still names the mode")
	end)

	-- Mutation: in SectionOrder, table.insert into `order` itself instead of building `out`.
	it("never writes the order it is given; leaving the mode gives the same order back", function()
		local order = { unpack(ORDER) }
		F.SetSignal("challengeMode", true)
		F.SectionOrder(order)
		assert.same(ORDER, order, "the category order is untouched")
		F.SetSignal("challengeMode", false)
		assert.equal(order, F.SectionOrder(order), "no mode: the very same list")
		assert.is_nil(SB.Config.db.categoryOrder)
	end)

	-- Mutation: in computeFront, drop the `seen` check.
	it("merge: two modes move both sets up, each section once, the first mode's first", function()
		F.SetSignal("challengeMode", true)
		F.SetSignal("instanceType", "raid") -- Raid opens Consumables and Gear: already in front
		F.SetSignal("fishing", true)
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets", "c_fish", "c_cooking" }, F.Front())
		SB.Config.Set("focus.resolve", "priority")
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Front(), "priority: M+ only (mode order)")
	end)

	-- Mutation: in SectionOrder, append every id of Front() whether or not order has it.
	it("a section the bag does not have is skipped; New and Free keep their places", function()
		F.SetSignal("fishing", true)
		assert.same({ "new", "c_cooking", "c_gear", "c_junk", "free" },
			F.SectionOrder({ "new", "c_gear", "c_cooking", "c_junk", "free" }))
		assert.same({ "c_gear", "free" }, F.SectionOrder({ "c_gear", "free" }), "no New: nothing is added")
	end)

	-- Mutation: in computeFront, drop the expandAll check.
	it("the bank moves nothing; pause and switching modes off move nothing", function()
		F.SetSignal("merchantOpen", true)
		assert.same({ "c_junk", "c_tradegoods", "c_boe", "c_wue" }, F.Front())
		F.SetSignal("bankOpen", true)
		assert.is_nil(F.Front(), "at the bank everything stays where it is")
		F.SetSignal("bankOpen", false)
		F.Pause()
		assert.is_nil(F.Front())
		assert.equal(ORDER, F.SectionOrder(ORDER))
		F.Resume()
		SB.Config.Set("focus.auto", false)
		assert.is_nil(F.Front())
	end)

	-- Mutation: Applies() returns Expanded() ~= nil (ignores the style).
	it("a header click or right-click is the user's own: HeaderClick and Pin refuse, no override is kept", function()
		F.SetSignal("challengeMode", true)
		assert.falsy(F.HeaderClick("c_junk", true))
		assert.falsy(F.Pin("c_junk"))
		assert.is_nil(F.OverrideOf("c_junk"))
	end)

	-- Mutations: drop SetStyle's readOnly check (the M5 skip then answers true for the value already in
	-- force while read-only); drop the `write` skip (M5), so a repeat emits.
	it("SetStyle switches live, refuses unknown words and read-only, and a repeat writes nothing (M5)", function()
		F.SetSignal("challengeMode", true)
		events = {}
		assert.truthy(F.SetStyle("collapse"))
		assert.same({ "settings" }, events)
		assert.truthy(F.Applies())
		assert.is_nil(F.Front())
		assert.truthy(F.SetStyle("collapse"), "a repeat still answers")
		assert.same({ "settings" }, events, "a repeat writes nothing, so nothing re-stacks")
		assert.same({ false, "unknown" }, { F.SetStyle("sideways") })
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { F.SetStyle("front") })
		assert.same({ false, "readonly" }, { F.SetStyle("collapse") }, "read-only refuses, even the same style")
		assert.equal("collapse", F.Style())
	end)

	-- Mutation: drop the `Focus.overrides = {}` in Refresh's style check (peeks resurrect on collapse again).
	it("a style change drops the peeks and pins: collapse -> front -> collapse in one mode starts clean", function()
		assert.truthy(F.SetStyle("collapse"))
		F.SetSignal("challengeMode", true)
		assert.equal("peek", F.HeaderClick("c_junk", true))
		assert.equal("pin", F.Pin("c_gear"))
		assert.truthy(F.SetStyle("front"))
		assert.truthy(F.SetStyle("collapse"))
		assert.is_nil(F.OverrideOf("c_junk"))
		assert.is_nil(F.OverrideOf("c_gear"))
		assert.equal(true, F.CollapsedView({})["c_junk"], "c_junk is collapsed by the mode again")
		-- a setting that is not the style keeps them
		assert.equal("peek", F.HeaderClick("c_junk", true))
		SB.Config.Set("focus.peek", "keep")
		assert.equal("peek", F.OverrideOf("c_junk"))
	end)

	-- P2: every form answers. Mutation: styleCommand returns nil for a word it does not know.
	it("/swagbag mode style answers every form: the style now, a switch, a wrong word, read-only", function()
		local L = SB.L
		SB.Slash.Dispatch("mode style")
		SB.Slash.Dispatch("mode style Collapse")
		SB.Slash.Dispatch("mode style sideways")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("mode style front")
		assert.same({ L.MODE_STYLE_STATE:format(L.MODE_STYLE_NAME_FRONT), L.MODE_STYLE_COLLAPSE,
			L.MODE_STYLE_STATE:format(L.MODE_STYLE_NAME_COLLAPSE), L.SETTINGS_READONLY }, SB.Adapter.Lines())
		assert.equal("collapse", F.Style())
	end)

	-- M5 (week-4 deferred). Mutation: SetEnabled calls Config.Set directly again.
	it("a focus writer whose value is already in force emits nothing", function()
		assert.truthy(F.SetEnabled("mplus", true))
		assert.truthy(F.SetSections("mplus", { "c_consumables", "c_keystone", "c_gear", "c_sets" }))
		assert.same({}, events)
		assert.same({ auto = true }, SB.Config.db.settings.focus, "nothing was stored but the switch the test turned on")
	end)
end)

-- Forever Stage A, Task 3: no M+ and no Delves mode on WoW Forever; saved settings are kept.
describe("Focus on WoW Forever", function()
	local SB, F
	before_each(function()
		SB = Loader.New(FILES, { flavor = "forever" })
		SB.Config.Init(nil, nil)
		SB.Config.Set("focus.auto", true)
		F = SB.Focus
	end)

	local function ids(list)
		local out = {}
		for i, x in ipairs(list) do
			out[i] = x.id
		end
		return out
	end

	-- Mutation: gating Focus.All only (Focus.Active still walks Focus.MODES).
	it("on Forever the M+ and Delves modes never switch on", function()
		F.SetSignal("challengeMode", true)
		F.SetSignal("delve", true)
		F.SetSignal("instanceType", "raid")
		assert.same({ "raid" }, F.Active())
	end)

	-- Mutation: Focus.All or Focus.Triggers without the Allows filter.
	it("on Forever Focus.All and Focus.Triggers leave out M+ and Delves", function()
		assert.same({ "raid", "gathering", "fishing", "market" }, ids(F.All()))
		assert.same({ "manual", "dungeon", "raid", "pvp", "fishing", "gathering", "vendor", "auction", "bank" },
			ids(F.Triggers()))
	end)

	-- Characterization (passes before and after). Mutation: filtering byId, so Focus.Mode("mplus") is nil on Forever.
	it("on Forever a saved focus.on.mplus is kept, not deleted", function()
		SB.Config.Set("focus.on.mplus", false)
		F.SetSignal("challengeMode", true)
		F.Recompute("signal")
		assert.equal(false, SB.Config.Get("focus.on.mplus"))
		assert.truthy(F.Mode("mplus"), "Focus.Mode still knows the built-in")
		assert.equal(SB.L.MODE_MPLUS, F.NameOf("mplus"))
	end)
end)
