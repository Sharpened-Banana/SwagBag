# SwagBag Week 4 (Oct 22–28, 2026): Focus Modes, Signals, Pause, the Low-Consumables Warning, Settings Pages and the Quick Setup Screen. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** By the end of week 4 the user's bags follow what they are doing, with no setup. In a Mythic+ key, a raid or a delve, while fishing or gathering, and at a vendor, auction house or bank, every section except the activity's own collapses, and it comes back when the activity ends. A click peeks a collapsed section; a right-click keeps it open. One button pauses everything. A key, a dungeon entry or a dungeon teleport warns once if consumables are low. A settings window and a one-screen quick setup make every choice findable. This is spec §12.2 week 4: "M5 focus modes + signals + pause + consumables warning · quick setup screen · settings pages", verified by V5–V8 and V11 in real play.

**Architecture:** `Engine/Focus.lua` is a pure state machine: signals in, "which sections are open" out. It never writes the user's saved collapse state. The bags window asks it for a *collapsed view* (the mode's set plus this session's peeks and pins), and it re-stacks through the existing guarded `Restack` path whenever `SB_FOCUS_CHANGED` fires. That path is held by the hover guard and retried every 300 ms, so nothing moves under the mouse. `Engine/Signals.lua` turns WoW events into signals. It reads everything through new feature-detected Adapter functions, with spell lists in a data file (`Engine/FocusData.lua`). `Engine/Consumables.lua` counts watched entries in the bags on the three spec triggers. The settings window (`UI/SettingsWindow.lua`) is SwagBag's own plain frame of data-driven pages. A choice that has a chat command runs that command, so the window and the command never disagree. The bank and guild bank windows are not touched by modes.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- spec §6 (all of it: §6.1 concepts, §6.2 signals, §6.3 the six v1.0 modes in bold, §6.4 state machine, §6.5 cost, §6.6 the warning);
- F8 (AC8.1–AC8.6; AC8.7 custom modes is November, see D13);
- F11 (AC11.1, AC11.2);
- F15 (AC15.1, AC15.2);
- the October half of F7 (§12.1: a one-screen quick setup; AC7.2, AC7.4);
- §10.5's `/swagbag` (opens settings), `setup`, `tour`, `mode [pause|resume|list]`;
- checks V5–V8 and V11 (§11.3);
- every week-3 ledger item marked deferred to week 4 that touches code this week changes (`docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md`, see "Week-3 carry-overs" below).

Week-3 plan (style and interfaces): `docs/superpowers/plans/2026-10-02-swagbag-week3-banks-overlays.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week4-focus`, already checked out from `main` at `aa3fea1` (week 3 merged, 718 tests). No task creates or switches branches.

**The code at `aa3fea1` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). Interfaces used, as they are on `aa3fea1`:
- `SB.On(event, fn, window)`, `SB.Emit`, `SB.Debounce(key, delay, fn, window)` and `SB.OutOfCombat(fn, label, window)`. `SB.On` skips an event the client does not know.
- `SB.ErrorTrap.Run(label, window, fn, ...)` and `Guard(label, fn, window)`. Window labels are `"bags"`, `"bank"` and `"none"` (record only).
- `SB.Config.Get/Set/CharOverride/IsCharOverride/UI/Defaults/readOnly`. `Set` returns false while read-only. A setting with no stored value falls back to `Config.Defaults.settings`.
- `SB.Slash.Register(name, help, fn, window)`. `fn(arg)` returns its feedback; `nil` prints "Done.".
- `SB.Categories.Load/Get/Name/SectionOrder/display` and `SB.Categorizer.Assign`.
- `SB.Layout.Position(state, opts, collapsed)` reads `collapsed[id] == true`. `SB.Layout.Apply(state, changes, isBusy, collapsed)` reads `collapsed[Layout.NEW]`. `SB.Layout.Moves`.
- `SB.BagsWindow`: `Collapsed`, `Restack`, `ToggleSection`, `RequestLayout`, `SetView`, `SetScale`, `RefreshTitle`, `Title`, `Flash`, `IsOpen`, `View`, `frame`, `sortButton`, `reflowButton`, `viewButton`; and the local `renderMoved(oldPos, newPos)`, `anyBusy(keys)` and `busyCheck()`.
- `SB.GroupView.New(cfg)` with `v.RequestLayout` and the header `owner`. `SB.SectionHeaders.Acquire/SetLabel/ReleaseAll` with `onClick(sectionId)`.
- `SB.Inventory.Iterate("bags")`, `Inventory.OnChanged`, `Items.Describe`, `Query.Compile/Eval`.
- `SB.Overlays.RefreshAll`, `SB.Prices`, `SB.Snapshots`.
- Every slash command: `free`, `bank`, `guild`, `overlays`, `snapshot`, and so on.
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua`, `uienv.lua` (`Env.ENGINE`), `spec/mock_adapter.lua` and `spec/fixtures/items.lua` (`Fixtures.SmallBags`).

## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.4.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. `spikes/SwagBagSpikes/SpikeFocus.lua` is reference only.
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator`.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators (`scripts/check.sh` parses every file with LuaJIT).
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace or `Enum`, **comments included**. It is grep-enforced for `C_X.`/`Enum.` and review-enforced for bare names. Every other file calls `SB.Adapter.*`. Files under `spec/` may name them as test data.
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`. `SetCurrentGuildBankTab` is never called.
- P1: every setting ships with a chosen default, and its alternative sits next to it in the same place. Options are phrased as choices ("Peeks / Keeps it open"), never as abstract toggles.
- P2: every command, button and settings choice answers. The answer is a chat line, a title flash or the settings window's status line. Silence is a bug.
- P5 / spec §4.2 rule 5: nothing moves under the mouse or while an item is on the cursor. Held moves retry 300 ms later through `SB.Debounce`, never `OnUpdate`.
- W10 / spec §6.4: applying a mode never moves a button relative to its own section header. Sections below a collapsed one shift as a whole, and that shift is held by the hover guard like any other move.
- P6: every WoW entry point (events, hooks, frame scripts, timers, slash commands, external callbacks) runs inside `SB.ErrorTrap.Run` or `Guard`:
  - focus signals, the consumables triggers and the bags window use `"bags"`;
  - the settings window and the quick setup use `"none"` (a settings glitch is recorded for the report but never takes the bags away; the status line says it failed);
  - bank and guild code keeps `"bank"`.
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`. Numbers shown on buttons go through `tostring` or a Locale format.
- Secure frames: item buttons are never created in combat, never reparented, never re-`SetID`'d. The settings window and the quick setup create only plain `Frame`, `Button` (`UIPanelButtonTemplate`, `UIPanelCloseButton`), `ScrollFrame` and `FontString` regions, so both open in combat.
- A focus mode **never writes the user's saved collapse state** (`SwagBagCharDB.ui.collapsed`). Leaving a mode shows the user's own state again (AC8.2).
- Persisted settings have defaults in `Config.Defaults`. Every new writer refuses while `Config.readOnly` (a newer schema) and says `L.SETTINGS_READONLY`. No schema bump this week: every new value lives under `settings`, which every migration keeps.
- No file calls `Config` at load time (a load-order test per new window). Every `OnHide` handler starts with `if self:IsShown() then return end`.
- No `OnUpdate` anywhere. Idle CPU with every window closed is 0. Spec §6.5 budgets: signal handler ≤ 0.1 ms average, `Recompute` ≤ 0.5 ms for 30 modes, `Apply` with the window open ≤ 5 ms (a header re-stack that touches only the buttons that move).
- Every critical test names the mutation that must make it fail.
- **Tooling (binding, same as weeks 1–3):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- One commit per task, made with `git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit`. The message ends with exactly these two lines:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`
- In-game checks are written for the user, who is not a programmer:
  - numbered, one action per step, each saying exactly what the user should see;
  - quoted strings match `SwagBag/Locale/enUS.lua` exactly; chat lines start with `SwagBag: `;
  - a step after a click on an item says to move the mouse off it;
  - a session after a task that adds files starts with a full game restart, not `/reload`.

  Sessions never block the build: findings come back as fixes.

## Review Focus

1. **A mode switch while the mouse rests on an item.** A key starts, or a vendor closes, while the user is hovering a potion or dragging an item. Expected: no button moves under the mouse or with an item on the cursor. The switch lands within 300 ms of the mouse leaving. A pause pressed meanwhile wins: the held retry draws whatever is current, never a stale mode. Pinned by:
   - Task 3: `bagswindow_sections_spec` "W10 and P5: no button moves relative to its own header, and none moves under the mouse" and "an item on the cursor holds the switch; it applies once the item is put down";
   - Task 4: "pausing while a switch waits under the mouse: the retry draws the paused state, never the mode".
2. **Mode switches in combat** (pulling right as the key starts, or a delve that enters combat on arrival). Expected: the collapse applies at once (moving item buttons is legal in combat), no frame is created, and nothing is blocked. Pinned by Task 3 "a switch in combat applies at once (moving buttons is legal in combat)" and Task 6 "opens in combat, and creates only plain frames (never an item or secure button)".
3. **The user's own collapse choices survive modes.** The user collapses Junk, runs a key and clicks headers during it. Expected: after the key, Junk is still collapsed and nothing else changed. Peeks end when the bag closes, pins when the mode changes. Pinned by:
   - Task 3: "a key starting while the bag is open collapses all but the M+ sections; leaving restores the user's own";
   - Task 4: "AC8.3: a click on a collapsed header peeks it until the bag closes; the saved set is untouched";
   - Task 1: "a peek ends when the bag closes; a pin stays until the mode changes".
4. **Settings from a newer SwagBag (read-only).** Expected: every new writer refuses with `SwagBag's saved settings are read-only, so nothing was changed.` and changes nothing: mode switches, section sets, the watch list, thresholds, the quick setup, and every settings choice. Pinned by:
   - Task 1: "read-only settings: SetEnabled, SetSections and ResetSections refuse and change nothing";
   - Task 5: "read-only settings (a newer schema): every edit refuses and changes nothing";
   - Task 6: "read-only settings: a click refuses with the reason and the selection stays";
   - Task 7: "read-only settings: every focus change refuses with the reason";
   - Task 8: "an item already watched, or read-only settings, keep the item on the cursor with the reason";
   - Task 9: "read-only settings: Apply and Skip refuse with the reason and change nothing".
5. **False positives from activity signals.** Expected:
   - another player's fishing cast, loot after any spell more than 6 s old, a chest ("Opening") and archaeology ("Survey", "Digging") never switch a mode;
   - fishing ends 90 s after the last cast and gathering 120 s after the last gather.

   Pinned by Task 2: "V6: a fishing channel by the player turns Fishing on; it decays 90 s after the last cast", "V8: loot from a node within 6 s of Herb Gathering…", "AC8.6: opening a chest or digging (archaeology) never turns Gathering on" and "loot from a player's corpse or an item after a gathering spell is not gathering".

## Decisions and resolved spec ambiguities (read before Task 1)

| # | Spec text | This plan | Why |
|---|---|---|---|
| D1 | §6.1 `ExpandedSections(windowId)`; week-3 plan "What week 4 builds on": "a focus mode that collapses sections in the bank window writes the group's set and calls `view.Restack()`" | Modes apply to the **bags window only**. The bank and guild bank windows always show the user's own collapse state. A mode never writes any saved collapse set. Instead, the bags window asks `Focus.CollapsedView(savedSet)` and gets a read-only lookup. | §6.3: at the bank "everything expands by default (bank mode is about highlighting, not collapsing)". Writing the saved set would lose the user's own choices (AC3.2, AC8.2 "leaving restores"). |
| D2 | §6.1 "'No active mode' → all sections expanded (normal browsing)" | "Expanded" means "not collapsed by a mode". With no mode, and at the bank, the user's own saved collapse state applies as before. | AC3.2 makes collapse state persist; reading §6.1 literally would reopen every section the user closed. |
| D3 | §6.3 section lists include "New" | New is never collapsed by a mode, even when a user's edited set leaves it out. Free follows the set like any section, so it is collapsed in all six built-in modes (its header still shows the free count). | Loot during a key must stay visible (AC3.3). |
| D4 | §6.3 Delves: "Delve items (keys/curios via query)" | Delves opens Consumables and Gear (plus New). §7.6 has no "Delve items" category. The user can add any section in Settings → Focus modes. | No such category exists, and inventing one changes every user's bags. |
| D5 | §6.3 AH/Vendor/Bank: "Sellables (worth-money rule)" | Opens Junk, Trade Goods and BoE gear. | The worth-money rule is v1.1 (§2.2). |
| D6 | §6.3 Gathering: "the profession's materials sections … (Herbs / Ore / Leather / Cloth), Tools" | Tools is `c_tools` ("Teleports & Tools"). Herbs, Ore, and Leather & Cloth are dropped for professions the character lacks. If the client cannot tell the professions, all three open. | §7.6 has one "Leather & Cloth" category. Feature detection needs a fallback. |
| D7 | §6.1 / AC8.3 "a small pin on the peeked header" | **Right-click** on a header pins it (no new frame). The header text says how: `(peek - right-click keeps it open)` while peeked, `(kept open)` while pinned. A second right-click unpins. In a mode, a left-click on an *open* section closes it for this opening of the bag. Without a mode, a right-click is a plain click. | Section headers are pooled plain Buttons; text needs no new widget and tells the user what to do. The spec does not say what a click on an open section does in a mode. |
| D8 | §6.1 "Pause modes for this session (one click, with a visible 'Paused' badge and a resume button)" | A `Pause` button in the bags title row (between Sort and Reflow) turns into `Resume`, and the title reads `SwagBag — Paused`. The pause lasts until Resume or `/reload` and is not saved. Signals keep tracking while paused, so Resume shows the right mode at once. The consumables warning is not paused (pause is about collapsing). A switch that is held under the mouse is never queued: the 300 ms retry draws whatever is current when it runs, so a pause pressed while a switch waits shows the user's own state and never the stale mode. | Spec §6.1/§6.4 leave the held-switch and pause interaction undefined; "latest state wins" can never show a stale layout. |
| D9 | AC8.5 "the current mode is shown in the window title ('SwagBag — M+') and a click on it opens the mode's section list for editing" | The title reads `SwagBag — M+` (`SwagBag — M+ — ilvl 279.4` with the item level). A **right-click on the Pause button** opens Settings → Focus modes at the active mode's sections. The button's tooltip says both clicks. | The title is a FontString inside the window's drag area. A second clickable title would steal the window's drag. |
| D10 | — | In the grid view, a mode changes only the title (the grid has no sections). | AC3.6: the grid is physical order. |
| D11 | §6.2 lists `combat`, `encounter`, `pvpMatch`, `tradeSkillOpen` (v1.1), `mapRestricted` | Not wired this week: no v1.0 mode reads them, and an unused event still costs a handler. The guild vault is not a market signal (§6.2 lists only `BANKFRAME_*`). `ADDON_RESTRICTION_STATE_CHANGED` is wired (it refreshes `challengeMode`). | §6.5: "zero cost while … no signal fires". |
| D12 | §6.1 strict priority "within a class, user order" | Within a class, the mode order is fixed: M+, Raid, Delves, Gathering, Fishing. No mode-order editing this week. | No combination of the six v1.0 modes depends on it in practice (M+, Raid and Delves exclude each other). |
| D13 | AC8.7 custom modes | Deferred to November, with the rule builder (M7). The engine reads `Focus.MODES` as data, so custom modes add entries there. | §12.1 lists "F8 six core focus modes (+ pause)" for October. |
| D14 | §6.2 `FISHING_SPELLS` "seeded with 131474", `GATHER_SPELLS` "seeded from the spike's log", §6.6 teleport allowlist (§13.2 item 3) | `Engine/FocusData.lua` holds only IDs known to be right: 131474 for Fishing (spike), and 2366, 2575 and 8613 (the long-standing Herb Gathering, Mining and Skinning). Exact English names back them up: `herb gathering`, `mining`, `skinning`, `fishing`. Teleports match by the name prefix `path of ` (every M+ dungeon teleport is "Path of …"). `/swagbag report` lists the last 5 spells cast before loot, so confirmed IDs can be added. | The spike's loot log was never saved, and no verified Midnight spell IDs exist. A wrong ID would flip modes. A name match is English-only, like the launch. |
| D15 | AC11.1 example "Low: Flask (0), Healing Potion (2/5)"; AC11.2 "the wizard seeds it per role" | The default watch list is three keyword entries: Flask 1, Potions 5, Food 5. Every part reads `Name (have/need)`, e.g. `Low: Flask (0/1), Food (2/5)`. Per-role seeding moves to the full wizard (November). Each trigger (key start, dungeon entry, teleport) has its own 60 s clock, so entering and then starting a key can warn twice. | One format is easier to read. Role detection is wizard work. The 60 s per trigger is spec §6.6 text. |
| D16 | §8.2 `SwagBagDB.consumableWatch` and `modes` at the top level | No schema bump. The watch list is `settings.consumables.watch` (nil means the default list). Modes are `settings.focus.on.<id>` and `settings.focus.sections.<id>` (comma-separated text, so a per-character override copies a value, not a shared table). | Week-3 D7 precedent: every migration keeps `settings`, defaults overlay it, and `Config.CharOverride` works on setting paths (AC15.1). |
| D17 | F15 "Settings"; §10.5 "`/swagbag` (opens settings)" | SwagBag's own window, with pages Bags, Bank & guild, Overlays, Focus modes, Consumables. No Blizzard Settings-panel entry. A bare `/swagbag` and `/swagbag settings [page]` open it. A choice with a chat command runs that command (`Slash.Run`), so both give the same result and the same answer. | The spec does not ask for a Blizzard panel entry, and the panel's API is not needed for anything here. |
| D18 | AC15.1 "focus modes … can be overridden per character via 'Use character-specific settings'" | One choice on the Focus modes page: `These focus settings are for: All characters / This character`. "This character" makes every `focus.*` path a character override. "All characters" removes them. Other pages are account-wide. | The spec names focus modes (and profession-dependent settings, which this week has none of beyond Gathering's automatic filter). |
| D19 | §8.2 `SwagBagCharDB.ui.wizardDone`; F7 four-step wizard | The quick setup is one screen: playstyles (M+, Raid, Gold-making, Casual, Collector, pick any) and slots per row. It shows once **per account** (`settings.setup.done`), 3 s after the first login with this build. Apply, Skip (AC7.2) and Esc (later) all answer. A preset only switches things on for the picked styles; Casual alone (without M+ or Raid) is the one that switches the warning and the upgrade track off. Gold moves Trade Goods and BoE gear up after Keystone & Crests; Collector moves Pets & Mounts & Toys up. | Settings are account-wide, so asking on every alt would repeat the same question. All modes are on by default (settled decision), so no preset turns a mode off. |
| D20 | §10.5 `tour` | `/swagbag tour` answers that the tour arrives in November. | P2; F7 tour is November (§12.1). |
| D21 | §6.6 "prints one line through `UIErrorsFrame` (on-screen) and chat" | `Adapter.ScreenMessage` (feature-detected `UIErrorsFrame`) plus chat. | Spec text. |

## Week-3 carry-overs (from `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md`)

| Ledger item | Where |
|---|---|
| Final: "held-retry rebuild every 300 ms (re-arm without rebuild while same button busy)" | Task 10 (`GroupView.RequestLayout`) |
| Final: "M8 tests for guild/bags toggles" (view toggles honour a failed `Set`) | Task 10 |
| Final: "drag onto guild section header swallows the following click" | Task 10 |
| Task 10 minor / final: "PLAYER_LOGOUT stores in one trapped handler — wrap each" | Task 10 (`Snapshots.lua`) |
| Brief: "Restack in the bags window redraws every cell" | Task 3 (`W.Restack` uses `renderMoved`) |
| Final: "xpcall traceback in ScanKind" | Not this week: `Inventory.lua` is not changed by week 4. Week 5 hardening. |
| Other deferred minors (re-hooking tabs Blizzard adds mid-visit, guild server refusals, caged pets in the guild bank, the shared bank-window shell W3-8, …) | Not this week: none touches code week 4 changes. Week 5 hardening, as the ledger says. |

---

## File structure (end of week 4)

New and changed files only. Everything else is as on `aa3fea1`.

```
SwagBag/Engine/Focus.lua               NEW  modes, triggers, merge/priority, collapsed view, peek/pin/close, pause, labels; /swagbag mode
SwagBag/Engine/FocusData.lua           NEW  fishing, gathering and teleport spell lists (IDs + English names)
SwagBag/Engine/Signals.lua             NEW  WoW events -> Focus signals through the Adapter; spells-before-loot log
SwagBag/Engine/Consumables.lua         NEW  watch list, counting, the three triggers, 60 s per trigger; /swagbag consumables
SwagBag/UI/SettingsWindow.lua          NEW  the settings frame, page registry, row renderer, status line; /swagbag, /swagbag settings
SwagBag/UI/SettingsPages.lua           NEW  pages Bags, Bank & guild, Overlays
SwagBag/UI/SettingsFocus.lua           NEW  page Focus modes (AC8.1-8.5, AC15.1)
SwagBag/UI/SettingsConsumables.lua     NEW  page Consumables (AC11.2)
SwagBag/UI/QuickSetup.lua              NEW  one-screen quick setup; /swagbag setup, /swagbag tour
SwagBag/UI/BagsWindow.lua              MOD  EffectiveCollapsed, incremental Restack, peek/pin, Pause button, mode in the title
SwagBag/UI/SectionHeaders.lua          MOD  right-click passes the mouse button to the owner
SwagBag/UI/GroupView.lua               MOD  held full layout re-arms without re-reading; no drop guard without onDrop
SwagBag/Engine/Snapshots.lua           MOD  each logout write in its own trap
SwagBag/Core/Adapter.lua               MOD  instance, challenge mode, delve, spell name, loot source, professions, ScreenMessage; checks
SwagBag/Core/Config.lua                MOD  focus.*, consumables.*, setup.done defaults
SwagBag/Core/Slash.lua                 MOD  Slash.Run; a bare /swagbag runs Slash.onEmpty
SwagBag/Core/Report.lua                MOD  Focus and Spells-before-loot lines
SwagBag/Core/Init.lua, SwagBag.toc, Locale/enUS.lua, .luacheckrc   MOD
spec/focus_spec.lua, signals_spec.lua, adapter_signals_spec.lua, consumables_spec.lua, settings_spec.lua,
spec/settings_focus_spec.lua, settings_consumables_spec.lua, quicksetup_spec.lua                         NEW
spec/mock_adapter.lua, bagswindow_sections_spec.lua, bankwindow_groups_spec.lua, groupview_spec.lua,
spec/guildbank_spec.lua, snapshots_spec.lua                                                               MOD
```

## Schedule (spec §12.2 week 4, Oct 22–28: "Modes switch correctly in real play")

The user plays keys every day, so the M+ mode and the warning come first.

| Day | Tasks | User in game? |
|---|---|---|
| 1 (Oct 22) | 1, 2, 3, 4 | **yes:** session FM1 (town, vendor, bank, peek, pin, pause, fishing, gathering; about 15 minutes) and, if you do delves or raids today, session DR1 (V7, raid; 5 minutes) |
| 2 (Oct 23) | 5 | **yes:** session K1 in a real key (V5, V11; no extra time beyond the key) |
| 3 (Oct 24) | 6, 7 | daily focus check (2 minutes) |
| 4 (Oct 25) | 8 | **yes:** session S1 (settings pages, 10 minutes) |
| 5 (Oct 26) | 9 | **yes:** session Q1 (quick setup, 3 minutes) |
| 6 (Oct 27) | 10 | **yes:** session W1 (guild header drag, logout snapshot; 3 minutes) |
| 7 (Oct 28) | fixes from the user's reports | **yes:** daily focus check; **Week 4 exit check** |

Cumulative `scripts/check.sh` test totals (from 718 on `aa3fea1`). Each was produced by replaying this file's blocks in order on a fresh clone of `aa3fea1`:
- T1 742 passed, 0 failed
- T2 766 passed, 0 failed
- T3 775 passed, 0 failed
- T4 783 passed, 0 failed
- T5 800 passed, 0 failed
- T6 814 passed, 0 failed
- T7 824 passed, 0 failed
- T8 832 passed, 0 failed
- T9 844 passed, 0 failed
- T10 849 passed, 0 failed

## How the TOC grows

`scripts/check.sh` prints `TOC OK (N files)`: 43 on `aa3fea1`, 44 after Task 1, 46 after Tasks 2–4, 47 after Task 5, 49 after Task 6, 50 after Task 7, 51 after Task 8 and 52 after Tasks 9–10. Final order of the changed sections:

```text
Engine/Prices.lua
Engine/OverlayData.lua
Engine/Focus.lua
Engine/FocusData.lua
Engine/Signals.lua
Engine/Consumables.lua

# Providers
Providers/Auctionator.lua

# UI
...
UI/Overlays.lua
UI/SettingsWindow.lua
UI/SettingsPages.lua
UI/SettingsFocus.lua
UI/SettingsConsumables.lua
UI/QuickSetup.lua
UI/DebugV1.lua
```

## How to read the code steps

- A **Create** step gives a complete new file.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point (it occurs exactly once) and its replacement. When a file has several edits in one task, they are numbered "(edit N of M)". Apply them in that order, top to bottom.
- No step replaces a whole existing file. Blocks begin and end on non-blank lines.
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks. Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists the critical tests and the code change (mutation) that must make each one fail. Every mutation was applied to the finished code of that task and the named test failed. A reviewer re-runs any of them with a one-line edit.

---
### Task 1: The focus engine: modes, merge and strict priority, the collapsed view, peek, pin and close, pause

Spec §6.1, §6.3, §6.4 and AC8.1–AC8.4: `Engine/Focus.lua` is pure Lua. It holds the six v1.0 modes as data (D12, D13). It turns signals into the active set, and the active set into the open sections, by merge (default) or strict priority. It also keeps this session's peeks, pins and closes. `Focus.CollapsedView(savedSet)` is what the bags window will hand to `Layout`. It returns the saved set itself when no mode applies, and otherwise a read-only lookup that never writes anything (D1, D2, D3). Settings get defaults under `settings.focus` (D16). Nothing calls this module yet; Task 2 feeds it and Task 3 draws it. The version goes to 0.4.0.

**Files:**
- Create: `SwagBag/Engine/Focus.lua`
- Modify: `SwagBag/Core/Config.lua` (focus defaults), `SwagBag/Locale/enUS.lua` (mode names), `SwagBag/Core/Init.lua` and `SwagBag/SwagBag.toc` (0.4.0, one file)
- Test: `spec/focus_spec.lua` (new)

**Interfaces:**
- Consumes (on `aa3fea1`): `SB.Config.Get/Set/IsCharOverride/Defaults`, `SB.Emit`, `SB.Print`, `SB.L`.
- Produces:
  - `SB.Focus.MODES` (ordered `{ id, class, name = <Locale key>, trigger(signals), expandAll(signals)? }`) and `SB.Focus.byId`;
  - `SB.Focus.signals` (table) and `Focus.SetSignal(name, value) -> changed`;
  - `Focus.Recompute(reason) -> changed` and `Focus.Refresh(reason)` (always emits);
  - `Focus.Active() -> { ids }`, `Focus.active` (the last computed list), `Focus.IsEnabled(id)`;
  - `Focus.Expanded() -> set | nil` and `Focus.Applies() -> bool`;
  - `Focus.CollapsedView(userSet) -> lookup` (`lookup[id] == true` means collapsed);
  - `Focus.HeaderClick(id, collapsedNow) -> "peek" | "close"`, `Focus.Pin(id) -> "pin" | "unpin"`, `Focus.OverrideOf(id) -> nil | "peek" | "pin" | "closed"`, `Focus.WindowClosed()`;
  - `Focus.Pause() / Resume() -> changed`, `Focus.IsPaused()`, `Focus.Label() -> text | nil`;
  - `Focus.Sections(id) -> { category ids }`, `Focus.SetEnabled(id, on)`, `Focus.SetSections(id, list)` and `Focus.ResetSections(id)` (each `-> bool`, false while read-only);
  - internal event `SB_FOCUS_CHANGED(reason)`, reason `"signal" | "pause" | "resume" | "settings"`;
  - settings `focus.auto`, `focus.resolve`, `focus.peek`, `focus.announce`, `focus.on.<id>` and `focus.sections.<id>`.

- [ ] **Step 1: Write the failing tests**

Create `spec/focus_spec.lua`:

```lua
-- Focus modes engine (spec 6): signals -> active modes -> open sections; merge and strict
-- priority; peek, pin and close; pause; labels; section sets from the settings.
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua",
	"SwagBag/Engine/Focus.lua",
}

local ORDER = { "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
	"c_leathercloth", "c_fish", "c_cooking", "c_tools", "c_junk", "c_other", "free" }

describe("Focus", function()
	local SB, F, events
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		F = SB.Focus
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason)
			events[#events + 1] = reason
		end)
	end)

	local function openIds()
		local view = F.CollapsedView({})
		local out = {}
		for _, id in ipairs(ORDER) do
			if view[id] ~= true then
				out[#out + 1] = id
			end
		end
		return out
	end

	it("no signal: no mode, nothing collapsed by Focus, the user's own set is used as it is", function()
		local user = { c_gear = true }
		assert.same({}, F.Active())
		assert.equal(user, F.CollapsedView(user))
		assert.is_nil(F.Label())
		assert.same({}, events)
	end)

	-- Mutation: return false from the mplus trigger's challengeMode branch.
	it("M+ (AC8.2): a running key opens Consumables, Keystone & Crests, Gear and New, nothing else", function()
		assert.truthy(F.SetSignal("challengeMode", true))
		assert.same({ "mplus" }, F.Active())
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear" }, openIds())
		assert.equal("M+", F.Label())
		assert.same({ "signal" }, events)
	end)

	it("M+ fallback (V5): a Mythic party dungeon with a keystone in the bags, before the key starts", function()
		F.SetSignal("instanceType", "party")
		F.SetSignal("mythic", true)
		assert.same({}, F.Active(), "no keystone yet")
		F.SetSignal("keystone", true)
		assert.same({ "mplus" }, F.Active())
		F.SetSignal("mythic", false)
		assert.same({}, F.Active(), "heroic dungeon")
	end)

	it("leaving restores the user's own state (AC8.2)", function()
		local user = { c_junk = true }
		F.SetSignal("challengeMode", true)
		F.SetSignal("challengeMode", false)
		assert.equal(user, F.CollapsedView(user))
		assert.same({ "signal", "signal" }, events)
	end)

	it("raid, delves and fishing open their own sets", function()
		F.SetSignal("instanceType", "raid")
		assert.same({ "new", "c_consumables", "c_gear" }, openIds())
		F.SetSignal("instanceType", "scenario")
		F.SetSignal("delve", true)
		assert.same({ "delves" }, F.Active())
		assert.same({ "new", "c_consumables", "c_gear" }, openIds())
		F.SetSignal("delve", false)
		F.SetSignal("fishing", true)
		assert.same({ "new", "c_fish", "c_cooking" }, openIds())
	end)

	-- Mutation: drop the professions filter in Focus.Sections.
	it("gathering opens only the materials of the character's gathering professions, plus Tools", function()
		F.SetSignal("gathering", true)
		assert.same({ "new", "c_herbs", "c_ore", "c_leathercloth", "c_tools" }, openIds(), "professions unknown")
		F.SetSignal("professions", { herb = true })
		F.Recompute()
		assert.same({ "new", "c_herbs", "c_tools" }, openIds())
	end)

	it("vendor and auction house open Junk, Trade Goods and BoE gear; the bank opens everything (spec 6.3)", function()
		F.SetSignal("merchantOpen", true)
		assert.same({ "new", "c_boe", "c_tradegoods", "c_junk" }, openIds())
		F.SetSignal("merchantOpen", false)
		F.SetSignal("auctionOpen", true)
		assert.equal("AH/Vendor/Bank", F.Label())
		F.SetSignal("auctionOpen", false)
		F.SetSignal("bankOpen", true)
		assert.same({ "market" }, F.Active())
		local user = { c_gear = true }
		assert.equal(user, F.CollapsedView(user), "at the bank the user's own state is shown")
		assert.equal("AH/Vendor/Bank", F.Label())
	end)

	-- Mutation: make deciding() always return the strongest mode (strict) even under merge.
	it("overlapping modes merge by default (AC8.4): the union is open and the title names both", function()
		F.SetSignal("fishing", true)
		F.SetSignal("merchantOpen", true)
		assert.same({ "new", "c_boe", "c_tradegoods", "c_fish", "c_cooking", "c_junk" }, openIds())
		assert.equal("Fishing + AH/Vendor/Bank", F.Label())
	end)

	-- Mutation: compare CLASS_RANK with < instead of >.
	it("strict priority (AC8.4) keeps only the strongest class: activity beats location", function()
		SB.Config.Set("focus.resolve", "priority")
		F.SetSignal("merchantOpen", true)
		F.SetSignal("fishing", true)
		assert.same({ "new", "c_fish", "c_cooking" }, openIds())
		assert.equal("Fishing", F.Label())
	end)

	it("strict priority within a class follows the mode order (M+ before Fishing)", function()
		SB.Config.Set("focus.resolve", "priority")
		F.SetSignal("fishing", true)
		F.SetSignal("challengeMode", true)
		assert.equal("M+", F.Label())
	end)

	it("merge: a bank visit during another mode opens everything (the bank expands all)", function()
		F.SetSignal("fishing", true)
		F.SetSignal("bankOpen", true)
		local user = {}
		assert.equal(user, F.CollapsedView(user))
	end)

	it("a disabled mode never triggers; switching modes off entirely stops all of them", function()
		assert.truthy(F.SetEnabled("fishing", false))
		F.SetSignal("fishing", true)
		assert.same({}, F.Active())
		F.SetSignal("challengeMode", true)
		assert.same({ "mplus" }, F.Active())
		SB.Config.Set("focus.auto", false)
		F.Refresh("settings")
		assert.same({}, F.Active())
		assert.is_nil(F.Label())
	end)

	-- Mutation: remove `Focus.overrides = {}` from Recompute.
	it("peek (AC8.3): a click on a collapsed header opens it; a change of mode ends the peek", function()
		F.SetSignal("challengeMode", true)
		assert.equal("peek", F.HeaderClick("c_junk", true))
		assert.equal("peek", F.OverrideOf("c_junk"))
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_junk" }, openIds())
		F.SetSignal("merchantOpen", true)
		assert.is_nil(F.OverrideOf("c_junk"))
	end)

	-- Mutation: clear pins in WindowClosed too.
	it("a peek ends when the bag closes; a pin stays until the mode changes", function()
		F.SetSignal("challengeMode", true)
		F.HeaderClick("c_junk", true)
		F.Pin("c_tools")
		F.WindowClosed()
		assert.is_nil(F.OverrideOf("c_junk"))
		assert.equal("pin", F.OverrideOf("c_tools"))
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_tools" }, openIds())
		F.SetSignal("challengeMode", false)
		F.SetSignal("challengeMode", true)
		assert.is_nil(F.OverrideOf("c_tools"))
	end)

	it("with \"Keep open until mode changes\" a click pins at once", function()
		SB.Config.Set("focus.peek", "keep")
		F.SetSignal("challengeMode", true)
		F.HeaderClick("c_junk", true)
		F.WindowClosed()
		assert.equal("pin", F.OverrideOf("c_junk"))
	end)

	it("a click on an open section closes it for this bag opening; a second right-click unpins", function()
		F.SetSignal("challengeMode", true)
		assert.equal("close", F.HeaderClick("c_gear", false))
		assert.same({ "new", "c_keystone", "c_consumables" }, openIds())
		assert.equal("pin", F.Pin("c_gear"))
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear" }, openIds())
		assert.equal("unpin", F.Pin("c_gear"))
		assert.is_nil(F.OverrideOf("c_gear"))
	end)

	it("New is never collapsed by a mode, even when it is missing from the section set", function()
		SB.Config.Set("focus.sections.mplus", "c_gear")
		F.SetSignal("challengeMode", true)
		assert.is_nil(F.CollapsedView({})["new"])
	end)

	-- Mutation: make Pause leave Focus.paused false.
	it("pause (spec 6.1): no mode applies, the title says Paused, resume brings the mode back", function()
		F.SetSignal("challengeMode", true)
		F.HeaderClick("c_junk", true)
		assert.truthy(F.Pause())
		assert.falsy(F.Pause(), "already paused")
		local user = {}
		assert.equal(user, F.CollapsedView(user))
		assert.equal("Paused", F.Label())
		assert.is_nil(F.OverrideOf("c_junk"), "a pause ends peeks")
		F.SetSignal("fishing", true) -- signals still follow the world while paused
		assert.truthy(F.Resume())
		assert.equal("M+ + Fishing", F.Label())
		assert.same({ "signal", "pause", "signal", "resume" }, events)
	end)

	it("announce (off by default) prints one line per change of the active set", function()
		F.SetSignal("challengeMode", true)
		assert.same({}, SB.Adapter.Lines())
		SB.Config.Set("focus.announce", true)
		F.SetSignal("challengeMode", false)
		F.SetSignal("fishing", true)
		assert.same({ "Focus mode: no mode", "Focus mode: Fishing" }, SB.Adapter.Lines())
	end)

	it("a signal that does not change the active set changes nothing and emits nothing", function()
		F.SetSignal("instanceType", "party")
		assert.same({}, events)
		F.SetSignal("instanceType", "party")
		assert.falsy(F.SetSignal("instanceType", "party"))
	end)

	it("section sets are stored as text; reset removes the stored set so a new default applies", function()
		assert.truthy(F.SetSections("mplus", { "c_consumables", "c_junk" }))
		assert.equal("c_consumables,c_junk", SB.Config.db.settings.focus.sections.mplus)
		assert.same({ "c_consumables", "c_junk" }, F.Sections("mplus"))
		assert.same({ "settings" }, events)
		assert.truthy(F.ResetSections("mplus"))
		assert.is_nil(SB.Config.db.settings.focus.sections.mplus)
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
	end)

	-- Mutation: in ResetSections, always Set(path, nil) (that removes the character override).
	it("with a character override, reset puts the default into the override and keeps it", function()
		SB.Config.CharOverride("focus.sections.mplus", true)
		F.SetSections("mplus", { "c_junk" })
		assert.truthy(F.ResetSections("mplus"))
		assert.truthy(SB.Config.IsCharOverride("focus.sections.mplus"))
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
	end)

	it("read-only settings: SetEnabled, SetSections and ResetSections refuse and change nothing", function()
		SB.Config.readOnly = true
		assert.falsy(F.SetEnabled("mplus", false))
		assert.falsy(F.SetSections("mplus", { "c_junk" }))
		assert.falsy(F.ResetSections("mplus"))
		assert.truthy(F.IsEnabled("mplus"))
		assert.same({}, events)
	end)

	it("Recompute for 30 modes stays well under 0.5 ms per call (spec 6.5)", function()
		for i = 1, 24 do
			F.MODES[#F.MODES + 1] = { id = "x" .. i, class = "activity", name = "MODE_RAID", trigger = function(s)
				return s.fishing == true and s.never == true
			end }
			F.byId["x" .. i] = F.MODES[#F.MODES]
		end
		local t0 = os.clock()
		for i = 1, 1000 do
			F.SetSignal("fishing", i % 2 == 0)
		end
		local perCall = (os.clock() - t0) * 1000 / 1000
		assert.truthy(perCall < 0.5, ("%.3f ms per Recompute"):format(perCall))
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/focus_spec.lua`
Expected: `0 passed, 24 failed`, each with `cannot open SwagBag/Engine/Focus.lua: No such file or directory`.

Critical tests and their mutations (each makes the named test fail):

| Test | Mutation (in `SwagBag/Engine/Focus.lua`) |
|---|---|
| "M+ (AC8.2): a running key opens Consumables, …" | the M+ trigger returns `false or (…)` instead of `s.challengeMode == true or (…)` |
| "gathering opens only the materials of the character's gathering professions, plus Tools" | `if not need or Focus.signals.professions[need] then` → `if true then` |
| "overlapping modes merge by default (AC8.4)…" | in `deciding()`, `if cfg("focus.resolve") ~= "priority" or #active <= 1 then` → `if #active <= 1 then` |
| "strict priority (AC8.4) keeps only the strongest class…" | `CLASS_RANK[…] > CLASS_RANK[…]` → `<` |
| "peek (AC8.3): … a change of mode ends the peek" | in `Recompute`, drop `Focus.overrides = {}` from the assignment |
| "a peek ends when the bag closes; a pin stays until the mode changes" | in `WindowClosed`, `if o ~= "pin" then` → `if true then` |
| "pause (spec 6.1): …" | in `Pause`, `Focus.paused, Focus.overrides = true, {}` → `false, {}` |
| "with a character override, reset puts the default into the override and keeps it" | in `ResetSections`, `if SB.Config.IsCharOverride(path) then` → `if false then` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Config.lua`, find:

```lua
			usePawn = false },
	},
