# SwagBag Week 10: Lock warnings before a locked item is destroyed (spells, the delete box, the scrapper), and week-9 polish. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ] `) syntax for tracking.

**Goal:** the user asked "Will locking prevent disenchanting or similar as well?", then "Make it". Week 7's locks only stop SwagBag's own selling. Disenchanting, milling, prospecting, the scrapper and Blizzard's delete box are Blizzard's own flows: an addon that tried to cancel them would taint them ("Interface action failed because of an AddOn"), and stopping a click on a bag item needs a click hook, which spec §5.3 forbids. So this week SwagBag **warns, and never blocks**, in this order of priority, so the earlier ones ship first if time runs out:
1. **A red tooltip line while a spell waits for its target** (Disenchanting, Milling, Prospecting, or any other spell with the targeting hand): a locked item's tooltip says `Locked by you. SwagBag can't stop this spell: press Esc to cancel it.` right under its gold "Locked" line, through the tooltip hook SwagBag already has (D2, D3) (Task 1). The version goes to 0.10.0.
2. **The delete box:** when Blizzard asks "Do you want to destroy ...?" for a locked item, one red chat line names it, and a small note of SwagBag's own sits just above Blizzard's box: `This item is locked in SwagBag.` Blizzard's box is never touched (D5) (Task 2).
3. **The scrapper:** SwagBag cannot refuse a locked item there within the rules (D6). Instead, while the scrapper is open a locked item's tooltip says a right-click puts it in, and a locked item that lands in a scrapper slot gets one red chat line saying how to take it out (Task 3).
4. **One switch:** Settings > Vendor > "Warn before destroying locked items" (On, the default / Off), `/swagbag lock warn [on|off]`, and a `/swagbag report` line (D7) (Task 4).
5. **Week-9 deferred polish:** the bags and bank windows' layout guards also wait while a spell waits for its target (`Adapter.CursorBusy`), so no other item slides under the targeting hand (D8) (Task 5); the spec notes that a pending item also waits for a hover (spec update at week end, D10). The rest stays deferred ("Carry-overs").

Tests go from 1522 to **1543**.

**Architecture:**
- (1) `UI/LockWarnings.lua` (new, `SB.LockWarnings`): `LW.On()` (the `locks.warn` setting), `LW.TooltipText()` (the red line for a locked item right now, or nil). `Engine/Locks.lua`'s `Locks.TooltipLine` (already hooked at login by `UI/LockButton.lua` through `Adapter.HookItemTooltip`, the taint-free `TooltipDataProcessor` post-call, under `"none"`) adds that line right under its "Locked" line through the new `Adapter.TooltipWarning`. `Adapter.SpellTargeting()` exposes week 9's `SpellIsTargeting()` read.
- (2) `LW.OnDelete` listens to `DELETE_ITEM_CONFIRM` (the item is still on the cursor: Blizzard's Yes runs `DeleteCursorItem()`); for a locked item it prints one red line and, a moment later (`Adapter.After(0)`, once Blizzard's own handler of the same event has shown the box), `LW.ShowNote` anchors SwagBag's own plain frame above the box that `Adapter.DeletePopup()` finds (`StaticPopup_FindVisible` over the four delete kinds). `LW.CheckDelete` hides it once the item left the cursor (`ITEM_LOCK_CHANGED`, `BAG_UPDATE_DELAYED`, `CURSOR_CHANGED`).
- (3) `LW.scrapper` follows `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/_HIDE` for the scrapper (`Adapter.IsScrapper`); `LW.CheckScrapper` reads the slots (`Adapter.ScrapperItemIDs`, read only) on `SCRAPPING_MACHINE_PENDING_ITEM_CHANGED`.
- (4) `/swagbag lock warn` in `Engine/Locks.lua`'s `lock` command; a row in `UI/SettingsVendor.lua`; a line in `Core/Report.lua`.
- (5) `UI/BagsWindow.lua` and `UI/GroupView.lua`: every layout guard that read `Adapter.CursorItem()` reads `Adapter.CursorBusy()` (the drops that need the item itself keep `CursorItem`).

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105; 12.1.5 goes live 2026-10-13). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- F18 (item locks) gains warnings before a locked item is destroyed (new AC18.3, AC18.4 at week end);
- §5.3 (taint rules) as it stands: nothing new hooks a click, a Blizzard frame or a Blizzard dialog; every new piece only reads and writes SwagBag's own lines and frame;
- §4.2 rule 5 (nothing moves under the mouse or while anything is on the cursor) for every layout of the bags and bank windows, a spell waiting for its target included;
- §10.4 (`/swagbag report`) and §10.5 (commands): the Locks line and `/swagbag lock warn`.
The spec text is updated at week end (see "Spec updates at week end"). All rights reserved: every idea here is clean-room; no code is copied from any other addon. Only the public APIs named in "What the week relies on" are called.

Ledgers (binding rulings W3-*, W4-*, W5-*, week 6, week 7 R1–R22, week 8 Q1–Q13, week 9 R0, S1–S20): `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md` through `2026-10-08-swagbag-week9-ledger.md`. Week-9 plan (style and interfaces): `docs/superpowers/plans/2026-10-08-swagbag-week9-sort-tsm-masque.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week10` is already checked out. It was made from `week9` at `7ee3958` (v0.9.0, the week-9 ledger and preflight; **week 9 is not merged to `main` yet**, so everything here is based on `7ee3958`). The suite has 1522 tests. No task creates or switches branches.

**The code at `7ee3958` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). These interfaces are used as they are on `7ee3958`:
- `SB.On(event, fn, window)` (an event WoW refuses is skipped, never an error), `SB.Emit`, `SB.ErrorTrap.Run/Guard/OnError/Recent`, `SB.Print`, `SB.Slash.Register/Dispatch`.
- `SB.Config.Get/Set/readOnly/db/Init`; `Config.Set` returns false while read-only.
- `SB.Locks` (`Has`, `Toggle`, `List`, `Name`, `TooltipLine`, the `lock` command), `UI/LockButton.lua` (hooks `Locks.TooltipLine` at `SB_LOGIN` with `Adapter.HookItemTooltip(Guard("tooltip.lock", ..., "none"))`), `UI/SettingsVendor.lua` (rows `kind = "choice"`, `SettingsWindow.RunCommand`).
- `SB.Report.Build`, `L.OVERLAY_ON/OFF`, `L.SET_ON/OFF`, `L.SETTINGS_READONLY`.
- `UI/BagsWindow.lua`'s guards (`busyCheck`, `W.Resize`, `W.Restack`, `W.RequestLayout`, `W.ApplyChanges`' area check, the W4-25 grow), `UI/GroupView.lua`'s `busyCheck`.
- Adapter: `A.CursorItem`, `A.CursorBusy` (week 9: any `GetCursorInfo()` answer or `SpellIsTargeting()`), `A.HookItemTooltip`, `A.TooltipLine`, `A.After`, `A.IsGuildBanker` (the pattern for `A.IsScrapper`), `A.CHECKS`.
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua` (`Fake.New`, `Fake.Fire`, `Fake.Strict`, `Fake.Install/Uninstall`), `uienv.lua` (`Env.ENGINE`), `spec/fixtures/items.lua` (`Fixtures.FLASK` "Flask of Alchemical Chaos", `Fixtures.HEALING_POTION` "Algari Healing Potion", `Fixtures.SmallBags`), `spec/mock_adapter.lua` (week 9's `m.cursor`, `m.cursorOther = "targeting"` for a spell waiting for its target, `m.CursorBusy`), and `format51` (installed by the runner).



## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.10.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. New this week, all in the Adapter and all read only: `SpellIsTargeting()` (already read since week 9, now also exposed), `StaticPopup_FindVisible(which)`, `Enum.PlayerInteractionType.ScrappingMachine`, `C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex(index)`, `C_Item.GetItemID(itemLocation)`; four optional entries in `A.CHECKS`. Events: `DELETE_ITEM_CONFIRM`, `CURSOR_CHANGED`, `SCRAPPING_MACHINE_PENDING_ITEM_CHANGED` (new), `ITEM_LOCK_CHANGED`, `BAG_UPDATE_DELAYED`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/_HIDE` (already used).
- TOC metadata unchanged (`## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator, ElvUI, TradeSkillMaster, Masque`). One file is added: `UI/LockWarnings.lua` (Task 1, right after `UI/LockButton.lua`): the TOC goes from 75 to 76 files.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets a string or a number, never a boolean or nil. Every spec runs under `spec/helpers/format51.lua`.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace, `Enum`, ElvUI, Syndicator, `TSM_API` or `LibStub`, **comments included** (`scripts/check.sh`). This week `C_ScrappingMachineUI`, `C_Item.GetItemID` and `Enum.PlayerInteractionType` stay in the Adapter; `UI/LockWarnings.lua` calls `SB.Adapter.*` only.
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`. `SetCurrentGuildBankTab` is never called.
- **Warnings only, never a block (this week's binding rule).** Nothing this week cancels a spell (`SpellStopTargeting` is never called), clicks, hides, disables or re-texts a Blizzard button or dialog, writes to `StaticPopupDialogs`, calls a `C_ScrappingMachineUI` function that changes anything (`RemoveItemToScrap`, `ScrapItems`, `DropPendingScrapItemFromCursor`, `CloseScrappingMachine` are never named), or hooks a click. **Secure item buttons** (`ContainerFrameItemButtonTemplate`) get no script and no hook of any kind; the only tooltip hook is the existing `TooltipDataProcessor` post-call. SwagBag's delete note is its own plain frame, parented to `UIParent`, anchored to Blizzard's box (an anchor on SwagBag's frame, never a call on the box), taking no mouse.
- P1: every setting ships with a chosen default, and its alternative sits next to it in the same place. This week: `locks.warn` "On" first, "Off" next (Settings > Vendor > "Warn before destroying locked items", `/swagbag lock warn on|off`).
- P2: every command, button and settings choice answers **exactly once**: `/swagbag lock warn` in chat; a Settings click in the status line (through the command). The warnings themselves: one tooltip line per refresh (the tooltip's own), one chat line per delete box, one chat line per locked item landing in the scrapper (again only after it was taken out and put back).
- P5 / spec §4.2 rule 5: nothing moves under the mouse or while anything is on the cursor. From Task 5 every layout guard of the bags and bank windows reads `Adapter.CursorBusy()` (an item, money, a spell, a merchant's item, or **a spell waiting for its target**); the drops that need the item itself (a section header, the Lock button, the Consumables page) keep `Adapter.CursorItem()`.
- **P6.** Every WoW entry point runs inside `SB.ErrorTrap.Run` or `Guard`. The labels this week, all `"none"` (recorded for `/swagbag report`, never Safe Mode): the tooltip line (inside the existing `tooltip.lock` guard), the listeners `event:DELETE_ITEM_CONFIRM`, `event:ITEM_LOCK_CHANGED`, `event:BAG_UPDATE_DELAYED`, `event:CURSOR_CHANGED`, `event:PLAYER_INTERACTION_MANAGER_FRAME_SHOW`, `event:PLAYER_INTERACTION_MANAGER_FRAME_HIDE`, `event:SCRAPPING_MACHINE_PENDING_ITEM_CHANGED` (`SB.On(..., "none")`), the note's timer (`lockwarn.note`), and the `lock` command (`Slash.Register`'s default window).
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`. The red chat lines carry their colour inside the Locale string (`|cffff4444...|r`, as `L.CHECK_FAIL_LINE` since week 1); the red tooltip line gets its colour from `Adapter.TooltipWarning`.
- **Plain frames only, may be created in combat:** the delete note (`CreateFrame("Frame", nil, UIParent)`, made at its first use).
- **Settings and saved data (schema stays 2):** one new key with an explicit default in `Config.Defaults`: `locks.warn = true` (Task 1). Only values somebody wrote are stored, so no migration. It is a boolean, so `Engine/Profiles.lua` checks it by its type; `LABELS` names it (`SET_LOCK_WARN`; the week-7 test "every known setting has a label" covers it). The writer refuses while `Config.readOnly` and says `L.SETTINGS_READONLY`. (`SwagBagDB.settings.locks` is a different table from week 7's lock set `SwagBagDB.locks`.)
- No file calls `Config` at load time (the load-order tests stay green). Every `OnHide` handler starts with `if self:IsShown() then return end` (none is added this week: the note has no scripts).
- No `OnUpdate` anywhere. Idle CPU with every window closed is 0: the warnings run only on a tooltip refresh of a locked item, on the four events above, and `LW.CheckDelete` returns at once unless a delete box for a locked item is up.
- Every critical test names the mutation that must make it fail. Each task lists its mutations under Step 2.
- **Tooling (binding, as in weeks 1–9):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). Where a test fakes a Blizzard API, it fakes it the way the real one behaves (`StaticPopup_FindVisible` returns the shown dialog or nil; the scrapper's slots are numbered from 0, as in Blizzard's own `Blizzard_ScrappingMachineUI`). CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Test totals are cumulative from 1522 (see "Schedule").
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

These are the failure modes most likely to bite the user that the spec implies but the feature tests would not naturally hit, most likely first. Each is pinned by tests in the task that owns the code.

1. **SwagBag touching Blizzard's destroy flows** (a taint that makes Disenchant, Delete or Scrap fail with "Interface action failed because of an AddOn", or a box whose buttons stop working). Expected: SwagBag only reads; its note is its own frame; no click hook (check.sh forbids `PreClick`/`PostClick`). Pinned by Task 2: "a note sits just above Blizzard's delete box, which is never touched; it goes once the item leaves the cursor" (every method call on the box is logged by `Fake.Strict`: none) and "DeletePopup finds Blizzard's shown delete box of any of its four kinds; none, or an error, is nil"; Task 3: "ScrapperItemIDs reads the scrapper's nine slots, numbered from 0; empty, broken and secret ones are skipped" (only the read call is faked: any other call would error). In game: LW1 steps 7 and 9 (G2, G3).
2. **A warning on the wrong item, or none on a locked one** (a red line on an unlocked item teaches the user to ignore it; a missing one is the loss the user asked about). Expected: only a locked item ID gets a line, every kind of delete box counts. Pinned by Task 1: "while a spell waits for its target, a locked item's tooltip gets the red line; nothing otherwise"; Task 2: "deleting a locked item: one red chat line naming it; an unlocked item, an empty cursor or the switch off: none", "DeletePopup finds Blizzard's shown delete box of any of its four kinds; none, or an error, is nil"; Task 3: "while the scrapper is open, a locked item's tooltip says a right-click puts it in; once closed, nothing", "a locked item put in the scrapper: one red chat line; again only once taken out and put back".
3. **An error on the tooltip or event path** (the tooltip refreshes five times a second; the events fire for every item pick-up). Expected: recorded under `"none"` at most, never Safe Mode, never a red Lua error; a missing Blizzard box is no error. Pinned by Task 2: "when Blizzard's box is not found, only the chat line: no note, nothing recorded"; Task 1: "SpellTargeting reads SpellIsTargeting; none, false or an error is no"; Task 3: the scrapper read test (a failing slot is skipped).
4. **An item sliding under the targeting hand** (a regroup while Disenchant waits would put a different item, maybe a locked one, under the click). Expected: every layout of the bags and bank windows waits while a spell waits for its target. Pinned by Task 5: "a spell waiting for its target holds a header click's collapse; it applies once cast or cancelled", "a full layout waits while a spell waits for its target, then runs", "a shorter footer waits while a spell waits for its target, then fits the window", "hidden New: an arrival waits while a spell waits for its target; New shows once it is cast or cancelled", "W4-25: the grow waits while a spell waits for its target; it applies once cast or cancelled", "a spell waiting for its target holds every move and every push too".
5. **Noise** (a chat line at every scrapper change, a note left on the screen after the box closed). Expected: one line per locked item landing in the scrapper; the note goes when the item leaves the cursor; one switch silences all. Pinned by Task 3: "a locked item put in the scrapper: one red chat line; again only once taken out and put back"; Task 2: the note test; Task 1: "with the warning switched off (locks.warn) the tooltip keeps only its Locked line"; Task 4: "/swagbag lock warn says the state, switches it, refuses while read-only, and answers every form", "the destroy-warning row: On first and selected; Off runs /swagbag lock warn off and says so".



## Decisions (every product default chosen this week, read before Task 1)

| # | Question | This plan (the default) | The alternative, and where it is | Why |
|---|---|---|---|---|
| D1 | Block, or warn? | **Warn, never block.** No spell is cancelled, no Blizzard button clicked, hidden or disabled, no dialog changed, no click hooked. | — (blocking is not possible within the rules; see Why). | Disenchant, Milling and Prospecting are spells cast on a target the player clicks; the delete box's Yes runs `DeleteCursorItem()`; the scrapper's slots fill from Blizzard's own `UseContainerItem` on the secure bag button. Cancelling any of them from an addon means a click hook on a secure button (`PreClick`, forbidden by spec §5.3 and check.sh) or calling into a protected flow from tainted code, which risks "Interface action failed because of an AddOn" in the very flows the user relies on. |
| D2 | Which spells get the tooltip line | **Any spell waiting for its target** (`SpellIsTargeting()`), not a list of spell IDs. | — | The client has no call that names the spell behind the targeting hand, and `UNIT_SPELLCAST_SENT` fires only once a target is clicked (too late). A list (Disenchanting 13262, Milling 51005, Prospecting 31252, and each expansion's extras such as Dragonflight's crushing and shuffling recipes) would rot with every patch. Every spell that targets an item changes or uses up the item (an enchant replaces the old one), so the line is right for all of them: "SwagBag can't stop this spell: press Esc to cancel it." Simpler and safer. |
| D3 | Which tooltips | **Every item tooltip of a locked item** that the existing hook sees (the main tooltip and the chat-link tooltip, F20): SwagBag's bags, bank and guild bank, and Blizzard's own bags in Safe Mode. The red line comes **right under** the gold `Locked in SwagBag: never sold by SwagBag`. | — | It is the hook week 7 already uses (taint-free `TooltipDataProcessor` post-call, under `"none"`); a lock is per item ID (week 7), so every copy warns. |
| D4 | The wording | Tooltip, spell: `Locked by you. SwagBag can't stop this spell: press Esc to cancel it.` Tooltip, scrapper open: `Locked by you. SwagBag can't stop the scrapper: a right-click puts this item in it.` Chat lines in red, naming the item. | — | Plain English; Esc is the one action that cancels a waiting spell everywhere (a click elsewhere may cast it on something else). |
| D5 | The delete box | **One red chat line** (`<item> is locked in SwagBag. SwagBag can't stop Blizzard's delete: click No (or press Esc) to keep it.`) and **a note of SwagBag's own just above Blizzard's box** (`This item is locked in SwagBag.`, red on a dark bar, 300 × 24). The note goes as soon as the item leaves the cursor (Yes deletes it; No and Esc put it back). Blizzard's box itself is never touched; if a patch renames it, only the chat line comes. | — | Changing the box's own text (`StaticPopupDialogs`, the box's font string) would taint the dialog whose Yes calls `DeleteCursorItem()`. An anchor of SwagBag's own frame on the box is not a call on the box. The box is shown by Blizzard's handler of the same `DELETE_ITEM_CONFIRM` event, so the note looks for it a moment later (`Adapter.After(0)`). |
| D6 | The scrapper: refuse a locked item? | **No: warn.** While a scrapper is open, a locked item's tooltip says a right-click puts it in; a locked item that lands in a scrapper slot gets one red chat line: `<item> is locked in SwagBag and is now in the scrapper. SwagBag can't stop it: click it in the scrapper to take it out before you press Scrap.` Said once per item while it stays; again only after it was taken out and put back. | Taking locked items back out by itself (`C_ScrappingMachineUI.RemoveItemToScrap(index)` after `SCRAPPING_MACHINE_PENDING_ITEM_CHANGED`): **not this week**. | A right-click on SwagBag's bag button is Blizzard's own `UseContainerItem` on the secure template; SwagBag cannot see it before it happens without a `PreClick` (forbidden). `RemoveItemToScrap` is not marked protected in the client's API documentation (only "secret arguments allowed when untainted"), but calling it from an event handler is SwagBag acting inside Blizzard's machine, untested in game, and it would undo the user's own click without asking. If the user wants it, it can follow once session LW1 shows the events work (G5). |
| D7 | The switch | **One switch for all three warnings**, `locks.warn`, **on** by default: Settings > Vendor > "Warn before destroying locked items" (right under the lock rows), `/swagbag lock warn [on|off]`; `/swagbag report` says `Locks: N locked; destroy warnings on`. | Off: Settings > Vendor, or `/swagbag lock warn off`. | The brief's default. A separate scrapper setting is not needed: all three are warnings (nothing can go wrong by having them on). |
| D8 | The windows' layout guards (week-9 deferred) | **`Adapter.CursorBusy()`** in every guard of the bags window (`busyCheck`, `W.Resize`, `W.Restack`'s area wait, `W.RequestLayout`, `W.ApplyChanges`' hidden-New area check, the W4-25 grow) and the bank and guild bank group view (`busyCheck`). The drops that need the item itself (a section header, the Lock button, the Consumables page) keep `Adapter.CursorItem()`. The alt viewer (`UI/OfflineWindow.lua`) is left as it is: its items are snapshots that no spell can target. | — | Spec §4.2 rule 5 says "while `GetCursorInfo()` holds an item"; week 9 widened "anything on the cursor" for the item movers only. This week's feature is the reason to widen it everywhere: a regroup while Disenchant waits could slide another item (maybe a locked one) under the targeting hand, and the click would destroy that one. The wait costs nothing visible (layouts retry every 0.3 s, as for an item on the cursor). The spec wording is updated at week end. |
| D9 | Version | `0.10.0` (Task 1). | — | — |
| D10 | Week-9 deferred items | **This week:** D8 (code) and the spec note that a pending item (data not loaded, AC4.4) also stays in New until hovered, like every arrival since the week-9 New rule (AC3.3; a spec text update, no code). The rest stays deferred ("Carry-overs"). | — | Cheap and user-visible (the brief). |
| D11 | What the warnings do not cover | Stated in the Settings tip and here: hand-selling (week 7's buyback line covers it), mailing, trading, posting, using or equipping a locked item; and **destroy buttons of other addons** (TSM's destroying window, one-click mill/prospect addons) that cast the spell on the item directly, with no targeting hand: SwagBag sees no targeting and cannot warn. | — | Those are the user's own deliberate actions or another addon's secure buttons; SwagBag sees nothing it could read in time. |


## What the week relies on

| What | Name | Since | Confidence |
|---|---|---|---|
| A spell waiting for its target | `SpellIsTargeting()` (Adapter `A.SpellTargeting`, week 9's read in `A.CursorBusy`) | week 9 | Read only; pcall'd. That Disenchant, Milling and Prospecting show the targeting hand with it true: G1. |
| Item tooltips | `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)` (`A.HookItemTooltip`, week 4; the lock line since week 7). The tooltip refreshes about five times a second while hovered, so a spell cast while already hovering shows the line within a moment. | week 4 | G1 |
| The delete box | Event `DELETE_ITEM_CONFIRM(itemName, qualityID, bonding, questWarn)`; Blizzard's handler (`Blizzard_Game/Mainline/EventImplementation.lua`, `GameEvent.HandleDeleteItemConfirm`) shows `StaticPopup_Show("DELETE_ITEM" \| "DELETE_GOOD_ITEM" \| "DELETE_QUEST_ITEM" \| "DELETE_GOOD_QUEST_ITEM", itemName)`; the box's Yes calls `DeleteCursorItem()`, its No calls `ClearCursor()`, and it hides itself once `CursorHasItem()` is false (`Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua`): the item stays on the cursor while the box is up. `StaticPopup_FindVisible(which)` returns the shown box (`Blizzard_StaticPopup/StaticPopup.lua`). | new | Read from Blizzard's 12.1.5 interface source (Gethe/wow-ui-source, live branch) and warcraft.wiki.gg. G2, G3. |
| The note leaving | `ITEM_LOCK_CHANGED` (the item returns to its slot), `BAG_UPDATE_DELAYED` (it was deleted), `CURSOR_CHANGED` (a third chance; `SB.On` skips it without an error if a patch removes it) | ITEM_LOCK_CHANGED, BAG_UPDATE_DELAYED since week 1 | G2, G4 |
| The scrapper | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/_HIDE(type)` with `Enum.PlayerInteractionType.ScrappingMachine` (40); `SCRAPPING_MACHINE_PENDING_ITEM_CHANGED`; `C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex(index)` (slots 0–8, as Blizzard's own `Blizzard_ScrappingMachineUI` numbers them) and `C_Item.GetItemID(itemLocation)` | new | Read from the client's generated API documentation (`ScrappingMachineUIDocumentation.lua`, `PlayerInteractionManagerConstantsDocumentation.lua`) and Blizzard's scrapper UI. G5. |


## Needs in-game confirmation (what could not be verified at the desk)

Each item names the session step that checks it. None blocks the build; a wrong answer comes back as a fix.

| # | What | Why it is uncertain | Checked in |
|---|---|---|---|
| G1 | While Disenchanting (or Milling, Prospecting) waits for its target, a locked item's tooltip shows the red line, also when the spell was cast with the mouse already resting on the item | `SpellIsTargeting()` during these spells and the tooltip's refresh are modelled, not seen | LW1 steps 11–13 |
| G2 | Blizzard's delete box for a locked item comes with the red chat line, SwagBag's note sits just above the box, readable, covering nothing of it, and goes when the box closes | The box's frame, its position and the order of the two event handlers are read from Blizzard's source, not seen | LW1 steps 6–8 |
| G3 | Deleting a locked item with the note shown still works (Yes deletes, no "Interface action failed") | No taint path is known, but the delete flow is Blizzard's protected territory | LW1 step 9 |
| G4 | No note is ever left on the screen (after No, Esc, Yes, or walking away) | The events that hide it are chosen from the client's behaviour | LW1 steps 8, 9 |
| G5 | At a scrapper: the tooltip line while it is open, the chat line when a locked item lands in a slot, nothing once closed | The scrapper interaction type (40), the event and the slot numbering are read from the documentation | LW1 steps 15–18 (optional, needs a scrapper) |
| G6 | The red is readable on the tooltip and in chat | Taste | LW1 steps 6, 11 |
| G7 | Nothing in the bags moves while Disenchant waits for its target (loot or a bag change meanwhile waits) | Modelled by the tests; in game it is hard to stage | LW1 step 13 (watch the bags) |


## Carry-overs: what this week takes, and what stays deferred

Taken (the task that does it): week-9 final re-review minors "window layout guards use CursorItem not CursorBusy (per spec wording)" (Task 5, D8) and "AC4.4/§4.3 don't mention hover for pending items" ("Spec updates at week end", D10).

Checked and already done (no task): the week-9 final fix wave (`b3274d5`..`9a30914`) already fixed "error stop prints stuck wording", "MAX_PENDING path untested", the sell path's cached AH miss and `CursorBusy` with a spell waiting for its target.

Triaged and left deferred (not user-visible, test-only, by design, or needing an in-game look first):
- week-9 Task 1: an empty-error refusal records nothing; a not-loaded item is left out of the whole run; the run machinery is duplicated with the Mover; `Mover.IsBusy` uses `CursorBusy` (intended);
- week-9 Task 2: `St.SortButton` flashes `STACK_NOTHING` for a "combat" refusal (unreachable today); no list-view stacker busy test; a run survives close and quick reopen (same scope); `MOVER_BUSY` reused;
- week-9 Task 3: TSM names hardcoded in `PRICE_STATE`/`USAGE` strings; source words listed thrice; the report's cached count is approximate; `adapter_spec`'s `after_each` clears `issecretvalue` globally;
- week-9 Task 4: `Skins.Add` silent on a `MasqueAdd` false; the flush clears the queue before its loop; no offline test for list rows with Masque; overlays under Masque (left to MQ1 step 4, ruling);
- week-9 Task 5: redundant type guards inside pcall; `A.OtherBagAddons` unprotected in `Report.Build` (only matters if the client's addon API breaks);
- week-9 Task 6: the custom worth button shows unselected in top/off mode (by design: the way back to the typed amount); 100/500/1000 listed twice; no "recorded once" assertion across a held attempt;
- week-9 final re-review: the `new` search keyword and the New section are different sets (by design: the keyword is Blizzard's new-item flag); the unseen mark can drop across a multi-flush server sort; a consume and a loot in the same flush may miss New; Safe-Mode arrivals pile into New (both need an in-game look first);
- the week-8 and earlier items listed as deferred in the week-9 plan, unchanged; the week-6 bank-speed part 2 still waits on session TF1's numbers.

The week-9 sessions (ST1, TS1, MQ1, NW1) and the earlier open checks are unchanged by this plan.


---

## File structure (end of week 10)

New and changed files only. Everything else is as on `7ee3958`.

```
SwagBag/UI/LockWarnings.lua            NEW  (T1) LW.On, LW.TooltipText (a spell waiting); (T2) the delete box: OnDelete,
                                            ShowNote, CheckDelete, the note; (T3) the scrapper: its tooltip line,
                                            CheckScrapper
SwagBag/Core/Adapter.lua               MOD  (T1) SpellTargeting, TooltipWarning, SpellIsTargeting check; (T2) DELETE_POPUPS,
                                            DeletePopup, its check; (T3) IsScrapper, SCRAP_SLOTS, ScrapperItemIDs, two checks
SwagBag/Engine/Locks.lua               MOD  (T1) TooltipLine adds the red line; (T4) /swagbag lock warn
SwagBag/Core/Config.lua                MOD  (T1) locks.warn = true
SwagBag/Engine/Profiles.lua            MOD  (T1) the label for locks.warn
SwagBag/UI/SettingsVendor.lua          MOD  (T4) the "Warn before destroying locked items" row
SwagBag/Core/Report.lua                MOD  (T4) the Locks line
SwagBag/UI/BagsWindow.lua              MOD  (T5) every layout guard reads CursorBusy
SwagBag/UI/GroupView.lua               MOD  (T5) busyCheck reads CursorBusy
SwagBag/Locale/enUS.lua                MOD  (T1–T4)
SwagBag/SwagBag.toc                    MOD  (T1) LockWarnings, 0.10.0
SwagBag/Core/Init.lua                  MOD  (T1) 0.10.0
spec/lockwarnings_spec.lua (T1–T4)                                                                          NEW
spec/adapter_spec.lua (T1–T3), mock_adapter.lua (T1–T3), vendor_spec.lua (T4), report_spec.lua (T4),
spec/bagswindow_sections_spec.lua (T5), groupview_spec.lua (T5)                                             MOD
```

`TOC OK (76 files)` after every task.


## Schedule (week 10)

In priority order, so the earlier items ship first if time runs out. 12.1.5 goes live on 2026-10-13; nothing this week depends on it, and session LW1 can run on 12.1.0 or 12.1.5.

| Day | Tasks | User in game? |
|---|---|---|
| 1 | 1, 2, 3 | — |
| 1 | 4, 5 | after the merge: session LW1 (lock warnings, about 15 minutes) |
| 2 | final review, fixes | **Week 10 exit check** |

Cumulative `scripts/check.sh` test totals (from 1522 on `7ee3958`). Each was produced by replaying this file's blocks in order on a fresh clone of `7ee3958`:
- T1 1526 passed, 0 failed (+4)
- T2 1530 passed, 0 failed (+4)
- T3 1534 passed, 0 failed (+4)
- T4 1537 passed, 0 failed (+3; one existing test gains a row)
- T5 1543 passed, 0 failed (+6)

## How to read the code steps

- A **Create** step gives a complete new file.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point and its replacement. The block occurs exactly once in the file, and starts and ends on a non-blank line. When a step edits one file in several places, the places are numbered "(edit N of M)". Apply them in that order, top to bottom. Each find block is unique in the file as it is after the earlier edits.
- No step replaces a whole existing file.
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks (everything else). Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists its critical tests and, for each, the code change (mutation) that must make it fail. Every mutation was applied to the finished code of its task and the named test failed. A reviewer re-runs any of them with a one-line edit (Task 5 has two mutations of two or three edits: the guards there back each other up, and either alone still holds; that is the point). In a mutation, ` ⏎ ` marks a line break and `∅` an empty replacement; leading tabs are left out.
- A test that passes at Step 2 is named there with the reason (none this week).

---

### Task 1: A locked item's tooltip warns while a spell waits for its target (UI/LockWarnings.lua); v0.10.0

The user's question, first part: Disenchanting, Milling and Prospecting are spells that wait for a target (the targeting hand); the next click on an item casts them there, and SwagBag cannot stop that click (D1). So the tooltip of a locked item says so, in red, right under its gold "Locked" line, while any spell waits for its target (D2, D3, D4). The line comes from `Locks.TooltipLine`, which `UI/LockButton.lua` has hooked at login since week 7 through the taint-free tooltip post-call under `"none"`, so nothing new is hooked. The new `UI/LockWarnings.lua` holds the warnings and their switch (`locks.warn`, on by default; its command and Settings row come in Task 4). The Adapter exposes week 9's `SpellIsTargeting()` read as `Adapter.SpellTargeting` and adds `Adapter.TooltipWarning` (a red line that wraps). The version goes to 0.10.0.

**Files:**
- Create: `SwagBag/UI/LockWarnings.lua`, `spec/lockwarnings_spec.lua`
- Modify: `SwagBag/Core/Adapter.lua` (`A.SpellTargeting`, `A.TooltipWarning`, the `SpellIsTargeting` check), `SwagBag/Engine/Locks.lua` (`TooltipLine`), `SwagBag/Core/Config.lua` (`locks.warn`), `SwagBag/Engine/Profiles.lua` (its label), `SwagBag/Locale/enUS.lua`
- Modify: `SwagBag/SwagBag.toc` (the new file; 0.10.0), `SwagBag/Core/Init.lua` (0.10.0)
- Test: `spec/adapter_spec.lua`, `spec/mock_adapter.lua` (`m.SpellTargeting`)

**Interfaces:**
- Consumes: `Locks.Has`, `Locks.TooltipLine` (hooked by `UI/LockButton.lua`), `Adapter.TooltipLine`, week 9's `spellTargeting()` inside the Adapter, `Config.Get`.
- Produces: `Adapter.SpellTargeting() -> bool`; `Adapter.TooltipWarning(tooltip, text)`; `SB.LockWarnings` with `On() -> bool`, `TooltipText() -> text | nil`; the setting `locks.warn` (default `true`); `L.LOCK_WARN_SPELL`, `L.SET_LOCK_WARN`; `SB.VERSION = "0.10.0"`.

- [ ] **Step 1: Write the failing tests**

In `spec/adapter_spec.lua`, find:

```lua
		assert.falsy(A.MasqueAdd("Bags", "button1"))
	end)
end)
```

and replace it with:

```lua
		assert.falsy(A.MasqueAdd("Bags", "button1"))
	end)
end)

-- Week 10 (lock warnings, UI/LockWarnings.lua): what SwagBag reads to warn about a locked item, never to stop
-- anything.
describe("Adapter lock-warning helpers (week 10)", function()
	local A, tip
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		tip = { lines = {} }
		function tip.AddLine(_, ...)
			tip.lines[#tip.lines + 1] = { ... }
		end
	end)

	after_each(function()
		SpellIsTargeting = nil
	end)

	-- Mutation: in A.SpellTargeting, `return spellTargeting()` -> `return cursorHeld()`.
	it("SpellTargeting reads SpellIsTargeting; none, false or an error is no", function()
		assert.falsy(A.SpellTargeting(), "no API")
		SpellIsTargeting = function() return false end
		assert.falsy(A.SpellTargeting())
		SpellIsTargeting = function() return true end
		assert.truthy(A.SpellTargeting())
		SpellIsTargeting = function() error("broken") end
		assert.falsy(A.SpellTargeting(), "an error is no answer")
	end)

	-- Mutation: in A.TooltipWarning, drop the last `true` (the line would run off the tooltip's edge).
	it("TooltipWarning adds one red line that wraps; an error is not swallowed", function()
		A.TooltipWarning(tip, "careful")
		assert.same({ { "careful", 1, 0.27, 0.27, true } }, tip.lines)
		assert.has_error(function() A.TooltipWarning({}, "x") end)
	end)
end)
```

Create `spec/lockwarnings_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 10 (the user: "Will locking prevent disenchanting or similar as well?" -> "Make it"): SwagBag cannot stop
-- Blizzard's disenchanting, milling, prospecting, scrapping or deleting without tainting them, so it warns about a
-- locked item instead, and never blocks, cancels, clicks or hides anything of Blizzard's.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Lock warnings (week 10)", function()
	local SB, A, L, Locks, warned, tip
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
		SB = Loader.New(files)
		A, L, Locks = SB.Adapter, SB.L, SB.Locks
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/LockWarnings.lua")
		warned = {}
		A.TooltipWarning = function(_, text)
			warned[#warned + 1] = text
		end
		tip = Fake.New("GameTooltip")
		Locks.Toggle(Fixtures.FLASK)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- Mutations: in LW.TooltipText, `if SB.Adapter.SpellTargeting() then` -> `if true then`; or in
	-- Locks.TooltipLine, drop the `local warn = ...` block.
	it("while a spell waits for its target, a locked item's tooltip gets the red line; nothing otherwise", function()
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.same({}, warned, "no spell waiting: only the Locked line")
		assert.equal(L.LOCK_TOOLTIP, tip.calls.AddLine[1])
		A.cursorOther = "targeting" -- Disenchant (or Milling, Prospecting, an enchant) waits for its target
		Locks.TooltipLine(tip, Fixtures.FLASK)
		Locks.TooltipLine(tip, Fixtures.HEALING_POTION)
		assert.same({ L.LOCK_WARN_SPELL }, warned, "the locked item only")
	end)

	-- Mutation: in LW.TooltipText, drop `if not LW.On() then return nil end`.
	it("with the warning switched off (locks.warn) the tooltip keeps only its Locked line", function()
		assert.truthy(SB.Config.Get("locks.warn"), "on by default")
		SB.Config.Set("locks.warn", false)
		A.cursorOther = "targeting"
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.same({}, warned)
		assert.equal(L.LOCK_TOOLTIP, tip.calls.AddLine[1])
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
		return m.cursor ~= nil or m.cursorOther ~= nil
	end
```

and replace it with:

```lua
		return m.cursor ~= nil or m.cursorOther ~= nil
	end

	-- Week 10: a spell waiting for its target is m.cursorOther = "targeting" (as above).
	function m.SpellTargeting()
		return m.cursorOther == "targeting"
	end
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1522 passed, 4 failed`. The failures, exactly:

- `spec/adapter_spec.lua :: Adapter lock-warning helpers (week 10) > SpellTargeting reads SpellIsTargeting; none, false or an error is no`
- `spec/adapter_spec.lua :: Adapter lock-warning helpers (week 10) > TooltipWarning adds one red line that wraps; an error is not swallowed`
- `spec/lockwarnings_spec.lua :: Lock warnings (week 10) > while a spell waits for its target, a locked item's tooltip gets the red line; nothing otherwise`
- `spec/lockwarnings_spec.lua :: Lock warnings (week 10) > with the warning switched off (locks.warn) the tooltip keeps only its Locked line`

The two Adapter tests fail because `A.SpellTargeting` and `A.TooltipWarning` do not exist yet; the two lock-warning tests fail because `UI/LockWarnings.lua` does not exist yet (their `before_each` loads it). The new mock function changes nothing for the existing tests.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "while a spell waits for its target, a locked item's tooltip gets the red line; nothing otherwise": in `SwagBag/UI/LockWarnings.lua`, `if SB.Adapter.SpellTargeting() then` → `if true then`.
- "while a spell waits for its target, a locked item's tooltip gets the red line; nothing otherwise": in `SwagBag/Engine/Locks.lua`, `local warn = SB.LockWarnings and SB.LockWarnings.TooltipText() ⏎ if warn then ⏎ SB.Adapter.TooltipWarning(tooltip, warn) ⏎ end` → ∅.
- "with the warning switched off (locks.warn) the tooltip keeps only its Locked line": in `SwagBag/UI/LockWarnings.lua`, `if not LW.On() then ⏎ return nil ⏎ end` → ∅.
- "SpellTargeting reads SpellIsTargeting; none, false or an error is no": in `SwagBag/Core/Adapter.lua`, `function A.SpellTargeting() ⏎ return spellTargeting()` → `function A.SpellTargeting() ⏎ return cursorHeld()`.
- "TooltipWarning adds one red line that wraps; an error is not swallowed": in `SwagBag/Core/Adapter.lua`, `tooltip:AddLine(text, 1, 0.27, 0.27, true)` → `tooltip:AddLine(text, 1, 0.27, 0.27)`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua` (edit 1 of 3), find:

```lua
-- Puts a picked-up item back where it came from.
```

and replace it with:

```lua
-- Week 10 (UI/LockWarnings.lua): a spell waits for its target (Disenchant, Milling, Prospecting, an enchant...), so
-- the next click on an item casts it there. Read only, to warn: SwagBag never cancels or changes the spell.
function A.SpellTargeting()
	return spellTargeting()
end

-- Puts a picked-up item back where it came from.
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 3), find:

```lua
-- "|cffRRGGBB" for a class file name ("MAGE") from the client's class colours, or nil.
```

and replace it with:

```lua
-- Week 10: one red warning line, wrapped (UI/LockWarnings.lua). Errors are not caught here either.
function A.TooltipWarning(tooltip, text)
	tooltip:AddLine(text, 1, 0.27, 0.27, true)
end

-- "|cffRRGGBB" for a class file name ("MAGE") from the client's class colours, or nil.
```

In `SwagBag/Core/Adapter.lua` (edit 3 of 3), find:

```lua
	{ path = "GameTooltip", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "SpellIsTargeting", window = "bags", required = false },
	{ path = "GameTooltip", window = "bags", required = false },
```

In `SwagBag/Core/Config.lua`, find:

```lua
		tooltip = { counts = "auto" },
	},
```

and replace it with:

```lua
		tooltip = { counts = "auto" },
		-- warn (week 10, UI/LockWarnings.lua): warn before a locked item is destroyed (a spell waiting for its
		-- target, the delete box, the scrapper). Warnings only: SwagBag never stops Blizzard's own flows.
		locks = { warn = true },
	},
```

In `SwagBag/Core/Init.lua`, find:

```lua
SB.VERSION = "0.9.0"
```

and replace it with:

```lua
SB.VERSION = "0.10.0"
```

In `SwagBag/Engine/Locks.lua` (edit 1 of 2), find:

```lua
--   Locks.TooltipLine(tooltip, itemID)   the item tooltip's "Locked" line (UI/LockButton.lua hooks it)
```

and replace it with:

```lua
--   Locks.TooltipLine(tooltip, itemID)   the item tooltip's "Locked" line (UI/LockButton.lua hooks it), and under
--     it the red warning of UI/LockWarnings.lua while the item could be destroyed (week 10)
```

In `SwagBag/Engine/Locks.lua` (edit 2 of 2), find:

```lua
		SB.Adapter.TooltipLine(tooltip, L.LOCK_TOOLTIP)
	end
```

and replace it with:

```lua
		SB.Adapter.TooltipLine(tooltip, L.LOCK_TOOLTIP)
		-- Week 10: right under it, a red warning while the item could be destroyed (UI/LockWarnings.lua).
		local warn = SB.LockWarnings and SB.LockWarnings.TooltipText()
		if warn then
			SB.Adapter.TooltipWarning(tooltip, warn)
		end
	end
```

In `SwagBag/Engine/Profiles.lua`, find:

```lua
	["sort.mode"] = "SET_SORT",
```

and replace it with:

```lua
	["sort.mode"] = "SET_SORT", ["locks.warn"] = "SET_LOCK_WARN",
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
	.. " switches an addon off. Bag modules inside UI suites (KkthnxUI, NDui, GW2_UI, Tukui) are not recognised."
```

and replace it with:

```lua
	.. " switches an addon off. Bag modules inside UI suites (KkthnxUI, NDui, GW2_UI, Tukui) are not recognised."

-- Lock warnings (week 10): UI/LockWarnings.lua
L.LOCK_WARN_SPELL = "Locked by you. SwagBag can't stop this spell: press Esc to cancel it."
L.SET_LOCK_WARN = "Warn before destroying locked items"
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
## Version: 0.9.0
```

and replace it with:

```text
## Version: 0.10.0
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
UI/TinyHost.lua
```

and replace it with:

```text
UI/LockWarnings.lua
UI/TinyHost.lua
```

Create `SwagBag/UI/LockWarnings.lua`:

```lua
-- SwagBag lock warnings (week 10; the user: "Will locking prevent disenchanting or similar as well?", then
-- "Make it"). Disenchanting, milling, prospecting, the scrapper and the delete box are Blizzard's own flows: an
-- addon that tried to cancel them would taint them ("Interface action failed because of an AddOn"). So SwagBag
-- never blocks, cancels, clicks, hides or changes anything there (no click hook of any kind, spec 5.3). It
-- warns instead, for the items the user locked (Engine/Locks.lua):
--   a locked item's tooltip gets a red line under its "Locked" line while a spell waits for its target (any
--   spell: SpellIsTargeting names none, and a click would cast it on the item);
-- One switch for every warning: locks.warn (default on).
--   LW.On() -> bool
--   LW.TooltipText() -> the red tooltip line for a locked item right now, or nil
local _, SB = ...

local L = SB.L
local LW = {}
SB.LockWarnings = LW

function LW.On()
	return SB.Config.Get("locks.warn") == true
end

function LW.TooltipText()
	if not LW.On() then
		return nil
	end
	if SB.Adapter.SpellTargeting() then
		return L.LOCK_WARN_SPELL
	end
	return nil
end
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1526 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (76 files)`, `1526 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Core/Config.lua \
	SwagBag/Core/Init.lua \
	SwagBag/Engine/Locks.lua \
	SwagBag/Engine/Profiles.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/LockWarnings.lua \
	spec/adapter_spec.lua \
	spec/lockwarnings_spec.lua \
	spec/mock_adapter.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 10 Task 1: a locked item's tooltip warns while a spell waits for its target; v0.10.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 2: Blizzard's delete box for a locked item: one red chat line and SwagBag's own note above the box

The second part: dropping an item outside the windows makes Blizzard ask whether to destroy it (`DELETE_ITEM_CONFIRM`; the item stays on the cursor while the box is up: Yes runs `DeleteCursorItem()`, No puts it back). For a locked item SwagBag prints one red chat line naming it and how to keep it, and, a moment later, once Blizzard's own handler of the same event has shown the box, places a small note of its own just above the box (D5). The note is SwagBag's plain frame, anchored to the box; no call is ever made on the box, and `StaticPopupDialogs` is never written. It goes as soon as the item has left the cursor (an `ITEM_LOCK_CHANGED`, `BAG_UPDATE_DELAYED` or `CURSOR_CHANGED` with something else, or nothing, on the cursor). If a patch renames the box, only the chat line comes; nothing is recorded as an error.

**Files:**
- Modify: `SwagBag/UI/LockWarnings.lua`, `SwagBag/Core/Adapter.lua` (`A.DELETE_POPUPS`, `A.DeletePopup`, the `StaticPopup_FindVisible` check), `SwagBag/Locale/enUS.lua`
- Test: `spec/lockwarnings_spec.lua`, `spec/adapter_spec.lua`, `spec/mock_adapter.lua` (`m.deletePopup`, `m.DeletePopup`)

**Interfaces:**
- Consumes: `Adapter.CursorItem/After`, `Locks.Has/Name`, `LW.On`, `ErrorTrap.Guard`, `SB.On`.
- Produces: `Adapter.DELETE_POPUPS` (the four kinds), `Adapter.DeletePopup() -> frame | nil`; `LW.OnDelete()`, `LW.ShowNote()`, `LW.CheckDelete()`, `LW.deleting` (the item ID while its box is up), `LW.note` (made at first use, `LW.NOTE_WIDTH` 300, `LW.NOTE_HEIGHT` 24); `L.LOCK_WARN_DELETE`, `L.LOCK_WARN_NOTE`.

- [ ] **Step 1: Write the failing tests**

In `spec/adapter_spec.lua` (edit 1 of 3), find:

```lua
-- luacheck: globals SpellIsTargeting
```

and replace it with:

```lua
-- luacheck: globals SpellIsTargeting StaticPopup_FindVisible
```

In `spec/adapter_spec.lua` (edit 2 of 3), find:

```lua
		SpellIsTargeting = nil
```

and replace it with:

```lua
		SpellIsTargeting, StaticPopup_FindVisible = nil, nil
```

In `spec/adapter_spec.lua` (edit 3 of 3), find:

```lua
		assert.has_error(function() A.TooltipWarning({}, "x") end)
	end)
end)
```

and replace it with:

```lua
		assert.has_error(function() A.TooltipWarning({}, "x") end)
	end)

	-- Mutation: in A.DELETE_POPUPS, keep "DELETE_ITEM" only (a rare item's box would be missed).
	it("DeletePopup finds Blizzard's shown delete box of any of its four kinds; none, or an error, is nil", function()
		assert.is_nil(A.DeletePopup(), "no API")
		local box = {}
		StaticPopup_FindVisible = function(which)
			if which == "DELETE_GOOD_QUEST_ITEM" then
				return box
			end
		end
		assert.equal(box, A.DeletePopup())
		StaticPopup_FindVisible = function() return nil end
		assert.is_nil(A.DeletePopup())
		StaticPopup_FindVisible = function() error("renamed") end
		assert.is_nil(A.DeletePopup(), "an error is no box")
	end)
end)
```

In `spec/lockwarnings_spec.lua`, find:

```lua
		assert.equal(L.LOCK_TOOLTIP, tip.calls.AddLine[1])
	end)
