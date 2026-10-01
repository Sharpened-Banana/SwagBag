# SDD ledger — plan: docs/superpowers/plans/2026-10-01-swagbag-week2-categories.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Branch: week2-categories (created by controller; base d8a5553). Task 0's branch-creation step must be skipped.
Ruling: user approved the week-2 plan ("Go for week 2") with subagent-driven execution, 2026-10-01.
Preflight: 82-row table in preflight.md; all 111 code blocks replay, totals 261→360 match.
Ruling W1 (T9, critical): BagsWindow must not call Config.Get at file load; create the view button with L.VIEW_TO_GRID and set its label in W.Open(); add a test that loads BagsWindow before Config.Init — cost: none.
Ruling W2 (T9/T11): OnHide handler starts with `if frame:IsShown() then return end` (Alt+Z hides UIParent) + test — cost: none.
Ruling W3 (T11): W.Sort also starts the settle timer with a timeout so sortPending clears when Sort changes nothing + test — cost: none.
Ruling W4 (T7): randomized test leave-step: `local new; if rand(3) ~= 1 then new = rand(30) end` so items actually leave — cost: none.
Ruling W5 (T10): Review-Focus-3 test must assert one deferred change and zero placeholders before Close; correct the "already pass" count — cost: none.
Ruling W6 (T0/T1): skip the stale branch step and the git add of already-committed plan/research docs — cost: none.
Ruling W7: minor batch (arrival during deferred collapse, New "+N" never decreases, category errors re-recorded after drag-assign, duplicated key decode / unused AssignAll / RefreshVolatile duplication / duplicated pool pattern, test teardown leaving CreateFrame global) deferred to final review triage — cost: minor.
Task 0: review → Needs fixes (2 Important: W2 OnHide IsShown guard missing; plan-mandated "closed" marker blocks same-frame close→open (vendor→mailbox) — reproduced). Ruling: fix both; onOpenAll same-frame bail only when lastKind ~= "closed" — cost: small.
Task 0: minor (deferred): reopen emits SB_BAGS_CLOSED mid-frame (T9 must expect it); open-new-before-close-old ordering can close the new panel's window (ledger note); E0-3 should also check the red text vs the X button.
Task 0: fix round 1/5 (3 addressed, 0 open; commits a9c931b..f10a4ed)
Task 0: complete (commits d8a5553..f10a4ed, review clean after 1 fix round)
Task 1: review → Needs fixes (2 Important: §7.2 prose edit not applied; fuzz tests degenerate ~30 distinct inputs). Reviewer's own 200k fuzz: 0 throws, 0 round-trip failures; 0 alias collisions. Fix round 1 dispatched (+ soft warning colour, stale comments, alias-collision test).
Ruling: alias keywords (belt, gloves, trash, helm, …) replacing name search for those words is intended — matches Baganator — cost: user must quote ("belt") to name-search those words.
Task 1: minor (deferred): Wago-string test compile-only (pin warnings per row); several aliases + profession/one-hand lack positive fixtures; dropped research "must" aliases (elemental, fish, parts, item enhancement, open, optional/finishing reagents) — list in §7.5 #12 or add in week 3; `<nan`/hex numbers accepted.
Task 1: fix round 1/5 (5 addressed, 0 open; commits a4573de..c8efc17). Pretty round-trip concern disproven (200k fuzz, 0 mismatches).
Task 1: complete (commits f10a4ed..c8efc17, review clean after 1 fix round)
Ruling W8 (T2): a failed migration must carry the old DB's existing backups entries into the reset table (as Reset does) — spec §8.5 backup intent — cost: small.
Task 2: fix round 1/5 (2 addressed, 0 open; commits d6654f3..bdb8f92)
Task 2: complete (commits c8efc17..bdb8f92, review clean after 1 fix round)
Task 2: minor (deferred): no direct test that Reset()/Boot yield collapsed/categories/userEdits
Task 3: review → Needs fixes (3 Important, plan-mandated: AddToList leaves empty/redundant diffs → false "edited"; editFor crashes on damaged diff; tie-break + compile tests can't fail). Ruling: fix all (spec §8.5 wins) — cost: small.
Task 3: minor (deferred): orphan diffs for removed built-in ids never pruned; user category id colliding with future built-in silently dropped; Counts counts user categories as "edited"; new built-ins land after saved categoryOrder; AddToList readOnly false → T11 caller must print P2 feedback.
Task 3: fix round 1/5 (I-1, I-2, compile test, small fixes addressed; I-3 tie-break test still passes with tie-break removed — 1 open; commits 5d875a3..0e88c8e). Round 2 dispatched (multi-tie + shuffles + 2 mutations).
Task 3: fix round 2/5 (1 addressed, 0 open; commits 0e88c8e..6dd780a; both mutations fail as required)
Task 3: complete (commits bdb8f92..6dd780a, review clean after 2 fix rounds)
Task 4: review → Needs fixes. Code correct on all named risks (verified by reviewer mutations); 4 behaviours untested (order test never reaches tie-break; manual include conflict; failed-category skip; loaded-nil not memoised) + "recorded once" re-arms after Categories.Load.
Ruling W9: carry runtimeError across Categories.Load() when id and query text are unchanged; an edited query re-arms — spec §7.10 "recorded once" + 10-entry ring protection — cost: a fixed-elsewhere keyword error stays disabled until /reload or edit.
Task 4: minor (deferred): include+exclude of same item in one category untested; 1,290-slot wall-clock asserts may flake.
Task 4: fix round 1/5 (6 addressed, 0 open; commits ab4842e..f2f31aa; mutations proven)
Task 4: complete (commits 6dd780a..f2f31aa, review clean after 1 fix round)
HAND-OFF (T5→T10): BagsWindow BAG_UPDATE_COOLDOWN handler must call Items.RefreshVolatile only when Search.NeedsVolatileRefresh() is true.
Task 5: complete (commits f2f31aa..358dcc8, review clean)
Task 5: minor (deferred, FLAG FOR FINAL REVIEW): clear S.failedId on success (one line); tests for !cooldown / parens / alias + fail→success→fail sequences; brittle source-text OnUpdate scan → move to check.sh grep on SetScript/HookScript("OnUpdate"; HAND-OFF T10: RefreshVolatile also flips isNew — T10 test must confirm no relayout mid-open (P5).
Task 6: complete (commits 358dcc8..5fb4612, review clean, opus reviewer; reviewer confirmed 1290/1290 unique placement, 0.37 ms layout)
Ruling W10: spec §6.4 "never moves item buttons" is read as "never moves a button relative to its own section header"; sections below a collapsed one shift as a whole and are listed in Moves for the hover guard — cost: spec wording to tidy at week-2 end.
HAND-OFF (T6→T9): BagsWindow must pass Categories.SectionOrder() (display order), not byPriority, to Layout.
Task 6: minor (deferred, FLAG FOR FINAL REVIEW): big-fixture exactly-once placement assertion; guard a real item assigned id "free" (map to NEW / reserve ids); header-relative offset assertion; reagent-bag empties mixed into Free (UI cue later); duplicate fixture/opts in layout_spec.
Task 7: review → Needs fixes (1 Important: randomized test degenerate — low-bit LCG, 6/20 slots, 8 real moves, no overflow/swaps/hover). Apply verified correct by reviewer's independent 80k-step stress (0 violations). Fix round 1 dispatched (+ overflow count set, added→needsReflow, placeholder icon assert, no-reuse comment).
HAND-OFF (T7→T10): count/lock/cooldown changes, item-data-load, placeholder release on close are Task 8-10 responsibilities, not Apply.
Task 7: fix round 1/5 (4 addressed, 0 open; commits d8069da..689273f; randomized test 24 seeds × 400 steps, both mutations fail it, 0.30 s)
Task 7: complete (commits 5fb4612..689273f, review clean after 1 fix round)
Task 7: minor (deferred, FLAG FOR FINAL REVIEW — one-line fix): overflowKeys[X] not cleared when an overflowed Free button moves into New after New is expanded (collapse→expand→re-arrive); call clearOverflow before append to NEW in the Free→New branch + test.
Task 8: review → Needs fixes (1 Important plan-mandated: pools ignore parent on reuse). Taint/layering, cursor item, header reuse, ClearCursor all verified safe. Fix round 1 dispatched.
Ruling W11 (HAND-OFF to T11): a Sort pressed in combat must NOT auto-run from PLAYER_REGEN_ENABLED (not a hardware event; SortBags only proven from a click) — instead show "Sort after combat ends" and do nothing — cost: user presses Sort again after combat.
⚠️ IN-GAME (T11/E2): check a header doesn't both receive a drop and toggle collapse on one click-pickup/click-drop.
Task 8: fix round 1/5 (4 addressed, 0 open; commits 728f749..22d98b6)
Task 8: complete (commits 689273f..22d98b6, review clean after 1 fix round)
Task 9: complete (commits 22d98b6..b1b7c79, review clean, opus reviewer)
HAND-OFF (T9→T10): SIZE event still calls W.Layout("size") directly (full regroup, no rule-5 guard) — Task 10 must replace it.
Task 9: minor (deferred, FLAG FOR FINAL REVIEW): reopen-mid-hide test weak/misnamed; untested "unchanged buttons get no SetPoint"; no test for cursor-held collapse/toggle or retry dying on close; held-back collapse gives no immediate header feedback (P2); report can't separate first vs warm open budget; double full layout on quick close/reopen.
Task 10: review → Needs fixes (2 Important probe-confirmed: overflow header never refreshes while open; placeholders lose icon when LOCK arrives before flush; + E1 checklist would cause false failures). Fix round 1 dispatched.
Ruling W12: an ITEM change with the same itemID but a changed link (keystone level after a run, enchant, gem) is a repaint in place, not "arrived" — M+ user's keystone must not jump to New — cost: such items re-categorize only on next open/Reflow.
Task 10: minor (deferred): modifier-key part of rule 5 not implemented; bag equipped in combat stays invisible until next open; deferred "removed" can re-show a hidden button; ApplyChanges re-renders all cells on any move (§9 5 ms budget unmeasured).
Task 10: fix round 1/5 (6 addressed, 0 open; commits 0edd924..9fcddd8)
Task 10: complete (commits b1b7c79..9fcddd8, review clean after 1 fix round)
Task 10: minor (deferred): search may briefly use emptied slot's old record (≤250 ms); E1 step 24 must say keep the bag OPEN when the keystone changes (controller will word it when handing E1 to user); step 23 explain getting the stack to 1; deferred "left" + re-arrival before retry untested.
Task 11: review → Needs fixes (2 Important: plan E2 steps 6/9/10 contradict behaviour; click-then-drop guard half can't fail). All rulings verified in code. Fix round 1 dispatched (+ COOLDOWN doesn't arm settle, second Sort keeps first regroup, clear dropGuard on hide, collapsed-header drop test).
Task 11: minor (deferred): "Added X" shown when item already in section (dedicated message); failing Sort recorded on every press; reagent-bag sorting by SortBags to be checked in E2 step 8.
Task 11: fix round 1/5 (6 addressed, 0 open; commits 6987e00..39dbe63)
Task 11: complete (commits 9fcddd8..39dbe63, review clean after 1 fix round)
ALL 12 TASKS COMPLETE. Final whole-branch review next.
Final review (opus): Ready to merge with fixes — 1 Critical (C1: window resizes around bottom anchor → items shift under mouse; breaks exit criterion), 3 Important (I1 overflow key, I2 checklist errors, I3 spec wording), 1 Minor (M1 reset doesn't reload categories). Perf: <1 ms bags, 2–4 ms projected bank (make render incremental in week 3). Fix list at final-fix-list.md; ~30 items triaged deferred.
Final fix wave: 5/5 addressed (commits 39dbe63..644b224; 427 passed). Scale-change formula verified correct (left*old/new).
Ruling (residual → week 3): call savePosition() at the end of W.SetScale when shown (window moves on reopen after a Ctrl+wheel scale change); Ctrl+wheel test should cover a second notch / non-1 start scale; avoid re-anchoring during an active drag — cost: cosmetic window jump on reopen after rescaling.
WEEK 2 COMPLETE.
