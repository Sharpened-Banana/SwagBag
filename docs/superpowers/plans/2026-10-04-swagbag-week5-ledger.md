# SDD ledger — plan: docs/superpowers/plans/2026-10-04-swagbag-views-syndicator-themes.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md. Branch week5-views from main d759564 (week 4 merged), plan commit 19330aa, 992 tests. Plan replayed on a fresh clone (totals 1014…1115). Prior ledgers: week3, week4 (W3-*, W4-* bind).
Preflight: preflight.md (29 findings). ALL proposed rulings ADOPTED as binding (cite F-number in dispatches). Before Task 1: F1 (format51 required from spec/runner.lua so every spec incl. Adapter specs is strict), F2 (guard pattern handles + space # flags and skips %%), F3 (row tooltip scripts trap "none", D23 precedent; amend P6), F5 (row name colour from record.quality via Adapter helper, link colour fallback; |cnIQ tags), F24 (click on row text flashes "Click the icon on the left…" — P2). Before Task 2: F6 (SetScale self-check: if scale didn't take, draw that layout as categories + chat line; L1 step: switch view in combat then use a potion), F7 (New holds 8 rows in list; L1 loot ≥5 step), F8 (Value column repaints on SB_PRICES_CHANGED), F9 (reagent free row says it's for reagents). Later: F14 amend no-schema-bump wording; F15 write guild only when non-empty; F19 SB_ALTDATA_CHANGED needs a listener or drop; F20 counts only on main + chat-link tooltips; F22 alt viewer re-sorts loaded items; F12/F13 TH1 look checks.
Task 1: dispatched (BASE 19330aa, sonnet; F1 F2 F3 F5 F24 carried)
Task 1: DONE 0358a83 (1022 tests). Carry to T2: pass the flash callback as 3rd arg of ListRows.New. P6 amendment wording in task-1-report.md (apply at week end).
Task 1: review → Needs fixes (ghost-row click silent; click answer lost with no callback; consumables_spec duplicate weaker %s guard). LIST_ROW_CLICK ratified. Fix round 1/5 dispatched (+ %q, non-string fmt, desc fallback, NaN, row level/contract, short empty-row text).
Task 1: fix round 1/5 (0358a83..f1379a9, 1028 tests). Controller check: clean, green — addressed.
Task 1: complete (commits 19330aa..f1379a9)
Task 2: dispatched (BASE f1379a9, opus; flash callback, F6 scale self-check, F7, F8, F9 carried)
Task 2: DONE_WITH_CONCERNS 4959d59 (1051 tests; F6 recorded as none; added-slot scale failure has a one-tick window)
Task 2: review → Needs fixes (Important, probe-confirmed: sizeChanges shows a scale-failed new slot at full size in the list while the fallback is held under the mouse).
Ruling W5-1: showAt never shows an unscaled button in list view (hide it + schedule the categories fallback) — cost: a new slot can be briefly invisible.
Ruling W5-2: F6 error-ring entry recorded under "none" (label bags.listScale) — ratified (a "bags" label would trigger Safe Mode).
Task 2 round 1 also: list scroll step; L1 F7 step "keep the mouse off the bag"; optional profession-bag tile text. Note: after a fallback the view button still reads per the setting (chat line explains).
Task 2: fix round 1/5 (4959d59..57e7cab, 1054 tests). Ruling W5-3: showAt fallback request uses W.RETRY not 0 (no per-frame loop if listFailed ever breaks). Fix round 2/5 dispatched.
Task 2: fix round 2/5 (57e7cab..e53c44e, 1054 tests). Controller check: clean, green — addressed.
Task 2: complete (commits f1379a9..e53c44e)
Task 3: dispatched (BASE e53c44e, opus; a2 alignment test, F6/F26 + F7 L1 steps, P5 held re-sort carried)
Task 3: DONE_WITH_CONCERNS d9db62d (1069 tests; quiet flag on Flash/SortList; L1 steps 24-26 rewritten)
Task 3: review → Needs fixes (double chat line on view/scale paths when title truncated; L1 multi-action steps). Ruling W5-4: callers that return their own answer pass quiet (SetView/SetScale flag). Fix round 1/5 dispatched (+ truncation L1 step, no-layout test, Sort guard, SET_LIST_DESC wording).
Task 3: fix round 1/5 (d9db62d..904f147, 1074 tests). SET_LIST_ASC → "Lowest first" accepted. Controller check: clean, green — addressed.
Task 3: complete (commits e53c44e..904f147)
L1 IN-GAME CHECKLIST READY (60 single-action steps, task-3-report.md).
Task 4: dispatched (BASE 904f147, sonnet; F12/F13, W5-4 quiet, live switch in combat)
Task 4: DONE ece9ca7 (1087 tests)
Task 4: review → Needs fixes (incomplete palette accepted/saved then breaks header creation under 'bags' (P6); deviation untested). Ruling W5-5: validate palette, restyleAll under ErrorTrap none with rollback, HeaderColor never throws. Fix round 1/5 dispatched (+ record palette/available errors, hardening tests, flat title size).
Task 4: fix round 1/5 (ece9ca7..8d12450, 1096 tests). Controller check: clean, green — addressed.
Task 4: complete (commits 904f147..8d12450)
Task 5: dispatched (BASE 8d12450, sonnet; W5-5 validation, F12/F13 TH1 steps)
Task 5: DONE 53a80db (1107 tests)
Task 5: review → Needs fixes (TH1 wording only; code sound vs ElvUI v13.97). Fix round 1/5 dispatched (+ font size clamp, nil palette when media gone, SetFont comment).
Task 5: fix round 1/5 (53a80db..6f5598b, 1109 tests). Controller check: clean, green — addressed.
Task 5: complete (commits 8d12450..6f5598b)
TH1 IN-GAME CHECKLIST READY (task-5-report.md).
Task 6: dispatched (BASE 6f5598b, sonnet; F14 F15 F16 F17 carried)
Task 6: DONE 4587caa (1125 tests; Adapter.IsInGuild added)
Task 6: review → Needs fixes (3 Important plan-mandated: vacuous per-container index test; guildName wrong on hyphenated realms; available() errors swallowed).
Ruling W5-6: guild link cleared only when IsInGuild()==false AND PLAYER_GUILD_UPDATE fired this session — cost: none.
Ruling W5-7: AltData index prebuilt once 5 s after login, out of combat (retry on REGEN) so the first tooltip in combat does no build work (~20 ms measured under PUC Lua) — cost: one idle build per session.
Task 6 round 1 also: mock IsInGuild nil unless set; IsInGuild nil-branch tests; current-row class; Own exempt from switch-off; stack traces via xpcall; F16 test var rename.
Task 6: fix round 1/5 (4587caa..7fc7aad, 1133 tests). Controller check: clean, green — addressed.
Task 6: complete (commits 6f5598b..7fc7aad)
Task 7: dispatched (BASE 7fc7aad, sonnet; F17 F18 F19 carried, adapter-only Syndicator)
USER F1 RESULT 2026-10-01 21:35: all pass (9 N/A); report shows 0.3.0 — game was still running the week-3 code (not fully restarted after week-4 install).
Task 7: DONE 14b538a (1150 tests)
Task 7: review → Needs fixes (Important, probe vs real v284: GetInventoryInfoByItemID never returns nil → Syndicator always answers, Own never does; pets always empty).
Ruling W5-8: Syndicator counts → nil when nothing non-zero (before appending Own guilds); nil for pet cages — cost: none.
Ruling W5-9: F17 fold-in — current character via Adapter.SyndicatorCurrentKey() (GetCurrentCharacter) — cost: none.
Task 7 round 1 also: more Syndicator events through the debounce; single cold-miss rebuild; report line single call; test/doc gaps.
Task 7: fix round 1/5 (14b538a..78ddfcc, 1156 tests). Controller check: clean, green — addressed.
Task 7: complete (commits 7fc7aad..78ddfcc)
Task 8: dispatched (BASE 78ddfcc, sonnet; F20, F21 memo, taint-free hook, auto default)
Task 8: DONE d52e545 (1176 tests)
Task 8: review → Needs fixes (TooltipLine pcall swallows errors (plan-mandated); A1 step 10 can't verify F20). Fix round 1/5 dispatched (+ memo cap 500, drop dead HookScript fallback, A1 single actions, hint line order).
Task 8: fix round 1/5 (d52e545..04802c2, 1180 tests). Hint line stays below counts (client clears tooltip in SetBagItem) — accepted. Controller check: clean, green — addressed.
Task 8: complete (commits 78ddfcc..04802c2)
A1 IN-GAME CHECKLIST READY (38 steps, task-8-report.md).
Task 9: dispatched (BASE 04802c2, opus; F22, plain display buttons only, none traps, no arrows)
Task 9: DONE_WITH_CONCERNS 2c0cb21 (1200 tests; newRows 1; guild bank has the same pending-item gap — out of scope, note for week 6)
Task 9: review → Needs fixes (duplicated P5 hold; plan-mandated: alts' gear always "unbound" → soulbound shown as sellable BoE). Item safety sound.
Ruling W5-10: offline non-guild bind-on-equip items have unknown bind: no BoE badge/keyword, priced as bound (vendor) — cost: a truly unbound BoE on an alt shows vendor value in the viewer.
Task 9 round 1 also: RequestLayout reuse; no-drag assertion; idle handler exit; Canon name lookup + ambiguity; RefreshAll includes viewer; reagent bag kind; pool-size test.
Task 9: fix round 1/5 (2c0cb21..03e32f6, 1208 tests). bindUnknown=false (not nil) so it's categorised; Prices.Bound(record) used by 3 callers (live behaviour unchanged: isBound/isWUE booleans). Controller scoped check: diff read, green — addressed.
Task 9: complete (commits 04802c2..03e32f6)
Task 9: minor (deferred → final review): search not re-applied after a held RequestLayout lands via GroupView retry (bank window same) — wire cfg.onUpdated → searchBox.Apply.
Task 10: dispatched (BASE 03e32f6, sonnet; F23, onUpdated search re-apply, OF1 + exit check)
Task 10: DONE dd7a337 (1216 tests; GroupView.RequestLayout now calls cfg.onUpdated — affects bank/guild too)
Task 10: review → Needs fixes (source text unclamped; OF1 multi-action steps & weak W5-10 step; missing picker/onUpdated tests; duplicated searchBox.Apply in bank/guild). onUpdated cross-window change judged safe (search only). Fix round 1/5 dispatched.
Task 10: fix round 1/5 (dd7a337..fac27f5, 1223 tests). Controller check: clean, green — addressed.
Task 10: complete (commits 03e32f6..fac27f5)
OF1 + week-5 exit check READY (task-10-report.md).
ALL 10 TASKS COMPLETE. Next: final whole-branch review (opus), 19330aa..fac27f5 (code from d759564).
Week-5 checklists committed (docs/superpowers/plans/2026-10-04-swagbag-week5-checklists.md).
Final review: Ready to merge (0 Critical/Important; 5 Minor fixed in one wave). Main open risk is in-game: F6 SetScale in combat (L1 step 14).
Ruling W5-11 (M2): offline non-guild items with static bind pickup/account/warbound/wue price as bound (vendor), matching live bags — cost: none.
Final fix wave: 704d112 (1226 tests; toc_check pins OptionalDeps, updated). Controller scoped check: diff read, green — approved.
Final: deferred → week 6: list view for bank/guild windows (D9); guild bank pending-item relayout gap; Syndicator loaded mid-session callbacks; amend P6/no-schema-bump/BackdropTemplate constraint wording; in-game: F6 SetScale in combat (L1 step 14), IsTruncated timing, ElvUI media timing, ItemButton template-less behaviour.
