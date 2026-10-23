# SwagBag: WoW Forever, Stage A (prepare, ship nothing new to Retail). Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** prepare SwagBag for World of Warcraft: Forever (launch 2026-11-04) without changing anything a Retail player sees or does. This is Stage A of `research/2026-10-22-wow-forever-port.md`: "Interface list, Enum-derived bag IDs, Forever detection, feature gating, tests. Ships nothing new to Retail players." Stage B (in a real Forever client, launch week) verifies it, declares Forever in the TOC and uploads. Stage B is not in this plan.

What Forever is, from the report (§1, §2):
- the Midnight 12.1 client API;
- Interface 16001 in beta, launch number unknown;
- `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18)`;
- the same `C_Container` / `C_Bank` / `Enum.BankType` API;
- **different bag IDs**: character bank tabs 6-14 and warband tabs 15-23, where Retail has 6-11 and 12-16;
- a Classic-style bank with bank bags.

The version goes to 0.15.0 (Task 1).

**The user's principle (binding):** "out of the box simple, full power underneath", and "never break". **On Forever, anything uncertain falls back to Blizzard's own UI rather than guessing.**
- **Retail:** byte-for-byte as today. Every new gate answers "on" on Retail. Every existing test passes unchanged.
- **Forever:**
  - The bags window works, with bag IDs read from the client's `Enum.BagIndex`.
  - Every Retail-only feature is hidden at every entry point.
  - The bank and guild bank are left to Blizzard's frames, and SwagBag says so once per session.

**Architecture:**
- **`Core/Adapter.lua` gets:**
  - `A.Flavor()`, which reads the project constants, with a feature fallback;
  - `A.FEATURES`, the one capability table: each Retail-only feature with its Forever answer and the UI surfaces it owns;
  - `A.Has(feature)` and `A.Allows(surface, id)`;
  - `A.LayoutFromBagIndex(bi)` and `A.BagLayout()`, which derive every bag ID range from `Enum.BagIndex` names, with the verified Retail layout as the only literal fallback.
- **`BagKind` and `GetBagIDs`** read the layout. A few Adapter data reads (upgrade tracks, keystone dungeon, M+, delves, decor, WuE, warband tab IDs) return "no data" when their feature is off.
- **`A.CHECKS`** gains an optional `foreverValue`. `Checks.Run` uses it on Forever.
- **The UI files ask `SB.Adapter.Allows(...)`** at each entry point: overlays, footer entries, focus modes and triggers, setup styles and switches, and Settings rows. The decision lives only in `A.FEATURES`.
- **The bank on Forever:**
  - `Core/Boot.lua` turns on the existing bank Safe Mode with a new reason, `"forever"`. That covers SwagBag's bank window, the guild bank window, the bank menu and warband gold.
  - `SafeMode.ForeverNotice()` prints one line per session at the first bank or guild-bank visit.
  - `/swagbag bank`, `/swagbag guild` and Settings > Bank & guild say the same.
  - `/swagbag safe bank` turns it off for one session. That is the Stage B test path.
- **Tests:**
  - `spec/mock_adapter.lua` gets a Forever mode (`Mock.Forever(m)`, `Loader.New(files, { flavor = "forever" })`) with Forever's real `Enum.BagIndex` table.
  - New specs run the real Adapter with Forever globals, and the bags window and the bank fallback under the Forever mock.
- **Tooling:**
  - New pure `scripts/interfaces.lua` maps an Interface number to `retail` / `forever` and a version name.
  - `scripts/toc_check.lua` refuses a Forever number or a second TOC until Stage B.
  - `scripts/release.sh` learns Forever's CurseForge type `88568`, behind an explicit `--forever` that Stage A never uses.

**Tech Stack:**
- Lua 5.1 (WoW Retail 12.1.x; WoW Forever 1.60.x is prepared for, not declared).
- LuaJIT 2.1 for tests, with the in-repo runner `spec/runner.lua`.
- luacheck, and `scripts/check.sh` for the full gate. Bash for `scripts/release.sh`.

