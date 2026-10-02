-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The Consumables settings page (spec 6.6, AC11.2): on/off, thresholds, remove, drop an item
-- to watch it, Check now, Reset to default; read-only refusals keep the item on the cursor.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Settings: consumables page", function()
	local SB, A, SW, C, L
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		for _, f in ipairs({ "SwagBag/Engine/Focus.lua", "SwagBag/Engine/FocusData.lua", "SwagBag/Engine/Signals.lua",
			"SwagBag/Engine/Consumables.lua" }) do
			files[#files + 1] = f
		end
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsConsumables.lua")
		SW, C, L = SB.SettingsWindow, SB.Consumables, SB.L
		SB.Emit("SB_LOGIN")
		SW.Show("consumables")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function rowButton(rowLabel, text)
		local index = 0
		for _, row in ipairs(SW.byId.consumables.rows()) do
			local items = row.choices or row.actions or (row.kind == "drop" and { { text = row.text } }) or {}
			for _, item in ipairs(items) do
				index = index + 1
				if row.label == rowLabel and item.text == text then
					return SW.buttons[index]
				end
			end
		end
		error("no button " .. text .. " in row " .. rowLabel)
	end

	local function click(rowLabel, text)
		Fake.Fire(rowButton(rowLabel, text), "OnClick")
	end

	it("lists the default watch list with each threshold", function()
		assert.truthy(rowButton("Flask: warn below 1", "+"))
		assert.truthy(rowButton("Potions: warn below 5", "Remove"))
		assert.truthy(rowButton("Food: warn below 5", "-"))
		assert.truthy(SW.selected[rowButton(L.SET_WATCH_WARN, L.SET_ON)])
	end)

	-- Mutation: make the + action call change(e.threshold) (no change).
	it("+ and - change a threshold and say the new value; the row follows", function()
		click("Potions: warn below 5", "+")
		assert.equal(6, C.List()[2].threshold)
		assert.equal("Potions: warns when you have fewer than 6.", SW.lastStatus)
		click("Potions: warn below 6", "-")
		click("Potions: warn below 5", "-")
		assert.equal(4, C.List()[2].threshold)
	end)

	-- Mutation: make the - action's refusal text L.SET_WATCH_INVALID, or let it save when unchanged.
	it("- at threshold 1 says it is already the threshold and saves nothing", function()
		click("Flask: warn below 1", "-")
		assert.equal(L.SET_WATCH_SAME, SW.lastStatus)
		assert.equal(1, C.List()[1].threshold, "never below 1")
		assert.is_nil(SB.Config.Get("consumables.watch"), "the default list stays unsaved")
	end)

	it("Remove stops watching an entry", function()
		click("Food: warn below 5", "Remove")
		assert.equal("Flask 1, Potions 5", C.Summary())
		assert.equal("Food is no longer watched.", SW.lastStatus)
	end)

	it("AC11.2: an item dropped on the drop target is watched (threshold 1) and leaves the cursor", function()
		A.cursor = { itemID = Fixtures.HEALING_POTION, link = "item:211880" }
		Fake.Fire(rowButton(L.SET_WATCH_ADD, L.SET_WATCH_DROP), "OnReceiveDrag")
		assert.equal("Flask 1, Potions 5, Food 5, Algari Healing Potion 1", C.Summary())
		assert.equal("Now watching Algari Healing Potion (warns below 1; use + to raise it).", SW.lastStatus)
		assert.is_nil(A.cursor)
	end)

	it("a click on the drop target while holding an item does the same; an empty cursor explains", function()
		click(L.SET_WATCH_ADD, L.SET_WATCH_DROP)
		assert.equal(L.SET_WATCH_DROP_EMPTY, SW.lastStatus)
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		click(L.SET_WATCH_ADD, L.SET_WATCH_DROP)
		assert.equal("Flask 1, Potions 5, Food 5, Flask of Alchemical Chaos 1", C.Summary())
	end)

	-- Mutation: call A.ClearCursor() before C.Add in onDrop.
	it("an item already watched, or read-only settings, keep the item on the cursor with the reason", function()
		C.Add(Fixtures.FLASK)
		SW.Render()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		click(L.SET_WATCH_ADD, L.SET_WATCH_DROP)
		assert.equal(L.SET_WATCH_KNOWN, SW.lastStatus)
		assert.truthy(A.cursor)
		SB.Config.readOnly = true
		A.cursor = { itemID = Fixtures.HEALING_POTION, link = "item:211880" }
		click(L.SET_WATCH_ADD, L.SET_WATCH_DROP)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		assert.truthy(A.cursor)
		click("Flask: warn below 1", "+")
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
	end)

	it("Check now prints the result whatever the rate limit; Reset to default restores the list", function()
		SB.eventFrame:Fire("CHALLENGE_MODE_START")
		click(L.SET_WATCH_TOOLS, L.SET_CHECK_NOW)
		assert.same({ "Low: Food (0/5)", "Low: Food (0/5)" }, A.Lines())
		assert.equal(L.SET_WATCH_CHECKED, SW.lastStatus)
		click("Food: warn below 5", "Remove")
		click(L.SET_WATCH_TOOLS, L.SET_RESET_DEFAULT)
		assert.equal("Flask 1, Potions 5, Food 5", C.Summary())
	end)

	it("the warning switch runs /swagbag consumables on|off", function()
		click(L.SET_WATCH_WARN, L.SET_OFF)
		assert.equal(false, SB.Config.Get("consumables.warn"))
		assert.equal(L.CONSUMABLES_OFF, SW.lastStatus)
	end)
end)