end)
```

and replace it with:

```lua
		assert.equal(L.LOCK_TOOLTIP, tip.calls.AddLine[1])
	end)

	-- Mutations: in LW.OnDelete, `SB.Locks.Has(itemID)` -> `true` (every deleted item would warn); or
	-- `LW.On() and` -> `true and`.
	it("deleting a locked item: one red chat line naming it; an unlocked item, an empty cursor or the switch off: none", function()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		assert.same({ L.LOCK_WARN_DELETE:format("Flask of Alchemical Chaos") }, A.Lines())
		A.cursor = { itemID = Fixtures.HEALING_POTION, link = "item:211880" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Algari Healing Potion", 1, 0, 0)
		A.cursor = nil
		SB.Emit("DELETE_ITEM_CONFIRM", "Algari Healing Potion", 1, 0, 0)
		SB.Config.Set("locks.warn", false)
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		assert.equal(1, #A.Lines())
	end)

	-- Mutations: in LW.ShowNote, drop `n:Show()`; or in LW.CheckDelete, drop `note:Hide()`.
	it("a note sits just above Blizzard's delete box, which is never touched; it goes once the item leaves the cursor", function()
		local popup = Fake.Strict(Fake.New("Frame", UIParent))
		A.deletePopup = popup
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		assert.is_nil(SB.LockWarnings.note, "placed a moment later, once Blizzard's box is up")
		A.Advance(0)
		local note = SB.LockWarnings.note
		assert.truthy(note.shown)
		assert.equal(L.LOCK_WARN_NOTE, note.text.text)
		assert.same({ "BOTTOM", popup, "TOP", 0, 4 }, note.points[1])
		SB.Emit("ITEM_LOCK_CHANGED", 0, 2)
		assert.truthy(note.shown, "still on the cursor: the box is still up")
		A.cursor = nil -- No or Esc (Blizzard puts it back), or Yes (deleted)
		SB.Emit("ITEM_LOCK_CHANGED", 0, 2)
		assert.falsy(note.shown)
		assert.same({}, popup.log, "never a call on Blizzard's box")
	end)

	-- Mutation: in LW.ShowNote, drop `if not popup then return end`.
	it("when Blizzard's box is not found, only the chat line: no note, nothing recorded", function()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		SB.Emit("DELETE_ITEM_CONFIRM", "Flask of Alchemical Chaos", 3, 1, 0)
		A.Advance(0)
		assert.is_nil(SB.LockWarnings.note)
		assert.equal(1, #A.Lines())
		assert.same({}, SB.ErrorTrap.Recent())
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
		return m.cursorOther == "targeting"
	end
```

and replace it with:

```lua
		return m.cursorOther == "targeting"
	end

	-- Week 10: m.deletePopup = a frame: Blizzard's delete box is shown.
	m.deletePopup = nil
	function m.DeletePopup()
		return m.deletePopup
	end
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1526 passed, 4 failed`. The failures, exactly:

- `spec/adapter_spec.lua :: Adapter lock-warning helpers (week 10) > DeletePopup finds Blizzard's shown delete box of any of its four kinds; none, or an error, is nil`
- `spec/lockwarnings_spec.lua :: Lock warnings (week 10) > deleting a locked item: one red chat line naming it; an unlocked item, an empty cursor or the switch off: none`
- `spec/lockwarnings_spec.lua :: Lock warnings (week 10) > a note sits just above Blizzard's delete box, which is never touched; it goes once the item leaves the cursor`
- `spec/lockwarnings_spec.lua :: Lock warnings (week 10) > when Blizzard's box is not found, only the chat line: no note, nothing recorded`

`A.DeletePopup` does not exist yet, and nothing listens to `DELETE_ITEM_CONFIRM` (no chat line, no note); the mock's new `m.DeletePopup` changes nothing for the existing tests.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "deleting a locked item: one red chat line naming it; an unlocked item, an empty cursor or the switch off: none": in `SwagBag/UI/LockWarnings.lua`, `if not (itemID and LW.On() and SB.Locks.Has(itemID)) then` → `if not (itemID and LW.On() and true) then`.
- "deleting a locked item: one red chat line naming it; an unlocked item, an empty cursor or the switch off: none": in `SwagBag/UI/LockWarnings.lua`, `if not (itemID and LW.On() and SB.Locks.Has(itemID)) then` → `if not (itemID and true and SB.Locks.Has(itemID)) then`.
- "a note sits just above Blizzard's delete box, which is never touched; it goes once the item leaves the cursor": in `SwagBag/UI/LockWarnings.lua`, `n:Show()` → ∅.
- "a note sits just above Blizzard's delete box, which is never touched; it goes once the item leaves the cursor": in `SwagBag/UI/LockWarnings.lua`, `if note then ⏎ note:Hide() ⏎ end` → ∅.
- "when Blizzard's box is not found, only the chat line: no note, nothing recorded": in `SwagBag/UI/LockWarnings.lua`, `if not popup then ⏎ return -- the box was not found (renamed by a patch?): the chat line has said it ⏎ end` → ∅.
- "DeletePopup finds Blizzard's shown delete box of any of its four kinds; none, or an error, is nil": in `SwagBag/Core/Adapter.lua`, `A.DELETE_POPUPS = { "DELETE_ITEM", "DELETE_GOOD_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_QUEST_ITEM" }` → `A.DELETE_POPUPS = { "DELETE_ITEM" }`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
-- "|cffRRGGBB" for a class file name ("MAGE") from the client's class colours, or nil.
```

and replace it with:

```lua
-- Week 10: Blizzard's delete box, while one of its four kinds is shown (StaticPopup_FindVisible), else nil. Read
-- only: UI/LockWarnings.lua anchors its own note above it and never calls anything on the box.
A.DELETE_POPUPS = { "DELETE_ITEM", "DELETE_GOOD_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_QUEST_ITEM" }
function A.DeletePopup()
	local find = _G.StaticPopup_FindVisible
	if type(find) ~= "function" then
		return nil
	end
	for _, which in ipairs(A.DELETE_POPUPS) do
		local ok, box = pcall(find, which)
		if ok and box then
			return box
		end
	end
	return nil
end

-- "|cffRRGGBB" for a class file name ("MAGE") from the client's class colours, or nil.
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "GameTooltip", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "StaticPopup_FindVisible", window = "bags", required = false },
	{ path = "GameTooltip", window = "bags", required = false },
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SET_LOCK_WARN = "Warn before destroying locked items"
```

and replace it with:

```lua
L.SET_LOCK_WARN = "Warn before destroying locked items"
L.LOCK_WARN_DELETE = "|cffff4444%s is locked in SwagBag. SwagBag can't stop Blizzard's delete: click No (or press Esc)"
	.. " to keep it.|r"
L.LOCK_WARN_NOTE = "This item is locked in SwagBag."
```

In `SwagBag/UI/LockWarnings.lua` (edit 1 of 4), find:

```lua
-- One switch for every warning: locks.warn (default on).
```

and replace it with:

```lua
--   Blizzard's delete box for a locked item (DELETE_ITEM_CONFIRM, the item still on the cursor) gets one red
--   chat line, and SwagBag's own small note just above the box (its own frame; the box itself is never touched).
-- One switch for every warning: locks.warn (default on).
```

In `SwagBag/UI/LockWarnings.lua` (edit 2 of 4), find:

```lua
local _, SB = ...
```

and replace it with:

```lua
--   LW.OnDelete(), LW.ShowNote(), LW.CheckDelete()   the delete box's warning; LW.note (made at first use)
local _, SB = ...
```

In `SwagBag/UI/LockWarnings.lua` (edit 3 of 4), find:

```lua
local LW = {}
SB.LockWarnings = LW
```

and replace it with:

```lua
local LW = { NOTE_WIDTH = 300, NOTE_HEIGHT = 24 }
SB.LockWarnings = LW
```

In `SwagBag/UI/LockWarnings.lua` (edit 4 of 4), find:

```lua
		return L.LOCK_WARN_SPELL
	end
	return nil
end
```

and replace it with:

```lua
		return L.LOCK_WARN_SPELL
	end
	return nil
end

-- The delete box: Blizzard asks with DELETE_ITEM_CONFIRM while the item is still on the cursor (its Yes deletes
-- the cursor's item, its No puts it back).
function LW.OnDelete()
	local A = SB.Adapter
	local itemID = A.CursorItem()
	if not (itemID and LW.On() and SB.Locks.Has(itemID)) then
		return
	end
	LW.deleting = itemID
	SB.Print(L.LOCK_WARN_DELETE:format(SB.Locks.Name(itemID)))
	-- Blizzard shows its box from its own handler of the same event: the note looks for it a moment later.
	A.After(0, SB.ErrorTrap.Guard("lockwarn.note", LW.ShowNote, "none"))
end

local note

-- A plain frame of SwagBag's own (may be made in combat), never a child of the box and never taking the mouse.
local function makeNote()
	note = CreateFrame("Frame", nil, UIParent)
	note:SetFrameStrata("DIALOG")
	note:SetSize(LW.NOTE_WIDTH, LW.NOTE_HEIGHT)
	local bg = note:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(note)
	bg:SetColorTexture(0, 0, 0, 0.8)
	local text = note:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", note, "CENTER", 0, 0)
	text:SetTextColor(1, 0.27, 0.27)
	text:SetText(L.LOCK_WARN_NOTE)
	note.text = text
	note:Hide()
	LW.note = note
	return note
end

function LW.ShowNote()
	local A = SB.Adapter
	if not LW.deleting or A.CursorItem() ~= LW.deleting then
		return
	end
	local popup = A.DeletePopup()
	if not popup then
		return -- the box was not found (renamed by a patch?): the chat line has said it
	end
	local n = note or makeNote()
	n:ClearAllPoints()
	n:SetPoint("BOTTOM", popup, "TOP", 0, 4)
	n:Show()
end

-- The item left the cursor: deleted (Yes) or put back (No, Esc). The note goes with it.
function LW.CheckDelete()
	if LW.deleting and SB.Adapter.CursorItem() ~= LW.deleting then
		LW.deleting = nil
		if note then
			note:Hide()
		end
	end
end

SB.On("DELETE_ITEM_CONFIRM", LW.OnDelete, "none")
for _, event in ipairs({ "ITEM_LOCK_CHANGED", "BAG_UPDATE_DELAYED", "CURSOR_CHANGED" }) do
	SB.On(event, LW.CheckDelete, "none")
end
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1530 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (76 files)`, `1530 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/LockWarnings.lua \
	spec/adapter_spec.lua \
	spec/lockwarnings_spec.lua \
	spec/mock_adapter.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 10 Task 2: Blizzard's delete box for a locked item: a red chat line and SwagBag's own note above it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 3: The scrapper: a tooltip line while it is open, and a red chat line when a locked item lands in it

The third part. Research (D6): a right-click on a bag item while the scrapper is open is Blizzard's own `UseContainerItem` on the secure bag button, which puts the item in the scrapper; SwagBag cannot see that click before it happens without a `PreClick` (forbidden, spec §5.3). Taking it back out (`C_ScrappingMachineUI.RemoveItemToScrap`) would be SwagBag acting inside Blizzard's machine from an event, untested in game: not this week. So SwagBag warns: while the scrapper is open (`PLAYER_INTERACTION_MANAGER_FRAME_SHOW` / `_HIDE` for `Enum.PlayerInteractionType.ScrappingMachine`), a locked item's tooltip says a right-click puts it in (a spell waiting for its target is said first: the next click casts it); when a locked item lands in a scrapper slot (`SCRAPPING_MACHINE_PENDING_ITEM_CHANGED`, the slots read through `Adapter.ScrapperItemIDs`, slots 0–8 as Blizzard numbers them), one red chat line says how to take it out before pressing Scrap. Once per item while it stays; again only after it was taken out and put back. The `locks.warn` switch covers both.

**Files:**
- Modify: `SwagBag/UI/LockWarnings.lua`, `SwagBag/Core/Adapter.lua` (`A.IsScrapper`, `A.SCRAP_SLOTS`, `A.ScrapperItemIDs`, two checks), `SwagBag/Locale/enUS.lua`
- Test: `spec/lockwarnings_spec.lua`, `spec/adapter_spec.lua`, `spec/mock_adapter.lua` (`m.scrapper`, `m.ScrapperItemIDs`, `m.IsScrapper`)

**Interfaces:**
- Consumes: `LW.On`, `LW.TooltipText` (T1), `Locks.Has/Name`, `SB.On`.
- Produces: `Adapter.IsScrapper(interactionType) -> bool`, `Adapter.SCRAP_SLOTS` (9), `Adapter.ScrapperItemIDs() -> { itemID }`; `LW.scrapper` (bool), `LW.scrapWarned` (itemID → true), `LW.CheckScrapper()`; `L.LOCK_WARN_SCRAP`, `L.LOCK_WARN_SCRAP_ADDED`.

- [ ] **Step 1: Write the failing tests**

In `spec/adapter_spec.lua` (edit 1 of 3), find:

```lua
-- luacheck: globals SpellIsTargeting StaticPopup_FindVisible
```

and replace it with:

```lua
-- luacheck: globals SpellIsTargeting StaticPopup_FindVisible C_ScrappingMachineUI Enum
```

In `spec/adapter_spec.lua` (edit 2 of 3), find:

```lua
		SpellIsTargeting, StaticPopup_FindVisible = nil, nil
	end)
```

and replace it with:

```lua
		SpellIsTargeting, StaticPopup_FindVisible = nil, nil
		C_ScrappingMachineUI, C_Item, issecretvalue, Enum = nil, nil, nil, nil
	end)
```

In `spec/adapter_spec.lua` (edit 3 of 3), find:

```lua
		assert.is_nil(A.DeletePopup(), "an error is no box")
	end)
end)
```

and replace it with:

```lua
		assert.is_nil(A.DeletePopup(), "an error is no box")
	end)

	-- Mutation: in A.ScrapperItemIDs, `for index = 0, A.SCRAP_SLOTS - 1 do` -> `for index = 1, A.SCRAP_SLOTS do`.
	it("ScrapperItemIDs reads the scrapper's nine slots, numbered from 0; empty, broken and secret ones are skipped", function()
		assert.same({}, A.ScrapperItemIDs(), "no API")
		local asked, slots = {}, { [0] = { id = 211880 }, [3] = { id = 5 }, [8] = { id = 212283 } }
		C_ScrappingMachineUI = { GetCurrentPendingScrapItemLocationByIndex = function(i)
			asked[#asked + 1] = i
			if i == 4 then
				error("broken")
			end
			return slots[i]
		end }
		C_Item = { GetItemID = function(loc) return loc.id end }
		issecretvalue = function(v) return v == 5 end
		assert.same({ 211880, 212283 }, A.ScrapperItemIDs())
		assert.same({ 0, 1, 2, 3, 4, 5, 6, 7, 8 }, asked)
	end)

	-- Mutation: in A.IsScrapper, `PIT.ScrappingMachine` -> `PIT.GuildBanker` (both places).
	it("IsScrapper is true for the scrapper's interaction only", function()
		assert.falsy(A.IsScrapper(40), "no Enum")
		Enum = { PlayerInteractionType = { ScrappingMachine = 40, GuildBanker = 10 } }
		assert.truthy(A.IsScrapper(40))
		assert.falsy(A.IsScrapper(10))
	end)
end)
```

In `spec/lockwarnings_spec.lua`, find:

```lua
		assert.same({}, SB.ErrorTrap.Recent())
	end)
end)
```

and replace it with:

```lua
		assert.same({}, SB.ErrorTrap.Recent())
	end)

	-- Mutations: in LW.TooltipText, `if LW.scrapper then` -> `if false then`; or in the _HIDE listener,
	-- `LW.scrapper, LW.scrapWarned = false, {}` -> `LW.scrapWarned = {}`.
	it("while the scrapper is open, a locked item's tooltip says a right-click puts it in; once closed, nothing", function()
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "scrapper")
		Locks.TooltipLine(tip, Fixtures.FLASK)
		Locks.TooltipLine(tip, Fixtures.HEALING_POTION)
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "merchant")
		Locks.TooltipLine(tip, Fixtures.FLASK)
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "scrapper")
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.same({ L.LOCK_WARN_SCRAP, L.LOCK_WARN_SCRAP }, warned)
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "scrapper")
		A.cursorOther = "targeting"
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.equal(L.LOCK_WARN_SPELL, warned[3], "a spell waiting comes first: the next click casts it")
	end)

	-- Mutations: in LW.CheckScrapper, `not LW.scrapWarned[id]` -> `true` (a line at every change); or
	-- `LW.scrapWarned = seen` -> ∅ (an item taken out and put back would never be said again).
	it("a locked item put in the scrapper: one red chat line; again only once taken out and put back", function()
		SB.Emit("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "scrapper")
		A.scrapper = { Fixtures.HEALING_POTION }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		assert.same({}, A.Lines(), "not locked")
		A.scrapper = { Fixtures.HEALING_POTION, Fixtures.FLASK }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		A.scrapper = { Fixtures.HEALING_POTION, Fixtures.FLASK, Fixtures.FLASK }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		assert.same({ L.LOCK_WARN_SCRAP_ADDED:format("Flask of Alchemical Chaos") }, A.Lines())
		A.scrapper = { Fixtures.HEALING_POTION }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		A.scrapper = { Fixtures.FLASK }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		assert.equal(2, #A.Lines(), "taken out and put back: said again")
		SB.Config.Set("locks.warn", false)
		A.scrapper = {}
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		A.scrapper = { Fixtures.FLASK }
		SB.Emit("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED")
		assert.equal(2, #A.Lines(), "switched off: nothing")
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
		return m.deletePopup
	end
```

and replace it with:

```lua
		return m.deletePopup
	end

	-- Week 10: the scrapper. m.scrapper = { itemID, ... } in its slots; its interaction type is "scrapper".
	m.scrapper = {}
	function m.ScrapperItemIDs()
		return { unpack(m.scrapper) }
	end

	function m.IsScrapper(interactionType)
		return interactionType == "scrapper"
	end
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1530 passed, 4 failed`. The failures, exactly:

- `spec/adapter_spec.lua :: Adapter lock-warning helpers (week 10) > ScrapperItemIDs reads the scrapper's nine slots, numbered from 0; empty, broken and secret ones are skipped`
- `spec/adapter_spec.lua :: Adapter lock-warning helpers (week 10) > IsScrapper is true for the scrapper's interaction only`
- `spec/lockwarnings_spec.lua :: Lock warnings (week 10) > while the scrapper is open, a locked item's tooltip says a right-click puts it in; once closed, nothing`
- `spec/lockwarnings_spec.lua :: Lock warnings (week 10) > a locked item put in the scrapper: one red chat line; again only once taken out and put back`

`A.ScrapperItemIDs` and `A.IsScrapper` do not exist yet, and nothing follows the scrapper (no tooltip line, no chat line); the new mock functions change nothing for the existing tests.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "while the scrapper is open, a locked item's tooltip says a right-click puts it in; once closed, nothing": in `SwagBag/UI/LockWarnings.lua`, `if LW.scrapper then ⏎ return L.LOCK_WARN_SCRAP` → `if false then ⏎ return L.LOCK_WARN_SCRAP`.
- "while the scrapper is open, a locked item's tooltip says a right-click puts it in; once closed, nothing": in `SwagBag/UI/LockWarnings.lua`, `LW.scrapper, LW.scrapWarned = false, {}` → `LW.scrapWarned = {}`.
- "a locked item put in the scrapper: one red chat line; again only once taken out and put back": in `SwagBag/UI/LockWarnings.lua`, `and not LW.scrapWarned[id] and` → `and true and`.
- "a locked item put in the scrapper: one red chat line; again only once taken out and put back": in `SwagBag/UI/LockWarnings.lua`, `LW.scrapWarned = seen` → ∅.
- "ScrapperItemIDs reads the scrapper's nine slots, numbered from 0; empty, broken and secret ones are skipped": in `SwagBag/Core/Adapter.lua`, `for index = 0, A.SCRAP_SLOTS - 1 do` → `for index = 1, A.SCRAP_SLOTS do`.
- "IsScrapper is true for the scrapper's interaction only": in `SwagBag/Core/Adapter.lua`, `PIT.ScrappingMachine ~= nil and interactionType == PIT.ScrappingMachine` → `PIT.GuildBanker ~= nil and interactionType == PIT.GuildBanker`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
-- "|cffRRGGBB" for a class file name ("MAGE") from the client's class colours, or nil.
```

and replace it with:

```lua
-- Week 10: the scrapper, in PLAYER_INTERACTION_MANAGER_FRAME_SHOW / _HIDE.
function A.IsScrapper(interactionType)
	local PIT = Enum and Enum.PlayerInteractionType
	return PIT ~= nil and PIT.ScrappingMachine ~= nil and interactionType == PIT.ScrappingMachine
end

-- Week 10: the item IDs in the scrapper's slots (Blizzard numbers them from 0), read only: SwagBag never adds,
-- removes or scraps anything. A slot that is empty, fails or holds a secret ID is skipped.
A.SCRAP_SLOTS = 9
function A.ScrapperItemIDs()
	local S = _G.C_ScrappingMachineUI
	local out = {}
	if not (S and S.GetCurrentPendingScrapItemLocationByIndex and C_Item and C_Item.GetItemID) then
		return out
	end
	for index = 0, A.SCRAP_SLOTS - 1 do
		local ok, loc = pcall(S.GetCurrentPendingScrapItemLocationByIndex, index)
		if ok and loc then
			local okID, id = pcall(C_Item.GetItemID, loc)
			if okID and type(id) == "number" and not isSecret(id) then
				out[#out + 1] = id
			end
		end
	end
	return out
end

-- "|cffRRGGBB" for a class file name ("MAGE") from the client's class colours, or nil.
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "GameTooltip", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex", window = "bags", required = false },
	{ path = "C_Item.GetItemID", window = "bags", required = false },
	{ path = "GameTooltip", window = "bags", required = false },
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.LOCK_WARN_NOTE = "This item is locked in SwagBag."
```

and replace it with:

```lua
L.LOCK_WARN_NOTE = "This item is locked in SwagBag."
L.LOCK_WARN_SCRAP = "Locked by you. SwagBag can't stop the scrapper: a right-click puts this item in it."
L.LOCK_WARN_SCRAP_ADDED = "|cffff4444%s is locked in SwagBag and is now in the scrapper. SwagBag can't stop it:"
	.. " click it in the scrapper to take it out before you press Scrap.|r"
```

In `SwagBag/UI/LockWarnings.lua` (edit 1 of 5), find:

```lua
-- One switch for every warning: locks.warn (default on).
```

and replace it with:

```lua
--   The scrapper: SwagBag cannot refuse an item there (a right-click on a bag item is Blizzard's own
--   UseContainerItem; stopping it would need a click hook, spec 5.3). So while it is open a locked item's
--   tooltip says a right-click puts it in, and a locked item that lands in a scrapper slot gets one red chat line.
-- One switch for every warning: locks.warn (default on).
```

In `SwagBag/UI/LockWarnings.lua` (edit 2 of 5), find:

```lua
local _, SB = ...
```

and replace it with:

```lua
--   LW.CheckScrapper()   the scrapper's chat line; LW.scrapper (open), LW.scrapWarned (itemID -> true)
local _, SB = ...
```

In `SwagBag/UI/LockWarnings.lua` (edit 3 of 5), find:

```lua
local LW = { NOTE_WIDTH = 300, NOTE_HEIGHT = 24 }
```

and replace it with:

```lua
local LW = { NOTE_WIDTH = 300, NOTE_HEIGHT = 24, scrapper = false, scrapWarned = {} }
```

In `SwagBag/UI/LockWarnings.lua` (edit 4 of 5), find:

```lua
		return L.LOCK_WARN_SPELL
	end
```

and replace it with:

```lua
		return L.LOCK_WARN_SPELL
	end
	if LW.scrapper then
		return L.LOCK_WARN_SCRAP
	end
```

In `SwagBag/UI/LockWarnings.lua` (edit 5 of 5), find:

```lua
	SB.On(event, LW.CheckDelete, "none")
end
```

and replace it with:

```lua
	SB.On(event, LW.CheckDelete, "none")
end

-- The scrapper: open between PLAYER_INTERACTION_MANAGER_FRAME_SHOW and _HIDE for its interaction.
SB.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
	if SB.Adapter.IsScrapper(kind) then
		LW.scrapper, LW.scrapWarned = true, {}
	end
end, "none")
SB.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
	if SB.Adapter.IsScrapper(kind) then
		LW.scrapper, LW.scrapWarned = false, {}
	end
end, "none")

-- One line per locked item that lands in a slot; said again only after it was taken out and put back.
function LW.CheckScrapper()
	local seen = {}
	for _, id in ipairs(SB.Adapter.ScrapperItemIDs()) do
		if LW.On() and SB.Locks.Has(id) and not LW.scrapWarned[id] and not seen[id] then
			SB.Print(L.LOCK_WARN_SCRAP_ADDED:format(SB.Locks.Name(id)))
		end
		seen[id] = true
	end
	LW.scrapWarned = seen
end

SB.On("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED", LW.CheckScrapper, "none")
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1534 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (76 files)`, `1534 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/LockWarnings.lua \
	spec/adapter_spec.lua \
	spec/lockwarnings_spec.lua \
	spec/mock_adapter.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 10 Task 3: the scrapper: a tooltip line while open, a red chat line when a locked item lands in it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 4: The switch: /swagbag lock warn, Settings > Vendor, and the report line

D7: one switch for the three warnings. `/swagbag lock warn` says the state; `lock warn on` / `lock warn off` switch it (refused while read-only); anything else after `warn` gets its usage line (P2). Settings > Vendor gets a row "Warn before destroying locked items" (On first and selected, Off) right under the lock rows; a click runs the command, so the status line answers. `/swagbag report` says `Locks: N locked; destroy warnings on|off`. The `lock` command's help and usage lines name `warn`. The existing vendor-page test "defaults first ..." gains the row's two buttons.

**Files:**
- Modify: `SwagBag/Engine/Locks.lua` (the `lock` command), `SwagBag/UI/SettingsVendor.lua`, `SwagBag/Core/Report.lua`, `SwagBag/Locale/enUS.lua`
- Test: `spec/lockwarnings_spec.lua`, `spec/vendor_spec.lua`, `spec/report_spec.lua`

**Interfaces:**
- Consumes: `locks.warn` (T1), `Config.Set` (false while read-only), `SettingsWindow.RunCommand`, `L.OVERLAY_ON/OFF`, `L.SET_ON/OFF`.
- Produces: `/swagbag lock warn [on|off]`; the Settings > Vendor row; the report line; `L.LOCK_WARN_STATE/ON/OFF/USAGE`, `L.SET_LOCK_WARN_TIP`, `L.REPORT_LOCKS`; `L.HELP_LOCK` and `L.LOCK_USAGE` name `warn`.

- [ ] **Step 1: Write the failing tests**

In `spec/lockwarnings_spec.lua`, find:

```lua
		assert.equal(2, #A.Lines(), "switched off: nothing")
	end)
end)
```

and replace it with:

```lua
		assert.equal(2, #A.Lines(), "switched off: nothing")
	end)

	-- P2. Mutation: in the lock command, drop the `if not SB.Config.Set("locks.warn", word == "on") then` refusal
	-- (read-only would answer "now warns").
	it("/swagbag lock warn says the state, switches it, refuses while read-only, and answers every form", function()
		SB.Slash.Dispatch("lock warn")
		SB.Slash.Dispatch("lock warn off")
		SB.Slash.Dispatch("lock warn maybe")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("lock warn on")
		SB.Config.readOnly = false
		SB.Slash.Dispatch("lock warn on")
		assert.same({ L.LOCK_WARN_STATE:format("on"), L.LOCK_WARN_OFF, L.LOCK_WARN_USAGE, L.SETTINGS_READONLY,
			L.LOCK_WARN_ON }, A.Lines())
		assert.truthy(SB.Config.Get("locks.warn"))
	end)
end)
```

In `spec/report_spec.lua`, find:

```lua
	-- Week 9 (user pick 11b). Mutations: in A.OtherBagAddons drop the ElvUIBagsOn() check; or in A.ElvUIBagsOn
```

and replace it with:

```lua
	-- Week 10. Mutation: drop the Locks line from Report.Build.
	it("says how many items are locked and whether the destroy warnings are on", function()
		SB.Checks.last = {}
		SB.Locks = { List = function() return { 1, 2, 3 } end }
		assert.truthy(SB.Report.Build():find("\nLocks: 3 locked; destroy warnings on", 1, true))
		SB.Config.Set("locks.warn", false)
		assert.truthy(SB.Report.Build():find("\nLocks: 3 locked; destroy warnings off", 1, true))
	end)

	-- Week 9 (user pick 11b). Mutations: in A.OtherBagAddons drop the ElvUIBagsOn() check; or in A.ElvUIBagsOn
```

In `spec/vendor_spec.lua` (edit 1 of 2), find:

```lua
			{ "Off", false }, { "Drop an item here", false }, { "List them", false }, { "Unlock all", false } }, shown)
```

and replace it with:

```lua
			{ "Off", false }, { "Drop an item here", false }, { "List them", false }, { "Unlock all", false },
			{ "On", true }, { "Off", false } }, shown)
```

In `spec/vendor_spec.lua` (edit 2 of 2), find:

```lua
	-- Ruling R17. Mutation: the page's SB_LOCKS_CHANGED listener never re-draws (`if SW.IsOpen() then` ->
```

and replace it with:

```lua
	-- Week 10. Mutation: in the warning row's apply, always run "lock warn on".
	it("the destroy-warning row: On first and selected; Off runs /swagbag lock warn off and says so", function()
		local row
		for i = 1, SW.used.buttons do
			if SW.buttons[i].text == SB.L.SET_OFF then
				row = SW.buttons[i] -- the last Off on the page: the warning row's
			end
		end
		Fake.Fire(row, "OnClick")
		assert.equal(false, SB.Config.Get("locks.warn"))
		assert.equal(SB.L.LOCK_WARN_OFF, SW.lastStatus)
	end)

	-- Ruling R17. Mutation: the page's SB_LOCKS_CHANGED listener never re-draws (`if SW.IsOpen() then` ->
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1533 passed, 4 failed`. The failures, exactly:

- `spec/lockwarnings_spec.lua :: Lock warnings (week 10) > /swagbag lock warn says the state, switches it, refuses while read-only, and answers every form`
- `spec/report_spec.lua :: Report > says how many items are locked and whether the destroy warnings are on`
- `spec/vendor_spec.lua :: Settings: vendor page (week 7) > defaults first (On; Your gold), each click runs the command and answers in the status line`
- `spec/vendor_spec.lua :: Settings: vendor page (week 7) > the destroy-warning row: On first and selected; Off runs /swagbag lock warn off and says so`

The command has no `warn` form yet (it answers its usage line), the Vendor page has no warning row (the existing test now expects its two buttons; the new row test clicks the repair row's Off instead), and the report has no Locks line.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "/swagbag lock warn says the state, switches it, refuses while read-only, and answers every form": in `SwagBag/Engine/Locks.lua`, `if not SB.Config.Set("locks.warn", word == "on") then ⏎ return L.SETTINGS_READONLY ⏎ end` → `SB.Config.Set("locks.warn", word == "on")`.
- "the destroy-warning row: On first and selected; Off runs /swagbag lock warn off and says so": in `SwagBag/UI/SettingsVendor.lua`, `return run(v and "lock warn on" or "lock warn off")` → `return run("lock warn on")`.
- "says how many items are locked and whether the destroy warnings are on": in `SwagBag/Core/Report.lua`, `lines[#lines + 1] = L.REPORT_LOCKS:format(#SB.Locks.List(), SB.Config.Get("locks.warn") and L.OVERLAY_ON or L.OVERLAY_OFF)` → ∅.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Report.lua`, find:

```lua
	if SB.Theme and SB.Config.db then
```

and replace it with:

```lua
	if SB.Locks and SB.Config.db then -- week 10: the locks and their destroy warnings
		lines[#lines + 1] = L.REPORT_LOCKS:format(#SB.Locks.List(), SB.Config.Get("locks.warn") and L.OVERLAY_ON or L.OVERLAY_OFF)
	end
	if SB.Theme and SB.Config.db then
```

In `SwagBag/Engine/Locks.lua` (edit 1 of 2), find:

```lua
-- /swagbag lock [list|clear|undo]: how to lock, the locked items, or unlock them all (P2).
```

and replace it with:

```lua
-- /swagbag lock [list|clear|undo|warn [on|off]]: how to lock, the locked items, unlock them all, or the warnings
-- before a locked item is destroyed (week 10) (P2).
```

In `SwagBag/Engine/Locks.lua` (edit 2 of 2), find:

```lua
		return n == 1 and L.LOCK_UNDONE_ONE or L.LOCK_UNDONE:format(n)
	end
```

and replace it with:

```lua
		return n == 1 and L.LOCK_UNDONE_ONE or L.LOCK_UNDONE:format(n)
	elseif arg:match("^warn") then -- week 10: the warnings before a locked item is destroyed (UI/LockWarnings.lua)
		local word = arg:match("^warn%s*(%a*)$")
		if word == "" then
			return L.LOCK_WARN_STATE:format(SB.Config.Get("locks.warn") and L.OVERLAY_ON or L.OVERLAY_OFF)
		elseif word ~= "on" and word ~= "off" then
			return L.LOCK_WARN_USAGE
		end
		if not SB.Config.Set("locks.warn", word == "on") then
			return L.SETTINGS_READONLY
		end
		return word == "on" and L.LOCK_WARN_ON or L.LOCK_WARN_OFF
	end
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 3), find:

```lua
L.HELP_LOCK = "lock [list|clear|undo]: how to lock items (drag one onto Lock), list the locked ones, unlock them all"
	.. " (asks first), or bring back the ones the last unlock-all removed"
```

and replace it with:

```lua
L.HELP_LOCK = "lock [list|clear|undo|warn [on|off]]: how to lock items (drag one onto Lock), list the locked ones,"
	.. " unlock them all (asks first), bring back the ones the last unlock-all removed, or switch the warnings before"
	.. " a locked item is destroyed"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 3), find:

```lua
L.LOCK_USAGE = "Use /swagbag lock, lock list, lock clear, or lock undo."
```

and replace it with:

```lua
L.LOCK_USAGE = "Use /swagbag lock, lock list, lock clear, lock undo, or lock warn."
```

In `SwagBag/Locale/enUS.lua` (edit 3 of 3), find:

```lua
	.. " click it in the scrapper to take it out before you press Scrap.|r"
```

and replace it with:

```lua
	.. " click it in the scrapper to take it out before you press Scrap.|r"
L.LOCK_WARN_STATE = "Warnings before a locked item is destroyed (a spell waiting for a target, the scrapper, Blizzard's"
	.. " delete box): %s. SwagBag never stops these itself. Type /swagbag lock warn on or lock warn off."
L.LOCK_WARN_ON = "SwagBag warns before a locked item is destroyed: a red line on its tooltip while a spell waits for a"
	.. " target or the scrapper is open, and a red chat line at Blizzard's delete box or when it lands in the scrapper."
L.LOCK_WARN_OFF = "No more warnings before a locked item is destroyed. (SwagBag never stopped these; it only warned.)"
L.LOCK_WARN_USAGE = "Use /swagbag lock warn, lock warn on, or lock warn off."
L.SET_LOCK_WARN_TIP = "On: a red line on a locked item's tooltip while a spell (Disenchanting, Milling, Prospecting...)"
	.. " waits for its target or the scrapper is open; a red chat line and a note at Blizzard's delete box; a red chat"
	.. " line when a locked item lands in the scrapper. These are Blizzard's own actions: SwagBag can't stop them, so it"
	.. " warns. Off: no warnings."
L.REPORT_LOCKS = "Locks: %d locked; destroy warnings %s"
```

In `SwagBag/UI/SettingsVendor.lua` (edit 1 of 2), find:

```lua
-- target that locks or unlocks the item on the cursor (as the bags' Lock button), and Unlock all.
```

and replace it with:

```lua
-- target that locks or unlocks the item on the cursor (as the bags' Lock button), and Unlock all. Week 10: the
-- warnings before a locked item is destroyed, On (default) / Off.
```

In `SwagBag/UI/SettingsVendor.lua` (edit 2 of 2), find:

```lua
				return run("lock clear")
			end },
		} },
	}
end

SB.SettingsWindow.AddPage({ id = "vendor", title = L.SET_PAGE_VENDOR, rows = rows })
```

and replace it with:

```lua
				return run("lock clear")
			end },
		} },
		-- Week 10: warnings before a locked item is destroyed (UI/LockWarnings.lua); runs /swagbag lock warn.
		{ kind = "choice", label = L.SET_LOCK_WARN, tip = L.SET_LOCK_WARN_TIP, get = function()
			return SB.Config.Get("locks.warn")
		end, choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			return run(v and "lock warn on" or "lock warn off")
		end },
	}
