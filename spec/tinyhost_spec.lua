-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")

describe("TinyHost (spec 5.2 tiny mode)", function()
	local SB, A, host, panel, tabs, window
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua" })
		A = SB.Adapter
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		host = SB.TinyHost.New("test", "bank")
		panel = Fake.New("Frame", UIParent)
		panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
		panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 80)
		tabs = Fake.New("Frame", panel)
		tabs:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 22, 2)
		window = Fake.New("Frame", UIParent)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	it("Shrink keeps the frame shown inside a 1x1 parent at scale 0.001", function()
		Fake.Strict(panel)
		assert.truthy(host.Shrink(panel))
		local tiny = SB.TinyHost.Parent()
		assert.equal(tiny, panel.parent)
		assert.equal(0.001, tiny.scale)
		assert.equal(true, panel.shown)
		assert.same({}, panel.calls, "nothing but the parent changed")
		local writes = {}
		for _, c in ipairs(panel.log) do
			if not (c.name:find("^Get") or c.name:find("^Is")) then
				writes[#writes + 1] = c.name
			end
		end
		assert.same({ "SetParent" }, writes, "the only write on the frame is its parent")
		assert.truthy(host.IsActive())
	end)

	it("Rehost moves a frame onto the window and anchors it with place()", function()
		assert.truthy(host.Rehost(tabs, window, function(f) f:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 12, 2) end))
		assert.equal(window, tabs.parent)
		assert.same({ { "TOPLEFT", window, "BOTTOMLEFT", 12, 2 } }, tabs.points)
	end)

	it("Restore puts every parent and every anchor point back exactly", function()
		host.Shrink(panel)
		host.Rehost(tabs, window, function(f) f:SetPoint("CENTER") end)
		assert.truthy(host.Restore())
		assert.equal(UIParent, panel.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 }, { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 80 } },
			panel.points)
		assert.equal(panel, tabs.parent)
		assert.same({ { "TOPLEFT", panel, "BOTTOMLEFT", 22, 2 } }, tabs.points)
		assert.falsy(host.IsActive())
	end)

	-- Ruling W3-3: the reverse-order Restore hides a second saved entry, so the parents alone
	-- cannot catch it. Mutation: delete the `if not h.byFrame[frame]` guard in remember().
	it("a second Shrink or Rehost never saves SwagBag's own parent as the original", function()
		host.Shrink(panel)
		host.Shrink(panel)
		host.Rehost(tabs, window, function() end)
		host.Rehost(tabs, window, function() end)
		assert.equal(2, #host.entries, "one saved entry per frame")
		assert.equal(UIParent, host.entries[1].parent)
		assert.equal(panel, host.entries[2].parent)
		host.Restore()
		assert.equal(UIParent, panel.parent)
		assert.equal(panel, tabs.parent)
	end)

	it("in combat Shrink and Rehost change nothing", function()
		A.combat = true
		assert.falsy(host.Shrink(panel))
		assert.falsy(host.Rehost(tabs, window, function() end))
		assert.equal(UIParent, panel.parent)
		assert.equal(panel, tabs.parent)
		assert.falsy(host.IsActive())
	end)

	it("Restore in combat waits for combat to end, then puts everything back", function()
		host.Shrink(panel)
		A.combat = true
		assert.falsy(host.Restore())
		assert.equal(SB.TinyHost.Parent(), panel.parent)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(UIParent, panel.parent)
	end)

	-- Ruling W3-1: a bank closed and reopened inside one fight keeps Blizzard's frame tiny.
	-- Mutation: drop the `if gen ~= h.gen then return end` check in host.Restore.
	it("Keep cancels a Restore that waits for combat; nothing moves when combat ends", function()
		host.Shrink(panel)
		A.combat = true
		assert.falsy(host.Restore())
		host.Keep()
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(SB.TinyHost.Parent(), panel.parent)
		assert.truthy(host.IsActive())
		assert.truthy(host.Restore())
		assert.equal(UIParent, panel.parent)
	end)
end)