```

and replace it with:

```lua
			usePawn = false },
		-- Focus modes (spec 6, Engine/Focus.lua). auto: modes switch by themselves (AC8.1);
		-- resolve: "merge" (open the union, default) | "priority" (combat > activity > location,
		-- AC8.4); peek: a click on a collapsed header opens it until the bag closes ("peek") or
		-- until the mode changes ("keep", AC8.3); announce: one chat line per mode change (spec
		-- 6.4, default off); on.<mode>: each built-in mode (all on); sections.<mode>: the sections
		-- the mode opens, comma-separated category ids (New is always open).
		focus = { auto = true, resolve = "merge", peek = "peek", announce = false,
			on = { mplus = true, raid = true, delves = true, gathering = true, fishing = true, market = true },
			sections = {
				mplus = "c_consumables,c_keystone,c_gear",
				raid = "c_consumables,c_gear",
				delves = "c_consumables,c_gear",
				gathering = "c_herbs,c_ore,c_leathercloth,c_tools",
				fishing = "c_fish,c_cooking",
				market = "c_junk,c_tradegoods,c_boe",
			} },
	},
```

In `SwagBag/Core/Init.lua`, find:

```lua
SB.name = ADDON
SB.VERSION = "0.3.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "
```

and replace it with:

```lua
SB.name = ADDON
SB.VERSION = "0.4.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "
```

Create `SwagBag/Engine/Focus.lua`:

```lua
-- SwagBag focus modes (spec section 6). Pure Lua: signals in, "which sections are open" out.
-- No frames and no WoW calls; Engine/Signals.lua feeds the signals, the bags window asks.
--   Focus.SetSignal(name, value) -> changed      one fact about the world (spec 6.2)
--   Focus.Recompute(reason) -> changed           re-evaluate the triggers (signals call it)
--   Focus.Refresh(reason)                        a focus setting changed: always tell the windows
--   Focus.Active() -> { ids }                    enabled modes whose trigger is true (MODES order)
--   Focus.Expanded() -> set | nil                the open sections, or nil when no mode applies
--                                                (none active, paused, switched off, or a mode
--                                                that expands everything: the bank)
--   Focus.CollapsedView(userSet) -> lookup       collapsed[id] for Layout.Position / Apply:
--                                                userSet itself when no mode applies
--   Focus.HeaderClick(id, collapsedNow) -> "peek" | "close"   a header click while a mode applies
--   Focus.Pin(id) -> "pin" | "unpin"             right-click: keep a section open until the
--                                                mode changes (spec 6.1 pin)
--   Focus.OverrideOf(id) -> nil | "peek" | "pin" | "closed"
--   Focus.WindowClosed()                         peeks and closes end; pins stay (spec 6.1)
--   Focus.Pause() / Focus.Resume() -> changed; Focus.IsPaused()   for this session only
--   Focus.Label() -> text | nil                  "M+", "M+ + Fishing", "Paused" (title, AC8.5)
--   Focus.Sections(id) -> { category ids }       a mode's section set (settings or default)
--   Focus.SetSections(id, list) -> bool, Focus.ResetSections(id) -> bool, Focus.SetEnabled(id, on) -> bool
-- The windows hear SB_FOCUS_CHANGED(reason) whenever what is open may have changed: the active set
-- changed ("signal"), "pause", "resume", or a focus setting ("settings"). A change of the active
-- set ends every peek and pin (spec 6.4). New is never collapsed by a mode.
-- Settings (Core/Config.lua): focus.auto, focus.resolve ("merge" | "priority"), focus.peek
-- ("peek" | "keep"), focus.announce, focus.on.<id>, focus.sections.<id> (comma-separated ids).
local _, SB = ...

local Focus = { signals = {}, overrides = {}, paused = false, key = "", active = {} }
SB.Focus = Focus

local CLASS_RANK = { combat = 3, activity = 2, location = 1 }

-- The six v1.0 modes (spec 6.3, AC8.1), in "user order" for strict priority within a class.
Focus.MODES = {
	{ id = "mplus", class = "activity", name = "MODE_MPLUS", trigger = function(s)
		return s.challengeMode == true or (s.instanceType == "party" and s.keystone == true and s.mythic == true)
	end },
	{ id = "raid", class = "activity", name = "MODE_RAID", trigger = function(s)
		return s.instanceType == "raid"
	end },
	{ id = "delves", class = "activity", name = "MODE_DELVES", trigger = function(s)
		return s.delve == true
	end },
	{ id = "gathering", class = "activity", name = "MODE_GATHERING", trigger = function(s)
		return s.gathering == true
	end },
	{ id = "fishing", class = "activity", name = "MODE_FISHING", trigger = function(s)
		return s.fishing == true
	end },
	{ id = "market", class = "location", name = "MODE_MARKET", trigger = function(s)
		return s.auctionOpen == true or s.merchantOpen == true or s.bankOpen == true
	end, expandAll = function(s)
		return s.bankOpen == true -- at the bank everything stays open (spec 6.3)
	end },
}
local byId = {}
for _, m in ipairs(Focus.MODES) do
	byId[m.id] = m
end
Focus.byId = byId

-- Gathering opens only the materials of the gathering professions the character has
-- (spec 6.2 "professions"); without that signal it opens all three.
local PROFESSION_OF = { c_herbs = "herb", c_ore = "ore", c_leathercloth = "skin" }

local function cfg(path)
	return SB.Config.Get(path)
end

local function split(text)
	local out = {}
	if type(text) == "string" then
		for id in text:gmatch("[^,%s]+") do
			out[#out + 1] = id
		end
	end
	return out
end

function Focus.IsEnabled(id)
	return cfg("focus.on." .. id) ~= false
end

function Focus.Sections(id)
	local list = split(cfg("focus.sections." .. id))
	if id ~= "gathering" or type(Focus.signals.professions) ~= "table" then
		return list
	end
	local out = {}
	for _, sid in ipairs(list) do
		local need = PROFESSION_OF[sid]
		if not need or Focus.signals.professions[need] then
			out[#out + 1] = sid
		end
	end
	return out
end

function Focus.Active()
	local out = {}
	if cfg("focus.auto") == false then
		return out
	end
	for _, m in ipairs(Focus.MODES) do
		if Focus.IsEnabled(m.id) and m.trigger(Focus.signals) then
			out[#out + 1] = m.id
		end
	end
	return out
end

-- The modes that decide what is open: all active ones (merge), or the strongest (priority).
local function deciding()
	local active = Focus.active
	if cfg("focus.resolve") ~= "priority" or #active <= 1 then
		return active
	end
	local best
	for _, id in ipairs(active) do
		if not best or CLASS_RANK[byId[id].class] > CLASS_RANK[byId[best].class] then
			best = id
		end
	end
	return { best }
end

function Focus.Expanded()
	if Focus.paused or #Focus.active == 0 then
		return nil
	end
	local set = { new = true }
	for _, id in ipairs(deciding()) do
		local m = byId[id]
		if m.expandAll and m.expandAll(Focus.signals) then
			return nil
		end
		for _, sid in ipairs(Focus.Sections(id)) do
			set[sid] = true
		end
	end
	return set
end

-- What Layout sees as collapsed. The user's own set while no mode applies; otherwise the mode's
-- set with this session's peeks, pins and closes on top. The user's saved set is never written.
function Focus.CollapsedView(userSet)
	local open = Focus.Expanded()
	if not open then
		return userSet
	end
	local overrides = Focus.overrides
	return setmetatable({}, { __index = function(_, id)
		local o = overrides[id]
		if o == "peek" or o == "pin" then
			return nil
		elseif o == "closed" then
			return true
		end
		return (id ~= "new" and not open[id]) or nil
	end })
end

function Focus.Applies()
	return Focus.Expanded() ~= nil
end

function Focus.OverrideOf(id)
	return Focus.overrides[id]
end

function Focus.HeaderClick(id, collapsedNow)
	if collapsedNow then
		Focus.overrides[id] = cfg("focus.peek") == "keep" and "pin" or "peek"
		return "peek"
	end
	Focus.overrides[id] = "closed"
	return "close"
end

function Focus.Pin(id)
	if Focus.overrides[id] == "pin" then
		Focus.overrides[id] = nil
		return "unpin"
	end
	Focus.overrides[id] = "pin"
	return "pin"
end

function Focus.WindowClosed()
	for id, o in pairs(Focus.overrides) do
		if o ~= "pin" then
			Focus.overrides[id] = nil
		end
	end
end

local function label(ids)
	local L, names = SB.L, {}
	for _, id in ipairs(ids) do
		names[#names + 1] = L[byId[id].name]
	end
	return table.concat(names, " + ")
end

function Focus.Label()
	if Focus.paused then
		return SB.L.FOCUS_PAUSED
	end
	if #Focus.active == 0 then
		return nil
	end
	return label(deciding())
end

local function emit(reason)
	SB.Emit("SB_FOCUS_CHANGED", reason)
end

-- Re-evaluate the triggers. A different active set ends every peek and pin and tells the windows.
function Focus.Recompute(reason)
	local active = Focus.Active()
	local key = table.concat(active, ",")
	if key == Focus.key then
		return false
	end
	Focus.key, Focus.active, Focus.overrides = key, active, {}
	if cfg("focus.announce") and not Focus.paused then
		SB.Print(SB.L.FOCUS_ANNOUNCE:format(#active > 0 and label(deciding()) or SB.L.FOCUS_NONE))
	end
	emit(reason or "signal")
	return true
end

function Focus.Refresh(reason)
	if not Focus.Recompute(reason or "settings") then
		emit(reason or "settings")
	end
end

function Focus.SetSignal(name, value)
	if Focus.signals[name] == value then
		return false
	end
	Focus.signals[name] = value
	return Focus.Recompute("signal")
end

function Focus.IsPaused()
	return Focus.paused
end

function Focus.Pause()
	if Focus.paused then
		return false
	end
	Focus.paused, Focus.overrides = true, {}
	emit("pause")
	return true
end

function Focus.Resume()
	if not Focus.paused then
		return false
	end
	Focus.paused, Focus.overrides = false, {}
	emit("resume")
	return true
end

-- Settings writes. Each returns false (and changes nothing) while the settings are read-only.
function Focus.SetEnabled(id, on)
	if not byId[id] or not SB.Config.Set("focus.on." .. id, on and true or false) then
		return false
	end
	Focus.Refresh("settings")
	return true
end

function Focus.SetSections(id, list)
	if not byId[id] or not SB.Config.Set("focus.sections." .. id, table.concat(list, ",")) then
		return false
	end
	Focus.Refresh("settings")
	return true
end

-- Back to the built-in set. Account-wide: the stored value is removed, so a new default in an
-- update applies (spec 8.5). With a character override the override takes the default.
function Focus.ResetSections(id)
	local path = "focus.sections." .. id
	local value = nil
	if SB.Config.IsCharOverride(path) then
		value = SB.Config.Defaults.settings.focus.sections[id]
	end
	if not byId[id] or not SB.Config.Set(path, value) then
		return false
	end
	Focus.Refresh("settings")
	return true
end
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.FREE_MODE_ALL = "Every free slot is shown again."

-- In-game check V1 (optional)
```

and replace it with:

```lua
L.FREE_MODE_ALL = "Every free slot is shown again."

-- Focus modes (spec 6)
L.MODE_MPLUS = "M+"
L.MODE_RAID = "Raid"
L.MODE_DELVES = "Delves"
L.MODE_GATHERING = "Gathering"
L.MODE_FISHING = "Fishing"
L.MODE_MARKET = "AH/Vendor/Bank"
L.FOCUS_PAUSED = "Paused"
L.FOCUS_NONE = "no mode"
L.FOCUS_ANNOUNCE = "Focus mode: %s"

-- In-game check V1 (optional)
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
## Author: lonezebra
## Version: 0.3.0
## SavedVariables: SwagBagDB
```

and replace it with:

```text
## Author: lonezebra
## Version: 0.4.0
## SavedVariables: SwagBagDB
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
Engine/Prices.lua
Engine/OverlayData.lua

# Providers
```

and replace it with:

```text
Engine/Prices.lua
Engine/OverlayData.lua
Engine/Focus.lua

# Providers
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/focus_spec.lua`
Expected: `24 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (44 files)`, `742 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add "spec/focus_spec.lua" "SwagBag/Core/Config.lua" "SwagBag/Core/Init.lua" "SwagBag/Engine/Focus.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 1: focus engine (modes, merge/priority, collapsed view, peek/pin/close, pause), v0.4.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 2: Signals through the Adapter (V5–V8): zone, M+, delve, fishing, gathering allowlist, professions, vendor, auction house and bank

Spec §6.2 and §13.2 items 2–3: every signal is read through new Adapter functions. Each is feature-detected with a stated fallback:

| Signal | Adapter read | Fallback when the client lacks it |
|---|---|---|
| `instanceType`, `mythic` | `A.InstanceInfo()` (`IsInInstance`, `GetInstanceInfo` difficulty 8 or 23) | nil type (open world), not mythic |
| `challengeMode` | `A.ChallengeModeActive()`: the challenge-mode API, else the ChallengeMode add-on restriction | nil: the M+ trigger then uses its fallback, a Mythic party dungeon with a keystone in the bags (V5) |
| `delve` | `A.InDelve(info)`: the party API, else a scenario at difficulty 208 (V7) | the difficulty table |
| `keystone` | `Signals.HasKeystone()` from `Inventory` (a `keystone:` link in the bags) | none needed |
| `fishing` | `UNIT_SPELLCAST_CHANNEL_START` (player) spell in `FocusData.fishing`, or `A.IsFishingLoot()` (V6) | ID list, then English name; loot only |
| `gathering` | `LOOT_READY` within 6 s of a player `UNIT_SPELLCAST_SUCCEEDED` in `FocusData.gathering`, source `A.LootSourceType()` GameObject or Creature (V8, AC8.6) | without a loot source, the spell alone decides |
| `professions` | `A.GatheringProfessions()` (skill lines 182, 186, 393) | nil: Gathering opens all three materials sections |
| `merchantOpen`, `auctionOpen`, `bankOpen` | `MERCHANT_*`, `AUCTION_HOUSE_*`, `BANKFRAME_*` | none needed |

Every handler waits for `SB_LOGIN` (settings are loaded then) and traps as `"bags"`. Fishing decays 90 s after the last signal and gathering 120 s after the last gather (`SB.Debounce`, no polling). The report gains two lines for checks V5–V8: what the signals said, and the last 5 spells cast before loot (spec §13.1). Every new client function is an optional check in `A.CHECKS`.

**Files:**
- Create: `SwagBag/Engine/FocusData.lua`, `SwagBag/Engine/Signals.lua`
- Modify: `SwagBag/Core/Adapter.lua` (signal reads and checks), `SwagBag/Core/Report.lua`, `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`, `.luacheckrc`
- Test: `spec/mock_adapter.lua`, `spec/signals_spec.lua` (new), `spec/adapter_signals_spec.lua` (new)

**Interfaces:**
- Consumes: Task 1's `Focus.SetSignal/Recompute/signals/Label/Expanded`. On `aa3fea1`: `SB.Inventory.Iterate/OnChanged`, `SB.Debounce`, `SB.ErrorTrap.Guard`.
- Produces:
  - Adapter reads `A.InstanceInfo() -> { instanceType, difficultyID }`, `A.ChallengeModeActive() -> true | false | nil` and `A.InDelve(info) -> bool`;
  - `A.SpellName(spellID) -> lower-case name | nil`, `A.IsFishingLoot() -> bool`, `A.LootSourceType() -> "GameObject" | "Creature" | … | nil` and `A.GatheringProfessions() -> { herb, ore, skin } | nil`;
  - Adapter tables `A.MYTHIC_DUNGEON_DIFFICULTY` and `A.DELVE_DIFFICULTY`;
  - `SB.FocusData.fishing/gathering/teleports` (`{ ids, names, prefixes }`) and `FocusData.Matches(list, spellID) -> bool`;
  - `SB.Signals.ready`, `Signals.ReadZone()`, `Signals.HasKeystone()`, `Signals.Fishing()`, `Signals.Gathering()` and `Signals.recent` (last 5 spell IDs);
  - mock adapter fields `m.instance`, `m.challengeMode`, `m.delve`, `m.spellNames`, `m.fishingLoot`, `m.lootSource` and `m.professions`;
  - report lines `Focus: …` and `Spells before loot (last 5): …`.

- [ ] **Step 1: Write the failing tests**

Create `spec/adapter_signals_spec.lua`:

```lua
-- luacheck: globals IsInInstance GetInstanceInfo C_ChallengeMode C_RestrictedActions Enum C_PartyInfo C_Spell
-- luacheck: globals IsFishingLoot GetLootSourceInfo GetProfessions GetProfessionInfo
-- The REAL Adapter.lua (not the mock): the focus-mode signal reads (week 4, spec 6.2). Each one
-- is feature-detected; a missing or failing client function gives the stated fallback.
describe("Adapter focus signals (real adapter, stubbed globals)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		IsInInstance, GetInstanceInfo, C_ChallengeMode, C_RestrictedActions, Enum = nil, nil, nil, nil, nil
		C_PartyInfo, C_Spell, IsFishingLoot, GetLootSourceInfo, GetProfessions, GetProfessionInfo =
			nil, nil, nil, nil, nil, nil
	end)

	it("InstanceInfo: type and difficulty inside an instance; nothing outside one or without the API", function()
		assert.same({}, A.InstanceInfo())
		IsInInstance = function() return false, "none" end
		assert.same({}, A.InstanceInfo())
		IsInInstance = function() return true, "party" end
		GetInstanceInfo = function() return "Ara-Kara", "party", 8, "Mythic Keystone" end
		assert.same({ instanceType = "party", difficultyID = 8 }, A.InstanceInfo())
		GetInstanceInfo = function() error("broken") end
		assert.same({ instanceType = "party" }, A.InstanceInfo())
	end)

	it("ChallengeModeActive: the challenge-mode API, else the restriction, else nil", function()
		assert.is_nil(A.ChallengeModeActive())
		Enum = { AddOnRestrictionType = { ChallengeMode = 2 } }
		C_RestrictedActions = { IsAddOnRestrictionActive = function(kind) return kind == 2 end }
		assert.equal(true, A.ChallengeModeActive())
		C_ChallengeMode = { IsChallengeModeActive = function() return false end }
		assert.equal(false, A.ChallengeModeActive())
		C_ChallengeMode = { IsChallengeModeActive = function() error("broken") end }
		assert.equal(true, A.ChallengeModeActive(), "a failing API falls back to the restriction")
	end)

	it("InDelve: the party API when present, else a scenario at the delve difficulty", function()
		assert.equal(false, A.InDelve({ instanceType = "scenario", difficultyID = 1 }))
		assert.equal(true, A.InDelve({ instanceType = "scenario", difficultyID = 208 }))
		C_PartyInfo = { IsDelveInProgress = function() return false end }
		assert.equal(false, A.InDelve({ instanceType = "scenario", difficultyID = 208 }))
	end)

	it("SpellName is lower case, nil without the API or for a bad ID", function()
		assert.is_nil(A.SpellName(131474))
		C_Spell = { GetSpellName = function(id) return id == 131474 and "Fishing" or nil end }
		assert.equal("fishing", A.SpellName(131474))
		assert.is_nil(A.SpellName(1))
		assert.is_nil(A.SpellName("131474"))
	end)

	it("IsFishingLoot and LootSourceType", function()
		assert.equal(false, A.IsFishingLoot())
		IsFishingLoot = function() return true end
		assert.equal(true, A.IsFishingLoot())
		assert.is_nil(A.LootSourceType())
		GetLootSourceInfo = function() return "GameObject-0-1-2-3-4-5" end
		assert.equal("GameObject", A.LootSourceType())
		GetLootSourceInfo = function() error("no loot") end
		assert.is_nil(A.LootSourceType())
	end)

	it("GatheringProfessions reads the two primary professions' skill lines; nil without the API", function()
		assert.is_nil(A.GatheringProfessions())
		GetProfessions = function() return 3, 7, nil, 9 end
		GetProfessionInfo = function(index)
			local lines = { [3] = 182, [7] = 171 }
			return "Name", 0, 1, 100, 1, 0, lines[index]
		end
		assert.same({ herb = true }, A.GatheringProfessions())
		GetProfessions = function() return nil, 7 end
		assert.same({}, A.GatheringProfessions())
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
	end

	M.AddContainers(m)
```

and replace it with:

```lua
	end

	-- Focus signals (week 4): m.instance = { instanceType, difficultyID }; m.challengeMode true |
	-- false | nil (no API); m.delve; m.spellNames[spellID] = lower-case name; m.fishingLoot;
	-- m.lootSource ("GameObject", "Creature", ... or nil); m.professions ({ herb, ore, skin } or nil).
	m.instance, m.challengeMode, m.delve, m.spellNames = {}, nil, false, {}
	m.fishingLoot, m.lootSource, m.professions = false, nil, nil
	function m.InstanceInfo()
		return { instanceType = m.instance.instanceType, difficultyID = m.instance.difficultyID }
	end
	function m.ChallengeModeActive()
		return m.challengeMode
	end
	function m.InDelve()
		return m.delve == true
	end
	function m.SpellName(spellID)
		return m.spellNames[spellID]
	end
	function m.IsFishingLoot()
		return m.fishingLoot == true
	end
	function m.LootSourceType()
		return m.lootSource
	end
	function m.GatheringProfessions()
		return m.professions
	end

	M.AddContainers(m)
```

Create `spec/signals_spec.lua`:

```lua
-- Signals (spec 6.2): WoW events -> Focus signals, through the mock Adapter. Checks V5-V8 in
-- unit form: M+ (and its fallback), raid, delve, fishing (channel and loot), gathering (the
-- allowlist; chests and archaeology never), professions, vendor / auction house / bank.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Focus.lua",
	"SwagBag/Engine/FocusData.lua", "SwagBag/Engine/Signals.lua",
}

describe("Signals", function()
	local SB, A, F, S
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- slot 5 holds a keystone
		F, S = SB.Focus, SB.Signals
		SB.Emit("SB_LOGIN")
	end)

	local function fire(event, ...)
		SB.eventFrame:Fire(event, ...)
	end

	local function bagUpdate()
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function enter(instanceType, difficultyID)
		A.instance = { instanceType = instanceType, difficultyID = difficultyID }
		fire("PLAYER_ENTERING_WORLD")
	end

	it("registers every event it listens to", function()
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "SCENARIO_UPDATE", "CHALLENGE_MODE_START",
			"CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "ADDON_RESTRICTION_STATE_CHANGED",
			"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
			"LOOT_READY", "SKILL_LINES_CHANGED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "AUCTION_HOUSE_SHOW",
			"AUCTION_HOUSE_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED" }) do
			assert.truthy(SB.eventFrame.events[e], e)
		end
	end)

	it("nothing fires before login: settings are not loaded yet", function()
		local SB2 = Loader.New(FILES)
		SB2.Config.Get = function() error("Config read before login") end
		SB2.Adapter.challengeMode = true
		SB2.eventFrame:Fire("PLAYER_ENTERING_WORLD")
		assert.is_nil(SB2.Focus.signals.challengeMode)
		assert.same({}, SB2.ErrorTrap.Recent())
	end)

	-- Mutation: drop `s.challengeMode = A.ChallengeModeActive() == true` from ReadZone.
	it("V5: the key starts (CHALLENGE_MODE_START) -> M+; the key ends and the player leaves -> no mode", function()
		enter("party", nil) -- difficulty unreadable: only the challenge-mode signal can say M+
		A.challengeMode = true
		fire("CHALLENGE_MODE_START")
		assert.same({ "mplus" }, F.Active())
		A.challengeMode = false
		A.Clear(0, 5) -- keystone handed in
		bagUpdate()
		enter(nil, nil)
		assert.same({}, F.Active())
	end)

	-- Mutation: make HasKeystone always return false.
	it("V5 fallback: a Mythic party dungeon with a keystone in the bags is M+ before the key starts", function()
		A.challengeMode = nil -- the client cannot tell
		enter("party", 23)
		assert.same({ "mplus" }, F.Active())
		enter("party", 2) -- heroic
		assert.same({}, F.Active())
	end)

	it("the keystone signal follows the bags while in a party dungeon", function()
		A.Clear(0, 5)
		bagUpdate()
		enter("party", 23)
		assert.same({}, F.Active())
		A.Put(0, 5, Fixtures.KEYSTONE, 1, { link = "|Hkeystone:180653:503:12|h[Keystone]|h" })
		bagUpdate()
		assert.same({ "mplus" }, F.Active())
	end)

	it("raid and delve (V7) come from the zone", function()
		enter("raid", 16)
		assert.same({ "raid" }, F.Active())
		A.delve = true
		enter("scenario", 208)
		assert.same({ "delves" }, F.Active())
	end)

	-- Mutation: compare `unit == "target"` in the channel handler.
	it("V6: a fishing channel by the player turns Fishing on; it decays 90 s after the last cast", function()
		A.spellNames[131474] = "fishing"
		fire("UNIT_SPELLCAST_CHANNEL_START", "party1", "guid", 131474)
		assert.same({}, F.Active(), "another player's cast")
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
		assert.same({ "fishing" }, F.Active())
		A.Advance(60)
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
		A.Advance(89)
		assert.same({ "fishing" }, F.Active(), "still within 90 s of the last cast")
		A.Advance(2)
		assert.same({}, F.Active())
	end)

	it("V6 backups: a fishing spell found by name, and fishing loot without any cast", function()
		A.spellNames[999001] = "fishing"
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 999001)
		assert.same({ "fishing" }, F.Active())
		A.Advance(91)
		A.fishingLoot = true
		fire("LOOT_READY")
		assert.same({ "fishing" }, F.Active())
	end)

	-- Mutation: drop the `A.Now() - at > Sig.GATHER_WINDOW` test.
	it("V8: loot from a node within 6 s of Herb Gathering turns Gathering on; it decays after 120 s", function()
		A.lootSource = "GameObject"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366)
		A.Advance(2)
		fire("LOOT_READY")
		assert.same({ "gathering" }, F.Active())
		A.Advance(121)
		assert.same({}, F.Active())
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366)
		A.Advance(7)
		fire("LOOT_READY")
		assert.same({}, F.Active(), "loot more than 6 s after the cast")
	end)

	-- Mutation: let any spell name match (return true at the end of FocusData.Matches).
	it("AC8.6: opening a chest or digging (archaeology) never turns Gathering on", function()
		A.lootSource = "GameObject"
		A.spellNames[3365] = "opening"
		A.spellNames[80451] = "survey"
		A.spellNames[73979] = "digging"
		for _, spell in ipairs({ 3365, 80451, 73979 }) do
			fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", spell)
			fire("LOOT_READY")
		end
		assert.same({}, F.Active())
	end)

	it("a gathering spell of a later expansion is found by its name; skinning loots a creature", function()
		A.spellNames[423395] = "herb gathering"
		A.lootSource = "GameObject"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 423395)
		fire("LOOT_READY")
		assert.same({ "gathering" }, F.Active())
		A.Advance(121)
		A.spellNames[440977] = "skinning"
		A.lootSource = "Creature"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 440977)
		fire("LOOT_READY")
		assert.same({ "gathering" }, F.Active())
	end)

	it("loot from a player's corpse or an item after a gathering spell is not gathering", function()
		A.lootSource = "Player"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2575)
		fire("LOOT_READY")
		assert.same({}, F.Active())
	end)

	it("the report keeps the last 5 spells cast before loot", function()
		for _, spell in ipairs({ 1, 2, 3, 4, 5, 6 }) do
			fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", spell)
			fire("LOOT_READY")
		end
		assert.same({ 2, 3, 4, 5, 6 }, S.recent)
	end)

	it("Gathering opens only the materials of the professions read at login and on SKILL_LINES_CHANGED", function()
		A.professions = { ore = true }
		fire("SKILL_LINES_CHANGED")
		assert.same({ "c_ore", "c_tools" }, F.Sections("gathering"))
	end)

	it("vendor, auction house and bank open and close the AH/Vendor/Bank mode", function()
		fire("MERCHANT_SHOW")
		assert.same({ "market" }, F.Active())
		fire("MERCHANT_CLOSED")
		fire("AUCTION_HOUSE_SHOW")
		assert.same({ "market" }, F.Active())
		fire("AUCTION_HOUSE_CLOSED")
		fire("BANKFRAME_OPENED")
		assert.truthy(F.signals.bankOpen)
		fire("BANKFRAME_CLOSED")
		assert.same({}, F.Active())
	end)

	it("an error in a signal handler is trapped with the bags window's label", function()
		A.InstanceInfo = function() error("zone broke") end
		fire("ZONE_CHANGED_NEW_AREA")
		local e = SB.ErrorTrap.Recent()[1]
		assert.equal("event:ZONE_CHANGED_NEW_AREA", e.label)
		assert.equal("bags", e.window)
	end)

	it("a handler costs well under 0.1 ms on average (spec 6.5)", function()
		A.lootSource = "GameObject"
		local t0 = os.clock()
		for i = 1, 2000 do
			fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366 + (i % 2))
			fire("LOOT_READY")
		end
		local avg = (os.clock() - t0) * 1000 / 4000
		assert.truthy(avg < 0.1, ("%.4f ms per handler"):format(avg))
	end)
end)

describe("Report focus lines", function()
	it("names the mode, the resolve setting, the signals and the spells cast before loot", function()
		local SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
			"SwagBag/Core/Config.lua", "SwagBag/Core/Slash.lua", "SwagBag/Core/Checks.lua", "SwagBag/Core/Blocked.lua",
			"SwagBag/Core/Report.lua",
			"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Focus.lua",
			"SwagBag/Engine/FocusData.lua", "SwagBag/Engine/Signals.lua" })
		local A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		SB.Emit("SB_LOGIN")
		A.instance = { instanceType = "party", difficultyID = 8 }
		A.challengeMode = true
		SB.eventFrame:Fire("CHALLENGE_MODE_START")
		SB.eventFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 3365)
		SB.eventFrame:Fire("LOOT_READY")
		local text = SB.Report.Build()
		assert.truthy(text:find("Focus: M+ (merge); zone party, collapsing yes; M+ yes, keystone yes, delve no, fishing no, "
			.. "gathering no", 1, true), text)
		assert.truthy(text:find("Spells before loot (last 5): 3365", 1, true), text)
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/signals_spec.lua spec/adapter_signals_spec.lua`
Expected: `0 passed, 24 failed`. The signals tests fail with `cannot open SwagBag/Engine/FocusData.lua: No such file or directory`; the real-adapter tests fail because the new Adapter functions are missing (`attempt to call field 'InstanceInfo' (a nil value)` and similar).

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "V5: the key starts (CHALLENGE_MODE_START) -> M+; …" | `Signals.lua`: delete the line `s.challengeMode = A.ChallengeModeActive() == true` |
| "V5 fallback: a Mythic party dungeon with a keystone in the bags is M+ before the key starts" | `Signals.lua`: `HasKeystone` returns `false` where it returns `true` |
| "V6: a fishing channel by the player turns Fishing on; …" | `Signals.lua`: `unit == "player"` → `unit == "target"` in the channel handler |
| "V8: loot from a node within 6 s of Herb Gathering …" | `Signals.lua`: `if not spell or A.Now() - at > Sig.GATHER_WINDOW then` → `if not spell then` |
| "AC8.6: opening a chest or digging (archaeology) never turns Gathering on" | `FocusData.lua`: the last `return false` of `Matches` → `return true` |
| "loot from a player's corpse or an item after a gathering spell is not gathering" | `Signals.lua`: `if (source == nil or source == "GameObject" or source == "Creature")` → `if (true)` |
| "nothing fires before login: settings are not loaded yet" | `Signals.lua`: `if Sig.ready then` → `if true then` |
| "InstanceInfo: type and difficulty inside an instance; …" | `Adapter.lua`: `type(difficultyID) == "number"` → `== "string"` |

- [ ] **Step 3: Write the implementation**

In `.luacheckrc`, find:

```lua
	"C_ChallengeMode", "C_PlayerInfo", "GetInventoryItemLink",
}
```

and replace it with:

```lua
	"C_ChallengeMode", "C_PlayerInfo", "GetInventoryItemLink",
	"C_RestrictedActions", "C_PartyInfo", "C_Spell",
}
```

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- Focus-mode signals (week 4, spec 6.2). Every read is feature-detected: a missing function
-- gives the fallback named next to it, never an error.
---------------------------------------------------------------------------
-- Difficulty IDs (12.1): 8 Mythic Keystone and 23 Mythic dungeon; 208 Delves.
A.MYTHIC_DUNGEON_DIFFICULTY = { [8] = true, [23] = true }
A.DELVE_DIFFICULTY = { [208] = true }

-- { instanceType = "party" | "raid" | "pvp" | "arena" | "scenario" | nil, difficultyID = n | nil }.
-- Outside an instance (or without IsInInstance) both are nil.
function A.InstanceInfo()
	local out = {}
	local inInstance, info = _G.IsInInstance, _G.GetInstanceInfo
	if type(inInstance) ~= "function" then
		return out
	end
	local ok, inside, kind = pcall(inInstance)
	if not ok or not inside or type(kind) ~= "string" or isSecret(kind) or kind == "none" then
		return out
	end
	out.instanceType = kind
	if type(info) == "function" then
		local okI, _, _, difficultyID = pcall(info)
		if okI and type(difficultyID) == "number" and not isSecret(difficultyID) then
			out.difficultyID = difficultyID
		end
	end
	return out
end

-- true / false: a Mythic+ key is running. Read from the challenge-mode API, else from the
-- client's ChallengeMode add-on restriction. nil when neither exists: the M+ mode then uses its
-- fallback, a Mythic party dungeon with a keystone in the bags (check V5).
function A.ChallengeModeActive()
	if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
		local ok, v = pcall(C_ChallengeMode.IsChallengeModeActive)
		if ok and not isSecret(v) then
			return v == true
		end
	end
	local R, E = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
	if R and R.IsAddOnRestrictionActive and E and E.ChallengeMode ~= nil then
		local ok, v = pcall(R.IsAddOnRestrictionActive, E.ChallengeMode)
		if ok and not isSecret(v) then
			return v == true
		end
	end
	return nil
end

-- true inside a delve: the party API when the client has it, else a scenario at the delve
-- difficulty (check V7). info: an InstanceInfo() result (read again when nil).
function A.InDelve(info)
	if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
		local ok, v = pcall(C_PartyInfo.IsDelveInProgress)
		if ok and not isSecret(v) then
			return v == true
		end
	end
	info = info or A.InstanceInfo()
	return info.instanceType == "scenario" and A.DELVE_DIFFICULTY[info.difficultyID] == true
end

-- The lower-case name of a spell (name matching backs up the spell-ID lists), or nil.
function A.SpellName(spellID)
	if type(spellID) ~= "number" or isSecret(spellID) or not (C_Spell and C_Spell.GetSpellName) then
		return nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, spellID)
	if ok and type(name) == "string" and not isSecret(name) then
		return name:lower()
	end
	return nil
end

-- true while the open loot window is fishing loot; false otherwise or without the function.
function A.IsFishingLoot()
	local fn = _G.IsFishingLoot
	if type(fn) ~= "function" then
		return false
	end
	local ok, v = pcall(fn)
	return ok and v == true
end

-- The GUID type of the first loot slot's source ("GameObject" for a node, "Creature" for
-- skinning), or nil when the client cannot tell (the gathering signal then trusts the spell).
function A.LootSourceType()
	local fn = _G.GetLootSourceInfo
	if type(fn) ~= "function" then
		return nil
	end
	local ok, guid = pcall(fn, 1)
	if not ok or type(guid) ~= "string" or isSecret(guid) then
		return nil
	end
	return guid:match("^(%a+)%-")
end

-- The character's gathering professions: { herb = true, ore = true, skin = true } (those it
-- has), or nil when the client cannot tell (Gathering then opens all three materials sections).
-- Skill lines: 182 Herbalism, 186 Mining, 393 Skinning.
local GATHER_SKILL_LINES = { [182] = "herb", [186] = "ore", [393] = "skin" }
function A.GatheringProfessions()
	local list, info = _G.GetProfessions, _G.GetProfessionInfo
	if type(list) ~= "function" or type(info) ~= "function" then
		return nil
	end
	local ok, first, second = pcall(list)
	if not ok then
		return nil
	end
	local out = {}
	for _, index in pairs({ first, second }) do
		local okI, _, _, _, _, _, _, skillLine = pcall(info, index)
		if okI and GATHER_SKILL_LINES[skillLine] then
			out[GATHER_SKILL_LINES[skillLine]] = true
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "Enum.PlayerInteractionType.GuildBanker", window = "bank", required = false },
}
```

and replace it with:

```lua
	{ path = "Enum.PlayerInteractionType.GuildBanker", window = "bank", required = false },
	{ path = "IsInInstance", window = "bags", required = false },
	{ path = "GetInstanceInfo", window = "bags", required = false },
	{ path = "C_PartyInfo.IsDelveInProgress", window = "bags", required = false },
	{ path = "C_Spell.GetSpellName", window = "bags", required = false },
	{ path = "IsFishingLoot", window = "bags", required = false },
	{ path = "GetLootSourceInfo", window = "bags", required = false },
	{ path = "GetProfessions", window = "bags", required = false },
	{ path = "GetProfessionInfo", window = "bags", required = false },
}
```

In `SwagBag/Core/Report.lua`, find:

```lua
	end
	local guild = SB.GuildBankWindow
