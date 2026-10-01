# SwagBag Week 2 (Oct 8–14, 2026): Categorizer, Default Categories, Sections Layout, Placeholders, Collapse, Drag-to-Assign, Sort/Reflow. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** By the end of week 2 the category view is the user's default bag: every item sits in a sensible section, sections collapse and stay collapsed, an item dragged onto a header joins that section, Sort works, and no item ever moves under the cursor while the window is open.

**Architecture:** Week 2 adds four pure-Lua engine modules and wires them into the existing bags window. `Engine/CategoryDefaults.lua` holds the 18 built-in categories (spec §7.6). `Engine/Categories.lua` merges them with the user's diffs (`SwagBagDB.userEdits`, spec §8.5) and user categories, and compiles each query. `Engine/Categorizer.lua` turns an item record into a category id (exclude → include → rules by priority, tri-state blocking, per-category error isolation, memo by cache class). `Engine/Layout.lua` is the spec §4 engine: `Build` (full layout), `Position` (pixels, collapse), `Apply` (the §4.3 transitions while open, with the hover guard). `UI/BagsWindow.lua` gains the category view (default), the grid/categories toggle, pooled section headers (`UI/SectionHeaders.lua`) and placeholders (`UI/Buttons.lua`), drag-onto-header, Sort and Reflow. Task 0 first fixes three residual week-1 defects; Task 1 applies desk spike F's grammar findings.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements spec §12.2 week 2 (M3) plus desk spike F (§7.1, §13.2 item 1). Week-1 plan (style and interfaces): `docs/superpowers/plans/2026-09-30-swagbag-week1-foundations.md`. Week-1 rulings and deferred findings: `docs/superpowers/plans/2026-09-30-swagbag-week1-ledger.md`. Desk spike F output: `docs/research/2026-10-syndicator-grammar-diff.md` (already written during planning; Task 1 commits it).

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**The code on `main` is the source of truth.** Every interface used below was read from the merged week-1 code (commit `635e9cc`, 252 tests), not from the week-1 plan text: `Items.Key` suffixes are `#b`, `#uw`, `#u`; parser error codes include `SHALLOWER` and `AND_BEFORE_COMPARISON`; leaf results are normalised to true/false/nil; `ErrorTrap.Run` never throws; `SafeModeHooks` has `autoOpenedBy` and a `ToggleBag` hook; `Inventory` ignores failed item loads and sets `lastFlush` only on a real flush; `Config` checks for a newer schema before upgrading and keeps backups on `Reset`; `Engine/Search.lua` and `UI/SearchBox.lua` exist.

## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only.
- License: `## X-License: All Rights Reserved`. Clean-room: no code copied from any other addon. Desk spike F read Syndicator (GPL) only to learn its behaviour; its doc describes behaviour in our own words, and no Syndicator code appears in SwagBag.
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator`.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `scripts/check.sh` enforces this with LuaJIT's parser and a `goto` grep.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace or `Enum`, **comments included** (enforced by `scripts/check.sh` for `C_X.`/`Enum.` usage, and by review for bare names). Everything else calls `SB.Adapter.*`. Spec files under `spec/` may name them as test data (ledger ruling, Task 2).
- Forbidden anywhere in `SwagBag/` (spec §5.3, enforced by `scripts/check.sh`, **comments included**): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`. Write "the OpenAllBags hook", never "OpenAllBags(frame)", in comments. `hooksecurefunc("OpenAllBags", …)` is allowed (ledger ruling).
- P2: every command and button gives feedback. Header buttons flash a line in the window title; drag-to-assign prints a chat line.
- P5 / spec §4.2 rule 5: while a window is open, a slot button moves only into New or Free (spec §4.3), never while it is under the mouse and never while an item is on the cursor. Held-back moves retry 300 ms later through `SB.Debounce` (a `C_Timer`), never `OnUpdate`.
- P6: every WoW entry point (events, hooks, `OnClick`/`OnEnter`/`OnHide`/`OnReceiveDrag`/`OnMouseDown` scripts, timers, slash commands) runs inside `SB.ErrorTrap.Run` or `SB.ErrorTrap.Guard`. Never call `seterrorhandler`.
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails if code uses an undefined `L.KEY`.
- Slot buttons: one `ContainerFrameItemButtonTemplate` per (bag, slot), parented to a per-bag frame with `SetID(bag)`. Never reparented, destroyed or re-`SetID`'d. They move only via `ClearAllPoints` + `SetPoint`. Item buttons are never created in combat (growth is queued with `SB.OutOfCombat`). Placeholders and section headers are pooled **plain** frames (spec §4.1) and may be created in combat (ledger ruling P9).
- No `OnUpdate` scripts anywhere. Idle CPU with windows closed is 0.
- Spec §9 budgets that week 2 touches: first bag open ≤ 25 ms; warm open ≤ 10 ms; incremental update ≤ 5 ms for ≤ 10 changed slots; reflow after sort ≤ 40 ms; search keystroke ≤ 4 ms for 200 slots after the 150 ms debounce; `BAG_UPDATE_COOLDOWN` never triggers a rescan. Spec §11.1: the 1,290-slot layout runs in ≤ 20 ms of plain Lua. Spec §7.8: memo tables hold at most 4,000 entries and are dropped whenever any category changes.
- SavedVariables: this plan moves `schemaVersion` from 1 to **2** (Task 2). A newer schema is never touched (Safe Mode plus one message). A failed migration keeps a backup and resets to defaults.
- **Tooling deviation (binding, same as week 1):** tests run with `luajit spec/runner.lua spec/*_spec.lua` using the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Work on branch `week2-categories` (created in Task 0). One commit per task, made with `git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit`. The message ends with exactly these two lines:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`
- In-game checks are written for the user, who is not a programmer. They are numbered, one action per step, and each says what the user should see. In-game sessions do not block the build (ledger ruling); findings come back as fixes.

## Review Focus

1. **Moving items inside the bags while the window is open** (drag to an empty slot, shift-click split, swapping two items, all in one bag update). Expected: exactly one placeholder per vacated section cell, every moved or new stack visible in New, and no other button moves. Pinned by Task 7 (`layout_spec` "section truth: after any sequence of changes…", a 300-step randomized check) and Task 10 (`bagswindow_sections_spec` "a drag to an empty slot and a stack split in one update…").
2. **Items whose data is not loaded yet** (fresh login, new loot, caged pets, keystones). Expected: never mis-filed. A rule that cannot decide holds the item in New; the item joins its section on the next open. Instant facts may still decide (a loading potion is a Consumable). Pinned by Task 4 (`categorizer_spec` "a rule that cannot decide (nil) stops the search…" and "a loading item that instant facts already decide…"), Task 6 (`layout_spec` "New reserves newRows rows… grows to fit every pending item") and Task 10 ("an item whose data loads stays in New until the next open…").
3. **Closing the window (Esc, X, B) or switching views while a move is held back** under the mouse or by an item on the cursor. Expected: no error, no stray placeholder, and the next open is a clean full layout. Pinned by Task 10 ("closing while a move is held back under the mouse is safe…") and Task 9 ("a collapse waits while a button that would move is under the mouse").
4. **Damaged or hand-edited saved category data** (a non-table diff, a string priority, unknown ids in `categoryOrder`, a user category without a query). Expected: loading never errors, damaged parts are ignored, and the rest works. Pinned by Task 2 (`config_spec` "v1 -> v2 repairs damaged category values…") and Task 3 (`categories_spec` "damaged saved category data never breaks loading").
5. **A category rule that throws** for some item type (a keyword bug, an API change). Expected: only that category stops matching. The error is recorded once (not once per item per open), Safe Mode stays off, and every other category keeps working. Pinned by Task 4 (`categorizer_spec` "a rule that throws is isolated…") and Task 5 (`search_spec` "a failing query is recorded once…").

## Decisions and deviations from the spec (read before Task 0)

| # | Spec text | This plan | Why |
|---|---|---|---|
| D1 | §4.3: the Reflow/sort button is "Allowed (verified)" in combat | **Sort** waits until combat ends (queued with `SB.OutOfCombat`, title says so). **Reflow** works in combat. | §9 says "Combat: … no physical sort". The two sections conflict, and the stricter one wins. |
| D2 | §4.3: "New overflows its 2 rows" | New's two rows are **always reserved** at the top while the window is open, even when New is empty. Collapsing New sends arrivals to the end of Free (counted on New's header). | Any section that grows at the top would push everything below it. Fixed capacity is the only reading that keeps P5. The user can collapse New if the empty space bothers them. |
| D3 | AC4.4: unloaded items "go to New" | A loading item whose winning rule is already decided by instant facts (class, slot) is filed directly. Only a rule that returns nil holds the item in New (§7.7 step 4). | §7.7 is the detailed rule, and it means fewer items in New. |
| D4 | §7.7: `itemList.include = { [itemKey] = true }` | Manual lists are keyed by **itemID** (the static key): dragging one Healing Potion files every Healing Potion. All caged pets share itemID 82800. | Users expect "this item goes here" to cover every copy. |
| D5 | §7.6 "Keystone & Crests", "Fish & Lures" | Keystone & Crests matches `keystone` only. The crest allowlist is the §13.2 item 4 data file (week 3, M6). Fish & Lures matches item names `fish | lure | bait`, because the client has no fish subclass. The user files other fish by dragging one onto the header (AC4.3). | No reliable data this week. Matching on the word "crest" would catch gear named "…Crest…". |
| D6 | §8.2 shows `schemaVersion = 1` with `categories`, `categoryOrder` | Week 1 shipped schema 1 without them, so they arrive as **schema 2**, with a v1 → v2 migration. | Week-1 plan, "What week 2 builds on". |
| D7 | §5.5/AC2.7: reflow "after the next BAG_UPDATE_DELAYED" | Reflow runs 0.3 s after the **last** bag update of a sort (debounced), then waits for the mouse to leave the items (rule 5). | A sort can arrive in several batches. Regrouping once avoids a regroup per batch. |
| D8 | §4.3 "Window closes … In combat: Reflow deferred to PLAYER_REGEN_ENABLED plus next open" | The next open always does a full layout, in or out of combat. | Moving and showing buttons in combat is legal (verified), so no deferral is needed. |
| D9 | §4.2 rule 5: "or while a modifier key relevant to the button is down" | Covered by the hover check: a modifier only matters for the button under the mouse, which is already held back. | Same effect, one rule. |
| D10 | §4.3 "Bag size grows … In combat: buttons created on PLAYER_REGEN_ENABLED" | The buttons are created then, but the new slots appear at the next full layout (close and reopen, Reflow). | Rare (no bag swaps in combat), and the spec already accepts "invisible" for that time. |
| D11 | Spike F | Spec §7.2 and §7.5 are **edited** in Task 1 (bare `<N`/`>N`/`=N`/`N` and `N-M` item levels, `~`, `||`, unknown `#keyword` = warning that matches nothing, Syndicator aliases). §13.2 item 1 is marked resolved. | Spike F found that common Baganator strings (`#gear & <536`, `400-450`, `#tradeable loot \| #tradable loot`) failed or silently meant something else. |

Spike F was done during planning (the doc exists). Task 1 is its follow-up: it commits the doc, edits the spec, and changes the grammar.

---

## File structure (end of week 2)

New and changed files only. Everything else is as on `main`.

```
SwagBag/Engine/CategoryDefaults.lua   NEW  the 18 built-in categories (data, spec 7.6)
SwagBag/Engine/Categories.lua         NEW  built-ins + userEdits diffs + user categories; compile; AddToList; order
SwagBag/Engine/Categorizer.lua        NEW  record -> category id; tri-state; error isolation; memo by cache class
SwagBag/Engine/Layout.lua             NEW  spec 4: Build / Position / Moves / Apply (pure)
SwagBag/UI/SectionHeaders.lua         NEW  pooled plain-Button headers: label, click, receive-drag
SwagBag/UI/Buttons.lua                MOD  + placeholder pool (plain Frames, tooltip only)
SwagBag/UI/BagsWindow.lua             REWRITE  category view + grid toggle, collapse, live 4.3 updates, sort, reflow, drop
SwagBag/UI/SafeModeHooks.lua          REWRITE  one-frame-one-action hooks, ToggleBag 0-5 only, forget on close
SwagBag/UI/SearchBox.lua              MOD  error line anchors; soft warning line
SwagBag/Engine/Query/Lexer.lua        REWRITE  ~ and ||
SwagBag/Engine/Query/Parser.lua       MOD  bare item levels <N >N =N N, ranges N-M
SwagBag/Engine/Query/Query.lua        MOD  unknown #keyword = warning; FormatWarning
SwagBag/Engine/Keywords.lua           MOD  Syndicator aliases, `profession`, `one-hand`
SwagBag/Engine/Search.lua             MOD  soft warning; one ring entry per failing query; NeedsVolatileRefresh
SwagBag/Engine/Items.lua              MOD  RefreshVolatile
SwagBag/Core/Config.lua               MOD  schema 2, view/newRows/reagentSeparate defaults
SwagBag/Core/Adapter.lua              MOD  CursorItem, ClearCursor, SortBags, 4 optional checks
SwagBag/Core/Report.lua               MOD  "Categories:" and "Last bags layout:" lines
SwagBag/Core/Commands.lua, Core/Init.lua, SwagBag.toc, Locale/enUS.lua, .luacheckrc   MOD
spec/categories_spec.lua, categorizer_spec.lua, layout_spec.lua, buttons_spec.lua,
spec/adapter_spec.lua, bagswindow_sections_spec.lua, spec/fixtures/big.lua           NEW
docs/research/2026-10-syndicator-grammar-diff.md                                       NEW (committed in Task 1)
docs/superpowers/specs/2026-09-30-swagbag-design.md                                     MOD (§7.1, §7.2, §7.5, §13.2)
```

## Schedule (daily testing; spec §12.2 week 2: "V12 every day")

| Day | Tasks | User in game? |
|---|---|---|
| Thu Oct 8 | 0, 1, 2, 3 | **yes:** session E0 (Task 0: vendor auto-close, bag-bar icons, search error line), about 5 minutes |
| Fri Oct 9 | 4, 5, 6, 7 (all pure Lua, no new in-game behaviour) | normal play on the week-1 grid (category view not wired yet) |
| Sat Oct 10 | 8, 9, 10 | **yes:** session E1 (category view, collapse, toggle, V4, V12 loot/use/vendor/split/drag) |
| Sun Oct 11 | 11 | **yes:** session E2 (drag-to-assign, Sort, Reflow, V12 sort and bank) |
| Mon–Wed Oct 12–14 | fixes from the user's reports | **yes:** daily V12 check (5 minutes, every day); **Week 2 exit check** on Oct 14 |

Tasks 4–7 depend only on Tasks 2–3 and could run in a parallel lane. The only file both lanes touch is `SwagBag/SwagBag.toc` (keep the `# Engine` order shown below).

Cumulative `scripts/check.sh` test totals when tasks run in numeric order (verified by replaying every task on a fresh clone of `main`): start 252 · T0 261 · T1 272 · T2 275 · T3 289 · T4 301 · T5 304 · T6 313 · T7 325 · T8 332 · T9 341 · T10 354 · T11 360.

## How the TOC grows

Same rule as week 1: "append to section X" means directly after the last file line of that section. Final order of the changed sections:

```
# Engine
Engine/Items.lua
Engine/Inventory.lua
Engine/GridLayout.lua
Engine/Query/Lexer.lua
Engine/Query/Parser.lua
Engine/Query/Query.lua
Engine/Keywords.lua
Engine/Search.lua
Engine/CategoryDefaults.lua
Engine/Categories.lua
Engine/Categorizer.lua
Engine/Layout.lua

# UI
UI/ReportBox.lua
UI/Buttons.lua
UI/SectionHeaders.lua
UI/BagsWindow.lua
UI/SafeModeHooks.lua
UI/SearchBox.lua
UI/DebugV1.lua
```

`scripts/check.sh` prints `TOC OK (N files)`: 27 for Tasks 0–2, 29 after Task 3, 30 after Tasks 4–5, 31 after Tasks 6–7 and 32 from Task 8 on.

## How to read the code steps

A step that says **Create** or **Replace the whole file** gives the complete file. A step that says **find … and replace it with …** gives an exact block of the current file (it occurs exactly once) and its replacement. Copy both verbatim, including tabs. Every block in this plan was applied in this order to a fresh clone of `main` and checked with `scripts/check.sh`. The `Expected` lines below are those real outputs.

---
### Task 0: Branch and residual week-1 fixes (search error line, vendor auto-close, ToggleBag guard)

Three findings from the week-1 final review were left for week 2 (ledger lines 92–94). They are user-visible, so they come first.

- **(a)** The search error line is anchored `RIGHT` to the window. That anchor can stretch the line down over the item grid. It should be anchored `TOPRIGHT` to the frame at (-8, -26), top-aligned with the box, and `SetJustifyV("TOP")`.
- **(b)** Blizzard's `OpenAllBags` may call `ToggleBackpack`/`ToggleBag` inside itself, and `ToggleAllBags` may call `OpenAllBags`/`CloseAllBags` inside itself. The inner hook runs **before** the outer one, so today the inner `onBagKey` clears `autoOpenedBy`. The vendor window then never auto-closes, and a B press could even toggle twice. The fix: every hook records what it did in this frame (`lastAt = GetTime()`, `lastKind`), and a second hook in the same frame only corrects the bookkeeping. If an inner toggle opened the window, OpenAllBags claims it as auto-opened. If an inner toggle closed a window the user had open, OpenAllBags opens it again as the user's. If an inner OpenAllBags opened the window, the outer key press makes it the user's. If an inner OpenAllBags found the window already open, it did nothing, so the outer key press still closes the window. If an inner CloseAllBags closed the window, the outer key press does not reopen it.
- **(c)** The `ToggleBag` hook accepts only numeric IDs 0–5. Today `KindOf(nil)` throws, which would flip bags to Safe Mode, and `-1` is treated as a bag. Also, a stale `autoOpenedBy` is cleared whenever the window hides (Esc, X, any close): the window's `OnHide` emits `SB_BAGS_CLOSED`.

The task also fixes the stale comment in `Core/Commands.lua` (ledger P8) and bumps the version to 0.2.0, so the user can see the week-2 build in the loaded line and in the report.

**Files:**
- Modify (replace whole file): `SwagBag/UI/SafeModeHooks.lua`
- Modify: `SwagBag/UI/SearchBox.lua` (error-line anchors), `SwagBag/UI/BagsWindow.lua` (`OnHide`), `SwagBag/Core/Commands.lua` (comment), `SwagBag/Core/Init.lua` and `SwagBag/SwagBag.toc` (version 0.2.0)
- Test: `spec/safemodehooks_spec.lua`, `spec/searchbox_spec.lua`, `spec/bagswindow_spec.lua`

**Interfaces:**
- Consumes: `SB.BagsWindow.IsOpen/Open/Close/Toggle`, `SB.Buttons.created`, `SB.SafeMode.IsOn`, `SB.ErrorTrap.Guard`, `SB.On/Emit`, `SB.Adapter.Now` (all on `main`).
- Produces: internal event `SB_BAGS_CLOSED` (no arguments), emitted from the bags window's `OnHide`. Task 9 extends that handler. `SB.SafeModeHooks` fields `lastAt` (number), `lastKind` (`"toggle"|"auto"|"closed"|"none"`), `toggleOpened` (boolean) and `autoOpenedBy` (frame name, `true`, or nil). `SB.VERSION == "0.2.0"`.

- [ ] **Step 1: Create the branch**

```bash
git checkout main
git status --short
git checkout -b week2-categories
```

Expected: `git status --short` lists only `?? docs/research/` and `?? docs/superpowers/plans/2026-10-01-swagbag-week2-categories.md` (this plan). Both are committed by this plan, in Task 1 and Task 0. Nothing else may be listed. If there is anything else, stop and ask.

- [ ] **Step 2: Write the failing tests**

Let the searchbox fake record every `SetPoint`:

<!-- sbw2:edit T0 04-searchbox-spec-points spec/searchbox_spec.lua -->
In `spec/searchbox_spec.lua`, find:

```lua
			elseif name == "GetTextInsets" then
				return function() return 16 end
```

and replace it with:

```lua
			elseif name == "GetTextInsets" then
				return function() return 16 end
			elseif name == "SetPoint" then
				return function(self, ...) self.points[#self.points + 1] = { ... } end
```

Add the anchor test at the end of `spec/searchbox_spec.lua`:

<!-- sbw2:edit T0 05-searchbox-spec-test spec/searchbox_spec.lua -->
In `spec/searchbox_spec.lua`, find:

```lua
		assert.equal(true, errorLine.calls.SetWordWrap[1])
		assert.equal(2, errorLine.calls.SetMaxLines[1])
	end)
end)
```

and replace it with:

```lua
		assert.equal(true, errorLine.calls.SetWordWrap[1])
		assert.equal(2, errorLine.calls.SetMaxLines[1])
	end)

	it("the error line is top-aligned right of the box and never stretches over the items", function()
		local errorLine
		for _, fs in ipairs(window.frame.created) do
			if fs.calls.SetWordWrap then
				errorLine = fs
			end
		end
		assert.equal(2, #errorLine.points)
		assert.same({ "TOPLEFT", Box.editBox, "TOPRIGHT", 8, 4 }, errorLine.points[1])
		assert.same({ "TOPRIGHT", window.frame, "TOPRIGHT", -8, -26 }, errorLine.points[2])
		assert.equal("TOP", errorLine.calls.SetJustifyV[1])
	end)
end)
```

Add the hook tests at the end of `spec/safemodehooks_spec.lua`:

<!-- sbw2:edit T0 06-safemodehooks-spec spec/safemodehooks_spec.lua -->
In `spec/safemodehooks_spec.lua`, find:

```lua
	it("ToggleBag and ToggleBackpack in the same frame toggle once", function()
		hooks.ToggleBag(1)
		hooks.ToggleBackpack()
		assert.equal(1, toggles)
	end)
end)
```

and replace it with:

```lua
	it("ToggleBag and ToggleBackpack in the same frame toggle once", function()
		hooks.ToggleBag(1)
		hooks.ToggleBackpack()
		assert.equal(1, toggles)
	end)

	-- A Toggle that really opens and closes the fake window.
	local function realToggle()
		SB.BagsWindow.Toggle = function()
			toggles = toggles + 1
			windowOpen = not windowOpen
		end
	end

	it("ToggleBag ignores anything that is not a bag number 0-5 (no toggle, no Safe Mode)", function()
		hooks.ToggleBag(nil)
		hooks.ToggleBag("1")
		hooks.ToggleBag(-1)
		hooks.ToggleBag(6)
		assert.equal(0, toggles)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("an OpenAllBags that toggles the backpack inside still counts as the game's open", function()
		realToggle()
		hooks.ToggleBackpack() -- inner call, same frame
		hooks.OpenAllBags(named("MerchantFrame"))
		assert.equal("MerchantFrame", SB.SafeModeHooks.autoOpenedBy)
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.falsy(windowOpen)
	end)

	it("an OpenAllBags whose inner toggle closed a user-opened window opens it again, still the user's", function()
		realToggle()
		windowOpen = true -- opened with B earlier
		A.Advance(1)
		hooks.ToggleBackpack() -- inner call closes it
		hooks.OpenAllBags(named("MerchantFrame"))
		assert.truthy(windowOpen)
		assert.is_nil(SB.SafeModeHooks.autoOpenedBy)
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.truthy(windowOpen)
	end)

	it("a bag key whose ToggleAllBags opens through OpenAllBags is the user's window", function()
		realToggle()
		hooks.OpenAllBags() -- inner call, same frame
		hooks.ToggleAllBags()
		assert.truthy(windowOpen)
		assert.equal(0, toggles)
		assert.is_nil(SB.SafeModeHooks.autoOpenedBy)
	end)

	it("a bag key whose ToggleAllBags runs OpenAllBags inside, with the window open, still closes it", function()
		realToggle()
		windowOpen = true
		A.Advance(1)
		hooks.OpenAllBags() -- inner call finds the window open and does nothing
		hooks.ToggleAllBags()
		assert.falsy(windowOpen)
		assert.equal(1, toggles)
	end)

	it("a bag key whose ToggleAllBags closes through CloseAllBags() does not reopen", function()
		realToggle()
		windowOpen = true
		A.Advance(1)
		hooks.CloseAllBags() -- inner call, same frame
		hooks.ToggleAllBags()
		assert.falsy(windowOpen)
		assert.equal(0, toggles)
	end)

	it("closing the window with Esc or X forgets that the game opened it", function()
		hooks.OpenAllBags(named("MerchantFrame"))
		assert.equal("MerchantFrame", SB.SafeModeHooks.autoOpenedBy)
		SB.Emit("SB_BAGS_CLOSED")
		assert.is_nil(SB.SafeModeHooks.autoOpenedBy)
	end)
end)
```

Add the `OnHide` test to `spec/bagswindow_spec.lua`:

<!-- sbw2:edit T0 07-bagswindow-spec-onhide spec/bagswindow_spec.lua -->
In `spec/bagswindow_spec.lua`, find:

```lua
	it("runs its handlers inside the error trap", function()
```

and replace it with:

```lua
	it("hiding the window (Esc, X or Close) emits SB_BAGS_CLOSED", function()
		local closed = 0
		SB.On("SB_BAGS_CLOSED", function() closed = closed + 1 end)
		W.Open()
		W.frame.scripts.OnHide(W.frame)
		assert.equal(1, closed)
	end)

	it("runs its handlers inside the error trap", function()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/searchbox_spec.lua; luajit spec/runner.lua spec/safemodehooks_spec.lua; luajit spec/runner.lua spec/bagswindow_spec.lua`
Expected: `7 passed, 1 failed`, then `16 passed, 6 failed`, then `10 passed, 1 failed`. The new ToggleBag test fails because `KindOf("1")` throws and flips Safe Mode. The same-frame tests fail on `autoOpenedBy`/`toggles`. The `OnHide` test fails with `attempt to call field 'OnHide' (a nil value)`. The test "…runs OpenAllBags inside, with the window open, still closes it" already passes: it pins week 1's behaviour, which the new same-frame logic must keep.

- [ ] **Step 4: Replace `SwagBag/UI/SafeModeHooks.lua` with**

<!-- sbw2:file T0 SwagBag/UI/SafeModeHooks.lua -->
```lua
-- SwagBag Safe Mode hooks (spec 10.1, proven in spike S).
-- While SwagBag is active for bags (Safe Mode off and the button pool exists):
--   * B / ToggleAllBags / ToggleBackpack / ToggleBag(0-5) toggle SwagBag's window,
--   * OpenAllBags / CloseAllBags (vendor, mailbox, ...) open/close it,
--   * ContainerFrame1..N and ContainerFrameCombinedBags hide themselves on show.
-- The hooks only check a flag, so flipping Safe Mode is the whole toggle - legal
-- in and out of combat. We never CALL any Blizzard bag-opening function.
--
-- One frame, one action: a Blizzard bag function may call another one inside it
-- (OpenAllBags -> ToggleBackpack, ToggleAllBags -> OpenAllBags/CloseAllBags), and the
-- inner hook runs BEFORE the outer one. So every hook notes what it did in this frame
-- (lastAt = GetTime(), lastKind), and a second hook in the same frame only corrects
-- the bookkeeping instead of toggling again.
local _, SB = ...

-- autoOpenedBy: set when the game's OpenAllBags (vendor, mailbox, ...) opened our window,
-- so only the matching CloseAllBags(frame) closes it again; a window the user opened stays.
-- lastKind: "toggle" (a bag key toggled), "auto" (OpenAllBags opened it), "closed"
-- (CloseAllBags closed it), "none" (OpenAllBags found it already open).
local Hooks = { installed = false, lastAt = -1, lastKind = nil, toggleOpened = false, autoOpenedBy = nil }
SB.SafeModeHooks = Hooks

function Hooks.IsActive()
	return SB.Buttons.created and not SB.SafeMode.IsOn("bags")
end

local function blizzardBagFrames()
	local list = {}
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		local f = _G["ContainerFrame" .. i]
		if f then
			list[#list + 1] = f
		end
	end
	if ContainerFrameCombinedBags then
		list[#list + 1] = ContainerFrameCombinedBags
	end
	return list
end

function Hooks.HideBlizzardBags()
	for _, f in ipairs(blizzardBagFrames()) do
		if f:IsShown() then
			f:Hide()
		end
	end
end

local function frameName(frame)
	return (frame and frame.GetName and frame:GetName()) or true
end

-- B / backpack / bag-bar icon.
local function onBagKey()
	if not Hooks.IsActive() then
		Hooks.autoOpenedBy = nil
		return
	end
	local now = SB.Adapter.Now()
	if now == Hooks.lastAt then
		-- An inner OpenAllBags already opened the window for this key press: it is the
		-- user's window, not the game's. An inner OpenAllBags that found the window open
		-- ("none") did nothing, so this key press still toggles. Anything else already acted.
		if Hooks.lastKind == "auto" then
			Hooks.autoOpenedBy = nil
			Hooks.lastKind = "toggle"
			return
		elseif Hooks.lastKind ~= "none" then
			return
		end
	end
	Hooks.autoOpenedBy = nil
	local W = SB.BagsWindow
	local wasOpen = W.IsOpen()
	W.Toggle()
	Hooks.lastAt, Hooks.lastKind = now, "toggle"
	Hooks.toggleOpened = not wasOpen and W.IsOpen()
end

-- OpenAllBags hook (arg: the frame that wants the bags, e.g. MerchantFrame).
local function onOpenAll(frame)
	if not Hooks.IsActive() then
		return
	end
	local W = SB.BagsWindow
	local now = SB.Adapter.Now()
	if now == Hooks.lastAt then
		-- A toggle hook ran inside this OpenAllBags. If it opened the window, the game
		-- opened it; if it closed a window the user had open, open it again.
		if Hooks.lastKind == "toggle" then
			if Hooks.toggleOpened then
				Hooks.autoOpenedBy = frameName(frame)
			elseif not W.IsOpen() then
				W.Open()
			end
		end
		return
	end
	Hooks.lastAt = now
	if W.IsOpen() then
		Hooks.lastKind = "none"
		return
	end
	if W.Open() then
		Hooks.autoOpenedBy = frameName(frame)
		Hooks.lastKind = "auto"
	end
end

-- CloseAllBags(frame): close only a window the game opened for that frame
-- (CloseAllBags() with no frame always closes).
local function onCloseAll(frame)
	if not Hooks.IsActive() then
		return
	end
	local by = Hooks.autoOpenedBy
	if frame == nil or (by and (by == true or (frame.GetName and frame:GetName() == by))) then
		local wasOpen = SB.BagsWindow.IsOpen()
		SB.BagsWindow.Close()
		Hooks.autoOpenedBy = nil
		if wasOpen then
			Hooks.lastAt, Hooks.lastKind = SB.Adapter.Now(), "closed"
		end
	end
end

function Hooks.Install()
	if Hooks.installed then
		return
	end
	Hooks.installed = true
	local Guard = SB.ErrorTrap.Guard
	hooksecurefunc("ToggleAllBags", Guard("hook:ToggleAllBags", onBagKey, "bags"))
	hooksecurefunc("ToggleBackpack", Guard("hook:ToggleBackpack", onBagKey, "bags"))
	if ToggleBag then
		-- Only the bag-bar IDs 0-5; never bank tabs, nil or other values.
		hooksecurefunc("ToggleBag", Guard("hook:ToggleBag", function(id)
			if type(id) == "number" and id >= 0 and id <= 5 then
				onBagKey()
			end
		end, "bags"))
	end
	hooksecurefunc("OpenAllBags", Guard("hook:OpenAllBags", onOpenAll, "bags"))
	hooksecurefunc("CloseAllBags", Guard("hook:CloseAllBags", onCloseAll, "bags"))
	for _, f in ipairs(blizzardBagFrames()) do
		f:HookScript("OnShow", Guard("hook:BlizzardBagOnShow", function(self)
			if Hooks.IsActive() then
				self:Hide()
			end
		end, "bags"))
	end
	if Hooks.IsActive() then
		Hooks.HideBlizzardBags()
	end
end

-- Safe Mode on: close our window (Blizzard's bags answer the next B press).
-- Safe Mode off: hide any open Blizzard bag frame (ours answers the next B press).
SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window ~= "bags" then
		return
	end
	if on then
		SB.BagsWindow.Close()
	elseif Hooks.installed then
		Hooks.HideBlizzardBags()
	end
end, "none")

-- The window was hidden (Esc, X, or any close): the game no longer owns it.
SB.On("SB_BAGS_CLOSED", function()
	Hooks.autoOpenedBy = nil
end, "bags")

-- Pool created late (login or /reload in combat): SwagBag takes over from here on.
SB.On("SB_BUTTONS_READY", function()
	if Hooks.installed and Hooks.IsActive() then
		Hooks.HideBlizzardBags()
	end
end, "bags")

SB.On("SB_LOGIN", function()
	Hooks.Install()
end, "bags")
```

