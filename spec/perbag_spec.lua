local Loader = dofile("spec/helpers/loader.lua")

-- Layout.Position's convention for a section (Engine/Layout.lua), with top = 0:
--   header y = -(top + padding) for the first section
--   first row of slots y = -(top + padding + header)         (no gap under the header)
--   a section's slot area is rows * (size + gap) - gap tall  (none when collapsed)
--   next header y = this header y - header - area - sectionGap
--   height = top + padding + sum(header + area + sectionGap) + padding
local OPTS = { columns = 12, size = 37, gap = 4, padding = 4, header = 20, sectionGap = 6 }
local STEP = OPTS.size + OPTS.gap

local function area(rows)
	return rows * STEP - OPTS.gap
end

describe("PerBag", function()
	local PerBag
	before_each(function()
		local SB = Loader.New({ "SwagBag/Engine/GridLayout.lua", "SwagBag/Engine/PerBag.lua" })
		PerBag = SB.PerBag
	end)

	it("one section per bag in the order given, slots in physical order", function()
		local pos = PerBag.Compute({ { bag = 0, size = 16 }, { bag = 1, size = 20 } }, OPTS, {})
		assert.equal("bag:0", pos.headers[1].id)
		assert.equal("bag:1", pos.headers[2].id)
		assert.equal(2, #pos.headers)
		local row1 = -(OPTS.padding + OPTS.header)
		assert.same({ bag = 0, slot = 1, x = OPTS.padding, y = row1, shown = true }, pos.cells[1])
		assert.equal(row1 - STEP, pos.cells[13].y, "slot 13 starts row 2")
		assert.equal(0, pos.cells[13].slot - 13)
		assert.equal(OPTS.padding, pos.cells[13].x)
		assert.equal(-OPTS.padding, pos.headers[1].y)
		local second = -(OPTS.padding + OPTS.header + area(2) + OPTS.sectionGap)
		assert.equal(second, pos.headers[2].y)
		assert.same({ bag = 1, slot = 1, x = OPTS.padding, y = second - OPTS.header, shown = true }, pos.cells[17])
		assert.equal(16, pos.headers[1].size)
		assert.equal(1, pos.headers[2].bag)
		assert.equal(36, #pos.cells)
		local total = OPTS.padding + (OPTS.header + area(2) + OPTS.sectionGap)
			+ (OPTS.header + area(2) + OPTS.sectionGap) + OPTS.padding
		assert.equal(total, pos.height)
	end)

	it("width is the grid width for the columns, even for a bag with fewer slots than a row", function()
		local pos = PerBag.Compute({ { bag = 2, size = 3 } }, OPTS, {})
		assert.equal(OPTS.padding * 2 + 12 * 37 + 11 * 4, pos.width)
	end)

	it("top moves everything down, and height includes it", function()
		local o = { columns = 12, size = 37, gap = 4, padding = 4, header = 20, sectionGap = 6, top = 50 }
		local pos = PerBag.Compute({ { bag = 0, size = 4 } }, o, {})
		assert.equal(-(50 + 4), pos.headers[1].y)
		assert.equal(-(50 + 4 + 20), pos.cells[1].y)
		assert.equal(50 + 4 + 20 + area(1) + 6 + 4, pos.height)
	end)

	-- Review Focus 3. Mutation: drop the `size > 0` test in PerBag.Compute.
	it("a bag of size 0 has no section", function()
		local pos = PerBag.Compute({ { bag = 1, size = 0 }, { bag = 2, size = 5 } }, OPTS, {})
		assert.equal(1, #pos.headers)
		assert.equal("bag:2", pos.headers[1].id)
		assert.equal(-OPTS.padding, pos.headers[1].y, "nothing was reserved for the empty bag")
		local none = PerBag.Compute({ { bag = 1, size = 0 } }, OPTS, {})
		assert.same({}, none.headers)
		assert.same({}, none.cells)
		assert.equal(OPTS.padding * 2, none.height)
	end)

	it("a collapsed bag keeps its header, hides its cells and takes no height", function()
		local bags = { { bag = 0, size = 16 }, { bag = 1, size = 20 } }
		local open = PerBag.Compute(bags, OPTS, {})
		local shut = PerBag.Compute(bags, OPTS, { [PerBag.Id(0)] = true })
		assert.equal(true, shut.headers[1].collapsed)
		assert.equal(false, shut.headers[2].collapsed)
		assert.equal(36, #shut.cells)
		for i = 1, 16 do
			assert.equal(false, shut.cells[i].shown)
		end
		assert.equal(true, shut.cells[17].shown)
		assert.equal(open.headers[2].y + area(2), shut.headers[2].y)
		assert.equal(open.height - area(2), shut.height)
	end)

	it("label: name, slots, free, collapse mark", function()
		assert.equal("- Backpack · 16 slots · 3 free", PerBag.Label("Backpack", 16, 3, false))
		assert.equal("+ Tab 2 · 98 slots · 0 free", PerBag.Label("Tab 2", 98, 0, true))
	end)

	it("Id is the section and collapse key", function()
		assert.equal("bag:7", PerBag.Id(7))
	end)
end)
