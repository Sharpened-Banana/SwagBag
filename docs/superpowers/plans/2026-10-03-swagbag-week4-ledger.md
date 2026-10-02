# SDD ledger — plan: docs/superpowers/plans/2026-10-03-swagbag-week4-focus-modes.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md. Branch week4-focus, base aa3fea1 (main), plan commit f48e4eb, 718 tests. Plan author replayed every task on a fresh clone (totals 742…849).
Preflight: preflight.md (46 rows, 28 findings). All proposed rulings in preflight.md ADOPTED as binding (cited by F-number in each task dispatch). Key ones:
Ruling W4-1 (F-1, Task 3): bags window keeps the collapse view it last drew; ApplyChanges lays out with that drawn view; only a successful Restack switches to the new mode's view. Test: loot during a held switch moves nothing under the mouse — cost: ~10 lines.
Ruling W4-2 (F-2, Task 1→7): Focus.Sections(id, raw); editor reads/writes the raw list; only Expanded() filters by profession — cost: one param.
Ruling W4-3 (F-3, Task 1/2/5): FocusData.Matches returns false first on a secret spell ID; spell names cached so teleport matching does no name lookup per combat cast — cost: two lines.
Ruling W4-4 (F-4, Task 7): Free stays in each mode's collapsed set by default (D3), and the section editor gets a Free row — cost: none.
Ruling W4-5 (F-5, Task 7): right-click on Pause opens settings under "none" and flashes SETTINGS_FAILED on error — cost: none.
Ruling W4-6 (F-6, Task 9): quick setup Apply error shows/prints SETTINGS_FAILED — cost: none.
Ruling W4-7: settings window runs commands under each command's own trap label; global-constraint wording amended accordingly — cost: none.
Task 1: dispatched (BASE f48e4eb, sonnet; W4-2 carried)
Task 1: DONE c496431 (743 tests)
Task 1: review → Needs fixes (1 Important plan-mandated, probe-confirmed: view inputs (bankOpen expandAll, professions) change what is open without SB_FOCUS_CHANGED).
Ruling W4-8: the change key includes the effective-view inputs (expandAll-at-bank flag, professions fingerprint while gathering applies); a view change with the same active set emits once without clearing pins — cost: none.
Task 1 round 1 also: proxy view __newindex errors; contents-unchanged test for the user set through mode/peek/pin/close/pause; HeaderClick/Pin no-op (return false) when no mode applies; writers return false,"readonly" vs false,"unknown"; cache Expanded() and precompute config paths; header comment notes no announce while paused.
Task 1: fix round 1/5 (c496431..d8d0b63, 749 tests).
Ruling W4-9: Expanded() is cached; every write of a focus setting (Tasks 6-9: settings pages, quick setup presets) must go through the Focus writers or call Focus.Refresh — carry into those dispatches — cost: none.
Task 1: re-review → Needs fixes (Resume invalidate untested; CharOverride/Reset/Init bypass Refresh → stale cache).
Ruling W4-10: Config emits SB_CONFIG_CHANGED(path|nil) after Set/CharOverride/Reset/Init; Focus refreshes on nil or "focus.*" — robust at the source (supersedes the caller discipline in W4-9, which stays as belt-and-braces) — cost: one event per settings write.
Task 1: fix round 2/5 dispatched (also tostring in fingerprint).
Task 1: fix round 2/5 (d8d0b63..fd87b4d, 751 tests). Controller scoped check: Config emits SB_CONFIG_CHANGED on Set/CharOverride/Reset/Init via guarded helper; Focus listener under "bags"; writers no longer double-refresh — addressed.
Task 1: complete (commits f48e4eb..fd87b4d, after 2 fix rounds)
Task 1: minor (deferred): fingerprint includes unrelated professions (spurious emit); in-place mutation of professions table undetected; CollapsedView objects must not be held across Recompute (Task 3 must call fresh per layout).
Task 2: dispatched (BASE fd87b4d, sonnet; W4-3 + d8 carried)
Task 2: DONE 010f02f (778 tests)
Task 2: review → Needs fixes (plan-mandated: UNIT_SPELLCAST_* registered for all units → every nameplate/party cast runs through ErrorTrap (~576 B garbage) in combat; player filter untested).
Ruling W4-11: SB.OnUnit(event, unit, fn, window) in Events.lua registers via RegisterUnitEvent(event, "player") on a dedicated frame (pcall registration, same Run wrapper); Signals' spellcast events and Task 5's teleport handler use it — cost: none.
Ruling W4-12: ADDON_RESTRICTION_STATE_CHANGED re-reads the zone only for the ChallengeMode restriction type (Adapter helper) — cost: none.
Task 2 round 1 also: player-filter test; skillLine/inside secret checks in Adapter; PEW clears merchant/AH/bank open flags; Report yes() nit; secret-fallback adapter test + unknown-event load test.
Task 2: fix round 1/5 (010f02f..c3409d3, 786 tests). Controller scoped check: SB.OnUnit dedicated frame, pcall registration, per-event handler list under Run — addressed. Note: unit is fixed by the first OnUnit per event (all callers use "player").
Task 2: complete (commits fd87b4d..c3409d3)
Task 3: dispatched (BASE c3409d3, opus; W4-1, d1, e2 carried)
Task 3: DONE_WITH_CONCERNS e434068 (799 tests; until Task 4, a header click in a mode writes the saved set — Task 4 must route through Focus overrides + W.Restack)
Task 3: review → Needs fixes (1 Important plan-mandated, probe-confirmed: automatic mode switch holds only on item buttons; headers/gaps under a resting mouse move and an item can slide under the pointer — vendor right-click could sell it).
Ruling W4-13: switches from SB_FOCUS_CHANGED (world-triggered) are also held while the mouse is over the scroll area (scroll:IsMouseOver()) or an item is on the cursor, same 300 ms retry; header-click restacks keep the button-only guard (the clicked header doesn't move) — cost: a switch waits while the mouse rests anywhere on the items.
Task 4 carry (from Task 3 review (g)): i) header click/right-click in a mode → Focus.HeaderClick/Pin, never ToggleSection, fallback only when they return false; ii) W.Restack after overrides; iii) collapsedNow from W.view; iv) Focus.WindowClosed in OnHide after IsShown; v) flash every click; vi) tests: saved set unchanged after click in a mode, held peek + loot; vii) area hold for peek/pin where clicked header can move.
NOTE: the installed addon is a symlink to the working tree — the user plays on the branch HEAD (O1 report showed 0.4.0). Interim states go live.
USER O1 RESULTS (2026-10-01): all pass except: overlays/icons too small (3-5), junk coin not pronounced (10); step 15 Pawn installed but "Pawn is not loaded" (A.HasPawn checks PawnIsContainerItemAnUpgrade, absent in Pawn 2.13.16; API is PawnIsReady + PawnIsItemDefinitivelyAnUpgrade(link,true) / PawnShouldItemLinkHaveUpgradeArrow); 16-17 not tested (none carried). Requests: New hidden when empty by default; BUG: blue new-item tint returns on all items after /reload (root-cause agent dispatched).
USER REQUEST (2026-10-01): gold, crests and other things pinned at the bottom of the bags window (currency footer).
Task 3: fix round 1/5 (e434068..3e855b4, 803 tests). Controller scoped check: W.Restack(area) holds on scroll:IsMouseOver()/cursor for world-started switches; areaHeld makes header clicks wait during a held switch; reset on hide/layout — addressed.
Task 3: complete (commits c3409d3..3e855b4)
USER (2026-10-01): footer items = keystone and free slots too; "let the user decide what can go down there/fits". Install stable week 3: DONE — symlink removed, main's SwagBag (0.3.0, aa3fea1) extracted as a real folder into AddOns. Week-4 sessions need a re-install of the branch (scripts/install.sh after removing the copy).
Ruling W4-14 (footer): a bottom bar in the bags window with user-chosen entries: gold, Blizzard backpack-tracked currencies, crests (auto when owned), keystone, free-slot count; default all on; entries that don't fit the width wrap to a second row (never overlap); settings page lists every entry with on/off and order — cost: one task.
Ruling W4-15 (O1 fixes): Pawn via PawnIsReady + PawnIsItemDefinitivelyAnUpgrade(link,true) (nil → item-level rule; supersedes W3-16 fold); overlay text larger with thick outline, arrow and junk coin larger/more pronounced; "New" hidden when empty by default (setting: always show), its appearance shifts sections — hover-guarded; blue new-item glow fix per root-cause agent.
Task 4: dispatched (BASE 3e855b4, opus; Task 3 review carry i-vii + a11)
Blue glow root cause: newglow-diagnosis.md (C_NewItems flag never cleared since SwagBag replaced ContainerFrame).
Task 4: DONE_WITH_CONCERNS 53a2f0a (817 tests; W.ClickSection/PinSection; FM1/DR1 in report)
Task 4: review → Needs fixes (1 Important, probe-confirmed: click during a held mode-exit/pause switch flips the saved set opposite to what's drawn, silently).
Ruling W4-16: W.ToggleSection decides from the drawn view (set[id] = not (W.view[id]==true) or nil) and flashes when the restack is held — cost: none.
Ruling W4-17: right-click with an item on the cursor drops into the category like left-click (plan behaviour kept); FM1 gets a line saying so — cost: none.
Task 4 round 1 also: tests (bank/guild header right-click collapses; right-click with cursor item on group header doesn't drop; paused left-click writes user set); /swagbag mode <unknown> adds a usage line; flash keys passed as L.* values. Deferred: scroll clamp can move the clicked header (week-3 behaviour).
Task 4: fix round 1/5 (53a2f0a..ef9e9a5, 824 tests). Controller scoped check: ToggleSection flips the drawn view, held click flashes; flash keys are L values — addressed.
Task 4: complete (commits 3e855b4..ef9e9a5)
FM1 + DR1 IN-GAME CHECKLISTS READY (task-4-report.md; FM1 13a, 17a added).
Task 5: dispatched (BASE ef9e9a5, sonnet; W4-11, W4-3, a12, a6, T5 carried)
Task 5: DONE_WITH_CONCERNS 9f1888b (844 tests)
Task 5: review → Needs fixes (3 Important: damaged saved name throws under Lua 5.1 %s → Safe Mode at key start (probe); DK "Path of Frost" counts as a teleport; K1 session T5 line missing / report's K1 steps wrong).
Ruling W4-18: saved watch names kept only if string and a real Locale key; tests under a 5.1 %s format shim — cost: none.
Ruling W4-19: FocusData.teleports gets an excludes list ("path of frost") checked in Matches — cost: none.
Ruling W4-20: PEW with isReload while challengeMode already true does not fire "enter" — cost: none.
Task 5 round 1 also: CONSUMABLES_NONE for empty list; dedicated CONSUMABLES_STATE_ON/OFF strings; d6 (SetThreshold doesn't save an unchanged clamped value); single-pass counting; tests (Mythic w/o keystone, challengeMode branch, consumables on, bank not counted). K1: corrected session goes in task-5-report.md (plan file is being amended by another agent — don't edit it); controller folds it into the checklist doc.
Note for Task 8/user: Food counts drinks; potion counts all potions; item entries don't group quality ranks.
Task 5: fix round 1/5 (9f1888b..a2dda17, 853 tests). Controller scoped check: shim restored in after_each; W4-18/19/20/d6 mutations caught; check.sh green — addressed.
Task 5: complete (commits ef9e9a5..a2dda17)
K1 IN-GAME CHECKLIST READY (corrected, task-5-report.md).
Task 6: dispatched (BASE a2dda17, sonnet; W4-7, W4-9/10, d2, T6 carried)
Task 6: DONE d6f8335 (868 tests)
Task 6: review → Needs fixes (1 Important, probe: rows stale after an outside change while the window is open). W4-7 kept as ruled (commands trap under their own window; bank/guild rows can Safe-Mode the bank like a typed command) — amend P6 wording at week end.
Task 6 round 1: re-render on SB_CONFIG_CHANGED and SB_FOCUS_CHANGED while shown; W4-7 test uses the real bank registration and asserts SafeMode bank on/bags off; unknown-command row message; read-only command-row test; help pointer in the settings note; keep scroll when re-showing the same page.
Task 6: fix round 1/5 (d6f8335..db86177, 872 tests). Controller check: clean tree, green — addressed.
Task 6: complete (commits a2dda17..db86177)
Task 7: dispatched (BASE db86177, sonnet; W4-2, W4-4, W4-5, W4-9/10 carried; told not to stage plan file)
Task 7: DONE 3ea5c8b (885 tests)
Plan amended b762599: Task 11 (O1 fixes, plan 6131-7444) + Task 12 (footer, 7445-8668); sessions O2, FT1; decisions D22-D27 (New hidden while empty stays until next full layout; glow errors trap "none"; overlay sizes constants; footer storage comma text; crests via SB.Crests.currencies + name words; free count main + reagent). Replayed on scratch copy at d6f8335.
Task 7: review → Approved (minors). Fix round 1/5 dispatched: layer suffix, W4-2 reset/override tests, Config.CharOverrideMany single emit, nil SettingsFocus flash, tooltip test.
Task 7: fix round 1/5 (3ea5c8b..91a5e99, 892 tests). Controller check: clean tree, green — addressed.
Task 7: complete (commits db86177..91a5e99)
Task 8: dispatched (BASE 91a5e99, sonnet; d6/a12/d7/T8 carried)
Task 8: DONE 5b34f22 (901 tests)
Task 8: review → Needs fixes (refused-drop text lacks 'stays on cursor'; empty list untested/unanswered; note rows may clip; click+drop double fire; S1 install/Esc steps). Fix round 1/5 dispatched incl. corrected S1 in report.
Task 8: fix round 1/5 (5b34f22..93f18ac, 907 tests). Controller check: clean, green — addressed.
Task 8: complete (commits 91a5e99..93f18ac)
S1 IN-GAME CHECKLIST READY (corrected, task-8-report.md).
Task 9: dispatched (BASE 93f18ac, sonnet; W4-6, c10, d9, W4-9/10 carried)
Task 9: DONE b306feb (922 tests)
Task 9: review → Needs fixes (I1 test-only: categoryOrder read-only guard untested). Partial Apply accepted (writes idempotent, setup.done last).
Ruling W4-21: the first-login quick setup waits until out of combat and outside an instance (re-check on PLAYER_REGEN_ENABLED / zone change) — the user plays keys; cost: setup appears later for a player who logs in inside a dungeon.
Task 9 round 1: I1 test; refresh() under its own trap after a successful write (no false "failed", Esc text follows setup.done); W4-21; Q1 note that /reload re-shows it until Apply/Skip.
Task 9: fix round 1/5 (b306feb..ba1f7bc, 927 tests). Controller check: clean, green — addressed.
Task 9: complete (commits 93f18ac..ba1f7bc)
Q1 IN-GAME CHECKLIST READY (task-9-report.md).
Task 10: dispatched (BASE ba1f7bc, opus; c2, c6 carried)
Task 10: DONE_WITH_CONCERNS f2e8b0b (932 tests; v.Layout doesn't clear heldKey)
Task 10: review → Approved (1 Important test gap: P5 re-check after held button frees). Fix round 1/5 dispatched (+ heldKey clear in commit, logout Safe Mode asserts, distinct trap labels).
Task 10: fix round 1/5 (f2e8b0b..ca7deab, 933 tests). Controller check: clean, green — addressed.
Task 10: complete (commits ba1f7bc..ca7deab)
W1 IN-GAME CHECKLIST READY (task-10-report.md).
Task 11: dispatched (BASE ca7deab, opus; brief replayed at d6f8335 — anchors adapted; W4-1/13/15/16, D22/D23 carried)
Task 11: DONE_WITH_CONCERNS d0d69d9 (956 tests; ApplyChanges redraws when New becomes shown; hidden-New hover relies on scroll:IsMouseOver)
Task 11: review → Needs fixes (Important test gap: no hidden-New W4-1 tests; fake allows hovered button without scroll hover). Code probe-confirmed correct. Fix round 1/5 dispatched (+ no empty New(0), ClearGlow alloc, corner test, O2 step 16, NEW_MODE_AUTO wording). Deferred: ilvl text may touch arrow (O2 steps 3/5); bank-close clear may no-op if NumSlots=0 after close.
Task 11: fix round 1/5 (d0d69d9..d209557, 960 tests). Fake ties scroll hover to button hover; hidden-New W4-1 tests; New shows only for a known slot (round-0 redraw removed as unreachable). Controller check: clean, green — addressed.
Task 11: complete (commits ca7deab..d209557)
O2 IN-GAME CHECKLIST READY (task-11-report.md; plan copy steps 16/18 stale — use the report's).
Task 12: dispatched (BASE d209557, opus; W4-14, footer growth must not move items, adapter-only currency APIs)
Task 12: DONE 3053381 (975 tests)
Task 12: review → Needs fixes (I1 item safety: screen clamp pushes the window up when a taller footer grows past the screen bottom; I2 dedup/parse tests can't fail; I3 FT1 step 14 Esc closes bags).
Ruling W4-22: with keepTop, the view height is also limited by the room below the top edge (scroll area shortens instead of the window running off-screen) — cost: fewer visible rows when the window sits low.
Ruling W4-23: a footer entry added in a future release joins at its default position (after its nearest preceding default neighbour present in the saved order), on — cost: none.
Ruling W4-24: lazy creation of plain footer frames in combat is accepted (not protected).
Task 12 round 1 also: M1 held shrink kept across ApplyChanges; M2 dirty on bags close; M3 gold keeps last known value / omitted when no number; M4 cursor test; M5 IsOwned guard; M8 CHECKS entries; M10 FT1 install line.
Task 12: fix round 1/5 (3053381..f015164, 982 tests). Controller check: clean, green — addressed.
Task 12: complete (commits d209557..f015164)
Task 12: minor (deferred → final review): room clamp can leave a very short item area if the window is dragged near the screen bottom (consider a minimum rows floor).
FT1 IN-GAME CHECKLIST READY (corrected, task-12-report.md).
ALL 12 TASKS COMPLETE. Next: final whole-branch review (opus), f48e4eb..f015164 (code from aa3fea1).
Week-4 checklists committed (docs/superpowers/plans/2026-10-03-swagbag-week4-checklists.md).
Final review: Ready after fixes (I1: W4-22 room clamp + default bottom anchor → window can't grow after first open; Pause/peek/mode end leave most of the bag hidden. I2: cooldown/lock-only inventory changes re-scan keystone and refresh footer per cast in keys).
Ruling W4-25 (I1): sizeFrame grows the window UP (moves the top edge, bounded by 75% max and the screen top, bottom kept on screen) when the mouse is not over the window and the cursor is empty; otherwise cap as now and retry via SB.Debounce("bags.grow", W.RETRY, W.Resize) — P5 holds — cost: the window's top edge can move when nothing is under the pointer.
Ruling W4-26 (I2): Signals' keystone listener and the footer listener return early unless the change includes ITEM or SIZE — cost: none.
Final fix wave also: M1 no-op world restack returns true without holding; M2 skip the area hold while the mouse is over the settings window; M3 isSecret guards (IsFishingLoot, :307 compare, currency names). Deferred: M4 title flash truncation (O2/FT1 watch), M5 no-op focus writes re-stack.
Final fix wave: DONE_WITH_CONCERNS 2034176 (992 tests; window grows down to screen bottom first, then up; M2 covers only Restack hold)
Final fix wave: scoped re-review → Approved (14 mutations fail; every sizeFrame path safe; title-bar hold necessary — keep).
Final: deferred → week 5: drag stops the grow retry and drop doesn't re-fit (call W.Resize in OnDragStop); no default-anchor (y=100) grow test; unbounded 300 ms grow retry while mouse rests; M4 title flash truncation (O2/FT1); M5 no-op focus writes re-stack; CurrencyList isHeader secret guard; consumables trap "bags" at key start (P6, noted); amend P6/constraint wording (W4-7, BackdropTemplate, "new keys").
