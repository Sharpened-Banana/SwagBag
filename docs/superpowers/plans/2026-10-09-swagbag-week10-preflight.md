# Week 10 preflight: lock warnings (plan d53173f, base 7ee3958)

Read-only scan. Nothing in the repo was changed except this file.

## Replay

I made a fresh clone of `7ee3958` at `/tmp/sb10pf`. A script read the plan file and, for each task, applied the Step 1 blocks, ran the suite, applied the Step 3 blocks, then ran the suite and `scripts/check.sh` and committed.

- Every find block matched exactly once: 36 code and test blocks, plus 2 Create steps.
- The five task briefs are byte-identical to the plan's task sections.
- Red/green results matched the plan exactly, including each failing test's name:

| Task | Step 2 (plan) | Step 2 (replay) | Step 4/5 (plan) | Step 4/5 (replay) | `git status` = Step 6 `git add` list |
|---|---|---|---|---|---|
| T1 | 1522 / 4 failed | 1522 / 4 failed, same 4 names | 1526 / 0, TOC 76, ALL CHECKS PASSED | same | yes (11 files) |
| T2 | 1526 / 4 | same, same names | 1530 / 0 | same | yes (6) |
| T3 | 1530 / 4 | same, same names | 1534 / 0 | same | yes (6) |
| T4 | 1533 / 4 (3 new + 1 existing) | same, same names | 1537 / 0 | same | yes (7) |
| T5 | 1537 / 6 | same, same names | 1543 / 0 | same | yes (4) |

**Mutations.** I applied all 26 listed mutations to their own task's replayed commit and ran the whole suite each time. Every mutation made its named test fail (26/26 killed). Each multi-edit mutation in T5 is killed only when all of its edits are applied, as the plan says.

## 1. Cross-task rows (shared files and interfaces)

| # | Pair | Shared file / interface | Verdict |
|---|---|---|---|
| X1 | T1–T2 | `UI/LockWarnings.lua`: T2's four edits anchor on T1's text (header, `local _, SB`, `LW = {}`, the end of `TooltipText`) | consistent |
| X2 | T1–T3 | `LW.TooltipText`: T3 adds the scrapper branch *after* the spell branch, and the T3 test pins that the spell line wins | consistent |
| X3 | T2–T3 | `LockWarnings.lua`: header comments, the `LW` table literal (`NOTE_*` then `scrapper`, `scrapWarned`), the anchor on the listener loop | consistent |
| X4 | T1–T4 | `Engine/Locks.lua`: T1 edits `TooltipLine`, T4 edits the `lock` command (separate regions) | consistent |
| X5 | T1–T2/T3/T4 | `locks.warn` and `LW.On()`: T1 adds the default and `LW.On`; T2 `OnDelete` and T3 `CheckScrapper` read it; T4's command, Settings row and report write or read it | consistent |
| X6 | T1–T4 | `SET_LOCK_WARN`: the Profiles `LABELS` entry (T1) and the Settings row label (T4) | consistent |
| X7 | T1–T4 | Profiles `VALID`: no entry (a boolean is checked by type); `LABELS` covered by the week-7 "every known setting has a label" test; no `locks` name collision with `SwagBagDB.locks` | consistent |
| X8 | T1–T2–T3 | `Core/Adapter.lua`: three inserts before the `"|cffRRGGBB"` comment anchor, and three `A.CHECKS` inserts before the `GameTooltip` row, giving 4 optional checks | consistent |
| X9 | T1–T2–T3 | `spec/mock_adapter.lua`: chained anchors (`SpellTargeting`, then `deletePopup`, then `scrapper`/`IsScrapper`) | consistent |
| X10 | T1–T2–T3 | `spec/adapter_spec.lua`: the T1 describe block, T2's luacheck-globals and `after_each` edits, T3's further globals | consistent (see D5) |
| X11 | T1–T4 | `spec/lockwarnings_spec.lua`: each task anchors on the previous task's final `end) end)` | consistent |
| X12 | T1–T4 | `Locale/enUS.lua`: chained anchors; every `L.KEY` added in the diff is defined; the LW1 quotes match the strings | consistent |
| X13 | T1–T5 | `Adapter.spellTargeting()` is shared by `A.SpellTargeting` (T1) and `A.CursorBusy` (week 9, T5's guards); the mock `cursorOther = "targeting"` drives both | consistent |
| X14 | T2–T5 | `CursorItem` vs `CursorBusy`: T2's delete flow needs the item ID (`CursorItem`); T5 keeps `CursorItem` for the item drops (`DropOnSection`, the header `onClick`, GroupView's header drop, LockButton, Settings drops) | consistent |
| X15 | T2–T4 | Delete-box note vs strings: `LOCK_WARN_STATE` and `SET_LOCK_WARN_TIP` (T4) describe the T2 behaviour accurately | consistent |
| X16 | T3–T4 | Scrapper events vs strings: `LOCK_WARN_ON` and `SET_LOCK_WARN_TIP` describe the T3 behaviour | consistent |
| X17 | T2–T3 | P6 labels: every new listener is `SB.On(..., "none")`; the timer is `Guard("lockwarn.note", ..., "none")` | consistent |
| X18 | T4 (internal) | Command, Settings row (`run("lock warn on/off")`) and status line, plus the existing vendor test gaining two buttons (the 4th red test) | consistent |
| X19 | T1–T5 | TOC and version: only T1 changes them (76 files, 0.10.0); `toc_check` passes after every task | consistent |
| X20 | T1–T5 | Test-count chain 1522 → 1526 → 1530 → 1534 → 1537 → 1543 | consistent |
| X21 | T5–(T1–T4) | No shared files (BagsWindow and GroupView only); independent | consistent |

