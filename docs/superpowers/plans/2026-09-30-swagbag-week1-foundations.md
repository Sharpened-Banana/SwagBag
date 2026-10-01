# SwagBag Week 1 (Oct 1–7, 2026): Foundations, Grid Bags, Safe Mode, Query Engine. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** By the end of week 1 the user plays all day with SwagBag's grid bag window and search box as their only bag UI, and Safe Mode has been shown to drop back to Blizzard's bags, even in combat.

**Architecture:** This is a single WoW addon folder `SwagBag/`. Its modules hang off a private namespace table `SB` (`local ADDON, SB = ...`). Pure-Lua modules (Query, Config, Inventory diffing, ErrorTrap, Locale, GridLayout, Search, Items) only call `SB.Adapter`. That makes them unit-testable under LuaJIT, using the real `Core/Adapter.lua` with its WoW calls swapped for fakes (`spec/mock_adapter.lua`). WoW-only modules (Buttons, BagsWindow, SearchBox, SafeModeHooks, ReportBox) are lint-checked and then verified by the user in game using numbered checklists. Every entry point from WoW (events, hooks, scripts, timers, slash commands) runs inside `SB.ErrorTrap.Run/Guard`. An error there turns Safe Mode on for that window.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105). LuaJIT 2.1 for tests. A dependency-free test runner `spec/runner.lua`. luacheck 1.2. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements spec §12.2 week 1: M0 + M1 + M2.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only.
- License: `## X-License: All Rights Reserved`. Clean-room: no code copied from any other addon. The `spikes/` folder is a reference only: re-write, never copy wholesale.
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator`.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. Bit flags use arithmetic (`math.floor(mask / flag) % 2 == 1`). `scripts/check.sh` enforces this with LuaJIT's parser and a `goto` grep.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace or `Enum` (enforced by `scripts/check.sh`). Everything else calls `SB.Adapter.*`.
- Forbidden anywhere in `SwagBag/` (spec §5.3, enforced by `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, and `PreClick`/`PostClick` (no pre/post-click scripts on slot buttons).
- P2: every slash command prints feedback. `SB.Slash.Dispatch` guarantees this structurally: a command returns its feedback text, and "Done." is printed if it returns nothing.
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails if code uses an undefined key.
- P6: every WoW entry point runs inside `SB.ErrorTrap.Run` or `SB.ErrorTrap.Guard`. Never call `seterrorhandler` (BugGrabber/BugSack must keep working).
- Slot buttons: one `ContainerFrameItemButtonTemplate` per (bag, slot), parented to a per-bag frame with `SetID(bag)`. They are never reparented, destroyed or re-`SetID`'d. They move only via `ClearAllPoints` + `SetPoint`. In combat: no `CreateFrame` and no pool growth (queue them with `SB.OutOfCombat`).
- No `OnUpdate` scripts anywhere. Idle CPU with windows closed is 0.
- Week-1 budgets (spec §9): pool creation ≤ 150 ms. First bag open ≤ 25 ms. `BAG_UPDATE_DELAYED` debounce 50 ms. Failsafe flush 250 ms. Search keystroke debounce 150 ms, then ≤ 4 ms to re-evaluate 200 slots.
- SavedVariables schema: `schemaVersion = 1`. A newer schema is never touched (Safe Mode plus one message). A failed migration keeps a backup and resets to defaults.
- **Tooling deviation (binding, replaces spec §3.1/§11.1 "busted" and §11.5 GitHub Actions for week 1):** tests run with `luajit spec/runner.lua spec/*_spec.lua`, using the in-repo runner (describe / it / before_each / after_each / assert.equal / same / truthy / falsy / is_nil / has_error). CI is the local `scripts/check.sh`. Every task's verification ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Work on branch `week1-foundations` (created in Task 1). One commit per task, using `git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit`. The message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- In-game checks are written for the user, who is not a programmer. They are numbered, one action per step, and each says what the user should see.

## Review Focus

1. **Items whose data the client has not loaded yet** (fresh login, new loot, caged pets, keystones). They must never cause an error or a false match. Instant facts (class, slot) still work. Loaded-only facts give `nil`. Search dims these items and re-checks them when `ITEM_DATA_LOAD_RESULT` arrives. Pinned by Task 9 (`items_spec` "marks an unloaded item pending…"), Task 10 (`inventory_spec` "item data arriving…"), Task 17 (`keywords_spec` "an unloaded item gives nil…"), and Task 18 (`search_spec` "dims everything that is not a definite match…").
2. **Login or `/reload` during combat.** Pool creation is deferred to the end of combat. Until the pool exists, SwagBag stays out of the way and Blizzard's bags keep working. Once the pool is ready, SwagBag takes over cleanly. Pinned by Task 13 (`safemodehooks_spec` "stays inactive until the button pool exists…" and "when the pool becomes ready later…") and in-game step D3.14.
3. **Saved settings from a newer or broken version.** They are never modified (newer) or are backed up then reset (broken). Both windows go to Safe Mode. Exactly one chat line. Pinned by Task 5 (`config_spec` newer/failed-migration tests) and Task 8 (`boot_spec` "a newer schema is left untouched…" and "a failed migration is reported…").
4. **A Lua error in an event, hook or timer during combat.** It is trapped and recorded with its combat flag. It switches the affected window to Blizzard's bags with exactly one line, and the bag key keeps working. Pinned by Task 3 (`errortrap_spec` "records whether the error happened in combat"), Task 4 (`events_spec` "a failing handler is trapped…"), Task 13 (`safemodehooks_spec` "an error inside a hook flips bags…"), and in-game check V9.
5. **Odd search text:** trailing operators, unbalanced parentheses, unterminated quotes, Lua pattern characters (`%`, `[`, `(`), apostrophes and hyphens. None of these may throw. Errors are positioned, and the previous valid search stays applied. Pinned by Task 14 (`query_lexer_spec`), Task 15 (`query_parser_spec` error tests), Task 16 (`query_spec` "matches name text literally, including pattern characters…"), and Task 18 (`search_spec` "keeps the previous valid search…").

---

## File structure (end of week 1)

```
.luacheckrc                     lint config: std lua51 + WoW read_globals
scripts/check.sh                local CI: syntax, luacheck, forbidden tokens, TOC, tests
scripts/toc_check.lua           TOC <-> files consistency + required headers
scripts/install.sh              symlink SwagBag/ into WoW's AddOns folder
SwagBag/SwagBag.toc             load order in four sections: Core, Engine, UI, Start-up
SwagBag/Core/Init.lua           namespace, VERSION, SB.Print
SwagBag/Locale/enUS.lua         every UI string (L.KEY), English fallback = key
SwagBag/Core/Adapter.lua        the ONLY C_*/Enum caller: clock, timers, containers, items, CHECKS list
SwagBag/Core/SafeMode.lua       per-window Safe Mode flags (pure)
SwagBag/Core/ErrorTrap.lua      Run/Guard, 10-entry ring buffer, auto-fallback line
SwagBag/Core/Events.lua         SB.On/Emit, SB.OutOfCombat queue, SB.Debounce
SwagBag/Core/Config.lua         SwagBagDB/SwagBagCharDB, defaults, overrides, migrations, Reset
SwagBag/Core/Checks.lua         feature checks from Adapter.CHECKS, Apply -> Safe Mode
SwagBag/Core/Blocked.lua        ADDON_ACTION_BLOCKED/FORBIDDEN log for the report
SwagBag/Core/Report.lua         /swagbag report text (pure)
SwagBag/Core/Slash.lua          /swagbag dispatcher + help (P2 by construction)
SwagBag/Core/Commands.lua       safe, report, check, reset, debug
SwagBag/Engine/Items.lua        Items.Describe(bag, slot) -> item record; Items.Key
SwagBag/Engine/Inventory.lua    container model, dirty set, 50 ms flush, 250 ms failsafe, reason flags
SwagBag/Engine/GridLayout.lua   grid cell math, scroll clamp, scale clamp (pure)
SwagBag/Engine/Query/Lexer.lua  tokens with spans
SwagBag/Engine/Query/Parser.lua precedence parser -> AST with spans, positioned errors
SwagBag/Engine/Query/Query.lua  registry, Compile, Eval (tri-state), Validate, Pretty, FormatError
SwagBag/Engine/Keywords.lua     v1.0 keywords: type, slot, quality, binding, numeric, state, location
SwagBag/Engine/Search.lua       search state + Apply (dim) (pure)
SwagBag/UI/ReportBox.lua        copyable report window
SwagBag/UI/Buttons.lua          per-bag frames + ContainerFrameItemButtonTemplate pool
SwagBag/UI/BagsWindow.lua       grid window: scroll, clamp, move, scale, position, Esc
SwagBag/UI/SafeModeHooks.lua    B-key / Blizzard bag frame takeover and release
SwagBag/UI/SearchBox.lua        search box, red error + underline, /swagbag search
SwagBag/UI/DebugV1.lua          optional in-game check V1 (SetBagID strip)
SwagBag/Core/Boot.lua           ADDON_LOADED / PLAYER_LOGIN wiring, SB_LOGIN
spec/runner.lua                 the test runner
spec/helpers/{loader,wow_stub,globals}.lua, spec/mock_adapter.lua, spec/fixtures/items.lua
spec/*_spec.lua                 one spec file per pure module
```

## Schedule and parallel lane

| Day | Tasks | User in game? |
|---|---|---|
| Thu Oct 1 | 1–5 (core). **Parallel lane:** 14–16 (query engine), which need only Tasks 1–2 | no |
| Fri Oct 2 | 6–8 | **yes:** session D2 (commands, report, injected error) |
| Sat Oct 3 | 9–13 | **yes:** session D3 (grid bags + Safe Mode, V3, V9, V4 n/a) |
| Sun Oct 4 | 17–18 (Task 17 needs 6 and 9; Task 18 needs 12, 16 and 17) | **yes:** session D4 (search) |
| Mon Oct 5 | 19 (optional V1) + fixes from the user's reports | optional V1 |
| Tue–Wed Oct 6–7 | daily driving, fixes | **Week 1 exit check** |

If the query lane runs in parallel (for example in a separate worktree), the only file both lanes touch is `SwagBag/SwagBag.toc`. To merge, keep both lanes' lines inside the `# Engine` section. When tasks run in a different order, the `N passed` totals below change. What matters is `0 failed` and `ALL CHECKS PASSED`.

Cumulative `scripts/check.sh` test totals when tasks run in numeric order: T1 7 · T2 14 · T3 30 · T4 39 · T5 49 · T6 56 · T7 67 · T8 84 · T9 92 · T10 104 · T11 104 · T12 109 · T13 116 · T14 123 · T15 135 · T16 156 · T17 169 · T18 174 · T19 174.

## How the TOC grows

Task 1 creates `SwagBag/SwagBag.toc` with four section comments: `# Core`, `# Engine`, `# UI`, `# Start-up (keep last)`. Each later task says "append to the end of section X". That means: add the line directly after the last file line of that section, before the blank line that precedes the next section comment. Final order:

```
## Interface: 120100, 120105
## Title: SwagBag
## Notes: Bags that set themselves up, show what matters, and never break.
## Author: lonezebra
## Version: 0.1.0
## SavedVariables: SwagBagDB
## SavedVariablesPerCharacter: SwagBagCharDB
## OptionalDeps: Auctionator, Syndicator
## X-License: All Rights Reserved

# Core
Core/Init.lua
Locale/enUS.lua
Core/Adapter.lua
Core/SafeMode.lua
Core/ErrorTrap.lua
Core/Events.lua
Core/Config.lua
Core/Checks.lua
Core/Blocked.lua
Core/Report.lua
Core/Slash.lua
Core/Commands.lua

# Engine
Engine/Items.lua
Engine/Inventory.lua
Engine/GridLayout.lua
Engine/Query/Lexer.lua
Engine/Query/Parser.lua
Engine/Query/Query.lua
Engine/Keywords.lua
Engine/Search.lua

# UI
UI/ReportBox.lua
UI/Buttons.lua
UI/BagsWindow.lua
UI/SafeModeHooks.lua
UI/SearchBox.lua
UI/DebugV1.lua

# Start-up (keep last)
Core/Boot.lua
```

---

### Task 1: Toolchain, test runner, check script, addon skeleton

**Files:**
- Create: `spec/runner.lua`, `spec/runner_spec.lua`, `.luacheckrc`, `scripts/check.sh`, `scripts/toc_check.lua`, `SwagBag/SwagBag.toc`, `SwagBag/Core/Init.lua`
- Test: `spec/runner_spec.lua`

**Interfaces:**
- Consumes: none.
- Produces:
  - `luajit spec/runner.lua <spec files...>` defines the globals `describe(name, fn)`, `it(name, fn)`, `before_each(fn)`, `after_each(fn)`, and `assert`. `assert` is callable and has `.equal(expected, actual, msg)`, `.same(expected, actual, msg)` (deep), `.truthy(v, msg)`, `.falsy(v, msg)`, `.is_nil(v, msg)`, and `.has_error(fn, substring, msg)`. The runner prints `FAIL <file> :: <path>` blocks, then a last line `N passed, M failed`, and exits 1 on any failure.
  - `scripts/check.sh` runs five stages and prints `ALL CHECKS PASSED` with exit 0, or `CHECKS FAILED` with exit 1.
  - The addon namespace: every addon file starts with `local ADDON, SB = ...` or `local _, SB = ...`. `SB.name` (the string `"SwagBag"`), `SB.VERSION = "0.1.0"` (must equal the TOC `## Version`), `SB.CHAT_PREFIX`, and `SB.Print(msg)`, which calls `SB.Adapter.ChatPrint(SB.CHAT_PREFIX .. msg)`.

- [ ] **Step 1: Create the work branch and install LuaJIT**

```bash
git checkout -b week1-foundations
brew install luajit
luajit -v
```

Expected: the last line starts with `LuaJIT 2.1`.

- [ ] **Step 2: Write the failing test** (`spec/runner_spec.lua`)

```lua
-- Self-test for spec/runner.lua: the assertions must catch what they claim to.
describe("runner assertions", function()
	it("equal passes on identical values and fails otherwise", function()
		assert.equal(3, 3)
		assert.falsy(pcall(assert.equal, 3, 4))
	end)

	it("same compares nested tables deeply", function()
		assert.same({ a = { 1, 2 }, b = "x" }, { a = { 1, 2 }, b = "x" })
		assert.falsy(pcall(assert.same, { a = { 1, 2 } }, { a = { 1, 3 } }))
		assert.falsy(pcall(assert.same, { a = 1 }, { a = 1, b = 2 }))
	end)

	it("truthy, falsy and is_nil", function()
		assert.truthy(0)
		assert.falsy(false)
		assert.is_nil(nil)
		assert.falsy(pcall(assert.truthy, nil))
		assert.falsy(pcall(assert.falsy, "x"))
		assert.falsy(pcall(assert.is_nil, false))
	end)

	it("has_error checks that an error happens and contains the text", function()
		assert.has_error(function() error("boom here") end, "boom")
		assert.falsy(pcall(assert.has_error, function() end))
		assert.falsy(pcall(assert.has_error, function() error("other") end, "boom"))
	end)

	it("assert itself is still callable", function()
		assert(true)
		assert.falsy(pcall(assert, false, "nope"))
	end)
end)

describe("runner hooks", function()
	local calls = {}
	before_each(function()
		calls[#calls + 1] = "before"
	end)
	after_each(function()
		calls[#calls + 1] = "after"
	end)

	it("runs before_each before the test", function()
		assert.equal("before", calls[#calls])
	end)

	it("ran after_each after the previous test", function()
		assert.same({ "before", "after", "before" }, calls)
	end)
end)
```

- [ ] **Step 3: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/runner_spec.lua`
Expected: FAIL. `luajit: cannot open spec/runner.lua` (exit code 1).

- [ ] **Step 4: Write the runner** (`spec/runner.lua`)

```lua
-- SwagBag test runner: a tiny, dependency-free stand-in for busted.
-- Usage (from the repo root):  luajit spec/runner.lua spec/a_spec.lua spec/b_spec.lua ...
-- Provides globals: describe, it, before_each, after_each, assert (callable table
-- with equal, same, truthy, falsy, is_nil, has_error).

local results = { passed = 0, failed = 0, failures = {} }
local blocks = {} -- stack of describe blocks: { name, before = {}, after = {} }
local currentFile = "?"

