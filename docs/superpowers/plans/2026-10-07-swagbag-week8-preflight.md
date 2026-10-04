# Week 8 pre-flight: docs/superpowers/plans/2026-10-07-swagbag-week8-carryovers.md

Read-only scan on 2026-10-03. Repo untouched (branch week8 at 22c7381, which adds only the plan file to ab9d5a2).

## Replay (fresh clone of ab9d5a2 under /tmp/w8pf)

A script parsed every `In `path` ... find / and replace it with` and `Create` block in each task's Step 1 and Step 3 and applied them in order. Every find block occurred exactly once.

| Task | Edits (tests / code) | Step 2 red (actual) | Plan | Step 4 green | check.sh |
|---|---|---|---|---|---|
| T1 | 7 / 59 | 1394 passed, 10 failed, names identical | same | 1404 | ALL CHECKS PASSED, TOC OK (72 files) |
| T2 | 2 / 17 | 1404 / 6, identical | same | 1410 | PASSED |
| T3 | 1 / 7 | 1410 / 3, identical | same | 1413 | PASSED |
| T4 | 2 / 4 | 1414 / 2, identical (1 new test green at red, as stated) | same | 1416 | PASSED |
| T5 | 3 / 10 | 1416 / 4, identical | same | 1420 | PASSED |
| T6 | 4 / 11 | 1419 / 4, identical (edited week-7 test green at red, as stated) | same | 1423 | PASSED |
| T7 | 1 / 7 | 1423 / 1, identical | same | 1424 | PASSED |

- All 37 listed mutations were applied to their own task's commit. Every one made its named test fail.
- The files each task changed match its Files section and its Step 6 `git add` list exactly.
- Each brief (`task-N-brief.md`) is identical to its plan section.
- The final diff has none of the forbidden tokens, no `C_*`/`Enum.` outside the Adapter (comments included), no new other-addon globals outside the Adapter, no `OnUpdate`, and no `SetParent`/`SetID`/`SetScript`/`HookScript` on slot buttons. `UI/ListRows.lua` loads before BankWindow and GuildBankWindow in the TOC (line 64), so `BW.rows` and `GW.rows` exist in game.
- The VP1 steps 12–13 preview and import were simulated: the preview lines and "Imported 1 changes" match the session text.

Extra probe mutations (not in the plan) that **survive** (1424 still green): see findings 2–5.

## 1. Pairs of tasks that share a file or interface

