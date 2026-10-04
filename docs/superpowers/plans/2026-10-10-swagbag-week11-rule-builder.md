# SwagBag Week 11: The category editor (the visual rule builder) and paste import of a Baganator search. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ] `) syntax for tracking.

**Goal:** the user left Baganator because it was "too complicated to set up". SwagBag's categories work out of the box, but today the only ways to change one are dragging an item onto a header and a share string. This week builds spec F6, the last big piece of v1.0: a category editor in Settings that a non-coder can use, and a way to bring a Baganator search across by pasting it. In this order of priority, so the earlier ones ship first if time runs out:
1. **Rules as rows, and back** (engine, pure Lua): a category's rule turns into rows of `[keyword] [operator] [value]` in groups (All of these / Any of these, with Not on a row and on a group), and the rows turn back into the same rule, losslessly. A rule too nested for rows opens as text only, with the reason (D1, D2) (Task 1). The version goes to 0.11.0.
2. **The category writers** (engine): make a category, save one (a built-in keeps only the user's difference; a rule with an error is saved switched off with the error, never dropped: AC6.2), delete one (its id leaves every focus mode, the order and the collapsed sections), move one up or down, and count what a rule matches in the bags now (D7–D12) (Task 2).
3. **Settings > Categories**: the list (Edit, Up, Down, New category) and the editor: name, On/Off, the rows with a keyword picker, the rule as text (Advanced), "Matches N of the M items in your bags right now" with Show matches (the bags' own search dimming), the priority, Save / Cancel / Delete / Reset to default (D3–D12) (Task 3).
4. **Paste a Baganator search** (AC6.3): a box on the Categories page; SwagBag reads the string (nothing in it ever runs), says what it reads it as and every difference, counts its matches, and makes a new category of it only on Make category. A string it can't read is refused whole, with the reason and where (D13, D14) (Task 4).
5. **Week-10 polish:** none qualifies as cheap and user-visible; everything stays deferred with its reason (D15, "Carry-overs").

Tests go from 1547 to **1582**.

**Architecture:**
- (1) `Engine/Query/Rows.lua` (new, `SB.QueryRows`): `Rows.FromText(text) -> rules | nil, why, err` reads the parser's tree (`SB.QueryParser.Parse`) into two levels (groups of rows); `Rows.ToText(rules)` prints them with the parentheses `Query.Pretty` would use, so the text is the canonical spelling of the same tree. `Rows.FAMILIES` (the editor's keyword lists, every registered keyword once, by the spec 7.3 families), `Rows.KindOf`, `Rows.NewRow`, `Rows.Problem`; Task 3 adds `Rows.Nearest` (spec 7.2's "did you mean").
- (2) `Engine/Categories.lua` gains the writers `CheckName`, `Create`, `Save`, `Delete`, `Move`, `Preview` (all refuse while the settings are read-only; all `Load()` again after a change). `ResetBuiltin` now refuses while read-only and answers true. `Engine/Focus.lua`'s `/swagbag mode list` leaves out an id that is no category any more (a deleted one another character still opens).
- (3) `UI/SettingsCategories.lua` (new, `SB.SettingsCategories`): one settings page, `categories`, drawn by `UI/SettingsWindow.lua` from rows like every page. The window gains two things: a text-box row (`kind = "input"`, a plain `InputBoxTemplate` EditBox: keystrokes go to `set`, Enter or an Apply button to `commit`) and a selected state for action buttons. The editor works on an in-memory draft that only Save writes.
- (4) `Engine/Query/Paste.lua` (new, `SB.QueryPaste`): `Paste.Translate(text)` reads the pasted string with the query lexer and patterns only, rewrites what Baganator spells differently (gold amounts, `!!`, a `(` left open), names every other difference as a note, and refuses what SwagBag cannot read. The Categories page gets the paste view.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105; 12.1.5 goes live 2026-10-13). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- F6 (visual rule builder): AC6.1 (rows grouped in AND/OR blocks with a NOT toggle; Advanced reveals the text; both round-trip losslessly), AC6.2 (Save runs Validate; a broken category is saved disabled with the error shown, never dropped), AC6.3 (paste a Syndicator/Baganator string, preview what it matches before saving);
- §7.2 (the "did you mean" hint for a word one letter from a keyword), §7.5 (the known divergences, now surfaced at paste), §7.7 (`source = "import"` for a pasted category), §7.9 (`Validate` before save), §7.10 (a broken category saved with `enabled = false` and its error, shown in the list);
- §8.5 (a built-in is never stored; the user's change is a diff in `userEdits`, and Reset to default removes it);
- P1, P2, P3 (Advanced behind a button), P5 (Save never regroups the open bags; Show matches only dims, AC5.2);
- F20's limits reused for categories made here: the `u_` id shape, priorities 1 to 89 (nothing outranks Junk, Equipment sets, Keystone & Crests or Reagents), no chat codes.
The spec text is updated at week end (see "Spec updates at week end"). All rights reserved: every idea here is clean-room; no code is copied from any other addon. Baganator's search syntax comes only from public documentation and the week-1 desk spike's behaviour notes (`docs/research/2026-10-syndicator-grammar-diff.md`), which quotes no code.

Ledgers (binding rulings W3-*, W4-*, W5-*, week 6, week 7 R1–R22, week 8 Q1–Q13, week 9 R0, S1–S20, week 10 U1–U11): `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md` through `2026-10-09-swagbag-week10-ledger.md`. Week-10 plan (style and interfaces): `docs/superpowers/plans/2026-10-09-swagbag-week10-lock-warnings.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week11` is already checked out. It was made from `main` at `134a6bd` (v0.10.0, the week-10 ledger and preflight; weeks 9 and 10 are merged). The suite has 1547 tests. No task creates or switches branches.

**The code at `134a6bd` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). These interfaces are used as they are on `134a6bd`:
- `SB.On`, `SB.Emit`, `SB.ErrorTrap.Run/Guard`, `SB.Print`, `SB.Slash.Register/Run/Dispatch`.
- `SB.Config.Get/Set/CharOverride/UI/readOnly/db/charDB/Defaults` (`Config.Set` returns false while read-only; `SwagBagDB.categories`, `.userEdits`, `.categoryOrder` since schema 2).
- `SB.Categories` (`Load`, `Ensure`, `Get`, `Name`, `SectionOrder`, `ByPriority`, `Counts`, `ResetBuiltin`, `list`, `byId`, `display`, `NEW`, `FREE`; `build()` disables a category whose query does not compile and sets `error`), `SB.CategoryDefaults` (20 built-ins; `c_other` is the fallback, `c_reagents` follows `bags.reagentSeparate`).
- `SB.QueryLexer.Tokenize`, `SB.QueryParser.Parse` (node types `or`, `and`, `not`, `word`, `text`, `exact`, `num`; bare `<N`, `>N`, `N`, `N-M` already read as `ilvl` tests), `SB.Query.Compile/Eval/Validate/Pretty/FormatError/FormatWarning/Lookup/keywords/RegisterKeyword`.
- `SB.Inventory.Iterate("bags")`, `SB.Inventory.ScanAll`, `SB.Items.Describe`.
- `SB.SettingsWindow` (`AddPage`, `Render`, `Show`, `Say`, `RunCommand` from `UI/SettingsPages.lua`, rows `choice` / `actions` / `drop` / `note`, `act()` under `"none"`), `/swagbag search <text>` (`UI/SearchBox.lua`: the bags' own search; answers `L.SEARCH_RESULT`, `L.SEARCH_CLEARED` or `L.SEARCH_OPEN_FIRST`).
- `SB.Focus.ListLines` (`/swagbag mode list`), `SB.Profiles` (unchanged: share strings carry user categories as `cu.u_...` entries).
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua` (`Fake.New`, `Fake.Fire`, `Fake.Install/Uninstall`; a fake's unmodelled methods are recorded no-ops, `SetText/GetText` are modelled), `uienv.lua` (`Env.ENGINE`), `spec/fixtures/items.lua` (`Fixtures.SmallBags`: six items in a 16-slot backpack, among them "Algari Healing Potion" and "Flask of Alchemical Chaos"), `spec/mock_adapter.lua` (`m.Put`, `m.Lines`), and `format51` (installed by the runner).



## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.11.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon; Baganator's search behaviour is implemented from its public description and the week-1 spike's notes only. **No new Blizzard API this week and no Adapter change.** The one new client template is `InputBoxTemplate` (a plain, non-secure FrameXML EditBox template, like the `UIPanelButtonTemplate` the settings window already uses).
- TOC metadata unchanged (`## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster, Masque`). Three files are added: `Engine/Query/Rows.lua` (Task 1, right after `Engine/Query/Query.lua`), `UI/SettingsCategories.lua` (Task 3, right after `UI/SettingsPages.lua`, so the page sits after Overlays in the settings window), `Engine/Query/Paste.lua` (Task 4, right after `Engine/Query/Rows.lua`): the TOC goes from 76 to 77, 78, then 79 files.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets a string or a number, never a boolean or nil. Every spec runs under `spec/helpers/format51.lua`.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace, `Enum`, ElvUI, Syndicator, `TSM_API` or `LibStub`, **comments included** (`scripts/check.sh`). Nothing this week names any of them: the new files and strings say "Baganator", the addon the user knows (the older comments that name Syndicator's spellings are unchanged).
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`.
- **Plain frames only, no secure frame touched.** The Categories page is the settings window's own Buttons, FontStrings and (new) EditBoxes, which may be created in combat. Nothing this week touches an item button, a bag, a bank frame or any Blizzard frame. "Show matches" runs `/swagbag search`, the bags' own search, which dims and never moves an item (AC5.2).
- **Nothing in a pasted or typed rule is ever run.** Rules are read by the query lexer and parser and by Lua patterns only; no `loadstring`, `load`, `RunScript` or `setfenv` anywhere (checked by grep, "How this plan was checked").
- P1: every choice ships with a default and its alternative next to it. This week: a new category is On, priority 88, shown first; the rule as text is hidden behind "Show the rule as text" next to the rules (shown at once when the rule can't be rows); a pasted category is named "From Baganator" (the next free "From Baganator 2", ...).
- P2: every click on the Categories page answers **exactly once**, in the settings window's status line (`SW.Say` through `act()`); the page prints no chat line. Typing in a text box answers nothing; Enter or Apply answers once.
- P5 / spec §4.2 rule 5: nothing moves in the open bags while editing. Save, Delete, Move and Reset change the stored categories and call `Categories.Load()` only; the bags sort by them the next time they open, or at Reflow, and every Save answer says so. `UI/SettingsCategories.lua` and the new `Categories` writers never call the bags window.
- **P6.** Every WoW entry point runs inside `SB.ErrorTrap.Run` or `Guard`. The labels this week, all `"none"` (recorded for `/swagbag report`, never Safe Mode): `settings.input` (a text box's Enter or Apply, through the window's `act()`), `settings.inputEnter`, `settings.inputEscape`, `settings.inputText` (the EditBox scripts), and the existing `settings.action` / `settings.choice`. `Categories.Preview` evaluates inside `pcall` and answers `L.SEARCH_EVAL_FAILED` for a keyword that throws (the categorizer records that keyword's error once when it really sorts, as before).
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`. Keys built at run time (`L[fam.label]`, `L["CAT_PROBLEM_" .. why]`, `L["CAT_WHY_" .. why]`, `L["PASTE_ERR_" .. why]`, `L["PASTE_NOTE_" .. kind]`) are each checked by a test or used in one.
- **Settings and saved data (schema stays 2): no new setting and no new key.** The editor writes only tables that exist since schema 2: `SwagBagDB.categories[id]` (a user category: `name`, `query`, `priority`, `enabled`, `source`, and `displayOrder` only when there is no saved order), `SwagBagDB.userEdits[id]` (a built-in: only the fields that differ from its default; removed when nothing is left, spec 8.5) and `SwagBagDB.categoryOrder` (only when the user moves a category, or when a new one joins an order that is already saved). Delete also edits `focus.sections.<mode>` (the account's and this character's) and this character's `ui.collapsed`. Drafts and the paste view live in memory only. Only values somebody wrote are stored, so no migration.
- **Limits** (one place each, `Categories.MAX_NAME`, `C.MAX_QUERY`, `Rows.MAX_*`, `Paste.MAX`): a name has 1 to 30 characters, no `|` (a chat code) and no control character, and no other category (built-in or not, any case) nor New or Free has it; a rule has at most 500 characters (the share-string limit, `Profiles.MAX_STRING`); rows show at most 40 rows in 10 groups; priorities go from 1 to 89; the paste box takes up to 1,000 characters so a longer paste is refused with its length instead of being cut silently.
- No file calls `Config` at load time. No `OnUpdate` anywhere. Idle CPU with every window closed is 0: the preview count runs only when the Categories page is drawn (a click, Enter, or a setting changing while it is open).
- Every critical test names the mutation that must make it fail. Each task lists its mutations under Step 2.
- **Tooling (binding, as in weeks 1–10):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). The UI tests drive the page as the user does: buttons by their text (`Fake.Fire(button, "OnClick")`), text boxes by setting the text, firing `OnTextChanged` with `userInput = true`, then `OnEnterPressed`. CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Test totals are cumulative from 1547 (see "Schedule").
- One commit per task, made with `git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit`. The message ends with exactly these two lines:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`
- In-game checks are written for the user, who is not a programmer:
  - each session begins with "Claude installs the build first", followed by a full game restart (not `/reload`);
  - steps are numbered, one action per step, each saying exactly what the user should see;
  - quoted strings match `SwagBag/Locale/enUS.lua` exactly, and chat lines start with `SwagBag: `;
  - a step that types into a box says where to click first and to press Enter after.

  Sessions never block the build: findings come back as fixes.


## Review Focus

These are the failure modes most likely to bite the user that the spec implies but the feature tests would not naturally hit, most likely first. Each is pinned by tests in the task that owns the code.

1. **An edit that silently changes which items a category takes** (the rows and the text disagree, a "!" or a pair of parentheses lost on the way, a typed name read as a keyword). Expected: rows → text → rows gives the same rows; text → rows → text gives the same tree (`Query.Pretty`); a rule nobody touched is saved exactly as typed; a name typed in a row is always quoted. Pinned by Task 1: "every built-in category query turns into rows and back into the same query", "rows -> text -> rows is lossless for every shape the rows can show", "fuzz: 400 random rule sets print as text that reads back the same and matches the same items" (each random rule is also evaluated row by row on real item records and must match the compiled text, so a misplaced parenthesis fails); Task 3: "rows and text change each other, losslessly; a rule nobody touched keeps its own spelling", "a rule too nested for rows opens as text only, and is saved as it is".
2. **A malformed or hostile paste** (a chat link or texture code, a quote, a 10,000-character string, unbalanced parentheses, something that looks like Lua). Expected: refused whole with the reason and where, or read; never run; never an error; whatever is read compiles and fits a category. Pinned by Task 4: "refused whole, with the reason and where: quotes, chat codes, too long, empty, what SwagBag can't read", "nothing pasted is ever run, and whatever is pasted it never errors; a string it reads always compiles" (1,500 random strings plus hostile ones), "Paste: a string SwagBag can't read is refused whole, with the reason; nothing is made".
3. **A broken rule lost** (AC6.2: "never silently dropped"). Expected: saved, switched off, its error said at Save and shown in the list and the report; fixed and saved, it is on again. Pinned by Task 2: "AC6.2: a rule that doesn't compile is saved switched off with its error, never dropped; fixed, it is on again"; Task 3: "AC6.2: Save keeps a broken rule, switched off, says why, and the list marks it".
4. **Deleting a category something else points at.** Focus modes' section sets (account-wide and this character's own), the display order and the collapsed sections hold category ids. Expected: all of them lose the id (Focus is told once); another character's own focus sections, which SwagBag cannot reach from here, are harmless and not named in `/swagbag mode list`. The consumables watch list holds queries and item IDs, never a category id (`Engine/Consumables.lua`), so it is unaffected. Pinned by Task 2: "deleting a user category takes it out of the order, every focus mode and the collapsed sections", "a deleted category another character still opens is not named in /swagbag mode list"; Task 3: "Delete asks once more; any other click forgets the question".
5. **Renaming collisions** (two "Potions", a category named "New", a name that is a chat code). Expected: refused with the reason; a rename keeps the id, so focus sections and collapsed state stay attached; two names with the same stem get `u_name` and `u_name_2`. Pinned by Task 2: "Create: a user category with a checked name, shown first, at priority 88"; Task 3: "a text box: typing is kept across a redraw; Enter and Apply each answer once"; Task 4: "Paste: a string changed after it was read must be read again; a taken name is refused".
6. **Editing a built-in, then Reset.** Expected: only the user's difference is stored, a change back to the default removes it, Reset to default removes all of it (and says it also forgets dragged items); Junk, Equipment sets, Keystone & Crests and Reagents keep their priority. Pinned by Task 2: "a built-in keeps only the user's difference; Reset to default removes it; its rank rules hold"; Task 3: "a built-in: Save stores only the difference; Reset to default brings it back; Junk has no priority".
7. **Very long queries.** Expected: 500 characters at most everywhere (typed, saved, pasted, and after a paste's gold terms grow it); rows at most 40 in 10 groups, else text only; the parser's 100-level nesting limit as before. Pinned by Task 1: "queries the rows can't show open as text only, and say why"; Task 2: the Create test; Task 4: the "nothing pasted is ever run" test (299 characters pasted, 799 read: refused).
8. **Read-only settings** (a newer SwagBag's data). Expected: every writer and every page button refuses with `L.SETTINGS_READONLY` and changes nothing. Pinned by Task 2: "read-only: every writer refuses and changes nothing"; Task 3: "read-only: Save, Delete and Up refuse with the reason, and nothing changes".



## Decisions (every product default chosen this week, read before Task 1)

| # | Question | This plan (the default) | The alternative, and where it is | Why |
|---|---|---|---|---|
| D1 | What can the rows show? | **Two levels:** groups of rows. Each group is "All of these" (AND) or "Any of these" (OR) and has a Not; each row has a Not; with more than one group, "All groups must match" or "Any group may match". A rule nested deeper (`a & (b \| (c & d))`), a double Not (`!!a`), more than 40 rows or 10 groups opens as **text only**, with a note saying why. | Edit such a rule as text (Advanced), which always works. | AC6.1 asks for rows "grouped in AND/OR blocks with a NOT toggle": two levels. Every built-in rule and every published Baganator string of the week-1 spike fits. Deeper nesting is Pat's (P3: power behind Advanced). |
| D2 | What does "losslessly" mean? | **The same rule, item for item:** text → rows → text gives `Query.Pretty`'s spelling of the same tree; rows → text → rows gives the same rows. A rule nobody changed in the rows is saved **exactly as typed** (its own spacing, `~`, `\|\|`, aliases like `gray`); a rule changed in the rows is saved in Pretty's spelling (`~boe\|\|bop` becomes `!boe \| bop`: the same items). | — | Keeping the user's spelling for every edit would need a second text model; the meaning is what matters, and Pretty's spelling is what the search box already shows for errors. The fuzz test checks the meaning on real item records. |
| D3 | How is a keyword picked? | **Lists of buttons by family** (Item type, Quality, Binding, Numbers, State, Gear slot, Where it is: the spec 7.3 families), with "Item name contains..." first, shown in place of the rules after "Add a rule" or "Change". Every registered keyword is in exactly one list (a test checks the lists against the registry). | — (a scrolling dropdown would need Blizzard's menu system: not this week). | The settings window already lays out wrapping buttons; a list of words is easier to scan than a dropdown, and nothing new can break. |
| D4 | Operators | Keyword rows: just the keyword, with **Not**. Number rows (ilvl, gear, level, value, count, stack, tab): `>=` (default) `>` `=` `<` `<=` and a number box. Name rows: "item name contains" and a text box; a name typed here is **always quoted**, so "fish" can never turn into a keyword. Not on every row and every group. | — | One Not toggle covers "is not" for every kind; `!ilvl>600` and `ilvl<=600` are different rules (the first also takes items with no item level), so the rows keep both. |
| D5 | The rule as text (Advanced) | **Hidden** behind "Show the rule as text", next to the rules (P3, P1); shown at once when the rule can't be rows or has an error. Two-way: Enter or Apply reads the text into rows; a row click after text typed but not read reads the text first and says so (no click lands on a row that changed under it). | "Hide the text". | AC6.1: "Advanced reveals the text". |
| D6 | The preview | "**Matches N of the M items in your bags right now.**" (stacks), counted each time the page is drawn; a rule with an error says the error instead. "**Show matches in the bags**" puts the rule into the bags' search box (`/swagbag search`): everything else dims, nothing moves (AC5.2); "Clear the bags' search" undims. Not cleared by Save or Cancel. | The search box's own X also clears it. | The dimming exists and is proven never to move an item; a second highlight would be new code on secure buttons. Clearing it behind the user's back would be a second answer to one click (P2). |
| D7 | Save | **Nothing is written before Save.** Save checks the name, compiles and validates the rule (spec 7.9): a rule with an error is **saved switched off**, the answer says why (`Saved X, but it stays off until its rule is fixed: ...`), the list shows `X (off: its rule has an error)` and `/swagbag report`'s Broken list names it (AC6.2, spec 7.10); fixed and saved, it is on again. The open bags do not change: the answer says they sort by it next time they open (or at Reflow) (P5). | Cancel: nothing changes. | AC6.2, P5. |
| D8 | A new category's defaults | **On, priority 88, shown first** (right under New), id `u_<name>` (`u_my_potions`; `_2`, `_3` when taken). Its name is required. | Up/Down on the list, the priority steps, Off. | At 88 it wins over every built-in except Reagents (100), Keystone & Crests (95), Equipment sets (92) and Junk (90), so a user's "My potions" really gets the potions (Consumables is 65). Shown first so the user sees it at once. The `u_` shape is the share strings' (F20). |
| D9 | Priority | Steps **−10, −1, +1, +10** within **1 to 89**, with a tip in plain words. The four pinned built-ins have no steps (a note says why). | — (typing a number: not this week). | F20's rule (week 7): nothing outranks Junk, Equipment sets, Keystone & Crests or Reagents. Steps are easier than a number box for a non-coder. |
| D10 | Display order | **Up / Down** on the list, one place each; saved as the whole order (`categoryOrder`), as the quick setup already saves it. | — | The brief: "simple up/down". |
| D11 | Delete | **Only the user's own categories**, and it asks once more: the button becomes "Delete: sure?"; any other click forgets the question. The id leaves the order, every focus mode's sections (account-wide and this character's) and this character's collapsed sections. | A built-in can be switched Off (and Reset), never deleted. | A built-in is never stored (spec 8.5), so it cannot be deleted; Off hides it. The second click is week 7's Unlock-all pattern. |
| D12 | Editing a built-in | Name, rule, On/Off, priority (not the four pinned); stored as a diff; "Reset to default" (shown only when there is a diff) removes the whole diff, **including items dragged onto it**, and says so. Other: name only (it holds what no rule takes). Reagents: no On/Off (Settings > Bags > Reagent bag decides). | — | Spec 8.5. A Reset that kept the drags would leave a half-edited built-in. |
| D13 | Paste: refuse, translate, or save what was understood? | **Translate** what Baganator spells differently and has a clear twin (gold amounts, `!!`, a `(` left open); **keep and name** every difference (an unknown `#keyword` matches nothing, as in Baganator; a bare word matches names only; `upgrade`/`bop` mean something else; item levels count gear only); **refuse the whole string** for anything SwagBag can't read (a stray `)`, an operator with nothing after it, a name before a comparison, a quote, a chat code, over 500 characters), with the reason and where in the pasted text. **Never "save what we understood".** | Edit the string in the box and read it again; or make a category by hand. | Dropping one term of an AND makes the category take more items, dropping one of an OR fewer: a silent wrong filing, which a non-coder can't spot. The preview count is shown before anything is made (AC6.3). |
| D14 | What a paste makes | **A new category of the user's**, named "From Baganator" (changeable before Make category), `source = "import"` (spec 7.7), priority 88, shown first. Never replaces an existing category. | Rename it in the box first; edit it later like any category. | A paste never overwrites anything. |
| D15 | Week-10 polish | **None this week.** Every deferred week-10 item is test-only, a comment, rare, or waits on session LW1 (see "Carry-overs"). | — | The brief: only if cheap and user-visible. |
| D16 | Version | `0.11.0` (Task 1). | — | — |
| D17 | A broken category in a share string | **Unchanged:** a share string with categories carries a broken one as it is, and importing that string is refused (F20: an imported rule must compile), naming the entry (`cu.u_x.query`). Fix or delete it before exporting. | Importing it switched off instead would change F20: the user's call. | F20 is binding (week 7, ruling R3: a string is accepted whole or refused whole). |


## Paste mapping (Baganator → SwagBag, D13)

| Baganator (Syndicator's search language) | SwagBag reads it as | Note shown |
|---|---|---|
| `&` `\|` `!` `~` `\|\|` `( )` | the same | — |
| `!!x`, `~~x`, longer runs | `!x` (Baganator reads one Not) | "!! (or ~~) is read as one Not, as Baganator does." |
| a `(` left open at the end | closed with `)` at the end (Baganator closes it) | "A ( left open at the end is closed, as Baganator does." |
| `#word` SwagBag has | the same | — |
| `#word` SwagBag doesn't have (`#elemental`, `#open`, `#fish`...) | the same: matches nothing, as in Baganator | "#elemental is a keyword SwagBag doesn't have: it matches nothing, as in Baganator." |
| `N`, `=N`, `<N`, `>N`, `N-M` (item level) | the same (`<N` is `ilvl<=N`, both ends included) | "Item levels count gear only in SwagBag (Baganator also reads other items' item level)." |
| `>Ng`, `<Ns`, `=Nc`, `Ng`, `Ng-Mg` (auction value; g, s or c, one unit per amount) | `value>=N`, `value<=N/100`, `value=N/10000`, `value=N`, `(value>=N & value<=M)` | "Gold amounts compare SwagBag's price for one item (auction, else vendor); < and > include the amount, as in Baganator." |
| a bare word that is one of SwagBag's keywords | the keyword | — (`upgrade` and `bop`: "... means something else in SwagBag ...") |
| any other bare word | an item-name match (no keyword prefixes, no tooltip lines) | ""pot" matches item names only (Baganator also tried keywords starting with it, and some tooltip lines). SwagBag keywords starting with it: potion." |
| `"` | **refused** (a letter for Baganator, a quoted name for SwagBag) | the character's position |
| `\|c........`, `\|T`, `\|H`, `\|A`, `\|K`, `\|cnNAME:` | **refused** (a chat code) | — |
| a stray `)`, `a & & b`, `a b >5`, an operator at the end | **refused** with SwagBag's positioned error, positioned in the pasted text | e.g. "SwagBag can't read it: Expected & or \| but found ")" at character 14. Nothing was made." |
| over 500 characters (also after gold terms grow it) | **refused** with the length | — |
| `1g50s` (two units), amounts over 9 digits | not gold: a name word (`1g50s`) or refused (`>1000000000000g`: "Expected a number") | the NAME note, or the error |

What SwagBag can't support from Baganator's language, and says so: keyword prefixes (`pot` finding potions), tooltip-line text search, gold amounts with two units, Baganator's keywords SwagBag has not registered (subclass, profession and expansion names among them: spec 7.5 #12), and `upgrade`/`bop`'s other meaning.


## What the week relies on

| What | Name | Since | Confidence |
|---|---|---|---|
| A one-line text box | `CreateFrame("EditBox", nil, parent, "InputBoxTemplate")`; `SetMaxLetters`, `SetAutoFocus(false)`, `SetText`, `GetText`, `ClearFocus`; scripts `OnEnterPressed`, `OnEscapePressed`, `OnTextChanged(self, userInput)` | new to the settings window (the share box and search boxes have used EditBoxes since weeks 1 and 7) | Long-standing FrameXML template, plain and non-secure. That typing, Enter, Esc and Ctrl+V work inside the settings window's scroll frame, and that a key like B types into the box instead of opening the bags: G1. |
| The bags' own search | `/swagbag search <text>` (`UI/SearchBox.lua`), dimming only (AC5.2) | week 1 | Tested since week 1; with the settings window open at the same time: G3. |
| Baganator's search language | Syndicator v284 as described by the week-1 desk spike (`docs/research/2026-10-syndicator-grammar-diff.md`: operators, precedence, `#`, item-level and gold patterns, prefix matching, tooltip text) | week 1 | Read from public behaviour notes, not code. The spike's 24 published strings are a test fixture (Task 4). That a string copied from Baganator today matches about the same items: G5. The gold amounts' unit (per item or per stack) and price source: G6. |


## Needs in-game confirmation (what could not be verified at the desk)

Each item names the session step that checks it. None blocks the build; a wrong answer comes back as a fix.

| # | What | Why it is uncertain | Checked in |
|---|---|---|---|
| G1 | The text boxes work in the settings window: click, type, Enter, Esc, Ctrl+V; typing B while a box has the cursor types "b" and does not close the bags | EditBoxes inside the settings scroll frame are new; focus and key capture are not modelled | CE1 steps 5, 21 |
| G2 | The keyword lists are readable: buttons wrap, the page scrolls with the mouse wheel, nothing overlaps | Button widths come from the client's text widths; the fakes have none | CE1 step 6 |
| G3 | Show matches dims the bags while the settings window is open, nothing moves, and Clear undims | Two windows at once is not modelled | CE1 steps 9, 10 |
| G4 | Save leaves the open bags as they are; closing and opening them shows the new section with the right items | The layout after `Categories.Load()` is tested elsewhere, not with the editor | CE1 steps 11, 12 |
| G5 | A string copied from Baganator (or Wago) matches about the same items in SwagBag as in Baganator | Baganator's current behaviour was read in week 1, from notes | CE1 step 27 (optional) |
| G6 | Gold amounts: Baganator's `>100g` is per item and uses an auction price | The spike's notes say "auction value", not per item or per stack | CE1 step 27 (optional) |
| G7 | A long editor page (several groups and rows) scrolls, and the status line stays readable | Page heights come from the client's text heights | CE1 steps 14, 18 |


## Carry-overs: what this week takes, and what stays deferred

Taken: none (D15).

Triaged and left deferred (not user-visible, test-only, rare, or needing an in-game look first):
- week-10 Task 1: the unused globals header in `spec/lockwarnings_spec.lua`; the red line's order under the Locked line is not asserted; `LW.On` compares with `true` strictly (test-only or by design);
- week-10 Task 2: a note of the delete box can linger if Blizzard's box is hidden by something else while the item stays on the cursor (the final review advised against a timer; revisit only if session LW1 shows a leftover bar); a login in combat has no note until combat ends (comment only); weak count assertions;
- week-10 Task 3: switching `locks.warn` on while a locked item already sits in the scrapper gives no line until it is put in again (rare); the `not seen[id]` dedupe is untested;
- week-10 Task 4: `report_spec` stubs `SB.Locks` without restoring it; read-only is tested for `on` only (test-only);
- week-10 Task 5: some reworded comments exceed the wrap width (cosmetic);
- the week-9 and earlier items listed as deferred in the week-10 plan, unchanged; the week-6 bank-speed part 2 still waits on session TF1's numbers.

Session LW1 (week 10) and the earlier open checks are unchanged by this plan.


---

## File structure (end of week 11)

New and changed files only. Everything else is as on `134a6bd`.

```
SwagBag/Engine/Query/Rows.lua          NEW  (T1) FromText, ToText, FAMILIES, KindOf, NewRow, Problem; (T3) Nearest
SwagBag/Engine/Query/Paste.lua         NEW  (T4) Translate, Prefixed
SwagBag/Engine/Categories.lua          MOD  (T2) CheckName, Create, Save, Delete, Move, Preview; ResetBuiltin refuses
                                            while read-only
SwagBag/Engine/Focus.lua               MOD  (T2) /swagbag mode list leaves out a deleted category
SwagBag/UI/SettingsCategories.lua      NEW  (T3) the Categories page: list, editor, keyword lists; (T4) the paste view
SwagBag/UI/SettingsWindow.lua          MOD  (T3) the text-box row, selected action buttons
SwagBag/Locale/enUS.lua                MOD  (T1, T3, T4)
SwagBag/SwagBag.toc                    MOD  (T1) Rows, 0.11.0; (T3) SettingsCategories; (T4) Paste
SwagBag/Core/Init.lua                  MOD  (T1) 0.11.0
spec/query_rows_spec.lua (T1), categories_edit_spec.lua (T2), settings_categories_spec.lua (T3, T4),
spec/query_paste_spec.lua (T4)                                                                               NEW
```

`TOC OK (77 files)` after Task 1 and 2, `78` after Task 3, `79` after Task 4.


## Schedule (week 11)

In priority order, so the earlier items ship first if time runs out. Nothing this week depends on 12.1.5 (live 2026-10-13); session CE1 runs on either.

| Day | Tasks | User in game? |
|---|---|---|
| 1 | 1, 2 | — |
| 2 | 3, 4 | after the merge: session CE1 (the category editor and paste, about 25 minutes) |
| 3 | final review, fixes | **Week 11 exit check** |

Cumulative `scripts/check.sh` test totals (from 1547 on `134a6bd`). Each was produced by replaying this file's blocks in order on a fresh clone of `134a6bd`:
- T1 1553 passed, 0 failed (+6)
- T2 1561 passed, 0 failed (+8)
- T3 1572 passed, 0 failed (+11)
- T4 1582 passed, 0 failed (+10; one existing test of Task 3 gains the paste button, and one gains a line)

## How to read the code steps

- A **Create** step gives a complete new file.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point and its replacement. The block occurs exactly once in the file, and starts and ends on a non-blank line. When a step edits one file in several places, the places are numbered "(edit N of M)". Apply them in that order, top to bottom. Each find block is unique in the file as it is after the earlier edits.
- No step replaces a whole existing file.
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks (everything else). Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists its critical tests and, for each, the code change (mutation) that must make it fail. Every mutation was applied to the finished code of its task and the named test failed. A reviewer re-runs any of them with a one-line edit. In a mutation, ` ⏎ ` marks a line break and `∅` an empty replacement; leading tabs are left out.
- A test that passes at Step 2 is named there with the reason (none this week).

---

### Task 1: Rules as rows, and back (Engine/Query/Rows.lua); v0.11.0

The engine under the editor. `Rows.FromText` reads a rule (through the query parser, so it accepts exactly what the search box accepts) into two levels: groups of rows (D1). Each row is one term: a bare word (a keyword, else an item-name match), a quoted name, a `#keyword`, or a number comparison, with its own Not; each group is All of these / Any of these with its own Not. `Rows.ToText` prints rows back with the parentheses `Query.Pretty` would print, so the round trip is lossless (D2): text → rows → text is Pretty's spelling of the same tree, rows → text → rows is the same rows. A rule the rows cannot show (deeper nesting, `!!`, more than 40 rows or 10 groups, more than 500 characters, or an error) gives `nil` and the reason, and the editor opens it as text. `Rows.FAMILIES` is the editor's keyword lists (D3): every registered keyword once, in the spec 7.3 families; a test holds it to the registry, so a keyword added later without a list fails the suite. `Rows.NewRow` makes the row a picked keyword or name starts with; `Rows.Problem` says what keeps a row from being saved (an empty value, a quote in a name, a number that isn't one, a bare word that would not read back as itself). Nothing here runs or stores anything. The version goes to 0.11.0.

**Files:**
- Create: `SwagBag/Engine/Query/Rows.lua`, `spec/query_rows_spec.lua`
- Modify: `SwagBag/Locale/enUS.lua` (the family names), `SwagBag/SwagBag.toc` (the new file; 0.11.0), `SwagBag/Core/Init.lua` (0.11.0)

**Interfaces:**
- Consumes: `SB.QueryParser.Parse`, `SB.Query.Lookup`, `SB.Query.keywords` (the tests: `Query.Compile/Eval/Pretty`, `Items.Describe`, `CategoryDefaults`).
- Produces: `SB.QueryRows` with `FromText(text) -> rules | nil, "error" | "deep" | "long" | "toolong", err`, `ToText(rules) -> text`, `FAMILIES = { { label = <Locale key>, numbers = bool, words } }`, `NUMBER_OPS`, `KindOf(word) -> "flag" | "number" | "both" | nil`, `NewRow(word, asNumber) -> row`, `Problem(row) -> nil | "EMPTY" | "QUOTE" | "NUMBER" | "WORD"`, `MAX_ROWS = 40`, `MAX_BLOCKS = 10`, `MAX_TEXT = 500`; `L.KW_FAMILY_*`; `SB.VERSION = "0.11.0"`.

- [ ] **Step 1: Write the failing tests**

Create `spec/query_rows_spec.lua`:

```lua
-- Week 11 (spec F6, AC6.1): a category's query as editable rows (Engine/Query/Rows.lua) and back to text,
-- losslessly. Every built-in query, a list of shapes, the shapes the rows cannot show, and a fuzz over random rows.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Query/Rows.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
	"SwagBag/Engine/CategoryDefaults.lua",
}

describe("Rule rows (week 11)", function()
	local SB, Q, Rows
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		Q, Rows = SB.Query, SB.QueryRows
	end)

	local function pretty(text)
		return Q.Pretty(Q.Compile(text).ast)
	end

	-- Mutation: in Rows.lua's asBlock, `return { join = node.type, ...` -> `return { join = "and", ...`.
	it("every built-in category query turns into rows and back into the same query", function()
		assert.truthy(#SB.CategoryDefaults >= 20)
		for _, def in ipairs(SB.CategoryDefaults) do
			local rules, why = Rows.FromText(def.query)
			assert.truthy(rules, def.id .. " " .. tostring(why))
			assert.equal(def.query == "" and "" or pretty(def.query), Rows.ToText(rules), def.id)
			assert.same(rules, Rows.FromText(Rows.ToText(rules)), def.id)
		end
		assert.same({ join = "and", blocks = { { join = "or", negate = false, rows = {
			{ kind = "word", value = "keystone", negate = false }, { kind = "word", value = "crest", negate = false } } } } },
			Rows.FromText("keystone | crest"))
	end)

	-- Mutations: in Rows.lua's blockText, `return "!(" .. s .. ")"` -> `return "!" .. s`; or in asRow,
	-- `return { kind = t, value = node.value, negate = negate }` -> `... negate = false }` (a "!" row loses its "!").
	it("rows -> text -> rows is lossless for every shape the rows can show", function()
		local shapes = {
			"boe", "!boe", "gear & ilvl>=600", "potion | flask | food", "(potion | flask) & !junk", "a & b | c",
			"!(a & b) | c", "#trade goods", "\"healing potion\" | lure", "<536", ">150", "=480", "536", "400-450",
			"gear & 400-450", "ilvl>5 & !ilvl>600", "(a | b) | c", "(a & b) & c", "~boe || bop", "!\"x y\" & #rune",
			"gear & (ilvl>=400 | uncollected) & !bound", "epic & boe | rare & boe | !(junk | trash)", "value>=100.5",
			"gray", "fish | lure | bait",
		}
		for _, text in ipairs(shapes) do
			local rules, why = Rows.FromText(text)
			assert.truthy(rules, text .. " " .. tostring(why))
			local back = Rows.ToText(rules)
			assert.equal(pretty(text), back, text)
			assert.same(rules, Rows.FromText(back), text)
		end
		local r = Rows.FromText("(potion | flask) & !(junk & poor) & ilvl>5")
		assert.equal("and", r.join)
		assert.same({ "or", "and", "and" }, { r.blocks[1].join, r.blocks[2].join, r.blocks[3].join })
		assert.same({ false, true, false }, { r.blocks[1].negate, r.blocks[2].negate, r.blocks[3].negate })
		assert.same({ kind = "num", name = "ilvl", op = ">", raw = "5", negate = false }, r.blocks[3].rows[1])
		assert.same({ join = "and", blocks = {} }, Rows.FromText("  "))
		assert.equal("", Rows.ToText({ join = "or", blocks = { { join = "and", negate = false, rows = {} } } }))
	end)

	-- Mutation: in Rows.FromText, drop the `if n > Rows.MAX_ROWS or ...` check (a 41-row query opens as rows).
	it("queries the rows can't show open as text only, and say why", function()
		assert.same({ nil, "deep" }, { Rows.FromText("a & (b | (c & d))") })
		assert.same({ nil, "deep" }, { Rows.FromText("!!boe") })
		assert.same({ nil, "deep" }, { Rows.FromText("!(a | !(b & c))") })
		local rows40, rows41 = {}, {}
		for i = 1, 41 do
			rows41[i] = "w" .. i
			if i <= 40 then
				rows40[i] = "w" .. i
			end
		end
		assert.truthy(Rows.FromText(table.concat(rows40, " | ")))
		assert.same({ nil, "long" }, { Rows.FromText(table.concat(rows41, " | ")) })
		local groups = {}
		for i = 1, 11 do
			groups[i] = "(a" .. i .. " & b)"
		end
		assert.same({ nil, "long" }, { Rows.FromText(table.concat(groups, " | ")) })
		assert.same({ nil, "toolong" }, { Rows.FromText(string.rep("a", Rows.MAX_TEXT + 1)) })
		local none, why, err = Rows.FromText("boe &")
		assert.is_nil(none)
		assert.equal("error", why)
		assert.equal("VALUE", err.expected)
	end)

	-- Mutation: in Rows.lua's blockText, `if inside and (inside == b.join or b.join == "or") then` ->
	-- `if inside and inside == b.join then` (precedence changes which items match).
	it("fuzz: 400 random rule sets print as text that reads back the same and matches the same items", function()
		Fixtures.SmallBags(SB.Adapter)
		SB.Adapter.Put(0, 7, Fixtures.HERB, 40)
		SB.Adapter.Put(0, 8, Fixtures.UNLOADED, 1)
		SB.Adapter.Put(0, 9, Fixtures.TOY, 1)
		local records = {}
		for slot = 1, 9 do
			records[#records + 1] = SB.Items.Describe(0, slot)
		end
		local seed = 4242
		local function rnd(n)
			seed = seed * 16807 % 2147483647
			return seed % n + 1
		end
		local flags, numbers = {}, {}
		for _, fam in ipairs(Rows.FAMILIES) do
			for _, w in ipairs(fam.words) do
				if fam.numbers then
					numbers[#numbers + 1] = w
				else
					flags[#flags + 1] = w
				end
			end
		end
		local names = { "potion", "Healing", "of the", "tooth", "x y" }
		local function row()
			local k = rnd(5)
			local r
			if k == 1 then
				r = Rows.NewRow(names[rnd(#names)])
			elseif k == 2 then
				r = Rows.NewRow(nil)
				r.value = names[rnd(#names)]
			elseif k == 3 then
				r = { kind = "exact", value = flags[rnd(#flags)], negate = false }
			elseif k == 4 then
				r = Rows.NewRow(numbers[rnd(#numbers)], true)
				r.op, r.raw = Rows.NUMBER_OPS[rnd(5)], tostring(rnd(400))
			else
				r = Rows.NewRow(flags[rnd(#flags)])
			end
			r.negate = rnd(3) == 1
			return r
		end
		local function kleene(join, values, n)
			local out = join == "and"
			for i = 1, n do -- not ipairs: an unknown (nil) answer is a value here
				local v = values[i]
				if v == (join ~= "and") then
					return v
				elseif v == nil then
					out = nil
				end
			end
			return out
		end
		local function no(v, negate)
			if v == nil or not negate then
				return v
			end
			return not v
		end
		-- The reference: each row's own query, joined here, independent of ToText's parentheses.
		local function expect(rules, rec)
			local blocks = {}
			for i, b in ipairs(rules.blocks) do
				local vals = {}
				for j, r in ipairs(b.rows) do
					local single = Rows.ToText({ join = "and", blocks = { { join = "and", negate = false,
						rows = { { kind = r.kind, value = r.value, name = r.name, op = r.op, raw = r.raw, negate = false } } } } })
					local v = Q.Eval(Q.Compile(single), rec)
					vals[j] = no(v, r.negate)
				end
				local v = kleene(b.join, vals, #b.rows)
				blocks[i] = no(v, b.negate)
			end
			return kleene(rules.join, blocks, #rules.blocks)
		end
		local shown = 0
		for _ = 1, 400 do
			local rules = { join = rnd(2) == 1 and "and" or "or", blocks = {} }
			for i = 1, rnd(3) do
				local b = { join = rnd(2) == 1 and "and" or "or", negate = rnd(4) == 1, rows = {} }
				for j = 1, rnd(3) do
					b.rows[j] = row()
				end
				rules.blocks[i] = b
			end
			local text = Rows.ToText(rules)
			local again, why = Rows.FromText(text)
			assert.truthy(again, text .. " " .. tostring(why))
			assert.equal(text, Rows.ToText(again), text)
			assert.same(again, Rows.FromText(Rows.ToText(again)), text)
			local compiled = Q.Compile(text)
			assert.truthy(compiled.fn, text)
			for _, rec in ipairs(records) do
				local want = expect(rules, rec)
				assert.equal(want, Q.Eval(compiled, rec), text .. " on " .. tostring(rec.name))
				if want then
					shown = shown + 1
				end
			end
		end
		assert.truthy(shown > 300, "too few matches to mean anything: " .. shown)
	end)

	-- Mutation: in Rows.FAMILIES, drop "tab" from the numbers family.
	it("the keyword lists name every registered keyword once, each where it can be used", function()
		local listed, seen = {}, {}
		for _, fam in ipairs(Rows.FAMILIES) do
			assert.truthy(rawget(SB.L, fam.label), fam.label)
			for _, w in ipairs(fam.words) do
				local key = w .. (fam.numbers and "#" or "")
				assert.falsy(seen[key], "listed twice: " .. w)
				seen[key] = true
				local kind = Rows.KindOf(w)
				assert.truthy(kind, "not a keyword: " .. w)
				if fam.numbers then
					assert.truthy(kind == "number" or kind == "both", w)
				else
					assert.truthy(kind == "flag" or kind == "both", w)
				end
				listed[w] = true
			end
		end
		for name, kw in pairs(Q.keywords) do
			if kw.name == name then
				assert.truthy(listed[name], "missing from the lists: " .. name)
			end
		end
		assert.is_nil(Rows.KindOf("fish"))
		assert.equal("both", Rows.KindOf("gear"))
		assert.equal("flag", Rows.KindOf("GRAY"))
	end)

	-- Mutation: in Rows.Problem, drop the `elseif v:find("\"", 1, true) then return "QUOTE"` branch.
	it("a new row, and what keeps a row from being saved", function()
		assert.same({ kind = "word", value = "boe", negate = false }, Rows.NewRow("boe"))
		assert.same({ kind = "num", name = "ilvl", op = ">=", raw = "", negate = false }, Rows.NewRow("ilvl", true))
		assert.same({ kind = "text", value = "", negate = false }, Rows.NewRow(nil))
		assert.equal("NUMBER", Rows.Problem(Rows.NewRow("ilvl", true)))
		assert.is_nil(Rows.Problem({ kind = "num", name = "ilvl", op = ">=", raw = "600" }))
		assert.is_nil(Rows.Problem({ kind = "num", name = "value", op = ">", raw = "2.5" }))
		assert.equal("NUMBER", Rows.Problem({ kind = "num", name = "ilvl", op = ">=", raw = "6x" }))
		assert.equal("EMPTY", Rows.Problem(Rows.NewRow(nil)))
		assert.equal("QUOTE", Rows.Problem({ kind = "text", value = "say \"hi\"" }))
		assert.is_nil(Rows.Problem({ kind = "text", value = "Metal & Stone (rare)" }))
		assert.equal("WORD", Rows.Problem({ kind = "word", value = "a&b" }))
		assert.equal("WORD", Rows.Problem({ kind = "word", value = "536" }))
		assert.equal("WORD", Rows.Problem({ kind = "word", value = "a  b" }))
		assert.is_nil(Rows.Problem({ kind = "word", value = "trade goods" }))
	end)
end)
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1547 passed, 6 failed`. The failures, exactly:

- `spec/query_rows_spec.lua :: Rule rows (week 11) > every built-in category query turns into rows and back into the same query`
- `spec/query_rows_spec.lua :: Rule rows (week 11) > rows -> text -> rows is lossless for every shape the rows can show`
- `spec/query_rows_spec.lua :: Rule rows (week 11) > queries the rows can't show open as text only, and say why`
- `spec/query_rows_spec.lua :: Rule rows (week 11) > fuzz: 400 random rule sets print as text that reads back the same and matches the same items`
- `spec/query_rows_spec.lua :: Rule rows (week 11) > the keyword lists name every registered keyword once, each where it can be used`
- `spec/query_rows_spec.lua :: Rule rows (week 11) > a new row, and what keeps a row from being saved`

All six fail in `before_each`, which loads `SwagBag/Engine/Query/Rows.lua`: it does not exist yet.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "every built-in category query turns into rows and back into the same query": in `SwagBag/Engine/Query/Rows.lua`, `return { join = node.type, negate = negate, rows = rows }` → `return { join = "and", negate = negate, rows = rows }`.
- "rows -> text -> rows is lossless for every shape the rows can show": in `SwagBag/Engine/Query/Rows.lua`, `return "!(" .. s .. ")"` → `return "!" .. s`.
- "rows -> text -> rows is lossless for every shape the rows can show": in `SwagBag/Engine/Query/Rows.lua`, `return { kind = t, value = node.value, negate = negate }` → `return { kind = t, value = node.value, negate = false }`.
- "queries the rows can't show open as text only, and say why": in `SwagBag/Engine/Query/Rows.lua`, `if n > Rows.MAX_ROWS or #rules.blocks > Rows.MAX_BLOCKS then` → `if false then`.
- "fuzz: 400 random rule sets print as text that reads back the same and matches the same items": in `SwagBag/Engine/Query/Rows.lua`, `if inside and (inside == b.join or b.join == "or") then` → `if inside and inside == b.join then`.
- "the keyword lists name every registered keyword once, each where it can be used": in `SwagBag/Engine/Query/Rows.lua`, `"count", "stack", "tab" }` → `"count", "stack" }`.
- "a new row, and what keeps a row from being saved": in `SwagBag/Engine/Query/Rows.lua`, `elseif v:find("\"", 1, true) then ⏎ return "QUOTE"` → ∅.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Init.lua`, find:

```lua
SB.VERSION = "0.10.0"
```

and replace it with:

```lua
SB.VERSION = "0.11.0"
```

Create `SwagBag/Engine/Query/Rows.lua`:

```lua
-- SwagBag rule rows (week 11, spec F6 AC6.1): a category's query as rows the category editor shows and changes,
-- and back to text. Pure Lua: reads SB.QueryParser and SB.Query only.
-- The rows (rules) are two levels deep, as the editor shows them:
--   rules = { join = "and" | "or", blocks = { block, ... } }      how the groups combine
--   block = { join = "and" | "or", negate = bool, rows = { row, ... } }
--   row   = { kind = "word", value, negate }    a bare word: a keyword ("boe"), else an item-name match ("fish")
--           { kind = "text", value, negate }    a quoted item name ("Healing Potion")
--           { kind = "exact", value, negate }   #keyword: the keyword only
--           { kind = "num", name, op, raw, negate }   ilvl>=600 (op = < <= > >=, raw = the number as typed)
-- Lossless (AC6.1): for every query FromText accepts, ToText(FromText(t)) is Query.Pretty of t's tree (the same
-- tree, the same items), and FromText(ToText(r)) gives r back for every r FromText made. A query the rows cannot
-- show (nesting deeper than groups of rows, "!!", too many rows, too long, or not a query at all) opens as text
-- only; FromText says why. Nothing here runs or stores anything.
--   Rows.FromText(text) -> rules | nil, why, err   why: "error" (err = the parse error), "deep", "long", "toolong"
--   Rows.ToText(rules) -> text          empty groups are left out; "" when there is no row at all
--   Rows.FAMILIES                       the editor's keyword lists: { { label = Locale key, words = { ... } } }
--   Rows.KindOf(word) -> "flag" | "number" | "both" | nil (not a keyword: an item-name match)
--   Rows.NewRow(word, asNumber) -> row  a keyword row, a number row (asNumber), or an empty name row (word nil)
--   Rows.Problem(row) -> nil | "EMPTY" | "QUOTE" | "NUMBER" | "WORD"   what keeps a row from being saved
local _, SB = ...

local Rows = { MAX_ROWS = 40, MAX_BLOCKS = 10, MAX_TEXT = 500 }
SB.QueryRows = Rows

-- Every registered keyword, once, by family (the spec 7.3 table). A test checks this against the registry.
Rows.FAMILIES = {
	{ label = "KW_FAMILY_TYPE", words = { "gear", "armor", "weapon", "consumable", "potion", "flask", "food", "elixir",
		"rune", "reagent", "tradegoods", "herb", "ore", "leather", "cloth", "enchanting", "cooking", "gem", "recipe",
		"questitem", "key", "keystone", "crest", "pet", "mount", "toy", "housing", "cosmetic", "container",
		"miscellaneous", "junk", "profession", "profession tool", "profession gear" } },
	{ label = "KW_FAMILY_QUALITY", words = { "poor", "common", "uncommon", "rare", "epic", "legendary", "artifact",
		"heirloom" } },
	{ label = "KW_FAMILY_BINDING", words = { "boe", "bop", "warbound", "wue", "bound", "soulbound", "tradeable" } },
	{ label = "KW_FAMILY_NUMBER", numbers = true, words = { "ilvl", "gear", "level", "value", "count", "stack", "tab" } },
	{ label = "KW_FAMILY_STATE", words = { "new", "locked", "inuse", "uncollected", "cooldown", "usable", "equipped",
		"upgrade", "partial" } },
	{ label = "KW_FAMILY_SLOT", words = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs",
		"feet", "finger", "trinket", "mainhand", "offhand", "one-hand", "twohand", "ranged", "shirt", "tabard", "bag" } },
	{ label = "KW_FAMILY_PLACE", words = { "bags", "backpack", "reagentbag", "bank", "warband" } },
}

Rows.NUMBER_OPS = { ">=", ">", "=", "<", "<=" }

function Rows.KindOf(word)
	local kw = type(word) == "string" and SB.Query.Lookup(word) or nil
	if not kw then
		return nil
	end
	if kw.eval and kw.value then
		return "both"
	end
	return kw.eval and "flag" or "number"
end

local function asRow(node)
	local negate = false
	if node.type == "not" then
		negate, node = true, node.item
	end
	local t = node.type
	if t == "word" or t == "text" or t == "exact" then
		return { kind = t, value = node.value, negate = negate }
	elseif t == "num" then
		return { kind = "num", name = node.name, op = node.op, raw = node.raw, negate = negate }
	end
	return nil
end

-- A group: one row, rows joined by one operator, or "!" before such a join.
local function asBlock(node)
	local row = asRow(node)
	if row then
		return { join = "and", negate = false, rows = { row } }
	end
	local negate = false
	if node.type == "not" then
		negate, node = true, node.item
	end
	if node.type ~= "and" and node.type ~= "or" then
		return nil
	end
	local rows = {}
	for i, child in ipairs(node.items) do
		rows[i] = asRow(child)
		if not rows[i] then
			return nil
		end
	end
	return { join = node.type, negate = negate, rows = rows }
end

function Rows.FromText(text)
	text = type(text) == "string" and text or ""
	if #text > Rows.MAX_TEXT then
		return nil, "toolong"
	end
	if not text:find("%S") then
		return { join = "and", blocks = {} }
	end
	local ast, err = SB.QueryParser.Parse(text)
	if not ast then
		return nil, "error", err
	end
	local rules
	local whole = asBlock(ast)
	if whole then
		rules = { join = "and", blocks = { whole } }
	elseif ast.type == "and" or ast.type == "or" then
		rules = { join = ast.type, blocks = {} }
		for i, child in ipairs(ast.items) do
			rules.blocks[i] = asBlock(child)
			if not rules.blocks[i] then
				return nil, "deep"
			end
		end
	else
		return nil, "deep"
	end
	local n = 0
	for _, b in ipairs(rules.blocks) do
		n = n + #b.rows
	end
	if n > Rows.MAX_ROWS or #rules.blocks > Rows.MAX_BLOCKS then
		return nil, "long"
	end
	return rules
end

local function rowText(r, negate)
	local s
	if r.kind == "num" then
		s = r.name .. r.op .. r.raw
	elseif r.kind == "text" then
		s = "\"" .. r.value .. "\""
	elseif r.kind == "exact" then
		s = "#" .. r.value
	else
		s = r.value
	end
	return negate and ("!" .. s) or s
end

-- inside: the operator joining the groups, or nil for a group on its own. Parentheses only where Query.Pretty
-- puts them, so the text is the canonical one.
local function blockText(b, inside)
	if #b.rows == 1 then
		-- "!" on a one-row group is that row's own "!" (never "!!", which the rows cannot show)
		return rowText(b.rows[1], b.rows[1].negate ~= (b.negate == true))
	end
	local parts = {}
	for i, r in ipairs(b.rows) do
		parts[i] = rowText(r, r.negate)
	end
	local s = table.concat(parts, b.join == "or" and " | " or " & ")
	if b.negate then
		return "!(" .. s .. ")"
	end
	if inside and (inside == b.join or b.join == "or") then
		return "(" .. s .. ")"
	end
	return s
end

function Rows.ToText(rules)
	local blocks = {}
	for _, b in ipairs(rules.blocks or {}) do
		if #b.rows > 0 then
			blocks[#blocks + 1] = b
		end
	end
	if #blocks == 0 then
		return ""
	elseif #blocks == 1 then
		return blockText(blocks[1], nil)
	end
	local parts = {}
	for i, b in ipairs(blocks) do
		parts[i] = blockText(b, rules.join)
	end
	return table.concat(parts, rules.join == "or" and " | " or " & ")
end

function Rows.NewRow(word, asNumber)
	if word == nil then
		return { kind = "text", value = "", negate = false }
	elseif asNumber then
		return { kind = "num", name = word, op = ">=", raw = "", negate = false }
	end
	return { kind = "word", value = word, negate = false }
end

-- What keeps a row from being saved: an empty value, a double quote in a name (it would end the name), a number
-- that is not one, or a bare word that would not read back as the same word.
function Rows.Problem(row)
	if row.kind == "num" then
		if not (type(row.raw) == "string" and row.raw:match("^%d+%.?%d*$") and tonumber(row.raw)) then
			return "NUMBER"
		end
		return nil
	end
	local v = row.value
	if type(v) ~= "string" or not v:find("%S") then
		return "EMPTY"
	elseif v:find("\"", 1, true) then
		return "QUOTE"
	elseif row.kind ~= "text" and (v:find("[&|!~()#=<>]") or v:find("%s%s") or v ~= v:match("^%s*(.-)%s*$")
		or (row.kind == "word" and (v:match("^%d+$") or v:match("^%d+%-%d+$")))) then
		return "WORD" -- a bare 536 or 400-450 is an item level, not a word
	end
	return nil
end
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_LOCKS = "Locks: %d locked; destroy warnings %s"
```

and replace it with:

```lua
L.REPORT_LOCKS = "Locks: %d locked; destroy warnings %s"

-- Category editor (week 11): Engine/Query/Rows.lua's keyword lists, UI/SettingsCategories.lua
L.KW_FAMILY_TYPE = "Item type"
L.KW_FAMILY_QUALITY = "Quality"
L.KW_FAMILY_BINDING = "Binding"
L.KW_FAMILY_NUMBER = "Numbers (item level, gold...)"
L.KW_FAMILY_STATE = "State"
L.KW_FAMILY_SLOT = "Gear slot"
L.KW_FAMILY_PLACE = "Where it is"
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
## Version: 0.10.0
```

and replace it with:

```text
## Version: 0.11.0
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
Engine/Crests.lua
```

and replace it with:

```text
Engine/Query/Rows.lua
Engine/Crests.lua
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1553 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (77 files)`, `1553 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Init.lua \
	SwagBag/Engine/Query/Rows.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	spec/query_rows_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 11 Task 1: rule rows: a query as editable rows and back, losslessly; v0.11.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 2: The category writers: create, save, delete, move, preview (Engine/Categories.lua)

What the editor's buttons do, as engine functions with no UI, each refusing while the settings are read-only and loading the categories again after a change. `Create` makes a user category with a checked name (D8: On, priority 88, first in the bags, id `u_<name>`). `Save` writes a user category's fields, or a built-in's difference from its default only (spec 8.5, D12; a field set back to its default is removed, and so is an empty diff); a rule that does not compile is saved **switched off** and answered with `"broken"` and the error (AC6.2, D7); the four pinned built-ins keep their priority, others stay in 1–89 (D9). `Delete` removes a user category and its id from the order, every focus mode's sections (account and this character, both layers) and this character's collapsed sections, and tells Focus once (D11). `Move` swaps a category with its neighbour in the display order and saves the whole order (D10). `Preview` counts the bags' items a rule matches now, for the editor's line (D6). `ResetBuiltin` refuses while read-only and answers true. `/swagbag mode list` leaves out an id that is no category any more (another character's own focus sections can still hold a deleted one).

**Files:**
- Modify: `SwagBag/Engine/Categories.lua`, `SwagBag/Engine/Focus.lua` (`sectionNames`)
- Test: `spec/categories_edit_spec.lua` (new)

**Interfaces:**
- Consumes: `Categories.Load/Ensure`, the local `editFor` and `prune` (week 2), `SB.CategoryDefaults`, `SB.Query.Compile/FormatError/Eval`, `SB.Config.db/charDB/Defaults/UI/readOnly`, `SB.Inventory.Iterate`, `SB.Items.Describe`, `SB.Emit("SB_CONFIG_CHANGED")`.
- Produces: `Categories.MAX_NAME = 30`, `MAX_QUERY = 500`, `USER_PRIORITY = 88`, `MIN_PRIORITY = 1`, `MAX_PRIORITY = 89`, `PINNED`; `CheckName(name, exceptId) -> name | nil, "EMPTY" | "LONG" | "CHARS" | "TAKEN"`; `Create(name, query, source) -> id | nil, why` (and `id, "broken", error`); `Save(id, fields) -> true | true, "broken", error | false, why`; `Delete(id)`, `Move(id, step)`, `ResetBuiltin(id) -> true | false, why`; `Preview(query) -> matches, total | nil, message`.

- [ ] **Step 1: Write the failing tests**

Create `spec/categories_edit_spec.lua`:

```lua
-- Week 11 (spec F6, AC6.2): the category editor's writers in Engine/Categories.lua. A user category is made, saved,
-- moved and deleted here; a built-in keeps only the user's difference (spec 8.5); a broken rule is saved switched
-- off with its error, never dropped; every writer refuses while the settings are read-only.
local Loader = dofile("spec/helpers/loader.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Category editing (week 11)", function()
	local SB, C, L, changed
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		C, L = SB.Categories, SB.L
		C.Load()
		changed = 0
		SB.On("SB_CONFIG_CHANGED", function()
			changed = changed + 1
		end)
	end)

	-- Mutations: in Categories.CheckName, drop the `for _, c in ipairs(C.list) do ... end` loop (a taken name is
	-- accepted); or in Categories.Create, `table.insert(db.categoryOrder, 1, id)` -> `table.insert(db.categoryOrder, id)`.
	it("Create: a user category with a checked name, shown first, at priority 88", function()
		local id = C.Create("  My potions ", "potion")
		assert.equal("u_my_potions", id)
		local c = C.Get(id)
		assert.same({ "My potions", "potion", 88, true, false, "user" }, { c.name, c.query, c.priority, c.enabled, c.builtin,
			c.source })
		assert.same({ "new", id, "c_keystone" }, { unpack(C.SectionOrder(), 1, 3) })
		assert.equal("u_my_potions_2", C.Create("My potions!", "potion"), "another name, the same id stem")
		assert.same({ nil, "TAKEN" }, { C.Create("my POTIONS", "flask") })
		assert.same({ nil, "TAKEN" }, { C.Create("Gear", "flask") })
		assert.same({ nil, "TAKEN" }, { C.Create("new", "flask") })
		assert.same({ nil, "EMPTY" }, { C.Create("   ", "flask") })
		assert.same({ nil, "LONG" }, { C.Create(string.rep("x", C.MAX_NAME + 1), "flask") })
		assert.same({ nil, "CHARS" }, { C.Create("|cffff0000Red", "flask") })
		assert.same({ nil, "long" }, { C.Create("Long", string.rep("a", C.MAX_QUERY + 1)) })
		SB.Config.db.categoryOrder = { "c_gear", "c_keystone" }
		local third = C.Create("Third", "toy")
		assert.same({ third, "c_gear", "c_keystone" }, SB.Config.db.categoryOrder, "a saved order gets it first")
		assert.equal(third, C.SectionOrder()[2])
	end)

	-- Mutation: in Categories.Save, drop `out.enabled = false -- AC6.2: ...` (a broken rule stays switched on).
	it("AC6.2: a rule that doesn't compile is saved switched off with its error, never dropped; fixed, it is on again", function()
		local id, why, err = C.Create("Broken one", "boe &")
		assert.equal("u_broken_one", id)
		assert.equal("broken", why)
		assert.equal("Expected a value after \"&\" at character 6", err)
		local c = C.Get(id)
		assert.same({ "boe &", false, err }, { c.query, c.enabled, c.error })
		assert.same({ "boe &", false }, { SB.Config.db.categories[id].query, SB.Config.db.categories[id].enabled })
		local _, _, broken = C.Counts()
		assert.same({ "Broken one" }, broken, "the report names it")
		assert.truthy(C.Save(id, { query = "boe", enabled = true }))
		assert.same({ true, nil }, { C.Get(id).enabled, C.Get(id).error })
		assert.same({ true, "broken", "Expected a closing ) after \"boe\" at character 5" },
			{ C.Save(id, { query = "(boe", enabled = true }) })
		assert.same({ false, "(boe" }, { C.Get(id).enabled, C.Get(id).query })
		assert.equal(false, SB.Config.db.categories[id].enabled, "saved switched off (spec 7.10)")
	end)

	-- Mutation: in Categories.Save, `if def and (v == def[f] or ...) then` -> `if false then` (an unchanged field of a
	-- built-in is stored).
	it("a built-in keeps only the user's difference; Reset to default removes it; its rank rules hold", function()
		assert.truthy(C.Save("c_gear", { name = "Gear", query = "gear & !junk", priority = 70, enabled = true }))
		assert.same({ query = "gear & !junk" }, SB.Config.db.userEdits.c_gear)
		assert.equal("gear & !junk", C.Get("c_gear").query)
		assert.truthy(C.Save("c_gear", { query = "gear", name = "My gear", enabled = false }))
		assert.same({ name = "My gear", enabled = false }, SB.Config.db.userEdits.c_gear)
		assert.truthy(C.Save("c_gear", { name = "Gear", enabled = true }))
		assert.is_nil(SB.Config.db.userEdits.c_gear, "nothing left: nothing stored")
		assert.truthy(C.Save("c_gear", { priority = 89 }))
		assert.truthy(C.ResetBuiltin("c_gear"))
		assert.is_nil(SB.Config.db.userEdits.c_gear)
		assert.equal(70, C.Get("c_gear").priority)
		assert.same({ false, "pinned" }, { C.Save("c_junk", { priority = 50 }) })
		assert.truthy(C.Save("c_junk", { priority = 90, name = "Trash" }), "its own rank is no change")
		assert.same({ name = "Trash" }, SB.Config.db.userEdits.c_junk)
		for _, bad in ipairs({ 90, 0, 2.5, "50" }) do
			assert.same({ false, "priority" }, { C.Save("c_gear", { priority = bad }) }, tostring(bad))
		end
		assert.same({ false, "TAKEN" }, { C.Save("c_gear", { name = "ore" }) })
		assert.truthy(C.Save("c_gear", { name = "GEAR" }), "its own name, another case")
		assert.same({ false, "unknown" }, { C.Save("c_nope", { name = "x" }) })
	end)

	-- Mutation: in Categories.Delete, drop the `left = without(Cfg.charDB.overrides[path], id)` block (this
	-- character's own focus sections keep the id).
	it("deleting a user category takes it out of the order, every focus mode and the collapsed sections", function()
		local id = C.Create("Pots", "potion")
		local keep = C.Create("Keep", "flask")
		SB.Config.Set("focus.sections.mplus", "c_consumables," .. id .. ",c_gear")
		SB.Config.CharOverride("focus.sections.market", true)
		SB.Config.Set("focus.sections.market", id .. ",c_junk")
		SB.Config.db.categoryOrder = { id, keep, "c_gear" }
		SB.Config.UI().collapsed.bags = { [id] = true, c_gear = true }
		changed = 0
		assert.truthy(C.Delete(id))
		assert.is_nil(C.Get(id))
		assert.is_nil(SB.Config.db.categories[id])
		assert.same({ keep, "c_gear" }, SB.Config.db.categoryOrder)
		assert.equal("c_consumables,c_gear", SB.Config.Get("focus.sections.mplus"))
		assert.equal("c_junk", SB.Config.Get("focus.sections.market"))
		assert.same({ c_gear = true }, SB.Config.UI().collapsed.bags)
		assert.equal(1, changed, "Focus is told once")
		assert.same({ false, "builtin" }, { C.Delete("c_gear") })
		assert.same({ false, "unknown" }, { C.Delete(id) })
		assert.truthy(C.Delete(keep))
		assert.equal(1, changed, "nothing opened it: no event")
	end)

	-- Mutation: in Focus.lua's sectionNames, `if not SB.Categories or sid == SB.Categories.FREE or
	-- SB.Categories.Get(sid) then` -> `if true then` (a deleted id is named in /swagbag mode list).
	it("a deleted category another character still opens is not named in /swagbag mode list", function()
		SB.Config.Set("focus.sections.fishing", "c_fish,u_gone,free")
		local line = SB.Focus.ListLines()[5]
		assert.equal(L.MODE_LIST_LINE:format(L.MODE_FISHING, L.OVERLAY_ON, "", "Fish & Lures, Free"), line)
	end)

	-- Mutation: in Categories.Move, `if to < 1 or to > #order then` -> `if to < 1 then`.
	it("Move: one place up or down in the display order, saved; past either end refused", function()
		assert.truthy(C.Move("c_consumables", -1))
		assert.same({ "new", "c_consumables", "c_keystone", "c_gear" }, { unpack(C.SectionOrder(), 1, 4) })
		assert.equal("c_consumables", SB.Config.db.categoryOrder[1])
		assert.same({ false, "edge" }, { C.Move("c_consumables", -1) })
		assert.same({ false, "edge" }, { C.Move("c_other", 1) })
		assert.truthy(C.Move("c_keystone", 1))
		assert.same({ "c_consumables", "c_gear", "c_keystone" }, { unpack(SB.Config.db.categoryOrder, 1, 3) })
		assert.same({ false, "unknown" }, { C.Move("u_none", 1) })
	end)

	-- Mutation: in Categories.ResetBuiltin, drop the read-only refusal (the diff is removed while read-only).
	it("read-only: every writer refuses and changes nothing", function()
		local id = C.Create("Mine", "toy")
		assert.truthy(C.Save("c_gear", { name = "Kit" }))
		SB.Config.readOnly = true
		assert.same({ nil, "readonly" }, { C.Create("Other", "pet") })
		assert.same({ false, "readonly" }, { C.Save(id, { name = "Ours" }) })
		assert.same({ false, "readonly" }, { C.Delete(id) })
		assert.same({ false, "readonly" }, { C.Move(id, 1) })
		assert.same({ false, "readonly" }, { C.ResetBuiltin("c_gear") })
		assert.same({ name = "Kit" }, SB.Config.db.userEdits.c_gear)
		assert.equal("Mine", C.Get(id).name)
	end)

	-- Mutation: in Categories.Preview, `if SB.Query.Eval(compiled, record) == true then` -> `if SB.Query.Eval(compiled,
	-- record) ~= false then` (an item still loading counts as a match).
	it("Preview counts the bags' items a rule matches now; an error or a failing keyword says why", function()
		Fixtures.SmallBags(SB.Adapter)
		SB.Adapter.Put(0, 7, Fixtures.UNLOADED, 1)
		SB.Inventory.ScanAll()
		assert.same({ 2, 7 }, { C.Preview("potion | flask") })
		assert.same({ 7, 7 }, { C.Preview("") }, "no rule: every item")
		assert.same({ 0, 7 }, { C.Preview("boe & !gear") })
		assert.same({ 1, 7 }, { C.Preview("gear & ilvl>=280 | epic & !keystone & !gear") })
		assert.same({ nil, "Expected a value after \"|\" at character 9" }, { C.Preview("potion |") })
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("boom") end })
		assert.same({ nil, L.SEARCH_EVAL_FAILED }, { C.Preview("boom") })
	end)
end)
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1553 passed, 8 failed`. The failures, exactly:

- `spec/categories_edit_spec.lua :: Category editing (week 11) > Create: a user category with a checked name, shown first, at priority 88`
- `spec/categories_edit_spec.lua :: Category editing (week 11) > AC6.2: a rule that doesn't compile is saved switched off with its error, never dropped; fixed, it is on again`
- `spec/categories_edit_spec.lua :: Category editing (week 11) > a built-in keeps only the user's difference; Reset to default removes it; its rank rules hold`
- `spec/categories_edit_spec.lua :: Category editing (week 11) > deleting a user category takes it out of the order, every focus mode and the collapsed sections`
- `spec/categories_edit_spec.lua :: Category editing (week 11) > a deleted category another character still opens is not named in /swagbag mode list`
- `spec/categories_edit_spec.lua :: Category editing (week 11) > Move: one place up or down in the display order, saved; past either end refused`
- `spec/categories_edit_spec.lua :: Category editing (week 11) > read-only: every writer refuses and changes nothing`
- `spec/categories_edit_spec.lua :: Category editing (week 11) > Preview counts the bags' items a rule matches now; an error or a failing keyword says why`

