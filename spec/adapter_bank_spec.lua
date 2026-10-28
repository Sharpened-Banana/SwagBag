-- luacheck: globals C_Bank C_Item C_CVar Enum ItemLocation issecretvalue StaticPopup_Show StaticPopup_Hide
-- luacheck: globals StaticPopup_Visible StaticPopupDialogs
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
		StaticPopup_Show, StaticPopup_Hide, StaticPopup_Visible, StaticPopupDialogs = nil, nil, nil, nil
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
	-- 0.14.2 Warband gold. Mutation: ask Enum.BankType.Character, or return a secret amount.
	it("WarbandMoney reads the Warband bank's gold; nil when unsupported, failing or secret", function()
		assert.is_nil(A.WarbandMoney(), "no API")
		local asked, supported = {}, true
		C_Bank = { FetchDepositedMoney = function(t) asked[#asked + 1] = t return 50000 end,
			DoesBankTypeSupportMoneyTransfer = function() return supported end }
		assert.equal(50000, A.WarbandMoney())
		assert.same({ 2 }, asked)
		supported = false
		assert.is_nil(A.WarbandMoney(), "unsupported")
		supported = true
		C_Bank.FetchDepositedMoney = function() error("boom") end
		assert.is_nil(A.WarbandMoney())
		C_Bank.FetchDepositedMoney = function() return 7 end
		issecretvalue = function(v) return v == 7 end
		assert.is_nil(A.WarbandMoney(), "secret")
	end)

	-- Mutation: drop a pcall (an error escapes), or report supported without DoesBankTypeSupportMoneyTransfer.
	it("WarbandMoneyState: can deposit, can withdraw, supported; each answer guarded", function()
		assert.same({ false, false, false }, { A.WarbandMoneyState() }, "no API")
		local asked = {}
		C_Bank = { DoesBankTypeSupportMoneyTransfer = function(t) asked[#asked + 1] = t return true end,
			CanDepositMoney = function(t) asked[#asked + 1] = t return true end,
			CanWithdrawMoney = function(t) asked[#asked + 1] = t return false end }
		assert.same({ true, false, true }, { A.WarbandMoneyState() })
		assert.same({ 2, 2, 2 }, asked)
		C_Bank.CanWithdrawMoney = function() error("boom") end
		C_Bank.CanDepositMoney = nil
		assert.same({ false, false, true }, { A.WarbandMoneyState() })
		C_Bank.DoesBankTypeSupportMoneyTransfer = function() error("boom") end
		assert.same({ false, false, false }, { A.WarbandMoneyState() })
	end)

	-- Mutation: skip hiding the other popup, drop the toggle, or pass the Character bank type.
	it("ShowWarbandMoneyPopup opens Blizzard's popup for the Warband bank, as Blizzard's buttons do", function()
		assert.equal(false, A.ShowWarbandMoneyPopup("deposit"), "no popup API")
		local shown, hidden, visible = {}, {}, {}
		StaticPopupDialogs = { BANK_MONEY_DEPOSIT = {}, BANK_MONEY_WITHDRAW = {} }
		StaticPopup_Show = function(which, a, b, data)
			shown[#shown + 1] = { which, a, b, data.bankType }
			visible[which] = true
			return {}
		end
		StaticPopup_Hide = function(which) hidden[#hidden + 1] = which visible[which] = nil end
		StaticPopup_Visible = function(which) return visible[which] and {} or nil end
		assert.equal(false, A.ShowWarbandMoneyPopup("sideways"))
		assert.equal(true, A.ShowWarbandMoneyPopup("deposit"))
		assert.same({ { "BANK_MONEY_DEPOSIT", nil, nil, 2 } }, shown)
		assert.same({ "BANK_MONEY_WITHDRAW" }, hidden, "the other one is hidden first")
		assert.equal(true, A.ShowWarbandMoneyPopup("deposit"), "a second click hides it")
		assert.equal(1, #shown)
		assert.same({ "BANK_MONEY_WITHDRAW", "BANK_MONEY_WITHDRAW", "BANK_MONEY_DEPOSIT" }, hidden)
		assert.equal(true, A.ShowWarbandMoneyPopup("withdraw"))
		assert.same({ "BANK_MONEY_WITHDRAW", nil, nil, 2 }, shown[2])
		assert.equal(true, A.WarbandMoneyPopupShown("withdraw"))
		assert.equal(false, A.WarbandMoneyPopupShown("deposit"))
		assert.equal(false, A.WarbandMoneyPopupShown("sideways"))
		StaticPopupDialogs.BANK_MONEY_DEPOSIT = nil
		assert.equal(false, A.ShowWarbandMoneyPopup("deposit"), "the popup is gone from this client")
		StaticPopupDialogs.BANK_MONEY_DEPOSIT = {}
		visible = {}
		StaticPopup_Show = function() return nil end
		assert.equal(false, A.ShowWarbandMoneyPopup("deposit"), "the client refused to show it")
		StaticPopup_Show = function() error("boom") end
		assert.equal(false, A.ShowWarbandMoneyPopup("deposit"))
		Enum = nil
		assert.equal(false, A.ShowWarbandMoneyPopup("deposit"))
	end)
end)

describe("Adapter.BankTabNames (real adapter, stubbed globals)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		Enum = { BankType = { Character = 0, Account = 2 } }
	end)

	after_each(function()
		C_Bank, Enum, issecretvalue = nil, nil, nil
	end)

	-- Mutation: ask for the character bank whatever the kind.
	it("BankTabNames: names by tab ID, a secret name left out", function()
		assert.same({}, A.BankTabNames("bank"), "no API")
		local asked = {}
		C_Bank = { FetchPurchasedBankTabData = function(bankType)
			asked[#asked + 1] = bankType
			if bankType == 2 then
				return { { ID = 15, name = "Alts" } }
			end
			return { { ID = 6, name = "Potions" }, { ID = 7, name = "Hidden" }, { ID = 8 },
				{ ID = 9, name = "" }, { name = "No ID" }, "junk" }
		end }
		issecretvalue = function(v) return v == "Hidden" end
		assert.same({ [6] = "Potions" }, A.BankTabNames("bank"))
		assert.same({ [15] = "Alts" }, A.BankTabNames("warband"))
		assert.same({ 0, 2 }, asked)
		assert.same({}, A.BankTabNames("bags"), "not a bank kind")
		C_Bank.FetchPurchasedBankTabData = function() error("boom") end
		assert.same({}, A.BankTabNames("bank"))
		C_Bank.FetchPurchasedBankTabData = function() return nil end
		assert.same({}, A.BankTabNames("bank"))
	end)
end)
