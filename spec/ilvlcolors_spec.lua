-- Item-level colors (Engine/IlvlColors.lua): the steps text, the pick rule, the fill from the equipped level.
local Loader = dofile("spec/helpers/loader.lua")

describe("IlvlColors", function()
	local SB, IC
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
			"SwagBag/Core/Config.lua", "SwagBag/Engine/IlvlColors.lua" })
		SB.Config.Init(nil, nil)
		IC = SB.IlvlColors
	end)

	local function levels(steps)
		local out = {}
		for i, s in ipairs(steps) do
			out[i] = s.level
		end
		return out
	end

	it("parses, drops bad parts, keeps at most 4", function()
		local steps = IC.Parse("680:green,abc,690:pink,0:blue,700:purple,710:orange,720:gray,730:white")
		assert.same({ 680, 700, 710, 720 }, levels(steps))
		assert.equal("purple", steps[2].color)
		assert.same({ 1, 9999 }, levels(IC.Parse("1:gray,9999:white,10000:green,100000:blue")))
	end)

	it("formats the steps back to text", function()
		assert.equal("680:green,690:blue", IC.Format({ { level = 680, color = "green" }, { level = 690, color = "blue" } }))
		assert.equal("", IC.Format({}))
	end)

	it("picks the highest step reached, rows in any order, white below the lowest", function()
		local steps = IC.Parse("700:purple,680:green")
		assert.is_nil(IC.Pick(steps, 679))
		assert.same(IC.PALETTE.green, { IC.Pick(steps, 680) })
		assert.same(IC.PALETTE.green, { IC.Pick(steps, 699) })
		assert.same(IC.PALETTE.purple, { IC.Pick(steps, 700) })
		assert.same(IC.PALETTE.purple, { IC.Pick(steps, 9000) })
		assert.equal(700, steps[1].level) -- the caller's steps are not re-ordered
	end)

	it("two steps with one level: the earlier row wins", function()
		local steps = IC.Parse("690:blue,680:gray,690:orange,690:green")
		assert.same(IC.PALETTE.blue, { IC.Pick(steps, 690) })
		assert.same(IC.PALETTE.gray, { IC.Pick(steps, 689) })
	end)

	it("off, For gives nil whatever the steps", function()
		SB.Config.Set("overlays.ilvlSteps", "680:green")
		assert.is_nil(IC.For(700))
		SB.Config.Set("overlays.ilvlColors", true)
		assert.same(IC.PALETTE.green, { IC.For(700) })
		assert.is_nil(IC.For(600))
		assert.is_nil(IC.For(nil))
	end)

	it("the parsed steps follow a change of the setting", function()
		SB.Config.Set("overlays.ilvlColors", true)
		SB.Config.Set("overlays.ilvlSteps", "680:green")
		assert.same(IC.PALETTE.green, { IC.For(700) })
		SB.Config.Set("overlays.ilvlSteps", "680:orange")
		assert.same(IC.PALETTE.orange, { IC.For(700) })
	end)

	it("a non-string setting parses to nothing", function()
		assert.same({}, IC.Parse(nil))
		assert.same({}, IC.Parse(42))
		assert.same({}, IC.Parse({}))
		SB.Config.Set("overlays.ilvlColors", true)
		assert.is_nil(IC.Pick({}, 700))
	end)

	it("fills from the equipped level, rounded down", function()
		local steps = IC.Fill(684.7)
		assert.same({ 684, 694, 704 }, levels(steps))
		assert.same({ "green", "blue", "purple" }, { steps[1].color, steps[2].color, steps[3].color })
		assert.same({}, IC.Fill(nil))
		assert.same({}, IC.Fill(0))
		assert.same({}, IC.Fill("x"))
	end)

	it("the defaults: off, no steps", function()
		assert.equal(false, SB.Config.Get("overlays.ilvlColors"))
		assert.equal("", SB.Config.Get("overlays.ilvlSteps"))
	end)
end)
