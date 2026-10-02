-- luacheck: globals issecretvalue IsInInstance GetInstanceInfo C_ChallengeMode C_RestrictedActions Enum C_PartyInfo C_Spell
-- luacheck: globals IsFishingLoot GetLootSourceInfo GetProfessions GetProfessionInfo
-- The REAL Adapter.lua (not the mock): the focus-mode signal reads (week 4, spec 6.2). Each one
-- is feature-detected; a missing or failing client function gives the stated fallback.
describe("Adapter focus signals (real adapter, stubbed globals)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		IsInInstance, GetInstanceInfo, C_ChallengeMode, C_RestrictedActions, Enum = nil, nil, nil, nil, nil
		C_PartyInfo, C_Spell, IsFishingLoot, GetLootSourceInfo, GetProfessions, GetProfessionInfo =
			nil, nil, nil, nil, nil, nil
		issecretvalue = nil
	end)

	it("InstanceInfo: type and difficulty inside an instance; nothing outside one or without the API", function()
		assert.same({}, A.InstanceInfo())
		IsInInstance = function() return false, "none" end
		assert.same({}, A.InstanceInfo())
		IsInInstance = function() return true, "party" end
		GetInstanceInfo = function() return "Ara-Kara", "party", 8, "Mythic Keystone" end
		assert.same({ instanceType = "party", difficultyID = 8 }, A.InstanceInfo())
		GetInstanceInfo = function() error("broken") end
		assert.same({ instanceType = "party" }, A.InstanceInfo())
	end)

	it("ChallengeModeActive: the challenge-mode API, else the restriction, else nil", function()
		assert.is_nil(A.ChallengeModeActive())
		Enum = { AddOnRestrictionType = { ChallengeMode = 2 } }
		C_RestrictedActions = { IsAddOnRestrictionActive = function(kind) return kind == 2 end }
		assert.equal(true, A.ChallengeModeActive())
		C_ChallengeMode = { IsChallengeModeActive = function() return false end }
		assert.equal(false, A.ChallengeModeActive())
		C_ChallengeMode = { IsChallengeModeActive = function() error("broken") end }
		assert.equal(true, A.ChallengeModeActive(), "a failing API falls back to the restriction")
	end)

	it("InDelve: the party API when present, else a scenario at the delve difficulty", function()
		assert.equal(false, A.InDelve({ instanceType = "scenario", difficultyID = 1 }))
		assert.equal(true, A.InDelve({ instanceType = "scenario", difficultyID = 208 }))
		C_PartyInfo = { IsDelveInProgress = function() return false end }
		assert.equal(false, A.InDelve({ instanceType = "scenario", difficultyID = 208 }))
	end)

	it("SpellName is lower case, nil without the API or for a bad ID", function()
		assert.is_nil(A.SpellName(131474))
		C_Spell = { GetSpellName = function(id) return id == 131474 and "Fishing" or nil end }
		assert.equal("fishing", A.SpellName(131474))
		assert.is_nil(A.SpellName(1))
		assert.is_nil(A.SpellName("131474"))
	end)

	it("IsFishingLoot and LootSourceType", function()
		assert.equal(false, A.IsFishingLoot())
		IsFishingLoot = function() return true end
		assert.equal(true, A.IsFishingLoot())
		-- M3 (final review). Mutation: in A.IsFishingLoot, drop the isSecret(v) check.
		issecretvalue = function(v) return v == true end
		assert.equal(false, A.IsFishingLoot(), "a secret answer never decides")
		issecretvalue = nil
		assert.is_nil(A.LootSourceType())
		GetLootSourceInfo = function() return "GameObject-0-1-2-3-4-5" end
		assert.equal("GameObject", A.LootSourceType())
		GetLootSourceInfo = function() error("no loot") end
		assert.is_nil(A.LootSourceType())
	end)

	it("GatheringProfessions reads the two primary professions' skill lines; nil without the API", function()
		assert.is_nil(A.GatheringProfessions())
		GetProfessions = function() return 3, 7, nil, 9 end
		GetProfessionInfo = function(index)
			local lines = { [3] = 182, [7] = 171 }
			return "Name", 0, 1, 100, 1, 0, lines[index]
		end
		assert.same({ herb = true }, A.GatheringProfessions())
		GetProfessions = function() return nil, 7 end
		assert.same({}, A.GatheringProfessions())
	end)

	it("a secret IsChallengeModeActive result falls back to the restriction", function()
		Enum = { AddOnRestrictionType = { ChallengeMode = 2 } }
		C_RestrictedActions = { IsAddOnRestrictionActive = function() return true end }
		C_ChallengeMode = { IsChallengeModeActive = function() return false end }
		issecretvalue = function(v) return v == false end -- the API's answer is secret
		assert.equal(true, A.ChallengeModeActive())
	end)

	it("IsChallengeModeRestriction: only the ChallengeMode kind; every kind when the enum is missing", function()
		assert.equal(true, A.IsChallengeModeRestriction(1))
		Enum = { AddOnRestrictionType = { ChallengeMode = 2 } }
		assert.equal(true, A.IsChallengeModeRestriction(2))
		assert.equal(false, A.IsChallengeModeRestriction(1))
	end)

	it("secret values never decide: a secret inInstance flag and a secret skill line", function()
		issecretvalue = function(v) return v == "secret" end
		IsInInstance = function() return "secret", "party" end
		assert.same({}, A.InstanceInfo())
		GetProfessions = function() return 3 end
		GetProfessionInfo = function() return "Name", 0, 1, 100, 1, 0, "secret" end
		assert.same({}, A.GatheringProfessions())
	end)
end)