Seven fail because the writers (`Create`, `Move`, `Preview`...) do not exist yet; "a deleted category another character still opens..." fails because `/swagbag mode list` still names `u_gone`.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "Create: a user category with a checked name, shown first, at priority 88": in `SwagBag/Engine/Categories.lua`, `for _, c in ipairs(C.list) do ⏎ if c.id ~= exceptId and type(c.name) == "string" and c.name:lower() == low then ⏎ return nil, "TAKEN" ⏎ end ⏎ end` → ∅.
- "Create: a user category with a checked name, shown first, at priority 88": in `SwagBag/Engine/Categories.lua`, `table.insert(db.categoryOrder, 1, id)` → `table.insert(db.categoryOrder, id)`.
- "AC6.2: a rule that doesn't compile is saved switched off with its error, never dropped; fixed, it is on again": in `SwagBag/Engine/Categories.lua`, `out.enabled = false -- AC6.2: saved, switched off, the error shown` → ∅.
- "a built-in keeps only the user's difference; Reset to default removes it; its rank rules hold": in `SwagBag/Engine/Categories.lua`, `if def and (v == def[f] or (f == "enabled" and v == true and def.enabled == nil)) then` → `if false then`.
- "deleting a user category takes it out of the order, every focus mode and the collapsed sections": in `SwagBag/Engine/Categories.lua`, `left = without(Cfg.charDB.overrides[path], id) ⏎ if left then ⏎ Cfg.charDB.overrides[path], changed = left, true ⏎ end` → ∅.
- "a deleted category another character still opens is not named in /swagbag mode list": in `SwagBag/Engine/Focus.lua`, `if not SB.Categories or sid == SB.Categories.FREE or SB.Categories.Get(sid) then` → `if true then`.
- "Move: one place up or down in the display order, saved; past either end refused": in `SwagBag/Engine/Categories.lua`, `if to < 1 or to > #order then` → `if to < 1 then`.
- "read-only: every writer refuses and changes nothing": in `SwagBag/Engine/Categories.lua`, `return false, "readonly" -- week 11: the editor's Reset to default refuses, as every writer` → ∅.
- "Preview counts the bags' items a rule matches now; an error or a failing keyword says why": in `SwagBag/Engine/Categories.lua`, `if SB.Query.Eval(compiled, record) == true then` → `if SB.Query.Eval(compiled, record) ~= false then`.

