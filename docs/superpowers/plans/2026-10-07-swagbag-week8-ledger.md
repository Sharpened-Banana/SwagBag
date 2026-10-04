# SDD ledger — plan: docs/superpowers/plans/2026-10-07-swagbag-week8-carryovers.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Plan 22c7381 on week8 from main ab9d5a2 (0.7.0). Expected 1394 -> 1424, 7 tasks.
User: 'merge week 7 and install 0.7.0. start on week 8' (scope = carry-overs, my default).
Preflight: 17 pair rows + 7 task rows (preflight.md); replay matches exactly (1424, 37 mutations). 13 findings. Rulings — carried into task dispatches (implementers deviate from the brief where ruled, documenting it), not a plan rewrite:
- Q1 Ruling (T3, Important safety): the "loaded" guild relayout also waits while the guild scroll frame is under the mouse (scroll:IsMouseOver, as T4) — test + mutation; GL1 step 10 updated at week end — cost: regroup waits until mouse leaves.
- Q2 Ruling (T5): add test — gray robe with secret/missing link is NOT sold (LookUnknown returns true).
- Q3/Q4 Ruling (T1/T2): add tests — showAt hides a button whose scale changed after draw; scaleWarned resets on close; T2 F6 test also checks guild.listScale record and Safe Mode stays off.
- Q5 Ruling: add tests in owning tasks — Uncollected gear secret-link guard (T5), alt viewer cursor wait (T4), guild success==false guard (T3), top-%-only guard (T7), spare-button row hide (T1).
- Q6 Ruling (T6): the priority clamp applies only to cu (user) categories; a priority on ce edits of c_junk, c_sets, c_keystone, c_reagents is ignored (not imported, named in preview); dedupe data.lowered — cost: share strings can't re-rank those four.
- Q7/Q13 Ruling: plan/spec wording fixed at week end (D14 "editor can raise" removed; G9 note about free-all + list row frames).
- Q8: ledger note — a share string can still demote a built-in's priority (display only; auto-sell goes by quality/protections).
- Q9 Ruling (T1/T2): ghost rows in bank/guild use window-correct placeholder text (new locale strings) for tooltip and click answer.
- Q10 Ruling (T4): followSource stores and compares the same value (the provider that answered).
- Q11 Ruling: T7 redraws overlays only when the computed threshold changed; T1 remembers a list-size fallback for the rest of the visit (no re-scale/record loop).
- Q12 Ruling (T2): BW/GW SortList and VIEW_* tables shared via one helper (ListRows or GroupView); ColumnBar/GV.LIST_* dedupe if cheap, else ledger as deliberate.
Task 1: dispatched (BASE 22c7381, sonnet)
Task 1: implemented 663e9ef (1409 = brief+5); review dispatched (opus)
Task 1: minor (deferred, FINAL CONSIDER): F6 fallback commit can redraw under the mouse (no P5 re-check of fallback candidate); after a Q11 fallback a later click to list flashes BANK_VIEW_LIST while categories are drawn
Task 1: Ruling: placeholder ICON tooltip picks text by window (bags/bank/guild) — carried into Task 2 (before guild ghost rows repeat it) — cost: small
Task 1: minor (deferred): column-bar/sort-text duplicated with BagsWindow (plan-mandated); build() paints rows for discarded candidates; scaleAll GetScale per slot on non-list layouts; Q5 test not unique, hideGone rows.Place unpinned
Task 1: complete (commits 22c7381..663e9ef, review clean). Suite 1409 = plan +5.
Task 2: dispatched (BASE 663e9ef, sonnet)
Task 2: implemented 36fc7d2 (1421); review dispatched (opus)
Task 2: minor (deferred): no guild tests for P5 on list re-sort, SB_PRICES_CHANGED RefreshRows, list-mode right-click/drop on scaled guild buttons; GW.View near-dup of BW.View; small polish; not red-first (stash red shown)
Task 2: complete (commits 663e9ef..36fc7d2, review clean). Suite 1421 = plan +11.
Task 3: dispatched (BASE 36fc7d2, sonnet)
Task 3: implemented 5bd7c5e (1427); review dispatched (sonnet)
Task 3: minor (deferred): second pending item stays pending after first loads — untested; close test doesn't fire an event after close; chest literal repeated in specs; late item waits in New while mouse rests over window (by design, Q1 — mention in GL1)
Task 3: complete (commits 36fc7d2..5bd7c5e, review clean). Suite 1427 = plan +14.
Task 4: dispatched (BASE 5bd7c5e, sonnet)
Task 4: implemented e01c9d3 (1432); review dispatched (sonnet)
Task 4: minor (deferred, FINAL CONSIDER): no retry if Syndicator's callback registry isn't ready at its ADDON_LOADED (P.hooked stays false); spurious late announce if Syndicator loads before login; tooltip memo recompute not asserted; followSource calls Characters() per event; OW.source not reset on close
Task 4: complete (commits 5bd7c5e..e01c9d3, review clean). Suite 1432 = plan +16.
Task 5: dispatched (BASE e01c9d3, sonnet)
Task 5: implemented fa52e07 (1438); review dispatched (opus)
Task 5: minor (deferred, FINAL CONSIDER): Vendor.Protected(r,true) on draw path reaches worthMoreAtAuction → Prices.Value(r.link) uses a possibly secret link as a table key (pre-existing)
Task 5: minor (deferred): LookUnknown header/param name mismatch (plan-mandated); stale "asked fresh" comment; coin vs sale may disagree until cache clears (safe side); "cannot tell yet" wording loose; Q2 test sets link=nil by hand
Task 5: complete (commits e01c9d3..fa52e07, review clean). Suite 1438 = plan +18.
Task 6: dispatched (BASE fa52e07, sonnet)
Task 6: implemented 16e9b03 (1442); review dispatched (sonnet)
Task 6: minor (deferred): PINNED table splits idOk comment; protected ids hard-coded (drift risk); lowered/pinned dedupe+format duplicated; "just below Junk" loose; pinned-only string preview/import count unchecked
Task 6: complete (commits fa52e07..16e9b03, review clean). Suite 1442 = plan +19.
Task 7: dispatched (BASE 16e9b03, sonnet)
Task 7: implemented 440ead7 (1445); review dispatched (sonnet)
Task 7: minor (deferred): only BAG_UPDATE emit site mutation-pinned; possible double emit per BW.Layout (debounced); stubs restored at test end not after_each
Task 7: complete (commits 16e9b03..440ead7, review clean). Suite 1445.
Final review: dispatched (opus) over 22c7381..440ead7
Final review: With fixes — 0 Critical, 1 Important (Prices.Value uses possibly secret link as table key; more draw-path callers this week), 4 Minor. 1445 pass, check.sh green.
Final: Ruling: one fix wave: Important 1 (IsSecret guard in Prices.Value → fall back to itemID, spec) + Minor 1 (P5 re-check/hold after F6 fallback; correct flash when v.listFailed) + Minor 3 (one retry of P.Hook on next SB_ALTDATA_CHANGED / short debounce) + cheap cosmetics (LookUnknown param/comment; drift test protected ids vs CategoryDefaults) + week-end docs (GL1 step 10 mentions Q1 wait; Q7/Q13 plan/spec wording; spec updates list) — cost: small
Final: fix wave dispatched (sonnet)
Final: fix wave 74cedd0..6b03701 (1452); note Q6 as built: clamp applies to cu AND non-protected ce edits (matches brief + ruling); re-review dispatched (sonnet)
Final: re-review — all 7 addressed, no new Critical/Important. Minors (deferred): held F6 fallback leaves already-scaled buttons small until retry (click targets smaller briefly); Prices.Value doesn't guard a secret itemID. GL1 step 10 wording fixed by controller (item area).
Final: complete (week 8, 1452 tests)
