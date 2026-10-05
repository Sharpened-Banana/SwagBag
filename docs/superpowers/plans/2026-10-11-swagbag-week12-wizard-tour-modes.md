# SwagBag Week 12: The setup wizard, the guided tour, and focus modes of your own. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ] `) syntax for tracking.

**Goal:** the user left Baganator because it was "too complicated to set up". Week 12 finishes the v1.0 feature list with the three things that make SwagBag set itself up and explain itself, and the last power feature of the focus modes. In this order of priority, so the earlier ones ship first if time runs out:
1. **The setup draft and the playstyle overlays** (engine, pure Lua): what the wizard picks lives in a draft in memory; Finish writes exactly what a picked playstyle sets (its focus modes, its overlays: AC9.2, written as explicit values) and what the user changed, and nothing else; Skip writes only that setup is done (AC7.2). The version goes to 0.12.0 (Task 1).
2. **The four-step wizard** (AC7.1, AC7.4): the quick setup screen becomes four short steps, one screen each: 1 What do you play? (M+, Raid, Gold-making, Casual, Collector), 2 What that turns on (every focus mode and what the picks switch, a click each), 3 How your bags look (slots per row, size, look), 4 Gold (where prices come from, found or not; the gold glow at the bank; selling junk). Back, Next and Skip on every step, Finish on the last. A user who already finished or skipped the quick setup never sees it again unless they type `/swagbag setup`, which starts from their settings as they are (Task 2).
3. **The guided tour** (AC7.3): `/swagbag tour`, any time, shows the bag window's parts one at a time (section headers, collapse, focus modes and peek, search, the mode title and Pause, Sort, Safe Mode), each with a small note and a thin gold frame, with Back, Next and End. It only points, never moves anything, and ends cleanly (one line) when the bags close or combat starts. Finish offers it once ("Show me around") (Task 3).
4. **Focus modes of your own** (AC8.7), the engine: a name, a trigger (only when you switch it on, or one of the built-in signals: a key, a dungeon, a raid, a delve, PvP, fishing, gathering, a vendor, the auction house, the bank) and a section set; merged with the built-ins, or ranked under strict priority; `/swagbag mode on <name>` and `off`; delete; read defensively (Task 4).
5. **Settings > Focus modes for them** (AC8.7, AC15.1): New mode (a name, when it switches on, Make mode), a manual mode switched from the mode list, editing one (its sections with the existing editor, its name, its trigger), Delete asking once more, "This character only" covering them; share strings leave them out and say so; and the one week-11 deferred item that is cheap and user-visible (the import preview's "Ranked just below Junk" line names a category by the name it comes in under) (Task 5).

**The user's principle (2026-10-04, ruling V0, binding on every task):** "out of the box as easy and simple as possible, under the hood an insane amount of customization and power." The simple half: the wizard is four short screens with everything pre-selected (on a first run SwagBag's defaults, on a re-run your own settings), Skip on every step, nothing written before Finish, plain words, and it never comes back by itself for a user who has set up; the tour is offered once and never needed; nothing new appears in the bag window. The power half: every switch the wizard shows stays in Settings with its alternative next to it; modes of your own can use any built-in signal, any sections, strict priority, a character of their own; nothing the wizard does limits what Settings can do.

Tests go from 1614 to **1663**.

