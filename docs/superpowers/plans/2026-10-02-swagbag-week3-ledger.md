# SDD ledger — plan: docs/superpowers/plans/2026-10-02-swagbag-week3-banks-overlays.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Branch: week3-banks (created by controller; base a7cd430). No task creates the branch.
Ruling: user approved week 3 (subagent-driven) with overlays + avg-ilvl title moved to the front (D18), 2026-10-02.
Preflight: 81 rows; 182 blocks replay; totals 427→590 match; 29 mutations confirmed; no forward refs, no Blizzard writes, no C_/Enum leaks.
Ruling W3-1 (T1,T2): when SwagBag's window is re-applied while Blizzard's frame is already tiny/hidden (host.IsActive()), stay tiny/full and only restore our position — never flip to beside/view; test for bank and guild — cost: none.
Ruling W3-2 (T1,T2 tests): "never writes Blizzard state" tests use a STRICT fake that logs every method call (incl. modelled ones like SetScript) and assert the write-list is empty — cost: test work only.
Ruling W3-3: add the five missing guarded-behaviour tests (incl. collapse hover guard, guild Safe Mode gate) in their owning tasks; rewrite the tinyhost test that cannot fail — cost: test work.
Ruling W3-4 (checklists): G2 step 7 reworded (item sits in New, no faded copy); B1 step 4 / G2 step 6 name an item the bank doesn't hold; B1 step 5 "move the mouse off" before the expected move; G1 steps 5,7-10 add "move the mouse off it"; any session after a task that adds files says full restart, not /reload — cost: none.
Ruling W3-5 (F6): guild "withdrawals left" re-read on every guild slot change (GUILDBANKBAGSLOTS_CHANGED) as well as its own event — cost: one call per update.
Ruling W3-6 (F8): section-header errors in bank/guild windows trap with the owning window ("bank"), not "bags" — pass window through the header owner — cost: small.
Ruling W3-7 (F9,F10): Auctionator update callback wrapped in ErrorTrap; g/s/c money suffixes move to Locale — cost: none.
Ruling W3-8 (F11): fix F1 in both bank and guild windows now; shared bank-window shell deferred to week 5 — cost: ~200 duplicated lines until then.
Ruling W3-9 (F12): snapshot is CAPTURED at bank/guild close (even in combat); only the SavedVariables write is deferred to out-of-combat — cost: none.
Ruling: W3-1 applies to automatic re-application only; an explicit user '/swagbag bank beside' out of combat may switch to beside immediately — it's the user's choice — cost: none.
Task 1: review → Needs fixes (1 Important, probe-confirmed: restoring BankFrame anchors writes stale/empty points — unproven write, can make BankFrame invisible). Ruling: TinyHost touches only BankFrame's PARENT; points only for re-hosted TabSystem — cost: none.
Task 1: minor (deferred): tabs Blizzard adds/re-anchors mid-visit not re-hooked/re-placed until next visit (watch V2 step 4); Keep() bumps gen when nothing queued; spec §5.4/§5.2 wording (beside direction, "tabs above") to update at week end.
Task 1: fix round 1/5 (5 addressed, 0 open; commits 1aaa19f..f8bcd46; probe re-run: BankFrame keeps Blizzard's anchor)
Task 1: complete (commits a7cd430..f8bcd46, review clean after 1 fix round)
V2 IN-GAME CHECKLIST READY (task-1-report.md / plan Step 7). Tab labels "Bank"/"Warband Bank" unverified in 12.1.
Task 2: review → Needs fixes (1 Critical probe-confirmed: Safe Mode/refused Open still shrinks GuildBankFrame → invisible vault every visit after any error; 1 Important probe-confirmed: hiding our window mid-visit leaves invisible open vault eating bag right-clicks — also checking BankWindow for same).
Ruling W3-10: guildBank.withdrawAnyTab defaults FALSE until G1 proves the client honours the tab argument (else a different item could be withdrawn silently) — cost: user must click the tab first.
Ruling W3-11: whenever SwagBag's bank/guild window hides while the interaction is still live, restore Blizzard's frame (visible) — an invisible open bank/vault is an item-safety hazard — cost: Blizzard's window pops up after X/Esc if the visit continues.
Task 2: minor (deferred): drag/left-click pickup skip the no-withdrawals refusal; slot events mark in-flight tab loaded early; every slot change re-reads all tabs (perf; Task 10 rewrites); caged pets show empty (GetItemInstant nil); 784-button first-open cost vs §9 unmeasured.
USER REQUEST 2026-10-02 (W3-12): collapse Free into ONE real empty-slot button showing the free count (default), option "show every free slot". Separate tile for reagent-bag empties (own count). Tile = first real empty slot button (drops/splits are Blizzard's own); when it fills, next empty button takes the same spot. Applies to bank/warband groups later. Insert as new task right after Task 4 (bag overlays), via a plan amendment once Task 2's fix agent is done editing the plan file.
Ruling: V2 checklist steps 11-12 (X/Esc) reworded for W3-11 (Blizzard's bank becomes visible while the visit is live) — folded into the free-slot plan amendment; spec §5.6 wording updated at week end.
Task 2: fix round 1/5 (5 addressed, 0 open; commits a3e7802..2b37296; probes confirm no invisible vault/bank incl. error-driven Safe Mode and combat-deferred cases)
Task 2: complete (commits f8bcd46..2b37296, review clean after 1 fix round)
Task 2: minor (deferred): Adapter guild actions detect only Lua errors, not server refusals; GUILD_USAGE omits anytab; bank W3-1 test doesn't fire REGEN (covered by another test).
G1 IN-GAME CHECKLIST READY (17 steps; plan G1 section / task-2-report.md).
Plan anchors for withdrawAnyTab (T4 i05, ~10285) + D5 row: sent to the plan-amendment agent to fix.
Plan amended (W3-12 free tile = new Task 5; renumbered 1-13; stale anchors + Task 11 whole-file replacements merged with Task 2 fixes; D5 rewritten; V2 steps 11-12 rewritten). Totals 493→625.
Ruling W3-13 (D19): with the free tile on, a button emptied in New joins Free so the tile count is always the real count (spec §4.3 "repaint only" amended); guild bank has no tile — cost: an emptied New slot leaves New immediately.
Task 3: dispatched (BASE beca4e9, sonnet)
Task 3: DONE 6fff2a2 (507 tests)
Task 3: review → Needs fixes (1 Important plan-mandated: 2H vs 1H main + empty off hand returns false; AC9.3 says sum with empty=0).
Ruling W3-14: two-hander rule = if main hand holds a 2H compare ilvl > main, else 2*ilvl > main+off (empty=0) — per AC9.3 — cost: none.
Ruling W3-15: Pawn verdict replaces only the ilvl rule; pending/unusable gates run first — AC9.3 "never" — cost: none.
Ruling W3-16 (minor 3): keep Pawn nil→false fold — Pawn's nil also means "not an upgrade", returning nil would let ilvl override Pawn's no — cost: when Pawn lacks data no arrow; add O1 check line.
Ruling W3-17 (minor 4): an equipped slot whose ilvl can't be read marks the comparison unknown (no arrow) instead of 0; add the two equip APIs to A.CHECKS — cost: brief miss on login until items load.
Minors 5,6,7 fixed in the same round (c_keystone diff test; Short keeps apostrophes inside words and drops possessive 's; one GetItemUpgradeInfo call per slot).
Task 3: fix round 1/5 (commits 6fff2a2..b737fee, 509 tests). A.HasUpgradeTrack removed; UpgradeInfo(link, bag, slot) returns (track, hasTrack).
Ruling W3-18: later plan text calling A.HasUpgradeTrack (plan ~3644/3653) must use the second return of A.UpgradeInfo instead — carry in that task's dispatch — cost: none. Test totals in later briefs run +2 from here.
Task 3: re-review round 1 → Needs fixes (W3-17 only in mock, real EquippedItems still 0; report claim false). Fix round 2/5 dispatched (also drop mock-only UpgradeInfo params).
Task 3: fix round 2/5 (commits b737fee..bee962f, 510 tests; real EquippedItems now sets unknown; mock-only params removed; fixture slot 3 link changed to "item:225001::upgradable"). Scoped re-review by controller: diff read, check.sh green — addressed.
Task 3: complete (commits beca4e9..bee962f, after 2 fix rounds)
Task 3: minor (deferred): wand INVTYPE_RANGEDRIGHT as 2H, GetMapUIInfo first return, Pawn behaviour — verify in O1.
Task 4: dispatched (BASE bee962f, sonnet)
Task 4: DONE_WITH_CONCERNS 199c0a0 (526 tests; atlas-missing fallback concern)
Task 4: review → Needs fixes (1 Important: Ov.Context cached while an equipped ilvl is unknown → no arrows for that slot all session).
Ruling W3-19: never cache a context with an unknown equipped entry; when one is unknown, schedule a debounced RefreshAll retry (1 s, up to 10 tries per unknown episode) so arrows appear once gear loads without the user acting — cost: ≤10 extra redraws after login.
Task 4: minors fixed in round 1: atlas-fallback test; one names list; SETTINGS_READONLY + non-number/secret tests. Deferred: RefreshAll each() wrapper; reagent tint in every view (watch F1); Pawn gate on guild records → carry to Task 12 dispatch (W3-20).
Task 4: fix round 1/5 (199c0a0..805dc3e, 530 tests). Controller re-review: W3-19 retry counter increments per button call → cap exhausted in one redraw + N equipment re-reads. Fix round 2/5 dispatched (cache + pending flag, count firings).
Task 4: fix round 2/5 (805dc3e..f364506, 531 tests). Controller scoped re-review: cache + retryPending + count firings — addressed.
Task 4: complete (commits bee962f..f364506, after 2 fix rounds)
Task 4: minor (deferred): retryPending stays true if RefreshAll errors inside the retry (ErrorTrap catches; no more retries that session); each() wrapper; reagent tint in all views (F1); Blizzard's own UpgradeIcon/JunkIcon may double up (O1 steps 5/10).
Ruling W3-20: Task 12 dispatch must check Overlays Pawn gate (record.bag + BagKind) against guild records' bag field.
O1 IN-GAME CHECKLIST READY (task-4-report.md).
Task 5: dispatched (BASE f364506, opus — layout invariants)
Task 5: DONE 30cf920 (547 tests; concern: emptied item in combat hides button via render())
Task 5: review → Needs fixes (1 Important plan-mandated, probe-reproduced: tile-ness re-reads bag family live; unequipping a profession bag loses its family's tile, spares hidden until reopen).
Ruling W3-21: each key's family is stored when it joins (Build/ToFamily) and isTile/partner/promote/Position use the stored value; a bag swap in an equipped bag slot (existing bag-change handling) requests a guarded full layout (RequestLayout) — cost: one regroup per bag swap, held while the mouse is over items.
Task 5: minors fixed in round 1: C_Container leak in adapter_spec; randomized test gains added/removed + changing family fn + per-family 0→1 minimums; tile number restored after a held drop is picked back up. Deferred: CreateFontString in combat unproven → add a combat tile swap to F1.
Task 5: fix round 1/5 (30cf920..b39b645, 550 tests; BAG_CONTAINER_UPDATE via SB.On → RequestLayout)
Task 5: re-review → Approved (W3-21 mutation confirmed; BAG_CONTAINER_UPDATE guarded, no loop).
Task 5: complete (commits f364506..b39b645, after 1 fix round)
Task 5: minor (deferred): BAG_CONTAINER_UPDATE unproven for same-size swap; full layout on every BAG_CONTAINER_UPDATE while open; tile FontString created in combat unproven — both added to F1 (controller addendum in task-5-report.md).
F1 IN-GAME CHECKLIST READY (task-5-report.md + addendum).
Task 6: dispatched (BASE b39b645, opus)
Task 6: DONE_WITH_CONCERNS 551627c (562 tests; inventory handler reordered: ApplyChanges first, paintTiles only if nothing redrawn)
Task 6: review → Approved (no Critical/Important; reorder judged behaviour-neutral).
Task 6: complete (commits b39b645..551627c, clean first review)
Task 6: minor (deferred): past-size test only via full render; cellsOf lists cells without B.Get (ForEachSlot skips).
Ruling W3-22: Task 8 (first owner pass) adds owner.window to SectionHeaders and window = kind=="bags" and "bags" or "bank" in SetParentFor/EnsureCapacity ErrorTrap labels (P6) — carry in Task 8 dispatch — cost: none.
Task 7: dispatched (BASE 551627c, sonnet)
Task 7: DONE b2e0d93 (564 tests)
Task 7: review → Approved (minors: isolation test can't catch shared failedId/lastEvalError/stats; no overlapping-debounce test). Fix round 1/5 (test-only) dispatched.
Task 7: fix round 1/5 (b2e0d93..10407b3, test-only, 565 tests; both mutations caught). Controller scoped check: spec-only diff, check.sh green.
Task 7: complete (commits 551627c..10407b3)
Task 7: minor (deferred): SearchBox.New doesn't assert required o fields; TOPLEFT 14,-30 hard-coded for every box (Task 8/9 may need an offset).
Task 8: dispatched (BASE 10407b3, opus; W3-22 carried)
Task 8: DONE_WITH_CONCERNS 73ee8af (589 tests; placeholder tooltip scripts still trap as bags)
Task 8: review → Needs fixes (1 Important plan-mandated: Restack hover guard (P5) survives deletion — no test; preflight F3 carried).
Ruling W3-23 (extends W3-22): placeholders carry a window label in a side table (AcquirePlaceholder(..., window)); their scripts trap with it; GroupView passes its window — cost: none.
Ruling W3-24: a click on a GROUP header with an item on the cursor toggles the group (no drop target there) — P2 — cost: none.
Task 8 round 1 also: GroupView repaints tiles when no redraw ran (Task 5 parity); freeTile lookup-cap test; timed push ≤5 ms; rename 1,078-slot test; assert cfg.child; SectionHeaders comment; clear redrawPending after Restack.
Task 8: fix round 1/5 (73ee8af..695bcf9, 597 tests; Restack mutation caught by 2 new tests). Controller scoped re-review: production diff read (W3-23 side table, W3-24 group header never a drop target incl. onDrop, paintTiles when not drawn — redraw returns bool), check.sh green — addressed.
Task 8: complete (commits 10407b3..695bcf9, after 1 fix round)
Task 8: minor (deferred): push-budget 5 ms test is a weak guard (lookup caps are the real one); placeholderWindow clear-on-release untestable (Acquire overwrites); randomized overlap check compares top-left only.
Task 9: dispatched (BASE 695bcf9, opus)
Task 9: DONE_WITH_CONCERNS 7ccd1f7 (616 tests; title flash may run under 5 buttons)
Task 9: review → Approved (minors only). Fix round 1 anyway (cheap, P5/P2-relevant):
Ruling W3-25: a bank visit starts with no "new" marks in that kind's bags (ScanKind clears newSet for them); the tabs-settings path flushes pending dirty bank bags before rescanning — cost: deposits from the previous visit no longer show as New.
Ruling W3-26: bank title text is bounded (RIGHT to the leftmost title button, no word wrap) so feedback flashes never run under buttons — cost: long flashes truncate with ellipsis (B1 watch).
Ruling W3-27: queued bank-slot growth after combat re-requests the bank layout when the window is open — cost: one guarded layout.
Task 9: fix round 1/5 (7ccd1f7..2cc8522, 621 tests; 6 new mutations caught). Controller scoped re-review: Inventory diff read (FlushKinds re-arms others; ScanKind visit clears newSet by bag prefix), check.sh green — addressed.
Task 9: complete (commits 695bcf9..2cc8522)
Task 9: minor (deferred): reagents-only bank tab family trusts client (B1 watch); BAG_UPDATE-before-BANKFRAME_OPENED ordering unverified (B1).
Task 10: dispatched (BASE 2cc8522, sonnet; W3-9 capture-now/write-later carried)
Task 10: DONE_WITH_CONCERNS af68235 (638 tests; logout writes bags even in combat; bankOpen guard on timers)
Task 10: review → Needs fixes (2 Important, probe-confirmed: queued combat write lost at logout/reload; 0-slot read during visit blanks good bank snapshot).
Ruling W3-28: PLAYER_LOGOUT (not read-only) stores every pending queued snapshot (bank/warband/guild), captures bank+warband if bankOpen, then bags — cost: none.
Ruling W3-29: a bank/warband container with saved size>0 is never replaced by a captured size-0 container; a capture totalling 0 slots is not written — tabs can't be un-bought — cost: a truly emptied-to-0 container is impossible, so none.
Task 10 round 1 also: per-guard tests (outer bankOpen, read-only); SaveGuild serializes up front; budget trigger 1.45 MB; B1 note about /reload at the bank.
Task 10: fix round 1/5 (af68235..ec67601, 653 tests; per-guard mutations each fail alone). Controller scoped re-review: Snapshots diff read (pending tables, logout flush order, W3-29 guard in store, guild serialized up front, per-guild queue key) — addressed.
Task 10: complete (commits 2cc8522..ec67601)
Task 10: minor (deferred): PLAYER_LOGOUT runs all stores in one trapped handler — an error in one skips the rest (wrap each in week-4 hardening); Bytes() undercounts ~1-3%.
B1 IN-GAME CHECKLIST READY (task-10-report.md + fix-round note).
Task 11: dispatched (BASE ec67601, opus; whole-file replacement verified safe — no edits since 2b37296)
Task 11: DONE_WITH_CONCERNS c7d485e (659 tests; any slot event during U's query = U's answer → may briefly read U empty; refused-pickup chat line untested; DescribeLink hasUpgradeTrack=false)
Task 11: review → Needs fixes (4 Important, 2 probe-confirmed; 2 plan-mandated): foreign event marks U answered → empty layout, snapshot blanked, items land in New; cache never reset on guild change → other guild's items shown/saved, right-click acts on a different real item; SaveSnapshot saves all cached tabs; DescribeLink hasUpgradeTrack hard-coded false; refused left-pickup untested.
Ruling W3-30: a query event counts as U's answer only if U reads ≥1 item; an empty read is "known empty" only after U's own retry also reads empty; otherwise U stays unanswered, queue waits for timedOut — cost: a truly empty tab shows "(loading...)" ~0.6 s longer.
Ruling W3-31: an unconfirmed empty read never replaces a non-empty cached tab or saved tab snapshot (guild analog of W3-29) — cost: none.
Ruling W3-32: GW.cache is keyed by A.GuildKey(); cleared when the key differs at Open and on PLAYER_GUILD_UPDATE — cost: no instant reopen after a guild switch.
Ruling W3-33: slot actions (click, drag, right-click) refuse with a chat line while their tab is not answered this visit; right-click withdraw re-reads the slot live and acts only if it matches what is displayed (else refresh + chat line) — cost: one extra API read per right-click.
Ruling W3-34: SaveSnapshot saves only tabs answered this visit that are in GW.order — cost: none.
Task 11: fix round 1/5 (c7d485e..330a758, 672 tests). Concern: truly empty tab with no events stays loading all visit (safe side; G2 watch).
Task 11: re-review round 1 → Needs fixes (W3-30 both-empty rule untested; Requery early return when querying==tab can strand a tab all visit). Fix round 2/5 dispatched (+ pin 3 surviving mutations; sameItem compares link too).
Task 11: fix round 2/5 (330a758..fa4903b, 677 tests). Controller scoped re-review: production diff is the one-line Requery early-return removal (queue de-dup kept); new tests pin W3-30 both-empty, mid-visit guild update, sameItem link, confirmedEmpty reset — addressed.
Task 11: complete (commits ec67601..fa4903b, after 2 fix rounds)
Task 11: minor (deferred → G2 watch): a tab with no slot events stays "(loading...)" all visit (safe); re-query may be sent while our window is hidden (read-only); real client: does an unqueried tab read nil or stale? does GUILDBANKBAGSLOTS_CHANGED fire for an empty tab?
Task 12: dispatched (BASE fa4903b, sonnet; W3-20 carried)
Task 12: DONE_WITH_CONCERNS ac5f363 (681 tests; bank in-place Apply + guild describe Apply unpinned)
Task 12: review → Approved (minors: unpinned bank in-place + guild describe Apply; context-once-per-pass untested). Test-only round 1 dispatched.
Task 12: fix round 1/5 (ac5f363..8787055, test-only, 684 tests; 3 mutations caught). Controller check: spec-only diff, green.
Task 12: complete (commits fa4903b..8787055)
Task 13: dispatched (BASE 8787055, sonnet)
Task 13: DONE_WITH_CONCERNS e01265b (699 tests; added RefreshHeaders/RefreshTotals for count-only changes; Auctionator DB update doesn't redraw open headers)
Task 13: review → Needs fixes (W3-7 not applied: unguarded Auctionator callback + hard-coded g/s/c; RefreshHeaders/RefreshTotals churn the header+placeholder pools on nearly every loot).
Ruling W3-35: Warbound-until-equipped items price at vendor like bound items (they can't be auctioned either; D11's reason) — cost: WuE gear shows low values.
Ruling W3-36: an Auctionator DB update invalidates the cache and, debounced 0.5 s, emits SB_PRICES_CHANGED; open windows refresh header text in place (no layout) — cost: one cheap pass per scan burst.
Ruling W3-37: overflowed New items are counted in Free's total (where their buttons sit) — accepted; noted in P1 — cost: Free can show a value while New is full.
Task 13 round 1 also: in-place SetLabel refresh (no Acquire/Release); prices sanitised (finite, ≥0); Auctionator api resolved once per fill.
Task 13: fix round 1/5 (e01265b..342f0ff, 706 tests). Controller scoped re-review: SetLabel in place (no acquire/release, '#' skipped, labels side table cleared on release), RefreshHeaders gated on shown, SB_PRICES_CHANGED wired — addressed.
Task 13: complete (commits 8787055..342f0ff)
P1 IN-GAME CHECKLIST READY (task-13-report.md).
ALL 13 TASKS COMPLETE. Next: final whole-branch review (opus).
Final review: dispatched (opus, a7cd430..342f0ff)
Final review: Ready after fixes (0 Critical, 1 Important: guild first-answer layout held while mouse anywhere over window → items sit in Free under "(0)" headers; 8 Minor).
Ruling W3-38: GroupView.RequestLayout computes the new positions and holds only when a button that would move is busy (mouse over it / item on cursor) — same guard as redraw/Restack; P5 kept — cost: none.
Ruling W3-39: /swagbag reset carries chars/warband/guilds snapshots into the new DB and leaves them out of backups.reset — cost: reset no longer clears snapshots (use a future /swagbag snapshot clear).
Ruling W3-40: a section header click with an item on the cursor in a window with no onDrop (guild) collapses the section like a plain click (P2) — cost: none.
Final fix wave also: guild title bounded (W3-26 parity); bags title bounded to leftmost visible title button incl. "Bank still open"; bags snapshot with 0 total slots not written (W3-29 parity); ScanKind restores Inv.scanned on error; FlushKinds before bank close capture; view toggles in bags/bank/guild honour a failed Set (read-only).
Final fix wave: DONE_WITH_CONCERNS b3f85a5 (718 tests; held rebuild every 300 ms while hovering a moving button; describe repaints during held build)
Final fix wave: scoped re-review → Approved (all 9 items, mutations re-run; 718 tests).
Final: deferred minors → week 4: held-retry rebuild every 300 ms (re-arm without rebuild while same button busy); M8 tests for guild/bags toggles; drag onto guild section header swallows the following click; PLAYER_LOGOUT stores in one trapped handler; xpcall traceback in ScanKind.