**Spec:**
- `research/2026-10-22-wow-forever-port.md`: §1, the detection rule in §3, §4, the Stage A row, and step list items 1-8 minus 6.
- `docs/superpowers/specs/2026-09-30-swagbag-design.md`: Task 5 adds a change-log line and a WoW Forever paragraph.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag` (quote it: it contains a space). Run every command from there.

**Branch:**
- Make it before Task 1: `git checkout -b forever-stage-a` from `main` at `d17f92b` (v0.14.5, 1992 tests).
- No task creates or switches branches.
- Leave the untracked `.venv/` alone.

**Interfaces used as they are on `d17f92b`:**
- **Core:**
  - `SB.On/Emit/Print`, `SB.ErrorTrap.Guard/Run`, `SB.Slash.Register/Run`, `SB.Config.Get/Set`;
  - `SB.SafeMode` (`Enable(window, reason)`, `Disable`, `IsOn`, `Describe`, `state`);
  - `SB.Checks.Run/Failed/Apply/Lines`;
  - `SB.Commands.SetSafe`;
  - `SB.Report.Build`.
- **Adapter:**
  - `A.Resolve`, `A.BuildInfo`, `A.BagKind` (`Core/Adapter.lua:191-207`), `A.GetBagIDs` (225-245);
  - `A.IsWarboundUntilEquip` (345-353), `A.UpgradeInfo` (355-372), `A.DungeonName` (374-385), `A.DecorKnown` (672);
  - `A.ChallengeModeActive` (1773-1791), `A.InDelve` (1803-1814);
  - `A.CHECKS` (1888-2011; the bank Enum lines are 1951-1954).
- **Engine:**
  - `SB.Focus` (`MODES` 67-88, `TRIGGERS` 96-128, `All` 156-165, `Active` 279-296);
  - `SB.Setup` (`STYLES` 31-34, `Preset` 45-80, the switch modes 183);
  - `SB.Snapshots.Save`;
  - `SB.Items` (`location` / `tab` from `BagKind`, `Engine/Items.lua:39`).
- **UI:**
  - `SB.Overlays` (`NAMES` 31, local `on` 163-165, the slash command 349-381);
  - `SB.Footer` (`IDS` 35, `Entries` 56-86, `SetEntry`, `Move`, `Items` 262-300, the slash command 522-548, `footerRows` after it);
  - `UI/SettingsPages.lua` (`bankRows` 162, `OVERLAYS` 231-237, `overlayRows` 239-252);
  - `UI/SettingsFocus.lua` (18, 130-148, 253, 363);
  - `UI/QuickSetup.lua:23`;
  - `UI/SafeModeHooks.lua:213-220`;
  - `SB.BankWindow` (`OnBankOpened` 1253-1257, the slash command 1370);
  - `SB.GuildBankWindow` (the slash command 995, its open handler);
  - `SB.Buttons.KindOf`.
- **Test helpers:**
  - `spec/helpers/loader.lua` (`Loader.New(files)`);
  - `spec/helpers/uienv.lua` (`Env.ENGINE`, `Env.LoadBank`, `Env.LoadGuild`, `Env.PaintGlobals`);
  - `spec/helpers/globals.lua` (`Globals.AllPresent`);
  - `spec/mock_adapter.lua` (`m.bagIDs`, `m.Put`, `m.SetBagSize`, `m.globals`, `m.Lines()`, `m.frames`);
  - `spec/boot_spec.lua` (fires `ADDON_LOADED` / `PLAYER_LOGIN` on `SB.eventFrame`);
  - `spec/fixtures/items.lua`.

## Global Constraints

- **Target and versions:**
  - WoW Retail 12.1.x. The TOC stays `## Interface: 120100, 120105`: **no Forever number, no `SwagBag_Forever.toc` / `_Camelot.toc` / `_Mainline.toc` in Stage A.**
  - English only.
  - Version `0.15.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
  - No new addon file: the TOC file list is unchanged.
  - New non-addon files: `scripts/interfaces.lua` and the specs named in the tasks.
- **Retail byte-for-byte:**
  - On Retail (`A.Flavor() == "retail"`), `A.Has` and `A.Allows` return true for everything, `Checks.Run` compares the same values, and every Adapter read takes the same path as today.
  - No existing `it` block is edited or deleted. New tests may be added to existing spec files.
  - The Retail layout derived from Blizzard's 12.1.5 `Enum.BagIndex` must equal today's literals (Task 2 pins it).
- **Lua 5.1 only:** no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets only strings or numbers.
- **Adapter rule (widened):**
  - `SwagBag/Core/Adapter.lua` is the only file that may name `C_*`, `Enum`, `WOW_PROJECT_*`, ElvUI, Syndicator, `TSM_API` or `LibStub`, comments included.
  - Task 1 adds `WOW_PROJECT_` to `scripts/check.sh`'s rule.
  - The Adapter reads the project constants as `_G.WOW_PROJECT_ID` etc. (the `_G.IsInInstance` pattern), so `.luacheckrc` is unchanged.
- **Forbidden anywhere in `SwagBag/`, comments included:** `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`.
- **Detection rule (report §3):**
  - Gate on the project constant, then on the feature. **Never gate on the Interface number**; it is for logs only.
  - Feature decisions live only in `A.FEATURES`. UI files ask `SB.Adapter.Has(feature)` or `SB.Adapter.Allows(surface, id)`, never `A.Flavor()`.
  - The one exception is `Core/Report.lua`'s diagnostic line.
- **On Forever, uncertain means Blizzard's:**
  - The bank and guild bank windows are off through Safe Mode.
  - The warband bank is never read.
  - Every gated feature gives "no data" and has no entry point.
  - Nothing falls back to a guessed number.
- **P2 (exactly one answer per click and command):**
  - A gated name typed into `/swagbag overlays` or `/swagbag footer` answers `L.FOREVER_LEFT_OUT`.
  - `/swagbag bank` and `/swagbag guild` answer `L.FOREVER_BANK_OFF` while the bank's Safe Mode reason is `"forever"`.
- **P5:** no layout or button change is added. Gates only remove rows, entries and data.
- **P6:** every new entry point runs where its caller already runs (inside `ErrorTrap`). No new label.
- **P8:** every user-visible string is in `SwagBag/Locale/enUS.lua`, with the exact copy given in the tasks. `spec/locale_spec.lua` must stay green. No `…`, `→`, `←` or `⋯`.
- **Saved data:**
  - Schema stays 2, no migration, no new setting.
  - The Stage B opt-in (`/swagbag safe bank`) reuses `safeMode.bank`. Boot re-applies the `"forever"` reason at every login, so the opt-in lasts one session.
- **Idle and load time:**
  - No `OnUpdate`. No file calls `Config` at load time.
  - `A.Flavor()` reads four globals and is not cached, so tests can switch it.
  - `A.BagLayout()` is cached per `Enum.BagIndex` table identity: `BagKind` stays O(1) table lookups.
- **Tests:**
  - Every critical test names the mutation that must make it fail; each task lists its mutations at its test step.
  - Tests run with `luajit spec/runner.lua spec/*_spec.lua`.
  - Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
  - The suite starts at 1992. Each task states the minimum number of new tests.
  - Specs that set `WOW_PROJECT_*`, `Enum` or `C_Bank` globals declare them in a `-- luacheck: globals` header and clear them in `after_each`, like `spec/adapter_bank_spec.lua`.
- **No upload, no tag, no push in this plan.** `scripts/release.sh` is changed and syntax-checked (`bash -n`), never run.
- **Repo is public:** never put a real name or a personal email in any file, test fixture, comment or commit.
- **Commits:**
  - One commit per task: `git -c user.name=lonezebra -c user.email=294288393+Sharpened-Banana@users.noreply.github.com commit`.
  - The message ends with exactly:
    `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Review Focus

The five uncovered inputs most likely to hurt a player. Each has a test in the task named.

1. **A Forever character-bank tab with a Retail warband number (bags 12-14).**
   - It must read as `bank`, tab 7-9: not `warband`, not New, not hidden.
   - Covered by Task 2 "Forever bank tabs 7-9 (bags 12-14) are character bank, not warband", Task 2 "an item in bag 13 on Forever is in the bank, not the warband" (search keywords), and Task 4 "with the opt-in, the Forever bank shows bag 13 in the Character bank group".
2. **A half-renamed or gapped `Enum.BagIndex`.**
   - It must fall back whole to the verified Retail layout, never half-derive.
   - Covered by Task 2 "an incomplete BagIndex gives nil, and BagLayout falls back to Retail" and Task 2 "a gap ends a range; overlapping ranges are refused".
3. **Misdetecting the client.**
   - Retail must stay Retail even if it gains `C_Bank.ShouldUsePlayerBagsInBank`.
   - A renamed Forever constant, or an unknown non-Retail project, must take the restricted (Forever) profile.
   - Covered by Task 1's Flavor tests.
4. **A Retail regression through a gate.**
   - On Retail, every feature is on, every surface is allowed, and the checks compare the same values.
   - Covered by Task 1 "on Retail every declared feature and surface is on", Task 2 "Retail's 12.1.5 BagIndex derives exactly today's literals" and Task 2 "on Retail, 15 still fails the warband check". The full unchanged suite also covers it.
5. **The Forever bank visit.**
   - SwagBag must never take Blizzard's bank frame or its tabs, and must say so once, not on every visit or at login.
   - The opt-in must last one session.
   - Covered by Task 4 "a Forever bank visit leaves Blizzard's bank alone and says so once", Task 4 "the notice is not printed at login" and Task 4 "the opt-in lasts one session".

---

### Task 1: Flavor detection and the capability table in the Adapter; the Forever mock; 0.15.0

**Files:**
- Modify: `SwagBag/Core/Adapter.lua`:
  - header comment (lines 1-4: add the `WOW_PROJECT_*` rule and the Flavor/Has paragraph);
  - a new section after "Basics" (after line 123): `A.Flavor`, `A.FEATURES`, `A.Has`, `A.Allows`.
- Modify: `SwagBag/SwagBag.toc` (line 5 `## Version: 0.15.0`), `SwagBag/Core/Init.lua:6` (`SB.VERSION = "0.15.0"`)
- Modify: `scripts/check.sh`. In step 3, after the C_*/Enum rule, add:
  `if grep -rnE '(^|[^[:alnum:]_])WOW_PROJECT_' SwagBag | grep -v '^SwagBag/Core/Adapter.lua:'; then fail "WOW_PROJECT_* named outside SwagBag/Core/Adapter.lua (comments included)"; fi`
- Modify: `spec/mock_adapter.lua`:
  - `m.flavor = "retail"` and `function m.Flavor() return m.flavor end` in `M.New`;
  - new `M.FOREVER_BAG_INDEX`, `M.RETAIL_BAG_INDEX` and `M.Forever(m)`. `M.Forever` is completed in Task 2.