| Pair | Shared | Produces → consumes | Verdict |
|---|---|---|---|
| T1 → T2 | GroupView cfg `rows`/`onListFailed`/`family`/`freeTile(view)`; `v.drawn`, `v.RowWidth`, `v.RefreshRows`, `v.SetDimmed`; `GV.LIST_*`; `ListRows.New(...opts)`, `ColumnBar`, `SortedText`; `SB_LIST_SORTED`; `Sort.Save` | T1 defines all of these; T2's GuildBankWindow uses them with the same names and signatures | consistent |
| T1 → T2 | `spec/helpers/uienv.lua` (T1 adds ListRows to the guild loader for T2) | T1 edit 2 → `Env.LoadGuild` in guildbank_list_spec | consistent |
| T1 / T2 | `Engine/Profiles.lua` VALID (adjacent lines 72/73), `Locale/enUS.lua` (BANK_* vs GUILD_*/LIST_GUILD_*), `spec/profiles_spec.lua` (same anchor region) | distinct find blocks, each unique in order | consistent |
| T1 / T2 | config `bags.list.sort`/`bags.list.desc` (one shared order); `bank.view` (T1) and `guildBank.view` (T2) gain `"list"` | Sort.Save writes these keys and emits `SB_LIST_SORTED`; bags, bank and guild listeners consume it | consistent |
| T1 → T3 | GroupView `RequestLayout` / `busyCheck` (now including `rows.IsMouseOver`) used by T3's `"loaded"` regroup | T3 relies on T1's P5 hold | consistent in code; **safety gap, see finding 1** |
| T2 → T3 | `UI/GuildBankWindow.lua` (T3 adds `recordOf`/`GW.pending` to T2's describe and Refresh; its OnHide edit sits next to T2's `scaleWarned` reset) | applied cleanly in order | consistent |
| T1 → T4 | GroupView `commit` now runs `scaleAll(b, 1)` for every window, including the alt viewer's DisplayButtons (no `rows`, so `"list"` is drawn as sections); OfflineWindow uses `GV.RETRY` | consumed unchanged | consistent |
| T3 / T4 | the same ITEM_DATA / Debounce pattern (`guild.loaded` vs `offline.loaded`/`offline.source`) | separate keys and labels | consistent |
| T1/T2 → T5 | `Overlays.Apply` is called from GroupView's build/describe (bank and guild draw paths), which T5 changes to the cached `Protected(r, true)` | the draw path gets cheaper; the sell path is unchanged | consistent |
| T5 / T6 | `Locale/enUS.lua` (VENDOR_KEEPS vs LOCK_*_ONE, PROFILE_PREVIEW_LOWERED); `spec/vendor_spec.lua` (T5 adds tests, T6 edits the Unlock-all expectations) | separate blocks | consistent |
| T1 / T6 | `Engine/Profiles.lua` (VALID vs escapeCode/Parse/Preview), `spec/profiles_spec.lua` | separate blocks | consistent |
| T2 / T6 | as T1 / T6 | — | consistent |
| T1 → T7 | `UI/BankWindow.lua`: T7 emits `SB_BANK_CHANGED` in T1's `BW.Layout`, the GroupView `onUpdated` and the Inventory handler; `spec/bankwindow_groups_spec.lua` loads through T1's changed `Env.LoadBank` | the list's held layouts also reach the top-% line | consistent |
| T5 / T7 | `UI/Overlays.lua` (Context `protected` vs `IsWorth` and the `SB_BANK_CHANGED` listener) | separate blocks | consistent |
| T2 / T7 | the guild window is not in the top-% values; `Ov.RefreshAll` redraws it | — | consistent (cost: finding 11) |
| All | test counts 1394→1404→1410→1413→1416→1420→1423→1424 (+10 +6 +3 +3 +4 +3 +1) | the Schedule, each Step 2/4/5 and Global Constraints agree; the replay reproduces them | consistent |
| All | P6 labels: `bank.listColumn`/`guild.listColumn` "bank"; `guild.loaded` "bank"; `SB_LIST_SORTED` bank/guild "bank", bags "bags"; `bank.listScale`/`guild.listScale`, the Syndicator hook, `ADDON_LOADED`, `offline.source` and the Overlays' `SB_BANK_CHANGED` all "none" | as in Global Constraints | consistent |

## 2. Each task against itself

| Task | Tests vs code | Files / commit list | Red / green | Mutation comments vs Step 2 | Verdict |
|---|---|---|---|---|---|
| T1 | 9 new tests + 1 profiles test; the bags-list edits change comments only (as stated) | match | 10 red → 1404 | match | consistent; test gaps: findings 3, 4 |
| T2 | 5 + 1 | match | 6 → 1410 | match (the test comment says "freeTile returns false", Step 2 says `view == false`: same effect) | consistent; the F6 test is weaker than T1's (finding 4) |
| T3 | 3 | match | 3 → 1413 | match | consistent; finding 1 |
| T4 | 3 (1 green at red, as stated) | match | 2 → 1416 | match | consistent; finding 10 |
| T5 | 4 | match | 4 → 1420 | match | consistent; test gaps: finding 2 |
| T6 | 3 new, 1 edited (green at red, as stated) + vendor Unlock-all edit | match | 4 → 1423 | match | consistent; findings 6, 7 |
| T7 | 1 | match | 1 → 1424 | match ("BAG_UPDATE handler" = the Inventory.OnChanged emit) | consistent; finding 11 |

## 3. What a reviewer would flag as a defect

