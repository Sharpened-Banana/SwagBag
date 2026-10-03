-- luacheck: globals C_Bank C_Item C_CVar Enum ItemLocation issecretvalue
-- The REAL Adapter's warband deposit helpers (week 6, user request 3), with stubbed game globals.
describe("Adapter warband deposit (real adapter, stubbed globals)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		Enum = { BankType = { Character = 0, Account = 2 } }
	end)

	after_each(function()
		C_Bank, C_Item, C_CVar, Enum, ItemLocation, issecretvalue = nil, nil, nil, nil, nil, nil
	end)

	-- Mutation: pass Enum.BankType.Character (or Blizzard's selected type) to the game call.
	it("DepositWarband asks the game for the warband bank by type, and refuses without the API", function()
		assert.equal(false, A.DepositWarband(), "no API")
		local asked = {}
		C_Bank = { AutoDepositItemsIntoBank = function(bankType) asked[#asked + 1] = bankType end }
		assert.truthy(A.DepositWarband())
		assert.same({ 2 }, asked)
		C_Bank.AutoDepositItemsIntoBank = function() error("boom") end
		local ok, err = A.DepositWarband()
		assert.equal(false, ok)
		assert.truthy(tostring(err):find("boom", 1, true))
	end)

	-- Mutation: treat any FetchBankLockedReason answer (nil included) as locked.
	it("WarbandDepositState: usable, locked by another character, or unavailable", function()
		assert.same({ false, "unavailable" }, { A.WarbandDepositState() }, "no API")
		local locked, can = nil, true
		C_Bank = { AutoDepositItemsIntoBank = function() end,
			FetchBankLockedReason = function() return locked end, CanUseBank = function() return can end }
		assert.same({ true }, { A.WarbandDepositState() })
		locked = 1
		assert.same({ false, "locked" }, { A.WarbandDepositState() })
		locked, can = nil, false
		assert.same({ false, "unavailable" }, { A.WarbandDepositState() })
		C_Bank.CanUseBank = function() error("boom") end
		assert.same({ false, "unavailable" }, { A.WarbandDepositState() })
	end)

	-- Item safety. Mutation: drop the IsItemAllowedInBankType test (any refundable item counts) -- or
	-- return false instead of nil when the answer is secret.
	it("RefundableForWarband finds a refundable item the warband bank would take; nil when it cannot tell", function()
		local bags = { { bag = 0, size = 3 } }
		assert.is_nil(A.RefundableForWarband(bags), "no API: unknown")
		ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
		local refundable, allowed = { [2] = true, [3] = true }, { [3] = true }
		C_Item = { DoesItemExist = function(loc) return loc.slot ~= 1 end,
			CanBeRefunded = function(loc) return refundable[loc.slot] == true end }
		C_Bank = { IsItemAllowedInBankType = function(bankType, loc) return bankType == 2 and allowed[loc.slot] == true end }
		assert.equal(true, A.RefundableForWarband(bags), "slot 3: refundable and the warband bank takes it")
		allowed[3] = nil
		assert.equal(false, A.RefundableForWarband(bags), "slot 2 is refundable, but the warband bank refuses it")
		issecretvalue = function(v) return v == true end
		assert.is_nil(A.RefundableForWarband(bags), "a secret answer: unknown")
	end)

	-- Mutation: SetDepositReagents writes "1" for false.
	it("DepositReagents reads Blizzard's include-reagents choice; SetDepositReagents writes it as the box does", function()
		assert.is_nil(A.DepositReagents())
		assert.equal(false, A.SetDepositReagents(true))
		local cvar = "0"
		C_CVar = { GetCVarBool = function(name) return name == "bankAutoDepositReagents" and cvar == "1" end,
			SetCVar = function(name, v) if name == "bankAutoDepositReagents" then cvar = v end end }
		assert.equal(false, A.DepositReagents())
		assert.truthy(A.SetDepositReagents(true))
		assert.equal("1", cvar)
		assert.equal(true, A.DepositReagents())
		assert.truthy(A.SetDepositReagents(false))
		assert.equal("0", cvar)
	end)
end)
