# SwagBag Week 5: the List View, Syndicator and Alt Data, and Themes. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three features the user picked, pulled forward from spec §2.2 v1.1–v1.3. (1) A third bag view, the **list view**: "Sorted-style" rows with name, count, item level and AH value, sortable by clicking a column, where every row still acts on the real item. (2) **Alt data**: the spec's `AltData` module with its built-in "Own" provider and a **Syndicator** provider, used by tooltip counts on every item and by an **alt viewer** that shows any saved character's bags, bank, warband bank and guild bank, read-only, with search. (3) **Themes**: a registry whose default "Blizzard" look is exactly today's, plus "Modern flat" and "Matches ElvUI", switched live with no `/reload`.

**Architecture:** The list view is not a new layout engine. It is the category view drawn as rows: the bags window sorts the slots with a new pure `Engine/Sort.lua`, hands them to the existing `Engine/Layout.lua`, and positions them one per row (one column, row-high cells). Each row is the slot's own `ContainerFrameItemButtonTemplate` button, scaled to the row height and placed at the row's left edge, plus a plain text frame (`UI/ListRows.lua`) beside it. So New, Free, placeholders, collapse, focus modes, W10 and the hover guard all work unchanged. `Engine/AltData.lua` implements spec §3.3: providers by priority, three errors switch one off, a built-in "Own" over `Engine/Snapshots.lua`. `Providers/Syndicator.lua` reads Syndicator's public API through the Adapter. `UI/TooltipCounts.lua` and `UI/OfflineWindow.lua` (on `UI/GroupView.lua` with plain display buttons) are the two consumers. `UI/Theme.lua` is a registry of palettes. SwagBag's own frames register once and are restyled on every switch. The built-in "blizzard" palette holds exactly the numbers the windows use today, and `UI/Themes.lua` adds the other two looks.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- §2.2 v1.3 "List view (Sorted-style rows with name, count, ilvl, AH value column, sortable)", in the bags window (D1–D9);
- §2.2 v1.2 "Syndicator provider for alt data (replaces own store when present)" and §3.3 "AltData" (D10–D15);
- §2.1 F13 AC13.2 (offline view of any alt's bags, bank and warband bank "via the character dropdown", with an age stamp) and AC13.3 (tooltip counts), which §12.1 had deferred to November (D16–D21);
- §2.2 v1.3 "Themes: modern flat; ElvUI-matching (auto-detect ElvUI, use its media)", and AC14.1 (the default stays Blizzard-like), §3.2 `Theme` (D22–D27);
- §3.2 `Sort` ("display order as data"; the physical sort stays where it is) and `Views.Offline`;
- every week-4 ledger item marked deferred to week 5 that touches code this week changes (see "Week-4 carry-overs").

Ledgers (binding rulings W3-*, W4-*): `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md`, `docs/superpowers/plans/2026-10-03-swagbag-week4-ledger.md`. Week-4 plan (style and interfaces): `docs/superpowers/plans/2026-10-03-swagbag-week4-focus-modes.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week5-views`, already checked out, made from `week4-focus` at `d759564` (week 4 is not merged to `main` yet; 992 tests). No task creates or switches branches.

**The code at `d759564` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). These interfaces are used as they are on `d759564`:
- `SB.On(event, fn, window)`, `SB.Emit`, `SB.Debounce(key, delay, fn, window)`, `SB.OutOfCombat(fn, label, window)`, `SB.ErrorTrap.Run(label, window, fn, ...)` and `Guard(label, fn, window)`. The window labels are `"bags"`, `"bank"` and `"none"` (record only).
- `SB.Config.Get/Set/CharOverride/CharOverrideMany/UI/Defaults/readOnly`. `Set` returns false while read-only, and every write emits `SB_CONFIG_CHANGED(path | nil)`.
- `SB.Slash.Register(name, help, fn, window)` and `SB.Slash.Run(line)`. `SB.SettingsWindow.AddPage{ id, title, rows }`, `.RunCommand(line)`, `.Say`, `.Show(page)`, `.lastStatus`. The row kinds are `choice`, `actions`, `drop` and `note`.
- `SB.BagsWindow`:
  - `W.view` (the drawn collapsed lookup, W4-1) and `W.Restack(area)` with `W.areaHeld` (W4-13);
  - `W.RequestLayout(reason)` (held while the mouse is over the items or an item is on the cursor);
  - `sizeFrame(width, height, keepTop)`, with the footer room, the W4-22 room clamp and the W4-25 grow-up and its `"bags.grow"` retry; `W.Resize()`;
  - `W.SetView`, `W.ToggleView`, `W.viewButton`, `W.BoundTitle(leftmost)`, `W.Flash`, `W.RefreshTitle`, `W.ForEachSlot`, `W.ButtonBusy`, and the locals `showAt`, `renderExtras`, `renderMoved`, `paintTiles`, `overlay`, `describe`, `layoutSections`, `layoutGrid`, `positionOpts`.
- `SB.GroupView.New(cfg)` (cfg as documented at the top of `UI/GroupView.lua`), `SB.SectionHeaders.Acquire/SetLabel/ReleaseAll`, `SB.Buttons.Get/Place/Paint/SetDimmed/AcquirePlaceholder/DIM_ALPHA/PLACEHOLDER_ALPHA`, `SB.Overlays.Apply/RefreshAll/regions`, `SB.Footer`.
- `SB.Prices.Value(link, itemID, bound)` (D11 and W3-35: a bound or WuE item gets its vendor price), `SB.Prices.Money`, `SB.Snapshots.DB/Save/SaveGuild/Serialize/Deserialize/Age/Count/Bytes`, `SB.Items.Describe/DescribeLink`, `SB.OverlayData.SLOTS/CanCompare`, `SB.Focus.SetSignal`, `SB.SearchBox.New`, `SB.SearchState.New`.
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua`, `uienv.lua` (`Env.ENGINE`, `Env.FakeBags`, `Env.LoadBank`), `spec/mock_adapter.lua`, `spec/fixtures/items.lua` (`Fixtures.SmallBags`).

## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.5.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. Syndicator (all rights reserved) and ElvUI were read for **public API names only**. The names this plan uses are listed in D12 and D26, and nothing else of theirs is used.
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator`.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets a string or a number, never a boolean or nil (WoW's Lua 5.1 errors where LuaJIT does not). Pass `tostring(v)` or a Locale word. From Task 1 every spec runs with `spec/helpers/format51.lua`, which makes the tests as strict as WoW.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace or `Enum`, **comments included**. It is grep-enforced for `C_X.`/`Enum.` and review-enforced for bare names. Every other file calls `SB.Adapter.*`. Files under `spec/` may name them as test data.
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`. `SetCurrentGuildBankTab` is never called.
- P1: every setting ships with a chosen default, and its alternative sits next to it in the same place. Options are phrased as choices, never as abstract toggles.
- P2: every command, button and settings choice answers with a chat line, a title flash or the settings window's status line. A title flash that does not fit the title also goes to chat (Task 3). Silence is a bug.
- P5 / spec §4.2 rule 5: nothing moves under the mouse or while an item is on the cursor. Held moves retry 300 ms later through `SB.Debounce`, never `OnUpdate`. In the list view a row counts as part of its button: the mouse on a row's text holds that button (D5).
- W10 / spec §6.4: applying a mode never moves a button relative to its own section header. The list view uses the same sections and the same `Restack`, so this holds there too (D3).
- P6 (amended, week-4 deferred: W4-7 and the consumables note). Every WoW entry point runs inside `SB.ErrorTrap.Run` or `Guard`: events, hooks, frame scripts, timers, slash commands, external callbacks (Syndicator's callback registry, the tooltip post-call). The window label is the one whose Safe Mode a failure there may flip:
  - the bags window, its list rows and column bar, focus signals and the consumables triggers use `"bags"`;
  - bank and guild code keeps `"bank"`;
  - settings, quick setup, themes, tooltip counts, alt data and the alt viewer use `"none"`. A glitch there is recorded for the report but never takes the bags away; the alt viewer has no Blizzard window to fall back to;
  - a command run from the settings window traps under that command's own window and label (W4-7). So a bank or guild row can Safe-Mode the bank, exactly like the typed command;
  - known exception, unchanged: the consumables warning at key start traps as `"bags"` (week-4 note).
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`.
- Secure frames (amended, week-4 deferred "BackdropTemplate"):
  - item buttons are never created in combat, never reparented, never re-`SetID`'d;
  - the list view only scales and places the pool's own buttons (D4);
  - SwagBag's other frames are plain: `Frame`, `Button` (`UIPanelButtonTemplate`, `UIPanelCloseButton`, or none), `ScrollFrame`, `EditBox` (`SearchBoxTemplate`), and `"BackdropTemplate"` (a plain template), with `FontString` and `Texture` regions. They may be created in combat;
  - the alt viewer's display buttons are plain `ItemButton`s with **no template** (D18).
- Themes restyle only SwagBag's own frames: window backdrops, title and other font strings SwagBag made, section headers, the footer, list rows, the settings window, the quick setup, SwagBag's own `UIPanelButtonTemplate` buttons, and the slot background texture SwagBag adds under each item. Nothing of Blizzard's on an item button changes: not the icon, the quality border, the count or the cooldown. Themes add no frame (D23).
- A focus mode never writes the user's saved collapse state (`SwagBagCharDB.ui.collapsed`).
- Settings (amended, week-4 deferred "new keys"): every new settings key has a default in `Config.Defaults`. New this week: `bags.list.sort` and `bags.list.desc`, `theme.name`, `tooltip.counts`. No schema bump: all of them live under `settings`. Every new writer refuses while `Config.readOnly` and says `L.SETTINGS_READONLY`.
- No file calls `Config` at load time (a load-order test per new window). Every `OnHide` handler starts with `if self:IsShown() then return end`.
- No `OnUpdate` anywhere. Idle CPU with every window closed is 0. No polling of Syndicator or ElvUI: Syndicator's own callbacks and SwagBag's events drive every refresh.
- Every critical test names the mutation that must make it fail.
- **Tooling (binding, as in weeks 1–4):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). Where a test fakes a frame method WoW has, it fakes it the way WoW behaves. CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- One commit per task, made with `git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit`. The message ends with exactly these two lines:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`
- In-game checks are written for the user, who is not a programmer:
  - each session begins with "Claude installs the build first" (the user's game runs a stable week-3 copy until then);
  - steps are numbered, one action per step, each saying exactly what the user should see;
  - quoted strings match `SwagBag/Locale/enUS.lua` exactly, and chat lines start with `SwagBag: `;
  - a step after a click on an item says to move the mouse off it;
  - a session after a task that adds files starts with a full game restart, not `/reload`.

  Sessions never block the build: findings come back as fixes.

## Review Focus

The five failure modes most likely to bite the user that the spec implies but does not spell out, most likely first. Each is pinned by tests in the task that owns the code.

1. **Using an item from a list row, in and out of combat** (a potion mid-key, a gray item at a vendor, a deposit at the bank, a split). The list view draws the slot's real button smaller. Expected: every click on the icon is Blizzard's own item click, and nothing is ever "blocked". Pinned by:
   - Task 2: "the list view makes only plain frames and never reparents or re-IDs a slot button, also in combat";
   - Task 2: "offsets a scaled button by x / scale and y / scale, so it lands on the same spot";
   - session L1, steps 8–12 (combat use, split, vendor, a drop, bank). D4 gives the one-constant fallback if the client objects to a scaled button.
2. **The mouse resting on a row's text while something changes** (loot arrives, a mode switches, a column is clicked, the view changes). Expected: no row moves under the mouse. The change lands once the mouse leaves, and loot meanwhile lands in the drawn geometry. Pinned by:
   - Task 2: "a collapse waits while the mouse is on the row (not the icon) of a button that would move";
   - Task 2: "a layout held under the mouse keeps drawing the old view's geometry until it runs";
   - Task 3: "a re-sort waits while the mouse is over the items or an item is on the cursor".
3. **Syndicator installed but not ready, hiding a character, or throwing.** Expected: SwagBag uses its own data until Syndicator is ready. It never shows a character the user hid in Syndicator. After three errors it switches Syndicator off for the session with one line, and every tooltip and the alt viewer carry on. Pinned by Task 7: "answers only while Syndicator is loaded, complete and ready…", "lists Syndicator's characters … hidden ones left out" and "three errors switch Syndicator off for the session…".
4. **Many saved characters and a tooltip on every hover.** Expected: hovering stays instant. The count index is built once per saved container and rebuilt only when that container is saved again. Pinned by Task 6: "25 saved characters: the first count builds the index in under 50 ms; then a count takes under 1 ms" and "the index is built once per container and dropped when that container is saved again".
5. **A saved look whose addon is gone, and damaged saved data** (ElvUI disabled next session; a hand-edited or truncated SavedVariables line). Expected: the Blizzard look with one line, the choice kept; a damaged line is skipped, never an error. Pinned by:
   - Task 5: "a saved ElvUI look while ElvUI is not loaded shows Blizzard's at login, says so, and stays saved";
   - Task 9: "a damaged saved line or a link with no item ID is skipped: no button, no error".

## Decisions and resolved spec ambiguities (read before Task 1)

| # | Brief or spec text | This plan | Why |
|---|---|---|---|
| D1 | "Choose whether stacks of the same item across slots are grouped into one row or shown one row per slot" | **One row per slot.** Two stacks of a potion are two rows. | Each row is a real slot button, so a right-click acts on exactly the stack it shows. A grouped row would have to pick one slot to act on, or need a button per stack anyway. Item safety wins, and the count column still shows each stack. |
| D2 | v1.3 "Sorted-style rows … sortable" | The list view is the **category view drawn as rows**: the same sections (New, categories, Free) with their headers and value totals, each section listed in the chosen order. It is not one flat list. | The sections give the user the same mental map in every view. Free, New and placeholders keep their spec §4.3 meaning. The layout engine and every P5 rule are reused unchanged instead of re-proved. |
| D3 | "decide and justify whether a mode collapses anything in list view" | **Yes: a focus mode collapses exactly the sections it collapses in the category view.** Peek, pin, Pause and the title work the same. In the grid view a mode still changes only the title (week-4 D10). | Because of D2 the list has the same sections. An M+ player who prefers rows still wants only Consumables, Keystone and Gear open in a key. W10 holds because the list re-stacks through the same `W.Restack`. |
| D4 | "Rows must still act on real items. Use the existing secure ContainerFrameItemButtonTemplate buttons, one per slot … Never create secure buttons in combat and never reparent them." | Each row's icon **is** the slot's pool button, scaled to `LIST_ROW / SLOT` (24/37) with `SetScale` and placed at the row's left edge. `Buttons.Place` divides its offsets by the button's scale, so a point lands where the window means. Other views set the scale back to 1. No button is made, reparented or re-ID'd. Fallback, if session L1 step 8 shows a "blocked" message: set `W.LIST_ROW = 37` (rows as tall as a button). The scale is then 1, `SetScale` is never called, and nothing else changes. | The pool's buttons are not protected (spec §4.1, verified), so a frame method on them is as legal in combat as `SetPoint`. `SetScale` itself has not been tried in combat, so it is session L1's first check, with a one-constant fallback. |
| D5 | "the hover guard (P5: re-sorting must not move a row under the mouse)" | A row's text frame counts as part of its button: `W.ButtonBusy` is also true while the mouse is on that slot's row. A re-sort is a full layout (`W.RequestLayout("listsort")`), held while the mouse is over the items or an item is on the cursor. A count change repaints the row in place and **never re-sorts**. The order changes only on open, Reflow, sort, a column click or the view toggle. | Same rule as categories (AC3.4: items move only on the next open or Reflow). Sorting by count while counts change would move rows constantly. |
| D6 | "Sorting by name, count, ilvl or value, ascending and descending, is persisted" | Settings `bags.list.sort` (`"value"`) and `bags.list.desc` (`true`): **worth most first** by default. A click on the sorted column flips it. A click on another column starts at its natural direction: names A to Z, numbers highest first. An item with no value for the column (a potion's item level, an unpriced item) goes last either way. Ties go by name, then physical order. `/swagbag list [name\|count\|ilvl\|value] [asc\|desc]` and two rows on Settings > Bags. | Spec goal 3, "tells you what your stuff is worth". Deterministic order (spec §7.7 "no pairs()"). |
| D7 | "AH value column" | The value is the **stack's** value: `Prices.Value` per unit × count. Bound and WuE items get the vendor price (D11, W3-35). The cell is blank when nothing pays for it. The item level shows for equippable gear only, as the overlay does. | The section header totals already sum stack values; the column adds up to them. |
| D8 | "It is a third view alongside sections and grid … Toggle it via the existing view button, a settings row and a slash command" | The view button cycles **categories → list → grid → categories** and is labelled with the view a click shows next (`List`, `Grid`, `Categories`). `/swagbag view [sections\|list\|grid]`. Settings > Bags > `Bag view`: `Categories`, `List`, `Grid`. Two existing view-toggle tests and the settings P1 test change with this order (Task 2 Step 1). | One button, as week 1 asked for, and each click says what it will do. |
| D9 | "Add it to the bank and guild windows if that stays cheap; otherwise list them as later" | **Later (week 6).** The bags window only. | The bank and guild bank draw through `UI/GroupView.lua`, which has its own place and redraw code for three users: bank, guild bank and the alt viewer. Rows there need the scale, row and column code a second time, plus the guild's plain buttons. That is about a task's worth of work and tests. `UI/ListRows.lua` and `Engine/Sort.lua` are window-agnostic, so week 6 adds it once in GroupView. |
| D10 | §3.3 AltData "highest-priority available provider wins per call" | Per call, the best available provider that **answers** wins; one that answers `nil` hands the call to the next. Availability is asked on every call, not cached. Three errors in a session switch a provider off, with one chat line and one `"none"` error-ring entry. | Syndicator becomes ready only after its own login work. Per-call fallback lets the guild bank and characters Syndicator never saw come from SwagBag's own data. |
| D11 | v1.2 "Syndicator provider for alt data (replaces own store when present)" | **Replaces, while Syndicator answers:** the character list, every character's bags and bank, the warband bank, and tooltip counts. **Adds:** characters SwagBag never saw, and the mail, worn, auction and void counts only Syndicator tracks. **Stays SwagBag's own:** guild banks (SwagBag's guild snapshots answer), the item index for its own data, and the snapshots themselves, which are still saved, so uninstalling Syndicator loses nothing. A character hidden in Syndicator (`show.inventory == false`) is not listed. | "Replaces" read as "answers instead of" (reading), not "stops saving" (writing). Spec §8.4 budgets already pay for the snapshots. |
| D12 | "Find the real Syndicator API by reading … for API names only" | Syndicator v284 public names used: `Syndicator.API.IsReady`, `.GetAllCharacters`, `.GetByCharacterFullName`, `.GetWarband`, `.GetInventoryInfoByItemID` and `Syndicator.CallbackRegistry:RegisterCallback(event, fn, owner)`, for the events `BagCacheUpdate`, `WarbandBankCacheUpdate`, `GuildCacheUpdate` and `Ready`. Data fields read:<br>• character `bags[i]` (bag i − 1), `bankTabs[i].slots` (bag 5 + i) and `details.character`, `.realm`, `.realmNormalized`, `.className`, `.show.inventory`;<br>• the warband's `bank[i].slots` (bag 11 + i);<br>• a slot's `itemLink` and `itemCount`;<br>• from `GetInventoryInfoByItemID`: `characters[]` (`character`, `realmNormalized`, `className`, `bags`, `bank`, `mail`, `equipped`, `auctions`, `void`), `guilds[]` (`guild`, `realmNormalized`, `bank`) and `warband[1]`.<br>The Adapter resolves and feature-checks the API; `Providers/Syndicator.lua` only maps shapes. | Only public, documented-in-file API functions. No internal tables, no code. |
| D13 | — (two key spellings) | A character's key in `AltData` is **canonical**: `Name-Realm` with the realm's spaces and hyphens removed (`Swagger-ArgentDawn`), as Syndicator writes it. `AltData.Canon` maps SwagBag's own keys (`Swagger-Argent Dawn`). | Both providers then name a character the same way: tooltips mark the current character, and the alt viewer finds a Syndicator character's guild in SwagBag's data. |
| D14 | §8.4 "Aggregated counts are derived at load into an in-memory index … never stored" | Own's index is one `itemID → count` table **per saved container**, built the first time a tooltip asks. It is dropped only when that container is saved again (`SB_SNAPSHOT_SAVED(kind, owner)`, new in `Engine/Snapshots.lua`). The current character's bags are counted **live** from `Engine/Inventory.lua`, not from the snapshot saved 5 s after loot. | "At load" would cost every login. Lazy-per-container costs the first hover only, and a bag save rebuilds one table, not 25 characters'. |
| D15 | Items are counted by `itemID` | `AltData.ItemID(link)` reads `item:`, `keystone:` and `battlepet:` links (a caged pet counts as Pet Cage 82800). | Spec §8.3 stores links only. A pure link parse needs no API call per line. |
| D16 | AC13.3 "Item tooltips show 'You have N (Bags 3, Bank 2 on Alt)'" | Lines under every item tooltip:<br>• `SwagBag: 27 in all`;<br>• one line per character, the current one first as `Name (this character)`, in its class colour, with `Bags 5, Bank 20, Mail 2` (only non-zero parts);<br>• `Warband bank` and `<Guild> (guild bank)` lines;<br>• at most 8 characters, then `...and N more characters`.<br>No lines when the only place is this character's bags. | One line per place reads better than one long sentence. The bag-only case would add noise to every hover. |
| D17 | — (Syndicator also writes tooltip lines) | Setting `tooltip.counts`: `"auto"` (default: shown **unless Syndicator is loaded**, since it writes the same lines), `"on"`, `"off"`. `/swagbag tooltip` and Settings > Alt data. | No duplicate lines for a Syndicator user (P3). `On` is one click away (P1). |
| D18 | "Reuse GroupView and plain display buttons. These are NOT secure item buttons" | `UI/DisplayButtons.lua`: plain `ItemButton`s with **no template**, made on first use per (bag, slot) of the saved data, kept for the session (plain frames, so allowed in combat). A click answers `Saved items can't be used from here. Shift-click links one in chat.`, a modified click links the item, and hovering shows the item's tooltip from its link. | Nothing in the alt viewer can use, move or sell an item, whatever is clicked. |
| D19 | AC13.2 "via the character dropdown, with an 'as of 2 days ago' stamp" | `/swagbag alts [name]` and Settings > Alt data > `Open the alt viewer` open it on this character (or the named one). A `Character: <name>` button opens a list of every saved character, with age when known, and a click shows that character. Groups, top to bottom: `Bags`, `Bank`, `Warband bank`, `Guild bank: <guild>`. Each header carries the age (`- 2 days ago`) or the source (`- from Syndicator`). Each group shows the category sections, with New hidden while empty (new GroupView option `hideEmptyNew`) and no Free (empty saved slots get no button). Search has its own box. No upgrade arrow on saved items (`record.offline`): they may be another character's. | Reuses GroupView whole. A title button on the bags window was left out (D21). |
| D20 | — (which guild belongs to an alt) | `Engine/Snapshots.lua` now also saves `chars[key].guild` (the character's `GuildKey` when last seen), and the alt viewer shows that guild's saved bank. | The spec stores guild banks per guild, not per character. One field links them. |
| D21 | — (where the alt viewer is reached) | No new button in the bags title row. | The row already holds Sort, Pause, Reflow and the view button. In the list view (480 px) another button would squeeze the title to nothing. Settings > Alt data is where P1's "easy to find" points. |
| D22 | AC14.1 "Default theme uses Blizzard's bag atlases/fonts and quality borders" | `theme.name = "blizzard"` by default, and the built-in "blizzard" palette is the exact numbers the windows use today:<br>• backdrop 0.06/0.06/0.08 at 0.95 (dialogs 0.97), border 0.35/0.35/0.4;<br>• header 1/1/1 at 0.06;<br>• the `bags-item-slot64` atlas;<br>• each font string's own font object.<br>The windows keep their old lines, and registering re-applies the same values. | "The default stays exactly as it looks today" is then a test, not a promise (Task 4). |
| D23 | "Themes restyle only SwagBag's own frames … button borders where SwagBag owns them" | A theme restyles window backdrops, font strings SwagBag made, section header backgrounds, list-row backgrounds, SwagBag's own `UIPanelButtonTemplate` buttons and SwagBag's slot background texture. A flat look hides a template button's `Left`/`Middle`/`Right` textures and shows one flat texture of SwagBag's own. The deposit group's green tint survives a theme switch (`SectionHeaders.Tint`). Not themed: `UI/ReportBox.lua` and `UI/DebugV1.lua` (diagnostics, kept recognisable), and every Blizzard region on an item button. | Exactly the brief's list. Nothing secure is touched. |
| D24 | "Live switch from a settings row and a slash command, with no reload" | `Theme.Apply(id, save)` restyles every registered object at once, in or out of combat, and emits `SB_THEME_CHANGED`. `/swagbag theme [blizzard\|flat\|elvui]` and a new Settings > **Look** page (`UI/Themes.lua`) that runs that command (week-4 D17). | One code path for both; legal in combat because only plain frames and SwagBag's own regions change. |
| D25 | v1.3 "Themes: modern flat" | `flat`: dark flat panels (0.09/0.09/0.10), a black edge, white text (`GameFontHighlight` family), flat slots and buttons, a faint stripe behind list rows. | Blizzard's own font objects, so no font file is shipped. |
| D26 | v1.3 "ElvUI-matching (auto-detect ElvUI, use its media)" | `elvui` ("Matches ElvUI") is available only while ElvUI is loaded. `Adapter.ElvUIMedia` reads ElvUI's public globals: `ElvUI[1].media.normFont`, `.blankTex`, `.bordercolor`, `.backdropcolor`, `.backdropfadecolor` (each with r/g/b/a and [1]–[4]) and `ElvUI[1].db.general.fontSize`. ElvUI v13.97 is installed on the user's machine and was read for these names only. It reads them again on every switch. Without ElvUI the choice is refused with `The ElvUI look needs ElvUI, which is not loaded. The look stays %s.` A saved `elvui` with ElvUI gone shows the Blizzard look for the session, says so once, and stays saved. **"Auto-detect" means the theme finds ElvUI's media by itself; it does not switch the default.** | AC14.1 keeps Blizzard as the default even for an ElvUI user; the choice is one click on the Look page. |
| D27 | — (P2 for long flashes) | A title flash that the title's room cuts short (`FontString:IsTruncated()`) is also printed to chat (week-4 deferred M4). | The list view's narrower window makes this likelier. A truncated answer is no answer. |
| D28 | — (report) | `/swagbag report` gains `Look: <current> (setting <saved>)` and `Alt data: <source>, <n> characters`. | Claude needs both to read a theme or alt-data bug from a pasted report. |

## Week-4 carry-overs (from `docs/superpowers/plans/2026-10-03-swagbag-week4-ledger.md`, "Final: deferred → week 5")

| Ledger item | Where |
|---|---|
| "drag stops the grow retry and drop doesn't re-fit (call W.Resize in OnDragStop)" | Task 3 (`OnDragStop` calls `W.Resize()`; test "a drop fits the window again…") |
| "no default-anchor (y=100) grow test" | Task 3 (test "at the default place, Pause with the mouse away grows…"; it passes before Task 3's code, it pins week-4 behaviour) |
| "M4 title flash truncation (O2/FT1 watch)" | Task 3 (D27) |
| "amend P6/constraint wording (W4-7, BackdropTemplate, 'new keys')" | Global Constraints above: P6, Secure frames, Settings |
| "consumables trap 'bags' at key start (P6, noted)" | Global Constraints, P6 (named as the known exception) |
| "CurrencyList isHeader secret guard" | Task 7 (`Core/Adapter.lua` changes there anyway) |
| "unbounded 300 ms grow retry while mouse rests" | Not changed. Accepted as ruled in W4-25: one cheap resize every 300 ms while the mouse rests on a window that is too short, ending the moment the window fits. |
| "M5 no-op focus writes re-stack" | Not this week: `Engine/Focus.lua` is not changed. Week 6. |
| Week-3 leftovers still open (shared bank-window shell W3-8, tabs added mid-visit, guild server refusals, caged pets in the guild bank, xpcall traceback in `ScanKind`) | Not this week. Themes touch the bank and guild windows only with one `SB.Theme` block each; none of these files' logic changes. Week 6 hardening. |

---

## File structure (end of week 5)

New and changed files only. Everything else is as on `d759564`.

```
SwagBag/Engine/Sort.lua                NEW  (T1) display order: columns, saved spec, Next, Ilvl, Value, DisplayOrder
SwagBag/UI/ListRows.lua                NEW  (T1) list-view row texts per slot button: place, paint, ghosts, dim, hover
SwagBag/UI/Theme.lua                   NEW  (T4) theme registry, the built-in Blizzard palette, Window/Text/Button/Slot/Row, Apply
SwagBag/UI/Themes.lua                  NEW  (T4, T5) Modern flat, Matches ElvUI; /swagbag theme; Settings > Look
SwagBag/Engine/AltData.lua             NEW  (T6) providers by priority, the built-in "Own" over snapshots, the count index
SwagBag/Providers/Syndicator.lua       NEW  (T7) the "Syndicator" provider (characters, containers, counts, updates)
SwagBag/UI/TooltipCounts.lua           NEW  (T8, T10) counts under item tooltips; /swagbag tooltip; Settings > Alt data
SwagBag/UI/DisplayButtons.lua          NEW  (T9) plain display buttons for saved items
SwagBag/UI/OfflineWindow.lua           NEW  (T9, T10) the alt viewer; /swagbag alts; the character picker
SwagBag/UI/BagsWindow.lua              MOD  (T2) the list view; (T3) column bar, W.SortList, /swagbag list, carry-overs; (T4) theme
SwagBag/UI/Buttons.lua                 MOD  (T2) Place keeps parent units at any scale; (T4) slot background themed
SwagBag/UI/SearchBox.lua               MOD  (T2) the bags box dims through W.SetDimmed (button and row)
SwagBag/UI/SettingsPages.lua           MOD  (T2) List in the view row; (T3) list sort and order rows
SwagBag/UI/SectionHeaders.lua          MOD  (T4) themed text and background; Tint; restyle on SB_THEME_CHANGED
SwagBag/UI/GroupView.lua               MOD  (T4) the deposit tint through SectionHeaders.Tint; (T9) hideEmptyNew
SwagBag/UI/BankWindow.lua, GuildBankWindow.lua, SettingsWindow.lua, QuickSetup.lua, Footer.lua   MOD  (T4) theme registration
SwagBag/UI/Overlays.lua                MOD  (T10) RefreshAll includes the alt viewer
SwagBag/Engine/Snapshots.lua           MOD  (T6) chars[key].guild; SB_SNAPSHOT_SAVED(kind, owner)
SwagBag/Engine/Items.lua               MOD  (T9) DescribeLink takes a location
SwagBag/Engine/OverlayData.lua         MOD  (T9) no upgrade verdict for a saved (offline) item
SwagBag/Core/Adapter.lua               MOD  SlotTooltip (T1), FontObject (T4), ElvUIMedia (T5), Syndicator + CurrencyList guard (T7),
                                            HookItemTooltip/TooltipLine/ClassColour (T8), LinkTooltip (T9)
SwagBag/Core/Config.lua                MOD  bags.list (T1), theme.name (T4), tooltip.counts (T8)
SwagBag/Core/Report.lua                MOD  Look line (T5), Alt data line (T7)
SwagBag/Core/Init.lua, SwagBag.toc, Locale/enUS.lua                                              MOD
spec/sort_spec.lua, listrows_spec.lua, helpers/format51.lua (T1), bagswindow_list_spec.lua (T2), theme_spec.lua (T4),
spec/altdata_spec.lua (T6), syndicator_spec.lua (T7), tooltip_spec.lua (T8), offline_spec.lua (T9)  NEW
spec/mock_adapter.lua, helpers/loader.lua (T1), bagswindow_sections_spec.lua, searchbox_spec.lua, settings_spec.lua (T2, T3),
spec/helpers/uienv.lua (T3)                                                                       MOD
```

## Schedule (week 5)

The user tests a few evenings per week. Each feature lands as a block with its own session, the bag view first because it is used every minute.

| Day | Tasks | User in game? |
|---|---|---|
| 1 | 1, 2, 3 | **yes:** session L1 (the list view, about 15 minutes, includes one combat item use) |
| 2 | 4, 5 | **yes:** session TH1 (looks, about 8 minutes) |
| 3 | 6, 7, 8 | **yes:** session A1 (tooltip counts and the Syndicator source, about 6 minutes) |
| 4 | 9, 10 | **yes:** session OF1 (the alt viewer, about 8 minutes); **Week 5 exit check** |

Cumulative `scripts/check.sh` test totals (from 992 on `d759564`). Each was produced by replaying this file's blocks in order on a fresh clone of `d759564`:
- T1 1014 passed, 0 failed (+22)
- T2 1028 passed, 0 failed (+14)
- T3 1038 passed, 0 failed (+10)
- T4 1051 passed, 0 failed (+13)
- T5 1058 passed, 0 failed (+7)
- T6 1071 passed, 0 failed (+13)
- T7 1083 passed, 0 failed (+12)
- T8 1095 passed, 0 failed (+12)
- T9 1110 passed, 0 failed (+15)
- T10 1115 passed, 0 failed (+5)

## How the TOC grows

`scripts/check.sh` prints `TOC OK (N files)`: 53 on `d759564`, then 55 after Tasks 1–3, 57 after Tasks 4–5, 58 after Task 6, 59 after Task 7, 60 after Task 8 and 62 after Tasks 9–10. The final order of the changed parts:

```text
Engine/Snapshots.lua
Engine/AltData.lua
Engine/Prices.lua
Engine/OverlayData.lua
Engine/Sort.lua
Engine/Focus.lua
...
# Providers
Providers/Auctionator.lua
Providers/Syndicator.lua

# UI
UI/Theme.lua
UI/ReportBox.lua
UI/Buttons.lua
UI/SectionHeaders.lua
UI/ListRows.lua
UI/BagsWindow.lua
...
UI/GuildBankWindow.lua
UI/DisplayButtons.lua
UI/OfflineWindow.lua
UI/Overlays.lua
...
UI/Footer.lua
UI/Themes.lua
UI/TooltipCounts.lua
UI/QuickSetup.lua
UI/DebugV1.lua
```

## How to read the code steps

- A **Create** step gives a complete new file.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point and its replacement. The block occurs exactly once, and has at least one line a reader can recognise. When a file has several edits in one task, they are numbered "(edit N of M)"; apply them in that order, top to bottom. Each find block is unique in the file as it is after the previous edits.
- No step replaces a whole existing file. Blocks begin and end on non-blank lines.
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks. Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists its critical tests and, for each, the code change (mutation) that must make it fail. Every mutation was applied to the finished code of its task and the named test failed. A reviewer re-runs any of them with a one-line edit.
- An edit block may start or end in the middle of a function (the diff of the finished file): the text in the block is what matters, not where it sits.

---
### Task 1: The display order and the list rows (`Engine/Sort.lua`, `UI/ListRows.lua`), v0.5.0

Spec §3.2 `Sort` ("display order as data") and the text half of the v1.3 list view. `Engine/Sort.lua` is pure Lua. It holds the four columns, the saved order (`bags.list.sort`, `bags.list.desc`, D6), what a column click does (`Sort.Next`), and the item level and stack value a row shows (D7: bound and WuE items at vendor price). `Sort.DisplayOrder` sorts filled slots by a column and keeps the empty ones after them in physical order. `UI/ListRows.lua` makes one plain row frame per slot button, with four font strings, a background texture for themes and a tooltip that points at the icon (P2). Nothing uses either yet; Task 2 draws them. The version goes to 0.5.0.

The tests also get the guard the user asked for: `spec/helpers/format51.lua`, required once by the loader, makes `string.format`'s `%s` as strict as WoW's Lua 5.1 in every spec (a boolean or nil is an error), as `consumables_spec` already did for itself (W4-18).

**Files:**
- Create: `SwagBag/Engine/Sort.lua`, `SwagBag/UI/ListRows.lua`, `spec/sort_spec.lua`, `spec/listrows_spec.lua`, `spec/helpers/format51.lua`
- Modify: `SwagBag/Core/Adapter.lua` (`SlotTooltip`), `SwagBag/Core/Config.lua` (`bags.list`), `SwagBag/Core/Init.lua` and `SwagBag/SwagBag.toc` (0.5.0, two files), `SwagBag/Locale/enUS.lua`, `spec/mock_adapter.lua`, `spec/helpers/loader.lua`

**Interfaces:**
- Consumes: `SB.Config.Get/Set`, `SB.Prices.Value(link, itemID, bound)`, `SB.Prices.Money`, `SB.OverlayData.SLOTS`, `SB.Buttons.DIM_ALPHA/PLACEHOLDER_ALPHA`, `SB.ErrorTrap.Guard`.
- Produces:
  - `SB.Sort.COLUMNS = { "name", "count", "ilvl", "value" }`, `Sort.Spec() -> { by, desc }`, `Sort.Save(by, desc) -> bool`, `Sort.Next(spec, by) -> spec`, `Sort.Ilvl(record) -> n|nil`, `Sort.Value(record) -> copper|nil`;
  - `Sort.DisplayOrder(slots, spec, valueOf) -> list` (slots `{ { bag, slot, record } }`);
  - `SB.ListRows.New(parent, window) -> rows` with `rows.Place(button, x, y, width, height, shown)`, `rows.Paint(button, bag, slot, record, freeCount)`, `rows.Ghosts(list, width, height)`, `rows.HideAll()`, `rows.SetDimmed(button, dimmed)`, `rows.IsMouseOver(button)`, `rows.rows[button]` (each row frame has `.bg`, `.name`, `.count`, `.ilvl`, `.value`) and `rows.ghosts`;
  - `ListRows.Columns(width)`, `ListRows.Texts(record, freeCount)`;
  - `SB.Adapter.SlotTooltip(owner, bag, slot, hint)` (mock: `m.slotTip`);
  - settings `bags.list = { sort = "value", desc = true }`;
  - for every later spec: `spec/helpers/format51.lua` (strict `%s`), required by `spec/helpers/loader.lua`.

- [ ] **Step 1: Write the failing tests**

Create `spec/helpers/format51.lua`:

```lua
-- luacheck: ignore 122
-- WoW runs Lua 5.1, whose string.format takes only a string or a number for %s. LuaJIT, which runs
-- these tests, also takes a boolean or nil and would hide that bug (ruling W4-18). spec/helpers/loader.lua
-- requires this once per run (require caches it), so every spec formats as strictly as WoW does.
-- Returns the real string.format.
local real = string.format
string.format = function(fmt, ...)
	local args, i = { ... }, 0
	for spec in fmt:gmatch("%%[%-%d%.]*(%a)") do
		i = i + 1
		if spec == "s" and type(args[i]) ~= "string" and type(args[i]) ~= "number" then
			error("bad argument #" .. (i + 1) .. " to 'format' (string expected, got " .. type(args[i]) .. ")", 2)
		end
	end
	return real(fmt, ...)
end
return real
```

In `spec/helpers/loader.lua`, find:

```lua
local Mock = dofile("spec/mock_adapter.lua")
```

and replace it with:

```lua
local Mock = dofile("spec/mock_adapter.lua")
require("spec.helpers.format51") -- %s as strict as WoW's Lua 5.1, for every spec (week 5)
```

Create `spec/listrows_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The list view's rows (UI/ListRows.lua): texts per column, one plain row per slot button,
-- placed and hidden by the window, dimmed with its button, and a tooltip that points at the icon.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("ListRows", function()
	local SB, A, LR, rows, parent
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/Engine/Sort.lua")
		SB.Buttons = { DIM_ALPHA = 0.2, PLACEHOLDER_ALPHA = 0.5 }
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		LR = SB.ListRows
		parent = Fake.New("Frame", UIParent)
		rows = LR.New(parent, "bags")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function record(slot)
		return SB.Items.Describe(0, slot)
	end

	it("texts: name, count (blank for one), item level for gear only, value of the stack", function()
		A.items[Fixtures.HEALING_POTION].sellPrice = 200
		local t = LR.Texts(record(1))
		assert.same({ name = "Algari Healing Potion", count = "5", ilvl = "", value = "10s" }, t)
		local ring = LR.Texts(record(3))
		assert.equal("", ring.count)
		assert.equal("285", ring.ilvl)
	end)

	it("texts: the name takes its link's quality colour; a loading item shows its link's name", function()
		local r = { name = "Band", link = "|cffa335ee|Hitem:225001::|h[Band]|h|r", count = 1 }
		assert.equal("|cffa335eeBand|r", LR.Texts(r).name)
		assert.equal("|cffa335eeLate|r", LR.Texts({ link = "|cffa335ee|Hitem:1|h[Late]|h|r", pending = true }).name)
		assert.equal(SB.L.LIST_LOADING, LR.Texts({ count = 1, pending = true }).name)
	end)

	it("texts: an empty slot, and the free tile with its number", function()
		assert.equal(SB.L.LIST_EMPTY, LR.Texts(nil).name)
		assert.equal(SB.L.LIST_FREE:format(10), LR.Texts(nil, 10).name)
	end)

	it("columns fill the row: name on the left, count, item level and value on the right", function()
		local c = LR.Columns(440)
		assert.equal(0, c.name.x)
		assert.equal(440, c.value.x + c.value.width)
		assert.truthy(c.count.x > c.name.width)
	end)

	-- Mutation: in R.Place, create a new row on every call instead of reusing R.rows[button].
	it("one row per slot button, made on first use, placed where the window says and hidden when not shown", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		local row = rows.rows[button]
		assert.truthy(row.shown)
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 32, -40 }, row.points[1])
		assert.equal("Algari Healing Potion", row.name.text)
		local n = #Fake.created
		rows.Place(button, 32, -66, 400, 24, true)
		assert.equal(n, #Fake.created, "no new frame for a row that exists")
		rows.Place(button, 32, -66, 400, 24, false)
		assert.falsy(row.shown)
	end)

	-- AC5.1 in the list view. Mutation: in R.Place, always SetAlpha(1).
	it("a dimmed row stays dimmed when it is placed again; undimming restores it", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		rows.SetDimmed(button, true)
		assert.equal(0.2, rows.rows[button].alpha)
		rows.Place(button, 32, -66, 400, 24, true)
		assert.equal(0.2, rows.rows[button].alpha)
		rows.SetDimmed(button, false)
		assert.equal(1, rows.rows[button].alpha)
	end)

	it("IsMouseOver is true only for a shown row under the mouse", function()
		local button = Fake.New("ItemButton", parent)
		assert.falsy(rows.IsMouseOver(button))
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		rows.rows[button].mouseOver = true
		assert.truthy(rows.IsMouseOver(button))
		rows.Place(button, 32, -40, 400, 24, false)
		assert.falsy(rows.IsMouseOver(button))
	end)

	it("ghost rows for placeholders are pooled, and the extra ones hide; HideAll hides every row", function()
		rows.Ghosts({ { x = 32, y = -40 }, { x = 32, y = -66 } }, 400, 24)
		assert.equal(2, #rows.ghosts)
		assert.equal(SB.L.LIST_GONE, rows.ghosts[1].name.text)
		rows.Ghosts({ { x = 32, y = -40 } }, 400, 24)
		assert.truthy(rows.ghosts[1].shown)
		assert.falsy(rows.ghosts[2].shown)
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		rows.HideAll()
		assert.falsy(rows.rows[button].shown)
		assert.falsy(rows.ghosts[1].shown)
	end)

	-- P2: hovering a row answers. Mutation: in itemTip, drop the hint argument.
	it("hovering a row shows the item's tooltip with a line pointing at the icon; an empty row says what it is", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		Fake.Fire(rows.rows[button], "OnEnter")
		assert.same({ owner = rows.rows[button], bag = 0, slot = 1, hint = SB.L.LIST_ROW_TIP }, A.slotTip)
		local empty = Fake.New("ItemButton", parent)
		rows.Paint(empty, 0, 9, nil)
		rows.Place(empty, 32, -66, 400, 24, true)
		Fake.Fire(rows.rows[empty], "OnEnter")
		assert.equal(SB.L.LIST_EMPTY_TIP, GameTooltip.text)
	end)

	it("an error in a row's tooltip is trapped as the window's (never a Lua error)", function()
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		A.SlotTooltip = function() error("tooltip broke") end
		Fake.Fire(rows.rows[button], "OnEnter")
		assert.equal("list.rowTip", SB.ErrorTrap.Recent()[1].label)
		assert.equal("bags", SB.ErrorTrap.Recent()[1].window)
	end)

	it("creates only plain frames (never an item or secure button), also in combat", function()
		A.combat = true
		local button = Fake.New("ItemButton", parent)
		rows.Paint(button, 0, 1, record(1))
		rows.Place(button, 32, -40, 400, 24, true)
		rows.Ghosts({ { x = 32, y = -66 } }, 400, 24)
		for _, f in ipairs(Fake.created) do
			assert.equal("Frame", f.kind)
		end
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
	function m.HideTooltip()
		m.tooltip = nil
	end
```

and replace it with:

```lua
	function m.HideTooltip()
		m.tooltip = nil
	end

	-- The list view's row tooltips: m.slotTip = { owner, bag, slot, hint }.
	function m.SlotTooltip(owner, bag, slot, hint)
		m.slotTip = { owner = owner, bag = bag, slot = slot, hint = hint }
	end
```

Create `spec/sort_spec.lua`:

```lua
-- The list view's display order (Engine/Sort.lua): pure sorting by name, count, item level or
-- value, items without the value last, ties by name then physical order, empty slots after.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Prices.lua",
	"SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/OverlayData.lua", "SwagBag/Engine/Sort.lua",
}

-- The guard the user asked for in week 5: WoW's Lua 5.1 refuses a boolean or nil for %s, so every
-- spec does too (spec/helpers/format51.lua, required by the loader). Mutation: drop the require.
describe("Test format (spec/helpers/format51.lua)", function()
	it("formats %s as strictly as WoW's Lua 5.1: a boolean or nil is an error, strings and numbers are fine", function()
		Loader.New()
		assert.has_error(function() return ("%s"):format(true) end, "string expected, got boolean")
		assert.has_error(function() return ("%d %s"):format(1, nil) end, "string expected, got nil")
		assert.equal("a 1 2.5", ("%s %s %.1f"):format("a", 1, 2.5))
		assert.equal("100%", ("%d%%"):format(100))
	end)
end)

describe("Sort", function()
	local SB, A, S
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		S = SB.Sort
	end)

	local function slot(n, record)
		return { bag = 0, slot = n, record = record }
	end

	local function rec(name, count, extra)
		local r = extra or {}
		r.name, r.count = name, count
		return r
	end

	local function names(list)
		local out = {}
		for i, s in ipairs(list) do
			out[i] = s.record and s.record.name or ("empty " .. s.slot)
		end
		return out
	end

	local function value(r)
		return r.v
	end

	-- Mutation: compare a.key < b.key for both directions.
	it("by name, A to Z or Z to A; empty slots after, in physical order", function()
		local slots = { slot(1, rec("Bismuth", 5)), slot(2, nil), slot(3, rec("Algari Healing Potion", 2)),
			slot(4, nil), slot(5, rec("Mycobloom", 20)) }
		assert.same({ "Algari Healing Potion", "Bismuth", "Mycobloom", "empty 2", "empty 4" },
			names(S.DisplayOrder(slots, { by = "name", desc = false }, value)))
		assert.same({ "Mycobloom", "Bismuth", "Algari Healing Potion", "empty 2", "empty 4" },
			names(S.DisplayOrder(slots, { by = "name", desc = true }, value)))
	end)

	it("by count, highest first", function()
		local slots = { slot(1, rec("A", 5)), slot(2, rec("B", 20)), slot(3, rec("C", 1)) }
		assert.same({ "B", "A", "C" }, names(S.DisplayOrder(slots, { by = "count", desc = true }, value)))
	end)

	-- Mutation: in the comparator, drop the "a.key == nil -> false" branch.
	it("an item without the value goes last in both directions (a potion's item level, an unpriced item)", function()
		local helm = rec("Helm", 1, { equipLoc = "INVTYPE_HEAD", ilvl = 270 })
		local ring = rec("Ring", 1, { equipLoc = "INVTYPE_FINGER", ilvl = 285 })
		local potion = rec("Potion", 5, { ilvl = 300 })
		local slots = { slot(1, potion), slot(2, helm), slot(3, ring) }
		assert.same({ "Ring", "Helm", "Potion" }, names(S.DisplayOrder(slots, { by = "ilvl", desc = true }, value)))
		assert.same({ "Helm", "Ring", "Potion" }, names(S.DisplayOrder(slots, { by = "ilvl", desc = false }, value)))
		local priced = { slot(1, rec("Unpriced", 1)), slot(2, rec("Cheap", 1, { v = 10 })), slot(3, rec("Dear", 1, { v = 90 })) }
		assert.same({ "Cheap", "Dear", "Unpriced" }, names(S.DisplayOrder(priced, { by = "value", desc = false }, value)))
	end)

	-- Mutation: drop the name tie-break (equal keys keep their input order).
	it("ties are broken by name, then by physical order, so the order never depends on the input table", function()
		local a1, a2 = rec("Same", 1, { v = 5 }), rec("Same", 1, { v = 5 })
		local slots = { slot(1, rec("Zed", 1, { v = 5 })), slot(2, a1), slot(3, a2) }
		local out = S.DisplayOrder(slots, { by = "value", desc = true }, value)
		assert.same({ "Same", "Same", "Zed" }, names(out))
		assert.equal(2, out[1].slot)
		assert.equal(3, out[2].slot)
	end)

	it("an item still loading sorts by the name in its link, else last", function()
		local loading = { link = "|cff0070dd|Hitem:1|h[Aaa Loading]|h|r", count = 1, pending = true }
		local slots = { slot(1, rec("Bbb", 1)), slot(2, loading), slot(3, { count = 1, pending = true }) }
		local out = S.DisplayOrder(slots, { by = "name", desc = false }, value)
		assert.equal(2, out[1].slot)
		assert.equal(1, out[2].slot)
		assert.equal(3, out[3].slot)
	end)

	it("Sort.Next: the same column flips; another column starts at its natural direction", function()
		assert.same({ by = "value", desc = false }, S.Next({ by = "value", desc = true }, "value"))
		assert.same({ by = "name", desc = false }, S.Next({ by = "value", desc = true }, "name"))
		assert.same({ by = "count", desc = true }, S.Next({ by = "name", desc = false }, "count"))
		assert.same({ by = "ilvl", desc = true }, S.Next(nil, "ilvl"))
	end)

	it("Sort.Spec: value, highest first, by default; a damaged saved column falls back to value", function()
		assert.same({ by = "value", desc = true }, S.Spec())
		SB.Config.Set("bags.list.sort", "weight")
		assert.same({ by = "value", desc = true }, S.Spec())
		assert.truthy(S.Save("name", false))
		assert.same({ by = "name", desc = false }, S.Spec())
	end)

	-- Mutation: in Sort.Save, return true whatever Config.Set answered.
	it("Sort.Save refuses an unknown column and read-only settings, and writes nothing", function()
		assert.falsy(S.Save("weight", true))
		SB.Config.readOnly = true
		assert.falsy(S.Save("name", false))
		SB.Config.readOnly = false
		assert.same({ by = "value", desc = true }, S.Spec())
	end)

	it("Sort.Ilvl: equippable gear only", function()
		assert.equal(285, S.Ilvl({ equipLoc = "INVTYPE_FINGER", ilvl = 285 }))
		assert.is_nil(S.Ilvl({ equipLoc = "", ilvl = 300 }))
		assert.is_nil(S.Ilvl(nil))
	end)

	-- D11 / W3-35. Mutation: in Sort.Value, pass false instead of isBound or isWUE.
	it("Sort.Value: the stack's value; a bound or warbound-until-equipped item at its vendor price", function()
		A.items[Fixtures.BOE_RING].sellPrice = 1000
		A.auctionator = { prices = { ["item:225001"] = 500000 } }
		local ring = { itemID = Fixtures.BOE_RING, link = "item:225001", count = 2 }
		assert.equal(1000000, S.Value(ring))
		SB.Prices.Invalidate()
		ring.isBound = true
		assert.equal(2000, S.Value(ring))
		ring.isBound, ring.isWUE = false, true
		assert.equal(2000, S.Value(ring))
		assert.is_nil(S.Value({ itemID = Fixtures.BOE_RING, link = "item:225001", count = 1, pending = true }))
		assert.is_nil(S.Value(nil))
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `993 passed, 21 failed`. The 21 are every test in `spec/sort_spec.lua` and `spec/listrows_spec.lua` but one, each with `cannot open SwagBag/Engine/Sort.lua: No such file or directory`. The 22nd new test, "formats %s as strictly as WoW's Lua 5.1…", passes already: it checks the test helper itself.

Critical tests and their mutations (each makes the named test fail):

| Test | Mutation |
|---|---|
| sort_spec "formats %s as strictly as WoW's Lua 5.1: …" (run with `consumables_spec` first, as the full suite does) | in `spec/helpers/loader.lua`, delete the `require("spec.helpers.format51")` line |
| sort_spec "by name, A to Z or Z to A; …" | in `Sort.DisplayOrder`'s comparator, delete the `if spec.desc then return a.key > b.key end` branch |
| sort_spec "an item without the value goes last in both directions …" | replace `if a.key == nil then return false elseif b.key == nil then` with `if b.key == nil then` |
| sort_spec "ties are broken by name, then by physical order, …" | delete the `if a.name ~= b.name then return a.name < b.name end` tie-break |
| sort_spec "Sort.Save refuses an unknown column and read-only settings, …" | in `Sort.Save`, call both `Config.Set`s and `return true` |
| sort_spec "Sort.Value: the stack's value; a bound or warbound-until-equipped item at its vendor price" | pass `false` instead of `record.isBound or record.isWUE` to `Prices.Value` |
| listrows_spec "one row per slot button, made on first use, …" | in `rowFor`, create a row on every call |
| listrows_spec "a dimmed row stays dimmed when it is placed again; …" | in `R.Place`, `row:SetAlpha(1)` |
| listrows_spec "hovering a row shows the item's tooltip with a line pointing at the icon; …" | drop the `L.LIST_ROW_TIP` argument to `SlotTooltip` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Adapter.lua`, find:

```lua
-- Shift/Ctrl-click on an item link (chat link, dressing room). True when Blizzard handled it.
```

and replace it with:

```lua
-- A bag or bank slot's item tooltip (the list view's rows), with an optional white hint line.
function A.SlotTooltip(owner, bag, slot, hint)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetBagItem, GameTooltip, bag, slot)
	if hint then
		GameTooltip:AddLine(hint, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- Shift/Ctrl-click on an item link (chat link, dressing room). True when Blizzard handled it.
```

In `SwagBag/Core/Config.lua`, find:

```lua
			-- footer.entries: the bar under the items (UI/Footer.lua, W4-14), left to right; "-" before
```

and replace it with:

```lua
			-- list: the list view's order (Engine/Sort.lua; the bags window's third view). sort: "value" |
			-- "name" | "count" | "ilvl"; desc: highest first (Z to A for names). Default: worth most first.
			list = { sort = "value", desc = true },
			-- footer.entries: the bar under the items (UI/Footer.lua, W4-14), left to right; "-" before
```

In `SwagBag/Core/Init.lua`, find:

```lua
SB.VERSION = "0.4.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "
```

and replace it with:

```lua
SB.VERSION = "0.5.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "
```

Create `SwagBag/Engine/Sort.lua`:

```lua
-- SwagBag display order (spec 3.2 "Sort": display order as data). Pure Lua. The list view
-- (UI/BagsWindow.lua) sorts the slots it lays out with it before Engine/Layout.lua groups them
-- into sections, so every section lists its items in this order. The physical sort stays
-- Blizzard's own (the Sort button, Adapter.SortBags).
--   Sort.COLUMNS                     { "name", "count", "ilvl", "value" }: the list view's columns
--   Sort.Spec() -> { by, desc }      the saved order (bags.list.sort, bags.list.desc), checked
--   Sort.Save(by, desc) -> ok        false (nothing written) while the settings are read-only
--   Sort.Next(spec, by) -> spec      a click on a column: the same column flips the direction;
--                                    another column starts at its natural one (names A to Z,
--                                    numbers highest first)
--   Sort.Ilvl(record) -> n | nil     the item level the list shows: equippable gear only (as the overlay)
--   Sort.Value(record) -> copper | nil   the stack's value: Prices per unit x count. A bound or
--                                    warbound-until-equipped item is worth its vendor price (D11, W3-35)
--   Sort.DisplayOrder(slots, spec, valueOf) -> list
--       slots: { { bag, slot, record } } in physical order (record nil = an empty slot). The filled
--       slots come first, sorted by spec.by; an item with no value for that column (a potion's item
--       level, an unpriced item) goes last whatever the direction; ties by name, then physical
--       order, so the result never depends on the input's table order. The empty slots follow in
--       physical order (the free tile is the first empty slot, as in every view).
local _, SB = ...

local Sort = { COLUMNS = { "name", "count", "ilvl", "value" } }
SB.Sort = Sort

local KNOWN = { name = true, count = true, ilvl = true, value = true }

function Sort.Spec()
	local by = SB.Config.Get("bags.list.sort")
	if not KNOWN[by] then
		by = "value"
	end
	return { by = by, desc = SB.Config.Get("bags.list.desc") == true }
end

function Sort.Save(by, desc)
	if not KNOWN[by] then
		return false
	end
	return SB.Config.Set("bags.list.sort", by) and SB.Config.Set("bags.list.desc", desc == true)
end

function Sort.Next(spec, by)
	if spec and spec.by == by then
		return { by = by, desc = not spec.desc }
	end
	return { by = by, desc = by ~= "name" }
end

function Sort.Ilvl(record)
	local O = SB.OverlayData
	if record and O and O.SLOTS[record.equipLoc or ""] and type(record.ilvl) == "number" then
		return record.ilvl
	end
	return nil
end

function Sort.Value(record)
	if not record or record.pending or not SB.Prices then
		return nil
	end
	local v = SB.Prices.Value(record.link, record.itemID, record.isBound or record.isWUE)
	if type(v) ~= "number" then
		return nil
	end
	return v * (record.count or 1)
end

local function nameOf(record)
	local name = record.name
	if type(name) ~= "string" and type(record.link) == "string" then
		name = record.link:match("%[(.-)%]")
	end
	return type(name) == "string" and name:lower() or nil
end

local function keyOf(record, by, valueOf)
	if by == "name" then
		return nameOf(record)
	elseif by == "count" then
		return record.count or 1
	elseif by == "ilvl" then
		return Sort.Ilvl(record)
	end
	return valueOf(record)
end

function Sort.DisplayOrder(slots, spec, valueOf)
	spec = spec or { by = "value", desc = true }
	valueOf = valueOf or Sort.Value
	local filled, empty = {}, {}
	for i, s in ipairs(slots) do
		if s.record then
			filled[#filled + 1] = { s = s, i = i, key = keyOf(s.record, spec.by, valueOf), name = nameOf(s.record) or "" }
		else
			empty[#empty + 1] = s
		end
	end
	table.sort(filled, function(a, b)
		if a.key ~= b.key then
			if a.key == nil then
				return false
			elseif b.key == nil then
				return true
			end
			if spec.desc then
				return a.key > b.key
			end
			return a.key < b.key
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.i < b.i
	end)
	local out = {}
	for _, f in ipairs(filled) do
		out[#out + 1] = f.s
	end
	for _, s in ipairs(empty) do
		out[#out + 1] = s
	end
	return out
end
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

and replace it with:

```lua
-- The list view (week 5): rows of name, count, item level and value
L.LIST_LOADING = "Loading..."
L.LIST_EMPTY = "Empty slot"
L.LIST_FREE = "%d free - drop items here"
L.LIST_GONE = "(moved or used - regroups when you close the bag)"
L.LIST_ROW_TIP = "Click the icon on the left to use, sell or move this item."
L.LIST_EMPTY_TIP = "An empty bag slot: drop an item on the icon on the left."

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

In `SwagBag/SwagBag.toc`, find (edit 1 of 3):

```text
## Version: 0.4.0
## SavedVariables: SwagBagDB
```

and replace it with:

```text
## Version: 0.5.0
## SavedVariables: SwagBagDB
```

In `SwagBag/SwagBag.toc`, find (edit 2 of 3):

```text
Engine/Focus.lua
Engine/FocusData.lua
Engine/Signals.lua
```

and replace it with:

```text
Engine/Sort.lua
Engine/Focus.lua
Engine/FocusData.lua
Engine/Signals.lua
```

In `SwagBag/SwagBag.toc`, find (edit 3 of 3):

```text
UI/BagsWindow.lua
UI/SafeModeHooks.lua
UI/SearchBox.lua
```

and replace it with:

```text
UI/ListRows.lua
UI/BagsWindow.lua
UI/SafeModeHooks.lua
UI/SearchBox.lua
```

Create `SwagBag/UI/ListRows.lua`:

```lua
-- SwagBag list rows (spec 2.2 v1.3, the list view): the text part of each row, in four columns
-- -- the name in its quality colour, the count, the item level and the stack's value. The item
-- part of a row is the slot's own button (UI/Buttons.lua), which the window places at the row's
-- left edge: every click on the icon is Blizzard's own item click (use, sell, deposit, split,
-- drag), and a row itself takes no click. Hovering a row shows the item's tooltip and a line
-- that says to click the icon (P2). Plain frames and font strings only, made the first time a
-- row is needed (allowed in combat, like the footer, ruling W4-24); one set of rows per window.
--   ListRows.New(parent, window) -> rows       window: the ErrorTrap window of the rows' scripts
--   rows.Place(button, x, y, width, height, shown)  the row of a slot button (made on first use)
--   rows.Paint(button, bag, slot, record, freeCount)  record nil: an empty slot ("Empty slot"),
--                                              or the free tile when freeCount is a number
--   rows.Ghosts(list, width, height)           rows for placeholders: { { x, y } }, drawn whole
--   rows.HideAll()                             another view, or a full layout starting
--   rows.SetDimmed(button, dimmed)             search: a row dims with its button (AC5.1)
--   rows.IsMouseOver(button) -> bool           P5: a row under the mouse holds its button
--   ListRows.Columns(width) -> { name, count, ilvl, value } = { x, width }   pure
--   ListRows.Texts(record, freeCount) -> { name, count, ilvl, value }         pure
local _, SB = ...

local L = SB.L
local LR = { COUNT = 36, ILVL = 36, VALUE = 86, GAP = 6, FONT = "GameFontHighlightSmall" }
SB.ListRows = LR

function LR.Columns(width)
	local nameW = math.max(40, width - LR.COUNT - LR.ILVL - LR.VALUE - 3 * LR.GAP)
	local x = nameW + LR.GAP
	local out = { name = { x = 0, width = nameW }, count = { x = x, width = LR.COUNT } }
	x = x + LR.COUNT + LR.GAP
	out.ilvl = { x = x, width = LR.ILVL }
	out.value = { x = x + LR.ILVL + LR.GAP, width = LR.VALUE }
	return out
end

-- The name in the colour of its link ("|cffa335ee|Hitem:...|h[Name]|h|r"), else plain.
local function coloured(record)
	local name = record.name
	if type(name) ~= "string" and type(record.link) == "string" then
		name = record.link:match("%[(.-)%]")
	end
	if type(name) ~= "string" then
		return L.LIST_LOADING
	end
	local colour = type(record.link) == "string" and record.link:match("|c(%x%x%x%x%x%x%x%x)")
	if colour then
		return "|c" .. colour .. name .. "|r"
	end
	return name
end

function LR.Texts(record, freeCount)
	if not record then
		local name = type(freeCount) == "number" and L.LIST_FREE:format(freeCount) or L.LIST_EMPTY
		return { name = name, count = "", ilvl = "", value = "" }
	end
	local count = record.count or 1
	local ilvl = SB.Sort.Ilvl(record)
	local value = SB.Sort.Value(record)
	return {
		name = coloured(record),
		count = count > 1 and tostring(count) or "",
		ilvl = ilvl and tostring(math.floor(ilvl)) or "",
		value = (value and value > 0) and SB.Prices.Money(value) or "",
	}
end

local function hideTip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

function LR.New(parent, window)
	local Guard = SB.ErrorTrap.Guard
	local R = { rows = {}, ghosts = {}, used = 0 }
	-- [row] = { bag, slot, filled }; [button] = true while dimmed; [button] = its texts, kept until
	-- its row is first needed, so a hidden slot (a spare in Free) never gets a row
	local slotOf, dimmed, texts = {}, {}, {}

	local function text(row, justify)
		local fs = row:CreateFontString(nil, "OVERLAY", LR.FONT)
		fs:SetJustifyH(justify)
		fs:SetWordWrap(false)
		return fs
	end

	local function create(tip)
		local row = CreateFrame("Frame", nil, parent)
		row:EnableMouse(true)
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints(row)
		row.bg:Hide()
		row.name, row.count, row.ilvl, row.value = text(row, "LEFT"), text(row, "RIGHT"), text(row, "RIGHT"),
			text(row, "RIGHT")
		row:SetScript("OnEnter", Guard("list.rowTip", tip, window))
		row:SetScript("OnLeave", Guard("list.rowTipHide", hideTip, window))
		return row
	end

	local function itemTip(row)
		local s = slotOf[row]
		if s and s.filled then
			SB.Adapter.SlotTooltip(row, s.bag, s.slot, L.LIST_ROW_TIP)
		elseif GameTooltip then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.LIST_EMPTY_TIP, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end

	local function ghostTip(row)
		if GameTooltip then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.PLACEHOLDER_TIP, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end

	local function layoutTexts(row, width, height)
		local cols = LR.Columns(width)
		row:SetSize(width, height)
		for _, id in ipairs(SB.Sort.COLUMNS) do
			local fs = row[id]
			fs:ClearAllPoints()
			fs:SetPoint("LEFT", row, "LEFT", cols[id].x, 0)
			fs:SetWidth(cols[id].width)
		end
	end

	local function setTexts(row, t)
		row.name:SetText(t.name)
		row.count:SetText(t.count)
		row.ilvl:SetText(t.ilvl)
		row.value:SetText(t.value)
	end

	local function rowFor(button)
		local row = R.rows[button]
		if not row then
			row = create(itemTip)
			R.rows[button] = row
			local t = texts[button]
			if t then
				slotOf[row] = t.slot
				setTexts(row, t)
			end
		end
		return row
	end

	function R.Place(button, x, y, width, height, shown)
		local row = R.rows[button]
		if not shown or not x then
			if row then
				row:Hide()
			end
			return
		end
		row = rowFor(button)
		layoutTexts(row, width, height)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
		row:SetAlpha(dimmed[button] and SB.Buttons.DIM_ALPHA or 1)
		row:Show()
	end

	function R.Paint(button, bag, slot, record, freeCount)
		local t = LR.Texts(record, freeCount)
		t.slot = { bag = bag, slot = slot, filled = record ~= nil }
		texts[button] = t
		local row = R.rows[button]
		if row then
			slotOf[row] = t.slot
			setTexts(row, t)
		end
	end

	function R.Ghosts(list, width, height)
		for i, p in ipairs(list) do
			local row = R.ghosts[i]
			if not row then
				row = create(ghostTip)
				R.ghosts[i] = row
			end
			layoutTexts(row, width, height)
			setTexts(row, { name = L.LIST_GONE, count = "", ilvl = "", value = "" })
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", parent, "TOPLEFT", p.x, p.y)
			row:SetAlpha(SB.Buttons.PLACEHOLDER_ALPHA)
			row:Show()
		end
		for i = #list + 1, R.used do
			R.ghosts[i]:Hide()
		end
		R.used = #list
	end

	function R.HideAll()
		for _, row in pairs(R.rows) do
			row:Hide()
		end
		R.Ghosts({}, 0, 0)
	end

	function R.SetDimmed(button, dim)
		dimmed[button] = dim and true or nil
		local row = R.rows[button]
		if row then
			row:SetAlpha(dim and SB.Buttons.DIM_ALPHA or 1)
		end
	end

	function R.IsMouseOver(button)
		local row = R.rows[button]
		return row ~= nil and row:IsShown() and row:IsMouseOver() == true
	end

	return R
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/sort_spec.lua spec/listrows_spec.lua`
Expected: `22 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (55 files)`, `1014 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add "spec/sort_spec.lua" "spec/listrows_spec.lua" "spec/mock_adapter.lua" "spec/helpers/format51.lua" "spec/helpers/loader.lua" "SwagBag/Engine/Sort.lua" "SwagBag/UI/ListRows.lua" "SwagBag/Core/Adapter.lua" "SwagBag/Core/Config.lua" "SwagBag/Core/Init.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 1: display order (Engine/Sort.lua) and list rows (UI/ListRows.lua), v0.5.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 2: The list view in the bags window (D1–D5, D8)

The bags window gets its third view. `W.drawn` remembers the view the current layout was drawn in, so a re-stack or loot that lands while a view change still waits under the mouse is drawn in the old geometry. In the list view:
- `layoutSections` sorts the slots with `Sort.DisplayOrder` before `Layout.Build`, with one column and `LIST_NEW_ROWS` rows for New;
- `position()` lays the cells out one per row (`LIST_ROW` high, `LIST_WIDTH` wide);
- `setScale` draws each slot button at row size, and back at full size in the other views. `Buttons.Place` divides offsets by the button's scale (D4);
- `showAt` places each row beside its button, `overlay` and `paintTiles` paint its texts, and `renderExtras` draws placeholders at row size with a "moved or used" ghost row;
- `W.ButtonBusy` counts a hovered row as its button (D5), and the bags search dims rows through `W.SetDimmed`.

The view button cycles categories → list → grid (D8), `/swagbag view` sets one, and Settings > Bags > `Bag view` gets `List`. Focus modes collapse the same sections (D3). Three existing assertions change with the new cycle and the new choice (Step 1, edits in `bagswindow_sections_spec` and `settings_spec`), and the search box spec's stand-in window gets `SetDimmed`.

**Files:**
- Create: `spec/bagswindow_list_spec.lua`
- Modify: `SwagBag/UI/BagsWindow.lua`, `SwagBag/UI/Buttons.lua`, `SwagBag/UI/SearchBox.lua`, `SwagBag/UI/SettingsPages.lua`, `SwagBag/Locale/enUS.lua`, `spec/bagswindow_sections_spec.lua`, `spec/searchbox_spec.lua`, `spec/settings_spec.lua`

**Interfaces:**
- Consumes: Task 1's `SB.Sort.*` and `SB.ListRows.New`; `SB.Layout.Build/Position/Moves`; the window's locals named in the header.
- Produces:
  - `W.View() -> "sections" | "list" | "grid"`, `W.VIEWS`, `W.SetView(view) -> bool` (false while read-only or for an unknown view), `W.ToggleView()` (the cycle);
  - `W.drawn`, `W.rows` (the window's `ListRows` object, nil without `UI/ListRows.lua`), `W.SetDimmed(button, dimmed)`;
  - the constants `W.LIST_ROW` (24), `W.LIST_GAP` (2), `W.LIST_WIDTH` (480), `W.LIST_NEW_ROWS` (4) and `W.ROW_TEXT_GAP` (4);
  - `W.tiled[button]` now holds the tile entry `{ bag, slot, ... }` (was `true`);
  - `/swagbag view [sections|list|grid]`; `L.VIEW_TO_LIST`, `L.VIEW_LIST`, `L.HELP_VIEW`, `L.VIEW_USAGE`.

- [ ] **Step 1: Write the failing tests**

Create `spec/bagswindow_list_spec.lua`:

```lua
-- luacheck: globals UIParent UISpecialFrames IsControlKeyDown GameTooltip
-- The bags window's list view (spec 2.2 v1.3), end to end over the real engine with fake frames
-- and buttons: one row per slot, the slot's own button at the row's left edge, the same sections,
-- New, Free, placeholders, focus modes and hover guard as the category view.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/OverlayData.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/GridLayout.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua", "SwagBag/Engine/CategoryDefaults.lua",
	"SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/Sort.lua",
	"SwagBag/Engine/Focus.lua",
}

-- Fake frame: shown state, scripts (Hide fires OnHide like the client), points, text, scale, mouse-over.
local function newFake(kind)
	local f = { kind = kind, shown = false, scale = 1, alpha = 1, vscroll = 0, w = 0, h = 0, scripts = {}, points = {},
		calls = {} }
	local methods = {
		IsShown = function(self) return self.shown end,
		Show = function(self) self.shown = true end,
		Hide = function(self)
			local was = self.shown
			self.shown = false
			if was and self.scripts.OnHide then
				self.scripts.OnHide(self)
			end
		end,
		IsMouseOver = function(self) return self.mouseOver == true end,
		SetScale = function(self, s) self.scale = s end,
		GetScale = function(self) return self.scale end,
		SetAlpha = function(self, a) self.alpha = a end,
		SetSize = function(self, w, h) self.w, self.h = w, h end,
		GetHeight = function(self) return self.h end,
		SetScript = function(self, n, fn) self.scripts[n] = fn end,
		SetVerticalScroll = function(self, v) self.vscroll = v end,
		GetVerticalScroll = function(self) return self.vscroll end,
		ClearAllPoints = function(self) self.points = {} end,
		SetPoint = function(self, ...)
			self.points[#self.points + 1] = { ... }
			local p = { ... }
			if p[3] == "BOTTOMLEFT" and (p[1] == "TOPLEFT" or p[1] == "BOTTOMLEFT") then
				self.anchor, self.left, self.edgeY = p[1], p[4], p[5]
			end
		end,
		GetLeft = function(self) return self.left end,
		GetTop = function(self)
			if self.anchor == "BOTTOMLEFT" then
				return self.edgeY + self.h
			end
			return self.edgeY
		end,
		SetText = function(self, s) self.text = s end,
		CreateFontString = function() return newFake("FontString") end,
		CreateTexture = function() return newFake("Texture") end,
	}
	return setmetatable(f, {
		__index = function(_, name)
			return methods[name] or function(self, ...) self.calls[name] = { ... } end
		end,
	})
end

-- Fake button pool: records placement (in the parent's units, as Buttons.Place promises), paint,
-- scale and dimming; placeholders as plain tables.
local function fakeButtons()
	local B = { created = true, buttons = {}, placeholders = {}, DIM_ALPHA = 0.2, PLACEHOLDER_ALPHA = 0.5 }
	function B.EnsureCapacity(bag, n)
		B.buttons[bag] = B.buttons[bag] or {}
		for slot = #B.buttons[bag] + 1, n do
			local b = newFake("ItemButton")
			b.bag, b.slot, b.placed = bag, slot, 0
			B.buttons[bag][slot] = b
		end
	end
	function B.Count(bag) return #(B.buttons[bag] or {}) end
	function B.Get(bag, slot) return B.buttons[bag] and B.buttons[bag][slot] end
	function B.Place(button, x, y)
		button.x, button.y = x, y
		button.placed = button.placed + 1
	end
	function B.Paint(button, info)
		button.itemID = info and info.itemID or nil
		if info then
			button.freeCount = nil
		end
	end
	function B.SetFreeCount(button, n) button.freeCount = n end
	function B.KindOf(bag) return bag <= 5 and "bags" or "bank" end
	function B.SetParentFor() end
	function B.SetDimmed(button, d) button.dimmed = d end
	function B.AcquirePlaceholder(_, icon, size, x, y)
		local p = { icon = icon, size = size, x = x, y = y }
		B.placeholders[#B.placeholders + 1] = p
		return p
	end
	function B.ReleasePlaceholders()
		B.placeholders = {}
	end
	return B
end

describe("BagsWindow list view", function()
	local SB, A, W, B
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- backpack 16 slots: potion x5, flask x2, BoE ring, soulbound helm, keystone, junk x3
		A.items[Fixtures.HEALING_POTION].sellPrice = 100 -- the stack of 5: 500
		A.items[Fixtures.FLASK].sellPrice = 1000 -- the stack of 2: 2000
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		GameTooltip = newFake("GameTooltip")
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SearchBox.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
		SB.Config.Set("bags.view", "list")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown, GameTooltip = nil, nil, nil, nil
	end)

	local function headers()
		local out = {}
		for i, h in ipairs(SB.SectionHeaders.inUse) do
			out[i] = h.text.text
		end
		return out
	end

	local function header(id)
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId == id then
				return h
			end
		end
	end

	local function row(slot)
		return W.rows.rows[B.Get(0, slot)]
	end

	-- Change the mock bags, then deliver the events the client would send.
	local function bagUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag or 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function rowY(slot)
		return row(slot).points[1][5]
	end

	it("one row per slot: the same sections, the slot's button at the row's left edge, at row size", function()
		assert.truthy(W.Open())
		assert.same({ "- Keystone & Crests (1)", "- Consumables (2) - 25s vendor", "- Gear (1)", "- BoE gear (1)",
			"- Junk (1)", "- Free (10)" }, headers())
		local potion, flask = B.Get(0, 1), B.Get(0, 2)
		assert.equal(W.PAD, potion.x, "every button sits at the left edge")
		assert.equal(W.PAD, flask.x)
		assert.equal(W.LIST_ROW / W.SLOT, potion.scale, "drawn at the row's height")
		assert.equal(W.LIST_ROW + W.LIST_GAP, math.abs(potion.y - flask.y), "one row apart")
		assert.equal(potion.y, rowY(1), "the row's texts sit beside the button")
		assert.equal(W.PAD + W.LIST_ROW + W.ROW_TEXT_GAP, row(1).points[1][4])
		assert.equal(W.LIST_WIDTH, W.child.w, "the list is LIST_WIDTH wide")
		assert.equal("Algari Healing Potion", row(1).name.text)
		assert.equal("5", row(1).count.text)
		assert.equal("285", row(3).ilvl.text, "item level for gear")
		assert.equal("", row(1).ilvl.text, "none for a potion")
	end)

	-- Mutation: in layoutSections, drop the SB.Sort.DisplayOrder call.
	it("each section lists its items in the saved order: value, highest first, by default", function()
		W.Open()
		assert.truthy(B.Get(0, 2).y > B.Get(0, 1).y, "flask (2000) above potion (500)")
		assert.equal("20s", row(2).value.text)
		SB.Sort.Save("name", false)
		W.Close()
		W.Open()
		assert.truthy(B.Get(0, 1).y > B.Get(0, 2).y, "Algari Healing Potion above Flask of Alchemical Chaos")
	end)

	it("the free tile's row says how many slots are free; spares have no row", function()
		W.Open()
		local tile = B.Get(0, 7)
		assert.equal(10, tile.freeCount)
		assert.equal(SB.L.LIST_FREE:format(10), W.rows.rows[tile].name.text)
		assert.falsy(B.Get(0, 8).shown)
		assert.is_nil(W.rows.rows[B.Get(0, 8)], "a hidden spare never got a row")
	end)

	-- Mutation: in setScale, never call SetScale (the buttons stay at row size in the grid).
	it("switching to the grid or the categories draws the buttons at full size again and hides the rows", function()
		W.Open()
		local potion = B.Get(0, 1)
		W.SetView("grid")
		assert.equal(1, potion.scale)
		assert.same({ 4, -4 }, { potion.x, potion.y })
		assert.falsy(row(1).shown)
		W.SetView("sections")
		assert.equal(1, potion.scale)
		assert.falsy(row(1).shown)
		W.SetView("list")
		assert.equal(W.LIST_ROW / W.SLOT, potion.scale)
		assert.truthy(row(1).shown)
	end)

	it("a count change repaints the row in place; nothing moves", function()
		W.Open()
		local potion = B.Get(0, 1)
		local y, placed = potion.y, potion.placed
		A.Put(0, 1, Fixtures.HEALING_POTION, 3)
		bagUpdate()
		assert.equal("3", row(1).count.text)
		assert.equal(y, potion.y)
		assert.equal(placed, potion.placed)
	end)

	-- Spec 4.3 in the list view. Mutation: in renderExtras, drop the W.rows.Ghosts call.
	it("an item that leaves leaves a row-size placeholder and a ghost row; its button goes to Free", function()
		W.Open()
		local junkY = B.Get(0, 6).y
		A.Clear(0, 6)
		bagUpdate()
		assert.equal(1, #B.placeholders)
		assert.equal(W.LIST_ROW, B.placeholders[1].size)
		assert.equal(junkY, B.placeholders[1].y)
		assert.equal(SB.L.LIST_GONE, W.rows.ghosts[1].name.text)
		assert.equal(junkY, W.rows.ghosts[1].points[1][5])
		assert.truthy(W.rows.ghosts[1].shown)
	end)

	-- P5 for rows. Mutation: in buttonBusy, drop the W.rows.IsMouseOver check.
	it("a collapse waits while the mouse is on the row (not the icon) of a button that would move", function()
		W.Open()
		local junk = B.Get(0, 6)
		local y = junk.y
		row(6).mouseOver = true
		W.ToggleSection("c_consumables")
		assert.equal(y, junk.y, "nothing moved under the row")
		row(6).mouseOver = false
		A.Advance(W.RETRY)
		assert.truthy(junk.y > y, "applied once the mouse left the row")
	end)

	-- AC8.2 in the list view: same sections, same mode sets.
	it("a focus mode collapses the same sections as in the category view", function()
		W.Open()
		SB.Focus.SetSignal("challengeMode", true)
		assert.equal("+ Junk (1)", header("c_junk").text.text)
		assert.equal("- Consumables (2) - 25s vendor", header("c_consumables").text.text)
		assert.falsy(row(6).shown, "junk's row is hidden with its section")
		assert.truthy(row(1).shown)
	end)

	-- AC5.1. Mutation: in W.SetDimmed, drop the W.rows.SetDimmed call.
	it("search dims a non-matching row together with its button", function()
		W.Open()
		SB.Slash.Dispatch("search potion")
		assert.equal(0.2, row(6).alpha)
		assert.truthy(B.Get(0, 6).dimmed)
		assert.equal(1, row(1).alpha)
	end)

	-- Item safety (spec 4.1): rows are plain frames; slot buttons are only scaled and placed, never made,
	-- reparented or re-ID'd, also in combat. Mutation: in ListRows' create(), make the row an "ItemButton".
	it("the list view makes only plain frames and never reparents or re-IDs a slot button, also in combat", function()
		local kinds, create = {}, CreateFrame
		CreateFrame = function(kind, ...)
			kinds[#kinds + 1] = kind
			return create(kind, ...)
		end
		A.combat = true
		W.Open()
		W.SetView("sections")
		W.SetView("list")
		assert.truthy(#kinds > 0, "rows were made")
		for _, kind in ipairs(kinds) do
			assert.truthy(kind == "Frame" or kind == "Button", kind) -- rows; pooled section headers
		end
		assert.equal("Frame", row(1).kind)
		for slot = 1, 16 do
			local b = B.Get(0, slot)
			assert.is_nil(b.calls.SetParent, "slot " .. slot)
			assert.is_nil(b.calls.SetID, "slot " .. slot)
		end
	end)

	it("the view button and /swagbag view switch in combat and answer; the label names the next view", function()
		A.combat = true
		W.Open()
		assert.equal(SB.L.VIEW_TO_GRID, W.viewButton.text)
		SB.Slash.Dispatch("view grid")
		assert.equal("grid", W.View())
		assert.equal(SB.L.VIEW_GRID, A.Lines()[1])
		SB.Slash.Dispatch("view")
		assert.equal(SB.L.VIEW_USAGE:format("grid"), A.Lines()[2])
		SB.Slash.Dispatch("view list")
		assert.equal("list", W.View())
		assert.truthy(row(1).shown)
	end)

	it("/swagbag view refuses with read-only settings and changes nothing", function()
		W.Open()
		SB.Config.readOnly = true
		SB.Slash.Dispatch("view grid")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[1])
		assert.equal("list", W.View())
	end)

	it("a layout held under the mouse keeps drawing the old view's geometry until it runs", function()
		SB.Config.Set("bags.newAlways", true) -- New shown, so loot under the mouse lands at once (W4-15)
		W.Open()
		W.scroll.mouseOver = true
		W.SetView("grid")
		assert.equal("list", W.drawn, "held: still the list")
		A.Put(0, 9, Fixtures.HERB, 2)
		bagUpdate()
		assert.equal(W.PAD, B.Get(0, 9).x, "loot arrives as a row")
		W.scroll.mouseOver = false
		A.Advance(W.RETRY)
		assert.equal("grid", W.drawn)
		assert.equal(1, B.Get(0, 9).scale)
	end)
end)

describe("Buttons.Place at a scale", function()
	it("offsets a scaled button by x / scale and y / scale, so it lands on the same spot", function()
		local SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua" })
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		local parent = Fake.New("Frame")
		local b = Fake.New("ItemButton", parent)
		b:SetScale(0.5)
		SB.Buttons.Place(b, 40, -60)
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 80, -120 }, b.points[1])
		b:SetScale(1)
		SB.Buttons.Place(b, 40, -60)
		assert.same({ "TOPLEFT", parent, "TOPLEFT", 40, -60 }, b.points[1])
		Fake.Uninstall()
	end)
end)
```

In `spec/bagswindow_sections_spec.lua`, find (edit 1 of 3):

```lua
	it("the header button switches to the grid and back without /reload, also in combat (AC3.1)", function()
		W.Open()
		A.combat = true
```

and replace it with:

```lua
	-- Week 5: the button shows the next view, sections -> list -> grid -> sections.
	it("the header button switches to the list, the grid and back without /reload, also in combat (AC3.1)", function()
		W.Open()
		A.combat = true
		W.viewButton.scripts.OnClick(W.viewButton)
		assert.equal("list", SB.Config.Get("bags.view"))
		assert.equal(SB.L.VIEW_TO_GRID, W.viewButton.text)
		assert.equal(SB.L.VIEW_LIST, W.frame.title.text)
```

In `spec/bagswindow_sections_spec.lua`, find (edit 2 of 3):

```lua
		assert.same({ 4, -191 }, at(0, 1))
		assert.equal(7, #headers())
```

and replace it with:

```lua
		assert.equal(SB.L.VIEW_TO_LIST, W.viewButton.text)
		assert.same({ 4, -191 }, at(0, 1))
		assert.equal(7, #headers())
```

In `spec/bagswindow_sections_spec.lua`, find (edit 3 of 3):

```lua
		assert.equal(SB.L.VIEW_TO_GRID, W.viewButton.text)
	end)
```

and replace it with:

```lua
		assert.equal(SB.L.VIEW_TO_LIST, W.viewButton.text)
	end)
```

In `spec/searchbox_spec.lua`, find:

```lua
		end
		SB.BagsWindow = window
		SB.Buttons = { SetDimmed = function(button, d) dimmed[button] = d end }
```

and replace it with:

```lua
		end
		function window.SetDimmed(button, d) -- the bags window dims the button (and a list row) through this
			SB.Buttons.SetDimmed(button, d)
		end
		SB.BagsWindow = window
		SB.Buttons = { SetDimmed = function(button, d) dimmed[button] = d end }
```

In `spec/settings_spec.lua`, find:

```lua
		assert.same({ "Grid", false }, b[2])
		assert.same({ "12", true }, b[3], "12 slots per row, the default, first")
```

and replace it with:

```lua
		assert.same({ "List", false }, b[2])
		assert.same({ "Grid", false }, b[3])
		assert.same({ "12", true }, b[4], "12 slots per row, the default, first")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1011 passed, 17 failed`:
- the 14 tests of `spec/bagswindow_list_spec.lua`, most with `attempt to index field 'rows' (a nil value)`;
- the two view-toggle tests in `spec/bagswindow_sections_spec.lua` (the button still toggles to the grid);
- the P1 test in `spec/settings_spec.lua` (`expected {1="List", 2=false}, got {1="Grid", 2=false}`).

Critical tests and their mutations (all in `spec/bagswindow_list_spec.lua`):

| Test | Mutation |
|---|---|
| "each section lists its items in the saved order: value, highest first, by default" | in `layoutSections`, delete the `SB.Sort.DisplayOrder` line |
| "switching to the grid or the categories draws the buttons at full size again and hides the rows" | in `setScale`, `if false then` instead of the scale comparison |
| "an item that leaves leaves a row-size placeholder and a ghost row; its button goes to Free" | in `renderExtras`, delete `W.rows.Ghosts(...)` |
| "a collapse waits while the mouse is on the row (not the icon) of a button that would move" | in `buttonBusy`, keep only `button:IsMouseOver()` |
| "search dims a non-matching row together with its button" | in `W.SetDimmed`, delete the `W.rows.SetDimmed` call |
| "the list view makes only plain frames and never reparents or re-IDs a slot button, also in combat" | in `UI/ListRows.lua`'s `create`, `CreateFrame("ItemButton", ...)` |
| "offsets a scaled button by x / scale and y / scale, …" | in `Buttons.Place`, pass `x, y` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.VIEW_GRID = "SwagBag - grid view"
L.VIEW_SECTIONS = "SwagBag - category view"
```

and replace it with:

```lua
L.VIEW_TO_LIST = "List"
L.VIEW_LIST = "SwagBag - list view"
L.HELP_VIEW = "view [sections|list|grid]: show or switch the bags' view (categories, list rows, or the grid)"
L.VIEW_USAGE = "The bags show the %s view. Use /swagbag view sections, /swagbag view list or /swagbag view grid."
L.VIEW_GRID = "SwagBag - grid view"
L.VIEW_SECTIONS = "SwagBag - category view"
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 1 of 26):

```lua
-- SwagBag bags window (spec F1, F3). Two views, switched with the header button
-- without /reload, in or out of combat (AC3.1):
--   "sections" (default)  category sections from Engine/Layout.lua: New on top, Free
--                         at the bottom, collapsible headers remembered per character
```

and replace it with:

```lua
-- SwagBag bags window (spec F1, F3). Three views, switched with the header button
-- without /reload, in or out of combat (AC3.1):
--   "sections" (default)  category sections from Engine/Layout.lua: New on top, Free
--                         at the bottom, collapsible headers remembered per character
--   "list"                the same sections, one row per slot (spec 2.2 v1.3): the slot's own
--                         button, scaled to the row's height, then its name, count, item level
--                         and value (UI/ListRows.lua), each section in the order of
--                         Engine/Sort.lua. Same layout engine, so New, Free, placeholders,
--                         collapse, focus modes and the hover guard work exactly as in "sections"
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 2 of 26):

```lua
	areaHeld = false, -- a world-started re-stack is waiting for the mouse to leave the items (W4-13)
	placed = {}, -- [button] = "x,y" of its last SetPoint, so unchanged buttons are not touched
	tiled = {}, -- [button] = true while it shows a free tile's number (plan D19)
```

and replace it with:

```lua
	drawn = "sections", -- the view the current layout was drawn in (the setting may change before a held layout)
	areaHeld = false, -- a world-started re-stack is waiting for the mouse to leave the items (W4-13)
	placed = {}, -- [button] = "x,y" of its last SetPoint, so unchanged buttons are not touched
	tiled = {}, -- [button] = its tile entry ({ bag, slot, ... }) while it shows a free tile's number (plan D19)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 3 of 26):

```lua
	DROP_GUARD = 0.3, -- the click that follows a drop on the same header is ignored for this long
```

and replace it with:

```lua
	DROP_GUARD = 0.3, -- the click that follows a drop on the same header is ignored for this long
	LIST_ROW = 24, -- list view: a row's height, and its slot button's size (the button is scaled to it)
	LIST_GAP = 2, -- list view: the gap between two rows
	LIST_WIDTH = 480, -- list view: the item area's width
	LIST_NEW_ROWS = 4, -- list view: rows New keeps while open (the sections view keeps bags.newRows rows)
	ROW_TEXT_GAP = 4, -- list view: between a row's icon and its texts
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 4 of 26):

```lua
W.scroll, W.child = scroll, child
SB.Buttons.SetParentFor("bags", child)
```

and replace it with:

```lua
W.scroll, W.child = scroll, child
SB.Buttons.SetParentFor("bags", child)
-- The list view's rows (UI/ListRows.lua). Without that file (a load failure) the bags show the
-- category view instead of the list.
W.rows = SB.ListRows and SB.ListRows.New(child, "bags") or nil
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 5 of 26):

```lua
function W.View()
	return SB.Config.Get("bags.view") == "grid" and "grid" or "sections"
```

and replace it with:

```lua
W.VIEWS = { "sections", "list", "grid" } -- the view button's order: each click shows the next one
local VIEW_NEXT = { sections = "list", list = "grid", grid = "sections" }
local VIEW_BUTTON = { sections = L.VIEW_TO_SECTIONS, list = L.VIEW_TO_LIST, grid = L.VIEW_TO_GRID }
local VIEW_FLASH = { sections = L.VIEW_SECTIONS, list = L.VIEW_LIST, grid = L.VIEW_GRID }

function W.View()
	local v = SB.Config.Get("bags.view")
	if v == "grid" or v == "list" then
		return v
	end
	return "sections"
end

local function isList()
	return W.drawn == "list"
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 6 of 26):

```lua
	return { columns = columns(), size = W.SLOT, gap = W.GAP, padding = W.PAD, header = W.SECTION_HEADER,
		sectionGap = W.SECTION_GAP }
```

and replace it with:

```lua
	if isList() then -- one column of rows, each as tall as its (scaled) button
		return { columns = 1, size = W.LIST_ROW, gap = W.LIST_GAP, padding = W.PAD, header = W.SECTION_HEADER,
			sectionGap = W.SECTION_GAP }
	end
	return { columns = columns(), size = W.SLOT, gap = W.GAP, padding = W.PAD, header = W.SECTION_HEADER,
		sectionGap = W.SECTION_GAP }
end

-- Layout.Position for the drawn view. A list is LIST_WIDTH wide (its single column of cells is
-- only an icon wide; the rows' texts fill the rest).
local function position(st, view)
	local pos = SB.Layout.Position(st, positionOpts(), view)
	if isList() then
		pos.width = W.LIST_WIDTH
	end
	return pos
end

-- A row's texts start right of its icon and end at the item area's right edge.
local function rowWidth()
	return W.LIST_WIDTH - 2 * W.PAD - W.LIST_ROW - W.ROW_TEXT_GAP
end

-- Slot buttons are drawn at row size in the list view and at full size elsewhere. Buttons are not
-- protected (spec 4.1), so this is legal in combat; Buttons.Place keeps offsets in the parent's
-- units at any scale. A button whose scale changes is placed again.
local function setScale(button, scale)
	if (button:GetScale() or 1) ~= scale then
		button:SetScale(scale)
		W.placed[button] = nil
	end
end

local function slotScale()
	return isList() and W.LIST_ROW / W.SLOT or 1
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 7 of 26):

```lua
-- Config is not initialized while this file loads, so the real label is set in W.Open().
W.viewButton = titleButton(L.VIEW_TO_GRID, "bags.viewButton", function()
```

and replace it with:

```lua
-- Config is not initialized while this file loads, so the real label is set in W.Open(). The button
-- names the view a click shows next (sections -> list -> grid -> sections).
W.viewButton = titleButton(L.VIEW_TO_LIST, "bags.viewButton", function()
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 8 of 26):

```lua
-- Overlays (spec F9) follow the record; an empty reagent-bag slot gets its Free cue.
local function overlay(bag, slot)
	if SB.Overlays then
		SB.Overlays.Apply(SB.Buttons.Get(bag, slot), W.records[bag] and W.records[bag][slot], bag)
```

and replace it with:

```lua
-- Overlays (spec F9) follow the record; an empty reagent-bag slot gets its Free cue. In the list
-- view the row's texts follow it too (every repaint of a slot comes through here).
local function overlay(bag, slot)
	local record = W.records[bag] and W.records[bag][slot]
	if SB.Overlays then
		SB.Overlays.Apply(SB.Buttons.Get(bag, slot), record, bag)
	end
	if isList() then
		local button = SB.Buttons.Get(bag, slot)
		if button then
			W.rows.Paint(button, bag, slot, record)
		end
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 9 of 26):

```lua
			now[button] = true
		end
	end
	for button in pairs(W.tiled) do
		if not now[button] then
			B.SetFreeCount(button, nil)
```

and replace it with:

```lua
			now[button] = t
			if isList() then
				W.rows.Paint(button, t.bag, t.slot, nil, t.count)
			end
		end
	end
	for button, t in pairs(W.tiled) do
		if not now[button] then
			B.SetFreeCount(button, nil)
			if isList() then -- a tile that filled or became a plain empty slot: its row says what it holds now
				W.rows.Paint(button, t.bag, t.slot, W.records[t.bag] and W.records[t.bag][t.slot])
			end
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 10 of 26):

```lua
			place(button, c.x, c.y)
			B.Paint(button, A.GetSlot(c.bag, c.slot))
```

and replace it with:

```lua
			setScale(button, 1)
			place(button, c.x, c.y)
			B.Paint(button, A.GetSlot(c.bag, c.slot))
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 11 of 26):

```lua
	if c.shown and inBag(c) then
		place(button, c.x, c.y)
```

and replace it with:

```lua
	local shown = c.shown and inBag(c)
	if shown then
		place(button, c.x, c.y)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 12 of 26):

```lua
	end
end

-- Each section header's text, with its total value (spec F10) when that setting is on.
```

and replace it with:

```lua
	end
	if isList() then -- a spare (hidden, no position) has no row either
		W.rows.Place(button, shown and c.x + W.LIST_ROW + W.ROW_TEXT_GAP, c.y, rowWidth(), W.LIST_ROW, shown)
	end
end

-- Each section header's text, with its total value (spec F10) when that setting is on.
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 13 of 26):

```lua
	for _, p in ipairs(pos.placeholders) do
		if p.shown then
			B.AcquirePlaceholder(child, p.icon, W.SLOT, p.x, p.y)
		end
```

and replace it with:

```lua
	local ghosts = {}
	for _, p in ipairs(pos.placeholders) do
		if p.shown then
			B.AcquirePlaceholder(child, p.icon, isList() and W.LIST_ROW or W.SLOT, p.x, p.y)
			ghosts[#ghosts + 1] = { x = p.x + W.LIST_ROW + W.ROW_TEXT_GAP, y = p.y }
		end
	end
	if isList() then -- a placeholder's row says the item moved or was used
		W.rows.Ghosts(ghosts, rowWidth(), W.LIST_ROW)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 14 of 26):

```lua
			local button = B.Get(c.bag, c.slot)
			if button then
				button:Hide()
```

and replace it with:

```lua
			local button = B.Get(c.bag, c.slot)
			if button then
				button:Hide()
				if isList() then
					W.rows.Place(button, 0, 0, 0, 0, false)
				end
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 15 of 26):

```lua
	for _, b in ipairs(bags) do
		for slot = 1, b.size do
```

and replace it with:

```lua
	local scale = slotScale()
	for _, b in ipairs(bags) do
		for slot = 1, b.size do
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 16 of 26):

```lua
			if button then -- nil only while combat delays pool growth (spec 4.3: slot invisible)
```

and replace it with:

```lua
			if button then -- nil only while combat delays pool growth (spec 4.3: slot invisible)
				setScale(button, scale)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 17 of 26):

```lua
	-- New is hidden while empty unless bags.newAlways (ruling W4-15); the bank windows never hide it.
	W.state = SB.Layout.Build(slots, SB.Categorizer.Assign, SB.Categories.SectionOrder(),
		{ columns = columns(), newRows = SB.Config.Get("bags.newRows"), freeTile = SB.Config.Get("bags.freeTile"),
			family = SB.Adapter.BagFamily, hideEmptyNew = not SB.Config.Get("bags.newAlways") })
	W.view = snapshot(W.state, W.EffectiveCollapsed())
	W.pos = SB.Layout.Position(W.state, positionOpts(), W.view)
```

and replace it with:

```lua
	-- The list view lays the slots out in its display order (Engine/Sort.lua): Layout keeps the
	-- order it is given inside each section. Empty slots keep their physical order.
	if isList() then
		slots = SB.Sort.DisplayOrder(slots, SB.Sort.Spec(), SB.Sort.Value)
	end
	-- New is hidden while empty unless bags.newAlways (ruling W4-15); the bank windows never hide it.
	W.state = SB.Layout.Build(slots, SB.Categorizer.Assign, SB.Categories.SectionOrder(),
		{ columns = isList() and 1 or columns(),
			newRows = isList() and W.LIST_NEW_ROWS or SB.Config.Get("bags.newRows"), freeTile = SB.Config.Get("bags.freeTile"),
			family = SB.Adapter.BagFamily, hideEmptyNew = not SB.Config.Get("bags.newAlways") })
	W.view = snapshot(W.state, W.EffectiveCollapsed())
	W.pos = position(W.state, W.view)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 18 of 26):

```lua
	local t0 = A.ProfileMs()
	local bags = bagList()
```

and replace it with:

```lua
	local t0 = A.ProfileMs()
	W.drawn = W.View()
	if W.drawn == "list" and not W.rows then
		W.drawn = "sections"
	end
	if W.rows then
		W.rows.HideAll()
	end
	local bags = bagList()
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 19 of 26):

```lua
	if W.View() == "grid" then
		width, height = layoutGrid(bags)
```

and replace it with:

```lua
	if W.drawn == "grid" then
		width, height = layoutGrid(bags)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 20 of 26):

```lua
local function buttonBusy(bag, slot)
	local button = SB.Buttons.Get(bag, slot)
	return button ~= nil and button:IsShown() and button:IsMouseOver()
end
W.ButtonBusy = buttonBusy
```

and replace it with:

```lua
-- In the list view a row under the mouse holds its button as well (P5: its text would move too).
local function buttonBusy(bag, slot)
	local button = SB.Buttons.Get(bag, slot)
	return button ~= nil and button:IsShown() and (button:IsMouseOver() or (isList() and W.rows.IsMouseOver(button)))
end
W.ButtonBusy = buttonBusy

-- Search dimming (UI/SearchBox.lua): the button, and in the list view its row (AC5.1: fully dimmed).
function W.SetDimmed(button, dimmed)
	SB.Buttons.SetDimmed(button, dimmed)
	if W.rows then
		W.rows.SetDimmed(button, dimmed)
	end
end
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 21 of 26):

```lua
	local pos = SB.Layout.Position(W.state, positionOpts(), view)
```

and replace it with:

```lua
	local pos = position(W.state, view)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 22 of 26):

```lua
function W.SetView(view)
	if not SB.Config.Set("bags.view", view) then -- read-only settings: nothing changes
		W.Flash(L.SETTINGS_READONLY)
		return
	end
	W.viewButton:SetText(view == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	W.Flash(view == "grid" and L.VIEW_GRID or L.VIEW_SECTIONS)
	W.RequestLayout("view")
end

function W.ToggleView()
	W.SetView(W.View() == "grid" and "sections" or "grid")
```

and replace it with:

```lua
-- view: "sections" | "list" | "grid". Returns true when the setting changed (the window regroups
-- now, or once the mouse leaves the items), false (with a title flash) while read-only.
function W.SetView(view)
	if not VIEW_NEXT[view] then
		return false
	end
	if not SB.Config.Set("bags.view", view) then -- read-only settings: nothing changes
		W.Flash(L.SETTINGS_READONLY)
		return false
	end
	W.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[view]])
	W.Flash(VIEW_FLASH[view])
	W.RequestLayout("view")
	return true
end

function W.ToggleView()
	W.SetView(VIEW_NEXT[W.View()])
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 23 of 26):

```lua
	W.viewButton:SetText(W.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
```

and replace it with:

```lua
	W.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[W.View()]])
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 24 of 26):

```lua
		W.pos = SB.Layout.Position(st, positionOpts(), W.view)
```

and replace it with:

```lua
		W.pos = position(st, W.view)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 25 of 26):

```lua
				B.Paint(button, A.GetSlot(bag, slot))
				describe(bag, slot)
```

and replace it with:

```lua
				setScale(button, slotScale())
				B.Paint(button, A.GetSlot(bag, slot))
				describe(bag, slot)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 26 of 26):

```lua
-- A bag equipped, taken off or swapped (W3-21). A swap for a bag of the same size changes no
```

and replace it with:

```lua
-- /swagbag view [sections|list|grid]: show or switch the bags' view (the view button's three views).
SB.Slash.Register("view", L.HELP_VIEW, function(arg)
	arg = (arg or ""):lower()
	if not VIEW_NEXT[arg] then
		return L.VIEW_USAGE:format(W.View())
	end
	if not W.SetView(arg) then
		return L.SETTINGS_READONLY
	end
	return VIEW_FLASH[arg]
end, "bags")

-- A bag equipped, taken off or swapped (W3-21). A swap for a bag of the same size changes no
```

In `SwagBag/UI/Buttons.lua`, find:

```lua
-- Coordinates are TOPLEFT offsets inside the window's scroll child.
function Buttons.Place(button, x, y)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x, y)
```

and replace it with:

```lua
-- Coordinates are TOPLEFT offsets inside the window's scroll child, in its units. A point's
-- offsets are in the button's own scale, so a button drawn smaller (the list view) is offset by
-- x / scale, y / scale to land on the same spot.
function Buttons.Place(button, x, y)
	local scale = button:GetScale() or 1
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x / scale, y / scale)
```

In `SwagBag/UI/SearchBox.lua`, find:

```lua
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
```

and replace it with:

```lua
	setDimmed = function(button, dimmed) -- the button, and in the list view its row (W.SetDimmed)
		return W.SetDimmed(button, dimmed)
```

In `SwagBag/UI/SettingsPages.lua`, find (edit 1 of 2):

```lua
		end, choices = { { value = "sections", text = L.VIEW_TO_SECTIONS }, { value = "grid", text = L.VIEW_TO_GRID } },
```

and replace it with:

```lua
		end, choices = { { value = "sections", text = L.VIEW_TO_SECTIONS }, { value = "list", text = L.VIEW_TO_LIST },
			{ value = "grid", text = L.VIEW_TO_GRID } },
```

In `SwagBag/UI/SettingsPages.lua`, find (edit 2 of 2):

```lua
			return v == "grid" and L.VIEW_GRID or L.VIEW_SECTIONS
```

and replace it with:

```lua
			return (v == "grid" and L.VIEW_GRID) or (v == "list" and L.VIEW_LIST) or L.VIEW_SECTIONS
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_list_spec.lua spec/bagswindow_sections_spec.lua spec/searchbox_spec.lua spec/settings_spec.lua`
Expected: `0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (55 files)`, `1028 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Rules grep**

Run: `grep -n 'CreateFrame' SwagBag/UI/BagsWindow.lua SwagBag/UI/ListRows.lua; grep -n 'SetParent\|SetID' SwagBag/UI/BagsWindow.lua SwagBag/UI/ListRows.lua`
Expected: six lines, the same five `BagsWindow.lua` creations as before (the window `Frame` with `"BackdropTemplate"`, the `UIPanelCloseButton`, the `ScrollFrame`, its child `Frame`, the `UIPanelButtonTemplate` title buttons) plus `ListRows.lua`'s `CreateFrame("Frame", nil, parent)`; no `ItemButton`. The second grep shows only `SB.Buttons.SetParentFor("bags", child)`.

- [ ] **Step 7: Commit**

```bash
git add "spec/bagswindow_list_spec.lua" "spec/bagswindow_sections_spec.lua" "spec/searchbox_spec.lua" "spec/settings_spec.lua" "SwagBag/UI/BagsWindow.lua" "SwagBag/UI/Buttons.lua" "SwagBag/UI/SearchBox.lua" "SwagBag/UI/SettingsPages.lua" "SwagBag/Locale/enUS.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 2: the list view in the bags window (rows of real slot buttons, same sections, hover guard on rows)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 3: Sortable columns, `/swagbag list`, the Settings rows, and the week-4 bags-window carry-overs

The list view gets its column bar: four plain buttons over the rows' texts (`Name`, `Count`, `ilvl`, `Value`), with a `v`/`^` marker on the sorted column. A click runs `W.SortList(by)`, which saves the order, answers in the title and regroups the list through `W.RequestLayout("listsort")`. That layout is held while the mouse is over the items or an item is on the cursor (P5, D5). The header area is `W.HeaderHeight()` (taller by the bar in the list view), and `sizeFrame` uses it everywhere it used `W.HEADER`. `/swagbag list [column] [asc|desc]` and two Settings > Bags rows (`The list view sorts by`, `The list view's order`) run the same code (week-4 D17).

The week-4 carry-overs in the same file:
- a drop calls `W.Resize()`, so a W4-25 grow that stopped retrying during the drag starts again;
- a flash cut short by the title's room also goes to chat (D27);
- a test pins the grow at the window's default place. It passes before this task's code: it pins week-4 behaviour.

`spec/helpers/uienv.lua` loads `Engine/Sort.lua` for every window spec, because the Settings rows read the saved order.

**Files:**
- Modify: `SwagBag/UI/BagsWindow.lua`, `SwagBag/UI/SettingsPages.lua`, `SwagBag/Locale/enUS.lua`, `spec/bagswindow_list_spec.lua`, `spec/settings_spec.lua`, `spec/helpers/uienv.lua`

**Interfaces:**
- Consumes: Task 1's `Sort.Spec/Save/Next/COLUMNS` and `ListRows.Columns`; Task 2's `W.drawn`, `isList`, `rowWidth`, `W.rows`.
- Produces:
  - `W.COLUMNS_H` (18), `W.HeaderHeight()`, `W.columnsBar`, `W.columnButtons[column]` (each has `.label`);
  - `W.RefreshColumns()`, `W.SortList(by, desc) -> bool`;
  - `/swagbag list`;
  - Locale `LIST_COL_*`, `LIST_SORTED`, `LIST_STATE`, `LIST_USAGE`, `LIST_NOT_SHOWN`, `SET_LIST_*`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_list_spec.lua`, find (edit 1 of 4):

```lua
			end
		end,
		GetLeft = function(self) return self.left end,
		GetTop = function(self)
			if self.anchor == "BOTTOMLEFT" then
```

and replace it with:

```lua
			elseif p[1] == "BOTTOMRIGHT" and p[3] == "BOTTOMRIGHT" then -- the default place (RestorePosition)
				self.anchor, self.right, self.edgeY = "BOTTOMRIGHT", p[4], p[5]
			end
		end,
		GetLeft = function(self)
			if self.anchor == "BOTTOMRIGHT" then
				return (UIParent.w or 0) + self.right - self.w
			end
			return self.left
		end,
		GetTop = function(self)
			if self.anchor == "BOTTOMLEFT" or self.anchor == "BOTTOMRIGHT" then
```

In `spec/bagswindow_list_spec.lua`, find (edit 2 of 4):

```lua
		SetText = function(self, s) self.text = s end,
```

and replace it with:

```lua
		IsTruncated = function(self) return self.truncated == true end,
		SetText = function(self, s) self.text = s end,
```

In `spec/bagswindow_list_spec.lua`, find (edit 3 of 4):

```lua
	it("a layout held under the mouse keeps drawing the old view's geometry until it runs", function()
```

and replace it with:

```lua
	local function lastTopLeft(f)
		local found
		for _, p in ipairs(f.points) do
			if p[1] == "TOPLEFT" then
				found = p
			end
		end
		return found
	end

	it("the column bar shows above the list only, and the items start under it", function()
		W.Open()
		assert.truthy(W.columnsBar.shown)
		assert.equal(-(W.HEADER + W.COLUMNS_H), lastTopLeft(W.scroll)[5])
		assert.equal(W.child.h + W.HEADER + W.COLUMNS_H + W.foot, W.frame.h, "the bar is part of the window")
		assert.equal("Value v", W.columnButtons.value.label.text, "the sorted column carries a marker")
		assert.equal("Name", W.columnButtons.name.label.text)
		W.SetView("grid")
		assert.falsy(W.columnsBar.shown)
		assert.equal(-W.HEADER, lastTopLeft(W.scroll)[5])
	end)

	-- Mutation: in W.SortList, drop the W.RequestLayout("listsort") call.
	it("a click on the sorted column flips it: saved, answered in the title, and the list regroups", function()
		W.Open()
		W.columnButtons.value.scripts.OnClick(W.columnButtons.value)
		assert.same({ by = "value", desc = false }, SB.Sort.Spec())
		assert.equal("Sorted by Value, lowest first", W.frame.title.text)
		assert.equal("Value ^", W.columnButtons.value.label.text)
		assert.truthy(B.Get(0, 1).y > B.Get(0, 2).y, "potion (500) above flask (2000) now")
	end)

	it("a click on another column sorts by it in its natural direction (names A to Z)", function()
		W.Open()
		W.columnButtons.name.scripts.OnClick(W.columnButtons.name)
		assert.same({ by = "name", desc = false }, SB.Sort.Spec())
		assert.equal("Sorted by Name, A to Z", W.frame.title.text)
		assert.equal("Name ^", W.columnButtons.name.label.text)
		assert.equal("Value", W.columnButtons.value.label.text)
	end)

	-- P5: re-sorting never moves a row under the mouse. Mutation: in W.SortList, call W.Layout
	-- instead of W.RequestLayout.
	it("a re-sort waits while the mouse is over the items or an item is on the cursor", function()
		W.Open()
		local potion, flask = B.Get(0, 1), B.Get(0, 2)
		local py, fy = potion.y, flask.y
		W.scroll.mouseOver = true
		W.SortList("value")
		assert.equal(py, potion.y, "held while the mouse is over the items")
		assert.equal(fy, flask.y)
		W.scroll.mouseOver = false
		A.cursor = { itemID = Fixtures.HERB }
		A.Advance(W.RETRY)
		assert.equal(py, potion.y, "held while an item is on the cursor")
		A.cursor = nil
		A.Advance(W.RETRY)
		assert.equal(fy, potion.y, "swapped once both are clear")
	end)

	-- Mutation: in W.SortList, ignore Sort.Save's result.
	it("read-only settings: a column click refuses with the reason and the order stays", function()
		W.Open()
		local y = B.Get(0, 1).y
		SB.Config.readOnly = true
		W.columnButtons.name.scripts.OnClick(W.columnButtons.name)
		assert.equal(SB.L.SETTINGS_READONLY, W.frame.title.text)
		assert.same({ by = "value", desc = true }, SB.Sort.Spec())
		assert.equal(y, B.Get(0, 1).y)
	end)

	it("/swagbag list shows and sets the order, and answers every form (P2)", function()
		W.Open()
		SB.Slash.Dispatch("list")
		SB.Slash.Dispatch("list name")
		SB.Slash.Dispatch("list count asc")
		SB.Slash.Dispatch("list weight")
		assert.same({ "List view: sorted by Value, highest first.", "Sorted by Name, A to Z", "Sorted by Count, lowest first",
			SB.L.LIST_USAGE }, A.Lines())
		assert.same({ by = "count", desc = false }, SB.Sort.Spec())
		W.SetView("grid")
		SB.Slash.Dispatch("list ilvl")
		assert.equal(SB.L.LIST_NOT_SHOWN, A.Lines()[6])
	end)

	it("a layout held under the mouse keeps drawing the old view's geometry until it runs", function()
```

In `spec/bagswindow_list_spec.lua`, find (edit 4 of 4):

```lua
		assert.equal("grid", W.drawn)
		assert.equal(1, B.Get(0, 9).scale)
```

and replace it with:

```lua
		assert.equal("grid", W.drawn)
		assert.equal(1, B.Get(0, 9).scale)
	end)
end)

describe("BagsWindow week-4 carry-overs (title flash, drop, default place)", function()
	local SB, A, W, B, F
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		B = fakeButtons()
		SB.Buttons = B
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		W, F = SB.BagsWindow, SB.Focus
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
	end)

	local function viewHeight()
		return W.frame.h - W.HEADER - W.foot
	end

	-- Week-4 deferred M4. Mutation: in W.Flash, drop the SB.Print when the title is truncated.
	it("a flash cut short by the title's room also goes to chat; one that fits does not", function()
		W.Open()
		W.Flash("short")
		assert.same({}, A.Lines())
		W.frame.title.truncated = true
		W.Flash("Sorted by Value, lowest first")
		assert.same({ "Sorted by Value, lowest first" }, A.Lines())
	end)

	-- Week-4 deferred: a drag stopped the W4-25 grow retry and the drop did not fit the window again.
	-- Mutation: in OnDragStop, drop the W.Resize() call.
	it("a drop fits the window again: a grow that waited during the drag applies once the pointer leaves", function()
		SB.Config.UI().positions.bags = { "BOTTOMLEFT", "BOTTOMLEFT", 100, 0 }
		F.SetSignal("challengeMode", true)
		W.Open()
		local top = W.frame:GetTop()
		W.frame.mouseOver = true
		W.TogglePause()
		assert.equal(top, W.frame:GetTop(), "capped under the mouse")
		W.frame.scripts.OnDragStart(W.frame)
		A.Advance(W.RETRY)
		W.frame.scripts.OnDragStop(W.frame)
		assert.equal(top, W.frame:GetTop(), "the drop moved nothing under the mouse")
		W.frame.mouseOver = false
		A.Advance(W.RETRY)
		assert.truthy(W.frame:GetTop() > top, "grown up once the pointer left")
		assert.equal(W.size[2], viewHeight())
		assert.equal(0, W.frame:GetTop() - W.frame.h, "the bottom edge stays on the screen")
	end)

	-- Week-4 deferred: no test opened the window at its default place (bottom right, 100 up).
	it("at the default place, Pause with the mouse away grows the window to the whole bag, on the screen", function()
		F.SetSignal("challengeMode", true)
		W.Open()
		assert.equal(100, W.frame:GetTop() - W.frame.h, "preflight: the default place, 100 above the bottom")
		W.TogglePause()
		assert.equal(W.size[2], viewHeight(), "the view is as tall as the bag")
		assert.truthy(W.frame:GetTop() - W.frame.h >= 0, "the bottom edge is on the screen")
		assert.truthy(W.frame:GetTop() <= UIParent.h, "the top edge is on the screen")
```

In `spec/helpers/uienv.lua`, find:

```lua
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/OverlayData.lua",
```

and replace it with:

```lua
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/OverlayData.lua",
	"SwagBag/Engine/Sort.lua",
```

In `spec/settings_spec.lua`, find:

```lua
	it("overlays page: each overlay switches through /swagbag overlays", function()
```

and replace it with:

```lua
	-- Week 5: the list view's order runs /swagbag list. Mutation: in the order row's apply, drop
	-- the saved column (run "list desc").
	it("the list rows run /swagbag list: a column in its natural direction; the order keeps the column", function()
		SB.Slash.Register("list", "test", function(arg)
			ran[#ran + 1] = "list " .. arg
			return "ran list " .. arg
		end)
		SW.Show("bags")
		assert.truthy(SW.selected[button("Value")], "value, the default, first")
		assert.truthy(SW.selected[button("Highest first (Z to A)")])
		click("Name")
		click("Lowest first (A to Z)")
		assert.same({ "list name", "list value asc" }, ran)
		assert.equal("ran list value asc", SW.lastStatus)
	end)

	it("overlays page: each overlay switches through /swagbag overlays", function()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1029 passed, 9 failed`:
- six list tests (the column bar, two column clicks, the held re-sort, read-only and `/swagbag list`);
- two carry-over tests (the flash to chat: `expected {1="Sorted by Value, lowest first"}, got {}`; the drop: `grown up once the pointer left: expected a truthy value, got false`);
- `settings_spec` "the list rows run /swagbag list…" (`no button Value`).

The tenth new test, "at the default place, Pause with the mouse away grows…", passes already: it pins week-4 behaviour.

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "a click on the sorted column flips it: saved, answered in the title, and the list regroups" | in `W.SortList`, delete the `W.RequestLayout("listsort")` block |
| "a re-sort waits while the mouse is over the items or an item is on the cursor" | in `W.SortList`, `W.Layout("listsort")` instead of `W.RequestLayout("listsort")` |
| "read-only settings: a column click refuses with the reason and the order stays" | in `W.SortList`, ignore `Sort.Save`'s result |
| "a flash cut short by the title's room also goes to chat; one that fits does not" | in `W.Flash`, delete the `IsTruncated` block |
| "a drop fits the window again: a grow that waited during the drag applies once the pointer leaves" | in `OnDragStop`, delete `W.Resize()` |
| settings_spec "the list rows run /swagbag list: …" | in the order row's apply, `run("list " .. (v and "desc" or "asc"))` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.LIST_EMPTY_TIP = "An empty bag slot: drop an item on the icon on the left."
```

and replace it with:

```lua
L.LIST_EMPTY_TIP = "An empty bag slot: drop an item on the icon on the left."
L.LIST_COL_NAME = "Name"
L.LIST_COL_COUNT = "Count"
L.LIST_COL_ILVL = "ilvl"
L.LIST_COL_VALUE = "Value"
L.LIST_COL_DOWN = "%s v"
L.LIST_COL_UP = "%s ^"
L.LIST_HIGH_FIRST = "highest first"
L.LIST_LOW_FIRST = "lowest first"
L.LIST_A_TO_Z = "A to Z"
L.LIST_Z_TO_A = "Z to A"
L.LIST_SORTED = "Sorted by %s, %s"
L.LIST_STATE = "List view: sorted by %s, %s."
L.LIST_USAGE = "Use /swagbag list, or /swagbag list <name|count|ilvl|value> [asc|desc]."
L.LIST_NOT_SHOWN = "The bags show another view now: /swagbag view list shows the list."
L.HELP_LIST = "list [name|count|ilvl|value] [asc|desc]: show or set how the list view is sorted"
L.SET_LIST_SORT = "The list view sorts by"
L.SET_LIST_ORDER = "The list view's order"
L.SET_LIST_DESC = "Highest first (Z to A)"
L.SET_LIST_ASC = "Lowest first (A to Z)"
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 1 of 11):

```lua
	ROW_TEXT_GAP = 4, -- list view: between a row's icon and its texts
```

and replace it with:

```lua
	ROW_TEXT_GAP = 4, -- list view: between a row's icon and its texts
	COLUMNS_H = 18, -- list view: the column header bar under the search box
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 2 of 11):

```lua
local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)
```

and replace it with:

```lua
local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

-- The title and search rows, plus the list view's column bar while the list is drawn.
function W.HeaderHeight()
	return W.HEADER + (W.drawn == "list" and W.COLUMNS_H or 0)
end
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 3 of 11):

```lua
-- the resting title.
function W.Flash(text)
```

and replace it with:

```lua
-- the resting title. The title ends left of the title buttons (W3-26), so a long flash in a narrow
-- window is cut short with "...": then the whole text also goes to chat, so the answer is never
-- lost (week-4 deferred M4).
function W.Flash(text)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 4 of 11):

```lua
	SB.Adapter.After(1.5, Guard("bags.flash", function()
```

and replace it with:

```lua
	if frame.title.IsTruncated and frame.title:IsTruncated() then
		SB.Print(text)
	end
	SB.Adapter.After(1.5, Guard("bags.flash", function()
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 5 of 11):

```lua
frame:SetScript("OnDragStop", Guard("bags.dragStop", function()
```

and replace it with:

```lua
-- The drop fits the window again (week-4 deferred): a grow that waited for the pointer (W4-25) stops
-- retrying while the window is dragged, so the drop starts it again from the new corner.
frame:SetScript("OnDragStop", Guard("bags.dragStop", function()
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 6 of 11):

```lua
	frame:StopMovingOrSizing()
	savePosition()
```

and replace it with:

```lua
	frame:StopMovingOrSizing()
	savePosition()
	W.Resize()
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 7 of 11):

```lua
	local maxHeight = UIParent:GetHeight() * W.MAX_HEIGHT_FRACTION / frame:GetScale()
	local viewHeight = math.min(height, maxHeight - W.HEADER - foot)
	local pinned = keepTop and type(left) == "number" and type(top) == "number" and not W.dragging
	local grown = false
	if pinned then
		local shortfall = viewHeight - (top - W.HEADER - foot)
```

and replace it with:

```lua
	local header = W.HeaderHeight()
	local maxHeight = UIParent:GetHeight() * W.MAX_HEIGHT_FRACTION / frame:GetScale()
	local viewHeight = math.min(height, maxHeight - header - foot)
	local pinned = keepTop and type(left) == "number" and type(top) == "number" and not W.dragging
	local grown = false
	if pinned then
		local shortfall = viewHeight - (top - header - foot)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 8 of 11):

```lua
		viewHeight = math.max(0, math.min(viewHeight, top - W.HEADER - foot))
	end
	frame:SetSize(width + 8, viewHeight + W.HEADER + foot)
```

and replace it with:

```lua
		viewHeight = math.max(0, math.min(viewHeight, top - header - foot))
	end
	frame:SetSize(width + 8, viewHeight + header + foot)
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 9 of 11):

```lua
W.viewButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)
```

and replace it with:

```lua
W.viewButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

---------------------------------------------------------------------------
-- The list view's column bar: Name, Count, ilvl, Value over the rows' texts. A click sorts by
-- that column (again: the other way round), saved (bags.list), and the list regroups now or once
-- the mouse leaves the items (P5: re-sorting never moves a row under the mouse). Plain buttons.
---------------------------------------------------------------------------
local COLUMN_NAMES = { name = L.LIST_COL_NAME, count = L.LIST_COL_COUNT, ilvl = L.LIST_COL_ILVL,
	value = L.LIST_COL_VALUE }
W.columnsBar = CreateFrame("Frame", nil, frame)
W.columnsBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4 + W.PAD + W.LIST_ROW + W.ROW_TEXT_GAP, -W.HEADER)
W.columnsBar:SetSize(rowWidth(), W.COLUMNS_H)
W.columnsBar:Hide()
W.columnButtons = {}
if SB.ListRows and SB.Sort then -- the list view's files (absent: no list view, see W.rows)
	local cols = SB.ListRows.Columns(rowWidth())
	for _, id in ipairs(SB.Sort.COLUMNS) do
		local b = CreateFrame("Button", nil, W.columnsBar)
		b:SetPoint("TOPLEFT", W.columnsBar, "TOPLEFT", cols[id].x, 0)
		b:SetSize(cols[id].width, W.COLUMNS_H)
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.label:SetAllPoints(b)
		b.label:SetJustifyH(id == "name" and "LEFT" or "RIGHT")
		b.label:SetText(COLUMN_NAMES[id])
		b:SetScript("OnClick", Guard("bags.listColumn", function()
			W.SortList(id)
		end, "bags"))
		W.columnButtons[id] = b
	end
end

-- How a direction reads for a column: names A to Z, numbers highest first.
local function direction(by, desc)
	if by == "name" then
		return desc and L.LIST_Z_TO_A or L.LIST_A_TO_Z
	end
	return desc and L.LIST_HIGH_FIRST or L.LIST_LOW_FIRST
end

-- The column the list is sorted by carries a marker: "Value v" (down) or "Value ^" (up).
function W.RefreshColumns()
	local spec = SB.Sort.Spec()
	for id, b in pairs(W.columnButtons) do
		if id == spec.by then
			b.label:SetText((spec.desc and L.LIST_COL_DOWN or L.LIST_COL_UP):format(COLUMN_NAMES[id]))
		else
			b.label:SetText(COLUMN_NAMES[id])
		end
	end
end

-- by: a column; desc: the direction, or nil for a click (the same column flips, another starts at
-- its natural direction, Sort.Next). Saved, answered in the title (P2), and the open list regroups.
-- Returns true, or false (with the reason in the title) while the settings are read-only.
function W.SortList(by, desc)
	local spec = SB.Sort.Next(SB.Sort.Spec(), by)
	if desc ~= nil then
		spec.desc = desc
	end
	if not SB.Sort.Save(spec.by, spec.desc) then
		W.Flash(L.SETTINGS_READONLY)
		return false
	end
	W.RefreshColumns()
	W.Flash(L.LIST_SORTED:format(COLUMN_NAMES[spec.by], direction(spec.by, spec.desc)))
	if frame:IsShown() and isList() then
		W.RequestLayout("listsort")
	end
	return true
end
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 10 of 11):

```lua
	local bags = bagList()
	W.sizes = {}
	for _, b in ipairs(bags) do
```

and replace it with:

```lua
	-- the column bar shows above a list only; the scroll area starts under it
	if isList() then
		W.RefreshColumns()
		W.columnsBar:Show()
	else
		W.columnsBar:Hide()
	end
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -W.HeaderHeight())
	local bags = bagList()
	W.sizes = {}
	for _, b in ipairs(bags) do
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 11 of 11):

```lua
-- A bag equipped, taken off or swapped (W3-21). A swap for a bag of the same size changes no
```

and replace it with:

```lua
-- /swagbag list [name|count|ilvl|value] [asc|desc]: show or set the list view's order (the column
-- bar's clicks, the Settings rows). Without a direction a column starts at its natural one.
SB.Slash.Register("list", L.HELP_LIST, function(arg)
	local by, dir = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	local spec = SB.Sort.Spec()
	if by == "" then
		return L.LIST_STATE:format(COLUMN_NAMES[spec.by], direction(spec.by, spec.desc))
	end
	if not COLUMN_NAMES[by] or not (dir == "" or dir == "asc" or dir == "desc") then
		return L.LIST_USAGE
	end
	local desc
	if dir == "" then
		desc = by ~= "name"
	else
		desc = dir == "desc"
	end
	if not W.SortList(by, desc) then
		return L.SETTINGS_READONLY
	end
	local line = L.LIST_SORTED:format(COLUMN_NAMES[by], direction(by, desc))
	if W.View() ~= "list" then
		return { line, L.LIST_NOT_SHOWN }
	end
	return line
end, "bags")

-- A bag equipped, taken off or swapped (W3-21). A swap for a bag of the same size changes no
```

In `SwagBag/UI/SettingsPages.lua`, find:

```lua
		onOff(L.SET_TITLE_ILVL, "bags.showIlvl", "overlays title"),
```

and replace it with:

```lua
		onOff(L.SET_TITLE_ILVL, "bags.showIlvl", "overlays title"),
		{ kind = "choice", label = L.SET_LIST_SORT, get = function()
			return SB.Sort.Spec().by
		end, width = 90, choices = { { value = "value", text = L.LIST_COL_VALUE }, { value = "name", text = L.LIST_COL_NAME },
			{ value = "count", text = L.LIST_COL_COUNT }, { value = "ilvl", text = L.LIST_COL_ILVL } },
		apply = function(v)
			return run("list " .. v)
		end },
		{ kind = "choice", label = L.SET_LIST_ORDER, get = function()
			return SB.Sort.Spec().desc
		end, width = 150, choices = { { value = true, text = L.SET_LIST_DESC }, { value = false, text = L.SET_LIST_ASC } },
		apply = function(v)
			return run("list " .. SB.Sort.Spec().by .. (v and " desc" or " asc"))
		end },
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/bagswindow_list_spec.lua spec/bagswindow_sections_spec.lua spec/settings_spec.lua`
Expected: `0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (55 files)`, `1038 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: In-game session L1** (see "In-game sessions"; Claude installs the build first; full restart, because Task 1 added files).

- [ ] **Step 7: Commit**

```bash
git add "spec/bagswindow_list_spec.lua" "spec/settings_spec.lua" "spec/helpers/uienv.lua" "SwagBag/UI/BagsWindow.lua" "SwagBag/UI/SettingsPages.lua" "SwagBag/Locale/enUS.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 3: sortable list columns, /swagbag list, Settings rows; drop refits the window, long flashes to chat

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 4: The theme registry, the Blizzard look as it is, Modern flat, `/swagbag theme`, Settings > Look (AC14.1, D22–D25)

`UI/Theme.lua` (first in the UI section of the TOC) holds the registry, the built-in `blizzard` palette, which is exactly today's numbers (D22), and five ways to register SwagBag's own objects: `Window`, `Text`, `Button`, `Slot` and `Row`. Each registered object is styled at once and again on every `Theme.Apply`. Every SwagBag window registers in one guarded block next to its existing lines. Those lines stay, so a build without `UI/Theme.lua` looks exactly as before:
- the bags, bank, guild bank, settings and quick setup windows: backdrops, titles and status lines;
- title, settings and quick setup buttons, the list column labels, the footer texts and list rows;
- section headers (`SectionHeaders.Tint` keeps the deposit group's green through a switch), and the slot background SwagBag adds under each item.

`UI/Themes.lua` (after the settings pages) registers Modern flat, adds `/swagbag theme` and the Settings > Look page. At login the saved look is applied. One that cannot be used then shows the Blizzard look for the session, says so once, and stays saved (Review Focus 5).

**Files:**
- Create: `SwagBag/UI/Theme.lua`, `SwagBag/UI/Themes.lua`, `spec/theme_spec.lua`
- Modify:
  - window registration: `SwagBag/UI/BagsWindow.lua`, `SwagBag/UI/BankWindow.lua`, `SwagBag/UI/GuildBankWindow.lua`, `SwagBag/UI/SettingsWindow.lua`, `SwagBag/UI/QuickSetup.lua`, `SwagBag/UI/Footer.lua`, `SwagBag/UI/ListRows.lua`;
  - `SwagBag/UI/SectionHeaders.lua`, `SwagBag/UI/GroupView.lua` (`Tint`), `SwagBag/UI/Buttons.lua` (the slot background);
  - `SwagBag/Core/Adapter.lua` (`FontObject`), `SwagBag/Core/Config.lua` (`theme.name`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`;
  - `spec/bagswindow_list_spec.lua` (a describe for the bags window's look).

**Interfaces:**
- Consumes: `SB.SettingsWindow.AddPage/RunCommand`, `SB.Slash.Register`, `SB.Config.Set`, `SB_LOGIN`.
- Produces:
  - `SB.Theme.Register(def)`, `.Apply(id, save) -> ok, why` (`"unknown" | "unavailable" | "readonly"`), `.Current()`, `.Name(id)`, `.Available(id)`, `.order`, `.themes`, `.BLANK`, `.SLOT_ATLAS`;
  - the registration functions `.Window(frame, "main"|"dialog")`, `.Text(fs, role)`, `.Button(b)`, `.Slot(texture)`, `.Row(row)`, and `.HeaderColor() -> r, g, b, a`;
  - the event `SB_THEME_CHANGED(id)`;
  - `SB.SectionHeaders.Tint(h, r, g, b, a)`; `SB.Adapter.FontObject(name)`;
  - `/swagbag theme`, the settings page id `"look"`, and the setting `theme.name` (`"blizzard"`).
  - A palette is `{ window, dialog, border, header, row?, slot?, backdrop, fonts?, button? }`. `fonts` is either font-object names by role or `{ file, size, flags }` (Task 5).

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_list_spec.lua`, find:

```lua
describe("Buttons.Place at a scale", function()
```

and replace it with:

```lua
describe("BagsWindow look (themes)", function()
	local SB, A, W
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.FontObject = function(name) return { fontObject = name } end
		CreateFrame = function(kind) return newFake(kind) end
		UIParent = newFake("Frame")
		UIParent.h = 2000
		UISpecialFrames = {}
		IsControlKeyDown = function() return false end
		SB.Buttons = fakeButtons()
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ListRows.lua")
		Loader.LoadFile(SB, "SwagBag/UI/BagsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
	end)

	-- AC14.1 and the live switch. Mutation: in BagsWindow.lua, drop SB.Theme.Window(frame, "main").
	it("the window, its title, column labels, headers and list rows follow the look, live and back", function()
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, W.frame.calls.SetBackdropColor, "the Blizzard look as before")
		SB.Config.Set("bags.view", "list")
		W.Open()
		local row = W.rows.rows[SB.Buttons.Get(0, 1)]
		assert.falsy(row.bg.shown)
		assert.truthy(SB.Theme.Apply("flat", false))
		assert.same({ 0.09, 0.09, 0.1, 0.92 }, W.frame.calls.SetBackdropColor)
		assert.same({ { fontObject = "GameFontHighlight" } }, W.frame.title.calls.SetFontObject)
		assert.same({ { fontObject = "GameFontHighlightSmall" } }, W.columnButtons.value.label.calls.SetFontObject)
		assert.truthy(row.bg.shown, "list rows get the flat stripe")
		assert.same({ { fontObject = "GameFontHighlightSmall" } }, row.name.calls.SetFontObject)
		assert.same({ 1, 1, 1, 0.03 }, SB.SectionHeaders.inUse[1].bg.calls.SetColorTexture)
		SB.Theme.Apply("blizzard", false)
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, W.frame.calls.SetBackdropColor)
		assert.falsy(row.bg.shown)
	end)
end)

describe("Buttons.Place at a scale", function()
```

Create `spec/theme_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Themes (UI/Theme.lua, UI/Themes.lua): the Blizzard look is exactly the old one (AC14.1); a theme
-- restyles only SwagBag's own frames, live, in or out of combat; refusals answer (P2).
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Theme", function()
	local SB, A, T
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		Fake.Install()
		A.FontObject = function(name) return { fontObject = name } end
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		T = SB.Theme
		SB.Config.Init(nil, nil)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- A font string made with a font object, as the windows make theirs.
	local function fontString(objectName)
		local fs = Fake.New("FontString")
		fs.GetFontObject = function() return objectName end
		return fs
	end

	local function templateButton()
		local b = Fake.New("Button")
		b.Left, b.Middle, b.Right = Fake.New("Texture"), Fake.New("Texture"), Fake.New("Texture")
		return b
	end

	-- AC14.1. Mutation: change any number of the Blizzard palette (e.g. window alpha 0.95 -> 0.9).
	it("the Blizzard look is the old one: backdrops, header colour, slot atlas, fonts untouched", function()
		local main, dialog = Fake.New("Frame"), Fake.New("Frame")
		T.Window(main, "main")
		T.Window(dialog, "dialog")
		assert.same({ { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 } },
			main.calls.SetBackdrop)
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, main.calls.SetBackdropColor)
		assert.same({ 0.35, 0.35, 0.4, 1 }, main.calls.SetBackdropBorderColor)
		assert.same({ 0.06, 0.06, 0.08, 0.97 }, dialog.calls.SetBackdropColor)
		assert.same({ 1, 1, 1, 0.06 }, { T.HeaderColor() })
		local slot = Fake.New("Texture")
		T.Slot(slot)
		assert.same({ "bags-item-slot64" }, slot.calls.SetAtlas)
		local fs = fontString("GameFontNormal")
		T.Text(fs, "title")
		assert.same({ "GameFontNormal" }, fs.calls.SetFontObject, "the font it was made with")
		local b = templateButton()
		T.Button(b)
		assert.truthy(b.Left.shown)
		assert.is_nil(b.calls.CreateTexture, "no texture added to a button in the Blizzard look")
	end)

	-- Mutation: in Theme.Apply, drop restyleAll().
	it("Modern flat restyles every registered object at once, and Blizzard puts every one back", function()
		local main, fs, b, slot = Fake.New("Frame"), fontString("GameFontNormal"), templateButton(), Fake.New("Texture")
		local row = Fake.New("Frame")
		row.bg = Fake.New("Texture")
		T.Window(main, "main")
		T.Text(fs, "title")
		T.Button(b)
		T.Slot(slot)
		T.Row(row)
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		assert.truthy(T.Apply("flat", true))
		assert.equal("flat", SB.Config.Get("theme.name"))
		assert.same({ 0.09, 0.09, 0.1, 0.92 }, main.calls.SetBackdropColor)
		assert.same({ 0, 0, 0, 1 }, main.calls.SetBackdropBorderColor)
		assert.same({ { fontObject = "GameFontHighlight" } }, fs.calls.SetFontObject)
		assert.falsy(b.Left.shown, "the template's own textures are hidden")
		assert.same({ 0.14, 0.14, 0.15, 1 }, slot.calls.SetColorTexture)
		assert.truthy(row.bg.shown)
		assert.truthy(T.Apply("blizzard", true))
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, main.calls.SetBackdropColor)
		assert.same({ "GameFontNormal" }, fs.calls.SetFontObject)
		assert.truthy(b.Left.shown)
		assert.same({ "bags-item-slot64" }, slot.calls.SetAtlas)
		assert.falsy(row.bg.shown)
	end)

	it("an object registered while a theme is on gets that theme at once", function()
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		T.Apply("flat", false)
		local w = Fake.New("Frame")
		T.Window(w, "dialog")
		assert.same({ 0.09, 0.09, 0.1, 0.96 }, w.calls.SetBackdropColor)
	end)

	-- Mutation: in Theme.Apply, write theme.name before the availability check.
	it("Apply refuses an unknown look, a look not available now and read-only settings, and changes nothing", function()
		T.Register({ id = "gone", name = "Gone", available = function() return false end, palette = function() return {} end })
		local main = Fake.New("Frame")
		T.Window(main, "main")
		assert.same({ false, "unknown" }, { T.Apply("nope", true) })
		assert.same({ false, "unavailable" }, { T.Apply("gone", true) })
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { T.Apply("flat", true) })
		assert.equal("blizzard", T.Current())
		assert.equal("blizzard", SB.Config.Get("theme.name"))
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, main.calls.SetBackdropColor)
	end)

	it("SB_THEME_CHANGED fires with the new look", function()
		local seen
		SB.On("SB_THEME_CHANGED", function(_, id) seen = id end)
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		T.Apply("flat", false)
		assert.equal("flat", seen)
	end)

	it("at login the saved look applies; one not available now shows Blizzard's, says so once and stays saved", function()
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		SB.Config.Set("theme.name", "flat")
		SB.Emit("SB_LOGIN")
		assert.equal("flat", T.Current())
		T.Apply("blizzard", false)
		T.Register({ id = "gone", name = "Gone", available = function() return false end, palette = function() return {} end })
		SB.Config.Set("theme.name", "gone")
		SB.Emit("SB_LOGIN")
		assert.equal("blizzard", T.Current())
		assert.same({ SB.L.THEME_FALLBACK:format("Gone") }, A.Lines())
		assert.equal("gone", SB.Config.Get("theme.name"))
	end)

	it("restyles in combat and creates no frame (a flat button gets one texture of SwagBag's own)", function()
		local b = templateButton()
		T.Button(b)
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		A.combat = true
		local n = #Fake.created
		assert.truthy(T.Apply("flat", false))
		assert.equal(n, #Fake.created)
		assert.falsy(b.Left.shown)
	end)

	it("loads before Config.Init without touching Config", function()
		local SB2 = Loader.New(Env.ENGINE)
		SB2.Config.Get = function() error("Config.Get called while loading") end
		local ok, err = pcall(Loader.LoadFile, SB2, "SwagBag/UI/Theme.lua")
		assert.truthy(ok, tostring(err))
	end)
end)

describe("Themes: /swagbag theme, Settings > Look, the windows", function()
	local SB, A, T, SW
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		Env.PaintGlobals()
		A.FontObject = function(name) return { fontObject = name } end
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		T = SB.Theme
		SB.BagsWindow = { View = function() return "sections" end }
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		SW = SB.SettingsWindow
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
	end)

	-- P2. Mutation: in the theme command, return THEME_SET even when Apply fails.
	it("/swagbag theme answers every form", function()
		T.Register({ id = "gone", name = "Gone", available = function() return false end, palette = function() return {} end })
		SB.Slash.Dispatch("theme")
		SB.Slash.Dispatch("theme flat")
		SB.Slash.Dispatch("theme gone")
		SB.Slash.Dispatch("theme nope")
		local lines = A.Lines()
		assert.truthy(lines[1]:find("Look: Blizzard. Looks: blizzard (Blizzard), flat (Modern flat), ", 1, true), lines[1])
		assert.truthy(lines[1]:find("gone (Gone, not available now)", 1, true), lines[1])
		assert.equal("Look: Modern flat. Only SwagBag's own windows change.", lines[2])
		assert.equal(SB.L.THEME_UNAVAILABLE:format("Modern flat"), lines[3])
		assert.truthy(lines[4]:find("Use /swagbag theme", 1, true))
		SB.Config.readOnly = true
		SB.Slash.Dispatch("theme blizzard")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[5])
		assert.equal("flat", T.Current())
	end)

	it("Settings > Look: Blizzard first and selected; a click switches live and the status line answers", function()
		SW.Show("look")
		assert.equal("Blizzard", SW.buttons[1].text)
		assert.truthy(SW.selected[SW.buttons[1]])
		Fake.Fire(SW.buttons[2], "OnClick")
		assert.equal("flat", T.Current())
		assert.equal("Look: Modern flat. Only SwagBag's own windows change.", SW.lastStatus)
		assert.same({ 0.09, 0.09, 0.1, 0.96 }, SW.frame.calls.SetBackdropColor, "the settings window itself changed")
		assert.truthy(SW.selected[SW.buttons[2]])
	end)

	it("the bank window and its title buttons follow the look", function()
		Env.FakeBags(SB)
		Env.LoadBank(SB)
		local BW = SB.BankWindow
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, BW.frame.calls.SetBackdropColor)
		T.Apply("flat", false)
		assert.same({ 0.09, 0.09, 0.1, 0.92 }, BW.frame.calls.SetBackdropColor)
		assert.same({ { fontObject = "GameFontHighlight" } }, BW.frame.title.calls.SetFontObject)
	end)

	-- The deposit group keeps its tint through a theme change. Mutation: drop the tinted check in
	-- SectionHeaders' SB_THEME_CHANGED handler.
	it("section headers take the new background, except one tinted for deposits", function()
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		local H = SB.SectionHeaders
		local parent = Fake.New("Frame")
		local plain = H.Acquire(parent, "c_junk", "Junk", 0, 0, 100)
		local tinted = H.Acquire(parent, "#bank", "Bank", 0, -20, 100)
		H.Tint(tinted, 0.25, 0.85, 0.35, 0.3)
		T.Apply("flat", false)
		assert.same({ 1, 1, 1, 0.03 }, plain.bg.calls.SetColorTexture)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, tinted.bg.calls.SetColorTexture)
		H.ReleaseAll(parent)
		local again = H.Acquire(parent, "#bank", "Bank", 0, 0, 100)
		assert.same({ 1, 1, 1, 0.03 }, again.bg.calls.SetColorTexture, "a reacquired header loses the tint")
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1038 passed, 13 failed`. The 12 tests of `spec/theme_spec.lua` and the new "BagsWindow look (themes)" test fail, all with `cannot open SwagBag/UI/Theme.lua: No such file or directory`.

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "the Blizzard look is the old one: backdrops, header colour, slot atlas, fonts untouched" (AC14.1) | in the Blizzard palette, the window alpha `0.95` → `0.9` |
| "Modern flat restyles every registered object at once, and Blizzard puts every one back" | in `Theme.Apply`, delete `restyleAll()` |
| "Apply refuses an unknown look, a look not available now and read-only settings, and changes nothing" | in `Theme.Apply`, delete the `save and not SB.Config.Set(...)` refusal |
| "section headers take the new background, except one tinted for deposits" | in `SectionHeaders`' `SB_THEME_CHANGED` handler, `if true then` instead of `if not tinted[h] then` |
| bagswindow_list_spec "the window, its title, column labels, headers and list rows follow the look, live and back" | in `BagsWindow.lua`, delete `SB.Theme.Window(frame, "main")` |
| "/swagbag theme answers every form" | in the theme command, `if true then return L.THEME_SET…` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Adapter.lua`, find:

```lua
-- "bank" (character bank) | "warband" | nil: the bank type Blizzard's bank frame has
```

and replace it with:

```lua
-- One of Blizzard's font objects by its global name (GameFontHighlight, ...), or nil (themes).
function A.FontObject(name)
	local object = _G[name]
	return type(object) == "table" and object or nil
end

-- "bank" (character bank) | "warband" | nil: the bank type Blizzard's bank frame has
```

In `SwagBag/Core/Config.lua`, find:

```lua
		-- like the settings it sets, so it shows once per account, not once per character.
		setup = { done = false },
```

and replace it with:

```lua
		-- like the settings it sets, so it shows once per account, not once per character.
		setup = { done = false },
		-- name: the look of SwagBag's own windows (UI/Theme.lua): "blizzard" (the default, AC14.1) |
		-- "flat" | "elvui" (UI/Themes.lua).
		theme = { name = "blizzard" },
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

and replace it with:

```lua
-- Themes (week 5): the look of SwagBag's own windows
L.THEME_BLIZZARD = "Blizzard"
L.THEME_FALLBACK = "The %s look cannot be used now, so SwagBag looks like Blizzard's bags this session."
L.THEME_FLAT = "Modern flat"
L.THEME_NOT_LOADED = "%s, not available now"
L.THEME_ITEM = "%s (%s)"
L.HELP_THEME = "theme [blizzard|flat|elvui]: show or switch the look of SwagBag's windows"
L.THEME_STATE = "Look: %s. Looks: %s."
L.THEME_SET = "Look: %s. Only SwagBag's own windows change."
L.THEME_UNAVAILABLE = "That look cannot be used now. The look stays %s."
L.THEME_USAGE = "Use /swagbag theme, or /swagbag theme <name>. Looks: %s."
L.SET_PAGE_LOOK = "Look"
L.SET_LOOK = "The look of SwagBag's windows"
L.SET_LOOK_NOTE = "Only SwagBag's own windows, headers, rows and buttons change. Item buttons keep Blizzard's icons and"
	.. " quality borders."

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
```

In `SwagBag/SwagBag.toc`, find (edit 1 of 2):

```text
UI/ReportBox.lua
UI/Buttons.lua
UI/SectionHeaders.lua
```

and replace it with:

```text
UI/Theme.lua
UI/ReportBox.lua
UI/Buttons.lua
UI/SectionHeaders.lua
```

In `SwagBag/SwagBag.toc`, find (edit 2 of 2):

```text
UI/Footer.lua
UI/QuickSetup.lua
UI/DebugV1.lua
```

and replace it with:

```text
UI/Footer.lua
UI/Themes.lua
UI/QuickSetup.lua
UI/DebugV1.lua
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 1 of 3):

```lua
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.BAGS_TITLE)
```

and replace it with:

```lua
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.BAGS_TITLE)
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "main")
	SB.Theme.Text(frame.title, "title")
end
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 2 of 3):

```lua
	b:SetScript("OnClick", Guard(label, onClick, "bags"))
```

and replace it with:

```lua
	b:SetScript("OnClick", Guard(label, onClick, "bags"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
```

In `SwagBag/UI/BagsWindow.lua`, find (edit 3 of 3):

```lua
		b:SetScript("OnClick", Guard("bags.listColumn", function()
```

and replace it with:

```lua
		if SB.Theme then
			SB.Theme.Text(b.label, "small")
		end
		b:SetScript("OnClick", Guard("bags.listColumn", function()
```

In `SwagBag/UI/BankWindow.lua`, find (edit 1 of 3):

```lua
frame.deposit:SetPoint("TOPLEFT", 14, -58)
frame.deposit:SetJustifyH("LEFT")
```

and replace it with:

```lua
frame.deposit:SetPoint("TOPLEFT", 14, -58)
frame.deposit:SetJustifyH("LEFT")
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "main")
	SB.Theme.Text(frame.title, "title")
	SB.Theme.Text(frame.deposit, "small")
end
```

In `SwagBag/UI/BankWindow.lua`, find (edit 2 of 3):

```lua
	b:SetScript("OnClick", Guard(label, onClick, "bank"))
```

and replace it with:

```lua
	b:SetScript("OnClick", Guard(label, onClick, "bank"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
```

In `SwagBag/UI/BankWindow.lua`, find (edit 3 of 3):

```lua
BW.stillOpenButton:Hide()

-- The bags title ends left of the leftmost shown title button: this one while it shows.
```

and replace it with:

```lua
BW.stillOpenButton:Hide()
if SB.Theme then
	SB.Theme.Button(BW.stillOpenButton)
end

-- The bags title ends left of the leftmost shown title button: this one while it shows.
```

In `SwagBag/UI/Buttons.lua`, find (edit 1 of 2):

```lua
local function addBackground(button)
	local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
```

and replace it with:

```lua
-- SwagBag's own slot background under the item (a texture region on the button, as since week 1).
-- The theme (UI/Theme.lua) restyles it; the Blizzard theme is the atlas below.
local function addBackground(button)
	local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
```

In `SwagBag/UI/Buttons.lua`, find (edit 2 of 2):

```lua
		bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
```

and replace it with:

```lua
		bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
	end
	if SB.Theme then
		SB.Theme.Slot(bg)
```

In `SwagBag/UI/Footer.lua`, find:

```lua
		w:SetScript("OnEnter", Guard("footer.tip", function(self)
```

and replace it with:

```lua
		if SB.Theme then
			SB.Theme.Text(w.text, "small")
		end
		w:SetScript("OnEnter", Guard("footer.tip", function(self)
```

In `SwagBag/UI/GroupView.lua`, find:

```lua
				h.bg:SetColorTexture(0.25, 0.85, 0.35, 0.3)
```

and replace it with:

```lua
				H.Tint(h, 0.25, 0.85, 0.35, 0.3)
```

In `SwagBag/UI/GuildBankWindow.lua`, find (edit 1 of 2):

```lua
frame.deposit:SetPoint("TOPLEFT", 14, -58)
frame.deposit:SetJustifyH("LEFT")
```

and replace it with:

```lua
frame.deposit:SetPoint("TOPLEFT", 14, -58)
frame.deposit:SetJustifyH("LEFT")
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "main")
	SB.Theme.Text(frame.title, "title")
	SB.Theme.Text(frame.deposit, "small")
end
```

In `SwagBag/UI/GuildBankWindow.lua`, find (edit 2 of 2):

```lua
	b:SetScript("OnClick", Guard(label, onClick, "bank"))
```

and replace it with:

```lua
	b:SetScript("OnClick", Guard(label, onClick, "bank"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
```

In `SwagBag/UI/ListRows.lua`, find (edit 1 of 2):

```lua
		fs:SetJustifyH(justify)
		fs:SetWordWrap(false)
```

and replace it with:

```lua
		fs:SetJustifyH(justify)
		fs:SetWordWrap(false)
		if SB.Theme then
			SB.Theme.Text(fs, "row")
		end
```

In `SwagBag/UI/ListRows.lua`, find (edit 2 of 2):

```lua
		row:SetScript("OnLeave", Guard("list.rowTipHide", hideTip, window))
```

and replace it with:

```lua
		row:SetScript("OnLeave", Guard("list.rowTipHide", hideTip, window))
		if SB.Theme then
			SB.Theme.Row(row)
		end
```

In `SwagBag/UI/QuickSetup.lua`, find (edit 1 of 2):

```lua
frame.status:SetPoint("BOTTOMLEFT", 14, 44)
frame.status:SetText(L.QS_HINT)
```

and replace it with:

```lua
frame.status:SetPoint("BOTTOMLEFT", 14, 44)
frame.status:SetText(L.QS_HINT)
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "dialog")
	SB.Theme.Text(frame.title, "title")
	SB.Theme.Text(frame.intro, "body")
	SB.Theme.Text(frame.columnsLabel, "label")
	SB.Theme.Text(frame.status, "small")
end
```

In `SwagBag/UI/QuickSetup.lua`, find (edit 2 of 2):

```lua
end, "none"))

-- Closing without Apply or Skip (Esc, the X) is "later": it says when the screen comes back.
```

and replace it with:

```lua
end, "none"))
if SB.Theme then
	for _, b in pairs(QS.styleButtons) do
		SB.Theme.Button(b)
	end
	for _, b in pairs(QS.columnButtons) do
		SB.Theme.Button(b)
	end
	SB.Theme.Button(QS.applyButton)
	SB.Theme.Button(QS.skipButton)
end

-- Closing without Apply or Skip (Esc, the X) is "later": it says when the screen comes back.
```

In `SwagBag/UI/SectionHeaders.lua`, find (edit 1 of 4):

```lua
local parents, owners, labels = {}, {}, {}
```

and replace it with:

```lua
local parents, owners, labels, tinted = {}, {}, {}, {}

-- The header background: the theme's (UI/Theme.lua), else the look SwagBag always had.
local function headerColor()
	if SB.Theme then
		return SB.Theme.HeaderColor()
	end
	return 1, 1, 1, 0.06
end
```

In `SwagBag/UI/SectionHeaders.lua`, find (edit 2 of 4):

```lua
	h.bg:SetColorTexture(1, 1, 1, 0.06)
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h.text:SetPoint("LEFT", h, "LEFT", 4, 0)
	h.text:SetJustifyH("LEFT")
```

and replace it with:

```lua
	h.bg:SetColorTexture(headerColor())
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h.text:SetPoint("LEFT", h, "LEFT", 4, 0)
	h.text:SetJustifyH("LEFT")
	if SB.Theme then
		SB.Theme.Text(h.text, "header")
	end
```

In `SwagBag/UI/SectionHeaders.lua`, find (edit 3 of 4):

```lua
	h.bg:SetColorTexture(1, 1, 1, 0.06)
	h.text:SetText(label)
```

and replace it with:

```lua
	tinted[h] = nil
	h.bg:SetColorTexture(headerColor())
	h.text:SetText(label)
```

In `SwagBag/UI/SectionHeaders.lua`, find (edit 4 of 4):

```lua
end

-- Change the text of the header (parent, sectionId) in place, only when it differs. Group headers
```

and replace it with:

```lua
end

-- A header with its own colour (the bank group that receives deposits): kept through theme changes
-- until the header is acquired again.
function H.Tint(h, r, g, b, a)
	tinted[h] = true
	h.bg:SetColorTexture(r, g, b, a)
end

-- A new look (UI/Theme.lua): every header that is not tinted takes the theme's background.
SB.On("SB_THEME_CHANGED", function()
	for _, list in ipairs({ H.inUse, H.pool }) do
		for _, h in ipairs(list) do
			if not tinted[h] then
				h.bg:SetColorTexture(headerColor())
			end
		end
	end
end, "none")

-- Change the text of the header (parent, sectionId) in place, only when it differs. Group headers
```

In `SwagBag/UI/SettingsWindow.lua`, find (edit 1 of 4):

```lua
frame.status:SetWordWrap(true)
frame.status:SetText(L.SET_SAVED_NOTE)
```

and replace it with:

```lua
frame.status:SetWordWrap(true)
frame.status:SetText(L.SET_SAVED_NOTE)
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "dialog")
	SB.Theme.Text(frame.title, "title")
	SB.Theme.Text(frame.status, "small")
end
```

In `SwagBag/UI/SettingsWindow.lua`, find (edit 2 of 4):

```lua
		fs:SetJustifyH("LEFT")
		SW.labels[SW.used.labels] = fs
```

and replace it with:

```lua
		fs:SetJustifyH("LEFT")
		if SB.Theme then
			SB.Theme.Text(fs, "label")
		end
		SW.labels[SW.used.labels] = fs
```

In `SwagBag/UI/SettingsWindow.lua`, find (edit 3 of 4):

```lua
		end, "none"))
		SW.buttons[SW.used.buttons] = b
```

and replace it with:

```lua
		end, "none"))
		if SB.Theme then
			SB.Theme.Button(b)
		end
		SW.buttons[SW.used.buttons] = b
```

In `SwagBag/UI/SettingsWindow.lua`, find (edit 4 of 4):

```lua
	end, "none"))
	SW.nav[page.id] = b
	return page
```

and replace it with:

```lua
	end, "none"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	SW.nav[page.id] = b
	return page
```

Create `SwagBag/UI/Theme.lua`:

```lua
-- SwagBag themes (spec 3.2 "Theme", AC14.1, 2.2 v1.3): how SwagBag's OWN frames look. A theme
-- is a palette; the frames register here once and are restyled whenever the theme changes, live,
-- in or out of combat (no /reload). What a theme touches, and nothing else:
--   Theme.Window(frame, kind)  a window's backdrop (kind "main": bags, bank, guild bank, alt viewer;
--                              "dialog": settings, quick setup). frame uses "BackdropTemplate"
--   Theme.Text(fs, role)       a font string's font (role "title" | "header" | "label" | "body" |
--                              "small" | "row"); the Blizzard look puts back the font it was made with
--   Theme.Button(b)            SwagBag's own UIPanelButtonTemplate buttons (title buttons, settings):
--                              a flat look hides the template's Left/Middle/Right textures and shows a
--                              flat texture of SwagBag's own; never an item button or a secure frame
--   Theme.Slot(texture)        the slot background SwagBag adds under each item button (Buttons.lua):
--                              SwagBag's own texture region, as in week 3 (regions only, nothing of
--                              Blizzard's is restyled)
--   Theme.Row(row)             a list-view row's background (UI/ListRows.lua)
--   Theme.HeaderColor() -> r, g, b, a   section headers' background (UI/SectionHeaders.lua)
-- The "blizzard" theme (built in, the default) is exactly the look SwagBag had before themes
-- (AC14.1): the same backdrop colours, Blizzard's fonts and the bag-slot atlas. More themes come
-- from UI/Themes.lua. Theme.Register{ id, name, available() -> bool, unavailable (text), palette() }
--   palette = { window, dialog, border = { r, g, b, a }, header = { r, g, b, a }, row = colour | nil,
--     slot = colour | nil (nil: the bag-slot atlas), backdrop = texture path, fonts = nil | { [role] =
--     font object name } | { file, size, flags } (one font file, sizes by role), button = nil | { bg, border } }
--   Theme.Apply(id, save) -> ok, why   why: "unknown" | "unavailable" | "readonly"; save writes
--     settings.theme.name. Emits SB_THEME_CHANGED(id).
-- The saved theme is applied at login; one that is not available then (ElvUI not loaded) shows the
-- Blizzard look for the session, says so once, and stays saved.
local _, SB = ...

local L = SB.L
local Theme = { themes = {}, order = {}, current = "blizzard" }
SB.Theme = Theme

local weak = { __mode = "k" }
local windows = setmetatable({}, weak) -- [frame] = kind
local texts = setmetatable({}, weak) -- [fs] = { role, original font object }
local buttons = setmetatable({}, weak) -- [button] = true
local flats = setmetatable({}, weak) -- [button] = SwagBag's flat texture on it
local slots = setmetatable({}, weak) -- [texture] = true
local rows = setmetatable({}, weak) -- [row] = true

Theme.SLOT_ATLAS = "bags-item-slot64"
Theme.BLANK = "Interface\\Buttons\\WHITE8x8"
local SIZES = { title = 1, header = 0, label = 0, body = -1, small = -1, row = -1 } -- one-font themes: size offsets

function Theme.Register(def)
	if not Theme.themes[def.id] then
		Theme.order[#Theme.order + 1] = def.id
	end
	Theme.themes[def.id] = def
	return def
end

Theme.Register({
	id = "blizzard",
	name = L.THEME_BLIZZARD,
	available = function()
		return true
	end,
	palette = function()
		return { window = { 0.06, 0.06, 0.08, 0.95 }, dialog = { 0.06, 0.06, 0.08, 0.97 }, border = { 0.35, 0.35, 0.4, 1 },
			header = { 1, 1, 1, 0.06 }, backdrop = Theme.BLANK }
	end,
})

local palette = Theme.themes.blizzard.palette()

function Theme.Current()
	return Theme.current
end

function Theme.Name(id)
	local def = Theme.themes[id]
	return def and def.name or tostring(id)
end

function Theme.Available(id)
	local def = Theme.themes[id]
	if not def then
		return false
	end
	local ok, yes = pcall(def.available)
	return ok and yes == true
end

---------------------------------------------------------------------------
-- Styling one object with the current palette
---------------------------------------------------------------------------
local function styleWindow(frame, kind)
	local bg = palette[kind] or palette.window
	frame:SetBackdrop({ bgFile = palette.backdrop, edgeFile = palette.backdrop, edgeSize = 1 })
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	local b = palette.border
	frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4])
end

local function styleText(fs, t)
	local f = palette.fonts
	if f == nil then
		if t.original then
			fs:SetFontObject(t.original)
		end
	elseif f.file then
		fs:SetFont(f.file, f.size + (SIZES[t.role] or 0), f.flags)
	else
		local object = f[t.role] and SB.Adapter.FontObject(f[t.role])
		if object then
			fs:SetFontObject(object)
		elseif t.original then
			fs:SetFontObject(t.original)
		end
	end
end

local TEMPLATE_PARTS = { "Left", "Middle", "Right" }

local function styleButton(b)
	local look = palette.button
	for _, key in ipairs(TEMPLATE_PARTS) do
		local part = b[key]
		if type(part) == "table" and part.SetShown then
			part:SetShown(look == nil)
		end
	end
	local flat = flats[b]
	if look and not flat then
		flat = b:CreateTexture(nil, "BACKGROUND")
		flat:SetAllPoints(b)
		flats[b] = flat
	end
	if flat then
		if look then
			flat:SetColorTexture(look.bg[1], look.bg[2], look.bg[3], look.bg[4])
			flat:Show()
		else
			flat:Hide()
		end
	end
end

local function styleSlot(tex)
	local c = palette.slot
	if c then
		tex:SetColorTexture(c[1], c[2], c[3], c[4])
	elseif not pcall(tex.SetAtlas, tex, Theme.SLOT_ATLAS) then
		tex:SetColorTexture(0.15, 0.15, 0.15, 0.8)
	end
end

local function styleRow(row)
	local c = palette.row
	if not row.bg then
		return
	end
	if c then
		row.bg:SetColorTexture(c[1], c[2], c[3], c[4])
		row.bg:Show()
	else
		row.bg:Hide()
	end
end

function Theme.HeaderColor()
	local c = palette.header
	return c[1], c[2], c[3], c[4]
end

---------------------------------------------------------------------------
-- Registration: styled now, and again on every theme change
---------------------------------------------------------------------------
function Theme.Window(frame, kind)
	windows[frame] = kind or "main"
	styleWindow(frame, windows[frame])
end

function Theme.Text(fs, role)
	if not fs then
		return
	end
	local t = texts[fs]
	if not t then
		t = { role = role, original = fs.GetFontObject and fs:GetFontObject() or nil }
		texts[fs] = t
	end
	t.role = role
	styleText(fs, t)
end

function Theme.Button(b)
	buttons[b] = true
	styleButton(b)
end

function Theme.Slot(tex)
	slots[tex] = true
	styleSlot(tex)
end

function Theme.Row(row)
	rows[row] = true
	styleRow(row)
end

local function restyleAll()
	for frame, kind in pairs(windows) do
		styleWindow(frame, kind)
	end
	for fs, t in pairs(texts) do
		styleText(fs, t)
	end
	for b in pairs(buttons) do
		styleButton(b)
	end
	for tex in pairs(slots) do
		styleSlot(tex)
	end
	for row in pairs(rows) do
		styleRow(row)
	end
end

-- Switch the look. save: also write settings.theme.name (a choice in Settings, /swagbag theme).
function Theme.Apply(id, save)
	local def = Theme.themes[id]
	if not def then
		return false, "unknown"
	end
	if not Theme.Available(id) then
		return false, "unavailable"
	end
	if save and not SB.Config.Set("theme.name", id) then
		return false, "readonly"
	end
	local ok, p = pcall(def.palette)
	if not ok or type(p) ~= "table" then
		return false, "unavailable"
	end
	palette, Theme.current = p, id
	restyleAll()
	SB.Emit("SB_THEME_CHANGED", id)
	return true
end

-- The saved look, at login. A theme that cannot be used now (its addon is not loaded) leaves the
-- Blizzard look for this session, with one line, and stays saved for when it can.
SB.On("SB_LOGIN", function()
	local id = SB.Config.Get("theme.name")
	if id == Theme.current then
		return
	end
	local ok = Theme.Apply(id, false)
	if not ok then
		Theme.Apply("blizzard", false)
		SB.Print(L.THEME_FALLBACK:format(Theme.Name(id)))
	end
end, "none")
```

Create `SwagBag/UI/Themes.lua`:

```lua
-- SwagBag's looks beyond the Blizzard default (UI/Theme.lua holds the registry and that default),
-- the /swagbag theme command and the Settings > Look page. A change applies at once, in or out of
-- combat, with no /reload, and is saved (settings.theme.name).
--   "flat"  Modern flat: dark flat panels, a black edge, white text, flat slots and buttons.
local _, SB = ...

local L = SB.L
local Theme = SB.Theme

Theme.Register({
	id = "flat",
	name = L.THEME_FLAT,
	available = function()
		return true
	end,
	palette = function()
		return {
			window = { 0.09, 0.09, 0.1, 0.92 }, dialog = { 0.09, 0.09, 0.1, 0.96 }, border = { 0, 0, 0, 1 },
			header = { 1, 1, 1, 0.03 }, row = { 1, 1, 1, 0.025 }, slot = { 0.14, 0.14, 0.15, 1 }, backdrop = Theme.BLANK,
			fonts = { title = "GameFontHighlight", header = "GameFontHighlight", label = "GameFontHighlight",
				body = "GameFontHighlightSmall", small = "GameFontHighlightSmall", row = "GameFontHighlightSmall" },
			button = { bg = { 0.16, 0.16, 0.18, 1 } },
		}
	end,
})

local function list()
	local parts = {}
	for _, id in ipairs(Theme.order) do
		local name = Theme.Name(id)
		if not Theme.Available(id) then
			name = L.THEME_NOT_LOADED:format(name)
		end
		parts[#parts + 1] = L.THEME_ITEM:format(id, name)
	end
	return table.concat(parts, ", ")
end

-- /swagbag theme              the current look and every look there is
-- /swagbag theme <id>         switch (saved); a look that cannot be used now says why
SB.Slash.Register("theme", L.HELP_THEME, function(arg)
	local id = (arg or ""):lower():match("^(%S*)")
	if id == "" then
		return L.THEME_STATE:format(Theme.Name(Theme.Current()), list())
	end
	local ok, why = Theme.Apply(id, true)
	if ok then
		return L.THEME_SET:format(Theme.Name(id))
	elseif why == "readonly" then
		return L.SETTINGS_READONLY
	elseif why == "unavailable" then
		local def = Theme.themes[id]
		return (def.unavailable or L.THEME_UNAVAILABLE):format(Theme.Name(Theme.Current()))
	end
	return L.THEME_USAGE:format(list())
end, "none")

-- Settings > Look: one choice, the Blizzard look first (the default, P1). Runs /swagbag theme (D17).
if SB.SettingsWindow then
	local function lookRows()
		local choices = {}
		for _, id in ipairs(Theme.order) do
			choices[#choices + 1] = { value = id, text = Theme.Name(id) }
		end
		return {
			{ kind = "choice", label = L.SET_LOOK, get = Theme.Current, choices = choices,
				apply = function(v)
					return SB.SettingsWindow.RunCommand("theme " .. v)
				end },
			{ kind = "note", label = L.SET_LOOK_NOTE },
		}
	end
	SB.SettingsWindow.AddPage({ id = "look", title = L.SET_PAGE_LOOK, rows = lookRows })
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/theme_spec.lua spec/bagswindow_list_spec.lua`
Expected: `0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (57 files)`, `1051 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Rules grep**

Run: `grep -n 'CreateFrame' SwagBag/UI/Theme.lua SwagBag/UI/Themes.lua; grep -rn 'IconBorder\|NormalTexture\|SetNormalTexture\|PushedTexture' SwagBag/UI`
Expected: no output from either grep. Themes make no frame and touch none of Blizzard's regions on item buttons.

- [ ] **Step 7: Commit**

```bash
git add "spec/theme_spec.lua" "spec/bagswindow_list_spec.lua" "SwagBag/UI/Theme.lua" "SwagBag/UI/Themes.lua" "SwagBag/UI/BagsWindow.lua" "SwagBag/UI/BankWindow.lua" "SwagBag/UI/GuildBankWindow.lua" "SwagBag/UI/SettingsWindow.lua" "SwagBag/UI/QuickSetup.lua" "SwagBag/UI/Footer.lua" "SwagBag/UI/ListRows.lua" "SwagBag/UI/SectionHeaders.lua" "SwagBag/UI/GroupView.lua" "SwagBag/UI/Buttons.lua" "SwagBag/Core/Adapter.lua" "SwagBag/Core/Config.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 4: theme registry (Blizzard look unchanged, Modern flat), live switch, /swagbag theme, Settings > Look

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 5: Matches ElvUI (auto-detected through the Adapter; D26) and the report's Look line

`Adapter.ElvUIMedia()` reads ElvUI's public globals inside a `pcall`: the font, the flat texture, the border, backdrop and fade colours, and the font size. It returns nil without ElvUI or with anything unexpected. The `elvui` theme is available only while that returns a table. It reads the media again on every switch, so a changed ElvUI profile shows after the next `/swagbag theme elvui`. Its palette uses ElvUI's texture for the backdrop, its colours for windows, headers, rows, slots and flat buttons, and one font file sized by role and outlined. `/swagbag report` gains `Look: <current> (setting <saved>)` (D28).

**Files:**
- Modify: `SwagBag/Core/Adapter.lua`, `SwagBag/UI/Themes.lua`, `SwagBag/Core/Report.lua`, `SwagBag/Locale/enUS.lua`, `spec/theme_spec.lua`

**Interfaces:**
- Consumes: Task 4's `Theme.Register/Apply`, the `{ file, size, flags }` font form, and `def.unavailable` (the refusal text).
- Produces: `SB.Adapter.ElvUIMedia() -> { font, size, blank, border, backdrop, fade } | nil` (colours as `{ r, g, b, a }`); the theme id `"elvui"`; `L.THEME_ELVUI`, `L.THEME_NO_ELVUI`, `L.REPORT_LOOK`.

- [ ] **Step 1: Write the failing tests**

In `spec/theme_spec.lua`, find:

```lua
		assert.same({ 1, 1, 1, 0.03 }, again.bg.calls.SetColorTexture, "a reacquired header loses the tint")
	end)
end)
```

and replace it with:

```lua
		assert.same({ 1, 1, 1, 0.03 }, again.bg.calls.SetColorTexture, "a reacquired header loses the tint")
	end)
end)

describe("Themes: Matches ElvUI", function()
	local SB, A, T, SW, media
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		A.FontObject = function(name) return { fontObject = name } end
		media = { font = "Fonts\\Elv.ttf", size = 12, blank = "Interface\\ElvBlank", border = { 0, 0, 0, 1 },
			backdrop = { 0.1, 0.1, 0.1, 1 }, fade = { 0.05, 0.05, 0.05, 0.8 } }
		A.ElvUIMedia = function() return media end
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		T = SB.Theme
		SB.BagsWindow = { View = function() return "sections" end }
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		SW = SB.SettingsWindow
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- Mutation: in the elvui palette, use m.border for the window background.
	it("uses ElvUI's texture, colours and font, sized by role, outlined", function()
		local w, fs, slot = Fake.New("Frame"), Fake.New("FontString"), Fake.New("Texture")
		T.Window(w, "main")
		T.Text(fs, "title")
		T.Slot(slot)
		assert.truthy(T.Apply("elvui", true))
		assert.same({ { bgFile = "Interface\\ElvBlank", edgeFile = "Interface\\ElvBlank", edgeSize = 1 } }, w.calls.SetBackdrop)
		assert.same({ 0.05, 0.05, 0.05, 0.8 }, w.calls.SetBackdropColor)
		assert.same({ 0, 0, 0, 1 }, w.calls.SetBackdropBorderColor)
		assert.same({ "Fonts\\Elv.ttf", 13, "OUTLINE" }, fs.calls.SetFont, "title: one point larger")
		assert.same({ 0.1, 0.1, 0.1, 1 }, slot.calls.SetColorTexture)
		assert.same({ 0.1, 0.1, 0.1, 0.6 }, { T.HeaderColor() })
	end)

	it("reads ElvUI's media again on every switch (a profile change shows after the next /swagbag theme elvui)", function()
		local w = Fake.New("Frame")
		T.Window(w, "main")
		T.Apply("elvui", false)
		media.fade = { 0.2, 0.2, 0.3, 0.7 }
		SB.Slash.Dispatch("theme elvui")
		assert.same({ 0.2, 0.2, 0.3, 0.7 }, w.calls.SetBackdropColor)
	end)

	-- Mutation: make the elvui theme's available() return true.
	it("without ElvUI the choice is refused with the reason; nothing changes", function()
		media = nil
		SB.Slash.Dispatch("theme elvui")
		assert.equal("The ElvUI look needs ElvUI, which is not loaded. The look stays Blizzard.", A.Lines()[1])
		assert.equal("blizzard", T.Current())
		assert.equal("blizzard", SB.Config.Get("theme.name"))
		SW.Show("look")
		Fake.Fire(SW.buttons[3], "OnClick")
		assert.equal("The ElvUI look needs ElvUI, which is not loaded. The look stays Blizzard.", SW.lastStatus)
		assert.truthy(SW.selected[SW.buttons[1]], "Blizzard stays selected")
	end)

	it("a saved ElvUI look while ElvUI is not loaded shows Blizzard's at login, says so, and stays saved", function()
		SB.Config.Set("theme.name", "elvui")
		media = nil
		SB.Emit("SB_LOGIN")
		assert.equal("blizzard", T.Current())
		assert.same({ SB.L.THEME_FALLBACK:format("Matches ElvUI") }, A.Lines())
		assert.equal("elvui", SB.Config.Get("theme.name"))
	end)

	it("the report names the look and the saved setting", function()
		Loader.LoadFile(SB, "SwagBag/Core/Checks.lua")
		Loader.LoadFile(SB, "SwagBag/Core/Report.lua")
		T.Apply("elvui", true)
		assert.truthy(SB.Report.Build():find("Look: elvui (setting elvui)", 1, true))
	end)
end)

describe("Adapter.ElvUIMedia (ElvUI's public globals, read only)", function()
	-- luacheck: globals ElvUI
	local SB
	before_each(function()
		SB = Loader.New()
	end)

	after_each(function()
		ElvUI = nil
	end)

	it("reads the font, texture, colours (r/g/b/a or [1]..[4]) and font size", function()
		ElvUI = { { media = { normFont = "F.ttf", blankTex = "Blank", bordercolor = { r = 0, g = 0, b = 0 },
			backdropcolor = { 0.1, 0.2, 0.3, 1 }, backdropfadecolor = { r = 0.05, g = 0.05, b = 0.05, a = 0.7 } },
			db = { general = { fontSize = 11 } } } }
		assert.same({ font = "F.ttf", size = 11, blank = "Blank", border = { 0, 0, 0, 1 }, backdrop = { 0.1, 0.2, 0.3, 1 },
			fade = { 0.05, 0.05, 0.05, 0.7 } }, SB.Adapter.ElvUIMedia())
	end)

	it("is nil without ElvUI, with odd media, and never errors", function()
		assert.is_nil(SB.Adapter.ElvUIMedia())
		ElvUI = { { media = { normFont = 3 } } }
		assert.is_nil(SB.Adapter.ElvUIMedia())
		ElvUI = setmetatable({}, { __index = function() error("boom") end })
		assert.is_nil(SB.Adapter.ElvUIMedia())
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1051 passed, 7 failed`. These are the seven new tests in `spec/theme_spec.lua` ("Themes: Matches ElvUI" and "Adapter.ElvUIMedia …"), with messages such as `attempt to call field 'ElvUIMedia' (a nil value)`.

Critical tests and their mutations:

| Test | Mutation (in `SwagBag/UI/Themes.lua`) |
|---|---|
| "uses ElvUI's texture, colours and font, sized by role, outlined" | the elvui palette's `window = m.border` |
| "without ElvUI the choice is refused with the reason; nothing changes" | the elvui theme's `available` returns `true` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Adapter.lua`, find:

```lua
-- "bank" (character bank) | "warband" | nil: the bank type Blizzard's bank frame has
```

and replace it with:

```lua
-- ElvUI's look, for the "Matches ElvUI" theme (UI/Themes.lua), or nil while ElvUI is not loaded.
-- Read only, from ElvUI's public globals: ElvUI[1] is its engine; engine.media.normFont (font
-- file), .blankTex (flat texture), .bordercolor, .backdropcolor, .backdropfadecolor (colours with
-- r, g, b, a, also at [1]..[4]); engine.db.general.fontSize. Read again on every theme change.
-- Returns { font, size, blank, border, backdrop, fade } (colours as { r, g, b, a }).
local function elvColour(c, alpha)
	if type(c) ~= "table" then
		return nil
	end
	local r, g, b, a = c.r or c[1], c.g or c[2], c.b or c[3], c.a or c[4]
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	return { r, g, b, type(a) == "number" and a or alpha or 1 }
end

function A.ElvUIMedia()
	local ok, out = pcall(function()
		local elv = _G.ElvUI
		local engine = type(elv) == "table" and elv[1]
		local media = type(engine) == "table" and engine.media
		if type(media) ~= "table" or type(media.normFont) ~= "string" or type(media.blankTex) ~= "string" then
			return nil
		end
		local general = type(engine.db) == "table" and engine.db.general
		local size = type(general) == "table" and tonumber(general.fontSize) or 12
		local border, backdrop = elvColour(media.bordercolor), elvColour(media.backdropcolor)
		local fade = elvColour(media.backdropfadecolor, 0.8)
		if not (border and backdrop and fade) then
			return nil
		end
		return { font = media.normFont, size = size, blank = media.blankTex, border = border, backdrop = backdrop,
			fade = fade }
	end)
	return ok and out or nil
end

-- "bank" (character bank) | "warband" | nil: the bank type Blizzard's bank frame has
```

In `SwagBag/Core/Report.lua`, find:

```lua
	local guild = SB.GuildBankWindow
	if guild then
```

and replace it with:

```lua
	if SB.Theme and SB.Config.db then
		lines[#lines + 1] = L.REPORT_LOOK:format(SB.Theme.Current(), tostring(SB.Config.Get("theme.name")))
	end
	local guild = SB.GuildBankWindow
	if guild then
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.THEME_NOT_LOADED = "%s, not available now"
```

and replace it with:

```lua
L.THEME_ELVUI = "Matches ElvUI"
L.THEME_NO_ELVUI = "The ElvUI look needs ElvUI, which is not loaded. The look stays %s."
L.REPORT_LOOK = "Look: %s (setting %s)"
L.THEME_NOT_LOADED = "%s, not available now"
```

In `SwagBag/UI/Themes.lua`, find (edit 1 of 2):

```lua
--   "flat"  Modern flat: dark flat panels, a black edge, white text, flat slots and buttons.
```

and replace it with:

```lua
--   "flat"   Modern flat: dark flat panels, a black edge, white text, flat slots and buttons.
--   "elvui"  Matches ElvUI: ElvUI's font, flat texture and colours, read from ElvUI itself through
--            Adapter.ElvUIMedia each time it is applied. Only while ElvUI is loaded; otherwise the
--            choice is refused with the reason, and a saved "elvui" shows the Blizzard look.
```

In `SwagBag/UI/Themes.lua`, find (edit 2 of 2):

```lua
			button = { bg = { 0.16, 0.16, 0.18, 1 } },
```

and replace it with:

```lua
			button = { bg = { 0.16, 0.16, 0.18, 1 } },
		}
	end,
})

Theme.Register({
	id = "elvui",
	name = L.THEME_ELVUI,
	unavailable = L.THEME_NO_ELVUI,
	available = function()
		return SB.Adapter.ElvUIMedia() ~= nil
	end,
	palette = function()
		local m = SB.Adapter.ElvUIMedia()
		local f, d = m.fade, m.backdrop
		return {
			window = { f[1], f[2], f[3], f[4] }, dialog = { f[1], f[2], f[3], math.max(f[4], 0.9) }, border = m.border,
			header = { d[1], d[2], d[3], 0.6 }, row = { d[1], d[2], d[3], 0.25 }, slot = { d[1], d[2], d[3], 1 },
			backdrop = m.blank, fonts = { file = m.font, size = m.size, flags = "OUTLINE" },
			button = { bg = { d[1], d[2], d[3], 1 } },
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/theme_spec.lua`
Expected: `19 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (57 files)`, `1058 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: In-game session TH1** (see "In-game sessions"; Claude installs the build first; full restart, because Task 4 added files).

- [ ] **Step 7: Commit**

```bash
git add "spec/theme_spec.lua" "SwagBag/Core/Adapter.lua" "SwagBag/UI/Themes.lua" "SwagBag/Core/Report.lua" "SwagBag/Locale/enUS.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 5: Matches ElvUI theme (ElvUI media through the Adapter, refused without ElvUI), Look line in the report

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 6: `Engine/AltData.lua`: providers, the built-in "Own", and the count index (spec §3.3; D10, D13–D15, D20)

Pure Lua over the Adapter and `Engine/Snapshots.lua`. The provider registry works like `Engine/Prices.lua`, with one difference: per call, the best available provider that **answers** wins, and three errors switch a provider off (D10). `AltData.Canon` gives one key spelling for both providers (D13), and `AltData.ItemID` reads item, keystone and battle-pet links (D15).

The built-in "Own" provider:
- lists SwagBag's saved characters, the current one first;
- decodes any saved container: bags, bank, the warband bank, and the guild bank of the character's guild (D20);
- counts an item everywhere: alts and banks from a per-container index that is rebuilt only for a container saved again (D14), this character's bags live.

`Engine/Snapshots.lua` saves each character's guild key and emits `SB_SNAPSHOT_SAVED(kind, owner)` after every write. No UI yet.

**Files:**
- Create: `SwagBag/Engine/AltData.lua`, `spec/altdata_spec.lua`
- Modify: `SwagBag/Engine/Snapshots.lua`, `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`

**Interfaces:**
- Consumes: `SB.Snapshots.DB/Deserialize`, `SB.Inventory.Iterate("bags")`, `SB.Adapter.CharKey/GuildKey`, `SB.ErrorTrap.OnError`.
- Produces:
  - `SB.AltData.RegisterProvider(p)` with p = `{ name, priority, available(), characters(), counts(itemID), container(key, kind) }`;
  - `AltData.Characters() -> list, source`, each entry `{ key, name, realm, class, level, lastSeen, guild, current }`;
  - `AltData.Counts(itemID) -> { chars = { { key, name, class, current, bags, bank, mail?, equipped?, auctions?, void? } }, warband, guilds = { { key, name, count } } }, source`;
  - `AltData.Container(key, kind) -> { at, title?, names?, containers = { [id] = { size, slots = { [slot] = { link, count } } } } }, source` for kind `"bags" | "bank" | "warband" | "guild"`;
  - `AltData.Source()`, `AltData.Canon(key)`, `AltData.ItemID(link)`, `AltData.Index()`, `AltData.Own`, `AltData.PET_CAGE`, `AltData.KINDS`;
  - the event `SB_SNAPSHOT_SAVED(kind, owner)` (owner: the raw character key for `"bags"`/`"bank"`, the guild key for `"guild"`, nil for `"warband"`);
  - `SwagBagDB.chars[key].guild`;
  - `L.ALTDATA_PROVIDER_OFF`.

- [ ] **Step 1: Write the failing tests**

Create `spec/altdata_spec.lua`:

```lua
-- Alt data (Engine/AltData.lua, spec 3.3, F13): providers by priority, the built-in "Own" over
-- SwagBag's snapshots, live bags for the current character, per-container count index.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Snapshots.lua",
	"SwagBag/Engine/AltData.lua",
}

describe("AltData", function()
	local SB, A, AD, Snap
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- this character's bags: potion x5, flask x2, ring, helm, keystone, junk x3
		SB.Inventory.ScanAll()
		AD, Snap = SB.AltData, SB.Snapshots
	end)

	-- An alt saved with the given bags and bank lines ("slot:link;count\n").
	local function alt(key, bags, bank, extra)
		local c = extra or {}
		c.class, c.level, c.lastSeen = c.class or "PRIEST", 80, A.Time() - 3600
		c.bags = bags and { v = 1, at = A.Time() - 3600, containers = { [0] = { size = 16, s = bags } } } or nil
		c.bank = bank and { v = 1, at = A.Time() - 7200, containers = { [6] = { size = 98, s = bank } } } or nil
		Snap.DB().chars[key] = c
		return c
	end

	it("Canon removes spaces and hyphens from the realm, as Syndicator writes it", function()
		assert.equal("Swagger-ArgentDawn", AD.Canon("Swagger-Argent Dawn"))
		assert.equal("Alt-AzjolNerub", AD.Canon("Alt-Azjol-Nerub"))
		assert.equal("Alt-ArgentDawn", AD.Canon("Alt-ArgentDawn"))
	end)

	it("ItemID reads item, keystone and battle pet links", function()
		assert.equal(211880, AD.ItemID("|cffffffff|Hitem:211880::::::::80:::::|h[Potion]|h|r"))
		assert.equal(180653, AD.ItemID("|cffa335ee|Hkeystone:180653:503:12:10:9:0:0|h[Keystone]|h|r"))
		assert.equal(82800, AD.ItemID("|cff0070dd|Hbattlepet:1234:25:3:1400:250:250:0|h[Pet]|h|r"))
		assert.is_nil(AD.ItemID(nil))
	end)

	it("Own lists saved characters with canonical keys, the current one first, then by name", function()
		Snap.Save("bags")
		alt("Zed-Argent Dawn", "1:item:210796;20\n")
		alt("Abby-Argent Dawn", nil, nil, { class = "MAGE", guild = "Tidewatch-Argent Dawn" })
		local list, source = AD.Characters()
		assert.equal("Own", source)
		assert.same({ "Swagger-ArgentDawn", "Abby-ArgentDawn", "Zed-ArgentDawn" }, { list[1].key, list[2].key, list[3].key })
		assert.truthy(list[1].current)
		assert.equal("Abby", list[2].name)
		assert.equal("Argent Dawn", list[2].realm)
		assert.equal("MAGE", list[2].class)
		assert.equal("Tidewatch-Argent Dawn", list[2].guild)
	end)

	it("Own containers: bags, bank, the warband bank and the character's guild bank, decoded", function()
		alt("Abby-Argent Dawn", "1:item:210796;20\n3:item:211880;2\n", "5:item:210930;100\n",
			{ guild = "Tidewatch-Argent Dawn" })
		Snap.DB().warband = { v = 1, at = A.Time(), containers = { [12] = { size = 98, s = "2:item:156654;7\n" } } }
		Snap.DB().guilds["Tidewatch-Argent Dawn"] = { tabs = { [1] = "Mats" },
			snapshot = { v = 1, at = A.Time(), containers = { [1] = { size = 98, s = "4:item:212283;3\n" } } } }
		local bags = AD.Container("Abby-ArgentDawn", "bags")
		assert.same({ link = "item:211880", count = 2 }, bags.containers[0].slots[3])
		assert.equal(16, bags.containers[0].size)
		assert.same({ link = "item:210930", count = 100 }, AD.Container("Abby-ArgentDawn", "bank").containers[6].slots[5])
		assert.same({ link = "item:156654", count = 7 }, AD.Container("Abby-ArgentDawn", "warband").containers[12].slots[2])
		local guild = AD.Container("Abby-ArgentDawn", "guild")
		assert.equal("Tidewatch", guild.title)
		assert.equal("Mats", guild.names[1])
		assert.same({ link = "item:212283", count = 3 }, guild.containers[1].slots[4])
		assert.is_nil(AD.Container("Nobody-ArgentDawn", "bags"))
		assert.is_nil(AD.Container("Abby-ArgentDawn", "nothing"))
	end)

	-- Mutation: count the current character's bags from its snapshot instead of liveBags.
	it("Own counts: alts from their snapshots, this character's bags live, the warband bank and guilds", function()
		Snap.Save("bags") -- this character is saved too (potion x5)
		alt("Abby-Argent Dawn", "1:item:211880;20\n", "5:item:211880;100\n")
		Snap.DB().warband = { v = 1, containers = { [12] = { size = 98, s = "2:item:211880;7\n" } } }
		Snap.DB().guilds["Tidewatch-Argent Dawn"] = { snapshot = { v = 1, containers = { [1] = { size = 98,
			s = "4:item:211880;3\n" } } } }
		local c = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal(2, #c.chars)
		assert.same({ key = "Swagger-ArgentDawn", name = "Swagger", class = "MAGE", current = true, bags = 5, bank = 0 },
			c.chars[1])
		assert.same({ key = "Abby-ArgentDawn", name = "Abby", class = "PRIEST", current = false, bags = 20, bank = 100 },
			c.chars[2])
		assert.equal(7, c.warband)
		assert.same({ { key = "Tidewatch-Argent Dawn", name = "Tidewatch", count = 3 } }, c.guilds)
		A.Put(0, 1, Fixtures.HEALING_POTION, 9)
		SB.Inventory.ScanAll()
		assert.equal(9, AD.Counts(Fixtures.HEALING_POTION).chars[1].bags, "live: no snapshot needed")
	end)

	it("Own counts leave out characters without the item", function()
		alt("Abby-Argent Dawn", "1:item:210796;20\n")
		local c = AD.Counts(Fixtures.FLASK)
		assert.equal(1, #c.chars)
		assert.equal("Swagger", c.chars[1].name)
		assert.same({}, AD.Counts(999999).chars)
	end)

	-- Spec 8.4: the index is derived, per container, and rebuilt only for what was saved again.
	-- Mutation: in the SB_SNAPSHOT_SAVED listener, do nothing.
	it("the index is built once per container and dropped when that container is saved again", function()
		alt("Abby-Argent Dawn", "1:item:211880;20\n")
		AD.Counts(Fixtures.HEALING_POTION)
		assert.truthy(AD.Index()["bags:Abby-Argent Dawn"])
		assert.truthy(AD.Index()["bags:Swagger-Argent Dawn"] == nil, "this character's bags are live, not indexed")
		Snap.Save("bank") -- this character's bank was saved: only its index goes
		assert.truthy(AD.Index()["bags:Abby-Argent Dawn"])
		Snap.DB().chars["Abby-Argent Dawn"].bags.containers[0].s = "1:item:211880;50\n"
		SB.Emit("SB_SNAPSHOT_SAVED", "bags", "Abby-Argent Dawn")
		assert.equal(50, AD.Counts(Fixtures.HEALING_POTION).chars[2].bags)
	end)

	it("Snapshots remember the character's guild and announce every save", function()
		local seen = {}
		SB.On("SB_SNAPSHOT_SAVED", function(_, kind, owner) seen[#seen + 1] = kind .. ":" .. tostring(owner) end)
		Snap.Save("bags")
		Snap.SaveGuild("Tidewatch-Argent Dawn", { [1] = { name = "Mats", slots = {} } })
		assert.equal("Tidewatch-Argent Dawn", Snap.DB().chars["Swagger-Argent Dawn"].guild)
		assert.same({ "bags:Swagger-Argent Dawn", "guild:Tidewatch-Argent Dawn" }, seen)
	end)

	it("a better provider wins; one that answers nil hands the call to the next", function()
		local answer = { { key = "X-Y", name = "X" } }
		AD.RegisterProvider({ name = "Better", priority = 10, available = function() return true end,
			characters = function() return answer end, counts = function() return nil end })
		local list, source = AD.Characters()
		assert.equal(answer, list)
		assert.equal("Better", source)
		local _, countSource = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal("Own", countSource)
		assert.equal("Better", AD.Source())
	end)

	it("an unavailable provider is skipped", function()
		AD.RegisterProvider({ name = "Gone", priority = 10, available = function() return false end,
			characters = function() error("never asked") end })
		local _, source = AD.Characters()
		assert.equal("Own", source)
		assert.equal("Own", AD.Source())
	end)

	-- Spec 3.3. Mutation: in failed(), switch the provider off at the first error.
	it("a provider that throws three times is switched off with one chat line and one recorded error", function()
		AD.RegisterProvider({ name = "Broken", priority = 10, available = function() return true end,
			characters = function() error("broke") end })
		for _ = 1, 2 do
			local _, source = AD.Characters()
			assert.equal("Own", source, "the next provider answers meanwhile")
		end
		assert.same({}, A.Lines())
		AD.Characters()
		AD.Characters()
		assert.same({ SB.L.ALTDATA_PROVIDER_OFF:format("Broken") }, A.Lines())
		assert.equal("altdata:Broken", SB.ErrorTrap.Recent()[1].label)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("Counts of a non-number is nil (a tooltip with no item ID)", function()
		assert.is_nil(AD.Counts(nil))
	end)

	-- Review Focus 4 (many alts, a tooltip on every hover). Mutation: in mapOf, never store the map.
	it("25 saved characters: the first count builds the index in under 50 ms; then a count takes under 1 ms", function()
		local lines = {}
		for slot = 1, 98 do
			lines[#lines + 1] = slot .. ":item:" .. (200000 + slot) .. ";" .. slot .. "\n"
		end
		local s = table.concat(lines)
		for i = 1, 25 do
			alt("Alt" .. i .. "-Argent Dawn", s, s)
		end
		local t0 = os.clock()
		AD.Counts(200001)
		local first = (os.clock() - t0) * 1000
		assert.truthy(first < 50, ("first count took %.1f ms"):format(first))
		t0 = os.clock()
		for id = 200001, 200098 do
			AD.Counts(id)
		end
		local each = (os.clock() - t0) * 1000 / 98
		assert.truthy(each < 1, ("a count took %.2f ms"):format(each))
		assert.equal(25, #AD.Counts(200050).chars)
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1058 passed, 13 failed`. These are the 13 tests of `spec/altdata_spec.lua`, each with `cannot open SwagBag/Engine/AltData.lua: No such file or directory`.

Critical tests and their mutations (in `SwagBag/Engine/AltData.lua`):

| Test | Mutation |
|---|---|
| "Own counts: alts from their snapshots, this character's bags live, the warband bank and guilds" | in `own.counts`, `local bags = mapOf("bags:" .. raw, c.bags)[itemID] or 0` (no live bags) |
| "the index is built once per container and dropped when that container is saved again" | empty the `SB_SNAPSHOT_SAVED` listener |
| "a provider that throws three times is switched off with one chat line and one recorded error" | in `failed`, `if not AD.off[p.name] then` (off at the first error) |
| "25 saved characters: the first count builds the index in under 50 ms; then a count takes under 1 ms" | in `mapOf`, never store the map in `index` |

- [ ] **Step 3: Write the implementation**

Create `SwagBag/Engine/AltData.lua`:

```lua
-- SwagBag alt data (spec 3.2, 3.3, F13): which characters have an item, and what a saved character
-- holds, through providers. Pure Lua over the Adapter and SwagBag's own snapshots. Per call, the
-- available provider with the highest priority that answers wins (ties: name order); one that
-- answers nil hands the call to the next. A provider that throws three times in a session is
-- switched off with one chat line and one error-ring entry; the others carry on (spec 3.3).
-- Built in: "Own" (priority 0) over Engine/Snapshots.lua. Providers/Syndicator.lua adds
-- "Syndicator" (priority 10) while Syndicator is loaded and ready.
--   AltData.RegisterProvider(p)   p = { name, priority, available() -> bool,
--       characters() -> list | nil, counts(itemID) -> counts | nil, container(key, kind) -> c | nil }
--   AltData.Characters() -> list, source   { { key, name, realm, class, level, lastSeen, guild, current } },
--       the current character first, then by name. key is canonical (AltData.Canon)
--   AltData.Counts(itemID) -> counts, source   { chars = { { key, name, class, current, bags, bank, mail,
--       equipped, auctions } }, warband = n, guilds = { { key, name, count } } }: only non-zero counts
--   AltData.Container(key, kind) -> c, source   kind "bags" | "bank" | "warband" | "guild":
--       { at = epoch | nil, title = text | nil, containers = { [bag or guild tab] = { size, slots =
--       { [slot] = { link, count } } } } }, or nil when nothing is saved
--   AltData.Source() -> name   the provider that answers first now
--   AltData.Canon(key) -> "Name-Realm" with the realm's spaces and hyphens removed (the form
--       Syndicator uses), so both providers name a character the same way
--   AltData.ItemID(link) -> itemID | nil   from an item, keystone or battle pet link (pure)
-- Own counts: an index (itemID -> count) per saved container, built the first time it is asked
-- and dropped when that container is saved again (SB_SNAPSHOT_SAVED), never stored (spec 8.4).
-- The current character's bags are counted live (Engine/Inventory.lua), so a tooltip is never
-- 5 s behind the bag.
local _, SB = ...

local AD = { providers = {}, errors = {}, off = {}, MAX_ERRORS = 3, PET_CAGE = 82800,
	KINDS = { "bags", "bank", "warband", "guild" } }
SB.AltData = AD

function AD.Canon(key)
	if type(key) ~= "string" then
		return nil
	end
	local name, realm = key:match("^([^%-]+)%-(.+)$")
	if not name then
		return key
	end
	return name .. "-" .. (realm:gsub("[%s%-]", ""))
end

function AD.ItemID(link)
	if type(link) ~= "string" then
		return nil
	end
	local id = link:match("item:(%d+)") or link:match("keystone:(%d+)")
	if id then
		return tonumber(id)
	end
	if link:find("battlepet:", 1, true) then
		return AD.PET_CAGE
	end
	return nil
end

---------------------------------------------------------------------------
-- Providers
---------------------------------------------------------------------------
function AD.RegisterProvider(p)
	AD.providers[#AD.providers + 1] = p
end

local function byPriority(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end
	return a.name < b.name
end

-- The available providers, best first. Asked on every call: Syndicator becomes ready after login.
local function active()
	local list = {}
	for _, p in ipairs(AD.providers) do
		if not AD.off[p.name] then
			local ok, yes = pcall(p.available)
			if ok and yes then
				list[#list + 1] = p
			end
		end
	end
	table.sort(list, byPriority)
	return list
end

function AD.Source()
	local first = active()[1]
	return first and first.name or nil
end

local function failed(p, message)
	AD.errors[p.name] = (AD.errors[p.name] or 0) + 1
	if AD.errors[p.name] >= AD.MAX_ERRORS and not AD.off[p.name] then
		AD.off[p.name] = true
		pcall(SB.ErrorTrap.OnError, "altdata:" .. p.name, "none", tostring(message), "")
		SB.Print(SB.L.ALTDATA_PROVIDER_OFF:format(p.name))
	end
end

local function call(method, ...)
	for _, p in ipairs(active()) do
		if p[method] then
			local ok, v = pcall(p[method], ...)
			if not ok then
				failed(p, v)
			elseif v ~= nil then
				return v, p.name
			end
		end
	end
	return nil, nil
end

function AD.Characters()
	return call("characters")
end

function AD.Counts(itemID)
	if type(itemID) ~= "number" then
		return nil, nil
	end
	return call("counts", itemID)
end

function AD.Container(key, kind)
	return call("container", key, kind)
end

---------------------------------------------------------------------------
-- The built-in provider "Own": SwagBag's snapshots (Engine/Snapshots.lua)
---------------------------------------------------------------------------
local index = {} -- [source] = { [itemID] = count }; source = "bags:<raw key>", "bank:<raw key>", "warband", "guild:<guild key>"

local function countMap(snap)
	local map = {}
	if type(snap) == "table" and type(snap.containers) == "table" then
		for _, c in pairs(snap.containers) do
			for _, s in pairs(SB.Snapshots.Deserialize(c)) do
				local id = AD.ItemID(s.link)
				if id then
					map[id] = (map[id] or 0) + (s.count or 1)
				end
			end
		end
	end
	return map
end

local function mapOf(source, snap)
	local map = index[source]
	if not map then
		map = countMap(snap)
		index[source] = map
	end
	return map
end
-- The Own index as it is now (tests and /swagbag report).
function AD.Index()
	return index
end

-- The bags of the character playing now, read live.
local function liveBags(itemID)
	local n = 0
	for _, _, s in SB.Inventory.Iterate("bags") do
		if s and s.itemID == itemID then
			n = n + (s.count or 1)
		end
	end
	return n
end

local function splitKey(raw)
	local name, realm = raw:match("^([^%-]+)%-(.+)$")
	return name or raw, realm
end

local function guildName(guildKey)
	return type(guildKey) == "string" and (guildKey:match("^(.-)%-[^%-]*$") or guildKey) or nil
end

-- The saved character whose canonical key is key: its raw key and its table.
local function charOf(key)
	for raw, c in pairs(SB.Snapshots.DB().chars) do
		if type(c) == "table" and AD.Canon(raw) == key then
			return raw, c
		end
	end
	return nil, nil
end

local function decode(snap, title)
	if type(snap) ~= "table" or type(snap.containers) ~= "table" then
		return nil
	end
	local out = { at = snap.at, title = title, containers = {} }
	for bag, c in pairs(snap.containers) do
		if type(c) == "table" then
			out.containers[bag] = { size = tonumber(c.size) or 0, slots = SB.Snapshots.Deserialize(c) }
		end
	end
	return out
end

local own = { name = "Own", priority = 0 }

function own.available()
	return SB.Config.db ~= nil
end

function own.characters()
	local me, list = SB.Adapter.CharKey(), {}
	for raw, c in pairs(SB.Snapshots.DB().chars) do
		if type(c) == "table" then
			local name, realm = splitKey(raw)
			list[#list + 1] = { key = AD.Canon(raw), name = name, realm = realm, class = c.class, level = c.level,
				lastSeen = c.lastSeen, guild = c.guild, current = raw == me }
		end
	end
	table.sort(list, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		return a.key < b.key
	end)
	return list
end

function own.container(key, kind)
	local db = SB.Snapshots.DB()
	if kind == "warband" then
		return decode(db.warband)
	end
	local _, c = charOf(key)
	if not c then
		return nil
	end
	if kind == "guild" then
		local g = c.guild and db.guilds[c.guild]
		local out = type(g) == "table" and decode(g.snapshot, guildName(c.guild)) or nil
		if out then
			out.names = type(g.tabs) == "table" and g.tabs or {}
		end
		return out
	end
	return decode(c[kind])
end

function own.counts(itemID)
	local db, me = SB.Snapshots.DB(), SB.Adapter.CharKey()
	local out = { chars = {}, warband = 0, guilds = {} }
	for raw, c in pairs(db.chars) do
		if type(c) == "table" then
			local bags = raw == me and liveBags(itemID) or (mapOf("bags:" .. raw, c.bags)[itemID] or 0)
			local bank = mapOf("bank:" .. raw, c.bank)[itemID] or 0
			if bags > 0 or bank > 0 then
				local name = splitKey(raw)
				out.chars[#out.chars + 1] = { key = AD.Canon(raw), name = name, class = c.class, current = raw == me,
					bags = bags, bank = bank }
			end
		end
	end
	if not db.chars[me] then -- not saved yet (the first minutes of a new character)
		local bags = liveBags(itemID)
		if bags > 0 then
			out.chars[#out.chars + 1] = { key = AD.Canon(me), name = splitKey(me), current = true, bags = bags, bank = 0 }
		end
	end
	out.warband = mapOf("warband", db.warband)[itemID] or 0
	for gk, g in pairs(db.guilds) do
		if type(g) == "table" then
			local n = mapOf("guild:" .. gk, g.snapshot)[itemID] or 0
			if n > 0 then
				out.guilds[#out.guilds + 1] = { key = gk, name = guildName(gk), count = n }
			end
		end
	end
	table.sort(out.chars, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		return a.key < b.key
	end)
	table.sort(out.guilds, function(a, b)
		return a.key < b.key
	end)
	return out
end

AD.RegisterProvider(own)
AD.Own = own

-- A container was saved again (Engine/Snapshots.lua): its index is rebuilt when next asked.
-- owner: the raw character key ("bags", "bank"), the guild key ("guild"), nil ("warband").
SB.On("SB_SNAPSHOT_SAVED", function(_, kind, owner)
	if kind == "warband" then
		index.warband = nil
	elseif owner then
		index[kind .. ":" .. owner] = nil
	end
end, "none")

-- New or reset settings: every index goes.
SB.On("SB_CONFIG_CHANGED", function(_, path)
	if path == nil then
		index = {}
	end
end, "none")
```

In `SwagBag/Engine/Snapshots.lua`, find (edit 1 of 4):

```lua
-- Where they live (spec 8.2): SwagBagDB.chars["Name-Realm"] = { class, level, lastSeen, bags,
-- bank }, SwagBagDB.warband (one for the account), SwagBagDB.guilds["Guild-Realm"] =
-- { lastSeen, tabs = { [tab] = name }, snapshot }.
```

and replace it with:

```lua
-- Where they live (spec 8.2): SwagBagDB.chars["Name-Realm"] = { class, level, lastSeen, guild,
-- bags, bank }, SwagBagDB.warband (one for the account), SwagBagDB.guilds["Guild-Realm"] =
-- { lastSeen, tabs = { [tab] = name }, snapshot }. guild: the character's guild key when last seen
-- (week 5: the alt viewer shows that guild's bank with the character). Every write emits
-- SB_SNAPSHOT_SAVED(kind, owner) (owner: the character key, the guild key, nil for the warband
-- bank), so Engine/AltData.lua rebuilds only that container's counts.
```

In `SwagBag/Engine/Snapshots.lua`, find (edit 2 of 4):

```lua
	c.class, c.level, c.lastSeen = info.class, info.level, A.Time()
```

and replace it with:

```lua
	c.class, c.level, c.lastSeen, c.guild = info.class, info.level, A.Time(), A.GuildKey()
```

In `SwagBag/Engine/Snapshots.lua`, find (edit 3 of 4):

```lua
	if kind == "warband" then
		Snap.DB().warband = snap
	else
		local c = Snap.Char()
		c[kind] = snap
	end
	Snap.Enforce()
```

and replace it with:

```lua
	local owner
	if kind == "warband" then
		Snap.DB().warband = snap
	else
		local c, key = Snap.Char()
		c[kind] = snap
		owner = key
	end
	Snap.Enforce()
	SB.Emit("SB_SNAPSHOT_SAVED", kind, owner)
```

In `SwagBag/Engine/Snapshots.lua`, find (edit 4 of 4):

```lua
end

-- tabs[tab] = { name, slots = { [slot] = { link, count } } } for the tabs read this visit.
```

and replace it with:

```lua
	SB.Emit("SB_SNAPSHOT_SAVED", "guild", guildKey)
end

-- tabs[tab] = { name, slots = { [slot] = { link, count } } } for the tabs read this visit.
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
-- Themes (week 5): the look of SwagBag's own windows
```

and replace it with:

```lua
-- Alt data (week 5): other characters' items
L.ALTDATA_PROVIDER_OFF = "The %s alt data stopped working this session; SwagBag uses its own saved data instead."

-- Themes (week 5): the look of SwagBag's own windows
```

In `SwagBag/SwagBag.toc`, find:

```text
Engine/Prices.lua
Engine/OverlayData.lua
Engine/Sort.lua
```

and replace it with:

```text
Engine/AltData.lua
Engine/Prices.lua
Engine/OverlayData.lua
Engine/Sort.lua
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/altdata_spec.lua spec/snapshots_spec.lua`
Expected: `0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (58 files)`, `1071 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Commit**

```bash
git add "spec/altdata_spec.lua" "SwagBag/Engine/AltData.lua" "SwagBag/Engine/Snapshots.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 6: AltData (providers by priority, built-in Own over snapshots, per-container count index)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 7: The Syndicator provider (spec §3.3, v1.2; D11, D12) and the week-4 `CurrencyList` guard

`Core/Adapter.lua`:
- `SyndicatorAPI()` returns Syndicator's API table only when it has every function SwagBag reads and `IsReady()` says yes (P4);
- `SyndicatorOnUpdate(cb)` registers on Syndicator's callback registry for four events.

`Providers/Syndicator.lua` (priority 10):
- maps Syndicator's characters (hidden ones left out), bags, bank tabs and warband tabs to AltData's shapes;
- maps the counts, with mail, worn, auctions and void;
- answers nil for the guild bank and for anything it does not have, so "Own" answers (D11);
- turns Syndicator's update callbacks into one debounced `SB_ALTDATA_CHANGED`, trapped as `"none"`.

`/swagbag report` gains `Alt data: <source>, <n> characters` (D28). The week-4 deferred guard: `Adapter.CurrencyList` skips a currency line whose header flag is a secret value.

**Files:**
- Create: `SwagBag/Providers/Syndicator.lua`, `spec/syndicator_spec.lua`
- Modify: `SwagBag/Core/Adapter.lua`, `SwagBag/Core/Report.lua`, `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`

**Interfaces:**
- Consumes: Task 6's `AltData.RegisterProvider`, `AltData.Canon`; `SB.Adapter.Resolve`, `SB.Adapter.CharKey`.
- Produces:
  - `SB.Adapter.SyndicatorAPI() -> api | nil`, `SB.Adapter.SyndicatorOnUpdate(cb) -> bool`, `SB.Adapter.SYNDICATOR_EVENTS`;
  - `SB.SyndicatorProvider` (`.available/.characters/.container/.counts`, priority 10);
  - the event `SB_ALTDATA_CHANGED(source)`;
  - `L.REPORT_ALTDATA`.

- [ ] **Step 1: Write the failing tests**

Create `spec/syndicator_spec.lua`:

```lua
-- luacheck: globals Syndicator C_CurrencyInfo issecretvalue
-- The Syndicator alt data provider (Providers/Syndicator.lua, spec 3.3): used only while Syndicator
-- is loaded and ready; replaces Own for characters, containers and counts, adds mail/equipped/auction
-- counts; guild banks stay SwagBag's own; errors switch it off and Own carries on.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Snapshots.lua",
	"SwagBag/Engine/AltData.lua", "SwagBag/Providers/Syndicator.lua",
}

-- A stand-in for Syndicator's public API (names only, as the provider reads them).
local function fakeSyndicator()
	local chars = {
		["Swagger-ArgentDawn"] = { details = { character = "Swagger", realm = "Argent Dawn", realmNormalized = "ArgentDawn",
			className = "MAGE", show = { inventory = true } },
			bags = { { [1] = { itemID = 211880, itemCount = 5, itemLink = "item:211880" }, [2] = {} } }, bankTabs = {} },
		["Abby-ArgentDawn"] = { details = { character = "Abby", realm = "Argent Dawn", realmNormalized = "ArgentDawn",
			className = "PRIEST", show = { inventory = true } },
			bags = { { [1] = { itemLink = "item:210796", itemCount = 20 }, [2] = {} }, {}, {}, {}, {}, {} },
			bankTabs = { { slots = { [1] = {}, [2] = { itemLink = "item:210930", itemCount = 100 } } } } },
		["Hidden-ArgentDawn"] = { details = { character = "Hidden", className = "ROGUE", show = { inventory = false } },
			bags = {} },
	}
	local api = { ready = true, calls = 0 }
	function api.IsReady() return api.ready end
	function api.GetAllCharacters()
		local keys = {}
		for k in pairs(chars) do
			keys[#keys + 1] = k
		end
		table.sort(keys)
		return keys
	end
	function api.GetByCharacterFullName(k) return chars[k] end
	function api.GetWarband() return { bank = { { slots = { [3] = { itemLink = "item:156654", itemCount = 7 } } } } } end
	function api.GetInventoryInfoByItemID(id)
		api.calls = api.calls + 1
		if api.broken then
			error("syndicator broke")
		end
		if id ~= 211880 then
			return nil
		end
		return { characters = {
			{ character = "Swagger", realmNormalized = "ArgentDawn", className = "MAGE", bags = 5, bank = 0, mail = 0,
				equipped = 0, auctions = 0, void = 0 },
			{ character = "Abby", realmNormalized = "ArgentDawn", className = "PRIEST", bags = 20, bank = 0, mail = 2,
				equipped = 0, auctions = 1, void = 0 },
			{ character = "Empty", realmNormalized = "ArgentDawn", bags = 0, bank = 0 },
		}, guilds = { { guild = "Tidewatch", realmNormalized = "ArgentDawn", bank = 3 } }, warband = { 7 } }
	end
	local reg = { events = {} }
	function reg:RegisterCallback(event, fn, owner)
		self.events[event] = function(...) return fn(owner, ...) end
	end
	return api, reg
end

describe("Syndicator provider", function()
	local SB, A, AD, api, reg
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		SB.Inventory.ScanAll()
		AD = SB.AltData
		api, reg = fakeSyndicator()
		A.globals.Syndicator = { API = api, CallbackRegistry = reg }
	end)

	-- P4. Mutation: in Adapter.SyndicatorAPI, skip the IsReady check.
	it("answers only while Syndicator is loaded, complete and ready; Own answers otherwise", function()
		assert.equal("Syndicator", AD.Source())
		api.ready = false
		assert.equal("Own", AD.Source())
		api.ready = true
		api.GetWarband = nil
		assert.equal("Own", AD.Source(), "an API missing a function SwagBag reads is not used")
		A.globals.Syndicator = nil
		assert.equal("Own", AD.Source())
	end)

	it("lists Syndicator's characters with canonical keys, the current one first, hidden ones left out", function()
		local list, source = AD.Characters()
		assert.equal("Syndicator", source)
		assert.equal(2, #list)
		assert.same({ key = "Swagger-ArgentDawn", name = "Swagger", realm = "Argent Dawn", class = "MAGE", current = true },
			list[1])
		assert.equal("Abby-ArgentDawn", list[2].key)
	end)

	-- Mutation: map bags[i] to bag i instead of i - 1.
	it("containers: bags[i] is bag i - 1, bank tab i is bag 5 + i, warband tab i is bag 11 + i", function()
		local bags = AD.Container("Abby-ArgentDawn", "bags")
		assert.same({ link = "item:210796", count = 20 }, bags.containers[0].slots[1])
		assert.equal(2, bags.containers[0].size)
		assert.is_nil(bags.containers[1], "an empty bag is left out")
		local bank = AD.Container("Abby-ArgentDawn", "bank")
		assert.same({ link = "item:210930", count = 100 }, bank.containers[6].slots[2])
		local warband, source = AD.Container("Abby-ArgentDawn", "warband")
		assert.equal("Syndicator", source)
		assert.same({ link = "item:156654", count = 7 }, warband.containers[12].slots[3])
	end)

	it("the guild bank, and a character Syndicator does not have, come from SwagBag's own snapshots", function()
		SB.Snapshots.DB().chars["Abby-Argent Dawn"] = { guild = "Tidewatch-Argent Dawn" }
		SB.Snapshots.DB().guilds["Tidewatch-Argent Dawn"] = { tabs = { [1] = "Mats" },
			snapshot = { v = 1, containers = { [1] = { size = 98, s = "4:item:212283;3\n" } } } }
		local guild, source = AD.Container("Abby-ArgentDawn", "guild")
		assert.equal("Own", source)
		assert.equal("Tidewatch", guild.title)
		SB.Snapshots.DB().chars["Ghost-Argent Dawn"] = { bags = { v = 1, containers = { [0] = { size = 16,
			s = "1:item:211880;1\n" } } } }
		local _, ghostSource = AD.Container("Ghost-ArgentDawn", "bags")
		assert.equal("Own", ghostSource)
	end)

	-- Mutation: drop mail from the counted fields.
	it("counts: per character with mail and auctions (what only Syndicator tracks), the warband bank and guilds", function()
		local c, source = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal("Syndicator", source)
		assert.equal(2, #c.chars, "a character with none is left out")
		assert.truthy(c.chars[1].current)
		assert.same({ key = "Abby-ArgentDawn", name = "Abby", class = "PRIEST", current = false, bags = 20, bank = 0, mail = 2,
			equipped = 0, auctions = 1, void = 0 }, c.chars[2])
		assert.equal(7, c.warband)
		assert.same({ { key = "Tidewatch-ArgentDawn", name = "Tidewatch", count = 3 } }, c.guilds)
	end)

	it("an item Syndicator knows nothing about is counted by SwagBag's own data", function()
		local c, source = AD.Counts(Fixtures.FLASK)
		assert.equal("Own", source)
		assert.equal(2, c.chars[1].bags)
	end)

	-- Spec 3.3. Mutation: in Providers/Syndicator.lua, pcall GetInventoryInfoByItemID and return nil.
	it("three errors switch Syndicator off for the session, with one line; SwagBag's own data answers", function()
		api.broken = true
		for _ = 1, 3 do
			local _, source = AD.Counts(Fixtures.HEALING_POTION)
			assert.equal("Own", source)
		end
		assert.same({ SB.L.ALTDATA_PROVIDER_OFF:format("Syndicator") }, A.Lines())
		api.broken = false
		local _, source = AD.Counts(Fixtures.HEALING_POTION)
		assert.equal("Own", source, "stays off this session")
		assert.equal(3, api.calls)
	end)

	-- Mutation: in the SB_LOGIN handler, emit without SB.Debounce.
	it("Syndicator's updates announce SB_ALTDATA_CHANGED once, after the burst, trapped as 'none'", function()
		local n = 0
		SB.On("SB_ALTDATA_CHANGED", function() n = n + 1 end)
		SB.Emit("SB_LOGIN")
		assert.truthy(reg.events.BagCacheUpdate and reg.events.WarbandBankCacheUpdate and reg.events.GuildCacheUpdate
			and reg.events.Ready)
		reg.events.BagCacheUpdate("x")
		reg.events.WarbandBankCacheUpdate()
		A.Advance(0.6)
		assert.equal(1, n)
	end)

	it("the report names the alt data source and how many characters it has", function()
		Loader.LoadFile(SB, "SwagBag/Core/Checks.lua")
		Loader.LoadFile(SB, "SwagBag/Core/Report.lua")
		assert.truthy(SB.Report.Build():find("Alt data: Syndicator, 2 characters", 1, true))
		A.globals.Syndicator = nil
		assert.truthy(SB.Report.Build():find("Alt data: Own, 0 characters", 1, true))
	end)
end)

describe("Adapter: Syndicator and currency reads (the real Adapter.lua)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		Syndicator, C_CurrencyInfo, issecretvalue = nil, nil, nil
	end)

	it("SyndicatorAPI reads only Syndicator's public names and never errors", function()
		assert.is_nil(A.SyndicatorAPI())
		local api = fakeSyndicator()
		Syndicator = { API = api }
		assert.equal(api, A.SyndicatorAPI())
		api.IsReady = function() error("not yet") end
		assert.is_nil(A.SyndicatorAPI())
	end)

	it("SyndicatorOnUpdate registers for the four events, or says there is no registry", function()
		assert.equal(false, A.SyndicatorOnUpdate(function() end))
		local _, reg = fakeSyndicator()
		Syndicator = { CallbackRegistry = reg }
		assert.equal(true, A.SyndicatorOnUpdate(function() end))
		for _, event in ipairs(A.SYNDICATOR_EVENTS) do
			assert.truthy(reg.events[event], event)
		end
	end)

	-- Week-4 deferred. Mutation: drop the isSecret(info.isHeader) check in CurrencyList.
	it("CurrencyList skips a line whose header flag is secret", function()
		issecretvalue = function(v) return v == false end -- the first row's flag reads false, but secret
		local rows = { { name = "Header", isHeader = false, quantity = 1 }, { name = "Crest", quantity = 4 } }
		C_CurrencyInfo = {
			GetCurrencyListSize = function() return #rows end,
			GetCurrencyListInfo = function(i) return rows[i] end,
			GetCurrencyListLink = function(i) return "currency:" .. i end,
			GetCurrencyIDFromLink = function(link) return tonumber(link:match("%d+")) + 3000 end,
		}
		local list = A.CurrencyList()
		assert.equal(1, #list)
		assert.equal("Crest", list[1].name)
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1071 passed, 12 failed`. These are the 12 tests of `spec/syndicator_spec.lua`: nine with `cannot open SwagBag/Providers/Syndicator.lua`, the two Adapter tests with `attempt to call field 'SyndicatorAPI'/'SyndicatorOnUpdate' (a nil value)`, and the CurrencyList test with `expected 1, got 2`.

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "answers only while Syndicator is loaded, complete and ready; Own answers otherwise" | in `Adapter.SyndicatorAPI`, return the API without checking `IsReady` |
| "containers: bags[i] is bag i - 1, bank tab i is bag 5 + i, warband tab i is bag 11 + i" | `add(i, list)` instead of `add(i - 1, list)` |
| "counts: per character with mail and auctions (what only Syndicator tracks), …" | drop `mail = n(c.mail)` from the entry |
| "Syndicator's updates announce SB_ALTDATA_CHANGED once, after the burst, trapped as 'none'" | emit without `SB.Debounce` |
| "CurrencyList skips a line whose header flag is secret" | in `Adapter.CurrencyList`, drop `not isSecret(info.isHeader) and` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Adapter.lua`, find (edit 1 of 2):

```lua
		if ok and type(info) == "table" and not info.isHeader then
```

and replace it with:

```lua
		-- a secret header flag counts as a header (skipped): its line cannot be told (week-4 deferred)
		if ok and type(info) == "table" and not isSecret(info.isHeader) and not info.isHeader then
```

In `SwagBag/Core/Adapter.lua`, find (edit 2 of 2):

```lua
-- Focus-mode signals (week 4, spec 6.2). Every read is feature-detected: a missing function
```

and replace it with:

```lua
-- Syndicator (optional alt data, spec 3.3; Providers/Syndicator.lua). Read only, through its
-- public API: Syndicator.API.IsReady, .GetAllCharacters, .GetByCharacterFullName, .GetWarband,
-- .GetInventoryInfoByItemID, and Syndicator.CallbackRegistry:RegisterCallback(event, fn, owner).
-- No Syndicator code is used; only these public names.
---------------------------------------------------------------------------
local SYNDICATOR_NEEDS = { "IsReady", "GetAllCharacters", "GetByCharacterFullName", "GetWarband",
	"GetInventoryInfoByItemID" }
A.SYNDICATOR_EVENTS = { "BagCacheUpdate", "WarbandBankCacheUpdate", "GuildCacheUpdate", "Ready" }

-- Syndicator's API table while Syndicator is loaded, has every function above and says it is
-- ready; nil otherwise (then SwagBag's own snapshots answer).
function A.SyndicatorAPI()
	local api = A.Resolve("Syndicator.API")
	if type(api) ~= "table" then
		return nil
	end
	for _, name in ipairs(SYNDICATOR_NEEDS) do
		if type(api[name]) ~= "function" then
			return nil
		end
	end
	local ok, ready = pcall(api.IsReady)
	if ok and ready == true then
		return api
	end
	return nil
end

-- cb runs when Syndicator's saved data changes (bags, warband bank, guild) or becomes ready.
-- Returns false when Syndicator has no callback registry.
function A.SyndicatorOnUpdate(cb)
	local reg = A.Resolve("Syndicator.CallbackRegistry")
	if type(reg) ~= "table" or type(reg.RegisterCallback) ~= "function" then
		return false
	end
	for _, event in ipairs(A.SYNDICATOR_EVENTS) do
		pcall(reg.RegisterCallback, reg, event, cb, A)
	end
	return true
end

---------------------------------------------------------------------------
-- Focus-mode signals (week 4, spec 6.2). Every read is feature-detected: a missing function
```

In `SwagBag/Core/Report.lua`, find:

```lua
	if SB.Theme and SB.Config.db then
		lines[#lines + 1] = L.REPORT_LOOK:format(SB.Theme.Current(), tostring(SB.Config.Get("theme.name")))
```

and replace it with:

```lua
	if SB.AltData and SB.Config.db then
		local list = SB.AltData.Characters()
		lines[#lines + 1] = L.REPORT_ALTDATA:format(tostring(SB.AltData.Source() or L.REPORT_NONE), list and #list or 0)
	end
	if SB.Theme and SB.Config.db then
		lines[#lines + 1] = L.REPORT_LOOK:format(SB.Theme.Current(), tostring(SB.Config.Get("theme.name")))
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.ALTDATA_PROVIDER_OFF = "The %s alt data stopped working this session; SwagBag uses its own saved data instead."
```

and replace it with:

```lua
L.ALTDATA_PROVIDER_OFF = "The %s alt data stopped working this session; SwagBag uses its own saved data instead."
L.REPORT_ALTDATA = "Alt data: %s, %d characters"
```

Create `SwagBag/Providers/Syndicator.lua`:

```lua
-- SwagBag alt data provider "Syndicator" (spec 3.3, v1.2 pulled forward). Optional (P4): it answers
-- only while Syndicator is loaded and ready (Adapter.SyndicatorAPI); otherwise SwagBag's own
-- snapshots ("Own", Engine/AltData.lua) answer, and nothing else changes. While it answers it
-- REPLACES Own for the character list, every character's bags and bank, the warband bank and the
-- tooltip counts (Syndicator also knows characters SwagBag never saw), and ADDS what only
-- Syndicator tracks: mail, equipped, auctions and void storage counts. Guild banks stay SwagBag's
-- own (container "guild" answers nil here, so Own answers). SwagBag keeps saving its own
-- snapshots either way, so removing Syndicator loses nothing.
-- Slot data read (names only): bags[i] (bag i - 1), bankTabs[i].slots (bag 5 + i), the warband's
-- bank[i].slots (bag 11 + i); a slot is { itemLink, itemCount }. Details: character, realm,
-- realmNormalized, className, show.inventory (false: the user hid the character in Syndicator).
local _, SB = ...

local AD = SB.AltData
local P = { name = "Syndicator", priority = 10, DEBOUNCE = 0.5 }
SB.SyndicatorProvider = P

local function api()
	return SB.Adapter.SyndicatorAPI()
end

local function n(v)
	return type(v) == "number" and v or 0
end

local function shown(data)
	local d = type(data) == "table" and data.details
	if type(d) ~= "table" then
		return nil
	end
	if type(d.show) == "table" and d.show.inventory == false then
		return nil
	end
	return d
end

function P.available()
	return api() ~= nil
end

function P.characters()
	local S = api()
	if not S then
		return nil
	end
	local me, list = AD.Canon(SB.Adapter.CharKey()), {}
	for _, full in ipairs(S.GetAllCharacters() or {}) do
		local d = shown(S.GetByCharacterFullName(full))
		if d then
			local key = AD.Canon(full)
			list[#list + 1] = { key = key, name = d.character or full:match("^[^%-]+"), realm = d.realm or d.realmNormalized,
				class = d.className, current = key == me }
		end
	end
	table.sort(list, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		return a.key < b.key
	end)
	return list
end

-- One Syndicator container (a list of slots) as { size, slots = { [slot] = { link, count } } }.
local function container(slotList)
	local out = { size = 0, slots = {} }
	if type(slotList) ~= "table" then
		return out
	end
	for slot, s in pairs(slotList) do
		if type(slot) == "number" then
			out.size = math.max(out.size, slot)
			if type(s) == "table" and type(s.itemLink) == "string" then
				out.slots[slot] = { link = s.itemLink, count = n(s.itemCount) > 0 and s.itemCount or 1 }
			end
		end
	end
	return out
end

local function fullName(S, key)
	for _, full in ipairs(S.GetAllCharacters() or {}) do
		if AD.Canon(full) == key then
			return full
		end
	end
	return nil
end

-- kind "bags" | "bank" | "warband"; "guild" is SwagBag's own (nil here). nil when Syndicator has
-- nothing for it, so Own answers.
function P.container(key, kind)
	local S = api()
	if not S or kind == "guild" then
		return nil
	end
	local out, any = { containers = {} }, false
	local function add(bag, list)
		local c = container(list)
		if c.size > 0 then
			out.containers[bag] = c
			any = true
		end
	end
	if kind == "warband" then
		local w = S.GetWarband(1)
		for i, tab in ipairs(type(w) == "table" and type(w.bank) == "table" and w.bank or {}) do
			add(11 + i, type(tab) == "table" and tab.slots)
		end
		return any and out or nil
	end
	local full = fullName(S, key)
	local data = full and S.GetByCharacterFullName(full)
	if not shown(data) then
		return nil
	end
	if kind == "bags" then
		for i, list in ipairs(type(data.bags) == "table" and data.bags or {}) do
			add(i - 1, list)
		end
	elseif kind == "bank" then
		for i, tab in ipairs(type(data.bankTabs) == "table" and data.bankTabs or {}) do
			add(5 + i, type(tab) == "table" and tab.slots)
		end
	end
	return any and out or nil
end

function P.counts(itemID)
	local S = api()
	if not S then
		return nil
	end
	local info = S.GetInventoryInfoByItemID(itemID, false, false)
	if type(info) ~= "table" then
		return nil
	end
	local me = AD.Canon(SB.Adapter.CharKey())
	local out = { chars = {}, warband = n(type(info.warband) == "table" and info.warband[1]), guilds = {} }
	for _, c in ipairs(type(info.characters) == "table" and info.characters or {}) do
		if type(c) == "table" and type(c.character) == "string" then
			local key = AD.Canon(c.character .. "-" .. tostring(c.realmNormalized or ""))
			local e = { key = key, name = c.character, class = c.className, current = key == me, bags = n(c.bags),
				bank = n(c.bank), mail = n(c.mail), equipped = n(c.equipped), auctions = n(c.auctions), void = n(c.void) }
			if e.bags + e.bank + e.mail + e.equipped + e.auctions + e.void > 0 then
				out.chars[#out.chars + 1] = e
			end
		end
	end
	for _, g in ipairs(type(info.guilds) == "table" and info.guilds or {}) do
		if type(g) == "table" and type(g.guild) == "string" and n(g.bank) > 0 then
			out.guilds[#out.guilds + 1] = { key = AD.Canon(g.guild .. "-" .. tostring(g.realmNormalized or "")),
				name = g.guild, count = g.bank }
		end
	end
	table.sort(out.chars, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		return a.key < b.key
	end)
	return out
end

AD.RegisterProvider(P)

-- Syndicator's data changed: open alt views redraw once, after the burst (SB_ALTDATA_CHANGED).
-- The callback is Syndicator's call into SwagBag, so it runs under ErrorTrap (record only).
SB.On("SB_LOGIN", function()
	SB.Adapter.SyndicatorOnUpdate(SB.ErrorTrap.Guard("altdata.syndicator", function()
		SB.Debounce("altdata.changed", P.DEBOUNCE, function()
			SB.Emit("SB_ALTDATA_CHANGED", "Syndicator")
		end, "none")
	end, "none"))
end, "none")
```

In `SwagBag/SwagBag.toc`, find:

```text
Providers/Auctionator.lua

# UI
UI/Theme.lua
```

and replace it with:

```text
Providers/Auctionator.lua
Providers/Syndicator.lua

# UI
UI/Theme.lua
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/syndicator_spec.lua spec/altdata_spec.lua spec/footer_spec.lua`
Expected: `0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (59 files)`, `1083 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Rules grep**

Run: `grep -n 'Syndicator\.' SwagBag/Providers/Syndicator.lua SwagBag/Core/Adapter.lua | grep -v '^[^:]*:[0-9]*:\s*--'`
Expected: only `A.Resolve("Syndicator.API")` and `A.Resolve("Syndicator.CallbackRegistry")` in `Core/Adapter.lua`. The provider never names Syndicator's globals; it uses the table the Adapter hands it.

- [ ] **Step 7: Commit**

```bash
git add "spec/syndicator_spec.lua" "SwagBag/Providers/Syndicator.lua" "SwagBag/Core/Adapter.lua" "SwagBag/Core/Report.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 7: Syndicator alt data provider (public API through the Adapter), report line, CurrencyList secret guard

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 8: Counts under every item tooltip (AC13.3; D16, D17) and Settings > Alt data

`Core/Adapter.lua`:
- `HookItemTooltip(fn)` runs `fn(tooltip, itemID)` after the client fills any item tooltip: through `TooltipDataProcessor.AddTooltipPostCall` for the item tooltip type, else `GameTooltip`'s `OnTooltipSetItem`. A secret item ID is skipped;
- `TooltipLine` adds one line;
- `ClassColour` reads the client's class colours.

`UI/TooltipCounts.lua`:
- `TooltipCounts.Lines(counts)` is pure and turns `AltData.Counts` into lines (D16);
- the hook runs under `ErrorTrap.Guard("tooltip.counts", …, "none")`;
- the setting `tooltip.counts` is `auto` by default: no lines while Syndicator, which writes its own, is loaded (D17);
- `/swagbag tooltip` and a new Settings > **Alt data** page with the choice and a note naming the data's source.

**Files:**
- Create: `SwagBag/UI/TooltipCounts.lua`, `spec/tooltip_spec.lua`
- Modify: `SwagBag/Core/Adapter.lua`, `SwagBag/Core/Config.lua` (`tooltip.counts`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`

**Interfaces:**
- Consumes: Task 6's `AltData.Counts/Characters`; `SB.Snapshots.Count/Bytes`; `SB.SettingsWindow.AddPage/RunCommand`; `SB.Adapter.AddOnState`.
- Produces:
  - `SB.Adapter.HookItemTooltip(fn) -> bool`, `SB.Adapter.TooltipLine(tooltip, left, right)`, `SB.Adapter.ClassColour(class) -> "|cffRRGGBB" | nil`;
  - `SB.TooltipCounts.Lines(counts) -> { { left, right? } }`, `.Add(tooltip, itemID)`, `.Mode()`, `.Showing()`, `.MAX_CHARS` (8);
  - `/swagbag tooltip`, the settings page id `"alts"`, and the setting `tooltip.counts` (`"auto"`).

- [ ] **Step 1: Write the failing tests**

Create `spec/tooltip_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip TooltipDataProcessor Enum RAID_CLASS_COLORS
-- luacheck: globals issecretvalue
-- Tooltip counts (UI/TooltipCounts.lua, spec AC13.3): lines per character, the warband bank and
-- guilds under every item tooltip, from Engine/AltData.lua; a setting; a hook that never breaks bags.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Tooltip counts", function()
	local SB, A, TC, lines
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/Engine/Snapshots.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/AltData.lua")
		SB.Inventory.ScanAll()
		lines = {}
		A.TooltipLine = function(_, left, right) lines[#lines + 1] = { left, right } end
		A.ClassColour = function() return nil end
		A.HookItemTooltip = function(fn) A.tooltipHook = fn return true end
		SB.BagsWindow = { View = function() return "sections" end }
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/TooltipCounts.lua")
		TC = SB.TooltipCounts
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function abby(bags, bank)
		SB.Snapshots.DB().chars["Abby-Argent Dawn"] = { class = "PRIEST",
			bags = { v = 1, containers = { [0] = { size = 16, s = bags or "" } } },
			bank = { v = 1, containers = { [6] = { size = 98, s = bank or "" } } } }
	end

	-- Mutation: in TC.Lines, drop the warband line.
	it("lines: the total, one per character with where, the warband bank and guild banks", function()
		local out = TC.Lines({ chars = {
			{ name = "Swagger", current = true, bags = 5, bank = 0 },
			{ name = "Abby", bags = 20, bank = 100, mail = 2, auctions = 1 },
		}, warband = 7, guilds = { { name = "Tidewatch", count = 3 } } })
		assert.same({
			{ "SwagBag: 138 in all" },
			{ "Swagger (this character)", "Bags 5" },
			{ "Abby", "Bags 20, Bank 100, Mail 2, Auctions 1" },
			{ "Warband bank", "7" },
			{ "Tidewatch (guild bank)", "3" },
		}, out)
	end)

	-- Mutation: in TC.Lines, drop the "elsewhere" check (always show).
	it("nothing is added when the only place is this character's bags, or when there is nothing", function()
		assert.same({}, TC.Lines({ chars = { { name = "Swagger", current = true, bags = 5, bank = 0 } }, warband = 0,
			guilds = {} }))
		assert.same({}, TC.Lines({ chars = {}, warband = 0, guilds = {} }))
		assert.same({}, TC.Lines(nil))
		assert.equal(2, #TC.Lines({ chars = { { name = "Swagger", current = true, bags = 5, bank = 2 } } }),
			"this character's bank counts as elsewhere")
	end)

	it("at most eight characters, then how many more", function()
		local chars = {}
		for i = 1, 10 do
			chars[i] = { name = "Alt" .. i, bags = 1 }
		end
		local out = TC.Lines({ chars = chars })
		assert.equal(10, #out)
		assert.same({ "...and 2 more characters" }, out[10])
	end)

	it("a character's name takes its class colour when the client has one", function()
		A.ClassColour = function(class) return class == "PRIEST" and "|cffffffff" or nil end
		local out = TC.Lines({ chars = { { name = "Abby", class = "PRIEST", bags = 1 } } })
		assert.equal("|cffffffffAbby|r", out[2][1])
	end)

	it("the hook adds the lines for the hovered item from the alt data", function()
		abby("1:item:211880;20\n")
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.same({ "SwagBag: 25 in all" }, lines[1])
		assert.same({ "Swagger (this character)", "Bags 5" }, lines[2])
		assert.same({ "Abby", "Bags 20" }, lines[3])
	end)

	-- P6. Mutation: hook TC.Add directly instead of through ErrorTrap.Guard.
	it("an error while counting is recorded as 'none' and never takes the bags to Safe Mode", function()
		SB.AltData.Counts = function() error("counts broke") end
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.equal("tooltip.counts", SB.ErrorTrap.Recent()[1].label)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	-- Mutation: in TC.Showing, ignore whether Syndicator is loaded.
	it("auto: not shown while Syndicator is loaded (it writes its own); on: always; off: never", function()
		abby("1:item:211880;20\n")
		A.addons.Syndicator = "284"
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.same({}, lines)
		SB.Config.Set("tooltip.counts", "on")
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.truthy(#lines > 0)
		lines = {}
		SB.Config.Set("tooltip.counts", "off")
		A.addons.Syndicator = nil
		A.tooltipHook("tooltip", Fixtures.HEALING_POTION)
		assert.same({}, lines)
	end)

	it("/swagbag tooltip answers every form; read-only refuses", function()
		SB.Slash.Dispatch("tooltip")
		SB.Slash.Dispatch("tooltip off")
		SB.Slash.Dispatch("tooltip maybe")
		assert.same({ "Tooltip counts: shown unless Syndicator shows them. Use /swagbag tooltip auto, on or off.",
			"Tooltip counts: hidden.", "Tooltip counts: hidden. Use /swagbag tooltip auto, on or off." }, A.Lines())
		SB.Config.readOnly = true
		SB.Slash.Dispatch("tooltip on")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[4])
		assert.equal("off", TC.Mode())
	end)

	it("Settings > Alt data: shown first and selected; a click runs /swagbag tooltip; the note names the source", function()
		local SW = SB.SettingsWindow
		SW.Show("alts")
		assert.equal(SB.L.SET_TIP_AUTO, SW.buttons[1].text)
		assert.truthy(SW.selected[SW.buttons[1]])
		Fake.Fire(SW.buttons[3], "OnClick")
		assert.equal("off", TC.Mode())
		assert.equal("Tooltip counts: hidden.", SW.lastStatus)
		local note = SW.labels[SW.used.labels].text
		assert.truthy(note:find("SwagBag's own saved bags", 1, true), note)
	end)
end)

describe("Adapter.HookItemTooltip (the real Adapter.lua)", function()
	local A
	before_each(function()
		local SB = {}
		Fake.Install()
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		TooltipDataProcessor, Enum, RAID_CLASS_COLORS, issecretvalue = nil, nil, nil, nil
		Fake.Uninstall()
	end)

	it("uses TooltipDataProcessor's item post-call and passes the item ID; a secret ID is skipped", function()
		local post
		TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) assert.equal(0, kind) post = fn end }
		Enum = { TooltipDataType = { Item = 0 } }
		local seen = {}
		assert.truthy(A.HookItemTooltip(function(_, id) seen[#seen + 1] = id end))
		post("tt", { id = 211880 })
		post("tt", {})
		issecretvalue = function(v) return v == 5 end
		post("tt", { id = 5 })
		assert.same({ 211880 }, seen)
	end)

	it("falls back to GameTooltip's OnTooltipSetItem without the processor", function()
		assert.truthy(A.HookItemTooltip(function() end))
		assert.equal(1, #GameTooltip.hooks.OnTooltipSetItem)
	end)

	it("ClassColour reads the client's class colours", function()
		assert.is_nil(A.ClassColour("MAGE"))
		RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
		assert.equal("|cff3fc7eb", A.ClassColour("MAGE"))
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1083 passed, 12 failed`. These are the 12 tests of `spec/tooltip_spec.lua`: nine with `cannot open SwagBag/UI/TooltipCounts.lua`, and the three Adapter tests with `attempt to call field 'HookItemTooltip'/'ClassColour' (a nil value)`.

Critical tests and their mutations (in `SwagBag/UI/TooltipCounts.lua`):

| Test | Mutation |
|---|---|
| "lines: the total, one per character with where, the warband bank and guild banks" | delete the `Warband bank` line |
| "nothing is added when the only place is this character's bags, or when there is nothing" | `if total == 0 then` (drop `not elsewhere`) |
| "an error while counting is recorded as 'none' and never takes the bags to Safe Mode" | hook `TC.Add` without `ErrorTrap.Guard` |
| "auto: not shown while Syndicator is loaded (it writes its own); on: always; off: never" | in `TC.Showing`, `return true` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Adapter.lua`, find:

```lua
-- A bag or bank slot's item tooltip (the list view's rows), with an optional white hint line.
```

and replace it with:

```lua
-- Every item tooltip the client fills (bags, bank, auction house, chat links): fn(tooltip, itemID)
-- runs after it, to add lines (the alt counts, UI/TooltipCounts.lua). Through
-- TooltipDataProcessor.AddTooltipPostCall for Enum.TooltipDataType.Item when the client has it,
-- else GameTooltip's OnTooltipSetItem. A secret or missing item ID is skipped. True when hooked.
function A.HookItemTooltip(fn)
	local TDP = _G.TooltipDataProcessor
	local kind = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
	if type(TDP) == "table" and type(TDP.AddTooltipPostCall) == "function" and kind ~= nil then
		local ok = pcall(TDP.AddTooltipPostCall, kind, function(tooltip, data)
			local id = type(data) == "table" and data.id or nil
			if type(id) == "number" and not isSecret(id) then
				fn(tooltip, id)
			end
		end)
		return ok
	end
	if GameTooltip and GameTooltip.HookScript then
		GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
			local ok, _, link = pcall(tooltip.GetItem, tooltip)
			if ok and type(link) == "string" and not isSecret(link) then
				local inst = A.GetItemInstant(link)
				if inst then
					fn(tooltip, inst.itemID)
				end
			end
		end)
		return true
	end
	return false
end

-- One line on a tooltip: left in gold, right (optional) in white.
function A.TooltipLine(tooltip, left, right)
	if right then
		pcall(tooltip.AddDoubleLine, tooltip, left, right, 1, 0.82, 0, 1, 1, 1)
	else
		pcall(tooltip.AddLine, tooltip, left, 1, 0.82, 0)
	end
end

-- "|cffRRGGBB" for a class file name ("MAGE"), or nil.
function A.ClassColour(class)
	local colours = _G.RAID_CLASS_COLORS
	local c = type(colours) == "table" and type(class) == "string" and colours[class]
	if type(c) == "table" and type(c.colorStr) == "string" then
		return "|c" .. c.colorStr
	end
	return nil
end

-- A bag or bank slot's item tooltip (the list view's rows), with an optional white hint line.
```

In `SwagBag/Core/Config.lua`, find:

```lua
		-- "flat" | "elvui" (UI/Themes.lua).
		theme = { name = "blizzard" },
```

and replace it with:

```lua
		-- "flat" | "elvui" (UI/Themes.lua).
		theme = { name = "blizzard" },
		-- counts: other characters' counts on item tooltips (UI/TooltipCounts.lua): "auto" (shown unless
		-- Syndicator is loaded, which writes its own), "on", "off".
		tooltip = { counts = "auto" },
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_ALTDATA = "Alt data: %s, %d characters"
```

and replace it with:

```lua
L.REPORT_ALTDATA = "Alt data: %s, %d characters"
L.TIP_TOTAL = "SwagBag: %d in all"
L.TIP_THIS_CHAR = "%s (this character)"
L.TIP_BAGS = "Bags %d"
L.TIP_BANK = "Bank %d"
L.TIP_MAIL = "Mail %d"
L.TIP_EQUIPPED = "Worn %d"
L.TIP_AUCTIONS = "Auctions %d"
L.TIP_VOID = "Void %d"
L.TIP_WARBAND = "Warband bank"
L.TIP_GUILD = "%s (guild bank)"
L.TIP_MORE = "...and %d more characters"
L.HELP_TOOLTIP = "tooltip [auto|on|off]: other characters' counts on item tooltips"
L.TIP_USAGE = "Tooltip counts: %s. Use /swagbag tooltip auto, on or off."
L.TIP_STATE_AUTO = "shown unless Syndicator shows them"
L.TIP_STATE_ON = "always shown"
L.TIP_STATE_OFF = "hidden"
L.TIP_SET = "Tooltip counts: %s."
L.SET_PAGE_ALTS = "Alt data"
L.SET_TIP = "Other characters' counts on item tooltips"
L.SET_TIP_AUTO = "Shown (not twice with Syndicator)"
L.SET_TIP_ON = "Always shown"
L.SET_TIP_OFF = "Hidden"
L.SET_ALTS_SOURCE = "Alt data comes from %s: %d characters. SwagBag also keeps its own: %d characters, %d KB."
L.ALTS_OWN = "SwagBag's own saved bags"
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/Themes.lua
UI/QuickSetup.lua
UI/DebugV1.lua
```

and replace it with:

```text
UI/Themes.lua
UI/TooltipCounts.lua
UI/QuickSetup.lua
UI/DebugV1.lua
```

Create `SwagBag/UI/TooltipCounts.lua`:

```lua
-- SwagBag tooltip counts (spec AC13.3, F13): how many of an item the account has, and where, under
-- every item tooltip ("SwagBag: 27 in all", then a line per character -- "Bags 5, Bank 20" -- the
-- warband bank and guild banks). Counts come from Engine/AltData.lua (Syndicator when it answers,
-- else SwagBag's own snapshots, with this character's bags live). Nothing is added when the only
-- place is this character's bags (the tooltip's own item says that already).
-- Setting tooltip.counts: "auto" (default: shown unless Syndicator is loaded, which writes the same
-- lines itself; one set, not two), "on", "off". /swagbag tooltip and Settings > Alt data.
-- The hook is a client call into SwagBag: it runs under ErrorTrap "none" (a tooltip glitch is
-- recorded for /swagbag report and never takes the bags away).
--   TooltipCounts.Lines(counts) -> { { left, right } }   pure
--   TooltipCounts.Add(tooltip, itemID)
local _, SB = ...

local L = SB.L
local TC = { MAX_CHARS = 8, MODES = { auto = true, on = true, off = true } }
SB.TooltipCounts = TC

function TC.Mode()
	local m = SB.Config.Get("tooltip.counts")
	return TC.MODES[m] and m or "auto"
end

function TC.Showing()
	local m = TC.Mode()
	if m == "off" then
		return false
	end
	return not (m == "auto" and SB.Adapter.AddOnState("Syndicator"))
end

local PARTS = { { "bags", L.TIP_BAGS }, { "bank", L.TIP_BANK }, { "mail", L.TIP_MAIL }, { "equipped", L.TIP_EQUIPPED },
	{ "auctions", L.TIP_AUCTIONS }, { "void", L.TIP_VOID } }

local function charTotal(c)
	local n = 0
	for _, p in ipairs(PARTS) do
		n = n + (c[p[1]] or 0)
	end
	return n
end

local function charLine(c)
	local parts = {}
	for _, p in ipairs(PARTS) do
		local v = c[p[1]] or 0
		if v > 0 then
			parts[#parts + 1] = p[2]:format(v)
		end
	end
	local name = c.current and L.TIP_THIS_CHAR:format(c.name) or c.name
	local colour = SB.Adapter.ClassColour(c.class)
	if colour then
		name = colour .. name .. "|r"
	end
	return { name, table.concat(parts, ", ") }
end

function TC.Lines(counts)
	if type(counts) ~= "table" then
		return {}
	end
	local total, elsewhere = 0, false
	for _, c in ipairs(counts.chars or {}) do
		local n = charTotal(c)
		total = total + n
		if n > (c.current and (c.bags or 0) or 0) then
			elsewhere = true
		end
	end
	local warband = counts.warband or 0
	total = total + warband
	elsewhere = elsewhere or warband > 0
	for _, g in ipairs(counts.guilds or {}) do
		total = total + (g.count or 0)
		elsewhere = true
	end
	if total == 0 or not elsewhere then
		return {}
	end
	local lines = { { L.TIP_TOTAL:format(total) } }
	for i, c in ipairs(counts.chars or {}) do
		if i > TC.MAX_CHARS then
			lines[#lines + 1] = { L.TIP_MORE:format(#counts.chars - TC.MAX_CHARS) }
			break
		end
		lines[#lines + 1] = charLine(c)
	end
	if warband > 0 then
		lines[#lines + 1] = { L.TIP_WARBAND, tostring(warband) }
	end
	for _, g in ipairs(counts.guilds or {}) do
		lines[#lines + 1] = { L.TIP_GUILD:format(g.name), tostring(g.count) }
	end
	return lines
end

function TC.Add(tooltip, itemID)
	if not TC.Showing() then
		return
	end
	for _, line in ipairs(TC.Lines(SB.AltData.Counts(itemID))) do
		SB.Adapter.TooltipLine(tooltip, line[1], line[2])
	end
end

SB.On("SB_LOGIN", function()
	SB.Adapter.HookItemTooltip(SB.ErrorTrap.Guard("tooltip.counts", TC.Add, "none"))
end, "none")

local STATE = { auto = L.TIP_STATE_AUTO, on = L.TIP_STATE_ON, off = L.TIP_STATE_OFF }

-- /swagbag tooltip [auto|on|off]
SB.Slash.Register("tooltip", L.HELP_TOOLTIP, function(arg)
	arg = (arg or ""):lower()
	if not TC.MODES[arg] then
		return L.TIP_USAGE:format(STATE[TC.Mode()])
	end
	if not SB.Config.Set("tooltip.counts", arg) then
		return L.SETTINGS_READONLY
	end
	return L.TIP_SET:format(STATE[arg])
end)

-- Settings > Alt data: the tooltip choice (runs /swagbag tooltip, D17) and where the data comes from.
if SB.SettingsWindow then
	local function altsRows()
		local rows = {
			{ kind = "choice", label = L.SET_TIP, get = TC.Mode, width = 190,
				choices = { { value = "auto", text = L.SET_TIP_AUTO }, { value = "on", text = L.SET_TIP_ON },
					{ value = "off", text = L.SET_TIP_OFF } },
				apply = function(v)
					return SB.SettingsWindow.RunCommand("tooltip " .. v)
				end },
		}
		local list, source = SB.AltData.Characters()
		local chars = SB.Snapshots.Count()
		rows[#rows + 1] = { kind = "note", label = L.SET_ALTS_SOURCE:format(source == "Own" and L.ALTS_OWN or tostring(source),
			list and #list or 0, chars, math.floor(SB.Snapshots.Bytes() / 1024 + 0.5)) }
		return rows
	end
	SB.SettingsWindow.AddPage({ id = "alts", title = L.SET_PAGE_ALTS, rows = altsRows })
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/tooltip_spec.lua`
Expected: `12 passed, 0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (60 files)`, `1095 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: In-game session A1** (see "In-game sessions"; Claude installs the build first; full restart, because Tasks 6–8 added files).

- [ ] **Step 7: Commit**

```bash
git add "spec/tooltip_spec.lua" "SwagBag/UI/TooltipCounts.lua" "SwagBag/Core/Adapter.lua" "SwagBag/Core/Config.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 8: alt counts under item tooltips (auto: not twice with Syndicator), /swagbag tooltip, Settings > Alt data

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 9: The alt viewer: display buttons, the window, its search, `/swagbag alts` (AC13.2; D18–D20)

`UI/DisplayButtons.lua` makes plain `ItemButton`s with no template, one per saved (bag, slot), on first use. A click goes to the window, which only links the item (a modified click) or answers that it cannot be used. Hovering shows the item's tooltip from its link (`Adapter.LinkTooltip`), and the tooltip counts of Task 8 follow.

`UI/OfflineWindow.lua` is a movable window like the guild bank window, built on `GroupView`:
- `OW.Load(key)` asks AltData for each kind and builds one group per kind that has saved items, with the guild tabs at bag 100 + tab;
- `describe` turns each saved line into a record with `Items.DescribeLink(info, bag, slot, tab, location)` and marks it `offline`;
- `OverlayData.CanCompare` says no to a record marked `offline`, so a saved item never shows the upgrade arrow;
- the window has its own search box;
- empty saved slots have no button, so there is no Free, and the new GroupView option `hideEmptyNew` hides an empty New;
- every script traps as `"none"`.

`/swagbag alts [name]` opens it on this character or the named one. A name not saved lists the saved ones.

**Files:**
- Create: `SwagBag/UI/DisplayButtons.lua`, `SwagBag/UI/OfflineWindow.lua`, `spec/offline_spec.lua`
- Modify: `SwagBag/UI/GroupView.lua` (`hideEmptyNew`), `SwagBag/Engine/Items.lua` (`DescribeLink`'s location), `SwagBag/Engine/OverlayData.lua` (`record.offline`), `SwagBag/Core/Adapter.lua` (`LinkTooltip`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`

**Interfaces:**
- Consumes:
  - Task 6's `AltData.Container/Characters/Canon/ItemID`;
  - `SB.GroupView.New`, `SB.SearchBox.New`, `SB.SearchState.New`, `SB.Snapshots.Age`, `SB.Overlays.Apply`, `SB.Buttons.SetDimmed`, `SB.Adapter.ModifiedClick/HideTooltip/BagKind`;
  - Task 4's `SB.Theme.Window/Text` (guarded).
- Produces:
  - `SB.DisplayButtons.SetParent/Get(bag, slot)/Paint(button, info)`, `.onClick(bag, slot, mouseButton)`, `.buttons`;
  - `SB.OfflineWindow.Open(key) -> true`, `.Close()`, `.IsOpen()`, `.Flash(text)`, `.Layout(reason)`, `.Load(key)`, `.Info(slot) -> info | nil`, `.ClickSlot(bag, slot)`, `.GroupLabel(id, collapsed, count)`, `.view`, `.searchBox`, `.frame` (with `.title` and `.source`), `.key`, `.name`, `.GUILD_BASE` (100);
  - `SB.Adapter.LinkTooltip(owner, link)`;
  - the GroupView option `cfg.hideEmptyNew`;
  - `Items.DescribeLink(info, bag, slot, tab, location)`; `record.offline`;
  - `/swagbag alts`.

- [ ] **Step 1: Write the failing tests**

Create `spec/offline_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The alt viewer (UI/OfflineWindow.lua, UI/DisplayButtons.lua; spec Views.Offline, AC13.2): a saved
-- character's bags, bank, the warband bank and its guild bank as read-only groups with search.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local function loadOffline(SB)
	Env.FakeBags(SB)
	for _, path in ipairs({ "SwagBag/Engine/Snapshots.lua", "SwagBag/Engine/AltData.lua", "SwagBag/UI/Buttons.lua",
		"SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/SearchBox.lua", "SwagBag/UI/GroupView.lua",
		"SwagBag/UI/DisplayButtons.lua", "SwagBag/UI/OfflineWindow.lua", "SwagBag/UI/Overlays.lua" }) do
		Loader.LoadFile(SB, path)
	end
	return SB.OfflineWindow
end

describe("Alt viewer", function()
	local SB, A, OW, DB
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Env.PaintGlobals()
		OW = loadOffline(SB)
		SB.Inventory.ScanAll()
		DB = SB.DisplayButtons
		SB.Categories.Load()
		local db = SB.Snapshots.DB()
		db.chars["Abby-Argent Dawn"] = { class = "PRIEST", lastSeen = A.Time() - 7200, guild = "Tidewatch-Argent Dawn",
			bags = { v = 1, at = A.Time() - 2 * 86400, containers = { [0] = { size = 16,
				s = "1:item:211880;20\n2:item:225001;1\n4:item:156654;3\n" } } },
			bank = { v = 1, at = A.Time() - 3600, containers = { [6] = { size = 98, s = "5:item:210930;100\n" } } } }
		db.warband = { v = 1, at = A.Time() - 600, containers = { [12] = { size = 98, s = "2:item:212283;7\n" } } }
		db.guilds["Tidewatch-Argent Dawn"] = { tabs = { [1] = "Mats" }, snapshot = { v = 1, at = A.Time() - 60,
			containers = { [1] = { size = 98, s = "4:item:210796;50\n" } } } }
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
	end)

	local function groupHeaders()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId:sub(1, 1) == "#" then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	local function sectionHeaders()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId:sub(1, 1) ~= "#" then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	-- AC13.2. Mutation: in OW.Load, drop the "guild" kind from OW.KINDS.
	it("/swagbag alts <name> shows the character's bags, bank, the warband bank and its guild bank, with ages", function()
		SB.Slash.Dispatch("alts abby")
		assert.truthy(OW.IsOpen())
		assert.same({ "Showing the saved items of Abby." }, A.Lines())
		assert.equal("SwagBag — Abby (saved)", OW.frame.title.text)
		assert.same({ "- Bags (3) - 2 days ago", "- Bank (1) - 1 h ago", "- Warband bank (1) - 10 min ago",
			"- Guild bank: Tidewatch (1) - 1 min ago" }, groupHeaders())
		assert.same({ "- Consumables (1)", "- BoE gear (1)", "- Junk (1)", "- Ore (1)", "- Consumables (1)",
			"- Herbs (1)" }, sectionHeaders())
	end)

	-- Item safety: these are never item buttons. Mutation: create them with "ContainerFrameItemButtonTemplate".
	it("items are SwagBag's own plain display buttons, made only for saved items, never a template", function()
		OW.Open("Abby-ArgentDawn")
		local made = 0
		for _, f in ipairs(Fake.created) do
			if f.kind == "ItemButton" then
				made = made + 1
				assert.is_nil(rawget(f, "template"), "no template, nothing secure")
			end
		end
		assert.equal(6, made, "one per saved item, none for empty saved slots")
		local potion = DB.Get(0, 1)
		assert.truthy(potion.shown)
		assert.equal(20, potion.count)
	end)

	-- P2. Mutation: in OW.ClickSlot, return without the flash.
	it("a click answers that saved items cannot be used; a modified click links the item instead", function()
		OW.Open("Abby-ArgentDawn")
		local potion = DB.Get(0, 1)
		Fake.Fire(potion, "OnClick", "RightButton")
		assert.equal(SB.L.OFFLINE_READONLY, OW.frame.title.text)
		A.Advance(1.6)
		assert.equal("SwagBag — Abby (saved)", OW.frame.title.text)
		A.modified = true
		assert.equal("link", OW.ClickSlot(0, 1))
	end)

	it("hovering shows the item's tooltip from its saved link", function()
		local shown
		A.LinkTooltip = function(owner, link) shown = { owner, link } end
		OW.Open("Abby-ArgentDawn")
		local potion = DB.Get(0, 1)
		Fake.Fire(potion, "OnEnter")
		assert.same({ potion, "item:211880" }, shown)
	end)

	-- AC5.1 in the alt viewer. Mutation: in OW.Layout, drop searchBox.Apply().
	it("its own search dims what does not match, and keywords see where a saved item is", function()
		OW.Open("Abby-ArgentDawn")
		OW.searchBox.editBox:SetText("bank")
		OW.searchBox.Run()
		assert.equal(1, DB.Get(6, 5).alpha, "the bank's ore matches 'bank'")
		assert.equal(0.2, DB.Get(0, 1).alpha, "the bags' potion is dimmed")
		SB.Snapshots.Save("bags")
		OW.Open("Swagger-ArgentDawn")
		assert.equal(0.2, DB.Get(0, 6).alpha, "a button new to this layout is dimmed too: the search applies again")
	end)

	-- Mutation: in OverlayData.CanCompare, drop the record.offline check.
	it("a saved item never shows the upgrade arrow (it may be another character's)", function()
		A.equipped = { [11] = { ilvl = 100, equipLoc = "INVTYPE_FINGER" }, [12] = { ilvl = 100, equipLoc = "INVTYPE_FINGER" } }
		OW.Open("Abby-ArgentDawn")
		local ring = DB.Get(0, 2)
		assert.falsy(SB.Overlays.regions[ring].arrow.shown)
		assert.equal("285", SB.Overlays.regions[ring].topLeft.text, "other overlays still show")
	end)

	it("this character by default; nothing saved yet says so and still opens", function()
		SB.Slash.Dispatch("alts")
		assert.same({ "Showing the saved items of Swagger." }, A.Lines())
		assert.equal(SB.L.OFFLINE_NOTHING:format("Swagger"), OW.frame.source.text)
		assert.same({ "- Warband bank (1) - 10 min ago" }, groupHeaders(), "the warband bank is the account's")
	end)

	it("an unknown name lists the saved characters", function()
		SB.Snapshots.Save("bags")
		SB.Slash.Dispatch("alts zed")
		assert.same({ "No saved character named \"zed\". Saved: Swagger, Abby." }, A.Lines())
		assert.falsy(OW.IsOpen())
	end)

	-- Review Focus 5. Mutation: in OW.Load, keep slots whose OW.Info is nil.
	it("a damaged saved line or a link with no item ID is skipped: no button, no error", function()
		local bags = SB.Snapshots.DB().chars["Abby-Argent Dawn"].bags.containers[0]
		bags.s = bags.s .. "3:garbage;1\n7:|cff00ccff|Hcurrency:3008|h[Crest]|h|r;5\nnot a line\n"
		OW.Open("Abby-ArgentDawn")
		assert.same({ "- Bags (3) - 2 days ago", "- Bank (1) - 1 h ago", "- Warband bank (1) - 10 min ago",
			"- Guild bank: Tidewatch (1) - 1 min ago" }, groupHeaders())
		assert.is_nil(DB.buttons[0][3])
		assert.is_nil(DB.buttons[0][7])
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	it("another character replaces the first: its buttons hide, the new ones show", function()
		SB.Snapshots.Save("bags")
		OW.Open("Abby-ArgentDawn")
		local abbyPotion = DB.Get(0, 1)
		OW.Open("Swagger-ArgentDawn")
		assert.equal("SwagBag — Swagger (saved)", OW.frame.title.text)
		assert.truthy(abbyPotion.shown, "slot 0:1 holds Swagger's potion now")
		assert.equal(5, abbyPotion.count)
		assert.falsy(DB.Get(6, 5).shown, "Abby's bank item is gone")
	end)

	it("Esc or the X hides it and clears the view; reopening lays it out again", function()
		OW.Open("Abby-ArgentDawn")
		OW.Close()
		assert.falsy(DB.Get(0, 1).shown)
		assert.falsy(OW.view.IsOpen())
		assert.truthy(UISpecialFrames[#UISpecialFrames] == "SwagBagOfflineWindow")
		OW.Open("Abby-ArgentDawn")
		assert.truthy(DB.Get(0, 1).shown)
	end)

	-- P6: "none". Mutation: give DisplayButtons' OnClick the window "bags".
	it("an error in a click is recorded as 'none' and never takes the bags or bank to Safe Mode", function()
		OW.Open("Abby-ArgentDawn")
		DB.onClick = function() error("click broke") end
		Fake.Fire(DB.Get(0, 1), "OnClick", "LeftButton")
		assert.equal("offline.click", SB.ErrorTrap.Recent()[1].label)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	it("opens in combat; only plain frames are made", function()
		A.combat = true
		OW.Open("Abby-ArgentDawn")
		for _, f in ipairs(Fake.created) do
			assert.falsy(tostring(f.template):find("Secure"), tostring(f.template))
			assert.falsy(tostring(f.template):find("ContainerFrameItemButton"), tostring(f.template))
		end
	end)
end)

describe("Alt viewer load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Get = function() error("Config.Get called while loading") end
		SB.Config.UI = function() error("Config.UI called while loading") end
		Fake.Install()
		local ok, err = pcall(loadOffline, SB)
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)

describe("GroupView hideEmptyNew", function()
	it("hides each group's New while it is empty when the window asks", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(SB.Adapter)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/Buttons.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		Loader.LoadFile(SB, "SwagBag/UI/GroupView.lua")
		SB.Categories.Load()
		local buttons = {}
		local function cfg(hide)
			return { key = "t", child = Fake.New("Frame"), scroll = Fake.New("ScrollFrame"),
				button = function(_, slot)
					buttons[slot] = buttons[slot] or Fake.New("ItemButton")
					return slot <= 2 and buttons[slot] or nil
				end,
				describe = function(bag, slot) return SB.Items.Describe(bag, slot) end,
				groups = function() return { { id = "g", bags = { { bag = 0, size = 2 } } } } end,
				groupLabel = function() return "g" end, view = function() return "sections" end,
				columns = function() return 10 end, newRows = function() return 2 end, onResize = function() end,
				hideEmptyNew = hide }
		end
		local function ids(v)
			local out = {}
			for _, h in ipairs(v.pos.headers) do
				out[#out + 1] = h.id
			end
			return out
		end
		local shown = SB.GroupView.New(cfg(nil))
		shown.Layout("open")
		assert.same({ "new", "c_consumables" }, ids(shown))
		local hidden = SB.GroupView.New(cfg(true))
		hidden.Layout("open")
		assert.same({ "c_consumables" }, ids(hidden))
		Fake.Uninstall()
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1095 passed, 15 failed`. These are the 15 tests of `spec/offline_spec.lua`, each with `cannot open SwagBag/UI/DisplayButtons.lua: No such file or directory`, except the GroupView test: `expected {1="c_consumables"}, got {1="new", 2="c_consumables"}` (New is still drawn).

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "/swagbag alts <name> shows the character's bags, bank, the warband bank and its guild bank, with ages" | `OW.KINDS` without `"guild"` |
| "items are SwagBag's own plain display buttons, made only for saved items, never a template" | create them with `"ContainerFrameItemButtonTemplate"` |
| "a click answers that saved items cannot be used; a modified click links the item instead" | in `OW.ClickSlot`, delete the `OW.Flash` |
| "its own search dims what does not match, and keywords see where a saved item is" | in `OW.Layout`, delete `searchBox.Apply()` |
| "a saved item never shows the upgrade arrow (it may be another character's)" | in `OverlayData.CanCompare`, drop `record.offline or` |
| "a damaged saved line or a link with no item ID is skipped: no button, no error" | in `OW.Load`, keep every slot (drop the `OW.Info(s)` check) |
| "an error in a click is recorded as 'none' and never takes the bags or bank to Safe Mode" | give the display buttons' `OnClick` the window `"bags"` |
| GroupView "hides each group's New while it is empty when the window asks" | in `GroupView` `build`, drop `hideEmptyNew = cfg.hideEmptyNew` |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Adapter.lua`, find:

```lua
-- One line on a tooltip: left in gold, right (optional) in white.
```

and replace it with:

```lua
-- An item's tooltip from its link (the alt viewer's saved items).
function A.LinkTooltip(owner, link)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetHyperlink, GameTooltip, link)
	GameTooltip:Show()
end

-- One line on a tooltip: left in gold, right (optional) in white.
```

In `SwagBag/Engine/Items.lua`, find (edit 1 of 2):

```lua
-- bag is the caller's slot key (guild tab N uses bag 100 + N); location is "guild". Guild
-- bank items are never bound, never on cooldown and never new.
function Items.DescribeLink(info, bag, slot, tab)
```

and replace it with:

```lua
-- bag is the caller's slot key (guild tab N uses bag 100 + N); location is "guild" unless given
-- (the alt viewer passes "bags", "bank" or "warband" for saved items, so location keywords
-- search them). Such items are never bound, never on cooldown and never new.
function Items.DescribeLink(info, bag, slot, tab, location)
```

In `SwagBag/Engine/Items.lua`, find (edit 2 of 2):

```lua
		location = "guild",
		tab = tab,
		pending = data == nil,
```

and replace it with:

```lua
		location = location or "guild",
		tab = tab,
		pending = data == nil,
```

In `SwagBag/Engine/OverlayData.lua`, find:

```lua
function O.CanCompare(record, canUse)
	local A = SB.Adapter
	if not O.SLOTS[record.equipLoc or ""] or record.pending or type(record.ilvl) ~= "number" then
```

and replace it with:

```lua
-- A saved item in the alt viewer (record.offline) never is: it may be another character's.
function O.CanCompare(record, canUse)
	local A = SB.Adapter
	if record.offline or not O.SLOTS[record.equipLoc or ""] or record.pending or type(record.ilvl) ~= "number" then
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SET_ALTS_SOURCE = "Alt data comes from %s: %d characters. SwagBag also keeps its own: %d characters, %d KB."
L.ALTS_OWN = "SwagBag's own saved bags"
```

and replace it with:

```lua
L.SET_ALTS_SOURCE = "Alt data comes from %s: %d characters. SwagBag also keeps its own: %d characters, %d KB."
L.ALTS_OWN = "SwagBag's own saved bags"
L.OFFLINE_TITLE = "SwagBag — %s (saved)"
L.OFFLINE_BAGS = "Bags"
L.OFFLINE_BANK = "Bank"
L.OFFLINE_WARBAND = "Warband bank"
L.OFFLINE_GUILD = "Guild bank: %s"
L.OFFLINE_GROUP = "%s %s (%d) - %s"
L.OFFLINE_FROM = "from %s"
L.OFFLINE_READONLY = "Saved items can't be used from here. Shift-click links one in chat."
L.OFFLINE_SOURCE = "Saved data from %s. Nothing here can be used or moved."
L.OFFLINE_NOTHING = "Nothing is saved for %s yet: log in on that character once (and open the bank for the bank)."
L.HELP_ALTS = "alts [name]: browse a character's saved bags, bank, warband bank and guild bank"
L.OFFLINE_OPENED = "Showing the saved items of %s."
L.OFFLINE_UNKNOWN = "No saved character named \"%s\". Saved: %s."
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/GuildButtons.lua
UI/GuildBankWindow.lua
```

and replace it with:

```text
UI/GuildButtons.lua
UI/GuildBankWindow.lua
UI/DisplayButtons.lua
UI/OfflineWindow.lua
```

Create `SwagBag/UI/DisplayButtons.lua`:

```lua
-- SwagBag display buttons (the alt viewer, UI/OfflineWindow.lua): saved items are not in any bag
-- this character can reach, so these are SwagBag's own PLAIN ItemButtons (no template, nothing
-- secure), one per (bag, slot) of the saved data, made the first time a saved item needs one and
-- kept for the session. A click never uses or moves anything: a modified click links the item in
-- chat (Blizzard's own handler), any other click answers that the item cannot be used from here
-- (P2). Hovering shows the item's tooltip from its link. Plain frames, so they are made in combat
-- too (like placeholders and section headers).
--   DisplayButtons.SetParent(frame)          the alt viewer's scroll child (set once at load)
--   DisplayButtons.Get(bag, slot) -> button  made on first use; button.bag, button.slot
--   DisplayButtons.Paint(button, info)       info = { link, count, icon, quality } or nil
--   DisplayButtons.onClick(bag, slot, mouseButton), DisplayButtons.linkOf(bag, slot) -> link
--       set by the window that owns them
local _, SB = ...

local DB = { buttons = {}, count = 0, parent = nil, links = setmetatable({}, { __mode = "k" }) }
SB.DisplayButtons = DB

function DB.SetParent(frame)
	DB.parent = frame
end

local function create(bag, slot)
	local Guard = SB.ErrorTrap.Guard
	local b = CreateFrame("ItemButton", nil, DB.parent)
	b.bag, b.slot = bag, slot
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", Guard("offline.click", function(self, mouseButton)
		if DB.onClick then
			DB.onClick(self.bag, self.slot, mouseButton)
		end
	end, "none"))
	b:SetScript("OnEnter", Guard("offline.enter", function(self)
		local link = DB.links[self]
		if link then
			SB.Adapter.LinkTooltip(self, link)
		end
	end, "none"))
	b:SetScript("OnLeave", Guard("offline.leave", function()
		SB.Adapter.HideTooltip()
	end, "none"))
	b:Hide()
	DB.count = DB.count + 1
	return b
end

function DB.Get(bag, slot)
	DB.buttons[bag] = DB.buttons[bag] or {}
	local b = DB.buttons[bag][slot]
	if not b then
		b = create(bag, slot)
		DB.buttons[bag][slot] = b
	end
	return b
end

function DB.Paint(button, info)
	DB.links[button] = info and info.link or nil
	SetItemButtonTexture(button, info and info.icon or nil)
	SetItemButtonCount(button, info and info.count or 0)
	SetItemButtonQuality(button, info and info.quality or nil, info and info.link or nil)
	SetItemButtonDesaturated(button, false)
end
```

In `SwagBag/UI/GroupView.lua`, find (edit 1 of 2):

```lua
--   number of free slots (Engine/Layout.lua, plan D19; families from Adapter.BagFamily) }
```

and replace it with:

```lua
--   number of free slots (Engine/Layout.lua, plan D19; families from Adapter.BagFamily),
--   hideEmptyNew optional: true hides each group's New while it is empty (the alt viewer, where
--   nothing ever arrives) }
```

In `SwagBag/UI/GroupView.lua`, find (edit 2 of 2):

```lua
					newRows = cfg.newRows(), freeTile = cfg.freeTile and cfg.freeTile() or nil,
					family = SB.Adapter.BagFamily })
```

and replace it with:

```lua
					newRows = cfg.newRows(), freeTile = cfg.freeTile and cfg.freeTile() or nil,
					family = SB.Adapter.BagFamily, hideEmptyNew = cfg.hideEmptyNew })
```

Create `SwagBag/UI/OfflineWindow.lua`:

```lua
-- SwagBag alt viewer (spec 3.2 Views.Offline, AC13.2): one saved character's items, read only --
-- its bags, its bank, the warband bank and its guild's bank, as groups of category sections
-- (UI/GroupView.lua), with a search box of its own (AC5.1). The data comes from
-- Engine/AltData.lua (Syndicator when it answers, else SwagBag's own snapshots); each group
-- header says how old it is ("2 days ago") or where it came from ("from Syndicator").
-- Items are SwagBag's own plain display buttons (UI/DisplayButtons.lua), never item buttons:
-- nothing here can be used, moved or sold. A click says so (P2); a modified click links the item.
-- The window shows what was saved when it opened (or when another character is picked); it does
-- not follow saves made while it is open. Every entry point traps as "none": a glitch here is
-- recorded for /swagbag report and never takes the bags or the bank away (there is no Blizzard
-- window to fall back to).
--   OfflineWindow.Open(key) -> bool   key: AltData.Canon("Name-Realm"), default this character
--   OfflineWindow.Close(), .IsOpen(), .Flash(text), .key
--   /swagbag alts [name]               open (this character, or the one named)
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local OW = { HEADER = 80, FOOTER = 6, MAX_HEIGHT_FRACTION = 0.75, GUILD_BASE = 100, key = nil, slots = {}, groups = {},
	info = {}, KINDS = { "bags", "bank", "warband", "guild" } }
SB.OfflineWindow = OW

local frame = CreateFrame("Frame", "SwagBagOfflineWindow", UIParent, "BackdropTemplate")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(600, 200)
frame:Hide()
if frame.SetDontSavePosition then
	frame:SetDontSavePosition(true)
end
OW.frame = frame
table.insert(UISpecialFrames, "SwagBagOfflineWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetPoint("RIGHT", frame, "RIGHT", -30, 0)
frame.title:SetJustifyH("LEFT")
frame.title:SetWordWrap(false)
frame.source = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.source:SetPoint("TOPLEFT", 14, -58)
frame.source:SetJustifyH("LEFT")
if SB.Theme then
	SB.Theme.Window(frame, "main")
	SB.Theme.Text(frame.title, "title")
	SB.Theme.Text(frame.source, "small")
end

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -OW.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, OW.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
OW.scroll, OW.child = scroll, child
SB.DisplayButtons.SetParent(child)

local function clampScroll()
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("offline.wheel", function(_, delta)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (SB.GroupView.SLOT + SB.GroupView.GAP) * 3)
	clampScroll()
end, "none"))

frame:SetScript("OnDragStart", Guard("offline.dragStart", function()
	frame:StartMoving()
end, "none"))
frame:SetScript("OnDragStop", Guard("offline.dragStop", function()
	frame:StopMovingOrSizing()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top then
		SB.Config.UI().positions.offline = { "TOPLEFT", "BOTTOMLEFT", left, top }
	end
end, "none"))

function OW.RestorePosition()
	local p = SB.Config.UI().positions.offline
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 80, -140)
	end
end

---------------------------------------------------------------------------
-- Title
---------------------------------------------------------------------------
local titleToken = 0

local function restingTitle()
	return L.OFFLINE_TITLE:format(OW.name or "")
end

function OW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("offline.flash", function()
		if token == titleToken then
			frame.title:SetText(restingTitle())
		end
	end, "none"))
end

---------------------------------------------------------------------------
-- The saved data of one character
---------------------------------------------------------------------------
local GROUP_NAMES = { bags = L.OFFLINE_BAGS, bank = L.OFFLINE_BANK, warband = L.OFFLINE_WARBAND }

-- A saved slot { link, count } as the button and Items.DescribeLink want it, or nil (a link with no
-- item ID: never shown).
function OW.Info(s)
	local A = SB.Adapter
	local id = s and SB.AltData.ItemID(s.link)
	if not id then
		return nil
	end
	local data = A.GetItemInfo(id)
	return { itemID = id, link = s.link, count = s.count or 1, icon = (A.GetItemInstant(id) or {}).icon,
		quality = data and data.quality or nil }
end

local function kindOf(bag)
	if bag >= OW.GUILD_BASE then
		return "guild", bag - OW.GUILD_BASE
	end
	local kind, tab = SB.Adapter.BagKind(bag)
	if kind == "bank" or kind == "warband" then
		return kind, tab
	end
	return "bags", nil
end

-- Read every kind of saved container for key into OW.slots (bag -> slot -> { link, count }) and
-- OW.groups (GroupView groups, in KINDS order, only kinds with something saved).
function OW.Load(key)
	OW.slots, OW.groups, OW.info = {}, {}, {}
	for _, kind in ipairs(OW.KINDS) do
		local c, source = SB.AltData.Container(key, kind)
		if c then
			local bags = {}
			for id, cont in pairs(c.containers) do
				local bag = kind == "guild" and OW.GUILD_BASE + id or id
				local slots = {}
				for slot, s in pairs(cont.slots) do
					if OW.Info(s) then
						slots[slot] = s
					end
				end
				OW.slots[bag] = slots
				bags[#bags + 1] = { bag = bag, size = cont.size }
			end
			table.sort(bags, function(a, b)
				return a.bag < b.bag
			end)
			if #bags > 0 then
				OW.groups[#OW.groups + 1] = { id = kind, bags = bags }
				OW.info[kind] = { at = c.at, source = source, title = c.title }
			end
		end
	end
end

local function age(info)
	if info.at then
		return SB.Snapshots.Age(SB.Adapter.Time() - info.at)
	end
	return L.OFFLINE_FROM:format(tostring(info.source))
end

function OW.GroupLabel(id, collapsed, count)
	local info = OW.info[id] or {}
	local name = GROUP_NAMES[id] or L.OFFLINE_GUILD:format(info.title or "")
	return L.OFFLINE_GROUP:format(collapsed and "+" or "-", name, count or 0, age(info))
end

local function describe(bag, slot)
	local s = OW.slots[bag] and OW.slots[bag][slot]
	local info = OW.Info(s)
	local button = SB.DisplayButtons.Get(bag, slot)
	SB.DisplayButtons.Paint(button, info)
	if not info then
		return nil
	end
	local kind, tab = kindOf(bag)
	local record = SB.Items.DescribeLink(info, bag, slot, tab, kind)
	record.offline = true
	if SB.Overlays then
		SB.Overlays.Apply(button, record, bag)
	end
	return record
end

local function sizeFrame(width, height)
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * OW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - OW.HEADER - OW.FOOTER) + OW.HEADER + OW.FOOTER)
	clampScroll()
end

local searchBox

OW.view = SB.GroupView.New({
	key = "offline",
	window = "none",
	child = child,
	scroll = scroll,
	-- only saved items have a button in the layout: an empty saved slot is not drawn (no Free)
	button = function(bag, slot)
		if OW.slots[bag] and OW.slots[bag][slot] then
			return SB.DisplayButtons.Get(bag, slot)
		end
		return nil
	end,
	describe = describe,
	groups = function()
		return OW.groups
	end,
	groupLabel = OW.GroupLabel,
	view = function()
		return "sections"
	end,
	columns = function()
		return SB.Config.Get("bank.columns")
	end,
	newRows = function()
		return 0
	end,
	hideEmptyNew = true,
	onResize = sizeFrame,
	onUpdated = function()
		searchBox.Apply()
	end,
})

searchBox = SB.SearchBox.New({
	parent = frame,
	name = "SwagBagOfflineSearchBox",
	search = SB.SearchState.New(),
	window = "none",
	debounceKey = "search.offline",
	isOpen = function()
		return OW.IsOpen()
	end,
	forEachSlot = function(fn)
		return OW.view.ForEachSlot(fn)
	end,
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
	end,
})
OW.searchBox = searchBox

---------------------------------------------------------------------------
-- Clicks (UI/DisplayButtons.lua): nothing is used; a modified click links the item
---------------------------------------------------------------------------
function OW.ClickSlot(bag, slot)
	local s = OW.slots[bag] and OW.slots[bag][slot]
	if s and SB.Adapter.ModifiedClick(s.link) then
		return "link"
	end
	OW.Flash(L.OFFLINE_READONLY)
	return "readonly"
end
SB.DisplayButtons.onClick = OW.ClickSlot

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
local function nameOf(key)
	for _, c in ipairs(SB.AltData.Characters() or {}) do
		if c.key == key then
			return c.name
		end
	end
	return key and key:match("^[^%-]+") or key
end

function OW.IsOpen()
	return frame:IsShown()
end

function OW.Layout(reason)
	OW.view.Clear() -- the buttons of what was shown, before the new data replaces it
	OW.Load(OW.key)
	frame.title:SetText(restingTitle())
	-- nothing of the character's own saved (the warband bank is the account's): say how to get it
	local _, source = SB.AltData.Characters()
	if OW.info.bags or OW.info.bank or OW.info.guild then
		frame.source:SetText(L.OFFLINE_SOURCE:format(source == "Own" and L.ALTS_OWN or tostring(source)))
	else
		frame.source:SetText(L.OFFLINE_NOTHING:format(OW.name or ""))
	end
	OW.view.Layout(reason)
	searchBox.Apply()
end

function OW.Open(key)
	OW.key = key or SB.AltData.Canon(SB.Adapter.CharKey())
	OW.name = nameOf(OW.key)
	if not frame:IsShown() then
		OW.RestorePosition()
		frame:Show()
	end
	OW.Layout("open")
	return true
end

function OW.Close()
	frame:Hide()
end

frame:SetScript("OnHide", Guard("offline.hide", function(self)
	if self:IsShown() then
		return
	end
	OW.view.Clear()
end, "none"))

-- The saved character whose name (or "Name-Realm") is text, or nil and the names there are.
local function find(text)
	text = text:lower()
	local names = {}
	for _, c in ipairs(SB.AltData.Characters() or {}) do
		names[#names + 1] = c.name
		if c.key:lower() == text or (c.name or ""):lower() == text then
			return c
		end
	end
	return nil, names
end

-- /swagbag alts [name]
SB.Slash.Register("alts", L.HELP_ALTS, function(arg)
	arg = arg or ""
	if arg == "" then
		OW.Open()
		return L.OFFLINE_OPENED:format(OW.name)
	end
	local c, names = find(arg)
	if not c then
		return L.OFFLINE_UNKNOWN:format(arg, #names > 0 and table.concat(names, ", ") or L.REPORT_NONE)
	end
	OW.Open(c.key)
	return L.OFFLINE_OPENED:format(OW.name)
end)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/offline_spec.lua spec/groupview_spec.lua spec/guildbank_spec.lua spec/overlays_spec.lua`
Expected: `0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1110 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Rules grep**

Run: `grep -n 'CreateFrame' SwagBag/UI/DisplayButtons.lua SwagBag/UI/OfflineWindow.lua`
Expected: `CreateFrame("ItemButton", nil, DB.parent)` with no template. The other creations are the window `Frame` (`"BackdropTemplate"`), a `UIPanelCloseButton`, a `ScrollFrame` and its child `Frame`; none is secure.

- [ ] **Step 7: Commit**

```bash
git add "spec/offline_spec.lua" "SwagBag/UI/DisplayButtons.lua" "SwagBag/UI/OfflineWindow.lua" "SwagBag/UI/GroupView.lua" "SwagBag/Engine/Items.lua" "SwagBag/Engine/OverlayData.lua" "SwagBag/Core/Adapter.lua" "SwagBag/Locale/enUS.lua" "SwagBag/SwagBag.toc"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 9: the alt viewer (read-only saved bags, bank, warband and guild bank; plain display buttons; search)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---
### Task 10: The character picker, Settings > Alt data's "Open the alt viewer", overlays in the alt viewer (AC13.2 "via the character dropdown")

A `Character: <name>` button on the alt viewer's search row opens a list of every saved character, from whichever provider answers. The list is pooled plain buttons in a small backdrop frame, with the shown character highlighted and the age when known. A click shows that character. Esc or the X closes the list with the window. Settings > Alt data gets `Open the alt viewer`, which runs `/swagbag alts` (week-4 D17). `Overlays.RefreshAll` also redraws the alt viewer, so `/swagbag overlays …` changes it at once.

**Files:**
- Modify: `SwagBag/UI/OfflineWindow.lua`, `SwagBag/UI/TooltipCounts.lua`, `SwagBag/UI/Overlays.lua`, `SwagBag/Locale/enUS.lua`, `spec/offline_spec.lua`

**Interfaces:**
- Consumes: Task 9's `OW.Open/Layout/key/name`; Task 8's Alt data page; `SB.Theme.Button/Window` (guarded).
- Produces: `SB.OfflineWindow.ToggleMenu() -> bool`, `.pickButton`, `.menu`, `.menuButtons`, `.MENU_MAX` (30); `L.OFFLINE_PICK`, `L.OFFLINE_MENU_REALM`, `L.OFFLINE_MENU_SEEN`, `L.OFFLINE_NONE_SAVED`, `L.SET_ALTS_VIEW`, `L.SET_ALTS_OPEN`.

- [ ] **Step 1: Write the failing tests**

In `spec/offline_spec.lua`, find:

```lua
describe("Alt viewer load order", function()
```

and replace it with:

```lua
describe("Alt viewer: the character picker and the ways in", function()
	local SB, A, OW
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Env.PaintGlobals()
		OW = loadOffline(SB)
		SB.Inventory.ScanAll()
		SB.Categories.Load()
		SB.Snapshots.Save("bags")
		SB.Snapshots.DB().chars["Abby-Argent Dawn"] = { class = "PRIEST", lastSeen = A.Time() - 2 * 86400,
			bags = { v = 1, at = A.Time() - 2 * 86400, containers = { [0] = { size = 16, s = "1:item:211880;20\n" } } } }
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
	end)

	local function menuTexts()
		local out = {}
		for _, b in ipairs(OW.menuButtons) do
			if b.shown then
				out[#out + 1] = b.text
			end
		end
		return out
	end

	-- AC13.2 "via the character dropdown". Mutation: in the menu buttons' OnClick, drop OW.Open(self.key).
	it("the picker lists every saved character (this one first, with ages); a click shows that one", function()
		OW.Open()
		assert.equal("Character: Swagger", OW.pickButton.text)
		Fake.Fire(OW.pickButton, "OnClick")
		assert.truthy(OW.menu.shown)
		assert.same({ "Swagger (Argent Dawn) - just now", "Abby (Argent Dawn) - 2 days ago" }, menuTexts())
		Fake.Fire(OW.menuButtons[2], "OnClick")
		assert.falsy(OW.menu.shown)
		assert.equal("SwagBag — Abby (saved)", OW.frame.title.text)
		assert.equal("Character: Abby", OW.pickButton.text)
		assert.equal(20, SB.DisplayButtons.Get(0, 1).count)
	end)

	it("a second click closes the list; reopening reuses its buttons; hiding the window hides it", function()
		OW.Open()
		OW.ToggleMenu()
		local n = #Fake.created
		OW.ToggleMenu()
		assert.falsy(OW.menu.shown)
		OW.ToggleMenu()
		assert.equal(n, #Fake.created, "no new frames")
		OW.Close()
		assert.falsy(OW.menu.shown)
	end)

	it("with Syndicator answering, its characters are listed (no stamp: name and realm only)", function()
		SB.AltData.RegisterProvider({ name = "Syndicator", priority = 10, available = function() return true end,
			characters = function() return { { key = "Zed-ArgentDawn", name = "Zed", realm = "Argent Dawn" } } end })
		OW.Open("Zed-ArgentDawn")
		OW.ToggleMenu()
		assert.same({ "Zed (Argent Dawn)" }, menuTexts())
	end)

	it("Settings > Alt data opens the alt viewer through /swagbag alts", function()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/TooltipCounts.lua")
		local SW = SB.SettingsWindow
		SW.Show("alts")
		for i = 1, SW.used.buttons do
			if SW.buttons[i].text == SB.L.SET_ALTS_OPEN then
				Fake.Fire(SW.buttons[i], "OnClick")
			end
		end
		assert.truthy(OW.IsOpen())
		assert.equal("Showing the saved items of Swagger.", SW.lastStatus)
	end)

	-- Mutation: drop the offline window from Overlays.RefreshAll.
	it("switching an overlay redraws the alt viewer's items too", function()
		OW.Open("Swagger-ArgentDawn")
		local ring = SB.DisplayButtons.Get(0, 3)
		assert.equal("285", SB.Overlays.regions[ring].topLeft.text)
		SB.Slash.Dispatch("overlays ilvl off")
		assert.equal("", SB.Overlays.regions[ring].topLeft.text)
	end)
end)

describe("Alt viewer load order", function()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1110 passed, 5 failed`. These are the five tests of "Alt viewer: the character picker and the ways in", with messages such as `attempt to call field 'ToggleMenu' (a nil value)` and `expected "", got "285"`.

Critical tests and their mutations:

| Test | Mutation |
|---|---|
| "the picker lists every saved character (this one first, with ages); a click shows that one" | in the menu buttons' `OnClick`, delete `OW.Open(self.key)` |
| "switching an overlay redraws the alt viewer's items too" | in `Overlays.RefreshAll`, delete the alt viewer block |

- [ ] **Step 3: Write the implementation**

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.OFFLINE_UNKNOWN = "No saved character named \"%s\". Saved: %s."
```

and replace it with:

```lua
L.OFFLINE_UNKNOWN = "No saved character named \"%s\". Saved: %s."
L.OFFLINE_PICK = "Character: %s"
L.OFFLINE_MENU_REALM = "%s (%s)"
L.OFFLINE_MENU_SEEN = "%s - %s"
L.OFFLINE_NONE_SAVED = "No character is saved yet."
L.SET_ALTS_VIEW = "Browse a character's saved bags, bank, warband bank and guild bank"
L.SET_ALTS_OPEN = "Open the alt viewer"
```

In `SwagBag/UI/OfflineWindow.lua`, find (edit 1 of 5):

```lua
--   /swagbag alts [name]               open (this character, or the one named)
```

and replace it with:

```lua
--   OfflineWindow.ToggleMenu()         the character picker: every saved character, a click shows it
--   /swagbag alts [name]               open (this character, or the one named)
```

In `SwagBag/UI/OfflineWindow.lua`, find (edit 2 of 5):

```lua
	info = {}, KINDS = { "bags", "bank", "warband", "guild" } }
```

and replace it with:

```lua
	info = {}, KINDS = { "bags", "bank", "warband", "guild" }, menuButtons = {}, MENU_ROW = 20, MENU_MAX = 30 }
```

In `SwagBag/UI/OfflineWindow.lua`, find (edit 3 of 5):

```lua
	-- nothing of the character's own saved (the warband bank is the account's): say how to get it
```

and replace it with:

```lua
	OW.pickButton:SetText(L.OFFLINE_PICK:format(OW.name or ""))
	-- nothing of the character's own saved (the warband bank is the account's): say how to get it
```

In `SwagBag/UI/OfflineWindow.lua`, find (edit 4 of 5):

```lua
frame:SetScript("OnHide", Guard("offline.hide", function(self)
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- The character picker: a button on the search row and a list of plain buttons under it
---------------------------------------------------------------------------
OW.pickButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
OW.pickButton:SetSize(180, 20)
OW.pickButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -30)
OW.pickButton:SetText(L.OFFLINE_PICK:format(""))
OW.pickButton:SetScript("OnClick", Guard("offline.pick", function()
	OW.ToggleMenu()
end, "none"))

local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
menu:SetPoint("TOPRIGHT", OW.pickButton, "BOTTOMRIGHT", 0, -2)
menu:SetFrameStrata("DIALOG")
menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
menu:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
menu:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
menu:Hide()
OW.menu = menu
if SB.Theme then
	SB.Theme.Button(OW.pickButton)
	SB.Theme.Window(menu, "dialog")
end

-- "Abby (Argent Dawn) - 2 days ago"; without a stamp (Syndicator) just the name and realm.
local function menuText(c)
	local text = c.realm and L.OFFLINE_MENU_REALM:format(c.name, c.realm) or c.name
	if c.lastSeen then
		text = L.OFFLINE_MENU_SEEN:format(text, SB.Snapshots.Age(SB.Adapter.Time() - c.lastSeen))
	end
	return text
end

local function menuButton(i)
	local b = OW.menuButtons[i]
	if not b then
		b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
		b:SetSize(260, OW.MENU_ROW)
		b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * (OW.MENU_ROW + 2))
		b:SetScript("OnClick", Guard("offline.menuPick", function(self)
			menu:Hide()
			OW.Open(self.key)
		end, "none"))
		if SB.Theme then
			SB.Theme.Button(b)
		end
		OW.menuButtons[i] = b
	end
	b:Show()
	return b
end

-- Open the list of saved characters (the one shown is highlighted), or close it. Up to MENU_MAX;
-- /swagbag alts <name> reaches any other.
function OW.ToggleMenu()
	if menu:IsShown() then
		menu:Hide()
		return false
	end
	local list = SB.AltData.Characters() or {}
	local n = math.min(#list, OW.MENU_MAX)
	for i = 1, n do
		local b = menuButton(i)
		b.key = list[i].key
		b:SetText(menuText(list[i]))
		if list[i].key == OW.key then
			b:LockHighlight()
		else
			b:UnlockHighlight()
		end
	end
	for i = n + 1, #OW.menuButtons do
		OW.menuButtons[i]:Hide()
	end
	menu:SetSize(268, 8 + math.max(1, n) * (OW.MENU_ROW + 2))
	menu:Show()
	if n == 0 then
		OW.Flash(L.OFFLINE_NONE_SAVED)
	end
	return true
end

frame:SetScript("OnHide", Guard("offline.hide", function(self)
```

In `SwagBag/UI/OfflineWindow.lua`, find (edit 5 of 5):

```lua
	OW.view.Clear()
end, "none"))

-- The saved character whose name (or "Name-Realm") is text, or nil and the names there are.
```

and replace it with:

```lua
	menu:Hide()
	OW.view.Clear()
end, "none"))

-- The saved character whose name (or "Name-Realm") is text, or nil and the names there are.
```

In `SwagBag/UI/Overlays.lua`, find (edit 1 of 2):

```lua
	local bags, bank, guild = SB.BagsWindow, SB.BankWindow, SB.GuildBankWindow
```

and replace it with:

```lua
	local bags, bank, guild, offline = SB.BagsWindow, SB.BankWindow, SB.GuildBankWindow, SB.OfflineWindow
```

In `SwagBag/UI/Overlays.lua`, find (edit 2 of 2):

```lua
	if guild and guild.IsOpen() then
		each(guild.view.ForEachSlot)
```

and replace it with:

```lua
	if guild and guild.IsOpen() then
		each(guild.view.ForEachSlot)
	end
	if offline and offline.IsOpen() then -- the alt viewer (week 5)
		each(offline.view.ForEachSlot)
```

In `SwagBag/UI/TooltipCounts.lua`, find:

```lua
		}
		local list, source = SB.AltData.Characters()
```

and replace it with:

```lua
			-- the alt viewer (UI/OfflineWindow.lua): runs /swagbag alts (D17)
			{ kind = "actions", label = L.SET_ALTS_VIEW, actions = { { text = L.SET_ALTS_OPEN, width = 160, run = function()
				return SB.SettingsWindow.RunCommand("alts")
			end } } },
		}
		local list, source = SB.AltData.Characters()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `luajit spec/runner.lua spec/offline_spec.lua spec/tooltip_spec.lua spec/overlays_spec.lua`
Expected: `0 failed`

- [ ] **Step 5: Run every check**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1115 passed, 0 failed`, `ALL CHECKS PASSED`

- [ ] **Step 6: Rules grep (the whole week)**

Run: `grep -rnE '(^|[^[:alnum:]_])(C_[A-Z][A-Za-z]*|Enum)\.' SwagBag | grep -v '^SwagBag/Core/Adapter.lua:'; grep -rn '"OnUpdate"\|SetCurrentGuildBankTab(' SwagBag; grep -rn 'ContainerFrameItemButtonTemplate' SwagBag`
Expected: no line from the first or the second grep. The third shows only `UI/Buttons.lua` (the pool: its header comment and its `CreateFrame`) and `UI/DebugV1.lua` (the week-1 V1 test strip), as on `d759564`: no new secure button anywhere.

- [ ] **Step 7: In-game session OF1** (see "In-game sessions"; Claude installs the build first; full restart, because Task 9 added files).

- [ ] **Step 8: Commit**

```bash
git add "spec/offline_spec.lua" "SwagBag/UI/OfflineWindow.lua" "SwagBag/UI/TooltipCounts.lua" "SwagBag/UI/Overlays.lua" "SwagBag/Locale/enUS.lua"
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -F - <<'EOF'
Week 5 Task 10: alt viewer character picker, Settings > Alt data opens it, overlays redraw it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx
EOF
```

---

## In-game sessions

**Claude installs the build first, before every session.** The user's game runs a stable week-3 copy of SwagBag until Claude replaces it with this branch's build at the task the session follows. Claude runs, from the repo root, after that task's commit:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
scripts/install.sh --remove
scripts/install.sh --copy --yes
```

Expected: `Copied folder removed.` (or `Symlink removed.`), then `Done. Copied. Restart WoW or /reload.` SavedVariables are not touched. A copy (not a link) keeps the user's game on the tested build while later tasks change the working tree.

**If anything goes wrong at any point,** type `/swagbag report`, press Ctrl+C, and paste the result to Claude. Each session ends with a reply line for Claude. A step marked "(note it)" asks for something the code cannot check on its own: say what you saw.

Session order: L1 (after Task 3), TH1 (after Task 5), A1 (after Task 8), OF1 (after Task 10).

Note on the title: with the item level on (the default), the bags title is `SwagBag — ilvl <number>` (or `SwagBag — <mode> — ilvl <number>` in a focus mode). A long title may end in `...`; only its start matters below.

### Session L1: the list view (after Task 3, about 15 minutes)

You need:
- a stack of something (more than 1);
- a potion or food you can use in combat, and a training dummy;
- a vendor and a gray item (optional, step 10);
- a banker (optional, step 12).

1. Claude has installed the build. Quit the game completely and start it again (new files). Log in. Expected: chat shows `SwagBag: v0.5.0 loaded. Type /swagbag help for commands.`
2. Press **B**. Expected: the bags open exactly as before, in the category view. The buttons at the top read, from left to right: `Sort`, `Pause`, `Reflow`, `List`.
3. Click `List`. Expected:
   - the title shows `SwagBag - list view` for a moment, and the button now says `Grid`;
   - a bar under the search box reads `Name`, `Count`, `ilvl`, `Value v`;
   - each item is one row: a small icon on the left, then its name in its quality colour, then its count (blank for a single item), its item level (gear only) and its value;
   - the sections are the same as in the category view (`Consumables`, `Gear`, `Junk`, …), each with its header, and the window is about as wide as before.
4. Look at a section with several items. Expected: the item worth the most is on top (`Value v` means highest first).
5. Click `Value v`. Expected:
   - the title shows `Sorted by Value, lowest first`, and the bar reads `Value ^`;
   - in every section the cheapest item is now on top.
6. Click `Name`. Expected: the title shows `Sorted by Name, A to Z`, the bar reads `Name ^` and `Value` (no marker), and each section is in A-to-Z order.
7. Rest the mouse on an item's **name** (not its icon). Expected: the item's tooltip, with a white line at the bottom: `Click the icon on the left to use, sell or move this item.` Move the mouse off it.
8. Go to a training dummy and start combat. In the list, right-click the **icon** of a potion or food you can use in combat. Expected:
   - it is used (one fewer);
   - no red `Interface action failed because of an AddOn` message, and nothing about "blocked".

   Move the mouse off it and leave combat. If a "blocked" message showed, stop here and tell Claude (D4 fallback).
9. Shift-click the icon of a stack. Expected: Blizzard's small split box opens. Press **Esc** to close it. Move the mouse off the icon.
10. (Vendor, optional) Open a vendor. Right-click the icon of a gray item. Expected:
    - it is sold;
    - its row now reads `(moved or used - regroups when you close the bag)` with a faded icon;
    - no other row moves.

    Move the mouse off it. Close the vendor.
11. Drag an item's icon onto the icon of the row that reads `<number> free - drop items here`, then move the mouse off the bags. Expected: within half a second a `New` header appears at the top with that item in it, and the number on the free row is one lower.
12. (Bank, optional) Open your bank. Right-click an item's icon in the bags' list. Expected: it goes into the bank, into the tab Blizzard's bank tabs have selected, exactly as in the category view. Move the mouse off it. Close the bank.
13. Type `/swagbag search potion`. Expected:
    - chat shows a line starting `SwagBag: Search "potion":`;
    - every row that is not a potion is faded, icon and text together.

    Type `/swagbag search` (nothing after it). Expected: `SwagBag: Search cleared.` and nothing is faded.
14. Open a vendor again. Expected: the title starts with `SwagBag — AH/Vendor/Bank`, and only `New`, `BoE gear`, `Trade Goods` and `Junk` start with `-` (those you have items in), the same as in the category view. Close the vendor. Expected: your own sections are back.
15. Type `/swagbag list`. Expected: `SwagBag: List view: sorted by Name, A to Z.`
16. Type `/swagbag list value`. Expected: `SwagBag: Sorted by Value, highest first`, and the list goes back to most valuable first.
17. Type `/swagbag`, then click `Bags` on the left. Expected:
    - the `Bag view` row shows `Categories`, `List` (highlighted) and `Grid`;
    - near the bottom, `The list view sorts by` shows `Value` highlighted, then `Name`, `Count`, `ilvl`;
    - `The list view's order` shows `Highest first (Z to A)` highlighted.
18. Click `Count`. Expected: the bottom line says `Sorted by Count, highest first`. Press **Esc**.
19. Drag the bags window by its title down until its bottom edge is cut off by the bottom of the screen, and let go while the mouse is still on the title. Then move the mouse off the window. Expected: within half a second the window grows upward so that everything fits again, and it stays on the screen.
20. Click `Grid`. Expected:
    - the title shows `SwagBag - grid view`;
    - full-size icons in bag order, and no column bar.

    Click `Categories`. Expected: the category view as at the start, full-size icons.
21. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: Claude sees no new errors and `Blocked actions: none`.

Pass: steps 1–9, 11, 13–20, and 10 and 12 if you tried them. If a title message was cut short with `...`, it should also be in chat (note it).

Reply to Claude with: L1 done, and the numbers of any steps that didn't match

### Session TH1: looks (after Task 5, about 8 minutes)

1. Claude has installed the build. Quit the game completely and start it again (new files). Log in. Press **B**. Expected: the bags look exactly as they did in session L1's step 2: the same dark background, gold title, headers and slot backgrounds.
2. Type `/swagbag theme`. Expected: a line starting `SwagBag: Look: Blizzard. Looks: blizzard (Blizzard), flat (Modern flat), elvui (Matches ElvUI`. If ElvUI is not turned on, it ends `elvui (Matches ElvUI, not available now).`
3. Type `/swagbag theme flat`. Expected:
   - `SwagBag: Look: Modern flat. Only SwagBag's own windows change.`;
   - at once, with no reload: a slightly lighter flat background with a black edge, a white title, flatter section headers, flat `Sort`/`Pause`/`Reflow`/`List` buttons and flat slot squares behind the items;
   - the item icons, their quality borders and their counts look the same as before.
4. Click `List`. Expected: the rows have a faint stripe behind them. Click `Grid`, then `Categories`.
5. Type `/swagbag`. Expected: the settings window is flat too. Click `Look` on the left. Expected: the row `The look of SwagBag's windows` shows `Blizzard`, `Modern flat` (highlighted) and `Matches ElvUI`.
6. Go to a training dummy, start combat, and click `Blizzard` in that row. Expected:
   - every SwagBag window changes back at once;
   - the bottom line says `Look: Blizzard. Only SwagBag's own windows change.`;
   - no error and no "blocked" message.

   Leave combat.
7. Click `Matches ElvUI`. Expected, if ElvUI is on: the bottom line says `Look: Matches ElvUI. Only SwagBag's own windows change.`, and the windows use ElvUI's font and colours (note how it looks). If ElvUI is off: the bottom line says `The ElvUI look needs ElvUI, which is not loaded. The look stays Blizzard.`, and `Blizzard` stays highlighted.
8. Click `Modern flat`. Press **Esc**. Type `/reload`. Press **B**. Expected: still the Modern flat look (saved).
9. (Bank, optional) Open your bank. Expected: the bank window is flat too, and the group that receives deposits still has its green tint. Close the bank.
10. Type `/swagbag theme blizzard`. Expected: `SwagBag: Look: Blizzard. Only SwagBag's own windows change.`, and the bags look exactly as in step 1.
11. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: a line `Look: blizzard (setting blizzard)`, no new errors, `Blocked actions: none`.

Pass: steps 1–8, 10, 11, and 9 if you tried it. Steps 3 and 7: say whether you like the looks (note it); colours are constants in `UI/Themes.lua`, and Claude tunes them from your answer.

Reply to Claude with: TH1 done, the numbers of any steps that didn't match, and what you thought of the looks

### Session A1: counts on item tooltips, and where alt data comes from (after Task 8, about 6 minutes)

You need: an item you have both in your bags and somewhere else (your bank, the warband bank, or another character you have logged in on since week 3).

1. Claude has installed the build. Quit the game completely and start it again (new files). Log in. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: a line `Alt data: Syndicator, <number> characters` (Syndicator is on) or `Alt data: Own, <number> characters`.
2. Type `/swagbag tooltip`. Expected: `SwagBag: Tooltip counts: shown unless Syndicator shows them. Use /swagbag tooltip auto, on or off.`
3. Rest the mouse on the item from "You need". Expected: if Syndicator is on, Syndicator's own count lines show and SwagBag adds none (so they are not there twice). If Syndicator is off, see step 5. Move the mouse off it.
4. Type `/swagbag tooltip on`. Expected: `SwagBag: Tooltip counts: always shown.`
5. Rest the mouse on that item again. Expected, at the bottom of the tooltip:
   - `SwagBag: <total> in all`;
   - a line `<your name> (this character)` with, on the right, where it is (for example `Bags 3, Bank 2`);
   - a line per other character that has it (in its class colour), and `Warband bank` with a number if it is there.

   If Syndicator is on, the numbers match Syndicator's lines (note it). Move the mouse off it.
6. Rest the mouse on an item that is only in your bags. Expected: no SwagBag lines. Move the mouse off it.
7. Start combat at a training dummy and rest the mouse on the item from step 5. Expected: the same lines; no error. Move the mouse off it and leave combat.
8. Type `/swagbag`, then click `Alt data` on the left. Expected:
   - the row `Other characters' counts on item tooltips` shows `Shown (not twice with Syndicator)`, `Always shown` (highlighted) and `Hidden`;
   - a line under it starting `Alt data comes from`.
9. Click `Shown (not twice with Syndicator)`. Expected: the bottom line says `Tooltip counts: shown unless Syndicator shows them.` Press **Esc**.
10. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors, `Blocked actions: none`.

Pass: steps 1, 2, 4–10, and 3 if Syndicator is on.

Reply to Claude with: A1 done, the numbers of any steps that didn't match, and whether SwagBag's numbers matched Syndicator's

### Session OF1: the alt viewer (after Task 10, about 8 minutes)

You need: another character that has logged in at least once since week 3 (with Syndicator on, any character Syndicator knows).

1. Claude has installed the build. Quit the game completely and start it again (new files). Log in. Move one item in your bags, then wait 10 seconds (this character's bags are saved 5 s after a change).
2. Type `/swagbag alts`. Expected:
   - chat: `SwagBag: Showing the saved items of <your name>.`;
   - a window titled `SwagBag — <your name> (saved)`;
   - group headers such as `- Bags (<number>) - just now`, `- Bank (<number>) - <age>`, `- Warband bank (<number>) - <age>` (and `- Guild bank: <guild> (<number>) - <age>` if you have opened the guild vault on this character since week 3);
   - with Syndicator on, a header may end in `- from Syndicator` instead of an age.
3. Click the `Character: <your name>` button. Expected: a list of your characters, yours first and highlighted.
4. Click another character. Expected: the list closes, the title reads `SwagBag — <that name> (saved)`, and the groups show that character's items.
5. Rest the mouse on one of its items. Expected: the item's tooltip (with the SwagBag count lines if tooltip counts are on). Move the mouse off it.
6. Right-click that item. Expected: the title shows `Saved items can't be used from here. Shift-click links one in chat.`, and nothing else happens. Move the mouse off it.
7. Shift-click that item. Expected: its link appears in the chat box. Clear the chat box.
8. Type `ore` in the alt viewer's own search box. Expected: everything that is not ore is faded. Clear the box.
9. Click a section header in the alt viewer (for example `- Consumables`). Expected: it collapses to `+ Consumables`. Click it again to open it.
10. Type `/swagbag alts Nobody`. Expected: `SwagBag: No saved character named "Nobody". Saved: ` and your characters' names.
11. Press **Esc**. Expected: the alt viewer closes.
12. Type `/swagbag`, click `Alt data` on the left, then `Open the alt viewer`. Expected: the alt viewer opens on your character, and the bottom line says `Showing the saved items of <your name>.` Press **Esc** twice.
13. In combat at a training dummy, type `/swagbag alts`. Expected: it opens, with no error and no "blocked" message. Press **Esc**.
14. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors, `Blocked actions: none`.

Pass: steps 1–14. If a character you expected is missing from the list in step 3, tell Claude its name (note it).

Reply to Claude with: OF1 done, and the numbers of any steps that didn't match

## Week 5 exit check

The user ticks these in game after session OF1 and pastes the final `/swagbag report` to Claude:

1. [ ] Sessions L1, TH1, A1 and OF1 passed, or every failure was fixed and its step re-run.
2. [ ] The list view was used for at least one real play session (a key or a farming route) with no item used, sold or moved other than the one clicked.
3. [ ] A potion or food was used from a list row in combat (L1 step 8) without a "blocked" message. If one showed, Claude applied D4's fallback and the step was re-run.
4. [ ] The Blizzard look was unchanged from week 4 (TH1 steps 1 and 10).
5. [ ] Tooltip counts matched where the items are (A1 step 5), and the alt viewer showed another character's items (OF1 step 4).
6. [ ] Claude ran `scripts/check.sh` on the branch: `ALL CHECKS PASSED`, with 1115 or more passed and 0 failed. The branch is merged (week 4 first, then week 5) or kept, as the user chooses.

If a line fails, paste the report, and Claude fixes it before week 6 starts.

## What week 6 builds on

- The list view in the bank and guild bank windows (D9): `UI/ListRows.lua` and `Engine/Sort.lua` are window-agnostic. GroupView adds `cfg.view() == "list"`, a scale per button and a `ListRows` object per window.
- `SB.AltData` is the one place alt data comes from. A future "manage snapshots" page (spec §8.4) lists `AltData.Characters()` and deletes through `Engine/Snapshots.lua`.
- `SB.Theme.Register` takes more looks. Any new SwagBag frame registers with `Theme.Window/Text/Button` as it is made.
- The remaining ledger items: M5 no-op focus writes, the week-3 leftovers (shared bank-window shell W3-8, tabs added mid-visit, guild server refusals, caged pets in the guild bank, the xpcall stack in `ScanKind`), and a perf pass over §9 with the list view and the alt viewer open.

## Spec coverage (week-5 scope → task)

| Item (spec, brief) | Task |
|---|---|
| v1.3 list view: rows with name, count, ilvl, AH value | 1 (texts, values), 2 (rows in the bags window) |
| … sortable by name/count/ilvl/value, both directions, persisted; a column click answers (P2) | 1 (`Sort`), 3 (column bar, `/swagbag list`, Settings rows) |
| … a third view beside sections and grid, in the bags window; bank and guild later | 2 (D8, D9) |
| … values from Prices; bound and WuE at vendor (D11, W3-35) | 1 (`Sort.Value`) |
| … rows act on real items: the slot's own secure button, never made in combat, never reparented | 2 (D4; tests; session L1 steps 8–12) |
| … search dimming, overlays, focus modes (decided: they collapse the same sections), hover guard (rows hold), W10, footer bar | 2, 3 (D3, D5) |
| … grouping decided: one row per slot | 2 (D1) |
| … toggled by the view button, a settings row and a slash command | 2, 3 |
| §3.3 AltData with priority, three errors switch a provider off; built-in "Own" over Snapshots | 6 |
| v1.2 `Providers/Syndicator.lua` (priority 10), only while loaded and ready, through the Adapter, pcall'd | 7 (D11, D12) |
| AC13.3 tooltip counts, with a setting | 8 (D16, D17) |
| AC13.2 / Views.Offline: pick a character; its bags, bank, warband bank and guild bank, read only, with search; GroupView and plain display buttons | 9, 10 (D18–D21) |
| No Syndicator: everything from SwagBag's own snapshots | 6, 7 (tests "Own answers otherwise") |
| §3.2 Theme registry; AC14.1 default unchanged | 4 (D22, D23) |
| v1.3 Modern flat | 4 (D25) |
| v1.3 ElvUI-matching, auto-detected through the Adapter, refused without ElvUI | 5 (D26) |
| Themes restyle only SwagBag's own frames; live switch from a settings row and a slash command | 4 (D23, D24) |
| Week-4 deferred: drag/grow retry, OnDragStop → W.Resize, title-flash truncation, P6 and constraint wording, CurrencyList secret guard, default-anchor grow test | 3, 7, Global Constraints |

## How this plan was checked (while writing it)

- **Replay.** Every code block of Tasks 1–10 was applied in order to a fresh clone of `d759564` in a scratch folder outside the repo. For each task:
  - the Step 1 blocks were applied alone, and Step 2's `Expected` line is that red run;
  - then the Step 3 blocks were applied, and Step 5's `scripts/check.sh` gave the totals above (992 → 1115 passed, 0 failed), the stated `TOC OK` count and `ALL CHECKS PASSED`;
  - the final tree matched the reference build file for file.
- **Anchors.** Every find block occurs exactly once in its file at the point it is applied, starts and ends on a non-blank line, and was found by the replay. No step replaces a whole file.
- **Mutations.** Every mutation in the "Critical tests" tables was applied to the finished code of its task, and the named test failed: 53 runs.
- **Rules grep** on the final tree:
  - no `C_`/`Enum` outside `Core/Adapter.lua`, comments included;
  - no `OnUpdate` script, no forbidden token, no `SetCurrentGuildBankTab`;
  - no new `ContainerFrameItemButtonTemplate` (Task 10 Step 6).
- **Name check.** Every `SB.*` name a task uses exists on `d759564`, in an earlier task's **Produces** block, or in the same task. Task 1's `UI/ListRows.lua` and Task 2's window code reach `SB.Theme` only from Task 4's own edits, never before.
- **Placeholder scan.** No TBD, TODO or "similar to". Every step that changes code shows the code.
- **Review Focus.** Each of the five lines names the tests that pin it, in the tasks that own the code. Three of them (Task 2's "plain frames" test, Task 6's 25-character timing, Task 9's damaged line) were written for this section.
- **Syndicator and ElvUI.** Both are installed on the user's machine (Syndicator v284, ElvUI v13.97) and were read for public API names only (D12, D26). No code was copied.