- Modify: `spec/helpers/loader.lua`: `Loader.New(files, opts)`. When `opts and opts.flavor == "forever"`, it calls `Mock.Forever(SB.Adapter)` **before** loading `files` (UI files read flavor-dependent lists at load: QuickSetup's style buttons).
- Test: `spec/adapter_forever_spec.lua` (new: real Adapter, stubbed globals), `spec/checks_spec.lua` (new `it`s only)

**Interfaces:**
- Produces `A.Flavor() -> "retail" | "forever"`, in this order:
  1. `id = _G.WOW_PROJECT_ID`, `forever = _G.WOW_PROJECT_FOREVER or _G.WOW_PROJECT_CAMELOT`, `mainline = _G.WOW_PROJECT_MAINLINE`.
  2. When `id ~= nil and forever ~= nil and id == forever`, the answer is `"forever"`.
  3. When `id ~= nil and mainline ~= nil and id ~= mainline`, the answer is `"forever"`. This is an unknown non-Retail project: it takes the restricted profile.
  4. When `id == nil` and `C_Bank and C_Bank.ShouldUsePlayerBagsInBank ~= nil`, the answer is `"forever"`. This is the report's feature fallback, for a client whose constants were removed.
  5. Otherwise the answer is `"retail"`. That covers live Retail, where `id == mainline`, and the test environment, which has no constants.
- Produces `A.FEATURES`. Every entry is `{ forever = false, surfaces = { [surface] = { id, ... } } }`; Stage A has no Forever `true`.

  | Feature | Retail-only because (report §3) | Surfaces it owns |
  |---|---|---|
  | `keystones` | No Challenges UI, no Mythic+, no crests | `overlay = { "keystone" }`, `footer = { "crests", "keystone" }`, `mode = { "mplus" }`, `trigger = { "mplus" }`, `style = { "mplus" }`, `setting = { "overlays.keystone", "focus.on.mplus" }` |
  | `delves` | Delves UI is `standard` only | `mode = { "delves" }`, `trigger = { "delve" }`, `setting = { "focus.on.delves" }` |
  | `upgradeTracks` | Retail's upgrade system | `overlay = { "track" }`, `setting = { "overlays.track" }` |
  | `housing` | Housing is `standard` only | none (data only: `DecorKnown`) |
  | `warband` | Whether the warband bank is enabled is unverified | none (data only: warband tab IDs, WuE, warband snapshots) |
  | `bankWindow` | Forever's bank-bag bank is unverified (report §4) | none (Boot's Safe Mode, Task 4) |

- Produces `A.Has(feature) -> bool`:
  - false for an undeclared name, on both clients;
  - true when `A.Flavor() ~= "forever"`;
  - else `A.FEATURES[feature].forever == true`.
- Produces `A.Allows(surface, id) -> bool`:
  - false only when some declared feature lists `id` under `surface` and `A.Has` of that feature is false;
  - true for an undeclared id;
  - the reverse index is built once, lazily, from `A.FEATURES`.
- The mock:
  - `m.flavor` (default `"retail"`) drives the real `A.Has` / `A.Allows`, which call `A.Flavor()` through the table.
  - `M.Forever(m)` sets `m.flavor = "forever"`, and `m.BuildInfo` to `{ version = "1.60.1", build = "70532", toc = 16001, locale = "enUS" }`.
  - `M.FOREVER_BAG_INDEX` is Blizzard's build-70532 table: `Keyring = -1`, `Characterbanktab = -2`, `Accountbanktab = -3`, `Backpack = 0`, `Bag_1..Bag_4 = 1..4`, `ReagentBag = 5`, `CharacterBankTab_1..9 = 6..14`, `AccountBankTab_1..9 = 15..23`.
  - `M.RETAIL_BAG_INDEX` is Blizzard's 12.1.5 table. Copy both from `Gethe/wow-ui-source` `BagIndexConstantsDocumentation.lua` on the `forever` and `live` branches. Keep every name, the negative ones included; the Retail values must match `Adapter.lua:191-207`'s literals.

- [ ] **Step 1: Write the failing tests.**
  - `spec/adapter_forever_spec.lua` (`describe("Adapter flavor (real adapter, stubbed globals)")`; loads `Core/Adapter.lua` into a bare `SB`, like `spec/adapter_bank_spec.lua`):
    - `it("no project constants and no Forever API is retail (tests, old clients)")`.
    - `it("WOW_PROJECT_ID == WOW_PROJECT_MAINLINE is retail")`: `ID = 1, MAINLINE = 1, CAMELOT = 18`.
    - `it("WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18) is forever")`. Mutation: comparing `id` with `mainline` only, in rule 2.
    - `it("a renamed constant, WOW_PROJECT_FOREVER, is still forever")`: `ID = 18, FOREVER = 18`, no CAMELOT.
    - `it("an unknown project that is not Retail takes the Forever profile")`: `ID = 99, MAINLINE = 1`. Mutation: dropping rule 3.
    - `it("Retail that gains C_Bank.ShouldUsePlayerBagsInBank stays retail")`: `ID = MAINLINE = 1` plus the function. Mutation: checking the API before the constants.
    - `it("no constants but C_Bank.ShouldUsePlayerBagsInBank is forever")`.
    - `it("on Retail every declared feature and surface is on")`: `Has(name)` is true for each key of `A.FEATURES`, and `Allows(surface, id)` is true for every listed pair. Mutation: `Has` reading `FEATURES[f].forever` on both clients.
    - `it("on Forever every Stage A feature is off and its surfaces are refused")`:
      - each `Has` is false;
      - `Allows("overlay", "keystone")`, `("footer", "crests")`, `("mode", "delves")`, `("trigger", "mplus")`, `("style", "mplus")` and `("setting", "overlays.track")` are false;
      - `Allows("overlay", "ilvl")` and `("footer", "gold")` stay true.
      - Mutation: `Allows` returning `Has` of the first feature for every id.
    - `it("an undeclared feature is off on both clients")`: `Has("nope")` is false.
    - `it("every Has and Allows call in SwagBag/ names a declared feature or surface")`:
      - scan `find SwagBag -name '*.lua'` (the `spec/locale_spec.lua` pattern) for `Has%("([%w]+)"%)`;
      - each name is a key of `A.FEATURES`;
      - for `Allows%("(%a+)",`, each surface is one of `overlay footer mode trigger style setting`.
      - Mutation: a typo, `Has("keystone")`, in Task 3.
  - `spec/adapter_forever_spec.lua`, `describe("Mock Forever mode")`:
    - `it("Loader.New with flavor forever runs the files under Forever")`: a probe file is not needed. After `Loader.New({}, { flavor = "forever" })`:
      - `SB.Adapter.Flavor() == "forever"`;
      - `SB.Adapter.Has("keystones") == false`;
      - `SB.Adapter.BuildInfo().toc == 16001`.
    - `it("the default mock stays retail")`.
  - At least 14 new tests.

- [ ] **Step 2: Run them and see them fail**: `luajit spec/runner.lua spec/adapter_forever_spec.lua`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - The Adapter code as in Interfaces. No other file calls `Has` or `Allows` yet, so the scan test passes vacuously until Task 3.
  - Bump the TOC `## Version` and `SB.VERSION` to `0.15.0`.
  - Add the `check.sh` rule.

