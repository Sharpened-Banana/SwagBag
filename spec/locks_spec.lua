-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 7 (user pick 5): item locks. Per item ID, account-wide (SwagBagDB.locks), never sold by SwagBag,
-- found by the `locked` keyword, set by dropping an item on the bags window's Lock button.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Locks (week 7)", function()
	local SB, A, Locks, changed
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
		SB = Loader.New(files)
		A, Locks = SB.Adapter, SB.Locks
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		changed = 0
		SB.On("SB_LOCKS_CHANGED", function()
			changed = changed + 1
		end)
	end)

	-- Mutation: in Locks.Toggle, store under tostring(itemID) (Has would never find it).
	it("a lock is per item ID, stored account-wide; a second toggle removes it; every change is announced", function()
		assert.same({ true, true }, { Locks.Toggle(Fixtures.HEALING_POTION) })
		assert.truthy(Locks.Has(Fixtures.HEALING_POTION))
		assert.same({ [Fixtures.HEALING_POTION] = true }, SB.Config.db.locks)
		assert.same({ Fixtures.HEALING_POTION }, Locks.List())
		assert.same({ true, false }, { Locks.Toggle(Fixtures.HEALING_POTION) })
		assert.falsy(Locks.Has(Fixtures.HEALING_POTION))
		assert.same({}, SB.Config.db.locks)
		assert.equal(2, changed)
	end)

	-- Mutation: in Locks.Toggle, drop the readOnly check.
	it("read-only settings, a bad item ID and damaged saved data change nothing and never throw", function()
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { Locks.Toggle(Fixtures.HEALING_POTION) })
		SB.Config.readOnly = false
		assert.same({ false, "invalid" }, { Locks.Toggle("potion") })
		SB.Config.db.locks = "broken"
		assert.falsy(Locks.Has(Fixtures.HEALING_POTION))
		assert.same({}, Locks.List())
		SB.Config.db.locks = { [Fixtures.FLASK] = true, junk = true, [1.5] = true }
		assert.same({ Fixtures.FLASK }, Locks.List())
		assert.equal(0, changed)
	end)

	-- Mutation: register `locked` as flag("isLocked") again.
	it("the search keyword `locked` finds the user's locked items; `inuse` is the client's lock", function()
		Locks.Toggle(Fixtures.FLASK)
		A.Put(0, 7, Fixtures.HERB, 3, { isLocked = true })
		local function matches(query, slot)
			return SB.Query.Eval(SB.Query.Compile(query), SB.Items.Describe(0, slot)) == true
		end
		assert.same({ false, true, false }, { matches("locked", 1), matches("locked", 2), matches("locked", 7) })
		assert.same({ false, true }, { matches("inuse", 2), matches("inuse", 7) })
	end)

	-- P2. Mutation: /swagbag lock clear without the readOnly refusal (Locks.Clear's check removed).
	it("/swagbag lock says how, lists, unlocks all, and answers every form", function()
		Locks.Toggle(Fixtures.HEALING_POTION)
		Locks.Toggle(Fixtures.FLASK)
		SB.Slash.Dispatch("lock")
		SB.Slash.Dispatch("lock list")
		SB.Slash.Dispatch("lock what")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("lock clear")
		SB.Config.readOnly = false
		SB.Slash.Dispatch("lock clear")
		SB.Slash.Dispatch("lock clear")
		SB.Slash.Dispatch("lock list")
		local L = SB.L
		assert.same({ L.LOCK_STATE:format(2), "Locked: Algari Healing Potion, Flask of Alchemical Chaos.", L.LOCK_USAGE,
			L.SETTINGS_READONLY, L.LOCK_CLEAR_ASK:format(2), "Unlocked all items (2).", L.LOCK_NONE }, A.Lines())
	end)

	-- Final review fix 2. Mutations: Locks.AskClear clears at once (drop the ask); or the window check `<=`
	-- CONFIRM is removed (a stale ask confirms); or Locks.Clear keeps no backup; or Locks.Undo forgets to
	-- drop the backup (a second undo answers again).
	it("lock clear asks first; only a second within 10 seconds clears; lock undo brings the set back once", function()
		local L = SB.L
		Locks.Toggle(Fixtures.HEALING_POTION)
		Locks.Toggle(Fixtures.FLASK)
		SB.Slash.Dispatch("lock undo") -- nothing cleared yet
		SB.Slash.Dispatch("lock clear")
		assert.equal(2, #Locks.List(), "the first press only asks")
		A.Advance(11)
		SB.Slash.Dispatch("lock clear")
		assert.equal(2, #Locks.List(), "too late: asks again")
		A.Advance(9)
		SB.Slash.Dispatch("lock clear")
		assert.equal(0, #Locks.List())
		SB.Slash.Dispatch("lock undo")
		assert.same({ true, true }, { Locks.Has(Fixtures.HEALING_POTION), Locks.Has(Fixtures.FLASK) })
		assert.equal(2, #Locks.List(), "both are back")
		SB.Slash.Dispatch("lock undo")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("lock undo")
		assert.same({ L.LOCK_UNDO_NONE, L.LOCK_CLEAR_ASK:format(2), L.LOCK_CLEAR_ASK:format(2), "Unlocked all items (2).",
			L.LOCK_UNDONE:format(2), L.LOCK_UNDO_NONE, L.SETTINGS_READONLY }, A.Lines())
	end)

	-- Final review fix 2: a lock made between the two presses starts the question over.
	it("a lock or unlock between the two presses starts the question over", function()
		Locks.Toggle(Fixtures.HEALING_POTION)
		SB.Slash.Dispatch("lock clear")
		Locks.Toggle(Fixtures.FLASK)
		SB.Slash.Dispatch("lock clear")
		assert.equal(2, #Locks.List())
		assert.equal(SB.L.LOCK_CLEAR_ASK:format(2), A.Lines()[2])
	end)

	-- Mutation: Locks.TooltipLine adds its line whatever Has says.
	it("a locked item's tooltip says it is locked; others get nothing", function()
		local tip = Fake.New("GameTooltip")
		Locks.Toggle(Fixtures.FLASK)
		Locks.TooltipLine(tip, Fixtures.HEALING_POTION)
		assert.is_nil(tip.calls.AddLine)
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.equal(SB.L.LOCK_TOOLTIP, tip.calls.AddLine[1])
	end)

	-- Ruling R21. Mutations: in Locks.KeywordNote, drop the `if d.notes.lockedKeyword then` check (the note
	-- would come at every login); or `usesLocked(def.query)` -> `true` (a note with no saved `locked`).
	it("first login with this version: one note if a saved query uses the word locked, never again", function()
		SB.Config.db.categories.u_x = { name = "X", query = "junk & locked", priority = 58, displayOrder = 55 }
		SB.Emit("SB_LOGIN")
		SB.Emit("SB_LOGIN")
		assert.same({ SB.L.LOCK_KEYWORD_NOTE }, A.Lines())
		assert.truthy(SB.Config.db.notes.lockedKeyword)
		SB.Config.db.notes = nil
		SB.Config.db.categories.u_x.query = "junk"
		SB.Emit("SB_LOGIN")
		assert.equal(1, #A.Lines(), "no saved query uses it: no note")
	end)
end)

describe("Lock button (week 7)", function()
	local SB, A, LB, button
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		SB.BagsWindow = { frame = Fake.New("Frame", UIParent) }
		Loader.LoadFile(SB, "SwagBag/UI/LockButton.lua")
		LB = SB.LockButton
		button = LB.button
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- Mutation: in LB.Drop, drop A.ClearCursor() (the item would stay on the cursor).
	it("an item dropped on Lock is locked and goes back; again unlocks it; each answers once in chat", function()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		Fake.Fire(button, "OnReceiveDrag")
		Fake.Fire(button, "OnClick", "LeftButton") -- the same press: ignored
		assert.truthy(SB.Locks.Has(Fixtures.FLASK))
		assert.is_nil(A.cursor, "the item went back")
		A.Advance(LB.DROP_GUARD)
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		Fake.Fire(button, "OnClick", "LeftButton")
		assert.falsy(SB.Locks.Has(Fixtures.FLASK))
		assert.same({ "Locked: Flask of Alchemical Chaos. SwagBag never sells it, and it shows a small lock.",
			"Unlocked: Flask of Alchemical Chaos." }, A.Lines())
	end)

	-- Mutations: in press(), drop the `elseif not guarded` branch (an empty click says nothing); or in LB.Drop,
	-- `L.LOCK_INVALID` -> `L.DROP_INVALID` (a category's words).
	it("a click with nothing on the cursor says how; read-only keeps the item on the cursor and says why", function()
		A.Advance(1)
		Fake.Fire(button, "OnClick", "LeftButton")
		SB.Config.readOnly = true
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		Fake.Fire(button, "OnClick", "LeftButton")
		assert.truthy(A.cursor, "refused: still on the cursor")
		SB.Config.readOnly = false
		A.cursor = { itemID = -1, link = "x" } -- not an item SwagBag can lock (ruling R16: its own words)
		Fake.Fire(button, "OnClick", "LeftButton")
		assert.truthy(A.cursor, "refused: still on the cursor")
		assert.same({ SB.L.LOCK_STATE:format(0), SB.L.SETTINGS_READONLY, SB.L.LOCK_INVALID }, A.Lines())
		assert.same({ "TOPRIGHT", SB.BagsWindow.frame, "TOPRIGHT", -8, -31 }, button.points[1], "right of the search box")
	end)

	-- Fix round 1: every caged battle pet is the one item 82800, so a lock would lock them all. Mutation: in
	-- Locks.Toggle, drop the `itemID == Locks.PET_CAGE` refusal.
	it("a caged battle pet cannot be locked (all cages share one item ID); it stays on the cursor", function()
		A.cursor = { itemID = 82800, link = "battlepet:1234:25:3:1500:300:300:0000000000000000" }
		Fake.Fire(button, "OnClick", "LeftButton")
		assert.truthy(A.cursor, "refused: still on the cursor")
		assert.falsy(SB.Locks.Has(82800))
		assert.same({ false, "invalid" }, { SB.Locks.Toggle(82800) })
		assert.same({ SB.L.LOCK_INVALID }, A.Lines())
	end)
end)
