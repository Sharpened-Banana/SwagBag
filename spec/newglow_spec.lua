-- luacheck: globals PawnIsReady PawnIsItemDefinitivelyAnUpgrade C_Container C_NewItems issecretvalue
-- Ruling W4-15: Pawn through PawnIsReady + PawnIsItemDefinitivelyAnUpgrade, and Blizzard's blue
-- new-item glow (newglow-diagnosis.md): the client's flag is cleared per slot on hover, when the
-- bags or the bank close, and when an item leaves; SwagBag's own New never reads it.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Adapter: Pawn and Blizzard's new-item flag (the real Adapter)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		PawnIsReady, PawnIsItemDefinitivelyAnUpgrade, C_Container, C_NewItems, issecretvalue = nil, nil, nil, nil, nil
	end)

	-- Mutation: A.HasPawn returns `type(_G.PawnIsContainerItemAnUpgrade) == "function"` again.
	it("HasPawn: true only once PawnIsReady exists and says yes", function()
		assert.falsy(A.HasPawn())
		PawnIsItemDefinitivelyAnUpgrade = function()
			return true
		end
		PawnIsReady = function()
			return false
		end
		assert.falsy(A.HasPawn(), "loaded, not ready yet")
		PawnIsReady = function()
			error("Pawn broke")
		end
		assert.falsy(A.HasPawn())
		PawnIsReady = function()
			return true
		end
		assert.truthy(A.HasPawn())
	end)

	-- Mutation: fold Pawn's answer again (`return yes and true or false`, the old W3-16 rule).
	it("PawnUpgrade asks Pawn about the slot's link: true, false, or nil (no opinion: the item-level rule)", function()
		local asked
		local verdict = true
		C_Container = { GetContainerItemInfo = function(bag, slot)
			return { itemID = 225001, hyperlink = "item:225001:" .. bag .. ":" .. slot }
		end }
		PawnIsReady = function()
			return true
		end
		PawnIsItemDefinitivelyAnUpgrade = function(link, checkLevel)
			asked = { link, checkLevel }
			return verdict
		end
		assert.equal(true, A.PawnUpgrade(0, 3))
		assert.same({ "item:225001:0:3", true }, asked)
		verdict = false
		assert.equal(false, A.PawnUpgrade(0, 3))
		verdict = nil
		assert.is_nil(A.PawnUpgrade(0, 3))
		PawnIsItemDefinitivelyAnUpgrade = function()
			error("Pawn broke")
		end
		assert.is_nil(A.PawnUpgrade(0, 3))
		PawnIsItemDefinitivelyAnUpgrade = function()
			return true
		end
		issecretvalue = function(v)
			return v == true
		end
		assert.is_nil(A.PawnUpgrade(0, 3), "a secret verdict is no opinion")
		issecretvalue = nil
		C_Container = { GetContainerItemInfo = function()
			return nil
		end }
		assert.is_nil(A.PawnUpgrade(0, 3), "an empty slot")
		PawnIsReady = function()
			return false
		end
		C_Container = { GetContainerItemInfo = function()
			return { itemID = 1, hyperlink = "item:1" }
		end }
		assert.is_nil(A.PawnUpgrade(0, 3), "Pawn not ready yet")
	end)

	-- Mutation: delete `pcall(N.RemoveNewItem, bag, slot)` in A.ClearNewItem.
	it("ClearNewItem and ClearNewItems clear the flag slot by slot, and do nothing without the API", function()
		A.ClearNewItem(0, 1)
		A.ClearNewItems({ 0 })
		local cleared = {}
		C_NewItems = { RemoveNewItem = function(bag, slot)
			cleared[#cleared + 1] = bag .. ":" .. slot
		end }
		C_Container = { GetContainerNumSlots = function(bag)
			return bag == 0 and 2 or 1
		end }
		A.ClearNewItem(0, 3)
		A.ClearNewItems({ 0, 5 })
		assert.same({ "0:3", "0:1", "0:2", "5:1" }, cleared)
		C_NewItems = { RemoveNewItem = function()
			error("gone")
		end }
		A.ClearNewItem(0, 1) -- an error from the client never escapes
		A.ClearNewItems({ 0 })
	end)
end)

