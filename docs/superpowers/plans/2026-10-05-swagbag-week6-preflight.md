# Preflight: week-6 plan (docs/superpowers/plans/2026-10-05-swagbag-week6-user-requests.md)

Read-only scan, 2026-10-03, against the tree at e9d09c4 (code identical to 3d2421d). Line numbers are plan lines.
Method: the whole plan was read; find blocks that land on earlier tasks' replacements were matched by hand; code anchors were spot-checked in `SwagBag/` (Categories.Load, Focus.refuse, GroupView commit/build, Snapshots snapshotBytes/Bytes, BankWindow titleButton/Theme, Footer tooltip, SettingsWindow child, QuickSetup layout, enUS keys). Test counts were recounted from the Step 1 blocks.

## 1. Task pairs that share a file or an interface

| Pair | Producer -> consumer (what is shared) | Finding |
|---|---|---|
| T1 -> T2 | `Focus.SectionOrder(order)` (T1 704-728) and `Focus.Applies()` (760-762) are used by `W.EffectiveOrder` (T2 1233-1235) and by `W.ClickSection` through Applies. | Consistent. SectionOrder returns the same table when nothing moves; T2's `sameOrder` compares contents, so M1 still works. `Layout.Apply` adds no sections, so `W.order` stays a permutation of `st.order` for the drawn state. |
| T1 / T2 (spec files) | `bagswindow_sections_spec.lua`: T1 pins "collapse" in the "focus modes (spec 6)" before_each (326-339). T2 adds a new describe before "load order" (936-1116) that keeps the "front" default. `bagswindow_list_spec.lua`: T1 pins collapse in one test (300-305) and in the week-4 carry-overs before_each (316-324). T2's list test (910-920) sits in "BagsWindow list view" (spec line 116), which T1 did not pin. | Consistent. The front-style tests run with the default. |
| T1 -> T3 | `Focus.Style/SetStyle/Applies` -> `styleCommand` (1663-1672), the settings style row (1777-1786), Report (1622-1625). T3's focus_spec find block (1472-1477) is T1's inserted M5 test header (489-490). | Consistent. The find text matches T1's replacement verbatim. |
| T1 / T4 | `SwagBag/Core/Config.lua`: T1 `focus.style` (529-547), T4 `overlays.bind` (2145-2165). | Consistent. Different blocks. |
| T1 / T4 (focus sets) | T1 tests use a fixed `ORDER` in focus_spec and Market `{c_junk,c_tradegoods,c_boe}` (451). T4 adds `c_wue` (2223). | Consistent. ORDER is a spec constant, D9 keeps Market's set, and the SmallBags fixture has no WuE item, so T2's header lists (1021-1024) do not change. |
| T1 -> T7/T8/T9, sessions | Version 0.6.0 (T1 549-563, 838-852) -> `v0.6.0` login lines in FS1/OV1/DP1/TF1 (5341, 5376, 5392, 5426). | Consistent. T7-T9 do not bump the version again, which matches line 59. |
| T2 / T8 | `SwagBag/UI/BagsWindow.lua`: T2 layout edits (1185-1430). T8 Pause tooltip (4010-4046). `bagswindow_sections_spec.lua`: T2's new describe, T8 rewrites the Pause test (3717-3756) in "focus modes (spec 6)". | Consistent. Different regions. The Pause tooltip does not depend on the style. |
| T3 -> T8 | `SettingsFocus.lua` style row. T8 edit 5 find (4157-4168) contains T3's inserted lines 1775-1778 verbatim. `L.SET_FOCUS_STYLE/_FRONT/_COLLAPSE` (T3 1724-1726) are used by T8's tip test (3811, 3814). | Consistent. |
| T3 -> T8 (row indices) | T3 changes the "This character" test from row 6 to row 7 (1544). T8 adds the intro note as row 1 and changes it to rows 2 and 8 (3836-3837). | Consistent. T8's find block (3826-3829) is T3's replacement. |
| T3 / T7 / T9 | `SwagBag/Core/Report.lua`: T3 Focus line (1607-1626), T7 Bag hooks line before `local bank = SB.BankWindow` (3221-3237), T9 bank parts and snapshot kinds (4745-4778). | Consistent. Distinct anchors. |
| T7 / T9 (report_spec) | T7 adds a test before "shows the bank setting…" (3052-3073). T9 extends that test and the snapshots test (4625-4658). | Consistent. T9's red list (4726-4727) names both extended tests. |
| T3 / T4 / T6 / T7 / T8 / T9 | `SwagBag/Locale/enUS.lua`: each task edits a different anchor block. Every new key is defined exactly once in the plan, and every existing key appears only as a find/replace pair. | Consistent. Checked by script. `MODE_TIP_LEFT`, removed by T8 (3952 -> 3956-3991), has no other user in `SwagBag/` (only BagsWindow 1285, which T8 replaces) or in `spec/` (bagswindow_sections_spec 1930, which T8 rewrites). |
| T5 -> T6 | Adapter `WarbandDepositState/RefundableForWarband/DepositWarband/DepositReagents/SetDepositReagents` (2475-2572), and the mock fields `warband{usable,reason,refundable,reagents}`, `warbandDeposits`, `refundChecks` (2386-2415). T6 uses them in `BW.DepositWarband` (2891-2917), `BW.RefreshReagents`, the box OnClick and its tests (2688-2754). | Consistent. Names, return shapes (`false, err` with `err == nil` when the API is missing) and mock fields match. |
| T5 -> DP1 | `A.CHECKS` gets 8 optional "bank" checks (2589-2596). DP1 step 20 reads "Failed checks" (5420). | Consistent. |
| T6 -> T7 | `SwagBag/UI/BankWindow.lua` `BW.Flash`: T7 edit 2's find (3287-3298) is T6's replacement (2843-2852) plus the original next line. T6's callers pass one argument, which is still valid for `Flash(text, seconds, toChat)`. | Consistent. D14 (print only when cut short) and D17 (toChat prints once) combine into one `SB.Print` (3310). |
| T6 / T7 (bankwindow_spec) | T6 inserts before "an error in a tab-click hook…" (2672-2758). T7 inserts before "the Blizzard bank button does nothing in combat…" (3020-3050). | Consistent. Distinct anchors. |
| T6 -> DP1, T7 | DP1 steps 6 and 9 (5399, 5402) expect the bank title flash `Blizzard's bank is shown/hidden…`. In 0.5.0 testing that flash was never seen (V2 step 6). T7 fixes it (D17, 3001, 3348). DP1 runs after T6 and before T7 (237, 5326). | **Conflict (seam).** DP1 asks the user to confirm the symptom T7 exists to fix. See defect 2. |
| T6 / T9 | `BankWindow.lua`: T9 changes `describe` and the count-only repaint (4986-5034), which are regions T6/T7 do not touch. `bankwindow_groups_spec.lua`: T6's free-tile test (2636-2669) and T9's two tests (4464-4515) use distinct anchors. T6's free-tile mutation targets the `family = SB.Adapter.BagFamily` line, which T9 edit 3 keeps (5212-5214). | Consistent. |
| T4 / T6 / T9 | `bankwindow_groups_spec.lua`: T4 turns on `overlays.bind` in the overlay test (1844-1857). T6 and T9 add tests. | Consistent. |
| T6 / T9 (GroupView, D13) | D13 and line 182: "nothing changes in GroupView" (T1-T6). T9 adds timing only (5143-5299). `commit` is reached only from `build()` candidates (GroupView 417 and 455), so `b.ms` always exists. | Consistent. |
| T7 -> TF1 | `TraceText` / `REPORT_BAG_HOOKS` (3254) -> TF1 steps 6 and 27 (5430, 5461). The D16 ownership rule -> TF1 steps 3-9. | Consistent. |
| T7 -> FS1 (vendor walk-away) | FS1 (after T3) has the user open bags with B (5342), then walk away from the vendor (steps 8, 15, 21; 5352, 5359, 5365). Until T7's D16 fix (3092-3101, 3596-3628), that walk-away closes bags the user opened (FM1 step 8, 3000). | **Conflict (seam).** FS1 steps 8-9, the in-game check for Review Focus 1 (108), cannot be observed on the T3 build. See defect 1. |
| T8 -> FS1 | FS1 step 16 says "The second row reads `While a mode is on`" (5360). That is true after T3, but after T8 the intro note is row 1 (4185) and the style row is the third. | Consistent on the current schedule. **Conflict if FS1 is moved after T8** (defect 1's fix). |
| T8 -> TF1 | `SET_FOCUS_INTRO`, `SET_FOCUS_STYLE_TIP`, `SET_MODE_TIP`+`SET_MODE_WHEN_FISHING`, `MODE_TIP_*`, `QS_PAUSE_NOTE` (3961-4006) -> TF1 steps 10-19 (5434-5446). | Consistent. Quoted strings match. |
| T9 -> TF1 | `REPORT_BANK_PHASES`, `REPORT_SNAPSHOT_KINDS`, `FOOTER_GOLD`, `F.GoldText` -> TF1 steps 21-22 and 27. | Consistent. |
| T3 -> FS1 | `MODE_STYLE_STATE/NAME_FRONT/COLLAPSE/FRONT`, `SET_FOCUS_STYLE*`, the report `(merge, front)` / `collapsing no` -> FS1 steps 12, 13, 16, 17 and 23. | Consistent. Quoted strings match T3's locale lines and the existing `FOCUS_NONE = "no mode"` and `VIEW_LIST`. |
| T4 -> OV1 | Badge default off, `CAT_WUE`, the existing `OVERLAYS_SET` -> OV1 steps 3-7. | Consistent. |
| Test totals | 1226 +8 +8 +2 +4 +4 +6 +6 +4 +6 = 1274 (241-249). progress.md says 1226 -> 1274. | Consistent. See section 2 for each task. |

## 2. Each task against itself

| Task | Tests added vs schedule; red/green | Code vs tests | Files list vs commit | Finding |
|---|---|---|---|---|
| T1 | 8 new tests (408-490). Red: 1225 passed + 9 failed = 1234, the 8 new tests plus the edited W4-10 test (503-514). Green 1234 (+8). | Each listed mutation (518-525) maps to a line of the Step 3 code. `refuse()` already checks read-only before `write`'s M5 skip, so `SetEnabled`/`SetSections` still refuse while read-only. The M5 comment in the test (489) and Step 2 (525) name different but equivalent mutations. | Files (266-270) = commit (867-868). | Consistent. |
| T2 | 8 new tests (1 list + 7 sections). Red: 1236 + 6 = 1242. The 2 tests that already pass are named (1135-1137). Green 1242. | The mutations (1140-1145) match the code. **Nit:** the comment on "Pause draws the user's order again…" (1096) says it "Pins week-4 behaviour (no code change makes it fail on its own)", but it is red at Step 2 (1133). It is new behaviour with no mutation. | Files (881-883) = commit (1445). | Minor (defect 6). |
| T3 | +2 tests (focus 1485, settings_focus 1516). The signals test is renamed and extended, and the row-6 test is edited. Red: 1241 + 3 = 1244. Green 1244. | The mutations match. **Nit:** `MODE_STYLE_COLLAPSE` (1708) ends "A click on a collapsed one peeks.", which is wrong when `focus.peek = "keep"`. | Files (1458-1462) = commit (1803-1804). | Minor (defect 7). |
| T4 | +4 tests (categories 1930 and 1943, overlays 2084 and 2094). Red: 1239 + 9 = 1248. Green 1248. | The `def.after` loop (2180-2191) nests correctly inside `if type(db.categoryOrder)` (Categories.lua 141-149). **Gap:** "Warbound until equipped keeps a user's rename…" (1943) is named in Review Focus 4 (119) but has no mutation, in the test or under Step 2 (2138-2141). | Files (1816-1821) = commit (2255-2257). | Minor (defect 5). |
| T5 | +4 tests (new file). Red: 1248 + 4 = 1252. Green 1252. | The mutations (2431-2434) match. `isSecret` (Adapter 10) and `location` (274) are defined before the insertion point (702). | Files (2275-2279) = commit (2613). | Consistent. |
| T6 | +6 tests (5 bankwindow, 1 groups). Red: 1253 + 5 = 1258. The free-tile test passes already, as stated (2772). Green 1258. | The mutations (2775-2780) match the code. The theme goes through `titleButton` -> `SB.Theme.Button` (BankWindow 245-247) and through `SB.Theme.Text` for the label. Guard labels `bank.depositWarband`/`bank.depositReagents` use the `"bank"` window, and `bank.deposit` is recorded as `"none"`, all as P6 (71-72). | Files (2625-2628) = commit (2989). | Consistent. |
| T7 | +6 tests (bankwindow +1, report +1, safemodehooks: 1 replaced by 2, 1 changed, 3 new = +4). Red: 1258 + 6 = 1264. The 2 tests that already pass are named (3208). Green 1264. | The mutations (3211-3217) match. Every `format` gets a string or a number. | Files (3004-3008) = commit (3682-3683). | Consistent. |
| T8 | +4 tests (settings +2, settings_focus +1, quicksetup +1). The Pause test is rewritten and the row test edited. Red: 1262 + 6 = 1268. Green 1268. | The mutations (3939-3943) match. The wrap geometry agrees with the test: child width 484, room 480, and b3 wraps at x=432. `GameTooltip` is reset by `Fake.Install/Uninstall`, so nothing leaks between specs. | Files (3700-3705) = commit (4428-4430). | Consistent. **Nit:** `SET_FOCUS_INTRO` (3961) says modes "tidy the rest", which describes the collapse style, not the default "front" style (defect 7). |
| T9 | +6 tests (groups +2, snapshots +3, footer +1). Report tests are extended, and footer expectations are edited (6 in 5 tests). Red: 1262 + 12 = 1274. The 0.5.0-reader test passes already, as stated (4731). Green 1274. | The mutations (4734-4741) match. `snapshotBytes` (Snapshots 220) is defined before the new `BytesByKind`. `tip` is in scope in the Footer tooltip (Footer 290). There are 27 mutations across T7-T9 (5513), which matches the count. | Files (4444-4452) = commit (5314-5316). | **Duplication** (defect 4). |

## 3. What the plan mandates that a code reviewer would treat as a defect

No forbidden token is written into `SwagBag/`. Every `C_*`/`Enum.` in a code block is in `SwagBag/Core/Adapter.lua` (T5) or under `spec/`. No addon's name appears outside the Adapter. Every test asserts something. The items a reviewer would raise:

- (a) **Verbatim logic duplication.** `Snap.BytesByKind` (4928-4943) repeats `Snap.Bytes`'s traversal line for line (Snapshots.lua 233-247: warband, then each char's bags+bank, then each guild's snapshot). Fix: have `Snap.Bytes()` return the sum of `BytesByKind()`. The T9 test `Snap.Bytes() == k.bags + k.bank + k.warband + k.guild` (4708) still holds.
- (b) **A critical test with no mutation.** Review Focus 4 (119) names "Warbound until equipped keeps a user's rename as a diff; reset restores it" (1942-1951), but neither its comment nor Step 2 (2138-2141) gives a mutation (line 90 requires one). It only pins the existing `userEdits` machinery for the new id.
- (c) **A misleading test comment.** T2 "Pause draws the user's order again…" (1096-1104) says it pins week-4 behaviour that no code change breaks, but it is red at Step 2 (1133).
- (d) **Small repeated guards (nit).** `A.WarbandDepositState` and `A.DepositWarband` repeat the same `account == nil or not (C_Bank and C_Bank.AutoDepositItemsIntoBank)` guard (2483-2486, 2542-2545). `styleCommand` and the settings row repeat the `front -> MODE_STYLE_FRONT` mapping (1669, 1785). These are single lines, not blocks.
- (e) **User-facing text that is inaccurate (P2 honesty).** `MODE_STYLE_COLLAPSE` (1708) says a click "peeks" even with `focus.peek = "keep"`. `SET_FOCUS_INTRO` (3961) says modes "tidy the rest" under the default "front" style. FS1 step 13 (5357) and TF1 step 14 (5441) quote these strings, so a change must update them too.
- Observation (not a defect): BagsWindow's own `describe` (BagsWindow.lua 564, 578) has the same paint-then-`Items.Describe` double read that T9 removes from the bank. D20 limits the change to the bank, which is in scope.

## 4. Conflicts with the spec

| # | Spec text | Plan | Status |
|---|---|---|---|
| S1 | §6.1, §6.4, AC8.2 ("collapses every section except the M+ mode's set"), AC8.3 (peek and pin) | The "front" style is the default and has no peek or pin in it (D1, D3, D15) | Acknowledged. The spec is updated at week end (D15, 5479). |
| S2 | §10.5 `mode [pause\|resume\|list]` | Adds `mode style [front\|collapse]` (T3) | Not in the week-end list at 5479. Add it. |
| S3 | §5.2 "Deposit target: SwagBag never chooses it … SwagBag only reads the result"; §1.3 "No writing of any Blizzard bank state, ever" | `Deposit warbound` chooses the warband bank type itself (`AutoDepositItemsIntoBank(Account)`), and `With reagents` writes Blizzard's CVar `bankAutoDepositReagents` (D11, D12) | Argued in D11/D12 and in "Blizzard's deposit control" (154-175), but not in the week-end spec-update list (5479). Record a ruling that amends §5.2/§1.3. |
| S4 | §8.3 `slot:link;count`, full links verbatim | `slot:=thatSlot;count` for repeats (D21) | Acknowledged (5479). |
| S5 | §8.6 "Downgrading one minor version is safe" | D21 accepts that a downgrade to 0.5.0 reads pointed-to stacks as unknown items. The schema stays 2, so the newer-schema guard does not fire. Other characters' snapshots stay unreadable in 0.5.0 until their character logs in. | Not in the week-end list. Record an amendment to §8.6, or accept explicitly in the ledger. |
| S6 | §8.4 "Per character ≤ 30 KB"; §9 "First bank open ≤ 80 ms" | D20 and D21 do not promise either budget (one read halved, plus instrumentation) | Acknowledged as measure-first (D20, D21, 5480-5481). The ledger should record that both budgets are still open. |
| S7 | §6.3 M+/Raid/Delves open "Gear" | `c_wue` (priority 74) takes WuE gear out of Gear (T4, D9). In the "collapse" style, WuE gear now collapses during M+/Raid/Delves (it was visible under Gear), and in "front" it no longer moves up. D9 considers only Market. | Gap, not decided. Either add `c_wue` to those modes' default sets (FocusData) or record that this is accepted, as BoE gear already is. |
| S8 | §7.6 default category set | Adds `c_wue` after BoE gear | Acknowledged (5479). |
| S9 | §10.1 hooks open/close SwagBag's window; week-1 rule "CloseAllBags() with no frame always closes" | D16 ownership rule | Acknowledged (5479). |
| S10 | Footer ruling W4-14 (gold via MoneyText) | D22 coin + `GoldText` | Acknowledged (5479). |

## Defect list (summary)

1. FS1 runs on the T3 build, but its vendor walk-away steps hit the FM1 bug that only T7 fixes (235, 5326, 5352, 5359, 5365 vs 3000, 3092-3101).
2. DP1 steps 6 and 9 expect the bank title flash that V2 showed is never seen, and only T7 fixes it (5399, 5402 vs 3001, 3348; schedule 237).
3. FS1 step 16 "second row" (5360) becomes wrong if FS1 moves after T8 (intro row, 4185).
4. `Snap.BytesByKind` duplicates `Snap.Bytes` (4928-4943).
5. A Review Focus 4 test has no mutation (1942-1951, 2138-2141).
6. A misleading T2 test comment (1096 vs 1133).
7. Inaccurate strings `MODE_STYLE_COLLAPSE` (1708) and `SET_FOCUS_INTRO` (3961), which FS1 step 13 and TF1 step 14 quote.
8. Spec items S2, S3, S5 and S7 are missing from the week-end spec-update list (5479). S6 is open.