## 2. Per-task internal consistency

| # | Task | Tests vs code, files, counts, commit list | Verdict |
|---|---|---|---|
| I1 | T1 | 4 tests. Both Adapter tests fail on missing functions and both LW tests on a missing file. 11 files, matching Files and Step 6. 5 mutations, all killed. | consistent |
| I2 | T2 | 4 tests. `Fake.Strict` uses a per-frame metatable, so `popup.log` is a real "no call on the box" assertion. 6 files. 6 mutations killed. | consistent |
| I3 | T3 | 4 tests. The adapter test fakes only the read call and checks slots 0–8 in order. 6 files. 6 mutations killed. | consistent |
| I4 | T4 | 3 new tests and 1 edited. 7 files. 3 mutations killed. The new vendor test's name says "On first and selected", but only the edited existing test checks that (D4). | consistent (nit) |
| I5 | T5 | 6 tests. 7 + 2 edits apply cleanly. 4 files. 6 mutations (two of them multi-edit) killed. Stale comments remain (D6). | consistent (nit) |

## 3. Reviewer-defect patterns

| # | Check | Result |
|---|---|---|
| R1 | Tests that assert nothing | none |
| R2 | Forbidden tokens (`BankFrame:SetTab`, `.bankType =`, `CloseBankFrame(`, `PurchaseBankTab`, `OpenAllBags(`, `PreClick`, `PostClick`) | none (check.sh passes; grep of the diff is clean) |
| R3 | Week-10 never-named list (`SpellStopTargeting`, `StaticPopupDialogs`, `RemoveItemToScrap`, `ScrapItems`, `DropPendingScrapItemFromCursor`, `CloseScrappingMachine`, `DeleteCursorItem`, `SetScript`/`HookScript`/`hooksecurefunc`, `OnUpdate`) in the new code | none |
| R4 | Adapter-only rule, comments included | every added `C_`/`Enum`/`StaticPopup_FindVisible` is in `Core/Adapter.lua`; LockWarnings comments name only `UseContainerItem` (allowed) |
| R5 | Duplicated logic | minor: `A.IsScrapper` copies the `A.IsGuildBanker` pattern; the on/off word is computed twice (Report, the lock command). Acceptable. |
| R6 | Lua 5.1, format51, no Config at load | clean (LockWarnings reads Config only at call time) |

## 4. Safety and taint

| # | Area | Finding |
|---|---|---|
| S1 | Blizzard delete box | SwagBag only reads it (`StaticPopup_FindVisible`, wrapped in `pcall`, four kinds) and makes no call on the box. The only link is `note:SetPoint("BOTTOM", popup, "TOP", 0, 4)` on SwagBag's own frame, which writes nothing into the box. No `StaticPopupDialogs` write, no button access. The Yes path (`DeleteCursorItem`) is untouched. Residual risk is in-game only (G3). Note edge cases in D2 and D3. |
| S2 | Scrapper | Read-only (`GetCurrentPendingScrapItemLocationByIndex` and `C_Item.GetItemID`, each wrapped in `pcall`, secret IDs skipped). No scrapper frame touched; no hook. Clean. |
| S3 | Tooltip hook | No new hook. The existing `TooltipDataProcessor` post-call keeps `countsTooltip` (GameTooltip and ItemRefTooltip only), the secret-ID skip and the `"none"` guard. The added text is a Locale string, never a secret value. Clean. |
| S4 | CursorBusy layout guards | They hold only while something is on the cursor or a spell waits for its target. That state ends on cast, Esc or a click, so nothing freezes indefinitely in any known client state. Held layouts retry every 0.3 s by timer (no `OnUpdate`), only while a window is open. Nothing is blocked that matters: repaints (identity) still run, and item drops still read `CursorItem`. In M+ combat, ground-target spells will briefly hold bag regroups; that is intended. |
| S5 | Combat | The note is a plain `CreateFrame("Frame")` made at first use, possibly in combat (weeks 6–9 allow this for plain frames; see D9 for the spec wording). `SetPoint` and `SetFrameStrata` on SwagBag's own unprotected frame are legal in combat. |
| S6 | P2 / P5 | One chat line per delete box. One per locked item landing in the scrapper (deduplicated across slots, reset on scrapper show/hide). The command answers exactly once in every form. The note moves no SwagBag button. |
| S7 | Plain-English strings | Fine overall. One wording edge is in D7. |
| S8 | Event cost | `CURSOR_CHANGED` is new to SwagBag and fires very often during normal play (see D1). |

