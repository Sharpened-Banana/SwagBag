# SwagBag Week 3 (Oct 15–21, 2026): Bank and Warband Bank, Guild Bank, Overlays, Auctionator Totals, Snapshots. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** By the end of week 3 the user banks, uses the warband bank and the guild bank through SwagBag every day: one bank window with the character bank and the warband bank stacked, a full guild bank window, item overlays with an upgrade arrow (on the bags from day 2), the average equipped item level in the bags title, per-category gold totals from Auctionator, and bank/guild snapshots saved on every visit. The two first-day checks (V2, G1) run on Oct 15, and each has a fallback that is one setting.

**Architecture:** Blizzard's bank and guild bank frames stay open the whole visit. They are parented to an invisible 0.001-scale frame (`UI/TinyHost.lua`), and their real tab buttons are moved onto SwagBag's windows. SwagBag only reads which tab is selected. The bank and guild bank contents are drawn by a new multi-group view, `UI/GroupView.lua`: a stack of groups (character bank and warband bank, or one group per guild tab), each with its own week-2 `Layout` state, the same hover guard, and redraws that touch only the buttons that moved. Pure engine modules add snapshots (`Engine/Snapshots.lua`), prices (`Engine/Prices.lua` plus `Providers/Auctionator.lua`) and overlay data with the upgrade arrow (`Engine/OverlayData.lua`). `UI/Overlays.lua` draws them on bag buttons first (Task 4), then on bank and guild buttons (Task 11). The bags window's title shows the average equipped item level (`SwagBag — ilvl 279.4`).

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements spec §12.2 week 3: M4 (F2, §5), M4G (F16), M6 (F9, F10), and the October half of F13 (snapshots are captured; the offline view is November, §12.1). It also folds in every item that the week-1 and week-2 ledgers mark for week 3 (`docs/superpowers/plans/2026-09-30-swagbag-week1-ledger.md`, `docs/superpowers/plans/2026-10-01-swagbag-week2-ledger.md`). Week-2 plan (style and interfaces): `docs/superpowers/plans/2026-10-01-swagbag-week2-categories.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week3-banks`. The controller creates it before Task 1. No task creates or switches branches.

**The code on `main` (commit `5be2c2b`, 427 tests; it only adds this plan on top of week 2's `7beafdc`) is the source of truth.** Every interface below was read from the merged week-2 code:
- `Buttons.Get/Count/EnsureCapacity/Place/Paint/SetDimmed/AcquirePlaceholder/ReleasePlaceholders/KindOf/SetParentFor/CreateAll` and `Buttons.created`.
- `SectionHeaders.Acquire(parent, id, label, x, y, width)` and `ReleaseAll()`, whose clicks call the module-level `onClick`/`onDrop` (the bags window's).
- `BagsWindow`: `busyCheck`, `sizeFrame(width, height, keepTop)`, `Sort`/`Reflow`/`RequestLayout`/`ApplyChanges`/`DropOnSection`/`ForEachSlot`, and `W.records[bag][slot]`.
- `Layout.Build/Position/Moves/Apply` and `Layout.Key(bag, slot) = bag * 1000 + slot`.
- `Search` is a single module (`SB.Search`) and `SearchBox` is bound to the bags window.
- `Inventory.ScanBag/ScanAll/OnChanged/Has/R`, `Items.Describe`.
- `Config` schema 2 with `settings`, `userEdits`, `categories`, `ui.collapsed[window]`.
- `SafeMode.WINDOWS = { "bags", "bank" }`.

## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only.
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. `spikes/SwagBagSpikes/SpikeBank.lua` is reference only (the tiny-mode idea); none of its code is copied.
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator`.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `scripts/check.sh` enforces this with LuaJIT's parser and a `goto` grep.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace or `Enum`, **comments included** (grep-enforced for `C_X.`/`Enum.`, review-enforced for bare names). Everything else calls `SB.Adapter.*`. Spec files under `spec/` may name them as test data.
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, enforced by `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`.
- **SwagBag never writes Blizzard bank or guild bank state.** It reads `BankFrame:GetActiveBankType()` and `GetCurrentGuildBankTab()` through the Adapter. It never selects a tab, never sets a bank type, and never closes the bank from its own code. The only changes it makes to Blizzard frames are parents and anchors (tiny mode), and it puts every one back exactly (`UI/TinyHost.lua`).
- P2: every command and button gives feedback (a title flash or a chat line).
- P5 / spec §4.2 rule 5: while a window is open, a slot button moves only into New or Free (spec §4.3). It never moves while it is under the mouse or while an item is on the cursor. That includes a push from a group above that grew. Held-back moves retry 300 ms later through `SB.Debounce` (a `C_Timer`), never `OnUpdate`.
- P6: every WoW entry point (events, hooks, `OnClick`/`OnEnter`/`OnLeave`/`OnHide`/`OnShow`/`OnDragStart`/`OnReceiveDrag`/`OnMouseWheel` scripts, timers, slash commands) runs inside `SB.ErrorTrap.Run` or `SB.ErrorTrap.Guard`. Bank and guild bank code uses window `"bank"`. Never call `seterrorhandler`.
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails if code uses an undefined `L.KEY`.
- Item buttons (`ContainerFrameItemButtonTemplate`) are never reparented, destroyed or re-`SetID`'d, and never created in combat (growth is queued with `SB.OutOfCombat`). Only their per-bag *bag frames* may move to a window's scroll child, and only out of combat. Guild bank buttons are SwagBag's own plain `ItemButton`s, and they too are created out of combat. Placeholders and section headers are pooled **plain** frames and may be created in combat (ruling P9). Pools re-parent on Acquire.
- No file calls `Config` at load time (a load-order test per new window). Every `OnHide` handler starts with `if self:IsShown() then return end` (Alt+Z hides UIParent).
- No `OnUpdate` scripts anywhere. Idle CPU with every window closed is 0.
- Spec §9 budgets this week touches: first bank open (≈700 slots) ≤ 80 ms, hidden until complete; incremental update ≤ 5 ms for ≤ 10 changed slots; Auctionator lookups ≤ 0.01 ms per call and ≤ 2 ms per layout (session cache); no snapshot writes in combat. Spec §8.4: 1.5 MB hard cap on saved snapshots, with the oldest-seen characters' bank snapshots dropped first.
- Randomized tests use an exact generator (Park-Miller `seed * 16807 % 2147483647`), assert coverage minimums, and every critical test names the mutation that must make it fail. Tie-break tests use fixtures where definition order and id order disagree.
- **Tooling deviation (binding, same as weeks 1–2):** tests run with `luajit spec/runner.lua spec/*_spec.lua` using the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- One commit per task, made with `git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit`. The message ends with exactly these two lines:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`
- In-game checks are written for the user, who is not a programmer:
  - numbered, one action per step, each saying what the user should see;
  - after a click on an item, the step says to move the mouse off it (the hover guard holds moves under the mouse);
  - a session after a task that adds files starts with a full game restart, not `/reload`;
  - every quoted string matches `SwagBag/Locale/enUS.lua` exactly.
  In-game sessions do not block the build; findings come back as fixes. The first-day checks V2 and G1 decide their fallbacks by day 2 (spec §12.2).

## Review Focus

1. **The bags window and the bank window open at the same time.** At a banker both are open, and the bags window redraws often (deposits, Reflow). Expected: a redraw of one window never takes the other window's section headers or placeholders. Week 2's pools released *every* header and placeholder. Pinned by Task 5 (`buttons_spec` "ReleasePlaceholders(parent) releases only the placeholders inside that parent", "ReleaseAll(parent) releases only that window's headers…") and Task 8 (`bankwindow_groups_spec` "a bags redraw (Reflow, a bag change) never takes the bank window's headers or placeholders").
2. **The bank or guild vault closing in combat, the player logging out with the bank open, or Safe Mode switching on mid-visit.** Expected: Blizzard's frames get their parents and anchors back exactly. In combat they get them back the moment combat ends. Nothing stays invisible. Pinned by Task 1 (`tinyhost_spec` "Restore in combat waits for combat to end…", `bankwindow_spec` "a bank closed in combat is put back as soon as combat ends", "logging out during a visit puts Blizzard's bank back (spec 8.6)", "Safe Mode for the bank…") and Task 10 (`guildbank_spec` "closing the vault puts Blizzard's frame and its tabs back exactly…").
3. **Guild bank tab answers that arrive late, out of order, or never.** The client answers `QueryGuildBankTab` one tab at a time, and reading a tab before its answer may return nothing. Expected: a tab never looks empty because its answer is still on the way; an unanswered tab is asked once more; a reopen shows the session's cached contents at once. Pinned by Task 10 (`guildbank_spec` "a reopen shows the session's cached contents at once; a tab whose answer is on its way is not read", "a query that gets no answer moves on after QUERY_GAP and is asked once more at the end").
4. **Items moving in the upper bank group while the mouse rests on the lower group.** A withdrawal adds a row to the character bank's Free section, which pushes the warband group down. Expected: the push waits until the mouse leaves the pushed buttons, and no button ever moves under the mouse. Pinned by Task 7 (`groupview_spec` "a group that grows a row pushes the groups below, but not while one of them is under the mouse", and the randomized "never moves a hovered button, and after each drain every category cell holds its own item").
5. **Damaged or oversized saved snapshot data** (a hand-edited `chars` that is a string, a warband entry that is a number, many alts' banks). Expected: saving never errors; damaged parts are replaced; over 1.5 MB the bank snapshots of the characters seen longest ago are dropped first (never the current character's), with one chat line. Pinned by Task 9 (`snapshots_spec` "damaged saved snapshot tables never break a save", "over 1.5 MB, other characters' bank snapshots go first, seen longest ago first, ties by name").

## Decisions and deviations from the spec (read before Task 1)

| # | Spec text | This plan | Why |
|---|---|---|---|
| D1 | §5.4 "Blizzard's bank frame stays visible, anchored to the right of SwagBag's window" | In "beside" mode SwagBag's window is anchored to the right of **Blizzard's** bank frame. SwagBag never moves `BankFrame`. | Moving a Blizzard panel is writing its frame state. Anchoring our own frame to it is a read. |
| D2 | F12 / §10.1: Safe Mode per window, `bags` and `bank` | The guild bank shares the `bank` Safe Mode flag. There is no third window. | An error in either bank turns both over to Blizzard. This avoids changing `/swagbag safe`, the report line and every Safe Mode test. |
| D3 | AC16.1 "(or one tab at a time, option)" | Not built this week. Each tab group collapses on its own (saved per character). | The brief asks for all tabs stacked. A collapsed group gives the same view. |
| D4 | AC16.7 "SetCurrentGuildBankTab only if G1 proves it untainted, otherwise … re-hosted" | Tabs are always switched with Blizzard's re-hosted tab buttons. `SetCurrentGuildBankTab` is never called, and G1 does not test it. | Re-hosting is always spec-compliant. A direct call would need its own taint check for no user benefit. |
| D5 | AC16.2 "Withdraw: right-click…" | A right-click withdraws from **any** tab with `AutoStoreGuildBankItem(tab, slot)`. G1 step 7 checks this. Fallback: `guildBank.withdrawAnyTab = false`, which refuses with "Click the X tab on the right first…". | Blizzard only ever withdraws from the selected tab. Whether the server accepts another tab is an in-game fact. |
| D6 | F13 AC13.1: bags on logout and every `BAG_UPDATE_DELAYED` (5 s); banks on open and close | As written, plus every bank update while the bank is open (1 s debounce, spec §5.7). The close snapshot is taken from SwagBag's own inventory model, because the client may already read 0 slots by then. | Spec §5.7 lists the open-time updates. |
| D7 | §8.2 shows `chars`/`warband` in the schema | No schema bump. The tables are created on the first save and repaired if damaged (`Snapshots.DB`). | Nothing old needs converting. A migration would only touch every config test. |
| D8 | §7.3 `crest`: "item ID allowlist in data file", §13.2 item 4 | `Engine/Crests.lua` starts with **no** item IDs. Non-gear items whose name contains "crest" or "valorstone" match until session O1 confirms the season's IDs. A loading item is "not a crest" (false, not nil). | No verified Midnight item IDs exist yet. A nil in Keystone & Crests (priority 95) would hold every loading item in New (week-2 D3). |
| D9 | AC10.1 "items show AH value on hover" | Not added. Auctionator already adds its price to item tooltips, and Blizzard's tooltip shows the vendor price. | It would duplicate a line. The AH value *overlay* is v1.1 (§2.2). |
| D10 | AC9.3 "matching slot(s)" | A one-hander also compares with the off hand only when the off hand holds a one-hand weapon (dual wield). An off-hand item never beats an equipped two-hander, because equipping it would leave the main hand empty. | The spec does not cover these two cases. |
| D11 | F10 per-category totals | A bound item counts at its vendor price only. | It cannot be sold on the auction house. |
| D12 | AC2.7 "Sort buttons for … character bank and warband bank" | `Sort bank` and `Sort warband` sit in the bank window's title row. | One place, like the bags window's Sort. |
| D13 | AC4.3 drag onto a header | A drop on a **bank** section header uses the bags window's drag-to-assign. A drop on a guild section header does nothing. | Assigning categories from the guild vault would surprise users. |
| D14 | AC1.5 scale | The bank and guild bank windows are not scalable this week (the wheel scrolls). | Settings week (week 4). |
| D15 | — (not in spec) | A `Blizzard bank` button shows Blizzard's bank for this visit only. | In tiny mode, tab purchase (`PurchaseBankTab` stays Blizzard's) and warband gold live in Blizzard's hidden frame. |
| D16 | §7.3 numeric `gold`/`value` | Registered now (`value>100`), volatile, from `Prices`. | The spec §7.4 example `value>100 & tradegoods` works this week. |
| D17 | F16 "Tab contents load on demand" | A tab read for the first time in the session is laid out in full (held back while the mouse is over the items). Later changes follow spec §4.3 (placeholder, New, Free). | Otherwise a tab's first answer would put every item in New. |
| D18 | §12.2 week 3 order (overlays after the banks); title not in spec | **The user's decisions of 2026-10-02.** (1) Overlays move to the front: overlay data and the arrow (Task 3) and overlays on the bags (Task 4) come right after V2 and G1; bank and guild buttons get theirs in Task 11, once those windows have contents. (2) New: the bags window's title shows the character's average **equipped** item level with one decimal, `SwagBag — ilvl 279.4`, from `GetAverageItemLevel()`'s second value (feature-detected; plain `SwagBag` without it, no error). It is read on open, `PLAYER_EQUIPMENT_CHANGED` and `PLAYER_AVG_ITEM_LEVEL_UPDATE`; a title flash (`SwagBag 105%`, `Regrouped`, …) is never cut short, and the item-level title comes back after it. Setting `bags.showIlvl` (default on), switched with `/swagbag overlays title on|off`. | The user wants overlays and the item level on the bags within days. The overlays need only the bags' item records, so nothing from Tasks 5–12 moves with them, and prices (Task 12) are never read by an overlay. |

---

## File structure (end of week 3)

New and changed files only. Everything else is as on `main`.

```
SwagBag/UI/TinyHost.lua              NEW  tiny mode: keep a Blizzard frame shown at scale 0.001; re-host its tabs; restore exactly
SwagBag/UI/BankWindow.lua            NEW  bank window: tiny/beside, read-only deposit target, two groups, sort, reflow, grid, search
SwagBag/UI/GuildButtons.lua          NEW  SwagBag's own guild slot buttons (withdraw / pickup / drop through the Adapter)
SwagBag/UI/GuildBankWindow.lua       NEW  guild bank window: full/view, re-hosted tabs, one group per tab, queries, cache
SwagBag/UI/GroupView.lua             NEW  stacked groups of Layout sections or grids; hover guard across groups; incremental redraw
SwagBag/UI/Overlays.lua              NEW  draws overlay data on bag, bank and guild buttons; /swagbag overlays
SwagBag/Engine/Snapshots.lua         NEW  spec 8.3 format, capture timing, 8.4 budget; /swagbag snapshot
SwagBag/Engine/Prices.lua            NEW  provider registry, session cache, section totals, money format
SwagBag/Providers/Auctionator.lua    NEW  the Auctionator price provider
SwagBag/Engine/OverlayData.lua       NEW  record -> overlay data; the AC9.3 upgrade arrow
SwagBag/Engine/Crests.lua            NEW  crest data (spec 7.3, 13.2 item 4)
SwagBag/UI/Buttons.lua               MOD  growth max-merge, CreateAll retry, SetParentFor moves bag frames, EnsureBankTabs, per-parent placeholders
SwagBag/UI/SectionHeaders.lua        MOD  per-window owners and release; value in the label; Totals/IsVendor
SwagBag/UI/BagsWindow.lua            MOD  incremental ApplyChanges, cells past a bag's size, scale saves position, drag guard, totals, overlays, item-level title
SwagBag/UI/SearchBox.lua             REWRITE  SearchBox.New(o) factory; the bags box is built through it
SwagBag/Engine/Search.lua            REWRITE  SearchState.New() instances; SB.Search is the bags window's
SwagBag/Engine/Layout.lua            MOD  Position(opts.top)
SwagBag/Engine/Inventory.lua         MOD  ScanKind (no "new" marks) on BANKFRAME_OPENED
SwagBag/Engine/Items.lua             MOD  DescribeLink (guild records), track, hasNoValue
SwagBag/Engine/Keywords.lua          MOD  value/gold, crest/upgrade currency
SwagBag/Engine/CategoryDefaults.lua  MOD  Keystone & Crests = "keystone | crest"
SwagBag/Core/Adapter.lua             MOD  bank, guild bank, sort bank, time/char, Auctionator, overlay reads, average item level; optional checks
SwagBag/Core/Config.lua              MOD  bank, guildBank, prices, overlays, bags.showIlvl defaults (schema stays 2)
SwagBag/Core/Report.lua              MOD  Bank, Last bank layout, Prices, Snapshots, Guild bank lines
SwagBag/Core/Init.lua, SwagBag.toc, Locale/enUS.lua, .luacheckrc   MOD
spec/helpers/fakeframe.lua, spec/helpers/uienv.lua               NEW  fake frames; shared window test set-up
spec/tinyhost_spec.lua, bankwindow_spec.lua, bankwindow_groups_spec.lua, guildbank_spec.lua, groupview_spec.lua,
spec/snapshots_spec.lua, prices_spec.lua, overlaydata_spec.lua, overlays_spec.lua                NEW
```

## Schedule (daily testing; spec §12.2 week 3: "V2, G1, overlay spot-checks"; "fallback decided by day 2")

| Day | Tasks | User in game? |
|---|---|---|
| Thu Oct 15 | 1, 2 | **yes, first day:** session V2 (Task 1, bank, about 10 minutes) and session G1 (Task 2, guild vault, about 10 minutes) |
| Fri Oct 16 | 3, 4 | **yes:** session O1 (Task 4: overlays and the item level in the title, on the bags; about 10 minutes). **Day 2:** if V2 or G1 failed, its fallback becomes the default today (one line in `Config.Defaults`, see the session's "If it fails") |
| Sat Oct 17 | 5, 6, 7 | **yes:** session S3 (Task 5, 2 minutes) |
| Sun Oct 18 | 8, 9 | **yes:** session B1 (Task 9: bank contents, sort, snapshots), about 15 minutes |
| Mon Oct 19 | 10, 11 | **yes:** session G2 (Task 11: guild bank contents, overlays in the bank and guild windows), about 15 minutes |
| Tue Oct 20 | 12 | **yes:** session P1 (Task 12: gold totals, 5 minutes); daily bank check (5 minutes) |
| Wed Oct 21 | fixes from the user's reports | **yes:** daily bank check (5 minutes); **Week 3 exit check** |

Tasks 1 and 2 come first because no in-game session has run yet: V2 and G1 are the riskiest unknowns (spec §13.1), and their fallbacks are setting switches, so a failure never blocks Tasks 3–12. Tasks 3 and 4 come next by the user's choice (D18): overlays and the item-level title on the bags within days. They need nothing from the bank work. The bank and guild buttons get their overlays in Task 11, after both windows have contents (Tasks 8 and 10). Prices come last (Task 12); no earlier task reads a price.

Cumulative `scripts/check.sh` test totals when tasks run in numeric order (verified by replaying every task's blocks from this file on a fresh clone of `main`): start 427 · T1 451 passed, 0 failed · T2 476 passed, 0 failed · T3 490 passed, 0 failed · T4 506 passed, 0 failed · T5 518 passed, 0 failed · T6 520 passed, 0 failed · T7 536 passed, 0 failed · T8 554 passed, 0 failed · T9 568 passed, 0 failed · T10 574 passed, 0 failed · T11 578 passed, 0 failed · T12 590 passed, 0 failed.

## How the TOC grows

Each task's TOC block shows exactly where its new lines go. `scripts/check.sh` prints `TOC OK (N files)`: 32 on `main`, 34 after Task 1, 36 after Task 2, 38 after Task 3, 39 after Tasks 4–6, 40 after Tasks 7–8, 41 after Tasks 9–11 and 43 after Task 12. Final order of the changed sections:

```
# Engine
Engine/Items.lua
Engine/Inventory.lua
Engine/GridLayout.lua
Engine/Query/Lexer.lua
Engine/Query/Parser.lua
Engine/Query/Query.lua
Engine/Crests.lua
Engine/Keywords.lua
Engine/Search.lua
Engine/CategoryDefaults.lua
Engine/Categories.lua
Engine/Categorizer.lua
Engine/Layout.lua
Engine/Snapshots.lua
Engine/Prices.lua
Engine/OverlayData.lua

# Providers
Providers/Auctionator.lua

# UI
UI/ReportBox.lua
UI/Buttons.lua
UI/SectionHeaders.lua
UI/BagsWindow.lua
UI/SafeModeHooks.lua
UI/SearchBox.lua
UI/TinyHost.lua
UI/GroupView.lua
UI/BankWindow.lua
UI/GuildButtons.lua
UI/GuildBankWindow.lua
UI/Overlays.lua
UI/DebugV1.lua
```

## How to read the code steps

- A **Create** step gives a complete new file.
- A **Replace the whole file** step gives the complete new content of an existing file.
- An **In `path`, find … and replace it with …** step gives an exact block of the current file (it occurs exactly once) and its replacement.
- Copy every block verbatim, including tabs, and apply a task's blocks in the order shown. The `<!-- sbw3:… -->` comments mark blocks for the replay check (see "How this plan was checked"); leave them out of the code.
- Every block in this plan was applied in this order to a fresh clone of `main` and checked with `scripts/check.sh`. The `Expected` lines are those real outputs.

**Critical tests and their mutations.** For each task, the list under Step 2 names the critical tests and the code change (mutation) that must make each one fail. Every mutation was applied to the finished code and the named test failed. A reviewer re-runs any of them with a one-line edit.

---
### Task 1: First-day check V2: tiny-mode bank, the bank window shell, the read-only deposit target, the "beside" fallback

Spec §5.2 and §11.3 V2: SwagBag shows the bank while Blizzard's bank frame stays open and invisible ("tiny mode"). Deposits must still land in whichever bank type Blizzard has selected, and a Hearthstone must work afterwards. Nobody has tested this in game yet. This task builds the smallest real piece that lets the user test it today:
- `UI/TinyHost.lua`, which keeps a Blizzard frame shown at scale 0.001 and re-hosts its tab buttons;
- the `SwagBag bank` window, still without contents (those come in Task 8), with the deposit line read from Blizzard and the `Blizzard bank` button;
- the fallback setting `bank.blizzardFrame = "tiny" | "beside"` (spec §5.4, AC2.6) with `/swagbag bank tiny|beside`;
- the "Bank still open" button on the bags window (spec §5.6).

The code is not throwaway: Task 8 fills this window.

The task also adds `spec/helpers/fakeframe.lua`, a fake frame that every week-3 UI spec uses. It records shown state, parent, anchors, scripts and hooks; `Show`/`Hide` fire `OnShow`/`OnHide`; and every other method is a recorded no-op (`f.calls[name]`). That is how the tests prove "no call on BankFrame besides moving it". The version goes to 0.3.0, so the loaded line and the report show the week-3 build.

**Files:**
- Create: `SwagBag/UI/TinyHost.lua`, `SwagBag/UI/BankWindow.lua`
- Modify: `SwagBag/Core/Adapter.lua` (`Frame`, `ActiveBankType`), `SwagBag/Core/Config.lua` (`bank.blizzardFrame`), `SwagBag/Locale/enUS.lua`, `SwagBag/Core/Report.lua` (bank line), `SwagBag/Core/Init.lua` and `SwagBag/SwagBag.toc` (version 0.3.0, two files)
- Test: `spec/helpers/fakeframe.lua` (new), `spec/mock_adapter.lua`, `spec/tinyhost_spec.lua` (new), `spec/bankwindow_spec.lua` (new), `spec/report_spec.lua`

**Interfaces:**
- Consumes (on `main`): `SB.On/Emit/OutOfCombat/Debounce`, `SB.ErrorTrap.Guard`, `SB.SafeMode.IsOn`, `SB.Config.Get/Set/UI`, `SB.Slash.Register`, `SB.BagsWindow.frame` and `SB.BagsWindow.sortButton` (the "Bank still open" button's parent and anchor), `SB.Adapter.InCombat/After`.
- Produces:
  - `SB.Adapter.Frame(name) -> frame | nil` and `SB.Adapter.ActiveBankType() -> "bank" | "warband" | nil` (read only).
  - `SB.TinyHost.Parent() -> frame` (the shared 1×1, 0.001-scale parent).
  - `SB.TinyHost.New(label, window) -> host` with `host.Shrink(frame) -> bool`, `host.Rehost(frame, onto, place) -> bool`, `host.Restore() -> bool` (false = waits for combat to end) and `host.IsActive() -> bool`.
  - `SB.BankWindow`:
    - fields: `frame`, `host`, `interaction`, `visit`, `target`, `lastVisit`, `blizzardButton`, `stillOpenButton`;
    - mode and target: `Mode() -> "tiny"|"beside"`, `VisitMode()`, `GroupName(kind) -> text`, `RefreshTarget()`, `ApplyMode()`, `ToggleVisit() -> bool`;
    - window: `Open() -> bool`, `Close()`, `IsOpen()`, `Flash(text)`, `RestorePosition()`, `TitleButton(text, label, onClick, width)`, `RefreshStillOpen()`, `OnBankOpened()`, `OnBankClosed()`.
  - Internal events `SB_BANK_TARGET(target)`, `SB_BANK_OPENED`, `SB_BANK_CLOSED` (our window hidden).
  - Setting `bank.blizzardFrame`. Slash command `bank`. Report line `Bank: setting %s, last visit %s, last deposit target %s`.
  - `spec/helpers/fakeframe.lua`: `Fake.Install()`, `Fake.Uninstall()`, `Fake.New(kind, parent)`, `Fake.Fire(f, script, ...)`, `Fake.CreateFrame`.

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:file T1 s01 spec/helpers/fakeframe.lua -->
Create `spec/helpers/fakeframe.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Fake WoW frames for the week-3 UI specs. A fake records what the window logic depends
-- on (shown state, parent, anchors, scripts and hooks, text, scale, size, mouse-over) and
-- turns every other method into a recorded no-op: f.calls[name] = { args }.
--   Fake.Install()            sets CreateFrame, UIParent, UISpecialFrames, GameTooltip
--   Fake.Uninstall()          clears those globals again (call it in after_each)
--   Fake.New(kind, parent)    a fake frame
--   Fake.Fire(f, script, ...) run f's script and then its HookScript hooks
-- Show and Hide fire OnShow / OnHide like the client (only on a real change).
local Fake = {}

local methods = {}

function Fake.Fire(f, name, ...)
	local s = f.scripts[name]
	if s then
		s(f, ...)
	end
	for _, h in ipairs(f.hooks[name] or {}) do
		h(f, ...)
	end
end

function methods.IsShown(self) return self.shown end
function methods.IsVisible(self) return self.shown end
function methods.Show(self)
	if not self.shown then
		self.shown = true
		Fake.Fire(self, "OnShow")
	end
end
function methods.Hide(self)
	if self.shown then
		self.shown = false
		Fake.Fire(self, "OnHide")
	end
end
function methods.SetShown(self, v)
	if v then
		self:Show()
	else
		self:Hide()
	end
end
function methods.SetParent(self, p) self.parent = p end
function methods.GetParent(self) return self.parent end
function methods.SetScale(self, s) self.scale = s end
function methods.GetScale(self) return self.scale end
function methods.SetSize(self, w, h) self.w, self.h = w, h end
function methods.SetWidth(self, w) self.w = w end
function methods.SetHeight(self, h) self.h = h end
function methods.GetWidth(self) return self.w end
function methods.GetHeight(self) return self.h end
function methods.ClearAllPoints(self) self.points = {} end
function methods.SetPoint(self, ...)
	local p = { ... }
	self.points[#self.points + 1] = p
	if p[3] == "BOTTOMLEFT" and p[1] == "TOPLEFT" then
		self.left, self.top = p[4], p[5]
	end
end
function methods.SetAllPoints(self, other) self.allPoints = other end
function methods.GetNumPoints(self) return #self.points end
function methods.GetPoint(self, i)
	local p = self.points[i]
	if p then
		return p[1], p[2], p[3], p[4], p[5]
	end
end
function methods.GetLeft(self) return self.left end
function methods.GetTop(self) return self.top end
function methods.SetScript(self, n, fn) self.scripts[n] = fn end
function methods.GetScript(self, n) return self.scripts[n] end
function methods.HookScript(self, n, fn)
	self.hooks[n] = self.hooks[n] or {}
	table.insert(self.hooks[n], fn)
end
function methods.SetText(self, s) self.text = s end
function methods.GetText(self) return self.text end
function methods.IsMouseOver(self) return self.mouseOver == true end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.GetAlpha(self) return self.alpha end
function methods.SetID(self, id) self.id = id end
function methods.GetID(self) return self.id end
function methods.SetVerticalScroll(self, v) self.vscroll = v end
function methods.GetVerticalScroll(self) return self.vscroll end
function methods.CreateFontString(self) return Fake.New("FontString", self) end
function methods.CreateTexture(self) return Fake.New("Texture", self) end

function Fake.New(kind, parent)
	local f = { kind = kind, parent = parent, shown = true, scale = 1, w = 0, h = 0, vscroll = 0, alpha = 1,
		points = {}, scripts = {}, hooks = {}, calls = {} }
	return setmetatable(f, {
		__index = function(_, name)
			return methods[name] or function(self, ...)
				self.calls[name] = { ... }
			end
		end,
	})
end

-- CreateFrame(kind, name, parent, template): like the client, a new frame starts shown.
function Fake.CreateFrame(kind, name, parent, template)
	local f = Fake.New(kind, parent)
	f.name, f.template = name, template
	Fake.created[#Fake.created + 1] = f
	if name then
		Fake.named[name] = f
	end
	return f
end

function Fake.Install()
	Fake.created, Fake.named = {}, {}
	CreateFrame = Fake.CreateFrame
	UIParent = Fake.New("Frame")
	UIParent.shown, UIParent.h = true, 1000
	UISpecialFrames = {}
	GameTooltip = Fake.New("GameTooltip")
	return Fake
end

function Fake.Uninstall()
	UIParent, UISpecialFrames, GameTooltip = nil, nil, nil
end

return Fake
```

<!-- sbw3:edit T1 s02 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
		m.sorts = m.sorts + 1
		return true
	end

```

and replace it with:

```lua
		m.sorts = m.sorts + 1
		return true
	end

	-- Blizzard frames by global name, and Blizzard's selected bank type (week 3).
	m.frames = {}
	m.activeBankType = nil
	function m.Frame(name)
		return m.frames[name]
	end

	function m.ActiveBankType()
		return m.activeBankType
	end

```

<!-- sbw3:file T1 s03 spec/bankwindow_spec.lua -->
Create `spec/bankwindow_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The bank window's frame handling (check V2): tiny mode, beside, the read-only deposit
-- target, Esc, Safe Mode. The bank contents are covered by spec/bankwindow_groups_spec.lua.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")

local FILES = { "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
	"SwagBag/Core/Config.lua", "SwagBag/Core/Slash.lua" }

-- Blizzard's bank as Blizzard shows it: parented to UIParent, two real tabs underneath.
local function blizzardBank()
	local bf = Fake.New("Frame", UIParent)
	bf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	bf.TabSystem = Fake.New("Frame", bf)
	bf.TabSystem:SetPoint("TOPLEFT", bf, "BOTTOMLEFT", 22, 2)
	bf.TabSystem.tabs = { Fake.New("Button", bf.TabSystem), Fake.New("Button", bf.TabSystem) }
	return bf
end

describe("BankWindow frames (check V2)", function()
	local SB, A, BW, bf
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		bf = blizzardBank()
		A.frames.BankFrame = bf
		A.activeBankType = "bank"
		SB.BagsWindow = { frame = Fake.New("Frame", UIParent), sortButton = Fake.New("Button") }
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BankWindow.lua")
		BW = SB.BankWindow
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function openBank()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	local function closeBank()
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
	end

	it("opens at the banker; Blizzard's bank stays shown inside the 0.001 parent, its tabs under our window", function()
		openBank()
		assert.truthy(BW.IsOpen())
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		assert.equal(true, bf.shown, "still shown: the bank visit stays open")
		assert.equal(BW.frame, bf.TabSystem.parent)
		assert.same({ "TOPLEFT", BW.frame, "BOTTOMLEFT", 12, 2 }, bf.TabSystem.points[1])
	end)

	it("never writes Blizzard's bank state: no call on BankFrame or its tabs besides moving them", function()
		openBank()
		Fake.Fire(bf.TabSystem.tabs[2], "OnClick")
		A.Advance(0)
		BW.frame:Hide()
		closeBank()
		assert.same({}, bf.calls)
		assert.same({}, bf.TabSystem.calls)
		assert.is_nil(rawget(bf, "bankType"))
		assert.equal(true, bf.shown)
	end)

	it("shows where deposits go, read from Blizzard's selected tab on the frame after a tab click", function()
		A.activeBankType = "warband"
		local seen = {}
		SB.On("SB_BANK_TARGET", function(_, target) seen[#seen + 1] = target end)
		openBank()
		assert.equal("Deposits go to Warband bank - switch with the tabs below", BW.frame.deposit.text)
		A.activeBankType = "bank"
		Fake.Fire(bf.TabSystem.tabs[1], "OnClick")
		assert.equal("Deposits go to Warband bank - switch with the tabs below", BW.frame.deposit.text,
			"Blizzard's click handler has not run yet")
		A.Advance(0)
		assert.equal("Deposits go to Character bank - switch with the tabs below", BW.frame.deposit.text)
		assert.same({ "warband", "bank" }, seen)
	end)

	it("hooks each Blizzard tab once, however many visits", function()
		openBank()
		closeBank()
		openBank()
		assert.equal(1, #bf.TabSystem.tabs[1].hooks.OnClick)
	end)

	it("closing the bank puts Blizzard's bank and its tabs back exactly where they were", function()
		openBank()
		closeBank()
		assert.falsy(BW.IsOpen())
		assert.equal(UIParent, bf.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }, bf.points)
		assert.equal(bf, bf.TabSystem.parent)
		assert.same({ { "TOPLEFT", bf, "BOTTOMLEFT", 22, 2 } }, bf.TabSystem.points)
	end)

	it("a bank closed in combat is put back as soon as combat ends", function()
		openBank()
		A.combat = true
		closeBank()
		assert.equal(SB.TinyHost.Parent(), bf.parent, "parents never change in combat")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(UIParent, bf.parent)
	end)

	it("a visit that starts in combat leaves Blizzard's bank visible and puts ours beside it", function()
		A.combat = true
		openBank()
		assert.truthy(BW.IsOpen())
		assert.equal(UIParent, bf.parent)
		assert.equal("beside", BW.VisitMode())
		assert.same({ "TOPLEFT", bf, "TOPRIGHT", 8, 0 }, BW.frame.points[#BW.frame.points])
		assert.equal(SB.L.BANK_COMBAT_BESIDE, BW.frame.title.text)
	end)

	it("the beside setting leaves Blizzard's bank alone and puts ours to its right (spec 5.4)", function()
		SB.Config.Set("bank.blizzardFrame", "beside")
		openBank()
		assert.equal(UIParent, bf.parent)
		assert.equal(bf, bf.TabSystem.parent)
		assert.same({ "TOPLEFT", bf, "TOPRIGHT", 8, 0 }, BW.frame.points[#BW.frame.points])
		assert.equal("Deposits go to Character bank - switch with the tabs below", BW.frame.deposit.text)
	end)

	it("the Blizzard bank button shows Blizzard's bank for this visit only, and hides it again", function()
		openBank()
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.equal(UIParent, bf.parent)
		assert.equal(SB.L.BANK_SHOWING_BLIZZARD, BW.frame.title.text)
		assert.equal("tiny", SB.Config.Get("bank.blizzardFrame"), "the setting is unchanged")
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		Fake.Fire(BW.blizzardButton, "OnClick")
		closeBank()
		openBank()
		assert.equal("tiny", BW.VisitMode(), "the next visit uses the setting again")
		assert.equal(SB.TinyHost.Parent(), bf.parent)
	end)

	it("the Blizzard bank button does nothing in combat and says so", function()
		openBank()
		A.combat = true
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		assert.equal(SB.L.BANK_NOT_IN_COMBAT, BW.frame.title.text)
	end)

	it("/swagbag bank beside saves the setting and applies it to the open bank; other text prints the usage", function()
		openBank()
		SB.Slash.Dispatch("bank beside")
		assert.equal("beside", SB.Config.Get("bank.blizzardFrame"))
		assert.equal(UIParent, bf.parent)
		SB.Slash.Dispatch("bank tiny")
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		SB.Slash.Dispatch("bank")
		assert.same({ SB.L.BANK_MODE_BESIDE, SB.L.BANK_MODE_TINY,
			"Use /swagbag bank tiny or /swagbag bank beside (now: tiny)." }, A.Lines())
	end)

	it("Esc hides only SwagBag's window; the bags window offers 'Bank still open', which reopens it", function()
		openBank()
		assert.equal("SwagBagBankWindow", UISpecialFrames[1])
		assert.falsy(BW.stillOpenButton.shown)
		BW.frame:Hide() -- what Esc and the X button do
		assert.equal(SB.TinyHost.Parent(), bf.parent, "the bank visit is untouched")
		assert.truthy(BW.stillOpenButton.shown)
		assert.equal(SB.BagsWindow.frame, BW.stillOpenButton.parent)
		Fake.Fire(BW.stillOpenButton, "OnClick")
		assert.truthy(BW.IsOpen())
		assert.falsy(BW.stillOpenButton.shown)
		BW.frame:Hide()
		closeBank()
		assert.falsy(BW.stillOpenButton.shown, "the visit is over")
	end)

	it("OnHide while the window is still shown (Alt+Z hiding UIParent) does nothing", function()
		openBank()
		local closed = 0
		SB.On("SB_BANK_CLOSED", function() closed = closed + 1 end)
		Fake.Fire(BW.frame, "OnHide")
		assert.equal(0, closed)
		assert.falsy(BW.stillOpenButton.shown)
		BW.Close()
		assert.equal(1, closed)
	end)

	it("Safe Mode for the bank: nothing moves and the window stays closed; off mid-visit takes over, on hands back", function()
		SB.SafeMode.Enable("bank", "manual")
		openBank()
		assert.falsy(BW.IsOpen())
		assert.equal(UIParent, bf.parent)
		assert.falsy(BW.stillOpenButton.shown)
		SB.SafeMode.Disable("bank")
		assert.truthy(BW.IsOpen())
		assert.equal(SB.TinyHost.Parent(), bf.parent)
		SB.SafeMode.Enable("bank", "auto")
		assert.falsy(BW.IsOpen())
		assert.equal(UIParent, bf.parent)
	end)

	it("logging out during a visit puts Blizzard's bank back (spec 8.6)", function()
		openBank()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		assert.equal(UIParent, bf.parent)
	end)

	it("an error in a tab-click hook switches only the bank to Safe Mode", function()
		openBank()
		A.ActiveBankType = function() error("boom") end
		Fake.Fire(bf.TabSystem.tabs[1], "OnClick")
		A.Advance(0)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal(UIParent, bf.parent, "Safe Mode handed the bank back")
	end)
end)

describe("BankWindow load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(FILES)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		SB.BagsWindow = { frame = Fake.New("Frame", UIParent), sortButton = Fake.New("Button") }
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/BankWindow.lua")
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
```

<!-- sbw3:edit T1 s04 spec/report_spec.lua -->
In `spec/report_spec.lua`, find:

```lua
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
```

and replace it with:

```lua
	end)

	it("shows the bank setting, the last visit and the deposit target (check V2)", function()
		SB.Checks.last = {}
		SB.BankWindow = { Mode = function() return "tiny" end, lastVisit = "beside", target = "warband",
			GroupName = function() return "Warband bank" end }
		assert.truthy(SB.Report.Build():find("\nBank: setting tiny, last visit beside, last deposit target Warband bank",
			1, true))
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
```

<!-- sbw3:file T1 s05 spec/tinyhost_spec.lua -->
Create `spec/tinyhost_spec.lua`:

```lua
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
		assert.truthy(host.Shrink(panel))
		local tiny = SB.TinyHost.Parent()
		assert.equal(tiny, panel.parent)
		assert.equal(0.001, tiny.scale)
		assert.equal(true, panel.shown)
		assert.same({}, panel.calls, "nothing but the parent changed")
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

	it("a second Shrink or Rehost never saves SwagBag's own parent as the original", function()
		host.Shrink(panel)
		host.Shrink(panel)
		host.Rehost(tabs, window, function() end)
		host.Rehost(tabs, window, function() end)
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
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/bankwindow_spec.lua spec/report_spec.lua spec/tinyhost_spec.lua`
Expected: `6 passed, 24 failed`. `UI/TinyHost.lua` and `UI/BankWindow.lua` do not exist yet, so every new test fails to load. The report test fails because there is no bank line.

Critical tests and the mutation that must make each fail:
- `bankwindow_spec` "opens at the banker; Blizzard's bank stays shown inside the 0.001 parent…": add `bf:Hide()` before `if host.Shrink(bf) then` in `BW.ApplyMode`.
- `bankwindow_spec` "never writes Blizzard's bank state…": the same mutation, or a call the fake frame does not model, for example `bf:UpdateTabs()` before `if host.Shrink(bf) then` (such calls are recorded in `bf.calls`; `Show`, `SetAlpha` and the other modelled methods are not).
- `tinyhost_spec` "Restore puts every parent and every anchor point back exactly" and `bankwindow_spec` "closing the bank puts Blizzard's bank and its tabs back exactly…": delete `restorePoints(e.frame, e.points)` in `host.Restore`.
- `bankwindow_spec` "shows where deposits go, read from Blizzard's selected tab on the frame after a tab click": replace the `SB.Adapter.After(0, …)` in the tab hook with a direct `BW.RefreshTarget()`.
- `bankwindow_spec` "a visit that starts in combat leaves Blizzard's bank visible…": drop the `SB.Adapter.InCombat()` test from `host.Shrink`.
- `bankwindow_spec` "Esc hides only SwagBag's window; … 'Bank still open'…": make `RefreshStillOpen` always hide the button.
- `bankwindow_spec` "OnHide while the window is still shown…": delete the `IsShown` guard.
- `bankwindow_spec` "Safe Mode for the bank…": drop `host.Restore()` from the `SB_SAFEMODE_CHANGED` handler.
- `bankwindow_spec` "logging out during a visit…": delete the `PLAYER_LOGOUT` handler.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T1 i01 SwagBag/Core/Init.lua -->
In `SwagBag/Core/Init.lua`, find:

```lua

SB.name = ADDON
SB.VERSION = "0.2.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "

```

and replace it with:

```lua

SB.name = ADDON
SB.VERSION = "0.3.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "

```

<!-- sbw3:edit T1 i02 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
## Notes: Bags that set themselves up, show what matters, and never break.
## Author: lonezebra
## Version: 0.2.0
## SavedVariables: SwagBagDB
## SavedVariablesPerCharacter: SwagBagCharDB
```

and replace it with:

```text
## Notes: Bags that set themselves up, show what matters, and never break.
## Author: lonezebra
## Version: 0.3.0
## SavedVariables: SwagBagDB
## SavedVariablesPerCharacter: SwagBagCharDB
```

<!-- sbw3:edit T1 i03 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
UI/SafeModeHooks.lua
UI/SearchBox.lua
UI/DebugV1.lua

```

and replace it with:

```text
UI/SafeModeHooks.lua
UI/SearchBox.lua
UI/TinyHost.lua
UI/BankWindow.lua
UI/DebugV1.lua

```

<!-- sbw3:edit T1 i04 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
```

and replace it with:

```lua

---------------------------------------------------------------------------
-- Blizzard frames and the bank (week 3). SwagBag only READS Blizzard's bank state
-- (spec 5.2, 5.3): it never selects a tab or a bank type and never closes the bank.
---------------------------------------------------------------------------
-- A Blizzard frame by its global name (BankFrame, GuildBankFrame, ...), or nil.
function A.Frame(name)
	return _G[name]
end

-- "bank" (character bank) | "warband" | nil: the bank type Blizzard's bank frame has
-- selected, which is where a right-clicked bag item goes. Read only.
function A.ActiveBankType()
	local f = _G.BankFrame
	if not (f and f.GetActiveBankType) then
		return nil
	end
	local ok, bankType = pcall(f.GetActiveBankType, f)
	local BT = Enum and Enum.BankType
	if not ok or bankType == nil or isSecret(bankType) or not BT then
		return nil
	end
	if bankType == BT.Character then
		return "bank"
	elseif bankType == BT.Account then
		return "warband"
	end
	return nil
end

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
```

<!-- sbw3:edit T1 i05 SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
		bags = { columns = 12, scale = 1.0, view = "sections", newRows = 2, reagentSeparate = false },
		safeMode = { bags = false, bank = false },
	},
}
```

and replace it with:

```lua
		bags = { columns = 12, scale = 1.0, view = "sections", newRows = 2, reagentSeparate = false },
		safeMode = { bags = false, bank = false },
		-- blizzardFrame: "tiny" (Blizzard's bank invisible, its tabs on SwagBag's window) |
		-- "beside" (Blizzard's bank visible, SwagBag's window next to it; spec 5.4, check V2).
		bank = { blizzardFrame = "tiny" },
	},
}
```

<!-- sbw3:edit T1 i06 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.QUERY_WARN_UNKNOWN_KEYWORD = "Unknown keyword \"#%s\" matches nothing (character %d)"

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

and replace it with:

```lua
L.QUERY_WARN_UNKNOWN_KEYWORD = "Unknown keyword \"#%s\" matches nothing (character %d)"

-- Bank window (spec F2, section 5)
L.BANK_TITLE = "SwagBag bank"
L.BANK_GROUP_BANK = "Character bank"
L.BANK_GROUP_WARBAND = "Warband bank"
L.BANK_DEPOSITS_TO = "Deposits go to %s - switch with the tabs below"
L.BTN_BLIZZARD_BANK = "Blizzard bank"
L.BANK_SHOWING_BLIZZARD = "Blizzard's bank is shown for this visit"
L.BANK_HIDING_BLIZZARD = "Blizzard's bank is hidden again"
L.BANK_COMBAT_BESIDE = "In combat: Blizzard's bank stays visible for this visit"
L.BANK_NOT_IN_COMBAT = "Leave combat first"
L.BANK_STILL_OPEN = "Bank still open"
L.HELP_BANK = "bank tiny|beside: hide Blizzard's bank (tiny) or show it beside SwagBag's"
L.BANK_USAGE = "Use /swagbag bank tiny or /swagbag bank beside (now: %s)."
L.BANK_MODE_TINY = "Bank: Blizzard's bank is hidden; its tabs are under SwagBag's bank window."
L.BANK_MODE_BESIDE = "Bank: Blizzard's bank is shown, with SwagBag's bank window beside it."
L.SETTINGS_READONLY = "SwagBag's saved settings are read-only, so nothing was changed."
L.REPORT_BANK = "Bank: setting %s, last visit %s, last deposit target %s"

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

<!-- sbw3:file T1 i07 SwagBag/UI/TinyHost.lua -->
Create `SwagBag/UI/TinyHost.lua`:

```lua
-- SwagBag tiny mode (spec 5.2, F16). Blizzard's bank frame must stay SHOWN while SwagBag
-- shows the bank: hiding it ends the bank visit, and its "active bank type" (where a
-- right-clicked bag item goes) only exists while it is shown. So SwagBag parents it to a
-- 1x1 frame at scale 0.001: still shown, but invisible. Blizzard's own tab buttons are
-- moved onto SwagBag's window, so a tab click still runs Blizzard's own code.
-- SwagBag changes only parents and anchors, and Restore puts every frame back exactly as
-- it was (parent and every anchor point). Parents change out of combat only: Shrink and
-- Rehost refuse in combat; Restore waits for combat to end (spec 13.2 item 5).
--   local host = SB.TinyHost.New(label, window)
--   host.Shrink(frame) -> true | false     keep frame shown but invisible
--   host.Rehost(frame, onto, place) -> true | false   move frame onto `onto`, place(frame) anchors it
--   host.Restore() -> true (done now) | false (waits for combat to end)
--   host.IsActive() -> true while anything is moved
local _, SB = ...

local TinyHost = {}
SB.TinyHost = TinyHost

local tinyParent

-- The shared invisible parent (a plain frame, created on first use).
function TinyHost.Parent()
	if not tinyParent then
		tinyParent = CreateFrame("Frame", nil, UIParent)
		tinyParent:SetSize(1, 1)
		tinyParent:SetScale(0.001)
		tinyParent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	end
	return tinyParent
end

local function savePoints(f)
	local points = {}
	for i = 1, f:GetNumPoints() or 0 do
		local point, relativeTo, relativePoint, x, y = f:GetPoint(i)
		points[i] = { point, relativeTo, relativePoint, x, y }
	end
	return points
end

local function restorePoints(f, points)
	f:ClearAllPoints()
	for _, p in ipairs(points) do
		f:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
end

-- label names the restore job (one per host); window is the ErrorTrap window.
function TinyHost.New(label, window)
	local h = { entries = {}, byFrame = {} }

	-- Remember where a frame lives, once (a second move must not save SwagBag's own parent).
	local function remember(frame)
		if not h.byFrame[frame] then
			local e = { frame = frame, parent = frame:GetParent(), points = savePoints(frame) }
			h.entries[#h.entries + 1] = e
			h.byFrame[frame] = e
		end
	end

	function h.Shrink(frame)
		if not frame or SB.Adapter.InCombat() then
			return false
		end
		remember(frame)
		if frame:GetParent() ~= TinyHost.Parent() then
			frame:SetParent(TinyHost.Parent())
		end
		return true
	end

	function h.Rehost(frame, onto, place)
		if not frame or SB.Adapter.InCombat() then
			return false
		end
		remember(frame)
		frame:SetParent(onto)
		frame:ClearAllPoints()
		place(frame)
		return true
	end

	function h.IsActive()
		return #h.entries > 0
	end

	function h.Restore()
		return SB.OutOfCombat(function()
			for i = #h.entries, 1, -1 do
				local e = h.entries[i]
				e.frame:SetParent(e.parent)
				restorePoints(e.frame, e.points)
				h.entries[i] = nil
				h.byFrame[e.frame] = nil
			end
		end, "tinyHost.restore." .. label, window)
	end

	return h
end
```

<!-- sbw3:file T1 i08 SwagBag/UI/BankWindow.lua -->
Create `SwagBag/UI/BankWindow.lua`:

```lua
-- SwagBag bank window (spec F2, section 5). Opens on BANKFRAME_OPENED, closes on
-- BANKFRAME_CLOSED. Blizzard's bank frame stays open the whole time:
--   "tiny" (default)  Blizzard's bank is shown but invisible (UI/TinyHost.lua) and its real
--                     tab buttons (BankFrame.TabSystem) hang under SwagBag's window
--   "beside"          Blizzard's bank is left exactly as Blizzard shows it, and SwagBag's
--                     window sits to its right (spec 5.4; the fallback if check V2 fails)
-- The "Blizzard bank" button switches between the two for this visit only (tab purchase and
-- warband gold live in Blizzard's frame). The setting is bank.blizzardFrame
-- (/swagbag bank tiny|beside).
-- Read only (spec 5.2, 5.3): the deposit target is whatever bank type Blizzard has selected
-- (Adapter.ActiveBankType); SwagBag shows it and never sets it. Esc or the X hides SwagBag's
-- window and nothing else (spec 5.6); if the bank is still open, the bags window shows
-- "Bank still open", which only shows this window again.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local BW = {
	interaction = false, -- the bank visit is open (between BANKFRAME_OPENED and _CLOSED)
	visit = nil, -- "tiny" | "beside" for this visit (the Blizzard bank button), nil = setting
	target = nil, -- "bank" | "warband" | nil: Blizzard's selected bank type, last read
	lastVisit = nil, -- "tiny" | "beside": the mode of the last visit (for /swagbag report)
	HEADER = 58,
	FOOTER = 6,
}
SB.BankWindow = BW

local host = SB.TinyHost.New("bank", "bank")
BW.host = host

local frame = CreateFrame("Frame", "SwagBagBankWindow", UIParent, "BackdropTemplate")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(540, 120)
frame:Hide()
if frame.SetDontSavePosition then
	frame:SetDontSavePosition(true)
end
BW.frame = frame
table.insert(UISpecialFrames, "SwagBagBankWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.BANK_TITLE)

frame.deposit = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.deposit:SetPoint("TOPLEFT", 10, -24)
frame.deposit:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local function blizzardBank()
	return SB.Adapter.Frame("BankFrame")
end

---------------------------------------------------------------------------
-- Title feedback and position
---------------------------------------------------------------------------
local titleToken = 0
function BW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("bank.flash", function()
		if token == titleToken then
			frame.title:SetText(L.BANK_TITLE)
		end
	end, "bank"))
end

function BW.RestorePosition()
	local p = SB.Config.UI().positions.bank
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)
	end
end

frame:SetScript("OnDragStart", Guard("bank.dragStart", function()
	frame:StartMoving()
end, "bank"))
frame:SetScript("OnDragStop", Guard("bank.dragStop", function()
	frame:StopMovingOrSizing()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top and BW.VisitMode() == "tiny" then -- beside follows Blizzard's frame instead
		SB.Config.UI().positions.bank = { "TOPLEFT", "BOTTOMLEFT", left, top }
	end
end, "bank"))

---------------------------------------------------------------------------
-- Tiny / beside
---------------------------------------------------------------------------
function BW.Mode()
	return SB.Config.Get("bank.blizzardFrame") == "beside" and "beside" or "tiny"
end

function BW.VisitMode()
	return BW.visit or BW.Mode()
end

local function groupName(kind)
	return kind == "warband" and L.BANK_GROUP_WARBAND or L.BANK_GROUP_BANK
end
BW.GroupName = groupName

-- Read Blizzard's selected bank type (never written) and show where deposits go.
function BW.RefreshTarget()
	BW.target = SB.Adapter.ActiveBankType()
	frame.deposit:SetText(BW.target and L.BANK_DEPOSITS_TO:format(groupName(BW.target)) or "")
	SB.Emit("SB_BANK_TARGET", BW.target)
end

-- A click on one of Blizzard's tabs runs Blizzard's code first; SwagBag reads the result
-- on the next frame. Each tab is hooked once.
local hookedTabs = setmetatable({}, { __mode = "k" })
local function hookTabs(tabSystem)
	if not tabSystem or type(tabSystem.tabs) ~= "table" then
		return
	end
	for _, tab in ipairs(tabSystem.tabs) do
		if not hookedTabs[tab] and tab.HookScript then
			hookedTabs[tab] = true
			tab:HookScript("OnClick", Guard("bank.tabClick", function()
				SB.Adapter.After(0, Guard("bank.tabRead", BW.RefreshTarget, "bank"))
			end, "bank"))
		end
	end
end

local function placeTabs(tabSystem)
	tabSystem:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
end

local function anchorBeside(bf)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", bf, "TOPRIGHT", 8, 0)
end

-- Put Blizzard's bank and SwagBag's window in the visit's mode. In combat parents cannot
-- change, so a visit that starts in combat stays "beside".
function BW.ApplyMode()
	local bf = blizzardBank()
	if not bf then
		return
	end
	hookTabs(bf.TabSystem)
	if BW.VisitMode() == "tiny" then
		if host.Shrink(bf) then
			if bf.TabSystem then
				host.Rehost(bf.TabSystem, frame, placeTabs)
			end
			BW.RestorePosition()
		else
			BW.visit = "beside"
			anchorBeside(bf)
			BW.Flash(L.BANK_COMBAT_BESIDE)
		end
	else
		host.Restore()
		anchorBeside(bf)
	end
	BW.lastVisit = BW.VisitMode()
	BW.RefreshTarget()
end

-- The "Blizzard bank" button: show or hide Blizzard's bank for this visit.
function BW.ToggleVisit()
	if SB.Adapter.InCombat() then
		BW.Flash(L.BANK_NOT_IN_COMBAT)
		return false
	end
	BW.visit = BW.VisitMode() == "tiny" and "beside" or "tiny"
	BW.ApplyMode()
	BW.Flash(BW.visit == "beside" and L.BANK_SHOWING_BLIZZARD or L.BANK_HIDING_BLIZZARD)
	return true
end

local function titleButton(text, label, onClick, width)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width or 72, 18)
	b:SetText(text)
	b:SetScript("OnClick", Guard(label, onClick, "bank"))
	return b
end
BW.TitleButton = titleButton

BW.blizzardButton = titleButton(L.BTN_BLIZZARD_BANK, "bank.blizzardButton", function()
	BW.ToggleVisit()
end, 104)
BW.blizzardButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
function BW.IsOpen()
	return frame:IsShown()
end

-- "Bank still open" on the bags window (spec 5.6): shown while the visit is open but
-- SwagBag's bank window is hidden. Its click only shows SwagBag's bank window again.
local bags = SB.BagsWindow
BW.stillOpenButton = CreateFrame("Button", nil, bags.frame, "UIPanelButtonTemplate")
BW.stillOpenButton:SetSize(110, 18)
BW.stillOpenButton:SetText(L.BANK_STILL_OPEN)
BW.stillOpenButton:SetPoint("RIGHT", bags.sortButton, "LEFT", -4, 0)
BW.stillOpenButton:SetScript("OnClick", Guard("bank.stillOpen", function()
	BW.Open()
end, "bank"))
BW.stillOpenButton:Hide()

function BW.RefreshStillOpen()
	BW.stillOpenButton:SetShown(BW.interaction and not frame:IsShown() and not SB.SafeMode.IsOn("bank"))
end

function BW.Open()
	if SB.SafeMode.IsOn("bank") or not BW.interaction then
		return false
	end
	if frame:IsShown() then
		return true
	end
	frame:Show()
	BW.ApplyMode()
	SB.Emit("SB_BANK_OPENED")
	BW.RefreshStillOpen()
	return true
end

function BW.Close()
	frame:Hide()
end

-- Esc, the X button and BW.Close() hide only SwagBag's window. The OnHide guard comes first:
-- Alt+Z hides UIParent, which fires OnHide while the frame itself is still shown.
frame:SetScript("OnHide", Guard("bank.hide", function(self)
	if self:IsShown() then
		return
	end
	SB.Emit("SB_BANK_CLOSED")
	BW.RefreshStillOpen()
end, "bank"))

function BW.OnBankOpened()
	BW.interaction, BW.visit = true, nil
	BW.Open()
	BW.RefreshStillOpen()
end

function BW.OnBankClosed()
	BW.interaction, BW.visit = false, nil
	frame:Hide()
	host.Restore()
	BW.RefreshStillOpen()
end

SB.On("BANKFRAME_OPENED", function()
	BW.OnBankOpened()
end, "bank")

SB.On("BANKFRAME_CLOSED", function()
	BW.OnBankClosed()
end, "bank")

-- Disabling or reloading never leaves Blizzard's bank moved (spec 8.6).
SB.On("PLAYER_LOGOUT", function()
	host.Restore()
end, "bank")

-- Safe Mode for the bank: hand everything back to Blizzard; switching it off during a visit
-- takes over again.
SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window ~= "bank" then
		return
	end
	if on then
		frame:Hide()
		host.Restore()
	elseif BW.interaction then
		BW.Open()
	end
	BW.RefreshStillOpen()
end, "none")

SB.Slash.Register("bank", L.HELP_BANK, function(arg)
	arg = (arg or ""):lower()
	if arg ~= "tiny" and arg ~= "beside" then
		return L.BANK_USAGE:format(BW.Mode())
	end
	if not SB.Config.Set("bank.blizzardFrame", arg) then
		return L.SETTINGS_READONLY
	end
	BW.visit = nil
	if frame:IsShown() then
		BW.ApplyMode()
	end
	return arg == "tiny" and L.BANK_MODE_TINY or L.BANK_MODE_BESIDE
end, "bank")
```

<!-- sbw3:edit T1 i09 SwagBag/Core/Report.lua -->
In `SwagBag/Core/Report.lua`, find:

```lua
		lines[#lines + 1] = L.REPORT_LAYOUT:format(bags.lastLayoutMs, tostring(bags.lastLayoutReason))
	end
	return table.concat(lines, "\n")
end
```

and replace it with:

```lua
		lines[#lines + 1] = L.REPORT_LAYOUT:format(bags.lastLayoutMs, tostring(bags.lastLayoutReason))
	end
	local bank = SB.BankWindow
	if bank then
		lines[#lines + 1] = L.REPORT_BANK:format(bank.Mode(), tostring(bank.lastVisit or L.REPORT_NONE),
			bank.target and bank.GroupName(bank.target) or L.REPORT_NONE)
	end
	return table.concat(lines, "\n")
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bankwindow_spec.lua spec/report_spec.lua spec/tinyhost_spec.lua`
Expected: `30 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (34 files)`, `451 passed, 0 failed`, `ALL CHECKS PASSED`. If the forbidden-token step fails, a comment contains one of the tokens (for example "CloseBankFrame("). Reword the comment.

- [ ] **Step 6: Commit**

```bash
git add spec/helpers/fakeframe.lua \
  spec/mock_adapter.lua \
  spec/bankwindow_spec.lua \
  spec/report_spec.lua \
  spec/tinyhost_spec.lua \
  SwagBag/Core/Init.lua \
  SwagBag/SwagBag.toc \
  SwagBag/Core/Adapter.lua \
  SwagBag/Core/Config.lua \
  SwagBag/Locale/enUS.lua \
  SwagBag/UI/TinyHost.lua \
  SwagBag/UI/BankWindow.lua \
  SwagBag/Core/Report.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 1: tiny-mode bank host, bank window shell, read-only deposit target, beside fallback" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 7: In-game session V2 (the user does this on Oct 15; about 10 minutes)**

Give the user this checklist exactly. You need:
- a banker nearby;
- two cheap gray (junk) items in your bags that you do not mind moving;
- your Hearthstone in your bags;
- not to be in a group.

1. Quit the game completely and start it again (new files need a full restart, not `/reload`). Log in. Chat shows `SwagBag: v0.3.0 loaded. Type /swagbag help for commands.`
2. Talk to the banker. Blizzard's bank window does **not** appear. A small dark window titled `SwagBag bank` appears instead, with a `Blizzard bank` button at its top right. It is empty for now (the bank's items come later this week). Blizzard's own bank tabs hang under its bottom edge, and your SwagBag bags open too.
3. The second line of the SwagBag bank window says `Deposits go to Character bank - switch with the tabs below` (or `Deposits go to Warband bank - switch with the tabs below` if the warband tab was selected last time).
4. Click the warband tab under the SwagBag bank window. The line now says `Deposits go to Warband bank - switch with the tabs below`.
5. In your SwagBag bags, right-click one gray item. It leaves your bags (a faded copy stays where it was). Move the mouse off it.
6. Click `Blizzard bank`. The SwagBag bank window's title says `Blizzard's bank is shown for this visit` for a moment, and Blizzard's bank window appears, open on the warband bank. **The gray item is in the warband bank.**
7. Click `Blizzard bank` again. Blizzard's bank window disappears, the title says `Blizzard's bank is hidden again` for a moment, and the tabs are back under the SwagBag bank window.
8. Click the character bank tab. The line says `Deposits go to Character bank - switch with the tabs below`. Right-click the second gray item in your bags, then move the mouse off it.
9. Click `Blizzard bank`. **The second gray item is in the character bank.** Click `Blizzard bank` again.
10. Click the **X** of the SwagBag bank window. Only that window closes. Your bags window now shows a `Bank still open` button in its title row. Click it: the SwagBag bank window comes back.
11. Press **Esc** once. The SwagBag bank window closes. Press **B**: your bags window has **no** `Bank still open` button (the Esc ended the bank visit).
12. Walk a few steps away from the banker. Right-click your Hearthstone in the SwagBag bags. The cast bar appears, and there is **no** red message `Interface action failed because of an AddOn`. Move to cancel the cast if you want to stay.
13. Type `/swagbag bank beside`. Chat says `Bank: Blizzard's bank is shown, with SwagBag's bank window beside it.` Talk to the banker: Blizzard's bank appears as usual, and the SwagBag bank window sits to its right. Press **Esc**.
14. Type `/swagbag bank tiny`. Chat says `Bank: Blizzard's bank is hidden; its tabs are under SwagBag's bank window.`
15. Type `/swagbag report`, press Ctrl+C, and paste it into Claude Code. Claude checks:
    - the first line starts `SwagBag 0.3.0`;
    - `Blocked actions: none` and no new errors;
    - a line `Bank: setting tiny, last visit beside, last deposit target …`.

Pass: in steps 6 and 9 each item landed in the bank that the line named, step 12 cast with no red message, and the report is clean.

If it fails: tell Claude which step. Until it is fixed, type `/swagbag bank beside`: Blizzard's bank stays visible and deposits are Blizzard's own. If the failure is the deposit landing in the wrong bank or the Hearthstone being blocked, then on Oct 16 Claude makes "beside" the default (spec AC2.6). That is one line in `SwagBag/Core/Config.lua`, `bank = { blizzardFrame = "beside", … }`, plus the matching expectations in `spec/bankwindow_spec.lua`. Nothing else changes.

---

### Task 2: First-day check G1: guild bank in tiny mode, re-hosted tab buttons, withdraw and deposit through Blizzard's functions, the "view" fallback

Spec F16 and §11.3 G1: SwagBag's guild bank window replaces Blizzard's. Blizzard's guild bank frame stays shown, as with the bank. A right-click withdraws to the bags with `AutoStoreGuildBankItem`, a drag picks up or drops with `PickupGuildBankItem`, and a right-click on a bag item deposits into the tab Blizzard has selected (Blizzard's own container code). G1 checks all of that, plus tab switching and a Hearthstone afterwards, with no blocked actions. This task builds exactly what G1 needs:
- `UI/GuildButtons.lua` (SwagBag's own plain `ItemButton`s, one per tab slot, made out of combat);
- the `SwagBag guild bank` window in tiny mode, with Blizzard's tab buttons re-hosted on its right edge;
- every viewable tab as a header line ("Mats - 5 withdrawals left today") and a grid of its 98 slots;
- one-at-a-time `QueryGuildBankTab` with a session cache;
- the `Blizzard guild bank` button (gold, log, permissions; AC16.5);
- the fallback setting `guildBank.mode = "full" | "view"` (AC16.6) with `/swagbag guild full|view`, and `guildBank.withdrawAnyTab` (D5).

Blizzard's guild bank UI is load-on-demand. The window hooks `GuildBankFrame`'s `OnShow` once the frame exists (`ADDON_LOADED` "Blizzard_GuildBankUI", or at login if it is already loaded). It listens to `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` for the vault, and to the older `GUILDBANKFRAME_OPENED/CLOSED` when the client still has them (a registration that fails is silent). The guild bank shares the `bank` Safe Mode flag (D2). Task 10 replaces this task's simple grid with category sections.

**Files:**
- Create: `SwagBag/UI/GuildButtons.lua`, `SwagBag/UI/GuildBankWindow.lua`
- Modify: `SwagBag/Core/Adapter.lua` (guild bank functions, optional checks), `.luacheckrc`, `SwagBag/Core/Config.lua` (`guildBank`), `SwagBag/Locale/enUS.lua`, `SwagBag/Core/Report.lua` (guild line), `SwagBag/SwagBag.toc`
- Test: `spec/mock_adapter.lua`, `spec/guildbank_spec.lua` (new), `spec/report_spec.lua`

**Interfaces:**
- Consumes: Task 1's `SB.TinyHost.New/Parent`, `SB.Adapter.Frame`, `spec/helpers/fakeframe.lua`; `SB.GridLayout.ClampOffset` (on `main`).
- Produces:
  - `SB.Adapter.GUILD_SLOTS == 98`.
  - Adapter reads: `GuildTabs() -> { { tab, name, icon, viewable, canDeposit, withdrawals } }` (withdrawals: -1 = unlimited), `GuildSlot(tab, slot) -> { itemID, link, count, icon, quality, isLocked } | nil`, `GuildCurrentTab() -> tab | nil`, `GuildKey() -> "Guild-Realm" | nil`, `IsGuildBanker(interactionType) -> bool`, `GuildTabFrames() -> { frame }`.
  - Adapter actions: `GuildQuery(tab)`, `GuildWithdraw(tab, slot) -> ok`, `GuildPickup(tab, slot) -> ok`, `GuildTooltip(owner, tab, slot)`, `HideTooltip()`, `ModifiedClick(link) -> bool`.
  - `SB.GuildButtons.SetParent(frame)`, `.Ensure(tabs) -> bool` (false = waits for combat to end), `.Get(tab, slot) -> button` (`button.tab`, `button.slot`), `.Paint(button, info)`.
  - `SB.GuildBankWindow`:
    - fields: `frame`, `host`, `interaction`, `visit`, `target`, `lastVisit`, `tabs`, `order`, `cache[tab][slot]`, `blizzardButton`;
    - mode: `Mode() -> "full"|"view"`, `VisitMode()`, `ApplyMode()`, `ToggleVisit()`, `RefreshTarget()`;
    - window and tabs: `Open()`, `Close()`, `IsOpen()`, `Flash(text)`, `RestorePosition()`, `ReadTabs()`, `QueryAll()`, `QueryNext()`, `TabName(tab)`, `WithdrawText(tabInfo)`;
    - slot actions: `ClickSlot(tab, slot, mouseButton) -> "link"|"view"|"empty"|"limit"|"tab"|"withdraw"|"pickup"`, `DragSlot(tab, slot)`, `DropSlot(tab, slot)`.
  - Settings `guildBank.mode` and `guildBank.withdrawAnyTab`. Slash command `guild`. Report line `Guild bank: setting %s, last visit %s`.

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T2 s01 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
	function m.ActiveBankType()
		return m.activeBankType
	end

```

and replace it with:

```lua
	function m.ActiveBankType()
		return m.activeBankType
	end

	-- Guild bank: m.guild.tabs = { { tab, name, viewable, canDeposit, withdrawals } },
	-- m.guild.slots[tab][slot] = { itemID, count, link?, isLocked? }; calls are recorded.
	m.guild = { tabs = {}, slots = {}, current = 1, key = "Tidewatch-Argent Dawn", queried = {}, withdrawn = {},
		picked = {} }
	m.modified = false
	m.tooltip = nil
	m.guildTabFrames = {}
	function m.GuildTabs()
		local out = {}
		for i, t in ipairs(m.guild.tabs) do
			out[i] = { tab = t.tab, name = t.name, icon = t.icon, viewable = t.viewable ~= false,
				canDeposit = t.canDeposit ~= false, withdrawals = t.withdrawals or -1 }
		end
		return out
	end

	function m.GuildSlot(tab, slot)
		local s = m.guild.slots[tab] and m.guild.slots[tab][slot]
		if not s then
			return nil
		end
		local it = m.items[s.itemID] or {}
		return { itemID = s.itemID, link = s.link or ("item:" .. s.itemID), count = s.count or 1, icon = s.itemID,
			quality = it.quality, isLocked = s.isLocked == true }
	end

	function m.GuildQuery(tab)
		m.guild.queried[#m.guild.queried + 1] = tab
	end

	function m.GuildCurrentTab()
		return m.guild.current
	end

	function m.GuildWithdraw(tab, slot)
		m.guild.withdrawn[#m.guild.withdrawn + 1] = { tab, slot }
		return true
	end

	function m.GuildPickup(tab, slot)
		m.guild.picked[#m.guild.picked + 1] = { tab, slot }
		return true
	end

	function m.GuildKey()
		return m.guild.key
	end

	function m.GuildTooltip(owner, tab, slot)
		m.tooltip = { owner = owner, tab = tab, slot = slot }
	end

	function m.HideTooltip()
		m.tooltip = nil
	end

	function m.ModifiedClick()
		return m.modified
	end

	function m.IsGuildBanker(interactionType)
		return interactionType == "GuildBanker"
	end

	function m.GuildTabFrames()
		return m.guildTabFrames
	end

```

<!-- sbw3:file T2 s02 spec/guildbank_spec.lua -->
Create `spec/guildbank_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- luacheck: globals SetItemButtonTexture SetItemButtonCount SetItemButtonQuality SetItemButtonDesaturated
-- The guild bank window (check G1): tiny mode, re-hosted tabs, withdraw / pickup / drop
-- through Blizzard's own guild bank functions, the read-only selected tab, view mode.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = { "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
	"SwagBag/Core/Config.lua", "SwagBag/Core/Slash.lua", "SwagBag/Engine/GridLayout.lua" }

local function paintGlobals()
	SetItemButtonTexture = function(b, icon) b.icon = icon end
	SetItemButtonCount = function(b, n) b.count = n end
	SetItemButtonQuality = function(b, q) b.quality = q end
	SetItemButtonDesaturated = function(b, d) b.desaturated = d end
end

local function clearPaintGlobals()
	SetItemButtonTexture, SetItemButtonCount, SetItemButtonQuality, SetItemButtonDesaturated = nil, nil, nil, nil
end

-- Blizzard's guild bank as Blizzard shows it, with two tab buttons on its right edge.
local function blizzardGuildBank(A)
	local gf = Fake.New("Frame", UIParent)
	gf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	local tabs = {}
	for i = 1, 2 do
		local t = Fake.New("Frame", gf)
		t.Button = Fake.New("CheckButton", t)
		if i == 1 then
			t:SetPoint("TOPLEFT", gf, "TOPRIGHT", -1, -17)
		else
			t:SetPoint("TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -17)
		end
		tabs[i] = t
	end
	A.frames.GuildBankFrame = gf
	A.guildTabFrames = tabs
	return gf, tabs
end

describe("GuildBankWindow (check G1)", function()
	local SB, A, GW, gf, tabs
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		paintGlobals()
		gf, tabs = blizzardGuildBank(A)
		A.guild.tabs = {
			{ tab = 1, name = "Mats", withdrawals = 5 },
			{ tab = 2, name = "Gear", withdrawals = 0 },
			{ tab = 3, name = "Officers", viewable = false },
		}
		A.guild.slots = { [1] = { [1] = { itemID = Fixtures.HERB, count = 20 }, [2] = { itemID = Fixtures.ORE, count = 5 } },
			[2] = { [1] = { itemID = Fixtures.BOE_RING } } }
		A.guild.current = 1
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GuildButtons.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GuildBankWindow.lua")
		GW = SB.GuildBankWindow
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
		clearPaintGlobals()
	end)

	local function openVault()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
	end

	local function closeVault()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "GuildBanker")
	end

	-- The client answers each query with GUILDBANKBAGSLOTS_CHANGED.
	local function answerQueries()
		for _ = 1, 4 do
			SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
			A.Advance(0.06)
		end
	end

	local function button(tab, slot)
		return SB.GuildButtons.Get(tab, slot)
	end

	it("opens at the vault; Blizzard's guild bank stays shown in the 0.001 parent, its tabs on our right edge", function()
		openVault()
		assert.truthy(GW.IsOpen())
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.equal(true, gf.shown, "still shown: the visit stays open")
		assert.equal(GW.frame, tabs[1].parent)
		assert.same({ "TOPLEFT", GW.frame, "TOPRIGHT", 0, -16 }, tabs[1].points[1])
		assert.same({ "TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -6 }, tabs[2].points[1])
	end)

	it("never calls a method on Blizzard's guild bank frame or its tabs (it only moves them)", function()
		openVault()
		answerQueries()
		Fake.Fire(tabs[2].Button, "OnClick")
		A.Advance(0)
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		closeVault()
		assert.same({}, gf.calls)
		for i = 1, 2 do
			assert.same({}, tabs[i].calls)
			assert.same({}, tabs[i].Button.calls)
		end
	end)

	it("lists every viewable tab with its withdrawals left; a tab the player cannot view is left out", function()
		openVault()
		assert.same({ 1, 2 }, GW.order)
		assert.equal("Mats - 5 withdrawals left today (loading...)  - deposits go here", GW.labels[1].text)
		answerQueries()
		assert.equal("Mats - 5 withdrawals left today  - deposits go here", GW.labels[1].text)
		assert.equal("Gear - no withdrawals left today", GW.labels[2].text)
		assert.is_nil(GW.labels[3])
		assert.is_nil(button(3, 1), "no buttons for a tab that is not shown")
		A.guild.tabs[1].withdrawals = -1
		SB.eventFrame:Fire("GUILDBANK_UPDATE_TABS")
		assert.equal("Mats - unlimited withdrawals  - deposits go here", GW.labels[1].text)
	end)

	it("queries the selected tab first, then the others one at a time, and shows what arrived", function()
		A.guild.current = 2
		openVault()
		assert.same({ 2 }, A.guild.queried)
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		A.Advance(0.06)
		assert.same({ 2, 1 }, A.guild.queried)
		answerQueries()
		assert.same({ 2, 1 }, A.guild.queried, "tab 3 is not viewable and never queried")
		assert.equal(Fixtures.HERB, button(1, 1).icon)
		assert.equal(20, button(1, 1).count)
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon)
		assert.is_nil(rawget(button(1, 3), "icon"))
	end)

	it("a query that gets no answer moves on after QUERY_GAP", function()
		openVault()
		A.Advance(GW.QUERY_GAP + 0.01)
		assert.same({ 1, 2 }, A.guild.queried)
	end)

	it("a reopen shows the session's cached contents at once, then asks again", function()
		openVault()
		answerQueries()
		closeVault()
		A.guild.queried = {}
		openVault()
		assert.equal(Fixtures.HERB, button(1, 1).icon, "cached")
		assert.same({ 1 }, A.guild.queried)
	end)

	it("a right-click withdraws to the bags, from any tab by default", function()
		A.guild.tabs[2].withdrawals = 3
		openVault()
		answerQueries()
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({ { 1, 1 }, { 2, 1 } }, A.guild.withdrawn)
		assert.same({}, A.Lines())
	end)

	it("with withdrawAnyTab off, a right-click in a tab Blizzard has not selected says which tab to click", function()
		A.guild.tabs[2].withdrawals = 3
		SB.Config.Set("guildBank.withdrawAnyTab", false)
		openVault()
		answerQueries()
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ "Click the Gear tab on the right first, then right-click the item again." }, A.Lines())
	end)

	it("a tab with no withdrawals left refuses with a message and calls nothing (AC16.2)", function()
		openVault()
		answerQueries()
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ "No withdrawals left today from Gear." }, A.Lines())
	end)

	it("a right-click on an empty slot does nothing", function()
		openVault()
		answerQueries()
		assert.equal("empty", GW.ClickSlot(1, 50, "RightButton"))
		assert.same({}, A.guild.withdrawn)
	end)

	it("left-click and drag pick the stack up; a drop puts the cursor's item into that slot", function()
		openVault()
		answerQueries()
		Fake.Fire(button(1, 2), "OnClick", "LeftButton")
		Fake.Fire(button(1, 1), "OnDragStart")
		Fake.Fire(button(1, 9), "OnReceiveDrag")
		assert.same({ { 1, 2 }, { 1, 1 }, { 1, 9 } }, A.guild.picked)
	end)

	it("a modified click (shift: link to chat) is Blizzard's and does nothing else", function()
		openVault()
		answerQueries()
		A.modified = true
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({}, A.guild.picked)
	end)

	it("hovering shows Blizzard's guild bank tooltip for that slot", function()
		openVault()
		Fake.Fire(button(1, 2), "OnEnter")
		assert.same({ owner = button(1, 2), tab = 1, slot = 2 }, A.tooltip)
		Fake.Fire(button(1, 2), "OnLeave")
		assert.is_nil(A.tooltip)
	end)

	it("deposits go to the tab Blizzard has selected, read on the frame after a tab click", function()
		openVault()
		answerQueries()
		assert.equal("Deposits go to Mats - switch with the tabs on the right", GW.frame.deposit.text)
		A.guild.current = 2
		Fake.Fire(tabs[2].Button, "OnClick")
		A.Advance(0)
		assert.equal("Deposits go to Gear - switch with the tabs on the right", GW.frame.deposit.text)
		assert.equal("Gear - no withdrawals left today  - deposits go here", GW.labels[2].text)
		assert.equal("Mats - 5 withdrawals left today", GW.labels[1].text)
	end)

	it("view mode (the setting): Blizzard's guild bank stays as it is and ours is read-only beside it", function()
		SB.Config.Set("guildBank.mode", "view")
		openVault()
		answerQueries()
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
		assert.same({ "TOPLEFT", gf, "TOPRIGHT", 8, 0 }, GW.frame.points[#GW.frame.points])
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(1, 1), "OnDragStart")
		assert.same({}, A.guild.withdrawn)
		assert.same({}, A.guild.picked)
		assert.same({ SB.L.GUILD_VIEW_ONLY, SB.L.GUILD_VIEW_ONLY }, A.Lines())
	end)

	it("the Blizzard guild bank button shows Blizzard's frame for this visit and hides it again", function()
		openVault()
		Fake.Fire(GW.blizzardButton, "OnClick")
		assert.equal(UIParent, gf.parent)
		assert.equal("view", GW.VisitMode())
		assert.equal("full", SB.Config.Get("guildBank.mode"))
		Fake.Fire(GW.blizzardButton, "OnClick")
		assert.equal(SB.TinyHost.Parent(), gf.parent)
	end)

	it("closing the vault puts Blizzard's frame and its tabs back exactly", function()
		openVault()
		closeVault()
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }, gf.points)
		assert.equal(gf, tabs[2].parent)
		assert.same({ { "TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -17 } }, tabs[2].points)
	end)

	it("Esc hides only SwagBag's window; Blizzard's frame keeps the visit open", function()
		openVault()
		assert.equal("SwagBagGuildBankWindow", UISpecialFrames[1])
		GW.frame:Hide()
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.same({}, gf.calls)
	end)

	it("works when Blizzard's guild bank UI loads on demand during the visit", function()
		A.frames.GuildBankFrame = nil
		gf.shown = false
		SB.eventFrame:Fire("ADDON_LOADED", "Blizzard_GuildBankUI") -- not there yet: nothing to hook
		openVault()
		assert.truthy(GW.IsOpen())
		A.frames.GuildBankFrame = gf
		SB.eventFrame:Fire("ADDON_LOADED", "Blizzard_GuildBankUI")
		gf:Show()
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.equal(1, #gf.hooks.OnShow)
	end)

	it("a visit that starts in combat creates no buttons and leaves Blizzard's guild bank as it is", function()
		A.combat = true
		openVault()
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.is_nil(button(1, 1))
		assert.same({ SB.L.GUILD_COMBAT_WAIT }, A.Lines())
	end)

	it("Safe Mode for the bank also hands the guild bank to Blizzard", function()
		openVault()
		SB.SafeMode.Enable("bank", "manual")
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
	end)

	it("/swagbag guild view|full saves the setting and applies it now", function()
		openVault()
		SB.Slash.Dispatch("guild view")
		assert.equal("view", SB.Config.Get("guildBank.mode"))
		assert.equal(UIParent, gf.parent)
		SB.Slash.Dispatch("guild nonsense")
		assert.same({ SB.L.GUILD_MODE_VIEW, "Use /swagbag guild full or /swagbag guild view (now: view)." }, A.Lines())
	end)

	it("an error in a slot click switches only the bank to Safe Mode and hands the guild bank back", function()
		openVault()
		answerQueries()
		A.GuildWithdraw = function() error("boom") end
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal(UIParent, gf.parent)
	end)
end)

describe("GuildBankWindow load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(FILES)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GuildButtons.lua")
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/GuildBankWindow.lua")
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
```

<!-- sbw3:edit T2 s03 spec/report_spec.lua -->
In `spec/report_spec.lua`, find:

```lua
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
```

and replace it with:

```lua
	end)

	it("shows the guild bank setting and the last visit (check G1)", function()
		SB.Checks.last = {}
		SB.GuildBankWindow = { Mode = function() return "full" end, lastVisit = "view" }
		assert.truthy(SB.Report.Build():find("\nGuild bank: setting full, last visit view", 1, true))
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/guildbank_spec.lua spec/report_spec.lua`
Expected: `7 passed, 25 failed`. The guild bank files do not exist yet, and the report has no guild line.

Critical tests and the mutation that must make each fail:
- "never calls a method on Blizzard's guild bank frame or its tabs…": add `gf:UpdateTabs()` before `if host.Shrink(gf) then` in `GW.ApplyMode`. A method the fake frame does not model is recorded in `gf.calls`; `Show`, `SetAlpha` and the other modelled methods are not.
- "a tab with no withdrawals left refuses with a message and calls nothing (AC16.2)": change `if t and t.withdrawals == 0 then` to `if false then`.
- "view mode … ours is read-only beside it": delete the `GW.VisitMode() == "view"` block in `ClickSlot`.
- "a modified click (shift: link to chat) is Blizzard's…": delete the `A.ModifiedClick` check.
- "a visit that starts in combat creates no buttons…": ignore `GuildButtons.Ensure`'s result in `GW.Open`.
- "works when Blizzard's guild bank UI loads on demand during the visit": drop `frameHooked` from `GW.HookFrame` (the frame gets hooked twice).
- "queries the selected tab first…": set `first = nil` in `QueryAll`.
- "lists every viewable tab…": append every tab to `GW.order`, viewable or not.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T2 i01 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
UI/TinyHost.lua
UI/BankWindow.lua
UI/DebugV1.lua

```

and replace it with:

```text
UI/TinyHost.lua
UI/BankWindow.lua
UI/GuildButtons.lua
UI/GuildBankWindow.lua
UI/DebugV1.lua

```

<!-- sbw3:edit T2 i02 .luacheckrc -->
In `.luacheckrc`, find:

```lua
	"StaticPopup_Show", "YES", "NO",
	"GetCursorInfo", "ClearCursor", "GameTooltip",
}

```

and replace it with:

```lua
	"StaticPopup_Show", "YES", "NO",
	"GetCursorInfo", "ClearCursor", "GameTooltip",
	"GetNumGuildBankTabs", "GetGuildBankTabInfo", "GetGuildBankItemInfo", "GetGuildBankItemLink", "QueryGuildBankTab",
	"GetCurrentGuildBankTab", "AutoStoreGuildBankItem", "PickupGuildBankItem", "GetGuildInfo", "GetRealmName",
	"IsModifiedClick", "HandleModifiedItemClick",
}

```

<!-- sbw3:edit T2 i03 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
```

and replace it with:

```lua

---------------------------------------------------------------------------
-- Guild bank (week 3, spec F16). Blizzard's guild bank functions are plain globals; the
-- guild bank UI (GuildBankFrame) is load-on-demand, so nothing here may assume it exists.
-- SwagBag never selects a guild bank tab: Blizzard's own tab buttons do (spec AC16.7).
---------------------------------------------------------------------------
A.GUILD_SLOTS = 98 -- slots per guild bank tab

-- { { tab, name, icon, viewable, canDeposit, withdrawals } } for each tab the guild owns.
-- withdrawals: stacks the player may still take from that tab today; -1 = unlimited.
function A.GuildTabs()
	if not (GetNumGuildBankTabs and GetGuildBankTabInfo) then
		return {}
	end
	local okN, n = pcall(GetNumGuildBankTabs)
	if not okN or type(n) ~= "number" or isSecret(n) then
		return {}
	end
	local out = {}
	for tab = 1, n do
		local ok, name, icon, viewable, canDeposit, _, remaining = pcall(GetGuildBankTabInfo, tab)
		if ok and not isSecret(name) then
			out[#out + 1] = { tab = tab, name = name, icon = icon, viewable = viewable == true,
				canDeposit = canDeposit == true,
				withdrawals = (type(remaining) == "number" and not isSecret(remaining)) and remaining or 0 }
		end
	end
	return out
end

-- Normalized guild slot { itemID, link, count, icon, quality, isLocked }, or nil when empty
-- (or not loaded yet: QueryGuildBankTab loads a tab).
function A.GuildSlot(tab, slot)
	local ok, icon, count, locked, _, quality = pcall(GetGuildBankItemInfo, tab, slot)
	if not ok or icon == nil or isSecret(icon) then
		return nil
	end
	local okL, link = pcall(GetGuildBankItemLink, tab, slot)
	if not okL or type(link) ~= "string" or isSecret(link) then
		return nil
	end
	local inst = A.GetItemInstant(link)
	if not inst then
		return nil
	end
	return { itemID = inst.itemID, link = link, count = count or 1, icon = icon, quality = quality,
		isLocked = locked == true }
end

function A.GuildQuery(tab)
	if QueryGuildBankTab then
		pcall(QueryGuildBankTab, tab)
	end
end

-- The tab Blizzard's guild bank has selected (where a right-clicked bag item goes). Read only.
function A.GuildCurrentTab()
	if not GetCurrentGuildBankTab then
		return nil
	end
	local ok, tab = pcall(GetCurrentGuildBankTab)
	if ok and type(tab) == "number" and not isSecret(tab) then
		return tab
	end
	return nil
end

-- Withdraw a stack to the bags (what a right-click does in Blizzard's guild bank).
function A.GuildWithdraw(tab, slot)
	return pcall(AutoStoreGuildBankItem, tab, slot)
end

-- Pick up the stack, or put the cursor's item into that slot (deposit or move).
function A.GuildPickup(tab, slot)
	return pcall(PickupGuildBankItem, tab, slot)
end

-- "Guild Name-Realm" for the player's guild, or nil without a guild.
function A.GuildKey()
	if not GetGuildInfo then
		return nil
	end
	local ok, name, _, _, realm = pcall(GetGuildInfo, "player")
	if not ok or type(name) ~= "string" or isSecret(name) then
		return nil
	end
	return name .. "-" .. tostring(realm or (GetRealmName and GetRealmName()) or "")
end

function A.GuildTooltip(owner, tab, slot)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetGuildBankItem, GameTooltip, tab, slot)
	GameTooltip:Show()
end

function A.HideTooltip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

-- Shift/Ctrl-click on an item link (chat link, dressing room). True when Blizzard handled it.
function A.ModifiedClick(link)
	if not (IsModifiedClick and HandleModifiedItemClick) or not IsModifiedClick() then
		return false
	end
	local ok, handled = pcall(HandleModifiedItemClick, link)
	return ok and handled ~= false
end

-- True for the guild vault in PLAYER_INTERACTION_MANAGER_FRAME_SHOW / _HIDE.
function A.IsGuildBanker(interactionType)
	local PIT = Enum and Enum.PlayerInteractionType
	return PIT ~= nil and PIT.GuildBanker ~= nil and interactionType == PIT.GuildBanker
end

-- Blizzard's guild bank tab buttons (to re-host on SwagBag's window), top to bottom.
function A.GuildTabFrames()
	local gf = _G.GuildBankFrame
	local list = {}
	if not gf then
		return list
	end
	if type(gf.BankTabs) == "table" then
		for i, t in ipairs(gf.BankTabs) do
			list[i] = t
		end
	else
		for i = 1, 8 do
			local t = _G["GuildBankTab" .. i]
			if t then
				list[#list + 1] = t
			end
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
```

<!-- sbw3:edit T2 i04 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
	{ path = "C_ChallengeMode.IsChallengeModeActive", window = "bags", required = false },
	{ path = "C_RestrictedActions.IsAddOnRestrictionActive", window = "bags", required = false },
}
```

and replace it with:

```lua
	{ path = "C_ChallengeMode.IsChallengeModeActive", window = "bags", required = false },
	{ path = "C_RestrictedActions.IsAddOnRestrictionActive", window = "bags", required = false },
	{ path = "GetGuildBankItemInfo", window = "bank", required = false },
	{ path = "GetGuildBankItemLink", window = "bank", required = false },
	{ path = "GetGuildBankTabInfo", window = "bank", required = false },
	{ path = "QueryGuildBankTab", window = "bank", required = false },
	{ path = "AutoStoreGuildBankItem", window = "bank", required = false },
	{ path = "PickupGuildBankItem", window = "bank", required = false },
	{ path = "Enum.PlayerInteractionType.GuildBanker", window = "bank", required = false },
}
```

<!-- sbw3:edit T2 i05 SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
		-- "beside" (Blizzard's bank visible, SwagBag's window next to it; spec 5.4, check V2).
		bank = { blizzardFrame = "tiny" },
	},
}
```

and replace it with:

```lua
		-- "beside" (Blizzard's bank visible, SwagBag's window next to it; spec 5.4, check V2).
		bank = { blizzardFrame = "tiny" },
		-- mode: "full" (SwagBag's window replaces Blizzard's; spec F16) | "view" (read-only window
		-- with Blizzard's frame beside it; the fallback if check G1 fails). withdrawAnyTab: a
		-- right-click withdraws from any tab (false: only from the tab Blizzard has selected).
		guildBank = { mode = "full", withdrawAnyTab = true },
	},
}
```

<!-- sbw3:edit T2 i06 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_BANK = "Bank: setting %s, last visit %s, last deposit target %s"

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

and replace it with:

```lua
L.REPORT_BANK = "Bank: setting %s, last visit %s, last deposit target %s"

-- Guild bank window (spec F16)
L.GUILD_TITLE = "SwagBag guild bank"
L.GUILD_TAB_N = "Tab %d"
L.GUILD_DEPOSITS_TO = "Deposits go to %s - switch with the tabs on the right"
L.GUILD_TAB_HEADER = "%s - %s"
L.GUILD_WITHDRAW_LEFT = "%d withdrawals left today"
L.GUILD_WITHDRAW_UNLIMITED = "unlimited withdrawals"
L.GUILD_WITHDRAW_NONE = "no withdrawals left today"
L.GUILD_TAB_LOADING = " (loading...)"
L.GUILD_DEPOSITS_HERE = "  - deposits go here"
L.BTN_BLIZZARD_GUILD = "Blizzard guild bank"
L.GUILD_SHOWING_BLIZZARD = "Blizzard's guild bank is shown for this visit (gold, log, permissions)"
L.GUILD_HIDING_BLIZZARD = "Blizzard's guild bank is hidden again"
L.GUILD_COMBAT_VIEW = "In combat: Blizzard's guild bank stays visible for this visit"
L.GUILD_COMBAT_WAIT = "In combat: SwagBag's guild bank window opens on your next visit."
L.GUILD_VIEW_ONLY = "SwagBag's guild bank is view-only now: move items in Blizzard's guild bank window."
L.GUILD_NO_WITHDRAWALS = "No withdrawals left today from %s."
L.GUILD_SELECT_TAB_FIRST = "Click the %s tab on the right first, then right-click the item again."
L.HELP_GUILD = "guild full|view: SwagBag's guild bank replaces Blizzard's (full) or only shows it (view)"
L.GUILD_USAGE = "Use /swagbag guild full or /swagbag guild view (now: %s)."
L.GUILD_MODE_FULL = "Guild bank: SwagBag's window replaces Blizzard's; its tabs are on the right of SwagBag's window."
L.GUILD_MODE_VIEW = "Guild bank: Blizzard's window is shown; SwagBag's window beside it is view-only."
L.REPORT_GUILD = "Guild bank: setting %s, last visit %s"

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

<!-- sbw3:file T2 i07 SwagBag/UI/GuildBankWindow.lua -->
Create `SwagBag/UI/GuildBankWindow.lua`:

```lua
-- SwagBag guild bank window (spec F16). Opens when the guild vault opens. Blizzard's guild
-- bank frame stays open the whole time (hiding it would end the visit):
--   "full" (default)  Blizzard's frame is shown but invisible (UI/TinyHost.lua); its real tab
--                     buttons sit on the right edge of SwagBag's window. A right-click
--                     withdraws to the bags, a drag picks up or drops, a right-click on a bag
--                     item deposits into the tab Blizzard has selected (Blizzard's own code).
--   "view"            Blizzard's frame is left as Blizzard shows it and SwagBag's window is
--                     read-only beside it (the fallback if check G1 fails; spec AC16.6).
-- The "Blizzard guild bank" button switches to "view" for this visit (gold, log,
-- permissions, tab purchase stay in Blizzard's frame; spec AC16.5). Setting:
-- guildBank.mode (/swagbag guild full|view). SwagBag never selects a tab and never writes
-- Blizzard's guild bank frame state (spec AC16.7): it reads the selected tab only.
-- Every viewable tab is listed top to bottom with its daily withdrawals left (AC16.2).
-- Tab contents load on demand (QueryGuildBankTab, one tab after another) and are kept for
-- the session, so a reopen shows them at once (AC16.4).
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local GW = {
	interaction = false, -- the vault is open
	visit = nil, -- "full" | "view" for this visit (the Blizzard guild bank button), nil = setting
	target = nil, -- the tab Blizzard has selected, last read
	lastVisit = nil,
	tabs = {}, -- [tab] = Adapter.GuildTabs entry (only tabs the guild owns)
	order = {}, -- viewable tab numbers, ascending
	cache = {}, -- [tab][slot] = Adapter.GuildSlot result, kept for the session
	loaded = {}, -- [tab] = true once its contents arrived this session
	queue = {}, -- tabs still to query this visit
	asked = {}, -- [tab] = true once queried this visit
	querying = nil,
	QUERY_GAP = 0.3, -- seconds between two tab queries (and the wait if no answer comes)
	SLOT = 37,
	GAP = 4,
	PAD = 4,
	COLUMNS = 14,
	TAB_HEADER = 20,
	TAB_GAP = 8,
	HEADER = 58,
	FOOTER = 6,
	MAX_HEIGHT_FRACTION = 0.75,
}
SB.GuildBankWindow = GW

local host = SB.TinyHost.New("guild", "bank")
GW.host = host

local frame = CreateFrame("Frame", "SwagBagGuildBankWindow", UIParent, "BackdropTemplate")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(600, 200)
frame:Hide()
if frame.SetDontSavePosition then
	frame:SetDontSavePosition(true)
end
GW.frame = frame
table.insert(UISpecialFrames, "SwagBagGuildBankWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.GUILD_TITLE)

frame.deposit = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.deposit:SetPoint("TOPLEFT", 10, -24)
frame.deposit:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -GW.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, GW.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
GW.scroll, GW.child = scroll, child
SB.GuildButtons.SetParent(child)

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("guild.wheel", function(_, delta)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (GW.SLOT + GW.GAP) * 3)
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end, "bank"))

local function blizzardGuildBank()
	return SB.Adapter.Frame("GuildBankFrame")
end

---------------------------------------------------------------------------
-- Title feedback and position
---------------------------------------------------------------------------
local titleToken = 0
function GW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("guild.flash", function()
		if token == titleToken then
			frame.title:SetText(L.GUILD_TITLE)
		end
	end, "bank"))
end

function GW.RestorePosition()
	local p = SB.Config.UI().positions.guild
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)
	end
end

frame:SetScript("OnDragStart", Guard("guild.dragStart", function()
	frame:StartMoving()
end, "bank"))
frame:SetScript("OnDragStop", Guard("guild.dragStop", function()
	frame:StopMovingOrSizing()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top and GW.VisitMode() == "full" then
		SB.Config.UI().positions.guild = { "TOPLEFT", "BOTTOMLEFT", left, top }
	end
end, "bank"))

---------------------------------------------------------------------------
-- Full / view
---------------------------------------------------------------------------
function GW.Mode()
	return SB.Config.Get("guildBank.mode") == "view" and "view" or "full"
end

function GW.VisitMode()
	return GW.visit or GW.Mode()
end

local function tabName(tab)
	local t = GW.tabs[tab]
	return (t and t.name and t.name ~= "") and t.name or L.GUILD_TAB_N:format(tab)
end
GW.TabName = tabName

-- Read the tab Blizzard has selected (never written) and show where deposits go.
function GW.RefreshTarget()
	local old = GW.target
	GW.target = SB.Adapter.GuildCurrentTab()
	frame.deposit:SetText(GW.target and L.GUILD_DEPOSITS_TO:format(tabName(GW.target)) or "")
	if old ~= GW.target and frame:IsShown() then
		GW.Render()
	end
end

-- Blizzard's tab buttons run Blizzard's code; SwagBag reads the result on the next frame.
local hookedTabs = setmetatable({}, { __mode = "k" })
local function hookTabs(tabFrames)
	for _, t in ipairs(tabFrames) do
		local b = t.Button or t
		if not hookedTabs[b] and b.HookScript then
			hookedTabs[b] = true
			b:HookScript("OnClick", Guard("guild.tabClick", function()
				SB.Adapter.After(0, Guard("guild.tabRead", GW.RefreshTarget, "bank"))
			end, "bank"))
		end
	end
end

local function rehostTabs(tabFrames)
	for i, t in ipairs(tabFrames) do
		host.Rehost(t, frame, function(f)
			if i == 1 then
				f:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -16)
			else
				f:SetPoint("TOPLEFT", tabFrames[i - 1], "BOTTOMLEFT", 0, -6)
			end
		end)
	end
end

local function anchorBeside(gf)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", gf, "TOPRIGHT", 8, 0)
end

-- Put Blizzard's guild bank and SwagBag's window in the visit's mode. Blizzard's frame is
-- load-on-demand: until it exists (or while it is hidden) there is nothing to move yet, and
-- its OnShow hook calls this again. In combat parents cannot change: the visit stays "view".
function GW.ApplyMode()
	local gf = blizzardGuildBank()
	if not (gf and gf:IsShown()) then
		return
	end
	local tabFrames = SB.Adapter.GuildTabFrames()
	hookTabs(tabFrames)
	if GW.VisitMode() == "full" then
		if host.Shrink(gf) then
			rehostTabs(tabFrames)
			GW.RestorePosition()
		else
			GW.visit = "view"
			anchorBeside(gf)
			GW.Flash(L.GUILD_COMBAT_VIEW)
		end
	else
		host.Restore()
		anchorBeside(gf)
	end
	GW.lastVisit = GW.VisitMode()
	GW.RefreshTarget()
end

function GW.ToggleVisit()
	if SB.Adapter.InCombat() then
		GW.Flash(L.BANK_NOT_IN_COMBAT)
		return false
	end
	GW.visit = GW.VisitMode() == "full" and "view" or "full"
	GW.ApplyMode()
	GW.Flash(GW.visit == "view" and L.GUILD_SHOWING_BLIZZARD or L.GUILD_HIDING_BLIZZARD)
	return true
end

GW.blizzardButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
GW.blizzardButton:SetSize(140, 18)
GW.blizzardButton:SetText(L.BTN_BLIZZARD_GUILD)
GW.blizzardButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)
GW.blizzardButton:SetScript("OnClick", Guard("guild.blizzardButton", function()
	GW.ToggleVisit()
end, "bank"))

---------------------------------------------------------------------------
-- Tabs, queries and the session cache
---------------------------------------------------------------------------
function GW.ReadTabs()
	GW.tabs, GW.order = {}, {}
	for _, t in ipairs(SB.Adapter.GuildTabs()) do
		GW.tabs[t.tab] = t
		if t.viewable then
			GW.order[#GW.order + 1] = t.tab
		end
	end
	table.sort(GW.order)
end

-- Re-read every slot of a loaded tab into the cache.
function GW.ReadTab(tab)
	local A, list = SB.Adapter, {}
	for slot = 1, A.GUILD_SLOTS do
		list[slot] = A.GuildSlot(tab, slot)
	end
	GW.cache[tab] = list
end

-- Query the selected tab first, then the others, one at a time: the next query goes out when
-- the previous answer arrives (GUILDBANKBAGSLOTS_CHANGED) or QUERY_GAP later.
function GW.QueryNext()
	local tab = table.remove(GW.queue, 1)
	GW.querying = tab
	if not tab then
		return
	end
	GW.asked[tab] = true
	SB.Adapter.GuildQuery(tab)
	SB.Debounce("guild.queryNext", GW.QUERY_GAP, GW.QueryNext, "bank")
end

function GW.QueryAll()
	GW.queue, GW.asked = {}, {}
	local first = SB.Adapter.GuildCurrentTab()
	if first and GW.tabs[first] and GW.tabs[first].viewable then
		GW.queue[1] = first
	end
	for _, tab in ipairs(GW.order) do
		if tab ~= first then
			GW.queue[#GW.queue + 1] = tab
		end
	end
	GW.QueryNext()
end

---------------------------------------------------------------------------
-- Contents: each viewable tab as a header line and a grid of its 98 slots
---------------------------------------------------------------------------
GW.labels = {}

local function withdrawText(t)
	if not t or t.withdrawals < 0 then
		return L.GUILD_WITHDRAW_UNLIMITED
	elseif t.withdrawals == 0 then
		return L.GUILD_WITHDRAW_NONE
	end
	return L.GUILD_WITHDRAW_LEFT:format(t.withdrawals)
end
GW.WithdrawText = withdrawText

function GW.TabLabel(tab)
	local text = L.GUILD_TAB_HEADER:format(tabName(tab), withdrawText(GW.tabs[tab]))
	if not GW.loaded[tab] then
		text = text .. L.GUILD_TAB_LOADING
	end
	if tab == GW.target then
		text = text .. L.GUILD_DEPOSITS_HERE
	end
	return text
end

local function label(tab)
	local fs = GW.labels[tab]
	if not fs then
		fs = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetJustifyH("LEFT")
		GW.labels[tab] = fs
	end
	return fs
end

function GW.Render()
	local B, cols = SB.GuildButtons, GW.COLUMNS
	local step = GW.SLOT + GW.GAP
	local y = GW.PAD
	local shown = {}
	for _, tab in ipairs(GW.order) do
		shown[tab] = true
		local fs = label(tab)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", child, "TOPLEFT", GW.PAD, -y)
		fs:SetText(GW.TabLabel(tab))
		if tab == GW.target then
			fs:SetTextColor(0.3, 1, 0.3)
		else
			fs:SetTextColor(1, 0.82, 0)
		end
		fs:Show()
		y = y + GW.TAB_HEADER
		local cached = GW.cache[tab] or {}
		for slot = 1, SB.Adapter.GUILD_SLOTS do
			local b = B.Get(tab, slot)
			if b then
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", child, "TOPLEFT", GW.PAD + ((slot - 1) % cols) * step,
					-(y + math.floor((slot - 1) / cols) * step))
				B.Paint(b, cached[slot])
				b:Show()
			end
		end
		y = y + math.ceil(SB.Adapter.GUILD_SLOTS / cols) * step + GW.TAB_GAP
	end
	for tab, fs in pairs(GW.labels) do
		if not shown[tab] then
			fs:Hide()
			for slot = 1, SB.Adapter.GUILD_SLOTS do
				local b = B.Get(tab, slot)
				if b then
					b:Hide()
				end
			end
		end
	end
	local width = GW.PAD * 2 + cols * GW.SLOT + (cols - 1) * GW.GAP
	child:SetSize(width, y + GW.PAD)
	local maxHeight = UIParent:GetHeight() * GW.MAX_HEIGHT_FRACTION
	frame:SetSize(width + 8, math.min(y + GW.PAD, maxHeight - GW.HEADER - GW.FOOTER) + GW.HEADER + GW.FOOTER)
end

---------------------------------------------------------------------------
-- Slot actions (called by UI/GuildButtons.lua). Feedback in chat for every refusal (P2).
---------------------------------------------------------------------------
local function slotInfo(tab, slot)
	return GW.cache[tab] and GW.cache[tab][slot]
end

-- Returns what happened: "link" | "view" | "empty" | "limit" | "tab" | "withdraw" | "pickup".
function GW.ClickSlot(tab, slot, mouseButton)
	local A, info = SB.Adapter, slotInfo(tab, slot)
	if info and A.ModifiedClick(info.link) then
		return "link"
	end
	if GW.VisitMode() == "view" then
		SB.Print(L.GUILD_VIEW_ONLY)
		return "view"
	end
	if mouseButton ~= "RightButton" then
		A.GuildPickup(tab, slot)
		return "pickup"
	end
	if not info then
		return "empty"
	end
	local t = GW.tabs[tab]
	if t and t.withdrawals == 0 then
		SB.Print(L.GUILD_NO_WITHDRAWALS:format(tabName(tab)))
		return "limit"
	end
	if not SB.Config.Get("guildBank.withdrawAnyTab") and tab ~= A.GuildCurrentTab() then
		SB.Print(L.GUILD_SELECT_TAB_FIRST:format(tabName(tab)))
		return "tab"
	end
	A.GuildWithdraw(tab, slot)
	return "withdraw"
end

function GW.DragSlot(tab, slot)
	if GW.VisitMode() == "view" then
		SB.Print(L.GUILD_VIEW_ONLY)
		return false
	end
	SB.Adapter.GuildPickup(tab, slot)
	return true
end

function GW.DropSlot(tab, slot)
	return GW.DragSlot(tab, slot)
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
function GW.IsOpen()
	return frame:IsShown()
end

function GW.Open()
	if SB.SafeMode.IsOn("bank") or not GW.interaction then
		return false
	end
	if frame:IsShown() then
		return true
	end
	GW.ReadTabs()
	if not SB.GuildButtons.Ensure(GW.order) then
		SB.Print(L.GUILD_COMBAT_WAIT)
		return false
	end
	frame:Show()
	GW.ApplyMode()
	GW.Render()
	GW.QueryAll()
	return true
end

function GW.Close()
	frame:Hide()
end

frame:SetScript("OnHide", Guard("guild.hide", function(self)
	if self:IsShown() then
		return
	end
	GW.queue, GW.querying = {}, nil
	SB.Emit("SB_GUILD_CLOSED")
end, "bank"))

function GW.OnOpened()
	if GW.interaction then
		GW.ApplyMode() -- a second signal for the same visit (event and OnShow): just re-apply
		return
	end
	GW.interaction, GW.visit = true, nil
	GW.Open()
end

function GW.OnClosed()
	if not GW.interaction then
		return
	end
	GW.interaction, GW.visit = false, nil
	frame:Hide()
	host.Restore()
end

-- Blizzard's guild bank UI loads on demand; hook its OnShow once it exists.
local frameHooked = false
function GW.HookFrame()
	local gf = blizzardGuildBank()
	if frameHooked or not gf then
		return
	end
	frameHooked = true
	gf:HookScript("OnShow", Guard("guild.blizzardShown", function()
		GW.OnOpened()
	end, "bank"))
end

SB.On("ADDON_LOADED", function(_, name)
	if name == "Blizzard_GuildBankUI" then
		GW.HookFrame()
	end
end, "bank")

SB.On("SB_LOGIN", function()
	GW.HookFrame()
end, "bank")

SB.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, interactionType)
	if SB.Adapter.IsGuildBanker(interactionType) then
		GW.HookFrame()
		GW.OnOpened()
	end
end, "bank")

SB.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, interactionType)
	if SB.Adapter.IsGuildBanker(interactionType) then
		GW.OnClosed()
	end
end, "bank")

-- Older clients name the visit with these events; registration fails silently without them.
SB.On("GUILDBANKFRAME_OPENED", function()
	GW.HookFrame()
	GW.OnOpened()
end, "bank")

SB.On("GUILDBANKFRAME_CLOSED", function()
	GW.OnClosed()
end, "bank")

-- A queried tab's contents arrived, or an item moved: re-read every tab asked for this visit
-- (an answer may come late, after the next query went out) and query the next tab.
SB.On("GUILDBANKBAGSLOTS_CHANGED", function()
	if not GW.interaction then
		return
	end
	for tab in pairs(GW.asked) do
		GW.loaded[tab] = true
	end
	if GW.querying then
		SB.Debounce("guild.queryNext", 0.05, GW.QueryNext, "bank")
	end
	for _, tab in ipairs(GW.order) do
		if GW.loaded[tab] then
			GW.ReadTab(tab)
		end
	end
	GW.RefreshTarget()
	if frame:IsShown() then
		GW.Render()
	end
end, "bank")

SB.On("GUILDBANK_UPDATE_TABS", function()
	if not GW.interaction then
		return
	end
	GW.ReadTabs()
	if frame:IsShown() and SB.GuildButtons.Ensure(GW.order) then
		GW.Render()
	end
end, "bank")

SB.On("GUILDBANK_ITEM_LOCK_CHANGED", function()
	if GW.interaction and frame:IsShown() then
		for _, tab in ipairs(GW.order) do
			if GW.loaded[tab] then
				GW.ReadTab(tab)
			end
		end
		GW.Render()
	end
end, "bank")

SB.On("PLAYER_LOGOUT", function()
	host.Restore()
end, "bank")

SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window ~= "bank" then
		return
	end
	if on then
		frame:Hide()
		host.Restore()
	elseif GW.interaction then
		GW.Open()
	end
end, "none")

SB.Slash.Register("guild", L.HELP_GUILD, function(arg)
	arg = (arg or ""):lower()
	if arg ~= "full" and arg ~= "view" then
		return L.GUILD_USAGE:format(GW.Mode())
	end
	if not SB.Config.Set("guildBank.mode", arg) then
		return L.SETTINGS_READONLY
	end
	GW.visit = nil
	if frame:IsShown() then
		GW.ApplyMode()
	end
	return arg == "full" and L.GUILD_MODE_FULL or L.GUILD_MODE_VIEW
end, "bank")
```

<!-- sbw3:file T2 i08 SwagBag/UI/GuildButtons.lua -->
Create `SwagBag/UI/GuildButtons.lua`:

```lua
-- SwagBag guild bank slot buttons (spec F16). Guild bank items are not container items, so
-- these are SwagBag's own plain ItemButtons (no secure template), one per (tab, slot),
-- created out of combat when the guild bank first opens and kept for the session. What a
-- click does is decided by the guild bank window (SB.GuildBankWindow.ClickSlot / DragSlot /
-- DropSlot), which calls Blizzard's own guild bank functions through the Adapter.
--   GuildButtons.SetParent(frame)  the guild window's scroll child (set once at load)
--   GuildButtons.Ensure(tabs) -> true when every button exists (false: waits for combat to end)
--   GuildButtons.Get(tab, slot) -> button | nil;  button.tab, button.slot
--   GuildButtons.Paint(button, info)   info: Adapter.GuildSlot result or nil
local _, SB = ...

local GB = { buttons = {}, count = 0, parent = nil }
SB.GuildButtons = GB

function GB.SetParent(frame)
	GB.parent = frame
end

local function window()
	return SB.GuildBankWindow
end

local function create(tab, slot)
	local Guard = SB.ErrorTrap.Guard
	local b = CreateFrame("ItemButton", nil, GB.parent)
	b.tab, b.slot = tab, slot
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnClick", Guard("guild.click", function(self, mouseButton)
		window().ClickSlot(self.tab, self.slot, mouseButton)
	end, "bank"))
	b:SetScript("OnDragStart", Guard("guild.drag", function(self)
		window().DragSlot(self.tab, self.slot)
	end, "bank"))
	b:SetScript("OnReceiveDrag", Guard("guild.drop", function(self)
		window().DropSlot(self.tab, self.slot)
	end, "bank"))
	b:SetScript("OnEnter", Guard("guild.enter", function(self)
		SB.Adapter.GuildTooltip(self, self.tab, self.slot)
	end, "bank"))
	b:SetScript("OnLeave", Guard("guild.leave", function()
		SB.Adapter.HideTooltip()
	end, "bank"))
	b:Hide()
	GB.buttons[tab][slot] = b
	GB.count = GB.count + 1
	return b
end

function GB.Ensure(tabs)
	if SB.Adapter.InCombat() then
		SB.OutOfCombat(function()
			GB.Ensure(tabs)
		end, "guildButtons.ensure", "bank")
		return false
	end
	for _, tab in ipairs(tabs) do
		GB.buttons[tab] = GB.buttons[tab] or {}
		for slot = #GB.buttons[tab] + 1, SB.Adapter.GUILD_SLOTS do
			create(tab, slot)
		end
	end
	return true
end

function GB.Get(tab, slot)
	local list = GB.buttons[tab]
	return list and list[slot]
end

function GB.Paint(button, info)
	SetItemButtonTexture(button, info and info.icon or nil)
	SetItemButtonCount(button, info and info.count or 0)
	SetItemButtonQuality(button, info and info.quality or nil, info and info.link or nil)
	SetItemButtonDesaturated(button, info ~= nil and info.isLocked)
end
```

<!-- sbw3:edit T2 i09 SwagBag/Core/Report.lua -->
In `SwagBag/Core/Report.lua`, find:

```lua
			bank.target and bank.GroupName(bank.target) or L.REPORT_NONE)
	end
	return table.concat(lines, "\n")
end
```

and replace it with:

```lua
			bank.target and bank.GroupName(bank.target) or L.REPORT_NONE)
	end
	local guild = SB.GuildBankWindow
	if guild then
		lines[#lines + 1] = L.REPORT_GUILD:format(guild.Mode(), tostring(guild.lastVisit or L.REPORT_NONE))
	end
	return table.concat(lines, "\n")
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/guildbank_spec.lua spec/report_spec.lua`
Expected: `32 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (36 files)`, `476 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/mock_adapter.lua \
  spec/guildbank_spec.lua \
  spec/report_spec.lua \
  SwagBag/SwagBag.toc \
  .luacheckrc \
  SwagBag/Core/Adapter.lua \
  SwagBag/Core/Config.lua \
  SwagBag/Locale/enUS.lua \
  SwagBag/UI/GuildBankWindow.lua \
  SwagBag/UI/GuildButtons.lua \
  SwagBag/Core/Report.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 2: guild bank in tiny mode with re-hosted tabs, withdraw and deposit, view fallback" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 7: In-game session G1 (the user does this on Oct 15; about 10 minutes)**

Give the user this checklist exactly. You need:
- a guild vault;
- a tab you may deposit into;
- a tab you may withdraw from (at least one withdrawal left today), and ideally a second one;
- one cheap item you do not mind putting in the guild bank;
- your Hearthstone.

1. Quit the game completely and start it again (new files need a full restart). Log in. Chat shows `SwagBag: v0.3.0 loaded. Type /swagbag help for commands.`
2. Open the guild vault. Blizzard's guild bank does **not** appear. A window titled `SwagBag guild bank` appears instead, with Blizzard's tab icons along its right edge. Each tab you may view has a line like `Mats - 5 withdrawals left today (loading...)` (or `unlimited withdrawals`). Within a few seconds `(loading...)` goes away and the tab's items appear in a grid under its line.
3. The window's second line says `Deposits go to <tab name> - switch with the tabs on the right`. That tab's line ends with `- deposits go here` and is green.
4. Click a different tab icon on the right (one you may deposit into). The second line and the green line follow it.
5. In your SwagBag bags, right-click the cheap item. It goes into the tab named on the second line: within a second it shows in that tab's grid.
6. In the SwagBag guild bank window, right-click that item. It comes back to your bags. If the tab is not unlimited, its `withdrawals left today` number goes down by one. Move the mouse off it.
7. If you may withdraw from a tab that is **not** the selected one, right-click an item there. It moves to your bags. (If nothing happens, tell Claude the tab's name.)
8. Drag an item from the guild bank window onto an empty slot of your SwagBag bags: it moves there. Drag it back onto an empty slot of the guild bank window: it moves back.
9. Press **Enter** to open the chat box, then shift-click an item in the guild bank window. Its link appears in the chat box. Press **Esc** to clear the chat box.
10. Click `Blizzard guild bank`. The title says `Blizzard's guild bank is shown for this visit (gold, log, permissions)` for a moment, and Blizzard's guild bank appears with the SwagBag window to its right. Right-click an item in the SwagBag window: chat says `SwagBag's guild bank is view-only now: move items in Blizzard's guild bank window.` Nothing moves.
11. Click `Blizzard guild bank` again. Blizzard's guild bank disappears, and the title says `Blizzard's guild bank is hidden again` for a moment.
12. Press **Esc** once. The SwagBag guild bank window closes.
13. Walk away from the vault. Right-click your Hearthstone in the SwagBag bags: the cast bar appears, with **no** red `Interface action failed because of an AddOn` message. Move to cancel it.
14. Type `/swagbag report`, press Ctrl+C, and paste it into Claude Code. Claude checks `Blocked actions: none`, no new errors, and a line `Guild bank: setting full, last visit full`.

Pass: steps 5, 6 and 8 moved the items as described, step 13 cast with no red message, and the report is clean.

If it fails: tell Claude which step. If step 5, 6 or 8 failed, or the report lists a blocked action, type `/swagbag guild view`. SwagBag's window then only shows the guild bank, and you move items in Blizzard's window. On Oct 16 Claude makes "view" the default (spec AC16.6): one line in `SwagBag/Core/Config.lua`, `guildBank = { mode = "view", … }`. If only step 7 failed, Claude makes `withdrawAnyTab = false` the default instead: a right-click in another tab then says `Click the <tab> tab on the right first, then right-click the item again.`

---
### Task 3: Overlay data and the upgrade arrow (AC9.3); the crest keyword and data file

Spec F9 (AC9.1, AC9.3). This task and Task 4 come right after the first-day checks (D18): they need only the bags' item records, so the user gets overlays on the bags within days. `Engine/OverlayData.lua` is pure: an item record goes in, and what to draw on its button comes out:
- the item level on equippable gear;
- the upgrade track as `H3/6` (initial, level, maximum), from `C_Item.GetItemUpgradeInfo` through the Adapter, never from the tooltip;
- the keystone's level and a short dungeon name from its link (`O.Short`: the initials of the words that matter, or 3 letters of a one-word name);
- the junk coin (gray, and a vendor pays for it);
- a `BoE` / `WuE` badge until the item is bound;
- the **upgrade arrow**.

**The arrow (AC9.3).** The item must beat the lowest-ilvl item equipped in the matching slot(s); an empty slot counts as 0.
- Rings and trinkets compare with both slots.
- A two-hander compares by summed item level (2 × its level against main hand plus off hand).
- A one-hander also compares with the off hand when the off hand holds a one-hand weapon. An off-hand item never beats a two-hander (D10).
- Gear the character cannot use (`C_PlayerInfo.CanUseItem`, feature-detected) and items still loading never get an arrow.
- With "Use Pawn", Pawn's verdict replaces the item-level rule when Pawn gives one.

**Records.** `Items.Describe` records gain `record.track` and `record.hasNoValue`. (Guild bank records get the same two fields when Task 10 adds `Items.DescribeLink`.)

**Crests (D8).** `Engine/Crests.lua` holds the season's crest item IDs (empty until session O1 confirms them) and the name words `crest` and `valorstone`. The keyword `crest` (alias `upgrade currency`) matches an ID, else a non-gear item whose name contains a word. A loading item is "not a crest", because a nil in Keystone & Crests (priority 95) would hold every loading item in New. `c_keystone`'s query becomes `keystone | crest`. That changes a built-in default, so users' diffs (spec §8.5) stay intact.

**Files:**
- Create: `SwagBag/Engine/OverlayData.lua`, `SwagBag/Engine/Crests.lua`
- Modify:
  - `SwagBag/Core/Adapter.lua`: `UpgradeInfo`, `DungeonName`, `EquippedItems`, `CanUse`, `PawnUpgrade`, optional checks;
  - `.luacheckrc`;
  - `SwagBag/Engine/Items.lua` (`track`, `hasNoValue`), `SwagBag/Engine/Keywords.lua` (`crest`), `SwagBag/Engine/CategoryDefaults.lua`;
  - `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`.
- Test: `spec/mock_adapter.lua`, `spec/overlaydata_spec.lua` (new), `spec/keywords_spec.lua`, `spec/categorizer_spec.lua`, `spec/categories_spec.lua`

**Interfaces:**
- Consumes: item records (`classID`, `equipLoc`, `ilvl`, `pending`, `isBound`, `isWUE`, `bind`, `quality`, `isKeystone`, `link`), `SB.Adapter.ITEM_CLASS`.
- Produces:
  - `SB.OverlayData.For(record, ctx) -> { ilvl, track, keystone = { level, dungeon }, junk, bind, upgrade }`, with `ctx = { equipped, canUse, dungeonName, pawn }`.
  - `SB.OverlayData.IsUpgrade(record, equipped, canUse) -> bool`, `.Short(name) -> text`, `.SLOTS`.
  - `SB.Crests = { ids = {}, words = { "crest", "valorstone" } }`.
  - `SB.Adapter.UpgradeInfo(link) -> { track, level, max } | nil`, `.DungeonName(mapID)`, `.EquippedItems() -> { [invSlot] = { ilvl, equipLoc } }`, `.CanUse(itemID) -> bool`, `.PawnUpgrade(bag, slot) -> bool | nil`.
  - Records gain `track` and `hasNoValue`. Keyword `crest` (alias `upgrade currency`).

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T3 s01 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
			isBound = s.isBound == true,
			name = (not it.pending) and it.name or nil,
			hasNoValue = false,
		}
	end
```

and replace it with:

```lua
			isBound = s.isBound == true,
			name = (not it.pending) and it.name or nil,
			hasNoValue = s.hasNoValue == true,
		}
	end
```

<!-- sbw3:edit T3 s02 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
	end

	function m.IsWarboundUntilEquip(bag, slot)
		local s = slotOf(bag, slot)
```

and replace it with:

```lua
	end

	-- Overlays: m.tracks[link] = { track, level, max }; m.dungeons[mapID] = name;
	-- m.equipped[invSlot] = { ilvl, equipLoc }; m.cannotUse[itemID] = true; m.pawn[bag .. ":" .. slot] = bool.
	m.tracks, m.dungeons, m.equipped, m.cannotUse, m.pawn = {}, {}, {}, {}, nil
	function m.UpgradeInfo(link)
		return m.tracks[link]
	end

	function m.DungeonName(mapID)
		return m.dungeons[mapID]
	end

	function m.EquippedItems()
		local out = {}
		for slot, e in pairs(m.equipped) do
			out[slot] = { ilvl = e.ilvl, equipLoc = e.equipLoc }
		end
		return out
	end

	function m.CanUse(itemID)
		return not m.cannotUse[itemID]
	end

	function m.PawnUpgrade(bag, slot)
		if m.pawn == nil then
			return nil
		end
		return m.pawn[bag .. ":" .. slot] == true
	end

	function m.IsWarboundUntilEquip(bag, slot)
		local s = slotOf(bag, slot)
```

<!-- sbw3:edit T3 s03 spec/categories_spec.lua -->
In `spec/categories_spec.lua`, find:

```lua
-- c_fish (name search by design), c_other (fallback) are exempt; c_tools also has an item list.
local EXPECTED = {
	c_keystone = { "keystone" }, c_consumables = { "consumable" }, c_gear = { "gear" },
	c_boe = { "boe", "gear" }, c_tradegoods = { "reagent", "tradegoods" }, c_herbs = { "herb" }, c_ore = { "ore" },
	c_leathercloth = { "cloth", "leather" }, c_enchanting = { "enchanting" }, c_cooking = { "cooking" },
```

and replace it with:

```lua
-- c_fish (name search by design), c_other (fallback) are exempt; c_tools also has an item list.
local EXPECTED = {
	c_keystone = { "crest", "keystone" }, c_consumables = { "consumable" }, c_gear = { "gear" },
	c_boe = { "boe", "gear" }, c_tradegoods = { "reagent", "tradegoods" }, c_herbs = { "herb" }, c_ore = { "ore" },
	c_leathercloth = { "cloth", "leather" }, c_enchanting = { "enchanting" }, c_cooking = { "cooking" },
```

<!-- sbw3:edit T3 s04 spec/categorizer_spec.lua -->
In `spec/categorizer_spec.lua`, find:

```lua
		assert.equal(before + 2, #SB.ErrorTrap.Recent())
	end)
end)
```

and replace it with:

```lua
		assert.equal(before + 2, #SB.ErrorTrap.Recent())
	end)

	it("Keystone & Crests files the keystone and crest items (spec 7.6)", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Crests.lua")
		A.AddItem(500001, { name = "Weathered Harbinger Crest", classID = A.ITEM_CLASS.Miscellaneous, subclassID = 0,
			quality = 2, maxStack = 99, bind = "pickup" })
		A.Put(0, 7, 500001, 12)
		C.Load()
		assert.equal("c_keystone", at(5))
		assert.equal("c_keystone", at(7))
	end)
end)
```

<!-- sbw3:edit T3 s05 spec/keywords_spec.lua -->
In `spec/keywords_spec.lua`, find:

```lua
		end
	end)
end)
```

and replace it with:

```lua
		end
	end)

	it("crest: the season's item IDs, else a crest or valorstone name, never gear, never 'unknown'", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Crests.lua")
		local A = SB.Adapter
		A.AddItem(500001, { name = "Gilded Harbinger Crest", classID = A.ITEM_CLASS.Miscellaneous, subclassID = 0,
			quality = 4, maxStack = 99, bind = "pickup" })
		A.AddItem(500002, { name = "Crest of the Tides", classID = A.ITEM_CLASS.Armor, subclassID = 1,
			equipLoc = "INVTYPE_CLOAK", quality = 3, ilvl = 280, maxStack = 1, bind = "equip" })
		A.AddItem(500003, { name = "Shiny Token", classID = A.ITEM_CLASS.Miscellaneous, subclassID = 0, quality = 3 })
		A.AddItem(500004, { classID = A.ITEM_CLASS.Miscellaneous, subclassID = 0, pending = true })
		SB.Crests.ids[500003] = true
		A.SetBagSize(1, 4)
		for i = 1, 4 do
			A.Put(1, i, 500000 + i, 1)
		end
		local q = Q.Compile("crest")
		local function at(slot)
			return Q.Eval(q, SB.Items.Describe(1, slot))
		end
		assert.same({ true, false, true, false }, { at(1), at(2), at(3), at(4) })
		assert.equal(true, Q.Eval(Q.Compile("upgrade currency"), SB.Items.Describe(1, 1)))
	end)
end)
```

<!-- sbw3:file T3 s06 spec/overlaydata_spec.lua -->
Create `spec/overlaydata_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("OverlayData (spec F9)", function()
	local SB, A, O
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Items.lua", "SwagBag/Engine/OverlayData.lua" })
		A, O = SB.Adapter, SB.OverlayData
		Fixtures.SmallBags(A)
	end)

	local function gear(equipLoc, ilvl, extra)
		local r = { itemID = 400000, classID = A.ITEM_CLASS.Armor, equipLoc = equipLoc, ilvl = ilvl, pending = false }
		for k, v in pairs(extra or {}) do
			r[k] = v
		end
		return r
	end

	local function weapon(equipLoc, ilvl)
		return { itemID = 400001, classID = A.ITEM_CLASS.Weapon, equipLoc = equipLoc, ilvl = ilvl, pending = false }
	end

	local function worn(list)
		local out = {}
		for slot, e in pairs(list) do
			out[slot] = { ilvl = e[1], equipLoc = e[2] }
		end
		return out
	end

	it("item level only on equippable gear", function()
		assert.equal(285, O.For(SB.Items.Describe(0, 3)).ilvl, "the ring")
		assert.is_nil(O.For(SB.Items.Describe(0, 1)).ilvl, "a potion")
		assert.is_nil(O.For({ classID = A.ITEM_CLASS.Armor, equipLoc = "INVTYPE_BAG", ilvl = 1 }).ilvl, "a bag")
		assert.is_nil(O.For(gear("INVTYPE_FINGER", nil, { pending = true })).ilvl, "still loading")
	end)

	it("the upgrade track as initial, level and maximum", function()
		assert.equal("H3/6", O.For(gear("INVTYPE_HEAD", 280, { track = { track = "Hero", level = 3, max = 6 } })).track)
		assert.is_nil(O.For(gear("INVTYPE_HEAD", 280)).track)
	end)

	it("the keystone's level and a short dungeon name from its link", function()
		local r = SB.Items.Describe(0, 5)
		assert.same({ level = 12, dungeon = "AKCE" },
			O.For(r, { dungeonName = function(id) return id == 503 and "Ara-Kara, City of Echoes" or nil end }).keystone)
		assert.same({ level = 12 }, O.For(r, {}).keystone, "no name known: the level alone")
	end)

	it("short dungeon names: initials of the words that matter, or three letters of a one-word name", function()
		assert.same({ "DC", "AKCE", "PSF", "Roo", "OF", "TP" }, { O.Short("Darkflame Cleft"),
			O.Short("Ara-Kara, City of Echoes"), O.Short("Priory of the Sacred Flame"), O.Short("The Rookery"),
			O.Short("Operation: Floodgate"), O.Short("Theater of Pain") })
		assert.is_nil(O.Short(nil))
	end)

	it("a junk coin on gray items a vendor pays for", function()
		assert.equal(true, O.For(SB.Items.Describe(0, 6)).junk)
		A.Put(0, 6, Fixtures.JUNK, 3, { hasNoValue = true })
		assert.equal(false, O.For(SB.Items.Describe(0, 6)).junk)
		assert.equal(false, O.For(SB.Items.Describe(0, 1)).junk)
	end)

	it("BoE and WuE badges until the item is bound", function()
		assert.equal("BoE", O.For(SB.Items.Describe(0, 3)).bind)
		assert.equal("WuE", O.For(gear("INVTYPE_HEAD", 1, { bind = "equip", isWUE = true })).bind)
		assert.is_nil(O.For(gear("INVTYPE_HEAD", 1, { bind = "equip", isBound = true })).bind)
		assert.is_nil(O.For(SB.Items.Describe(0, 4)).bind, "soulbound helm")
	end)

	it("upgrade arrow, one slot: beats the item worn there; an empty slot is always beaten (AC9.3)", function()
		local up = O.IsUpgrade
		assert.equal(true, up(gear("INVTYPE_HEAD", 280), worn({ [1] = { 270, "INVTYPE_HEAD" } })))
		assert.equal(false, up(gear("INVTYPE_HEAD", 280), worn({ [1] = { 285, "INVTYPE_HEAD" } })))
		assert.equal(false, up(gear("INVTYPE_HEAD", 280), worn({ [1] = { 280, "INVTYPE_HEAD" } })), "equal is not up")
		assert.equal(true, up(gear("INVTYPE_HEAD", 280), worn({})))
		assert.equal(true, up(gear("INVTYPE_ROBE", 281), worn({ [5] = { 280, "INVTYPE_CHEST" } })))
	end)

	it("rings and trinkets compare with the lower of both slots", function()
		local up = O.IsUpgrade
		assert.equal(true, up(gear("INVTYPE_FINGER", 285), worn({ [11] = { 290, "INVTYPE_FINGER" },
			[12] = { 280, "INVTYPE_FINGER" } })))
		assert.equal(false, up(gear("INVTYPE_FINGER", 285), worn({ [11] = { 290, "INVTYPE_FINGER" },
			[12] = { 286, "INVTYPE_FINGER" } })))
		assert.equal(true, up(gear("INVTYPE_TRINKET", 270), worn({ [13] = { 300, "INVTYPE_TRINKET" } })),
			"the second trinket slot is empty")
		assert.equal(false, up(gear("INVTYPE_TRINKET", 270), worn({ [13] = { 300, "INVTYPE_TRINKET" },
			[14] = { 270, "INVTYPE_TRINKET" } })))
	end)

	it("a two-hander compares by summed item level against main and off hand", function()
		local up = O.IsUpgrade
		local dual = worn({ [16] = { 290, "INVTYPE_WEAPON" }, [17] = { 280, "INVTYPE_SHIELD" } })
		assert.equal(true, up(weapon("INVTYPE_2HWEAPON", 286), dual), "572 > 570")
		assert.equal(false, up(weapon("INVTYPE_2HWEAPON", 285), dual), "570 = 570")
		assert.equal(false, up(weapon("INVTYPE_2HWEAPON", 289), worn({ [16] = { 290, "INVTYPE_2HWEAPON" } })))
		assert.equal(true, up(weapon("INVTYPE_2HWEAPON", 291), worn({ [16] = { 290, "INVTYPE_2HWEAPON" } })))
		assert.equal(true, up(weapon("INVTYPE_RANGEDRIGHT", 200), worn({})))
	end)

	it("one-handers: the main hand, plus the off hand when it holds a one-hand weapon; off-hands never beat a two-hander",
		function()
			local up = O.IsUpgrade
			local shield = worn({ [16] = { 280, "INVTYPE_WEAPON" }, [17] = { 260, "INVTYPE_SHIELD" } })
			assert.equal(false, up(weapon("INVTYPE_WEAPON", 275), shield), "the shield slot is not a weapon slot")
			local dual = worn({ [16] = { 290, "INVTYPE_WEAPON" }, [17] = { 280, "INVTYPE_WEAPON" } })
			assert.equal(true, up(weapon("INVTYPE_WEAPON", 285), dual))
			assert.equal(true, up(gear("INVTYPE_SHIELD", 270), shield))
			assert.equal(false, up(gear("INVTYPE_HOLDABLE", 400), worn({ [16] = { 290, "INVTYPE_2HWEAPON" } })))
			assert.equal(true, up(weapon("INVTYPE_WEAPONMAINHAND", 300), worn({ [16] = { 290, "INVTYPE_2HWEAPON" } })))
		end)

	it("no arrow on gear the character cannot use, on items still loading, or on things that are not worn gear", function()
		local up = O.IsUpgrade
		assert.equal(false, up(gear("INVTYPE_HEAD", 400), worn({}), function() return false end))
		assert.equal(false, up(gear("INVTYPE_HEAD", 400, { pending = true }), worn({})))
		assert.equal(false, up(gear("INVTYPE_BODY", 400), worn({})), "a shirt")
		assert.equal(false, up({ classID = A.ITEM_CLASS.Consumable, equipLoc = "", ilvl = 400 }, worn({})))
	end)

	it("with Pawn the verdict is Pawn's; without an answer from Pawn the item-level rule decides", function()
		local helm = gear("INVTYPE_HEAD", 200)
		local worse = worn({ [1] = { 300, "INVTYPE_HEAD" } })
		assert.equal(true, O.For(helm, { equipped = worse, pawn = function() return true end }).upgrade)
		assert.equal(false, O.For(gear("INVTYPE_HEAD", 400), { equipped = worse, pawn = function() return false end }).upgrade)
		assert.equal(false, O.For(helm, { equipped = worse, pawn = function() return nil end }).upgrade)
		assert.equal(true, O.For(gear("INVTYPE_HEAD", 301), { equipped = worse, pawn = function() return nil end }).upgrade)
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/categories_spec.lua spec/categorizer_spec.lua spec/keywords_spec.lua spec/overlaydata_spec.lua`
Expected: `52 passed, 15 failed`. `Engine/OverlayData.lua`, `Engine/Crests.lua` and the `crest` keyword do not exist, and `c_keystone` still reads `keystone`.

Critical tests and the mutation that must make each fail:
- "a two-hander compares by summed item level against main and off hand": `return ilvl > math.min(main, off)` in the two-hander branch.
- "rings and trinkets compare with the lower of both slots": take the highest slot instead of the lowest.
- "one-handers: the main hand, plus the off hand when it holds a one-hand weapon…": drop `ONE_HAND_WEAPON[off.equipLoc]`, or delete the `mainIsTwoHand` refusal.
- "no arrow on gear the character cannot use…": `if false then` for the `canUse` test.
- "with Pawn the verdict is Pawn's…": `if verdict then` instead of `if verdict ~= nil then`.
- `keywords_spec` "crest: … never 'unknown'": return `nil` for a loading item.
- `categorizer_spec` "a loading item that instant facts already decide is filed directly (tri-state, spec 7.7)" (a week-2 test): the same mutation. It is why the crest rule returns false.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T3 i01 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
Engine/Query/Parser.lua
Engine/Query/Query.lua
Engine/Keywords.lua
Engine/Search.lua
```

and replace it with:

```text
Engine/Query/Parser.lua
Engine/Query/Query.lua
Engine/Crests.lua
Engine/Keywords.lua
Engine/Search.lua
```

<!-- sbw3:edit T3 i02 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
Engine/Categorizer.lua
Engine/Layout.lua

# UI
```

and replace it with:

```text
Engine/Categorizer.lua
Engine/Layout.lua
Engine/OverlayData.lua

# UI
```

<!-- sbw3:edit T3 i03 .luacheckrc -->
In `.luacheckrc`, find:

```lua
	"GetCurrentGuildBankTab", "AutoStoreGuildBankItem", "PickupGuildBankItem", "GetGuildInfo", "GetRealmName",
	"IsModifiedClick", "HandleModifiedItemClick",
}

```

and replace it with:

```lua
	"GetCurrentGuildBankTab", "AutoStoreGuildBankItem", "PickupGuildBankItem", "GetGuildInfo", "GetRealmName",
	"IsModifiedClick", "HandleModifiedItemClick",
	"C_ChallengeMode", "C_PlayerInfo", "GetInventoryItemLink",
}

```

<!-- sbw3:edit T3 i04 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
	end
	return (info.maxLevel or info.maxUpgradeLevel or 0) > 0 or (info.trackString or "") ~= ""
end

```

and replace it with:

```lua
	end
	return (info.maxLevel or info.maxUpgradeLevel or 0) > 0 or (info.trackString or "") ~= ""
end

-- Upgrade track of an item link: { track = "Hero", level = 3, max = 6 }, or nil when the
-- item has none (or the API is missing). Real API only; no tooltip reading (spec P7).
function A.UpgradeInfo(link)
	if type(link) ~= "string" or not (C_Item and C_Item.GetItemUpgradeInfo) then
		return nil
	end
	local ok, info = pcall(C_Item.GetItemUpgradeInfo, link)
	if not ok or type(info) ~= "table" then
		return nil
	end
	local track, level, max = info.trackString, info.currentLevel, info.maxLevel or info.maxUpgradeLevel
	if type(track) ~= "string" or track == "" or isSecret(track) or type(level) ~= "number" or type(max) ~= "number" then
		return nil
	end
	return { track = track, level = level, max = max }
end

-- Name of a Mythic+ dungeon (keystone link map ID), or nil.
function A.DungeonName(mapID)
	if not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then
		return nil
	end
	local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
	if ok and type(name) == "string" and not isSecret(name) then
		return name
	end
	return nil
end

-- What the character wears: [inventory slot 1-17] = { ilvl, equipLoc } (nil = empty slot).
function A.EquippedItems()
	local out = {}
	for slot = 1, 17 do
		local okL, link = pcall(GetInventoryItemLink, "player", slot)
		if okL and type(link) == "string" and not isSecret(link) then
			local inst = A.GetItemInstant(link)
			local okI, ilvl = pcall(function()
				return C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot))
			end)
			out[slot] = { ilvl = (okI and type(ilvl) == "number" and not isSecret(ilvl)) and ilvl or 0,
				equipLoc = inst and inst.equipLoc or "" }
		end
	end
	return out
end

-- True unless the client says this character cannot use the item (feature-detected).
function A.CanUse(itemID)
	if not (C_PlayerInfo and C_PlayerInfo.CanUseItem) then
		return true
	end
	local ok, yes = pcall(C_PlayerInfo.CanUseItem, itemID)
	return not ok or yes ~= false
end

-- Pawn's verdict for a bag item: true / false, or nil without Pawn (spec AC9.3).
function A.PawnUpgrade(bag, slot)
	local fn = _G.PawnIsContainerItemAnUpgrade
	if type(fn) ~= "function" then
		return nil
	end
	local ok, yes = pcall(fn, bag, slot)
	if not ok then
		return nil
	end
	return yes and true or false
end

```

<!-- sbw3:edit T3 i05 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
	{ path = "Enum.AddOnRestrictionType", window = "bags", required = false },
	{ path = "C_ChallengeMode.IsChallengeModeActive", window = "bags", required = false },
	{ path = "C_RestrictedActions.IsAddOnRestrictionActive", window = "bags", required = false },
	{ path = "GetGuildBankItemInfo", window = "bank", required = false },
```

and replace it with:

```lua
	{ path = "Enum.AddOnRestrictionType", window = "bags", required = false },
	{ path = "C_ChallengeMode.IsChallengeModeActive", window = "bags", required = false },
	{ path = "C_ChallengeMode.GetMapUIInfo", window = "bags", required = false },
	{ path = "C_PlayerInfo.CanUseItem", window = "bags", required = false },
	{ path = "GetInventoryItemLink", window = "bags", required = false },
	{ path = "C_RestrictedActions.IsAddOnRestrictionActive", window = "bags", required = false },
	{ path = "GetGuildBankItemInfo", window = "bank", required = false },
```

<!-- sbw3:edit T3 i06 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_GUILD = "Guild bank: setting %s, last visit %s"

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

and replace it with:

```lua
L.REPORT_GUILD = "Guild bank: setting %s, last visit %s"

-- Overlays (spec F9)
L.OVERLAY_TRACK = "%s%d/%d"
L.BADGE_BOE = "BoE"
L.BADGE_WUE = "WuE"

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

<!-- sbw3:edit T3 i07 SwagBag/Engine/CategoryDefaults.lua -->
In `SwagBag/Engine/CategoryDefaults.lua`, find:

```lua

SB.CategoryDefaults = {
	{ id = "c_keystone", name = L.CAT_KEYSTONE, query = "keystone", priority = 95, displayOrder = 10 },
	{ id = "c_consumables", name = L.CAT_CONSUMABLES, query = "consumable", priority = 65, displayOrder = 20 },
	{ id = "c_gear", name = L.CAT_GEAR, query = "gear", priority = 70, displayOrder = 30 },
```

and replace it with:

```lua

SB.CategoryDefaults = {
	{ id = "c_keystone", name = L.CAT_KEYSTONE, query = "keystone | crest", priority = 95, displayOrder = 10 },
	{ id = "c_consumables", name = L.CAT_CONSUMABLES, query = "consumable", priority = 65, displayOrder = 20 },
	{ id = "c_gear", name = L.CAT_GEAR, query = "gear", priority = 70, displayOrder = 30 },
```

<!-- sbw3:file T3 i08 SwagBag/Engine/Crests.lua -->
Create `SwagBag/Engine/Crests.lua`:

```lua
-- SwagBag crest data (spec 7.3 "crest", 13.2 item 4): what files into "Keystone & Crests"
-- besides the keystone. Per season, updated with patches.
--   ids    item IDs of the season's upgrade-currency items, confirmed in game
--   words  lower-case name words for the rest (never matched on gear, so a cloak named
--          "...Crest..." stays in Gear)
-- An item the user drops on the Keystone & Crests header joins it whatever this file says
-- (spec AC4.3); Claude moves confirmed IDs into `ids` when the user reports them.
local _, SB = ...

SB.Crests = {
	ids = {},
	words = { "crest", "valorstone" },
}
```

<!-- sbw3:edit T3 i09 SwagBag/Engine/Items.lua -->
In `SwagBag/Engine/Items.lua`, find:

```lua
--   location        "backpack"|"bags"|"reagentbag"|"bank"|"warband"
--   tab             bank tab number (1-based) | nil
--   pending         true while the item's data has not loaded
-- }
```

and replace it with:

```lua
--   location        "backpack"|"bags"|"reagentbag"|"bank"|"warband"
--   tab             bank tab number (1-based) | nil
--   track           { track, level, max } upgrade track | nil (overlays)
--   hasNoValue      boolean: a vendor pays nothing for it
--   pending         true while the item's data has not loaded
-- }
```

<!-- sbw3:edit T3 i10 SwagBag/Engine/Items.lua -->
In `SwagBag/Engine/Items.lua`, find:

```lua
		inEquipmentSet = A.InEquipmentSet(bag, slot),
		hasUpgradeTrack = A.HasUpgradeTrack(bag, slot),
		isUsable = A.IsUsable(s.itemID),
		isToy = A.IsToy(s.itemID),
```

and replace it with:

```lua
		inEquipmentSet = A.InEquipmentSet(bag, slot),
		hasUpgradeTrack = A.HasUpgradeTrack(bag, slot),
		track = A.UpgradeInfo(s.link),
		hasNoValue = s.hasNoValue == true,
		isUsable = A.IsUsable(s.itemID),
		isToy = A.IsToy(s.itemID),
```

<!-- sbw3:edit T3 i11 SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
-- strings (desk spike F, docs/research/2026-10-syndicator-grammar-diff.md).
-- Not yet registered (need later modules): expansion, gold/value, crafting quality,
-- collection, crest / upgrade currency.
local _, SB = ...

```

and replace it with:

```lua
-- strings (desk spike F, docs/research/2026-10-syndicator-grammar-diff.md).
-- Not yet registered (need later modules): expansion, gold/value, crafting quality,
-- collection.
local _, SB = ...

```

<!-- sbw3:edit T3 i12 SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
		return r.isKeystone == true
	end)
	kw("pet", "instance", function(r)
		return r.isCagedPet == true or r.classID == C.Battlepet
```

and replace it with:

```lua
		return r.isKeystone == true
	end)
	-- Crests and other upgrade currency items (spec 7.3): the season's item IDs, else a name
	-- word from the data file (Engine/Crests.lua). Gear is never a crest. A loading item with an
	-- unknown ID is "not a crest" rather than "unknown": the rule sits in Keystone & Crests
	-- (priority 95), and an unknown there would hold every loading item in New (spec 7.7 D3).
	kw("crest", "static", function(r)
		local list = SB.Crests or { ids = {}, words = {} }
		if list.ids[r.itemID] then
			return true
		end
		if isGear(r) or r.name == nil then
			return false
		end
		local name = r.name:lower()
		for _, word in ipairs(list.words) do
			if name:find(word, 1, true) then
				return true
			end
		end
		return false
	end, { "upgrade currency" })
	kw("pet", "instance", function(r)
		return r.isCagedPet == true or r.classID == C.Battlepet
```

<!-- sbw3:file T3 i13 SwagBag/Engine/OverlayData.lua -->
Create `SwagBag/Engine/OverlayData.lua`:

```lua
-- SwagBag overlay data (spec F9: AC9.1, AC9.3). Pure: an item record in, what to draw on its
-- button out. UI/Overlays.lua draws it and applies the per-overlay settings. Everything
-- comes from the record (Items.lua: real APIs, no tooltip reading).
--   OverlayData.For(record, ctx) -> {
--     ilvl      number | nil    equippable gear only
--     track     "H3/6" | nil    upgrade track initial, level / max
--     keystone  { level, dungeon } | nil   from the keystone link; dungeon = short name
--     junk      boolean         poor quality and a vendor pays for it
--     bind      "BoE" | "WuE" | nil   bind on equip / warbound until equipped, not yet bound
--     upgrade   boolean         the arrow (AC9.3, see IsUpgrade) }
--   ctx = { equipped = { [invSlot] = { ilvl, equipLoc } }, canUse = fn(itemID) -> bool,
--           dungeonName = fn(mapID) -> name | nil, pawn = fn(record) -> true | false | nil }
--   OverlayData.IsUpgrade(record, equipped, canUse) -> boolean
--   OverlayData.Short(name) -> short dungeon name ("Darkflame Cleft" -> "DC")
local _, SB = ...

local O = {}
SB.OverlayData = O

-- Equip location -> the inventory slots it can go in (spec AC9.3 "matching slot(s)").
O.SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_RANGED = { 16 },
	INVTYPE_RANGEDRIGHT = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
}
local TWO_HAND = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local ONE_HAND_WEAPON = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }
local MAIN, OFF = 16, 17

local function ilvlAt(equipped, slot)
	local e = equipped[slot]
	return e and e.ilvl or 0
end

-- AC9.3: higher than the lowest-ilvl item equipped in the matching slot(s); an empty slot
-- counts as 0. Rings and trinkets compare with both slots. A two-hander replaces the main and
-- off hand, so it compares by summed item level (2 x its level against both). A one-hander
-- also compares with the off hand when the off hand holds a one-hand weapon (dual wield).
-- An off-hand item never beats a two-hander (it would leave the main hand empty).
function O.IsUpgrade(record, equipped, canUse)
	local A = SB.Adapter
	local ilvl = record.ilvl
	local slots = O.SLOTS[record.equipLoc or ""]
	if not slots or record.pending or type(ilvl) ~= "number" then
		return false
	end
	if record.classID ~= A.ITEM_CLASS.Armor and record.classID ~= A.ITEM_CLASS.Weapon then
		return false
	end
	if canUse and not canUse(record.itemID) then
		return false
	end
	local main, off = equipped[MAIN], equipped[OFF]
	local mainIsTwoHand = main and TWO_HAND[main.equipLoc] or false
	if TWO_HAND[record.equipLoc] then
		if off then
			return ilvl * 2 > ilvlAt(equipped, MAIN) + ilvlAt(equipped, OFF)
		end
		return ilvl > ilvlAt(equipped, MAIN)
	end
	if slots[1] == OFF then
		if mainIsTwoHand then
			return false
		end
		return ilvl > ilvlAt(equipped, OFF)
	end
	local lowest = math.huge
	for _, slot in ipairs(slots) do
		lowest = math.min(lowest, ilvlAt(equipped, slot))
	end
	if record.equipLoc == "INVTYPE_WEAPON" and off and ONE_HAND_WEAPON[off.equipLoc] then
		lowest = math.min(lowest, ilvlAt(equipped, OFF))
	end
	return ilvl > lowest
end

local SMALL = { ["of"] = true, ["the"] = true, ["and"] = true }

-- Initials of the meaningful words (up to 4), or the first 3 letters of a one-word name.
function O.Short(name)
	if type(name) ~= "string" then
		return nil
	end
	local words = {}
	for w in name:gmatch("[^%s%-,:']+") do
		if not SMALL[w:lower()] then
			words[#words + 1] = w
		end
	end
	if #words == 0 then
		return nil
	elseif #words == 1 then
		return words[1]:sub(1, 3)
	end
	local out = {}
	for i = 1, math.min(4, #words) do
		out[i] = words[i]:sub(1, 1):upper()
	end
	return table.concat(out)
end

local function isGear(r)
	local C = SB.Adapter.ITEM_CLASS
	return r.classID == C.Armor or r.classID == C.Weapon
end

function O.For(record, ctx)
	local out = { junk = false, upgrade = false }
	if not record then
		return out
	end
	ctx = ctx or {}
	local L = SB.L
	if isGear(record) and O.SLOTS[record.equipLoc or ""] and type(record.ilvl) == "number" then
		out.ilvl = record.ilvl
	end
	local t = record.track
	if t and t.track and t.level and t.max then
		out.track = L.OVERLAY_TRACK:format(t.track:sub(1, 1), t.level, t.max)
	end
	if record.isKeystone and record.link then
		local mapID, level = record.link:match("keystone:%d+:(%d+):(%d+)")
		if level then
			local name = ctx.dungeonName and ctx.dungeonName(tonumber(mapID))
			out.keystone = { level = tonumber(level), dungeon = O.Short(name) }
		end
	end
	out.junk = record.quality == 0 and not record.hasNoValue
	if not record.isBound then
		if record.isWUE then
			out.bind = L.BADGE_WUE
		elseif record.bind == "equip" then
			out.bind = L.BADGE_BOE
		end
	end
	local verdict = ctx.pawn and ctx.pawn(record)
	if verdict ~= nil then
		out.upgrade = verdict and true or false
	else
		out.upgrade = O.IsUpgrade(record, ctx.equipped or {}, ctx.canUse)
	end
	return out
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/categories_spec.lua spec/categorizer_spec.lua spec/keywords_spec.lua spec/overlaydata_spec.lua`
Expected: `67 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (38 files)`, `490 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/mock_adapter.lua \
  spec/categories_spec.lua \
  spec/categorizer_spec.lua \
  spec/keywords_spec.lua \
  spec/overlaydata_spec.lua \
  SwagBag/SwagBag.toc \
  .luacheckrc \
  SwagBag/Core/Adapter.lua \
  SwagBag/Locale/enUS.lua \
  SwagBag/Engine/CategoryDefaults.lua \
  SwagBag/Engine/Crests.lua \
  SwagBag/Engine/Items.lua \
  SwagBag/Engine/Keywords.lua \
  SwagBag/Engine/OverlayData.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 3: overlay data and the upgrade arrow, crest keyword and data file" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 4: Overlays on bag buttons; the average item level in the bags title; Use Pawn; the reagent-bag cue; `/swagbag overlays`

`UI/Overlays.lua` draws Task 3's data on an item button:
- top left: the item level, or `+12` on a keystone;
- bottom left: the track `H3/6`, or the keystone's dungeon;
- left: `BoE` / `WuE`;
- top right: a green upgrade arrow;
- top left: a junk coin (only when nothing else is there).

The stack count stays Blizzard's own. This task wires the overlays onto the **bags** window only, so the user has them on day 2 (D18). Task 11 wires the same `Overlays.Apply` onto the bank and guild bank buttons, once those windows have contents (Tasks 8 and 10).

**How it draws.** Regions are font strings and textures on the button itself (no frames, so drawing is allowed in combat), made the first time a button needs one, in its OVERLAY layer. Dimming a button for search therefore dims its overlays too. An empty slot that never showed anything gets no regions, so a bank with many empties stays light later.

**Free-section cue.** An empty reagent-bag slot gets a faint green tint, so it is clear which empty slots take only reagents (the week-2 ledger's "reagent-bag empties in Free (UI cue)").

**When it redraws.** What the character wears is read once and kept until `PLAYER_EQUIPMENT_CHANGED`. A gear swap fires one event per slot, so the open bags window redraws once, 0.1 s after the last one (AC9.3 "re-evaluated on PLAYER_EQUIPMENT_CHANGED").

**The average item level in the title (D18).** The bags window's title reads `SwagBag — ilvl 279.4`: the average item level the character has **equipped**, with one decimal. `Adapter.EquippedItemLevel()` returns the second value of `GetAverageItemLevel()` (warcraft.wiki.gg: `avgItemLevel, avgItemLevelEquipped, avgItemLevelPvp = GetAverageItemLevel()`), feature-detected and inside `pcall`. When the function is missing or gives no number, the title is the plain `SwagBag`, with no error. The title is read again on open, on `PLAYER_EQUIPMENT_CHANGED` and on `PLAYER_AVG_ITEM_LEVEL_UPDATE` (while the window is shown). Both events are registered through `SB.On`, which already skips an event the client does not know. The title's flash messages (`SwagBag 110%`, `Regrouped`, `Sorting...` and the rest) are untouched: an item-level change during a flash does not cut it short, and when the flash ends the title goes back to the item-level title, read fresh. The setting is `bags.showIlvl` (default on).

**Switches.** Each overlay has its own switch (AC9.2), `overlays.ilvl/track/upgrade/keystone/junk/bind`, plus `overlays.usePawn`. Until the settings window arrives in week 4, `/swagbag overlays` lists them and `/swagbag overlays <name> on|off` switches one (P2: it always answers). The name `title` switches `bags.showIlvl`.

**Wiring.** The bags window applies overlays in `describe` and when a loading item's data arrives (`refreshRecord`).

**Files:**
- Create: `SwagBag/UI/Overlays.lua`
- Modify: `SwagBag/UI/BagsWindow.lua` (apply overlays; `Title`, `RefreshTitle`, flash back to the item-level title), `SwagBag/Core/Adapter.lua` (`EquippedItemLevel`, `HasPawn`, optional check), `SwagBag/Core/Config.lua` (`bags.showIlvl`, `overlays`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/mock_adapter.lua`, `spec/adapter_spec.lua`, `spec/bagswindow_spec.lua`, `spec/overlays_spec.lua` (new), `spec/bagswindow_sections_spec.lua`

**Interfaces:**
- Consumes:
  - Task 3: `SB.OverlayData.For`, `SB.Adapter.EquippedItems/CanUse/DungeonName/PawnUpgrade`, records' `track` and `hasNoValue`;
  - on `main`: `SB.BagsWindow.ForEachSlot` (`fn(button, record, bag, slot)`), `SB.BagsWindow.Flash`, `SB.On`, `SB.Debounce`, `SB.Slash.Register`, `SB.Adapter.BagKind`.
- Produces:
  - `SB.Overlays.Apply(button, record, bag)`, `.RefreshAll()` (the open bags window; Task 11 adds the bank and guild windows), `.Context()`, `.regions[button]` (`topLeft`, `bottomLeft`, `bind`, `arrow`, `junk`, `reagent`).
  - `SB.Adapter.EquippedItemLevel() -> number | nil` and `SB.Adapter.HasPawn() -> bool`.
  - `SB.BagsWindow.Title() -> text` and `SB.BagsWindow.RefreshTitle()` (does nothing while a flash shows).
  - Settings `bags.showIlvl` and `overlays.*`. Slash command `overlays` (names `ilvl`, `track`, `upgrade`, `keystone`, `junk`, `bind`, `pawn`, `title`).

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T4 s01 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
	end

	function m.PawnUpgrade(bag, slot)
		if m.pawn == nil then
```

and replace it with:

```lua
	end

	-- m.avgIlvl: the average equipped item level (nil = the client gives none).
	function m.EquippedItemLevel()
		return m.avgIlvl
	end

	function m.HasPawn()
		return m.pawn ~= nil
	end

	function m.PawnUpgrade(bag, slot)
		if m.pawn == nil then
```

<!-- sbw3:edit T4 s02 spec/adapter_spec.lua -->
In `spec/adapter_spec.lua`, find:

```lua
-- luacheck: globals GetCursorInfo ClearCursor C_Container
-- The REAL Adapter.lua (not the mock): cursor and sort helpers added in week 2.
describe("Adapter cursor and sort helpers", function()
```

and replace it with:

```lua
-- luacheck: globals GetCursorInfo ClearCursor C_Container GetAverageItemLevel
-- The REAL Adapter.lua (not the mock): cursor and sort helpers added in week 2.
describe("Adapter cursor and sort helpers", function()
```

<!-- sbw3:edit T4 s03 spec/adapter_spec.lua -->
In `spec/adapter_spec.lua`, find:

```lua

	after_each(function()
		GetCursorInfo, ClearCursor, C_Container = nil, nil, nil
	end)

```

and replace it with:

```lua

	after_each(function()
		GetCursorInfo, ClearCursor, C_Container, GetAverageItemLevel = nil, nil, nil, nil
	end)

```

<!-- sbw3:edit T4 s04 spec/adapter_spec.lua -->
In `spec/adapter_spec.lua`, find:

```lua
		assert.truthy(err)
	end)
end)
```

and replace it with:

```lua
		assert.truthy(err)
	end)

	it("EquippedItemLevel is GetAverageItemLevel's equipped value, and nil without the API or on an error", function()
		assert.is_nil(A.EquippedItemLevel())
		GetAverageItemLevel = function() return 285.5, 279.44, 270 end
		assert.equal(279.44, A.EquippedItemLevel())
		GetAverageItemLevel = function() return 285.5 end
		assert.is_nil(A.EquippedItemLevel())
		GetAverageItemLevel = function() error("boom") end
		assert.is_nil(A.EquippedItemLevel())
	end)
end)
```

<!-- sbw3:edit T4 s05 spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
```

and replace it with:

```lua
local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/OverlayData.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
```

<!-- sbw3:edit T4 s06 spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
```

and replace it with:

```lua
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Overlays.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
```

<!-- sbw3:edit T4 s07 spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
		assert.equal("- New (1)", header("new").text.text)
		assert.equal(0, #B.placeholders, "it came from Free: no placeholder")
	end)

```

and replace it with:

```lua
		assert.equal("- New (1)", header("new").text.text)
		assert.equal(0, #B.placeholders, "it came from Free: no placeholder")
	end)

	it("bag items get their overlays; an empty reagent-bag slot is tinted in Free", function()
		A.SetBagSize(5, 2)
		SB.Inventory.ScanAll()
		W.Open()
		local ring = SB.Overlays.regions[B.Get(0, 3)]
		assert.same({ "285", "BoE" }, { ring.topLeft.text, ring.bind.text })
		assert.truthy(SB.Overlays.regions[B.Get(5, 1)].reagent.shown)
		assert.is_nil(SB.Overlays.regions[B.Get(0, 16)], "an ordinary empty slot gets nothing")
		A.Clear(0, 3)
		bagUpdate()
		assert.equal("", ring.topLeft.text, "the emptied slot's overlays are cleared")
	end)

	it("an item whose data loads while open gets its overlays at once (it moves only on the next open)", function()
		W.Open()
		A.Put(0, 10, Fixtures.UNLOADED, 1)
		bagUpdate()
		assert.equal("", SB.Overlays.regions[B.Get(0, 10)].topLeft.text)
		A.items[Fixtures.UNLOADED] = { name = "Robe", classID = A.ITEM_CLASS.Armor, subclassID = 0, quality = 3,
			equipLoc = "INVTYPE_CHEST", ilvl = 280, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		assert.equal("280", SB.Overlays.regions[B.Get(0, 10)].topLeft.text)
	end)

```

<!-- sbw3:edit T4 s08 spec/bagswindow_spec.lua -->
In `spec/bagswindow_spec.lua`, find:

```lua
	end)

	it("Ctrl+wheel changes the scale and plain wheel scrolls", function()
		A.sizes[0] = 160
```

and replace it with:

```lua
	end)

	it("the title shows the average equipped item level with one decimal (D18)", function()
		A.avgIlvl = 279.44
		W.Open()
		assert.equal("SwagBag — ilvl 279.4", W.frame.title.text)
	end)

	it("the item level in the title follows gear swaps while open, and is read again on open", function()
		A.avgIlvl = 279.44
		W.Open()
		A.avgIlvl = 281.06
		SB.eventFrame:Fire("PLAYER_AVG_ITEM_LEVEL_UPDATE")
		assert.equal("SwagBag — ilvl 281.1", W.frame.title.text)
		A.avgIlvl = 283
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 1)
		assert.equal("SwagBag — ilvl 283.0", W.frame.title.text)
		W.frame:Hide()
		A.avgIlvl = 284.5
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 1)
		assert.equal("SwagBag — ilvl 283.0", W.frame.title.text, "closed: nothing is read")
		W.Open()
		assert.equal("SwagBag — ilvl 284.5", W.frame.title.text)
	end)

	it("a flash keeps the title until it ends, then the item-level title comes back up to date", function()
		A.avgIlvl = 279.44
		W.Open()
		W.SetScale(0.5)
		A.avgIlvl = 280.02
		SB.eventFrame:Fire("PLAYER_AVG_ITEM_LEVEL_UPDATE")
		assert.equal("SwagBag 50%", W.frame.title.text, "the flash is not cut short")
		A.Advance(1.5)
		assert.equal("SwagBag — ilvl 280.0", W.frame.title.text)
	end)

	it("no item level from the client, or bags.showIlvl off: the plain title, no error", function()
		A.avgIlvl = nil
		W.Open()
		assert.equal("SwagBag", W.frame.title.text)
		SB.eventFrame:Fire("PLAYER_AVG_ITEM_LEVEL_UPDATE")
		assert.equal("SwagBag", W.frame.title.text)
		assert.equal(0, #SB.ErrorTrap.Recent())
		A.avgIlvl = 279.44
		SB.Config.Set("bags.showIlvl", false)
		W.RefreshTitle()
		assert.equal("SwagBag", W.frame.title.text)
	end)

	it("Ctrl+wheel changes the scale and plain wheel scrolls", function()
		A.sizes[0] = 160
```

<!-- sbw3:file T4 s09 spec/overlays_spec.lua -->
Create `spec/overlays_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Overlays drawn on item buttons (spec F9), with fake buttons; and in the open bags window.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/OverlayData.lua",
}

describe("Overlays (spec F9)", function()
	local SB, A, Ov
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Overlays.lua")
		Ov = SB.Overlays
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function draw(bag, slot)
		local b = Fake.New("ItemButton")
		Ov.Apply(b, SB.Items.Describe(bag, slot), bag)
		return b, Ov.regions[b]
	end

	it("gear: item level top left, track bottom left, BoE badge, upgrade arrow", function()
		A.tracks["item:" .. Fixtures.BOE_RING] = { track = "Champion", level = 2, max = 8 }
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 290, equipLoc = "INVTYPE_FINGER" }
		local _, r = draw(0, 3)
		assert.same({ "285", "C2/8", "BoE", true, false },
			{ r.topLeft.text, r.bottomLeft.text, r.bind.text, r.arrow.shown, r.junk.shown })
	end)

	it("a keystone shows +level and its dungeon's short name", function()
		A.dungeons[503] = "Ara-Kara, City of Echoes"
		local _, r = draw(0, 5)
		assert.same({ "+12", "AKCE", "" }, { r.topLeft.text, r.bottomLeft.text, r.bind.text })
	end)

	it("a junk coin on gray items; nothing on a potion", function()
		local _, junk = draw(0, 6)
		assert.truthy(junk.junk.shown)
		local _, potion = draw(0, 1)
		assert.same({ "", "", "", false, false },
			{ potion.topLeft.text, potion.bottomLeft.text, potion.bind.text, potion.arrow.shown, potion.junk.shown })
	end)

	it("a slot that empties clears its overlays; an empty slot that never had an item makes no regions", function()
		local b = draw(0, 3)
		Ov.Apply(b, nil, 0)
		local r = Ov.regions[b]
		assert.same({ "", "", false }, { r.topLeft.text, r.bind.text, r.arrow.shown })
		local empty = Fake.New("ItemButton")
		Ov.Apply(empty, nil, 0)
		assert.is_nil(Ov.regions[empty])
	end)

	it("an empty reagent-bag slot is tinted so it stands out in Free; an item there is not", function()
		A.SetBagSize(5, 4)
		local b = Fake.New("ItemButton")
		Ov.Apply(b, nil, 5)
		assert.truthy(Ov.regions[b].reagent.shown)
		A.Put(5, 1, Fixtures.HERB, 5)
		Ov.Apply(b, SB.Items.Describe(5, 1), 5)
		assert.falsy(Ov.regions[b].reagent.shown)
		local other = Fake.New("ItemButton")
		Ov.Apply(other, SB.Items.Describe(0, 1), 0)
		Ov.Apply(other, nil, 0)
		assert.falsy(Ov.regions[other].reagent.shown)
	end)

	it("each overlay has its own switch; /swagbag overlays lists and switches them", function()
		SB.Config.Set("overlays.ilvl", false)
		local _, r = draw(0, 3)
		assert.equal("", r.topLeft.text)
		assert.equal("BoE", r.bind.text)
		SB.Slash.Dispatch("overlays bind off")
		SB.Slash.Dispatch("overlays")
		SB.Slash.Dispatch("overlays sparkles on")
		assert.same({ "Overlay bind is now off.",
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, pawn off, title on",
			SB.L.OVERLAYS_USAGE }, A.Lines())
		assert.equal(false, SB.Config.Get("overlays.bind"))
	end)

	it("a gear change re-draws the arrows of the open windows, once after the last slot event", function()
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		local b, r = draw(0, 3)
		assert.truthy(r.arrow.shown)
		local record = SB.Items.Describe(0, 3)
		local passes = 0
		SB.BagsWindow = { IsOpen = function() return true end,
			ForEachSlot = function(fn) passes = passes + 1 fn(b, record, 0, 3) end }
		A.equipped[11] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 11)
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 12)
		assert.truthy(r.arrow.shown, "not yet")
		A.Advance(0.1)
		assert.falsy(r.arrow.shown)
		assert.equal(1, passes)
	end)

	it("with Use Pawn, Pawn decides the arrow for bag items", function()
		A.equipped[11] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.pawn = { ["0:3"] = true }
		SB.Slash.Dispatch("overlays pawn on")
		local _, r = draw(0, 3)
		assert.truthy(r.arrow.shown, "Pawn says upgrade, although 285 does not beat 300")
		assert.same({ "Overlay pawn is now on." }, A.Lines())
		A.pawn = nil
		A.printed = {}
		SB.Slash.Dispatch("overlays pawn on")
		assert.same({ "Overlay pawn is now on.", SB.L.OVERLAYS_NO_PAWN }, A.Lines())
	end)

	it("/swagbag overlays title off switches the item level in the bags title off at once", function()
		local refreshed = 0
		SB.BagsWindow = { IsOpen = function() return false end, RefreshTitle = function() refreshed = refreshed + 1 end }
		SB.Slash.Dispatch("overlays title off")
		assert.equal(false, SB.Config.Get("bags.showIlvl"))
		assert.equal(1, refreshed)
		assert.same({ "Overlay title is now off." }, A.Lines())
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/adapter_spec.lua spec/bagswindow_sections_spec.lua spec/bagswindow_spec.lua spec/overlays_spec.lua`
Expected: `16 passed, 70 failed`. `UI/Overlays.lua` does not exist yet, so every `overlays_spec` test, and every `bagswindow_sections_spec` test except the load-order one, fails to load. The four title tests in `bagswindow_spec` and the `EquippedItemLevel` test in `adapter_spec` fail because `W.Title`, `W.RefreshTitle` and `Adapter.EquippedItemLevel` do not exist yet.

Critical tests and the mutation that must make each fail:
- `overlays_spec` "a slot that empties clears its overlays; an empty slot that never had an item makes no regions": delete the early return for empty slots in `Ov.Apply`.
- `overlays_spec` "a gear change re-draws the arrows of the open windows, once after the last slot event": delete `Ov.context = nil` in the `PLAYER_EQUIPMENT_CHANGED` handler.
- `overlays_spec` "an empty reagent-bag slot is tinted…": `show(r.reagent, record == nil)`.
- `overlays_spec` "/swagbag overlays title off switches the item level in the bags title off at once": delete `title = "bags.showIlvl"` from `SETTING`.
- `bagswindow_sections_spec` "an item whose data loads while open gets its overlays at once…": delete `overlay(bag, slot)` in `refreshRecord`.
- `bagswindow_spec` "the title shows the average equipped item level with one decimal (D18)": `return L.BAGS_TITLE` instead of `return L.BAGS_TITLE_ILVL:format(ilvl)` in `W.Title`.
- `bagswindow_spec` "the item level in the title follows gear swaps while open…": delete the `SB.On("PLAYER_AVG_ITEM_LEVEL_UPDATE", …)` line.
- `bagswindow_spec` "a flash keeps the title until it ends, then the item-level title comes back up to date": `if true then` instead of `if not flashing then` in `W.RefreshTitle`; or `frame.title:SetText(L.BAGS_TITLE)` instead of `frame.title:SetText(W.Title())` when the flash ends.
- `bagswindow_spec` "no item level from the client, or bags.showIlvl off: the plain title, no error": `if true then` instead of `if ilvl then` in `W.Title` (the format errors on nil).
- `adapter_spec` "EquippedItemLevel is GetAverageItemLevel's equipped value…": `local ok, equipped = pcall(fn)` (the overall value instead of the equipped one).

- [ ] **Step 3: Implement**

<!-- sbw3:edit T4 i01 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
UI/GuildButtons.lua
UI/GuildBankWindow.lua
UI/DebugV1.lua

```

and replace it with:

```text
UI/GuildButtons.lua
UI/GuildBankWindow.lua
UI/Overlays.lua
UI/DebugV1.lua

```

<!-- sbw3:edit T4 i02 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
end

-- Pawn's verdict for a bag item: true / false, or nil without Pawn (spec AC9.3).
function A.PawnUpgrade(bag, slot)
```

and replace it with:

```lua
end

-- Average item level of what the character wears (GetAverageItemLevel's second value), or
-- nil when the client lacks the function or gives no number (spec addition D18).
function A.EquippedItemLevel()
	local fn = _G.GetAverageItemLevel
	if type(fn) ~= "function" then
		return nil
	end
	local ok, _, equipped = pcall(fn)
	if not ok or type(equipped) ~= "number" or isSecret(equipped) then
		return nil
	end
	return equipped
end

function A.HasPawn()
	return type(_G.PawnIsContainerItemAnUpgrade) == "function"
end

-- Pawn's verdict for a bag item: true / false, or nil without Pawn (spec AC9.3).
function A.PawnUpgrade(bag, slot)
```

<!-- sbw3:edit T4 i03 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
	{ path = "C_PlayerInfo.CanUseItem", window = "bags", required = false },
	{ path = "GetInventoryItemLink", window = "bags", required = false },
	{ path = "C_RestrictedActions.IsAddOnRestrictionActive", window = "bags", required = false },
	{ path = "GetGuildBankItemInfo", window = "bank", required = false },
```

and replace it with:

```lua
	{ path = "C_PlayerInfo.CanUseItem", window = "bags", required = false },
	{ path = "GetInventoryItemLink", window = "bags", required = false },
	{ path = "GetAverageItemLevel", window = "bags", required = false },
	{ path = "C_RestrictedActions.IsAddOnRestrictionActive", window = "bags", required = false },
	{ path = "GetGuildBankItemInfo", window = "bank", required = false },
```

<!-- sbw3:edit T4 i04 SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
	settings = {
		-- view: "sections" (category view) | "grid"; newRows: rows kept for New while open;
		-- reagentSeparate: show the reagent bag as its own "Reagents" section (spec AC1.4).
		bags = { columns = 12, scale = 1.0, view = "sections", newRows = 2, reagentSeparate = false },
		safeMode = { bags = false, bank = false },
		-- blizzardFrame: "tiny" (Blizzard's bank invisible, its tabs on SwagBag's window) |
```

and replace it with:

```lua
	settings = {
		-- view: "sections" (category view) | "grid"; newRows: rows kept for New while open;
		-- reagentSeparate: show the reagent bag as its own "Reagents" section (spec AC1.4);
		-- showIlvl: the title shows the average equipped item level (plan D18).
		bags = { columns = 12, scale = 1.0, view = "sections", newRows = 2, reagentSeparate = false,
			showIlvl = true },
		safeMode = { bags = false, bank = false },
		-- blizzardFrame: "tiny" (Blizzard's bank invisible, its tabs on SwagBag's window) |
```

<!-- sbw3:edit T4 i05 SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
		-- right-click withdraws from any tab (false: only from the tab Blizzard has selected).
		guildBank = { mode = "full", withdrawAnyTab = true },
	},
}
```

and replace it with:

```lua
		-- right-click withdraws from any tab (false: only from the tab Blizzard has selected).
		guildBank = { mode = "full", withdrawAnyTab = true },
		-- Overlays on item buttons (spec F9); usePawn: Pawn decides the upgrade arrow.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = true,
			usePawn = false },
	},
}
```

<!-- sbw3:edit T4 i06 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.BAGS_TITLE = "SwagBag"
L.BAGS_SCALE = "SwagBag %d%%"
L.VIEW_TO_GRID = "Grid"
L.VIEW_TO_SECTIONS = "Categories"
```

and replace it with:

```lua
L.BAGS_TITLE = "SwagBag"
L.BAGS_SCALE = "SwagBag %d%%"
L.BAGS_TITLE_ILVL = "SwagBag — ilvl %.1f"
L.VIEW_TO_GRID = "Grid"
L.VIEW_TO_SECTIONS = "Categories"
```

<!-- sbw3:edit T4 i07 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.BADGE_BOE = "BoE"
L.BADGE_WUE = "WuE"

-- In-game check V1 (optional)
```

and replace it with:

```lua
L.BADGE_BOE = "BoE"
L.BADGE_WUE = "WuE"
L.OVERLAY_KEYSTONE = "+%d"
L.OVERLAY_ON = "on"
L.OVERLAY_OFF = "off"
L.HELP_OVERLAYS = "overlays [name on|off]: list or switch item overlays (ilvl, track, upgrade, keystone, junk, bind, pawn)"
	.. " and the item level in the bags title (title)"
L.OVERLAYS_STATE = "Overlays: %s"
L.OVERLAYS_SET = "Overlay %s is now %s."
L.OVERLAYS_USAGE = "Use /swagbag overlays, or /swagbag overlays <ilvl|track|upgrade|keystone|junk|bind|pawn|title> <on|off>."
L.OVERLAYS_NO_PAWN = "Pawn is not loaded, so the item-level rule still decides the upgrade arrow."

-- In-game check V1 (optional)
```

<!-- sbw3:edit T4 i08 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
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
```

and replace it with:

```lua
---------------------------------------------------------------------------
local titleToken = 0
local flashing = false

-- The title at rest: "SwagBag — ilvl 279.4" (the average item level the character wears,
-- one decimal) while bags.showIlvl is on and the client answers; otherwise "SwagBag" (D18).
function W.Title()
	if SB.Config.Get("bags.showIlvl") then
		local ilvl = SB.Adapter.EquippedItemLevel()
		if ilvl then
			return L.BAGS_TITLE_ILVL:format(ilvl)
		end
	end
	return L.BAGS_TITLE
end

-- Shows the resting title, unless a flash is up (the flash puts the resting title back).
function W.RefreshTitle()
	if not flashing then
		frame.title:SetText(W.Title())
	end
end

-- Show text in the title for 1.5 s (feedback for header buttons and scaling, P2), then
-- the resting title.
function W.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	flashing = true
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("bags.flash", function()
		if token == titleToken then
			flashing = false
			frame.title:SetText(W.Title())
		end
	end, "bags"))
end

-- A gear swap changes the item level in the title. SB.On skips an event the client does
-- not know, so a missing PLAYER_AVG_ITEM_LEVEL_UPDATE costs nothing.
local function itemLevelChanged()
	if frame:IsShown() then
		W.RefreshTitle()
	end
end
SB.On("PLAYER_EQUIPMENT_CHANGED", itemLevelChanged, "bags")
SB.On("PLAYER_AVG_ITEM_LEVEL_UPDATE", itemLevelChanged, "bags")

function W.RestorePosition()
```

<!-- sbw3:edit T4 i09 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
end

local function describe(bag, slot)
	W.records[bag] = W.records[bag] or {}
```

and replace it with:

```lua
end

-- Overlays (spec F9) follow the record; an empty reagent-bag slot gets its Free cue.
local function overlay(bag, slot)
	if SB.Overlays then
		SB.Overlays.Apply(SB.Buttons.Get(bag, slot), W.records[bag] and W.records[bag][slot], bag)
	end
end

local function describe(bag, slot)
	W.records[bag] = W.records[bag] or {}
```

<!-- sbw3:edit T4 i10 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	end
	W.records[bag][slot] = record
	return record
end
```

and replace it with:

```lua
	end
	W.records[bag][slot] = record
	overlay(bag, slot)
	return record
end
```

<!-- sbw3:edit T4 i11 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
		fresh.icon = fresh.icon or old.icon
		W.records[bag][slot] = fresh
	end
end
```

and replace it with:

```lua
		fresh.icon = fresh.icon or old.icon
		W.records[bag][slot] = fresh
		overlay(bag, slot)
	end
end
```

<!-- sbw3:edit T4 i12 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	W.sortPending, W.sortSawUpdate = false, false
	W.viewButton:SetText(W.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	frame:Show()
	W.Layout("open")
```

and replace it with:

```lua
	W.sortPending, W.sortSawUpdate = false, false
	W.viewButton:SetText(W.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	W.RefreshTitle()
	frame:Show()
	W.Layout("open")
```

<!-- sbw3:file T4 i13 SwagBag/UI/Overlays.lua -->
Create `SwagBag/UI/Overlays.lua`:

```lua
-- SwagBag overlays (spec F9). Draws Engine/OverlayData.lua's result on an item button:
--   top left      item level, or "+12" on a keystone          (overlays.ilvl / .keystone)
--   bottom left   upgrade track "H3/6", or the keystone's dungeon (overlays.track / .keystone)
--   left          "BoE" / "WuE" until the item is bound          (overlays.bind)
--   top right     green upgrade arrow (AC9.3)                     (overlays.upgrade)
--   top left      junk coin on gray items a vendor pays for       (overlays.junk)
-- The stack count is Blizzard's own (SetItemButtonCount). overlays.usePawn hands the arrow
-- to Pawn's PawnIsContainerItemAnUpgrade for bag and bank items.
-- An empty reagent-bag slot gets a faint green tint, so in Free it is clear which empty slots
-- take reagents only (the week-2 "reagent-bag empties in Free" cue).
-- Regions are font strings and textures on the button itself (no frames: allowed in combat),
-- made the first time a button needs one, in its OVERLAY layer, so dimming the button dims
-- them too. What the character wears is read once and kept until PLAYER_EQUIPMENT_CHANGED,
-- which re-draws the open windows (spec AC9.3).
-- /swagbag overlays also switches the item level in the bags window's title (bags.showIlvl).
--   Overlays.Apply(button, record, bag)   record nil = empty slot
--   Overlays.RefreshAll()                 re-draw the open bags window's buttons
local _, SB = ...

local L = SB.L
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind" } }
SB.Overlays = Ov

local regions = setmetatable({}, { __mode = "k" }) -- [button] = its overlay regions
Ov.regions = regions

local function text(button, point, x, y)
	local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	fs:SetPoint(point, button, point, x, y)
	return fs
end

-- A texture with an atlas, or a plain colour when the atlas is missing.
local function texture(button, sublevel, atlas, r, g, b, a)
	local t = button:CreateTexture(nil, "OVERLAY", nil, sublevel)
	local ok, set = pcall(t.SetAtlas, t, atlas)
	if not (ok and set ~= false) then
		t:SetColorTexture(r, g, b, a)
	end
	t:Hide()
	return t
end

local function regionsFor(button)
	local r = regions[button]
	if not r then
		r = {
			topLeft = text(button, "TOPLEFT", 2, -2),
			bottomLeft = text(button, "BOTTOMLEFT", 2, 2),
			bind = text(button, "LEFT", 2, 0),
			arrow = texture(button, 7, "bags-greenarrow", 0.2, 1, 0.2, 0.9),
			junk = texture(button, 7, "bags-junkcoin", 1, 0.85, 0.1, 0.9),
			reagent = texture(button, 6, "", 0.2, 0.75, 0.35, 0.18),
		}
		r.arrow:SetSize(14, 14)
		r.arrow:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
		r.junk:SetSize(12, 12)
		r.junk:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		r.reagent:SetAllPoints(button)
		regions[button] = r
	end
	return r
end

-- What the character wears and can use; kept until the equipment changes.
function Ov.Context()
	if not Ov.context then
		local A = SB.Adapter
		local ctx = { equipped = A.EquippedItems(), canUse = A.CanUse, dungeonName = A.DungeonName }
		if SB.Config.Get("overlays.usePawn") then
			ctx.pawn = function(record)
				if record.bag and A.BagKind(record.bag) then -- bag and bank slots; not the guild bank
					return A.PawnUpgrade(record.bag, record.slot)
				end
				return nil
			end
		end
		Ov.context = ctx
	end
	return Ov.context
end

local function on(name)
	return SB.Config.Get("overlays." .. name) == true
end

local function show(region, yes)
	if yes then
		region:Show()
	else
		region:Hide()
	end
end

function Ov.Apply(button, record, bag)
	if not button then
		return
	end
	local reagentEmpty = record == nil and bag ~= nil and SB.Adapter.BagKind(bag) == "reagentbag"
	if not regions[button] and record == nil and not reagentEmpty then
		return -- an empty slot that never showed anything: no regions needed
	end
	local r = regionsFor(button)
	local d = SB.OverlayData.For(record, Ov.Context())
	local top = (on("ilvl") and d.ilvl and tostring(d.ilvl))
		or (on("keystone") and d.keystone and L.OVERLAY_KEYSTONE:format(d.keystone.level)) or ""
	local bottom = (on("track") and d.track) or (on("keystone") and d.keystone and d.keystone.dungeon) or ""
	r.topLeft:SetText(top)
	r.bottomLeft:SetText(bottom)
	r.bind:SetText(on("bind") and d.bind or "")
	show(r.arrow, on("upgrade") and d.upgrade)
	show(r.junk, on("junk") and d.junk and top == "")
	show(r.reagent, reagentEmpty)
end

-- Re-draw the buttons of the open bags window (equipment or settings changed).
function Ov.RefreshAll()
	local function each(fn)
		fn(function(button, record, bag)
			Ov.Apply(button, record, bag)
		end)
	end
	local bags = SB.BagsWindow
	if bags and bags.IsOpen() then
		each(bags.ForEachSlot)
	end
end

-- A gear swap fires one event per slot: re-draw once, after the last one.
SB.On("PLAYER_EQUIPMENT_CHANGED", function()
	Ov.context = nil
	SB.Debounce("overlays.equipment", 0.1, Ov.RefreshAll, "none")
end, "none")

-- The setting behind each name /swagbag overlays knows (plain names are overlays.<name>).
local SETTING = { pawn = "overlays.usePawn", title = "bags.showIlvl" }

local function path(name)
	return SETTING[name] or ("overlays." .. name)
end

local function state(name)
	return SB.Config.Get(path(name)) and L.OVERLAY_ON or L.OVERLAY_OFF
end

-- /swagbag overlays              list every overlay and whether it is on
-- /swagbag overlays <name> on|off  switch one (pawn: let Pawn decide the arrow;
--                                  title: the item level in the bags window's title)
SB.Slash.Register("overlays", L.HELP_OVERLAYS, function(arg)
	local name, value = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	local names = { "ilvl", "track", "upgrade", "keystone", "junk", "bind", "pawn", "title" }
	if name == "" then
		local parts = {}
		for _, n in ipairs(names) do
			parts[#parts + 1] = n .. " " .. state(n)
		end
		return L.OVERLAYS_STATE:format(table.concat(parts, ", "))
	end
	local known = false
	for _, n in ipairs(names) do
		known = known or n == name
	end
	if not known or (value ~= "on" and value ~= "off") then
		return L.OVERLAYS_USAGE
	end
	if not SB.Config.Set(path(name), value == "on") then
		return L.SETTINGS_READONLY
	end
	Ov.context = nil
	Ov.RefreshAll()
	if SB.BagsWindow then
		SB.BagsWindow.RefreshTitle()
	end
	local line = L.OVERLAYS_SET:format(name, state(name))
	if name == "pawn" and value == "on" and not SB.Adapter.HasPawn() then
		return { line, L.OVERLAYS_NO_PAWN }
	end
	return line
end)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/adapter_spec.lua spec/bagswindow_sections_spec.lua spec/bagswindow_spec.lua spec/overlays_spec.lua`
Expected: `86 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (39 files)`, `506 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/mock_adapter.lua \
  spec/adapter_spec.lua \
  spec/bagswindow_sections_spec.lua \
  spec/bagswindow_spec.lua \
  spec/overlays_spec.lua \
  SwagBag/SwagBag.toc \
  SwagBag/Core/Adapter.lua \
  SwagBag/Core/Config.lua \
  SwagBag/Locale/enUS.lua \
  SwagBag/UI/BagsWindow.lua \
  SwagBag/UI/Overlays.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 4: overlays on bag buttons, item level in the bags title, Use Pawn, reagent-bag cue, /swagbag overlays" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 7: In-game session O1 (the user does this on Oct 16; about 10 minutes; bags only)**

Give the user this checklist exactly. Carry some gear (one piece better than what you wear, if you have one), your keystone, a gray item and some crafting materials. The bank and guild bank do not show overlays yet; session G2 checks them later in the week.

1. Quit the game completely and start it again (new files). Log in. Press **B**.
2. The bags window's title reads `SwagBag — ilvl` and a number with one decimal, for example `SwagBag — ilvl 279.4`. Press **C**: the character window's item level is the same number (the character window may round it). Press **C** again to close it.
3. Gear shows its item level in the top left corner (for example `285`). Gear with an upgrade track shows it in the bottom left (for example `H3/6`). If **no** gear shows a track, tell Claude: the game's track information may be missing.
4. A BoE item shows `BoE` on its left side, and a warbound-until-equipped item shows `WuE`.
5. Gear that beats what you wear in that slot shows a small green arrow in its top right corner. For rings and trinkets, "what you wear" means the weaker of your two.
6. Equip one item that has an arrow (right-click it). Within a moment its arrow is gone, the piece you took off shows an arrow only if it beats what you now wear, and **the number in the title changes**. Move the mouse off it. (No arrow anywhere? Equip any piece with a different item level than the one it replaces: the number in the title changes all the same. Put your usual piece back afterwards.)
7. Hold **Ctrl** and turn the mouse wheel up one notch over the items. The title says `SwagBag 105%` for a moment, then `SwagBag — ilvl …` again. Turn the wheel down one notch to go back to your size.
8. Click `Reflow`. The title says `Regrouped` for a moment, then `SwagBag — ilvl …` again.
9. Your keystone shows `+` and its level in the top left (for example `+12`) and a short dungeon name in the bottom left.
10. Gray items show a small coin.
11. If you have a reagent bag with empty slots, those empty slots in `Free` have a faint green tint.
12. Type `/swagbag overlays`. Chat says `Overlays: ilvl on, track on, upgrade on, keystone on, junk on, bind on, pawn off, title on`.
13. Type `/swagbag overlays ilvl off`. Chat says `Overlay ilvl is now off.`, and the item levels on the items disappear. Type `/swagbag overlays ilvl on`: they come back.
14. Type `/swagbag overlays title off`. Chat says `Overlay title is now off.`, and the title reads just `SwagBag`. Type `/swagbag overlays title on`: the item level is back in the title.
15. If you use Pawn, type `/swagbag overlays pawn on`: the arrows now follow Pawn. Without Pawn, chat says `Overlay pawn is now on.` and `Pawn is not loaded, so the item-level rule still decides the upgrade arrow.` Either way, type `/swagbag overlays pawn off` afterwards.
16. Every crest or valorstone item you carry is in `Keystone & Crests`. If one is somewhere else, drop it on the `Keystone & Crests` header and tell Claude its exact name.
17. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks no new errors and `Blocked actions: none`.

Pass: steps 2–16 behave as described. Report every crest name from step 16: Claude adds their item IDs to `Engine/Crests.lua`.

---

### Task 5: Button pool and bags-window fixes from the ledgers (growth, retry, parents, bank tabs, per-window pools, incremental redraw, scale)

The week-1 and week-2 ledgers left these for week 3. Each one matters once the bank window exists:

- **EnsureCapacity growth is "last request wins"** (week-1 ledger, Task 11). Two growth requests for one bag during combat (40, then 20) leave 20. Fix: keep the largest in `Buttons.pendingGrow[bag]`.
- **CreateAll never retries.** A login that errors half-way switches the bags to Safe Mode with `Buttons.created == false`. `/swagbag safe off` then does nothing visible, because `BagsWindow.Open` refuses without the pool. Fix: switching bags Safe Mode off runs `CreateAll` again, and `EnsureCapacity` carries on where it stopped.
- **SetParentFor after creation is a no-op.** Bank bag frames made at login live under a hidden holder, and a later `SetParentFor("bank", child)` never moved them. Fix: it moves the existing **bag frames** of that kind (never the item buttons), out of combat.
- **Bank tabs bought after login get no buttons.** Fix: `Buttons.EnsureBankTabs()` runs at login (inside `CreateAll`) and on every `BANKFRAME_OPENED`.
- **The pools are global** (Review Focus 1). `SectionHeaders.ReleaseAll()` and `Buttons.ReleasePlaceholders()` release every window's frames, so a bags redraw would wipe the bank window's headers. Fix: both take the parent frame and release only frames acquired in it. `SectionHeaders.Acquire` takes an optional owner `{ onClick, onDrop }`, so the bank's headers do not call the bags window's click handler. Owners and parents are kept in side tables, not in fields on the frames.
- **ApplyChanges redraws every cell** (week-2 final review: "make render incremental for 1,290 slots"). Fix: `renderMoved(oldPos, newPos)` touches only the buttons whose cell changed (`Layout.Moves`), plus the placeholders and headers. The test allows 4 button lookups for one change: the changed slot's repaint, its overlay (Task 4) and the one button that moved.
- **A cell whose slot is past the bag's size can be shown again** while its "removed" change is held back (week-2 Task 10 minor). Fix: `render` and `renderMoved` never show such a cell, and search skips it.
- **The window jumps on reopen after Ctrl+wheel** (week-2 final residual). Fix: `W.SetScale` saves the new corner at once. A test covers a second notch from 120 %.
- **No re-anchoring during a drag** (same residual). While `W.dragging` is true, neither a scale change nor a resize calls `SetPoint`. The drop saves the corner.

**Files:**
- Modify: `SwagBag/UI/Buttons.lua`, `SwagBag/UI/SectionHeaders.lua`, `SwagBag/UI/BagsWindow.lua`
- Test: `spec/buttons_spec.lua`, `spec/bagswindow_sections_spec.lua`

**Interfaces:**
- Consumes: `SB.Layout.Moves` (on `main`), `spec/helpers/fakeframe.lua` (Task 1), `SB.Overlays.Apply` (Task 4; the bags window already calls it).
- Produces:
  - `SB.Buttons.pendingGrow[bag]`, `SB.Buttons.EnsureBankTabs()`.
  - `SB.Buttons.SetParentFor(kind, frame)` now moves existing bag frames of that kind.
  - `SB.Buttons.ReleasePlaceholders(parent)` (nil = all).
  - `SB.SectionHeaders.Acquire(parent, sectionId, label, x, y, width, owner)` (owner = `{ onClick(id), onDrop(id) }`, optional) and `SB.SectionHeaders.ReleaseAll(parent)` (nil = all).
  - `SB.BagsWindow.dragging`.
  - Every window must pass its own scroll child to both release calls (Tasks 7, 8, 10 do).

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T5 s01 spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
	end)

	it("Ctrl+wheel scaling only resizes; it does not regroup", function()
		W.Open()
```

and replace it with:

```lua
	end)

	it("a Ctrl+wheel scale change saves the new corner; a second notch from 120 % keeps it on screen", function()
		SB.Config.Set("bags.scale", 1.2)
		SB.Config.UI().positions.bags = { "TOPLEFT", "BOTTOMLEFT", 100, 900 }
		W.Open()
		IsControlKeyDown = function() return true end
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		assert.truthy(math.abs(SB.Config.Get("bags.scale") - 1.3) < 1e-9)
		local saved = SB.Config.UI().positions.bags
		assert.equal("TOPLEFT", saved[1])
		assert.truthy(math.abs(saved[3] * 1.3 - 100 * 1.2) < 1e-6 and math.abs(saved[4] * 1.3 - 900 * 1.2) < 1e-6,
			"the saved corner is the same screen spot, in the new scale")
		W.Close()
		W.Open()
		local p = W.frame.points[1]
		assert.same({ "TOPLEFT", "BOTTOMLEFT" }, { p[1], p[3] })
		assert.truthy(math.abs(p[4] * 1.3 - 120) < 1e-6, "a reopen lands where the window was")
	end)

	it("while the window is dragged a scale change does not re-anchor it; the drop saves the corner", function()
		SB.Config.UI().positions.bags = { "TOPLEFT", "BOTTOMLEFT", 100, 900 }
		W.Open()
		W.frame.scripts.OnDragStart(W.frame)
		local setPoints, realSetPoint = 0, W.frame.SetPoint
		W.frame.SetPoint = function(self, ...)
			setPoints = setPoints + 1
			return realSetPoint(self, ...)
		end
		IsControlKeyDown = function() return true end
		W.scroll.scripts.OnMouseWheel(W.scroll, 1)
		assert.equal(1.05, W.frame.scale)
		assert.equal(0, setPoints, "no SetPoint during the drag")
		W.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 300, 700) -- where the client moved it
		W.frame.scripts.OnDragStop(W.frame)
		assert.same({ "TOPLEFT", "BOTTOMLEFT", 300, 700 }, SB.Config.UI().positions.bags)
	end)

	it("Ctrl+wheel scaling only resizes; it does not regroup", function()
		W.Open()
```

<!-- sbw3:edit T5 s02 spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
		assert.equal("- New (1)", header("new").text.text)
		assert.equal(0, #B.placeholders, "it came from Free: no placeholder")
	end)

```

and replace it with:

```lua
		assert.equal("- New (1)", header("new").text.text)
		assert.equal(0, #B.placeholders, "it came from Free: no placeholder")
	end)

	it("a live change touches only the moved button's frame, not every slot (incremental render)", function()
		W.Open()
		local gets, realGet = 0, B.Get
		B.Get = function(bag, slot)
			gets = gets + 1
			return realGet(bag, slot)
		end
		A.Clear(0, 1)
		bagUpdate()
		B.Get = realGet
		assert.equal(1, #B.placeholders)
		-- the changed slot's repaint, its overlay and the one button that moved
		assert.truthy(gets <= 4, "Buttons.Get called " .. gets .. " times for one change in 16 slots")
		assert.equal(16, #W.cells, "search still sees every slot")
	end)

	it("a slot past the bag's size is never shown again while its removal is held back", function()
		A.SetBagSize(1, 4)
		SB.Inventory.ScanAll()
		W.Open()
		A.cursor = { itemID = Fixtures.FLASK } -- holds every move
		A.SetBagSize(1, 0)
		bagUpdate(1)
		assert.equal(4, #W.state.deferred, "the removals wait")
		W.Render()
		for slot = 1, 4 do
			assert.falsy(B.Get(1, slot).shown, "slot " .. slot)
		end
		assert.equal(16, #W.cells, "only the backpack is searchable")
		A.cursor = nil
		A.Advance(0.3)
		assert.equal(0, #W.state.deferred)
		assert.falsy(B.Get(1, 4).shown)
	end)

```

<!-- sbw3:edit T5 s03 spec/buttons_spec.lua -->
In `spec/buttons_spec.lua`, find:

```lua
		assert.equal(B, h.calls.SetParent[1])
	end)
end)
```

and replace it with:

```lua
		assert.equal(B, h.calls.SetParent[1])
	end)
end)

describe("Button pool growth, parents and bank tabs (week-1 ledger)", function()
	local Fake = dofile("spec/helpers/fakeframe.lua")
	local SB, A, B
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		B = SB.Buttons
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	it("growth asked for during combat keeps the largest request, in either order", function()
		A.combat = true
		B.EnsureCapacity(0, 40)
		B.EnsureCapacity(0, 20)
		B.EnsureCapacity(1, 12)
		B.EnsureCapacity(1, 30)
		assert.equal(0, B.Count(0), "nothing is created in combat")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(40, B.Count(0))
		assert.equal(30, B.Count(1))
	end)

	it("a login that failed half-way creates the rest when bags Safe Mode is switched off", function()
		A.SetBagSize(0, 16)
		local made = 0
		CreateFrame = function(kind, ...)
			if kind == "ItemButton" then
				made = made + 1
				if made == 50 then
					error("client hiccup")
				end
			end
			return Fake.CreateFrame(kind, ...)
		end
		SB.Emit("SB_LOGIN")
		assert.falsy(B.created)
		assert.truthy(SB.SafeMode.IsOn("bags"))
		CreateFrame = Fake.CreateFrame
		SB.SafeMode.Disable("bags")
		assert.truthy(B.created)
		for bag = 0, 5 do
			assert.equal(38, B.Count(bag), "bag " .. bag)
		end
	end)

	it("SetParentFor moves bag frames made earlier onto the new parent; their buttons stay on them", function()
		B.EnsureCapacity(6, 2)
		B.EnsureCapacity(0, 1)
		local holder, bagsParent = B.frames[6].parent, B.frames[0].parent
		local child = Fake.New("Frame")
		B.SetParentFor("bank", child)
		assert.equal(child, B.frames[6].parent)
		assert.equal(child, B.frames[6].allPoints)
		assert.equal(B.frames[6], B.Get(6, 1).parent, "the item button was not reparented")
		assert.equal(bagsParent, B.frames[0].parent, "other kinds are untouched")
		assert.truthy(holder ~= child)
	end)

	it("SetParentFor in combat moves the bag frames when combat ends", function()
		B.EnsureCapacity(12, 1)
		local child = Fake.New("Frame")
		A.combat = true
		B.SetParentFor("warband", child)
		assert.truthy(B.frames[12].parent ~= child)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(child, B.frames[12].parent)
	end)

	it("a bank tab bought after login gets its 98 buttons when the bank opens", function()
		A.bagIDs.bank = { 6 }
		SB.Emit("SB_LOGIN")
		assert.equal(98, B.Count(6))
		assert.equal(0, B.Count(7))
		A.bagIDs.bank = { 6, 7 }
		A.SetBagSize(7, 98)
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.equal(98, B.Count(7))
		assert.equal(98, B.Count(6), "nothing extra for the old tab")
	end)

	it("ReleasePlaceholders(parent) releases only the placeholders inside that parent", function()
		local bagsChild, bankChild = Fake.New("Frame"), Fake.New("Frame")
		local a = B.AcquirePlaceholder(bagsChild, 1, 37, 0, 0)
		local b = B.AcquirePlaceholder(bankChild, 2, 37, 0, 0)
		B.ReleasePlaceholders(bagsChild)
		assert.falsy(a.shown)
		assert.truthy(b.shown)
		assert.same({ b }, B.placeholdersInUse)
		B.ReleasePlaceholders()
		assert.falsy(b.shown)
	end)
end)

describe("Section headers per window", function()
	local Fake = dofile("spec/helpers/fakeframe.lua")
	local SB, H
	before_each(function()
		SB = Loader.New(FILES)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		H = SB.SectionHeaders
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	it("an owner's onClick and onDrop handle its headers; headers without an owner use the bags window's", function()
		local bagsClicks, bankClicks, bankDrops = {}, {}, {}
		H.onClick = function(id) bagsClicks[#bagsClicks + 1] = id end
		local owner = { onClick = function(id) bankClicks[#bankClicks + 1] = id end,
			onDrop = function(id) bankDrops[#bankDrops + 1] = id end }
		local mine = H.Acquire(Fake.New("Frame"), "bank:c_gear", "x", 0, 0, 10, owner)
		local bags = H.Acquire(Fake.New("Frame"), "c_gear", "x", 0, 0, 10)
		Fake.Fire(mine, "OnClick")
		Fake.Fire(mine, "OnReceiveDrag")
		Fake.Fire(bags, "OnClick")
		assert.same({ "bank:c_gear" }, bankClicks)
		assert.same({ "bank:c_gear" }, bankDrops)
		assert.same({ "c_gear" }, bagsClicks)
	end)

	it("ReleaseAll(parent) releases only that window's headers, and a reused header forgets its owner", function()
		local bagsChild, bankChild = Fake.New("Frame"), Fake.New("Frame")
		local clicks = 0
		local a = H.Acquire(bankChild, "x", "x", 0, 0, 10, { onClick = function() clicks = clicks + 1 end })
		local b = H.Acquire(bagsChild, "y", "y", 0, 0, 10)
		H.ReleaseAll(bankChild)
		assert.falsy(a.shown)
		assert.truthy(b.shown)
		local reused = H.Acquire(bagsChild, "z", "z", 0, 0, 10)
		assert.equal(a, reused)
		Fake.Fire(reused, "OnClick")
		assert.equal(0, clicks, "the old owner is gone")
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/buttons_spec.lua`
Expected: `65 passed, 12 failed`. Each new test fails on the defect it pins.

Critical tests and the mutation that must make each fail:
- "growth asked for during combat keeps the largest request, in either order": `Buttons.pendingGrow[bag] = n`.
- "a login that failed half-way creates the rest when bags Safe Mode is switched off": make the `SB_SAFEMODE_CHANGED` handler's test `if false then`.
- "SetParentFor moves bag frames made earlier onto the new parent…": make its loop's test `if false then`.
- "a bank tab bought after login gets its 98 buttons when the bank opens": remove `Buttons.EnsureBankTabs()` from the `BANKFRAME_OPENED` handler.
- "ReleasePlaceholders(parent) releases only the placeholders inside that parent": `if true then` in the loop.
- "an owner's onClick and onDrop handle its headers…": `local o = H` in the click script.
- "ReleaseAll(parent) releases only that window's headers…": `if true then` in the loop.
- "a Ctrl+wheel scale change saves the new corner; a second notch from 120 %…": delete `savePosition()` in `W.SetScale`.
- "while the window is dragged a scale change does not re-anchor it…": drop `and not W.dragging` in `W.SetScale` or in `sizeFrame`.
- "a live change touches only the moved button's frame, not every slot": use `render()` instead of `renderMoved(oldPos, W.pos)` in `W.ApplyChanges`.
- "a slot past the bag's size is never shown again while its removal is held back": `if c.shown then` in `showAt`.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T5 i01 SwagBag/UI/Buttons.lua -->
In `SwagBag/UI/Buttons.lua`, find:

```lua
Buttons.KindOf = kindOf

-- The bags window registers its scroll child here at load time. Bank kinds get a
-- hidden holder frame until the bank window exists (week 3).
function Buttons.SetParentFor(kind, frame)
	Buttons.parents[kind] = frame
end

```

and replace it with:

```lua
Buttons.KindOf = kindOf

-- Each window registers its scroll child here at load time ("bags"; "bank" and "warband"
-- share the bank window's). A kind without a window gets a hidden holder frame. Bag frames
-- made before the call move to the new parent, out of combat; only the bag frames move,
-- their item buttons stay parented to them (spec 4.1).
function Buttons.SetParentFor(kind, frame)
	Buttons.parents[kind] = frame
	SB.OutOfCombat(function()
		for bag, f in pairs(Buttons.frames) do
			if kindOf(bag) == kind and f:GetParent() ~= frame then
				f:SetParent(frame)
				f:SetAllPoints(frame)
			end
		end
	end, "buttons.parent." .. kind, "bags")
end

```

<!-- sbw3:edit T5 i02 SwagBag/UI/Buttons.lua -->
In `SwagBag/UI/Buttons.lua`, find:

```lua
end

-- Ensure `bag` has at least n buttons. In combat the growth is queued (policy).
function Buttons.EnsureCapacity(bag, n)
	if SB.Adapter.InCombat() then
		SB.OutOfCombat(function()
			Buttons.EnsureCapacity(bag, n)
		end, "buttons.grow." .. bag, "bags")
		return 0
```

and replace it with:

```lua
end

-- Ensure `bag` has at least n buttons. In combat the growth is queued (policy); several
-- requests for one bag during combat keep the largest.
Buttons.pendingGrow = {} -- [bag] = largest size asked for during combat
function Buttons.EnsureCapacity(bag, n)
	if SB.Adapter.InCombat() then
		Buttons.pendingGrow[bag] = math.max(Buttons.pendingGrow[bag] or 0, n)
		SB.OutOfCombat(function()
			local want = Buttons.pendingGrow[bag]
			Buttons.pendingGrow[bag] = nil
			if want then
				Buttons.EnsureCapacity(bag, want)
			end
		end, "buttons.grow." .. bag, "bags")
		return 0
```

<!-- sbw3:edit T5 i03 SwagBag/UI/Buttons.lua -->
In `SwagBag/UI/Buttons.lua`, find:

```lua
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

```

and replace it with:

```lua
		Buttons.EnsureCapacity(bag, math.max(A.NumSlots(bag), A.BAG_CAPACITY))
	end
	Buttons.EnsureBankTabs()
	Buttons.stats.createMs = A.ProfileMs() - t0
	Buttons.created = true
	SB.Emit("SB_BUTTONS_READY")
end

-- Buttons for every purchased bank tab: max(size, 98) per tab (spec 4.1). Runs at login and
-- whenever the bank opens, so a tab bought after login gets its buttons too.
function Buttons.EnsureBankTabs()
	local A = SB.Adapter
	for _, kind in ipairs({ "bank", "warband" }) do
		for _, bag in ipairs(A.GetBagIDs(kind)) do
			local want = math.max(A.NumSlots(bag), A.BANK_TAB_CAPACITY)
			if Buttons.Count(bag) < want then
				Buttons.EnsureCapacity(bag, want)
			end
		end
	end
end

```

<!-- sbw3:edit T5 i04 SwagBag/UI/Buttons.lua -->
In `SwagBag/UI/Buttons.lua`, find:

```lua
---------------------------------------------------------------------------
Buttons.placeholderPool, Buttons.placeholdersInUse = {}, {}
Buttons.PLACEHOLDER_ALPHA = 0.5

```

and replace it with:

```lua
---------------------------------------------------------------------------
Buttons.placeholderPool, Buttons.placeholdersInUse = {}, {}
local placeholderParent = {} -- [placeholder] = the frame it was acquired in
Buttons.PLACEHOLDER_ALPHA = 0.5

```

<!-- sbw3:edit T5 i05 SwagBag/UI/Buttons.lua -->
In `SwagBag/UI/Buttons.lua`, find:

```lua
	local p = table.remove(Buttons.placeholderPool) or createPlaceholder(parent)
	p:SetParent(parent)
	p:SetSize(size, size)
	p.icon:SetTexture(icon)
```

and replace it with:

```lua
	local p = table.remove(Buttons.placeholderPool) or createPlaceholder(parent)
	p:SetParent(parent)
	placeholderParent[p] = parent
	p:SetSize(size, size)
	p.icon:SetTexture(icon)
```

<!-- sbw3:edit T5 i06 SwagBag/UI/Buttons.lua -->
In `SwagBag/UI/Buttons.lua`, find:

```lua
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

and replace it with:

```lua
end

-- Release the placeholders inside parent; every placeholder when parent is nil. Windows pass
-- their own scroll child, so the bags window never releases the bank window's placeholders.
function Buttons.ReleasePlaceholders(parent)
	for i = #Buttons.placeholdersInUse, 1, -1 do
		local p = Buttons.placeholdersInUse[i]
		if parent == nil or placeholderParent[p] == parent then
			p:Hide()
			placeholderParent[p] = nil
			table.remove(Buttons.placeholdersInUse, i)
			Buttons.placeholderPool[#Buttons.placeholderPool + 1] = p
		end
	end
end
```

<!-- sbw3:edit T5 i07 SwagBag/UI/Buttons.lua -->
In `SwagBag/UI/Buttons.lua`, find:

```lua
	Buttons.CreateAll()
end, "bags")
```

and replace it with:

```lua
	Buttons.CreateAll()
end, "bags")

-- A login that failed half-way switched the bags to Safe Mode; switching it off tries again
-- (EnsureCapacity carries on where it stopped).
SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window == "bags" and not on and not Buttons.created then
		Buttons.CreateAll()
	end
end, "bags")

SB.On("BANKFRAME_OPENED", function()
	Buttons.EnsureBankTabs()
end, "bank")
```

<!-- sbw3:edit T5 i08 SwagBag/UI/SectionHeaders.lua -->
In `SwagBag/UI/SectionHeaders.lua`, find:

```lua
--   Headers.onClick(sectionId)  left-click (collapse/expand, or drop the cursor item)
--   Headers.onDrop(sectionId)   an item dragged onto the header (AC4.3)
local _, SB = ...

```

and replace it with:

```lua
--   Headers.onClick(sectionId)  left-click (collapse/expand, or drop the cursor item)
--   Headers.onDrop(sectionId)   an item dragged onto the header (AC4.3)
-- Those two are the bags window's. Another window passes its own { onClick, onDrop } as the
-- owner of the headers it acquires, and releases only the headers inside its own frame.
local _, SB = ...

```

<!-- sbw3:edit T5 i09 SwagBag/UI/SectionHeaders.lua -->
In `SwagBag/UI/SectionHeaders.lua`, find:

```lua
local H = { pool = {}, inUse = {}, HEIGHT = 18 }
SB.SectionHeaders = H

-- Pure: the header text.
```

and replace it with:

```lua
local H = { pool = {}, inUse = {}, HEIGHT = 18 }
SB.SectionHeaders = H

-- [header] = the frame it was acquired in / its owner's { onClick, onDrop }. Kept beside the
-- frames, not on them, so a field name can never clash with a frame method.
local parents, owners = {}, {}

-- Pure: the header text.
```

<!-- sbw3:edit T5 i10 SwagBag/UI/SectionHeaders.lua -->
In `SwagBag/UI/SectionHeaders.lua`, find:

```lua
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
```

and replace it with:

```lua
	h.text:SetJustifyH("LEFT")
	h:SetScript("OnClick", Guard("header.click", function(self)
		local o = owners[self] or H
		if o.onClick then
			o.onClick(self.sectionId)
		end
	end, "bags"))
	h:SetScript("OnReceiveDrag", Guard("header.drop", function(self)
		local o = owners[self] or H
		if o.onDrop then
			o.onDrop(self.sectionId)
		end
	end, "bags"))
```

<!-- sbw3:edit T5 i11 SwagBag/UI/SectionHeaders.lua -->
In `SwagBag/UI/SectionHeaders.lua`, find:

```lua
end

-- A shown header for sectionId at (x, y) inside parent.
function H.Acquire(parent, sectionId, label, x, y, width)
	local h = table.remove(H.pool) or create(parent)
	h:SetParent(parent)
	h.sectionId = sectionId
	h.text:SetText(label)
	h:SetWidth(width)
```

and replace it with:

```lua
end

-- A shown header for sectionId at (x, y) inside parent. owner: optional { onClick, onDrop }.
function H.Acquire(parent, sectionId, label, x, y, width, owner)
	local h = table.remove(H.pool) or create(parent)
	h:SetParent(parent)
	parents[h], owners[h] = parent, owner
	h.sectionId = sectionId
	h.bg:SetColorTexture(1, 1, 1, 0.06)
	h.text:SetText(label)
	h:SetWidth(width)
```

<!-- sbw3:edit T5 i12 SwagBag/UI/SectionHeaders.lua -->
In `SwagBag/UI/SectionHeaders.lua`, find:

```lua
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

and replace it with:

```lua
end

-- Release the headers inside parent; every header when parent is nil.
function H.ReleaseAll(parent)
	for i = #H.inUse, 1, -1 do
		local h = H.inUse[i]
		if parent == nil or parents[h] == parent then
			h:Hide()
			h.sectionId, parents[h], owners[h] = nil, nil, nil
			table.remove(H.inUse, i)
			H.pool[#H.pool + 1] = h
		end
	end
end
```

<!-- sbw3:edit T5 i13 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
		return
	end
	W.state, W.pos, W.sortPending, W.sortSawUpdate = nil, nil, false, false
	W.ClearDropGuard()
	SB.Buttons.ReleasePlaceholders()
	SB.Emit("SB_BAGS_CLOSED")
end, "bags"))
```

and replace it with:

```lua
		return
	end
	W.state, W.pos, W.sortPending, W.sortSawUpdate, W.dragging = nil, nil, false, false, false
	W.ClearDropGuard()
	SB.Buttons.ReleasePlaceholders(child)
	SB.Emit("SB_BAGS_CLOSED")
end, "bags"))
```

<!-- sbw3:edit T5 i14 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
end

frame:SetScript("OnDragStart", Guard("bags.dragStart", function()
	frame:StartMoving()
end, "bags"))
frame:SetScript("OnDragStop", Guard("bags.dragStop", function()
	frame:StopMovingOrSizing()
	savePosition()
```

and replace it with:

```lua
end

-- While the window is being dragged nothing re-anchors it (a scale change or a resize waits
-- for the drop; the drop saves the new corner).
frame:SetScript("OnDragStart", Guard("bags.dragStart", function()
	W.dragging = true
	frame:StartMoving()
end, "bags"))
frame:SetScript("OnDragStop", Guard("bags.dragStop", function()
	W.dragging = false
	frame:StopMovingOrSizing()
	savePosition()
```

<!-- sbw3:edit T5 i15 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	local viewHeight = math.min(height, maxHeight - W.HEADER - W.FOOTER)
	frame:SetSize(width + 8, viewHeight + W.HEADER + W.FOOTER)
	if keepTop and left and top then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
```

and replace it with:

```lua
	local viewHeight = math.min(height, maxHeight - W.HEADER - W.FOOTER)
	frame:SetSize(width + 8, viewHeight + W.HEADER + W.FOOTER)
	if keepTop and left and top and not W.dragging then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
```

<!-- sbw3:edit T5 i16 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
end

-- Scaling only resizes the window; nothing is regrouped.
function W.SetScale(scale)
	scale = SB.GridLayout.ClampScale(scale)
```

and replace it with:

```lua
end

-- Scaling only resizes the window; nothing is regrouped. The new corner is saved at once, so
-- a reopen lands where the window is now (the saved offsets are in the new scale).
function W.SetScale(scale)
	scale = SB.GridLayout.ClampScale(scale)
```

<!-- sbw3:edit T5 i17 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	local oldScale, left, top = frame:GetScale(), frame:GetLeft(), frame:GetTop()
	frame:SetScale(scale)
	if left and top and frame:IsShown() then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * oldScale / scale, top * oldScale / scale)
	end
	W.Flash(L.BAGS_SCALE:format(math.floor(scale * 100 + 0.5)))
```

and replace it with:

```lua
	local oldScale, left, top = frame:GetScale(), frame:GetLeft(), frame:GetTop()
	frame:SetScale(scale)
	if left and top and frame:IsShown() and not W.dragging then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * oldScale / scale, top * oldScale / scale)
		savePosition()
	end
	W.Flash(L.BAGS_SCALE:format(math.floor(scale * 100 + 0.5)))
```

<!-- sbw3:edit T5 i18 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
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
```

and replace it with:

```lua
end

-- A cell whose slot is past the bag's current size (the bag shrank and the "removed" change
-- is still held back) is never shown.
local function inBag(c)
	return c.slot <= (W.sizes[c.bag] or 0)
end

local function showAt(button, c)
	if c.shown and inBag(c) then
		place(button, c.x, c.y)
		button:Show()
	else
		button:Hide()
	end
end

-- Placeholders and headers (a handful) are redrawn whole; they live in this window's child,
-- so nothing another window drew is released.
local function renderExtras(pos)
	local B, H = SB.Buttons, SB.SectionHeaders
	B.ReleasePlaceholders(child)
	for _, p in ipairs(pos.placeholders) do
		if p.shown then
```

<!-- sbw3:edit T5 i19 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
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
```

and replace it with:

```lua
		end
	end
	H.ReleaseAll(child)
	for _, h in ipairs(pos.headers) do
		H.Acquire(child, h.id, H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow), W.PAD, h.y,
			pos.width - 2 * W.PAD)
	end
end

local function cellsOf(pos)
	local cells = {}
	for _, c in ipairs(pos.cells) do
		if inBag(c) then
			cells[#cells + 1] = c
		end
	end
	return cells
end

-- Put buttons, placeholders and headers where W.pos says. Returns width, height.
local function render()
	local B, pos = SB.Buttons, W.pos
	W.cells = {}
	for _, c in ipairs(pos.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			showAt(button, c)
			if inBag(c) then
				W.cells[#W.cells + 1] = c
			end
		end
	end
	renderExtras(pos)
	return pos.width, pos.height
end
W.Render = render

-- After Layout.Apply only the buttons whose cell changed are touched (Layout.Moves), plus the
-- placeholders and headers: a few frame calls however many slots the window holds (spec 9).
local function renderMoved(oldPos, newPos)
	local B = SB.Buttons
	for _, key in ipairs(SB.Layout.Moves(oldPos, newPos)) do
		local c = newPos.byKey[key]
		local button = B.Get(c.bag, c.slot)
		if button then
			showAt(button, c)
		end
	end
	for key, c in pairs(oldPos.byKey) do
		if not newPos.byKey[key] then -- a removed slot (the bag shrank)
			local button = B.Get(c.bag, c.slot)
			if button then
				button:Hide()
			end
		end
	end
	W.cells = cellsOf(newPos)
	renderExtras(newPos)
	return newPos.width, newPos.height
end

local function layoutSections(bags)
```

<!-- sbw3:edit T5 i20 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	end
	W.records, W.state, W.pos = {}, nil, nil
	B.ReleasePlaceholders()
	SB.SectionHeaders.ReleaseAll()
	local width, height
	if W.View() == "grid" then
```

and replace it with:

```lua
	end
	W.records, W.state, W.pos = {}, nil, nil
	B.ReleasePlaceholders(child)
	SB.SectionHeaders.ReleaseAll(child)
	local width, height
	if W.View() == "grid" then
```

<!-- sbw3:edit T5 i21 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	if #result.moved > 0 or (newSec and newSec.overflow or 0) ~= overflowBefore then
		result.rendered = true
		W.pos = SB.Layout.Position(st, positionOpts(), W.Collapsed())
		local width, height = render()
		sizeFrame(width, height, true)
	end
```

and replace it with:

```lua
	if #result.moved > 0 or (newSec and newSec.overflow or 0) ~= overflowBefore then
		result.rendered = true
		local oldPos = W.pos
		W.pos = SB.Layout.Position(st, positionOpts(), W.Collapsed())
		local width, height = renderMoved(oldPos, W.pos)
		sizeFrame(width, height, true)
	end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/buttons_spec.lua`
Expected: `77 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (39 files)`, `518 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/bagswindow_sections_spec.lua \
  spec/buttons_spec.lua \
  SwagBag/UI/Buttons.lua \
  SwagBag/UI/SectionHeaders.lua \
  SwagBag/UI/BagsWindow.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 5: pool growth max-merge, CreateAll retry, bank bag frames, per-window pools, incremental redraw, scale position" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 7: In-game session S3 (the user does this on Oct 17; about 2 minutes)**

No new files, so `/reload` is enough.

1. Type `/reload`. Press **B**. Move the window somewhere easy to see.
2. Hold **Ctrl** and turn the mouse wheel up two notches over the items. The window grows, and its top-left corner stays exactly where it was.
3. Press **B** twice (close, open). The window opens at the same place and size as in step 2.
4. Hold **Ctrl** and turn the wheel down two notches. The window shrinks back, and its top-left corner stays put.
5. Use up the last item of a stack (for example eat your last food), then move the mouse off it. A faded copy stays where it was, and nothing else in the window moves.

Pass: steps 2–5 behave as described.

---

### Task 6: One search per window (`SearchState.New`, `SearchBox.New`)

Spec AC5.1 asks for "a search box per window". Today `SB.Search` is a single module state, and `UI/SearchBox.lua` builds one box bound to the bags window. The bank and guild bank windows need their own search text and dimming, so this task makes the search state an instance (`SB.SearchState.New()`). `SB.Search` stays the bags window's instance, so every existing caller and test keeps working. The box becomes a factory, `SB.SearchBox.New(o)`, which builds a box on any frame with its own state, slot iterator and dimmer; the bags box is built through it. `ErrorSpan` and `VOLATILE_REFRESH` are shared and stay on every instance. Both files are replaced whole, because the search body is now indented inside the constructor.

**Files:**
- Modify (replace whole files): `SwagBag/Engine/Search.lua`, `SwagBag/UI/SearchBox.lua`
- Test: `spec/search_spec.lua`, `spec/searchbox_spec.lua`

**Interfaces:**
- Consumes: `SB.Query.Compile/Eval/FormatError/FormatWarning`, `SB.ErrorTrap.Run/Guard`, `SB.Debounce`, `SB.BagsWindow.IsOpen/ForEachSlot/frame`, `SB.Buttons.SetDimmed` (all on `main`).
- Produces:
  - `SB.SearchState.New() -> search`, with the same fields and functions as before: `SetText`, `IsActive`, `NeedsVolatileRefresh`, `Apply(forEach, setDimmed)`, `ErrorSpan`, `active`, `text`, `lastError`, `lastWarning`, `lastEvalError`, `failedId`, `stats`.
  - `SB.SearchState.ErrorSpan(text, err)` and `SB.SearchState.VOLATILE_REFRESH`.
  - `SB.Search` is the bags window's search.
  - `SB.SearchBox.New(o) -> box`, with `o = { parent, name, search, window, debounceKey, isOpen(), forEachSlot(fn), setDimmed(button, dimmed) }`. The box has `editBox`, `search`, `Apply()`, `Run()`, `ShowError(text, err)` and `ClearError()`.
  - `SB.SearchBox` is the bags window's box, with the same fields as before.

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T6 s01 spec/search_spec.lua -->
In `spec/search_spec.lua`, find:

```lua
		end)
	end)
end)
```

and replace it with:

```lua
		end)
	end)

	it("SearchState.New makes independent searches; each records its failing query once", function()
		local bank = SB.SearchState.New()
		assert.truthy(bank ~= S)
		assert.truthy(bank.SetText("gear"))
		assert.truthy(S.SetText("potion"))
		assert.equal("gear", bank.text)
		assert.equal("potion", S.text)
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("x") end })
		bank.SetText("boom")
		S.SetText("boom")
		bank.Apply(forEach, setDimmed)
		bank.Apply(forEach, setDimmed)
		S.Apply(forEach, setDimmed)
		assert.equal(2, #SB.ErrorTrap.Recent(), "once per search, not once per pass")
	end)
end)
```

<!-- sbw3:edit T6 s02 spec/searchbox_spec.lua -->
In `spec/searchbox_spec.lua`, find:

```lua
	end)

	it("the error line is top-aligned right of the box and never stretches over the items", function()
		local errorLine
```

and replace it with:

```lua
	end)

	it("another window's box has its own search: typing there never changes the bags window's", function()
		open()
		Box.editBox:SetText("potion")
		SB.Adapter.Advance(0.2)
		local bankFrame, bankDimmed, bankOpen = newFake(), {}, true
		local bankSlots = { { button = "k1", record = slots[3].record }, { button = "k2", record = slots[1].record } }
		local bank = Box.New({
			parent = bankFrame, name = "SwagBagBankSearchBox", search = SB.SearchState.New(), window = "bank",
			debounceKey = "search.bank",
			isOpen = function() return bankOpen end,
			forEachSlot = function(fn)
				for _, s in ipairs(bankSlots) do
					fn(s.button, s.record)
				end
			end,
			setDimmed = function(button, d) bankDimmed[button] = d end,
		})
		bank.editBox:SetText("gear")
		SB.Adapter.Advance(0.2)
		assert.same({ k1 = false, k2 = true }, bankDimmed, "the ring matches gear, the potion does not")
		assert.equal("potion", SB.Search.text, "the bags search is unchanged")
		assert.equal("gear", bank.search.text)
		assert.falsy(dimmed.k1, "the bags window never dimmed bank buttons")
		bank.editBox:SetText("gear &")
		SB.Adapter.Advance(0.2)
		assert.truthy(bank.search.lastError)
		assert.is_nil(SB.Search.lastError, "the error belongs to the bank box only")
	end)

	it("the error line is top-aligned right of the box and never stretches over the items", function()
		local errorLine
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/search_spec.lua spec/searchbox_spec.lua`
Expected: `26 passed, 2 failed`. `SB.SearchState` and `SB.SearchBox.New` do not exist yet.

Critical test and its mutation: `searchbox_spec` "another window's box has its own search…" fails when `SearchBox.New` uses `SB.Search` instead of `o.search` (add `o.search = SB.Search` at its top).

- [ ] **Step 3: Implement**

<!-- sbw3:file T6 i01 SwagBag/Engine/Search.lua -->
Replace the whole file `SwagBag/Engine/Search.lua` with:

```lua
-- SwagBag search state (spec F5), pure. The search box (UI/SearchBox.lua) feeds text
-- in; Apply dims every slot that is not a definite match. Search never moves items.
-- A text with errors is rejected and the previous valid search stays applied (AC5.3).
-- A keyword that fails while evaluating is trapped per pass: the previous dimming
-- stays and the search is reported as invalid (lastEvalError). The error ring gets ONE
-- entry per failing query (failedId), not one per keystroke or bag update.
-- Each window has its own search (spec AC5.1, "a search box per window"):
--   SB.Search               the bags window's search
--   SB.SearchState.New()    another, independent search (the bank and guild bank windows)
local _, SB = ...

local SearchState = {}
SB.SearchState = SearchState

-- Keywords whose answer changes with no bag update (a cooldown starts or ends, an item
-- becomes usable). The bags window re-reads those fields on BAG_UPDATE_COOLDOWN, but only
-- while the active search uses one of them (spec 9: cooldown events never rescan).
SearchState.VOLATILE_REFRESH = { cooldown = true, usable = true }

-- Byte range (first, last) of the characters to underline for a parse error.
-- Error positions are byte offsets; a trailing-operator error points one past the
-- end of the text, so it underlines the token before it. last < first means nothing
-- to underline (empty text). Never extends past the end of the text.
function SearchState.ErrorSpan(text, err)
	local n = #text
	local first = math.max(1, math.min(err.position or 1, n + 1))
	if err.got and err.got ~= "" and first <= n then
		return first, math.min(n, first + #err.got - 1)
	end
	local last = #text:sub(1, first - 1):gsub("%s+$", "")
	if last == 0 then
		return 1, 0
	end
	local after = err.after
	if after and after ~= "" and last - #after + 1 >= 1 and text:sub(last - #after + 1, last) == after then
		return last - #after + 1, last
	end
	local start = text:sub(1, last):find("%S+$")
	return start or last, last
end

function SearchState.New()
	-- lastWarning: a soft message for an applied search (an unknown #keyword matches nothing).
	local S = { active = nil, text = "", lastError = nil, lastWarning = nil, lastEvalError = nil, stats = {},
		VOLATILE_REFRESH = SearchState.VOLATILE_REFRESH, ErrorSpan = SearchState.ErrorSpan }

	-- Returns true, or false + formatted error message.
	function S.SetText(text)
		text = text or ""
		if S.active and text == S.text then
			S.lastError = nil -- unchanged valid query: no recompile
			return true
		end
		local compiled = SB.Query.Compile(text)
		if not compiled.fn then
			S.lastError = compiled.errors[1]
			return false, SB.Query.FormatError(S.lastError)
		end
		S.active, S.text, S.lastError = compiled, text, nil
		local w = compiled.warnings and compiled.warnings[1]
		S.lastWarning = w and SB.Query.FormatWarning(w) or nil
		return true
	end

	function S.IsActive()
		return S.active ~= nil and not S.active.empty
	end

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

	-- forEach(fn) calls fn(button, record-or-nil) for every slot in the window;
	-- setDimmed(button, dimmed). Unknown (nil) results and empty slots are dimmed
	-- while a search is active. Returns matches, total, milliseconds. If evaluation
	-- fails, nothing is dimmed or undimmed and it returns nil, nil, ms, message.
	function S.Apply(forEach, setDimmed)
		local A = SB.Adapter
		local t0 = A.ProfileMs()
		local c = S.IsActive() and S.active or nil
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
		S.stats.lastMs = ms
		if not ok then
			S.lastEvalError = SB.L.SEARCH_EVAL_FAILED
			return nil, nil, ms, S.lastEvalError
		end
		S.lastEvalError = nil
		for i = 1, count do
			setDimmed(results[i][1], not results[i][2])
		end
		S.stats.lastMatches, S.stats.lastTotal = matches, count
		return matches, count, ms
	end

	return S
end

SB.Search = SearchState.New()
```

<!-- sbw3:file T6 i02 SwagBag/UI/SearchBox.lua -->
Replace the whole file `SwagBag/UI/SearchBox.lua` with:

```lua
-- SwagBag search boxes (spec F5). One box per window, each with its own search
-- (Engine/Search.lua): typing re-applies the search 150 ms after the last keystroke. A
-- parse error shows a red message and a red underline under the offending characters;
-- the previous valid search stays. The owning window re-applies the dimming whenever it
-- lays out (including reopen) and whenever slot data changes (Box.Apply).
--   SB.SearchBox                the bags window's box (built at load, below)
--   SB.SearchBox.New(o) -> box  another window's box. o = { parent, name, search, window,
--     debounceKey, isOpen = fn() -> bool, forEachSlot = fn(fn), setDimmed = fn(button, dimmed) }
--   box.editBox, box.Apply(), box.Run(), box.ShowError(text, err), box.ClearError()
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard

local function new(o)
	local Box = { search = o.search }

	local box = CreateFrame("EditBox", o.name, o.parent, "SearchBoxTemplate")
	box:SetSize(200, 20)
	box:SetPoint("TOPLEFT", 14, -30)
	box:SetAutoFocus(false)
	Box.editBox = box

	local errorLine = o.parent:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	-- Two lines at most, between the box and the window's right edge, top-aligned with
	-- the box. Anchored TOPRIGHT (not RIGHT) so it never stretches down over the items.
	errorLine:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 4)
	errorLine:SetPoint("TOPRIGHT", o.parent, "TOPRIGHT", -8, -26)
	errorLine:SetJustifyH("LEFT")
	errorLine:SetJustifyV("TOP")
	errorLine:SetWordWrap(true)
	if errorLine.SetMaxLines then
		errorLine:SetMaxLines(2)
	end

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

	-- No error: show the applied search's soft warning (unknown #keyword), if any.
	function Box.ClearError()
		errorLine:SetTextColor(1, 0.82, 0) -- soft yellow: a warning is not an error
		errorLine:SetText(o.search.lastWarning or "")
		underline:Hide()
	end

	-- Underline the offending characters (byte range from ErrorSpan; for a trailing
	-- operator that is the token before the end of the text).
	function Box.ShowError(text, err)
		errorLine:SetTextColor(1, 0.1, 0.1) -- red, as GameFontRedSmall
		errorLine:SetText(SB.Query.FormatError(err))
		local first, last = o.search.ErrorSpan(text, err)
		if last < first then
			underline:Hide()
			return
		end
		local left = box:GetTextInsets()
		underline:ClearAllPoints()
		underline:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", (left or 0) + textWidth(text:sub(1, first - 1)), 1)
		underline:SetWidth(math.max(6, textWidth(text:sub(first, last))))
		underline:Show()
	end

	-- Re-applies the current search to every slot. Does nothing while the window is closed.
	function Box.Apply()
		if not o.isOpen() then
			return 0, 0, 0
		end
		local matches, total, ms = o.search.Apply(o.forEachSlot, o.setDimmed)
		if matches == nil then
			errorLine:SetTextColor(1, 0.1, 0.1)
			errorLine:SetText(L.SEARCH_EVAL_FAILED)
			underline:Hide()
		elseif o.search.lastError == nil then
			Box.ClearError()
		end
		return matches, total, ms
	end

	function Box.Run()
		local text = box:GetText()
		if o.search.SetText(text) then
			Box.ClearError()
		else
			Box.ShowError(text, o.search.lastError)
		end
		return Box.Apply()
	end

	-- Any text change (typing, or the box's own clear button) schedules one debounced run.
	box:HookScript("OnTextChanged", Guard("search.textChanged", function()
		SB.Debounce(o.debounceKey, 0.15, Box.Run, o.window)
	end, o.window))

	return Box
end

-- The bags window's box.
local W = SB.BagsWindow
local Box = new({
	parent = W.frame,
	name = "SwagBagBagsSearchBox",
	search = SB.Search,
	window = "bags",
	debounceKey = "search.bags",
	isOpen = function()
		return W.IsOpen()
	end,
	forEachSlot = function(fn)
		return W.ForEachSlot(fn)
	end,
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
	end,
})
Box.New = new
SB.SearchBox = Box

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
	Box.editBox:SetText(arg)
	if not SB.Search.SetText(arg) then
		Box.ShowError(arg, SB.Search.lastError)
		return L.SEARCH_ERROR:format(SB.Query.FormatError(SB.Search.lastError))
	end
	Box.ClearError()
	local matches, total, ms = Box.Apply()
	if matches == nil then
		return L.SEARCH_EVAL_FAILED
	end
	if not SB.Search.IsActive() then
		return L.SEARCH_CLEARED
	end
	local result = L.SEARCH_RESULT:format(arg, matches, total, ms)
	if SB.Search.lastWarning then
		return { result, SB.Search.lastWarning }
	end
	return result
end, "bags")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/search_spec.lua spec/searchbox_spec.lua`
Expected: `28 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (39 files)`, `520 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/search_spec.lua \
  spec/searchbox_spec.lua \
  SwagBag/Engine/Search.lua \
  SwagBag/UI/SearchBox.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 6: one search state and search box per window" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 7: GroupView: stacked groups with their own sections, the hover guard across groups, the 1,290-slot budget

The bank window shows two groups (character bank, warband bank) and the guild bank one group per tab. Both need what the bags window does for one group: week-2 `Layout` sections or a grid, collapse, the spec §4.3 transitions while open, and spec §4.2 rule 5. `UI/GroupView.lua` provides that for a stack of groups in one scroll child:

- Each group has a header (`"#" .. groupId`) that collapses the whole group, its own `Layout` state, and its own collapse set: `ui.collapsed["bank:warband"]`, `ui.collapsed["bank:#"]` for whole groups.
- Section headers are `groupId .. ":" .. sectionId` and are acquired with the view's own owner (Task 5), so clicks never reach the bags window.
- `Layout.Position` gains `opts.top`, so each group's sections start under the group above.
- **Cross-group pushes.** A change in one group can push the groups below it (the character bank's Free gains a row). That push is held back while one of the pushed buttons is under the mouse or an item is on the cursor (Review Focus 4). It retries 300 ms later; `v.stats.heldRedraws` counts the holds.
- **Incremental redraws.** Redraws touch only `Layout.Moves` keys plus the placeholders and headers. The 1,290-slot fixture is laid out in plain Lua well inside the 80 ms first-open budget (spec §9), and a live change looks up at most 4 buttons.
- **Drops on headers.** A drop on a section header goes to `cfg.onDrop(sectionId)`. The click that follows the drop is ignored for 0.3 s, exactly like the bags window (week-2 ruling).

**Files:**
- Create: `SwagBag/UI/GroupView.lua`
- Modify: `SwagBag/Engine/Layout.lua` (`opts.top`), `SwagBag/SwagBag.toc`
- Test: `spec/groupview_spec.lua` (new), `spec/layout_spec.lua`

**Interfaces:**
- Consumes:
  - `SB.Layout.Build/Position/Apply/Moves/Key/NEW` and `SB.GridLayout.Compute` (on `main`);
  - `SB.Categorizer.Assign`, `SB.Categories.SectionOrder/Name`, `SB.Config.UI` (on `main`);
  - Task 5's `SB.SectionHeaders.Acquire(…, owner)`, `ReleaseAll(parent)` and `SB.Buttons.AcquirePlaceholder/ReleasePlaceholders(parent)`.
- Produces:
  - `SB.Layout.Position(state, opts, collapsed)` with `opts.top` (default 0; the height includes it).
  - `SB.GroupView.New(cfg) -> v` (the cfg fields are listed at the top of the file).
  - Layout: `v.Layout(reason) -> width, height`, `v.RequestLayout(reason) -> bool`.
  - Live changes and collapse: `v.Changes(groupId, list)`, `v.Retry()`, `v.Restack() -> bool`, `v.ToggleSection(groupId, sectionId)`, `v.ToggleGroup(groupId)`.
  - Access: `v.ForEachSlot(fn(button, record, bag, slot))`, `v.Record(bag, slot)`, `v.SetRecord(bag, slot, record)`, `v.GroupOf(bag)`, `v.Size(bag)`, `v.IsOpen()`, `v.Clear()`, `v.Collapsed(id)`.
  - Fields: `v.groups`, `v.pos`, `v.cells`, `v.stats.lastLayoutMs`, `v.stats.lastLayoutReason`, `v.stats.heldRedraws`.
  - Constants: `SB.GroupView.SLOT/GAP/PAD/SECTION_HEADER/SECTION_GAP/GROUP_HEADER/GROUP_GAP/RETRY/DROP_GUARD`.

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:file T7 s01 spec/groupview_spec.lua -->
Create `spec/groupview_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The group view (bank and guild bank contents) over the real engine with fake frames:
-- stacked groups, per-group sections, collapse, spec 4.3 changes, the hover guard across
-- groups, the grid view, and the 1,290-slot budget.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Big = dofile("spec/fixtures/big.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/CategoryDefaults.lua", "SwagBag/Engine/Categories.lua",
	"SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
}

-- A view over bank tab 6 ("bank") and warband tab 12 ("warband"), with fake buttons.
local function newView(SB, opts)
	opts = opts or {}
	local child = Fake.New("Frame")
	local scroll = Fake.New("ScrollFrame")
	local buttons, gets, resized = {}, { n = 0 }, {}
	local tint = {}
	local cfg = {
		key = "bank", window = "bank", child = child, scroll = scroll,
		button = function(bag, slot)
			gets.n = gets.n + 1
			if slot > (opts.capacity or 98) then
				return nil
			end
			buttons[bag] = buttons[bag] or {}
			local b = buttons[bag][slot]
			if not b then
				b = Fake.New("ItemButton", child)
				b.bag, b.slot = bag, slot
				buttons[bag][slot] = b
			end
			return b
		end,
		describe = function(bag, slot)
			return SB.Items.Describe(bag, slot)
		end,
		groups = function()
			local out = {}
			for _, def in ipairs(opts.groups or { { "bank", "bank" }, { "warband", "warband" } }) do
				local bags = {}
				for _, bag in ipairs(SB.Adapter.GetBagIDs(def[2])) do
					bags[#bags + 1] = { bag = bag, size = SB.Adapter.NumSlots(bag) }
				end
				out[#out + 1] = { id = def[1], bags = bags }
			end
			return out
		end,
		groupLabel = function(id, collapsed, count)
			return (collapsed and "+ " or "- ") .. id .. " (" .. count .. ")"
		end,
		groupTint = function(id) return tint[id] end,
		view = function() return opts.view or "sections" end,
		columns = function() return opts.columns or 4 end,
		newRows = function() return 1 end,
		onResize = function(w, h, keepTop) resized[#resized + 1] = { w, h, keepTop } end,
	}
	local v = SB.GroupView.New(cfg)
	return v, { buttons = buttons, gets = gets, child = child, scroll = scroll, resized = resized, tint = tint, cfg = cfg }
end

local function at(b)
	local p = b.points[#b.points]
	return { p[4], p[5] }
end

describe("GroupView", function()
	local SB, A, v, f
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GroupView.lua")
		SB.Categories.Load()
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.Put(6, 1, Fixtures.HEALING_POTION, 5)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(6, 3, Fixtures.FLASK, 1)
		A.Put(12, 1, Fixtures.ORE, 10)
		A.Put(12, 2, Fixtures.BOE_RING, 1)
		v, f = newView(SB)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function labels()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			out[#out + 1] = h.sectionId .. "=" .. h.text.text
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

	local function btn(bag, slot)
		return f.buttons[bag][slot]
	end

	it("stacks the groups top to bottom, each with its header and its own New, categories and Free", function()
		v.Layout("open")
		assert.same({
			"#bank=- bank (3)", "#warband=- warband (2)",
			"bank:new=- New (0)", "bank:c_consumables=- Consumables (2)", "bank:c_herbs=- Herbs (1)",
			"bank:free=- Free (5)",
			"warband:new=- New (0)", "warband:c_boe=- BoE gear (1)", "warband:c_ore=- Ore (1)",
			"warband:free=- Free (6)",
		}, labels())
		assert.equal(0, header("#bank").points[1][5])
		assert.truthy(header("#warband").points[1][5] < at(btn(6, 8))[2], "warband starts below bank's Free")
		assert.equal(16, #v.cells)
		assert.equal("open", v.stats.lastLayoutReason)
		assert.same({ v.pos.width, v.pos.height, false }, f.resized[1])
	end)

	it("collapsing a group hides its slots and lifts the groups below; expanding restores every cell", function()
		v.Layout("open")
		local before = { at(btn(12, 1)), at(btn(12, 2)), at(btn(6, 1)) }
		header("#bank").scripts.OnClick(header("#bank"))
		assert.equal(true, SB.Config.UI().collapsed["bank:#"].bank)
		assert.falsy(btn(6, 1).shown)
		assert.equal("- bank (3)", header("#bank").text.text:gsub("^%+", "-"))
		assert.truthy(at(btn(12, 1))[2] > before[1][2], "warband moved up")
		assert.is_nil(header("bank:new"), "a collapsed group shows no section headers")
		header("#bank").scripts.OnClick(header("#bank"))
		assert.same(before, { at(btn(12, 1)), at(btn(12, 2)), at(btn(6, 1)) })
		assert.truthy(btn(6, 1).shown)
	end)

	it("collapse state is kept per window, per group and per section", function()
		v.Layout("open")
		header("warband:c_ore").scripts.OnClick(header("warband:c_ore"))
		assert.equal(true, SB.Config.UI().collapsed["bank:warband"].c_ore)
		assert.is_nil(SB.Config.UI().collapsed["bank:bank"].c_ore)
		assert.falsy(btn(12, 1).shown)
		v.Clear()
		v.Layout("open")
		assert.falsy(btn(12, 1).shown, "still collapsed after a reopen")
		assert.equal("+ Ore (1)", header("warband:c_ore").text.text)
	end)

	it("an item taken from a group leaves a placeholder; its button goes to that group's Free", function()
		v.Layout("open")
		local potionAt = at(btn(6, 1))
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		assert.equal(1, #SB.Buttons.placeholdersInUse)
		assert.truthy(at(btn(6, 1))[2] < potionAt[2], "moved down into Free")
		assert.equal("bank:free=- Free (6)", labels()[6])
	end)

	it("a deposit goes to that group's New and nothing else moves", function()
		v.Layout("open")
		local before = {}
		for slot = 1, 8 do
			before[slot] = at(btn(12, slot))
		end
		A.Put(6, 5, Fixtures.JUNK, 1)
		v.Changes("bank", { { bag = 6, slot = 5, kind = "arrived" } })
		v.SetRecord(6, 5, SB.Items.Describe(6, 5))
		assert.equal(header("bank:new").points[1][5] - 20, at(btn(6, 5))[2], "first cell of New")
		for slot = 1, 8 do
			assert.same(before[slot], at(btn(12, slot)), "warband slot " .. slot)
		end
	end)

	it("a group that grows a row pushes the groups below, but not while one of them is under the mouse", function()
		A.Put(6, 4, Fixtures.JUNK, 1) -- bank Free has 4 cells: one more starts a new row
		v.Layout("open")
		local ore = btn(12, 1)
		local oreAt = at(ore)
		ore.mouseOver = true
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		assert.same(oreAt, at(ore), "held: the ore is under the mouse")
		assert.equal(1, v.stats.heldRedraws)
		A.Advance(0.3)
		assert.same(oreAt, at(ore), "still under the mouse")
		ore.mouseOver = false
		A.Advance(0.3)
		assert.truthy(at(ore)[2] < oreAt[2], "pushed down once the mouse left")
		assert.equal(1, #SB.Buttons.placeholdersInUse)
	end)

	it("an item on the cursor holds every move and every push", function()
		v.Layout("open")
		local potionAt = at(btn(6, 1))
		A.cursor = { itemID = Fixtures.FLASK }
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		A.Advance(0.6)
		assert.same(potionAt, at(btn(6, 1)))
		A.cursor = nil
		A.Advance(0.3)
		assert.truthy(at(btn(6, 1))[2] < potionAt[2])
	end)

	it("the grid view shows each group's slots in physical order under its header", function()
		v, f = newView(SB, { view = "grid" })
		v.Layout("open")
		assert.same({ "#bank=- bank (3)", "#warband=- warband (2)" }, labels())
		assert.same({ 4, -26 }, at(btn(6, 1)))
		assert.same({ 45, -26 }, at(btn(6, 2)))
		assert.same({ 4, -67 }, at(btn(6, 5)))
		assert.truthy(at(btn(12, 1))[2] < at(btn(6, 8))[2])
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left" } })
		assert.same({ 4, -26 }, at(btn(6, 1)), "the grid never moves a button")
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		v.ToggleGroup("bank")
		assert.falsy(btn(6, 2).shown, "a collapsed group hides its grid")
		assert.equal(-56, at(btn(12, 1))[2], "warband moved up: bank header, gap, warband header")
	end)

	it("dropping an item on a section header calls onDrop once; the click of the same press does not collapse", function()
		local dropped = {}
		f.cfg.onDrop = function(sid) dropped[#dropped + 1] = sid end
		v.Layout("open")
		A.cursor = { itemID = Fixtures.JUNK }
		local h = header("bank:c_herbs")
		h.scripts.OnReceiveDrag(h)
		A.cursor = nil -- the drop put it in the category list and the item back in its slot
		h.scripts.OnClick(h)
		assert.same({ "c_herbs" }, dropped)
		assert.is_nil(SB.Config.UI().collapsed["bank:bank"].c_herbs)
		A.Advance(0.5)
		h.scripts.OnClick(h)
		assert.equal(true, SB.Config.UI().collapsed["bank:bank"].c_herbs, "a later click collapses")
	end)

	it("Clear hides every button and releases only this view's placeholders and headers", function()
		local other = Fake.New("Frame")
		local foreign = SB.SectionHeaders.Acquire(other, "c_gear", "x", 0, 0, 10)
		local foreignP = SB.Buttons.AcquirePlaceholder(other, 1, 37, 0, 0)
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		v.Clear()
		for slot = 1, 8 do
			assert.falsy(btn(6, slot).shown)
		end
		assert.truthy(foreign.shown)
		assert.truthy(foreignP.shown)
		assert.same({ foreign }, SB.SectionHeaders.inUse)
		assert.falsy(v.IsOpen())
	end)

	it("a full layout request waits while the mouse is over the items or an item is on the cursor", function()
		v.Layout("open")
		f.scroll.mouseOver = true
		assert.falsy(v.RequestLayout("sort"))
		A.Advance(0.3)
		assert.equal("open", v.stats.lastLayoutReason)
		f.scroll.mouseOver = false
		A.cursor = { itemID = 1 }
		A.Advance(0.3)
		assert.equal("open", v.stats.lastLayoutReason)
		A.cursor = nil
		A.Advance(0.3)
		assert.equal("sort", v.stats.lastLayoutReason)
	end)

	it("the deposit target's group header is tinted", function()
		f.tint.warband = true
		v.Layout("open")
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
		assert.same({ 1, 1, 1, 0.06 }, header("#bank").bg.calls.SetColorTexture)
	end)

	it("a group that disappears between layouts hides its buttons", function()
		v.Layout("open")
		f.cfg.groups = function()
			return { { id = "bank", bags = { { bag = 6, size = 8 } } } }
		end
		v.Layout("reflow")
		assert.falsy(btn(12, 1).shown)
		assert.equal(8, #v.cells)
	end)

	it("1,290 slots: a full layout stays inside the first-bank-open budget; a live change touches a few buttons", function()
		Big.Install(A)
		v, f = newView(SB, { columns = 14 })
		local t0 = os.clock()
		v.Layout("open")
		local ms = (os.clock() - t0) * 1000
		assert.equal(1078, #v.cells)
		assert.truthy(ms <= 80, ("layout of 1,078 bank slots took %.1f ms"):format(ms))
		f.gets.n = 0
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		assert.equal(1, #SB.Buttons.placeholdersInUse)
		assert.truthy(f.gets.n <= 4, "Buttons looked up " .. f.gets.n .. " times for one change")
	end)
end)

describe("GroupView randomized (Park-Miller): hover holds across groups, section truth after every drain", function()
	local SB, A
	local POOL = { Fixtures.HEALING_POTION, Fixtures.FLASK, Fixtures.HERB, Fixtures.ORE, Fixtures.BOE_RING,
		Fixtures.SOULBOUND_HELM, Fixtures.JUNK }

	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GroupView.lua")
		SB.Categories.Load()
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(6, 12)
		A.SetBagSize(12, 12)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	it("never moves a hovered button, and after each drain every category cell holds its own item", function()
		local seed = 20261015
		local function rand(n)
			seed = seed * 16807 % 2147483647 -- Park-Miller, exact in doubles
			return seed % n + 1
		end
		local count = { left = 0, arrived = 0, drains = 0, holds = 0, pushes = 0 }
		for run = 1, 12 do
			for _, bag in ipairs({ 6, 12 }) do
				for slot = 1, 12 do
					if rand(3) ~= 1 then
						A.Put(bag, slot, POOL[rand(#POOL)], 1)
					else
						A.Clear(bag, slot)
					end
				end
			end
			local v, f = newView(SB, { columns = 4 })
			v.Layout("open")
			local function check(where)
				local seen = {}
				for _, g in ipairs(v.groups) do
					for id, sec in pairs(g.state.sections) do
						for i = 1, sec.size do
							local cell = sec.cells[i]
							if cell and not cell.placeholder and id ~= "new" and id ~= "free" then
								local r = SB.Items.Describe(cell.bag, cell.slot)
								assert.truthy(r and SB.Categorizer.Assign(r) == id,
									where .. ": " .. cell.bag .. ":" .. cell.slot .. " is not a " .. id)
							end
						end
					end
				end
				for _, c in ipairs(v.pos.cells) do
					local b = f.buttons[c.bag][c.slot]
					if c.shown then
						assert.same({ c.x, c.y }, at(b), where .. ": drawn where the layout says")
						local k = c.x .. "," .. c.y
						assert.is_nil(seen[k], where .. ": two buttons at " .. k)
						seen[k] = true
					end
				end
				assert.falsy(v.redrawPending, where)
			end
			check("run " .. run .. " open")
			for step = 1, 40 do
				local where = ("run %d step %d"):format(run, step)
				local hovered = {}
				for _ = 1, rand(3) - 1 do
					local b = f.buttons[rand(2) == 1 and 6 or 12][rand(12)]
					if b.shown then
						b.mouseOver = true
						hovered[#hovered + 1] = { b, at(b) }
					end
				end
				local bag, slot = rand(2) == 1 and 6 or 12, rand(12)
				local had = A.slots[bag][slot]
				local change
				if had and rand(2) == 1 then
					A.Clear(bag, slot)
					change = { bag = bag, slot = slot, kind = "left", icon = had.itemID }
					count.left = count.left + 1
				else
					local i = rand(#POOL)
					local id = POOL[i]
					if had and had.itemID == id then
						id = POOL[i % #POOL + 1] -- a different item, so the slot really changes
					end
					A.Put(bag, slot, id, 1)
					change = { bag = bag, slot = slot, kind = "arrived", icon = had and had.itemID }
					count.arrived = count.arrived + 1
				end
				local held = v.stats.heldRedraws or 0
				local warbandTop = v.pos.groupHeaders[2].y
				v.SetRecord(bag, slot, SB.Items.Describe(bag, slot))
				v.Changes(bag == 6 and "bank" or "warband", { change })
				if (v.stats.heldRedraws or 0) > held then
					count.holds = count.holds + 1
				end
				for _, h in ipairs(hovered) do
					assert.same(h[2], at(h[1]), where .. ": a hovered button moved")
				end
				if v.pos.groupHeaders[2].y ~= warbandTop then
					count.pushes = count.pushes + 1 -- the bank grew or shrank and the warband followed
				end
				if rand(4) == 1 or step == 40 then
					for _, h in ipairs(hovered) do
						h[1].mouseOver = false
					end
					A.Advance(1)
					count.drains = count.drains + 1
					check(where .. " drained")
				else
					for _, h in ipairs(hovered) do
						h[1].mouseOver = false
					end
				end
			end
			v.Clear()
		end
		assert.truthy(count.left >= 150, "lefts " .. count.left)
		assert.truthy(count.arrived >= 150, "arrivals " .. count.arrived)
		assert.truthy(count.drains >= 100, "drains " .. count.drains)
		assert.truthy(count.holds >= 5, "held pushes " .. count.holds)
		assert.truthy(count.pushes >= 5, "warband pushed by the bank growing " .. count.pushes)
	end)
end)
```

<!-- sbw3:edit T7 s02 spec/layout_spec.lua -->
In `spec/layout_spec.lua`, find:

```lua
		assert.equal(open.height - 10, closed.height)
		assert.same(open, L.Position(st, OPTS, {}))
	end)

```

and replace it with:

```lua
		assert.equal(open.height - 10, closed.height)
		assert.same(open, L.Position(st, OPTS, {}))
	end)

	it("opts.top shifts every header and cell down by top, and the height includes it", function()
		local opts = {}
		for k, val in pairs(OPTS) do
			opts[k] = val
		end
		opts.top = 100
		local base, shifted = L.Position(sample(), OPTS, {}), L.Position(sample(), opts, {})
		for i, h in ipairs(base.headers) do
			assert.equal(h.y - 100, shifted.headers[i].y)
		end
		for k, c in pairs(base.byKey) do
			assert.same({ c.x, c.y - 100 }, { shifted.byKey[k].x, shifted.byKey[k].y })
		end
		assert.equal(base.height + 100, shifted.height)
	end)

```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/groupview_spec.lua spec/layout_spec.lua`
Expected: `28 passed, 16 failed`. `UI/GroupView.lua` does not exist, and `Layout.Position` ignores `top`.

The randomized test uses Park-Miller (`seed * 16807 % 2147483647`, exact in doubles): 12 runs of 40 steps, with 0–2 hovered buttons per step. It asserts coverage minimums, so it can never pass vacuously: ≥ 150 lefts, ≥ 150 arrivals, ≥ 100 drains, ≥ 5 held pushes, ≥ 5 pushes of the warband group. Measured: 165 / 315 / 132 / 12 / 10.

Critical tests and the mutation that must make each fail:
- "a group that grows a row pushes the groups below, but not while one of them is under the mouse" and the randomized test: change `if anyBusy(others) then` to `if false then` in `redraw`.
- The randomized test: pass `nil` instead of `(busyCheck())` to `Layout.Apply` in `applyGroup`.
- "a group that disappears between layouts hides its buttons": delete `hideGone(old, pos)` in `v.Layout`.
- "the grid view shows each group's slots…" (its collapse half): `c.shown = c.shown` in `positionAll`.
- "1,290 slots: … a live change touches a few buttons": `render(pos)` instead of `renderMoved(v.pos, pos)` in `redraw`.
- "dropping an item on a section header calls onDrop once…": delete the `dropGuard == id` test in `owner.onClick`.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T7 i01 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
UI/SearchBox.lua
UI/TinyHost.lua
UI/BankWindow.lua
UI/GuildButtons.lua
```

and replace it with:

```text
UI/SearchBox.lua
UI/TinyHost.lua
UI/GroupView.lua
UI/BankWindow.lua
UI/GuildButtons.lua
```

<!-- sbw3:edit T7 i02 SwagBag/Engine/Layout.lua -->
In `SwagBag/Engine/Layout.lua`, find:

```lua
--   negative). Collapsing changes section offsets only, so expanding returns every item
--   to the same cell (spec 6.4). New always shows its header and newRows reserved rows.
--   opts: { columns, size, gap, padding, header, sectionGap }
--   pos = { cells = { {bag, slot, x, y, shown} } (display order), byKey = { [key] = cell },
--           placeholders = { {bag, slot, icon, x, y, shown} }, headers = { {id, y, count,
```

and replace it with:

```lua
--   negative). Collapsing changes section offsets only, so expanding returns every item
--   to the same cell (spec 6.4). New always shows its header and newRows reserved rows.
--   opts: { columns, size, gap, padding, header, sectionGap, top }   top: y offset where the
--   layout starts (a window that stacks several layouts, default 0); height includes it.
--   pos = { cells = { {bag, slot, x, y, shown} } (display order), byKey = { [key] = cell },
--           placeholders = { {bag, slot, icon, x, y, shown} }, headers = { {id, y, count,
```

<!-- sbw3:edit T7 i03 SwagBag/Engine/Layout.lua -->
In `SwagBag/Engine/Layout.lua`, find:

```lua
	local step = size + gap
	local pos = { cells = {}, byKey = {}, placeholders = {}, headers = {} }
	local y = pad
	for _, id in ipairs(st.order) do
		local sec = st.sections[id]
```

and replace it with:

```lua
	local step = size + gap
	local pos = { cells = {}, byKey = {}, placeholders = {}, headers = {} }
	local y = (opts.top or 0) + pad
	for _, id in ipairs(st.order) do
		local sec = st.sections[id]
```

<!-- sbw3:file T7 i04 SwagBag/UI/GroupView.lua -->
Create `SwagBag/UI/GroupView.lua`:

```lua
-- SwagBag group view (spec F2, F16, section 4): the contents of the bank window (two groups:
-- character bank and warband bank) and of the guild bank window (one group per tab). A view
-- is a stack of GROUPS in one scroll child. Each group has a header (name, item count,
-- collapse, a tint for "deposits go here") and under it either its own category sections
-- (New, categories, Free: one Engine/Layout.lua state per group) or, in the grid view, its
-- slots in physical order.
-- While the window is open the bags window's rules hold (spec 4.2, 4.3): a button moves only
-- into New or Free, never while it is under the mouse and never while an item is on the
-- cursor. A group that grows (Free gains a row) pushes the groups below it down; that push
-- waits too while one of the pushed buttons is under the mouse. Held-back work retries 300 ms
-- later through SB.Debounce (no OnUpdate). A redraw touches only the buttons whose cell
-- changed (Layout.Moves), so a 1,290-slot bank stays inside the spec 9 incremental budget.
--   local v = SB.GroupView.New(cfg)
--   v.Layout(reason) -> width, height   full layout (open, Reflow, sort, view toggle)
--   v.RequestLayout(reason) -> bool     the same, held back while an item is on the cursor
--                                       or the mouse is over the items (spec 4.3 rule 5)
--   v.Changes(groupId, list)            live changes { { bag, slot, kind, icon } }, kind
--                                       "left" | "arrived" | "added" | "removed" (Layout.Apply)
--   v.Restack() -> bool                 redraw after a collapse or expand (held back like a move)
--   v.ToggleSection(groupId, sectionId), v.ToggleGroup(groupId)
--   v.ForEachSlot(fn)                   fn(button, record, bag, slot) for every slot (search)
--   v.Record(bag, slot), v.SetRecord(bag, slot, record), v.GroupOf(bag), v.Size(bag), v.IsOpen()
--   v.Clear()                           window closed: hide the buttons, forget the layout
-- cfg = { key = "bank" | "guild", window = ErrorTrap window, child, scroll,
--   button(bag, slot) -> button | nil;  describe(bag, slot) -> record | nil (paints the button),
--   groups() -> { { id, bags = { { bag, size } } } } in display order,
--   groupLabel(groupId, collapsed, count) -> text;  groupTint(groupId) -> true to tint,
--   view() -> "sections" | "grid";  columns() -> n;  newRows() -> n,
--   onResize(width, height, keepTop);  onUpdated() optional, after a redraw while open,
--   onDrop(sectionId) optional: an item dropped on a section header,
--   sectionLabel(groupId, header) optional: header = { id, count, collapsed, overflow } }
-- Collapse state is saved per character in ui.collapsed[key .. ":" .. groupId] (sections)
-- and ui.collapsed[key .. ":#"] (whole groups).
local _, SB = ...

local GV = { SLOT = 37, GAP = 4, PAD = 4, SECTION_HEADER = 20, SECTION_GAP = 6, GROUP_HEADER = 22, GROUP_GAP = 8,
	RETRY = 0.3, DROP_GUARD = 0.3 }
SB.GroupView = GV

local function keyOf(bag, slot)
	return SB.Layout.Key(bag, slot)
end

function GV.New(cfg)
	local Guard = SB.ErrorTrap.Guard
	local v = { groups = {}, byId = {}, records = {}, cells = {}, placed = {}, sizes = {}, groupOf = {}, pos = nil,
		redrawPending = false, stats = {} }

	-- Collapse sets, saved per character.
	local function collapsedFor(id)
		local ui = SB.Config.UI()
		ui.collapsed = type(ui.collapsed) == "table" and ui.collapsed or {}
		local k = cfg.key .. ":" .. id
		ui.collapsed[k] = type(ui.collapsed[k]) == "table" and ui.collapsed[k] or {}
		return ui.collapsed[k]
	end
	v.Collapsed = collapsedFor

	local function groupClosed(gid)
		return collapsedFor("#")[gid] == true
	end

	local function positionOpts(top)
		return { columns = cfg.columns(), size = GV.SLOT, gap = GV.GAP, padding = GV.PAD, header = GV.SECTION_HEADER,
			sectionGap = GV.SECTION_GAP, top = top }
	end

	local function gridPos(g, top)
		local grid = SB.GridLayout.Compute(g.bags, { columns = cfg.columns(), size = GV.SLOT, gap = GV.GAP,
			padding = GV.PAD })
		local pos = { cells = {}, placeholders = {}, headers = {}, height = top + grid.height }
		for _, c in ipairs(grid.cells) do
			pos.cells[#pos.cells + 1] = { bag = c.bag, slot = c.slot, x = c.x, y = c.y - top, shown = true }
		end
		return pos
	end

	-- Pixel positions of every group, stacked top to bottom. Combined result:
	-- { cells, byKey, placeholders, headers = { { group, id, y, count, overflow, collapsed } },
	--   groupHeaders = { { id, y, count, collapsed } }, width, height }
	local function positionAll()
		local cols = cfg.columns()
		local all = { cells = {}, byKey = {}, placeholders = {}, headers = {}, groupHeaders = {},
			width = GV.PAD * 2 + cols * GV.SLOT + (cols - 1) * GV.GAP }
		local y = 0
		for _, g in ipairs(v.groups) do
			local closed = groupClosed(g.id)
			local header = { id = g.id, y = -y, count = 0, collapsed = closed }
			all.groupHeaders[#all.groupHeaders + 1] = header
			y = y + GV.GROUP_HEADER
			local pos
			if g.state then
				local col = collapsedFor(g.id)
				if closed then
					col = {}
					for _, sid in ipairs(g.state.order) do
						col[sid] = true
					end
				end
				pos = SB.Layout.Position(g.state, positionOpts(y), col)
			else
				pos = gridPos(g, y)
			end
			for _, c in ipairs(pos.cells) do
				c.shown = c.shown and not closed
				all.cells[#all.cells + 1] = c
				all.byKey[keyOf(c.bag, c.slot)] = c
				if v.records[keyOf(c.bag, c.slot)] then
					header.count = header.count + 1
				end
			end
			for _, p in ipairs(pos.placeholders) do
				p.shown = p.shown and not closed
				all.placeholders[#all.placeholders + 1] = p
			end
			if not closed then
				for _, h in ipairs(pos.headers) do
					h.group = g.id
					all.headers[#all.headers + 1] = h
				end
				y = pos.height
			end
			y = y + GV.GROUP_GAP
		end
		all.height = y
		return all
	end

	---------------------------------------------------------------------------
	-- Drawing
	---------------------------------------------------------------------------
	local function place(button, x, y)
		local at = x .. "," .. y
		if v.placed[button] ~= at then
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x, y)
			v.placed[button] = at
		end
	end

	-- A cell past its bag's current size (a removal still held back) is never shown.
	local function inSize(c)
		return c.slot <= (v.sizes[c.bag] or 0)
	end

	local function showAt(button, c)
		if c.shown and inSize(c) then
			place(button, c.x, c.y)
			button:Show()
		else
			button:Hide()
		end
	end

	-- Header clicks: collapse; with an item on the cursor (or dragged onto a section header)
	-- the item is dropped (cfg.onDrop). The click that follows a drop on the same header in
	-- one press is ignored for DROP_GUARD seconds, as in the bags window.
	local dropGuard, dropToken = nil, 0
	local function parseId(id)
		if id:sub(1, 1) == "#" then
			return id:sub(2), nil
		end
		return id:match("^(.-):(.*)$")
	end

	local function drop(id)
		dropToken = dropToken + 1
		local token = dropToken
		dropGuard = id
		SB.Adapter.After(GV.DROP_GUARD, Guard(cfg.key .. ".dropGuard", function()
			if token == dropToken then
				dropGuard = nil
			end
		end, cfg.window))
		local _, sid = parseId(id)
		if sid and cfg.onDrop then
			cfg.onDrop(sid)
		end
	end

	local owner = {}
	function owner.onClick(id)
		if dropGuard == id then
			return
		end
		if SB.Adapter.CursorItem() then
			drop(id)
			return
		end
		local gid, sid = parseId(id)
		if sid then
			v.ToggleSection(gid, sid)
		else
			v.ToggleGroup(gid)
		end
	end

	function owner.onDrop(id)
		if dropGuard ~= id then
			drop(id)
		end
	end

	local function sectionLabel(gid, h)
		if cfg.sectionLabel then
			return cfg.sectionLabel(gid, h)
		end
		return SB.SectionHeaders.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow)
	end

	-- Placeholders and headers are few: they are redrawn whole, inside this view's child only.
	local function renderExtras(pos)
		local B, H, child = SB.Buttons, SB.SectionHeaders, cfg.child
		local width = pos.width - 2 * GV.PAD
		B.ReleasePlaceholders(child)
		for _, p in ipairs(pos.placeholders) do
			if p.shown then
				B.AcquirePlaceholder(child, p.icon, GV.SLOT, p.x, p.y)
			end
		end
		H.ReleaseAll(child)
		for _, g in ipairs(pos.groupHeaders) do
			local h = H.Acquire(child, "#" .. g.id, cfg.groupLabel(g.id, g.collapsed, g.count), GV.PAD, g.y, width, owner)
			if cfg.groupTint and cfg.groupTint(g.id) then
				h.bg:SetColorTexture(0.25, 0.85, 0.35, 0.3)
			end
		end
		for _, h in ipairs(pos.headers) do
			H.Acquire(child, h.group .. ":" .. h.id, sectionLabel(h.group, h), GV.PAD, h.y, width, owner)
		end
	end

	local function cellsOf(pos)
		local cells = {}
		for _, c in ipairs(pos.cells) do
			if inSize(c) then
				cells[#cells + 1] = c
			end
		end
		return cells
	end

	local function render(pos)
		for _, c in ipairs(pos.cells) do
			local button = cfg.button(c.bag, c.slot)
			if button then
				showAt(button, c)
			end
		end
		v.cells = cellsOf(pos)
		renderExtras(pos)
		v.pos = pos
	end

	local function hideGone(old, pos)
		for k, c in pairs(old.byKey) do
			if not pos.byKey[k] then
				local button = cfg.button(c.bag, c.slot)
				if button then
					button:Hide()
				end
			end
		end
	end

	local function renderMoved(old, pos)
		for _, k in ipairs(SB.Layout.Moves(old, pos)) do
			local c = pos.byKey[k]
			local button = cfg.button(c.bag, c.slot)
			if button then
				showAt(button, c)
			end
		end
		hideGone(old, pos)
		v.cells = cellsOf(pos)
		renderExtras(pos)
		v.pos = pos
	end

	---------------------------------------------------------------------------
	-- Rule 5: nothing moves under the mouse or while an item is on the cursor
	---------------------------------------------------------------------------
	local function busyCheck()
		local cursor = SB.Adapter.CursorItem() ~= nil
		return function(bag, slot)
			if cursor then
				return true
			end
			local b = cfg.button(bag, slot)
			return b ~= nil and b:IsShown() and b:IsMouseOver()
		end, cursor
	end

	local function anyBusy(keys)
		local busy, cursor = busyCheck()
		if cursor then
			return true
		end
		for _, k in ipairs(keys) do
			if busy(math.floor(k / 1000), k % 1000) then
				return true
			end
		end
		return false
	end

	---------------------------------------------------------------------------
	-- Full layout
	---------------------------------------------------------------------------
	function v.Layout(reason)
		local A = SB.Adapter
		local t0 = A.ProfileMs()
		local old = v.pos
		v.groups, v.byId, v.records, v.sizes, v.groupOf, v.redrawPending = {}, {}, {}, {}, {}, false
		local sections = cfg.view() ~= "grid"
		local order = sections and SB.Categories.SectionOrder() or nil
		for _, def in ipairs(cfg.groups()) do
			local g = { id = def.id, bags = def.bags }
			local slots = {}
			for _, b in ipairs(def.bags) do
				v.sizes[b.bag], v.groupOf[b.bag] = b.size, def.id
				for slot = 1, b.size do
					if cfg.button(b.bag, slot) then
						local record = cfg.describe(b.bag, slot)
						v.records[keyOf(b.bag, slot)] = record
						slots[#slots + 1] = { bag = b.bag, slot = slot, record = record }
					end
				end
			end
			if sections then
				g.state = SB.Layout.Build(slots, SB.Categorizer.Assign, order,
					{ columns = cfg.columns(), newRows = cfg.newRows() })
			end
			v.groups[#v.groups + 1] = g
			v.byId[g.id] = g
		end
		local pos = positionAll()
		if old then
			hideGone(old, pos)
		end
		render(pos)
		cfg.onResize(pos.width, pos.height, reason ~= "open")
		v.stats.lastLayoutMs = A.ProfileMs() - t0
		v.stats.lastLayoutReason = reason
		return pos.width, pos.height
	end

	function v.RequestLayout(reason)
		if not v.pos then
			return false
		end
		if SB.Adapter.CursorItem() or (cfg.scroll and cfg.scroll:IsMouseOver()) then
			SB.Debounce(cfg.key .. ".layout", GV.RETRY, function()
				v.RequestLayout(reason)
			end, cfg.window)
			return false
		end
		v.Layout(reason)
		return true
	end

	---------------------------------------------------------------------------
	-- Live changes (spec 4.3)
	---------------------------------------------------------------------------
	local function applyGroup(g, list)
		if not g.state then
			return { moved = {}, deferred = 0 }
		end
		return SB.Layout.Apply(g.state, list, (busyCheck()), collapsedFor(g.id))
	end

	local function overflowOf(g)
		local new = g.state and g.state.sections[SB.Layout.NEW]
		return new and new.overflow or 0
	end

	-- Redraw. Buttons that would shift with no change of their own (a group above grew) wait
	-- while one of them is under the mouse or an item is on the cursor.
	local function redraw(exempt)
		local pos = positionAll()
		local others = {}
		for _, k in ipairs(SB.Layout.Moves(v.pos, pos)) do
			if not exempt[k] then
				others[#others + 1] = k
			end
		end
		if anyBusy(others) then
			v.redrawPending = true
			v.stats.heldRedraws = (v.stats.heldRedraws or 0) + 1
			SB.Debounce(cfg.key .. ".retry", GV.RETRY, v.Retry, cfg.window)
			return false
		end
		v.redrawPending = false
		renderMoved(v.pos, pos)
		cfg.onResize(pos.width, pos.height, true)
		if cfg.onUpdated then
			cfg.onUpdated()
		end
		return true
	end

	function v.Changes(gid, list)
		local g = v.byId[gid]
		if not (g and v.pos) then
			return
		end
		local before = overflowOf(g)
		local res = applyGroup(g, list)
		local exempt = {}
		for _, k in ipairs(res.moved) do
			exempt[k] = true
		end
		if #res.moved > 0 or overflowOf(g) ~= before or v.redrawPending then
			redraw(exempt)
		end
		if res.deferred > 0 then
			SB.Debounce(cfg.key .. ".retry", GV.RETRY, v.Retry, cfg.window)
		end
	end

	-- 300 ms after something was held back: every group's waiting changes, then the redraw.
	function v.Retry()
		if not v.pos then
			return
		end
		local exempt, again, any = {}, false, v.redrawPending
		for _, g in ipairs(v.groups) do
			if g.state and #g.state.deferred > 0 then
				local res = applyGroup(g, {})
				for _, k in ipairs(res.moved) do
					exempt[k] = true
				end
				any = any or #res.moved > 0
				again = again or res.deferred > 0
			end
		end
		if any then
			redraw(exempt)
		end
		if again then
			SB.Debounce(cfg.key .. ".retry", GV.RETRY, v.Retry, cfg.window)
		end
	end

	---------------------------------------------------------------------------
	-- Collapse
	---------------------------------------------------------------------------
	function v.Restack()
		if not v.pos then
			return true
		end
		local pos = positionAll()
		if anyBusy(SB.Layout.Moves(v.pos, pos)) then
			SB.Debounce(cfg.key .. ".restack", GV.RETRY, v.Restack, cfg.window)
			return false
		end
		renderMoved(v.pos, pos)
		cfg.onResize(pos.width, pos.height, true)
		if cfg.onUpdated then
			cfg.onUpdated()
		end
		return true
	end

	function v.ToggleSection(gid, sid)
		local set = collapsedFor(gid)
		set[sid] = not set[sid] or nil
		return v.Restack()
	end

	function v.ToggleGroup(gid)
		local set = collapsedFor("#")
		set[gid] = not set[gid] or nil
		return v.Restack()
	end

	---------------------------------------------------------------------------
	-- Access
	---------------------------------------------------------------------------
	function v.ForEachSlot(fn)
		for _, c in ipairs(v.cells) do
			local button = cfg.button(c.bag, c.slot)
			if button then
				fn(button, v.records[keyOf(c.bag, c.slot)], c.bag, c.slot)
			end
		end
	end

	function v.Record(bag, slot)
		return v.records[keyOf(bag, slot)]
	end

	function v.SetRecord(bag, slot, record)
		v.records[keyOf(bag, slot)] = record
	end

	function v.GroupOf(bag)
		return v.groupOf[bag]
	end

	function v.Size(bag)
		return v.sizes[bag]
	end

	function v.IsOpen()
		return v.pos ~= nil
	end

	function v.Clear()
		if v.pos then
			for _, c in ipairs(v.pos.cells) do
				local button = cfg.button(c.bag, c.slot)
				if button then
					button:Hide()
				end
			end
		end
		v.groups, v.byId, v.pos, v.cells, v.redrawPending = {}, {}, nil, {}, false
		SB.Buttons.ReleasePlaceholders(cfg.child)
		SB.SectionHeaders.ReleaseAll(cfg.child)
	end

	return v
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/groupview_spec.lua spec/layout_spec.lua`
Expected: `44 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (40 files)`, `536 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/groupview_spec.lua \
  spec/layout_spec.lua \
  SwagBag/SwagBag.toc \
  SwagBag/Engine/Layout.lua \
  SwagBag/UI/GroupView.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 7: GroupView, stacked groups with their own sections and a hover guard across groups" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 8: Bank window contents: Character bank and Warband bank groups, deposit highlight, live updates, Sort per bank type, Reflow, grid, search

This task fills Task 1's window (spec F2, §5.1).

**Groups and highlight.** A `GroupView` holds two groups, `"bank"` (Character bank) and `"warband"` (Warband bank). Each lists the purchased tabs the client reports, never a hardcoded count. The group that receives deposits is tinted, and its header ends with `  - deposits go here` (AC2.3). A tab click moves that highlight with `v.Relabel()`, and nothing moves.

**Opening.** The bank tabs' bag frames move into this window's scroll child (`Buttons.SetParentFor("bank"/"warband", child)`; Task 5 made that work after login). `Inventory.ScanKind` rescans the bank on `BANKFRAME_OPENED` without marking anything "new": what was already in the bank is not a new arrival.

**Live updates (spec §4.3).** While open, a deposit shows in that group's New, a withdrawal leaves a placeholder and its button goes to that group's Free, and count/lock/load changes repaint in place. A same-itemID link change (a keystone after a run) is a repaint, not an arrival (week-2 W12).

**Tabs bought during the visit.** A bank tab bought (or changed) during the visit lays the bank out again. Two paths lead there: the `SIZE` reason from `BAG_UPDATE`, and the feature-detected `BANK_TAB_SETTINGS_UPDATED` (spec §9, §13.2 item 6). Both run `Buttons.EnsureBankTabs`.

**Sort.** `Sort bank` and `Sort warband` call `Adapter.SortBank(kind)` (spec §5.5, D12). The window regroups 0.3 s after the last bank update, held back while the mouse is over the items. In combat a Sort says `Sort after combat ends` and nothing runs later (week-2 ruling W11). A sort that changes nothing stops waiting after 1.5 s.

**Buttons, search and drops.** `Reflow` and `Grid`/`Categories` work as in the bags window. The window has its own search box (Task 6). A drop on a bank section header goes to the bags window's drag-to-assign (D13).

**Report.** The report gains `Last bank layout: … ms (open)` for the 80 ms budget (spec §9).

The bank buttons get their overlays in Task 11, once the guild bank has contents too.

The task also adds `spec/helpers/uienv.lua`, the shared set-up of the window specs (this task's and Tasks 10, 11 and 12): the engine file list, the paint globals and loading the bank window. It also adds the Review Focus 1 test: the real bags window and the real bank window open together, and a bags redraw never takes the bank's headers or placeholders.

**Files:**
- Modify: `SwagBag/UI/BankWindow.lua`, `SwagBag/UI/GroupView.lua` (`Relabel`), `SwagBag/Core/Adapter.lua` (`SortBank`, optional check), `SwagBag/Engine/Inventory.lua` (`ScanKind`), `SwagBag/Core/Config.lua` (`bank.view`, `bank.columns`), `SwagBag/Locale/enUS.lua`, `SwagBag/Core/Report.lua`
- Test: `spec/mock_adapter.lua`, `spec/helpers/uienv.lua` (new), `spec/bankwindow_spec.lua`, `spec/bankwindow_groups_spec.lua` (new), `spec/report_spec.lua`

**Interfaces:**
- Consumes:
  - Task 1: `SB.BankWindow` (frame, mode, target, `Flash`, `TitleButton`, `GroupName`);
  - Task 5: `SB.Buttons.SetParentFor/EnsureBankTabs/ReleasePlaceholders(parent)`;
  - Task 6: `SB.SearchState.New`, `SB.SearchBox.New`;
  - Task 7: `SB.GroupView.New`;
  - on `main`: `SB.BagsWindow.DropOnSection(id)`, `SB.Inventory.OnChanged/Has/R`, `SB.Items.Describe`.
- Produces:
  - `SB.Adapter.SortBank(kind) -> ok, err` and `SB.Inventory.ScanKind(kind)`.
  - `SB.BankWindow` gains:
    - `view` (a GroupView), `searchBox`, `scroll`, `child`, `sortPending`, `sortSawUpdate`;
    - `View() -> "sections"|"grid"`, `Layout(reason)`, `Sort(kind) -> bool`, `Reflow(reason) -> bool`, `ToggleView()`;
    - buttons `viewButton`, `reflowButton`, `sortBankButton`, `sortWarbandButton`.
  - `GroupView` gains `v.Relabel()`.
  - Settings `bank.view` and `bank.columns`. Report line `Last bank layout: %.1f ms (%s)`.
  - `spec/helpers/uienv.lua`: `Env.ENGINE`, `Env.PaintGlobals()`, `Env.ClearPaintGlobals()`, `Env.FakeBags(SB)`, `Env.LoadBank(SB)` (loads the search box, GroupView and bank window together).

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:file T8 s01 spec/helpers/uienv.lua -->
Create `spec/helpers/uienv.lua`:

```lua
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
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
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
	SB.BagsWindow = bags
	return bags
end

-- Load the bank window (and the UI files it uses) into SB. Fake.Install() must have run.
function Env.LoadBank(SB)
	if not SB.BagsWindow then
		Env.FakeBags(SB)
	end
	for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/SearchBox.lua",
		"SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua" }) do
		Loader.LoadFile(SB, path)
	end
	return SB.BankWindow
end

return Env
```

<!-- sbw3:edit T8 s02 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
	function m.SortBags()
		m.sorts = m.sorts + 1
		return true
	end
```

and replace it with:

```lua
	function m.SortBags()
		m.sorts = m.sorts + 1
		return true
	end

	m.bankSorts = {}
	function m.SortBank(kind)
		m.bankSorts[#m.bankSorts + 1] = kind
		return true
	end
```

<!-- sbw3:file T8 s03 spec/bankwindow_groups_spec.lua -->
Create `spec/bankwindow_groups_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The bank window's contents (spec F2): the Character bank and Warband bank groups over the
-- real engine and button pool, deposits and withdrawals while open (spec 4.3), the deposit
-- highlight, Sort per bank type, Reflow, its own search, and the first-open budget.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Big = dofile("spec/fixtures/big.lua")

local function blizzardBank()
	local bf = Fake.New("Frame", UIParent)
	bf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	bf.TabSystem = Fake.New("Frame", bf)
	bf.TabSystem.tabs = { Fake.New("Button", bf.TabSystem), Fake.New("Button", bf.TabSystem) }
	return bf
end

describe("BankWindow contents", function()
	local SB, A, BW, B, bf
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		Fake.Install()
		Env.PaintGlobals()
		bf = blizzardBank()
		A.frames.BankFrame = bf
		A.activeBankType = "bank"
		BW = Env.LoadBank(SB)
		B = SB.Buttons
		SB.Emit("SB_LOGIN") -- the pool and the session scan; the bank reads 0 slots away from a banker
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.Put(6, 1, Fixtures.HEALING_POTION, 5)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(12, 1, Fixtures.ORE, 10)
		A.Put(12, 2, Fixtures.BOE_RING, 1)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openBank()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	local function bankUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function header(id)
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId == id then
				return h
			end
		end
	end

	local function labels()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	local function at(bag, slot)
		local p = B.Get(bag, slot).points
		p = p[#p]
		return { p[4], p[5] }
	end

	it("a bank visit shows Character bank on top and Warband bank below, each with its own sections", function()
		openBank()
		assert.same({ "- Character bank (2)  - deposits go here", "- Warband bank (2)",
			"- New (0)", "- Consumables (1)", "- Herbs (1)", "- Free (6)",
			"- New (0)", "- BoE gear (1)", "- Ore (1)", "- Free (6)" }, labels())
		assert.truthy(B.Get(6, 1).shown)
		assert.equal(BW.child, B.frames[6].parent, "the bank tab's bag frame lives in the bank window")
		assert.equal(16, #BW.view.cells)
		assert.equal("open", BW.view.stats.lastLayoutReason)
	end)

	it("the group that receives deposits is tinted; a tab click moves the highlight to the other group", function()
		openBank()
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#bank").bg.calls.SetColorTexture)
		A.activeBankType = "warband"
		Fake.Fire(bf.TabSystem.tabs[2], "OnClick")
		A.Advance(0)
		assert.equal("- Warband bank (2)  - deposits go here", header("#warband").text.text)
		assert.equal("- Character bank (2)", header("#bank").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
	end)

	it("a deposit shows in that group's New; nothing else moves", function()
		openBank()
		local before = { at(6, 1), at(6, 2), at(12, 1), at(12, 2) }
		A.Put(6, 5, Fixtures.FLASK, 2) -- a bag item right-clicked into the character bank
		bankUpdate(6)
		assert.equal(header("bank:new").points[1][5] - 20, at(6, 5)[2], "first cell of New")
		assert.same(before, { at(6, 1), at(6, 2), at(12, 1), at(12, 2) })
		assert.equal("- Character bank (3)  - deposits go here", header("#bank").text.text)
	end)

	it("a withdrawal leaves a placeholder in its group; the button goes to that group's Free", function()
		openBank()
		local herbAt = at(6, 2)
		A.Clear(6, 2)
		bankUpdate(6)
		assert.equal(1, #B.placeholdersInUse)
		assert.truthy(at(6, 2)[2] < herbAt[2])
		assert.equal("- Free (7)", header("bank:free").text.text)
		A.Clear(12, 2)
		bankUpdate(12)
		assert.equal(2, #B.placeholdersInUse)
		assert.equal("- Free (7)", header("warband:free").text.text, "the warband item went to the warband's Free")
		assert.truthy(at(12, 2)[2] < header("warband:free").points[1][5])
	end)

	it("Sort bank sorts the character bank and regroups after the bank settles; Sort warband sorts the warband", function()
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		assert.same({ "bank" }, A.bankSorts)
		assert.equal(SB.L.SORT_STARTED, BW.frame.title.text)
		A.Put(6, 1, Fixtures.HERB, 20)
		A.Put(6, 2, Fixtures.HEALING_POTION, 5)
		bankUpdate(6)
		A.Advance(0.3)
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		assert.equal(0, #B.placeholdersInUse)
		Fake.Fire(BW.sortWarbandButton, "OnClick")
		assert.same({ "bank", "warband" }, A.bankSorts)
	end)

	it("a second Sort during a settle keeps the first sort's regroup; a sort that changes nothing stops waiting", function()
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		A.Clear(6, 1)
		bankUpdate(6)
		Fake.Fire(BW.sortWarbandButton, "OnClick")
		A.Advance(BW.SORT_TIMEOUT + 0.1)
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		assert.falsy(BW.sortPending)
		Fake.Fire(BW.sortBankButton, "OnClick")
		A.Advance(BW.SORT_TIMEOUT + 0.1)
		assert.falsy(BW.sortPending)
		BW.view.stats.lastLayoutReason = "marker"
		A.Put(6, 7, Fixtures.JUNK, 1)
		bankUpdate(6)
		A.Advance(1)
		assert.equal("marker", BW.view.stats.lastLayoutReason, "no regroup after the sort timed out")
	end)

	it("sorting in combat shows feedback and does nothing, now or after combat (W11)", function()
		openBank()
		A.combat = true
		Fake.Fire(BW.sortBankButton, "OnClick")
		assert.same({}, A.bankSorts)
		assert.equal(SB.L.SORT_AFTER_COMBAT, BW.frame.title.text)
		assert.equal(0, SB.OutOfCombatPending())
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(5)
		assert.same({}, A.bankSorts)
	end)

	it("a failing bank sort says so, records the error, and never claims it started", function()
		openBank()
		A.SortBank = function() return false, "boom" end
		Fake.Fire(BW.sortBankButton, "OnClick")
		assert.equal(SB.L.SORT_UNAVAILABLE, BW.frame.title.text)
		assert.equal("boom", SB.ErrorTrap.Recent()[1].message)
		assert.falsy(SB.SafeMode.IsOn("bank"))
		assert.falsy(BW.sortPending)
	end)

	it("Reflow regroups, but waits while the mouse is over the items", function()
		openBank()
		A.Clear(6, 2)
		bankUpdate(6)
		BW.scroll.mouseOver = true
		Fake.Fire(BW.reflowButton, "OnClick")
		assert.equal(SB.L.REFLOW_WAITING, BW.frame.title.text)
		assert.equal(1, #B.placeholdersInUse)
		BW.scroll.mouseOver = false
		A.Advance(0.3)
		assert.equal(0, #B.placeholdersInUse)
		assert.equal("reflow", BW.view.stats.lastLayoutReason)
	end)

	it("the bank's search box dims bank slots only; the bags search is separate", function()
		openBank()
		BW.searchBox.editBox:SetText("ore")
		Fake.Fire(BW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
		assert.equal(1, B.Get(12, 1).alpha)
		assert.equal(B.DIM_ALPHA, B.Get(6, 1).alpha)
		assert.equal("", SB.Search.text, "the bags window's search is untouched")
	end)

	it("the grid view shows each group in physical order", function()
		SB.Config.Set("bank.view", "grid")
		openBank()
		assert.same({ "- Character bank (2)  - deposits go here", "- Warband bank (2)" }, labels())
		assert.equal(SB.L.VIEW_TO_SECTIONS, BW.viewButton.text)
		Fake.Fire(BW.viewButton, "OnClick")
		assert.equal("sections", SB.Config.Get("bank.view"))
		assert.equal(10, #labels())
	end)

	it("closing the bank forgets the layout; the next visit rebuilds it and keeps collapse state", function()
		openBank()
		header("bank:c_herbs").scripts.OnClick(header("bank:c_herbs"))
		A.Clear(6, 1)
		bankUpdate(6)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.falsy(BW.view.IsOpen())
		assert.equal(0, #B.placeholdersInUse)
		openBank()
		assert.equal("+ Herbs (1)", header("bank:c_herbs").text.text)
		assert.equal(0, #B.placeholdersInUse)
	end)

	it("what is already in the bank at a visit is not marked new", function()
		openBank()
		assert.equal(false, BW.view.Record(6, 1).isNew)
		assert.equal(false, BW.view.Record(12, 2).isNew)
		A.Put(6, 5, Fixtures.FLASK, 1)
		bankUpdate(6)
		assert.equal(true, BW.view.Record(6, 5).isNew, "a deposit during the visit is new")
	end)

	it("a bank tab bought during the visit gets its buttons and the bank is laid out again", function()
		openBank()
		A.bagIDs.bank = { 6, 7 }
		A.SetBagSize(7, 4)
		A.Put(7, 1, Fixtures.JUNK, 2)
		bankUpdate(7)
		assert.equal(98, B.Count(7))
		assert.equal("size", BW.view.stats.lastLayoutReason)
		assert.truthy(B.Get(7, 1).shown)
	end)

	it("a bank tab change during the visit (BANK_TAB_SETTINGS_UPDATED) lays the bank out again", function()
		openBank()
		A.bagIDs.warband = { 12, 13 }
		A.SetBagSize(13, 98)
		A.Put(13, 1, Fixtures.BOE_RING, 1)
		SB.eventFrame:Fire("BANK_TAB_SETTINGS_UPDATED")
		assert.equal("tabs", BW.view.stats.lastLayoutReason)
		assert.truthy(B.Get(13, 1).shown)
		assert.equal(false, BW.view.Record(13, 1).isNew, "not new: it was there when the tab appeared")
	end)

	it("an item dropped on a bank section header goes to the bags window's drag-to-assign", function()
		openBank()
		A.cursor = { itemID = Fixtures.JUNK }
		header("bank:c_herbs").scripts.OnReceiveDrag(header("bank:c_herbs"))
		assert.same({ "c_herbs" }, SB.BagsWindow.dropped)
	end)

	it("the first visit to a full bank (1,078 slots) is laid out within 80 ms (spec 9)", function()
		Big.Install(A)
		local t0 = os.clock()
		openBank()
		local ms = (os.clock() - t0) * 1000
		assert.equal(1078, #BW.view.cells)
		assert.truthy(ms <= 80, ("first bank open took %.1f ms"):format(ms))
	end)
end)

describe("Bags and bank windows open together (Review Focus 1)", function()
	local SB, A, B, W, BW
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		Fake.Install()
		Env.PaintGlobals()
		A.frames.BankFrame = blizzardBank()
		A.activeBankType = "bank"
		for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/BagsWindow.lua",
			"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua" }) do
			Loader.LoadFile(SB, path)
		end
		B, W, BW = SB.Buttons, SB.BagsWindow, SB.BankWindow
		SB.Emit("SB_LOGIN")
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.Put(6, 1, Fixtures.HERB, 20)
		A.Put(12, 1, Fixtures.ORE, 10)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function bankHeaders()
		local n = 0
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown and h.sectionId:find("[#:]") then
				n = n + 1
			end
		end
		return n
	end

	it("a bags redraw (Reflow, a bag change) never takes the bank window's headers or placeholders", function()
		W.Open()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		local headers = bankHeaders()
		assert.truthy(headers >= 8)
		A.Clear(6, 1) -- a withdrawal leaves a placeholder in the bank window
		SB.eventFrame:Fire("BAG_UPDATE", 6)
		A.Put(0, 10, Fixtures.HERB, 20) -- ... and the herb lands in the bags
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
		local bankPlaceholder = B.placeholdersInUse[1]
		assert.truthy(bankPlaceholder and bankPlaceholder.shown)
		W.Reflow("reflow")
		assert.equal(headers, bankHeaders(), "the bank's headers survived the bags regroup")
		assert.truthy(bankPlaceholder.shown, "and so did its placeholder")
		BW.Reflow("reflow")
		assert.truthy(#SB.SectionHeaders.inUse > headers, "the bags window kept its headers too")
	end)
end)
```

<!-- sbw3:edit T8 s04 spec/bankwindow_spec.lua -->
In `spec/bankwindow_spec.lua`, find:

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")

local FILES = { "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
	"SwagBag/Core/Config.lua", "SwagBag/Core/Slash.lua" }

-- Blizzard's bank as Blizzard shows it: parented to UIParent, two real tabs underneath.
```

and replace it with:

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

local FILES = Env.ENGINE

-- Blizzard's bank as Blizzard shows it: parented to UIParent, two real tabs underneath.
```

<!-- sbw3:edit T8 s05 spec/bankwindow_spec.lua -->
In `spec/bankwindow_spec.lua`, find:

```lua
		A.frames.BankFrame = bf
		A.activeBankType = "bank"
		SB.BagsWindow = { frame = Fake.New("Frame", UIParent), sortButton = Fake.New("Button") }
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BankWindow.lua")
		BW = SB.BankWindow
	end)

	after_each(function()
		Fake.Uninstall()
	end)

```

and replace it with:

```lua
		A.frames.BankFrame = bf
		A.activeBankType = "bank"
		Env.PaintGlobals()
		BW = Env.LoadBank(SB)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

```

<!-- sbw3:edit T8 s06 spec/bankwindow_spec.lua -->
In `spec/bankwindow_spec.lua`, find:

```lua
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		SB.BagsWindow = { frame = Fake.New("Frame", UIParent), sortButton = Fake.New("Button") }
		Loader.LoadFile(SB, "SwagBag/UI/TinyHost.lua")
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/BankWindow.lua")
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
```

and replace it with:

```lua
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		local ok, err = pcall(Env.LoadBank, SB)
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
```

<!-- sbw3:edit T8 s07 spec/report_spec.lua -->
In `spec/report_spec.lua`, find:

```lua
		assert.truthy(SB.Report.Build():find("\nBank: setting tiny, last visit beside, last deposit target Warband bank",
			1, true))
	end)

```

and replace it with:

```lua
		assert.truthy(SB.Report.Build():find("\nBank: setting tiny, last visit beside, last deposit target Warband bank",
			1, true))
		SB.BankWindow.view = { stats = { lastLayoutMs = 61.27, lastLayoutReason = "open" } }
		assert.truthy(SB.Report.Build():find("\nLast bank layout: 61.3 ms (open)", 1, true), "spec 9: first bank open")
	end)

```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/bankwindow_groups_spec.lua spec/bankwindow_spec.lua spec/report_spec.lua`
Expected: `24 passed, 19 failed`. The window has no contents, sort or search yet.

Critical tests and the mutation that must make each fail:
- "what is already in the bank at a visit is not marked new": delete `Inv.scanned = false` in `Inv.ScanKind`.
- "the group that receives deposits is tinted; a tab click moves the highlight…": delete `BW.view.Relabel()` in `BW.RefreshTarget`.
- "sorting in combat shows feedback and does nothing, now or after combat (W11)": queue `A.SortBank(kind)` with `SB.OutOfCombat` in the combat branch.
- "a withdrawal leaves a placeholder in its group…" (its warband half): `local gid = v.GroupOf(c.bag) and 'bank'` in the inventory listener.
- "a bank tab bought during the visit gets its buttons…": delete `B.EnsureBankTabs()` in the `SIZE` branch.
- "Sort bank sorts the character bank and regroups after the bank settles…": delete `BW.Reflow("sort")` from the settle debounce.
- "a second Sort during a settle keeps the first sort's regroup…": `if false then` instead of `if saw then`.
- "a bags redraw (Reflow, a bag change) never takes the bank window's headers or placeholders": `H.ReleaseAll()` (no parent), or `B.ReleasePlaceholders()`, in the bags window's `renderExtras`.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T8 i01 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
end

---------------------------------------------------------------------------
-- Blizzard frames and the bank (week 3). SwagBag only READS Blizzard's bank state
```

and replace it with:

```lua
end

-- Blizzard's own bank sort for "bank" (character bank) or "warband" (spec 5.5). ok, err.
function A.SortBank(kind)
	local BT = Enum and Enum.BankType
	local bankType = BT and ((kind == "bank" and BT.Character) or (kind == "warband" and BT.Account))
	if bankType == nil or not (C_Container and C_Container.SortBank) then
		return false
	end
	return pcall(C_Container.SortBank, bankType)
end

---------------------------------------------------------------------------
-- Blizzard frames and the bank (week 3). SwagBag only READS Blizzard's bank state
```

<!-- sbw3:edit T8 i02 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
	{ path = "C_Container.GetContainerItemQuestInfo", window = "bags", required = false },
	{ path = "C_Container.SortBags", window = "bags", required = false },
	{ path = "GetCursorInfo", window = "bags", required = false },
	{ path = "ClearCursor", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "C_Container.GetContainerItemQuestInfo", window = "bags", required = false },
	{ path = "C_Container.SortBags", window = "bags", required = false },
	{ path = "C_Container.SortBank", window = "bank", required = false },
	{ path = "GetCursorInfo", window = "bags", required = false },
	{ path = "ClearCursor", window = "bags", required = false },
```

<!-- sbw3:edit T8 i03 SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
		-- blizzardFrame: "tiny" (Blizzard's bank invisible, its tabs on SwagBag's window) |
		-- "beside" (Blizzard's bank visible, SwagBag's window next to it; spec 5.4, check V2).
		bank = { blizzardFrame = "tiny" },
		-- mode: "full" (SwagBag's window replaces Blizzard's; spec F16) | "view" (read-only window
		-- with Blizzard's frame beside it; the fallback if check G1 fails). withdrawAnyTab: a
```

and replace it with:

```lua
		-- blizzardFrame: "tiny" (Blizzard's bank invisible, its tabs on SwagBag's window) |
		-- "beside" (Blizzard's bank visible, SwagBag's window next to it; spec 5.4, check V2).
		-- view: "sections" | "grid"; columns: slots per row in the bank window.
		bank = { blizzardFrame = "tiny", view = "sections", columns = 14 },
		-- mode: "full" (SwagBag's window replaces Blizzard's; spec F16) | "view" (read-only window
		-- with Blizzard's frame beside it; the fallback if check G1 fails). withdrawAnyTab: a
```

<!-- sbw3:edit T8 i04 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SETTINGS_READONLY = "SwagBag's saved settings are read-only, so nothing was changed."
L.REPORT_BANK = "Bank: setting %s, last visit %s, last deposit target %s"

-- Guild bank window (spec F16)
```

and replace it with:

```lua
L.SETTINGS_READONLY = "SwagBag's saved settings are read-only, so nothing was changed."
L.REPORT_BANK = "Bank: setting %s, last visit %s, last deposit target %s"
L.BANK_GROUP_LABEL = "%s %s (%d)"
L.BANK_GROUP_TARGET = "  - deposits go here"
L.BTN_SORT_BANK = "Sort bank"
L.BTN_SORT_WARBAND = "Sort warband"
L.BANK_VIEW_GRID = "SwagBag bank - grid view"
L.BANK_VIEW_SECTIONS = "SwagBag bank - category view"
L.REPORT_BANK_LAYOUT = "Last bank layout: %.1f ms (%s)"

-- Guild bank window (spec F16)
```

<!-- sbw3:edit T8 i05 SwagBag/Engine/Inventory.lua -->
In `SwagBag/Engine/Inventory.lua`, find:

```lua
end

-- Initial full scan (no "new" marking). Called on SB_LOGIN.
function Inv.ScanAll()
```

and replace it with:

```lua
end

-- Rescan every bag of a kind without marking anything "new". The character bank can only be
-- read at a banker (spec 5.7), so what is in it at a visit is not a new arrival.
function Inv.ScanKind(kind)
	local was = Inv.scanned
	Inv.scanned = false
	for _, bag in ipairs(SB.Adapter.GetBagIDs(kind)) do
		Inv.ScanBag(bag)
		Inv.dirty[bag] = nil
	end
	Inv.scanned = was
end

-- Initial full scan (no "new" marking). Called on SB_LOGIN.
function Inv.ScanAll()
```

<!-- sbw3:edit T8 i06 SwagBag/Engine/Inventory.lua -->
In `SwagBag/Engine/Inventory.lua`, find:

```lua
	Inv.ScanAll()
end, "bags")
```

and replace it with:

```lua
	Inv.ScanAll()
end, "bags")

SB.On("BANKFRAME_OPENED", function()
	Inv.ScanKind("bank")
	Inv.ScanKind("warband")
end, "bank")
```

<!-- sbw3:edit T8 i07 SwagBag/UI/GroupView.lua -->
In `SwagBag/UI/GroupView.lua`, find:

```lua
--   v.Restack() -> bool                 redraw after a collapse or expand (held back like a move)
--   v.ToggleSection(groupId, sectionId), v.ToggleGroup(groupId)
--   v.ForEachSlot(fn)                   fn(button, record, bag, slot) for every slot (search)
--   v.Record(bag, slot), v.SetRecord(bag, slot, record), v.GroupOf(bag), v.Size(bag), v.IsOpen()
```

and replace it with:

```lua
--   v.Restack() -> bool                 redraw after a collapse or expand (held back like a move)
--   v.ToggleSection(groupId, sectionId), v.ToggleGroup(groupId)
--   v.Relabel()                         redraw the headers only (nothing moves)
--   v.ForEachSlot(fn)                   fn(button, record, bag, slot) for every slot (search)
--   v.Record(bag, slot), v.SetRecord(bag, slot, record), v.GroupOf(bag), v.Size(bag), v.IsOpen()
```

<!-- sbw3:edit T8 i08 SwagBag/UI/GroupView.lua -->
In `SwagBag/UI/GroupView.lua`, find:

```lua
	-- Collapse
	---------------------------------------------------------------------------
	function v.Restack()
		if not v.pos then
```

and replace it with:

```lua
	-- Collapse
	---------------------------------------------------------------------------
	-- Redraw only the headers (a new deposit target, a renamed tab): nothing moves.
	function v.Relabel()
		if v.pos then
			renderExtras(v.pos)
		end
	end

	function v.Restack()
		if not v.pos then
```

<!-- sbw3:edit T8 i09 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua
-- window and nothing else (spec 5.6); if the bank is still open, the bags window shows
-- "Bank still open", which only shows this window again.
local _, SB = ...

```

and replace it with:

```lua
-- window and nothing else (spec 5.6); if the bank is still open, the bags window shows
-- "Bank still open", which only shows this window again.
-- Contents (UI/GroupView.lua): the "Character bank" group on top, the "Warband bank" group
-- below, each with its own category sections (or grid), for the purchased tabs the client
-- reports. The receiving group is tinted and says "deposits go here". Items move only into
-- New or Free while the window is open (spec 4.3). Sort buttons call Blizzard's bank sort
-- and regroup after the bank settles; in combat they refuse with feedback and nothing runs
-- later (spec 5.5, ruling W11). The window has its own search box.
local _, SB = ...

```

<!-- sbw3:edit T8 i10 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua
	target = nil, -- "bank" | "warband" | nil: Blizzard's selected bank type, last read
	lastVisit = nil, -- "tiny" | "beside": the mode of the last visit (for /swagbag report)
	HEADER = 58,
	FOOTER = 6,
}
SB.BankWindow = BW
```

and replace it with:

```lua
	target = nil, -- "bank" | "warband" | nil: Blizzard's selected bank type, last read
	lastVisit = nil, -- "tiny" | "beside": the mode of the last visit (for /swagbag report)
	sortPending = false, -- a Sort was pressed and the bank updates are still settling
	sortSawUpdate = false,
	HEADER = 80, -- title row, search row, deposit line
	FOOTER = 6,
	MAX_HEIGHT_FRACTION = 0.75,
	SORT_SETTLE = 0.3,
	SORT_TIMEOUT = 1.5,
}
SB.BankWindow = BW
```

<!-- sbw3:edit T8 i11 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua

frame.deposit = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.deposit:SetPoint("TOPLEFT", 10, -24)
frame.deposit:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local function blizzardBank()
```

and replace it with:

```lua

frame.deposit = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.deposit:SetPoint("TOPLEFT", 14, -58)
frame.deposit:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -BW.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, BW.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
BW.scroll, BW.child = scroll, child
-- The bank tabs' bag frames (and so their item buttons) live in this window.
SB.Buttons.SetParentFor("bank", child)
SB.Buttons.SetParentFor("warband", child)

local function clampScroll()
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("bank.wheel", function(_, delta)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (SB.GroupView.SLOT + SB.GroupView.GAP) * 3)
	clampScroll()
end, "bank"))

local function blizzardBank()
```

<!-- sbw3:edit T8 i12 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua
-- Read Blizzard's selected bank type (never written) and show where deposits go.
function BW.RefreshTarget()
	BW.target = SB.Adapter.ActiveBankType()
	frame.deposit:SetText(BW.target and L.BANK_DEPOSITS_TO:format(groupName(BW.target)) or "")
	SB.Emit("SB_BANK_TARGET", BW.target)
end
```

and replace it with:

```lua
-- Read Blizzard's selected bank type (never written) and show where deposits go.
function BW.RefreshTarget()
	local old = BW.target
	BW.target = SB.Adapter.ActiveBankType()
	frame.deposit:SetText(BW.target and L.BANK_DEPOSITS_TO:format(groupName(BW.target)) or "")
	if old ~= BW.target and BW.view and BW.view.IsOpen() then
		BW.view.Relabel() -- the tint and "deposits go here" move to the other group
	end
	SB.Emit("SB_BANK_TARGET", BW.target)
end
```

<!-- sbw3:edit T8 i13 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
```

and replace it with:

```lua

---------------------------------------------------------------------------
-- Contents: two groups in one GroupView
---------------------------------------------------------------------------
function BW.View()
	return SB.Config.Get("bank.view") == "grid" and "grid" or "sections"
end

local function bagsOf(kind)
	local A, B, list = SB.Adapter, SB.Buttons, {}
	for _, bag in ipairs(A.GetBagIDs(kind)) do
		local n = A.NumSlots(bag)
		if n > 0 then
			if B.Count(bag) < n then
				B.EnsureCapacity(bag, n) -- in combat this waits; the slots appear at the next layout
			end
			list[#list + 1] = { bag = bag, size = n }
		end
	end
	return list
end

-- Paint the slot's button and return its item record (nil for an empty slot). A pending item
-- has no slot icon yet; placeholders still need one.
local function describe(bag, slot)
	local A, B = SB.Adapter, SB.Buttons
	local button = B.Get(bag, slot)
	if button then
		B.Paint(button, A.GetSlot(bag, slot))
	end
	local record = SB.Items.Describe(bag, slot)
	if record and not record.icon then
		record.icon = (A.GetItemInstant(record.itemID) or {}).icon
	end
	return record
end

-- Fit the window around the content; scroll when taller than 75 % of the screen. Every anchor
-- of this window is a top-left corner, so a resize never moves its top edge.
local function sizeFrame(width, height)
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * BW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - BW.HEADER - BW.FOOTER) + BW.HEADER + BW.FOOTER)
	clampScroll()
end

local searchBox

BW.view = SB.GroupView.New({
	key = "bank",
	window = "bank",
	child = child,
	scroll = scroll,
	button = function(bag, slot)
		return SB.Buttons.Get(bag, slot)
	end,
	describe = describe,
	groups = function()
		return { { id = "bank", bags = bagsOf("bank") }, { id = "warband", bags = bagsOf("warband") } }
	end,
	groupLabel = function(id, collapsed, count)
		local text = L.BANK_GROUP_LABEL:format(collapsed and "+" or "-", groupName(id), count)
		if id == BW.target then
			text = text .. L.BANK_GROUP_TARGET
		end
		return text
	end,
	groupTint = function(id)
		return id == BW.target
	end,
	view = BW.View,
	columns = function()
		return SB.Config.Get("bank.columns")
	end,
	newRows = function()
		return SB.Config.Get("bags.newRows")
	end,
	onResize = sizeFrame,
	onUpdated = function()
		searchBox.Apply()
	end,
	onDrop = function(sectionId)
		SB.BagsWindow.DropOnSection(sectionId)
	end,
})

searchBox = SB.SearchBox.New({
	parent = frame,
	name = "SwagBagBankSearchBox",
	search = SB.SearchState.New(),
	window = "bank",
	debounceKey = "search.bank",
	isOpen = function()
		return BW.IsOpen()
	end,
	forEachSlot = function(fn)
		return BW.view.ForEachSlot(fn)
	end,
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
	end,
})
BW.searchBox = searchBox

-- Full layout of both groups, then the search dimming.
function BW.Layout(reason)
	BW.view.Layout(reason)
	searchBox.Apply()
end

-- Sort (spec 5.5): Blizzard's bank sort for one bank type, only from a click and never in
-- combat (nothing is queued; ruling W11). SORT_SETTLE after the last bank update the window
-- regroups (held back while the mouse is over the items); a sort that changes nothing stops
-- waiting after SORT_TIMEOUT.
function BW.Sort(kind)
	local A = SB.Adapter
	if A.InCombat() then
		BW.Flash(L.SORT_AFTER_COMBAT)
		return false
	end
	local ok, err = A.SortBank(kind)
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("bank.sort", "none", tostring(err), A.Stack())
		end
		BW.Flash(L.SORT_UNAVAILABLE)
		return false
	end
	if not BW.sortPending then
		BW.sortSawUpdate = false
	end
	BW.sortPending = frame:IsShown()
	if BW.sortPending then
		SB.Debounce("bank.sortSettle", BW.SORT_TIMEOUT, function()
			local saw = BW.sortSawUpdate
			BW.sortPending, BW.sortSawUpdate = false, false
			if saw then
				BW.Reflow("sort")
			end
		end, "bank")
	end
	BW.Flash(L.SORT_STARTED)
	return true
end

function BW.Reflow(reason)
	if not frame:IsShown() then
		return false
	end
	local done = BW.view.RequestLayout(reason or "reflow")
	if done then
		searchBox.Apply()
	end
	BW.Flash(done and L.REFLOW_DONE or L.REFLOW_WAITING)
	return done
end

function BW.ToggleView()
	local view = BW.View() == "grid" and "sections" or "grid"
	SB.Config.Set("bank.view", view)
	BW.viewButton:SetText(view == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	BW.Flash(view == "grid" and L.BANK_VIEW_GRID or L.BANK_VIEW_SECTIONS)
	if BW.view.RequestLayout("view") then
		searchBox.Apply()
	end
end

-- Config is not initialized while this file loads, so the view label is set in BW.Open().
BW.viewButton = titleButton(L.VIEW_TO_GRID, "bank.viewButton", function()
	BW.ToggleView()
end)
BW.viewButton:SetPoint("RIGHT", BW.blizzardButton, "LEFT", -4, 0)
BW.reflowButton = titleButton(L.BTN_REFLOW, "bank.reflowButton", function()
	BW.Reflow("reflow")
end, 60)
BW.reflowButton:SetPoint("RIGHT", BW.viewButton, "LEFT", -4, 0)
BW.sortWarbandButton = titleButton(L.BTN_SORT_WARBAND, "bank.sortWarband", function()
	BW.Sort("warband")
end, 96)
BW.sortWarbandButton:SetPoint("RIGHT", BW.reflowButton, "LEFT", -4, 0)
BW.sortBankButton = titleButton(L.BTN_SORT_BANK, "bank.sortBank", function()
	BW.Sort("bank")
end, 76)
BW.sortBankButton:SetPoint("RIGHT", BW.sortWarbandButton, "LEFT", -4, 0)

-- Live updates while open (spec 4.3), for the bank tabs only: count, lock and loaded data
-- repaint in place; an emptied slot or a different item goes to GroupView.Changes; a tab
-- that appears or changes size lays the bank out again (held back like any full layout).
local BANK_REASONS
SB.Inventory.OnChanged(Guard("bank.inventory", function(mask, changes)
	if not (frame:IsShown() and BW.view.IsOpen()) then
		return
	end
	local Inv, B, A, v = SB.Inventory, SB.Buttons, SB.Adapter, BW.view
	BANK_REASONS = BANK_REASONS or { Inv.R.COUNT, Inv.R.ITEM, Inv.R.SIZE, Inv.R.LOCK, Inv.R.LOADED }
	local bankChange = false
	for _, c in ipairs(changes) do
		if B.KindOf(c.bag) ~= "bags" then
			bankChange = true
			break
		end
	end
	if BW.sortPending and bankChange then
		for _, r in ipairs(BANK_REASONS) do
			if Inv.Has(mask, r) then
				BW.sortSawUpdate = true
				SB.Debounce("bank.sortSettle", BW.SORT_SETTLE, function()
					BW.sortPending, BW.sortSawUpdate = false, false
					BW.Reflow("sort")
				end, "bank")
				break
			end
		end
	end
	if Inv.Has(mask, Inv.R.SIZE) and bankChange then
		B.EnsureBankTabs()
		if BW.view.RequestLayout("size") then
			searchBox.Apply()
		end
		return
	end
	local byGroup, touched = {}, false
	for _, c in ipairs(changes) do
		local gid = v.GroupOf(c.bag)
		local button = B.Get(c.bag, c.slot)
		if gid and button and c.slot <= (v.Size(c.bag) or 0) then
			local old = v.Record(c.bag, c.slot)
			touched = true
			if not Inv.Has(c.reasons, Inv.R.ITEM) then
				B.Paint(button, A.GetSlot(c.bag, c.slot))
				local fresh = SB.Items.Describe(c.bag, c.slot)
				if old and fresh and fresh.itemID == old.itemID then
					fresh.icon = fresh.icon or old.icon
					v.SetRecord(c.bag, c.slot, fresh)
				end
			else
				local record = describe(c.bag, c.slot)
				v.SetRecord(c.bag, c.slot, record)
				-- Same itemID, new link (a keystone after a run): repaint in place (W12).
				local sameItem = old and record and old.itemID == record.itemID
				if not sameItem and (record or old) then
					byGroup[gid] = byGroup[gid] or {}
					table.insert(byGroup[gid], { bag = c.bag, slot = c.slot, kind = record and "arrived" or "left",
						icon = old and old.icon })
				end
			end
		end
	end
	for _, gid in ipairs({ "bank", "warband" }) do
		if byGroup[gid] then
			v.Changes(gid, byGroup[gid])
		end
	end
	if touched then
		searchBox.Apply()
	end
end, "bank"))

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
```

<!-- sbw3:edit T8 i14 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua
		return true
	end
	frame:Show()
	BW.ApplyMode()
	SB.Emit("SB_BANK_OPENED")
	BW.RefreshStillOpen()
```

and replace it with:

```lua
		return true
	end
	BW.sortPending, BW.sortSawUpdate = false, false
	BW.viewButton:SetText(BW.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	frame:Show()
	BW.ApplyMode()
	BW.Layout("open")
	SB.Emit("SB_BANK_OPENED")
	BW.RefreshStillOpen()
```

<!-- sbw3:edit T8 i15 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua
		return
	end
	SB.Emit("SB_BANK_CLOSED")
	BW.RefreshStillOpen()
```

and replace it with:

```lua
		return
	end
	BW.view.Clear()
	BW.sortPending, BW.sortSawUpdate = false, false
	SB.Emit("SB_BANK_CLOSED")
	BW.RefreshStillOpen()
```

<!-- sbw3:edit T8 i16 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua
SB.On("BANKFRAME_CLOSED", function()
	BW.OnBankClosed()
end, "bank")

```

and replace it with:

```lua
SB.On("BANKFRAME_CLOSED", function()
	BW.OnBankClosed()
end, "bank")

-- A bank tab bought or changed during the visit (spec 9, 13.2 item 6; the event is
-- feature-detected: registration fails silently on a client without it).
SB.On("BANK_TAB_SETTINGS_UPDATED", function()
	if not (frame:IsShown() and BW.view.IsOpen()) then
		return
	end
	SB.Inventory.ScanKind("bank")
	SB.Inventory.ScanKind("warband")
	SB.Buttons.EnsureBankTabs()
	if BW.view.RequestLayout("tabs") then
		searchBox.Apply()
	end
end, "bank")

```

<!-- sbw3:edit T8 i17 SwagBag/Core/Report.lua -->
In `SwagBag/Core/Report.lua`, find:

```lua
		lines[#lines + 1] = L.REPORT_BANK:format(bank.Mode(), tostring(bank.lastVisit or L.REPORT_NONE),
			bank.target and bank.GroupName(bank.target) or L.REPORT_NONE)
	end
	local guild = SB.GuildBankWindow
```

and replace it with:

```lua
		lines[#lines + 1] = L.REPORT_BANK:format(bank.Mode(), tostring(bank.lastVisit or L.REPORT_NONE),
			bank.target and bank.GroupName(bank.target) or L.REPORT_NONE)
		local bankStats = bank.view and bank.view.stats
		if bankStats and bankStats.lastLayoutMs then -- spec 9: first bank open <= 80 ms
			lines[#lines + 1] = L.REPORT_BANK_LAYOUT:format(bankStats.lastLayoutMs, tostring(bankStats.lastLayoutReason))
		end
	end
	local guild = SB.GuildBankWindow
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bankwindow_groups_spec.lua spec/bankwindow_spec.lua spec/report_spec.lua`
Expected: `43 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (40 files)`, `554 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/helpers/uienv.lua \
  spec/mock_adapter.lua \
  spec/bankwindow_groups_spec.lua \
  spec/bankwindow_spec.lua \
  spec/report_spec.lua \
  SwagBag/Core/Adapter.lua \
  SwagBag/Core/Config.lua \
  SwagBag/Locale/enUS.lua \
  SwagBag/Engine/Inventory.lua \
  SwagBag/UI/GroupView.lua \
  SwagBag/UI/BankWindow.lua \
  SwagBag/Core/Report.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 8: bank window contents, deposit highlight, live updates, sort per bank type, search" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

Session B1 (the bank contents) runs after Task 9, so it can check the snapshots too.

---

### Task 9: Snapshots captured: format, timing, combat, budget, `/swagbag snapshot`

Spec F13 ships its offline view in November. The data has to start now (spec §12.1: "bank snapshots are still captured in October"), because the character bank can only be read at a banker (§5.7). `Engine/Snapshots.lua` stores the spec §8.3 format:
- `{ v = 1, at, containers = { [bag] = { size, s } } }`;
- one `"slot:link;count\n"` string per container, links verbatim;
- `Deserialize` reads it back. A link that contains `;` round-trips, because the line pattern takes the last `;`.

**Where it saves:** `SwagBagDB.chars["Name-Realm"]` (with class, level, lastSeen), `SwagBagDB.warband`, and `SwagBagDB.guilds["Guild-Realm"]` (used by Task 10). There is no schema bump (D7): `Snapshots.DB()` creates the tables and repairs damaged ones.

**When (D6):**
- bags at logout and 5 s after the last bag update;
- the character bank and warband bank 0.3 s after the bank opens, 1 s after each bank update while it is open, and when it closes.

The close snapshot is read from SwagBag's inventory model, so a client that already reads 0 slots cannot blank it. Away from a banker, bank-bag events never touch the bank snapshot. A save during combat waits for combat to end (spec §9), and a newer (read-only) schema is never written (§8.5).

**Budget (spec §8.4):** above 1.5 MB, other characters' bank snapshots are dropped, seen longest ago first, ties in name order, never the current character's. One chat line per session says so.

**Command and report.** `/swagbag snapshot` (spec §10.5) prints how old this character's snapshots are. The report gains `Snapshots: N characters, N guilds, N KB` for check V10.

**Files:**
- Create: `SwagBag/Engine/Snapshots.lua`
- Modify: `SwagBag/Core/Adapter.lua` (`Time`, `CharKey`, `CharInfo`), `.luacheckrc`, `SwagBag/Locale/enUS.lua`, `SwagBag/Core/Report.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/mock_adapter.lua`, `spec/snapshots_spec.lua` (new), `spec/report_spec.lua`

**Interfaces:**
- Consumes: `SB.Inventory.GetSlot/Size/OnChanged` (slots hold `{ itemID, link, count, isLocked }`), `SB.Adapter.GetBagIDs/BagKind`, `SB.OutOfCombat`, `SB.Debounce`, `SB.Slash.Register`, `SB.Config.db/readOnly`, `SB.Adapter.GUILD_SLOTS` (Task 2).
- Produces:
  - `SB.Adapter.Time() -> epoch seconds`, `SB.Adapter.CharKey() -> "Name-Realm"`, `SB.Adapter.CharInfo() -> { class, level }`.
  - Format: `SB.Snapshots.Serialize(slots, size) -> { size, s }`, `.Deserialize(container) -> slots`.
  - Saving: `SB.Snapshots.DB()`, `.Char() -> charTable, key`, `.Capture(kind) -> snapshot`, `.Save(kind) -> bool`, `.SaveGuild(guildKey, tabs) -> bool` (`tabs[tab] = { name, slots }`).
  - Budget and display: `SB.Snapshots.Bytes()`, `.Enforce() -> dropped keys`, `.Age(seconds) -> text`, `.Lines()`, `.Count() -> chars, guilds`, `HARD_CAP`.
  - Slash command `snapshot`. Report line `Snapshots: %d characters, %d guilds, %d KB`.

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T9 s01 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
	function m.Date(fmt)
		return (fmt:gsub("%%(%a)", DATE_PARTS))
	end

```

and replace it with:

```lua
	function m.Date(fmt)
		return (fmt:gsub("%%(%a)", DATE_PARTS))
	end

	m.epoch = 1791000000 -- seconds since the epoch at clock 0
	m.charKey = "Swagger-Argent Dawn"
	function m.Time()
		return m.epoch + math.floor(m.clock)
	end

	function m.CharKey()
		return m.charKey
	end

	function m.CharInfo()
		return { class = "MAGE", level = 90 }
	end

```

<!-- sbw3:edit T9 s02 spec/report_spec.lua -->
In `spec/report_spec.lua`, find:

```lua
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
```

and replace it with:

```lua
	end)

	it("shows the snapshot counts and size, for the spec 8.4 budgets (check V10)", function()
		SB.Checks.last = {}
		SB.Snapshots = { Count = function() return 3, 1 end, Bytes = function() return 40 * 1024 end }
		assert.truthy(SB.Report.Build():find("\nSnapshots: 3 characters, 1 guilds, 40 KB", 1, true))
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
```

<!-- sbw3:file T9 s03 spec/snapshots_spec.lua -->
Create `spec/snapshots_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Snapshots.lua",
}

local PET = "|cff0070dd|Hbattlepet:1387:25:3:1725:276:244:0000000000000000:82800|h[Lil' Tarecgosa]|h|r"
local KEY = "|cffa335ee|Hkeystone:180653:503:12:10:9:0:0|h[Keystone: Ara-Kara]|h|r"

describe("Snapshots (spec 8.3 format, 5.7 timing, 8.4 budget)", function()
	local SB, A, Snap
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Snap = SB.Snapshots
		Fixtures.Install(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(0, 8)
		A.Put(0, 1, Fixtures.HEALING_POTION, 5, { link = "|cffffffff|Hitem:211880::::::::80:::::|h[Algari Healing Potion]|h|r" })
		A.Put(0, 7, Fixtures.PET_CAGE, 1, { link = PET })
		A.Put(0, 8, Fixtures.KEYSTONE, 1, { link = KEY })
	end)

	local function bankVisit()
		A.SetBagSize(6, 4)
		A.SetBagSize(12, 4)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(12, 1, Fixtures.ORE, 10)
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	it("one string per container: slot:link;count lines in slot order, links verbatim, empties skipped", function()
		local c = Snap.Serialize({ [1] = { link = "item:1", count = 5 }, [3] = { link = PET, count = 1 } }, 4)
		assert.same({ size = 4, s = "1:item:1;5\n3:" .. PET .. ";1\n" }, c)
	end)

	it("round-trips caged pets, keystones and a link that contains a semicolon", function()
		local odd = "|Hitem:1|h[Odd;Name]|h"
		local slots = { [2] = { link = PET, count = 1 }, [5] = { link = KEY, count = 1 }, [9] = { link = odd, count = 20 } }
		assert.same(slots, Snap.Deserialize(Snap.Serialize(slots, 10)))
		assert.same({}, Snap.Deserialize({ s = "garbage\n12:x\n" }), "damaged lines are skipped")
		assert.same({}, Snap.Deserialize("not a table"))
	end)

	it("logging out saves the bags snapshot with the character's class, level and last-seen time", function()
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		local c = SB.Config.db.chars["Swagger-Argent Dawn"]
		assert.same({ "MAGE", 90, A.epoch }, { c.class, c.level, c.lastSeen })
		assert.equal(1, c.bags.v)
		assert.equal(A.epoch, c.bags.at)
		assert.equal(8, c.bags.containers[0].size)
		assert.equal(PET, Snap.Deserialize(c.bags.containers[0])[7].link)
		assert.is_nil(c.bank, "no bank without a banker visit")
	end)

	it("a bag update saves the bags 5 s after the last one, not before", function()
		SB.Inventory.ScanAll()
		A.Put(0, 2, Fixtures.FLASK, 1)
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(4)
		A.Put(0, 3, Fixtures.JUNK, 1)
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(4.9)
		assert.is_nil(SB.Config.db.chars, "debounced")
		A.Advance(0.2)
		local slots = Snap.Deserialize(SB.Config.db.chars["Swagger-Argent Dawn"].bags.containers[0])
		assert.equal("item:" .. Fixtures.JUNK, slots[3].link)
	end)

	it("a bank visit saves the character bank and the warband bank 0.3 s after opening", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.Advance(0.2)
		assert.is_nil(SB.Config.db.chars)
		A.Advance(0.2)
		local c = SB.Config.db.chars["Swagger-Argent Dawn"]
		assert.equal("item:" .. Fixtures.HERB, Snap.Deserialize(c.bank.containers[6])[2].link)
		assert.equal(4, c.bank.containers[6].size)
		assert.equal("item:" .. Fixtures.ORE, Snap.Deserialize(SB.Config.db.warband.containers[12])[1].link)
	end)

	it("bank updates during the visit save again (1 s debounce); the close saves the last state", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.Advance(0.5)
		A.Put(6, 3, Fixtures.FLASK, 2)
		SB.eventFrame:Fire("BAG_UPDATE", 6)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(1.1)
		assert.equal(2, Snap.Deserialize(SB.Config.db.chars["Swagger-Argent Dawn"].bank.containers[6])[3].count)
		A.Put(6, 4, Fixtures.JUNK, 1)
		SB.eventFrame:Fire("BAG_UPDATE", 6)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.truthy(Snap.Deserialize(SB.Config.db.chars["Swagger-Argent Dawn"].bank.containers[6])[4])
	end)

	it("away from a banker, bank-bag events never overwrite the bank snapshot", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.Advance(0.5)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		local saved = SB.Config.db.chars["Swagger-Argent Dawn"].bank
		A.SetBagSize(6, 0) -- the client reads 0 slots away from a banker
		SB.eventFrame:Fire("BAG_UPDATE", 6)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(10)
		assert.equal(saved, SB.Config.db.chars["Swagger-Argent Dawn"].bank)
		assert.equal(4, saved.containers[6].size)
	end)

	it("nothing is written in combat; the save happens when combat ends (spec 9)", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.combat = true
		A.Advance(0.5)
		assert.is_nil(SB.Config.db.chars)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.truthy(SB.Config.db.chars["Swagger-Argent Dawn"].bank)
	end)

	it("a newer (read-only) schema is never written", function()
		SB.Config.readOnly = true
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		bankVisit()
		A.Advance(1)
		assert.is_nil(SB.Config.db.chars)
	end)

	it("damaged saved snapshot tables never break a save", function()
		SB.Config.db.chars = "oops"
		SB.Config.db.warband = 7
		SB.Config.db.guilds = { ["X-Y"] = "bad" }
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		assert.truthy(SB.Config.db.chars["Swagger-Argent Dawn"].bags)
		assert.is_nil(SB.Config.db.warband)
		assert.equal(0, #SB.ErrorTrap.Recent())
		assert.same({ 1, 0 }, { Snap.Count() })
	end)

	it("over 1.5 MB, other characters' bank snapshots go first, seen longest ago first, ties by name", function()
		local big = { v = 1, at = 1, containers = { [6] = { size = 98, s = string.rep("x", 400 * 1024) } } }
		SB.Config.db.chars = {
			-- written in an order that disagrees with both lastSeen and name order
			["Zed-Realm"] = { lastSeen = 100, bank = big },
			["Amy-Realm"] = { lastSeen = 300, bank = big },
			["Bob-Realm"] = { lastSeen = 100, bank = big },
			["Cat-Realm"] = { lastSeen = 200, bank = big },
			["Swagger-Argent Dawn"] = { lastSeen = 1, bank = big },
		}
		local dropped = Snap.Enforce()
		assert.same({ "Bob-Realm", "Zed-Realm" }, dropped, "lastSeen 100 twice: Bob before Zed")
		assert.truthy(SB.Config.db.chars["Swagger-Argent Dawn"].bank, "the current character is never trimmed")
		assert.truthy(SB.Config.db.chars["Cat-Realm"].bank)
		assert.truthy(Snap.Bytes() <= Snap.HARD_CAP)
		assert.same({ "Saved bank snapshots went over 1.5 MB; dropped the oldest: Bob-Realm, Zed-Realm." }, A.Lines())
		SB.Config.db.chars["Amy-Realm"].bags = { v = 1, containers = { [0] = { size = 1, s = string.rep("y", 600 * 1024) } } }
		Snap.Enforce()
		assert.equal(1, #A.Lines(), "one chat line per session")
	end)

	it("a guild snapshot is saved per guild with its tab names", function()
		Snap.SaveGuild("Tidewatch-Argent Dawn", { [2] = { name = "Gear", slots = { [5] = { link = "item:1", count = 1 } } } })
		local g = SB.Config.db.guilds["Tidewatch-Argent Dawn"]
		assert.equal("Gear", g.tabs[2])
		assert.equal(A.epoch, g.lastSeen)
		assert.equal(98, g.snapshot.containers[2].size)
		assert.equal("5:item:1;1\n", g.snapshot.containers[2].s)
		assert.falsy(Snap.SaveGuild(nil, {}), "no guild, nothing saved")
	end)

	it("/swagbag snapshot prints how old each snapshot is", function()
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		A.Advance(3 * 3600)
		SB.Slash.Dispatch("snapshot")
		assert.same({ "Bags: 3 h ago", "Bank: not saved yet (visit a banker)", "Warband bank: not saved yet (visit a banker)",
			"Saved: 1 characters, 0 KB in all" }, A.Lines())
		assert.same({ "just now", "59 min ago", "1 h ago", "2 days ago" },
			{ Snap.Age(59), Snap.Age(3599), Snap.Age(3600), Snap.Age(2 * 86400 + 5) })
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/report_spec.lua spec/snapshots_spec.lua`
Expected: `8 passed, 14 failed`. `Engine/Snapshots.lua` does not exist.

Critical tests and the mutation that must make each fail:
- "over 1.5 MB, other characters' bank snapshots go first, seen longest ago first, ties by name": `return a.key > b.key` for the tie-break. The fixture lists Zed before Bob with equal `lastSeen`, so definition order and name order disagree. A second mutation also fails this test: drop `key ~= me` (the current character must never be trimmed).
- "nothing is written in combat…": `function Snap.Save(kind) write(kind) end` (no `SB.OutOfCombat`).
- "away from a banker, bank-bag events never overwrite the bank snapshot": `if bank then` instead of `if bank and bankOpen then`.
- "a bag update saves the bags 5 s after the last one, not before": `BAGS_DELAY = 0`.
- "a newer (read-only) schema is never written": `if false then` for the read-only test in `write`.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T9 i01 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
Engine/Categorizer.lua
Engine/Layout.lua
Engine/OverlayData.lua

```

and replace it with:

```text
Engine/Categorizer.lua
Engine/Layout.lua
Engine/Snapshots.lua
Engine/OverlayData.lua

```

<!-- sbw3:edit T9 i02 .luacheckrc -->
In `.luacheckrc`, find:

```lua
	"GetNumGuildBankTabs", "GetGuildBankTabInfo", "GetGuildBankItemInfo", "GetGuildBankItemLink", "QueryGuildBankTab",
	"GetCurrentGuildBankTab", "AutoStoreGuildBankItem", "PickupGuildBankItem", "GetGuildInfo", "GetRealmName",
	"IsModifiedClick", "HandleModifiedItemClick",
	"C_ChallengeMode", "C_PlayerInfo", "GetInventoryItemLink",
}
```

and replace it with:

```lua
	"GetNumGuildBankTabs", "GetGuildBankTabInfo", "GetGuildBankItemInfo", "GetGuildBankItemLink", "QueryGuildBankTab",
	"GetCurrentGuildBankTab", "AutoStoreGuildBankItem", "PickupGuildBankItem", "GetGuildInfo", "GetRealmName",
	"IsModifiedClick", "HandleModifiedItemClick", "time", "UnitName", "UnitClass", "UnitLevel",
	"C_ChallengeMode", "C_PlayerInfo", "GetInventoryItemLink",
}
```

<!-- sbw3:edit T9 i03 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
function A.Date(fmt)
	return date(fmt)
end

```

and replace it with:

```lua
function A.Date(fmt)
	return date(fmt)
end

-- Seconds since the epoch (snapshot stamps).
function A.Time()
	return time()
end

-- "Name-Realm" of the logged-in character (the snapshot key, spec 8.2).
function A.CharKey()
	return tostring(UnitName("player")) .. "-" .. tostring(GetRealmName())
end

function A.CharInfo()
	local _, class = UnitClass("player")
	return { class = class, level = UnitLevel("player") }
end

```

<!-- sbw3:edit T9 i04 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_GUILD = "Guild bank: setting %s, last visit %s"

-- Overlays (spec F9)
L.OVERLAY_TRACK = "%s%d/%d"
```

and replace it with:

```lua
L.REPORT_GUILD = "Guild bank: setting %s, last visit %s"

-- Snapshots (spec F13: captured now, shown offline in November)
L.HELP_SNAPSHOT = "snapshot: show how old this character's saved bags, bank and warband bank are"
L.SNAPSHOT_LINE = "%s: %s"
L.SNAPSHOT_BAGS = "Bags"
L.SNAPSHOT_BANK = "Bank"
L.SNAPSHOT_WARBAND = "Warband bank"
L.SNAPSHOT_NEVER = "not saved yet (visit a banker)"
L.SNAPSHOT_TOTAL = "Saved: %d characters, %d KB in all"
L.SNAPSHOT_TRIMMED = "Saved bank snapshots went over 1.5 MB; dropped the oldest: %s."
L.AGE_NOW = "just now"
L.AGE_MINUTES = "%d min ago"
L.AGE_HOURS = "%d h ago"
L.AGE_DAYS = "%d days ago"
L.REPORT_SNAPSHOTS = "Snapshots: %d characters, %d guilds, %d KB"

-- Overlays (spec F9)
L.OVERLAY_TRACK = "%s%d/%d"
```

<!-- sbw3:file T9 i05 SwagBag/Engine/Snapshots.lua -->
Create `SwagBag/Engine/Snapshots.lua`:

```lua
-- SwagBag snapshots (spec F13, 5.7, 8.3, 8.4). October CAPTURES them so the data exists when
-- the offline view arrives in November (spec 12.1); nothing shows them yet except
-- /swagbag snapshot and /swagbag report.
-- Format (spec 8.3): snapshot = { v = 1, at = epoch, containers = { [bag] = { size, s } } },
-- one string per container of "slot:link;count\n" lines in slot order, full links verbatim
-- (caged pets, keystones and bonus IDs round-trip), no derived values.
-- Where they live (spec 8.2): SwagBagDB.chars["Name-Realm"] = { class, level, lastSeen, bags,
-- bank }, SwagBagDB.warband (one for the account), SwagBagDB.guilds["Guild-Realm"] =
-- { lastSeen, tabs = { [tab] = name }, snapshot }.
-- When (spec AC13.1, 5.7): bags on logout and 5 s after the last bag update; the character
-- bank and warband bank 0.3 s after the bank opens, after each bank update while open (1 s
-- debounce) and when it closes. Never in combat (spec 9): a save in combat waits for it to end.
-- Budget (spec 8.4): over 1.5 MB in all, the bank snapshots of the characters seen longest
-- ago are dropped first (never the current character's), with one chat line per session.
local _, SB = ...

local Snap = { HARD_CAP = 1.5 * 1024 * 1024, BAGS_DELAY = 5, BANK_DELAY = 1, OPEN_DELAY = 0.3, trimmedSaid = false }
SB.Snapshots = Snap

---------------------------------------------------------------------------
-- Format (pure)
---------------------------------------------------------------------------
-- slots[slot] = { link, count } (nil = empty) for slots 1..size.
function Snap.Serialize(slots, size)
	local parts = {}
	for slot = 1, size do
		local s = slots[slot]
		if s and s.link then
			parts[#parts + 1] = slot .. ":" .. s.link .. ";" .. (s.count or 1) .. "\n"
		end
	end
	return { size = size, s = table.concat(parts) }
end

-- The inverse: slots[slot] = { link, count }. A damaged line is skipped.
function Snap.Deserialize(container)
	local slots = {}
	if type(container) ~= "table" or type(container.s) ~= "string" then
		return slots
	end
	for line in container.s:gmatch("[^\n]+") do
		local slot, link, count = line:match("^(%d+):(.*);(%d+)$")
		if slot then
			slots[tonumber(slot)] = { link = link, count = tonumber(count) }
		end
	end
	return slots
end

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------
local function tableOr(v)
	return type(v) == "table" and v or {}
end

-- The saved tables, repaired if damaged (a hand-edited or broken file never errors).
function Snap.DB()
	local db = SB.Config.db
	db.chars = tableOr(db.chars)
	db.guilds = tableOr(db.guilds)
	if db.warband ~= nil and type(db.warband) ~= "table" then
		db.warband = nil
	end
	return db
end

function Snap.Char()
	local A, db = SB.Adapter, Snap.DB()
	local key = A.CharKey()
	local c = tableOr(db.chars[key])
	db.chars[key] = c
	local info = A.CharInfo()
	c.class, c.level, c.lastSeen = info.class, info.level, A.Time()
	return c, key
end

-- A snapshot of every bag of a kind ("bags" | "bank" | "warband") from Inventory's model.
function Snap.Capture(kind)
	local Inv = SB.Inventory
	local snap = { v = 1, at = SB.Adapter.Time(), containers = {} }
	for _, bag in ipairs(SB.Adapter.GetBagIDs(kind)) do
		local size, slots = Inv.Size(bag), {}
		for slot = 1, size do
			slots[slot] = Inv.GetSlot(bag, slot)
		end
		snap.containers[bag] = Snap.Serialize(slots, size)
	end
	return snap
end

local function write(kind)
	if SB.Config.readOnly then
		return -- a newer schema is never touched (spec 8.5)
	end
	if kind == "warband" then
		Snap.DB().warband = Snap.Capture("warband")
	else
		local c = Snap.Char()
		c[kind] = Snap.Capture(kind)
	end
	Snap.Enforce()
end

-- Save one kind now, or as soon as combat ends (no snapshot writes in combat, spec 9).
function Snap.Save(kind)
	return SB.OutOfCombat(function()
		write(kind)
	end, "snapshot." .. kind, "none")
end

-- tabs[tab] = { name, slots = { [slot] = { link, count } } } for the tabs read this visit.
function Snap.SaveGuild(guildKey, tabs)
	if not guildKey then
		return false
	end
	return SB.OutOfCombat(function()
		if SB.Config.readOnly then
			return
		end
		local db = Snap.DB()
		local g = tableOr(db.guilds[guildKey])
		db.guilds[guildKey] = g
		g.lastSeen = SB.Adapter.Time()
		g.tabs = tableOr(g.tabs)
		g.snapshot = type(g.snapshot) == "table" and g.snapshot or { v = 1, containers = {} }
		g.snapshot.containers = tableOr(g.snapshot.containers)
		g.snapshot.at = g.lastSeen
		for tab, t in pairs(tabs) do
			g.tabs[tab] = t.name
			g.snapshot.containers[tab] = Snap.Serialize(t.slots or {}, SB.Adapter.GUILD_SLOTS)
		end
		Snap.Enforce()
	end, "snapshot.guild", "none")
end

---------------------------------------------------------------------------
-- Budget (spec 8.4)
---------------------------------------------------------------------------
local function snapshotBytes(snap)
	local n = 0
	if type(snap) == "table" and type(snap.containers) == "table" then
		for _, c in pairs(snap.containers) do
			if type(c) == "table" and type(c.s) == "string" then
				n = n + #c.s + 16
			end
		end
	end
	return n
end

-- Approximate saved size of every snapshot (strings plus a small per-container overhead).
function Snap.Bytes()
	local db = Snap.DB()
	local n = snapshotBytes(db.warband)
	for _, c in pairs(db.chars) do
		if type(c) == "table" then
			n = n + snapshotBytes(c.bags) + snapshotBytes(c.bank)
		end
	end
	for _, g in pairs(db.guilds) do
		if type(g) == "table" then
			n = n + snapshotBytes(g.snapshot)
		end
	end
	return n
end

-- Over the hard cap: drop other characters' bank snapshots, seen longest ago first (ties: name
-- order), until under the cap. Returns the names dropped.
function Snap.Enforce()
	local dropped = {}
	if Snap.Bytes() <= Snap.HARD_CAP then
		return dropped
	end
	local db, me = Snap.DB(), SB.Adapter.CharKey()
	local list = {}
	for key, c in pairs(db.chars) do
		if key ~= me and type(c) == "table" and c.bank then
			list[#list + 1] = { key = key, seen = tonumber(c.lastSeen) or 0 }
		end
	end
	table.sort(list, function(a, b)
		if a.seen ~= b.seen then
			return a.seen < b.seen
		end
		return a.key < b.key
	end)
	for _, e in ipairs(list) do
		if Snap.Bytes() <= Snap.HARD_CAP then
			break
		end
		db.chars[e.key].bank = nil
		dropped[#dropped + 1] = e.key
	end
	if #dropped > 0 and not Snap.trimmedSaid then
		Snap.trimmedSaid = true
		SB.Print(SB.L.SNAPSHOT_TRIMMED:format(table.concat(dropped, ", ")))
	end
	return dropped
end

---------------------------------------------------------------------------
-- Ages for /swagbag snapshot
---------------------------------------------------------------------------
function Snap.Age(seconds)
	local L = SB.L
	if seconds < 60 then
		return L.AGE_NOW
	elseif seconds < 3600 then
		return L.AGE_MINUTES:format(math.floor(seconds / 60))
	elseif seconds < 86400 then
		return L.AGE_HOURS:format(math.floor(seconds / 3600))
	end
	return L.AGE_DAYS:format(math.floor(seconds / 86400))
end

function Snap.Lines()
	local L, db, now = SB.L, Snap.DB(), SB.Adapter.Time()
	local c = db.chars[SB.Adapter.CharKey()]
	local chars = Snap.Count()
	local function age(snap)
		if type(snap) ~= "table" or not snap.at then
			return L.SNAPSHOT_NEVER
		end
		return Snap.Age(now - snap.at)
	end
	return {
		L.SNAPSHOT_LINE:format(L.SNAPSHOT_BAGS, age(c and c.bags)),
		L.SNAPSHOT_LINE:format(L.SNAPSHOT_BANK, age(c and c.bank)),
		L.SNAPSHOT_LINE:format(L.SNAPSHOT_WARBAND, age(db.warband)),
		L.SNAPSHOT_TOTAL:format(chars, math.floor(Snap.Bytes() / 1024 + 0.5)),
	}
end

-- characters, guilds
function Snap.Count()
	local chars, guilds = 0, 0
	local db = Snap.DB()
	for _, c in pairs(db.chars) do
		if type(c) == "table" then
			chars = chars + 1
		end
	end
	for _, g in pairs(db.guilds) do
		if type(g) == "table" then
			guilds = guilds + 1
		end
	end
	return chars, guilds
end

---------------------------------------------------------------------------
-- When to capture
---------------------------------------------------------------------------
local bankOpen = false

SB.On("PLAYER_LOGOUT", function()
	write("bags")
end, "none")

SB.On("BANKFRAME_OPENED", function()
	bankOpen = true
	SB.Debounce("snapshot.bankOpen", Snap.OPEN_DELAY, function()
		Snap.Save("bank")
		Snap.Save("warband")
	end, "none")
end, "none")

SB.On("BANKFRAME_CLOSED", function()
	if bankOpen then
		bankOpen = false
		Snap.Save("bank")
		Snap.Save("warband")
	end
end, "none")

SB.Inventory.OnChanged(SB.ErrorTrap.Guard("snapshot.inventory", function(_, changes)
	local bags, bank = false, false
	for _, c in ipairs(changes) do
		local kind = SB.Adapter.BagKind(c.bag)
		if kind == "bank" or kind == "warband" then
			bank = true
		elseif kind then
			bags = true
		end
	end
	if bags then
		SB.Debounce("snapshot.bags", Snap.BAGS_DELAY, function()
			Snap.Save("bags")
		end, "none")
	end
	if bank and bankOpen then
		SB.Debounce("snapshot.bank", Snap.BANK_DELAY, function()
			Snap.Save("bank")
			Snap.Save("warband")
		end, "none")
	end
end, "none"))

SB.Slash.Register("snapshot", SB.L.HELP_SNAPSHOT, function()
	return Snap.Lines()
end)
```

<!-- sbw3:edit T9 i06 SwagBag/Core/Report.lua -->
In `SwagBag/Core/Report.lua`, find:

```lua
		end
	end
	local guild = SB.GuildBankWindow
	if guild then
```

and replace it with:

```lua
		end
	end
	if SB.Snapshots and SB.Config.db then -- spec 8.4 budgets, check V10
		local chars, guilds = SB.Snapshots.Count()
		lines[#lines + 1] = L.REPORT_SNAPSHOTS:format(chars, guilds, math.floor(SB.Snapshots.Bytes() / 1024 + 0.5))
	end
	local guild = SB.GuildBankWindow
	if guild then
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/report_spec.lua spec/snapshots_spec.lua`
Expected: `22 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (41 files)`, `568 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/mock_adapter.lua \
  spec/report_spec.lua \
  spec/snapshots_spec.lua \
  SwagBag/SwagBag.toc \
  .luacheckrc \
  SwagBag/Core/Adapter.lua \
  SwagBag/Locale/enUS.lua \
  SwagBag/Engine/Snapshots.lua \
  SwagBag/Core/Report.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 9: snapshots of bags, bank and warband bank, with budget and /swagbag snapshot" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 7: In-game session B1 (the user does this on Oct 18; about 15 minutes)**

Give the user this checklist exactly. Stand at a banker, with some items in both the character bank and the warband bank.

1. Quit the game completely and start it again (new files). Log in. Chat shows `SwagBag: v0.3.0 loaded. Type /swagbag help for commands.`
2. Talk to the banker. The `SwagBag bank` window now shows two groups:
   - `- Character bank (N)` on top. If it is the selected tab, its header is green and ends with `  - deposits go here`.
   - `- Warband bank (N)` below.
   Each group has its own sections: `- New (0)`, your categories, and `- Free (N)`.
3. Click the warband tab under the window. The green header and `  - deposits go here` move to `Warband bank`. Nothing else moves.
4. Right-click an item in your SwagBag bags. It appears in the first cell of `New` in the Warband bank group, and nothing else in the bank window moves. Move the mouse off it.
5. Right-click an item in the Character bank group. It goes to your bags, a faded copy stays where it was, and the button moves to the end of that group's `Free`. Move the mouse off it.
6. Click a section header in the bank window (for example `- Herbs (N)`). It turns into `+ Herbs (N)`, and the sections below move up. The header you clicked does not move. Click it again: every item returns to the same place.
7. Click the `- Warband bank (N)` header. The whole warband group folds into `+ Warband bank (N)`. Click it again to open it.
8. Click the bank window's search box and type `ore`. The bank items that are not ore dim, and your bags window is not dimmed. Clear the box with its small x.
9. Click `Sort bank`. The title says `Sorting...`, Blizzard sorts the character bank, and about half a second after it stops the bank window regroups (the title says `Regrouped`, and the faded copies are gone). Click `Sort warband`: the same for the warband bank. (If a bank was already sorted, nothing moves. That is fine.)
10. Click `Grid`. The title says `SwagBag bank - grid view`, each group shows its slots in bank order, and the button now says `Categories`. Click `Categories` to go back.
11. Type `/swagbag snapshot`. Chat shows four lines:
    - `Bags: …`;
    - `Bank: just now` (or `1 min ago`);
    - `Warband bank: just now` (or `1 min ago`);
    - `Saved: N characters, N KB in all`.
12. Walk away from the banker, then talk to the banker again (a fresh open). Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks:
    - `Last bank layout: … ms (open)` is at or below 80 ms;
    - `Snapshots: 1 characters, 0 guilds, … KB` (for check V10: at or below about 30 KB for this character);
    - `Bank: setting tiny, last visit tiny, …`;
    - no new errors and `Blocked actions: none`.
13. Walk away from the banker. Right-click your Hearthstone: the cast bar appears, with no red message.

Pass: steps 2–13 behave as described, and no item moved while the mouse was on it.

---

### Task 10: Guild bank window on GroupView: sections per tab, on-demand queries with a session cache, live changes, search, per-guild snapshot

Task 2's guild window draws each tab as a plain grid. This task replaces it with a `GroupView` (AC16.1): every viewable tab is a group (`"tab" .. N`, pseudo bag `100 + N`) with its own category sections or grid, its own search box, Reflow and Grid. The tab header shows the marker, name, item count and withdrawals left, for example `- Mats (12) - 5 withdrawals left today`.

Guild items are not container items, so `Items.DescribeLink(info, bag, slot, tab)` builds their records from the link. It uses `Adapter.GetLinkIlvl(link)` for the item level, sets location `"guild"`, and marks guild items as never bound, never on cooldown and never new. Like bag records (Task 3) it carries `track` (from `Adapter.UpgradeInfo`) and `hasNoValue` (always false), so Task 11 can draw overlays on guild buttons.

**Queries (Review Focus 3).** One tab is queried at a time. A `GUILDBANKBAGSLOTS_CHANGED` that arrives while tab T is being queried is T's answer, and only tabs that answered during this visit are read. A tab whose answer is still on its way never reads as empty and never turns into a screen of placeholders. A tab with no answer in 0.3 s is asked once more at the end of the queue.

**Cache and live changes.** The session cache shows a reopen at once. A tab read for the first time in the session is laid out in full (D17), held back while the mouse is over the items. After that, a slot whose item changed goes through `GroupView.Changes` (spec §4.3), and every other change only repaints.

**Snapshot.** A per-guild snapshot is saved 1 s after an answer and when the vault closes (AC16.4, `Snapshots.SaveGuild`).

**Unchanged from Task 2:** the window's frame handling (tiny/view, re-hosted tabs, read-only selected tab, Esc, Safe Mode, the slot actions). `GW.ApplyMode` still moves nothing while Blizzard's frame is hidden; a new test pins that. The window file and its spec are replaced whole.

**Files:**
- Modify (replace whole files): `SwagBag/UI/GuildBankWindow.lua`, `spec/guildbank_spec.lua`
- Modify: `SwagBag/Engine/Items.lua` (`DescribeLink`), `SwagBag/Core/Adapter.lua` (`GetLinkIlvl`, optional check), `SwagBag/Core/Config.lua` (`guildBank.view`, `guildBank.columns`), `SwagBag/Locale/enUS.lua`
- Test: `spec/mock_adapter.lua`, `spec/helpers/uienv.lua` (`Env.LoadGuild`), `spec/items_spec.lua`, `spec/guildbank_spec.lua`

**Interfaces:**
- Consumes:
  - Task 2: `SB.GuildButtons`, the Adapter guild functions, `SB.TinyHost`;
  - Task 3: `SB.Adapter.UpgradeInfo` (records carry `track`);
  - Task 6: `SB.SearchState.New`, `SB.SearchBox.New`;
  - Task 7: `SB.GroupView.New` (with `Relabel` from Task 8);
  - Task 8: `spec/helpers/uienv.lua`;
  - Task 9: `SB.Snapshots.SaveGuild`.
- Produces:
  - `SB.Items.DescribeLink(info, bag, slot, tab) -> record` and `SB.Adapter.GetLinkIlvl(link) -> number | nil`.
  - `SB.GuildBankWindow` keeps the Task 2 names listed there. `ReadTab`, `Render` and `labels` are gone (the GroupView draws). `TabLabel` now takes `(tab, collapsed, count)`. It gains:
    - fields: `view`, `searchBox`, `scroll`, `child`, `answered[tab]`, `retried[tab]`, `BAG_BASE == 100`, `viewButton`, `reflowButton`;
    - `TabLabel(tab, collapsed, count) -> text`, `View()`, `Layout(reason)`, `Reflow(reason)`, `ToggleView()`, `Refresh()`, `SaveSnapshot()`.
  - Settings `guildBank.view` and `guildBank.columns`. `Env.LoadGuild(SB)`.

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T10 s01 spec/helpers/uienv.lua -->
In `spec/helpers/uienv.lua`, find:

```lua
end

return Env
```

and replace it with:

```lua
end

-- Load the guild bank window (and the UI files it uses) into SB. Fake.Install() must have run.
function Env.LoadGuild(SB)
	if not SB.BagsWindow then
		Env.FakeBags(SB)
	end
	for _, path in ipairs({ "SwagBag/Engine/Snapshots.lua", "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua",
		"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/GuildButtons.lua",
		"SwagBag/UI/GuildBankWindow.lua" }) do
		Loader.LoadFile(SB, path)
	end
	return SB.GuildBankWindow
end

return Env
```

<!-- sbw3:edit T10 s02 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
	end

	-- Overlays: m.tracks[link] = { track, level, max }; m.dungeons[mapID] = name;
	-- m.equipped[invSlot] = { ilvl, equipLoc }; m.cannotUse[itemID] = true; m.pawn[bag .. ":" .. slot] = bool.
```

and replace it with:

```lua
	end

	-- Links in fixtures carry the itemID ("item:<id>..."); the item level is the fixture's.
	function m.GetLinkIlvl(link)
		local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
		local it = id and m.items[id]
		return it and not it.pending and it.ilvl or nil
	end

	-- Overlays: m.tracks[link] = { track, level, max }; m.dungeons[mapID] = name;
	-- m.equipped[invSlot] = { ilvl, equipLoc }; m.cannotUse[itemID] = true; m.pawn[bag .. ":" .. slot] = bool.
```

<!-- sbw3:file T10 s03 spec/guildbank_spec.lua -->
Replace the whole file `spec/guildbank_spec.lua` with:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The guild bank window (spec F16, check G1): tiny mode, re-hosted tabs, withdraw / pickup /
-- drop through Blizzard's own guild bank functions, the read-only selected tab, view mode,
-- one group per tab with its own sections, on-demand queries, the session cache, live
-- changes, its own search, and the per-guild snapshot.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

-- Blizzard's guild bank as Blizzard shows it, with two tab buttons on its right edge.
local function blizzardGuildBank(A)
	local gf = Fake.New("Frame", UIParent)
	gf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	local tabs = {}
	for i = 1, 2 do
		local t = Fake.New("Frame", gf)
		t.Button = Fake.New("CheckButton", t)
		if i == 1 then
			t:SetPoint("TOPLEFT", gf, "TOPRIGHT", -1, -17)
		else
			t:SetPoint("TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -17)
		end
		tabs[i] = t
	end
	A.frames.GuildBankFrame = gf
	A.guildTabFrames = tabs
	return gf, tabs
end

describe("GuildBankWindow (check G1)", function()
	local SB, A, GW, gf, tabs
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		Env.PaintGlobals()
		gf, tabs = blizzardGuildBank(A)
		A.guild.tabs = {
			{ tab = 1, name = "Mats", withdrawals = 5 },
			{ tab = 2, name = "Gear", withdrawals = 0 },
			{ tab = 3, name = "Officers", viewable = false },
		}
		A.guild.slots = { [1] = { [1] = { itemID = Fixtures.HERB, count = 20 }, [2] = { itemID = Fixtures.ORE, count = 5 } },
			[2] = { [1] = { itemID = Fixtures.BOE_RING } } }
		A.guild.current = 1
		GW = Env.LoadGuild(SB)
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openVault()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
	end

	local function closeVault()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "GuildBanker")
	end

	-- The client answers each query with GUILDBANKBAGSLOTS_CHANGED.
	local function answerQueries()
		for _ = 1, 4 do
			SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
			A.Advance(0.06)
		end
	end

	local function button(tab, slot)
		return SB.GuildButtons.Get(tab, slot)
	end

	local function header(id)
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId == id then
				return h
			end
		end
	end

	local function at(b)
		local p = b.points[#b.points]
		return { p[4], p[5] }
	end

	it("opens at the vault; Blizzard's guild bank stays shown in the 0.001 parent, its tabs on our right edge", function()
		openVault()
		assert.truthy(GW.IsOpen())
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.equal(true, gf.shown, "still shown: the visit stays open")
		assert.equal(GW.frame, tabs[1].parent)
		assert.same({ "TOPLEFT", GW.frame, "TOPRIGHT", 0, -16 }, tabs[1].points[1])
		assert.same({ "TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -6 }, tabs[2].points[1])
	end)

	it("never calls a method on Blizzard's guild bank frame or its tabs (it only moves them)", function()
		openVault()
		answerQueries()
		Fake.Fire(tabs[2].Button, "OnClick")
		A.Advance(0)
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		closeVault()
		assert.same({}, gf.calls)
		for i = 1, 2 do
			assert.same({}, tabs[i].calls)
			assert.same({}, tabs[i].Button.calls)
		end
	end)

	it("lists every viewable tab with its withdrawals left; a tab the player cannot view is left out", function()
		openVault()
		assert.equal("- Mats (0) - 5 withdrawals left today (loading...)  - deposits go here", header("#tab1").text.text)
		answerQueries()
		assert.equal("- Mats (2) - 5 withdrawals left today  - deposits go here", header("#tab1").text.text)
		assert.equal("- Gear (1) - no withdrawals left today", header("#tab2").text.text)
		assert.is_nil(header("#tab3"))
		assert.is_nil(button(3, 1), "no buttons for a tab that is not shown")
		A.guild.tabs[1].withdrawals = -1
		SB.eventFrame:Fire("GUILDBANK_UPDATE_TABS")
		assert.equal("- Mats (2) - unlimited withdrawals  - deposits go here", header("#tab1").text.text)
	end)

	it("each tab is a group with its own sections: the tab's items sit in their categories", function()
		openVault()
		answerQueries()
		assert.truthy(header("tab1:c_herbs"))
		assert.truthy(header("tab1:c_ore"))
		assert.truthy(header("tab2:c_boe"))
		assert.equal("load", GW.view.stats.lastLayoutReason)
		assert.truthy(at(button(2, 1))[2] < at(button(1, 98))[2], "tab 2 below tab 1")
	end)

	it("queries the selected tab first, then the others one at a time, and shows what arrived", function()
		A.guild.current = 2
		openVault()
		assert.same({ 2 }, A.guild.queried)
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		A.Advance(0.06)
		assert.same({ 2, 1 }, A.guild.queried)
		answerQueries()
		assert.same({ 2, 1 }, A.guild.queried, "tab 3 is not viewable and never queried")
		assert.equal(Fixtures.HERB, button(1, 1).icon)
		assert.equal(20, button(1, 1).count)
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon)
		assert.is_nil(rawget(button(1, 3), "icon"))
	end)

	it("a query that gets no answer moves on after QUERY_GAP and is asked once more at the end", function()
		openVault()
		A.Advance(GW.QUERY_GAP + 0.01)
		assert.same({ 1, 2 }, A.guild.queried)
		A.Advance(3 * GW.QUERY_GAP)
		assert.same({ 1, 2, 1, 2 }, A.guild.queried)
		A.Advance(5)
		assert.equal(4, #A.guild.queried, "only once more")
	end)

	it("a reopen shows the session's cached contents at once; a tab whose answer is on its way is not read", function()
		openVault()
		answerQueries()
		closeVault()
		A.guild.queried = {}
		A.guild.slots[2] = {} -- what the client returns for tab 2 before its new answer arrives
		openVault()
		assert.equal(Fixtures.HERB, button(1, 1).icon, "cached")
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon, "cached")
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED") -- tab 1's answer
		assert.equal(Fixtures.BOE_RING, button(2, 1).icon, "tab 2 has not answered yet: not read")
		assert.equal(0, #SB.Buttons.placeholdersInUse)
		assert.same({ 1 }, A.guild.queried)
	end)

	it("while open, an item taken by someone else leaves a placeholder; a deposit goes to that tab's New", function()
		openVault()
		answerQueries()
		local herbAt = at(button(1, 1))
		A.guild.slots[1][1] = nil
		A.guild.slots[1][7] = { itemID = Fixtures.FLASK, count = 3 }
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		assert.equal(1, #SB.Buttons.placeholdersInUse)
		assert.same(herbAt, { SB.Buttons.placeholdersInUse[1].points[1][4], SB.Buttons.placeholdersInUse[1].points[1][5] })
		assert.equal(header("tab1:new").points[1][5] - 20, at(button(1, 7))[2], "the deposit is first in New")
	end)

	it("a right-click withdraws to the bags, from any tab by default", function()
		A.guild.tabs[2].withdrawals = 3
		openVault()
		answerQueries()
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({ { 1, 1 }, { 2, 1 } }, A.guild.withdrawn)
		assert.same({}, A.Lines())
	end)

	it("with withdrawAnyTab off, a right-click in a tab Blizzard has not selected says which tab to click", function()
		A.guild.tabs[2].withdrawals = 3
		SB.Config.Set("guildBank.withdrawAnyTab", false)
		openVault()
		answerQueries()
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ "Click the Gear tab on the right first, then right-click the item again." }, A.Lines())
	end)

	it("a tab with no withdrawals left refuses with a message and calls nothing (AC16.2)", function()
		openVault()
		answerQueries()
		Fake.Fire(button(2, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({ "No withdrawals left today from Gear." }, A.Lines())
	end)

	it("a right-click on an empty slot does nothing", function()
		openVault()
		answerQueries()
		assert.equal("empty", GW.ClickSlot(1, 50, "RightButton"))
		assert.same({}, A.guild.withdrawn)
	end)

	it("left-click and drag pick the stack up; a drop puts the cursor's item into that slot", function()
		openVault()
		answerQueries()
		Fake.Fire(button(1, 2), "OnClick", "LeftButton")
		Fake.Fire(button(1, 1), "OnDragStart")
		Fake.Fire(button(1, 9), "OnReceiveDrag")
		assert.same({ { 1, 2 }, { 1, 1 }, { 1, 9 } }, A.guild.picked)
	end)

	it("a modified click (shift: link to chat) is Blizzard's and does nothing else", function()
		openVault()
		answerQueries()
		A.modified = true
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.same({}, A.guild.withdrawn)
		assert.same({}, A.guild.picked)
	end)

	it("hovering shows Blizzard's guild bank tooltip for that slot", function()
		openVault()
		Fake.Fire(button(1, 2), "OnEnter")
		assert.same({ owner = button(1, 2), tab = 1, slot = 2 }, A.tooltip)
		Fake.Fire(button(1, 2), "OnLeave")
		assert.is_nil(A.tooltip)
	end)

	it("deposits go to the tab Blizzard has selected, read on the frame after a tab click; its header says so", function()
		openVault()
		answerQueries()
		assert.equal("Deposits go to Mats - switch with the tabs on the right", GW.frame.deposit.text)
		A.guild.current = 2
		Fake.Fire(tabs[2].Button, "OnClick")
		A.Advance(0)
		assert.equal("Deposits go to Gear - switch with the tabs on the right", GW.frame.deposit.text)
		assert.equal("- Gear (1) - no withdrawals left today  - deposits go here", header("#tab2").text.text)
		assert.equal("- Mats (2) - 5 withdrawals left today", header("#tab1").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#tab2").bg.calls.SetColorTexture)
	end)

	it("the guild bank's search box dims guild slots only", function()
		openVault()
		answerQueries()
		GW.searchBox.editBox:SetText("herb")
		Fake.Fire(GW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
		assert.equal(1, button(1, 1).alpha)
		assert.equal(SB.Buttons.DIM_ALPHA, button(1, 2).alpha)
		assert.equal("", SB.Search.text)
	end)

	it("a snapshot of the tabs read is saved per guild after an answer and when the vault closes (AC16.4)", function()
		openVault()
		answerQueries()
		A.Advance(1.1)
		local g = SB.Config.db.guilds["Tidewatch-Argent Dawn"]
		assert.same({ "Mats", "Gear" }, { g.tabs[1], g.tabs[2] })
		assert.equal("1:item:" .. Fixtures.HERB .. ";20\n2:item:" .. Fixtures.ORE .. ";5\n", g.snapshot.containers[1].s)
		A.guild.slots[1][3] = { itemID = Fixtures.JUNK, count = 2 }
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		closeVault()
		assert.truthy(g.snapshot.containers[1].s:find("3:item:" .. Fixtures.JUNK .. ";2", 1, true))
	end)

	it("view mode (the setting): Blizzard's guild bank stays as it is and ours is read-only beside it", function()
		SB.Config.Set("guildBank.mode", "view")
		openVault()
		answerQueries()
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
		assert.same({ "TOPLEFT", gf, "TOPRIGHT", 8, 0 }, GW.frame.points[#GW.frame.points])
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		Fake.Fire(button(1, 1), "OnDragStart")
		assert.same({}, A.guild.withdrawn)
		assert.same({}, A.guild.picked)
		assert.same({ SB.L.GUILD_VIEW_ONLY, SB.L.GUILD_VIEW_ONLY }, A.Lines())
	end)

	it("the Blizzard guild bank button shows Blizzard's frame for this visit and hides it again", function()
		openVault()
		Fake.Fire(GW.blizzardButton, "OnClick")
		assert.equal(UIParent, gf.parent)
		assert.equal("view", GW.VisitMode())
		assert.equal("full", SB.Config.Get("guildBank.mode"))
		Fake.Fire(GW.blizzardButton, "OnClick")
		assert.equal(SB.TinyHost.Parent(), gf.parent)
	end)

	it("closing the vault puts Blizzard's frame and its tabs back exactly and forgets the layout", function()
		openVault()
		answerQueries()
		closeVault()
		assert.falsy(GW.IsOpen())
		assert.falsy(GW.view.IsOpen())
		assert.falsy(button(1, 1).shown)
		assert.equal(UIParent, gf.parent)
		assert.same({ { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }, gf.points)
		assert.equal(gf, tabs[2].parent)
		assert.same({ { "TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -17 } }, tabs[2].points)
	end)

	it("Esc hides only SwagBag's window; Blizzard's frame keeps the visit open", function()
		openVault()
		assert.equal("SwagBagGuildBankWindow", UISpecialFrames[#UISpecialFrames])
		GW.frame:Hide()
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.same({}, gf.calls)
	end)

	it("works when Blizzard's guild bank UI loads on demand during the visit", function()
		A.frames.GuildBankFrame = nil
		gf.shown = false
		SB.eventFrame:Fire("ADDON_LOADED", "Blizzard_GuildBankUI") -- not there yet: nothing to hook
		openVault()
		assert.truthy(GW.IsOpen())
		A.frames.GuildBankFrame = gf
		SB.eventFrame:Fire("ADDON_LOADED", "Blizzard_GuildBankUI")
		gf:Show()
		assert.equal(SB.TinyHost.Parent(), gf.parent)
		assert.equal(1, #gf.hooks.OnShow)
	end)

	it("nothing moves while Blizzard's guild bank frame is still hidden; it is shrunk once Blizzard shows it", function()
		gf.shown = false
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
		assert.truthy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.equal(gf, tabs[1].parent)
		gf:Show()
		assert.equal(SB.TinyHost.Parent(), gf.parent)
	end)

	it("a visit that starts in combat creates no buttons and leaves Blizzard's guild bank as it is", function()
		A.combat = true
		openVault()
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
		assert.is_nil(button(1, 1))
		assert.same({ SB.L.GUILD_COMBAT_WAIT }, A.Lines())
	end)

	it("Safe Mode for the bank also hands the guild bank to Blizzard", function()
		openVault()
		SB.SafeMode.Enable("bank", "manual")
		assert.falsy(GW.IsOpen())
		assert.equal(UIParent, gf.parent)
	end)

	it("/swagbag guild view|full saves the setting and applies it now", function()
		openVault()
		SB.Slash.Dispatch("guild view")
		assert.equal("view", SB.Config.Get("guildBank.mode"))
		assert.equal(UIParent, gf.parent)
		SB.Slash.Dispatch("guild nonsense")
		assert.same({ SB.L.GUILD_MODE_VIEW, "Use /swagbag guild full or /swagbag guild view (now: view)." }, A.Lines())
	end)

	it("an error in a slot click switches only the bank to Safe Mode and hands the guild bank back", function()
		openVault()
		answerQueries()
		A.GuildWithdraw = function() error("boom") end
		Fake.Fire(button(1, 1), "OnClick", "RightButton")
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal(UIParent, gf.parent)
	end)
end)

describe("GuildBankWindow load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		local ok, err = pcall(Env.LoadGuild, SB)
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
```

<!-- sbw3:edit T10 s04 spec/items_spec.lua -->
In `spec/items_spec.lua`, find:

```lua
	local SB, A, Items
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Items.lua" })
		A, Items = SB.Adapter, SB.Items
		Fixtures.SmallBags(A)
```

and replace it with:

```lua
	local SB, A, Items
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Items.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
			"SwagBag/Engine/Query/Query.lua", "SwagBag/Engine/Keywords.lua" })
		A, Items = SB.Adapter, SB.Items
		Fixtures.SmallBags(A)
```

<!-- sbw3:edit T10 s05 spec/items_spec.lua -->
In `spec/items_spec.lua`, find:

```lua
		assert.equal(false, r.pending)
		assert.equal(true, r.isUsable)
	end)

```

and replace it with:

```lua
		assert.equal(false, r.pending)
		assert.equal(true, r.isUsable)
	end)

	it("DescribeLink builds a guild bank record from the link: location guild, never bound, cooldown or new", function()
		local link = "|cffa335ee|Hitem:" .. Fixtures.BOE_RING .. "::::::::90:::::|h[Band of the Fallen]|h|r"
		local r = Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = link, count = 1, icon = 7, quality = 4 }, 102, 5, 2)
		assert.same({ 102, 5, 2, "guild", "Band of the Fallen", 285, "equip", "INVTYPE_FINGER" },
			{ r.bag, r.slot, r.tab, r.location, r.name, r.ilvl, r.bind, r.equipLoc })
		assert.same({ false, false, false, false, false }, { r.isBound, r.isWUE, r.onCooldown, r.isNew, r.pending })
		assert.equal(true, SB.Query.Eval(SB.Query.Compile("boe & ilvl>280"), r))
		local p = Items.DescribeLink({ itemID = Fixtures.UNLOADED, link = "item:" .. Fixtures.UNLOADED, count = 1 }, 101, 1, 1)
		assert.equal(true, p.pending)
		assert.same({ Fixtures.UNLOADED }, A.loadRequests)
	end)

```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/guildbank_spec.lua spec/items_spec.lua`
Expected: `29 passed, 10 failed`. The tab headers, sections, search, answered-tab tracking and snapshot do not exist yet.

Critical tests and the mutation that must make each fail:
- "a reopen shows the session's cached contents at once; a tab whose answer is on its way is not read": `if GW.answered[tab] or GW.cache[tab] then` in `GW.Refresh`.
- "a query that gets no answer moves on after QUERY_GAP and is asked once more at the end": drop `and not GW.retried[tab]` in `timedOut`.
- "each tab is a group with its own sections…": `if false then` for the first-load layout in `GW.Refresh`.
- "a snapshot of the tabs read is saved per guild…": delete the `SaveSnapshot` call in `GW.OnClosed`.
- "deposits go to the tab Blizzard has selected … its header says so": delete `GW.view.Relabel()` in `GW.RefreshTarget`.
- "nothing moves while Blizzard's guild bank frame is still hidden…": `if not gf then` instead of `if not (gf and gf:IsShown()) then` in `GW.ApplyMode`.
- Task 2's mutations still apply to the same tests.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T10 i01 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
		return C_Item.GetCurrentItemLevel(location(bag, slot))
	end)
	if ok and type(v) == "number" and not isSecret(v) then
		return v
```

and replace it with:

```lua
		return C_Item.GetCurrentItemLevel(location(bag, slot))
	end)
	if ok and type(v) == "number" and not isSecret(v) then
		return v
	end
	return nil
end

-- Item level of an item link (guild bank items have no bag slot), or nil.
function A.GetLinkIlvl(link)
	if type(link) ~= "string" or not (C_Item and C_Item.GetDetailedItemLevelInfo) then
		return nil
	end
	local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
	if ok and type(v) == "number" and not isSecret(v) then
		return v
```

<!-- sbw3:edit T10 i02 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua
	{ path = "C_Item.IsBoundToAccountUntilEquip", window = "bags", required = false },
	{ path = "C_Item.GetItemUpgradeInfo", window = "bags", required = false },
	{ path = "C_ToyBox.GetToyInfo", window = "bags", required = false },
	{ path = "C_Timer.After", window = "bags", required = true },
```

and replace it with:

```lua
	{ path = "C_Item.IsBoundToAccountUntilEquip", window = "bags", required = false },
	{ path = "C_Item.GetItemUpgradeInfo", window = "bags", required = false },
	{ path = "C_Item.GetDetailedItemLevelInfo", window = "bank", required = false },
	{ path = "C_ToyBox.GetToyInfo", window = "bags", required = false },
	{ path = "C_Timer.After", window = "bags", required = true },
```

<!-- sbw3:edit T10 i03 SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
		-- with Blizzard's frame beside it; the fallback if check G1 fails). withdrawAnyTab: a
		-- right-click withdraws from any tab (false: only from the tab Blizzard has selected).
		guildBank = { mode = "full", withdrawAnyTab = true },
		-- Overlays on item buttons (spec F9); usePawn: Pawn decides the upgrade arrow.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = true,
```

and replace it with:

```lua
		-- with Blizzard's frame beside it; the fallback if check G1 fails). withdrawAnyTab: a
		-- right-click withdraws from any tab (false: only from the tab Blizzard has selected).
		-- view / columns: as for the bank window.
		guildBank = { mode = "full", withdrawAnyTab = true, view = "sections", columns = 14 },
		-- Overlays on item buttons (spec F9); usePawn: Pawn decides the upgrade arrow.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = true,
```

<!-- sbw3:edit T10 i04 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.GUILD_TAB_N = "Tab %d"
L.GUILD_DEPOSITS_TO = "Deposits go to %s - switch with the tabs on the right"
L.GUILD_TAB_HEADER = "%s - %s"
L.GUILD_WITHDRAW_LEFT = "%d withdrawals left today"
L.GUILD_WITHDRAW_UNLIMITED = "unlimited withdrawals"
```

and replace it with:

```lua
L.GUILD_TAB_N = "Tab %d"
L.GUILD_DEPOSITS_TO = "Deposits go to %s - switch with the tabs on the right"
L.GUILD_TAB_LABEL = "%s %s (%d) - %s"
L.GUILD_WITHDRAW_LEFT = "%d withdrawals left today"
L.GUILD_WITHDRAW_UNLIMITED = "unlimited withdrawals"
```

<!-- sbw3:edit T10 i05 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.GUILD_MODE_VIEW = "Guild bank: Blizzard's window is shown; SwagBag's window beside it is view-only."
L.REPORT_GUILD = "Guild bank: setting %s, last visit %s"

-- Snapshots (spec F13: captured now, shown offline in November)
```

and replace it with:

```lua
L.GUILD_MODE_VIEW = "Guild bank: Blizzard's window is shown; SwagBag's window beside it is view-only."
L.REPORT_GUILD = "Guild bank: setting %s, last visit %s"
L.GUILD_VIEW_GRID = "SwagBag guild bank - grid view"
L.GUILD_VIEW_SECTIONS = "SwagBag guild bank - category view"

-- Snapshots (spec F13: captured now, shown offline in November)
```

<!-- sbw3:edit T10 i06 SwagBag/Engine/Items.lua -->
In `SwagBag/Engine/Items.lua`, find:

```lua
--   isBound, isWUE, isLocked, onCooldown, inEquipmentSet, hasUpgradeTrack,
--   isUsable, isToy, isQuestItem, isKeystone, isCagedPet, isNew    booleans
--   location        "backpack"|"bags"|"reagentbag"|"bank"|"warband"
--   tab             bank tab number (1-based) | nil
--   track           { track, level, max } upgrade track | nil (overlays)
```

and replace it with:

```lua
--   isBound, isWUE, isLocked, onCooldown, inEquipmentSet, hasUpgradeTrack,
--   isUsable, isToy, isQuestItem, isKeystone, isCagedPet, isNew    booleans
--   location        "backpack"|"bags"|"reagentbag"|"bank"|"warband"|"guild"
--   tab             bank tab number (1-based) | nil
--   track           { track, level, max } upgrade track | nil (overlays)
```

<!-- sbw3:edit T10 i07 SwagBag/Engine/Items.lua -->
In `SwagBag/Engine/Items.lua`, find:

```lua
end

-- Re-read the facts that change without a bag update: cooldown, usability, "new".
-- Three cheap lookups, no item-info calls. Returns the same record.
```

and replace it with:

```lua
end

-- A record for an item that is not in a container slot (a guild bank slot), built from its
-- link: info = Adapter.GuildSlot result { itemID, link, count, icon, quality, isLocked }.
-- bag is the caller's slot key (guild tab N uses bag 100 + N); location is "guild". Guild
-- bank items are never bound, never on cooldown and never new.
function Items.DescribeLink(info, bag, slot, tab)
	local A = SB.Adapter
	local inst = A.GetItemInstant(info.itemID) or {}
	local data = A.GetItemInfo(info.itemID)
	local link = info.link or ""
	local r = {
		bag = bag,
		slot = slot,
		itemID = info.itemID,
		link = info.link,
		count = info.count or 1,
		icon = info.icon,
		quality = info.quality,
		classID = inst.classID,
		subclassID = inst.subclassID,
		equipLoc = inst.equipLoc or "",
		isBound = false,
		isLocked = info.isLocked == true,
		isWUE = false,
		onCooldown = false,
		inEquipmentSet = false,
		hasUpgradeTrack = false,
		track = A.UpgradeInfo(info.link),
		hasNoValue = false,
		isUsable = A.IsUsable(info.itemID),
		isToy = A.IsToy(info.itemID),
		isQuestItem = inst.classID == A.ITEM_CLASS.Questitem,
		isKeystone = link:find("keystone:", 1, true) ~= nil,
		isCagedPet = link:find("battlepet:", 1, true) ~= nil,
		isNew = false,
		location = "guild",
		tab = tab,
		pending = data == nil,
	}
	if data then
		r.name = data.name
		if r.quality == nil then
			r.quality = data.quality
		end
		r.reqLevel = data.reqLevel
		r.maxStack = data.maxStack
		r.bind = data.bind
		r.isCraftingReagent = data.isCraftingReagent
		r.ilvl = A.GetLinkIlvl(info.link) or data.baseIlvl
	else
		A.RequestLoad(info.itemID)
	end
	return r
end

-- Re-read the facts that change without a bag update: cooldown, usability, "new".
-- Three cheap lookups, no item-info calls. Returns the same record.
```

<!-- sbw3:file T10 i08 SwagBag/UI/GuildBankWindow.lua -->
Replace the whole file `SwagBag/UI/GuildBankWindow.lua` with:

```lua
-- SwagBag guild bank window (spec F16). Opens when the guild vault opens. Blizzard's guild
-- bank frame stays open the whole time (hiding it would end the visit):
--   "full" (default)  Blizzard's frame is shown but invisible (UI/TinyHost.lua); its real tab
--                     buttons sit on the right edge of SwagBag's window. A right-click
--                     withdraws to the bags, a drag picks up or drops, a right-click on a bag
--                     item deposits into the tab Blizzard has selected (Blizzard's own code).
--   "view"            Blizzard's frame is left as Blizzard shows it and SwagBag's window is
--                     read-only beside it (the fallback if check G1 fails; spec AC16.6).
-- The "Blizzard guild bank" button switches to "view" for this visit (gold, log,
-- permissions, tab purchase stay in Blizzard's frame; spec AC16.5). Setting:
-- guildBank.mode (/swagbag guild full|view). SwagBag never selects a tab and never writes
-- Blizzard's guild bank frame state (spec AC16.7): it reads the selected tab only.
-- Contents (UI/GroupView.lua): every viewable tab is a group, top to bottom, with its daily
-- withdrawals left in the header (AC16.2) and its own category sections or grid; the window
-- has its own search box (AC16.1). Tab contents load on demand (QueryGuildBankTab, one tab
-- after another) and are kept for the session, so a reopen shows them at once; a snapshot is
-- saved per guild (AC16.4). Guild slot keys use bag 100 + tab.
-- Queries go out one at a time: a GUILDBANKBAGSLOTS_CHANGED that arrives while tab T is being
-- queried is T's answer. Only tabs that answered during this visit are read, so a tab whose
-- answer is still on its way never looks empty. A tab that gets no answer in QUERY_GAP is
-- asked once more at the end of the queue.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local GW = {
	interaction = false, -- the vault is open
	visit = nil, -- "full" | "view" for this visit (the Blizzard guild bank button), nil = setting
	target = nil, -- the tab Blizzard has selected, last read
	lastVisit = nil,
	tabs = {}, -- [tab] = Adapter.GuildTabs entry (only tabs the guild owns)
	order = {}, -- viewable tab numbers, ascending
	cache = {}, -- [tab][slot] = Adapter.GuildSlot result, kept for the session
	queue = {}, -- tabs still to query this visit
	answered = {}, -- [tab] = true once its answer arrived this visit
	retried = {}, -- [tab] = true once re-queued after a query got no answer
	querying = nil,
	BAG_BASE = 100, -- guild tab N is bag 100 + N in layout keys
	QUERY_GAP = 0.3, -- seconds between two tab queries (and the wait if no answer comes)
	SNAPSHOT_DELAY = 1,
	HEADER = 80,
	FOOTER = 6,
	MAX_HEIGHT_FRACTION = 0.75,
}
SB.GuildBankWindow = GW

local host = SB.TinyHost.New("guild", "bank")
GW.host = host

local frame = CreateFrame("Frame", "SwagBagGuildBankWindow", UIParent, "BackdropTemplate")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(600, 200)
frame:Hide()
if frame.SetDontSavePosition then
	frame:SetDontSavePosition(true)
end
GW.frame = frame
table.insert(UISpecialFrames, "SwagBagGuildBankWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.GUILD_TITLE)

frame.deposit = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.deposit:SetPoint("TOPLEFT", 14, -58)
frame.deposit:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -GW.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, GW.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
GW.scroll, GW.child = scroll, child
SB.GuildButtons.SetParent(child)

local function clampScroll()
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("guild.wheel", function(_, delta)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (SB.GroupView.SLOT + SB.GroupView.GAP) * 3)
	clampScroll()
end, "bank"))

local function blizzardGuildBank()
	return SB.Adapter.Frame("GuildBankFrame")
end

---------------------------------------------------------------------------
-- Title feedback and position
---------------------------------------------------------------------------
local titleToken = 0
function GW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("guild.flash", function()
		if token == titleToken then
			frame.title:SetText(L.GUILD_TITLE)
		end
	end, "bank"))
end

function GW.RestorePosition()
	local p = SB.Config.UI().positions.guild
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)
	end
end

frame:SetScript("OnDragStart", Guard("guild.dragStart", function()
	frame:StartMoving()
end, "bank"))
frame:SetScript("OnDragStop", Guard("guild.dragStop", function()
	frame:StopMovingOrSizing()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top and GW.VisitMode() == "full" then
		SB.Config.UI().positions.guild = { "TOPLEFT", "BOTTOMLEFT", left, top }
	end
end, "bank"))

---------------------------------------------------------------------------
-- Full / view
---------------------------------------------------------------------------
function GW.Mode()
	return SB.Config.Get("guildBank.mode") == "view" and "view" or "full"
end

function GW.VisitMode()
	return GW.visit or GW.Mode()
end

local function tabName(tab)
	local t = GW.tabs[tab]
	return (t and t.name and t.name ~= "") and t.name or L.GUILD_TAB_N:format(tab)
end
GW.TabName = tabName

-- Read the tab Blizzard has selected (never written) and show where deposits go.
function GW.RefreshTarget()
	local old = GW.target
	GW.target = SB.Adapter.GuildCurrentTab()
	frame.deposit:SetText(GW.target and L.GUILD_DEPOSITS_TO:format(tabName(GW.target)) or "")
	if old ~= GW.target and GW.view and GW.view.IsOpen() then
		GW.view.Relabel()
	end
end

-- Blizzard's tab buttons run Blizzard's code; SwagBag reads the result on the next frame.
local hookedTabs = setmetatable({}, { __mode = "k" })
local function hookTabs(tabFrames)
	for _, t in ipairs(tabFrames) do
		local b = t.Button or t
		if not hookedTabs[b] and b.HookScript then
			hookedTabs[b] = true
			b:HookScript("OnClick", Guard("guild.tabClick", function()
				SB.Adapter.After(0, Guard("guild.tabRead", GW.RefreshTarget, "bank"))
			end, "bank"))
		end
	end
end

local function rehostTabs(tabFrames)
	for i, t in ipairs(tabFrames) do
		host.Rehost(t, frame, function(f)
			if i == 1 then
				f:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -16)
			else
				f:SetPoint("TOPLEFT", tabFrames[i - 1], "BOTTOMLEFT", 0, -6)
			end
		end)
	end
end

local function anchorBeside(gf)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", gf, "TOPRIGHT", 8, 0)
end

-- Put Blizzard's guild bank and SwagBag's window in the visit's mode. Blizzard's frame is
-- load-on-demand: until it exists (or while it is hidden) there is nothing to move yet, and
-- its OnShow hook calls this again. In combat parents cannot change: the visit stays "view".
function GW.ApplyMode()
	local gf = blizzardGuildBank()
	if not (gf and gf:IsShown()) then
		return
	end
	local tabFrames = SB.Adapter.GuildTabFrames()
	hookTabs(tabFrames)
	if GW.VisitMode() == "full" then
		if host.Shrink(gf) then
			rehostTabs(tabFrames)
			GW.RestorePosition()
		else
			GW.visit = "view"
			anchorBeside(gf)
			GW.Flash(L.GUILD_COMBAT_VIEW)
		end
	else
		host.Restore()
		anchorBeside(gf)
	end
	GW.lastVisit = GW.VisitMode()
	GW.RefreshTarget()
end

function GW.ToggleVisit()
	if SB.Adapter.InCombat() then
		GW.Flash(L.BANK_NOT_IN_COMBAT)
		return false
	end
	GW.visit = GW.VisitMode() == "full" and "view" or "full"
	GW.ApplyMode()
	GW.Flash(GW.visit == "view" and L.GUILD_SHOWING_BLIZZARD or L.GUILD_HIDING_BLIZZARD)
	return true
end

local function titleButton(text, label, onClick, width)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width or 72, 18)
	b:SetText(text)
	b:SetScript("OnClick", Guard(label, onClick, "bank"))
	return b
end

GW.blizzardButton = titleButton(L.BTN_BLIZZARD_GUILD, "guild.blizzardButton", function()
	GW.ToggleVisit()
end, 140)
GW.blizzardButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

---------------------------------------------------------------------------
-- Tabs, queries and the session cache
---------------------------------------------------------------------------
function GW.ReadTabs()
	GW.tabs, GW.order = {}, {}
	for _, t in ipairs(SB.Adapter.GuildTabs()) do
		GW.tabs[t.tab] = t
		if t.viewable then
			GW.order[#GW.order + 1] = t.tab
		end
	end
	table.sort(GW.order)
end

-- Read every slot of a tab. Returns the new list (the cache is the caller's to update).
local function readTab(tab)
	local A, list = SB.Adapter, {}
	for slot = 1, A.GUILD_SLOTS do
		list[slot] = A.GuildSlot(tab, slot)
	end
	return list
end

-- Query the selected tab first, then the others, one at a time: the next query goes out when
-- the previous answer arrives (GUILDBANKBAGSLOTS_CHANGED) or QUERY_GAP later.
local function timedOut()
	local tab = GW.querying
	if tab and not GW.answered[tab] and not GW.retried[tab] then
		GW.retried[tab] = true
		GW.queue[#GW.queue + 1] = tab
	end
	GW.QueryNext()
end

function GW.QueryNext()
	local tab = table.remove(GW.queue, 1)
	GW.querying = tab
	if not tab then
		return
	end
	SB.Adapter.GuildQuery(tab)
	SB.Debounce("guild.queryNext", GW.QUERY_GAP, timedOut, "bank")
end

function GW.QueryAll()
	GW.queue, GW.answered, GW.retried = {}, {}, {}
	local first = SB.Adapter.GuildCurrentTab()
	if first and GW.tabs[first] and GW.tabs[first].viewable then
		GW.queue[1] = first
	end
	for _, tab in ipairs(GW.order) do
		if tab ~= first then
			GW.queue[#GW.queue + 1] = tab
		end
	end
	GW.QueryNext()
end

-- The tabs read this session, for the per-guild snapshot (AC16.4).
function GW.SaveSnapshot()
	local tabs = {}
	for tab, slots in pairs(GW.cache) do
		tabs[tab] = { name = tabName(tab), slots = slots }
	end
	return SB.Snapshots.SaveGuild(SB.Adapter.GuildKey(), tabs)
end

---------------------------------------------------------------------------
-- Contents: one group per viewable tab
---------------------------------------------------------------------------
local function withdrawText(t)
	if not t or t.withdrawals < 0 then
		return L.GUILD_WITHDRAW_UNLIMITED
	elseif t.withdrawals == 0 then
		return L.GUILD_WITHDRAW_NONE
	end
	return L.GUILD_WITHDRAW_LEFT:format(t.withdrawals)
end
GW.WithdrawText = withdrawText

local function tabOf(bag)
	return bag - GW.BAG_BASE
end

function GW.TabLabel(tab, collapsed, count)
	local text = L.GUILD_TAB_LABEL:format(collapsed and "+" or "-", tabName(tab), count or 0, withdrawText(GW.tabs[tab]))
	if not GW.cache[tab] then
		text = text .. L.GUILD_TAB_LOADING
	end
	if tab == GW.target then
		text = text .. L.GUILD_DEPOSITS_HERE
	end
	return text
end

function GW.View()
	return SB.Config.Get("guildBank.view") == "grid" and "grid" or "sections"
end

local function sizeFrame(width, height)
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * GW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - GW.HEADER - GW.FOOTER) + GW.HEADER + GW.FOOTER)
	clampScroll()
end

local function describe(bag, slot)
	local tab = tabOf(bag)
	local info = GW.cache[tab] and GW.cache[tab][slot]
	local button = SB.GuildButtons.Get(tab, slot)
	if button then
		SB.GuildButtons.Paint(button, info)
	end
	return info and SB.Items.DescribeLink(info, bag, slot, tab) or nil
end

local searchBox

GW.view = SB.GroupView.New({
	key = "guild",
	window = "bank",
	child = child,
	scroll = scroll,
	button = function(bag, slot)
		return SB.GuildButtons.Get(tabOf(bag), slot)
	end,
	describe = describe,
	groups = function()
		local out = {}
		for _, tab in ipairs(GW.order) do
			out[#out + 1] = { id = "tab" .. tab, bags = { { bag = GW.BAG_BASE + tab, size = SB.Adapter.GUILD_SLOTS } } }
		end
		return out
	end,
	groupLabel = function(id, collapsed, count)
		return GW.TabLabel(tonumber(id:sub(4)), collapsed, count)
	end,
	groupTint = function(id)
		return GW.target ~= nil and id == "tab" .. GW.target
	end,
	view = GW.View,
	columns = function()
		return SB.Config.Get("guildBank.columns")
	end,
	newRows = function()
		return SB.Config.Get("bags.newRows")
	end,
	onResize = sizeFrame,
	onUpdated = function()
		searchBox.Apply()
	end,
})

searchBox = SB.SearchBox.New({
	parent = frame,
	name = "SwagBagGuildSearchBox",
	search = SB.SearchState.New(),
	window = "bank",
	debounceKey = "search.guild",
	isOpen = function()
		return GW.IsOpen()
	end,
	forEachSlot = function(fn)
		return GW.view.ForEachSlot(fn)
	end,
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
	end,
})
GW.searchBox = searchBox

function GW.Layout(reason)
	GW.view.Layout(reason)
	searchBox.Apply()
end

function GW.Reflow(reason)
	if not frame:IsShown() then
		return false
	end
	local done = GW.view.RequestLayout(reason or "reflow")
	if done then
		searchBox.Apply()
	end
	GW.Flash(done and L.REFLOW_DONE or L.REFLOW_WAITING)
	return done
end

function GW.ToggleView()
	local view = GW.View() == "grid" and "sections" or "grid"
	SB.Config.Set("guildBank.view", view)
	GW.viewButton:SetText(view == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	GW.Flash(view == "grid" and L.GUILD_VIEW_GRID or L.GUILD_VIEW_SECTIONS)
	if GW.view.RequestLayout("view") then
		searchBox.Apply()
	end
end

GW.viewButton = titleButton(L.VIEW_TO_GRID, "guild.viewButton", function()
	GW.ToggleView()
end)
GW.viewButton:SetPoint("RIGHT", GW.blizzardButton, "LEFT", -4, 0)
GW.reflowButton = titleButton(L.BTN_REFLOW, "guild.reflowButton", function()
	GW.Reflow("reflow")
end, 60)
GW.reflowButton:SetPoint("RIGHT", GW.viewButton, "LEFT", -4, 0)

-- Re-read the tabs that answered this visit (a query answer, or an item that moved). A tab
-- read for the first time this session is laid out in full (held back while the mouse is
-- over the items); otherwise slots whose item changed go through GroupView.Changes (spec
-- 4.3) and the rest only repaint.
function GW.Refresh()
	local A, B = SB.Adapter, SB.GuildButtons
	local first = false
	local byTab = {}
	for _, tab in ipairs(GW.order) do
		if GW.answered[tab] then
			first = first or GW.cache[tab] == nil
			local old, new = GW.cache[tab] or {}, readTab(tab)
			GW.cache[tab] = new
			local bag = GW.BAG_BASE + tab
			for slot = 1, A.GUILD_SLOTS do
				local a, b = old[slot], new[slot]
				if a ~= nil or b ~= nil then
					local button = B.Get(tab, slot)
					if button then
						B.Paint(button, b)
					end
					if GW.view.IsOpen() then
						GW.view.SetRecord(bag, slot, b and SB.Items.DescribeLink(b, bag, slot, tab) or nil)
					end
					if (a and a.itemID) ~= (b and b.itemID) then
						byTab[tab] = byTab[tab] or {}
						table.insert(byTab[tab], { bag = bag, slot = slot, kind = b and "arrived" or "left", icon = a and a.icon })
					end
				end
			end
		end
	end
	SB.Debounce("guild.snapshot", GW.SNAPSHOT_DELAY, GW.SaveSnapshot, "none")
	if not GW.view.IsOpen() then
		return
	end
	if first then
		GW.view.RequestLayout("load")
		searchBox.Apply()
		return
	end
	for _, tab in ipairs(GW.order) do
		if byTab[tab] then
			GW.view.Changes("tab" .. tab, byTab[tab])
		end
	end
	GW.view.Relabel()
	searchBox.Apply()
end

---------------------------------------------------------------------------
-- Slot actions (called by UI/GuildButtons.lua). Feedback in chat for every refusal (P2).
---------------------------------------------------------------------------
local function slotInfo(tab, slot)
	return GW.cache[tab] and GW.cache[tab][slot]
end

-- Returns what happened: "link" | "view" | "empty" | "limit" | "tab" | "withdraw" | "pickup".
function GW.ClickSlot(tab, slot, mouseButton)
	local A, info = SB.Adapter, slotInfo(tab, slot)
	if info and A.ModifiedClick(info.link) then
		return "link"
	end
	if GW.VisitMode() == "view" then
		SB.Print(L.GUILD_VIEW_ONLY)
		return "view"
	end
	if mouseButton ~= "RightButton" then
		A.GuildPickup(tab, slot)
		return "pickup"
	end
	if not info then
		return "empty"
	end
	local t = GW.tabs[tab]
	if t and t.withdrawals == 0 then
		SB.Print(L.GUILD_NO_WITHDRAWALS:format(tabName(tab)))
		return "limit"
	end
	if not SB.Config.Get("guildBank.withdrawAnyTab") and tab ~= A.GuildCurrentTab() then
		SB.Print(L.GUILD_SELECT_TAB_FIRST:format(tabName(tab)))
		return "tab"
	end
	A.GuildWithdraw(tab, slot)
	return "withdraw"
end

function GW.DragSlot(tab, slot)
	if GW.VisitMode() == "view" then
		SB.Print(L.GUILD_VIEW_ONLY)
		return false
	end
	SB.Adapter.GuildPickup(tab, slot)
	return true
end

function GW.DropSlot(tab, slot)
	return GW.DragSlot(tab, slot)
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
function GW.IsOpen()
	return frame:IsShown()
end

function GW.Open()
	if SB.SafeMode.IsOn("bank") or not GW.interaction then
		return false
	end
	if frame:IsShown() then
		return true
	end
	GW.ReadTabs()
	if not SB.GuildButtons.Ensure(GW.order) then
		SB.Print(L.GUILD_COMBAT_WAIT)
		return false
	end
	GW.viewButton:SetText(GW.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	frame:Show()
	GW.ApplyMode()
	GW.Layout("open")
	GW.QueryAll()
	return true
end

function GW.Close()
	frame:Hide()
end

frame:SetScript("OnHide", Guard("guild.hide", function(self)
	if self:IsShown() then
		return
	end
	GW.queue, GW.querying = {}, nil
	GW.view.Clear()
	SB.Emit("SB_GUILD_CLOSED")
end, "bank"))

function GW.OnOpened()
	if GW.interaction then
		GW.ApplyMode() -- a second signal for the same visit (event and OnShow): just re-apply
		return
	end
	GW.interaction, GW.visit = true, nil
	GW.Open()
end

function GW.OnClosed()
	if not GW.interaction then
		return
	end
	GW.interaction, GW.visit = false, nil
	frame:Hide()
	host.Restore()
	if next(GW.cache) then
		GW.SaveSnapshot()
	end
end

-- Blizzard's guild bank UI loads on demand; hook its OnShow once it exists.
local frameHooked = false
function GW.HookFrame()
	local gf = blizzardGuildBank()
	if frameHooked or not gf then
		return
	end
	frameHooked = true
	gf:HookScript("OnShow", Guard("guild.blizzardShown", function()
		GW.OnOpened()
	end, "bank"))
end

SB.On("ADDON_LOADED", function(_, name)
	if name == "Blizzard_GuildBankUI" then
		GW.HookFrame()
	end
end, "bank")

SB.On("SB_LOGIN", function()
	GW.HookFrame()
end, "bank")

SB.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, interactionType)
	if SB.Adapter.IsGuildBanker(interactionType) then
		GW.HookFrame()
		GW.OnOpened()
	end
end, "bank")

SB.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, interactionType)
	if SB.Adapter.IsGuildBanker(interactionType) then
		GW.OnClosed()
	end
end, "bank")

-- Older clients name the visit with these events; registration fails silently without them.
SB.On("GUILDBANKFRAME_OPENED", function()
	GW.HookFrame()
	GW.OnOpened()
end, "bank")

SB.On("GUILDBANKFRAME_CLOSED", function()
	GW.OnClosed()
end, "bank")

-- A queried tab's contents arrived, or an item moved: query the next tab and re-read the
-- tabs that answered.
SB.On("GUILDBANKBAGSLOTS_CHANGED", function()
	if not GW.interaction then
		return
	end
	if GW.querying then
		GW.answered[GW.querying] = true
		SB.Debounce("guild.queryNext", 0.05, GW.QueryNext, "bank")
	end
	GW.Refresh()
	GW.RefreshTarget()
end, "bank")

SB.On("GUILDBANK_UPDATE_TABS", function()
	if not GW.interaction then
		return
	end
	GW.ReadTabs()
	if frame:IsShown() and SB.GuildButtons.Ensure(GW.order) then
		GW.view.RequestLayout("tabs")
		searchBox.Apply()
	end
end, "bank")

SB.On("GUILDBANK_ITEM_LOCK_CHANGED", function()
	if GW.interaction then
		GW.Refresh()
	end
end, "bank")

SB.On("PLAYER_LOGOUT", function()
	host.Restore()
end, "bank")

SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window ~= "bank" then
		return
	end
	if on then
		frame:Hide()
		host.Restore()
	elseif GW.interaction then
		GW.Open()
	end
end, "none")

SB.Slash.Register("guild", L.HELP_GUILD, function(arg)
	arg = (arg or ""):lower()
	if arg ~= "full" and arg ~= "view" then
		return L.GUILD_USAGE:format(GW.Mode())
	end
	if not SB.Config.Set("guildBank.mode", arg) then
		return L.SETTINGS_READONLY
	end
	GW.visit = nil
	if frame:IsShown() then
		GW.ApplyMode()
	end
	return arg == "full" and L.GUILD_MODE_FULL or L.GUILD_MODE_VIEW
end, "bank")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/guildbank_spec.lua spec/items_spec.lua`
Expected: `39 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (41 files)`, `574 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/helpers/uienv.lua \
  spec/mock_adapter.lua \
  spec/guildbank_spec.lua \
  spec/items_spec.lua \
  SwagBag/Core/Adapter.lua \
  SwagBag/Core/Config.lua \
  SwagBag/Locale/enUS.lua \
  SwagBag/Engine/Items.lua \
  SwagBag/UI/GuildBankWindow.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 10: guild bank on GroupView with sections per tab, queries, cache, search, snapshot" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

Session G2 (the guild bank contents) runs after Task 11, so it can check the overlays on bank and guild items too.

---

### Task 11: Overlays on bank and guild bank buttons

Task 4 drew overlays on the bags only, because the bank and guild bank windows had no contents yet. Now they do (Tasks 8 and 10), so this task applies the same `SB.Overlays.Apply(button, record, bag)` there (spec F9: overlays on every item button):
- the bank window applies overlays in its `describe` and when a live change refreshes a record in place;
- the guild bank window applies them in its `describe` and in `GW.Refresh`, when a tab's answer changes a slot;
- `Overlays.RefreshAll` also redraws the open bank and guild bank windows after a gear change or a `/swagbag overlays` switch.

"Use Pawn" asks Pawn about bag and bank slots only. A guild slot (pseudo bag `100 + N`) has no container, so the item-level rule decides its arrow; a test pins that with a fixture whose Pawn would say "upgrade" for the guild slot.

**Files:**
- Modify: `SwagBag/UI/BankWindow.lua`, `SwagBag/UI/GuildBankWindow.lua` (apply overlays), `SwagBag/UI/Overlays.lua` (`RefreshAll` covers both windows)
- Test: `spec/helpers/uienv.lua` (load `Engine/OverlayData.lua` and `UI/Overlays.lua`), `spec/overlays_spec.lua`, `spec/bankwindow_groups_spec.lua`, `spec/guildbank_spec.lua`

**Interfaces:**
- Consumes:
  - Task 4: `SB.Overlays.Apply/RefreshAll/regions`;
  - Task 8: `SB.BankWindow.view.ForEachSlot`, `Env.LoadBank`;
  - Task 10: `SB.GuildBankWindow.view.ForEachSlot`, `SB.Items.DescribeLink` (records carry `track`), `Env.LoadGuild`.
- Produces: `SB.Overlays.RefreshAll()` now redraws every open window (bags, bank, guild bank). No new names.

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T11 s01 spec/helpers/uienv.lua -->
In `spec/helpers/uienv.lua`, find:

```lua
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
}

```

and replace it with:

```lua
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/OverlayData.lua",
}

```

<!-- sbw3:edit T11 s02 spec/helpers/uienv.lua -->
In `spec/helpers/uienv.lua`, find:

```lua
	end
	for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/SearchBox.lua",
		"SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua" }) do
		Loader.LoadFile(SB, path)
	end
```

and replace it with:

```lua
	end
	for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/SearchBox.lua",
		"SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua", "SwagBag/UI/Overlays.lua" }) do
		Loader.LoadFile(SB, path)
	end
```

<!-- sbw3:edit T11 s03 spec/helpers/uienv.lua -->
In `spec/helpers/uienv.lua`, find:

```lua
	for _, path in ipairs({ "SwagBag/Engine/Snapshots.lua", "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua",
		"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/GuildButtons.lua",
		"SwagBag/UI/GuildBankWindow.lua" }) do
		Loader.LoadFile(SB, path)
	end
```

and replace it with:

```lua
	for _, path in ipairs({ "SwagBag/Engine/Snapshots.lua", "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua",
		"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/GuildButtons.lua",
		"SwagBag/UI/GuildBankWindow.lua", "SwagBag/UI/Overlays.lua" }) do
		Loader.LoadFile(SB, path)
	end
```

<!-- sbw3:edit T11 s04 spec/bankwindow_groups_spec.lua -->
In `spec/bankwindow_groups_spec.lua`, find:

```lua
		assert.equal("- Character bank (2)", header("#bank").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
	end)

```

and replace it with:

```lua
		assert.equal("- Character bank (2)", header("#bank").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
	end)

	it("bank items get their overlays (the BoE ring's item level and badge)", function()
		openBank()
		local r = SB.Overlays.regions[B.Get(12, 2)]
		assert.same({ "285", "BoE" }, { r.topLeft.text, r.bind.text })
	end)

```

<!-- sbw3:edit T11 s05 spec/guildbank_spec.lua -->
In `spec/guildbank_spec.lua`, find:

```lua
		assert.same(herbAt, { SB.Buttons.placeholdersInUse[1].points[1][4], SB.Buttons.placeholdersInUse[1].points[1][5] })
		assert.equal(header("tab1:new").points[1][5] - 20, at(button(1, 7))[2], "the deposit is first in New")
	end)

```

and replace it with:

```lua
		assert.same(herbAt, { SB.Buttons.placeholdersInUse[1].points[1][4], SB.Buttons.placeholdersInUse[1].points[1][5] })
		assert.equal(header("tab1:new").points[1][5] - 20, at(button(1, 7))[2], "the deposit is first in New")
	end)

	it("guild items get their overlays (the BoE ring's item level and badge)", function()
		openVault()
		answerQueries()
		local r = SB.Overlays.regions[button(2, 1)]
		assert.same({ "285", "BoE" }, { r.topLeft.text, r.bind.text })
	end)

```

<!-- sbw3:edit T11 s06 spec/overlays_spec.lua -->
In `spec/overlays_spec.lua`, find:

```lua
		assert.same({ "Overlay title is now off." }, A.Lines())
	end)
end)
```

and replace it with:

```lua
		assert.same({ "Overlay title is now off." }, A.Lines())
	end)

	it("a gear change re-draws the open bank and guild bank windows too", function()
		A.equipped[11] = { ilvl = 270, equipLoc = "INVTYPE_FINGER" }
		local bankButton, bank = draw(0, 3)
		local guildButton, guild = draw(0, 3)
		local record = SB.Items.Describe(0, 3)
		local function window(button)
			return { IsOpen = function() return true end,
				view = { ForEachSlot = function(fn) fn(button, record, 0, 3) end } }
		end
		SB.BankWindow, SB.GuildBankWindow = window(bankButton), window(guildButton)
		A.equipped[11] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		SB.eventFrame:Fire("PLAYER_EQUIPMENT_CHANGED", 11)
		A.Advance(0.1)
		assert.same({ false, false }, { bank.arrow.shown, guild.arrow.shown })
	end)

	it("Use Pawn never asks Pawn about a guild bank slot; the item-level rule decides there", function()
		A.equipped[11] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.equipped[12] = { ilvl = 300, equipLoc = "INVTYPE_FINGER" }
		A.pawn = { ["101:3"] = true }
		SB.Config.Set("overlays.usePawn", true)
		local g = Fake.New("ItemButton")
		Ov.Apply(g, SB.Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = "item:" .. Fixtures.BOE_RING, count = 1 },
			101, 3, 1), 101)
		assert.falsy(Ov.regions[g].arrow.shown, "285 does not beat 300")
	end)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/bankwindow_groups_spec.lua spec/guildbank_spec.lua spec/overlays_spec.lua`
Expected: `57 passed, 3 failed`. The bank and guild windows do not apply overlays yet, and `Overlays.RefreshAll` redraws only the bags window. The fourth new test (Use Pawn and a guild slot) already passes, because Task 4's `Ov.Context` asks Pawn only about container slots; it is there to keep it that way now that guild buttons draw overlays.

Critical tests and the mutation that must make each fail:
- `bankwindow_groups_spec` "bank items get their overlays (the BoE ring's item level and badge)": delete the `SB.Overlays.Apply(button, record, bag)` block in the bank window's `describe`.
- `guildbank_spec` "guild items get their overlays (the BoE ring's item level and badge)": delete the `SB.Overlays.Apply(button, record, bag)` blocks in both the guild window's `describe` and `GW.Refresh`. (Deleting only one survives: the first answer reaches the buttons through both paths.)
- `overlays_spec` "a gear change re-draws the open bank and guild bank windows too": delete the `if bank and bank.IsOpen() then … end` block in `Ov.RefreshAll`.
- `overlays_spec` "Use Pawn never asks Pawn about a guild bank slot…": `if record.bag then` instead of `if record.bag and A.BagKind(record.bag) then` in `Ov.Context`.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T11 i01 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua
		record.icon = (A.GetItemInstant(record.itemID) or {}).icon
	end
	return record
end
```

and replace it with:

```lua
		record.icon = (A.GetItemInstant(record.itemID) or {}).icon
	end
	if SB.Overlays then
		SB.Overlays.Apply(button, record, bag)
	end
	return record
end
```

<!-- sbw3:edit T11 i02 SwagBag/UI/BankWindow.lua -->
In `SwagBag/UI/BankWindow.lua`, find:

```lua
					fresh.icon = fresh.icon or old.icon
					v.SetRecord(c.bag, c.slot, fresh)
				end
			else
```

and replace it with:

```lua
					fresh.icon = fresh.icon or old.icon
					v.SetRecord(c.bag, c.slot, fresh)
					if SB.Overlays then
						SB.Overlays.Apply(button, fresh, c.bag)
					end
				end
			else
```

<!-- sbw3:edit T11 i03 SwagBag/UI/GuildBankWindow.lua -->
In `SwagBag/UI/GuildBankWindow.lua`, find:

```lua
		SB.GuildButtons.Paint(button, info)
	end
	return info and SB.Items.DescribeLink(info, bag, slot, tab) or nil
end

```

and replace it with:

```lua
		SB.GuildButtons.Paint(button, info)
	end
	local record = info and SB.Items.DescribeLink(info, bag, slot, tab) or nil
	if SB.Overlays then
		SB.Overlays.Apply(button, record, bag)
	end
	return record
end

```

<!-- sbw3:edit T11 i04 SwagBag/UI/GuildBankWindow.lua -->
In `SwagBag/UI/GuildBankWindow.lua`, find:

```lua
					end
					if GW.view.IsOpen() then
						GW.view.SetRecord(bag, slot, b and SB.Items.DescribeLink(b, bag, slot, tab) or nil)
					end
					if (a and a.itemID) ~= (b and b.itemID) then
```

and replace it with:

```lua
					end
					if GW.view.IsOpen() then
						local record = b and SB.Items.DescribeLink(b, bag, slot, tab) or nil
						GW.view.SetRecord(bag, slot, record)
						if SB.Overlays then
							SB.Overlays.Apply(button, record, bag)
						end
					end
					if (a and a.itemID) ~= (b and b.itemID) then
```

<!-- sbw3:edit T11 i05 SwagBag/UI/Overlays.lua -->
In `SwagBag/UI/Overlays.lua`, find:

```lua
-- /swagbag overlays also switches the item level in the bags window's title (bags.showIlvl).
--   Overlays.Apply(button, record, bag)   record nil = empty slot
--   Overlays.RefreshAll()                 re-draw the open bags window's buttons
local _, SB = ...

```

and replace it with:

```lua
-- /swagbag overlays also switches the item level in the bags window's title (bags.showIlvl).
--   Overlays.Apply(button, record, bag)   record nil = empty slot
--   Overlays.RefreshAll()                 re-draw every open window's buttons
local _, SB = ...

```

<!-- sbw3:edit T11 i06 SwagBag/UI/Overlays.lua -->
In `SwagBag/UI/Overlays.lua`, find:

```lua
end

-- Re-draw the buttons of the open bags window (equipment or settings changed).
function Ov.RefreshAll()
	local function each(fn)
```

and replace it with:

```lua
end

-- Re-draw the buttons of every open window (equipment or settings changed).
function Ov.RefreshAll()
	local function each(fn)
```

<!-- sbw3:edit T11 i07 SwagBag/UI/Overlays.lua -->
In `SwagBag/UI/Overlays.lua`, find:

```lua
		end)
	end
	local bags = SB.BagsWindow
	if bags and bags.IsOpen() then
		each(bags.ForEachSlot)
	end
end
```

and replace it with:

```lua
		end)
	end
	local bags, bank, guild = SB.BagsWindow, SB.BankWindow, SB.GuildBankWindow
	if bags and bags.IsOpen() then
		each(bags.ForEachSlot)
	end
	if bank and bank.IsOpen() then
		each(bank.view.ForEachSlot)
	end
	if guild and guild.IsOpen() then
		each(guild.view.ForEachSlot)
	end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bankwindow_groups_spec.lua spec/guildbank_spec.lua spec/overlays_spec.lua`
Expected: `60 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (41 files)`, `578 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/helpers/uienv.lua \
  spec/bankwindow_groups_spec.lua \
  spec/guildbank_spec.lua \
  spec/overlays_spec.lua \
  SwagBag/UI/BankWindow.lua \
  SwagBag/UI/GuildBankWindow.lua \
  SwagBag/UI/Overlays.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 11: overlays on bank and guild bank buttons" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 7: In-game session G2 (the user does this on Oct 19; about 15 minutes)**

No new files, so `/reload` is enough. Carry one piece of gear better than what you wear if you have one, and put a BoE item or any gear in the bank beforehand if you can.

1. Type `/reload`. Talk to a banker. In the `SwagBag bank` window, gear shows its item level in the top left corner (for example `285`), a BoE item shows `BoE` on its left side, gear that beats what you wear shows the small green arrow, and gray items show the coin, just as in your bags.
2. Equip a piece of gear from your bags (right-click it) while the bank window is open. Within a moment the arrows in the bank window follow your new gear, and the number in your bags window's title changes. Move the mouse off it. Press **Esc**.
3. Open the guild vault. Every tab you may view is a group, for example `- Mats (12) - 5 withdrawals left today`. Under each header are its own sections: `- New (0)`, your categories, `- Free (N)`. For a moment some tab headers may end with `(loading...)`.
4. Guild gear shows its item level in the top left and `BoE` where it applies, as in your bags. Gear that beats what you wear shows the green arrow.
5. The selected tab's header is green and ends with `  - deposits go here`. Click another tab icon on the right: the green header follows.
6. Right-click a cheap item in your bags. It appears in the first cell of `New` in the selected tab's group. Move the mouse off it.
7. Right-click that item in the guild window. It goes back to your bags, a faded copy stays where it was, and nothing else moves. Move the mouse off it.
8. Click a tab's header, for example `- Mats (12) …`. The whole tab folds into `+ Mats (12) …`. Click it again to open it.
9. Type `herb` (or any word) in the guild window's search box. The guild items that do not match dim, and your bags are not dimmed. Clear the box.
10. Click `Grid`. The title says `SwagBag guild bank - grid view`. Click `Categories` to go back.
11. Press **Esc**. Open the vault again. The tabs' items show at once, with no `(loading...)`.
12. Press **Esc**, walk away, and right-click your Hearthstone: the cast bar appears, with no red message.
13. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks `Snapshots: … 1 guilds …`, `Guild bank: setting full, last visit full`, no new errors and `Blocked actions: none`.

Pass: steps 1–13 behave as described, and no item moved while the mouse was on it.

---

### Task 12: Prices: Vendor and Auctionator providers, session cache, per-category totals in section headers, the `value` keyword

Spec F10 and §3.3. `Engine/Prices.lua` is a provider registry.

**Providers.** The available provider with the highest priority that knows a price answers (ties in name order; D16's keyword uses the same lookup). The built-in `Vendor` provider (priority 0) answers with the sell price. `Providers/Auctionator.lua` registers `Auctionator` (priority 10). It answers only while Auctionator's public API is loaded, calling `Auctionator.API.v1.GetAuctionPriceByItemLink("SwagBag", link)` through the Adapter. Without it, every total is a vendor total, and the header says `vendor` (AC10.2). A bound item counts at its vendor price (D11).

**Cache (AC10.3).** Lookups are cached per link for the session. The cache is dropped when Auctionator reports new prices (`RegisterForDBUpdate`, if offered) and at the first lookup 10 minutes after it was filled. No timer is used. A provider that throws three times is switched off with one chat line and one error-ring entry (spec §3.3), and the vendor price carries on.

**Totals in headers.** Section headers in all three windows end with the section's total:
- with Auctionator: `- Trade Goods (12) - 1,240g`;
- without it: `- Trade Goods (12) - 35g vendor`;
- a section worth nothing shows no value.

The setting is `prices.headerTotals`. Week-2 header strings stay exactly as they were for sections worth 0, so no existing test changes.

**Keyword and report.** The spec §7.3 `value`/`gold` keyword is registered (`value>100 & tradegoods`, §7.4). The report gains `Prices: <source>, N cached`.

**Files:**
- Create: `SwagBag/Engine/Prices.lua`, `SwagBag/Providers/Auctionator.lua`
- Modify: `SwagBag/Core/Adapter.lua` (Auctionator functions), `SwagBag/UI/SectionHeaders.lua` (value in `Label`, `Totals`, `IsVendor`), `SwagBag/UI/BagsWindow.lua` and `SwagBag/UI/GroupView.lua` (totals in headers), `SwagBag/Engine/Keywords.lua` (`value`), `SwagBag/Core/Config.lua` (`prices.headerTotals`), `SwagBag/Locale/enUS.lua`, `SwagBag/Core/Report.lua`, `SwagBag/SwagBag.toc` (new `# Providers` section)
- Test: `spec/mock_adapter.lua` (sell prices, Auctionator), `spec/helpers/uienv.lua`, `spec/prices_spec.lua` (new), `spec/bagswindow_sections_spec.lua`, `spec/bankwindow_groups_spec.lua`, `spec/report_spec.lua`

**Interfaces:**
- Consumes: `SB.Adapter.GetItemInfo(itemID).sellPrice`, `SB.Adapter.Resolve`, `SB.Adapter.Now` (on `main`); Layout states (`state.sections[id].cells`, placeholders flagged `placeholder = true`); Task 7's GroupView section headers; Task 8's `spec/helpers/uienv.lua`. Prices come last because nothing earlier needs them: the overlays (Tasks 3, 4, 11) never read a price.
- Produces:
  - `SB.Prices.RegisterProvider(p)`, with `p = { name, priority, available(), value(link, itemID), onUpdate(cb) }`.
  - `SB.Prices.Value(link, itemID, bound) -> copper | nil, source`, `.Source() -> name`, `.SectionTotals(state, recordOf) -> { [sectionId] = copper }`, `.Money(copper) -> text`, `.Invalidate()`, `.cached`.
  - `SB.Adapter.AuctionatorAvailable()`, `.AuctionatorPrice(link)`, `.AuctionatorOnUpdate(cb)`.
  - `SB.SectionHeaders.Label(name, count, collapsed, overflow, value, vendor)`, `.Totals(state, recordOf) -> totals | nil`, `.IsVendor()`.
  - Keyword `value` (alias `gold`). Setting `prices.headerTotals`. Report line `Prices: %s, %d cached`.

- [ ] **Step 1: Write the failing tests**

<!-- sbw3:edit T12 s01 spec/helpers/uienv.lua -->
In `spec/helpers/uienv.lua`, find:

```lua
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/OverlayData.lua",
}

```

and replace it with:

```lua
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/OverlayData.lua",
}

```

<!-- sbw3:edit T12 s02 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
	end

	M.AddContainers(m)
	return m
```

and replace it with:

```lua
	end

	-- Auctionator: m.auctionator = { prices = { [link] = copper } } while "loaded"; nil otherwise.
	m.auctionator = nil
	m.auctionatorCalls = 0
	function m.AuctionatorAvailable()
		return m.auctionator ~= nil
	end

	function m.AuctionatorPrice(link)
		m.auctionatorCalls = m.auctionatorCalls + 1
		if m.auctionator and m.auctionator.fail then
			error("Auctionator broke")
		end
		return m.auctionator and m.auctionator.prices[link] or nil
	end

	function m.AuctionatorOnUpdate(cb)
		m.auctionatorCallback = cb
	end

	M.AddContainers(m)
	return m
```

<!-- sbw3:edit T12 s03 spec/mock_adapter.lua -->
In `spec/mock_adapter.lua`, find:

```lua
			reqLevel = it.reqLevel or 0,
			maxStack = it.maxStack or 1,
			sellPrice = 0,
			bind = it.bind or "none",
			expansionID = 0,
```

and replace it with:

```lua
			reqLevel = it.reqLevel or 0,
			maxStack = it.maxStack or 1,
			sellPrice = it.sellPrice or 0,
			bind = it.bind or "none",
			expansionID = 0,
```

<!-- sbw3:edit T12 s04 spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
}

```

and replace it with:

```lua
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua",
}

```

<!-- sbw3:edit T12 s05 spec/bagswindow_sections_spec.lua -->
In `spec/bagswindow_sections_spec.lua`, find:

```lua
		assert.equal(0, #W.state.deferred)
		assert.falsy(B.Get(1, 4).shown)
	end)

```

and replace it with:

```lua
		assert.equal(0, #W.state.deferred)
		assert.falsy(B.Get(1, 4).shown)
	end)

	it("section headers show each category's total value, marked vendor without Auctionator (F10)", function()
		A.items[Fixtures.HEALING_POTION].sellPrice = 2500 -- 5 potions: 1g 25s at a vendor
		A.items[Fixtures.FLASK].sellPrice = 60000 -- 2 flasks: 12g
		W.Open()
		assert.equal("- Consumables (2) - 13g vendor", header("c_consumables").text.text)
		assert.equal("- Gear (1)", header("c_gear").text.text, "nothing worth anything: no value")
		A.auctionator = { prices = { ["item:" .. Fixtures.FLASK] = 12400000 } } -- 1,240g each
		SB.Prices.Invalidate()
		W.Close()
		W.Open()
		assert.equal("- Consumables (2) - 2,481g", header("c_consumables").text.text, "AH flasks plus vendor potions")
		SB.Config.Set("prices.headerTotals", false)
		W.Close()
		W.Open()
		assert.equal("- Consumables (2)", header("c_consumables").text.text)
	end)

```

<!-- sbw3:edit T12 s06 spec/bankwindow_groups_spec.lua -->
In `spec/bankwindow_groups_spec.lua`, find:

```lua
		assert.equal("- Character bank (2)", header("#bank").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
	end)

```

and replace it with:

```lua
		assert.equal("- Character bank (2)", header("#bank").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
	end)

	it("bank section headers show each category's total value (F10)", function()
		A.items[Fixtures.HERB].sellPrice = 1500
		A.auctionator = { prices = { ["item:" .. Fixtures.ORE] = 9000 } }
		SB.Prices.Invalidate()
		openBank()
		assert.equal("- Herbs (1) - 3g", header("bank:c_herbs").text.text, "20 herbs at the vendor price, no vendor label")
		assert.equal("- Ore (1) - 9g", header("warband:c_ore").text.text, "10 ore at 90s")
	end)

```

<!-- sbw3:file T12 s07 spec/prices_spec.lua -->
Create `spec/prices_spec.lua`:

```lua
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
	"SwagBag/Engine/Query/Query.lua", "SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua",
}

local HERB_LINK = "|cffffffff|Hitem:210796::::::::80:::::|h[Mycobloom]|h|r"
local RING_LINK = "|cffa335ee|Hitem:225001::::::::80:::::|h[Band of the Fallen]|h|r"

describe("Prices (spec F10, 3.3)", function()
	local SB, A, P
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		A.items[Fixtures.HERB].sellPrice = 1500
		A.items[Fixtures.BOE_RING].sellPrice = 250000
		P = SB.Prices
		SB.Emit("SB_LOGIN")
	end)

	it("money: gold with thousands separators, else silver, else copper", function()
		assert.same({ "12c", "35s", "1,240g", "123,456g", "1g", "0c" },
			{ P.Money(12), P.Money(3550), P.Money(12400000), P.Money(1234567890), P.Money(10000), P.Money(0) })
	end)

	it("without Auctionator the vendor price answers and the source is Vendor", function()
		assert.same({ 1500, "Vendor" }, { P.Value(HERB_LINK, Fixtures.HERB) })
		assert.equal("Vendor", P.Source())
	end)

	it("with Auctionator its price wins; an item it has no price for falls back to the vendor", function()
		A.auctionator = { prices = { [HERB_LINK] = 42000 } }
		P.Invalidate()
		assert.equal("Auctionator", P.Source())
		assert.same({ 42000, "Auctionator" }, { P.Value(HERB_LINK, Fixtures.HERB) })
		assert.same({ 250000, "Vendor" }, { P.Value(RING_LINK, Fixtures.BOE_RING) })
	end)

	it("a bound item is worth its vendor price only", function()
		A.auctionator = { prices = { [RING_LINK] = 9990000 } }
		P.Invalidate()
		assert.same({ 250000, "Vendor" }, { P.Value(RING_LINK, Fixtures.BOE_RING, true) })
		assert.same({ 9990000, "Auctionator" }, { P.Value(RING_LINK, Fixtures.BOE_RING, false) })
	end)

	it("caches per link for the session; Auctionator's update callback and 10 minutes drop the cache", function()
		A.auctionator = { prices = { [HERB_LINK] = 42000 } }
		SB.Emit("SB_LOGIN")
		P.Invalidate()
		P.Value(HERB_LINK, Fixtures.HERB)
		P.Value(HERB_LINK, Fixtures.HERB)
		assert.equal(1, A.auctionatorCalls)
		A.auctionator.prices[HERB_LINK] = 50000
		A.auctionatorCallback()
		assert.equal(50000, P.Value(HERB_LINK, Fixtures.HERB))
		A.auctionator.prices[HERB_LINK] = 60000
		A.Advance(599)
		assert.equal(50000, P.Value(HERB_LINK, Fixtures.HERB), "still cached")
		A.Advance(2)
		assert.equal(60000, P.Value(HERB_LINK, Fixtures.HERB))
		assert.equal(3, A.auctionatorCalls)
	end)

	it("a provider that throws three times is switched off with one line; the vendor price carries on", function()
		A.auctionator = { prices = {}, fail = true }
		P.Invalidate()
		for i = 1, 4 do
			assert.equal(1500, P.Value(HERB_LINK .. i, Fixtures.HERB))
		end
		assert.equal("Vendor", P.Source())
		assert.same({ "Price source Auctionator stopped working and was switched off until /reload." }, A.Lines())
		assert.equal(1, #SB.ErrorTrap.Recent())
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal(3, A.auctionatorCalls, "never asked again")
	end)

	it("providers with the same priority are asked in name order, whatever order they registered in", function()
		local asked = {}
		local function provider(name, v)
			return { name = name, priority = 5, available = function() return true end,
				value = function() asked[#asked + 1] = name return v end }
		end
		P.RegisterProvider(provider("Zeta", 1))
		P.RegisterProvider(provider("Alpha", nil))
		assert.same({ 1, "Zeta" }, { P.Value("item:1", 1) })
		assert.same({ "Alpha", "Zeta" }, asked)
	end)

	it("section totals: value x count per section; placeholders and holes are skipped", function()
		A.items[Fixtures.HEALING_POTION].sellPrice = 100
		local records = {
			[1] = { itemID = Fixtures.HERB, link = HERB_LINK, count = 20 },
			[2] = { itemID = Fixtures.HERB, link = HERB_LINK, count = 3 },
			[3] = { itemID = Fixtures.HEALING_POTION, link = "item:" .. Fixtures.HEALING_POTION, count = 5 },
			[4] = { itemID = Fixtures.UNLOADED, pending = true, count = 1 },
		}
		local st = { sections = {
			c_herbs = { size = 3, cells = { { bag = 0, slot = 1 }, nil, { bag = 0, slot = 2 } } },
			-- a placeholder stands where a button was; its slot's item is counted where the button is now
			c_consumables = { size = 2, cells = { { bag = 0, slot = 3 }, { bag = 0, slot = 3, placeholder = true } } },
			new = { size = 1, cells = { { bag = 0, slot = 4 } } },
		} }
		local totals = P.SectionTotals(st, function(_, slot) return records[slot] end)
		assert.same({ c_herbs = 23 * 1500, c_consumables = 500, new = 0 }, totals)
	end)

	it("the value keyword compares the price per unit in gold (spec 7.4: value>100 & tradegoods)", function()
		A.auctionator = { prices = { [HERB_LINK] = 1500000 } }
		P.Invalidate()
		A.SetBagSize(0, 2)
		A.Put(0, 1, Fixtures.HERB, 20, { link = HERB_LINK })
		A.Put(0, 2, Fixtures.ORE, 5)
		local q = SB.Query.Compile("value>100 & tradegoods")
		assert.equal(true, SB.Query.Eval(q, SB.Items.Describe(0, 1)))
		assert.equal(false, SB.Query.Eval(q, SB.Items.Describe(0, 2)))
	end)
end)
```

<!-- sbw3:edit T12 s08 spec/report_spec.lua -->
In `spec/report_spec.lua`, find:

```lua
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
```

and replace it with:

```lua
	end)

	it("shows which price source answers and how many prices are cached (F10)", function()
		SB.Checks.last = {}
		SB.Prices = { Source = function() return "Auctionator" end, cached = 412 }
		assert.truthy(SB.Report.Build():find("\nPrices: Auctionator, 412 cached", 1, true))
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
```

- [ ] **Step 2: Run them to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/bankwindow_groups_spec.lua spec/prices_spec.lua spec/report_spec.lua`
Expected: `9 passed, 92 failed`. `prices_spec`, `bagswindow_sections_spec` and `bankwindow_groups_spec` now load `Engine/Prices.lua` and `Providers/Auctionator.lua`, which do not exist yet, so all of their tests fail. Only `report_spec`'s older tests pass.

Critical tests and the mutation that must make each fail:
- "a bound item is worth its vendor price only": `if true then` instead of `if not bound or p.name == "Vendor" then` in `lookup`.
- "providers with the same priority are asked in name order, whatever order they registered in": `return a.name > b.name`. The fixture registers Zeta before Alpha.
- "caches per link for the session; Auctionator's update callback and 10 minutes drop the cache": `if false then` for the 10-minute expiry.
- "a provider that throws three times is switched off…": `if false then` for the switch-off.
- "section totals: value x count per section; placeholders and holes are skipped": `if cell then` (the placeholder's slot would be counted twice).
- `bagswindow_sections_spec` "section headers show each category's total value, marked vendor…": always use `L.HEADER_VALUE` in `H.Label`.

- [ ] **Step 3: Implement**

<!-- sbw3:edit T12 i01 SwagBag/SwagBag.toc -->
In `SwagBag/SwagBag.toc`, find:

```text
Engine/Layout.lua
Engine/Snapshots.lua
Engine/OverlayData.lua

# UI
```

and replace it with:

```text
Engine/Layout.lua
Engine/Snapshots.lua
Engine/Prices.lua
Engine/OverlayData.lua

# Providers
Providers/Auctionator.lua

# UI
```

<!-- sbw3:edit T12 i02 SwagBag/Core/Adapter.lua -->
In `SwagBag/Core/Adapter.lua`, find:

```lua

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
```

and replace it with:

```lua

---------------------------------------------------------------------------
-- Auctionator (optional price source, spec F10). Only its public API v1 is used.
---------------------------------------------------------------------------
local function auctionator()
	local api = A.Resolve("Auctionator.API.v1")
	if type(api) == "table" and type(api.GetAuctionPriceByItemLink) == "function" then
		return api
	end
	return nil
end

function A.AuctionatorAvailable()
	return auctionator() ~= nil
end

-- Copper per unit, or nil when Auctionator has no price. Errors are the caller's to count.
function A.AuctionatorPrice(link)
	local api = auctionator()
	if not api then
		return nil
	end
	local v = api.GetAuctionPriceByItemLink("SwagBag", link)
	if type(v) == "number" and not isSecret(v) then
		return v
	end
	return nil
end

-- cb runs whenever Auctionator's price database changes (when the API offers that).
function A.AuctionatorOnUpdate(cb)
	local api = auctionator()
	if api and type(api.RegisterForDBUpdate) == "function" then
		pcall(api.RegisterForDBUpdate, "SwagBag", cb)
	end
end

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
-- flag a failed REQUIRED check turns on. value: exact value expected.
```

<!-- sbw3:edit T12 i03 SwagBag/Core/Config.lua -->
In `SwagBag/Core/Config.lua`, find:

```lua
		-- view / columns: as for the bank window.
		guildBank = { mode = "full", withdrawAnyTab = true, view = "sections", columns = 14 },
		-- Overlays on item buttons (spec F9); usePawn: Pawn decides the upgrade arrow.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = true,
```

and replace it with:

```lua
		-- view / columns: as for the bank window.
		guildBank = { mode = "full", withdrawAnyTab = true, view = "sections", columns = 14 },
		-- headerTotals: each section header shows its total value (spec F10).
		prices = { headerTotals = true },
		-- Overlays on item buttons (spec F9); usePawn: Pawn decides the upgrade arrow.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = true,
```

<!-- sbw3:edit T12 i04 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.HEADER_LABEL = "%s %s (%d)"
L.HEADER_OVERFLOW = "  +%d more below"
L.PLACEHOLDER_TIP = "This item moved or was used - items regroup when you close the bag."

```

and replace it with:

```lua
L.HEADER_LABEL = "%s %s (%d)"
L.HEADER_OVERFLOW = "  +%d more below"
L.HEADER_VALUE = " - %s"
L.HEADER_VALUE_VENDOR = " - %s vendor"
L.PLACEHOLDER_TIP = "This item moved or was used - items regroup when you close the bag."

```

<!-- sbw3:edit T12 i05 SwagBag/Locale/enUS.lua -->
In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_SNAPSHOTS = "Snapshots: %d characters, %d guilds, %d KB"

-- Overlays (spec F9)
L.OVERLAY_TRACK = "%s%d/%d"
```

and replace it with:

```lua
L.REPORT_SNAPSHOTS = "Snapshots: %d characters, %d guilds, %d KB"

-- Prices (spec F10)
L.PRICES_PROVIDER_OFF = "Price source %s stopped working and was switched off until /reload."
L.REPORT_PRICES = "Prices: %s, %d cached"

-- Overlays (spec F9)
L.OVERLAY_TRACK = "%s%d/%d"
```

<!-- sbw3:edit T12 i06 SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
-- Aliases include Syndicator's English spellings used by published Baganator category
-- strings (desk spike F, docs/research/2026-10-syndicator-grammar-diff.md).
-- Not yet registered (need later modules): expansion, gold/value, crafting quality,
-- collection.
local _, SB = ...

```

and replace it with:

```lua
-- Aliases include Syndicator's English spellings used by published Baganator category
-- strings (desk spike F, docs/research/2026-10-syndicator-grammar-diff.md).
-- Not yet registered (need later modules): expansion, crafting quality, collection.
local _, SB = ...

```

<!-- sbw3:edit T12 i07 SwagBag/Engine/Keywords.lua -->
In `SwagBag/Engine/Keywords.lua`, find:

```lua
		return r.tab or false
	end)

	-- State (volatile) ---------------------------------------------------------
```

and replace it with:

```lua
		return r.tab or false
	end)
	-- value>50: price per unit in gold (spec 7.3), from Engine/Prices.lua (AH, else vendor).
	num("value", "volatile", function(r)
		if r.pending then
			return nil
		end
		local copper = SB.Prices and SB.Prices.Value(r.link, r.itemID, r.isBound)
		return copper and copper / 10000 or false
	end, { "gold" })

	-- State (volatile) ---------------------------------------------------------
```

<!-- sbw3:file T12 i08 SwagBag/Engine/Prices.lua -->
Create `SwagBag/Engine/Prices.lua`:

```lua
-- SwagBag prices (spec F10, 3.3). Item values come from providers; the available provider
-- with the highest priority that knows a price answers (ties: name order). Built in:
-- "Vendor" (priority 0, the sell price). Providers/Auctionator.lua adds "Auctionator"
-- (priority 10) while Auctionator is loaded. SwagBag never scans the auction house itself.
-- Lookups are cached per link for the session. The cache is dropped when a provider reports
-- new prices (onUpdate) and at the first lookup 10 minutes after it was filled (no timer).
-- A provider that throws three times in a session is switched off, with one chat line and one
-- error-ring entry; the others carry on (spec 3.3).
--   Prices.RegisterProvider(p)   p = { name, priority, available() -> bool,
--                                      value(link, itemID) -> copper | nil, onUpdate(cb) optional }
--   Prices.Value(link, itemID, bound) -> copper | nil, providerName   per unit; a bound item
--                                      is worth its vendor price only (it cannot be sold on the AH)
--   Prices.Source() -> "Auctionator" | "Vendor" | ...   the provider that answers first
--   Prices.SectionTotals(state, recordOf) -> { [sectionId] = copper }   value x count per
--                                      layout section (Engine/Layout.lua state), placeholders skipped
--   Prices.Money(copper) -> "1,240g" | "35s" | "12c"
--   Prices.Invalidate()
local _, SB = ...

local P = { providers = {}, cache = {}, cached = 0, filledAt = nil, active = nil, errors = {}, off = {},
	MAX_AGE = 600, MAX_ERRORS = 3 }
SB.Prices = P

function P.RegisterProvider(p)
	P.providers[#P.providers + 1] = p
	P.Invalidate()
end

function P.Invalidate()
	P.cache, P.cached, P.filledAt, P.active = {}, 0, nil, nil
end

local function byPriority(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end
	return a.name < b.name
end

-- The available providers, best first (worked out once per cache fill).
local function active()
	if not P.active then
		local list = {}
		for _, p in ipairs(P.providers) do
			if not P.off[p.name] then
				local ok, yes = pcall(p.available)
				if ok and yes then
					list[#list + 1] = p
				end
			end
		end
		table.sort(list, byPriority)
		P.active = list
	end
	return P.active
end

function P.Source()
	local first = active()[1]
	return first and first.name or nil
end

local function failed(p, message)
	P.errors[p.name] = (P.errors[p.name] or 0) + 1
	if P.errors[p.name] >= P.MAX_ERRORS and not P.off[p.name] then
		P.off[p.name] = true
		P.Invalidate()
		pcall(SB.ErrorTrap.OnError, "prices:" .. p.name, "none", tostring(message), "")
		SB.Print(SB.L.PRICES_PROVIDER_OFF:format(p.name))
	end
end

local function lookup(link, itemID, bound)
	for _, p in ipairs(active()) do
		if not bound or p.name == "Vendor" then
			local ok, v = pcall(p.value, link, itemID)
			if not ok then
				failed(p, v)
			elseif type(v) == "number" then
				return v, p.name
			end
		end
	end
	return nil, nil
end

function P.Value(link, itemID, bound)
	local now = SB.Adapter.Now()
	if P.filledAt and now - P.filledAt > P.MAX_AGE then
		P.Invalidate()
	end
	local key = (link or tostring(itemID)) .. (bound and "#b" or "")
	local hit = P.cache[key]
	if hit then
		return hit[1] or nil, hit[2]
	end
	local v, source = lookup(link, itemID, bound)
	P.cache[key] = { v or false, source }
	P.cached = P.cached + 1
	P.filledAt = P.filledAt or now
	return v, source
end

function P.SectionTotals(state, recordOf)
	local totals = {}
	for id, sec in pairs(state.sections) do
		local sum = 0
		for i = 1, sec.size do
			local cell = sec.cells[i]
			if cell and not cell.placeholder then
				local r = recordOf(cell.bag, cell.slot)
				if r and not r.pending then
					local v = P.Value(r.link, r.itemID, r.isBound)
					if v then
						sum = sum + v * (r.count or 1)
					end
				end
			end
		end
		totals[id] = sum
	end
	return totals
end

local function thousands(n)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function P.Money(copper)
	copper = math.floor(copper or 0)
	if copper >= 10000 then
		return thousands(math.floor(copper / 10000)) .. "g"
	elseif copper >= 100 then
		return math.floor(copper / 100) .. "s"
	end
	return copper .. "c"
end

-- The built-in fallback: what a vendor pays.
P.RegisterProvider({
	name = "Vendor",
	priority = 0,
	available = function()
		return true
	end,
	value = function(_, itemID)
		local info = itemID and SB.Adapter.GetItemInfo(itemID)
		return info and info.sellPrice or nil
	end,
})

-- Providers that can say "prices changed" drop the cache when they do.
SB.On("SB_LOGIN", function()
	for _, p in ipairs(P.providers) do
		if p.onUpdate then
			pcall(p.onUpdate, function()
				P.Invalidate()
			end)
		end
	end
end, "none")
```

<!-- sbw3:file T12 i09 SwagBag/Providers/Auctionator.lua -->
Create `SwagBag/Providers/Auctionator.lua`:

```lua
-- SwagBag price provider "Auctionator" (spec F10, 3.3). Optional (P4): it answers only while
-- Auctionator's public API is loaded; otherwise the built-in "Vendor" provider answers and
-- section totals say "vendor". Calls go through the Adapter
-- (Auctionator.API.v1.GetAuctionPriceByItemLink("SwagBag", link)).
local _, SB = ...

SB.Prices.RegisterProvider({
	name = "Auctionator",
	priority = 10,
	available = function()
		return SB.Adapter.AuctionatorAvailable()
	end,
	value = function(link)
		if type(link) ~= "string" then
			return nil
		end
		return SB.Adapter.AuctionatorPrice(link)
	end,
	onUpdate = function(callback)
		SB.Adapter.AuctionatorOnUpdate(callback)
	end,
})
```

<!-- sbw3:edit T12 i10 SwagBag/UI/SectionHeaders.lua -->
In `SwagBag/UI/SectionHeaders.lua`, find:

```lua
local parents, owners = {}, {}

-- Pure: the header text.
function H.Label(name, count, collapsed, overflow)
	local text = L.HEADER_LABEL:format(collapsed and "+" or "-", name, count)
	if overflow and overflow > 0 then
		text = text .. L.HEADER_OVERFLOW:format(overflow)
	end
	return text
end

```

and replace it with:

```lua
local parents, owners = {}, {}

-- Pure: the header text. value (copper, optional) is the section's total value (spec F10),
-- shown when above 0; vendor = the value is the vendor price (no Auctionator).
function H.Label(name, count, collapsed, overflow, value, vendor)
	local text = L.HEADER_LABEL:format(collapsed and "+" or "-", name, count)
	if value and value > 0 then
		text = text .. (vendor and L.HEADER_VALUE_VENDOR or L.HEADER_VALUE):format(SB.Prices.Money(value))
	end
	if overflow and overflow > 0 then
		text = text .. L.HEADER_OVERFLOW:format(overflow)
	end
	return text
end

-- Section totals for a layout state, or nil when header totals are switched off.
-- recordOf(bag, slot) -> item record.
function H.Totals(state, recordOf)
	if not (state and SB.Prices and SB.Config.Get("prices.headerTotals")) then
		return nil
	end
	return SB.Prices.SectionTotals(state, recordOf)
end

function H.IsVendor()
	return SB.Prices ~= nil and SB.Prices.Source() == "Vendor"
end

```

<!-- sbw3:edit T12 i11 SwagBag/UI/GroupView.lua -->
In `SwagBag/UI/GroupView.lua`, find:

```lua
	end

	local function sectionLabel(gid, h)
		if cfg.sectionLabel then
			return cfg.sectionLabel(gid, h)
		end
		return SB.SectionHeaders.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow)
	end

```

and replace it with:

```lua
	end

	local function sectionLabel(gid, h, totals, vendor)
		if cfg.sectionLabel then
			return cfg.sectionLabel(gid, h)
		end
		return SB.SectionHeaders.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow,
			totals[gid] and totals[gid][h.id], vendor)
	end

	-- Each group's section totals (spec F10), or none when switched off.
	local function groupTotals()
		local totals = {}
		for _, g in ipairs(v.groups) do
			totals[g.id] = SB.SectionHeaders.Totals(g.state, v.Record)
		end
		return totals
	end

```

<!-- sbw3:edit T12 i12 SwagBag/UI/GroupView.lua -->
In `SwagBag/UI/GroupView.lua`, find:

```lua
			end
		end
		for _, h in ipairs(pos.headers) do
			H.Acquire(child, h.group .. ":" .. h.id, sectionLabel(h.group, h), GV.PAD, h.y, width, owner)
		end
	end
```

and replace it with:

```lua
			end
		end
		local totals, vendor = groupTotals(), H.IsVendor()
		for _, h in ipairs(pos.headers) do
			H.Acquire(child, h.group .. ":" .. h.id, sectionLabel(h.group, h, totals, vendor), GV.PAD, h.y, width, owner)
		end
	end
```

<!-- sbw3:edit T12 i13 SwagBag/UI/BagsWindow.lua -->
In `SwagBag/UI/BagsWindow.lua`, find:

```lua
	end
	H.ReleaseAll(child)
	for _, h in ipairs(pos.headers) do
		H.Acquire(child, h.id, H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow), W.PAD, h.y,
			pos.width - 2 * W.PAD)
	end
end
```

and replace it with:

```lua
	end
	H.ReleaseAll(child)
	local totals = H.Totals(W.state, function(bag, slot)
		return W.records[bag] and W.records[bag][slot]
	end) or {}
	local vendor = H.IsVendor()
	for _, h in ipairs(pos.headers) do
		H.Acquire(child, h.id, H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow, totals[h.id], vendor),
			W.PAD, h.y, pos.width - 2 * W.PAD)
	end
end
```

<!-- sbw3:edit T12 i14 SwagBag/Core/Report.lua -->
In `SwagBag/Core/Report.lua`, find:

```lua
		end
	end
	if SB.Snapshots and SB.Config.db then -- spec 8.4 budgets, check V10
		local chars, guilds = SB.Snapshots.Count()
```

and replace it with:

```lua
		end
	end
	if SB.Prices then
		lines[#lines + 1] = L.REPORT_PRICES:format(tostring(SB.Prices.Source() or L.REPORT_NONE), SB.Prices.cached)
	end
	if SB.Snapshots and SB.Config.db then -- spec 8.4 budgets, check V10
		local chars, guilds = SB.Snapshots.Count()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/bankwindow_groups_spec.lua spec/prices_spec.lua spec/report_spec.lua`
Expected: `101 passed, 0 failed`

- [ ] **Step 5: Run all checks**

Run: `scripts/check.sh`
Expected: `TOC OK (43 files)`, `590 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add spec/helpers/uienv.lua \
  spec/mock_adapter.lua \
  spec/bagswindow_sections_spec.lua \
  spec/bankwindow_groups_spec.lua \
  spec/prices_spec.lua \
  spec/report_spec.lua \
  SwagBag/SwagBag.toc \
  SwagBag/Core/Adapter.lua \
  SwagBag/Core/Config.lua \
  SwagBag/Locale/enUS.lua \
  SwagBag/Engine/Keywords.lua \
  SwagBag/Engine/Prices.lua \
  SwagBag/Providers/Auctionator.lua \
  SwagBag/UI/SectionHeaders.lua \
  SwagBag/UI/GroupView.lua \
  SwagBag/UI/BagsWindow.lua \
  SwagBag/Core/Report.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 3 Task 12: prices from Auctionator or the vendor, per-category totals in headers, value keyword" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

- [ ] **Step 7: In-game session P1 (the user does this on Oct 20; about 5 minutes)**

Give the user this checklist exactly. Carry some crafting materials and a few consumables. Auctionator may be on or off; say which.

1. Quit the game completely and start it again (new files). Log in. Press **B**.
2. Section headers end with a value. With Auctionator: for example `- Trade Goods (12) - 1,240g`. Without it: for example `- Trade Goods (12) - 35g vendor`. A section worth nothing shows no value.
3. Click the bags window's search box and type `value>1`. Items worth 1 gold or less each, and items with no price, dim. Clear the box with its small x.
4. Talk to a banker. The bank window's section headers show values the same way. Press **Esc**.
5. Open the guild vault. The guild window's section headers show values too. Press **Esc**.
6. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks `Prices: Auctionator, … cached` (or `Prices: Vendor, … cached` without Auctionator), no new errors and `Blocked actions: none`.

Pass: steps 2–6 behave as described.

---

## Daily bank check (Oct 20–21, about 5 minutes; spec §12.2 week 3: "bank and guild bank used for real")

At the end of each day's play, the user answers these and pastes the report:

1. Did you use the bank or the guild bank through SwagBag today? (yes/no; which)
2. Did any deposit land in the wrong bank or tab? (yes/no; which item, which tab the window said)
3. Did any item move while your mouse was on it, in the bags, bank or guild bank window? (yes/no; what were you doing)
4. After leaving a bank, did your Hearthstone or any item work normally? (yes/no)
5. Did any overlay show something wrong (wrong item level, an arrow on worse gear, no arrow on better gear), or did the item level in the bags title not match your character window? (item name, or the two numbers)
6. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks no new errors, `Blocked actions: none`, `Last bank layout` at or below 80 ms for an `open`, and the `Snapshots:` size.

Any "yes" to questions 2, 3 or 5, and any "no" to question 4, is a bug report. Claude first reproduces it as a failing test in the owning spec file (`bankwindow_groups_spec`, `guildbank_spec`, `groupview_spec`, `overlaydata_spec` or `bagswindow_spec`), then fixes it.

## Week 3 exit check (spec §12.2 week 3: "Bank and guild bank used for real; fallback decided by day 2 if a check fails")

The user ticks these in game on Oct 21 and pastes the final `/swagbag report` into Claude Code:

1. [ ] Sessions V2 and G1 passed on Oct 15, or their fallback (`/swagbag bank beside`, `/swagbag guild view`) became the default on Oct 16.
2. [ ] Sessions O1, S3, B1, G2 and P1 passed, or every failure was fixed and its step re-run.
3. [ ] At least three bank visits and two guild vault visits through SwagBag during normal play, with deposits, withdrawals and one Sort.
4. [ ] The daily bank check had no bug answers, or every one was fixed.
5. [ ] Every crest item the user carries is in Keystone & Crests, and its item ID is in `Engine/Crests.lua`.
6. [ ] The final report shows:
   - errors `none` (or only deliberate `debug:error` entries);
   - `Blocked actions: none`;
   - `Last bank layout` at or below 80 ms for `open`;
   - `Snapshots:` at or below about 30 KB per character (check V10);
   - a `Prices:` line naming the source.
7. [ ] Claude ran `scripts/check.sh` on the branch: `ALL CHECKS PASSED`, 590 passed, 0 failed or more. The branch is merged (or kept), as the user chooses.

If a line fails, paste the report, and Claude fixes it before week 4 starts. Any slip is reported at the end of the week (spec §12.2).

## What week 4 builds on

Week 4 (M5 focus modes, signals, the consumables warning, quick setup, settings pages) uses these interfaces unchanged:

- **Windows.** Spec §6.3's "AH/Vendor/Bank" mode expands everything at the bank, and it needs the bank window open. Use `SB.BankWindow.IsOpen()`, `SB.BankWindow.interaction` (the visit is open) and `SB.GuildBankWindow.interaction`. Collapse state lives in `ui.collapsed["bank:<group>"]`, `["bank:#"]`, `["guild:tab<N>"]` and `["guild:#"]`. A focus mode that collapses sections in the bank window writes the group's set and calls `view.Restack()`.
- **Settings pages.** The keys are `bank.blizzardFrame` ("tiny" / "beside"), `guildBank.mode` ("full" / "view"), `guildBank.withdrawAnyTab`, `bank.view`, `bank.columns`, `guildBank.view`, `guildBank.columns`, `prices.headerTotals`, `overlays.ilvl/track/upgrade/keystone/junk/bind/usePawn`, `bags.showIlvl`. Each setting's alternative is next to it (P1); the slash commands give the wording.
- **GroupView** (`SB.GroupView.New(cfg)`) is window-agnostic. Spec §12.3 M8's offline alt view can draw snapshot contents through it with a `describe` that reads `Snapshots.Deserialize` records.
- **Snapshots.** `SB.Snapshots.Deserialize`, `SwagBagDB.chars[...].bags/bank`, `SwagBagDB.warband`, `SwagBagDB.guilds[...]` are what M8 reads.
- **Prices.** `SB.Prices.Value/Source/SectionTotals`. Spec §2.2 v1.1's worth-money highlight uses `Value`.
- **Deferred to week 5 hardening** (logged now, so they are not lost):
  - the bags window could move onto GroupView (one group, no group header) to remove the duplicated window plumbing;
  - the bank and guild windows could get Ctrl+wheel scale (D14).

## Spec coverage (week-3 scope → task)

| Week-3 item (spec §12.2, the brief, the ledgers) | Task |
|---|---|
| V2 first-day check: deposit in tiny mode, Hearthstone afterwards; fallback `bank.blizzardFrame = "beside"` (§5.4, AC2.6) | 1 (session V2) |
| G1 first-day check: withdraw, deposit, tab switch, Hearthstone; fallback `guildBank.mode = "view"` (AC16.6) | 2 (session G1) |
| §5.2 tiny mode: BankFrame shown in a 0.001 parent; TabSystem re-hosted; restored on close, out of combat (§13.2 item 5), on logout (§8.6) | 1 |
| AC2.3 / §5.2 deposit target read from `GetActiveBankType`, receiving group highlighted | 1, 8 |
| AC2.5 / §5.3 never write bank state; forbidden tokens | 1 (tests), all (check.sh) |
| §5.6 Esc hides only SwagBag's window; "Bank still open" | 1 |
| AC2.1 / §5.1 Character bank and Warband bank stacked, sections or grid, purchased tabs only | 7, 8 |
| AC2.7 / §5.5 SortBank per type; regroup after the bank settles; combat refusal with no auto-run (W11) | 8 |
| §9 first bank open ≤ 80 ms, hidden until complete; incremental update budget | 7, 8 (tests + report line) |
| AC16.1 guild tabs stacked, sections or grid, search, per-category totals | 10, 12 |
| AC16.2 withdraw by right-click or drag; withdrawals left in the tab header; limits respected | 2, 10 |
| AC16.3 deposit by right-click into Blizzard's selected tab, highlighted | 2, 10 |
| AC16.4 on-demand `QueryGuildBankTab`, session cache, per-guild snapshot | 2, 9, 10 |
| AC16.5 "Blizzard guild bank" button; AC16.7 never write guild bank state; re-hosted tab buttons | 2 |
| F9 overlays: ilvl, track, arrow (AC9.3, both rings/trinkets, two-hand summed, Use Pawn), keystone level + dungeon, junk coin, BoE/WuE, stack count (Blizzard's), no tooltip parsing; AC9.2 switches | 3, 4 (bags), 11 (bank, guild bank) |
| F10 Prices provider interface (§3.3), Auctionator with session cache, vendor fallback, totals in headers with "vendor" | 12 |
| F13 / §5.7 / §8.3 / §8.4 snapshots captured on every visit, compact strings, size budget | 9, 10 |
| §7.3 `crest`, `value` keywords; §13.2 item 4 crest data file | 3 (`crest`), 12 (`value`) |
| Ledger: EnsureCapacity max-merge; CreateAll retry; SetParentFor after creation; tabs bought after login | 5, 8 |
| Ledger: incremental ApplyChanges (1,290 slots); skip cells with slot > size | 5, 7 |
| Ledger: savePosition after SetScale + second-notch test; no re-anchor while dragging | 5 |
| Ledger: reagent-bag empties in Free (UI cue) | 4 |
| Ledger: week-3 crest item IDs | 3 (data file + names), O1 step 16 (the IDs) |
| A search box per window (AC5.1) | 6, 8, 10 |
| §9 / §13.2 item 6 `BANK_TAB_SETTINGS_UPDATED`, feature-detected | 8 |
| D18 (user, 2026-10-02): average equipped item level in the bags title, one decimal, feature-detected, back after every flash, `bags.showIlvl` | 4 (session O1 steps 2, 6–8, 14) |

Not in week 3 by design: the offline snapshot view and tooltip alt counts (F13 AC13.2–13.3, November M8), the worth-money highlight and the AH value overlay (v1.1), focus modes and settings pages (week 4), bank/guild window scaling (D14).

## How this plan was checked (while writing it)

- **Replay.** Every code block above was extracted from this file and applied, task by task, to a fresh clone of the repo's `main` (`5be2c2b`) in a scratch folder outside the repo (`/tmp/sbw3b`), in the task order above (after the 2026-10-02 reorder, D18). For each task the spec blocks were applied alone first, and the `Expected` line under Step 2 is that red run. Then the whole task was applied and `scripts/check.sh` was run: the totals above (427 → 590 passed, 0 failed) and `ALL CHECKS PASSED` are those green runs.
- **Mutations.** Every "Critical tests" mutation listed under a Step 2 (88 runs, counting each alternative) was applied to the finished code of the reordered plan, and the named test failed.
- **Timing.** The two wall-clock budget tests (1,078 bank slots ≤ 80 ms) measured 7–22 ms over several runs.
- **Spec coverage.** See the table above.
- **Placeholder scan.** No TBD, TODO or "similar to"; every step that changes code shows the code.
- **Name check.** Every `SB.*` name a task uses exists on `main`, in an earlier task's **Produces** block, or in the same task (checked against the final tree with grep).
- **Rules grep.** No `C_`/`Enum` outside `Core/Adapter.lua` (comments included), no `OnUpdate` script, no forbidden token, and no item button created in combat or reparented.
- **Review Focus.** Each of the five lines names the test that pins it, in the task that owns the code.

