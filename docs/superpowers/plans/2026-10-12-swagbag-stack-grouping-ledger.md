# SDD ledger — plan: docs/superpowers/plans/2026-10-12-swagbag-stack-grouping.md

Branch stack-grouping from main c4a2ea1 (v0.13.6, 1851 tests). Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md.

## Preflight scan

| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T1 -> T2 | Stacks.Key (T1) is passed by callers as opts.stackKey; Layout never names SB.Stacks | Consistent. |
| T1 -> T3/T4 | Stacks.Totals/Of/Line/CountText/Enabled, L.STACKS_TIP_* | Consistent. |
| T2 -> T3 | pos.stacks {bag,slot,key,members,shown}, Layout.MembersOf, Sort.DisplayOrder(...,totalOf), Prices.SectionTotals members | Consistent. |
| T2 -> T4 | GroupView merges pos.stacks per group | Consistent (one Layout state per group). |
| T3 -> T4 | Buttons.SetStack/StackOf/StackTooltipLine, SearchBox o.afterApply, ListRows total arg | Consistent; T4 reuses. |
| T1 -> T3/T4 | SB_STACKS_CHANGED emitted by /swagbag stacks; listeners in T3 (bags) and T4 (bank) | Consistent. |
| T5 | spec text + checklist after code | Consistent. |
| T1 self | Key: "blank 10th and 11th colon fields" of the item string | See ruling S1. |
| T3 self | test "a hidden stack's match keeps the icon lit" text is muddled (search `stack`, then "make the 45 a full stack instead") | See ruling S2. |
| T2 self | representative = largest, cell at the first stack's index; tests agree | Agrees. |
| T4 self | guild bank / offline never group (no cfg.stacks) | Agrees. |

Ruling S1: blank the item string's linkLevel and specializationID fields by their documented positions (item:itemID:enchant:gem1-4:suffixID:uniqueID:linkLevel:specializationID:...), verified against the format, not by a literal "10th/11th" count — the plan's count is ambiguous about whether "item" is field 1 — if wrong, identical items fail to merge or (worse) viewer-only fields split them; tests pin both.
Ruling S2: the "hidden stack's match keeps the icon lit" test uses a search that matches only the hidden stack (e.g. a count comparison like `count<10` against stacks 45 and 7), so the shown 45 must stay lit through afterApply — the plan's intent; costs nothing if wrong.

## Tasks
Task 1: implementer DONE f8e554b (1869 tests); S1: blanked fields 10,11 counting 'item' as 1 (linkLevel, specID) — correct per format; Totals slot shape {bag,slot,record}
Task 1: minor (deferred): no test pins that suffixID/uniqueID (fields 8-9) and field 12+ are NOT blanked (FINAL SHOULD FIX: cheap)
Task 1: minor (deferred): no-link + nil itemID key "nil#u"; Of assumes first.count numeric; secret test comment
Task 1: complete (commits c4a2ea1..f8e554b, review clean)
Task 2: implementer DONE_WITH_CONCERNS cd9a2f8 (1888 tests); concern: no randomized invariant test with stackKey
Task 2: review Approved; minors: no randomized invariant test with stackKey (reviewer ran one in a temp copy: 24 seeds x 400 steps + 40 tile runs pass); Prices header stale; Prices duplicates Layout key decode; vacate/MembersOf nil-guard mismatch; dead clearOverflow for members; Position test loop can pass silently; wall-clock timing test
Task 2: Ruling: add the stackKey randomized invariant tests + Prices header + Layout.BagSlot now (one extra round) — this is the riskiest state machine and Tasks 3-4 build on it — costs one small round
Task 2: fix round 1/5 (4 addressed, 0 open — stackKey randomized harnesses, Prices header, Layout.BagSlot, guards/tests; commits cd9a2f8..88e5b49)
Task 2: minor (deferred): tile harness with tile off doesn't assert a member slot holds an item (one-line assert)
Task 2: complete (commits f8e554b..88e5b49, review clean)
Task 3: implementer DONE_WITH_CONCERNS 8defe1b (1915 tests); concerns: grid check in W.StackKey untestable; list sort total spans sections; relit icons not in /swagbag search count
Task 3: minor (deferred, FINAL SHOULD CONSIDER): bagswindow_sections/list specs load Engine/Stacks only in nested describes — run them once with Stacks loaded (default "one") to confirm no existing test changes
Task 3: minor (deferred): list sort total bags-wide not per section (plan-mandated); search match count misses relit icons; Overlays.lua:14 stale comment; grid guard in W.StackKey unreachable
Task 3: complete (commits 88e5b49..8defe1b, review clean)
Task 4: implementer DONE_WITH_CONCERNS 9913b7e (1929 tests); concerns: GroupView copies BagsWindow paintStacks/RelightStacks (shared helper broke fake Buttons pools); 2 surviving mutants
Task 4: review: 1 Important (paintStacks/RelightStacks copied verbatim BagsWindow<->GroupView; share via callback helpers in Engine/Stacks.lua)
Task 4: minor (deferred): build computes Stacks.Key twice per slot in list view; bank handler PaintStacks redundant after v.Changes; characterization tests' mutations described not run
Task 4: fix round 1/5 (3 addressed, 0 open — Stacks.Paint/Relight shared; v.Clear dimmed; build guard; commits 9913b7e..097a2a4)
Task 4: complete (commits 8defe1b..097a2a4, review clean)
Task 5: implementer DONE_WITH_CONCERNS f310631 (docs; master checklist now tracked with Session 16)
Task 5: review: 2 Important (S-5 'loot one more' tops up a stack, never New; Session 1 version) + 6 minors — all fixed in 456a7db
Task 5: Ruling: the docs-only fix round's re-review is folded into the final whole-branch review (it reads the same diff) — saves one seat — costs nothing if wrong (final reviewer sees every line)
Task 5: complete (commits 097a2a4..456a7db)
Final review (456a7db): With fixes — 1 Important (Stacks.Of never checks members are still the same item: a held swap shows a false total/tooltip on a different item), minors: field 8-9/12-13 pin test, Overlays.lua:14 comment, fake pool SetStack/StackOf, double Key in list
Final: Ruling: one fix wave = Important + all 4 minors (all cheap, two are tests) — costs nothing if wrong
Final: fix wave 8d3f274 (1938 tests); re-review: all 5 addressed, no new breakage
