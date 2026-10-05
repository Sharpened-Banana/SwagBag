# SDD ledger — plan: docs/superpowers/plans/2026-10-11-swagbag-week12-wizard-tour-modes.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Plan 6189276 written on 8503e06; week12 REBASED onto main 65b6985 (hotfix 0.11.1, +19 tests: 1633). Plan counts assume 1614 base -> expect +19 shift (1663 -> 1682) unless find blocks differ.
User: 'merge, install, do week 12'. Principle V0 binding.
Preflight: replay on 65b6985 — all tasks hold; every count +19 (T1 1633/13->1646, T2 1639/11->1650, T3 1650/11->1661, T4 1661/13->1674, T5 1674/8->1682); T1's two version find blocks need 0.11.1; all mutations killed; defect scan clean. 14 findings. Rulings (carried into dispatches):
- Y1 (T1): version find blocks read 0.11.1 (-> 0.12.0).
- Y2: all counts +19 vs the plan text; base is 65b6985.
- Y3 (T4): a manual-trigger mode ignores focus.on (the Off switch in the mode list only governs triggered modes) — or SetTrigger(id,"manual") writes focus.on.<id>=true; choose one, test + mutation; P2 answer must be true.
- Y4 (T2): a wizard hidden by combat inside an instance (M+/raid/delve) does NOT come back on PLAYER_REGEN_ENABLED; it keeps the draft and comes back when the player leaves the instance (or on /swagbag setup, resuming the draft); test.
- Y5 (T5): Profiles Load/Reset/Undo carry the user's own modes (m_* definitions, their on switches and sections) across replace() so a profile never strips them; test.
- Y6 (T2): step 4 writes prices.worthGold only when the planned prices.worth is "fixed".
- Y7 (T3): no tour offer after Finish while the bags are in Safe Mode.
- Y9 (T2): fix stale spec comment quicksetup_spec.lua:127 ("Setup.Finish").
- Y10 (T4): LoadCustom skips stored modes whose names are taken (duplicate or built-in).
- Y14 (T2): the Finish answer adds that settings are saved on logout or /reload.
- Y8/Y11/Y12/Y13: week-end docs — D12 says "after each Finish"; spec §8.1/8.2 setup.done account-wide; AC8.4 manual first; AC11.2 watch-list seeding listed as deferred carry-over.
Task 1: dispatched (BASE 5f08322, sonnet)
Task 1: implemented f0c4367 (1646); review dispatched (sonnet)
Task 1: Ruling (plan-mandated Important): Gold's prices.worth="fixed" write is not a step-2 switch — resolved in Task 2: step 4's gold-glow choice must show the value the picked styles would set (Gold → the planned amount pre-selected) and Off reverts it, so it is visible and switchable before Finish; test in T2. Also T2 adds a fallback append in Setup.Order so a promoted id never vanishes when c_keystone is absent (and never adds a phantom id).
Task 1: minor (deferred): Finish ignores C.Set returns; HELP_TOUR/TOUR_LATER "November" text (T3 scope); Setup.Label no raw-key fallback
Task 1: complete (commits 5f08322..f0c4367, review clean). Suite 1646.
Task 2: dispatched (BASE f0c4367, sonnet)
Task 2: implemented ae82aa0 (1656 = brief+19+6); review dispatched (opus)
Task 2: review Needs fixes — 1 Important: WIZ_COMBAT_HIDDEN says it returns when combat ends, false inside an instance (Y4). Ruling: fix round 1 = instance-aware combat line (+ exact-text test); frame/rows fit 17+ switches (taller frame or 22px rows) without overlapping the status line; re-run wording: Skip says 'keep my settings' when setup.done (button label + hint); step 2 lists BUILT-IN modes only (custom modes stay in Settings — principle V0; avoids MAX_SWITCHES overflow when Task 4 adds up to 10); fix stale test mutation comment and enUS:515 comment. Custom-value highlight deferred.
Task 2: fix round 1 4869d76 (1659); re-review dispatched (sonnet)
Task 2: fix round 1/5 (5 addressed, 0 open; commits ae82aa0..4869d76)
Task 2: minor (deferred): custom values (worthGold 250, odd scale/columns) show no lit button; MAX_SWITCHES cap silent (built-ins only now); wizard kept draft is memory-only
Task 2: complete (commits f0c4367..4869d76, review clean after fix round 1). Suite 1659 = plan +28.
Task 3: dispatched (BASE 4869d76, sonnet)
Task 3: implemented c082698 (1671); review dispatched (sonnet)
Task 3: minor (deferred, FINAL cheap): tour offer left up when /swagbag tour or /swagbag setup runs (later prints WIZ_TOUR_LATER wrongly) — hide offer with offerAnswered in Tour.Start/QS.Show; Esc via UISpecialFrames test hole; Esc also closes the bags (note for WZ1); Start while running untested; scrolled-out header
Task 3: complete (commits 4869d76..c082698, review clean). Suite 1671 = plan +29.
Task 4: dispatched (BASE c082698, sonnet)
Task 4: implemented 435a71b (1686); concern: SetEnabled on manual mode is a no-op -> T5 UI must not offer On switch for manual modes; review dispatched (opus)
Task 4: review Needs fixes — 1 Important: P2 with focus.announce on: mode on prints 2 lines; bulk off prints intermediate modes and re-stacks per mode. Ruling: fix round 1 = SetManual quiet path (no announce for user-initiated switches), bulk off clears all then one Recompute (one emit, one re-stack); test with announce on; fold in MODE_STATUS mentions on/off, unknown-name echoes the typed case if available (else accept), delete test asserts char override removal, Categories.Delete override loop test, drop the useless truthy(dump) assert.
Task 4: fix round 1 42e7e28 (1688); re-review dispatched (sonnet)
Task 4: fix round 1/5 (3 addressed, 0 open; commits 435a71b..42e7e28)
Task 4: minor (deferred): trailing truthy assert in quiet test; hidden skipped modes stay in SavedVariables; freeId slug can end "_"; MODE_MANUAL_UNKNOWN echoes lowercased input
Task 4: complete (commits c082698..42e7e28, review clean after fix round 1). Suite 1688 = plan +33.
Task 5: dispatched (BASE 42e7e28, sonnet)
Task 5: implemented e1f2aa7 (1699); review dispatched (opus)
Task 5: minor (deferred, FINAL cheap): SF.confirmDelete stays armed after window close (also SettingsCategories) — clear on hide/page switch; locale hard-codes 10/24 limits (format from constants); manual row labelled as char setting; two "It switches on" rows; Profiles reads Focus.custom directly; read-only refusals untested; Y5 Reset switch not asserted
Task 5: complete (commits 42e7e28..e1f2aa7, review clean). Suite 1699.
Final review: dispatched (opus) over 5f08322..e1f2aa7
Final review: With fixes — 1 Critical (delete confirmation stays armed after closing Settings/page change, SF and SC), 1 Important (tour offer left up when /swagbag tour or setup runs), 4 Minor. 1699 pass.
Final: Ruling: one fix wave (sonnet): #1 clear SF.confirmDelete (+creating/renameText) and SC.confirmDelete (+confirmReset) on settings hide and page change, test arm→hide→reopen→click doesn't delete; #2 Tour.Start and QS.Show answer+hide a showing offer, no WIZ_TOUR_LATER; #3 TryShow returns early when the wizard is shown/combatHidden, QS.Show clears waiting; #4 no tour offer inside an instance; #5 "leave the instance" wording; #6 manual mode row not layered; plus week-end docs (spec updates list + Y8 D12 wording, Y11 setup.done account-wide, Y12 AC8.4 manual first, Y13 AC11.2 deferred carry-over) and WZ1 notes (Esc closes bags too).
Final: fix wave dispatched (sonnet)
Final: fix wave cc401e6..2ba53e6 (1709); re-review dispatched (sonnet)
Final: re-review — all 8 addressed, no new breakage.
Final: complete (week 12, 1709 tests)
