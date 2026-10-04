-- luacheck: globals SetItemButtonTexture SetItemButtonCount SetItemButtonQuality SetItemButtonDesaturated
-- Week 9 (user pick 11): with Masque loaded, SwagBag's item buttons join Masque groups ("Bags", "Bank", "Guild
-- bank", "Alt viewer") once each, never in combat, and nothing else about them changes; without Masque nothing
-- happens at all.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Skins (week 9, Masque)", function()
	local SB, A, Sk
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
			"SwagBag/Core/Config.lua" })
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		Env.PaintGlobals()
		A.SetBagSize(0, 16)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(6, 98)
		A.SetBagSize(12, 98)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function load(files)
		for _, f in ipairs(files) do
			Loader.LoadFile(SB, f)
		end
		Sk = SB.Skins
	end

	-- Mutation: in createButton (UI/Buttons.lua), drop the SB.Skins.Add call.
	it("every bag and bank button joins its Masque group once at login; a bank tab bought later joins too", function()
		A.masque = { groups = {} }
		load({ "SwagBag/UI/Skins.lua", "SwagBag/UI/Buttons.lua" })
		SB.Emit("SB_LOGIN")
		local B = SB.Buttons
		assert.equal(6 * 38, #A.masque.groups.Bags, "bags 0-5 at 38 buttons each")
		assert.equal(2 * 98, #A.masque.groups.Bank, "the character and the warband bank share a group")
		assert.equal(B.Get(0, 1), A.masque.groups.Bags[1])
		A.bagIDs.bank = { 6, 7 }
		A.SetBagSize(7, 98)
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.equal(3 * 98, #A.masque.groups.Bank)
		Sk.Add("bags", B.Get(0, 1))
		assert.equal(6 * 38, #A.masque.groups.Bags, "never twice")
		assert.equal(6 * 38 + 3 * 98, Sk.count)
	end)

	-- Never in combat. Mutation: in Skins.Add, drop the InCombat check (the button joins at once).
	it("a button made in combat joins only once combat ends", function()
		A.masque = { groups = {} }
		load({ "SwagBag/UI/Skins.lua", "SwagBag/UI/DisplayButtons.lua" })
		SB.DisplayButtons.SetParent(Fake.New("Frame", UIParent))
		A.combat = true
		local b = SB.DisplayButtons.Get(0, 1) -- the alt viewer's plain buttons may be made in combat
		assert.is_nil(A.masque.groups["Alt viewer"])
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.same({ b }, A.masque.groups["Alt viewer"])
	end)

	-- Mutation: in GuildButtons' create, drop the SB.Skins.Add call.
	it("the guild bank's buttons join the Guild bank group when they are made", function()
		A.masque = { groups = {} }
		load({ "SwagBag/UI/Skins.lua", "SwagBag/UI/GuildButtons.lua" })
		SB.GuildButtons.SetParent(Fake.New("Frame", UIParent))
		SB.GuildButtons.Ensure({ 1 })
		assert.equal(A.GUILD_SLOTS, #A.masque.groups["Guild bank"])
	end)

	-- Mutations: in Skins.Add, drop the Available() check (Masque is asked for every button); or in
	-- Skins.Available, ask each time (`if Sk.available == nil then` -> `if true then`).
	it("without Masque nothing is asked, and whether Masque is there is asked once per session", function()
		load({ "SwagBag/UI/Skins.lua", "SwagBag/UI/Buttons.lua" })
		local asked, looked = 0, 0
		A.MasqueAdd = function() asked = asked + 1 return false end
		local available = A.MasqueAvailable
		A.MasqueAvailable = function()
			looked = looked + 1
			return available()
		end
		SB.Emit("SB_LOGIN")
		assert.same({ 0, 0, 1 }, { asked, Sk.count, looked })
		A.masque = { groups = {} } -- Masque was not there at login: the answer is kept for the session
		Sk.Add("bags", SB.Buttons.Get(0, 1))
		assert.same({ 0, 0, 1 }, { asked, Sk.count, looked }, "the late button: nothing asked either")
	end)
end)