- [ ] **Step 4: Run the gate**: `scripts/check.sh`. Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Forever Stage A Task 1: Adapter flavor detection and capability table; mock Forever mode; 0.15.0`.

---

### Task 2: Bag IDs from `Enum.BagIndex`; the per-client bank check; the Forever bag layout in tests

**Files:**
- Modify: `SwagBag/Core/Adapter.lua`:
  - replace lines 191-207 (`BagKind`) and the `"bags"` branch of 226-229 (`GetBagIDs`); add `A.RETAIL_BAG_INDEX`, `A.LayoutFromBagIndex`, `A.RETAIL_LAYOUT`, `A.BagLayout`;
  - line 1952: add `foreverValue = 15` to the `Enum.BagIndex.AccountBankTab_1` check (its `value = 12` stays);
  - the header comment of the Feature checks section (1884-1887): document `foreverValue`.
- Modify: `SwagBag/Core/Checks.lua:13-20` (`Run`: the expected value)
- Modify: `SwagBag/UI/SafeModeHooks.lua:213-220`. The `ToggleBag` filter becomes `local k = SB.Adapter.BagKind(id)` and `k == "backpack" or k == "bags" or k == "reagentbag"`. The comment says "the bag-bar IDs from Enum.BagIndex; never bank tabs, nil or other values".
- Modify: `spec/mock_adapter.lua`. `M.Forever(m)` now also:
  - builds `local layout = m.LayoutFromBagIndex(M.FOREVER_BAG_INDEX)`;
  - sets `m.BagLayout = function() return layout end`;
  - sets `m.bagIDs = { bags = layout.bags (copied), bank = {}, warband = {} }`.
  - The default mode keeps the real `A.BagLayout`. With no global `Enum` it gives `A.RETAIL_LAYOUT`, so every existing test sees today's IDs.
- Test: `spec/adapter_forever_spec.lua`, `spec/checks_spec.lua` (new `it`s), `spec/items_spec.lua` (new `it`s), `spec/safemodehooks_spec.lua` (new `it`), `spec/inventory_spec.lua` (new `it`), `spec/buttons_spec.lua` (new `it`)

**Interfaces:**
- Produces `A.LayoutFromBagIndex(bi) -> layout | nil`. It is pure and reads only these names:
  - It needs numbers for `Backpack`, `Bag_1`, `CharacterBankTab_1` and `AccountBankTab_1`; otherwise it gives nil.
  - `bags` is `Backpack`, then `Bag_1..Bag_k` for as long as each is the previous one plus 1. Then `ReagentBag`, when it is a number.
  - `bank` is `{ first = CharacterBankTab_1, last = CharacterBankTab_k }`, with the same consecutive rule. `warband` is the same for `AccountBankTab_*`.
  - It gives nil if any ID would belong to two kinds.
  - Every other name is ignored, including `Keyring`, `Characterbanktab`, `Accountbanktab` and `Bank`.
  - The result is `{ bags = { ids }, reagent = id | nil, bank = { first, last }, warband = { first, last }, kind = { [id] = "backpack" | "bags" | "reagentbag" | "bank" | "warband" }, tab = { [id] = n } }`, with `tab` only for bank kinds and 1-based.
- Produces `A.RETAIL_BAG_INDEX`: the 12.1.5 literal table, the only bag-ID literals left. Also `A.RETAIL_LAYOUT = A.LayoutFromBagIndex(A.RETAIL_BAG_INDEX)`.
- Produces `A.BagLayout() -> layout`:
  - it reads `Enum and Enum.BagIndex`;
  - when that table is new (identity), it re-derives;
  - it gives `A.RETAIL_LAYOUT` when there is no table or the derivation gives nil.
- `A.BagKind(bag)` returns `layout.kind[bag], layout.tab[bag]`, through `A.BagLayout()`. For an unknown bag it returns nothing, so `{ A.BagKind(99) }` is still `{}`.
- `A.GetBagIDs("bags")` returns a copy of `A.BagLayout().bags`. The bank kinds are unchanged until Task 3 adds the warband gate.
- `Checks.Run`: `local want = c.value`; when `c.foreverValue ~= nil and A.Flavor() == "forever"` then `want = c.foreverValue`. The pass test and the `CHECK_EXPECTED` detail use `want`.

- [ ] **Step 1: Write the failing tests.**
  - `spec/adapter_forever_spec.lua`, `describe("Bag layout from Enum.BagIndex")`:
    - `it("Retail's 12.1.5 BagIndex derives exactly today's literals")`:
      - `LayoutFromBagIndex(Mock.RETAIL_BAG_INDEX)` has bags `{0,1,2,3,4,5}`, bank 6-11 and warband 12-16;
      - its `kind` and `tab` maps equal `A.RETAIL_LAYOUT`'s.
      - Mutation: off-by-one in the consecutive scan.
    - `it("Forever's BagIndex gives bank 6-14 and warband 15-23")`. Mutation: a hardcoded `last = first + 5`.
    - `it("Forever's extra names (-1, -2, -3) are never bags")`: `kind[-1]`, `kind[-2]` and `kind[-3]` are nil.
    - `it("an incomplete BagIndex gives nil, and BagLayout falls back to Retail")`:
      - no `AccountBankTab_1` gives nil;
      - with global `Enum = { BagIndex = that }`, `A.BagLayout() == A.RETAIL_LAYOUT`.
      - Mutation: deriving a partial layout.
    - `it("a gap ends a range; overlapping ranges are refused")`:
      - with `CharacterBankTab_3` missing, bank is 6-7;
      - with `AccountBankTab_1 = 8` inside the bank range, the result is nil.
    - `it("no ReagentBag: the bags are 0-4")`.
    - `it("BagLayout follows a new Enum.BagIndex table and caches the same one")`: the same table is derived once (count calls with a metatable `__index` counter on the table); a new table re-derives.
    - `it("Forever bank tabs 7-9 (bags 12-14) are character bank, not warband")`:
      - with global `Enum.BagIndex = Mock.FOREVER_BAG_INDEX`, `{ A.BagKind(12) } == { "bank", 7 }`, `{ A.BagKind(14) } == { "bank", 9 }`, `{ A.BagKind(15) } == { "warband", 1 }`, `{ A.BagKind(23) } == { "warband", 9 }`;
      - `{ A.BagKind(24) } == {}`.
      - Mutation: restoring the literal ranges.
    - `it("GetBagIDs('bags') comes from the layout")`: Forever and Retail both give `{0,1,2,3,4,5}`, and a layout without a reagent bag gives `{0,1,2,3,4}`.
  - `spec/checks_spec.lua`:
    - `it("on Forever the warband bank's first ID is checked against 15")`:
      - `A.globals = Globals.AllPresent(A)`, `A.globals.Enum.BagIndex.AccountBankTab_1 = 15`, `A.flavor = "forever"`;
      - no failed required check for bank.
      - Mutation: ignoring `foreverValue`.
    - `it("on Retail, 15 still fails the warband check")`: the same with `A.flavor = "retail"` fails, with the detail `"expected 12, got 15"`.
  - `spec/items_spec.lua`: `it("an item in bag 13 on Forever is in the bank, not the warband")`:
    - `Loader.New(files, { flavor = "forever" })`; `Items.Record(13, 1)` has `location == "bank"` and `tab == 8`;
    - the `bank` keyword matches it and `warband` does not.
  - `spec/inventory_spec.lua`: `it("a Forever bank scan reads tabs 6-14 as bank")`. With `m.bagIDs.bank = { 6, 10, 14 }` and an item in each, every record's location is `"bank"`.
  - `spec/buttons_spec.lua`: `it("on Forever Buttons.KindOf(12) is bank and 15 is warband")`.
  - `spec/safemodehooks_spec.lua`: `it("ToggleBag reacts to the bag-bar IDs only, from the layout")`: 0-5 react, while 6, 12, -1 and nil do not, under both flavors. Mutation: `id >= 0` only.
  - At least 16 new tests.

- [ ] **Step 2: Run them**: `luajit spec/runner.lua spec/adapter_forever_spec.lua spec/checks_spec.lua spec/items_spec.lua spec/inventory_spec.lua spec/buttons_spec.lua spec/safemodehooks_spec.lua`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement** as in Interfaces.
  - Keep `A.BAG_CAPACITY` and `A.BANK_TAB_CAPACITY`. `Buttons.EnsureBankTabs` already takes `max(NumSlots, 98)`, and Forever pages at 88.
  - Rewrite the BagKind comment: "derived from Enum.BagIndex names (Retail 6-11 / 12-16, Forever 6-14 / 15-23); the 12.1.5 table is the fallback".

- [ ] **Step 4: Run the gate**: `scripts/check.sh`. Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Forever Stage A Task 2: bag IDs from Enum.BagIndex; per-client bank check`.

