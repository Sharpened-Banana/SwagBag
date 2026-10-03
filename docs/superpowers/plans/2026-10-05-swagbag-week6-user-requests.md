# SwagBag Week 6: the User's Requests (Focus "front" style, a cleaner item, Deposit warbound, the bank's free tile). Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The four requests the user made on 2026-10-01, in their words:
1. "I like the idea of collapsing all of the categories when you are doing things but I think there should two options. The way we have it as one option, and the default option would keep all categories already opened, opened, but move the categories for the event being done to the top."
2. "look at the item screenshot ... with the ilvl, wue, h1/8. It is very cluttered. We might need to instead of putting boe, wue etc, make their own categories."
3. "bank should have a deposit all warband items" button.
4. "and it should have the same empty slot with a number in it idea" (the free-slot tile, in the bank).

**Tasks 7–9 (added 2026-10-03, from the user's in-game testing of 0.5.0):** six fixes.
1. Bags opened with B closed when the user walked away from a vendor (FM1 step 8). They now stay open, and `/swagbag report` gains the last five bag-hook calls.
2. The Pause button and the Focus modes page were not understood (S1, FM1). They get plain-words tooltips and an intro line. Quick setup explains Pause.
3. A long choice spilled out of its button on Settings > Alt data (O2 step 19). Buttons now fit their text and wrap to a new line.
4. The bank's `Blizzard's bank is shown for this visit` flash was never seen (V2 step 6). It now shows for 3 s and also goes to chat.
5. Bank open took 72–86 ms (budget 80 ms), and one character's snapshots were 40 KB. The bank now reads each slot once and reports where its open time goes. Repeated stacks are written once in snapshots, and the report splits the snapshot size by kind.
6. The footer's gold gets a full-size coin and a plain amount like `1,234,567` (FT1, O1).

**Architecture:** (1) `Engine/Focus.lua` gets a style, `focus.style = "front"` (the new default) or `"collapse"` (today's behaviour). In "front" style no mode collapses anything: `Focus.CollapsedView` returns the user's own set and `Focus.SectionOrder(order)` returns a new list with New, then the mode's sections, then everything else in its own order. `Engine/Layout.lua`'s `Position` takes that order as `opts.order`. The bags window keeps the order it last drew (`W.order`) beside the collapsed lookup it last drew (`W.view`, W4-1), and re-orders through the same `W.Restack`. So P5, the area hold (W4-13), W10, W4-1 and W4-16 hold for a re-order exactly as they do for a collapse, in the category view and the list view. `/swagbag mode style` and a Settings > Focus modes row write the setting. (2) `overlays.bind` defaults to `false`, and a built-in "Warbound until equipped" category (`c_wue`, `gear & wue`) sits next to "BoE gear". (3) The bank window gets SwagBag's own plain `Deposit warbound` button. It makes the same C call Blizzard's button makes, through the Adapter. Beside it is a `With reagents` box for Blizzard's own include-reagents setting. (4) The bank's free tile already works for both groups; Task 6 pins it with a test and the DP1 session shows the user where it is.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- the user's four requests above, which change spec §6.1/§6.4 and AC8.2 ("a mode collapses everything else"): that becomes the alternative style, and "front" becomes the default (D1, D15);
- spec §6 (focus modes) in the new style, with every §4.2 rule 5, §6.4 and W10 guarantee kept;
- spec F9 (overlays): the bind badge stays available, off by default, and §7.6 gains a built-in category; §8.5's "built-ins are never stored" diff system stays intact;
- spec F2 / §5.2–5.3 (the bank window, read-only towards Blizzard's bank state) with the deposit button, and W3-12/D19 (the free tile) in both bank groups;
- the week-5 ledger items deferred to week 6 that touch code this plan changes (see "Week-5 carry-overs").

Ledgers (binding rulings W3-*, W4-*, W5-*): `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md`, `docs/superpowers/plans/2026-10-03-swagbag-week4-ledger.md`, `docs/superpowers/plans/2026-10-04-swagbag-week5-ledger.md`. Week-5 plan (style and interfaces): `docs/superpowers/plans/2026-10-04-swagbag-views-syndicator-themes.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week6-requests` is already checked out. It was made from `week5-views` at `3d2421d`; week 5 is not merged to `main` yet. The suite has 1226 tests. No task creates or switches branches.

**The code at `3d2421d` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). These interfaces are used as they are on `3d2421d`:
- `SB.On`, `SB.Emit`, `SB.Debounce(key, delay, fn, window)`, `SB.ErrorTrap.Run/Guard/OnError(label, window, message, stack)`, `SB.Print`.
- `SB.Config.Get/Set/CharOverride/CharOverrideMany/IsCharOverride/UI/Defaults/readOnly/Init/Reset`. `Set` returns false while read-only, and every write emits `SB_CONFIG_CHANGED(path | nil)`. `Config.Get` reads a character override, then the saved account value, then `Config.Defaults`. Only values somebody wrote are stored.
- `SB.Focus`:
  - `MODES`, `byId`, `Sections(id, raw)`, `Active()`, `Expanded()` (cached), `CollapsedView(userSet)`, `Applies()`, `HeaderClick`, `Pin`, `OverrideOf`, `WindowClosed`, `Pause/Resume/IsPaused`, `Label()`;
  - `Recompute`, `Refresh`, `SetSignal`, and the writers `SetEnabled`, `SetSections`, `ResetSections`;
  - the `SB_CONFIG_CHANGED` listener that refreshes on `focus.*`.
- `SB.Layout.Build/Position/Moves/Apply`. `state.order` is New, the categories, then Free.
- `SB.Categories.Load/SectionOrder/Name/Get/ResetBuiltin`, `SB.CategoryDefaults`.
- `SB.BagsWindow`:
  - `W.view` (the drawn collapsed lookup, W4-1), `W.Restack(area)` with `W.areaHeld` (W4-13) and the M1 no-op shortcut;
  - `W.ApplyChanges`, `W.ToggleSection` (W4-16), `W.ClickSection`, `W.PinSection`, `W.TogglePause`;
  - the locals `snapshot`, `sameView`, `positionOpts`, `position`, `layoutSections`, `renderMoved`.
- `SB.BankWindow`: `BW.Flash`, `titleButton` (`BW.TitleButton`), `BW.Open`, `bagsOf`, `BW.view` (GroupView with `freeTile`), `BW.blizzardButton`, `frame.deposit`, `host` (TinyHost).
- `SB.Adapter`: `isSecret`, the local `location(bag, slot)`, `A.GetBagIDs`, `A.NumSlots`, `A.InCombat`, `A.Stack`, `A.CHECKS`. The mock is `spec/mock_adapter.lua`.
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua` (`Fake.New`, `Fake.Strict`, `Fake.Fire`), `uienv.lua` (`Env.ENGINE`, `Env.LoadBank`), `spec/fixtures/items.lua` (`Fixtures.SmallBags`), and `format51` (installed by the runner).

## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.6.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. To find Blizzard's names for the deposit (D11), five installed addons were read for **API names only**: Baganator 833, ElvUI, TradeSkillMaster, EllesmereUI and EnhanceQoL. No code of theirs is used.
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator, ElvUI`.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets a string or a number, never a boolean or nil. Every spec runs under `spec/helpers/format51.lua`, which makes the tests as strict as WoW.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace, `Enum` or another addon's globals, **comments included**. It is grep-enforced for `C_X.`/`Enum.` and review-enforced for bare names. Every other file calls `SB.Adapter.*`. Files under `spec/` may name them as test data.
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`. `SetCurrentGuildBankTab` is never called. (Task 5's Adapter comment describes the week-1 spike without writing the forbidden name.)
- P1: every setting ships with a chosen default, and its alternative sits next to it in the same place. Options are phrased as choices, never as abstract toggles.
- P2: every command, button and settings choice answers exactly once, with a chat line, a title flash or the settings window's status line. A title flash that is cut short also goes to chat: the bags window since week 5 (D27), and the bank window from Task 6. Silence is a bug.
- P5 / spec §4.2 rule 5: nothing moves under the mouse or while an item is on the cursor. Held moves retry 300 ms later through `SB.Debounce`, never `OnUpdate`. A move the world starts (a mode switch or re-order) also waits while the mouse is anywhere over the items (W4-13). In the list view a row counts as part of its button (week-5 D5).
- W10 / spec §6.4: applying a mode never moves a button relative to its own section header. A collapse changes section offsets. A "front" re-order changes the order of whole sections, each with its header and its cells (Task 2).
- **P6 (amended, week-5 deferred: F3, W5-2, and this week's labels).** Every WoW entry point runs inside `SB.ErrorTrap.Run` or `Guard`: events, hooks, frame scripts, timers, slash commands, and external callbacks (Syndicator's registry, the tooltip post-call). The window label is the one whose Safe Mode a failure there may flip:
  - `"bags"`: the bags window, its list rows' click handling and column bar, focus signals and the focus engine's listeners (including the `mode` slash command), and the consumables triggers;
  - `"bank"`: bank and guild code, including this week's `bank.depositWarband` button and `bank.depositReagents` box;
  - `"none"` (recorded for the report, never Safe Mode): settings, quick setup, themes, tooltip counts, alt data, the alt viewer, the list rows' tooltip scripts (week-5 F3, as D23), the list view's scale self-check (`bags.listScale`, W5-2), and a game error the deposit call returns (`bank.deposit`, recorded like `bank.sort`);
  - a command run from the settings window traps under that command's own window and label (W4-7), so a bank or guild row can put the bank in Safe Mode exactly as the typed command does;
  - known exception, unchanged: the consumables warning at key start traps as `"bags"`.
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`.
- **Secure frames (amended, week-5 deferred "BackdropTemplate"; week 6 adds one template):**
  - item buttons are never created in combat, never reparented, never re-`SetID`'d;
  - SwagBag's other frames are plain and may be created in combat. That means `Frame`; `Button` (with `UIPanelButtonTemplate`, `UIPanelCloseButton` or no template); `CheckButton` with `UICheckButtonTemplate` (the `With reagents` box, Task 6); `ScrollFrame`; `EditBox` (`SearchBoxTemplate`); and `"BackdropTemplate"`, a plain template SwagBag has used on its windows since week 1. They carry `FontString` and `Texture` regions;
  - the alt viewer's display buttons are plain `ItemButton`s with no template (week-5 D18);
  - nothing of Blizzard's bank is created, reparented or written by Task 6. Its tiny-mode moves (TinyHost) are unchanged.
- Themes restyle only SwagBag's own frames (week-5 D23). The new label goes through `SB.Theme.Text` and the new button through `SB.Theme.Button`. The check box keeps Blizzard's template look.
- A focus mode never writes the user's saved collapse state (`SwagBagCharDB.ui.collapsed`) or the user's category order (`SwagBagDB.categoryOrder`). In the "front" style a header click is the user's own collapse and is saved as one (D3). That is the user's action, not the mode's.
- **Settings (amended, week-5 deferred F14 "no schema bump" wording):**
  - every new settings key has a default in `Config.Defaults`. New this week: `focus.style` (`"front"`). Changed default: `overlays.bind` (`false`);
  - the schema stays 2. Settings are read through `Config.Get`, which falls back to `Config.Defaults`, so a new key or a new default needs no migration;
  - saved data outside `settings` that grows a field (week 5's `chars[key].guild`, F14) is read defensively (type-checked) and needs no bump either. A bump is needed only when an existing saved value must be converted, and nothing this week does that;
  - every new writer refuses while `Config.readOnly` and says `L.SETTINGS_READONLY`. The one write that is not SwagBag's setting is the `With reagents` box, which writes Blizzard's own game setting (D12).
- No file calls `Config` at load time (the load-order tests stay green). Every `OnHide` handler starts with `if self:IsShown() then return end`.
- No `OnUpdate` anywhere. Idle CPU with every window closed is 0.
- Every critical test names the mutation that must make it fail. Each task lists its mutations under Step 2.
- **Tooling (binding, as in weeks 1–5):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). Where a test fakes a frame method WoW has, it fakes it the way WoW behaves. CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Test totals are cumulative from 1226 (see "Schedule").
- One commit per task, made with `git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit`. The message ends with exactly these two lines:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`
- In-game checks are written for the user, who is not a programmer:
  - each session begins with "Claude installs the build first", followed by a full game restart (not `/reload`);
  - steps are numbered, one action per step, each saying exactly what the user should see;
  - quoted strings match `SwagBag/Locale/enUS.lua` exactly, and chat lines start with `SwagBag: `;
  - a step after a click on an item says to move the mouse off it.

  Sessions never block the build: findings come back as fixes.

## Review Focus

These are the five failure modes most likely to bite the user that the spec implies but does not spell out, most likely first, plus one the user hit in game (6, Task 7). Each is pinned by tests in the task that owns the code.

1. **A key, a vendor or a bank visit starts while the mouse rests on the bag ("front" style).** The re-order moves every section below New. Expected: nothing moves under the pointer. The re-order lands once the mouse leaves the items, and loot that arrives meanwhile lands in the order still drawn. Pinned by Task 2: "a re-order the world started waits while the mouse is anywhere over the items, then applies" and "loot during a held re-order lays out in the drawn order: nothing moves under the mouse".
2. **A header click during a key ("front" style).** Expected: it is the user's own collapse, it stays after the key, and nothing the mode does writes the saved collapse set or the category order. Pinned by:
   - Task 1: "never writes the order it is given; leaving the mode gives the same order back";
   - Task 2: "a header click in a mode is the user's own collapse: saved, no peek, and it stays after the mode";
   - Task 2: "a vendor visit moves Junk, Trade Goods and BoE gear up and collapses nothing; leaving puts them back" (it checks the saved set and `categoryOrder`).
3. **Deposit warbound while an item could still be refunded, or while the game cannot say, the warband bank is in use, or the player is in combat.** Expected: nothing is deposited, and the reason is said (P2). Blizzard's own button, which asks first, is one click away. Pinned by:
   - Task 5: "RefundableForWarband finds a refundable item the warband bank would take; nil when it cannot tell";
   - Task 6: "it refuses in combat, while the warband bank is busy, and when a refund could be lost; each says why".
4. **An existing user updates.** Saved settings and a saved category order from quick setup are already there. Expected: the badge is off unless they saved it on. "Warbound until equipped" appears right after "BoE gear", not after "Other". Their edits to built-ins survive. Pinned by Task 4:
   - "the BoE/WuE badge is off by default; a user who saved it on keeps it";
   - "a built-in added later joins a saved order right after the one it follows (WuE after BoE gear)";
   - "Warbound until equipped keeps a user's rename as a diff; reset restores it".
5. **A long answer in the bank's bounded title.** The refund refusal is about 150 characters, and the title is cut short at the title buttons (W3-26). Expected: the whole line also goes to chat. Pinned by Task 6: "a long answer cut short in the bank title also goes to chat".
6. **Bags the user opened, then a vendor that closes by walking away (FM1 step 8, seen in game).** Expected: the bags stay open; a vendor-opened window still closes with the vendor. Pinned by Task 7:
   - "CloseAllBags() with no frame leaves a window the user opened open";
   - "a bag toggle inside a vendor's CloseAllBags that closed the user's window opens it again";
   - "CloseAllBags() with no frame still closes a window the game opened";
   - the trace test, and session TF1 steps 3–6.

## Decisions and resolved spec ambiguities (read before Task 1)

| # | Request or spec text | This plan | Why |
|---|---|---|---|
| D1 | "two options … the default option would keep all categories already opened, opened, but move the categories for the event being done to the top" | Setting `focus.style`: `"front"` (**default**), `"collapse"` (today's behaviour). Every user gets "front" after the update. Nobody has a saved `focus.style` yet, so `Config.Get` falls back to the new default. | The user's words name the default. P1: the alternative sits in the same row and the same command. |
| D2 | "move the categories for the event being done to the top" | `Focus.SectionOrder(order)` returns: New; then the deciding modes' sections (`Focus.Front()`), each once, in the mode's own order (merge: the first mode's, then the next one's new ones; priority: the strongest mode's); then every other section in its own order, with Free last. A section the bag does not have is skipped. Nothing moves while paused, while `focus.auto` is off, or while a deciding mode expands everything (at the bank, where the "collapse" style also opens everything). | "Right after New" keeps New's promise (new loot is first) and keeps Free last (spec §4.3). The mode's own list order is what the user edits on the Focus modes page. |
| D3 | "decide what peek and pin mean in 'front' style, and justify it" | **No peek, pin or close in "front" style.** A left-click or right-click on a header is the user's own collapse or expand, saved per character exactly as without a mode. `Focus.Applies()` is true only in the "collapse" style, so `HeaderClick` and `Pin` return false and `W.ClickSection`/`W.PinSection` fall through to `W.ToggleSection` (W4-16: it decides from the drawn view). There is no "(peek …)" suffix. | Peek and pin exist because in the "collapse" style the mode owns what is open, and the user needs a temporary way past it. In "front" the mode owns nothing about open or closed. What is open is the user's own state, which the user asked to keep ("keep all categories already opened, opened"). A temporary peek would bring back the forgetting the user objected to. A saved click is what the user expects from a header. A mode still never writes the set: the click does. |
| D4 | "Every existing guarantee still applies to the re-order" | The bags window keeps `W.order`, the section order `W.pos` was drawn in, beside `W.view` (W4-1). `layoutSections`, `W.Restack` and `W.ApplyChanges` all position with it. Only a re-stack that runs switches it. The M1 no-op shortcut compares the order too. `Layout.Position(state, opts, collapsed)` reads `opts.order or state.order`. Each section is drawn whole with its header, so a button's offset to its header never changes (W10). | One code path for collapse and re-order. Every hold (P5, W4-13 area hold, W4-1 drawn view, W4-16 drawn header, W4-25 grow) applies to both with no new rule. |
| D5 | "the list view (week 5): sections are re-ordered the same way; grid view: only the title changes" | The list view draws through the same `position`, so it re-orders identically and each row follows its button. The grid has no sections: a mode changes only its title (week-4 D10), pinned again for the new style. | Week-5 D2/D3: the list is the category view drawn as rows. |
| D6 | "Add the setting to Settings > Focus modes and to a slash form … It must answer (P2) and refuse when read-only" | `/swagbag mode style` (shows the style and how to type it), `/swagbag mode style front`, and `/swagbag mode style collapse`. A wrong word gets the style and how to type it. Settings > Focus modes, second row: `While a mode is on`: `Move to the top` / `Collapse the rest`. Both go through `Focus.SetStyle`, which refuses unknown words and read-only. `focus.style` joins `SF.Paths()`, so "This character" covers it. The peek row now reads `Collapse style: a click on a collapsed section`. | One writer, two places, the same answers. |
| D7 | — (week-4 deferred M5 "no-op focus writes re-stack") | The Focus writers (`SetEnabled`, `SetSections`, `SetStyle`) write nothing when the value is already in force. No `SB_CONFIG_CHANGED` is emitted, so no re-stack runs. `SetStyle` still answers and still refuses while read-only. | Cheap now that `Focus.lua` changes anyway. M1 already made such a re-stack harmless; this removes the work. |
| D8 | "`overlays.bind` defaults to false … anyone who explicitly saved it keeps their value. Check how Config stores defaults versus saved values" | `Config.Defaults.settings.overlays.bind = false`. `Config.Set` stores only a value somebody wrote (`/swagbag overlays bind on\|off`, the Overlays page; quick setup never writes `overlays.bind`). `Config.Get` returns a saved value first, then the default. So a user who never touched the badge sees it off after the update, and one who saved `on` (or `off`) keeps it. No migration. | Verified in `SwagBag/Core/Config.lua` (`Get`: override, then `db.settings`, then `Defaults`) and by grep: nothing writes `overlays.bind` but the user's own switches. |
| D9 | "Add a built-in 'Warbound until equipped' category … Keep the category-defaults/diff system intact … Check whether keyword support exists for wue" | `c_wue`, name `Warbound until equipped`, query `gear & wue`, priority 74 (above Gear 70, below BoE gear 75; `boe` and `wue` never match the same item), displayOrder 45 (after BoE gear's 40). A new `after = "c_boe"` field places it right after BoE gear in a **saved** category order (quick setup writes the whole list). Without that it would land after Other. Built-ins are still never stored, and a rename is a `userEdits` diff (spec §8.5). The `wue` keyword and its alias `warbound until equipped` already exist (week 2, `Engine/Keywords.lua`), so nothing is added there. Market mode's sections stay `c_junk,c_tradegoods,c_boe`: warbound gear can't be sold on the AH. | The user's "make their own categories". The `after` field mirrors W4-23 (a footer entry added later joins at its default neighbour). |
| D10 | "Re-check the overlay layout without the badge: does the item level / track text need the space back? Keep the Task-11 constants" | No. The badge sat at `LEFT` (the middle of the left edge). The item level is `TOPLEFT` and the track `BOTTOMLEFT`, so turning the badge off frees the middle and nothing moves. `FONT_SIZE` 13, `BIND_SIZE` 11 and `TEXT_WIDTH` 33 stay. A test pins the corners and sizes. | No code change, so no new risk. Session OV1 step 3 is the eye check. |
| D11 | "Preferred design: re-host Blizzard's own button … If calling C_Bank.AutoDepositItemsIntoBank from an addon is known to be safe … justify the choice against the week-1 spike finding" | **SwagBag's own plain button, `Deposit warbound`, calls `Adapter.DepositWarband()`, which is `pcall(C_Bank.AutoDepositItemsIntoBank, Enum.BankType.Account)`.** Blizzard's own control is `BankPanel.AutoDepositFrame.DepositButton`, with `IncludeReagentsCheckbox` beside it (the names ElvUI's skin uses). Its label is `ACCOUNT_BANK_DEPOSIT_BUTTON_LABEL` ("Deposit All Warbound Items"). It is not re-hosted. The full reasoning is under "Blizzard's deposit control". | Re-hosting risks Blizzard's own click code failing or the control appearing in the wrong place. Item safety and taint come first. |
| D12 | "Also include Blizzard's 'include reagents' checkbox only if it is part of that control" | It is part of it (`AutoDepositFrame.IncludeReagentsCheckbox`), so it is included as SwagBag's `With reagents` box. It shows and switches Blizzard's own setting, `bankAutoDepositReagents`, which is the setting Blizzard's box reads and writes and the one the game's deposit obeys. It goes through `Adapter.DepositReagents/SetDepositReagents`, and is hidden when the game cannot say. It is not refused while SwagBag's settings are read-only, because it is not SwagBag's setting. | The user gets the whole control in tiny mode, where Blizzard's frame is invisible. Spec §5.2–5.3 forbid writing Blizzard's **bank state** (tab, bank type, close), and a deposit preference is not that. ElvUI writes the same setting from its options. |
| D13 | "the free-slot tile in the bank … Verify it works for the character bank AND the warband bank groups, and the reagent-tab case" | It already works (week-3 W3-12/D19, `UI/BankWindow.lua` `freeTile`, GroupView builds each group with `family = Adapter.BagFamily`). Bank tabs report no bag family. In 12.1, reagent storage is a bank tab with a deposit filter, not a reagent bag. So every tab of a group is family `"any"`, and the group shows **one** tile whose number counts the free slots of all its tabs. Task 6 adds a test with two character tabs and two warband tabs, and session DP1 shows the user where to look. | Nothing missing, so nothing changes in GroupView. That is also why the guild bank's pending-item gap (week-5 ledger) is not touched this week (see "Week-5 carry-overs"). |
| D14 | — (P2 in the bank window) | `BW.Flash` also prints to chat when the bounded title (W3-26) cuts the text short. This is the bags window's D27 (week 5). | The deposit's refusals are long. A truncated answer is no answer. |
| D15 | Spec §6.1 "collapse everything except …", AC8.2 | The spec's wording now describes the "collapse" style. The user's request (binding) makes "front" the default. The spec text is updated at week end, recorded in the ledger. This plan commits only the plan file. | The ledgers bind, the user's request outranks the spec's wording, and executors read this table first. |
| D16 | FM1 step 8: "walked out of vendor range, the bags closed" (they were opened with B); "a window the user opened stays open whenever any game frame's CloseAllBags runs … decide what CloseAllBags() with nil frame should do" | **Who opened the window decides.** A window the user opened (B, a bag icon) is closed only by the user: B, Esc or the X. No `CloseAllBags` closes it, **with a frame or without one**. A window the game opened (its open-all-bags call named a frame) closes with that frame's `CloseAllBags`, or with a `CloseAllBags()` that names no frame. When the open call named no frame, any `CloseAllBags` closes it, as before. A bag toggle that runs inside a frame's `CloseAllBags` and closes the user's window opens it again in the same frame, as `onOpenAll` already does for its inner toggle. `CloseAllBags()` inside the bag key itself (ToggleAllBags) changes nothing: the key's own toggle closes the window, once. The last five hook calls (hook, argument, what SwagBag did, time) go to `/swagbag report`. | Blizzard's FrameXML is not on disk, so the walk-away path cannot be read. Both explanations that fit (a frameless close, or a toggle inside the vendor's close) are closed. Blizzard's own bags survive a vendor that did not open them, which is what the user expects. The frameless close's other callers that matter are the bag key (handled by its own toggle) and other addons' "close all bags". Those now leave a user-opened window alone. That cost is accepted: a user-opened window is the user's. Esc still closes it through `UISpecialFrames`. Session TF1 step 6 reads the trace, so the next week knows which path it was. |
| D17 | V2 step 6: "the title flash was never seen" | `BW.Flash(text, seconds, toChat)`. The Blizzard bank button's answer shows 3 s (`BW.VISIT_FLASH`) and is printed once in chat. A line that is also cut short in the title still prints once. Other bank flashes keep 1.5 s (`BW.FLASH`) and print only when cut short (D14). | The window jumps beside Blizzard's bank on that click, so the eye is elsewhere for the first second. Chat is where a missed answer can be read again (P2). |
| D18 | S1/FM1: "did not understand Pause/Resume and the Focus modes page" | One generic mechanism: a row's `tip` (and an item's own `tip`) shows on hover over its buttons in every settings page. Settings > Focus modes: an intro note, and a tip on every row with buttons (including Task 3's style row and every section row). Pause tooltip: title `Pause focus modes` (or `Resume focus modes` while paused), one plain sentence, and the right-click line kept. Quick setup: one line under the slots-per-row buttons. | Tooltips cost no space and never move a row. One builder change serves later pages too. The intro is the user's own sentence, lightly adapted. |
| D19 | O2 step 19: "Shown (not twice with Syndicator)" spills, next button cut | Each button is `max(row/item width or SW.BUTTON, text width + SW.TEXT_PAD)`, capped at the line. A button that would cross the line starts the next line (`SW.ROW + SW.LINE_GAP` lower), and the rows below move down. | Generic: fixes every page, keeps today's minimum widths (no visual change where text fits), and needs no per-page width tuning. |
| D20 | "Bank open layout ~72–86 ms (target ≤ 80 ms)… find the hot spots … if you can't justify a concrete code change, make this instrumentation" | One concrete change: the bank's `describe` passes the slot it read to `Items.Describe(bag, slot, s)`, so each slot is read once, not twice (2,156 → 1,078 client reads for a full bank). Plus instrumentation: `GroupView` records the parts of every full layout, and the report prints `Bank layout parts: tabs …, reading …, categories …, positions …, drawing …`. Not done: skipping per-item client calls (item level, toy, quest, cooldown lookups) for some item kinds. Each changes a field some search keyword reads, so it waits for the numbers. | Reading the code proves the double read and nothing else. The other costs are client calls whose real price only the game shows. The mock makes every call cost the same, so a mock timing would mislead. |
| D21 | "Snapshot 40 KB for one character (target ~30 KB) … schema stays 2; reading old snapshots must keep working" | A link that an earlier slot of the same container holds is written `slot:=thatSlot;count`. `Deserialize` reads both forms, so every snapshot saved before still reads the same (tested), and the schema stays 2. A snapshot's `v` stays 1: `v` names the container layout (`{ size, s }`), which is unchanged. Not done: shortening links (the colour code or the name), because the alt viewer's shift-click puts the saved link into chat, and a shortened link may not post. The report adds `Snapshot sizes: bags …, banks …, warband …, guild banks …`. | Repeated stacks are common in a gold-maker's banks: 10 stacks each of two herbs go from 1,591 to 358 bytes. The 30 KB aim is not promised. The split shows where the bytes are. A downgrade to 0.5.0 would read a pointed-to stack as an unknown item, and the next save rewrites it. Accepted. |
| D22 | FT1/O1: "gold needs a proper gold-coin icon … silver and copper move into the tooltip" | The gold entry is a 14-px coin (`F.ICON`, the same as the currencies and crests) and the whole gold with `,` separators (`F.GoldText`). The tooltip is `Gold on this character` and `Adapter.MoneyText` of the full amount. The texture is the file path `Interface\MoneyFrame\UI-GoldIcon`, a string rather than a Blizzard global, so it stays in `Footer.lua`. | English only (the addon's scope), so `,` is the separator. One widget path for every footer icon keeps the sizes equal. |

## Blizzard's deposit control (what was found, and what needs an in-game check)

Blizzard's FrameXML is not on disk. These names come from knowledge of 11.x/12.x and from five installed addons, read for **names only** (they run on Interface 120100):
- **The control.** `BankPanel.AutoDepositFrame.DepositButton` and `BankPanel.AutoDepositFrame.IncludeReagentsCheckbox` (ElvUI `Mainline/Modules/Skins/Bags.lua` skins exactly these). `BankPanel` is Blizzard's bank panel inside `BankFrame` and serves both bank types. The button's text follows the selected bank type: `ACCOUNT_BANK_DEPOSIT_BUTTON_LABEL` ("Deposit All Warbound Items") for the warband bank, and `CHARACTER_BANK_DEPOSIT_BUTTON_LABEL` ("Deposit All Reagents") for the character bank (EnhanceQoL). The box's label is `BANK_DEPOSIT_INCLUDE_REAGENTS_CHECKBOX_LABEL`, and its mixin is `BankPanelIncludeReagentsCheckboxMixin`. Baganator and EnhanceQoL put that mixin on their own boxes, so the box is not tied to its parent.
- **The call.** `C_Bank.AutoDepositItemsIntoBank(bankType)`. Baganator 833 calls it from a plain XML `OnClick` with `Enum.BankType.Account`, and TradeSkillMaster, ElvUI, EllesmereUI and EnhanceQoL do the same. So it is callable from addon code and is not protected.
- **The setting.** The CVar `bankAutoDepositReagents` (ElvUI's options read it with `GetCVarBool` and write it with `SetCVar`).
- **Availability.** `C_Bank.FetchBankLockedReason(Enum.BankType.Account)` is non-nil while another character of the account holds the warband bank (Baganator hides its deposit button then). `C_Bank.CanUseBank(bankType)` is EnhanceQoL's guard.
- **Refunds.** Before depositing, EnhanceQoL checks every bag item with `C_Bank.IsItemAllowedInBankType(bankType, itemLocation)` and `C_Item.CanBeRefunded(itemLocation)`, and shows Blizzard's `ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM` popup if any match. So Blizzard's own button asks before a deposit ends a refund, and the bare C call does not.

**Why SwagBag's own button and not a re-host.** Week 3 re-hosted `BankFrame.TabSystem`, which works because a tab button reaches its owner through fields set at load, not through its parent. Nothing on disk shows how `DepositButton`'s click finds its bank panel. If it walks `self:GetParent()`, a re-hosted button would raise an error inside Blizzard's code on the user's click. Blizzard also lays out and shows/hides `AutoDepositFrame` with the bank type, and could re-anchor it against the 0.001-scale panel, putting it in a strange place. A plain SwagBag button avoids both risks.

**Why the C call is safe against the week-1 spike finding.** The spike's taint came from calling the bank frame's **Lua** tab method from addon code. That method wrote fields on Blizzard's frame, and Blizzard's secure item click later read those fields, so `UseContainerItem` became tainted. `C_Bank.AutoDepositItemsIntoBank` is a C function. Called from SwagBag, it writes no Lua field of any Blizzard frame. SwagBag passes the warband bank type explicitly, so Blizzard's selected bank type is neither read for the deposit nor set. The only cost of the bare call is Blizzard's refund confirmation, which SwagBag replaces with a refusal (`Adapter.RefundableForWarband`; nothing is deposited and Blizzard's button is named). If the game cannot say, SwagBag also refuses.

**Combat.** Whether Blizzard's own button works in combat is unknown. SwagBag refuses in combat, as Sort does (W11, nothing queued). The bank is rarely open in combat, and moving items mid-fight helps nobody.

**What needs an in-game check (session DP1):**
- No "Interface action failed" or "blocked" message after a deposit, and a right-click deposit of a bag item still works afterwards (the spike's symptom). Steps 10 and 12.
- `FetchBankLockedReason` and `CanUseBank` do not refuse a usable warband bank (step 10), and `/swagbag report` lists none of the new checks as failed (step 20).
- `CanBeRefunded`, `IsItemAllowedInBankType` and `DoesItemExist` answer, with no false "can't tell" (step 10).
- The CVar name: SwagBag's `With reagents` box matches Blizzard's `Include Reagents` box and changes it (steps 8 and 14).
- `UICheckButtonTemplate` draws a tick box (step 3).
- Blizzard's labels as the user sees them, `Deposit All Warbound Items` and `Include Reagents` (step 7; looked at, not used).

## Week-5 carry-overs (from `docs/superpowers/plans/2026-10-04-swagbag-week5-ledger.md`, "Final: deferred → week 6")

| Ledger item | Where |
|---|---|
| "amend P6/no-schema-bump/BackdropTemplate constraint wording" | Global Constraints above: **P6** (F3 row tooltips and W5-2 `bags.listScale` under `"none"`; this week's labels), **Secure frames** (`BackdropTemplate` named; `UICheckButtonTemplate` added), **Settings** (F14: what needs a schema bump and what does not). |
| "guild bank pending-item relayout gap" (fix "if GroupView is touched") | **Not this week.** Tasks 1–6 do not change `UI/GroupView.lua`: the free tile already works (D13). Task 9 adds only timing to GroupView's full layout (D20). Nothing is drawn differently, and the relayout path the gap lives in is untouched. Week 7, with "list view for bank/guild windows (D9)", which rewrites GroupView's drawing anyway. |
| "list view for bank/guild windows (D9)" | Not this week (see above). |
| "Syndicator loaded mid-session callbacks" | Not this week: no task touches `Providers/Syndicator.lua`. |
| In-game: F6 SetScale in combat (L1 step 14), IsTruncated timing, ElvUI media timing, ItemButton template-less behaviour | Still in `docs/superpowers/plans/2026-10-04-swagbag-week5-checklists.md` (L1, TH1, OF1). This plan adds no step for them. Task 6 relies on `IsTruncated` the same way the bags window does, so L1's answer covers both. |
| Week-4 deferred "M5 no-op focus writes re-stack" (week-5 plan: "Week 6") | Task 1 (D7). |

---

## File structure (end of week 6)

New and changed files only. Everything else is as on `3d2421d`.

```
SwagBag/Engine/Focus.lua               MOD  (T1) Style, Front, SectionOrder, Applies, SetStyle, writers skip no-ops (M5); (T3) /swagbag mode style
SwagBag/Engine/Layout.lua              MOD  (T2) Position reads opts.order
SwagBag/UI/BagsWindow.lua              MOD  (T2) W.order, W.EffectiveOrder, sameOrder; Layout/Restack/ApplyChanges draw with the order;
                                            (T8) the Pause tooltip
SwagBag/UI/SettingsFocus.lua           MOD  (T3) the style row; focus.style in Paths; (T8) intro note, every row's tip
SwagBag/Core/Report.lua                MOD  (T3) the Focus line names the style; "collapsing" follows Applies();
                                            (T7) Bag hooks line; (T9) Bank layout parts, Snapshot sizes
SwagBag/Core/Config.lua                MOD  (T1) focus.style; (T4) overlays.bind = false
SwagBag/Engine/CategoryDefaults.lua    MOD  (T4) c_wue, the `after` field
SwagBag/Engine/Categories.lua          MOD  (T4) a built-in with `after` joins a saved order after its neighbour
SwagBag/Core/Adapter.lua               MOD  (T5) WarbandDepositState, RefundableForWarband, DepositWarband, DepositReagents, SetDepositReagents, CHECKS
SwagBag/UI/BankWindow.lua              MOD  (T6) Deposit warbound, With reagents, Flash to chat when cut short;
                                            (T7) Flash(text, seconds, toChat), ToggleVisit 3 s + chat; (T9) describe reads once
SwagBag/UI/SafeModeHooks.lua           MOD  (T7) D16 ownership rule, toggleClosedUsers, the trace (TraceText)
SwagBag/UI/SettingsWindow.lua          MOD  (T8) row/item tip, SW.ShowTip, buttons fit their text and wrap
SwagBag/UI/QuickSetup.lua              MOD  (T8) the Pause note
SwagBag/Engine/Items.lua               MOD  (T9) Describe(bag, slot, s)
SwagBag/UI/GroupView.lua               MOD  (T9) stats.phases
SwagBag/Engine/Snapshots.lua           MOD  (T9) "=slot" repeats, BytesByKind
SwagBag/UI/Footer.lua                  MOD  (T9) gold coin, GoldText, money tooltip
SwagBag/Locale/enUS.lua                MOD  (T3, T4, T6, T7, T8, T9)
SwagBag/SwagBag.toc, SwagBag/Core/Init.lua   MOD  (T1) 0.6.0
.luacheckrc                            MOD  (T5) C_CVar
spec/adapter_bank_spec.lua             NEW  (T5)
spec/focus_spec.lua (T1, T3), bagswindow_sections_spec.lua (T1, T2, T4), bagswindow_list_spec.lua (T1, T2),
spec/settings_focus_spec.lua, signals_spec.lua (T3), overlays_spec.lua, categories_spec.lua, categorizer_spec.lua,
spec/bankwindow_groups_spec.lua, guildbank_spec.lua, offline_spec.lua (T4), mock_adapter.lua (T5),
spec/bankwindow_spec.lua (T6, T7), bankwindow_groups_spec.lua (T6, T9), safemodehooks_spec.lua (T7),
spec/report_spec.lua (T7, T9), settings_spec.lua, quicksetup_spec.lua (T8), settings_focus_spec.lua (T3, T8),
spec/bagswindow_sections_spec.lua (T8), snapshots_spec.lua, footer_spec.lua (T9)                       MOD
```

No file is added to `SwagBag/`, so the TOC keeps 62 files (`TOC OK (62 files)` after every task).

## Schedule (week 6)

The user plays keys daily, so the focus style comes first and is testable after Task 3.

| Day | Tasks | User in game? |
|---|---|---|
| 1 | 1, 2, 3 | **yes:** session FS1 (focus "front" style, about 10 minutes, at a vendor; one step at the next key) |
| 1 | 4 | **yes:** session OV1 (the cleaner item and the new category, about 5 minutes) |
| 2 | 5, 6 | **yes:** session DP1 (Deposit warbound and the bank's free tile, about 10 minutes, at a banker) |
| 3 | 7, 8, 9 (the fixes from the 0.5.0 testing) | **yes:** session TF1 (the fixes, about 10 minutes, at a vendor and a banker); **Week 6 exit check** |

Cumulative `scripts/check.sh` test totals (from 1226 on `3d2421d`). Each was produced by replaying this file's blocks in order on a fresh clone of `3d2421d`:
- T1 1234 passed, 0 failed (+8)
- T2 1242 passed, 0 failed (+8)
- T3 1244 passed, 0 failed (+2)
- T4 1248 passed, 0 failed (+4)
- T5 1252 passed, 0 failed (+4)
- T6 1258 passed, 0 failed (+6)
- T7 1264 passed, 0 failed (+6)
- T8 1268 passed, 0 failed (+4)
- T9 1274 passed, 0 failed (+6)

## How to read the code steps

- A **Create** step gives a complete new file.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point and its replacement. The block occurs exactly once in the file, and has at least one line a reader can recognise. When a step edits one file in several places, the places are numbered "(edit N of M)". Apply them in that order, top to bottom. Each find block is unique in the file as it is after the earlier edits.
- No step replaces a whole existing file. Blocks begin and end on non-blank lines (a block may begin with a closing `end)` of the test above it).
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks (everything else). Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists its critical tests and, for each, the code change (mutation) that must make it fail. Every mutation was applied to the finished code of its task and the named test failed. A reviewer re-runs any of them with a one-line edit.
- A test that passes at Step 2 is named there with the reason: it pins behaviour that already exists.

---
### Task 1: The focus style in the engine (`Engine/Focus.lua`), v0.6.0

User request 1, the engine half. `Focus.Style()` reads `focus.style` (`"front"` by default). In "front" style, `Focus.CollapsedView` returns the user's own set, `Focus.Applies()` is false (so there is no peek, pin or close; D3), and `Focus.SectionOrder(order)` puts the deciding modes' sections right after New (D2). `Focus.Front()` is cached with `Expanded()`. `Focus.SetStyle` is the one writer. The Focus writers no longer write a value that is already in force (week-4 M5, D7). Every existing focus test pins the "collapse" style it was written for. The version goes to 0.6.0.

**Files:**
- Modify: `SwagBag/Engine/Focus.lua` (header comment, `invalidate`, new `Style`/`Front`/`SectionOrder`, `CollapsedView`, `Applies`, `write`, `SetEnabled`, `SetSections`, new `SetStyle`)
- Modify: `SwagBag/Core/Config.lua` (`focus.style`)
- Modify: `SwagBag/SwagBag.toc`, `SwagBag/Core/Init.lua` (0.6.0)
- Test: `spec/focus_spec.lua` (pin "collapse"; the W4-10 test's last line; new block "Focus front style (week 6)"), `spec/bagswindow_sections_spec.lua` and `spec/bagswindow_list_spec.lua` (pin "collapse" where a test needs a mode that collapses)

**Interfaces:**
- Consumes: `Focus.Expanded()`, `deciding()`, `Focus.Sections(id)`, `SB.Config.Get/Set/readOnly`.
- Produces (Tasks 2 and 3 rely on these):
  - `Focus.Style() -> "front" | "collapse"`;
  - `Focus.Front() -> { sectionId } | nil` (never `"new"` or `"free"`);
  - `Focus.SectionOrder(order) -> order`: the very same table when nothing moves, otherwise a new list; never writes `order`;
  - `Focus.Applies() -> bool`, true only in the "collapse" style while a mode applies;
  - `Focus.SetStyle(style) -> true | false, "unknown" | "readonly"`;
  - the setting `focus.style`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_list_spec.lua` (edit 1 of 2), find:

```lua
	end)

	-- AC8.2 in the list view: same sections, same mode sets.
	it("a focus mode collapses the same sections as in the category view", function()
		W.Open()
		SB.Focus.SetSignal("challengeMode", true)
```

and replace it with:

```lua
	end)

	-- AC8.2 in the list view: same sections, same mode sets (the collapse style, week 4).
	it("a focus mode collapses the same sections as in the category view", function()
		SB.Config.Set("focus.style", "collapse")
		W.Open()
		SB.Focus.SetSignal("challengeMode", true)
```

In `spec/bagswindow_list_spec.lua` (edit 2 of 2), find:

```lua
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		CreateFrame = function(kind) return newFake(kind) end
```

and replace it with:

```lua
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		SB.Config.Set("focus.style", "collapse") -- the grow tests need a mode that collapses (week 4)
		Fixtures.SmallBags(A)
		CreateFrame = function(kind) return newFake(kind) end
```

In `spec/bagswindow_sections_spec.lua`, find:

```lua
		SB.Config.Set("bags.newAlways", true) -- New's reserved rows, as these tests were written
		CreateFrame = function(kind) return newFake(kind) end
```

and replace it with:

```lua
		SB.Config.Set("bags.newAlways", true) -- New's reserved rows, as these tests were written
		SB.Config.Set("focus.style", "collapse") -- these tests pin the collapse style (week 4); see "front" below
		CreateFrame = function(kind) return newFake(kind) end
```

In `spec/focus_spec.lua` (edit 1 of 3), find:

```lua
		SB.Config.Init(nil, nil)
		F = SB.Focus
```

and replace it with:

```lua
		SB.Config.Init(nil, nil)
		-- These tests pin the "collapse" style (week 4's behaviour, now the alternative); the default
		-- "front" style has its own block below. Set before the listener, so no event is counted.
		SB.Config.Set("focus.style", "collapse")
		F = SB.Focus
```

In `spec/focus_spec.lua` (edit 2 of 3), find:

```lua
		assert.same({ "new", "c_junk" }, openIds())
		SB.Config.Reset()
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear" }, openIds())
	end)
```

and replace it with:

```lua
		assert.same({ "new", "c_junk" }, openIds())
		SB.Config.Reset() -- the defaults again: the "front" style, and M+'s own sections in front
		assert.falsy(F.Applies(), "front collapses nothing")
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Front())
	end)
```

In `spec/focus_spec.lua` (edit 3 of 3), find:

```lua
		assert.truthy(perCall < 0.5, ("%.3f ms per Recompute"):format(perCall))
	end)
end)
```

and replace it with:

```lua
		assert.truthy(perCall < 0.5, ("%.3f ms per Recompute"):format(perCall))
	end)
end)

-- Week 6, user request 1: the "front" style (the default). An active mode collapses nothing; its
-- sections are drawn first, right after New, in the mode's order. The "collapse" style above is the
-- alternative.
describe("Focus front style (week 6)", function()
	local SB, F, events
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		F = SB.Focus
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason)
			events[#events + 1] = reason
		end)
	end)

	-- Mutation: in Config.Defaults, focus.style = "collapse".
	it("is the default: a running key collapses nothing and moves M+'s sections up, right after New", function()
		local user = { c_junk = true }
		F.SetSignal("challengeMode", true)
		assert.equal("front", F.Style())
		assert.falsy(F.Applies())
		assert.equal(user, F.CollapsedView(user), "the user's own collapse set, as it is")
		assert.same({ "new", "c_consumables", "c_keystone", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
			"c_leathercloth", "c_fish", "c_cooking", "c_tools", "c_junk", "c_other", "free" }, F.SectionOrder(ORDER))
		assert.equal("M+", F.Label(), "the title still names the mode")
	end)

	-- Mutation: in SectionOrder, table.insert into `order` itself instead of building `out`.
	it("never writes the order it is given; leaving the mode gives the same order back", function()
		local order = { unpack(ORDER) }
		F.SetSignal("challengeMode", true)
		F.SectionOrder(order)
		assert.same(ORDER, order, "the category order is untouched")
		F.SetSignal("challengeMode", false)
		assert.equal(order, F.SectionOrder(order), "no mode: the very same list")
		assert.is_nil(SB.Config.db.categoryOrder)
	end)

	-- Mutation: in computeFront, drop the `seen` check.
	it("merge: two modes move both sets up, each section once, the first mode's first", function()
		F.SetSignal("challengeMode", true)
		F.SetSignal("instanceType", "raid") -- Raid opens Consumables and Gear: already in front
		F.SetSignal("fishing", true)
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_fish", "c_cooking" }, F.Front())
		SB.Config.Set("focus.resolve", "priority")
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Front(), "priority: M+ only (mode order)")
	end)

	-- Mutation: in SectionOrder, append every id of Front() whether or not order has it.
	it("a section the bag does not have is skipped; New and Free keep their places", function()
		F.SetSignal("fishing", true)
		assert.same({ "new", "c_cooking", "c_gear", "c_junk", "free" },
			F.SectionOrder({ "new", "c_gear", "c_cooking", "c_junk", "free" }))
		assert.same({ "c_gear", "free" }, F.SectionOrder({ "c_gear", "free" }), "no New: nothing is added")
	end)

	-- Mutation: in computeFront, drop the expandAll check.
	it("the bank moves nothing; pause and switching modes off move nothing", function()
		F.SetSignal("merchantOpen", true)
		assert.same({ "c_junk", "c_tradegoods", "c_boe" }, F.Front())
		F.SetSignal("bankOpen", true)
		assert.is_nil(F.Front(), "at the bank everything stays where it is")
		F.SetSignal("bankOpen", false)
		F.Pause()
		assert.is_nil(F.Front())
		assert.equal(ORDER, F.SectionOrder(ORDER))
		F.Resume()
		SB.Config.Set("focus.auto", false)
		assert.is_nil(F.Front())
	end)

	-- Mutation: Applies() returns Expanded() ~= nil (ignores the style).
	it("a header click or right-click is the user's own: HeaderClick and Pin refuse, no override is kept", function()
		F.SetSignal("challengeMode", true)
		assert.falsy(F.HeaderClick("c_junk", true))
		assert.falsy(F.Pin("c_junk"))
		assert.is_nil(F.OverrideOf("c_junk"))
	end)

	-- Mutations: drop SetStyle's readOnly check (the M5 skip then answers true for the value already in
	-- force while read-only); drop the `write` skip (M5), so a repeat emits.
	it("SetStyle switches live, refuses unknown words and read-only, and a repeat writes nothing (M5)", function()
		F.SetSignal("challengeMode", true)
		events = {}
		assert.truthy(F.SetStyle("collapse"))
		assert.same({ "settings" }, events)
		assert.truthy(F.Applies())
		assert.is_nil(F.Front())
		assert.truthy(F.SetStyle("collapse"), "a repeat still answers")
		assert.same({ "settings" }, events, "a repeat writes nothing, so nothing re-stacks")
		assert.same({ false, "unknown" }, { F.SetStyle("sideways") })
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { F.SetStyle("front") })
		assert.same({ false, "readonly" }, { F.SetStyle("collapse") }, "read-only refuses, even the same style")
		assert.equal("collapse", F.Style())
	end)

	-- M5 (week-4 deferred). Mutation: SetEnabled calls Config.Set directly again.
	it("a focus writer whose value is already in force emits nothing", function()
		assert.truthy(F.SetEnabled("mplus", true))
		assert.truthy(F.SetSections("mplus", { "c_consumables", "c_keystone", "c_gear" }))
		assert.same({}, events)
		assert.is_nil(SB.Config.db.settings.focus, "nothing was stored")
	end)
end)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1225 passed, 9 failed`, and the failures are exactly:
```text
FAIL spec/focus_spec.lua :: Focus > a character override or a reset of a focus setting updates the view (W4-10)
FAIL spec/focus_spec.lua :: Focus front style (week 6) > is the default: a running key collapses nothing and moves M+'s sections up, right after New
FAIL spec/focus_spec.lua :: Focus front style (week 6) > never writes the order it is given; leaving the mode gives the same order back
FAIL spec/focus_spec.lua :: Focus front style (week 6) > merge: two modes move both sets up, each section once, the first mode's first
FAIL spec/focus_spec.lua :: Focus front style (week 6) > a section the bag does not have is skipped; New and Free keep their places
FAIL spec/focus_spec.lua :: Focus front style (week 6) > the bank moves nothing; pause and switching modes off move nothing
FAIL spec/focus_spec.lua :: Focus front style (week 6) > a header click or right-click is the user's own: HeaderClick and Pin refuse, no override is kept
FAIL spec/focus_spec.lua :: Focus front style (week 6) > SetStyle switches live, refuses unknown words and read-only, and a repeat writes nothing (M5)
FAIL spec/focus_spec.lua :: Focus front style (week 6) > a focus writer whose value is already in force emits nothing
```
The tests that only pin `focus.style = "collapse"` pass already: before Task 1 the setting does not exist and the behaviour is the collapse style.

Critical tests and the mutation each must catch (applied to the finished Task 1 code):
- "is the default: …": in `Config.Defaults`, `style = "collapse"`.
- "never writes the order it is given …": in `SectionOrder`, replace `out[#out + 1] = id` (inside `for _, id in ipairs(front)`) with `table.insert(order, 2, id)`.
- "merge: two modes …": in `computeFront`, replace `if not seen[sid] then` with `if true then`.
- "a section the bag does not have is skipped …": in `SectionOrder`, replace `if present[id] then` with `if true then`.
- "the bank moves nothing …": in `computeFront`, delete the `if m.expandAll and m.expandAll(Focus.signals) then return nil end` block.
- "a header click or right-click is the user's own …": `Focus.Applies` returns `Focus.Expanded() ~= nil`.
- "SetStyle switches live …": delete the `elseif SB.Config.readOnly then return false, "readonly"` branch in `SetStyle`; separately, delete the `if SB.Config.Get(path) == value then return true end` skip in `write`.
- "a focus writer whose value is already in force emits nothing": the same `write` skip.

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Config.lua`, find:

```lua
		-- 6.4, default off); on.<mode>: each built-in mode (all on); sections.<mode>: the sections
		-- the mode opens, comma-separated category ids (New is always open).
		focus = { auto = true, resolve = "merge", peek = "peek", announce = false,
			on = { mplus = true, raid = true, delves = true, gathering = true, fishing = true, market = true },
```

and replace it with:

```lua
		-- 6.4, default off); on.<mode>: each built-in mode (all on); sections.<mode>: the sections
		-- the mode opens, comma-separated category ids (New is always open). style: "front" (default:
		-- a mode moves its sections to the top, right after New, and collapses nothing) | "collapse"
		-- (a mode collapses every section it does not open; week 4's behaviour). Week 6, user request.
		focus = { auto = true, resolve = "merge", peek = "peek", announce = false, style = "front",
			on = { mplus = true, raid = true, delves = true, gathering = true, fishing = true, market = true },
```

In `SwagBag/Core/Init.lua`, find:

```lua
SB.name = ADDON
SB.VERSION = "0.5.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "
```

and replace it with:

```lua
SB.name = ADDON
SB.VERSION = "0.6.0"
SB.CHAT_PREFIX = "|cff33ff99SwagBag|r: "
```

In `SwagBag/Engine/Focus.lua` (edit 1 of 9), find:

```lua
--                                                that expands everything: the bank)
--   Focus.CollapsedView(userSet) -> lookup       collapsed[id] for Layout.Position / Apply:
--                                                userSet itself when no mode applies
--   Focus.HeaderClick(id, collapsedNow) -> "peek" | "close"   a header click while a mode applies
```

and replace it with:

```lua
--                                                that expands everything: the bank)
--   Focus.Style() -> "front" | "collapse"         what an active mode does (focus.style, week 6):
--                                                "front" (default) moves its sections to the top and
--                                                collapses nothing; "collapse" collapses the rest
--   Focus.Front() -> { ids } | nil               "front" style: the sections the deciding modes move
--                                                up, in the modes' order (never New or Free), or nil
--   Focus.SectionOrder(order) -> order           the drawn section order: order itself, or in "front"
--                                                style New, then Front(), then the rest as they were
--   Focus.Applies() -> bool                      a mode's collapse set is in force ("collapse" style)
--   Focus.CollapsedView(userSet) -> lookup       collapsed[id] for Layout.Position / Apply:
--                                                userSet itself when no mode collapses ("front" too)
--   Focus.HeaderClick(id, collapsedNow) -> "peek" | "close"   a header click while a mode applies
```

In `SwagBag/Engine/Focus.lua` (edit 2 of 9), find:

```lua
--   Focus.SetSections(id, list) -> bool, Focus.ResetSections(id) -> bool, Focus.SetEnabled(id, on) -> bool
--   Focus.ListLines() -> { lines }               one chat line per mode (/swagbag mode list)
```

and replace it with:

```lua
--   Focus.SetSections(id, list) -> bool, Focus.ResetSections(id) -> bool, Focus.SetEnabled(id, on) -> bool
--   Focus.SetStyle(style) -> bool                "front" | "collapse"; false, "unknown" | "readonly"
-- A writer whose value is already in force writes nothing (no SB_CONFIG_CHANGED, so no re-stack:
-- week-4 deferred M5).
--   Focus.ListLines() -> { lines }               one chat line per mode (/swagbag mode list)
```

In `SwagBag/Engine/Focus.lua` (edit 3 of 9), find:

```lua
-- Settings (Core/Config.lua): focus.auto, focus.resolve ("merge" | "priority"), focus.peek
-- ("peek" | "keep"), focus.announce, focus.on.<id>, focus.sections.<id> (comma-separated ids).
local _, SB = ...
```

and replace it with:

```lua
-- Settings (Core/Config.lua): focus.auto, focus.resolve ("merge" | "priority"), focus.peek
-- ("peek" | "keep"), focus.announce, focus.on.<id>, focus.sections.<id> (comma-separated ids),
-- focus.style ("front" | "collapse"). In "front" style a mode never collapses anything: there is no
-- peek, pin or close, and a header click is the user's own collapse, saved as without a mode.
local _, SB = ...
```

In `SwagBag/Engine/Focus.lua` (edit 4 of 9), find:

```lua
local expandedCache, cacheValid = nil, false
local function invalidate()
	cacheValid = false
end
```

and replace it with:

```lua
local expandedCache, cacheValid = nil, false
local frontCache, frontValid = nil, false
local function invalidate()
	cacheValid, frontValid = false, false
end

function Focus.Style()
	return cfg("focus.style") == "collapse" and "collapse" or "front"
end
```

In `SwagBag/Engine/Focus.lua` (edit 5 of 9), find:

```lua
end

-- What Layout sees as collapsed. The user's own set while no mode applies; otherwise the mode's
-- set with this session's peeks, pins and closes on top. The user's saved set is never written.
function Focus.CollapsedView(userSet)
	local open = Focus.Expanded()
	if not open then
		return userSet
	end
```

and replace it with:

```lua
end

-- The sections the deciding modes move to the top in "front" style, each once, in the modes'
-- order (merge: the first mode's, then the next one's new ones). nil while no mode applies, in
-- "collapse" style, or while a deciding mode expands everything (the bank: nothing moves there).
local function computeFront()
	if Focus.Style() ~= "front" or Focus.paused or #Focus.active == 0 then
		return nil
	end
	local list, seen = {}, { new = true, free = true }
	for _, id in ipairs(deciding()) do
		local m = byId[id]
		if m.expandAll and m.expandAll(Focus.signals) then
			return nil
		end
		for _, sid in ipairs(Focus.Sections(id)) do
			if not seen[sid] then
				seen[sid] = true
				list[#list + 1] = sid
			end
		end
	end
	return list
end

-- Cached like Expanded(). Read only: callers never change the list.
function Focus.Front()
	if not frontValid then
		frontCache, frontValid = computeFront(), true
	end
	return frontCache
end

-- The order the sections are drawn in. order (New first, Free last, as Layout keeps it) is
-- returned as it is unless "front" style moves sections: then a new list with New, the mode's
-- sections that are in order, and every other id in its own order (Free stays last). A section the
-- mode names but the bag does not have is skipped. Nothing is saved: the user's category order and
-- collapse set are never written (W10: each section moves whole, with its header).
function Focus.SectionOrder(order)
	local front = Focus.Front()
	if not front or #front == 0 then
		return order
	end
	local present, moved, out = {}, {}, {}
	for _, id in ipairs(order) do
		present[id] = true
	end
	if present.new then
		out[1] = "new"
	end
	for _, id in ipairs(front) do
		if present[id] then
			out[#out + 1] = id
			moved[id] = true
		end
	end
	for _, id in ipairs(order) do
		if id ~= "new" and not moved[id] then
			out[#out + 1] = id
		end
	end
	return out
end

-- What Layout sees as collapsed. The user's own set while no mode collapses (none applies, paused,
-- or "front" style); otherwise the mode's set with this session's peeks, pins and closes on top.
-- The user's saved set is never written.
function Focus.CollapsedView(userSet)
	local open = Focus.Expanded()
	if not open or Focus.Style() ~= "collapse" then
		return userSet
	end
```

In `SwagBag/Engine/Focus.lua` (edit 6 of 9), find:

```lua
	end })
end

function Focus.Applies()
	return Focus.Expanded() ~= nil
end

function Focus.OverrideOf(id)
```

and replace it with:

```lua
	end })
