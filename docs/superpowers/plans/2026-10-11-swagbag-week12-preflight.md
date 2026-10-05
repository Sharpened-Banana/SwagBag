# Week 12 preflight: replayed on the new base 65b6985 (hotfix 0.11.1)

Plan: `docs/superpowers/plans/2026-10-11-swagbag-week12-wizard-tour-modes.md` (written and replayed on 8503e06, 1614 tests).
Base now: `65b6985` (hotfix 0.11.1, 1633 tests). Scratch replay: `/tmp/w12pf/base` (fresh clone, one commit per task),
driven by a script that reads the plan file (find/replace, Create, Replace the whole of), runs the suite after Step 1
and Step 3, runs `scripts/check.sh`, then applies every listed mutation to that task's finished code and runs the suite.
The five briefs are byte-for-byte the plan's task sections (checked line by line), so everything below holds for both.

Hotfix 0.11.1 changed only `Core/Adapter.lua`, `Engine/Inventory.lua`, `Core/Init.lua` and `SwagBag.toc` (version),
the spec's AC3.3 and some specs and fixtures. Week 12 touches none of those files except the version lines.

## 1. Replay summary

| Task | Find blocks | Red (Step 2): plan / actual | FAIL list | Green (Step 4/5): plan / actual | TOC | check.sh | Mutations killed |
|---|---|---|---|---|---|---|---|
| T1 | 6 of 6 ops; **2 MISMATCH (0 matches)**: `Core/Init.lua` `SB.VERSION = "0.11.0"` and `SwagBag.toc` `## Version: 0.11.0` (both are 0.11.1 now). Applied by hand as 0.11.1 -> 0.12.0 | 1614/13 -> **1633/13** | identical (13 names) | 1627 -> **1646** | 80 | ALL CHECKS PASSED | 14/14 |
| T2 | 14 + 4 ops, all exactly once (QuickSetup.lua whole file) | 1620/11 -> **1639/11** | identical (11 names) | 1631 -> **1650** | 80 | ALL CHECKS PASSED | 8/8 |
| T3 | 3 + 10 ops, all exactly once (7 QuickSetup edits on T2's file) | 1631/11 -> **1650/11** | identical (11 names) | 1642 -> **1661** | 81 | ALL CHECKS PASSED | 10/10 |
| T4 | 1 + 17 ops, all exactly once | 1642/13 -> **1661/13** | identical (13 names) | 1655 -> **1674** | 81 | ALL CHECKS PASSED | 13/13 |
| T5 | 1 + 14 ops, all exactly once | 1655/8 -> **1674/8** | identical (8 names) | 1663 -> **1682** | 81 | ALL CHECKS PASSED | 9/9 |

Every count is the plan's +19 (the hotfix's tests). Each Step 6 `git add` list equals the files the replayed task changed.
Tests with no mutation, as the plan says: T3 "every note's words are in enUS.lua; only plain frames" and T4's Recompute
timing test (guards, both assert something). No new spec needs `Fixtures.Settle` (none tests an item arriving).

Text to update before execution (plan and briefs): the two T1 version find blocks (0.11.0 -> 0.11.1); "Tests go from
1614 to 1663"; Global Constraints "cumulative from 1614"; Schedule totals; every Step 2/4/5 count above; "Branch ...
made from main at 8503e06", "The code at 8503e06 is the source of truth", "Everything else is as on 8503e06".

## 2. Cross-task rows (every pair sharing a file or an interface)