---

### Task 3: Retail-only features off on Forever, at the data and at every entry point

**Files:**
- Modify: `SwagBag/Core/Adapter.lua`. On `not A.Has(f)`, each read returns its existing "no data" answer before touching the API:
  - `UpgradeInfo` (355): `nil, false` (`upgradeTracks`);
  - `DungeonName` (375): nil (`keystones`);
  - `ChallengeModeActive` (1776): false (`keystones`);
  - `InDelve` (1805): false (`delves`);
  - `DecorKnown` (672): nil (`housing`);
  - `IsWarboundUntilEquip` (345): false (`warband`);
  - `GetBagIDs("warband")`: `{}` (`warband`).
- Modify: `SwagBag/UI/Overlays.lua`:
  - local `on(name)` (163): `SB.Adapter.Allows("overlay", name) and ...`;
  - new `Ov.Names()`: `NAMES` filtered by `Allows`;
  - the slash command (349-381): list `Ov.Names()`; a known but refused name answers `L.FOREVER_LEFT_OUT:format(name)` and writes nothing.
- Modify: `SwagBag/UI/SettingsPages.lua:239-252` (`overlayRows` skips refused overlays)
- Modify: `SwagBag/UI/Footer.lua`:
  - new `F.Shown()`: `F.Entries()` filtered by `Allows("footer", id)`;
  - `F.Items` (262), the slash listing and `footerRows` use `F.Shown()`;
  - `F.SetEntry` / `F.Move` on a refused id return `false, "unavailable"`, and the slash command answers `L.FOREVER_LEFT_OUT:format(F.Name(id))`;
  - `F.Move` steps over refused neighbours;
  - `F.Entries()` and `save` stay complete, so a refused entry keeps its saved place.
- Modify: `SwagBag/Engine/Focus.lua`:
  - `All` (156) and `Active` (279) skip built-ins refused by `Allows("mode", id)`;
  - new `Focus.Triggers()`: `TRIGGERS` filtered by `Allows("trigger", id)`;
  - `Focus.Mode` / `byId` are unchanged, so saved settings and profiles keep working.
- Modify: `SwagBag/UI/SettingsFocus.lua`:
  - `triggerChoices` (141-148) uses `Focus.Triggers()`; `triggerName` is unchanged, so an existing mode's trigger still has a name;
  - the three `"mplus"` defaults (18, 253, 363) become `SF.FirstMode()`, which is `Focus.All()[1].id` (`"mplus"` on Retail).
- Modify: `SwagBag/Engine/Setup.lua`:
  - new `Setup.Styles()`: `STYLES` filtered by `Allows("style", id)`;
  - `Preset`'s `set()` skips a path refused by `Allows("setting", path)`;
  - the focus switch loop (183) skips refused modes.
- Modify: `SwagBag/UI/QuickSetup.lua:23` (`QS.STYLES = Setup.Styles()`)
- Modify: `SwagBag/Locale/enUS.lua` (after `OVERLAYS_*`): `L.FOREVER_LEFT_OUT`
- Test: `spec/adapter_forever_spec.lua`, `spec/overlays_spec.lua`, `spec/settings_spec.lua`, `spec/footer_spec.lua`, `spec/focus_spec.lua`, `spec/settings_focus_spec.lua`, `spec/setup_spec.lua`, `spec/quicksetup_spec.lua` (new `it`s only)

**Interfaces:**
- Consumes `A.Has`, `A.Allows` (Task 1) and the Forever mock (Tasks 1-2).
- Produces `Ov.Names()`, `F.Shown()`, `Focus.Triggers()`, `SF.FirstMode()`, `Setup.Styles()`.
- On Retail each of them returns exactly today's list.
- String (exact):
  - `L.FOREVER_LEFT_OUT = "%s is not part of WoW Forever, so SwagBag leaves it out there."`

- [ ] **Step 1: Write the failing tests.** Each Forever test uses `Loader.New(files, { flavor = "forever" })`.
  - `spec/adapter_forever_spec.lua` (real Adapter, `WOW_PROJECT_ID = WOW_PROJECT_CAMELOT = 18`):
    - `it("on Forever the gated reads return no data and never call the game")`:
      - stub `C_Item.GetItemUpgradeInfo`, `C_ChallengeMode.GetMapUIInfo / IsChallengeModeActive`, `C_PartyInfo.IsDelveInProgress`, `C_HousingCatalog.GetCatalogEntryInfoByItem` and `C_Item.IsBoundToAccountUntilEquip` to count their calls and return data;
      - `UpgradeInfo` gives `nil, false`, `DungeonName` nil, `ChallengeModeActive` false, `InDelve` false, `DecorKnown` nil and `IsWarboundUntilEquip` false;
      - every call count is 0.
      - Mutation: gating after the API call.
    - `it("on Forever GetBagIDs('warband') is empty even when C_Bank lists tabs")`: `FetchPurchasedBankTabIDs` returns `{15, 16}` for Account, and `GetBagIDs("bank")` still gives its list. Mutation: no warband gate.
    - `it("on Retail the same reads still ask the game")`: the same stubs give data, with call counts of 1.
  - `spec/overlays_spec.lua`:
    - `it("on Forever a keystone and an upgrade track draw nothing")`: with `m.tracks[link]` set and a keystone link, `topLeft` and `bottomLeft` are `""` while the item level still draws. Mutation: no `Allows` in `on`.
    - `it("on Forever /swagbag overlays lists no track or keystone")`.
    - `it("on Forever /swagbag overlays track on answers left out and saves nothing")`: the answer is `L.FOREVER_LEFT_OUT:format("track")`, and `overlays.track` is unchanged.
  - `spec/settings_spec.lua`: `it("on Forever the Overlays page has no Upgrade track or Keystone row")`.
  - `spec/footer_spec.lua`:
    - `it("on Forever the footer shows no crests or keystone")`: with a crest currency and a keystone in the bags, `F.Items()` has no `crests` or `keystone` entry. Mutation: `Items` iterating `Entries`.
    - `it("on Forever /swagbag footer lists gold, currencies and free only")`.
    - `it("on Forever /swagbag footer crests on answers left out")`.
    - `it("on Forever moving gold down passes the hidden crests")`: from the default order, `/swagbag footer currencies down` puts `free` before `currencies` in `F.Shown()`, and the saved string keeps `crests,keystone`.
    - `it("on Forever Settings > Footer has three rows and the note")`.
  - `spec/focus_spec.lua`:
    - `it("on Forever the M+ and Delves modes never switch on")`: `challengeMode = true`, `delve = true` and `focus.auto` on give `Focus.Active()` without `mplus` or `delves`. Mutation: gating `All` only.
    - `it("on Forever Focus.All and Focus.Triggers leave out M+ and Delves")`.
    - `it("on Forever a saved focus.on.mplus is kept, not deleted")`.
  - `spec/settings_focus_spec.lua`:
    - `it("on Forever the Focus page starts on Raid and offers no M+ or Delve trigger")`.
    - `it("on Retail the Focus page still starts on M+")`.
  - `spec/setup_spec.lua`:
    - `it("on Forever there is no M+ style")`.
    - `it("on Forever Raid's preset sets no upgrade track")`: `Preset({ raid = true })` has no `overlays.track`, and still has `overlays.ilvl`. Mutation: no `set()` filter.
    - `it("on Forever the switches list no M+ or Delves mode")`.
  - `spec/quicksetup_spec.lua`: `it("on Forever the wizard shows four style buttons")`.
  - At least 22 new tests.