- Forbidden tokens, the Adapter-only rule (including bare `C_*` in comments) and secure-button rules: clean (grep plus check.sh).
- Assertion-free tests: none. Each new test asserts. `overlays_spec` "cached form" checks only that the overlays pass the flag, through a fake Vendor; the caching itself is covered in vendor_spec.
- Untested branches (finding 2–5): the LookUnknown secret/missing-link protection, the F6 late-scale hide in `showAt`, the once-per-opening resets, the Uncollected gear secret guard, the alt viewer's cursor hold, the guild `success == false` guard, and the top-% "top only" guard.
- Duplicated code (finding 12): `BW.SortList` and `GW.SortList` are identical; the VIEW_NEXT/VIEW_BUTTON tables appear in three windows; `ListRows.ColumnBar` repeats the bags window's own bar; `GV.LIST_*` repeats `W.LIST_*`.

## 4. Safety and UX (non-coder M+ / gold-maker)

- **Secure bank buttons in the list:** only `SetScale` and `SetPoint` (offset / scale) are used. No reparenting, no `SetID`, no scripts or hooks, and none are created for the list (pinned by the strict-log combat test). F6 scales every button before drawing and falls back to categories. Rows start to the right of the icon at the parent's frame level, so a row never covers a button; a click on a row's text only flashes. Deposit, withdraw and split are Blizzard's own clicks on the button. Hit rect: G2 / BL1 step 8. OK.
- **Wrong row on right-click:** OK by construction; in-game G2 checks it.
- **P5:** a row under the mouse holds its button (pinned). **Gap: an automatic regroup can slide a different item under a still mouse (finding 1).**
- **Guild relayout clearing placeholders:** D7 accepts it. The hole is in finding 1.
- **Syndicator mid-session:** callbacks are registered once (pinned); errors are trapped under "none"; AltData answers from one provider per call, so nothing is counted twice; the late hook announces, so the tooltip memos follow. One robustness gap in the alt viewer: finding 10.
- **Gray jewelry auto-sell:** only `INVTYPE_FINGER`/`NECK`/`TRINKET` with quality 0 change. Locks, equipment sets, learnables and the BoE-worth-more-at-auction rule still apply. Other unknown-look gray gear stays, and the sell path asks the client fresh before each sale (pinned). A secret link still protects, but that branch is now unpinned (finding 2). Low risk to valuables.
- **Priority clamp:** no Parse path can store 90 or more (every `priority` field goes through the branch; NaN and inf are rejected by `decode`). Surprises: finding 6. D14 wording: finding 7.
- **The `|cn` rule:** `|c[nN][%u_][%u%d_]*:` still refuses `|cnIQ4:` and `|cnGREEN_FONT_COLOR:`; lower-case words pass. OK.
- **Top-% cost:** debounced 0.1 s, bank only, and only for "top". Each burst still rebuilds every open window's overlays (finding 11). Nothing in it is protected, so combat is not a concern.

## 5. Spec conflicts

The plan's own changes conflict with AC20.2 (refuse ≥90; any `|cn`), AC17.2 (jewelry; the cached draw path), §4.3 "Item data loads: stays in New" (the guild bank now regroups), §4.1 "Moves by SetPoint only" (SetScale) and §3.3/P4 "detected at load". **All of these are listed in "Spec updates at week end"**, so none is unplanned. Finding 1 runs against §4.2 rule 5 / P5 in spirit: nothing moves under the cursor.

## Findings (numbered)

