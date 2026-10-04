# SDD ledger — plan: docs/superpowers/plans/2026-10-09-swagbag-week10-lock-warnings.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Plan d53173f on week10 from week9 7ee3958 (0.9.0, week 9 NOT merged). Expected 1522 -> 1543, 5 tasks.
User: 'Make it' (lock warnings) then 'Start building 10. I'm very behind on tests.'
Preflight: 21 pair rows + 5 task rows (preflight.md); replay exact (1543, 26 mutations); 11 findings, none blocking. Rulings (carried into task dispatches):
- U1 (T2): drop CURSOR_CHANGED from the delete-warning listeners (fires constantly incl. M+ combat; ITEM_LOCK_CHANGED/BAG_UPDATE_DELAYED cover No/Esc/Yes); fix "four events" count.
- U2 (T2): hide the note when Adapter.DeletePopup() returns nil even if the item is still on the cursor.
- U9 (T2): create the delete note frame at SB_LOGIN (out of combat), not lazily.
- U7 (T3): scrapper tooltip says "a right-click can put this item in it".
- U4/U11 (T4): rename/fix the "On first and selected" test; `/swagbag lock warn` accepts only `warn` alone or `warn <word>` (no `warnon`).
- U5 (whichever task adds the adapter_spec after_each): save and restore the original globals instead of nil'ing them.
- U6 (T5): update the layout-guard comments to "anything on the cursor (CursorBusy)".
- U3/U8/U10 docs: week-end — widen LW1 step 6 question; D3 cites Adapter.HookItemTooltip (AC13.3); spec §9 event list + plain-frame-in-combat note.
Task 1: dispatched (BASE d53173f, sonnet)
Task 1: implemented 90f3bf6 (1526); review dispatched (sonnet)
Task 1: minor (deferred): unused globals header in lockwarnings_spec (brief); red-line order under Locked line not asserted; LW.On strict true
Task 1: complete (commits d53173f..90f3bf6, review clean)
Task 2: dispatched (BASE 90f3bf6, sonnet)
Task 2: implemented 58e8352 (1532 = brief+2); concern: note can linger if popup closes without lock/bag events; review dispatched (opus)
Task 2: Ruling: implementer's edits to global-constraints.md (U1/U9 wording) accepted — they match the rulings.
Task 2: minor (deferred, FINAL: cheap): note can linger if the popup is hidden externally while the item stays held — fix with a bounded self-rescheduling 0.25 s recheck timer only while LW.deleting (no OnUpdate, no popup hooks)
Task 2: minor (deferred): comment that a login in combat has no note until combat ends; weak count assertion; implicit negative checks
Task 2: complete (commits 90f3bf6..58e8352, review clean). Suite 1532 = plan +2.
Task 3: dispatched (BASE 58e8352, sonnet)
Task 3: implemented 0a3d1bc (1536); review dispatched (sonnet)
Task 3: minor (deferred, FINAL cheap): CheckScrapper lacks an LW.scrapper guard (late event after close could warn) + no test; `not seen[id]` dedupe untested; switching warn on with an item already in a slot doesn't warn
Task 3: complete (commits 58e8352..0a3d1bc, review clean). Suite 1536 = plan +2.
Task 4: dispatched (BASE 0a3d1bc, sonnet)
Task 4: implemented 37b19fb (1540); review dispatched (haiku)
Task 4: minor (deferred, FINAL cheap): L.LOCK_STATE doesn't mention `warn`; report_spec stubs SB.Locks without restore; read-only only tested for on
Task 4: complete (commits 0a3d1bc..37b19fb, review clean). Suite 1540 = plan +3.
Task 5: dispatched (BASE 37b19fb, sonnet)
Task 5: implemented 63523f0 (1546); review dispatched (sonnet)
Task 5: minor (deferred, FINAL cheap): W4-25 spec comment now sits above the wrong test (move); some reworded comments exceed wrap width
Task 5: complete (commits 37b19fb..63523f0, review clean). Suite 1546.
Final review: dispatched (opus) over d53173f..63523f0
Final review: With fixes — 0 Critical, 1 Important (LW1 step 16 / D4 quote "puts" vs U7 "can put"; stale CURSOR_CHANGED mentions), minors. 1546 pass. Linger timer: reviewer recommends NOT adding (cosmetic).
Final: Ruling: one fix wave: scrapper close guard + test; LOCK_STATE mentions warn; move W4-25 comment; docs (LW1 step 16, D4, remove CURSOR_CHANGED mentions, U3/U8/U10, week-end spec list). Linger timer NOT added (reviewer triage; revisit if LW1 shows a leftover bar) — cost: cosmetic bar may linger rarely
Final: fix wave dispatched (sonnet)
Final: fix wave 654b37c..6c21aaa (1547); re-review dispatched (sonnet)
Final: re-review — all 5 addressed, no new breakage.
Final: complete (week 10, 1547 tests)