- [ ] **Step 2: Run them.** Expected: the new tests FAIL.

- [ ] **Step 3: Implement** as in Files and Interfaces.
  - Every gate is `SB.Adapter.Allows(...)` or `A.Has(...)`, never a flavor test.
  - The Adapter gates go first in each function, before any `C_*` lookup.
  - Data that is simply absent on Forever needs no gate; Decisions lists it: the `keystone`, `crest`, `warbound`, `wue` and `housing` keywords, the Keystone & Crests category, and the Signals keystone read.

- [ ] **Step 4: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Forever Stage A Task 3: Retail-only features off on Forever, data and entry points`.

---

### Task 4: The bank on Forever is Blizzard's (Safe Mode reason "forever"); the windows under the Forever mock

**Files:**
- Modify: `SwagBag/Core/SafeMode.lua`:
  - new `SM.Reason(window) -> reason | nil` (nil while off);
  - new `SM.ForeverNotice() -> bool`. It prints `L.FOREVER_BANK_OFF` once per session while `SM.Reason("bank") == "forever"`, and `SM.foreverTold` remembers it.
- Modify: `SwagBag/Core/Boot.lua:22-40`. First in the `PLAYER_LOGIN` handler, before `Checks.Apply`:
  `if not SB.Adapter.Has("bankWindow") then SM.Enable("bank", "forever") end`.
  The reason is then always `"forever"` on Forever, and nothing is printed at login.
- Modify: `SwagBag/UI/BankWindow.lua`: `BW.OnBankOpened` (1253) calls `SB.SafeMode.ForeverNotice()`. The `bank` slash command (1370) answers only `L.FOREVER_BANK_OFF` while `SB.SafeMode.Reason("bank") == "forever"`.
- Modify: `SwagBag/UI/GuildBankWindow.lua`: its `GUILDBANKFRAME_OPENED` handler calls `SB.SafeMode.ForeverNotice()`. The `guild` slash command (995) answers the same way as `/swagbag bank`.
- Modify: `SwagBag/UI/SettingsPages.lua:162` (`bankRows`): while the reason is `"forever"`, it returns only `{ { kind = "note", label = L.SET_BANK_FOREVER_NOTE } }`.
- Modify: `SwagBag/Engine/Snapshots.lua`: `Snap.Save(kind)` and the capture on bank open/close skip `"warband"` when `not SB.Adapter.Has("warband")`. The alt viewer then never gets an empty Warband group (`OW.Load` keeps only kinds with something saved).
- Modify: `SwagBag/Core/Report.lua:79-86`. After `REPORT_SAFE`, and only when `A.Flavor() == "forever"`, add one line:
  - `L.REPORT_FOREVER:format(tostring(build.toc), bagsRange, bank.first, bank.last, warband.first, warband.last)`;
  - the numbers come from `A.BagLayout()`;
  - `bagsRange` is `first .. "-" .. last` of `layout.bags`.
- Modify: `SwagBag/Locale/enUS.lua` (after the `SAFE_*` lines 33-44, and after `REPORT_SAFE` line 75)
- Test: `spec/forever_spec.lua` (new), `spec/boot_spec.lua`, `spec/safemode_spec.lua`, `spec/report_spec.lua`, `spec/snapshots_spec.lua`, `spec/settings_spec.lua`, `spec/locale_spec.lua` (new `it`s only)

**Interfaces:**
- Consumes everything from Tasks 1-3, `Env.LoadBank` and `Env.LoadGuild`.
- Produces `SM.Reason`, `SM.ForeverNotice`, and the Safe Mode reason `"forever"` (shown by `SM.Describe` through `L.SAFE_REASON_FOREVER`).
- The Stage B opt-in:
  - `/swagbag safe bank` (the existing `Commands.SetSafe`) switches the bank's Safe Mode off for this session;
  - the next login turns it back on, because Boot enables `"forever"` before reading `safeMode.*`.
- Strings (exact):
  - `L.SAFE_REASON_FOREVER = "WoW Forever"`
  - `L.FOREVER_BANK_OFF = "On WoW Forever, Blizzard's own bank and guild bank are used for now: SwagBag's bank windows wait until they have been checked there. Your bags still use SwagBag."`
  - `L.SET_BANK_FOREVER_NOTE = "On WoW Forever, Blizzard's own bank and guild bank are used for now. These settings come back once SwagBag's bank windows have been checked there."`
  - `L.REPORT_FOREVER = "WoW Forever: Interface %s | bags %s | bank tabs %d-%d | warband tabs %d-%d"`

- [ ] **Step 1: Write the failing tests.**
  - `spec/boot_spec.lua`:
    - `it("a Forever login puts the bank, not the bags, in Safe Mode with reason forever")`: the bank reason is `"forever"`, bags are off, and the lines are only the loaded line. Mutation: printing the notice at login.
    - `it("a Forever login keeps reason forever even when a bank check also fails")`: `A.globals.BankFrame = nil` gives `"forever"`. Mutation: enabling after `Checks.Apply`.
    - `it("a Retail login is unchanged")`: the bank is off and the lines are the same.
  - `spec/safemode_spec.lua`:
    - `it("Reason is nil while off and the reason while on")`.
    - `it("ForeverNotice prints once, and only for reason forever")`.
  - `spec/forever_spec.lua` (new; `Fake.Install()`, `Env.PaintGlobals()`, `Loader.New(Env.ENGINE, { flavor = "forever" })`, then the bags window and `Env.LoadBank`, as `spec/bankwindow_spec.lua` does; fire `PLAYER_LOGIN` as `spec/boot_spec.lua` does):
    - `it("the bags window opens on Forever with the bags and the reagent bag")`:
      - an herb in bag 2 and a reagent in bag 5;
      - the bags open in sections, the reagent's section holds (5, n), and the footer has gold, currencies and free only.
    - `it("a Forever bank visit leaves Blizzard's bank alone and says so once")`:
      - `BANKFRAME_OPENED` twice (with a close between);
      - `BW.IsOpen()` is false;
      - Blizzard's fake `BankFrame` keeps its parent, and its `TabSystem` parent is unchanged (never hosted);
      - `A.Lines()` holds `L.FOREVER_BANK_OFF` exactly once;
      - the bags window's "Show bank" button stays hidden.
      - Mutation: `BW.Open` ignoring Safe Mode.
    - `it("the notice is not printed at login")`.
    - `it("a Forever guild bank visit is Blizzard's too, with no second notice")`: `Env.LoadGuild`; the guild window does not open, and the notice count stays 1 after a bank visit.
    - `it("/swagbag bank and /swagbag guild say the bank is Blizzard's on Forever")`: one line each, and no setting changes.
    - `it("with the opt-in, the Forever bank shows bag 13 in the Character bank group")`:
      - `/swagbag safe bank`, then `m.bagIDs.bank = { 6, 13 }`, an item at (13, 1), `m.bagIDs.warband = {}`;
      - `BANKFRAME_OPENED`: the window opens, the item's button is in the Character bank group, and there is no Warband group content;
      - a search for `warband` finds nothing and `bank` finds it.
      - Mutation: literal Retail ranges in `BagKind`.
    - `it("the opt-in lasts one session")`: after a new `PLAYER_LOGIN`, the bank reason is `"forever"` again.
  - `spec/settings_spec.lua`: `it("on Forever Settings > Bank & guild shows only the note")`.
  - `spec/snapshots_spec.lua`: `it("on Forever the warband bank is never saved")`: after a bank open and close, `SwagBagDB.warband` is nil. Mutation: no gate in `Save`.
  - `spec/report_spec.lua`:
    - `it("on Forever the report names the client and the bag layout")`: the line is `"WoW Forever: Interface 16001 | bags 0-5 | bank tabs 6-14 | warband tabs 15-23"`, and the Safe line reads `bank=on (WoW Forever, 21:03)`.
    - `it("on Retail the report has no Forever line")`.
  - `spec/locale_spec.lua`: `it("defines the Forever Safe Mode reason")`: `SAFE_REASON_FOREVER`.
  - At least 12 new tests.

- [ ] **Step 2: Run them.** Expected: the new tests FAIL.

- [ ] **Step 3: Implement** as in Files and Interfaces.
  - No change to the bank window's layout code: Stage A only keeps it closed on Forever.
  - Stage B decides the "buy more bank slots" line from report §4.

- [ ] **Step 4: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Forever Stage A Task 4: Forever's bank and guild bank stay Blizzard's (Safe Mode reason forever); windows tested under Forever`.

