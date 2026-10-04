# SDD ledger — plan: docs/superpowers/plans/2026-10-08-swagbag-week9-sort-tsm-masque.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Plan 785b78c on week9 from main ae00814 (0.8.0). Expected 1452 -> 1491, 6 tasks.
User: 'Merge and install 8. Lets go for 9' (scope = remaining picks 8/10/11 + polish, my default).
Pre-ruling R0: the gray-BoE 'worth >2x at auction' sell protection always asks an AH source (Auctionator or TSM, whichever is loaded) even when the display price source is Vendor — gold-maker safety; carried into Task 3 — cost: protection may differ from displayed value.
Preflight: 31 pair rows + 6 task rows (preflight.md); replay clean (1491). 20 findings. Rulings (carried into a plan amendment with full replay before Task 1):
- S1 Ruling: implement R0 as Prices.AuctionValue(link,itemID) asking every loaded AH provider (ignores prices.source; own cache cleared by Invalidate); worthMoreAtAuction protects when ANY AH price > 2x vendor; tests for Vendor-source + Auctionator high (kept) and no AH addon (sells); fix tip text, D13, Vendor.lua comments, AC17.2; Sell-all AH sentence uses AuctionValue too.
- S2 Ruling: a TSM "no price" answer is not cached (or cached <= 30 s) so TSM data arriving after login is picked up.
- S3 Ruling: the Stacker leaves game-locked slots (AH/mail/trade) out of read(), and waits only on the two slots of the move just made — no false "stuck".
- S4 Ruling: step checks still() (window open) and combat FIRST, before judging the last move — closed bank reports "closed".
- S5 Ruling: new A.CursorBusy() true for any GetCursorInfo() answer; used by Stacker, MoveStack guard, put-back, and the week-7 Mover's cursor wait.
- S6 Ruling: a vendor opened during a stacking run queues the auto-sell Visit to run when the run ends if the vendor is still open (no silent skip).
- S7 Ruling: the "TSM price" Settings row sets only prices.tsm (never switches prices.source); /swagbag price tsm X keeps switching as documented.
- S8 Ruling: St.Start runs the first step under ErrorTrap.Run("stacker.step","none",...).
- S9/S10 Ruling: spec-update list gains §1.3 non-goals (TSM), §2.3, P4, F10/AC10.2, and the §4.2 rule 5 exception for the held F6 fallback rescale.
- S11 Ruling: TSM price must be > 0 to count.
- S12 Ruling: A.TSMPrice resolves the TSM API lazily.
- S13 Ruling: Profiles VALID and Settings choices built from A.TSM_PRICES; one shared stackSort.
- S14 Ruling: fix the Skins "without Masque" test so it can fail; check the last Sk.Add against asked.
- S15/S17/S19 Ruling: session text fixes (drag each small stack to a different empty bank slot; MQ1 bank group at login; MQ1 step 4 names padlock, reagent mark, star, gold glow, learn glow).
- S16 Ruling: add a setting "Warn about other bag addons" (default on) in Settings + /swagbag; D16 notes undetected UI suites.
- S18 nit: fix Stacker header.
- S20: ledger only (bind-state swap counted as merge; low risk; in-game G1/G2 cover).
Plan amendment dispatched (opus).
Plan amended af0b084 (1452 -> 1503; greens T1 1469, T2 1476, T3 1489, T4 1496, T5 1500, T6 1503); replay clean, 70 mutations. Accepted deviations: S2 TSM miss cached 30 s; S8 error in a step ends the run; added D19 (vendor visit waits for stacking run).
Briefs regenerated; Task 6 brief cut at "## In-game sessions".
Task 1: dispatched (BASE af0b084, sonnet)
Task 1: implemented 4931409 (1469); review dispatched (opus)
Task 1: ⚠️ carried: P5 mouse check only via job.busy — Task 2 must always pass busy (incl. list rows) and still; done may fire synchronously inside Start → Task 2 must not overwrite the answer (P2)
Task 1: minor (deferred): "error" stop prints stuck wording; empty-error refusal records nothing; MAX_PENDING path untested; not-loaded item excluded whole run; run machinery duplicated with Mover; Mover.IsBusy uses CursorBusy
Task 1: complete (commits af0b084..4931409, review clean)
Task 2: dispatched (BASE 4931409, sonnet)
Task 2: implemented b7e69b6 (1477 = brief+1); review dispatched (sonnet)
Task 2: minor (deferred): St.SortButton flashes STACK_NOTHING for a "combat" refusal (unreachable today); no list-view stacker busy test; run survives close+quick reopen (same scope); MOVER_BUSY reused
Task 2: complete (commits 4931409..b7e69b6, review clean). Suite 1477 = plan +1.
Task 3: dispatched (BASE b7e69b6, sonnet)
Task 3: implemented 3a6f9a0 (1490); review dispatched (opus)
Task 3: minor (deferred, FINAL SHOULD FIX — sell safety): AuctionValue trusts a cached "no price" on the sell path (30 s TSM / until DB update for Auctionator) — sell path should re-ask misses
Task 3: minor (deferred): TSM names hardcoded in PRICE_STATE/USAGE strings; source words listed thrice; report cached count approximate; adapter_spec after_each clears issecretvalue globally
Task 3: complete (commits b7e69b6..3a6f9a0, review clean). Suite 1490 = plan +1.
Task 4: dispatched (BASE 3a6f9a0, sonnet)
Task 4: implemented 53fbf84 (1497); concern overlays vs Masque layers; review dispatched (sonnet)
Task 4: Ruling: overlays-under-Masque left to in-game MQ1 step 4 (skin-dependent; raising overlays would touch Overlays.lua) — cost if wrong: padlock/star/glow dimmed under some skins until a follow-up
Task 4: minor (deferred): Skins.Add silent on MasqueAdd false (no failure count); flush clears queue before loop; no offline test for list rows/SetScale with Masque
Task 4: complete (commits 3a6f9a0..53fbf84, review clean). Suite 1497 = plan +1.
Task 5: dispatched (BASE 53fbf84, sonnet)
Task 5: implemented 8a376eb (1501); review dispatched (sonnet)
Task 5: minor (deferred): redundant type guards inside pcall; A.OtherBagAddons unprotected in Report.Build
Task 5: complete (commits 53fbf84..8a376eb, review clean). Suite 1501 = plan +1.
Task 6: dispatched (BASE 8a376eb, sonnet)
Task 6: implemented b8cd057 (1504); review dispatched (sonnet)
Task 6: ⚠️ S10 §4.2 rule-5 spec note belongs to week-end spec update (final fix wave)
Task 6: minor (deferred): custom worth button visible unselected in top/off mode; 100/500/1000 listed twice; no "recorded once" assertion across held attempt
Task 6: complete (commits 8a376eb..b8cd057, review clean). Suite 1504.
Final review: dispatched (opus) over af0b084..b8cd057
Final review: With fixes — 0 Critical, 2 Important (sell path trusts cached AH miss; spell-targeting cursor not busy), minors. 1504 pass.
USER REQUEST (2026-10-03, mid-final-review): "New items should go in New regardless of what mode, at the top." Clarified via question: items SKIPPED New entirely (looted/bought while a mode was active → straight to their category); New should hold an item UNTIL THE USER HOVERS IT (like Blizzard's new-item glow), at the top in every mode, then it joins its category on the next open.
Final: Ruling: fix wave (opus implementer) covers Important 1 (AuctionValue fresh flag on the sell path; rebuild sources), Important 2 (CursorBusy includes SpellIsTargeting via Adapter), cheap minors (error-stop wording, MAX_PENDING test, refresh custom worth button), the week-end spec updates incl. §4.2 rule-5 exception, AND the user's New request as its own TDD item — cost: larger fix wave; New behaviour is a design change reviewed by an opus re-review
Final: fix wave b3274d5..9a30914 (1522). New: own session 'unseen' set in Inventory.lua (Blizzard flag cleared on close per W4-15); cause = full layout only asked categorizer; concerns: swapped-out gear shows in New; New uncapped at open. Re-review dispatched (opus)
Final: re-review — all 7 + 3 concerns addressed/acceptable, no new Critical/Important. Minors (deferred): AC4.4/§4.3 don't mention hover for pending items; `new` search keyword vs New section are different sets; unseen mark can drop across multi-flush server sort; consume+loot same flush may miss New; Safe-Mode arrivals pile into New; window layout guards use CursorItem not CursorBusy (per spec wording). NW1 step 7 wording fixed by controller.
Final: complete (week 9, 1522 tests)