end

SB.SettingsWindow.AddPage({ id = "vendor", title = L.SET_PAGE_VENDOR, rows = rows })
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1537 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (76 files)`, `1537 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Report.lua \
	SwagBag/Engine/Locks.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/SettingsVendor.lua \
	spec/lockwarnings_spec.lua \
	spec/report_spec.lua \
	spec/vendor_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 10 Task 4: the lock warnings' switch: /swagbag lock warn, Settings > Vendor, the report line

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 5: Week-9 deferred: every layout of the bags and bank windows waits while a spell waits for its target

The week-9 final re-review left "window layout guards use CursorItem not CursorBusy (per spec wording)". This week's feature decides it (D8): while Disenchant waits for its target, a regroup could slide another item, maybe a locked one, under the targeting hand, and the click would destroy that one. So every guard of the bags window (`busyCheck`, which every move and `anyBusy` use; `W.Resize`'s footer shrink; `W.Restack`'s area wait; `W.RequestLayout`; `W.ApplyChanges`' hidden-New area check; the W4-25 grow) and of the bank and guild bank group view (`busyCheck`) reads `Adapter.CursorBusy()` (anything on the cursor, a spell waiting for its target included). The drops that need the item itself keep `Adapter.CursorItem()`: a drop on a section header (`W.DropOnSection`, GroupView's header drop), the Lock button, the Settings drop rows. The alt viewer stays as it is (its items are snapshots; no spell can target them). The tests use week 9's mock `m.cursorOther = "targeting"`. Some guards back each other up under a waiting spell (a held switch's re-stack runs before its grow; every move's `busyCheck` holds a hidden-New arrival too); the two tests that see that name a mutation of all the guards involved.

**Files:**
- Modify: `SwagBag/UI/BagsWindow.lua`, `SwagBag/UI/GroupView.lua`
- Test: `spec/bagswindow_sections_spec.lua`, `spec/groupview_spec.lua`

**Interfaces:**
- Consumes: `Adapter.CursorBusy` (week 9).
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua` (edit 1 of 4), find:

```lua
		assert.truthy(helm.y > y)
	end)