---

### Task 5: TOC and release tooling know Forever but refuse it until Stage B; changelog, spec text and the Stage B checklist

**Files:**
- Create: `scripts/interfaces.lua`. It is pure Lua 5.1 and returns `M` when loaded with `dofile`. Run as `luajit scripts/interfaces.lua "<list>"`, it prints one `<type> <name>` line per number and exits 1 on an unknown one.
- Modify: `scripts/toc_check.lua`:
  - `local I = dofile("scripts/interfaces.lua")`;
  - `local FOREVER_READY = false -- Stage B sets this after the in-game checks`;
  - every `## Interface` number must be `retail` or `forever`, and a `forever` number fails while `FOREVER_READY` is false;
  - any `SwagBag/*.toc` other than `SwagBag.toc` fails (`find SwagBag -maxdepth 1 -name '*.toc'`);
  - the success line becomes `TOC OK (%d files; %s)`, with the version names joined by `", "`;
  - `REQUIRED` is unchanged.
- Modify: `scripts/release.sh`:
  - header comment (`--forever`);
  - `FOREVER_TYPE=88568` next to `RETAIL_TYPE=517`;
  - `ALLOW_FOREVER=0` and the option `--forever) ALLOW_FOREVER=1; shift ;;`;
  - step 6 reads `luajit scripts/interfaces.lua "$INTERFACES"` instead of the inline `printf` name.
  - For each line:
    - `retail`: the same lookup as today against `RETAIL_TYPE`;
    - `forever`: when `ALLOW_FOREVER` is 0, `fail "the TOC lists WoW Forever ($name). Forever uploads wait for the Stage B checks in game; add --forever when they pass."`; else the lookup against `FOREVER_TYPE`;
    - the "no version named" note names the type ("Retail" or "WoW Forever").
  - The summary line becomes `Game versions: <names>`, unchanged for a Retail-only TOC.
- Modify: `CHANGELOG.md`: a new `## 0.15.0` on top.
- Modify: `docs/superpowers/specs/2026-09-30-swagbag-design.md`: the §2.2 change log, plus a short "WoW Forever (Stage A)" paragraph next to the Adapter rule.
- Create: `docs/superpowers/plans/2026-10-22-swagbag-forever-stage-b-checklist.md`, written from the section below.
- Test: `spec/interfaces_spec.lua` (new)

