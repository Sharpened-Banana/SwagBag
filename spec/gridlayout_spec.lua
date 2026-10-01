local Loader = dofile("spec/helpers/loader.lua")

local OPTS = { columns = 4, size = 37, gap = 4, padding = 4 }

describe("GridLayout", function()
	local Grid
	before_each(function()
		Grid = Loader.New({ "SwagBag/Engine/GridLayout.lua" }).GridLayout
	end)

	it("flows slots of consecutive bags through one grid in physical order", function()
		local g = Grid.Compute({ { bag = 0, size = 3 }, { bag = 1, size = 3 } }, OPTS)
		assert.equal(6, g.count)
		assert.equal(2, g.rows)
		assert.same({ bag = 0, slot = 1, x = 4, y = -4 }, g.cells[1])
		assert.same({ bag = 0, slot = 3, x = 86, y = -4 }, g.cells[3])
		assert.same({ bag = 1, slot = 1, x = 127, y = -4 }, g.cells[4])
		assert.same({ bag = 1, slot = 2, x = 4, y = -45 }, g.cells[5])
	end)

	it("computes width and height including padding and gaps", function()
		local g = Grid.Compute({ { bag = 0, size = 5 } }, OPTS)
		assert.equal(4 * 2 + 4 * 37 + 3 * 4, g.width)
		assert.equal(4 * 2 + 2 * 37 + 1 * 4, g.height)
	end)

	it("handles no slots at all", function()
		local g = Grid.Compute({}, OPTS)
		assert.equal(0, g.count)
		assert.equal(0, g.rows)
		assert.equal(8, g.height)
	end)

	it("ClampOffset keeps the view inside the content (bank-close case)", function()
		assert.equal(0, Grid.ClampOffset(120, 300, 400))
		assert.equal(200, Grid.ClampOffset(350, 600, 400))
		assert.equal(150, Grid.ClampOffset(150, 600, 400))
		assert.equal(0, Grid.ClampOffset(-5, 600, 400))
	end)

	it("ClampScale keeps the scale between 50% and 200%", function()
		assert.equal(0.5, Grid.ClampScale(0.3))
		assert.equal(2.0, Grid.ClampScale(2.5))
		assert.equal(1.25, Grid.ClampScale(1.25))
	end)
end)