end

-- A mode's collapse set is in force: peeks, pins and closes mean something only then.
function Focus.Applies()
	return Focus.Expanded() ~= nil and Focus.Style() == "collapse"
end

function Focus.OverrideOf(id)
```

In `SwagBag/Engine/Focus.lua` (edit 7 of 9), find:

```lua
end

function Focus.SetEnabled(id, on)
	local why = refuse(id)
```

and replace it with:

```lua
end

-- M5: a value already in force is not written again (no event, so nothing re-stacks).
local function write(path, value)
	if SB.Config.Get(path) == value then
		return true
	end
	return SB.Config.Set(path, value)
end

function Focus.SetEnabled(id, on)
	local why = refuse(id)
```

In `SwagBag/Engine/Focus.lua` (edit 8 of 9), find:

```lua
	end
	if not SB.Config.Set("focus.on." .. id, on and true or false) then
		return false, "readonly"
```

and replace it with:

```lua
	end
	if not write("focus.on." .. id, on and true or false) then
		return false, "readonly"
```

In `SwagBag/Engine/Focus.lua` (edit 9 of 9), find:

```lua
	end
	if not SB.Config.Set("focus.sections." .. id, table.concat(list, ",")) then
		return false, "readonly"
```

and replace it with:

```lua
	end
	if not write("focus.sections." .. id, table.concat(list, ",")) then
		return false, "readonly"
	end
	return true
end

-- "front" (move the mode's sections to the top, collapse nothing) or "collapse" (week-4 behaviour).
function Focus.SetStyle(style)
	if style ~= "front" and style ~= "collapse" then
		return false, "unknown"
	elseif SB.Config.readOnly then
		return false, "readonly"
	end
	if not write("focus.style", style) then
		return false, "readonly"
```

In `SwagBag/SwagBag.toc`, find:

```text
## Author: lonezebra
## Version: 0.5.0
## SavedVariables: SwagBagDB
```

and replace it with:

```text
## Author: lonezebra
## Version: 0.6.0
## SavedVariables: SwagBagDB
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1234 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1234 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Focus.lua SwagBag/Core/Config.lua SwagBag/SwagBag.toc SwagBag/Core/Init.lua \
  spec/focus_spec.lua spec/bagswindow_sections_spec.lua spec/bagswindow_list_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 1: focus style in the engine (front by default, collapse as the option), M5 no-op writes, v0.6.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 2: The bags window draws the mode's sections first (category view and list view)

User request 1, the window half (D4, D5). `Layout.Position` reads `opts.order`. The bags window keeps the order it drew (`W.order`) next to the collapsed lookup it drew (`W.view`). `layoutSections`, `W.Restack` and `W.ApplyChanges` all position with it, and the M1 shortcut compares it. A re-order is then just another re-stack: the hover guard, the area hold for world-started switches (W4-13), the drawn view (W4-1), the drawn header (W4-16) and W10 all apply with no new rule. The list view uses the same code path. The grid view only changes its title, as before.

**Files:**
- Modify: `SwagBag/Engine/Layout.lua` (`Position`)
- Modify: `SwagBag/UI/BagsWindow.lua` (fields, `OnHide`, `W.EffectiveOrder`, `positionOpts`, `position`, `layoutSections`, `W.Layout`, `sameOrder`, `W.Restack`, `W.ApplyChanges`)
- Test: `spec/bagswindow_sections_spec.lua` (new block "BagsWindow focus front style (week 6)"), `spec/bagswindow_list_spec.lua` (one test)

**Interfaces:**
- Consumes: `Focus.SectionOrder(order)` (Task 1), `Focus.Applies()` (Task 1, through `W.ClickSection`).
- Produces: `Layout.Position(state, opts, collapsed)` with `opts.order` (a list of section ids; default `state.order`); `W.order` (the drawn order, or nil while nothing is laid out); `W.EffectiveOrder(state) -> order`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_list_spec.lua`, find:

```lua
		assert.equal("- Consumables (2) - 25s vendor", header("c_consumables").text.text)
		assert.falsy(row(6).shown, "junk's row is hidden with its section")
		assert.truthy(row(1).shown)
	end)

	-- AC5.1. Mutation: in W.SetDimmed, drop the W.rows.SetDimmed call.
```

and replace it with:

```lua
		assert.equal("- Consumables (2) - 25s vendor", header("c_consumables").text.text)
		assert.falsy(row(6).shown, "junk's row is hidden with its section")
		assert.truthy(row(1).shown)
	end)

	-- Week 6, the "front" style in the list: the same re-order, and each row stays beside its button.
	-- Mutation: in W.Restack, position(W.state, view) without the order.
	it("a mode in the front style moves its sections up in the list too; every row follows its button", function()
		W.Open()
		SB.Focus.SetSignal("merchantOpen", true)
		assert.equal("- Junk (1)", headers()[1])
		assert.equal("- Gear (1)", headers()[5])
		assert.truthy(row(6).shown and row(4).shown, "nothing collapses")
		assert.equal(B.Get(0, 6).y, rowY(6), "Junk's row moved with its button")
		assert.truthy(rowY(6) > rowY(5), "Junk is above Keystone now")
	end)

	-- AC5.1. Mutation: in W.SetDimmed, drop the W.rows.SetDimmed call.
```

In `spec/bagswindow_sections_spec.lua`, find:

```lua
end)