1. **Important, safety (T3).** The `"loaded"` regroup is automatic, and its P5 hold covers only buttons under the mouse that would move. With the mouse resting on a placeholder, a ghost row or a gap, the full layout (which also clears placeholders, D7) can slide another guild item under the cursor. The next right-click then withdraws the wrong item, and guild withdrawals have daily limits. Fix: for `"loaded"`, also hold while the guild scroll frame is under the mouse (`scroll:IsMouseOver()`, as T4's `followSource` does). Add a test (mouse over a placeholder → held) and add that to GL1 step 10.
2. **Test gap, sell safety (T5).** In `Collections.LookUnknown`, `if not link then return true end` keeps gray gear with a secret or missing link. Mutating it to `false` survives. Add a vendor test: a gray robe whose link is secret is not sold.
3. **Test gap (T1).** The W5-1 branch in `showAt` (a button whose scale changes later is hidden, row and all, and a `"scale"` layout follows) is unpinned. Replacing it with `if false then` survives. Add a test.
4. **Test gap (T1, T2).** Resetting `BW.scaleWarned`/`GW.scaleWarned` on hide ("once per opening") is unpinned; deleting either reset survives. The T2 F6 test also does not assert the `guild.listScale` record or that Safe Mode stays off, as T1's does. Add a close/reopen assertion and those two asserts.
5. **Test gaps (minor).** These survive deletion: the `plain(r.link)` in `Uncollected`'s gear branch; `followSource`'s `CursorItem()` hold (P5); the guild `success == false` guard; the Overlays' `== "top"` guard; hiding a spare's row in `hideGone`. Add one assertion each, or accept them in the ledger.
6. **UX (T6).** The clamp also lowers edits of the four protected built-ins themselves. `ce.c_junk.priority=n90` drops Junk to 89, and the preview reads "Ranked just below Junk ...: Junk". The same happens to `c_sets` 92, `c_keystone` 95 and `c_reagents` 100. A repeated id is named twice ("A, A"). Fix: for `ce` edits of those four ids, ignore the priority field (or keep their default); dedupe `data.lowered`.
7. **Plan text (D14).** It says "The editor can raise it again" and also "No SwagBag UI sets a priority today". Reword the first.
8. **Note, pre-existing (week 7).** A share string can still lower a built-in, e.g. `ce.c_junk.priority=n-50`. This is display-only, because auto-sell is by quality, but AC20.2's "cannot outrank Junk ..." can be reached by demoting Junk instead. Log it in the ledger; not this week.
9. **Wording, P2 (T1, T2).** A ghost row says "...when you close the bank / guild bank", but its tooltip and click answer still use `L.PLACEHOLDER_TIP` ("...when you close the bag."), which D6 meant to avoid at a bank. Fix: `opts.goneTip`, or reuse `opts.gone` in `ghostTip`/`ghostClick`.
10. **Robustness (T4).** `followSource` compares `AltData.Source()` (the first active provider) with `OW.source` (the provider that answered `Characters()`). If they differ (Syndicator is active but its `characters()` returns nil or errors), every Syndicator update re-reads the viewer, which breaks "saves never redraw it". Fix: store and compare the same value.
11. **Cost (T7, T1).**
    - Every bank change in "top" mode runs `RefreshWorth` and a full `Ov.RefreshAll` over every open window, even when `worthMin` did not change. Fix: call `RefreshAll` only when the threshold moved.
    - After an F6 fallback, every later layout in the same opening re-scales all buttons and records another `*.listScale` error. Chat says it only once, but the error ring fills. Fix: remember the failure for the opening.
12. **Duplication (T1, T2).** `BW.SortList` and `GW.SortList` are identical; the VIEW_* tables are repeated in three windows; `ColumnBar` repeats the bags' bar; `GV.LIST_*` repeats `W.LIST_*`. Fix: a shared helper (e.g. `ListRows.SortBy(flash)`), or record it as deliberate.
13. **Constraint wording (T1).** "A list paints row texts only for slots it draws" is not literally true: `build()` computes texts (prices included) for every slot that has a button, spares and collapsed sections included; row frames are made only when placed. Reword the constraint, or paint lazily. Add to G9 that `/swagbag free all` plus the list on a full bank makes one row frame per empty slot.

Rows: 17 pair rows + 7 task rows. Every pairing is consistent, there are no unplanned spec conflicts, and the replay is clean. 1 important finding (1) and 12 minor ones.