- [ ] **Step 5: Anchor the search error line, emit `SB_BAGS_CLOSED`, fix the comment, bump the version**

<!-- sbw2:edit T0 01-searchbox-anchors SwagBag/UI/SearchBox.lua -->
In `SwagBag/UI/SearchBox.lua`, find:

```lua
errorLine:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 4)
errorLine:SetPoint("RIGHT", W.frame, "RIGHT", -8, 0)
errorLine:SetJustifyH("LEFT")
```

and replace it with:

```lua
-- Two lines at most, between the box and the window's right edge, top-aligned with
-- the box. Anchored TOPRIGHT (not RIGHT) so it never stretches down over the items.
errorLine:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 4)
errorLine:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -8, -26)
errorLine:SetJustifyH("LEFT")
errorLine:SetJustifyV("TOP")
```

<!-- sbw2:edit T0 02-bagswindow-onhide SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
W.frame = frame
table.insert(UISpecialFrames, "SwagBagBagsWindow")
```

and replace it with:

```lua
W.frame = frame
table.insert(UISpecialFrames, "SwagBagBagsWindow")

-- Esc, the X button and W.Close() all hide the frame; listeners forget per-open state.
frame:SetScript("OnHide", SB.ErrorTrap.Guard("bags.hide", function()
	SB.Emit("SB_BAGS_CLOSED")
end, "bags"))
```

<!-- sbw2:edit T0 03-commands-comment SwagBag/Core/Commands.lua -->
In `SwagBag/Core/Commands.lua`, find:

```lua
-- (help lives in Core/Slash.lua; search is registered by UI/Search.lua.)
```

and replace it with:

```lua
-- (help lives in Core/Slash.lua; search is registered by UI/SearchBox.lua.)
```

<!-- sbw2:edit T0 08-version-init SwagBag/Core/Init.lua -->
In `SwagBag/Core/Init.lua`, find:

```lua
SB.VERSION = "0.1.0"
```

and replace it with:

```lua
SB.VERSION = "0.2.0"
```

<!-- sbw2:edit T0 09-version-toc SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
## Version: 0.1.0
```

and replace it with:

```text
## Version: 0.2.0
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/searchbox_spec.lua; luajit spec/runner.lua spec/safemodehooks_spec.lua; luajit spec/runner.lua spec/bagswindow_spec.lua`
Expected: `8 passed, 0 failed`, `22 passed, 0 failed`, `11 passed, 0 failed`