**Interfaces:**
- Produces `I.Parse(list) -> { { iface = n, name = "x.y.z", type = "retail" | "forever" | "unknown" } }`:
  - `list` is the TOC's comma list; spaces and blanks are dropped; the order is kept;
  - `name` is `floor(n/10000) .. "." .. floor(n/100) % 100 .. "." .. n % 100`;
  - `type` is `"forever"` for `16000 <= n <= 16999` (the packager's `16???`), `"retail"` for `n >= 100000`, and else `"unknown"`.
- Produces `I.Lines(list) -> { "<type> <name>" }, ok`.
- `release.sh` keeps every Retail behaviour:
  - the same names (`12.1.0`, `12.1.5`), the same type 517, the same metadata;
  - with today's TOC, `--forever` changes nothing.

- [ ] **Step 1: Write the failing tests.** `spec/interfaces_spec.lua`:
  - `it("120105 is Retail 12.1.5 and 120100 is 12.1.0")`.
  - `it("16001 is WoW Forever 1.60.1")`. Mutation: typing by digit count only (`#s == 5`).
  - `it("16000 and 16999 are Forever; 17000 and 15999 are not")`.
  - `it("11509 (Classic Era) is unknown")`.
  - `it("a list keeps its order and drops spaces and blanks")`: `"120100, 120105,,16001 "` gives three entries in order.
  - `it("Lines prints type and name, and says not ok on an unknown number")`.
  - `it("today's TOC Interface line is Retail only")`: read `SwagBag/SwagBag.toc`; every entry is `retail`. This mirrors toc_check's Stage A rule. Mutation: adding `16001` to the TOC.
  - `it("there is no second TOC in SwagBag/")`: `find SwagBag -maxdepth 1 -name '*.toc'` lists only `SwagBag/SwagBag.toc`.
  - At least 8 new tests.

- [ ] **Step 2: Run them**: `luajit spec/runner.lua spec/interfaces_spec.lua`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - Write `scripts/interfaces.lua`, `toc_check.lua` and `release.sh` as in Files.
  - Check them by hand. None of these upload or use the Keychain:
    - `bash -n scripts/release.sh`;
    - `scripts/release.sh --help` shows `--forever`;
    - `luajit scripts/interfaces.lua "120100, 120105"` prints `retail 12.1.0` / `retail 12.1.5`;
    - `luajit scripts/interfaces.lua 16001` prints `forever 1.60.1`;
    - `luajit scripts/toc_check.lua` prints `TOC OK (... files; 12.1.0, 12.1.5)`.
  - CHANGELOG (exact):
    ```
    ## 0.15.0

    - Groundwork for WoW Forever. Nothing changes on Retail: your bags, bank and settings work exactly as before.
    ```
  - The design spec's change log: "v1.5 (0.15.0): WoW Forever groundwork (Stage A). Flavor detection and the capability table in the Adapter, bag IDs from Enum.BagIndex, Retail-only features off on Forever, Forever's bank and guild bank left to Blizzard. Not declared in the TOC; no Forever upload."
  - The checklist file: "Claude installs the build first", then a full game restart; numbered steps, one action each, each saying what the user should see; quoted strings exactly as in enUS.lua.

- [ ] **Step 4: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Forever Stage A Task 5: interface mapping, TOC and release guards for Forever; changelog and Stage B checklist`.

---

## Stage B in-game checklist (for the user, Forever client, launch week)

Claude installs the build first; then restart the game fully. The TOC does not list Forever yet, so on the character screen open AddOns and tick "Load out of date AddOns".

- **F-1 Client facts.** Type each line and note the answers for Claude:
  1. `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT, WOW_PROJECT_MAINLINE`: expect `18, 18, 1`.
  2. `/dump select(4, GetBuildInfo())`: the launch Interface number (16001 or new).
  3. `/dump C_Bank.ShouldUsePlayerBagsInBank()`.
  4. `/dump C_Bank.FetchPurchasedBankTabIDs(0)` at the bank: expect 6 upwards.
  5. `/dump C_Bank.CanViewBank(2)`: is the warband bank on?
- **F-2 Report.** `/swagbag report` shows "WoW Forever: Interface 16001 | bags 0-5 | bank tabs 6-14 | warband tabs 15-23" and "bank=on (WoW Forever, ...)". The bags must say off.
- **F-3 Checks.** `/swagbag check` ends with "0 required" failed. Copy any FAIL lines to Claude.
- **F-4 Bags.** Press B. SwagBag's bags open with your items in sections; reagent-bag items are in Reagents. Hover three items: the tooltips look normal.
- **F-5 Nothing Retail-only.**
  1. Settings > Overlays has no "Upgrade track" or "Keystone" row.
  2. Settings > Footer lists Gold, Currencies and Free slots only.
  3. Settings > Focus modes has no M+ or Delves mode.
  4. `/swagbag setup` offers four styles, with no M+.
- **F-6 Bank.** Talk to a banker. Blizzard's bank opens, and the chat shows once: "On WoW Forever, Blizzard's own bank and guild bank are used for now: SwagBag's bank windows wait until they have been checked there. Your bags still use SwagBag." Close it and open it again: no second line.
- **F-7 Bank, opt-in (testing only).**
  1. `/swagbag safe bank`, then talk to the banker again. SwagBag's bank opens.
  2. Every item from every bank bag you bought is in the Character bank group. None of it is in Warband or New.
  3. Blizzard's Bank / Warband Bank tabs sit in SwagBag's header and switch where right-click deposits go.
  4. Buying a bank bag slot still works in Blizzard's frame (Settings > Bank & guild, "shown").
  5. Note anything that looks wrong. The next login turns it back to Blizzard's.
- **F-8 Guild bank** (if your guild has one): Blizzard's guild bank opens, with no second chat line.
- **F-9 In an instance.** Open your bags inside a dungeon: no Lua error, items stay visible.
- **F-10 Other bag addons.** If Baganator or Bagnon is installed, SwagBag's login line names it.

## Decisions

- **Detection: project constant first, then a feature fallback; never the Interface number** (report §3).
  - A renamed constant (`WOW_PROJECT_FOREVER`) and an unknown non-Retail project both take the Forever profile: uncertain means restricted.
  - Retail is recognised only by `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`, so a new Forever API reaching Retail cannot flip it.
  - No constants at all (the test environment) is Retail, so every existing test is untouched.
- **One capability table, `A.FEATURES`, owning both the decision and the UI surfaces.** UI files ask `Allows(surface, id)` and never know which client they run on. Adding a Forever feature in Stage B is a one-line `forever = true`.
- **Retail-only reads give their existing "no data" answer inside the Adapter, before any API call.** They are on Forever's API surface (report §2), so feature detection alone would read them.
- **Absent data needs no gate.** On Forever these simply match nothing:
  - the `keystone`, `crest`, `warbound`, `wue` and `housing` keywords;
  - the Keystone & Crests category (empty sections are not drawn);
  - the Signals keystone read;
  - `CHALLENGE_MODE_COMPLETED`, whose registration is already pcall-guarded.
  - There are no crafting-quality overlays in the code, so there is nothing to gate (report §3's row).
- **Bag IDs:**
  - All ranges come from `Enum.BagIndex` names, read as consecutive runs from `_1`.
  - An incomplete or overlapping table falls back whole to the verified 12.1.5 Retail table, the only literals left. A half-derived layout is the "Safe Mode can't catch it" failure.
  - The layout is cached per table identity, so `BagKind` stays two table lookups.
  - `/swagbag report` prints the derived ranges on Forever, so Stage B sees them.
- **The pinned check stays pinned, per client.** `AccountBankTab_1` must be 12 on Retail and 15 on Forever (`foreverValue`). Retail's check, detail and line count are byte-for-byte; a Forever renumbering still trips Safe Mode.
- **Forever's bank in Stage A is Blizzard's, through the existing bank Safe Mode with a new reason.** The report's proposed design (§4) needs a real client: `ShouldUsePlayerBagsInBank`, the Camelot `TabSystem` hosted in SwagBag's header, warband availability and bank-bag purchase. Safe Mode is the tested fallback, and it already covers the guild bank, the bank menu, warband gold, deposit tooltips and the "Show bank" button.
- **The notice is one line per session, at the first bank or guild-bank visit, never at login.** It shows when it matters, and login stays the single "loaded" line.
- **The Stage B opt-in is the existing `/swagbag safe bank`, for one session.** Boot re-applies `"forever"` before reading `safeMode.*`. No new command or setting is added, and a player who stumbles on it is back to Blizzard's bank at the next login.
- **The warband bank is never read on Forever in Stage A.** Tab IDs and snapshots are off, so the alt viewer and tooltip counts never show an empty or stale Warband.
- **The guild bank is off on Forever** (it shares the bank's Safe Mode). Whether Forever guilds have one is unknown (report §5, item 8).
- **The TOC stays `120100, 120105`; no `SwagBag_Forever.toc` or `_Mainline.toc`.**
  - Listing 16001 would make the Forever client treat SwagBag as current and load it for anyone with the folder, before an in-game check.
  - CurseForge offers a file by the game versions attached at upload; `release.sh` attaches Retail only, and refuses Forever without `--forever`.
  - `toc_check.lua` refuses a Forever number (`FOREVER_READY = false`) and any second TOC (the `_Mainline` trap).
  - Stage B appends 16001 and the launch number to the single `SwagBag.toc`, as the report recommends (one file list, the runtime decides).
- **The Interface-to-type mapping lives in a pure Lua file**, so it is unit-tested. `release.sh` and `toc_check.lua` share it, and Retail's names and type 517 come out exactly as today.
- **The bags window stays SwagBag's on Forever.** Bags 0-5 and the reagent bag are identical on both clients (report §2), and its required checks are the same Midnight API. Stage A protects players who tick "Load out of date AddOns" before Stage B.
- **`BANK_TAB_CAPACITY` (98) is unchanged.** The pool already takes `max(NumSlots, 98)`, and Forever pages at 88.

## Schedule

| Task | Files (main) | New tests (at least) |
|---|---|---|
| 1 Flavor, capability table, mock Forever mode, 0.15.0 | Adapter, check.sh, mock_adapter, loader | 14 |
| 2 Bag IDs from Enum.BagIndex; per-client check | Adapter, Checks, SafeModeHooks, mock_adapter | 16 |
| 3 Retail-only features off on Forever | Adapter, Overlays, SettingsPages, Footer, Focus, SettingsFocus, Setup, QuickSetup | 22 |
| 4 Forever bank is Blizzard's; windows under Forever | SafeMode, Boot, BankWindow, GuildBankWindow, SettingsPages, Snapshots, Report | 12 |
| 5 Interface mapping, TOC and release guards, docs | interfaces.lua (new), toc_check, release.sh, CHANGELOG, design spec, checklist | 8 |

From 1992 to at least **2064**.

## Not in this plan (named so nobody adds them)

- Adding 16001 or the launch Interface number to the TOC, a second TOC, setting `FOREVER_READY`, or any upload, tag or push. Those are Stage B, after the checklist.
- SwagBag's bank window design on Forever (report §4): the "Buy more bank slots" line, Warband-group gating on `CanViewBank(Account)`, and the Camelot skin and tab sizes.
- Sizing bank button pools from `GetContainerNumSlots` only (dropping the 98 floor).
- Turning any feature on for Forever (`forever = true`): the warband bank, warband gold, the guild bank, upgrade tracks.
- Reviewing category, consumable or keyword defaults for Forever's item sets (report §5, "scope creep").
- New `A.CHECKS` entries for Forever-only APIs; they would change Retail's `/swagbag check` output.
- Changes to `OtherBagAddons` for Forever-specific bag addons.
- Running `scripts/release.sh --dry-run` against CurseForge (it needs the Keychain token; do it at launch).

### Critical Files for Implementation
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/SwagBag/Core/Adapter.lua
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/spec/mock_adapter.lua
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/SwagBag/Core/Boot.lua
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/SwagBag/UI/Footer.lua
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/scripts/release.sh