```

and replace it with:

```lua
	end
	local F, S = SB.Focus, SB.Signals
	if F and S and SB.Config.db then -- checks V5-V8: what the signals said, and the spells before loot
		local s = F.signals
		local function yes(v)
			return v and L.REPORT_YES or L.REPORT_NO
		end
		lines[#lines + 1] = L.REPORT_FOCUS:format(F.Label() or L.FOCUS_NONE, tostring(SB.Config.Get("focus.resolve")),
			tostring(s.instanceType or L.REPORT_NONE), tostring(F.Expanded() and L.REPORT_YES or L.REPORT_NO),
			yes(s.challengeMode), yes(s.keystone), yes(s.delve), yes(s.fishing), yes(s.gathering))
		local spells = {}
		for i, id in ipairs(S.recent) do
			spells[i] = tostring(id)
		end
		lines[#lines + 1] = L.REPORT_SPELLS:format(#spells > 0 and table.concat(spells, ", ") or L.REPORT_NONE)
	end
	local guild = SB.GuildBankWindow
```

Create `SwagBag/Engine/FocusData.lua`:

```lua
-- SwagBag focus-mode spell data (spec 6.2, 6.6, 13.2 item 3). Pure data, updated with patches.
-- A spell matches a list when its ID is in `ids`, or its lower-case name (Adapter.SpellName) is
-- one of `names` or starts with one of `prefixes`. Name matching is English (the client
-- language at launch) and backs up the IDs until in-game checks confirm them.
--   fishing    the Fishing channel (check V6). 131474 was seen in the 12.1 spike.
--   gathering  herb, ore and skin gathering (check V8). The IDs are the long-standing base
--              spells; each expansion adds its own, so names back them up. Chests ("Opening")
--              and archaeology ("Survey", "Digging") are deliberately not listed (AC8.6).
--   teleports  Mythic+ dungeon teleports (check V11): all are named "Path of ...".
-- /swagbag report lists the last spells cast before loot, so Claude can add confirmed IDs.
local _, SB = ...

local FD = {
	fishing = { ids = { [131474] = true }, names = { "fishing" }, prefixes = {} },
	gathering = { ids = { [2366] = true, [2575] = true, [8613] = true },
		names = { "herb gathering", "mining", "skinning" }, prefixes = {} },
	teleports = { ids = {}, names = {}, prefixes = { "path of " } },
}
SB.FocusData = FD

-- True when spellID belongs to list (one of the tables above).
function FD.Matches(list, spellID)
	if type(spellID) ~= "number" then
		return false
	end
	if list.ids[spellID] then
		return true
	end
	local name = SB.Adapter.SpellName(spellID)
	if not name then
		return false
	end
	for _, n in ipairs(list.names) do
		if name == n then
			return true
		end
	end
	for _, p in ipairs(list.prefixes) do
		if name:sub(1, #p) == p then
			return true
		end
	end
	return false
end
```

Create `SwagBag/Engine/Signals.lua`:

```lua
-- SwagBag signals (spec 6.2): WoW events -> Focus.SetSignal. Every read goes through the
-- Adapter, feature-detected (see Core/Adapter.lua for each fallback). Handlers are O(1) table
-- writes plus one Focus.Recompute; nothing polls and nothing runs while nothing happens (6.5).
--   zone        instanceType, mythic (Mythic dungeon difficulty), delve, challengeMode, keystone:
--               PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, SCENARIO_UPDATE, CHALLENGE_MODE_*,
--               ADDON_RESTRICTION_STATE_CHANGED (the ChallengeMode restriction; skipped by SB.On on
--               a client without the event)
--   keystone    a keystone in the bags; re-read on bag changes while in a party dungeon
--   fishing     the player channels a fishing spell, or fishing loot opens; off 90 s after the last
--   gathering   loot from a node or a skinned creature within 6 s of a gathering spell (the
--               allowlist in Engine/FocusData.lua); off 120 s after the last
--   professions the gathering professions (Gathering opens only theirs): login, SKILL_LINES_CHANGED
--   merchantOpen, auctionOpen, bankOpen   MERCHANT_*, AUCTION_HOUSE_*, BANKFRAME_*
-- Not wired in v1.0 (no v1.0 mode uses them, so they would only cost events): combat,
-- encounter, pvpMatch, mapRestricted, tradeSkillOpen.
-- Signals.recent: the last 5 spells cast before a loot window opened (for /swagbag report, so
-- missing gathering IDs can be added; spec 13.1).
local _, SB = ...

local Sig = { ready = false, lastSpell = nil, lastSpellAt = nil, recent = {}, RECENT = 5,
	GATHER_WINDOW = 6, FISHING_DECAY = 90, GATHER_DECAY = 120 }
SB.Signals = Sig

function Sig.HasKeystone()
	for _, _, s in SB.Inventory.Iterate("bags") do
		if s and type(s.link) == "string" and s.link:find("keystone:", 1, true) then
			return true
		end
	end
	return false
end

-- Read every place-bound signal, then decide once.
function Sig.ReadZone()
	local A, F = SB.Adapter, SB.Focus
	local info = A.InstanceInfo()
	local s = F.signals
	s.instanceType = info.instanceType
	s.mythic = A.MYTHIC_DUNGEON_DIFFICULTY[info.difficultyID] == true
	s.delve = A.InDelve(info)
	s.challengeMode = A.ChallengeModeActive() == true
	s.keystone = Sig.HasKeystone()
	return F.Recompute("signal")
end

-- A decaying signal: on now, off `decay` seconds after the last time it was seen.
local function pulse(name, decay)
	SB.Focus.SetSignal(name, true)
	SB.Debounce("signals." .. name, decay, function()
		SB.Focus.SetSignal(name, false)
	end, "bags")
end

function Sig.Fishing()
	pulse("fishing", Sig.FISHING_DECAY)
end

function Sig.Gathering()
	pulse("gathering", Sig.GATHER_DECAY)
end

local function remember(spellID)
	local list = Sig.recent
	list[#list + 1] = spellID
	while #list > Sig.RECENT do
		table.remove(list, 1)
	end
end

-- Every handler waits for SB_LOGIN: settings are not loaded before it.
local function on(event, fn)
	SB.On(event, function(...)
		if Sig.ready then
			fn(...)
		end
	end, "bags")
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "SCENARIO_UPDATE",
	"CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "ADDON_RESTRICTION_STATE_CHANGED" }) do
	on(event, function()
		Sig.ReadZone()
	end)
end

on("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
	if unit == "player" and SB.FocusData.Matches(SB.FocusData.fishing, spellID) then
		Sig.Fishing()
	end
end)

on("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
	if unit == "player" and type(spellID) == "number" and not SB.Adapter.IsSecret(spellID) then
		Sig.lastSpell, Sig.lastSpellAt = spellID, SB.Adapter.Now()
	end
end)

on("LOOT_READY", function()
	local A = SB.Adapter
	if A.IsFishingLoot() then
		Sig.Fishing()
		return
	end
	local spell, at = Sig.lastSpell, Sig.lastSpellAt
	if not spell or A.Now() - at > Sig.GATHER_WINDOW then
		return
	end
	remember(spell)
	local source = A.LootSourceType()
	if (source == nil or source == "GameObject" or source == "Creature")
		and SB.FocusData.Matches(SB.FocusData.gathering, spell) then
		Sig.Gathering()
	end
end)

local function readProfessions()
	SB.Focus.signals.professions = SB.Adapter.GatheringProfessions()
	SB.Focus.Recompute("signal")
end
on("SKILL_LINES_CHANGED", readProfessions)

local function flag(showEvent, closeEvent, name)
	on(showEvent, function()
		SB.Focus.SetSignal(name, true)
	end)
	on(closeEvent, function()
		SB.Focus.SetSignal(name, false)
	end)
end
flag("MERCHANT_SHOW", "MERCHANT_CLOSED", "merchantOpen")
flag("AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "auctionOpen")
flag("BANKFRAME_OPENED", "BANKFRAME_CLOSED", "bankOpen")

-- A keystone looted or handed in changes the M+ fallback, but only matters in a party dungeon.
SB.Inventory.OnChanged(SB.ErrorTrap.Guard("signals.inventory", function()
	if Sig.ready and SB.Focus.signals.instanceType == "party" then
		SB.Focus.SetSignal("keystone", Sig.HasKeystone())
	end
end, "bags"))

SB.On("SB_LOGIN", function()
	Sig.ready = true
	SB.Focus.signals.professions = SB.Adapter.GatheringProfessions()
	Sig.ReadZone()
end, "bags")
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.FOCUS_NONE = "no mode"
L.FOCUS_ANNOUNCE = "Focus mode: %s"

-- In-game check V1 (optional)
```

and replace it with:

```lua
L.FOCUS_NONE = "no mode"
L.FOCUS_ANNOUNCE = "Focus mode: %s"
L.REPORT_FOCUS = "Focus: %s (%s); zone %s, collapsing %s; M+ %s, keystone %s, delve %s, fishing %s, gathering %s"
L.REPORT_SPELLS = "Spells before loot (last 5): %s"
L.REPORT_YES = "yes"
L.REPORT_NO = "no"

-- In-game check V1 (optional)
```

In `SwagBag/SwagBag.toc`, find:

```text
Engine/OverlayData.lua
Engine/Focus.lua

# Providers
```

and replace it with:

```text
Engine/OverlayData.lua
Engine/Focus.lua
Engine/FocusData.lua
Engine/Signals.lua

# Providers
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/signals_spec.lua spec/adapter_signals_spec.lua`
Expected: `24 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (46 files)`, `766 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add "spec/adapter_signals_spec.lua" "spec/mock_adapter.lua" "spec/signals_spec.lua" ".luacheckrc" "SwagBag/Core/Adapter.lua" "SwagBag/Core/Report.lua" "SwagBag/Engine/FocusData.lua" "SwagBag/Engine/Signals.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 2: focus signals through the Adapter (zone, M+, delve, fishing, gathering allowlist, professions, vendor/AH/bank)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 3: The bags window follows the active mode (AC8.2, AC8.5 title, W10, P5)

The bags window hands `W.EffectiveCollapsed()` (Task 1's collapsed view over the saved set) to every `Layout.Position` and `Layout.Apply` call. On `SB_FOCUS_CHANGED` it refreshes the title at once and re-stacks through the existing guarded `W.Restack`. What happens to a switch in each state:
- **Mouse on a button that would move, or an item on the cursor:** `Restack` waits and retries every 300 ms, and the title changes at once. The retry draws whatever state is current when it runs, so a switch is never queued behind another.
- **In combat:** it applies at once (buttons are not protected).
- **Bag closed:** it is drawn on the next open (the full layout reads the same view).
- **Grid view:** only the title changes (D10).
- **Bank and guild bank windows:** never collapsed by a mode (D1). A test pins this.

Week-3 carry-over: `W.Restack` used to redraw every cell. It now uses `renderMoved(oldPos, pos)`, so a switch touches only the buttons that move or hide (spec §6.5 "Apply ≤ 5 ms"). The title reads `SwagBag — M+` or `SwagBag — M+ — ilvl 279.4` (AC8.5).

**Files:**
- Modify: `SwagBag/UI/BagsWindow.lua`, `SwagBag/Locale/enUS.lua`
- Test: `spec/bagswindow_sections_spec.lua` (a new `describe` before "BagsWindow load order"), `spec/bankwindow_groups_spec.lua`

**Interfaces:**
- Consumes: Task 1's `Focus.CollapsedView/Label/SetSignal` and `SB_FOCUS_CHANGED`. On `aa3fea1`: `W.Collapsed`, `renderMoved`, `anyBusy`, `sizeFrame`, `W.RefreshTitle`.
- Produces: `SB.BagsWindow.EffectiveCollapsed() -> lookup`. `W.Restack()` is now incremental. `W.Title()` includes the mode. Locale `BAGS_TITLE_MODE`, `BAGS_TITLE_MODE_ILVL`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua`, find:

```lua
end)

describe("BagsWindow load order", function()
```

and replace it with:

```lua
end)

describe("BagsWindow focus modes (spec 6)", function()
	local SB, A, W, B, F
	before_each(function()
		local files = { unpack(FILES) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- potion, flask, BoE ring, soulbound helm, keystone, junk
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W, F = SB.BagsWindow, SB.Focus
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

	local M_PLUS = { "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "+ BoE gear (1)",
		"+ Junk (1)", "+ Free (10)" }

	-- Mutation: return own (the saved set) from W.EffectiveCollapsed.
	it("a key starting while the bag is open collapses all but the M+ sections; leaving restores the user's own", function()
		W.Open()
		W.ToggleSection("c_junk") -- the user's own choice, saved
		F.SetSignal("challengeMode", true)
		assert.same(M_PLUS, headers())
		assert.falsy(B.Get(0, 3).shown, "BoE ring hidden")
		assert.truthy(B.Get(0, 5).shown, "keystone shown")
		assert.same({ c_junk = true }, SB.Config.UI().collapsed.bags, "a mode never writes the saved set")
		F.SetSignal("challengeMode", false)
		assert.same({ "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "- BoE gear (1)",
			"+ Junk (1)", "- Free (10)" }, headers())
	end)

	-- Mutation: Restack calls render() instead of renderMoved(oldPos, pos).
	it("a mode switch touches only the buttons that move or hide (Restack is incremental)", function()
		W.Open()
		local shows = {}
		for slot = 1, 16 do
			local b = B.Get(0, slot)
			local show = b.Show
			b.Show = function(self)
				shows[slot] = (shows[slot] or 0) + 1
				return show(self)
			end
		end
		F.SetSignal("challengeMode", true)
		assert.is_nil(shows[1], "the potion keeps its cell: no frame call")
		assert.is_nil(shows[5], "the keystone keeps its cell: no frame call")
	end)

	-- Mutation: delete the Layout.Moves hover check in W.Restack (anyBusy).
	it("W10 and P5: no button moves relative to its own header, and none moves under the mouse", function()
		W.Open()
		local junk = B.Get(0, 6)
		local offset = junk.y - header("c_junk").points[1][5]
		local gear = B.Get(0, 4)
		gear.mouseOver = true -- Gear does not move (everything above it stays open)
		F.SetSignal("merchantOpen", true) -- opens BoE gear, Trade Goods, Junk: Gear and Consumables collapse
		local ring = B.Get(0, 3)
		assert.equal("SwagBag — AH/Vendor/Bank", W.frame.title.text, "the title changes at once")
		assert.truthy(gear.shown, "held: the hovered helm is still shown")
		A.Advance(0.3)
		assert.truthy(gear.shown, "still held while the mouse stays")
		gear.mouseOver = false
		A.Advance(0.3)
		assert.falsy(gear.shown)
		assert.truthy(ring.shown)
		assert.equal(offset, junk.y - header("c_junk").points[1][5], "Junk's button kept its offset to its header")
	end)

	it("an item on the cursor holds the switch; it applies once the item is put down", function()
		W.Open()
		A.cursor = { itemID = 1 }
		F.SetSignal("challengeMode", true)
		assert.truthy(B.Get(0, 6).shown)
		A.cursor = nil
		A.Advance(0.3)
		assert.falsy(B.Get(0, 6).shown)
	end)

	it("a switch in combat applies at once (moving buttons is legal in combat)", function()
		W.Open()
		A.combat = true
		F.SetSignal("challengeMode", true)
		assert.same(M_PLUS, headers())
	end)

	it("a switch while the bag is closed is applied on the next open", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		assert.same(M_PLUS, headers())
	end)

	it("in the grid view a switch changes only the title", function()
		SB.Config.Set("bags.view", "grid")
		W.Open()
		F.SetSignal("challengeMode", true)
		assert.equal("SwagBag — M+", W.frame.title.text)
		assert.truthy(B.Get(0, 6).shown)
	end)

	it("AC8.5: the title names the mode, before the item level", function()
		A.avgIlvl = 279.44
		F.SetSignal("fishing", true)
		W.Open()
		assert.equal("SwagBag — Fishing — ilvl 279.4", W.frame.title.text)
	end)

end)

describe("BagsWindow load order", function()
```

In `spec/bankwindow_groups_spec.lua`, find:

```lua
		assert.truthy(ms <= 80, ("first bank open took %.1f ms"):format(ms))
	end)
end)
```

and replace it with:

```lua
		assert.truthy(ms <= 80, ("first bank open took %.1f ms"):format(ms))
	end)

	-- Spec 6.3: at the bank everything stays open. The bank window follows only the user's own
	-- collapse state; no focus mode ever collapses it. Mutation: in GroupView's collapsedFor,
	-- return SB.Focus.CollapsedView(set) when SB.Focus exists.
	it("a focus mode never collapses the bank window's sections", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Focus.lua")
		SB.Focus.SetSignal("challengeMode", true)
		openBank()
		for _, text in ipairs(labels()) do
			assert.equal("-", text:sub(1, 1), text)
		end
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/bankwindow_groups_spec.lua`
Expected: `101 passed, 7 failed`. The failures are "a key starting while the bag is open …", "W10 and P5 …", "an item on the cursor holds the switch …", "a switch in combat applies at once …", "a switch while the bag is closed …", "in the grid view a switch changes only the title" and "AC8.5: the title names the mode, before the item level".

The other two new tests pass already. "a mode switch touches only the buttons that move or hide" passes because nothing switches yet; it fails under its mutation once the code is in. "a focus mode never collapses the bank window's sections" pins D1, which already holds.

Critical tests and their mutations (in `SwagBag/UI/BagsWindow.lua`):

| Test | Mutation |
|---|---|
| "a key starting while the bag is open collapses all but the M+ sections; leaving restores the user's own" | `W.EffectiveCollapsed` returns `own` |
| "a mode switch touches only the buttons that move or hide (Restack is incremental)" | in `W.Restack`, `renderMoved(oldPos, pos)` → `render()` |
| "W10 and P5: no button moves relative to its own header, and none moves under the mouse" | in `W.Restack`, `if anyBusy(SB.Layout.Moves(W.pos, pos)) then` → `if false then` |
| "a switch in combat applies at once …" (and three more) | in the `SB_FOCUS_CHANGED` handler, `if frame:IsShown() and W.state then` → `if false then` |
| "a focus mode never collapses the bank window's sections" (`bankwindow_groups_spec`) | `GroupView.lua`: `collapsedFor` returns `SB.Focus.CollapsedView(ui.collapsed[k])` when `SB.Focus` exists |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.FOCUS_ANNOUNCE = "Focus mode: %s"
L.REPORT_FOCUS = "Focus: %s (%s); zone %s, collapsing %s; M+ %s, keystone %s, delve %s, fishing %s, gathering %s"
```

and replace it with:

```lua
L.FOCUS_ANNOUNCE = "Focus mode: %s"
L.BAGS_TITLE_MODE = "SwagBag — %s"
L.BAGS_TITLE_MODE_ILVL = "SwagBag — %s — ilvl %.1f"
L.REPORT_FOCUS = "Focus: %s (%s); zone %s, collapsing %s; M+ %s, keystone %s, delve %s, fishing %s, gathering %s"
```

In `SwagBag/UI/BagsWindow.lua` (edit 1 of 6), find:

```lua
-- one decimal) while bags.showIlvl is on and the client answers; otherwise "SwagBag" (D18).
function W.Title()
	if SB.Config.Get("bags.showIlvl") then
		local ilvl = SB.Adapter.EquippedItemLevel()
		if ilvl then
			return L.BAGS_TITLE_ILVL:format(ilvl)
		end
	end
```

and replace it with:

```lua
-- one decimal) while bags.showIlvl is on and the client answers; otherwise "SwagBag" (D18).
-- While a focus mode is active (or modes are paused) its name comes first: "SwagBag — M+ —
-- ilvl 279.4", "SwagBag — Paused" (AC8.5, spec 6.1).
function W.Title()
	local mode = SB.Focus and SB.Focus.Label()
	local ilvl = SB.Config.Get("bags.showIlvl") and SB.Adapter.EquippedItemLevel() or nil
	if mode and ilvl then
		return L.BAGS_TITLE_MODE_ILVL:format(mode, ilvl)
	elseif mode then
		return L.BAGS_TITLE_MODE:format(mode)
	elseif ilvl then
		return L.BAGS_TITLE_ILVL:format(ilvl)
	end
```

In `SwagBag/UI/BagsWindow.lua` (edit 2 of 6), find:

```lua
	return ui.collapsed.bags
end
```

and replace it with:

```lua
	return ui.collapsed.bags
end

-- What the layout treats as collapsed: the saved set above, or while a focus mode applies the
-- mode's set with this session's peeks and pins (Engine/Focus.lua). The saved set is never
-- written by a mode, so leaving the mode shows the user's own state again (AC8.2).
function W.EffectiveCollapsed()
	local own = W.Collapsed()
	return SB.Focus and SB.Focus.CollapsedView(own) or own
end
```

In `SwagBag/UI/BagsWindow.lua` (edit 3 of 6), find:

```lua
			family = SB.Adapter.BagFamily })
	W.pos = SB.Layout.Position(W.state, positionOpts(), W.Collapsed())
	return render()
```

and replace it with:

```lua
			family = SB.Adapter.BagFamily })
	W.pos = SB.Layout.Position(W.state, positionOpts(), W.EffectiveCollapsed())
	return render()
```

In `SwagBag/UI/BagsWindow.lua` (edit 4 of 6), find:

```lua
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
	local width, height = render()
	sizeFrame(width, height, true)
```

and replace it with:

```lua
end

-- Collapse/expand re-stack (spec 6.4): same cells, new section offsets, so no button moves
-- relative to its own header. Only the buttons whose position changes are touched. It waits
-- while an item is on the cursor or a button that would move is under the mouse, and retries
-- every 300 ms. A focus-mode switch comes here too: whichever state is current when the retry
-- runs is the one drawn (a switch that waits is never queued behind another).
function W.Restack()
	if not W.state then
		return true
	end
	local pos = SB.Layout.Position(W.state, positionOpts(), W.EffectiveCollapsed())
	if anyBusy(SB.Layout.Moves(W.pos, pos)) then
		SB.Debounce("bags.restack", W.RETRY, W.Restack, "bags")
		return false
	end
	local oldPos = W.pos
	W.pos = pos
	local width, height = renderMoved(oldPos, pos)
	sizeFrame(width, height, true)
```

In `SwagBag/UI/BagsWindow.lua` (edit 5 of 6), find:

```lua
	local overflowBefore = newSec and newSec.overflow or 0
	local result = SB.Layout.Apply(st, changes, (busyCheck()), W.Collapsed())
	newSec = st.sections[SB.Layout.NEW]
	-- New's "+N more below" can change with no button moving, so the headers redraw then too.
	if #result.moved > 0 or (newSec and newSec.overflow or 0) ~= overflowBefore then
		result.rendered = true
		local oldPos = W.pos
		W.pos = SB.Layout.Position(st, positionOpts(), W.Collapsed())
		local width, height = renderMoved(oldPos, W.pos)
```

and replace it with:

```lua
	local overflowBefore = newSec and newSec.overflow or 0
	local result = SB.Layout.Apply(st, changes, (busyCheck()), W.EffectiveCollapsed())
	newSec = st.sections[SB.Layout.NEW]
	-- New's "+N more below" can change with no button moving, so the headers redraw then too.
	if #result.moved > 0 or (newSec and newSec.overflow or 0) ~= overflowBefore then
		result.rendered = true
		local oldPos = W.pos
		W.pos = SB.Layout.Position(st, positionOpts(), W.EffectiveCollapsed())
		local width, height = renderMoved(oldPos, W.pos)
```

In `SwagBag/UI/BagsWindow.lua` (edit 6 of 6), find:

```lua
end, "bags"))

-- /swagbag free tile|all (Core/Commands.lua): regroup now, or once the mouse leaves the items.
```

and replace it with:

```lua
end, "bags"))

-- A focus mode switched, or a focus setting changed (Engine/Focus.lua): the title follows at
-- once; the sections re-stack, held back while a button that would move is under the mouse or
-- an item is on the cursor. In the grid view there are no sections, so only the title changes.
-- A closed window picks the state up on its next open.
SB.On("SB_FOCUS_CHANGED", function()
	W.RefreshTitle()
	if frame:IsShown() and W.state then
		W.Restack()
	end
end, "bags")

-- /swagbag free tile|all (Core/Commands.lua): regroup now, or once the mouse leaves the items.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/bankwindow_groups_spec.lua`
Expected: `108 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (46 files)`, `775 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add "spec/bagswindow_sections_spec.lua" "spec/bankwindow_groups_spec.lua" "SwagBag/Locale/enUS.lua" "SwagBag/UI/BagsWindow.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 3: bags window follows the active focus mode (guarded incremental restack, mode in the title)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 4: Peek, pin and close on headers; the Pause button; `/swagbag mode` (AC8.3, spec 6.1, 10.5)

While a mode applies:
- a left-click on a collapsed header peeks it (until the bag closes; with "Keep open until the mode changes" it pins at once);
- a left-click on an open section closes it for this opening of the bag;
- a right-click pins (`(kept open)`) or unpins (D7).

The saved collapse set is never touched in a mode. Without a mode, both clicks collapse as before. Section headers now pass the mouse button to their owner. The bank and guild views ignore it, so a right-click there is a plain click. A header click with an item on the cursor is still a drop (AC4.3). Closing the bag ends peeks and closes (`Focus.WindowClosed`).

The title row gains `Pause` (between Sort and Reflow), which turns into `Resume` (D8). Both clicks print a chat line, and the title reads `SwagBag — Paused`. `/swagbag mode [pause|resume|list]` gives every form an answer.

**Files:**
- Modify: `SwagBag/UI/BagsWindow.lua`, `SwagBag/UI/SectionHeaders.lua`, `SwagBag/Engine/Focus.lua` (`/swagbag mode`, `Focus.ListLines`), `SwagBag/Locale/enUS.lua`
- Test: `spec/bagswindow_sections_spec.lua`

**Interfaces:**
- Consumes: Task 1's `Focus.Applies/HeaderClick/Pin/OverrideOf/WindowClosed/Pause/Resume/IsPaused/Sections`. Task 3's `W.EffectiveCollapsed`, `W.Restack`.
- Produces:
  - `SB.BagsWindow.PinSection(id)`, `W.TogglePause()`, `W.RefreshModeButton()` and `W.modeButton`;
  - `SectionHeaders` owner `onClick(sectionId, mouseButton)`;
  - `SB.Focus.ListLines() -> { lines }`;
  - slash command `mode`;
  - Locale `HEADER_PEEK`, `HEADER_PINNED`, `BTN_PAUSE`, `BTN_RESUME`, `MODE_*`, `HELP_MODE`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua` (edit 1 of 2), find:

```lua
		"+ Junk (1)", "+ Free (10)" }

	-- Mutation: return own (the saved set) from W.EffectiveCollapsed.
```

and replace it with:

```lua
		"+ Junk (1)", "+ Free (10)" }

	local function click(id, mouseButton)
		header(id).scripts.OnClick(header(id), mouseButton or "LeftButton")
	end


	-- Mutation: return own (the saved set) from W.EffectiveCollapsed.
```

In `spec/bagswindow_sections_spec.lua` (edit 2 of 2), find:

```lua
	end)

	it("AC8.5: the title names the mode, before the item level", function()
		A.avgIlvl = 279.44
		F.SetSignal("fishing", true)
		W.Open()
		assert.equal("SwagBag — Fishing — ilvl 279.4", W.frame.title.text)
	end)

end)
```

and replace it with:

```lua
	end)

	-- Mutation: make Focus.Pause leave the overrides and the paused flag alone (no-op).
	it("pausing while a switch waits under the mouse: the retry draws the paused state, never the mode", function()
		W.Open()
		local ring = B.Get(0, 3)
		ring.mouseOver = true
		F.SetSignal("challengeMode", true) -- would hide the ring: held
		assert.truthy(ring.shown)
		W.modeButton.scripts.OnClick(W.modeButton)
		ring.mouseOver = false
		A.Advance(0.3)
		assert.truthy(ring.shown, "paused: the user's own (all open) state")
		assert.equal("SwagBag — Paused", W.frame.title.text)
	end)

	-- Mutation: in W.ToggleSection, always toggle the saved set.
	it("AC8.3: a click on a collapsed header peeks it until the bag closes; the saved set is untouched", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		click("c_junk")
		assert.equal("- Junk (1)  (peek - right-click keeps it open)", header("c_junk").text.text)
		assert.truthy(B.Get(0, 6).shown)
		assert.same({}, SB.Config.UI().collapsed.bags)
		W.Close()
		W.Open()
		assert.equal("+ Junk (1)", header("c_junk").text.text)
	end)

	-- Mutation: in SectionHeaders' OnClick, drop the mouseButton argument.
	it("a right-click keeps a section open until the mode changes; it survives closing the bag", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		click("c_junk", "RightButton")
		assert.equal("- Junk (1)  (kept open)", header("c_junk").text.text)
		W.Close()
		W.Open()
		assert.equal("- Junk (1)  (kept open)", header("c_junk").text.text)
		F.SetSignal("merchantOpen", true)
		assert.equal("- Junk (1)", header("c_junk").text.text, "the mode set changed: the pin is gone")
	end)

	it("a click on an open section in a mode closes it for this opening only", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		click("c_gear")
		assert.equal("+ Gear (1)", header("c_gear").text.text)
		W.Close()
		W.Open()
		assert.equal("- Gear (1)", header("c_gear").text.text)
	end)

	it("without a mode a right-click collapses like a left-click", function()
		W.Open()
		click("c_gear", "RightButton")
		assert.equal("+ Gear (1)", header("c_gear").text.text)
		assert.same({ c_gear = true }, SB.Config.UI().collapsed.bags)
	end)

	it("an item on the cursor dropped on a header in a mode is still a drop (AC4.3), not a peek", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		click("c_junk")
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		assert.truthy(SB.Categories.Get("c_junk").itemList.include[Fixtures.FLASK])
	end)

	it("the Pause button: one click pauses (chat, title, button), the next resumes", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		assert.equal("Pause", W.modeButton.text)
		W.modeButton.scripts.OnClick(W.modeButton)
		assert.equal("Resume", W.modeButton.text)
		assert.equal("SwagBag — Paused", W.frame.title.text)
		assert.equal("- Junk (1)", header("c_junk").text.text)
		assert.equal(SB.L.MODE_PAUSED, A.Lines()[#A.Lines()])
		W.modeButton.scripts.OnClick(W.modeButton)
		assert.equal("Pause", W.modeButton.text)
		assert.equal("SwagBag — M+", W.frame.title.text)
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		assert.equal(SB.L.MODE_RESUMED, A.Lines()[#A.Lines()])
	end)


	it("AC8.5: the title names the mode, before the item level", function()
		A.avgIlvl = 279.44
		F.SetSignal("fishing", true)
		W.Open()
		assert.equal("SwagBag — Fishing — ilvl 279.4", W.frame.title.text)
	end)

	it("/swagbag mode answers every form (P2)", function()
		SB.Categories.Load()
		F.SetSignal("challengeMode", true)
		SB.Slash.Dispatch("mode")
		SB.Slash.Dispatch("mode pause")
		SB.Slash.Dispatch("mode pause")
		SB.Slash.Dispatch("mode resume")
		SB.Slash.Dispatch("mode resume")
		local lines = A.Lines()
		assert.same({ "Focus mode now: M+. Type /swagbag mode pause, resume or list.", SB.L.MODE_PAUSED,
			SB.L.MODE_ALREADY_PAUSED, SB.L.MODE_RESUMED, SB.L.MODE_NOT_PAUSED }, lines)
		SB.Slash.Dispatch("mode list")
		lines = A.Lines()
		assert.equal("M+: on, active now - opens Consumables, Keystone & Crests, Gear", lines[6])
		assert.equal("AH/Vendor/Bank: on - opens Junk, Trade Goods, BoE gear", lines[11])
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua`
Expected: `81 passed, 6 failed`. The failures are "pausing while a switch waits under the mouse …", "AC8.3: a click on a collapsed header peeks it …", "a right-click keeps a section open …", "a click on an open section in a mode closes it …", "the Pause button: …" and "/swagbag mode answers every form (P2)".

Two new tests pass already: "without a mode a right-click collapses like a left-click" and "an item on the cursor dropped on a header in a mode is still a drop (AC4.3), not a peek". Both pin behaviour this task must keep.

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "pausing while a switch waits under the mouse: the retry draws the paused state, never the mode" | `Focus.lua`: in `Pause`, delete `Focus.paused, Focus.overrides = true, {}` |
| "AC8.3: a click on a collapsed header peeks it until the bag closes; …" | `BagsWindow.lua`: in `W.ToggleSection`, `if F and F.Applies() then` → `if false then` |
| "a right-click keeps a section open until the mode changes; …" | `SectionHeaders.lua`: `o.onClick(self.sectionId, mouseButton)` → `o.onClick(self.sectionId)` |
| "AC8.3 …" (the reopen half) | `BagsWindow.lua`: comment out `SB.Focus.WindowClosed()` in the OnHide handler |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Engine/Focus.lua`, find:

```lua
	if not byId[id] or not SB.Config.Set(path, value) then
		return false
	end
	Focus.Refresh("settings")
	return true
end
```

and replace it with:

```lua
	if not byId[id] or not SB.Config.Set(path, value) then
		return false
	end
	Focus.Refresh("settings")
	return true
end

---------------------------------------------------------------------------
-- /swagbag mode [pause|resume|list] (spec 10.5). Every form answers (P2).
---------------------------------------------------------------------------
local function sectionNames(id)
	local names = {}
	for _, sid in ipairs(Focus.Sections(id)) do
		names[#names + 1] = SB.Categories and SB.Categories.Name(sid) or sid
	end
	return #names > 0 and table.concat(names, ", ") or SB.L.REPORT_NONE
end

function Focus.ListLines()
	local L, lines = SB.L, {}
	local active = {}
	for _, id in ipairs(Focus.active) do
		active[id] = true
	end
	for _, m in ipairs(Focus.MODES) do
		lines[#lines + 1] = L.MODE_LIST_LINE:format(L[m.name], Focus.IsEnabled(m.id) and L.OVERLAY_ON or L.OVERLAY_OFF,
			active[m.id] and L.MODE_ACTIVE or "", sectionNames(m.id))
	end
	return lines
end

SB.Slash.Register("mode", SB.L.HELP_MODE, function(arg)
	local L = SB.L
	arg = (arg or ""):lower()
	if arg == "pause" then
		return Focus.Pause() and L.MODE_PAUSED or L.MODE_ALREADY_PAUSED
	elseif arg == "resume" then
		return Focus.Resume() and L.MODE_RESUMED or L.MODE_NOT_PAUSED
	elseif arg == "list" then
		return Focus.ListLines()
	end
	return L.MODE_STATUS:format(Focus.Label() or L.FOCUS_NONE)
end, "bags")
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.BAGS_TITLE_MODE_ILVL = "SwagBag — %s — ilvl %.1f"
L.REPORT_FOCUS = "Focus: %s (%s); zone %s, collapsing %s; M+ %s, keystone %s, delve %s, fishing %s, gathering %s"
```

and replace it with:

```lua
L.BAGS_TITLE_MODE_ILVL = "SwagBag — %s — ilvl %.1f"
L.HEADER_PEEK = "  (peek - right-click keeps it open)"
L.HEADER_PINNED = "  (kept open)"
L.BTN_PAUSE = "Pause"
L.BTN_RESUME = "Resume"
L.MODE_PAUSED = "Focus modes are paused for this session: sections stay as you set them. Click Resume, or type /swagbag mode resume."
L.MODE_RESUMED = "Focus modes are back on: sections follow what you are doing again."
L.MODE_ALREADY_PAUSED = "Focus modes were already paused. Type /swagbag mode resume to switch them back on."
L.MODE_NOT_PAUSED = "Focus modes were not paused."
L.MODE_STATUS = "Focus mode now: %s. Type /swagbag mode pause, resume or list."
L.MODE_LIST_LINE = "%s: %s%s - opens %s"
L.MODE_ACTIVE = ", active now"
L.HELP_MODE = "mode [pause|resume|list]: pause or resume focus modes for this session, or list them"
L.REPORT_FOCUS = "Focus: %s (%s); zone %s, collapsing %s; M+ %s, keystone %s, delve %s, fishing %s, gathering %s"
```

In `SwagBag/UI/BagsWindow.lua` (edit 1 of 7), find:

```lua
	W.ClearDropGuard()
	SB.Buttons.ReleasePlaceholders(child)
```

and replace it with:

```lua
	W.ClearDropGuard()
	if SB.Focus then
		SB.Focus.WindowClosed() -- peeks end with the bag; pins stay until the mode changes (spec 6.1)
	end
	SB.Buttons.ReleasePlaceholders(child)
```

In `SwagBag/UI/BagsWindow.lua` (edit 2 of 7), find:

```lua
	local vendor, labels = H.IsVendor(), {}
	for i, h in ipairs(pos.headers) do
		labels[i] = H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow, totals[h.id], vendor)
	end
```

and replace it with:

```lua
	local vendor, labels = H.IsVendor(), {}
	local F = SB.Focus
	local focused = F and F.Applies()
	for i, h in ipairs(pos.headers) do
		labels[i] = H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow, totals[h.id], vendor)
		local o = focused and F.OverrideOf(h.id)
		if o == "peek" then
			labels[i] = labels[i] .. L.HEADER_PEEK
		elseif o == "pin" then
			labels[i] = labels[i] .. L.HEADER_PINNED
		end
	end
```

In `SwagBag/UI/BagsWindow.lua` (edit 3 of 7), find:

```lua
end

function W.ToggleSection(id)
	local set = W.Collapsed()
	set[id] = not set[id] or nil
	W.Restack()
```

and replace it with:

```lua
end

-- A header click. While a focus mode applies it peeks a collapsed section or closes an open one
-- for this opening of the bag (AC8.3); the saved collapse state is the user's own otherwise.
function W.ToggleSection(id)
	local F = SB.Focus
	if F and F.Applies() then
		F.HeaderClick(id, W.EffectiveCollapsed()[id] == true)
	else
		local set = W.Collapsed()
		set[id] = not set[id] or nil
	end
	W.Restack()
end

-- A right-click on a header while a focus mode applies: keep that section open until the mode
-- changes, or (a second time) give it back to the mode (spec 6.1 pin). Otherwise a plain click.
function W.PinSection(id)
	local F = SB.Focus
	if not (F and F.Applies()) then
		W.ToggleSection(id)
		return
	end
	F.Pin(id)
	W.Restack()
```

In `SwagBag/UI/BagsWindow.lua` (edit 4 of 7), find:

```lua
end

SB.SectionHeaders.onClick = function(id)
	if dropGuard == id then
		return
	end
	if SB.Adapter.CursorItem() then
		W.DropOnSection(id)
	else
```

and replace it with:

```lua
end

SB.SectionHeaders.onClick = function(id, mouseButton)
	if dropGuard == id then
		return
	end
	if SB.Adapter.CursorItem() then
		W.DropOnSection(id)
	elseif mouseButton == "RightButton" then
		W.PinSection(id)
	else
```

In `SwagBag/UI/BagsWindow.lua` (edit 5 of 7), find:

```lua
end, 60)
W.reflowButton:SetPoint("RIGHT", W.viewButton, "LEFT", -4, 0)
W.sortButton = titleButton(L.BTN_SORT, "bags.sortButton", function()
	W.Sort()
end, 52)
W.sortButton:SetPoint("RIGHT", W.reflowButton, "LEFT", -4, 0)

-- W3-26 parity: the title (and its flashes) ends left of the leftmost SHOWN title button, on one
```

and replace it with:

```lua
end, 60)
W.reflowButton:SetPoint("RIGHT", W.viewButton, "LEFT", -4, 0)
-- Pause / Resume (spec 6.1): one click stops focus modes for this session (until /reload) and
-- the title says "Paused"; the next click switches them back on. Chat confirms both (P2).
function W.TogglePause()
	local F = SB.Focus
	if F.IsPaused() then
		F.Resume()
		SB.Print(L.MODE_RESUMED)
	else
		F.Pause()
		SB.Print(L.MODE_PAUSED)
	end
end

function W.RefreshModeButton()
	W.modeButton:SetText(SB.Focus and SB.Focus.IsPaused() and L.BTN_RESUME or L.BTN_PAUSE)
end

W.modeButton = titleButton(L.BTN_PAUSE, "bags.modeButton", function()
	W.TogglePause()
end, 64)
W.modeButton:SetPoint("RIGHT", W.reflowButton, "LEFT", -4, 0)
W.sortButton = titleButton(L.BTN_SORT, "bags.sortButton", function()
	W.Sort()
end, 52)
W.sortButton:SetPoint("RIGHT", W.modeButton, "LEFT", -4, 0)

-- W3-26 parity: the title (and its flashes) ends left of the leftmost SHOWN title button, on one
```

In `SwagBag/UI/BagsWindow.lua` (edit 6 of 7), find:

```lua
	W.viewButton:SetText(W.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	W.RefreshTitle()
```

and replace it with:

```lua
	W.viewButton:SetText(W.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	W.RefreshModeButton()
	W.RefreshTitle()
```

In `SwagBag/UI/BagsWindow.lua` (edit 7 of 7), find:

```lua
end, "bags"))

-- A focus mode switched, or a focus setting changed (Engine/Focus.lua): the title follows at
-- once; the sections re-stack, held back while a button that would move is under the mouse or
-- an item is on the cursor. In the grid view there are no sections, so only the title changes.
-- A closed window picks the state up on its next open.
SB.On("SB_FOCUS_CHANGED", function()
	W.RefreshTitle()
	if frame:IsShown() and W.state then
```

and replace it with:

```lua
end, "bags"))

-- A focus mode switched, paused or resumed, or a focus setting changed (Engine/Focus.lua): the
-- title and the Pause button follow at once; the sections re-stack, held back while a button
-- that would move is under the mouse or an item is on the cursor. In the grid view there are no
-- sections, so only the title changes. A closed window picks the state up on its next open.
SB.On("SB_FOCUS_CHANGED", function()
	W.RefreshTitle()
	W.RefreshModeButton()
	if frame:IsShown() and W.state then
```

In `SwagBag/UI/SectionHeaders.lua` (edit 1 of 2), find:

```lua
-- combat is allowed (ruling P9). The window supplies the actions:
--   Headers.onClick(sectionId)  left-click (collapse/expand, or drop the cursor item)
--   Headers.onDrop(sectionId)   an item dragged onto the header (AC4.3)
```

and replace it with:

```lua
-- combat is allowed (ruling P9). The window supplies the actions:
--   Headers.onClick(sectionId, mouseButton)  left- or right-click ("LeftButton" | "RightButton"):
--                               collapse/expand, peek or pin (focus modes), or drop the cursor item
--   Headers.onDrop(sectionId)   an item dragged onto the header (AC4.3)
```

In `SwagBag/UI/SectionHeaders.lua` (edit 2 of 2), find:

```lua
	h:EnableMouse(true)
	h:RegisterForClicks("LeftButtonUp")
	h.bg = h:CreateTexture(nil, "BACKGROUND")
	h.bg:SetAllPoints(h)
	h.bg:SetColorTexture(1, 1, 1, 0.06)
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h.text:SetPoint("LEFT", h, "LEFT", 4, 0)
	h.text:SetJustifyH("LEFT")
	-- The ErrorTrap window is the owner's (W3-22, spec P6): an error in a bank header puts the
	-- bank window, not the bags window, in Safe Mode. No owner window: the bags window.
	h:SetScript("OnClick", function(self)
		local o = owners[self]
		SB.ErrorTrap.Run("header.click", o and o.window or "bags", function()
			o = o or H
			if o.onClick then
				o.onClick(self.sectionId)
			end
```

and replace it with:

```lua
	h:EnableMouse(true)
	h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	h.bg = h:CreateTexture(nil, "BACKGROUND")
	h.bg:SetAllPoints(h)
	h.bg:SetColorTexture(1, 1, 1, 0.06)
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h.text:SetPoint("LEFT", h, "LEFT", 4, 0)
	h.text:SetJustifyH("LEFT")
	-- The ErrorTrap window is the owner's (W3-22, spec P6): an error in a bank header puts the
	-- bank window, not the bags window, in Safe Mode. No owner window: the bags window.
	h:SetScript("OnClick", function(self, mouseButton)
		local o = owners[self]
		SB.ErrorTrap.Run("header.click", o and o.window or "bags", function()
			o = o or H
			if o.onClick then
				o.onClick(self.sectionId, mouseButton)
			end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua`
Expected: `87 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (46 files)`, `783 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: In-game sessions FM1 and DR1** (see "In-game sessions" at the end of this plan). They need Tasks 1–4 only. Session FM1 starts with a full game restart (Tasks 1 and 2 added files).

- [ ] **Step 7: Commit**

```bash
git add "spec/bagswindow_sections_spec.lua" "SwagBag/Engine/Focus.lua" "SwagBag/Locale/enUS.lua" "SwagBag/UI/BagsWindow.lua" "SwagBag/UI/SectionHeaders.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 4: peek, pin and close on headers, the Pause button, /swagbag mode

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 5: The low-consumables warning (spec 6.6, F11, check V11)

`Engine/Consumables.lua` counts each watched entry in the bags: a keyword entry by its query (`flask`, `potion`, `food`), an item entry by item ID, whole stacks. It checks on three triggers:
- `CHALLENGE_MODE_START`;
- `PLAYER_ENTERING_WORLD` into a party dungeon that is M+ or Mythic with a keystone in the bags;
- a player `UNIT_SPELLCAST_SUCCEEDED` whose spell is a dungeon teleport (`FocusData.teleports`, "Path of …").

It prints one line on screen (`Adapter.ScreenMessage`, feature-detected `UIErrorsFrame`) and in chat, e.g. `Low: Flask (0/1), Food (2/5)`. It prints nothing when everything is stocked. The limit is once per 60 s per trigger. The warning has its own switch (`consumables.warn`, default on) and is not affected by Pause (D8).

The watch list lives at `settings.consumables.watch`; nil means the default list (D15, D16). Every edit refuses while read-only, and damaged saved entries are skipped. `/swagbag consumables [check|on|off|reset]` answers every form; `check` ignores the rate limit and always answers.

**Files:**
- Create: `SwagBag/Engine/Consumables.lua`
- Modify: `SwagBag/Core/Adapter.lua` (`ScreenMessage`, check), `SwagBag/Core/Config.lua` (`consumables.warn`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/mock_adapter.lua` (`m.screen`), `spec/consumables_spec.lua` (new)

**Interfaces:**
- Consumes: Task 2's `SB.Signals.ready`, `SB.Focus.signals` (fresh on `PLAYER_ENTERING_WORLD`: `Signals.lua` loads first, so its handler runs first) and `SB.FocusData.Matches/teleports`. On `aa3fea1`: `SB.Inventory.Iterate("bags")`, `SB.Items.Describe`, `SB.Query.Compile/Eval`, `SB.Adapter.GetItemInfo`.
- Produces:
  - `SB.Consumables.DEFAULTS`, `List() -> { { query | itemID, threshold, name } }`, `Name(entry)`, `Count(entry) -> n`;
  - `Consumables.Low() -> { { name, have, need } }` and `Check(trigger, force) -> low | nil`;
  - edits `Add(itemID)`, `Remove(index)`, `SetThreshold(index, n)` and `Reset()`, each `-> ok, reason` (`"readonly" | "known" | "invalid"`);
  - `Consumables.Summary() -> text`;
  - `SB.Adapter.ScreenMessage(text)`;
  - setting `consumables.warn`, slash command `consumables`.

- [ ] **Step 1: Write the failing tests**

Create `spec/consumables_spec.lua`:

```lua
-- The low-consumables warning (spec 6.6, F11; check V11): counting, the three triggers, the
-- 60 s rate limit, the watch list (defaults, edits, read-only, damaged saved data), and
-- /swagbag consumables.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Crests.lua", "SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Focus.lua",
	"SwagBag/Engine/FocusData.lua", "SwagBag/Engine/Signals.lua", "SwagBag/Engine/Consumables.lua",
}

describe("Consumables", function()
	local SB, A, C
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- 5 healing potions, 2 flasks, no food; a keystone
		C = SB.Consumables
		SB.Emit("SB_LOGIN")
	end)

	local function fire(event, ...)
		SB.eventFrame:Fire(event, ...)
	end

	local function bagUpdate()
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	it("defaults: flask 1, potions 5, food 5, and the warning is on", function()
		assert.equal(true, SB.Config.Get("consumables.warn"))
		assert.equal("Flask 1, Potions 5, Food 5", C.Summary())
	end)

	-- Mutation: count 1 per slot instead of the stack size (`n = n + 1`).
	it("counts whole stacks in the bags by keyword and by item", function()
		assert.equal(2, C.Count({ query = "flask", threshold = 1 }))
		assert.equal(5, C.Count({ query = "potion", threshold = 5 }))
		assert.equal(5, C.Count({ itemID = Fixtures.HEALING_POTION, threshold = 5 }))
		assert.equal(0, C.Count({ query = "food", threshold = 5 }))
	end)

	-- Mutation: compare `have <= e.threshold` in Low.
	it("V11: a key starting with too little food prints one line on screen and in chat", function()
		fire("CHALLENGE_MODE_START")
		assert.same({ "Low: Food (0/5)" }, A.screen)
		assert.same({ "Low: Food (0/5)" }, A.Lines())
	end)

	it("nothing prints when every threshold is met", function()
		SB.Config.Set("consumables.watch", { { query = "flask", threshold = 2 }, { query = "potion", threshold = 5 } })
		fire("CHALLENGE_MODE_START")
		assert.same({}, A.screen)
		assert.same({}, A.Lines())
	end)

	-- Mutation: drop the teleports Matches test (warn on any spell).
	it("V11: a dungeon teleport (\"Path of ...\") warns; another spell does not", function()
		A.spellNames[445417] = "path of the ruined city"
		A.spellNames[8690] = "hearthstone"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8690)
		assert.same({}, A.screen)
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 445417)
		assert.same({ "Low: Food (0/5)" }, A.screen)
	end)

	it("zoning into a Mythic dungeon with a keystone warns; a heroic dungeon does not", function()
		A.instance = { instanceType = "party", difficultyID = 2 }
		fire("PLAYER_ENTERING_WORLD")
		assert.same({}, A.screen)
		A.instance = { instanceType = "party", difficultyID = 23 }
		fire("PLAYER_ENTERING_WORLD")
		assert.same({ "Low: Food (0/5)" }, A.screen)
	end)

	-- Mutation: compare `now - Cons.last[trigger] < 0` (no rate limit).
	it("at most once per 60 s per trigger; each trigger has its own clock", function()
		fire("CHALLENGE_MODE_START")
		fire("CHALLENGE_MODE_START")
		assert.equal(1, #A.screen)
		A.spellNames[445417] = "path of the ruined city"
		fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 445417)
		assert.equal(2, #A.screen)
		A.Advance(61)
		fire("CHALLENGE_MODE_START")
		assert.equal(3, #A.screen)
	end)

	it("switched off: no trigger warns; /swagbag consumables check still answers", function()
		SB.Slash.Dispatch("consumables off")
		fire("CHALLENGE_MODE_START")
		assert.same({}, A.screen)
		SB.Slash.Dispatch("consumables check")
		assert.same({ SB.L.CONSUMABLES_OFF, "Low: Food (0/5)" }, A.Lines())
	end)

	it("a check with everything stocked says so when asked by hand", function()
		SB.Config.Set("consumables.watch", { { query = "flask", threshold = 1 } })
		SB.Slash.Dispatch("consumables check")
		assert.same({ SB.L.CONSUMABLES_OK }, A.Lines())
	end)

	it("an entry whose query does not compile counts nothing and never errors", function()
		assert.equal(0, C.Count({ query = "flask &", threshold = 1 }))
	end)

	it("counts follow the bags: using a flask lowers the count", function()
		A.Put(0, 2, Fixtures.FLASK, 1)
		bagUpdate()
		assert.equal(1, C.Count({ query = "flask", threshold = 1 }))
	end)

	it("Add watches an item once (threshold 1); Remove and SetThreshold edit the saved list", function()
		assert.truthy(C.Add(Fixtures.HEALING_POTION))
		assert.same({ false, "known" }, { C.Add(Fixtures.HEALING_POTION) })
		assert.equal("Flask 1, Potions 5, Food 5, Algari Healing Potion 1", C.Summary())
		assert.truthy(C.SetThreshold(4, 8))
		assert.truthy(C.Remove(3))
		assert.equal("Flask 1, Potions 5, Algari Healing Potion 8", C.Summary())
		assert.truthy(C.SetThreshold(1, 999))
		assert.equal(200, C.List()[1].threshold, "thresholds are kept between 1 and 200")
		assert.same({ false, "invalid" }, { C.Remove(9) })
		assert.same({ false, "invalid" }, { C.Add(0) })
	end)

	it("Reset brings the default list back and stores nothing", function()
		C.Add(Fixtures.HEALING_POTION)
		SB.Slash.Dispatch("consumables reset")
		assert.is_nil(SB.Config.db.settings.consumables.watch)
		assert.same({ "The consumables watch list is back to the default: Flask 1, Potions 5, Food 5." }, A.Lines())
	end)

	-- Mutation: return true from save() without calling Config.Set.
	it("read-only settings (a newer schema): every edit refuses and changes nothing", function()
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { C.Add(Fixtures.HEALING_POTION) })
		assert.same({ false, "readonly" }, { C.SetThreshold(1, 3) })
		assert.same({ false, "readonly" }, { C.Remove(1) })
		assert.same({ false, "readonly" }, { C.Reset() })
		SB.Slash.Dispatch("consumables off")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[1])
		assert.equal("Flask 1, Potions 5, Food 5", C.Summary())
	end)

	it("damaged saved entries are skipped, never an error", function()
		SB.Config.Set("consumables.watch", { { query = "flask", threshold = 0 }, "x", { itemID = -3, threshold = 2 },
			{ itemID = Fixtures.FLASK, threshold = 2.5 }, { query = "potion", threshold = 3 } })
		assert.equal("potion 3", C.Summary(), "an entry without a name shows its search text")
		SB.Config.Set("consumables.watch", "broken")
		assert.equal("Flask 1, Potions 5, Food 5", C.Summary())
	end)

	it("the saved list survives a migration (v1 -> v2) and a failed one keeps it in the backup", function()
		local list = { { itemID = Fixtures.FLASK, threshold = 3 } }
		local db = { schemaVersion = 1, settings = { consumables = { watch = list } }, errors = {}, backups = {} }
		assert.equal("migrated", SB.Config.Init(db, nil))
		assert.equal("Flask of Alchemical Chaos 3", C.Summary())
		SB.Config.migrations[2] = function() error("boom") end
		local db2 = { schemaVersion = 1, settings = { consumables = { watch = list } }, errors = {}, backups = {} }
		assert.equal("reset", SB.Config.Init(db2, nil))
		assert.equal(3, SB.Config.db.backups.v1.settings.consumables.watch[1].threshold)
	end)

	it("/swagbag consumables lists the watch list; an unknown word shows the usage", function()
		SB.Slash.Dispatch("consumables")
		SB.Slash.Dispatch("consumables maybe")
		assert.same({ "Consumables warning on. Watching: Flask 1, Potions 5, Food 5", SB.L.CONSUMABLES_USAGE }, A.Lines())
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
	end

	M.AddContainers(m)
```

and replace it with:

```lua
	end

	-- On-screen lines (the consumables warning): m.screen = { text, ... }
	m.screen = {}
	function m.ScreenMessage(text)
		m.screen[#m.screen + 1] = text
	end

	M.AddContainers(m)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/consumables_spec.lua`
Expected: `0 passed, 17 failed`, each with `cannot open SwagBag/Engine/Consumables.lua: No such file or directory`.

Critical tests and their mutations (in `SwagBag/Engine/Consumables.lua` unless named):

| Test | Mutation |
|---|---|
| "counts whole stacks in the bags by keyword and by item" | `n = n + (s.count or 1)` → `n = n + 1` (either branch) |
| "V11: a key starting with too little food prints one line on screen and in chat" | `if have < e.threshold then` → `if have <= e.threshold then` |
| "V11: a dungeon teleport (\"Path of ...\") warns; another spell does not" | `if unit == "player" and SB.FocusData.Matches(SB.FocusData.teleports, spellID) then` → `if unit == "player" then` |
| "zoning into a Mythic dungeon with a keystone warns; a heroic dungeon does not" | `if s.instanceType == "party" and (s.challengeMode or (s.mythic and s.keystone)) then` → `if s.instanceType == "party" then` |
| "at most once per 60 s per trigger; each trigger has its own clock" | `now - Cons.last[trigger] < Cons.RATE` → `< 0` |
| "read-only settings (a newer schema): every edit refuses and changes nothing" | `save()` returns `true` without calling `SB.Config.Set` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
end

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
```

and replace it with:

```lua
end

-- One line in the middle of the screen (where "Not enough rage" shows), for the consumables
-- warning. Without UIErrorsFrame nothing shows there; chat still gets the line.
function A.ScreenMessage(text)
	local f = _G.UIErrorsFrame
	if f and f.AddMessage then
		pcall(f.AddMessage, f, text, 1.0, 0.82, 0.0)
	end
end

---------------------------------------------------------------------------
-- Feature checks (consumed by Core/Checks.lua). window: which Safe Mode
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "GetProfessionInfo", window = "bags", required = false },
}
```

and replace it with:

```lua
	{ path = "GetProfessionInfo", window = "bags", required = false },
	{ path = "UIErrorsFrame", window = "bags", required = false },
}
```

In `SwagBag/Core/Config.lua`, find:

```lua
			} },
	},