- [ ] **Step 7: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (27 files)`, `261 passed, 0 failed`, `ALL CHECKS PASSED`. If the forbidden-token step fails on `OpenAllBags(`, a comment contains that text. Reword the comment.

- [ ] **Step 8: Commit**

```bash
git add SwagBag/UI/SafeModeHooks.lua SwagBag/UI/SearchBox.lua SwagBag/UI/BagsWindow.lua SwagBag/Core/Commands.lua \
  SwagBag/Core/Init.lua SwagBag/SwagBag.toc spec/safemodehooks_spec.lua spec/searchbox_spec.lua spec/bagswindow_spec.lua \
  docs/superpowers/plans/2026-10-01-swagbag-week2-categories.md
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 0: search error line anchors, one-action-per-frame bag hooks, ToggleBag 0-5 only" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 9: In-game session E0 (the user does this; about 5 minutes)**

Give the user this checklist exactly. Stand near a vendor.

1. Type `/reload`. Chat shows `SwagBag: v0.2.0 loaded. Type /swagbag help for commands.`
2. Press **B**. The SwagBag window opens.
3. Click the search box and type `boe &` (with the trailing &). A red message appears to the right of the search box, level with the box, on at most two lines. It does **not** cover any items.
4. Click the small **x** in the search box. The red message disappears.
5. Press **B** to close the window. Click one of the bag icons on your bag bar (bottom right of the screen). The SwagBag window opens. Click the same icon again: it closes. Each click opens or closes it exactly once.
6. With the window closed, talk to the vendor. The SwagBag window opens by itself.
7. Close the vendor window (walk away or press Esc). The SwagBag window closes too.
8. Press **B** to open your bags, then talk to the vendor. The window stays open. Close the vendor: **your** window stays open.
9. Press **B** to close it. Talk to the vendor (the window opens), press **Esc** once (the window closes), then close the vendor. Nothing reopens. Press **B**: the window opens normally.
10. Type `/swagbag report`, press Ctrl+C, and paste it into Claude Code. Claude checks the first line says `SwagBag 0.2.0`, `Errors` shows only old entries or `none`, and `Blocked actions: none`.

Pass: steps 3–9 behave as described. If step 7 leaves the window open, say which vendor (this is the case Task 0 hardens).

---

### Task 1: Desk spike F follow-up: Syndicator-compatible grammar and spec §7.2/§7.5

Desk spike F was done during planning. Read `docs/research/2026-10-syndicator-grammar-diff.md` first. Its verdicts:

- **`#`**: same as Syndicator (exact keyword). Keep `#`; the `=word` fallback is not needed.
- **Adjacent words**: a phrase in both. §7.5 item 1 wrongly called this a divergence.
- **`gear<N`**: Syndicator has no `ilvl`/`gear<N`. Its item level is a bare term `<N`, `>N` (both **inclusive**), `=N` or `N`. Published strings such as `#gear & <536` are parse errors in SwagBag today.
- **Ranges**: Syndicator accepts a whole-term `N-M` (inclusive). In SwagBag `400-450` silently becomes a name search.
- **AND_BEFORE_COMPARISON**: harmless divergence. Keep it.
- **Operators**: precedence is the same. `~` means NOT and `||` means OR, and SwagBag lacks both.
- **Unknown `#word`**: Syndicator returns false silently. SwagBag raises a compile error, which breaks imported OR-lists such as `#tradeable loot | #tradable loot`.

This task applies the doc's "must for compatibility" list:

- bare comparisons and `N`, with `<`/`>` inclusive
- `N-M` ranges
- `~` and `||`
- unknown `#keyword` becomes a **warning** that evaluates `false`, shown softly in the search box
- the Syndicator aliases used by published strings

It also writes the doc's replacement text into the spec. Its nice-to-have items (gold terms, expansion words, profession names, tooltip text) are not in this week.

**Files:**
- Modify (replace whole file): `SwagBag/Engine/Query/Lexer.lua`
- Modify: `SwagBag/Engine/Query/Parser.lua`, `SwagBag/Engine/Query/Query.lua`, `SwagBag/Engine/Keywords.lua`, `SwagBag/Engine/Search.lua`, `SwagBag/UI/SearchBox.lua`, `SwagBag/Locale/enUS.lua`, `docs/superpowers/specs/2026-09-30-swagbag-design.md`
- Commit: `docs/research/2026-10-syndicator-grammar-diff.md` (already on disk)
- Test: `spec/query_lexer_spec.lua`, `spec/query_parser_spec.lua`, `spec/query_spec.lua`, `spec/keywords_spec.lua`, `spec/search_spec.lua`, `spec/searchbox_spec.lua`

**Interfaces:**
- Consumes: `SB.QueryLexer.Tokenize`, `SB.QueryParser.Parse`, `SB.Query.Compile/Eval/Validate/FormatError/RegisterKeyword`, `SB.Search.SetText/Apply`, `SB.SearchBox` (all on `main`).
- Produces:
  - Lexer: token `NOT` with value `"~"`, and token `OR` with value `"||"` spanning 2 bytes.
  - Parser: bare `<N`/`>N`/`<=N`/`>=N`/`=N` → `{ type = "num", name = "ilvl", op = "<=" | ">=" | "=" , value, raw }`, where bare `<`/`>` become `<=`/`>=`. A single all-digit word `N` → `ilvl = N`. A single word `N-M` → `{ type = "and", items = { ilvl >= min, ilvl <= max } }`. The `num`/`and` node shapes are unchanged, so `Pretty` round-trips.
  - Compiler: `compiled.warnings = { { kind = "unknown_keyword", value, position } }`. An unknown `#word` compiles to a leaf that returns `false`. `Query.FormatWarning(w) -> string`. `Query.Validate(c).warnings` includes these warnings.
  - Search: `SB.Search.lastWarning` (string or nil) is set by `SetText`. `SearchBox.ClearError()` shows `lastWarning` (or nothing). `/swagbag search` prints the warning as a second line.
  - New keyword aliases: `equipment`, `bwe`, `tradeable loot`, `tradable loot`, `tradeskill`, `battle pet`, `battle pets`, `trash`, `account bound`, `warbound until equipped`, `profession equipment`, `helm`, `cloak`, `bracers`, `gloves`, `belt`, `boots`, `main hand`, `off-hand`, `off hand`, `held in off-hand`, `two-hand`. New keywords: `profession` (item class) and `one-hand` (`INVTYPE_WEAPON`).

- [ ] **Step 1: Write the failing tests**

<!-- sbw2:edit T1 30-lexer-spec spec/query_lexer_spec.lua -->
In `spec/query_lexer_spec.lua`, find:

```lua
	it("reads a quoted string as one STRING token spanning its quotes", function()
```

and replace it with:

```lua
	it("reads ~ as NOT and || as one OR (Syndicator spellings)", function()
		assert.same({ "NOT:~@1-1", "WORD:a@2-2", "OR:||@4-5", "WORD:b@7-7", "EOF:@8-8" }, brief(Lexer.Tokenize("~a || b")))
		assert.same({ "WORD:a@1-1", "OR:||@2-3", "OR:|@4-4", "WORD:b@5-5", "EOF:@6-6" }, brief(Lexer.Tokenize("a|||b")))
	end)

	it("reads a quoted string as one STRING token spanning its quotes", function()
```

<!-- sbw2:edit T1 31-parser-spec spec/query_parser_spec.lua -->
In `spec/query_parser_spec.lua`, find:

```lua
	it("gives & precedence over |", function()
```

and replace it with:

```lua
	it("reads Syndicator-style bare item levels: <N and >N include N, =N and N are equal", function()
		assert.same({ type = "num", name = "ilvl", op = "<=", value = 536, raw = "536" }, parse("<536"))
		assert.same({ type = "num", name = "ilvl", op = ">=", value = 150, raw = "150" }, parse("> 150"))
		assert.same({ type = "num", name = "ilvl", op = "=", value = 536, raw = "536" }, parse("=536"))
		assert.same({ type = "num", name = "ilvl", op = "=", value = 536, raw = "536" }, parse("536"))
		assert.same({ type = "num", name = "ilvl", op = "<=", value = 80, raw = "80" }, parse("<=80"))
		assert.same({ type = "num", name = "ilvl", op = "<=", value = 536, s = 1, e = 4, raw = "536" }, P.Parse("<536"))
	end)

	it("reads N-M as an inclusive item-level range, in either order", function()
		local range = { type = "and", items = {
			{ type = "num", name = "ilvl", op = ">=", value = 400, raw = "400" },
			{ type = "num", name = "ilvl", op = "<=", value = 450, raw = "450" } } }
		assert.same(range, parse("400-450"))
		assert.same(range, parse("450-400"))
	end)

	it("keeps numbers inside phrases and other hyphenated words as name text", function()
		assert.same({ type = "word", value = "potion 2" }, parse("potion 2"))
		assert.same({ type = "word", value = "Ara-Kara" }, parse("Ara-Kara"))
		assert.same({ type = "word", value = "1-2-3" }, parse("1-2-3"))
	end)

	it("combines bare levels with keywords, ~ and || as published Baganator strings do", function()
		assert.same({ type = "and", items = { { type = "exact", value = "gear" },
			{ type = "num", name = "ilvl", op = "<=", value = 536, raw = "536" } } }, parse("#gear&<536"))
		assert.same({ type = "or", items = { { type = "not", item = W("a") }, W("b") } }, parse("~a || b"))
		assert.same({ type = "and", items = { { type = "word", value = "a b" },
			{ type = "num", name = "ilvl", op = ">=", value = 5, raw = "5" } } }, parse("a b & >5"))
	end)

	it("reports a bare comparison without a number", function()
		local _, err = P.Parse("<")
		assert.same({ position = 2, expected = "NUMBER", got = "", after = "<" }, err)
		_, err = P.Parse("#gear & >x")
		assert.same({ position = 10, expected = "NUMBER", got = "x", after = ">" }, err)
	end)

	it("gives & precedence over |", function()
```

Replace the old "unknown `#word` is a positioned error" test, and add the bare item-level test (`spec/query_spec.lua`):

<!-- sbw2:edit T1 32-query-spec-exact spec/query_spec.lua -->
In `spec/query_spec.lua`, find:

```lua
	it("#word forces a keyword and an unknown #word is a positioned error", function()
		assert.equal(true, run("#potion", POTION))
		local c = Q.Compile("boe | #potin")
		assert.is_nil(c.fn)
		assert.same({ { position = 7, expected = "KEYWORD", got = "potin" } }, c.errors)
		assert.is_nil(Q.Eval(c, POTION))
	end)
```

and replace it with:

```lua
	it("#word forces a keyword; an unknown #word is a warning that matches nothing (spec 7.5 #3)", function()
		assert.equal(true, run("#potion", POTION))
		local c = Q.Compile("boe | #potin")
		assert.truthy(c.fn)
		assert.same({}, c.errors)
		assert.same({ { kind = "unknown_keyword", value = "potin", position = 7 } }, c.warnings)
		assert.equal(false, Q.Eval(c, POTION))
		assert.equal(true, Q.Eval(c, RING))
		assert.equal("Unknown keyword \"#potin\" matches nothing (character 7)", Q.FormatWarning(c.warnings[1]))
		assert.same(c.warnings, Q.Validate(c).warnings)
	end)

	it("bare item levels compare like Syndicator: < and > include the number, N-M is inclusive", function()
		assert.equal(true, run("<285", RING))
		assert.equal(true, run(">285", RING))
		assert.equal(false, run("<284", RING))
		assert.equal(true, run("285", RING))
		assert.equal(true, run("280-290", RING))
		assert.equal(true, run("285-285", RING))
		assert.equal(false, run("290-300", RING))
		assert.equal(false, run("<300", POTION), "no item level: false")
		assert.is_nil(run("<300", LOADING), "not loaded yet: nil")
	end)
```

`#potin` is no longer an error, so the error-format test uses another `KEYWORD` error:

<!-- sbw2:edit T1 33-query-spec-format spec/query_spec.lua -->
In `spec/query_spec.lua`, find:

```lua
		assert.equal("Expected a known keyword but found \"potin\" at character 1", Q.FormatError(Q.Compile("#potin").errors[1]))
```

and replace it with:

```lua
		assert.equal("Expected a known keyword but found \"&\" at character 3", Q.FormatError(Q.Compile("# & boe").errors[1]))
```

<!-- sbw2:edit T1 34-query-spec-pretty spec/query_spec.lua -->
In `spec/query_spec.lua`, find:

```lua
			"!(a | b) & !c", "trade goods & count<=5 | tab=2",
		}
```

and replace it with:

```lua
			"!(a | b) & !c", "trade goods & count<=5 | tab=2", "#gear & <536", "400-450 | ~boe", "a || b",
		}
```

The 21 Wago/Baganator strings from the spike F doc go in `spec/keywords_spec.lua`:

<!-- sbw2:edit T1 35-keywords-spec spec/keywords_spec.lua -->
In `spec/keywords_spec.lua`, find:

```lua
	it("location keywords and tab=N", function()
```

and replace it with:

```lua
	it("Syndicator aliases used by published Baganator strings match like our own keywords (spike F)", function()
		assert.same(matching("gear", ALL), matching("equipment", ALL))
		assert.same(matching("boe", ALL), matching("#bwe", ALL))
		assert.same(matching("tradeable", ALL), matching("#tradeable loot | #tradable loot", ALL))
		assert.same(matching("tradegoods", ALL), matching("#tradeskill", ALL))
		assert.same(matching("pet", ALL), matching("#battle pet | #battle pets", ALL))
		assert.same(matching("junk", ALL), matching("trash", ALL))
		assert.same(matching("wue", ALL), matching("warbound until equipped", ALL))
		assert.same(matching("warbound", ALL), matching("account bound", ALL))
		assert.same(matching("head", ALL), matching("helm", ALL))
		assert.same({ 3, 14 }, matching("#gear & >280", ALL))
		assert.same({ 4 }, matching("#gear&<280", ALL))
		assert.same({ 3, 4, 14 }, matching("270-285", ALL))
	end)

	it("published Baganator category strings all compile; unknown #keywords only warn", function()
		local strings = {
			"#key", "#tradeable loot | #tradable loot", "#toy", "#gear & <536", "#gear&<80", "#armor", "#profession",
			"#elemental", "#finishing reagents | #optional reagents | #crafting reagent | #reagent", "#food",
			"!gear & (#leather | #leatherworking)", "#battle pet | #battle pets", "#open", "#cooking | #fish ",
			"#boe | #bwe", "#herb | #alchemy | #inscription", "soulbound", "#tradeskill | #reagent", "#weapon | #off-hand",
			"#tabard | #shirt", "hearthstone",
		}
		local clean = {
			["#tradeable loot | #tradable loot"] = true, ["#gear & <536"] = true, ["#boe | #bwe"] = true,
			["#battle pet | #battle pets"] = true, ["#tradeskill | #reagent"] = true, ["#weapon | #off-hand"] = true,
			["#profession"] = true,
		}
		for _, s in ipairs(strings) do
			local c = Q.Compile(s)
			assert.same({}, c.errors, s)
			assert.truthy(c.fn, s)
			if clean[s] then
				assert.same({}, c.warnings, s)
			end
		end
	end)

	it("location keywords and tab=N", function()
```

<!-- sbw2:edit T1 36-search-spec spec/search_spec.lua -->
In `spec/search_spec.lua`, find:

```lua
	it("a valid search after an error clears the error", function()
```

and replace it with:

```lua
	it("an unknown #keyword applies (matches nothing) and leaves a soft warning", function()
		assert.truthy(S.SetText("#potin"))
		assert.is_nil(S.lastError)
		assert.equal("Unknown keyword \"#potin\" matches nothing (character 1)", S.lastWarning)
		assert.equal(0, (S.Apply(forEach, setDimmed)))
		assert.truthy(S.SetText("potion"))
		assert.is_nil(S.lastWarning)
	end)

	it("a valid search after an error clears the error", function()
```

<!-- sbw2:edit T1 37-searchbox-spec spec/searchbox_spec.lua -->
In `spec/searchbox_spec.lua`, find:

```lua
	it("a failing keyword does not break the window and reports the problem", function()
```

and replace it with:

```lua
	it("an unknown #keyword is a soft warning: the search still applies and the line says why", function()
		open()
		SB.Slash.Dispatch("search #potin")
		assert.equal(2, #printed)
		assert.truthy(printed[1]:find("slots match", 1, true))
		assert.equal("Unknown keyword \"#potin\" matches nothing (character 1)", printed[2])
		local errorLine
		for _, fs in ipairs(window.frame.created) do
			if fs.calls.SetWordWrap then
				errorLine = fs
			end
		end
		assert.equal(printed[2], errorLine.text)
		assert.equal(6, dimCount())
	end)

	it("a failing keyword does not break the window and reports the problem", function()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `for s in query_lexer query_parser query keywords search searchbox; do luajit spec/runner.lua spec/${s}_spec.lua | tail -1; done`
Expected, in order: `15 passed, 1 failed`, `21 passed, 4 failed`, `26 passed, 3 failed`, `14 passed, 2 failed`, `11 passed, 1 failed`, `8 passed, 1 failed`. The new parser test "keeps numbers inside phrases and other hyphenated words as name text" already passes: it pins today's behaviour.

- [ ] **Step 3: Replace `SwagBag/Engine/Query/Lexer.lua` with**

<!-- sbw2:file T1 SwagBag/Engine/Query/Lexer.lua -->
```lua
-- SwagBag query tokenizer (spec 7.2). Pure Lua.
-- Token: { type, value, s, e } with 1-based character span s..e.
-- Spans are byte offsets, not UTF-8 character positions.
-- Types: WORD, STRING, OP (= < <= > >=), AND (&), OR (| or ||), NOT (! or ~),
--        LPAREN, RPAREN, HASH (#), EOF. A WORD is any run of characters that are
--        not whitespace and not one of  & | ! ~ ( ) # " = < >
-- `~` (NOT) and `||` (OR) are Syndicator spellings (spec 7.5 #2).
-- Errors are returned as { position, expected, got } (expected is a code, see Query.FormatError).
local _, SB = ...

local Lexer = {}
SB.QueryLexer = Lexer

local SINGLE = {
	["&"] = "AND", ["|"] = "OR", ["!"] = "NOT", ["~"] = "NOT", ["("] = "LPAREN", [")"] = "RPAREN", ["#"] = "HASH",
}
local STOP = "[%s&|!~()#\"=<>]"

function Lexer.Tokenize(text)
	text = text or ""
	local tokens, i, n = {}, 1, #text
	while i <= n do
		local c = text:sub(i, i)
		if c:find("%s") then
			i = i + 1
		elseif c == "|" and text:sub(i + 1, i + 1) == "|" then
			tokens[#tokens + 1] = { type = "OR", value = "||", s = i, e = i + 1 }
			i = i + 2
		elseif SINGLE[c] then
			tokens[#tokens + 1] = { type = SINGLE[c], value = c, s = i, e = i }
			i = i + 1
		elseif c == "<" or c == ">" then
			if text:sub(i + 1, i + 1) == "=" then
				tokens[#tokens + 1] = { type = "OP", value = c .. "=", s = i, e = i + 1 }
				i = i + 2
			else
				tokens[#tokens + 1] = { type = "OP", value = c, s = i, e = i }
				i = i + 1
			end
		elseif c == "=" then
			tokens[#tokens + 1] = { type = "OP", value = "=", s = i, e = i }
			i = i + 1
		elseif c == "\"" then
			local close = text:find("\"", i + 1, true)
			if not close then
				return nil, { position = n + 1, expected = "QUOTE", got = "" }
			end
			tokens[#tokens + 1] = { type = "STRING", value = text:sub(i + 1, close - 1), s = i, e = close }
			i = close + 1
		else
			local j = text:find(STOP, i) or (n + 1)
			tokens[#tokens + 1] = { type = "WORD", value = text:sub(i, j - 1), s = i, e = j - 1 }
			i = j
		end
	end
	tokens[#tokens + 1] = { type = "EOF", value = "", s = n + 1, e = n + 1 }
	return tokens
end
```

- [ ] **Step 4: Parser: bare item levels and ranges**

<!-- sbw2:edit T1 01-parser-header SwagBag/Engine/Query/Parser.lua -->
In `SwagBag/Engine/Query/Parser.lua`, find:

```lua
--   primary := "(" or ")" | STRING | "#" phrase | phrase [ OP NUMBER ]
--   phrase  := WORD+            adjacent words form ONE phrase (spec 7.5 #1)
```

and replace it with:

```lua
--   primary := "(" or ")" | STRING | "#" phrase | OP NUMBER | phrase [ OP NUMBER ]
--   phrase  := WORD+            adjacent words form ONE phrase (spec 7.5 #1)
-- Syndicator-style item level (spec 7.5 #8), always on the "ilvl" keyword:
--   <N >N =N   bare comparison; < and > INCLUDE N (<536 is ilvl<=536)
--   N          a single all-digit word: ilvl=N
--   N-M        a single word: ilvl>=min(N,M) & ilvl<=max(N,M)
```

<!-- sbw2:edit T1 02-parser-bare SwagBag/Engine/Query/Parser.lua -->
In `SwagBag/Engine/Query/Parser.lua`, find:

```lua
local Parser = {}
SB.QueryParser = Parser
```

and replace it with:

```lua
local Parser = {}
SB.QueryParser = Parser

-- Bare < and > include the number, as in Syndicator.
local INCLUSIVE = { ["<"] = "<=", [">"] = ">=" }

local function levelNode(op, value, raw, s, e)
	return { type = "num", name = "ilvl", op = op, value = value, raw = raw, s = s, e = e }
end
```

<!-- sbw2:edit T1 03-parser-primary SwagBag/Engine/Query/Parser.lua -->
In `SwagBag/Engine/Query/Parser.lua`, find:

```lua
		elseif tok.type == "WORD" then
			local value, s, e, wordCount = phrase()
			if peek().type ~= "OP" then
				return { type = "word", value = value, s = s, e = e }
			end
```

and replace it with:

```lua
		elseif tok.type == "OP" then
			pos = pos + 1
			local num = peek()
			local n = num.type == "WORD" and tonumber(num.value) or nil
			if n == nil then
				fail("NUMBER")
			end
			pos = pos + 1
			return levelNode(INCLUSIVE[tok.value] or tok.value, n, num.value, tok.s, num.e)
		elseif tok.type == "WORD" then
			local value, s, e, wordCount = phrase()
			if peek().type ~= "OP" then
				if wordCount == 1 then
					local lo, hi = value:match("^(%d+)%-(%d+)$")
					if lo then
						lo, hi = tonumber(lo), tonumber(hi)
						if lo > hi then
							lo, hi = hi, lo
						end
						return { type = "and", s = s, e = e, items = {
							levelNode(">=", lo, tostring(lo), s, e), levelNode("<=", hi, tostring(hi), s, e) } }
					elseif value:match("^%d+$") then
						return levelNode("=", tonumber(value), value, s, e)
					end
				end
				return { type = "word", value = value, s = s, e = e }
			end
```

- [ ] **Step 5: Compiler: unknown `#keyword` is a warning**

<!-- sbw2:edit T1 04-query-header SwagBag/Engine/Query/Query.lua -->
In `SwagBag/Engine/Query/Query.lua`, find:

```lua
--   Query.Compile(text) -> { fn, cacheClass, keywords, errors, ast, id, text, empty }
--   Query.Eval(compiled, record) -> true | false | nil   (nil when compiled has errors)
--   Query.Validate(compiled) -> { ok, problems, warnings }
--   Query.Pretty(ast) -> canonical text; Parse(Pretty(ast)) gives the same tree
--   Query.FormatError(err) -> "Expected a value after "&" at character 6"
```

and replace it with:

```lua
--   Query.Compile(text) -> { fn, cacheClass, keywords, errors, warnings, ast, id, text, empty }
--       warnings: { { kind = "unknown_keyword", value, position } } for #word with no such
--       keyword. Like Syndicator, such a term is simply false (spec 7.5 #3); not an error.
--   Query.Eval(compiled, record) -> true | false | nil   (nil when compiled has errors)
--   Query.Validate(compiled) -> { ok, problems, warnings }
--   Query.Pretty(ast) -> canonical text; Parse(Pretty(ast)) gives the same tree
--   Query.FormatError(err) -> "Expected a value after "&" at character 6"
--   Query.FormatWarning(w) -> "Unknown keyword "#potin" matches nothing (character 7)"
```

<!-- sbw2:edit T1 05-query-unknown SwagBag/Engine/Query/Query.lua -->
In `SwagBag/Engine/Query/Query.lua`, find:

```lua
local function unknown()
	return nil
end

function Q.Compile(text)
	text = text or ""
	local compiled = { text = text, keywords = {}, errors = {}, cacheClass = "static" }
```

and replace it with:

```lua
local function unknown()
	return nil
end

local function never()
	return false
end

function Q.Compile(text)
	text = text or ""
	local compiled = { text = text, keywords = {}, errors = {}, warnings = {}, cacheClass = "static" }
```

<!-- sbw2:edit T1 06-query-exact SwagBag/Engine/Query/Query.lua -->
In `SwagBag/Engine/Query/Query.lua`, find:

```lua
			if node.type == "exact" then
				fail(node, "KEYWORD", node.value)
				return unknown
			end
```

and replace it with:

```lua
			if node.type == "exact" then
				compiled.warnings[#compiled.warnings + 1] = { kind = "unknown_keyword", value = node.value, position = node.s }
				return never
			end
```

<!-- sbw2:edit T1 07-query-formatwarning SwagBag/Engine/Query/Query.lua -->
In `SwagBag/Engine/Query/Query.lua`, find:

```lua
local function walk(node, fn)
```

and replace it with:

```lua
function Q.FormatWarning(w)
	return SB.L.QUERY_WARN_UNKNOWN_KEYWORD:format(w.value, w.position)
end

local function walk(node, fn)
```

<!-- sbw2:edit T1 08-query-validate SwagBag/Engine/Query/Query.lua -->
In `SwagBag/Engine/Query/Query.lua`, find:

```lua
		return report
	end
	for _, mode in ipairs(VALIDATE_MODES) do
```

and replace it with:

```lua
		return report
	end
	for _, w in ipairs(compiled.warnings or {}) do
		report.warnings[#report.warnings + 1] = w
	end
	for _, mode in ipairs(VALIDATE_MODES) do
```

<!-- sbw2:edit T1 09-locale SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.QUERY_FOUND_END = "the end of the search"
```

and replace it with:

```lua
L.QUERY_FOUND_END = "the end of the search"
L.QUERY_WARN_UNKNOWN_KEYWORD = "Unknown keyword \"#%s\" matches nothing (character %d)"
```

- [ ] **Step 6: Search and search box show the warning softly**

<!-- sbw2:edit T1 11-search-header SwagBag/Engine/Search.lua -->
In `SwagBag/Engine/Search.lua`, find:

```lua
local S = { active = nil, text = "", lastError = nil, lastEvalError = nil, stats = {} }
```

and replace it with:

```lua
-- lastWarning: a soft message for an applied search (an unknown #keyword matches nothing).
local S = { active = nil, text = "", lastError = nil, lastWarning = nil, lastEvalError = nil, stats = {} }
```

<!-- sbw2:edit T1 10-search-warning SwagBag/Engine/Search.lua -->
In `SwagBag/Engine/Search.lua`, find:

```lua
	S.active, S.text, S.lastError = compiled, text, nil
	return true
end
```

and replace it with:

```lua
	S.active, S.text, S.lastError = compiled, text, nil
	local w = compiled.warnings and compiled.warnings[1]
	S.lastWarning = w and SB.Query.FormatWarning(w) or nil
	return true
end
```

<!-- sbw2:edit T1 12-searchbox-clear SwagBag/UI/SearchBox.lua -->
In `SwagBag/UI/SearchBox.lua`, find:

```lua
function Box.ClearError()
	errorLine:SetText("")
	underline:Hide()
end
```

and replace it with:

```lua
-- No error: show the applied search's soft warning (unknown #keyword), if any.
function Box.ClearError()
	errorLine:SetText(SB.Search.lastWarning or "")
	underline:Hide()
end
```

<!-- sbw2:edit T1 13-searchbox-slash SwagBag/UI/SearchBox.lua -->
In `SwagBag/UI/SearchBox.lua`, find:

```lua
	if not SB.Search.IsActive() then
		return L.SEARCH_CLEARED
	end
	return L.SEARCH_RESULT:format(arg, matches, total, ms)
```

and replace it with:

```lua
	if not SB.Search.IsActive() then
		return L.SEARCH_CLEARED
	end
	local result = L.SEARCH_RESULT:format(arg, matches, total, ms)
	if SB.Search.lastWarning then
		return { result, SB.Search.lastWarning }
	end
	return result
```

- [ ] **Step 7: Syndicator aliases in `SwagBag/Engine/Keywords.lua`**

<!-- sbw2:edit T1 14-keywords-header SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
-- Every keyword reads ONLY the item record from Engine/Items.lua.
```

and replace it with:

```lua
-- Every keyword reads ONLY the item record from Engine/Items.lua.
-- Aliases include Syndicator's English spellings used by published Baganator category
-- strings (desk spike F, docs/research/2026-10-syndicator-grammar-diff.md).
```

<!-- sbw2:edit T1 15-keywords-gear SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
		eval = isGear,
		value = itemLevel, -- gear<210: equippable gear under an item level
	})
```

and replace it with:

```lua
		eval = isGear,
		value = itemLevel, -- gear<210: equippable gear under an item level
		aliases = { "equipment" },
	})
```

<!-- sbw2:edit T1 16-keywords-tradegoods SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
	kw("tradegoods", "static", classIs(C.Tradegoods), { "trade goods" })
```

and replace it with:

```lua
	kw("tradegoods", "static", classIs(C.Tradegoods), { "trade goods", "tradeskill" })
```

<!-- sbw2:edit T1 17-keywords-pet SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
		return r.isCagedPet == true or r.classID == C.Battlepet
			or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet)
	end)
```

and replace it with:

```lua
		return r.isCagedPet == true or r.classID == C.Battlepet
			or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet)
	end, { "battle pet", "battle pets" })
```

<!-- sbw2:edit T1 18-keywords-junk SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
	kw("junk", "static", function(r)
		if r.quality == nil then
			return nil
		end
		return r.quality == 0
	end)
```

and replace it with:

```lua
	kw("junk", "static", function(r)
		if r.quality == nil then
			return nil
		end
		return r.quality == 0
	end, { "trash" })
```

<!-- sbw2:edit T1 19-keywords-profession SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
	kw("profession gear", "static", function(r)
		return r.equipLoc == "INVTYPE_PROFESSION_GEAR"
	end)
```

and replace it with:

```lua
	kw("profession gear", "static", function(r)
		return r.equipLoc == "INVTYPE_PROFESSION_GEAR"
	end, { "profession equipment" })
	kw("profession", "static", classIs(C.Profession))
```

<!-- sbw2:edit T1 20-keywords-slots SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
		shirt = { "INVTYPE_BODY" }, tabard = { "INVTYPE_TABARD" }, bag = { "INVTYPE_BAG" },
	}
	for name, locs in pairs(SLOTS) do
		local set = has(locs)
		kw(name, "static", function(r)
			return set[r.equipLoc] == true
		end)
	end
```

and replace it with:

```lua
		shirt = { "INVTYPE_BODY" }, tabard = { "INVTYPE_TABARD" }, bag = { "INVTYPE_BAG" },
		["one-hand"] = { "INVTYPE_WEAPON" },
	}
	local SLOT_ALIASES = {
		head = { "helm" }, back = { "cloak" }, wrist = { "bracers" }, hands = { "gloves" }, waist = { "belt" },
		feet = { "boots" }, mainhand = { "main hand" }, offhand = { "off-hand", "off hand", "held in off-hand" },
		twohand = { "two-hand" },
	}
	for name, locs in pairs(SLOTS) do
		local set = has(locs)
		kw(name, "static", function(r)
			return set[r.equipLoc] == true
		end, SLOT_ALIASES[name])
	end
```

<!-- sbw2:edit T1 21-keywords-boe SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
	kw("boe", "instance", bindKnown(function(r)
		return not r.isBound and not r.isWUE and r.bind == "equip"
	end))
```

and replace it with:

```lua
	kw("boe", "instance", bindKnown(function(r)
		return not r.isBound and not r.isWUE and r.bind == "equip"
	end), { "bwe" })
```

<!-- sbw2:edit T1 22-keywords-warbound SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
	end), { "boa" })
	kw("wue", "instance", function(r)
		return r.isWUE == true or (r.bind == "wue" and not r.isBound)
	end)
```

and replace it with:

```lua
	end), { "boa", "account bound" })
	kw("wue", "instance", function(r)
		return r.isWUE == true or (r.bind == "wue" and not r.isBound)
	end, { "warbound until equipped" })
```

<!-- sbw2:edit T1 23-keywords-tradeable SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
		return not (ACCOUNT[r.bind] or r.bind == "wue" or r.bind == "quest")
	end)
```

and replace it with:

```lua
		return not (ACCOUNT[r.bind] or r.bind == "wue" or r.bind == "quest")
	end, { "tradeable loot", "tradable loot" })
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `for s in query_lexer query_parser query keywords search searchbox; do luajit spec/runner.lua spec/${s}_spec.lua | tail -1; done`
Expected: `16 passed, 0 failed`, `25 passed, 0 failed`, `29 passed, 0 failed`, `16 passed, 0 failed`, `12 passed, 0 failed`, `9 passed, 0 failed`

- [ ] **Step 9: Update the spec (§7.1, §7.2, §7.5, §13.2) with spike F's findings**

<!-- sbw2:edit T1 40-spec-71 docs/superpowers/specs/2026-09-30-swagbag-design.md -->
In `docs/superpowers/specs/2026-09-30-swagbag-design.md`, find:

```markdown
Desk spike F (grammar diff against the Syndicator mirror with 20 popular Wago strings) runs before M2 freezes; its output updates §7.3 and §7.5. Any divergence found there is listed under "Known divergences", never silently absorbed.
```

and replace it with:

```markdown
Desk spike F (grammar diff against the Syndicator v284 mirror and 24 published Wago/Baganator strings) ran on 2026-10-01: `docs/research/2026-10-syndicator-grammar-diff.md`. Its findings are folded into §7.2 and §7.5. Any divergence found there is listed under "Known divergences", never silently absorbed.
```

<!-- sbw2:edit T1 41-spec-72 docs/superpowers/specs/2026-09-30-swagbag-design.md -->
In `docs/superpowers/specs/2026-09-30-swagbag-design.md`, find:

````markdown
expr     := or
or       := and ( "|" and )*
and      := not ( "&" not )*               -- explicit & only; adjacent words are NOT implicit AND (see 7.5)
not      := "!" not | primary
primary  := "(" expr ")" | term
term     := keyword | numeric | exact | text
keyword  := WORD                            -- registered keyword: boe, junk, potion, reagent, ...
numeric  := WORD op NUMBER                  -- ilvl>250, lvl<80, gear<210, count>=5
exact    := "#" WORD                        -- keyword only; never a name-text match
text     := WORD | '"' chars '"'            -- item-name substring (case-insensitive, ASCII-folded in enUS)
op       := "=" | "<" | "<=" | ">" | ">="
```

Precedence: `!` > `&` > `|`; parentheses override. Whitespace around operators is ignored. A bare `WORD` is resolved as: registered keyword if one exists (keyword match), **else** name-text match. `#word` forces keyword. A quoted string is always text. The parser records the character span of every node for error display.
````

and replace it with:

````markdown
expr     := or
or       := and ( ("|" | "||") and )*
and      := not ( "&" not )*               -- explicit & only; adjacent words are NOT implicit AND (see 7.5)
not      := ("!" | "~") not | primary
primary  := "(" expr ")" | term
term     := keyword | numeric | level | range | exact | text
keyword  := WORD                            -- registered keyword: boe, junk, potion, reagent, ...
numeric  := WORD op NUMBER                  -- ilvl>250, lvl<80, gear<210, count>=5 (strict < >)
level    := op NUMBER | DIGITS              -- Syndicator item level: <536 = ilvl<=536, >150 = ilvl>=150, 536 = ilvl=536
range    := DIGITS "-" DIGITS               -- one word: 400-450 = ilvl>=400 & ilvl<=450 (either order)
exact    := "#" WORD                        -- keyword only; never a name-text match; unknown = warning, false
text     := WORD | '"' chars '"'            -- item-name substring (case-insensitive, ASCII-folded in enUS)
op       := "=" | "<" | "<=" | ">" | ">="
```

Precedence: `!` > `&` > `|`; parentheses override. `~` is a synonym for `!` and `||` for `|` (Syndicator spellings). Whitespace around operators is ignored. A bare `WORD` is resolved as: registered keyword if one exists (keyword match), **else** name-text match; a single all-digit word or `N-M` word is an item-level test (`level`, `range`). `#word` forces keyword. A quoted string is always text. The parser records the character span of every node for error display.
````

<!-- sbw2:edit T1 42-spec-75 docs/superpowers/specs/2026-09-30-swagbag-design.md -->
In `docs/superpowers/specs/2026-09-30-swagbag-design.md`, find:

```markdown
1. **Adjacent words are not implicit AND.** `healing potion` is a single text phrase "healing potion", as in Syndicator-style name search. Use `&` for conjunction. (Decision: phrase search is what bag users expect; the critique's `Metal & Stone` parse problem is handled by quoting: the builder auto-quotes values containing operators.)
2. **Precedence is fixed** (`!` > `&` > `|`). Strings relying on left-to-right evaluation may differ; the editor shows the parsed tree so the user sees what will match.
3. **Errors are shown**, not swallowed. A trailing `&` or unbalanced parenthesis marks the category invalid and keeps the previous compiled version active.
4. **Undefined branches are defined.** Numeric comparisons on items lacking the field (ilvl on a potion) evaluate `false`, not `nil`.
5. **Tri-state**: items with unloaded data evaluate `nil` and are held in New rather than mis-filed.
6. **`#` is keyword-only** in both; if desk spike F finds a different Syndicator meaning, we follow Syndicator and move our "exact" prefix to `=word`.
```

and replace it with:

```markdown
Verified against Syndicator v284 by desk spike F (`docs/research/2026-10-syndicator-grammar-diff.md`, 2026-10-01).

1. **Adjacent words are one phrase in both.** `healing potion` is one term; use `&` for conjunction. (Not a divergence; kept for clarity. The builder auto-quotes values containing operators, which handles the critique's `Metal & Stone` case.)
2. **Precedence is the same** (`!` > `&` > `|`, parentheses group). `~` is accepted as a synonym for `!`, and `||` for `|`.
3. **Errors are shown, not swallowed.** Syndicator silently ignores unbalanced parentheses and stray operators; we mark the category invalid and keep the previous compiled version active. Exception: an **unknown `#keyword` is a warning, not an error**. It evaluates `false`, as in Syndicator, so imported OR-lists of alternative spellings keep working.
4. **Undefined branches are defined.** Numeric comparisons on items lacking the field (ilvl on a potion) evaluate `false`, not `nil`.
5. **Tri-state**: items with unloaded data evaluate `nil` and are held in New rather than mis-filed (Syndicator also passes "unknown" through).
6. **`#` is keyword-only in both** (exact keyword: no prefix expansion, no name text). Confirmed by spike F; the `=word` fallback is dropped.
7. **Bare words search item names only.** Syndicator also searches selected tooltip lines and treats a bare word as a keyword *prefix* (`pot` finds potions). We match whole keywords, else the name. The editor hints at the nearest keyword.
8. **Item-level syntax.** Syndicator's bare forms are accepted: `<N`, `>N`, `=N`, `N` and the range `N-M`. Bare `<`/`>` **include** N as in Syndicator (`<536` = `ilvl<=536`), and the range includes both ends. Our named forms `ilvl>N`, `gear<N`, `lvl<N` are SwagBag extensions with **strict** `<`/`>`. A bare number is an item-level test only; it does not also match item names. Our `ilvl` counts equippable gear only; Syndicator reads the tooltip item level of any item.
9. **Quotes** are a SwagBag extension (always name text). In Syndicator `"` is a literal character.
10. **Same word, different meaning:** `upgrade` (ours: has an upgrade track; theirs: is an upgrade for this character) and `bop` (ours: bind type; theirs: currently bound). Both are explained in the editor's keyword help.
11. **A comparison after a multi-word phrase** (`a b ilvl>5`) is a positioned `AND_BEFORE_COMPARISON` error for us; Syndicator treats the whole string as a name search that matches nothing.
12. **Keyword vocabulary.** Syndicator's English spellings used by published category strings are registered as aliases: `equipment`, `bwe`, `tradeable loot`, `tradable loot`, `tradeskill`, `profession`, `profession equipment`, `battle pet(s)`, `off-hand`/`off hand`/`held in off-hand`, `main hand`, `two-hand`, `one-hand`, `trash`, `account bound`, `warbound until equipped`, `helm`, `cloak`, `bracers`, `gloves`, `belt`, `boots`. Subclass and detail keywords we do not have yet (`elemental`, `optional reagents`, `finishing reagents`, `crafting reagent`, `open`, `socket`, expansion and profession names) are unknown `#keywords` (rule 3) until they are registered.
```

<!-- sbw2:edit T1 43-spec-132 docs/superpowers/specs/2026-09-30-swagbag-design.md -->
In `docs/superpowers/specs/2026-09-30-swagbag-design.md`, find:

```markdown
1. Desk spike F: exact Syndicator semantics of `#`, `gear<N`, and whether adjacent words are phrase or AND; update §7.5 (M2).
```

and replace it with:

```markdown
1. ~~Desk spike F: exact Syndicator semantics of `#`, `gear<N`, and whether adjacent words are phrase or AND; update §7.5 (M2).~~ Resolved 2026-10-01: see §7.2, §7.5 and `docs/research/2026-10-syndicator-grammar-diff.md`.
```

- [ ] **Step 10: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (27 files)`, `272 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 11: Commit**

```bash
git add SwagBag/Engine/Query/Lexer.lua SwagBag/Engine/Query/Parser.lua SwagBag/Engine/Query/Query.lua \
  SwagBag/Engine/Keywords.lua SwagBag/Engine/Search.lua SwagBag/UI/SearchBox.lua SwagBag/Locale/enUS.lua \
  spec/query_lexer_spec.lua spec/query_parser_spec.lua spec/query_spec.lua spec/keywords_spec.lua spec/search_spec.lua \
  spec/searchbox_spec.lua docs/research/2026-10-syndicator-grammar-diff.md docs/superpowers/specs/2026-09-30-swagbag-design.md
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 1: desk spike F - bare item levels, ranges, ~ and ||, unknown #keyword warns, Syndicator aliases" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 2: Config schema 2 (category storage, collapse state, view settings)

Spec §8.2/§8.5 put the categories in `SwagBagDB`, and the per-character UI state (collapse) in `SwagBagCharDB.ui.collapsed`. Week 1 shipped schema 1 without them, so this task adds a v1 → v2 migration (deviation D6). Built-in categories are **never** stored. Only the user's diffs (`userEdits[id]`) and user-made categories (`categories[id]`) are. `categoryOrder` stays nil until the user reorders sections (not this week).

**Files:**
- Modify: `SwagBag/Core/Config.lua`
- Test: `spec/config_spec.lua`; update the schema number asserted in `spec/boot_spec.lua`, `spec/commands_spec.lua` and `spec/report_spec.lua`

**Interfaces:**
- Consumes: `Config.Init/Get/Set/UI/Reset`, `Config.migrations`, `Config.charMigrations` (on `main`).
- Produces:
  - `Config.CURRENT == 2`.
  - Fresh tables: `SwagBagDB` has `categories = {}`, `userEdits = {}` and no `categoryOrder`. `SwagBagCharDB.ui` has `collapsed = {}`.
  - `Config.migrations[2](db)` makes `db.categories`/`db.userEdits` tables and drops a non-table `categoryOrder`. `Config.charMigrations[2](c)` adds `c.ui.collapsed`.
  - Defaults: `bags.view = "sections"`, `bags.newRows = 2`, `bags.reagentSeparate = false`.
  - The collapse state is `Config.UI().collapsed.bags[sectionId] = true` (written by Task 9).

- [ ] **Step 1: Write the failing tests**

<!-- sbw2:edit T2 10-config-spec-fresh spec/config_spec.lua -->
In `spec/config_spec.lua`, find:

```lua
	it("creates fresh tables at schema 1 when nothing is saved", function()
		assert.equal("new", Config.Init(nil, nil))
		assert.equal(1, Config.db.schemaVersion)
		assert.equal(1, Config.charDB.schemaVersion)
		assert.same({}, Config.db.errors)
		assert.same({ positions = {} }, Config.UI())
	end)
```

and replace it with:

```lua
	it("creates fresh tables at schema 2 when nothing is saved", function()
		assert.equal("new", Config.Init(nil, nil))
		assert.equal(2, Config.db.schemaVersion)
		assert.equal(2, Config.charDB.schemaVersion)
		assert.same({}, Config.db.errors)
		assert.same({}, Config.db.categories)
		assert.same({}, Config.db.userEdits)
		assert.is_nil(Config.db.categoryOrder)
		assert.same({ positions = {}, collapsed = {} }, Config.UI())
	end)

	it("defaults to the category view with two New rows and the reagent bag mixed in", function()
		Config.Init(nil, nil)
		assert.equal("sections", Config.Get("bags.view"))
		assert.equal(2, Config.Get("bags.newRows"))
		assert.equal(false, Config.Get("bags.reagentSeparate"))
	end)

	it("v1 -> v2 adds empty category tables, keeps settings, and gives the character collapse state", function()
		local db = { schemaVersion = 1, settings = { bags = { columns = 8 } }, errors = {}, backups = {} }
		local char = { schemaVersion = 1, overrides = {}, ui = { positions = { bags = { "CENTER" } } }, backups = {} }
		assert.equal("migrated", Config.Init(db, char))
		assert.equal(2, db.schemaVersion)
		assert.same({}, db.categories)
		assert.same({}, db.userEdits)
		assert.equal(8, Config.Get("bags.columns"))
		assert.equal(2, char.schemaVersion)
		assert.same({ positions = { bags = { "CENTER" } }, collapsed = {} }, Config.UI())
	end)

	it("v1 -> v2 repairs damaged category values instead of failing", function()
		local db = { schemaVersion = 1, settings = {}, errors = {}, backups = {}, categories = "x", categoryOrder = 5 }
		assert.equal("migrated", Config.Init(db, nil))
		assert.same({}, db.categories)
		assert.is_nil(db.categoryOrder)
		assert.is_nil(db.backups.v1)
	end)
```

<!-- sbw2:edit T2 11-config-spec-v0 spec/config_spec.lua -->
In `spec/config_spec.lua`, find:

```lua
		assert.equal("migrated", Config.Init(old, { ui = { positions = { bags = { "CENTER" } } } }))
		assert.equal(1, Config.db.schemaVersion)
```

and replace it with:

```lua
		assert.equal("migrated", Config.Init(old, { ui = { positions = { bags = { "CENTER" } } } }))
		assert.equal(2, Config.db.schemaVersion)
```

The synthetic migration test moves up one version, because v1 → v2 is now real:

<!-- sbw2:edit T2 12-config-spec-order spec/config_spec.lua -->
In `spec/config_spec.lua`, find:

```lua
	it("runs migrations in order (synthetic v1 -> v2)", function()
		Config.CURRENT = 2
		local order = {}
		local v1 = Config.migrations[1]
		Config.migrations[1] = function(db) order[#order + 1] = 1; v1(db) end
		Config.migrations[2] = function(db) order[#order + 1] = 2; db.settings.newThing = true end
		Config.charMigrations[2] = function() end
		assert.equal("migrated", Config.Init({}, nil))
		assert.same({ 1, 2 }, order)
		assert.equal(2, Config.db.schemaVersion)
		assert.equal(true, Config.db.settings.newThing)
	end)
```

and replace it with:

```lua
	it("runs migrations in order (synthetic v2 -> v3)", function()
		Config.CURRENT = 3
		local order = {}
		local v1, v2 = Config.migrations[1], Config.migrations[2]
		Config.migrations[1] = function(db) order[#order + 1] = 1; v1(db) end
		Config.migrations[2] = function(db) order[#order + 1] = 2; v2(db) end
		Config.migrations[3] = function(db) order[#order + 1] = 3; db.settings.newThing = true end
		Config.charMigrations[3] = function() end
		assert.equal("migrated", Config.Init({}, nil))
		assert.same({ 1, 2, 3 }, order)
		assert.equal(3, Config.db.schemaVersion)
		assert.equal(true, Config.db.settings.newThing)
		assert.same({}, Config.db.userEdits)
	end)
```

<!-- sbw2:edit T2 13-config-spec-reset spec/config_spec.lua -->
In `spec/config_spec.lua`, find:

```lua
		local db, charDB = Config.Reset()
		assert.falsy(Config.readOnly)
		assert.equal(1, db.schemaVersion)
```

and replace it with:

```lua
		local db, charDB = Config.Reset()
		assert.falsy(Config.readOnly)
		assert.equal(2, db.schemaVersion)
```

<!-- sbw2:edit T2 14-config-spec-reset2 spec/config_spec.lua -->
In `spec/config_spec.lua`, find:

```lua
		-- Verify charDB has the correct schema version
		assert.equal(1, charDB.schemaVersion)
```

and replace it with:

```lua
		-- Verify charDB has the correct schema version
		assert.equal(2, charDB.schemaVersion)
```

<!-- sbw2:edit T2 15-boot-spec spec/boot_spec.lua -->
In `spec/boot_spec.lua`, find:

```lua
		assert.equal(1, SwagBagDB.schemaVersion)
```

and replace it with:

```lua
		assert.equal(2, SwagBagDB.schemaVersion)
```

<!-- sbw2:edit T2 16-commands-spec spec/commands_spec.lua -->
In `spec/commands_spec.lua`, find:

```lua
		assert.equal(1, SwagBagDB.schemaVersion)
```

and replace it with:

```lua
		assert.equal(2, SwagBagDB.schemaVersion)
```

<!-- sbw2:edit T2 17-report-spec spec/report_spec.lua -->
In `spec/report_spec.lua`, find:

```lua
			"Settings hash: " .. SB.Report.Hash({}) .. "  Schema: 1  Buttons: 0 (0 ms)",
```

and replace it with:

```lua
			"Settings hash: " .. SB.Report.Hash({}) .. "  Schema: 2  Buttons: 0 (0 ms)",
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `for s in config boot commands report; do luajit spec/runner.lua spec/${s}_spec.lua | tail -1; done`
Expected: `9 passed, 8 failed`, `9 passed, 1 failed`, `10 passed, 1 failed`, `4 passed, 1 failed`

- [ ] **Step 3: Implement schema 2 in `SwagBag/Core/Config.lua`**

<!-- sbw2:edit T2 01-config-header SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
-- failing migration keeps a backup under db.backups["v<old>"] and resets.
local _, SB = ...

local Config = { CURRENT = 1, migrations = {}, charMigrations = {} }
SB.Config = Config

Config.Defaults = {
	settings = {
		bags = { columns = 12, scale = 1.0 },
		safeMode = { bags = false, bank = false },
	},
}
```

and replace it with:

```lua
-- failing migration keeps a backup under db.backups["v<old>"] and resets.
-- Schema 2 (spec 8.2, 8.5): SwagBagDB.categories (user categories), .userEdits (diffs
-- of built-in categories; built-ins themselves are never stored), .categoryOrder (nil =
-- default order); SwagBagCharDB.ui.collapsed[window][sectionId] = true.
local _, SB = ...

local Config = { CURRENT = 2, migrations = {}, charMigrations = {} }
SB.Config = Config

Config.Defaults = {
	settings = {
		-- view: "sections" (category view) | "grid"; newRows: rows kept for New while open;
		-- reagentSeparate: show the reagent bag as its own "Reagents" section (spec AC1.4).
		bags = { columns = 12, scale = 1.0, view = "sections", newRows = 2, reagentSeparate = false },
		safeMode = { bags = false, bank = false },
	},
}
```

<!-- sbw2:edit T2 02-config-new SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
local function newDB()
	return { schemaVersion = Config.CURRENT, settings = {}, errors = {}, backups = {} }
end

local function newCharDB()
	return { schemaVersion = Config.CURRENT, overrides = {}, ui = { positions = {} }, backups = {} }
end
```

and replace it with:

```lua
local function newDB()
	return { schemaVersion = Config.CURRENT, settings = {}, errors = {}, backups = {}, categories = {}, userEdits = {} }
end

local function newCharDB()
	return { schemaVersion = Config.CURRENT, overrides = {}, ui = { positions = {}, collapsed = {} }, backups = {} }
end
```

<!-- sbw2:edit T2 03-config-migrations SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
Config.charMigrations[1] = function(c)
	c.overrides = tableOr(c.overrides)
	c.ui = tableOr(c.ui)
	c.ui.positions = tableOr(c.ui.positions)
	c.backups = tableOr(c.backups)
end
```

and replace it with:

```lua
Config.charMigrations[1] = function(c)
	c.overrides = tableOr(c.overrides)
	c.ui = tableOr(c.ui)
	c.ui.positions = tableOr(c.ui.positions)
	c.backups = tableOr(c.backups)
end

-- v1 -> v2: category storage (week 2). Nothing to convert; damaged values are dropped.
Config.migrations[2] = function(db)
	db.categories = tableOr(db.categories)
	db.userEdits = tableOr(db.userEdits)
	if type(db.categoryOrder) ~= "table" then
		db.categoryOrder = nil
	end
end

Config.charMigrations[2] = function(c)
	c.ui = tableOr(c.ui)
	c.ui.collapsed = tableOr(c.ui.collapsed)
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `for s in config boot commands report; do luajit spec/runner.lua spec/${s}_spec.lua | tail -1; done`
Expected: `17 passed, 0 failed`, `10 passed, 0 failed`, `11 passed, 0 failed`, `5 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (27 files)`, `275 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Config.lua spec/config_spec.lua spec/boot_spec.lua spec/commands_spec.lua spec/report_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 2: schema 2 with category storage, collapse state and view defaults" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

Note for the user (say it once when this build reaches them): a week-2 build upgrades the saved settings to schema 2. If they go back to a week-1 build, it refuses the newer settings and runs in Safe Mode (by design, spec §8.5).

---

### Task 3: Default categories and the Categories model

The 18 built-in categories of spec §7.6, as data. New and Free are layout sections, not categories. Each one has a query, a priority (which rule wins) and a display order (where it shows; spec AC4.2: these two are separate). `Engine/Categories.lua` merges the built-ins with the user's diffs and user categories and compiles each query. A query that fails to compile disables only that category, with its error text (spec §7.10). The manual-list operation `AddToList` is used by drag-to-assign (Task 11). The report gains a `Categories:` line.

Priorities (higher wins; ties by id). Reagents 100 (only with "reagent bag separate", AC1.4), Keystone 95, Junk 90, Quest 85, Teleports & Tools 80, BoE gear 75, Gear 70, Consumables 65, Fish & Lures 60, Herbs 55, Ore 54, Leather & Cloth 53, Enchanting 52, Cooking 51, Trade Goods 50, Housing 45, Pets & Mounts & Toys 40, Other 0 (fallback, no rule). So gray gear is Junk, BoE gear beats Gear, herbs beat the generic Trade Goods, and a Fish Feast (a consumable) stays in Consumables.

**Files:**
- Create: `SwagBag/Engine/CategoryDefaults.lua`, `SwagBag/Engine/Categories.lua`, `spec/categories_spec.lua`
- Modify: `SwagBag/Locale/enUS.lua`, `SwagBag/Core/Report.lua`, `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/CategoryDefaults.lua`, `Engine/Categories.lua`)

**Interfaces:**
- Consumes: `SB.Config.db/Get/readOnly` (Task 2), `SB.Query.Compile/FormatError` (Task 1), `SB.L`, `SB.On("SB_LOGIN")`.
- Produces:
  - `SB.CategoryDefaults`: an array of `{ id, name, query, priority, displayOrder, itemList?, setting?, fallback? }`.
  - `SB.Categories`, with `NEW = "new"`, `FREE = "free"`, `OTHER = "c_other"`, `version` (number, bumped by every `Load`) and `loaded` (boolean).
  - `Load()` and `Ensure()`.
  - `Get(id) -> category|nil` and `ByPriority() -> array` (priority desc, ties id asc).
  - `SectionOrder() -> { "new", <enabled ids in display order>, "free" }` and `Name(sectionId) -> string`.
  - `AddToList(id, itemID) -> boolean` and `ResetBuiltin(id)`.
  - `MarkFailed(id, message) -> boolean` (true the first time only).
  - `Counts() -> total, edited, brokenNames`.
  - Runtime category fields: `id`, `name`, `query`, `priority`, `displayOrder`, `enabled`, `builtin`, `source`, `itemList = { include = {[itemID]=true}, exclude = {...} }`, `compiled`, `hasRule`, `fallback`, `setting`, `error`, `runtimeError`.
  - The report line `Categories: N (M edited)  Broken: names|none`, shown once categories are loaded.

- [ ] **Step 1: Write the failing test** (`spec/categories_spec.lua`)

<!-- sbw2:file T3 spec/categories_spec.lua -->
```lua
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Blocked.lua", "SwagBag/Core/Report.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
	"SwagBag/Engine/CategoryDefaults.lua", "SwagBag/Engine/Categories.lua",
}

describe("Categories", function()
	local SB, C
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		C = SB.Categories
		C.Load()
	end)

	local function ids(list)
		local out = {}
		for i, c in ipairs(list) do
			out[i] = c.id
		end
		return out
	end

	it("ships the spec 7.6 set in display order, with New first and Free last", function()
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
			"c_leathercloth", "c_enchanting", "c_cooking", "c_fish", "c_quest", "c_housing", "c_collect", "c_tools",
			"c_junk", "c_other", "free" }, C.SectionOrder())
		assert.equal("Keystone & Crests", C.Name("c_keystone"))
		assert.equal("New", C.Name("new"))
		assert.equal("Free", C.Name("free"))
	end)

	it("every built-in query compiles without errors or warnings", function()
		for _, c in ipairs(C.list) do
			assert.is_nil(c.error, c.id)
			assert.same({}, c.compiled.warnings, c.id)
		end
		assert.falsy(C.Get("c_other").hasRule, "Other has no rule; it is the fallback")
		assert.truthy(C.Get("c_gear").hasRule)
	end)

	it("orders rules by priority, ties by id, never by table order", function()
		local p = ids(C.ByPriority())
		assert.same({ "c_reagents", "c_keystone", "c_junk", "c_quest", "c_tools", "c_boe", "c_gear", "c_consumables" },
			{ unpack(p, 1, 8) })
		assert.equal("c_other", p[#p])
		SB.Config.db.userEdits.c_ore = { priority = 55 } -- same as Herbs
		C.Load()
		p = ids(C.ByPriority())
		local herbs, ore
		for i, id in ipairs(p) do
			if id == "c_herbs" then
				herbs = i
			elseif id == "c_ore" then
				ore = i
			end
		end
		assert.equal(herbs + 1, ore, "tie: c_herbs before c_ore")
	end)

	it("Reagents exists only while the reagent bag is shown separately (AC1.4)", function()
		assert.falsy(C.Get("c_reagents").enabled)
		SB.Config.Set("bags.reagentSeparate", true)
		C.Load()
		assert.truthy(C.Get("c_reagents").enabled)
		local order = C.SectionOrder()
		assert.equal("c_reagents", order[#order - 3])
	end)

	it("stores no built-in in SavedVariables until the user edits one (spec 8.5)", function()
		assert.same({}, SB.Config.db.userEdits)
		assert.same({}, SB.Config.db.categories)
	end)

	it("applies a stored diff over a built-in, and ResetBuiltin removes it", function()
		SB.Config.db.userEdits.c_gear = { name = "My Gear", priority = 99 }
		C.Load()
		assert.equal("My Gear", C.Get("c_gear").name)
		assert.equal(99, C.Get("c_gear").priority)
		assert.equal("gear", C.Get("c_gear").query, "fields not in the diff keep the default")
		C.ResetBuiltin("c_gear")
		assert.equal("Gear", C.Get("c_gear").name)
		assert.is_nil(SB.Config.db.userEdits.c_gear)
	end)

	it("AddToList stores a diff, moves the item off other lists, and bumps the version", function()
		local v = C.version
		assert.truthy(C.AddToList("c_consumables", 211880))
		assert.truthy(C.version > v)
		assert.truthy(C.Get("c_consumables").itemList.include[211880])
		assert.same({ itemList = { include = { [211880] = true } } }, SB.Config.db.userEdits.c_consumables)
		C.AddToList("c_fish", 211880)
		assert.falsy(C.Get("c_consumables").itemList.include[211880])
		assert.truthy(C.Get("c_fish").itemList.include[211880])
	end)

	it("moving a default-included item (Hearthstone) elsewhere excludes it from the built-in", function()
		assert.truthy(C.Get("c_tools").itemList.include[6948])
		C.AddToList("c_other", 6948)
		assert.truthy(C.Get("c_tools").itemList.exclude[6948])
		assert.truthy(C.Get("c_other").itemList.include[6948])
		C.AddToList("c_tools", 6948)
		assert.falsy(C.Get("c_tools").itemList.exclude[6948])
		assert.falsy(C.Get("c_other").itemList.include[6948])
	end)

	it("AddToList refuses unknown categories, New/Free and non-item values", function()
		assert.falsy(C.AddToList("nope", 1))
		assert.falsy(C.AddToList("new", 1))
		assert.falsy(C.AddToList("c_gear", "x"))
	end)

	it("a user category whose query does not compile is disabled with its error, others unaffected", function()
		SB.Config.db.categories.u_broken = { name = "Broken", query = "boe &", priority = 500, displayOrder = 5 }
		SB.Config.db.categories.u_ok = { name = "Mine", query = "potion", priority = 66, displayOrder = 25 }
		C.Load()
		local broken = C.Get("u_broken")
		assert.falsy(broken.enabled)
		assert.equal("Expected a value after \"&\" at character 6", broken.error)
		assert.truthy(C.Get("u_ok").enabled)
		local order = C.SectionOrder()
		for _, id in ipairs(order) do
			assert.truthy(id ~= "u_broken")
		end
		assert.equal("u_ok", order[4], "user category placed by its displayOrder (25: after Consumables)")
	end)

	it("a saved categoryOrder wins; unknown ids are skipped and the rest follow", function()
		SB.Config.db.categoryOrder = { "c_junk", "gone", "c_gear" }
		C.Load()
		assert.same({ "new", "c_junk", "c_gear", "c_keystone" }, { unpack(C.SectionOrder(), 1, 4) })
	end)

	it("damaged saved category data never breaks loading (Review Focus 4)", function()
		SB.Config.db.userEdits = { c_gear = "garbage", c_ore = { priority = "high", itemList = "x" }, nope = { name = "?" } }
		SB.Config.db.categories = { u_bad = "x", u_list = { name = "Only a list", itemList = { include = { [5] = true } } } }
		SB.Config.db.categoryOrder = { 42, "c_gear" }
		C.Load()
		assert.equal("Gear", C.Get("c_gear").name)
		assert.equal(0, C.Get("c_ore").priority)
		assert.same({}, C.Get("c_ore").itemList.include)
		assert.is_nil(C.Get("u_bad"))
		assert.falsy(C.Get("u_list").hasRule, "no query: only its manual list")
		assert.truthy(C.Get("u_list").enabled)
		assert.equal("c_gear", C.SectionOrder()[2])
	end)

	it("Counts reports totals, edited categories and broken ones", function()
		SB.Config.db.userEdits.c_gear = { name = "My Gear" }
		SB.Config.db.categories.u_broken = { name = "Broken", query = "(", priority = 1 }
		C.Load()
		assert.truthy(C.MarkFailed("c_fish", "boom"))
		assert.falsy(C.MarkFailed("c_fish", "boom again"), "only the first failure counts")
		local total, edited, broken = C.Counts()
		assert.equal(19, total)
		assert.equal(2, edited)
		assert.same({ "Fish & Lures", "Broken" }, broken)
	end)

	it("/swagbag report shows category counts and broken categories", function()
		SB.Checks.last = {}
		C.MarkFailed("c_fish", "boom")
		local text = SB.Report.Build()
		assert.truthy(text:find("\nCategories: 18 (0 edited)  Broken: Fish & Lures", 1, true))
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/categories_spec.lua`
Expected: `0 passed, 14 failed` (`cannot open SwagBag/Engine/CategoryDefaults.lua`)

- [ ] **Step 3: Add the category names and the report line text to `SwagBag/Locale/enUS.lua`**

<!-- sbw2:edit T3 01-locale SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
-- Bags window
L.BAGS_TITLE = "SwagBag"
L.BAGS_SCALE = "SwagBag %d%%"
```

and replace it with:

```lua
-- Bags window
L.BAGS_TITLE = "SwagBag"
L.BAGS_SCALE = "SwagBag %d%%"

-- Categories (spec 7.6) and New / Free sections
L.CAT_NEW = "New"
L.CAT_KEYSTONE = "Keystone & Crests"
L.CAT_CONSUMABLES = "Consumables"
L.CAT_GEAR = "Gear"
L.CAT_BOE = "BoE gear"
L.CAT_TRADEGOODS = "Trade Goods"
L.CAT_HERBS = "Herbs"
L.CAT_ORE = "Ore"
L.CAT_LEATHERCLOTH = "Leather & Cloth"
L.CAT_ENCHANTING = "Enchanting"
L.CAT_COOKING = "Cooking"
L.CAT_FISH = "Fish & Lures"
L.CAT_QUEST = "Quest"
L.CAT_HOUSING = "Housing"
L.CAT_COLLECT = "Pets & Mounts & Toys"
L.CAT_TOOLS = "Teleports & Tools"
L.CAT_REAGENTS = "Reagents"
L.CAT_JUNK = "Junk"
L.CAT_OTHER = "Other"
L.CAT_FREE = "Free"
```

<!-- sbw2:edit T3 02-locale-report SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_SETTINGS = "Settings hash: %s  Schema: %d  Buttons: %d (%d ms)"
```

and replace it with:

```lua
L.REPORT_SETTINGS = "Settings hash: %s  Schema: %d  Buttons: %d (%d ms)"
L.REPORT_CATEGORIES = "Categories: %d (%d edited)  Broken: %s"
```

- [ ] **Step 4: Create `SwagBag/Engine/CategoryDefaults.lua`**

<!-- sbw2:file T3 SwagBag/Engine/CategoryDefaults.lua -->
```lua
-- SwagBag default categories (spec 7.6, first-run set). Pure data.
-- Built-ins are NEVER written to SavedVariables: a user's change to one is stored as a
-- diff in SwagBagDB.userEdits[id] (spec 8.5), so a new default set in an update applies
-- cleanly and "reset to default" just removes the diff.
--   priority      higher wins when several rules match (ties: lower id first)
--   displayOrder  section order on screen (separate from priority, spec AC4.2)
--   itemList      manual lists, keyed by itemID: include wins over every rule
--   setting       the category only exists while that Config setting is true
--   fallback      the category for items no rule claims ("Other")
-- New and Free are not categories: the layout adds them (spec 7.6, 4.3).
-- Queries use only registered keywords except Fish & Lures, which matches item names
-- ("fish", "lure", "bait"); users file other fish by dragging one onto the header.
local _, SB = ...

local L = SB.L

SB.CategoryDefaults = {
	{ id = "c_keystone", name = L.CAT_KEYSTONE, query = "keystone", priority = 95, displayOrder = 10 },
	{ id = "c_consumables", name = L.CAT_CONSUMABLES, query = "consumable", priority = 65, displayOrder = 20 },
	{ id = "c_gear", name = L.CAT_GEAR, query = "gear", priority = 70, displayOrder = 30 },
	{ id = "c_boe", name = L.CAT_BOE, query = "gear & boe", priority = 75, displayOrder = 40 },
	{ id = "c_tradegoods", name = L.CAT_TRADEGOODS, query = "tradegoods | reagent", priority = 50, displayOrder = 50 },
	{ id = "c_herbs", name = L.CAT_HERBS, query = "herb", priority = 55, displayOrder = 60 },
	{ id = "c_ore", name = L.CAT_ORE, query = "ore", priority = 54, displayOrder = 70 },
	{ id = "c_leathercloth", name = L.CAT_LEATHERCLOTH, query = "leather | cloth", priority = 53, displayOrder = 80 },
	{ id = "c_enchanting", name = L.CAT_ENCHANTING, query = "enchanting", priority = 52, displayOrder = 90 },
	{ id = "c_cooking", name = L.CAT_COOKING, query = "cooking", priority = 51, displayOrder = 100 },
	{ id = "c_fish", name = L.CAT_FISH, query = "fish | lure | bait", priority = 60, displayOrder = 110 },
	{ id = "c_quest", name = L.CAT_QUEST, query = "questitem", priority = 85, displayOrder = 120 },
	{ id = "c_housing", name = L.CAT_HOUSING, query = "housing", priority = 45, displayOrder = 130 },
	{ id = "c_collect", name = L.CAT_COLLECT, query = "pet | mount | toy", priority = 40, displayOrder = 140 },
	{ id = "c_tools", name = L.CAT_TOOLS, query = "profession tool | profession gear", priority = 80, displayOrder = 150,
		-- Hearthstone, Dalaran Hearthstone, Garrison Hearthstone (not toys, no keyword)
		itemList = { include = { [6948] = true, [140192] = true, [110560] = true } } },
	{ id = "c_reagents", name = L.CAT_REAGENTS, query = "reagentbag", priority = 100, displayOrder = 160,
		setting = "bags.reagentSeparate" },
	{ id = "c_junk", name = L.CAT_JUNK, query = "junk", priority = 90, displayOrder = 170 },
	{ id = "c_other", name = L.CAT_OTHER, query = "", priority = 0, displayOrder = 180, fallback = true },
}
```

- [ ] **Step 5: Create `SwagBag/Engine/Categories.lua`**

<!-- sbw2:file T3 SwagBag/Engine/Categories.lua -->
```lua
-- SwagBag categories (spec 7.7, 8.5): built-ins + the user's diffs + user categories,
-- merged into runtime records. Pure (reads SB.Config.db, SB.CategoryDefaults, SB.Query).
--   Categories.Load()                  rebuild everything; bumps Categories.version
--   Categories.Get(id) -> category | nil
--   Categories.ByPriority()            enabled-or-not, priority desc, ties id asc (no pairs())
--   Categories.SectionOrder()          { "new", <enabled categories in display order>, "free" }
--   Categories.Name(sectionId)         display name, including "new" and "free"
--   Categories.AddToList(id, itemID)   manual include (drag onto a header, AC4.3)
--   Categories.ResetBuiltin(id)        remove the user's diff of a built-in
--   Categories.MarkFailed(id, message) a rule threw while evaluating (Categorizer)
--   Categories.Counts() -> total, edited, broken names (list)
-- Runtime category: { id, name, query, priority, displayOrder, enabled, builtin, source,
--   itemList = { include = {[itemID]=true}, exclude = {...} }, compiled, hasRule,
--   fallback, setting, error (compile error text), runtimeError (evaluation error text) }
-- A category whose query does not compile is disabled with `error` set and never
-- affects other categories (spec 7.10).
local _, SB = ...

local C = { version = 0, loaded = false, list = {}, byId = {}, byPriority = {}, display = {},
	NEW = "new", FREE = "free", OTHER = "c_other" }
SB.Categories = C

local FIELDS = { "name", "query", "priority", "displayOrder", "enabled" }

local function copySet(...)
	local out = {}
	for i = 1, select("#", ...) do
		local t = select(i, ...)
		if type(t) == "table" then
			for k, v in pairs(t) do
				if v then
					out[k] = true
				end
			end
		end
	end
	return out
end

local function list(t, which)
	return type(t) == "table" and type(t.itemList) == "table" and t.itemList[which] or nil
end

local function build(def, edit, builtin)
	local c = { id = def.id, builtin = builtin, source = builtin and "builtin" or (def.source or "user"),
		fallback = def.fallback, setting = def.setting }
	for _, f in ipairs(FIELDS) do
		c[f] = def[f]
	end
	if type(edit) == "table" then
		for _, f in ipairs(FIELDS) do
			if edit[f] ~= nil then
				c[f] = edit[f]
			end
		end
	end
	c.name = c.name or c.id
	c.priority = tonumber(c.priority) or 0
	c.displayOrder = tonumber(c.displayOrder) or 1000
	c.enabled = c.enabled ~= false
	c.itemList = {
		include = copySet(list(def, "include"), list(edit, "include")),
		exclude = copySet(list(def, "exclude"), list(edit, "exclude")),
	}
	if c.setting and not SB.Config.Get(c.setting) then
		c.enabled = false
	end
	local compiled = SB.Query.Compile(type(c.query) == "string" and c.query or "")
	if compiled.fn then
		c.compiled = compiled
		c.hasRule = not compiled.empty
	else
		c.error = SB.Query.FormatError(compiled.errors[1])
		c.enabled = false
	end
	return c
end

local function byPriority(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end
	return a.id < b.id
end

local function byDisplay(a, b)
	if a.displayOrder ~= b.displayOrder then
		return a.displayOrder < b.displayOrder
	end
	return a.id < b.id
end

function C.Load()
	local db = SB.Config.db or {}
	local edits = type(db.userEdits) == "table" and db.userEdits or {}
	local users = type(db.categories) == "table" and db.categories or {}
	C.list, C.byId = {}, {}
	for _, def in ipairs(SB.CategoryDefaults) do
		local c = build(def, edits[def.id], true)
		C.list[#C.list + 1] = c
		C.byId[c.id] = c
	end
	local userIds = {}
	for id, def in pairs(users) do
		if type(def) == "table" and not C.byId[id] then
			userIds[#userIds + 1] = id
		end
	end
	table.sort(userIds)
	for _, id in ipairs(userIds) do
		local def = users[id]
		def.id = id
		local c = build(def, nil, false)
		C.list[#C.list + 1] = c
		C.byId[id] = c
	end
	C.byPriority = {}
	for i, c in ipairs(C.list) do
		C.byPriority[i] = c
	end
	table.sort(C.byPriority, byPriority)
	-- Display order: the saved order first (unknown ids skipped), then the rest by displayOrder.
	local rest, placed = {}, {}
	C.display = {}
	if type(db.categoryOrder) == "table" then
		for _, id in ipairs(db.categoryOrder) do
			local c = C.byId[id]
			if c and not placed[id] then
				placed[id] = true
				C.display[#C.display + 1] = c
			end
		end
	end
	for _, c in ipairs(C.list) do
		if not placed[c.id] then
			rest[#rest + 1] = c
		end
	end
	table.sort(rest, byDisplay)
	for _, c in ipairs(rest) do
		C.display[#C.display + 1] = c
	end
	C.version = C.version + 1
	C.loaded = true
end

function C.Ensure()
	if not C.loaded then
		C.Load()
	end
end

function C.Get(id)
	C.Ensure()
	return C.byId[id]
end

function C.ByPriority()
	C.Ensure()
	return C.byPriority
end

function C.SectionOrder()
	C.Ensure()
	local order = { C.NEW }
	for _, c in ipairs(C.display) do
		if c.enabled then
			order[#order + 1] = c.id
		end
	end
	order[#order + 1] = C.FREE
	return order
end

function C.Name(sectionId)
	if sectionId == C.NEW then
		return SB.L.CAT_NEW
	elseif sectionId == C.FREE then
		return SB.L.CAT_FREE
	end
	local c = C.Get(sectionId)
	return c and c.name or tostring(sectionId)
end

-- The table that stores the user's version of a category's fields and lists:
-- the diff for a built-in, the category itself for a user category.
local function editFor(c)
	local db = SB.Config.db
	if c.builtin then
		db.userEdits = type(db.userEdits) == "table" and db.userEdits or {}
		db.userEdits[c.id] = db.userEdits[c.id] or {}
		return db.userEdits[c.id]
	end
	return db.categories[c.id]
end

local function ensureList(e, which)
	e.itemList = type(e.itemList) == "table" and e.itemList or {}
	e.itemList[which] = type(e.itemList[which]) == "table" and e.itemList[which] or {}
	return e.itemList[which]
end

local function defaultIncludes(id)
	for _, def in ipairs(SB.CategoryDefaults) do
		if def.id == id then
			return list(def, "include") or {}
		end
	end
	return {}
end

-- Put itemID on targetId's manual include list and take it off every other list, so the
-- latest drag wins. A built-in's default include is overridden by a diff exclude.
-- Returns true, or false for an unknown category / item.
function C.AddToList(targetId, itemID)
	C.Ensure()
	local target = C.byId[targetId]
	if not target or type(itemID) ~= "number" or SB.Config.readOnly then
		return false
	end
	for _, c in ipairs(C.list) do
		if c.id ~= targetId and c.itemList.include[itemID] then
			local e = editFor(c)
			local inc = list(e, "include")
			if inc then
				inc[itemID] = nil
			end
			if c.builtin and defaultIncludes(c.id)[itemID] then
				ensureList(e, "exclude")[itemID] = true
			end
		end
	end
	local e = editFor(target)
	ensureList(e, "include")[itemID] = true
	local exc = list(e, "exclude")
	if exc then
		exc[itemID] = nil
	end
	C.Load()
	return true
end

function C.ResetBuiltin(id)
	local db = SB.Config.db
	if type(db.userEdits) == "table" then
		db.userEdits[id] = nil
	end
	C.Load()
end

-- Called by the Categorizer when a category's rule throws. Returns true the first time
-- (so the caller records the error once per category), false afterwards.
function C.MarkFailed(id, message)
	local c = C.byId[id]
	if not c or c.runtimeError then
		return false
	end
	c.runtimeError = tostring(message)
	return true
end

function C.Counts()
	C.Ensure()
	local db = SB.Config.db or {}
	local edited = 0
	for _, c in ipairs(C.list) do
		if not c.builtin or (type(db.userEdits) == "table" and db.userEdits[c.id] ~= nil) then
			edited = edited + 1
		end
	end
	local broken = {}
	for _, c in ipairs(C.display) do
		if c.error or c.runtimeError then
			broken[#broken + 1] = c.name
		end
	end
	return #C.list, edited, broken
end

SB.On("SB_LOGIN", function()
	C.Load()
end, "bags")
```

- [ ] **Step 6: Add the report line and the TOC entries**

<!-- sbw2:edit T3 03-report SwagBag/Core/Report.lua -->
In `SwagBag/Core/Report.lua`, find:

```lua
	lines[#lines + 1] = L.REPORT_SETTINGS:format(Report.Hash(db.settings or {}), db.schemaVersion or 0, stats.count or 0,
		math.floor(stats.createMs or 0))
	return table.concat(lines, "\n")
```

and replace it with:

```lua
	lines[#lines + 1] = L.REPORT_SETTINGS:format(Report.Hash(db.settings or {}), db.schemaVersion or 0, stats.count or 0,
		math.floor(stats.createMs or 0))
	if SB.Categories and SB.Categories.loaded then
		local total, edited, broken = SB.Categories.Counts()
		lines[#lines + 1] = L.REPORT_CATEGORIES:format(total, edited, #broken > 0 and table.concat(broken, ", ") or L.REPORT_NONE)
	end
	return table.concat(lines, "\n")
```

<!-- sbw2:edit T3 04-toc SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
Engine/Search.lua
```

and replace it with:

```text
Engine/Search.lua
Engine/CategoryDefaults.lua
Engine/Categories.lua
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/categories_spec.lua`
Expected: `14 passed, 0 failed`

- [ ] **Step 8: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (29 files)`, `289 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 9: Commit**

```bash
git add SwagBag/Engine/CategoryDefaults.lua SwagBag/Engine/Categories.lua SwagBag/Locale/enUS.lua SwagBag/Core/Report.lua \
  SwagBag/SwagBag.toc spec/categories_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 3: default categories (spec 7.6) stored as diffs, Categories model, report line" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 4: The Categorizer (priority, item lists, tri-state blocking, error isolation, memo)

Spec §7.7 order, applied to one item record:

1. **Exclude** lists first. An excluded item never lands in that category.
2. **Include** lists, highest priority first.
3. Rules by priority, ties by id. The first `true` wins. A `nil` (data not loaded) **stops** the search, and the item is pending. The layout puts it in New, or it stays put while the window is open.
4. No rule matched: Other.

**Per-category error isolation** is the binding hand-off from week 1 (ledger line 72): `Query.Eval` propagates keyword errors. The Categorizer runs each rule in `pcall`. A rule that throws is marked failed through `Categories.MarkFailed`, recorded **once** in the error ring with window `"none"` (no Safe Mode, no chat line), and skipped from then on.

Memo (spec §7.8), per category, by the rule's cache class:

- `static` → itemID
- `instance` → `Items.Key` (link + `#b`/`#uw`/`#u`)
- `volatile` → never memoized

Only definite results of loaded records are kept. There are at most 4,000 entries, and the oldest is dropped first. Everything is dropped when any category changes (`Categories.version`).

**Files:**
- Create: `SwagBag/Engine/Categorizer.lua`, `spec/categorizer_spec.lua`, `spec/fixtures/big.lua` (the spec §3.4 1,290-slot fixture, reused by Task 6)
- Modify: `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/Categorizer.lua`)

**Interfaces:**
- Consumes: `SB.Categories.Ensure/version/byPriority/OTHER/MarkFailed` (Task 3), `SB.Query.Eval` and `compiled.cacheClass`, `SB.Items.Key(record, class)` and `record.pending` (on `main`), `SB.ErrorTrap.OnError(label, window, message, stack)`.
- Produces: `SB.Categorizer.Assign(record) -> id, how`, where `how` is `"manual"`, `"rule"` or `"fallback"`. It returns `nil, "pending"` when a rule could not decide. `SB.Categorizer.AssignAll(records) -> groups, pending`: `groups` is `{ [id] = { records in bag/slot order } }`. `SB.Categorizer.Invalidate()`. Fields `MAX_MEMO` (4000), `memoCount` and `stats = { hits, misses, evictions }`. `spec/fixtures/big.lua` exports `Big.SLOTS` (1290), `Big.BAGS` (`{ {bag, size} }`) and `Big.Install(mockAdapter) -> slotCount`.

- [ ] **Step 1: Write the 1,290-slot fixture** (`spec/fixtures/big.lua`)

<!-- sbw2:file T4 spec/fixtures/big.lua -->
```lua
-- 1,290-slot fixture (spec 3.4, 11.1): bags 0-4 x36 + reagent bag x32 (212 slots), six
-- character bank tabs and five warband tabs x98 (1,078 slots). Every fifth slot is empty;
-- the rest cycle through the shared item fixtures with 7 link variants per item.
local Fixtures = dofile("spec/fixtures/items.lua")

local Big = { SLOTS = 1290 }

Big.BAGS = { { 0, 36 }, { 1, 36 }, { 2, 36 }, { 3, 36 }, { 4, 36 }, { 5, 32 } }
for bag = 6, 16 do
	Big.BAGS[#Big.BAGS + 1] = { bag, 98 }
end

local CYCLE = {
	Fixtures.HEALING_POTION, Fixtures.FLASK, Fixtures.HERB, Fixtures.ORE, Fixtures.BOE_RING, Fixtures.SOULBOUND_HELM,
	Fixtures.JUNK, Fixtures.PET_CAGE, Fixtures.TOY, Fixtures.QUEST, Fixtures.BAG, Fixtures.UNLOADED,
}

-- Fill a mock Adapter. Returns the number of slots.
function Big.Install(m)
	Fixtures.Install(m)
	m.bagIDs = { bags = { 0, 1, 2, 3, 4, 5 }, bank = { 6, 7, 8, 9, 10, 11 }, warband = { 12, 13, 14, 15, 16 } }
	local n = 0
	for _, b in ipairs(Big.BAGS) do
		m.SetBagSize(b[1], b[2])
		for slot = 1, b[2] do
			n = n + 1
			if n % 5 ~= 0 then
				local id = CYCLE[n % #CYCLE + 1]
				m.Put(b[1], slot, id, 1, { link = "item:" .. id .. "::" .. (n % 7) })
			end
		end
	end
	return n
end

return Big
```

- [ ] **Step 2: Write the failing test** (`spec/categorizer_spec.lua`)

<!-- sbw2:file T4 spec/categorizer_spec.lua -->
```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Big = dofile("spec/fixtures/big.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
	"SwagBag/Engine/CategoryDefaults.lua", "SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua",
}

describe("Categorizer", function()
	local SB, A, Z, C
	before_each(function()
		SB = Loader.New(FILES)
		A, Z, C = SB.Adapter, SB.Categorizer, SB.Categories
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		C.Load()
	end)

	local function at(slot, bag)
		return (Z.Assign(SB.Items.Describe(bag or 0, slot)))
	end

	-- A user category with a counting keyword; returns the counter table.
	local function counting(name, class, priority, result)
		local counter = { n = 0 }
		SB.Query.RegisterKeyword({ name = name, class = class, eval = function()
			counter.n = counter.n + 1
			return result
		end })
		SB.Config.db.categories["u_" .. name] = { name = name, query = name, priority = priority }
		C.Load()
		return counter
	end

	it("files the fixture bag into the default sections, keystones and caged pets by link", function()
		A.Put(0, 7, Fixtures.HERB, 40)
		A.Put(0, 8, Fixtures.ORE, 10)
		A.Put(0, 9, Fixtures.PET_CAGE, 1, { link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r" })
		A.Put(0, 10, Fixtures.TOY, 1)
		A.Put(0, 11, Fixtures.QUEST, 1, { quest = true })
		A.Put(0, 12, Fixtures.BAG, 1)
		A.Put(0, 13, Fixtures.BOE_RING, 1, { isWUE = true })
		local expected = { "c_consumables", "c_consumables", "c_boe", "c_gear", "c_keystone", "c_junk", "c_herbs", "c_ore",
			"c_collect", "c_collect", "c_quest", "c_other", "c_gear" }
		for slot, id in ipairs(expected) do
			assert.equal(id, at(slot), "slot " .. slot)
		end
	end)

	it("a manual include beats every rule; an exclude keeps an item out of a category", function()
		C.AddToList("c_junk", Fixtures.HEALING_POTION)
		assert.equal("c_junk", at(1))
		assert.same({ "c_junk", "manual" }, { Z.Assign(SB.Items.Describe(0, 1)) })
		SB.Config.db.userEdits.c_consumables = { itemList = { exclude = { [Fixtures.FLASK] = true } } }
		C.Load()
		assert.equal("c_other", at(2), "excluded from Consumables, no other rule claims it")
	end)

	it("a rule that cannot decide (nil) stops the search: the item is pending, not mis-filed", function()
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		assert.same({ nil, "pending" }, { Z.Assign(SB.Items.Describe(0, 7)) })
		A.items[Fixtures.UNLOADED] = { name = "Robe", classID = A.ITEM_CLASS.Armor, subclassID = 0, quality = 3,
			equipLoc = "INVTYPE_CHEST", ilvl = 280, maxStack = 1, bind = "equip" }
		assert.equal("c_boe", at(7), "once loaded it is filed normally")
	end)

	it("a loading item that instant facts already decide is filed directly (tri-state, spec 7.7)", function()
		A.AddItem(300001, { classID = A.ITEM_CLASS.Consumable, subclassID = A.CONSUMABLE_SUB.Potion, quality = 1,
			pending = true })
		A.Put(0, 7, 300001, 1)
		local r = SB.Items.Describe(0, 7)
		assert.truthy(r.pending)
		assert.equal("c_consumables", (Z.Assign(r)))
	end)

	it("a rule that throws is isolated: recorded once, disabled, and every other category still works", function()
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("kaboom") end })
		SB.Config.db.categories.u_boom = { name = "Boom", query = "boom", priority = 200 }
		C.Load()
		for _ = 1, 3 do
			assert.equal("c_consumables", at(1))
			assert.equal("c_junk", at(6))
		end
		local recent = SB.ErrorTrap.Recent()
		assert.equal(1, #recent)
		assert.equal("category:u_boom", recent[1].label)
		assert.equal("none", recent[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.truthy(C.Get("u_boom").runtimeError:find("kaboom", 1, true))
	end)

	it("memoizes static rules per itemID and instance rules per link + bind; never volatile ones", function()
		local s = counting("cstatic", "static", 300, false)
		local i = counting("cinst", "instance", 299, false)
		local v = counting("cvol", "volatile", 298, false)
		at(1)
		at(1)
		assert.same({ 1, 1, 2 }, { s.n, i.n, v.n })
		A.Put(0, 7, Fixtures.HEALING_POTION, 1, { isBound = true }) -- same item and link, now bound
		at(7)
		assert.same({ 1, 2, 3 }, { s.n, i.n, v.n })
		assert.truthy(Z.stats.hits >= 3)
	end)

	it("never memoizes a loading record", function()
		local s = counting("cstatic", "static", 300, false)
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		at(7)
		at(7)
		assert.equal(2, s.n)
	end)

	it("drops every memo when any category changes", function()
		local s = counting("cstatic", "static", 300, false)
		at(1)
		C.AddToList("c_junk", Fixtures.JUNK)
		at(1)
		assert.equal(2, s.n)
	end)

	it("keeps at most MAX_MEMO entries, dropping the oldest first", function()
		local s = counting("cstatic", "static", 300, false)
		Z.MAX_MEMO = 3
		for slot = 1, 6 do -- six different itemIDs
			at(slot)
		end
		assert.equal(3, Z.memoCount)
		assert.equal(6, s.n)
		at(6)
		assert.equal(6, s.n, "newest is still cached")
		at(1)
		assert.equal(7, s.n, "oldest was dropped")
	end)

	it("is deterministic: shuffled input gives the same groups", function()
		local records = {}
		for slot = 1, 6 do
			records[slot] = SB.Items.Describe(0, slot)
		end
		local function shape(groups)
			local out = {}
			for id, list in pairs(groups) do
				out[id] = {}
				for i, r in ipairs(list) do
					out[id][i] = r.slot
				end
			end
			return out
		end
		local a = shape((Z.AssignAll(records)))
		local shuffled = { records[4], records[1], records[6], records[2], records[5], records[3] }
		Z.Invalidate()
		assert.same(a, shape((Z.AssignAll(shuffled))))
		assert.same({ 1, 2 }, a.c_consumables)
	end)

	it("puts reagent-bag items in Reagents only while it is shown separately (AC1.4)", function()
		A.SetBagSize(5, 36)
		A.Put(5, 1, Fixtures.HERB, 12)
		assert.equal("c_herbs", at(1, 5))
		SB.Config.Set("bags.reagentSeparate", true)
		C.Load()
		assert.equal("c_reagents", at(1, 5))
	end)

	it("categorizes the 1,290-slot fixture well inside the first-open budget", function()
		local m = SB.Adapter
		m.slots, m.sizes = {}, {}
		Big.Install(m)
		local records = {}
		for _, b in ipairs(Big.BAGS) do
			for slot = 1, b[2] do
				local r = SB.Items.Describe(b[1], slot)
				if r then
					records[#records + 1] = r
				end
			end
		end
		assert.equal(1032, #records)
		local t0 = os.clock()
		Z.AssignAll(records)
		local cold = (os.clock() - t0) * 1000
		t0 = os.clock()
		Z.AssignAll(records)
		local warm = (os.clock() - t0) * 1000
		assert.truthy(cold < 20, ("cold %.2f ms"):format(cold))
		assert.truthy(warm < 10, ("warm %.2f ms"):format(warm))
	end)
end)
```

- [ ] **Step 3: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/categorizer_spec.lua`
Expected: `0 passed, 12 failed` (`cannot open SwagBag/Engine/Categorizer.lua`)

- [ ] **Step 4: Create `SwagBag/Engine/Categorizer.lua`**

<!-- sbw2:file T4 SwagBag/Engine/Categorizer.lua -->
```lua
-- SwagBag categorizer (spec 7.7, 7.8). Pure: item record -> category id.
--   Categorizer.Assign(record) -> id, how     how = "manual" | "rule" | "fallback"
--                              -> nil, "pending"   a rule could not decide yet (goes to New)
--   Categorizer.AssignAll(records) -> groups { [id] = { records in bag/slot order } }, pending list
--   Categorizer.Invalidate()   drop every memo (automatic whenever any category changes)
--   Categorizer.stats          { hits, misses, evictions } for /swagbag perf (later week)
-- Order (spec 7.7): exclude lists first (an excluded item never lands in that category),
-- then include lists by priority, then rules by priority (ties by id). The first rule
-- that says true wins. A rule that says nil (item data not loaded) STOPS the search: the
-- item waits in New instead of being mis-filed by a lower rule. No rule: Other.
-- Error isolation (spec 7.10): each rule runs inside pcall. A rule that throws is marked
-- failed (Categories.MarkFailed), recorded ONCE in the error ring with window "none"
-- (no Safe Mode, no chat line), and skipped from then on. Other categories carry on.
-- Memo (spec 7.8), per category, by the rule's cache class: static -> itemID, instance ->
-- Items.Key (link + bind suffix), volatile -> never. Only definite (true/false) results
-- of loaded records are kept. At most MAX_MEMO entries in all; the oldest go first.
local _, SB = ...

local Z = { MAX_MEMO = 4000, memo = {}, memoCount = 0, version = -1, stats = { hits = 0, misses = 0, evictions = 0 } }
SB.Categorizer = Z

local TRUE, FALSE = 1, 0
local queueId, queueKey, head, tail = {}, {}, 1, 0

function Z.Invalidate()
	Z.memo, Z.memoCount = {}, 0
	queueId, queueKey, head, tail = {}, {}, 1, 0
end

local function sync()
	local C = SB.Categories
	C.Ensure()
	if C.version ~= Z.version then
		Z.Invalidate()
		Z.version = C.version
	end
end

local function remember(id, key, value)
	while Z.memoCount >= Z.MAX_MEMO and head <= tail do
		local oldId, oldKey = queueId[head], queueKey[head]
		queueId[head], queueKey[head] = nil, nil
		head = head + 1
		local m = Z.memo[oldId]
		if m and m[oldKey] ~= nil then
			m[oldKey] = nil
			Z.memoCount = Z.memoCount - 1
			Z.stats.evictions = Z.stats.evictions + 1
		end
	end
	local m = Z.memo[id]
	if not m then
		m = {}
		Z.memo[id] = m
	end
	m[key] = value
	Z.memoCount = Z.memoCount + 1
	tail = tail + 1
	queueId[tail], queueKey[tail] = id, key
end

local function fail(c, err)
	local message = tostring(err)
	if SB.Categories.MarkFailed(c.id, message) then
		pcall(SB.ErrorTrap.OnError, "category:" .. c.id, "none", message, "")
	end
end

-- One category's rule for one record: true | false | nil. Never throws.
local function rule(c, record)
	local class = c.compiled.cacheClass
	local key
	if class ~= "volatile" and not record.pending then
		key = SB.Items.Key(record, class)
	end
	if key ~= nil then
		local m = Z.memo[c.id]
		local v = m and m[key]
		if v ~= nil then
			Z.stats.hits = Z.stats.hits + 1
			return v == TRUE
		end
	end
	Z.stats.misses = Z.stats.misses + 1
	local ok, v = pcall(SB.Query.Eval, c.compiled, record)
	if not ok then
		fail(c, v)
		return false
	end
	if key ~= nil and v ~= nil then
		remember(c.id, key, v and TRUE or FALSE)
	end
	return v
end

local function usable(c)
	return c.enabled and not c.runtimeError
end

function Z.Assign(record)
	sync()
	local C = SB.Categories
	local list = C.byPriority
	local itemID = record.itemID
	for i = 1, #list do
		local c = list[i]
		if usable(c) and c.itemList.include[itemID] and not c.itemList.exclude[itemID] then
			return c.id, "manual"
		end
	end
	for i = 1, #list do
		local c = list[i]
		if usable(c) and c.hasRule and not c.itemList.exclude[itemID] then
			local v = rule(c, record)
			if v == true then
				return c.id, "rule"
			elseif v == nil then
				return nil, "pending"
			end
		end
	end
	return C.OTHER, "fallback"
end

local function bySlot(a, b)
	if a.bag ~= b.bag then
		return a.bag < b.bag
	end
	return a.slot < b.slot
end

function Z.AssignAll(records)
	local groups, pending = {}, {}
	for _, r in ipairs(records) do
		local id = Z.Assign(r)
		if id == nil then
			pending[#pending + 1] = r
		else
			groups[id] = groups[id] or {}
			table.insert(groups[id], r)
		end
	end
	for _, g in pairs(groups) do
		table.sort(g, bySlot)
	end
	table.sort(pending, bySlot)
	return groups, pending
end
```

- [ ] **Step 5: Add it to the TOC**

<!-- sbw2:edit T4 01-toc SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
Engine/Categories.lua
```

and replace it with:

```text
Engine/Categories.lua
Engine/Categorizer.lua
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/categorizer_spec.lua`
Expected: `12 passed, 0 failed`. Measured during planning: 1,032 records take about 1.1 ms cold and 0.4 ms warm. The test asserts < 20 ms and < 10 ms.

- [ ] **Step 7: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (30 files)`, `301 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 8: Commit**

```bash
git add SwagBag/Engine/Categorizer.lua SwagBag/SwagBag.toc spec/categorizer_spec.lua spec/fixtures/big.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 4: categorizer with item lists, tri-state blocking, per-category error isolation, bounded memo" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 5: Search fixes: one ring entry per failing query; cooldown/usable refresh without rescans

Two deferred week-1 minors that week-2 code touches (ledger line 85):

- **Error flooding.** `Search.Apply` records an error-ring entry on **every** pass of a failing query, so one broken keyword can push all 10 real errors out of the ring. Now each failing query (`compiled.id`) is recorded once.
- **Stale searches.** `cooldown` and `usable` searches go stale, because `BAG_UPDATE_COOLDOWN` only repaints and does not update records. The design keeps spec §9 ("`BAG_UPDATE_COOLDOWN` → cooldown repaint of visible buttons only; never a rescan"). `Items.RefreshVolatile(record)` re-reads just three cheap facts (cooldown, usable, new). The bags window (Task 10) calls it on `BAG_UPDATE_COOLDOWN` **only while** `Search.NeedsVolatileRefresh()` says the active search uses `cooldown` or `usable`. With any other search, the cost stays zero.
- **`new`.** The `new` keyword is not stale: changed slots are re-described on every flush, and Task 10 pins that with a test.

**Files:**
- Modify: `SwagBag/Engine/Search.lua`, `SwagBag/Engine/Items.lua`
- Test: `spec/search_spec.lua`, `spec/items_spec.lua`

**Interfaces:**
- Consumes: `SB.ErrorTrap.Run`, `compiled.id`/`compiled.keywords` (on `main`), `SB.Adapter.IsOnCooldown/IsUsable`, `SB.Inventory.IsNew`.
- Produces: `SB.Search.failedId` (the id of the last query that failed and was recorded), `SB.Search.VOLATILE_REFRESH = { cooldown = true, usable = true }`, `SB.Search.NeedsVolatileRefresh() -> boolean`, `SB.Items.RefreshVolatile(record) -> record` (updates `onCooldown`, `isUsable`, `isNew` in place).

- [ ] **Step 1: Write the failing tests**

<!-- sbw2:edit T5 10-search-spec spec/search_spec.lua -->
In `spec/search_spec.lua`, find:

```lua
	describe("ErrorSpan (byte offsets, never past the end)", function()
```

and replace it with:

```lua
	it("a failing query is recorded once, not on every pass", function()
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("keyword exploded") end })
		S.SetText("boom")
		for _ = 1, 3 do
			S.Apply(forEach, setDimmed)
		end
		assert.equal(1, #SB.ErrorTrap.Recent())
		S.SetText("boom & potion") -- a different query that fails too: one more entry
		S.Apply(forEach, setDimmed)
		S.Apply(forEach, setDimmed)
		assert.equal(2, #SB.ErrorTrap.Recent())
	end)

	it("asks for a cooldown/usable refresh only while the search uses those keywords", function()
		S.SetText("")
		assert.falsy(S.NeedsVolatileRefresh())
		S.SetText("potion")
		assert.falsy(S.NeedsVolatileRefresh())
		S.SetText("cooldown")
		assert.truthy(S.NeedsVolatileRefresh())
		S.SetText("potion & !usable")
		assert.truthy(S.NeedsVolatileRefresh())
	end)

	describe("ErrorSpan (byte offsets, never past the end)", function()
```

<!-- sbw2:edit T5 11-items-spec spec/items_spec.lua -->
In `spec/items_spec.lua`, find:

```lua
	it("Key gives itemID for static, link+bound for instance, nil for volatile", function()
```

and replace it with:

```lua
	it("RefreshVolatile re-reads cooldown, usability and new without a full describe", function()
		local r = Items.Describe(0, 2)
		assert.equal(true, r.onCooldown)
		assert.equal(true, r.isUsable)
		A.slots[0][2].onCooldown = false
		A.items[Fixtures.FLASK].usable = false
		SB.Inventory = { IsNew = function() return true end }
		assert.equal(r, Items.RefreshVolatile(r))
		assert.equal(false, r.onCooldown)
		assert.equal(false, r.isUsable)
		assert.equal(true, r.isNew)
	end)

	it("Key gives itemID for static, link+bound for instance, nil for volatile", function()
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/search_spec.lua; luajit spec/runner.lua spec/items_spec.lua`
Expected: `12 passed, 2 failed` (3 ring entries instead of 1; `NeedsVolatileRefresh` is nil), then `8 passed, 1 failed` (`RefreshVolatile` is nil)

- [ ] **Step 3: Implement**

<!-- sbw2:edit T5 02-search-header SwagBag/Engine/Search.lua -->
In `SwagBag/Engine/Search.lua`, find:

```lua
-- A keyword that fails while evaluating is trapped per pass: the previous dimming
-- stays and the search is reported as invalid (lastEvalError).
```

and replace it with:

```lua
-- A keyword that fails while evaluating is trapped per pass: the previous dimming
-- stays and the search is reported as invalid (lastEvalError). The error ring gets ONE
-- entry per failing query (failedId), not one per keystroke or bag update.
```

<!-- sbw2:edit T5 01-search-apply SwagBag/Engine/Search.lua -->
In `SwagBag/Engine/Search.lua`, find:

```lua
	local results, count, matches = {}, 0, 0
	local ok = SB.ErrorTrap.Run("search.eval", "none", function()
		forEach(function(button, record)
			count = count + 1
			local match = c == nil or (record ~= nil and SB.Query.Eval(c, record) == true)
			if match then
				matches = matches + 1
			end
			results[count] = { button, match }
		end)
	end)
	local ms = A.ProfileMs() - t0
```

and replace it with:

```lua
	local results, count, matches = {}, 0, 0
	local function pass()
		forEach(function(button, record)
			count = count + 1
			local match = c == nil or (record ~= nil and SB.Query.Eval(c, record) == true)
			if match then
				matches = matches + 1
			end
			results[count] = { button, match }
		end)
	end
	local ok
	if c and S.failedId == c.id then
		ok = pcall(pass) -- this query already failed and was recorded once
	else
		ok = SB.ErrorTrap.Run("search.eval", "none", pass)
		if not ok and c then
			S.failedId = c.id
		end
	end
	local ms = A.ProfileMs() - t0
```

<!-- sbw2:edit T5 03-search-volatile SwagBag/Engine/Search.lua -->
In `SwagBag/Engine/Search.lua`, find:

```lua
function S.IsActive()
	return S.active ~= nil and not S.active.empty
end
```

and replace it with:

```lua
function S.IsActive()
	return S.active ~= nil and not S.active.empty
end

-- Keywords whose answer changes with no bag update (a cooldown starts or ends, an item
-- becomes usable). The bags window re-reads those fields on BAG_UPDATE_COOLDOWN, but only
-- while the active search uses one of them (spec 9: cooldown events never rescan).
S.VOLATILE_REFRESH = { cooldown = true, usable = true }

function S.NeedsVolatileRefresh()
	if not S.IsActive() then
		return false
	end
	for _, name in ipairs(S.active.keywords) do
		if S.VOLATILE_REFRESH[name] then
			return true
		end
	end
	return false
end
```

<!-- sbw2:edit T5 04-items-refresh SwagBag/Engine/Items.lua -->
In `SwagBag/Engine/Items.lua`, find:

```lua
-- Memo key for a record by cache class (spec 7.8):
```

and replace it with:

```lua
-- Re-read the facts that change without a bag update: cooldown, usability, "new".
-- Three cheap lookups, no item-info calls. Returns the same record.
function Items.RefreshVolatile(record)
	local A = SB.Adapter
	record.onCooldown = A.IsOnCooldown(record.bag, record.slot)
	record.isUsable = A.IsUsable(record.itemID)
	local inv = SB.Inventory
	record.isNew = inv ~= nil and inv.IsNew(record.bag, record.slot) or false
	return record
end

-- Memo key for a record by cache class (spec 7.8):
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/search_spec.lua; luajit spec/runner.lua spec/items_spec.lua`
Expected: `14 passed, 0 failed`, then `9 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (30 files)`, `304 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Search.lua SwagBag/Engine/Items.lua spec/search_spec.lua spec/items_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 5: one error entry per failing search; cooldown/usable refresh helper" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 6: Layout engine, part 1: Build, Position, collapse, scroll clamp (pure)

The spec §4 layout as pure Lua (the week-1 plan's `Engine/Layout.lua`, "`Compute(prev, assignments, opts)`", is split into three functions with clear jobs):

- **`Build`**: the full layout (open, Reflow, sort, view toggle). Each slot goes to its section in physical order. Empty slots go to Free and pending items to New. New is first and Free last. New reserves `newRows` rows (2) and grows to fit every pending item at a full layout (D2).
- **`Position`**: pixel offsets for a state and a collapse set. Collapse changes section offsets only, so expanding puts every item back in the same cell (spec §6.4).
- **`Moves`**: which buttons a re-stack would move. The window uses it for the hover guard (Task 9).

The 1,290-slot fixture must build and position in ≤ 20 ms of plain Lua (spec §11.1). It measured about 0.4 ms during planning.

**Files:**
- Create: `SwagBag/Engine/Layout.lua`, `spec/layout_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/Layout.lua`)

**Interfaces:**
- Consumes: `SB.GridLayout.ClampOffset` (in the test only), `spec/fixtures/big.lua` (Task 4).
- Produces: `SB.Layout` with `NEW = "new"` and `FREE = "free"`.
  - `Key(bag, slot) -> bag * 1000 + slot`
  - `Build(slots, assign, order, opts) -> state`
    - `slots`: `{ { bag, slot, record } }` with `record` nil for an empty slot
    - `assign(record) -> id | nil`
    - `opts`: `{ columns, newRows }`
  - `Position(state, opts, collapsed) -> pos`
    - `opts`: `{ columns, size, gap, padding, header, sectionGap }`
    - `pos`: `{ cells = { {bag, slot, x, y, shown} }, byKey, placeholders = { {bag, slot, icon, x, y, shown} }, headers = { {id, y, count, overflow, collapsed} }, width, height }`
  - `Moves(oldPos, newPos) -> { keys }`
  - `Append(state, id, cell)` (internal, used by Task 7)
  - State shape: `{ columns, newRows, order, sections = { [id] = { id, cells, size, capacity?, overflow } }, where = { [key] = { section, index } }, deferred = {}, needsReflow }`.

- [ ] **Step 1: Write the failing test** (`spec/layout_spec.lua`)

<!-- sbw2:file T6 spec/layout_spec.lua -->
```lua
local Loader = dofile("spec/helpers/loader.lua")
local Big = dofile("spec/fixtures/big.lua")

-- Small numbers keep the expected pixel positions easy to check by hand: step = 12.
local OPTS = { columns = 4, size = 10, gap = 2, padding = 1, header = 5, sectionGap = 3 }

local function S(bag, slot, cat)
	return { bag = bag, slot = slot, record = cat ~= false and { cat = cat } or nil }
end

local function assign(r)
	return r.cat
end

describe("Layout (build, position, collapse)", function()
	local SB, L
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/GridLayout.lua", "SwagBag/Engine/Layout.lua" })
		L = SB.Layout
	end)

	-- a: (0,1) (0,5)   b: (0,3)   New: (0,4) pending   Free: (0,2) (1,1)
	local function sample()
		return L.Build({ S(0, 1, "a"), S(0, 2, false), S(0, 3, "b"), S(0, 4, nil), S(0, 5, "a"), S(1, 1, false) },
			assign, { "a", "b" }, { columns = 4, newRows = 2 })
	end

	local function slotsOf(sec)
		local out = {}
		for i = 1, sec.size do
			local c = sec.cells[i]
			out[i] = c and (c.bag .. ":" .. c.slot) or "hole"
		end
		return out
	end

	it("groups slots by section in physical order; empty slots go to Free, pending items to New", function()
		local st = sample()
		assert.same({ "new", "a", "b", "free" }, st.order)
		assert.same({ "0:1", "0:5" }, slotsOf(st.sections.a))
		assert.same({ "0:3" }, slotsOf(st.sections.b))
		assert.same({ "0:4" }, slotsOf(st.sections.new))
		assert.same({ "0:2", "1:1" }, slotsOf(st.sections.free))
		assert.same({ section = "a", index = 2 }, st.where[L.Key(0, 5)])
		assert.falsy(st.needsReflow)
	end)

	it("keeps New first and Free last whatever the order says; unknown ids get a section before Free", function()
		local st = L.Build({ S(0, 1, "a"), S(0, 2, "zzz") }, assign, { "free", "b", "new", "a" }, { columns = 4 })
		assert.same({ "new", "b", "a", "zzz", "free" }, st.order)
		assert.same({ "0:2" }, slotsOf(st.sections.zzz))
	end)

	it("New reserves newRows rows even when empty, and grows to fit every pending item on a full layout", function()
		assert.equal(8, L.Build({}, assign, {}, { columns = 4, newRows = 2 }).sections.new.capacity)
		local slots = {}
		for slot = 1, 9 do
			slots[slot] = S(0, slot, nil)
		end
		assert.equal(12, L.Build(slots, assign, {}, { columns = 4, newRows = 2 }).sections.new.capacity)
	end)

	it("positions headers and cells top to bottom (y grows down as negative offsets)", function()
		local pos = L.Position(sample(), OPTS, {})
		local headers = {}
		for i, h in ipairs(pos.headers) do
			headers[i] = h.id .. "@" .. h.y .. "#" .. h.count
		end
		assert.same({ "new@-1#1", "a@-31#2", "b@-49#1", "free@-67#2" }, headers)
		assert.same({ x = 1, y = -6 }, { x = pos.byKey[L.Key(0, 4)].x, y = pos.byKey[L.Key(0, 4)].y })
		assert.same({ x = 13, y = -36 }, { x = pos.byKey[L.Key(0, 5)].x, y = pos.byKey[L.Key(0, 5)].y })
		assert.same({ x = 13, y = -72 }, { x = pos.byKey[L.Key(1, 1)].x, y = pos.byKey[L.Key(1, 1)].y })
		assert.equal(48, pos.width)
		assert.equal(86, pos.height)
		assert.equal(6, #pos.cells)
	end)

	it("collapsing hides a section and re-stacks the ones below; expanding returns every item to its cell", function()
		local st = sample()
		local open = L.Position(st, OPTS, {})
		local closed = L.Position(st, OPTS, { a = true })
		assert.falsy(closed.byKey[L.Key(0, 1)].shown)
		assert.truthy(closed.headers[2].collapsed)
		assert.equal(-39, closed.headers[3].y, "b moved up by a's row")
		assert.equal(open.height - 10, closed.height)
		assert.same(open, L.Position(st, OPTS, {}))
	end)

	it("a collapsed New keeps only its header", function()
		local pos = L.Position(sample(), OPTS, { new = true })
		assert.equal(-1, pos.headers[1].y)
		assert.equal(-9, pos.headers[2].y, "a follows right after New's header")
	end)

	it("Moves lists the buttons a re-stack would move, show or hide", function()
		local st = sample()
		local open = L.Position(st, OPTS, {})
		local closed = L.Position(st, OPTS, { a = true })
		assert.same({ L.Key(0, 1), L.Key(0, 2), L.Key(0, 3), L.Key(0, 5), L.Key(1, 1) }, L.Moves(open, closed))
		assert.same({}, L.Moves(open, L.Position(st, OPTS, {})))
	end)

	it("the scroll offset is clamped when a collapse makes the content shorter (spec 4.4)", function()
		local st = sample()
		local view = 40
		local offset = SB.GridLayout.ClampOffset(46, L.Position(st, OPTS, {}).height, view)
		assert.equal(46, offset)
		offset = SB.GridLayout.ClampOffset(offset, L.Position(st, OPTS, { a = true, free = true }).height, view)
		assert.equal(26, offset)
	end)

	it("builds and positions the 1,290-slot fixture in under 20 ms of plain Lua", function()
		local ids = { "c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10", "c11", "c12", "c13", "c14", "c15", "c16" }
		local function cat(n) -- every 5th slot empty, every 23rd pending, the rest spread over 16 sections
			if n % 5 == 0 then
				return false
			elseif n % 23 == 0 then
				return nil
			end
			return ids[n % #ids + 1]
		end
		local slots, n = {}, 0
		for _, b in ipairs(Big.BAGS) do
			for slot = 1, b[2] do
				n = n + 1
				slots[n] = S(b[1], slot, cat(n))
			end
		end
		assert.equal(Big.SLOTS, n)
		local t0 = os.clock()
		local st = L.Build(slots, assign, ids, { columns = 12, newRows = 2 })
		local pos = L.Position(st, { columns = 12, size = 37, gap = 4, padding = 4, header = 20, sectionGap = 6 }, {})
		local ms = (os.clock() - t0) * 1000
		assert.equal(n, #pos.cells)
		assert.equal(45, st.sections.new.size)
		assert.truthy(ms < 20, ("%.2f ms"):format(ms))
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/layout_spec.lua`
Expected: `0 passed, 9 failed` (`cannot open SwagBag/Engine/Layout.lua`)

- [ ] **Step 3: Create `SwagBag/Engine/Layout.lua`**

<!-- sbw2:file T6 SwagBag/Engine/Layout.lua -->
```lua
-- SwagBag sections layout (spec 4, F3). Pure Lua: no frames, no WoW calls.
-- A layout STATE says which section each slot button is in, at which cell index:
--   state = { columns, newRows, order = { "new", ..., "free" },
--             sections = { [id] = { id, cells = { [i] = cell }, size, capacity?, overflow } },
--             where = { [key] = { section = id, index = i } }, deferred = {}, needsReflow }
--   cell  = { bag, slot }  (a slot button)  |  { bag, slot, placeholder = true, icon }
--   Cells may have holes (nil) so that nothing after them ever shifts.
-- Layout.Build(slots, assign, order, opts)   full layout (open, Reflow, sort, view toggle)
--   slots: physical order { { bag, slot, record } } (record nil = empty slot)
--   assign(record) -> section id, or nil (pending -> New); empty slots go to Free.
--   order: section ids in display order; New is forced first and Free last.
--   opts: { columns, newRows }
-- Layout.Position(state, opts, collapsed) -> pos   pixel positions (TOPLEFT offsets, y down
--   negative). Collapsing changes section offsets only, so expanding returns every item
--   to the same cell (spec 6.4). New always shows its header and newRows reserved rows.
--   opts: { columns, size, gap, padding, header, sectionGap }
--   pos = { cells = { {bag, slot, x, y, shown} } (display order), byKey = { [key] = cell },
--           placeholders = { {bag, slot, icon, x, y, shown} }, headers = { {id, y, count,
--           overflow, collapsed} }, width, height }
-- Layout.Moves(oldPos, newPos) -> keys whose button position changes (hover guard, 4.2 #5)
local _, SB = ...

local Layout = { NEW = "new", FREE = "free" }
SB.Layout = Layout

-- Numeric key for a (bag, slot): bags are 0-16 and slots 1-98.
function Layout.Key(bag, slot)
	return bag * 1000 + slot
end

local function section(st, id)
	local sec = st.sections[id]
	if not sec then
		sec = { id = id, cells = {}, size = 0, overflow = 0 }
		st.sections[id] = sec
	end
	return sec
end

-- Put a cell at the end of a section. Returns its index.
local function append(st, id, cell)
	local sec = section(st, id)
	sec.size = sec.size + 1
	sec.cells[sec.size] = cell
	if not cell.placeholder then
		st.where[Layout.Key(cell.bag, cell.slot)] = { section = id, index = sec.size }
	end
	return sec.size
end
Layout.Append = append

function Layout.Build(slots, assign, order, opts)
	local cols = opts.columns
	local st = { columns = cols, newRows = opts.newRows or 2, order = { Layout.NEW }, sections = {}, where = {},
		deferred = {}, needsReflow = false }
	local known = { [Layout.NEW] = true, [Layout.FREE] = true }
	for _, id in ipairs(order) do
		if not known[id] then
			known[id] = true
			st.order[#st.order + 1] = id
		end
	end
	st.order[#st.order + 1] = Layout.FREE
	for _, s in ipairs(slots) do
		local id
		if s.record == nil then
			id = Layout.FREE
		else
			id = assign(s.record) or Layout.NEW
		end
		if not known[id] then -- an id missing from the order still gets a section (before Free)
			known[id] = true
			table.insert(st.order, #st.order, id)
		end
		append(st, id, { bag = s.bag, slot = s.slot })
	end
	local new = section(st, Layout.NEW)
	new.capacity = math.max(st.newRows, math.ceil(new.size / cols)) * cols
	return st
end

local function countButtons(sec)
	local n = 0
	for i = 1, sec.size do
		local cell = sec.cells[i]
		if cell and not cell.placeholder then
			n = n + 1
		end
	end
	return n
end

function Layout.Position(st, opts, collapsed)
	collapsed = collapsed or {}
	local cols, size, gap, pad = opts.columns, opts.size, opts.gap, opts.padding
	local step = size + gap
	local pos = { cells = {}, byKey = {}, placeholders = {}, headers = {} }
	local y = pad
	for _, id in ipairs(st.order) do
		local sec = st.sections[id]
		local visible = id == Layout.NEW or (sec ~= nil and sec.size > 0)
		if visible then
			sec = sec or { cells = {}, size = 0, overflow = 0 }
			local closed = collapsed[id] == true
			pos.headers[#pos.headers + 1] = { id = id, y = -y, count = countButtons(sec), overflow = sec.overflow,
				collapsed = closed }
			y = y + opts.header
			local slots = sec.size
			if id == Layout.NEW then
				slots = math.max(sec.capacity or st.newRows * cols, sec.size)
			end
			local rows = closed and 0 or math.ceil(slots / cols)
			for i = 1, sec.size do
				local cell = sec.cells[i]
				if cell then
					local entry = {
						bag = cell.bag,
						slot = cell.slot,
						x = pad + ((i - 1) % cols) * step,
						y = -(y + math.floor((i - 1) / cols) * step),
						shown = not closed,
					}
					if cell.placeholder then
						entry.icon = cell.icon
						pos.placeholders[#pos.placeholders + 1] = entry
					else
						pos.cells[#pos.cells + 1] = entry
						pos.byKey[Layout.Key(cell.bag, cell.slot)] = entry
					end
				end
			end
			if rows > 0 then
				y = y + rows * step - gap
			end
			y = y + opts.sectionGap
		end
	end
	pos.width = pad * 2 + cols * size + (cols - 1) * gap
	pos.height = y + pad
	return pos
end

-- Keys of buttons that are shown in both layouts but at different coordinates, or that
-- become hidden/shown. Used to hold back a re-stack while one of them is under the cursor.
function Layout.Moves(oldPos, newPos)
	local out = {}
	for key, b in pairs(newPos.byKey) do
		local a = oldPos and oldPos.byKey[key]
		if not a or a.x ~= b.x or a.y ~= b.y or a.shown ~= b.shown then
			out[#out + 1] = key
		end
	end
	table.sort(out)
	return out
end
```

- [ ] **Step 4: Add it to the TOC**

<!-- sbw2:edit T6 01-toc SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
Engine/Categorizer.lua
```

and replace it with:

```text
Engine/Categorizer.lua
Engine/Layout.lua
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/layout_spec.lua`
Expected: `9 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (31 files)`, `313 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Engine/Layout.lua SwagBag/SwagBag.toc spec/layout_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 6: pure sections layout - build, position, collapse, moves" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 7: Layout engine, part 2: `Layout.Apply`, the spec §4.3 transitions while open

Every row of the spec §4.3 table that concerns positions is handled by `Layout.Apply` and has a test here.

| §4.3 row | Where |
|---|---|
| Item leaves (button in a section) | `Layout.Apply` "left" |
| Item leaves (button in Free/New) | `Layout.Apply` "left" |
| Different item arrives (in a section) | `Layout.Apply` "arrived" |
| Item arrives in a Free slot | `Layout.Apply` "arrived" |
| New overflows its 2 rows | `Layout.Apply` + `Position` header overflow |
| Bag size grows | `Layout.Apply` "added" ("removed" for a bag taken off) |
| Reflow / sort / window closes (next layout is clean) | `Layout.Build` (test here; window wiring in Tasks 9–11) |
| Count changes, lock/cooldown changes, item data loads | repaint only: the window never sends these to `Apply` (Task 10 tests) |
| Placeholder clicked | `Buttons` placeholder (Task 8, V4) |

The hover guard (spec §4.2 rule 5) is an `isBusy(bag, slot)` callback. A busy button's changes wait in `state.deferred`, in order, together with any later change to the same slot. The next `Apply` (the window retries after 300 ms) applies them. The last test is a 300-step randomized run of the spike's `noWrongItemInSection` invariant (spec AC3.4): after every change, a button inside a category section still shows the item that section was built for, and no button moves unless it changed.

**Files:**
- Modify: `SwagBag/Engine/Layout.lua`
- Test: `spec/layout_spec.lua`

**Interfaces:**
- Consumes: `Layout.Build/Position/Key` and the state shape (Task 6).
- Produces: `SB.Layout.Apply(state, changes, isBusy, collapsed) -> { moved = { keys }, placeholders = n, overflowed = n, deferred = n }`.
  - `changes`: `{ { bag, slot, kind = "left"|"arrived"|"added"|"removed", icon } }`.
  - A placeholder cell is `{ bag, slot, placeholder = true, icon }`.
  - `state.needsReflow` becomes true on any move, placeholder or hole.
  - `state.sections.new.overflow` counts arrivals that did not fit in New.

- [ ] **Step 1: Write the failing tests** (append to `spec/layout_spec.lua`)

<!-- sbw2:edit T7 10-layout-spec spec/layout_spec.lua -->
In `spec/layout_spec.lua`, find:

```lua
	it("builds and positions the 1,290-slot fixture in under 20 ms of plain Lua", function()
```

and replace it with:

```lua
	it("builds and positions the 1,290-slot fixture in under 20 ms of plain Lua (spec 11.1)", function()
```

<!-- sbw2:edit T7 11-layout-spec-apply spec/layout_spec.lua -->
In `spec/layout_spec.lua`, find:

```lua
		assert.equal(45, st.sections.new.size)
		assert.truthy(ms < 20, ("%.2f ms"):format(ms))
	end)
end)
```

and replace it with:

```lua
		assert.equal(45, st.sections.new.size)
		assert.truthy(ms < 20, ("%.2f ms"):format(ms))
	end)
end)

describe("Layout.Apply (spec 4.3: what happens while the window is open)", function()
	local SB, L, st
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Layout.lua" })
		L = SB.Layout
		-- a: (0,1) (0,5)   b: (0,3)   New: (0,4) [capacity 8]   Free: (0,2) (1,1)
		st = L.Build({ S(0, 1, "a"), S(0, 2, false), S(0, 3, "b"), S(0, 4, nil), S(0, 5, "a"), S(1, 1, false) },
			assign, { "a", "b" }, { columns = 4, newRows = 2 })
	end)

	local function where(bag, slot)
		local w = st.where[L.Key(bag, slot)]
		return w and (w.section .. "#" .. w.index)
	end

	local function change(bag, slot, kind, icon)
		return { bag = bag, slot = slot, kind = kind, icon = icon }
	end

	it("an item leaving a category section leaves a placeholder with its icon; the button goes to Free", function()
		local r = L.Apply(st, { change(0, 1, "left", 111) })
		local ph = st.sections.a.cells[1]
		assert.same({ bag = 0, slot = 1, placeholder = true, icon = 111 }, ph)
		assert.equal("free#3", where(0, 1))
		assert.same({ L.Key(0, 1) }, r.moved)
		assert.equal(1, r.placeholders)
		assert.truthy(st.needsReflow)
		local pos = L.Position(st, OPTS, {})
		assert.same({ 1, -36 }, { pos.placeholders[1].x, pos.placeholders[1].y }, "placeholder sits where the button was")
		assert.same({ 25, -72 }, { pos.byKey[L.Key(0, 1)].x, pos.byKey[L.Key(0, 1)].y }, "button is Free's 3rd cell")
		assert.equal(1, pos.headers[2].count, "a now counts one item")
	end)

	it("an item leaving a button that is in Free or New only repaints", function()
		local r = L.Apply(st, { change(0, 4, "left"), change(0, 2, "left") })
		assert.equal("new#1", where(0, 4))
		assert.equal("free#1", where(0, 2))
		assert.same({}, r.moved)
		assert.falsy(st.needsReflow)
	end)

	it("a different item arriving in a category section leaves a placeholder; the button goes to New", function()
		L.Apply(st, { change(0, 3, "arrived", 333) })
		assert.truthy(st.sections.b.cells[1].placeholder)
		assert.equal("new#2", where(0, 3))
	end)

	it("an item arriving in a Free slot moves its button to New and leaves a hole: nothing else shifts", function()
		local before = L.Position(st, OPTS, {})
		L.Apply(st, { change(0, 2, "arrived") })
		assert.equal("new#2", where(0, 2))
		assert.is_nil(st.sections.free.cells[1])
		local after = L.Position(st, OPTS, {})
		assert.same({ L.Key(0, 2) }, L.Moves(before, after))
	end)

	it("an item arriving in a button already in New only repaints", function()
		local r = L.Apply(st, { change(0, 4, "arrived") })
		assert.equal("new#1", where(0, 4))
		assert.same({}, r.moved)
	end)

	it("when New's two rows are full, arrivals go to the end of Free and New's header says how many", function()
		local slots = { S(0, 1, nil) }
		for slot = 2, 12 do
			slots[slot] = S(0, slot, "a")
		end
		slots[13] = S(0, 13, false)
		st = L.Build(slots, assign, { "a" }, { columns = 4, newRows = 2 })
		local changes = {}
		for slot = 2, 10 do
			changes[#changes + 1] = change(0, slot, "arrived")
		end
		changes[#changes + 1] = change(0, 13, "arrived") -- already in Free: stays, counted
		local r = L.Apply(st, changes)
		assert.equal(8, st.sections.new.size)
		assert.equal("new#8", where(0, 8))
		assert.equal("free#2", where(0, 9))
		assert.equal("free#3", where(0, 10))
		assert.equal("free#1", where(0, 13))
		assert.equal(3, r.overflowed)
		assert.equal(3, L.Position(st, OPTS, {}).headers[1].overflow)
	end)

	it("with New collapsed, arrivals go to the end of Free instead of disappearing", function()
		L.Apply(st, { change(0, 3, "arrived") }, nil, { new = true })
		assert.equal("free#3", where(0, 3))
		assert.equal(1, st.sections.new.overflow)
	end)

	it("a bag that grows adds its new slots at the end of Free; a removed slot leaves a hole", function()
		L.Apply(st, { change(2, 1, "added"), change(2, 2, "added"), change(1, 1, "removed") })
		assert.equal("free#3", where(2, 1))
		assert.equal("free#4", where(2, 2))
		assert.is_nil(where(1, 1))
		assert.is_nil(st.sections.free.cells[2])
		assert.truthy(st.needsReflow)
	end)

	it("a button under the cursor does not move: its changes wait, in order, for the next Apply", function()
		local hovered = true
		local function busy(bag, slot)
			return hovered and bag == 0 and slot == 1
		end
		local r = L.Apply(st, { change(0, 1, "left", 111), change(0, 5, "left", 555) }, busy)
		assert.equal(1, r.deferred)
		assert.equal("a#1", where(0, 1))
		assert.equal("free#3", where(0, 5), "other buttons are not held back")
		r = L.Apply(st, { change(0, 1, "arrived", 112) }, busy)
		assert.equal(2, r.deferred, "a later change of a held slot waits behind it")
		hovered = false
		r = L.Apply(st, {}, busy)
		assert.equal(0, r.deferred)
		assert.truthy(st.sections.a.cells[1].placeholder)
		assert.equal(111, st.sections.a.cells[1].icon)
		assert.equal("new#2", where(0, 1), "left then arrived: Free, then New")
	end)

	it("an item on the cursor holds every move", function()
		local r = L.Apply(st, { change(0, 1, "left"), change(0, 3, "arrived") }, function() return true end)
		assert.equal(2, r.deferred)
		assert.same({}, r.moved)
		assert.falsy(st.needsReflow)
	end)

	it("the next full layout has no placeholders and clears needsReflow", function()
		L.Apply(st, { change(0, 1, "left") })
		st = L.Build({ S(0, 1, false), S(0, 2, false), S(0, 3, "b"), S(0, 4, nil), S(0, 5, "a") }, assign, { "a", "b" },
			{ columns = 4 })
		assert.falsy(st.needsReflow)
		assert.same({}, L.Position(st, OPTS, {}).placeholders)
	end)

	it("section truth: after any sequence of changes, a button in a category section still holds its item", function()
		local content, built, slots = {}, {}, {}
		for slot = 1, 20 do
			content[slot] = slot % 4 ~= 0 and slot or nil
			built[slot] = content[slot]
			slots[slot] = { bag = 0, slot = slot, record = content[slot] and { cat = "c" .. (content[slot] % 3) } or nil }
		end
		st = L.Build(slots, assign, { "c0", "c1", "c2" }, { columns = 4, newRows = 2 })
		local seed = 7
		local function rand(n)
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % n + 1
		end
		for _ = 1, 300 do
			local slot = rand(20)
			local new = rand(3) == 1 and nil or rand(30)
			if new ~= content[slot] then
				local before = {}
				for k, w in pairs(st.where) do
					before[k] = w.section .. "#" .. w.index
				end
				content[slot] = new
				local r = L.Apply(st, { change(0, slot, new == nil and "left" or "arrived") })
				local moved = {}
				for _, k in ipairs(r.moved) do
					moved[k] = true
				end
				for k, w in pairs(st.where) do
					if w.section ~= "new" and w.section ~= "free" then
						assert.equal(built[k % 1000], content[k % 1000], "wrong item in section " .. w.section)
					end
					if not moved[k] then
						assert.equal(before[k], w.section .. "#" .. w.index, "a button moved that was not changed")
					end
				end
			end
		end
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/layout_spec.lua`
Expected: `9 passed, 12 failed` (`attempt to call field 'Apply' (a nil value)`)

- [ ] **Step 3: Implement `Layout.Apply`**

<!-- sbw2:edit T7 01-layout-header SwagBag/Engine/Layout.lua -->
In `SwagBag/Engine/Layout.lua`, find:

```lua
-- Layout.Moves(oldPos, newPos) -> keys whose button position changes (hover guard, 4.2 #5)
local _, SB = ...
```

and replace it with:

```lua
-- Layout.Moves(oldPos, newPos) -> keys whose button position changes (hover guard, 4.2 #5)
-- Layout.Apply(state, changes, isBusy, collapsed) -> result   while the window is open
--   changes: { { bag, slot, kind, icon } } in order. kind:
--     "left"    the slot is now empty        "arrived" a different item is now in the slot
--     "added"   the slot is new (bag grew)   "removed" the slot no longer exists
--   isBusy(bag, slot) -> true while that button must not move (spec 4.2 rule 5: under the
--     mouse, or an item on the cursor). Its changes wait in state.deferred, in order, and
--     the next Apply retries them (the window calls Apply(state, {}) 300 ms later).
--   result = { moved = { keys }, placeholders = n, overflowed = n, deferred = n }
-- Transitions (spec 4.3 table):
--   left    + button in a category section -> placeholder (old icon) in its cell, button to Free's end
--   left    + button in Free or New        -> stays (repaint only)
--   arrived + button in a category section -> placeholder in its cell, button to New's next cell
--   arrived + button in Free               -> to New's next cell; its Free cell becomes a hole
--   arrived + button in New                -> stays (repaint only)
--   New full (its reserved rows) or collapsed -> the button goes to Free's end instead (one
--     already in Free stays put) and New's header counts it ("+N more below")
--   added -> a new button at Free's end;  removed -> its cell becomes a hole
-- Nothing else ever moves, so no other button changes position. Any placeholder, move or
-- hole sets state.needsReflow; the next full Build (close + open, Reflow, sort) clears it.
local _, SB = ...
```

<!-- sbw2:edit T7 02-layout-apply SwagBag/Engine/Layout.lua -->
In `SwagBag/Engine/Layout.lua`, find:

```lua
	table.sort(out)
	return out
end
```

and replace it with:

```lua
	table.sort(out)
	return out
end

-- Remove a button from its cell (leaving a hole). Returns where it was and the cell.
local function take(st, key)
	local w = st.where[key]
	local sec = st.sections[w.section]
	local cell = sec.cells[w.index]
	sec.cells[w.index] = nil
	st.where[key] = nil
	return w, cell
end

local function newHasRoom(st, collapsed)
	local new = section(st, Layout.NEW)
	return not collapsed[Layout.NEW] and new.size < (new.capacity or st.newRows * st.columns)
end

local function overflow(st, result)
	local new = section(st, Layout.NEW)
	new.overflow = new.overflow + 1
	result.overflowed = result.overflowed + 1
end

local function applyOne(st, ch, collapsed, result)
	local key = Layout.Key(ch.bag, ch.slot)
	local w = st.where[key]
	if ch.kind == "added" then
		if not w then
			append(st, Layout.FREE, { bag = ch.bag, slot = ch.slot })
			result.moved[#result.moved + 1] = key
		end
		return
	end
	if not w then
		return
	end
	local id = w.section
	if ch.kind == "removed" then
		take(st, key)
	elseif ch.kind == "left" then
		if id == Layout.FREE or id == Layout.NEW then
			return
		end
		local old, cell = take(st, key)
		st.sections[id].cells[old.index] = { bag = ch.bag, slot = ch.slot, placeholder = true, icon = ch.icon }
		result.placeholders = result.placeholders + 1
		append(st, Layout.FREE, cell)
	elseif ch.kind == "arrived" then
		if id == Layout.NEW then
			return
		end
		if id == Layout.FREE then
			if not newHasRoom(st, collapsed) then
				overflow(st, result)
				return
			end
			local _, cell = take(st, key)
			append(st, Layout.NEW, cell)
		else
			local old, cell = take(st, key)
			st.sections[id].cells[old.index] = { bag = ch.bag, slot = ch.slot, placeholder = true, icon = ch.icon }
			result.placeholders = result.placeholders + 1
			if newHasRoom(st, collapsed) then
				append(st, Layout.NEW, cell)
			else
				append(st, Layout.FREE, cell)
				overflow(st, result)
			end
		end
	else
		return
	end
	st.needsReflow = true
	result.moved[#result.moved + 1] = key
end

function Layout.Apply(st, changes, isBusy, collapsed)
	collapsed = collapsed or {}
	local result = { moved = {}, placeholders = 0, overflowed = 0, deferred = 0 }
	local queue = st.deferred
	for _, ch in ipairs(changes or {}) do
		queue[#queue + 1] = ch
	end
	st.deferred = {}
	local held = {}
	for _, ch in ipairs(queue) do
		local key = Layout.Key(ch.bag, ch.slot)
		if held[key] or (isBusy and isBusy(ch.bag, ch.slot)) then
			held[key] = true -- later changes of a held slot wait too, so order is kept
			st.deferred[#st.deferred + 1] = ch
		else
			applyOne(st, ch, collapsed, result)
		end
	end
	result.deferred = #st.deferred
	return result
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/layout_spec.lua`
Expected: `21 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (31 files)`, `325 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Layout.lua spec/layout_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 7: Layout.Apply - spec 4.3 placeholders, New/Free, overflow, hover guard" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 8: Placeholder pool, section headers, Adapter cursor and sort helpers

The WoW-side building blocks for Tasks 9–11, each tested with fake frames:

- **Placeholders** (spec §4.1, §4.2 rule 3, check V4): pooled **plain Frames**, parented to the window's scroll child, showing the old icon desaturated. They have **no** click, drag or receive-drag script. Mouse-down (and hover) only shows the tooltip "This item moved or was used - items regroup when you close the bag." They are plain frames, so they may be created in combat (ruling P9).
- **Section headers** (spec §4.1): pooled plain Buttons. A header reads `- Consumables (12)` (`+` while collapsed), and New adds `  +3 more below`. Click and receive-drag call actions the window supplies.
- **Adapter**: `CursorItem()` (`GetCursorInfo` → itemID, link), `ClearCursor()` and `SortBags()` (`C_Container.SortBags`). C_* stays inside the Adapter. The mock gains `m.cursor`, `m.cleared` and `m.sorts`. Four new optional checks, which only degrade features if missing.

**Files:**
- Create: `SwagBag/UI/SectionHeaders.lua`, `spec/buttons_spec.lua`, `spec/adapter_spec.lua`
- Modify: `SwagBag/UI/Buttons.lua`, `SwagBag/Core/Adapter.lua`, `SwagBag/Locale/enUS.lua`, `.luacheckrc`, `spec/mock_adapter.lua`, `SwagBag/SwagBag.toc` (append to `# UI` after `UI/Buttons.lua`: `UI/SectionHeaders.lua`)

**Interfaces:**
- Consumes: `SB.ErrorTrap.Guard`, `SB.L`, and the WoW globals `CreateFrame`, `GameTooltip`, `GetCursorInfo`, `ClearCursor`.
- Produces:
  - Placeholders: `SB.Buttons.AcquirePlaceholder(parent, icon, size, x, y) -> frame` and `SB.Buttons.ReleasePlaceholders()`. Pool fields `placeholderPool` and `placeholdersInUse`.
  - Headers: `SB.SectionHeaders.Label(name, count, collapsed, overflow) -> string`, `Acquire(parent, sectionId, label, x, y, width) -> button` (the button carries `.sectionId` and `.text`), `ReleaseAll()`, and the window-set callbacks `onClick(sectionId)`/`onDrop(sectionId)`. The pool lists are `pool` and `inUse`.
  - Adapter: `SB.Adapter.CursorItem() -> itemID, link | nil`, `ClearCursor()`, `SortBags() -> boolean`.
  - Mock adapter: `m.cursor = { itemID, link } | nil`, `m.cleared` (count), `m.sorts` (count).

- [ ] **Step 1: Write the failing tests**

`spec/buttons_spec.lua`:

<!-- sbw2:file T8 spec/buttons_spec.lua -->
```lua
-- luacheck: globals GameTooltip
local Loader = dofile("spec/helpers/loader.lua")

-- Permissive fake frame: records scripts, points, text and every other call.
local function fakeFrame(kind)
	local f = { kind = kind, scripts = {}, shown = true, points = {}, calls = {} }
	return setmetatable(f, {
		__index = function(_, name)
			if name == "SetScript" then
				return function(self, n, fn) self.scripts[n] = fn end
			elseif name == "Show" then
				return function(self) self.shown = true end
			elseif name == "Hide" then
				return function(self) self.shown = false end
			elseif name == "SetPoint" then
				return function(self, ...) self.points[#self.points + 1] = { ... } end
			elseif name == "ClearAllPoints" then
				return function(self) self.points = {} end
			elseif name == "CreateTexture" or name == "CreateFontString" then
				return function() return fakeFrame("region") end
			elseif name == "SetText" then
				return function(self, t) self.text = t end
			end
			return function(self, ...) self.calls[name] = { ... } end
		end,
	})
end

local FILES = { "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua" }

describe("Placeholders (spec 4.2 rule 3, check V4)", function()
	local SB, created, tip
	before_each(function()
		SB = Loader.New(FILES)
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		created = {}
		CreateFrame = function(kind)
			local f = fakeFrame(kind)
			created[#created + 1] = f
			return f
		end
		tip = { shown = false }
		GameTooltip = {
			SetOwner = function(_, owner) tip.owner = owner end,
			SetText = function(_, text) tip.text = text end,
			Show = function() tip.shown = true end,
			Hide = function() tip.shown = false end,
		}
	end)

	after_each(function()
		GameTooltip = nil
	end)

	it("is a plain Frame showing the old icon, desaturated, at the given cell", function()
		local parent = fakeFrame("Frame")
		local p = SB.Buttons.AcquirePlaceholder(parent, 12345, 37, 41, -20)
		assert.equal("Frame", p.kind)
		assert.equal(12345, p.icon.calls.SetTexture[1])
		assert.equal(true, p.icon.calls.SetDesaturated[1])
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 41, -20 }, p.points[1])
		assert.same({ 37, 37 }, p.calls.SetSize)
		assert.truthy(p.shown)
	end)

	it("clicking it only shows a tooltip: it has no click, drag or drop handler (V4)", function()
		local p = SB.Buttons.AcquirePlaceholder(fakeFrame("Frame"), 1, 37, 0, 0)
		local names = {}
		for name in pairs(p.scripts) do
			names[#names + 1] = name
		end
		table.sort(names)
		assert.same({ "OnEnter", "OnLeave", "OnMouseDown" }, names)
		p.scripts.OnMouseDown(p, "RightButton")
		assert.truthy(tip.shown)
		assert.equal(SB.L.PLACEHOLDER_TIP, tip.text)
		assert.equal(p, tip.owner)
		p.scripts.OnLeave(p)
		assert.falsy(tip.shown)
	end)

	it("is pooled: released placeholders hide and are reused", function()
		local parent = fakeFrame("Frame")
		local a = SB.Buttons.AcquirePlaceholder(parent, 1, 37, 0, 0)
		SB.Buttons.ReleasePlaceholders()
		assert.falsy(a.shown)
		assert.equal(a, SB.Buttons.AcquirePlaceholder(parent, 2, 37, 0, 0))
		assert.equal(1, #created)
	end)
end)

describe("Section headers", function()
	local SB, H
	before_each(function()
		SB = Loader.New(FILES)
		CreateFrame = function(kind) return fakeFrame(kind) end
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		H = SB.SectionHeaders
	end)

	it("labels show the collapse marker, name, count and New's overflow", function()
		assert.equal("- Consumables (12)", H.Label("Consumables", 12, false, 0))
		assert.equal("+ Gear (3)", H.Label("Gear", 3, true))
		assert.equal("- New (8)  +3 more below", H.Label("New", 8, false, 3))
	end)

	it("are pooled plain Buttons whose click and drop call the window's actions with the section id", function()
		local clicks, drops = {}, {}
		H.onClick = function(id) clicks[#clicks + 1] = id end
		H.onDrop = function(id) drops[#drops + 1] = id end
		local parent = fakeFrame("Frame")
		local h = H.Acquire(parent, "c_gear", "- Gear (3)", 4, -30, 300)
		assert.equal("Button", h.kind)
		assert.equal("- Gear (3)", h.text.text)
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 4, -30 }, h.points[1])
		h.scripts.OnClick(h)
		h.scripts.OnReceiveDrag(h)
		assert.same({ "c_gear" }, clicks)
		assert.same({ "c_gear" }, drops)
		H.ReleaseAll()
		assert.falsy(h.shown)
		assert.equal(h, H.Acquire(parent, "new", "x", 0, 0, 10))
		assert.equal("new", h.sectionId)
	end)
end)
```

`spec/adapter_spec.lua` (tests the real `Adapter.lua`, not the mock):

<!-- sbw2:file T8 spec/adapter_spec.lua -->
```lua
-- luacheck: globals GetCursorInfo ClearCursor C_Container
-- The REAL Adapter.lua (not the mock): cursor and sort helpers added in week 2.
describe("Adapter cursor and sort helpers", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		GetCursorInfo, ClearCursor, C_Container = nil, nil, nil
	end)

	it("CursorItem returns the item on the cursor, and nothing for spells, errors or a missing API", function()
		assert.is_nil(A.CursorItem())
		GetCursorInfo = function() return "item", 211880, "|Hitem:211880|h[Potion]|h" end
		assert.same({ 211880, "|Hitem:211880|h[Potion]|h" }, { A.CursorItem() })
		GetCursorInfo = function() return "spell", 1, nil end
		assert.is_nil(A.CursorItem())
		GetCursorInfo = function() error("broken") end
		assert.is_nil(A.CursorItem())
	end)

	it("ClearCursor and SortBags call the game only when it has them", function()
		A.ClearCursor()
		assert.falsy(A.SortBags())
		local cleared, sorted = 0, 0
		ClearCursor = function() cleared = cleared + 1 end
		C_Container = { SortBags = function() sorted = sorted + 1 end }
		A.ClearCursor()
		assert.truthy(A.SortBags())
		assert.same({ 1, 1 }, { cleared, sorted })
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/buttons_spec.lua; luajit spec/runner.lua spec/adapter_spec.lua`
Expected: `0 passed, 5 failed`, then `0 passed, 2 failed`

- [ ] **Step 3: Strings, lint globals and the mock**

<!-- sbw2:edit T8 05-locale SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.CAT_FREE = "Free"
```

and replace it with:

```lua
L.CAT_FREE = "Free"
L.HEADER_LABEL = "%s %s (%d)"
L.HEADER_OVERFLOW = "  +%d more below"
L.PLACEHOLDER_TIP = "This item moved or was used - items regroup when you close the bag."
```

<!-- sbw2:edit T8 04-luacheck .luacheckrc -->
In `.luacheckrc`, find:

```lua
	"StaticPopup_Show", "YES", "NO",
}
```

and replace it with:

```lua
	"StaticPopup_Show", "YES", "NO",
	"GetCursorInfo", "ClearCursor", "GameTooltip",
}
```

<!-- sbw2:edit T8 06-mock spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
	function m.AddOnState(name)
		local v = m.addons[name]
		if v == nil or v == false then
			return false, nil
		end
		return true, v
	end
```

and replace it with:

```lua
	function m.AddOnState(name)
		local v = m.addons[name]
		if v == nil or v == false then
			return false, nil
		end
		return true, v
	end

	-- Cursor and sort: set m.cursor = { itemID, link } to simulate a picked-up item.
	m.cursor = nil
	m.cleared = 0
	m.sorts = 0
	function m.CursorItem()
		if m.cursor then
			return m.cursor.itemID, m.cursor.link
		end
		return nil
	end

	function m.ClearCursor()
		m.cursor = nil
		m.cleared = m.cleared + 1
	end

	function m.SortBags()
		m.sorts = m.sorts + 1
		return true
	end
```

- [ ] **Step 4: Placeholder pool in `SwagBag/UI/Buttons.lua`**

<!-- sbw2:edit T8 01-buttons-placeholders SwagBag/UI/Buttons.lua -->
In `SwagBag/UI/Buttons.lua`, find:

```lua
-- Full dim: alpha on the whole button covers icon, border, count and glows.
function Buttons.SetDimmed(button, dimmed)
	button:SetAlpha(dimmed and Buttons.DIM_ALPHA or 1)
end
```

and replace it with:

```lua
-- Full dim: alpha on the whole button covers icon, border, count and glows.
function Buttons.SetDimmed(button, dimmed)
	button:SetAlpha(dimmed and Buttons.DIM_ALPHA or 1)
end

---------------------------------------------------------------------------
-- Placeholders (spec 4.1, 4.2 rule 3): pooled plain Frames showing the icon of an
-- item that moved or was used. A placeholder never responds to item interaction: it
-- has no click, drag or drop script; mouse-down only shows a tooltip (check V4).
-- Plain frames, so creating one in combat is allowed (ruling P9).
---------------------------------------------------------------------------
Buttons.placeholderPool, Buttons.placeholdersInUse = {}, {}
Buttons.PLACEHOLDER_ALPHA = 0.5

local function placeholderTip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(SB.L.PLACEHOLDER_TIP, 1, 1, 1, 1, true)
	GameTooltip:Show()
end

local function hideTip()
	GameTooltip:Hide()
end

local function createPlaceholder(parent)
	local Guard = SB.ErrorTrap.Guard
	local p = CreateFrame("Frame", nil, parent)
	p:EnableMouse(true)
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetAllPoints(p)
	p.icon:SetDesaturated(true)
	p:SetAlpha(Buttons.PLACEHOLDER_ALPHA)
	p:SetScript("OnEnter", Guard("placeholder.enter", placeholderTip, "bags"))
	p:SetScript("OnMouseDown", Guard("placeholder.click", placeholderTip, "bags"))
	p:SetScript("OnLeave", Guard("placeholder.leave", hideTip, "bags"))
	return p
end

-- A shown placeholder of `size` at TOPLEFT offset (x, y) inside parent.
function Buttons.AcquirePlaceholder(parent, icon, size, x, y)
	local p = table.remove(Buttons.placeholderPool) or createPlaceholder(parent)
	p:SetSize(size, size)
	p.icon:SetTexture(icon)
	p:ClearAllPoints()
	p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	p:Show()
	Buttons.placeholdersInUse[#Buttons.placeholdersInUse + 1] = p
	return p
end

function Buttons.ReleasePlaceholders()
	for i = #Buttons.placeholdersInUse, 1, -1 do
		local p = Buttons.placeholdersInUse[i]
		p:Hide()
		Buttons.placeholdersInUse[i] = nil
		Buttons.placeholderPool[#Buttons.placeholderPool + 1] = p
	end
end
```

- [ ] **Step 5: Create `SwagBag/UI/SectionHeaders.lua`**

<!-- sbw2:file T8 SwagBag/UI/SectionHeaders.lua -->
```lua
-- SwagBag section headers (spec 4.1: "Section header: plain Button, pooled").
-- A header reads "- Consumables (12)" ("+" while collapsed); New adds "+N more below"
-- when arrivals overflowed into Free (spec 4.3). Plain Buttons, so creating one in
-- combat is allowed (ruling P9). The window supplies the actions:
--   Headers.onClick(sectionId)  left-click (collapse/expand, or drop the cursor item)
--   Headers.onDrop(sectionId)   an item dragged onto the header (AC4.3)
local _, SB = ...

local L = SB.L
local H = { pool = {}, inUse = {}, HEIGHT = 18 }
SB.SectionHeaders = H

-- Pure: the header text.
function H.Label(name, count, collapsed, overflow)
	local text = L.HEADER_LABEL:format(collapsed and "+" or "-", name, count)
	if overflow and overflow > 0 then
		text = text .. L.HEADER_OVERFLOW:format(overflow)
	end
	return text
end

local function create(parent)
	local Guard = SB.ErrorTrap.Guard
	local h = CreateFrame("Button", nil, parent)
	h:SetHeight(H.HEIGHT)
	h:EnableMouse(true)
	h:RegisterForClicks("LeftButtonUp")
	h.bg = h:CreateTexture(nil, "BACKGROUND")
	h.bg:SetAllPoints(h)
	h.bg:SetColorTexture(1, 1, 1, 0.06)
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h.text:SetPoint("LEFT", h, "LEFT", 4, 0)
	h.text:SetJustifyH("LEFT")
	h:SetScript("OnClick", Guard("header.click", function(self)
		if H.onClick then
			H.onClick(self.sectionId)
		end
	end, "bags"))
	h:SetScript("OnReceiveDrag", Guard("header.drop", function(self)
		if H.onDrop then
			H.onDrop(self.sectionId)
		end
	end, "bags"))
	return h
end

-- A shown header for sectionId at (x, y) inside parent.
function H.Acquire(parent, sectionId, label, x, y, width)
	local h = table.remove(H.pool) or create(parent)
	h.sectionId = sectionId
	h.text:SetText(label)
	h:SetWidth(width)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	h:Show()
	H.inUse[#H.inUse + 1] = h
	return h
end

function H.ReleaseAll()
	for i = #H.inUse, 1, -1 do
		local h = H.inUse[i]
		h:Hide()
		h.sectionId = nil
		H.inUse[i] = nil
		H.pool[#H.pool + 1] = h
	end
end
```

- [ ] **Step 6: Adapter helpers and checks, then the TOC**

<!-- sbw2:edit T8 02-adapter-cursor SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
function A.RequestLoad(itemID)
	pcall(C_Item.RequestLoadItemDataByID, itemID)
end
```

and replace it with:

```lua
function A.RequestLoad(itemID)
	pcall(C_Item.RequestLoadItemDataByID, itemID)
end

---------------------------------------------------------------------------
-- Cursor and sorting (week 2: drag onto a section header, sort button)
---------------------------------------------------------------------------
-- itemID, link of the item on the cursor; nil when the cursor holds no item.
function A.CursorItem()
	if not GetCursorInfo then
		return nil
	end
	local ok, kind, itemID, link = pcall(GetCursorInfo)
	if ok and kind == "item" and type(itemID) == "number" and not isSecret(itemID) then
		return itemID, link
	end
	return nil
end

-- Puts a picked-up item back where it came from.
function A.ClearCursor()
	if ClearCursor then
		pcall(ClearCursor)
	end
end

-- Blizzard's own bag sort. Returns true if it was started.
function A.SortBags()
	if not (C_Container and C_Container.SortBags) then
		return false
	end
	return (pcall(C_Container.SortBags))
end
```

<!-- sbw2:edit T8 03-adapter-checks SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
	{ path = "C_Container.GetContainerItemQuestInfo", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "C_Container.GetContainerItemQuestInfo", window = "bags", required = false },
	{ path = "C_Container.SortBags", window = "bags", required = false },
	{ path = "GetCursorInfo", window = "bags", required = false },
	{ path = "ClearCursor", window = "bags", required = false },
	{ path = "GameTooltip", window = "bags", required = false },
```

<!-- sbw2:edit T8 07-toc SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
UI/Buttons.lua
```

and replace it with:

```text
UI/Buttons.lua
UI/SectionHeaders.lua
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/buttons_spec.lua; luajit spec/runner.lua spec/adapter_spec.lua`
Expected: `5 passed, 0 failed`, then `2 passed, 0 failed`

- [ ] **Step 8: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (32 files)`, `332 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 9: Commit**

```bash
git add SwagBag/UI/Buttons.lua SwagBag/UI/SectionHeaders.lua SwagBag/Core/Adapter.lua SwagBag/Locale/enUS.lua \
  SwagBag/SwagBag.toc .luacheckrc spec/mock_adapter.lua spec/buttons_spec.lua spec/adapter_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 8: placeholder pool (tooltip only), section headers, cursor and sort helpers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 9: Bags window category view: sections, headers, collapse persistence, grid/categories toggle

`UI/BagsWindow.lua` is rewritten around two views. The category view is the default (spec F3). Everything from week 1 stays: the grid view, position, scale, Esc, scroll clamp, hidden until laid out, and the `SB_BAGS_LAYOUT`/`SB_BAGS_UPDATED` events the search box listens to.

- **Full layout.** `W.Layout(reason)` describes every slot, categorizes it (Task 4), and calls `Layout.Build` + `Position` (Task 6). It then places buttons, placeholders and headers. Unchanged buttons get no `SetPoint`.
- **Headers.** Clicking a header collapses or expands it. The state is saved in `SwagBagCharDB.ui.collapsed.bags` (AC3.2), so it survives close, reopen and `/reload`. A collapse is a re-stack of section offsets only, and it waits while a button that would move is under the mouse (spec §6.4, rule 5).
- **View toggle.** The header button switches grid ↔ categories without `/reload`, in or out of combat (AC3.1). The title flashes the new view.
- **Scaling.** Ctrl+wheel now only resizes the window. It no longer regroups (week-1 minor, ledger line 58).
- **Report.** The report gains `Last bags layout: X ms (reason)`, so the user's report shows the spec §9 open budget (≤ 25 ms first open; ledger ruling P10).

Live updates while open are still week 1's "repaint in place" here; Task 10 replaces them with spec §4.3. Do not hand this build to the user before Task 10.

This task also fixes two deferred week-1 minors: the stale header comment of `BagsWindow.lua` (ledger line 58) and the WoW globals `bagswindow_spec` leaks into other spec files.

**Files:**
- Modify (replace whole file): `SwagBag/UI/BagsWindow.lua`
- Create: `spec/bagswindow_sections_spec.lua`
- Modify: `SwagBag/Locale/enUS.lua`, `SwagBag/Core/Report.lua`, `spec/bagswindow_spec.lua` (grid view only, stubs for headers and placeholders, `after_each` clears its globals), `spec/report_spec.lua`

**Interfaces:**
- Consumes: `SB.Categories.SectionOrder/Name` (Task 3), `SB.Categorizer.Assign` (Task 4), `SB.Layout.Build/Position/Moves` (Task 6), `SB.SectionHeaders.Acquire/ReleaseAll/Label/onClick` and `SB.Buttons.AcquirePlaceholder/ReleasePlaceholders` (Task 8), `SB.Config.Get("bags.view"/"bags.newRows"/"bags.columns")` and `Config.UI()` (Task 2), `SB.Adapter.CursorItem` (Task 8), and `SB.Items.Describe`, `SB.GridLayout`, `SB.Debounce` (on `main`).
- Produces (`SB.BagsWindow`, in addition to week 1's `Open/Close/Toggle/IsOpen/Layout/ForEachSlot/ClampScroll/SetScale/RestorePosition/frame/scroll/child/records/cells/stats`):
  - `View() -> "sections"|"grid"`, `SetView(view)`, `ToggleView()`.
  - `Collapsed() -> { [sectionId] = true }`, `ToggleSection(id)`, `Restack() -> boolean` (false = held back, retried after 300 ms).
  - `RequestLayout(reason) -> boolean`: a full layout that waits while an item is on the cursor or the mouse is over the items.
  - `Flash(text)`, `Render()`, `ButtonBusy(bag, slot) -> boolean`.
  - Fields `state`, `pos`, `sizes`, `placed`, `viewButton`, `RETRY = 0.3`.
  - `OnHide` clears `state`/`pos`, releases placeholders and emits `SB_BAGS_CLOSED`.
  - Report line `Last bags layout: %.1f ms (%s)`.

- [ ] **Step 1: Write the failing tests**

`spec/bagswindow_sections_spec.lua`. It runs the real engine (Inventory, Items, Keywords, Categories, Categorizer, Layout, SectionHeaders) under fake frames and a fake button pool:

<!-- sbw2:file T9 spec/bagswindow_sections_spec.lua -->
```lua
-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown
-- The bags window's category view, end to end over the real engine (Inventory, Items,
-- Keywords, Categories, Categorizer, Layout, SectionHeaders) with fake frames and buttons.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
}

-- Fake frame: shown state, scripts (Hide fires OnHide like the client), points, text, mouse-over.
local function newFake(kind)
	local f = { kind = kind, shown = false, scale = 1, vscroll = 0, w = 0, h = 0, scripts = {}, points = {}, calls = {} }
	local methods = {
		IsShown = function(self) return self.shown end,
		Show = function(self) self.shown = true end,
		Hide = function(self)
			local was = self.shown
			self.shown = false
			if was and self.scripts.OnHide then
				self.scripts.OnHide(self)
			end
		end,
		IsMouseOver = function(self) return self.mouseOver == true end,
		SetScale = function(self, s) self.scale = s end,
		GetScale = function(self) return self.scale end,
		SetSize = function(self, w, h) self.w, self.h = w, h end,
		GetHeight = function(self) return self.h end,
		SetScript = function(self, n, fn) self.scripts[n] = fn end,
		SetVerticalScroll = function(self, v) self.vscroll = v end,
		GetVerticalScroll = function(self) return self.vscroll end,
		ClearAllPoints = function(self) self.points = {} end,
		SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
		GetPoint = function(self, i)
			local p = self.points[i]
			if p then
				return p[1], p[2], p[3], p[4], p[5]
			end
		end,
		SetText = function(self, s) self.text = s end,
		CreateFontString = function() return newFake("FontString") end,
		CreateTexture = function() return newFake("Texture") end,
	}
	return setmetatable(f, {
		__index = function(_, name)
			return methods[name] or function(self, ...) self.calls[name] = { ... } end
		end,
	})
end

-- Fake button pool: records placement, paint and dimming; placeholders as plain tables.
local function fakeButtons()
	local B = { created = true, buttons = {}, placeholders = {}, released = 0 }
	function B.EnsureCapacity(bag, n)
		B.buttons[bag] = B.buttons[bag] or {}
		for slot = #B.buttons[bag] + 1, n do
			local b = newFake("ItemButton")
			b.bag, b.slot, b.placed = bag, slot, 0
			B.buttons[bag][slot] = b
		end
	end
	function B.Count(bag) return #(B.buttons[bag] or {}) end
	function B.Get(bag, slot) return B.buttons[bag] and B.buttons[bag][slot] end
	function B.Place(button, x, y)
		button.x, button.y = x, y
		button.placed = button.placed + 1
	end
	function B.Paint(button, info) button.itemID = info and info.itemID or nil end
	function B.KindOf(bag) return bag <= 5 and "bags" or "bank" end
	function B.SetParentFor() end
	function B.SetDimmed(button, d) button.dimmed = d end
	function B.AcquirePlaceholder(_, icon, _, x, y)
		local p = { icon = icon, x = x, y = y }
		B.placeholders[#B.placeholders + 1] = p
		return p
	end
	function B.ReleasePlaceholders()
		B.placeholders = {}
		B.released = B.released + 1
	end
	return B
end

describe("BagsWindow category view", function()
	local SB, A, W, B
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- backpack 16 slots: potion, flask, BoE ring, soulbound helm, keystone, junk
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
	end)

	local function headers()
		local out = {}
		for i, h in ipairs(SB.SectionHeaders.inUse) do
			out[i] = h.text.text
		end
		return out
	end

	local function header(id)
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId == id then
				return h
			end
		end
	end

	local function at(bag, slot)
		local b = B.Get(bag, slot)
		return { b.x, b.y }
	end

	it("opens in the category view: sections in display order, New reserved on top, Free last", function()
		assert.truthy(W.Open())
		assert.same({ "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "- BoE gear (1)",
			"- Junk (1)", "- Free (10)" }, headers())
		-- New's header at y=-4 and its two reserved rows; Keystone's header at -108, its cell at -128 ...
		assert.same({ 4, -128 }, at(0, 5), "keystone: first cell under its header")
		assert.same({ 4, -191 }, at(0, 1), "potion: first cell of Consumables")
		assert.same({ 45, -191 }, at(0, 2), "flask: second cell of Consumables")
		assert.equal(16, #W.cells)
	end)

	it("shows every slot button exactly once, each at its own cell", function()
		W.Open()
		local seen = {}
		for slot = 1, 16 do
			local b = B.Get(0, slot)
			assert.truthy(b.shown, "slot " .. slot)
			local key = b.x .. "," .. b.y
			assert.is_nil(seen[key], "two buttons at " .. key)
			seen[key] = true
		end
	end)

	it("collapsing hides a section, re-stacks the rest, is saved per character, and expanding restores the cells", function()
		W.Open()
		local before = { at(0, 1), at(0, 3), at(0, 7) }
		header("c_consumables").scripts.OnClick(header("c_consumables"))
		assert.equal(true, SB.Config.UI().collapsed.bags.c_consumables)
		assert.falsy(B.Get(0, 1).shown)
		assert.equal("+ Consumables (2)", header("c_consumables").text.text)
		assert.equal(before[2][2] + 37, at(0, 3)[2], "Gear moved up by Consumables' row")
		header("c_consumables").scripts.OnClick(header("c_consumables"))
		assert.is_nil(SB.Config.UI().collapsed.bags.c_consumables)
		assert.same(before, { at(0, 1), at(0, 3), at(0, 7) })
	end)

	it("collapse state survives closing and reopening", function()
		W.Open()
		W.ToggleSection("c_gear")
		W.Close()
		W.Open()
		assert.equal("+ Gear (1)", header("c_gear").text.text)
		assert.falsy(B.Get(0, 4).shown)
	end)

	it("the header button switches to the grid and back without /reload, also in combat (AC3.1)", function()
		W.Open()
		A.combat = true
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("grid", SB.Config.Get("bags.view"))
		assert.equal(SB.L.VIEW_TO_SECTIONS, W.viewButton.text)
		assert.equal(SB.L.VIEW_GRID, W.frame.title.text)
		assert.same({ 4, -4 }, at(0, 1), "grid: physical order")
		assert.same({}, headers())
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("sections", SB.Config.Get("bags.view"))
		assert.same({ 4, -191 }, at(0, 1))
		assert.equal(7, #headers())
	end)

	it("a collapse waits while a button that would move is under the mouse", function()
		W.Open()
		local helm = B.Get(0, 4)
		helm.mouseOver = true
		W.ToggleSection("c_consumables")
		local y = helm.y
		assert.truthy(B.Get(0, 1).shown, "not applied yet")
		A.Advance(0.3)
		assert.equal(y, helm.y)
		helm.mouseOver = false
		A.Advance(0.3)
		assert.falsy(B.Get(0, 1).shown)
		assert.truthy(helm.y > y)
	end)

	it("closing forgets the layout and releases placeholders", function()
		W.Open()
		local released = B.released
		W.Close()
		assert.is_nil(W.state)
		assert.truthy(B.released > released)
	end)

	it("Ctrl+wheel scaling only resizes; it does not regroup", function()
		W.Open()
		IsControlKeyDown = function() return true end
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		assert.equal(1.05, SB.Config.Get("bags.scale"))
		assert.equal("open", W.stats.lastLayoutReason)
	end)
end)
```

Keep `spec/bagswindow_spec.lua` on the grid view and stop it leaking globals:

<!-- sbw2:edit T9 02-grid-spec-header spec/bagswindow_spec.lua -->
In `spec/bagswindow_spec.lua`, find:

```lua
-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown
local Loader = dofile("spec/helpers/loader.lua")
```

and replace it with:

```lua
-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown
-- The bags window's GRID view and window basics. The category view is covered by
-- spec/bagswindow_sections_spec.lua.
local Loader = dofile("spec/helpers/loader.lua")
```

<!-- sbw2:edit T9 03-grid-spec-setup spec/bagswindow_spec.lua -->
In `spec/bagswindow_spec.lua`, find:

```lua
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		fake = { pools = {}, changed = nil }
```

and replace it with:

```lua
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		SB.Config.Set("bags.view", "grid")
		fake = { pools = {}, changed = nil }
```

<!-- sbw2:edit T9 04-grid-spec-buttons spec/bagswindow_spec.lua -->
In `spec/bagswindow_spec.lua`, find:

```lua
			Place = function() end,
			Paint = function() end,
			KindOf = function() return "bags" end,
		}
```

and replace it with:

```lua
			Place = function() end,
			Paint = function() end,
			KindOf = function() return "bags" end,
			ReleasePlaceholders = function() end,
		}
		SB.SectionHeaders = { ReleaseAll = function() end }
```

<!-- sbw2:edit T9 05-grid-spec-aftereach spec/bagswindow_spec.lua -->
In `spec/bagswindow_spec.lua`, find:

```lua
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W = SB.BagsWindow
	end)
```

and replace it with:

```lua
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W = SB.BagsWindow
	end)

	after_each(function() -- do not leak WoW globals into other spec files
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
	end)
```

<!-- sbw2:edit T9 08-report-spec spec/report_spec.lua -->
In `spec/report_spec.lua`, find:

```lua
	it("Hash is stable, order-independent and changes with content", function()
```

and replace it with:

```lua
	it("shows the last bags layout time, for the spec 9 open budgets", function()
		SB.Checks.last = {}
		SB.BagsWindow = { stats = { lastLayoutMs = 12.34, lastLayoutReason = "open" } }
		assert.truthy(SB.Report.Build():find("\nLast bags layout: 12.3 ms (open)", 1, true))
	end)

	it("Hash is stable, order-independent and changes with content", function()
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua; luajit spec/runner.lua spec/bagswindow_spec.lua; luajit spec/runner.lua spec/report_spec.lua`
Expected: `1 passed, 7 failed`, `11 passed, 0 failed` (the grid tests keep passing), `5 passed, 1 failed`

- [ ] **Step 3: Strings and the report line**

<!-- sbw2:edit T9 01-locale SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.BAGS_TITLE = "SwagBag"
L.BAGS_SCALE = "SwagBag %d%%"
```

and replace it with:

```lua
L.BAGS_TITLE = "SwagBag"
L.BAGS_SCALE = "SwagBag %d%%"
L.VIEW_TO_GRID = "Grid"
L.VIEW_TO_SECTIONS = "Categories"
L.VIEW_GRID = "SwagBag - grid view"
L.VIEW_SECTIONS = "SwagBag - category view"
```

<!-- sbw2:edit T9 07-locale-report SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_CATEGORIES = "Categories: %d (%d edited)  Broken: %s"
```

and replace it with:

```lua
L.REPORT_CATEGORIES = "Categories: %d (%d edited)  Broken: %s"
L.REPORT_LAYOUT = "Last bags layout: %.1f ms (%s)"
```

<!-- sbw2:edit T9 06-report SwagBag/Core/Report.lua -->
In `SwagBag/Core/Report.lua`, find:

```lua
		lines[#lines + 1] = L.REPORT_CATEGORIES:format(total, edited, #broken > 0 and table.concat(broken, ", ") or L.REPORT_NONE)
	end
	return table.concat(lines, "\n")
```

and replace it with:

```lua
		lines[#lines + 1] = L.REPORT_CATEGORIES:format(total, edited, #broken > 0 and table.concat(broken, ", ") or L.REPORT_NONE)
	end
	local bags = SB.BagsWindow and SB.BagsWindow.stats
	if bags and bags.lastLayoutMs then -- spec 9: first open <= 25 ms, warm open <= 10 ms
		lines[#lines + 1] = L.REPORT_LAYOUT:format(bags.lastLayoutMs, tostring(bags.lastLayoutReason))
	end
	return table.concat(lines, "\n")
```

- [ ] **Step 4: Replace `SwagBag/UI/BagsWindow.lua` with**

<!-- sbw2:file T9 SwagBag/UI/BagsWindow.lua -->
```lua
-- SwagBag bags window (spec F1, F3). Two views, switched with the header button
-- without /reload, in or out of combat (AC3.1):
--   "sections" (default)  category sections from Engine/Layout.lua: New on top, Free
--                         at the bottom, collapsible headers remembered per character
--   "grid"                one grid in physical slot order (AC3.6)
-- Movable, Ctrl+wheel scale 50-200 %, remembers its position per character, closes on
-- Esc, scrolls with a clamped offset (spec 4.4), and stays hidden until laid out.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local W = {
	records = {}, -- [bag][slot] = item record (Items.Describe) for every slot in the view
	cells = {}, -- { {bag, slot, ...} } every slot in the view, shown or collapsed (search dims these)
	sizes = {}, -- [bag] = number of slots laid out
	stats = {},
	state = nil, -- sections view: Layout state while open (nil when closed or in grid view)
	pos = nil, -- sections view: last Layout.Position result
	placed = {}, -- [button] = "x,y" of its last SetPoint, so unchanged buttons are not touched
	size = { 100, 100 }, -- last content width, height
	SLOT = 37,
	GAP = 4,
	PAD = 4,
	HEADER = 58, -- title row + search row
	FOOTER = 6,
	SECTION_HEADER = 20,
	SECTION_GAP = 6,
	MAX_HEIGHT_FRACTION = 0.75,
	SCALE_STEP = 0.05,
	RETRY = 0.3, -- spec 4.2 rule 5: held-back moves retry 300 ms later
}
SB.BagsWindow = W

local frame = CreateFrame("Frame", "SwagBagBagsWindow", UIParent, "BackdropTemplate")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:Hide()
if frame.SetDontSavePosition then
	frame:SetDontSavePosition(true) -- SwagBag keeps its own saved position
end
W.frame = frame
table.insert(UISpecialFrames, "SwagBagBagsWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.BAGS_TITLE)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -W.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, W.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
W.scroll, W.child = scroll, child
SB.Buttons.SetParentFor("bags", child)

function W.ClampScroll()
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end

-- Esc, the X button and W.Close() all hide the frame. Spec 4.3 "window closes":
-- placeholders are released and the layout is forgotten; the next open lays out fully.
frame:SetScript("OnHide", Guard("bags.hide", function()
	W.state, W.pos = nil, nil
	SB.Buttons.ReleasePlaceholders()
	SB.Emit("SB_BAGS_CLOSED")
end, "bags"))

---------------------------------------------------------------------------
-- Title feedback, position and scale
---------------------------------------------------------------------------
local titleToken = 0

-- Show text in the title for 1.5 s (feedback for header buttons and scaling, P2).
function W.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("bags.flash", function()
		if token == titleToken then
			frame.title:SetText(L.BAGS_TITLE)
		end
	end, "bags"))
end

function W.RestorePosition()
	local p = SB.Config.UI().positions.bags
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 100)
	end
end

local function savePosition()
	local point, _, relPoint, x, y = frame:GetPoint(1)
	SB.Config.UI().positions.bags = { point, relPoint, x, y }
end

frame:SetScript("OnDragStart", Guard("bags.dragStart", function()
	frame:StartMoving()
end, "bags"))
frame:SetScript("OnDragStop", Guard("bags.dragStop", function()
	frame:StopMovingOrSizing()
	savePosition()
end, "bags"))

-- Fit the window around content of width x height (scroll when taller than 75 % of the screen).
local function sizeFrame(width, height)
	W.size = { width, height }
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * W.MAX_HEIGHT_FRACTION / frame:GetScale()
	local viewHeight = math.min(height, maxHeight - W.HEADER - W.FOOTER)
	frame:SetSize(width + 8, viewHeight + W.HEADER + W.FOOTER)
	W.ClampScroll()
end

-- Scaling only resizes the window; nothing is regrouped.
function W.SetScale(scale)
	scale = SB.GridLayout.ClampScale(scale)
	SB.Config.Set("bags.scale", scale)
	frame:SetScale(scale)
	W.Flash(L.BAGS_SCALE:format(math.floor(scale * 100 + 0.5)))
	if frame:IsShown() then
		sizeFrame(W.size[1], W.size[2])
	end
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("bags.wheel", function(_, delta)
	if IsControlKeyDown() then
		W.SetScale(SB.Config.Get("bags.scale") + delta * W.SCALE_STEP)
		return
	end
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (W.SLOT + W.GAP) * 3)
	W.ClampScroll()
end, "bags"))

---------------------------------------------------------------------------
-- Views and collapse state
---------------------------------------------------------------------------
function W.View()
	return SB.Config.Get("bags.view") == "grid" and "grid" or "sections"
end

-- [sectionId] = true for collapsed sections, saved per character (AC3.2).
function W.Collapsed()
	local ui = SB.Config.UI()
	ui.collapsed = type(ui.collapsed) == "table" and ui.collapsed or {}
	ui.collapsed.bags = type(ui.collapsed.bags) == "table" and ui.collapsed.bags or {}
	return ui.collapsed.bags
end

local function columns()
	return SB.Config.Get("bags.columns")
end

local function positionOpts()
	return { columns = columns(), size = W.SLOT, gap = W.GAP, padding = W.PAD, header = W.SECTION_HEADER,
		sectionGap = W.SECTION_GAP }
end

local function titleButton(text, label, onClick)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(72, 18)
	b:SetText(text)
	b:SetScript("OnClick", Guard(label, onClick, "bags"))
	return b
end

W.viewButton = titleButton(W.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID, "bags.viewButton", function()
	W.ToggleView()
end)
W.viewButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function bagList()
	local A, list = SB.Adapter, {}
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		local n = A.NumSlots(bag)
		if n > 0 then
			list[#list + 1] = { bag = bag, size = n }
		end
	end
	return list
end

local function describe(bag, slot)
	W.records[bag] = W.records[bag] or {}
	local record = SB.Items.Describe(bag, slot)
	W.records[bag][slot] = record
	return record
end

local function place(button, x, y)
	local at = x .. "," .. y
	if W.placed[button] ~= at then
		SB.Buttons.Place(button, x, y)
		W.placed[button] = at
	end
end

local function layoutGrid(bags)
	local A, B = SB.Adapter, SB.Buttons
	local g = SB.GridLayout.Compute(bags, { columns = columns(), size = W.SLOT, gap = W.GAP, padding = W.PAD })
	W.cells = g.cells
	for _, c in ipairs(g.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			place(button, c.x, c.y)
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			describe(c.bag, c.slot)
			button:Show()
		end
	end
	return g.width, g.height
end

-- Put buttons, placeholders and headers where W.pos says. Returns width, height.
local function render()
	local B, H, pos = SB.Buttons, SB.SectionHeaders, W.pos
	W.cells = {}
	for _, c in ipairs(pos.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			if c.shown then
				place(button, c.x, c.y)
				button:Show()
			else
				button:Hide()
			end
			W.cells[#W.cells + 1] = c
		end
	end
	B.ReleasePlaceholders()
	for _, p in ipairs(pos.placeholders) do
		if p.shown then
			B.AcquirePlaceholder(child, p.icon, W.SLOT, p.x, p.y)
		end
	end
	H.ReleaseAll()
	for _, h in ipairs(pos.headers) do
		H.Acquire(child, h.id, H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow), W.PAD, h.y,
			pos.width - 2 * W.PAD)
	end
	return pos.width, pos.height
end
W.Render = render

local function layoutSections(bags)
	local A, B = SB.Adapter, SB.Buttons
	local slots = {}
	for _, b in ipairs(bags) do
		for slot = 1, b.size do
			local button = B.Get(b.bag, slot)
			if button then -- nil only while combat delays pool growth (spec 4.3: slot invisible)
				B.Paint(button, A.GetSlot(b.bag, slot))
				slots[#slots + 1] = { bag = b.bag, slot = slot, record = describe(b.bag, slot) }
			end
		end
	end
	W.state = SB.Layout.Build(slots, SB.Categorizer.Assign, SB.Categories.SectionOrder(),
		{ columns = columns(), newRows = SB.Config.Get("bags.newRows") })
	W.pos = SB.Layout.Position(W.state, positionOpts(), W.Collapsed())
	return render()
end

-- Full layout: every item to its section (or the physical grid). Called on open and by
-- explicit actions only, never by bag updates in the sections view.
function W.Layout(reason)
	local A, B = SB.Adapter, SB.Buttons
	local t0 = A.ProfileMs()
	local bags = bagList()
	W.sizes = {}
	for _, b in ipairs(bags) do
		W.sizes[b.bag] = b.size
		if B.Count(b.bag) < b.size then
			B.EnsureCapacity(b.bag, b.size)
		end
	end
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		for slot = (W.sizes[bag] or 0) + 1, B.Count(bag) do
			B.Get(bag, slot):Hide()
		end
	end
	W.records, W.state, W.pos = {}, nil, nil
	B.ReleasePlaceholders()
	SB.SectionHeaders.ReleaseAll()
	local width, height
	if W.View() == "grid" then
		width, height = layoutGrid(bags)
	else
		width, height = layoutSections(bags)
	end
	sizeFrame(width, height)
	W.stats.lastLayoutMs = A.ProfileMs() - t0
	W.stats.lastLayoutReason = reason
	SB.Emit("SB_BAGS_LAYOUT", reason)
end

local function buttonBusy(bag, slot)
	local button = SB.Buttons.Get(bag, slot)
	return button ~= nil and button:IsShown() and button:IsMouseOver()
end
W.ButtonBusy = buttonBusy

-- Spec 4.2 rule 5 for a re-stack: wait while an item is on the cursor or one of the
-- buttons that would move is under the mouse.
local function anyBusy(keys)
	if SB.Adapter.CursorItem() then
		return true
	end
	for _, key in ipairs(keys) do
		if buttonBusy(math.floor(key / 1000), key % 1000) then
			return true
		end
	end
	return false
end

-- Collapse/expand re-stack (spec 6.4): same cells, new section offsets.
function W.Restack()
	if not W.state then
		return true
	end
	local pos = SB.Layout.Position(W.state, positionOpts(), W.Collapsed())
	if anyBusy(SB.Layout.Moves(W.pos, pos)) then
		SB.Debounce("bags.restack", W.RETRY, W.Restack, "bags")
		return false
	end
	W.pos = pos
	sizeFrame(render())
	SB.Emit("SB_BAGS_UPDATED")
	return true
end

function W.ToggleSection(id)
	local set = W.Collapsed()
	set[id] = not set[id] or nil
	W.Restack()
end

-- A full layout moves many buttons, so it waits while an item is on the cursor or the
-- mouse is over the items (spec 4.3: Reflow/sort "guarded by rule 5"), retrying every 300 ms.
function W.RequestLayout(reason)
	if not frame:IsShown() then
		return false
	end
	if SB.Adapter.CursorItem() or scroll:IsMouseOver() then
		SB.Debounce("bags.layout", W.RETRY, function()
			W.RequestLayout(reason)
		end, "bags")
		return false
	end
	W.Layout(reason)
	return true
end

function W.SetView(view)
	SB.Config.Set("bags.view", view)
	W.viewButton:SetText(view == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	W.Flash(view == "grid" and L.VIEW_GRID or L.VIEW_SECTIONS)
	W.RequestLayout("view")
end

function W.ToggleView()
	W.SetView(W.View() == "grid" and "sections" or "grid")
end

SB.SectionHeaders.onClick = function(id)
	W.ToggleSection(id)
end

-- fn(button, record-or-nil, bag, slot) for every slot in the view (collapsed ones too).
function W.ForEachSlot(fn)
	local B = SB.Buttons
	for _, c in ipairs(W.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			fn(button, W.records[c.bag] and W.records[c.bag][c.slot], c.bag, c.slot)
		end
	end
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
function W.IsOpen()
	return frame:IsShown()
end

function W.Open()
	if SB.SafeMode.IsOn("bags") or not SB.Buttons.created then
		return false
	end
	if frame:IsShown() then
		return true
	end
	W.RestorePosition()
	frame:SetScale(SB.GridLayout.ClampScale(SB.Config.Get("bags.scale")))
	frame:Show()
	W.Layout("open")
	return true
end

function W.Close()
	frame:Hide()
end

function W.Toggle()
	if frame:IsShown() then
		W.Close()
	else
		W.Open()
	end
end

---------------------------------------------------------------------------
-- Live updates while open
---------------------------------------------------------------------------
SB.Inventory.OnChanged(Guard("bags.inventory", function(mask, changes)
	if not frame:IsShown() then
		return
	end
	local Inv, B, A = SB.Inventory, SB.Buttons, SB.Adapter
	if Inv.Has(mask, Inv.R.SIZE) then
		W.Layout("size")
		return
	end
	if Inv.Has(mask, Inv.R.COOLDOWN) then
		W.ForEachSlot(function(button, record)
			if record and button.UpdateCooldown then
				pcall(button.UpdateCooldown, button, record.icon)
			end
		end)
	end
	local touched = false
	for _, c in ipairs(changes) do
		local button = B.Get(c.bag, c.slot)
		if B.KindOf(c.bag) == "bags" and button and button:IsShown() then
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			describe(c.bag, c.slot)
			touched = true
		end
	end
	if touched then
		SB.Emit("SB_BAGS_UPDATED")
	end
end, "bags"))
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua; luajit spec/runner.lua spec/bagswindow_spec.lua; luajit spec/runner.lua spec/report_spec.lua`
Expected: `8 passed, 0 failed`, `11 passed, 0 failed`, `6 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (32 files)`, `341 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 7: Commit**

```bash
git add SwagBag/UI/BagsWindow.lua SwagBag/Locale/enUS.lua SwagBag/Core/Report.lua spec/bagswindow_sections_spec.lua \
  spec/bagswindow_spec.lua spec/report_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 9: category view with headers, saved collapse state and grid toggle" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 10: Live updates while open: placeholders, New, Free, hover guard (spec §4.3) and in-game session E1

The inventory listener now follows spec §4.3 in the category view:

- **Repaint in place.** Count, lock, cooldown and "data loaded" changes only repaint. A loaded item stays in New until the next open.
- **Moves.** An emptied slot or a different item goes through `Layout.Apply`: a placeholder in the old cell, and the button goes to Free or New.
- **Bag size.** A bag that grows adds its slots to the end of Free. A bag taken off leaves holes.
- **Hover guard.** A button under the mouse, or every button while an item is on the cursor, waits and is retried every 300 ms (`SB.Debounce`, no `OnUpdate`).
- **Grid view.** It keeps week 1's behaviour: repaint in place, and a full layout on a size change.
- **Search refresh.** On `BAG_UPDATE_COOLDOWN` the cooldown spirals repaint as before. Only while the active search uses `cooldown`/`usable` are those fields re-read and the search re-applied (Task 5).

**Files:**
- Modify: `SwagBag/UI/BagsWindow.lua` (the live-update section)
- Test: `spec/bagswindow_sections_spec.lua`

**Interfaces:**
- Consumes: `SB.Layout.Apply/Position` (Tasks 6–7), `SB.Inventory.OnChanged/R/Has` (on `main`), `SB.Search.NeedsVolatileRefresh` and `SB.Items.RefreshVolatile` (Task 5), `W.Collapsed/Render/ButtonBusy/sizes/records` (Task 9).
- Produces: `SB.BagsWindow.ApplyChanges(changes) -> result | nil`. Retries are scheduled under the debounce key `"bags.retry"`. `SB_BAGS_UPDATED` is emitted after any repaint or move, so the search box re-dims.

- [ ] **Step 1: Write the failing tests** (append to `spec/bagswindow_sections_spec.lua`)

<!-- sbw2:edit T10 10-sections-spec spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
		assert.equal(1.05, SB.Config.Get("bags.scale"))
		assert.equal("open", W.stats.lastLayoutReason)
	end)
end)
```

and replace it with:

```lua
		assert.equal(1.05, SB.Config.Get("bags.scale"))
		assert.equal("open", W.stats.lastLayoutReason)
	end)

	-- Change the mock bags, then deliver the events the client would send.
	local function bagUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag or 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function placedCounts()
		local out = {}
		for slot = 1, 16 do
			out[slot] = B.Get(0, slot).placed
		end
		return out
	end

	it("using up an item leaves a placeholder with its icon; its button goes to Free; nothing else moves", function()
		W.Open()
		local potionAt, counts = at(0, 1), placedCounts()
		A.Clear(0, 1)
		bagUpdate()
		assert.equal(1, #B.placeholders)
		assert.same({ Fixtures.HEALING_POTION, potionAt[1], potionAt[2] },
			{ B.placeholders[1].icon, B.placeholders[1].x, B.placeholders[1].y })
		assert.equal(counts[1] + 1, B.Get(0, 1).placed, "the emptied button moved once")
		for slot = 2, 16 do
			assert.equal(counts[slot], B.Get(0, slot).placed, "slot " .. slot .. " did not move")
		end
		assert.equal("- Free (11)", header("free").text.text)
		assert.truthy(W.state.needsReflow)
	end)

	it("a drag to an empty slot and a stack split in one update: one placeholder, both show in New (Review Focus 1)",
		function()
			W.Open()
			local counts = placedCounts()
			local ringAt = at(0, 3)
			A.Clear(0, 3) -- the ring is dragged ...
			A.Put(0, 7, Fixtures.BOE_RING, 1) -- ... to an empty slot
			A.Put(0, 1, Fixtures.HEALING_POTION, 3) -- two potions are split off ...
			A.Put(0, 8, Fixtures.HEALING_POTION, 2) -- ... into another empty slot
			bagUpdate()
			assert.equal(1, #B.placeholders)
			assert.same(ringAt, { B.placeholders[1].x, B.placeholders[1].y })
			assert.same({ 4, -24 }, at(0, 7), "the ring shows first in New")
			assert.same({ 45, -24 }, at(0, 8), "the split stack second")
			for _, slot in ipairs({ 1, 2, 4, 5, 6, 9, 10 }) do
				assert.equal(counts[slot], B.Get(0, slot).placed, "slot " .. slot .. " did not move")
			end
		end)

	it("a looted item goes to New; New's header counts it", function()
		W.Open()
		A.Put(0, 10, Fixtures.HERB, 20)
		bagUpdate()
		assert.same({ 4, -24 }, at(0, 10), "first cell of New")
		assert.equal("- New (1)", header("new").text.text)
		assert.equal(0, #B.placeholders, "it came from Free: no placeholder")
	end)

	it("a stack count change only repaints", function()
		W.Open()
		local counts = placedCounts()
		A.Put(0, 1, Fixtures.HEALING_POTION, 2)
		bagUpdate()
		assert.same(counts, placedCounts())
		assert.equal(0, #B.placeholders)
	end)

	it("a button under the mouse does not move; it moves 300 ms after the mouse leaves", function()
		W.Open()
		local potion = B.Get(0, 1)
		local before = at(0, 1)
		potion.mouseOver = true
		A.Clear(0, 1)
		bagUpdate()
		assert.same(before, at(0, 1))
		A.Advance(0.3)
		assert.same(before, at(0, 1), "still under the mouse")
		potion.mouseOver = false
		A.Advance(0.3)
		assert.truthy(at(0, 1)[2] < before[2], "moved down to Free")
		assert.equal(1, #B.placeholders)
	end)

	it("an item on the cursor holds every move until it is put down", function()
		W.Open()
		A.cursor = { itemID = Fixtures.FLASK }
		local before = at(0, 1)
		A.Clear(0, 1)
		bagUpdate()
		assert.same(before, at(0, 1))
		A.cursor = nil
		A.Advance(0.3)
		assert.truthy(at(0, 1)[2] < before[2])
	end)

	it("closing while a move is held back under the mouse is safe; the next open is clean (Review Focus 3)", function()
		W.Open()
		B.Get(0, 1).mouseOver = true
		A.Clear(0, 1)
		bagUpdate()
		W.Close()
		B.Get(0, 1).mouseOver = false
		A.Advance(1)
		assert.equal(0, #B.placeholders)
		assert.equal(0, #SB.ErrorTrap.Recent())
		W.Open()
		assert.equal("- Consumables (1)", header("c_consumables").text.text)
	end)

	it("an item whose data loads stays in New until the next open, then joins its section", function()
		W.Open()
		A.Put(0, 10, Fixtures.UNLOADED, 1)
		bagUpdate()
		assert.same({ 4, -24 }, at(0, 10))
		A.items[Fixtures.UNLOADED] = { name = "Robe", classID = A.ITEM_CLASS.Armor, subclassID = 0, quality = 3,
			equipLoc = "INVTYPE_CHEST", ilvl = 280, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		assert.same({ 4, -24 }, at(0, 10), "loaded: still in New while open")
		W.Close()
		W.Open()
		assert.equal("- BoE gear (2)", header("c_boe").text.text)
	end)

	it("closing after changes releases the placeholders; reopening regroups everything", function()
		W.Open()
		A.Clear(0, 1)
		bagUpdate()
		assert.equal(1, #B.placeholders)
		W.Close()
		assert.equal(0, #B.placeholders)
		W.Open()
		assert.equal(0, #B.placeholders)
		assert.equal("- Consumables (1)", header("c_consumables").text.text)
		assert.falsy(W.state.needsReflow)
	end)

	it("a cooldown search stays correct: cooldown events refresh only while the search uses cooldown", function()
		W.Open()
		local updated = 0
		SB.On("SB_BAGS_UPDATED", function() updated = updated + 1 end)
		SB.Search.SetText("potion")
		A.slots[0][1].onCooldown = true
		SB.eventFrame:Fire("BAG_UPDATE_COOLDOWN")
		assert.equal(false, W.records[0][1].onCooldown, "no refresh for a search without cooldown")
		assert.equal(0, updated)
		SB.Search.SetText("cooldown")
		SB.eventFrame:Fire("BAG_UPDATE_COOLDOWN")
		assert.equal(true, W.records[0][1].onCooldown)
		assert.equal(1, updated)
	end)

	it("a new item matches the `new` search as soon as it arrives", function()
		W.Open()
		A.Put(0, 10, Fixtures.HERB, 20)
		bagUpdate()
		assert.equal(true, SB.Query.Eval(SB.Query.Compile("new"), W.records[0][10]))
	end)

	it("a bag equipped while open adds its slots at the end of Free", function()
		W.Open()
		local counts = placedCounts()
		A.SetBagSize(1, 4)
		bagUpdate(1)
		assert.equal("- Free (14)", header("free").text.text)
		assert.truthy(B.Get(1, 4).shown)
		assert.same(counts, placedCounts(), "nothing in the backpack moved")
	end)

	it("the grid view only repaints: no placeholders, nothing moves", function()
		SB.Config.Set("bags.view", "grid")
		W.Open()
		local counts = placedCounts()
		A.Clear(0, 1)
		bagUpdate()
		assert.equal(0, #B.placeholders)
		assert.same(counts, placedCounts())
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua`
Expected: `13 passed, 8 failed`. Four of the new tests already pass on Task 9's repaint-in-place code: the count repaint, the `new` search, the bag-equipped case (a full re-layout) and the grid view. They pin behaviour that must not regress.

- [ ] **Step 3: Replace the live-update section of `SwagBag/UI/BagsWindow.lua`**

<!-- sbw2:edit T10 01-bagswindow-live SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
---------------------------------------------------------------------------
-- Live updates while open
---------------------------------------------------------------------------
SB.Inventory.OnChanged(Guard("bags.inventory", function(mask, changes)
	if not frame:IsShown() then
		return
	end
	local Inv, B, A = SB.Inventory, SB.Buttons, SB.Adapter
	if Inv.Has(mask, Inv.R.SIZE) then
		W.Layout("size")
		return
	end
	if Inv.Has(mask, Inv.R.COOLDOWN) then
		W.ForEachSlot(function(button, record)
			if record and button.UpdateCooldown then
				pcall(button.UpdateCooldown, button, record.icon)
			end
		end)
	end
	local touched = false
	for _, c in ipairs(changes) do
		local button = B.Get(c.bag, c.slot)
		if B.KindOf(c.bag) == "bags" and button and button:IsShown() then
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			describe(c.bag, c.slot)
			touched = true
		end
	end
	if touched then
		SB.Emit("SB_BAGS_UPDATED")
	end
end, "bags"))
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- Live updates while open (spec 4.3)
--   grid view:     repaint in place; a bag that changes size lays the grid out again
--   sections view: count, lock, cooldown and loaded data repaint in place; an emptied
--                  slot or a different item goes through Layout.Apply (placeholder, New,
--                  Free); a bag that grows or shrinks adds or removes Free slots. A button
--                  under the mouse, or every button while an item is on the cursor, waits
--                  and retries 300 ms later (spec 4.2 rule 5). No OnUpdate anywhere.
---------------------------------------------------------------------------
-- Apply transitions to the open sections layout and redraw. Returns Layout.Apply's result.
function W.ApplyChanges(changes)
	local st = W.state
	if not st then
		return nil
	end
	local cursor = SB.Adapter.CursorItem() ~= nil
	local result = SB.Layout.Apply(st, changes, function(bag, slot)
		return cursor or buttonBusy(bag, slot)
	end, W.Collapsed())
	if #result.moved > 0 then
		W.pos = SB.Layout.Position(st, positionOpts(), W.Collapsed())
		sizeFrame(render())
	end
	if result.deferred > 0 then
		SB.Debounce("bags.retry", W.RETRY, function()
			W.ApplyChanges({})
			SB.Emit("SB_BAGS_UPDATED")
		end, "bags")
	end
	return result
end

-- Slots added or removed since the last layout (a bag was equipped or taken off).
local function sizeChanges()
	local A, B, out = SB.Adapter, SB.Buttons, {}
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		local old, new = W.sizes[bag] or 0, A.NumSlots(bag)
		if new > B.Count(bag) then
			B.EnsureCapacity(bag, new) -- queued until combat ends; the slot stays invisible meanwhile
		end
		for slot = old + 1, new do
			local button = B.Get(bag, slot)
			if button then
				B.Paint(button, A.GetSlot(bag, slot))
				describe(bag, slot)
				out[#out + 1] = { bag = bag, slot = slot, kind = "added" }
			end
		end
		for slot = new + 1, old do
			local button = B.Get(bag, slot)
			if button then
				button:Hide()
			end
			if W.records[bag] then
				W.records[bag][slot] = nil
			end
			out[#out + 1] = { bag = bag, slot = slot, kind = "removed" }
		end
		W.sizes[bag] = new
	end
	return out
end

SB.Inventory.OnChanged(Guard("bags.inventory", function(mask, changes)
	if not frame:IsShown() then
		return
	end
	local Inv, B, A = SB.Inventory, SB.Buttons, SB.Adapter
	if not W.state and Inv.Has(mask, Inv.R.SIZE) then
		W.Layout("size") -- grid view: the grid is the physical order
		return
	end
	local touched = false
	if Inv.Has(mask, Inv.R.COOLDOWN) then
		W.ForEachSlot(function(button, record)
			if record and button.UpdateCooldown then
				pcall(button.UpdateCooldown, button, record.icon)
			end
		end)
		-- A cooldown/usable search must not go stale; never a rescan otherwise (spec 9).
		if SB.Search and SB.Search.NeedsVolatileRefresh() then
			W.ForEachSlot(function(_, record)
				if record then
					SB.Items.RefreshVolatile(record)
				end
			end)
			touched = true
		end
	end
	local moves = {}
	if W.state and Inv.Has(mask, Inv.R.SIZE) then
		moves = sizeChanges()
		touched = touched or #moves > 0
	end
	for _, c in ipairs(changes) do
		local button = B.Get(c.bag, c.slot)
		if B.KindOf(c.bag) == "bags" and button and c.slot <= (W.sizes[c.bag] or 0) then
			local old = W.records[c.bag] and W.records[c.bag][c.slot]
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			local record = describe(c.bag, c.slot)
			touched = true
			if W.state and Inv.Has(c.reasons, Inv.R.ITEM) then
				moves[#moves + 1] = { bag = c.bag, slot = c.slot, kind = record and "arrived" or "left",
					icon = old and old.icon }
			end
		end
	end
	if W.state and (#moves > 0 or #W.state.deferred > 0) then
		W.ApplyChanges(moves)
	end
	if touched then
		SB.Emit("SB_BAGS_UPDATED")
	end
end, "bags"))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua`
Expected: `21 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (32 files)`, `354 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add SwagBag/UI/BagsWindow.lua spec/bagswindow_sections_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 10: spec 4.3 live updates - placeholders, New and Free, nothing moves under the cursor" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 7: In-game session E1: category view, collapse, toggle, V4 and V12 (the user does this; about 25 minutes)**

Give the user this checklist exactly. Have with you: two small stacks (2 or 3 each) of food or drink, a few gray junk items, a stack of something you can split (herbs, cloth), at least two empty bag slots, your Mythic keystone, and a training dummy and a vendor nearby (a capital city). Use the food or drink out of combat. Eating or drinking makes your character sit down; that is fine, but stand up again afterwards.

Throughout: whenever a step says an item "moves" or "goes away", move the mouse off that slot first. SwagBag deliberately waits while the mouse is on a slot or an item is on your cursor.

1. **Quit the game completely and start it again.** New files were added this week, and `/reload` does not load new files. Log in. Chat shows `SwagBag: v0.2.0 loaded…`.
2. Press **B**. The window shows sections with headers such as `- Keystone & Crests (1)`, `- Consumables (…)`, `- Gear (…)`, `- Junk (…)`, `- Other (…)` and, at the bottom, `- Free (…)` with your empty slots. At the very top is `- New (0)` with an empty area two rows tall.
3. **Category check.** Look through every section and compare with this list:
   - Keystone & Crests: your keystone.
   - Consumables: potions, flasks, food, drinks.
   - Gear: equipment that is bound to you.
   - BoE gear: equipment you could sell.
   - Herbs, Ore, Leather & Cloth, Enchanting, Cooking: those materials.
   - Trade Goods: other crafting materials.
   - Quest: quest items.
   - Pets & Mounts & Toys: caged pets, mounts and toys.
   - Teleports & Tools: your Hearthstone and profession tools.
   - Junk: gray items.
   - Other: anything else.

   Write down every item that looks wrong: the item name and the section it is in. Also write down what is in **Other**.
4. Click the **Consumables** header. Its items disappear, the header now starts with `+`, and the sections below move up.
5. Click it again. The items come back in exactly the same places.
6. Click the **Junk** header to collapse it.
7. Press **B** to close the window, then press **B** again to open it. Junk is still collapsed.
8. Type `/reload`, then press **B**. Junk is **still** collapsed (saved for this character).
9. Click the **Junk** header to expand it again.
10. Click the **Grid** button at the top right. All items show in one grid in bag order. The button now reads **Categories**, and the title briefly says `SwagBag - grid view`.
11. Click **Categories**. The sections come back.
12. Attack a training dummy.
13. While in combat, click **Grid**. The grid shows, with no red error.
14. Still in combat, click **Categories**. The sections come back, with no red error.
15. Stop attacking and leave combat.
16. **V12, using up a stack:** right-click one of your small food or drink stacks until it is gone. Move the mouse off the slot after the last use. Within about half a second a faded gray copy of its icon stays where it was, and one more empty slot appears at the end of **Free**. Nothing else in the window moves.
17. **V4:** right-click the faded icon. Only a tooltip appears: "This item moved or was used - items regroup when you close the bag." Nothing is used and nothing is picked up.
18. Left-click the faded icon. Same: only the tooltip.
19. **V12, looting or buying:** buy one cheap item from the vendor that you do **not** already have (an item you already have would stack onto its existing stack and not appear in New). Move the mouse off it. Within about half a second the item appears in the **New** section at the top, and New's header shows `(1)`. Nothing else moves.
20. **V12, vendoring:** with the vendor open, right-click a gray junk item to sell it. Move the mouse off the slot. Within about half a second a faded copy stays where it was. Nothing else moves.
21. **V12, splitting:** Shift-click a stack, choose 1, and click **Okay**. The 1 item sits on your cursor. Click an empty slot in **Free** to put it down, then move the mouse off it. Within about half a second it shows up in **New**. The original stack stays where it was.
22. **V12, dragging:** drag an item from a category section (not from New or Free) onto an empty slot in **Free**, then move the mouse off it. Within about half a second a faded copy stays where the item was, and the item shows up in **New**.
23. **Hover guard:** right-click the last item of your other small food or drink stack and keep the mouse **still** on it afterwards. Its slot does not jump away while the mouse is on it. Move the mouse off. Within about half a second the empty slot moves to Free and a faded copy remains.
24. **Keystone:** if you can finish a key (or get a changed keystone), check afterwards that your keystone is still in its **Keystone & Crests** section, even though its level changed. It regroups only the next time you open the bag. If you cannot do a key now, say so and skip this step.
25. Press **B** to close the window, then press **B** again to open it. All faded icons are gone, New is empty, and the items you bought, split or dragged are now in their real sections.
26. If the window scrolls: scroll to the bottom, then collapse two big sections. The view never stays scrolled past the end.
27. Type `/swagbag report`, press Ctrl+C, and paste it into Claude Code together with your notes from step 3. Claude checks:
    - no new errors and `Blocked actions: none`;
    - `Categories: 18 (0 edited)  Broken: none`;
    - `Last bags layout: … ms (open)` at or below 25 ms.

Pass: steps 2 and 4-26 behave as described, no item was ever used or picked up by mistake, and nothing moved while the mouse was on it.

---

### Task 11: Drag onto a section header (AC4.3), Sort and Reflow buttons, and in-game session E2

- **Drag onto a header** (AC4.3). Dropping an item on a section header, or clicking a header while an item is on the cursor, adds it to that section's manual list (`Categories.AddToList`, stored as a diff). The item goes back to its slot (`ClearCursor`), and chat confirms: "Added Healing Potion to Consumables. It moves there when you reopen your bags or press Reflow." Nothing moves while the window is open (P5). New and Free refuse with an explanation.
- **Sort** (AC2.7, spec §5.5). The button calls Blizzard's sort through the Adapter. Bag updates during the sort follow §4.3 as usual. 0.3 s after the last one, the window regroups with a guarded full layout (D7). In combat the sort waits for combat to end (D1).
- **Reflow** (spec §4.3). The button regroups now, or as soon as the mouse leaves the items.

**Files:**
- Modify: `SwagBag/UI/BagsWindow.lua`, `SwagBag/Locale/enUS.lua`
- Test: `spec/bagswindow_sections_spec.lua`

**Interfaces:**
- Consumes: `SB.Categories.AddToList/Name/NEW/FREE` (Task 3), `SB.Adapter.CursorItem/ClearCursor/SortBags/GetItemInfo/InCombat` (Task 8 and `main`), `SB.OutOfCombat` (on `main`), `W.RequestLayout/Flash` (Task 9).
- Produces:
  - `SB.BagsWindow.DropOnSection(sectionId) -> boolean`, `Sort() -> boolean`, `Reflow(reason) -> boolean`.
  - Fields `sortPending` and `SORT_SETTLE = 0.3`, and the buttons `sortButton` and `reflowButton`.
  - `SB.SectionHeaders.onClick` drops when an item is on the cursor and otherwise collapses. `onDrop = DropOnSection`.

- [ ] **Step 1: Write the failing tests** (in `spec/bagswindow_sections_spec.lua`, before the grid-view test)

<!-- sbw2:edit T11 10-spec spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
	it("the grid view only repaints: no placeholders, nothing moves", function()
```

and replace it with:

```lua
	it("dropping an item on a header adds it to that section, confirms, and moves it on Reflow (AC4.3)", function()
		A.Put(0, 10, Fixtures.HERB, 20)
		W.Open()
		local counts = placedCounts()
		A.cursor = { itemID = Fixtures.HERB, link = "|cffffffff|Hitem:210796|h[Mycobloom]|h|r" }
		header("c_consumables").scripts.OnReceiveDrag(header("c_consumables"))
		assert.same({ "Added Mycobloom to Consumables. It moves there when you reopen your bags or press Reflow." },
			A.Lines())
		assert.equal(1, A.cleared, "the item went back to its slot")
		assert.same({ itemList = { include = { [Fixtures.HERB] = true } } }, SB.Config.db.userEdits.c_consumables)
		assert.same(counts, placedCounts(), "nothing moves while the window is open")
		W.reflowButton.scripts.OnClick(W.reflowButton)
		assert.equal("- Consumables (3)", header("c_consumables").text.text)
		assert.is_nil(header("c_herbs"))
	end)

	it("clicking a header while holding an item drops it instead of collapsing", function()
		W.Open()
		A.cursor = { itemID = Fixtures.JUNK }
		header("c_gear").scripts.OnClick(header("c_gear"))
		assert.is_nil(SB.Config.UI().collapsed.bags.c_gear)
		assert.truthy(SB.Categories.Get("c_gear").itemList.include[Fixtures.JUNK])
	end)

	it("New and Free refuse drops and say why", function()
		W.Open()
		A.cursor = { itemID = Fixtures.JUNK }
		header("new").scripts.OnReceiveDrag(header("new"))
		assert.same({ "Items can't be added to New. Drop them on a category header." }, A.Lines())
		assert.same({}, SB.Config.db.userEdits)
		assert.is_nil(A.cursor)
	end)

	it("the sort button sorts, then regroups once the bags settle", function()
		W.Open()
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(1, A.sorts)
		assert.equal(SB.L.SORT_STARTED, W.frame.title.text)
		A.Put(0, 1, Fixtures.JUNK, 3) -- the sort swaps the potion and the junk
		A.Put(0, 6, Fixtures.HEALING_POTION, 5)
		bagUpdate()
		assert.equal(2, #B.placeholders, "while sorting, spec 4.3 holds as usual")
		A.Advance(0.3)
		assert.equal("sort", W.stats.lastLayoutReason)
		assert.equal(0, #B.placeholders)
		assert.same({ 45, -191 }, at(0, 6), "the potion is Consumables' second item now")
	end)

	it("sorting waits until combat ends", function()
		W.Open()
		A.combat = true
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(0, A.sorts)
		assert.equal(SB.L.SORT_AFTER_COMBAT, W.frame.title.text)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(1, A.sorts)
	end)

	it("Reflow waits while the mouse is over the items, then regroups", function()
		W.Open()
		A.Clear(0, 1)
		bagUpdate()
		W.scroll.mouseOver = true
		W.reflowButton.scripts.OnClick(W.reflowButton)
		assert.equal(SB.L.REFLOW_WAITING, W.frame.title.text)
		assert.equal(1, #B.placeholders)
		A.Advance(0.3)
		assert.equal(1, #B.placeholders)
		W.scroll.mouseOver = false
		A.Advance(0.3)
		assert.equal(0, #B.placeholders)
		assert.equal("reflow", W.stats.lastLayoutReason)
	end)

	it("the grid view only repaints: no placeholders, nothing moves", function()
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua`
Expected: `21 passed, 6 failed`

- [ ] **Step 3: Strings**

<!-- sbw2:edit T11 07-locale SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.VIEW_SECTIONS = "SwagBag - category view"
```

and replace it with:

```lua
L.VIEW_SECTIONS = "SwagBag - category view"
L.BTN_SORT = "Sort"
L.BTN_REFLOW = "Reflow"
L.SORT_STARTED = "Sorting..."
L.SORT_AFTER_COMBAT = "Sort will run after combat"
L.SORT_UNAVAILABLE = "Sorting is not available right now"
L.REFLOW_DONE = "Regrouped"
L.REFLOW_WAITING = "Regroups when the mouse leaves the items"
L.DROP_ADDED = "Added %s to %s. It moves there when you reopen your bags or press Reflow."
L.DROP_NOT_HERE = "Items can't be added to %s. Drop them on a category header."
```

- [ ] **Step 4: Implement drop, Sort and Reflow in `SwagBag/UI/BagsWindow.lua`**

<!-- sbw2:edit T11 01-fields SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	RETRY = 0.3, -- spec 4.2 rule 5: held-back moves retry 300 ms later
}
```

and replace it with:

```lua
	RETRY = 0.3, -- spec 4.2 rule 5: held-back moves retry 300 ms later
	SORT_SETTLE = 0.3, -- regroup this long after the last bag update of a sort
}
```

<!-- sbw2:edit T11 02-onhide SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
frame:SetScript("OnHide", Guard("bags.hide", function()
	W.state, W.pos = nil, nil
```

and replace it with:

```lua
frame:SetScript("OnHide", Guard("bags.hide", function()
	W.state, W.pos, W.sortPending = nil, nil, false
```

<!-- sbw2:edit T11 03-titlebutton SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
local function titleButton(text, label, onClick)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(72, 18)
```

and replace it with:

```lua
local function titleButton(text, label, onClick, width)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width or 72, 18)
```

<!-- sbw2:edit T11 04-drop-sort SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
SB.SectionHeaders.onClick = function(id)
	W.ToggleSection(id)
end
```

and replace it with:

```lua
-- Reflow button (spec 4.3): regroup now, or as soon as the mouse leaves the items.
function W.Reflow(reason)
	if not frame:IsShown() then
		return false
	end
	local done = W.RequestLayout(reason or "reflow")
	W.Flash(done and L.REFLOW_DONE or L.REFLOW_WAITING)
	return done
end

-- Sort button (AC2.7, spec 5.5): Blizzard's own sort moves items physically. Bag updates
-- during the sort follow spec 4.3 as usual; SORT_SETTLE after the last one the window
-- regroups (a guarded full layout). Never in combat (spec 9): it waits for combat to end.
function W.Sort()
	local A = SB.Adapter
	if A.InCombat() then
		SB.OutOfCombat(W.Sort, "bags.sort", "bags")
		W.Flash(L.SORT_AFTER_COMBAT)
		return false
	end
	if not A.SortBags() then
		W.Flash(L.SORT_UNAVAILABLE)
		return false
	end
	W.sortPending = frame:IsShown()
	W.Flash(L.SORT_STARTED)
	return true
end

local function itemName(itemID, link)
	local info = SB.Adapter.GetItemInfo(itemID)
	if info and info.name then
		return info.name
	end
	return (type(link) == "string" and link:match("%[(.-)%]")) or tostring(itemID)
end

-- AC4.3: an item dropped on a header (or clicked onto it) joins that section's manual
-- list. The item goes back to its slot; it moves into the section on the next open or
-- Reflow, never under the cursor (P5).
function W.DropOnSection(id)
	local A, C = SB.Adapter, SB.Categories
	local itemID, link = A.CursorItem()
	if not itemID then
		return false
	end
	A.ClearCursor()
	if id == C.NEW or id == C.FREE or not C.AddToList(id, itemID) then
		SB.Print(L.DROP_NOT_HERE:format(C.Name(id)))
		return false
	end
	SB.Print(L.DROP_ADDED:format(itemName(itemID, link), C.Name(id)))
	return true
end

SB.SectionHeaders.onClick = function(id)
	if SB.Adapter.CursorItem() then
		W.DropOnSection(id)
	else
		W.ToggleSection(id)
	end
end
SB.SectionHeaders.onDrop = W.DropOnSection

W.reflowButton = titleButton(L.BTN_REFLOW, "bags.reflowButton", function()
	W.Reflow("reflow")
end, 60)
W.reflowButton:SetPoint("RIGHT", W.viewButton, "LEFT", -4, 0)
W.sortButton = titleButton(L.BTN_SORT, "bags.sortButton", function()
	W.Sort()
end, 52)
W.sortButton:SetPoint("RIGHT", W.reflowButton, "LEFT", -4, 0)
```

<!-- sbw2:edit T11 05-open SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	W.RestorePosition()
	frame:SetScale(SB.GridLayout.ClampScale(SB.Config.Get("bags.scale")))
	frame:Show()
	W.Layout("open")
```

and replace it with:

```lua
	W.RestorePosition()
	frame:SetScale(SB.GridLayout.ClampScale(SB.Config.Get("bags.scale")))
	W.sortPending = false
	frame:Show()
	W.Layout("open")
```

<!-- sbw2:edit T11 06-listener SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	if W.state and (#moves > 0 or #W.state.deferred > 0) then
		W.ApplyChanges(moves)
	end
	if touched then
```

and replace it with:

```lua
	if W.state and (#moves > 0 or #W.state.deferred > 0) then
		W.ApplyChanges(moves)
	end
	if W.sortPending then
		SB.Debounce("bags.sortSettle", W.SORT_SETTLE, function()
			W.sortPending = false
			W.Reflow("sort")
		end, "bags")
	end
	if touched then
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua`
Expected: `27 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (32 files)`, `360 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 7: Commit**

```bash
git add SwagBag/UI/BagsWindow.lua SwagBag/Locale/enUS.lua spec/bagswindow_sections_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 2 Task 11: drag onto a header to assign, Sort and Reflow buttons" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 8: In-game session E2: drag-to-assign, Sort, Reflow, V12 at the bank (the user does this; about 20 minutes)**

Give the user this checklist exactly. Stand near a banker, with a training dummy close by if possible.

1. Type `/reload`. Press **B**. Next to the **Grid** button there are now **Sort** and **Reflow** buttons.
2. Pick one item that is in **Other** (or any item you want somewhere else). Left-click it to pick it up, then drop it on the **Consumables** header. Chat says `Added <item name> to Consumables. It moves there when you reopen your bags or press Reflow.` The item goes back to where it was. Nothing moves.
3. Click **Reflow**. The title briefly says `Regrouped`, and the item now sits in Consumables.
4. Press **B** twice (close, open). It is still in Consumables. Type `/reload` and press **B**: still there (saved).
5. Pick up another item and **click** (do not drag) on the **Gear** header. The same kind of chat line appears for Gear, and Gear does **not** collapse.
6. Pick up an item and drop it on the **New** header. Chat says `Items can't be added to New. Drop them on a category header.` The item goes back.
7. If you carry a fish or a lure that is not in **Fish & Lures**, drop it on that header, then click **Reflow**. It moves there.
8. Click **Sort**. The title says `Sorting...`. Blizzard sorts your bags. For a moment faded icons may appear. About half a second after the sorting stops, the window regroups (title `Regrouped`): no faded icons, and every item is in its section. (If your bags were already sorted, nothing moves and nothing regroups. That is fine. Swap two items by hand and try again.)
9. Click **Sort** again and immediately move the mouse over the items and keep it there. The window waits. The title says `Regroups when the mouse leaves the items`. Move the mouse off the window. It regroups.
10. Attack a training dummy. In combat, click **Sort**. The title says `Sort will run after combat`, and nothing moves. Leave combat. Within a moment the sort runs and the window regroups.
11. **V12 at the bank:** talk to the banker (Blizzard's bank window is still used this week). Right-click an item in the SwagBag window: it goes to the bank, a faded copy stays where it was, and nothing else moves.
12. Drag an item from the bank into an empty SwagBag slot. It appears in **New**.
13. Close the bank and press **B** twice. Everything is regrouped, with no faded icons.
14. Type `/swagbag report`, press Ctrl+C, and paste it into Claude Code. Claude checks:
    - no new errors and `Blocked actions: none`;
    - `Categories: 18 (N edited)  Broken: none`, where N is the number of sections you dropped items on;
    - `Last bags layout: … ms (sort)` or `(reflow)` at or below 40 ms.

Pass: steps 2–13 behave as described, and no item ever moved under the mouse.

---
## Daily V12 check (spec §12.2 week 2: "V12 every day"; Oct 10–14, about 5 minutes)

At the end of each day's play, the user answers these and pastes the report:

1. Did any item ever move while your mouse was on it? (yes/no; if yes, what were you doing)
2. Did you ever use, sell or pick up a different item than the one you clicked? (yes/no)
3. Did any item sit in a wrong section after you reopened your bags? (item name + section)
4. Did a faded icon ever do anything other than show its tooltip? (yes/no)
5. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks for no new errors, `Blocked actions: none`, `Broken: none`, and the layout time.

Any "yes" is a bug report. Claude reproduces it as a failing test in `spec/layout_spec.lua` or `spec/bagswindow_sections_spec.lua` before fixing it.

## Week 2 exit check (spec §12.2 week 2: "Category view is the user's default bag; no item ever moves under the cursor")

The user ticks these in game on Oct 14 and pastes the final `/swagbag report` into Claude Code:

1. [ ] Sessions E0, E1 and E2 passed (or every failure was fixed and its step re-run).
2. [ ] At least three days of play with the category view as the only bag view, including at least one dungeon or M+ key. Bags were opened with B, the backpack button, a bag-bar icon, the vendor, the mailbox and the bank.
3. [ ] The daily V12 check had five "no" answers every day, or every "yes" was fixed.
4. [ ] V4 passed (E1 steps 12–13): a faded icon only ever shows its tooltip.
5. [ ] The items in **Other** were reviewed. Each was either moved by drag-onto-header or reported, so Claude can decide whether a default category needs a better rule.
6. [ ] Collapse state survived `/reload` and logging out and back in.
7. [ ] The final report shows: errors `none` (or only deliberate `debug:error` entries), `Blocked actions: none`, `Categories: 18 (N edited)  Broken: none`, and `Last bags layout` ≤ 25 ms for `open`.
8. [ ] Claude ran `scripts/check.sh` on the branch: `ALL CHECKS PASSED`, 360 tests or more. The branch is merged (or kept) per the user's choice.

If any line fails: paste the report, and Claude fixes it before week 3 starts. Any slip is reported at the end of the week (spec §12.2).

## What week 3 builds on

Week 3 (M4 bank + warband with V2, M4G guild bank with G1, M6 overlays, Auctionator totals) consumes these interfaces unchanged:

- **Categories and categorizer:** `SB.Categories.SectionOrder/Name/Get/AddToList/Counts`, `SB.Categorizer.Assign` (same rules for bank items; `location` keywords are volatile), `Categories.MarkFailed`. The crest allowlist (spec §13.2 item 4) adds a `crest` keyword and changes `c_keystone`'s query to `keystone | crest` in `Engine/CategoryDefaults.lua`. That is a default change, so users' diffs stay intact.
- **Layout:** `SB.Layout.Build/Position/Apply/Moves` are window-agnostic. A bank window builds one state per group (character bank, warband bank) or one state with group-prefixed section ids. `Position` takes any column count.
- **Window pattern:** `UI/BagsWindow.lua` shows the recipe:
  - `RequestLayout` (guarded full layout), `Restack` (guarded collapse), `ApplyChanges` (guarded §4.3);
  - `Collapsed()` keyed per window (`ui.collapsed.bank`);
  - pooled headers and placeholders;
  - the `OnHide` cleanup;
  - `SB_*_CLOSED`.
- **Sort:** `SB.Adapter.SortBags` sits next to a `SortBank(bankType)` that week 3 adds. `W.Sort`'s "settle then guarded reflow" is reused for the bank (spec §5.5).
- **Buttons:** `SB.Buttons.AcquirePlaceholder(parent, …)` takes a parent, so the bank window's scroll child works. The week-1 ledger minors flagged for week 3 (EnsureCapacity last-wins, tabs purchased after login) still apply.
- **Report:** the `Categories:` and `Last bags layout:` lines. Week 3 adds the bank layout time.
- **Search:** `Search.lastWarning` and `NeedsVolatileRefresh` work for any window that provides `ForEachSlot`.

## Spec coverage (week-2 scope → task)

| Week-2 item (spec §12.2 M3 and brief) | Task |
|---|---|
| Residual week-1 fixes (ledger 92–94): error-line anchors, vendor auto-close hardening, ToggleBag 0–5, stale `autoOpenedBy` | 0 |
| Desk spike F (§7.1, §13.2 item 1): grammar diff doc, §7.2/§7.5 updates, compatibility changes | 1 (doc written during planning) |
| §8.2/§8.5 schema: categories, userEdits (diffs), categoryOrder, per-character collapse | 2, 3 |
| §7.6 default category set; AC4.1 | 3 |
| §7.7 categories `{query, priority, itemList}`; exclude → include → rules; tri-state nil blocks; ties by id; AC4.2 | 3, 4 |
| §7.10 a broken category never affects others; per-category error isolation (ledger 72), recorded once | 3, 4 |
| §7.8 memo by cache class, bounded 4,000, dropped on change, never volatile | 4 |
| §11.1 Categorizer tests (priorities, lists, nil blocking, memo classes, caged pets and keystones by link, determinism) | 4 |
| Deferred minors: search eval errors flooding the ring; stale cooldown/new/usable searches (§9-safe design) | 5, 10 |
| §4 layout: sections, New, Free, placeholders, New overflow, collapse/expand same cells, scroll clamp; §11.1 1,290-slot fixture ≤ 20 ms | 6, 7 |
| §4.3 every state-transition row; §4.2 rule 5 hover/drag guard; AC3.4 `noWrongItemInSection` | 7, 10 |
| §4.1 placeholders as pooled plain frames; §4.2 rule 3 tooltip only; V4 | 8, 10 (E1) |
| AC3.1 grid/sections toggle without /reload, in or out of combat | 9, 10 (E1) |
| AC3.2 collapsible headers, state persisted per section per window | 9, 10 (E1) |
| AC3.3/AC4.4 New section; AC3.5 Free of real buttons; AC3.7 scroll clamp | 6, 7, 9, 10 |
| AC4.3 drag onto a header adds to the manual list with confirmation | 11 (E2) |
| AC2.7/§5.5 Sort through the Adapter, reflow after the bag updates, hover guard | 11 (E2) |
| V12 (loot, use, vendor, split, drag, sort, bank) | E1, E2, daily V12 check |
| Deferred minors: leaked spec globals in `bagswindow_spec`, stale BagsWindow comment, Ctrl+wheel full layout, Commands comment | 9, 0 |
| §9 budgets evidence in game (ledger P10) | 9 (report line), E1/E2 |

## How this plan was checked (while writing it)

- Every code block above was extracted from this file into a scratch folder outside the repo and applied, task by task, to a fresh clone of `main` (`635e9cc`). For each task, the spec files were applied alone first: the "fail" outputs above are those red runs. Then the whole task was applied and `scripts/check.sh` was run: the totals above (252 → 360) and `ALL CHECKS PASSED` are those green runs.
- Spec coverage: see the table above. Not in week 2 by design: bank/warband windows and `SortBank` (week 3), settings UI for "reagent bag separate" and New rows (week 4 settings pages; the Config keys exist now), crest allowlist (§13.2 item 4), `/swagbag perf` (the report's layout line covers the budget evidence this week).
- Placeholder scan: no TBD/TODO/"similar to"; every step that changes code shows the code.
- Name check: every `SB.*` name used by a task exists on `main` or in an earlier task's **Produces** block (checked by grepping the final tree).
- Review Focus: each of the five lines names the test that pins it, in the task that owns the code.
