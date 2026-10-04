# Week 11 preflight: the category editor and paste import (plan 09516e5, base 134a6bd)

This was a read-only scan. The only file added to the repo is this one; it is git-ignored under `.superpowers/sdd/`. All the work ran in a scratch clone.

## Replay

I made a fresh clone of `134a6bd` at `/tmp/sb11pf`. A script (`/tmp/sb11pf_replay.py`) read the plan file. For each task it applied the Step 1 blocks, ran the suite, applied the Step 3 blocks, ran `scripts/check.sh`, and committed.

- Every find block matched exactly once: 4 + 5 + 9 + 3 + 9 code edits, plus 6 Create steps.
- The four task briefs are byte-identical to the plan's task sections, apart from one trailing newline. `global-constraints.md` is identical to the plan's section.

| Task | Step 2 (plan) | Step 2 (replay) | Step 4/5 (plan) | Step 4/5 (replay) | `git status` = Step 6 `git add` list |
|---|---|---|---|---|---|
| T1 | 1547 / 6 failed | 1547 / 6, the same 6 names | 1553 / 0, TOC 77, ALL CHECKS PASSED | same | yes (5 files) |
| T2 | 1553 / 8 | same, same names | 1561 / 0, TOC 77 | same | yes (3) |
| T3 | 1561 / 11 | same, same names | 1572 / 0, TOC 78 | same | yes (6) |
| T4 | 1561 / 21 (7 new + 14 in settings_categories) | same, same names | 1582 / 0, TOC 79 | same | yes (6) |

**Mutations.** I applied all 41 listed mutations (7 + 9 + 12 + 13), each to its own task's replayed commit, and ran the whole suite each time. Every one made its named test fail: 41 of 41 killed.

**Extra fuzz (mine).** I ran 20,000 random strings (ASCII 32–126, UTF-8, NUL, tab, newline, `|`, `||`, gold pieces) through `Paste.Translate` and `Rows.FromText`. There were 0 Lua errors. Every string Paste read compiles. For every string Rows accepted, `ToText` equals `Query.Pretty` of the parsed tree.

**Probes (mine).** I drove the finished page with the plan's own test helpers in a throwaway spec, which I then deleted. The results are quoted in the findings below.

## 1. Cross-task rows (shared files and interfaces)