**Architecture:**
- (1) `Engine/Setup.lua` (new, `SB.Setup`): pure Lua, no frames. `Setup.New()` makes a draft `{ styles, touched }` pre-filled from `setup.styles` (a new key under `setup`, this machine's state like `setup.done`); `Setup.Value(d, key)` is the user's choice in this run, else what a picked style sets (`Setup.Preset`), else the setting now; `Setup.Plan(d)` is what Finish writes; `Setup.Finish(d)` writes it, the category order (`Setup.Order`, moved here from the quick setup) and `setup.styles`/`setup.done`, then `SB.FollowSettings` (and the look, and the open bags' size); `Setup.Skip()`.
- (2) `UI/QuickSetup.lua` (rewritten in place, same frame name `SwagBagQuickSetup`, same `setup.done`, same `/swagbag setup`): four step panels of plain Buttons and FontStrings, drawn from the draft by `QS.Paint()`; nothing in it writes a setting.
- (3) `UI/Tour.lua` (new, `SB.Tour`): one note frame and one gold ring frame (plain `BackdropTemplate` Frames), pointed at parts of `SB.BagsWindow` that already exist (`SB.SectionHeaders.inUse`, `SB.SearchBox.editBox`, `W.modeButton`, `W.sortButton`, `W.frame`); `/swagbag tour` moves from `UI/QuickSetup.lua` to here. The quick setup file gets the small tour-offer note.
- (4) `Engine/Focus.lua` gains the user's modes next to `Focus.MODES` (`Focus.custom`, `Focus.All()`, `Focus.TRIGGERS`, `Focus.Mode/NameOf/FindMode`, writers `CreateMode/RenameMode/SetTrigger/DeleteMode/SetManual`, `/swagbag mode on|off`). Stored in `SwagBagDB.modes` (schema 2, read defensively); their on/off and sections are the ordinary `focus.on.<id>` / `focus.sections.<id>` settings. `Engine/Categories.lua`'s Delete cleans the user's modes' sections too.
- (5) `UI/SettingsFocus.lua` gains the user's modes on the existing page (rows of the existing kinds: `choice`, `actions`, `input`); `Engine/Profiles.lua`'s export answer names the user's modes as left out, and its preview's lowered line uses the placed name.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105; 12.1.5 goes live 2026-10-13). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- F7 (first-run wizard and tour): AC7.1 (the 4-step wizard: playstyle multi-select, preset categories and focus modes, layout, gold settings with Auctionator/TSM detected or not and the threshold), AC7.2 (Skip applies the defaults and says so), AC7.3 (`/swagbag tour` at any time: headers, collapse, peek, search, modes, sort, Safe Mode), AC7.4 (`/swagbag setup` re-runs it);
- F8: AC8.7 (custom mode: name, trigger, section set), with AC8.4's merge / strict priority and AC15.1's per-character override; §6.3's "Users create custom modes with the same editor";
- F9: AC9.2 (the playstyle sets the overlays' defaults);
- §12.1: the "one-screen quick setup" becomes the full wizard and tour (F7 moves to "In");
- P1, P2, P3, P5, P6, P8 as in "Global Constraints".
The spec text is updated at week end (see "Spec updates at week end"). All rights reserved: every idea here is clean-room; no code is copied from any other addon.

Ledgers (binding rulings W3-*, W4-*, W5-*, week 6, week 7 R1–R22, week 8 Q1–Q13, week 9 R0, S1–S20, week 10 U1–U11, week 11 V0, X1–X19, SP1–SP4 and the final fixes): `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md` through `2026-10-10-swagbag-week11-ledger.md`. Week-11 plan (style and interfaces): `docs/superpowers/plans/2026-10-10-swagbag-week11-rule-builder.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week12` is already checked out. It was made from `main` at `8503e06` (v0.11.0, the week-11 ledger and preflight; week 11 is merged). The suite has 1614 tests. No task creates or switches branches.

**The code at `8503e06` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). These interfaces are used as they are on `8503e06`:
- `SB.On`, `SB.Emit`, `SB.Debounce`, `SB.ErrorTrap.Run/Guard`, `SB.Print`, `SB.Slash.Register/Run/Dispatch`, `SB.FollowSettings(reason)` (`Core/Init.lua`: categories, prices, overlays, the open bags' layout and title).
- `SB.Config.Get/Set/CharOverride/CharOverrideMany/IsCharOverride/db/charDB/readOnly/Init/Defaults` (`Config.Set` returns false while read-only; `Config.Get` falls back to `Config.Defaults`; only values somebody wrote are stored).
- `SB.Focus` (`MODES`, `byId`, `signals`, `SetSignal`, `Recompute`, `Refresh`, `Active`, `Label`, `Front`, `SectionOrder`, `Sections(id, raw)`, `SetSections`, `SetEnabled`, `IsEnabled`, `ResetSections`, `Pause`, `Resume`, `ListLines`; the `SB_CONFIG_CHANGED` listener refreshes on any `focus.*` path), `Engine/Signals.lua` (unchanged: every signal a mode of your own can use is already read there).
- `SB.Categories` (`Load`, `display`, `SectionOrder`, `Create`, `Delete`, `Name`), `SB.Profiles` (`CategoriesChanged`, `Export`, `Parse`, `Preview`, `Import`; `KEEP = { safeMode, setup }` never travels), `SB.Prices.Source/SourceText/Invalidate`.
- `SB.SettingsWindow` (`AddPage`, `Render`, `Show`, `Say`; rows `choice` / `actions` (with `selected`) / `input` / `note`, `act()` under `"none"`), `UI/SettingsFocus.lua` (`SF.Paths`, `SF.Edit`, the section editor).
- `SB.BagsWindow` (`frame`, `child`, `modeButton`, `sortButton`, `IsOpen`, `Open`, `SetScale`, `RequestLayout`), `SB.SectionHeaders.inUse` (each header's `GetParent()` is the window's child it was acquired in), `SB.SearchBox.editBox`, the internal events `SB_BAGS_CLOSED` and `SB_BAGS_LAYOUT`, `SB.Theme` (`order`, `Name`, `Available`, `Apply(id, save)`, `Button`, `Window`, `Text`).
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua` (`Fake.New`, `Fake.Fire`, `Fake.Install/Uninstall`, `Fake.created`; a fake's unmodelled methods are recorded no-ops; `Show`/`Hide` fire `OnShow`/`OnHide` on a real change), `uienv.lua` (`Env.ENGINE`), `spec/mock_adapter.lua` (`m.combat`, `m.instance`, `m.auctionator`, `m.Lines`, `m.Advance`), `SB.eventFrame:Fire(event)`, and `format51` (installed by the runner).

## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.12.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. **No new Blizzard API this week and no Adapter change.** No new event: the wizard and the tour listen to `PLAYER_REGEN_DISABLED` (week 11) and `PLAYER_REGEN_ENABLED` (week 1), and to SwagBag's own `SB_BAGS_CLOSED` and `SB_BAGS_LAYOUT`. No new client template: `BackdropTemplate`, `UIPanelButtonTemplate`, `UIPanelCloseButton` and `InputBoxTemplate` are the ones the settings window and the quick setup already use.
- TOC metadata unchanged (`## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster, Masque`). Two files are added: `Engine/Setup.lua` (Task 1, right after `Engine/Profiles.lua`) and `UI/Tour.lua` (Task 3, right after `UI/QuickSetup.lua`): the TOC goes from 79 to 80, then 81 files.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets a string or a number, never a boolean or nil. Every spec runs under `spec/helpers/format51.lua`.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace, `Enum`, ElvUI, Syndicator, `TSM_API` or `LibStub`, **comments included** (`scripts/check.sh` enforces `C_*`, `Enum.`, `TSM_API`, `LibStub`). Nothing new names any of them: the wizard's look buttons take their words from `Theme.Name(id)`, and its price line from `Prices.SourceText()` (checked by grep, "How this plan was checked").
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`.
- **Plain frames only, no secure frame touched.** The wizard, the tour's note and its gold ring, and the tour offer are plain `Frame`s, `Button`s and `FontString`s, which may be created and hidden in combat. The tour anchors its note to plain frames that already exist (a section header, the search box, the Pause and Sort buttons, the bag window) and **never to an item button**; it calls nothing on the bags window but `IsOpen` and `Open` (P5). Settings > Focus modes adds rows of the kinds it already has.
- **Nothing typed is ever run.** A mode's name is text: trimmed, checked by Lua patterns, stored and shown; it never becomes a path piece (the id is `m_` plus letters, digits and `_` only). No `loadstring`, `load`, `RunScript` or `setfenv` anywhere (checked by grep).
- **V0 (the user's principle, binding):** "out of the box as easy and simple as possible, under the hood an insane amount of customization and power." Simple: the wizard is four short screens, pre-selected, Skip on every step, nothing written before Finish, never shown again by itself to a user who has set up; the tour is offered once and never needed; nothing new in the bag window (checked by grep: no change to `UI/BagsWindow.lua`, `UI/SectionHeaders.lua`, `UI/SearchBox.lua`). Power: everything the wizard shows stays in Settings with its alternative; modes of your own take any built-in signal, any sections, strict priority and a character of their own. Every task is checked against both halves.
- P1: every choice ships with a default and its alternative next to it. This week: the wizard's every value starts as it is now (SwagBag's default on a first run); a picked style's switches start On; a new mode starts as "Only when I switch it on" with no sections; strict priority stays the alternative to merge.
- P2: every click and command answers **exactly once**. The wizard: Finish and Skip answer in chat and on its status line; Next, Back and a switch answer by the screen itself (the step or the button's text changes), with no chat line; the tour offer's two buttons answer in chat. The tour: Start, Done, End tour, Esc, the bags closing and combat starting each say one chat line; Next and Back answer by the note itself. Settings > Focus modes answers in the status line (`SW.Say` through `act()`). `/swagbag mode on|off` answers every form.
- P5 / spec §4.2 rule 5: nothing moves under the mouse. Finish lays out the open bags as the quick setup always did (`SB.FollowSettings`, ruling R12; `W.RequestLayout` keeps its own hover guard). The tour lays out, sorts and moves nothing. A mode of your own switching on or off re-stacks the open bags exactly as a built-in mode does (`SB_FOCUS_CHANGED`, the existing "front" re-order and its hover guard).
- **P6.** Every WoW entry point runs inside `SB.ErrorTrap.Run` or `Guard`, all under `"none"` (a wizard, tour or settings glitch is recorded for `/swagbag report` and never takes the bags away): `setup.click` (every wizard and offer button), `setup.finish`, `setup.refresh` (the windows following after Finish), `setup.hide`, `setup.offerHide`, `setup.dragStart`, `setup.dragStop`, `tour.back`, `tour.next`, `tour.end`, `tour.hide`, `event:SB_BAGS_CLOSED`, `event:SB_BAGS_LAYOUT`, `event:PLAYER_REGEN_DISABLED`, `event:PLAYER_REGEN_ENABLED` (`SB.On`'s own labels), `slash:tour`, and the settings window's existing `settings.choice` / `settings.action` / `settings.input`. `/swagbag mode` keeps its `"bags"` window (week 4).
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`. Keys built at run time are checked by tests: `L[s.text]` (the tour's notes: "every note's words are in enUS.lua"), `L[t.name]` (the triggers: "each built-in signal a mode can use..."), `L["SET_CUSTOM_WHY_" .. why:upper()]` (guarded by `rawget`, and "a name that can't be used says why..." asserts every reason), `L[STEP_NAMES[step]]` (the four step names, asserted word for word), `L[ENDS[reason]]` (each tour ending asserted).
- **Settings and saved data (schema stays 2, no migration).** New this week, all read defensively and stored only when somebody wrote them: `settings.setup.styles` (a string such as `"mplus,gold"`, written at Finish; under `setup`, this machine's state like `setup.done`, so Profiles' `KEEP` never saves, loads or shares it); `SwagBagDB.modes` (a new top-level table like week 7's `locks` and `profiles`: `modes[id] = { name, trigger, n }`, and `false` for a deleted one so its id is never given again; anything damaged is skipped, an unknown trigger reads as manual, ten at most are used); and the ordinary settings `focus.on.<m_id>` and `focus.sections.<m_id>` of a mode of your own (written when the mode is made, so "This character only" can copy them). The wizard writes nothing but Finish's plan (a picked style's settings, as explicit values, AC9.2, and what this run changed), `categoryOrder` (as the quick setup did), `setup.styles` and `setup.done`. A week-11 save loads exactly as before and nothing in it changes (tests in Tasks 2 and 4).
- No file calls `Config` at load time. No `OnUpdate` anywhere. Idle CPU with every window closed is 0: the wizard and the tour draw only on clicks and on the events above; the user's modes are read again only when a focus setting changes (`Focus.Refresh`), never per signal.
- Every critical test names the mutation that must make it fail. Each task lists its mutations under Step 2.
- **Tooling (binding, as in weeks 1–11):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). The UI tests drive the screens as the user does: buttons by their text or their field (`Fake.Fire(button, "OnClick")`), text boxes by setting the text, firing `OnTextChanged` with `userInput = true`, then `OnEnterPressed`. CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Test totals are cumulative from 1614 (see "Schedule").
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

1. **A returning user shown the wizard again** (the user finished the quick setup in week 4; a wizard that pops up at login now is exactly the nagging V0 forbids). Expected: `setup.done` is the same flag as before, account-wide; a save that has it never shows the wizard by itself, also when the wait for leaving an instance ends after the user set up meanwhile; only `/swagbag setup` opens it. Pinned by Task 2: "setup done (a week-11 save, or done while it waited in an instance): never shown by itself again", and the unchanged "shows a few seconds after the first login; not again once applied or skipped".
2. **The wizard writing what the user did not choose, or half of what they did.** Expected: nothing is written before Finish (Back, Next, a switch, Esc, combat: nothing); Finish writes exactly a picked style's settings (explicit, AC9.2) and what this run changed; Skip writes only `setup.done`; read-only writes nothing. Pinned by Task 1: "the plan: a picked style's settings, written even when they equal the default; other values only if changed", "Finish writes the plan...", "Finish with no style picked writes only what was changed, and says so", "read-only settings: Finish and Skip refuse...", "AC7.2: Skip writes only that setup is done..."; Task 2: "AC7.1: four steps, one screen each: ... nothing saved before", "combat starts while it is open...".
3. **A re-run quietly undoing a choice made in Settings since** (a style's preset re-applied over a switch the user turned off). Expected: a re-run starts from the settings as they are and last time's styles; what a picked style would switch is shown on step 2, line by line, before Finish, and any line can be switched back. Pinned by Task 1: "what the wizard shows: the user's choice, else what a picked style sets, else the setting now", "a new draft starts from the styles picked last time..."; Task 2: "AC7.4: /swagbag setup starts from the settings as they are...", "step 2 lists every focus mode and what the picks switch...".
4. **The wizard in combat.** Expected: it never opens by itself in combat or in an instance (W4-21); opened by the user it works; combat starting while it is open makes it step aside with one line and come back at the same step with the same picks; Finish in combat saves; no tour is offered in combat, and an offer shown when combat starts goes away with how to get it later. Pinned by Task 2: "combat starts while it is open: it steps aside, says so once, and comes back as it was when combat ends" and the W4-21 tests; Task 3: "no tour offer in combat; combat starting while it is offered takes it away, with how to get it later".
5. **The tour when the bags close, combat starts, or Esc is pressed** (a note left floating, two lines, a note over a fight). Expected: each ends the tour at once with one line, the note and the gold frame go, a second ending says nothing. Pinned by Task 3: "the bags closing ends it: the note goes, one line, once", "combat starting ends it at once, with one line; the bags stay as they are", "End tour and Esc stop it with one line; nothing in the bags moved, sorted or was laid out", "refused in combat, while the bags are Blizzard's, or when they can't open; nothing is shown".
6. **The tour touching what it must not** (an item button, a layout under the mouse, the bank's headers). Expected: it points at the bags' own header (never another window's), the search box and the title buttons; it calls nothing that lays out, sorts or collapses; plain frames only; after a layout it points again. Pinned by Task 3: "AC7.3: /swagbag tour opens the bags and puts the first note next to the bags' first section header", "a part that isn't drawn...", "the bags laid out again (a view change) while it runs...", "every note's words are in enUS.lua; only plain frames".
7. **Custom mode names colliding with built-ins or each other** (two "Farming", one called "Raid", `/swagbag mode on raid` switching the wrong thing). Expected: a name is refused (with the reason) when empty, over 24 characters, a chat code, a built-in mode's name or id in any case, or one of the user's other modes; `/swagbag mode on|off` only switches the user's manual modes and says why for any other. Pinned by Task 4: "names: refused when empty, too long, a chat code, a built-in mode's name (any case), or another of yours", "/swagbag mode on <name> and off: every form answers once...", "at most ten modes of your own; ids follow the name and are never given twice"; Task 5: "a name that can't be used says why, at Enter and at Make mode; nothing is made".
8. **A mode of your own pointing at a deleted category.** Expected: deleting a category takes its id out of every mode's sections, the user's modes included, the account's and this character's; an id another character still holds is harmless (not shown, never given to a new category: week 11). Pinned by Task 4: "deleting a category takes it out of your own modes' sections too, the account's and this character's".
9. **Trigger signals firing in combat.** Expected: a mode of your own uses only the signals `Engine/Signals.lua` already reads (no new event, no polling); its trigger is one table lookup; Recompute stays well under its budget with ten of them; the open bags re-stack through the same path as a built-in (`SB_FOCUS_CHANGED`, the hover guard). Pinned by Task 4: "each built-in signal a mode can use switches it on exactly while that signal holds", "Recompute with the six built-ins and ten modes of your own stays well under 0.5 ms (spec 6.5)", "merge opens the union with the built-ins; strict priority: a manual mode you switched on decides first".
10. **A deleted mode coming back** (its switch, sections or character override left behind and picked up by a new mode with the same name). Expected: Delete removes its switch and sections from the account and from this character's overrides, switches it off, and its id stays taken (`m_farming_2` next time). Pinned by Task 4: "delete: the mode, its switch and its sections go...", "at most ten modes of your own; ids follow the name and are never given twice"; Task 5: "Delete asks once more; any other click forgets the question; deleted, the page shows M+ again".
11. **Hostile or damaged modes** (a hand-made share string with `m.` entries or `focus.*.m_` paths; a damaged `SwagBagDB.modes`). Expected: share strings never carry modes: an import skips such entries (named in the preview as skipped) and never makes a mode; a damaged stored entry is skipped, an unknown trigger reads as manual, ten at most; the user's own export says their modes are not in it. Pinned by Task 4: "stored modes are read defensively: damaged entries skipped, an unknown trigger is manual, ten at most"; Task 5: "an export leaves your own modes out and names them; an import never makes one (hostile entries skipped)".
12. **"This character only" not covering the user's modes.** Expected: the scope switch makes every mode's switch and sections this character's own, those of a mode made meanwhile too. Pinned by Task 5: "This character only makes your own modes' switches and sections this character's too".
13. **Read-only settings.** Expected: Finish, Skip and every mode writer refuse with `L.SETTINGS_READONLY` and change nothing. Pinned by Task 1: "read-only settings: Finish and Skip refuse with the reason and write nothing"; Task 2: "read-only settings: Finish and Skip refuse with the reason and change nothing"; Task 4: "read-only settings: every writer refuses and changes nothing".

## Decisions (every product default chosen this week, read before Task 1)

| # | Question | This plan (the default) | The alternative, and where it is | Why |
|---|---|---|---|---|
| D1 | Wizard, or the quick setup kept? | **The quick setup screen becomes the wizard, in place**: same window, same `setup.done` flag (account-wide), same `/swagbag setup`. A user who finished or skipped the quick setup is **never shown the wizard by itself**. | `/swagbag setup` runs it any time (AC7.4). | V0: it never forces anything; the user set up in week 4. One flag means no "what's new" nag and no migration. |
| D2 | When is anything written? | **Only at Finish.** The draft lives in memory (`Engine/Setup.lua`); Back, Next and every switch are free; Esc or the X is "later" (nothing saved, it says so); combat makes it step aside and come back. | — | A wizard that writes per step would leave half a setup when closed, and Back would have to undo. One write, one answer (P2). |
| D3 | What does Skip do? | **Leaves the wizard on any step and keeps SwagBag's defaults** (on a re-run: the settings as they are), writes only `setup.done`, and says so (AC7.2: `QS_SKIPPED` / `QS_SKIPPED_KEPT`). "Skip this step" is Next: every step is pre-filled. | Finish with nothing changed. | AC7.2 word for word; one Skip is simpler than two kinds. |
| D4 | Step 1: what is pre-selected? | **First run: nothing** (any or none may be picked; none keeps SwagBag's defaults). **Re-run: last time's styles** (`setup.styles`, written at Finish). | Pick any. | A playstyle is a statement about the player: SwagBag cannot guess it. The defaults already serve "Casual". |
| D5 | Step 2: what does it show? | **Every built-in focus mode with On/Off, what the picked styles switch, and the categories they move up**, one line each, its state in its text ("Upgrade arrow on gear: On"); a click switches it. At most 17 lines in two columns. | Settings > Focus modes and > Bags have each switch with more words. | AC7.1 "preset categories and focus modes"; the user sees exactly what Finish will do. |
| D6 | AC9.2: what does each style set? | **M+**: M+ mode, the low-consumables warning, keystone level, upgrade track, upgrade arrow, item level. **Raid**: Raid mode, the warning, upgrade arrow, item level, upgrade track. **Gold-making**: gold totals on headers, the junk coin, and the gold glow at the bank (100 g) **only if it is off** (an amount or a top % the user set stays). **Collector**: the uncollected star and the learn glow. **Casual** alone: the warning and the upgrade track off. Gold also moves Trade Goods and BoE gear up, Collector moves Collections up (week 4). Each is written **as an explicit value at Finish** (even when equal to today's default), so a later default never undoes what the style chose. | Any switch on step 2, or later in Settings. | AC9.2 "the wizard's playstyle sets the defaults"; the brief's examples (Collector: uncollected/learn; M+: keystone/upgrade; Gold: worth glow). Every mark defaults to on today, so a style changes nothing visible for a new user, and pins it for the future. |
| D7 | A re-run with styles already picked | **Step 2 shows each picked style's switches as the style sets them** (over the settings now); a switch the user changed in Settings since shows the style's value, visibly, and can be clicked back before Finish. | Unpick the style. | One rule ("what a picked style sets, unless you switch it here") is easier to understand than "only styles new this time"; nothing is hidden. |
| D8 | Step 3: layout | **Slots per row 10 / 12 / 14 / 16, size 80–125 %, the look** (only the looks whose addon is loaded, plus the one set now), each pre-selected as it is now. A value set elsewhere that is not a button (13 slots, a Ctrl+wheel size) shows nothing selected and is kept unless a button is clicked. | Settings > Bags, Settings > Look, Ctrl+wheel. | The settings page's own choices; nothing new to learn. |
| D9 | Step 4: gold | **Where prices come from** (one line: the addon found, e.g. "SwagBag found Auctionator", or "No auction price addon found, so prices are what a vendor pays..."), **the gold glow at the bank** (Off / 50g / 100g / 500g / 1000g, plus "Your top N%" while that is the setting), **selling junk** (On / Off). | Settings > Bank & guild (price source, TSM's price), Settings > Vendor (repair). | AC7.1 "Auctionator detected or not; threshold". The price source choice and repair stay in Settings (power under the hood; repair is a money choice). |
| D10 | The wizard and combat | **Never opens by itself in combat or an instance** (W4-21, unchanged); `/swagbag setup` opens at once; **combat starting while it is open: it steps aside** with one line (`WIZ_COMBAT_HIDDEN`) **and comes back at the same step** when combat ends; Finish works in combat (plain frames; the bags follow as after any setting). | Esc. | A 580×360 dialog must not cover a pull; the user loses nothing. |
| D11 | The tour | **Seven notes**: section headers, collapse (and drag onto a header), focus modes and peek, search, the mode title and Pause, Sort, Safe Mode (`/swagbag safe on`). Each note sits next to its part with a thin gold frame around it; a part not drawn (no headers in the grid view) gets its note beside the window. Back, Next (Done on the last), End tour; Esc ends it. It **opens the bags** if they are closed; **refuses in combat** (try again after), in Safe Mode, or when the bags can't open. **Ends with one line** when the bags close or combat starts. | `/swagbag help`, the tooltips. | AC7.3's list; "never blocks play": no modal, nothing over a fight, nothing moved. |
| D12 | The tour offer | **Once, after Finish** (not after Skip, not in combat): a small note "All set. Want a short tour of your bags?..." with **Show me around** / **No thanks**; any other close says `/swagbag tour` works any time. | `/swagbag tour`. | The brief: offered once at the end; V0: never forced. |
| D13 | Where modes of your own live | **`SwagBagDB.modes[id] = { name, trigger, n }`** (schema 2, read defensively, like week 7's `locks`), id `m_<name>` (`_2`, `_3`...), **a deleted one stays `false`** so its id is never given again. Their on/off and sections are **the ordinary settings** `focus.on.<id>`, `focus.sections.<id>` (written when the mode is made). | — | The same mechanics as the built-ins: "This character only", profiles, Reset (Defaults) and the section editor work unchanged. Week 11's id rule (X9). |
| D14 | Triggers | **Only when I switch it on** (default), or one built-in signal: **in a Mythic+ key, in a dungeon, in a raid, in a delve, in a battleground or arena, while fishing, while gathering, at a vendor, at the auction house, at the bank.** | — (combinations of signals: later, with demand). | AC8.7 "manual, or any built-in signal"; spec 6.2's signals that SwagBag reads today (combat and encounter are not wired, spec 6.2). One choice is understandable; the built-in modes already combine. |
| D15 | A manual mode switched on | **For this session**: until switched off, a log out or a reload. `/swagbag mode on <name>`, `/swagbag mode off` (all) or `off <name>`, and the mode's line in Settings > Focus modes ("Switched on" / "Off"). It **does not need "Switch by themselves"** (the user switched it), but **Pause stops it** like every mode. | — | A mode left on by yesterday's farming would surprise; Pause means everything. |
| D16 | Merge and strict priority | **Merge** (default): the union, the title names all ("AH/Vendor/Bank + Sell run"). **Strict priority**: a manual mode you switched on decides first (class `manual`), then combat > activity > location (a signal mode takes its signal's class: a vendor, the auction house and the bank are location, the rest activity); within a class SwagBag's own modes first, then yours in the order you made them. | — | AC8.4 unchanged for the built-ins; a mode you just switched on yourself is what you want to see. |
| D17 | Names and how many | **1–24 characters**, trimmed, no `|` or control character, **not a built-in mode's name or id in any case** ("Raid", "mplus", "ah/vendor/bank"), not another of yours in any case; **at most 10** modes of your own. | Rename any time. | `/swagbag mode on <name>` must find exactly one mode; spec 6.5's budget (≈30 modes). |
| D18 | Delete | **Your own modes only, and it asks once more** ("Delete: sure?"; any other click on the page forgets the question). It removes the mode, its switch and its sections (the account's and this character's own) and switches it off; its id stays taken. | A built-in mode is switched Off, never deleted. | Week 7's Unlock-all pattern and week 11's Delete. |
| D19 | Share strings and modes of your own | **They do not travel this week.** An export leaves them out and its answer names them (`PROFILE_EXPORT_MODES`); an import skips `m.` entries and `focus.*.m_*` settings as unknown entries (named as skipped in the preview) and never makes a mode; an import keeps your modes' sections. | v1.1: carry them with the same rules as categories (a fresh id when taken, "(2)" names: AC20.4) and validate trigger and name. | Carrying them safely needs the categories' id remapping and its own validation and preview lines: a week of its own. Saying so is honest and costs one line. |
| D20 | Week-11 deferred polish | **One item:** the import preview's "Ranked just below Junk" line names a category by the name it comes in under ("Mine (2)"), as the "Added as new" line does. Everything else stays deferred (see "Carry-overs"). | — | The brief: only if cheap and user-visible. |
| D21 | Version | `0.12.0` (Task 1). | — | — |
| D22 | The user's principle (V0) | **Simple out of the box, power under the hood.** See Global Constraints. | — | The user, 2026-10-04 (ruling V0). |

## What the week relies on

| What | Name | Since | Confidence |
|---|---|---|---|
| Plain dialog frames, buttons and text | `CreateFrame("Frame", name, UIParent, "BackdropTemplate")`, `UIPanelButtonTemplate`, `LockHighlight`/`UnlockHighlight`, `SetShown`, `UISpecialFrames` (Esc) | week 4 (the quick setup), week 6 (settings) | Unchanged templates; the wizard's two-column step 2 and the tour's note placement: W1, W4. |
| The bags window's parts | `SB.SectionHeaders.inUse` (each header's `GetParent()` is the child it was acquired in), `SB.SearchBox.editBox`, `W.modeButton`, `W.sortButton`, `W.frame`, `W.Open`, `W.IsOpen` | weeks 1–6 | Read only. That the note lands next to each part and stays on screen: W4. |
| The bags closing, laid out | `SB_BAGS_CLOSED` (the window's `OnHide`), `SB_BAGS_LAYOUT` (after every full layout) | weeks 1, 3 | Internal events, tested since. |
| Combat starts / ends | `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` | weeks 11 / 1 | Hiding a plain frame in combat is allowed: W5, W6. |
| The look | `SB.Theme.order`, `Name`, `Available`, `Apply(id, save)` | week 5 | Tested since; the wizard applying it live: W2. |
| Where prices come from | `SB.Prices.Source()`, `SourceText()` | weeks 2, 9 | Tested since; the wizard's line with Auctionator or TSM loaded: W3. |
| Focus signals | `Engine/Signals.lua` (`challengeMode`, `instanceType`, `delve`, `fishing`, `gathering`, `merchantOpen`, `auctionOpen`, `bankOpen`) | week 4 | Each confirmed in game for the built-in modes (sessions V5–V11); a mode of your own reads the same values: W8. |

## Needs in-game confirmation (what could not be verified at the desk)

Each item names the session step that checks it. None blocks the build; a wrong answer comes back as a fix.

| # | What | Why it is uncertain | Checked in |
|---|---|---|---|
| W1 | The wizard's four steps are readable: the step-2 lines fit their 270-pixel buttons in two columns, the gold buttons fit, nothing overlaps | Text widths come from the client; the fakes have none | WZ1 steps 5–12 |
| W2 | Finish applies at once: slots per row and Trade Goods / BoE gear near the top in the open bags; the look if changed | The layout after `FollowSettings` is tested, the wizard's call into it is not drawn | WZ1 step 13 |
| W3 | Step 4's line names the price addon the user has (Auctionator, TSM) or says vendor prices | Which providers answer depends on the user's addons | WZ1 step 11 |
| W4 | The tour's notes sit next to their parts, on screen, readable, with the gold frame around each part; scrolling the bags does not leave the note pointing at nothing important | Anchor positions and the bags' scroll are not modelled | WZ1 steps 14–17 |
| W5 | The tour ends at once when combat starts, and the ability key works | Event order in a pull is not modelled | WZ1 step 20 |
| W6 | The wizard steps aside when combat starts and comes back after | As W5 | WZ1 steps 22–24 |
| W7 | A mode of your own, switched on by hand, brings its sections to the top and the title names it; off puts them back | The re-stack is the built-ins', the custom trigger is new | WZ1 steps 31–33 |
| W8 | A mode of your own set to "At a vendor" switches on at a vendor together with AH/Vendor/Bank | The merchant signal is the built-in's (V-checks), the merge with a mode of your own is new | WZ1 step 35 |
| W9 | Esc during the tour closes the note and the bags and says one line | Esc closes every `UISpecialFrames` window; which hides first is the client's | WZ1 step 19 |

## Carry-overs: what this week takes, and what stays deferred

Taken (D20): the import preview's lowered-priority line names a category by the name it comes in under (week-11 final review minor "LOWERED preview line uses original name").

Triaged and left deferred (not user-visible, test-only, rare, or needing an in-game look first):
- week-11 Task 1: `ToText` errors on malformed rules (callers pass well-formed rules; `Problem` guards the editor); the fuzz reference shares `rowText` (test-only);
- week-11 Task 2: an import can overwrite a deleted id's tombstone (the final fix's fresh-id rule covers live ids and tombstones for imports since; rare); profile snapshots keep deleted ids (the preview shows the raw id; rare); a leftover draft on a second broken save; `Preview`'s `pcall` drops the error; `enabled` coerced; the name limit counts bytes (no user-visible case in English);
- week-11 Task 3: a turned-off broken category opens as On (fixing it needs to know whether `enabled = false` was the user's or the build's: not cheap); the Apply button wraps after a full-width box (cosmetic, needs an in-game look); the preview compiles twice (cost only); the remaining test-only items;
- week-11 Task 4: the `MAX_NOTES` cap untested; an oversized gold amount in a range passes as a NAME note; SwagBag-only syntax passes without a note (rare, harmless);
- week-11 final review: the `co` remap can move a user category to the end; `ce` edits replace built-in edits wholesale; an imported built-in rename can duplicate a user name; long unclaimed imported names kept; a settings-only Undo may restore stale focus refs (harmless);
- the week-10 and earlier items listed as deferred in the week-11 plan, unchanged; the week-6 bank-speed part 2 still waits on session TF1's numbers.

Session CE1 (week 11) and the earlier open checks are unchanged by this plan.

---

## File structure (end of week 12)

New and changed files only. Everything else is as on `8503e06`.

```
SwagBag/Engine/Setup.lua               NEW  (T1) the wizard's draft: STYLES, Preset (AC9.2), Order, New, Toggle, Value,
                                            Set, Switches, Label, Plan, Finish, Skip
SwagBag/UI/QuickSetup.lua              MOD  (T2) the four-step wizard (given whole); (T3) the tour offer after Finish,
                                            /swagbag tour moves out
SwagBag/UI/Tour.lua                    NEW  (T3) the guided tour: Start, Next, Back, End; /swagbag tour
SwagBag/Engine/Focus.lua               MOD  (T4) modes of your own: TRIGGERS, custom, All, Mode, NameOf, FindMode,
                                            CheckName, CreateMode, RenameMode, SetTrigger, DeleteMode, SetManual,
                                            LoadCustom; /swagbag mode on|off; list, label and priority include them
SwagBag/Engine/Categories.lua          MOD  (T4) Delete cleans every mode's sections, yours included
SwagBag/UI/SettingsFocus.lua           MOD  (T5) New mode, a manual mode's line, editing and deleting your modes
SwagBag/Engine/Profiles.lua            MOD  (T5) the export answer names your modes as left out; the lowered line's name
SwagBag/Core/Config.lua                MOD  (T1) setup.styles
SwagBag/Locale/enUS.lua                MOD  (T1, T2, T3, T4, T5)
SwagBag/SwagBag.toc                    MOD  (T1) Setup, 0.12.0; (T3) Tour
SwagBag/Core/Init.lua                  MOD  (T1) 0.12.0
spec/setup_spec.lua (T1), tour_spec.lua (T3), focus_custom_spec.lua (T4), settings_focus_custom_spec.lua (T5)   NEW
spec/quicksetup_spec.lua (T2, T3), theme_spec.lua (T2: one line)                                                    MOD
```

`TOC OK (80 files)` after Tasks 1 and 2, `81` after Tasks 3 to 5.

## Schedule (week 12)

In priority order, so the earlier items ship first if time runs out. Nothing this week depends on 12.1.5 (live 2026-10-13); session WZ1 runs on either.

| Day | Tasks | User in game? |
|---|---|---|
| 1 | 1, 2 | — |
| 2 | 3, 4, 5 | after the merge: session WZ1 (the wizard, the tour, a mode of your own, about 40 minutes) |
| 3 | final review, fixes | **Week 12 exit check** |

Cumulative `scripts/check.sh` test totals (from 1614 on `8503e06`). Each was produced by replaying this file's blocks in order on a fresh clone of `8503e06`:
- T1 1627 passed, 0 failed (+13)
- T2 1631 passed, 0 failed (+4)
- T3 1642 passed, 0 failed (+11)
- T4 1655 passed, 0 failed (+13)
- T5 1663 passed, 0 failed (+8)

## How to read the code steps

- A **Create** step gives a complete new file.
- A **Replace the whole of** step gives a complete existing file, as it is after the step. It is used once this week, for `SwagBag/UI/QuickSetup.lua` in Task 2: the one-screen quick setup becomes the four-step wizard and more than two thirds of the file changes, so a whole file is easier to check than forty blocks.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point and its replacement. The block occurs exactly once in the file as it is, and starts and ends on a non-blank line. When a step edits one file in several places, the places are numbered "(edit N of M)". Apply them in that order, top to bottom. Each find block is unique in the file as it is after the earlier edits.
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks (everything else). Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists its critical tests and, for each, the code change (mutation) that must make it fail. Every mutation was applied to the finished code of its task and the named test failed. A reviewer re-runs any of them with a one-line edit. In a mutation, ` ⏎ ` marks a line break and `∅` an empty replacement; leading tabs are left out.
- A test that passes at Step 2 is named there with the reason.

---

### Task 1: The setup draft and the playstyle overlays (Engine/Setup.lua); v0.12.0

The engine under the wizard. `Setup.New()` makes a draft pre-filled from the settings as they are: the styles picked at the last Finish (`setup.styles`, a new key under `setup`, this machine's state like `setup.done`, never in a profile or share string) and every value as set now. `Setup.Value(d, key)` is what the wizard shows: the user's own choice in this run, else what a picked style sets, else the setting now. `Setup.Preset` is the quick setup's preset table with AC9.2 added (D6): M+ and Raid make the gear marks explicit, Gold the junk coin (and the gold glow when it is off), Collector the collection marks. `Setup.Switches` is step 2's list (D5); `Setup.Plan` is exactly what Finish writes: every setting a picked style sets, as an explicit value even when it equals today's default, and every other value this run changed, nothing else (Config keeps only explicit values). `Setup.Finish` writes the plan, moves the picked styles' categories up (`Setup.Order`, the quick setup's), remembers the styles, marks setup done, then lets the windows follow under `ErrorTrap` (`SB.FollowSettings`, the look, the open bags' size); `Setup.Skip` writes only `setup.done` (AC7.2). Nothing here draws anything; the quick setup screen is untouched until Task 2. The version goes to 0.12.0.

**Files:**
- Create: `SwagBag/Engine/Setup.lua`, `spec/setup_spec.lua`
- Modify: `SwagBag/Core/Config.lua` (`setup.styles`), `SwagBag/Locale/enUS.lua` (the step-2 switch names, `WIZ_DONE_NONE`), `SwagBag/SwagBag.toc` (the new file after `Engine/Profiles.lua`; 0.12.0), `SwagBag/Core/Init.lua` (0.12.0)

**Interfaces:**
- Consumes: `SB.Config.Get/Set/db/readOnly`, `SB.Categories.display/SectionOrder`, `SB.Focus.MODES/byId`, `SB.Profiles.CategoriesChanged` (when loaded), `SB.FollowSettings`, `SB.Theme.Apply` (when loaded), `SB.BagsWindow.IsOpen/SetScale` (when present), `SB.ErrorTrap.Run`.
- Produces: `SB.Setup` with `STYLES`, `Preset(picked, get) -> { { path, value } }`, `Order(display, promote) -> order | nil`, `New() -> draft`, `Toggle(d, style)`, `Value(d, key)`, `Set(d, key, value)`, `Switches(d) -> { key }`, `Label(key) -> text`, `Plan(d) -> { { path, value } }`, `Finish(d) -> feedback`, `Skip() -> feedback`; the draft `{ styles = { [id] = true }, touched = { [key] = value } }`; the keys `"order.gold"` and `"order.collector"`; the setting `setup.styles`; `L.WIZ_SW_*`, `L.WIZ_DONE_NONE`; `SB.VERSION = "0.12.0"`.

- [ ] **Step 1: Write the failing tests**

Create `spec/setup_spec.lua`:

```lua
-- Week 12 (spec F7: AC7.1, AC7.2; AC9.2): the setup wizard's draft and what Finish writes (Engine/Setup.lua).
-- Nothing is written before Finish; a picked style's settings are written as explicit values; nothing else is.
local Loader = dofile("spec/helpers/loader.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Setup wizard: the draft and Finish (week 12)", function()
	local SB, S, C, bags
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Setup.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		SB.Categories.Load()
		S, C = SB.Setup, SB.Config
		bags = { layouts = 0, open = false, scales = {} }
		function bags.IsOpen() return bags.open end
		function bags.RequestLayout() bags.layouts = bags.layouts + 1 end
		function bags.RefreshTitle() end
		function bags.SetScale(v, quiet) bags.scales[#bags.scales + 1] = { v, quiet } end
		SB.BagsWindow = bags
	end)

	local function keys(t)
		local out = {}
		for k in pairs(t or {}) do
			out[#out + 1] = k
		end
		table.sort(out)
		return out
	end

	-- AC9.2. Mutations: in Setup.Preset, drop `set("overlays.upgrade", true)` from the M+ block; or drop the Collector
	-- block's `set("overlays.learn", true)`.
	it("AC9.2: each playstyle sets its overlays; Casual alone switches the warning and the track off", function()
		assert.same({ { "focus.on.mplus", true }, { "consumables.warn", true }, { "overlays.keystone", true },
			{ "overlays.track", true }, { "overlays.upgrade", true }, { "overlays.ilvl", true } }, S.Preset({ mplus = true }))
		assert.same({ { "focus.on.raid", true }, { "consumables.warn", true }, { "overlays.upgrade", true },
			{ "overlays.ilvl", true }, { "overlays.track", true } }, S.Preset({ raid = true }))
		assert.same({ { "prices.headerTotals", true }, { "overlays.junk", true } }, S.Preset({ gold = true }))
		assert.same({ { "overlays.uncollected", true }, { "overlays.learn", true } }, S.Preset({ collector = true }))
		assert.same({ { "consumables.warn", false }, { "overlays.track", false } }, S.Preset({ casual = true }))
		assert.same(S.Preset({ mplus = true }), S.Preset({ mplus = true, casual = true }))
	end)

	-- Mutation: in Setup.Preset, `if get and get("prices.worth") == "off" then` -> `if get then`.
	it("Gold switches the gold glow on only when it is off; a glow the user set stays", function()
		assert.same({ { "prices.headerTotals", true }, { "overlays.junk", true } }, S.Preset({ gold = true }, C.Get))
		C.Set("prices.worth", "off")
		assert.same({ { "prices.headerTotals", true }, { "overlays.junk", true }, { "prices.worth", "fixed" } },
			S.Preset({ gold = true }, C.Get))
		C.Set("prices.worth", "top")
		local d = S.New()
		S.Toggle(d, "gold")
		assert.equal("top", S.Value(d, "prices.worth"))
	end)

	it("Gold moves Trade Goods and BoE gear up after Keystone & Crests; Collector moves the collectibles", function()
		local display = { "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_collect", "c_other" }
		assert.same({ "c_keystone", "c_tradegoods", "c_boe", "c_collect", "c_consumables", "c_gear", "c_other" },
			S.Order(display, { gold = true, collector = true }))
		assert.is_nil(S.Order(display, { mplus = true }))
		assert.is_nil(S.Order(display, { gold = false }))
	end)

	-- AC7.4 (a re-run starts from the settings as they are). Mutation: in Setup.New, drop the `if STYLE[id] then` check
	-- (a damaged or unknown word becomes a picked style).
	it("a new draft starts from the styles picked last time and every setting as it is now", function()
		local d = S.New()
		assert.same({}, d.styles)
		assert.equal(12, S.Value(d, "bags.columns"))
		C.Set("setup.styles", "gold,nonsense,mplus")
		C.Set("bags.columns", 14)
		d = S.New()
		assert.same({ gold = true, mplus = true }, d.styles)
		assert.equal(14, S.Value(d, "bags.columns"))
		C.Set("setup.styles", 7)
		assert.same({}, S.New().styles, "a damaged value reads as nothing picked")
	end)

	-- Mutation: in Setup.Value, drop the `if d.touched[key] ~= nil then` branch (the user's switch would be lost).
	it("what the wizard shows: the user's choice, else what a picked style sets, else the setting now", function()
		C.Set("overlays.track", false)
		local d = S.New()
		assert.equal(false, S.Value(d, "overlays.track"))
		S.Toggle(d, "mplus")
		assert.equal(true, S.Value(d, "overlays.track"), "M+ switches the track on")
		S.Set(d, "overlays.track", false)
		assert.equal(false, S.Value(d, "overlays.track"), "the user switched it off again")
		S.Toggle(d, "mplus")
		assert.equal(false, S.Value(d, "overlays.track"))
		assert.is_nil(d.styles.mplus)
		assert.equal(true, S.Value(d, "focus.on.mplus"), "unpicked: back to the setting now")
	end)

	-- Mutation: in Setup.Switches, drop the loop over Focus.MODES.
	it("step 2 lists the six focus modes, then what the picked styles switch, once each, then the categories they move up", function()
		local d = S.New()
		assert.same({ "focus.on.mplus", "focus.on.raid", "focus.on.delves", "focus.on.gathering", "focus.on.fishing",
			"focus.on.market" }, S.Switches(d))
		S.Toggle(d, "raid")
		S.Toggle(d, "gold")
		S.Toggle(d, "collector")
		assert.same({ "focus.on.mplus", "focus.on.raid", "focus.on.delves", "focus.on.gathering", "focus.on.fishing",
			"focus.on.market", "consumables.warn", "overlays.upgrade", "overlays.ilvl", "overlays.track",
			"prices.headerTotals", "overlays.junk", "overlays.uncollected", "overlays.learn", "order.gold",
			"order.collector" }, S.Switches(d))
		assert.equal("Raid mode", S.Label("focus.on.raid"))
		assert.equal(SB.L.WIZ_SW_ORDER_GOLD, S.Label("order.gold"))
		for _, key in ipairs(S.Switches(d)) do
			assert.truthy(S.Label(key) ~= key, "no words for " .. key)
		end
	end)

	-- Config keeps only explicit values. Mutation: in Setup.Plan, `if preset[key] ~= nil or v ~= get(key) then` ->
	-- `if v ~= get(key) then` (a picked style's settings, equal to the defaults, would not be written).
	it("the plan: a picked style's settings, written even when they equal the default; other values only if changed", function()
		local d = S.New()
		assert.same({}, S.Plan(d))
		S.Toggle(d, "collector")
		S.Set(d, "bags.columns", 12)
		S.Set(d, "bags.scale", 1.1)
		S.Set(d, "focus.on.fishing", false)
		assert.same({ { "bags.scale", 1.1 }, { "focus.on.fishing", false }, { "overlays.learn", true },
			{ "overlays.uncollected", true } }, S.Plan(d))
		S.Set(d, "order.collector", false)
		assert.same(4, #S.Plan(d), "the order switch is no setting")
	end)

	-- Mutations: in Setup.Finish, drop the `C.Set("setup.styles", styles)` write; or drop `C.Set("setup.done", true)`.
	it("Finish writes the plan, moves the picked styles' categories up, remembers the styles, and the bags follow", function()
		local d = S.New()
		S.Toggle(d, "mplus")
		S.Toggle(d, "gold")
		S.Set(d, "bags.columns", 14)
		bags.open = true
		assert.equal("Set up for M+, Gold-making. Change anything later: type /swagbag.", S.Finish(d))
		assert.equal(true, C.Get("setup.done"))
		assert.equal("mplus,gold", C.Get("setup.styles"))
		assert.equal(14, C.Get("bags.columns"))
		assert.same({ "bags", "consumables", "focus", "overlays", "prices", "setup" }, keys(C.db.settings))
		assert.same({ "ilvl", "junk", "keystone", "track", "upgrade" }, keys(C.db.settings.overlays))
		assert.same({ "headerTotals" }, keys(C.db.settings.prices))
		assert.same({ "c_keystone", "c_tradegoods", "c_boe" },
			{ C.db.categoryOrder[1], C.db.categoryOrder[2], C.db.categoryOrder[3] })
		assert.equal("c_tradegoods", SB.Categories.SectionOrder()[3], "the categories follow at once")
		assert.equal(1, bags.layouts, "the open bags regroup")
		assert.same({}, bags.scales, "the size did not change")
	end)

	-- Mutation: in Setup.Finish, `promote[o.style] = d.styles[o.style] == true and Setup.Value(d, o.key) == true` ->
	-- `promote[o.style] = d.styles[o.style] == true`.
	it("a category switch turned off on step 2 leaves the order as it is", function()
		local d = S.New()
		S.Toggle(d, "gold")
		S.Set(d, "order.gold", false)
		S.Finish(d)
		assert.is_nil(C.db.categoryOrder)
		assert.equal(true, C.Get("prices.headerTotals"))
	end)

	it("Finish with no style picked writes only what was changed, and says so", function()
		local d = S.New()
		S.Set(d, "bags.scale", 1.25)
		bags.open = true
		assert.equal(SB.L.WIZ_DONE_NONE, S.Finish(d))
		assert.same({ "bags", "setup" }, keys(C.db.settings))
		assert.same({ "scale" }, keys(C.db.settings.bags))
		assert.same({ "done" }, keys(C.db.settings.setup))
		assert.same({ { 1.25, true } }, bags.scales, "the open bags take the new size, quietly")
	end)

	-- Mutation: in Setup.Finish, move the readOnly check below the plan's writes.
	it("read-only settings: Finish and Skip refuse with the reason and write nothing", function()
		local d = S.New()
		S.Toggle(d, "gold")
		S.Set(d, "bags.columns", 16)
		C.readOnly = true
		assert.equal(SB.L.SETTINGS_READONLY, S.Finish(d))
		assert.equal(SB.L.SETTINGS_READONLY, S.Skip())
		C.readOnly = false
		assert.same({}, keys(C.db.settings))
		assert.is_nil(C.db.categoryOrder)
	end)

	-- AC7.2. Mutation: make Skip always answer with L.QS_SKIPPED.
	it("AC7.2: Skip writes only that setup is done, and says the defaults (or your settings) are kept", function()
		assert.equal(SB.L.QS_SKIPPED, S.Skip())
		assert.same({ "setup" }, keys(C.db.settings))
		assert.equal(SB.L.QS_SKIPPED_KEPT, S.Skip())
	end)

	-- Mutation: run follow() bare in Finish (no ErrorTrap.Run).
	it("a refresh error after Finish still says the settings were saved, with a note, and never trips Safe Mode", function()
		local d = S.New()
		S.Toggle(d, "raid")
		bags.open = true
		function bags.RequestLayout() error("layout boom") end
		assert.equal(SB.L.QS_APPLIED:format("Raid") .. " " .. SB.L.QS_REFRESH_NOTE, S.Finish(d))
		assert.equal(true, C.Get("setup.done"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)
end)
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1614 passed, 13 failed`. The failures, exactly:

- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > AC9.2: each playstyle sets its overlays; Casual alone switches the warning and the track off`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > Gold switches the gold glow on only when it is off; a glow the user set stays`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > Gold moves Trade Goods and BoE gear up after Keystone & Crests; Collector moves the collectibles`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > a new draft starts from the styles picked last time and every setting as it is now`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > what the wizard shows: the user's choice, else what a picked style sets, else the setting now`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > step 2 lists the six focus modes, then what the picked styles switch, once each, then the categories they move up`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > the plan: a picked style's settings, written even when they equal the default; other values only if changed`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > Finish writes the plan, moves the picked styles' categories up, remembers the styles, and the bags follow`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > a category switch turned off on step 2 leaves the order as it is`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > Finish with no style picked writes only what was changed, and says so`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > read-only settings: Finish and Skip refuse with the reason and write nothing`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > AC7.2: Skip writes only that setup is done, and says the defaults (or your settings) are kept`
- `spec/setup_spec.lua :: Setup wizard: the draft and Finish (week 12) > a refresh error after Finish still says the settings were saved, with a note, and never trips Safe Mode`

All thirteen fail in `before_each`, which loads `SwagBag/Engine/Setup.lua`: it does not exist yet.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "AC9.2: each playstyle sets its overlays; Casual alone switches the warning and the track off": in `SwagBag/Engine/Setup.lua`, `set("overlays.learn", true)` → `set("overlays.learn", false)`.
- "Gold switches the gold glow on only when it is off; a glow the user set stays": in `SwagBag/Engine/Setup.lua`, `if get and get("prices.worth") == "off" then` → `if get then`.
- "Gold moves Trade Goods and BoE gear up after Keystone & Crests; Collector moves the collectibles": in `SwagBag/Engine/Setup.lua`, `if id == "c_keystone" then` → `if id == "c_gear" then`.
- "a new draft starts from the styles picked last time and every setting as it is now": in `SwagBag/Engine/Setup.lua`, `if STYLE[id] then` → `if true then`.
- "what the wizard shows: the user's choice, else what a picked style sets, else the setting now": in `SwagBag/Engine/Setup.lua`, `if d.touched[key] ~= nil then` → `if false then`.
- "step 2 lists the six focus modes, then what the picked styles switch, once each, then the categories they move up": in `SwagBag/Engine/Setup.lua`, `for _, m in ipairs(SB.Focus and SB.Focus.MODES or {}) do` → `for _, m in ipairs({}) do`.
- "the plan: a picked style's settings, written even when they equal the default; other values only if changed": in `SwagBag/Engine/Setup.lua`, `if preset[key] ~= nil or v ~= get(key) then` → `if v ~= get(key) then`.
- "Finish writes the plan, moves the picked styles' categories up, remembers the styles, and the bags follow": in `SwagBag/Engine/Setup.lua`, `C.Set("setup.styles", styles)` → ∅.
- "Finish writes the plan, moves the picked styles' categories up, remembers the styles, and the bags follow": in `SwagBag/Engine/Setup.lua`, `C.Set("setup.done", true)` → ∅.
- "a category switch turned off on step 2 leaves the order as it is": in `SwagBag/Engine/Setup.lua`, `promote[o.style] = d.styles[o.style] == true and Setup.Value(d, o.key) == true` → `promote[o.style] = d.styles[o.style] == true`.
- "Finish with no style picked writes only what was changed, and says so": in `SwagBag/Engine/Setup.lua`, `if scale and W and W.SetScale and W.IsOpen and W.IsOpen() then` → `if false then`.
- "read-only settings: Finish and Skip refuse with the reason and write nothing": in `SwagBag/Engine/Setup.lua`, `if C.readOnly then` → `if false then`.
- "AC7.2: Skip writes only that setup is done, and says the defaults (or your settings) are kept": in `SwagBag/Engine/Setup.lua`, `return rerun and L.QS_SKIPPED_KEPT or L.QS_SKIPPED` → `return L.QS_SKIPPED`.
- "a refresh error after Finish still says the settings were saved, with a note, and never trips Safe Mode": in `SwagBag/Engine/Setup.lua`, `local refreshed = SB.ErrorTrap.Run("setup.refresh", "none", follow, look, scale)` → `local refreshed = follow(look, scale) or true`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Config.lua`, find:

```lua
		-- done: the quick setup screen was applied or skipped (UI/QuickSetup.lua); account-wide,
		-- like the settings it sets, so it shows once per account, not once per character.
		setup = { done = false },
```

and replace it with:

```lua
		-- done: the setup wizard was finished or skipped (UI/QuickSetup.lua); account-wide,
		-- like the settings it sets, so it shows once per account, not once per character.
		-- styles (week 12): the playstyles picked at the last Finish ("mplus,gold"), so /swagbag setup starts from
		-- them. This machine's state, like done: never in a profile or a share string (Engine/Profiles.lua KEEP).
		setup = { done = false, styles = "" },
```

In `SwagBag/Core/Init.lua`, find:

```lua
SB.VERSION = "0.11.0"
```

and replace it with:

```lua
SB.VERSION = "0.12.0"
```

Create `SwagBag/Engine/Setup.lua`:

```lua
-- SwagBag setup (spec F7: AC7.1, AC7.2; AC9.2; week 12): what the setup wizard picks, kept as a draft in memory, and
-- what Finish writes. No frames: UI/QuickSetup.lua draws the four steps and calls these.
--   Setup.STYLES                              the five playstyles, in the wizard's order
--   Setup.Preset(picked, get) -> { { path, value } }   what each picked style sets (AC9.2: its overlays too); get
--                                             (optional, Config.Get) lets Gold switch the gold glow on only when it is off
--   Setup.Order(display, promote) -> order | nil       the category order with the promoted styles' categories
--                                             moved up, right after Keystone & Crests (spec 7.6)
--   Setup.New() -> draft                      pre-filled: the styles picked last time (setup.styles), every value as set now
--   Setup.Toggle(d, style)                    pick or unpick a style
--   Setup.Value(d, key) -> value              what the wizard shows: the user's own choice in this run, else what a
--                                             picked style sets, else the setting now ("order.gold" and
--                                             "order.collector": the picked style's categories move up)
--   Setup.Set(d, key, value)                  a choice on steps 2 to 4
--   Setup.Switches(d) -> { key }              step 2's on/off lines: the six focus modes, what the picked styles set,
--                                             then the categories they move up
--   Setup.Label(key) -> text                  a switch's name in plain words
--   Setup.Plan(d) -> { { path, value } }      what Finish writes, by path: every setting a picked style sets (an
--                                             explicit value, AC9.2) and every other one this run changed; nothing else
--                                             (Config keeps only the values somebody chose)
--   Setup.Finish(d) -> feedback               writes the plan, the category order, setup.styles and setup.done, then the
--                                             windows follow; refuses while read-only, writing nothing
--   Setup.Skip() -> feedback                  only setup.done (AC7.2: the defaults, or the settings as they are)
-- Nothing is written before Finish: Back and Next are free, and closing the wizard keeps everything as it was.
local _, SB = ...

local L = SB.L
local Setup = {}
SB.Setup = Setup

Setup.STYLES = {
	{ id = "mplus", name = "QS_MPLUS" }, { id = "raid", name = "QS_RAID" }, { id = "gold", name = "QS_GOLD" },
	{ id = "casual", name = "QS_CASUAL" }, { id = "collector", name = "QS_COLLECTOR" },
}
local STYLE = {}
for _, s in ipairs(Setup.STYLES) do
	STYLE[s.id] = s
end

-- Categories a style moves up, right after Keystone & Crests (spec 7.6: "Gold promotes Trade Goods and BoE gear").
local PROMOTE = { gold = { "c_tradegoods", "c_boe" }, collector = { "c_collect" } }
local ORDER_KEYS = { { key = "order.gold", style = "gold" }, { key = "order.collector", style = "collector" } }

-- Pure: the settings each style sets. Every style only switches things on, except Casual on its own, which switches
-- the consumables warning and the upgrade track off. Week 12 (AC9.2): M+ and Raid make the gear marks explicit,
-- Gold the junk coin (and the gold glow when it is off), Collector the collection marks.
function Setup.Preset(picked, get)
	local out = {}
	local function set(path, value)
		out[#out + 1] = { path, value }
	end
	if picked.mplus then
		set("focus.on.mplus", true)
		set("consumables.warn", true)
		set("overlays.keystone", true)
		set("overlays.track", true)
		set("overlays.upgrade", true)
		set("overlays.ilvl", true)
	end
	if picked.raid then
		set("focus.on.raid", true)
		set("consumables.warn", true)
		set("overlays.upgrade", true)
		set("overlays.ilvl", true)
		set("overlays.track", true)
	end
	if picked.gold then
		set("prices.headerTotals", true)
		set("overlays.junk", true)
		if get and get("prices.worth") == "off" then
			set("prices.worth", "fixed") -- a glow the user set (an amount, or the top %) stays as it is
		end
	end
	if picked.casual and not picked.mplus and not picked.raid then
		set("consumables.warn", false)
		set("overlays.track", false)
	end
	if picked.collector then
		set("overlays.uncollected", true)
		set("overlays.learn", true)
	end
	return out
end

-- Pure: the display order with the promoted styles' categories moved up, or nil when none moves.
function Setup.Order(display, promote)
	local up = {}
	for _, s in ipairs(Setup.STYLES) do
		for _, id in ipairs(promote[s.id] and PROMOTE[s.id] or {}) do
			up[#up + 1] = id
		end
	end
	if #up == 0 then
		return nil
	end
	local moved, out = {}, {}
	for _, id in ipairs(up) do
		moved[id] = true
	end
	for _, id in ipairs(display) do
		if not moved[id] then
			out[#out + 1] = id
			if id == "c_keystone" then
				for _, u in ipairs(up) do
					out[#out + 1] = u
				end
			end
		end
	end
	return out
end

local function get(path)
	return SB.Config.Get(path)
end

function Setup.New()
	local d = { styles = {}, touched = {} }
	local saved = get("setup.styles")
	if type(saved) == "string" then
		for id in saved:gmatch("[^,]+") do
			if STYLE[id] then
				d.styles[id] = true
			end
		end
	end
	return d
end

function Setup.Toggle(d, style)
	if STYLE[style] then
		d.styles[style] = not d.styles[style] or nil
	end
end

local function presetMap(d)
	local map = {}
	for _, p in ipairs(Setup.Preset(d.styles, get)) do
		map[p[1]] = p[2]
	end
	return map
end

function Setup.Value(d, key)
	if d.touched[key] ~= nil then
		return d.touched[key]
	end
	for _, o in ipairs(ORDER_KEYS) do
		if o.key == key then
			return d.styles[o.style] == true
		end
	end
	local preset = presetMap(d)[key]
	if preset ~= nil then
		return preset
	end
	return get(key)
end

function Setup.Set(d, key, value)
	d.touched[key] = value
end

function Setup.Switches(d)
	local out, seen = {}, {}
	local function add(key)
		if not seen[key] then
			seen[key] = true
			out[#out + 1] = key
		end
	end
	for _, m in ipairs(SB.Focus and SB.Focus.MODES or {}) do
		add("focus.on." .. m.id)
	end
	for _, p in ipairs(Setup.Preset(d.styles, get)) do
		if type(p[2]) == "boolean" then
			add(p[1])
		end
	end
	for _, o in ipairs(ORDER_KEYS) do
		if d.styles[o.style] then
			add(o.key)
		end
	end
	return out
end

local LABELS = {
	["consumables.warn"] = "WIZ_SW_WARN", ["overlays.keystone"] = "WIZ_SW_KEYSTONE", ["overlays.track"] = "WIZ_SW_TRACK",
	["overlays.upgrade"] = "WIZ_SW_UPGRADE", ["overlays.ilvl"] = "WIZ_SW_ILVL", ["prices.headerTotals"] = "WIZ_SW_TOTALS",
	["overlays.junk"] = "WIZ_SW_JUNK", ["overlays.uncollected"] = "WIZ_SW_UNCOLLECTED", ["overlays.learn"] = "WIZ_SW_LEARN",
	["order.gold"] = "WIZ_SW_ORDER_GOLD", ["order.collector"] = "WIZ_SW_ORDER_COLLECTOR",
}

function Setup.Label(key)
	local mode = key:match("^focus%.on%.(.+)$")
	local m = mode and SB.Focus and SB.Focus.byId[mode]
	if m then
		return L.WIZ_SW_MODE:format(L[m.name])
	end
	return LABELS[key] and L[LABELS[key]] or key
end

function Setup.Plan(d)
	local preset, keys, seen = presetMap(d), {}, {}
	local function add(key)
		if not seen[key] and not key:match("^order%.") then
			seen[key] = true
			keys[#keys + 1] = key
		end
	end
	for key in pairs(preset) do
		add(key)
	end
	for key in pairs(d.touched) do
		add(key)
	end
	table.sort(keys)
	local out = {}
	for _, key in ipairs(keys) do
		local v = Setup.Value(d, key)
		if preset[key] ~= nil or v ~= get(key) then
			out[#out + 1] = { key, v }
		end
	end
	return out
end

local function names(picked)
	local out = {}
	for _, s in ipairs(Setup.STYLES) do
		if picked[s.id] then
			out[#out + 1] = L[s.name]
		end
	end
	return out
end

local function styleList(picked)
	local ids = {}
	for _, s in ipairs(Setup.STYLES) do
		if picked[s.id] then
			ids[#ids + 1] = s.id
		end
	end
	return table.concat(ids, ",")
end

-- The open windows follow at once (SB.FollowSettings, Core/Init.lua; ruling R12), the look and the bags' size too.
local function follow(look, scale)
	if look and SB.Theme and SB.Theme.Apply then
		SB.Theme.Apply(look, false)
	end
	SB.FollowSettings("setup")
	local W = SB.BagsWindow
	if scale and W and W.SetScale and W.IsOpen and W.IsOpen() then
		W.SetScale(scale, true)
	end
end

function Setup.Finish(d)
	local C = SB.Config
	if C.readOnly then
		return L.SETTINGS_READONLY
	end
	local look, scale
	for _, p in ipairs(Setup.Plan(d)) do
		C.Set(p[1], p[2])
		if p[1] == "theme.name" then
			look = p[2]
		elseif p[1] == "bags.scale" then
			scale = p[2]
		end
	end
	local promote = {}
	for _, o in ipairs(ORDER_KEYS) do
		promote[o.style] = d.styles[o.style] == true and Setup.Value(d, o.key) == true
	end
	local display = {}
	for _, c in ipairs(SB.Categories.display) do
		display[#display + 1] = c.id
	end
	local order = Setup.Order(display, promote)
	if order then
		C.db.categoryOrder = order
		if SB.Profiles and SB.Profiles.CategoriesChanged then
			SB.Profiles.CategoriesChanged() -- a profile Undo never puts an older order back over this one
		end
	end
	local styles = styleList(d.styles)
	if get("setup.styles") ~= styles then
		C.Set("setup.styles", styles)
	end
	C.Set("setup.done", true)
	-- The settings are saved; a refresh error must not turn that into "failed".
	local refreshed = SB.ErrorTrap.Run("setup.refresh", "none", follow, look, scale)
	local list = names(d.styles)
	local line = #list > 0 and L.QS_APPLIED:format(table.concat(list, ", ")) or L.WIZ_DONE_NONE
	if not refreshed then
		line = line .. " " .. L.QS_REFRESH_NOTE
	end
	return line
end

-- First run: "keeps its defaults". A re-run: "keeps your current settings", since the defaults are no longer what is set.
function Setup.Skip()
	local rerun = get("setup.done") == true
	if not SB.Config.Set("setup.done", true) then
		return L.SETTINGS_READONLY
	end
	return rerun and L.QS_SKIPPED_KEPT or L.QS_SKIPPED
end
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.QS_OPENED = "Quick setup opened."
```

and replace it with:

```lua
L.QS_OPENED = "Quick setup opened."
-- Week 12: the setup wizard's step-2 switches (Engine/Setup.lua) and its Finish with no style picked.
L.WIZ_SW_MODE = "%s mode"
L.WIZ_SW_WARN = "Low-consumables warning"
L.WIZ_SW_KEYSTONE = "Keystone level and dungeon"
L.WIZ_SW_TRACK = "Upgrade track on gear"
L.WIZ_SW_UPGRADE = "Upgrade arrow on gear"
L.WIZ_SW_ILVL = "Item level on gear"
L.WIZ_SW_TOTALS = "Gold totals on section headers"
L.WIZ_SW_JUNK = "Junk coin on gray items"
L.WIZ_SW_UNCOLLECTED = "Star on looks you haven't collected"
L.WIZ_SW_LEARN = "Glow on things to open or learn"
L.WIZ_SW_ORDER_GOLD = "Trade Goods and BoE gear near the top"
L.WIZ_SW_ORDER_COLLECTOR = "Collections near the top"
L.WIZ_DONE_NONE = "SwagBag is set up. Change anything later: type /swagbag."
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
## Version: 0.11.0
```

and replace it with:

```text
## Version: 0.12.0
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
Engine/Profiles.lua
```

and replace it with:

```text
Engine/Profiles.lua
Engine/Setup.lua
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1627 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (80 files)`, `1627 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Config.lua \
	SwagBag/Core/Init.lua \
	SwagBag/Engine/Setup.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	spec/setup_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 12 Task 1: setup draft engine, playstyle overlays (AC9.2); v0.12.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 2: The four-step wizard (UI/QuickSetup.lua)

The quick setup screen becomes the wizard, in place: the same window (`SwagBagQuickSetup`), the same `setup.done`, the same `/swagbag setup` and login timing (D1). Four step panels of plain Buttons and FontStrings, only the current one shown, with "Step N of 4: ..." above them; Back, Next and Skip on every step, Finish on the last. Step 1 is the five styles (and the Pause note, week 6); step 2 the switches of `Setup.Switches`, each a button whose text says the switch and its state; step 3 slots per row, the size and the look (only the looks whose addon is loaded, D8); step 4 where prices come from, the gold glow and selling junk (D9). Every button only changes the draft (`Engine/Setup.lua`) and redraws; Finish and Skip are the only writes, through `Setup.Finish` / `Setup.Skip`, answering in chat and on the status line (P2). A draft is made fresh at every open, so a re-run starts from the settings as they are (AC7.4). When combat starts the wizard steps aside with one line and comes back at the same step when combat ends (D10). `QS.Preset` and `QS.Order` are gone (they are `Setup`'s since Task 1, and their tests moved there).

**Files:**
- Modify: `SwagBag/UI/QuickSetup.lua` (given whole), `SwagBag/Locale/enUS.lua` (the screen's words; the quick setup's `QS_HINT`, `QS_APPLY` and `QS_PICK_FIRST` go; `QS_LATER`, `QS_LATER_KEPT`, `QS_OPENED` and `HELP_SETUP` say "setup"), `spec/quicksetup_spec.lua`, `spec/theme_spec.lua` (its quick setup test loads `Engine/Setup.lua` first)

**Interfaces:**
- Consumes: `SB.Setup` (Task 1), `SB.Prices.Source/SourceText`, `SB.Theme.order/Name/Available/Button/Window/Text`, `SB.Config.Get/readOnly`, `SB.SafeMode.IsOn`, `SB.Adapter.InCombat/InstanceInfo`, `SB.On`, `SB.Debounce`, `SB.Slash.Register`.
- Produces: `SB.QuickSetup` with `frame` (`stepLabel`, `steps[1..4]`, `status`, `prices`, `pauseNote`...), `step`, `STEPS`, `draft`, `Show()`, `Paint()`, `Close(how)`, `IsOpen()`, `TryShow()`, `styleButtons[id]`, `switchButtons[i]` (`.key`), `columnButtons[n]`, `scaleButtons[n]`, `lookButtons[id]`, `worthButtons[v]`, `sellButtons[v]`, `backButton`, `nextButton`, `finishButton`, `skipButton`, `lit[button]` (drawn selected), `COLUMNS`, `SCALES`, `WORTH`, `MAX_SWITCHES = 18`; `L.WIZ_*` (the screen).

- [ ] **Step 1: Write the failing tests**

In `spec/quicksetup_spec.lua` (edit 1 of 13), find:

```lua
-- The quick setup screen (spec 12.1 "one-screen quick setup (playstyle -> preset)"; AC7.2,
-- AC7.4): when it shows, what each style sets, Apply / Skip / later, read-only.
```

and replace it with:

```lua
-- The setup wizard (spec F7: AC7.1, AC7.2, AC7.4; week 12, from the quick setup screen): when it shows, its four
-- steps, Finish / Skip / later, read-only, combat. What each style sets is spec/setup_spec.lua.
```

In `spec/quicksetup_spec.lua` (edit 2 of 13), find:

```lua
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
```

and replace it with:

```lua
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Setup.lua"
		SB = Loader.New(files)
```

In `spec/quicksetup_spec.lua` (edit 3 of 13), find:

```lua
	end

	it("shows a few seconds after the first login; not again once applied or skipped", function()
```

and replace it with:

```lua
	end

	-- Next until the wizard is at step n (week 12).
	local function step(n)
		while QS.step < n do
			Fake.Fire(QS.nextButton, "OnClick")
		end
	end

	local function finishWizard()
		step(4)
		Fake.Fire(QS.finishButton, "OnClick")
	end

	-- The shown step-2 button with this text.
	local function switch(text)
		for _, b in ipairs(QS.switchButtons) do
			if b.shown and b.text == text then
				return b
			end
		end
		error("no switch " .. text)
	end

	it("shows a few seconds after the first login; not again once applied or skipped", function()
```

In `spec/quicksetup_spec.lua` (edit 4 of 13), find:

```lua
	-- Mutation: drop the `not picked.mplus and not picked.raid` guard on Casual.
	it("presets: M+ and Raid switch things on; Casual alone switches the warning and the track off", function()
		assert.same({ { "focus.on.mplus", true }, { "consumables.warn", true }, { "overlays.keystone", true },
			{ "overlays.track", true } }, QS.Preset({ mplus = true }))
		assert.same({ { "consumables.warn", false }, { "overlays.track", false } }, QS.Preset({ casual = true }))
		assert.same(QS.Preset({ mplus = true }), QS.Preset({ mplus = true, casual = true }))
		assert.same({ { "prices.headerTotals", true } }, QS.Preset({ gold = true }))
	end)

	it("Gold moves Trade Goods and BoE gear up after Keystone & Crests; Collector moves the collectibles", function()
		local display = { "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_collect", "c_other" }
		assert.same({ "c_keystone", "c_tradegoods", "c_boe", "c_collect", "c_consumables", "c_gear", "c_other" },
			QS.Order(display, { gold = true, collector = true }))
		assert.is_nil(QS.Order(display, { mplus = true }))
	end)

	it("Apply with nothing picked asks for a pick and stays open", function()
		login()
		Fake.Fire(QS.applyButton, "OnClick")
		assert.truthy(QS.IsOpen())
		assert.equal(SB.L.QS_PICK_FIRST, QS.frame.status.text)
		assert.equal(false, SB.Config.Get("setup.done"))
	end)

	-- Mutation: remove `C.Set("setup.done", true)` from Apply.
	it("Apply sets each picked style's preset and the slots per row, says what it did, and closes", function()
		login()
		pick("mplus")
		pick("gold")
		Fake.Fire(QS.columnButtons[14], "OnClick")
		bags.open = true
		Fake.Fire(QS.applyButton, "OnClick")
```

and replace it with:

```lua
	-- AC7.1 (week 12). Mutation: in QS.Paint, `QS.finishButton:SetShown(QS.step == QS.STEPS)` ->
	-- `QS.finishButton:SetShown(true)`.
	it("AC7.1: four steps, one screen each: Back, Next and Skip on the way, Finish on the last; nothing saved before", function()
		login()
		local seen = {}
		for n = 1, 4 do
			step(n)
			seen[n] = QS.frame.stepLabel.text
			assert.truthy(QS.frame.steps[n].shown, "step " .. n)
			for m = 1, 4 do
				assert.equal(m == n, QS.frame.steps[m].shown == true, "only step " .. n .. " is shown")
			end
			assert.equal(n > 1, QS.backButton.shown, "Back on step " .. n)
			assert.equal(n < 4, QS.nextButton.shown, "Next on step " .. n)
			assert.equal(n == 4, QS.finishButton.shown, "Finish on step " .. n)
			assert.truthy(QS.skipButton.shown, "Skip on step " .. n)
		end
		assert.same({ "Step 1 of 4: What do you play?", "Step 2 of 4: What that turns on",
			"Step 3 of 4: How your bags look", "Step 4 of 4: Gold" }, seen)
		Fake.Fire(QS.backButton, "OnClick")
		assert.equal(3, QS.step)
		assert.same({}, SB.Config.db.settings, "nothing is written before Finish")
		assert.same({}, A.Lines())
	end)

	-- Mutation: remove `C.Set("setup.done", true)` from Setup.Finish.
	it("Finish sets each picked style's preset and the slots per row, says what it did, and closes", function()
		login()
		pick("mplus")
		pick("gold")
		step(3)
		Fake.Fire(QS.columnButtons[14], "OnClick")
		bags.open = true
		finishWizard()
```

In `spec/quicksetup_spec.lua` (edit 5 of 13), find:

```lua
	it("Apply's new category order drops the categories from the profiles' one step of undo", function()
```

and replace it with:

```lua
	it("Finish's new category order drops the categories from the profiles' one step of undo", function()
```

In `spec/quicksetup_spec.lua` (edit 6 of 13), find:

```lua
		pick("gold")
		Fake.Fire(QS.applyButton, "OnClick")
```

and replace it with:

```lua
		pick("gold")
		finishWizard()
```

In `spec/quicksetup_spec.lua` (edit 7 of 13), find:

```lua
	it("read-only settings: Apply and Skip refuse with the reason and change nothing", function()
```

and replace it with:

```lua
	it("read-only settings: Finish and Skip refuse with the reason and change nothing", function()
```

In `spec/quicksetup_spec.lua` (edit 8 of 13), find:

```lua
		SB.Config.readOnly = true
		Fake.Fire(QS.applyButton, "OnClick")
```

and replace it with:

```lua
		SB.Config.readOnly = true
		finishWizard()
```

In `spec/quicksetup_spec.lua` (edit 9 of 13), find:

```lua
	-- Mutation: make refresh() not run under its own ErrorTrap.Run.
	it("a refresh error after a successful Apply still reports success, with a note", function()
```

and replace it with:

```lua
	-- Mutation: make follow() not run under its own ErrorTrap.Run.
	it("a refresh error after a successful Finish still reports success, with a note", function()
```

In `spec/quicksetup_spec.lua` (edit 10 of 13), find:

```lua
		function bags.RequestLayout() error("layout boom") end
		Fake.Fire(QS.applyButton, "OnClick")
```

and replace it with:

```lua
		function bags.RequestLayout() error("layout boom") end
		finishWizard()
```

In `spec/quicksetup_spec.lua` (edit 11 of 13), find:

```lua
	-- Mutation: call Apply bare in finish() (no ErrorTrap.Run), or give Apply window "bags".
	it("W4-6: an error in Apply says SETTINGS_FAILED on the status line and in chat, and never trips Safe Mode", function()
		QS.Show()
		pick("mplus")
		SB.Config.Set = function() error("boom") end
		Fake.Fire(QS.applyButton, "OnClick")
```

and replace it with:

```lua
	-- Mutation: call fn bare in finish() (no ErrorTrap.Run), or give it window "bags".
	it("W4-6: an error in Finish says SETTINGS_FAILED on the status line and in chat, and never trips Safe Mode", function()
		QS.Show()
		pick("mplus")
		SB.Config.Set = function() error("boom") end
		finishWizard()
```

In `spec/quicksetup_spec.lua` (edit 12 of 13), find:

```lua
	end)

	it("only plain frames", function()
```

and replace it with:

```lua
	end)

	-- AC9.2 on screen (week 12). Mutation: in paintStep2, `local on = value(key) == true` -> `local on = true`.
	it("step 2 lists every focus mode and what the picks switch, each with its state; a click switches it", function()
		SB.Config.Set("overlays.upgrade", false)
		QS.Show()
		pick("mplus")
		step(2)
		assert.truthy(switch("M+ mode: On"))
		assert.truthy(switch("AH/Vendor/Bank mode: On"))
		assert.truthy(switch("Upgrade arrow on gear: On"), "M+ switches the arrow on")
		local shown = 0
		for _, b in ipairs(QS.switchButtons) do
			if b.shown then
				shown = shown + 1
			end
		end
		assert.equal(11, shown, "six modes and M+'s five switches")
		Fake.Fire(switch("Upgrade arrow on gear: On"), "OnClick")
		assert.truthy(switch("Upgrade arrow on gear: Off"))
		Fake.Fire(switch("Fishing mode: On"), "OnClick")
		assert.falsy(QS.lit[switch("Fishing mode: Off")])
		assert.truthy(QS.lit[switch("Keystone level and dungeon: On")])
		assert.is_nil(SB.Config.db.settings.focus, "still nothing written")
		finishWizard()
		assert.equal(false, SB.Config.Get("overlays.upgrade"))
		assert.equal(false, SB.Config.Get("focus.on.fishing"))
		assert.equal(true, SB.Config.db.settings.overlays.keystone, "written, though it is the default (AC9.2)")
	end)

	-- AC7.4 (week 12). Mutation: in QS.Show, `QS.draft, QS.step, QS.combatHidden = Setup.New(), 1, false` ->
	-- `QS.draft, QS.step, QS.combatHidden = QS.draft or Setup.New(), 1, false`.
	it("AC7.4: /swagbag setup starts from the settings as they are: last time's styles, the layout, the gold", function()
		SB.Config.Set("setup.done", true)
		SB.Config.Set("setup.styles", "gold")
		SB.Config.Set("bags.columns", 16)
		SB.Config.Set("bags.scale", 0.9)
		SB.Config.Set("prices.worthGold", 500)
		SB.Config.Set("vendor.autoSell", false)
		QS.Show()
		pick("raid")
		QS.frame:Hide()
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.lit[QS.styleButtons.gold])
		assert.falsy(QS.lit[QS.styleButtons.raid], "what was picked but not finished is gone")
		step(3)
		assert.truthy(QS.lit[QS.columnButtons[16]])
		assert.falsy(QS.lit[QS.columnButtons[12]])
		assert.truthy(QS.lit[QS.scaleButtons[0.9]])
		step(4)
		assert.truthy(QS.lit[QS.worthButtons[500]])
		assert.falsy(QS.lit[QS.worthButtons[100]])
		assert.truthy(QS.lit[QS.sellButtons[false]])
		assert.falsy(QS.worthButtons.top.shown)
	end)

	-- Mutation: in pricesLine, `if source and source ~= "Vendor" then` -> `if source then`.
	it("step 4 says where prices come from (an auction addon found, or a vendor's price); its choices are saved", function()
		QS.Show()
		step(4)
		assert.equal(SB.L.WIZ_PRICES_VENDOR, QS.frame.prices.text)
		A.auctionator = { prices = {} }
		SB.Prices.Invalidate()
		QS.Show()
		step(4)
		assert.equal("SwagBag found Auctionator: your items' prices come from it.", QS.frame.prices.text)
		Fake.Fire(QS.worthButtons.off, "OnClick")
		Fake.Fire(QS.sellButtons[false], "OnClick")
		assert.truthy(QS.lit[QS.worthButtons.off])
		Fake.Fire(QS.finishButton, "OnClick")
		assert.equal("off", SB.Config.Get("prices.worth"))
		assert.equal(false, SB.Config.Get("vendor.autoSell"))
	end)

	-- Mutation: in paintStep3, `if T.Available(id) or id == value("theme.name") then` -> `if true then`.
	it("step 3 offers the looks whose addon is loaded; Finish switches the look and the open bags' size", function()
		local applied = {}
		SB.Theme = { order = { "blizzard", "flat", "elvui" }, Button = function() end,
			Name = function(id) return ({ blizzard = "Blizzard", flat = "Flat", elvui = "ElvUI" })[id] end,
			Available = function(id) return id ~= "elvui" end,
			Apply = function(id, save) applied[#applied + 1] = { id, save } return true end }
		local scaled = {}
		function bags.SetScale(v, quiet) scaled[#scaled + 1] = { v, quiet } end
		QS.Show()
		step(3)
		assert.truthy(QS.lookButtons.blizzard.shown)
		assert.truthy(QS.lit[QS.lookButtons.blizzard])
		assert.is_nil(QS.lookButtons.elvui, "a look whose addon is not loaded is not offered")
		Fake.Fire(QS.lookButtons.flat, "OnClick")
		Fake.Fire(QS.scaleButtons[1.1], "OnClick")
		bags.open = true
		finishWizard()
		assert.equal("flat", SB.Config.Get("theme.name"))
		assert.same({ { "flat", false } }, applied)
		assert.same({ { 1.1, true } }, scaled)
	end)

	-- A user of the quick setup (week 11 and before) is never shown the wizard by itself. Mutation: in QS.TryShow,
	-- `if SB.SafeMode.IsOn("bags") or SB.Config.readOnly or SB.Config.Get("setup.done") then` ->
	-- `if SB.SafeMode.IsOn("bags") or SB.Config.readOnly then`.
	it("setup done (a week-11 save, or done while it waited in an instance): never shown by itself again", function()
		SB.Config.Init({ schemaVersion = 2, settings = { setup = { done = true }, bags = { columns = 14 } } }, nil)
		login()
		assert.falsy(QS.IsOpen())
		SB.Config.Init(nil, nil)
		A.instance = { instanceType = "party", difficultyID = 8 }
		login()
		SB.Slash.Dispatch("setup")
		Fake.Fire(QS.skipButton, "OnClick")
		A.instance = {}
		SB.eventFrame:Fire("PLAYER_ENTERING_WORLD")
		assert.falsy(QS.IsOpen(), "the wait for leaving the instance does not bring it back")
		assert.same({ SB.L.QS_OPENED, SB.L.QS_SKIPPED }, A.Lines())
	end)

	-- Mutation: in the PLAYER_REGEN_DISABLED handler, drop `QS.Close("combat")`.
	it("combat starts while it is open: it steps aside, says so once, and comes back as it was when combat ends", function()
		QS.Show()
		pick("gold")
		step(3)
		Fake.Fire(QS.columnButtons[10], "OnClick")
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		assert.falsy(QS.IsOpen())
		assert.same({ SB.L.WIZ_COMBAT_HIDDEN }, A.Lines())
		assert.same({}, SB.Config.db.settings, "nothing is saved")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.truthy(QS.IsOpen())
		assert.equal(3, QS.step)
		assert.truthy(QS.lit[QS.columnButtons[10]])
		assert.truthy(QS.draft.styles.gold)
		A.combat = true -- Finish in combat (opened or kept open by the user): plain frames, the settings are saved
		finishWizard()
		assert.equal(10, SB.Config.Get("bags.columns"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(QS.IsOpen())
	end)

	it("only plain frames", function()
```

In `spec/quicksetup_spec.lua` (edit 13 of 13), find:

```lua
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		local SB = Loader.New(files)
```

and replace it with:

```lua
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Setup.lua"
		local SB = Loader.New(files)
```

In `spec/theme_spec.lua`, find:

```lua
		SB.BagsWindow = { RequestLayout = function() end, RefreshTitle = function() end, IsOpen = function() return false end }
```

and replace it with:

```lua
		SB.BagsWindow = { RequestLayout = function() end, RefreshTitle = function() end, IsOpen = function() return false end }
		Loader.LoadFile(SB, "SwagBag/Engine/Setup.lua") -- week 12: the wizard's draft
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1620 passed, 11 failed`. The failures, exactly:

- `spec/quicksetup_spec.lua :: Quick setup > AC7.1: four steps, one screen each: Back, Next and Skip on the way, Finish on the last; nothing saved before`
- `spec/quicksetup_spec.lua :: Quick setup > Finish sets each picked style's preset and the slots per row, says what it did, and closes`
- `spec/quicksetup_spec.lua :: Quick setup > Finish's new category order drops the categories from the profiles' one step of undo`
- `spec/quicksetup_spec.lua :: Quick setup > read-only settings: Finish and Skip refuse with the reason and change nothing`
- `spec/quicksetup_spec.lua :: Quick setup > a refresh error after a successful Finish still reports success, with a note`
- `spec/quicksetup_spec.lua :: Quick setup > W4-6: an error in Finish says SETTINGS_FAILED on the status line and in chat, and never trips Safe Mode`
- `spec/quicksetup_spec.lua :: Quick setup > step 2 lists every focus mode and what the picks switch, each with its state; a click switches it`
- `spec/quicksetup_spec.lua :: Quick setup > AC7.4: /swagbag setup starts from the settings as they are: last time's styles, the layout, the gold`
- `spec/quicksetup_spec.lua :: Quick setup > step 4 says where prices come from (an auction addon found, or a vendor's price); its choices are saved`
- `spec/quicksetup_spec.lua :: Quick setup > step 3 offers the looks whose addon is loaded; Finish switches the look and the open bags' size`
- `spec/quicksetup_spec.lua :: Quick setup > combat starts while it is open: it steps aside, says so once, and comes back as it was when combat ends`

The old screen has no `nextButton`, `finishButton`, `switchButtons`, step panels, `scaleButtons`, `worthButtons`, `prices` line or combat handling: every test that walks the steps errors on the missing button (`Fake.Fire(nil)`), the step-2 test finds no switch, and the combat test finds the screen still open.

One new test passes here: "setup done (a week-11 save, or done while it waited in an instance): never shown by itself again". The quick setup already had both guards; the test pins them for the wizard (its mutation is on this task's code). The changed tests "loads before Config.Init without touching Config" (it loads `Engine/Setup.lua` too) and `spec/theme_spec.lua`'s "the quick setup window is a dialog with the old numbers" pass with either screen.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "AC7.1: four steps, one screen each: Back, Next and Skip on the way, Finish on the last; nothing saved before": in `SwagBag/UI/QuickSetup.lua`, `QS.finishButton:SetShown(QS.step == QS.STEPS)` → `QS.finishButton:SetShown(true)`.
- "Finish sets each picked style's preset and the slots per row, says what it did, and closes": in `SwagBag/UI/QuickSetup.lua`, `QS.Close("done")` → ∅.
- "step 2 lists every focus mode and what the picks switch, each with its state; a click switches it": in `SwagBag/UI/QuickSetup.lua`, `local on = value(key) == true` → `local on = true`.
- "AC7.4: /swagbag setup starts from the settings as they are: last time's styles, the layout, the gold": in `SwagBag/UI/QuickSetup.lua`, `QS.draft, QS.step, QS.combatHidden = Setup.New(), 1, false` → `QS.draft, QS.step, QS.combatHidden = QS.draft or Setup.New(), 1, false`.
- "step 4 says where prices come from (an auction addon found, or a vendor's price); its choices are saved": in `SwagBag/UI/QuickSetup.lua`, `if source and source ~= "Vendor" then` → `if source then`.
- "step 3 offers the looks whose addon is loaded; Finish switches the look and the open bags' size": in `SwagBag/UI/QuickSetup.lua`, `if T.Available(id) or id == value("theme.name") then` → `if true then`.
- "setup done (a week-11 save, or done while it waited in an instance): never shown by itself again": in `SwagBag/UI/QuickSetup.lua`, `if SB.SafeMode.IsOn("bags") or SB.Config.readOnly or SB.Config.Get("setup.done") then` → `if SB.SafeMode.IsOn("bags") or SB.Config.readOnly then`.
- "combat starts while it is open: it steps aside, says so once, and comes back as it was when combat ends": in `SwagBag/UI/QuickSetup.lua`, `QS.Close("combat")` → ∅.

- [ ] **Step 3: Write the code**

In `SwagBag/Locale/enUS.lua` (edit 1 of 3), find:

```lua
L.QS_INTRO = "What do you play? Pick any. You can change everything later: type /swagbag."
L.QS_HINT = "Apply sets SwagBag up for what you picked. Skip keeps SwagBag's defaults."
```

and replace it with:

```lua
L.QS_INTRO = "What do you play? Pick any. You can change everything later: type /swagbag."
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 3), find:

```lua
L.QS_APPLY = "Apply"
L.QS_SKIP = "Skip (use defaults)"
L.QS_PICK_FIRST = "Pick at least one of the buttons first, or press Skip."
L.QS_APPLIED = "Set up for %s. Change anything later: type /swagbag."
L.QS_SKIPPED = "SwagBag keeps its defaults. Type /swagbag to change anything, or /swagbag setup to see this screen again."
L.QS_SKIPPED_KEPT = "SwagBag keeps your current settings. Type /swagbag to change anything."
L.QS_LATER = "Quick setup closed without changes; it opens again at your next login, or type /swagbag setup."
L.QS_LATER_KEPT = "Quick setup closed; your settings are unchanged. Type /swagbag setup to open it again."
L.QS_REFRESH_NOTE = "Some open windows may need a moment to catch up; reopen your bags if they look off."
L.QS_OPENED = "Quick setup opened."
```

and replace it with:

```lua
L.QS_SKIP = "Skip (use defaults)"
L.QS_APPLIED = "Set up for %s. Change anything later: type /swagbag."
L.QS_SKIPPED = "SwagBag keeps its defaults. Type /swagbag to change anything, or /swagbag setup to see this screen again."
L.QS_SKIPPED_KEPT = "SwagBag keeps your current settings. Type /swagbag to change anything."
L.QS_LATER = "Setup closed without changes; it opens again at your next login, or type /swagbag setup."
L.QS_LATER_KEPT = "Setup closed; your settings are unchanged. Type /swagbag setup to open it again."
L.QS_REFRESH_NOTE = "Some open windows may need a moment to catch up; reopen your bags if they look off."
L.QS_OPENED = "Setup opened."
```

In `SwagBag/Locale/enUS.lua` (edit 3 of 3), find:

```lua
L.HELP_SETUP = "setup: show the quick setup screen again"
```

and replace it with:

```lua
-- Week 12: the setup wizard's screen (UI/QuickSetup.lua).
L.WIZ_STEP = "Step %d of %d: %s"
L.WIZ_STEP1 = "What do you play?"
L.WIZ_STEP2 = "What that turns on"
L.WIZ_STEP3 = "How your bags look"
L.WIZ_STEP4 = "Gold"
L.WIZ_HINT = "Nothing is saved until Finish. Skip keeps SwagBag's defaults."
L.WIZ_SWITCH_NOTE = "This is what your picks turn on. Click a line to switch it. Everything is in /swagbag later."
L.WIZ_SWITCH = "%s: %s"
L.WIZ_NEXT = "Next"
L.WIZ_BACK = "Back"
L.WIZ_FINISH = "Finish"
L.WIZ_WORTH_GOLD = "%dg"
L.WIZ_PRICES_FROM = "SwagBag found %s: your items' prices come from it."
L.WIZ_PRICES_VENDOR = "No auction price addon found, so prices are what a vendor pays. Install Auctionator or TSM"
	.. " and SwagBag uses it by itself."
L.WIZ_COMBAT_HIDDEN = "Setup steps aside during the fight; it comes back where you were when combat ends."
L.HELP_SETUP = "setup: run the setup wizard again (it starts from your settings as they are)"
```

Replace the whole of `SwagBag/UI/QuickSetup.lua` with (most of the file changes, so it is given whole):

```lua
-- SwagBag setup wizard (spec F7: AC7.1, AC7.2, AC7.4; week 12, from the week-4 quick setup). Shown once, a few
-- seconds after the first login, on any character (settings are account-wide); a user who finished or skipped the
-- quick setup before (setup.done) never sees it again unless they type /swagbag setup (AC7.4), which shows it filled
-- in with the settings as they are. Four short steps, one screen each:
--   1 What do you play?   M+, Raid, Gold-making, Casual, Collector: pick any, or none
--   2 What that turns on  every focus mode and what the picked styles switch (AC9.2), each a click to switch
--   3 Layout              slots per row, the bags' size, the look
--   4 Gold                where prices come from (found or not), the gold glow at the bank, selling junk
-- Back, Next and Skip on every step, Finish on the last. Nothing is written before Finish (Engine/Setup.lua keeps the
-- draft): Skip keeps SwagBag's defaults (or the settings as they are) and says so (AC7.2); Esc or the X is "later",
-- nothing saved. When combat starts the wizard steps aside and comes back where it was when combat ends.
-- All writes refuse while the settings are read-only (a newer schema), with that reason.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local Setup = SB.Setup
local QS = { step = 1, STEPS = 4, styleButtons = {}, columnButtons = {}, scaleButtons = {}, lookButtons = {},
	worthButtons = {}, sellButtons = {}, switchButtons = {}, MAX_SWITCHES = 18, DELAY = 3 }
SB.QuickSetup = QS

QS.STYLES = Setup.STYLES
QS.COLUMNS = { 10, 12, 14, 16 }
QS.SCALES = { 0.8, 0.9, 1.0, 1.1, 1.25 }
QS.WORTH = { "off", 50, 100, 500, 1000, "top" } -- "top" is shown only while it is the setting now

---------------------------------------------------------------------------
-- The screen (plain frames only; it can open in combat)
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "SwagBagQuickSetup", UIParent, "BackdropTemplate")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(580, 360)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
frame:Hide()
QS.frame = frame
table.insert(UISpecialFrames, "SwagBagQuickSetup")

frame:SetScript("OnDragStart", Guard("setup.dragStart", function()
	frame:StartMoving()
end, "none"))
frame:SetScript("OnDragStop", Guard("setup.dragStop", function()
	frame:StopMovingOrSizing()
end, "none"))

local function text(parent, template, x, y, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", template)
	fs:SetPoint("TOPLEFT", x, y)
	if width then
		fs:SetWidth(width)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
	end
	return fs
end

frame.title = text(frame, "GameFontNormalLarge", 14, -12)
frame.title:SetText(L.QS_TITLE)
frame.stepLabel = text(frame, "GameFontNormal", 14, -38)
frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.status:SetPoint("BOTTOMLEFT", 14, 44)
frame.status:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
frame.status:SetJustifyH("LEFT")
frame.status:SetText(L.WIZ_HINT)

-- One panel per step, under the step's name; only the current one is shown.
frame.steps = {}
for i = 1, QS.STEPS do
	local p = CreateFrame("Frame", nil, frame)
	p:SetPoint("TOPLEFT", 0, -60)
	p:SetPoint("BOTTOMRIGHT", 0, 64)
	p:Hide()
	frame.steps[i] = p
end
local step1, step2, step3, step4 = frame.steps[1], frame.steps[2], frame.steps[3], frame.steps[4]

frame.intro = text(step1, "GameFontHighlight", 14, -4, 552)
frame.intro:SetText(L.QS_INTRO)
-- Week 6 (D18): what the Pause button on the bags is for, before the user meets it.
frame.pauseNote = text(step1, "GameFontHighlightSmall", 14, -90, 552)
frame.pauseNote:SetText(L.QS_PAUSE_NOTE)
frame.switchNote = text(step2, "GameFontHighlight", 14, -4, 552)
frame.switchNote:SetText(L.WIZ_SWITCH_NOTE)
frame.columnsLabel = text(step3, "GameFontNormal", 14, -4)
frame.columnsLabel:SetText(L.SET_COLUMNS)
frame.scaleLabel = text(step3, "GameFontNormal", 14, -60)
frame.scaleLabel:SetText(L.SET_SCALE)
frame.lookLabel = text(step3, "GameFontNormal", 14, -116)
frame.lookLabel:SetText(L.SET_LOOK)
frame.prices = text(step4, "GameFontHighlight", 14, -4, 552)
frame.worthLabel = text(step4, "GameFontNormal", 14, -52)
frame.worthLabel:SetText(L.SET_WORTH)
frame.sellLabel = text(step4, "GameFontNormal", 14, -108)
frame.sellLabel:SetText(L.SET_VENDOR_SELL)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

-- A wizard button: fn() runs under ErrorTrap "none", then the screen is drawn again.
local function button(parent, width, x, y, label, fn)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	if x then
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	end
	if label then
		b:SetText(label)
	end
	b:SetScript("OnClick", Guard("setup.click", function()
		fn()
		QS.Paint()
	end, "none"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	return b
end

-- QS.lit[button]: drawn selected (a picked style, the choice in force).
QS.lit = {}
local function highlight(b, on)
	QS.lit[b] = on or nil
	if on then
		b:LockHighlight()
	else
		b:UnlockHighlight()
	end
end

local function value(key)
	return Setup.Value(QS.draft, key)
end

-- Step 1: the styles.
for i, s in ipairs(QS.STYLES) do
	QS.styleButtons[s.id] = button(step1, 100, 14 + (i - 1) * 106, -40, nil, function()
		Setup.Toggle(QS.draft, s.id)
	end)
end

-- Step 2: one button per switch, in two columns; the text says the switch and its state, a click switches it.
for i = 1, QS.MAX_SWITCHES do
	local b
	b = button(step2, 270, 14 + ((i - 1) % 2) * 280, -44 - math.floor((i - 1) / 2) * 24, nil, function()
		if b.key then
			Setup.Set(QS.draft, b.key, not value(b.key))
		end
	end)
	QS.switchButtons[i] = b
end

-- Step 3: slots per row, size, look.
for i, n in ipairs(QS.COLUMNS) do
	QS.columnButtons[n] = button(step3, 56, 14 + (i - 1) * 60, -22, tostring(n), function()
		Setup.Set(QS.draft, "bags.columns", n)
	end)
end
for i, n in ipairs(QS.SCALES) do
	QS.scaleButtons[n] = button(step3, 56, 14 + (i - 1) * 60, -78, L.SET_PERCENT:format(math.floor(n * 100 + 0.5)), function()
		Setup.Set(QS.draft, "bags.scale", n)
	end)
end

-- The looks there are (UI/Theme.lua), each made the first time it is drawn: a look whose addon is not loaded is left
-- out, unless it is the one set now.
local function lookButton(id, i)
	local b = QS.lookButtons[id]
	if not b then
		b = button(step3, 120, nil, nil, SB.Theme.Name(id), function()
			Setup.Set(QS.draft, "theme.name", id)
		end)
		QS.lookButtons[id] = b
	end
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", step3, "TOPLEFT", 14 + (i - 1) * 126, -134)
	return b
end

-- Step 4: the gold glow and selling junk.
local function worthText(v)
	if v == "off" then
		return L.SET_OFF
	elseif v == "top" then
		return L.SET_WORTH_TOP:format(SB.Config.Get("prices.worthTop"))
	end
	return L.WIZ_WORTH_GOLD:format(v)
end
for i, v in ipairs(QS.WORTH) do
	QS.worthButtons[v] = button(step4, 84, 14 + (i - 1) * 88, -70, nil, function()
		if v == "off" or v == "top" then
			Setup.Set(QS.draft, "prices.worth", v)
		else
			Setup.Set(QS.draft, "prices.worth", "fixed")
			Setup.Set(QS.draft, "prices.worthGold", v)
		end
	end)
end
for i, v in ipairs({ true, false }) do
	QS.sellButtons[v] = button(step4, 84, 14 + (i - 1) * 88, -126, v and L.SET_ON or L.SET_OFF, function()
		Setup.Set(QS.draft, "vendor.autoSell", v)
	end)
end

-- Where prices come from: the auction addon SwagBag found, or what a vendor pays.
local function pricesLine()
	local P = SB.Prices
	local source = P and P.Source()
	if source and source ~= "Vendor" then
		return L.WIZ_PRICES_FROM:format(P.SourceText())
	end
	return L.WIZ_PRICES_VENDOR
end

local function paintStep2()
	local keys = Setup.Switches(QS.draft)
	for i, b in ipairs(QS.switchButtons) do
		local key = keys[i]
		b.key = key
		if key then
			local on = value(key) == true
			b:SetText(L.WIZ_SWITCH:format(Setup.Label(key), on and L.SET_ON or L.SET_OFF))
			highlight(b, on)
			b:Show()
		else
			b:Hide()
		end
	end
end

local function paintStep3()
	for n, b in pairs(QS.columnButtons) do
		highlight(b, value("bags.columns") == n)
	end
	for n, b in pairs(QS.scaleButtons) do
		highlight(b, value("bags.scale") == n)
	end
	local T, shown, i = SB.Theme, {}, 0
	if T and T.order then
		for _, id in ipairs(T.order) do
			if T.Available(id) or id == value("theme.name") then
				i = i + 1
				local b = lookButton(id, i)
				highlight(b, value("theme.name") == id)
				b:Show()
				shown[id] = true
			end
		end
	end
	for id, b in pairs(QS.lookButtons) do
		if not shown[id] then
			b:Hide()
		end
	end
	frame.lookLabel:SetShown(i > 0)
end

local function paintStep4()
	frame.prices:SetText(pricesLine())
	local mode, gold = value("prices.worth"), value("prices.worthGold")
	for v, b in pairs(QS.worthButtons) do
		b:SetText(worthText(v))
		if v == "off" or v == "top" then
			highlight(b, mode == v)
		else
			highlight(b, mode == "fixed" and gold == v)
		end
	end
	QS.worthButtons.top:SetShown(SB.Config.Get("prices.worth") == "top")
	for v, b in pairs(QS.sellButtons) do
		highlight(b, value("vendor.autoSell") == v)
	end
end

local STEP_NAMES = { "WIZ_STEP1", "WIZ_STEP2", "WIZ_STEP3", "WIZ_STEP4" }

function QS.Paint()
	local d = QS.draft
	if not d then
		return
	end
	frame.stepLabel:SetText(L.WIZ_STEP:format(QS.step, QS.STEPS, L[STEP_NAMES[QS.step]]))
	for i, p in ipairs(frame.steps) do
		p:SetShown(i == QS.step)
	end
	for _, s in ipairs(QS.STYLES) do
		local b = QS.styleButtons[s.id]
		local on = d.styles[s.id] == true
		b:SetText(on and L.QS_STYLE_ON:format(L[s.name]) or L[s.name])
		highlight(b, on)
	end
	if QS.step == 2 then
		paintStep2()
	elseif QS.step == 3 then
		paintStep3()
	elseif QS.step == 4 then
		paintStep4()
	end
	QS.backButton:SetShown(QS.step > 1)
	QS.nextButton:SetShown(QS.step < QS.STEPS)
	QS.finishButton:SetShown(QS.step == QS.STEPS)
end

-- Finish / Skip answer in chat (P2); a refusal also shows on the screen, which stays open. An error runs under "none"
-- (a settings glitch never takes the bags away): the status line and chat say it failed, and the error is recorded
-- for /swagbag report.
local function finish(fn)
	local ok, feedback = SB.ErrorTrap.Run("setup.finish", "none", fn, QS.draft)
	if not ok then
		feedback = L.SETTINGS_FAILED
	end
	SB.Print(feedback)
	frame.status:SetText(feedback)
	if ok and not SB.Config.readOnly then
		QS.Close("done")
	end
end

local function go(step)
	QS.step = math.max(1, math.min(QS.STEPS, step))
	frame.status:SetText(L.WIZ_HINT)
end

QS.finishButton = button(frame, 120, nil, nil, L.WIZ_FINISH, function()
	finish(Setup.Finish)
end)
QS.finishButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
QS.nextButton = button(frame, 120, nil, nil, L.WIZ_NEXT, function()
	go(QS.step + 1)
end)
QS.nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
QS.backButton = button(frame, 90, nil, nil, L.WIZ_BACK, function()
	go(QS.step - 1)
end)
QS.backButton:SetPoint("RIGHT", QS.nextButton, "LEFT", -8, 0)
QS.skipButton = button(frame, 160, nil, nil, L.QS_SKIP, function()
	finish(Setup.Skip)
end)
QS.skipButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "dialog")
	SB.Theme.Text(frame.title, "titleLarge")
	for _, fs in ipairs({ frame.intro, frame.switchNote, frame.prices }) do
		SB.Theme.Text(fs, "body")
	end
	for _, fs in ipairs({ frame.stepLabel, frame.columnsLabel, frame.scaleLabel, frame.lookLabel, frame.worthLabel,
		frame.sellLabel }) do
		SB.Theme.Text(fs, "label")
	end
	SB.Theme.Text(frame.pauseNote, "small")
	SB.Theme.Text(frame.status, "small")
end

-- Closing without Finish or Skip (Esc, the X) is "later": it says when the screen comes back. Stepping aside for
-- combat says its own line. The OnHide guard comes first (Alt+Z hides UIParent while this frame stays shown).
frame:SetScript("OnHide", Guard("setup.hide", function(self)
	if self:IsShown() then
		return
	end
	if not QS.closing then
		-- Once setup is done it never comes back by itself, so do not promise it will.
		SB.Print(SB.Config.Get("setup.done") and L.QS_LATER_KEPT or L.QS_LATER)
	end
	QS.closing = nil
end, "none"))

function QS.Close(how)
	QS.closing = how
	frame:Hide()
end

-- A fresh draft from the settings as they are (a re-run starts from the styles picked last time), at step 1.
function QS.Show()
	QS.draft, QS.step, QS.combatHidden = Setup.New(), 1, false
	frame.status:SetText(L.WIZ_HINT)
	QS.Paint()
	frame:Show()
end

function QS.IsOpen()
	return frame:IsShown()
end

-- First login with this build: show it a few seconds after the loading screen, unless the settings are read-only, the
-- bags are in Safe Mode (then the bags are Blizzard's anyway), or setup is done (a user of the quick setup).
SB.On("SB_LOGIN", function()
	if SB.Config.Get("setup.done") or SB.Config.readOnly then
		return
	end
	SB.Debounce("setup.show", QS.DELAY, QS.TryShow, "none")
end, "none")

-- Not in combat and not inside an instance (a popup there would cover the fight or the run): wait, and try again when
-- combat ends or the zone changes. /swagbag setup opens at once.
function QS.TryShow()
	if SB.SafeMode.IsOn("bags") or SB.Config.readOnly or SB.Config.Get("setup.done") then
		QS.waiting = false
		return
	end
	if SB.Adapter.InCombat() or SB.Adapter.InstanceInfo().instanceType then
		QS.waiting = true
		return
	end
	QS.waiting = false
	QS.Show()
end

-- Combat starts while the wizard is open: it steps aside (it never covers a fight) and comes back where it was, with
-- everything picked, when combat ends. Nothing is saved meanwhile.
SB.On("PLAYER_REGEN_DISABLED", function()
	if frame:IsShown() then
		QS.combatHidden = true
		QS.Close("combat")
		SB.Print(L.WIZ_COMBAT_HIDDEN)
	end
end, "none")

SB.On("PLAYER_REGEN_ENABLED", function()
	if QS.combatHidden then
		QS.combatHidden = false
		QS.Paint()
		frame:Show()
	elseif QS.waiting then
		QS.TryShow()
	end
end, "none")
SB.On("PLAYER_ENTERING_WORLD", function()
	if QS.waiting then
		QS.TryShow()
	end
end, "none")

SB.Slash.Register("setup", L.HELP_SETUP, function()
	QS.Show()
	return L.QS_OPENED
end)

SB.Slash.Register("tour", L.HELP_TOUR, function()
	return L.TOUR_LATER
end)
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1631 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (80 files)`, `1631 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Locale/enUS.lua \
	SwagBag/UI/QuickSetup.lua \
	spec/quicksetup_spec.lua \
	spec/theme_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 12 Task 2: the four-step setup wizard

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 3: The guided tour (UI/Tour.lua), offered after Finish

`/swagbag tour`, any time (AC7.3, D11): seven notes, each next to a part of the bag window with a thin gold frame around it: the first section header (three notes: what a header says; click to collapse, drag onto it; focus modes and peek), the search box, the Pause button with the mode title, the Sort button, and Safe Mode (beside the window). A part that is not drawn gets its note beside the window. Back, Next (Done on the last) and End tour on the note; Esc ends it. Start opens the bags if they are closed, and refuses in combat, in Safe Mode, or when the bags can't open. The bags closing, combat starting, Esc and End each end it with one line; a layout while it runs (a view change) points the note again. It calls nothing on the bags window but `IsOpen` and `Open`. `/swagbag tour` moves here from the quick setup file, and Finish now offers the tour once (D12) in a small note of its own: "Show me around" or "No thanks".

**Files:**
- Create: `SwagBag/UI/Tour.lua`, `spec/tour_spec.lua`
- Modify: `SwagBag/UI/QuickSetup.lua` (the offer; `/swagbag tour` moves out), `SwagBag/Locale/enUS.lua` (the notes, the endings, the offer; `TOUR_LATER` goes, `HELP_TOUR` changes), `SwagBag/SwagBag.toc` (the new file after `UI/QuickSetup.lua`), `spec/quicksetup_spec.lua` (two offer tests; the AC7.4 test no longer types `/swagbag tour`)

**Interfaces:**
- Consumes: `SB.BagsWindow` (`frame`, `child`, `modeButton`, `sortButton`, `IsOpen`, `Open`), `SB.SectionHeaders.inUse`, `SB.SearchBox.editBox`, `SB.SafeMode.IsOn`, `SB.Adapter.InCombat`, the events `SB_BAGS_CLOSED`, `SB_BAGS_LAYOUT`, `PLAYER_REGEN_DISABLED`.
- Produces: `SB.Tour` with `STEPS` (`{ id, text, target }`), `Start() -> feedback`, `Next()`, `Back()`, `End(reason) -> bool`, `step`, `target`, `frame` (`count`, `text`), `ring`, `backButton`, `nextButton`, `endButton`; `SB.QuickSetup.offer`, `tourButton`, `noTourButton`; `L.TOUR_*`, `L.WIZ_TOUR_*`.

- [ ] **Step 1: Write the failing tests**

In `spec/quicksetup_spec.lua` (edit 1 of 2), find:

```lua
	it("AC7.4: /swagbag setup shows it again; /swagbag tour answers (P2)", function()
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.IsOpen())
		SB.Slash.Dispatch("tour")
		assert.same({ SB.L.QS_OPENED, SB.L.TOUR_LATER }, A.Lines())
```

and replace it with:

```lua
	it("AC7.4: /swagbag setup shows it again (P2)", function()
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.IsOpen())
		assert.same({ SB.L.QS_OPENED }, A.Lines())
```

In `spec/quicksetup_spec.lua` (edit 2 of 2), find:

```lua
	end)

	it("only plain frames", function()
```

and replace it with:

```lua
	end)

	-- AC7.3 (week 12). Mutation: in finish(), drop `QS.offer:Show()`.
	it("after Finish the tour is offered once: Show me around starts it, No thanks or Esc say how to get it later", function()
		local started = 0
		SB.Tour = { Start = function()
			started = started + 1
			return "TOUR STARTED"
		end }
		QS.Show()
		finishWizard()
		assert.falsy(QS.IsOpen())
		assert.truthy(QS.offer.shown)
		Fake.Fire(QS.tourButton, "OnClick")
		assert.falsy(QS.offer.shown)
		assert.equal(1, started)
		assert.same({ SB.L.WIZ_DONE_NONE, "TOUR STARTED" }, A.Lines())
		QS.Show()
		finishWizard()
		Fake.Fire(QS.noTourButton, "OnClick")
		QS.Show()
		finishWizard()
		QS.offer:Hide() -- Esc
		QS.Show()
		Fake.Fire(QS.skipButton, "OnClick")
		assert.falsy(QS.offer.shown, "Skip offers nothing")
		local lines = A.Lines()
		assert.same({ SB.L.WIZ_DONE_NONE, SB.L.WIZ_TOUR_LATER, SB.L.WIZ_DONE_NONE, SB.L.WIZ_TOUR_LATER,
			SB.L.QS_SKIPPED_KEPT }, { lines[3], lines[4], lines[5], lines[6], lines[7] })
		assert.equal(1, started)
	end)

	-- Mutation: in finish(), drop `and not SB.Adapter.InCombat()`.
	it("no tour offer in combat; combat starting while it is offered takes it away, with how to get it later", function()
		SB.Tour = { Start = function() return "TOUR STARTED" end }
		A.combat = true
		SB.Slash.Dispatch("setup")
		finishWizard()
		assert.falsy(QS.offer.shown)
		A.combat = false
		QS.Show()
		finishWizard()
		assert.truthy(QS.offer.shown)
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		assert.falsy(QS.offer.shown)
		local lines = A.Lines()
		assert.equal(SB.L.WIZ_TOUR_LATER, lines[#lines])
	end)

	it("only plain frames", function()
```

Create `spec/tour_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 12 (spec F7, AC7.3): the guided tour of the bag window (UI/Tour.lua): /swagbag tour, a note next to each part,
-- Back / Next / End, and it ends cleanly when the bags close or combat starts. It only points: nothing moves.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("The guided tour (week 12)", function()
	local SB, A, T, W, header, bankHeader, L
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A, L = SB.Adapter, SB.L
		SB.Config.Init(nil, nil)
		Fake.Install()
		-- A stand-in bags window: the parts the tour points at, and counters for anything that would move an item.
		W = { frame = Fake.New("Frame", UIParent), modeButton = Fake.New("Button"), sortButton = Fake.New("Button"),
			moved = 0, opened = 0 }
		W.child = Fake.New("Frame", W.frame)
		W.frame.shown = false
		function W.IsOpen() return W.frame.shown end
		function W.Open()
			W.opened = W.opened + 1
			W.frame:Show()
			return true
		end
		function W.Close() W.frame:Hide() end
		for _, name in ipairs({ "RequestLayout", "Reflow", "Sort", "Layout", "Restack", "ToggleSection", "SetView" }) do
			W[name] = function() W.moved = W.moved + 1 end
		end
		W.frame:SetScript("OnHide", function() SB.Emit("SB_BAGS_CLOSED") end)
		SB.BagsWindow = W
		bankHeader = Fake.New("Button", Fake.New("Frame"))
		header = Fake.New("Button", W.child)
		SB.SectionHeaders = { inUse = { bankHeader, header } }
		SB.SearchBox = { editBox = Fake.New("EditBox", W.frame) }
		Loader.LoadFile(SB, "SwagBag/UI/Tour.lua")
		T = SB.Tour
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function anchor()
		return T.frame.points[1] and T.frame.points[1][2]
	end

	-- AC7.3. Mutation: in firstHeader, `if h:GetParent() == W.child then` -> `if true then` (the bank's header would be
	-- pointed at).
	it("AC7.3: /swagbag tour opens the bags and puts the first note next to the bags' first section header", function()
		SB.Slash.Dispatch("tour")
		assert.same({ L.TOUR_STARTED }, A.Lines())
		assert.equal(1, W.opened)
		assert.truthy(T.frame.shown)
		assert.equal(L.TOUR_HEADERS, T.frame.text.text)
		assert.equal("1 of 7", T.frame.count.text)
		assert.equal(header, anchor())
		assert.equal(header, T.target)
		assert.truthy(T.ring.shown, "a thin frame around the header")
		assert.falsy(T.backButton.shown)
		assert.equal(L.TOUR_NEXT, T.nextButton.text)
	end)

	-- Mutation: in Tour.Next, `if Tour.step >= #Tour.STEPS then` -> `if Tour.step > #Tour.STEPS then`.
	it("Next and Back walk the seven notes, each next to its part; Next on the last ends the tour with one line", function()
		T.Start()
		local seen, texts = { T.target }, { T.frame.text.text }
		for _ = 2, 7 do
			Fake.Fire(T.nextButton, "OnClick")
			seen[#seen + 1] = T.target
			texts[#texts + 1] = T.frame.text.text
		end
		assert.same({ header, header, header, SB.SearchBox.editBox, W.modeButton, W.sortButton, W.frame }, seen)
		assert.same({ L.TOUR_HEADERS, L.TOUR_COLLAPSE, L.TOUR_PEEK, L.TOUR_SEARCH, L.TOUR_MODES, L.TOUR_SORT, L.TOUR_SAFE },
			texts)
		assert.equal(L.TOUR_DONE, T.nextButton.text)
		assert.falsy(T.ring.shown, "the last note sits beside the window, no frame to draw")
		Fake.Fire(T.backButton, "OnClick")
		assert.equal(W.sortButton, T.target)
		Fake.Fire(T.nextButton, "OnClick")
		Fake.Fire(T.nextButton, "OnClick")
		assert.is_nil(T.step)
		assert.falsy(T.frame.shown)
		assert.same({ L.TOUR_FINISHED }, A.Lines())
		assert.truthy(W.frame.shown, "the bags stay open")
	end)

	-- Mutation: in show(), `if not (target and target:IsShown()) then` -> `if not target then`.
	it("a part that isn't drawn (no section headers in the grid view): the note sits beside the window, same words", function()
		header.shown = false
		T.Start()
		assert.equal(W.frame, anchor())
		assert.equal(W.frame, T.target)
		assert.equal(L.TOUR_HEADERS, T.frame.text.text)
		assert.falsy(T.ring.shown)
	end)

	-- Mutation: drop the SB_BAGS_CLOSED listener.
	it("the bags closing ends it: the note goes, one line, once", function()
		T.Start()
		Fake.Fire(T.nextButton, "OnClick")
		W.Close()
		assert.is_nil(T.step)
		assert.falsy(T.frame.shown)
		assert.falsy(T.ring.shown)
		assert.same({ L.TOUR_ENDED_CLOSED }, A.Lines())
		T.frame:Hide()
		assert.same({ L.TOUR_ENDED_CLOSED }, A.Lines(), "no second line")
	end)

	-- Mutation: drop the PLAYER_REGEN_DISABLED listener.
	it("combat starting ends it at once, with one line; the bags stay as they are", function()
		T.Start()
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		assert.is_nil(T.step)
		assert.falsy(T.frame.shown)
		assert.same({ L.TOUR_ENDED_COMBAT }, A.Lines())
		assert.truthy(W.frame.shown)
	end)

	-- Mutation: in Tour.Start, drop the `if SB.Adapter.InCombat() then return L.TOUR_COMBAT` branch.
	it("refused in combat, while the bags are Blizzard's, or when they can't open; nothing is shown", function()
		A.combat = true
		SB.Slash.Dispatch("tour")
		A.combat = false
		SB.SafeMode.Enable("bags", "manual")
		SB.Slash.Dispatch("tour")
		SB.SafeMode.Disable("bags")
		function W.Open() return false end
		SB.Slash.Dispatch("tour")
		local lines = A.Lines()
		assert.same({ L.TOUR_COMBAT, L.TOUR_SAFE_MODE, L.TOUR_NO_BAGS }, { lines[1], lines[#lines - 1], lines[#lines] })
		assert.falsy(T.frame.shown)
		assert.is_nil(T.step)
		assert.equal(0, W.opened)
	end)

	-- Mutation: in the note's OnHide, drop `Tour.End("ended")`.
	it("End tour and Esc stop it with one line; nothing in the bags moved, sorted or was laid out", function()
		T.Start()
		Fake.Fire(T.nextButton, "OnClick")
		Fake.Fire(T.endButton, "OnClick")
		assert.same({ L.TOUR_ENDED }, A.Lines())
		T.Start()
		T.frame:Hide() -- Esc
		assert.is_nil(T.step)
		assert.falsy(T.ring.shown)
		assert.same({ L.TOUR_ENDED, L.TOUR_ENDED }, A.Lines())
		assert.equal(0, W.moved)
	end)

	-- Mutation: drop the SB_BAGS_LAYOUT listener.
	it("the bags laid out again (a view change) while it runs: the note points again", function()
		T.Start()
		local other = Fake.New("Button", W.child)
		header.shown = false
		SB.SectionHeaders.inUse = { other }
		SB.Emit("SB_BAGS_LAYOUT")
		assert.equal(other, T.target)
		assert.equal(other, anchor())
		assert.equal(1, T.step)
	end)

	it("every note's words are in enUS.lua; only plain frames", function()
		for _, s in ipairs(T.STEPS) do
			assert.truthy(rawget(L, s.text), s.text)
		end
		for _, f in ipairs(Fake.created) do
			assert.truthy(f.kind == "Frame" or f.kind == "Button", f.kind)
		end
	end)
end)
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1631 passed, 11 failed`. The failures, exactly:

- `spec/quicksetup_spec.lua :: Quick setup > after Finish the tour is offered once: Show me around starts it, No thanks or Esc say how to get it later`
- `spec/quicksetup_spec.lua :: Quick setup > no tour offer in combat; combat starting while it is offered takes it away, with how to get it later`
- `spec/tour_spec.lua :: The guided tour (week 12) > AC7.3: /swagbag tour opens the bags and puts the first note next to the bags' first section header`
- `spec/tour_spec.lua :: The guided tour (week 12) > Next and Back walk the seven notes, each next to its part; Next on the last ends the tour with one line`
- `spec/tour_spec.lua :: The guided tour (week 12) > a part that isn't drawn (no section headers in the grid view): the note sits beside the window, same words`
- `spec/tour_spec.lua :: The guided tour (week 12) > the bags closing ends it: the note goes, one line, once`
- `spec/tour_spec.lua :: The guided tour (week 12) > combat starting ends it at once, with one line; the bags stay as they are`
- `spec/tour_spec.lua :: The guided tour (week 12) > refused in combat, while the bags are Blizzard's, or when they can't open; nothing is shown`
- `spec/tour_spec.lua :: The guided tour (week 12) > End tour and Esc stop it with one line; nothing in the bags moved, sorted or was laid out`
- `spec/tour_spec.lua :: The guided tour (week 12) > the bags laid out again (a view change) while it runs: the note points again`
- `spec/tour_spec.lua :: The guided tour (week 12) > every note's words are in enUS.lua; only plain frames`

The tour tests fail in `before_each`, which loads `SwagBag/UI/Tour.lua`: it does not exist yet. The two offer tests find no `QS.offer` (Finish only closes the wizard).

The changed test "AC7.4: /swagbag setup shows it again (P2)" passes here: it no longer types `/swagbag tour`, which this task moves to `UI/Tour.lua` (the quick setup spec does not load it).

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "AC7.3: /swagbag tour opens the bags and puts the first note next to the bags' first section header": in `SwagBag/UI/Tour.lua`, `if h:GetParent() == W.child then` → `if true then`.
- "Next and Back walk the seven notes, each next to its part; Next on the last ends the tour with one line": in `SwagBag/UI/Tour.lua`, `if Tour.step >= #Tour.STEPS then` → `if Tour.step > #Tour.STEPS then`.
- "a part that isn't drawn (no section headers in the grid view): the note sits beside the window, same words": in `SwagBag/UI/Tour.lua`, `if not (target and target:IsShown()) then` → `if not target then`.
- "the bags closing ends it: the note goes, one line, once": in `SwagBag/UI/Tour.lua`, `Tour.End("closed")` → ∅.
- "combat starting ends it at once, with one line; the bags stay as they are": in `SwagBag/UI/Tour.lua`, `Tour.End("combat")` → ∅.
- "refused in combat, while the bags are Blizzard's, or when they can't open; nothing is shown": in `SwagBag/UI/Tour.lua`, `if SB.Adapter.InCombat() then` → `if false then`.
- "End tour and Esc stop it with one line; nothing in the bags moved, sorted or was laid out": in `SwagBag/UI/Tour.lua`, `if not self:IsShown() and Tour.step then` → `if false then`.
- "the bags laid out again (a view change) while it runs: the note points again": in `SwagBag/UI/Tour.lua`, `SB.On("SB_BAGS_LAYOUT", function()` → `SB.On("SB_BAGS_LAYOUT_NEVER", function()`.
- "after Finish the tour is offered once: Show me around starts it, No thanks or Esc say how to get it later": in `SwagBag/UI/QuickSetup.lua`, `QS.offer:Show() -- the tour, offered once at the end (AC7.3)` → ∅.
- "no tour offer in combat; combat starting while it is offered takes it away, with how to get it later": in `SwagBag/UI/QuickSetup.lua`, `if offer and SB.Tour and not SB.Adapter.InCombat() then` → `if offer and SB.Tour then`.

- [ ] **Step 3: Write the code**

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.HELP_SETUP = "setup: run the setup wizard again (it starts from your settings as they are)"
L.HELP_TOUR = "tour: the guided tour (arrives in November)"
L.TOUR_LATER = "The guided tour arrives with the full setup wizard in November. Until then, /swagbag help lists every command."
```

and replace it with:

```lua
L.WIZ_TOUR_ASK = "All set. Want a short tour of your bags? It takes a minute, and you can stop it any time."
L.WIZ_TOUR_YES = "Show me around"
L.WIZ_TOUR_NO = "No thanks"
L.WIZ_TOUR_LATER = "Type /swagbag tour any time for a short tour of your bags."
-- Week 12: the guided tour (UI/Tour.lua, AC7.3).
L.TOUR_COUNT = "%d of %d"
L.TOUR_BACK = "Back"
L.TOUR_NEXT = "Next"
L.TOUR_DONE = "Done"
L.TOUR_END = "End tour"
L.TOUR_HEADERS = "Each section is a category. Its header says what is in it, how many, and what it is worth."
L.TOUR_COLLAPSE = "Click a header to close or open its section. Drag an item onto a header to keep it in that section."
L.TOUR_PEEK = "Focus modes bring the sections you need to the top by themselves: in a key, at a vendor, while fishing."
	.. " With the Collapse style the others close instead; click a closed header to peek at it."
L.TOUR_SEARCH = "Type here to search, for example potion or boe: everything else dims, and nothing moves."
L.TOUR_MODES = "The title names the focus mode that is on. Pause stops modes until you click Resume; right-click it to"
	.. " choose a mode's sections."
L.TOUR_SORT = "Sort tidies your bags: Blizzard's sort, or partial stacks first (Settings > Bags)."
L.TOUR_SAFE = "If your bags ever act up, type /swagbag safe on: Blizzard's bags come back at once. /swagbag safe off"
	.. " brings SwagBag back, and /swagbag report shows what went wrong."
L.TOUR_STARTED = "Tour started: the notes next to your bags show you around. Esc or End tour stops it."
L.TOUR_FINISHED = "That's the tour. Type /swagbag tour to see it again, or /swagbag for every setting."
L.TOUR_ENDED = "Tour ended. Type /swagbag tour to see it again."
L.TOUR_ENDED_CLOSED = "Tour ended because your bags closed. Type /swagbag tour to see it again."
L.TOUR_ENDED_COMBAT = "Tour ended because combat started. Type /swagbag tour after the fight."
L.TOUR_COMBAT = "The tour waits until you are out of combat. Type /swagbag tour again then."
L.TOUR_SAFE_MODE = "Your bags are Blizzard's right now (Safe Mode), so there is nothing to show. Type /swagbag safe off first."
L.TOUR_NO_BAGS = "SwagBag's bags can't open yet, so the tour can't start. Try again in a moment."
L.HELP_SETUP = "setup: run the setup wizard again (it starts from your settings as they are)"
L.HELP_TOUR = "tour: a short guided tour of your bags, any time"
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/QuickSetup.lua
```

and replace it with:

```text
UI/QuickSetup.lua
UI/Tour.lua
```

In `SwagBag/UI/QuickSetup.lua` (edit 1 of 7), find:

```lua
-- nothing saved. When combat starts the wizard steps aside and comes back where it was when combat ends.
```

and replace it with:

```lua
-- nothing saved. When combat starts the wizard steps aside and comes back where it was when combat ends.
-- After Finish (out of combat) a small note offers the tour (AC7.3, UI/Tour.lua): "Show me around" or "No thanks".
```

In `SwagBag/UI/QuickSetup.lua` (edit 2 of 7), find:

```lua
local function finish(fn)
```

and replace it with:

```lua
local function finish(fn, offer)
```

In `SwagBag/UI/QuickSetup.lua` (edit 3 of 7), find:

```lua
		QS.Close("done")
```

and replace it with:

```lua
		QS.Close("done")
		if offer and SB.Tour and not SB.Adapter.InCombat() then
			QS.offer:Show() -- the tour, offered once at the end (AC7.3)
		end
```

In `SwagBag/UI/QuickSetup.lua` (edit 4 of 7), find:

```lua
	finish(Setup.Finish)
```

and replace it with:

```lua
	finish(Setup.Finish, true)
```

In `SwagBag/UI/QuickSetup.lua` (edit 5 of 7), find:

```lua
end

-- A fresh draft from the settings as they are (a re-run starts from the styles picked last time), at step 1.
```

and replace it with:

```lua
end

-- The tour offer after Finish (week 12, AC7.3): a small note of its own, so the wizard is closed by then. "Show me
-- around" starts the tour and says what it said; "No thanks", Esc, the X or combat starting say how to get it later.
local offer = CreateFrame("Frame", "SwagBagTourOffer", UIParent, "BackdropTemplate")
offer:SetFrameStrata("DIALOG")
offer:SetToplevel(true)
offer:SetClampedToScreen(true)
offer:EnableMouse(true)
offer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
offer:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
offer:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
offer:SetSize(360, 110)
offer:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
offer:Hide()
QS.offer = offer
table.insert(UISpecialFrames, "SwagBagTourOffer")
offer.text = text(offer, "GameFontHighlight", 14, -14, 332)
offer.text:SetText(L.WIZ_TOUR_ASK)
QS.tourButton = button(offer, 150, 14, -72, L.WIZ_TOUR_YES, function()
	QS.offerAnswered = true
	offer:Hide()
	SB.Print(SB.Tour.Start())
end)
QS.noTourButton = button(offer, 150, 196, -72, L.WIZ_TOUR_NO, function()
	offer:Hide()
end)
if SB.Theme then
	SB.Theme.Window(offer, "dialog")
	SB.Theme.Text(offer.text, "body")
end
offer:SetScript("OnHide", Guard("setup.offerHide", function(self)
	if self:IsShown() then
		return
	end
	if not QS.offerAnswered then
		SB.Print(L.WIZ_TOUR_LATER)
	end
	QS.offerAnswered = nil
end, "none"))

-- A fresh draft from the settings as they are (a re-run starts from the styles picked last time), at step 1.
```

In `SwagBag/UI/QuickSetup.lua` (edit 6 of 7), find:

```lua
SB.On("PLAYER_REGEN_DISABLED", function()
```

and replace it with:

```lua
SB.On("PLAYER_REGEN_DISABLED", function()
	if offer:IsShown() then
		offer:Hide() -- no tour in a fight; the line says how to get it later
	end
```

In `SwagBag/UI/QuickSetup.lua` (edit 7 of 7), find:

```lua
end)

SB.Slash.Register("tour", L.HELP_TOUR, function()
	return L.TOUR_LATER
end)
```

and replace it with:

```lua
end)
```

Create `SwagBag/UI/Tour.lua`:

```lua
-- SwagBag guided tour (spec F7, AC7.3; week 12). /swagbag tour, any time, shows the bag window's parts one at a time,
-- each with a small note next to it and a thin gold frame around it: the section headers, collapsing a section, focus
-- modes and peeking, the search box, the mode title and Pause, Sort, and Safe Mode. Back, Next and End on the note.
-- It only points: it never clicks, moves, sorts or lays out anything (P5). It never covers a fight: it ends when
-- combat starts, and when the bags close, with one chat line either way. A part that is not drawn (the grid view has
-- no section headers) gets its note beside the bag window, with the same words. Plain frames only.
--   Tour.Start() -> feedback        opens the bags if they are closed; refuses in combat, while the bags are
--                                   Blizzard's (Safe Mode), or when they can't open
--   Tour.Next() / Tour.Back()       the next or previous note; Next on the last one ends the tour (said once)
--   Tour.End(reason) -> bool        "done" | "ended" | "closed" | "combat": the note goes and one line says so;
--                                   false when no tour runs
--   Tour.step, Tour.target          the note shown (nil: no tour) and what it points at
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local Tour = { step = nil, target = nil }
SB.Tour = Tour

-- The bags window's first section header (the bank's and the guild bank's headers have other parents); show() checks
-- that it is drawn.
local function firstHeader()
	local W, H = SB.BagsWindow, SB.SectionHeaders
	if not (W and W.child and H and H.inUse) then
		return nil
	end
	for _, h in ipairs(H.inUse) do
		if h:GetParent() == W.child then
			return h
		end
	end
	return nil
end

local function bagsPart(name)
	return function()
		return SB.BagsWindow and SB.BagsWindow[name]
	end
end

-- The notes, in order. target() -> the frame the note points at, or nil (the note sits beside the window).
Tour.STEPS = {
	{ id = "headers", text = "TOUR_HEADERS", target = firstHeader },
	{ id = "collapse", text = "TOUR_COLLAPSE", target = firstHeader },
	{ id = "peek", text = "TOUR_PEEK", target = firstHeader },
	{ id = "search", text = "TOUR_SEARCH", target = function()
		return SB.SearchBox and SB.SearchBox.editBox
	end },
	{ id = "modes", text = "TOUR_MODES", target = bagsPart("modeButton") },
	{ id = "sort", text = "TOUR_SORT", target = bagsPart("sortButton") },
	{ id = "safe", text = "TOUR_SAFE" },
}

local frame = CreateFrame("Frame", "SwagBagTour", UIParent, "BackdropTemplate")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
frame:SetBackdropBorderColor(1, 0.82, 0, 1)
frame:SetSize(300, 150)
frame:Hide()
Tour.frame = frame
table.insert(UISpecialFrames, "SwagBagTour") -- Esc ends the tour

frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.count:SetPoint("TOPLEFT", 10, -8)
frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.text:SetPoint("TOPLEFT", 10, -26)
frame.text:SetWidth(280)
frame.text:SetJustifyH("LEFT")
frame.text:SetWordWrap(true)

-- The thin gold frame around what the note points at. It takes no mouse: everything under it works as usual.
local ring = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
ring:SetFrameStrata("DIALOG")
ring:EnableMouse(false)
ring:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
ring:SetBackdropBorderColor(1, 0.82, 0, 1)
ring:Hide()
Tour.ring = ring

local function button(label, x, fn, name)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(80, 22)
	b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 10)
	b:SetText(label)
	b:SetScript("OnClick", Guard(name, fn, "none"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	return b
end
Tour.backButton = button(L.TOUR_BACK, 10, function()
	Tour.Back()
end, "tour.back")
Tour.nextButton = button(L.TOUR_NEXT, 110, function()
	Tour.Next()
end, "tour.next")
Tour.endButton = button(L.TOUR_END, 210, function()
	Tour.End("ended")
end, "tour.end")
if SB.Theme then
	SB.Theme.Window(frame, "dialog")
	SB.Theme.Text(frame.count, "small")
	SB.Theme.Text(frame.text, "body")
end

-- Draw the note of the current step, next to its part (or beside the window when the part is not drawn).
local function show()
	local s = Tour.STEPS[Tour.step]
	local target = s.target and s.target() or nil
	if not (target and target:IsShown()) then
		target = nil
	end
	frame.count:SetText(L.TOUR_COUNT:format(Tour.step, #Tour.STEPS))
	frame.text:SetText(L[s.text])
	frame:ClearAllPoints()
	ring:ClearAllPoints()
	if target then
		frame:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 10)
		ring:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
		ring:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
		ring:Show()
	else
		frame:SetPoint("TOPRIGHT", SB.BagsWindow.frame, "TOPLEFT", -10, 0)
		ring:Hide()
	end
	Tour.target = target or SB.BagsWindow.frame
	Tour.backButton:SetShown(Tour.step > 1)
	Tour.nextButton:SetText(Tour.step == #Tour.STEPS and L.TOUR_DONE or L.TOUR_NEXT)
	frame:Show()
end

function Tour.Start()
	local W = SB.BagsWindow
	if SB.Adapter.InCombat() then
		return L.TOUR_COMBAT
	elseif not W or SB.SafeMode.IsOn("bags") then
		return L.TOUR_SAFE_MODE
	elseif not W.IsOpen() and not W.Open() then
		return L.TOUR_NO_BAGS
	end
	Tour.step = 1
	show()
	return L.TOUR_STARTED
end

function Tour.Next()
	if not Tour.step then
		return
	end
	if Tour.step >= #Tour.STEPS then
		Tour.End("done")
		return
	end
	Tour.step = Tour.step + 1
	show()
end

function Tour.Back()
	if Tour.step and Tour.step > 1 then
		Tour.step = Tour.step - 1
		show()
	end
end

local ENDS = { done = "TOUR_FINISHED", ended = "TOUR_ENDED", closed = "TOUR_ENDED_CLOSED", combat = "TOUR_ENDED_COMBAT" }

function Tour.End(reason)
	if not Tour.step then
		return false
	end
	Tour.step, Tour.target = nil, nil
	ring:Hide()
	frame:Hide()
	SB.Print(L[ENDS[reason] or ENDS.ended])
	return true
end

-- Esc (or anything else hiding the note) ends the tour, once. The guard first: Alt+Z hides UIParent, not the note.
frame:SetScript("OnHide", Guard("tour.hide", function(self)
	if not self:IsShown() and Tour.step then
		Tour.End("ended")
	end
end, "none"))

SB.On("SB_BAGS_CLOSED", function()
	Tour.End("closed")
end, "none")

-- Combat starts: the note goes at once (it never covers a fight). Hiding a plain frame is allowed in combat.
SB.On("PLAYER_REGEN_DISABLED", function()
	Tour.End("combat")
end, "none")

-- The bags were laid out again (a view change, Reflow): the parts may be other frames now, so point again.
SB.On("SB_BAGS_LAYOUT", function()
	if Tour.step then
		show()
	end
end, "none")

SB.Slash.Register("tour", L.HELP_TOUR, function()
	return Tour.Start()
end)
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1642 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (81 files)`, `1642 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/QuickSetup.lua \
	SwagBag/UI/Tour.lua \
	spec/quicksetup_spec.lua \
	spec/tour_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 12 Task 3: the guided tour, offered after the wizard

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 4: Focus modes of your own: the engine and /swagbag mode on / off (Engine/Focus.lua)

AC8.7 in the engine. `Focus.TRIGGERS` (D14) is "Only when I switch it on" and ten built-in signals, each a one-line test over the signals `Engine/Signals.lua` already reads, with a class for strict priority (D16). `Focus.LoadCustom()` reads `SwagBagDB.modes` defensively into `Focus.custom` (made order, ten at most) on every `Focus.Refresh`; `Focus.All()` is the built-ins then yours; `Active`, the labels, the priority and the views look a mode up with `Focus.Mode(id)`, so a mode of your own behaves exactly as a built-in one. The writers (D13, D17, D18) check the name (`CheckName`), make (`CreateMode`, writing the new mode's switch and empty sections as explicit settings), rename, change the trigger, delete (its switch and sections leave the account and this character's overrides; the id stays `false`) and switch a manual mode on or off for this session (`SetManual`, D15). `/swagbag mode on <name>`, `off` and `off <name>` answer every form; `/swagbag mode list` names your modes too. `Categories.Delete` now cleans every mode's sections, yours included.

**Files:**
- Create: `spec/focus_custom_spec.lua`
- Modify: `SwagBag/Engine/Focus.lua`, `SwagBag/Engine/Categories.lua` (Delete), `SwagBag/Locale/enUS.lua` (`MODE_MANUAL_*`, `MODE_LIST_MANUAL`, `TRIGGER_*`; `MODE_USAGE` and `HELP_MODE` name on / off)

**Interfaces:**
- Consumes: `SB.Config.db/charDB/Get/Set/readOnly/CharOverride`, `SB.Emit("SB_CONFIG_CHANGED", "focus.modes")` (the existing listener refreshes on any `focus.*` path), `SB.Categories.Get/Name/FREE`.
- Produces: `Focus.TRIGGERS` (`{ id, name, class, test }`), `Focus.MAX_CUSTOM = 10`, `Focus.MAX_NAME = 24`, `Focus.custom` (`{ id, name, custom = true, triggerId, class, n, trigger }`), `Focus.manual`, `Focus.All()`, `Focus.Mode(id)`, `Focus.IsCustom(id)`, `Focus.NameOf(id)`, `Focus.ManualOn(id)`, `Focus.LoadCustom()`, `Focus.CheckName(name, exceptId) -> name | nil, why`, `Focus.CreateMode(name, trigger) -> id | nil, why`, `Focus.RenameMode(id, name)`, `Focus.SetTrigger(id, trigger)`, `Focus.DeleteMode(id)` (each `-> ok, why`), `Focus.SetManual(id, on) -> ok, changed | why`, `Focus.FindMode(name) -> id`, `Focus.CustomNames(manualOnly) -> { names }`; whys `"empty" | "long" | "code" | "builtin" | "taken" | "full" | "trigger" | "readonly" | "unknown" | "notmanual"`; `SwagBagDB.modes`.

- [ ] **Step 1: Write the failing tests**

Create `spec/focus_custom_spec.lua`:

```lua
-- Week 12 (spec AC8.7, 6.3): focus modes of the user's own (Engine/Focus.lua): a name, a trigger (manual, or one of
-- the built-in signals) and a section set; switched on and off by hand when manual; merge and strict priority with
-- the built-ins; delete; stored modes read defensively; /swagbag mode on / off / list.
local Loader = dofile("spec/helpers/loader.lua")
local Env = dofile("spec/helpers/uienv.lua")

local ORDER = { "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
	"c_junk", "c_other", "free" }

describe("Focus modes of your own (week 12)", function()
	local SB, F, C, L, events
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		F, C, L = SB.Focus, SB.Config, SB.L
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason)
			events[#events + 1] = reason
		end)
	end)

	-- AC8.7. Mutation: in Focus.LoadCustom, the manual trigger `return Focus.manual[mid] == true` -> `return false`.
	it("AC8.7: a manual mode: made with a name, off until switched on; then its sections move up; off again", function()
		local id = F.CreateMode("Farming")
		assert.equal("m_farming", id)
		assert.same({ name = "Farming", trigger = "manual", n = 1 }, C.db.modes[id])
		assert.same({ true, "" }, { C.db.settings.focus.on[id], C.db.settings.focus.sections[id] },
			"its switch and sections are explicit from the start (This character only can copy them)")
		assert.truthy(F.SetSections(id, { "c_herbs", "c_ore" }))
		assert.same({}, F.Active())
		assert.same({ true, true }, { F.SetManual(id, true) })
		assert.same({ id }, F.Active())
		assert.equal("Farming", F.Label())
		assert.same({ "new", "c_herbs", "c_ore", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_junk",
			"c_other", "free" }, F.SectionOrder(ORDER))
		assert.same({ true, false }, { F.SetManual(id, true) }, "already on: nothing changes")
		F.SetManual(id, false)
		assert.same({}, F.Active())
		assert.equal(ORDER, F.SectionOrder(ORDER))
		assert.same({ "settings", "settings", "signal", "signal" }, events, "made, sections set, on, off")
	end)

	-- Mutation: in Focus.TRIGGERS, the pvp test `return s.instanceType == "pvp" or s.instanceType == "arena"` ->
	-- `return s.instanceType == "pvp"`.
	it("each built-in signal a mode can use switches it on exactly while that signal holds", function()
		local when = {
			mplus = { challengeMode = true }, dungeon = { instanceType = "party" }, raid = { instanceType = "raid" },
			delve = { delve = true }, pvp = { instanceType = "arena" }, fishing = { fishing = true },
			gathering = { gathering = true }, vendor = { merchantOpen = true }, auction = { auctionOpen = true },
			bank = { bankOpen = true },
		}
		local ids = {}
		for _, t in ipairs(F.TRIGGERS) do
			assert.truthy(rawget(L, t.name), t.name)
			if t.id ~= "manual" then
				ids[t.id] = F.CreateMode("Mine " .. t.id, t.id)
				assert.truthy(ids[t.id], t.id)
			end
		end
		for trig, signals in pairs(when) do
			F.signals = {}
			for k, v in pairs(signals) do
				F.signals[k] = v
			end
			F.Recompute("signal")
			local mine = {}
			for _, id in ipairs(F.Active()) do
				if F.IsCustom(id) then
					mine[#mine + 1] = id
				end
			end
			assert.same({ ids[trig] }, mine, trig)
		end
	end)

	-- AC8.4 with modes of your own. Mutation: in CLASS_RANK, `manual = 4` -> `manual = 0`.
	it("merge opens the union with the built-ins; strict priority: a manual mode you switched on decides first", function()
		local farm = F.CreateMode("Farm")
		local dump = F.CreateMode("Vendor dump", "vendor")
		F.SetSections(farm, { "c_herbs" })
		F.SetSections(dump, { "c_junk" })
		F.SetSignal("challengeMode", true)
		F.SetManual(farm, true)
		assert.same({ "mplus", farm }, F.Active())
		assert.equal("M+ + Farm", F.Label())
		C.Set("focus.resolve", "priority")
		assert.equal("Farm", F.Label())
		assert.same({ "c_herbs" }, F.Front())
		F.SetManual(farm, false)
		F.SetSignal("challengeMode", false)
		F.SetSignal("instanceType", "raid")
		F.SetSignal("merchantOpen", true)
		assert.equal("Raid", F.Label(), "activity beats location")
		F.SetSignal("instanceType", nil)
		assert.equal("AH/Vendor/Bank", F.Label(), "same class: the built-in first")
		C.Set("focus.resolve", "merge")
		assert.equal("AH/Vendor/Bank + Vendor dump", F.Label())
	end)

	-- Mutation: in Focus.Active, `(auto or m.class == "manual")` -> `auto`.
	it("with Switch by themselves off, only a manual mode you switched on applies; Pause stops it too", function()
		local farm = F.CreateMode("Farm")
		local dump = F.CreateMode("Vendor dump", "vendor")
		C.Set("focus.auto", false)
		F.SetSignal("merchantOpen", true)
		F.SetManual(farm, true)
		assert.same({ farm }, F.Active())
		assert.truthy(dump)
		F.Pause()
		assert.equal(L.FOCUS_PAUSED, F.Label())
		assert.is_nil(F.Front())
	end)

	-- Mutation: in Focus.CheckName, drop the `if low == SB.L[m.name]:lower() or low == m.id then` check.
	it("names: refused when empty, too long, a chat code, a built-in mode's name (any case), or another of yours", function()
		assert.same({ nil, "empty" }, { F.CreateMode("   ") })
		assert.same({ nil, "long" }, { F.CreateMode(string.rep("a", 25)) })
		assert.truthy(F.CreateMode(string.rep("a", 24)))
		assert.same({ nil, "code" }, { F.CreateMode("Red|cffff0000") })
		assert.same({ nil, "builtin" }, { F.CreateMode("raid") })
		assert.same({ nil, "builtin" }, { F.CreateMode("ah/vendor/bank") })
		assert.same({ nil, "builtin" }, { F.CreateMode("mplus") })
		local id = F.CreateMode("  Farming ")
		assert.equal("Farming", F.NameOf(id))
		assert.same({ nil, "taken" }, { F.CreateMode("FARMING") })
		assert.same({ nil, "trigger" }, { F.CreateMode("Other", "always") })
		assert.same({ false, "taken" }, { F.RenameMode(F.CreateMode("Second"), "farming") })
		assert.truthy(F.RenameMode(id, "farming"), "its own name in another case")
		assert.equal("farming", F.NameOf(id))
		assert.equal(id, F.FindMode(" FARMING "))
		assert.equal("raid", F.FindMode("Raid"))
	end)

	-- Mutation: in Focus.CreateMode, drop the `elseif #Focus.custom >= Focus.MAX_CUSTOM then return nil, "full"` check.
	it("at most ten modes of your own; ids follow the name and are never given twice", function()
		for i = 1, 10 do
			assert.truthy(F.CreateMode("Mode " .. i))
		end
		assert.same({ nil, "full" }, { F.CreateMode("Eleven") })
		assert.truthy(F.DeleteMode("m_mode_1"))
		assert.equal("m_mode_1_2", F.CreateMode("Mode 1"), "a deleted mode's id stays taken")
		F.DeleteMode("m_mode_2")
		assert.equal("m_mode", F.CreateMode("???"), "a name with no letters still gets an id")
	end)

	-- Mutation: in Focus.DeleteMode, drop `C.charDB.overrides["focus." .. kind .. "." .. id] = nil`.
	it("delete: the mode, its switch and its sections go (the account's and this character's); it is no longer on", function()
		local id = F.CreateMode("Farm")
		F.SetSections(id, { "c_herbs" })
		F.SetEnabled(id, true)
		C.CharOverride("focus.sections." .. id, true)
		F.SetSections(id, { "c_ore" })
		F.SetManual(id, true)
		events = {}
		assert.truthy(F.DeleteMode(id))
		assert.equal(false, C.db.modes[id])
		assert.is_nil(C.db.settings.focus.sections[id])
		assert.is_nil(C.db.settings.focus.on[id])
		assert.is_nil(C.charDB.overrides["focus.sections." .. id])
		assert.same({}, F.Active())
		assert.is_nil(F.Mode(id))
		assert.same({ "settings" }, events, "the open bags follow once")
		assert.same({ false, "unknown" }, { F.DeleteMode(id) })
		assert.same({ false, "unknown" }, { F.SetManual(id, true) })
	end)

	-- Mutation: in Categories.Delete, drop the `for mode in pairs(account) do` loop (a mode of yours would keep the id).
	it("deleting a category takes it out of your own modes' sections too, the account's and this character's", function()
		SB.Categories.Load()
		local cat = SB.Categories.Create("Pots", "potion")
		local id = F.CreateMode("Farm")
		local other = F.CreateMode("Other")
		F.SetSections(id, { cat, "c_herbs" })
		C.CharOverride("focus.sections." .. other, true)
		F.SetSections(other, { "c_ore", cat })
		assert.truthy(SB.Categories.Delete(cat))
		assert.same({ "c_herbs" }, F.Sections(id))
		assert.same({ "c_ore" }, F.Sections(other))
	end)

	-- Mutation: in manualCommand, drop the `if not ok then return L.MODE_MANUAL_AUTO:format(name)` branch.
	it("/swagbag mode on <name> and off: every form answers once; a mode that switches by itself is not switched here", function()
		local id = F.CreateMode("Farming")
		F.CreateMode("Vendor dump", "vendor")
		local function run(line)
			return select(2, SB.Slash.Run(line))
		end
		assert.equal(L.MODE_MANUAL_USAGE:format("Farming"), run("mode on"))
		assert.equal(L.MODE_MANUAL_ON:format("Farming"), run("mode on farming"))
		assert.truthy(F.ManualOn(id))
		assert.equal(L.MODE_MANUAL_ALREADY_ON:format("Farming"), run("mode on Farming"))
		assert.equal(L.MODE_MANUAL_AUTO:format("Vendor dump"), run("mode on vendor dump"))
		assert.equal(L.MODE_MANUAL_AUTO:format("Raid"), run("mode off raid"))
		assert.equal(L.MODE_MANUAL_UNKNOWN:format("fish", "Farming"), run("mode on fish"))
		assert.equal(L.MODE_MANUAL_ALL_OFF:format("Farming"), run("mode off"))
		assert.equal(L.MODE_MANUAL_NONE_ON, run("mode off"))
		assert.equal(L.MODE_MANUAL_ALREADY_OFF:format("Farming"), run("mode off farming"))
		F.Pause()
		assert.same({ L.MODE_MANUAL_ON:format("Farming"), L.MODE_MANUAL_PAUSED }, run("mode on farming"))
		assert.truthy(L.MODE_USAGE:find("on <your mode>", 1, true))
	end)

	-- Mutation: in Focus.ListLines, iterate `Focus.MODES` instead of `Focus.All()`.
	it("/swagbag mode list names your own modes after the built-ins, a manual one as such", function()
		local id = F.CreateMode("Farming")
		F.SetSections(id, { "c_herbs" })
		F.CreateMode("Vendor dump", "vendor")
		F.SetManual(id, true)
		local lines = F.ListLines()
		assert.equal(8, #lines)
		assert.equal(L.MODE_LIST_LINE:format("Farming (you switch it)", L.OVERLAY_ON, L.MODE_ACTIVE, "Herbs"), lines[7])
		assert.equal(L.MODE_LIST_LINE:format("Vendor dump", L.OVERLAY_ON, "", L.REPORT_NONE), lines[8])
	end)

	-- Mutation: in Focus.LoadCustom, drop `and cleanName(def.name) == def.name` (a damaged name would be shown).
	it("stored modes are read defensively: damaged entries skipped, an unknown trigger is manual, ten at most", function()
		local modes = {
			m_ok = { name = "Okay", trigger = "bank", n = 2 }, m_first = { name = "First", trigger = "weird", n = 1 },
			bad = { name = "No prefix", trigger = "bank" }, m_junk = "junk", m_code = { name = "a|Hlink", trigger = "bank" },
			m_gone = false, m_blank = { name = "", trigger = "manual" },
		}
		for i = 1, 12 do
			modes["m_extra" .. i] = { name = "Extra " .. i, n = 10 + i }
		end
		C.Init({ schemaVersion = 2, settings = {}, modes = modes }, nil)
		assert.equal(10, #F.custom)
		assert.same({ "m_first", "m_ok" }, { F.custom[1].id, F.custom[2].id })
		assert.equal("manual", F.custom[1].triggerId)
		assert.equal("location", F.custom[2].class)
		C.Init({ schemaVersion = 2, settings = {}, modes = "damaged" }, nil)
		assert.same({}, F.custom)
		C.Init({ schemaVersion = 2, settings = { focus = { auto = true } } }, nil)
		assert.same({}, F.custom, "a week-11 save: no modes of your own, nothing written")
		assert.is_nil(C.db.modes)
	end)

	-- Mutation: in ownMode, drop the `elseif SB.Config.readOnly then return "readonly"` branch.
	it("read-only settings: every writer refuses and changes nothing", function()
		local id = F.CreateMode("Farm")
		C.readOnly = true
		assert.same({ nil, "readonly" }, { F.CreateMode("Other") })
		assert.same({ false, "readonly" }, { F.RenameMode(id, "Other") })
		assert.same({ false, "readonly" }, { F.SetTrigger(id, "bank") })
		assert.same({ false, "readonly" }, { F.DeleteMode(id) })
		assert.same({ false, "readonly" }, { F.SetSections(id, { "c_ore" }) })
		C.readOnly = false
		assert.equal("Farm", F.NameOf(id))
		assert.equal("manual", F.Mode(id).triggerId)
	end)

	it("Recompute with the six built-ins and ten modes of your own stays well under 0.5 ms (spec 6.5)", function()
		for i = 1, 10 do
			F.CreateMode("Mode " .. i, i % 2 == 0 and "fishing" or "manual")
		end
		local t0 = os.clock()
		for i = 1, 1000 do
			F.SetSignal("fishing", i % 2 == 0)
		end
		local perCall = (os.clock() - t0) * 1000 / 1000
		assert.truthy(perCall < 0.5, ("%.3f ms per Recompute"):format(perCall))
	end)
end)
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1642 passed, 13 failed`. The failures, exactly:

- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > AC8.7: a manual mode: made with a name, off until switched on; then its sections move up; off again`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > each built-in signal a mode can use switches it on exactly while that signal holds`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > merge opens the union with the built-ins; strict priority: a manual mode you switched on decides first`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > with Switch by themselves off, only a manual mode you switched on applies; Pause stops it too`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > names: refused when empty, too long, a chat code, a built-in mode's name (any case), or another of yours`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > at most ten modes of your own; ids follow the name and are never given twice`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > delete: the mode, its switch and its sections go (the account's and this character's); it is no longer on`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > deleting a category takes it out of your own modes' sections too, the account's and this character's`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > /swagbag mode on <name> and off: every form answers once; a mode that switches by itself is not switched here`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > /swagbag mode list names your own modes after the built-ins, a manual one as such`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > stored modes are read defensively: damaged entries skipped, an unknown trigger is manual, ten at most`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > read-only settings: every writer refuses and changes nothing`
- `spec/focus_custom_spec.lua :: Focus modes of your own (week 12) > Recompute with the six built-ins and ten modes of your own stays well under 0.5 ms (spec 6.5)`

`Focus.CreateMode` does not exist yet: every test calls it (or loads modes it does not read), and errors.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "AC8.7: a manual mode: made with a name, off until switched on; then its sections move up; off again": in `SwagBag/Engine/Focus.lua`, `return Focus.manual[mid] == true` → `return false`.
- "AC8.7: a manual mode: made with a name, off until switched on; then its sections move up; off again": in `SwagBag/Engine/Focus.lua`, `for kind, v in pairs({ on = true, sections = "" }) do` → `for kind, v in pairs({}) do`.
- "each built-in signal a mode can use switches it on exactly while that signal holds": in `SwagBag/Engine/Focus.lua`, `return s.instanceType == "pvp" or s.instanceType == "arena"` → `return s.instanceType == "pvp"`.
- "merge opens the union with the built-ins; strict priority: a manual mode you switched on decides first": in `SwagBag/Engine/Focus.lua`, `local CLASS_RANK = { manual = 4, combat = 3, activity = 2, location = 1 }` → `local CLASS_RANK = { manual = 0, combat = 3, activity = 2, location = 1 }`.
- "with Switch by themselves off, only a manual mode you switched on applies; Pause stops it too": in `SwagBag/Engine/Focus.lua`, `if (auto or m.class == "manual") and` → `if auto and`.
- "names: refused when empty, too long, a chat code, a built-in mode's name (any case), or another of yours": in `SwagBag/Engine/Focus.lua`, `if low == SB.L[m.name]:lower() or low == m.id then` → `if false then`.
- "at most ten modes of your own; ids follow the name and are never given twice": in `SwagBag/Engine/Focus.lua`, `elseif #Focus.custom >= Focus.MAX_CUSTOM then` → `elseif false then`.
- "delete: the mode, its switch and its sections go (the account's and this character's); it is no longer on": in `SwagBag/Engine/Focus.lua`, `C.charDB.overrides["focus." .. kind .. "." .. id] = nil` → ∅.
- "deleting a category takes it out of your own modes' sections too, the account's and this character's": in `SwagBag/Engine/Categories.lua`, `modes[mode] = true -- week 12: the user's own focus modes too (AC8.7)` → ∅.
- "/swagbag mode on <name> and off: every form answers once; a mode that switches by itself is not switched here": in `SwagBag/Engine/Focus.lua`, `return L.MODE_MANUAL_AUTO:format(name)` → `return L.MODE_MANUAL_UNKNOWN:format(name, manualList())`.
- "/swagbag mode list names your own modes after the built-ins, a manual one as such": in `SwagBag/Engine/Focus.lua`, `for _, m in ipairs(Focus.All()) do ⏎ local name, on = Focus.NameOf(m.id), Focus.IsEnabled(m.id)` → `for _, m in ipairs(Focus.MODES) do ⏎ local name, on = Focus.NameOf(m.id), Focus.IsEnabled(m.id)`.
- "stored modes are read defensively: damaged entries skipped, an unknown trigger is manual, ten at most": in `SwagBag/Engine/Focus.lua`, `and cleanName(def.name) == def.name then` → `then`.
- "read-only settings: every writer refuses and changes nothing": in `SwagBag/Engine/Focus.lua`, `if not customById[id] then ⏎ return "unknown" ⏎ elseif SB.Config.readOnly then` → `if not customById[id] then ⏎ return "unknown" ⏎ elseif false then`.

- [ ] **Step 3: Write the code**

In `SwagBag/Engine/Categories.lua`, find:

```lua
	for mode in pairs(Cfg.Defaults.settings.focus.sections) do
```

and replace it with:

```lua
	local modes = {}
	for mode in pairs(Cfg.Defaults.settings.focus.sections) do
		modes[mode] = true
	end
	for mode in pairs(account) do
		modes[mode] = true -- week 12: the user's own focus modes too (AC8.7)
	end
	for path in pairs(Cfg.charDB.overrides) do
		local mode = type(path) == "string" and path:match("^focus%.sections%.(.+)$")
		if mode then
			modes[mode] = true
		end
	end
	for mode in pairs(modes) do
```

In `SwagBag/Engine/Focus.lua` (edit 1 of 15), find:

```lua
--   Focus.ListLines() -> { lines }               one chat line per mode (/swagbag mode list)
```

and replace it with:

```lua
--   Focus.ListLines() -> { lines }               one chat line per mode (/swagbag mode list)
-- Week 12 (AC8.7): the user's own modes, next to the six built-ins (Focus.All() lists both, built-ins first):
--   Focus.TRIGGERS                               when one switches on: "manual" (only when the user says so), or one
--                                                of the built-in signals (a key, a dungeon, a raid, a delve, PvP,
--                                                fishing, gathering, a vendor, the auction house, the bank)
--   Focus.CheckName(name, exceptId) -> name | nil, why   why: "empty" | "long" | "code" | "builtin" | "taken"
--   Focus.CreateMode(name, trigger) -> id | nil, why     why also "readonly" | "full" | "trigger"
--   Focus.RenameMode(id, name), Focus.SetTrigger(id, trigger), Focus.DeleteMode(id) -> ok, why ("unknown" too)
--   Focus.SetManual(id, on) -> ok, why           a manual mode on or off, for this session ("notmanual")
--   Focus.Mode(id), Focus.NameOf(id), Focus.FindMode(name) -> id, Focus.IsCustom(id), Focus.ManualOn(id)
-- Stored account-wide in SwagBagDB.modes (schema 2, no migration, read defensively: Focus.LoadCustom):
-- modes[id] = { name, trigger, n = the order it was made in }; a deleted one stays false, so its id (m_<name>) is
-- never given again (another character's own sections can still name it). A mode's on/off and sections are the
-- ordinary settings focus.on.<id> and focus.sections.<id>, so "This character only" and profiles treat them as the
-- built-ins'. A manual mode is on only while the user has switched it on (this session: a log out or reload ends it);
-- it does not need "Switch by themselves" (focus.auto), but Pause stops it like every mode. In strict priority a manual
-- mode the user switched on decides first, then combat > activity > location; within a class, built-ins first.
```

In `SwagBag/Engine/Focus.lua` (edit 2 of 15), find:

```lua
local CLASS_RANK = { combat = 3, activity = 2, location = 1 }
```

and replace it with:

```lua
local CLASS_RANK = { manual = 4, combat = 3, activity = 2, location = 1 }
```

In `SwagBag/Engine/Focus.lua` (edit 3 of 15), find:

```lua
Focus.byId = byId

-- Gathering opens only the materials of the gathering professions the character has
```

and replace it with:

```lua
Focus.byId = byId

-- Week 12 (AC8.7): what a mode of the user's can switch on with. class decides strict priority, as for the built-ins.
Focus.TRIGGERS = {
	{ id = "manual", name = "TRIGGER_MANUAL", class = "manual" },
	{ id = "mplus", name = "TRIGGER_MPLUS", class = "activity", test = function(s)
		return s.challengeMode == true
	end },
	{ id = "dungeon", name = "TRIGGER_DUNGEON", class = "activity", test = function(s)
		return s.instanceType == "party"
	end },
	{ id = "raid", name = "TRIGGER_RAID", class = "activity", test = function(s)
		return s.instanceType == "raid"
	end },
	{ id = "delve", name = "TRIGGER_DELVE", class = "activity", test = function(s)
		return s.delve == true
	end },
	{ id = "pvp", name = "TRIGGER_PVP", class = "activity", test = function(s)
		return s.instanceType == "pvp" or s.instanceType == "arena"
	end },
	{ id = "fishing", name = "TRIGGER_FISHING", class = "activity", test = function(s)
		return s.fishing == true
	end },
	{ id = "gathering", name = "TRIGGER_GATHERING", class = "activity", test = function(s)
		return s.gathering == true
	end },
	{ id = "vendor", name = "TRIGGER_VENDOR", class = "location", test = function(s)
		return s.merchantOpen == true
	end },
	{ id = "auction", name = "TRIGGER_AUCTION", class = "location", test = function(s)
		return s.auctionOpen == true
	end },
	{ id = "bank", name = "TRIGGER_BANK", class = "location", test = function(s)
		return s.bankOpen == true
	end },
}
local TRIGGER = {}
for _, t in ipairs(Focus.TRIGGERS) do
	TRIGGER[t.id] = t
end
Focus.MAX_CUSTOM, Focus.MAX_NAME = 10, 24
Focus.custom, Focus.manual = {}, {} -- the user's modes (made order), and the manual ones switched on now
local customById = {}

-- A mode by id: a built-in, or one of the user's.
local function mode(id)
	return byId[id] or customById[id]
end
Focus.Mode = mode

function Focus.IsCustom(id)
	return customById[id] ~= nil
end

function Focus.NameOf(id)
	local m = mode(id)
	if not m then
		return tostring(id)
	end
	return m.custom and m.name or SB.L[m.name]
end

-- Built-ins first, then the user's modes in the order they were made.
function Focus.All()
	local out = {}
	for _, m in ipairs(Focus.MODES) do
		out[#out + 1] = m
	end
	for _, m in ipairs(Focus.custom) do
		out[#out + 1] = m
	end
	return out
end

function Focus.ManualOn(id)
	return Focus.manual[id] == true
end

local function cleanName(name)
	name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
	if name == "" then
		return nil, "empty"
	elseif #name > Focus.MAX_NAME then
		return nil, "long"
	elseif name:find("[%c|]") then
		return nil, "code"
	end
	return name
end

-- The user's modes as stored, read defensively: a damaged entry is skipped, an unknown trigger reads as manual, and
-- no more than MAX_CUSTOM are used. Called by Refresh (every focus setting change, a new Init) and the writers.
function Focus.LoadCustom()
	local list, stored = {}, SB.Config.db and SB.Config.db.modes
	for id, def in pairs(type(stored) == "table" and stored or {}) do
		if type(id) == "string" and #id <= 40 and id:match("^m_[%w_]+$") and type(def) == "table"
			and cleanName(def.name) == def.name then
			local t = TRIGGER[def.trigger] or TRIGGER.manual
			local mid = id
			list[#list + 1] = { id = id, name = def.name, custom = true, triggerId = t.id, class = t.class,
				n = tonumber(def.n) or 0, trigger = t.test or function()
					return Focus.manual[mid] == true
				end }
		end
	end
	table.sort(list, function(a, b)
		if a.n ~= b.n then
			return a.n < b.n
		end
		return a.id < b.id
	end)
	while #list > Focus.MAX_CUSTOM do
		table.remove(list)
	end
	customById = {}
	for _, m in ipairs(list) do
		customById[m.id] = m
	end
	Focus.custom = list
	for id in pairs(Focus.manual) do
		local m = customById[id]
		if not (m and m.triggerId == "manual") then
			Focus.manual[id] = nil -- a mode that is gone, or no longer manual, is not "switched on"
		end
	end
end

-- Gathering opens only the materials of the gathering professions the character has
```

In `SwagBag/Engine/Focus.lua` (edit 4 of 15), find:

```lua
function Focus.Active()
	local out = {}
	if cfg("focus.auto") == false then
		return out
	end
	for _, m in ipairs(Focus.MODES) do
		if Focus.IsEnabled(m.id) and m.trigger(Focus.signals) then
```

and replace it with:

```lua
-- With "Switch by themselves" off only the user's manual modes can be on: the user switched them on.
function Focus.Active()
	local out = {}
	local auto = cfg("focus.auto") ~= false
	for _, m in ipairs(Focus.MODES) do
		if auto and Focus.IsEnabled(m.id) and m.trigger(Focus.signals) then
			out[#out + 1] = m.id
		end
	end
	for _, m in ipairs(Focus.custom) do
		if (auto or m.class == "manual") and Focus.IsEnabled(m.id) and m.trigger(Focus.signals) then
```

In `SwagBag/Engine/Focus.lua` (edit 5 of 15), find:

```lua
		if not best or CLASS_RANK[byId[id].class] > CLASS_RANK[byId[best].class] then
```

and replace it with:

```lua
		if not best or CLASS_RANK[mode(id).class] > CLASS_RANK[mode(best).class] then
```

In `SwagBag/Engine/Focus.lua` (edit 6 of 15), find:

```lua
	for _, id in ipairs(decidingOf(active)) do
		local m = byId[id]
```

and replace it with:

```lua
	for _, id in ipairs(decidingOf(active)) do
		local m = mode(id)
```

In `SwagBag/Engine/Focus.lua` (edit 7 of 15), find:

```lua
	local set = { new = true }
	for _, id in ipairs(deciding()) do
		local m = byId[id]
		if m.expandAll and m.expandAll(Focus.signals) then
```

and replace it with:

```lua
	local set = { new = true }
	for _, id in ipairs(deciding()) do
		local m = mode(id)
		if m.expandAll and m.expandAll(Focus.signals) then
```

In `SwagBag/Engine/Focus.lua` (edit 8 of 15), find:

```lua
		local m = byId[id]
```

and replace it with:

```lua
		local m = mode(id)
```

In `SwagBag/Engine/Focus.lua` (edit 9 of 15), find:

```lua
	local L, names = SB.L, {}
	for _, id in ipairs(ids) do
		names[#names + 1] = L[byId[id].name]
```

and replace it with:

```lua
	local names = {}
	for _, id in ipairs(ids) do
		names[#names + 1] = Focus.NameOf(id)
```

In `SwagBag/Engine/Focus.lua` (edit 10 of 15), find:

```lua
function Focus.Refresh(reason)
```

and replace it with:

```lua
function Focus.Refresh(reason)
	Focus.LoadCustom()
```

In `SwagBag/Engine/Focus.lua` (edit 11 of 15), find:

```lua
	if not byId[id] then
```

and replace it with:

```lua
	if not mode(id) then
```

In `SwagBag/Engine/Focus.lua` (edit 12 of 15), find:

```lua
end

---------------------------------------------------------------------------
```

and replace it with:

```lua
end

---------------------------------------------------------------------------
-- Week 12 (AC8.7): the user's own modes. Each writer refuses while read-only, writing nothing; a change emits
-- SB_CONFIG_CHANGED("focus.modes"), which the listener below turns into a Refresh (the modes are read again).
---------------------------------------------------------------------------
local function stored()
	local d = SB.Config.db
	if type(d.modes) ~= "table" then
		d.modes = {}
	end
	return d.modes
end

local function modesChanged()
	SB.Emit("SB_CONFIG_CHANGED", "focus.modes")
end

-- A name the user's mode may have: trimmed, 1 to 24 characters, no chat code, not a built-in mode's name or id (any
-- case), not another of the user's modes (exceptId: the mode being renamed).
function Focus.CheckName(name, exceptId)
	local clean, why = cleanName(name)
	if not clean then
		return nil, why
	end
	local low = clean:lower()
	for _, m in ipairs(Focus.MODES) do
		if low == SB.L[m.name]:lower() or low == m.id then
			return nil, "builtin"
		end
	end
	for _, m in ipairs(Focus.custom) do
		if m.id ~= exceptId and low == m.name:lower() then
			return nil, "taken"
		end
	end
	return clean
end

-- m_<the name in lower case, letters and digits>, then _2, _3...: never an id the user's modes have or had.
local function freeId(name, taken)
	local slug = name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""):sub(1, 20)
	if slug == "" then
		slug = "mode"
	end
	local id, n = "m_" .. slug, 1
	while taken[id] ~= nil do
		n = n + 1
		id = "m_" .. slug .. "_" .. n
	end
	return id
end

function Focus.CreateMode(name, trigger)
	trigger = trigger or "manual"
	if SB.Config.readOnly then
		return nil, "readonly"
	elseif not TRIGGER[trigger] then
		return nil, "trigger"
	end
	local clean, why = Focus.CheckName(name)
	if not clean then
		return nil, why
	elseif #Focus.custom >= Focus.MAX_CUSTOM then
		return nil, "full"
	end
	local modes, n = stored(), 0
	for _, def in pairs(modes) do
		if type(def) == "table" and type(def.n) == "number" and def.n > n then
			n = def.n
		end
	end
	local id = freeId(clean, modes)
	modes[id] = { name = clean, trigger = trigger, n = n + 1 }
	-- Its switch and its (empty) sections are explicit values from the start, so "This character only" can copy them.
	local settings = SB.Config.db.settings
	settings.focus = type(settings.focus) == "table" and settings.focus or {}
	for kind, v in pairs({ on = true, sections = "" }) do
		settings.focus[kind] = type(settings.focus[kind]) == "table" and settings.focus[kind] or {}
		settings.focus[kind][id] = v
	end
	modesChanged()
	return id
end

local function ownMode(id)
	if not customById[id] then
		return "unknown"
	elseif SB.Config.readOnly then
		return "readonly"
	end
end

function Focus.RenameMode(id, name)
	local why = ownMode(id)
	if why then
		return false, why
	end
	local clean
	clean, why = Focus.CheckName(name, id)
	if not clean then
		return false, why
	end
	stored()[id].name = clean
	modesChanged()
	return true
end

function Focus.SetTrigger(id, trigger)
	local why = ownMode(id)
	if why then
		return false, why
	elseif not TRIGGER[trigger] then
		return false, "trigger"
	end
	stored()[id].trigger = trigger
	modesChanged()
	return true
end

-- The mode goes, with its on/off and its sections (the account's and this character's own); its id stays taken.
function Focus.DeleteMode(id)
	local why = ownMode(id)
	if why then
		return false, why
	end
	local C = SB.Config
	stored()[id] = false
	local focus = type(C.db.settings.focus) == "table" and C.db.settings.focus or {}
	for _, kind in ipairs({ "on", "sections" }) do
		if type(focus[kind]) == "table" then
			focus[kind][id] = nil
		end
		C.charDB.overrides["focus." .. kind .. "." .. id] = nil
	end
	Focus.manual[id] = nil
	modesChanged()
	return true
end

-- A manual mode on or off (this session). Returns true, changed; or false, why.
function Focus.SetManual(id, on)
	local m = customById[id]
	if not m then
		return false, "unknown"
	elseif m.triggerId ~= "manual" then
		return false, "notmanual"
	end
	if (Focus.manual[id] == true) == (on == true) then
		return true, false
	end
	Focus.manual[id] = on and true or nil
	Focus.Recompute("signal")
	return true, true
end

-- A mode by its name as shown (any case, spaces around ignored), built-in or the user's.
function Focus.FindMode(name)
	local low = type(name) == "string" and name:match("^%s*(.-)%s*$"):lower() or ""
	for _, m in ipairs(Focus.All()) do
		if Focus.NameOf(m.id):lower() == low then
			return m.id
		end
	end
	return nil
end

-- The user's modes' names (for /swagbag mode on and the share-string note).
function Focus.CustomNames(manualOnly)
	local out = {}
	for _, m in ipairs(Focus.custom) do
		if not manualOnly or m.triggerId == "manual" then
			out[#out + 1] = m.name
		end
	end
	return out
end

---------------------------------------------------------------------------
```

In `SwagBag/Engine/Focus.lua` (edit 13 of 15), find:

```lua
	for _, m in ipairs(Focus.MODES) do
		lines[#lines + 1] = L.MODE_LIST_LINE:format(L[m.name], Focus.IsEnabled(m.id) and L.OVERLAY_ON or L.OVERLAY_OFF,
```

and replace it with:

```lua
	for _, m in ipairs(Focus.All()) do
		local name, on = Focus.NameOf(m.id), Focus.IsEnabled(m.id)
		if m.triggerId == "manual" then -- week 12: the user's manual mode says so, and whether it is switched on
			name, on = L.MODE_LIST_MANUAL:format(name), Focus.manual[m.id] == true
		end
		lines[#lines + 1] = L.MODE_LIST_LINE:format(name, on and L.OVERLAY_ON or L.OVERLAY_OFF,
```

In `SwagBag/Engine/Focus.lua` (edit 14 of 15), find:

```lua
end

-- /swagbag mode style [front|collapse]: the style now, or switch it. A wrong word gets the style now
```

and replace it with:

```lua
end

-- /swagbag mode on <name> | off [<name>] (week 12, AC8.7): the user's manual modes. Every form answers (P2).
local function manualList()
	local names = Focus.CustomNames(true)
	return #names > 0 and table.concat(names, ", ") or SB.L.REPORT_NONE
end

local function manualCommand(word, rest)
	local L = SB.L
	if rest == "" and word == "on" then
		return L.MODE_MANUAL_USAGE:format(manualList())
	elseif rest == "" then
		local off = {}
		for _, m in ipairs(Focus.custom) do
			if Focus.manual[m.id] then
				off[#off + 1] = m.name
				Focus.SetManual(m.id, false)
			end
		end
		return #off > 0 and L.MODE_MANUAL_ALL_OFF:format(table.concat(off, ", ")) or L.MODE_MANUAL_NONE_ON
	end
	local id = Focus.FindMode(rest)
	if not id then
		return L.MODE_MANUAL_UNKNOWN:format(rest, manualList())
	end
	local name = Focus.NameOf(id)
	local ok, changed = Focus.SetManual(id, word == "on")
	if not ok then
		return L.MODE_MANUAL_AUTO:format(name)
	elseif word == "off" then
		return changed and L.MODE_MANUAL_OFF:format(name) or L.MODE_MANUAL_ALREADY_OFF:format(name)
	elseif not changed then
		return L.MODE_MANUAL_ALREADY_ON:format(name)
	end
	return Focus.paused and { L.MODE_MANUAL_ON:format(name), L.MODE_MANUAL_PAUSED } or L.MODE_MANUAL_ON:format(name)
end

-- /swagbag mode style [front|collapse]: the style now, or switch it. A wrong word gets the style now
```

In `SwagBag/Engine/Focus.lua` (edit 15 of 15), find:

```lua
		return styleCommand(rest)
```

and replace it with:

```lua
		return styleCommand(rest)
	elseif word == "on" or word == "off" then
		return manualCommand(word, rest)
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.MODE_USAGE = "Usage: /swagbag mode, /swagbag mode pause, /swagbag mode resume, /swagbag mode list or /swagbag mode style"
L.MODE_LIST_LINE = "%s: %s%s - opens %s"
L.MODE_ACTIVE = ", active now"
L.HELP_MODE = "mode [pause|resume|list|style]: pause or resume focus modes for this session, list them, or choose their style"
```

and replace it with:

```lua
L.MODE_USAGE = "Usage: /swagbag mode, /swagbag mode pause, resume, list, style, on <your mode> or off"
L.MODE_LIST_LINE = "%s: %s%s - opens %s"
L.MODE_ACTIVE = ", active now"
-- Week 12 (AC8.7): the user's own focus modes (Engine/Focus.lua).
L.MODE_LIST_MANUAL = "%s (you switch it)"
L.MODE_MANUAL_USAGE = "Type /swagbag mode on and the name of a mode of yours that you switch yourself: %s."
L.MODE_MANUAL_ON = "%s is on until you switch it off (/swagbag mode off), log out or reload."
L.MODE_MANUAL_PAUSED = "Focus modes are paused, so it waits: type /swagbag mode resume."
L.MODE_MANUAL_OFF = "%s is off."
L.MODE_MANUAL_ALREADY_ON = "%s was already on."
L.MODE_MANUAL_ALREADY_OFF = "%s was already off."
L.MODE_MANUAL_ALL_OFF = "Switched off: %s."
L.MODE_MANUAL_NONE_ON = "No mode of yours was switched on."
L.MODE_MANUAL_UNKNOWN = "No mode is called \"%s\". The modes you switch yourself: %s."
L.MODE_MANUAL_AUTO = "%s switches on by itself, so it can't be switched here. Settings > Focus modes can turn it off."
L.TRIGGER_MANUAL = "Only when I switch it on"
L.TRIGGER_MPLUS = "In a Mythic+ key"
L.TRIGGER_DUNGEON = "In a dungeon"
L.TRIGGER_RAID = "In a raid"
L.TRIGGER_DELVE = "In a delve"
L.TRIGGER_PVP = "In a battleground or arena"
L.TRIGGER_FISHING = "While fishing"
L.TRIGGER_GATHERING = "While gathering"
L.TRIGGER_VENDOR = "At a vendor"
L.TRIGGER_AUCTION = "At the auction house"
L.TRIGGER_BANK = "At the bank"
L.HELP_MODE = "mode [pause|resume|list|style|on <name>|off]: pause or resume focus modes, list them, choose their style,"
	.. " or switch a mode of your own on or off"
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1655 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (81 files)`, `1655 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Categories.lua \
	SwagBag/Engine/Focus.lua \
	SwagBag/Locale/enUS.lua \
	spec/focus_custom_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 12 Task 4: focus modes of your own: engine and /swagbag mode on/off

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 5: Settings > Focus modes: New mode, edit, delete; share strings name them; week-11 polish

The user's side of AC8.7, on the existing Focus modes page, with the existing row kinds. After the mode lines, "Your own modes" with **New mode**: a short form (a name box, "It switches on" with the triggers, "Make mode" / "Cancel"); nothing is made before Make mode, and then the page shows the new mode's sections in the existing editor. A manual mode's line in the mode list is "Switched on" / "Off" for this session; a signal mode's line is On / Off like SwagBag's own. Picking a mode of yours in "Edit the sections of" shows its sections (no Reset: there is no default to go back to), its name (a box; a refused name stays in it to be fixed), when it switches on, and **Delete**, which asks once more; any other click on the page forgets the question. "This character only" covers your modes' switches and sections, and a mode made meanwhile. `/swagbag profile export` names your modes as left out (D19). The polish (D20): the import preview's lowered-priority line names a category by the name it comes in under.

**Files:**
- Create: `spec/settings_focus_custom_spec.lua`
- Modify: `SwagBag/UI/SettingsFocus.lua`, `SwagBag/Engine/Profiles.lua` (the export answer; the preview's lowered names), `SwagBag/Locale/enUS.lua` (`SET_CUSTOM_*`, `SET_MANUAL_*`, `PROFILE_EXPORT_MODES`)

**Interfaces:**
- Consumes: Task 4's `SB.Focus` writers and readers, `SB.Config.CharOverrideMany/IsCharOverride`, the settings window's `input`, `choice` and `actions` rows (`selected`), `SB.Profiles` export command and `Preview`'s `placedNames`.
- Produces: `SB.SettingsFocus` `creating` (the form: `{ name, trigger }`), `confirmDelete`, `renameText`; `SF.Paths()` covers every mode in `Focus.All()`; `L.SET_CUSTOM_*`, `L.SET_MANUAL_ON`, `L.SET_MANUAL_TIP`, `L.PROFILE_EXPORT_MODES`.

- [ ] **Step 1: Write the failing tests**

Create `spec/settings_focus_custom_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 12 (spec AC8.7, AC15.1): Settings > Focus modes for modes of the user's own (UI/SettingsFocus.lua): New mode's
-- short form, a manual mode switched from the list, editing one (sections, name, trigger), Delete asking once more,
-- "This character only"; and share strings (Engine/Profiles.lua): the user's modes never travel, and say so.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Settings: focus modes of your own (week 12)", function()
	local SB, SW, F, L, events
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsFocus.lua")
		SW, F, L = SB.SettingsWindow, SB.Focus, SB.L
		SB.Categories.Load()
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason) events[#events + 1] = reason end)
		SW.Show("focus")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- The button with this text in the row with this label (a text box row has one button: Apply).
	local function rowButton(rowLabel, text)
		local index = 0
		for _, row in ipairs(SW.byId[SW.current].rows()) do
			local items = row.choices or row.actions or (row.kind == "input" and { { text = L.SET_APPLY } }) or {}
			for _, item in ipairs(items) do
				index = index + 1
				if row.label == rowLabel and item.text == text then
					return SW.buttons[index]
				end
			end
		end
		error("no button " .. text .. " in row " .. rowLabel)
	end

	local function click(rowLabel, text)
		Fake.Fire(rowButton(rowLabel, text), "OnClick")
	end

	-- The text box of the row with this label: typed as the user does, then Enter.
	local function type(rowLabel, text)
		local index = 0
		for _, row in ipairs(SW.byId[SW.current].rows()) do
			if row.kind == "input" then
				index = index + 1
				if row.label == rowLabel then
					local box = SW.inputs[index]
					box:SetText(text)
					Fake.Fire(box, "OnTextChanged", true)
					Fake.Fire(box, "OnEnterPressed")
					return
				end
			end
		end
		error("no text box " .. rowLabel)
	end

	local function labels()
		local out = {}
		for _, row in ipairs(SW.byId.focus.rows()) do
			out[row.label] = true
		end
		return out
	end

	-- AC8.7. Mutation: in the Make mode run, `SF.creating, SF.editing, SF.renameText = nil, id, nil` ->
	-- `SF.creating, SF.renameText = nil, nil`.
	it("AC8.7: New mode is a short form: a name, when it switches on, Make mode; then its sections are shown", function()
		assert.falsy(labels()[L.SET_CUSTOM_NAME], "no form until New mode")
		click(L.SET_CUSTOM_LABEL, L.SET_CUSTOM_NEW)
		assert.equal(L.SET_CUSTOM_NEW_HINT, SW.lastStatus)
		type(L.SET_CUSTOM_NAME, "Vendor dump")
		assert.equal("Name: Vendor dump (click Make mode to keep it).", SW.lastStatus)
		assert.truthy(SW.selected[rowButton(L.SET_CUSTOM_TRIGGER, L.TRIGGER_MANUAL)], "manual by default")
		click(L.SET_CUSTOM_TRIGGER, L.TRIGGER_VENDOR)
		assert.equal("It switches on: At a vendor (click Make mode to keep it).", SW.lastStatus)
		assert.is_nil(SB.Config.db.modes, "nothing is made before Make mode")
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_MAKE)
		assert.equal("Made the Vendor dump mode. Pick the sections it brings up below.", SW.lastStatus)
		assert.equal("vendor", F.Mode("m_vendor_dump").triggerId)
		assert.equal("m_vendor_dump", SB.SettingsFocus.editing)
		assert.truthy(labels()[L.SET_SECTIONS_OF:format("Vendor dump")])
		assert.falsy(labels()[L.SET_CUSTOM_NAME], "the form is gone")
		click("Junk", L.SET_SECTION_OPEN)
		assert.same({ "c_junk" }, F.Sections("m_vendor_dump"))
		click(L.SET_CUSTOM_LABEL, L.SET_CUSTOM_NEW)
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_CANCEL)
		assert.equal(L.SET_CUSTOM_CANCELLED, SW.lastStatus)
		assert.equal(1, #F.custom)
	end)

	-- Mutation: in refusal(), drop the `elseif why and rawget(L, "SET_CUSTOM_WHY_" .. why:upper()) then` branch.
	it("a name that can't be used says why, at Enter and at Make mode; nothing is made", function()
		click(L.SET_CUSTOM_LABEL, L.SET_CUSTOM_NEW)
		type(L.SET_CUSTOM_NAME, "raid")
		assert.equal(L.SET_CUSTOM_WHY_BUILTIN, SW.lastStatus)
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_MAKE)
		assert.equal(L.SET_CUSTOM_WHY_BUILTIN, SW.lastStatus)
		type(L.SET_CUSTOM_NAME, "")
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_MAKE)
		assert.equal(L.SET_CUSTOM_WHY_EMPTY, SW.lastStatus)
		assert.same({}, F.custom)
		for _, why in ipairs({ "EMPTY", "LONG", "CODE", "BUILTIN", "TAKEN", "FULL", "TRIGGER", "NOTMANUAL" }) do
			assert.truthy(rawget(L, "SET_CUSTOM_WHY_" .. why), why)
		end
	end)

	-- Mutation: in the manual row's apply, `F.SetManual(m.id, v)` -> `F.SetManual(m.id, true)`.
	it("a manual mode's line in the list switches it on and off for this session, like /swagbag mode on", function()
		local id = F.CreateMode("Farming")
		F.SetSections(id, { "c_herbs" })
		SW.Render()
		local row = L.SET_MODE_LABEL:format("Farming (you switch it)")
		assert.truthy(SW.selected[rowButton(row, L.SET_OFF)])
		events = {}
		click(row, L.SET_MANUAL_ON)
		assert.equal(L.MODE_MANUAL_ON:format("Farming"), SW.lastStatus)
		assert.truthy(F.ManualOn(id))
		assert.truthy(SW.selected[rowButton(row, L.SET_MANUAL_ON)])
		assert.same({ "signal" }, events, "the open bags follow")
		click(row, L.SET_OFF)
		assert.equal(L.MODE_MANUAL_OFF:format("Farming"), SW.lastStatus)
		assert.falsy(F.ManualOn(id))
	end)

	-- Mutation: in sectionRows, drop `if F.IsCustom(id) then return end` (a Reset with no default to go back to).
	it("editing a mode of yours: its sections with no Reset, its name, when it switches on", function()
		local id = F.CreateMode("Farming")
		SW.Render()
		click(L.SET_EDIT_MODE, "Farming")
		assert.truthy(labels()[L.SET_SECTIONS_OF:format("Farming")])
		assert.falsy(labels()[L.SET_SECTIONS_DEFAULT_LABEL])
		click("Herbs", L.SET_SECTION_OPEN)
		assert.same({ "c_herbs" }, F.Sections(id))
		type(L.SET_CUSTOM_RENAME, "Herb run")
		assert.equal("Farming is now called Herb run.", SW.lastStatus)
		assert.equal("Herb run", F.NameOf(id))
		type(L.SET_CUSTOM_RENAME, "Fishing")
		assert.equal(L.SET_CUSTOM_WHY_BUILTIN, SW.lastStatus)
		assert.equal("Fishing", SW.inputs[1]:GetText(), "a refused name stays in the box to be fixed")
		assert.equal("Herb run", F.NameOf(id))
		click(L.SET_CUSTOM_TRIGGER, L.TRIGGER_BANK)
		assert.equal("Herb run now switches on: At the bank.", SW.lastStatus)
		assert.truthy(labels()[L.SET_MODE_LABEL:format("Herb run")], "now an On / Off line like SwagBag's own")
		F.SetSignal("bankOpen", true)
		assert.same({ "market", id }, F.Active())
	end)

	-- Mutation: in forgetting(), drop `row.apply = wrap(row.apply)` (a choice would keep Delete's question).
	it("Delete asks once more; any other click forgets the question; deleted, the page shows M+ again", function()
		local id = F.CreateMode("Farming")
		SW.Render()
		click(L.SET_EDIT_MODE, "Farming")
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE)
		assert.equal("Click \"Delete: sure?\" to delete the Farming mode. Any other click keeps it.", SW.lastStatus)
		click("Herbs", L.SET_SECTION_OPEN)
		assert.truthy(rowButton(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE), "the question is forgotten")
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE)
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE_SURE)
		assert.equal("Deleted the Farming mode.", SW.lastStatus)
		assert.is_nil(F.Mode(id))
		assert.equal("mplus", SB.SettingsFocus.editing)
		assert.truthy(SW.selected[rowButton(L.SET_EDIT_MODE, "M+")])
	end)

	-- AC15.1. Mutation: in SF.Paths, iterate `SB.Focus.MODES` instead of `SB.Focus.All()`.
	it("This character only makes your own modes' switches and sections this character's too", function()
		local id = F.CreateMode("Dump", "vendor")
		F.SetSections(id, { "c_junk" })
		SW.Render()
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		assert.truthy(SB.Config.IsCharOverride("focus.sections." .. id))
		assert.truthy(SB.Config.IsCharOverride("focus.on." .. id))
		click(L.SET_THIS_CHARACTER:format(L.SET_MODE_LABEL:format("Dump")), L.SET_OFF)
		assert.equal(true, SB.Config.db.settings.focus.on[id], "the account's switch is untouched")
		assert.falsy(F.IsEnabled(id))
		click(L.SET_CUSTOM_LABEL, L.SET_CUSTOM_NEW)
		type(L.SET_CUSTOM_NAME, "Later")
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_MAKE)
		assert.truthy(SB.Config.IsCharOverride("focus.sections.m_later"), "a mode made meanwhile is this character's too")
	end)
end)

describe("Share strings and modes of your own (week 12)", function()
	local SB, Pr, F
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Profiles.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		SB.Categories.Load()
		Pr, F = SB.Profiles, SB.Focus
	end)

	-- Mutation: in the profile command, drop the `if #modes > 0 then` block (the answer would not name them).
	it("an export leaves your own modes out and names them; an import never makes one (hostile entries skipped)", function()
		local id = F.CreateMode("Farming")
		F.SetSections(id, { "c_herbs" })
		F.SetEnabled(id, false)
		local ok, said = SB.Slash.Run("profile export")
		assert.truthy(ok)
		assert.same({ SB.L.PROFILE_EXPORTED, SB.L.PROFILE_EXPORT_MODES:format("Farming") }, said)
		local text = Pr.Export(false)
		assert.falsy(text:find("m_farming", 1, true))
		local data = assert(Pr.Parse("SWAGBAG:1:s.focus.on.m_evil=b1;s.focus.sections.m_evil=sc_junk;m.m_evil.name=sEvil;"
			.. "s.bags.columns=n14"))
		assert.same({ "focus.on.m_evil", "focus.sections.m_evil", "m.m_evil.name" }, data.skipped)
		assert.truthy(Pr.Import(data))
		assert.is_nil(F.Mode("m_evil"))
		assert.same({ id }, { F.custom[1].id })
		assert.equal(14, SB.Config.Get("bags.columns"))
		assert.equal("c_herbs", SB.Config.Get("focus.sections." .. id), "an import keeps your modes' sections")
	end)

	-- Week-11 deferred (Profiles preview). Mutation: in Pr.Preview's lowered names, drop `placedNames[id] or`.
	it("the preview's ranked-lower line names a category by the name it comes in under", function()
		SB.Config.db.categories = { u_mine = { name = "Mine", query = "herb", priority = 50 } }
		SB.Categories.Load()
		local data = assert(Pr.Parse("SWAGBAG:1:cu.u_mine.name=sMine;cu.u_mine.query=sore;cu.u_mine.priority=n95"))
		local lines = Pr.Preview(data)
		local found
		for _, line in ipairs(lines) do
			if line == SB.L.PROFILE_PREVIEW_LOWERED:format("Mine (2)") then
				found = true
			end
		end
		assert.truthy(found, table.concat(lines, " / "))
	end)
end)
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1655 passed, 8 failed`. The failures, exactly:

- `spec/settings_focus_custom_spec.lua :: Settings: focus modes of your own (week 12) > AC8.7: New mode is a short form: a name, when it switches on, Make mode; then its sections are shown`
- `spec/settings_focus_custom_spec.lua :: Settings: focus modes of your own (week 12) > a name that can't be used says why, at Enter and at Make mode; nothing is made`
- `spec/settings_focus_custom_spec.lua :: Settings: focus modes of your own (week 12) > a manual mode's line in the list switches it on and off for this session, like /swagbag mode on`
- `spec/settings_focus_custom_spec.lua :: Settings: focus modes of your own (week 12) > editing a mode of yours: its sections with no Reset, its name, when it switches on`
- `spec/settings_focus_custom_spec.lua :: Settings: focus modes of your own (week 12) > Delete asks once more; any other click forgets the question; deleted, the page shows M+ again`
- `spec/settings_focus_custom_spec.lua :: Settings: focus modes of your own (week 12) > This character only makes your own modes' switches and sections this character's too`
- `spec/settings_focus_custom_spec.lua :: Share strings and modes of your own (week 12) > an export leaves your own modes out and names them; an import never makes one (hostile entries skipped)`
- `spec/settings_focus_custom_spec.lua :: Share strings and modes of your own (week 12) > the preview's ranked-lower line names a category by the name it comes in under`

The page has no "Your own modes" row, form, manual line, rename box, trigger row or Delete (the tests' `rowButton` finds no such button and errors); "This character only" leaves your modes' paths out; the export answers one line; the preview's lowered line says "Mine".

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "AC8.7: New mode is a short form: a name, when it switches on, Make mode; then its sections are shown": in `SwagBag/UI/SettingsFocus.lua`, `SF.creating, SF.editing, SF.renameText = nil, id, nil` → `SF.creating, SF.renameText = nil, nil`.
- "a name that can't be used says why, at Enter and at Make mode; nothing is made": in `SwagBag/UI/SettingsFocus.lua`, `elseif why and rawget(L, "SET_CUSTOM_WHY_" .. why:upper()) then` → `elseif false then`.
- "a manual mode's line in the list switches it on and off for this session, like /swagbag mode on": in `SwagBag/UI/SettingsFocus.lua`, `local ok, why = F.SetManual(m.id, v)` → `local ok, why = F.SetManual(m.id, true)`.
- "editing a mode of yours: its sections with no Reset, its name, when it switches on": in `SwagBag/UI/SettingsFocus.lua`, `if F.IsCustom(id) then` → `if false then`.
- "Delete asks once more; any other click forgets the question; deleted, the page shows M+ again": in `SwagBag/UI/SettingsFocus.lua`, `row.apply = wrap(row.apply)` → ∅.
- "This character only makes your own modes' switches and sections this character's too": in `SwagBag/UI/SettingsFocus.lua`, `for _, m in ipairs(SB.Focus.All()) do -- week 12: the user's own modes too` → `for _, m in ipairs(SB.Focus.MODES) do`.
- "This character only makes your own modes' switches and sections this character's too": in `SwagBag/UI/SettingsFocus.lua`, `if anyOverride() then -- "This character only" is on: the new mode's settings are this character's too` → `if false then`.
- "an export leaves your own modes out and names them; an import never makes one (hostile entries skipped)": in `SwagBag/Engine/Profiles.lua`, `if #modes > 0 then` → `if false then`.
- "the preview's ranked-lower line names a category by the name it comes in under": in `SwagBag/Engine/Profiles.lua`, `names[i] = placedNames[id] or (def and def.name) or` → `names[i] = (def and def.name) or`.

- [ ] **Step 3: Write the code**

In `SwagBag/Engine/Profiles.lua` (edit 1 of 3), find:

```lua
--                                            follow it), one whose name is taken as "Name (2)"; the preview names them
```

and replace it with:

```lua
--                                            follow it), one whose name is taken as "Name (2)"; the preview names them
-- The user's own focus modes (week 12, AC8.7) are not in share strings: their settings are no known path, so an
-- export leaves them out (its answer names the modes) and an import skips them, as any unknown entry.
```

In `SwagBag/Engine/Profiles.lua` (edit 2 of 3), find:

```lua
			names[i] = (def and def.name) or (SB.Categories and SB.Categories.Name(id)) or id
```

and replace it with:

```lua
			-- week 12 (week-11 deferred): the name it comes in under ("Mine (2)"), as the Added line says
			names[i] = placedNames[id] or (def and def.name) or (SB.Categories and SB.Categories.Name(id)) or id
```

In `SwagBag/Engine/Profiles.lua` (edit 3 of 3), find:

```lua
		local said = rest ~= "" and L.PROFILE_EXPORTED_CATEGORIES or L.PROFILE_EXPORTED
		if #left > 0 then
			return { said, L.PROFILE_EXPORT_LEFT_OUT:format(table.concat(left, ", ")) } -- one answer, two lines
		end
		return said
```

and replace it with:

```lua
		local said = { rest ~= "" and L.PROFILE_EXPORTED_CATEGORIES or L.PROFILE_EXPORTED }
		if #left > 0 then
			said[#said + 1] = L.PROFILE_EXPORT_LEFT_OUT:format(table.concat(left, ", ")) -- one answer, two lines
		end
		-- Week 12 (AC8.7): the user's own focus modes never travel; the answer says so, naming them.
		local modes = SB.Focus and SB.Focus.CustomNames and SB.Focus.CustomNames() or {}
		if #modes > 0 then
			said[#said + 1] = L.PROFILE_EXPORT_MODES:format(table.concat(modes, ", "))
		end
		return #said == 1 and said[1] or said
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 2), find:

```lua
L.TRIGGER_BANK = "At the bank"
```

and replace it with:

```lua
L.TRIGGER_BANK = "At the bank"
-- Week 12: Settings > Focus modes, modes of your own (UI/SettingsFocus.lua).
L.SET_CUSTOM_LABEL = "Your own modes"
L.SET_CUSTOM_TIP = "Make a focus mode of your own: a name, when it switches on (by itself with one of SwagBag's signals,"
	.. " or only when you switch it), and the sections it brings up. Up to 10."
L.SET_CUSTOM_NEW = "New mode"
L.SET_CUSTOM_NEW_HINT = "A new mode: type its name, pick when it switches on, then click Make mode."
L.SET_CUSTOM_NAME = "Its name (press Enter or Apply)"
L.SET_CUSTOM_NAME_OK = "Name: %s (click Make mode to keep it)."
L.SET_CUSTOM_TRIGGER = "It switches on"
L.SET_CUSTOM_TRIGGER_TIP = "Only when I switch it on: you switch it with /swagbag mode on <name> or in the list above."
	.. " Any other choice: it switches on by itself, like SwagBag's own modes."
L.SET_CUSTOM_TRIGGER_PICKED = "It switches on: %s (click Make mode to keep it)."
L.SET_CUSTOM_MAKE_LABEL = "Done?"
L.SET_CUSTOM_MAKE_TIP = "Make mode makes it; you pick its sections next. Cancel forgets this form."
L.SET_CUSTOM_MAKE = "Make mode"
L.SET_CUSTOM_CANCEL = "Cancel"
L.SET_CUSTOM_CANCELLED = "No mode was made."
L.SET_CUSTOM_MADE = "Made the %s mode. Pick the sections it brings up below."
L.SET_CUSTOM_MADE_MANUAL = "Made the %s mode. Pick the sections it brings up below; switch it on with /swagbag mode on %s"
	.. " or in the list above."
L.SET_CUSTOM_RENAME = "This mode's name (press Enter or Apply)"
L.SET_CUSTOM_RENAMED = "%s is now called %s."
L.SET_CUSTOM_TRIGGER_SET = "%s now switches on: %s."
L.SET_CUSTOM_DELETE_LABEL = "Remove this mode"
L.SET_CUSTOM_DELETE_TIP = "Deletes this mode of yours and its sections. Your categories and items stay as they are."
L.SET_CUSTOM_DELETE = "Delete"
L.SET_CUSTOM_DELETE_SURE = "Delete: sure?"
L.SET_CUSTOM_DELETE_ASK = "Click \"%s\" to delete the %s mode. Any other click keeps it."
L.SET_CUSTOM_DELETED = "Deleted the %s mode."
L.SET_CUSTOM_MODE_TIP = "Your own mode. On: it switches on by itself (%s), as long as Switch by themselves is on. Off: it"
	.. " never does."
L.SET_MANUAL_TIP = "Your own mode: Switched on brings its sections up until you switch it off, log out or reload (the"
	.. " same as /swagbag mode on %s)."
L.SET_MANUAL_ON = "Switched on"
L.SET_CUSTOM_WHY_EMPTY = "Type a name first."
L.SET_CUSTOM_WHY_LONG = "That name is too long: 24 letters at most."
L.SET_CUSTOM_WHY_CODE = "A name can't have | or other special characters."
L.SET_CUSTOM_WHY_BUILTIN = "That is the name of one of SwagBag's own modes: pick another."
L.SET_CUSTOM_WHY_TAKEN = "You have a mode with that name already: pick another."
L.SET_CUSTOM_WHY_FULL = "You have 10 modes of your own, the most there can be: delete one first."
L.SET_CUSTOM_WHY_TRIGGER = "Pick when it switches on first."
L.SET_CUSTOM_WHY_NOTMANUAL = "That mode switches on by itself."
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 2), find:

```lua
L.PROFILE_EXPORTED_CATEGORIES = "Your settings' and categories' share string is in the box: press Ctrl+C to copy it."
```

and replace it with:

```lua
L.PROFILE_EXPORTED_CATEGORIES = "Your settings' and categories' share string is in the box: press Ctrl+C to copy it."
L.PROFILE_EXPORT_MODES = "Your own focus modes stay on this account: share strings don't carry them (%s)."
```

In `SwagBag/UI/SettingsFocus.lua` (edit 1 of 9), find:

```lua
--   SettingsFocus.Edit(modeId)   open the page with that mode's sections shown
```

and replace it with:

```lua
--   SettingsFocus.Edit(modeId)   open the page with that mode's sections shown
-- Week 12 (AC8.7): modes of the user's own. "New mode" opens a short form (a name, when it switches on, Make mode);
-- a mode of the user's is edited like a built-in (its sections, with no default to go back to) and also has its name,
-- its trigger and Delete (asks once more; any other click on the page forgets the question). A manual mode's row in
-- the mode list switches it on or off for this session (as /swagbag mode on / off).
```

In `SwagBag/UI/SettingsFocus.lua` (edit 2 of 9), find:

```lua
local SF = { editing = "mplus" }
```

and replace it with:

```lua
local SF = { editing = "mplus", creating = nil, confirmDelete = nil, renameText = nil }
```

In `SwagBag/UI/SettingsFocus.lua` (edit 3 of 9), find:

```lua
	for _, m in ipairs(SB.Focus.MODES) do
```

and replace it with:

```lua
	for _, m in ipairs(SB.Focus.All()) do -- week 12: the user's own modes too
```

In `SwagBag/UI/SettingsFocus.lua` (edit 4 of 9), find:

```lua
	return L[SB.Focus.byId[id].name]
end

-- The Focus writers return false, "readonly" | "unknown".
local function refusal(why)
	return why == "unknown" and L.SET_FOCUS_UNKNOWN or L.SETTINGS_READONLY
```

and replace it with:

```lua
	return SB.Focus.NameOf(id)
end

-- The Focus writers return false, "readonly" | "unknown"; the user's modes' writers also a name or trigger reason.
local function refusal(why)
	if why == "readonly" then
		return L.SETTINGS_READONLY
	elseif why and rawget(L, "SET_CUSTOM_WHY_" .. why:upper()) then
		return L["SET_CUSTOM_WHY_" .. why:upper()]
	end
	return L.SET_FOCUS_UNKNOWN
```

In `SwagBag/UI/SettingsFocus.lua` (edit 5 of 9), find:

```lua
	end
	rows[#rows + 1] = { kind = "actions", label = L.SET_SECTIONS_DEFAULT_LABEL, tip = L.SET_SECTIONS_DEFAULT_TIP,
```

and replace it with:

```lua
	end
	if F.IsCustom(id) then
		return -- a mode of the user's has no default set; its own rows follow (customRows)
	end
	rows[#rows + 1] = { kind = "actions", label = L.SET_SECTIONS_DEFAULT_LABEL, tip = L.SET_SECTIONS_DEFAULT_TIP,
```

In `SwagBag/UI/SettingsFocus.lua` (edit 6 of 9), find:

```lua
end

local function rows()
```

and replace it with:

```lua
end

-- A trigger's words ("At a vendor").
local function triggerName(id)
	for _, t in ipairs(SB.Focus.TRIGGERS) do
		if t.id == id then
			return L[t.name]
		end
	end
	return tostring(id)
end

-- The triggers as choices (manual first), for the new-mode form and a mode of the user's.
local function triggerChoices()
	local out = {}
	for _, t in ipairs(SB.Focus.TRIGGERS) do
		out[#out + 1] = { value = t.id, text = L[t.name] }
	end
	return out
end

-- Week 12: "New mode" and its short form. Nothing is made before Make mode; Cancel forgets it.
local function newModeRows(out)
	local F = SB.Focus
	out[#out + 1] = { kind = "actions", label = L.SET_CUSTOM_LABEL, tip = L.SET_CUSTOM_TIP, actions = {
		{ text = L.SET_CUSTOM_NEW, selected = SF.creating ~= nil, run = function()
			SF.creating = { name = "", trigger = "manual" }
			return L.SET_CUSTOM_NEW_HINT
		end } } }
	local d = SF.creating
	if not d then
		return
	end
	out[#out + 1] = { kind = "input", label = L.SET_CUSTOM_NAME, maxLetters = 2 * F.MAX_NAME,
		get = function()
			return d.name
		end,
		set = function(text)
			d.name = text
		end,
		commit = function(text)
			d.name = text
			local clean, why = F.CheckName(text)
			return clean and L.SET_CUSTOM_NAME_OK:format(clean) or refusal(why)
		end }
	out[#out + 1] = { kind = "choice", label = L.SET_CUSTOM_TRIGGER, tip = L.SET_CUSTOM_TRIGGER_TIP, width = 90,
		choices = triggerChoices(),
		get = function()
			return d.trigger
		end,
		apply = function(v)
			d.trigger = v
			return L.SET_CUSTOM_TRIGGER_PICKED:format(triggerName(v))
		end }
	out[#out + 1] = { kind = "actions", label = L.SET_CUSTOM_MAKE_LABEL, tip = L.SET_CUSTOM_MAKE_TIP, actions = {
		{ text = L.SET_CUSTOM_MAKE, run = function()
			local id, why = F.CreateMode(d.name, d.trigger)
			if not id then
				return refusal(why)
			end
			if anyOverride() then -- "This character only" is on: the new mode's settings are this character's too
				SB.Config.CharOverrideMany({ "focus.on." .. id, "focus.sections." .. id }, true)
			end
			SF.creating, SF.editing, SF.renameText = nil, id, nil
			local name = modeName(id)
			if d.trigger == "manual" then
				return L.SET_CUSTOM_MADE_MANUAL:format(name, name)
			end
			return L.SET_CUSTOM_MADE:format(name)
		end },
		{ text = L.SET_CUSTOM_CANCEL, run = function()
			SF.creating = nil
			return L.SET_CUSTOM_CANCELLED
		end } } }
end

-- Week 12: the rows of the user's mode being edited, after its sections: its name, when it switches on, Delete.
local function customRows(out)
	local F, id = SB.Focus, SF.editing
	if not F.IsCustom(id) then
		return
	end
	out[#out + 1] = { kind = "input", label = L.SET_CUSTOM_RENAME, maxLetters = 2 * F.MAX_NAME,
		get = function()
			return SF.renameText or modeName(id)
		end,
		set = function(text)
			SF.renameText = text
		end,
		commit = function(text)
			local old = modeName(id)
			local ok, why = F.RenameMode(id, text)
			if not ok then
				SF.renameText = text -- what was typed stays in the box, to be fixed
				return refusal(why)
			end
			SF.renameText = nil
			return L.SET_CUSTOM_RENAMED:format(old, modeName(id))
		end }
	out[#out + 1] = { kind = "choice", label = L.SET_CUSTOM_TRIGGER, tip = L.SET_CUSTOM_TRIGGER_TIP, width = 90,
		choices = triggerChoices(),
		get = function()
			return F.Mode(id).triggerId
		end,
		apply = function(v)
			local ok, why = F.SetTrigger(id, v)
			if not ok then
				return refusal(why)
			end
			return L.SET_CUSTOM_TRIGGER_SET:format(modeName(id), triggerName(v))
		end }
	local sure = SF.confirmDelete == id
	out[#out + 1] = { kind = "actions", label = L.SET_CUSTOM_DELETE_LABEL, tip = L.SET_CUSTOM_DELETE_TIP, actions = {
		{ text = sure and L.SET_CUSTOM_DELETE_SURE or L.SET_CUSTOM_DELETE, selected = sure, keepsQuestion = true,
		run = function()
			local name = modeName(id)
			if SF.confirmDelete ~= id then
				SF.confirmDelete = id
				return L.SET_CUSTOM_DELETE_ASK:format(L.SET_CUSTOM_DELETE_SURE, name)
			end
			SF.confirmDelete = nil
			local ok, why = F.DeleteMode(id)
			if not ok then
				return refusal(why)
			end
			SF.editing = "mplus"
			return L.SET_CUSTOM_DELETED:format(name)
		end } } }
end

-- Every click on the page but Delete's own forgets Delete's question (week 7's Unlock-all pattern).
local function forgetting(list)
	local function wrap(f)
		return function(...)
			SF.confirmDelete = nil
			return f(...)
		end
	end
	for _, row in ipairs(list) do
		if row.apply then
			row.apply = wrap(row.apply)
		end
		if row.commit then
			row.commit = wrap(row.commit)
		end
		for _, a in ipairs(row.actions or {}) do
			if not a.keepsQuestion then
				a.run = wrap(a.run)
			end
		end
	end
	return list
end

local function rows()
```

In `SwagBag/UI/SettingsFocus.lua` (edit 7 of 9), find:

```lua
	for _, m in ipairs(F.MODES) do
		out[#out + 1] = { kind = "choice", label = layered(L.SET_MODE_LABEL:format(L[m.name])),
			tip = L.SET_MODE_TIP:format(whenText(m.id)),
			choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
			get = function()
				return F.IsEnabled(m.id)
			end,
			apply = function(v)
				local ok, why = F.SetEnabled(m.id, v)
				if not ok then
					return refusal(why)
				end
				return (v and L.SET_MODE_ON or L.SET_MODE_OFF):format(L[m.name])
			end }
```

and replace it with:

```lua
	for _, m in ipairs(F.All()) do
		local name = modeName(m.id)
		if m.triggerId == "manual" then
			-- Week 12: a manual mode of the user's is switched on and off here, for this session.
			out[#out + 1] = { kind = "choice", label = layered(L.SET_MODE_LABEL:format(L.MODE_LIST_MANUAL:format(name))),
				tip = L.SET_MANUAL_TIP:format(name),
				choices = { { value = true, text = L.SET_MANUAL_ON }, { value = false, text = L.SET_OFF } },
				get = function()
					return F.ManualOn(m.id)
				end,
				apply = function(v)
					local ok, why = F.SetManual(m.id, v)
					if not ok then
						return refusal(why)
					end
					return v and L.MODE_MANUAL_ON:format(name) or L.MODE_MANUAL_OFF:format(name)
				end }
		else
			out[#out + 1] = { kind = "choice", label = layered(L.SET_MODE_LABEL:format(name)),
				tip = m.custom and L.SET_CUSTOM_MODE_TIP:format(triggerName(m.triggerId))
					or L.SET_MODE_TIP:format(whenText(m.id)),
				choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
				get = function()
					return F.IsEnabled(m.id)
				end,
				apply = function(v)
					local ok, why = F.SetEnabled(m.id, v)
					if not ok then
						return refusal(why)
					end
					return (v and L.SET_MODE_ON or L.SET_MODE_OFF):format(name)
				end }
		end
	end
	newModeRows(out)
	if not F.Mode(SF.editing) then
		SF.editing = "mplus" -- the mode being edited was deleted (here, or by a profile or a reset)
```

In `SwagBag/UI/SettingsFocus.lua` (edit 8 of 9), find:

```lua
		return L.SET_EDITING:format(modeName(v))
	end }
	for _, m in ipairs(F.MODES) do
		pick.choices[#pick.choices + 1] = { value = m.id, text = L[m.name] }
	end
	out[#out + 1] = pick
	sectionRows(out)
	return out
```

and replace it with:

```lua
		SF.renameText = nil
		return L.SET_EDITING:format(modeName(v))
	end }
	for _, m in ipairs(F.All()) do
		pick.choices[#pick.choices + 1] = { value = m.id, text = modeName(m.id) }
	end
	out[#out + 1] = pick
	sectionRows(out)
	customRows(out)
	return forgetting(out)
```

In `SwagBag/UI/SettingsFocus.lua` (edit 9 of 9), find:

```lua
	if modeId and SB.Focus.byId[modeId] then
		SF.editing = modeId
```

and replace it with:

```lua
	if modeId and SB.Focus.Mode(modeId) then
		SF.editing, SF.renameText = modeId, nil
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1663 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (81 files)`, `1663 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Profiles.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/SettingsFocus.lua \
	spec/settings_focus_custom_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 12 Task 5: Settings > Focus modes: modes of your own; share strings name them; preview polish

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

## In-game sessions

One session, WZ1, on the **final merged build** (every task done, reviewed and fixed), as week 6's ruling P1 set. Then the week-12 exit check. It never blocks the build: findings come back as fixes.

Before the session:
- Claude installs the build first. The game currently runs an older copy, and the login line must say `v0.12.0`.
- If anything shows a red Lua error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After the session, reply "WZ1 done" and the numbers of any steps that didn't match.

Chat lines start with `SwagBag: `. The settings window answers in its **status line** (the small text at its bottom), not in chat. Names and numbers like `N` are examples: yours will differ.

### Session WZ1: the setup wizard, the tour, and a mode of your own (checks Tasks 1 to 5 and the final fixes; about 40 minutes)

You need: a training dummy close by (every capital city has some) for steps 20 and 22; a vendor for step 35. Your settings are changed by this session (14 slots per row, a few marks made explicit); step 39 tells you how to put back what you want.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in and wait about ten seconds. Expected: chat shows `SwagBag: v0.12.0 loaded. Type /swagbag help for commands.`, and **no setup window opens** (you set SwagBag up before; it never asks again by itself).
3. Press **B** to open your bags. Expected: your bags look as they did last week: no new button, nothing new.
4. Type `/swagbag setup`. Expected: chat `SwagBag: Setup opened.`; a window `Welcome to SwagBag` with `Step 1 of 4: What do you play?`, the text `What do you play? Pick any. You can change everything later: type /swagbag.`, five buttons `M+`, `Raid`, `Gold-making`, `Casual`, `Collector` (none highlighted: this version remembers your picks from now on), and at the bottom `Skip (use defaults)` on the left and `Next` on the right; no `Back`.
5. Click `M+`, then `Gold-making`. Expected: both turn green.
6. Click `Next`. Expected: `Step 2 of 4: What that turns on`, the text `This is what your picks turn on. Click a line to switch it. Everything is in /swagbag later.`, and fourteen buttons in two columns: `M+ mode: On`, `Raid mode: On`, `Delves mode: On`, `Gathering mode: On`, `Fishing mode: On`, `AH/Vendor/Bank mode: On` (a mode you switched off in Settings says `Off`, except M+, which your pick switches on), `Low-consumables warning: On`, `Keystone level and dungeon: On`, `Upgrade track on gear: On`, `Upgrade arrow on gear: On`, `Item level on gear: On`, `Gold totals on section headers: On`, `Junk coin on gray items: On`, `Trade Goods and BoE gear near the top: On`. Say if any text is cut off or buttons overlap (W1).
7. Click `Fishing mode: On`. Expected: it now reads `Fishing mode: Off`; nothing else changes.
8. Click `Back`. Expected: `Step 1 of 4: What do you play?` with `M+` and `Gold-making` still green. Click `Next`. Expected: step 2 again, with `Fishing mode: Off`.
9. Click `Next`. Expected: `Step 3 of 4: How your bags look`, with `Slots per row` (`10` `12` `14` `16`, yours highlighted), `Bag window size` (`80%` `90%` `100%` `110%` `125%`), and `The look of SwagBag's windows` (`Blizzard`, `Modern flat`, and `Matches ElvUI` only if ElvUI is on; yours highlighted).
10. Click `14`. Expected: `14` is highlighted.
11. Click `Next`. Expected: `Step 4 of 4: Gold`, a line that names your price addon, `SwagBag found Auctionator: your items' prices come from it.` (or `TSM (DBMarket)` in place of Auctionator; without either: `No auction price addon found, so prices are what a vendor pays. Install Auctionator or TSM and SwagBag uses it by itself.`) (W3); then `Gold glow at the bank on items worth` with `Off` `50g` `100g` `500g` `1000g` (yours highlighted, `100g` if you never changed it), and `Sell gray junk by itself at every vendor` with `On` and `Off`. The button `Next` is now `Finish`.
12. Click `Finish`. Expected: chat `SwagBag: Set up for M+, Gold-making. Change anything later: type /swagbag.`; the window closes, and a small window says `All set. Want a short tour of your bags? It takes a minute, and you can stop it any time.` with `Show me around` and `No thanks`.
13. Look at your open bags. Expected: 14 slots per row; `Trade Goods` and `BoE gear` sections right under `Keystone & Crests` (W2).
14. Click `Show me around`. Expected: chat `SwagBag: Tour started: the notes next to your bags show you around. Esc or End tour stops it.`; a note `1 of 7` next to your first section header saying `Each section is a category. Its header says what is in it, how many, and what it is worth.`, and a thin gold frame around that header (W4).
15. Click `Next` five times, reading each note. Expected, in order: `2 of 7` (`Click a header to close or open its section...`) and `3 of 7` (`Focus modes bring the sections you need to the top by themselves...`) at the same header; `4 of 7` (`Type here to search...`) at the search box; `5 of 7` (`The title names the focus mode that is on...`) at the `Pause` button; `6 of 7` (`Sort tidies your bags...`) at the `Sort` button. Say if a note is off screen or hard to read (W4).
16. Click `Next`. Expected: `7 of 7` beside your bags: `If your bags ever act up, type /swagbag safe on: Blizzard's bags come back at once. /swagbag safe off brings SwagBag back, and /swagbag report shows what went wrong.`; the button reads `Done`. Click `Back`. Expected: `6 of 7` again.
17. Click `Next`, then `Done`. Expected: chat `SwagBag: That's the tour. Type /swagbag tour to see it again, or /swagbag for every setting.`; the note is gone, your bags are still open, and nothing in them moved.
18. Type `/swagbag tour`, then press **B** to close your bags. Expected: chat `SwagBag: Tour started: ...`, then once `SwagBag: Tour ended because your bags closed. Type /swagbag tour to see it again.`; no note left on screen.
19. Type `/swagbag tour`, then press **Esc** once. Expected: the note and your bags close, and chat says one line: `SwagBag: Tour ended. Type /swagbag tour to see it again.` or `SwagBag: Tour ended because your bags closed. Type /swagbag tour to see it again.` (say which: W9).
20. Go to a training dummy. Type `/swagbag tour`, then attack the dummy with one of your abilities. Expected: the ability is used, the note disappears at once, and chat says `SwagBag: Tour ended because combat started. Type /swagbag tour after the fight.` (W5)
21. Still in combat, type `/swagbag tour`. Expected: `SwagBag: The tour waits until you are out of combat. Type /swagbag tour again then.`; no note.
22. Stop attacking and wait until you are out of combat (about five seconds). Type `/swagbag setup`. Expected: `SwagBag: Setup opened.`; `M+` and `Gold-making` are green (remembered from step 12). Click `Next`.
23. Attack the dummy. Expected: the setup window disappears and chat says `SwagBag: Setup steps aside during the fight; it comes back where you were when combat ends.` (W6)
24. Stop attacking and wait until you are out of combat. Expected: the setup window is back at `Step 2 of 4: What that turns on`.
25. Click `Skip (use defaults)`. Expected: chat `SwagBag: SwagBag keeps your current settings. Type /swagbag to change anything.`; the window closes, and no tour is offered.
26. Type `/swagbag settings focus`. Expected: chat `SwagBag: Settings opened.`; the Focus modes page; below the `Mode: ...` lines a row `Your own modes` with a button `New mode`.
27. Click `New mode`. Expected: the status line says `A new mode: type its name, pick when it switches on, then click Make mode.`; below it a box under `Its name (press Enter or Apply)`, a row `It switches on` with `Only when I switch it on` highlighted and `In a Mythic+ key`, `In a dungeon`, `In a raid`, `In a delve`, `In a battleground or arena`, `While fishing`, `While gathering`, `At a vendor`, `At the auction house`, `At the bank`, and a row `Done?` with `Make mode` and `Cancel`.
28. Click into the box under `Its name (press Enter or Apply)`, type `Herb run` and press Enter. Expected: `Name: Herb run (click Make mode to keep it).`
29. Click `Make mode`. Expected: `Made the Herb run mode. Pick the sections it brings up below; switch it on with /swagbag mode on Herb run or in the list above.`; further down `Sections the Herb run mode opens (New is always open):` with every section `Collapsed`.
30. Click `Open` next to `Herbs`, then `Open` next to `Ore`. Expected: `Herbs now opens in the Herb run mode.`, then `Ore now opens in the Herb run mode.` Close the settings window and press **B** if your bags are closed.
31. Type `/swagbag mode on herb run`. Expected: `SwagBag: Herb run is on until you switch it off (/swagbag mode off), log out or reload.`; the bags' title starts with `SwagBag — Herb run`, and `Herbs` and `Ore` move to the top, right under New (W7).
32. Type `/swagbag mode list`. Expected: one line per mode; the last one `SwagBag: Herb run (you switch it): on, active now - opens Herbs, Ore`.
33. Type `/swagbag mode off`. Expected: `SwagBag: Switched off: Herb run.`; the sections go back to where they were (W7).
34. Type `/swagbag mode on raid`. Expected: `SwagBag: Raid switches on by itself, so it can't be switched here. Settings > Focus modes can turn it off.`
35. Type `/swagbag settings focus`, click `New mode`, type `Sell run` in the name box and press Enter, click `At a vendor`, then `Make mode`. Expected: `Made the Sell run mode. Pick the sections it brings up below.` Click `Open` next to `Junk`. Close the settings window, open your bags and talk to a vendor. Expected: the bags' title starts with `SwagBag — AH/Vendor/Bank + Sell run` (W8). Close the vendor.
36. Type `/swagbag settings focus`. In the row `Edit the sections of`, click `Sell run`; scroll down to `Remove this mode` and click `Delete`. Expected: `Click "Delete: sure?" to delete the Sell run mode. Any other click keeps it.`, and the button reads `Delete: sure?`. Click `Delete: sure?`. Expected: `Deleted the Sell run mode.`
37. Close the settings window and type `/swagbag profile export`. Expected: two chat lines, `SwagBag: Your settings' share string is in the box: press Ctrl+C to copy it.` and `SwagBag: Your own focus modes stay on this account: share strings don't carry them (Herb run).`; close the box.
38. Delete `Herb run` the same way as step 36 if you don't want to keep it. Expected: `Deleted the Herb run mode.`
39. If you want 12 slots per row back, or Fishing mode on again: type `/swagbag setup` and change them on steps 2 and 3, then `Finish` and `No thanks`. Expected: `SwagBag: Set up for M+, Gold-making. Change anything later: type /swagbag.`, then `SwagBag: Type /swagbag tour any time for a short tour of your bags.`
40. Type `/swagbag report`. Expected: `Failed checks: none` and no new error lines. Close the report box.

## Week 12 exit check

1. Claude installs the week-12 build, at the end of Task 5 (after review and fixes), and you fully restart the game.
2. Play normally for a day, with a key, a vendor and a bank visit. Expected: no red errors; no setup window by itself; nothing moves under your mouse; your focus modes behave as before.
3. Type `/swagbag report` and paste it to Claude. Expected:
   - `Safe Mode: bags=off bank=off`;
   - `Failed checks: none`;
   - `Blocked actions: none`.

## Spec updates at week end

Recorded in the week-12 ledger and applied to `docs/superpowers/specs/2026-09-30-swagbag-design.md` at week end (this plan commits only the plan file):
- **F7, AC7.1** gains: the wizard is the quick setup screen grown in place (one window, `setup.done`, account-wide); four steps, one screen each (What do you play? / What that turns on / How your bags look / Gold), Back, Next and Skip on every step, Finish on the last; nothing is written before Finish; a first run starts from the defaults, a re-run from the settings as they are and last time's styles (`setup.styles`); step 2 lists every built-in focus mode, the picked styles' switches and category moves; step 3 slots per row, size, the looks whose addon is loaded; step 4 the price source found (or vendor prices), the gold glow (Off / 50g / 100g / 500g / 1000g, or the top % set), selling junk; combat makes it step aside and come back; a user who finished the quick setup is never shown it by itself.
- **F7, AC7.2** gains: Skip is on every step and writes only `setup.done`; on a re-run it says the current settings are kept.
- **F7, AC7.3** gains: seven notes (headers, collapse and drag, focus modes and peek, search, the mode title and Pause, Sort, Safe Mode), each next to its part with a gold frame (beside the window when the part is not drawn); Back, Next, End tour, Esc; it opens the bags, refuses in combat or Safe Mode, ends with one line when the bags close or combat starts, never moves or lays out anything; Finish offers it once ("Show me around" / "No thanks"), not after Skip and not in combat.
- **F8, AC8.7** is worded out: up to 10 modes of your own, named 1–24 characters (not a built-in mode's name or id, unique, any case); trigger "only when I switch it on" or one of in a Mythic+ key, a dungeon, a raid, a delve, a battleground or arena, fishing, gathering, at a vendor, the auction house, the bank; sections with the built-ins' editor; a manual mode is on for the session (`/swagbag mode on <name>`, `off [<name>]`, or its line in Settings), needs no "Switch by themselves", and Pause stops it; merge as the built-ins, strict priority manual > combat > activity > location; Delete asks once more and its id is never given again; "This character only" covers them.
- **§6.3:** "Users create custom modes with the same editor" points to AC8.7; a mode of your own's class follows its trigger.
- **§6.5:** Recompute with ten modes of your own stays within budget (measured by the suite).
- **F9, AC9.2** gains the table of D6 (what each playstyle sets, written as explicit values at Finish; Gold's glow only when off).
- **F20:** share strings do not carry modes of your own (an export names them as left out; an import skips their entries and never makes one); the preview's "Ranked just below Junk" line names a category by the name it comes in under (AC20.4).
- **§8.2:** `settings.setup.styles` (this machine's state, never shared); `SwagBagDB.modes = { [m_id] = { name, trigger, n } | false }` (schema 2, read defensively); a mode's `focus.on.<m_id>` and `focus.sections.<m_id>` are ordinary settings.
- **§10.5:** `setup` runs the wizard; `tour` runs the tour; `mode on <name>`, `mode off [<name>]`.
- **§12.1 (what is in and out):** F7 (the full wizard and the interactive tour) moves from "Deferred" to "In", delivered in week 12 (v0.12.0); AC8.7 and AC9.2 delivered.

## Spec coverage (week-12 scope → task)

| Requirement (from the brief) | Task |
|---|---|
| 1a. The 4-step wizard building on the quick setup: playstyle multi-select; what that picks with simple on/off; layout (slots per row, scale, look); gold (price source detected, worth glow, auto-sell) | T1 (draft, plan), T2 (screen) (D1, D4–D9) |
| 1b. Back / Next / Skip / Finish; Skip applies the defaults and says so | T1 `Setup.Skip`, T2 (D3) |
| 1c. Choices applied only at Finish (decide, justify) | T1 `Setup.Plan/Finish` (D2) |
| 1d. `/swagbag setup` re-runs it pre-filled; existing users not shown it again | T1 `Setup.New` (`setup.styles`), T2 (D1, D7) |
| 2. Playstyle sets overlay defaults (AC9.2), written explicitly only at Finish | T1 `Setup.Preset` (D6) |
| 3a. `/swagbag tour`: callouts anchored to header, collapse, peek, search box, mode title / Pause, Sort, Safe Mode; Next / Back / End | T3 (D11) |
| 3b. Offered once at the end of the wizard | T3 (D12) |
| 3c. Ends cleanly if the bags close or combat starts; never moves items; P2 | T3 |
| 4a. New mode: name, trigger (manual or a built-in signal), section set (the existing editor) | T4 (engine), T5 (page) (D13, D14, D17) |
| 4b. Manual modes on/off with `/swagbag mode on <name>` / `off` and from the mode list | T4 (slash), T5 (the line) (D15) |
| 4c. Merge / priority with the built-ins | T4 (D16) |
| 4d. Delete with confirmation | T4 (`DeleteMode`), T5 (asks once more) (D18) |
| 4e. Per-character override works | T5 (`SF.Paths`, a new mode under "This character only") |
| 4f. Share strings carry custom modes or explicitly don't (decide) | T5 (D19: they don't; the export says so; an import skips them) |
| 5. Cheap deferred polish from the week-11 ledger if user-visible | T5 (D20), "Carry-overs" |
| Version 0.12.0 in Task 1 | T1 |

## How this plan was checked (while writing it)

- Every task was first built on a scratch clone at `/tmp/sb12` (outside the repo), one commit per task, test-first: each task's tests were run against the previous task's code (red) and then against its own (green). Every block in this file was then generated from those commits' diffs by a script: each find block is the smallest one, grown line by line above and below a hunk of git's histogram diff, that occurs exactly once in the file as it is after the earlier edits, starts and ends on a non-blank line, holds a line of at least twelve characters, and whose replacement also starts and ends on a non-blank line; the script re-applied every block to the old file and compared the result with the commit's file.
- **Replay.** A fresh clone of `8503e06` (`/tmp/sb12v`) was driven by a script that reads this file: for each task it applies the Step 1 blocks, runs the suite, applies the Step 3 blocks, runs the suite and `scripts/check.sh`, then commits. Every find block occurred exactly once when applied; every Step 2 count and FAIL list (name by name), every Step 4 total, every Step 5 `ALL CHECKS PASSED` and TOC count, and every Step 6 `git add` list (equal to the files the task changed) above is that script's output, and each replayed commit's tree equals the scratch commit's. Final total: **1663 passed, 0 failed**.
- **Mutations.** Every mutation listed under a Step 2 (54 in all: 14, 8, 10, 13, 9) was read back from this file by the same script, applied to its own task's replayed commit, and the whole suite run: every one made its named test fail.
- **Strings.** Every quoted string in session WZ1 was compared with `enUS.lua` (and, for the composed lines, produced by the code under test in the specs: the step labels, the step-2 switch texts, the price line, the tour's notes and endings, the mode answers); `N` and the price addon's name are the only placeholders.
- Greps on the final tree:
  - no `C_`/`Enum.` outside `SwagBag/Core/Adapter.lua`, no `TSM_API`/`LibStub` (check.sh); no `ElvUI` or `Syndicator` in the new or changed code; none of the forbidden tokens;
  - no `loadstring`, `load(`, `RunScript`, `setfenv` or `dofile` in `SwagBag/`;
  - `UI/Tour.lua` calls nothing on `SB.BagsWindow` but `IsOpen` and `Open` (no `RequestLayout`, `Reflow`, `Sort`, `Layout`, `ToggleSection`, `SetView`), and never names `SB.Buttons` (no item button);
  - V0: no change to `UI/BagsWindow.lua`, `UI/SectionHeaders.lua`, `UI/SearchBox.lua` or any other bag-window file;
  - no `SetScript("OnUpdate", ...)` anywhere; no `Config` call at load (the quick setup's load-order test, and `Engine/Setup.lua`, `UI/Tour.lua` read settings only in functions); no `%s` given a boolean (format51 runs on every spec).

## Self-review

1. **Scope coverage.** Every item of the brief maps to a task or a named decision in "Spec coverage", in the brief's order (the wizard, the overlays, the tour, modes of your own, the polish). Each open question has a decision row: wizard vs quick setup (D1), when it writes (D2), Skip (D3), pre-selection (D4), step 2 (D5), AC9.2 per style (D6), re-runs (D7), layout (D8), gold (D9), combat (D10), the tour (D11), the offer (D12), storage (D13), triggers (D14), manual on/off (D15), priority (D16), names (D17), delete (D18), share strings (D19), the polish (D20), the version (D21), the principle (D22).
2. **Placeholder scan.** No "TBD", "TODO", "similar to", or test-free step. Every code step is a complete block (the replay applies them as written). The in-game expectations quote Locale strings verbatim; where a line holds the player's own names or numbers the step says so.
3. **Type and name consistency.** These names are the same in every task that uses them: `SB.Setup` (`STYLES`, `Preset`, `Order`, `New`, `Toggle`, `Value`, `Set`, `Switches`, `Label`, `Plan`, `Finish`, `Skip`; the draft `{ styles, touched }`; `"order.gold"`, `"order.collector"`), `setup.styles`, `SB.QuickSetup` (`step`, `STEPS`, `draft`, `Show`, `Paint`, `Close`, `IsOpen`, `TryShow`, `lit`, `styleButtons`, `switchButtons`, `columnButtons`, `scaleButtons`, `lookButtons`, `worthButtons`, `sellButtons`, `backButton`, `nextButton`, `finishButton`, `skipButton`, `offer`, `tourButton`, `noTourButton`), `SB.Tour` (`STEPS`, `Start`, `Next`, `Back`, `End`, `step`, `target`, `frame`, `ring`, `backButton`, `nextButton`, `endButton`), `SB.Focus` (`TRIGGERS`, `custom`, `manual`, `All`, `Mode`, `IsCustom`, `NameOf`, `ManualOn`, `LoadCustom`, `CheckName`, `CreateMode`, `RenameMode`, `SetTrigger`, `DeleteMode`, `SetManual`, `FindMode`, `CustomNames`, `MAX_CUSTOM`, `MAX_NAME`; a mode `{ id, name, custom, triggerId, class, n, trigger }`), `SwagBagDB.modes`, `SB.SettingsFocus` (`creating`, `confirmDelete`, `renameText`, `Paths`).
4. **Review Focus.** Each of the thirteen lines names its pinning tests, and each of those tests is in its owning task's Step 1.
5. **Global Constraints.** No `C_`/`Enum.` anywhere new; no Adapter change; no secure frame or item button touched; every new entry point under `"none"`; every user-visible string in `enUS.lua`; schema 2 with two defensively read additions (`setup.styles`, `SwagBagDB.modes`), a week-11 save loads unchanged; nothing typed is run; no `OnUpdate`; nothing runs while idle; nothing new in the bag window (V0).
6. **Known limits, stated in the plan.** Modes of your own are not in share strings (D19), and a profile Load or Defaults replaces their switches and sections like any setting (the modes themselves stay). A manual mode is on for one session only (D15). One trigger per mode (D14). The wizard's step 3 has no button for a slots-per-row or size value set elsewhere (D8). The tour's note follows a part's frame; if the bags are scrolled so the first header is out of view, its note may point off the visible area (W4). The tour is offered after Finish only (not after Skip, not in combat), once per Finish.
