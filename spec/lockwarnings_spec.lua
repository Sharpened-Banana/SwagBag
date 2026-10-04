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
		SB.Emit("SB_LOGIN") -- makes the delete note, out of combat
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

	-- Mutations: in LW.OnDelete, `SB.Locks.Has(itemID)` -> `true` (every deleted item would warn); or
	-- `LW.On() and` -> `true and`.
	it("deleting a locked item: one red chat line naming it; an unlocked item, an empty cursor or the switch off: none", function()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		assert.same({ L.LOCK_WARN_DELETE:format("Flask of Alchemical Chaos") }, A.Lines())
		A.cursor = { itemID = Fixtures.HEALING_POTION, link = "item:211880" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Algari Healing Potion", 1, 0, 0)
		A.cursor = nil
		SB.Emit("DELETE_ITEM_CONFIRM", "Algari Healing Potion", 1, 0, 0)
		SB.Config.Set("locks.warn", false)
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		assert.equal(1, #A.Lines())
	end)

	-- Mutations: in LW.ShowNote, drop `n:Show()`; or in LW.CheckDelete, drop `note:Hide()`.
	it("a note sits just above Blizzard's delete box, which is never touched; it goes once the item leaves the cursor", function()
		local popup = Fake.Strict(Fake.New("Frame", UIParent))
		A.deletePopup = popup
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		local note = SB.LockWarnings.note
		assert.truthy(note, "made at login")
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		assert.falsy(note.shown, "placed a moment later, once Blizzard's box is up")
		A.Advance(0)
		assert.truthy(note.shown)
		assert.equal(L.LOCK_WARN_NOTE, note.text.text)
		assert.same({ "BOTTOM", popup, "TOP", 0, 4 }, note.points[1])
		SB.Emit("ITEM_LOCK_CHANGED", 0, 2)
		assert.truthy(note.shown, "still on the cursor: the box is still up")
		A.cursor = nil -- No or Esc (Blizzard puts it back), or Yes (deleted)
		SB.Emit("ITEM_LOCK_CHANGED", 0, 2)
		assert.falsy(note.shown)
		assert.same({}, popup.log, "never a call on Blizzard's box")
	end)

	-- Mutation: in LW.CheckDelete, drop `or not SB.Adapter.DeletePopup()`.
	it("the note also goes when Blizzard's box is gone, even with the item still on the cursor", function()
		A.deletePopup = Fake.Strict(Fake.New("Frame", UIParent))
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		A.Advance(0)
		local note = SB.LockWarnings.note
		assert.truthy(note.shown)
		A.deletePopup = nil -- the box closed; the item is still held
		SB.Emit("ITEM_LOCK_CHANGED", 0, 2)
		assert.falsy(note.shown)
		assert.is_nil(SB.LockWarnings.deleting)
	end)

	-- Mutation: in the SB_LOGIN listener, call `makeNote()` without SB.OutOfCombat.
	it("the note's frame is made at login out of combat, never in combat; a login in combat waits for its end", function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
		local SB2 = Loader.New(files)
		SB2.Config.Init(nil, nil)
		Fake.Install() -- Loader.New put the plain stubs back; the fake frames count what is made
		local before = #Fake.created
		SB2.Adapter.combat = true
		Loader.LoadFile(SB2, "SwagBag/UI/LockWarnings.lua")
		SB2.Emit("SB_LOGIN")
		assert.is_nil(SB2.LockWarnings.note, "no frame made in combat")
		assert.equal(before, #Fake.created)
		SB2.Adapter.combat = false
		SB2.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.truthy(SB2.LockWarnings.note)
		assert.falsy(SB2.LockWarnings.note.shown)
	end)

	-- Mutation: in LW.ShowNote, drop `if not popup then return end`.
	it("when Blizzard's box is not found, only the chat line: no note, nothing recorded", function()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		A.Advance(0)
		assert.falsy(SB.LockWarnings.note.shown)
		assert.equal(1, #A.Lines())
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	-- Mutations: in LW.TooltipText, `if LW.scrapper then` -> `if false then`; or in the _HIDE listener,
	-- `LW.scrapper, LW.scrapWarned = false, {}` -> `LW.scrapWarned = {}`.
	it("while the scrapper is open, a locked item's tooltip says a right-click can put it in; once closed, nothing", function()
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "scrapper")
		Locks.TooltipLine(tip, Fixtures.FLASK)
		Locks.TooltipLine(tip, Fixtures.HEALING_POTION)
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "merchant")
		Locks.TooltipLine(tip, Fixtures.FLASK)
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "scrapper")
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.same({ L.LOCK_WARN_SCRAP, L.LOCK_WARN_SCRAP }, warned)
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "scrapper")
		A.cursorOther = "targeting"
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.equal(L.LOCK_WARN_SPELL, warned[3], "a spell waiting comes first: the next click casts it")
	end)

	-- Mutations: in LW.CheckScrapper, `not LW.scrapWarned[id]` -> `true` (a line at every change); or
	-- `LW.scrapWarned = seen` -> nothing (an item taken out and put back would never be said again).
	it("a locked item put in the scrapper: one red chat line; again only once taken out and put back", function()
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "scrapper")
		A.scrapper = { Fixtures.HEALING_POTION }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		assert.same({}, A.Lines(), "not locked")
		A.scrapper = { Fixtures.HEALING_POTION, Fixtures.FLASK }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		A.scrapper = { Fixtures.HEALING_POTION, Fixtures.FLASK, Fixtures.FLASK }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		assert.same({ L.LOCK_WARN_SCRAP_ADDED:format("Flask of Alchemical Chaos") }, A.Lines())
		A.scrapper = { Fixtures.HEALING_POTION }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		A.scrapper = { Fixtures.FLASK }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		assert.equal(2, #A.Lines(), "taken out and put back: said again")
		SB.Config.Set("locks.warn", false)
		A.scrapper = {}
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		A.scrapper = { Fixtures.FLASK }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		assert.equal(2, #A.Lines(), "switched off: nothing")
	end)
end)