describe("Buttons: Blizzard's blue new-item glow", function()
	local SB, A, B
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Env.PaintGlobals()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		B = SB.Buttons
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	-- The template's glow parts, as ContainerFrameItemButtonTemplate has them.
	local function glowing(bag, slot)
		local b = B.Get(bag, slot)
		b.NewItemTexture = Fake.New("Texture", b)
		b.BattlepayItemTexture = Fake.New("Texture", b)
		b.flashAnim = Fake.New("AnimationGroup", b)
		b.newitemglowAnim = Fake.New("AnimationGroup", b)
		return b
	end

	-- Mutation: delete the HookScript("OnEnter", ...) in createButton.
	it("hovering a button clears the client's flag for its slot and hides the glow", function()
		local b = glowing(0, 3)
		Fake.Fire(b, "OnEnter")
		assert.same({ "0:3" }, A.newCleared)
		assert.same({ false, false }, { b.NewItemTexture.shown, b.BattlepayItemTexture.shown })
		assert.truthy(b.flashAnim.calls.Stop, "flashAnim stopped")
		assert.truthy(b.newitemglowAnim.calls.Stop, "newitemglowAnim stopped")
	end)

	-- Mutation: pass the bare function to HookScript instead of SB.ErrorTrap.Guard(...).
	it("an error while clearing is recorded without Safe Mode, and the glow is still hidden", function()
		local b = glowing(0, 3)
		A.ClearNewItem = function()
			error("flag broke")
		end
		Fake.Fire(b, "OnEnter")
		local e = SB.ErrorTrap.Recent()[1]
		assert.same({ "buttons.newGlow", "none" }, { e.label, e.window })
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(b.NewItemTexture.shown)
	end)

	-- Mutation: delete Buttons.ClearGlow(button) at the end of Buttons.Paint.
	it("painting a button hides a glow the template showed; a button without the parts is fine", function()
		local b = glowing(0, 3)
		B.Paint(b, A.GetSlot(0, 3))
		assert.falsy(b.NewItemTexture.shown)
		assert.truthy(b.flashAnim.calls.Stop)
		B.Paint(B.Get(0, 7), nil)
	end)

	-- Mutation: delete the SB_BAGS_CLOSED handler (or the SB_BANK_CLOSED one) at the end of Buttons.lua.
	it("closing the bags clears the flags of bags 0-5 only; closing the bank clears its tabs", function()
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		SB.Emit("SB_BAGS_CLOSED")
		assert.same({ { 0, 1, 2, 3, 4, 5 } }, A.newClearedBags)
		SB.Emit("SB_BANK_CLOSED")
		assert.same({ 6, 12 }, A.newClearedBags[2])
	end)
end)

describe("Inventory and the client's new-item flag", function()
	local SB, A, Inv
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Inv = SB.Inventory
	end)

	after_each(function()
		C_NewItems = nil
	end)

	-- Pins the diagnosis: SwagBag's newSet is the only "new"; Blizzard's flag is never imported.
	-- The C_NewItems.IsNewItem stub only documents that intent: no SwagBag code reads it (the mock
	-- Adapter has no such call), so the stub alone guards nothing. The real guard is the Inv.scanned
	-- check below. Mutation: in Inventory.ScanBag, `if r == Inv.R.ITEM and Inv.scanned then` →
	-- `if r == Inv.R.ITEM then`.
	it("the login scan marks nothing new, even when the client flags every slot new", function()
		C_NewItems = { IsNewItem = function()
			return true
		end }
		Inv.ScanAll()
		assert.is_nil(next(Inv.newSet))
	end)

	-- Mutation: delete `SB.Adapter.ClearNewItem(bag, slot)` in Inventory.ScanBag.
	it("an item that leaves its slot is no longer new, and the client's flag for the slot is cleared", function()
		Inv.ScanAll()
		A.Put(0, 7, Fixtures.HERB, 5)
		Inv.ScanBag(0)
		assert.truthy(Inv.IsNew(0, 7))
		A.Clear(0, 7)
		Inv.ScanBag(0)
		assert.falsy(Inv.IsNew(0, 7))
		assert.same({ "0:7" }, A.newCleared)
	end)
end)