| Pair | Shared | Status |
|---|---|---|
| T1-T2 | `SB.Setup` (`STYLES`, `New`, `Toggle`, `Value`, `Set`, `Switches`, `Label`, `Finish`, `Skip`) produced by T1, drawn by T2; `QS.Preset/Order/Apply/Skip` move into Setup (no file still calls them); `QS_APPLIED`, `QS_REFRESH_NOTE`, `QS_SKIPPED(_KEPT)` move to Setup.lua; enUS (separate blocks); `spec/quicksetup_spec.lua` loads `Engine/Setup.lua` | OK. Stale comment: `spec/quicksetup_spec.lua:127` still says "Mutation: in QS.Apply" (now `Setup.Finish`) (defect 9) |
| T1-T3 | TOC (Setup after Profiles; Tour after QuickSetup: separate blocks); enUS; `finish(Setup.Finish, true)` shows the offer | OK |
| T1-T4 | `Focus.MODES/byId` read by `Setup.Switches/Label`; T4 keeps both unchanged, so step 2 lists built-ins only (by design, V0 simple) | OK |
| T1-T5 | Profiles `KEEP.setup` keeps `setup.styles` out of profiles and share strings; `Profiles.CategoriesChanged` called by Finish; T5 edits only Export's answer and Preview's lowered line | OK |
| T2-T3 | `UI/QuickSetup.lua` (whole file, then 7 edits: all match once); `spec/quicksetup_spec.lua` (13 then 2 edits); `/swagbag tour` moves from QS to Tour (between T2 and T3 the old "arrives in November" slash stays; one registration at the end); both listen to `PLAYER_REGEN_DISABLED` (wizard + offer in QS, the note in Tour): at most one line each, never both for one window | OK |
| T2-T4 | enUS only; the wizard writes `focus.on.<built-in>` through `Config.Set`, T4 adds `focus.on.m_*` beside them | OK |
| T2-T5 | enUS only; Settings > Focus modes and step 2 both switch `focus.on.*` (same paths) | OK |
| T3-T4 | enUS; `PLAYER_REGEN_DISABLED` (Tour) vs Focus (no new event); the tour reads `W.modeButton` only | OK |
| T3-T5 | enUS only | OK |
| T4-T5 | Focus API (`All`, `Mode`, `IsCustom`, `NameOf`, `ManualOn`, `TRIGGERS`, `CheckName`, `CreateMode`, `RenameMode`, `SetTrigger`, `DeleteMode`, `SetManual`, `CustomNames`, `MAX_NAME`); whys -> `SET_CUSTOM_WHY_*` (all 8 non-readonly/unknown keys exist, `rawget`-guarded); `SF.Paths` uses `All()`; Make mode adds the char override; Profiles export uses `CustomNames`; `Categories.Delete` (T4) cleans `m_*` sections | Seam defect: a manual mode whose `focus.on` is false can be "switched on" but never applies (defect 3) |
| Signals | `Engine/Signals.lua` unchanged; triggers are one table lookup on `Focus.signals`; Recompute only on signal change | OK |
| Config paths | `setup.styles` (default `""`, under KEEP), `SwagBagDB.modes` (top-level, kept by `upgrade` at schema 2), `focus.on/sections.m_*` (not in Defaults, so not known paths: never exported or imported) | OK; profile Load/Reset/Undo replace them (defect 5) |
| Locale keys | no duplicate `L.X =` after all five tasks; removed keys (`QS_APPLY`, `QS_HINT`, `QS_PICK_FIRST`, `TOUR_LATER`) have no reader left | OK |

## 3. Per-task internal consistency

| Task | Notes |
|---|---|
| T1 | Plan writes preset keys explicitly and touched keys only when they differ. Finish refuses read-only before any write. `Setup.Order` is the week-4 algorithm, unchanged. Clicking 50g then Off on step 4 still writes `prices.worthGold = 50` (defect 6, harmless). |
| T2 | Week 4-11 behaviour kept: Pause note (week 6), presets (now via Setup), W4-6 error line, W4-21 combat/instance wait, Esc "later" / "later, kept", read-only refusal, `Profiles.CategoriesChanged`. Intended changes: 16 slots per row added; Finish with no style allowed (`WIZ_DONE_NONE`, replaces `QS_PICK_FIRST`). Combat-hidden wizard returns after combat even inside an instance (defect 4). |
| T3 | Calls only `W.IsOpen` / `W.Open`; ring takes no mouse; `End` clears `step` before `Hide`, so Esc/close/combat say one line. Offer shown after Finish even in Safe Mode (defect 7). |
| T4 | Ids `m_<slug>[_n]`, tombstones `false`; `CreateMode` writes `on = true`, `sections = ""` directly into `db.settings.focus` (not `Config.Set`), then emits `focus.modes` -> Refresh. `SetTrigger` never touches `focus.on` (defect 3). `LoadCustom` accepts duplicate or built-in names from a hand-edited save (defect 10). |
| T5 | Every page click but Delete's forgets the question (`forgetting`). A manual mode's list row is the session switch; its stored `focus.on` is not shown anywhere (defect 3). |

## 4. Reviewer-defect patterns (on the replayed final tree)

