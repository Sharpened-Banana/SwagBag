# SDD ledger — plan: docs/superpowers/plans/2026-10-06-swagbag-week7-research-picks.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Plan commit 482c315 on week7-picks from main a1f7f86 (0.6.0). Expected 1281 -> 1356, 9 tasks.
User: picked items 1-7,9,12; said 'Start on next week' (build authorized).
Preflight: 36 pair rows + 9 task rows (preflight.md); mechanics replay clean (1356); 22 findings. Rulings (all carried into a plan amendment before Task 1):
- R1 Ruling: buyback cap is per VISIT (count reset on MERCHANT_SHOW); auto-sell, /swagbag sell junk and Sell all share it; going past what still fits needs a second explicit confirmation that says earlier sales leave the Buyback tab — cost: one more prompt.
- R2 Ruling: the sell/bank step re-checks Vendor.Protected (lock, equipment set, protections below) on the slot immediately before acting — cost: none.
- R3 Ruling: profile import validates every setting against a per-path validator table (type + range/allowed words); any invalid value refuses the WHOLE string with a reason; guildBank.withdrawAnyTab is never imported — cost: stricter import.
- R4 Ruling: rename the shadowing `load` helper in profiles_spec and intercept _G.load as well as loadstring — cost: none.
- R5 Ruling: Collections.lua comment must not name C_TransmogCollection; also extend check.sh's Adapter-only grep to catch bare C_* names without a dot if cheap — cost: none.
- R6 Ruling: profile undo backs up and restores categories, userEdits and categoryOrder too — cost: a bigger backup.
- R7 Ruling: preview/import compare the watch list with the current one; add a singular string — cost: none.
- R8-R18 Ruling: fix the minors in the plan: mover end-of-run wording/counts; silent combat-vendor when nothing to do; uncollected star shown even under the gold glow (separate corner); no junk coin on locked items; dedupe Pr.Follow/QuickSetup refresh, atBank, RepairCost/GuildRepairMoney; enforce Pr.MAX_LIST and drop unused exports; theme the section menu; lock.dropGuard and Vendor/Collections listeners trap under "none"; own string for invalid lock drop; refresh Locked items label; friendly names in chat and setting labels (not dotted paths) in the share preview — cost: plan rework time.
- R19 Ruling (product, gold-maker safety; tell user): auto-sell and Sell all never sell (a) items whose appearance is uncollected, (b) items with the green use/open/learn glow (caches, unlearned toys/mounts/pets/decor, knowledge), (c) gray BoE items whose AH price (Auctionator) is more than 2x vendor price; the Sell all confirmation names the AH value when it is higher than the vendor value — cost: a few grays stay in bags; user can sell by hand.
- R20 Ruling: the mover re-checks the vendor/bank is still open immediately before each UseContainerItem — cost: none.
- R21 Ruling: on first 0.7.0 login, if any saved user category/search contains the word "locked", print one note that it now means "locked by you" and the old meaning is "inuse"; a live `locked` search refreshes when a lock changes — cost: tiny.
- R22 Ruling: Task 9 brief cut at "## In-game sessions" after the amendment; week-end spec list gains: `uncollected` cache class volatile vs spec "instance"; guild-funded repair vs "no guild bank money" non-goal (option is off by default, user-chosen); imported categories get source = "import".
Plan amendment dispatched (opus) — re-replay required.
Plan amended a5b303a (1281 -> 1376; greens T1 1285, T2 1292, T3 1299, T4 1321, T5 1338, T6 1349, T7 1354, T8 1359, T9 1376); replayed clean, 124 mutations.
- Ruling (accept amendment deviations): R2 banking re-checks only bank-open (locks/sets mean "never sold", not "never banked"); R6 categories backed up only when an import carries them; R1 counts only SwagBag's own sales (hand sales not counted — stated in G14); R15 dropGuard label changed without a test — cost if wrong: a hand-sold item plus 12 auto-sales could exceed buyback (user acted by hand).
Briefs regenerated from a5b303a; Task 9 brief cut at "## In-game sessions" (R22).
Task 1: dispatched (BASE a5b303a, sonnet)
Task 1: implemented 54474a6 (1285); review dispatched (sonnet)
Task 1: ⚠️ noted: users with stored focus.sections.mplus/raid/delves won't get c_sets automatically (only-explicit-values rule; plan-intended) — mention in session notes at week end
Task 1: minor (deferred): no direct rename/reset test for c_sets; junk keyword vs junk coin disagree for gray set piece (add comment)
Task 1: complete (commits a5b303a..54474a6, review clean)
Task 2: dispatched (BASE 54474a6, sonnet)
Task 2: implemented 0c1d92e (1292); review dispatched (sonnet)
Task 2: minor (deferred): SeasonText ITEM_N fallback + no-icon footer entry untested; SeasonText unguarded inside Report.Build (a failure blanks whole report); report_spec stubs Footer; seasonCount rebuilds ID set per notification
Task 2: complete (commits 54474a6..0c1d92e, review clean)
Task 3: dispatched (BASE 0c1d92e, sonnet)
Task 3: implemented 91046d1 (1299); review dispatched (sonnet)
Task 3: ⚠️ in-game: bags-glow-white atlas; glow layering vs new-item glow; housing totalNumStored semantics; mount/pet return positions — in sessions
Task 3: minor (deferred, FINAL MUST CONSIDER): Collections.Learn pet branch r.link:match / knowledge() r.name:lower() lack isSecret guard in draw path (an error there runs under "bags" → Safe Mode)
Task 3: minor (deferred): whole cache cleared on any R.ITEM change; decor ownership changes not watched (comment); SetVertexColor only when shown (shared glow must tint every time); overlays_spec stubs Collections
Task 3: complete (commits 0c1d92e..91046d1, review clean)
Task 4: dispatched (BASE 91046d1, sonnet)
Task 4: implemented 316fac1 (1321); review dispatched (opus)
Task 4: review Needs fixes — 2 Important (plan-mandated): repair runs in combat via done→after; guild repair checks only withdraw limit, claims success, no fallback
Task 4: Ruling: (1) repair never runs in combat — it waits for OutOfCombat like the sale and re-checks vendor open; (2) add Adapter wrapper for the guild bank balance; guild pays only when min(limit, balance) >= cost (limit -1 = balance); otherwise fall back to own gold with the line saying so; success claimed only if A.RepairCost() reads 0 after the call (else say repair didn't finish). New Adapter global allowed (Adapter-only rule respected). Also fold in minor 3 (no line when nothing sold) and minor 6 (same RepairCost re-check for own gold) — cost: small extra code; user sees truthful lines
Task 4: minor (deferred): lag can undercount one sale past MAX_PENDING; stack count change skews gold total; no tests for real Adapter SellItem/MoveToBank/copperIf; run straddling two MERCHANT_SHOWs
Task 4: fix round 1 dispatched (resume implementer)
Task 4: fix round 1 implemented d596f38 (1324); re-review dispatched (sonnet)
Task 4: fix round 1/5 (3 addressed, 0 open — repair waits for combat end; guild balance + fallback + result re-read; no zero-sale line; commits 316fac1..d596f38)
Task 4: complete (commits 91046d1..d596f38, review clean after fix round 1). Suite 1324 = plan +3.
Task 5: dispatched (BASE d596f38, sonnet)
Task 5: implemented 8b2c832 (1341); review dispatched (sonnet)
Task 5: review Approved but 1 Important (plan-mandated): padlock TOP-centre 14px overlaps ilvl and upgrade arrow
Task 5: Ruling: move the padlock to a spot no existing overlay uses (implementer reads UI/Overlays.lua anchors: ilvl, arrow, track, count, junk coin, keystone, bind, new glow, learn glow); if every corner is taken, use a 10px lock at LEFT-centre; add a test asserting its rect doesn't intersect the other corner overlays' rects. Also fold in minor 2: refuse locking battle-pet cages (shared item ID 82800 would lock every caged pet) with L.LOCK_INVALID — cost: small
Task 5: minor (deferred): false-positive hand-sold warning when a same-link locked stack moves after an earlier hand sale; partial stack sales undetected; KeywordNote userEdits/watch branches untested; Locks.Clear emits on n==0; brittle English-string tests
Task 5: fix round 1 dispatched (resume implementer)
Task 5: fix round 1 implemented ada1178 (1343); concern: BoE badge (off by default) also LEFT-centre — may overlap lock when both on; re-review dispatched (sonnet)
Task 5: fix round 1/5 (2 addressed, 0 open — padlock 10px LEFT-centre with no-overlap test; caged pets refused; commits 8b2c832..ada1178)
Task 5: minor (deferred): bind badge (off by default) shares LEFT-centre with padlock — overlap when both on
Task 5: complete (commits d596f38..ada1178, review clean after fix round 1). Suite 1343 = plan +5.
Task 6: dispatched (BASE ada1178, sonnet)
Task 6: implemented 420b8a5 (1354); review dispatched (opus)
Task 6: review Approved, 1 Important (plan-mandated): StaticPopup re-show cancels pending → Yes silent (P2)
Task 6: Ruling: fix via popup data (job passed to StaticPopup_Show, OnAccept(self,data)) or noCancelOnReuse; fold in minors: escape % in category names in popup text (a Lua error there is outside SwagBag's trap), singular sell question, StaticPopup_Hide on MERCHANT_CLOSED — cost: small
Task 6: minor (deferred): stale menu counts / menu not closed on combat start; hint shown when section has nothing to act on; SectionSlots includes collapsed cells; no collapse-style Shift test; onLeave untested; real A.AllowedInBank untested; CHECKS row order
Task 6: fix round 1 dispatched (resume implementer)
Task 6: fix round 1 implemented 966cd42 (1356); re-review dispatched (sonnet)
Task 6: fix round 1/5 (4 addressed, 0 open — popup data, % escape, singular, hide on close; commits 420b8a5..966cd42)
Task 6: minor (deferred, FINAL MUST CONSIDER + in-game): shared StaticPopupDialogs text — confirm the on-screen question always matches the job Yes will run when a second question replaces the first (BK1 step)
Task 6: complete (commits ada1178..966cd42, review clean after fix round 1). Suite 1356 = plan +7.
Task 7: dispatched (BASE 966cd42, sonnet)
Task 7: implemented cc2bbad (1361); review dispatched (sonnet)
Task 7: ⚠️ resolved: A.AuctionatorPrice rejects secret/NaN/inf (Adapter.lua ~1291) — controller check
Task 7: minor (deferred, in-game): top-N worth line may be computed from bags only if the bank window isn't populated 0.1 s after open — no bank-layout retrigger; check in BK1
Task 7: minor (deferred): IsWorth calls stackValue twice; secret-price test absent (plan-mandated title); top-mode/retrigger handlers untested; custom slash amount shows no selected button
Task 7: complete (commits 966cd42..cc2bbad, review clean)
Task 8: dispatched (BASE cc2bbad, sonnet)
Task 8: implemented b93590c (1366); review dispatched (sonnet)
Task 8: ⚠️ check.sh bare-C_ gate: plan amendment replay showed the old Collections comment makes check.sh fail (amendment report) — accepted
Task 8: minor (deferred): SectionActions.lua:7 protection comment stale (no uncollected); no star geometry test (in-game check); vendor nil-look case only indirect; report mutation-1 count wrong (8 tests)
Task 8: complete (commits cc2bbad..b93590c, review clean)
Task 9: dispatched (BASE b93590c, sonnet)
Task 9: implemented 415a921 (1383); review dispatched (opus)
Task 9: review Needs fixes — 3 Important (2 plan-mandated): imported category queries not compiled; cu ids may be new/free/built-in; category name/query unbounded + | codes
Task 9: Ruling: fix all three (refuse the WHOLE string on any bad category: query must compile via SB.Query.Compile; cu ids must match the user-id shape and not equal a built-in or reserved section id; ce ids only built-in ids; name/query <= MAX_STRING and no "|"), plus minors: version >= 1; category numbers range-checked; category with neither name nor query refused; encode numbers with %.17g; Export reads defensively (skip non-string/number order entries) — cost: stricter import
Task 9: minor (deferred): import stores values equal to defaults (defensible); preview names replaced categories only by count; bank/guild windows follow on load (check)
Task 9: fix round 1 dispatched (resume implementer)
Task 9: fix round 1 cd7f584 (1385). Ruling: query | rule too broad (would refuse 'herb|cloth', 'ore|reagent'); refuse only real escape openers in queries: |T |H |A |K (uppercase) and |c followed by 8 hex digits; names keep refusing any | — fix round 2 (resume) — cost: none
Task 9: fix round 2 006b6ff (1385); re-review of rounds 1-2 dispatched (opus)
Task 9: fix rounds 1-2 (8 findings addressed, 0 open; commits 415a921..006b6ff)
Task 9: minor (deferred, FINAL SHOULD FIX): imported cu category with empty query (match-all) + priority up to 1000 can take every item; |cnNAME: named-colour escape passes queries
Task 9: complete (commits b93590c..006b6ff, review clean after 2 fix rounds). Suite 1385.
Final review: dispatched (opus) over a5b303a..006b6ff
Final review: With fixes — 0 Critical, 2 Important (unknown uncollected look sellable; one-click Unlock all, no undo), 6 Minor. check.sh 1385 pass. FINAL MUST CONSIDER items triaged: T3 defer (existing pattern), T6 resolved in code (in-game BK1), T9 empty query not match-all (hasRule) — |cn fix folded in.
Final: Ruling: one fix wave: Important 1 (Adapter distinguishes cannot-collect vs unknown; unknown look on gray armor/weapon = protected for selling; don't cache unknown on sell path) + Important 2 (Unlock all asks first via type-again / popup AND keeps a one-step `lock undo`) + minors: star lowered/shrunk off the arrow + geometry test, junk coin hidden when Vendor.Protected, vendor.repair added to profile NEVER list, pcall SeasonText in Report, SectionActions comment, |c[nN] escape, cap imported category priority < 100; plus week-end docs (sessions: star/arrow/padlock eye-checks, unlock confirmation; spec update list items) — cost: small, all safety-direction
Final: fix wave dispatched (sonnet)
Final: fix wave done 6063728..238e3a1 (1394 tests). Note: gray rings/necks/trinkets (no appearance source) now count as unknown look → never auto-sold (minor, user-visible; could treat no-appearance equip slots as cannot-collect later)
Final: scoped re-review dispatched (sonnet)
Final: re-review — all 11 addressed, no new Critical/Important. Minors (deferred): VENDOR_KEEPS doesn't mention unknown-look gray gear; gray jewelry never auto-sold; own priority >=90 refused on import (export doesn't clamp); |c[nN] also refuses unspaced 'herb|cname'; Protected on draw path (small cost); "all 1 locks" plural; star clearance model-only (LN1 eye-check). VN1 step 18 wait fixed by controller (doc only).
Final: complete (week 7 HEAD after doc fix, 1394 tests)
