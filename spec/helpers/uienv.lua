-- luacheck: globals SetItemButtonTexture SetItemButtonCount SetItemButtonQuality SetItemButtonDesaturated
-- Shared set-up for the week-3 window specs: the engine file list, the paint globals the
-- button pool calls, and loading the bank window with everything it needs.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")

local Env = {}

Env.ENGINE = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua", "SwagBag/Engine/Stacks.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/OverlayData.lua",
	"SwagBag/Engine/Sort.lua",
	"SwagBag/Engine/IlvlColors.lua", -- 0.17 (item-level color steps; the Settings rows edit them)
	"SwagBag/Engine/ItemFacts.lua", -- 0.16.0 (the TOC loads it after Items.lua; last here so the indices above stay)
	"SwagBag/Engine/PerBag.lua", -- 0.17 (the bank's per-tab view; the TOC loads it after GridLayout.lua)
}

-- SetItemButton* record what they were given on the fake button.
function Env.PaintGlobals()
	SetItemButtonTexture = function(b, icon) b.icon = icon end
	SetItemButtonCount = function(b, n) b.count = n end
	SetItemButtonQuality = function(b, q) b.quality = q end
	SetItemButtonDesaturated = function(b, d) b.desaturated = d end
end

function Env.ClearPaintGlobals()
	SetItemButtonTexture, SetItemButtonCount, SetItemButtonQuality, SetItemButtonDesaturated = nil, nil, nil, nil
end

-- A stand-in bags window: the bank window puts "Bank still open" on it and calls its
-- DropOnSection for drops on its headers.
function Env.FakeBags(SB)
	local bags = { frame = Fake.New("Frame", UIParent), sortButton = Fake.New("Button"), dropped = {} }
	function bags.IsOpen() return false end
	function bags.ForEachSlot() end
	function bags.DropOnSection(id) bags.dropped[#bags.dropped + 1] = id end
	function bags.BoundTitle(button) bags.titleBound = button or false end
	SB.BagsWindow = bags
	return bags
end

-- Load the bank window (and the UI files it uses) into SB. Fake.Install() must have run.
function Env.LoadBank(SB)
	if not SB.BagsWindow then
		Env.FakeBags(SB)
	end
	for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/SearchBox.lua",
		"SwagBag/UI/ListRows.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua",
		"SwagBag/UI/BankMenu.lua", "SwagBag/UI/Overlays.lua" }) do
		Loader.LoadFile(SB, path)
	end
	return SB.BankWindow
end

-- Load the guild bank window (and the UI files it uses) into SB. Fake.Install() must have run.
function Env.LoadGuild(SB)
	if not SB.BagsWindow then
		Env.FakeBags(SB)
	end
	for _, path in ipairs({ "SwagBag/Engine/Snapshots.lua", "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua",
		"SwagBag/UI/SearchBox.lua", "SwagBag/UI/ListRows.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua",
		"SwagBag/UI/GuildButtons.lua",
		"SwagBag/UI/GuildBankWindow.lua", "SwagBag/UI/Overlays.lua" }) do
		Loader.LoadFile(SB, path)
	end
	return SB.GuildBankWindow
end

return Env
