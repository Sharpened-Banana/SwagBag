# SDD ledger — plan: docs/superpowers/plans/2026-10-10-swagbag-week11-rule-builder.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Plan 09516e5 on week11 from main 134a6bd (0.10.0). Expected 1547 -> 1582, 4 tasks.
User: 'Do week 11' (rule builder + paste import).
User principle (2026-10-04): 'out of the box as easy and simple as possible, under the hood an insane amount of customization and power.' Ruling V0: the editor adds nothing to the bag window or quick setup; Settings > Categories sits after the everyday pages; the text view (Show the rule as text) must accept the FULL query grammar so power users are never limited by the two-level rows; check every task against both halves.
Preflight: 40 rows (preflight.md); replay exact (1582, 41/41 mutations, 20k fuzz clean). 19 findings + 5 spec conflicts. Rulings (plan amendment with full replay before Task 1):
- X1 (D1): Save refuses (one answer naming the row) while any row has a Rows.Problem (e.g. empty "name contains") — nothing saved; test.
- X2 (D2): "Add a rule", "Change" and typing in a row's value box go through the read-text-first guard; unread typed text is never lost; tests for both probes.
- X3 (D3): C.Save re-enables a category whose broken rule now compiles when enabled wasn't explicitly sent and it had an error (covers Reagents/setting-owned on/off); test.
- X4 (D4): Reset to default asks once more like Delete, its question says it also forgets items you dragged onto/off it; the editor closes after a Reset (no false "Nothing was changed"); CE1 uses a category that isn't "(changed)".
- X5 (D5): C.Delete emits "focus.sections" (not the nil everything-changed path); test asserts the path; no restack of open bags (P5).
- X6 (D6): ClearFocus on every SwagBag edit box on PLAYER_REGEN_DISABLED (combat start) so keys go back to abilities; test + CE1 step.
- X7 (D7): rule-text box maxLetters = 2 * C.MAX_QUERY so the too-long refusal is reachable; one shared constant.
- X8 (D8): when the settings window hides, clear the bags search if it is still the one "Show matches" set; test.
- X9 (D9): a renamed built-in's default name stays reserved; new category ids are never reused after a delete (monotonic counter); tests.
- X10 (D10): separate message when Baganator gold-term expansion makes a short paste exceed the limit.
- X11 (D11/SP1): a broken Save keeps the PREVIOUS working rule active and on (spec §7.5 #3) and stores the broken text as a draft with its error, shown in the editor and marked in the list; never lost (AC6.2); fixing the draft and saving replaces the rule. A new category whose first rule is broken is created switched off with the error (no previous rule). Tests.
- X12 (D12): the category list shows each category's priority number.
- X13 (D13): one shared chat-code check (Profiles + Paste + editor), one PINNED list, one MAX_QUERY constant.
- X14 (D14): a test loops over every runtime reason key and asserts the locale key exists.
- X15 (D15): paste note when a bare keyword is a prefix of others (Paste.Prefixed).
- X16 (D16): refuse chat codes (|T |H |A |K |c+8hex |cn…) in rules at Save/Create; export names broken categories (or skips them with a note) instead of producing a string that refuses at import.
- X17 (D17) rename test; X18 (D18) CE1 check for typed | positions; X19 (D19) fix stale comment.
- SP2: keep a text marker, record spec update (no icon dependency). SP3: Save runs C.Validate and the preview lists every warning (not only the first). SP4: accept adjacent-swap suggestions, spec update.
- Principle V0 stays binding.
Plan amendment dispatched (opus).
Plan amended b61b590 (1547 -> 1596; greens T1 1553, T2 1567, T3 1585, T4 1596); replay clean, 71 mutations. Accepted deviation: X9 uses categories[id] = false tombstones (schema 2) instead of a counter.
Briefs and constraints regenerated from b61b590; Task 4 brief cut at "## In-game sessions".
Task 1: dispatched (BASE b61b590, sonnet)
Task 1: implemented a91bac6 (1553); review dispatched (sonnet)
Task 1: review Needs fixes — 1 Important: round trip breaks near the length cap (FromText limit on raw text vs longer canonical ToText). Ruling: FromText measures the limit on the canonical text (rows only offered when #ToText(r) <= MAX_TEXT; else text-only with 'long'), boundary test; fold in minors 1 (built-ins evaluated semantically, not just text) and 2 (adversarial inputs no error). Fix round 1 (resume).
Task 1: fix round 1 c7b240f (1556); re-review dispatched (sonnet)
Task 1: fix round 1/5 (3 addressed, 0 open; commits a91bac6..c7b240f)
Task 1: minor (deferred): ToText errors on malformed rules (callers must pass well-formed; Problem guards editor); fuzz reference shares rowText
Task 1: complete (commits b61b590..c7b240f, review clean after fix round 1). Suite 1556 = plan +3.
Task 2: dispatched (BASE c7b240f, sonnet)
Task 2: implemented f45e632 (1570); review dispatched (opus)
Task 2: minor (deferred, FINAL CONSIDER): Import can overwrite a deleted id tombstone (X9 holds only for Create); profile snapshots keep deleted ids (preview shows raw id); leftover draft on second broken save; Preview pcall drops error/no length cap; enabled coerced; name limit counts bytes
Task 2: complete (commits c7b240f..f45e632, review clean). Suite 1570 = plan +3.
Task 3: dispatched (BASE f45e632, sonnet)
Task 3: implemented c9cdaec (1588); review dispatched (opus)
Task 3: review Needs fixes — 1 Important: X8 fails for rules with leading/trailing spaces (Slash.Run trims; SC.shown untrimmed) → bags stay dimmed after close. Ruling: fix round 1 = trim SC.shown + padded-rule test via real Slash.Run; fold in: ClearFocus on pooled inputs when hidden/re-rendered/window closed (focus never stuck); name/value boxes maxLetters above their limits so refusals are reachable (never silently cut); new-category Save never says Saved after a follow-up refusal; per-box guard in the combat ClearFocus loop. Others deferred.
Task 3: fix round 1 9626b5d (1593); re-review dispatched (sonnet)
Task 3: fix round 1/5 (5 addressed, 0 open; commits c9cdaec..9626b5d)
Task 3: minor (deferred, FINAL cheap): after a refused follow-up save of a NEW category, d.id stays nil (second Save hits TAKEN) — rebind the draft to the created id; Apply button wraps after full-width box; turned-off broken category opens as On; edited() reads db directly; preview compiles twice; spec shadows `type`; P2 count not asserted; no end-to-end over-limit value test
Task 3: complete (commits f45e632..9626b5d, review clean after fix round 1). Suite 1593 = plan +8.
Task 4: dispatched (BASE 9626b5d, sonnet)
Task 4: implemented 2c98a82 (1604); review dispatched (opus)
Task 4: minor (deferred, FINAL cheap): SC.Edit/SC.New don't clear SC.paste (latent); MAX_NOTES cap untested; oversized gold in a range passes as NAME note vs refused elsewhere; SwagBag-only syntax passes without a note
Task 4: complete (commits 9626b5d..2c98a82, review clean). Suite 1604.
Final review: dispatched (opus) over b61b590..2c98a82
Final review: With fixes — 2 Critical (data loss via existing Profiles paths exposed by the editor): (1) Profiles Undo after an import restores a stale category backup, wiping editor-made categories and tombstones; (2) Import with a same-id category silently replaces the user's own (incl. over tombstones). 1604 pass.
Final: Ruling: one fix wave (opus implementer): C1 — Profiles.CategoriesChanged() called by every category writer (Create/Save/Delete/Move/ResetBuiltin/AddToList) drops the category part of backups.profile; Undo then restores settings only; Undo's answer says when categories are included. C2 — Import gives an imported cu id that matches a live local category or a tombstone a fresh id (as Create does) and maps co; a same NAME gets a unique name ("Potions (2)"); the preview lists them ("Added as new: …"); never replaces a user category. One-liners: d.id rebind after Create; SC.Edit/SC.New clear SC.paste; paste name box maxLetters MAX_NAME+20; Save answer wording ("at the next full layout, never under the mouse"). Spec + plan session updates. — cost: an import never overwrites a user category (a friend's update arrives as a copy)
Final: fix wave dispatched (opus)
Final: fix wave 1d24742..e861537 (1614); re-review dispatched (opus)
Final: re-review — all 7 addressed, no new Critical/Important. Product consequence (tell user): re-importing your own share string adds "(2)" copies instead of restoring — a share string is no longer a category backup/restore. Minors (deferred): LOWERED preview line uses original name; co remap can move a user category to the end; ce edits still replace built-in edits wholesale and imported built-in rename can duplicate a user name; long unclaimed imported names kept; settings-only Undo may restore stale focus refs (harmless). CE1 step 38 hedged by controller.
Final: complete (week 11, 1614 tests)