```

and replace it with:

```lua
			} },
		-- The low-consumables warning (spec 6.6, F11). warn: on by default. watch: nil means the
		-- default list (Engine/Consumables.lua); the user's edited list is stored here.
		consumables = { warn = true },
	},
```

Create `SwagBag/Engine/Consumables.lua`:

```lua
-- SwagBag low-consumables warning (spec 6.6, F11). Part of the M+ experience: when a key starts,
-- when the player zones into a Mythic dungeon holding a keystone, and when a dungeon teleport
-- ("Path of ...", Engine/FocusData.lua) is cast, each watched entry is counted in the bags and
-- one line names what is short: "Low: Flask (0/1), Potions (2/5)", on screen and in chat.
-- Nothing prints when every threshold is met. At most once per 60 s per trigger.
--   Consumables.List() -> { { query | itemID, threshold, name } }   the watch list (a copy)
--   Consumables.Low() -> { { name, have, need } }                    what is short now
--   Consumables.Check(trigger, force) -> low list | nil (nil: rate-limited or switched off)
--     force (the "Check now" button, /swagbag consumables check): no rate limit, always answers
--   Consumables.Add(itemID) / Remove(index) / SetThreshold(index, n) / Reset() -> ok, reason
--     reason "readonly" (newer settings), "known" (already watched), "invalid"
-- Settings: consumables.warn (default on); consumables.watch (nil = Consumables.DEFAULTS; a
-- list once the user edits it). The warning does not depend on the M+ mode being on or paused:
-- pausing only stops sections collapsing.
local _, SB = ...

