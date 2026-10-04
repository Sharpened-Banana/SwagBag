# SwagBag Week 9: Sort with partial stacks first, TSM prices, Masque skins and the double bag-addon warning. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ] `) syntax for tracking.

**Goal:** the user's remaining research picks, in this order of priority, so the earlier ones ship first if time runs out:
1. **Pick 8: Sort with partial stacks first, for TSM posting** (research `2026-10-03-feature-gaps.md` gap 9, `2026-10-03-community-asks.md` ask 5, Bagnon #2200). An optional mode for the Sort buttons (Settings and `/swagbag sort`): SwagBag merges the partial stacks of each item, then puts each item's one partial stack in front of its full ones. Blizzard's sort stays the default. Out of combat only, never under the mouse, small timed steps with identity checks, in the bags and in each bank type apart; it stops cleanly on combat or when the window closes (Tasks 1 and 2).
2. **Pick 10: TSM prices** (gap 22). When TradeSkillMaster is loaded it is a price source (Settings and `/swagbag price`: auto = Auctionator, else TSM, else the vendor; or one of them), with a TSM price string (DBMarket by default; DBMinBuyout, DBRegionMarketAvg, DBRegionSaleAvg). Through the Adapter only, secret-safe, cached like Auctionator. Header totals, the list's Value column, the gold glow and the vendor protection all follow the choice (Task 3).
3. **Pick 11: Masque skins and the double bag-addon warning** (gap 14, community ask 10 / theme P). (a) With Masque loaded, SwagBag's item buttons (bags, bank, guild bank, alt viewer; the list rows use the same buttons) join Masque groups; never in combat, nothing secure touched, nothing without Masque (Task 4). (b) At login, if another bag replacement is also on, one chat line names it and suggests `/swagbag safe on` or disabling one; never disables anything; `/swagbag report` names it (Task 5).
4. **Week-8 deferred polish, user-visible only:** the held F6 fallback restores full-size buttons at once; `Prices.Value` guards a secret item ID; and (week 7) a gold amount typed with `/swagbag worth` shows on the Settings row (Task 6). The rest stays deferred (see "Carry-overs").

Tests go from 1452 to **1491**.

**Architecture:**
- (1) `Engine/Stacker.lua` (new): a mover-style run (week 7's `Engine/Mover.lua` pattern: one step at a time through `Adapter.After`, `ErrorTrap.Guard`, P5 waits, a check after each move) that plans each move from the slots as they are now. One game call, `Adapter.MoveStack` (`C_Container.PickupContainerItem` on the stack, then on the target; the rest goes back). `Mover` and `Stacker` never run at once. (2) `sort.mode` (`"blizzard"` | `"stacks"`) decides what `W.Sort` (`UI/BagsWindow.lua`) and `BW.Sort(kind)` (`UI/BankWindow.lua`) run; `UI/GroupView.lua` gains `v.Busy` for the bank's P5 check; `/swagbag sort` lives in the stacker's file; one Settings > Bags row.
- (3) `Providers/TSM.lua` (new) registers "TSM" with `Engine/Prices.lua`; `Adapter.TSMAvailable/TSMPrice` read `TSM_API`. `Prices` learns `prices.source` and `prices.tsm` (`Prices.Choice`, `TSMString`, `SourceText`, a `SB_CONFIG_CHANGED` listener) and `/swagbag price`; two Settings > Bank & guild rows; the report names TSM's string. `scripts/check.sh` keeps `TSM_API` and `LibStub` in the Adapter.
- (4) `UI/Skins.lua` (new): `Skins.Add(kind, button)` from the three button factories (`UI/Buttons.lua`, `UI/GuildButtons.lua`, `UI/DisplayButtons.lua`); `Adapter.MasqueAvailable/MasqueAdd` read `LibStub("Masque", true)`.
- (5) `Adapter.OtherBagAddons` (`A.OTHER_BAG_ADDONS` through `A.AddOnState`, plus ElvUI's bags module); `Core/Report.lua` says it at `SB_LOGIN` and in the report.
- (6) `UI/GroupView.lua` (`listFailed`), `Engine/Prices.lua` (`Value`), `UI/SettingsPages.lua` (the worth row's choices).

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105; 12.1.5 goes live 2026-10-13). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- spec §5.5 (Sort) gains an optional SwagBag sort mode, under §4.2 rule 5 (nothing moves under the mouse) and the week-7 mover rules (out of combat, small timed steps, identity checks, stop on close);
- §3.3 and F10 (price providers): TSM joins Auctionator and the vendor, with a user choice; AC17.2 (the vendor's protections) follows that choice;
- §4.1 (the button contract) for Masque: the buttons are handed to Masque, never reparented, re-ID'd or given attributes, never in combat;
- §10.4 (`/swagbag report`) and P4 (other addons: detect, never take over) for the second bag addon;
- §9 (secret values) for a secret item ID, and the week-5 F6 rule for a held fallback.
The spec text is updated at week end (see "Spec updates at week end"). All rights reserved: every idea here is clean-room; no code is copied from Baganator, Bagnon, BankStack, TSM, Masque or any other addon (GPL or not). Only the public APIs named in "What the week relies on" are called.

Ledgers (binding rulings W3-*, W4-*, W5-*, week 6, week 7 R1–R22, week 8 Q1–Q13): `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md` through `2026-10-07-swagbag-week8-ledger.md`. Week-8 plan (style and interfaces): `docs/superpowers/plans/2026-10-07-swagbag-week8-carryovers.md`. Research: `research/2026-10-03-feature-gaps.md`, `research/2026-10-03-community-asks.md`, `research/2026-10-03-horizon.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week9` is already checked out. It was made from `main` at `ae00814` (v0.8.0, week 8 merged). The suite has 1452 tests. No task creates or switches branches.

**The code at `ae00814` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). These interfaces are used as they are on `ae00814`:
- `SB.On`, `SB.Emit`, `SB.Debounce(key, delay, fn, window)`, `SB.OutOfCombat(fn, label, window)`, `SB.ErrorTrap.Run/Guard/OnError(label, window, message, stack)`, `SB.Print`, `SB.Slash.Register/Run/Dispatch`.
- `SB.Config.Get/Set/readOnly/db/Init`; `Config.Set` emits `SB_CONFIG_CHANGED(path)` and returns false while read-only; `Config.Init` emits it with `nil`.
- `SB.Mover` (`Start`, `Busy`, `IsBusy`, `run`, `DELAY`, `RETRY`, `MAX_WAITS`, `MAX_PENDING`), `SB.Locks.Has/Toggle`, `L.MOVER_BUSY`.
- `SB.BagsWindow` (`W.Sort`, `W.sortButton`, `W.Flash`, `W.RequestLayout`, `W.ButtonBusy`, `W.stats`, `W.SORT_SETTLE`), `SB.BankWindow` (`BW.Sort(kind)`, `BW.sortBankButton`, `BW.sortWarbandButton`, `BW.Flash`, `BW.interaction`, `BW.view`), `SB.GroupView` views (`RequestLayout`, `IsOpen`, `drawn`, `listFailed`, `stats`), `GV.RETRY`.
- `SB.Prices` (`RegisterProvider`, `Value`, `Source`, `Invalidate`, `cache`, `REFRESH_DELAY`, `MAX_AGE`), `Providers/Auctionator.lua`, `SB_PRICES_CHANGED`, `Vendor`'s `worthMoreAtAuction`.
- `SB.Buttons` (`createButton` via `EnsureCapacity`, `CreateAll`, `EnsureBankTabs`, `Get`, `KindOf`), `SB.GuildButtons` (`Ensure`, `SetParent`), `SB.DisplayButtons` (`Get`, `SetParent`).
- `SB.Report.Build`, `Report.ADDONS_IF_LOADED`, `SB.SafeMode.IsOn/Enable`, `SB.Profiles` (`VALID`, `LABELS`, `Parse`, `Export`), `SB.SettingsWindow` (`AddPage`, rows `kind = "choice"`).
- Adapter: `A.Resolve`, `A.AddOnState`, `A.GetBagIDs/NumSlots/GetSlot/GetItemInfo/InEquipmentSet/IsSecret/CursorItem/ClearCursor/InCombat/After/SortBags/SortBank`, `A.CHECKS`.
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua` (`Fake.New`, `Fake.Fire`, `Fake.Strict`, `Fake.Install/Uninstall`), `uienv.lua` (`Env.ENGINE`, `Env.LoadBank`, `Env.PaintGlobals`), `spec/fixtures/items.lua` (potions and flasks stack to 20, junk to 200), `spec/mock_adapter.lua` (its fakes replace the Adapter's WoW calls; the Adapter's own logic that only calls other Adapter functions, like `A.OtherBagAddons`, runs for real over them), and `format51` (installed by the runner).



## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.9.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. New this week, all in the Adapter: one Blizzard function (`C_Container.PickupContainerItem`, the game's own click-to-pick-up, added to `A.CHECKS` as optional), and other addons' public APIs: `TSM_API.ToItemString` / `TSM_API.GetCustomPriceValue`, `LibStub("Masque", true)` with `:Group` / `:AddButton`, and ElvUI's `ElvUI[1].private.bags.enable` (read only).
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster, Masque` (TradeSkillMaster from Task 3, Masque from Task 4; `scripts/toc_check.lua` requires the line as it is at that point). Three files are added: `Engine/Stacker.lua` (Task 1), `Providers/TSM.lua` (Task 3), `UI/Skins.lua` (Task 4): the TOC goes from 72 to 73, 74 and 75 files.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets a string or a number, never a boolean or nil. Every spec runs under `spec/helpers/format51.lua`, which makes the tests as strict as WoW.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace, `Enum`, ElvUI, Syndicator, TSM or Masque globals, **comments included**. `scripts/check.sh` fails on `C_X.`/`Enum.` and on a bare `C_X` name outside the Adapter (week 7, ruling R5), and from Task 3 on `TSM_API` or `LibStub` as a word outside the Adapter (the product names "TSM" and "Masque" in strings and comments are fine; their globals are not). ElvUI and Syndicator globals stay review-enforced. Every other file calls `SB.Adapter.*`.
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`. `SetCurrentGuildBankTab` is never called.
- **Secure item buttons** (`ContainerFrameItemButtonTemplate`, the bags' and the bank's) are never reparented, never created in combat, never re-`SetID`'d, and get **no** click script or click hook of any kind. This week: the stacker never touches a button at all (it moves items through the game's own pickup calls on bag slots, out of combat); Masque gets each button once through `group:AddButton(button, nil, "Item")`, out of combat only. **F6 / ruling W5-1** stands: a list row never shows a full-size button; Task 6 makes a held fallback restore full size at once under drawn categories.
- **Item safety (this week's moves):** a stacking move only ever lands on a stack of the same item (same link) in the same scope: the bags (bags and reagent bag), the character bank or the warband bank, never across, so no item changes bank type. Items the user locked, equipment-set items, single items, items whose data has not loaded and secret links stay put. Nothing is ever left on the cursor (`Adapter.MoveStack` puts back what did not fit). The stacker and the week-7 mover (auto-sell, Sell all, bank all) never run at once.
- P1: every setting ships with a chosen default, and its alternative sits next to it in the same place. Options are phrased as choices. This week: `sort.mode` "Blizzard's sort" first, "Partial stacks first" next (Settings > Bags, `/swagbag sort`); `prices.source` "Auto" first, then Auctionator, TSM, Vendor; `prices.tsm` "DBMarket" first (Settings > Bank & guild, `/swagbag price`). Masque has no SwagBag setting: Masque's own options switch each SwagBag group off (D14).
- P2: every command, button and settings choice answers **exactly once**: a Sort click in its window's title (`Stacking...`, or why it cannot start); the stacking run's outcome is the run's own single chat line (as the auto-sell line since week 7, D8); `/swagbag sort` and `/swagbag price` in chat; a Settings click in the status line (through the command).
- P5 / spec §4.2 rule 5: nothing moves under the mouse or while an item is on the cursor. The stacker waits `RETRY` (0.3 s) while an item is on the cursor (however long), and while a slot it would touch is under the mouse (in a list its row too) up to `MAX_WAITS` (20) times, then leaves that item. Held moves and layouts retry through `Adapter.After` / `SB.Debounce`, never `OnUpdate`.
- **P6.** Every WoW entry point runs inside `SB.ErrorTrap.Run` or `Guard`. The labels this week:
  - unchanged: the Sort buttons' clicks (`bags.sortButton` under `"bags"`, `bank.sortBank` / `bank.sortWarband` under `"bank"`);
  - `"none"` (recorded, never Safe Mode): the stacker's steps (`stacker.step`), its result callback (`stacker.done`, which also prints the line and asks the window to regroup), a refused move (`stacker.move`), the Skins' out-of-combat flush (`skins.add`), the Prices `SB_CONFIG_CHANGED` listener, the Report's `SB_LOGIN` warning, and the `sort` and `price` commands (`Slash.Register`'s default window).
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`. Product and price-string names (`Auctionator`, `TSM`, `DBMarket`, an addon's folder name) are shown as they are.
- **Plain frames only, may be created in combat:** nothing new is a frame this week except what Masque itself adds to a button (Masque's business, out of combat).
- **Settings and saved data (schema stays 2):** new keys with explicit defaults in `Config.Defaults`: `sort.mode = "blizzard"` (Task 2), `prices.source = "auto"` and `prices.tsm = "DBMarket"` (Task 3). Only values somebody wrote are stored, so no migration. `Engine/Profiles.lua`'s `VALID` lists their words (a share string with another word is refused whole) and `LABELS` names them (the week-7 test "every known setting has a label" covers them). Every writer refuses while `Config.readOnly` and says `L.SETTINGS_READONLY`.
- No file calls `Config` at load time (the load-order tests stay green). Every `OnHide` handler starts with `if self:IsShown() then return end` (none is added this week).
- No `OnUpdate` anywhere. Idle CPU with every window closed is 0: the stacker runs only after a Sort click and stops when done; TSM is never polled (its prices are read on lookup and cached 10 minutes); Masque is asked once per session.
- Every critical test names the mutation that must make it fail. Each task lists its mutations under Step 2.
- **Tooling (binding, as in weeks 1–8):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). Where a test fakes a frame method or another addon's API, it fakes it the way the real one behaves (`TSM_API` raises an error on an unknown name; `LibStub` is a callable table; a shrunk button's hit area moves with it). CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Test totals are cumulative from 1452 (see "Schedule").
- One commit per task, made with `git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit`. The message ends with exactly these two lines:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`
- In-game checks are written for the user, who is not a programmer:
  - each session begins with "Claude installs the build first", followed by a full game restart (not `/reload`);
  - steps are numbered, one action per step, each saying exactly what the user should see;
  - quoted strings match `SwagBag/Locale/enUS.lua` exactly, and chat lines start with `SwagBag: `;
  - a step after a click on an item says to move the mouse off it.

  Sessions never block the build: findings come back as fixes.


## Review Focus

These are the failure modes most likely to bite the user that the spec implies but the feature tests would not naturally hit, most likely first. Each is pinned by tests in the task that owns the code.

1. **An item moved into the wrong bank type, or between the bags and a bank, by stacking.** Expected: a run reads only its own scope and only ever drops onto a stack of the same item there. Pinned by Task 1: "never pairs stacks across scopes: the bags, the character bank and the warband bank are stacked apart" and Task 2: "with sort stacks, Sort bank stacks the character bank only; the warband bank is never touched".
2. **Stacking under the mouse, with an item on the cursor, or leaving an item on the cursor.** Expected: every step waits (P5); a pair the mouse never leaves is left; whatever does not fit goes back to its slot. Pinned by Task 1: "waits while an item is on the cursor or a slot it would touch is under the mouse, then moves", "a pair the mouse never leaves is left as it is; the run carries on with the next item", "picks up and drops with the game's own call, puts back what is left, never starts with an item held", "a throwing pickup is reported and the cursor is cleared"; Task 2: "stacking waits while the slot it would touch is under the mouse".
3. **A run that keeps going after combat starts or the window closes, or that never ends.** Expected: combat or a closed window stops it before the next move, nothing is queued; a move that changed nothing stops it. Pinned by Task 1: "combat or a closed window stops the run before the next move; nothing is queued", "waits while the game holds a moved slot locked; a move that changes nothing stops the run"; Task 2: "closing the bank stops stacking before the next move".
4. **A locked or equipment-set item moved.** Expected: never touched by stacking. Pinned by Task 1: "leaves locked items, equipment-set items, single items and items not loaded yet where they are".
5. **Selling a gray BoE that TSM says is valuable, or prices from a source the user did not pick.** Expected: the protection and every total ask the chosen source. Pinned by Task 3: "a gray BoE worth more than twice its vendor price by TSM's price stays when TSM is the source" and "by default Auctionator answers, else TSM, else the vendor; prices.source picks one, the vendor fills in".
6. **A TSM error or a secret value on the draw path** (header totals and the list run under `"bags"`: an error there means Safe Mode). Expected: no price, never an error. Pinned by Task 3: "prices through ToItemString and GetCustomPriceValue, only for the price strings SwagBag offers", "an error, a negative or a non-number from TSM is no price"; Task 6: "a secret item ID is no key either: no price, nothing cached under it, never an error".
7. **Masque restyling a secure button in combat, or anything happening without Masque.** Expected: out of combat only, once per button; without Masque nothing is asked. Pinned by Task 4: "a button made in combat joins only once combat ends" and "without Masque nothing is asked, and SwagBag calls nothing more on a button than before".
8. **A second bag addon switched off, or a warning that will not go away.** Expected: one line per login, silent in Safe Mode, nothing disabled. Pinned by Task 5: "at login one line names them and suggests /swagbag safe on; silent when none, or in Safe Mode".
9. **Shrunk buttons under drawn categories (smaller click targets).** Expected: a held F6 fallback restores full size at once. Pinned by Task 6: "F6: a fallback held under the mouse puts the drawn categories' buttons back at full size at once".



## Decisions (every product default chosen this week, read before Task 1)

| # | Question | This plan (the default) | The alternative, and where it is | Why |
|---|---|---|---|---|
| D1 | What the Sort buttons do | **Blizzard's sort** (as since week 2). The new mode "Partial stacks first" (`sort.mode = "stacks"`) applies to every Sort button: the bags' Sort, the bank's "Sort bank" and "Sort warband". | Settings > Bags > "The Sort buttons": Partial stacks first; `/swagbag sort stacks` (and back: `/swagbag sort blizzard`). | The brief: off by default; one switch for all three buttons is one thing to learn. |
| D2 | What "Partial stacks first" does | **Merge, then order, and nothing else:** first every item's partial stacks are merged (the last onto the first), then each item's one partial stack swaps with that item's first full stack, so it comes first. Every other item stays where it is; Blizzard's sort is not run. | Press Sort in Blizzard's mode first for Blizzard's order, then in this mode. (Chaining both in one press: rejected, see Why.) | Blizzard's sort runs on the server and settles over a second or more; chaining a second engine after it doubles the moves and the wait, and its result would decide which slot is "first". Merge-then-order is predictable and is what TSM posting needs. |
| D3 | Could Blizzard's sort be told to do this? | **No.** `C_Container.SortBags()` / `SortBank(bankType)` take no options. The client's only sort settings are "sort right to left", "insert left to right" and each bag's "ignore when cleaning up" flags; none merges or orders partial stacks. So SwagBag moves the stacks itself, with the week-7 mover's safety rules. | — | Research for pick 8. |
| D4 | Which stack goes where | **"First" is slot order:** bag IDs in the game's order, then slot number (the grid view's order). Merge: the item's last partial stack goes onto its first partial stack (what does not fit stays in the last). Order: the one partial stack swaps with the item's first stack when that one is full. "The same item" means the same item link, so two stacks the game would not stack are never paired. | — | Fewest moves; the partial lands where TSM and the eye look first. |
| D5 | Where a run works | **One scope per press, never across:** the bags' Sort stacks the bags (backpack, bags and the reagent bag); "Sort bank" the character bank's tabs; "Sort warband" the warband bank's tabs. | — | Item safety: an item never changes bank type or leaves the bags. |
| D6 | What stacking leaves alone | **Items you locked** (every stack of a locked item, `/swagbag lock`), **equipment-set items**, items that do not stack, items whose data has not loaded, a secret link. | Merging locked items too: rejected (the brief: never touch locked items' positions). | Locks mean "leave it alone" to a gold-maker; a set piece is gear. |
| D7 | Pace and patience | One move every **0.2 s** (`DELAY`). An item on the cursor: wait 0.3 s and look again, however long. A slot under the mouse: wait 0.3 s up to **20** times (6 s), then that item is left and the line says `Left alone under your mouse: N.` After a move, while the game holds either slot locked (the server has not answered), wait 0.2 s up to 10 times; then a move that did not do what it should (the target did not gain, or the partial did not arrive first) **stops the run** with `Stacking stopped: an item did not move as expected (...)`. | — | The mover's tested timings (week 7); a run never loops on a move the game refuses. |
| D8 | How a run answers | The click answers in the window's title: `Stacking...`, or `Nothing to stack: ...`, `SwagBag is still moving items: ...` (the mover runs) or `Sort after combat ends`. The **outcome is one chat line** (`Stacking done. Stacks merged: N. Partial stacks moved first: N.`, or why it stopped), then the window regroups (held while the mouse is over the items, P5). | The outcome in the title: rejected. | A run can outlast the title's 1.5 s answer, and the window may be closed by then; the auto-sell's line works the same way. |
| D9 | Combat and closing | Combat or the window closing (the bags window for the bags; the bank visit for the bank) **stops the run before its next move**; nothing is queued; what moved stays moved. Press Sort again to finish. | — | Spec §5.5 / ruling W11: nothing runs later by itself. |
| D10 | Where prices come from | **Auto:** Auctionator if loaded, else TSM if loaded, else what a vendor pays. Or one of them: Auctionator, TSM or Vendor (that one; the vendor for what it has no price for). A chosen source that is not loaded leaves the vendor answering, and `/swagbag price` says so. | Settings > Bank & guild > "Item prices come from"; `/swagbag price auto|auctionator|tsm|vendor`. | The brief's default; "auto" is exactly the providers' priority order (Auctionator 10, TSM 5, vendor 0). |
| D11 | Which TSM price | **DBMarket** (TSM's realm market value). The others offered: **DBMinBuyout**, **DBRegionMarketAvg**, **DBRegionSaleAvg**. Only these four are ever asked; no custom TSM formulas. | Settings > Bank & guild > "TSM price (when TSM answers)"; `/swagbag price tsm dbminbuyout` (any case). | A share string must never make SwagBag evaluate an arbitrary formula; the four cover the brief. |
| D12 | When TSM prices refresh | TSM's public addon API has **no "prices changed" callback**, so TSM prices refresh through the existing 10-minute cache age (`Prices.MAX_AGE`) and whenever the source or the TSM price changes (one refresh of the open windows' totals). Auctionator keeps its own callback. | `/reload` refreshes at once. | Researched (TSM's addon API documentation and adapters built on it): the API is pull-only (`ToItemString`, `GetCustomPriceValue` and lookups); no price-update callback is documented. |
| D13 | The vendor's "gray BoE worth more than twice at auction" rule | **Follows the chosen source**, like everything else. With "Vendor" chosen there is no auction price, so a gray BoE is judged by what a vendor pays and can be sold as junk (the Settings tip says so). | **Flag for the user:** the protection could keep asking Auctionator/TSM even when "Vendor" is chosen (one line in `Engine/Vendor.lua`). | The brief: the protections use the chosen source. |
| D14 | Masque | **On whenever Masque is loaded:** SwagBag's groups "Bags", "Bank", "Guild bank" and "Alt viewer" appear under SwagBag in Masque's options, which pick the skin and can switch each group off. No SwagBag setting. | Masque's own options (`/masque`). | One switch, where Masque users already look. |
| D15 | Masque and the secure buttons | SwagBag's only call is `group:AddButton(button, nil, "Item")`, **once per button, out of combat** (a button made in combat joins when combat ends). Nothing else about a button changes; SwagBag's slot background (week 1) stays under the skin. | — | Spec §4.1; Masque restyles textures only, never secure attributes. |
| D16 | A second bag addon | **One chat line at every login** while another bag addon is on and SwagBag's bags are not in Safe Mode, naming it and suggesting `/swagbag safe on` or disabling one in the AddOns list. `/swagbag report` always says `Other bag addons on: ...`. Nothing is ever switched off. ElvUI counts only while its own bags module is on. | `/swagbag safe on` silences it (SwagBag steps aside). | The conflict persists until one is chosen; P4: never take over another addon. |
| D17 | Week-8 (and one week-7) deferred items | **This week:** the held F6 fallback restores full size at once (week-8 final re-review); `Prices.Value` guards a secret item ID (week-8 final re-review); an amount typed with `/swagbag worth` gets its own selected button (week 7, Task 7). The rest stays deferred ("Carry-overs"). | — | Cheap and user-visible (the brief). |
| D18 | Version | `0.9.0` (Task 1). | — | — |


## What the week relies on

| What | Name | Since | Confidence |
|---|---|---|---|
| Picking up and dropping a bag item | `C_Container.PickupContainerItem(bag, slot)` (Adapter `A.MoveStack`; `GetCursorInfo` and `ClearCursor` as since week 2) | new (the game's own click; every stacking addon uses it) | Out of combat only. The merge/swap answer of the game is checked in session ST1 (G1, G2). |
| Blizzard's sort has no options | `C_Container.SortBags()`, `C_Container.SortBank(bankType)` | week 2 / week 3 | Research for D3. |
| TSM prices | `TSM_API.ToItemString(item)`, `TSM_API.GetCustomPriceValue(customPriceStr, itemStr)` (TSM's public addon API, `api.tradeskillmaster.com/addon`; `TSM_API` raises an error on an unknown key, so every read is pcall'd) | new | The db* sources are nil without TSM's desktop app feeding them (the TSM answer then is "no price": the vendor answers). Session TS1 (G5). |
| Masque | `LibStub("Masque", true)`, `Masque:Group(addon, group)`, `Group:AddButton(button [, regions [, type [, strict]]])` (Masque's Group API wiki) | new | The `"Item"` type and the skins on SwagBag's buttons, in tiny and list views, are checked in MQ1 (G6, G7). |
| Other addons on | `C_AddOns.IsAddOnLoaded`, `C_AddOns.GetAddOnMetadata` (`A.AddOnState`) | week 1 (the report) | The folder names of a few addons are not verified (G8). |
| ElvUI's bags module | `ElvUI[1].private.bags.enable` | new (read only) | ElvUI's private profile is read at `SB_LOGIN`, after ElvUI loaded (OptionalDeps). G9. |


## Needs in-game confirmation (what could not be verified at the desk)

Each item names the session step that checks it. None blocks the build; a wrong answer comes back as a fix.

| # | What | Why it is uncertain | Checked in |
|---|---|---|---|
| G1 | A partial stack dropped on a full stack of the same item **swaps** with it (the order pass) | The game's answer for a full target is modelled, not seen; if it refuses, the run stops with "did not move as expected" and nothing is lost | ST1 steps 7–8 |
| G2 | A merge whose stacks do not fit in one keeps the rest in the source slot, nothing on the cursor | `A.MoveStack` puts back what is left; the second pickup's timing is the client's | ST1 steps 7, 10 |
| G3 | Stacking in the bank tabs (character and warband) works the same, and never crosses bank types | Bank tabs are bags 6–16 to the game; not tried in game | ST1 steps 13–16 |
| G4 | Five moves a second feels fine for a bag with many partial stacks | Taste | ST1 step 7 (say if it is too slow) |
| G5 | TSM answers DBMarket and the others for item links, and the numbers match TSM's own tooltip | Read from TSM's documentation only | TS1 steps 5–8 |
| G6 | Masque skins the bags', bank's and guild bank's buttons with no "action blocked" message, and potions still work from the bags in combat | Masque on Blizzard's secure item template, out of combat | MQ1 steps 4–9 |
| G7 | The list view and SwagBag's own slot background look right under a Masque skin | Looks | MQ1 steps 5–6 |
| G8 | The folder names `GudaBags`, `Inventorian`, `EllesmereUIBags` and `EnhanceQoLBags` are the ones `C_AddOns` reports | From the research files and the week-1 report list, not installed copies | MQ1 steps 11–14 (with whichever bag addon the user has; Baganator is checked) |
| G9 | ElvUI's `private.bags.enable` is readable at login | ElvUI builds its profile on its own load | MQ1 step 15 (only with ElvUI) |


## Carry-overs: what this week takes, and what stays deferred

Taken (the task that does it): week-8 final re-review minors "held F6 fallback leaves already-scaled buttons small until retry" and "Prices.Value doesn't guard a secret itemID" (Task 6); week-7 Task 7 "custom slash amount shows no selected button" (Task 6).

Checked and already done (no task): every week-8 "FINAL CONSIDER" item was fixed in the week-8 final fix wave (`74cedd0`): the F6 fallback's P5 re-check and title (Task 1), one retry of `P.Hook` (Task 4), the secret-link guard in `Prices.Value` (Task 5).

Triaged and left deferred (not user-visible, test-only, or needing an in-game look first):
- week-8 Task 1: column bar and sort text duplicated with the bags window; `build()` paints rows for discarded candidates; `scaleAll` reads `GetScale` per slot on non-list layouts; a not-unique Q5 test; `hideGone`'s `rows.Place` unpinned;
- week-8 Task 2: guild tests for P5 on a list re-sort, `SB_PRICES_CHANGED` `RefreshRows`, right-click/drop on scaled guild buttons (test-only); `GW.View` near-duplicate of `BW.View`;
- week-8 Task 3: a second pending item, an event after close, the chest literal (test-only);
- week-8 Task 4: a spurious late announce if Syndicator loads before login; tooltip memo recompute not asserted; `followSource` calls `Characters()` per event; `OW.source` not reset on close;
- week-8 Task 5: `LookUnknown` naming, a stale comment, the coin and the sale may disagree until the cache clears (safe side), wording, the Q2 test;
- week-8 Task 6: `PINNED` comment, duplicated preview code, "just below Junk" wording, the pinned-only preview count;
- week-8 Task 7: only one `SB_BANK_CHANGED` emit site pinned; a possible double emit per layout (debounced); stubs restored at test end;
- the week-6 and week-7 items listed as deferred in the week-8 plan (bind badge overlap, stale menu counts, `Snap.Bytes`, the reagents box in beside mode, ...), unchanged;
- the week-6 bank-speed part 2: still waits on session TF1's numbers.

The week-8 sessions (BL1, GL1, SY1, VP1) and the earlier open checks are unchanged by this plan.


---

## File structure (end of week 9)

New and changed files only. Everything else is as on `ae00814`.

```
SwagBag/Engine/Stacker.lua             NEW  (T1) the stacking run; (T2) /swagbag sort
SwagBag/Providers/TSM.lua              NEW  (T3) the "TSM" price provider
SwagBag/UI/Skins.lua                   NEW  (T4) Masque groups for SwagBag's item buttons
SwagBag/Core/Adapter.lua               MOD  (T1) MoveStack, the PickupContainerItem check; (T3) TSM_PRICES, TSMAvailable,
                                            TSMPrice; (T4) MasqueAvailable, MasqueAdd; (T5) OTHER_BAG_ADDONS,
                                            ElvUIBagsOn, OtherBagAddons
SwagBag/Engine/Mover.lua               MOD  (T1) waits for a stacking run
SwagBag/Engine/Prices.lua              MOD  (T3) the source choice, TSMString, SourceText, /swagbag price;
                                            (T6) a secret item ID
SwagBag/Core/Config.lua                MOD  (T2) sort.mode; (T3) prices.source, prices.tsm
SwagBag/Engine/Profiles.lua            MOD  (T2, T3) VALID and LABELS for the new settings
SwagBag/UI/BagsWindow.lua              MOD  (T2) Sort stacks in "stacks" mode
SwagBag/UI/BankWindow.lua              MOD  (T2) Sort bank / Sort warband stack in "stacks" mode
SwagBag/UI/GroupView.lua               MOD  (T2) v.Busy; (T6) a held F6 fallback restores full size
SwagBag/UI/SettingsPages.lua           MOD  (T2) the Sort row; (T3) the price rows; (T6) a typed gold amount
SwagBag/UI/Buttons.lua, GuildButtons.lua, DisplayButtons.lua   MOD  (T4) Skins.Add when a button is made
SwagBag/Core/Report.lua                MOD  (T3) TSM's price string; (T4) the Masque line; (T5) the other-bag-addon line
                                            and login warning
SwagBag/Locale/enUS.lua                MOD  (T1–T5)
SwagBag/SwagBag.toc                    MOD  (T1) Stacker, 0.9.0; (T3) TSM, OptionalDeps; (T4) Skins, OptionalDeps
SwagBag/Core/Init.lua                  MOD  (T1) 0.9.0
scripts/check.sh                       MOD  (T3) TSM_API / LibStub only in the Adapter
scripts/toc_check.lua                  MOD  (T3, T4) the OptionalDeps line
spec/stacker_spec.lua (T1), spec/skins_spec.lua (T4)                                                         NEW
spec/mock_adapter.lua (T1, T3, T4), adapter_spec.lua (T1, T3, T4), bagswindow_sections_spec.lua (T2),
spec/bankwindow_groups_spec.lua (T2), settings_spec.lua (T2, T3, T6), profiles_spec.lua (T2, T3),
spec/prices_spec.lua (T3, T6), vendor_spec.lua (T3), report_spec.lua (T3, T4, T5), bankwindow_list_spec.lua (T6)  MOD
```

`TOC OK (73 files)` after Task 1 and 2, `(74 files)` after Task 3, `(75 files)` after Tasks 4 to 6.


## Schedule (week 9)

In priority order, so the earlier items ship first if time runs out. 12.1.5 goes live on 2026-10-13; nothing this week depends on it.

| Day | Tasks | User in game? |
|---|---|---|
| 1 | 1, 2 | after the merge: session ST1 (stacking, about 15 minutes) |
| 1 | 3 | after the merge: session TS1 (TSM prices, about 10 minutes) |
| 2 | 4, 5, 6 | after the merge: session MQ1 (Masque and the warning, about 10 minutes) |
| 3 | final review, fixes | **Week 9 exit check** |

Cumulative `scripts/check.sh` test totals (from 1452 on `ae00814`). Each was produced by replaying this file's blocks in order on a fresh clone of `ae00814`:
- T1 1463 passed, 0 failed (+11)
- T2 1470 passed, 0 failed (+7)
- T3 1479 passed, 0 failed (+9)
- T4 1486 passed, 0 failed (+7)
- T5 1488 passed, 0 failed (+2; one existing test gains a line)
- T6 1491 passed, 0 failed (+3)

## How to read the code steps

- A **Create** step gives a complete new file.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point and its replacement. The block occurs exactly once in the file, and starts and ends on a non-blank line. When a step edits one file in several places, the places are numbered "(edit N of M)". Apply them in that order, top to bottom. Each find block is unique in the file as it is after the earlier edits.
- No step replaces a whole existing file.
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks (everything else, `scripts/` included). Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists its critical tests and, for each, the code change (mutation) that must make it fail. Every mutation was applied to the finished code of its task and the named test failed. A reviewer re-runs any of them with a one-line edit. In a mutation, ` ⏎ ` marks a line break and `∅` an empty replacement; leading tabs are left out.
- A test that passes at Step 2 is named there with the reason (none this week).

---

### Task 1: The stacker: merge partial stacks, then the partial stack first (Engine/Stacker.lua); v0.9.0

The user's first pick this week (pick 8, "partial stacks first, for TSM posting"). Research first: Blizzard's sort (`C_Container.SortBags`, `C_Container.SortBank`) takes no options at all; the only sort-related client settings are "sort right to left", "insert left to right" and the per-bag "ignore this bag when cleaning up" flags, and none of them orders partial stacks (D3). So SwagBag gets its own small run, built like the week-7 mover: `Engine/Stacker.lua` plans one move at a time from the slots as they are now: first it merges an item's last partial stack onto its first one, then it swaps an item's one partial stack with the item's first full stack, so the partial comes first (D2, D4). One scope per run, never across (D5): the bags, the character bank or the warband bank, from `Adapter.GetBagIDs(kind)`; a move only ever lands on a stack of the same item in the same scope. Locked, equipment-set, single, not-loaded and secret-link items stay put (D6). Every step is out of combat, never with an item on the cursor, never on a slot under the mouse (P5, with the mover's `MAX_WAITS` rule), waits while the game holds a moved slot locked, and checks the move did what it should; one that did not stops the run (D7, D9). The one game call is `Adapter.MoveStack`: the game's own pickup on the stack and on the target, and whatever is left on the cursor goes back where it came from. The mover and the stacker never run at once. Nothing calls the stacker yet (Task 2 wires the Sort buttons). The version goes to 0.9.0.

**Files:**
- Create: `SwagBag/Engine/Stacker.lua`, `spec/stacker_spec.lua`
- Modify: `SwagBag/Core/Adapter.lua` (`A.MoveStack`, the `C_Container.PickupContainerItem` check), `SwagBag/Engine/Mover.lua` (waits for a stacking run), `SwagBag/Locale/enUS.lua`
- Modify: `SwagBag/SwagBag.toc` (the new file; 0.9.0), `SwagBag/Core/Init.lua` (0.9.0)
- Test: `spec/adapter_spec.lua`, `spec/mock_adapter.lua` (`m.MoveStack`, `m.stackMoves`, `m.onMoveStack`, `m.moveFails`)

**Interfaces:**
- Consumes: `Adapter.GetBagIDs/NumSlots/GetSlot/GetItemInfo/InEquipmentSet/IsSecret/CursorItem/InCombat/After`, `Locks.Has`, `Mover.Busy`, `ErrorTrap.Run/Guard/OnError`.
- Produces: `Adapter.MoveStack(fromBag, fromSlot, toBag, toSlot) -> ok, err`; `SB.Stacker` with `Start(job) -> true | false, why` (`job = { kind, still, busy, done }`, why `"busy" | "combat" | "nothing"`), `Busy()`, `Stop(why)`, `Plan(kind, skip, maxOf)`, `ResultText(result)`, `DELAY` 0.2, `RETRY` 0.3, `MAX_WAITS` 20, `MAX_PENDING` 10; result `{ merged, ordered, kept, why }`; `L.STACK_DONE/KEPT/STOP_COMBAT/STOP_CLOSED/STOP_STUCK`; `SB.VERSION = "0.9.0"`.

- [ ] **Step 1: Write the failing tests**

In `spec/adapter_spec.lua`, find:

```lua
		assert.is_nil(A.AppearanceKnown("item:2"), "a secret answer")
	end)
end)
```

and replace it with:

```lua
		assert.is_nil(A.AppearanceKnown("item:2"), "a secret answer")
	end)