- [ ] **Step 3: Write the code**

In `SwagBag/Engine/Categories.lua` (edit 1 of 4), find:

```lua
-- Runtime category: { id, name, query, priority, displayOrder, enabled, builtin, source,
```

and replace it with:

```lua
-- The category editor's writers (week 11, spec F6; UI/SettingsCategories.lua). Each refuses while the settings are
-- read-only and changes nothing then; each loads the categories again after a change:
--   Categories.CheckName(name, exceptId) -> name (trimmed) | nil, why   why: "EMPTY" | "LONG" | "CHARS" | "TAKEN"
--   Categories.Create(name, query, source) -> id | nil, why, detail      a user category ("u_..."), shown first
--   Categories.Save(id, fields) -> ok, why, detail   fields: name, query, priority, enabled (each optional). A
--     built-in keeps only what differs from its default (spec 8.5). A query that does not compile is saved, switched
--     off, and the answer is true, "broken", the error text (AC6.2: never dropped)
--   Categories.Delete(id) -> ok, why       a user category only; its id leaves the order, every focus mode's sections
--     (account-wide and this character's) and this character's collapsed sections
--   Categories.Move(id, step) -> ok, why   one place up (-1) or down (+1) in the display order
--   Categories.Preview(query) -> matches, total | nil, message     the bags' slots the query matches now
--   why (all writers): "readonly" | "unknown" | "builtin" | "pinned" | "priority" | "long" | "edge" or a name why
-- Runtime category: { id, name, query, priority, displayOrder, enabled, builtin, source,
```