local Cons = { RATE = 60, last = {}, compiled = {}, MAX_THRESHOLD = 200 }
SB.Consumables = Cons

-- name is a Locale key for keyword entries; item entries are named from the item.
Cons.DEFAULTS = {
	{ query = "flask", threshold = 1, name = "WATCH_FLASK" },
	{ query = "potion", threshold = 5, name = "WATCH_POTION" },
	{ query = "food", threshold = 5, name = "WATCH_FOOD" },
}

local function valid(e)
	if type(e) ~= "table" or type(e.threshold) ~= "number" or e.threshold < 1 or e.threshold ~= math.floor(e.threshold)
		or e.threshold > Cons.MAX_THRESHOLD then
		return false
	end
	if type(e.itemID) == "number" then
		return e.itemID >= 1 and e.itemID == math.floor(e.itemID) and e.itemID < math.huge
	end
	return type(e.query) == "string" and e.query ~= ""
end

-- The watch list as plain copies; damaged saved entries are skipped, never an error.
function Cons.List()
	local saved = SB.Config.Get("consumables.watch")
	local src = type(saved) == "table" and saved or Cons.DEFAULTS
	local out = {}
	for _, e in ipairs(src) do
		if valid(e) then
			out[#out + 1] = { query = e.query, itemID = e.itemID, threshold = e.threshold, name = e.name }
		end
	end
	return out
end

function Cons.Name(e)
	local L = SB.L
	if e.itemID then
		local info = SB.Adapter.GetItemInfo(e.itemID)
		return info and info.name or L.ITEM_N:format(e.itemID)
	end
	return e.name and L[e.name] or e.query
end

local function compiled(query)
	local c = Cons.compiled[query]
	if not c then
		c = SB.Query.Compile(query)
		Cons.compiled[query] = c
	end
	return c
end

-- How many of an entry the bags hold (backpack, bags and the reagent bag).
function Cons.Count(e)
	local n = 0
	local c = e.query and compiled(e.query)
	for bag, slot, s in SB.Inventory.Iterate("bags") do
		if s then
			if e.itemID then
				if s.itemID == e.itemID then
					n = n + (s.count or 1)
				end
			elseif c and c.fn then
				local record = SB.Items.Describe(bag, slot)
				if record and SB.Query.Eval(c, record) == true then
					n = n + (s.count or 1)
				end
			end
		end
	end
	return n
end

function Cons.Low()
	local low = {}
	for _, e in ipairs(Cons.List()) do
		local have = Cons.Count(e)
		if have < e.threshold then
			low[#low + 1] = { name = Cons.Name(e), have = have, need = e.threshold }
		end
	end
	return low
end

function Cons.Check(trigger, force)
	local A, L = SB.Adapter, SB.L
	if not force then
		if not SB.Config.Get("consumables.warn") then
			return nil
		end
		local now = A.Now()
		if Cons.last[trigger] and now - Cons.last[trigger] < Cons.RATE then
			return nil
		end
		Cons.last[trigger] = now
	end
	local low = Cons.Low()
	if #low == 0 then
		if force then
			SB.Print(L.CONSUMABLES_OK)
		end
		return low
	end
	local parts = {}
	for i, l in ipairs(low) do
		parts[i] = L.CONSUMABLES_PART:format(l.name, l.have, l.need)
	end
	local text = L.CONSUMABLES_LOW:format(table.concat(parts, ", "))
	A.ScreenMessage(text)
	SB.Print(text)
	return low
end

---------------------------------------------------------------------------
-- Editing the watch list (Settings, /swagbag consumables). Every write refuses while the
-- settings are read-only (a newer schema) and changes nothing then.
---------------------------------------------------------------------------
local function save(list)
	if not SB.Config.Set("consumables.watch", list) then
		return false, "readonly"
	end
	return true
end

function Cons.Add(itemID)
	if type(itemID) ~= "number" or not valid({ itemID = itemID, threshold = 1 }) then
		return false, "invalid"
	end
	local list = Cons.List()
	for _, e in ipairs(list) do
		if e.itemID == itemID then
			return false, "known"
		end
	end
	list[#list + 1] = { itemID = itemID, threshold = 1 }
	return save(list)
end

function Cons.Remove(index)
	local list = Cons.List()
	if not list[index] then
		return false, "invalid"
	end
	table.remove(list, index)
	return save(list)
end

function Cons.SetThreshold(index, n)
	local list = Cons.List()
	if not list[index] or type(n) ~= "number" then
		return false, "invalid"
	end
	list[index].threshold = math.max(1, math.min(Cons.MAX_THRESHOLD, math.floor(n)))
	return save(list)
end

function Cons.Reset()
	return save(nil)
end

function Cons.Summary()
	local L, parts = SB.L, {}
	for i, e in ipairs(Cons.List()) do
		parts[i] = L.CONSUMABLES_ENTRY:format(Cons.Name(e), e.threshold)
	end
	return #parts > 0 and table.concat(parts, ", ") or L.REPORT_NONE
end

---------------------------------------------------------------------------
-- Triggers (spec 6.6). They wait for login like the signals (Engine/Signals.lua runs first, so
-- the zone signals are fresh when PLAYER_ENTERING_WORLD reaches this file).
---------------------------------------------------------------------------
local function on(event, fn)
	SB.On(event, function(...)
		if SB.Signals.ready then
			fn(...)
		end
	end, "bags")
end

on("CHALLENGE_MODE_START", function()
	Cons.Check("start")
end)

on("PLAYER_ENTERING_WORLD", function()
	local s = SB.Focus.signals
	if s.instanceType == "party" and (s.challengeMode or (s.mythic and s.keystone)) then
		Cons.Check("enter")
	end
end)

on("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
	if unit == "player" and SB.FocusData.Matches(SB.FocusData.teleports, spellID) then
		Cons.Check("portal")
	end
end)

SB.Slash.Register("consumables", SB.L.HELP_CONSUMABLES, function(arg)
	local L, C = SB.L, SB.Config
	arg = (arg or ""):lower()
	if arg == "" then
		return L.CONSUMABLES_LIST:format(C.Get("consumables.warn") and L.OVERLAY_ON or L.OVERLAY_OFF, Cons.Summary())
	elseif arg == "check" then
		Cons.Check("manual", true)
		return {}
	elseif arg == "on" or arg == "off" then
		if not C.Set("consumables.warn", arg == "on") then
			return L.SETTINGS_READONLY
		end
		return arg == "on" and L.CONSUMABLES_ON or L.CONSUMABLES_OFF
	elseif arg == "reset" then
		if not Cons.Reset() then
			return L.SETTINGS_READONLY
		end
		return L.CONSUMABLES_RESET:format(Cons.Summary())
	end
	return L.CONSUMABLES_USAGE
end, "bags")
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.HELP_MODE = "mode [pause|resume|list]: pause or resume focus modes for this session, or list them"
L.REPORT_FOCUS = "Focus: %s (%s); zone %s, collapsing %s; M+ %s, keystone %s, delve %s, fishing %s, gathering %s"
```

and replace it with:

```lua
L.HELP_MODE = "mode [pause|resume|list]: pause or resume focus modes for this session, or list them"
L.WATCH_FLASK = "Flask"
L.WATCH_POTION = "Potions"
L.WATCH_FOOD = "Food"
L.ITEM_N = "item %d"
L.CONSUMABLES_LOW = "Low: %s"
L.CONSUMABLES_PART = "%s (%d/%d)"
L.CONSUMABLES_OK = "All watched consumables are stocked."
L.CONSUMABLES_ENTRY = "%s %d"
L.CONSUMABLES_LIST = "Consumables warning %s. Watching: %s"
L.CONSUMABLES_USAGE = "Use /swagbag consumables, or /swagbag consumables check, on, off or reset."
L.CONSUMABLES_ON = "The low-consumables warning is on: it checks when a key starts, when you enter a Mythic dungeon"
	.. " with a keystone, and when you use a dungeon teleport."
L.CONSUMABLES_OFF = "The low-consumables warning is off. Type /swagbag consumables on to switch it back on."
L.CONSUMABLES_RESET = "The consumables watch list is back to the default: %s."
L.HELP_CONSUMABLES = "consumables [check|on|off|reset]: show, test or switch the low-consumables warning"
L.REPORT_FOCUS = "Focus: %s (%s); zone %s, collapsing %s; M+ %s, keystone %s, delve %s, fishing %s, gathering %s"
```

In `SwagBag/SwagBag.toc`, find:

```text
Engine/FocusData.lua
Engine/Signals.lua

# Providers
```

and replace it with:

```text
Engine/FocusData.lua
Engine/Signals.lua
Engine/Consumables.lua

# Providers
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/consumables_spec.lua`
Expected: `17 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (47 files)`, `800 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: In-game session K1** (a real key; full restart, because this task adds a file).

- [ ] **Step 7: Commit**

```bash
git add "spec/consumables_spec.lua" "spec/mock_adapter.lua" "SwagBag/Core/Adapter.lua" "SwagBag/Core/Config.lua" "SwagBag/Engine/Consumables.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 5: low-consumables warning on key start, Mythic dungeon entry and dungeon teleports

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 6: The settings window and the Bags, Bank & guild, and Overlays pages (F15, AC15.2, spec 10.5)

`UI/SettingsWindow.lua` is SwagBag's own movable frame, built from plain frames only (D17). Page buttons sit on the left; a scrolling list of rows fills the right; a status line runs along the bottom. Pages register with `SW.AddPage{ id, title, rows = function }` in TOC order and are rebuilt after every click from pooled widgets (no new frames per click).

Row kinds:
- `choice`: the default first, then the alternatives; the current one is highlighted (P1);
- `actions`: buttons that each run something;
- `drop`: a button that takes the item on the cursor;
- `note`: text only.

Every click runs inside `ErrorTrap.Run("…", "none")`, and its feedback (or `L.SETTINGS_FAILED`) goes to the status line (P2). A choice that has a chat command runs it through the new `SB.Slash.Run`, so the window and the command can never disagree. A bare `/swagbag` and `/swagbag settings [page]` open the window.

Pages this task adds (each row lists the default first):
- **Bags:** view (Categories / Grid), slots per row (12 / 10 / 14 / 16), window size (100 % / 80 / 90 / 110 / 125), free slots (one with the count / every free slot), reagent bag (mixed in / own section), item level in the title.
- **Bank & guild:** Blizzard's bank (hidden / shown beside), guild bank (SwagBag's window / view only), right-click withdraws from (the selected tab / any tab), gold totals (show / hide).
- **Overlays:** each overlay on or off, and the upgrade arrow decided by item level or Pawn.

**Files:**
- Create: `SwagBag/UI/SettingsWindow.lua`, `SwagBag/UI/SettingsPages.lua`
- Modify: `SwagBag/Core/Slash.lua` (`Slash.Run`, `Slash.onEmpty`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/settings_spec.lua` (new)

**Interfaces:**
- Consumes (on `aa3fea1`): `SB.Slash.commands` (`free`, `bank`, `guild`, `overlays`), `SB.BagsWindow.View/SetView/SetScale/RequestLayout`, `SB.Categories.Load/Get`, `SB.Config.Get/Set/readOnly`, `SB_PRICES_CHANGED`.
- Produces:
  - `SB.Slash.Run(line) -> ok, feedback` and `SB.Slash.onEmpty`;
  - `SB.SettingsWindow` with `AddPage(page)`, `Show(pageId) -> true`, `Hide()`, `IsOpen()`, `Render()` and `Say(feedback)`;
  - its fields `frame`, `pages`, `byId`, `current`, `buttons`, `used`, `selected`, `lastStatus` and `nav`;
  - the slash command `settings`;
  - pages `bags`, `bank` and `overlays`.

- [ ] **Step 1: Write the failing tests**

Create `spec/settings_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The settings window (spec F15, 10.5): pages of choices, default first with its alternative
-- next to it (P1), feedback for every click (P2), read-only refusal, plain frames only.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Settings window", function()
	local SB, A, SW, bags, ran
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		-- The bags window as the settings rows use it.
		bags = { calls = {} }
		function bags.View() return SB.Config.Get("bags.view") end
		function bags.SetView(v) bags.calls[#bags.calls + 1] = "view " .. v SB.Config.Set("bags.view", v) end
		function bags.SetScale(v) bags.calls[#bags.calls + 1] = "scale " .. v SB.Config.Set("bags.scale", v) end
		function bags.RequestLayout(r) bags.calls[#bags.calls + 1] = "layout " .. r end
		SB.BagsWindow = bags
		-- The chat commands the rows run (their real versions live in the windows' files).
		ran = {}
		for _, name in ipairs({ "free", "bank", "guild", "overlays" }) do
			SB.Slash.Register(name, "test", function(arg)
				ran[#ran + 1] = name .. " " .. arg
				return "ran " .. name .. " " .. arg
			end)
		end
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		SW = SB.SettingsWindow
		SB.Categories.Load()
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- The shown buttons of the page, in order: { text, selected }.
	local function buttons()
		local out = {}
		for i = 1, SW.used.buttons do
			local b = SW.buttons[i]
			out[#out + 1] = { b.text, SW.selected[b] == true }
		end
		return out
	end

	local function button(text)
		for i = 1, SW.used.buttons do
			local b = SW.buttons[i]
			if b.text == text then
				return b
			end
		end
		error("no button " .. text)
	end

	local function click(text)
		Fake.Fire(button(text), "OnClick")
	end

	it("a bare /swagbag opens the settings at the first page (spec 10.5)", function()
		SW.frame:Hide()
		SB.Slash.Dispatch("")
		assert.truthy(SW.IsOpen())
		assert.equal("bags", SW.current)
		assert.same({ "Settings opened." }, A.Lines())
	end)

	it("/swagbag settings <page> opens that page; an unknown page lists the pages", function()
		SB.Slash.Dispatch("settings bank")
		assert.equal("bank", SW.current)
		SB.Slash.Dispatch("settings nope")
		assert.equal("Use /swagbag settings, or /swagbag settings <page> (pages: bags, bank, overlays).", A.Lines()[2])
	end)

	it("P1: each row shows the default first, its alternative next to it, and the current one selected", function()
		SW.Show("bags")
		local b = buttons()
		assert.same({ "Categories", true }, b[1])
		assert.same({ "Grid", false }, b[2])
		assert.same({ "12", true }, b[3], "12 slots per row, the default, first")
	end)

	-- Mutation: in SettingsWindow's act(), drop SW.Say (the status line keeps the old text).
	it("P2: a choice with a chat command runs it and shows its answer", function()
		SW.Show("bags")
		click("Every free slot")
		assert.same({ "free all" }, ran)
		assert.equal("ran free all", SW.lastStatus)
	end)

	it("columns: saved, the bags regroup, the status says so, and the new one is selected", function()
		SW.Show("bags")
		click("14")
		assert.equal(14, SB.Config.Get("bags.columns"))
		assert.same({ "layout columns" }, bags.calls)
		assert.equal("Bags: 14 slots per row.", SW.lastStatus)
		assert.truthy(SW.selected[button("14")])
		assert.falsy(SW.selected[button("12")])
	end)

	-- Mutation: in the columns row's apply, ignore Config.Set's result.
	it("read-only settings: a click refuses with the reason and the selection stays", function()
		SB.Config.readOnly = true
		SW.Show("bags")
		click("14")
		assert.equal(12, SB.Config.Get("bags.columns"))
		assert.equal(SB.L.SETTINGS_READONLY, SW.lastStatus)
		assert.truthy(SW.selected[button("12")])
		click("Grid")
		assert.same({}, bags.calls)
		assert.equal(SB.L.SETTINGS_READONLY, SW.lastStatus)
	end)

	it("the view and size rows go through the bags window", function()
		SW.Show("bags")
		click("Grid")
		click("125%")
		assert.same({ "view grid", "scale 1.25" }, bags.calls)
		assert.equal("SwagBag 125%", SW.lastStatus)
	end)

	it("reagent bag own section: the categories are rebuilt, so Reagents exists at once", function()
		SW.Show("bags")
		assert.falsy(SB.Categories.Get("c_reagents").enabled)
		click("Own section")
		assert.truthy(SB.Categories.Get("c_reagents").enabled)
		assert.equal(SB.L.SET_REAGENTS_OWN_DONE, SW.lastStatus)
	end)

	it("bank page rows run the bank and guild commands; totals off refreshes the open headers", function()
		local refreshed = 0
		SB.On("SB_PRICES_CHANGED", function() refreshed = refreshed + 1 end)
		SW.Show("bank")
		click("Shown beside")
		click("View only")
		click("Any tab")
		click("Hide")
		assert.same({ "bank beside", "guild view", "guild anytab on" }, ran)
		assert.equal(false, SB.Config.Get("prices.headerTotals"))
		assert.equal(1, refreshed)
	end)

	it("overlays page: each overlay switches through /swagbag overlays", function()
		SW.Show("overlays")
		click("Off") -- the first row: item level on gear
		click("Pawn")
		assert.same({ "overlays ilvl off", "overlays pawn on" }, ran)
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
	it("an error in a change is recorded without Safe Mode, and the status line says so", function()
		SW.Show("bags")
		bags.RequestLayout = function() error("layout broke") end
		click("14")
		assert.equal(SB.L.SETTINGS_FAILED, SW.lastStatus)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("opens in combat, and creates only plain frames (never an item or secure button)", function()
		A.combat = true
		SW.Show("bank")
		SW.Show("overlays")
		SW.Show("bags")
		for _, f in ipairs(Fake.created) do
			assert.truthy(f.kind == "Frame" or f.kind == "Button" or f.kind == "ScrollFrame", f.kind)
			assert.falsy(tostring(f.template):find("Secure"), tostring(f.template))
		end
	end)

	it("rebuilding a page reuses its buttons (no new frames per click)", function()
		SW.Show("bags")
		local n = #Fake.created
		click("14")
		click("12")
		SW.Show("bank")
		SW.Show("bags")
		assert.equal(n, #Fake.created)
	end)
end)

describe("Settings window load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Get = function() error("Config.Get called while loading") end
		Fake.Install()
		local ok, err = pcall(function()
			Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
			Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		end)
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/settings_spec.lua`
Expected: `0 passed, 14 failed`, each with `cannot open SwagBag/UI/SettingsWindow.lua: No such file or directory`.

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "P2: a choice with a chat command runs it and shows its answer" | `SettingsWindow.lua`: delete `SW.Say(ok and feedback or L.SETTINGS_FAILED)` in `act` |
| "read-only settings: a click refuses with the reason and the selection stays" | `SettingsPages.lua`: in the columns row, replace the `if not SB.Config.Set(…) then return L.SETTINGS_READONLY end` with a bare `SB.Config.Set("bags.columns", v)` |
| "an error in a change is recorded without Safe Mode, and the status line says so" | `SettingsWindow.lua`: in `act`, `local ok, feedback = SB.ErrorTrap.Run(label, "none", fn, ...)` → `local ok, feedback = true, fn(...)` |
| "a bare /swagbag opens the settings at the first page (spec 10.5)" | `Slash.lua`: `if Slash.onEmpty then` → `if false then` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Slash.lua`, find:

```lua
end

-- Dispatch runs inside SlashCmdList.SWAGBAG's ErrorTrap wrapper; callers must use the entry point.
function Slash.Dispatch(msg)
	local L = SB.L
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" then
		SB.Print(L.NO_SETTINGS_YET)
		return
```

and replace it with:

```lua
end

-- Run one command line ("free tile") the way the chat command would, but return its feedback
-- instead of printing it: ok, feedback (a string, a list of strings, or nil for "Done."). The
-- settings window uses this so a choice there does exactly what the command does (P2).
function Slash.Run(line)
	local L = SB.L
	local cmd, rest = (line or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local c = Slash.commands[cmd:lower()]
	if not c then
		return false, L.UNKNOWN_COMMAND:format(cmd)
	end
	local ok, feedback = SB.ErrorTrap.Run("slash:" .. cmd:lower(), c.window, c.fn, rest)
	if not ok then
		return false, L.CMD_FAILED
	end
	return true, feedback
end

-- Dispatch runs inside SlashCmdList.SWAGBAG's ErrorTrap wrapper; callers must use the entry point.
-- A bare /swagbag runs Slash.onEmpty (the settings window) when one is set (spec 10.5).
function Slash.Dispatch(msg)
	local L = SB.L
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" then
		if Slash.onEmpty then
			say(Slash.onEmpty())
		else
			SB.Print(L.NO_SETTINGS_YET)
		end
		return
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_NO = "no"

-- In-game check V1 (optional)
```

and replace it with:

```lua
L.REPORT_NO = "no"

-- Settings window (spec F15)
L.SET_TITLE = "SwagBag settings"
L.SET_SAVED_NOTE = "Changes apply at once and are saved when you log out or type /reload."
L.SETTINGS_FAILED = "That change hit an error. It was recorded; type /swagbag report."
L.SET_USAGE = "Use /swagbag settings, or /swagbag settings <page> (pages: %s)."
L.SET_OPENED = "Settings opened."
L.HELP_SETTINGS = "settings [page]: open the settings window (a bare /swagbag does too)"
L.SET_PAGE_BAGS = "Bags"
L.SET_PAGE_BANK = "Bank & guild"
L.SET_PAGE_OVERLAYS = "Overlays"
L.SET_ON = "On"
L.SET_OFF = "Off"
L.SET_SHOW = "Show"
L.SET_HIDE = "Hide"
L.SET_PERCENT = "%d%%"
L.SET_VIEW = "Bag view"
L.SET_COLUMNS = "Slots per row"
L.SET_COLUMNS_DONE = "Bags: %d slots per row."
L.SET_SCALE = "Bag window size"
L.SET_FREE = "Free slots"
L.SET_FREE_TILE = "One with the count"
L.SET_FREE_ALL = "Every free slot"
L.SET_REAGENTS = "Reagent bag"
L.SET_REAGENTS_MIXED = "Mixed in"
L.SET_REAGENTS_OWN = "Own section"
L.SET_REAGENTS_MIXED_DONE = "Reagent bag items are mixed into your categories again."
L.SET_REAGENTS_OWN_DONE = "Reagent bag items now have their own section, Reagents."
L.SET_TITLE_ILVL = "Item level in the bags title"
L.SET_BANK_FRAME = "Blizzard's bank while SwagBag's bank is open"
L.SET_BANK_TINY = "Hidden"
L.SET_BANK_BESIDE = "Shown beside"
L.SET_GUILD_MODE = "Guild bank"
L.SET_GUILD_FULL = "SwagBag's window"
L.SET_GUILD_VIEW = "View only"
L.SET_GUILD_ANYTAB = "A right-click in the guild bank withdraws from"
L.SET_GUILD_SELECTED = "Selected tab"
L.SET_GUILD_ANY = "Any tab"
L.SET_TOTALS = "Gold totals on section headers"
L.SET_TOTALS_ON = "Section headers show their gold totals."
L.SET_TOTALS_OFF = "Section headers no longer show gold totals."
L.SET_BANK_NOTE = "Tab purchase, warband gold and the guild bank log stay in Blizzard's windows: use the Blizzard bank and"
	.. " Blizzard guild bank buttons."
L.SET_OV_ILVL = "Item level on gear"
L.SET_OV_TRACK = "Upgrade track"
L.SET_OV_UPGRADE = "Upgrade arrow"
L.SET_OV_KEYSTONE = "Keystone level and dungeon"
L.SET_OV_JUNK = "Junk coin"
L.SET_OV_BIND = "BoE and WuE badge"
L.SET_OV_PAWN = "The upgrade arrow is decided by"
L.SET_PAWN_ILVL = "Item level"
L.SET_PAWN_PAWN = "Pawn"

-- In-game check V1 (optional)
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/Overlays.lua
UI/DebugV1.lua
```

and replace it with:

```text
UI/Overlays.lua
UI/SettingsWindow.lua
UI/SettingsPages.lua
UI/DebugV1.lua
```

Create `SwagBag/UI/SettingsPages.lua`:

```lua
-- SwagBag settings pages: Bags, Bank & guild bank, Overlays (spec F15, AC15.2). Every row shows
-- the opinionated default first and its alternative next to it (P1). A choice that has a chat
-- command runs that command (SB.Slash.Run), so the window and the command can never disagree;
-- the rest set their setting here. Every choice answers in the status line (P2), and refuses
-- with L.SETTINGS_READONLY while the settings are read-only (a newer schema).
local _, SB = ...

local L = SB.L
local SW = SB.SettingsWindow

-- Run a chat command and hand back its feedback.
local function run(line)
	local _, feedback = SB.Slash.Run(line)
	return feedback
end

local function get(path)
	return function()
		return SB.Config.Get(path)
	end
end

local function onOff(label, path, command)
	return { kind = "choice", label = label, get = get(path),
		choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			return run(command .. (v and " on" or " off"))
		end }
end

-- Bags --------------------------------------------------------------------
local function bagsRows()
	local W = SB.BagsWindow
	return {
		{ kind = "choice", label = L.SET_VIEW, get = function()
			return W.View()
		end, choices = { { value = "sections", text = L.VIEW_TO_SECTIONS }, { value = "grid", text = L.VIEW_TO_GRID } },
		apply = function(v)
			if SB.Config.readOnly then
				return L.SETTINGS_READONLY
			end
			W.SetView(v)
			return v == "grid" and L.VIEW_GRID or L.VIEW_SECTIONS
		end },
		{ kind = "choice", label = L.SET_COLUMNS, get = get("bags.columns"), width = 56,
			choices = { { value = 12, text = tostring(12) }, { value = 10, text = tostring(10) },
				{ value = 14, text = tostring(14) }, { value = 16, text = tostring(16) } },
			apply = function(v)
				if not SB.Config.Set("bags.columns", v) then
					return L.SETTINGS_READONLY
				end
				W.RequestLayout("columns")
				return L.SET_COLUMNS_DONE:format(v)
			end },
		{ kind = "choice", label = L.SET_SCALE, get = get("bags.scale"), width = 56,
			choices = { { value = 1.0, text = L.SET_PERCENT:format(100) }, { value = 0.8, text = L.SET_PERCENT:format(80) },
				{ value = 0.9, text = L.SET_PERCENT:format(90) }, { value = 1.1, text = L.SET_PERCENT:format(110) },
				{ value = 1.25, text = L.SET_PERCENT:format(125) } },
			apply = function(v)
				if SB.Config.readOnly then
					return L.SETTINGS_READONLY
				end
				W.SetScale(v)
				return L.BAGS_SCALE:format(math.floor(v * 100 + 0.5))
			end },
		{ kind = "choice", label = L.SET_FREE, get = get("bags.freeTile"),
			choices = { { value = true, text = L.SET_FREE_TILE }, { value = false, text = L.SET_FREE_ALL } },
			apply = function(v)
				return run(v and "free tile" or "free all")
			end },
		{ kind = "choice", label = L.SET_REAGENTS, get = get("bags.reagentSeparate"),
			choices = { { value = false, text = L.SET_REAGENTS_MIXED }, { value = true, text = L.SET_REAGENTS_OWN } },
			apply = function(v)
				if not SB.Config.Set("bags.reagentSeparate", v) then
					return L.SETTINGS_READONLY
				end
				SB.Categories.Load()
				W.RequestLayout("reagents")
				return v and L.SET_REAGENTS_OWN_DONE or L.SET_REAGENTS_MIXED_DONE
			end },
		onOff(L.SET_TITLE_ILVL, "bags.showIlvl", "overlays title"),
	}
end

-- Bank and guild bank -----------------------------------------------------
local function bankRows()
	return {
		{ kind = "choice", label = L.SET_BANK_FRAME, get = get("bank.blizzardFrame"),
			choices = { { value = "tiny", text = L.SET_BANK_TINY }, { value = "beside", text = L.SET_BANK_BESIDE } },
			apply = function(v)
				return run("bank " .. v)
			end },
		{ kind = "choice", label = L.SET_GUILD_MODE, get = get("guildBank.mode"),
			choices = { { value = "full", text = L.SET_GUILD_FULL }, { value = "view", text = L.SET_GUILD_VIEW } },
			apply = function(v)
				return run("guild " .. v)
			end },
		{ kind = "choice", label = L.SET_GUILD_ANYTAB, get = get("guildBank.withdrawAnyTab"),
			choices = { { value = false, text = L.SET_GUILD_SELECTED }, { value = true, text = L.SET_GUILD_ANY } },
			apply = function(v)
				return run("guild anytab " .. (v and "on" or "off"))
			end },
		{ kind = "choice", label = L.SET_TOTALS, get = get("prices.headerTotals"),
			choices = { { value = true, text = L.SET_SHOW }, { value = false, text = L.SET_HIDE } },
			apply = function(v)
				if not SB.Config.Set("prices.headerTotals", v) then
					return L.SETTINGS_READONLY
				end
				SB.Emit("SB_PRICES_CHANGED") -- open windows re-read their header texts in place
				return v and L.SET_TOTALS_ON or L.SET_TOTALS_OFF
			end },
		{ kind = "note", label = L.SET_BANK_NOTE },
	}
end

-- Overlays ----------------------------------------------------------------
local OVERLAYS = {
	{ "ilvl", "overlays.ilvl", L.SET_OV_ILVL }, { "track", "overlays.track", L.SET_OV_TRACK },
	{ "upgrade", "overlays.upgrade", L.SET_OV_UPGRADE }, { "keystone", "overlays.keystone", L.SET_OV_KEYSTONE },
	{ "junk", "overlays.junk", L.SET_OV_JUNK }, { "bind", "overlays.bind", L.SET_OV_BIND },
}

local function overlayRows()
	local rows = {}
	for _, o in ipairs(OVERLAYS) do
		rows[#rows + 1] = onOff(o[3], o[2], "overlays " .. o[1])
	end
	rows[#rows + 1] = { kind = "choice", label = L.SET_OV_PAWN, get = get("overlays.usePawn"),
		choices = { { value = false, text = L.SET_PAWN_ILVL }, { value = true, text = L.SET_PAWN_PAWN } },
		apply = function(v)
			return run("overlays pawn " .. (v and "on" or "off"))
		end }
	return rows
end

SW.AddPage({ id = "bags", title = L.SET_PAGE_BAGS, rows = bagsRows })
SW.AddPage({ id = "bank", title = L.SET_PAGE_BANK, rows = bankRows })
SW.AddPage({ id = "overlays", title = L.SET_PAGE_OVERLAYS, rows = overlayRows })
```

Create `SwagBag/UI/SettingsWindow.lua`:

```lua
-- SwagBag settings window (spec F15, 10.5): SwagBag's own frame, opened by a bare /swagbag or
-- /swagbag settings [page]. No Blizzard Settings-panel integration (the spec does not ask for
-- one); only plain Frames, Buttons and FontStrings, so it opens in combat and never touches a
-- secure frame or an item button.
-- Each page is a list of rows, laid out top to bottom, label above its buttons:
--   { kind = "choice", label, choices = { { value, text } }, get() -> value, apply(value) -> feedback }
--       the opinionated default is the first choice, the alternative right next to it (P1);
--       the button whose value get() returns is shown selected (highlight locked)
--   { kind = "actions", label, actions = { { text, run() -> feedback } } }
--   { kind = "drop", label, text, onDrop() -> feedback }   a button that takes the item on the
--       cursor (dragged onto it, or clicked while holding it)
--   { kind = "note", label }
-- Pages register with SW.AddPage{ id, title, rows = function() -> list }, in TOC order, and are
-- rebuilt after every click, so a page can change its rows (the focus mode being edited).
-- Every click answers in the status line at the bottom (P2): the feedback text, which for a
-- read-only setting is L.SETTINGS_READONLY. An error is recorded (window "none": a settings
-- glitch never takes the bags away) and the status line says so.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local SW = { pages = {}, byId = {}, current = nil, labels = {}, buttons = {}, used = { labels = 0, buttons = 0 },
	selected = {}, WIDTH = 640, HEIGHT = 470, NAV = 140, BUTTON = 120, ROW = 20, GAP = 8 }
SB.SettingsWindow = SW

local frame = CreateFrame("Frame", "SwagBagSettings", UIParent, "BackdropTemplate")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(SW.WIDTH, SW.HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
frame:Hide()
SW.frame = frame
table.insert(UISpecialFrames, "SwagBagSettings")

frame:SetScript("OnDragStart", Guard("settings.dragStart", function()
	frame:StartMoving()
end, "none"))
frame:SetScript("OnDragStop", Guard("settings.dragStop", function()
	frame:StopMovingOrSizing()
end, "none"))

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOPLEFT", 12, -10)
frame.title:SetText(L.SET_TITLE)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.status:SetPoint("BOTTOMLEFT", SW.NAV + 12, 10)
frame.status:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
frame.status:SetJustifyH("LEFT")
frame.status:SetWordWrap(true)
frame.status:SetText(L.SET_SAVED_NOTE)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", SW.NAV + 8, -40)
scroll:SetPoint("BOTTOMRIGHT", -8, 44)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(SW.WIDTH - SW.NAV - 16, 100)
scroll:SetScrollChild(child)
SW.scroll, SW.child = scroll, child
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("settings.wheel", function(_, delta)
	local max = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
	scroll:SetVerticalScroll(math.max(0, math.min(max, scroll:GetVerticalScroll() - delta * 40)))
end, "none"))

-- The status line: feedback (string, list of strings, or nil = "Done.").
function SW.Say(feedback)
	if type(feedback) == "table" then
		feedback = table.concat(feedback, " ")
	end
	if feedback == nil or feedback == "" then
		feedback = L.CMD_DONE
	end
	SW.lastStatus = feedback
	frame.status:SetText(feedback)
end

-- Run fn (a click) inside ErrorTrap; its return value is the feedback. Then redraw the page.
local function act(label, fn, ...)
	local ok, feedback = SB.ErrorTrap.Run(label, "none", fn, ...)
	SW.Say(ok and feedback or L.SETTINGS_FAILED)
	SW.Render()
end

---------------------------------------------------------------------------
-- Widget pools (plain FontStrings and Buttons inside the scroll child)
---------------------------------------------------------------------------
local function label()
	SW.used.labels = SW.used.labels + 1
	local fs = SW.labels[SW.used.labels]
	if not fs then
		fs = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetJustifyH("LEFT")
		SW.labels[SW.used.labels] = fs
	end
	fs:Show()
	return fs
end

local function button()
	SW.used.buttons = SW.used.buttons + 1
	local b = SW.buttons[SW.used.buttons]
	if not b then
		b = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
		b:SetHeight(SW.ROW)
		b:SetScript("OnClick", Guard("settings.click", function(self)
			if self.onClick then
				self.onClick()
			end
		end, "none"))
		b:SetScript("OnReceiveDrag", Guard("settings.drop", function(self)
			if self.onDrop then
				self.onDrop()
			end
		end, "none"))
		SW.buttons[SW.used.buttons] = b
	end
	b.onClick, b.onDrop = nil, nil
	b:Show()
	return b
end

local function setSelected(b, on)
	SW.selected[b] = on and true or nil
	if on then
		b:LockHighlight()
	else
		b:UnlockHighlight()
	end
end

local function place(region, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", child, "TOPLEFT", x, y)
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
SW.nav = {}

function SW.AddPage(page)
	SW.pages[#SW.pages + 1] = page
	SW.byId[page.id] = page
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(SW.NAV - 16, 22)
	b:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40 - (#SW.pages - 1) * 26)
	b:SetText(page.title)
	b:SetScript("OnClick", Guard("settings.page", function()
		SW.Show(page.id)
	end, "none"))
	SW.nav[page.id] = b
	return page
end

-- Lay the current page out again (after every click, and on open).
function SW.Render()
	for i = 1, SW.used.labels do
		SW.labels[i]:Hide()
	end
	for i = 1, SW.used.buttons do
		local b = SW.buttons[i]
		setSelected(b, false)
		b:Hide()
	end
	SW.used.labels, SW.used.buttons = 0, 0
	local page = SW.byId[SW.current]
	if not page then
		return
	end
	for id, b in pairs(SW.nav) do
		setSelected(b, id == SW.current)
	end
	local y = -4
	for _, row in ipairs(page.rows()) do
		local fs = label()
		fs:SetText(row.label)
		place(fs, 4, y)
		y = y - 18
		local items = row.choices or row.actions
		if row.kind == "drop" then
			items = { { text = row.text } }
		end
		if items then
			local current = row.get and row.get()
			local x = 12
			for _, item in ipairs(items) do
				local b = button()
				b:SetText(item.text)
				b:SetWidth(item.width or row.width or SW.BUTTON)
				place(b, x, y)
				x = x + (item.width or row.width or SW.BUTTON) + 4
				if row.kind == "choice" then
					setSelected(b, current == item.value)
					b.onClick = function()
						act("settings.choice", row.apply, item.value)
					end
				elseif row.kind == "actions" then
					b.onClick = function()
						act("settings.action", item.run)
					end
				else
					b.onClick = function()
						act("settings.drop", row.onDrop)
					end
					b.onDrop = b.onClick
				end
			end
			y = y - SW.ROW - SW.GAP
		end
	end
	child:SetHeight(-y)
end

-- Show the window at a page (default: the last one shown, else the first).
function SW.Show(pageId)
	SW.current = (pageId and SW.byId[pageId] and pageId) or SW.current or (SW.pages[1] and SW.pages[1].id)
	scroll:SetVerticalScroll(0)
	frame:Show()
	SW.Render()
	return true
end

function SW.Hide()
	frame:Hide()
end

function SW.IsOpen()
	return frame:IsShown()
end

-- /swagbag and /swagbag settings [page] (spec 10.5).
local function open(arg)
	arg = (arg or ""):lower()
	if arg ~= "" and not SW.byId[arg] then
		local ids = {}
		for i, p in ipairs(SW.pages) do
			ids[i] = p.id
		end
		return L.SET_USAGE:format(table.concat(ids, ", "))
	end
	SW.Show(arg ~= "" and arg or nil)
	return L.SET_OPENED
end

SB.Slash.Register("settings", L.HELP_SETTINGS, open)
SB.Slash.onEmpty = function()
	return open("")
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/settings_spec.lua`
Expected: `14 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (49 files)`, `814 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add "spec/settings_spec.lua" "SwagBag/Core/Slash.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc" "SwagBag/UI/SettingsPages.lua" "SwagBag/UI/SettingsWindow.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 6: settings window with Bags, Bank & guild and Overlays pages; /swagbag opens it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 7: Settings → Focus modes (AC8.1–AC8.5, AC15.1); right-click on Pause opens it

The Focus modes page has these rows:
- Focus modes (switch by themselves / off);
- when two modes apply at once (open both sets / strict priority);
- a click on a collapsed section in a mode (peeks / keeps it open);
- mode changes in chat (quiet / announce);
- these focus settings are for (all characters / this character, D18);
- each of the six modes on or off;
- "Edit the sections of" (one button per mode), then for the picked mode one Open / Collapsed row per category, with `Reset to default` next to them (spec §6.3).

Every write goes through Task 1's Focus setters or `Config.Set` plus `Focus.Refresh("settings")`, so an open bag re-stacks at once (guarded as in Task 3). The bags window's Pause button gets its right-click: Settings → Focus modes at the active mode's sections (AC8.5, D9). A tooltip names both clicks.

**Files:**
- Create: `SwagBag/UI/SettingsFocus.lua`
- Modify: `SwagBag/UI/BagsWindow.lua` (Pause button right-click and tooltip), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/settings_focus_spec.lua` (new), `spec/bagswindow_sections_spec.lua`

**Interfaces:**
- Consumes: Task 1's `Focus.MODES/byId/IsEnabled/SetEnabled/Sections/SetSections/ResetSections/Refresh/active`. Task 6's `SettingsWindow.AddPage/Show/Say`. Task 4's `W.modeButton`, `W.TogglePause`. On `aa3fea1`: `Config.CharOverride/IsCharOverride`, `Categories.SectionOrder/Name`.
- Produces: `SB.SettingsFocus.Edit(modeId)`, `SettingsFocus.Paths() -> { setting paths }`, `SettingsFocus.editing`. Page `focus`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua`, find:

```lua
	end)

	it("/swagbag mode answers every form (P2)", function()
```

and replace it with:

```lua
	end)

	-- Mutation: ignore mouseButton in the mode button's click (always pause).
	it("AC8.5: a right-click on the Pause button opens the settings at the active mode's sections", function()
		local edited = {}
		SB.SettingsFocus = { Edit = function(id) edited[#edited + 1] = id end }
		F.SetSignal("fishing", true)
		W.Open()
		W.modeButton.scripts.OnClick(W.modeButton, "RightButton")
		assert.same({ "fishing" }, edited)
		assert.falsy(F.IsPaused(), "a right-click does not pause")
	end)

	it("/swagbag mode answers every form (P2)", function()
```

Create `spec/settings_focus_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The Focus modes settings page (spec 6, AC8.1-8.5, AC15.1): every focus setting with its
-- alternative, per-mode on/off, each mode's sections with Reset to default, and "This character".
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Settings: focus modes page", function()
	local SB, SW, F, events
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsFocus.lua")
		SW, F = SB.SettingsWindow, SB.Focus
		SB.Categories.Load()
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason) events[#events + 1] = reason end)
		SW.Show("focus")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- The button with this text in the row with this label (rows are label, then its buttons).
	local function rowButton(rowLabel, text)
		local page = SW.byId[SW.current].rows()
		local index = 0
		for _, row in ipairs(page) do
			local items = row.choices or row.actions or (row.kind == "drop" and { {} }) or {}
			for _, item in ipairs(items) do
				index = index + 1
				if row.label == rowLabel and item.text == text then
					return SW.buttons[index]
				end
			end
		end
		error("no button " .. text .. " in row " .. rowLabel)
	end

	local function click(rowLabel, text)
		Fake.Fire(rowButton(rowLabel, text), "OnClick")
	end

	local function selected(rowLabel, text)
		return SW.selected[rowButton(rowLabel, text)] == true
	end

	local L
	before_each(function()
		L = SB.L
	end)

	it("AC8.1 and P1: the defaults are selected, each with its alternative next to it", function()
		assert.truthy(selected(L.SET_FOCUS_AUTO, L.SET_FOCUS_AUTO_ON))
		assert.truthy(selected(L.SET_FOCUS_RESOLVE, L.SET_FOCUS_MERGE))
		assert.truthy(selected(L.SET_FOCUS_PEEK, L.SET_FOCUS_PEEK_PEEK))
		assert.truthy(selected(L.SET_FOCUS_ANNOUNCE, L.SET_FOCUS_QUIET))
		assert.truthy(selected(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT))
		for _, name in ipairs({ "M+", "Raid", "Delves", "Gathering", "Fishing", "AH/Vendor/Bank" }) do
			assert.truthy(selected(L.SET_MODE_LABEL:format(name), L.SET_ON), name)
		end
		assert.truthy(selected(L.SET_EDIT_MODE, "M+"))
		assert.truthy(selected("Consumables", L.SET_SECTION_OPEN))
		assert.truthy(selected("Junk", L.SET_SECTION_CLOSED))
	end)

	-- Mutation: drop `SB.Focus.Refresh("settings")` from the setting rows' apply.
	it("strict priority is saved and the open bag re-stacks (SB_FOCUS_CHANGED settings)", function()
		click(L.SET_FOCUS_RESOLVE, L.SET_FOCUS_PRIORITY)
		assert.equal("priority", SB.Config.Get("focus.resolve"))
		assert.same({ "settings" }, events)
		assert.equal(L.SET_FOCUS_PRIORITY_DONE, SW.lastStatus)
		assert.truthy(selected(L.SET_FOCUS_RESOLVE, L.SET_FOCUS_PRIORITY))
	end)

	it("a mode switched off never triggers", function()
		click(L.SET_MODE_LABEL:format("Fishing"), L.SET_OFF)
		assert.falsy(F.IsEnabled("fishing"))
		assert.equal("Fishing mode is off: it no longer collapses anything.", SW.lastStatus)
		F.SetSignal("fishing", true)
		assert.same({}, F.Active())
	end)

	-- Mutation: in the section row's apply, keep `sid` out of the list when v is true.
	it("a section opened for M+ joins its set; the M+ mode then opens it", function()
		click("Junk", L.SET_SECTION_OPEN)
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_junk" }, F.Sections("mplus"))
		assert.equal("Junk now opens in the M+ mode.", SW.lastStatus)
		click("Gear", L.SET_SECTION_CLOSED)
		assert.same({ "c_consumables", "c_keystone", "c_junk" }, F.Sections("mplus"))
	end)

	it("Reset to default brings the built-in set back", function()
		click("Junk", L.SET_SECTION_OPEN)
		click(L.SET_SECTIONS_DEFAULT_LABEL, L.SET_RESET_DEFAULT)
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
		assert.equal("The M+ mode opens its default sections again.", SW.lastStatus)
	end)

	it("picking another mode shows its sections", function()
		click(L.SET_EDIT_MODE, "Fishing")
		assert.truthy(selected("Fish & Lures", L.SET_SECTION_OPEN))
		assert.truthy(selected("Consumables", L.SET_SECTION_CLOSED))
		click("Consumables", L.SET_SECTION_OPEN)
		assert.same({ "c_fish", "c_cooking", "c_consumables" }, F.Sections("fishing"))
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"), "M+ untouched")
	end)

	-- Mutation: CharOverride only "focus.auto" in the scope row's apply.
	it("AC15.1: \"This character\" makes every focus setting this character's own; back again clears them", function()
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		for _, path in ipairs(SB.SettingsFocus.Paths()) do
			assert.truthy(SB.Config.IsCharOverride(path), path)
		end
		click("Junk", L.SET_SECTION_OPEN)
		click(L.SET_MODE_LABEL:format("Raid"), L.SET_OFF)
		assert.is_nil(SB.Config.db.settings.focus, "the account-wide settings are untouched")
		assert.equal("c_consumables,c_keystone,c_gear,c_junk", SB.Config.charDB.overrides["focus.sections.mplus"])
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT)
		assert.falsy(SB.Config.IsCharOverride("focus.sections.mplus"))
		assert.truthy(F.IsEnabled("raid"), "the account setting applies again")
	end)

	it("read-only settings: every focus change refuses with the reason", function()
		SB.Config.readOnly = true
		click("Junk", L.SET_SECTION_OPEN)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		click(L.SET_FOCUS_RESOLVE, L.SET_FOCUS_PRIORITY)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
	end)

	it("Edit(mode) opens the page at that mode and says so (AC8.5)", function()
		SW.Hide()
		SB.SettingsFocus.Edit("gathering")
		assert.truthy(SW.IsOpen())
		assert.equal("focus", SW.current)
		assert.truthy(selected(L.SET_EDIT_MODE, "Gathering"))
		assert.equal("Editing the sections the Gathering mode opens (below).", SW.lastStatus)
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/settings_focus_spec.lua`
Expected: `87 passed, 10 failed`. The nine `Settings: focus modes page` tests fail with `cannot open SwagBag/UI/SettingsFocus.lua: No such file or directory`, and "AC8.5: a right-click on the Pause button opens the settings at the active mode's sections" fails because a right-click still pauses.

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "strict priority is saved and the open bag re-stacks (SB_FOCUS_CHANGED settings)" | `SettingsFocus.lua`: delete `SB.Focus.Refresh("settings")` in `setting()`'s apply |
| "a section opened for M+ joins its set; …" | `SettingsFocus.lua`: delete the `if v then list[#list + 1] = sid end` lines |
| "AC15.1: \"This character\" makes every focus setting this character's own; …" | `SettingsFocus.lua`: `for _, path in ipairs(SF.Paths()) do` → `for _, path in ipairs({ "focus.auto" }) do` |
| "AC8.5: a right-click on the Pause button opens the settings …" | `BagsWindow.lua`: `if mouseButton == "RightButton" and SB.SettingsFocus then` → `if false then` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SET_PAWN_PAWN = "Pawn"

-- In-game check V1 (optional)
```

and replace it with:

```lua
L.SET_PAWN_PAWN = "Pawn"

-- Settings: focus modes page
L.SET_PAGE_FOCUS = "Focus modes"
L.SET_FOCUS_AUTO = "Focus modes"
L.SET_FOCUS_AUTO_ON = "Switch by themselves"
L.SET_FOCUS_AUTO_DONE = "Focus modes switch by themselves again."
L.SET_FOCUS_OFF_DONE = "Focus modes are off: your sections stay as you set them."
L.SET_FOCUS_RESOLVE = "When two modes apply at once"
L.SET_FOCUS_MERGE = "Open both sets"
L.SET_FOCUS_PRIORITY = "Strict priority"
L.SET_FOCUS_MERGE_DONE = "Two modes at once now open the sections of both."
L.SET_FOCUS_PRIORITY_DONE = "Two modes at once now open only the stronger one's (dungeon or activity before vendor)."
L.SET_FOCUS_PEEK = "A click on a collapsed section in a mode"
L.SET_FOCUS_PEEK_PEEK = "Peeks"
L.SET_FOCUS_PEEK_KEEP = "Keeps it open"
L.SET_FOCUS_PEEK_DONE = "A clicked section now stays open until you close your bags."
L.SET_FOCUS_KEEP_DONE = "A clicked section now stays open until the mode changes."
L.SET_FOCUS_ANNOUNCE = "Mode changes in chat"
L.SET_FOCUS_QUIET = "Quiet"
L.SET_FOCUS_LOUD = "Announce"
L.SET_FOCUS_QUIET_DONE = "Mode changes are quiet again."
L.SET_FOCUS_LOUD_DONE = "Each mode change now prints one line in chat."
L.SET_FOCUS_SCOPE = "These focus settings are for"
L.SET_FOCUS_ACCOUNT = "All characters"
L.SET_FOCUS_CHARACTER = "This character"
L.SET_FOCUS_ACCOUNT_DONE = "This character uses the account-wide focus settings again."
L.SET_FOCUS_CHARACTER_DONE = "This character now has its own focus settings; the others keep theirs."
L.SET_MODE_LABEL = "Mode: %s"
L.SET_MODE_ON = "%s mode is on."
L.SET_MODE_OFF = "%s mode is off: it no longer collapses anything."
L.SET_EDIT_MODE = "Edit the sections of"
L.SET_EDITING = "Editing the sections the %s mode opens (below)."
L.SET_SECTIONS_OF = "Sections the %s mode opens (New is always open):"
L.SET_SECTION_OPEN = "Open"
L.SET_SECTION_CLOSED = "Collapsed"
L.SET_SECTION_NOW_OPEN = "%s now opens in the %s mode."
L.SET_SECTION_NOW_CLOSED = "%s now collapses in the %s mode."
L.SET_SECTIONS_DEFAULT_LABEL = "Back to SwagBag's choice for this mode"
L.SET_RESET_DEFAULT = "Reset to default"
L.SET_SECTIONS_RESET = "The %s mode opens its default sections again."
L.SET_GATHERING_NOTE = "Gathering opens only the materials of the gathering professions this character has."
L.MODE_TIP_TITLE = "Focus modes"
L.MODE_TIP_LEFT = "Left-click: pause or resume for this session"
L.MODE_TIP_RIGHT = "Right-click: choose the sections this mode opens"

-- In-game check V1 (optional)
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/SettingsPages.lua
UI/DebugV1.lua
```

and replace it with:

```text
UI/SettingsPages.lua
UI/SettingsFocus.lua
UI/DebugV1.lua
```

In `SwagBag/UI/BagsWindow.lua`, find:

```lua
end

W.modeButton = titleButton(L.BTN_PAUSE, "bags.modeButton", function()
	W.TogglePause()
end, 64)
W.modeButton:SetPoint("RIGHT", W.reflowButton, "LEFT", -4, 0)
```

and replace it with:

```lua
end

-- Left-click: pause / resume. Right-click: the Focus modes settings page at the active mode's
-- sections (AC8.5). The tooltip says both.
W.modeButton = titleButton(L.BTN_PAUSE, "bags.modeButton", function(_, mouseButton)
	if mouseButton == "RightButton" and SB.SettingsFocus then
		SB.SettingsFocus.Edit(SB.Focus.active[1])
	else
		W.TogglePause()
	end
end, 64)
W.modeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
W.modeButton:SetScript("OnEnter", Guard("bags.modeTip", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L.MODE_TIP_TITLE)
	GameTooltip:AddLine(L.MODE_TIP_LEFT, 1, 1, 1)
	GameTooltip:AddLine(L.MODE_TIP_RIGHT, 1, 1, 1)
	GameTooltip:Show()
end, "bags"))
W.modeButton:SetScript("OnLeave", Guard("bags.modeTipHide", function()
	GameTooltip:Hide()
end, "bags"))
W.modeButton:SetPoint("RIGHT", W.reflowButton, "LEFT", -4, 0)
```

Create `SwagBag/UI/SettingsFocus.lua`:

```lua
-- SwagBag settings: the Focus modes page (spec 6, AC8.1-8.5, AC15.1). Switching modes on and
-- off, merge or strict priority, peek or keep open, announce, account-wide or this character
-- only, and each mode's section set with "Reset to default" next to it (spec 6.3). The bags
-- window's Pause button opens this page at the active mode with a right-click (AC8.5).
--   SettingsFocus.Edit(modeId)   open the page with that mode's sections shown
local _, SB = ...

local L = SB.L
local SF = { editing = "mplus" }
SB.SettingsFocus = SF

-- Every focus setting: "This character only" makes each one a character override (AC15.1).
function SF.Paths()
	local paths = { "focus.auto", "focus.resolve", "focus.peek", "focus.announce" }
	for _, m in ipairs(SB.Focus.MODES) do
		paths[#paths + 1] = "focus.on." .. m.id
		paths[#paths + 1] = "focus.sections." .. m.id
	end
	return paths
end

local function modeName(id)
	return L[SB.Focus.byId[id].name]
end

local function setting(label, path, choices, done)
	return { kind = "choice", label = label, choices = choices, get = function()
		return SB.Config.Get(path)
	end, apply = function(v)
		if not SB.Config.Set(path, v) then
			return L.SETTINGS_READONLY
		end
		SB.Focus.Refresh("settings")
		return done(v)
	end }
end

-- The sections the mode being edited opens, with one Open / Collapsed row per category.
local function sectionRows(rows)
	local F, id = SB.Focus, SF.editing
	local open = {}
	for _, sid in ipairs(F.Sections(id)) do
		open[sid] = true
	end
	rows[#rows + 1] = { kind = "note", label = L.SET_SECTIONS_OF:format(modeName(id)) }
	for _, sid in ipairs(SB.Categories.SectionOrder()) do
		if sid ~= SB.Categories.NEW and sid ~= SB.Categories.FREE then
			local name = SB.Categories.Name(sid)
			rows[#rows + 1] = { kind = "choice", label = name, width = 96,
				choices = { { value = true, text = L.SET_SECTION_OPEN }, { value = false, text = L.SET_SECTION_CLOSED } },
				get = function()
					return open[sid] == true
				end,
				apply = function(v)
					local list = {}
					for _, s in ipairs(F.Sections(id)) do
						if s ~= sid then
							list[#list + 1] = s
						end
					end
					if v then
						list[#list + 1] = sid
					end
					if not F.SetSections(id, list) then
						return L.SETTINGS_READONLY
					end
					return (v and L.SET_SECTION_NOW_OPEN or L.SET_SECTION_NOW_CLOSED):format(name, modeName(id))
				end }
		end
	end
	rows[#rows + 1] = { kind = "actions", label = L.SET_SECTIONS_DEFAULT_LABEL, actions = { { text = L.SET_RESET_DEFAULT,
		run = function()
			if not F.ResetSections(id) then
				return L.SETTINGS_READONLY
			end
			return L.SET_SECTIONS_RESET:format(modeName(id))
		end } } }
	if id == "gathering" then
		rows[#rows + 1] = { kind = "note", label = L.SET_GATHERING_NOTE }
	end
end

local function rows()
	local F = SB.Focus
	local out = {
		setting(L.SET_FOCUS_AUTO, "focus.auto", { { value = true, text = L.SET_FOCUS_AUTO_ON },
			{ value = false, text = L.SET_OFF } }, function(v)
			return v and L.SET_FOCUS_AUTO_DONE or L.SET_FOCUS_OFF_DONE
		end),
		setting(L.SET_FOCUS_RESOLVE, "focus.resolve", { { value = "merge", text = L.SET_FOCUS_MERGE },
			{ value = "priority", text = L.SET_FOCUS_PRIORITY } }, function(v)
			return v == "merge" and L.SET_FOCUS_MERGE_DONE or L.SET_FOCUS_PRIORITY_DONE
		end),
		setting(L.SET_FOCUS_PEEK, "focus.peek", { { value = "peek", text = L.SET_FOCUS_PEEK_PEEK },
			{ value = "keep", text = L.SET_FOCUS_PEEK_KEEP } }, function(v)
			return v == "peek" and L.SET_FOCUS_PEEK_DONE or L.SET_FOCUS_KEEP_DONE
		end),
		setting(L.SET_FOCUS_ANNOUNCE, "focus.announce", { { value = false, text = L.SET_FOCUS_QUIET },
			{ value = true, text = L.SET_FOCUS_LOUD } }, function(v)
			return v and L.SET_FOCUS_LOUD_DONE or L.SET_FOCUS_QUIET_DONE
		end),
		{ kind = "choice", label = L.SET_FOCUS_SCOPE, choices = { { value = false, text = L.SET_FOCUS_ACCOUNT },
			{ value = true, text = L.SET_FOCUS_CHARACTER } },
			get = function()
				return SB.Config.IsCharOverride("focus.auto")
			end,
			apply = function(v)
				for _, path in ipairs(SF.Paths()) do
					if not SB.Config.CharOverride(path, v) then
						return L.SETTINGS_READONLY
					end
				end
				F.Refresh("settings")
				return v and L.SET_FOCUS_CHARACTER_DONE or L.SET_FOCUS_ACCOUNT_DONE
			end },
	}
	for _, m in ipairs(F.MODES) do
		out[#out + 1] = { kind = "choice", label = L.SET_MODE_LABEL:format(L[m.name]),
			choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
			get = function()
				return F.IsEnabled(m.id)
			end,
			apply = function(v)
				if not F.SetEnabled(m.id, v) then
					return L.SETTINGS_READONLY
				end
				return (v and L.SET_MODE_ON or L.SET_MODE_OFF):format(L[m.name])
			end }
	end
	local pick = { kind = "choice", label = L.SET_EDIT_MODE, width = 76, choices = {}, get = function()
		return SF.editing
	end, apply = function(v)
		SF.editing = v
		return L.SET_EDITING:format(modeName(v))
	end }
	for _, m in ipairs(F.MODES) do
		pick.choices[#pick.choices + 1] = { value = m.id, text = L[m.name] }
	end
	out[#out + 1] = pick
	sectionRows(out)
	return out
end

SB.SettingsWindow.AddPage({ id = "focus", title = L.SET_PAGE_FOCUS, rows = rows })

-- Open the page at one mode's sections (the Pause button's right-click, AC8.5).
function SF.Edit(modeId)
	if modeId and SB.Focus.byId[modeId] then
		SF.editing = modeId
	end
	SB.SettingsWindow.Show("focus")
	SB.SettingsWindow.Say(L.SET_EDITING:format(modeName(SF.editing)))
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/settings_focus_spec.lua`
Expected: `97 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (50 files)`, `824 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add "spec/bagswindow_sections_spec.lua" "spec/settings_focus_spec.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc" "SwagBag/UI/BagsWindow.lua" "SwagBag/UI/SettingsFocus.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 7: Settings -> Focus modes page; right-click on Pause opens it at the active mode

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 8: Settings → Consumables (AC11.2)

The Consumables page has:
- the warning on or off (through `/swagbag consumables on|off`) and when it checks;
- one row per watched entry, `Flask: warn below 1`, with `-`, `+` and `Remove`;
- a `Drop an item here` target: drag an item onto it, or click it while holding one. The item is watched at threshold 1 and goes back to the bag. A refused item stays on the cursor with the reason;
- `Check now` (no rate limit, always answers) and `Reset to default`.

**Files:**
- Create: `SwagBag/UI/SettingsConsumables.lua`
- Modify: `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/settings_consumables_spec.lua` (new)

**Interfaces:**
- Consumes: Task 5's `Consumables.List/Name/Add/Remove/SetThreshold/Reset/Check/Summary`. Task 6's `SettingsWindow.AddPage`, `Slash.Run`. On `aa3fea1`: `Adapter.CursorItem/ClearCursor`.
- Produces: page `consumables`.

- [ ] **Step 1: Write the failing tests**

Create `spec/settings_consumables_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The Consumables settings page (spec 6.6, AC11.2): on/off, thresholds, remove, drop an item
-- to watch it, Check now, Reset to default; read-only refusals keep the item on the cursor.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Settings: consumables page", function()
	local SB, A, SW, C, L
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		for _, f in ipairs({ "SwagBag/Engine/Focus.lua", "SwagBag/Engine/FocusData.lua", "SwagBag/Engine/Signals.lua",
			"SwagBag/Engine/Consumables.lua" }) do
			files[#files + 1] = f
		end
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsConsumables.lua")
		SW, C, L = SB.SettingsWindow, SB.Consumables, SB.L
		SB.Emit("SB_LOGIN")
		SW.Show("consumables")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function rowButton(rowLabel, text)
		local index = 0
		for _, row in ipairs(SW.byId.consumables.rows()) do
			local items = row.choices or row.actions or (row.kind == "drop" and { { text = row.text } }) or {}
			for _, item in ipairs(items) do
				index = index + 1
				if row.label == rowLabel and item.text == text then
					return SW.buttons[index]
				end
			end
		end
		error("no button " .. text .. " in row " .. rowLabel)
	end

	local function click(rowLabel, text)
		Fake.Fire(rowButton(rowLabel, text), "OnClick")
	end

	it("lists the default watch list with each threshold", function()
		assert.truthy(rowButton("Flask: warn below 1", "+"))
		assert.truthy(rowButton("Potions: warn below 5", "Remove"))
		assert.truthy(rowButton("Food: warn below 5", "-"))
		assert.truthy(SW.selected[rowButton(L.SET_WATCH_WARN, L.SET_ON)])
	end)

	-- Mutation: make the + action call change(e.threshold) (no change).
	it("+ and - change a threshold and say the new value; the row follows", function()
		click("Potions: warn below 5", "+")
		assert.equal(6, C.List()[2].threshold)
		assert.equal("Potions: warns when you have fewer than 6.", SW.lastStatus)
		click("Potions: warn below 6", "-")
		click("Potions: warn below 5", "-")
		assert.equal(4, C.List()[2].threshold)
		click("Flask: warn below 1", "-")
		assert.equal(1, C.List()[1].threshold, "never below 1")
	end)

	it("Remove stops watching an entry", function()
		click("Food: warn below 5", "Remove")
		assert.equal("Flask 1, Potions 5", C.Summary())
		assert.equal("Food is no longer watched.", SW.lastStatus)
	end)

	-- Mutation: call A.ClearCursor() before C.Add in onDrop.
	it("AC11.2: an item dropped on the drop target is watched (threshold 1) and leaves the cursor", function()
		A.cursor = { itemID = Fixtures.HEALING_POTION, link = "item:211880" }
		Fake.Fire(rowButton(L.SET_WATCH_ADD, L.SET_WATCH_DROP), "OnReceiveDrag")
		assert.equal("Flask 1, Potions 5, Food 5, Algari Healing Potion 1", C.Summary())
		assert.equal("Now watching Algari Healing Potion (warns below 1; use + to raise it).", SW.lastStatus)
		assert.is_nil(A.cursor)
	end)

	it("a click on the drop target while holding an item does the same; an empty cursor explains", function()
		click(L.SET_WATCH_ADD, L.SET_WATCH_DROP)
		assert.equal(L.SET_WATCH_DROP_EMPTY, SW.lastStatus)
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		click(L.SET_WATCH_ADD, L.SET_WATCH_DROP)
		assert.equal("Flask 1, Potions 5, Food 5, Flask of Alchemical Chaos 1", C.Summary())
	end)

	it("an item already watched, or read-only settings, keep the item on the cursor with the reason", function()
		C.Add(Fixtures.FLASK)
		SW.Render()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		click(L.SET_WATCH_ADD, L.SET_WATCH_DROP)
		assert.equal(L.SET_WATCH_KNOWN, SW.lastStatus)
		assert.truthy(A.cursor)
		SB.Config.readOnly = true
		A.cursor = { itemID = Fixtures.HEALING_POTION, link = "item:211880" }
		click(L.SET_WATCH_ADD, L.SET_WATCH_DROP)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		assert.truthy(A.cursor)
		click("Flask: warn below 1", "+")
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
	end)

	it("Check now prints the result whatever the rate limit; Reset to default restores the list", function()
		SB.eventFrame:Fire("CHALLENGE_MODE_START")
		click(L.SET_WATCH_TOOLS, L.SET_CHECK_NOW)
		assert.same({ "Low: Food (0/5)", "Low: Food (0/5)" }, A.Lines())
		assert.equal(L.SET_WATCH_CHECKED, SW.lastStatus)
		click("Food: warn below 5", "Remove")
		click(L.SET_WATCH_TOOLS, L.SET_RESET_DEFAULT)
		assert.equal("Flask 1, Potions 5, Food 5", C.Summary())
	end)

	it("the warning switch runs /swagbag consumables on|off", function()
		click(L.SET_WATCH_WARN, L.SET_OFF)
		assert.equal(false, SB.Config.Get("consumables.warn"))
		assert.equal(L.CONSUMABLES_OFF, SW.lastStatus)
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/settings_consumables_spec.lua`
Expected: `0 passed, 8 failed`, each with `cannot open SwagBag/UI/SettingsConsumables.lua: No such file or directory`.

Critical tests and their mutations (in `SwagBag/UI/SettingsConsumables.lua`):

| Test | Mutation |
|---|---|
| "+ and - change a threshold and say the new value; the row follows" | the `+` action's `run = change(e.threshold + 1)` → `run = change(e.threshold)` |
| "an item already watched, or read-only settings, keep the item on the cursor with the reason" | call `A.ClearCursor()` before `C.Add(itemID)` in `onDrop` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.MODE_TIP_RIGHT = "Right-click: choose the sections this mode opens"

-- In-game check V1 (optional)
```

and replace it with:

```lua
L.MODE_TIP_RIGHT = "Right-click: choose the sections this mode opens"

-- Settings: consumables page
L.SET_PAGE_CONSUMABLES = "Consumables"
L.SET_WATCH_WARN = "Low-consumables warning"
L.SET_WATCH_WHEN = "It checks your bags when a key starts, when you enter a Mythic dungeon with a keystone, and when you"
	.. " use a dungeon teleport."
L.SET_WATCH_ROW = "%s: warn below %d"
L.SET_LESS = "-"
L.SET_MORE = "+"
L.SET_REMOVE = "Remove"
L.SET_WATCH_NEED = "%s: warns when you have fewer than %d."
L.SET_WATCH_REMOVED = "%s is no longer watched."
L.SET_WATCH_GONE = "That entry changed meanwhile; look again."
L.SET_WATCH_ADD = "Watch another item"
L.SET_WATCH_DROP = "Drop an item here"
L.SET_WATCH_DROP_EMPTY = "Pick up an item first (click it in your bags), then click here or drop it here."
L.SET_WATCH_KNOWN = "That item is already watched. Your item stays on the cursor."
L.SET_WATCH_ADDED = "Now watching %s (warns below 1; use + to raise it)."
L.SET_WATCH_TOOLS = "Test or start over"
L.SET_CHECK_NOW = "Check now"
L.SET_WATCH_CHECKED = "Checked: the result is in chat."

-- In-game check V1 (optional)
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/SettingsFocus.lua
UI/DebugV1.lua
```

and replace it with:

```text
UI/SettingsFocus.lua
UI/SettingsConsumables.lua
UI/DebugV1.lua
```

Create `SwagBag/UI/SettingsConsumables.lua`:

```lua
-- SwagBag settings: the Consumables page (spec 6.6, AC11.2). The warning on or off, each watched
-- entry with its threshold (- and +) and Remove, a drop target to watch another item (drag an
-- item onto it, or click it while holding one), Check now, and Reset to default.
local _, SB = ...

local L = SB.L

local function rows()
	local C, A = SB.Consumables, SB.Adapter
	local out = {
		{ kind = "choice", label = L.SET_WATCH_WARN, get = function()
			return SB.Config.Get("consumables.warn")
		end, choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			local _, feedback = SB.Slash.Run(v and "consumables on" or "consumables off")
			return feedback
		end },
		{ kind = "note", label = L.SET_WATCH_WHEN },
	}
	for i, e in ipairs(C.List()) do
		local name = C.Name(e)
		local function change(n)
			return function()
				local ok, why = C.SetThreshold(i, n)
				if not ok then
					return why == "readonly" and L.SETTINGS_READONLY or L.SET_WATCH_GONE
				end
				return L.SET_WATCH_NEED:format(name, C.List()[i].threshold)
			end
		end
		out[#out + 1] = { kind = "actions", label = L.SET_WATCH_ROW:format(name, e.threshold), actions = {
			{ text = L.SET_LESS, width = 40, run = change(e.threshold - 1) },
			{ text = L.SET_MORE, width = 40, run = change(e.threshold + 1) },
			{ text = L.SET_REMOVE, width = 80, run = function()
				local ok, why = C.Remove(i)
				if not ok then
					return why == "readonly" and L.SETTINGS_READONLY or L.SET_WATCH_GONE
				end
				return L.SET_WATCH_REMOVED:format(name)
			end },
		} }
	end
	out[#out + 1] = { kind = "drop", label = L.SET_WATCH_ADD, text = L.SET_WATCH_DROP, onDrop = function()
		local itemID = A.CursorItem()
		if not itemID then
			return L.SET_WATCH_DROP_EMPTY
		end
		local ok, why = C.Add(itemID)
		if not ok then
			return (why == "readonly" and L.SETTINGS_READONLY) or (why == "known" and L.SET_WATCH_KNOWN) or L.DROP_INVALID
		end
		A.ClearCursor() -- only now: a refused item stays on the cursor
		return L.SET_WATCH_ADDED:format(C.Name({ itemID = itemID }))
	end }
	out[#out + 1] = { kind = "actions", label = L.SET_WATCH_TOOLS, actions = {
		{ text = L.SET_CHECK_NOW, run = function()
			C.Check("manual", true)
			return L.SET_WATCH_CHECKED
		end },
		{ text = L.SET_RESET_DEFAULT, run = function()
			if not C.Reset() then
				return L.SETTINGS_READONLY
			end
			return L.CONSUMABLES_RESET:format(C.Summary())
		end },
	} }
	return out
end

SB.SettingsWindow.AddPage({ id = "consumables", title = L.SET_PAGE_CONSUMABLES, rows = rows })
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/settings_consumables_spec.lua`
Expected: `8 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (51 files)`, `832 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: In-game session S1** (settings pages; full restart, because Tasks 6–8 added files).

- [ ] **Step 7: Commit**

```bash
git add "spec/settings_consumables_spec.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc" "SwagBag/UI/SettingsConsumables.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 8: Settings -> Consumables page (thresholds, remove, drop to watch, check now, reset)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 9: The quick setup screen (spec 12.1; AC7.2, AC7.4)

The screen offers five playstyle toggles (M+, Raid, Gold-making, Casual, Collector, pick any), slots per row (10 / 12 / 14), and `Apply` and `Skip (use defaults)` (D19). It shows once per account, 3 s after the first login with this build. It does not show with read-only settings or with the bags in Safe Mode.

What each way out does:
- **Apply** writes the picked presets and the column count. It moves categories up for Gold and Collector, marks setup done, refreshes the open windows and says `Set up for …`.
- **Skip** marks setup done and says so.
- **Esc or the X** saves nothing and says the screen comes back at the next login.

`/swagbag setup` shows it again. `/swagbag tour` says the tour arrives in November (D20).

**Files:**
- Create: `SwagBag/UI/QuickSetup.lua`
- Modify: `SwagBag/Core/Config.lua` (`setup.done`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/quicksetup_spec.lua` (new)

**Interfaces:**
- Consumes: Task 1's `Focus.Refresh`. On `aa3fea1`: `Categories.Load/display/SectionOrder`, `Overlays.RefreshAll`, `BagsWindow.IsOpen/RequestLayout/RefreshTitle`, `SafeMode.IsOn`, `SB.Debounce`.
- Produces:
  - `SB.QuickSetup.STYLES`, `Preset(picked) -> { { path, value } }` and `Order(display, picked) -> ids | nil`;
  - `QuickSetup.Apply() -> feedback`, `Skip() -> feedback`, `Show()`, `Close(how)` and `IsOpen()`;
  - fields `QuickSetup.frame`, `styleButtons`, `columnButtons`, `applyButton` and `skipButton`;
  - setting `setup.done`;
  - slash commands `setup` and `tour`.

- [ ] **Step 1: Write the failing tests**

Create `spec/quicksetup_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The quick setup screen (spec 12.1 "one-screen quick setup (playstyle -> preset)"; AC7.2,
-- AC7.4): when it shows, what each style sets, Apply / Skip / later, read-only.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Quick setup", function()
	local SB, A, QS, bags
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		bags = { layouts = 0, open = false }
		function bags.IsOpen() return bags.open end
		function bags.RequestLayout() bags.layouts = bags.layouts + 1 end
		function bags.RefreshTitle() end
		SB.BagsWindow = bags
		Loader.LoadFile(SB, "SwagBag/UI/QuickSetup.lua")
		QS = SB.QuickSetup
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function login()
		SB.Emit("SB_LOGIN")
		A.Advance(3)
	end

	local function pick(id)
		Fake.Fire(QS.styleButtons[id], "OnClick")
	end

	it("shows a few seconds after the first login; not again once applied or skipped", function()
		SB.Emit("SB_LOGIN")
		assert.falsy(QS.IsOpen(), "not during the loading screen")
		A.Advance(3)
		assert.truthy(QS.IsOpen())
		Fake.Fire(QS.skipButton, "OnClick")
		login()
		assert.falsy(QS.IsOpen())
	end)

	it("does not show with read-only settings or while the bags are in Safe Mode", function()
		SB.Config.readOnly = true
		login()
		assert.falsy(QS.IsOpen())
		SB.Config.readOnly = false
		SB.SafeMode.Enable("bags", "manual")
		login()
		assert.falsy(QS.IsOpen())
	end)

	-- Mutation: drop the `not picked.mplus and not picked.raid` guard on Casual.
	it("presets: M+ and Raid switch things on; Casual alone switches the warning and the track off", function()
		assert.same({ { "focus.on.mplus", true }, { "consumables.warn", true }, { "overlays.keystone", true },
			{ "overlays.track", true } }, QS.Preset({ mplus = true }))
		assert.same({ { "consumables.warn", false }, { "overlays.track", false } }, QS.Preset({ casual = true }))
		assert.same(QS.Preset({ mplus = true }), QS.Preset({ mplus = true, casual = true }))
		assert.same({ { "prices.headerTotals", true } }, QS.Preset({ gold = true }))
	end)

	it("Gold moves Trade Goods and BoE gear up after Keystone & Crests; Collector moves the collectibles", function()
		local display = { "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_collect", "c_other" }
		assert.same({ "c_keystone", "c_tradegoods", "c_boe", "c_collect", "c_consumables", "c_gear", "c_other" },
			QS.Order(display, { gold = true, collector = true }))
		assert.is_nil(QS.Order(display, { mplus = true }))
	end)

	it("Apply with nothing picked asks for a pick and stays open", function()
		login()
		Fake.Fire(QS.applyButton, "OnClick")
		assert.truthy(QS.IsOpen())
		assert.equal(SB.L.QS_PICK_FIRST, QS.frame.status.text)
		assert.equal(false, SB.Config.Get("setup.done"))
	end)

	-- Mutation: remove `C.Set("setup.done", true)` from Apply.
	it("Apply sets each picked style's preset and the slots per row, says what it did, and closes", function()
		login()
		pick("mplus")
		pick("gold")
		Fake.Fire(QS.columnButtons[14], "OnClick")
		bags.open = true
		Fake.Fire(QS.applyButton, "OnClick")
		assert.falsy(QS.IsOpen())
		assert.equal(true, SB.Config.Get("setup.done"))
		assert.equal(14, SB.Config.Get("bags.columns"))
		assert.equal(true, SB.Config.Get("prices.headerTotals"))
		assert.same({ "c_keystone", "c_tradegoods", "c_boe" },
			{ SB.Config.db.categoryOrder[1], SB.Config.db.categoryOrder[2], SB.Config.db.categoryOrder[3] })
		assert.equal("c_tradegoods", SB.Categories.SectionOrder()[3], "the categories follow at once")
		assert.equal(1, bags.layouts, "the open bags regroup")
		assert.same({ "Set up for M+, Gold-making. Change anything later: type /swagbag." }, A.Lines())
	end)

	it("AC7.2: Skip keeps the defaults, says so, and closes", function()
		login()
		Fake.Fire(QS.skipButton, "OnClick")
		assert.falsy(QS.IsOpen())
		assert.equal(true, SB.Config.Get("setup.done"))
		assert.same({ SB.L.QS_SKIPPED }, A.Lines())
		assert.equal(12, SB.Config.Get("bags.columns"))
	end)

	-- Mutation: set setup.done in the OnHide handler.
	it("Esc or the X is \"later\": nothing is saved, it says so, and it shows at the next login", function()
		login()
		QS.frame:Hide()
		assert.same({ SB.L.QS_LATER }, A.Lines())
		assert.equal(false, SB.Config.Get("setup.done"))
		login()
		assert.truthy(QS.IsOpen())
	end)

	it("read-only settings: Apply and Skip refuse with the reason and change nothing", function()
		QS.Show()
		pick("raid")
		SB.Config.readOnly = true
		Fake.Fire(QS.applyButton, "OnClick")
		Fake.Fire(QS.skipButton, "OnClick")
		assert.same({ SB.L.SETTINGS_READONLY, SB.L.SETTINGS_READONLY }, A.Lines())
		assert.truthy(QS.IsOpen())
		assert.is_nil(SB.Config.db.settings.focus)
	end)

	it("AC7.4: /swagbag setup shows it again; /swagbag tour answers (P2)", function()
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.IsOpen())
		SB.Slash.Dispatch("tour")
		assert.same({ SB.L.QS_OPENED, SB.L.TOUR_LATER }, A.Lines())
	end)

	it("a picked style shows as picked; a second click unpicks it", function()
		QS.Show()
		pick("raid")
		assert.equal("|cff44ff44Raid|r", QS.styleButtons.raid.text)
		pick("raid")
		assert.equal("Raid", QS.styleButtons.raid.text)
	end)

	it("only plain frames", function()
		for _, f in ipairs(Fake.created) do
			assert.truthy(f.kind == "Frame" or f.kind == "Button", f.kind)
		end
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/quicksetup_spec.lua`
Expected: `0 passed, 12 failed`, each with `cannot open SwagBag/UI/QuickSetup.lua: No such file or directory`.

Critical tests and their mutations (in `SwagBag/UI/QuickSetup.lua`):

| Test | Mutation |
|---|---|
| "presets: M+ and Raid switch things on; Casual alone switches the warning and the track off" | `if picked.casual and not picked.mplus and not picked.raid then` → `if picked.casual then` |
| "Apply sets each picked style's preset and the slots per row, says what it did, and closes" | delete `C.Set("setup.done", true)` in `Apply` |
| "Esc or the X is \"later\": nothing is saved, it says so, and it shows at the next login" | in the OnHide handler, add `SB.Config.Set("setup.done", true)` after `SB.Print(L.QS_LATER)` |
| "read-only settings: Apply and Skip refuse with the reason and change nothing" | delete the `if C.readOnly then return L.SETTINGS_READONLY end` lines in `Apply` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Config.lua`, find:

```lua
		consumables = { warn = true },
	},
```

and replace it with:

```lua
		consumables = { warn = true },
		-- done: the quick setup screen was applied or skipped (UI/QuickSetup.lua); account-wide,
		-- like the settings it sets, so it shows once per account, not once per character.
		setup = { done = false },
	},
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SET_WATCH_CHECKED = "Checked: the result is in chat."

-- In-game check V1 (optional)
```

and replace it with:

```lua
L.SET_WATCH_CHECKED = "Checked: the result is in chat."

-- Quick setup (spec 12.1; the full wizard and the tour are November)
L.QS_TITLE = "Welcome to SwagBag"
L.QS_INTRO = "What do you play? Pick any. You can change everything later: type /swagbag."
L.QS_HINT = "Apply sets SwagBag up for what you picked. Skip keeps SwagBag's defaults."
L.QS_MPLUS = "M+"
L.QS_RAID = "Raid"
L.QS_GOLD = "Gold-making"
L.QS_CASUAL = "Casual"
L.QS_COLLECTOR = "Collector"
L.QS_STYLE_ON = "|cff44ff44%s|r"
L.QS_APPLY = "Apply"
L.QS_SKIP = "Skip (use defaults)"
L.QS_PICK_FIRST = "Pick at least one of the buttons first, or press Skip."
L.QS_APPLIED = "Set up for %s. Change anything later: type /swagbag."
L.QS_SKIPPED = "SwagBag keeps its defaults. Type /swagbag to change anything, or /swagbag setup to see this screen again."
L.QS_LATER = "Quick setup closed without changes; it opens again at your next login, or type /swagbag setup."
L.QS_OPENED = "Quick setup opened."
L.HELP_SETUP = "setup: show the quick setup screen again"
L.HELP_TOUR = "tour: the guided tour (arrives in November)"
L.TOUR_LATER = "The guided tour arrives with the full setup wizard in November. Until then, /swagbag help lists every command."

-- In-game check V1 (optional)
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/SettingsConsumables.lua
UI/DebugV1.lua
```

and replace it with:

```text
UI/SettingsConsumables.lua
UI/QuickSetup.lua
UI/DebugV1.lua
```

Create `SwagBag/UI/QuickSetup.lua`:

```lua
-- SwagBag quick setup (spec 12.1: "a one-screen quick setup (playstyle -> preset)"; the full
-- four-step wizard and the tour are November, F7). Shown once, a few seconds after the first
-- login with this build, on any character (settings are account-wide). /swagbag setup shows it
-- again (AC7.4); /swagbag tour says when the tour arrives.
--   Pick any of M+, Raid, Gold-making, Casual, Collector, and the slots per row, then:
--   Apply  sets each picked style's preset and says what it did
--   Skip   keeps SwagBag's defaults and says so (AC7.2)
--   Esc / the X  "later": nothing is saved; it opens again at the next login, and says so
-- Presets only switch things ON for the chosen styles (every focus mode is on by default) and
-- move categories up; Casual (without M+ or Raid) is the one that switches two things off.
-- All writes refuse while the settings are read-only (a newer schema), with that reason.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local QS = { picked = {}, columns = 12, styleButtons = {}, columnButtons = {}, DELAY = 3 }
SB.QuickSetup = QS

QS.STYLES = {
	{ id = "mplus", name = "QS_MPLUS" }, { id = "raid", name = "QS_RAID" }, { id = "gold", name = "QS_GOLD" },
	{ id = "casual", name = "QS_CASUAL" }, { id = "collector", name = "QS_COLLECTOR" },
}
QS.COLUMNS = { 10, 12, 14 }

-- Categories a style moves up, right after Keystone & Crests (spec 7.6: "Gold promotes Trade
-- Goods and BoE gear").
local PROMOTE = { gold = { "c_tradegoods", "c_boe" }, collector = { "c_collect" } }

-- Pure: the settings each style sets, given everything picked. Returns { { path, value } }.
function QS.Preset(picked)
	local out = {}
	local function set(path, value)
		out[#out + 1] = { path, value }
	end
	if picked.mplus then
		set("focus.on.mplus", true)
		set("consumables.warn", true)
		set("overlays.keystone", true)
		set("overlays.track", true)
	end
	if picked.raid then
		set("focus.on.raid", true)
		set("consumables.warn", true)
		set("overlays.upgrade", true)
	end
	if picked.gold then
		set("prices.headerTotals", true)
	end
	if picked.casual and not picked.mplus and not picked.raid then
		set("consumables.warn", false)
		set("overlays.track", false)
	end
	return out
end

-- Pure: the category display order with the picked styles' categories moved up.
function QS.Order(display, picked)
	local up = {}
	for _, s in ipairs(QS.STYLES) do
		for _, id in ipairs(picked[s.id] and PROMOTE[s.id] or {}) do
			up[#up + 1] = id
		end
	end
	if #up == 0 then
		return nil
	end
	local moved, out = {}, {}
	for _, id in ipairs(up) do
		moved[id] = true
	end
	for _, id in ipairs(display) do
		if not moved[id] then
			out[#out + 1] = id
			if id == "c_keystone" then
				for _, u in ipairs(up) do
					out[#out + 1] = u
				end
			end
		end
	end
	return out
end

local function names(picked)
	local out = {}
	for _, s in ipairs(QS.STYLES) do
		if picked[s.id] then
			out[#out + 1] = L[s.name]
		end
	end
	return out
end

-- The open windows follow at once.
local function refresh()
	SB.Categories.Load()
	if SB.Focus then
		SB.Focus.Refresh("settings")
	end
	SB.Emit("SB_PRICES_CHANGED")
	if SB.Overlays then
		SB.Overlays.context = nil
		SB.Overlays.RefreshAll()
	end
	local W = SB.BagsWindow
	if W and W.IsOpen() then
		W.RequestLayout("setup")
		W.RefreshTitle()
	end
end

-- Apply the picked styles. Returns the feedback line.
function QS.Apply()
	local C = SB.Config
	local list = names(QS.picked)
	if #list == 0 then
		return L.QS_PICK_FIRST
	end
	if C.readOnly then
		return L.SETTINGS_READONLY
	end
	for _, p in ipairs(QS.Preset(QS.picked)) do
		C.Set(p[1], p[2])
	end
	C.Set("bags.columns", QS.columns)
	local display = {}
	for _, c in ipairs(SB.Categories.display) do
		display[#display + 1] = c.id
	end
	local order = QS.Order(display, QS.picked)
	if order then
		C.db.categoryOrder = order
	end
	C.Set("setup.done", true)
	refresh()
	QS.Close("done")
	return L.QS_APPLIED:format(table.concat(list, ", "))
end

function QS.Skip()
	if not SB.Config.Set("setup.done", true) then
		return L.SETTINGS_READONLY
	end
	QS.Close("done")
	return L.QS_SKIPPED
end

---------------------------------------------------------------------------
-- The screen (plain frames only; it can open in combat)
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "SwagBagQuickSetup", UIParent, "BackdropTemplate")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(560, 250)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
frame:Hide()
QS.frame = frame
table.insert(UISpecialFrames, "SwagBagQuickSetup")

frame:SetScript("OnDragStart", Guard("setup.dragStart", function()
	frame:StartMoving()
end, "none"))
frame:SetScript("OnDragStop", Guard("setup.dragStop", function()
	frame:StopMovingOrSizing()
end, "none"))

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOPLEFT", 14, -12)
frame.title:SetText(L.QS_TITLE)
frame.intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.intro:SetPoint("TOPLEFT", 14, -40)
frame.intro:SetText(L.QS_INTRO)
frame.columnsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.columnsLabel:SetPoint("TOPLEFT", 14, -110)
frame.columnsLabel:SetText(L.SET_COLUMNS)
frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.status:SetPoint("BOTTOMLEFT", 14, 44)
frame.status:SetText(L.QS_HINT)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local function paint()
	for _, s in ipairs(QS.STYLES) do
		local b = QS.styleButtons[s.id]
		local on = QS.picked[s.id] == true
		b:SetText(on and L.QS_STYLE_ON:format(L[s.name]) or L[s.name])
		if on then
			b:LockHighlight()
		else
			b:UnlockHighlight()
		end
	end
	for n, b in pairs(QS.columnButtons) do
		if n == QS.columns then
			b:LockHighlight()
		else
			b:UnlockHighlight()
		end
	end
end
QS.Paint = paint

for i, s in ipairs(QS.STYLES) do
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(100, 24)
	b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * 106, -70)
	b:SetScript("OnClick", Guard("setup.style", function()
		QS.picked[s.id] = not QS.picked[s.id] or nil
		paint()
	end, "none"))
	QS.styleButtons[s.id] = b
end

for i, n in ipairs(QS.COLUMNS) do
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(56, 22)
	b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * 60, -130)
	b:SetText(tostring(n))
	b:SetScript("OnClick", Guard("setup.columns", function()
		QS.columns = n
		paint()
	end, "none"))
	QS.columnButtons[n] = b
end

-- Apply / Skip answer in chat (P2); a refusal also shows on the screen, which stays open.
local function finish(fn)
	local feedback = fn()
	SB.Print(feedback)
	frame.status:SetText(feedback)
end

QS.applyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
QS.applyButton:SetSize(120, 24)
QS.applyButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
QS.applyButton:SetText(L.QS_APPLY)
QS.applyButton:SetScript("OnClick", Guard("setup.apply", function()
	finish(QS.Apply)
end, "none"))
QS.skipButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
QS.skipButton:SetSize(160, 24)
QS.skipButton:SetPoint("RIGHT", QS.applyButton, "LEFT", -8, 0)
QS.skipButton:SetText(L.QS_SKIP)
QS.skipButton:SetScript("OnClick", Guard("setup.skip", function()
	finish(QS.Skip)
end, "none"))

-- Closing without Apply or Skip (Esc, the X) is "later": it says when the screen comes back.
-- The OnHide guard comes first (Alt+Z hides UIParent while this frame stays shown).
frame:SetScript("OnHide", Guard("setup.hide", function(self)
	if self:IsShown() then
		return
	end
	if QS.closing ~= "done" then
		SB.Print(L.QS_LATER)
	end
	QS.closing = nil
end, "none"))

function QS.Close(how)
	QS.closing = how
	frame:Hide()
end

function QS.Show()
	QS.picked, QS.columns = {}, SB.Config.Get("bags.columns")
	frame.status:SetText(L.QS_HINT)
	paint()
	frame:Show()
end

function QS.IsOpen()
	return frame:IsShown()
end

-- First login with this build: show it a few seconds after the loading screen, unless the
-- settings are read-only or the bags are in Safe Mode (then the bags are Blizzard's anyway).
SB.On("SB_LOGIN", function()
	if SB.Config.Get("setup.done") or SB.Config.readOnly then
		return
	end
	SB.Debounce("setup.show", QS.DELAY, function()
		if not SB.SafeMode.IsOn("bags") and not SB.Config.Get("setup.done") then
			QS.Show()
		end
	end, "none")
end, "none")

SB.Slash.Register("setup", L.HELP_SETUP, function()
	QS.Show()
	return L.QS_OPENED
end)

SB.Slash.Register("tour", L.HELP_TOUR, function()
	return L.TOUR_LATER
end)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/quicksetup_spec.lua`
Expected: `12 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (52 files)`, `844 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: In-game session Q1** (full restart, because this task adds a file).

- [ ] **Step 7: Commit**

```bash
git add "spec/quicksetup_spec.lua" "SwagBag/Core/Config.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc" "SwagBag/UI/QuickSetup.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 9: one-screen quick setup (playstyle presets), /swagbag setup and /swagbag tour

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 10: Week-3 carry-overs (GroupView held layout, guild header drag, logout traps, view-toggle tests)

Four items from the week-3 ledger touch code week 4 owns or tests (see "Week-3 carry-overs"):
1. **Held full layout.** `GroupView.RequestLayout` re-read every slot of the bank or guild bank every 300 ms while it was held. Now it remembers the button that held it. While that button is still under the mouse, or an item is still on the cursor, a retry only re-arms. Once it is free, the layout is computed again and checked again (W3-38 unchanged).
2. **Guild header drag.** A drag onto a guild bank section header set the 0.3 s drop guard although the guild view takes no drops, so the next click was swallowed. Without `cfg.onDrop`, a drop sets no guard.
3. **Logout writes.** `PLAYER_LOGOUT` ran every snapshot write in one trap, so an error in one lost the rest. Each write (pending kinds, pending guilds, an open bank, the warband, the bags) now has its own `ErrorTrap.Run`.
4. **Final review M8.** Tests for the bags and guild bank view toggles with read-only settings. The code was fixed in week 3's final wave without tests; these pin it.

The fifth carry-over, the bags `Restack` redrawing every cell, is done in Task 3.

**Files:**
- Modify: `SwagBag/UI/GroupView.lua`, `SwagBag/Engine/Snapshots.lua`
- Test: `spec/groupview_spec.lua`, `spec/guildbank_spec.lua`, `spec/snapshots_spec.lua`, `spec/bagswindow_sections_spec.lua`

**Interfaces:**
- Consumes (on `aa3fea1`): `GroupView` internals (`busyCheck`, `build`, `positionAll`, `commit`), `Snapshots` internals (`store`, `storeGuild`, `pending`, `pendingGuild`).
- Produces: `v.heldKey` (internal). No new public names.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua`, find:

```lua
	end)

	it("a read-only config refuses the drop with its reason and keeps the item on the cursor", function()
```

and replace it with:

```lua
	end)

	-- Week-3 carry-over (final review M8). Mutation: ignore SB.Config.Set's result in W.SetView.
	it("the view toggle with read-only settings says so and changes nothing", function()
		W.Open()
		local text, reason = W.viewButton.text, W.stats.lastLayoutReason
		SB.Config.readOnly = true
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal(SB.L.SETTINGS_READONLY, W.frame.title.text)
		assert.equal("sections", SB.Config.Get("bags.view"))
		assert.equal(text, W.viewButton.text)
		assert.equal(reason, W.stats.lastLayoutReason)
	end)

	it("a read-only config refuses the drop with its reason and keeps the item on the cursor", function()
```

In `spec/groupview_spec.lua`, find:

```lua
	end)

	it("W3-38: the mouse over the items but over no button that would move does not hold a full layout", function()
```

and replace it with:

```lua
	end)

	-- Week-3 carry-over. Mutation: drop the v.heldKey re-check in v.RequestLayout (every retry
	-- reads every slot again).
	it("a held full layout re-arms without reading the slots again while the same button stays busy", function()
		v.Layout("open")
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = 1 } })
		btn(6, 1).mouseOver = true
		local reads = 0
		local describe = f.cfg.describe
		f.cfg.describe = function(...)
			reads = reads + 1
			return describe(...)
		end
		assert.falsy(v.RequestLayout("sort"))
		local first = reads
		assert.truthy(first > 0, "the first request reads the slots once")
		A.Advance(0.3)
		A.Advance(0.3)
		A.Advance(0.3)
		assert.equal(first, reads, "three retries under the same button: no reads")
		btn(6, 1).mouseOver = false
		A.Advance(0.3)
		assert.equal("sort", v.stats.lastLayoutReason)
	end)

	it("W3-38: the mouse over the items but over no button that would move does not hold a full layout", function()
```

In `spec/guildbank_spec.lua`, find:

```lua
		assert.truthy(header("tab1:c_herbs").text.text:find("+", 1, true), header("tab1:c_herbs").text.text)
	end)
end)
```

and replace it with:

```lua
		assert.truthy(header("tab1:c_herbs").text.text:find("+", 1, true), header("tab1:c_herbs").text.text)
	end)

	-- Week-3 carry-over. Mutation: drop `cfg.onDrop and` from GroupView's owner.onDrop.
	it("a drag onto a guild section header does not swallow the next click", function()
		openVault()
		answerQueries()
		local h = header("tab1:c_herbs")
		h.scripts.OnReceiveDrag(h)
		h.scripts.OnClick(h, "LeftButton")
		assert.truthy(GW.view.Collapsed("tab1").c_herbs)
	end)

	-- Week-3 carry-over (final review M8). Mutation: ignore SB.Config.Set's result in GW.ToggleView.
	it("the view toggle with read-only settings says so and changes nothing", function()
		openVault()
		answerQueries()
		local text, reason = GW.viewButton.text, GW.view.stats.lastLayoutReason
		SB.Config.readOnly = true
		Fake.Fire(GW.viewButton, "OnClick")
		assert.equal(SB.L.SETTINGS_READONLY, GW.frame.title.text)
		assert.equal("sections", SB.Config.Get("guildBank.view"))
		assert.equal(text, GW.viewButton.text)
		assert.equal(reason, GW.view.stats.lastLayoutReason)
	end)
end)
```

In `spec/snapshots_spec.lua`, find:

```lua
	end)

	it("W3-28: a guild save queued in combat is written at logout", function()
```

and replace it with:

```lua
	end)

	-- Week-3 carry-over. Mutation: run every logout write inside one ErrorTrap.Run (the old code).
	it("an error in one logout write is recorded and the others are still written", function()
		SB.Inventory.ScanAll()
		bankVisit()
		local ids = A.GetBagIDs
		A.GetBagIDs = function(kind)
			if kind == "warband" then
				error("warband broke")
			end
			return ids(kind)
		end
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		assert.equal("item:" .. Fixtures.HERB, Snap.Deserialize(me().bank.containers[6])[2].link)
		assert.truthy(me().bags, "the bags are still written after the warband failed")
		assert.equal("snapshot.logout.warband", SB.ErrorTrap.Recent()[1].label)
	end)

	it("W3-28: a guild save queued in combat is written at logout", function()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/groupview_spec.lua spec/guildbank_spec.lua spec/snapshots_spec.lua`
Expected: `213 passed, 3 failed`. The failures are "a held full layout re-arms without reading the slots again while the same button stays busy", "a drag onto a guild section header does not swallow the next click" and "an error in one logout write is recorded and the others are still written". The two view-toggle tests pass already: they pin the week-3 final-wave fix.

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "a held full layout re-arms without reading the slots again while the same button stays busy" | `GroupView.lua`: delete the `if not held and v.heldKey then … end` re-check |
| "a drag onto a guild section header does not swallow the next click" | `GroupView.lua`: `if sid and cfg.onDrop and dropGuard ~= id then` → `if sid and dropGuard ~= id then` |
| "the view toggle with read-only settings says so and changes nothing" (`guildbank_spec`) | `GuildBankWindow.lua`: ignore `SB.Config.Set`'s result in `GW.ToggleView` |
| "the view toggle with read-only settings says so and changes nothing" (`bagswindow_sections_spec`) | `BagsWindow.lua`: ignore `SB.Config.Set`'s result in `W.SetView` |
| "an error in one logout write is recorded and the others are still written" | `Snapshots.lua`: `capture(kind)` calls `store(kind, Snap.Capture(kind))` without its own `Run` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Engine/Snapshots.lua`, find:

```lua
-- what was captured in combat and is still waiting (W3-28), then a visit still open, then bags.
-- store and storeGuild refuse a newer schema themselves.
SB.On("PLAYER_LOGOUT", function()
	for kind, snap in pairs(pending) do
		pending[kind] = nil
		store(kind, snap)
	end
	for key, ser in pairs(pendingGuild) do
		pendingGuild[key] = nil
		storeGuild(key, ser)
	end
	if bankOpen then
		store("bank", Snap.Capture("bank"))
		store("warband", Snap.Capture("warband"))
	end
	store("bags", Snap.Capture("bags"))
end, "none")
```

and replace it with:

```lua
-- what was captured in combat and is still waiting (W3-28), then a visit still open, then bags.
-- store and storeGuild refuse a newer schema themselves. Each write has its own trap, so an
-- error in one (recorded for /swagbag report) never costs the others.
SB.On("PLAYER_LOGOUT", function()
	local Run = SB.ErrorTrap.Run
	for kind, snap in pairs(pending) do
		pending[kind] = nil
		Run("snapshot.logout." .. kind, "none", store, kind, snap)
	end
	for key, ser in pairs(pendingGuild) do
		pendingGuild[key] = nil
		Run("snapshot.logout.guild", "none", storeGuild, key, ser)
	end
	local function capture(kind)
		Run("snapshot.logout." .. kind, "none", function()
			store(kind, Snap.Capture(kind))
		end)
	end
	if bankOpen then
		capture("bank")
		capture("warband")
	end
	capture("bags")
end, "none")
```

In `SwagBag/UI/GroupView.lua` (edit 1 of 3), find:

```lua
	end

	function owner.onDrop(id)
		local _, sid = parseId(id)
		if sid and dropGuard ~= id then
			drop(id)
```

and replace it with:

```lua
	end

	-- A view with no onDrop (the guild bank) takes no drops, so a drag onto its header sets no
	-- guard: the click that follows is a plain click (it used to be swallowed for 0.3 s).
	function owner.onDrop(id)
		local _, sid = parseId(id)
		if sid and cfg.onDrop and dropGuard ~= id then
			drop(id)
```

In `SwagBag/UI/GroupView.lua` (edit 2 of 3), find:

```lua
	-- is under the mouse -- the same guard as a redraw or a re-stack (W3-38, spec 4.2 rule 5).
	function v.RequestLayout(reason)
		if not v.pos then
			return false
		end
		local t0 = SB.Adapter.ProfileMs()
		local held = SB.Adapter.CursorItem() ~= nil
		local b, pos
		if not held then
			b = build()
			pos = positionAll(b.groups, b.records)
			held = anyBusy(SB.Layout.Moves(v.pos, pos))
		end
		if held then
			SB.Debounce(cfg.key .. ".layout", GV.RETRY, function()
				v.RequestLayout(reason)
			end, window)
			return false
		end
		commit(b, pos, reason, t0)
```

and replace it with:

```lua
	-- is under the mouse -- the same guard as a redraw or a re-stack (W3-38, spec 4.2 rule 5).
	-- While the button that held it is still under the mouse, a retry only re-arms: it does not
	-- read every slot again (week-3 final review), so a held layout costs nothing while it waits.
	function v.RequestLayout(reason)
		if not v.pos then
			return false
		end
		local t0 = SB.Adapter.ProfileMs()
		local busy, held = busyCheck()
		if not held and v.heldKey then
			held = busy(math.floor(v.heldKey / 1000), v.heldKey % 1000)
		end
		local b, pos
		if not held then
			b = build()
			pos = positionAll(b.groups, b.records)
			v.heldKey = nil
			for _, k in ipairs(SB.Layout.Moves(v.pos, pos)) do
				if busy(math.floor(k / 1000), k % 1000) then
					v.heldKey, held = k, true
					break
				end
			end
		end
		if held then
			SB.Debounce(cfg.key .. ".layout", GV.RETRY, function()
				v.RequestLayout(reason)
			end, window)
			return false
		end
		v.heldKey = nil
		commit(b, pos, reason, t0)
```

In `SwagBag/UI/GroupView.lua` (edit 3 of 3), find:

```lua
		end
		v.groups, v.byId, v.pos, v.cells, v.redrawPending = {}, {}, nil, {}, false
		SB.Buttons.ReleasePlaceholders(cfg.child)
```

and replace it with:

```lua
		end
		v.groups, v.byId, v.pos, v.cells, v.redrawPending, v.heldKey = {}, {}, nil, {}, false, nil
		SB.Buttons.ReleasePlaceholders(cfg.child)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_sections_spec.lua spec/groupview_spec.lua spec/guildbank_spec.lua spec/snapshots_spec.lua`
Expected: `216 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (52 files)`, `849 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: In-game session W1** (`/reload` is enough if you restarted for session Q1; otherwise a full restart).

- [ ] **Step 7: Commit**

```bash
git add "spec/bagswindow_sections_spec.lua" "spec/groupview_spec.lua" "spec/guildbank_spec.lua" "spec/snapshots_spec.lua" "SwagBag/Engine/Snapshots.lua" "SwagBag/UI/GroupView.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 4 Task 10: week-3 carry-overs (held layout re-arms, guild header drag, logout traps, view-toggle tests)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---

## In-game sessions

**If anything goes wrong at any point,** type `/swagbag report`, press Ctrl+C, and paste the result to Claude. Each session ends with a reply line for Claude. A step marked "(note it)" asks for something the code cannot check on its own: say what you saw.

Session order: FM1 and DR1 (after Task 4), K1 (after Task 5), S1 (after Task 8), Q1 (after Task 9), W1 (after Task 10).

Note on the title: with the item level on (the default), the title is `SwagBag — <mode> — ilvl <number>`. A long title may end in `...`; only its start matters below.

### Session FM1: focus modes in town, at the vendor and the bank, while fishing and gathering (after Task 4, about 15 minutes; checks V6 and V8)

You need:
- a vendor and a banker nearby;
- an item in Junk, or any gray item;
- for steps 18–20: a fishing pole and water (optional);
- for steps 21–23: a gathering profession and a node or a skinnable creature (optional).

1. Quit the game completely and start it again (new files). Log in. Expected: chat shows `SwagBag: v0.4.0 loaded. Type /swagbag help for commands.`
2. Press **B**. Expected: the bags open and the title starts with `SwagBag — ilvl`. The buttons at the top read, from left to right: `Sort`, `Pause`, `Reflow`, `Grid`. Keep the bags open for the whole session; if they close, press **B** again.
3. Click the `Junk` header. Expected: it reads `+ Junk (` and a number. This is your own choice, and SwagBag keeps it.
4. Right-click a vendor to open the vendor window. Expected:
   - the title starts with `SwagBag — AH/Vendor/Bank`;
   - `New`, `BoE gear`, `Trade Goods` and `Junk` start with `-` (those you have items in);
   - every other section header starts with `+`.
5. Close the vendor window. Expected: the title starts with `SwagBag — ilvl` again, and `Junk` is back to `+` (your choice from step 3).
6. Click the `Junk` header. Expected: it reads `- Junk (`.
7. Open the vendor window again. Rest the mouse on an item in `Junk` and keep it still.
8. With the mouse still on that item, walk away from the vendor with the keyboard until the vendor window closes. Expected:
   - the title starts with `SwagBag — ilvl`;
   - the item under your mouse does **not** move while the mouse stays on it.
9. Move the mouse off the item. Expected: within half a second the other sections open, and the Junk items move down together with their header.
10. Open the vendor window again. Click the `+ Consumables` header. Expected: it reads `- Consumables (`, a number, then `)  (peek - right-click keeps it open)`.
11. Press **B** twice (close and open the bags). Expected: `Consumables` reads `+ Consumables (` again (a peek ends when the bags close).
12. Right-click the `Consumables` header. Expected: it reads `- Consumables (`, a number, then `)  (kept open)`.
13. Press **B** twice. Expected: `Consumables` still ends in `(kept open)`.
14. Click `Pause`. Expected:
    - chat shows `SwagBag: Focus modes are paused for this session: sections stay as you set them. Click Resume, or type /swagbag mode resume.`;
    - the button now says `Resume`;
    - the title starts with `SwagBag — Paused`;
    - no section is collapsed (none starts with `+`).
15. Click `Resume`. Expected:
    - chat shows `SwagBag: Focus modes are back on: sections follow what you are doing again.`;
    - the title starts with `SwagBag — AH/Vendor/Bank`;
    - `Consumables` reads `+ Consumables (` (a resume starts the mode fresh).
16. Close the vendor window. Walk to a banker and open the bank. Expected:
    - the title starts with `SwagBag — AH/Vendor/Bank`;
    - every bags section is open (at the bank everything stays open);
    - the bank window looks exactly as it did last week.
17. Close the bank. Type `/swagbag mode list`. Expected: six chat lines, each with `- opens` and a list of sections. They start `SwagBag: M+: on`, `SwagBag: Raid: on`, `SwagBag: Delves: on`, `SwagBag: Gathering: on`, `SwagBag: Fishing: on` and `SwagBag: AH/Vendor/Bank: on`.
18. (Fishing, optional) Stand at water and cast Fishing once. Expected:
    - within a second the title starts with `SwagBag — Fishing`;
    - only `New`, `Fish & Lures` and `Cooking` start with `-` (the ones that have items).
19. Stop fishing, and stand still for 2 minutes.
20. Look at the title. Expected: it starts with `SwagBag — ilvl` again (about 90 seconds after your last cast).
21. (Gathering, optional) Gather one herb, ore or skin. Expected: the title starts with `SwagBag — Gathering`. Open sections: `New`, the materials of your gathering professions (`Herbs`, `Ore` and/or `Leather & Cloth`), and `Teleports & Tools`.
22. Wait 2 minutes. Expected: the title starts with `SwagBag — ilvl` again.
23. (Optional) Open a treasure chest. Expected: the title does **not** say `Gathering`.
24. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: Claude sees:
    - a `Focus:` line and a `Spells before loot (last 5):` line. The spell numbers let Claude add your gathering spells to the list;
    - no new errors;
    - `Blocked actions: none`.

Pass: steps 2–17 behave as described, and steps 18–23 for whatever you could try.
If step 18 or 21 shows no mode: tell Claude. The report's `Spells before loot` line gives the missing spell number (V6/V8 fallback: Claude adds it to `Engine/FocusData.lua`).

Reply to Claude with: FM1 done, and the numbers of any steps that didn't match

### Session DR1: delve and raid (after Task 4, about 5 minutes; check V7)

1. `/reload` is enough if you did FM1 since the last restart (otherwise quit and restart the game). Enter a delve. Press **B**. Expected: the title starts with `SwagBag — Delves`; only `New`, `Consumables` and `Gear` start with `-`.
2. Leave the delve. Expected: the title starts with `SwagBag — ilvl`, and your own sections are back.
3. Enter a raid (any difficulty). Press **B**. Expected: the title starts with `SwagBag — Raid`; only `New`, `Consumables` and `Gear` start with `-`.
4. Leave the raid. Expected: the title starts with `SwagBag — ilvl`.
5. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 1–4. If step 1 shows no `Delves`, tell Claude. The report's `Focus:` line says what the client reported, and the V7 fallback (the delve difficulty number) is then fixed.

Reply to Claude with: DR1 done, and the numbers of any steps that didn't match

### Session K1: a real Mythic+ key (after Task 5; checks V5 and V11)

You need: your keystone, a dungeon teleport you know ("Path of …"), and your usual consumables. To test the warning, carry fewer than 5 food or fewer than 5 potions (or no flask).

1. Quit the game completely and start it again (new file). Log in. Type `/swagbag consumables`. Expected: chat shows `SwagBag: Consumables warning on. Watching: Flask 1, Potions 5, Food 5`.
2. Type `/swagbag consumables check`. Expected: either `SwagBag: All watched consumables are stocked.`, or a line in the middle of the screen and in chat starting `Low:` (for example `SwagBag: Low: Food (2/5)`).
3. Cast your dungeon teleport. Expected: if something is low, one `Low:` line in the middle of the screen and in chat; nothing if everything is stocked. If step 2 said `Low:` but nothing shows here, tell Claude the teleport's name (note it).
4. Walk into the dungeon with your keystone, before starting it. Press **B**. Expected:
   - the title starts with `SwagBag — M+`;
   - only `New`, `Keystone & Crests`, `Consumables` and `Gear` start with `-`;
   - if something is low, one `Low:` line showed when you zoned in.

   If the title has no `M+`, tell Claude (V5).
5. Start the key. Expected: the title still starts with `SwagBag — M+`. If something is still low, the `Low:` line shows once more (starting the key checks again).
6. In combat during the key, press **B** to close the bags, then **B** to open them. Expected: they work, with no red error and no "blocked" message.
7. In combat, click a `+` header (for example `+ Junk`). Expected: it opens and ends in `(peek - right-click keeps it open)`. Move the mouse off it.
8. Finish the key and leave the dungeon. Expected: the title starts with `SwagBag — ilvl`, and your own sections are back.
9. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 1–8.

Reply to Claude with: K1 done, and the numbers of any steps that didn't match

### Session S1: the settings window (after Task 8, about 10 minutes)

1. Quit the game completely and start it again (new files). Log in. Type `/swagbag`. Expected: a window titled `SwagBag settings` opens at the `Bags` page, and chat shows `SwagBag: Settings opened.`
2. Look at the row `Free slots`. Expected: `One with the count` is highlighted, and `Every free slot` is right next to it.
3. Press **B** to open your bags. In the settings, click `14` under `Slots per row`. Expected: the line at the bottom of the settings says `Bags: 14 slots per row.` Move the mouse off the bags: they regroup 14 slots wide.
4. Click `12`. Expected: `Bags: 12 slots per row.`, and the bags go back.
5. Click `Focus modes` on the left. Expected: `Switch by themselves`, `Open both sets`, `Peeks`, `Quiet` and `All characters` are highlighted.
6. Scroll down to `Edit the sections of` and click `M+`. In the row `Junk`, click `Open`. Expected: the bottom line says `Junk now opens in the M+ mode.`
7. Click `Reset to default` (row `Back to SwagBag's choice for this mode`). Expected: `The M+ mode opens its default sections again.`
8. Scroll up and click `This character` (row `These focus settings are for`). Expected: `This character now has its own focus settings; the others keep theirs.`
9. Click `All characters`. Expected: `This character uses the account-wide focus settings again.`
10. Click `Consumables` on the left. Expected: rows `Flask: warn below 1`, `Potions: warn below 5` and `Food: warn below 5`.
11. Click `+` in the `Potions` row. Expected: the bottom line says `Potions: warns when you have fewer than 6.`, and the row reads `Potions: warn below 6`.
12. Click `-` in the `Potions` row. Expected: `Potions: warns when you have fewer than 5.`
13. In your bags, click a healing potion to pick it up. Click `Drop an item here`. Expected: the bottom line says `Now watching`, the potion's name, then `(warns below 1; use + to raise it).`; the potion goes back to its bag slot.
14. Click `Remove` in that potion's row. Expected: the potion's name, then `is no longer watched.`
15. Click `Check now`. Expected: the bottom line says `Checked: the result is in chat.`, and chat shows a `Low:` line or `SwagBag: All watched consumables are stocked.`
16. Click `Bank & guild` on the left. Expected: `Hidden`, `SwagBag's window`, `Selected tab` and `Show` are highlighted.
17. Press **Esc**. Expected: the settings window closes.
18. In the bags window, hover over `Pause` without clicking. Expected: a tooltip `Focus modes` with `Left-click: pause or resume for this session` and `Right-click: choose the sections this mode opens`.
19. Right-click `Pause`. Expected: the settings open at `Focus modes`, and the bottom line says `Editing the sections the M+ mode opens (below).` (in town no mode is active, so the page opens at the last mode you edited, M+).
20. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 1–19.

Reply to Claude with: S1 done, and the numbers of any steps that didn't match

### Session Q1: the quick setup screen (after Task 9, about 3 minutes)

1. Quit the game completely and start it again (new file). Log in and wait 3 seconds after the loading screen. Expected:
   - a window `Welcome to SwagBag` with `M+`, `Raid`, `Gold-making`, `Casual` and `Collector`;
   - `10`, `12` and `14` under `Slots per row`;
   - `Skip (use defaults)` and `Apply`.
2. Press **Esc**. Expected: chat shows `SwagBag: Quick setup closed without changes; it opens again at your next login, or type /swagbag setup.`
3. Type `/swagbag setup`. Expected: the window opens, and chat shows `SwagBag: Quick setup opened.`
4. Click `Apply` without picking anything. Expected: the window stays open and its bottom line says `Pick at least one of the buttons first, or press Skip.` (chat says the same).
5. Click `M+`. Expected: `M+` turns green.
6. Click `Apply`. Expected: chat shows `SwagBag: Set up for M+. Change anything later: type /swagbag.`, and the window closes.
7. Type `/swagbag tour`. Expected: chat shows `SwagBag: The guided tour arrives with the full setup wizard in November. Until then, /swagbag help lists every command.`
8. Type `/reload`. Wait 5 seconds. Expected: no quick setup window.
9. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors.

Pass: steps 1–8. (Gold-making moves Trade Goods and BoE gear up in your bags. Try it with `/swagbag setup` only if you want that order.)

Reply to Claude with: Q1 done, and the numbers of any steps that didn't match

### Session W1: guild bank header drag and the logout snapshot (after Task 10, about 3 minutes)

1. `/reload` is enough if you restarted for Q1 (otherwise quit and restart the game). Open the guild vault. Expected: SwagBag's guild bank window opens.
2. Press and hold the left mouse button on an item in a guild tab, move the mouse onto a section header of the guild bank window (for example `- Herbs (`), and let go. Expected: the item stays on your mouse cursor (the guild bank takes no drops on headers).
3. Click that same header at once. Expected: it collapses (`+`). If nothing happens, tell Claude.
4. Click the empty slot the item came from (the guild tab's grid). Expected: the item goes back. Move the mouse off it.
5. Leave the vault. Visit a banker and open the bank.
6. Type `/reload` while the bank is open. Then type `/swagbag snapshot`. Expected: chat shows `SwagBag: Bags: just now`, `SwagBag: Bank: just now` and `SwagBag: Warband bank: just now` (any of them may say `1 min ago`), then a `SwagBag: Saved:` line.
7. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 2–6.

Reply to Claude with: W1 done, and the numbers of any steps that didn't match

## Daily focus check (from Day 3, about 2 minutes; spec §12.2 week 4: "Modes switch correctly in real play")

At the end of each day's play, answer these and paste the report:

1. Which modes did you see today (M+, Raid, Delves, Gathering, Fishing, AH/Vendor/Bank)?
2. Did a mode ever switch on when it should not have (for example Gathering after opening a chest, or Fishing when you did not fish)? (yes/no; what were you doing)
3. Did a mode ever fail to switch on (a key with no `M+` in the title, a delve with no `Delves`)? (yes/no; where)
4. Did any item move while your mouse was on it? (yes/no; what were you doing)
5. Did the `Low:` warning show when you were low, and stay quiet when you were not? (yes/no)
6. After a mode ended, were your own collapsed sections as you left them? (yes/no)
7. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Claude checks for no new errors, `Blocked actions: none`, and the `Focus:` and `Spells before loot` lines.

Any "yes" to questions 2 or 4, and any "no" to questions 3, 5 or 6, is a bug report. Claude first reproduces it as a failing test in the owning spec file (`focus_spec`, `signals_spec`, `consumables_spec` or `bagswindow_sections_spec`), then fixes it.

## Week 4 exit check (spec §12.2 week 4: "Modes switch correctly in real play")

The user ticks these in game on Day 7 and pastes the final `/swagbag report` to Claude:

1. [ ] Sessions FM1, K1, S1, Q1 and W1 passed, or every failure was fixed and its step re-run. DR1 passed if you play delves or raids.
2. [ ] V5: at least two keys had `SwagBag — M+` in the title from entering the dungeon to leaving it.
3. [ ] V11: the `Low:` warning showed once when low (on teleport, entry or key start) and stayed quiet when stocked.
4. [ ] V6 and V8: fishing and gathering switched on within a second, and off within about 2 minutes. A chest never switched Gathering on (or you could not test it: say so).
5. [ ] V7: a delve showed `Delves` (or you did no delve: say so).
6. [ ] The daily focus check had no bug answers, or every one was fixed.
7. [ ] Claude ran `scripts/check.sh` on the branch: `ALL CHECKS PASSED`, with 849 or more passed and 0 failed. The branch is merged (or kept), as the user chooses.

If a line fails, paste the report, and Claude fixes it before week 5 starts. Any slip is reported at the end of the week (spec §12.2).

## What week 5 builds on

- `SB.Focus.MODES` is data. November's custom modes (AC8.7) add entries with `trigger` built from the same signals and `sections` stored under `focus.sections.<id>`. The settings page lists modes from `Focus.MODES`.
- `Signals.recent` and the report's `Spells before loot` line feed `Engine/FocusData.lua`. Confirmed IDs go into `ids`, and names stay as the backup.
- `SB.SettingsWindow.AddPage` takes more pages: the November rule builder, and the "Alt data" page with snapshot sizes (§8.4).
- `SB.QuickSetup.Preset/Order` are the first two steps of the November wizard (AC7.1); the wizard adds the layout and gold steps around them.
- Week 5 hardening (spec §12.2): the ledger's remaining minors (xpcall stack in `ScanKind`, the shared bank-window shell W3-8, tabs added mid-visit), and a perf pass over §9 and §6.5 with `/swagbag perf`.

## Spec coverage (week-4 scope → task)

| Week-4 item (spec, brief, settled decisions) | Task |
|---|---|
| §6.1 signal, mode, active set, merge (default) / strict priority, peek (default) / pin, pause with badge and resume | 1 (engine), 3 (window), 4 (peek, pin, pause) |
| §6.2 signals, feature-detected through the Adapter, stated fallbacks; gathering spell-ID allowlist (AC8.6) | 2 |
| §6.3 the six v1.0 modes, all ON by default (AC8.1), section sets editable with Reset to default | 1, 7 |
| §6.4 state machine: apply when visible, else store; clear peeks; announce (default off); W10; hover guard | 1, 3, 4 |
| §6.5 cost budget (handler, Recompute, Apply touches only moved buttons; no polling) | 1, 2, 3 (tests) |
| §6.6 / F11 warning: key start, Mythic dungeon entry, teleport; on screen and chat; once per 60 s per trigger; editable list (AC11.2) | 5, 8 |
| AC8.2 within one event cycle; leaving restores | 3 |
| AC8.3 peek / pin / "Keep open until mode changes" | 1, 4, 7 |
| AC8.4 merge / strict priority | 1, 7 |
| AC8.5 mode in the title, editing from the window | 3 (title), 7 (right-click → settings) |
| AC8.7 custom modes | November (D13) |
| F15 / AC15.1 account-wide with per-character focus override; AC15.2 default + alternative everywhere | 6, 7, 8 |
| §12.1 one-screen quick setup (playstyle → preset); AC7.2 Skip; AC7.4 `/swagbag setup` | 9 |
| §10.5 `/swagbag` opens settings; `setup`, `tour`, `mode [pause|resume|list]` | 4, 6, 9 |
| §11.3 V5, V6, V7, V8, V11 | 2 (unit), sessions FM1, DR1, K1 |
| §13.1 report lists last spells before loot | 2 |
| Week-3 ledger carry-overs | 3, 10 |

## How this plan was checked (while writing it)

- **Replay.** Every code block of Tasks 1–10 was extracted from this file and applied in order to a fresh clone of `aa3fea1` in a scratch folder outside the repo. For each task:
  - the Step 1 blocks were applied alone, and Step 2's `Expected` line is that red run;
  - then Step 3's blocks were applied; Step 4's run and `scripts/check.sh` gave the totals above (718 → 849 passed, 0 failed) and `ALL CHECKS PASSED`;
  - the final tree matched the reference build file for file.
- **Anchors.** Every find block occurs exactly once in its file at the point it is applied, starts and ends on a non-blank line, and was found by the replay. No step replaces a whole file.
- **Mutations.** Every mutation in the "Critical tests" tables was applied to the finished code of its task, and the named test failed: 50 runs.
- **Rules grep** on the final tree:
  - no `C_`/`Enum` outside `Core/Adapter.lua`, comments included;
  - no `OnUpdate` script, no forbidden token, no `SetCurrentGuildBankTab`;
  - the new UI files create only `Frame`, `Button` and `ScrollFrame` frames.
- **Name check.** Every `SB.*` name a task uses exists on `aa3fea1`, in an earlier task's **Produces** block, or in the same task.
- **Placeholder scan.** No TBD, TODO or "similar to". Every step that changes code shows the code.
- **Review Focus.** Each of the five lines names the tests that pin it, in the tasks that own the code.
