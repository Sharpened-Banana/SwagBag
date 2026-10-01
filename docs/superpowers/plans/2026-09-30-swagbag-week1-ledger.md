# SDD ledger — plan: docs/superpowers/plans/2026-09-30-swagbag-week1-foundations.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Branch: week1-foundations (created by controller before Task 1; branch base 52abc97)
Ruling: work on an in-place branch, not a git worktree — the WoW AddOns symlink (scripts/install.sh) must point at a stable repo path — cost if wrong: none for isolation (single developer, main untouched).
Ruling: Task 1's "create branch week1-foundations" step is already done by the controller; implementer must skip it — cost if wrong: none.
Preflight: 121-row table in preflight.md (70 pair rows, 24 per-task, 27 defect/constraint). Code blocks reproduce 174 tests under Lua 5.5 shim.
Ruling P1 (Task 12 vs 18): BagsWindow must fire its layout event AFTER the window is shown, so SearchBox re-applies dimming on open — spec AC5.1 — cost if wrong: one reorder.
Ruling P2 (Task 6): test failure text names BindKind, not BagKind — plan typo — cost: none.
Ruling P3 (Review Focus wording D3.14→D3.16; #3 wording): doc-only, no code change; reviewers judge against code — cost: none.
Ruling P4: wrap the scale-title timer (Task 12), ReportBox/DebugV1 drag scripts (Tasks 8, 19) and the slash dispatcher prologue (Task 7) in SB.ErrorTrap.Guard/Run — spec P6 — cost: trivial.
Ruling P5: Task 17 extracts one shared item-level helper used by both `gear` and `ilvl`; window-setup duplication across files deferred (minor) — cost: small refactor later.
Ruling P6: rename misnamed tests (Task 10 "SIZE plus empty slots"; Tasks 16/17 "spec 7.4 example") to describe what they actually assert, or make them use the spec's exact §7.4 queries — cost: none.
Ruling P7: accept spec deviations — migration backup in SwagBagDB.backups (spec's separate global would not persist without TOC change); error shown beside box; V4 n/a until placeholders; desk spike F deferred to week 2; no build field; ~53 query tests in week 1 (spec's 150 is a v1.0 target) — cost: spec text slightly stale, update at week-2 plan.
Ruling P8: fix comments (Commands.lua → UI/SearchBox.lua; Items.lua must not name C_Item in comments to keep the Adapter-only grep honest) — cost: none.
Ruling P9: "no CreateFrame in combat" applies to item buttons and pool growth; plain frames allowed (spike-verified) — cost: none.
Ruling P10: first-open 25 ms budget reported via /swagbag report timings in a later week; D3.17 user-facing button count = 228 + 98 × purchased bank tabs — cost: none.
Ruling P11: verify Enum override names with /dump during in-game session D2 — cost: one in-game check.
Task 1: complete (commits 52abc97..f2acf46, review clean; ⚠️ items verified by controller: luajit/luac/luacheck present, check.sh ALL CHECKS PASSED)
Task 1: minor (deferred): toc_check passes silently if both versions missing; io.popen not nil-checked; before_each outside describe unfriendly; after_each error lost when test already failed; no self-test of runner FAIL output/exit code
Task 2: review → Needs fixes. Ruling: P8 (and the plan's Adapter-only constraint) scopes to shipped addon files under SwagBag/; spec/ test files may name C_* as test data — the plan's constraint says "Everything else calls SB.Adapter" about addon code, and my dispatch wording over-broadened it — cost if wrong: none (check.sh greps SwagBag/ only). Findings 1–2 closed by this ruling; report-accuracy issue noted.
Ruling: commit trailers must be exactly `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` per Global Constraints even when a cheaper model implements; amend in fix round — cost: trivial.
Ruling: afa7b64 keeps its Haiku trailer (no history rewrite); all later commits use the Opus 5.5 + Claude-Session trailer — cost: one cosmetic trailer.
Task 2: fix round 1/5 (2 addressed, 0 open — real Resolve/IsSecret tested + non-table guard; trailer; commits afa7b64..cac64b9)
Task 2: complete (commits f2acf46..cac64b9, review clean after 1 fix round)
Task 2: minor (deferred): Stub.Install clears unknownEvents so load-time RegisterEvent failure can't be simulated; Adapter local isSecret alias; locale dynamic-key list hardcoded; locale_spec uses POSIX find
Task 3: complete (commits cac64b9..542d4c2, review clean; ⚠️ test count 32 vs brief 30 = +2 tests from Task 2 fix round — resolved by controller)
Task 3: minor (deferred, FLAG FOR FINAL REVIEW): ErrorTrap can itself throw if Adapter.Stack/Print/SM.Enable/Emit listener errors inside the handler/OnError → escapes into WoW entry point; Describe(unknown window) throws; ET.count unused; untested: secret path, nil args through Run, still-failing with nil window, combat=false, SB_SAFEMODE_CHANGED emit, Describe check/schema; Trim per-element remove
Task 4: complete (commits 542d4c2..2561f7a, review clean; ⚠️ SafeMode emits SB_SAFEMODE_CHANGED and suite green — verified by controller)
Task 4: minor (deferred, FLAG FOR FINAL REVIEW): OutOfCombat drain doesn't stop if combat restarts mid-drain; debounce key concat runs untrapped in timer; untested: throwing queued entry, window flip from OOC/Debounce, unknown-event handler not registered; handlers added mid-Emit run same dispatch; generations never pruned
Task 5: review → Needs fixes (2 Important, plan-mandated). Ruling: fix both — spec §8.5 says a newer schema is never touched and a failed migration keeps a backup; the plan's code violates that for mixed account/char versions and in Reset — cost if wrong: small extra code.
Ruling (carry to Task 8): boot wiring must assign Config.db/Config.charDB back to the SwagBagDB/SwagBagCharDB globals after Init and after Reset, or new/reset tables never persist.
Task 5: fix round 1/5 (3 addressed, 0 open — newer-check before upgrade; Reset backs up live tables + keeps backups; lastError reset; commits f5983e5..ff494fb)
Task 5: complete (commits 2561f7a..ff494fb, review clean after 1 fix round)
Task 5: minor (deferred): Reset before Init copies nil; test (c) mutates Config.CURRENT/migrations — verify restore; tonumber accepts fractional/string schemaVersion; Set(path,nil) removes override; CharOverride(path,true) no-op when Get nil; Get returns default tables by reference; Set("") errors; no test for failing char migration/mixed status RANK
Task 6: complete (commits ff494fb..d04fa2d, review clean, opus reviewer)
Task 6: minor (deferred): Enum override keys may not match real 12.1 spellings (silent fallback); IsToy may be true for every item if GetToyInfo echoes non-toys; pcall(C_Ns.Fn) throws on nil namespace (covered by required checks); no test for 17-value GetItemInfo unpack; GetSlot secret-checks only itemID
IN-GAME CHECKS for D2 session: /dump Enum.ItemConsumableSubclass ; /dump Enum.ItemTradegoodsSubclass ; /dump Enum.ItemBind ; /dump C_ToyBox.GetToyInfo(6948) (hearthstone, non-toy → expect nil)
Ruling: in-game sessions D2/D3/D4 (Tasks 8/13/18) do not block the build; checklists go to the user as they become ready and findings return as fixes. User asked (2026-10-01) to start the week-2 plan immediately after Task 19's final review; prefer D3 results before week-2 layout work builds on the bags window — cost if wrong: rework in week 2.
Task 7: review → Needs fixes (2 Important: P4 test didn't exercise SlashCmdList entry/prologue; fallback CMD_FAILED print untrapped). Fix round 1 dispatched to original implementer.
Task 7: fix round 1/5 (3 addressed, 0 open — real P4 entry-point test; fallback print pcall'd; bank assert + comment; commits 72cc926..5690cf4)
Task 7: complete (commits d04fa2d..5690cf4, review clean after 1 fix round)
Task 7: minor (deferred): Blocked 20-cap and FORBIDDEN-for-SwagBag untested; Report serialize has no cycle guard; Print-stub test restores only on success path
Task 8: complete (commits 5690cf4..6297a52, review clean, opus reviewer)
Task 8: minor (deferred, FLAG FOR FINAL REVIEW): SetSafe ignores Config.Set=false under read-only schema and silently overrides schema/check Safe Mode; DoReset keeps old error log (decide+test); commands_spec lacks after_each clearing globals; extra DoReset asserts; ReportBox no SetClampedToScreen / EditBox height; install.sh read under set -e on EOF; PLAYER_LOGIN assumes ADDON_LOADED succeeded
Task 9: review → Needs fixes (1 Important: C_Item named in Items.lua comment — check.sh grep only matches `C_X.` with a dot, so bare names in comments slip through). Fix round 1 dispatched.
Task 9: ⚠️ booleans contract — Adapter returns for isWUE/onCooldown/inEquipmentSet/hasUpgradeTrack/isUsable/isToy may be nil not false; FLAG FOR FINAL REVIEW (check Task 6 Adapter coercion).
Task 9: fix round 1/5 (3 addressed, 0 open; commits a9fdcd9..a8cada4). Controller note: Key fallback for no-link records is tostring(itemID) (brief code), not "item:<id>"; test asserts actual behaviour — acceptable, no collision with link keys.
Task 9: complete (commits 6297a52..a8cada4, review clean after 1 fix round)
Ruling: check.sh's Adapter-only grep matches `C_X.`/`Enum.` usage only; bare names in comments are reviewer-enforced, not grep-enforced — tightening the grep deferred to final review — cost: occasional comment slip caught by review.
Task 10: review → Needs fixes (2 Important: P6 test name still overclaims; no late-DELAYED / multi-bag storm regression tests). Fix round 1 dispatched (+ lastFlush only on real flush, ignore failed item loads).
Task 10: minor (deferred): Flush clears dirty before scan (lost marks on mid-scan error); `snap ~= nil or nil` cryptic; growth reports SIZE with empty changes (consumers use Size()); Inv.R/FLAGS duplicate values
Task 10: fix round 1/5 (4 addressed, 0 open; commits bf72910..f9b7f1f). Note: late-DELAYED test fires at 0.40s not 0.24s (race just before failsafe untested) — minor (deferred); TDD RED evidence for storm test not credible (report accuracy).
Task 10: complete (commits a8cada4..f9b7f1f, review clean after 1 fix round)
Task 11: complete (commits f9b7f1f..f0857da, review clean, opus reviewer)
Task 11: minor (deferred, FLAG FOR WEEK 3 + FINAL REVIEW): EnsureCapacity queued growth is last-wins (use max-merge pending[bag]); CreateAll partial on mid-loop error never retries; SetParentFor after frame creation is a no-op (week-3 bank windows); SetAtlas fallback never triggers (returns false, doesn't throw); UpdateCooldown errors swallowed by pcall; tabs purchased after login get no buttons
⚠️ verify in-game D3: FetchPurchasedBankTabIDs returns tab IDs at PLAYER_LOGIN before bank opened (Report "Buttons:" line should be ~228 + 98×tabs)
Task 12: complete (commits f0857da..22a7007, review clean, opus reviewer)
Task 12: minor (deferred, FLAG FOR FINAL REVIEW): add frame:SetDontSavePosition(true) (client layout-cache competes with our saved position); combat-queued growth never re-layouts; permissive fake frames hide API typos; scaleTitle Guard untested; SIZE/COOLDOWN branches + surplus-hide untested; position persistence across reload untested; stale header comment line 105; Ctrl+wheel does full Layout; spec globals leak (UIParent/UISpecialFrames/IsControlKeyDown)
Ruling: hooksecurefunc("OpenAllBags", ...) is allowed — spec §10.1 lists it; the forbidden token is calling OpenAllBags( — cost: none.
Task 13: complete (commits 22a7007..0baa73f, review clean, opus reviewer)
Task 13: minor (deferred, FLAG FOR FINAL REVIEW — user-visible): CloseAllBags hook closes a user-opened window when a vendor/mailbox closes (track autoOpened, honour frame arg); ToggleBag/OpenBag not hooked → single bag-bar icon clicks do nothing; OpenAllBags/CloseAllBags hooks untested; D3 wording fixed by controller when handing to user
Task 14: review → Needs fixes (1 Important: Focus #5 odd-input tests missing). Ruling: spans are byte offsets (document + test), Tokenize(nil) guarded — error display (Task 18) must work in bytes — cost: underline off by one per multibyte char in non-English names (English-only launch).
Task 14: fix round 1/5 (8 addressed, 0 open; commits 9bdd316..c3f7009). Minor (deferred): pattern-char test asserts only no-throw, not token types.
Task 14: complete (commits 0baa73f..c3f7009, review clean after 1 fix round)
Task 15: review → Needs fixes (2 Important: deep nesting stack overflow re-raised → throws (~3k levels in-game); "" and "!" untested). Fix round 1 dispatched with depth limit 100.
Ruling: nesting depth capped at 100 (parens + !) with positioned error — nobody types >100 levels — cost: pasted absurd queries get an error instead of a result.
Ruling: a comparison whose left side is a multi-word phrase (`a b ilvl>5`) is a positioned parse error AND_BEFORE_COMPARISON — spec §7.2 numeric := WORD op NUMBER, §7.5 adjacent words are not implicit AND — cost: user must type `a b & ilvl>5`; may diverge from Syndicator (desk spike F in week 2 checks).
Task 15: note for Task 18 UI: trailing-operator errors point at EOF (n+1); underline should use `after`/preceding token.
Task 15: fix round 1/5 (4 addressed, 0 open; commits 42ce427..6d9d9bf). Combined !/( share one depth counter (intended).
Task 15: complete (commits c3f7009..6d9d9bf, review clean after 1 fix round)
Task 16: review → Needs fixes (1 Important: tri-state truth tables incomplete — broken NOT passes). Fix round 1 dispatched (+ leaf normalisation, Eval-propagates test, exact error messages, "" matches-all pinned).
Ruling (HAND-OFF to week-2 Categorizer): Query.Eval propagates keyword errors by design; the categorizer MUST wrap each category's evaluation (pcall/ErrorTrap) and mark only that category errored/disabled — spec §7.10 — cost if forgotten: one bad category breaks all categorization.
Task 16: minor (deferred): #ilvl / bare ilvl on value-only keywords gives confusing message / silent name match; duplicated `same` helper in query_spec; Validate crash/value branches unreachable (comment); cache-class not tested inside NOT/parens.
Task 16: fix round 1/5 (5 addressed, 0 open; commits 910469a..4993106; RED proven for NOT)
Task 16: complete (commits 6d9d9bf..4993106, review clean after 1 fix round)
Task 17: controller amended HEAD commit message (no content change; trailer was already Opus 5.5 despite report) dff56cd → e197d23.
Task 17: review → Needs fixes (3 Important, plan-mandated): tradeable counts WuE as tradeable; equipped WuE classed warbound not soulbound; instance cache key ignores isWUE. Ruling: fix all (spec/user goal — gold-maker sell filters) — cost: small. Also reagent excludes keystones; BoP/quest fixtures set bound.
⚠️ IN-GAME CHECK (D4): does C_Item.IsBound return true for unequipped WuE / account-bound items in 12.1? (affects wue/bound keywords)
Task 17: minor (deferred): warbound nil for pending item with instant isWUE; thin positive-match coverage for many type keywords; bare `gear` memoized per link (perf only)
Ruling: a bound quest item counting as soulbound is fine (quest items are character-bound in WoW) — cost: none.
Task 17: fix round 1/5 (5 addressed, 0 open; commits e197d23..efd765d)
Task 17: complete (commits 4993106..efd765d, review clean after 1 fix round)
Task 17: minor (deferred): bind="wue" with isWUE=false gives wue=true but warbound=false (warbound keys off isWUE only)
Task 18: complete (commits efd765d..22124db, review clean, opus reviewer). Report file missing; controller verified check.sh: 233 passed, ALL CHECKS PASSED; D4 checklist taken from brief + reviewer additions.
Task 18: minor (deferred, FLAG FOR FINAL REVIEW): error line too narrow (word wrap off); underline can leave the box when text scrolls; eval-error records flood the 10-entry ring (record once per query id); cooldown/new/usable searches go stale (COOLDOWN branch doesn't re-describe); slash search causes a redundant debounced pass; thin LOADED/clear/count tests
Task 19: complete (commits 22124db..6706a86, review clean)
Task 19: minor (deferred): combat drag of V1 strip may raise false blocked entries (skip drag in combat); V1 steps lack "needs ≥1 usable item"/tally guidance; Fill doesn't break at 6 / no repaint; no test asserts SetBagID/SetID calls
ALL 19 TASKS COMPLETE. Final whole-branch review next.
Final review (opus): Ready to merge with fixes — 7 items (3 Important: ErrorTrap escapes, CloseAllBags closes user-opened window, search error truncated; 1 Medium: ToggleBag; 3 small). Fix list at final-fix-list.md. Everything else triaged deferred (see final review triage).
Ruling: OOC drain mid-combat-restart is not a defect (lockdown can't change within one synchronous run; queue swapped before drain) — per final reviewer.
Final fix wave: 7/7 implemented (commits 6706a86..9dae563; 252 passed). Scoped re-review: 2 residual Important + 1 Minor.
Ruling (residual, load-bearing → carry as week-2 Task 0): SearchBox error-line anchors — replace RIGHT anchor with TOPRIGHT to frame (-8,-26) + SetJustifyV("TOP"); prescribed anchors likely stretch the line over the item grid — cost if wrong: D4 shows the red error mid-window until fixed.
Ruling (residual, needs in-game evidence → week-2 Task 0 + D3 check): vendor auto-close may break if Blizzard's OpenAllBags internally calls ToggleBackpack/ToggleBag (hooks fire before ours, clearing autoOpenedBy); verify in D3 step 11; harden by recording open-time in onBagKey — cost if wrong: bags stay open after closing a vendor.
Ruling (residual minor → week 2): ToggleBag hook should accept only numeric IDs 0-5; KindOf(nil) would flip bags Safe Mode; autoOpenedBy can go stale after Esc.
No second fix wave per process; residuals surfaced to the user at finish.