end)

-- Week 9 (user pick 8): the stacker's one game call. Mutation: in A.MoveStack, drop the put-back pickup.
describe("Adapter.MoveStack (real adapter, stubbed globals)", function()
	local A, calls, cursor
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		calls, cursor = {}, nil
		GetCursorInfo = function()
			if cursor then
				return "item", 211880, "item:211880"
			end
		end
	end)

	after_each(function()
		GetCursorInfo, ClearCursor, C_Container = nil, nil, nil
	end)

	-- keep: what the drop leaves on the cursor (true: the rest that did not fit).
	local function game(keep)
		C_Container = { PickupContainerItem = function(bag, slot)
			calls[#calls + 1] = { bag, slot }
			if #calls == 1 then
				cursor = true
			elseif #calls == 2 then
				cursor = keep or nil
			else
				cursor = nil
			end
		end }
	end

	it("picks up and drops with the game's own call, puts back what is left, never starts with an item held", function()
		assert.falsy(A.MoveStack(0, 2, 0, 1), "no API")
		game(false)
		assert.truthy(A.MoveStack(0, 2, 0, 1))
		assert.same({ { 0, 2 }, { 0, 1 } }, calls)
		calls = {}
		game(true)
		assert.truthy(A.MoveStack(0, 4, 0, 2))
		assert.same({ { 0, 4 }, { 0, 2 }, { 0, 4 } }, calls, "the rest goes back where it came from")
		assert.is_nil(cursor)
		calls, cursor = {}, true
		assert.falsy(A.MoveStack(0, 4, 0, 2), "the user holds an item")
		assert.same({}, calls)
	end)

	it("a throwing pickup is reported and the cursor is cleared", function()
		local cleared = 0
		ClearCursor = function() cleared = cleared + 1 cursor = nil end
		C_Container = { PickupContainerItem = function(bag)
			if bag == 9 then
				error("refused")
			end
			cursor = true
		end }
		local ok, err = A.MoveStack(0, 1, 9, 1)
		assert.equal(false, ok)
		assert.truthy(err)
		assert.equal(1, cleared, "nothing stays on the cursor")
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
	end

	-- Repairs: m.repairCost (nil: this vendor does not repair), m.guildRepair (nil: the guild does not pay;
```

and replace it with:

```lua
	end

	-- Stacking (week 9): every MoveStack is recorded in m.stackMoves = { { fromBag, fromSlot, toBag, toSlot } }.
	-- m.onMoveStack(fromBag, fromSlot, toBag, toSlot) decides what happens; by default what the game does at once:
	-- onto a partial stack of the same item (same link) as many as fit (the rest stays), else the two swap.
	-- m.moveFails = true: the call throws (the client refused it).
	m.stackMoves = {}
	m.onMoveStack = function(fb, fs, tb, ts)
		local f, t = m.slots[fb] and m.slots[fb][fs], m.slots[tb] and m.slots[tb][ts]
		if not f then
			return
		end
		local max = (m.items[f.itemID] or {}).maxStack or 1
		if t and t.itemID == f.itemID and t.link == f.link and t.count < max then
			local moved = math.min(f.count, max - t.count)
			t.count, f.count = t.count + moved, f.count - moved
			if f.count == 0 then
				m.slots[fb][fs] = nil
			end
		else
			m.slots[tb] = m.slots[tb] or {}
			m.slots[fb][fs], m.slots[tb][ts] = t, f
		end
	end
	function m.MoveStack(fb, fs, tb, ts)
		m.stackMoves[#m.stackMoves + 1] = { fb, fs, tb, ts }
		if m.moveFails then
			return false, "refused"
		end
		m.onMoveStack(fb, fs, tb, ts)
		return true
	end

	-- Repairs: m.repairCost (nil: this vendor does not repair), m.guildRepair (nil: the guild does not pay;
```

Create `spec/stacker_spec.lua`:

```lua
-- Week 9 (user pick 8): the stacker merges the partial stacks of an item, then moves the partial stack in
-- front of the item's full ones (for TSM posting), one move at a time, a short delay apart, out of combat,
-- never while an item is on the cursor or a slot it would touch is under the mouse (spec 4.2 rule 5), inside
-- one scope only (the bags, the character bank or the warband bank), and stops on combat or a closed window.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Locks.lua",
	"SwagBag/Engine/Mover.lua", "SwagBag/Engine/Stacker.lua",
}

describe("Stacker (week 9)", function()
	local SB, A, St, result, open, hovered
	local POTION, FLASK, JUNK = Fixtures.HEALING_POTION, Fixtures.FLASK, Fixtures.JUNK
	before_each(function()
		SB = Loader.New(FILES)
		A, St = SB.Adapter, SB.Stacker
		SB.Config.Init(nil, nil)
		Fixtures.Install(A) -- potions and flasks stack to 20, junk to 200
		A.SetBagSize(0, 8)
		result, open, hovered = nil, true, {}
	end)

	local function start(kind)
		return St.Start({ kind = kind or "bags", still = function() return open end,
			busy = function(bag, slot) return hovered[bag .. ":" .. slot] == true end,
			done = function(r) result = r end })
	end

	local function count(bag, slot)
		local s = A.GetSlot(bag, slot)
		return s and s.count or 0
	end

	-- Mutations: in St.Plan, take partial[#partial] as the target (merge onto the last one); or drop the
	-- order pass (return nil after the merges).
	it("merges an item's partial stacks one move at a time, then moves the partial in front of the full ones", function()
		A.Put(0, 1, POTION, 20)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, FLASK, 2) -- a lone partial already first: nothing to do
		A.Put(0, 4, POTION, 8)
		assert.truthy(start())
		assert.same({ { 0, 4, 0, 2 } }, A.stackMoves, "the last partial onto the first, at once")
		assert.same({ 20, 13, 2, 0 }, { count(0, 1), count(0, 2), count(0, 3), count(0, 4) })
		A.Advance(St.DELAY)
		assert.same({ 0, 2, 0, 1 }, A.stackMoves[2], "then the partial swaps with the first full stack")
		assert.same({ 13, 20, 2, 0 }, { count(0, 1), count(0, 2), count(0, 3), count(0, 4) })
		A.Advance(St.DELAY)
		assert.equal(2, #A.stackMoves)
		assert.same({ 1, 1, 0 }, { result.merged, result.ordered, result.kept })
		assert.is_nil(result.why)
		assert.falsy(St.Busy())
	end)

	-- Item safety: an item never goes to another bank type. Mutation: in read(), take every bag and bank kind
	-- (A.GetBagIDs("bags") .. "bank" .. "warband") instead of the run's own kind.
	it("never pairs stacks across scopes: the bags, the character bank and the warband bank are stacked apart", function()
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(6, 4)
		A.SetBagSize(12, 4)
		A.Put(0, 1, POTION, 5)
		A.Put(6, 1, POTION, 5)
		A.Put(12, 1, POTION, 5)
		assert.same({ false, "nothing" }, { start("bank") })
		A.Put(6, 2, POTION, 4)
		assert.truthy(start("bank"))
		A.Advance(St.DELAY * 3)
		assert.same({ { 6, 2, 6, 1 } }, A.stackMoves)
		assert.same({ 5, 9, 5 }, { count(0, 1), count(6, 1), count(12, 1) })
	end)

	-- Mutation: in stackable(), drop the leftAlone() check.
	it("leaves locked items, equipment-set items, single items and items not loaded yet where they are", function()
		SB.Locks.Toggle(POTION)
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3, { inSet = true })
		A.Put(0, 4, JUNK, 4)
		A.Put(0, 5, Fixtures.BOE_RING, 1)
		A.Put(0, 6, Fixtures.BOE_RING, 1)
		A.items[FLASK].pending = true
		A.Put(0, 7, FLASK, 1)
		A.Put(0, 8, FLASK, 1)
		assert.same({ false, "nothing" }, { start() })
		assert.same({}, A.stackMoves)
		SB.Locks.Toggle(POTION)
		assert.truthy(start(), "unlocked: the potions stack")
		assert.same({ { 0, 2, 0, 1 } }, A.stackMoves)
	end)

	-- P5. Mutation: in step, drop the run.job.busy check.
	it("waits while an item is on the cursor or a slot it would touch is under the mouse, then moves", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		hovered["0:1"] = true
		start()
		assert.same({}, A.stackMoves, "the target is under the mouse")
		A.Advance(St.RETRY)
		assert.same({}, A.stackMoves)
		hovered["0:1"] = nil
		A.cursor = { itemID = 1, link = "x" }
		A.Advance(St.RETRY)
		assert.same({}, A.stackMoves, "an item on the cursor holds every step")
		A.cursor = nil
		A.Advance(St.RETRY)
		assert.same({ { 0, 2, 0, 1 } }, A.stackMoves)
	end)

	-- Mutation: in step, `if run.waits <= St.MAX_WAITS` -> `if true` (the run never ends).
	it("a pair the mouse never leaves is left as it is; the run carries on with the next item", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3)
		A.Put(0, 4, JUNK, 4)
		hovered["0:2"] = true
		start()
		A.Advance(St.RETRY * (St.MAX_WAITS + 1))
		assert.same({ { 0, 4, 0, 3 } }, A.stackMoves, "the junk stacks; the potions stay")
		A.Advance(St.DELAY)
		assert.same({ 0, 0, 1 }, { result.merged - 1, result.ordered, result.kept })
		assert.same({ 5, 5 }, { count(0, 1), count(0, 2) })
	end)

	-- Mutations: in step, drop the A.InCombat() check; or drop the still() check.
	it("combat or a closed window stops the run before the next move; nothing is queued", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3)
		A.Put(0, 4, JUNK, 4)
		start()
		A.combat = true
		A.Advance(St.DELAY)
		assert.equal("combat", result.why)
		assert.equal(1, #A.stackMoves)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(5)
		assert.equal(1, #A.stackMoves, "nothing runs after combat")
		start()
		open = false
		A.Advance(St.DELAY)
		assert.equal("closed", result.why)
		assert.equal(2, #A.stackMoves)
	end)

	-- Mutations: in step, drop the pending wait (a locked slot is read at once); or drop the progressed() check.
	it("waits while the game holds a moved slot locked; a move that changes nothing stops the run", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3)
		A.Put(0, 4, JUNK, 4)
		local apply = A.onMoveStack
		A.onMoveStack = function(fb, fs, tb, ts)
			A.slots[fb][fs].isLocked, A.slots[tb][ts].isLocked = true, true -- the server has not answered yet
		end
		start()
		A.Advance(St.DELAY * 3)
		assert.equal(1, #A.stackMoves, "waiting for the server")
		A.slots[0][1].isLocked, A.slots[0][2].isLocked = false, false
		apply(0, 2, 0, 1)
		A.onMoveStack = function() end -- the next move changes nothing
		A.Advance(St.DELAY)
		assert.equal(2, #A.stackMoves)
		A.Advance(St.DELAY)
		assert.same({ "stuck", 1 }, { result.why, result.merged })
		assert.equal(2, #A.stackMoves, "no third try")
	end)

	-- Mutation: in St.Start, drop the SB.Mover.Busy() check; or in Mover.Start drop the Stacker check.
	it("refuses in combat, while the mover runs, and with nothing to do; the mover waits for a run too", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.combat = true
		assert.same({ false, "combat" }, { start() })
		A.combat = false
		SB.Mover.run = {}
		assert.same({ false, "busy" }, { start() })
		SB.Mover.run = nil
		A.onMoveStack = function() end
		assert.truthy(start())
		assert.same({ false, "busy" }, { start() }, "one run at a time")
		assert.same({ false, "busy" }, { SB.Mover.Start({ items = { { bag = 0, slot = 1 } }, act = A.SellItem }) })
		St.Stop("closed")
		assert.equal("closed", result.why)
		A.Clear(0, 2)
		assert.same({ false, "nothing" }, { start() })
	end)

	it("the result line says what was merged and moved first, and why a run stopped", function()
		local L = SB.L
		assert.equal(L.STACK_DONE:format(2, 1), St.ResultText({ merged = 2, ordered = 1, kept = 0 }))
		assert.equal(L.STACK_DONE:format(0, 1) .. " " .. L.STACK_KEPT:format(1),
			St.ResultText({ merged = 0, ordered = 1, kept = 1 }))
		assert.equal(L.STACK_STOP_COMBAT:format(1, 0), St.ResultText({ merged = 1, ordered = 0, kept = 0, why = "combat" }))
		assert.equal(L.STACK_STOP_CLOSED:format(0, 0), St.ResultText({ merged = 0, ordered = 0, kept = 0, why = "closed" }))
		assert.equal(L.STACK_STOP_STUCK:format(3, 0), St.ResultText({ merged = 3, ordered = 0, kept = 0, why = "stuck" }))
		assert.equal(L.STACK_STOP_STUCK:format(0, 0), St.ResultText({ merged = 0, ordered = 0, kept = 0, why = "error" }))
	end)
end)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1452 passed, 11 failed`. The failures, exactly:

- `spec/adapter_spec.lua :: Adapter.MoveStack (real adapter, stubbed globals) > picks up and drops with the game's own call, puts back what is left, never starts with an item held`
- `spec/adapter_spec.lua :: Adapter.MoveStack (real adapter, stubbed globals) > a throwing pickup is reported and the cursor is cleared`
- `spec/stacker_spec.lua :: Stacker (week 9) > merges an item's partial stacks one move at a time, then moves the partial in front of the full ones`
- `spec/stacker_spec.lua :: Stacker (week 9) > never pairs stacks across scopes: the bags, the character bank and the warband bank are stacked apart`
- `spec/stacker_spec.lua :: Stacker (week 9) > leaves locked items, equipment-set items, single items and items not loaded yet where they are`
- `spec/stacker_spec.lua :: Stacker (week 9) > waits while an item is on the cursor or a slot it would touch is under the mouse, then moves`
- `spec/stacker_spec.lua :: Stacker (week 9) > a pair the mouse never leaves is left as it is; the run carries on with the next item`
- `spec/stacker_spec.lua :: Stacker (week 9) > combat or a closed window stops the run before the next move; nothing is queued`
- `spec/stacker_spec.lua :: Stacker (week 9) > waits while the game holds a moved slot locked; a move that changes nothing stops the run`
- `spec/stacker_spec.lua :: Stacker (week 9) > refuses in combat, while the mover runs, and with nothing to do; the mover waits for a run too`
- `spec/stacker_spec.lua :: Stacker (week 9) > the result line says what was merged and moved first, and why a run stopped`

The whole of `spec/stacker_spec.lua` fails at Step 2 because `Engine/Stacker.lua` does not exist yet; the new mock functions change nothing for the existing tests.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "merges an item's partial stacks one move at a time, then moves the partial in front of the full ones": in `SwagBag/Engine/Stacker.lua`, `return { what = "merge", key = key, from = partial[#partial], to = partial[1] }` → `return { what = "merge", key = key, from = partial[1], to = partial[#partial] }`.
- "merges an item's partial stacks one move at a time, then moves the partial in front of the full ones": in `SwagBag/Engine/Stacker.lua`, `for _, key in ipairs(order) do ⏎ local g = groups[key] ⏎ local first = g.list[1]` → `for _, key in ipairs({}) do ⏎ local g = groups[key] ⏎ local first = g.list[1]`.
- "never pairs stacks across scopes: the bags, the character bank and the warband bank are stacked apart": in `SwagBag/Engine/Stacker.lua`, `for _, bag in ipairs(A.GetBagIDs(kind)) do` → `local all = A.GetBagIDs("bags") ⏎ for _, k in ipairs({ "bank", "warband" }) do ⏎ for _, b in ipairs(A.GetBagIDs(k)) do ⏎ all[#all + 1] = b ⏎ end ⏎ end ⏎ for _, bag in ipairs(all) do`.
- "leaves locked items, equipment-set items, single items and items not loaded yet where they are": in `SwagBag/Engine/Stacker.lua`, `if type(s.link) ~= "string" or A.IsSecret(s.link) or leftAlone(s) then` → `if type(s.link) ~= "string" or A.IsSecret(s.link) then`.
- "waits while an item is on the cursor or a slot it would touch is under the mouse, then moves": in `SwagBag/Engine/Stacker.lua`, `if busy and (busy(nextMove.from.bag, nextMove.from.slot) or busy(nextMove.to.bag, nextMove.to.slot)) then` → `if false then`.
- "a pair the mouse never leaves is left as it is; the run carries on with the next item": in `SwagBag/Engine/Stacker.lua`, `if run.waits <= St.MAX_WAITS then` → `if true then`.
- "combat or a closed window stops the run before the next move; nothing is queued": in `SwagBag/Engine/Stacker.lua`, `if A.InCombat() then ⏎ return finish(run, "combat") ⏎ end` → ∅.
- "combat or a closed window stops the run before the next move; nothing is queued": in `SwagBag/Engine/Stacker.lua`, `if run.job.still and not run.job.still() then ⏎ return finish(run, "closed") ⏎ end` → ∅.
- "waits while the game holds a moved slot locked; a move that changes nothing stops the run": in `SwagBag/Engine/Stacker.lua`, `if lockedSlot(m) and run.pending < St.MAX_PENDING then` → `if false then`.
- "waits while the game holds a moved slot locked; a move that changes nothing stops the run": in `SwagBag/Engine/Stacker.lua`, `if not progressed(m) then` → `if false then`.
- "refuses in combat, while the mover runs, and with nothing to do; the mover waits for a run too": in `SwagBag/Engine/Stacker.lua`, `if St.run or (SB.Mover and SB.Mover.Busy()) then` → `if St.run then`.
- "refuses in combat, while the mover runs, and with nothing to do; the mover waits for a run too": in `SwagBag/Engine/Mover.lua`, `if Mover.run or (SB.Stacker and SB.Stacker.Busy()) then` → `if Mover.run then`.
- "picks up and drops with the game's own call, puts back what is left, never starts with an item held": in `SwagBag/Core/Adapter.lua`, `if A.CursorItem() ~= nil then ⏎ pcall(C_Container.PickupContainerItem, fromBag, fromSlot) ⏎ end` → ∅.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
	return pcall(C_Container.SortBags)
```

and replace it with:

```lua
	return pcall(C_Container.SortBags)
end

-- Week 9 (user pick 8, Engine/Stacker.lua): one stack onto another, as a player does it: a click on the stack
-- (C_Container.PickupContainerItem) and a click on the target. The game merges as many as fit onto a stack of
-- the same item, or swaps the two; what is left on the cursor goes back where it came from, so nothing ever
-- stays held. Never starts while the player holds an item. Out of combat only (the stacker checks). ok, err.
function A.MoveStack(fromBag, fromSlot, toBag, toSlot)
	if not (C_Container and C_Container.PickupContainerItem) or A.CursorItem() ~= nil then
		return false
	end
	local ok, err = pcall(C_Container.PickupContainerItem, fromBag, fromSlot)
	if ok then
		ok, err = pcall(C_Container.PickupContainerItem, toBag, toSlot)
	end
	if A.CursorItem() ~= nil then
		pcall(C_Container.PickupContainerItem, fromBag, fromSlot)
	end
	if A.CursorItem() ~= nil then
		A.ClearCursor()
	end
	return ok, err
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "C_Container.UseContainerItem", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "C_Container.UseContainerItem", window = "bags", required = false },
	{ path = "C_Container.PickupContainerItem", window = "bags", required = false },
```

In `SwagBag/Core/Init.lua`, find:

```lua
SB.VERSION = "0.8.0"
```

and replace it with:

```lua
SB.VERSION = "0.9.0"
```

In `SwagBag/Engine/Mover.lua`, find:

```lua
	if Mover.run then
```

and replace it with:

```lua
	if Mover.run or (SB.Stacker and SB.Stacker.Busy()) then -- week 9: one run moves items at a time
```

Create `SwagBag/Engine/Stacker.lua`:

```lua
-- SwagBag stacker (week 9, user pick 8): "partial stacks first", for TSM posting. Blizzard's own sort
-- (Adapter.SortBags / SortBank) takes no options, so this is SwagBag's own run, one move at a time:
--   1. merge: while an item has two partial stacks, the last one goes onto the first (Adapter.MoveStack: a
--      click on the stack and a click on the target, as a player does it; what does not fit stays);
--   2. order: an item's one partial stack swaps with the item's first full stack, so it comes first.
-- Nothing else moves. Only one scope at a time: the bags (bags and reagent bag), the character bank or the
-- warband bank (Adapter.GetBagIDs(kind)); a move only ever lands on a stack of the same item in the same
-- scope, so an item never changes bank type. Left as they are: items the user locked (Engine/Locks.lua),
-- equipment-set items, items that do not stack, items whose data has not loaded, and a secret link.
--   Stacker.Start(job) -> true | false, why   why: "busy" (this or the mover runs) | "combat" | "nothing"
--     job = { kind = "bags" | "bank" | "warband",
--             still = fn() -> bool         false once the window or the bank closed: the run stops
--             busy = fn(bag, slot) -> bool  the slot's button (or its list row) is under the mouse
--             done = fn(result) }          result = { merged = n, ordered = n, kept = n,
--                                           why = nil | "combat" | "closed" | "stuck" | "error" }
--   Stacker.Busy() -> bool;  Stacker.Stop(why);  Stacker.Plan(kind, skip) -> the next move | { wait } | nil
--   Stacker.ResultText(result) -> the one chat line for a finished run
-- Every step: out of combat only (combat stops the run, nothing is queued; P5), only while still(), never
-- while an item is on the cursor (it waits RETRY, however long), and a pair whose slot is under the mouse
-- waits RETRY up to MAX_WAITS times, then that item is left as it is. After a move the next step waits while
-- the game holds either slot locked (the server has not answered, up to MAX_PENDING), then checks the move
-- did what it should; one that changed nothing stops the run ("stuck"). Each step plans again from the slots
-- as they are, so an item used or moved by hand meanwhile is simply read as it is now. No OnUpdate.
local _, SB = ...

local L = SB.L
local St = { DELAY = 0.2, RETRY = 0.3, MAX_WAITS = 20, MAX_PENDING = 10, run = nil }
SB.Stacker = St

function St.Busy()
	return St.run ~= nil
end

-- The slot must stay where it is: locked by the user, or part of an equipment set.
local function leftAlone(s)
	return (SB.Locks ~= nil and SB.Locks.Has(s.itemID)) or SB.Adapter.InEquipmentSet(s.bag, s.slot)
end

-- How many of the item make a full stack; nil when it does not stack or must stay.
local function stackable(s, maxOf)
	local A = SB.Adapter
	if type(s.link) ~= "string" or A.IsSecret(s.link) or leftAlone(s) then
		return nil
	end
	local max = maxOf[s.itemID]
	if max == nil then
		local info = A.GetItemInfo(s.itemID)
		max = info and type(info.maxStack) == "number" and not A.IsSecret(info.maxStack) and info.maxStack or false
		maxOf[s.itemID] = max
	end
	return max and max > 1 and max or nil
end

-- The stackable items of a scope, grouped by link, in slot order (bag IDs, then slots).
local function read(kind, skip, maxOf)
	local A = SB.Adapter
	local groups, order, pending = {}, {}, false
	for _, bag in ipairs(A.GetBagIDs(kind)) do
		for slot = 1, A.NumSlots(bag) do
			local s = A.GetSlot(bag, slot)
			local max = s and stackable(s, maxOf)
			if max and not skip[s.link] then
				pending = pending or s.isLocked
				local g = groups[s.link]
				if not g then
					g = { max = max, list = {} }
					groups[s.link] = g
					order[#order + 1] = s.link
				end
				g.list[#g.list + 1] = s
			end
		end
	end
	return groups, order, pending
end

function St.Plan(kind, skip, maxOf)
	local groups, order, pending = read(kind, skip or {}, maxOf or {})
	if pending then
		return { wait = true } -- the game still holds a stack locked: read again shortly
	end
	for _, key in ipairs(order) do
		local g, partial = groups[key], {}
		for _, s in ipairs(g.list) do
			if s.count < g.max then
				partial[#partial + 1] = s
			end
		end
		if #partial >= 2 then
			return { what = "merge", key = key, from = partial[#partial], to = partial[1] }
		end
	end
	for _, key in ipairs(order) do
		local g = groups[key]
		local first = g.list[1]
		if first.count >= g.max then
			for _, s in ipairs(g.list) do
				if s.count < g.max then
					return { what = "order", key = key, from = s, to = first }
				end
			end
		end
	end
	return nil
end

local function finish(run, why)
	if St.run ~= run then
		return
	end
	St.run = nil
	run.result.why = why
	if run.job.done then
		SB.ErrorTrap.Run("stacker.done", "none", run.job.done, run.result)
	end
end

local step

local function later(run, seconds)
	SB.Adapter.After(seconds, SB.ErrorTrap.Guard("stacker.step", function()
		step(run)
	end, "none"))
end

-- Did the move do what it should? A merge: the target holds more of the item. An order: the target (the
-- item's first slot) now holds the partial stack's count.
local function progressed(m)
	local t = SB.Adapter.GetSlot(m.to.bag, m.to.slot)
	if not t or t.link ~= m.key then
		return false
	end
	if m.what == "merge" then
		return t.count > m.to.count
	end
	return t.count == m.from.count
end

local function lockedSlot(m)
	local A = SB.Adapter
	local t, f = A.GetSlot(m.to.bag, m.to.slot), A.GetSlot(m.from.bag, m.from.slot)
	return (t ~= nil and t.isLocked) or (f ~= nil and f.isLocked)
end

step = function(run)
	if St.run ~= run then
		return
	end
	local A = SB.Adapter
	local m = run.sent
	if m then
		if lockedSlot(m) and run.pending < St.MAX_PENDING then
			run.pending = run.pending + 1
			return later(run, St.DELAY)
		end
		run.sent, run.pending = nil, 0
		if not progressed(m) then
			return finish(run, "stuck")
		end
		if m.what == "merge" then
			run.result.merged = run.result.merged + 1
		else
			run.result.ordered = run.result.ordered + 1
		end
	end
	if run.job.still and not run.job.still() then
		return finish(run, "closed")
	end
	if A.InCombat() then
		return finish(run, "combat")
	end
	if A.CursorItem() ~= nil then
		return later(run, St.RETRY) -- the user is moving an item by hand: wait, however long it takes
	end
	local nextMove = St.Plan(run.kind, run.skip, run.maxOf)
	if not nextMove then
		return finish(run, nil)
	end
	if nextMove.wait then
		run.pending = run.pending + 1
		if run.pending > St.MAX_PENDING then
			return finish(run, "stuck")
		end
		return later(run, St.DELAY)
	end
	run.pending = 0
	local busy = run.job.busy
	if busy and (busy(nextMove.from.bag, nextMove.from.slot) or busy(nextMove.to.bag, nextMove.to.slot)) then
		run.waits = run.waits + 1
		if run.waits <= St.MAX_WAITS then
			return later(run, St.RETRY)
		end
		run.waits = 0
		run.skip[nextMove.key] = true -- the mouse never left it: this item stays as it is
		run.result.kept = run.result.kept + 1
		return step(run)
	end
	run.waits = 0
	local ok, err = A.MoveStack(nextMove.from.bag, nextMove.from.slot, nextMove.to.bag, nextMove.to.slot)
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("stacker.move", "none", tostring(err), A.Stack())
		end
		return finish(run, "error")
	end
	run.sent = nextMove
	return later(run, St.DELAY)
end

function St.Start(job)
	if St.run or (SB.Mover and SB.Mover.Busy()) then
		return false, "busy"
	end
	if SB.Adapter.InCombat() then
		return false, "combat"
	end
	local maxOf = {}
	if not St.Plan(job.kind, {}, maxOf) then
		return false, "nothing"
	end
	local run = { job = job, kind = job.kind, skip = {}, maxOf = maxOf, waits = 0, pending = 0,
		result = { merged = 0, ordered = 0, kept = 0 } }
	St.run = run
	step(run)
	return true
end

function St.Stop(why)
	if St.run then
		finish(St.run, why or "closed")
	end
end

function St.ResultText(r)
	if r.why == "combat" then
		return L.STACK_STOP_COMBAT:format(r.merged, r.ordered)
	elseif r.why == "closed" then
		return L.STACK_STOP_CLOSED:format(r.merged, r.ordered)
	elseif r.why ~= nil then
		return L.STACK_STOP_STUCK:format(r.merged, r.ordered)
	end
	local text = L.STACK_DONE:format(r.merged, r.ordered)
	if r.kept > 0 then
		text = text .. " " .. L.STACK_KEPT:format(r.kept)
	end
	return text
end
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SET_PROFILES_DEFAULTS = "Defaults"
```

and replace it with:

```lua
L.SET_PROFILES_DEFAULTS = "Defaults"

-- Stacking (week 9, user pick 8): Engine/Stacker.lua
L.STACK_DONE = "Stacking done. Stacks merged: %d. Partial stacks moved first: %d."
L.STACK_KEPT = "Left alone under your mouse: %d."
L.STACK_STOP_COMBAT = "Stacking stopped: combat started (stacks merged: %d, moved first: %d). Press Sort again after combat."
L.STACK_STOP_CLOSED = "Stacking stopped: the window closed (stacks merged: %d, moved first: %d)."
L.STACK_STOP_STUCK = "Stacking stopped: an item did not move as expected (stacks merged: %d, moved first: %d). Nothing"
	.. " was lost; press Sort to try again."
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
## Version: 0.8.0
```

and replace it with:

```text
## Version: 0.9.0
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
Engine/Mover.lua
```

and replace it with:

```text
Engine/Mover.lua
Engine/Stacker.lua
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1463 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (73 files)`, `1463 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Core/Init.lua \
	SwagBag/Engine/Mover.lua \
	SwagBag/Engine/Stacker.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	spec/adapter_spec.lua \
	spec/mock_adapter.lua \
	spec/stacker_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 9 Task 1: the stacker merges partial stacks and puts the partial stack first; v0.9.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 2: The Sort buttons can stack: the sort.mode setting, /swagbag sort, Settings

The setting `sort.mode` (D1): `"blizzard"` (the default: nothing changes for anyone who does not choose) or `"stacks"`. With `"stacks"` the bags window's Sort button and the bank window's "Sort bank" / "Sort warband" buttons start the stacker for their own scope (`"bags"`, `"bank"`, `"warband"`: D5) instead of Blizzard's sort. The click answers in the title (`Stacking...`, or why it cannot start), the run's outcome is one chat line, and the window regroups when the run is done, held by P5 like any layout (D8). The run stops when its window closes (the bags window; the bank visit). The stacker's P5 check is the window's own: the bags' `ButtonBusy` and the bank's new `GroupView` `v.Busy` (in the list a row under the mouse holds its button too). `/swagbag sort [stacks|blizzard]` and a Settings > Bags row ("The Sort buttons": Blizzard's sort first, then Partial stacks first) set it; a share string carries it.

**Files:**
- Modify: `SwagBag/Core/Config.lua` (`sort.mode`), `SwagBag/Engine/Stacker.lua` (`/swagbag sort`), `SwagBag/UI/BagsWindow.lua`, `SwagBag/UI/BankWindow.lua`, `SwagBag/UI/GroupView.lua` (`v.Busy`), `SwagBag/UI/SettingsPages.lua`, `SwagBag/Engine/Profiles.lua`, `SwagBag/Locale/enUS.lua`
- Test: `spec/stacker_spec.lua`, `spec/bagswindow_sections_spec.lua`, `spec/bankwindow_groups_spec.lua`, `spec/settings_spec.lua`, `spec/profiles_spec.lua`

**Interfaces:**
- Consumes: `Stacker.Start/ResultText` (Task 1), the bags window's `buttonBusy`, `W.Flash`, `W.RequestLayout`, `BW.Flash`, `BW.interaction`, `BW.view.RequestLayout`, `L.MOVER_BUSY`, `L.SORT_AFTER_COMBAT`.
- Produces: setting `sort.mode` (`"blizzard"` | `"stacks"`, Profiles `VALID` and `LABELS`); `/swagbag sort`; GroupView `v.Busy(bag, slot)`; `L.STACK_STARTED`, `L.STACK_NOTHING`, `L.HELP_SORT`, `L.SORT_MODE_*`, `L.SET_SORT`, `L.SET_SORT_BLIZZARD`, `L.SET_SORT_STACKS`, `L.SET_SORT_TIP`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua`, find:

```lua
		assert.equal(false, W.sortPending)
	end)
```

and replace it with:

```lua
		assert.equal(false, W.sortPending)
	end)

	-- Week 9 (user pick 8). Mutation: in W.Sort, drop the stackSort() branch (Blizzard's sort always runs).
	it("with sort stacks the Sort button stacks instead, says so, reports in chat and regroups when done", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Stacker.lua")
		SB.Config.Set("sort.mode", "stacks")
		A.Put(0, 7, Fixtures.HEALING_POTION, 3)
		W.Open()
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(0, A.sorts, "Blizzard's sort is not called")
		assert.same({ { 0, 7, 0, 1 } }, A.stackMoves)
		assert.equal(SB.L.STACK_STARTED, W.frame.title.text)
		A.Advance(SB.Stacker.DELAY)
		assert.same({ SB.L.STACK_DONE:format(1, 0) }, A.Lines())
		assert.equal("sort", W.stats.lastLayoutReason)
		W.sortButton.scripts.OnClick(W.sortButton)
		assert.equal(SB.L.STACK_NOTHING, W.frame.title.text, "nothing left to stack: said in the title")
		assert.equal(1, #A.stackMoves)
	end)

	-- Week 9, P5. Mutation: in stackSort, pass no busy function to the stacker.
	it("stacking waits while the slot it would touch is under the mouse", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Stacker.lua")
		SB.Config.Set("sort.mode", "stacks")
		A.Put(0, 7, Fixtures.HEALING_POTION, 3)
		W.Open()
		B.Get(0, 1).mouseOver = true
		W.sortButton.scripts.OnClick(W.sortButton)
		A.Advance(SB.Stacker.RETRY * 2)
		assert.same({}, A.stackMoves)
		B.Get(0, 1).mouseOver = false
		A.Advance(SB.Stacker.RETRY)
		assert.same({ { 0, 7, 0, 1 } }, A.stackMoves)
	end)
```

In `spec/bankwindow_groups_spec.lua`, find:

```lua
		assert.same({ "bank", "warband" }, A.bankSorts)
```

and replace it with:

```lua
		assert.same({ "bank", "warband" }, A.bankSorts)
	end)

	-- Week 9 (user pick 8): item safety. Mutations: in BW.Sort, drop the stackSort(kind) branch; or start the
	-- stacker with kind "warband" for either button.
	it("with sort stacks, Sort bank stacks the character bank only; the warband bank is never touched", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Stacker.lua")
		SB.Config.Set("sort.mode", "stacks")
		A.Put(6, 3, Fixtures.HEALING_POTION, 4)
		A.Put(12, 3, Fixtures.ORE, 5)
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		assert.same({}, A.bankSorts)
		assert.same({ { 6, 3, 6, 1 } }, A.stackMoves)
		assert.equal(SB.L.STACK_STARTED, BW.frame.title.text)
		A.Advance(SB.Stacker.DELAY)
		assert.same({ SB.L.STACK_DONE:format(1, 0) }, A.Lines())
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		Fake.Fire(BW.sortWarbandButton, "OnClick")
		A.Advance(SB.Stacker.DELAY)
		assert.same({ 6, 3, 6, 1 }, A.stackMoves[1])
		assert.same({ 12, 3, 12, 1 }, A.stackMoves[2], "the warband bank's own ore, in the warband bank")
		assert.same({ 9, 15 }, { A.GetSlot(6, 1).count, A.GetSlot(12, 1).count })
	end)

	-- Week 9: the bank closing stops a stacking run. Mutation: in stackSort's still(), return true.
	it("closing the bank stops stacking before the next move", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Stacker.lua")
		SB.Config.Set("sort.mode", "stacks")
		A.Put(6, 3, Fixtures.HEALING_POTION, 4)
		A.Put(6, 4, Fixtures.HERB, 5)
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		A.Advance(SB.Stacker.DELAY)
		assert.equal(1, #A.stackMoves)
		assert.same({ SB.L.STACK_STOP_CLOSED:format(1, 0) }, A.Lines())
```

In `spec/profiles_spec.lua`, find:

```lua
		assert.equal("list", data.settings["bank.view"])
```

and replace it with:

```lua
		assert.equal("list", data.settings["bank.view"])
	end)

	-- Week 9 (user pick 8). Mutation: drop `["sort.mode"] = ...` from VALID (any word would come in).
	it("the Sort button's mode travels in a share string; a word it may not hold is refused", function()
		C.Set("sort.mode", "stacks")
		local data = assert(Pr.Parse(Pr.Export(false)))
		assert.equal("stacks", data.settings["sort.mode"])
		assert.is_nil(Pr.Parse("SWAGBAG:1:s.sort.mode=sshuffle"))
```

In `spec/settings_spec.lua`, find:

```lua
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
```

and replace it with:

```lua
	end)

	-- Week 9 (user pick 8), P1. Mutation: in the sort row's apply, run "sort stacks" whatever the choice.
	it("bags page: the Sort button row, Blizzard's sort first and selected; each choice runs /swagbag sort", function()
		SB.Slash.Register("sort", "test", function(arg)
			ran[#ran + 1] = "sort " .. arg
			return "ran sort " .. arg
		end)
		SW.Show("bags")
		assert.truthy(SW.selected[button(SB.L.SET_SORT_BLIZZARD)])
		click(SB.L.SET_SORT_STACKS)
		click(SB.L.SET_SORT_BLIZZARD)
		assert.same({ "sort stacks", "sort blizzard" }, ran)
		assert.equal("ran sort blizzard", SW.lastStatus)
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
```

In `spec/stacker_spec.lua`, find:

```lua
	end)

	it("the result line says what was merged and moved first, and why a run stopped", function()
```

and replace it with:

```lua
	end)

	-- Mutation: in the sort command, set sort.mode without checking Config.Set's answer.
	it("/swagbag sort says the Sort button's mode, sets stacks or blizzard, and refuses while read-only", function()
		local L = SB.L
		assert.same({ true, L.SORT_MODE_STATE:format(L.SORT_MODE_BLIZZARD) }, { SB.Slash.Run("sort") })
		assert.same({ true, L.SORT_MODE_STACKS_ON }, { SB.Slash.Run("sort stacks") })
		assert.equal("stacks", SB.Config.Get("sort.mode"))
		assert.same({ true, L.SORT_MODE_STATE:format(L.SORT_MODE_STACKS) }, { SB.Slash.Run("sort") })
		assert.same({ true, L.SORT_MODE_BLIZZARD_ON }, { SB.Slash.Run("SORT Blizzard") })
		assert.same({ true, L.SORT_MODE_USAGE }, { SB.Slash.Run("sort shuffle") })
		SB.Config.readOnly = true
		assert.same({ true, L.SETTINGS_READONLY }, { SB.Slash.Run("sort stacks") })
		assert.equal("blizzard", SB.Config.Get("sort.mode"))
	end)

	it("the result line says what was merged and moved first, and why a run stopped", function()
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1463 passed, 7 failed`. The failures, exactly:

- `spec/bagswindow_sections_spec.lua :: BagsWindow category view > with sort stacks the Sort button stacks instead, says so, reports in chat and regroups when done`
- `spec/bagswindow_sections_spec.lua :: BagsWindow category view > stacking waits while the slot it would touch is under the mouse`
- `spec/bankwindow_groups_spec.lua :: BankWindow contents > with sort stacks, Sort bank stacks the character bank only; the warband bank is never touched`
- `spec/bankwindow_groups_spec.lua :: BankWindow contents > closing the bank stops stacking before the next move`
- `spec/profiles_spec.lua :: Profiles (week 7) > the Sort button's mode travels in a share string; a word it may not hold is refused`
- `spec/settings_spec.lua :: Settings window > bags page: the Sort button row, Blizzard's sort first and selected; each choice runs /swagbag sort`
- `spec/stacker_spec.lua :: Stacker (week 9) > /swagbag sort says the Sort button's mode, sets stacks or blizzard, and refuses while read-only`

The new bags and bank tests load `Engine/Stacker.lua` themselves (the window specs' file lists stay as they were), so no other test changes at Step 2.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "the Sort button's mode travels in a share string; a word it may not hold is refused": in `SwagBag/Engine/Profiles.lua`, `, ["sort.mode"] = words("blizzard", "stacks"), ⏎ }` → `, ⏎ }`.
- "bags page: the Sort button row, Blizzard's sort first and selected; each choice runs /swagbag sort": in `SwagBag/UI/SettingsPages.lua`, `return run("sort " .. v)` → `return run("sort stacks")`.
- "/swagbag sort says the Sort button's mode, sets stacks or blizzard, and refuses while read-only": in `SwagBag/Engine/Stacker.lua`, `if not SB.Config.Set("sort.mode", arg) then ⏎ return L.SETTINGS_READONLY ⏎ end` → `SB.Config.Set("sort.mode", arg)`.
- "with sort stacks the Sort button stacks instead, says so, reports in chat and regroups when done": in `SwagBag/UI/BagsWindow.lua`, `if SB.Stacker and SB.Config.Get("sort.mode") == "stacks" then ⏎ return stackSort() ⏎ end` → ∅.
- "stacking waits while the slot it would touch is under the mouse": in `SwagBag/UI/BagsWindow.lua`, `{ kind = "bags", busy = buttonBusy, still` → `{ kind = "bags", still`.
- "with sort stacks, Sort bank stacks the character bank only; the warband bank is never touched": in `SwagBag/UI/BankWindow.lua`, `if SB.Stacker and SB.Config.Get("sort.mode") == "stacks" then ⏎ return stackSort(kind) ⏎ end` → ∅.
- "with sort stacks, Sort bank stacks the character bank only; the warband bank is never touched": in `SwagBag/UI/BankWindow.lua`, `SB.Stacker.Start({ kind = kind, busy` → `SB.Stacker.Start({ kind = "warband", busy`.
- "closing the bank stops stacking before the next move": in `SwagBag/UI/BankWindow.lua`, `return BW.interaction and frame:IsShown()` → `return true`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Config.lua`, find:

```lua
		vendor = { autoSell = true, repair = "own" },
```

and replace it with:

```lua
		vendor = { autoSell = true, repair = "own" },
		-- mode: what the Sort buttons (bags, bank, warband) do (week 9, user pick 8): "blizzard" (Blizzard's own
		-- sort, the default) | "stacks" (SwagBag merges partial stacks, then puts each item's partial stack in front
		-- of its full ones, for TSM posting; Engine/Stacker.lua).
		sort = { mode = "blizzard" },
```

In `SwagBag/Engine/Profiles.lua` (edit 1 of 2), find:

```lua
	["tooltip.counts"] = words("auto", "on", "off"),
```

and replace it with:

```lua
	["tooltip.counts"] = words("auto", "on", "off"), ["sort.mode"] = words("blizzard", "stacks"),
```

In `SwagBag/Engine/Profiles.lua` (edit 2 of 2), find:

```lua
	["consumables.warn"] = "SET_WATCH_WARN", ["theme.name"] = "SET_LOOK", ["tooltip.counts"] = "SET_TIP",
```

and replace it with:

```lua
	["consumables.warn"] = "SET_WATCH_WARN", ["theme.name"] = "SET_LOOK", ["tooltip.counts"] = "SET_TIP",
	["sort.mode"] = "SET_SORT",
```

In `SwagBag/Engine/Stacker.lua`, find:

```lua
end

function St.ResultText(r)
```

and replace it with:

```lua
end

-- /swagbag sort                    what the Sort buttons do
-- /swagbag sort stacks|blizzard    partial stacks first (SwagBag's stacker) | Blizzard's own sort
SB.Slash.Register("sort", L.HELP_SORT, function(arg)
	arg = (arg or ""):lower()
	if arg == "" then
		return L.SORT_MODE_STATE:format(SB.Config.Get("sort.mode") == "stacks" and L.SORT_MODE_STACKS or L.SORT_MODE_BLIZZARD)
	elseif arg ~= "stacks" and arg ~= "blizzard" then
		return L.SORT_MODE_USAGE
	end
	if not SB.Config.Set("sort.mode", arg) then
		return L.SETTINGS_READONLY
	end
	return arg == "stacks" and L.SORT_MODE_STACKS_ON or L.SORT_MODE_BLIZZARD_ON
end)

function St.ResultText(r)
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
	.. " was lost; press Sort to try again."
```

and replace it with:

```lua
	.. " was lost; press Sort to try again."
L.STACK_STARTED = "Stacking..."
L.STACK_NOTHING = "Nothing to stack: each item has at most one partial stack, and it is already first."
L.HELP_SORT = "sort [stacks|blizzard]: what Sort does: partial stacks first (for TSM posting), or Blizzard's sort"
L.SORT_MODE_BLIZZARD = "Blizzard's sort"
L.SORT_MODE_STACKS = "partial stacks first (SwagBag merges partial stacks, then puts each item's partial stack in front)"
L.SORT_MODE_STATE = "Sort buttons: %s. Type /swagbag sort stacks or sort blizzard."
L.SORT_MODE_USAGE = "Use /swagbag sort, sort stacks, or sort blizzard."
L.SORT_MODE_STACKS_ON = "Sort now merges partial stacks, then puts each item's partial stack in front of its full ones."
	.. " Nothing else moves."
L.SORT_MODE_BLIZZARD_ON = "Sort now runs Blizzard's own sort."
L.SET_SORT = "The Sort buttons"
L.SET_SORT_BLIZZARD = "Blizzard's sort"
L.SET_SORT_STACKS = "Partial stacks first"
L.SET_SORT_TIP = "Blizzard's sort: the game's own sort. Partial stacks first: SwagBag merges the partial stacks of each"
	.. " item, then moves each item's one partial stack in front of its full ones (handy for TSM posting); nothing"
	.. " else moves, and locked or equipment-set items stay put. Bags, bank and warband bank are stacked apart."
```

In `SwagBag/UI/BagsWindow.lua` (edit 1 of 2), find:

```lua
-- changes nothing, the timeout below still clears sortPending (W3).
```

and replace it with:

```lua
-- changes nothing, the timeout below still clears sortPending (W3).
-- Week 9 (user pick 8): with sort.mode "stacks" the Sort button runs SwagBag's stacker (Engine/Stacker.lua)
-- instead of Blizzard's sort: the click answers in the title, the run's result is one chat line, and the
-- window regroups when it is done (held while the mouse is over the items, rule 5).
local function stackSort()
	local ok, why = SB.Stacker.Start({ kind = "bags", busy = buttonBusy, still = function()
		return frame:IsShown()
	end, done = function(result)
		SB.Print(SB.Stacker.ResultText(result))
		if frame:IsShown() then
			W.RequestLayout("sort")
		end
	end })
	W.Flash(ok and L.STACK_STARTED or (why == "busy" and L.MOVER_BUSY) or L.STACK_NOTHING)
	return ok
end

```

In `SwagBag/UI/BagsWindow.lua` (edit 2 of 2), find:

```lua
		W.Flash(L.SORT_AFTER_COMBAT)
		return false
	end
```

and replace it with:

```lua
		W.Flash(L.SORT_AFTER_COMBAT)
		return false
	end
	if SB.Stacker and SB.Config.Get("sort.mode") == "stacks" then
		return stackSort()
	end
```

In `SwagBag/UI/BankWindow.lua` (edit 1 of 2), find:

```lua
-- waiting after SORT_TIMEOUT.
```

and replace it with:

```lua
-- waiting after SORT_TIMEOUT.
-- Week 9 (user pick 8): with sort.mode "stacks" a Sort button runs SwagBag's stacker for its own bank type
-- only (kind "bank" or "warband": an item never changes bank type), as the bags window does.
local function stackSort(kind)
	local ok, why = SB.Stacker.Start({ kind = kind, busy = BW.view.Busy, still = function()
		return BW.interaction and frame:IsShown()
	end, done = function(result)
		SB.Print(SB.Stacker.ResultText(result))
		if frame:IsShown() and BW.view.IsOpen() then
			BW.view.RequestLayout("sort")
		end
	end })
	BW.Flash(ok and L.STACK_STARTED or (why == "busy" and L.MOVER_BUSY) or L.STACK_NOTHING)
	return ok
end

```

In `SwagBag/UI/BankWindow.lua` (edit 2 of 2), find:

```lua
		BW.Flash(L.SORT_AFTER_COMBAT)
		return false
	end
```

and replace it with:

```lua
		BW.Flash(L.SORT_AFTER_COMBAT)
		return false
	end
	if SB.Stacker and SB.Config.Get("sort.mode") == "stacks" then
		return stackSort(kind)
	end
```

In `SwagBag/UI/GroupView.lua`, find:

```lua
	end

	local function anyBusy(keys)
```

and replace it with:

```lua
	end

	-- Week 9: the stacker's P5 check for one slot (Engine/Stacker.lua): an item on the cursor, or the slot's
	-- button (in a list, its row) under the mouse.
	function v.Busy(bag, slot)
		return (busyCheck())(bag, slot)
	end

	local function anyBusy(keys)
```

In `SwagBag/UI/SettingsPages.lua`, find:

```lua
		onOff(L.SET_TITLE_ILVL, "bags.showIlvl", "overlays title"),
```

and replace it with:

```lua
		onOff(L.SET_TITLE_ILVL, "bags.showIlvl", "overlays title"),
		-- Week 9 (user pick 8): what Sort does; every click runs /swagbag sort.
		{ kind = "choice", label = L.SET_SORT, tip = L.SET_SORT_TIP, width = 150, get = get("sort.mode"),
			choices = { { value = "blizzard", text = L.SET_SORT_BLIZZARD }, { value = "stacks", text = L.SET_SORT_STACKS } },
			apply = function(v)
				return run("sort " .. v)
			end },
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1470 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (73 files)`, `1470 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Config.lua \
	SwagBag/Engine/Profiles.lua \
	SwagBag/Engine/Stacker.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/BagsWindow.lua \
	SwagBag/UI/BankWindow.lua \
	SwagBag/UI/GroupView.lua \
	SwagBag/UI/SettingsPages.lua \
	spec/bagswindow_sections_spec.lua \
	spec/bankwindow_groups_spec.lua \
	spec/profiles_spec.lua \
	spec/settings_spec.lua \
	spec/stacker_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 9 Task 2: the Sort buttons can stack partial stacks first (sort.mode, /swagbag sort, Settings)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 3: TSM as a price source, and the price source choice

The user's second pick (pick 10). `Providers/TSM.lua` registers a "TSM" price provider (priority 5: below Auctionator's 10, above the vendor's 0) that answers while TradeSkillMaster's public addon API is loaded, through the Adapter only: `TSM_API.ToItemString(link)` then `TSM_API.GetCustomPriceValue(priceString, itemString)`, every read pcall'd (TSM_API raises an error on a name it does not have), a secret link or a secret, negative or non-number answer is no price, and only four price strings are ever asked (D11). `Engine/Prices.lua` learns the choice `prices.source` (D10): `"auto"` (the default: Auctionator, else TSM, else the vendor, which is exactly the priority order), `"auctionator"`, `"tsm"` or `"vendor"` (that one, and the vendor for what it has no price for or while it is not loaded). Its cache works as before (per link, 10 minutes); TSM has no "prices changed" callback in that API, so a change of either setting also drops it and refreshes the open windows' totals once (D12). Header totals, the list's Value column, the gold glow and the vendor's "gray BoE worth more than twice at auction" protection all ask `Prices.Value`, so they all follow the choice (D13). `/swagbag price` and two rows on Settings > Bank & guild set it; `/swagbag report` names TSM's price string. `scripts/check.sh` now also fails on `TSM_API` or `LibStub` outside the Adapter, comments included.

**Files:**
- Create: `SwagBag/Providers/TSM.lua`
- Modify: `SwagBag/Core/Adapter.lua` (`A.TSM_PRICES`, `A.TSMAvailable`, `A.TSMPrice`), `SwagBag/Engine/Prices.lua`, `SwagBag/Core/Config.lua` (`prices.source`, `prices.tsm`), `SwagBag/Engine/Profiles.lua`, `SwagBag/Core/Report.lua`, `SwagBag/UI/SettingsPages.lua`, `SwagBag/Locale/enUS.lua`
- Modify: `SwagBag/SwagBag.toc` (the new file; `TradeSkillMaster` in OptionalDeps), `scripts/toc_check.lua` (the OptionalDeps line), `scripts/check.sh` (`TSM_API` / `LibStub` only in the Adapter)
- Test: `spec/adapter_spec.lua`, `spec/mock_adapter.lua` (`m.tsm`, `m.tsmCalls`), `spec/prices_spec.lua` (its file list gains `Core/Slash.lua`), `spec/vendor_spec.lua`, `spec/report_spec.lua`, `spec/profiles_spec.lua`, `spec/settings_spec.lua`

**Interfaces:**
- Consumes: `Prices.RegisterProvider/Invalidate/Value/Source`, `SB_CONFIG_CHANGED(path)`, `SB.Debounce`, `SB_PRICES_CHANGED`, `Adapter.Resolve`, `Vendor`'s `worthMoreAtAuction` (unchanged).
- Produces: `Adapter.TSM_PRICES` (`DBMarket`, `DBMinBuyout`, `DBRegionMarketAvg`, `DBRegionSaleAvg`), `Adapter.TSMAvailable()`, `Adapter.TSMPrice(link, priceString)`; `Prices.CHOICES`, `Prices.Choice()`, `Prices.TSMString()`, `Prices.SourceText()`; settings `prices.source` (`"auto"`), `prices.tsm` (`"DBMarket"`); `/swagbag price`; `L.HELP_PRICE`, `L.PRICE_*`, `L.SET_PRICE_*`.

- [ ] **Step 1: Write the failing tests**

In `spec/adapter_spec.lua` (edit 1 of 2), find:

```lua
-- luacheck: globals IsInGuild
```

and replace it with:

```lua
-- luacheck: globals IsInGuild TSM_API
```

In `spec/adapter_spec.lua` (edit 2 of 2), find:

```lua
		assert.equal(1, cleared, "nothing stays on the cursor")
	end)
end)
```

and replace it with:

```lua
		assert.equal(1, cleared, "nothing stays on the cursor")
	end)
end)

-- Week 9 (user pick 10): TSM's public addon API, read through the Adapter only. TSM_API errors on a name it does
-- not have, so the fake does too. Mutations: in A.TSMPrice drop the TSM_PRICE_OK check; or drop the isSecret(link)
-- check.
describe("Adapter TSM prices (real adapter, stubbed globals)", function()
	local A, asked
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		asked = {}
	end)

	after_each(function()
		TSM_API, issecretvalue = nil, nil
	end)

	local function tsm(fns)
		TSM_API = setmetatable(fns, { __index = function(_, k) error("TSM_API has no " .. tostring(k)) end })
	end

	it("prices through ToItemString and GetCustomPriceValue, only for the price strings SwagBag offers", function()
		assert.falsy(A.TSMAvailable(), "not loaded")
		tsm({ ToItemString = function(link) return "i:" .. link:match("item:(%d+)") end })
		assert.falsy(A.TSMAvailable(), "an API without GetCustomPriceValue")
		tsm({ ToItemString = function(link) return "i:" .. link:match("item:(%d+)") end,
			GetCustomPriceValue = function(priceString, itemString)
				asked[#asked + 1] = priceString .. " " .. itemString
				return itemString == "i:7" and 12345.6 or nil
			end })
		assert.truthy(A.TSMAvailable())
		assert.same({ 12345, nil }, { A.TSMPrice("item:7", "DBMarket"), A.TSMPrice("item:8", "DBMinBuyout") })
		assert.same({ "DBMarket i:7", "DBMinBuyout i:8" }, asked)
		assert.is_nil(A.TSMPrice("item:7", "vendorsell * 1000"), "a price string SwagBag does not offer")
		assert.equal(2, #asked)
		issecretvalue = function(v) return v == "item:7" end
		assert.is_nil(A.TSMPrice("item:7", "DBMarket"), "a secret link")
		assert.equal(2, #asked)
	end)

	it("an error, a negative or a non-number from TSM is no price", function()
		tsm({ ToItemString = function(link) return link end, GetCustomPriceValue = function(_, itemString)
			if itemString == "boom" then
				error("TSM broke")
			end
			return ({ neg = -5, text = "12" })[itemString]
		end })
		assert.truthy(A.TSMAvailable())
		assert.same({ nil, nil, nil }, { A.TSMPrice("boom", "DBMarket"), A.TSMPrice("neg", "DBMarket"),
			A.TSMPrice("text", "DBMarket") })
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
		m.auctionatorCallback = cb
```

and replace it with:

```lua
		m.auctionatorCallback = cb
	end

	-- TradeSkillMaster (week 9): m.tsm = { prices = { [priceString] = { [link] = copper } } } while "loaded"; nil
	-- otherwise. m.tsmCalls = { { link, priceString } } per price asked.
	m.tsm = nil
	m.tsmCalls = {}
	function m.TSMAvailable()
		return m.tsm ~= nil
	end

	function m.TSMPrice(link, priceString)
		m.tsmCalls[#m.tsmCalls + 1] = { link, priceString }
		local list = m.tsm and m.tsm.prices[priceString]
		return list and list[link] or nil
```

In `spec/prices_spec.lua` (edit 1 of 2), find:

```lua
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
```

and replace it with:

```lua
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
```

In `spec/prices_spec.lua` (edit 2 of 2), find:

```lua
		assert.same({ 250000, "Vendor" }, { P.Value(RING_LINK, Fixtures.BOE_RING) })
```

and replace it with:

```lua
		assert.same({ 250000, "Vendor" }, { P.Value(RING_LINK, Fixtures.BOE_RING) })
	end)

	-- Week 9 (user pick 10). Mutations: give TSM a priority above Auctionator's; or in active() drop the choice
	-- check (every available provider answers, whatever the setting).
	it("by default Auctionator answers, else TSM, else the vendor; prices.source picks one, the vendor fills in", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		A.tsm = { prices = { DBMarket = { [HERB_LINK] = 30000 } } }
		P.Invalidate()
		assert.same({ "TSM", 30000 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) }, "no Auctionator: TSM")
		A.auctionator = { prices = { [HERB_LINK] = 42000 } }
		P.Invalidate()
		assert.same({ "Auctionator", 42000 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) }, "both: Auctionator")
		SB.Config.Set("prices.source", "tsm")
		assert.same({ "TSM", 30000 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) })
		assert.same({ 250000, "Vendor" }, { P.Value(RING_LINK, Fixtures.BOE_RING) }, "what TSM has no price for")
		SB.Config.Set("prices.source", "vendor")
		assert.same({ "Vendor", 1500 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) })
		SB.Config.Set("prices.source", "auctionator")
		A.auctionator = nil
		P.Invalidate()
		assert.same({ "Vendor", 1500 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) }, "the chosen one is not loaded")
	end)

	-- Mutations: the TSM provider asks for "DBMarket" whatever the setting; or the SB_CONFIG_CHANGED listener
	-- does not drop the cache.
	it("TSM's price string follows the setting; a new source or string drops the cache and refreshes the totals", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		local refreshed = 0
		SB.On("SB_PRICES_CHANGED", function() refreshed = refreshed + 1 end)
		A.tsm = { prices = { DBMarket = { [HERB_LINK] = 30000 }, DBMinBuyout = { [HERB_LINK] = 25000 } } }
		SB.Config.Set("prices.source", "tsm")
		assert.equal(30000, P.Value(HERB_LINK, Fixtures.HERB))
		SB.Config.Set("prices.tsm", "DBMinBuyout")
		assert.equal(25000, P.Value(HERB_LINK, Fixtures.HERB))
		assert.same({ HERB_LINK, "DBMinBuyout" }, A.tsmCalls[#A.tsmCalls])
		A.Advance(P.REFRESH_DELAY)
		assert.equal(1, refreshed, "one refresh after the burst")
		assert.equal("TSM (DBMinBuyout)", P.SourceText())
		SB.Config.Set("prices.source", "auto")
		assert.equal("TSM (DBMinBuyout)", P.SourceText(), "auto, no Auctionator: TSM")
		A.tsm = nil
		P.Invalidate()
		assert.equal("Vendor", P.SourceText())
	end)

	-- Mutation: in the price command, set prices.source without checking Config.Set's answer.
	it("/swagbag price says where prices come from, picks a source and TSM's price, and refuses the rest", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		local L = SB.L
		local function run(line)
			local _, feedback = SB.Slash.Run(line)
			return feedback
		end
		assert.equal(L.PRICE_STATE:format(L.PRICE_CHOICE_AUTO, "Vendor"), run("price"))
		A.tsm = { prices = {} }
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_TSM:format("DBMarket")), run("price tsm"))
		assert.equal("tsm", SB.Config.Get("prices.source"))
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_TSM:format("DBRegionMarketAvg")), run("price TSM dbregionmarketavg"))
		assert.equal("DBRegionMarketAvg", SB.Config.Get("prices.tsm"))
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_AUCTIONATOR) .. " " .. L.PRICE_NOT_LOADED:format("Auctionator"),
			run("price auctionator"))
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_VENDOR), run("price vendor"))
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_AUTO), run("price auto"))
		assert.equal(L.PRICE_USAGE, run("price tsm dbanything"))
		assert.equal(L.PRICE_USAGE, run("price auctionhouse"))
		SB.Config.readOnly = true
		assert.equal(L.SETTINGS_READONLY, run("price tsm"))
		assert.equal("auto", SB.Config.Get("prices.source"))
```

In `spec/profiles_spec.lua`, find:

```lua
		assert.is_nil(Pr.Parse("SWAGBAG:1:s.sort.mode=sshuffle"))
```

and replace it with:

```lua
		assert.is_nil(Pr.Parse("SWAGBAG:1:s.sort.mode=sshuffle"))
	end)

	-- Week 9 (user pick 10). Mutation: drop `["prices.tsm"] = ...` from VALID.
	it("the price source and TSM's price string travel; a price string SwagBag does not offer is refused", function()
		C.Set("prices.source", "tsm")
		C.Set("prices.tsm", "DBMinBuyout")
		local data = assert(Pr.Parse(Pr.Export(false)))
		assert.same({ "tsm", "DBMinBuyout" }, { data.settings["prices.source"], data.settings["prices.tsm"] })
		assert.is_nil(Pr.Parse("SWAGBAG:1:s.prices.tsm=sDBAnything"))
		assert.is_nil(Pr.Parse("SWAGBAG:1:s.prices.source=sauctioneer"))
```

In `spec/report_spec.lua`, find:

```lua
	end)

	it("Hash is stable, order-independent and changes with content", function()
```

and replace it with:

```lua
	end)

	-- Week 9. Mutation: Report uses Prices.Source() even when SourceText exists.
	it("names TSM's price string when TSM answers", function()
		SB.Checks.last = {}
		SB.Prices = { Source = function() return "TSM" end, SourceText = function() return "TSM (DBMarket)" end, cached = 7 }
		assert.truthy(SB.Report.Build():find("\nPrices: TSM (DBMarket), 7 cached", 1, true))
	end)

	it("Hash is stable, order-independent and changes with content", function()
```

In `spec/settings_spec.lua`, find:

```lua
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
```

and replace it with:

```lua
	end)

	-- Week 9 (user pick 10), P1. Mutation: in the TSM price row's apply, run "price tsm" without the string.
	it("bank page: the price source rows, Auto and DBMarket first and selected; each choice runs /swagbag price", function()
		SB.Slash.Register("price", "test", function(arg)
			ran[#ran + 1] = "price " .. arg
			return "ran price " .. arg
		end)
		SW.Show("bank")
		assert.truthy(SW.selected[button(SB.L.SET_PRICE_AUTO)])
		assert.truthy(SW.selected[button("DBMarket")])
		click("TSM")
		click("DBMinBuyout")
		click(SB.L.SET_PRICE_VENDOR)
		assert.same({ "price tsm", "price tsm DBMinBuyout", "price vendor" }, ran)
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
```

In `spec/vendor_spec.lua`, find:

```lua
	end)

	-- Ruling R19: a gray piece whose look the account lacks is a transmog, not junk. Mutation: Vendor.Protected
```

and replace it with:

```lua
	end)

	-- Week 9 (user pick 10): the protection asks the chosen price source. Mutation: worthMoreAtAuction asks
	-- only Auctionator (source == "Auctionator").
	it("a gray BoE worth more than twice its vendor price by TSM's price stays when TSM is the source", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		A.AddItem(GRAY_BOE, { name = "Rusted Sabre", classID = A.ITEM_CLASS.Weapon, subclassID = 7,
			equipLoc = "INVTYPE_WEAPON", quality = 0, ilvl = 5, maxStack = 1, bind = "equip", sellPrice = 100 })
		A.Put(0, 8, GRAY_BOE, 1)
		A.auctionator = { prices = { ["item:" .. GRAY_BOE] = 150 } }
		A.tsm = { prices = { DBMarket = { ["item:" .. GRAY_BOE] = 900 } } }
		SB.Config.Set("prices.source", "tsm")
		SB.Inventory.ScanAll()
		visit()
		assert.same({ 6 }, sold())
	end)

	-- Ruling R19: a gray piece whose look the account lacks is a transmog, not junk. Mutation: Vendor.Protected
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1470 passed, 9 failed`. The failures, exactly:

- `spec/adapter_spec.lua :: Adapter TSM prices (real adapter, stubbed globals) > prices through ToItemString and GetCustomPriceValue, only for the price strings SwagBag offers`
- `spec/adapter_spec.lua :: Adapter TSM prices (real adapter, stubbed globals) > an error, a negative or a non-number from TSM is no price`
- `spec/prices_spec.lua :: Prices (spec F10, 3.3) > by default Auctionator answers, else TSM, else the vendor; prices.source picks one, the vendor fills in`
- `spec/prices_spec.lua :: Prices (spec F10, 3.3) > TSM's price string follows the setting; a new source or string drops the cache and refreshes the totals`
- `spec/prices_spec.lua :: Prices (spec F10, 3.3) > /swagbag price says where prices come from, picks a source and TSM's price, and refuses the rest`
- `spec/profiles_spec.lua :: Profiles (week 7) > the price source and TSM's price string travel; a price string SwagBag does not offer is refused`
- `spec/report_spec.lua :: Report > names TSM's price string when TSM answers`
- `spec/settings_spec.lua :: Settings window > bank page: the price source rows, Auto and DBMarket first and selected; each choice runs /swagbag price`
- `spec/vendor_spec.lua :: Vendor (week 7) > a gray BoE worth more than twice its vendor price by TSM's price stays when TSM is the source`

`spec/prices_spec.lua` now loads `Core/Slash.lua` (the price command lives in `Engine/Prices.lua`); the TSM provider is loaded inside the four tests that need it, so at Step 2 only the new tests fail. The worth line's wording changes in `enUS.lua`, and the week-7 test that quotes it formats `L.WORTH_STATE` itself, so it stays green.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "prices through ToItemString and GetCustomPriceValue, only for the price strings SwagBag offers": in `SwagBag/Core/Adapter.lua`, `if not api or type(link) ~= "string" or isSecret(link) or not TSM_PRICE_OK[priceString] then` → `if not api or type(link) ~= "string" or isSecret(link) then`.
- "prices through ToItemString and GetCustomPriceValue, only for the price strings SwagBag offers": in `SwagBag/Core/Adapter.lua`, `if not api or type(link) ~= "string" or isSecret(link) or not TSM_PRICE_OK[priceString] then` → `if not api or type(link) ~= "string" or not TSM_PRICE_OK[priceString] then`.
- "an error, a negative or a non-number from TSM is no price": in `SwagBag/Core/Adapter.lua`, `and v == v and v >= 0 and v < math.huge then ⏎ return math.floor(v)` → `then ⏎ return math.floor(v)`.
- "by default Auctionator answers, else TSM, else the vendor; prices.source picks one, the vendor fills in": in `SwagBag/Providers/TSM.lua`, `priority = 5,` → `priority = 15,`.
- "by default Auctionator answers, else TSM, else the vendor; prices.source picks one, the vendor fills in": in `SwagBag/Engine/Prices.lua`, `and (choice == nil or p.name == choice or p.name == "Vendor") then` → `then`.
- "TSM's price string follows the setting; a new source or string drops the cache and refreshes the totals": in `SwagBag/Providers/TSM.lua`, `SB.Adapter.TSMPrice(link, SB.Prices.TSMString())` → `SB.Adapter.TSMPrice(link, "DBMarket")`.
- "TSM's price string follows the setting; a new source or string drops the cache and refreshes the totals": in `SwagBag/Engine/Prices.lua`, `elseif path == "prices.source" or path == "prices.tsm" then ⏎ P.Invalidate()` → `elseif path == "prices.source" or path == "prices.tsm" then`.
- "/swagbag price says where prices come from, picks a source and TSM's price, and refuses the rest": in `SwagBag/Engine/Prices.lua`, `if not C.Set("prices.source", a) or (priceString and not C.Set("prices.tsm", priceString)) then` → `C.Set("prices.source", a) ⏎ if priceString and not C.Set("prices.tsm", priceString) then`.
- "names TSM's price string when TSM answers": in `SwagBag/Core/Report.lua`, `local source = (SB.Prices.SourceText or SB.Prices.Source)()` → `local source = SB.Prices.Source()`.
- "a gray BoE worth more than twice its vendor price by TSM's price stays when TSM is the source": in `SwagBag/Engine/Vendor.lua`, `return source ~= nil and source ~= "Vendor" and` → `return source == "Auctionator" and`.
- "the price source and TSM's price string travel; a price string SwagBag does not offer is refused": in `SwagBag/Engine/Profiles.lua`, `["prices.tsm"] = words("DBMarket", "DBMinBuyout", "DBRegionMarketAvg", "DBRegionSaleAvg"),` → ∅.
- "bank page: the price source rows, Auto and DBMarket first and selected; each choice runs /swagbag price": in `SwagBag/UI/SettingsPages.lua`, `return run("price tsm " .. v)` → `return run("price tsm")`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua`, find:

```lua
---------------------------------------------------------------------------
-- Syndicator (optional alt data, spec 3.3; Providers/Syndicator.lua). Read only, through its
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- TradeSkillMaster (optional price source, week 9, user pick 10; Providers/TSM.lua). Only its public addon
-- API: TSM_API.ToItemString(link) -> TSM's item string, and TSM_API.GetCustomPriceValue(priceString,
-- itemString) -> copper or nil. TSM_API raises an error on a name it does not have, so every read is
-- pcall'd (A.Resolve is). TSM offers no "prices changed" callback in that API: the price cache's 10-minute
-- age (Engine/Prices.lua) is what refreshes TSM prices. Only the price strings below are ever asked
-- (a share string cannot make SwagBag evaluate a custom formula).
---------------------------------------------------------------------------
A.TSM_PRICES = { "DBMarket", "DBMinBuyout", "DBRegionMarketAvg", "DBRegionSaleAvg" }
local TSM_PRICE_OK = {}
for _, name in ipairs(A.TSM_PRICES) do
	TSM_PRICE_OK[name] = true
end

local function tsm()
	local okR, api = pcall(A.Resolve, "TSM_API")
	if not okR or type(api) ~= "table" or isSecret(api) then
		return nil
	end
	local okF, toItem, value = pcall(function()
		return api.ToItemString, api.GetCustomPriceValue
	end)
	if okF and type(toItem) == "function" and type(value) == "function" then
		return { toItem = toItem, value = value }
	end
	return nil
end

-- Resolved when availability is asked (once per price-cache fill), as for Auctionator.
local tsmApi

function A.TSMAvailable()
	tsmApi = tsm()
	return tsmApi ~= nil
end

-- Copper per unit by one of A.TSM_PRICES, or nil (no price, not loaded, a secret link, an error).
function A.TSMPrice(link, priceString)
	local api = tsmApi
	if not api or type(link) ~= "string" or isSecret(link) or not TSM_PRICE_OK[priceString] then
		return nil
	end
	local okS, itemString = pcall(api.toItem, link)
	if not okS or type(itemString) ~= "string" or isSecret(itemString) then
		return nil
	end
	local ok, v = pcall(api.value, priceString, itemString)
	if ok and type(v) == "number" and not isSecret(v) and v == v and v >= 0 and v < math.huge then
		return math.floor(v)
	end
	return nil
end

---------------------------------------------------------------------------
-- Syndicator (optional alt data, spec 3.3; Providers/Syndicator.lua). Read only, through its
```

In `SwagBag/Core/Config.lua`, find:

```lua
		-- worthTop percent) | "off". Prices: Auctionator, else the vendor (Engine/Prices.lua).
		prices = { headerTotals = true, worth = "fixed", worthGold = 100, worthTop = 10 },
```

and replace it with:

```lua
		-- worthTop percent) | "off". source (week 9, user pick 10): who prices items: "auto" (Auctionator, else TSM,
		-- else the vendor) | "auctionator" | "tsm" | "vendor"; tsm: TSM's price string (Engine/Prices.lua).
		prices = { headerTotals = true, worth = "fixed", worthGold = 100, worthTop = 10, source = "auto", tsm = "DBMarket" },
```

In `SwagBag/Core/Report.lua`, find:

```lua
		lines[#lines + 1] = L.REPORT_PRICES:format(tostring(SB.Prices.Source() or L.REPORT_NONE), SB.Prices.cached)
```

and replace it with:

```lua
		local source = (SB.Prices.SourceText or SB.Prices.Source)() -- week 9: TSM names its price string
		lines[#lines + 1] = L.REPORT_PRICES:format(tostring(source or L.REPORT_NONE), SB.Prices.cached)
```

In `SwagBag/Engine/Prices.lua` (edit 1 of 5), find:

```lua
--   Prices.Invalidate()
```

and replace it with:

```lua
--   Prices.Invalidate()
-- Week 9 (user pick 10): Providers/TSM.lua adds "TSM" (priority 5, TradeSkillMaster's price string from the
-- prices.tsm setting). prices.source picks who answers: "auto" (the default: Auctionator, else TSM, else the
-- vendor, by priority) | "auctionator" | "tsm" | "vendor" (that one, the vendor for what it has no price for,
-- or for everything while it is not loaded). Header totals, the list's Value column, the gold glow and the
-- vendor's "worth more at auction" protection all ask Prices.Value, so they follow the choice.
--   Prices.Choice() -> provider name | nil (auto);  Prices.TSMString() -> one of Adapter.TSM_PRICES
--   Prices.SourceText() -> "Auctionator" | "TSM (DBMarket)" | "Vendor"   for /swagbag price and the report
-- A change of either setting drops the cache and refreshes the open windows' totals once.
```

In `SwagBag/Engine/Prices.lua` (edit 2 of 5), find:

```lua
-- The available providers, best first (worked out once per cache fill).
local function active()
	if not P.active then
		local list = {}
		for _, p in ipairs(P.providers) do
			if not P.off[p.name] then
```

and replace it with:

```lua
P.CHOICES = { auctionator = "Auctionator", tsm = "TSM", vendor = "Vendor" }

function P.Choice()
	return P.CHOICES[SB.Config.Get("prices.source")]
end

function P.TSMString()
	local want = SB.Config.Get("prices.tsm")
	for _, name in ipairs(SB.Adapter.TSM_PRICES) do
		if name == want then
			return name
		end
	end
	return SB.Adapter.TSM_PRICES[1]
end

-- The available providers, best first (worked out once per cache fill): every one ("auto"), or the chosen one
-- and the vendor.
local function active()
	if not P.active then
		local list, choice = {}, P.Choice()
		for _, p in ipairs(P.providers) do
			if not P.off[p.name] and (choice == nil or p.name == choice or p.name == "Vendor") then
```

In `SwagBag/Engine/Prices.lua` (edit 3 of 5), find:

```lua
	return first and first.name or nil
```

and replace it with:

```lua
	return first and first.name or nil
end

function P.SourceText()
	local source = P.Source()
	if source == "TSM" then
		return source .. " (" .. P.TSMString() .. ")"
	end
	return source
```

In `SwagBag/Engine/Prices.lua` (edit 4 of 5), find:

```lua
})

-- Providers that can say "prices changed" drop the cache when they do.
```

and replace it with:

```lua
})

local function refreshSoon()
	-- The windows refresh their header totals in place, once, after the burst.
	SB.Debounce("prices.refresh", P.REFRESH_DELAY, function()
		SB.Emit("SB_PRICES_CHANGED")
	end, "none")
end

-- Week 9: a new source or TSM price string asks the providers again; everything may have changed (nil: a
-- profile load, a reset) drops the cache too (SB.FollowSettings refreshes the windows then).
SB.On("SB_CONFIG_CHANGED", function(_, path)
	if path == nil then
		P.Invalidate()
	elseif path == "prices.source" or path == "prices.tsm" then
		P.Invalidate()
		refreshSoon()
	end
end, "none")

-- /swagbag price                       where prices come from
-- /swagbag price auto|auctionator|tsm|vendor
-- /swagbag price tsm <price>          TSM, with one of Adapter.TSM_PRICES (any case)
local function choiceText(choice)
	local L = SB.L
	if choice == "tsm" then
		return L.PRICE_CHOICE_TSM:format(P.TSMString())
	end
	return (choice == "auctionator" and L.PRICE_CHOICE_AUCTIONATOR) or (choice == "vendor" and L.PRICE_CHOICE_VENDOR)
		or L.PRICE_CHOICE_AUTO
end

SB.Slash.Register("price", SB.L.HELP_PRICE, function(arg)
	local L, C = SB.L, SB.Config
	local a, b = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	if a == "" then
		return L.PRICE_STATE:format(choiceText(C.Get("prices.source")), tostring(P.SourceText() or L.REPORT_NONE))
	end
	local priceString
	if a == "tsm" and b ~= "" then
		for _, name in ipairs(SB.Adapter.TSM_PRICES) do
			if name:lower() == b then
				priceString = name
			end
		end
		if not priceString then
			return L.PRICE_USAGE
		end
	elseif b ~= "" or not (a == "auto" or P.CHOICES[a]) then
		return L.PRICE_USAGE
	end
	if not C.Set("prices.source", a) or (priceString and not C.Set("prices.tsm", priceString)) then
		return L.SETTINGS_READONLY
	end
	local text = L.PRICE_SET:format(choiceText(a))
	local name = P.CHOICES[a]
	if name and name ~= "Vendor" and P.Source() ~= name then
		text = text .. " " .. L.PRICE_NOT_LOADED:format(name)
	end
	return text
end)

-- Providers that can say "prices changed" drop the cache when they do.
```

In `SwagBag/Engine/Prices.lua` (edit 5 of 5), find:

```lua
				-- The windows refresh their header totals in place, once, after the burst.
				SB.Debounce("prices.refresh", P.REFRESH_DELAY, function()
					SB.Emit("SB_PRICES_CHANGED")
				end, "none")
```

and replace it with:

```lua
				refreshSoon()
```

In `SwagBag/Engine/Profiles.lua` (edit 1 of 2), find:

```lua
	["prices.worthTop"] = range(1, 50, true),
```

and replace it with:

```lua
	["prices.worthTop"] = range(1, 50, true), ["prices.source"] = words("auto", "auctionator", "tsm", "vendor"),
	["prices.tsm"] = words("DBMarket", "DBMinBuyout", "DBRegionMarketAvg", "DBRegionSaleAvg"),
```

In `SwagBag/Engine/Profiles.lua` (edit 2 of 2), find:

```lua
	["prices.worthGold"] = "PROFILE_LABEL_WORTH_GOLD", ["prices.worthTop"] = "PROFILE_LABEL_WORTH_TOP",
```

and replace it with:

```lua
	["prices.worthGold"] = "PROFILE_LABEL_WORTH_GOLD", ["prices.worthTop"] = "PROFILE_LABEL_WORTH_TOP",
	["prices.source"] = "SET_PRICE_SOURCE", ["prices.tsm"] = "SET_PRICE_TSM",
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 3), find:

```lua
L.WORTH_STATE = "Gold glow at the bank: %s (Auctionator prices, else what a vendor pays). Type /swagbag worth <gold>,"
```

and replace it with:

```lua
L.WORTH_STATE = "Gold glow at the bank: %s (by your price source: /swagbag price). Type /swagbag worth <gold>,"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 3), find:

```lua
L.SET_WORTH_TIP = "While a bank is open, items worth that much (a whole stack, by Auctionator's price, else the"
	.. " vendor's) glow gold in your bags and the bank. Your top: the most valuable part of what you carry and"
```

and replace it with:

```lua
L.SET_WORTH_TIP = "While a bank is open, items worth that much (a whole stack, by your price source: Auctionator, TSM"
	.. " or the vendor) glow gold in your bags and the bank. Your top: the most valuable part of what you carry and"
```

In `SwagBag/Locale/enUS.lua` (edit 3 of 3), find:

```lua
	.. " else moves, and locked or equipment-set items stay put. Bags, bank and warband bank are stacked apart."
```

and replace it with:

```lua
	.. " else moves, and locked or equipment-set items stay put. Bags, bank and warband bank are stacked apart."

-- Price source (week 9, user pick 10): Engine/Prices.lua, Providers/TSM.lua
L.HELP_PRICE = "price [auto|auctionator|tsm [<price>]|vendor]: where item prices come from (header totals, Value, gold glow)"
L.PRICE_CHOICE_AUTO = "auto (Auctionator, else TSM, else what a vendor pays)"
L.PRICE_CHOICE_AUCTIONATOR = "Auctionator (else what a vendor pays)"
L.PRICE_CHOICE_TSM = "TSM's %s (else what a vendor pays)"
L.PRICE_CHOICE_VENDOR = "what a vendor pays"
L.PRICE_STATE = "Prices: %s. Answering now: %s. Type /swagbag price auto, price auctionator, price tsm, price vendor,"
	.. " or price tsm <DBMarket|DBMinBuyout|DBRegionMarketAvg|DBRegionSaleAvg>."
L.PRICE_SET = "Prices now come from: %s."
L.PRICE_NOT_LOADED = "%s is not loaded, so what a vendor pays answers until it is."
L.PRICE_USAGE = "Use /swagbag price, price auto, price auctionator, price tsm, price vendor, or price tsm <DBMarket|"
	.. "DBMinBuyout|DBRegionMarketAvg|DBRegionSaleAvg>."
L.SET_PRICE_SOURCE = "Item prices come from"
L.SET_PRICE_AUTO = "Auto"
L.SET_PRICE_VENDOR = "Vendor"
L.SET_PRICE_SOURCE_TIP = "Auto: Auctionator if it is loaded, else TSM, else what a vendor pays. Section totals, the"
	.. " list's Value column, the gold glow and the vendor's \"worth more at auction\" rule all use this. Vendor: no"
	.. " auction prices at all, so a gray BoE is judged by what a vendor pays."
L.SET_PRICE_TSM = "TSM price (when TSM answers)"
L.SET_PRICE_TSM_TIP = "DBMarket: TSM's market value on your realm (the default). DBMinBuyout: the lowest buyout it saw."
	.. " DBRegionMarketAvg / DBRegionSaleAvg: the region's averages (need TSM's desktop app for fresh data)."
```

Create `SwagBag/Providers/TSM.lua`:

```lua
-- SwagBag price provider "TSM" (week 9, user pick 10; spec F10, 3.3). Optional (P4): it answers only while
-- TradeSkillMaster's public addon API is loaded, by the price string the prices.tsm setting names (DBMarket by
-- default; Engine/Prices.lua, Prices.TSMString). Priority 5: below Auctionator (10), above the vendor (0), so
-- "auto" asks Auctionator first. Calls go through the Adapter (Adapter.TSMAvailable, Adapter.TSMPrice).
local _, SB = ...

SB.Prices.RegisterProvider({
	name = "TSM",
	priority = 5,
	available = function()
		return SB.Adapter.TSMAvailable()
	end,
	value = function(link)
		if type(link) ~= "string" then
			return nil
		end
		return SB.Adapter.TSMPrice(link, SB.Prices.TSMString())
	end,
})
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
## OptionalDeps: Auctionator, Syndicator, ElvUI
```

and replace it with:

```text
## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
Providers/Auctionator.lua
```

and replace it with:

```text
Providers/Auctionator.lua
Providers/TSM.lua
```

In `SwagBag/UI/SettingsPages.lua`, find:

```lua
		end },
		{ kind = "note", label = L.SET_BANK_NOTE },
```

and replace it with:

```lua
		end },
		-- Week 9 (user pick 10): who prices items, and TSM's price; every click runs /swagbag price.
		{ kind = "choice", label = L.SET_PRICE_SOURCE, tip = L.SET_PRICE_SOURCE_TIP, width = 90, get = get("prices.source"),
			choices = { { value = "auto", text = L.SET_PRICE_AUTO }, { value = "auctionator", text = "Auctionator" },
				{ value = "tsm", text = "TSM" }, { value = "vendor", text = L.SET_PRICE_VENDOR } },
			apply = function(v)
				return run("price " .. v)
			end },
		{ kind = "choice", label = L.SET_PRICE_TSM, tip = L.SET_PRICE_TSM_TIP, width = 130, get = function()
			return SB.Prices.TSMString()
		end, choices = { { value = "DBMarket", text = "DBMarket" }, { value = "DBMinBuyout", text = "DBMinBuyout" },
			{ value = "DBRegionMarketAvg", text = "DBRegionMarketAvg" }, { value = "DBRegionSaleAvg", text = "DBRegionSaleAvg" } },
		apply = function(v)
			return run("price tsm " .. v)
		end },
		{ kind = "note", label = L.SET_BANK_NOTE },
```

In `scripts/check.sh`, find:

```text
fi

echo "== 4/5 TOC"
```

and replace it with:

```text
fi

# Week 9: other addons' API globals that SwagBag reads (TradeSkillMaster's TSM_API, Masque through LibStub) are
# named only in the Adapter too, comments included.
if grep -rnE '(^|[^[:alnum:]_])(TSM_API|LibStub)([^[:alnum:]_]|$)' SwagBag | grep -v '^SwagBag/Core/Adapter.lua:'; then
	fail "TSM_API or LibStub named outside SwagBag/Core/Adapter.lua (comments included)"
fi

echo "== 4/5 TOC"
```

In `scripts/toc_check.lua`, find:

```lua
	"## OptionalDeps: Auctionator, Syndicator, ElvUI",
```

and replace it with:

```lua
	"## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster",
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1479 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (74 files)`, `1479 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Core/Config.lua \
	SwagBag/Core/Report.lua \
	SwagBag/Engine/Prices.lua \
	SwagBag/Engine/Profiles.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/Providers/TSM.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/SettingsPages.lua \
	scripts/check.sh \
	scripts/toc_check.lua \
	spec/adapter_spec.lua \
	spec/mock_adapter.lua \
	spec/prices_spec.lua \
	spec/profiles_spec.lua \
	spec/report_spec.lua \
	spec/settings_spec.lua \
	spec/vendor_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 9 Task 3: TSM as a price source, and the price source choice (/swagbag price, Settings)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 4: Masque skins on SwagBag's item buttons (UI/Skins.lua)

The user's third pick, part (a) (pick 11). When Masque is loaded, every item button SwagBag makes joins a Masque group (D14): "Bags" (the bags' secure buttons), "Bank" (the character and warband bank's secure buttons), "Guild bank" (SwagBag's own plain guild buttons) and "Alt viewer" (its plain display buttons). A list row's icon is the slot's own button, only scaled, so the list follows the skin with no extra work. SwagBag's only call is Masque's `group:AddButton(button, nil, "Item")`, once per button, and only out of combat (D15): the bags' and bank's buttons are made out of combat anyway (week 1), and a button made in combat (the alt viewer's) joins when combat ends. Whether Masque is there is asked once, at the first button; without it nothing is asked and nothing changes. Masque's own options page switches each group off. `/swagbag report` says how many buttons Masque skins.

**Files:**
- Create: `SwagBag/UI/Skins.lua`, `spec/skins_spec.lua`
- Modify: `SwagBag/Core/Adapter.lua` (`A.MasqueAvailable`, `A.MasqueAdd`), `SwagBag/UI/Buttons.lua`, `SwagBag/UI/GuildButtons.lua`, `SwagBag/UI/DisplayButtons.lua`, `SwagBag/Core/Report.lua`, `SwagBag/Locale/enUS.lua`
- Modify: `SwagBag/SwagBag.toc` (the new file; `Masque` in OptionalDeps), `scripts/toc_check.lua`
- Test: `spec/adapter_spec.lua`, `spec/mock_adapter.lua` (`m.masque`), `spec/report_spec.lua`

**Interfaces:**
- Consumes: `Adapter.Resolve`, `Adapter.InCombat`, `SB.OutOfCombat`, the three button files' `create` functions.
- Produces: `Adapter.MasqueAvailable()`, `Adapter.MasqueAdd(groupName, button) -> bool`; `SB.Skins` with `Add(kind, button)`, `Available()`, `count`, `GROUPS`; `L.REPORT_MASQUE`, `L.REPORT_MASQUE_OFF`.

- [ ] **Step 1: Write the failing tests**

In `spec/adapter_spec.lua` (edit 1 of 2), find:

```lua
-- luacheck: globals IsInGuild TSM_API
```

and replace it with:

```lua
-- luacheck: globals IsInGuild TSM_API LibStub
```

In `spec/adapter_spec.lua` (edit 2 of 2), find:

```lua
			A.TSMPrice("text", "DBMarket") })
	end)
end)
```

and replace it with:

```lua
			A.TSMPrice("text", "DBMarket") })
	end)
end)

-- Week 9 (user pick 11): Masque's public API through LibStub, read through the Adapter only. Mutation: in
-- A.MasqueAdd, make a new group on every call (Masque would list one group per button).
describe("Adapter Masque (real adapter, stubbed globals)", function()
	local A, made, added
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		made, added = {}, {}
	end)

	after_each(function()
		LibStub = nil
	end)

	local function masque(fail)
		local msq = { Group = function(_, addon, name)
			made[#made + 1] = addon .. ": " .. name
			return { AddButton = function(_, button, regions, kind)
				if fail then
					error("Masque broke")
				end
				added[#added + 1] = { button, regions, kind }
			end }
		end }
		LibStub = setmetatable({}, { __call = function(_, lib, silent)
			assert(silent == true, "asked silently: no error when Masque is missing")
			return lib == "Masque" and msq or nil
		end })
	end

	it("groups come from LibStub('Masque', true), each made once; buttons join as Item buttons", function()
		assert.falsy(A.MasqueAvailable())
		assert.falsy(A.MasqueAdd("Bags", "button1"), "no Masque: nothing")
		masque()
		assert.truthy(A.MasqueAvailable())
		assert.truthy(A.MasqueAdd("Bags", "button1"))
		assert.truthy(A.MasqueAdd("Bags", "button2"))
		assert.truthy(A.MasqueAdd("Bank", "button3"))
		assert.same({ "SwagBag: Bags", "SwagBag: Bank" }, made)
		assert.same({ "button1", nil, "Item" }, added[1])
		assert.equal(3, #added)
	end)

	it("an error inside Masque is no skin, never an error", function()
		masque(true)
		assert.falsy(A.MasqueAdd("Bags", "button1"))
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
		return list and list[link] or nil
```

and replace it with:

```lua
		return list and list[link] or nil
	end

	-- Masque (week 9): m.masque = { groups = { [groupName] = { button, ... } } } while "loaded"; nil otherwise.
	m.masque = nil
	function m.MasqueAvailable()
		return m.masque ~= nil
	end

	function m.MasqueAdd(groupName, button)
		if not m.masque then
			return false
		end
		local list = m.masque.groups[groupName] or {}
		m.masque.groups[groupName] = list
		list[#list + 1] = button
		return true
```

In `spec/report_spec.lua`, find:

```lua
	end)

	it("Hash is stable, order-independent and changes with content", function()
```

and replace it with:

```lua
	end)

	-- Week 9 (user pick 11). Mutation: drop the Masque line from Report.Build.
	it("says whether Masque skins SwagBag's buttons, and how many", function()
		SB.Checks.last = {}
		SB.Skins = { Available = function() return false end, count = 0 }
		assert.truthy(SB.Report.Build():find("\nMasque: not loaded", 1, true))
		SB.Skins = { Available = function() return true end, count = 410 }
		assert.truthy(SB.Report.Build():find("\nMasque: 410 buttons skinned", 1, true))
	end)

	it("Hash is stable, order-independent and changes with content", function()
```

Create `spec/skins_spec.lua`:

```lua
-- luacheck: globals SetItemButtonTexture SetItemButtonCount SetItemButtonQuality SetItemButtonDesaturated
-- Week 9 (user pick 11): with Masque loaded, SwagBag's item buttons join Masque groups ("Bags", "Bank", "Guild
-- bank", "Alt viewer") once each, never in combat, and nothing else about them changes; without Masque nothing
-- happens at all.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Skins (week 9, Masque)", function()
	local SB, A, Sk
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
			"SwagBag/Core/Config.lua" })
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		Env.PaintGlobals()
		A.SetBagSize(0, 16)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(6, 98)
		A.SetBagSize(12, 98)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function load(files)
		for _, f in ipairs(files) do
			Loader.LoadFile(SB, f)
		end
		Sk = SB.Skins
	end

	-- Mutation: in createButton (UI/Buttons.lua), drop the SB.Skins.Add call.
	it("every bag and bank button joins its Masque group once at login; a bank tab bought later joins too", function()
		A.masque = { groups = {} }
		load({ "SwagBag/UI/Skins.lua", "SwagBag/UI/Buttons.lua" })
		SB.Emit("SB_LOGIN")
		local B = SB.Buttons
		assert.equal(6 * 38, #A.masque.groups.Bags, "bags 0-5 at 38 buttons each")
		assert.equal(2 * 98, #A.masque.groups.Bank, "the character and the warband bank share a group")
		assert.equal(B.Get(0, 1), A.masque.groups.Bags[1])
		A.bagIDs.bank = { 6, 7 }
		A.SetBagSize(7, 98)
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.equal(3 * 98, #A.masque.groups.Bank)
		Sk.Add("bags", B.Get(0, 1))
		assert.equal(6 * 38, #A.masque.groups.Bags, "never twice")
		assert.equal(6 * 38 + 3 * 98, Sk.count)
	end)

	-- Never in combat. Mutation: in Skins.Add, drop the InCombat check (the button joins at once).
	it("a button made in combat joins only once combat ends", function()
		A.masque = { groups = {} }
		load({ "SwagBag/UI/Skins.lua", "SwagBag/UI/DisplayButtons.lua" })
		SB.DisplayButtons.SetParent(Fake.New("Frame", UIParent))
		A.combat = true
		local b = SB.DisplayButtons.Get(0, 1) -- the alt viewer's plain buttons may be made in combat
		assert.is_nil(A.masque.groups["Alt viewer"])
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.same({ b }, A.masque.groups["Alt viewer"])
	end)

	-- Mutation: in GuildButtons' create, drop the SB.Skins.Add call.
	it("the guild bank's buttons join the Guild bank group when they are made", function()
		A.masque = { groups = {} }
		load({ "SwagBag/UI/Skins.lua", "SwagBag/UI/GuildButtons.lua" })
		SB.GuildButtons.SetParent(Fake.New("Frame", UIParent))
		SB.GuildButtons.Ensure({ 1 })
		assert.equal(A.GUILD_SLOTS, #A.masque.groups["Guild bank"])
	end)

	-- Mutation: in Skins.Add, drop the Available() check (Masque is asked for every button).
	it("without Masque nothing is asked, and SwagBag calls nothing more on a button than before", function()
		load({ "SwagBag/UI/Skins.lua", "SwagBag/UI/Buttons.lua" })
		local asked = 0
		A.MasqueAdd = function() asked = asked + 1 return false end
		SB.Emit("SB_LOGIN")
		assert.equal(0, asked)
		assert.equal(0, Sk.count)
		local b = SB.Buttons.Get(0, 1)
		Fake.Strict(b)
		A.masque = { groups = {} }
		Sk.Add("bags", b) -- Masque was not there at login: the answer is kept for the session
		assert.same({}, b.log)
	end)
end)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1479 passed, 7 failed`. The failures, exactly:

- `spec/adapter_spec.lua :: Adapter Masque (real adapter, stubbed globals) > groups come from LibStub('Masque', true), each made once; buttons join as Item buttons`
- `spec/adapter_spec.lua :: Adapter Masque (real adapter, stubbed globals) > an error inside Masque is no skin, never an error`
- `spec/report_spec.lua :: Report > says whether Masque skins SwagBag's buttons, and how many`
- `spec/skins_spec.lua :: Skins (week 9, Masque) > every bag and bank button joins its Masque group once at login; a bank tab bought later joins too`
- `spec/skins_spec.lua :: Skins (week 9, Masque) > a button made in combat joins only once combat ends`
- `spec/skins_spec.lua :: Skins (week 9, Masque) > the guild bank's buttons join the Guild bank group when they are made`
- `spec/skins_spec.lua :: Skins (week 9, Masque) > without Masque nothing is asked, and SwagBag calls nothing more on a button than before`

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "groups come from LibStub('Masque', true), each made once; buttons join as Item buttons": in `SwagBag/Core/Adapter.lua`, `group = g ⏎ masqueGroups[groupName] = g` → `group = g`.
- "an error inside Masque is no skin, never an error": in `SwagBag/Core/Adapter.lua`, `return (pcall(function() ⏎ group:AddButton(button, nil, "Item") ⏎ end))` → `group:AddButton(button, nil, "Item") ⏎ return true`.
- "every bag and bank button joins its Masque group once at login; a bank tab bought later joins too": in `SwagBag/UI/Buttons.lua`, `if SB.Skins then -- week 9: Masque's skin, when it is loaded (out of combat: buttons are only made then) ⏎ SB.Skins.Add(kindOf(bag), b) ⏎ end` → ∅.
- "a button made in combat joins only once combat ends": in `SwagBag/UI/Skins.lua`, `if SB.Adapter.InCombat() then ⏎ Sk.pending[#Sk.pending + 1] = { kind, button } ⏎ SB.OutOfCombat(flush, "skins.add", "none") ⏎ return ⏎ end` → ∅.
- "the guild bank's buttons join the Guild bank group when they are made": in `SwagBag/UI/GuildButtons.lua`, `if SB.Skins then -- week 9: Masque's skin, when it is loaded ⏎ SB.Skins.Add("guild", b) ⏎ end` → ∅.
- "without Masque nothing is asked, and SwagBag calls nothing more on a button than before": in `SwagBag/UI/Skins.lua`, `if Sk.added[button] or not Sk.Available() then` → `if Sk.added[button] then`.
- "says whether Masque skins SwagBag's buttons, and how many": in `SwagBag/Core/Report.lua`, `lines[#lines + 1] = skins.Available() and L.REPORT_MASQUE:format(skins.count) or L.REPORT_MASQUE_OFF` → ∅.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua`, find:

```lua
---------------------------------------------------------------------------
-- Syndicator (optional alt data, spec 3.3; Providers/Syndicator.lua). Read only, through its
```

and replace it with:

```lua
---------------------------------------------------------------------------
-- Masque (optional button skins, week 9, user pick 11; UI/Skins.lua). Only its public API:
-- LibStub("Masque", true) (silent: nil when Masque is not there), Masque:Group("SwagBag", name) and
-- group:AddButton(button, nil, "Item") (Masque finds the item button's own regions). One group per name, made
-- once. Every call is pcall'd: an error inside Masque is no skin, never an error. UI/Skins.lua calls this out
-- of combat only.
---------------------------------------------------------------------------
local masqueGroups = {}

local function masque()
	local okL, lib = pcall(A.Resolve, "LibStub")
	if not okL or (type(lib) ~= "table" and type(lib) ~= "function") or isSecret(lib) then
		return nil
	end
	local ok, msq = pcall(lib, "Masque", true)
	if ok and type(msq) == "table" and not isSecret(msq) then
		return msq
	end
	return nil
end

function A.MasqueAvailable()
	return masque() ~= nil
end

-- true when the button joined Masque's group of that name.
function A.MasqueAdd(groupName, button)
	local group = masqueGroups[groupName]
	if not group then
		local msq = masque()
		if not msq then
			return false
		end
		local ok, g = pcall(function()
			return msq:Group("SwagBag", groupName)
		end)
		if not ok or type(g) ~= "table" then
			return false
		end
		group = g
		masqueGroups[groupName] = g
	end
	return (pcall(function()
		group:AddButton(button, nil, "Item")
	end))
end

---------------------------------------------------------------------------
-- Syndicator (optional alt data, spec 3.3; Providers/Syndicator.lua). Read only, through its
```

In `SwagBag/Core/Report.lua`, find:

```lua
	end
	if SB.Theme and SB.Config.db then
```

and replace it with:

```lua
	end
	local skins = SB.Skins
	if skins then -- week 9: Masque's skins on SwagBag's buttons
		lines[#lines + 1] = skins.Available() and L.REPORT_MASQUE:format(skins.count) or L.REPORT_MASQUE_OFF
	end
	if SB.Theme and SB.Config.db then
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
	.. " DBRegionMarketAvg / DBRegionSaleAvg: the region's averages (need TSM's desktop app for fresh data)."
```

and replace it with:

```lua
	.. " DBRegionMarketAvg / DBRegionSaleAvg: the region's averages (need TSM's desktop app for fresh data)."

-- Masque skins (week 9, user pick 11): UI/Skins.lua
L.REPORT_MASQUE = "Masque: %d buttons skinned"
L.REPORT_MASQUE_OFF = "Masque: not loaded"
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster
```

and replace it with:

```text
## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster, Masque
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
UI/Theme.lua
```

and replace it with:

```text
UI/Theme.lua
UI/Skins.lua
```

In `SwagBag/UI/Buttons.lua`, find:

```lua
	b:Hide()
```

and replace it with:

```lua
	b:Hide()
	if SB.Skins then -- week 9: Masque's skin, when it is loaded (out of combat: buttons are only made then)
		SB.Skins.Add(kindOf(bag), b)
	end
```

In `SwagBag/UI/DisplayButtons.lua`, find:

```lua
	b:Hide()
```

and replace it with:

```lua
	b:Hide()
	if SB.Skins then -- week 9: Masque's skin, when it is loaded (made in combat: it joins after combat)
		SB.Skins.Add("alts", b)
	end
```

In `SwagBag/UI/GuildButtons.lua`, find:

```lua
	b:Hide()
```

and replace it with:

```lua
	b:Hide()
	if SB.Skins then -- week 9: Masque's skin, when it is loaded
		SB.Skins.Add("guild", b)
	end
```

Create `SwagBag/UI/Skins.lua`:

```lua
-- SwagBag button skins (week 9, user pick 11). When Masque is loaded, SwagBag's item buttons join Masque groups
-- "SwagBag: Bags", "Bank" (character and warband), "Guild bank" and "Alt viewer", so they follow the skin the user
-- picks in Masque's own options (where each group can also be switched off). A list row's icon is the slot's
-- own button, scaled (week 5), so the list follows too. SwagBag only hands each button to Masque, once, and
-- only out of combat: Masque restyles the button's textures, and the bags' and the bank's buttons are Blizzard's
-- secure item buttons, so a button made during combat joins when combat ends. SwagBag never reparents, re-IDs or
-- sets an attribute on a button for this (spec 4.1). Without Masque nothing is asked and nothing changes; whether
-- it is there is asked once per session, at the first button.
--   Skins.Add(kind, button)   kind: "bags" | "bank" | "warband" | "guild" | "alts"
--   Skins.Available() -> bool;  Skins.count: buttons skinned (for /swagbag report)
local _, SB = ...

local Sk = { added = setmetatable({}, { __mode = "k" }), pending = {}, count = 0, available = nil,
	GROUPS = { bags = "Bags", bank = "Bank", warband = "Bank", guild = "Guild bank", alts = "Alt viewer" } }
SB.Skins = Sk

function Sk.Available()
	if Sk.available == nil then
		Sk.available = SB.Adapter.MasqueAvailable() == true
	end
	return Sk.available
end

local function flush()
	local list = Sk.pending
	Sk.pending = {}
	for _, e in ipairs(list) do
		Sk.Add(e[1], e[2])
	end
end

function Sk.Add(kind, button)
	if Sk.added[button] or not Sk.Available() then
		return
	end
	if SB.Adapter.InCombat() then
		Sk.pending[#Sk.pending + 1] = { kind, button }
		SB.OutOfCombat(flush, "skins.add", "none")
		return
	end
	if SB.Adapter.MasqueAdd(Sk.GROUPS[kind] or Sk.GROUPS.bags, button) then
		Sk.added[button] = true
		Sk.count = Sk.count + 1
	end
end
```

In `scripts/toc_check.lua`, find:

```lua
	"## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster",
```

and replace it with:

```lua
	"## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster, Masque",
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1486 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (75 files)`, `1486 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Core/Report.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/Buttons.lua \
	SwagBag/UI/DisplayButtons.lua \
	SwagBag/UI/GuildButtons.lua \
	SwagBag/UI/Skins.lua \
	scripts/toc_check.lua \
	spec/adapter_spec.lua \
	spec/mock_adapter.lua \
	spec/report_spec.lua \
	spec/skins_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 9 Task 4: Masque skins on SwagBag's item buttons (bags, bank, guild bank, alt viewer)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 5: Another bag addon on at the same time: one warning at login, and a report line

The third pick, part (b). Two bag replacements at once fight over the same bags (items in two windows, a bank that opens twice). The Adapter names the usual ones by the folder name `C_AddOns` reports them loaded under (`A.OTHER_BAG_ADDONS`: Baganator, Bagnon, Combuctor, AdiBags, ArkInventory, BetterBags, LiteBag, Sorted, GudaBags, Inventorian, EllesmereUIBags, EnhanceQoLBags), and ElvUI only while ElvUI's own bags module is on (`ElvUI[1].private.bags.enable`; ElvUI without its bags is fine). At login, while SwagBag's bags are not in Safe Mode, one chat line names the others that are on and says how to keep one: `/swagbag safe on`, or disable one in the AddOns list. Nothing is ever switched off (D16). `/swagbag report` always has the line `Other bag addons on: ...`.

**Files:**
- Modify: `SwagBag/Core/Adapter.lua` (`A.OTHER_BAG_ADDONS`, `A.ElvUIBagsOn`, `A.OtherBagAddons`), `SwagBag/Core/Report.lua`, `SwagBag/Locale/enUS.lua`
- Test: `spec/report_spec.lua`

**Interfaces:**
- Consumes: `Adapter.AddOnState`, `Adapter.Resolve`, `SafeMode.IsOn`, `SB_LOGIN`.
- Produces: `Adapter.OTHER_BAG_ADDONS`, `Adapter.ElvUIBagsOn()`, `Adapter.OtherBagAddons() -> { name }`; `L.OTHER_BAGS_WARN`, `L.REPORT_OTHER_BAGS`.

- [ ] **Step 1: Write the failing tests**

In `spec/report_spec.lua` (edit 1 of 2), find:

```lua
			"Bag-related addons: Auctionator (not loaded), Syndicator (not loaded)",
```

and replace it with:

```lua
			"Bag-related addons: Auctionator (not loaded), Syndicator (not loaded)",
			"Other bag addons on: none",
```

In `spec/report_spec.lua` (edit 2 of 2), find:

```lua
	end)

	it("Hash is stable, order-independent and changes with content", function()
```

and replace it with:

```lua
	end)

	-- Week 9 (user pick 11b). Mutations: in A.OtherBagAddons drop the ElvUIBagsOn() check; or in A.ElvUIBagsOn
	-- drop `== true` (any ElvUI counts, bags module or not).
	it("names every other bag addon that is on, and ElvUI only while its own bags module is on", function()
		SB.Checks.last = {}
		A.addons = { Baganator = "833", Bagnon = false, AdiBags = "1.10", ElvUI = "14.0", Syndicator = "200" }
		A.globals.ElvUI = { { private = { bags = { enable = false } } } }
		assert.same({ "Baganator", "AdiBags" }, A.OtherBagAddons())
		A.globals.ElvUI[1].private.bags.enable = true
		assert.same({ "Baganator", "AdiBags", "ElvUI" }, A.OtherBagAddons())
		A.globals.ElvUI = { { private = {} } }
		assert.same({ "Baganator", "AdiBags" }, A.OtherBagAddons(), "no bags settings yet: not counted")
		assert.truthy(SB.Report.Build():find("\nOther bag addons on: Baganator, AdiBags\n", 1, true))
	end)

	-- Never disables anything. Mutations: drop the login warning; or drop its Safe Mode check.
	it("at login one line names them and suggests /swagbag safe on; silent when none, or in Safe Mode", function()
		SB.Emit("SB_LOGIN")
		assert.same({}, A.Lines(), "none on: nothing said")
		A.addons = { Baganator = "833", BetterBags = "0.3" }
		SB.Emit("SB_LOGIN")
		assert.same({ SB.L.OTHER_BAGS_WARN:format("Baganator, BetterBags") }, A.Lines())
		SB.SafeMode.Enable("bags", "manual")
		SB.Emit("SB_LOGIN")
		assert.equal(1, #A.Lines(), "SwagBag has stepped aside already")
		assert.same({ "833", "0.3" }, { A.addons.Baganator, A.addons.BetterBags }, "nothing was switched off")
	end)

	it("Hash is stable, order-independent and changes with content", function()
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1485 passed, 3 failed`. The failures, exactly:

- `spec/report_spec.lua :: Report > builds the full report for a clean session`
- `spec/report_spec.lua :: Report > names every other bag addon that is on, and ElvUI only while its own bags module is on`
- `spec/report_spec.lua :: Report > at login one line names them and suggests /swagbag safe on; silent when none, or in Safe Mode`

The clean-session report test gains the new `Other bag addons on: none` line, so it fails at Step 2 too.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "names every other bag addon that is on, and ElvUI only while its own bags module is on": in `SwagBag/Core/Adapter.lua`, `if A.ElvUIBagsOn() then ⏎ out[#out + 1] = "ElvUI" ⏎ end` → ∅.
- "names every other bag addon that is on, and ElvUI only while its own bags module is on": in `SwagBag/Core/Adapter.lua`, `return type(bags) == "table" and bags.enable == true` → `return type(E) == "table"`.
- "at login one line names them and suggests /swagbag safe on; silent when none, or in Safe Mode": in `SwagBag/Core/Report.lua`, `if #others > 0 then ⏎ SB.Print(SB.L.OTHER_BAGS_WARN:format(table.concat(others, ", "))) ⏎ end` → ∅.
- "at login one line names them and suggests /swagbag safe on; silent when none, or in Safe Mode": in `SwagBag/Core/Report.lua`, `if SB.SafeMode.IsOn("bags") then ⏎ return ⏎ end ⏎ local others = SB.Adapter.OtherBagAddons()` → `local others = SB.Adapter.OtherBagAddons()`.
- "builds the full report for a clean session": in `SwagBag/Core/Report.lua`, `lines[#lines + 1] = L.REPORT_OTHER_BAGS:format(#others > 0 and table.concat(others, ", ") or L.REPORT_NONE)` → ∅.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua`, find:

```lua
	return loaded, version
```

and replace it with:

```lua
	return loaded, version
end

-- Week 9 (user pick 11b): other bag replacements that fight SwagBag over the same bags, by the folder name
-- C_AddOns reports them loaded under (A.AddOnState), and ElvUI only while its own bags module is on
-- (ElvUI[1].private.bags.enable; ElvUI without its bags is fine). Read only: SwagBag never disables an addon.
A.OTHER_BAG_ADDONS = { "Baganator", "Bagnon", "Combuctor", "AdiBags", "ArkInventory", "BetterBags", "LiteBag",
	"Sorted", "GudaBags", "Inventorian", "EllesmereUIBags", "EnhanceQoLBags" }

function A.ElvUIBagsOn()
	local ok, on = pcall(function()
		local E = A.Resolve("ElvUI")
		E = type(E) == "table" and E[1]
		local private = type(E) == "table" and E.private
		local bags = type(private) == "table" and private.bags
		return type(bags) == "table" and bags.enable == true
	end)
	return ok and on == true
end

-- The names of the other bag addons that are on now, in A.OTHER_BAG_ADDONS order, then "ElvUI".
function A.OtherBagAddons()
	local out = {}
	for _, name in ipairs(A.OTHER_BAG_ADDONS) do
		if A.AddOnState(name) then
			out[#out + 1] = name
		end
	end
	if A.ElvUIBagsOn() then
		out[#out + 1] = "ElvUI"
	end
	return out
```

In `SwagBag/Core/Report.lua` (edit 1 of 2), find:

```lua
end

function Report.Build()
```

and replace it with:

```lua
end

-- Week 9 (user pick 11b): two bag addons at once fight over the same bags (items in two windows, a bank that
-- opens twice). At login one chat line names the others that are on and says how to keep one; nothing is ever
-- switched off. Silent while SwagBag's bags are in Safe Mode (SwagBag has stepped aside already).
SB.On("SB_LOGIN", function()
	if SB.SafeMode.IsOn("bags") then
		return
	end
	local others = SB.Adapter.OtherBagAddons()
	if #others > 0 then
		SB.Print(SB.L.OTHER_BAGS_WARN:format(table.concat(others, ", ")))
	end
end, "none")

function Report.Build()
```

In `SwagBag/Core/Report.lua` (edit 2 of 2), find:

```lua
	lines[#lines + 1] = L.REPORT_ADDONS:format(table.concat(addonList(), ", "))
```

and replace it with:

```lua
	lines[#lines + 1] = L.REPORT_ADDONS:format(table.concat(addonList(), ", "))
	local others = A.OtherBagAddons() -- week 9: a second bag addon on at the same time
	lines[#lines + 1] = L.REPORT_OTHER_BAGS:format(#others > 0 and table.concat(others, ", ") or L.REPORT_NONE)
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_MASQUE_OFF = "Masque: not loaded"
```

and replace it with:

```lua
L.REPORT_MASQUE_OFF = "Masque: not loaded"

-- Another bag addon on at the same time (week 9, user pick 11b): Core/Report.lua
L.OTHER_BAGS_WARN = "Another bag addon is on too: %s. Two bag addons fight over the same bags. Keep one: type"
	.. " /swagbag safe on to let it handle your bags and bank, or disable one in the AddOns list. SwagBag switches"
	.. " nothing off by itself."
L.REPORT_OTHER_BAGS = "Other bag addons on: %s"
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1488 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (75 files)`, `1488 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Core/Report.lua \
	SwagBag/Locale/enUS.lua \
	spec/report_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 9 Task 5: warn once at login when another bag addon is on; name it in the report

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 6: Week-8 deferred polish: the held F6 fallback, a secret item ID, a typed gold amount

The cheap, user-visible deferred items (D17). (1) The week-8 final re-review: when a list fell back to categories (F6) and that fallback had to wait for the mouse, the buttons the list had already shrunk stayed small under the categories still drawn until the retry landed (smaller click targets, and a shrunk button can slide under the mouse). Now a held fallback puts them back at full size at once, unless a list is what is drawn. (2) The same review: `Prices.Value` guarded a secret link but not a secret item ID; a secret item ID is now no key and no price, never an error (the draw path runs under `"bags"`). (3) Week 7, Task 7: an amount typed with `/swagbag worth 250` had no button on the Settings row, so nothing showed selected; it now gets its own selected choice next to 100g, 500g and 1000g.

**Files:**
- Modify: `SwagBag/UI/GroupView.lua`, `SwagBag/Engine/Prices.lua`, `SwagBag/UI/SettingsPages.lua`
- Test: `spec/bankwindow_list_spec.lua`, `spec/prices_spec.lua`, `spec/settings_spec.lua`

**Interfaces:**
- Consumes: GroupView's `listFailed`, `scaleAll`, `v.drawn`; `Prices.Value`; the worth row.
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests**

In `spec/bankwindow_list_spec.lua`, find:

```lua
	end)

	-- Week 8 (final review). The title says what is drawn. Mutation: in BW.ToggleView, flash
```

and replace it with:

```lua
	end)

	-- Week 8 deferred (final re-review): a held fallback left the buttons it had already shrunk small until the
	-- retry landed, under categories still drawn at full size (smaller click targets meanwhile). Mutation: in
	-- GroupView's listFailed(), `if not held or v.drawn ~= "list" then` -> `if not held then`.
	it("F6: a fallback held under the mouse puts the drawn categories' buttons back at full size at once", function()
		openBank()
		A.Clear(6, 1) -- a withdrawal: the full layout that follows regroups the potion's neighbours
		bankUpdate(6)
		B.Get(12, 2).SetScale = function() end
		B.Get(6, 3).IsMouseOver = function(self) return self.scale ~= 1 end -- shrunk, the flask slides under the mouse
		Fake.Fire(BW.viewButton, "OnClick")
		assert.equal("sections", BW.view.drawn, "held: the categories stay drawn")
		assert.equal(1, #B.placeholdersInUse, "nothing regrouped yet")
		for _, bag in ipairs({ 6, 12 }) do
			for slot = 1, 8 do
				assert.equal(1, B.Get(bag, slot).scale, bag .. ":" .. slot)
			end
		end
		A.Advance(GV.RETRY)
		assert.equal("sections", BW.view.drawn)
		assert.equal(0, #B.placeholdersInUse, "the retry landed the fallback")
	end)

	-- Week 8 (final review). The title says what is drawn. Mutation: in BW.ToggleView, flash
```

In `spec/prices_spec.lua`, find:

```lua
		assert.is_nil(P.boundCache[secretLink])
```

and replace it with:

```lua
		assert.is_nil(P.boundCache[secretLink])
	end)

	-- Week 8 deferred (final re-review). Mutation: drop the `if SB.Adapter.IsSecret(itemID) then` guard in P.Value.
	it("a secret item ID is no key either: no price, nothing cached under it, never an error", function()
		local secretID = 999999
		A.IsSecret = function(v) return v == secretID end
		assert.is_nil((P.Value(nil, secretID)))
		assert.is_nil(P.cache[secretID])
		assert.same({ 1500, "Vendor" }, { P.Value(nil, Fixtures.HERB) }, "a plain one still prices")
```

In `spec/settings_spec.lua`, find:

```lua
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
```

and replace it with:

```lua
	end)

	-- Week 7 deferred: an amount typed in chat had no button. Mutation: drop the custom-amount choice from the
	-- worth row.
	it("bank page: a gold amount set with /swagbag worth shows as its own selected choice", function()
		SB.Config.Set("prices.worthGold", 250)
		SW.Show("bank")
		assert.truthy(SW.selected[button("250g or more")])
		assert.falsy(SW.selected[button("100g or more")])
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1488 passed, 3 failed`. The failures, exactly:

- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > F6: a fallback held under the mouse puts the drawn categories' buttons back at full size at once`
- `spec/prices_spec.lua :: Prices (spec F10, 3.3) > a secret item ID is no key either: no price, nothing cached under it, never an error`
- `spec/settings_spec.lua :: Settings window > bank page: a gold amount set with /swagbag worth shows as its own selected choice`

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "F6: a fallback held under the mouse puts the drawn categories' buttons back at full size at once": in `SwagBag/UI/GroupView.lua`, `if not held or v.drawn ~= "list" then` → `if not held then`.
- "a secret item ID is no key either: no price, nothing cached under it, never an error": in `SwagBag/Engine/Prices.lua`, `if SB.Adapter.IsSecret(itemID) then ⏎ itemID = nil -- nor a secret item ID (week 8 deferred): no key, no price ⏎ end` → ∅.
- "bank page: a gold amount set with /swagbag worth shows as its own selected choice": in `SwagBag/UI/SettingsPages.lua`, `if own ~= 100 and own ~= 500 and own ~= 1000 then` → `if false then`.

- [ ] **Step 3: Write the code**

In `SwagBag/Engine/Prices.lua`, find:

```lua
		link = nil -- a secret value is never a table key: price by itemID
```

and replace it with:

```lua
		link = nil -- a secret value is never a table key: price by itemID
	end
	if SB.Adapter.IsSecret(itemID) then
		itemID = nil -- nor a secret item ID (week 8 deferred): no key, no price
```

In `SwagBag/UI/GroupView.lua`, find:

```lua
		if not held then -- a held fallback leaves the buttons as drawn until the retry lands it
```

and replace it with:

```lua
		-- A held fallback leaves a drawn list as it is until the retry lands it; drawn categories or grid get their
		-- buttons back at full size at once (week 8 deferred: some were shrunk already, smaller click targets).
		if not held or v.drawn ~= "list" then
```

In `SwagBag/UI/SettingsPages.lua` (edit 1 of 2), find:

```lua
-- Bank and guild bank -----------------------------------------------------
```

and replace it with:

```lua
-- Bank and guild bank -----------------------------------------------------
-- The gold glow's amounts; one typed with /swagbag worth (say 250) gets its own button, selected (week 7 deferred).
local function worthChoices()
	local list = {}
	for _, gold in ipairs({ 100, 500, 1000 }) do
		list[#list + 1] = { value = gold, text = L.SET_WORTH_GOLD:format(gold) }
	end
	local own = SB.Config.Get("prices.worthGold")
	if own ~= 100 and own ~= 500 and own ~= 1000 then
		list[#list + 1] = { value = own, text = L.SET_WORTH_GOLD:format(own) }
	end
	list[#list + 1] = { value = "top", text = L.SET_WORTH_TOP:format(SB.Config.Get("prices.worthTop")) }
	list[#list + 1] = { value = "off", text = L.SET_OFF }
	return list
end

```

In `SwagBag/UI/SettingsPages.lua` (edit 2 of 2), find:

```lua
		end, choices = { { value = 100, text = L.SET_WORTH_GOLD:format(100) },
			{ value = 500, text = L.SET_WORTH_GOLD:format(500) }, { value = 1000, text = L.SET_WORTH_GOLD:format(1000) },
			{ value = "top", text = L.SET_WORTH_TOP:format(SB.Config.Get("prices.worthTop")) },
			{ value = "off", text = L.SET_OFF } },
```

and replace it with:

```lua
		end, choices = worthChoices(),
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1491 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (75 files)`, `1491 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Prices.lua \
	SwagBag/UI/GroupView.lua \
	SwagBag/UI/SettingsPages.lua \
	spec/bankwindow_list_spec.lua \
	spec/prices_spec.lua \
	spec/settings_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 9 Task 6: week-8 polish: a held F6 fallback restores full size, secret item IDs, a typed gold amount

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

## In-game sessions

Three short sessions: ST1, TS1 and MQ1. All three run on the **final merged build** (every task done, reviewed and fixed), as week 6's ruling P1 set; the "checks Task N" in each heading only says which task's work it checks. Then the week-9 exit check. They never block the build: findings come back as fixes.

Before every session:
- Claude installs the build first. The game currently runs an older copy, and the login line must say `v0.9.0`.
- If anything shows a red error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After the session, reply "<session> done" and the numbers of any steps that didn't match.

Chat lines start with `SwagBag: `. Names, numbers and amounts like `<its name>`, `N` or `1g 2s 3c` are examples: yours will differ.

### Session ST1: partial stacks first (checks Tasks 1 and 2; about 15 minutes)

You need: in your bags, one item that stacks (potions, flasks, herbs, cloth...) with at least one **full** stack and some spare to split; an empty bag slot or three; a banker; for steps 13–16 the same kind of item to put in your bank.

How to split a stack (steps 5 and 12): hold Shift and left-click the stack, type a small number (say 3), press Enter, then left-click an empty bag slot. The new small stack lands there.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.9.0 loaded. Type /swagbag help for commands.`
3. Type `/swagbag sort`. Expected: `SwagBag: Sort buttons: Blizzard's sort. Type /swagbag sort stacks or sort blizzard.`
4. Type `/swagbag view grid` and press **B**. Expected: `SwagBag: SwagBag - grid view`, and your bags show every slot in the game's order (first bag first).
5. Split the item twice (see above), into two different empty slots that come **before** your full stack in the grid if you can (higher up). Expected: one full stack and three partial stacks of that item (the one you split from, and the two new ones). Move the mouse off the bags.
6. Type `/swagbag sort stacks`. Expected: `SwagBag: Sort now merges partial stacks, then puts each item's partial stack in front of its full ones. Nothing else moves.`
7. With the mouse **off** the bags, click `Sort` in the bags' title row. Expected: the title shows `Stacking...` for a moment; the partial stacks join one by one (about five moves a second); then the remaining partial stack of that item sits **before** its full stack(s) in the grid, and chat shows `SwagBag: Stacking done. Stacks merged: N. Partial stacks moved first: N.` (your numbers). Other items that had several partial stacks were stacked the same way; items with a single stack did not move. (Say if it felt too slow.)
8. Check the stacks: rest the mouse on each stack of that item in turn. Expected: the counts add up to what you had; nothing is on your cursor. Move the mouse off the bags.
9. Click `Sort` again. Expected: the title shows `Nothing to stack: each item has at most one partial stack, and it is already first.`; nothing moves.
10. (Optional, only with a stack you can split into two halves that do not fit in one stack, e.g. two stacks of 15 potions where 20 fit.) Click `Sort`. Expected: one becomes a full stack, the rest stays as one partial stack, and that partial is first; nothing is left on your cursor.
11. Lock the item: pick up one of its stacks (left-click) and drop it on the small `Lock` button right of the search box. Expected: `SwagBag: Locked: <its name>. SwagBag never sells it, and it shows a small lock.`
12. Split that item once more into an empty slot, move the mouse off the bags, and click `Sort`. Expected: `Nothing to stack: ...` in the title, and nothing moves (locked items stay put). Then drop the item on `Lock` again. Expected: `SwagBag: Unlocked: <its name>.`
13. Right-click a banker. Put two small stacks of one item into the **character bank** (in SwagBag's bank: they show in the `Character bank` group). Put one small stack of the same item into the **warband bank** if you can. Move the mouse off the windows.
14. Click `Sort bank` in the bank's title row. Expected: `Stacking...` in the bank's title, then the two character-bank stacks become one, chat shows `SwagBag: Stacking done. Stacks merged: 1. Partial stacks moved first: 0.` (or similar numbers), and the warband bank's stack is **not** touched.
15. Click `Sort warband`. Expected: only warband bank items are stacked (with a single stack there: `Nothing to stack: ...` in the title).
16. Make two or three small stacks in the character bank again, click `Sort bank` and at once walk away from the banker (or press Esc twice to close the bank). Expected: chat shows `SwagBag: Stacking stopped: the window closed (stacks merged: N, moved first: N).` Nothing is on your cursor, nothing is lost.
17. Type `/swagbag settings bags`. Expected: the Bags page has a row `The Sort buttons` with `Partial stacks first` selected. Click `Blizzard's sort`. Expected: the status line says `Sort now runs Blizzard's own sort.` (Keep whichever you prefer.)
18. Type `/swagbag view sections` to go back to your usual view (or `list`). Expected: `SwagBag: SwagBag - category view`.

(Combat stopping a run cannot be staged safely by hand; the unit tests cover it: the run stops before its next move and the line says `Stacking stopped: combat started (...)`.)

### Session TS1: TSM prices, and a typed gold amount (checks Tasks 3 and 6; about 10 minutes)

You need: TradeSkillMaster installed and enabled, with its prices loaded (its tooltip shows "Market Value" on items); a stack of something with an auction value (herbs, ore, a BoE). Auctionator may be on or off.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.9.0 loaded. Type /swagbag help for commands.`
3. Type `/swagbag price`. Expected: `SwagBag: Prices: auto (Auctionator, else TSM, else what a vendor pays). Answering now: Auctionator. Type /swagbag price auto, price auctionator, price tsm, price vendor, or price tsm <DBMarket|DBMinBuyout|DBRegionMarketAvg|DBRegionSaleAvg>.` (with `Answering now: TSM (DBMarket).` if Auctionator is not loaded).
4. Type `/swagbag price tsm`. Expected: `SwagBag: Prices now come from: TSM's DBMarket (else what a vendor pays).`
5. Press **B** and type `/swagbag view list`. Expected: `SwagBag: SwagBag - list view`. Rest the mouse on the name of your valuable stack's row. Expected: the Value column on that row is the stack's count times TSM's market value from TSM's own tooltip lines (rounded), and the section headers' totals use TSM's prices.
6. Type `/swagbag price tsm dbminbuyout`. Expected: `SwagBag: Prices now come from: TSM's DBMinBuyout (else what a vendor pays).` Within a second the Value column and the section totals change to TSM's minimum buyout.
7. Type `/swagbag report`, then look for the `Prices:` line. Expected: `Prices: TSM (DBMinBuyout), N cached`. Close the report box.
8. Type `/swagbag settings bank`. Expected: the `Bank & guild` page shows `Item prices come from` with `TSM` selected and `TSM price (when TSM answers)` with `DBMinBuyout` selected. Click `Auto`. Expected: the status line says `Prices now come from: auto (Auctionator, else TSM, else what a vendor pays).`
9. Click `DBMarket` on the TSM row. Expected: the status line says `Prices now come from: TSM's DBMarket (else what a vendor pays).` (The source is now TSM again; click `Auto` once more if you prefer Auctionator first.)
10. Close the settings window. Type `/swagbag worth 250`. Expected: `SwagBag: Gold glow at the bank: items worth 250g or more a stack.`
11. Type `/swagbag settings bank`. Expected: the row `Gold glow at the bank on items worth` shows a button `250g or more`, selected. Click `100g or more` (or keep 250). Close the settings window.
12. Type `/swagbag view sections` (or your usual view).

### Session MQ1: Masque skins and the second-bag-addon warning (checks Tasks 4 and 5; about 10 minutes)

You need: Masque installed and enabled (it comes with a few skins of its own); Baganator installed (you have it) for steps 11–14; a banker; a healing potion in your bags. Step 15 only if you use ElvUI.

0. Claude installs the build first.
1. Make sure Baganator is **disabled** in the AddOns list (character select, "AddOns"). Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.9.0 loaded. Type /swagbag help for commands.` and **no** line about another bag addon.
3. Type `/masque`. Expected: Masque's options open; under its add-ons list there is `SwagBag` with the group `Bags`, and `Bank` (if it is not there yet, it appears after your first bank visit; `Guild bank` and `Alt viewer` appear once you opened those windows this session).
4. In Masque's options pick a clearly different skin for SwagBag (for example "Zoomed" or "Blizzard Classic"), then close Masque's options and press **B**. Expected: SwagBag's item icons wear the new skin; counts, item levels and SwagBag's own marks still show.
5. Type `/swagbag view list`. Expected: the small icons on the rows wear the same skin and still line up with their rows.
6. Type `/swagbag view sections` (or your usual view). Right-click a banker. Expected: the bank's icons wear the skin too. Walk away until the bank closes.
7. Attack a training dummy (or start any fight). While in combat, right-click the healing potion in SwagBag's bags. Expected: you drink it; no "Interface action failed because of an AddOn" message.
8. Leave combat. Type `/swagbag report` and look for the `Masque:` line. Expected: `Masque: N buttons skinned` (a few hundred). Close the report box.
9. Type `/masque`, switch SwagBag's skin back to what you like (or turn SwagBag's groups off there). Expected: SwagBag follows at once.
10. Type `/swagbag report` and look for `Other bag addons on:`. Expected: `Other bag addons on: none`.
11. Log out, **enable** Baganator in the AddOns list, and log in again. Expected: chat shows `SwagBag: Another bag addon is on too: Baganator. Two bag addons fight over the same bags. Keep one: type /swagbag safe on to let it handle your bags and bank, or disable one in the AddOns list. SwagBag switches nothing off by itself.`
12. Type `/swagbag report`. Expected: the line `Other bag addons on: Baganator`. Baganator is still enabled (SwagBag disabled nothing). Close the report box.
13. Type `/swagbag safe on`. Expected: `SwagBag: Safe Mode is ON for bags: Blizzard's frames are used. Type /swagbag safe off to switch back.` and `SwagBag: Safe Mode is ON for bank: Blizzard's frames are used. Type /swagbag safe off to switch back.` Type `/reload`. Expected: no line about another bag addon this time.
14. Type `/swagbag safe off`. Expected: `SwagBag: Safe Mode is OFF for bags: SwagBag handles them again.` and `SwagBag: Safe Mode is OFF for bank: SwagBag handles them again.` Log out, **disable** Baganator again, and log in. Expected: no line about another bag addon.
15. (Only with ElvUI.) With ElvUI's own bags turned **on** in ElvUI's options, log in. Expected: the warning names `ElvUI`. With ElvUI's bags **off**, no warning.

## Week 9 exit check

1. Claude installs the week-9 build, at the end of Task 6 (after review and fixes), and you fully restart the game.
2. Play normally for a day, with keys, a vendor and a bank visit, with the Sort mode you prefer. Expected: no red errors; nothing moves under your mouse; nothing is ever left on your cursor; items stay in the bank type you put them in.
3. Type `/swagbag report` and paste it to Claude. Expected:
   - `Safe Mode: bags=off bank=off`;
   - `Failed checks: none`;
   - `Other bag addons on: none` (or the one you chose to keep, with Safe Mode on);
   - the `Prices:` line naming your source, and the `Masque:` line.


## Spec updates at week end

Recorded in the week-9 ledger and applied to `docs/superpowers/specs/2026-09-30-swagbag-design.md` at week end (this plan commits only the plan file):
- **§5.5 (Sort):** an optional SwagBag sort mode, `sort.mode = "stacks"` ("Partial stacks first"): merge each item's partial stacks, then put the partial stack in front of the full ones; nothing else moves; one scope per button (bags, character bank, warband bank), never across; locked, equipment-set, single, not-loaded and secret-link items stay put; out of combat, P5, one move per 0.2 s, a move that does nothing stops the run; combat or closing stops it, nothing queued; the outcome is one chat line. Blizzard's sort stays the default. Add ACs from Tasks 1–2's tests.
- **§3.3 / F10 (prices):** providers Auctionator (10), TSM (5, TradeSkillMaster's public addon API, price strings DBMarket / DBMinBuyout / DBRegionMarketAvg / DBRegionSaleAvg only) and the vendor (0); `prices.source` "auto" (by priority) or one of them; TSM refreshes by the cache age (no callback); `/swagbag price`. Header totals, the Value column, the gold glow and AC17.2's "worth more at auction" follow the choice (D13 noted).
- **§4.1 (buttons):** Masque: `AddButton(button, nil, "Item")` once per button, out of combat only; groups Bags, Bank, Guild bank, Alt viewer; no SwagBag setting (Masque's options).
- **P4 / §10.4:** another bag addon on: one login line (silent in Safe Mode), never disabled; the report's `Other bag addons on:` and `Masque:` lines; `Prices:` names TSM's string.
- **§8.2 (settings):** `sort.mode`, `prices.source`, `prices.tsm` (explicit defaults, schema 2), share-string words.
- **§9 (secret values):** a secret item ID is no price key.
- **F6 / ruling W5-1:** a held fallback under drawn categories restores full size at once.
- **§10.5 (commands):** `/swagbag sort [stacks|blizzard]`, `/swagbag price [auto|auctionator|tsm [<price>]|vendor]`.
- **§11 / §12 (the Adapter rule):** `TSM_API` and `LibStub` are named only in the Adapter (check.sh).

## Spec coverage (week-9 scope → task)

| Requirement (from the brief) | Task |
|---|---|
| 1a. Research whether Blizzard's sort can do partial stacks first | D3 (no options), Task 1 intro |
| 1b. An optional sort mode (Settings + /swagbag), off by default, used when Sort is pressed | T2 (D1) |
| 1c. Merge partial stacks of the same item, then order partial stacks first | T1 (D2, D4) |
| 1d. Out of combat, never under the mouse, small timed steps, identity checks, bags and bank | T1 (D7), T2 (P5 per window) |
| 1e. Never the wrong bank type; never locked or equipment-set items; stop cleanly on combat/close | T1 (D5, D6, D9), T2 (bank scope, close) |
| 2a. TSM as a price source when loaded; Settings Auctionator / TSM / vendor; default Auctionator, else TSM, else vendor | T3 (D10) |
| 2b. A selectable TSM price string, default DBMarket | T3 (D11) |
| 2c. Through the Adapter only, secret-safe, cached like Auctionator, invalidated if TSM offers it | T3 (D12; check.sh) |
| 2d. Header totals, Value column, worth glow, vendor protections use the chosen source | T3 (D13) |
| 3a. Masque groups for bags, bank, guild, list-row icons; never secure attributes, never reparent, never in combat; clean without Masque | T4 (D14, D15) |
| 3b. Warn once at login about another bag addon (incl. ElvUI's bags), suggest /swagbag safe on or disabling one; never auto-disable; in /swagbag report | T5 (D16) |
| 4. Week-8 deferred polish (held F6 fallback, secret itemID) and other cheap ones; the rest listed | T6 (D17); "Carry-overs" |
| Version 0.9.0 in Task 1 | T1 |
| Adapter-only rule extended to TSM_API and LibStub | T3 (check.sh), Global Constraints |

## How this plan was checked (while writing it)

- Every task was first built on a scratch clone at `/tmp/sb9` (outside the repo), one commit per task, test-first: each task's tests were run against the previous task's code (red) and then against its own (green). Every block in this file was then generated from those commits' diffs by a script: each find block is grown line by line until it occurs exactly once in the file as it is after the earlier edits, and starts and ends on a non-blank line; the script re-applied every block to the old file and compared the result with the commit's file.
- **Replay.** A fresh clone of `ae00814` (`/tmp/sb9b`) was driven by a script that reads this file: for each task it applies the Step 1 blocks, runs the suite, applies the Step 3 blocks, runs the suite and `scripts/check.sh`, then commits. Every find block occurred exactly once when applied; every Step 2 count and FAIL list (name by name), every Step 4 total, every Step 5 `ALL CHECKS PASSED` and TOC count, and every Step 6 `git add` list (equal to the files the task changed) above is that script's output. Final total: **1491 passed, 0 failed**.
- **Mutations.** Every mutation listed under a Step 2 (48 in all) was applied, one at a time, to its own task's replayed commit, and the whole suite run: every one made its named test fail.
- **check.sh's new rule** was checked by hand on Task 3's code: a comment `-- TSM_API` added to `Providers/TSM.lua` makes it print `FAIL: TSM_API or LibStub named outside SwagBag/Core/Adapter.lua (comments included)` and `CHECKS FAILED`; removing it passes again.
- **The F6 polish test** reproduces the real mechanism: a button shrunk for the list moves (its point's offsets are in its own scale) and can slide under a resting mouse, which holds the fallback; the test's button reports the mouse over it only while shrunk.
- Greps on the final tree:
  - no `C_`/`Enum.` outside `SwagBag/Core/Adapter.lua`, no bare `C_*` name, and no `TSM_API`/`LibStub` either (check.sh);
  - none of the forbidden tokens; no `SetParent`/`SetID`/`SetAttribute` on a slot button in any new code (the Skins test logs every call on a button);
  - no `OnUpdate`; no `Config` call at load;
  - no `%s` given a boolean (format51 runs on every spec).

## Self-review

1. **Scope coverage.** Every item of the brief maps to a task or a named decision in "Spec coverage", in the brief's priority order (stacking first, then TSM, then Masque and the warning, then the polish). Each open question has a decision row: the default and the switch (D1), what the mode does (D2) and why not Blizzard's sort (D3), which stack goes where (D4), scopes (D5), what stays put (D6), pace and stopping (D7, D9), how it answers (D8), the price source (D10), TSM's string (D11) and refresh (D12), the vendor rule (D13, flagged), Masque (D14, D15), the warning (D16), the polish (D17).
2. **Placeholder scan.** No "TBD", "TODO", "similar to", or test-free step. Every code step is a complete block (the replay applies them as written). The in-game expectations quote Locale strings verbatim; where a line holds the player's own numbers or names the step says so.
3. **Type and name consistency.** These names are the same in every task that uses them: `Adapter.MoveStack`, `SB.Stacker` (`Start`, `Busy`, `Stop`, `Plan`, `ResultText`, `DELAY`, `RETRY`, `MAX_WAITS`), the job's `kind`/`still`/`busy`/`done`, the result's `merged`/`ordered`/`kept`/`why` (T1 → T2); `sort.mode` and its words `"blizzard"`/`"stacks"` (T2: Config, Profiles, Stacker, SettingsPages, both windows); GroupView `v.Busy` (T2); `Adapter.TSM_PRICES/TSMAvailable/TSMPrice`, `Prices.CHOICES/Choice/TSMString/SourceText`, `prices.source`, `prices.tsm` (T3: Adapter, Prices, provider, Profiles, Settings, Report); `Adapter.MasqueAvailable/MasqueAdd`, `SB.Skins.Add/Available/count/GROUPS` (T4); `Adapter.OTHER_BAG_ADDONS/ElvUIBagsOn/OtherBagAddons` (T5). The Locale keys quoted in ST1, TS1 and MQ1 were checked against the blocks by a script.
4. **Review Focus.** Each of the nine lines names its pinning tests, and each of those tests is in its owning task's Step 1.
5. **Global Constraints.** No `C_`/`Enum.` or another addon's global outside the Adapter (check.sh enforces `TSM_API`/`LibStub` from Task 3). The stacker touches no button; Masque gets each button once, out of combat. Every new timer, listener and callback runs under `ErrorTrap.Guard`/`Run`/`SB.On` with the labels in P6. Every user-visible string is in `enUS.lua`. Three new settings with explicit defaults, schema 2, share-string words and labels. No `OnUpdate`; nothing runs while idle.
6. **Known limits, stated in the plan.** The order pass relies on the game swapping a partial stack with a full one of the same item (G1); if it does not, the run stops and nothing is lost. Choosing "Vendor" as the price source also judges gray BoEs by the vendor price (D13, flagged for the user). TSM prices refresh by the cache's 10-minute age (D12). A few bag-addon folder names are unverified (G8). The week-6 bank-speed part 2 still waits on TF1.
