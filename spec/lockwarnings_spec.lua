-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 10 (the user: "Will locking prevent disenchanting or similar as well?" -> "Make it"): SwagBag cannot stop
-- Blizzard's disenchanting, milling, prospecting, scrapping or deleting without tainting them, so it warns about a
-- locked item instead, and never blocks, cancels, clicks or hides anything of Blizzard's.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Lock warnings (week 10)", function()
	local SB, A, L, Locks, warned, tip
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
		SB = Loader.New(files)
		A, L, Locks = SB.Adapter, SB.L, SB.Locks
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/LockWarnings.lua")
		warned = {}
		A.TooltipWarning = function(_, text)
			warned[#warned + 1] = text
		end
		tip = Fake.New("GameTooltip")
		Locks.Toggle(Fixtures.FLASK)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- Mutations: in LW.TooltipText, `if SB.Adapter.SpellTargeting() then` -> `if true then`; or in
	-- Locks.TooltipLine, drop the `local warn = ...` block.
	it("while a spell waits for its target, a locked item's tooltip gets the red line; nothing otherwise", function()
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.same({}, warned, "no spell waiting: only the Locked line")
		assert.equal(L.LOCK_TOOLTIP, tip.calls.AddLine[1])
		A.cursorOther = "targeting" -- Disenchant (or Milling, Prospecting, an enchant) waits for its target
		Locks.TooltipLine(tip, Fixtures.FLASK)
		Locks.TooltipLine(tip, Fixtures.HEALING_POTION)
		assert.same({ L.LOCK_WARN_SPELL }, warned, "the locked item only")
	end)

	-- Mutation: in LW.TooltipText, drop `if not LW.On() then return nil end`.
	it("with the warning switched off (locks.warn) the tooltip keeps only its Locked line", function()
		assert.truthy(SB.Config.Get("locks.warn"), "on by default")
		SB.Config.Set("locks.warn", false)
		A.cursorOther = "targeting"
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.same({}, warned)
		assert.equal(L.LOCK_TOOLTIP, tip.calls.AddLine[1])
	end)
end)