local function fullName(name)
	local parts = {}
	for i = 1, #blocks do
		parts[#parts + 1] = blocks[i].name
	end
	parts[#parts + 1] = name
	return table.concat(parts, " > ")
end

local function fail(name, err)
	results.failed = results.failed + 1
	results.failures[#results.failures + 1] = { file = currentFile, name = name, err = tostring(err) }
end

function describe(name, fn)
	blocks[#blocks + 1] = { name = name, before = {}, after = {} }
	local ok, err = pcall(fn)
	if not ok then
		fail(fullName("(describe body)"), err)
	end
	blocks[#blocks] = nil
end

function before_each(fn)
	local top = blocks[#blocks]
	top.before[#top.before + 1] = fn
end

function after_each(fn)
	local top = blocks[#blocks]
	top.after[#top.after + 1] = fn
end

function it(name, fn)
	local full = fullName(name)
	local ok, err = pcall(function()
		for i = 1, #blocks do
			for _, b in ipairs(blocks[i].before) do
				b()
			end
		end
		fn()
	end)
	for i = #blocks, 1, -1 do
		for _, a in ipairs(blocks[i].after) do
			local okA, errA = pcall(a)
			if ok and not okA then
				ok, err = false, errA
			end
		end
	end
	if ok then
		results.passed = results.passed + 1
	else
		fail(full, err)
	end
end

---------------------------------------------------------------------------
-- Assertions
---------------------------------------------------------------------------
local function show(v, depth)
	depth = depth or 0
	if type(v) == "string" then
		return string.format("%q", v)
	end
	if type(v) ~= "table" then
		return tostring(v)
	end
	if depth > 3 then
		return "{...}"
	end
	local keys = {}
	for k in pairs(v) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, k in ipairs(keys) do
		parts[#parts + 1] = tostring(k) .. "=" .. show(v[k], depth + 1)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function prefix(msg)
	return msg and (tostring(msg) .. ": ") or ""
end

local A = {}

function A.equal(expected, actual, msg)
	if expected ~= actual then
		error(prefix(msg) .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
	end
end

function A.same(expected, actual, msg)
	if not deepEqual(expected, actual) then
		error(prefix(msg) .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
	end
end

function A.truthy(v, msg)
	if not v then
		error(prefix(msg) .. "expected a truthy value, got " .. show(v), 2)
	end
end

function A.falsy(v, msg)
	if v then
		error(prefix(msg) .. "expected a falsy value, got " .. show(v), 2)
	end
end

function A.is_nil(v, msg)
	if v ~= nil then
		error(prefix(msg) .. "expected nil, got " .. show(v), 2)
	end
end

function A.has_error(fn, needle, msg)
	local ok, err = pcall(fn)
	if ok then
		error(prefix(msg) .. "expected an error, but the function returned normally", 2)
	end
	if needle and not tostring(err):find(needle, 1, true) then
		error(prefix(msg) .. "error " .. show(tostring(err)) .. " does not contain " .. show(needle), 2)
	end
end

assert = setmetatable(A, {
	__call = function(_, v, msg, ...)
		if not v then
			error(msg or "assertion failed!", 2)
		end
		return v, msg, ...
	end,
})

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------
if #arg == 0 then
	print("usage: luajit spec/runner.lua spec/*_spec.lua")
	os.exit(2)
end

for i = 1, #arg do
	currentFile = arg[i]
	local chunk, loadErr = loadfile(currentFile)
	if not chunk then
		fail("(load)", loadErr)
	else
		local ok, err = pcall(chunk)
		if not ok then
			fail("(file body)", err)
		end
	end
end

for _, f in ipairs(results.failures) do
	print("FAIL " .. f.file .. " :: " .. f.name)
	print("     " .. f.err)
end
print(string.format("%d passed, %d failed", results.passed, results.failed))
os.exit(results.failed == 0 and 0 or 1)
```

- [ ] **Step 5: Run it to verify it passes**

Run: `luajit spec/runner.lua spec/runner_spec.lua`
Expected: `7 passed, 0 failed`

- [ ] **Step 6: Create the addon skeleton**

`SwagBag/SwagBag.toc`:

```
## Interface: 120100, 120105
## Title: SwagBag
## Notes: Bags that set themselves up, show what matters, and never break.
## Author: lonezebra
## Version: 0.1.0
## SavedVariables: SwagBagDB
## SavedVariablesPerCharacter: SwagBagCharDB
## OptionalDeps: Auctionator, Syndicator
## X-License: All Rights Reserved


# Core
Core/Init.lua

# Engine

# UI

# Start-up (keep last)
```

`SwagBag/Core/Init.lua`:

```lua
-- SwagBag: addon namespace. Loaded first (see SwagBag.toc).
-- Every file starts with `local ADDON, SB = ...` and hangs its module off SB.
local ADDON, SB = ...

SB.name = ADDON
SB.VERSION = "0.1.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "

-- Print one chat line. Output goes through the Adapter so tests can capture it.
function SB.Print(msg)
	SB.Adapter.ChatPrint(SB.CHAT_PREFIX .. tostring(msg))
end
```

- [ ] **Step 7: Create the lint config** (`.luacheckrc`)

```lua
-- SwagBag lint config. Addon code is Lua 5.1 (WoW). WoW API names are listed
-- explicitly so a typo in an API name is a lint error, not a runtime error.
std = "lua51"
max_line_length = 140
codes = true

-- Globals SwagBag may WRITE.
globals = {
	"SwagBagDB", "SwagBagCharDB", "SLASH_SWAGBAG1", "SlashCmdList", "StaticPopupDialogs",
}

-- WoW globals SwagBag may READ.
read_globals = {
	"C_AddOns", "C_Bank", "C_Container", "C_Item", "C_Timer", "C_ToyBox", "Enum", "ItemLocation",
	"CreateFrame", "UIParent", "UISpecialFrames", "DEFAULT_CHAT_FRAME", "ChatFontNormal",
	"GetTime", "debugprofilestop", "debugstack", "date", "GetBuildInfo", "GetLocale",
	"InCombatLockdown", "issecretvalue", "hooksecurefunc", "IsControlKeyDown",
	"NUM_CONTAINER_FRAMES", "ContainerFrameCombinedBags",
	"SetItemButtonTexture", "SetItemButtonCount", "SetItemButtonQuality", "SetItemButtonDesaturated",
	"StaticPopup_Show", "YES", "NO",
}

files["spec/"] = {
	std = "+busted",
	globals = {
		"CreateFrame", "SwagBagDB", "SwagBagCharDB", "hooksecurefunc", "NUM_CONTAINER_FRAMES",
		"ContainerFrame1", "ContainerFrame2", "ContainerFrameCombinedBags",
	},
}
files["spec/runner.lua"] = {
	globals = { "describe", "it", "before_each", "after_each", "assert" },
}
files["scripts/"] = { std = "lua51" }
```

- [ ] **Step 8: Create the TOC checker** (`scripts/toc_check.lua`)

```lua
-- Checks SwagBag/SwagBag.toc against the files on disk (spec 11.2).
-- Usage (from the repo root): luajit scripts/toc_check.lua
local TOC = "SwagBag/SwagBag.toc"
local REQUIRED = {
	"## Interface: 120100, 120105",
	"## SavedVariables: SwagBagDB",
	"## SavedVariablesPerCharacter: SwagBagCharDB",
	"## OptionalDeps: Auctionator, Syndicator",
	"## X-License: All Rights Reserved",
}

local problems = {}
local function problem(msg)
	problems[#problems + 1] = msg
end

local toc = io.open(TOC, "r")
if not toc then
	print("TOC check FAILED: " .. TOC .. " not found")
	os.exit(1)
end
local headers, seen, count, version = {}, {}, 0, nil
for raw in toc:lines() do
	local line = raw:gsub("\r$", "")
	if line:match("^##") then
		headers[line] = true
		version = version or line:match("^## Version:%s*(%S+)")
	elseif line:match("%S") and not line:match("^#") then
		local path = line:match("^%s*(.-)%s*$")
		if seen[path] then
			problem("listed twice: " .. path)
		end
		seen[path] = true
		count = count + 1
		local f = io.open("SwagBag/" .. path, "r")
		if f then
			f:close()
		else
			problem("listed but missing: " .. path)
		end
	end
end
toc:close()

for _, h in ipairs(REQUIRED) do
	if not headers[h] then
		problem("missing header: " .. h)
	end
end

local init = io.open("SwagBag/Core/Init.lua", "r")
local codeVersion = init and init:read("*a"):match("SB%.VERSION = \"([^\"]+)\"")
if init then
	init:close()
end
if version ~= codeVersion then
	problem(("## Version %s does not match SB.VERSION %s"):format(tostring(version), tostring(codeVersion)))
end

local p = io.popen("cd SwagBag && find . -name '*.lua' | sort")
for line in p:lines() do
	local path = line:gsub("^%./", "")
	if not seen[path] then
		problem("not listed in the TOC: " .. path)
	end
end
p:close()

if #problems > 0 then
	for _, m in ipairs(problems) do
		print("TOC: " .. m)
	end
	print("TOC check FAILED")
	os.exit(1)
end
print(("TOC OK (%d files)"):format(count))
```

- [ ] **Step 9: Create the check script** (`scripts/check.sh`)

```bash
#!/usr/bin/env bash
# SwagBag local CI (spec 11.2). Run from anywhere; exits non-zero on any failure.
#   1 syntax  luac -p (Lua 5.5) and luajit -bl (Lua 5.1 rules, like WoW)
#   2 lint    luacheck with .luacheckrc
#   3 rules   forbidden tokens (spec 5.3), C_*/Enum only in Core/Adapter.lua, no goto
#   4 toc     scripts/toc_check.lua
#   5 tests   luajit spec/runner.lua spec/*_spec.lua
set -uo pipefail
cd "$(dirname "$0")/.."
status=0
fail() { echo "FAIL: $*"; status=1; }

echo "== 1/5 syntax"
while IFS= read -r f; do
	luac -p "$f" || fail "luac -p $f"
	luajit -bl "$f" > /dev/null || fail "luajit parse $f"
done < <(find SwagBag spec scripts -name '*.lua' | sort)

echo "== 2/5 luacheck"
luacheck SwagBag spec scripts --formatter plain || fail "luacheck"

echo "== 3/5 forbidden tokens"
for tok in 'BankFrame:SetTab' 'BankFrame.SetTab' 'C_Bank.CloseBankFrame' 'CloseBankFrame(' 'OpenAllBags(' \
	'PurchaseBankTab' 'PreClick' 'PostClick'; do
	if grep -rnF -- "$tok" SwagBag; then fail "forbidden token: $tok"; fi
done
if grep -rnE '\.bankType[[:space:]]*=([^=]|$)' SwagBag; then fail "forbidden: writing .bankType"; fi
if grep -rnE '^[[:space:]]*_[[:space:]]*=([^=]|$)' SwagBag; then fail "forbidden: assignment to global _"; fi
if grep -rnE '(^|[^[:alnum:]_])goto[[:space:]]' SwagBag; then fail "forbidden: goto (not Lua 5.1)"; fi
if grep -rnE '(^|[^[:alnum:]_])(C_[A-Z][A-Za-z]*|Enum)\.' SwagBag | grep -v '^SwagBag/Core/Adapter.lua:'; then
	fail "C_* or Enum used outside SwagBag/Core/Adapter.lua"
fi

echo "== 4/5 TOC"
luajit scripts/toc_check.lua || fail "TOC"

echo "== 5/5 unit tests"
luajit spec/runner.lua spec/*_spec.lua || fail "unit tests"

if [ "$status" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "$status"
```

Then: `chmod +x scripts/check.sh`

- [ ] **Step 10: Run all checks**

Run: `scripts/check.sh`
Expected (exactly these lines):

```
== 1/5 syntax
== 2/5 luacheck
== 3/5 forbidden tokens
== 4/5 TOC
TOC OK (1 files)
== 5/5 unit tests
7 passed, 0 failed
ALL CHECKS PASSED
```

- [ ] **Step 11: Prove the rules catch violations, then clean up**

```bash
printf 'BankFrame:SetTab(2)\nC_Container.SortBags()\n' > SwagBag/Core/Planted.lua
scripts/check.sh; echo "exit=$?"
rm SwagBag/Core/Planted.lua
scripts/check.sh
```

Expected from the first run: the output contains `FAIL: luacheck`, `FAIL: forbidden token: BankFrame:SetTab`, `FAIL: C_* or Enum used outside SwagBag/Core/Adapter.lua`, `TOC: not listed in the TOC: Core/Planted.lua`, `CHECKS FAILED` and `exit=1`. The second run ends with `ALL CHECKS PASSED`.

- [ ] **Step 12: Commit**

```bash
git add .luacheckrc spec/runner.lua spec/runner_spec.lua scripts/check.sh scripts/toc_check.lua SwagBag/SwagBag.toc SwagBag/Core/Init.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add LuaJIT test runner, local check script and addon skeleton" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Locale table, Adapter basics, test harness

**Files:**
- Create: `SwagBag/Locale/enUS.lua`, `SwagBag/Core/Adapter.lua`, `spec/helpers/wow_stub.lua`, `spec/mock_adapter.lua`, `spec/helpers/loader.lua`, `spec/init_spec.lua`, `spec/locale_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Core`: `Locale/enUS.lua`, then `Core/Adapter.lua`)
- Test: `spec/init_spec.lua`, `spec/locale_spec.lua`

**Interfaces:**
- Consumes: `SB.Print` (Task 1), the runner (Task 1).
- Produces:
  - `SB.L`: a string table. A missing key returns the key itself. This task defines **every** week-1 string, so later tasks only consume keys.
  - `SB.Adapter` basics: `ChatPrint(text)`, `Now()` (seconds), `ProfileMs()`, `After(seconds, fn)`, `InCombat()` (boolean), `IsSecret(v)`, `Stack()` (string), `Date(fmt)`, `BuildInfo()` (returns `{version, build, toc, locale}`), `Resolve("A.B.C")` (value or nil), and `AddOnState(name)` (returns `loaded:boolean, version:string|nil`).
  - The test harness: `local Loader = dofile("spec/helpers/loader.lua")`. Then `Loader.New({files...})` gives a fresh `SB`. It installs the WoW stubs, loads `Init.lua` and `Locale/enUS.lua`, loads the **real** `Core/Adapter.lua`, and swaps in the fakes. `Loader.LoadFile(SB, path)` and `Loader.Stub` (with `Stub.unknownEvents`) are also available. The mock adds `printed`, `Lines()` (prints without the prefix), `clock`, `Advance(seconds)` (runs due timers in order), `combat`, `globals` (what `Resolve` sees), and `addons` (name → version or false). The stub frame adds `frame:Fire(event, ...)` and `frame.events`.

- [ ] **Step 1: Write the test harness** (test code; nothing here is shipped)

`spec/helpers/wow_stub.lua`:

```lua
-- Minimal WoW API stub for unit tests. Only what pure modules touch at load time:
-- CreateFrame (event frames). Everything else goes through the mock Adapter.
local Stub = {}

-- Events listed here make RegisterEvent throw, like an event removed by a patch.
Stub.unknownEvents = {}

local Frame = {}
Frame.__index = Frame

function Frame:RegisterEvent(event)
	if Stub.unknownEvents[event] then
		error("Attempt to register unknown event \"" .. event .. "\"")
	end
	self.events[event] = true
end

function Frame:UnregisterEvent(event)
	self.events[event] = nil
end

function Frame:SetScript(name, fn)
	self.scripts[name] = fn
end

function Frame:GetScript(name)
	return self.scripts[name]
end

-- Test helper: deliver a WoW event the way the client would.
function Frame:Fire(event, ...)
	if self.events[event] and self.scripts.OnEvent then
		self.scripts.OnEvent(self, event, ...)
	end
end

function Stub.CreateFrame()
	local f = setmetatable({ events = {}, scripts = {} }, Frame)
	Stub.frames[#Stub.frames + 1] = f
	return f
end

function Stub.Install()
	Stub.frames = {}
	Stub.unknownEvents = {}
	CreateFrame = Stub.CreateFrame
end

return Stub
```

`spec/mock_adapter.lua`:

```lua
-- Mock Adapter for unit tests. Loads the REAL SwagBag/Core/Adapter.lua (so its
-- constants and pure helpers are tested too), then replaces every function that
-- would call WoW with an in-memory fake.
local M = {}

function M.New(SB)
	local chunk = assert(loadfile("SwagBag/Core/Adapter.lua"))
	chunk("SwagBag", SB)
	local m = SB.Adapter

	m.clock = 0 -- seconds, advanced only by m.Advance
	m.timers = {}
	m.timerSeq = 0
	m.printed = {}
	m.combat = false
	m.globals = {} -- what Resolve() can see
	m.addons = {} -- name -> version string (loaded) or false (installed, not loaded)

	function m.ChatPrint(text)
		m.printed[#m.printed + 1] = text
	end

	-- Printed lines with the "SwagBag: " chat prefix removed.
	function m.Lines()
		local out = {}
		for i, text in ipairs(m.printed) do
			out[i] = (text:gsub("^|cff33ff99SwagBag|r: ", ""))
		end
		return out
	end

	function m.Now()
		return m.clock
	end

	function m.ProfileMs()
		return m.clock * 1000
	end

	function m.After(seconds, fn)
		m.timerSeq = m.timerSeq + 1
		m.timers[#m.timers + 1] = { at = m.clock + seconds, seq = m.timerSeq, fn = fn }
	end

	-- Move the clock forward, running due timers in time order (ties: creation order).
	function m.Advance(seconds)
		local target = m.clock + seconds
		while true do
			local bestIndex, best
			for i, t in ipairs(m.timers) do
				if t.at <= target and (best == nil or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then
					bestIndex, best = i, t
				end
			end
			if not best then
				break
			end
			table.remove(m.timers, bestIndex)
			m.clock = best.at
			best.fn()
		end
		m.clock = target
	end

	function m.InCombat()
		return m.combat
	end

	function m.IsSecret()
		return false
	end

	function m.Stack()
		return "[stack]"
	end

	local DATE_PARTS = { Y = "2026", m = "10", d = "01", H = "21", M = "03", S = "07" }
	function m.Date(fmt)
		return (fmt:gsub("%%(%a)", DATE_PARTS))
	end

	function m.BuildInfo()
		return { version = "12.1.0", build = "69933", toc = 120100, locale = "enUS" }
	end

	function m.Resolve(path)
		local cur = m.globals
		for part in path:gmatch("[^%.]+") do
			if type(cur) ~= "table" then
				return nil
			end
			cur = cur[part]
			if cur == nil then
				return nil
			end
		end
		return cur
	end

	function m.AddOnState(name)
		local v = m.addons[name]
		if v == nil or v == false then
			return false, nil
		end
		return true, v
	end

	return m
end

return M
```

`spec/helpers/loader.lua`:

```lua
-- Builds a fresh SwagBag namespace for one test: WoW stubs, Init, Locale, the mock
-- Adapter (real Adapter.lua + fakes), then the requested module files in order.
-- Usage:  local SB = Loader.New({ "SwagBag/Core/SafeMode.lua", ... })
local Stub = dofile("spec/helpers/wow_stub.lua")
local Mock = dofile("spec/mock_adapter.lua")

local Loader = { Stub = Stub }

function Loader.LoadFile(SB, path)
	local chunk, err = loadfile(path)
	if not chunk then
		error(err, 2)
	end
	chunk("SwagBag", SB)
end

function Loader.New(files)
	Stub.Install()
	local SB = {}
	Loader.LoadFile(SB, "SwagBag/Core/Init.lua")
	Loader.LoadFile(SB, "SwagBag/Locale/enUS.lua")
	Mock.New(SB)
	for _, path in ipairs(files or {}) do
		Loader.LoadFile(SB, path)
	end
	return SB
end

return Loader
```

- [ ] **Step 2: Write the failing tests**

`spec/init_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")

describe("Init and test harness", function()
	local SB
	before_each(function()
		SB = Loader.New()
	end)

	it("SB.Print prefixes the line and sends it through the Adapter", function()
		SB.Print("hello")
		assert.equal("|cff33ff99SwagBag|r: hello", SB.Adapter.printed[1])
		assert.same({ "hello" }, SB.Adapter.Lines())
	end)

	it("has a version string", function()
		assert.equal("string", type(SB.VERSION))
		assert.truthy(SB.VERSION:match("^%d+%.%d+%.%d+"))
	end)

	it("mock timers run in time order when the clock advances", function()
		local A, order = SB.Adapter, {}
		A.After(2, function() order[#order + 1] = "b" end)
		A.After(0.5, function() order[#order + 1] = "a" end)
		A.Advance(1)
		assert.same({ "a" }, order)
		A.Advance(2)
		assert.same({ "a", "b" }, order)
		assert.equal(3, A.Now())
	end)

	it("mock Resolve walks dotted paths and returns nil when missing", function()
		local A = SB.Adapter
		A.globals = { C_Container = { SortBags = print } }
		assert.equal(print, A.Resolve("C_Container.SortBags"))
		assert.is_nil(A.Resolve("C_Container.Nope"))
		assert.is_nil(A.Resolve("C_Bank.FetchPurchasedBankTabIDs"))
	end)
end)
```

`spec/locale_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")

local function sourceFiles()
	local list = {}
	local p = io.popen("find SwagBag -name '*.lua' | sort")
	for line in p:lines() do
		list[#list + 1] = line
	end
	p:close()
	return list
end

describe("Locale", function()
	local SB
	before_each(function()
		SB = Loader.New()
	end)

	it("falls back to the key for a missing string", function()
		assert.equal("NOT_A_REAL_KEY", SB.L.NOT_A_REAL_KEY)
	end)

	it("defines every L.KEY and L[\"KEY\"] used anywhere in SwagBag/", function()
		local missing = {}
		for _, path in ipairs(sourceFiles()) do
			local f = assert(io.open(path, "r"))
			local text = f:read("*a")
			f:close()
			for key in text:gmatch("%f[%w_]L%.([%a_][%w_]*)") do
				if rawget(SB.L, key) == nil then
					missing[#missing + 1] = path .. ": " .. key
				end
			end
			for key in text:gmatch("%f[%w_]L%[\"([^\"]+)\"%]") do
				if rawget(SB.L, key) == nil then
					missing[#missing + 1] = path .. ": " .. key
				end
			end
		end
		assert.same({}, missing)
	end)

	it("defines the keys that are built dynamically", function()
		for _, reason in ipairs({ "MANUAL", "AUTO", "CHECK", "SCHEMA" }) do
			assert.truthy(rawget(SB.L, "SAFE_REASON_" .. reason), reason)
		end
		for _, code in ipairs({ "VALUE", "NUMBER", "RPAREN", "QUOTE", "KEYWORD", "NUMERIC", "OPERATOR" }) do
			assert.truthy(rawget(SB.L, "QUERY_EXPECT_" .. code), code)
		end
	end)
end)
```

- [ ] **Step 3: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/init_spec.lua spec/locale_spec.lua`
Expected: `0 passed, 7 failed`. Each failure message contains `cannot open SwagBag/Locale/enUS.lua`.

- [ ] **Step 4: Write the Locale table** (`SwagBag/Locale/enUS.lua`)

```lua
-- SwagBag UI strings (P8: every user-visible string lives here and nowhere else).
-- Missing keys fall back to the key itself, so a typo shows up as e.g. "SAFE_ON_BAGZ"
-- in game instead of an error. spec/locale_spec.lua checks that every key used in
-- SwagBag/ is defined here.
local _, SB = ...

local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
SB.L = L

-- General
L.LOADED = "v%s loaded. Type /swagbag help for commands."
L.UNKNOWN_COMMAND = "Unknown command \"%s\". Type /swagbag help for the list."
L.CMD_DONE = "Done."
L.CMD_FAILED = "That command hit an error. It was recorded; type /swagbag report."
L.NO_SETTINGS_YET = "There is no settings window yet. Type /swagbag help for commands."

-- Help
L.HELP_HEADER = "Commands:"
L.HELP_LINE = "/swagbag %s - %s"
L.HELP_HELP = "show this list"
L.HELP_SAFE = "safe [on|off|bags|bank]: show or switch Safe Mode (Blizzard bags)"
L.HELP_REPORT = "open a copyable report to paste into Claude Code"
L.HELP_CHECK = "run all feature checks and print PASS/FAIL"
L.HELP_RESET = "reset all SwagBag settings (asks first, keeps a backup)"
L.HELP_DEBUG = "debug error [bags|bank]: inject a test error to prove Safe Mode; debug v1: V1 test strip"
L.HELP_SEARCH = "search <text>: search the open bag window and print the match count"

-- Safe Mode
L.SAFE_STATE_OFF = "off"
L.SAFE_STATE_ON = "on (%s, %s)"
L.SAFE_REASON_MANUAL = "manual"
L.SAFE_REASON_AUTO = "auto"
L.SAFE_REASON_CHECK = "failed check"
L.SAFE_REASON_SCHEMA = "newer settings"
L.SAFE_STATUS = "Safe Mode: bags=%s bank=%s"
L.SAFE_NOW_ON = "Safe Mode is ON for %s: Blizzard's frames are used. Type /swagbag safe off to switch back."
L.SAFE_NOW_OFF = "Safe Mode is OFF for %s: SwagBag handles them again."
L.SAFE_ALREADY_ON = "Safe Mode was already ON for %s."
L.SAFE_ALREADY_OFF = "Safe Mode was already OFF for %s."
L.SAFE_USAGE = "Use /swagbag safe on, off, bags or bank."
L.WINDOW_BAGS = "bags"
L.WINDOW_BANK = "bank"

-- Errors
L.ERROR_SWITCHED = "SwagBag hit an error and switched to Blizzard bags. Type /swagbag report."
L.ERROR_STILL_FAILING = "Still failing - stay in Safe Mode and send the report (/swagbag report)."
L.DEBUG_ERROR_TEXT = "SwagBag test error (injected by /swagbag debug error)"
L.DEBUG_ERROR_DONE = "Injected a test error into the %s path."
L.DEBUG_USAGE = "Use /swagbag debug error [bags|bank] or /swagbag debug v1."

-- Settings / schema
L.NEWER_SCHEMA = "Settings are from a newer version; update the addon or type /swagbag reset. Running in Safe Mode."
L.MIGRATION_FAILED = "Could not upgrade your settings; they were backed up and reset to defaults. Type /swagbag report."
L.RESET_CONFIRM = "Reset ALL SwagBag settings? A backup copy is kept."
L.RESET_ASKED = "Confirm the reset in the dialog."
L.RESET_DONE = "Settings were reset (a backup was kept). Type /reload to finish."

-- Checks
L.CHECK_PRESENT = "present"
L.CHECK_MISSING = "missing"
L.CHECK_EXPECTED = "expected %s, got %s"
L.CHECK_PASS_LINE = "|cff44ff44PASS|r %s"
L.CHECK_FAIL_LINE = "|cffff4444FAIL|r %s (%s)%s"
L.CHECK_OPTIONAL = " [optional]"
L.CHECK_SUMMARY = "Checks: %d passed, %d failed (%d required)."

-- Report
L.REPORT_TITLE = "SwagBag report - press Ctrl+C to copy, Esc to close"
L.REPORT_OPENED = "Report opened. Press Ctrl+C to copy it, then paste it into Claude Code."
L.REPORT_HEADER = "SwagBag %s | WoW %s (%s) | %s | %s"
L.REPORT_SAFE = "Safe Mode: bags=%s bank=%s"
L.REPORT_FAILED_CHECKS = "Failed checks: %s"
L.REPORT_NONE = "none"
L.REPORT_ERRORS = "Errors (last %d):"
L.REPORT_ERROR_LINE = " %s [%s%s] %s: %s"
L.REPORT_IN_COMBAT = ", in combat"
L.REPORT_BLOCKED = "Blocked actions: %s"
L.REPORT_BLOCKED_ITEM = "%s at %s%s"
L.REPORT_ADDONS = "Bag-related addons: %s"
L.REPORT_NOT_LOADED = "%s (not loaded)"
L.REPORT_SETTINGS = "Settings hash: %s  Schema: %d  Buttons: %d (%d ms)"

-- Bags window
L.BAGS_TITLE = "SwagBag"
L.BAGS_SCALE = "SwagBag %d%%"

-- Search
L.SEARCH_RESULT = "Search \"%s\": %d of %d slots match (%.1f ms)."
L.SEARCH_CLEARED = "Search cleared."
L.SEARCH_OPEN_FIRST = "Open your bags first (press B), then search again."
L.SEARCH_ERROR = "Search error: %s"

-- Query errors
L.QUERY_ERR_AFTER = "Expected %s after \"%s\" at character %d"
L.QUERY_ERR_FOUND = "Expected %s but found %s at character %d"
L.QUERY_EXPECT_VALUE = "a value"
L.QUERY_EXPECT_NUMBER = "a number"
L.QUERY_EXPECT_RPAREN = "a closing )"
L.QUERY_EXPECT_QUOTE = "a closing \""
L.QUERY_EXPECT_KEYWORD = "a known keyword"
L.QUERY_EXPECT_NUMERIC = "a keyword that takes a number (ilvl, level, count, stack, gear, tab)"
L.QUERY_EXPECT_OPERATOR = "& or |"
L.QUERY_FOUND_END = "the end of the search"

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
L.V1_SHOWN = "V1 strip shown with %d usable items. Enter combat, right-click them 3 times, then /swagbag report."
L.V1_HIDDEN = "V1 strip hidden."
L.V1_COMBAT = "Open the V1 strip out of combat; it can only be filled then."
```

- [ ] **Step 5: Write the Adapter basics** (`SwagBag/Core/Adapter.lua`)

```lua
-- SwagBag Adapter: the ONLY file allowed to name C_* namespaces or Enum
-- (scripts/check.sh fails the build otherwise). Everything else calls SB.Adapter.*.
-- Load-time code here must stay safe outside WoW: tests load this file and then
-- replace the WoW-calling functions with fakes (spec/mock_adapter.lua).
local _, SB = ...

local A = {}
SB.Adapter = A

local function isSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
A.IsSecret = isSecret

---------------------------------------------------------------------------
-- Basics: chat, clock, timers, combat, diagnostics
---------------------------------------------------------------------------
function A.ChatPrint(text)
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

function A.Now()
	return GetTime()
end

function A.ProfileMs()
	return debugprofilestop()
end

function A.After(seconds, fn)
	C_Timer.After(seconds, fn)
end

function A.InCombat()
	return InCombatLockdown() == true
end

function A.Stack()
	return debugstack(3, 8, 0) or ""
end

function A.Date(fmt)
	return date(fmt)
end

function A.BuildInfo()
	local version, build, _, toc = GetBuildInfo()
	return { version = version, build = build, toc = toc, locale = GetLocale() }
end

-- Resolve a dotted path such as "C_Container.SortBags" without erroring.
function A.Resolve(path)
	local cur = _G
	for part in path:gmatch("[^%.]+") do
		local ok, nxt = pcall(function()
			return cur[part]
		end)
		if not ok or nxt == nil then
			return nil
		end
		cur = nxt
	end
	return cur
end

-- Returns loaded (boolean), version (string or nil) for another addon.
function A.AddOnState(name)
	if not (C_AddOns and C_AddOns.IsAddOnLoaded) then
		return false, nil
	end
	local loaded = C_AddOns.IsAddOnLoaded(name) == true
	local version = C_AddOns.GetAddOnMetadata(name, "Version")
	return loaded, version
end
```

- [ ] **Step 6: Add both files to the TOC**

Append to the end of the `# Core` section of `SwagBag/SwagBag.toc`, after `Core/Init.lua`:

```
Locale/enUS.lua
Core/Adapter.lua
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/init_spec.lua spec/locale_spec.lua`
Expected: `7 passed, 0 failed`

- [ ] **Step 8: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (3 files)`, `14 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 9: Commit**

```bash
git add SwagBag/Locale/enUS.lua SwagBag/Core/Adapter.lua SwagBag/SwagBag.toc spec/helpers/wow_stub.lua spec/mock_adapter.lua spec/helpers/loader.lua spec/init_spec.lua spec/locale_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add enUS string table, Adapter basics and the unit-test harness" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Safe Mode state and ErrorTrap

**Files:**
- Create: `SwagBag/Core/SafeMode.lua`, `SwagBag/Core/ErrorTrap.lua`, `spec/safemode_spec.lua`, `spec/errortrap_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Core`: `Core/SafeMode.lua`, `Core/ErrorTrap.lua`)
- Test: `spec/safemode_spec.lua`, `spec/errortrap_spec.lua`

**Interfaces:**
- Consumes: `SB.Adapter.Date/Now/InCombat/Stack/IsSecret`, `SB.Print`, and `SB.L` (Task 2). `SB.Emit` is used only if it is present (Task 4 adds it).
- Produces:
  - `SB.SafeMode`:
    - `WINDOWS = {"bags","bank"}` and `state[window] = {on, reason, since, offAt}`.
    - `IsOn(window)` returns a boolean.
    - `Enable(window, reason)` returns true if the flag changed. The reason is one of `"manual"`, `"auto"`, `"check"` or `"schema"`.
    - `Disable(window)` returns true if the flag changed.
    - `RecentlyDisabled(window, seconds)` returns a boolean.
    - `Describe(window)` returns `"off"` or `"on (auto, 21:03)"`.
    - It emits `SB_SAFEMODE_CHANGED(window, on, reason)`.
  - `SB.ErrorTrap`:
    - `Run(label, window, fn, ...)` returns `true, results...` on success, or `false` on error.
    - `Guard(label, fn, window)` returns a wrapped function.
    - The window argument is `"bags"`, `"bank"`, `nil` (meaning both), or `"none"` (record only).
    - `Recent()` returns the entries oldest first. Each entry is `{time, label, window, message, stack, version, combat}`.
    - `Attach(savedList)` and `Record(entry)`.
    - Also `OnError(label, window, message, stack)`, `MAX = 10` and `STILL_FAILING_SECONDS = 10`.

- [ ] **Step 1: Write the failing tests**

`spec/safemode_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")

describe("SafeMode state", function()
	local SB, SM
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/SafeMode.lua" })
		SM = SB.SafeMode
	end)

	it("starts off for bags and bank", function()
		assert.falsy(SM.IsOn("bags"))
		assert.falsy(SM.IsOn("bank"))
	end)

	it("Enable turns a window on once and remembers why", function()
		assert.truthy(SM.Enable("bags", "auto"))
		assert.truthy(SM.IsOn("bags"))
		assert.equal("auto", SM.state.bags.reason)
		assert.falsy(SM.Enable("bags", "manual"), "second Enable reports no change")
		assert.equal("auto", SM.state.bags.reason)
	end)

	it("Disable turns it off and RecentlyDisabled covers the next 10 seconds", function()
		SM.Enable("bags", "manual")
		assert.truthy(SM.Disable("bags"))
		assert.falsy(SM.IsOn("bags"))
		assert.truthy(SM.RecentlyDisabled("bags", 10))
		SB.Adapter.Advance(11)
		assert.falsy(SM.RecentlyDisabled("bags", 10))
		assert.falsy(SM.Disable("bags"), "already off")
	end)

	it("Describe reads off or on with reason and time", function()
		assert.equal("off", SM.Describe("bank"))
		SM.Enable("bank", "auto")
		assert.equal("on (auto, 21:03)", SM.Describe("bank"))
	end)

	it("keeps the two windows independent", function()
		SM.Enable("bank", "check")
		assert.falsy(SM.IsOn("bags"))
		assert.truthy(SM.IsOn("bank"))
		assert.falsy(SM.Enable("nonsense", "manual"))
	end)
end)
```

`spec/errortrap_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")

describe("ErrorTrap", function()
	local SB, ET, SM, A
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua" })
		ET, SM, A = SB.ErrorTrap, SB.SafeMode, SB.Adapter
	end)

	it("Run passes arguments and returns true plus the results", function()
		local ok, a, b = ET.Run("t", "bags", function(x, y) return x + y, "two" end, 2, 3)
		assert.equal(true, ok)
		assert.equal(5, a)
		assert.equal("two", b)
		assert.equal(0, #ET.Recent())
	end)

	it("Run returns false and records label, window, message and stack", function()
		local ok = ET.Run("Views.Bags.Refresh", "bags", function() error("kaboom") end)
		assert.equal(false, ok)
		local e = ET.Recent()[1]
		assert.equal("Views.Bags.Refresh", e.label)
		assert.equal("bags", e.window)
		assert.truthy(e.message:find("kaboom", 1, true))
		assert.equal("[stack]", e.stack)
		assert.equal("2026-10-01 21:03:07", e.time)
		assert.equal(SB.VERSION, e.version)
	end)

	it("records whether the error happened in combat", function()
		A.combat = true
		ET.Run("x", "bags", function() error("in a fight") end)
		assert.equal(true, ET.Recent()[1].combat)
		assert.truthy(SM.IsOn("bags"))
	end)

	it("an error in the bags path switches bags to Safe Mode with one chat line", function()
		ET.Run("x", "bags", function() error("1") end)
		assert.truthy(SM.IsOn("bags"))
		assert.falsy(SM.IsOn("bank"))
		assert.equal("auto", SM.state.bags.reason)
		assert.same({ SB.L.ERROR_SWITCHED }, A.Lines())
	end)

	it("further errors while in Safe Mode are recorded silently", function()
		ET.Run("x", "bags", function() error("1") end)
		ET.Run("x", "bags", function() error("2") end)
		assert.equal(1, #A.printed)
		assert.equal(2, #ET.Recent())
	end)

	it("an error with no window switches both windows, still one line", function()
		ET.Run("x", nil, function() error("1") end)
		assert.truthy(SM.IsOn("bags"))
		assert.truthy(SM.IsOn("bank"))
		assert.equal(1, #A.printed)
		assert.equal("both", ET.Recent()[1].window)
	end)

	it("window \"none\" records without Safe Mode or chat", function()
		ET.Run("slash:report", "none", function() error("1") end)
		assert.falsy(SM.IsOn("bags"))
		assert.equal(0, #A.printed)
		assert.equal(1, #ET.Recent())
	end)

	it("keeps only the last 10 errors", function()
		for i = 1, 12 do
			ET.Run("x", "none", function() error("e" .. i) end)
		end
		local recent = ET.Recent()
		assert.equal(10, #recent)
		assert.truthy(recent[1].message:find("e3", 1, true))
		assert.truthy(recent[10].message:find("e12", 1, true))
	end)

	it("says 'still failing' when an error follows a manual safe off within 10 s", function()
		SM.Enable("bags", "manual")
		SM.Disable("bags")
		A.Advance(5)
		ET.Run("x", "bags", function() error("again") end)
		assert.truthy(SM.IsOn("bags"))
		assert.same({ SB.L.ERROR_STILL_FAILING }, A.Lines())
	end)

	it("Guard wraps a function for hooks and returns its results", function()
		local wrapped = ET.Guard("hook", function(v) return v * 2 end, "bags")
		assert.equal(8, wrapped(4))
		local broken = ET.Guard("hook", function() error("x") end, "bags")
		assert.is_nil(broken())
		assert.truthy(SM.IsOn("bags"))
	end)

	it("Attach adopts the saved list, keeps earlier entries and trims to 10", function()
		ET.Run("early", "none", function() error("before attach") end)
		local saved = {}
		for i = 1, 10 do
			saved[i] = { label = "old" .. i, message = "m" }
		end
		ET.Attach(saved)
		assert.equal(saved, ET.buffer)
		assert.equal(10, #saved)
		assert.equal("old2", saved[1].label)
		assert.equal("early", saved[10].label)
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/safemode_spec.lua spec/errortrap_spec.lua`
Expected: `0 passed, 16 failed`. The failures contain `cannot open SwagBag/Core/SafeMode.lua`.

- [ ] **Step 3: Write `SwagBag/Core/SafeMode.lua`**

```lua
-- SwagBag Safe Mode state: one flag per window ("bags", "bank").
-- When a window's flag is on, SwagBag leaves that window to Blizzard.
-- The WoW hooks that act on these flags live in UI/SafeModeHooks.lua.
local _, SB = ...

local SM = {}
SB.SafeMode = SM

SM.WINDOWS = { "bags", "bank" }
SM.state = { bags = { on = false }, bank = { on = false } }

local function emit(window, on, reason)
	if SB.Emit then
		SB.Emit("SB_SAFEMODE_CHANGED", window, on, reason)
	end
end

function SM.IsOn(window)
	local s = SM.state[window]
	return s ~= nil and s.on
end

-- reason: "manual" | "auto" | "check" | "schema". Returns true if it changed.
function SM.Enable(window, reason)
	local s = SM.state[window]
	if not s or s.on then
		return false
	end
	s.on = true
	s.reason = reason or "manual"
	s.since = SB.Adapter.Date("%H:%M")
	s.offAt = nil
	emit(window, true, s.reason)
	return true
end

function SM.Disable(window)
	local s = SM.state[window]
	if not s or not s.on then
		return false
	end
	s.on = false
	s.reason = nil
	s.since = nil
	s.offAt = SB.Adapter.Now()
	emit(window, false, nil)
	return true
end

-- True if the window was switched off within the last `seconds`.
function SM.RecentlyDisabled(window, seconds)
	local s = SM.state[window]
	return s ~= nil and s.offAt ~= nil and (SB.Adapter.Now() - s.offAt) <= seconds
end

-- "off" or "on (auto, 21:01)" for /swagbag report and /swagbag safe.
function SM.Describe(window)
	local s = SM.state[window]
	local L = SB.L
	if not s.on then
		return L.SAFE_STATE_OFF
	end
	return L.SAFE_STATE_ON:format(L["SAFE_REASON_" .. s.reason:upper()], s.since)
end
```

- [ ] **Step 4: Write `SwagBag/Core/ErrorTrap.lua`**

```lua
-- SwagBag ErrorTrap: every entry point from WoW into SwagBag runs through
-- ErrorTrap.Run / ErrorTrap.Guard. An error is recorded in a 10-entry ring
-- buffer (mirrored into SwagBagDB.errors) and switches the affected window to
-- Safe Mode with exactly one chat line. We never call seterrorhandler, so
-- BugGrabber/BugSack keep working untouched.
local _, SB = ...

local unpack = unpack

local ET = { MAX = 10, STILL_FAILING_SECONDS = 10, buffer = {}, count = 0 }
SB.ErrorTrap = ET

local function pack(...)
	return { n = select("#", ...), ... }
end

local function clean(err)
	if SB.Adapter.IsSecret(err) then
		return "<secret>"
	end
	return tostring(err)
end

function ET.Trim()
	while #ET.buffer > ET.MAX do
		table.remove(ET.buffer, 1)
	end
end

function ET.Record(entry)
	ET.buffer[#ET.buffer + 1] = entry
	ET.Trim()
end

-- Adopt the saved list (SwagBagDB.errors) as the ring; keeps entries caught earlier.
function ET.Attach(list)
	for _, entry in ipairs(ET.buffer) do
		list[#list + 1] = entry
	end
	ET.buffer = list
	ET.Trim()
end

-- Oldest first. Returns a copy.
function ET.Recent()
	local out = {}
	for i, entry in ipairs(ET.buffer) do
		out[i] = entry
	end
	return out
end

-- window: "bags" | "bank" | nil (both) | "none" (record only, never Safe Mode).
function ET.OnError(label, window, message, stack)
	local A = SB.Adapter
	ET.count = ET.count + 1
	ET.Record({
		time = A.Date("%Y-%m-%d %H:%M:%S"),
		label = label,
		window = window or "both",
		message = message,
		stack = stack,
		version = SB.VERSION,
		combat = A.InCombat(),
	})
	if window == "none" then
		return
	end
	local SM = SB.SafeMode
	local targets = window and { window } or SM.WINDOWS
	local switched, stillFailing = false, false
	for _, w in ipairs(targets) do
		if not SM.IsOn(w) then
			if SM.RecentlyDisabled(w, ET.STILL_FAILING_SECONDS) then
				stillFailing = true
			end
			SM.Enable(w, "auto")
			switched = true
		end
	end
	if stillFailing then
		SB.Print(SB.L.ERROR_STILL_FAILING)
	elseif switched then
		SB.Print(SB.L.ERROR_SWITCHED)
	end
end

-- Run fn(...) now. Returns true, fn's results on success; false on error.
function ET.Run(label, window, fn, ...)
	local args = pack(...)
	local caught
	local r = pack(xpcall(function()
		return fn(unpack(args, 1, args.n))
	end, function(err)
		caught = { message = clean(err), stack = SB.Adapter.Stack() }
		return caught
	end))
	if r[1] then
		return true, unpack(r, 2, r.n)
	end
	ET.OnError(label, window, caught.message, caught.stack)
	return false
end

-- Wrap fn for use as a hook/script/timer callback. Returns fn's results, or nothing on error.
function ET.Guard(label, fn, window)
	return function(...)
		return select(2, ET.Run(label, window, fn, ...))
	end
end
```

- [ ] **Step 5: Add both files to the TOC** (append to the end of `# Core`)

```
Core/SafeMode.lua
Core/ErrorTrap.lua
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/safemode_spec.lua spec/errortrap_spec.lua`
Expected: `16 passed, 0 failed`

- [ ] **Step 7: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (5 files)`, `30 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 8: Commit**

```bash
git add SwagBag/Core/SafeMode.lua SwagBag/Core/ErrorTrap.lua SwagBag/SwagBag.toc spec/safemode_spec.lua spec/errortrap_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add per-window Safe Mode state and ErrorTrap with ring buffer and auto-fallback" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Event bus, out-of-combat queue, debounce

**Files:**
- Create: `SwagBag/Core/Events.lua`, `spec/events_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Core`: `Core/Events.lua`)
- Test: `spec/events_spec.lua`

**Interfaces:**
- Consumes: `SB.ErrorTrap.Run` (Task 3), `SB.Adapter.After/InCombat` (Task 2), `CreateFrame` (WoW, or the stub in tests).
- Produces:
  - `SB.On(event, fn, window)` returns false if WoW rejects the event. Handlers are called as `fn(event, ...)` inside `ErrorTrap.Run("event:"..event, window, ...)`. Events named `SB_*` are internal and are never registered with WoW.
  - `SB.Emit(event, ...)` dispatches synchronously.
  - `SB.eventFrame` is the event frame.
  - `SB.OutOfCombat(fn, label, window)` returns true if it ran now, or false if it was queued. Queued entries are deduped by label and drained on `PLAYER_REGEN_ENABLED`.
  - `SB.OutOfCombatPending()` returns the queue length.
  - `SB.Debounce(key, delay, fn, window)` is a trailing debounce.

- [ ] **Step 1: Write the failing test** (`spec/events_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")

local FILES = { "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua" }

describe("Events", function()
	local SB, A
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
	end)

	it("On registers the WoW event and delivers its arguments", function()
		local got
		assert.truthy(SB.On("BAG_UPDATE", function(event, bag) got = { event, bag } end, "bags"))
		assert.truthy(SB.eventFrame.events.BAG_UPDATE)
		SB.eventFrame:Fire("BAG_UPDATE", 3)
		assert.same({ "BAG_UPDATE", 3 }, got)
	end)

	it("On returns false for an event WoW does not know", function()
		Loader.Stub.unknownEvents.BANK_TAB_SETTINGS_UPDATED = true
		assert.falsy(SB.On("BANK_TAB_SETTINGS_UPDATED", function() end))
	end)

	it("internal SB_ messages are not registered with WoW but still dispatch", function()
		local count = 0
		SB.On("SB_TEST", function() count = count + 1 end)
		assert.is_nil(SB.eventFrame.events.SB_TEST)
		SB.Emit("SB_TEST")
		assert.equal(1, count)
	end)

	it("a failing handler is trapped, flips its window, and later handlers still run", function()
		local ran = false
		SB.On("SB_TEST", function() error("bad handler") end, "bags")
		SB.On("SB_TEST", function() ran = true end, "none")
		SB.Emit("SB_TEST")
		assert.truthy(ran)
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.equal("event:SB_TEST", SB.ErrorTrap.Recent()[1].label)
	end)

	it("SafeMode changes are announced as SB_SAFEMODE_CHANGED", function()
		local got
		SB.On("SB_SAFEMODE_CHANGED", function(_, window, on, reason) got = { window, on, reason } end)
		SB.SafeMode.Enable("bank", "manual")
		assert.same({ "bank", true, "manual" }, got)
	end)

	it("OutOfCombat runs immediately when not in combat", function()
		local ran = false
		assert.truthy(SB.OutOfCombat(function() ran = true end, "x"))
		assert.truthy(ran)
	end)

	it("OutOfCombat queues in combat, dedupes by label, and drains on PLAYER_REGEN_ENABLED", function()
		A.combat = true
		local log = {}
		assert.falsy(SB.OutOfCombat(function() log[#log + 1] = "grow-old" end, "grow"))
		SB.OutOfCombat(function() log[#log + 1] = "other" end, "other")
		SB.OutOfCombat(function() log[#log + 1] = "grow-new" end, "grow")
		assert.equal(2, SB.OutOfCombatPending())
		assert.same({}, log)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.same({ "grow-new", "other" }, log)
		assert.equal(0, SB.OutOfCombatPending())
	end)

	it("Debounce runs once, delay after the last call", function()
		local count = 0
		SB.Debounce("k", 0.15, function() count = count + 1 end)
		A.Advance(0.1)
		SB.Debounce("k", 0.15, function() count = count + 1 end)
		A.Advance(0.1)
		assert.equal(0, count)
		A.Advance(0.1)
		assert.equal(1, count)
		A.Advance(1)
		assert.equal(1, count)
	end)

	it("Debounce keys are independent", function()
		local hits = {}
		SB.Debounce("a", 0.05, function() hits[#hits + 1] = "a" end)
		SB.Debounce("b", 0.05, function() hits[#hits + 1] = "b" end)
		A.Advance(0.1)
		assert.same({ "a", "b" }, hits)
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/events_spec.lua`
Expected: `0 passed, 9 failed`. The failures contain `cannot open SwagBag/Core/Events.lua`.

- [ ] **Step 3: Write `SwagBag/Core/Events.lua`**

```lua
-- SwagBag event bus, out-of-combat queue and debounce.
--   SB.On(event, fn, window)   fn(event, ...) runs inside ErrorTrap.Run(label, window)
--   SB.Emit(event, ...)        dispatch now (used for internal "SB_*" messages)
--   SB.OutOfCombat(fn, label, window)  run now, or once combat ends (deduped by label)
--   SB.Debounce(key, delay, fn, window) run fn once, `delay` s after the LAST call
-- Events whose names start with "SB_" are internal and never registered with WoW.
local _, SB = ...

local handlers = {} -- event -> list of { fn, window, label }
local frame = CreateFrame("Frame")
SB.eventFrame = frame

local function isInternal(event)
	return event:sub(1, 3) == "SB_"
end

-- Returns false if WoW refused the event (e.g. removed by a patch); true otherwise.
function SB.On(event, fn, window)
	local list = handlers[event]
	if not list then
		if not isInternal(event) then
			local ok = pcall(frame.RegisterEvent, frame, event)
			if not ok then
				return false
			end
		end
		list = {}
		handlers[event] = list
	end
	list[#list + 1] = { fn = fn, window = window, label = "event:" .. event }
	return true
end

function SB.Emit(event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		local h = list[i]
		SB.ErrorTrap.Run(h.label, h.window, h.fn, event, ...)
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	SB.Emit(event, ...)
end)

---------------------------------------------------------------------------
-- Out-of-combat queue
---------------------------------------------------------------------------
local queue = {}

-- Returns true if fn ran now, false if it was queued for PLAYER_REGEN_ENABLED.
function SB.OutOfCombat(fn, label, window)
	label = label or "outOfCombat"
	if not SB.Adapter.InCombat() then
		SB.ErrorTrap.Run(label, window, fn)
		return true
	end
	for i = 1, #queue do
		if queue[i].label == label then
			queue[i] = { fn = fn, label = label, window = window }
			return false
		end
	end
	queue[#queue + 1] = { fn = fn, label = label, window = window }
	return false
end

function SB.OutOfCombatPending()
	return #queue
end

SB.On("PLAYER_REGEN_ENABLED", function()
	local q = queue
	queue = {}
	for i = 1, #q do
		SB.ErrorTrap.Run(q[i].label, q[i].window, q[i].fn)
	end
end, "none")

---------------------------------------------------------------------------
-- Debounce (trailing): only the last call within `delay` seconds runs.
---------------------------------------------------------------------------
local generations = {}

function SB.Debounce(key, delay, fn, window)
	local gen = (generations[key] or 0) + 1
	generations[key] = gen
	SB.Adapter.After(delay, function()
		if generations[key] == gen then
			SB.ErrorTrap.Run("debounce:" .. key, window, fn)
		end
	end)
end
```

- [ ] **Step 4: Add it to the TOC** (append to the end of `# Core`): `Core/Events.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/events_spec.lua`
Expected: `9 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (6 files)`, `39 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Core/Events.lua SwagBag/SwagBag.toc spec/events_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add event bus, out-of-combat queue and debounce" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Config: schema 1, defaults, character overrides, migrations

**Files:**
- Create: `SwagBag/Core/Config.lua`, `spec/config_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Core`: `Core/Config.lua`)
- Test: `spec/config_spec.lua`

**Interfaces:**
- Consumes: nothing beyond the namespace.
- Produces:
  - `SB.Config.Init(db, charDB)` returns a status: `"new"`, `"ok"`, `"migrated"`, `"reset"` or `"newer"`. After it runs, `Config.db`, `Config.charDB`, `Config.status`, `Config.readOnly` and `Config.lastError` are set.
  - `Config.Get(path)` and `Config.Set(path, value)`. Set returns false while the config is read-only.
  - `Config.CharOverride(path, on)`, `Config.IsCharOverride(path)`, `Config.UI()` (returns `charDB.ui`, which holds `positions`), `Config.Reset()` (returns `db, charDB`) and `Config.Copy(v)`.
  - `Config.CURRENT = 1`, `Config.migrations[n]` and `Config.charMigrations[n]` (each upgrades n-1 → n), and `Config.Defaults.settings = { bags = { columns = 12, scale = 1.0 }, safeMode = { bags = false, bank = false } }`.
  - Account DB shape: `{schemaVersion, settings, errors, backups}`. Character DB shape: `{schemaVersion, overrides, ui = {positions}, backups}`.

- [ ] **Step 1: Write the failing test** (`spec/config_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")

describe("Config", function()
	local SB, Config
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/Config.lua" })
		Config = SB.Config
	end)

	it("creates fresh tables at schema 1 when nothing is saved", function()
		assert.equal("new", Config.Init(nil, nil))
		assert.equal(1, Config.db.schemaVersion)
		assert.equal(1, Config.charDB.schemaVersion)
		assert.same({}, Config.db.errors)
		assert.same({ positions = {} }, Config.UI())
	end)

	it("Get falls back to the defaults", function()
		Config.Init(nil, nil)
		assert.equal(12, Config.Get("bags.columns"))
		assert.equal(false, Config.Get("safeMode.bank"))
		assert.is_nil(Config.Get("bags.nope"))
	end)

	it("Set stores account-wide and Get reads it back", function()
		Config.Init(nil, nil)
		assert.truthy(Config.Set("bags.columns", 10))
		assert.equal(10, Config.Get("bags.columns"))
		assert.equal(10, Config.db.settings.bags.columns)
	end)

	it("a character override wins, takes Set, and falls back when removed", function()
		Config.Init(nil, nil)
		Config.Set("bags.columns", 10)
		Config.CharOverride("bags.columns", true)
		assert.truthy(Config.IsCharOverride("bags.columns"))
		Config.Set("bags.columns", 16)
		assert.equal(16, Config.Get("bags.columns"))
		assert.equal(10, Config.db.settings.bags.columns)
		Config.CharOverride("bags.columns", false)
		assert.equal(10, Config.Get("bags.columns"))
	end)

	it("an override of false is respected", function()
		Config.Init(nil, nil)
		Config.Set("safeMode.bags", true)
		Config.CharOverride("safeMode.bags", true)
		Config.Set("safeMode.bags", false)
		assert.equal(false, Config.Get("safeMode.bags"))
	end)

	it("migrates a v0 table (no schemaVersion) and keeps its settings", function()
		local old = { settings = { bags = { columns = 8 } } }
		assert.equal("migrated", Config.Init(old, { ui = { positions = { bags = { "CENTER" } } } }))
		assert.equal(1, Config.db.schemaVersion)
		assert.equal(8, Config.Get("bags.columns"))
		assert.same({ "CENTER" }, Config.UI().positions.bags)
	end)

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

	it("a failing migration keeps a backup and resets to defaults", function()
		Config.CURRENT = 2
		Config.migrations[2] = function() error("broken step") end
		local saved = { schemaVersion = 1, settings = { bags = { columns = 7 } }, errors = {}, backups = {} }
		assert.equal("reset", Config.Init(saved, nil))
		assert.equal(2, Config.db.schemaVersion)
		assert.equal(12, Config.Get("bags.columns"))
		assert.equal(7, Config.db.backups.v1.settings.bags.columns)
		assert.truthy(Config.lastError:find("broken step", 1, true))
	end)

	it("refuses a newer schema: read-only, saved table untouched", function()
		local saved = { schemaVersion = 99, settings = { bags = { columns = 5 } } }
		assert.equal("newer", Config.Init(saved, nil))
		assert.truthy(Config.readOnly)
		assert.falsy(Config.Set("bags.columns", 3))
		assert.equal(12, Config.Get("bags.columns"))
		assert.same({ schemaVersion = 99, settings = { bags = { columns = 5 } } }, saved)
	end)

	it("Reset backs up what was saved and starts fresh", function()
		local saved = { schemaVersion = 99, settings = { bags = { columns = 5 } } }
		Config.Init(saved, nil)
		local db, charDB = Config.Reset()
		assert.falsy(Config.readOnly)
		assert.equal(1, db.schemaVersion)
		assert.equal(5, db.backups.reset.settings.bags.columns)
		assert.is_nil(charDB.backups.reset)
		assert.truthy(Config.Set("bags.columns", 9))
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/config_spec.lua`
Expected: `0 passed, 10 failed`. The failures contain `cannot open SwagBag/Core/Config.lua`.

- [ ] **Step 3: Write `SwagBag/Core/Config.lua`**

```lua
-- SwagBag Config: account DB (SwagBagDB) + per-character DB (SwagBagCharDB).
--   Config.Init(db, charDB) -> status: "new" | "ok" | "migrated" | "reset" | "newer"
--   Config.Get(path) / Config.Set(path, value)   dotted paths, e.g. "bags.columns"
--   Config.CharOverride(path, on)                make one setting character-specific
--   Config.UI()                                  per-character UI state (positions)
--   Config.Reset()                               back up, then start from defaults
-- Schema rules (spec 8.5): a DB newer than CURRENT is never touched (read-only,
-- Safe Mode); older DBs run migrations[n] (n-1 -> n) in order inside pcall; a
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

local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, val in pairs(v) do
		out[k] = copy(val)
	end
	return out
end
Config.Copy = copy

local function newDB()
	return { schemaVersion = Config.CURRENT, settings = {}, errors = {}, backups = {} }
end

local function newCharDB()
	return { schemaVersion = Config.CURRENT, overrides = {}, ui = { positions = {} }, backups = {} }
end

local function tableOr(v)
	return type(v) == "table" and v or {}
end

-- v0 -> v1: tables written before schemaVersion existed. Keep what we recognise.
Config.migrations[1] = function(db)
	db.settings = tableOr(db.settings)
	db.errors = tableOr(db.errors)
	db.backups = tableOr(db.backups)
end

Config.charMigrations[1] = function(c)
	c.overrides = tableOr(c.overrides)
	c.ui = tableOr(c.ui)
	c.ui.positions = tableOr(c.ui.positions)
	c.backups = tableOr(c.backups)
end

-- Returns table, status, errorMessage
local function upgrade(db, steps, fresh)
	if type(db) ~= "table" then
		return fresh(), "new"
	end
	local from = tonumber(db.schemaVersion) or 0
	if from > Config.CURRENT then
		return db, "newer"
	end
	if from == Config.CURRENT then
		return db, "ok"
	end
	local backup = copy(db)
	backup.backups = nil
	local ok, err = pcall(function()
		for n = from + 1, Config.CURRENT do
			local step = steps[n]
			if not step then
				error("no migration to schema " .. n)
			end
			step(db)
			db.schemaVersion = n
		end
	end)
	if ok then
		return db, "migrated"
	end
	local reset = fresh()
	reset.backups["v" .. from] = backup
	return reset, "reset", tostring(err)
end

local RANK = { ok = 1, new = 2, migrated = 3, reset = 4 }

function Config.Init(db, charDB)
	Config.source = { db = db, charDB = charDB }
	local a, sa, ea = upgrade(db, Config.migrations, newDB)
	local c, sc, ec = upgrade(charDB, Config.charMigrations, newCharDB)
	if sa == "newer" or sc == "newer" then
		Config.status = "newer"
		Config.readOnly = true
		Config.db, Config.charDB = newDB(), newCharDB() -- in memory only; saved tables untouched
		return Config.status
	end
	Config.readOnly = false
	Config.db, Config.charDB = a, c
	Config.status = RANK[sa] >= RANK[sc] and sa or sc
	Config.lastError = ea or ec
	return Config.status
end

local function split(path)
	local parts = {}
	for p in path:gmatch("[^%.]+") do
		parts[#parts + 1] = p
	end
	return parts
end

local function walk(t, parts)
	for i = 1, #parts do
		if type(t) ~= "table" then
			return nil
		end
		t = t[parts[i]]
	end
	return t
end

function Config.Get(path)
	local o = Config.charDB.overrides[path]
	if o ~= nil then
		return o
	end
	local parts = split(path)
	local v = walk(Config.db.settings, parts)
	if v ~= nil then
		return v
	end
	return walk(Config.Defaults.settings, parts)
end

-- Returns false (and changes nothing) while the DB is read-only.
function Config.Set(path, value)
	if Config.readOnly then
		return false
	end
	if Config.charDB.overrides[path] ~= nil then
		Config.charDB.overrides[path] = value
		return true
	end
	local parts = split(path)
	local t = Config.db.settings
	for i = 1, #parts - 1 do
		if type(t[parts[i]]) ~= "table" then
			t[parts[i]] = {}
		end
		t = t[parts[i]]
	end
	t[parts[#parts]] = value
	return true
end

function Config.CharOverride(path, on)
	if Config.readOnly then
		return false
	end
	if on then
		if Config.charDB.overrides[path] == nil then
			Config.charDB.overrides[path] = Config.Get(path)
		end
	else
		Config.charDB.overrides[path] = nil
	end
	return true
end

function Config.IsCharOverride(path)
	return Config.charDB.overrides[path] ~= nil
end

function Config.UI()
	return Config.charDB.ui
end

-- Wipe both DBs after keeping a copy of the saved data. Returns the new tables,
-- which the caller assigns to SwagBagDB / SwagBagCharDB.
function Config.Reset()
	local src = Config.source or {}
	local oldDB = type(src.db) == "table" and copy(src.db) or nil
	local oldChar = type(src.charDB) == "table" and copy(src.charDB) or nil
	if oldDB then
		oldDB.backups = nil
	end
	if oldChar then
		oldChar.backups = nil
	end
	Config.db, Config.charDB = newDB(), newCharDB()
	Config.db.backups.reset = oldDB
	Config.charDB.backups.reset = oldChar
	Config.source = { db = Config.db, charDB = Config.charDB }
	Config.readOnly = false
	Config.status = "ok"
	return Config.db, Config.charDB
end
```

- [ ] **Step 4: Add it to the TOC** (append to the end of `# Core`): `Core/Config.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/config_spec.lua`
Expected: `10 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (7 files)`, `49 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Core/Config.lua SwagBag/SwagBag.toc spec/config_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add Config with schema 1, defaults, character overrides and guarded migrations" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Adapter containers/items API and feature Checks

**Files:**
- Create: `SwagBag/Core/Checks.lua`, `spec/helpers/globals.lua`, `spec/checks_spec.lua`
- Modify: `SwagBag/Core/Adapter.lua` (append a section at the end of the file), `spec/mock_adapter.lua` (two edits), `SwagBag/SwagBag.toc` (append to `# Core`: `Core/Checks.lua`)
- Test: `spec/checks_spec.lua`

**Interfaces:**
- Consumes: `SB.Adapter.Resolve` (Task 2), `SB.SafeMode.Enable/WINDOWS` (Task 3), `SB.L` (Task 2).
- Produces (Adapter, the only `C_*`/`Enum` caller):
  - Constants: `BAG_CAPACITY = 38`, `BANK_TAB_CAPACITY = 98`, and the tables `ITEM_CLASS`, `CONSUMABLE_SUB`, `TRADEGOODS_SUB`, `MISC_SUB` and `ARMOR_SUB`. Their numbers are overridden from `Enum` when present.
  - `BindKind(bindType)` returns `"none"|"pickup"|"equip"|"use"|"quest"|"account"|"warbound"|"wue"|nil`.
  - `BagKind(bag)` returns a location (`"backpack"|"bags"|"reagentbag"|"bank"|"warband"`) and, for bank tabs, the tab number.
  - `GetBagIDs(kind)`: kind is `"bags"` (0–5) or `"bank"`/`"warband"` (purchased tab IDs via `C_Bank.FetchPurchasedBankTabIDs`).
  - `NumSlots(bag)`.
  - `GetSlot(bag, slot)` returns `{bag, slot, itemID, link, count, quality, icon, isLocked, isBound, name, hasNoValue}`, or nil for an empty slot.
  - `GetItemInstant(itemID)` returns `{itemID, equipLoc, icon, classID, subclassID}`.
  - `GetItemInfo(itemID)` returns `{name, quality, baseIlvl, reqLevel, maxStack, sellPrice, bind, expansionID, isCraftingReagent}`, or nil while the item is loading.
  - `GetIlvl(bag, slot)`, `IsWarboundUntilEquip(bag, slot)`, `HasUpgradeTrack(bag, slot)`, `IsOnCooldown(bag, slot)`, `InEquipmentSet(bag, slot)`, `IsUsable(itemID)`, `IsToy(itemID)`, `IsQuestItem(bag, slot)`, `RequestLoad(itemID)`.
  - `CHECKS`: a list of `{path, window, required, value?}`.
- Produces (mock): fixture helpers `AddItem(itemID, def)`, `SetBagSize(bag, n)`, `Put(bag, slot, itemID, count, extra)`, `Clear(bag, slot)`, plus `bagIDs`, `slots`, `items` and `loadRequests`. The mock versions of every function above read the fixtures (`def` fields: name, classID, subclassID, equipLoc, quality, ilvl, reqLevel, maxStack, bind, isCraftingReagent, usable, toy, pending; `extra` fields: link, isLocked, isBound, isWUE, onCooldown, inSet, upgrade, quest, ilvl).
- Produces (Checks):
  - `SB.Checks.Run()` returns an ordered list of `{name, pass, detail, required, window}` and also stores it in `Checks.last`.
  - `Checks.Failed(results, requiredOnly, window)` returns a list.
  - `Checks.Apply(results)` returns the list of windows switched to Safe Mode (reason `"check"`).
  - `Checks.Lines(results)` returns chat lines.
- Produces (test helper): `dofile("spec/helpers/globals.lua").AllPresent(A)` returns a fake `_G` in which every check passes.

- [ ] **Step 1: Write the failing test and its helper**

`spec/helpers/globals.lua`:

```lua
-- Fake _G builders for tests that run Checks.
local Globals = {}

-- A fake _G in which every path in Adapter.CHECKS resolves (exact values where given).
function Globals.AllPresent(A)
	local g = {}
	for _, c in ipairs(A.CHECKS) do
		local t = g
		local parts = {}
		for p in c.path:gmatch("[^%.]+") do
			parts[#parts + 1] = p
		end
		for i = 1, #parts - 1 do
			if type(t[parts[i]]) ~= "table" then
				t[parts[i]] = {}
			end
			t = t[parts[i]]
		end
		local leaf = parts[#parts]
		if c.value ~= nil then
			t[leaf] = c.value
		elseif t[leaf] == nil then
			t[leaf] = {}
		end
	end
	return g
end

return Globals
```

`spec/checks_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Globals = dofile("spec/helpers/globals.lua")

describe("Checks", function()
	local SB, A
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/SafeMode.lua", "SwagBag/Core/Checks.lua" })
		A = SB.Adapter
		A.globals = Globals.AllPresent(A)
	end)

	it("passes every check when all APIs are present", function()
		local results = SB.Checks.Run()
		assert.equal(#A.CHECKS, #results)
		assert.same({}, SB.Checks.Failed(results))
		assert.same({}, SB.Checks.Apply(results))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("a missing required bags API fails and turns on Safe Mode for bags only", function()
		A.globals.C_Container.GetContainerItemInfo = nil
		local results = SB.Checks.Run()
		local failed = SB.Checks.Failed(results, true)
		assert.equal(1, #failed)
		assert.equal("C_Container.GetContainerItemInfo", failed[1].name)
		assert.equal("missing", failed[1].detail)
		assert.same({ "bags" }, SB.Checks.Apply(results))
		assert.equal("check", SB.SafeMode.state.bags.reason)
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	it("a wrong enum value fails with expected/got detail", function()
		A.globals.Enum.BankType.Account = 1
		local failed = SB.Checks.Failed(SB.Checks.Run(), true, "bank")
		assert.equal(1, #failed)
		assert.equal("expected 2, got 1", failed[1].detail)
	end)

	it("an optional failure never turns on Safe Mode", function()
		A.globals.C_ToyBox = nil
		local results = SB.Checks.Run()
		assert.equal(1, #SB.Checks.Failed(results))
		assert.equal(0, #SB.Checks.Failed(results, true))
		assert.same({}, SB.Checks.Apply(results))
	end)

	it("Lines prints one line per check and a summary", function()
		A.globals.C_ToyBox = nil
		local lines = SB.Checks.Lines(SB.Checks.Run())
		assert.equal(#A.CHECKS + 1, #lines)
		assert.equal("|cff44ff44PASS|r C_Container.GetContainerNumSlots", lines[1])
		local summary = ("Checks: %d passed, 1 failed (0 required)."):format(#A.CHECKS - 1)
		assert.equal(summary, lines[#lines])
	end)
end)

describe("Adapter pure helpers", function()
	local A
	before_each(function()
		A = Loader.New().Adapter
	end)

	it("BagKind maps bag IDs to locations and bank tab numbers", function()
		assert.same({ "backpack" }, { A.BagKind(0) })
		assert.same({ "bags" }, { A.BagKind(4) })
		assert.same({ "reagentbag" }, { A.BagKind(5) })
		assert.same({ "bank", 2 }, { A.BagKind(7) })
		assert.same({ "warband", 2 }, { A.BagKind(13) })
		assert.same({}, { A.BagKind(99) })
	end)

	it("BindKind maps bind types to names", function()
		assert.equal("pickup", A.BindKind(1))
		assert.equal("equip", A.BindKind(2))
		assert.equal("wue", A.BindKind(9))
		assert.equal("none", A.BindKind(42))
		assert.is_nil(A.BindKind(nil))
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/checks_spec.lua`
Expected: `0 passed, 7 failed`. Five failures contain `cannot open SwagBag/Core/Checks.lua`. Two contain `attempt to call field 'BagKind' (a nil value)`.

- [ ] **Step 3: Append the containers section to `SwagBag/Core/Adapter.lua`** (paste it at the very end of the file, after `A.AddOnState`)

```lua
---------------------------------------------------------------------------
-- Containers and items
---------------------------------------------------------------------------
A.BAG_CAPACITY = 38 -- buttons pre-created per bag (largest bag size)
A.BANK_TAB_CAPACITY = 98 -- buttons pre-created per purchased bank tab

-- Item class / subclass IDs. Numbers are the 12.1 values; Enum overrides them
-- when present so a renumbering patch is picked up automatically.
A.ITEM_CLASS = {
	Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5,
	Tradegoods = 7, Recipe = 9, Questitem = 12, Key = 13, Miscellaneous = 15,
	Battlepet = 17, Profession = 19, Housing = 20,
}
A.CONSUMABLE_SUB = { Potion = 1, Elixir = 2, Flask = 3, FoodDrink = 5, VantusRune = 9 }
A.TRADEGOODS_SUB = { Cloth = 5, Leather = 6, MetalStone = 7, Cooking = 8, Herb = 9, Enchanting = 12 }
A.MISC_SUB = { Junk = 0, CompanionPet = 2, Mount = 5 }
A.ARMOR_SUB = { Cosmetic = 5 }

local function overrideFromEnum(target, enumTable)
	if type(enumTable) ~= "table" then
		return
	end
	for name in pairs(target) do
		if type(enumTable[name]) == "number" then
			target[name] = enumTable[name]
		end
	end
end
if Enum then
	overrideFromEnum(A.ITEM_CLASS, Enum.ItemClass)
	overrideFromEnum(A.CONSUMABLE_SUB, Enum.ItemConsumableSubclass)
	overrideFromEnum(A.TRADEGOODS_SUB, Enum.ItemTradegoodsSubclass)
	overrideFromEnum(A.MISC_SUB, Enum.ItemMiscellaneousSubclass)
	overrideFromEnum(A.ARMOR_SUB, Enum.ItemArmorSubclass)
end

-- Bind type number -> SwagBag bind kind. Names come from Enum.ItemBind when present.
local BIND_BY_ENUM_NAME = {
	None = "none", OnAcquire = "pickup", OnEquip = "equip", OnUse = "use", Quest = "quest",
	ToWoWAccount = "account", ToBnetAccount = "warbound", ToBnetAccountUntilEquipped = "wue",
}
local BIND_FALLBACK = { [0] = "none", [1] = "pickup", [2] = "equip", [3] = "use", [4] = "quest",
	[7] = "account", [8] = "warbound", [9] = "wue" }
local bindMap

function A.BindKind(bindType)
	if bindType == nil then
		return nil
	end
	if not bindMap then
		bindMap = {}
		for k, v in pairs(BIND_FALLBACK) do
			bindMap[k] = v
		end
		local enum = Enum and Enum.ItemBind
		if type(enum) == "table" then
			for name, value in pairs(enum) do
				if BIND_BY_ENUM_NAME[name] then
					bindMap[value] = BIND_BY_ENUM_NAME[name]
				end
			end
		end
	end
	return bindMap[bindType] or "none"
end

-- Bag ID ranges from Enum.BagIndex (verified 12.1): 0 backpack, 1-4 bags,
-- 5 reagent bag, 6-11 character bank tabs, 12-16 warband bank tabs.
-- Returns location kind and, for bank tabs, the tab number (1-based).
function A.BagKind(bag)
	if bag == 0 then
		return "backpack", nil
	elseif bag >= 1 and bag <= 4 then
		return "bags", nil
	elseif bag == 5 then
		return "reagentbag", nil
	elseif bag >= 6 and bag <= 11 then
		return "bank", bag - 5
	elseif bag >= 12 and bag <= 16 then
		return "warband", bag - 11
	end
	return nil, nil
end

-- kind: "bags" | "bank" | "warband". Bank kinds return PURCHASED tab IDs only.
function A.GetBagIDs(kind)
	if kind == "bags" then
		return { 0, 1, 2, 3, 4, 5 }
	end
	local bt = Enum and Enum.BankType
	local bankType = bt and ((kind == "bank" and bt.Character) or (kind == "warband" and bt.Account))
	if bankType == nil or not (C_Bank and C_Bank.FetchPurchasedBankTabIDs) then
		return {}
	end
	local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
	local out = {}
	if ok and type(ids) == "table" then
		for i = 1, #ids do
			if not isSecret(ids[i]) then
				out[#out + 1] = ids[i]
			end
		end
	end
	return out
end

function A.NumSlots(bag)
	local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
	if ok and type(n) == "number" and not isSecret(n) then
		return n
	end
	return 0
end

-- Normalized slot record, or nil for an empty slot.
function A.GetSlot(bag, slot)
	local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
	if not ok or type(info) ~= "table" or info.itemID == nil or isSecret(info.itemID) then
		return nil
	end
	return {
		bag = bag,
		slot = slot,
		itemID = info.itemID,
		link = info.hyperlink,
		count = info.stackCount or 1,
		quality = info.quality,
		icon = info.iconFileID,
		isLocked = info.isLocked == true,
		isBound = info.isBound == true,
		name = info.itemName,
		hasNoValue = info.hasNoValue == true,
	}
end

-- Instant (always cached) item facts.
function A.GetItemInstant(item)
	local ok, itemID, _, _, equipLoc, icon, classID, subclassID = pcall(C_Item.GetItemInfoInstant, item)
	if not ok or not itemID then
		return nil
	end
	return { itemID = itemID, equipLoc = equipLoc or "", icon = icon, classID = classID, subclassID = subclassID }
end

-- Full item facts, or nil while the client has not loaded the item yet.
function A.GetItemInfo(item)
	local ok, name, _, quality, baseIlvl, reqLevel, _, _, maxStack, _, _, sellPrice, _, _, bindType,
		expansionID, _, isCraftingReagent = pcall(C_Item.GetItemInfo, item)
	if not ok or name == nil then
		return nil
	end
	return {
		name = name,
		quality = quality,
		baseIlvl = baseIlvl,
		reqLevel = reqLevel,
		maxStack = maxStack,
		sellPrice = sellPrice,
		bind = A.BindKind(bindType),
		expansionID = expansionID,
		isCraftingReagent = isCraftingReagent == true,
	}
end

local function location(bag, slot)
	return ItemLocation:CreateFromBagAndSlot(bag, slot)
end

function A.GetIlvl(bag, slot)
	local ok, v = pcall(function()
		return C_Item.GetCurrentItemLevel(location(bag, slot))
	end)
	if ok and type(v) == "number" and not isSecret(v) then
		return v
	end
	return nil
end

function A.IsWarboundUntilEquip(bag, slot)
	if not (C_Item and C_Item.IsBoundToAccountUntilEquip) then
		return false
	end
	local ok, v = pcall(function()
		return C_Item.IsBoundToAccountUntilEquip(location(bag, slot))
	end)
	return ok and v == true
end

-- True when the item has an upgrade track. Feature-detected; false when unknown.
function A.HasUpgradeTrack(bag, slot)
	if not (C_Item and C_Item.GetItemUpgradeInfo) then
		return false
	end
	local okLink, link = pcall(C_Container.GetContainerItemLink, bag, slot)
	if not okLink or type(link) ~= "string" then
		return false
	end
	local ok, info = pcall(C_Item.GetItemUpgradeInfo, link)
	if not ok or type(info) ~= "table" then
		return false
	end
	return (info.maxLevel or info.maxUpgradeLevel or 0) > 0 or (info.trackString or "") ~= ""
end

function A.IsOnCooldown(bag, slot)
	local ok, start, duration, enable = pcall(C_Container.GetContainerItemCooldown, bag, slot)
	if not ok or isSecret(start) or isSecret(duration) then
		return false
	end
	return enable ~= 0 and enable ~= false and (start or 0) > 0 and (duration or 0) > 1.5
end

function A.InEquipmentSet(bag, slot)
	local ok, isInSet = pcall(C_Container.GetContainerItemEquipmentSetInfo, bag, slot)
	return ok and isInSet == true
end

function A.IsUsable(itemID)
	local ok, usable = pcall(C_Item.IsUsableItem, itemID)
	return ok and usable == true
end

function A.IsToy(itemID)
	if not (C_ToyBox and C_ToyBox.GetToyInfo) then
		return false
	end
	local ok, toyID = pcall(C_ToyBox.GetToyInfo, itemID)
	return ok and toyID ~= nil
end

function A.IsQuestItem(bag, slot)
	local ok, info = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
	return ok and type(info) == "table" and (info.isQuestItem == true or info.questID ~= nil)
end

function A.RequestLoad(itemID)
	pcall(C_Item.RequestLoadItemDataByID, itemID)
end

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
---------------------------------------------------------------------------
A.CHECKS = {
	{ path = "C_Container.GetContainerNumSlots", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemInfo", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemCooldown", window = "bags", required = true },
	{ path = "C_Container.GetContainerItemEquipmentSetInfo", window = "bags", required = false },
	{ path = "C_Container.GetContainerItemQuestInfo", window = "bags", required = false },
	{ path = "C_Item.GetItemInfoInstant", window = "bags", required = true },
	{ path = "C_Item.GetItemInfo", window = "bags", required = true },
	{ path = "C_Item.GetCurrentItemLevel", window = "bags", required = true },
	{ path = "C_Item.RequestLoadItemDataByID", window = "bags", required = true },
	{ path = "C_Item.IsUsableItem", window = "bags", required = false },
	{ path = "C_Item.IsBoundToAccountUntilEquip", window = "bags", required = false },
	{ path = "C_Item.GetItemUpgradeInfo", window = "bags", required = false },
	{ path = "C_ToyBox.GetToyInfo", window = "bags", required = false },
	{ path = "C_Timer.After", window = "bags", required = true },
	{ path = "C_AddOns.IsAddOnLoaded", window = "bags", required = false },
	{ path = "ItemLocation.CreateFromBagAndSlot", window = "bags", required = true },
	{ path = "ContainerFrameItemButtonMixin", window = "bags", required = true },
	{ path = "SetItemButtonTexture", window = "bags", required = true },
	{ path = "SetItemButtonCount", window = "bags", required = true },
	{ path = "SetItemButtonQuality", window = "bags", required = true },
	{ path = "SetItemButtonDesaturated", window = "bags", required = true },
	{ path = "ToggleAllBags", window = "bags", required = true },
	{ path = "ToggleBackpack", window = "bags", required = true },
	{ path = "OpenAllBags", window = "bags", required = true },
	{ path = "CloseAllBags", window = "bags", required = true },
	{ path = "ContainerFrame1", window = "bags", required = true },
	{ path = "ContainerFrameCombinedBags", window = "bags", required = true },
	{ path = "UISpecialFrames", window = "bags", required = true },
	{ path = "Enum.BagIndex.Backpack", value = 0, window = "bags", required = true },
	{ path = "Enum.BagIndex.ReagentBag", value = 5, window = "bags", required = true },
	{ path = "Enum.BagIndex.CharacterBankTab_1", value = 6, window = "bank", required = true },
	{ path = "Enum.BagIndex.AccountBankTab_1", value = 12, window = "bank", required = true },
	{ path = "Enum.BankType.Character", value = 0, window = "bank", required = true },
	{ path = "Enum.BankType.Account", value = 2, window = "bank", required = true },
	{ path = "C_Bank.FetchPurchasedBankTabIDs", window = "bank", required = true },
	{ path = "BankFrame", window = "bank", required = true },
	{ path = "BankFrame.GetActiveBankType", window = "bank", required = true },
	{ path = "BankFrame.TabSystem", window = "bank", required = true },
	{ path = "Enum.ItemClass", window = "bags", required = false },
	{ path = "Enum.ItemBind", window = "bags", required = false },
	{ path = "Enum.AddOnRestrictionType", window = "bags", required = false },
	{ path = "C_ChallengeMode.IsChallengeModeActive", window = "bags", required = false },
	{ path = "C_RestrictedActions.IsAddOnRestrictionActive", window = "bags", required = false },
}
```

- [ ] **Step 4: Teach the mock about containers** (`spec/mock_adapter.lua`)

Edit 1: inside `M.New`, find the line `return m`. It is the last line before the `end` that closes `M.New`. Replace it with these two lines:

```lua
	M.AddContainers(m)
	return m
```

Edit 2: insert this block between the `end` that closes `M.New` and the final `return M` line:

```lua
-- Fake bags and items. Fixture helpers:
--   m.AddItem(itemID, { name, classID, subclassID, equipLoc, quality, ilvl, reqLevel,
--                       maxStack, bind, isCraftingReagent, usable, toy, pending })
--   m.SetBagSize(bag, n)
--   m.Put(bag, slot, itemID, count, { link, isLocked, isBound, isWUE, onCooldown,
--                                    inSet, upgrade, quest, ilvl })
--   m.Clear(bag, slot)
function M.AddContainers(m)
	m.bagIDs = { bags = { 0, 1, 2, 3, 4, 5 }, bank = {}, warband = {} }
	m.sizes = {}
	m.slots = {}
	m.items = {}
	m.loadRequests = {}

	function m.AddItem(itemID, def)
		m.items[itemID] = def
	end

	function m.SetBagSize(bag, n)
		m.sizes[bag] = n
		m.slots[bag] = m.slots[bag] or {}
	end

	function m.Put(bag, slot, itemID, count, extra)
		local s = extra or {}
		s.itemID = itemID
		s.count = count or 1
		m.slots[bag] = m.slots[bag] or {}
		m.slots[bag][slot] = s
	end

	function m.Clear(bag, slot)
		if m.slots[bag] then
			m.slots[bag][slot] = nil
		end
	end

	local function slotOf(bag, slot)
		return m.slots[bag] and m.slots[bag][slot]
	end

	local function itemOf(itemID)
		return m.items[itemID] or {}
	end

	function m.GetBagIDs(kind)
		local out = {}
		for i, id in ipairs(m.bagIDs[kind] or {}) do
			out[i] = id
		end
		return out
	end

	function m.NumSlots(bag)
		return m.sizes[bag] or 0
	end

	function m.GetSlot(bag, slot)
		local s = slotOf(bag, slot)
		if not s then
			return nil
		end
		local it = itemOf(s.itemID)
		return {
			bag = bag,
			slot = slot,
			itemID = s.itemID,
			link = s.link or ("item:" .. s.itemID),
			count = s.count,
			quality = it.quality,
			icon = s.itemID,
			isLocked = s.isLocked == true,
			isBound = s.isBound == true,
			name = (not it.pending) and it.name or nil,
			hasNoValue = false,
		}
	end

	function m.GetItemInstant(itemID)
		local it = m.items[itemID]
		if not it then
			return nil
		end
		return { itemID = itemID, equipLoc = it.equipLoc or "", icon = itemID, classID = it.classID, subclassID = it.subclassID }
	end

	function m.GetItemInfo(itemID)
		local it = m.items[itemID]
		if not it or it.pending then
			return nil
		end
		return {
			name = it.name,
			quality = it.quality,
			baseIlvl = it.ilvl,
			reqLevel = it.reqLevel or 0,
			maxStack = it.maxStack or 1,
			sellPrice = 0,
			bind = it.bind or "none",
			expansionID = 0,
			isCraftingReagent = it.isCraftingReagent == true,
		}
	end

	function m.GetIlvl(bag, slot)
		local s = slotOf(bag, slot)
		if not s then
			return nil
		end
		local it = itemOf(s.itemID)
		if it.pending then
			return nil
		end
		return s.ilvl or it.ilvl
	end

	function m.IsWarboundUntilEquip(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.isWUE == true
	end

	function m.HasUpgradeTrack(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.upgrade == true
	end

	function m.IsOnCooldown(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.onCooldown == true
	end

	function m.InEquipmentSet(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.inSet == true
	end

	function m.IsUsable(itemID)
		return itemOf(itemID).usable == true
	end

	function m.IsToy(itemID)
		return itemOf(itemID).toy == true
	end

	function m.IsQuestItem(bag, slot)
		local s = slotOf(bag, slot)
		return s ~= nil and s.quest == true
	end

	function m.RequestLoad(itemID)
		m.loadRequests[#m.loadRequests + 1] = itemID
	end
end
```

- [ ] **Step 5: Write `SwagBag/Core/Checks.lua`**

```lua
-- SwagBag feature checks (spec 10.3). The list of paths lives in Adapter.CHECKS so
-- that no other file names a C_* API. A failed REQUIRED check turns on Safe Mode
-- for its window before anything is shown; optional checks only degrade features.
local _, SB = ...

local Checks = {}
SB.Checks = Checks

-- Returns an ordered list of { name, pass, detail, required, window }.
function Checks.Run()
	local A, L = SB.Adapter, SB.L
	local results = {}
	for i, c in ipairs(A.CHECKS) do
		local v = A.Resolve(c.path)
		local pass, detail
		if c.value ~= nil then
			pass = v == c.value
			detail = pass and tostring(v) or L.CHECK_EXPECTED:format(tostring(c.value), tostring(v))
		else
			pass = v ~= nil
			detail = pass and L.CHECK_PRESENT or L.CHECK_MISSING
		end
		results[i] = { name = c.path, pass = pass, detail = detail, required = c.required, window = c.window }
	end
	Checks.last = results
	return results
end

-- Failed results, optionally only required ones and/or one window.
function Checks.Failed(results, requiredOnly, window)
	local out = {}
	for _, r in ipairs(results or Checks.last or {}) do
		if not r.pass and (not requiredOnly or r.required) and (window == nil or r.window == window) then
			out[#out + 1] = r
		end
	end
	return out
end

-- Turn on Safe Mode for each window with a failed required check.
-- Returns the list of windows that were switched.
function Checks.Apply(results)
	local switched = {}
	for _, window in ipairs(SB.SafeMode.WINDOWS) do
		if #Checks.Failed(results, true, window) > 0 and SB.SafeMode.Enable(window, "check") then
			switched[#switched + 1] = window
		end
	end
	return switched
end

-- Chat lines for /swagbag check: one PASS/FAIL line per check, then a summary.
function Checks.Lines(results)
	local L = SB.L
	local lines, passed, failed, failedRequired = {}, 0, 0, 0
	for _, r in ipairs(results) do
		if r.pass then
			passed = passed + 1
			lines[#lines + 1] = L.CHECK_PASS_LINE:format(r.name)
		else
			failed = failed + 1
			if r.required then
				failedRequired = failedRequired + 1
			end
			lines[#lines + 1] = L.CHECK_FAIL_LINE:format(r.name, r.detail, r.required and "" or L.CHECK_OPTIONAL)
		end
	end
	lines[#lines + 1] = L.CHECK_SUMMARY:format(passed, failed, failedRequired)
	return lines
end
```

- [ ] **Step 6: Add it to the TOC** (append to the end of `# Core`): `Core/Checks.lua`

- [ ] **Step 7: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/checks_spec.lua`
Expected: `7 passed, 0 failed`

- [ ] **Step 8: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (8 files)`, `56 passed, 0 failed`, `ALL CHECKS PASSED`. Stage 3 must print nothing: all `C_*`/`Enum` names are inside `Core/Adapter.lua`.

- [ ] **Step 9: Commit**

```bash
git add SwagBag/Core/Adapter.lua SwagBag/Core/Checks.lua SwagBag/SwagBag.toc spec/mock_adapter.lua spec/helpers/globals.lua spec/checks_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add container/item Adapter API, feature check list and Checks" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Slash dispatcher, help, blocked-action log, report builder

**Files:**
- Create: `SwagBag/Core/Blocked.lua`, `SwagBag/Core/Report.lua`, `SwagBag/Core/Slash.lua`, `spec/slash_spec.lua`, `spec/report_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Core`: `Core/Blocked.lua`, `Core/Report.lua`, `Core/Slash.lua`)
- Test: `spec/slash_spec.lua`, `spec/report_spec.lua`

**Interfaces:**
- Consumes: `SB.On` (Task 4), `SB.ErrorTrap.Run/Recent/MAX` (Task 3), `SB.SafeMode.Describe` (Task 3), `SB.Checks.Failed/last` (Task 6), `SB.Config.db` (Task 5), `SB.Adapter.BuildInfo/Date/AddOnState/InCombat` (Tasks 2 and 6). `SB.Buttons.stats` is read only if present (Task 11).
- Produces:
  - `SB.Slash.Register(name, help, fn, window)`. `fn(rest)` returns a string, a list of strings, or nil. The window defaults to `"none"`.
  - `SB.Slash.Dispatch(msg)`, `SB.Slash.order` and `SB.Slash.commands`. The `help` command is built in. `/swagbag` is wired to `SlashCmdList.SWAGBAG`.
  - `SB.Blocked.list`: entries `{time, event, func, combat}`, last 20, only those naming SwagBag.
  - `SB.Report.Build()` returns the report text (spec §10.4 layout plus a "Blocked actions" line). `SB.Report.Hash(v)` returns 8 hex digits and does not depend on key order.

- [ ] **Step 1: Write the failing tests**

`spec/slash_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Slash.lua",
}

describe("Slash", function()
	local SB, A, Slash
	before_each(function()
		SB = Loader.New(FILES)
		A, Slash = SB.Adapter, SB.Slash
	end)

	it("an unknown command says so", function()
		Slash.Dispatch("frobnicate")
		assert.same({ 'Unknown command "frobnicate". Type /swagbag help for the list.' }, A.Lines())
	end)

	it("/swagbag with no command explains there is no settings window yet", function()
		Slash.Dispatch("   ")
		assert.same({ SB.L.NO_SETTINGS_YET }, A.Lines())
	end)

	it("prints a string, a list, or Done. when a command returns nothing", function()
		Slash.Register("one", "h", function() return "single" end)
		Slash.Register("many", "h", function() return { "a", "b" } end)
		Slash.Register("quiet", "h", function() end)
		Slash.Dispatch("one")
		Slash.Dispatch("many")
		Slash.Dispatch("quiet")
		assert.same({ "single", "a", "b", "Done." }, A.Lines())
	end)

	it("a failing command prints a pointer to the report and does not flip Safe Mode", function()
		Slash.Register("boom", "h", function() error("bad") end)
		Slash.Dispatch("boom")
		assert.same({ SB.L.CMD_FAILED }, A.Lines())
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal("slash:boom", SB.ErrorTrap.Recent()[1].label)
	end)

	it("matches the command case-insensitively and passes the trimmed rest", function()
		local got
		Slash.Register("echo", "h", function(rest) got = rest return rest end)
		Slash.Dispatch("  ECHO   ilvl>250 & boe  ")
		assert.equal("ilvl>250 & boe", got)
	end)

	it("help lists every command in registration order", function()
		Slash.Register("zeta", "last one", function() end)
		Slash.Dispatch("help")
		assert.same({ "Commands:", "/swagbag help - show this list", "/swagbag zeta - last one" }, A.Lines())
	end)
end)
```

`spec/report_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Blocked.lua", "SwagBag/Core/Report.lua",
}

describe("Report", function()
	local SB, A
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
	end)

	it("builds the full report for a clean session", function()
		SB.Checks.last = {}
		local expected = table.concat({
			"SwagBag " .. SB.VERSION .. " | WoW 12.1.0 (69933) | enUS | 2026-10-01 21:03",
			"Safe Mode: bags=off bank=off",
			"Failed checks: none",
			"Errors (last 10):",
			" none",
			"Blocked actions: none",
			"Bag-related addons: Auctionator (not loaded), Syndicator (not loaded)",
			"Settings hash: " .. SB.Report.Hash({}) .. "  Schema: 1  Buttons: 0 (0 ms)",
		}, "\n")
		assert.equal(expected, SB.Report.Build())
	end)

	it("lists Safe Mode reasons, failed checks and errors with indented stacks", function()
		SB.Checks.last = {
			{ name = "BankFrame.TabSystem", pass = false, detail = "missing", required = true, window = "bank" },
			{ name = "C_Timer.After", pass = true, detail = "present", required = true, window = "bags" },
		}
		A.combat = true
		A.Stack = function() return "line one\nline two" end
		SB.ErrorTrap.Run("Views.Bank.Refresh", "bank", function() error("attempt to index nil", 0) end)
		local text = SB.Report.Build()
		assert.truthy(text:find("Safe Mode: bags=off bank=on (auto, 21:03)", 1, true))
		assert.truthy(text:find("Failed checks: BankFrame.TabSystem (missing)", 1, true))
		local expected = " 2026-10-01 21:03:07 [bank, in combat] Views.Bank.Refresh: attempt to index nil\n"
			.. "    line one\n    line two"
		assert.truthy(text:find(expected, 1, true))
	end)

	it("shows loaded bag addons with versions and hides other unloaded ones", function()
		SB.Checks.last = {}
		A.addons = { Auctionator = "12.1.3", Bagnon = "10.2", AdiBags = false }
		local text = SB.Report.Build()
		assert.truthy(text:find("Bag-related addons: Auctionator 12.1.3, Syndicator (not loaded), Bagnon 10.2\n", 1, true))
		assert.falsy(text:find("AdiBags", 1, true))
	end)

	it("lists SwagBag's blocked actions and ignores other addons'", function()
		SB.Checks.last = {}
		A.combat = true
		SB.eventFrame:Fire("ADDON_ACTION_BLOCKED", "SwagBag", "UseContainerItem()")
		SB.eventFrame:Fire("ADDON_ACTION_FORBIDDEN", "OtherAddon", "CastSpellByName()")
		local text = SB.Report.Build()
		assert.truthy(text:find("Blocked actions: UseContainerItem() at 21:03:07, in combat\n", 1, true))
		assert.falsy(text:find("CastSpellByName", 1, true))
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
		local h2 = SB.Report.Hash({ x = "a", bags = { columns = 12 } })
		local h3 = SB.Report.Hash({ bags = { columns = 10 }, x = "a" })
		assert.equal(h1, h2)
		assert.truthy(h1 ~= h3)
		assert.truthy(h1:match("^%x%x%x%x%x%x%x%x$"))
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/slash_spec.lua spec/report_spec.lua`
Expected: `0 passed, 11 failed`. The slash failures contain `cannot open SwagBag/Core/Slash.lua`. The report failures contain `cannot open SwagBag/Core/Blocked.lua`.

- [ ] **Step 3: Write `SwagBag/Core/Blocked.lua`**

```lua
-- SwagBag blocked-action log: every ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN
-- that names SwagBag is kept (last 20) and shown in /swagbag report, so in-game
-- checks V1, V3 and V9 can be confirmed from the report instead of from memory.
local ADDON, SB = ...

local Blocked = { list = {}, MAX = 20 }
SB.Blocked = Blocked

local function onBlocked(event, addon, func)
	if addon ~= ADDON then
		return
	end
	local A = SB.Adapter
	local list = Blocked.list
	list[#list + 1] = { time = A.Date("%H:%M:%S"), event = event, func = tostring(func), combat = A.InCombat() }
	while #list > Blocked.MAX do
		table.remove(list, 1)
	end
end

SB.On("ADDON_ACTION_BLOCKED", onBlocked, "none")
SB.On("ADDON_ACTION_FORBIDDEN", onBlocked, "none")
```

- [ ] **Step 4: Write `SwagBag/Core/Report.lua`**

```lua
-- SwagBag report (spec 10.4): the text the user pastes into Claude Code.
-- Report.Build() is pure (reads module state through SB.*); UI/ReportBox.lua shows it.
local _, SB = ...

local Report = {}
SB.Report = Report

Report.ADDONS_ALWAYS = { "Auctionator", "Syndicator" }
Report.ADDONS_IF_LOADED = {
	"Baganator", "Bagnon", "AdiBags", "ArkInventory", "BetterBags", "Sorted", "ElvUI",
	"EllesmereUIBags", "EnhanceQoLBags", "TradeSkillMaster", "Pawn", "CanIMogIt",
}

local function serialize(v, out)
	if type(v) == "table" then
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		out[#out + 1] = "{"
		for _, k in ipairs(keys) do
			out[#out + 1] = tostring(k) .. "="
			serialize(v[k], out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = tostring(v)
	end
end

-- 8-hex-digit djb2 hash of a value, independent of table key order.
function Report.Hash(v)
	local parts = {}
	serialize(v, parts)
	local s = table.concat(parts)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 4294967296
	end
	return string.format("%08x", h)
end

local function addonList()
	local A, L = SB.Adapter, SB.L
	local out = {}
	for _, name in ipairs(Report.ADDONS_ALWAYS) do
		local loaded, version = A.AddOnState(name)
		out[#out + 1] = loaded and (name .. " " .. tostring(version or "?")) or L.REPORT_NOT_LOADED:format(name)
	end
	for _, name in ipairs(Report.ADDONS_IF_LOADED) do
		local loaded, version = A.AddOnState(name)
		if loaded then
			out[#out + 1] = name .. " " .. tostring(version or "?")
		end
	end
	return out
end

function Report.Build()
	local A, L = SB.Adapter, SB.L
	local build = A.BuildInfo()
	local lines = {}
	lines[#lines + 1] = L.REPORT_HEADER:format(SB.VERSION, tostring(build.version), tostring(build.build),
		tostring(build.locale), A.Date("%Y-%m-%d %H:%M"))
	lines[#lines + 1] = L.REPORT_SAFE:format(SB.SafeMode.Describe("bags"), SB.SafeMode.Describe("bank"))

	local failed = {}
	for _, r in ipairs(SB.Checks.Failed(SB.Checks.last or {})) do
		failed[#failed + 1] = r.name .. " (" .. r.detail .. ")"
	end
	lines[#lines + 1] = L.REPORT_FAILED_CHECKS:format(#failed > 0 and table.concat(failed, ", ") or L.REPORT_NONE)

	local errors = SB.ErrorTrap.Recent()
	lines[#lines + 1] = L.REPORT_ERRORS:format(SB.ErrorTrap.MAX)
	if #errors == 0 then
		lines[#lines + 1] = " " .. L.REPORT_NONE
	end
	for _, e in ipairs(errors) do
		lines[#lines + 1] = L.REPORT_ERROR_LINE:format(tostring(e.time), tostring(e.window), e.combat and L.REPORT_IN_COMBAT or "",
			tostring(e.label), tostring(e.message))
		for stackLine in tostring(e.stack or ""):gmatch("[^\n]+") do
			lines[#lines + 1] = "    " .. stackLine
		end
	end

	local blocked = {}
	for _, b in ipairs(SB.Blocked and SB.Blocked.list or {}) do
		blocked[#blocked + 1] = L.REPORT_BLOCKED_ITEM:format(b.func, b.time, b.combat and L.REPORT_IN_COMBAT or "")
	end
	lines[#lines + 1] = L.REPORT_BLOCKED:format(#blocked > 0 and table.concat(blocked, ", ") or L.REPORT_NONE)
	lines[#lines + 1] = L.REPORT_ADDONS:format(table.concat(addonList(), ", "))
	local db = SB.Config.db or {}
	local stats = SB.Buttons and SB.Buttons.stats or {}
	lines[#lines + 1] = L.REPORT_SETTINGS:format(Report.Hash(db.settings or {}), db.schemaVersion or 0, stats.count or 0,
		math.floor(stats.createMs or 0))
	return table.concat(lines, "\n")
end
```

- [ ] **Step 5: Write `SwagBag/Core/Slash.lua`**

```lua
-- SwagBag slash commands. P2: every command gives feedback. A command function
-- returns its feedback (a string or a list of strings); returning nothing prints
-- "Done.", and an error prints a pointer to /swagbag report. Silence is impossible.
local _, SB = ...

local Slash = { commands = {}, order = {} }
SB.Slash = Slash

-- window: Safe Mode window an error in this command may flip; default "none".
function Slash.Register(name, help, fn, window)
	name = name:lower()
	if not Slash.commands[name] then
		Slash.order[#Slash.order + 1] = name
	end
	Slash.commands[name] = { help = help, fn = fn, window = window or "none" }
end

local function say(feedback)
	if type(feedback) == "table" then
		for _, line in ipairs(feedback) do
			SB.Print(line)
		end
	elseif feedback ~= nil then
		SB.Print(feedback)
	else
		SB.Print(SB.L.CMD_DONE)
	end
end

function Slash.Dispatch(msg)
	local L = SB.L
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" then
		SB.Print(L.NO_SETTINGS_YET)
		return
	end
	local c = Slash.commands[cmd]
	if not c then
		SB.Print(L.UNKNOWN_COMMAND:format(cmd))
		return
	end
	local ok, feedback = SB.ErrorTrap.Run("slash:" .. cmd, c.window, c.fn, rest)
	if not ok then
		SB.Print(L.CMD_FAILED)
		return
	end
	say(feedback)
end

Slash.Register("help", SB.L.HELP_HELP, function()
	local L = SB.L
	local lines = { L.HELP_HEADER }
	for _, name in ipairs(Slash.order) do
		lines[#lines + 1] = L.HELP_LINE:format(name, Slash.commands[name].help)
	end
	return lines
end)

if SlashCmdList then
	SLASH_SWAGBAG1 = "/swagbag"
	SlashCmdList.SWAGBAG = function(msg)
		Slash.Dispatch(msg)
	end
end
```

- [ ] **Step 6: Add the three files to the TOC** (append to the end of `# Core`)

```
Core/Blocked.lua
Core/Report.lua
Core/Slash.lua
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/slash_spec.lua spec/report_spec.lua`
Expected: `11 passed, 0 failed`

- [ ] **Step 8: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (11 files)`, `67 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 9: Commit**

```bash
git add SwagBag/Core/Blocked.lua SwagBag/Core/Report.lua SwagBag/Core/Slash.lua SwagBag/SwagBag.toc spec/slash_spec.lua spec/report_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add /swagbag dispatcher with guaranteed feedback, blocked-action log and report builder" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Commands, start-up wiring, report window, install, and first in-game session (D2)

**Files:**
- Create: `SwagBag/Core/Commands.lua`, `SwagBag/Core/Boot.lua`, `SwagBag/UI/ReportBox.lua`, `scripts/install.sh`, `spec/commands_spec.lua`, `spec/boot_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append `Core/Commands.lua` to `# Core`, `UI/ReportBox.lua` to `# UI`, and `Core/Boot.lua` to `# Start-up (keep last)`)
- Test: `spec/commands_spec.lua`, `spec/boot_spec.lua`, plus in-game session D2

**Interfaces:**
- Consumes: everything from Tasks 2–7.
- Produces:
  - Commands: `/swagbag safe [on|off|bags|bank]`, `report`, `check`, `reset`, `debug error [bags|bank]` and `debug v1` (the last answers only once Task 19 adds `SB.DebugV1`).
  - `SB.Commands.SetSafe(window, on)` returns a line. `SB.Commands.DoReset()`.
  - `SB.ReportBox.Show(text)`.
  - Start-up events: `ADDON_LOADED` sets up Config and saved globals and attaches the error ring. `PLAYER_LOGIN` runs Checks.Run + Apply, schema Safe Mode, remembered manual Safe Mode, and the loaded line, then emits **`SB_LOGIN`**. Later modules start on `SB_LOGIN`.

- [ ] **Step 1: Write the failing tests**

`spec/commands_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Report.lua", "SwagBag/Core/Slash.lua", "SwagBag/Core/Commands.lua",
}

describe("Commands", function()
	local SB, A, SM, shown
	before_each(function()
		SB = Loader.New(FILES)
		A, SM = SB.Adapter, SB.SafeMode
		SB.Config.Init(nil, nil)
		shown = nil
		SB.ReportBox = { Show = function(text) shown = text end }
	end)

	it("safe with no argument prints both windows' state", function()
		SB.Slash.Dispatch("safe")
		assert.same({ "Safe Mode: bags=off bank=off" }, A.Lines())
	end)

	it("safe bags toggles bags, remembers it, and confirms each time", function()
		SB.Slash.Dispatch("safe bags")
		assert.truthy(SM.IsOn("bags"))
		assert.equal(true, SB.Config.Get("safeMode.bags"))
		SB.Slash.Dispatch("safe bags")
		assert.falsy(SM.IsOn("bags"))
		assert.equal(false, SB.Config.Get("safeMode.bags"))
		assert.same({
			"Safe Mode is ON for bags: Blizzard's frames are used. Type /swagbag safe off to switch back.",
			"Safe Mode is OFF for bags: SwagBag handles them again.",
		}, A.Lines())
	end)

	it("safe on switches both windows with one line each", function()
		SB.Slash.Dispatch("safe on")
		assert.truthy(SM.IsOn("bags"))
		assert.truthy(SM.IsOn("bank"))
		assert.equal(2, #A.printed)
		SB.Slash.Dispatch("safe on")
		assert.equal("Safe Mode was already ON for bank.", A.Lines()[4])
	end)

	it("safe with a wrong argument explains the usage", function()
		SB.Slash.Dispatch("safe maybe")
		assert.same({ SB.L.SAFE_USAGE }, A.Lines())
	end)

	it("debug error flips bags to Safe Mode, prints the error line, then confirms", function()
		SB.Slash.Dispatch("debug error")
		assert.truthy(SM.IsOn("bags"))
		assert.same({ SB.L.ERROR_SWITCHED, "Injected a test error into the bags path." }, A.Lines())
		local e = SB.ErrorTrap.Recent()[1]
		assert.equal("debug:error", e.label)
		assert.equal(SB.L.DEBUG_ERROR_TEXT, e.message)
	end)

	it("debug error bank flips only the bank", function()
		SB.Slash.Dispatch("debug error bank")
		assert.truthy(SM.IsOn("bank"))
		assert.falsy(SM.IsOn("bags"))
	end)

	it("debug v1 hands over to the V1 strip, or explains usage without it", function()
		SB.Slash.Dispatch("debug v1")
		assert.same({ SB.L.DEBUG_USAGE }, A.Lines())
		SB.DebugV1 = { Toggle = function() return "strip toggled" end }
		SB.Slash.Dispatch("debug v1")
		assert.equal("strip toggled", A.Lines()[2])
	end)

	it("check prints one line per check plus a summary", function()
		SB.Slash.Dispatch("check")
		assert.equal(#A.CHECKS + 1, #A.printed)
		assert.truthy(A.Lines()[#A.printed]:find("^Checks: 0 passed"))
	end)

	it("report opens the box with the built report and says how to copy it", function()
		SB.Slash.Dispatch("report")
		assert.truthy(shown:find("^SwagBag "))
		assert.same({ SB.L.REPORT_OPENED }, A.Lines())
	end)

	it("DoReset installs fresh saved tables and confirms", function()
		SB.Config.Set("bags.columns", 9)
		SB.Commands.DoReset()
		assert.equal(SB.Config.db, SwagBagDB)
		assert.equal(SB.Config.charDB, SwagBagCharDB)
		assert.equal(12, SB.Config.Get("bags.columns"))
		assert.same({ SB.L.RESET_DONE }, A.Lines())
	end)
end)
```

`spec/boot_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Globals = dofile("spec/helpers/globals.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Boot.lua",
}

describe("Boot", function()
	local SB, A, loginSeen
	before_each(function()
		SwagBagDB, SwagBagCharDB = nil, nil
		SB = Loader.New(FILES)
		A = SB.Adapter
		A.globals = Globals.AllPresent(A)
		loginSeen = false
		SB.On("SB_LOGIN", function() loginSeen = true end)
	end)

	after_each(function()
		SwagBagDB, SwagBagCharDB = nil, nil
	end)

	it("ADDON_LOADED for another addon is ignored", function()
		SB.eventFrame:Fire("ADDON_LOADED", "Auctionator")
		assert.is_nil(SwagBagDB)
	end)

	it("creates the saved tables and attaches the error ring", function()
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		assert.equal(1, SwagBagDB.schemaVersion)
		assert.equal(SwagBagDB.errors, SB.ErrorTrap.buffer)
	end)

	it("login runs checks, prints the loaded line, and emits SB_LOGIN", function()
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.same({ "v" .. SB.VERSION .. " loaded. Type /swagbag help for commands." }, A.Lines())
		assert.truthy(loginSeen)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("a failed required check at login puts that window in Safe Mode", function()
		A.globals.ContainerFrameCombinedBags = nil
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.equal("check", SB.SafeMode.state.bags.reason)
	end)

	it("a newer schema is left untouched, both windows go to Safe Mode, one warning", function()
		local saved = { schemaVersion = 7 }
		SwagBagDB = saved
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.equal(saved, SwagBagDB)
		assert.same({ schemaVersion = 7 }, saved)
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.equal(SB.L.NEWER_SCHEMA, A.Lines()[1])
	end)

	it("a remembered manual Safe Mode is restored at login", function()
		SwagBagDB = { schemaVersion = 1, settings = { safeMode = { bank = true } }, errors = {}, backups = {} }
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.equal("manual", SB.SafeMode.state.bank.reason)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("a failed migration is reported in chat and recorded for /swagbag report", function()
		SB.Config.CURRENT = 2
		SB.Config.migrations[2] = function() error("bad step") end
		SB.Config.charMigrations[2] = function() end
		SwagBagDB = { schemaVersion = 1, settings = {}, errors = {}, backups = {} }
		SB.eventFrame:Fire("ADDON_LOADED", "SwagBag")
		SB.eventFrame:Fire("PLAYER_LOGIN")
		assert.equal(SB.L.MIGRATION_FAILED, A.Lines()[1])
		assert.equal("Config.migrate", SB.ErrorTrap.Recent()[1].label)
		assert.truthy(SwagBagDB.backups.v1)
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/commands_spec.lua spec/boot_spec.lua`
Expected: `0 passed, 17 failed`. The failures contain `cannot open SwagBag/Core/Commands.lua` or `cannot open SwagBag/Core/Boot.lua`.

- [ ] **Step 3: Write `SwagBag/Core/Commands.lua`**

```lua
-- SwagBag week-1 slash commands: safe, report, check, reset, debug.
-- (help lives in Core/Slash.lua; search is registered by UI/Search.lua.)
local _, SB = ...

local L = SB.L
local Slash = SB.Slash
local Commands = {}
SB.Commands = Commands

local function windowName(window)
	return window == "bank" and L.WINDOW_BANK or L.WINDOW_BAGS
end

-- Switch one window's Safe Mode and remember the choice. Returns the feedback line.
function Commands.SetSafe(window, on)
	local SM = SB.SafeMode
	local changed
	if on then
		changed = SM.Enable(window, "manual")
	else
		changed = SM.Disable(window)
	end
	SB.Config.Set("safeMode." .. window, on)
	if changed then
		return (on and L.SAFE_NOW_ON or L.SAFE_NOW_OFF):format(windowName(window))
	end
	return (on and L.SAFE_ALREADY_ON or L.SAFE_ALREADY_OFF):format(windowName(window))
end

Slash.Register("safe", L.HELP_SAFE, function(arg)
	local SM = SB.SafeMode
	arg = arg:lower()
	if arg == "" then
		return L.SAFE_STATUS:format(SM.Describe("bags"), SM.Describe("bank"))
	elseif arg == "on" or arg == "off" then
		return { Commands.SetSafe("bags", arg == "on"), Commands.SetSafe("bank", arg == "on") }
	elseif arg == "bags" or arg == "bank" then
		return Commands.SetSafe(arg, not SM.IsOn(arg))
	end
	return L.SAFE_USAGE
end)

Slash.Register("report", L.HELP_REPORT, function()
	SB.ReportBox.Show(SB.Report.Build())
	return L.REPORT_OPENED
end)

Slash.Register("check", L.HELP_CHECK, function()
	return SB.Checks.Lines(SB.Checks.Run())
end)

-- Called by the confirmation dialog. Swaps in fresh SavedVariables tables.
function Commands.DoReset()
	SwagBagDB, SwagBagCharDB = SB.Config.Reset()
	SB.ErrorTrap.Attach(SwagBagDB.errors)
	SB.Print(L.RESET_DONE)
end

if StaticPopupDialogs then
	StaticPopupDialogs.SWAGBAG_RESET = {
		text = L.RESET_CONFIRM,
		button1 = YES,
		button2 = NO,
		OnAccept = SB.ErrorTrap.Guard("reset", Commands.DoReset, "none"),
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
end

Slash.Register("reset", L.HELP_RESET, function()
	StaticPopup_Show("SWAGBAG_RESET")
	return L.RESET_ASKED
end)

Slash.Register("debug", L.HELP_DEBUG, function(arg)
	local what, window = arg:lower():match("^(%S*)%s*(%S*)")
	if what == "v1" and SB.DebugV1 then
		return SB.DebugV1.Toggle()
	end
	if what ~= "error" then
		return L.DEBUG_USAGE
	end
	window = window == "bank" and "bank" or "bags"
	SB.ErrorTrap.Run("debug:error", window, function()
		error(L.DEBUG_ERROR_TEXT, 0)
	end)
	return L.DEBUG_ERROR_DONE:format(windowName(window))
end)
```

- [ ] **Step 4: Write `SwagBag/Core/Boot.lua`**

```lua
-- SwagBag start-up. ADDON_LOADED: settings + saved error ring.
-- PLAYER_LOGIN: feature checks, Safe Mode decisions, then SB_LOGIN for modules.
local ADDON, SB = ...

local L = SB.L

SB.On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then
		return
	end
	local status = SB.Config.Init(SwagBagDB, SwagBagCharDB)
	if status == "newer" then
		return -- never touch a newer schema; Safe Mode is switched on at login
	end
	SwagBagDB, SwagBagCharDB = SB.Config.db, SB.Config.charDB
	SB.ErrorTrap.Attach(SwagBagDB.errors)
	if status == "reset" then
		SB.ErrorTrap.OnError("Config.migrate", "none", tostring(SB.Config.lastError), "")
	end
end, "none")

SB.On("PLAYER_LOGIN", function()
	local Config, SM = SB.Config, SB.SafeMode
	SB.Checks.Apply(SB.Checks.Run())
	if Config.status == "newer" then
		SM.Enable("bags", "schema")
		SM.Enable("bank", "schema")
		SB.Print(L.NEWER_SCHEMA)
	elseif Config.status == "reset" then
		SB.Print(L.MIGRATION_FAILED)
	end
	for _, window in ipairs(SM.WINDOWS) do
		if Config.Get("safeMode." .. window) then
			SM.Enable(window, "manual")
		end
	end
	SB.Print(L.LOADED:format(SB.VERSION))
	SB.Emit("SB_LOGIN")
end, "none")
```

- [ ] **Step 5: Write `SwagBag/UI/ReportBox.lua`** (WoW-only; checked in game in D2)

```lua
-- SwagBag report box: one read-only, copyable, multi-line EditBox (spec 10.4).
-- Text is selected on show and on focus; typing restores it; Esc closes.
local _, SB = ...

local Box = {}
SB.ReportBox = Box

local function build()
	local Guard = SB.ErrorTrap.Guard
	local f = CreateFrame("Frame", "SwagBagReportFrame", UIParent, "BackdropTemplate")
	f:SetSize(640, 420)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
	f:SetBackdropBorderColor(0.3, 0.8, 0.6, 1)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText(SB.L.REPORT_TITLE)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -30)
	scroll:SetPoint("BOTTOMRIGHT", -30, 10)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(590)
	edit:SetScript("OnEscapePressed", Guard("report.escape", function()
		f:Hide()
	end, "none"))
	edit:SetScript("OnTextChanged", Guard("report.textChanged", function(self, userInput)
		if userInput then
			self:SetText(Box.text or "")
			self:HighlightText()
		end
	end, "none"))
	edit:SetScript("OnEditFocusGained", Guard("report.focus", function(self)
		self:HighlightText()
	end, "none"))
	scroll:SetScrollChild(edit)
	f.edit = edit

	table.insert(UISpecialFrames, "SwagBagReportFrame")
	f:Hide()
	return f
end

function Box.Show(text)
	Box.frame = Box.frame or build()
	Box.text = text
	Box.frame.edit:SetText(text)
	Box.frame:Show()
	Box.frame.edit:SetFocus()
	Box.frame.edit:HighlightText()
end
```

- [ ] **Step 6: Update the TOC**

Append `Core/Commands.lua` to the end of `# Core`. Append `UI/ReportBox.lua` under `# UI`. Append `Core/Boot.lua` under `# Start-up (keep last)`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/commands_spec.lua spec/boot_spec.lua`
Expected: `17 passed, 0 failed`

- [ ] **Step 8: Write the installer** (`scripts/install.sh`), then `chmod +x scripts/install.sh`

```bash
#!/usr/bin/env bash
# Link the SwagBag addon folder into World of Warcraft (retail).
#   scripts/install.sh            show the plan, ask, then create the symlink
#   scripts/install.sh --yes      same, without asking
#   scripts/install.sh --copy     copy the folder instead of symlinking
#   scripts/install.sh --remove   remove the symlink/copy (SavedVariables are kept)
# Override the game location with:  WOW_DIR="/path/to/World of Warcraft" scripts/install.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/SwagBag"
NAME="SwagBag"
MODE="link"
ASSUME_YES=0

for a in "$@"; do
	case "$a" in
		--yes|-y) ASSUME_YES=1 ;;
		--copy) MODE="copy" ;;
		--remove) MODE="remove" ;;
		-h|--help) sed -n '2,7p' "$0"; exit 0 ;;
		*) echo "Unknown option: $a"; exit 2 ;;
	esac
done

CANDIDATES=()
[ -n "${WOW_DIR:-}" ] && CANDIDATES+=("$WOW_DIR")
CANDIDATES+=("/Applications/World of Warcraft" "$HOME/Applications/World of Warcraft")
WOW=""
for c in "${CANDIDATES[@]}"; do
	if [ -d "$c/_retail_/Interface/AddOns" ]; then WOW="$c"; break; fi
done
if [ -z "$WOW" ]; then
	echo "Could not find '<World of Warcraft>/_retail_/Interface/AddOns'. Looked in: ${CANDIDATES[*]}"
	exit 1
fi
ADDONS="$WOW/_retail_/Interface/AddOns"
DEST="$ADDONS/$NAME"

if [ ! -f "$SRC/$NAME.toc" ]; then echo "Addon not found at: $SRC"; exit 1; fi

echo "Game AddOns folder : $ADDONS"
echo "SwagBag source     : $SRC"
case "$MODE" in
	link)   echo "Plan               : create symlink  $DEST  ->  $SRC" ;;
	copy)   echo "Plan               : copy folder to  $DEST" ;;
	remove) echo "Plan               : remove          $DEST  (SavedVariables are NOT touched)" ;;
esac

if [ -e "$ADDONS/SwagBagSpikes" ]; then
	echo "WARNING: the throwaway spike addon is still installed at $ADDONS/SwagBagSpikes."
	echo "         Remove it first:  \"$(dirname "$SRC")/spikes/install.sh\" --remove"
fi

if [ "$MODE" != "remove" ] && [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
	echo "A real folder named $NAME already exists there. Not touching it. Run: scripts/install.sh --remove"
	exit 1
fi
if [ "$MODE" = "link" ] && [ -L "$DEST" ] && [ "$(readlink "$DEST")" = "$SRC" ]; then
	echo "Already installed (symlink points here). Nothing to do."
	exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
	read -r -p "Proceed? [y/N] " ans
	case "$ans" in y|Y|yes|YES) ;; *) echo "Cancelled."; exit 0 ;; esac
fi

case "$MODE" in
	link)   [ -L "$DEST" ] && rm "$DEST"; ln -s "$SRC" "$DEST"; echo "Done. Linked. Restart WoW or /reload." ;;
	copy)   [ -L "$DEST" ] && rm "$DEST"; cp -R "$SRC" "$DEST"; echo "Done. Copied. Restart WoW or /reload." ;;
	remove)
		if [ -L "$DEST" ]; then rm "$DEST"; echo "Symlink removed."
		elif [ -d "$DEST" ] && [ -f "$DEST/$NAME.toc" ]; then rm -r "$DEST"; echo "Copied folder removed."
		else echo "Nothing to remove."; fi
		;;
esac
```

Run: `bash -n scripts/install.sh && echo syntax-ok`
Expected: `syntax-ok`

- [ ] **Step 9: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (14 files)`, `84 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 10: Commit**

```bash
git add SwagBag/Core/Commands.lua SwagBag/Core/Boot.lua SwagBag/UI/ReportBox.lua SwagBag/SwagBag.toc scripts/install.sh spec/commands_spec.lua spec/boot_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add safe/report/check/reset/debug commands, start-up wiring, report window and installer" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 11: In-game session D2 (the user does this; about 10 minutes)**

Give the user this checklist exactly:

1. Quit World of Warcraft if it is running.
2. Open the Terminal app. Paste this line and press Return. It removes the old test addon. Type `y` if asked.
   `"/Users/lonezebra/Local Documents/AI-Projects/SwagBag/spikes/install.sh" --remove`
   You should see `Symlink removed.` or `Nothing to remove.`
3. Paste this line and press Return. Type `y` when asked.
   `"/Users/lonezebra/Local Documents/AI-Projects/SwagBag/scripts/install.sh"`
   You should see `Done. Linked.`
4. Start WoW. On the character screen, click **AddOns**. Choose your test character in the dropdown. Tick **SwagBag**. Make sure **SwagBag Spikes** is no longer in the list. Keep Baganator and other bag addons **unticked** for this character. Click **Okay** and log in.
5. Chat shows: `SwagBag: v0.1.0 loaded. Type /swagbag help for commands.`
6. Type `/swagbag help`. You should see 7 lines: `Commands:` followed by help, safe, report, check, reset and debug.
7. Type `/swagbag check`. You should see many green `PASS` lines. The last line is `Checks: N passed, 0 failed (0 required).` If any line says `FAIL`, write down its name.
8. Type `/swagbag safe`. You should see `Safe Mode: bags=off bank=off`.
9. Type `/swagbag debug error`. You should see two lines: `SwagBag hit an error and switched to Blizzard bags. Type /swagbag report.` and `Injected a test error into the bags path.`
10. Type `/swagbag report`. A window opens with its text already selected. Press **Ctrl+C**, then Esc. Paste the text into Claude Code. It should show `Safe Mode: bags=on (auto, …)` and an error line containing `debug:error`.
11. Type `/swagbag safe bags`. You should see `Safe Mode is OFF for bags: SwagBag handles them again.`
12. Type `/swagbag frob`. You should see `Unknown command "frob". Type /swagbag help for the list.`
13. Type `/swagbag reset`. A dialog asks you to confirm. Click **No**. Chat had already said `Confirm the reset in the dialog.`
14. Type `/reload`. After loading, type `/swagbag report` again. The `debug:error` line from step 9 is still there, because it was saved. Paste this report into Claude Code too.

Pass: every step showed the described text, and there were no red Lua error popups. Your bags are still Blizzard's at this point; that is expected.

---

### Task 9: Item records (`Items.Describe`)

**Files:**
- Create: `SwagBag/Engine/Items.lua`, `spec/fixtures/items.lua`, `spec/items_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/Items.lua`)
- Test: `spec/items_spec.lua`

**Interfaces:**
- Consumes: the Adapter container/item API (Task 6). `SB.Inventory.IsNew/MarkPending` are called only if present (Task 10).
- Produces:
  - `SB.Items.Describe(bag, slot)` returns a **record** (see the field list at the top of `Items.lua`), or `nil, "empty"` for an empty slot. This record is the only input to the query engine.
  - `SB.Items.Key(record, class)`: `"static"` gives the itemID, `"instance"` gives `link .. "#b"` or `link .. "#u"`, and `"volatile"` gives nil.
  - Test fixtures: `dofile("spec/fixtures/items.lua")` provides item ID constants, `Install(m)` and `SmallBags(m)` (a 16-slot backpack with 6 items).

- [ ] **Step 1: Write the fixtures and the failing test**

`spec/fixtures/items.lua`:

```lua
-- Shared item fixtures (Midnight-squished item levels). Install(m) adds them to a
-- mock Adapter; class/subclass numbers come from the real Adapter constants.
local Fixtures = {}

Fixtures.HEALING_POTION = 211880
Fixtures.FLASK = 212283
Fixtures.HERB = 210796
Fixtures.ORE = 210930
Fixtures.BOE_RING = 225001
Fixtures.SOULBOUND_HELM = 225002
Fixtures.JUNK = 156654
Fixtures.KEYSTONE = 180653
Fixtures.PET_CAGE = 82800
Fixtures.TOY = 188680
Fixtures.QUEST = 230001
Fixtures.UNLOADED = 239999
Fixtures.BAG = 194017

function Fixtures.Install(m)
	local C, CS, TS, MS = m.ITEM_CLASS, m.CONSUMABLE_SUB, m.TRADEGOODS_SUB, m.MISC_SUB
	m.AddItem(Fixtures.HEALING_POTION, { name = "Algari Healing Potion", classID = C.Consumable, subclassID = CS.Potion,
		quality = 1, ilvl = 300, reqLevel = 71, maxStack = 20, bind = "none", usable = true })
	m.AddItem(Fixtures.FLASK, { name = "Flask of Alchemical Chaos", classID = C.Consumable, subclassID = CS.Flask,
		quality = 3, ilvl = 300, reqLevel = 71, maxStack = 20, bind = "none", usable = true })
	m.AddItem(Fixtures.HERB, { name = "Mycobloom", classID = C.Tradegoods, subclassID = TS.Herb, quality = 1,
		ilvl = 1, maxStack = 1000, bind = "none", isCraftingReagent = true })
	m.AddItem(Fixtures.ORE, { name = "Bismuth", classID = C.Tradegoods, subclassID = TS.MetalStone, quality = 1,
		ilvl = 1, maxStack = 1000, bind = "none", isCraftingReagent = true })
	m.AddItem(Fixtures.BOE_RING, { name = "Band of the Fallen", classID = C.Armor, subclassID = 0,
		equipLoc = "INVTYPE_FINGER", quality = 4, ilvl = 285, reqLevel = 80, maxStack = 1, bind = "equip" })
	m.AddItem(Fixtures.SOULBOUND_HELM, { name = "Helm of Tests", classID = C.Armor, subclassID = 4,
		equipLoc = "INVTYPE_HEAD", quality = 3, ilvl = 270, reqLevel = 80, maxStack = 1, bind = "pickup" })
	m.AddItem(Fixtures.JUNK, { name = "Broken Tooth", classID = C.Miscellaneous, subclassID = MS.Junk, quality = 0,
		ilvl = 1, maxStack = 200, bind = "none" })
	m.AddItem(Fixtures.KEYSTONE, { name = "Mythic Keystone", classID = C.Reagent, subclassID = 1, quality = 4,
		ilvl = 1, maxStack = 1, bind = "pickup" })
	m.AddItem(Fixtures.PET_CAGE, { name = "Pet Cage", classID = C.Battlepet, subclassID = 0, quality = 3,
		ilvl = 1, maxStack = 1, bind = "none" })
	m.AddItem(Fixtures.TOY, { name = "Toy Train", classID = C.Miscellaneous, subclassID = 4, quality = 3,
		ilvl = 1, maxStack = 1, bind = "pickup", toy = true })
	m.AddItem(Fixtures.QUEST, { name = "Strange Letter", classID = C.Questitem, subclassID = 0, quality = 1,
		ilvl = 1, maxStack = 1, bind = "quest" })
	m.AddItem(Fixtures.UNLOADED, { classID = C.Armor, subclassID = 0, equipLoc = "INVTYPE_CHEST", pending = true })
	m.AddItem(Fixtures.BAG, { name = "Wildercloth Bag", classID = C.Container, subclassID = 0, equipLoc = "INVTYPE_BAG",
		quality = 1, ilvl = 1, maxStack = 1, bind = "equip" })
end

-- A small backpack: 16 slots, 6 items.
function Fixtures.SmallBags(m)
	Fixtures.Install(m)
	m.SetBagSize(0, 16)
	m.Put(0, 1, Fixtures.HEALING_POTION, 5)
	m.Put(0, 2, Fixtures.FLASK, 2, { onCooldown = true })
	m.Put(0, 3, Fixtures.BOE_RING, 1, { upgrade = true })
	m.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true, inSet = true })
	m.Put(0, 5, Fixtures.KEYSTONE, 1, { isBound = true, link = "|cffa335ee|Hkeystone:180653:503:12:10:9:0:0|h[Keystone: Ara-Kara]|h|r" })
	m.Put(0, 6, Fixtures.JUNK, 3)
end

return Fixtures
```

`spec/items_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Items.Describe", function()
	local SB, A, Items
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Items.lua" })
		A, Items = SB.Adapter, SB.Items
		Fixtures.SmallBags(A)
	end)

	it("returns nil, \"empty\" for an empty slot", function()
		assert.same({ nil, "empty" }, { Items.Describe(0, 16) })
	end)

	it("builds a full record for a loaded item", function()
		local r = Items.Describe(0, 1)
		assert.equal(Fixtures.HEALING_POTION, r.itemID)
		assert.equal("Algari Healing Potion", r.name)
		assert.equal(5, r.count)
		assert.equal(1, r.quality)
		assert.equal(A.ITEM_CLASS.Consumable, r.classID)
		assert.equal(A.CONSUMABLE_SUB.Potion, r.subclassID)
		assert.equal("", r.equipLoc)
		assert.equal(300, r.ilvl)
		assert.equal(71, r.reqLevel)
		assert.equal(20, r.maxStack)
		assert.equal("none", r.bind)
		assert.equal("backpack", r.location)
		assert.is_nil(r.tab)
		assert.equal(false, r.pending)
		assert.equal(true, r.isUsable)
	end)

	it("marks an unloaded item pending, keeps instant facts, and asks the client to load it", function()
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		local r = Items.Describe(0, 7)
		assert.equal(true, r.pending)
		assert.is_nil(r.name)
		assert.is_nil(r.ilvl)
		assert.is_nil(r.bind)
		assert.equal(A.ITEM_CLASS.Armor, r.classID)
		assert.equal("INVTYPE_CHEST", r.equipLoc)
		assert.same({ Fixtures.UNLOADED }, A.loadRequests)
	end)

	it("detects keystones and caged pets from the link", function()
		local key = Items.Describe(0, 5)
		assert.equal(true, key.isKeystone)
		assert.equal(true, key.isBound)
		A.Put(0, 8, Fixtures.PET_CAGE, 1, { link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r" })
		assert.equal(true, Items.Describe(0, 8).isCagedPet)
	end)

	it("knows the location kind and bank tab number", function()
		A.SetBagSize(5, 36)
		A.Put(5, 1, Fixtures.HERB, 40)
		A.SetBagSize(7, 98)
		A.Put(7, 3, Fixtures.ORE, 10)
		A.SetBagSize(13, 98)
		A.Put(13, 1, Fixtures.ORE, 10)
		assert.equal("reagentbag", Items.Describe(5, 1).location)
		assert.same({ "bank", 2 }, { Items.Describe(7, 3).location, Items.Describe(7, 3).tab })
		assert.same({ "warband", 2 }, { Items.Describe(13, 1).location, Items.Describe(13, 1).tab })
	end)

	it("fills the state flags", function()
		A.Put(0, 9, Fixtures.QUEST, 1)
		A.Put(0, 10, Fixtures.TOY, 1, { isLocked = true })
		assert.equal(true, Items.Describe(0, 2).onCooldown)
		assert.equal(true, Items.Describe(0, 3).hasUpgradeTrack)
		assert.equal(true, Items.Describe(0, 4).inEquipmentSet)
		assert.equal(true, Items.Describe(0, 9).isQuestItem)
		assert.equal(true, Items.Describe(0, 10).isToy)
		assert.equal(true, Items.Describe(0, 10).isLocked)
		assert.equal(false, Items.Describe(0, 1).isNew)
	end)

	it("asks Inventory whether the slot is new and reports pending items to it", function()
		local pending = {}
		SB.Inventory = { IsNew = function(bag, slot) return bag == 0 and slot == 1 end,
			MarkPending = function(id) pending[#pending + 1] = id end }
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		assert.equal(true, Items.Describe(0, 1).isNew)
		Items.Describe(0, 7)
		assert.same({ Fixtures.UNLOADED }, pending)
	end)

	it("Key gives itemID for static, link+bound for instance, nil for volatile", function()
		local r = Items.Describe(0, 4)
		assert.equal(Fixtures.SOULBOUND_HELM, Items.Key(r, "static"))
		assert.equal("item:" .. Fixtures.SOULBOUND_HELM .. "#b", Items.Key(r, "instance"))
		assert.is_nil(Items.Key(r, "volatile"))
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/items_spec.lua`
Expected: `0 passed, 8 failed`. The failures contain `cannot open SwagBag/Engine/Items.lua`.

- [ ] **Step 3: Write `SwagBag/Engine/Items.lua`**

```lua
-- SwagBag Items: one "item record" per occupied slot. The record is the ONLY
-- input the query engine sees (Engine/Keywords.lua reads these fields).
--
-- Items.Describe(bag, slot) -> record, or nil + "empty"
-- record = {
--   bag, slot, itemID, link, count, icon,
--   name            string | nil (nil while the item is still loading)
--   quality         number 0-8 | nil
--   classID, subclassID, equipLoc ("" when not equippable)
--   ilvl            number | nil (nil while loading)
--   reqLevel, maxStack                  number | nil (nil while loading)
--   bind            "none"|"pickup"|"equip"|"use"|"quest"|"account"|"warbound"|"wue" | nil
--   isCraftingReagent boolean | nil (nil while loading)
--   isBound, isWUE, isLocked, onCooldown, inEquipmentSet, hasUpgradeTrack,
--   isUsable, isToy, isQuestItem, isKeystone, isCagedPet, isNew    booleans
--   location        "backpack"|"bags"|"reagentbag"|"bank"|"warband"
--   tab             bank tab number (1-based) | nil
--   pending         true while C_Item has not loaded the item's data
-- }
local _, SB = ...

local Items = {}
SB.Items = Items

function Items.Describe(bag, slot)
	local A = SB.Adapter
	local s = A.GetSlot(bag, slot)
	if not s then
		return nil, "empty"
	end
	local inst = A.GetItemInstant(s.itemID) or {}
	local info = A.GetItemInfo(s.itemID)
	local location, tab = A.BagKind(bag)
	local link = s.link or ""
	local inv = SB.Inventory
	local r = {
		bag = bag,
		slot = slot,
		itemID = s.itemID,
		link = s.link,
		count = s.count or 1,
		icon = s.icon,
		name = s.name,
		quality = s.quality,
		classID = inst.classID,
		subclassID = inst.subclassID,
		equipLoc = inst.equipLoc or "",
		isBound = s.isBound == true,
		isLocked = s.isLocked == true,
		isWUE = A.IsWarboundUntilEquip(bag, slot),
		onCooldown = A.IsOnCooldown(bag, slot),
		inEquipmentSet = A.InEquipmentSet(bag, slot),
		hasUpgradeTrack = A.HasUpgradeTrack(bag, slot),
		isUsable = A.IsUsable(s.itemID),
		isToy = A.IsToy(s.itemID),
		isQuestItem = A.IsQuestItem(bag, slot) or inst.classID == A.ITEM_CLASS.Questitem,
		isKeystone = link:find("keystone:", 1, true) ~= nil,
		isCagedPet = link:find("battlepet:", 1, true) ~= nil,
		isNew = inv ~= nil and inv.IsNew(bag, slot) or false,
		location = location,
		tab = tab,
		pending = info == nil,
	}
	if info then
		r.name = r.name or info.name
		if r.quality == nil then
			r.quality = info.quality
		end
		r.reqLevel = info.reqLevel
		r.maxStack = info.maxStack
		r.bind = info.bind
		r.isCraftingReagent = info.isCraftingReagent
		r.ilvl = A.GetIlvl(bag, slot) or info.baseIlvl
	else
		r.name = nil
		A.RequestLoad(s.itemID)
		if inv then
			inv.MarkPending(s.itemID)
		end
	end
	return r
end

-- Memo key for a record by cache class (spec 7.8):
--   static -> itemID; instance -> full link + bound suffix; volatile -> nil (never memoized)
function Items.Key(record, class)
	if class == "static" then
		return record.itemID
	elseif class == "instance" then
		return (record.link or tostring(record.itemID)) .. (record.isBound and "#b" or "#u")
	end
	return nil
end
```

- [ ] **Step 4: Add it to the TOC** (append to `# Engine`): `Engine/Items.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/items_spec.lua`
Expected: `8 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (15 files)`, `92 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Engine/Items.lua SwagBag/SwagBag.toc spec/fixtures/items.lua spec/items_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add item records (Items.Describe) and shared item fixtures" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Inventory model and event coalescing

**Files:**
- Create: `SwagBag/Engine/Inventory.lua`, `spec/inventory_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/Inventory.lua`)
- Test: `spec/inventory_spec.lua`

**Interfaces:**
- Consumes: `SB.On/Emit/Debounce` (Task 4), `SB.ErrorTrap.Run` (Task 3), `SB.Adapter.GetSlot/NumSlots/GetBagIDs/After/IsSecret` (Task 6).
- Produces `SB.Inventory`:
  - Reason flags `R = {COUNT=1, ITEM=2, SIZE=4, LOCK=8, COOLDOWN=16, LOADED=32}`, with `Has(mask, flag)` and `Or(a, b)`.
  - `DiffSlot(old, new)`, `ScanBag(bag)` (returns mask and changes), `ScanAll()` (runs on `SB_LOGIN`), `Flush(source)` and `MarkDirty(bag)`.
  - `OnChanged(fn)`, where `fn(mask, changes)` receives changes as a list of `{bag, slot, reasons}`.
  - `GetSlot(bag, slot)` returns `{itemID, link, count, isLocked}` or nil. `Size(bag)`, `IsNew(bag, slot)`, `MarkPending(itemID)`, `Iterate(kind)` and `lastFlush` (`"delayed"` or `"failsafe"`).
  - Events: `BAG_UPDATE` marks the bag dirty. `BAG_UPDATE_DELAYED` flushes after a 50 ms debounce. A failsafe flushes 250 ms after the first dirty mark. `ITEM_LOCK_CHANGED` reports LOCK. `BAG_UPDATE_COOLDOWN` reports COOLDOWN. `ITEM_DATA_LOAD_RESULT` and `GET_ITEM_INFO_RECEIVED` report LOADED for pending items.

- [ ] **Step 1: Write the failing test** (`spec/inventory_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Engine/Inventory.lua",
}

describe("Inventory", function()
	local SB, A, Inv, R, calls
	before_each(function()
		SB = Loader.New(FILES)
		A, Inv = SB.Adapter, SB.Inventory
		R = Inv.R
		Fixtures.SmallBags(A)
		SB.Emit("SB_LOGIN")
		calls = {}
		Inv.OnChanged(function(mask, changes) calls[#calls + 1] = { mask = mask, changes = changes } end)
	end)

	local function fire(event, ...)
		SB.eventFrame:Fire(event, ...)
	end

	it("Has and Or combine reason flags without bit operators", function()
		local m = Inv.Or(R.COUNT, R.ITEM)
		assert.equal(3, m)
		assert.truthy(Inv.Has(m, R.ITEM))
		assert.falsy(Inv.Has(m, R.SIZE))
		assert.equal(3, Inv.Or(m, R.COUNT))
	end)

	it("DiffSlot tells ITEM from COUNT from nothing", function()
		local a = { itemID = 1, link = "x", count = 1 }
		assert.equal(0, Inv.DiffSlot(nil, nil))
		assert.equal(R.ITEM, Inv.DiffSlot(nil, a))
		assert.equal(R.ITEM, Inv.DiffSlot(a, { itemID = 2, link = "y", count = 1 }))
		assert.equal(R.COUNT, Inv.DiffSlot(a, { itemID = 1, link = "x", count = 4 }))
		assert.equal(0, Inv.DiffSlot(a, { itemID = 1, link = "x", count = 1 }))
	end)

	it("the login scan fills the model without marking anything new", function()
		assert.equal(16, Inv.Size(0))
		assert.equal(Fixtures.HEALING_POTION, Inv.GetSlot(0, 1).itemID)
		assert.is_nil(Inv.GetSlot(0, 16))
		assert.falsy(Inv.IsNew(0, 1))
	end)

	it("BAG_UPDATE only marks dirty; BAG_UPDATE_DELAYED flushes once after 50 ms", function()
		A.Put(0, 1, Fixtures.HEALING_POTION, 4)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE", 0)
		assert.equal(0, #calls)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.04)
		assert.equal(0, #calls)
		A.Advance(0.02)
		assert.equal(1, #calls)
		assert.equal(R.COUNT, calls[1].mask)
		assert.same({ { bag = 0, slot = 1, reasons = R.COUNT } }, calls[1].changes)
		assert.equal("delayed", Inv.lastFlush)
		A.Advance(1)
		assert.equal(1, #calls, "the failsafe must not flush a second time")
	end)

	it("the 250 ms failsafe flushes when BAG_UPDATE_DELAYED never comes", function()
		A.Clear(0, 6)
		fire("BAG_UPDATE", 0)
		A.Advance(0.2)
		assert.equal(0, #calls)
		A.Advance(0.1)
		assert.equal(1, #calls)
		assert.equal(R.ITEM, calls[1].mask)
		assert.equal("failsafe", Inv.lastFlush)
	end)

	it("an item arriving after login is new; leaving clears it", function()
		A.Put(0, 12, Fixtures.HERB, 10)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		assert.truthy(Inv.IsNew(0, 12))
		A.Clear(0, 12)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		assert.falsy(Inv.IsNew(0, 12))
	end)

	it("a bag size change reports SIZE plus the new empty slots", function()
		A.SetBagSize(1, 4)
		fire("BAG_UPDATE", 1)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		assert.equal(1, #calls)
		assert.truthy(Inv.Has(calls[1].mask, R.SIZE))
		assert.equal(4, Inv.Size(1))
	end)

	it("ITEM_LOCK_CHANGED reports LOCK for that slot and updates the snapshot", function()
		A.slots[0][1].isLocked = true
		fire("ITEM_LOCK_CHANGED", 0, 1)
		assert.equal(R.LOCK, calls[1].mask)
		assert.same({ { bag = 0, slot = 1, reasons = R.LOCK } }, calls[1].changes)
		assert.equal(true, Inv.GetSlot(0, 1).isLocked)
		fire("ITEM_LOCK_CHANGED", 16, nil)
		assert.equal(1, #calls, "equipment-slot locks are ignored")
	end)

	it("BAG_UPDATE_COOLDOWN reports COOLDOWN without rescanning", function()
		fire("BAG_UPDATE_COOLDOWN")
		assert.equal(R.COOLDOWN, calls[1].mask)
		assert.same({}, calls[1].changes)
	end)

	it("item data arriving for a pending item reports LOADED for its slots", function()
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		A.Put(0, 8, Fixtures.UNLOADED, 1)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		Inv.MarkPending(Fixtures.UNLOADED)
		fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		local last = calls[#calls]
		assert.equal(R.LOADED, last.mask)
		assert.same({ { bag = 0, slot = 7, reasons = R.LOADED }, { bag = 0, slot = 8, reasons = R.LOADED } }, last.changes)
		local n = #calls
		fire("GET_ITEM_INFO_RECEIVED", Fixtures.UNLOADED, true)
		assert.equal(n, #calls, "only once per pending item")
	end)

	it("Iterate walks every slot of a kind in bag order", function()
		A.SetBagSize(1, 2)
		Inv.ScanBag(1)
		local seen = 0
		local last
		for bag, slot in Inv.Iterate("bags") do
			seen = seen + 1
			last = bag .. ":" .. slot
		end
		assert.equal(18, seen)
		assert.equal("1:2", last)
	end)

	it("a listener error is trapped and flips bags to Safe Mode", function()
		Inv.OnChanged(function() error("listener broke") end)
		fire("BAG_UPDATE_COOLDOWN")
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.equal("inventory.listener", SB.ErrorTrap.Recent()[1].label)
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/inventory_spec.lua`
Expected: `0 passed, 12 failed`. The failures contain `cannot open SwagBag/Engine/Inventory.lua`.

- [ ] **Step 3: Write `SwagBag/Engine/Inventory.lua`**

```lua
-- SwagBag Inventory: live model of every container plus event coalescing (spec 9).
--   BAG_UPDATE(bag)       -> mark bag dirty (no work)
--   BAG_UPDATE_DELAYED    -> flush once, 50 ms debounce
--   failsafe              -> flush 250 ms after the first dirty mark if DELAYED never came
--   ITEM_LOCK_CHANGED     -> LOCK for that slot
--   BAG_UPDATE_COOLDOWN   -> COOLDOWN (no rescan)
--   ITEM_DATA_LOAD_RESULT / GET_ITEM_INFO_RECEIVED -> LOADED for slots holding a pending item
-- Listeners: Inventory.OnChanged(fn) with fn(mask, changes); changes = { {bag, slot, reasons} }.
-- Reasons are bit flags combined with plain arithmetic (Lua 5.1 has no bit operators).
local _, SB = ...

local Inv = {
	slots = {}, -- [bag][slot] = { itemID, link, count, isLocked } (nil = empty)
	sizes = {}, -- [bag] = number of slots
	dirty = {}, -- [bag] = true
	listeners = {},
	newSet = {}, -- ["bag:slot"] = true for items that arrived this session
	pending = {}, -- [itemID] = true while waiting for item data
	scanned = false,
	failsafeArmed = false,
	DEBOUNCE = 0.05,
	FAILSAFE = 0.25,
}
SB.Inventory = Inv

Inv.R = { COUNT = 1, ITEM = 2, SIZE = 4, LOCK = 8, COOLDOWN = 16, LOADED = 32 }
local FLAGS = { 1, 2, 4, 8, 16, 32 }

function Inv.Has(mask, flag)
	return math.floor(mask / flag) % 2 == 1
end

function Inv.Or(a, b)
	for _, flag in ipairs(FLAGS) do
		if Inv.Has(b, flag) and not Inv.Has(a, flag) then
			a = a + flag
		end
	end
	return a
end

local function key(bag, slot)
	return bag .. ":" .. slot
end

-- Pure: reasons (0 = unchanged) between two slot snapshots.
function Inv.DiffSlot(old, new)
	if old == nil and new == nil then
		return 0
	end
	if old == nil or new == nil or old.itemID ~= new.itemID or old.link ~= new.link then
		return Inv.R.ITEM
	end
	if old.count ~= new.count then
		return Inv.R.COUNT
	end
	return 0
end

local function snapshot(bag, slot)
	local s = SB.Adapter.GetSlot(bag, slot)
	if not s then
		return nil
	end
	return { itemID = s.itemID, link = s.link, count = s.count, isLocked = s.isLocked }
end

-- Rescan one bag. Returns mask, changes.
function Inv.ScanBag(bag)
	local size = SB.Adapter.NumSlots(bag)
	local oldSize = Inv.sizes[bag] or 0
	local old = Inv.slots[bag] or {}
	local new, changes = {}, {}
	local mask = size ~= oldSize and Inv.R.SIZE or 0
	for slot = 1, math.max(size, oldSize) do
		local snap = slot <= size and snapshot(bag, slot) or nil
		new[slot] = snap
		local r = Inv.DiffSlot(old[slot], snap)
		if r ~= 0 then
			changes[#changes + 1] = { bag = bag, slot = slot, reasons = r }
			mask = Inv.Or(mask, r)
			if r == Inv.R.ITEM and Inv.scanned then
				Inv.newSet[key(bag, slot)] = snap ~= nil or nil
			end
		end
	end
	Inv.slots[bag], Inv.sizes[bag] = new, size
	return mask, changes
end

function Inv.Notify(mask, changes)
	for _, fn in ipairs(Inv.listeners) do
		SB.ErrorTrap.Run("inventory.listener", "bags", fn, mask, changes)
	end
end

function Inv.OnChanged(fn)
	Inv.listeners[#Inv.listeners + 1] = fn
end

local failsafeGen = 0

function Inv.Flush(source)
	local bags = {}
	for bag in pairs(Inv.dirty) do
		bags[#bags + 1] = bag
	end
	table.sort(bags)
	Inv.dirty = {}
	Inv.failsafeArmed = false
	failsafeGen = failsafeGen + 1
	local mask, all = 0, {}
	for _, bag in ipairs(bags) do
		local m, changes = Inv.ScanBag(bag)
		mask = Inv.Or(mask, m)
		for _, c in ipairs(changes) do
			all[#all + 1] = c
		end
	end
	Inv.lastFlush = source
	if mask ~= 0 then
		Inv.Notify(mask, all)
	end
end

function Inv.MarkDirty(bag)
	if type(bag) ~= "number" or SB.Adapter.IsSecret(bag) then
		return
	end
	Inv.dirty[bag] = true
	if Inv.failsafeArmed then
		return
	end
	Inv.failsafeArmed = true
	local gen = failsafeGen
	SB.Adapter.After(Inv.FAILSAFE, function()
		SB.ErrorTrap.Run("inventory.failsafe", "bags", function()
			if gen ~= failsafeGen then
				return
			end
			Inv.failsafeArmed = false
			if next(Inv.dirty) ~= nil then
				Inv.Flush("failsafe")
			end
		end)
	end)
end

function Inv.TrackedBags()
	local A, list = SB.Adapter, {}
	for _, kind in ipairs({ "bags", "bank", "warband" }) do
		for _, bag in ipairs(A.GetBagIDs(kind)) do
			list[#list + 1] = bag
		end
	end
	return list
end

-- Initial full scan (no "new" marking). Called on SB_LOGIN.
function Inv.ScanAll()
	for _, bag in ipairs(Inv.TrackedBags()) do
		Inv.ScanBag(bag)
	end
	Inv.dirty = {}
	Inv.scanned = true
end

function Inv.GetSlot(bag, slot)
	return Inv.slots[bag] and Inv.slots[bag][slot]
end

function Inv.Size(bag)
	return Inv.sizes[bag] or 0
end

function Inv.IsNew(bag, slot)
	return Inv.newSet[key(bag, slot)] == true
end

function Inv.MarkPending(itemID)
	Inv.pending[itemID] = true
end

-- Iterate every slot of a kind ("bags" | "bank" | "warband"): bag, slot, snapshot-or-nil.
function Inv.Iterate(kind)
	local bags = SB.Adapter.GetBagIDs(kind)
	local bi, slot = 1, 0
	return function()
		while bags[bi] do
			slot = slot + 1
			if slot <= Inv.Size(bags[bi]) then
				return bags[bi], slot, Inv.GetSlot(bags[bi], slot)
			end
			bi, slot = bi + 1, 0
		end
	end
end

local function onItemLoaded(_, itemID)
	if not Inv.pending[itemID] then
		return
	end
	Inv.pending[itemID] = nil
	local changes = {}
	for bag, list in pairs(Inv.slots) do
		for slot = 1, Inv.Size(bag) do
			local s = list[slot]
			if s and s.itemID == itemID then
				changes[#changes + 1] = { bag = bag, slot = slot, reasons = Inv.R.LOADED }
			end
		end
	end
	table.sort(changes, function(a, b)
		return a.bag < b.bag or (a.bag == b.bag and a.slot < b.slot)
	end)
	if #changes > 0 then
		Inv.Notify(Inv.R.LOADED, changes)
	end
end

SB.On("BAG_UPDATE", function(_, bag)
	Inv.MarkDirty(bag)
end, "bags")

SB.On("BAG_UPDATE_DELAYED", function()
	SB.Debounce("inventory.flush", Inv.DEBOUNCE, function()
		Inv.Flush("delayed")
	end, "bags")
end, "bags")

SB.On("ITEM_LOCK_CHANGED", function(_, bag, slot)
	if type(bag) ~= "number" or type(slot) ~= "number" then
		return -- equipment-slot locks have no bag slot
	end
	local s = Inv.GetSlot(bag, slot)
	if s then
		local fresh = SB.Adapter.GetSlot(bag, slot)
		s.isLocked = fresh ~= nil and fresh.isLocked or false
	end
	Inv.Notify(Inv.R.LOCK, { { bag = bag, slot = slot, reasons = Inv.R.LOCK } })
end, "bags")

SB.On("BAG_UPDATE_COOLDOWN", function()
	Inv.Notify(Inv.R.COOLDOWN, {})
end, "bags")

SB.On("ITEM_DATA_LOAD_RESULT", onItemLoaded, "bags")
SB.On("GET_ITEM_INFO_RECEIVED", onItemLoaded, "bags")

SB.On("SB_LOGIN", function()
	Inv.ScanAll()
end, "bags")
```

- [ ] **Step 4: Add it to the TOC** (append to `# Engine`): `Engine/Inventory.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/inventory_spec.lua`
Expected: `12 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (16 files)`, `104 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Engine/Inventory.lua SwagBag/SwagBag.toc spec/inventory_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add Inventory model with dirty-set flush, 250 ms failsafe and reason flags" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Button pool (WoW-only)

This module creates secure-template buttons, so it cannot run under the stub. Its gates are luacheck, the forbidden-token and C_* rules, and in-game session D3 (the report's `Buttons:` line). It follows the construction proven by the spike in `spikes/SwagBagSpikes/SpikePool.lua` (per-bag `SetID` parents, `IsCombinedBagContainer`, background atlas), but is written fresh.

**Files:**
- Create: `SwagBag/UI/Buttons.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# UI`: `UI/Buttons.lua`)
- Test: luacheck + D3 (Task 13 Step 8)

**Interfaces:**
- Consumes: `SB.Adapter` (Task 6), `SB.OutOfCombat/On/Emit` (Task 4), and the Blizzard globals `SetItemButtonTexture`, `SetItemButtonCount`, `SetItemButtonQuality` and `SetItemButtonDesaturated`.
- Produces `SB.Buttons`:
  - `SetParentFor(kind, frame)`, called by the bags window at load. Kinds without a registered parent get a hidden holder frame (week 3 hosts the bank holders).
  - `CreateAll()` runs on `SB_LOGIN`. It covers bags 0–5 at max(size, 38) each and purchased bank/warband tabs at max(size, 98) each. In combat it is queued. When done it emits `SB_BUTTONS_READY`.
  - `EnsureCapacity(bag, n)` (queued in combat), `Get(bag, slot)`, `Count(bag)`, `KindOf(bag)` (returns `"bags"|"bank"|"warband"`), `Place(button, x, y)`, `Paint(button, slotInfo)` and `SetDimmed(button, dimmed)` (alpha 0.2).
  - Fields `created` and `stats = {count, createMs}`.

- [ ] **Step 1: Write `SwagBag/UI/Buttons.lua`**

```lua
-- SwagBag button pool (spec 4.1). One ContainerFrameItemButtonTemplate button per
-- physical (bag, slot), created at login behind the loading screen, parented to a
-- per-bag frame (SetID(bag)) PERMANENTLY. Buttons are never reparented, destroyed
-- or re-SetID'd; they move only with ClearAllPoints + SetPoint. Item use, drag,
-- split and tooltips are Blizzard's own template handlers; we add no click scripts.
local _, SB = ...

local Buttons = {
	frames = {}, -- [bag] = plain Frame with SetID(bag)
	buttons = {}, -- [bag][slot] = ItemButton
	parents = {}, -- [kind] = frame the bag frames of that kind live under
	holders = {},
	stats = { count = 0, createMs = 0 },
	created = false,
	DIM_ALPHA = 0.2,
}
SB.Buttons = Buttons

-- kind "bags" | "bank" | "warband" for a bag ID.
local function kindOf(bag)
	local loc = SB.Adapter.BagKind(bag)
	if loc == "bank" or loc == "warband" then
		return loc
	end
	return "bags"
end
Buttons.KindOf = kindOf

-- The bags window registers its scroll child here at load time. Bank kinds get a
-- hidden holder frame until the bank window exists (week 3).
function Buttons.SetParentFor(kind, frame)
	Buttons.parents[kind] = frame
end

local function parentFor(kind)
	if Buttons.parents[kind] then
		return Buttons.parents[kind]
	end
	local h = Buttons.holders[kind]
	if not h then
		h = CreateFrame("Frame", nil, UIParent)
		h:SetSize(1, 1)
		h:Hide()
		Buttons.holders[kind] = h
	end
	return h
end

local function bagFrame(bag)
	local f = Buttons.frames[bag]
	if f then
		return f
	end
	local parent = parentFor(kindOf(bag))
	f = CreateFrame("Frame", nil, parent)
	f:SetID(bag)
	f:SetAllPoints(parent)
	f.IsCombinedBagContainer = function()
		return false
	end
	Buttons.frames[bag] = f
	Buttons.buttons[bag] = {}
	return f
end

local function addBackground(button)
	local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
	bg:SetAllPoints(button)
	if not pcall(bg.SetAtlas, bg, "bags-item-slot64") then
		bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
	end
end

local function createButton(bag, slot)
	local b = CreateFrame("ItemButton", nil, bagFrame(bag), "ContainerFrameItemButtonTemplate")
	b:SetID(slot)
	addBackground(b)
	b:Hide()
	Buttons.buttons[bag][slot] = b
	Buttons.stats.count = Buttons.stats.count + 1
	return b
end

-- Ensure `bag` has at least n buttons. In combat the growth is queued (policy).
function Buttons.EnsureCapacity(bag, n)
	if SB.Adapter.InCombat() then
		SB.OutOfCombat(function()
			Buttons.EnsureCapacity(bag, n)
		end, "buttons.grow." .. bag, "bags")
		return 0
	end
	bagFrame(bag)
	local list = Buttons.buttons[bag]
	local made = 0
	for slot = #list + 1, n do
		createButton(bag, slot)
		made = made + 1
	end
	return made
end

-- Create the whole pool: bags 0-5 at 38 each, purchased bank tabs at 98 each.
function Buttons.CreateAll()
	if Buttons.created then
		return
	end
	local A = SB.Adapter
	if A.InCombat() then
		SB.OutOfCombat(Buttons.CreateAll, "buttons.createAll", "bags")
		return
	end
	local t0 = A.ProfileMs()
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		Buttons.EnsureCapacity(bag, math.max(A.NumSlots(bag), A.BAG_CAPACITY))
	end
	for _, kind in ipairs({ "bank", "warband" }) do
		for _, bag in ipairs(A.GetBagIDs(kind)) do
			Buttons.EnsureCapacity(bag, math.max(A.NumSlots(bag), A.BANK_TAB_CAPACITY))
		end
	end
	Buttons.stats.createMs = A.ProfileMs() - t0
	Buttons.created = true
	SB.Emit("SB_BUTTONS_READY")
end

function Buttons.Get(bag, slot)
	local list = Buttons.buttons[bag]
	return list and list[slot]
end

function Buttons.Count(bag)
	return #(Buttons.buttons[bag] or {})
end

-- Coordinates are TOPLEFT offsets inside the window's scroll child.
function Buttons.Place(button, x, y)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x, y)
end

-- info: SB.Adapter.GetSlot(bag, slot) result, or nil for an empty slot.
function Buttons.Paint(button, info)
	SetItemButtonTexture(button, info and info.icon or nil)
	SetItemButtonCount(button, info and info.count or 0)
	SetItemButtonQuality(button, info and info.quality or nil, info and info.link or nil)
	SetItemButtonDesaturated(button, info ~= nil and info.isLocked)
	if button.UpdateCooldown then
		pcall(button.UpdateCooldown, button, info and info.icon or nil)
	end
end

-- Full dim: alpha on the whole button covers icon, border, count and glows.
function Buttons.SetDimmed(button, dimmed)
	button:SetAlpha(dimmed and Buttons.DIM_ALPHA or 1)
end

SB.On("SB_LOGIN", function()
	Buttons.CreateAll()
end, "bags")
```

- [ ] **Step 2: Add it to the TOC** (append to `# UI`, after `UI/ReportBox.lua`): `UI/Buttons.lua`

- [ ] **Step 3: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (17 files)`, `104 passed, 0 failed`, `ALL CHECKS PASSED` (stage 2 luacheck prints nothing).

- [ ] **Step 4: Commit**

```bash
git add SwagBag/UI/Buttons.lua SwagBag/SwagBag.toc
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add secure item-button pool with per-bag parent frames" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Grid layout math and the bags window

**Files:**
- Create: `SwagBag/Engine/GridLayout.lua`, `spec/gridlayout_spec.lua`, `SwagBag/UI/BagsWindow.lua`
- Modify: `SwagBag/SwagBag.toc` (append `Engine/GridLayout.lua` to `# Engine` and `UI/BagsWindow.lua` to `# UI`)
- Test: `spec/gridlayout_spec.lua`, plus D3 (the window is opened by the hooks from Task 13, so it is checked in the same session)

**Interfaces:**
- Consumes: `SB.Buttons.*` (Task 11), `SB.Items.Describe` (Task 9), `SB.Inventory.OnChanged/Has/R` (Task 10), `SB.Config.Get/Set/UI` (Task 5), `SB.ErrorTrap.Guard` (Task 3), and `SB.Emit` (Task 4).
- Produces:
  - `SB.GridLayout.Compute(bags, opts)` returns `{cells = {{bag, slot, x, y}}, count, rows, width, height}`, where `bags` is a list of `{bag, size}` and `opts` is `{columns, size, gap, padding}`. Also `ClampOffset(offset, childHeight, viewHeight)` and `ClampScale(scale)` (0.5–2.0).
  - `SB.BagsWindow`:
    - `Open()` returns false in Safe Mode or before the pool exists. `Close()`, `Toggle()` and `IsOpen()`.
    - `Layout(reason)` emits `SB_BAGS_LAYOUT`. `ForEachSlot(fn(button, record, bag, slot))`. `SetScale(scale)`, `RestorePosition()` and `ClampScroll()`.
    - Fields: `records[bag][slot]`, `cells`, `frame` (named `SwagBagBagsWindow`, listed in `UISpecialFrames`), `child`, `scroll`, `HEADER = 58` (the search row lives in this header) and `stats.lastLayoutMs`.
    - It emits `SB_BAGS_UPDATED` after a partial repaint.

- [ ] **Step 1: Write the failing test** (`spec/gridlayout_spec.lua`)

```lua
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/gridlayout_spec.lua`
Expected: `0 passed, 5 failed`. The failures contain `cannot open SwagBag/Engine/GridLayout.lua`.

- [ ] **Step 3: Write `SwagBag/Engine/GridLayout.lua`**

```lua
-- SwagBag grid layout math (pure). Grid view = physical slot order (bag 0, 1-4, 5)
-- flowing through one continuous grid (spec AC3.6).
local _, SB = ...

local Grid = {}
SB.GridLayout = Grid

-- bags: ordered list of { bag = id, size = n }
-- opts: { columns, size, gap, padding }
-- Returns { cells = { {bag, slot, x, y} }, count, rows, width, height }.
-- x grows right, y grows DOWN as negative numbers (WoW TOPLEFT offsets).
function Grid.Compute(bags, opts)
	local cols, size, gap, pad = opts.columns, opts.size, opts.gap, opts.padding
	local step = size + gap
	local cells, i = {}, 0
	for _, b in ipairs(bags) do
		for slot = 1, b.size do
			cells[#cells + 1] = {
				bag = b.bag,
				slot = slot,
				x = pad + (i % cols) * step,
				y = -(pad + math.floor(i / cols) * step),
			}
			i = i + 1
		end
	end
	local rows = math.ceil(i / cols)
	return {
		cells = cells,
		count = i,
		rows = rows,
		width = pad * 2 + cols * size + (cols - 1) * gap,
		height = rows > 0 and (pad * 2 + rows * size + (rows - 1) * gap) or pad * 2,
	}
end

-- Keep a scroll offset inside [0, max(0, childHeight - viewHeight)] (spec 4.4).
function Grid.ClampOffset(offset, childHeight, viewHeight)
	local max = math.max(0, childHeight - viewHeight)
	if offset > max then
		return max
	end
	if offset < 0 then
		return 0
	end
	return offset
end

-- Clamp a window scale to 50-200 % (spec AC1.5).
function Grid.ClampScale(scale)
	return math.max(0.5, math.min(2.0, scale))
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/gridlayout_spec.lua`
Expected: `5 passed, 0 failed`

- [ ] **Step 5: Write `SwagBag/UI/BagsWindow.lua`** (WoW-only)

```lua
-- SwagBag bags window, GRID view (spec F1, AC3.6). Movable, Ctrl+wheel scale
-- 50-200 %, remembers its position per character, closes on Esc, scrolls with a
-- clamped offset, and stays hidden until its layout is complete.
local _, SB = ...

local L = SB.L
local W = {
	records = {}, -- [bag][slot] = item record (Items.Describe) for shown slots
	cells = {}, -- last GridLayout cells
	stats = {},
	SLOT = 37,
	GAP = 4,
	PAD = 4,
	HEADER = 58, -- title row + search row
	FOOTER = 6,
	MAX_HEIGHT_FRACTION = 0.75,
	SCALE_STEP = 0.05,
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

---------------------------------------------------------------------------
-- Position and scale
---------------------------------------------------------------------------
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

frame:SetScript("OnDragStart", SB.ErrorTrap.Guard("bags.dragStart", function()
	frame:StartMoving()
end, "bags"))
frame:SetScript("OnDragStop", SB.ErrorTrap.Guard("bags.dragStop", function()
	frame:StopMovingOrSizing()
	savePosition()
end, "bags"))

local titleToken = 0
local function showScaleFeedback(scale)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(L.BAGS_SCALE:format(math.floor(scale * 100 + 0.5)))
	SB.Adapter.After(1.5, function()
		if token == titleToken then
			frame.title:SetText(L.BAGS_TITLE)
		end
	end)
end

function W.SetScale(scale)
	scale = SB.GridLayout.ClampScale(scale)
	SB.Config.Set("bags.scale", scale)
	frame:SetScale(scale)
	showScaleFeedback(scale)
	if frame:IsShown() then
		W.Layout("scale")
	end
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", SB.ErrorTrap.Guard("bags.wheel", function(_, delta)
	if IsControlKeyDown() then
		W.SetScale(SB.Config.Get("bags.scale") + delta * W.SCALE_STEP)
		return
	end
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (W.SLOT + W.GAP) * 3)
	W.ClampScroll()
end, "bags"))

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
	W.records[bag][slot] = SB.Items.Describe(bag, slot)
end

function W.Layout(reason)
	local A, B = SB.Adapter, SB.Buttons
	local t0 = A.ProfileMs()
	local bags = bagList()
	local sizeOf = {}
	for _, b in ipairs(bags) do
		sizeOf[b.bag] = b.size
		if B.Count(b.bag) < b.size then
			B.EnsureCapacity(b.bag, b.size)
		end
	end
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		for slot = (sizeOf[bag] or 0) + 1, B.Count(bag) do
			B.Get(bag, slot):Hide()
		end
	end
	local g = SB.GridLayout.Compute(bags, { columns = SB.Config.Get("bags.columns"), size = W.SLOT, gap = W.GAP, padding = W.PAD })
	W.records, W.cells = {}, g.cells
	for _, c in ipairs(g.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			B.Place(button, c.x, c.y)
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			describe(c.bag, c.slot)
			button:Show()
		end
	end
	child:SetSize(g.width, g.height)
	local maxHeight = UIParent:GetHeight() * W.MAX_HEIGHT_FRACTION / frame:GetScale()
	local viewHeight = math.min(g.height, maxHeight - W.HEADER - W.FOOTER)
	frame:SetSize(g.width + 8, viewHeight + W.HEADER + W.FOOTER)
	W.ClampScroll()
	W.stats.lastLayoutMs = A.ProfileMs() - t0
	W.stats.lastLayoutReason = reason
	SB.Emit("SB_BAGS_LAYOUT", reason)
end

-- fn(button, record-or-nil, bag, slot) for every slot currently in the grid.
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
	W.Layout("open")
	frame:Show()
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
SB.Inventory.OnChanged(function(mask, changes)
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
end)
```

- [ ] **Step 6: Update the TOC**

Append `Engine/GridLayout.lua` to the end of `# Engine`. Append `UI/BagsWindow.lua` to the end of `# UI` (after `UI/Buttons.lua`; it must load after Buttons and Inventory).

- [ ] **Step 7: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (19 files)`, `109 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 8: Commit**

```bash
git add SwagBag/Engine/GridLayout.lua SwagBag/UI/BagsWindow.lua SwagBag/SwagBag.toc spec/gridlayout_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add grid layout math and the movable, scalable bags window" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Safe Mode hooks (bag-key takeover) and in-game session D3

**Files:**
- Create: `SwagBag/UI/SafeModeHooks.lua`, `spec/safemodehooks_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# UI`: `UI/SafeModeHooks.lua`)
- Test: `spec/safemodehooks_spec.lua` (runs with stubbed `hooksecurefunc` and Blizzard frames), plus in-game session D3

**Interfaces:**
- Consumes: `SB.BagsWindow.Toggle/Open/Close` (Task 12), `SB.Buttons.created` (Task 11), `SB.SafeMode` (Task 3), `SB.ErrorTrap.Guard` (Task 3), `SB.On` (Task 4), `SB.Adapter.Now` (Task 2), and the Blizzard globals `hooksecurefunc`, `ToggleAllBags`, `ToggleBackpack`, `OpenAllBags`, `CloseAllBags`, `ContainerFrame1..NUM_CONTAINER_FRAMES` and `ContainerFrameCombinedBags`.
- Produces `SB.SafeModeHooks`:
  - `IsActive()` is true when the pool exists and bags are not in Safe Mode.
  - `Install()` runs on `SB_LOGIN`. `HideBlizzardBags()`.
  - Reactions: `SB_SAFEMODE_CHANGED` for bags closes SwagBag's window (on) or hides Blizzard's frames (off). `SB_BUTTONS_READY` hides Blizzard's frames when SwagBag becomes active late.

- [ ] **Step 1: Write the failing test** (`spec/safemodehooks_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")

local FILES = { "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua" }

-- A Blizzard bag frame stand-in: remembers OnShow hooks and its shown state.
local function fakeBlizzardFrame()
	local f = { shown = false, hooks = {} }
	function f:HookScript(_, fn) self.hooks[#self.hooks + 1] = fn end
	function f:IsShown() return self.shown end
	function f:Hide() self.shown = false end
	function f:Show()
		self.shown = true
		for _, fn in ipairs(self.hooks) do fn(self) end
	end
	return f
end

describe("SafeModeHooks", function()
	local SB, A, hooks, toggles, closes
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		hooks, toggles, closes = {}, 0, 0
		hooksecurefunc = function(name, fn) hooks[name] = fn end
		NUM_CONTAINER_FRAMES = 2
		ContainerFrame1, ContainerFrame2 = fakeBlizzardFrame(), fakeBlizzardFrame()
		ContainerFrameCombinedBags = fakeBlizzardFrame()
		SB.Buttons = { created = true }
		SB.BagsWindow = {
			Toggle = function() toggles = toggles + 1 end,
			Open = function() end,
			Close = function() closes = closes + 1 end,
		}
		Loader.LoadFile(SB, "SwagBag/UI/SafeModeHooks.lua")
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		hooksecurefunc, NUM_CONTAINER_FRAMES = nil, nil
		ContainerFrame1, ContainerFrame2, ContainerFrameCombinedBags = nil, nil, nil
	end)

	it("the bag key toggles SwagBag once per frame even when two bag functions fire", function()
		hooks.ToggleAllBags()
		hooks.ToggleBackpack()
		assert.equal(1, toggles)
		A.Advance(0.1)
		hooks.ToggleBackpack()
		assert.equal(2, toggles)
	end)

	it("Blizzard bag frames hide themselves while SwagBag is active", function()
		ContainerFrameCombinedBags:Show()
		assert.falsy(ContainerFrameCombinedBags:IsShown())
	end)

	it("in Safe Mode the hooks step aside: no toggle, Blizzard frames stay open", function()
		SB.SafeMode.Enable("bags", "manual")
		hooks.ToggleAllBags()
		assert.equal(0, toggles)
		ContainerFrame1:Show()
		assert.truthy(ContainerFrame1:IsShown())
	end)

	it("turning Safe Mode on closes SwagBag's window; turning it off hides Blizzard's", function()
		SB.SafeMode.Enable("bags", "auto")
		assert.equal(1, closes)
		ContainerFrame2:Show()
		SB.SafeMode.Disable("bags")
		assert.falsy(ContainerFrame2:IsShown())
	end)

	it("stays inactive until the button pool exists (login or /reload in combat)", function()
		SB.Buttons.created = false
		assert.falsy(SB.SafeModeHooks.IsActive())
		hooks.ToggleAllBags()
		assert.equal(0, toggles)
		ContainerFrame1:Show()
		assert.truthy(ContainerFrame1:IsShown(), "Blizzard bags must keep working meanwhile")
	end)

	it("when the pool becomes ready later, open Blizzard bags close so SwagBag takes over", function()
		SB.Buttons.created = false
		ContainerFrame1:Show()
		SB.Buttons.created = true
		SB.Emit("SB_BUTTONS_READY")
		assert.falsy(ContainerFrame1:IsShown())
	end)

	it("an error inside a hook flips bags to Safe Mode instead of breaking the bag key", function()
		SB.BagsWindow.Toggle = function() error("toggle broke") end
		hooks.ToggleAllBags()
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.equal("hook:ToggleAllBags", SB.ErrorTrap.Recent()[1].label)
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/safemodehooks_spec.lua`
Expected: `0 passed, 7 failed`. The failures contain `cannot open SwagBag/UI/SafeModeHooks.lua`.

- [ ] **Step 3: Write `SwagBag/UI/SafeModeHooks.lua`**

```lua
-- SwagBag Safe Mode hooks (spec 10.1, proven in spike S).
-- While SwagBag is active for bags (Safe Mode off and the button pool exists):
--   * B / ToggleAllBags / ToggleBackpack toggle SwagBag's window,
--   * OpenAllBags / CloseAllBags (vendor, mailbox, ...) open/close it,
--   * ContainerFrame1..N and ContainerFrameCombinedBags hide themselves on show.
-- The hooks only check a flag, so flipping Safe Mode is the whole toggle - legal
-- in and out of combat. We never CALL any Blizzard bag-opening function.
local _, SB = ...

local Hooks = { installed = false, lastToggle = -1 }
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

-- One key press can run several hooked bag functions in the same frame; act once.
local function onBagKey()
	if not Hooks.IsActive() then
		return
	end
	local now = SB.Adapter.Now()
	if now == Hooks.lastToggle then
		return
	end
	Hooks.lastToggle = now
	SB.BagsWindow.Toggle()
end

function Hooks.Install()
	if Hooks.installed then
		return
	end
	Hooks.installed = true
	local Guard = SB.ErrorTrap.Guard
	hooksecurefunc("ToggleAllBags", Guard("hook:ToggleAllBags", onBagKey, "bags"))
	hooksecurefunc("ToggleBackpack", Guard("hook:ToggleBackpack", onBagKey, "bags"))
	hooksecurefunc("OpenAllBags", Guard("hook:OpenAllBags", function()
		if Hooks.IsActive() then
			SB.BagsWindow.Open()
		end
	end, "bags"))
	hooksecurefunc("CloseAllBags", Guard("hook:CloseAllBags", function()
		if Hooks.IsActive() then
			SB.BagsWindow.Close()
		end
	end, "bags"))
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

- [ ] **Step 4: Add it to the TOC** (append to the end of `# UI`): `UI/SafeModeHooks.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/safemodehooks_spec.lua`
Expected: `7 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (20 files)`, `116 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 7: Commit**

```bash
git add SwagBag/UI/SafeModeHooks.lua SwagBag/SwagBag.toc spec/safemodehooks_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Take over the bag key and Blizzard bag frames, with live Safe Mode release" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: In-game session D3: grid bags + Safe Mode (the user does this; about 20 minutes)**

Give the user this checklist exactly. Have a healing potion or healthstone, some food, and a few junk items with you. Go to a city that has a vendor and training dummies.

1. Log in, or type `/reload` if you are already in game. Chat shows the `loaded` line.
2. Press **B**. The SwagBag window opens: a dark window titled **SwagBag** with all your bag slots in one grid. Blizzard's bag window does **not** appear.
3. Press **B** again. The window closes. Click the backpack icon on your action bar: it opens and closes the same window.
4. Hover over an item: Blizzard's normal tooltip appears.
5. Right-click some food (out of combat). You start eating. No red "Interface action failed because of an AddOn" message.
6. Shift-click a stack: the split box appears. Drag an item to an empty slot: it moves. Drag an item onto your action bar: it goes there.
7. Drag the window by an empty part of its border to another place. Type `/reload`, then press **B**: it opens where you left it.
8. Hold **Ctrl** and roll the mouse wheel over the items. The window grows or shrinks, and the title briefly shows a percentage such as `SwagBag 110%`. It never goes below 50% or above 200%.
9. Without Ctrl, roll the mouse wheel. If the window is shorter than your bags it scrolls, and it never scrolls past the last row.
10. Press **Esc**. The window closes.
11. Talk to a vendor. The SwagBag window opens by itself. Right-click a junk item: it sells. Close the vendor: the window closes.
12. **Combat:** attack a training dummy. While in combat, press **B** and right-click a healing potion or healthstone in the SwagBag window. It is used, with no red error.
13. **Check V9 (still in combat):** type `/swagbag debug error`. You see `SwagBag hit an error and switched to Blizzard bags…`, and the SwagBag window closes. Press **B**: Blizzard's bags open. Right-click your potion or healthstone from Blizzard's bags: it is used (or shows the normal cooldown message), with no red "Interface action failed" error.
14. **Check V3 (still in combat):** type `/swagbag safe bags`. You see `Safe Mode is OFF for bags…`. Press **B**: SwagBag's window opens (Blizzard's closes). Type `/swagbag safe bags` again. You see `Safe Mode is ON…`. Press **B** to open Blizzard's bags, then use an item from them in combat. It works, with no red error.
15. Stop attacking and leave combat. Type `/swagbag safe off`. Press **B**: SwagBag opens.
16. **Reload in combat:** attack the dummy again. While in combat type `/reload`. After loading (you are still in combat), press **B**: Blizzard's bags open, because SwagBag waits until combat ends. Leave combat. Blizzard's bags close by themselves. Press **B**: SwagBag opens.
17. Type `/swagbag report`, press Ctrl+C, and paste it into Claude Code. Claude checks for: `Blocked actions: none`, a `Buttons:` count around 1,000–1,300 with the milliseconds at or below 150, and only the deliberate `debug:error` errors.
18. **V4 (placeholder click is harmless):** not applicable this week. Placeholders arrive with category sections in week 2. Nothing to do.

Pass: steps 2–16 behaved as described, step 17's report shows no blocked actions and no unexpected errors, and the button-creation time is ≤ 150 ms. If anything differs, paste the report and describe the step number to Claude.

---

### Task 14: Query tokenizer (parallel lane; needs only Tasks 1–2)

**Files:**
- Create: `SwagBag/Engine/Query/Lexer.lua`, `spec/query_lexer_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/Query/Lexer.lua`)
- Test: `spec/query_lexer_spec.lua`

**Interfaces:**
- Consumes: the namespace only.
- Produces:
  - `SB.QueryLexer.Tokenize(text)` returns a token list, or `nil, {position, expected = "QUOTE", got = ""}`.
  - A token is `{type, value, s, e}`, where `type` is one of `WORD`, `STRING`, `OP` (`=` `<` `<=` `>` `>=`), `AND`, `OR`, `NOT`, `LPAREN`, `RPAREN`, `HASH` or `EOF`. Spans are 1-based character positions.

- [ ] **Step 1: Write the failing test** (`spec/query_lexer_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")

-- "TYPE:value@s-e" strings, easy to compare.
local function brief(tokens)
	local out = {}
	for i, t in ipairs(tokens) do
		out[i] = t.type .. ":" .. t.value .. "@" .. t.s .. "-" .. t.e
	end
	return out
end

describe("Query lexer", function()
	local Lexer
	before_each(function()
		Lexer = Loader.New({ "SwagBag/Engine/Query/Lexer.lua" }).QueryLexer
	end)

	it("splits words and operators with character spans", function()
		assert.same({ "WORD:gear@1-4", "AND:&@6-6", "WORD:ilvl@8-11", "OP:>@12-12", "WORD:280@13-15", "EOF:@16-16" },
			brief(Lexer.Tokenize("gear & ilvl>280")))
	end)

	it("reads two-character operators", function()
		assert.same({ "WORD:lvl@1-3", "OP:>=@4-5", "WORD:80@6-7", "EOF:@8-8" }, brief(Lexer.Tokenize("lvl>=80")))
		assert.same({ "WORD:count@1-5", "OP:<=@6-7", "WORD:5@8-8", "EOF:@9-9" }, brief(Lexer.Tokenize("count<=5")))
		assert.same({ "WORD:tab@1-3", "OP:=@4-4", "WORD:2@5-5", "EOF:@6-6" }, brief(Lexer.Tokenize("tab=2")))
	end)

	it("reads !, |, parentheses and # as single tokens", function()
		assert.same({ "NOT:!@1-1", "LPAREN:(@2-2", "HASH:#@3-3", "WORD:rune@4-7", "OR:|@9-9", "WORD:x@11-11",
			"RPAREN:)@12-12", "EOF:@13-13" }, brief(Lexer.Tokenize("!(#rune | x)")))
	end)

	it("reads a quoted string as one STRING token spanning its quotes", function()
		assert.same({ "STRING:Healing Potion@1-16", "EOF:@17-17" }, brief(Lexer.Tokenize("\"Healing Potion\"")))
	end)

	it("keeps punctuation that is not an operator inside words", function()
		assert.same({ "WORD:Ara-Kara@1-8", "WORD:it's@10-13", "EOF:@14-14" }, brief(Lexer.Tokenize("Ara-Kara it's")))
	end)

	it("reports an unterminated quote at the end of the text", function()
		local tokens, err = Lexer.Tokenize("boe & \"heal")
		assert.is_nil(tokens)
		assert.same({ position = 12, expected = "QUOTE", got = "" }, err)
	end)

	it("returns only EOF for empty or blank text", function()
		assert.same({ "EOF:@1-1" }, brief(Lexer.Tokenize("")))
		assert.same({ "EOF:@4-4" }, brief(Lexer.Tokenize("   ")))
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/query_lexer_spec.lua`
Expected: `0 passed, 7 failed`. The failures contain `cannot open SwagBag/Engine/Query/Lexer.lua`.

- [ ] **Step 3: Write `SwagBag/Engine/Query/Lexer.lua`**

```lua
-- SwagBag query tokenizer (spec 7.2). Pure Lua.
-- Token: { type, value, s, e } with 1-based character span s..e.
-- Types: WORD, STRING, OP (= < <= > >=), AND (&), OR (|), NOT (!), LPAREN, RPAREN,
--        HASH (#), EOF. A WORD is any run of characters that are not whitespace
--        and not one of  & | ! ( ) # " = < >
-- Errors are returned as { position, expected, got } (expected is a code, see Query.FormatError).
local _, SB = ...

local Lexer = {}
SB.QueryLexer = Lexer

local SINGLE = { ["&"] = "AND", ["|"] = "OR", ["!"] = "NOT", ["("] = "LPAREN", [")"] = "RPAREN", ["#"] = "HASH" }
local STOP = "[%s&|!()#\"=<>]"

function Lexer.Tokenize(text)
	local tokens, i, n = {}, 1, #text
	while i <= n do
		local c = text:sub(i, i)
		if c:find("%s") then
			i = i + 1
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

- [ ] **Step 4: Add it to the TOC** (append to `# Engine`): `Engine/Query/Lexer.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/query_lexer_spec.lua`
Expected: `7 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `0 failed` and `ALL CHECKS PASSED` (`123 passed` when run in numeric order).

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Engine/Query/Lexer.lua SwagBag/SwagBag.toc spec/query_lexer_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add query tokenizer with character spans" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Query parser (precedence ! > & > |, phrases, positioned errors)

**Files:**
- Create: `SwagBag/Engine/Query/Parser.lua`, `spec/query_parser_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/Query/Parser.lua`)
- Test: `spec/query_parser_spec.lua`

**Interfaces:**
- Consumes: `SB.QueryLexer.Tokenize` (Task 14).
- Produces:
  - `SB.QueryParser.Parse(text)` returns an AST, or `nil, {position, expected, got, after}`.
  - The `expected` codes are `VALUE`, `NUMBER`, `RPAREN`, `QUOTE`, `KEYWORD` and `OPERATOR`.
  - AST nodes (all with `s`, `e`): `{type="or"|"and", items}`, `{type="not", item}`, `{type="word", value}` (a bare word, or adjacent words joined by single spaces), `{type="exact", value}` (`#word`), `{type="text", value}` (quoted), and `{type="num", name, op, value=number, raw=string}`.

- [ ] **Step 1: Write the failing test** (`spec/query_parser_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")

-- Remove spans so tree shapes are easy to compare.
local function strip(node)
	if type(node) ~= "table" then
		return node
	end
	local out = {}
	for k, v in pairs(node) do
		if k ~= "s" and k ~= "e" then
			out[k] = strip(v)
		end
	end
	return out
end

local function W(v) return { type = "word", value = v } end

describe("Query parser", function()
	local P
	before_each(function()
		local SB = Loader.New({ "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua" })
		P = SB.QueryParser
	end)

	local function parse(text)
		return strip((P.Parse(text)))
	end

	it("parses a single word with its span", function()
		assert.same({ type = "word", value = "gear", s = 1, e = 4 }, P.Parse("gear"))
	end)

	it("joins adjacent words into one phrase", function()
		assert.same({ type = "word", value = "healing potion", s = 1, e = 15 }, P.Parse("healing  potion"))
	end)

	it("parses quoted text, #exact and numeric terms", function()
		assert.same({ type = "text", value = "Healing Potion" }, parse("\"Healing Potion\""))
		assert.same({ type = "exact", value = "rune" }, parse("#rune"))
		assert.same({ type = "num", name = "ilvl", op = ">=", value = 250, raw = "250" }, parse("ilvl >= 250"))
	end)

	it("gives & precedence over |", function()
		assert.same({ type = "or", items = { W("a"), { type = "and", items = { W("b"), W("c") } } } }, parse("a | b & c"))
	end)

	it("gives ! precedence over &", function()
		assert.same({ type = "and", items = { { type = "not", item = W("a") }, W("b") } }, parse("!a & b"))
	end)

	it("lets parentheses override precedence", function()
		assert.same({ type = "and", items = { { type = "or", items = { W("a"), W("b") } }, W("c") } }, parse("(a | b) & c"))
	end)

	it("flattens chains of the same operator", function()
		assert.same({ type = "and", items = { W("a"), W("b"), W("c") } }, parse("a & b & c"))
	end)

	it("records spans on combined nodes", function()
		local ast = P.Parse("boe & ilvl>250")
		assert.equal(1, ast.s)
		assert.equal(14, ast.e)
		assert.equal(7, ast.items[2].s)
	end)

	it("reports a missing value after & with position and the token before", function()
		local ast, err = P.Parse("boe &")
		assert.is_nil(ast)
		assert.same({ position = 6, expected = "VALUE", got = "", after = "&" }, err)
	end)

	it("reports a missing or bad number after an operator", function()
		local _, err = P.Parse("ilvl>")
		assert.same({ position = 6, expected = "NUMBER", got = "", after = ">" }, err)
		_, err = P.Parse("ilvl>abc")
		assert.same({ position = 6, expected = "NUMBER", got = "abc", after = ">" }, err)
	end)

	it("reports unbalanced and empty parentheses", function()
		local _, err = P.Parse("(boe")
		assert.same({ position = 5, expected = "RPAREN", got = "", after = "boe" }, err)
		_, err = P.Parse("()")
		assert.same({ position = 2, expected = "VALUE", got = ")", after = "(" }, err)
		_, err = P.Parse("boe)")
		assert.same({ position = 4, expected = "OPERATOR", got = ")", after = "boe" }, err)
	end)

	it("reports # without a keyword and passes lexer errors through", function()
		local _, err = P.Parse("# & boe")
		assert.same({ position = 3, expected = "KEYWORD", got = "&", after = "#" }, err)
		_, err = P.Parse("\"open")
		assert.same({ position = 6, expected = "QUOTE", got = "" }, err)
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/query_parser_spec.lua`
Expected: `0 passed, 12 failed`. The failures contain `cannot open SwagBag/Engine/Query/Parser.lua`.

- [ ] **Step 3: Write `SwagBag/Engine/Query/Parser.lua`**

```lua
-- SwagBag query parser (spec 7.2). Pure Lua. Precedence: ! > & > | ; parentheses override.
--   or      := and ( "|" and )*
--   and     := not ( "&" not )*
--   not     := "!" not | primary
--   primary := "(" or ")" | STRING | "#" phrase | phrase [ OP NUMBER ]
--   phrase  := WORD+            adjacent words form ONE phrase (spec 7.5 #1)
-- AST nodes (every node has a 1-based character span s..e):
--   { type = "or" | "and", items = {...} }      { type = "not", item = node }
--   { type = "word", value }   bare word/phrase: keyword if registered, else name text
--   { type = "exact", value }  #word: keyword only
--   { type = "text", value }   "quoted": always name text
--   { type = "num", name, op, value = number, raw = string }
-- Parse(text) -> ast | nil, { position, expected, got, after }
local _, SB = ...

local Parser = {}
SB.QueryParser = Parser

function Parser.Parse(text)
	local tokens, lexErr = SB.QueryLexer.Tokenize(text)
	if not tokens then
		return nil, lexErr
	end
	local pos = 1

	local function peek()
		return tokens[pos]
	end

	local function fail(expected)
		local tok, prev = tokens[pos], tokens[pos - 1]
		error({
			isQueryError = true,
			position = tok.s,
			expected = expected,
			got = tok.type == "EOF" and "" or tok.value,
			after = prev and prev.value or nil,
		}, 0)
	end

	local function phrase()
		local first, last = tokens[pos], tokens[pos]
		local words = { first.value }
		pos = pos + 1
		while tokens[pos].type == "WORD" do
			last = tokens[pos]
			words[#words + 1] = last.value
			pos = pos + 1
		end
		return table.concat(words, " "), first.s, last.e
	end

	local parseOr

	local function parsePrimary()
		local tok = peek()
		if tok.type == "LPAREN" then
			pos = pos + 1
			if peek().type == "RPAREN" then
				fail("VALUE")
			end
			local inner = parseOr()
			if peek().type ~= "RPAREN" then
				fail("RPAREN")
			end
			pos = pos + 1
			return inner
		elseif tok.type == "STRING" then
			pos = pos + 1
			return { type = "text", value = tok.value, s = tok.s, e = tok.e }
		elseif tok.type == "HASH" then
			pos = pos + 1
			if peek().type ~= "WORD" then
				fail("KEYWORD")
			end
			local value, _, e = phrase()
			return { type = "exact", value = value, s = tok.s, e = e }
		elseif tok.type == "WORD" then
			local value, s, e = phrase()
			if peek().type ~= "OP" then
				return { type = "word", value = value, s = s, e = e }
			end
			local op = peek()
			pos = pos + 1
			local num = peek()
			local n = num.type == "WORD" and tonumber(num.value) or nil
			if n == nil then
				fail("NUMBER")
			end
			pos = pos + 1
			return { type = "num", name = value, op = op.value, value = n, raw = num.value, s = s, e = num.e }
		end
		fail("VALUE")
	end

	local function parseNot()
		local tok = peek()
		if tok.type == "NOT" then
			pos = pos + 1
			local item = parseNot()
			return { type = "not", item = item, s = tok.s, e = item.e }
		end
		return parsePrimary()
	end

	local function chain(kind, tokenType, sub)
		local first = sub()
		if peek().type ~= tokenType then
			return first
		end
		local node = { type = kind, items = { first }, s = first.s }
		while peek().type == tokenType do
			pos = pos + 1
			node.items[#node.items + 1] = sub()
		end
		node.e = node.items[#node.items].e
		return node
	end

	local function parseAnd()
		return chain("and", "AND", parseNot)
	end

	parseOr = function()
		return chain("or", "OR", parseAnd)
	end

	local ok, result = pcall(function()
		local ast = parseOr()
		if peek().type ~= "EOF" then
			fail("OPERATOR")
		end
		return ast
	end)
	if ok then
		return result
	end
	if type(result) == "table" and result.isQueryError then
		result.isQueryError = nil
		return nil, result
	end
	error(result, 0)
end
```

- [ ] **Step 4: Add it to the TOC** (append to `# Engine`): `Engine/Query/Parser.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/query_parser_spec.lua`
Expected: `12 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `0 failed` and `ALL CHECKS PASSED` (`135 passed` in numeric order).

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Engine/Query/Parser.lua SwagBag/SwagBag.toc spec/query_parser_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add query parser with fixed precedence, phrases and positioned errors" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Query compile/eval: registry, tri-state, cache class, Validate, Pretty

**Files:**
- Create: `SwagBag/Engine/Query/Query.lua`, `spec/query_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/Query/Query.lua`)
- Test: `spec/query_spec.lua`

**Interfaces:**
- Consumes: `SB.QueryParser.Parse` (Task 15) and `SB.L` (Task 2, for `FormatError`).
- Produces `SB.Query`:
  - `RegisterKeyword{name, aliases, class = "static"|"instance"|"volatile", eval?, value?}`. `eval(record)` returns true, false or nil. `value(record)` returns a number, false (the item has no such field) or nil (not loaded).
  - `Compile(text)` returns `{fn, cacheClass, keywords, errors, ast, id, text, empty}`.
  - `Eval(compiled, record)` returns true, false or nil.
  - `Validate(compiled)` returns `{ok, problems, warnings}`.
  - `Pretty(ast)` and `FormatError(err)`.
  - `Lookup(name)`, `ResetKeywords()` and `keywords`.
  - Bare-word rule: a registered keyword (single word or phrase) is a keyword. Anything else is a case-insensitive plain-substring match on `record.name`. A quoted string is always a name match. `#word` must be a keyword.

- [ ] **Step 1: Write the failing test** (`spec/query_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")

local FILES = { "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua" }

-- Test keywords over tiny hand-made records (independent of Engine/Keywords.lua).
local function registerTestKeywords(Q)
	Q.RegisterKeyword({ name = "boe", class = "instance", eval = function(r)
		if r.bind == nil then return nil end
		return r.bind == "equip" and not r.isBound
	end })
	Q.RegisterKeyword({ name = "potion", class = "static", eval = function(r) return r.kind == "potion" end })
	Q.RegisterKeyword({ name = "trade goods", aliases = { "tradegoods" }, class = "static",
		eval = function(r) return r.kind == "tradegoods" end })
	Q.RegisterKeyword({ name = "gear", class = "static",
		eval = function(r) return r.kind == "gear" end,
		value = function(r)
			if r.kind ~= "gear" then return false end
			return r.ilvl
		end })
	Q.RegisterKeyword({ name = "ilvl", class = "instance", value = function(r)
		if r.kind ~= "gear" then return false end
		return r.ilvl
	end })
	Q.RegisterKeyword({ name = "count", class = "volatile", value = function(r) return r.count end })
	Q.RegisterKeyword({ name = "mystery", class = "instance", eval = function() return nil end })
end

local POTION = { kind = "potion", name = "Algari Healing Potion", bind = "none", count = 5 }
local RING = { kind = "gear", name = "Band of the Fallen", bind = "equip", isBound = false, ilvl = 285, count = 1 }
local HELM = { kind = "gear", name = "Helm of Tests", bind = "pickup", isBound = true, ilvl = 270, count = 1 }
local LOADING = { kind = "gear", count = 1 } -- name, bind and ilvl not loaded yet
local HERB = { kind = "tradegoods", name = "Mycobloom", bind = "none", count = 40 }

describe("Query compile and eval", function()
	local Q
	before_each(function()
		Q = Loader.New(FILES).Query
		registerTestKeywords(Q)
	end)

	local function run(text, record)
		return Q.Eval(Q.Compile(text), record)
	end

	it("an empty search matches everything", function()
		local c = Q.Compile("   ")
		assert.truthy(c.empty)
		assert.same({}, c.errors)
		assert.equal(true, Q.Eval(c, POTION))
	end)

	it("a registered bare word is a keyword; any other word matches item names", function()
		assert.equal(true, run("potion", POTION))
		assert.equal(false, run("potion", RING))
		assert.equal(true, run("band", RING))
		assert.equal(true, run("BAND", RING))
		assert.equal(false, run("band", HELM))
	end)

	it("a multi-word phrase can be a keyword, and aliases work", function()
		assert.equal(true, run("trade goods", HERB))
		assert.equal(true, run("tradegoods", HERB))
		assert.equal(true, run("healing potion", POTION))
		assert.equal(false, run("healing potion", HERB))
	end)

	it("quoted text is always a name match, even when it equals a keyword", function()
		assert.equal(true, run("\"Potion\"", POTION))
		assert.equal(false, run("\"potion\"", { kind = "potion", name = "Flask" }))
	end)

	it("#word forces a keyword and an unknown #word is a positioned error", function()
		assert.equal(true, run("#potion", POTION))
		local c = Q.Compile("boe | #potin")
		assert.is_nil(c.fn)
		assert.same({ { position = 7, expected = "KEYWORD", got = "potin" } }, c.errors)
		assert.is_nil(Q.Eval(c, POTION))
	end)

	it("compares numbers with = < <= > >=", function()
		assert.equal(true, run("ilvl>280", RING))
		assert.equal(false, run("ilvl>285", RING))
		assert.equal(true, run("ilvl>=285", RING))
		assert.equal(true, run("ilvl<=285", RING))
		assert.equal(true, run("ilvl<300", RING))
		assert.equal(true, run("ilvl=285", RING))
		assert.equal(true, run("count>=5", POTION))
	end)

	it("a numeric test on an item without the field is false; on an unloaded item it is nil", function()
		assert.equal(false, run("ilvl>1", POTION))
		assert.is_nil(run("ilvl>1", LOADING))
		assert.equal(true, run("gear<280", HELM))
		assert.equal(false, run("gear<280", POTION))
	end)

	it("a number on a keyword that takes none is a positioned error", function()
		local c = Q.Compile("potion>3")
		assert.same({ { position = 1, expected = "NUMERIC", got = "potion" } }, c.errors)
	end)

	it("AND/OR/NOT follow tri-state rules", function()
		assert.equal(false, run("mystery & potion", RING), "false dominates AND")
		assert.is_nil(run("mystery & potion", POTION), "nil & true is nil")
		assert.equal(true, run("mystery | potion", POTION), "true dominates OR")
		assert.is_nil(run("mystery | potion", RING), "nil | false is nil")
		assert.is_nil(run("!mystery", RING))
		assert.equal(false, run("!potion", POTION))
	end)

	it("name text on an unloaded item is nil", function()
		assert.is_nil(run("band", LOADING))
		assert.is_nil(run("boe", LOADING))
	end)

	it("matches name text literally, including pattern characters, apostrophes and hyphens", function()
		local odd = { kind = "misc", name = "Kyveza's Ara-Kara Sack [50%]", count = 1 }
		assert.equal(true, run("\"[50%]\"", odd))
		assert.equal(true, run("kyveza's", odd))
		assert.equal(true, run("ara-kara", odd))
		assert.equal(false, run("\"(50%)\"", odd))
	end)

	it("takes the strongest cache class of the keywords used", function()
		assert.equal("static", Q.Compile("potion").cacheClass)
		assert.equal("static", Q.Compile("band").cacheClass)
		assert.equal("instance", Q.Compile("potion & boe").cacheClass)
		assert.equal("volatile", Q.Compile("boe | count>1").cacheClass)
	end)

	it("lists the keywords used, once each, in order", function()
		assert.same({ "boe", "potion", "ilvl" }, Q.Compile("boe & (potion | boe) & ilvl>1 & band").keywords)
	end)

	it("gives every successful compile its own id", function()
		local a, b = Q.Compile("boe"), Q.Compile("boe")
		assert.truthy(a.id ~= b.id)
	end)

	it("evaluates the spec 7.4 example on squished item levels", function()
		local c = Q.Compile("gear & ilvl>280 & !boe")
		assert.equal(false, Q.Eval(c, RING))
		assert.equal(false, Q.Eval(c, HELM))
		local c2 = Q.Compile("gear & ilvl>280 & boe")
		assert.equal(true, Q.Eval(c2, RING))
	end)
end)

describe("Query errors, Validate, Pretty, registry", function()
	local Q
	before_each(function()
		Q = Loader.New(FILES).Query
		registerTestKeywords(Q)
	end)

	it("formats positioned error messages", function()
		assert.equal("Expected a value after \"&\" at character 6", Q.FormatError(Q.Compile("boe &").errors[1]))
		assert.equal("Expected a number after \">\" at character 6", Q.FormatError(Q.Compile("ilvl>").errors[1]))
		assert.equal("Expected a closing ) after \"boe\" at character 5", Q.FormatError(Q.Compile("(boe").errors[1]))
		assert.equal("Expected & or | but found \")\" at character 4", Q.FormatError(Q.Compile("boe)").errors[1]))
		assert.equal("Expected a known keyword but found \"potin\" at character 1", Q.FormatError(Q.Compile("#potin").errors[1]))
	end)

	it("Validate accepts a good query and warns about name-text words", function()
		local report = Q.Validate(Q.Compile("(potin | boe) & !ilvl>3"))
		assert.equal(true, report.ok)
		assert.same({}, report.problems)
		assert.same({ { kind = "text", value = "potin", position = 2 } }, report.warnings)
	end)

	it("Validate reports compile errors as problems", function()
		local report = Q.Validate(Q.Compile("boe & & potion"))
		assert.equal(false, report.ok)
		assert.equal("error", report.problems[1].kind)
		assert.equal(7, report.problems[1].position)
	end)

	it("Pretty prints a canonical form", function()
		local function p(text) return Q.Pretty((Q.Compile(text)).ast) end
		assert.equal("a | b & c", p("a|b&c"))
		assert.equal("(a | b) & c", p("(a|b)&c"))
		assert.equal("!(a & b)", p("!(a&b)"))
		assert.equal("a & (b & c)", p("a&(b&c)"))
		assert.equal("#rune | \"x y\" | ilvl>=250", p("#rune|\"x y\"|ilvl >= 250"))
		assert.equal("!!healing potion", p("! ! healing   potion"))
	end)

	it("Pretty round-trips: parsing the pretty text gives the same tree", function()
		local function strip(node)
			if type(node) ~= "table" then return node end
			local out = {}
			for k, v in pairs(node) do
				if k ~= "s" and k ~= "e" then out[k] = strip(v) end
			end
			return out
		end
		local queries = {
			"gear & ilvl>280 & !bound", "(potion | flask | food) & lvl>=80", "keystone | crest",
			"junk | (gray & !quest)", "\"Healing Potion\"", "#rune", "a & (b | (c & !d)) | e",
			"!(a | b) & !c", "trade goods & count<=5 | tab=2",
		}
		for _, q in ipairs(queries) do
			local ast = Q.Compile(q).ast
			local again = Q.Compile(Q.Pretty(ast)).ast
			assert.same(strip(ast), strip(again), q)
		end
	end)

	it("RegisterKeyword rejects bad definitions", function()
		assert.has_error(function() Q.RegisterKeyword({ name = "x", eval = function() end }) end, "class")
		assert.has_error(function() Q.RegisterKeyword({ name = "x", class = "static" }) end, "eval or value")
		assert.has_error(function() Q.RegisterKeyword({ class = "static", eval = function() end }) end, "name")
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/query_spec.lua`
Expected: `0 passed, 21 failed`. The failures contain `cannot open SwagBag/Engine/Query/Query.lua`.

- [ ] **Step 3: Write `SwagBag/Engine/Query/Query.lua`**

```lua
-- SwagBag query engine (spec 7). Pure Lua.
--   Query.RegisterKeyword{ name, aliases, class, eval, value }
--       class: "static" (per itemID) | "instance" (per link) | "volatile" (never cached)
--       eval(record)  -> true | false | nil   for bare use:      boe
--       value(record) -> number | false | nil for numeric use:   ilvl>250
--                        (false = item has no such field -> comparison is false;
--                         nil = data not loaded yet -> result unknown)
--   Query.Compile(text) -> { fn, cacheClass, keywords, errors, ast, id, text, empty }
--   Query.Eval(compiled, record) -> true | false | nil   (nil when compiled has errors)
--   Query.Validate(compiled) -> { ok, problems, warnings }
--   Query.Pretty(ast) -> canonical text; Parse(Pretty(ast)) gives the same tree
--   Query.FormatError(err) -> "Expected a value after "&" at character 6"
-- Tri-state (Kleene): AND is false if any part is false, else nil if any is nil;
-- OR is true if any part is true, else nil if any is nil; NOT nil is nil.
local _, SB = ...

local Q = { keywords = {}, nextId = 0 }
SB.Query = Q

local RANK = { static = 1, instance = 2, volatile = 3 }

function Q.RegisterKeyword(def)
	if type(def) ~= "table" or type(def.name) ~= "string" then
		error("RegisterKeyword: name required", 2)
	end
	if not RANK[def.class] then
		error("RegisterKeyword: class must be static, instance or volatile", 2)
	end
	if not def.eval and not def.value then
		error("RegisterKeyword: eval or value required", 2)
	end
	local entry = { name = def.name:lower(), class = def.class, eval = def.eval, value = def.value }
	Q.keywords[entry.name] = entry
	for _, alias in ipairs(def.aliases or {}) do
		Q.keywords[alias:lower()] = entry
	end
	return entry
end

function Q.ResetKeywords()
	Q.keywords = {}
end

function Q.Lookup(name)
	return Q.keywords[name:lower()]
end

local OPS = {
	["="] = function(a, b) return a == b end,
	["<"] = function(a, b) return a < b end,
	["<="] = function(a, b) return a <= b end,
	[">"] = function(a, b) return a > b end,
	[">="] = function(a, b) return a >= b end,
}

-- Case-insensitive substring match on the item name (ASCII lower-casing only).
local function textMatcher(needle)
	needle = needle:lower()
	return function(r)
		local name = r.name
		if name == nil then
			return nil
		end
		return name:lower():find(needle, 1, true) ~= nil
	end
end

-- Build the closure tree; leaf(node) returns the function for a term node.
local function build(node, leaf)
	local t = node.type
	if t == "and" or t == "or" then
		local fns = {}
		for i, child in ipairs(node.items) do
			fns[i] = build(child, leaf)
		end
		local n = #fns
		if t == "and" then
			return function(r)
				local result = true
				for i = 1, n do
					local v = fns[i](r)
					if v == false then
						return false
					elseif v == nil then
						result = nil
					end
				end
				return result
			end
		end
		return function(r)
			local result = false
			for i = 1, n do
				local v = fns[i](r)
				if v == true then
					return true
				elseif v == nil then
					result = nil
				end
			end
			return result
		end
	elseif t == "not" then
		local f = build(node.item, leaf)
		return function(r)
			local v = f(r)
			if v == nil then
				return nil
			end
			return not v
		end
	elseif t == "all" then
		return function()
			return true
		end
	end
	return leaf(node)
end

local function unknown()
	return nil
end

function Q.Compile(text)
	text = text or ""
	local compiled = { text = text, keywords = {}, errors = {}, cacheClass = "static" }
	if not text:find("%S") then
		compiled.empty = true
		compiled.ast = { type = "all" }
		compiled.fn = function()
			return true
		end
		return compiled
	end
	local ast, err = SB.QueryParser.Parse(text)
	if not ast then
		compiled.errors[1] = err
		return compiled
	end
	compiled.ast = ast
	local seen = {}
	local function use(kw)
		if RANK[kw.class] > RANK[compiled.cacheClass] then
			compiled.cacheClass = kw.class
		end
		if not seen[kw.name] then
			seen[kw.name] = true
			compiled.keywords[#compiled.keywords + 1] = kw.name
		end
	end
	local function fail(node, expected, got)
		compiled.errors[#compiled.errors + 1] = { position = node.s, expected = expected, got = got }
	end
	local fn = build(ast, function(node)
		if node.type == "word" or node.type == "exact" then
			local kw = Q.keywords[node.value:lower()]
			if kw and kw.eval then
				use(kw)
				return kw.eval
			end
			if node.type == "exact" then
				fail(node, "KEYWORD", node.value)
				return unknown
			end
			return textMatcher(node.value)
		elseif node.type == "text" then
			return textMatcher(node.value)
		end
		-- numeric
		local kw = Q.keywords[node.name:lower()]
		if not (kw and kw.value) then
			fail(node, "NUMERIC", node.name)
			return unknown
		end
		use(kw)
		local get, cmp, target = kw.value, OPS[node.op], node.value
		return function(r)
			local v = get(r)
			if v == nil then
				return nil
			elseif v == false then
				return false
			end
			return cmp(v, target)
		end
	end)
	if #compiled.errors > 0 then
		return compiled
	end
	Q.nextId = Q.nextId + 1
	compiled.id = Q.nextId
	compiled.fn = fn
	return compiled
end

function Q.Eval(compiled, record)
	if not compiled.fn then
		return nil
	end
	return compiled.fn(record)
end

function Q.FormatError(err)
	local L = SB.L
	local expect = L["QUERY_EXPECT_" .. err.expected]
	if err.after and err.got == "" then
		return L.QUERY_ERR_AFTER:format(expect, err.after, err.position)
	end
	local found = err.got == "" and L.QUERY_FOUND_END or ("\"" .. err.got .. "\"")
	return L.QUERY_ERR_FOUND:format(expect, found, err.position)
end

local function walk(node, fn)
	fn(node)
	if node.items then
		for _, child in ipairs(node.items) do
			walk(child, fn)
		end
	elseif node.item then
		walk(node.item, fn)
	end
end

local VALIDATE_MODES = { { name = "true", value = true }, { name = "false", value = false }, { name = "nil" } }

-- Spec 7.9: run the combinators with every leaf forced to true, false and nil;
-- each run must finish and return true, false or nil. Also warn about bare words
-- that are not keywords (they match item names).
function Q.Validate(compiled)
	local report = { ok = true, problems = {}, warnings = {} }
	if not compiled.fn then
		report.ok = false
		for _, err in ipairs(compiled.errors) do
			report.problems[#report.problems + 1] = { kind = "error", position = err.position, message = Q.FormatError(err) }
		end
		return report
	end
	for _, mode in ipairs(VALIDATE_MODES) do
		local leafValue = mode.value
		local fn = build(compiled.ast, function()
			return function()
				return leafValue
			end
		end)
		local ok, result = pcall(fn, {})
		if not ok then
			report.ok = false
			report.problems[#report.problems + 1] = { kind = "crash", leaf = mode.name, message = tostring(result) }
		elseif result ~= true and result ~= false and result ~= nil then
			report.ok = false
			report.problems[#report.problems + 1] = { kind = "value", leaf = mode.name, message = tostring(result) }
		end
	end
	walk(compiled.ast, function(node)
		if node.type == "word" then
			local kw = Q.keywords[node.value:lower()]
			if not (kw and kw.eval) then
				report.warnings[#report.warnings + 1] = { kind = "text", value = node.value, position = node.s }
			end
		end
	end)
	return report
end

local PREC = { ["or"] = 1, ["and"] = 2, ["not"] = 3 }

local function prec(node)
	return PREC[node.type] or 4
end

local function pretty(node)
	local t = node.type
	if t == "all" then
		return ""
	elseif t == "word" then
		return node.value
	elseif t == "exact" then
		return "#" .. node.value
	elseif t == "text" then
		return "\"" .. node.value .. "\""
	elseif t == "num" then
		return node.name .. node.op .. node.raw
	elseif t == "not" then
		local inner = pretty(node.item)
		if prec(node.item) < PREC["not"] then
			inner = "(" .. inner .. ")"
		end
		return "!" .. inner
	end
	local parts = {}
	for i, child in ipairs(node.items) do
		local s = pretty(child)
		if prec(child) < prec(node) or child.type == t then
			s = "(" .. s .. ")"
		end
		parts[i] = s
	end
	return table.concat(parts, t == "and" and " & " or " | ")
end

function Q.Pretty(ast)
	return pretty(ast)
end
```

- [ ] **Step 4: Add it to the TOC** (append to `# Engine`): `Engine/Query/Query.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/query_spec.lua`
Expected: `21 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `0 failed` and `ALL CHECKS PASSED` (`156 passed` in numeric order).

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Engine/Query/Query.lua SwagBag/SwagBag.toc spec/query_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add query compiler with tri-state eval, cache classes, Validate and Pretty" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: v1.0 keyword table (week-1 families)

**Files:**
- Create: `SwagBag/Engine/Keywords.lua`, `spec/keywords_spec.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# Engine`: `Engine/Keywords.lua`; it must come after `Engine/Query/Query.lua`)
- Test: `spec/keywords_spec.lua`

**Interfaces:**
- Consumes: `SB.Query.RegisterKeyword` (Task 16), the `SB.Adapter.ITEM_CLASS`/`*_SUB` constants (Task 6), the item record shape from `SB.Items.Describe` (Task 9), and `spec/fixtures/items.lua` (Task 9).
- Produces: `SB.Keywords.RegisterAll()`, which runs at load. The registered keywords:
  - Type: armor, weapon, gear (+ `gear<N`), consumable, potion, flask, food/drink, elixir, rune, reagent, tradegoods/"trade goods", herb, ore, leather, cloth, enchanting, cooking, gem, recipe, questitem/quest, key, keystone, pet, mount, toy, housing/decor, cosmetic, container, miscellaneous, junk, "profession tool", "profession gear".
  - Slot: head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, finger, trinket, mainhand, offhand, twohand, ranged, shirt, tabard, bag.
  - Quality: poor/gray/grey, common/white, uncommon/green, rare/blue, epic/purple, legendary/orange, artifact, heirloom.
  - Binding: boe, bop, warbound/boa, wue, bound, soulbound, tradeable.
  - Numeric: ilvl, level/lvl, count, stack, tab.
  - State: new, locked, cooldown, usable, equipped, upgrade, partial.
  - Location: bags, backpack, reagentbag, bank, warband.
  - Deferred to later weeks (they need later modules): expansion, gold/value, crafting quality, collection, crest/upgrade currency.

- [ ] **Step 1: Write the failing test** (`spec/keywords_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
}

-- Backpack after setup:
--  1 healing potion x5   2 flask x2 (cooldown)   3 BoE ring 285 (upgrade)   4 soulbound helm 270 (in set)
--  5 keystone            6 junk x3               7 herb x40                 8 ore x10
--  9 caged pet          10 toy (locked)         11 quest item              12 unloaded chest
-- 13 bag item           14 warbound-until-equip ring
-- Reagent bag (5) slot 1 herb; character bank tab 2 (bag 7) slot 3 ore; warband tab 2 (bag 13) slot 1 ore.
local function setup(A)
	Fixtures.SmallBags(A)
	A.Put(0, 7, Fixtures.HERB, 40)
	A.Put(0, 8, Fixtures.ORE, 10)
	A.Put(0, 9, Fixtures.PET_CAGE, 1, { link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r" })
	A.Put(0, 10, Fixtures.TOY, 1, { isLocked = true })
	A.Put(0, 11, Fixtures.QUEST, 1, { quest = true })
	A.Put(0, 12, Fixtures.UNLOADED, 1)
	A.Put(0, 13, Fixtures.BAG, 1)
	A.Put(0, 14, Fixtures.BOE_RING, 1, { isWUE = true })
	A.SetBagSize(5, 36)
	A.Put(5, 1, Fixtures.HERB, 12)
	A.SetBagSize(7, 98)
	A.Put(7, 3, Fixtures.ORE, 10)
	A.SetBagSize(13, 98)
	A.Put(13, 1, Fixtures.ORE, 10)
end

describe("Keywords (v1.0, week-1 families)", function()
	local SB, Q
	before_each(function()
		SB = Loader.New(FILES)
		Q = SB.Query
		setup(SB.Adapter)
	end)

	-- Which of the given backpack slots match the query.
	local function matching(query, slots, bag)
		local compiled = Q.Compile(query)
		assert.same({}, compiled.errors, query)
		local out = {}
		for _, slot in ipairs(slots) do
			if Q.Eval(compiled, SB.Items.Describe(bag or 0, slot)) == true then
				out[#out + 1] = slot
			end
		end
		return out
	end
	local ALL = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 }

	it("type: consumables", function()
		assert.same({ 1 }, matching("potion", ALL))
		assert.same({ 2 }, matching("flask", ALL))
		assert.same({ 1, 2 }, matching("consumable", ALL))
	end)

	it("type: gear, armor, weapon", function()
		assert.same({ 3, 4, 12, 14 }, matching("gear", ALL))
		assert.same({ 3, 4, 12, 14 }, matching("armor", ALL))
		assert.same({}, matching("weapon", ALL))
	end)

	it("type: trade goods, herb, ore, reagent", function()
		assert.same({ 7, 8 }, matching("trade goods", ALL))
		assert.same({ 7, 8 }, matching("tradegoods", ALL))
		assert.same({ 7 }, matching("herb", ALL))
		assert.same({ 8 }, matching("ore", ALL))
		assert.same({ 5, 7, 8 }, matching("reagent", ALL))
	end)

	it("type: keystone, pet, toy, quest, container, junk", function()
		assert.same({ 5 }, matching("keystone", ALL))
		assert.same({ 9 }, matching("pet", ALL))
		assert.same({ 10 }, matching("toy", ALL))
		assert.same({ 11 }, matching("quest", ALL))
		assert.same({ 13 }, matching("container", ALL))
		assert.same({ 6 }, matching("junk", ALL))
	end)

	it("slot keywords use the equip location", function()
		assert.same({ 3, 14 }, matching("finger", ALL))
		assert.same({ 4 }, matching("head", ALL))
		assert.same({ 12 }, matching("chest", ALL))
		assert.same({ 13 }, matching("bag", ALL))
	end)

	it("quality keywords and colour aliases", function()
		assert.same({ 3, 5, 14 }, matching("epic", ALL))
		assert.same({ 6 }, matching("gray", ALL))
		assert.same({ 6 }, matching("poor", ALL))
		assert.same({ 2, 4, 9, 10 }, matching("rare", ALL))
	end)

	it("binding keywords", function()
		assert.same({ 3, 13 }, matching("boe", ALL))
		assert.same({ 4, 5, 10 }, matching("bop", ALL))
		assert.same({ 4, 5 }, matching("bound", ALL))
		assert.same({ 4, 5 }, matching("soulbound", ALL))
		assert.same({ 14 }, matching("warbound", ALL))
		assert.same({ 14 }, matching("wue", ALL))
		assert.same({ 1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14 }, matching("tradeable", ALL))
	end)

	it("numeric keywords", function()
		assert.same({ 3, 14 }, matching("ilvl>280", ALL))
		assert.same({ 4 }, matching("gear<280", ALL))
		assert.same({ 3, 4, 14 }, matching("lvl>=80", ALL))
		assert.same({ 1, 2 }, matching("level=71", ALL))
		assert.same({ 1, 7, 8 }, matching("count>=5", ALL))
		assert.same({ 7, 8 }, matching("stack>=1000", ALL))
	end)

	it("state keywords", function()
		assert.same({ 2 }, matching("cooldown", ALL))
		assert.same({ 3 }, matching("upgrade", ALL))
		assert.same({ 4 }, matching("equipped", ALL))
		assert.same({ 1, 2 }, matching("usable", ALL))
		assert.same({ 10 }, matching("locked", ALL))
		assert.same({ 1, 2, 6, 7, 8 }, matching("partial", ALL))
		assert.same({}, matching("new", ALL))
	end)

	it("location keywords and tab=N", function()
		assert.same({ 1 }, matching("backpack & potion", { 1 }))
		assert.same({ 1 }, matching("reagentbag", { 1 }, 5))
		assert.same({ 1 }, matching("bags", { 1 }, 5))
		assert.same({ 3 }, matching("bank & tab=2", { 3 }, 7))
		assert.same({ 1 }, matching("warband & tab=2", { 1 }, 13))
		assert.same({}, matching("bank", { 1 }, 13))
	end)

	it("an unloaded item gives nil for loaded-only facts, but instant facts still work", function()
		local r = SB.Items.Describe(0, 12)
		assert.equal(true, Q.Eval(Q.Compile("armor"), r))
		assert.equal(true, Q.Eval(Q.Compile("chest"), r))
		assert.is_nil(Q.Eval(Q.Compile("boe"), r))
		assert.is_nil(Q.Eval(Q.Compile("epic"), r))
		assert.is_nil(Q.Eval(Q.Compile("ilvl>1"), r))
		assert.is_nil(Q.Eval(Q.Compile("level>1"), r))
		assert.is_nil(Q.Eval(Q.Compile("partial"), r))
	end)

	it("evaluates the spec 7.4 examples", function()
		assert.same({ 3 }, matching("gear & ilvl>280 & !bound & !wue", ALL))
		assert.same({ 5 }, matching("keystone | crest", ALL))
		assert.same({ 6 }, matching("junk | (gray & !quest)", ALL))
		assert.same({ 1 }, matching("\"Healing Potion\"", ALL))
	end)

	it("every keyword returns only true/false/nil (eval) or number/false/nil (value) on every record", function()
		local records = {}
		for _, slot in ipairs(ALL) do
			records[#records + 1] = SB.Items.Describe(0, slot)
		end
		records[#records + 1] = SB.Items.Describe(5, 1)
		records[#records + 1] = SB.Items.Describe(7, 3)
		for name, kw in pairs(Q.keywords) do
			for _, r in ipairs(records) do
				if kw.eval then
					local v = kw.eval(r)
					assert.truthy(v == true or v == false or v == nil, name .. " eval returned " .. tostring(v))
				end
				if kw.value then
					local v = kw.value(r)
					assert.truthy(type(v) == "number" or v == false or v == nil, name .. " value returned " .. tostring(v))
				end
			end
		end
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/keywords_spec.lua`
Expected: `0 passed, 13 failed`. The failures contain `cannot open SwagBag/Engine/Keywords.lua`.

- [ ] **Step 3: Write `SwagBag/Engine/Keywords.lua`**

```lua
-- SwagBag v1.0 keyword table, week-1 families (spec 7.3): type, slot, quality,
-- binding, numeric (ilvl, lvl/level, gear, count, stack, tab), state, location.
-- Every keyword reads ONLY the item record from Engine/Items.lua.
-- Not yet registered (need later modules): expansion, gold/value, crafting quality,
-- collection, crest / upgrade currency.
local _, SB = ...

local K = {}
SB.Keywords = K

local function has(list)
	local set = {}
	for _, v in ipairs(list) do
		set[v] = true
	end
	return set
end

function K.RegisterAll()
	local Q, A = SB.Query, SB.Adapter
	local C, CS, TS, MS, AS = A.ITEM_CLASS, A.CONSUMABLE_SUB, A.TRADEGOODS_SUB, A.MISC_SUB, A.ARMOR_SUB

	local function kw(name, class, eval, aliases)
		Q.RegisterKeyword({ name = name, class = class, eval = eval, aliases = aliases })
	end
	local function num(name, class, value, aliases)
		Q.RegisterKeyword({ name = name, class = class, value = value, aliases = aliases })
	end
	local function classIs(id)
		return function(r)
			return id ~= nil and r.classID == id
		end
	end
	local function subIs(classID, subID)
		return function(r)
			return r.classID == classID and subID ~= nil and r.subclassID == subID
		end
	end
	local function isGear(r)
		return r.classID == C.Armor or r.classID == C.Weapon
	end

	-- Type (static: item class/subclass from the instant item info) -----------
	kw("armor", "static", classIs(C.Armor))
	kw("weapon", "static", classIs(C.Weapon))
	Q.RegisterKeyword({
		name = "gear",
		class = "instance",
		eval = isGear,
		value = function(r) -- gear<210: equippable gear under an item level
			if not isGear(r) then
				return false
			end
			return r.ilvl
		end,
	})
	kw("consumable", "static", classIs(C.Consumable))
	kw("potion", "static", subIs(C.Consumable, CS.Potion))
	kw("flask", "static", subIs(C.Consumable, CS.Flask))
	kw("food", "static", subIs(C.Consumable, CS.FoodDrink), { "drink" })
	kw("elixir", "static", subIs(C.Consumable, CS.Elixir))
	kw("rune", "static", subIs(C.Consumable, CS.VantusRune))
	kw("reagent", "static", function(r)
		if r.classID == C.Reagent then
			return true
		end
		if r.pending then
			return nil
		end
		return r.isCraftingReagent == true
	end)
	kw("tradegoods", "static", classIs(C.Tradegoods), { "trade goods" })
	kw("herb", "static", subIs(C.Tradegoods, TS.Herb))
	kw("ore", "static", subIs(C.Tradegoods, TS.MetalStone))
	kw("leather", "static", subIs(C.Tradegoods, TS.Leather))
	kw("cloth", "static", subIs(C.Tradegoods, TS.Cloth))
	kw("enchanting", "static", subIs(C.Tradegoods, TS.Enchanting))
	kw("cooking", "static", subIs(C.Tradegoods, TS.Cooking))
	kw("gem", "static", classIs(C.Gem))
	kw("recipe", "static", classIs(C.Recipe))
	kw("questitem", "static", function(r)
		return r.isQuestItem == true
	end, { "quest" })
	kw("key", "static", classIs(C.Key))
	kw("keystone", "instance", function(r)
		return r.isKeystone == true
	end)
	kw("pet", "instance", function(r)
		return r.isCagedPet == true or r.classID == C.Battlepet
			or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet)
	end)
	kw("mount", "static", subIs(C.Miscellaneous, MS.Mount))
	kw("toy", "static", function(r)
		return r.isToy == true
	end)
	kw("housing", "static", classIs(C.Housing), { "decor" })
	kw("cosmetic", "static", subIs(C.Armor, AS.Cosmetic))
	kw("container", "static", classIs(C.Container))
	kw("miscellaneous", "static", classIs(C.Miscellaneous))
	kw("junk", "static", function(r)
		if r.quality == nil then
			return nil
		end
		return r.quality == 0
	end)
	kw("profession tool", "static", function(r)
		return r.equipLoc == "INVTYPE_PROFESSION_TOOL"
	end)
	kw("profession gear", "static", function(r)
		return r.equipLoc == "INVTYPE_PROFESSION_GEAR"
	end)

	-- Slot (static, equip location) -------------------------------------------
	local SLOTS = {
		head = { "INVTYPE_HEAD" }, neck = { "INVTYPE_NECK" }, shoulder = { "INVTYPE_SHOULDER" },
		back = { "INVTYPE_CLOAK" }, chest = { "INVTYPE_CHEST", "INVTYPE_ROBE" }, wrist = { "INVTYPE_WRIST" },
		hands = { "INVTYPE_HAND" }, waist = { "INVTYPE_WAIST" }, legs = { "INVTYPE_LEGS" },
		feet = { "INVTYPE_FEET" }, finger = { "INVTYPE_FINGER" }, trinket = { "INVTYPE_TRINKET" },
		mainhand = { "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPON" },
		offhand = { "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" },
		twohand = { "INVTYPE_2HWEAPON" }, ranged = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" },
		shirt = { "INVTYPE_BODY" }, tabard = { "INVTYPE_TABARD" }, bag = { "INVTYPE_BAG" },
	}
	for name, locs in pairs(SLOTS) do
		local set = has(locs)
		kw(name, "static", function(r)
			return set[r.equipLoc] == true
		end)
	end

	-- Quality (instance, from the link) ---------------------------------------
	local QUALITY = {
		{ "poor", 0, { "gray", "grey" } }, { "common", 1, { "white" } }, { "uncommon", 2, { "green" } },
		{ "rare", 3, { "blue" } }, { "epic", 4, { "purple" } }, { "legendary", 5, { "orange" } },
		{ "artifact", 6 }, { "heirloom", 7 },
	}
	for _, q in ipairs(QUALITY) do
		local value = q[2]
		kw(q[1], "instance", function(r)
			if r.quality == nil then
				return nil
			end
			return r.quality == value
		end, q[3])
	end

	-- Binding (instance) -------------------------------------------------------
	local ACCOUNT = has({ "account", "warbound", "wue" })
	local function bindKnown(test)
		return function(r)
			if r.bind == nil then
				return nil
			end
			return test(r)
		end
	end
	kw("boe", "instance", bindKnown(function(r)
		return not r.isBound and not r.isWUE and r.bind == "equip"
	end))
	kw("bop", "instance", bindKnown(function(r)
		return r.bind == "pickup"
	end))
	kw("warbound", "instance", bindKnown(function(r)
		return ACCOUNT[r.bind] == true or r.isWUE == true
	end), { "boa" })
	kw("wue", "instance", function(r)
		return r.isWUE == true or (r.bind == "wue" and not r.isBound)
	end)
	kw("bound", "instance", function(r)
		return r.isBound == true
	end)
	kw("soulbound", "instance", bindKnown(function(r)
		return r.isBound == true and not ACCOUNT[r.bind]
	end))
	kw("tradeable", "instance", function(r)
		return not r.isBound
	end)

	-- Numeric -------------------------------------------------------------------
	num("ilvl", "instance", function(r)
		if not isGear(r) then
			return false
		end
		return r.ilvl
	end)
	num("level", "instance", function(r)
		if r.pending then
			return nil
		end
		return r.reqLevel or false
	end, { "lvl" })
	num("count", "volatile", function(r)
		return r.count
	end)
	num("stack", "volatile", function(r)
		if r.pending then
			return nil
		end
		return r.maxStack or false
	end)
	num("tab", "volatile", function(r)
		return r.tab or false
	end)

	-- State (volatile) ---------------------------------------------------------
	local function flag(field)
		return function(r)
			return r[field] == true
		end
	end
	kw("new", "volatile", flag("isNew"))
	kw("locked", "volatile", flag("isLocked"))
	kw("cooldown", "volatile", flag("onCooldown"))
	kw("usable", "volatile", flag("isUsable"))
	kw("equipped", "volatile", flag("inEquipmentSet"))
	kw("upgrade", "volatile", flag("hasUpgradeTrack"))
	kw("partial", "volatile", function(r)
		if r.pending then
			return nil
		end
		return (r.maxStack or 1) > 1 and r.count < r.maxStack
	end)

	-- Location (volatile, slot-bound) -----------------------------------------
	local BAGS = has({ "backpack", "bags", "reagentbag" })
	kw("bags", "volatile", function(r)
		return BAGS[r.location] == true
	end)
	kw("backpack", "volatile", function(r)
		return r.location == "backpack"
	end)
	kw("reagentbag", "volatile", function(r)
		return r.location == "reagentbag"
	end)
	kw("bank", "volatile", function(r)
		return r.location == "bank"
	end)
	kw("warband", "volatile", function(r)
		return r.location == "warband"
	end)
end

K.RegisterAll()
```

- [ ] **Step 4: Add it to the TOC** (append to `# Engine`, after `Engine/Query/Query.lua`): `Engine/Keywords.lua`

- [ ] **Step 5: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/keywords_spec.lua`
Expected: `13 passed, 0 failed`

- [ ] **Step 6: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (24 files)`, `169 passed, 0 failed`, `ALL CHECKS PASSED` (in numeric order).

- [ ] **Step 7: Commit**

```bash
git add SwagBag/Engine/Keywords.lua SwagBag/SwagBag.toc spec/keywords_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add v1.0 keywords: type, slot, quality, binding, numeric, state, location" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: Search (full dim, inline errors) and in-game session D4

**Files:**
- Create: `SwagBag/Engine/Search.lua`, `spec/search_spec.lua`, `SwagBag/UI/SearchBox.lua`
- Modify: `SwagBag/SwagBag.toc` (append `Engine/Search.lua` to `# Engine` and `UI/SearchBox.lua` to `# UI`)
- Test: `spec/search_spec.lua`, plus in-game session D4

**Interfaces:**
- Consumes: `SB.Query.Compile/Eval/FormatError` (Task 16), the keywords (Task 17), `SB.BagsWindow.frame/IsOpen/ForEachSlot` plus the `SB_BAGS_LAYOUT`/`SB_BAGS_UPDATED` events (Task 12), `SB.Buttons.SetDimmed` (Task 11), `SB.Debounce/On` (Task 4), `SB.Slash.Register` (Task 7), and the Blizzard template `SearchBoxTemplate`.
- Produces:
  - `SB.Search.SetText(text)` returns true, or `false, message`. On an error the previous valid search stays.
  - `SB.Search.IsActive()` and `SB.Search.Apply(forEach, setDimmed)` (returns matches, total and ms). Also the fields `active`, `text`, `lastError` and `stats`.
  - `SB.SearchBox.Run/Apply/ShowError/ClearError` and `editBox`.
  - The command `/swagbag search <text>`.

- [ ] **Step 1: Write the failing test** (`spec/search_spec.lua`)

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua",
}

describe("Search", function()
	local SB, S, slots, dimmed
	before_each(function()
		SB = Loader.New(FILES)
		S = SB.Search
		Fixtures.SmallBags(SB.Adapter)
		SB.Adapter.Put(0, 7, Fixtures.UNLOADED, 1)
		slots = {}
		for slot = 1, 8 do -- 1-6 items, 7 unloaded, 8 empty
			slots[slot] = { button = "b" .. slot, record = SB.Items.Describe(0, slot) }
		end
		dimmed = {}
	end)

	local function forEach(fn)
		for _, s in ipairs(slots) do
			fn(s.button, s.record)
		end
	end
	local function setDimmed(button, d)
		dimmed[button] = d
	end
	local function dimList()
		local out = {}
		for slot = 1, 8 do
			if dimmed["b" .. slot] then
				out[#out + 1] = slot
			end
		end
		return out
	end

	it("with no search nothing is dimmed", function()
		assert.truthy(S.SetText(""))
		assert.falsy(S.IsActive())
		local matches, total = S.Apply(forEach, setDimmed)
		assert.equal(8, matches)
		assert.equal(8, total)
		assert.same({}, dimList())
	end)

	it("dims everything that is not a definite match, including empty and unloaded slots", function()
		assert.truthy(S.SetText("gear"))
		local matches, total = S.Apply(forEach, setDimmed)
		assert.equal(3, matches) -- ring, helm, and the unloaded chest (armor is an instant fact)
		assert.equal(8, total)
		assert.same({ 1, 2, 5, 6, 8 }, dimList())
		S.SetText("boe")
		S.Apply(forEach, setDimmed)
		assert.same({ 1, 2, 4, 5, 6, 7, 8 }, dimList(), "unloaded item's boe is unknown -> dimmed")
	end)

	it("keeps the previous valid search when the new text has an error", function()
		S.SetText("potion")
		local ok, message = S.SetText("potion &")
		assert.falsy(ok)
		assert.equal("Expected a value after \"&\" at character 9", message)
		assert.equal(9, S.lastError.position)
		assert.equal("potion", S.text)
		S.Apply(forEach, setDimmed)
		assert.same({ 2, 3, 4, 5, 6, 7, 8 }, dimList())
	end)

	it("a valid search after an error clears the error", function()
		S.SetText("(junk")
		assert.truthy(S.lastError)
		assert.truthy(S.SetText("junk"))
		assert.is_nil(S.lastError)
	end)

	it("re-evaluates 200 slots well under the 4 ms budget (spec AC5.4)", function()
		local many = {}
		for i = 1, 200 do
			many[i] = slots[(i % 7) + 1].record
		end
		S.SetText("(gear & ilvl>280 & !bound) | potion | \"tooth\"")
		local t0 = os.clock()
		for _ = 1, 10 do
			for i = 1, 200 do
				SB.Query.Eval(S.active, many[i])
			end
		end
		local perPassMs = (os.clock() - t0) * 1000 / 10
		assert.truthy(perPassMs < 4, ("%.3f ms per 200 slots"):format(perPassMs))
	end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `luajit spec/runner.lua spec/search_spec.lua`
Expected: `0 passed, 5 failed`. The failures contain `cannot open SwagBag/Engine/Search.lua`.

- [ ] **Step 3: Write `SwagBag/Engine/Search.lua`**

```lua
-- SwagBag search state (spec F5), pure. The search box (UI/SearchBox.lua) feeds text
-- in; Apply dims every slot that is not a definite match. Search never moves items.
-- A text with errors is rejected and the previous valid search stays applied (AC5.3).
local _, SB = ...

local S = { active = nil, text = "", lastError = nil, stats = {} }
SB.Search = S

-- Returns true, or false + formatted error message.
function S.SetText(text)
	local compiled = SB.Query.Compile(text or "")
	if not compiled.fn then
		S.lastError = compiled.errors[1]
		return false, SB.Query.FormatError(S.lastError)
	end
	S.active, S.text, S.lastError = compiled, text or "", nil
	return true
end

function S.IsActive()
	return S.active ~= nil and not S.active.empty
end

-- forEach(fn) calls fn(button, record-or-nil) for every slot in the window;
-- setDimmed(button, dimmed). Unknown (nil) results and empty slots are dimmed
-- while a search is active. Returns matches, total, milliseconds.
function S.Apply(forEach, setDimmed)
	local A = SB.Adapter
	local t0 = A.ProfileMs()
	local c = S.IsActive() and S.active or nil
	local matches, total = 0, 0
	forEach(function(button, record)
		total = total + 1
		local match = c == nil or (record ~= nil and SB.Query.Eval(c, record) == true)
		if match then
			matches = matches + 1
		end
		setDimmed(button, not match)
	end)
	S.stats.lastMs = A.ProfileMs() - t0
	S.stats.lastMatches, S.stats.lastTotal = matches, total
	return matches, total, S.stats.lastMs
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `luajit spec/runner.lua spec/search_spec.lua`
Expected: `5 passed, 0 failed`

- [ ] **Step 5: Write `SwagBag/UI/SearchBox.lua`** (WoW-only)

```lua
-- SwagBag search box on the bags window (spec F5). Typing re-applies the search
-- 150 ms after the last keystroke. A parse error shows a red message and a red
-- underline under the offending characters; the previous valid search stays.
local _, SB = ...

local L = SB.L
local Box = {}
SB.SearchBox = Box

local W = SB.BagsWindow
local Guard = SB.ErrorTrap.Guard

local box = CreateFrame("EditBox", "SwagBagBagsSearchBox", W.frame, "SearchBoxTemplate")
box:SetSize(200, 20)
box:SetPoint("TOPLEFT", 14, -30)
box:SetAutoFocus(false)
Box.editBox = box

local errorLine = W.frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
errorLine:SetPoint("LEFT", box, "RIGHT", 8, 0)
errorLine:SetPoint("RIGHT", W.frame, "RIGHT", -8, 0)
errorLine:SetJustifyH("LEFT")
errorLine:SetWordWrap(false)

local underline = box:CreateTexture(nil, "OVERLAY")
underline:SetColorTexture(1, 0.25, 0.25, 1)
underline:SetHeight(2)
underline:Hide()

local measure = box:CreateFontString(nil, "OVERLAY")
measure:SetFontObject(box:GetFontObject())
measure:Hide()

local function textWidth(text)
	measure:SetText(text)
	return measure:GetStringWidth()
end

function Box.ClearError()
	errorLine:SetText("")
	underline:Hide()
end

-- Underline err.got (or one space at the end of the text) in red.
function Box.ShowError(text, err)
	errorLine:SetText(SB.Query.FormatError(err))
	local left = box:GetTextInsets()
	local prefix = text:sub(1, err.position - 1)
	local span = err.got ~= "" and err.got or " "
	underline:ClearAllPoints()
	underline:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", (left or 0) + textWidth(prefix), 1)
	underline:SetWidth(math.max(6, textWidth(span)))
	underline:Show()
end

function Box.Apply()
	if not W.IsOpen() then
		return 0, 0, 0
	end
	return SB.Search.Apply(W.ForEachSlot, SB.Buttons.SetDimmed)
end

function Box.Run()
	local text = box:GetText()
	if SB.Search.SetText(text) then
		Box.ClearError()
	else
		Box.ShowError(text, SB.Search.lastError)
	end
	return Box.Apply()
end

box:HookScript("OnTextChanged", Guard("search.textChanged", function(_, userInput)
	if userInput then
		SB.Debounce("search.bags", 0.15, Box.Run, "bags")
	end
end, "bags"))

SB.On("SB_BAGS_LAYOUT", function()
	Box.Apply()
end, "bags")

SB.On("SB_BAGS_UPDATED", function()
	Box.Apply()
end, "bags")

SB.Slash.Register("search", L.HELP_SEARCH, function(arg)
	if not W.IsOpen() then
		return L.SEARCH_OPEN_FIRST
	end
	box:SetText(arg)
	if not SB.Search.SetText(arg) then
		Box.ShowError(arg, SB.Search.lastError)
		return L.SEARCH_ERROR:format(SB.Query.FormatError(SB.Search.lastError))
	end
	Box.ClearError()
	local matches, total, ms = Box.Apply()
	if not SB.Search.IsActive() then
		return L.SEARCH_CLEARED
	end
	return L.SEARCH_RESULT:format(arg, matches, total, ms)
end, "bags")
```

- [ ] **Step 6: Update the TOC**

Append `Engine/Search.lua` to the end of `# Engine`. Append `UI/SearchBox.lua` to the end of `# UI` (after `UI/SafeModeHooks.lua`).

- [ ] **Step 7: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (26 files)`, `174 passed, 0 failed`, `ALL CHECKS PASSED` (in numeric order).

- [ ] **Step 8: Commit**

```bash
git add SwagBag/Engine/Search.lua SwagBag/UI/SearchBox.lua SwagBag/SwagBag.toc spec/search_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add search with full dim, inline positioned errors and /swagbag search" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 9: In-game session D4: search (the user does this; about 10 minutes)**

1. `/reload`, then press **B**. A search box with a magnifier icon sits under the SwagBag title.
2. Click the box and type `potion`. About a moment after you stop typing, everything except potions fades out: icons, borders and counts. Potions look normal. Nothing moves.
3. Replace the text with `gear & ilvl>250`. Only gear above item level 250 stays bright. (Use a number that splits your gear if 250 does not.)
4. Type `"hearth"` (with the quotes). Your Hearthstone stays bright.
5. Type `boe &` (with the trailing &). A red message `Expected a value after "&" at character 6` appears next to the box, a short red line sits under the end of the text, and the **previous** search stays applied.
6. Click the small **x** in the box (or delete the text). Nothing is faded any more.
7. Type `/swagbag search junk`. Chat says `Search "junk": N of M slots match (x.x ms).` The milliseconds should be below 4.0.
8. With `junk` still searched, loot or buy a gray item. It shows bright. Other new non-junk items show faded.
9. Close and reopen the bags. The search text and fading are still applied.
10. Type `/swagbag search` with nothing after it. Chat says `Search cleared.`
11. Type `/swagbag report` and paste it into Claude Code (look for no new errors and `Blocked actions: none`).

Pass: steps 2–10 behave as described, there are no Lua errors, and step 7 shows ≤ 4 ms.

---

### Task 19 (optional): In-game check V1, `SetBagID()` attribute buttons in combat

Spec §4.5: v1.0 ships per-bag parent frames whatever the outcome. A pass here (three in-combat uses on three separate occasions) only allows v1.1 to consider the attribute construction behind a flag. Skip this task if the week is tight.

**Files:**
- Create: `SwagBag/UI/DebugV1.lua`
- Modify: `SwagBag/SwagBag.toc` (append to `# UI`: `UI/DebugV1.lua`)
- Test: luacheck + in-game V1. `debug v1` dispatch is already unit-tested in `spec/commands_spec.lua` (Task 8).

**Interfaces:**
- Consumes: `SB.Adapter.GetBagIDs/NumSlots/GetSlot/IsUsable/InCombat` (Task 6), `SB.Buttons.Paint` (Task 11), the `L.V1_*` strings (Task 2), and the `debug v1` branch in `SB.Commands` (Task 8).
- Produces: `SB.DebugV1.Toggle()` returns a line. `SB.DebugV1.Fill()` returns the count. The frame is named `SwagBagV1Strip`.

- [ ] **Step 1: Write `SwagBag/UI/DebugV1.lua`**

```lua
-- SwagBag in-game check V1 (optional, spec 4.5 / 11.3): six item buttons that use
-- SetBagID() (the "bagid" attribute) instead of a per-bag parent frame. The user
-- uses items from this strip IN COMBAT three times; /swagbag report then shows
-- whether any action was blocked. v1.0 ships per-bag parents either way.
local _, SB = ...

local L = SB.L
local V1 = { buttons = {} }
SB.DebugV1 = V1

local strip

local function build()
	strip = CreateFrame("Frame", "SwagBagV1Strip", UIParent, "BackdropTemplate")
	strip:SetSize(6 * 41 + 12, 70)
	strip:SetPoint("TOP", UIParent, "TOP", 0, -140)
	strip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	strip:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
	strip:SetBackdropBorderColor(0.9, 0.7, 0.2, 1)
	strip:SetMovable(true)
	strip:EnableMouse(true)
	strip:RegisterForDrag("LeftButton")
	strip:SetScript("OnDragStart", strip.StartMoving)
	strip:SetScript("OnDragStop", strip.StopMovingOrSizing)
	local title = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", 8, -7)
	title:SetText(L.V1_TITLE)
	local holder = CreateFrame("Frame", nil, strip) -- deliberately NO SetID: buttons rely on SetBagID()
	holder:SetAllPoints(strip)
	for i = 1, 6 do
		local b = CreateFrame("ItemButton", nil, holder, "ContainerFrameItemButtonTemplate")
		b:SetSize(37, 37)
		b:SetPoint("TOPLEFT", holder, "TOPLEFT", 6 + (i - 1) * 41, -26)
		b:Hide()
		V1.buttons[i] = b
	end
	table.insert(UISpecialFrames, "SwagBagV1Strip")
	strip:Hide()
end

-- Fill with up to 6 usable items from the bags. Returns how many.
function V1.Fill()
	local A, n = SB.Adapter, 0
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		for slot = 1, A.NumSlots(bag) do
			local s = A.GetSlot(bag, slot)
			if n < 6 and s and A.IsUsable(s.itemID) then
				n = n + 1
				local b = V1.buttons[n]
				b:SetBagID(bag)
				b:SetID(slot)
				SB.Buttons.Paint(b, s)
				b:Show()
			end
		end
	end
	for i = n + 1, 6 do
		V1.buttons[i]:Hide()
	end
	return n
end

-- Returns the feedback line for /swagbag debug v1.
function V1.Toggle()
	if SB.Adapter.InCombat() then
		return L.V1_COMBAT
	end
	if not strip then
		build()
	end
	if strip:IsShown() then
		strip:Hide()
		return L.V1_HIDDEN
	end
	local n = V1.Fill()
	strip:Show()
	return L.V1_SHOWN:format(n)
end
```

- [ ] **Step 2: Add it to the TOC** (append to the end of `# UI`): `UI/DebugV1.lua`

- [ ] **Step 3: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (27 files)`, `174 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 4: Commit**

```bash
git add SwagBag/UI/DebugV1.lua SwagBag/SwagBag.toc
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Add optional V1 probe: SetBagID attribute buttons" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: In-game check V1 (the user does this; about 5 minutes; repeat on 3 different days)**

1. `/reload`. Out of combat, type `/swagbag debug v1`. A small yellow-bordered strip appears near the top of the screen with up to 6 of your usable items. Chat says `V1 strip shown with N usable items…`.
2. Attack a training dummy. While in combat, right-click items in the strip 3 times (a potion or healthstone is best; "can't do that now" messages for food are fine).
3. Leave combat. Type `/swagbag report` and paste it into Claude Code.
4. PASS if the report says `Blocked actions: none`. FAIL if it lists anything such as `UseContainerItem…`. Either way your bags keep working, because v1.0 uses per-bag parents.
5. Type `/swagbag debug v1` again to hide the strip.

---

## Week 1 exit check (spec §12.2 week 1: "User plays with SwagBag grid bags + search all day; Safe Mode proven")

The user ticks these in game on Oct 6 or 7 and pastes the final `/swagbag report` into Claude Code:

1. [ ] A full play evening with SwagBag as the only bag UI: questing or world content plus at least one dungeon or M+ key. Bags opened with B, the backpack button, vendor, mailbox and bank (the bank shows Blizzard's bank plus SwagBag bags; the bank window comes in week 3).
2. [ ] Items used from SwagBag in combat (potion/healthstone) at least 3 times, with no red "Interface action failed" message.
3. [ ] Search used during play: `potion`, `boe`, `ilvl>…`, a quoted name, and one deliberate typo that showed the red message without breaking anything.
4. [ ] V9 passed (session D3, step 13): the injected error in combat switched to Blizzard bags, and an item was used from them in combat.
5. [ ] V3 passed (session D3, step 14): Safe Mode toggled both ways in combat, and Blizzard bags used items afterwards.
6. [ ] V4 recorded as "not applicable until placeholders exist (week 2)".
7. [ ] V1 recorded as PASS, FAIL or skipped (optional).
8. [ ] The final report shows: `Errors` = only deliberate `debug:error` entries (or `none` after a `/swagbag reset`), `Blocked actions: none`, `Buttons:` creation ≤ 150 ms, and `Failed checks: none` (an optional check failing is acceptable; write it down).
9. [ ] Position and scale survive `/reload` and logout.
10. [ ] Claude ran `scripts/check.sh` on the branch: `ALL CHECKS PASSED`. The branch is merged (or kept) per the user's choice.

If any line fails: paste the report, and Claude fixes it before week 2 starts. Any slip is reported at the end of the week (spec §12.3).

## What week 2 builds on

Week 2 (M3: categorizer, default categories, sections layout with placeholders/New/Free, collapse, drag-to-assign, sort/reflow, check V12, check V4) consumes these interfaces unchanged:

- **Item records:** `SB.Items.Describe(bag, slot)` (the field list in `Engine/Items.lua`) and `SB.Items.Key(record, class)` for categorizer memo keys (static = itemID, instance = link + bound suffix). Week 2 adds a bounded record cache and `Items.Invalidate`.
- **Query:** `SB.Query.Compile/Eval/Validate/Pretty/FormatError/RegisterKeyword`, `compiled.cacheClass` and `compiled.id` (the memo key part). Week 2 adds the crest/upgrade-currency keywords and folds desk spike F's findings (spec §7.5) into `Engine/Keywords.lua` and §7.5.
- **Inventory:** `SB.Inventory.OnChanged(fn(mask, changes))`, `R` flags, `Has`, `IsNew` (the "New" section seed), `Iterate(kind)` and `LOADED` notifications for re-categorising pending items.
- **Buttons:** `SB.Buttons.Get/Place/Paint/SetDimmed/EnsureCapacity/Count/KindOf/SetParentFor`. Week 2 adds the placeholder pool (`Buttons.Placeholder()`) and the hover/cursor guard (spec §4.2 rule 5).
- **Bags window:** `SB.BagsWindow.Layout/ForEachSlot/records/cells/child/scroll/ClampScroll/HEADER`, `SB_BAGS_LAYOUT`/`SB_BAGS_UPDATED`. Week 2 adds a sections/grid toggle in the header and a pure `Engine/Layout.lua` (`Compute(prev, assignments, opts)`).
- **Search:** `SB.Search.Apply(forEach, setDimmed)` works on any view that provides `ForEachSlot`.
- **Config:** `SB.Config.Get/Set/UI/CharOverride` and `Config.migrations[2]` for adding `categories`, `categoryOrder` and `userEdits` (spec §8.2/§8.5) with a v1 → v2 migration test.
- **Plumbing:** `SB.On/Emit/OutOfCombat/Debounce`, `SB.ErrorTrap.Run/Guard`, `SB.SafeMode`, `SB.Slash.Register` and `SB.Report.Build` (week 2 adds a `Categories: N (M user)` line).
- **Week 3** hosts the hidden bank holder frames `SB.Buttons.holders.bank` / `.warband` (the bank-tab bag frames are parented to them permanently) inside the bank window's scroll area (decide `SetScrollChild(holder)` versus anchoring the holder into a dedicated child during V2).

## Spec coverage (week-1 scope → task)

| Week-1 item (spec §12.2 and brief) | Task |
|---|---|
| Repo layout, TOC, luacheck, local CI script, forbidden-token check | 1 (rules), 2–19 (each task keeps it green) |
| Core namespace, event bus, out-of-combat queue, debounce | 1, 4 |
| Locale enUS table (P8) | 2 |
| Adapter as the only C_* user | 2, 6 (+ check.sh rule) |
| Checks feature detection, `/swagbag check` | 6, 8 |
| Config schema 1, defaults, character overrides, migrations + backup, newer-schema refusal | 5, 8 |
| ErrorTrap.Guard + ring buffer, one-line auto-fallback (P6) | 3, 4, 13 |
| `/swagbag report` copyable box, `/swagbag help`, P2 feedback | 7, 8 |
| Button pool: per-bag parents, 38/98 capacity from C_Bank tab IDs, never reparented | 11 |
| Inventory: BAG_UPDATE dirty → DELAYED flush + 250 ms failsafe, reason bit flags | 10 |
| Bags window GRID, scroll child + ClampScroll, movable/scalable/remembered, Esc | 12 |
| Search box with full dim | 18 |
| SafeMode hooks: B/ToggleAllBags/ToggleBackpack, ContainerFrame1..N + CombinedBags, per-window flags, auto-fallback | 3, 13 |
| Query: tokenizer with spans, parser precedence/parentheses, `#` exact, quoted text, numeric ops, tri-state, registry with cache classes, Validate, Pretty round-trip, positioned errors | 14, 15, 16 |
| v1.0 keywords: type, slot, quality, binding, numeric, state, location; record shape from Items.Describe | 9, 17 |
| In-game checks V1 (optional), V3, V4 (n/a), V9 | 19, 13 |