| # | Pair | Shared file / interface | Verdict |
|---|---|---|---|
| X1 | T1–T3 | `Engine/Query/Rows.lua`: T3's two edits anchor on T1 text (`local _, SB = ...`, the end of `Rows.Problem`) and add `Nearest` | consistent |
| X2 | T1–T3 | The Rows API the editor uses: `FromText` reasons → `L["CAT_WHY_"..why:upper()]`, `Problem` → `L["CAT_PROBLEM_"..why]`, `FAMILIES[].label` → `L[fam.label]`, `NUMBER_OPS`, `NewRow`, `KindOf`, `ToText` | consistent (D2: the editor bypasses its own read-text-first guard on two paths) |
| X3 | T1–T4 | Query/Rows vs Paste: both reuse the existing lexer, parser and `Compile`, so there is no second parser. Paste does not use Rows. | consistent |
| X4 | T1/T2/T4 (+ Profiles) | Limits: `Rows.MAX_TEXT`, `C.MAX_QUERY`, `Paste.MAX` and `Profiles.MAX_STRING` are all 500, in four places, against "one place each" | consistent values (nit D13) |
| X5 | T2–T3 | `Categories` writers ↔ `SettingsCategories` (`CheckName`, `Create`, `Save`, `Delete`, `Move`, `Preview`, `ResetBuiltin` now answering true). The why codes map to `refusal()`. `pinned`, `priority`, `builtin` and `edge` fall back to `CAT_UNKNOWN`, but the page cannot produce them. | **conflict** (D3: a fixed Reagents rule stays off) |
| X6 | T2–T4 | `Create(name, query, "import")`, and `CheckName` used by `freeName()` | consistent |
| X7 | T2–T3–T4 | `C.Preview` ↔ `previewRows`; T4 changes the signature to `(out, text, noHint)` with matching edits 4–6 | consistent |
| X8 | T3–T3/T4 | The settings `input` row (`get`/`set`/`commit`/`maxLetters`/`boxWidth`; `button` is declared but unused) used by the name, value, text and paste boxes | consistent (D7: the text box's limit cuts silently) |
| X9 | T3–T4 | Search box "Show matches": both views run `run("search " .. text)`, i.e. `UI/SearchBox.lua`, which dims only. The search stays after the settings window closes and is re-applied at every bag open. | consistent with D6 (risk D8) |
| X10 | T2 ↔ Focus | `Delete` edits account `settings.focus.sections[mode]` and this character's `overrides["focus.sections."..mode]`, both layers. `sectionNames` filters stale ids. Collapsed sets are this character's `ui.collapsed[window][id]`. | consistent (D5: the change event uses the nil path) |
| X11 | T2 ↔ consumables watch list | `Engine/Consumables.lua` stores `{query | itemID, threshold, name}`, never a category id. Delete is correctly silent here. | consistent |
| X12 | T2/T3/T4 ↔ Profiles / share strings | The `u_` slug (at most 26 characters, `[%w_]`) passes `idOk` (`^u_[%w_]+$`, at most 40). Priorities 1–89 match `Pr.MAX_PRIORITY - 1`. The name rule `[%c|]` matches Profiles. `C.PINNED` copies `Pr.PINNED`. | consistent (dup nit D13; export risk D16) |
| X13 | T1–T3–T4 | `Locale/enUS.lua` chain: T1 anchors `REPORT_LOCKS`, T3 anchors `KW_FAMILY_PLACE`, T4 anchors `CAT_PINNED_NOTE`. Every run-time key exists. | consistent (nit D14: 13 of those keys are not checked by any test) |
| X14 | T1–T3–T4 | TOC: Rows after `Query.lua` (77), SettingsCategories after `SettingsPages.lua` (78), Paste after Rows (79). Only T1 changes the version (0.11.0, TOC and `SB.VERSION`). | consistent |
| X15 | T3–T4 | Spec loaders: Rows inserted at `Env.ENGINE` index 12 (T3), Paste at 13 (T4). The replay confirms the order. | consistent |
| X16 | T3–T4 | `spec/settings_categories_spec.lua`: T4's 4 edits anchor on T3 text. The list test becomes `2 + #display*3`, and the mutation comment follows the `text` rename. | consistent |
| X17 | T1–T4 | Test-count chain 1547 → 1553 → 1561 → 1572 → 1582 (+6, +8, +11, +10) | consistent |
| X18 | T3 ↔ SettingsWindow | `action.selected` → `setSelected` (operators, All/Any, Not), the Apply button (`b.onClick = item.commit`), `x0` placement | consistent |
| X19 | T1 FAMILIES ↔ T3 picker ↔ registry | Every canonical keyword is listed once (the test is held to `Q.keywords`). `gear` appears as a flag and as a number. | consistent |
| X20 | All tasks ↔ config paths | No new setting and no new key. Writes go only to `categories`, `userEdits`, `categoryOrder`, `settings.focus.sections`, char `overrides` and `ui.collapsed`. | consistent |
| X21 | T2 ↔ the categorizer / open bags | `C.Load()` bumps `C.version`, so the categorizer re-reads at the next layout. The writers never call the bags window. | consistent, except Delete's restack (D5) |

## 2. Per-task internal consistency

| # | Task | Tests vs code, files, counts, commit list | Verdict |
|---|---|---|---|
| I1 | T1 | 6 tests, all failing in `before_each` (no Rows.lua). 5 files. 7 mutations, all killed. The fuzz checks meaning against a row-by-row reference on real records, not against ToText itself. | consistent |
| I2 | T2 | 8 tests: 7 fail on missing writers, 1 on the mode-list filter. 3 files. 9 mutations killed. The test "a deleted category another character still opens" sets the *account* sections, not another character's override (D17). | consistent (nit) |
| I3 | T3 | 11 tests. 6 files (9 SettingsWindow edits, 2 Rows edits). 12 mutations killed. The tests never type into the text box and then click Add a rule or a value box, so D2 is untested. | consistent; defects D1–D4 live here |
| I4 | T4 | 7 new Paste tests, plus 3 page tests and 2 edited ones (21 red). 6 files. 13 mutations killed. | consistent |

## 3. Reviewer-defect patterns

| # | Check | Result |
|---|---|---|
| R1 | Tests asserting nothing | None. The "nothing pasted is ever run" test only asserts `pcall` ok and compile; that is the right shape, since running cannot be observed directly. |
| R2 | Duplicated logic | No second query parser: Rows uses `QueryParser.Parse`, Paste uses `QueryLexer.Tokenize` + `Query.Compile`. There are copies, though: `Paste.escapeCode` = Profiles' local `escapeCode`; `C.PINNED` = `Pr.PINNED`; the 500 limit is defined four times (D13). `Rows.Problem`'s character class guesses what the lexer splits on, where re-parsing the one row would reuse the lexer (minor). |
| R3 | Forbidden tokens (`BankFrame:SetTab`, `.bankType =`, `CloseBankFrame(`, `PurchaseBankTab`, `OpenAllBags(`, `PreClick`, `PostClick`) | None in the diff (grep of every added line). check.sh passes. |
| R4 | Adapter-only rule, comments included (`C_*`, `Enum.`, `Syndicator`, `ElvUI`, `TSM_API`, `LibStub`) | None in the added `SwagBag/` lines. "Syndicator" appears only in `spec/query_paste_spec.lua`'s comment (outside `SwagBag/`). |
| R5 | `loadstring` / `load(` / `RunScript` / `setfenv` / `dofile`, `OnUpdate`, bags-window calls in the new code | None. |
| R6 | Lua 5.1, format51, no Config at load | Clean. SettingsCategories reads Config only at call time. |

## 4. Data-safety and UX risks (for a non-coder)

| # | Risk asked about | Finding |
|---|---|---|
| S1 | Round-trip loss (rows change which items match) | Clean for meaning (my 20k fuzz plus the plan's 400). Two real losses of *typed text* exist (D2). One rows path silently makes a catch-all rule (D1). |
| S2 | Deleting a category that others reference | Focus (account and this character), order and collapsed are handled. The consumables list never holds ids. Share strings and named profiles keep old copies, which is harmless. Re-making the same name reuses the same id and re-attaches stale references (D9). Delete's nil config event restacks the open bags and drops caches (D5). |
| S3 | Built-in edit, then Reset | The warning only comes *after* a one-click, immediate Reset. Cancel then says "Nothing was changed.", which is false. CE1 steps 22–23 make the user Reset their real Gear category (D4). Reset also forgets drags *off* a built-in's default list (c_tools), which the message doesn't say. |
| S4 | Priority collisions | Two user categories at 88 tie by id, alphabetically, and nothing shows priorities in the list (D12). No built-in sits at 88. |
| S5 | Rename collisions | `CheckName` covers live names, any case, plus New and Free. Reset of a renamed built-in can make a duplicate name (D9, probe: two "Gear"). |
| S6 | Broken rule saved disabled | Visible ("(off: its rule has an error)", `/swagbag report` Broken) and recoverable for user categories and most built-ins. **Reagents stays off after the fix** (D3). The broken save also overwrites the working rule (SP1). |
| S7 | EditBox focus vs keybinds and combat | Esc and Enter clear focus. Nothing clears focus when combat starts, so a cursor left in a box eats ability keys in a pull (D6). |
| S8 | Huge, hostile or malformed paste | Never run, never an error (my fuzz), refused whole. A paste over 1,000 characters is cut by `SetMaxLetters` and then refused with the cut length. The Advanced text box (500) cuts silently into a possibly valid, different rule (D7). "That is 799 characters long" after the user pasted 299 (D10). |
| S9 | Baganator gold semantics | Inclusive `<` and `>` follow the research (line 47, for item levels; the gold cases are assumed the same). Per-item use of `value` is SwagBag's own definition. Bare `25g` becomes `value=25` (exact equality, which almost never matches a real price). This is all G6, in-game. |
| S10 | "Show matches" leaves the bags dimmed | Yes. The search persists after the settings window closes and is re-applied at every bag open, until cleared (D8). |
| S11 | P2 / P5 | Every click answers once through `act()`, and typing answers nothing. P5 holds for Save, Move and Reset. Delete restacks the open bags through Focus (D5). |

## 5. Spec conflicts

| # | Spec text | Plan | Verdict |
|---|---|---|---|
| SP1 | §7.5 #3: a broken category is marked invalid "and keep[s] the previous compiled version active" | Save stores the broken rule over the working one, switched off (AC6.2, §7.10) | conflict inside the spec. The week-end updates don't amend §7.5 #3. |
| SP2 | §7.10 "shows a warning triangle in the list" | text marker `(off: its rule has an error)` | conflict. Add it to the §7.10 week-end update. |
| SP3 | AC6.2 "Saving runs `Validate`"; §7.9 "Results are shown in the editor before save" | `C.Save` and `C.Create` only `Compile` (D7 says "compiles and validates"). The preview shows only `Validate(...).warnings[1]`. | minor conflict. Either call `Validate` in Save, or reword D7 and the AC6.2 update. |
| SP4 | §7.2 "within edit distance 1" | `Rows.Nearest` also accepts one adjacent swap | nit. State it in the §7.2 update. |
| SP5 | §4.2 rule 5 / P5 | Delete's `SB_CONFIG_CHANGED(nil)` → Focus.Refresh → `W.Restack` on the open bags | conflict (D5) |
| SP6 | §7.7 `source="import"`, §12.1, the new AC6.4 | covered by "Spec updates at week end" | consistent |

## Numbered findings

- **D1 (medium, data).** An empty "Item name contains..." row is saved as `""`, which compiles and matches every item. Probe: New → name → Add a rule → Item name contains... → Save gives "Saved Empty." Stored `query=""`, enabled, "Matches 6 of the 6". At priority 88 it takes nearly every bag item at the next open. A `" "` value behaves almost the same. **Fix:** in `SC.Save`, refuse while any row has a `Rows.Problem` (answer that problem, write nothing), or save it switched off like AC6.2. Add a test.
- **D2 (medium, data; violates D5).** Text typed in "The rule as text" but not read is silently thrown away in two cases. (a) "Add a rule" and "Change" are wrapped in `forget`, not `change`. The pick then calls `rulesChanged` on the stale rows. Probe: typed `gear & epic & bound`, Add a rule → toy, and the rule became `gear & boe & toy`. (b) Typing in a row's value box (`valueRow.set` → `rulesChanged`) overwrites `d.text` and clears `textTyped`. Probe: typed `potion | flask`, then 600 in the ilvl box, and the rule became `ilvl>=600`. **Fix:** route Add a rule and Change through the read-text-first guard (answer `CAT_TEXT_FIRST`). In `valueRow.set`/`commit`, read the typed text first when `d.textTyped`. Add a test for each.
- **D3 (medium, AC6.2).** Reagents (and any `setting` category) that was saved broken stays off after it is fixed. `C.Save` stored `userEdits.c_reagents.enabled=false`. `SC.Save` never sends `enabled` for a setting category, and the page has no On/Off for it, so only Reset brings it back, which loses the user's edits. Probe: broken, then fixed, and `enabled=false` stays. **Fix:** in `C.Save`, when the query compiles, `fields.enabled == nil` and `c.error` was set, put `out.enabled = true` (for a built-in this falls out of the diff). Add a Reagents case to the AC6.2 test.
- **D4 (medium, UX/data).** Reset to default bypasses the draft: it is written at once, on one click, and forgets dragged items with no confirmation. Clicking Cancel right after answers "Nothing was changed." (probe), which is false. Reset also drops the excludes made when items were dragged *off* a built-in's default include list (`c_tools`), so those items go back. CE1 steps 22–23 tell the user to Reset Gear, which wipes any real Gear changes or drags they already had. **Fix:** make Reset ask once more like Delete ("Reset: sure?", naming that dragged items are forgotten). Close the editor after a Reset, or have Cancel say the reset stays. In CE1, use a category that shows no "(changed)", or add "skip if Gear shows (changed)". Optionally widen `CAT_RESET_DONE` to "items you dragged onto or off it".
- **D5 (low–medium, P5/perf).** `C.Delete` emits `SB_CONFIG_CHANGED(nil)`, the "everything changed" signal. It drops the price cache (`Prices.Invalidate`), the AltData index and tooltip counts. It also refreshes Focus, which emits `SB_FOCUS_CHANGED`, and `W.Restack` re-stacks the open bags (against P5's "Load only"). **Fix:** emit `SB.Emit("SB_CONFIG_CHANGED", "focus.sections")`; Focus's listener already matches the `focus.` prefix. Assert the path in the T2 test.
- **D6 (low–medium, combat).** No text box drops keyboard focus when combat starts. A cursor left in the Name, text or paste box swallows ability keys during a pull until Esc. **Fix:** on `PLAYER_REGEN_DISABLED` (Guard `"none"`), call `ClearFocus()` on every shown `SW.inputs[i]`. Add a CE1 step to G1: click into a box, then press an ability key after Esc.
- **D7 (low–medium, data).** The rule-as-text box has `maxLetters = C.MAX_QUERY` (500), so a longer pasted rule is cut silently into a different rule that may still be valid. The `toolong` path can never be reached from the page, against the constraint "refused with its length instead of being cut silently". **Fix:** `maxLetters = 2 * C.MAX_QUERY`, as the paste box, so Read and Save refuse with the length. For the paste box over 1,000, the answer could say "more than 1000".
- **D8 (low, UX).** "Show matches" leaves the bags dimmed after the settings window closes, and at every later bag open (SearchBox re-applies), until the user clears it. D6 deliberately does not clear it on Save or Cancel. **Fix (optional):** when the settings window hides, clear the bags' search only if it still equals the text Show matches put there (this answers no click, so P2 holds). Or add "it stays until you clear it" to `CAT_SEE_TIP` and a CE1 step that closes the window while the bags are dimmed.
- **D9 (low).** Two rename-collision paths. Rename Gear to Kit, make a user category "Gear", then Reset c_gear: there are now two categories named "Gear" (probe). Also, deleting "Pots" and making "Pots" again reuses `u_pots`, which re-attaches other characters' stale focus and collapsed entries. **Fix:** `CheckName` also reserves a renamed built-in's default name (or Reset refuses with TAKEN). Accept or document the id reuse.
- **D10 (low, wording).** A 299-character paste whose gold terms grow it to 799 is refused with "That is 799 characters long". The user pasted 299 characters. **Fix:** a separate why/message for "too long once read as SwagBag's rule".
- **D11 (low, spec SP1).** A broken Save replaces the working rule. The previous rule is gone, except through Reset for a built-in. **Fix:** record the §7.5 #3 change in "Spec updates at week end". Optionally make `CAT_TEXT_ERROR` say the old rule will be replaced.
- **D12 (low, UX).** Priority ties: two user categories at 88 tie alphabetically by id, not by which was made first. The list shows no priorities, so a non-coder can't see why "Flasks & potions" wins over "My potions". **Fix:** show the priority in the list label, or a note in the editor when another enabled category has the same priority.
- **D13 (nit, duplicated logic).** `Paste.escapeCode` copies Profiles' private `escapeCode`. `C.PINNED` copies `Pr.PINNED`. 500 is defined four times. **Fix:** expose one escape check (in Query or as `Profiles.EscapeCode`) and alias the limits (`Rows.MAX_TEXT = C.MAX_QUERY` is not possible at load order, so put one constant on `SB.Query`).
- **D14 (nit, tests/P8).** `L` falls back to the key name, so a typo shows the raw key and raises no error. Thirteen run-time keys are not checked by any test, against the P8 constraint: `CAT_PROBLEM_EMPTY/QUOTE/NUMBER/WORD`, `CAT_WHY_LONG/TOOLONG`, `PASTE_ERR_EMPTY`, `PASTE_NOTE_NOTS/PARENS/ILVL/UNKNOWN/DIFFERENT`. **Fix:** one test that loops over every why and kind and asserts `rawget(L, key)`.
- **D15 (low, paste notes).** A bare word that *is* a SwagBag keyword but also a prefix of others gets no note. Examples: `key` (keystone), `profession` (profession tool and gear), `bag` (bags). Baganator's prefix lookup matched those too, so "every difference is named" is not quite true. **Fix:** add a note when `Paste.Prefixed(word)` is non-empty for a keyword word.
- **D16 (low, share strings).** The editor accepts a rule holding a chat escape (`|T`, `|cff........`). F20 refuses such a rule at import, and a share string is refused whole, so one such rule poisons every export. The same holds for a broken category (D17 in the plan), and nothing warns at export. **Fix:** `Create`/`Save` refuse an escape code in a query (reuse the check from D13). Have the export answer name broken categories.
- **D17 (nit, test).** The T2 test "a deleted category another character still opens..." uses `Config.Set` (account level). Its name implies another character's override. Rename it, or set it through a character override.
- **D18 (in-game, G1).** Unverified: WoW edit boxes may return a typed `|` as `||` from `GetText`. If so, nothing breaks (`||` is OR, and chat codes are still caught), but error positions after a pipe shift by one. Add to CE1: type `potion |` in the text box and check that the error says character 9.
- **D19 (nit).** The `Categories.lua` header line for `ResetBuiltin` still reads "remove the user's diff". It now answers `true | false, "readonly"`.

None of these blocks the replay: the plan executes exactly as written and every count matches. D1–D4 should be fixed in the plan, or ruled on, before execution, because each one either silently changes what the user's categories hold or misleads them in the status line.