- Tests asserting nothing: none (the smallest new tests have 1-2 asserts and a real check).
- Duplicated logic: the dialog backdrop setup is repeated in QuickSetup (wizard, offer) and Tour (about 6 lines each): cosmetic. No duplicated rules logic (QS's Preset/Order moved, not copied).
- Forbidden tokens (`BankFrame:SetTab`, `.bankType =`, `CloseBankFrame(`, `PurchaseBankTab`, `OpenAllBags(`, `PreClick`, `PostClick`): none (check.sh and grep).
- Adapter-only names, comments included: no `C_*`, `Enum.`, `TSM_API`, `LibStub`, `ElvUI`, `Syndicator` in new lines ("Auctionator"/"TSM" appear only as user text in enUS, as before).
- No `OnUpdate`, `loadstring`, `load(`, `RunScript`, `setfenv` added. No change to `UI/BagsWindow.lua`, `UI/SectionHeaders.lua`, `UI/SearchBox.lua`, `Core/Adapter.lua`, `Engine/Signals.lua`, `Engine/Inventory.lua`.

## 5. Safety and UX (non-coder M+ player)

| Risk | Finding |
|---|---|
| Returning user re-shown the wizard | Safe: `SB_LOGIN` and `TryShow` both check `setup.done` (account-wide, KEEP-protected from profile Load/Reset); test + mutation pin it. |
| Wizard in combat / in a key | Never opens by itself in combat or an instance (W4-21). But once open and hidden by combat it comes back after combat **wherever the player is**, including inside a key, and does so after every pull (defect 4). |
| Tour in combat / in a key | Refused in combat; ends at once on combat with one line; plain frames only. Allowed in a key out of combat (user's choice). |
| Tour opening the bags (D11) | Safe: `W.Open` is exactly what pressing B does (Safe Mode and "buttons not made" refuse); it lays out once, as an open always does. |
| Manual modes and reload (D15) | In memory only; the "on" answer says "until you switch it off, log out or reload". Pause holds it and the answer says paused. Clear. |
| Name collisions | Built-in names and ids (any case), other modes (any case), chat codes, >24 bytes refused; `/swagbag mode on raid` finds the built-in and answers "switches by itself". Damaged saves can still hold duplicates (defect 10). |
| Mode -> deleted category | `Categories.Delete` cleans `m_*` sections, account and this character (tested). |
| Trigger signals in combat | No new event; one lookup per mode; re-stack via `SB_FOCUS_CHANGED` and the existing guard, as a built-in mode. |
| QuickSetup whole-file replacement | Nothing from weeks 4-11 lost (see T2 row). |
| Finish writes only explicit values | Yes (preset keys + changed keys); one transient-touch nit (defect 6). |
| 0.11.1 New/settle | No overlap: Finish's re-order and the tour's open are ordinary layouts; the settle lives in Inventory flushes, and New does not depend on category order. Skip calls no layout at all. |

## 6. Defects and conflicts

1. **(Blocking for T1)** Version find blocks `0.11.0` match 0 times. Change both T1 find blocks (plan and task-1-brief) to `0.11.1`.
2. **(Text)** All counts +19 and the base is 65b6985 (section 1 list). Update plan, Global Constraints and briefs.
3. **(Medium, P2)** A mode made with a signal trigger, switched Off in the mode list, then changed to "Only when I switch it on": `/swagbag mode on` and the Settings line say it is on, but `Focus.Active` also needs `IsEnabled`, so nothing happens and nothing shows the stored Off. Probed: `SetManual -> true, true`, `ManualOn -> true`, `#Active() == 0`. Fix: for manual-class modes skip `IsEnabled` in `Focus.Active` (the session switch is the switch), or have `SetTrigger(id, "manual")` write `focus.on.<id> = true` (account and char override). Add a test with a mutation.
4. **(Medium-low, V0)** Combat-hidden wizard re-shows on `PLAYER_REGEN_ENABLED` even inside an instance, after every pull. Fix: when combat ends inside an instance, keep the draft and wait (reuse `QS.waiting` with a "resume" flag, shown on `PLAYER_ENTERING_WORLD` outside), or say once "type /swagbag setup to go on" and have `Show` resume the kept draft. Add a test.
5. **(Low-medium, accepted limit)** Profile Load / Reset / Undo replace `db.settings` whole, so a mode of your own keeps its name but loses its sections (probed: 2 sections -> 0 after loading an older profile). Self-review 6 states it, but it is not in the Decisions table, the Review Focus or session WZ1. Either carry live `m_*` switches and sections across `replace()` when the incoming settings lack them, or name it in D13 and in the Load answer.
6. **(Low)** Step 4: 50g then Off writes `worthGold = 50` with the glow off. Write `worthGold` only when the planned `prices.worth` is `fixed`, or accept.
7. **(Low)** The tour offer appears after Finish while the bags are in Safe Mode, and "Show me around" then refuses. Skip the offer when `SafeMode.IsOn("bags")`.
8. **(Low, clarity)** The offer comes after every Finish, re-runs included (D12 says "once"; self-review says "once per Finish"). Align D12's wording.
9. **(Low)** Stale comment `spec/quicksetup_spec.lua:127` ("in QS.Apply") -> `Setup.Finish`.
10. **(Low)** `LoadCustom` accepts stored modes with duplicate or built-in names (hand-edited saves only); `FindMode` then picks the first. Skip a name already taken while loading, or accept.
11. **(Spec)** §8.1 and §8.2 put the wizard-done flag in `SwagBagCharDB.ui.wizardDone` (per character); the code since week 4 and this plan use account-wide `settings.setup.done`. Add to "Spec updates at week end".
12. **(Spec)** AC8.4 still says strict priority is "combat > activity > location"; the plan adds `manual` first but updates only AC8.7. Amend AC8.4 too.
13. **(Spec)** AC11.2 "the wizard seeds [the watch list] per role" is neither done nor listed as deferred. Add it to Carry-overs (deferred) or the spec updates.
14. **(Spec)** §679 "the wizard and settings UI remind the user with 'Saved on logout/reload' the first time": the wizard does not. Defer explicitly or add the words to the Finish line.
