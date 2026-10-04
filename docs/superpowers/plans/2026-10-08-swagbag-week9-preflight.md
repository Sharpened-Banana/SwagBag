# Pre-flight: week 9 (sort stacks, TSM, Masque, bag-addon warning, polish)

Plan: `docs/superpowers/plans/2026-10-08-swagbag-week9-sort-tsm-masque.md` (6 tasks, 1452 -> 1491). Briefs: `task-1..6-brief.md` here.
Scan: read-only, 2026-10-03. Spec: `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Controller ruling R0 (progress.md).

## 0. Replay (fresh clone of `ae00814` at `/tmp/pf9/repo`, script-applied find/replace and create blocks)

Every find block occurred exactly once. Step 2 / Step 4 / check.sh results, task by task, all equal the plan:
T1 `1452 passed, 11 failed` -> `1463/0`, `TOC OK (73 files)`, ALL CHECKS PASSED; T2 `1463/7` -> `1470/0` (73);
T3 `1470/9` -> `1479/0` (74); T4 `1479/7` -> `1486/0` (75); T5 `1485/3` -> `1488/0` (75); T6 `1488/3` -> `1491/0` (75).
FAIL lists match name by name. Each task's changed files equal its Step 6 `git add` list.
Spot-checked mutations (all made their named test fail): T1 MoveStack put-back removed; T2 bank `still()` -> `return true`.
check.sh's new rule: a `-- TSM_API` comment in `Providers/TSM.lua` and `local x = LibStub` in `UI/Skins.lua` each give `CHECKS FAILED`.
Briefs are verbatim copies of the plan's task sections (only a trailing `---` differs). **R0 is in none of them.**

Two behaviours were reproduced on the replayed tree with throwaway tests (deleted afterwards):
- a lone locked stack in the bags (nothing to stack): `Stacker.Start` returns true (`Stacking...`), then the run ends `why = "stuck"` with 0 moves;
- the bank-close test with bank slots unreadable after `BANKFRAME_CLOSED` (`GetSlot` -> nil for bags >= 6): the line is `Stacking stopped: an item did not move as expected ...`, not `... the window closed ...`.

## 1. Cross-task pairs (shared file or interface)

| # | Pair | Produces -> consumes | Verdict |
|---|---|---|---|
| X1 | T1 Stacker -> T2 windows | `Stacker.Start(job{kind,still,busy,done})`, `ResultText`, `DELAY/RETRY`, `L.STACK_*` -> `stackSort` in BagsWindow/BankWindow, T2 tests | consistent |
| X2 | T1 Stacker.lua -> T2 Stacker.lua | T2 inserts `/swagbag sort` before `function St.ResultText(r)` (unique) | consistent |
| X3 | T1 Stacker <-> Mover (T1) | `Mover.Start` refuses while `Stacker.Busy()`; `Stacker.Start` refuses while `Mover.Busy()` | consistent |
| X4 | T1 Mover change -> existing `Vendor.Visit` auto-sell | `Mover.Start` -> `false, "busy"` during a stacking run; `V.Visit` drops to repair only, no line | **conflict (P2), defect 6** |
| X5 | T1 `A.MoveStack` / `A.CursorItem` -> Stacker P5 | `CursorItem` sees only `kind == "item"` with a non-secret ID | **gap, defect 5** |
| X6 | T1 Stacker step order <-> T2 bank `still()` | `still()`/combat checked after the in-flight move's `progressed()` | **conflict with ST1 step 16, defect 4** |
| X7 | T1 Plan `pending` <-> any locked stack in scope | an unrelated locked stack makes Plan answer `{wait}` -> "stuck" | **defect 3** |
| X8 | T2 Sort buttons <-> week-2/3 Sort clicks | `bags.sortButton` / `bank.sortBank` / `bank.sortWarband` labels unchanged; combat refusal precedes `stackSort` | consistent |
| X9 | T2 `GroupView v.Busy` -> BankWindow stacker job | `busyCheck()` (cursor + button + list row) | consistent (bags use `buttonBusy` + Stacker's own cursor wait) |
| X10 | T2 GroupView (`v.Busy`) <-> T6 GroupView (`listFailed`) | different blocks | consistent |
| X11 | T1/T2 Adapter <-> T3/T4/T5 Adapter | anchors: SortBags (T1), `A.CHECKS` (T1), Syndicator header (T3 then T4, sequential), `return loaded, version` (T5) | consistent (order-dependent) |
| X12 | T3 `Prices.Value` honours `prices.source` -> `Vendor.worthMoreAtAuction` | D13: protection follows the choice; Vendor.lua unchanged | **conflict with R0 and AC17.2, defect 1** |
| X13 | T3 TSM provider -> `Prices` cache | nil answers cached 10 min (no TSM callback) | **risk, defect 2** |
| X14 | T3 Prices -> worth glow, header totals, list Value, `SectionHeaders` "vendor" mark | all ask `Value`/`Source()`; `Source() == "Vendor"` still right with TSM | consistent |
| X15 | T3 Prices -> `SectionActions.ConfirmSell` AH sentence | with "Vendor" chosen the Sell-all question loses its AH warning | note (R0 scope, defect 1) |
| X16 | T3 TSM provider -> T6 secret item ID | TSM `value(link)` returns nil for a non-string link; T6 nils a secret ID | consistent |
| X17 | T3 Settings TSM row -> `/swagbag price tsm X` | the row also sets `prices.source = "tsm"` | **UX conflict with its label, defect 7** |
| X18 | T2/T3/T6 SettingsPages | T2 bags row; T3 two rows before the bank note; T6 `worthChoices()` (built per Show, no Config at load) | consistent |
| X19 | T2/T3 Config + Profiles VALID/LABELS | `sort.mode`, `prices.source`, `prices.tsm` defaults, words, labels; label test covers | consistent; TSM words duplicated (defect 14) |
| X20 | T3/T4/T5 Report | `SourceText` Prices line; Masque line; Other-bag line + SB_LOGIN warning | consistent |
| X21 | T4 Skins <-> Buttons / GuildButtons / DisplayButtons | `Skins.Add(kind, b)` after `b:Hide()` in each factory | consistent |
| X22 | T4 Skins <-> ListRows | list icons are the slot buttons, scaled; no row code changed | consistent |
| X23 | T4 Masque <-> secure buttons | one `AddButton(b, nil, "Item")`, out of combat (deferred through `OutOfCombat`, deduped by label) | consistent; visual risk vs overlays (defect 20) |
| X24 | T4 Masque regions <-> SwagBag overlays | Masque Normal/Gloss vs `Overlays.lua` OVERLAY 6/7 (reagent, lock), star fontstring, slot bg BACKGROUND -7, gold/new glow | needs MQ1 look (G7) |
| X25 | T5 `A.OtherBagAddons` <-> `Report.ADDONS_IF_LOADED` | two lists of bag addon names | duplicated (defect 14) |
| X26 | T5 login warning <-> SafeMode | silent while `SafeMode.IsOn("bags")` | consistent; fires on every /reload too (defect 17) |
| X27 | T3 check.sh rule <-> T4 Adapter LibStub, T5 ElvUI | `TSM_API`/`LibStub` only in Adapter (verified); ElvUI named only in Adapter | consistent |
| X28 | Locale chain T1->T2->T3->T4->T5 | each task anchors on the previous task's last added line | consistent (tasks must run in order) |
| X29 | Locale keys | 39 new keys; all used in code, none duplicated; locale_spec green | consistent |
| X30 | Test files shared | adapter_spec (T1,T3,T4), mock_adapter (T1,T3,T4), stacker_spec (T1,T2), settings_spec (T2,T3,T6), profiles_spec (T2,T3), prices_spec (T3,T6), report_spec (T3,T4,T5) | consistent (replayed) |
| X31 | Counts / TOC | +11 +7 +9 +7 +2 +3 = 39; TOC 73/73/74/75/75/75; OptionalDeps line per task | consistent |

## 2. Per task

| Task | Internal consistency | Verdict |
|---|---|---|
| T1 | 11 red / 1463 green; 13 mutations; files = commit list. Nit: Stacker header says `Plan(kind, skip)`, interface `Plan(kind, skip, maxOf)`; `A.Stack` consumed but not listed. First `step(run)` runs inside the Sort click's trap, not "none" (defect 8). | consistent, with defects 3, 4, 5, 8 |
| T2 | 7 red / 1470; 8 mutations; files match. | consistent |
| T3 | 9 red / 1479; 12 mutations; files match. The vendor test is red only because `Providers/TSM.lua` is missing: the behaviour (Vendor.lua) is pre-existing and unchanged. "Consumes `worthMoreAtAuction` (unchanged)" contradicts R0. `SET_PRICE_SOURCE_TIP` says Vendor judges gray BoEs by the vendor price (contradicts R0). | **conflict (defect 1)**, defects 2, 7, 12, 13 |
| T4 | 7 red / 1486; 7 mutations; files match. Skins test "without Masque..." asserts `b.log` empty, which holds whatever Skins does (it never touches a button); its last `Sk.Add` is not checked against `asked`. | consistent; weak test (defect 15) |
| T5 | 3 red (one existing) / 1488; 5 mutations; files match. | consistent |
| T6 | 3 red / 1491; 3 mutations; files match. Held fallback rescales buttons that may be under the mouse (defect 11). | consistent |

## 3. Reviewer-defect patterns

| Pattern | Finding |
|---|---|
| Tests asserting nothing | T4 skins "without Masque" `b.log` check is vacuous (defect 15). Others assert real state. |
| Test green for the wrong reason | T3 vendor test (pre-existing behaviour; red only from a missing file). Under R0 it needs a companion test (defect 1). |
| Duplicated logic | TSM price strings in 4 places (`A.TSM_PRICES`, Profiles VALID, SettingsPages choices, `PRICE_STATE`/`PRICE_USAGE` text); bag addon names in 2 lists; `stackSort` near-duplicate in BagsWindow/BankWindow; Stacker step/finish mirrors Mover (accepted pattern). Defect 14. |
| Forbidden tokens | None added (`BankFrame:SetTab`, `.bankType =`, `CloseBankFrame(`, `PurchaseBankTab`, `OpenAllBags(`, `PreClick`, `PostClick`, `SetAttribute`, `SetID(`, `SetParent(` on slot buttons, `OnUpdate` code). Stacker's comment says "No OnUpdate" (not a check.sh token). |
| Adapter-only rule | No `C_`, `Enum.`, `TSM_API`, `LibStub`, `ElvUI[`, `_G[` outside the Adapter in new code or comments (grep of the replayed diff); check.sh enforces TSM_API/LibStub. |
| Stale comments | `Engine/Vendor.lua` lines 6, 50-51 still say "Auctionator prices" (fix with defect 1). |

## 4. Safety / UX (non-coder M+ player, gold-maker)

| Risk | Assessment |
|---|---|
| Item left on the cursor | `MoveStack` puts back, then `ClearCursor` (returns the item, never deletes). Safe, except a cursor `CursorItem` cannot see (defect 5). |
| Wrong bag / bank type | One scope per run from `GetBagIDs(kind)`; only same-link targets. Safe (pinned). |
| Delete / bad split | No delete or split call exists. A first pickup that silently fails (locked source) would pick the target up and drop it on the source: same item, same scope, caught by `progressed`. Safe. |
| Combat | Refused at Start; checked every step. Safe. |
| User holds an item | Waits forever while held (closing stops it). Merchant item / money / spell / secret ID on the cursor is not "held" to the stacker (defect 5). |
| Races with the user's clicks | Busy check per step on both slots (button and list row); plan re-read every step. Safe. |
| Races with Mover / auto-sell | Mutual refusal; auto-sell silently skipped for that visit (defect 6). |
| Bank closed mid-run | Stops, nothing queued; but the line may say "did not move as expected" (defect 4). |
| Unrelated locked stack (AH post slot, mail, trade) | False "Stacking..." then "stopped: did not move as expected" (defect 3) - likely for a TSM poster at the AH. |
| Server lag | `MAX_PENDING` 2 s, then "stuck" (nothing lost). Acceptable. |
| Same link, different bind state | Merge refused -> game swaps; counted as a merge, then stuck next step. Low (defect 22). |
| Masque on secure buttons | Out of combat, once, pcall'd; no reparent/attributes from SwagBag. Masque's own re-skins are texture work. Visual overlap with overlays is G7 (defect 20). Login cost: ~230 bag buttons plus bank buttons skinned at login (G4-like taste check). |
| TSM units / nil / errors / secrets | Copper, floored; pcall'd; secret link/value -> nil; non-number/negative -> nil. 0 is accepted as a price (defect 12). Nil answers cached 10 min (defect 2). |
| Profiles importing prices | Words checked; an imported `vendor` source silently drops the gray-BoE AH protection under D13 (fixed by R0, defect 1). |
| Bag-addon warning | No false positive for ElvUI with its bags off; prints at every /reload; only silencer is Safe Mode; UI suites with bag modules (KkthnxUI, NDui, GW2_UI, Tukui) not detected (defect 17). G8 folder names unverified. |
| R0 feasibility | Feasible: a choice-blind AH lookup in Prices (own cache), called by `worthMoreAtAuction`. Naive "Auctionator else TSM" would break T3's vendor test (Auctionator 150 < 2x100 while TSM 900): protect when **any** loaded AH source says > 2x. |

## 5. Spec conflicts

| Spec | Conflict |
|---|---|
| §1.3 Non-goals | "No TSM integration in v1.x" and "Prices come from Auctionator, else vendor price": Task 3 contradicts; not in "Spec updates at week end". |
| §2.3 Later | "TSM price source" listed as later; move it. |
| §1.4 P4 | names only Syndicator and Auctionator; add TSM, Masque. |
| F10 title / AC10.2 | "Auctionator integration", "Without Auctionator, totals use vendor price": generalise to the price source. |
| AC17.2 | "Never sold: a gray BoE worth more than twice its vendor price at auction": D13 drops this with "Vendor" chosen. R0 restores it; plan still says D13. |
| §4.2 rule 5 | Task 6 rescales (so moves) buttons while one may be under the mouse; plan records it only under F6. |

## Defects and suggested resolutions

1. **R0 not in the plan or Task 3 brief** (D13, `SET_PRICE_SOURCE_TIP`, Vendor.lua untouched, Self-review 6, spec-update line "D13 noted", Interfaces "(unchanged)"). Add `Prices.AuctionValue(link, itemID)` (ignores `prices.source`; asks every loaded non-Vendor provider; own cache cleared by `Invalidate`); `worthMoreAtAuction` protects when any AH answer > 2x vendor; new test "Vendor chosen: a gray BoE Auctionator prices > 2x stays; nothing loaded: it sells" (+1, totals shift); rewrite the tip's last sentence; update D13, Vendor.lua comments, AC17.2 note. Optionally the Sell-all AH sentence too.
2. **TSM nil cached 10 min** (TSM data may not be ready at first lookup): vendor values and, under D13, no gray-BoE protection. Do not cache a TSM miss (or cache misses briefly), or invalidate once shortly after login while TSM is available; ask in TS1.
3. **Unrelated locked stack -> false "stuck"** (reproduced). Exclude `isLocked` slots in `read()` like D6; wait only on the sent move's two slots; add a test.
4. **"stuck" instead of "closed" when the bank closes mid-run** if bank slots read nil after close (reproduced with that model). Check `still()` and combat at the top of `step`, before judging the in-flight move; add the nil-after-close variant to the bank test.
5. **Cursor check sees only items.** Merchant item, money, spell or a secret item ID on the cursor do not hold the stacker or `MoveStack`. Add `A.CursorBusy()` (any `GetCursorInfo()` answer) for the step wait, the `MoveStack` guard and the put-back.
6. **Auto-sell silently skipped** when a vendor opens during a stacking run (P2). Re-run `V.Visit` when the stacker finishes while the vendor is open, or print `L.MOVER_BUSY` once.
7. **Settings "TSM price (when TSM answers)" row switches the source to TSM.** Make the row set only `prices.tsm` (a separate subcommand), or relabel it; user decision.
8. **P6:** `St.Start` runs the first step synchronously under the Sort click's "bags"/"bank" trap. Run it through `ErrorTrap.Run("stacker.step", "none", step, run)`.
9. **Spec §1.3 / §2.3 / P4 / F10 conflicts** with TSM (and Masque). Add them to "Spec updates at week end".
10. (merged into 1) AC17.2 vs D13.
11. **§4.2 rule 5 vs Task 6** held-fallback rescale. Record the exception under §4.2 rule 5 as well.
12. **TSM 0 accepted as a price** (blocks the vendor fallback, shows 0). Use `v > 0`.
13. **`A.TSMPrice` depends on a prior `A.TSMAvailable()`** (module `tsmApi`). Resolve lazily (`tsmApi = tsmApi or tsm()`), important if R0 adds a second path.
14. **Duplicated lists**: build Profiles' `prices.tsm` words and the Settings choices from `A.TSM_PRICES`; share one bag-addon list; consider one `stackSort` helper.
15. **Weak Skins test**: assert `asked == 0` after the late `Sk.Add`; drop or replace the vacuous `b.log` check.
16. **ST1 steps 13 and 16**: a right-click deposit merges onto an existing bank stack; say "drag each small stack onto a different empty bank slot".
17. **Bag-addon warning** repeats on every /reload with no silencer but Safe Mode; suites with bag modules undetected. Note in D16 or offer a one-line "/swagbag ... quiet" later; user decision.
18. **MQ1 step 3** says the Bank group appears after the first bank visit; the bank buttons (and group) exist at login. Nit.
19. **Stacker header** `Plan(kind, skip)` -> `Plan(kind, skip, maxOf)`. Nit.
20. **Masque vs overlays**: make MQ1 step 4 name the padlock, the reagent/star marks and the gold glow (needs a locked item and a bank visit).
21. (merged into 1) stale Vendor.lua comments.
22. **Same link, different bind state**: a refused merge swaps and is counted as merged before the run stops. Low; check `t.count == m.to.count + moved` or accept.