## 5. Spec conflicts

| # | Spec text | Plan | Verdict |
|---|---|---|---|
| SP1 | §4.2 rule 5 ("while `GetCursorInfo()` holds an item" for layouts) | T5 widens it to `CursorBusy` for every bags/bank layout | intended change, already in "Spec updates at week end" |
| SP2 | §9 "Combat: no `CreateFrame`" | the note "may be created in combat" | wording conflict carried over from earlier weeks (plain frames have been allowed since week 6–7); see D9 |
| SP3 | §9 event policy ("PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE ... diagnostics only"; new events not listed) | T2/T3 add `DELETE_ITEM_CONFIRM`, `CURSOR_CHANGED`, `SCRAPPING_MACHINE_PENDING_ITEM_CHANGED` and scrapper SHOW/HIDE use | the week-end spec updates don't cover §9; see D10 |
| SP4 | §5.3 "tooltips hook OnEnter/OnLeave/OnUpdate only" | the existing `TooltipDataProcessor` post-call (since week 4) | carried over; the week-end §5.3 update could mention it |
| SP5 | F20 is Profiles / share strings | D3 cites "F20" for GameTooltip/ItemRefTooltip | wrong citation; see D8 |
| SP6 | F18 / AC18.x, §10.3–10.5, §8.2 | covered by the week-end updates | consistent |

## Numbered findings (none blocks execution)

- **D1 (low–med, perf).** T2 registers `CheckDelete` on `CURSOR_CHANGED`. That event fires on every cursor-shape change: mouseovers of units, NPCs and mobs, including M+ combat. Each fire goes through `ErrorTrap.Run` (an `xpcall`, two `pack` tables and a closure) only to return. It is redundant: No and Esc fire `ITEM_LOCK_CHANGED`, and Yes fires `BAG_UPDATE_DELAYED`. The Global Constraint also says "the four events above". **Fix:** drop `CURSOR_CHANGED` from the T2 loop, the constraints and the "What the week relies on" table. Or keep it and record why. No test depends on it.
- **D2 (low).** If Blizzard's box is hidden while the item stays on the cursor (a rare `StaticPopup_Hide` from elsewhere), the note floats with no box until the item leaves the cursor. **Fix (optional):** in `LW.CheckDelete`, also hide the note when `SB.Adapter.DeletePopup()` is nil (a read, only on these events). Or accept it under G4.
- **D3 (low).** When the delete box is not the top popup (for example StaticPopup2 under a group invite), the 300×24 note at DIALOG strata overlaps the bottom of the popup above it. It takes no mouse, but it can hide that popup's buttons. **Fix:** add "or any other box" to LW1 step 6's "covers" question, or accept.
- **D4 (nit).** The T4 vendor test "the destroy-warning row: On first and selected; ..." only clicks Off. "On first and selected" is pinned by the edited "defaults first" test. **Fix:** rename it to "the destroy-warning row's Off runs /swagbag lock warn off and says so", or add a check that the row's On is selected.
- **D5 (low, tests).** `adapter_spec`'s new `after_each` sets the globals `C_ScrappingMachineUI`, `C_Item`, `issecretvalue` and `Enum` to nil for the whole run. This extends the week-9 deferred item. The suite is green today, but it depends on order. **Fix:** save and restore the originals in `before_each`/`after_each`, or record it as deferred again.
- **D6 (nit).** After T5, several BagsWindow comments still say "an item on the cursor" or "a held item" next to code that now reads `CursorBusy`: `W.RequestLayout`, `anyBusy`, `W.Resize`'s header, the W4-25 "held item" note and `W.ApplyChanges`' W4-15 note. **Fix:** say "anything on the cursor (Adapter.CursorBusy)" in those comments.
- **D7 (low, wording).** While the scrapper is open, `LOCK_WARN_SCRAP` ("a right-click puts this item in it") shows on every locked item's tooltip. That includes items the scrapper can't take, the item already in a slot, and chat-link tooltips, where the sentence isn't true. **Fix:** change the wording to "a right-click can put this item in it", or accept it as covered by D2/D3's "any item" stance.
- **D8 (nit, doc).** D3 cites "F20" for the GameTooltip/ItemRefTooltip rule, but spec F20 is Profiles. **Fix:** cite `Adapter.HookItemTooltip` (the week-8 tooltip-counts rule, AC13.3).
- **D9 (spec, low).** §9 says "Combat: no `CreateFrame`", while the plan allows the plain note to be created in combat (weeks 6–9 precedent). **Fix:** add to "Spec updates at week end": §9 combat applies to secure/item buttons; plain frames may be created in combat. Or create the note out of combat at `SB_LOGIN`.
- **D10 (spec, low).** The §9 event policy doesn't list the new events and still calls PIM SHOW/HIDE "diagnostics only". **Fix:** add a §9 line to "Spec updates at week end".
- **D11 (nit).** `/swagbag lock warnon` is accepted as `lock warn on`, because of the pattern `^warn%s*(%a*)$`. **Fix:** use `arg == "warn"`, then `arg:match("^warn%s+(%a+)$")`. Harmless either way.