```

and replace it with:

```lua
		assert.truthy(helm.y > y)
	end)

	-- Week 10 (P5, week-9 deferred): a spell waiting for its target (Disenchant, Milling...) holds a regroup like an
	-- item on the cursor, so no other item slides under the targeting hand. Mutation: in BagsWindow's busyCheck,
	-- `local cursor = SB.Adapter.CursorBusy()` -> `local cursor = SB.Adapter.CursorItem() ~= nil`.
	it("a spell waiting for its target holds a header click's collapse; it applies once cast or cancelled", function()
		W.Open()
		A.cursorOther = "targeting"
		W.ToggleSection("c_consumables")
		A.Advance(0.3)
		assert.truthy(B.Get(0, 1).shown, "held")
		A.cursorOther = nil
		A.Advance(0.3)
		assert.falsy(B.Get(0, 1).shown)
	end)

	-- Week 10. Mutation: in W.RequestLayout, `if SB.Adapter.CursorBusy() or scroll:IsMouseOver() then` ->
	-- `if SB.Adapter.CursorItem() or scroll:IsMouseOver() then`.
	it("a full layout waits while a spell waits for its target, then runs", function()
		W.Open()
		A.cursorOther = "targeting"
		assert.falsy(W.RequestLayout("test"))
		assert.truthy(W.stats.lastLayoutReason ~= "test", "held")
		A.cursorOther = nil
		A.Advance(W.RETRY)
		assert.equal("test", W.stats.lastLayoutReason)
	end)
