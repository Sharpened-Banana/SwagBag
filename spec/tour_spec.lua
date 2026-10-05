-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 12 (spec F7, AC7.3): the guided tour of the bag window (UI/Tour.lua): /swagbag tour, a note next to each part,
-- Back / Next / End, and it ends cleanly when the bags close or combat starts. It only points: nothing moves.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("The guided tour (week 12)", function()
	local SB, A, T, W, header, bankHeader, L
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A, L = SB.Adapter, SB.L
		SB.Config.Init(nil, nil)
		Fake.Install()
		-- A stand-in bags window: the parts the tour points at, and counters for anything that would move an item.
		W = { frame = Fake.New("Frame", UIParent), modeButton = Fake.New("Button"), sortButton = Fake.New("Button"),
			moved = 0, opened = 0 }
		W.child = Fake.New("Frame", W.frame)
		W.frame.shown = false
		function W.IsOpen() return W.frame.shown end
		function W.Open()
			W.opened = W.opened + 1
			W.frame:Show()
			return true
		end
		function W.Close() W.frame:Hide() end
		for _, name in ipairs({ "RequestLayout", "Reflow", "Sort", "Layout", "Restack", "ToggleSection", "SetView" }) do
			W[name] = function() W.moved = W.moved + 1 end
		end
		W.frame:SetScript("OnHide", function() SB.Emit("SB_BAGS_CLOSED") end)
		SB.BagsWindow = W
		bankHeader = Fake.New("Button", Fake.New("Frame"))
		header = Fake.New("Button", W.child)
		SB.SectionHeaders = { inUse = { bankHeader, header } }
		SB.SearchBox = { editBox = Fake.New("EditBox", W.frame) }
		Loader.LoadFile(SB, "SwagBag/UI/Tour.lua")
		T = SB.Tour
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function anchor()
		return T.frame.points[1] and T.frame.points[1][2]
	end

	-- Final review. Mutation: in Tour.Start, drop the SB.QuickSetup.AnswerOffer() call.
	it("started while the tour offer is showing: the offer is answered once, and a refused start leaves it", function()
		local answered = 0
		SB.QuickSetup = { AnswerOffer = function() answered = answered + 1 end }
		A.combat = true
		assert.equal(L.TOUR_COMBAT, T.Start())
		assert.equal(0, answered)
		A.combat = false
		assert.equal(L.TOUR_STARTED, T.Start())
		assert.equal(1, answered)
		SB.QuickSetup = nil
		T.End("ended")
		assert.equal(L.TOUR_STARTED, T.Start())
	end)

	-- AC7.3. Mutation: in firstHeader, `if h:GetParent() == W.child then` -> `if true then` (the bank's header would be
	-- pointed at).
	it("AC7.3: /swagbag tour opens the bags and puts the first note next to the bags' first section header", function()
		SB.Slash.Dispatch("tour")
		assert.same({ L.TOUR_STARTED }, A.Lines())
		assert.equal(1, W.opened)
		assert.truthy(T.frame.shown)
		assert.equal(L.TOUR_HEADERS, T.frame.text.text)
		assert.equal("1 of 7", T.frame.count.text)
		assert.equal(header, anchor())
		assert.equal(header, T.target)
		assert.truthy(T.ring.shown, "a thin frame around the header")
		assert.falsy(T.backButton.shown)
		assert.equal(L.TOUR_NEXT, T.nextButton.text)
	end)

	-- Mutation: in Tour.Next, `if Tour.step >= #Tour.STEPS then` -> `if Tour.step > #Tour.STEPS then`.
	it("Next and Back walk the seven notes, each next to its part; Next on the last ends the tour with one line", function()
		T.Start()
		local seen, texts = { T.target }, { T.frame.text.text }
		for _ = 2, 7 do
			Fake.Fire(T.nextButton, "OnClick")
			seen[#seen + 1] = T.target
			texts[#texts + 1] = T.frame.text.text
		end
		assert.same({ header, header, header, SB.SearchBox.editBox, W.modeButton, W.sortButton, W.frame }, seen)
		assert.same({ L.TOUR_HEADERS, L.TOUR_COLLAPSE, L.TOUR_PEEK, L.TOUR_SEARCH, L.TOUR_MODES, L.TOUR_SORT, L.TOUR_SAFE },
			texts)
		assert.equal(L.TOUR_DONE, T.nextButton.text)
		assert.falsy(T.ring.shown, "the last note sits beside the window, no frame to draw")
		Fake.Fire(T.backButton, "OnClick")
		assert.equal(W.sortButton, T.target)
		Fake.Fire(T.nextButton, "OnClick")
		Fake.Fire(T.nextButton, "OnClick")
		assert.is_nil(T.step)
		assert.falsy(T.frame.shown)
		assert.same({ L.TOUR_FINISHED }, A.Lines())
		assert.truthy(W.frame.shown, "the bags stay open")
	end)

	-- Mutation: in show(), `if not (target and target:IsShown()) then` -> `if not target then`.
	it("a part that isn't drawn (no section headers in the grid view): the note sits beside the window, same words", function()
		header.shown = false
		T.Start()
		assert.equal(W.frame, anchor())
		assert.equal(W.frame, T.target)
		assert.equal(L.TOUR_HEADERS, T.frame.text.text)
		assert.falsy(T.ring.shown)
	end)

	-- Mutation: drop the SB_BAGS_CLOSED listener.
	it("the bags closing ends it: the note goes, one line, once", function()
		T.Start()
		Fake.Fire(T.nextButton, "OnClick")
		W.Close()
		assert.is_nil(T.step)
		assert.falsy(T.frame.shown)
		assert.falsy(T.ring.shown)
		assert.same({ L.TOUR_ENDED_CLOSED }, A.Lines())
		T.frame:Hide()
		assert.same({ L.TOUR_ENDED_CLOSED }, A.Lines(), "no second line")
	end)

	-- Mutation: drop the PLAYER_REGEN_DISABLED listener.
	it("combat starting ends it at once, with one line; the bags stay as they are", function()
		T.Start()
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		assert.is_nil(T.step)
		assert.falsy(T.frame.shown)
		assert.same({ L.TOUR_ENDED_COMBAT }, A.Lines())
		assert.truthy(W.frame.shown)
	end)

	-- Mutation: in Tour.Start, drop the `if SB.Adapter.InCombat() then return L.TOUR_COMBAT` branch.
	it("refused in combat, while the bags are Blizzard's, or when they can't open; nothing is shown", function()
		A.combat = true
		SB.Slash.Dispatch("tour")
		A.combat = false
		SB.SafeMode.Enable("bags", "manual")
		SB.Slash.Dispatch("tour")
		SB.SafeMode.Disable("bags")
		function W.Open() return false end
		SB.Slash.Dispatch("tour")
		local lines = A.Lines()
		assert.same({ L.TOUR_COMBAT, L.TOUR_SAFE_MODE, L.TOUR_NO_BAGS }, { lines[1], lines[#lines - 1], lines[#lines] })
		assert.falsy(T.frame.shown)
		assert.is_nil(T.step)
		assert.equal(0, W.opened)
	end)

	-- Mutation: in the note's OnHide, drop `Tour.End("ended")`.
	it("End tour and Esc stop it with one line; nothing in the bags moved, sorted or was laid out", function()
		T.Start()
		Fake.Fire(T.nextButton, "OnClick")
		Fake.Fire(T.endButton, "OnClick")
		assert.same({ L.TOUR_ENDED }, A.Lines())
		T.Start()
		T.frame:Hide() -- Esc
		assert.is_nil(T.step)
		assert.falsy(T.ring.shown)
		assert.same({ L.TOUR_ENDED, L.TOUR_ENDED }, A.Lines())
		assert.equal(0, W.moved)
	end)

	-- Mutation: drop the SB_BAGS_LAYOUT listener.
	it("the bags laid out again (a view change) while it runs: the note points again", function()
		T.Start()
		local other = Fake.New("Button", W.child)
		header.shown = false
		SB.SectionHeaders.inUse = { other }
		SB.Emit("SB_BAGS_LAYOUT")
		assert.equal(other, T.target)
		assert.equal(other, anchor())
		assert.equal(1, T.step)
	end)

	it("every note's words are in enUS.lua; only plain frames", function()
		for _, s in ipairs(T.STEPS) do
			assert.truthy(rawget(L, s.text), s.text)
		end
		for _, f in ipairs(Fake.created) do
			assert.truthy(f.kind == "Frame" or f.kind == "Button", f.kind)
		end
	end)
end)