describe("BagsWindow load order", function()
	it("loads before Config.Init without touching Config", function()
```

and replace it with:

```lua
end)

-- Week 6, user request 1: the "front" style, the default. A mode collapses nothing: the user's own
-- open and collapsed sections stay as they are, and the mode's sections are drawn first, right after
-- New. Each section moves whole with its header (W10), and every week-4 hold applies (P5, W4-13, W4-1).
describe("BagsWindow focus front style (week 6)", function()
	local SB, A, W, B, F
	before_each(function()
		local files = { unpack(FILES) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- potion, flask, BoE ring, soulbound helm, keystone, junk
		SB.Config.Set("bags.newAlways", true) -- New keeps its rows, so it is drawn first as in the game
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
		-- Like the client: a hovered item button lies inside the scroll frame.
		W.scroll.IsMouseOver = function(self)
			if self.mouseOver == true then
				return true
			end
			for _, list in pairs(B.buttons) do
				for _, b in pairs(list) do
					if b.shown and rawget(b, "mouseOver") == true then
						return true
					end
				end
			end
			return false
		end
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		UIParent, UISpecialFrames, IsControlKeyDown = nil, nil, nil
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

	local function bagUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag or 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function click(id, mouseButton)
		header(id).scripts.OnClick(header(id), mouseButton or "LeftButton")
	end

	-- Every shown button's offset to its own section's header (W10).
	local SECTION_OF = { [1] = "c_consumables", [2] = "c_consumables", [3] = "c_boe", [4] = "c_gear",
		[5] = "c_keystone", [6] = "c_junk" }
	local function offsets()
		local out = {}
		for slot, id in pairs(SECTION_OF) do
			out[slot] = B.Get(0, slot).y - header(id).points[1][5]
		end
		return out
	end

	local USER = { "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "- BoE gear (1)",
		"+ Junk (1)", "- Free (10)" }
	local MARKET = { "- New (0)", "+ Junk (1)", "- BoE gear (1)", "- Keystone & Crests (1)", "- Consumables (2)",
		"- Gear (1)", "- Free (10)" }

	-- Mutations: W.EffectiveOrder returns st.order; or Restack's M1 shortcut checks sameView only
	-- (nothing collapses in "front", so the re-order would never be drawn).
	it("a vendor visit moves Junk, Trade Goods and BoE gear up and collapses nothing; leaving puts them back",
		function()
			W.Open()
			W.ToggleSection("c_junk") -- the user's own choice, saved
			F.SetSignal("merchantOpen", true)
			assert.same(MARKET, headers(), "Junk stays collapsed: the user's choice")
			assert.truthy(B.Get(0, 4).shown, "Gear stays open")
			assert.equal("SwagBag — AH/Vendor/Bank", W.frame.title.text)
			assert.same({ c_junk = true }, SB.Config.UI().collapsed.bags, "the saved set is untouched")
			assert.is_nil(SB.Config.db.categoryOrder, "the category order is untouched")
			F.SetSignal("merchantOpen", false)
			assert.same(USER, headers())
		end)

	-- Mutation: in Layout.Position, iterate st.order instead of opts.order or st.order.
	it("W10: a re-order keeps every button at the same offset to its own header", function()
		W.Open()
		local before = offsets()
		F.SetSignal("merchantOpen", true)
		assert.equal("- Junk (1)", headers()[2], "the re-order was drawn")
		assert.same(before, offsets())
		assert.truthy(B.Get(0, 6).y > B.Get(0, 5).y, "Junk is drawn above Keystone now")
	end)

	-- W4-13 / P5. Mutation: in W.Restack, drop `area == true or` from `wait` (only a moving button holds).
	it("a re-order the world started waits while the mouse is anywhere over the items, then applies", function()
		W.Open()
		W.scroll.mouseOver = true -- over a gap: no button under the mouse
		F.SetSignal("merchantOpen", true)
		assert.equal("- Keystone & Crests (1)", headers()[2], "held: still the user's order")
		A.Advance(W.RETRY)
		assert.equal("- Keystone & Crests (1)", headers()[2], "still held while the mouse stays")
		W.scroll.mouseOver = false
		A.Advance(W.RETRY)
		assert.equal("- Junk (1)", headers()[2], "applied once the mouse left")
	end)

	-- W4-1. Mutation: in W.ApplyChanges, position with W.EffectiveOrder(st) instead of W.order.
	it("loot during a held re-order lays out in the drawn order: nothing moves under the mouse", function()
		W.Open()
		local ring = B.Get(0, 3)
		local x, y = ring.x, ring.y
		ring.mouseOver = true -- BoE gear would move up under the vendor
		F.SetSignal("merchantOpen", true)
		A.Put(0, 10, Fixtures.HERB, 20) -- an arrival: ApplyChanges runs
		bagUpdate()
		assert.equal("- New (1)", header("new").text.text, "the arrival was drawn")
		assert.same({ x, y }, { ring.x, ring.y }, "the hovered ring has not moved")
		assert.equal("- Keystone & Crests (1)", headers()[2], "the drawn order is kept")
		ring.mouseOver = false
		A.Advance(W.RETRY)
		assert.equal("- Junk (1)", headers()[2], "the re-order applies once the mouse leaves")
	end)

	-- Mutation: Focus.Applies() returns Expanded() ~= nil (a click would peek and save nothing).
	it("a header click in a mode is the user's own collapse: saved, no peek, and it stays after the mode",
		function()
			W.Open()
			F.SetSignal("challengeMode", true)
			click("c_gear")
			assert.equal("+ Gear (1)", header("c_gear").text.text, "no peek suffix")
			assert.same({ c_gear = true }, SB.Config.UI().collapsed.bags, "saved like any click without a mode")
			click("c_keystone", "RightButton")
			assert.equal("+ Keystone & Crests (1)", header("c_keystone").text.text, "a right-click collapses too")
			F.SetSignal("challengeMode", false)
			assert.equal("+ Gear (1)", header("c_gear").text.text, "the user's choice stays")
		end)

	-- Pins week-4 behaviour for the new style (no code change makes it fail on its own).
	it("Pause draws the user's order again and Resume moves the mode's sections back up", function()
		W.Open()
		F.SetSignal("merchantOpen", true)
		W.TogglePause()
		assert.equal("- Keystone & Crests (1)", headers()[2])
		W.TogglePause()
		assert.equal("- Junk (1)", headers()[2])
	end)

	-- Pins week-4 D10 for the new style: the grid view has no sections, only the title changes.
	it("in the grid view a mode changes only the title", function()
		SB.Config.Set("bags.view", "grid")
		W.Open()
		local x, y = B.Get(0, 6).x, B.Get(0, 6).y
		F.SetSignal("merchantOpen", true)
		assert.equal("SwagBag — AH/Vendor/Bank", W.frame.title.text)
		assert.same({ x, y }, { B.Get(0, 6).x, B.Get(0, 6).y })
		assert.same({}, headers())
	end)
end)

describe("BagsWindow load order", function()
	it("loads before Config.Init without touching Config", function()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1236 passed, 6 failed`, and the failures are exactly:
```text
FAIL spec/bagswindow_list_spec.lua :: BagsWindow list view > a mode in the front style moves its sections up in the list too; every row follows its button
FAIL spec/bagswindow_sections_spec.lua :: BagsWindow focus front style (week 6) > a vendor visit moves Junk, Trade Goods and BoE gear up and collapses nothing; leaving puts them back
FAIL spec/bagswindow_sections_spec.lua :: BagsWindow focus front style (week 6) > W10: a re-order keeps every button at the same offset to its own header
FAIL spec/bagswindow_sections_spec.lua :: BagsWindow focus front style (week 6) > a re-order the world started waits while the mouse is anywhere over the items, then applies
FAIL spec/bagswindow_sections_spec.lua :: BagsWindow focus front style (week 6) > loot during a held re-order lays out in the drawn order: nothing moves under the mouse
FAIL spec/bagswindow_sections_spec.lua :: BagsWindow focus front style (week 6) > Pause draws the user's order again and Resume moves the mode's sections back up
```
Two new tests pass already, and they pin behaviour that exists after Task 1:
- "a header click in a mode is the user's own collapse …": Task 1's `Applies()` already sends the click to `W.ToggleSection`;
- "in the grid view a mode changes only the title": week-4 D10.

Critical tests and the mutation each must catch (applied to the finished Task 2 code):
- "a vendor visit moves Junk, Trade Goods and BoE gear up …": `W.EffectiveOrder` returns `st.order`; separately, in `W.Restack` replace `sameView(view, W.view) and sameOrder(order, W.order)` with `sameView(view, W.view)` (nothing collapses in "front", so the re-order would never be drawn).
- "W10: a re-order keeps every button …": in `Layout.Position`, `for _, id in ipairs(st.order) do`.
- "a re-order the world started waits …": in `W.Restack`, `local wait = W.areaHeld` (drop `area == true or`).
- "loot during a held re-order …": in `W.ApplyChanges`, `W.pos = position(st, W.view, W.EffectiveOrder(st))`.
- "a header click in a mode is the user's own collapse …": `Focus.Applies` returns `Focus.Expanded() ~= nil`.
- "a mode in the front style moves its sections up in the list too …": in `W.Restack`, `local pos = position(W.state, view)`.

- [ ] **Step 3: Write the implementation**

In `SwagBag/Engine/Layout.lua` (edit 1 of 2), find:

```lua
--   state.newShown is false (hideEmptyNew and nothing has arrived since the last Build).
--   opts: { columns, size, gap, padding, header, sectionGap, top }   top: y offset where the
--   layout starts (a window that stacks several layouts, default 0); height includes it.
--   pos = { cells = { {bag, slot, x, y, shown} } (display order), byKey = { [key] = cell },
```

and replace it with:

```lua
--   state.newShown is false (hideEmptyNew and nothing has arrived since the last Build).
--   opts: { columns, size, gap, padding, header, sectionGap, top, order }   top: y offset where the
--   layout starts (a window that stacks several layouts, default 0); height includes it.
--   order: the section ids in the order to draw them (default state.order). A focus mode's "front"
--   style passes Focus.SectionOrder(state.order): each section moves whole, with its header (W10).
--   pos = { cells = { {bag, slot, x, y, shown} } (display order), byKey = { [key] = cell },
```

In `SwagBag/Engine/Layout.lua` (edit 2 of 2), find:

```lua
	local y = (opts.top or 0) + pad
	for _, id in ipairs(st.order) do
		local sec = st.sections[id]
```

and replace it with:

```lua
	local y = (opts.top or 0) + pad
	for _, id in ipairs(opts.order or st.order) do
		local sec = st.sections[id]
```

In `SwagBag/UI/BagsWindow.lua` (edit 1 of 12), find:

```lua
	view = nil, -- sections view: the collapsed lookup W.pos was built with (what is drawn, W4-1)
	drawn = "sections", -- the view the current layout was drawn in (the setting may change before a held layout)
```

and replace it with:

```lua
	view = nil, -- sections view: the collapsed lookup W.pos was built with (what is drawn, W4-1)
	order = nil, -- sections view: the section order W.pos was built with (what is drawn, W4-1)
	drawn = "sections", -- the view the current layout was drawn in (the setting may change before a held layout)
```

In `SwagBag/UI/BagsWindow.lua` (edit 2 of 12), find:

```lua
	W.state, W.pos, W.view, W.sortPending, W.sortSawUpdate, W.dragging = nil, nil, nil, false, false, false
	W.areaHeld, W.scaleWarned = false, false
	W.ClearDropGuard()
```

and replace it with:

```lua
	W.state, W.pos, W.view, W.sortPending, W.sortSawUpdate, W.dragging = nil, nil, nil, false, false, false
	W.order, W.areaHeld, W.scaleWarned = nil, false, false
	W.ClearDropGuard()
```

In `SwagBag/UI/BagsWindow.lua` (edit 3 of 12), find:

```lua
end

-- A frozen copy of a collapsed lookup for the sections in st (the only ids Layout reads), so
-- W.view stays what is drawn: a later header toggle or mode switch changes only the live
```

and replace it with:

```lua
end

-- The order the sections are drawn in: the layout's own (New, the categories, Free), or with a focus
-- mode in the "front" style its sections right after New (Engine/Focus.lua). A fresh list, asked
-- for every layout and re-stack; the category order itself is never written.
function W.EffectiveOrder(st)
	return SB.Focus and SB.Focus.SectionOrder(st.order) or st.order
end

-- A frozen copy of a collapsed lookup for the sections in st (the only ids Layout reads), so
-- W.view stays what is drawn: a later header toggle or mode switch changes only the live
```

In `SwagBag/UI/BagsWindow.lua` (edit 4 of 12), find:

```lua
end

local function positionOpts()
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
```

and replace it with:

```lua
end

local function positionOpts(order)
	if isList() then -- one column of rows, each as tall as its (scaled) button
		return { columns = 1, size = W.LIST_ROW, gap = W.LIST_GAP, padding = W.PAD, header = W.SECTION_HEADER,
			sectionGap = W.SECTION_GAP, order = order }
	end
	return { columns = columns(), size = W.SLOT, gap = W.GAP, padding = W.PAD, header = W.SECTION_HEADER,
		sectionGap = W.SECTION_GAP, order = order }
end

-- Layout.Position for the drawn view and section order. A list is LIST_WIDTH wide (its single
-- column of cells is only an icon wide; the rows' texts fill the rest).
local function position(st, view, order)
	local pos = SB.Layout.Position(st, positionOpts(order), view)
	if isList() then
		pos.width = W.LIST_WIDTH
```

In `SwagBag/UI/BagsWindow.lua` (edit 5 of 12), find:

```lua
	W.view = snapshot(W.state, W.EffectiveCollapsed())
	W.pos = position(W.state, W.view)
	return render()
```

and replace it with:

```lua
	W.view = snapshot(W.state, W.EffectiveCollapsed())
	W.order = W.EffectiveOrder(W.state)
	W.pos = position(W.state, W.view, W.order)
	return render()
```

In `SwagBag/UI/BagsWindow.lua` (edit 6 of 12), find:

```lua
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -W.HeaderHeight())
	W.records, W.state, W.pos, W.view, W.areaHeld = {}, nil, nil, nil, false
	B.ReleasePlaceholders(child)
```

and replace it with:

```lua
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -W.HeaderHeight())
	W.records, W.state, W.pos, W.view, W.order, W.areaHeld = {}, nil, nil, nil, nil, false
	B.ReleasePlaceholders(child)
```

In `SwagBag/UI/BagsWindow.lua` (edit 7 of 12), find:

```lua
-- that runs switches W.view, the lookup ApplyChanges lays out with (ruling W4-1).
-- area = true (a switch the world started, not the user's click): it also waits while the mouse
```

and replace it with:

```lua
-- that runs switches W.view, the lookup ApplyChanges lays out with (ruling W4-1).
-- In the "front" style a mode moves sections instead of collapsing them: the same cells, the
-- sections in another order (W.order, drawn like W.view), so every button keeps its offset to its
-- own header (W10) and the same holds apply to the re-order.
-- area = true (a switch the world started, not the user's click): it also waits while the mouse
```

In `SwagBag/UI/BagsWindow.lua` (edit 8 of 12), find:

```lua
end

-- Two collapsed lookups (snapshots) draw the same sections.
local function sameView(a, b)
```

and replace it with:

```lua
end

-- Two section orders are the same list of ids.
local function sameOrder(a, b)
	if not (a and b) or #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- Two collapsed lookups (snapshots) draw the same sections.
local function sameView(a, b)
```

In `SwagBag/UI/BagsWindow.lua` (edit 9 of 12), find:

```lua
	end
	local view = snapshot(W.state, W.EffectiveCollapsed())
	if area == true and sameView(view, W.view) then
		-- M1: the world asked for what is already drawn (or took back a switch still waiting):
```

and replace it with:

```lua
	end
	local view, order = snapshot(W.state, W.EffectiveCollapsed()), W.EffectiveOrder(W.state)
	if area == true and sameView(view, W.view) and sameOrder(order, W.order) then
		-- M1: the world asked for what is already drawn (or took back a switch still waiting):
```

In `SwagBag/UI/BagsWindow.lua` (edit 10 of 12), find:

```lua
	end
	local pos = position(W.state, view)
	local wait = area == true or W.areaHeld
```

and replace it with:

```lua
	end
	local pos = position(W.state, view, order)
	local wait = area == true or W.areaHeld
```

In `SwagBag/UI/BagsWindow.lua` (edit 11 of 12), find:

```lua
	local oldPos = W.pos
	W.pos, W.view, W.areaHeld = pos, view, false
	local width, height = renderMoved(oldPos, pos)
```

and replace it with:

```lua
	local oldPos = W.pos
	W.pos, W.view, W.order, W.areaHeld = pos, view, order, false
	local width, height = renderMoved(oldPos, pos)
```

In `SwagBag/UI/BagsWindow.lua` (edit 12 of 12), find:

```lua
		local oldPos = W.pos
		W.pos = position(st, W.view)
		local width, height = renderMoved(oldPos, W.pos)
```

and replace it with:

```lua
		local oldPos = W.pos
		W.pos = position(st, W.view, W.order)
		local width, height = renderMoved(oldPos, W.pos)
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1242 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1242 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Layout.lua SwagBag/UI/BagsWindow.lua spec/bagswindow_sections_spec.lua spec/bagswindow_list_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 2: the bags window draws a mode's sections first (front style), held like any re-stack

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 3: `/swagbag mode style`, Settings > Focus modes, and the report

User request 1, the switches (D6). `/swagbag mode style [front|collapse]` and a `While a mode is on` row both go through `Focus.SetStyle`. Both answer (P2) and both refuse while read-only. `focus.style` joins the "This character" paths. The report's Focus line names the style, and its "collapsing" word follows `Focus.Applies()`, so it says `no` in the "front" style. **Session FS1 runs after this task.**

**Files:**
- Modify: `SwagBag/Engine/Focus.lua` (slash section: `styleCommand`, the `mode` command)
- Modify: `SwagBag/UI/SettingsFocus.lua` (header comment, `SF.Paths`, the style row)
- Modify: `SwagBag/Core/Report.lua` (the Focus line)
- Modify: `SwagBag/Locale/enUS.lua` (`MODE_USAGE`, `HELP_MODE`, `MODE_STYLE_*`, `SET_FOCUS_STYLE*`, `SET_FOCUS_PEEK`)
- Test: `spec/focus_spec.lua`, `spec/settings_focus_spec.lua`, `spec/signals_spec.lua`

**Interfaces:**
- Consumes: `Focus.Style`, `Focus.SetStyle`, `Focus.Applies` (Task 1).
- Produces: the strings `L.MODE_STYLE_STATE` (one `%s`), `L.MODE_STYLE_NAME_FRONT`, `L.MODE_STYLE_NAME_COLLAPSE`, `L.MODE_STYLE_FRONT`, `L.MODE_STYLE_COLLAPSE`, `L.SET_FOCUS_STYLE`, `L.SET_FOCUS_STYLE_FRONT`, `L.SET_FOCUS_STYLE_COLLAPSE`, which session FS1 quotes.

- [ ] **Step 1: Write the failing tests**

In `spec/focus_spec.lua`, find:

```lua
	end)

	-- M5 (week-4 deferred). Mutation: SetEnabled calls Config.Set directly again.
	it("a focus writer whose value is already in force emits nothing", function()
```

and replace it with:

```lua
	end)

	-- P2: every form answers. Mutation: styleCommand returns nil for a word it does not know.
	it("/swagbag mode style answers every form: the style now, a switch, a wrong word, read-only", function()
		local L = SB.L
		SB.Slash.Dispatch("mode style")
		SB.Slash.Dispatch("mode style Collapse")
		SB.Slash.Dispatch("mode style sideways")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("mode style front")
		assert.same({ L.MODE_STYLE_STATE:format(L.MODE_STYLE_NAME_FRONT), L.MODE_STYLE_COLLAPSE,
			L.MODE_STYLE_STATE:format(L.MODE_STYLE_NAME_COLLAPSE), L.SETTINGS_READONLY }, SB.Adapter.Lines())
		assert.equal("collapse", F.Style())
	end)

	-- M5 (week-4 deferred). Mutation: SetEnabled calls Config.Set directly again.
	it("a focus writer whose value is already in force emits nothing", function()
```

In `spec/settings_focus_spec.lua` (edit 1 of 2), find:

```lua
		assert.truthy(selected("Junk", L.SET_SECTION_CLOSED))
	end)
```

and replace it with:

```lua
		assert.truthy(selected("Junk", L.SET_SECTION_CLOSED))
	end)

	-- Week 6, user request 1 (P1, P2). Mutations: the row's apply always answers MODE_STYLE_FRONT; drop
	-- "focus.style" from SF.Paths (This character would leave the style account-wide).
	it("the style row: Move to the top by default; Collapse the rest is saved, answers and re-stacks", function()
		assert.truthy(selected(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_FRONT))
		click(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_COLLAPSE)
		assert.equal("collapse", SB.Config.Get("focus.style"))
		assert.same({ "settings" }, events)
		assert.equal(L.MODE_STYLE_COLLAPSE, SW.lastStatus)
		assert.truthy(selected(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_COLLAPSE))
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		assert.truthy(SB.Config.IsCharOverride("focus.style"), "This character covers the style too")
		SB.Config.readOnly = true
		click(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_FRONT)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		assert.equal("collapse", SB.Config.Get("focus.style"))
	end)
```

In `spec/settings_focus_spec.lua` (edit 2 of 2), find:

```lua
		assert.truthy(SW.byId.focus.rows()[1].label == L.SET_FOCUS_AUTO)
		assert.falsy(SW.byId.focus.rows()[6].label:find("this character", 1, true))
	end)
```

and replace it with:

```lua
		assert.truthy(SW.byId.focus.rows()[1].label == L.SET_FOCUS_AUTO)
		assert.falsy(SW.byId.focus.rows()[7].label:find("this character", 1, true), "row 7: the first mode")
	end)
```

In `spec/signals_spec.lua` (edit 1 of 2), find:

```lua
describe("Report focus lines", function()
	it("names the mode, the resolve setting, the signals and the spells cast before loot", function()
		local SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
```

and replace it with:

```lua
describe("Report focus lines", function()
	-- Week 6. Mutation: Report passes yes(F.Expanded()) for "collapsing" again (yes in the front style too).
	it("names the mode, the resolve setting and style, the signals and the spells cast before loot", function()
		local SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
```

In `spec/signals_spec.lua` (edit 2 of 2), find:

```lua
		local text = SB.Report.Build()
		assert.truthy(text:find("Focus: M+ (merge); zone party, collapsing yes; M+ yes, keystone yes, delve no, fishing no, "
			.. "gathering no", 1, true), text)
		assert.truthy(text:find("Spells before loot (last 5): 3365", 1, true), text)
	end)
```

and replace it with:

```lua
		local text = SB.Report.Build()
		assert.truthy(text:find("Focus: M+ (merge, front); zone party, collapsing no; M+ yes, keystone yes, delve no, "
			.. "fishing no, gathering no", 1, true), text)
		assert.truthy(text:find("Spells before loot (last 5): 3365", 1, true), text)
		SB.Config.Set("focus.style", "collapse")
		text = SB.Report.Build()
		assert.truthy(text:find("Focus: M+ (merge, collapse); zone party, collapsing yes;", 1, true), text)
	end)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1241 passed, 3 failed`, and the failures are exactly:
```text
FAIL spec/focus_spec.lua :: Focus front style (week 6) > /swagbag mode style answers every form: the style now, a switch, a wrong word, read-only
FAIL spec/settings_focus_spec.lua :: Settings: focus modes page > the style row: Move to the top by default; Collapse the rest is saved, answers and re-stacks
FAIL spec/signals_spec.lua :: Report focus lines > names the mode, the resolve setting and style, the signals and the spells cast before loot
```
(The edited "This character" test, now reading row 7, passes before and after: row 7 is the first mode's row once the style row is in.)

Critical tests and the mutation each must catch (applied to the finished Task 3 code):
- "/swagbag mode style answers every form …": in `styleCommand`, wrap the last `return` in `if word == "" then … end` (a wrong word gets no answer).
- "the style row: …": the row's `apply` always returns `L.MODE_STYLE_FRONT`; separately, remove `"focus.style"` from `SF.Paths()`.
- "names the mode, the resolve setting and style …": in `Report.lua`, `yes(F.Expanded())` again.

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Report.lua`, find:

```lua
		end
		lines[#lines + 1] = L.REPORT_FOCUS:format(F.Label() or L.FOCUS_NONE, tostring(SB.Config.Get("focus.resolve")),
			tostring(s.instanceType or L.REPORT_NONE), yes(F.Expanded()),
			yes(s.challengeMode), yes(s.keystone), yes(s.delve), yes(s.fishing), yes(s.gathering))
```

and replace it with:

```lua
		end
		-- "(merge, front)": the resolve setting and the style; "collapsing" is yes only while a mode's
		-- collapse set is in force (the collapse style), never in the front style (week 6).
		lines[#lines + 1] = L.REPORT_FOCUS:format(F.Label() or L.FOCUS_NONE,
			tostring(SB.Config.Get("focus.resolve")) .. ", " .. F.Style(),
			tostring(s.instanceType or L.REPORT_NONE), yes(F.Applies()),
			yes(s.challengeMode), yes(s.keystone), yes(s.delve), yes(s.fishing), yes(s.gathering))
```

In `SwagBag/Engine/Focus.lua` (edit 1 of 2), find:

```lua
---------------------------------------------------------------------------
-- /swagbag mode [pause|resume|list] (spec 10.5). Every form answers (P2).
---------------------------------------------------------------------------
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- /swagbag mode [pause|resume|list|style [front|collapse]] (spec 10.5). Every form answers (P2).
---------------------------------------------------------------------------
```

In `SwagBag/Engine/Focus.lua` (edit 2 of 2), find:

```lua
end

SB.Slash.Register("mode", SB.L.HELP_MODE, function(arg)
	local L = SB.L
	arg = (arg or ""):lower()
	if arg == "pause" then
		return Focus.Pause() and L.MODE_PAUSED or L.MODE_ALREADY_PAUSED
```

and replace it with:

```lua
end

-- /swagbag mode style [front|collapse]: the style now, or switch it. A wrong word gets the style now
-- and how to type it; read-only settings refuse (P2).
local function styleCommand(word)
	local L = SB.L
	if word == "front" or word == "collapse" then
		if not Focus.SetStyle(word) then
			return L.SETTINGS_READONLY
		end
		return word == "front" and L.MODE_STYLE_FRONT or L.MODE_STYLE_COLLAPSE
	end
	return L.MODE_STYLE_STATE:format(Focus.Style() == "front" and L.MODE_STYLE_NAME_FRONT or L.MODE_STYLE_NAME_COLLAPSE)
end

SB.Slash.Register("mode", SB.L.HELP_MODE, function(arg)
	local L = SB.L
	arg = (arg or ""):lower()
	local word, rest = arg:match("^(%S*)%s*(.-)%s*$")
	if word == "style" then
		return styleCommand(rest)
	end
	if arg == "pause" then
		return Focus.Pause() and L.MODE_PAUSED or L.MODE_ALREADY_PAUSED
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 2), find:

```lua
L.MODE_STATUS = "Focus mode now: %s. Type /swagbag mode pause, resume or list."
L.MODE_USAGE = "Usage: /swagbag mode, /swagbag mode pause, /swagbag mode resume or /swagbag mode list"
L.MODE_LIST_LINE = "%s: %s%s - opens %s"
L.MODE_ACTIVE = ", active now"
L.HELP_MODE = "mode [pause|resume|list]: pause or resume focus modes for this session, or list them"
L.WATCH_FLASK = "Flask"
```

and replace it with:

```lua
L.MODE_STATUS = "Focus mode now: %s. Type /swagbag mode pause, resume or list."
L.MODE_USAGE = "Usage: /swagbag mode, /swagbag mode pause, /swagbag mode resume, /swagbag mode list or /swagbag mode style"
L.MODE_LIST_LINE = "%s: %s%s - opens %s"
L.MODE_ACTIVE = ", active now"
L.HELP_MODE = "mode [pause|resume|list|style]: pause or resume focus modes for this session, list them, or choose their style"
L.MODE_STYLE_STATE = "Focus style: %s. Type /swagbag mode style front or /swagbag mode style collapse."
L.MODE_STYLE_NAME_FRONT = "front (a mode moves its sections to the top)"
L.MODE_STYLE_NAME_COLLAPSE = "collapse (a mode collapses the rest)"
L.MODE_STYLE_FRONT = "Focus modes now move their sections to the top and leave every section open or collapsed as you set it."
L.MODE_STYLE_COLLAPSE = "Focus modes now collapse every section the mode does not need. A click on a collapsed one peeks."
L.WATCH_FLASK = "Flask"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 2), find:

```lua
L.SET_FOCUS_PRIORITY_DONE = "Two modes at once now open only the stronger one's (dungeon or activity before vendor)."
L.SET_FOCUS_PEEK = "A click on a collapsed section in a mode"
L.SET_FOCUS_PEEK_PEEK = "Peeks"
```

and replace it with:

```lua
L.SET_FOCUS_PRIORITY_DONE = "Two modes at once now open only the stronger one's (dungeon or activity before vendor)."
L.SET_FOCUS_STYLE = "While a mode is on"
L.SET_FOCUS_STYLE_FRONT = "Move to the top"
L.SET_FOCUS_STYLE_COLLAPSE = "Collapse the rest"
L.SET_FOCUS_PEEK = "Collapse style: a click on a collapsed section"
L.SET_FOCUS_PEEK_PEEK = "Peeks"
```

In `SwagBag/UI/SettingsFocus.lua` (edit 1 of 3), find:

```lua
-- SwagBag settings: the Focus modes page (spec 6, AC8.1-8.5, AC15.1). Switching modes on and
-- off, merge or strict priority, peek or keep open, announce, account-wide or this character
-- only, and each mode's section set with "Reset to default" next to it (spec 6.3). The bags
```

and replace it with:

```lua
-- SwagBag settings: the Focus modes page (spec 6, AC8.1-8.5, AC15.1). Switching modes on and
-- off, move to the top or collapse the rest (week 6), merge or strict priority, peek or keep open
-- (the collapse style), announce, account-wide or this character
-- only, and each mode's section set with "Reset to default" next to it (spec 6.3). The bags
```

In `SwagBag/UI/SettingsFocus.lua` (edit 2 of 3), find:

```lua
function SF.Paths()
	local paths = { "focus.auto", "focus.resolve", "focus.peek", "focus.announce" }
	for _, m in ipairs(SB.Focus.MODES) do
```

and replace it with:

```lua
function SF.Paths()
	local paths = { "focus.auto", "focus.style", "focus.resolve", "focus.peek", "focus.announce" }
	for _, m in ipairs(SB.Focus.MODES) do
```

In `SwagBag/UI/SettingsFocus.lua` (edit 3 of 3), find:

```lua
		end),
		setting(L.SET_FOCUS_RESOLVE, "focus.resolve", { { value = "merge", text = L.SET_FOCUS_MERGE },
```

and replace it with:

```lua
		end),
		-- Week 6: move the mode's sections up (default) or collapse the rest (the week-4 way). The same
		-- writer as /swagbag mode style, so both answer alike and refuse while read-only.
		{ kind = "choice", label = L.SET_FOCUS_STYLE, choices = { { value = "front", text = L.SET_FOCUS_STYLE_FRONT },
			{ value = "collapse", text = L.SET_FOCUS_STYLE_COLLAPSE } },
			get = F.Style,
			apply = function(v)
				local ok, why = F.SetStyle(v)
				if not ok then
					return refusal(why)
				end
				return v == "front" and L.MODE_STYLE_FRONT or L.MODE_STYLE_COLLAPSE
			end },
		setting(L.SET_FOCUS_RESOLVE, "focus.resolve", { { value = "merge", text = L.SET_FOCUS_MERGE },
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1244 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1244 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Focus.lua SwagBag/UI/SettingsFocus.lua SwagBag/Core/Report.lua SwagBag/Locale/enUS.lua \
  spec/focus_spec.lua spec/settings_focus_spec.lua spec/signals_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 3: /swagbag mode style, the Focus modes style row, the report names the style

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 4: The BoE/WuE badge off by default, and a "Warbound until equipped" category

User request 2 (D8, D9, D10). `overlays.bind` defaults to `false`. Only values the user wrote are stored, so the new default reaches everybody who never touched the badge, and a saved choice is kept. `c_wue` (`gear & wue`, priority 74, displayOrder 45) joins the built-ins next to BoE gear. Its `after = "c_boe"` places it there in a saved category order too. The keyword `wue` and its alias already exist. The overlay corners keep their week-4 Task 11 places and sizes. Every test that looks at the badge now switches it on first. **Session OV1 runs after this task.**

**Files:**
- Modify: `SwagBag/Core/Config.lua` (`overlays.bind`)
- Modify: `SwagBag/Engine/CategoryDefaults.lua` (`after` documented, `c_wue`)
- Modify: `SwagBag/Engine/Categories.lua` (`C.Load`: a built-in with `after` joins a saved order)
- Modify: `SwagBag/Locale/enUS.lua` (`CAT_WUE`)
- Test: `spec/overlays_spec.lua`, `spec/categories_spec.lua`, `spec/categorizer_spec.lua`, `spec/bagswindow_sections_spec.lua`, `spec/bankwindow_groups_spec.lua`, `spec/guildbank_spec.lua`, `spec/offline_spec.lua`

**Interfaces:**
- Consumes: `SB.Config.Defaults`, `SB.CategoryDefaults`, `C.Load`.
- Produces: the category id `c_wue` (Focus section lists and the category editor list it automatically); the optional `after` field on a `CategoryDefaults` entry.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua`, find:

```lua
	it("bag items get their overlays; an empty reagent-bag slot is tinted in Free", function()
		A.SetBagSize(5, 2)
```

and replace it with:

```lua
	it("bag items get their overlays; an empty reagent-bag slot is tinted in Free", function()
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		A.SetBagSize(5, 2)
```

In `spec/bankwindow_groups_spec.lua`, find:

```lua
	it("bank items get their overlays (the BoE ring's item level and badge)", function()
		openBank()
```

and replace it with:

```lua
	it("bank items get their overlays (the BoE ring's item level and badge)", function()
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		openBank()
```

In `spec/categories_spec.lua` (edit 1 of 6), find:

```lua
	c_keystone = { "crest", "keystone" }, c_consumables = { "consumable" }, c_gear = { "gear" },
	c_boe = { "boe", "gear" }, c_tradegoods = { "reagent", "tradegoods" }, c_herbs = { "herb" }, c_ore = { "ore" },
	c_leathercloth = { "cloth", "leather" }, c_enchanting = { "enchanting" }, c_cooking = { "cooking" },
```

and replace it with:

```lua
	c_keystone = { "crest", "keystone" }, c_consumables = { "consumable" }, c_gear = { "gear" },
	c_boe = { "boe", "gear" }, c_wue = { "gear", "wue" }, c_tradegoods = { "reagent", "tradegoods" }, c_herbs = { "herb" }, c_ore = { "ore" },
	c_leathercloth = { "cloth", "leather" }, c_enchanting = { "enchanting" }, c_cooking = { "cooking" },
```

In `spec/categories_spec.lua` (edit 2 of 6), find:

```lua
	it("ships the spec 7.6 set in display order, with New first and Free last", function()
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
			"c_leathercloth", "c_enchanting", "c_cooking", "c_fish", "c_quest", "c_housing", "c_collect", "c_tools",
			"c_junk", "c_other", "free" }, C.SectionOrder())
		assert.equal("Keystone & Crests", C.Name("c_keystone"))
```

and replace it with:

```lua
	it("ships the spec 7.6 set in display order, with New first and Free last", function()
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_wue", "c_tradegoods", "c_herbs", "c_ore",
			"c_leathercloth", "c_enchanting", "c_cooking", "c_fish", "c_quest", "c_housing", "c_collect", "c_tools",
			"c_junk", "c_other", "free" }, C.SectionOrder())
		assert.equal("Warbound until equipped", C.Name("c_wue"))
		assert.equal("Keystone & Crests", C.Name("c_keystone"))
```

In `spec/categories_spec.lua` (edit 3 of 6), find:

```lua
		local p = ids(C.ByPriority())
		assert.same({ "c_reagents", "c_keystone", "c_junk", "c_quest", "c_tools", "c_boe", "c_gear", "c_consumables" },
			{ unpack(p, 1, 8) })
		assert.equal("c_other", p[#p])
```

and replace it with:

```lua
		local p = ids(C.ByPriority())
		assert.same({ "c_reagents", "c_keystone", "c_junk", "c_quest", "c_tools", "c_boe", "c_wue", "c_gear",
			"c_consumables" }, { unpack(p, 1, 9) })
		assert.equal("c_other", p[#p])
```

In `spec/categories_spec.lua` (edit 4 of 6), find:

```lua
	end)

	it("damaged saved category data never breaks loading (Review Focus 4)", function()
		SB.Config.db.userEdits = { c_gear = "garbage", c_ore = { priority = "high", itemList = "x" }, nope = { name = "?" } }
```

and replace it with:

```lua
	end)

	-- Week 6. A saved order lists every category of its day (quick setup writes the whole list), so a
	-- built-in added later would land after Other. Mutation: delete the `def.after` loop in C.Load.
	it("a built-in added later joins a saved order right after the one it follows (WuE after BoE gear)", function()
		SB.Config.db.categoryOrder = { "c_keystone", "c_tradegoods", "c_boe", "c_consumables", "c_gear", "c_herbs",
			"c_ore", "c_leathercloth", "c_enchanting", "c_cooking", "c_fish", "c_quest", "c_housing", "c_collect",
			"c_tools", "c_reagents", "c_junk", "c_other" }
		C.Load()
		assert.same({ "new", "c_keystone", "c_tradegoods", "c_boe", "c_wue", "c_consumables" },
			{ unpack(C.SectionOrder(), 1, 6) })
		SB.Config.db.categoryOrder = { "c_junk", "c_gear" } -- BoE gear not saved: WuE follows with the rest
		C.Load()
		assert.same({ "new", "c_junk", "c_gear", "c_keystone" }, { unpack(C.SectionOrder(), 1, 4) })
	end)

	-- Spec 8.5: a user's edit of the new built-in is a diff, and Reset brings the built-in back.
	it("Warbound until equipped keeps a user's rename as a diff; reset restores it", function()
		SB.Config.db.userEdits.c_wue = { name = "WuE" }
		C.Load()
		assert.equal("WuE", C.Name("c_wue"))
		assert.equal("gear & wue", C.Get("c_wue").query, "the rest is the built-in's")
		C.ResetBuiltin("c_wue")
		assert.equal("Warbound until equipped", C.Name("c_wue"))
		assert.is_nil(SB.Config.db.userEdits.c_wue)
	end)

	it("damaged saved category data never breaks loading (Review Focus 4)", function()
		SB.Config.db.userEdits = { c_gear = "garbage", c_ore = { priority = "high", itemList = "x" }, nope = { name = "?" } }
```

In `spec/categories_spec.lua` (edit 5 of 6), find:

```lua
		local total, edited, broken = C.Counts()
		assert.equal(19, total)
		assert.equal(2, edited)
```

and replace it with:

```lua
		local total, edited, broken = C.Counts()
		assert.equal(20, total)
		assert.equal(2, edited)
```

In `spec/categories_spec.lua` (edit 6 of 6), find:

```lua
		local text = SB.Report.Build()
		assert.truthy(text:find("\nCategories: 18 (0 edited)  Broken: Fish & Lures", 1, true))
	end)
```

and replace it with:

```lua
		local text = SB.Report.Build()
		assert.truthy(text:find("\nCategories: 19 (0 edited)  Broken: Fish & Lures", 1, true))
	end)
```

In `spec/categorizer_spec.lua`, find:

```lua
		A.Put(0, 13, Fixtures.BOE_RING, 1, { isWUE = true })
		local expected = { "c_consumables", "c_consumables", "c_boe", "c_gear", "c_keystone", "c_junk", "c_herbs", "c_ore",
			"c_collect", "c_collect", "c_quest", "c_other", "c_gear" }
		for slot, id in ipairs(expected) do
```

and replace it with:

```lua
		A.Put(0, 13, Fixtures.BOE_RING, 1, { isWUE = true })
		-- slot 13, a warbound-until-equipped ring: its own section since week 6 (Gear before)
		local expected = { "c_consumables", "c_consumables", "c_boe", "c_gear", "c_keystone", "c_junk", "c_herbs", "c_ore",
			"c_collect", "c_collect", "c_quest", "c_other", "c_wue" }
		for slot, id in ipairs(expected) do
```

In `spec/guildbank_spec.lua` (edit 1 of 2), find:

```lua
	it("a reopen draws overlays on a cached tab that has not answered (describe path)", function()
		openVault()
```

and replace it with:

```lua
	it("a reopen draws overlays on a cached tab that has not answered (describe path)", function()
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		openVault()
```

In `spec/guildbank_spec.lua` (edit 2 of 2), find:

```lua
	it("guild items get their overlays (the BoE ring's item level and badge)", function()
		openVault()
```

and replace it with:

```lua
	it("guild items get their overlays (the BoE ring's item level and badge)", function()
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		openVault()
```

In `spec/offline_spec.lua`, find:

```lua
	it("a BoE item in a saved guild bank stays BoE (never bound there), beside the same ring in the bags", function()
		local tab = SB.Snapshots.DB().guilds["Tidewatch-Argent Dawn"].snapshot.containers[1]
```

and replace it with:

```lua
	it("a BoE item in a saved guild bank stays BoE (never bound there), beside the same ring in the bags", function()
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		local tab = SB.Snapshots.DB().guilds["Tidewatch-Argent Dawn"].snapshot.containers[1]
```

In `spec/overlays_spec.lua` (edit 1 of 3), find:

```lua
	it("gear: item level top left, track bottom left, BoE badge, upgrade arrow", function()
		A.tracks["item:225001::upgradable"] = { track = "Champion", level = 2, max = 8 }
```

and replace it with:

```lua
	it("gear: item level top left, track bottom left, BoE badge, upgrade arrow", function()
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		A.tracks["item:225001::upgradable"] = { track = "Champion", level = 2, max = 8 }
```

In `spec/overlays_spec.lua` (edit 2 of 3), find:

```lua
			{ r.topLeft.text, r.bottomLeft.text, r.bind.text, r.arrow.shown, r.junk.shown })
	end)
```

and replace it with:

```lua
			{ r.topLeft.text, r.bottomLeft.text, r.bind.text, r.arrow.shown, r.junk.shown })
	end)

	-- Week 6, user request 2: too cluttered with the item level, the track and the badge. Only a value the
	-- user saved is stored, so the new default reaches everyone who never touched it.
	-- Mutation: Config.Defaults overlays.bind = true.
	it("the BoE/WuE badge is off by default; a user who saved it on keeps it", function()
		local _, r = draw(0, 3)
		assert.equal("", r.bind.text)
		SB.Config.Init({ schemaVersion = SB.Config.CURRENT, settings = { overlays = { bind = true } } }, nil)
		local _, saved = draw(0, 3)
		assert.equal("BoE", saved.bind.text)
	end)

	-- Week 6: the badge sat between the two left corners, so with it off nothing needs the space back.
	-- Pins the week-4 Task 11 places and sizes (no code change this week).
	it("with the badge off, the item level and the track keep their corners and sizes", function()
		A.tracks["item:225001::upgradable"] = { track = "Champion", level = 2, max = 8 }
		local _, r = draw(0, 3)
		assert.same({ "285", "C2/8", "" }, { r.topLeft.text, r.bottomLeft.text, r.bind.text })
		local tl, bl = r.topLeft.points[1], r.bottomLeft.points[1]
		assert.same({ "TOPLEFT", 2, -2, "BOTTOMLEFT", 2, 2 }, { tl[1], tl[4], tl[5], bl[1], bl[4], bl[5] })
		assert.same({ 13, 11, 33 }, { Ov.FONT_SIZE, Ov.BIND_SIZE, Ov.TEXT_WIDTH })
		assert.equal(Ov.FONT_SIZE, r.topLeft.calls.SetFont[2])
	end)
```

In `spec/overlays_spec.lua` (edit 3 of 3), find:

```lua
	it("each overlay has its own switch; /swagbag overlays lists and switches them", function()
		SB.Config.Set("overlays.ilvl", false)
```

and replace it with:

```lua
	it("each overlay has its own switch; /swagbag overlays lists and switches them", function()
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		SB.Config.Set("overlays.ilvl", false)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1239 passed, 9 failed`, and the failures are exactly:
```text
FAIL spec/categories_spec.lua :: Categories > ships the spec 7.6 set in display order, with New first and Free last
FAIL spec/categories_spec.lua :: Categories > orders rules by priority, ties by id, never by table order
FAIL spec/categories_spec.lua :: Categories > a built-in added later joins a saved order right after the one it follows (WuE after BoE gear)
FAIL spec/categories_spec.lua :: Categories > Warbound until equipped keeps a user's rename as a diff; reset restores it
FAIL spec/categories_spec.lua :: Categories > Counts reports totals, edited categories and broken ones
FAIL spec/categories_spec.lua :: Categories > /swagbag report shows category counts and broken categories
FAIL spec/categorizer_spec.lua :: Categorizer > files the fixture bag into the default sections, keystones and caged pets by link
FAIL spec/overlays_spec.lua :: Overlays (spec F9) > the BoE/WuE badge is off by default; a user who saved it on keeps it
FAIL spec/overlays_spec.lua :: Overlays (spec F9) > with the badge off, the item level and the track keep their corners and sizes
```
The badge tests that now switch the badge on first pass before and after the change. (The last overlays test fails before Task 4 only because the badge is still on: its text is `BoE`. After Task 4 it pins the week-4 corners.)

Critical tests and the mutation each must catch (applied to the finished Task 4 code):
- "the BoE/WuE badge is off by default …": in `Config.Defaults`, `bind = true`.
- "a built-in added later joins a saved order …": in `C.Load`, replace `if def.after and not placed[def.id] and placed[def.after] and C.byId[def.id] then` with `if false then`.
- "files the fixture bag …" (slot 13 in `c_wue`): `c_wue` with `priority = 69` (below Gear).

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Config.lua`, find:

```lua
		prices = { headerTotals = true },
		-- Overlays on item buttons (spec F9); usePawn: Pawn decides the upgrade arrow.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = true,
			usePawn = false },
```

and replace it with:

```lua
		prices = { headerTotals = true },
		-- Overlays on item buttons (spec F9); usePawn: Pawn decides the upgrade arrow. bind: the "BoE" /
		-- "WuE" badge, off by default since week 6 (user request: the item level, track and badge were
		-- too cluttered; the "BoE gear" and "Warbound until equipped" sections say it instead). Only a
		-- value the user saved is stored (Config.Get falls back to these defaults), so whoever never
		-- touched it gets the new default and whoever saved "on" keeps it.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = false,
			usePawn = false },
```

In `SwagBag/Engine/Categories.lua`, find:

```lua
				C.display[#C.display + 1] = c
			end
```

and replace it with:

```lua
				C.display[#C.display + 1] = c
			end
		end
		-- A built-in added in an update (def.after) joins the saved order right after the category it
		-- follows by default, when that one is placed; otherwise it follows with the rest (week 6).
		for _, def in ipairs(SB.CategoryDefaults) do
			if def.after and not placed[def.id] and placed[def.after] and C.byId[def.id] then
				for i, c in ipairs(C.display) do
					if c.id == def.after then
						table.insert(C.display, i + 1, C.byId[def.id])
						placed[def.id] = true
						break
					end
				end
			end
```

In `SwagBag/Engine/CategoryDefaults.lua` (edit 1 of 2), find:

```lua
--   fallback      the category for items no rule claims ("Other")
-- New and Free are not categories: the layout adds them (spec 7.6, 4.3).
```

and replace it with:

```lua
--   fallback      the category for items no rule claims ("Other")
--   after         a built-in added in an update joins a SAVED category order right after this one
--                 (not at the end); without a saved order displayOrder places it as usual
-- New and Free are not categories: the layout adds them (spec 7.6, 4.3).
```

In `SwagBag/Engine/CategoryDefaults.lua` (edit 2 of 2), find:

```lua
	{ id = "c_boe", name = L.CAT_BOE, query = "gear & boe", priority = 75, displayOrder = 40 },
	{ id = "c_tradegoods", name = L.CAT_TRADEGOODS, query = "tradegoods | reagent", priority = 50, displayOrder = 50 },
```

and replace it with:

```lua
	{ id = "c_boe", name = L.CAT_BOE, query = "gear & boe", priority = 75, displayOrder = 40 },
	-- Week 6 (user request 2): gear that is warbound until equipped, next to BoE gear. Above Gear (70)
	-- so WuE gear lands here; "wue" and "boe" never match the same item (Engine/Keywords.lua).
	{ id = "c_wue", name = L.CAT_WUE, query = "gear & wue", priority = 74, displayOrder = 45, after = "c_boe" },
	{ id = "c_tradegoods", name = L.CAT_TRADEGOODS, query = "tradegoods | reagent", priority = 50, displayOrder = 50 },
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.CAT_BOE = "BoE gear"
L.CAT_TRADEGOODS = "Trade Goods"
```

and replace it with:

```lua
L.CAT_BOE = "BoE gear"
L.CAT_WUE = "Warbound until equipped"
L.CAT_TRADEGOODS = "Trade Goods"
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1248 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1248 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Config.lua SwagBag/Engine/CategoryDefaults.lua SwagBag/Engine/Categories.lua SwagBag/Locale/enUS.lua \
  spec/overlays_spec.lua spec/categories_spec.lua spec/categorizer_spec.lua spec/bagswindow_sections_spec.lua \
  spec/bankwindow_groups_spec.lua spec/guildbank_spec.lua spec/offline_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 4: BoE/WuE badge off by default, Warbound until equipped category next to BoE gear

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 5: The Adapter's warband deposit (the game call, its guards, Blizzard's reagents choice)

User request 3, the Adapter half (D11, D12). Five read-or-call helpers, all `pcall`-guarded and secret-aware, plus `A.CHECKS` entries (not required, window `"bank"`) so `/swagbag report` names any that a client lacks:
- `WarbandDepositState()`: usable, or `"locked"` / `"unavailable"`;
- `RefundableForWarband(bags)`: `true` / `false`, or `nil` when it cannot be told;
- `DepositWarband()`: the game call with the warband bank type;
- `DepositReagents()` and `SetDepositReagents(on)`: Blizzard's `bankAutoDepositReagents` setting.

The mock gets the same five functions. `.luacheckrc` learns `C_CVar`.

**Files:**
- Modify: `SwagBag/Core/Adapter.lua` (a new section after `A.ActiveBankType`; `A.CHECKS`)
- Modify: `.luacheckrc` (`C_CVar`)
- Create: `spec/adapter_bank_spec.lua`
- Modify: `spec/mock_adapter.lua`

**Interfaces:**
- Consumes: the Adapter locals `isSecret` and `location(bag, slot)`.
- Produces (Task 6 relies on these):
  - `A.WarbandDepositState() -> true | false, "locked" | "unavailable"`;
  - `A.RefundableForWarband(bags) -> true | false | nil`, where `bags = { { bag = id, size = n } }`;
  - `A.DepositWarband() -> true | false, err`;
  - `A.DepositReagents() -> true | false | nil`;
  - `A.SetDepositReagents(on) -> bool`;
  - mock state `m.warband = { usable, reason, refundable, reagents }`, `m.warbandDeposits` (count), `m.refundChecks` (each `bags` argument).

- [ ] **Step 1: Write the failing tests**

Create `spec/adapter_bank_spec.lua`:

```lua
-- luacheck: globals C_Bank C_Item C_CVar Enum ItemLocation issecretvalue
-- The REAL Adapter's warband deposit helpers (week 6, user request 3), with stubbed game globals.
describe("Adapter warband deposit (real adapter, stubbed globals)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		Enum = { BankType = { Character = 0, Account = 2 } }
	end)

	after_each(function()
		C_Bank, C_Item, C_CVar, Enum, ItemLocation, issecretvalue = nil, nil, nil, nil, nil, nil
	end)

	-- Mutation: pass Enum.BankType.Character (or Blizzard's selected type) to the game call.
	it("DepositWarband asks the game for the warband bank by type, and refuses without the API", function()
		assert.equal(false, A.DepositWarband(), "no API")
		local asked = {}
		C_Bank = { AutoDepositItemsIntoBank = function(bankType) asked[#asked + 1] = bankType end }
		assert.truthy(A.DepositWarband())
		assert.same({ 2 }, asked)
		C_Bank.AutoDepositItemsIntoBank = function() error("boom") end
		local ok, err = A.DepositWarband()
		assert.equal(false, ok)
		assert.truthy(tostring(err):find("boom", 1, true))
	end)

	-- Mutation: treat any FetchBankLockedReason answer (nil included) as locked.
	it("WarbandDepositState: usable, locked by another character, or unavailable", function()
		assert.same({ false, "unavailable" }, { A.WarbandDepositState() }, "no API")
		local locked, can = nil, true
		C_Bank = { AutoDepositItemsIntoBank = function() end,
			FetchBankLockedReason = function() return locked end, CanUseBank = function() return can end }
		assert.same({ true }, { A.WarbandDepositState() })
		locked = 1
		assert.same({ false, "locked" }, { A.WarbandDepositState() })
		locked, can = nil, false
		assert.same({ false, "unavailable" }, { A.WarbandDepositState() })
		C_Bank.CanUseBank = function() error("boom") end
		assert.same({ false, "unavailable" }, { A.WarbandDepositState() })
	end)

	-- Item safety. Mutation: drop the IsItemAllowedInBankType test (any refundable item counts) -- or
	-- return false instead of nil when the answer is secret.
	it("RefundableForWarband finds a refundable item the warband bank would take; nil when it cannot tell", function()
		local bags = { { bag = 0, size = 3 } }
		assert.is_nil(A.RefundableForWarband(bags), "no API: unknown")
		ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
		local refundable, allowed = { [2] = true, [3] = true }, { [3] = true }
		C_Item = { DoesItemExist = function(loc) return loc.slot ~= 1 end,
			CanBeRefunded = function(loc) return refundable[loc.slot] == true end }
		C_Bank = { IsItemAllowedInBankType = function(bankType, loc) return bankType == 2 and allowed[loc.slot] == true end }
		assert.equal(true, A.RefundableForWarband(bags), "slot 3: refundable and the warband bank takes it")
		allowed[3] = nil
		assert.equal(false, A.RefundableForWarband(bags), "slot 2 is refundable, but the warband bank refuses it")
		issecretvalue = function(v) return v == true end
		assert.is_nil(A.RefundableForWarband(bags), "a secret answer: unknown")
	end)

	-- Mutation: SetDepositReagents writes "1" for false.
	it("DepositReagents reads Blizzard's include-reagents choice; SetDepositReagents writes it as the box does", function()
		assert.is_nil(A.DepositReagents())
		assert.equal(false, A.SetDepositReagents(true))
		local cvar = "0"
		C_CVar = { GetCVarBool = function(name) return name == "bankAutoDepositReagents" and cvar == "1" end,
			SetCVar = function(name, v) if name == "bankAutoDepositReagents" then cvar = v end end }
		assert.equal(false, A.DepositReagents())
		assert.truthy(A.SetDepositReagents(true))
		assert.equal("1", cvar)
		assert.equal(true, A.DepositReagents())
		assert.truthy(A.SetDepositReagents(false))
		assert.equal("0", cvar)
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
		return m.activeBankType
	end
```

and replace it with:

```lua
		return m.activeBankType
	end

	-- Deposit all warbound items (week 6): m.warband.usable / .reason (WarbandDepositState),
	-- .refundable (true | false | nil), .reagents (Blizzard's "Include reagents"); deposits are counted.
	m.warband = { usable = true, reason = nil, refundable = false, reagents = false }
	m.warbandDeposits = 0
	m.refundChecks = {}
	function m.WarbandDepositState()
		if m.warband.usable then
			return true
		end
		return false, m.warband.reason or "unavailable"
	end

	function m.RefundableForWarband(bags)
		m.refundChecks[#m.refundChecks + 1] = bags
		return m.warband.refundable
	end

	function m.DepositWarband()
		m.warbandDeposits = m.warbandDeposits + 1
		return true
	end

	function m.DepositReagents()
		return m.warband.reagents
	end

	function m.SetDepositReagents(on)
		m.warband.reagents = on and true or false
		return true
	end
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1248 passed, 4 failed`, and the failures are exactly these four, each with `attempt to call field '…' (a nil value)`:
```text
FAIL spec/adapter_bank_spec.lua :: Adapter warband deposit (real adapter, stubbed globals) > DepositWarband asks the game for the warband bank by type, and refuses without the API
FAIL spec/adapter_bank_spec.lua :: Adapter warband deposit (real adapter, stubbed globals) > WarbandDepositState: usable, locked by another character, or unavailable
FAIL spec/adapter_bank_spec.lua :: Adapter warband deposit (real adapter, stubbed globals) > RefundableForWarband finds a refundable item the warband bank would take; nil when it cannot tell
FAIL spec/adapter_bank_spec.lua :: Adapter warband deposit (real adapter, stubbed globals) > DepositReagents reads Blizzard's include-reagents choice; SetDepositReagents writes it as the box does
```

Critical tests and the mutation each must catch (applied to the finished Task 5 code):
- "DepositWarband asks the game for the warband bank by type …": `return pcall(C_Bank.AutoDepositItemsIntoBank, Enum.BankType.Character)`.
- "WarbandDepositState …": replace `elseif reason ~= nil then` with `else` (any answer counts as locked).
- "RefundableForWarband …": `if refund then` instead of `if allowed and refund then`; separately, `return false` instead of `return nil` after a failed `pcall`.
- "DepositReagents reads … SetDepositReagents writes …": write `"1"` whatever `on` is.

- [ ] **Step 3: Write the implementation**

In `.luacheckrc`, find:

```lua
read_globals = {
	"C_AddOns", "C_Bank", "C_Container", "C_Item", "C_Timer", "C_ToyBox", "Enum", "ItemLocation",
	"CreateFrame", "UIParent", "UISpecialFrames", "DEFAULT_CHAT_FRAME", "ChatFontNormal",
```

and replace it with:

```lua
read_globals = {
	"C_AddOns", "C_Bank", "C_Container", "C_CVar", "C_Item", "C_Timer", "C_ToyBox", "Enum", "ItemLocation",
	"CreateFrame", "UIParent", "UISpecialFrames", "DEFAULT_CHAT_FRAME", "ChatFontNormal",
```

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
---------------------------------------------------------------------------
-- Guild bank (week 3, spec F16). Blizzard's guild bank functions are plain globals; the
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- Deposit all warbound items (week 6, user request 3). C_Bank.AutoDepositItemsIntoBank is the call
-- Blizzard's own "Deposit All Warbound Items" button (BankPanel.AutoDepositFrame.DepositButton) makes;
-- here it is given the warband bank type explicitly, so Blizzard's selected bank type is never read
-- for it nor set. It is a C function: it writes no Lua field of Blizzard's frames, so it cannot taint
-- them the way calling the bank frame's own tab method did in the week-1 spike (that Lua method wrote
-- the frame's own state, which Blizzard's secure item click then read). Not protected: Baganator 833, TradeSkillMaster,
-- ElvUI, EllesmereUI and EnhanceQoL call it from addon code on Interface 120100 (names read only).
-- Blizzard's button asks before a deposit would end an item's refund; SwagBag checks first and
-- leaves those cases to Blizzard's button (RefundableForWarband).
---------------------------------------------------------------------------
local function warbandType()
	local BT = Enum and Enum.BankType
	return BT and BT.Account
end

-- true when the warband bank takes items now; otherwise false and why: "locked" (another
-- character of the account has it open) or "unavailable" (no API, no tab, not at a banker).
function A.WarbandDepositState()
	local account = warbandType()
	if account == nil or not (C_Bank and C_Bank.AutoDepositItemsIntoBank) then
		return false, "unavailable"
	end
	if C_Bank.FetchBankLockedReason then
		local ok, reason = pcall(C_Bank.FetchBankLockedReason, account)
		if not ok or isSecret(reason) then
			return false, "unavailable"
		elseif reason ~= nil then
			return false, "locked"
		end
	end
	if C_Bank.CanUseBank then
		local ok, can = pcall(C_Bank.CanUseBank, account)
		if not ok or isSecret(can) or can ~= true then
			return false, "unavailable"
		end
	end
	return true
end

-- true when an item in bags = { { bag, size } } that the warband bank would take can still be
-- refunded (the deposit would end that refund); false when none; nil when it cannot be told.
function A.RefundableForWarband(bags)
	local account = warbandType()
	if account == nil or not (C_Item and C_Item.CanBeRefunded and C_Item.DoesItemExist and C_Bank
		and C_Bank.IsItemAllowedInBankType) then
		return nil
	end
	local ok, found = pcall(function()
		for _, b in ipairs(bags) do
			for slot = 1, b.size do
				local loc = location(b.bag, slot)
				local exists = C_Item.DoesItemExist(loc)
				if isSecret(exists) then
					error("secret")
				end
				if exists then
					local allowed, refund = C_Bank.IsItemAllowedInBankType(account, loc), C_Item.CanBeRefunded(loc)
					if isSecret(allowed) or isSecret(refund) then
						error("secret")
					end
					if allowed and refund then
						return true
					end
				end
			end
		end
		return false
	end)
	if not ok then
		return nil
	end
	return found
end

-- Deposit every item the warband bank takes; reagents too when Blizzard's "Include reagents" box is
-- ticked (the game reads it). Returns true, or false and the error (nil when the API is missing).
function A.DepositWarband()
	local account = warbandType()
	if account == nil or not (C_Bank and C_Bank.AutoDepositItemsIntoBank) then
		return false
	end
	return pcall(C_Bank.AutoDepositItemsIntoBank, account)
end

-- Blizzard's "Include reagents" choice for that deposit: the bankAutoDepositReagents setting its own
-- check box reads and writes. true | false | nil (unknown).
function A.DepositReagents()
	if not (C_CVar and C_CVar.GetCVarBool) then
		return nil
	end
	local ok, on = pcall(C_CVar.GetCVarBool, "bankAutoDepositReagents")
	if not ok or isSecret(on) or type(on) ~= "boolean" then
		return nil
	end
	return on
end

-- Set that choice, as Blizzard's own check box does. Returns true when it took.
function A.SetDepositReagents(on)
	if not (C_CVar and C_CVar.SetCVar) then
		return false
	end
	local want = on and true or false
	if not pcall(C_CVar.SetCVar, "bankAutoDepositReagents", want and "1" or "0") then
		return false
	end
	return A.DepositReagents() == want
end

---------------------------------------------------------------------------
-- Guild bank (week 3, spec F16). Blizzard's guild bank functions are plain globals; the
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "BankFrame.TabSystem", window = "bank", required = true },
	{ path = "Enum.ItemClass", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "BankFrame.TabSystem", window = "bank", required = true },
	{ path = "C_Bank.AutoDepositItemsIntoBank", window = "bank", required = false },
	{ path = "C_Bank.FetchBankLockedReason", window = "bank", required = false },
	{ path = "C_Bank.CanUseBank", window = "bank", required = false },
	{ path = "C_Bank.IsItemAllowedInBankType", window = "bank", required = false },
	{ path = "C_Item.CanBeRefunded", window = "bank", required = false },
	{ path = "C_Item.DoesItemExist", window = "bank", required = false },
	{ path = "C_CVar.GetCVarBool", window = "bank", required = false },
	{ path = "C_CVar.SetCVar", window = "bank", required = false },
	{ path = "Enum.ItemClass", window = "bags", required = false },
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1252 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1252 passed, 0 failed`, and the last line `ALL CHECKS PASSED`. (The forbidden-token grep is why the new Adapter comment says "the bank frame's own tab method" and never writes that method's name.)

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua .luacheckrc spec/adapter_bank_spec.lua spec/mock_adapter.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 5: Adapter warband deposit (state, refund guard, the call, Blizzard's reagents choice)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 6: `Deposit warbound` and `With reagents` on the bank window; the bank's free tile pinned

User requests 3 and 4 (D11–D14). SwagBag's own plain `Deposit warbound` button sits under the bank title on the right. It lives on SwagBag's window, so it shows in tiny and beside mode and hides with that window. It runs `BW.DepositWarband()`, which refuses in this order: in combat; when the warband bank is locked or unavailable; and when an item would lose its refund, or that cannot be told. Otherwise it deposits and says so. To its left, the `With reagents` box shows and switches Blizzard's own include-reagents setting. The deposit line (`Deposits go to …`) now ends left of the box. `BW.Flash` also prints a cut-short answer to chat (D14). Session DP1 shows the user the free tile, which needs no code (D13); a new test pins it for two tabs per group. **Session DP1 runs after this task.**

**Files:**
- Modify: `SwagBag/UI/BankWindow.lua` (header comment, `BW.Flash`, a new deposit section before the live-updates handler, `BW.Open`)
- Modify: `SwagBag/Locale/enUS.lua` (`BTN_DEPOSIT_WARBAND`, `DEPOSIT_*`)
- Test: `spec/bankwindow_spec.lua` (five tests), `spec/bankwindow_groups_spec.lua` (the free tile across tabs)

**Interfaces:**
- Consumes: Task 5's Adapter functions and mock state; `titleButton`, `BW.Flash`, `A.GetBagIDs`, `A.NumSlots`.
- Produces: `BW.DepositWarband() -> bool`, `BW.depositButton`, `BW.reagentsBox`, `BW.reagentsLabel`, `BW.RefreshReagents()`.

- [ ] **Step 1: Write the failing tests**

In `spec/bankwindow_groups_spec.lua`, find:

```lua
			assert.same({ 7, 7 }, { number(6, 3), number(12, 3) })
		end)

	-- Plan D19. Mutations: delete `freeTile = function() ... end` from the bank's GroupView cfg; delete
```

and replace it with:

```lua
			assert.same({ 7, 7 }, { number(6, 3), number(12, 3) })
		end)

	-- Week 6, user request 4: the free tile in the bank. Every tab of a group shares one tile (bank tabs
	-- are family "any", reagent-filtered tabs too: the client reports no bag family for them), in the
	-- character bank and the warband bank alike. Mutation: in GroupView's build(), pass
	-- `family = function(bag) return bag end` (one tile per tab).
	it("each group's tabs share one free tile with the group's number: character bank and warband bank", function()
		A.bagIDs.bank, A.bagIDs.warband = { 6, 7 }, { 12, 13 }
		A.SetBagSize(7, 4)
		A.SetBagSize(13, 4)
		SB.Buttons.EnsureBankTabs()
		openBank()
		assert.same({ 10, 10 }, { number(6, 3), number(12, 3) }, "6 + 4 free slots in each group, one number")
		for slot = 1, 4 do
			assert.falsy(B.Get(7, slot).shown, "the second character tab's empties are spares")
			assert.falsy(B.Get(13, slot).shown, "the second warband tab's empties are spares")
		end
		assert.equal("- Free (10)", header("warband:free").text.text)
	end)

	-- Plan D19. Mutations: delete `freeTile = function() ... end` from the bank's GroupView cfg; delete
```

In `spec/bankwindow_spec.lua`, find:

```lua
	end)

	it("an error in a tab-click hook switches only the bank to Safe Mode", function()
		openBank()
```

and replace it with:

```lua
	end)

	-- Week 6, user request 3. Mutations: drop the A.DepositWarband() call in BW.DepositWarband; or add
	-- bf:Show() there (a Blizzard write the strict fake logs).
	it("Deposit warbound runs the game's warband deposit and answers; Blizzard's bank is not touched", function()
		A.SetBagSize(0, 16)
		openBank()
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(1, A.warbandDeposits)
		assert.equal(SB.L.DEPOSIT_STARTED, BW.frame.title.text)
		assert.same({}, blizzardWrites(bf), "only the tiny-mode moves, nothing else")
		assert.equal("bank", A.activeBankType, "the selected bank type is never set")
		assert.same({ { bag = 0, size = 16 } }, A.refundChecks[1], "the refund check read the bags")
	end)

	-- Item safety and P2. Mutation: in BW.DepositWarband, `if refundable then` (an unknown answer deposits).
	it("it refuses in combat, while the warband bank is busy, and when a refund could be lost; each says why", function()
		openBank()
		A.combat = true
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_AFTER_COMBAT, BW.frame.title.text)
		A.combat = false
		A.warband.usable, A.warband.reason = false, "locked"
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_LOCKED, BW.frame.title.text)
		A.warband.reason = "unavailable"
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_UNAVAILABLE, BW.frame.title.text)
		A.warband.usable, A.warband.refundable = true, true
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_REFUNDABLE, BW.frame.title.text)
		A.warband.refundable = nil
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_UNSURE, BW.frame.title.text)
		assert.equal(0, A.warbandDeposits, "nothing was deposited")
	end)

	-- Never invisible but clickable. Mutation: create the button on Blizzard's bank (parent bf).
	it("the deposit button is on SwagBag's window in tiny and beside mode, so it hides with that window", function()
		openBank()
		assert.equal(BW.frame, BW.depositButton.parent)
		assert.equal(SB.TinyHost.Parent(), bf.parent, "tiny: Blizzard's bank is invisible, our button is not")
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.equal(UIParent, bf.parent, "beside")
		assert.equal(BW.frame, BW.depositButton.parent)
		assert.truthy(BW.frame.shown and BW.depositButton.shown)
	end)

	-- Mutation: the box's OnClick flashes without calling A.SetDepositReagents.
	it("With reagents shows Blizzard's include-reagents choice, switches it and answers", function()
		openBank()
		assert.same({ false }, BW.reagentsBox.calls.SetChecked)
		Fake.Fire(BW.reagentsBox, "OnClick")
		assert.equal(true, A.warband.reagents)
		assert.equal(SB.L.DEPOSIT_REAGENTS_ON, BW.frame.title.text)
		assert.same({ true }, BW.reagentsBox.calls.SetChecked)
		Fake.Fire(BW.depositButton, "OnClick")
		assert.equal(SB.L.DEPOSIT_STARTED_REAGENTS, BW.frame.title.text)
		A.DepositReagents = function() return nil end -- the game cannot say: no box
		BW.RefreshReagents()
		assert.falsy(BW.reagentsBox.shown)
	end)

	-- P2 (the bags window's D27). Mutation: drop the SB.Print in BW.Flash.
	it("a long answer cut short in the bank title also goes to chat", function()
		openBank()
		BW.frame.title.IsTruncated = function() return true end
		A.warband.refundable = true
		Fake.Fire(BW.depositButton, "OnClick")
		assert.same({ SB.L.DEPOSIT_REFUNDABLE }, A.Lines())
	end)

	it("an error in a tab-click hook switches only the bank to Safe Mode", function()
		openBank()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1253 passed, 5 failed`, and the failures are exactly:
```text
FAIL spec/bankwindow_spec.lua :: BankWindow frames (check V2) > Deposit warbound runs the game's warband deposit and answers; Blizzard's bank is not touched
FAIL spec/bankwindow_spec.lua :: BankWindow frames (check V2) > it refuses in combat, while the warband bank is busy, and when a refund could be lost; each says why
FAIL spec/bankwindow_spec.lua :: BankWindow frames (check V2) > the deposit button is on SwagBag's window in tiny and beside mode, so it hides with that window
FAIL spec/bankwindow_spec.lua :: BankWindow frames (check V2) > With reagents shows Blizzard's include-reagents choice, switches it and answers
FAIL spec/bankwindow_spec.lua :: BankWindow frames (check V2) > a long answer cut short in the bank title also goes to chat
```
The free-tile test, "each group's tabs share one free tile with the group's number: character bank and warband bank", passes already: it pins week-3 behaviour (D13). Its mutation is listed below.

Critical tests and the mutation each must catch (applied to the finished Task 6 code):
- "Deposit warbound runs the game's warband deposit …": replace `local ok, err = A.DepositWarband()` with `local ok, err = true, nil`; separately, add `A.Frame("BankFrame"):Show()` before it (a Blizzard write the strict fake logs).
- "it refuses in combat, …": replace `if refundable ~= false then` with `if refundable then`.
- "the deposit button is on SwagBag's window …": add `BW.depositButton:SetParent(SB.Adapter.Frame("BankFrame"))` after its `SetPoint`.
- "With reagents shows …": replace `if SB.Adapter.SetDepositReagents(want) then` with `if true then`.
- "a long answer cut short in the bank title also goes to chat": delete the `IsTruncated` block in `BW.Flash`.
- "each group's tabs share one free tile …": in `UI/GroupView.lua`'s `build()`, `family = function(bag) return bag end` (one tile per tab).

- [ ] **Step 3: Write the implementation**

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.BTN_SORT_WARBAND = "Sort warband"
L.BANK_VIEW_GRID = "SwagBag bank - grid view"
```

and replace it with:

```lua
L.BTN_SORT_WARBAND = "Sort warband"
L.BTN_DEPOSIT_WARBAND = "Deposit warbound"
L.DEPOSIT_REAGENTS_LABEL = "With reagents"
L.DEPOSIT_STARTED = "Depositing warbound items into the warband bank"
L.DEPOSIT_STARTED_REAGENTS = "Depositing warbound items and reagents into the warband bank"
L.DEPOSIT_AFTER_COMBAT = "Deposit after combat ends"
L.DEPOSIT_LOCKED = "Another character of your account is using the warband bank: nothing was deposited."
L.DEPOSIT_UNAVAILABLE = "The warband bank can't take items right now: nothing was deposited."
L.DEPOSIT_REFUNDABLE = "Some items can still be refunded and the warband bank would end that, so nothing was deposited."
	.. " Blizzard's own button asks first: click Blizzard bank."
L.DEPOSIT_UNSURE = "SwagBag can't tell whether a deposit would end an item's refund, so nothing was deposited."
	.. " Blizzard's own button asks first: click Blizzard bank."
L.DEPOSIT_REAGENTS_ON = "Deposit warbound now takes reagents too (Blizzard's own setting)"
L.DEPOSIT_REAGENTS_OFF = "Deposit warbound now leaves reagents in your bags (Blizzard's own setting)"
L.DEPOSIT_REAGENTS_FAILED = "The reagents choice did not change: use Blizzard's box (click Blizzard bank)"
L.BANK_VIEW_GRID = "SwagBag bank - grid view"
```

In `SwagBag/UI/BankWindow.lua` (edit 1 of 4), find:

```lua
-- later (spec 5.5, ruling W11). The window has its own search box.
local _, SB = ...
```

and replace it with:

```lua
-- later (spec 5.5, ruling W11). The window has its own search box.
-- "Deposit warbound" (week 6, user request 3) runs the game's own warband deposit through the
-- Adapter, beside a "With reagents" box that is Blizzard's own include-reagents choice.
local _, SB = ...
```

In `SwagBag/UI/BankWindow.lua` (edit 2 of 4), find:

```lua
local titleToken = 0
function BW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("bank.flash", function()
```

and replace it with:

```lua
local titleToken = 0
-- A flash cut short by the title's room (W3-26 bounds it) also goes to chat, so a long answer is
-- never lost (P2; the bags window's D27, week 5).
function BW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	if frame.title.IsTruncated and frame.title:IsTruncated() then
		SB.Print(text)
	end
	SB.Adapter.After(1.5, Guard("bank.flash", function()
```

In `SwagBag/UI/BankWindow.lua` (edit 3 of 4), find:

```lua
frame.title:SetWordWrap(false)

-- Live updates while open (spec 4.3), for the bank tabs only: count, lock and loaded data
-- repaint in place; an emptied slot or a different item goes to GroupView.Changes; a tab
```

and replace it with:

```lua
frame.title:SetWordWrap(false)

---------------------------------------------------------------------------
-- Deposit all warbound items (week 6, user request 3)
---------------------------------------------------------------------------
-- SwagBag's own plain button makes the game call Blizzard's "Deposit All Warbound Items" makes
-- (Adapter.DepositWarband, the warband bank by type: Blizzard's selected bank type is never read
-- for it nor set). It sits on this window under the title, so it shows in tiny and beside mode alike
-- and hides with the window: never invisible but clickable. Every click answers in the title (P2).
-- It refuses in combat (nothing is queued, like Sort), while another character of the account has
-- the warband bank open, and when a deposit would end an item's refund or that cannot be told:
-- Blizzard's own button asks first, and the "Blizzard bank" button shows it. SwagBag only reads
-- the result: the items arrive in the warband group's New like any deposit (spec 4.3).
local function carried()
	local A, list = SB.Adapter, {}
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		local n = A.NumSlots(bag)
		if n > 0 then
			list[#list + 1] = { bag = bag, size = n }
		end
	end
	return list
end

function BW.DepositWarband()
	local A = SB.Adapter
	if A.InCombat() then
		BW.Flash(L.DEPOSIT_AFTER_COMBAT)
		return false
	end
	local usable, why = A.WarbandDepositState()
	if not usable then
		BW.Flash(why == "locked" and L.DEPOSIT_LOCKED or L.DEPOSIT_UNAVAILABLE)
		return false
	end
	local refundable = A.RefundableForWarband(carried())
	if refundable ~= false then -- true, or nil: it cannot be told
		BW.Flash(refundable and L.DEPOSIT_REFUNDABLE or L.DEPOSIT_UNSURE)
		return false
	end
	local ok, err = A.DepositWarband()
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("bank.deposit", "none", tostring(err), A.Stack())
		end
		BW.Flash(L.DEPOSIT_UNAVAILABLE)
		return false
	end
	BW.Flash(A.DepositReagents() and L.DEPOSIT_STARTED_REAGENTS or L.DEPOSIT_STARTED)
	return true
end

BW.depositButton = titleButton(L.BTN_DEPOSIT_WARBAND, "bank.depositWarband", function()
	BW.DepositWarband()
end, 128)
BW.depositButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -54)

-- "With reagents": Blizzard's include-reagents choice for that deposit (its own setting, which its own
-- box writes too). Shown ticked as the game has it; hidden when the game cannot say.
BW.reagentsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
BW.reagentsLabel:SetPoint("RIGHT", BW.depositButton, "LEFT", -6, 0)
BW.reagentsLabel:SetText(L.DEPOSIT_REAGENTS_LABEL)
BW.reagentsBox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
BW.reagentsBox:SetSize(22, 22)
BW.reagentsBox:SetPoint("RIGHT", BW.reagentsLabel, "LEFT", -2, 0)
if SB.Theme then
	SB.Theme.Text(BW.reagentsLabel, "small")
end

function BW.RefreshReagents()
	local on = SB.Adapter.DepositReagents()
	BW.reagentsBox:SetShown(on ~= nil)
	BW.reagentsLabel:SetShown(on ~= nil)
	BW.reagentsBox:SetChecked(on == true)
end

BW.reagentsBox:SetScript("OnClick", Guard("bank.depositReagents", function()
	local want = SB.Adapter.DepositReagents() ~= true
	if SB.Adapter.SetDepositReagents(want) then
		BW.Flash(want and L.DEPOSIT_REAGENTS_ON or L.DEPOSIT_REAGENTS_OFF)
	else
		BW.Flash(L.DEPOSIT_REAGENTS_FAILED)
	end
	BW.RefreshReagents()
end, "bank"))

-- The deposit line ends left of the box, on one line.
frame.deposit:SetPoint("RIGHT", BW.reagentsBox, "LEFT", -6, 0)
frame.deposit:SetWordWrap(false)

-- Live updates while open (spec 4.3), for the bank tabs only: count, lock and loaded data
-- repaint in place; an emptied slot or a different item goes to GroupView.Changes; a tab
```

In `SwagBag/UI/BankWindow.lua` (edit 4 of 4), find:

```lua
	BW.ApplyMode()
	BW.Layout("open")
```

and replace it with:

```lua
	BW.ApplyMode()
	BW.RefreshReagents()
	BW.Layout("open")
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1258 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1258 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/UI/BankWindow.lua SwagBag/Locale/enUS.lua spec/bankwindow_spec.lua spec/bankwindow_groups_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 6: Deposit warbound and With reagents on the bank window; bank free tile pinned; bank flash to chat when cut short

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 7: Bags you opened stay open when a vendor closes; the bag-hook trace; the bank's "Blizzard bank" answer in chat

From the user's in-game testing of 0.5.0 (fixes 1 and 4).
- **FM1 step 8.** The user opened the bags with B, opened a vendor, then walked out of range: SwagBag's bags closed. Closing the vendor by hand (step 5) kept them open. The only close path is `SwagBag/UI/SafeModeHooks.lua` `onCloseAll`. It closes when `frame == nil` or when the window was opened for that frame (`autoOpenedBy`). Blizzard's code is not on disk, so the walk-away path cannot be read. Two explanations fit what the user saw, and this task closes both (D16). (a) The walk-away close calls `CloseAllBags` without a frame: from now on a frameless call closes only a window the game opened. (b) A bag toggle runs inside the vendor's close and closes the window: a toggle inside a frame's `CloseAllBags` that closed the user's window opens it again, in the same frame, as `onOpenAll` already does for its inner toggle. A small trace keeps the last five hook calls for `/swagbag report` (`Bag hooks (last 5): …`), so session TF1 shows which one it was.
- **V2 step 6.** The bank's title flash `Blizzard's bank is shown for this visit` was never seen: the window jumps beside Blizzard's bank and the flash lasted 1.5 s. `BW.Flash` takes an optional duration and an optional "also to chat". The Blizzard bank button's answer stays 3 s and prints once in chat (D17). A line that is also cut short in the title still prints once, not twice.

**Files:**
- Modify: `SwagBag/UI/SafeModeHooks.lua` (header, `Hooks` fields, new `note`/`argName`/`didText`/`Hooks.TraceText`, `onBagKey`, `onOpenAll`, `onCloseAll`, `Hooks.Install`)
- Modify: `SwagBag/Core/Report.lua` (the `Bag hooks` line)
- Modify: `SwagBag/UI/BankWindow.lua` (`BW.FLASH`, `BW.VISIT_FLASH`, `BW.Flash`, `BW.ToggleVisit`)
- Modify: `SwagBag/Locale/enUS.lua` (`REPORT_BAG_HOOKS`, `REPORT_BAG_HOOK`, `HOOK_*`)
- Test: `spec/safemodehooks_spec.lua` (one test replaced by two, one test changed, three new), `spec/report_spec.lua` (one new), `spec/bankwindow_spec.lua` (one new)

**Interfaces:**
- Consumes: `SB.Adapter.Now`, `SB.BagsWindow.IsOpen/Open/Close/Toggle`, `SB.Print`, `SB.Adapter.After`, `SB.L.REPORT_NONE`.
- Produces:
  - `SB.SafeModeHooks.trace`: a list, newest last, of at most `Hooks.TRACE` (5) entries `{ kind, arg, did, at }`. `kind` is the hook (`"ToggleAllBags"`, `"ToggleBackpack"`, `"ToggleBag"`, `"OpenAllBags"`, `"CloseAllBags"`). `arg` is the frame's name, `"nil"`, `"?"` (a frame without a name), the bag number, or `""`. `did` is one of `opened`, `closed`, `kept`, `reopened`, `game`, `user`, `nothing`, `inactive`. `at` is `Adapter.Now()`;
  - `SB.SafeModeHooks.TraceText() -> text` (`L.REPORT_NONE` when empty) and `Hooks.toggleClosedUsers`;
  - `BW.Flash(text, seconds?, toChat?)` with `BW.FLASH = 1.5` and `BW.VISIT_FLASH = 3`;
  - the report line `Bag hooks (last 5): …`.

- [ ] **Step 1: Write the failing tests**

In `spec/bankwindow_spec.lua`, find:

```lua
	end)

	it("the Blizzard bank button does nothing in combat and says so", function()
```

and replace it with:

```lua
	end)

	-- Week 6, D17 (V2 step 6: the flash was never seen). Mutations: ToggleVisit's Flash without
	-- toChat; ToggleVisit's Flash without BW.VISIT_FLASH (1.5 s).
	it("the Blizzard bank button's answer stays 3 s in the title and goes to chat once", function()
		openBank()
		BW.frame.title.IsTruncated = function() return true end -- cut short too: still one chat line
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.same({ SB.L.BANK_SHOWING_BLIZZARD }, A.Lines())
		A.Advance(2)
		assert.equal(SB.L.BANK_SHOWING_BLIZZARD, BW.frame.title.text, "still there after 2 s")
		A.Advance(1)
		assert.equal(SB.L.BANK_TITLE, BW.frame.title.text)
		BW.frame.title.IsTruncated = nil
		Fake.Fire(BW.blizzardButton, "OnClick")
		assert.same({ SB.L.BANK_SHOWING_BLIZZARD, SB.L.BANK_HIDING_BLIZZARD }, A.Lines())
	end)

	it("the Blizzard bank button does nothing in combat and says so", function()
```

In `spec/report_spec.lua`, find:

```lua
	end)

	it("shows the bank setting, the last visit and the deposit target (check V2)", function()
```

and replace it with:

```lua
	end)

	-- Week 6, D16 (FM1 step 8). Mutation: drop the REPORT_BAG_HOOKS line in Report.Build.
	it("shows the last bag hook calls, for the vendor walk-away check", function()
		SB.Checks.last = {}
		SB.SafeModeHooks = { TRACE = 5, TraceText = function() return "CloseAllBags(nil) kept open at 10.5" end }
		assert.truthy(SB.Report.Build():find("\nBag hooks (last 5): CloseAllBags(nil) kept open at 10.5", 1, true))
	end)

	it("shows the bank setting, the last visit and the deposit target (check V2)", function()
```

In `spec/safemodehooks_spec.lua` (edit 1 of 3), find:

```lua
	end)

	it("CloseAllBags() with no frame always closes", function()
		windowOpen = true
		hooks.CloseAllBags()
		assert.falsy(windowOpen)
	end)
```

and replace it with:

```lua
	end)

	-- Week 6, D16 (FM1 step 8: walking away from a vendor closed bags opened with B). Mutation: in
	-- onCloseAll, close when `frame == nil` whoever opened the window (the week-1 rule).
	it("CloseAllBags() with no frame leaves a window the user opened open", function()
		windowOpen = true -- opened with B before talking to the vendor
		hooks.OpenAllBags(named("MerchantFrame"))
		A.Advance(1)
		hooks.CloseAllBags() -- the walk-away close, if it names no frame
		assert.truthy(windowOpen)
		assert.equal(0, closes)
	end)

	-- Mutation: in onCloseAll, drop `frame == nil or` from the game-opened test.
	it("CloseAllBags() with no frame still closes a window the game opened", function()
		hooks.OpenAllBags(named("MerchantFrame"))
		A.Advance(1)
		hooks.CloseAllBags()
		assert.falsy(windowOpen)
		assert.is_nil(SB.SafeModeHooks.autoOpenedBy)
	end)
```

In `spec/safemodehooks_spec.lua` (edit 2 of 3), find:

```lua
	end)

	it("a bag key whose ToggleAllBags closes through CloseAllBags() does not reopen", function()
		realToggle()
```

and replace it with:

```lua
	end)

	-- D16: the inner CloseAllBags() leaves the user's window alone; the key itself closes it, once.
	it("a bag key whose ToggleAllBags runs CloseAllBags() inside closes the window once", function()
		realToggle()
```

In `spec/safemodehooks_spec.lua` (edit 3 of 3), find:

```lua
		assert.falsy(windowOpen)
		assert.equal(0, toggles)
	end)
```

and replace it with:

```lua
		assert.falsy(windowOpen)
		assert.equal(1, toggles)
		assert.equal(0, closes)
	end)

	-- D16, the other way the walk-away could close it. Mutation: delete the reopen branch in onCloseAll.
	it("a bag toggle inside a vendor's CloseAllBags that closed the user's window opens it again", function()
		realToggle()
		windowOpen = true -- opened with B
		hooks.OpenAllBags(named("MerchantFrame")) -- found it open: still the user's
		A.Advance(1)
		hooks.ToggleBackpack() -- inner call of the vendor's close, same frame
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.truthy(windowOpen)
		assert.is_nil(SB.SafeModeHooks.autoOpenedBy)
	end)

	-- Mutation: in onBagKey, toggleClosedUsers = wasOpen and not W.IsOpen() (forgets who owned it).
	it("a bag toggle inside a vendor's CloseAllBags that closed the game's window leaves it closed", function()
		realToggle()
		hooks.OpenAllBags(named("MerchantFrame")) -- the game opened it for the vendor
		A.Advance(1)
		hooks.ToggleBackpack() -- inner call, same frame
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.falsy(windowOpen)
	end)

	-- Week 6: /swagbag report shows the last five. Mutation: drop the table.remove in note (keeps all).
	it("keeps the last five hook calls, oldest first, with what SwagBag did and when", function()
		realToggle()
		hooks.ToggleAllBags()
		A.Advance(0.5)
		hooks.OpenAllBags(named("MerchantFrame"))
		A.Advance(10)
		hooks.CloseAllBags()
		A.Advance(1)
		hooks.ToggleBag(2)
		A.Advance(1)
		hooks.ToggleBag(2)
		A.Advance(1)
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.equal(5, #SB.SafeModeHooks.trace)
		assert.equal("OpenAllBags(MerchantFrame) nothing at 0.5, CloseAllBags(nil) kept open at 10.5, "
			.. "ToggleBag(2) closed at 11.5, ToggleBag(2) opened at 12.5, CloseAllBags(MerchantFrame) kept open at 13.5",
			SB.SafeModeHooks.TraceText())
		SB.SafeMode.Enable("bags", "manual")
		hooks.ToggleAllBags()
		assert.same({ kind = "ToggleAllBags", arg = "", did = "inactive", at = 13.5 }, SB.SafeModeHooks.trace[5],
			"Safe Mode: noted, nothing done")
	end)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1258 passed, 6 failed`, and the failures are exactly:
```text
FAIL spec/bankwindow_spec.lua :: BankWindow frames (check V2) > the Blizzard bank button's answer stays 3 s in the title and goes to chat once
FAIL spec/report_spec.lua :: Report > shows the last bag hook calls, for the vendor walk-away check
FAIL spec/safemodehooks_spec.lua :: SafeModeHooks > CloseAllBags() with no frame leaves a window the user opened open
FAIL spec/safemodehooks_spec.lua :: SafeModeHooks > a bag key whose ToggleAllBags runs CloseAllBags() inside closes the window once
FAIL spec/safemodehooks_spec.lua :: SafeModeHooks > a bag toggle inside a vendor's CloseAllBags that closed the user's window opens it again
FAIL spec/safemodehooks_spec.lua :: SafeModeHooks > keeps the last five hook calls, oldest first, with what SwagBag did and when
```
Two new tests pass at Step 2 because they pin behaviour that already exists. "CloseAllBags() with no frame still closes a window the game opened" passes because today a frameless call closes every window. "a bag toggle inside a vendor's CloseAllBags that closed the game's window leaves it closed" passes because today nothing reopens.

Critical tests and the mutation each must catch (applied to the finished Task 7 code):
- "CloseAllBags() with no frame leaves a window the user opened open": in `onCloseAll`, replace `if by and (by == true or frame == nil or (frame.GetName and frame:GetName() == by)) then` with `if frame == nil or (by and (by == true or (frame.GetName and frame:GetName() == by))) then` (the week-1 rule).
- "CloseAllBags() with no frame still closes a window the game opened": in the same line, drop `frame == nil or ` and guard the name with `frame and`.
- "a bag toggle inside a vendor's CloseAllBags that closed the user's window opens it again": replace `if frame ~= nil and now == Hooks.lastAt and Hooks.lastKind == "toggle" and Hooks.toggleClosedUsers then` with `if false then`.
- "a bag toggle inside a vendor's CloseAllBags that closed the game's window leaves it closed": in `onBagKey`, `Hooks.toggleClosedUsers = wasOpen and not W.IsOpen()`.
- "keeps the last five hook calls …": in `note`, delete the `if #t > Hooks.TRACE then table.remove(t, 1) end` block.
- "shows the last bag hook calls …": delete the `REPORT_BAG_HOOKS` line in `Report.Build`.
- "the Blizzard bank button's answer stays 3 s …": in `BW.ToggleVisit`, drop the `true` argument; separately, pass `nil` instead of `BW.VISIT_FLASH`.

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Report.lua`, find:

```lua
	end
	local bank = SB.BankWindow
```

and replace it with:

```lua
	end
	local hooks = SB.SafeModeHooks
	if hooks and hooks.TraceText then -- week 6 (D16): the last bag functions the game ran, and what SwagBag did
		lines[#lines + 1] = L.REPORT_BAG_HOOKS:format(hooks.TRACE, hooks.TraceText())
	end
	local bank = SB.BankWindow
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_CATEGORIES = "Categories: %d (%d edited)  Broken: %s"
L.REPORT_LAYOUT = "Last bags layout: %.1f ms (%s)"

-- Bags window
```

and replace it with:

```lua
L.REPORT_CATEGORIES = "Categories: %d (%d edited)  Broken: %s"
L.REPORT_LAYOUT = "Last bags layout: %.1f ms (%s)"
-- The bag hooks' trace (week 6, D16): "Bag hooks (last 5): CloseAllBags(MerchantFrame) kept open at 1234.5, ..."
L.REPORT_BAG_HOOKS = "Bag hooks (last %d): %s"
L.REPORT_BAG_HOOK = "%s(%s) %s at %.1f"
L.HOOK_OPENED = "opened"
L.HOOK_CLOSED = "closed"
L.HOOK_KEPT = "kept open"
L.HOOK_REOPENED = "opened again"
L.HOOK_GAME = "now the game's"
L.HOOK_USER = "now yours"
L.HOOK_NOTHING = "nothing"
L.HOOK_INACTIVE = "off (Safe Mode or not ready)"

-- Bags window
```

In `SwagBag/UI/BankWindow.lua` (edit 1 of 4), find:

```lua
	SORT_TIMEOUT = 1.5,
}
```

and replace it with:

```lua
	SORT_TIMEOUT = 1.5,
	FLASH = 1.5, -- seconds a title answer shows
	VISIT_FLASH = 3, -- the Blizzard bank button's answer: the window may jump beside Blizzard's (D17)
}
```

In `SwagBag/UI/BankWindow.lua` (edit 2 of 4), find:

```lua
-- A flash cut short by the title's room (W3-26 bounds it) also goes to chat, so a long answer is
-- never lost (P2; the bags window's D27, week 5).
function BW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	if frame.title.IsTruncated and frame.title:IsTruncated() then
		SB.Print(text)
	end
	SB.Adapter.After(1.5, Guard("bank.flash", function()
		if token == titleToken then
```

and replace it with:

```lua
-- A flash cut short by the title's room (W3-26 bounds it) also goes to chat, so a long answer is
-- never lost (P2; the bags window's D27, week 5). seconds: how long it shows (default FLASH);
-- toChat: the line also goes to chat, once, whether or not it was cut short (week 6, D17).
function BW.Flash(text, seconds, toChat)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	if toChat or (frame.title.IsTruncated and frame.title:IsTruncated()) then
		SB.Print(text)
	end
	SB.Adapter.After(seconds or BW.FLASH, Guard("bank.flash", function()
		if token == titleToken then
```

In `SwagBag/UI/BankWindow.lua` (edit 3 of 4), find:

```lua
end

-- The "Blizzard bank" button: show or hide Blizzard's bank for this visit.
function BW.ToggleVisit()
```

and replace it with:

```lua
end

-- The "Blizzard bank" button: show or hide Blizzard's bank for this visit. The window jumps
-- beside Blizzard's bank (or back), so the answer shows longer and also goes to chat (D17).
function BW.ToggleVisit()
```

In `SwagBag/UI/BankWindow.lua` (edit 4 of 4), find:

```lua
	BW.ApplyMode()
	BW.Flash(BW.visit == "beside" and L.BANK_SHOWING_BLIZZARD or L.BANK_HIDING_BLIZZARD)
	return true
```

and replace it with:

```lua
	BW.ApplyMode()
	BW.Flash(BW.visit == "beside" and L.BANK_SHOWING_BLIZZARD or L.BANK_HIDING_BLIZZARD, BW.VISIT_FLASH, true)
	return true
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 1 of 11), find:

```lua
-- the bookkeeping instead of toggling again.
local _, SB = ...
```

and replace it with:

```lua
-- the bookkeeping instead of toggling again.
-- Who owns the window (week 6, D16): a window the user opened (B, a bag icon) closes only by the
-- user's own hand (B, Esc, the X). No CloseAllBags closes it, with a frame or without one, and a
-- bag toggle that runs inside a frame's CloseAllBags and closes it opens it again. A window the
-- game opened for a frame (its OpenAllBags named that frame) closes with that frame's CloseAllBags,
-- or with a CloseAllBags() that names no frame.
-- Hooks.TraceText() -> text: the last TRACE hook calls (hook, its argument, what SwagBag did, when),
-- oldest first, for /swagbag report ("Bag hooks (last 5): ...").
local _, SB = ...
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 2 of 11), find:

```lua
-- lastKind: "toggle" (a bag key toggled), "auto" (OpenAllBags opened it), "closed"
-- (CloseAllBags closed it), "none" (OpenAllBags found it already open).
local Hooks = { installed = false, lastAt = -1, lastKind = nil, toggleOpened = false, autoOpenedBy = nil }
SB.SafeModeHooks = Hooks

function Hooks.IsActive()
```

and replace it with:

```lua
-- lastKind: "toggle" (a bag key toggled), "auto" (OpenAllBags opened it), "closed"
-- (CloseAllBags closed it), "none" (OpenAllBags found it already open).
-- toggleClosedUsers: the last toggle closed a window the user had opened (D16).
local Hooks = { installed = false, lastAt = -1, lastKind = nil, toggleOpened = false, toggleClosedUsers = false,
	autoOpenedBy = nil, trace = {}, TRACE = 5 }
SB.SafeModeHooks = Hooks

-- The trace (week 6): one entry per hook call, the newest last, at most TRACE of them.
local function note(kind, arg, did)
	local t = Hooks.trace
	t[#t + 1] = { kind = kind, arg = arg, did = did, at = SB.Adapter.Now() }
	if #t > Hooks.TRACE then
		table.remove(t, 1)
	end
end

local function argName(frame)
	if frame == nil then
		return "nil"
	end
	local name = frame.GetName and frame:GetName()
	return type(name) == "string" and name or "?"
end

local function didText(did)
	local L = SB.L
	return ({ opened = L.HOOK_OPENED, closed = L.HOOK_CLOSED, kept = L.HOOK_KEPT, reopened = L.HOOK_REOPENED,
		game = L.HOOK_GAME, user = L.HOOK_USER, nothing = L.HOOK_NOTHING, inactive = L.HOOK_INACTIVE })[did] or did
end

function Hooks.TraceText()
	local L, parts = SB.L, {}
	for i, e in ipairs(Hooks.trace) do
		parts[i] = L.REPORT_BAG_HOOK:format(e.kind, e.arg, didText(e.did), e.at)
	end
	return #parts > 0 and table.concat(parts, ", ") or L.REPORT_NONE
end

function Hooks.IsActive()
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 3 of 11), find:

```lua
end

-- B / backpack / bag-bar icon.
local function onBagKey()
	if not Hooks.IsActive() then
		Hooks.autoOpenedBy = nil
		return
```

and replace it with:

```lua
end

-- B / backpack / bag-bar icon. kind: the hook's name; arg: ToggleBag's bag number or "".
local function onBagKey(kind, arg)
	if not Hooks.IsActive() then
		Hooks.autoOpenedBy = nil
		note(kind, arg, "inactive")
		return
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 4 of 11), find:

```lua
			Hooks.lastKind = "toggle"
			return
		elseif Hooks.lastKind ~= "none" then
			return
		end
	end
	Hooks.autoOpenedBy = nil
```

and replace it with:

```lua
			Hooks.lastKind = "toggle"
			note(kind, arg, "user")
			return
		elseif Hooks.lastKind ~= "none" then
			note(kind, arg, "nothing")
			return
		end
	end
	local wasUsers = Hooks.autoOpenedBy == nil
	Hooks.autoOpenedBy = nil
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 5 of 11), find:

```lua
	Hooks.toggleOpened = not wasOpen and W.IsOpen()
end
```

and replace it with:

```lua
	Hooks.toggleOpened = not wasOpen and W.IsOpen()
	Hooks.toggleClosedUsers = wasOpen and wasUsers and not W.IsOpen()
	note(kind, arg, W.IsOpen() and "opened" or "closed")
end
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 6 of 11), find:

```lua
local function onOpenAll(frame)
	if not Hooks.IsActive() then
		return
```

and replace it with:

```lua
local function onOpenAll(frame)
	local arg = argName(frame)
	if not Hooks.IsActive() then
		note("OpenAllBags", arg, "inactive")
		return
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 7 of 11), find:

```lua
		-- opened it; if it closed a window the user had open, open it again.
		if Hooks.lastKind == "toggle" then
			if Hooks.toggleOpened then
				Hooks.autoOpenedBy = frameName(frame)
			elseif not W.IsOpen() then
				W.Open()
			end
		end
		return
```

and replace it with:

```lua
		-- opened it; if it closed a window the user had open, open it again.
		local did = "nothing"
		if Hooks.lastKind == "toggle" then
			if Hooks.toggleOpened then
				Hooks.autoOpenedBy = frameName(frame)
				did = "game"
			elseif not W.IsOpen() then
				W.Open()
				did = "reopened"
			end
		end
		note("OpenAllBags", arg, did)
		return
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 8 of 11), find:

```lua
		Hooks.lastKind = "none"
		return
```

and replace it with:

```lua
		Hooks.lastKind = "none"
		note("OpenAllBags", arg, "nothing")
		return
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 9 of 11), find:

```lua
		Hooks.lastKind = "auto"
	end
end

-- CloseAllBags(frame): close only a window the game opened for that frame
-- (CloseAllBags() with no frame always closes).
local function onCloseAll(frame)
	if not Hooks.IsActive() then
		return
	end
	local by = Hooks.autoOpenedBy
	if frame == nil or (by and (by == true or (frame.GetName and frame:GetName() == by))) then
		local wasOpen = SB.BagsWindow.IsOpen()
		SB.BagsWindow.Close()
		Hooks.autoOpenedBy = nil
		if wasOpen then
			Hooks.lastAt, Hooks.lastKind = SB.Adapter.Now(), "closed"
		end
	end
end
```

and replace it with:

```lua
		Hooks.lastKind = "auto"
		note("OpenAllBags", arg, "opened")
	else
		note("OpenAllBags", arg, "nothing")
	end
end

-- CloseAllBags(frame) (D16): closes only a window the game opened, for that frame (any frame
-- when its OpenAllBags named none), or with no frame at all. A window the user opened stays,
-- with or without a frame: the vendor's walk-away close (FM1 step 8) leaves it open, as
-- Blizzard's own bags stay open after a vendor that did not open them.
local function onCloseAll(frame)
	local arg = argName(frame)
	if not Hooks.IsActive() then
		note("CloseAllBags", arg, "inactive")
		return
	end
	local W = SB.BagsWindow
	local now = SB.Adapter.Now()
	if frame ~= nil and now == Hooks.lastAt and Hooks.lastKind == "toggle" and Hooks.toggleClosedUsers then
		-- A bag toggle ran inside this frame's CloseAllBags and closed the user's window: open it
		-- again. Never for CloseAllBags() with no frame: that runs inside the bag key itself.
		Hooks.toggleClosedUsers = false
		W.Open()
		note("CloseAllBags", arg, "reopened")
		return
	end
	local by = Hooks.autoOpenedBy
	if by and (by == true or frame == nil or (frame.GetName and frame:GetName() == by)) then
		local wasOpen = W.IsOpen()
		W.Close()
		Hooks.autoOpenedBy = nil
		if wasOpen then
			Hooks.lastAt, Hooks.lastKind = now, "closed"
		end
		note("CloseAllBags", arg, wasOpen and "closed" or "nothing")
		return
	end
	note("CloseAllBags", arg, W.IsOpen() and "kept" or "nothing")
end
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 10 of 11), find:

```lua
	local Guard = SB.ErrorTrap.Guard
	hooksecurefunc("ToggleAllBags", Guard("hook:ToggleAllBags", onBagKey, "bags"))
	hooksecurefunc("ToggleBackpack", Guard("hook:ToggleBackpack", onBagKey, "bags"))
	if ToggleBag then
```

and replace it with:

```lua
	local Guard = SB.ErrorTrap.Guard
	hooksecurefunc("ToggleAllBags", Guard("hook:ToggleAllBags", function()
		onBagKey("ToggleAllBags", "")
	end, "bags"))
	hooksecurefunc("ToggleBackpack", Guard("hook:ToggleBackpack", function()
		onBagKey("ToggleBackpack", "")
	end, "bags"))
	if ToggleBag then
```

In `SwagBag/UI/SafeModeHooks.lua` (edit 11 of 11), find:

```lua
			if type(id) == "number" and id >= 0 and id <= 5 then
				onBagKey()
			end
```

and replace it with:

```lua
			if type(id) == "number" and id >= 0 and id <= 5 then
				onBagKey("ToggleBag", tostring(id))
			end
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1264 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1264 passed, 0 failed`, and the last line `ALL CHECKS PASSED`. (A comment that writes the forbidden open-all-bags call with its parenthesis fails step 3/5. The header says "its OpenAllBags named that frame" for that reason.)

- [ ] **Step 6: Commit**

```bash
git add SwagBag/UI/SafeModeHooks.lua SwagBag/Core/Report.lua SwagBag/UI/BankWindow.lua SwagBag/Locale/enUS.lua \
  spec/safemodehooks_spec.lua spec/report_spec.lua spec/bankwindow_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 7: bags the user opened stay open when a vendor closes, bag-hook trace in the report, Blizzard bank answer in chat for 3 s

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 8: Plain-words explanations (Focus modes page, Pause, quick setup) and choice buttons that fit their text

From the user's in-game testing of 0.5.0 (fixes 2 and 3).
- **S1 and FM1.** The user did not understand the Pause/Resume button or the Focus modes page. The shared row builder (`UI/SettingsWindow.lua` `SW.Render`) learns a row-level `tip`: a short text shown when the mouse rests on any of the row's buttons, under the row's label. A choice or action may add its own `tip` after it. Any page can use it later. Settings > Focus modes starts with a plain-words note (`L.SET_FOCUS_INTRO`). Every row with buttons gets a tip, including Task 3's `While a mode is on` row (`L.SET_FOCUS_STYLE`, `Move to the top` / `Collapse the rest`), each mode's row and each section row. The Pause button's tooltip now says what a click does in plain words, with a Resume version while paused, and keeps the right-click line. Quick setup gets one line about the Pause button (D18).
- **O2 step 19.** On Settings > Alt data, `Shown (not twice with Syndicator)` spilled past its 190-px button and the next button was cut. In the same row builder, each button is now as wide as its text plus `SW.TEXT_PAD`, never narrower than the row's width. A button that no longer fits the line starts the next one, and the rows below move down by the extra line (D19).

The tooltip and wrap code is in the settings window, so its scripts trap under `"none"` (P6: settings), with the labels `settings.tip` and `settings.tipHide`. The tips live in `SW.tips[button]`, a side table like `SW.selected`. A field on the pooled button would read as a method on the test fakes (a fake answers every unknown key with a function), and the side table is cleared with the pool.

**Files:**
- Modify: `SwagBag/UI/SettingsWindow.lua` (header, `SW` fields `tips`/`LINE_GAP`/`TEXT_PAD`, new `SW.ShowTip`, `button()` scripts and reset, new `textWidth`, the item loop in `SW.Render`)
- Modify: `SwagBag/UI/SettingsFocus.lua` (header, `setting` takes a tip, section and reset rows' tips, new `whenText`, `rows()` intro and tips)
- Modify: `SwagBag/UI/BagsWindow.lua` (the Pause button's tooltip)
- Modify: `SwagBag/UI/QuickSetup.lua` (`frame.pauseNote`)
- Modify: `SwagBag/Locale/enUS.lua` (`SET_FOCUS_INTRO`, `SET_*_TIP`, `SET_MODE_WHEN_*`, `MODE_TIP_*`, `QS_PAUSE_NOTE`; `MODE_TIP_LEFT` is removed, since nothing uses it any more)
- Test: `spec/settings_spec.lua` (two new), `spec/settings_focus_spec.lua` (one new; one test's row numbers move by one), `spec/bagswindow_sections_spec.lua` (the Pause tooltip test rewritten), `spec/quicksetup_spec.lua` (one new)

**Interfaces:**
- Consumes: `SB.Focus.Style/IsPaused/MODES`, `SB.Focus.byId`, `Button:GetTextWidth()` (WoW; 0 when the client cannot say), `GameTooltip`.
- Produces:
  - row field `tip` and item field `tip` for every settings page, with `SW.tips[button] = { title, text, extra }` and `SW.ShowTip(button)`;
  - `SW.TEXT_PAD = 24` and `SW.LINE_GAP = 4`;
  - `QS.frame.pauseNote`;
  - Locale keys quoted in session TF1.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua` (edit 1 of 2), find:

```lua
	end)

	-- Mutation: delete the AddLine for the right-click.
	it("the Pause tooltip names both clicks", function()
		local lines = {}
```

and replace it with:

```lua
	end)

	-- Week 6, D18 (FM1: the user did not know what Pause does). Mutations: delete the AddLine for
	-- the right-click; always show the Pause text (ignore IsPaused).
	it("the Pause tooltip says in plain words what a click does now, and names the right-click", function()
		local lines = {}
```

In `spec/bagswindow_sections_spec.lua` (edit 2 of 2), find:

```lua
		W.modeButton.scripts.OnEnter(W.modeButton)
		GameTooltip = nil
		assert.same({ SB.L.MODE_TIP_TITLE, SB.L.MODE_TIP_LEFT, SB.L.MODE_TIP_RIGHT }, lines)
	end)
```

and replace it with:

```lua
		W.modeButton.scripts.OnEnter(W.modeButton)
		W.modeButton.scripts.OnClick(W.modeButton, "LeftButton")
		W.modeButton.scripts.OnEnter(W.modeButton)
		GameTooltip = nil
		assert.same({ "Pause focus modes", SB.L.MODE_TIP_BODY, SB.L.MODE_TIP_RIGHT,
			"Resume focus modes", SB.L.MODE_TIP_BODY_PAUSED, SB.L.MODE_TIP_RIGHT }, lines)
	end)
```

In `spec/quicksetup_spec.lua`, find:

```lua
	end)

	it("a picked style shows as picked; a second click unpicks it", function()
```

and replace it with:

```lua
	end)

	-- Week 6, D18. Mutation: delete the pauseNote SetText.
	it("explains the bags' Pause button in one line", function()
		SB.Slash.Dispatch("setup")
		assert.equal(SB.L.QS_PAUSE_NOTE, QS.frame.pauseNote.text)
		assert.truthy(QS.frame.pauseNote.shown)
	end)

	it("a picked style shows as picked; a second click unpicks it", function()
```

In `spec/settings_focus_spec.lua` (edit 1 of 2), find:

```lua
		return SW.selected[rowButton(rowLabel, text)] == true
	end

	it("AC8.1 and P1: the defaults are selected, each with its alternative next to it", function()
```

and replace it with:

```lua
		return SW.selected[rowButton(rowLabel, text)] == true
	end

	-- Week 6, D18 (S1: the page was not understood). Mutations: drop the intro row; drop the tip of
	-- the style row (or of any other row with buttons).
	it("starts with a plain-words intro, and every row with buttons explains itself on hover", function()
		local all = SW.byId.focus.rows()
		assert.same({ kind = "note", label = L.SET_FOCUS_INTRO }, all[1])
		assert.equal(L.SET_FOCUS_INTRO, SW.labels[1].text)
		for _, row in ipairs(all) do
			if row.choices or row.actions then
				assert.truthy(type(row.tip) == "string" and row.tip ~= "", "no tip on " .. row.label)
			end
		end
		local lines = {}
		GameTooltip = { SetOwner = function() end, SetText = function(_, t) lines[#lines + 1] = t end,
			AddLine = function(_, t) lines[#lines + 1] = t end, Show = function() end }
		Fake.Fire(rowButton(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_COLLAPSE), "OnEnter")
		Fake.Fire(rowButton(L.SET_MODE_LABEL:format("Fishing"), L.SET_ON), "OnEnter")
		Fake.Fire(rowButton("Junk", L.SET_SECTION_OPEN), "OnEnter")
		assert.same({ L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_TIP,
			L.SET_MODE_LABEL:format("Fishing"), "On: this mode switches on by itself while you fish. Off: it never does;"
				.. " the other modes still work.",
			"Junk", L.SET_SECTION_TIP:format("M+") }, lines)
	end)

	it("AC8.1 and P1: the defaults are selected, each with its alternative next to it", function()
```

In `spec/settings_focus_spec.lua` (edit 2 of 2), find:

```lua
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT)
		assert.truthy(SW.byId.focus.rows()[1].label == L.SET_FOCUS_AUTO)
		assert.falsy(SW.byId.focus.rows()[7].label:find("this character", 1, true), "row 7: the first mode")
	end)
```

and replace it with:

```lua
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT)
		assert.truthy(SW.byId.focus.rows()[2].label == L.SET_FOCUS_AUTO, "row 1 is the intro (week 6)")
		assert.falsy(SW.byId.focus.rows()[8].label:find("this character", 1, true), "row 8: the first mode")
	end)
```

In `spec/settings_spec.lua`, find:

```lua
		assert.equal(n, #Fake.created)
	end)
end)
```

and replace it with:

```lua
		assert.equal(n, #Fake.created)
	end)

	-- A test page shaped like Settings > Alt data (O2 step 19: "Shown (not twice with Syndicator)"
	-- spilled out of its button and the next button was cut). Text is 6 px per character.
	local function wideRows()
		local create = CreateFrame
		CreateFrame = function(kind, name, parent, template)
			local f = create(kind, name, parent, template)
			if kind == "Button" then
				function f.GetTextWidth(self)
					return 6 * #(self.text or "")
				end
			end
			return f
		end
		SW.AddPage({ id = "wide", title = "Wide", rows = function()
			return {
				{ kind = "choice", label = "Counts", width = 190, tip = "What the row does.", get = function() return "auto" end,
					choices = { { value = "auto", text = "Shown (not twice with Syndicator)", tip = "The default." },
						{ value = "on", text = "Always shown" }, { value = "off", text = "Hidden" } },
					apply = function() return "done" end },
				{ kind = "note", label = "Below" },
			}
		end })
		SW.Show("wide")
	end

	local function topLeft(region)
		local p = region.points[#region.points]
		return { p[4], p[5] }
	end

	-- Week 6, D19. Mutations: size every button to the row's width only (no text width); drop the
	-- out-of-room line break.
	it("a button is as wide as its text plus padding; one that does not fit starts the next line", function()
		wideRows()
		local b1, b2, b3 = button("Shown (not twice with Syndicator)"), button("Always shown"), button("Hidden")
		assert.equal(6 * 33 + SW.TEXT_PAD, b1.w, "the long text fits its button")
		assert.equal(190, b2.w, "never narrower than the row's width")
		assert.same({ 12, -22 }, topLeft(b1))
		assert.same({ 12 + b1.w + 4, -22 }, topLeft(b2))
		assert.same({ 12, -22 - SW.ROW - SW.LINE_GAP }, topLeft(b3), "out of room: the next line")
		assert.same({ 4, -22 - SW.ROW - SW.LINE_GAP - SW.ROW - SW.GAP }, topLeft(SW.labels[2]),
			"the row grew: the note below moved down")
		assert.truthy(b2.w + topLeft(b2)[1] <= SW.child:GetWidth(), "nothing runs past the page")
	end)

	-- Week 6, D18. Mutations: in ShowTip, skip the item's own tip; in OnLeave, always Hide.
	it("a row's tip shows on its buttons with the button's own tip after it; leaving hides it", function()
		wideRows()
		local lines = {}
		GameTooltip = Fake.New("GameTooltip")
		function GameTooltip.SetText(_, t) lines[#lines + 1] = t end
		function GameTooltip.AddLine(_, t) lines[#lines + 1] = t end
		function GameTooltip.IsOwned(t, owner) return t.calls.SetOwner ~= nil and t.calls.SetOwner[1] == owner end
		Fake.Fire(button("Shown (not twice with Syndicator)"), "OnEnter")
		assert.same({ "Counts", "What the row does.", "The default." }, lines)
		GameTooltip:Show()
		Fake.Fire(button("Hidden"), "OnLeave")
		assert.truthy(GameTooltip.shown, "another button's leave leaves the tooltip alone")
		Fake.Fire(button("Shown (not twice with Syndicator)"), "OnLeave")
		assert.falsy(GameTooltip.shown)
		SW.Show("bags")
		lines = {}
		Fake.Fire(button("Categories"), "OnEnter")
		assert.same({}, lines, "a row without a tip shows none")
	end)
end)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1262 passed, 6 failed`, and the failures are exactly:
```text
FAIL spec/bagswindow_sections_spec.lua :: BagsWindow focus modes (spec 6) > the Pause tooltip says in plain words what a click does now, and names the right-click
FAIL spec/quicksetup_spec.lua :: Quick setup > explains the bags' Pause button in one line
FAIL spec/settings_focus_spec.lua :: Settings: focus modes page > starts with a plain-words intro, and every row with buttons explains itself on hover
FAIL spec/settings_focus_spec.lua :: Settings: focus modes page > the layer is named while "This character" is on: the sections note and the mode labels
FAIL spec/settings_spec.lua :: Settings window > a button is as wide as its text plus padding; one that does not fit starts the next line
FAIL spec/settings_spec.lua :: Settings window > a row's tip shows on its buttons with the button's own tip after it; leaving hides it
```
"the layer is named …" fails only because its row numbers already count the intro row that Step 3 adds.

Critical tests and the mutation each must catch (applied to the finished Task 8 code):
- "a button is as wide as its text plus padding …": `textWidth` returns `0`; separately, replace `if x > 12 and x + w > room then` with `if false then`.
- "a row's tip shows on its buttons …": in `SW.ShowTip`, replace `if tip.extra then` with `if false then`; separately, in the pooled button's `OnLeave`, replace the `IsOwned` test with `if GameTooltip then`.
- "starts with a plain-words intro …": delete the `{ kind = "note", label = L.SET_FOCUS_INTRO }` row; separately, drop `tip = L.SET_FOCUS_STYLE_TIP,` from the style row.
- "the Pause tooltip says in plain words …": delete `GameTooltip:AddLine(L.MODE_TIP_RIGHT, 1, 1, 1)`; separately, `local paused = false`.
- "explains the bags' Pause button in one line": delete `frame.pauseNote:SetText(L.QS_PAUSE_NOTE)`.

- [ ] **Step 3: Write the implementation**

In `SwagBag/Locale/enUS.lua` (edit 1 of 2), find:

```lua
L.SET_GATHERING_NOTE = "Gathering opens only the materials of the gathering professions this character has."
L.MODE_TIP_TITLE = "Focus modes"
L.MODE_TIP_LEFT = "Left-click: pause or resume for this session"
L.MODE_TIP_RIGHT = "Right-click: choose the sections this mode opens"
```

and replace it with:

```lua
L.SET_GATHERING_NOTE = "Gathering opens only the materials of the gathering professions this character has."
-- Settings > Focus modes in plain words (week 6, D18): the page's first line, and each row's tooltip.
L.SET_FOCUS_INTRO = "Focus modes open the sections you need for what you're doing (a key, the vendor, fishing) and tidy"
	.. " the rest. They switch by themselves. Rest the mouse on a button to see what it does."
L.SET_FOCUS_AUTO_TIP = "Switch by themselves: SwagBag sees what you are doing (a key, a raid, a vendor, fishing...) and"
	.. " switches the matching mode on and off for you. Off: no mode ever changes your sections."
L.SET_FOCUS_STYLE_TIP = "Move to the top: the mode's sections come first, right under New, and nothing is collapsed."
	.. " Collapse the rest: only the mode's sections stay open; every other section collapses until the mode ends."
L.SET_FOCUS_RESOLVE_TIP = "Sometimes two modes apply at once, like fishing while a vendor is open. Open both sets: the"
	.. " sections of both modes count. Strict priority: only the stronger mode's (a dungeon or an activity before the vendor)."
L.SET_FOCUS_PEEK_TIP = "Only used with Collapse the rest. Peeks: a collapsed section you click opens until you close your"
	.. " bags. Keeps it open: it stays open until the mode changes."
L.SET_FOCUS_ANNOUNCE_TIP = "Announce: one chat line each time the mode changes. Quiet: no chat line; the bags' title"
	.. " still names the mode."
L.SET_FOCUS_SCOPE_TIP = "All characters: one set of focus settings for every character. This character: this"
	.. " character gets its own copy to change; the others keep theirs."
L.SET_MODE_TIP = "On: this mode switches on by itself %s. Off: it never does; the other modes still work."
L.SET_MODE_WHEN_MPLUS = "while a Mythic+ key runs"
L.SET_MODE_WHEN_RAID = "inside a raid"
L.SET_MODE_WHEN_DELVES = "inside a delve"
L.SET_MODE_WHEN_GATHERING = "while you gather herbs, ore or leather"
L.SET_MODE_WHEN_FISHING = "while you fish"
L.SET_MODE_WHEN_MARKET = "while a vendor, the auction house or your bank is open"
L.SET_EDIT_MODE_TIP = "Pick a mode to see and change its sections in the rows below."
L.SET_SECTION_TIP = "Open: the %s mode uses this section (moves it up, or keeps it open with Collapse the rest)."
	.. " Collapsed: the mode leaves it where it is (or collapses it with Collapse the rest)."
L.SET_SECTIONS_DEFAULT_TIP = "Puts this mode's sections back to SwagBag's choice. Your other modes keep theirs."
L.MODE_TIP_TITLE = "Pause focus modes"
L.MODE_TIP_BODY = "Sections stop opening, closing and moving by themselves until you click Resume (or log in again)."
L.MODE_TIP_TITLE_PAUSED = "Resume focus modes"
L.MODE_TIP_BODY_PAUSED = "Focus modes are paused: your sections stay as you set them. Click to let modes switch by"
	.. " themselves again."
L.MODE_TIP_RIGHT = "Right-click: choose the sections this mode opens"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 2), find:

```lua
L.QS_HINT = "Apply sets SwagBag up for what you picked. Skip keeps SwagBag's defaults."
L.QS_MPLUS = "M+"
```

and replace it with:

```lua
L.QS_HINT = "Apply sets SwagBag up for what you picked. Skip keeps SwagBag's defaults."
L.QS_PAUSE_NOTE = "Focus modes bring up the sections you need (a key, the vendor, fishing) by themselves. The Pause"
	.. " button at the top of your bags stops them until you click Resume."
L.QS_MPLUS = "M+"
```

In `SwagBag/UI/BagsWindow.lua` (edit 1 of 2), find:

```lua
-- sections (AC8.5). The settings open under ErrorTrap "none": a settings glitch flashes
-- L.SETTINGS_FAILED here and never puts the bags into Safe Mode (W4-5). The tooltip says both.
W.modeButton = titleButton(L.BTN_PAUSE, "bags.modeButton", function(_, mouseButton)
```

and replace it with:

```lua
-- sections (AC8.5). The settings open under ErrorTrap "none": a settings glitch flashes
-- L.SETTINGS_FAILED here and never puts the bags into Safe Mode (W4-5). The tooltip says what a
-- click does now, in plain words (week 6, D18), and names the right-click.
W.modeButton = titleButton(L.BTN_PAUSE, "bags.modeButton", function(_, mouseButton)
```

In `SwagBag/UI/BagsWindow.lua` (edit 2 of 2), find:

```lua
W.modeButton:SetScript("OnEnter", Guard("bags.modeTip", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L.MODE_TIP_TITLE)
	GameTooltip:AddLine(L.MODE_TIP_LEFT, 1, 1, 1)
	GameTooltip:AddLine(L.MODE_TIP_RIGHT, 1, 1, 1)
```

and replace it with:

```lua
W.modeButton:SetScript("OnEnter", Guard("bags.modeTip", function(self)
	local paused = SB.Focus and SB.Focus.IsPaused()
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(paused and L.MODE_TIP_TITLE_PAUSED or L.MODE_TIP_TITLE)
	GameTooltip:AddLine(paused and L.MODE_TIP_BODY_PAUSED or L.MODE_TIP_BODY, 1, 1, 1, true)
	GameTooltip:AddLine(L.MODE_TIP_RIGHT, 1, 1, 1)
```

In `SwagBag/UI/QuickSetup.lua` (edit 1 of 2), find:

```lua
frame.columnsLabel:SetText(L.SET_COLUMNS)
frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
```

and replace it with:

```lua
frame.columnsLabel:SetText(L.SET_COLUMNS)
-- Week 6 (D18): what the Pause button on the bags is for, before the user meets it.
frame.pauseNote = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.pauseNote:SetPoint("TOPLEFT", 14, -160)
frame.pauseNote:SetWidth(532)
frame.pauseNote:SetJustifyH("LEFT")
frame.pauseNote:SetWordWrap(true)
frame.pauseNote:SetText(L.QS_PAUSE_NOTE)
frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
```

In `SwagBag/UI/QuickSetup.lua` (edit 2 of 2), find:

```lua
	SB.Theme.Text(frame.columnsLabel, "label")
	SB.Theme.Text(frame.status, "small")
```

and replace it with:

```lua
	SB.Theme.Text(frame.columnsLabel, "label")
	SB.Theme.Text(frame.pauseNote, "small")
	SB.Theme.Text(frame.status, "small")
```

In `SwagBag/UI/SettingsFocus.lua` (edit 1 of 8), find:

```lua
--   SettingsFocus.Edit(modeId)   open the page with that mode's sections shown
-- Every write goes through Config.Set or the Focus writers; Config emits SB_CONFIG_CHANGED and
```

and replace it with:

```lua
--   SettingsFocus.Edit(modeId)   open the page with that mode's sections shown
-- The page starts with a plain-words note, and every row with buttons has a tooltip (row.tip, week 6).
-- Every write goes through Config.Set or the Focus writers; Config emits SB_CONFIG_CHANGED and
```

In `SwagBag/UI/SettingsFocus.lua` (edit 2 of 8), find:

```lua
end

local function setting(label, path, choices, done)
	return { kind = "choice", label = label, choices = choices, get = function()
		return SB.Config.Get(path)
```

and replace it with:

```lua
end

local function setting(label, path, choices, done, tip)
	return { kind = "choice", label = label, choices = choices, tip = tip, get = function()
		return SB.Config.Get(path)
```

In `SwagBag/UI/SettingsFocus.lua` (edit 3 of 8), find:

```lua
			local name = SB.Categories.Name(sid)
			rows[#rows + 1] = { kind = "choice", label = name, width = 96,
				choices = { { value = true, text = L.SET_SECTION_OPEN }, { value = false, text = L.SET_SECTION_CLOSED } },
```

and replace it with:

```lua
			local name = SB.Categories.Name(sid)
			rows[#rows + 1] = { kind = "choice", label = name, width = 96, tip = L.SET_SECTION_TIP:format(modeName(id)),
				choices = { { value = true, text = L.SET_SECTION_OPEN }, { value = false, text = L.SET_SECTION_CLOSED } },
```

In `SwagBag/UI/SettingsFocus.lua` (edit 4 of 8), find:

```lua
	end
	rows[#rows + 1] = { kind = "actions", label = L.SET_SECTIONS_DEFAULT_LABEL, actions = { { text = L.SET_RESET_DEFAULT,
		run = function()
```

and replace it with:

```lua
	end
	rows[#rows + 1] = { kind = "actions", label = L.SET_SECTIONS_DEFAULT_LABEL, tip = L.SET_SECTIONS_DEFAULT_TIP,
		actions = { { text = L.SET_RESET_DEFAULT,
		run = function()
```

In `SwagBag/UI/SettingsFocus.lua` (edit 5 of 8), find:

```lua
end

local function rows()
	local F = SB.Focus
	local out = {
		setting(L.SET_FOCUS_AUTO, "focus.auto", { { value = true, text = L.SET_FOCUS_AUTO_ON },
			{ value = false, text = L.SET_OFF } }, function(v)
			return v and L.SET_FOCUS_AUTO_DONE or L.SET_FOCUS_OFF_DONE
		end),
		-- Week 6: move the mode's sections up (default) or collapse the rest (the week-4 way). The same
		-- writer as /swagbag mode style, so both answer alike and refuse while read-only.
		{ kind = "choice", label = L.SET_FOCUS_STYLE, choices = { { value = "front", text = L.SET_FOCUS_STYLE_FRONT },
			{ value = "collapse", text = L.SET_FOCUS_STYLE_COLLAPSE } },
```

and replace it with:

```lua
end

-- When each mode switches on, for its row's tooltip.
local function whenText(id)
	return ({ mplus = L.SET_MODE_WHEN_MPLUS, raid = L.SET_MODE_WHEN_RAID, delves = L.SET_MODE_WHEN_DELVES,
		gathering = L.SET_MODE_WHEN_GATHERING, fishing = L.SET_MODE_WHEN_FISHING, market = L.SET_MODE_WHEN_MARKET })[id]
		or ""
end

local function rows()
	local F = SB.Focus
	local out = {
		{ kind = "note", label = L.SET_FOCUS_INTRO }, -- week 6: what focus modes are, in plain words (D18)
		setting(L.SET_FOCUS_AUTO, "focus.auto", { { value = true, text = L.SET_FOCUS_AUTO_ON },
			{ value = false, text = L.SET_OFF } }, function(v)
			return v and L.SET_FOCUS_AUTO_DONE or L.SET_FOCUS_OFF_DONE
		end, L.SET_FOCUS_AUTO_TIP),
		-- Week 6: move the mode's sections up (default) or collapse the rest (the week-4 way). The same
		-- writer as /swagbag mode style, so both answer alike and refuse while read-only.
		{ kind = "choice", label = L.SET_FOCUS_STYLE, tip = L.SET_FOCUS_STYLE_TIP,
			choices = { { value = "front", text = L.SET_FOCUS_STYLE_FRONT },
			{ value = "collapse", text = L.SET_FOCUS_STYLE_COLLAPSE } },
```

In `SwagBag/UI/SettingsFocus.lua` (edit 6 of 8), find:

```lua
			return v == "merge" and L.SET_FOCUS_MERGE_DONE or L.SET_FOCUS_PRIORITY_DONE
		end),
		setting(L.SET_FOCUS_PEEK, "focus.peek", { { value = "peek", text = L.SET_FOCUS_PEEK_PEEK },
			{ value = "keep", text = L.SET_FOCUS_PEEK_KEEP } }, function(v)
			return v == "peek" and L.SET_FOCUS_PEEK_DONE or L.SET_FOCUS_KEEP_DONE
		end),
		setting(L.SET_FOCUS_ANNOUNCE, "focus.announce", { { value = false, text = L.SET_FOCUS_QUIET },
			{ value = true, text = L.SET_FOCUS_LOUD } }, function(v)
			return v and L.SET_FOCUS_LOUD_DONE or L.SET_FOCUS_QUIET_DONE
		end),
		{ kind = "choice", label = L.SET_FOCUS_SCOPE, choices = { { value = false, text = L.SET_FOCUS_ACCOUNT },
			{ value = true, text = L.SET_FOCUS_CHARACTER } },
```

and replace it with:

```lua
			return v == "merge" and L.SET_FOCUS_MERGE_DONE or L.SET_FOCUS_PRIORITY_DONE
		end, L.SET_FOCUS_RESOLVE_TIP),
		setting(L.SET_FOCUS_PEEK, "focus.peek", { { value = "peek", text = L.SET_FOCUS_PEEK_PEEK },
			{ value = "keep", text = L.SET_FOCUS_PEEK_KEEP } }, function(v)
			return v == "peek" and L.SET_FOCUS_PEEK_DONE or L.SET_FOCUS_KEEP_DONE
		end, L.SET_FOCUS_PEEK_TIP),
		setting(L.SET_FOCUS_ANNOUNCE, "focus.announce", { { value = false, text = L.SET_FOCUS_QUIET },
			{ value = true, text = L.SET_FOCUS_LOUD } }, function(v)
			return v and L.SET_FOCUS_LOUD_DONE or L.SET_FOCUS_QUIET_DONE
		end, L.SET_FOCUS_ANNOUNCE_TIP),
		{ kind = "choice", label = L.SET_FOCUS_SCOPE, tip = L.SET_FOCUS_SCOPE_TIP,
			choices = { { value = false, text = L.SET_FOCUS_ACCOUNT },
			{ value = true, text = L.SET_FOCUS_CHARACTER } },
```

In `SwagBag/UI/SettingsFocus.lua` (edit 7 of 8), find:

```lua
		out[#out + 1] = { kind = "choice", label = layered(L.SET_MODE_LABEL:format(L[m.name])),
			choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
```

and replace it with:

```lua
		out[#out + 1] = { kind = "choice", label = layered(L.SET_MODE_LABEL:format(L[m.name])),
			tip = L.SET_MODE_TIP:format(whenText(m.id)),
			choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
```

In `SwagBag/UI/SettingsFocus.lua` (edit 8 of 8), find:

```lua
	end
	local pick = { kind = "choice", label = L.SET_EDIT_MODE, width = 76, choices = {}, get = function()
		return SF.editing
```

and replace it with:

```lua
	end
	local pick = { kind = "choice", label = L.SET_EDIT_MODE, width = 76, tip = L.SET_EDIT_MODE_TIP, choices = {}, get = function()
		return SF.editing
```

In `SwagBag/UI/SettingsWindow.lua` (edit 1 of 6), find:

```lua
--   { kind = "note", label }
-- Pages register with SW.AddPage{ id, title, rows = function() -> list }, in TOC order, and are
```

and replace it with:

```lua
--   { kind = "note", label }
-- Any row may carry tip: a plain-words explanation shown when the mouse rests on one of its buttons,
-- under the row's label; a choice or action may carry its own tip, shown after the row's (week 6).
-- A button is as wide as its text (plus TEXT_PAD), never narrower than the row's width (or
-- BUTTON); a button that no longer fits the line starts the next one, and the rows below move down.
-- Pages register with SW.AddPage{ id, title, rows = function() -> list }, in TOC order, and are
```

In `SwagBag/UI/SettingsWindow.lua` (edit 2 of 6), find:

```lua
local SW = { pages = {}, byId = {}, current = nil, labels = {}, buttons = {}, used = { labels = 0, buttons = 0 },
	selected = {}, WIDTH = 640, HEIGHT = 470, NAV = 140, BUTTON = 120, ROW = 20, GAP = 8 }
SB.SettingsWindow = SW
```

and replace it with:

```lua
local SW = { pages = {}, byId = {}, current = nil, labels = {}, buttons = {}, used = { labels = 0, buttons = 0 },
	selected = {}, tips = {}, WIDTH = 640, HEIGHT = 470, NAV = 140, BUTTON = 120, ROW = 20, GAP = 8, LINE_GAP = 4, TEXT_PAD = 24 }
SB.SettingsWindow = SW
```

In `SwagBag/UI/SettingsWindow.lua` (edit 3 of 6), find:

```lua
end

-- Run fn (a click) inside ErrorTrap; its return value is the feedback. Then redraw the page.
```

and replace it with:

```lua
end

-- The tooltip of a row's button (week 6): the row's label, its tip, then the button's own tip.
-- SW.tips[button] = { title, text, extra } for the buttons of the page as drawn.
function SW.ShowTip(b)
	local tip = SW.tips[b]
	if not (GameTooltip and tip and (tip.text or tip.extra)) then
		return
	end
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:SetText(tip.title or "")
	if tip.text then
		GameTooltip:AddLine(tip.text, 1, 1, 1, true)
	end
	if tip.extra then
		GameTooltip:AddLine(tip.extra, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- Run fn (a click) inside ErrorTrap; its return value is the feedback. Then redraw the page.
```

In `SwagBag/UI/SettingsWindow.lua` (edit 4 of 6), find:

```lua
		end, "none"))
		if SB.Theme then
```

and replace it with:

```lua
		end, "none"))
		b:SetScript("OnEnter", Guard("settings.tip", function(self)
			SW.ShowTip(self)
		end, "none"))
		b:SetScript("OnLeave", Guard("settings.tipHide", function(self)
			if GameTooltip and (not GameTooltip.IsOwned or GameTooltip:IsOwned(self)) then
				GameTooltip:Hide()
			end
		end, "none"))
		if SB.Theme then
```

In `SwagBag/UI/SettingsWindow.lua` (edit 5 of 6), find:

```lua
	end
	b.onClick, b.onDrop = nil, nil
	b:Show()
	return b
end
```

and replace it with:

```lua
	end
	b.onClick, b.onDrop, SW.tips[b] = nil, nil, nil
	b:Show()
	return b
end

-- The full width of a button's text (0 when the client cannot say).
local function textWidth(b)
	local w = b.GetTextWidth and b:GetTextWidth()
	return type(w) == "number" and w or 0
end
```

In `SwagBag/UI/SettingsWindow.lua` (edit 6 of 6), find:

```lua
			local current = row.get and row.get()
			local x = 12
			for _, item in ipairs(items) do
				local b = button()
				b:SetText(item.text)
				b:SetWidth(item.width or row.width or SW.BUTTON)
				place(b, x, y)
				x = x + (item.width or row.width or SW.BUTTON) + 4
				if row.kind == "choice" then
```

and replace it with:

```lua
			local current = row.get and row.get()
			local x, room = 12, (child:GetWidth() or SW.WIDTH) - 4
			for _, item in ipairs(items) do
				local b = button()
				b:SetText(item.text)
				-- as wide as its text, never narrower than the row's width; out of room: the next line
				local w = math.min(room - 12, math.max(item.width or row.width or SW.BUTTON, textWidth(b) + SW.TEXT_PAD))
				if x > 12 and x + w > room then
					x, y = 12, y - SW.ROW - SW.LINE_GAP
				end
				b:SetWidth(w)
				place(b, x, y)
				x = x + w + 4
				if row.tip or item.tip then
					SW.tips[b] = { title = row.label, text = row.tip, extra = item.tip }
				end
				if row.kind == "choice" then
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1268 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1268 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/UI/SettingsWindow.lua SwagBag/UI/SettingsFocus.lua SwagBag/UI/BagsWindow.lua SwagBag/UI/QuickSetup.lua \
  SwagBag/Locale/enUS.lua spec/settings_spec.lua spec/settings_focus_spec.lua spec/bagswindow_sections_spec.lua \
  spec/quicksetup_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 8: plain-words tips on settings rows, Focus modes intro, clearer Pause tooltip and quick setup line; choice buttons fit their text and wrap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
### Task 9: The bank layout reads each slot once and reports its parts; repeated stacks written once in snapshots; the footer's gold coin

From the user's in-game testing of 0.5.0 (fixes 5 and 6).
- **Bank open 72–86 ms (spec 9 budget: 80 ms) and a 40 KB snapshot for one character (aim: about 30 KB).** Reading the code found one hot spot that can be removed with no change in behaviour. The bank's `describe` (`UI/BankWindow.lua`) read every slot twice: `Adapter.GetSlot` for the paint, then `Items.Describe`, which calls `Adapter.GetSlot` again. That is two client `GetContainerItemInfo` calls per slot, 2,156 for a full 1,078-slot bank. `Items.Describe(bag, slot, s)` now takes the slot the caller already read. On the 1,078-slot fixture (`spec/fixtures/big.lua`) a bank layout makes 1,078 slot reads instead of 2,156 (counted while writing this plan). The rest of the open time cannot be split by reading the code: on the mock, every client call costs about the same. So `GroupView` now records where a full layout's time goes (tabs and their buttons, reading the slots, categories, positions, drawing), and `/swagbag report` prints it under `Last bank layout`. Session TF1 brings those numbers back, and the next step is chosen from them (D20). For snapshots, a link that an earlier slot of the same container already holds is written `slot:=thatSlot;count` instead of the full link again. A bank tab with 10 stacks each of two herbs drops from 1,591 to 358 bytes. The report splits the snapshot size into bags, banks, warband and guild banks. Every older snapshot still reads exactly as before, and the schema stays 2 (D21). The 30 KB aim is not promised: it depends on how many repeated stacks the user's banks hold, which the new report line shows.
- **FT1, O1: the footer's gold.** It showed `GetMoneyString`'s small inline coins. The gold entry now shows a gold coin as big as the currency and crest icons (`F.ICON`, the same widget), followed by the whole gold pieces with thousands separators (`1,234,567`). Silver and copper move into the tooltip (`Gold on this character`, then `Adapter.MoneyText` of the full amount). The coin is the texture file `Interface\MoneyFrame\UI-GoldIcon`, a plain path, so it does not go through the Adapter (D22).

**Files:**
- Modify: `SwagBag/Engine/Items.lua` (`Items.Describe(bag, slot, s)`)
- Modify: `SwagBag/UI/BankWindow.lua` (`describe`, the count-only repaint)
- Modify: `SwagBag/UI/GroupView.lua` (header, `build` timing, new `positionTimed`, `commit` records `stats.phases`, `v.Layout`, `v.RequestLayout`)
- Modify: `SwagBag/Engine/Snapshots.lua` (format comment, `Serialize`, `Deserialize`, new `Snap.BytesByKind`)
- Modify: `SwagBag/Core/Report.lua` (`Bank layout parts` and `Snapshot sizes` lines)
- Modify: `SwagBag/UI/Footer.lua` (header, `F.GOLD_ICON`, new `F.GoldText`, the gold item, the money tooltip)
- Modify: `SwagBag/Locale/enUS.lua` (`REPORT_BANK_PHASES`, `REPORT_SNAPSHOT_KINDS`)
- Test: `spec/bankwindow_groups_spec.lua` (two new), `spec/report_spec.lua` (two tests extended), `spec/snapshots_spec.lua` (three new), `spec/footer_spec.lua` (six `123g` expectations in five tests become `123`, one new)

**Interfaces:**
- Consumes: `SB.Adapter.GetSlot/ProfileMs/MoneyText`, `Snap.DB`, the local `snapshotBytes`.
- Produces:
  - `Items.Describe(bag, slot, s?)`, where `s` is a `GetSlot` result and `false` means read as empty;
  - `v.stats.phases = { groups, read, categories, positions, drawing }` (ms) on every `GroupView`;
  - `Snap.BytesByKind() -> { bags, bank, warband, guild }` (bytes) and the `=slot` line form;
  - `F.GOLD_ICON`, `F.GoldText(copper) -> text`, and the gold item's tip `{ kind = "money", copper }`.

- [ ] **Step 1: Write the failing tests**

In `spec/bankwindow_groups_spec.lua`, find:

```lua
	end)

	it("the first visit to a full bank (1,078 slots) is laid out within 80 ms (spec 9)", function()
```

and replace it with:

```lua
	end)

	-- Week 6, D20. Mutation: describe reads the slot again for the record (Items.Describe(bag, slot)).
	it("a bank layout reads each slot once, for the button and the record", function()
		openBank()
		local get, reads = A.GetSlot, {}
		A.GetSlot = function(bag, slot)
			local k = bag * 1000 + slot
			reads[k] = (reads[k] or 0) + 1
			return get(bag, slot)
		end
		BW.Layout("reflow")
		local n = 0
		for k, times in pairs(reads) do
			n = n + 1
			assert.equal(1, times, "slot " .. k)
		end
		assert.equal(16, n, "both groups' 8 slots")
		assert.equal(5, BW.view.Record(6, 1).count, "the record still has the item")
	end)

	-- Week 6, D20: /swagbag report shows where the bank layout's time goes. Mutation: drop
	-- `v.stats.phases = b.ms` in GroupView's commit.
	it("a bank layout records its parts: tabs, reading, categories, positions, drawing", function()
		local ms = 0
		A.ProfileMs = function()
			ms = ms + 1 -- every reading of the clock is 1 ms later
			return ms
		end
		openBank()
		local p = BW.view.stats.phases
		local sum = 0
		for _, part in ipairs({ "groups", "read", "categories", "positions", "drawing" }) do
			assert.truthy(type(p[part]) == "number" and p[part] > 0, part)
			sum = sum + p[part]
		end
		assert.truthy(sum <= BW.view.stats.lastLayoutMs, "the parts fit inside the whole")
	end)

	it("the first visit to a full bank (1,078 slots) is laid out within 80 ms (spec 9)", function()
```

In `spec/footer_spec.lua` (edit 1 of 5), find:

```lua
		F.Refresh()
		assert.same({ "123g", "500", "45", "AKCE +12", "10 free" }, texts())
		assert.equal(1, resized, "the window fits the new footer")
```

and replace it with:

```lua
		F.Refresh()
		assert.same({ "123", "500", "45", "AKCE +12", "10 free" }, texts(), "gold: the whole gold pieces (week 6)")
		assert.equal(1, resized, "the window fits the new footer")
```

In `spec/footer_spec.lua` (edit 2 of 5), find:

```lua
		F.Refresh()
		assert.same({ "123g", "500", "900", "AKCE +12", "10 free" }, texts())
	end)
```

and replace it with:

```lua
		F.Refresh()
		assert.same({ "123", "500", "900", "AKCE +12", "10 free" }, texts())
	end)
```

In `spec/footer_spec.lua` (edit 3 of 5), find:

```lua
		assert.equal("gold,currencies,-crests,free,keystone", SB.Config.Get("bags.footer.entries"))
		assert.same({ "123g", "500", "10 free", "AKCE +12" }, texts())
	end)
```

and replace it with:

```lua
		assert.equal("gold,currencies,-crests,free,keystone", SB.Config.Get("bags.footer.entries"))
		assert.same({ "123", "500", "10 free", "AKCE +12" }, texts())
	end)
```

In `spec/footer_spec.lua` (edit 4 of 5), find:

```lua
		F.Refresh()
		assert.same({ "123g", "500", "45", "AKCE +12", "10 free" }, texts())
		assert.equal("currencies", F.items[3].entry)
```

and replace it with:

```lua
		F.Refresh()
		assert.same({ "123", "500", "45", "AKCE +12", "10 free" }, texts())
		assert.equal("currencies", F.items[3].entry)
```

In `spec/footer_spec.lua` (edit 5 of 5), find:

```lua
		F.Refresh()
		assert.equal("123g", texts()[1])
		A.money = nil
		F.Refresh()
		assert.equal("123g", texts()[1], "the last known amount")
	end)
```

and replace it with:

```lua
		F.Refresh()
		assert.equal("123", texts()[1])
		A.money = nil
		F.Refresh()
		assert.equal("123", texts()[1], "the last known amount")
	end)

	-- Week 6, D22 (FT1, O1: the gold needs a proper coin). Mutations: add the gold entry with no
	-- icon; in GoldText, drop the separator loop; the money tooltip shows item.text (gold only).
	it("gold: a full-size coin, the whole gold with thousands separators; silver and copper in its tooltip", function()
		A.money = 12345678901 -- 1,234,567 gold 89 silver 1 copper
		local asked
		A.MoneyText = function(copper)
			asked = copper
			return "1,234,567g 89s 1c"
		end
		F.Refresh()
		assert.equal("1,234,567", F.items[1].text)
		assert.equal(F.GOLD_ICON, F.items[1].icon)
		assert.truthy(F.widgets[1].icon.shown)
		assert.equal(F.widgets[2].icon.w, F.widgets[1].icon.w, "the coin is as big as the currency icons")
		Fake.Fire(F.widgets[1], "OnEnter")
		assert.equal(SB.L.FOOTER_GOLD, GameTooltip.text)
		assert.same({ "1,234,567g 89s 1c", 1, 1, 1 }, GameTooltip.calls.AddLine)
		assert.equal(12345678901, asked, "the full amount, silver and copper too")
		assert.same({ "0", "0", "1", "999", "1,000", "10,000,000" }, { F.GoldText(0), F.GoldText(9999), F.GoldText(10000),
			F.GoldText(9990000), F.GoldText(10000000), F.GoldText(100000000000) })
	end)
```

In `spec/report_spec.lua` (edit 1 of 2), find:

```lua
		assert.truthy(SB.Report.Build():find("\nLast bank layout: 61.3 ms (open)", 1, true), "spec 9: first bank open")
	end)
```

and replace it with:

```lua
		assert.truthy(SB.Report.Build():find("\nLast bank layout: 61.3 ms (open)", 1, true), "spec 9: first bank open")
		-- Week 6, D20. Mutation: drop the REPORT_BANK_PHASES line.
		SB.BankWindow.view.stats.phases = { groups = 0.5, read = 40.04, categories = 12.3, positions = 6.1, drawing = 2 }
		assert.truthy(SB.Report.Build():find("\nBank layout parts: tabs 0.5 ms, reading 40.0 ms, categories 12.3 ms,"
			.. " positions 6.1 ms, drawing 2.0 ms", 1, true))
	end)
```

In `spec/report_spec.lua` (edit 2 of 2), find:

```lua
		assert.truthy(SB.Report.Build():find("\nSnapshots: 3 characters, 1 guilds, 40 KB", 1, true))
	end)
```

and replace it with:

```lua
		assert.truthy(SB.Report.Build():find("\nSnapshots: 3 characters, 1 guilds, 40 KB", 1, true))
		-- Week 6, D21. Mutation: drop the REPORT_SNAPSHOT_KINDS line.
		SB.Snapshots.BytesByKind = function() return { bags = 9216, bank = 20480, warband = 10240, guild = 512 } end
		assert.truthy(SB.Report.Build():find("\nSnapshot sizes: bags 9.0 KB, banks 20.0 KB, warband 10.0 KB,"
			.. " guild banks 0.5 KB", 1, true))
	end)
```

In `spec/snapshots_spec.lua`, find:

```lua
		assert.same({ size = 4, s = "1:item:1;5\n3:" .. PET .. ";1\n" }, c)
	end)
```

and replace it with:

```lua
		assert.same({ size = 4, s = "1:item:1;5\n3:" .. PET .. ";1\n" }, c)
	end)

	-- Week 6, D21. Mutation: in Serialize, always write the link (no "=slot" for a repeat).
	it("a link repeated in one container is written once; later slots point back to it", function()
		local herb = "|cffffffff|Hitem:210796::::::::80:253::::1:28:2462:::::|h[Mycobloom]|h|r"
		local slots = { [1] = { link = herb, count = 200 }, [2] = { link = PET, count = 1 }, [4] = { link = herb, count = 200 },
			[7] = { link = herb, count = 13 } }
		local c = Snap.Serialize(slots, 8)
		assert.equal("1:" .. herb .. ";200\n2:" .. PET .. ";1\n4:=1;200\n7:=1;13\n", c.s)
		assert.same(slots, Snap.Deserialize(c))
		local plain = 0
		for _, s in pairs(slots) do
			plain = plain + #s.link
		end
		assert.truthy(#c.s < plain, "smaller than writing every link out")
		assert.same({ [2] = { link = PET, count = 1 } }, Snap.Deserialize({ s = "3:=9;5\n2:" .. PET .. ";1\n" }),
			"a pointer to a slot with no link is skipped")
	end)

	-- Week 6, D21: the schema stays 2 and old snapshots read as before. Mutation: Deserialize reads
	-- only "=slot" lines' links (drops the plain-link branch).
	it("a snapshot written by 0.5.0 (every link written out) reads exactly as before", function()
		local old = { size = 4, s = "1:" .. KEY .. ";1\n2:item:1;5\n3:item:1;5\n" }
		assert.same({ [1] = { link = KEY, count = 1 }, [2] = { link = "item:1", count = 5 }, [3] = { link = "item:1", count = 5 } },
			Snap.Deserialize(old))
	end)

	-- Week 6, D21. Mutation: BytesByKind adds the bank snapshots into bags.
	it("BytesByKind splits the saved size into bags, banks, warband and guild banks", function()
		SB.Inventory.ScanAll()
		bankVisit()
		A.Advance(0.3)
		Snap.SaveGuild("Tidewatch-Argent Dawn", { [2] = { name = "Gear", slots = { [5] = { link = "item:1", count = 1 } } } })
		SB.eventFrame:Fire("PLAYER_LOGOUT")
		local k = Snap.BytesByKind()
		assert.truthy(k.bags > 0 and k.bank > 0 and k.warband > 0 and k.guild > 0)
		assert.equal(Snap.Bytes(), k.bags + k.bank + k.warband + k.guild)
	end)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `luajit spec/runner.lua spec/*_spec.lua`

Expected: the last line is `1262 passed, 12 failed`, and the failures are exactly:
```text
FAIL spec/bankwindow_groups_spec.lua :: BankWindow contents > a bank layout reads each slot once, for the button and the record
FAIL spec/bankwindow_groups_spec.lua :: BankWindow contents > a bank layout records its parts: tabs, reading, categories, positions, drawing
FAIL spec/footer_spec.lua :: Footer (ruling W4-14) > default: every entry on, in the order gold, currencies, crests, keystone, free; only owned crests
FAIL spec/footer_spec.lua :: Footer (ruling W4-14) > crests come from the season's confirmed currency IDs when Engine/Crests.lua has them
FAIL spec/footer_spec.lua :: Footer (ruling W4-14) > /swagbag footer lists the entries, switches and moves one, and answers each time
FAIL spec/footer_spec.lua :: Footer (ruling W4-14) > a crest ticked 'Show on backpack' shows once, under currencies; crests adds nothing
FAIL spec/footer_spec.lua :: Footer (ruling W4-14) > gold the client will not tell (secret or missing) shows the last known amount, never a false 0
FAIL spec/footer_spec.lua :: Footer (ruling W4-14) > gold: a full-size coin, the whole gold with thousands separators; silver and copper in its tooltip
FAIL spec/report_spec.lua :: Report > shows the bank setting, the last visit and the deposit target (check V2)
FAIL spec/report_spec.lua :: Report > shows the snapshot counts and size, for the spec 8.4 budgets (check V10)
FAIL spec/snapshots_spec.lua :: Snapshots (spec 8.3 format, 5.7 timing, 8.4 budget) > a link repeated in one container is written once; later slots point back to it
FAIL spec/snapshots_spec.lua :: Snapshots (spec 8.3 format, 5.7 timing, 8.4 budget) > BytesByKind splits the saved size into bags, banks, warband and guild banks
```
"a snapshot written by 0.5.0 (every link written out) reads exactly as before" passes at Step 2 because it pins what the reader does today, and must keep doing after Step 3.

Critical tests and the mutation each must catch (applied to the finished Task 9 code):
- "a bank layout reads each slot once …": in `describe`, `local record = SB.Items.Describe(bag, slot)` (reads again).
- "a bank layout records its parts …": in `commit`, delete `v.stats.phases = b.ms`.
- "shows the bank setting, the last visit …": delete the `REPORT_BANK_PHASES` line in `Report.Build`.
- "shows the snapshot counts and size …": delete the `REPORT_SNAPSHOT_KINDS` line.
- "a link repeated in one container is written once …": in `Serialize`, write `s.link` instead of `(ref and ("=" .. ref) or s.link)`.
- "a snapshot written by 0.5.0 …": in `Deserialize`, replace `if slot and link then` with `if slot and ref then`.
- "BytesByKind splits …": `out.bags = out.bags + snapshotBytes(c.bank)` in place of the bank line.
- "gold: a full-size coin …": add the gold item with `nil` for its icon; separately, in `F.GoldText`, replace the `gsub` line with `grouped = 0`; separately, the money tooltip adds `item.text` instead of `SB.Adapter.MoneyText(tip.copper)`.

- [ ] **Step 3: Write the implementation**

In `SwagBag/Core/Report.lua` (edit 1 of 2), find:

```lua
			lines[#lines + 1] = L.REPORT_BANK_LAYOUT:format(bankStats.lastLayoutMs, tostring(bankStats.lastLayoutReason))
		end
```

and replace it with:

```lua
			lines[#lines + 1] = L.REPORT_BANK_LAYOUT:format(bankStats.lastLayoutMs, tostring(bankStats.lastLayoutReason))
			local p = bankStats.phases
			if p then -- week 6 (D20): where the bank layout's time goes
				lines[#lines + 1] = L.REPORT_BANK_PHASES:format(p.groups, p.read, p.categories, p.positions, p.drawing)
			end
		end
```

In `SwagBag/Core/Report.lua` (edit 2 of 2), find:

```lua
		lines[#lines + 1] = L.REPORT_SNAPSHOTS:format(chars, guilds, math.floor(SB.Snapshots.Bytes() / 1024 + 0.5))
	end
```

and replace it with:

```lua
		lines[#lines + 1] = L.REPORT_SNAPSHOTS:format(chars, guilds, math.floor(SB.Snapshots.Bytes() / 1024 + 0.5))
		if SB.Snapshots.BytesByKind then -- week 6 (D21): where the snapshot bytes are
			local k = SB.Snapshots.BytesByKind()
			lines[#lines + 1] = L.REPORT_SNAPSHOT_KINDS:format(k.bags / 1024, k.bank / 1024, k.warband / 1024, k.guild / 1024)
		end
	end
```

In `SwagBag/Engine/Items.lua` (edit 1 of 2), find:

```lua
--
-- Items.Describe(bag, slot) -> record, or nil + "empty"
-- record = {
```

and replace it with:

```lua
--
-- Items.Describe(bag, slot[, s]) -> record, or nil + "empty". s: the slot as the caller already read
--   it with Adapter.GetSlot (false: read as empty), so the slot is not read twice (week 6, D20)
-- record = {
```

In `SwagBag/Engine/Items.lua` (edit 2 of 2), find:

```lua
SB.Items = Items

function Items.Describe(bag, slot)
	local A = SB.Adapter
	local s = A.GetSlot(bag, slot)
	if not s then
```

and replace it with:

```lua
SB.Items = Items

function Items.Describe(bag, slot, s)
	local A = SB.Adapter
	if s == nil then
		s = A.GetSlot(bag, slot)
	end
	if not s then
```

In `SwagBag/Engine/Snapshots.lua` (edit 1 of 5), find:

```lua
-- one string per container of "slot:link;count\n" lines in slot order, full links verbatim
-- (caged pets, keystones and bonus IDs round-trip), no derived values.
-- Where they live (spec 8.2): SwagBagDB.chars["Name-Realm"] = { class, level, lastSeen, guild,
```

and replace it with:

```lua
-- one string per container of "slot:link;count\n" lines in slot order, full links verbatim
-- (caged pets, keystones and bonus IDs round-trip), no derived values. Week 6 (D21): a link that
-- an earlier slot of the same container already has is written "slot:=thatSlot;count" (a stack of
-- the same item written once); Deserialize reads both forms, so every older snapshot reads as before.
-- Where they live (spec 8.2): SwagBagDB.chars["Name-Realm"] = { class, level, lastSeen, guild,
```

In `SwagBag/Engine/Snapshots.lua` (edit 2 of 5), find:

```lua
function Snap.Serialize(slots, size)
	local parts = {}
	for slot = 1, size do
		local s = slots[slot]
		if s and s.link then
			parts[#parts + 1] = slot .. ":" .. s.link .. ";" .. (s.count or 1) .. "\n"
		end
```

and replace it with:

```lua
function Snap.Serialize(slots, size)
	local parts, first = {}, {}
	for slot = 1, size do
		local s = slots[slot]
		if s and s.link then
			local ref = first[s.link]
			if not ref then
				first[s.link] = slot
			end
			parts[#parts + 1] = slot .. ":" .. (ref and ("=" .. ref) or s.link) .. ";" .. (s.count or 1) .. "\n"
		end
```

In `SwagBag/Engine/Snapshots.lua` (edit 3 of 5), find:

```lua
end

-- The inverse: slots[slot] = { link, count }. A damaged line is skipped.
function Snap.Deserialize(container)
```

and replace it with:

```lua
end

-- The inverse: slots[slot] = { link, count }. A damaged line, or a "=slot" whose slot has no
-- link above it, is skipped.
function Snap.Deserialize(container)
```

In `SwagBag/Engine/Snapshots.lua` (edit 4 of 5), find:

```lua
		local slot, link, count = line:match("^(%d+):(.*);(%d+)$")
		if slot then
			slots[tonumber(slot)] = { link = link, count = tonumber(count) }
```

and replace it with:

```lua
		local slot, link, count = line:match("^(%d+):(.*);(%d+)$")
		local ref = link and link:match("^=(%d+)$")
		if ref then
			local earlier = slots[tonumber(ref)]
			link = earlier and earlier.link
		end
		if slot and link then
			slots[tonumber(slot)] = { link = link, count = tonumber(count) }
```

In `SwagBag/Engine/Snapshots.lua` (edit 5 of 5), find:

```lua
		end
	end
	return n
end

-- Approximate saved size of every snapshot (strings plus a small per-container overhead).
```

and replace it with:

```lua
		end
	end
	return n
end

-- The same, split by kind (week 6, D21: /swagbag report): { bags, bank, warband, guild } in bytes.
function Snap.BytesByKind()
	local db = Snap.DB()
	local out = { bags = 0, bank = 0, warband = snapshotBytes(db.warband), guild = 0 }
	for _, c in pairs(db.chars) do
		if type(c) == "table" then
			out.bags = out.bags + snapshotBytes(c.bags)
			out.bank = out.bank + snapshotBytes(c.bank)
		end
	end
	for _, g in pairs(db.guilds) do
		if type(g) == "table" then
			out.guild = out.guild + snapshotBytes(g.snapshot)
		end
	end
	return out
end

-- Approximate saved size of every snapshot (strings plus a small per-container overhead).
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 2), find:

```lua
L.BANK_VIEW_SECTIONS = "SwagBag bank - category view"
L.REPORT_BANK_LAYOUT = "Last bank layout: %.1f ms (%s)"

-- Guild bank window (spec F16)
```

and replace it with:

```lua
L.BANK_VIEW_SECTIONS = "SwagBag bank - category view"
L.REPORT_BANK_LAYOUT = "Last bank layout: %.1f ms (%s)"
L.REPORT_BANK_PHASES = "Bank layout parts: tabs %.1f ms, reading %.1f ms, categories %.1f ms, positions %.1f ms, drawing %.1f ms"

-- Guild bank window (spec F16)
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 2), find:

```lua
L.AGE_DAYS = "%d days ago"
L.REPORT_SNAPSHOTS = "Snapshots: %d characters, %d guilds, %d KB"

-- Prices (spec F10)
```

and replace it with:

```lua
L.AGE_DAYS = "%d days ago"
L.REPORT_SNAPSHOTS = "Snapshots: %d characters, %d guilds, %d KB"
L.REPORT_SNAPSHOT_KINDS = "Snapshot sizes: bags %.1f KB, banks %.1f KB, warband %.1f KB, guild banks %.1f KB"

-- Prices (spec F10)
```

In `SwagBag/UI/BankWindow.lua` (edit 1 of 2), find:

```lua
-- Paint the slot's button and return its item record (nil for an empty slot). A pending item
-- has no slot icon yet; placeholders still need one.
local function describe(bag, slot)
	local A, B = SB.Adapter, SB.Buttons
	local button = B.Get(bag, slot)
	if button then
		B.Paint(button, A.GetSlot(bag, slot))
	end
	local record = SB.Items.Describe(bag, slot)
	if record and not record.icon then
```

and replace it with:

```lua
-- Paint the slot's button and return its item record (nil for an empty slot). A pending item
-- has no slot icon yet; placeholders still need one. The slot is read once, for both (D20).
local function describe(bag, slot)
	local A, B = SB.Adapter, SB.Buttons
	local s = A.GetSlot(bag, slot)
	local button = B.Get(bag, slot)
	if button then
		B.Paint(button, s)
	end
	local record = SB.Items.Describe(bag, slot, s or false)
	if record and not record.icon then
```

In `SwagBag/UI/BankWindow.lua` (edit 2 of 2), find:

```lua
			if not Inv.Has(c.reasons, Inv.R.ITEM) then
				B.Paint(button, A.GetSlot(c.bag, c.slot))
				local fresh = SB.Items.Describe(c.bag, c.slot)
				if old and fresh and fresh.itemID == old.itemID then
```

and replace it with:

```lua
			if not Inv.Has(c.reasons, Inv.R.ITEM) then
				local s = A.GetSlot(c.bag, c.slot)
				B.Paint(button, s)
				local fresh = SB.Items.Describe(c.bag, c.slot, s or false)
				if old and fresh and fresh.itemID == old.itemID then
```

In `SwagBag/UI/Footer.lua` (edit 1 of 6), find:

```lua
-- in the user's order (setting bags.footer.entries; /swagbag footer; Settings > Footer):
--   gold        the character's gold
--   currencies  the currencies ticked "Show on backpack" in Blizzard's Currency tab
```

and replace it with:

```lua
-- in the user's order (setting bags.footer.entries; /swagbag footer; Settings > Footer):
--   gold        the character's gold: a gold coin as big as the currency icons and the whole gold
--               pieces, with thousands separators ("1,234,567"); silver and copper are in its tooltip
--               (week 6, D22)
--   currencies  the currencies ticked "Show on backpack" in Blizzard's Currency tab
```

In `SwagBag/UI/Footer.lua` (edit 2 of 6), find:

```lua
--   Footer.Items() -> { { entry, text, icon, tip } }  what to draw, in order (reads the game)
--   Footer.Flow(widths, maxWidth) -> places, rows      pure: places[i] = { x, row }
```

and replace it with:

```lua
--   Footer.Items() -> { { entry, text, icon, tip } }  what to draw, in order (reads the game)
--   Footer.GoldText(copper) -> text     pure: the whole gold pieces with thousands separators
--   Footer.Flow(widths, maxWidth) -> places, rows      pure: places[i] = { x, row }
```

In `SwagBag/UI/Footer.lua` (edit 3 of 6), find:

```lua
	height = 0, places = {}, widths = {}, dirty = true,
	ROW = 16, ROW_GAP = 2, GAP = 12, ICON = 14, PAD = 2, INSET = 4, DELAY = 0.1 }
SB.Footer = F
```

and replace it with:

```lua
	height = 0, places = {}, widths = {}, dirty = true,
	ROW = 16, ROW_GAP = 2, GAP = 12, ICON = 14, PAD = 2, INSET = 4, DELAY = 0.1,
	GOLD_ICON = "Interface\\MoneyFrame\\UI-GoldIcon" } -- the gold coin texture file (a plain path)
SB.Footer = F
```

In `SwagBag/UI/Footer.lua` (edit 4 of 6), find:

```lua
end

function F.Items()
```

and replace it with:

```lua
end

function F.GoldText(copper)
	local text = tostring(math.floor(copper / 10000))
	local grouped
	repeat
		text, grouped = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until grouped == 0
	return text
end

function F.Items()
```

In `SwagBag/UI/Footer.lua` (edit 5 of 6), find:

```lua
			if F.lastMoney then
				add("gold", A.MoneyText(F.lastMoney), nil, { kind = "money" })
			end
```

and replace it with:

```lua
			if F.lastMoney then
				add("gold", F.GoldText(F.lastMoney), F.GOLD_ICON, { kind = "money", copper = F.lastMoney })
			end
```

In `SwagBag/UI/Footer.lua` (edit 6 of 6), find:

```lua
		T:SetText(L.FOOTER_GOLD)
		T:AddLine(item.text, 1, 1, 1)
	else
```

and replace it with:

```lua
		T:SetText(L.FOOTER_GOLD)
		T:AddLine(SB.Adapter.MoneyText(tip.copper), 1, 1, 1) -- gold, silver and copper, with the client's coins
	else
```

In `SwagBag/UI/GroupView.lua` (edit 1 of 7), find:

```lua
--   v.Clear()                           window closed: hide the buttons, forget the layout
-- cfg = { key = "bank" | "guild", window = ErrorTrap window (default "bank"), child, scroll,
```

and replace it with:

```lua
--   v.Clear()                           window closed: hide the buttons, forget the layout
--   v.stats = { lastLayoutMs, lastLayoutReason, phases = { groups, read, categories, positions,
--     drawing } }   the last full layout's time, and where it went (ms; week 6, D20: /swagbag report)
-- cfg = { key = "bank" | "guild", window = ErrorTrap window (default "bank"), child, scroll,
```

In `SwagBag/UI/GroupView.lua` (edit 2 of 7), find:

```lua
	-- Read every slot into a fresh candidate (groups, records, sizes); nothing is drawn.
	local function build()
		local b = { groups = {}, byId = {}, records = {}, sizes = {}, groupOf = {} }
		local sections = cfg.view() ~= "grid"
		local order = sections and SB.Categories.SectionOrder() or nil
		for _, def in ipairs(cfg.groups()) do
			local g = { id = def.id, bags = def.bags }
			local slots = {}
			for _, bag in ipairs(def.bags) do
```

and replace it with:

```lua
	-- Read every slot into a fresh candidate (groups, records, sizes); nothing is drawn.
	-- b.ms: where the time went (the groups and their buttons, reading the slots, the categories).
	local function build()
		local A = SB.Adapter
		local b = { groups = {}, byId = {}, records = {}, sizes = {}, groupOf = {},
			ms = { groups = 0, read = 0, categories = 0, positions = 0, drawing = 0 } }
		local sections = cfg.view() ~= "grid"
		local order = sections and SB.Categories.SectionOrder() or nil
		local t = A.ProfileMs()
		local defs = cfg.groups()
		b.ms.groups = A.ProfileMs() - t
		for _, def in ipairs(defs) do
			local g = { id = def.id, bags = def.bags }
			local slots = {}
			t = A.ProfileMs()
			for _, bag in ipairs(def.bags) do
```

In `SwagBag/UI/GroupView.lua` (edit 3 of 7), find:

```lua
			end
			if sections then
				g.state = SB.Layout.Build(slots, SB.Categorizer.Assign, order, { columns = cfg.columns(),
					newRows = cfg.newRows(), freeTile = cfg.freeTile and cfg.freeTile() or nil,
					family = SB.Adapter.BagFamily, hideEmptyNew = cfg.hideEmptyNew })
			end
```

and replace it with:

```lua
			end
			b.ms.read = b.ms.read + A.ProfileMs() - t
			if sections then
				t = A.ProfileMs()
				g.state = SB.Layout.Build(slots, SB.Categorizer.Assign, order, { columns = cfg.columns(),
					newRows = cfg.newRows(), freeTile = cfg.freeTile and cfg.freeTile() or nil,
					family = SB.Adapter.BagFamily, hideEmptyNew = cfg.hideEmptyNew })
				b.ms.categories = b.ms.categories + A.ProfileMs() - t
			end
```

In `SwagBag/UI/GroupView.lua` (edit 4 of 7), find:

```lua
	end

	-- Make a candidate the view's layout and draw it at pos.
	local function commit(b, pos, reason, t0)
		local old = v.pos
```

and replace it with:

```lua
	end

	-- A candidate's positions, timed (b.ms.positions).
	local function positionTimed(b)
		local t = SB.Adapter.ProfileMs()
		local pos = positionAll(b.groups, b.records)
		b.ms.positions = SB.Adapter.ProfileMs() - t
		return pos
	end

	-- Make a candidate the view's layout and draw it at pos.
	local function commit(b, pos, reason, t0)
		local t1 = SB.Adapter.ProfileMs()
		local old = v.pos
```

In `SwagBag/UI/GroupView.lua` (edit 5 of 7), find:

```lua
		cfg.onResize(pos.width, pos.height, reason ~= "open")
		v.stats.lastLayoutMs = SB.Adapter.ProfileMs() - t0
		v.stats.lastLayoutReason = reason
		return pos.width, pos.height
```

and replace it with:

```lua
		cfg.onResize(pos.width, pos.height, reason ~= "open")
		local now = SB.Adapter.ProfileMs()
		v.stats.lastLayoutMs = now - t0
		v.stats.lastLayoutReason = reason
		b.ms.drawing = now - t1
		v.stats.phases = b.ms
		return pos.width, pos.height
```

In `SwagBag/UI/GroupView.lua` (edit 6 of 7), find:

```lua
		local b = build()
		return commit(b, positionAll(b.groups, b.records), reason, t0)
	end
```

and replace it with:

```lua
		local b = build()
		return commit(b, positionTimed(b), reason, t0)
	end
```

In `SwagBag/UI/GroupView.lua` (edit 7 of 7), find:

```lua
			b = build()
			pos = positionAll(b.groups, b.records)
			v.heldKey = nil
```

and replace it with:

```lua
			b = build()
			pos = positionTimed(b)
			v.heldKey = nil
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `luajit spec/runner.lua spec/*_spec.lua`
Expected: `1274 passed, 0 failed`

- [ ] **Step 5: Run the full checks**

Run: `bash scripts/check.sh`
Expected: `TOC OK (62 files)`, `1274 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Items.lua SwagBag/UI/BankWindow.lua SwagBag/UI/GroupView.lua SwagBag/Engine/Snapshots.lua \
  SwagBag/Core/Report.lua SwagBag/UI/Footer.lua SwagBag/Locale/enUS.lua \
  spec/bankwindow_groups_spec.lua spec/report_spec.lua spec/snapshots_spec.lua spec/footer_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 6 Task 9: bank layout reads each slot once and reports its parts, repeated stacks written once in snapshots, footer gold coin

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---
## In-game sessions

Four short sessions: FS1, OV1, DP1 and TF1. All four run on the final merged build (every task done, reviewed and fixed), not on the build at the task each one is written for; the "after Task N" in each heading only says which task's work it checks. Then the week-6 exit check. They never block the build: findings come back as fixes.

Before every session:
- Claude installs the build first. The game currently runs an older copy, and the login line must say `v0.6.0`.
- If anything shows a red error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After the session, reply "<session> done" and the numbers of any steps that didn't match.

Chat lines start with `SwagBag: `. The bags' title shows the average item level after the mode name (for example `SwagBag — AH/Vendor/Bank — ilvl 279.4`), so the steps say what the title **starts with**.

### Session FS1: modes move their sections to the top (checks Task 3; runs on the final merged build, about 10 minutes)

You need: a vendor; something in your bags that goes to Junk, Trade Goods or BoE gear (one of them is enough). Step 25 waits for your next Mythic+ key.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.6.0 loaded. Type /swagbag help for commands.`
3. Press **B**. Expected: the bags open in the category view, with your sections in their usual order.
4. Click the `Junk` header. (If you carry no junk, click any other header except `New` and read that name for `Junk` until step 12.) Expected: it collapses to `+ Junk (…)`.
5. Move the mouse off the bags.
6. Right-click a vendor. Expected:
   - the vendor window opens;
   - the bags' title starts with `SwagBag — AH/Vendor/Bank`;
   - right under `New` (or at the very top, when New is hidden) come `Junk`, `Trade Goods` and `BoE gear`, the ones you carry, in that order;
   - `Junk` is still collapsed (`+ Junk`);
   - every other section is open or collapsed exactly as you left it. Nothing else collapsed.
7. Move the mouse onto any item in your bags and leave it there.
8. Keep the mouse still and walk away from the vendor with the **S** key until the vendor window closes. Expected: the title starts with `SwagBag — ilvl` again, and **no section moves** while the mouse stays on the item.
9. Move the mouse off the bags, to an empty part of the screen. Expected: within half a second the sections go back to your usual order. `Junk` is still collapsed.
10. Click the `+ Junk` header. Expected: Junk opens. It is your own choice, kept as you set it.
11. Move the mouse off the bags.
12. Type `/swagbag mode style`. Expected: `SwagBag: Focus style: front (a mode moves its sections to the top). Type /swagbag mode style front or /swagbag mode style collapse.`
13. Type `/swagbag mode style collapse`. Expected: `SwagBag: Focus modes now collapse every section the mode does not need. A click on a collapsed one opens it.`
14. Right-click the vendor. Expected: `Junk`, `Trade Goods` and `BoE gear` are open in their usual places, and every other section is collapsed (the week-4 way).
15. Walk away from the vendor with the **S** key until its window closes, with the mouse **not** over the bags. Expected: the sections open again as you had set them.
16. Type `/swagbag settings focus`. Expected: the settings window opens at `Focus modes`. It starts with a short paragraph (`Focus modes notice what you are doing...`), then a row `Focus modes` with `Switch by themselves` highlighted, then the row under it, `While a mode is on`, with `Move to the top` and `Collapse the rest`; `Collapse the rest` is highlighted.
17. Click `Move to the top`. Expected: the status line at the bottom reads `Focus modes now move their sections to the top and leave every section open or collapsed as you set it.`
18. Rest the mouse on `Move to the top`. Expected: a tooltip `While a mode is on`, then `Move to the top: the mode's sections come first, right under New. The mode collapses nothing; sections you collapsed yourself stay collapsed. Collapse the rest: only the mode's sections stay open (New always does); every other section collapses until the mode ends.`
19. Close the settings window with its X.
20. Type `/swagbag view list`. Expected: `SwagBag: SwagBag - list view`, and the bags show rows.
21. Right-click the vendor. Expected: in the list too, `Junk`, `Trade Goods` and `BoE gear` move right under New, and nothing collapses.
22. Walk away from the vendor with the **S** key until its window closes, with the mouse not over the bags. Expected: the usual order again.
23. Type `/swagbag view sections`. Expected: `SwagBag: SwagBag - category view`.
24. Type `/swagbag report`. Expected: the report box shows a line that starts `Focus: no mode (merge, front);` and contains `collapsing no`. Close the box.
25. Before your next Mythic+ key, press **B** and click the `Consumables` header yourself. Expected: it collapses to `+ Consumables (…)`. Move the mouse off the bags. When the key starts, press **B** once. Expected: `Consumables`, `Keystone & Crests` and `Gear` come right under New, in that order. `Consumables` is **still collapsed** (`+ Consumables`), because you collapsed it yourself, and nothing else is collapsed that you had open. (The same check works with the vendor, as in steps 4 to 6: your collapsed `Junk` moved up and stayed collapsed.) Tell Claude "FS1 step 25 ok" (or what you saw) with the session reply, or later.

### Session OV1: a cleaner item, and Warbound until equipped (checks Task 4; runs on the final merged build, about 5 minutes)

You need: a BoE or warbound-until-equipped gear item, if you have one; gear with an upgrade track (like `H1/8`).

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.6.0 loaded. Type /swagbag help for commands.`
3. Press **B**. Expected:
   - no `BoE` or `WuE` text on the left side of any item;
   - item levels are still top left and tracks (like `H1/8`) bottom left, the same size as before.
4. Look at your sections (no click). Expected: if you carry warbound-until-equipped gear, it sits in a section `Warbound until equipped` right below `BoE gear` (or where BoE gear would be). If you have none, the section is not shown, which is right.
5. Type `/swagbag overlays bind on`. Expected: `SwagBag: Overlay bind is now on.`, and `BoE` / `WuE` appear on those items again.
6. Type `/swagbag overlays bind off`. Expected: `SwagBag: Overlay bind is now off.`, and the badges are gone.
7. Click the bags' search box and type `wue`. Expected: only warbound-until-equipped items stay bright; everything else dims.
8. Press **Esc** once to leave the search box, then clear the box with its small x. Expected: everything is bright again.

### Session DP1: Deposit warbound, and the bank's free tile (checks Task 6; runs on the final merged build, about 10 minutes)

You need: a banker; at least one warbound item in your bags (its tooltip says `Warbound` or `Warbound until equipped`); a stack of an ordinary item (a trade good) for step 12.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.6.0 loaded. Type /swagbag help for commands.`
3. Right-click a banker. Expected:
   - the SwagBag bank opens;
   - on the right under the search box: a small tick box, the words `With reagents`, and a button `Deposit warbound`;
   - on the left of that row: `Deposits go to Character bank - switch with the tabs below` (or `Warband bank`).
4. Look at `Free` in the `Character bank` group (no click). Expected: **one** empty slot with a number in it, the free slots of all your character bank tabs together. No other empty slots show there.
5. Look at `Free` in the `Warband bank` group (no click). Expected: one empty slot with a number in it.
6. Click `Blizzard bank`. Expected: Blizzard's bank shows beside SwagBag's, and the title flashes `Blizzard's bank is shown for this visit`.
7. Click Blizzard's `Warband Bank` tab (bottom of Blizzard's window). Expected: Blizzard's window shows a `Deposit All Warbound Items` button and an `Include Reagents` box. Tell Claude if either has a different name.
8. Look at SwagBag's `With reagents` box (no click). Expected: ticked exactly when Blizzard's `Include Reagents` is ticked.
9. Click `Blizzard bank` again. Expected: Blizzard's bank hides, and the title flashes `Blizzard's bank is hidden again`.
10. Click `Deposit warbound`. Expected:
    - the title shows `Depositing warbound items into the warband bank` (or `Depositing warbound items and reagents into the warband bank` when the box is ticked);
    - within a second your warbound items leave the bags and appear under `New` in the `Warband bank` group;
    - no red `Interface action failed because of an AddOn` and nothing about "blocked".

    If the title or chat instead says `SwagBag can't tell whether a deposit would end an item's refund, …` or `The warband bank can't take items right now: nothing was deposited.` or `The warband bank is locked right now (another character of your account may be using it): nothing was deposited.`, tell Claude the exact line.
11. Move the mouse off the button.
12. Right-click the ordinary item stack in your bags. Expected: it moves into the bank group that says `deposits go here`. No red "Interface action failed" or "blocked" message.
13. Move the mouse off the bags, then click the `With reagents` box. Expected: the title flashes `Deposit warbound now takes reagents too (Blizzard's own setting)` (or `… now leaves reagents in your bags …` if it was ticked).
14. Click `Blizzard bank`. Expected: Blizzard's `Include Reagents` box now matches SwagBag's.
15. Click `Blizzard bank` again. Expected: Blizzard's bank hides.
16. Click the `With reagents` box once more. Expected: it is back as it was before step 13.
17. Type `/swagbag bank beside`. Expected: `SwagBag: Bank: Blizzard's bank is shown, with SwagBag's bank window beside it.`; the `Deposit warbound` button is still on SwagBag's window.
18. Type `/swagbag bank tiny`. Expected: `SwagBag: Bank: Blizzard's bank is hidden; its tabs are under SwagBag's bank window.`
19. Walk away from the banker until the bank closes. Expected: both bank windows close.
20. Type `/swagbag report`. Expected: the line `Failed checks: none`. If it names a `C_Bank…`, `C_Item…` or `C_CVar…` check, copy that line to Claude. Close the box.

### Session TF1: the fixes from your 0.5.0 testing (checks Tasks 7 to 9; runs on the final merged build, about 10 minutes)

You need: a vendor and a banker. Your bags should be closed when you start.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.6.0 loaded. Type /swagbag help for commands.`
3. Press **B**. Expected: your bags open.
4. Right-click a vendor. Expected: the vendor window opens, your bags stay open, and the bags' title starts with `SwagBag — AH/Vendor/Bank`.
5. Move the mouse off the bags. Walk away from the vendor with the **S** key until the vendor window closes. Expected: **your bags stay open** (this was FM1 step 8), and the title starts with `SwagBag — ilvl` again.
6. Type `/swagbag report`. Expected: the report box shows a line that starts with `Bag hooks (last 5):`. Press Ctrl+C, paste the whole report to Claude, then press **Esc** to close the box.
7. Press **B**. Expected: your bags close.
8. Right-click the vendor. Expected: the vendor window opens and your bags open by themselves.
9. Walk away from the vendor until its window closes. Expected: your bags close with it (the game opened them, so they go with the vendor).
10. Press **B**. Rest the mouse on the `Pause` button at the top of your bags. Expected: a tooltip with three lines:
    - `Pause focus modes`;
    - `Sections stop opening, closing and moving by themselves until you click Resume (or log in again).`;
    - `Right-click: choose the sections this mode uses`.
11. Click `Pause`. Expected: chat shows `SwagBag: Focus modes are paused for this session: sections stay as you set them. Click Resume, or type /swagbag mode resume.`, and the button now reads `Resume`.
12. Rest the mouse on `Resume`. Expected: the tooltip starts with `Resume focus modes`, then `Focus modes are paused: your sections stay as you set them. Click to let modes switch by themselves again.`
13. Click `Resume`. Expected: chat shows `SwagBag: Focus modes are back on: sections follow what you are doing again.`
14. Move the mouse off the bags. Type `/swagbag settings focus`. Expected: the settings window opens at `Focus modes`, and its first line reads `Focus modes notice what you are doing - a key, the vendor, fishing - and bring the sections you need to the top. They switch by themselves; the "While a mode is on" row below chooses whether the other sections also close. Rest the mouse on a button to see what it does.`
15. Rest the mouse on `Move to the top`. Expected: a tooltip `While a mode is on`, then `Move to the top: the mode's sections come first, right under New. The mode collapses nothing; sections you collapsed yourself stay collapsed. Collapse the rest: only the mode's sections stay open (New always does); every other section collapses until the mode ends.`
16. Rest the mouse on `On` in the row `Mode: Fishing`. Expected: `On: this mode switches on by itself while you fish, as long as Switch by themselves is on. Off: it never does; the other modes still work.` Rest the mouse on a few other buttons on this page. Tell Claude about any tooltip that is still unclear (note it).
17. Click `Alt data` on the left. Expected: in the row `Other characters' counts on item tooltips`, the words `Shown (not twice with Syndicator)` fit inside their button, and `Always shown` and `Hidden` are whole buttons. `Hidden` may sit on a second line. Nothing overlaps, and nothing is cut off at the right edge.
18. Close the settings window with its X.
19. Type `/swagbag setup`. Expected: chat shows `SwagBag: Quick setup opened.`, and under the slots-per-row buttons the window reads `Focus modes bring up the sections you need (a key, the vendor, fishing) by themselves. The Pause button at the top of your bags stops them until you click Resume.`
20. Press **Esc**. Expected: chat shows `SwagBag: Quick setup closed; your settings are unchanged. Type /swagbag setup to open it again.` (If you never pressed Apply or Skip in quick setup, it says `SwagBag: Quick setup closed without changes; it opens again at your next login, or type /swagbag setup.` instead. Both are right.)
21. Look at the bottom of your bags (no click). Expected: your gold shows as a gold coin, as big as the currency icons next to it, and then the gold amount with commas (for example `1,234,567`), with no silver or copper.
22. Rest the mouse on your gold. Expected: a tooltip `Gold on this character` with the full amount: gold, silver and copper, with their coins.
23. Move the mouse off the bags. Right-click a banker. Expected: the SwagBag bank opens.
24. Click `Blizzard bank`. Expected:
    - Blizzard's bank shows beside SwagBag's;
    - chat shows `SwagBag: Blizzard's bank is shown for this visit`;
    - the bank's title shows the same words for about 3 seconds.
25. Click `Blizzard bank` again. Expected: Blizzard's bank hides, and chat shows `SwagBag: Blizzard's bank is hidden again`.
26. Walk away from the banker until the bank closes.
27. Type `/swagbag report`. Expected: lines that start with:
    - `Last bank layout:`;
    - `Bank layout parts: tabs`;
    - `Snapshot sizes: bags`;
    - `Bag hooks (last 5):`.

    Press Ctrl+C, paste the whole report to Claude, then press **Esc**.

## Week 6 exit check

1. Claude installs the week-6 build, at the end of Task 9, and you fully restart the game.
2. Play normally for a day, with keys, a vendor and a bank visit. Expected: no red errors; bags, bank and modes behave as in FS1, DP1 and TF1. Bags you opened yourself stay open when a vendor, the mailbox or the bank closes.
3. Type `/swagbag report` and paste it to Claude. Expected:
   - `Safe Mode: bags=off bank=off`;
   - `Failed checks: none`;
   - a `Bag hooks (last 5):` line;
   - after a bank visit, a `Bank layout parts:` line.

## What week 7 builds on

- `Focus.SectionOrder` and the drawn `W.order` are the hook for any later "a mode moves sections" idea, for example pinning a section to the top for a mode in the editor.
- The deferred items (guild bank pending-item relayout, list view in the bank and guild windows, Syndicator loaded mid-session) all touch `UI/GroupView.lua` or `Providers/Syndicator.lua`; week 7 takes them together.
- The spec text for §6.1/§6.4/AC8.2 (D15) and the new `c_wue` in §7.6 are updated at week end, recorded in the week-6 ledger. So are the D16 ownership rule in §10.1, the D21 `=slot` line form in §8.3, and D22's gold entry in the footer ruling W4-14.
- TF1's `Bank layout parts` line chooses the next bank-speed step (D20). If `reading` dominates, skip some per-item client calls for item kinds that cannot use them, each pinned by a search test. If `drawing` dominates, it moves to the GroupView rewrite above. TF1's `Bag hooks` line shows which walk-away path the game takes (D16), and if it was the frameless call, a ledger note records it.
- `Snapshot sizes` shows whether the snapshot aim (about 30 KB for one character) needs more than D21.

## Spec coverage (week-6 scope → task)

| Requirement | Task |
|---|---|
| Request 1: two styles; default keeps open/collapsed as they are and moves the mode's sections to the top, right after New, in the mode's order | T1 (engine), T2 (window) |
| A mode never writes the saved collapse set or the category order | T1 test "never writes the order …", T2 test "a vendor visit …" |
| P5, hover guard / area hold (W4-13, W4-25), W10, W4-1, W4-16 for the re-order | T2 (one `W.Restack` path; tests for the area hold, W10, W4-1) |
| Peek and pin in "front": decided and justified | D3; T1 and T2 tests |
| List view re-orders the same way; grid changes only the title | T2 (list test; grid test) |
| Settings > Focus modes row and `/swagbag mode style front\|collapse`, answering, refusing read-only | T3 |
| Request 2: badge off by default, still available, existing saved choices kept | T4 (D8) |
| "Warbound until equipped" built-in next to BoE; diff system intact; keyword support | T4 (D9: the keyword already exists) |
| Overlay layout without the badge; Task-11 constants kept | T4 test (D10) |
| Request 3: deposit-all-warbound button; item safety and taint first; real names; tiny and beside; never invisible-but-clickable; P2; combat refusal; include-reagents box | T5 (Adapter), T6 (window); D11, D12, "Blizzard's deposit control" |
| Request 4: free tile in the bank for both groups and the reagent-tab case | D13; T6 test; DP1 steps 4–5 |
| Week-5 deferred: P6, no-schema-bump, BackdropTemplate wording | Global Constraints |
| Week-5 deferred: guild bank pending-item gap ("if GroupView is touched") | Not touched (D13); week 7 |
| Week-4 deferred M5 (no-op focus writes) | T1 (D7) |
| Fix 1: bags the user opened stay open whenever a game frame's CloseAllBags runs, and a game-opened window still closes with its vendor. Rule for CloseAllBags() with no frame. The last five hook calls in `/swagbag report` | T7 (D16); TF1 steps 3–9 |
| Fix 2: Focus modes intro; a tip on every Focus modes row (the style row too); a clearer Pause tooltip with the right-click line kept; one quick setup line; a generic row-level `tip` | T8 (D18); TF1 steps 10–16, 19 |
| Fix 3: a choice button fits its text, with a minimum width, and wraps onto the next line; the rows below move down | T8 (D19); TF1 step 17 |
| Fix 4: the Blizzard bank button's answer also goes to chat, once, and shows 3 s (`BW.Flash` duration) | T7 (D17); TF1 steps 24–25 |
| Fix 5: one measured bank-layout change (each slot read once) and per-part timings in the report; smaller snapshots with the schema kept at 2 and old snapshots read as before (tested) | T9 (D20, D21); TF1 step 27 |
| Fix 6: footer gold as a full-size coin and the gold with thousands separators; silver and copper in the tooltip | T9 (D22); TF1 steps 21–22 |

## How this plan was checked (while writing it)

- Every task was first built on a scratch clone at `/tmp/sb6` (outside the repo), one commit per task. Every block in this file was then generated from those commits' diffs, with each find block expanded until it is unique and starts and ends on a non-blank line.
- **Replay.** A fresh clone of `3d2421d` at `/tmp/sbr` was driven by a script that reads this file: it applies each task's Step 1 blocks, runs the suite, applies the Step 3 blocks, runs the suite and `scripts/check.sh`. Every Step 2 red line and FAIL list, every Step 4 total and every Step 5 `ALL CHECKS PASSED` above is that script's output. The replayed tree was compared file by file with the scratch build (`SwagBag/`, `spec/`, `.luacheckrc`): identical.
- **Mutations.** Every mutation listed under a Step 2 was applied to its task's finished code with a one-off script, and the named test failed (all caught).
- **Tasks 7–9** were built the same way, on top of the replayed Tasks 1–6 (a scratch clone at `/tmp/sbw/base`, one commit per task), and their blocks were generated from those commits' diffs. The whole file, Tasks 1–9, was then replayed on a fresh clone of `76293b0` (the code there is identical to `3d2421d`). Every Step 2 FAIL list and red total for Tasks 7–9 is the output of that task's Step 1 blocks applied to the previous task's finished tree. Every Step 4 and Step 5 line is the replay's output. All 27 mutations listed under the Step 2s of Tasks 7–9 were applied one at a time to the finished Task 9 tree, and each named test failed.
- The bank-read count in Task 9 (2,156 → 1,078 slot reads for one layout of the 1,078-slot fixture) and the snapshot example (1,591 → 358 bytes) were measured on the scratch tree with the mock Adapter. Timings on the mock were not used: they are noisy, and the mock's calls cost nothing like the client's.
- Greps on the final tree:
  - no `C_`/`Enum.` outside `SwagBag/Core/Adapter.lua`;
  - none of the forbidden tokens (one draft comment that named the bank frame's tab method was reworded; check.sh caught it);
  - no `OnUpdate`;
  - no `Config` call at load (the bank and bags load-order tests stay green);
  - no `%s` given a boolean (format51 runs on every spec).

## Self-review

1. **Spec and request coverage.** Every requirement in the brief and each request line maps to a task in "Spec coverage". Request 4 needed no code, and that is stated with the test that proves it (D13). The one deferred item the brief asked about, the guild gap, stays deferred: Task 9 touches GroupView only to time it (D20), not the relayout path the gap lives in. Each of the six fixes from the 0.5.0 testing maps to Task 7, 8 or 9, with a TF1 step that shows it in game. Fix 5 is honest about its limits: one change proven by reading the code, numbers for the rest (D20), and no promise of 30 KB (D21).
2. **Placeholder scan.** No "TBD", "TODO", "similar to", or test-free step. Every code step is a complete block (the replay applies them as written). The in-game expectations quote Locale strings verbatim.
3. **Type and name consistency.** These names are the same in every task that uses them:
   - `Focus.Style/Front/SectionOrder/Applies/SetStyle` (T1 → T2, T3);
   - `opts.order`, `W.order`, `W.EffectiveOrder` (T2);
   - `A.WarbandDepositState/RefundableForWarband/DepositWarband/DepositReagents/SetDepositReagents` and the mock fields `warband`, `warbandDeposits`, `refundChecks` (T5 → T6);
   - `BW.DepositWarband`, `BW.depositButton`, `BW.reagentsBox`, `BW.reagentsLabel`, `BW.RefreshReagents` (T6);
   - `SB.SafeModeHooks.trace/TRACE/TraceText/toggleClosedUsers` and `BW.Flash(text, seconds, toChat)`, `BW.FLASH`, `BW.VISIT_FLASH` (T7);
   - the row field `tip`, `SW.tips`, `SW.ShowTip`, `SW.TEXT_PAD`, `SW.LINE_GAP`, `QS.frame.pauseNote` (T8). Task 3's style-row names `L.SET_FOCUS_STYLE`, `L.SET_FOCUS_STYLE_FRONT` and `L.SET_FOCUS_STYLE_COLLAPSE` are used unchanged by Task 8's tip and its test;
   - `Items.Describe(bag, slot, s)`, `v.stats.phases`, `Snap.BytesByKind`, `F.GOLD_ICON`, `F.GoldText` (T9);
   - the Locale keys quoted in FS1/OV1/DP1/TF1, checked against the T3/T4/T6/T7/T8/T9 blocks. TF1's chat lines that existing keys print (`MODE_PAUSED`, `MODE_RESUMED`, `QS_OPENED`, `QS_LATER_KEPT`, `QS_LATER`, `BANK_SHOWING_BLIZZARD`, `BANK_HIDING_BLIZZARD`) were checked against `SwagBag/Locale/enUS.lua`.
5. **Global Constraints in Tasks 7–9.** No `C_`/`Enum.` or other addon's names outside the Adapter (the gold coin is a texture file path in `Footer.lua`). No forbidden token, including in comments (a draft comment that named the open-all-bags call with its parenthesis failed check.sh and was reworded). Every new script runs under `ErrorTrap.Guard` with its window: `settings.tip` and `settings.tipHide` under `"none"`; the hooks keep their `"bags"` labels; `bank.flash` keeps `"bank"`. Every user-visible string is in `enUS.lua`. Every `%s` gets a string and every `%.1f` a number (format51 runs on every spec). No new setting, no schema change, no `OnUpdate`, and no file added (the TOC stays at 62 files).
4. **Review Focus.** Each of the five lines names its pinning tests, and each of those tests is in its owning task's Step 1. The likeliest real-world failure, a re-order under a resting mouse during a key, has two tests and FS1 steps 7–9.