In `SwagBag/Engine/Categories.lua` (edit 2 of 4), find:

```lua
function C.ResetBuiltin(id)
```

and replace it with:

```lua
function C.ResetBuiltin(id)
	if SB.Config.readOnly then
		return false, "readonly" -- week 11: the editor's Reset to default refuses, as every writer
	end
```

In `SwagBag/Engine/Categories.lua` (edit 3 of 4), find:

```lua
end

-- Called by the Categorizer when a category's rule throws. Returns true the first time
```

and replace it with:

```lua
	return true
end

-- Called by the Categorizer when a category's rule throws. Returns true the first time
```

In `SwagBag/Engine/Categories.lua` (edit 4 of 4), find:

```lua
SB.On("SB_LOGIN", function()
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- The category editor's writers (week 11, spec F6)
---------------------------------------------------------------------------
C.MAX_NAME, C.MAX_QUERY = 30, 500
-- A category you make starts at 88: above every built-in but Reagents, Keystone & Crests, Equipment sets and Junk,
-- which it may never outrank (the share-string rule, F20). Priorities go from 1 to 89.
C.USER_PRIORITY, C.MIN_PRIORITY, C.MAX_PRIORITY = 88, 1, 89
C.PINNED = { c_junk = true, c_sets = true, c_keystone = true, c_reagents = true }

local function default(id)
	for _, def in ipairs(SB.CategoryDefaults) do
		if def.id == id then
			return def
		end
	end
end

function C.CheckName(name, exceptId)
	name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
	if name == "" then
		return nil, "EMPTY"
	elseif #name > C.MAX_NAME then
		return nil, "LONG"
	elseif name:find("[%c|]") then
		return nil, "CHARS" -- "|" starts a chat code (a colour, a link)
	end
	C.Ensure()
	local low = name:lower()
	if low == SB.L.CAT_NEW:lower() or low == SB.L.CAT_FREE:lower() then
		return nil, "TAKEN"
	end
	for _, c in ipairs(C.list) do
		if c.id ~= exceptId and type(c.name) == "string" and c.name:lower() == low then
			return nil, "TAKEN"
		end
	end
	return name
end

local function queryWhy(query)
	if type(query) ~= "string" then
		return "long"
	elseif #query > C.MAX_QUERY then
		return "long"
	end
end

-- The error text of a query that does not compile, or nil.
local function broken(query)
	local compiled = SB.Query.Compile(query)
	if compiled.fn then
		return nil
	end
	return SB.Query.FormatError(compiled.errors[1])
end

function C.Create(name, query, source)
	if SB.Config.readOnly then
		return nil, "readonly"
	end
	query = query or ""
	local clean, why = C.CheckName(name)
	if not clean then
		return nil, why
	end
	if queryWhy(query) then
		return nil, "long"
	end
	local db = SB.Config.db
	db.categories = type(db.categories) == "table" and db.categories or {}
	local slug = clean:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""):sub(1, 20)
	local base = "u_" .. (slug ~= "" and slug or "category")
	local id, n = base, 1
	while db.categories[id] ~= nil or C.byId[id] do
		n = n + 1
		id = base .. "_" .. n
	end
	local def = { name = clean, query = query, priority = C.USER_PRIORITY, enabled = true,
		source = source == "import" and "import" or "user" }
	local err = broken(query)
	if err then
		def.enabled = false
	end
	if type(db.categoryOrder) == "table" then
		table.insert(db.categoryOrder, 1, id)
	else
		def.displayOrder = 5 -- before Keystone & Crests (10): a new category shows first
	end
	db.categories[id] = def
	C.Load()
	if err then
		return id, "broken", err
	end
	return id
end

function C.Save(id, fields)
	if SB.Config.readOnly then
		return false, "readonly"
	end
	C.Ensure()
	local c = C.byId[id]
	if not c or type(fields) ~= "table" then
		return false, "unknown"
	end
	local out = {}
	if fields.name ~= nil then
		local clean, why = C.CheckName(fields.name, id)
		if not clean then
			return false, why
		end
		out.name = clean
	end
	if fields.query ~= nil then
		if queryWhy(fields.query) then
			return false, "long"
		end
		out.query = fields.query
	end
	local p = fields.priority
	if p ~= nil and p ~= c.priority then
		if C.PINNED[id] then
			return false, "pinned" -- Junk, Sets, Keystone & Crests and Reagents keep their rank
		elseif type(p) ~= "number" or p ~= math.floor(p) or p < C.MIN_PRIORITY or p > C.MAX_PRIORITY then
			return false, "priority"
		end
		out.priority = p
	end
	if fields.enabled ~= nil then
		out.enabled = fields.enabled == true
	end
	local err = broken(out.query or c.query or "")
	if err then
		out.enabled = false -- AC6.2: saved, switched off, the error shown
	end
	local e = editFor(c)
	local def = c.builtin and default(id) or nil
	for f, v in pairs(out) do
		if def and (v == def[f] or (f == "enabled" and v == true and def.enabled == nil)) then
			e[f] = nil -- a built-in keeps only what differs from its default (spec 8.5)
		else
			e[f] = v
		end
	end
	prune(c, e)
	C.Load()
	if err then
		return true, "broken", err
	end
	return true
end

-- One section id out of a comma-separated list; the new list, or nil when it was not there.
local function without(ids, id)
	if type(ids) ~= "string" then
		return nil
	end
	local out, found = {}, false
	for sid in ids:gmatch("[^,]+") do
		if sid == id then
			found = true
		else
			out[#out + 1] = sid
		end
	end
	return found and table.concat(out, ",") or nil
end

function C.Delete(id)
	if SB.Config.readOnly then
		return false, "readonly"
	end
	C.Ensure()
	local c = C.byId[id]
	if not c then
		return false, "unknown"
	elseif c.builtin then
		return false, "builtin"
	end
	local Cfg = SB.Config
	Cfg.db.categories[id] = nil
	if type(Cfg.db.categoryOrder) == "table" then
		for i = #Cfg.db.categoryOrder, 1, -1 do
			if Cfg.db.categoryOrder[i] == id then
				table.remove(Cfg.db.categoryOrder, i)
			end
		end
	end
	-- Focus modes that opened it (spec 6.1): the account's sections and this character's own, both layers.
	local account = type(Cfg.db.settings.focus) == "table" and type(Cfg.db.settings.focus.sections) == "table"
		and Cfg.db.settings.focus.sections or {}
	local changed = false
	for mode in pairs(Cfg.Defaults.settings.focus.sections) do
		local left = without(account[mode], id)
		if left then
			account[mode], changed = left, true
		end
		local path = "focus.sections." .. mode
		left = without(Cfg.charDB.overrides[path], id)
		if left then
			Cfg.charDB.overrides[path], changed = left, true
		end
	end
	local collapsed = Cfg.UI().collapsed
	for _, windowSet in pairs(type(collapsed) == "table" and collapsed or {}) do
		if type(windowSet) == "table" then
			windowSet[id] = nil
		end
	end
	C.Load()
	if changed then
		SB.Emit("SB_CONFIG_CHANGED", nil) -- Focus reads its sections again
	end
	return true
end

function C.Move(id, step)
	if SB.Config.readOnly then
		return false, "readonly"
	end
	C.Ensure()
	local order, at = {}, nil
	for i, c in ipairs(C.display) do
		order[i] = c.id
		if c.id == id then
			at = i
		end
	end
	if not at then
		return false, "unknown"
	end
	local to = at + step
	if to < 1 or to > #order then
		return false, "edge"
	end
	order[at], order[to] = order[to], order[at]
	SB.Config.db.categoryOrder = order
	C.Load()
	return true
end

-- How many of the bags' items (stacks) a query matches right now, of how many: for the editor's preview. A query
-- with an error, or one that fails while matching, answers nil and why.
function C.Preview(query)
	local compiled = SB.Query.Compile(query or "")
	if not compiled.fn then
		return nil, SB.Query.FormatError(compiled.errors[1])
	end
	local matches, total = 0, 0
	local ok = pcall(function()
		for bag, slot, s in SB.Inventory.Iterate("bags") do
			if s then
				local record = SB.Items.Describe(bag, slot)
				if record then
					total = total + 1
					if SB.Query.Eval(compiled, record) == true then
						matches = matches + 1
					end
				end
			end
		end
	end)
	if not ok then
		return nil, SB.L.SEARCH_EVAL_FAILED
	end
	return matches, total
end

SB.On("SB_LOGIN", function()
```

In `SwagBag/Engine/Focus.lua`, find:

```lua
		names[#names + 1] = SB.Categories and SB.Categories.Name(sid) or sid
```

and replace it with:

```lua
		-- week 11: a deleted category (a stale id in another character's own sections) is left out
		if not SB.Categories or sid == SB.Categories.FREE or SB.Categories.Get(sid) then
			names[#names + 1] = SB.Categories and SB.Categories.Name(sid) or sid
		end
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1561 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (77 files)`, `1561 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Categories.lua \
	SwagBag/Engine/Focus.lua \
	spec/categories_edit_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 11 Task 2: the category writers: create, save (broken rules saved off), delete, move, preview

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 3: Settings > Categories: the list and the rule editor (UI/SettingsCategories.lua)

The page the user sees (`/swagbag settings categories`, or the "Categories" button in the settings window). **The list:** a plain-words intro, "New category", and every category in display order with Edit, Up and Down; a category says `(off)`, `(off: its rule has an error)`, `(yours)` or `(changed)` after its name. **The editor** works on a draft that only Save writes (D7): Save / Cancel / Delete (a user category; asks once more, D11) / Reset to default (a changed built-in, D12); the name (a text box); On/Off; the rules as rows (D1, D4) with "Add a rule", "Change" (both open the keyword lists, D3), the operators of a number row, Not and Remove on each row, All of these / Any of these, Not, Remove group on each group, "Add a group"; "Show the rule as text" (Advanced, D5); "Matches N of the M items in your bags right now." with a "did you mean" hint for a word one letter from a keyword (spec 7.2), "Show matches in the bags" and "Clear the bags' search" (D6); the priority steps (D9). Every click answers once in the status line (P2); nothing in the open bags moves (P5).

The settings window gains a text-box row (`kind = "input"`): an `InputBoxTemplate` EditBox from a pool like its buttons; each keystroke goes to the row's `set` (so a redraw never loses typing), Enter or the Apply button after the box runs `commit`, which answers like any click. Action buttons may now show selected (the current operator, All of these / Any of these, Not). `Rows.Nearest` (a keyword one letter away) joins `Engine/Query/Rows.lua` for the hint.

**Files:**
- Create: `SwagBag/UI/SettingsCategories.lua`, `spec/settings_categories_spec.lua`
- Modify: `SwagBag/UI/SettingsWindow.lua` (the `input` row, selected actions), `SwagBag/Engine/Query/Rows.lua` (`Nearest`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`

**Interfaces:**
- Consumes: Task 1's `SB.QueryRows`; Task 2's `Categories` writers; `SettingsWindow.AddPage/Render/RunCommand`; `/swagbag search`; `SB.Query.Validate/Compile/FormatError/FormatWarning`.
- Produces: `SB.SettingsCategories` with `Edit(id)`, `New()`, `Save()`, `Cancel()` (each returns its answer), `draft`, `picking`, `confirmDelete`; the page id `categories`; the settings row `{ kind = "input", label, get, set, commit, button, maxLetters, boxWidth }`; `action.selected`; `L.SET_APPLY`, `L.SET_PAGE_CATEGORIES`, `L.CAT_*`; `Rows.Nearest(word)`.

- [ ] **Step 1: Write the failing tests**

Create `spec/settings_categories_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 11 (spec F6, AC6.1, AC6.2): Settings > Categories, the visual rule builder. The page is driven the way the
-- user drives it: buttons by their text, text boxes by typing and Enter.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Settings > Categories (week 11)", function()
	local SB, SW, C, L, searched
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		table.insert(files, 12, "SwagBag/Engine/Query/Rows.lua") -- right after Query.lua, as in the TOC
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		Fake.Install()
		searched = {}
		SB.Slash.Register("search", "test", function(arg)
			searched[#searched + 1] = arg
			return "searched " .. arg
		end)
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsCategories.lua")
		SW, C, L = SB.SettingsWindow, SB.Categories, SB.L
		C.Load()
		Fixtures.SmallBags(SB.Adapter)
		SB.Inventory.ScanAll()
		SW.Show("categories")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function texts()
		local out = {}
		for i = 1, SW.used.buttons do
			out[i] = SW.buttons[i].text
		end
		return out
	end

	local function labels()
		local out = {}
		for i = 1, SW.used.labels do
			out[i] = SW.labels[i].text
		end
		return out
	end

	local function has(list, want)
		for _, v in ipairs(list) do
			if v == want then
				return true
			end
		end
		return false
	end

	-- The n-th shown button with this text (default the first).
	local function nth(text, n)
		n = n or 1
		for i = 1, SW.used.buttons do
			local b = SW.buttons[i]
			if b.text == text then
				n = n - 1
				if n == 0 then
					return b
				end
			end
		end
		error("no button " .. text)
	end

	local function click(text, n)
		Fake.Fire(nth(text, n), "OnClick")
		return SW.lastStatus
	end

	-- Type into the n-th text box shown (as the user does: each keystroke, then Enter).
	local function type(n, text)
		local e = SW.inputs[n]
		assert.truthy(e and n <= SW.used.inputs, "no text box " .. n)
		e:SetText(text)
		Fake.Fire(e, "OnTextChanged", true)
		return e
	end

	local function enter(n, text)
		Fake.Fire(type(n, text), "OnEnterPressed")
		return SW.lastStatus
	end

	-- Mutation: in SettingsCategories' state(), `if c.error then` -> `if false then` (a broken one reads "off").
	it("the page lists every category in display order with Edit, Up and Down; each says off, broken, yours or changed", function()
		assert.equal(L.CAT_INTRO, labels()[1])
		assert.same({ L.CAT_NEW_BUTTON, L.CAT_EDIT, L.CAT_UP, L.CAT_DOWN, L.CAT_EDIT }, { unpack(texts(), 1, 5) })
		assert.equal(L.CAT_MAKE, labels()[2])
		assert.same({ "Keystone & Crests", "Consumables", "Gear" }, { unpack(labels(), 3, 5) })
		assert.equal(1 + #C.display * 3, #texts())
		C.Create("Mine", "toy")
		C.Create("Bad", "boe &")
		C.Save("c_gear", { name = "Kit" })
		SW.Render()
		local l = labels()
		assert.equal("Bad (off: its rule has an error)", l[3])
		assert.equal("Mine (yours)", l[4])
		assert.equal("Kit (changed)", l[7])
		assert.truthy(has(l, "Reagents (off)"), "off while the reagent bag shares the bags")
	end)

	-- Mutation: in SettingsCategories' move(), `return (step < 0 and L.CAT_MOVED_UP or L.CAT_MOVED_DOWN):format(name)` ->
	-- `return L.CAT_UNKNOWN`.
	it("Up and Down move a category one place and answer once; the first can't go up", function()
		assert.equal("Keystone & Crests is already first.", click(L.CAT_UP, 1))
		assert.equal("Consumables moved up one place.", click(L.CAT_UP, 2))
		assert.same({ "Consumables", "Keystone & Crests" }, { unpack(labels(), 3, 4) })
		assert.equal("Other is already last.", click(L.CAT_DOWN, #C.display))
		assert.equal("Consumables moved down one place.", click(L.CAT_DOWN, 1))
		assert.equal(0, #SB.Adapter.Lines(), "the status line answers, not chat")
	end)

	-- Mutations: in SettingsCategories' pick(), drop `rulesChanged(d)` (the picked keyword never reaches the text); or in
	-- SettingsWindow's Render, drop `e.onChange = row.set` (typing is lost).
	it("New category: a name, a rule from the lists, a number, Save: it shows first, at priority 88", function()
		assert.equal(L.CAT_NEW_HINT, click(L.CAT_NEW_BUTTON))
		assert.equal(L.CAT_EDITING_NEW, labels()[1])
		type(1, "Big gear")
		assert.equal(L.CAT_PICK_HINT, click(L.CAT_ADD_RULE))
		assert.truthy(has(labels(), L.KW_FAMILY_NUMBER))
		assert.equal(L.CAT_RULE_NOW:format("gear"), click("gear", 1))
		click(L.CAT_ADD_RULE)
		assert.equal(L.CAT_TYPE_VALUE, click("ilvl"))
		assert.truthy(has(labels(), "Rule 2: ilvl >= ?"))
		assert.equal(L.CAT_RULE_NOW:format("gear & ilvl>=280"), enter(2, "280"))
		assert.equal(L.CAT_RULE_NOW:format("gear & ilvl>280"), click(">"))
		assert.equal("Matches 1 of the 6 items in your bags right now.", labels()[#labels() - 2])
		assert.equal(L.CAT_SAVED:format("Big gear"), click(L.CAT_SAVE))
		local c = C.Get("u_big_gear")
		assert.same({ "Big gear", "gear & ilvl>280", 88, true }, { c.name, c.query, c.priority, c.enabled })
		assert.equal("u_big_gear", C.SectionOrder()[2])
		assert.equal("Big gear (yours)", labels()[3], "back at the list")
	end)

	-- Mutation: in SettingsCategories' readText(), `d.rules, d.why, d.err, d.textTyped = rules, why, err, false` ->
	-- `d.why, d.err, d.textTyped = why, err, false` (the text never changes the rows).
	it("rows and text change each other, losslessly; a rule nobody touched keeps its own spelling", function()
		click(L.CAT_EDIT, 5) -- BoE gear: gear & boe
		assert.equal("Editing: BoE gear", labels()[1])
		assert.truthy(has(labels(), "Rule 1: gear"))
		assert.truthy(has(labels(), "Rule 2: boe"))
		assert.equal(L.CAT_RULE_NOW:format("gear & !boe"), click(L.CAT_NOT, 3))
		assert.truthy(has(labels(), "Rule 2: not boe"))
		assert.equal(L.CAT_TEXT_SHOWN, click(L.CAT_SHOW_TEXT))
		assert.equal("gear & !boe", SW.inputs[2]:GetText())
		assert.equal(L.CAT_TEXT_READ:format(L.CAT_RULE_NOW:format("gear & (boe | wue)")), enter(2, "gear & (boe | wue)"))
		assert.truthy(has(labels(), "Group 2"))
		assert.equal(L.CAT_RULE_NOW:format("gear | (boe | wue)"), click(L.CAT_ANY_GROUP))
		click(L.CAT_CANCEL)
		C.Create("Mine", "~boe||bop")
		SW.Render()
		click(L.CAT_EDIT, 1)
		enter(1, "Mine too")
		assert.equal(L.CAT_SAVED:format("Mine too"), click(L.CAT_SAVE))
		assert.equal("~boe||bop", C.Get("u_mine").query, "untouched: saved as typed")
	end)

	-- Mutation: in SettingsCategories' editorRows, `if d.showText or not d.rules then` -> `if d.showText then` (a rule
	-- too nested for rows has no way to be edited).
	it("a rule too nested for rows opens as text only, and is saved as it is", function()
		C.Create("Deep", "gear & (boe | (epic & !bound))")
		SW.Render()
		click(L.CAT_EDIT, 1)
		assert.truthy(has(labels(), L.CAT_TEXT_ONLY:format(L.CAT_WHY_DEEP)))
		assert.equal("gear & (boe | (epic & !bound))", SW.inputs[2]:GetText())
		type(2, "gear & (boe | (rare & !bound))")
		assert.equal(L.CAT_SAVED:format("Deep"), click(L.CAT_SAVE))
		assert.equal("gear & (boe | (rare & !bound))", C.Get("u_deep").query)
	end)

	-- Mutation: in SettingsCategories' SC.Save, `return L.CAT_SAVED_BROKEN:format(name, detail)` ->
	-- `return L.CAT_SAVED:format(name)` (it says "Saved" only).
	it("AC6.2: Save keeps a broken rule, switched off, says why, and the list marks it", function()
		click(L.CAT_EDIT, 2) -- Consumables
		click(L.CAT_SHOW_TEXT)
		local said = enter(2, "consumable &")
		assert.equal(L.CAT_TEXT_ERROR:format("Expected a value after \"&\" at character 13"), said)
		assert.equal(L.CAT_SAVED_BROKEN:format("Consumables", "Expected a value after \"&\" at character 13"),
			click(L.CAT_SAVE))
		assert.same({ query = "consumable &", enabled = false }, SB.Config.db.userEdits.c_consumables)
		assert.equal("Consumables (off: its rule has an error)", labels()[4])
		click(L.CAT_EDIT, 2)
		assert.truthy(has(labels(), L.CAT_TEXT_ONLY:format(L.CAT_WHY_ERROR)), "a broken rule opens as text")
		enter(2, "consumable")
		assert.equal(L.CAT_SAVED:format("Consumables"), click(L.CAT_SAVE))
		assert.is_nil(SB.Config.db.userEdits.c_consumables, "fixed: back to the default, nothing stored")
	end)

	-- Mutation: in SettingsCategories' editorRows, `if d.builtin and edited(d.id) then` -> `if d.builtin then`.
	it("a built-in: Save stores only the difference; Reset to default brings it back; Junk has no priority", function()
		click(L.CAT_EDIT, 3) -- Gear
		assert.falsy(has(texts(), L.SET_RESET_DEFAULT), "nothing to reset")
		assert.equal(L.CAT_PRIORITY_NOW:format(80), click("+10"))
		assert.equal(L.CAT_PRIORITY_NOW:format(89), click("+10"))
		assert.equal(L.CAT_SAVED:format("Gear"), click(L.CAT_SAVE))
		assert.same({ priority = 89 }, SB.Config.db.userEdits.c_gear)
		click(L.CAT_EDIT, 3)
		assert.equal(L.CAT_RESET_DONE:format("Gear"), click(L.SET_RESET_DEFAULT))
		assert.is_nil(SB.Config.db.userEdits.c_gear)
		click(L.CAT_CANCEL)
		click(L.CAT_EDIT, #C.display - 1) -- Junk
		assert.equal("Editing: Junk", labels()[1])
		assert.truthy(has(labels(), L.CAT_PINNED_NOTE))
		assert.falsy(has(texts(), "+10"))
		assert.falsy(has(texts(), L.CAT_DELETE), "a built-in is never deleted")
	end)

	-- Mutation: in SettingsCategories' forget(), drop `SC.confirmDelete = nil` (an old question still deletes).
	it("Delete asks once more; any other click forgets the question", function()
		C.Create("Mine", "toy")
		SW.Render()
		click(L.CAT_EDIT, 1)
		assert.equal(L.CAT_DELETE_ASK:format("Mine"), click(L.CAT_DELETE))
		click(L.CAT_NOT)
		assert.truthy(has(texts(), L.CAT_DELETE), "the question is forgotten")
		click(L.CAT_DELETE)
		assert.equal(L.CAT_DELETED:format("Mine"), click(L.CAT_DELETE_SURE))
		assert.is_nil(C.Get("u_mine"))
		assert.equal("Keystone & Crests", labels()[3])
	end)

	-- Mutation: in SettingsCategories' previewRows, `return run("search " .. d.text)` -> `return run("search")`.
	it("the preview counts the bags' matches, names a word that is no keyword, and Show matches searches the bags", function()
		click(L.CAT_NEW_BUTTON)
		click(L.CAT_ADD_RULE)
		click(L.CAT_PICK_NAME)
		enter(2, "potin")
		assert.truthy(has(labels(), "Matches 0 of the 6 items in your bags right now."))
		assert.falsy(has(labels(), L.CAT_WARN_WORD:format("potin") .. L.CAT_DID_YOU_MEAN:format("potion")),
			"a quoted name is never a keyword: no hint")
		click(L.CAT_SHOW_TEXT)
		enter(3, "potin | flask")
		assert.truthy(has(labels(), "Matches 1 of the 6 items in your bags right now."))
		assert.truthy(has(labels(), L.CAT_WARN_WORD:format("potin") .. L.CAT_DID_YOU_MEAN:format("potion")))
		assert.equal("searched potin | flask", click(L.CAT_SHOW_MATCHES))
		assert.equal("searched ", click(L.CAT_CLEAR_MATCHES))
		assert.same({ "potin | flask", "" }, searched)
		enter(3, "potion |")
		assert.truthy(has(labels(), L.CAT_PREVIEW_ERROR:format("Expected a value after \"|\" at character 9")))
	end)

	-- Mutation: in SettingsCategories' SC.Save, `return refusal(why, d.name)` -> `return L.CAT_SAVED:format(d.name)`.
	it("read-only: Save, Delete and Up refuse with the reason, and nothing changes", function()
		C.Create("Mine", "toy")
		SW.Render()
		SB.Config.readOnly = true
		assert.equal(L.SETTINGS_READONLY, click(L.CAT_UP, 2))
		click(L.CAT_EDIT, 1)
		enter(1, "Ours")
		assert.equal(L.SETTINGS_READONLY, click(L.CAT_SAVE))
		click(L.CAT_DELETE)
		assert.equal(L.SETTINGS_READONLY, click(L.CAT_DELETE_SURE))
		assert.equal("Mine", C.Get("u_mine").name)
		assert.is_nil(SB.Config.db.categoryOrder)
	end)

	-- Mutation: in SettingsWindow's Render, `items = { { text = row.button or L.SET_APPLY, commit = commit } }` ->
	-- `items = {}` (no Apply button: Enter is the only way, which a mouse user doesn't know).
	it("a text box: typing is kept across a redraw; Enter and Apply each answer once", function()
		click(L.CAT_NEW_BUTTON)
		type(1, "Half typed")
		SW.Render() -- a setting changed elsewhere redraws the page
		assert.equal("Half typed", SW.inputs[1]:GetText())
		assert.equal(L.CAT_NAME_OK:format("Half typed"), click(L.SET_APPLY, 1))
		assert.equal(L.CAT_NAME_TAKEN:format("gear"), enter(1, "gear"))
		assert.equal(L.CAT_NAME_LONG:format(C.MAX_NAME), enter(1, string.rep("n", 31)))
		assert.equal(0, #SB.Adapter.Lines())
	end)
end)
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1561 passed, 11 failed`. The failures, exactly:

- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > the page lists every category in display order with Edit, Up and Down; each says off, broken, yours or changed`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > Up and Down move a category one place and answer once; the first can't go up`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > New category: a name, a rule from the lists, a number, Save: it shows first, at priority 88`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > rows and text change each other, losslessly; a rule nobody touched keeps its own spelling`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > a rule too nested for rows opens as text only, and is saved as it is`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > AC6.2: Save keeps a broken rule, switched off, says why, and the list marks it`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > a built-in: Save stores only the difference; Reset to default brings it back; Junk has no priority`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > Delete asks once more; any other click forgets the question`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > the preview counts the bags' matches, names a word that is no keyword, and Show matches searches the bags`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > read-only: Save, Delete and Up refuse with the reason, and nothing changes`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > a text box: typing is kept across a redraw; Enter and Apply each answer once`

All eleven fail in `before_each`, which loads `SwagBag/UI/SettingsCategories.lua`: it does not exist yet.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "the page lists every category in display order with Edit, Up and Down; each says off, broken, yours or changed": in `SwagBag/UI/SettingsCategories.lua`, `if c.error then` → `if false then`.
- "Up and Down move a category one place and answer once; the first can't go up": in `SwagBag/UI/SettingsCategories.lua`, `return (step < 0 and L.CAT_MOVED_UP or L.CAT_MOVED_DOWN):format(name)` → `return L.CAT_UNKNOWN`.
- "New category: a name, a rule from the lists, a number, Save: it shows first, at priority 88": in `SwagBag/UI/SettingsCategories.lua`, `SC.picking = nil ⏎ rulesChanged(d)` → `SC.picking = nil`.
- "New category: a name, a rule from the lists, a number, Save: it shows first, at priority 88": in `SwagBag/UI/SettingsWindow.lua`, `e.onChange = row.set` → ∅.
- "rows and text change each other, losslessly; a rule nobody touched keeps its own spelling": in `SwagBag/UI/SettingsCategories.lua`, `d.rules, d.why, d.err, d.textTyped = rules, why, err, false` → `d.why, d.err, d.textTyped = why, err, false`.
- "a rule too nested for rows opens as text only, and is saved as it is": in `SwagBag/UI/SettingsCategories.lua`, `if d.showText or not d.rules then` → `if d.showText then`.
- "AC6.2: Save keeps a broken rule, switched off, says why, and the list marks it": in `SwagBag/UI/SettingsCategories.lua`, `return L.CAT_SAVED_BROKEN:format(name, detail)` → `return L.CAT_SAVED:format(name)`.
- "a built-in: Save stores only the difference; Reset to default brings it back; Junk has no priority": in `SwagBag/UI/SettingsCategories.lua`, `if d.builtin and edited(d.id) then` → `if d.builtin then`.
- "Delete asks once more; any other click forgets the question": in `SwagBag/UI/SettingsCategories.lua`, `SC.confirmDelete = nil ⏎ return fn(...)` → `return fn(...)`.
- "the preview counts the bags' matches, names a word that is no keyword, and Show matches searches the bags": in `SwagBag/UI/SettingsCategories.lua`, `return run("search " .. d.text)` → `return run("search")`.
- "read-only: Save, Delete and Up refuse with the reason, and nothing changes": in `SwagBag/UI/SettingsCategories.lua`, `return refusal(why, d.name)` → `return L.CAT_SAVED:format(d.name)`.
- "a text box: typing is kept across a redraw; Enter and Apply each answer once": in `SwagBag/UI/SettingsWindow.lua`, `items = { { text = row.button or L.SET_APPLY, commit = commit } }` → `items = {}`.

- [ ] **Step 3: Write the code**

In `SwagBag/Engine/Query/Rows.lua` (edit 1 of 2), find:

```lua
local _, SB = ...
```

and replace it with:

```lua
--   Rows.Nearest(word) -> keyword | nil  a keyword one letter away (spec 7.2's "did you mean"; week 11 Task 3)
local _, SB = ...
```

In `SwagBag/Engine/Query/Rows.lua` (edit 2 of 2), find:

```lua
		return "WORD" -- a bare 536 or 400-450 is an item level, not a word
	end
	return nil
end
```

and replace it with:

```lua
		return "WORD" -- a bare 536 or 400-450 is an item level, not a word
	end
	return nil
end

-- One letter changed, added, dropped, or two neighbours swapped.
local function close(a, b)
	local la, lb = #a, #b
	if la > lb then
		a, b, la, lb = b, a, lb, la
	end
	if lb - la > 1 then
		return false
	end
	local i = 1
	while i <= la and a:sub(i, i) == b:sub(i, i) do
		i = i + 1
	end
	if la == lb then
		return a:sub(i + 1) == b:sub(i + 1)
			or (a:sub(i, i) == b:sub(i + 1, i + 1) and a:sub(i + 1, i + 1) == b:sub(i, i) and a:sub(i + 2) == b:sub(i + 2))
	end
	return a:sub(i) == b:sub(i + 1)
end

function Rows.Nearest(word)
	if type(word) ~= "string" then
		return nil
	end
	word = word:lower()
	local best
	for name, kw in pairs(SB.Query.keywords) do
		if kw.name == name and name ~= word and close(word, name) and (best == nil or name < best) then
			best = name
		end
	end
	return best
end
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.KW_FAMILY_PLACE = "Where it is"
```

and replace it with:

```lua
L.KW_FAMILY_PLACE = "Where it is"
L.SET_APPLY = "Apply"
L.SET_PAGE_CATEGORIES = "Categories"
L.CAT_INTRO = "Categories decide which section of your bags each item goes to. Edit one, make your own, or change"
	.. " their order. A change sorts your items the next time you open your bags (or press Reflow): nothing moves"
	.. " while they are open."
L.CAT_MAKE = "Your own"
L.CAT_NEW_BUTTON = "New category"
L.CAT_EDIT = "Edit"
L.CAT_UP = "Up"
L.CAT_DOWN = "Down"
L.CAT_STATE_BROKEN = "%s (off: its rule has an error)"
L.CAT_STATE_OFF = "%s (off)"
L.CAT_STATE_YOURS = "%s (yours)"
L.CAT_STATE_CHANGED = "%s (changed)"
L.CAT_MOVED_UP = "%s moved up one place."
L.CAT_MOVED_DOWN = "%s moved down one place."
L.CAT_EDGE_FIRST = "%s is already first."
L.CAT_EDGE_LAST = "%s is already last."
L.CAT_UNKNOWN = "That category no longer exists."
L.CAT_EDITING = "Editing: %s"
L.CAT_EDITING_NEW = "A new category"
L.CAT_NEW_HINT = "A new category: type its name, add rules, then click Save."
L.CAT_BUILTIN_NOTE = "A built-in category: SwagBag keeps your changes apart from its own, and Reset to default brings"
	.. " its own back."
L.CAT_ACTIONS = "This category"
L.CAT_SAVE = "Save"
L.CAT_CANCEL = "Cancel"
L.CAT_DELETE = "Delete"
L.CAT_DELETE_SURE = "Delete: sure?"
L.CAT_DELETE_ASK = "Click \"Delete: sure?\" to delete %s. Its items go to the other categories."
L.CAT_DELETED = "Deleted %s. Its items go to the other categories the next time you open your bags."
L.CAT_RESET_DONE = "%s is back to SwagBag's own (items you dragged onto it are forgotten too)."
L.CAT_CANCELLED = "Nothing was changed."
L.CAT_SAVED = "Saved %s. Your bags sort by it the next time you open them (or press Reflow)."
L.CAT_SAVED_BROKEN = "Saved %s, but it stays off until its rule is fixed: %s"
L.CAT_NAME = "Name"
L.CAT_NAME_OK = "Name: %s (click Save to keep it)."
L.CAT_NAME_EMPTY = "A category needs a name."
L.CAT_NAME_LONG = "A name can have at most %d letters."
L.CAT_NAME_CHARS = "A name can't contain | (it starts a chat code)."
L.CAT_NAME_TAKEN = "There is already a category named %s."
L.CAT_TOO_LONG = "A rule can have at most %d characters."
L.CAT_OTHER_NOTE = "Other has no rule: it holds every item no other category takes."
L.CAT_SETTING_NOTE = "Reagents is on only while Settings > Bags > Reagent bag is \"Own section\"."
L.CAT_ON = "Category"
L.CAT_ON_DONE = "On: its section shows in your bags (click Save to keep it)."
L.CAT_OFF_DONE = "Off: its section is hidden and its items go to the other categories (click Save to keep it)."
L.CAT_RULES = "Rules: an item goes here when it matches"
L.CAT_GROUP = "Group %d"
L.CAT_GROUPS_JOIN = "The groups"
L.CAT_ALL_GROUPS = "All groups must match"
L.CAT_ANY_GROUP = "Any group may match"
L.CAT_ALL_OF = "All of these"
L.CAT_ANY_OF = "Any of these"
L.CAT_NOT = "Not"
L.CAT_ADD_RULE = "Add a rule"
L.CAT_REMOVE_GROUP = "Remove group"
L.CAT_MORE = "More"
L.CAT_ADD_GROUP = "Add a group"
L.CAT_RULE = "Rule %d: %s"
L.CAT_CHANGE = "Change"
L.CAT_REMOVE = "Remove"
L.CAT_SUM_NAME = "item name contains \"%s\""
L.CAT_SUM_NOT = "not %s"
L.CAT_RULE_NOW = "Rule now: %s (click Save to keep it)."
L.CAT_RULE_NONE = "Rule now: none, so only items you drag onto its header go here (click Save to keep it)."
L.CAT_TEXT_FIRST = "The text you typed was read first: check the rules below, then click again."
L.CAT_PICK = "Pick what the rule checks"
L.CAT_PICK_HINT = "Pick what the rule checks."
L.CAT_PICK_CANCELLED = "No rule was added."
L.CAT_PICK_NAME_LABEL = "Item name"
L.CAT_PICK_NAME = "Item name contains..."
L.CAT_TYPE_VALUE = "Now type the value below, then press Enter."
L.CAT_VALUE_NUMBER = "Number for %s (gold for value)"
L.CAT_VALUE_NAME = "Item name contains"
L.CAT_PROBLEM_EMPTY = "This rule needs a value."
L.CAT_PROBLEM_QUOTE = "An item name can't hold a double quote (\")."
L.CAT_PROBLEM_NUMBER = "This rule needs a number, like 600 or 2.5."
L.CAT_PROBLEM_WORD = "This word can't be used as it is: pick Item name contains... instead."
L.CAT_ADVANCED = "Advanced"
L.CAT_ADVANCED_TIP = "The same rule as text, in the search box's language (Baganator's, with SwagBag's extras)."
	.. " Changing either one changes the other."
L.CAT_SHOW_TEXT = "Show the rule as text"
L.CAT_HIDE_TEXT = "Hide the text"
L.CAT_TEXT_SHOWN = "The rule as text is shown below the rules."
L.CAT_TEXT_HIDDEN = "The text is hidden; the rule is unchanged."
L.CAT_TEXT = "The rule as text (press Enter or Apply to read it)"
L.CAT_TEXT_READ = "Read. %s"
L.CAT_TEXT_ERROR = "The rule has an error: %s. It can still be saved; it stays off until fixed."
L.CAT_TEXT_ONLY = "This rule can only be edited as text: %s."
L.CAT_WHY_DEEP = "it has groups inside groups"
L.CAT_WHY_LONG = "it has more than 40 rules or 10 groups"
L.CAT_WHY_TOOLONG = "it is longer than 500 characters"
L.CAT_WHY_ERROR = "it has an error"
L.CAT_PREVIEW = "Matches %d of the %d items in your bags right now."
L.CAT_PREVIEW_ERROR = "Matches nothing yet: %s"
L.CAT_WARN_WORD = "\"%s\" is not a keyword, so it matches item names containing it."
L.CAT_DID_YOU_MEAN = " Did you mean %s?"
L.CAT_SEE = "See them"
L.CAT_SEE_TIP = "Show matches puts the rule in your bags' search box: everything else is dimmed, nothing moves."
	.. " Clear the bags' search (or the search box's X) undims them."
L.CAT_SHOW_MATCHES = "Show matches in the bags"
L.CAT_CLEAR_MATCHES = "Clear the bags' search"
L.CAT_PRIORITY = "Priority %d"
L.CAT_PRIORITY_TIP = "When an item fits two categories, the higher number wins. Your categories start at 88: above every"
	.. " built-in except Reagents, Keystone & Crests, Equipment sets and Junk, which nothing outranks (1 to 89)."
L.CAT_PRIORITY_NOW = "Priority %d (click Save to keep it)."
L.CAT_PINNED_NOTE = "Junk, Equipment sets, Keystone & Crests and Reagents keep their priority, so nothing outranks them."
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/SettingsFocus.lua
```

and replace it with:

```text
UI/SettingsCategories.lua
UI/SettingsFocus.lua
```

Create `SwagBag/UI/SettingsCategories.lua`:

```lua
-- SwagBag settings: the Categories page (week 11, spec F6: the visual rule builder, AC6.1, AC6.2). Every category in
-- display order with Edit, Up and Down, and New category. The editor works on a draft that only Save writes:
--   a name; On / Off; the rule as rows of [keyword] [operator] [value] in groups (All of these / Any of these, Not on
--   a row and on a group; Engine/Query/Rows.lua); the rule as text (Advanced: shown on request, always for a rule too
--   nested for rows); a live count of the bags' items it matches, "Show matches" (the bags' own search dimming,
--   which never moves an item: AC5.2); the priority in steps (1 to 89; Junk, Equipment sets, Keystone & Crests and
--   Reagents keep theirs).
-- Save runs Categories.Save / Create: a rule that does not compile is saved switched off with its error said
-- (AC6.2). A rule whose rows were never touched is saved exactly as it was typed (its own spelling); rows that were
-- changed are written in Query.Pretty's spelling (the same rule: Rows' lossless round trip). Nothing in the open bags
-- moves: the new rules sort the items the next time the bags open, or at Reflow (P5). Delete asks once more (the
-- same button again); every other click forgets the question. Every click answers once in the status line (P2).
-- Plain frames only (the settings window's own); no secure frame, no item button.
--   SC.Edit(id) / SC.New() / SC.Save() / SC.Cancel() -> feedback     SC.draft, SC.picking (the keyword lists shown)
local _, SB = ...

local L = SB.L
local C, Rows = SB.Categories, SB.QueryRows
local SC = { draft = nil, picking = nil, confirmDelete = nil, STEPS = { -10, -1, 1, 10 } }
SB.SettingsCategories = SC

local function run(line)
	return SB.SettingsWindow.RunCommand(line)
end

local NAME_WHY = { EMPTY = "CAT_NAME_EMPTY", LONG = "CAT_NAME_LONG", CHARS = "CAT_NAME_CHARS", TAKEN = "CAT_NAME_TAKEN" }

local function refusal(why, name)
	if why == "readonly" then
		return L.SETTINGS_READONLY
	elseif why == "long" then
		return L.CAT_TOO_LONG:format(C.MAX_QUERY)
	elseif why == "LONG" then
		return L.CAT_NAME_LONG:format(C.MAX_NAME)
	elseif NAME_WHY[why] then
		return L[NAME_WHY[why]]:format(tostring(name or ""))
	end
	return L.CAT_UNKNOWN
end

-- Every button but Delete forgets a pending "Delete again?" (the question is about the very next click).
local function forget(fn)
	return function(...)
		SC.confirmDelete = nil
		return fn(...)
	end
end

local function edited(id)
	local edits = SB.Config.db and SB.Config.db.userEdits
	return type(edits) == "table" and edits[id] ~= nil
end

-- The text after a change of the rows: Pretty's spelling. A rule nobody touched keeps the user's own.
local function rulesChanged(d)
	d.text = Rows.ToText(d.rules)
	d.textTyped = false
end

local function readText(d)
	local rules, why, err = Rows.FromText(d.text)
	d.rules, d.why, d.err, d.textTyped = rules, why, err, false
	if rules and #rules.blocks == 0 then
		rules.blocks[1] = { join = "and", negate = false, rows = {} } -- a group to add the first rule to
	end
end

local function ruleNow(d)
	return d.text:find("%S") and L.CAT_RULE_NOW:format(d.text) or L.CAT_RULE_NONE
end

-- A change of the rows: text typed but not read yet is read first instead (the rows on screen are then redrawn
-- from it, so a click never lands on a row that changed under it).
local function change(fn)
	return forget(function()
		local d = SC.draft
		if d.textTyped then
			readText(d)
			return L.CAT_TEXT_FIRST
		end
		fn(d)
		rulesChanged(d)
		return ruleNow(d)
	end)
end

function SC.Edit(id)
	local c = C.Get(id)
	if not c then
		return L.CAT_UNKNOWN
	end
	SC.draft = { id = id, builtin = c.builtin, pinned = C.PINNED[id], fallback = c.fallback, setting = c.setting,
		name = c.name, text = type(c.query) == "string" and c.query or "", enabled = c.enabled or c.error ~= nil,
		priority = c.priority }
	SC.picking, SC.confirmDelete = nil, nil
	readText(SC.draft)
	return L.CAT_EDITING:format(c.name)
end

function SC.New()
	SC.draft = { name = "", text = "", enabled = true, priority = C.USER_PRIORITY }
	SC.picking, SC.confirmDelete = nil, nil
	readText(SC.draft)
	return L.CAT_NEW_HINT
end

function SC.Cancel()
	SC.draft, SC.picking, SC.confirmDelete = nil, nil, nil
	return L.CAT_CANCELLED
end

function SC.Save()
	local d = SC.draft
	if d.textTyped then
		readText(d) -- the text as typed is what is saved
	end
	local fields = { name = d.name, query = d.text }
	if not (d.fallback or d.setting) then
		fields.enabled = d.enabled
	end
	if not (d.pinned or d.fallback) then
		fields.priority = d.priority
	end
	local id, ok, why, detail = d.id
	if id then
		ok, why, detail = C.Save(id, fields)
	else
		id, why, detail = C.Create(d.name, d.text)
		ok = id ~= nil
		if ok then
			local _, why2, detail2 = C.Save(id, { enabled = fields.enabled, priority = fields.priority })
			if why2 then
				why, detail = why2, detail2
			end
		end
	end
	if not ok then
		return refusal(why, d.name)
	end
	local name = C.Get(id).name
	SC.draft, SC.picking, SC.confirmDelete = nil, nil, nil
	if why == "broken" then
		return L.CAT_SAVED_BROKEN:format(name, detail)
	end
	return L.CAT_SAVED:format(name)
end

local function delete()
	local d = SC.draft
	if SC.confirmDelete ~= d.id then
		SC.confirmDelete = d.id
		return L.CAT_DELETE_ASK:format(d.name)
	end
	SC.confirmDelete = nil
	local name = C.Get(d.id) and C.Get(d.id).name or d.name
	local ok, why = C.Delete(d.id)
	if not ok then
		return refusal(why)
	end
	SC.draft, SC.picking = nil, nil
	return L.CAT_DELETED:format(name)
end

local function reset()
	local d = SC.draft
	local ok, why = C.ResetBuiltin(d.id)
	if not ok then
		return refusal(why)
	end
	SC.Edit(d.id)
	return L.CAT_RESET_DONE:format(SC.draft.name)
end

local function move(id, step)
	local ok, why = C.Move(id, step)
	local name = C.Name(id)
	if ok then
		return (step < 0 and L.CAT_MOVED_UP or L.CAT_MOVED_DOWN):format(name)
	elseif why == "edge" then
		return (step < 0 and L.CAT_EDGE_FIRST or L.CAT_EDGE_LAST):format(name)
	end
	return refusal(why)
end

-- A bare word that is a keyword (not one that only takes a number: a bare "ilvl" matches item names).
local function isKeyword(r)
	local kind = r.kind == "word" and Rows.KindOf(r.value)
	return kind == "flag" or kind == "both"
end

-- One row in words, for its label: "ilvl >= 600", "boe", "not epic", "item name contains "fish"".
local function summary(r)
	local s
	if r.kind == "num" then
		s = r.name .. " " .. r.op .. " " .. (r.raw ~= "" and r.raw or "?")
	elseif r.kind == "exact" then
		s = "#" .. r.value
	elseif isKeyword(r) then
		s = r.value
	else
		s = L.CAT_SUM_NAME:format(r.value)
	end
	return r.negate and L.CAT_SUM_NOT:format(s) or s
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
local function state(c)
	if c.error then
		return L.CAT_STATE_BROKEN:format(c.name)
	elseif not c.enabled then
		return L.CAT_STATE_OFF:format(c.name)
	elseif not c.builtin then
		return L.CAT_STATE_YOURS:format(c.name)
	elseif edited(c.id) then
		return L.CAT_STATE_CHANGED:format(c.name)
	end
	return c.name
end

local function listRows()
	C.Ensure()
	local out = {
		{ kind = "note", label = L.CAT_INTRO },
		{ kind = "actions", label = L.CAT_MAKE, actions = { { text = L.CAT_NEW_BUTTON, run = forget(SC.New) } } },
	}
	for _, c in ipairs(C.display) do
		local id = c.id
		out[#out + 1] = { kind = "actions", label = state(c), width = 56, actions = {
			{ text = L.CAT_EDIT, run = forget(function()
				return SC.Edit(id)
			end) },
			{ text = L.CAT_UP, run = forget(function()
				return move(id, -1)
			end) },
			{ text = L.CAT_DOWN, run = forget(function()
				return move(id, 1)
			end) },
		} }
	end
	return out
end

---------------------------------------------------------------------------
-- The editor
---------------------------------------------------------------------------
local function pick(word, asNumber)
	return forget(function()
		local d, p = SC.draft, SC.picking
		local block = d.rules.blocks[p.block]
		local row = Rows.NewRow(word, asNumber)
		if p.row and block.rows[p.row] then
			row.negate = block.rows[p.row].negate
			block.rows[p.row] = row
		else
			block.rows[#block.rows + 1] = row
		end
		SC.picking = nil
		rulesChanged(d)
		if word == nil or asNumber then
			return L.CAT_TYPE_VALUE
		end
		return ruleNow(d)
	end)
end

local function pickerRows(out)
	out[#out + 1] = { kind = "actions", label = L.CAT_PICK, actions = { { text = L.CAT_CANCEL, run = forget(function()
		SC.picking = nil
		return L.CAT_PICK_CANCELLED
	end) } } }
	out[#out + 1] = { kind = "actions", label = L.CAT_PICK_NAME_LABEL, actions = { { text = L.CAT_PICK_NAME,
		run = pick(nil) } } }
	for _, fam in ipairs(Rows.FAMILIES) do
		local actions = {}
		for i, word in ipairs(fam.words) do
			actions[i] = { text = word, run = pick(word, fam.numbers) }
		end
		out[#out + 1] = { kind = "actions", label = L[fam.label], width = 60, actions = actions }
	end
end

local function valueRow(out, r)
	local isNum = r.kind == "num"
	out[#out + 1] = { kind = "input", label = isNum and L.CAT_VALUE_NUMBER:format(r.name) or L.CAT_VALUE_NAME,
		boxWidth = 200, maxLetters = 100,
		get = function()
			return isNum and r.raw or r.value
		end,
		set = function(text)
			if isNum then
				r.raw = text
			else
				r.kind, r.value = "text", text -- a name the user typed is always quoted: no word turns into a keyword
			end
			rulesChanged(SC.draft)
		end,
		commit = forget(function(text)
			if isNum then
				r.raw = text
			else
				r.kind, r.value = "text", text
			end
			rulesChanged(SC.draft)
			local why = Rows.Problem(r)
			return why and L["CAT_PROBLEM_" .. why] or ruleNow(SC.draft)
		end) }
end

local function ruleRows(out, d)
	local rules = d.rules
	if #rules.blocks > 1 then
		out[#out + 1] = { kind = "actions", label = L.CAT_GROUPS_JOIN, actions = {
			{ text = L.CAT_ALL_GROUPS, selected = rules.join == "and", run = change(function()
				rules.join = "and"
			end) },
			{ text = L.CAT_ANY_GROUP, selected = rules.join == "or", run = change(function()
				rules.join = "or"
			end) },
		} }
	end
	local n = 0
	for i, b in ipairs(rules.blocks) do
		local acts = {
			{ text = L.CAT_ALL_OF, selected = b.join == "and", run = change(function()
				b.join = "and"
			end) },
			{ text = L.CAT_ANY_OF, selected = b.join == "or", run = change(function()
				b.join = "or"
			end) },
			{ text = L.CAT_NOT, selected = b.negate, run = change(function()
				b.negate = not b.negate
			end) },
			{ text = L.CAT_ADD_RULE, run = forget(function()
				SC.picking = { block = i }
				return L.CAT_PICK_HINT
			end) },
		}
		if #rules.blocks > 1 then
			acts[#acts + 1] = { text = L.CAT_REMOVE_GROUP, run = change(function()
				table.remove(rules.blocks, i)
			end) }
		end
		out[#out + 1] = { kind = "actions", label = #rules.blocks > 1 and L.CAT_GROUP:format(i) or L.CAT_RULES,
			actions = acts }
		for j, r in ipairs(b.rows) do
			n = n + 1
			local ra = { { text = L.CAT_CHANGE, run = forget(function()
				SC.picking = { block = i, row = j }
				return L.CAT_PICK_HINT
			end) } }
			if r.kind == "num" then
				for _, op in ipairs(Rows.NUMBER_OPS) do
					ra[#ra + 1] = { text = op, selected = r.op == op, run = change(function()
						r.op = op
					end) }
				end
			end
			ra[#ra + 1] = { text = L.CAT_NOT, selected = r.negate, run = change(function()
				r.negate = not r.negate
			end) }
			ra[#ra + 1] = { text = L.CAT_REMOVE, run = change(function()
				table.remove(b.rows, j)
				if #b.rows == 0 and #rules.blocks > 1 then
					table.remove(rules.blocks, i)
				end
			end) }
			out[#out + 1] = { kind = "actions", label = L.CAT_RULE:format(n, summary(r)), width = 44, actions = ra }
			if r.kind ~= "exact" and not isKeyword(r) then
				valueRow(out, r)
			end
			local why = Rows.Problem(r)
			if why then
				out[#out + 1] = { kind = "note", label = L["CAT_PROBLEM_" .. why] }
			end
		end
	end
	out[#out + 1] = { kind = "actions", label = L.CAT_MORE, actions = { { text = L.CAT_ADD_GROUP, run = change(function()
		rules.blocks[#rules.blocks + 1] = { join = "and", negate = false, rows = {} }
	end) } } }
end

local function previewRows(out, d)
	local n, total = C.Preview(d.text)
	out[#out + 1] = { kind = "note", label = n and L.CAT_PREVIEW:format(n, total) or L.CAT_PREVIEW_ERROR:format(total) }
	if n then
		local w = SB.Query.Validate(SB.Query.Compile(d.text)).warnings[1]
		if w and w.kind == "text" then
			local near = Rows.Nearest(w.value)
			out[#out + 1] = { kind = "note", label = L.CAT_WARN_WORD:format(w.value)
				.. (near and L.CAT_DID_YOU_MEAN:format(near) or "") }
		elseif w then
			out[#out + 1] = { kind = "note", label = SB.Query.FormatWarning(w) }
		end
	end
	out[#out + 1] = { kind = "actions", label = L.CAT_SEE, tip = L.CAT_SEE_TIP, actions = {
		{ text = L.CAT_SHOW_MATCHES, run = forget(function()
			return run("search " .. d.text)
		end) },
		{ text = L.CAT_CLEAR_MATCHES, run = forget(function()
			return run("search")
		end) },
	} }
end

local function editorRows()
	local d = SC.draft
	local out = { { kind = "note", label = d.id and L.CAT_EDITING:format(d.name) or L.CAT_EDITING_NEW } }
	if d.builtin then
		out[#out + 1] = { kind = "note", label = L.CAT_BUILTIN_NOTE }
	end
	local acts = { { text = L.CAT_SAVE, run = forget(SC.Save) }, { text = L.CAT_CANCEL, run = forget(SC.Cancel) } }
	if d.id and not d.builtin then
		acts[#acts + 1] = { text = SC.confirmDelete == d.id and L.CAT_DELETE_SURE or L.CAT_DELETE, run = delete }
	end
	if d.builtin and edited(d.id) then
		acts[#acts + 1] = { text = L.SET_RESET_DEFAULT, run = forget(reset) }
	end
	out[#out + 1] = { kind = "actions", label = L.CAT_ACTIONS, actions = acts }
	if SC.picking then
		pickerRows(out)
		return out
	end
	out[#out + 1] = { kind = "input", label = L.CAT_NAME, maxLetters = C.MAX_NAME, boxWidth = 200,
		get = function()
			return d.name
		end,
		set = function(text)
			d.name = text
		end,
		commit = forget(function(text)
			d.name = text
			local clean, why = C.CheckName(text, d.id)
			if not clean then
				return refusal(why, text)
			end
			return L.CAT_NAME_OK:format(clean)
		end) }
	if d.fallback then
		out[#out + 1] = { kind = "note", label = L.CAT_OTHER_NOTE }
		return out
	end
	if d.setting then
		out[#out + 1] = { kind = "note", label = L.CAT_SETTING_NOTE }
	else
		out[#out + 1] = { kind = "choice", label = L.CAT_ON, choices = { { value = true, text = L.SET_ON },
			{ value = false, text = L.SET_OFF } },
			get = function()
				return d.enabled
			end,
			apply = forget(function(v)
				d.enabled = v
				return v and L.CAT_ON_DONE or L.CAT_OFF_DONE
			end) }
	end
	if d.rules then
		ruleRows(out, d)
	else
		out[#out + 1] = { kind = "note", label = L.CAT_TEXT_ONLY:format(L["CAT_WHY_" .. d.why:upper()]) }
	end
	if d.rules then
		out[#out + 1] = { kind = "actions", label = L.CAT_ADVANCED, tip = L.CAT_ADVANCED_TIP, actions = {
			{ text = d.showText and L.CAT_HIDE_TEXT or L.CAT_SHOW_TEXT, run = forget(function()
				d.showText = not d.showText
				return d.showText and L.CAT_TEXT_SHOWN or L.CAT_TEXT_HIDDEN
			end) } } }
	end
	if d.showText or not d.rules then
		out[#out + 1] = { kind = "input", label = L.CAT_TEXT, maxLetters = C.MAX_QUERY,
			get = function()
				return d.text
			end,
			set = function(text)
				d.text, d.textTyped = text, true
			end,
			commit = forget(function(text)
				d.text = text
				readText(d)
				if d.rules then
					return L.CAT_TEXT_READ:format(ruleNow(d))
				elseif d.why == "error" then
					return L.CAT_TEXT_ERROR:format(SB.Query.FormatError(d.err))
				end
				return L.CAT_TEXT_ONLY:format(L["CAT_WHY_" .. d.why:upper()])
			end) }
	end
	previewRows(out, d)
	if d.pinned then
		out[#out + 1] = { kind = "note", label = L.CAT_PINNED_NOTE }
	else
		local steps = {}
		for i, step in ipairs(SC.STEPS) do
			steps[i] = { text = (step > 0 and "+" or "") .. step, run = forget(function()
				d.priority = math.max(C.MIN_PRIORITY, math.min(C.MAX_PRIORITY, d.priority + step))
				return L.CAT_PRIORITY_NOW:format(d.priority)
			end) }
		end
		out[#out + 1] = { kind = "actions", label = L.CAT_PRIORITY:format(d.priority), tip = L.CAT_PRIORITY_TIP,
			width = 44, actions = steps }
	end
	return out
end

SB.SettingsWindow.AddPage({ id = "categories", title = L.SET_PAGE_CATEGORIES, rows = function()
	if SC.draft then
		return editorRows()
	end
	return listRows()
end })
```

In `SwagBag/UI/SettingsWindow.lua` (edit 1 of 9), find:

```lua
-- Any row may carry tip: a plain-words explanation shown when the mouse rests on one of its buttons,
```

and replace it with:

```lua
--   { kind = "input", label, get() -> text, set(text), commit(text) -> feedback, button, maxLetters, boxWidth }
--       a one-line text box (week 11, the category editor): every keystroke goes to set (no answer, no redraw, so
--       nothing typed is lost when another button is clicked); Enter or the button after the box (button, default
--       L.SET_APPLY) runs commit, which answers in the status line like any click
-- An action may carry selected = true: its button is shown selected, as a choice's (week 11).
-- Any row may carry tip: a plain-words explanation shown when the mouse rests on one of its buttons,
```

In `SwagBag/UI/SettingsWindow.lua` (edit 2 of 9), find:

```lua
local SW = { pages = {}, byId = {}, current = nil, labels = {}, buttons = {}, used = { labels = 0, buttons = 0 },
```

and replace it with:

```lua
local SW = { pages = {}, byId = {}, current = nil, labels = {}, buttons = {}, inputs = {},
	used = { labels = 0, buttons = 0, inputs = 0 },
```

In `SwagBag/UI/SettingsWindow.lua` (edit 3 of 9), find:

```lua
-- The full width of a button's text (0 when the client cannot say).
```

and replace it with:

```lua
-- A one-line text box (week 11): InputBoxTemplate is a plain, non-secure template.
local function input()
	SW.used.inputs = SW.used.inputs + 1
	local e = SW.inputs[SW.used.inputs]
	if not e then
		e = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
		e:SetHeight(SW.ROW)
		e:SetAutoFocus(false)
		e:SetScript("OnEnterPressed", Guard("settings.inputEnter", function(self)
			self:ClearFocus()
			if self.onCommit then
				self.onCommit()
			end
		end, "none"))
		e:SetScript("OnEscapePressed", Guard("settings.inputEscape", function(self)
			self:ClearFocus()
		end, "none"))
		e:SetScript("OnTextChanged", Guard("settings.inputText", function(self, userInput)
			if userInput and self.onChange then
				self.onChange(self:GetText() or "")
			end
		end, "none"))
		SW.inputs[SW.used.inputs] = e
	end
	e.onCommit, e.onChange = nil, nil
	e:Show()
	return e
end

-- The full width of a button's text (0 when the client cannot say).
```

In `SwagBag/UI/SettingsWindow.lua` (edit 4 of 9), find:

```lua
	SW.used.labels, SW.used.buttons = 0, 0
```

and replace it with:

```lua
	for i = 1, SW.used.inputs do
		SW.inputs[i]:Hide()
	end
	SW.used.labels, SW.used.buttons, SW.used.inputs = 0, 0, 0
```

In `SwagBag/UI/SettingsWindow.lua` (edit 5 of 9), find:

```lua
	local y = -4
```

and replace it with:

```lua
	local y, x0 = -4, nil
```

In `SwagBag/UI/SettingsWindow.lua` (edit 6 of 9), find:

```lua
			items = { { text = row.text } }
```

and replace it with:

```lua
			items = { { text = row.text } }
		elseif row.kind == "input" then
			local e, width = input(), (child:GetWidth() or SW.WIDTH) - 4 - 12 - SW.BUTTON - 8
			e:SetMaxLetters(row.maxLetters or 255)
			e:SetText(row.get() or "")
			e:SetWidth(row.boxWidth or width)
			place(e, 18, y) -- InputBoxTemplate draws its frame a little left of the box
			e.onChange = row.set
			local function commit()
				act("settings.input", row.commit, e:GetText() or "")
			end
			e.onCommit = commit
			x0 = 18 + (row.boxWidth or width) + 8
			items = { { text = row.button or L.SET_APPLY, commit = commit } }
```

In `SwagBag/UI/SettingsWindow.lua` (edit 7 of 9), find:

```lua
			local x, room = 12, (child:GetWidth() or SW.WIDTH) - 4
```

and replace it with:

```lua
			local x, room = x0 or 12, (child:GetWidth() or SW.WIDTH) - 4
			x0 = nil
```

In `SwagBag/UI/SettingsWindow.lua` (edit 8 of 9), find:

```lua
				elseif row.kind == "actions" then
```

and replace it with:

```lua
				elseif row.kind == "actions" then
					setSelected(b, item.selected)
```

In `SwagBag/UI/SettingsWindow.lua` (edit 9 of 9), find:

```lua
				else
					b.onClick = function()
```

and replace it with:

```lua
				elseif row.kind == "input" then
					b.onClick = item.commit
				else
					b.onClick = function()
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1572 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (78 files)`, `1572 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Query/Rows.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/SettingsCategories.lua \
	SwagBag/UI/SettingsWindow.lua \
	spec/settings_categories_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 11 Task 3: Settings > Categories: the list and the rule editor

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 4: Paste a Baganator search (Engine/Query/Paste.lua, the paste view)

AC6.3, for the user's own Baganator searches and the category strings on Wago. `Paste.Translate` cleans the paste (control characters become spaces; trimmed), refuses what must not come in (empty, over 500 characters, a chat code, a quote), reads it with the query lexer, rewrites Baganator's gold amounts into `value` comparisons (inclusive, as Baganator's), a run of Nots into one, and a `(` left open at the end into a closed one, then compiles the result: an error refuses the whole string with SwagBag's message, positioned in **the pasted text**. A string that compiles comes back with every difference as a note (the mapping table, D13). `Paste.Prefixed` names SwagBag's keywords that start with a word (Baganator matched those too). Nothing is run: only the lexer and Lua patterns read the string.

The Categories page gets "Paste a Baganator search" next to "New category": a box (Enter or Apply reads it), what SwagBag reads it as, up to six notes (then "...and N more differences."), the preview count with Show matches (D6; no "did you mean" here: the notes say it), the name ("From Baganator", the next free one if taken) and "Make category", which makes a new user category (`source = "import"`, D14). A refused string makes nothing and says why; a string changed after it was read must be read again before Make category.

**Files:**
- Create: `SwagBag/Engine/Query/Paste.lua`, `spec/query_paste_spec.lua`
- Modify: `SwagBag/UI/SettingsCategories.lua` (the paste view; `previewRows` takes the text and a no-hint flag), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/settings_categories_spec.lua` (loads `Paste.lua`; the list test gains the paste button; three paste tests)

**Interfaces:**
- Consumes: `SB.QueryLexer.Tokenize`, `SB.Query.Compile/FormatError/Lookup/keywords`; Task 2's `Categories.Create/CheckName/Preview`; Task 3's page.
- Produces: `SB.QueryPaste` with `MAX = 500`, `Translate(text) -> { query, notes = { { kind, value } } } | nil, "EMPTY" | "LONG" | "CODE" | "QUOTE" | "ERROR", detail` (note kinds `NOTS`, `PARENS`, `GOLD`, `ILVL`, `UNKNOWN`, `NAME`, `DIFFERENT`), `Prefixed(word) -> { keyword }`; `SC.Paste()`, `SC.paste`; `L.PASTE_*`.

- [ ] **Step 1: Write the failing tests**

Create `spec/query_paste_spec.lua`:

```lua
-- Week 11 (spec F6, AC6.3): a Baganator (Syndicator) search pasted in, read into SwagBag's query language by
-- Engine/Query/Paste.lua: passed through, translated, noted, or refused whole with the reason. Never run.
local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Query/Paste.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
}

describe("Paste a Baganator search (week 11)", function()
	local SB, P
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		P = SB.QueryPaste
	end)

	-- The notes as "KIND" or "KIND=value", in order.
	local function kinds(result)
		local out = {}
		for i, n in ipairs(result.notes) do
			out[i] = n.kind .. (n.value and ("=" .. n.value) or "")
		end
		return out
	end

	-- Mutation: in Paste.Translate, `addNote(notes, seen, "ILVL")` -> `addNote(notes, seen, "GOLD")`.
	it("what both languages share passes through as it was pasted", function()
		for _, text in ipairs({ "#boe | #bwe", "(potion|flask)&!junk", "herb|cloth", "#tradeable loot | #tradable loot" }) do
			local r = P.Translate(text)
			assert.equal(text, r.query)
			assert.same({}, r.notes, text)
		end
		local r = P.Translate("  #gear & <536\n")
		assert.equal("#gear & <536", r.query)
		assert.same({ "ILVL" }, kinds(r))
		assert.same({ "ILVL" }, kinds(P.Translate("110-140")))
		assert.same({ "DIFFERENT=bop" }, kinds(P.Translate("~boe || bop")))
	end)

	-- Mutation: in Paste.lua, `local INCLUSIVE = { ["<"] = "<=", [">"] = ">=", ...` -> `{ ["<"] = "<", [">"] = ">", ...`.
	it("gold terms become value comparisons, < and > including the amount as in Baganator", function()
		local cases = {
			{ ">100g", "value>=100" }, { "<50s", "value<=0.5" }, { "=5c", "value=0.0005" }, { "25g", "value=25" },
			{ "10g-5g", "(value>=5 & value<=10)" }, { "#tradegoods & >10g", "#tradegoods & value>=10" },
			{ "!>5g", "!value>=5" }, { "(5s-1g | boe)", "((value>=0.05 & value<=1) | boe)" },
		}
		for _, c in ipairs(cases) do
			local r = P.Translate(c[1])
			assert.equal(c[2], r.query, c[1])
			assert.same({ "GOLD" }, kinds(r), c[1])
			assert.truthy(SB.Query.Compile(r.query).fn, c[1])
		end
		assert.same({ "5g potion", { "NAME=5g potion" } }, { P.Translate("5g potion").query, kinds(P.Translate("5g potion")) })
	end)

	-- Mutation: in Paste.Translate, `out = out .. string.rep(")", depth)` -> `out = out` (an open ( is refused).
	it("!! and ~~ are one Not and a ( left open at the end is closed, as Baganator reads them", function()
		assert.same({ "!boe", { "NOTS" } }, { P.Translate("!!boe").query, kinds(P.Translate("!!boe")) })
		assert.equal("!boe", P.Translate("~~~boe").query)
		assert.same({ "(boe | wue)", { "PARENS" } }, { P.Translate("(boe | wue").query, kinds(P.Translate("(boe | wue")) })
		assert.equal("((gear & epic))", P.Translate("((gear & epic").query)
	end)

	-- Mutations: in Paste.Translate, `err.position = math.min(original(edits, err.position), #text + 1)` ->
	-- `err.position = err.position` (the position is in SwagBag's text, not in what was pasted); or drop
	-- `elseif escapeCode(text) then return nil, "CODE"` (a link is let through).
	it("refused whole, with the reason and where: quotes, chat codes, too long, empty, what SwagBag can't read", function()
		assert.same({ nil, "QUOTE", 7 }, { P.Translate("potion\"s") })
		assert.same({ nil, "CODE" }, { P.Translate("|cffff0000red|r") })
		assert.same({ nil, "CODE" }, { P.Translate("|Hitem:1|h") })
		assert.same({ nil, "LONG", 501 }, { P.Translate(string.rep("a", 501)) })
		assert.same({ nil, "EMPTY" }, { P.Translate(" \n\t ") })
		assert.same({ nil, "EMPTY" }, { P.Translate(nil) })
		assert.same({ nil, "ERROR", "Expected & or | but found \")\" at character 4" }, { P.Translate("boe)") })
		assert.same({ nil, "ERROR", "Expected a value but found \"&\" at character 8" }, { P.Translate(">10g & & potion") })
		assert.same({ nil, "ERROR", "Put & between a name and a comparison (at character 1)" }, { P.Translate("a b >5") })
		assert.same({ nil, "ERROR", "Expected a value after \"|\" at character 6" }, { P.Translate("boe |") })
	end)

	-- Mutation: in Paste.Translate's walk, drop the `elseif node.type == "exact" and not (...) then addNote(..."UNKNOWN"...)`
	-- branch (an unknown #keyword is passed on with no word about it).
	it("every difference is named, never hidden: unknown #keywords, name words, other meanings, item levels", function()
		local r = P.Translate("#elemental | pot | upgrade | <600 | #elemental")
		assert.same({ "UNKNOWN=elemental", "NAME=pot", "DIFFERENT=upgrade", "ILVL" }, kinds(r))
		assert.same({ "potion" }, P.Prefixed("pot"))
		assert.same({ "keystone" }, P.Prefixed("key"), "a whole keyword is not its own prefix")
		assert.same({}, P.Prefixed("zzz"))
	end)

	-- Mutation: in Paste.Translate, drop the last `if #out > Paste.MAX then return nil, "LONG", #out end` (gold terms
	-- grow a string past what a category may hold).
	it("nothing pasted is ever run, and whatever is pasted it never errors; a string it reads always compiles", function()
		local hostile = { "os.exit()", "loadstring('x')()", "]]..error()..[[", "%s%d%n", string.rep("(", 300) .. "a",
			"|Kq1|k", "|T123:0|t", "a" .. string.rep(" & a", 120), string.rep("5g|", 99) .. "5g" }
		local pieces = { "!", "~", "&", "|", "||", "(", ")", "<", ">", "=", "#", "5g", "1s-2g", "400-450", "536", "boe",
			"pot", "a b", "-", "g", " " }
		local seed = 99
		local function rnd(n)
			seed = seed * 16807 % 2147483647
			return seed % n + 1
		end
		for _ = 1, 1500 do
			local parts = {}
			for i = 1, rnd(7) do
				parts[i] = pieces[rnd(#pieces)]
			end
			hostile[#hostile + 1] = table.concat(parts, rnd(2) == 1 and " " or "")
		end
		local read = 0
		for _, text in ipairs(hostile) do
			local ok, r, why = pcall(P.Translate, text)
			assert.truthy(ok, text)
			if r then
				read = read + 1
				assert.truthy(SB.Query.Compile(r.query).fn, text)
				assert.truthy(#r.query <= P.MAX, text)
			else
				assert.truthy(why == "ERROR" or why == "LONG" or why == "CODE" or why == "EMPTY", text)
			end
		end
		assert.truthy(read > 150, "too few readable strings: " .. read)
		assert.same({ nil, "LONG", 799 }, { P.Translate(string.rep("5g|", 99) .. "5g") }, "299 pasted, 799 read")
	end)

	-- Mutation: in Paste.lua's amount(), `if digits and #digits <= 9 then` -> `if digits then` (a huge amount prints as
	-- 1e+12, which is no number SwagBag reads back).
	it("the published Baganator strings of the grammar research read as expected", function()
		local cases = {
			{ "#key", {} }, { "#tradeable loot | #tradable loot", {} }, { "#toy", {} }, { "#gear & <536", { "ILVL" } },
			{ "#gear&<80", { "ILVL" } }, { "#armor", {} }, { "#profession", {} }, { "#elemental", { "UNKNOWN=elemental" } },
			{ "#finishing reagents | #optional reagents | #crafting reagent | #reagent", { "UNKNOWN=finishing reagents",
				"UNKNOWN=optional reagents", "UNKNOWN=crafting reagent" } },
			{ "#food", {} }, { "!gear & (#leather | #leatherworking)", { "UNKNOWN=leatherworking" } },
			{ "#battle pet | #battle pets", {} }, { "#open", { "UNKNOWN=open" } }, { "#cooking | #fish ", { "UNKNOWN=fish" } },
			{ "#boe | #bwe", {} }, { "#consumable | #recipe | #gem | #weapon", {} },
			{ "#herb | #alchemy | #inscription", { "UNKNOWN=alchemy", "UNKNOWN=inscription" } },
			{ "soulbound", {} }, { "boa", {} }, { "boe", {} }, { "open", { "NAME=open" } }, { "#tradeskill | #reagent", {} },
			{ "#weapon | #off-hand", {} }, { "#tabard | #shirt", {} }, { "#quest | #junk | #trinket | #wue | #housing", {} },
			{ "hearthstone", { "NAME=hearthstone" } },
		}
		for _, c in ipairs(cases) do
			local r, why, detail = P.Translate(c[1])
			assert.truthy(r, c[1] .. " " .. tostring(why) .. " " .. tostring(detail))
			assert.same(c[2], kinds(r), c[1])
		end
		assert.same({ nil, "ERROR", "Expected a number but found \"1000000000000g\" at character 2" },
			{ P.Translate(">1000000000000g") })
	end)
end)
```

In `spec/settings_categories_spec.lua` (edit 1 of 4), find:

```lua
		SB = Loader.New(files)
```

and replace it with:

```lua
		table.insert(files, 13, "SwagBag/Engine/Query/Paste.lua")
		SB = Loader.New(files)
```

In `spec/settings_categories_spec.lua` (edit 2 of 4), find:

```lua
		assert.same({ L.CAT_NEW_BUTTON, L.CAT_EDIT, L.CAT_UP, L.CAT_DOWN, L.CAT_EDIT }, { unpack(texts(), 1, 5) })
		assert.equal(L.CAT_MAKE, labels()[2])
		assert.same({ "Keystone & Crests", "Consumables", "Gear" }, { unpack(labels(), 3, 5) })
		assert.equal(1 + #C.display * 3, #texts())
```

and replace it with:

```lua
		assert.same({ L.CAT_NEW_BUTTON, L.PASTE_BUTTON, L.CAT_EDIT, L.CAT_UP, L.CAT_DOWN }, { unpack(texts(), 1, 5) })
		assert.equal(L.CAT_MAKE, labels()[2])
		assert.same({ "Keystone & Crests", "Consumables", "Gear" }, { unpack(labels(), 3, 5) })
		assert.equal(2 + #C.display * 3, #texts())
```

In `spec/settings_categories_spec.lua` (edit 3 of 4), find:

```lua
	-- Mutation: in SettingsCategories' previewRows, `return run("search " .. d.text)` -> `return run("search")`.
```

and replace it with:

```lua
	-- Mutation: in SettingsCategories' previewRows, `return run("search " .. text)` -> `return run("search")`.
```

In `spec/settings_categories_spec.lua` (edit 4 of 4), find:

```lua
		assert.equal(0, #SB.Adapter.Lines())
	end)
```

and replace it with:

```lua
		assert.equal(0, #SB.Adapter.Lines())
	end)

	-- Mutations: in SettingsCategories' make(), `local id, why = C.Create(p.name, p.result.query, "import")` ->
	-- `local id, why = C.Create(p.name, p.text, "import")` (the pasted text, not what SwagBag read it as); or in
	-- pasteRows, drop `previewRows(out, p.result.query, true)` (no count before saving: AC6.3).
	it("Paste: the search is read, its differences named, its matches counted; Make category saves it as yours", function()
		assert.equal(L.PASTE_HINT, click(L.PASTE_BUTTON))
		assert.equal(L.PASTE_INTRO, labels()[1])
		assert.falsy(has(texts(), L.PASTE_MAKE), "nothing read yet")
		assert.equal(L.PASTE_READ:format("#gear & value>=1000 | pot"), enter(1, "#gear & >1000g | pot"))
		local l = labels()
		assert.truthy(has(l, L.PASTE_READS_AS:format("#gear & value>=1000 | pot")))
		assert.truthy(has(l, L.PASTE_NOTE_GOLD))
		assert.truthy(has(l, L.PASTE_NOTE_NAME:format("pot") .. L.PASTE_NOTE_PREFIX:format("potion")))
		assert.truthy(has(l, "Matches 1 of the 6 items in your bags right now."), "the potion's name holds pot")
		assert.falsy(has(l, L.CAT_WARN_WORD:format("pot") .. L.CAT_DID_YOU_MEAN:format("pet")), "Paste's own note says it")
		assert.equal("From Baganator", SW.inputs[2]:GetText())
		assert.equal("searched #gear & value>=1000 | pot", click(L.CAT_SHOW_MATCHES))
		assert.equal(L.PASTE_MADE:format("From Baganator"), click(L.PASTE_MAKE))
		local c = C.Get("u_from_baganator")
		assert.same({ "#gear & value>=1000 | pot", "import", 88, true }, { c.query, c.source, c.priority, c.enabled })
		assert.equal("From Baganator (yours)", labels()[3], "back at the list, first")
		click(L.PASTE_BUTTON)
		enter(1, "#toy")
		assert.equal("From Baganator 2", SW.inputs[2]:GetText(), "a free name")
	end)

	-- Mutation: in SettingsCategories' readPaste(), `if not result then` -> `if false then` (a refused string offers
	-- Make category).
	it("Paste: a string SwagBag can't read is refused whole, with the reason; nothing is made", function()
		click(L.PASTE_BUTTON)
		local said = enter(1, "boe | (epic")
		assert.equal(L.PASTE_READ:format("boe | (epic)"), said, "an open ( is closed, as in Baganator")
		said = enter(1, "boe)")
		assert.equal(L.PASTE_ERR_ERROR:format("Expected & or | but found \")\" at character 4"), said)
		assert.truthy(has(labels(), said))
		assert.falsy(has(texts(), L.PASTE_MAKE))
		assert.equal(L.PASTE_ERR_QUOTE:format(4), enter(1, "pot\"s"))
		assert.equal(L.PASTE_ERR_CODE, enter(1, "|cffff0000x"))
		assert.equal(L.PASTE_ERR_LONG:format(600), enter(1, string.rep("b", 600)))
		assert.equal(L.PASTE_CANCELLED, click(L.CAT_CANCEL))
		local n = 0
		for _ in pairs(SB.Config.db.categories) do
			n = n + 1
		end
		assert.equal(0, n)
	end)

	-- Mutation: in SettingsCategories' pasteRows, the box's set: `p.text, p.result, p.why = text, nil, nil` ->
	-- `p.text = text` (a string changed after it was read is made without being read again).
	it("Paste: a string changed after it was read must be read again; a taken name is refused", function()
		click(L.PASTE_BUTTON)
		enter(1, "#toy")
		type(1, "#toy | #pet")
		assert.equal(L.PASTE_READ_FIRST, click(L.PASTE_MAKE), "changed: read it again first")
		assert.falsy(has(texts(), L.PASTE_MAKE))
		enter(1, "#toy | #pet")
		type(2, "Gear")
		assert.equal(L.CAT_NAME_TAKEN:format("Gear"), click(L.PASTE_MAKE))
		type(2, "Fun")
		assert.equal(L.PASTE_MADE:format("Fun"), click(L.PASTE_MAKE))
		assert.equal("#toy | #pet", C.Get("u_fun").query)
	end)
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1561 passed, 21 failed`. The failures, exactly:

- `spec/query_paste_spec.lua :: Paste a Baganator search (week 11) > what both languages share passes through as it was pasted`
- `spec/query_paste_spec.lua :: Paste a Baganator search (week 11) > gold terms become value comparisons, < and > including the amount as in Baganator`
- `spec/query_paste_spec.lua :: Paste a Baganator search (week 11) > !! and ~~ are one Not and a ( left open at the end is closed, as Baganator reads them`
- `spec/query_paste_spec.lua :: Paste a Baganator search (week 11) > refused whole, with the reason and where: quotes, chat codes, too long, empty, what SwagBag can't read`
- `spec/query_paste_spec.lua :: Paste a Baganator search (week 11) > every difference is named, never hidden: unknown #keywords, name words, other meanings, item levels`
- `spec/query_paste_spec.lua :: Paste a Baganator search (week 11) > nothing pasted is ever run, and whatever is pasted it never errors; a string it reads always compiles`
- `spec/query_paste_spec.lua :: Paste a Baganator search (week 11) > the published Baganator strings of the grammar research read as expected`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > the page lists every category in display order with Edit, Up and Down; each says off, broken, yours or changed`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > Up and Down move a category one place and answer once; the first can't go up`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > New category: a name, a rule from the lists, a number, Save: it shows first, at priority 88`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > rows and text change each other, losslessly; a rule nobody touched keeps its own spelling`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > a rule too nested for rows opens as text only, and is saved as it is`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > AC6.2: Save keeps a broken rule, switched off, says why, and the list marks it`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > a built-in: Save stores only the difference; Reset to default brings it back; Junk has no priority`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > Delete asks once more; any other click forgets the question`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > the preview counts the bags' matches, names a word that is no keyword, and Show matches searches the bags`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > read-only: Save, Delete and Up refuse with the reason, and nothing changes`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > a text box: typing is kept across a redraw; Enter and Apply each answer once`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > Paste: the search is read, its differences named, its matches counted; Make category saves it as yours`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > Paste: a string SwagBag can't read is refused whole, with the reason; nothing is made`
- `spec/settings_categories_spec.lua :: Settings > Categories (week 11) > Paste: a string changed after it was read must be read again; a taken name is refused`

The seven paste tests fail because `SwagBag/Engine/Query/Paste.lua` does not exist yet; every test of `spec/settings_categories_spec.lua` (eleven of Task 3's and the three new ones) fails in its `before_each`, which now loads that file too.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "what both languages share passes through as it was pasted": in `SwagBag/Engine/Query/Paste.lua`, `addNote(notes, seen, "ILVL")` → `addNote(notes, seen, "GOLD")`.
- "gold terms become value comparisons, < and > including the amount as in Baganator": in `SwagBag/Engine/Query/Paste.lua`, `local INCLUSIVE = { ["<"] = "<=", [">"] = ">=",` → `local INCLUSIVE = { ["<"] = "<", [">"] = ">",`.
- "!! and ~~ are one Not and a ( left open at the end is closed, as Baganator reads them": in `SwagBag/Engine/Query/Paste.lua`, `out = out .. string.rep(")", depth)` → `out = out`.
- "refused whole, with the reason and where: quotes, chat codes, too long, empty, what SwagBag can't read": in `SwagBag/Engine/Query/Paste.lua`, `err.position = math.min(original(edits, err.position), #text + 1)` → `err.position = err.position`.
- "refused whole, with the reason and where: quotes, chat codes, too long, empty, what SwagBag can't read": in `SwagBag/Engine/Query/Paste.lua`, `elseif escapeCode(text) then ⏎ return nil, "CODE"` → ∅.
- "every difference is named, never hidden: unknown #keywords, name words, other meanings, item levels": in `SwagBag/Engine/Query/Paste.lua`, `elseif node.type == "exact" and not (SB.Query.Lookup(value) and SB.Query.Lookup(value).eval) then ⏎ addNote(notes, seen, "UNKNOWN", node.value)` → ∅.
- "nothing pasted is ever run, and whatever is pasted it never errors; a string it reads always compiles": in `SwagBag/Engine/Query/Paste.lua`, `if #out > Paste.MAX then ⏎ return nil, "LONG", #out ⏎ end` → ∅.
- "the published Baganator strings of the grammar research read as expected": in `SwagBag/Engine/Query/Paste.lua`, `if digits and #digits <= 9 then` → `if digits then`.
- "Paste: the search is read, its differences named, its matches counted; Make category saves it as yours": in `SwagBag/UI/SettingsCategories.lua`, `local id, why = C.Create(p.name, p.result.query, "import")` → `local id, why = C.Create(p.name, p.text, "import")`.
- "Paste: the search is read, its differences named, its matches counted; Make category saves it as yours": in `SwagBag/UI/SettingsCategories.lua`, `previewRows(out, p.result.query, true)` → ∅.
- "Paste: the search is read, its differences named, its matches counted; Make category saves it as yours": in `SwagBag/UI/SettingsCategories.lua`, `if n and not noHint then` → `if n then`.
- "Paste: a string SwagBag can't read is refused whole, with the reason; nothing is made": in `SwagBag/UI/SettingsCategories.lua`, `if not result then` → `if false then`.
- "Paste: a string changed after it was read must be read again; a taken name is refused": in `SwagBag/UI/SettingsCategories.lua`, `p.text, p.result, p.why = text, nil, nil` → `p.text = text`.

- [ ] **Step 3: Write the code**

Create `SwagBag/Engine/Query/Paste.lua`:

```lua
-- SwagBag paste import (week 11, spec F6 AC6.3): a search or category string copied from Baganator (its search
-- language, spec 7.1) read into SwagBag's query language. Pure Lua: reads SB.QueryLexer and SB.Query only. The
-- pasted text is only read with the lexer and patterns: nothing in it is ever run, and nothing is stored here.
-- The languages are nearly the same (spec 7.1, 7.5); what Paste changes, adds a note for, or refuses:
--   the same in both            & | ! ~ || ( ) #word  N =N <N >N N-M  bare words  (passed through as they are)
--   !! and ~~ (and longer runs)  one ! (Baganator reads one NOT; SwagBag would read NOT NOT)       note "NOTS"
--   ( left open at the end      closed with ) at the end (Baganator closes them)                 note "PARENS"
--   >Ng <Ns =Nc Ng Ng-Mg        value>=N  value<=N/100  value=N/10000  value=N  (value>=N & value<=M)
--                               (gold per item; Baganator's < and > include the amount)            note "GOLD"
--   N, <N, >N, N-M              the same item-level tests; SwagBag counts gear only               note "ILVL"
--   #word SwagBag doesn't know  kept: it matches nothing, as in Baganator                         note "UNKNOWN"
--   a bare word that is not one of SwagBag's keywords: kept, it matches item names only (Baganator also tried
--                               keywords starting with it and some tooltip lines)                  note "NAME"
--   upgrade, bop                kept: the same word means something else in SwagBag (spec 7.5 #10) note "DIFFERENT"
-- Refused whole, with the reason (never half a string: dropping one term of an AND or an OR changes which items
-- match, silently): empty, longer than MAX characters, a chat code (|c........ |T |H |A |K |cnNAME:), a double
-- quote (a letter for Baganator, the start of a quoted name for SwagBag), or anything SwagBag can't read (a stray ),
-- an operator with nothing after it, a name before a comparison...: the error and where, in the pasted text).
--   Paste.Translate(text) -> { query, notes = { { kind, value } } } | nil, why, detail
--     why: "EMPTY" | "LONG" (detail: its length) | "CODE" | "QUOTE" (detail: its character) | "ERROR" (detail: the
--     error in words, positioned in the pasted text)
local _, SB = ...

local Paste = { MAX = 500 }
SB.QueryPaste = Paste

local MONEY = { g = 1, s = 0.01, c = 0.0001 }
local INCLUSIVE = { ["<"] = "<=", [">"] = ">=", ["="] = "=", ["<="] = "<=", [">="] = ">=" }
local DIFFERENT = { upgrade = true, bop = true }
local TERM_START = { AND = true, OR = true, NOT = true, LPAREN = true }

-- Gold as SwagBag's value keyword reads it: a plain number, never an exponent ("1e+06").
local function gold(digits, unit)
	local n = tonumber(digits) * MONEY[unit:lower()]
	if n == math.floor(n) then
		return string.format("%d", n)
	end
	return (string.format("%.4f", n):gsub("0+$", ""))
end

local function amount(word)
	local digits, unit = word:match("^(%d+)([gGsScC])$")
	if digits and #digits <= 9 then
		return gold(digits, unit)
	end
end

-- A chat escape opener (the share-string rule, Engine/Profiles.lua): |T |H |A |K, |c and eight hex digits, |cn
-- and an upper-case name and ":". Every other "|" is OR ("herb|cloth").
local function escapeCode(text)
	return text:find("|[THAK]") ~= nil or text:find("|c%x%x%x%x%x%x%x%x") ~= nil
		or text:find("|c[nN][%u_][%u%d_]*:") ~= nil
end

local function addNote(notes, seen, kind, value)
	local key = kind .. ":" .. (value or "")
	if not seen[key] then
		seen[key] = true
		notes[#notes + 1] = { kind = kind, value = value }
	end
end

-- Where a character of the translated text came from in the pasted one.
local function original(edits, position)
	local shift = 0
	for _, e in ipairs(edits) do
		if position < e.s + shift then
			break
		elseif position <= e.s + shift + #e.new - 1 then
			return e.s
		end
		shift = shift + #e.new - (e.e - e.s + 1)
	end
	return position - shift
end

local function walk(node, fn)
	fn(node)
	for _, child in ipairs(node.items or {}) do
		walk(child, fn)
	end
	if node.item then
		walk(node.item, fn)
	end
end

function Paste.Translate(text)
	if type(text) ~= "string" then
		return nil, "EMPTY"
	end
	text = text:gsub("%c", " "):match("^%s*(.-)%s*$")
	if text == "" then
		return nil, "EMPTY"
	elseif #text > Paste.MAX then
		return nil, "LONG", #text
	elseif escapeCode(text) then
		return nil, "CODE"
	end
	local quote = text:find("\"", 1, true)
	if quote then
		return nil, "QUOTE", quote
	end
	local tokens = SB.QueryLexer.Tokenize(text)
	local notes, seen, edits = {}, {}, {}
	local depth, i = 0, 1
	while tokens[i].type ~= "EOF" do
		local t, prev, nxt = tokens[i], tokens[i - 1], tokens[i + 1]
		local starts = prev == nil or TERM_START[prev.type]
		if t.type == "NOT" and nxt.type == "NOT" then
			local j = i
			while tokens[j + 1].type == "NOT" do
				j = j + 1
			end
			edits[#edits + 1] = { s = t.s, e = tokens[j].e, new = "!" }
			addNote(notes, seen, "NOTS")
			i = j
		elseif t.type == "OP" and starts and nxt.type == "WORD" and tokens[i + 2].type ~= "WORD" and amount(nxt.value) then
			edits[#edits + 1] = { s = t.s, e = nxt.e, new = "value" .. INCLUSIVE[t.value] .. amount(nxt.value) }
			addNote(notes, seen, "GOLD")
			i = i + 1
		elseif t.type == "WORD" and starts and nxt.type ~= "WORD" and nxt.type ~= "OP" then
			local lo, hi = t.value:match("^(%d+[gGsScC])%-(%d+[gGsScC])$")
			if amount(t.value) then
				edits[#edits + 1] = { s = t.s, e = t.e, new = "value=" .. amount(t.value) }
				addNote(notes, seen, "GOLD")
			elseif lo and amount(lo) and amount(hi) then
				local a, b = tonumber(amount(lo)), tonumber(amount(hi))
				if a > b then
					lo, hi = hi, lo
				end
				edits[#edits + 1] = { s = t.s, e = t.e, new = "(value>=" .. amount(lo) .. " & value<=" .. amount(hi) .. ")" }
				addNote(notes, seen, "GOLD")
			end
		elseif t.type == "LPAREN" then
			depth = depth + 1
		elseif t.type == "RPAREN" then
			depth = depth - 1
		end
		i = i + 1
	end
	local out = text
	for k = #edits, 1, -1 do
		local e = edits[k]
		out = out:sub(1, e.s - 1) .. e.new .. out:sub(e.e + 1)
	end
	if depth > 0 then
		out = out .. string.rep(")", depth)
		addNote(notes, seen, "PARENS")
	end
	local compiled = SB.Query.Compile(out)
	if not compiled.fn then
		local err = compiled.errors[1]
		err.position = math.min(original(edits, err.position), #text + 1) -- where it is in what was pasted
		return nil, "ERROR", SB.Query.FormatError(err)
	end
	walk(compiled.ast, function(node)
		local value = type(node.value) == "string" and node.value:lower() or nil
		if node.type == "num" and node.name == "ilvl" then
			addNote(notes, seen, "ILVL")
		elseif (node.type == "word" or node.type == "exact") and DIFFERENT[value] then
			addNote(notes, seen, "DIFFERENT", node.value)
		elseif node.type == "exact" and not (SB.Query.Lookup(value) and SB.Query.Lookup(value).eval) then
			addNote(notes, seen, "UNKNOWN", node.value)
		elseif node.type == "word" and not (SB.Query.Lookup(value) and SB.Query.Lookup(value).eval) then
			addNote(notes, seen, "NAME", node.value)
		end
	end)
	if #out > Paste.MAX then
		return nil, "LONG", #out
	end
	return { query = out, notes = notes }
end

-- SwagBag keywords starting with a word, for a NAME note ("pot" -> potion): Baganator matched those too.
function Paste.Prefixed(word)
	word = word:lower()
	local out = {}
	for name, kw in pairs(SB.Query.keywords) do
		if kw.name == name and kw.eval and name ~= word and name:sub(1, #word) == word then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.CAT_PINNED_NOTE = "Junk, Equipment sets, Keystone & Crests and Reagents keep their priority, so nothing outranks them."
```

and replace it with:

```lua
L.CAT_PINNED_NOTE = "Junk, Equipment sets, Keystone & Crests and Reagents keep their priority, so nothing outranks them."

-- Paste a Baganator search (week 11): Engine/Query/Paste.lua, UI/SettingsCategories.lua
L.PASTE_BUTTON = "Paste a Baganator search"
L.PASTE_TIP = "Copy a search or a category's search from Baganator (or from Wago), paste it here, and SwagBag makes a"
	.. " category of it: you see what it matches first."
L.PASTE_HINT = "Paste the search into the box (Ctrl+V), then press Enter."
L.PASTE_INTRO = "Paste a search from Baganator. SwagBag reads it (nothing in it ever runs), says what it reads it as and"
	.. " what is different, and shows what it matches in your bags. Nothing is made until you click Make category."
L.PASTE_TITLE = "Paste a Baganator search"
L.PASTE_BOX = "Baganator search (press Enter or Apply to read it)"
L.PASTE_CANCELLED = "Nothing was made."
L.PASTE_READ = "Read as: %s. Check what it matches, name it, then click Make category."
L.PASTE_READS_AS = "SwagBag reads it as: %s"
L.PASTE_READ_FIRST = "Press Enter in the box first, so SwagBag reads the search."
L.PASTE_NAME = "From Baganator"
L.PASTE_NAME_OK = "Name: %s."
L.PASTE_SAVE_LABEL = "Make it a category"
L.PASTE_MAKE = "Make category"
L.PASTE_MADE = "Made the category %s. Your bags sort by it the next time you open them (or press Reflow)."
L.PASTE_MORE = "...and %d more differences."
L.PASTE_ERR_EMPTY = "Paste a Baganator search first."
L.PASTE_ERR_LONG = "That is %s characters long; a category's rule can have at most 500. Nothing was made."
L.PASTE_ERR_CODE = "That holds a chat code (|c, |T, |H...), so SwagBag refuses it whole. Nothing was made."
L.PASTE_ERR_QUOTE = "Character %s is a double quote (\"): Baganator reads it as a letter, SwagBag as the start of a"
	.. " quoted name. Remove it and read again. Nothing was made."
L.PASTE_ERR_ERROR = "SwagBag can't read it: %s. Nothing was made."
L.PASTE_NOTE_NOTS = "!! (or ~~) is read as one Not, as Baganator does."
L.PASTE_NOTE_PARENS = "A ( left open at the end is closed, as Baganator does."
L.PASTE_NOTE_GOLD = "Gold amounts compare SwagBag's price for one item (auction, else vendor); < and > include the"
	.. " amount, as in Baganator."
L.PASTE_NOTE_ILVL = "Item levels count gear only in SwagBag (Baganator also reads other items' item level)."
L.PASTE_NOTE_UNKNOWN = "#%s is a keyword SwagBag doesn't have: it matches nothing, as in Baganator."
L.PASTE_NOTE_NAME = "\"%s\" matches item names only (Baganator also tried keywords starting with it, and some tooltip"
	.. " lines)."
L.PASTE_NOTE_PREFIX = " SwagBag keywords starting with it: %s."
L.PASTE_NOTE_DIFFERENT = "\"%s\" means something else in SwagBag (upgrade: has an upgrade track; bop: binds when"
	.. " picked up). Baganator: an upgrade for you; currently bound."
```

In `SwagBag/SwagBag.toc`, find:

```text
Engine/Crests.lua
```

and replace it with:

```text
Engine/Query/Paste.lua
Engine/Crests.lua
```

In `SwagBag/UI/SettingsCategories.lua` (edit 1 of 7), find:

```lua
local _, SB = ...
```

and replace it with:

```lua
-- Paste a Baganator search (week 11 Task 4, AC6.3): a box for the string, read by Engine/Query/Paste.lua (nothing in
-- it ever runs); what SwagBag reads it as, every difference in words, what it matches in the bags now (and Show
-- matches); Make category saves it as a new category of the user's (source "import") under a name they may change.
-- A string Paste refuses makes nothing, and says why and where.
--   SC.Paste() -> feedback       SC.paste = { text, result, why, detail, name } while the paste view is open
local _, SB = ...
```

In `SwagBag/UI/SettingsCategories.lua` (edit 2 of 7), find:

```lua
local C, Rows = SB.Categories, SB.QueryRows
local SC = { draft = nil, picking = nil, confirmDelete = nil, STEPS = { -10, -1, 1, 10 } }
```

and replace it with:

```lua
local C, Rows, Paste = SB.Categories, SB.QueryRows, SB.QueryPaste
local SC = { draft = nil, picking = nil, confirmDelete = nil, paste = nil, STEPS = { -10, -1, 1, 10 }, MAX_NOTES = 6 }
```

In `SwagBag/UI/SettingsCategories.lua` (edit 3 of 7), find:

```lua
		{ kind = "actions", label = L.CAT_MAKE, actions = { { text = L.CAT_NEW_BUTTON, run = forget(SC.New) } } },
```

and replace it with:

```lua
		{ kind = "actions", label = L.CAT_MAKE, actions = { { text = L.CAT_NEW_BUTTON, run = forget(SC.New) },
			{ text = L.PASTE_BUTTON, tip = L.PASTE_TIP, run = forget(function()
				return SC.Paste()
			end) } } },
```

In `SwagBag/UI/SettingsCategories.lua` (edit 4 of 7), find:

```lua
local function previewRows(out, d)
	local n, total = C.Preview(d.text)
	out[#out + 1] = { kind = "note", label = n and L.CAT_PREVIEW:format(n, total) or L.CAT_PREVIEW_ERROR:format(total) }
	if n then
		local w = SB.Query.Validate(SB.Query.Compile(d.text)).warnings[1]
```

and replace it with:

```lua
-- noHint: the paste view names its differences itself (Paste's notes), so no "did you mean" there.
local function previewRows(out, text, noHint)
	local n, total = C.Preview(text)
	out[#out + 1] = { kind = "note", label = n and L.CAT_PREVIEW:format(n, total) or L.CAT_PREVIEW_ERROR:format(total) }
	if n and not noHint then
		local w = SB.Query.Validate(SB.Query.Compile(text)).warnings[1]
```

In `SwagBag/UI/SettingsCategories.lua` (edit 5 of 7), find:

```lua
			return run("search " .. d.text)
```

and replace it with:

```lua
			return run("search " .. text)
```

In `SwagBag/UI/SettingsCategories.lua` (edit 6 of 7), find:

```lua
	previewRows(out, d)
```

and replace it with:

```lua
	previewRows(out, d.text)
```

In `SwagBag/UI/SettingsCategories.lua` (edit 7 of 7), find:

```lua
SB.SettingsWindow.AddPage({ id = "categories", title = L.SET_PAGE_CATEGORIES, rows = function()
	if SC.draft then
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- Paste a Baganator search (AC6.3)
---------------------------------------------------------------------------
-- "From Baganator", else "From Baganator 2", 3...: a name no category has yet.
local function freeName()
	for n = 1, 99 do
		local name = n == 1 and L.PASTE_NAME or (L.PASTE_NAME .. " " .. n)
		if C.CheckName(name) then
			return name
		end
	end
	return ""
end

function SC.Paste()
	SC.draft, SC.picking, SC.confirmDelete = nil, nil, nil
	SC.paste = { text = "", name = "" }
	return L.PASTE_HINT
end

local function readPaste(p)
	local result, why, detail = Paste.Translate(p.text)
	p.result, p.why, p.detail = result, why, detail
	if not result then
		return L["PASTE_ERR_" .. why]:format(tostring(detail or ""))
	end
	if p.name == "" then
		p.name = freeName()
	end
	return L.PASTE_READ:format(result.query)
end

local function noteText(n)
	if n.kind == "NAME" then
		local starting = Paste.Prefixed(n.value)
		return L.PASTE_NOTE_NAME:format(n.value)
			.. (#starting > 0 and L.PASTE_NOTE_PREFIX:format(table.concat(starting, ", ")) or "")
	end
	return L["PASTE_NOTE_" .. n.kind]:format(tostring(n.value or ""))
end

local function make()
	local p = SC.paste
	if not p.result then
		return L.PASTE_READ_FIRST
	end
	local id, why = C.Create(p.name, p.result.query, "import")
	if not id then
		return refusal(why, p.name)
	end
	SC.paste = nil
	return L.PASTE_MADE:format(C.Get(id).name)
end

local function pasteRows()
	local p = SC.paste
	local out = {
		{ kind = "note", label = L.PASTE_INTRO },
		{ kind = "actions", label = L.PASTE_TITLE, actions = { { text = L.CAT_CANCEL, run = forget(function()
			SC.paste = nil
			return L.PASTE_CANCELLED
		end) } } },
		{ kind = "input", label = L.PASTE_BOX, maxLetters = 2 * Paste.MAX,
			get = function()
				return p.text
			end,
			set = function(text)
				p.text, p.result, p.why = text, nil, nil -- a changed string is read again before anything is made
			end,
			commit = forget(function(text)
				p.text = text
				return readPaste(p)
			end) },
	}
	if p.why then
		out[#out + 1] = { kind = "note", label = L["PASTE_ERR_" .. p.why]:format(tostring(p.detail or "")) }
	end
	if not p.result then
		return out
	end
	out[#out + 1] = { kind = "note", label = L.PASTE_READS_AS:format(p.result.query) }
	for i, n in ipairs(p.result.notes) do
		if i > SC.MAX_NOTES then
			out[#out + 1] = { kind = "note", label = L.PASTE_MORE:format(#p.result.notes - SC.MAX_NOTES) }
			break
		end
		out[#out + 1] = { kind = "note", label = noteText(n) }
	end
	previewRows(out, p.result.query, true)
	out[#out + 1] = { kind = "input", label = L.CAT_NAME, maxLetters = C.MAX_NAME, boxWidth = 200,
		get = function()
			return p.name
		end,
		set = function(text)
			p.name = text
		end,
		commit = forget(function(text)
			p.name = text
			local clean, why = C.CheckName(text)
			if not clean then
				return refusal(why, text)
			end
			return L.PASTE_NAME_OK:format(clean)
		end) }
	out[#out + 1] = { kind = "actions", label = L.PASTE_SAVE_LABEL, actions = { { text = L.PASTE_MAKE, run = forget(make) } } }
	return out
end

SB.SettingsWindow.AddPage({ id = "categories", title = L.SET_PAGE_CATEGORIES, rows = function()
	if SC.paste then
		return pasteRows()
	elseif SC.draft then
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1582 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (79 files)`, `1582 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Query/Paste.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/SettingsCategories.lua \
	spec/query_paste_spec.lua \
	spec/settings_categories_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 11 Task 4: paste a Baganator search: read, noted or refused, previewed, made a category

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

## In-game sessions

One session, CE1, on the **final merged build** (every task done, reviewed and fixed), as week 6's ruling P1 set; the "checks Tasks N" in its heading only says which tasks' work it checks. Then the week-11 exit check. It never blocks the build: findings come back as fixes.

Before the session:
- Claude installs the build first. The game currently runs an older copy, and the login line must say `v0.11.0`.
- If anything shows a red Lua error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After the session, reply "CE1 done" and the numbers of any steps that didn't match.

Chat lines start with `SwagBag: `. The settings window answers in its **status line** (the small text at its bottom), not in chat. Names and numbers like `N`, `M` or `x.x` are examples: yours will differ. Text in `this style` after "type" is what you type; press Enter after it.

### Session CE1: the category editor and paste (checks Tasks 1 to 4; about 25 minutes)

You need: a few potions or flasks in your bags. Optional (steps 27–28): Baganator still installed but **switched off** (or a category string from Wago), to compare one of its searches.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.11.0 loaded. Type /swagbag help for commands.`
3. Press **B** to open your bags. Then type `/swagbag settings categories`. Expected: chat `SwagBag: Settings opened.`; the settings window shows the Categories page: a text starting `Categories decide which section of your bags each item goes to.`, a row `Your own` with the buttons `New category` and `Paste a Baganator search`, then `Keystone & Crests`, `Consumables`, `Gear`... each with `Edit`, `Up` and `Down`. (Say if any buttons overlap.)
4. Click `New category`. Expected: the status line says `A new category: type its name, add rules, then click Save.`, and the page starts with `A new category`.
5. Click into the box under `Name`, type `My potions` and press Enter. Expected: `Name: My potions (click Save to keep it).` While you type, the letters appear in the box and nothing else happens (typing a "b" does not close your bags).
6. Click `Add a rule`. Expected: `Pick what the rule checks.`; the page shows `Item name contains...` and lists of keyword buttons under `Item type`, `Quality`, `Binding`, `Numbers (item level, gold...)`, `State`, `Gear slot` and `Where it is`. Scroll down with the mouse wheel to see them all. (Say if the buttons are hard to read or overlap.)
7. Click `potion` (in the `Item type` list). Expected: `Rule now: potion (click Save to keep it).`; the page shows a row `Rule 1: potion` with `Change`, `Not` and `Remove`.
8. Look at the line under the rules. Expected: `Matches N of the M items in your bags right now.`, N being your stacks of potions.
9. Click `Show matches in the bags`. Expected: the status line says `Search "potion": N of M slots match (x.x ms).`; in your bags everything except potions is dimmed, and **nothing moves**.
10. Click `Clear the bags' search`. Expected: `Search cleared.`; nothing is dimmed any more.
11. Click `Save`. Expected: `Saved My potions. Your bags sort by it the next time you open them (or press Reflow).`; the page shows the list again, with `My potions (yours)` first. Your open bags have **not** changed.
12. Press **B** twice (close and open your bags). Expected: a `My potions` section at the top, right under New if you have new items, holding your potions; Consumables no longer holds them.
13. Click `Edit` next to `My potions (yours)`, then `Show the rule as text`. Expected: `The rule as text is shown below the rules.`; the box under `The rule as text (press Enter or Apply to read it)` says `potion`.
14. Click into that box, change it to `potion | flask` and press Enter. Expected: `Read. Rule now: potion | flask (click Save to keep it).`; the rows show `Rule 1: potion` and `Rule 2: flask`, and `Any of these` is highlighted.
15. Click `All of these`. Expected: `Rule now: potion & flask (click Save to keep it).`, and the count says `Matches 0 of the M items in your bags right now.` (nothing is a potion and a flask at once).
16. Click `Any of these`. Expected: `Rule now: potion | flask (click Save to keep it).`
17. Click `Save`. Expected: `Saved My potions. Your bags sort by it the next time you open them (or press Reflow).`
18. Click `Edit` next to `My potions (yours)` and `Show the rule as text`. Change the text to `potion &` and press Enter. Expected: `The rule has an error: Expected a value after "&" at character 9. It can still be saved; it stays off until fixed.`
19. Click `Save`. Expected: `Saved My potions, but it stays off until its rule is fixed: Expected a value after "&" at character 9`; the list shows `My potions (off: its rule has an error)`.
20. Click `Edit` next to it. Expected: the rule opens as text only (`This rule can only be edited as text: it has an error.`). Change the text to `potion | flask`, press Enter, and click `Save`. Expected: `Saved My potions. Your bags sort by it the next time you open them (or press Reflow).`; the list shows `My potions (yours)` again.
21. Click `Edit` next to `My potions (yours)` and click `Delete`. Expected: `Click "Delete: sure?" to delete My potions. Its items go to the other categories.`, and the button now reads `Delete: sure?`. Click `Delete: sure?`. Expected: `Deleted My potions. Its items go to the other categories the next time you open your bags.`
22. Click `Edit` next to `Gear`, then `+10`. Expected: `Priority 80 (click Save to keep it).` Click `Save`. Expected: `Saved Gear. Your bags sort by it the next time you open them (or press Reflow).`; the list shows `Gear (changed)`.
23. Click `Edit` next to `Gear (changed)`, then `Reset to default`. Expected: `Gear is back to SwagBag's own (items you dragged onto it are forgotten too).` Click `Cancel`. Expected: `Nothing was changed.`; the list shows `Gear`.
24. Click `Paste a Baganator search`. Expected: `Paste the search into the box (Ctrl+V), then press Enter.`
25. Click into the box, type `#toy | #pet | pot` and press Enter. Expected: `Read as: #toy | #pet | pot. Check what it matches, name it, then click Make category.`; below it `SwagBag reads it as: #toy | #pet | pot`, then `"pot" matches item names only (Baganator also tried keywords starting with it, and some tooltip lines). SwagBag keywords starting with it: potion.`, then `Matches N of the M items in your bags right now.`; the `Name` box says `From Baganator`.
26. Change the text in the paste box to `#gear & >100g)` and press Enter. Expected: `SwagBag can't read it: Expected & or | but found ")" at character 14. Nothing was made.`, and there is no `Make category` button. Change it to `#gear & >100g` and press Enter. Expected: `Read as: #gear & value>=100. Check what it matches, name it, then click Make category.` and the line `Gold amounts compare SwagBag's price for one item (auction, else vendor); < and > include the amount, as in Baganator.` Click `Make category`. Expected: `Made the category From Baganator. Your bags sort by it the next time you open them (or press Reflow).`, and the list shows `From Baganator (yours)` first.
27. (Optional, with Baganator switched off but installed, or a Wago category string.) Copy one of your Baganator categories' searches (Baganator's category settings show it as text), click `Paste a Baganator search`, click into the box, press **Ctrl+V** and Enter. Expected: `Read as: ...` or a reason why not. Compare the count with what that category held in Baganator (say if it is very different; and for a search with a gold amount, whether it seems to count per item or per stack).
28. Delete the categories you made for this session: `Edit` next to each `(yours)` one, `Delete`, `Delete: sure?`. Expected each time: `Deleted <its name>. Its items go to the other categories the next time you open your bags.`
29. Close the settings window and type `/swagbag report`. Expected: a line `Categories: 20 (N edited)  Broken: none` (N: the built-in categories you changed or dragged items onto before this session; 0 if none). Close the report box.

## Week 11 exit check

1. Claude installs the week-11 build, at the end of Task 4 (after review and fixes), and you fully restart the game.
2. Play normally for a day, with keys, a vendor and a bank visit, and make one category of your own that you keep. Expected: no red errors; nothing moves under your mouse; your category holds what you meant.
3. Type `/swagbag report` and paste it to Claude. Expected:
   - `Safe Mode: bags=off bank=off`;
   - `Failed checks: none`;
   - `Blocked actions: none`;
   - the `Categories:` line with your own category counted and `Broken: none`.


## Spec updates at week end

Recorded in the week-11 ledger and applied to `docs/superpowers/specs/2026-09-30-swagbag-design.md` at week end (this plan commits only the plan file):
- **F6, AC6.1** gains: the rows are two levels (groups of rows; All of these / Any of these; Not on a row and on a group; with several groups, all or any); a rule nested deeper, a double Not, more than 40 rows or 10 groups opens as text only with the reason; "losslessly" means the same tree (`Query.Pretty`'s spelling) both ways, and a rule not changed in the rows is saved as typed; the keyword lists are the spec 7.3 families; a name typed in a row is always quoted.
- **F6, AC6.2** gains: a broken rule is saved with `enabled = false`, said at Save, shown as `(off: its rule has an error)` in the list and in the report's Broken list; fixed and saved, it is on again; a Save never regroups the open bags (they sort by it at the next open or Reflow).
- **F6, AC6.3** gains: the paste mapping (this plan's table: gold amounts, `!!`, an open `(` translated; unknown `#keywords`, name words, `upgrade`/`bop`, item levels noted; quotes, chat codes, unreadable syntax and over 500 characters refused whole, positioned in the pasted text; never a partial save); the result is previewed (count and Show matches) and made a new user category "From Baganator" (`source = "import"`, priority 88).
- **F6, new AC6.4:** Settings > Categories lists every category in display order with Edit, Up and Down, and New category; a new category is On, priority 88, first; names have 1–30 characters, no `|`, unique (also against New and Free, any case); rules at most 500 characters; priorities 1–89 in steps, none for the four pinned built-ins; Delete (user categories only) asks once more and takes the id out of the order, every focus mode (account and this character) and this character's collapsed sections; Reset to default removes a built-in's whole diff, dragged items included.
- **§7.2:** the "did you mean" hint is in the editor (a keyword one letter away).
- **§7.5:** a new item 13, "At paste", pointing to AC6.3's mapping.
- **§7.7:** `source = "import"` also for a pasted category; user categories' ids are `u_<name>` (`_2`, `_3`...).
- **§7.10:** "The rule builder marks the row": a row with an empty value, a quote in a name or a non-number shows a note under it; a rule with an error opens as text with its error.
- **§8.2:** no new key; the editor writes `categories`, `userEdits` and `categoryOrder` only (as listed in "Global Constraints").
- **§10.5:** `/swagbag settings categories` opens the page.
- **§13.1 (risks):** a share string holding a broken category is refused at import (F20, D17); gold amounts from Baganator are compared per item with SwagBag's price (G6).
- **§12.1 (what is in and out):** F6 moves from "Deferred to November" to "In", delivered in week 11 (v0.11.0).

## Spec coverage (week-11 scope → task)

| Requirement (from the brief) | Task |
|---|---|
| 1a. Parse a query into an editable tree of AND/OR blocks with NOT; rows of keyword + operator + value | T1 (D1, D4) |
| 1b. Print the tree back; lossless round trip for everything the rows can express | T1 (D2), T3 (an untouched rule saved as typed) |
| 1c. Queries the rows can't express open in Advanced only, with a clear note | T1 (`FromText`'s reasons), T3 (the text-only note) |
| 1d. Property/fuzz-style tests over all built-in queries and the keyword list | T1 (built-ins, shapes, 400-rule fuzz with a semantic reference, keyword lists vs the registry) |
| 2a. Category list: built-in + user; create, rename, delete a user category; edit a built-in as a diff, Reset | T2 (writers), T3 (page) (D8, D11, D12) |
| 2b. The row editor: keyword lists, operators by kind, value field, add/remove row, groups, NOT | T3 (D3, D4) |
| 2c. Advanced text, two-way | T3 (D5) |
| 2d. Live "matches N items in your bags" preview; nothing moves in the bags | T2 (`Preview`), T3 (D6: Show matches dims through the search) |
| 2e. Priority and display order (up/down) | T2 (`Move`, `Save`), T3 (D9, D10) |
| 2f. Save runs Validate; invalid saved disabled with the error shown, never dropped (AC6.2) | T2, T3 (D7) |
| 2g. P2: every action answers once | T3, T4 (status line only) |
| 3a. Paste box translating supported syntax; mapping table; unsupported parts reported precisely | T4 ("Paste mapping", D13) |
| 3b. Preview (count + dimming), save as a new user category on confirm | T4 (D14) |
| 3c. Never executes input; length limits; refuse whole vs save what was understood (decide, justify) | T4 (D13: refuse whole) |
| 4. Week-10 polish only if cheap and user-visible | D15, "Carry-overs" |
| Version 0.11.0 in Task 1 | T1 |

## How this plan was checked (while writing it)

- Every task was first built on a scratch clone at `/tmp/sb11` (outside the repo), one commit per task, test-first: each task's tests were run against the previous task's code (red) and then against its own (green). Every block in this file was then generated from those commits' diffs by a script: each find block is the smallest one, grown line by line above and below the change, that occurs exactly once in the file as it is after the earlier edits, starts and ends on a non-blank line and holds a line of at least twelve characters; the script re-applied every block to the old file and compared the result with the commit's file.
- **Replay.** A fresh clone of `134a6bd` (`/tmp/sb11r`) was driven by a script that reads this file: for each task it applies the Step 1 blocks, runs the suite, applies the Step 3 blocks, runs the suite and `scripts/check.sh`, then commits. Every find block occurred exactly once when applied; every Step 2 count and FAIL list (name by name), every Step 4 total, every Step 5 `ALL CHECKS PASSED` and TOC count, and every Step 6 `git add` list (equal to the files the task changed) above is that script's output. Final total: **1582 passed, 0 failed**.
- **Mutations.** Every mutation listed under a Step 2 (41 in all) was read back from this file by the same script, applied to its own task's replayed commit, and the whole suite run: every one made its named test fail.
- **Strings.** The session's quoted status lines were produced by driving the finished page through the same test helpers (`Fake.Fire` on the buttons, the text boxes typed and entered), then compared with `enUS.lua`; `N`, `M` and `x.x` are the only placeholders.
- **Research** (no code copied): the week-1 desk spike's notes on Syndicator's search language (`docs/research/2026-10-syndicator-grammar-diff.md`); every row of its table of 24 published Baganator strings is in Task 4's fixture test.
- Greps on the final tree:
  - no `C_`/`Enum.` outside `SwagBag/Core/Adapter.lua`, no `TSM_API`/`LibStub` (check.sh); none of the forbidden tokens;
  - no `loadstring`, `load(`, `RunScript`, `setfenv` or `dofile` in `SwagBag/`;
  - no `BagsWindow`, `RequestLayout`, `Reflow` or `Layout` call in `UI/SettingsCategories.lua`, `Engine/Query/Rows.lua`, `Engine/Query/Paste.lua` or the new `Categories` writers (P5);
  - no `OnUpdate`; no `Config` call at load; no `%s` given a boolean (format51 runs on every spec).

## Self-review

1. **Scope coverage.** Every item of the brief maps to a task or a named decision in "Spec coverage", in the brief's order (the rows model first, then the editor, the paste, the polish). Each open question has a decision row: what the rows show (D1), lossless (D2), the keyword picker (D3), operators (D4), Advanced (D5), the preview and dimming (D6), Save and AC6.2 (D7), new-category defaults (D8), priority (D9), order (D10), delete (D11), built-ins (D12), paste refuse/translate/partial (D13), what a paste makes (D14), the polish (D15), the version (D16), share strings (D17).
2. **Placeholder scan.** No "TBD", "TODO", "similar to", or test-free step. Every code step is a complete block (the replay applies them as written). The in-game expectations quote Locale strings verbatim; where a line holds the player's own names or numbers the step says so.
3. **Type and name consistency.** These names are the same in every task that uses them: `SB.QueryRows` (`FromText`, `ToText`, `FAMILIES`, `NUMBER_OPS`, `KindOf`, `NewRow`, `Problem`, `Nearest`, `MAX_ROWS`, `MAX_BLOCKS`, `MAX_TEXT`), the rules shape `{ join, blocks = { { join, negate, rows = { { kind, value | name, op, raw, negate } } } } }`, `SB.Categories` (`CheckName`, `Create`, `Save`, `Delete`, `Move`, `Preview`, `ResetBuiltin`, `MAX_NAME`, `MAX_QUERY`, `USER_PRIORITY`, `MIN_PRIORITY`, `MAX_PRIORITY`, `PINNED`), `SB.SettingsCategories` (`Edit`, `New`, `Save`, `Cancel`, `Paste`, `draft`, `picking`, `confirmDelete`, `paste`, `STEPS`, `MAX_NOTES`), `SB.QueryPaste` (`MAX`, `Translate`, `Prefixed`, note kinds), the settings `input` row (`get`, `set`, `commit`, `button`, `maxLetters`, `boxWidth`).
4. **Review Focus.** Each of the eight lines names its pinning tests, and each of those tests is in its owning task's Step 1.
5. **Global Constraints.** No `C_`/`Enum.` anywhere new; no Adapter change; no secure frame or item button touched; every new entry point under `"none"`; every user-visible string in `enUS.lua`; no new setting, schema 2; nothing run from a string; no `OnUpdate`; nothing runs while idle.
6. **Known limits, stated in the plan.** Rows show two levels (deeper rules are text only, D1). A rule changed in the rows is saved in Pretty's spelling (D2). Baganator's keyword prefixes, tooltip-line search, two-unit gold amounts and the keywords SwagBag lacks are not supported, and each is named at paste (D13). A share string with a broken category is refused at import (D17). Another character's own focus sections keep a deleted id until that character edits them (harmless, not shown). The preview counts stacks in the bags only (not the bank).