```

In `spec/bagswindow_sections_spec.lua` (edit 2 of 4), find:

```lua
	-- M1. Mutation: in sizeFrame, drop `if W.footHeld and W.foot and foot < W.foot then foot = W.foot end`.
```

and replace it with:

```lua
	-- Week 10. Mutation: in W.Resize, `(scroll:IsMouseOver() or SB.Adapter.CursorBusy())` ->
	-- `(scroll:IsMouseOver() or SB.Adapter.CursorItem())`.
	it("a shorter footer waits while a spell waits for its target, then fits the window", function()
		local stub = { height = 34 }
		function stub.Layout()
			return stub.height
		end
		SB.Footer = stub
		W.Open()
		local h = W.frame.h
		A.cursorOther = "targeting"
		stub.height = 16
		W.Resize()
		assert.equal(h, W.frame.h, "held")
		A.cursorOther = nil
		A.Advance(W.RETRY)
		assert.equal(h - 18, W.frame.h)
	end)

	-- M1. Mutation: in sizeFrame, drop `if W.footHeld and W.foot and foot < W.foot then foot = W.foot end`.
```

In `spec/bagswindow_sections_spec.lua` (edit 3 of 4), find:

```lua
		assert.falsy(B.Get(0, 6).shown)
	end)
```

and replace it with:

```lua
		assert.falsy(B.Get(0, 6).shown)
	end)

	-- Week 10. Two guards hold it (every move's busyCheck and the hidden-New area check); either alone is enough.
	-- Mutation: both of them back to CursorItem.
	it("hidden New: an arrival waits while a spell waits for its target; New shows once it is cast or cancelled", function()
		SB.Config.Set("bags.newAlways", false)
		W.Open()
		A.cursorOther = "targeting"
		A.Put(0, 10, Fixtures.HERB, 20)
		bagUpdate()
		assert.is_nil(header("new"), "showing New would move every section under the targeting hand")
		A.cursorOther = nil
		A.Advance(0.3)
		assert.equal("- New (1)", header("new").text.text)
	end)
```

In `spec/bagswindow_sections_spec.lua` (edit 4 of 4), find:

```lua
	it("W4-25: with the mouse on the window the grow waits; it applies once the mouse leaves", function()
```

and replace it with:

```lua
	-- Week 10. Three guards hold it (busyCheck, the switch's re-stack and the grow itself); any one is enough.
	-- Mutation: all three back to CursorItem.
	it("W4-25: the grow waits while a spell waits for its target; it applies once cast or cancelled", function()
		local top = lowInMode()
		A.cursorOther = "targeting"
		W.modeButton.scripts.OnClick(W.modeButton)
		assert.equal(top, W.frame:GetTop(), "nothing moved under the targeting hand")
		A.cursorOther = nil
		A.Advance(W.RETRY)
		assert.equal(W.size[2], viewHeight(), "grown")
	end)

	it("W4-25: with the mouse on the window the grow waits; it applies once the mouse leaves", function()
```

In `spec/groupview_spec.lua`, find:

```lua
		A.cursor = nil
		A.Advance(0.3)
		assert.truthy(at(btn(6, 1))[2] < potionAt[2])
```

and replace it with:

```lua
		A.cursor = nil
		A.Advance(0.3)
		assert.truthy(at(btn(6, 1))[2] < potionAt[2])
	end)

	-- Week 10 (P5, week-9 deferred). Mutation: in GroupView's busyCheck, `local cursor = SB.Adapter.CursorBusy()` ->
	-- `local cursor = SB.Adapter.CursorItem() ~= nil`.
	it("a spell waiting for its target holds every move and every push too", function()
		v.Layout("open")
		local potionAt = at(btn(6, 1))
		A.cursorOther = "targeting"
		A.Clear(6, 1)
		v.Changes("bank", { { bag = 6, slot = 1, kind = "left", icon = Fixtures.HEALING_POTION } })
		A.Advance(0.6)
		assert.same(potionAt, at(btn(6, 1)))
		A.cursorOther = nil
		A.Advance(0.3)
		assert.truthy(at(btn(6, 1))[2] < potionAt[2])
```

- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1537 passed, 6 failed`. The failures, exactly:

- `spec/bagswindow_sections_spec.lua :: BagsWindow category view > a spell waiting for its target holds a header click's collapse; it applies once cast or cancelled`
- `spec/bagswindow_sections_spec.lua :: BagsWindow category view > a full layout waits while a spell waits for its target, then runs`
- `spec/bagswindow_sections_spec.lua :: BagsWindow category view > a shorter footer waits while a spell waits for its target, then fits the window`
- `spec/bagswindow_sections_spec.lua :: BagsWindow focus modes (spec 6) > hidden New: an arrival waits while a spell waits for its target; New shows once it is cast or cancelled`
- `spec/bagswindow_sections_spec.lua :: BagsWindow focus modes (spec 6) > W4-25: the grow waits while a spell waits for its target; it applies once cast or cancelled`
- `spec/groupview_spec.lua :: GroupView > a spell waiting for its target holds every move and every push too`

Every guard still reads `CursorItem`, which sees no spell waiting for its target, so each layout runs at once.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "a spell waiting for its target holds a header click's collapse; it applies once cast or cancelled": in `SwagBag/UI/BagsWindow.lua`, `local cursor = SB.Adapter.CursorBusy() ⏎ return function(bag, slot) ⏎ return cursor or buttonBusy(bag, slot)` → `local cursor = SB.Adapter.CursorItem() ~= nil ⏎ return function(bag, slot) ⏎ return cursor or buttonBusy(bag, slot)`.
- "a full layout waits while a spell waits for its target, then runs": in `SwagBag/UI/BagsWindow.lua`, `if SB.Adapter.CursorBusy() or scroll:IsMouseOver() then ⏎ SB.Debounce("bags.layout"` → `if SB.Adapter.CursorItem() or scroll:IsMouseOver() then ⏎ SB.Debounce("bags.layout"`.
- "a shorter footer waits while a spell waits for its target, then fits the window": in `SwagBag/UI/BagsWindow.lua`, `(scroll:IsMouseOver() or SB.Adapter.CursorBusy()) then ⏎ W.footHeld = true` → `(scroll:IsMouseOver() or SB.Adapter.CursorItem()) then ⏎ W.footHeld = true`.
- "hidden New: an arrival waits while a spell waits for its target; New shows once it is cast or cancelled": all of these together (each alone still holds): in `SwagBag/UI/BagsWindow.lua`, `local cursor = SB.Adapter.CursorBusy() ⏎ return function(bag, slot)` → `local cursor = SB.Adapter.CursorItem() ~= nil ⏎ return function(bag, slot)`; and in `SwagBag/UI/BagsWindow.lua`, `return scroll:IsMouseOver() or SB.Adapter.CursorBusy()` → `return scroll:IsMouseOver() or SB.Adapter.CursorItem() ~= nil`.
- "W4-25: the grow waits while a spell waits for its target; it applies once cast or cancelled": all of these together (each alone still holds): in `SwagBag/UI/BagsWindow.lua`, `local cursor = SB.Adapter.CursorBusy() ⏎ return function(bag, slot)` → `local cursor = SB.Adapter.CursorItem() ~= nil ⏎ return function(bag, slot)`; and in `SwagBag/UI/BagsWindow.lua`, `(scroll:IsMouseOver() and not overSettings()) or SB.Adapter.CursorBusy()` → `(scroll:IsMouseOver() and not overSettings()) or SB.Adapter.CursorItem()`; and in `SwagBag/UI/BagsWindow.lua`, `if not (frame:IsMouseOver() or scroll:IsMouseOver() or SB.Adapter.CursorBusy()) then` → `if not (frame:IsMouseOver() or scroll:IsMouseOver() or SB.Adapter.CursorItem()) then`.
- "a spell waiting for its target holds every move and every push too": in `SwagBag/UI/GroupView.lua`, `local cursor = SB.Adapter.CursorBusy()` → `local cursor = SB.Adapter.CursorItem() ~= nil`.

- [ ] **Step 3: Write the code**

In `SwagBag/UI/BagsWindow.lua` (edit 1 of 7), find:

```lua
			if not (frame:IsMouseOver() or scroll:IsMouseOver() or SB.Adapter.CursorItem()) then
```

and replace it with:

```lua
			if not (frame:IsMouseOver() or scroll:IsMouseOver() or SB.Adapter.CursorBusy()) then
```

In `SwagBag/UI/BagsWindow.lua` (edit 2 of 7), find:

```lua
	if W.foot and foot < W.foot and (scroll:IsMouseOver() or SB.Adapter.CursorItem()) then
```

and replace it with:

```lua
	if W.foot and foot < W.foot and (scroll:IsMouseOver() or SB.Adapter.CursorBusy()) then
```

In `SwagBag/UI/BagsWindow.lua` (edit 3 of 7), find:

```lua
-- true while an item is on the cursor or that button is under the mouse (the cursor is
-- read once), plus whether the cursor holds an item.
```

and replace it with:

```lua
-- true while anything is on the cursor or that button is under the mouse (the cursor is
-- read once), plus whether the cursor is busy. Week 10 (week-9 deferred): "anything" is
-- Adapter.CursorBusy, a spell waiting for its target too (Disenchant: an item sliding under the
-- targeting hand would be the one destroyed).
```

In `SwagBag/UI/BagsWindow.lua` (edit 4 of 7), find:

```lua
	local cursor = SB.Adapter.CursorItem() ~= nil
```

and replace it with:

```lua
	local cursor = SB.Adapter.CursorBusy()
```

In `SwagBag/UI/BagsWindow.lua` (edit 5 of 7), find:

```lua
	if (wait and ((scroll:IsMouseOver() and not overSettings()) or SB.Adapter.CursorItem())) or anyBusy(moves) then
```

and replace it with:

```lua
	if (wait and ((scroll:IsMouseOver() and not overSettings()) or SB.Adapter.CursorBusy())) or anyBusy(moves) then
```

In `SwagBag/UI/BagsWindow.lua` (edit 6 of 7), find:

```lua
	if SB.Adapter.CursorItem() or scroll:IsMouseOver() then
```

and replace it with:

```lua
	if SB.Adapter.CursorBusy() or scroll:IsMouseOver() then
```

In `SwagBag/UI/BagsWindow.lua` (edit 7 of 7), find:

```lua
		return scroll:IsMouseOver() or SB.Adapter.CursorItem() ~= nil
```

and replace it with:

```lua
		return scroll:IsMouseOver() or SB.Adapter.CursorBusy()
```

In `SwagBag/UI/GroupView.lua` (edit 1 of 2), find:

```lua
	-- Rule 5: nothing moves under the mouse or while an item is on the cursor
```

and replace it with:

```lua
	-- Rule 5: nothing moves under the mouse or while anything is on the cursor (week 10: a spell waiting
	-- for its target too, Adapter.CursorBusy)
```

In `SwagBag/UI/GroupView.lua` (edit 2 of 2), find:

```lua
		local cursor = SB.Adapter.CursorItem() ~= nil
```

and replace it with:

```lua
		local cursor = SB.Adapter.CursorBusy()
```

- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1543 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (76 files)`, `1543 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/UI/BagsWindow.lua \
	SwagBag/UI/GroupView.lua \
	spec/bagswindow_sections_spec.lua \
	spec/groupview_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 10 Task 5: week-9 polish: every layout waits while a spell waits for its target

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

## In-game sessions

One session, LW1, on the **final merged build** (every task done, reviewed and fixed), as week 6's ruling P1 set; the "checks Tasks N" in its heading only says which tasks' work it checks. Then the week-10 exit check. It never blocks the build: findings come back as fixes.

Before the session:
- Claude installs the build first. The game currently runs an older copy, and the login line must say `v0.10.0`.
- If anything shows a red Lua error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After the session, reply "LW1 done" and the numbers of any steps that didn't match.

Chat lines start with `SwagBag: `. Names and numbers like `<its name>` or `N` are examples: yours will differ. **SwagBag never stops anything this week: it only warns. Never click Yes, Scrap or the item itself unless the step says so.**

### Session LW1: lock warnings (checks Tasks 1 to 5; about 15 minutes)

You need: a **gray junk item** you don't mind losing (for the delete box; step 9 deletes it); for steps 10–13 a character with **Enchanting** and a green piece of gear it can disenchant (or Inscription and some herbs, or Jewelcrafting and some ore: then use Milling or Prospecting wherever the steps say Disenchant); for steps 15–18 (optional) a **scrapping machine** (for example in Boralus's Tradewinds Market or in Dazar'alor) and a piece of gear from Battle for Azeroth or later that you don't need.

How to lock or unlock an item: pick it up (left-click), drop it on the small `Lock` button right of the bags' search box, and move the mouse off the bags.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.10.0 loaded. Type /swagbag help for commands.`
3. Type `/swagbag lock warn`. Expected: `SwagBag: Warnings before a locked item is destroyed (a spell waiting for a target, the scrapper, Blizzard's delete box): on. SwagBag never stops these itself. Type /swagbag lock warn on or lock warn off.`
4. Press **B** and lock the gray junk item (see above). Expected: `SwagBag: Locked: <its name>. SwagBag never sells it, and it shows a small lock.`
5. Rest the mouse on the gray item. Expected: its tooltip has the gold line `Locked in SwagBag: never sold by SwagBag` and **no** red line under it. Move the mouse off the bags.
6. Pick up the gray item (left-click) and click on the ground in the game world, away from every window. Expected: Blizzard's box asks whether you want to destroy it; chat shows, in red, `SwagBag: <its name> is locked in SwagBag. SwagBag can't stop Blizzard's delete: click No (or press Esc) to keep it.`; and just above Blizzard's box a small dark bar says, in red, `This item is locked in SwagBag.` (Say if the bar covers any part of Blizzard's box, or if the red is hard to read.)
7. Look at Blizzard's box. Expected: it looks and works as always (Yes and No buttons; for a rare item, a field to type DELETE).
8. Click **No**. Expected: the box closes, the dark bar goes with it, and the gray item is back in your bags.
9. Do step 6 again, and this time click **Yes** (type DELETE first if the box asks). Expected: the item is destroyed, the dark bar goes, and **no** "Interface action failed because of an AddOn" message appears. (Blizzard's delete is not stopped by SwagBag: this is the point.)
10. Lock the green piece of gear (or a stack of herbs or ore). Expected: `SwagBag: Locked: <its name>. SwagBag never sells it, and it shows a small lock.`
11. Cast **Disenchant** (from your spellbook or professions window). The cursor becomes the targeting hand. Rest it on the locked gear, **without clicking**. Expected: the tooltip has the gold `Locked in SwagBag: never sold by SwagBag` and right under it, in red, `Locked by you. SwagBag can't stop this spell: press Esc to cancel it.`
12. Press **Esc**. Expected: the targeting hand is gone; rest the mouse on the gear again: no red line.
13. Rest the mouse on the locked gear first, then cast Disenchant with a key bind or from your bars **without moving the mouse** (skip if you can't). Expected: within a moment the red line appears on the open tooltip. While the hand waits, watch the bags: nothing moves. Press **Esc**. Move the mouse off the bags.
14. Cast Disenchant again and rest the hand on an **unlocked** item. Expected: no red line. Press **Esc**.
15. (Optional, at a scrapping machine.) Lock the piece of gear you don't need. Right-click the scrapping machine. Expected: the scrapper opens next to your bags.
16. Rest the mouse on the locked gear. Expected: under the gold line, in red, `Locked by you. SwagBag can't stop the scrapper: a right-click puts this item in it.`
17. Right-click the locked gear. Expected: it goes into a scrapper slot (SwagBag does not stop it), and chat shows, in red, `SwagBag: <its name> is locked in SwagBag and is now in the scrapper. SwagBag can't stop it: click it in the scrapper to take it out before you press Scrap.` **Do not press Scrap.**
18. Click the gear in the scrapper's slot. Expected: it goes back to your bags. Close the scrapper. Rest the mouse on the gear: no red line.
19. Type `/swagbag settings vendor`. Expected: the Vendor page has a row `Warn before destroying locked items` with `On` selected. Click `Off`. Expected: the status line says `No more warnings before a locked item is destroyed. (SwagBag never stopped these; it only warned.)`
20. Close the settings window. Cast Disenchant and rest the hand on the locked gear. Expected: only the gold line, no red line. Press **Esc**.
21. Type `/swagbag lock warn on`. Expected: `SwagBag: SwagBag warns before a locked item is destroyed: a red line on its tooltip while a spell waits for a target or the scrapper is open, and a red chat line at Blizzard's delete box or when it lands in the scrapper.`
22. Type `/swagbag report` and look for the `Locks:` line. Expected: `Locks: N locked; destroy warnings on`. Close the report box.
23. Unlock the gear (and anything else you locked for this session). Expected: `SwagBag: Unlocked: <its name>.`

## Week 10 exit check

1. Claude installs the week-10 build, at the end of Task 5 (after review and fixes), and you fully restart the game.
2. Play normally for a day, with keys, a vendor, a bank visit and your professions. Expected: no red errors; no "Interface action failed because of an AddOn" while disenchanting, milling, prospecting, scrapping or deleting; nothing moves under your mouse or under the targeting hand.
3. Type `/swagbag report` and paste it to Claude. Expected:
   - `Safe Mode: bags=off bank=off`;
   - `Failed checks: none`;
   - `Blocked actions: none`;
   - the `Locks:` line with your number of locked items.


## Spec updates at week end

Recorded in the week-10 ledger and applied to `docs/superpowers/specs/2026-09-30-swagbag-design.md` at week end (this plan commits only the plan file):
- **F18 (item locks), new AC18.3:** warnings, never blocks: while a spell waits for its target (`SpellIsTargeting()`, any spell), a locked item's tooltip shows a red line under its "Locked" line (`Locked by you. SwagBag can't stop this spell: press Esc to cancel it.`); while the scrapper is open, a red line that a right-click puts it in; at Blizzard's delete box for a locked item, one red chat line and SwagBag's own note above the box (the box never touched); a locked item landing in a scrapper slot, one red chat line (again only after it was taken out and put back). SwagBag never cancels, clicks, hides or changes Blizzard's spells, buttons or dialogs; other addons' one-click destroy buttons cast with no targeting and are not covered.
- **F18, new AC18.4:** one switch, `locks.warn` (default on): Settings > Vendor > "Warn before destroying locked items", `/swagbag lock warn [on|off]`; the report's `Locks: N locked; destroy warnings on|off`.
- **§4.2 rule 5:** "a button is never moved ... while `GetCursorInfo()` holds an item" becomes "while anything is on the cursor or a spell waits for its target (`Adapter.CursorBusy()`)", for every layout of the bags, bank and guild bank windows (week 10, D8); the drops that need the item itself read the item; the alt viewer keeps the item rule (no spell targets a snapshot).
- **AC4.4 and §4.3 (week-9 deferred, D10):** "Items whose data is not yet loaded go to New and are re-categorized when loaded; they move only on the next open or Reflow" gains "after they were hovered, like every arrival (AC3.3)"; §4.3's row "Item data loads for a pending item" says "Stays in New until hovered; re-categorized for the next layout after that".
- **§5.3 (taint rules):** add: reading Blizzard's delete box (`StaticPopup_FindVisible`) and the scrapper's slots is allowed; writing `StaticPopupDialogs`, calling any method on a Blizzard dialog, and every `C_ScrappingMachineUI` call that changes something are not.
- **§8.2 (settings):** `locks.warn` (explicit default `true`, schema 2; a boolean in share strings).
- **§10.4 (`/swagbag report`):** the `Locks:` line.
- **§10.5 (commands):** `lock [list|clear|undo|warn [on|off]]`.
- **§10.3 (feature checks):** four optional checks: `SpellIsTargeting`, `StaticPopup_FindVisible`, `C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex`, `C_Item.GetItemID`.
- **§13.1 (risks):** a patch that renames the delete box leaves only the chat line (no error); the scrapper's events or slot numbering changing leaves the tooltip line only.

## Spec coverage (week-10 scope → task)

| Requirement (from the brief) | Task |
|---|---|
| 1a. Tooltip warning on a locked item while a destroy spell waits for its target (Disenchanting, Milling, Prospecting...) | T1 (D2, D3, D4) |
| 1b. Any spell targeting, or a known ID list: decide and justify | D2 (any spell) |
| 1c. Through the existing tooltip hook; no new click hooks, no PreClick/PostClick, nothing secure | T1 (Locks.TooltipLine, hooked since week 7), Global Constraints |
| 2a. Delete box (DELETE_ITEM / DELETE_GOOD_ITEM / DELETE_QUEST_ITEM / DELETE_GOOD_QUEST_ITEM, DELETE_ITEM_CONFIRM): one red chat line for a locked item | T2 (D5) |
| 2b. A line on the popup if feasible without taint; never click, hide or change its buttons | T2 (SwagBag's own note above the box, D5) |
| 3. Scrapper: refuse if possible within the rules, else a tooltip line while open and a chat line when a locked item enters a slot; say so in Decisions | T3 (D6) |
| 4. Settings > Vendor row, default on; /swagbag lock warn [on\|off]; report line | T4 (D7) |
| 5a. Spec AC4.4/§4.3: pending items also wait for a hover | "Spec updates at week end" (D10) |
| 5b. The bags window's layout guards use CursorBusy (decide and justify) | T5 (D8) |
| 5c. Anything else cheap and user-visible from the week-9 ledger; the rest deferred | "Carry-overs" (D10) |
| Version 0.10.0 in Task 1 | T1 |

## How this plan was checked (while writing it)

- Every task was first built on a scratch clone at `/tmp/sb10` (outside the repo), one commit per task, test-first: each task's tests were run against the previous task's code (red) and then against its own (green). Every block in this file was then generated from those commits' diffs by a script: each find block is grown line by line until it occurs exactly once in the file as it is after the earlier edits, starts and ends on a non-blank line and holds at least one distinctive line; the script re-applied every block to the old file and compared the result with the commit's file.
- **Replay.** A fresh clone of `7ee3958` (`/tmp/sb10r`) was driven by a script that reads this file: for each task it applies the Step 1 blocks, runs the suite, applies the Step 3 blocks, runs the suite and `scripts/check.sh`, then commits. Every find block occurred exactly once when applied; every Step 2 count and FAIL list (name by name), every Step 4 total, every Step 5 `ALL CHECKS PASSED` and TOC count, and every Step 6 `git add` list (equal to the files the task changed) above is that script's output. Final total: **1543 passed, 0 failed**.
- **Mutations.** Every mutation listed under a Step 2 (26 in all) was applied to its own task's replayed commit, and the whole suite run: every one made its named test fail.
- **Strings.** Every quoted chat line, tooltip line and status line in LW1 was matched against `enUS.lua` by a script (colour codes stripped, `<its name>` and `N` as wildcards).
- **Research** (no code copied): Blizzard's 12.1.5 interface source (`Blizzard_Game/Mainline/EventImplementation.lua` for `DELETE_ITEM_CONFIRM`, `Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua` for the four delete boxes, `Blizzard_StaticPopup/StaticPopup.lua` for `StaticPopup_FindVisible`, `Blizzard_ScrappingMachineUI` for the slot numbering and events) and the client's generated API documentation (`ScrappingMachineUIDocumentation.lua`, `PlayerInteractionManagerConstantsDocumentation.lua`: `ScrappingMachine = 40`).
- Greps on the final tree:
  - no `C_`/`Enum.` outside `SwagBag/Core/Adapter.lua`, no bare `C_*` name, no `TSM_API`/`LibStub` (check.sh);
  - none of the forbidden tokens; no `SpellStopTargeting`, `StaticPopupDialogs[`, `RemoveItemToScrap`, `ScrapItems`, `DeleteCursorItem`, `HookScript` or `SetScript` in `UI/LockWarnings.lua` or the new Adapter code;
  - no `OnUpdate`; no `Config` call at load;
  - no `%s` given a boolean (format51 runs on every spec).

## Self-review

1. **Scope coverage.** Every item of the brief maps to a task or a named decision in "Spec coverage", in the brief's order (the tooltip first, then the delete box, the scrapper, the switch, the polish). Each open question has a decision row: block or warn (D1), which spells (D2), which tooltips (D3), the wording (D4), the delete box (D5), the scrapper (D6), the switch (D7), the layout guards (D8), the version (D9), the deferred items (D10), what is not covered (D11).
2. **Placeholder scan.** No "TBD", "TODO", "similar to", or test-free step. Every code step is a complete block (the replay applies them as written). The in-game expectations quote Locale strings verbatim; where a line holds the player's own names or numbers the step says so.
3. **Type and name consistency.** These names are the same in every task that uses them: `SB.LockWarnings` (`On`, `TooltipText`, `OnDelete`, `ShowNote`, `CheckDelete`, `deleting`, `note`, `NOTE_WIDTH`, `NOTE_HEIGHT`, `scrapper`, `scrapWarned`, `CheckScrapper`), `Adapter.SpellTargeting/TooltipWarning/DELETE_POPUPS/DeletePopup/IsScrapper/SCRAP_SLOTS/ScrapperItemIDs`, the setting `locks.warn` (T1: Config, Profiles, LockWarnings; T4: Locks' command, SettingsVendor, Report), the mock's `m.cursorOther = "targeting"`, `m.deletePopup`, `m.scrapper`. The Locale keys quoted in LW1 were checked against the blocks by a script.
4. **Review Focus.** Each of the five lines names its pinning tests, and each of those tests is in its owning task's Step 1.
5. **Global Constraints.** No `C_`/`Enum.` outside the Adapter. Nothing touches a Blizzard button, dialog or spell; the only new frame is SwagBag's own note. Every new listener and timer runs under `SB.On(..., "none")` or `ErrorTrap.Guard(..., "none")`. Every user-visible string is in `enUS.lua`. One new setting with an explicit default, schema 2, a label. No `OnUpdate`; nothing runs while idle.
6. **Known limits, stated in the plan.** SwagBag warns, it cannot stop (D1). Other addons' one-click destroy buttons cast with no targeting hand and get no warning (D11). The tooltip line is for any spell waiting for its target, also an enchant on a locked item (D2: right, since it changes the item). If a patch renames Blizzard's delete box, only the chat line comes (D5). Locked items in the scrapper are not taken back out (D6; a possible follow-up after LW1). An item whose ID is secret on the cursor (in combat, where none of these flows run anyway) gets no warning.
