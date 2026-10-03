# SwagBag Week 7: the User's Research Picks (equipment sets, Venomstones, learn glow, auto-sell and repair, item locks, section actions, worth-money glow, uncollected star, profiles). Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ] `) syntax for tracking.

**Goal:** the nine features the user picked on 2026-10-06 from the 2026-10-03 research (`research/2026-10-03-feature-gaps.md`, `research/2026-10-03-community-asks.md`, `research/2026-10-03-horizon.md`), in the user's order, so the earlier ones ship first if time runs out:
1. **Equipment set section.** Items in any equipment set get their own built-in category, used by the M+, Raid and Delves modes, never shown as junk or sellable.
2. **Ascendant Venomstones and the Oct 20 patch.** Venomstones in the footer next to the crests; season data (crests, currencies, Venomstones) in one data file; the upgrade-track overlay checked on Venomstone-boosted items.
3. **"Use / open / learn" glow.** A soft glow on items to click: caches and other containers, unlearned profession knowledge, toys, mounts, pets and decor not collected yet. Its own switch in Settings > Overlays, on by default.
4. **Auto-sell junk and auto-repair.** On by default; gray junk only, never locked items or equipment-set items, at most 12 per visit (Blizzard's buyback keeps 12), one chat line; repair with your own gold (guild funds an option, off). Nothing in combat. A setting and a command for each.
5. **Item lock.** Lock or unlock an item, account-wide, per item ID; a small lock mark; never auto-sold or "sold all"; a warning in chat if one is sold by hand; search keyword `locked`.
6. **Section actions.** Shift+right-click a section header: at a bank "Send all to bank" / "Send all to warband bank", at a vendor "Sell all" (asks first). Small steps, out of combat, never under the mouse.
7. **Worth-money glow at the bank.** Items worth 100 g or more (a stack; Auctionator, else vendor) glow gold while the bank is open, in the bags and the bank; "your top X %" as the alternative. A Settings row and a command.
9. **Uncollected marker.** A small star on gear whose appearance the account has not collected, and on toys, mounts and pets not learned yet. Its own switch, on by default. Secret-safe, cached, no per-frame cost.
12. **Settings profiles and a share string.** Named profiles (save, load, delete, back to defaults, undo), account-wide; export a profile (optionally with the categories) as a copyable, versioned string; import with a preview of every change, validation, and nothing in the string ever run.

(The numbers are the research's; picks 8, 10 and 11 were not chosen.)

**Architecture:**
- (1) A built-in category `c_sets` "Equipment sets" (`equipped`, priority 92, after Gear) and three focus-mode default sets that include it; the junk coin skips set pieces.
- (2) `Engine/Crests.lua` becomes the season data file: crest IDs and words, currency words, the season's bag items (the Venomstone, item 280562) and knowledge items. The footer's crests entry adds the season items it finds in the bags; `/swagbag report` gains a `Season data` line so the user confirms the IDs in game.
- (3) and (9) A new pure-ish engine `Engine/Collections.lua` answers "open / learn" and "uncollected" from the client's collection APIs through new Adapter calls, cached per item until something is learned. `UI/Overlays.lua` draws a whole-button glow (green: open or learn) and a star.
- (4) A generic **mover** (`Engine/Mover.lua`) moves a list of bag items one at a time, 0.2 s apart, out of combat, never while an item is on the cursor or the item's button is under the mouse, and stops when the vendor or bank closes or the target refuses. `Engine/Vendor.lua` uses it to sell junk on `MERCHANT_SHOW`, then repairs; `UI/SettingsVendor.lua` is a new Vendor page.
- (5) `Engine/Locks.lua` keeps `SwagBagDB.locks`; a plain **Lock** button at the right end of the bags window's search row takes a dropped item (the header-drop pattern of AC4.3; no click hook on any item button). The vendor never sells a locked item and warns when one is sold by hand.
- (6) `UI/SectionActions.lua`: Shift+right-click on a bags-window section header opens a small plain menu; actions go through the mover (`Adapter.MoveToBank` passes the bank type to the call, so Blizzard's selected tab is never touched).
- (7) The same overlay glow turns gold at the bank for items whose stack value reaches a threshold worked out once per visit (`Prices.WorthThreshold`); `/swagbag worth` and a Bank page row set it.
- (12) `Engine/Profiles.lua` (profiles, the share string, its parser, preview and import), `UI/ShareBox.lua` (copy / paste box with Preview and Import) and a Profiles settings page.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- spec F4/§7.6 (a new built-in category, `c_sets`), §6.3 (the M+, Raid and Delves sets), §7.3 (`equipped`, `locked`, `uncollected`), §13.2 item 4 (season data);
- spec F9 overlays and §2.2 v1.1/v1.2 items brought forward by the user: the worth-money highlight, the uncollected-transmog overlay and the uncollected pet/toy (and mount) overlay; plus a new "open or learn" glow;
- new features the spec does not have yet: auto-sell junk and auto-repair (the research's gap 2), item locks (gap 1), section actions (gap 3), profiles and share strings (gap 7). They follow every spec principle (P1–P8, §5.3, §9). The spec text is updated at week end (see "Spec updates at week end").

Ledgers (binding rulings W3-*, W4-*, W5-*, week 6): `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md`, `2026-10-03-swagbag-week4-ledger.md`, `2026-10-04-swagbag-week5-ledger.md`, `2026-10-05-swagbag-week6-ledger.md`. Week-6 plan (style and interfaces): `docs/superpowers/plans/2026-10-05-swagbag-week6-user-requests.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week7-picks` is already checked out. It was made from `main` at `a1f7f86` (v0.6.0, week 6 merged). The suite has 1281 tests. No task creates or switches branches.

**The code at `a1f7f86` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). These interfaces are used as they are on `a1f7f86`:
- `SB.On`, `SB.Emit`, `SB.Debounce(key, delay, fn, window)`, `SB.OutOfCombat(fn, label, window)`, `SB.ErrorTrap.Run/Guard/OnError(label, window, message, stack)`, `SB.Print`, `SB.Slash.Register(name, help, fn, window)` / `SB.Slash.Run(line)` (a command returning a table prints each line; an empty table prints nothing).
- `SB.Config.Get/Set/Copy/Defaults/readOnly/db/charDB`. `Config.Set` returns false while read-only and emits `SB_CONFIG_CHANGED(path)`; `Config.Get` reads a character override, then the saved account value, then `Config.Defaults`. Only values somebody wrote are stored.
- `SB.Items.Describe(bag, slot[, s])` and its record fields (`inEquipmentSet`, `isLocked` = the client's lock, `hasNoValue`, `isToy`, `isCagedPet`, `classID`, `subclassID`, `quality`, `link`, `count`, `pending`, `offline` on the alt viewer's records).
- `SB.Inventory.Iterate(kind)`, `GetSlot`, `OnChanged(fn(mask, changes))`, `Has`, `R`, `ScanAll`, `MarkDirty`, `Flush`.
- `SB.Categories` (`Load`, `Name`, `Get`, `SectionOrder`, `FREE`, `display`) and `SB.CategoryDefaults` with the week-6 `after` field.
- `SB.Focus.signals`, `Sections`, `Front`, `SectionOrder`; `SB.Prices.Value/Bound/Money`; `SB.Overlays.Apply/RefreshAll/Context/regions`; `SB.OverlayData.For(record, ctx)`.
- `SB.BagsWindow`: `W.state` (Layout state: `sections[id].cells`), `W.records`, `W.ButtonBusy(bag, slot)` (P5: the button is under the mouse; a list row counts as its button), `W.IsOpen`, `W.ForEachSlot`, `W.RequestLayout`, `W.RefreshTitle`, `SB.SectionHeaders.onClick/onDrop`.
- `SB.BankWindow.interaction` (true between `BANKFRAME_OPENED` and `_CLOSED`), `BW.IsOpen`, `BW.view.ForEachSlot`.
- `SB.SettingsWindow.AddPage/RunCommand/Show/lastStatus` and the row kinds `choice`, `actions`, `drop`, `note` (any row may carry `tip`).
- `SB.Adapter`: `isSecret` / `A.IsSecret`, the local `location(bag, slot)`, `A.TooltipLine`, `A.HookItemTooltip`, `A.CursorItem/ClearCursor`, `A.Money`, `A.GetItemInfo/GetItemInstant`, `A.CurrencyList/CurrencyInfo`, `A.CHECKS`. The mock is `spec/mock_adapter.lua`.
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua` (`Fake.New`, `Fake.Fire`, `Fake.Install/Uninstall`), `uienv.lua` (`Env.ENGINE`), `spec/fixtures/items.lua` (`Fixtures.SmallBags`, `Fixtures.Install`), and `format51` (installed by the runner).


## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.7.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. To confirm Blizzard's API names, installed addons were read for **names and call shapes only** (Baganator, Syndicator, EnhanceQoL, EnhanceQoLVendor, TitanRepair, WeeklyKnowledge); see "What the week relies on". No code of theirs is used.
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator, ElvUI`.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets a string or a number, never a boolean or nil. Every spec runs under `spec/helpers/format51.lua`, which makes the tests as strict as WoW.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace, `Enum` or another addon's globals, **comments included**. It is grep-enforced for `C_X.`/`Enum.` and review-enforced for bare names. Every other file calls `SB.Adapter.*`. This week adds Adapter calls for `C_Container.UseContainerItem`, `C_Bank.IsItemAllowedInBankType`, `C_MountJournal`, `C_PetJournal`, `C_HousingCatalog`, `C_TransmogCollection`, and the globals `PlayerHasToy`, `CanMerchantRepair`, `GetRepairAllCost`, `RepairAllItems`, `CanGuildBankRepair`, `GetGuildBankWithdrawMoney`, `GetNumBuybackItems`, `GetBuybackItemLink`, `IsShiftKeyDown`. Files under `spec/` may name them as test data.
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`. `SetCurrentGuildBankTab` is never called. (Task 5's comment on the item buttons says "no click script or click hook of any kind" rather than naming the forbidden scripts; check.sh caught the first draft.)
- **Secure item buttons** (`ContainerFrameItemButtonTemplate`) are never reparented, never created in combat, never re-`SetID`'d, and get **no** click script or click hook of any kind. This week's gestures avoid them: an item is locked by dropping it on SwagBag's own Lock button (Task 5), and section actions open from a section header (Task 6). The only hook on an item button stays week 4's `OnEnter` post-hook (the new-item glow). Overlays add regions (textures, font strings) on the button, as since week 3.
- **Moving items** (sell, bank) happens only through `Engine/Mover.lua`: out of combat only (combat stops a run; nothing is queued), one item at a time `Mover.DELAY` (0.2 s) apart, never while an item is on the cursor or the item's own button is under the mouse (spec §4.2 rule 5, P5), and only while the vendor or bank is still open. An item that leaves the bags leaves a placeholder (spec §4.3), so no other button moves.
- P1: every setting ships with a chosen default, and its alternative sits next to it in the same place. Options are phrased as choices, never as abstract toggles.
- P2: every command, button and settings choice answers **exactly once**, with a chat line, a title flash or the settings window's status line. A run that takes time (a sale, a send) answers once, when it ends; `/swagbag sell junk` therefore returns an empty list (nothing printed at once) and the sale's own line is its answer. Automatic actions (the auto-sell, the repair) print one line each when they did something, and nothing when there was nothing to do.
- P5 / spec §4.2 rule 5: nothing moves under the mouse or while an item is on the cursor. Held moves retry 300 ms later through `SB.Debounce` or `SB.Adapter.After`, never `OnUpdate`.
- **P6.** Every WoW entry point runs inside `SB.ErrorTrap.Run` or `Guard`. The window labels this week:
  - `"bags"`: the Lock button's scripts (`bags.lockButton`, `bags.lockDrop`, `bags.lockTip`), the section menu and its confirmation (`sections.menu`, `sections.sellAll`), the header hint (`header.enter`/`header.leave`, owner window);
  - `"none"` (recorded, never Safe Mode): the vendor's events and the mover's steps (`mover.step`, `mover.done`, `mover.act`), the collections' events, the worth glow's events, the tooltip line (`tooltip.lock`), the share box (`share.*`), and every settings page;
  - a command run from the settings window traps under that command's own window and label (W4-7).
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`.
- **Plain frames only, may be created in combat:** the Lock button (`UIPanelButtonTemplate`), the section menu (`"BackdropTemplate"` frame with `UIPanelButtonTemplate` buttons, in `UISpecialFrames`), the share box (`"BackdropTemplate"`, a `UIPanelScrollFrameTemplate` scroll frame and a plain multi-line `EditBox`, like the report box), and `StaticPopupDialogs.SWAGBAG_SELL_ALL` (SwagBag's own dialog, like week 1's reset). Themes restyle them through `SB.Theme.Button/Window/Text`.
- **Settings and saved data (schema stays 2):**
  - every new settings key has a default in `Config.Defaults`: `overlays.learn` (true), `overlays.lock` (true), `overlays.uncollected` (true), `vendor.autoSell` (true), `vendor.repair` (`"own"`), `prices.worth` (`"fixed"`), `prices.worthGold` (100), `prices.worthTop` (10). Changed defaults: `focus.sections.mplus/raid/delves` gain `c_sets`. Only values somebody wrote are stored, so no migration;
  - new top-level saved data, read defensively (a damaged value reads as empty, never an error), needs no bump: `SwagBagDB.locks = { [itemID] = true }`, `SwagBagDB.profiles = { [name] = { settings, saved } }`, `SwagBagDB.profile` (a name, shown only), `SwagBagDB.backups.profile` (one step of undo). `/swagbag reset` keeps a backup of them with everything else (week-1 rule);
  - every new writer refuses while `Config.readOnly` and says `L.SETTINGS_READONLY`.
- No file calls `Config` at load time (the load-order tests stay green). Every `OnHide` handler starts with `if self:IsShown() then return end`.
- No `OnUpdate` anywhere. Idle CPU with every window closed is 0: collection answers are cached and dropped only on events; the worth line is worked out once per bank visit.
- Every critical test names the mutation that must make it fail. Each task lists its mutations under Step 2.
- **Tooling (binding, as in weeks 1–6):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). Where a test fakes a frame method WoW has, it fakes it the way WoW behaves. CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Test totals are cumulative from 1281 (see "Schedule").
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

1. **Selling or banking while the mouse rests on the bags.** The auto-sell starts the moment a vendor opens, and the bags open with the vendor, often right under the pointer. Expected: an item whose button is under the mouse, or every item while one is on the cursor, waits (300 ms retries); an item the mouse never leaves stays and the chat line says so; a sold item leaves a placeholder, so nothing else moves. Pinned by:
   - Task 4: "waits while an item is on the cursor or the item's button is under the mouse, then moves it";
   - Task 4: "an item the mouse never leaves stays where it is; the run goes on with the next";
   - Task 6: "SectionSlots lists the items drawn in a section, never a placeholder" (a ghost is never sold).
2. **More junk than the buyback tab holds.** Blizzard keeps only the last 12 sold items. Expected: at most 12 per run, every one of them can still be bought back during the visit, and the line says how many wait and how to sell them. Pinned by Task 4: "sells at most 12 per run (the buyback tab keeps 12) and says how to sell the rest".
3. **A locked or equipment-set item inside "Sell all" or the auto-sell.** Expected: never sold by SwagBag; sold by hand it gets one warning naming it and the Buyback tab. Pinned by:
   - Task 4: "sells gray junk a vendor pays for; never a set piece, an item the client holds, or one worth nothing";
   - Task 5: "a locked junk item is never sold, by auto-sell or by /swagbag sell junk";
   - Task 5: "a locked item sold by hand (it left the bags and is in the buyback tab) gets one warning";
   - Task 6: "at a vendor Sell all asks first, then sells what a vendor pays for, never locked or set items".
4. **A bank tab that is full (or will not take the item) during "Send all".** Expected: the run stops at the first item that stays, says how many moved and how many stayed, and never loops. Pinned by Task 4: "waits while the client holds a sent item; an item still there and free means refused: the run stops" and Task 6: "a bank that stops taking items (full) ends the run and says how many stayed".
5. **The vendor or bank closing, or combat starting, mid-run.** Expected: the run stops at once (nothing queued), the line counts what moved and what stayed, and a vendor opened in combat sells only once combat ends and only if it is still open. Pinned by Task 4: "combat stops the run (nothing queued); a vendor or bank that closes stops it too", "a vendor closed mid-run: the line says how many sold and how many stayed", "a vendor opened in combat sells and repairs once combat ends, only if it is still open".
6. **A malformed, hostile or newer import string.** Expected: refused whole with the reason; nothing in it is ever run; unknown settings are skipped and named; nothing changes before Preview and Import. Pinned by Task 9: "refuses a string that is not ours, from a newer SwagBag, damaged, too long or with a wrong value", "never runs what it reads; settings this version does not know are skipped and named", "import: Preview first; a typed change needs a new preview; Import applies and answers in chat", "a refused string says why in the box and can never be imported".
7. **Secret or missing values** (prices, collection answers, appearance answers in M+ or a raid). Expected: a secret is no answer: no gold glow, no green glow, no star, never an error. Pinned by:
   - Task 3: "toys and mounts: true, false, or nil without the API, for a non-mount item, or a secret";
   - Task 3: "open: a container with loot; learn: ... else nothing" (a silent client gives no glow);
   - Task 7: "gold at the bank wins over green; a price the game will not give (secret, missing) never glows" (with week 3's `AuctionatorPrice` secret check);
   - Task 8: "appearances: collected or not; nil with no source, one the account cannot collect, or a secret".


## Decisions (every product default chosen this week, read before Task 1)

| # | Pick or question | This plan (the default) | The alternative, and where it is | Why |
|---|---|---|---|---|
| D1 | Pick 1: "decide its placement/priority vs Gear/BoE/WuE" | Built-in `c_sets`, name `Equipment sets`, query `equipped` (the existing keyword: `Items.inEquipmentSet`), **priority 92**: above Junk (90), Quest (85), Tools (80), BoE gear (75), WuE (74) and Gear (70); below Keystone & Crests (95) and Reagents (100). Display order 35, **right after Gear**, with `after = "c_gear"` so it also joins a saved category order (quick setup writes the whole list) next to Gear (week-6 D9 mechanism). | A user moves or renames it like any built-in (a `userEdits` diff, spec 8.5). | A piece in a set is "mine, in use": filing it under Junk or BoE gear (both "to sell") would invite a sale. Gear stays for gear not in a set. |
| D2 | Pick 1: "which focus modes use it" | `c_sets` joins the default section sets of **M+, Raid and Delves** (each already opens Gear). AH/Vendor/Bank, Gathering and Fishing do not. Users who saved their own set keep it (only written values are stored). | Settings > Focus modes adds or removes it per mode. | The modes that open Gear are the ones that swap gear; the vendor mode shows what can be sold, which set pieces never are. |
| D3 | Pick 1: "never shows as sellable/junk" | The junk coin skips a gray piece in a set; the auto-sell, Sell all and the AH/Vendor/Bank mode never include set pieces (`Vendor.Protected`). | — | The same rule everywhere an item can look "for sale". |
| D4 | Test fixtures for pick 1 | The `SmallBags` fixture's helm is **no longer in an equipment set** (it was only to test the `equipped` keyword). The two tests that read the flag put it on their own slot. | Leave the fixture: 31 window tests would change their section lists for no behaviour of theirs. | Keeps every existing window test about what it was written for; the new section has its own tests. |
| D5 | Pick 2: the Venomstone | **Item 280562**, "Ascendant Venomstone" (12.1.5 PTR, Wowhead and warcraft.wiki.gg: a bag item, stacks to 100, binds when picked up; 10 per upgrade). It files under **Keystone & Crests** by ID (`SB.Crests.ids`) and shows in the footer's crests entry with how many the bags hold. If the live game makes it a currency instead, the currency word `venomstone` finds it in the Currency tab (the existing name probe), with no code change. `/swagbag report` gets a `Season data` line that names both, so the user confirms in game (session SN1). | Raid and Delves do not open Keystone & Crests (unchanged); Settings > Focus modes can add it. | One data file to edit per season (`Engine/Crests.lua`); the probe means a wrong guess costs a data edit, never a broken footer. |
| D6 | Pick 2: "make season data data-driven where it is hard-coded, if cheap" | `Engine/Crests.lua` is the season data file: crest IDs and words, currency words, season bag items, knowledge items. The M+ dungeons were already data-driven (dungeon names come from the client, teleports by the `"path of "` prefix, Engine/FocusData.lua) and the consumables watch list is keyword-based, so nothing else moves. | — | Nothing else was hard-coded per season. |
| D7 | Pick 2: "check the upgrade-track overlay on Venomstone-boosted items" | No code change. The overlay reads the client's track (`C_Item.GetItemUpgradeInfo`) and the client's item level, never a table of levels, so a boosted Myth 6/6 necklace reads `M6/6` with its new item level. A level past the maximum draws as it is (`M7/6`), never an error. A test pins both. | — | Reasonable expectation only; the in-game check is session SN1 step 9 (the user has a boosted item from 2026-10-20). |
| D8 | Pick 3: what glows, and how | A **green** glow (Blizzard's `bags-glow-white` atlas tinted green, a flat translucent fill if the atlas is missing) on: a container the client says holds loot (`hasLoot`: caches, bags of goods, **lockboxes too**), a toy / mount / pet item the account has not collected (`PlayerHasToy`, `C_MountJournal`, `C_PetJournal`; a caged pet by its species), decor the account owns none of (`C_HousingCatalog`), and profession knowledge items (`SB.Crests.knowledge`: confirmed IDs, else the name word `treatise`, never on gear). Setting `overlays.learn`, **on**. | Off in Settings > Overlays or `/swagbag overlays learn off`. | Real APIs only (P7), no tooltip reading. A client that cannot say gives no glow, never a wrong one. Knowledge items have no API flag, so they are data; `/swagbag report` is not needed for them: the user names a missed one in session LN1. |
| D9 | One button, several signals | **One glow per button**: gold (worth money, at the bank) wins over green (open or learn). The uncollected star (D23) shows on a toy, mount or pet only while the green glow is off. | — | The week-6 request was "too cluttered": every item gets at most one glow and one star. |
| D10 | Pick 4: auto-sell default | **On**: gray (quality 0) items a vendor pays for, loaded, not held by the client, not locked, not in a set; **at most 12 per vendor visit** (one run), one item each 0.2 s; one chat line `Sold N junk items for Xg Ys Zc.`; when more wait, the same line says how many and to type `/swagbag sell junk`. | Settings > Vendor `Off`, or `/swagbag sell off`; `/swagbag sell junk` sells now. | "Sell at most what is safe": every item sold in a run can still be bought back during that visit. Gray junk rarely exceeds 12; the rest is one command away. |
| D11 | Pick 4: auto-repair default | **"Your gold"**: everything is repaired when a vendor that repairs opens, after the sale (so the junk's gold helps). Not enough gold: one line, no repair. | `Guild bank first` (the guild pays when it allows that much or has no limit, else your gold) and `Off`, in the same Settings row; `/swagbag repair own|guild|off`. | The user's words; the guild option is off by default because guild money is not the player's. |
| D12 | Pick 4: combat, and where it lives | Selling and repairing run from `MERCHANT_SHOW` through the Adapter (`C_Container.UseContainerItem` at a vendor sells; `RepairAllItems`). **Never in combat**: a vendor opened in combat waits until combat ends (`SB.OutOfCombat`) and then runs only if the vendor is still open (one line says so); combat during a run stops it (the line says how many stayed). | — | Item moves in combat help nobody and `UseContainerItem` is a protected use in combat. Nothing is queued past the visit. |
| D13 | Pick 4: the vendor focus mode and P5 | Unchanged: the AH/Vendor/Bank mode moves Junk to the top; the auto-sell then empties it item by item. A sold item leaves a placeholder in its cell (spec 4.3), the button goes to Free, and the mover waits while an item's button is under the mouse or an item is on the cursor. The window regroups on its next open, as always. | — | P5 holds with no new rule: the mover asks the bags window's own `ButtonBusy`. |
| D14 | Pick 5: what a lock is keyed by | **The item ID, account-wide** (`SwagBagDB.locks`): every stack and copy of that item, on every character. | Per link (one exact copy) was considered: an upgraded or enchanted copy changes its link and would silently lose its lock. | "Never sell my X" is about the item, and the lock must survive upgrades. |
| D15 | Pick 5: the gesture | **Drag the item onto a small `Lock` button** at the right end of the bags window's search row (or click Lock while holding the item); the item goes back where it came from. Again unlocks. A click with an empty cursor says how and how many are locked. The same drop target is on Settings > Vendor. The item tooltip says `Locked in SwagBag: never sold by SwagBag`. | `/swagbag lock list` and `lock clear`. | Alt+right-click needs a click hook on Blizzard's secure item button (spec 5.3 forbids click scripts on slot buttons) and, at a vendor, the right-click would still **sell** the item being locked. A drop is the proven header-drop pattern (AC4.3), uses SwagBag's own plain button only, and works in combat. |
| D16 | Pick 5: selling a locked item by hand | **No confirmation** (not feasible without taint: it would mean intercepting Blizzard's secure right-click or `UseContainerItem`). Instead, while a vendor is open, a locked item that leaves the bags **and** shows up in the vendor's buyback tab gets one chat line: `You sold <item>, which you locked. Buy it back from the vendor's Buyback tab if that was a mistake.` | — | Said plainly, as asked: warn in chat. The buyback check keeps a moved (not sold) item quiet. |
| D17 | Pick 5: the `locked` keyword | `locked` now means **locked by you**. The client's momentary lock on an item being moved, traded or sold (spec 7.3's old `locked`) is renamed `inuse`. | — | The user asked for `locked`; the old meaning had no use in a search or a category, and no built-in used it. Recorded for the spec update. |
| D18 | Pick 6: the gesture | **Shift+right-click** a section header in the bags window opens a small menu beside it. A header's tooltip names the gesture whenever an action is available (at a vendor or a bank). | — | Left-click collapses (AC3.2); right-click pins in the collapse style (AC8.3) and collapses in the front style (week-6 D3), so both are taken. A "..." button on every header would add a frame to each header and crowd the section totals. |
| D19 | Pick 6: routing at the bank | "Send all to bank" and "Send all to warband bank" pass the bank type to `C_Container.UseContainerItem(bag, slot, nil, bankType, false)` (the `bankType` argument exists since 11.0.0, warcraft.wiki.gg; EnhanceQoL's warband bank uses it). Blizzard's selected tab and bank type are **neither read nor written** for it, exactly like week 6's Deposit warbound (spec 5.2). Items the warband bank does not take (`C_Bank.IsItemAllowedInBankType`) are left out of its entry; a full tab stops the run. Right-click deposits still follow Blizzard's selected tab (spec 5.2, unchanged). | — | The user's choice is in the menu, so routing follows the menu, not the tab. If the argument does not route as documented, session BK1 shows it at once (the line names the bank) and the fallback is to show one entry, "Send all (deposits go to <selected>)". |
| D20 | Pick 6: confirmations | **Sell all asks first** (a SwagBag `StaticPopup`: count, section, about how much; locked and set items stay), capped at 12 like the auto-sell. Send all does not ask: nothing is lost, and a moved item is one right-click away. | — | The research's top fear for gold-makers is one wrong vendor click. |
| D21 | Pick 6: "Mail all" | **Left out.** | — | Attaching items to a letter needs the mail frame's own attachment slots and a send; it is not one safe call. |
| D22 | Pick 7: the worth line | **Fixed: 100 g or more for the stack** (value per unit × count; Auctionator's price, else the vendor's; a bound item at its vendor value, `Prices.Bound`). Shown while a bank visit is open, in the bags window and the bank window, as a **gold** glow. | `Your top 10%` (the most valuable tenth of the stacks in the bags and both banks), 500 g, 1000 g or Off in Settings > Bank & guild; `/swagbag worth <gold>`, `worth top <percent>`, `worth off`. | The spec's own default (F10, v1.1: "fixed threshold default 100 g, or top-X %"). Per stack, because 200 herbs at 1 g each are a reason to look at the stack. |
| D23 | Pick 9: the marker | A small **purple `*`** at the right middle of the button (a font string: no texture can go missing): gear whose appearance the account has not collected (`C_TransmogCollection.GetItemInfo` → `AccountCanCollectSource` → `PlayerHasTransmogItemModifiedAppearance`), and toys, mounts and pets not collected (only while the green glow is off, D9). Decor is the green glow's only. Setting `overlays.uncollected`, **on**. Search keyword `uncollected` (spec 7.3). | Off in Settings > Overlays or `/swagbag overlays uncollected off`. | No armor-type rule of SwagBag's own (12.2.5 lifts those restrictions); an appearance the account cannot collect, or a client that cannot say, gets no star. Cached per link; dropped on `TRANSMOG_COLLECTION_UPDATED`. |
| D24 | Pick 12: what a profile is | A **copy of the account settings the user set** (`SwagBagDB.settings`: only written values), saved under a name (1–24 characters). **Load replaces** the account settings with the copy; Safe Mode and the quick-setup flag are this machine's state and never travel; character overrides stay as they are. One step of **undo** (`/swagbag profile undo`) brings back the settings before the last load, import or "back to defaults". | Delete, Back to defaults (Settings > Profiles; `/swagbag profile delete <name>`, `reset`). | Simple and safe: switching never loses anything (undo), and nothing outside settings (categories, locks, snapshots) changes on a load. |
| D25 | Pick 12: the share string | **`SWAGBAG:1:` + `key=value` entries joined by `;`**: `s.<path>=` for each setting the user set (`b1`/`b0`, `n<number>`, `s<text>`), `w=` for the consumables watch list, and with categories `cu.<id>.<field>`, `ce.<id>.<field>`, `co=` for the user's categories, built-in edits and the order. Text is percent-escaped (only letters, digits, `.`, `_`, `-` stay), so the string has no spaces, no `|` (an edit box code) and survives line breaks a paste adds. | `Copy with categories` / `profile export categories`. | Versioned, compact, readable enough to diff in a report, and parsed with patterns only: nothing in a string is ever run (no `load`, no `loadstring`). |
| D26 | Pick 12: validation | Refused **whole**, with the reason: not ours, from a newer version (`SWAGBAG:2:`), longer than 30,000 characters or 1,500 entries, a bad escape or value, a known setting with the wrong type, a damaged watch list or category list. **Skipped and named**: settings this version does not know (a newer minor version). Category queries are compiled as usual on import (a broken one is saved disabled, spec 7.10). | — | Malformed or hostile input changes nothing; forward-compatible strings still import what they can. |
| D27 | Pick 12: import flow | Paste → **Preview** (every change as `path: old -> new`, the watch list, categories, skipped settings) → **Import**. Import refuses until the current text was previewed; editing the text needs a new preview. Import keeps the old settings for undo and answers once in chat: `Imported N changes. ...`. | — | Nothing changes before the user saw what changes. |
| D28 | Where the settings live | New page **Vendor** (auto-sell, repair, the lock drop target, list and unlock-all), new page **Profiles**; the worth row on **Bank & guild**; the learn, lock and uncollected rows on **Overlays**. Every row runs its chat command (P2: same answer). | — | Each setting next to its kin; P1 default first. |
| D29 | P2 for long runs | A run answers **once, when it ends** (one line counts what moved and what stayed and why). `/swagbag sell junk` prints nothing at once. | — | P2 "exactly once". |
| D30 | Saved data | Schema **stays 2**: new top-level tables read defensively, new settings only through `Config.Defaults`. | — | Nothing existing is converted. |


## What the week relies on (APIs and IDs, with where each was found)

Blizzard's FrameXML is not on disk. Names come from warcraft.wiki.gg, Wowhead and installed addons on Interface 120100 (read for **names and call shapes only**).

| What | Name / ID | Source | Confidence |
|---|---|---|---|
| Ascendant Venomstone | item **280562**; Max Stack 100; Binds when picked up; consumed 10 at a time at the Catalyst (Silvermoon) to raise a fully upgraded S2 Hero/Myth/Tidal Crafted weapon, trinket or necklace | Wowhead `item=280562` (12.1.5 PTR), warcraft.wiki.gg "Ascendant Venomstone" | PTR data; live from 2026-10-13. Confirm with `Season data` (SN1). |
| Sell at a vendor / move into a bank | `C_Container.UseContainerItem(bag, slot [, unit [, bankType [, reagentBankOpen]]])`; `bankType` added in 11.0.0 (`Enum.BankType.Character = 0`, `.Account = 2`) | warcraft.wiki.gg API page; EnhanceQoL WarbandBank (`UseContainerItem(bag, slot, nil, bankType, false)`), EnhanceQoLVendor (sells from a `C_Timer.After` chain, 0.1 s apart), Baganator (transfers) | The wiki marks it `#protected` (a use from secure code); addons call it out of combat for selling and banking. SwagBag calls it out of combat only. Confirm: no "Interface action failed" in VN1 / BK1. |
| Will that bank take this item | `C_Bank.IsItemAllowedInBankType(bankType, itemLocation)` | week 6 (already in `A.CHECKS`) | Checked in week 6's DP1. |
| Repair | `CanMerchantRepair()`, `GetRepairAllCost()` → cost, `RepairAllItems(guild)`, `CanGuildBankRepair()`, `GetGuildBankWithdrawMoney()` (-1: no limit) | TitanRepair, EnhanceQoL | Long-standing globals. |
| Buyback tab | `GetNumBuybackItems()`, `GetBuybackItemLink(i)` (i = 1..12) | long-standing globals | Index order not needed: SwagBag looks for the link anywhere in the tab. |
| Openable container | `hasLoot` in `C_Container.GetContainerItemInfo` | Syndicator BagCache, Baganator | Lockboxes also have `hasLoot` (D8). |
| Toys | `PlayerHasToy(itemID)`; `C_ToyBox.GetToyInfo` (already used for `isToy`) | Syndicator CheckItem | — |
| Mounts | `C_MountJournal.GetMountFromItem(itemID)` → mountID; `C_MountJournal.GetMountInfoByID(mountID)` 11th return = isCollected | Syndicator CheckItem | — |
| Pets | caged: species from `battlepet:<species>` in the link; items: `C_PetJournal.GetPetInfoByItemID(itemID)` 13th return = speciesID; `C_PetJournal.GetNumCollectedInfo(species)` → owned | Syndicator CheckItem | — |
| Decor | `C_HousingCatalog.GetCatalogEntryInfoByItem(itemID)` → `totalNumPlaced`, `remainingRedeemable`, `totalNumStored` | Syndicator CheckItem; horizon research (12.0.5 dropped the second argument) | — |
| Appearances | `C_TransmogCollection.GetItemInfo(link)` → appearanceID, sourceID; `AccountCanCollectSource(sourceID)` → hasData, canCollect; `PlayerHasTransmogItemModifiedAppearance(sourceID)` | Syndicator CheckItem (completionist check) | — |
| Collection events | `NEW_TOY_ADDED`, `NEW_MOUNT_ADDED`, `NEW_PET_ADDED`, `TRANSMOG_COLLECTION_UPDATED` | long-standing; `SB.On` skips an event the client does not know | — |
| Shift held | `IsShiftKeyDown()` | long-standing global | — |
| Textures | `bags-glow-white` atlas (the item buttons' new-item glow family), `Interface\PetBattles\PetBattle-LockIcon` (file path) | Blizzard's own UI | Eye check in LN1 / VN1; the glow falls back to a flat colour if the atlas is missing (tested pattern); the star is text. |


## Needs in-game confirmation (what could not be verified at the desk)

Each item names the session step that checks it. None blocks the build; a wrong answer comes back as a fix (usually a data edit).

| # | What | Why it is uncertain | Checked in |
|---|---|---|---|
| G1 | The Venomstone is **item 280562** on live 12.1.5, a bag item (not a currency) | PTR data only (Wowhead, warcraft.wiki.gg); the live game may renumber or turn it into a currency | SN1 steps 7–8 (the report's `Season data` line names both the item count and any currency with a season word) |
| G2 | A Venomstone-boosted item still reads its track (`M6/6`) with its new item level | The boost (from 2026-10-20) may add a track step or a new track string | SN1 step 9 |
| G3 | `C_Container.UseContainerItem` sells at a vendor and moves into a bank from SwagBag's timer chain, out of combat, with no "Interface action failed" | The wiki marks it `#protected`; addons on 12.1 call it from timers (EnhanceQoLVendor, Baganator), but SwagBag has never called it | VN1 step 8, BK1 steps 11 and 18 |
| G4 | The `bankType` argument routes to that bank whatever tab Blizzard has selected | Documented since 11.0.0 and used by EnhanceQoL, not seen by SwagBag | BK1 steps 11–12 (if not, D19's fallback) |
| G5 | `IsItemAllowedInBankType` leaves soulbound items out of "Send all to warband bank", and a full tab leaves the item in the bags unlocked (so the run stops as "stuck") | The client might keep the item locked a moment longer than 2 s (`MAX_PENDING` × `DELAY`) | BK1 step 11 |
| G6 | `RepairAllItems`, `GetRepairAllCost`, `CanMerchantRepair`, guild repair money | Long-standing, unchanged in 12.1 notes | VN1 step 8 |
| G7 | The buyback tab lists the sold item's exact link (`GetBuybackItemLink`), so the locked-item warning fires | A link could differ by a context suffix after the sale | VN1 step 10 |
| G8 | Collection answers: `PlayerHasToy`, `C_MountJournal.GetMountInfoByID` 11th return, `C_PetJournal.GetPetInfoByItemID` 13th return, `C_HousingCatalog.GetCatalogEntryInfoByItem` fields, `C_TransmogCollection` (three calls) | Return positions and field names come from Syndicator's 12.1 code, not from Blizzard's documentation | LN1 steps 3–6 |
| G9 | Profession knowledge items are named "... Treatise ..." in Midnight | Two expansions used that name; Midnight's other knowledge items need IDs | LN1 step 4 (the user names any that do not glow) |
| G10 | The `bags-glow-white` atlas exists and reads as a soft glow when tinted; `Interface\PetBattles\PetBattle-LockIcon` exists | Atlas and file names are from memory of Blizzard's UI; a missing atlas falls back to a flat tint, a missing file would show nothing (or a green square) | LN1 step 3, VN1 step 5 |
| G11 | `TRANSMOG_COLLECTION_UPDATED` / `NEW_TOY_ADDED` fire when expected and not every frame | Event frequency is not documented | LN1 step 6 (and no stutter while looting) |
| G12 | Shift+right-click on a header reaches SwagBag (no other addon binds Shift+right-click there) | Keybinding addons could | BK1 steps 9 and 15 |
| G13 | A lockbox showing the green glow is acceptable | Product taste | LN1 step 12 |


## Week-6 carry-overs

The week-6 ledger's deferred items are all minors (wording, test-only gaps) or belong to the bank and guild list view, which rewrites `UI/GroupView.lua`. None of this week's tasks touches `UI/GroupView.lua`, `Providers/Syndicator.lua` or `UI/SafeModeHooks.lua`, so they stay deferred, unchanged: the guild bank pending-item relayout gap, the list view for the bank and guild windows, Syndicator loaded mid-session, and the week-6 Task 5–9 minors. The week-6 checklists' open in-game checks (L1, TH1, OF1, DP1) are unchanged.

The horizon research's urgent item for 12.1.5 (2026-10-13: deprecated item and currency globals removed) needs nothing here: every item and currency call is already in `SwagBag/Core/Adapter.lua` through `C_Item`, `C_CurrencyInfo` and `C_Container`, and no new code calls a deprecated global.

---

## File structure (end of week 7)

New and changed files only. Everything else is as on `a1f7f86`.

```
SwagBag/Engine/CategoryDefaults.lua    MOD  (T1) c_sets
SwagBag/Core/Config.lua                MOD  (T1) focus sections gain c_sets; (T3) overlays.learn; (T4) vendor.*; (T5) overlays.lock;
                                            (T7) prices.worth*; (T8) overlays.uncollected
SwagBag/Engine/OverlayData.lua         MOD  (T1) junk skips set pieces; (T3) learn; (T5) locked; (T8) uncollected
SwagBag/Engine/Crests.lua              MOD  (T2) season data: currencyWords, items (Venomstone); (T3) knowledge
SwagBag/UI/Footer.lua                  MOD  (T2) SeasonItems, SeasonText, the crests entry, item tooltip, season count refresh
SwagBag/Core/Report.lua                MOD  (T2) Season data line
SwagBag/Engine/Collections.lua         NEW  (T3) Learn, cache, events; (T8) Uncollected, teaches, TRANSMOG_COLLECTION_UPDATED
SwagBag/Core/Adapter.lua               MOD  (T3) hasLoot, Toy/Mount/Pet/DecorKnown; (T4) SellItem, MoveToBank, RepairCost, Repair,
                                            GuildRepairMoney; (T5) BuybackLinks; (T6) AllowedInBank, ShiftDown; (T8) AppearanceKnown;
                                            optional CHECKS for each
SwagBag/Engine/Items.lua               MOD  (T3) hasLoot
SwagBag/UI/Overlays.lua                MOD  (T3) glow (green); (T5) padlock; (T7) gold glow at the bank, /swagbag worth; (T8) star
SwagBag/UI/SettingsPages.lua           MOD  (T3, T5, T8) overlay rows; (T7) the worth row on Bank & guild
SwagBag/Engine/Mover.lua               NEW  (T4) one item at a time, out of combat, never under the mouse
SwagBag/Engine/Vendor.lua              NEW  (T4) auto-sell, auto-repair, /swagbag sell, /swagbag repair; (T5) locked-item warning
SwagBag/UI/SettingsVendor.lua          NEW  (T4) Settings > Vendor; (T5) lock rows
SwagBag/Engine/Locks.lua               NEW  (T5) locks, /swagbag lock, tooltip line
SwagBag/UI/LockButton.lua              NEW  (T5) the Lock button, the tooltip hook
SwagBag/Engine/Keywords.lua            MOD  (T5) locked (user), inuse; (T8) uncollected
SwagBag/UI/SearchBox.lua               MOD  (T5) rightInset
SwagBag/UI/SectionActions.lua          NEW  (T6) the menu, Sell all, Send all, hints
SwagBag/UI/SectionHeaders.lua          MOD  (T6) onClick passes the header; onEnter/onLeave
SwagBag/UI/BagsWindow.lua              MOD  (T6) Shift+right-click, header hint, W.SectionSlots
SwagBag/Engine/Prices.lua              MOD  (T7) WorthThreshold
SwagBag/Engine/Profiles.lua            NEW  (T9) profiles, share string, parse, preview, import, /swagbag profile
SwagBag/UI/ShareBox.lua                NEW  (T9) the copy / paste box
SwagBag/UI/SettingsProfiles.lua        NEW  (T9) Settings > Profiles
SwagBag/Locale/enUS.lua                MOD  (T1–T9)
SwagBag/SwagBag.toc, SwagBag/Core/Init.lua   MOD  (T1) 0.7.0; (T3–T6, T9) new files
.luacheckrc                            MOD  (T3) C_MountJournal, C_PetJournal, C_HousingCatalog; (T8) C_TransmogCollection
spec/collections_spec.lua (T3, T8), mover_spec.lua, vendor_spec.lua (T4, T5), locks_spec.lua (T5), sectionactions_spec.lua (T6),
spec/profiles_spec.lua (T9)                                                                                          NEW
spec/fixtures/items.lua, items_spec.lua, keywords_spec.lua (T1, T5), categories_spec.lua, categorizer_spec.lua (T1, T2),
spec/focus_spec.lua, settings_focus_spec.lua, bagswindow_sections_spec.lua (T1, T6), overlaydata_spec.lua (T1, T2),
spec/footer_spec.lua, report_spec.lua (T2), adapter_spec.lua (T3, T8), overlays_spec.lua (T3, T5, T7, T8),
spec/mock_adapter.lua (T3–T6, T8), searchbox_spec.lua (T5), prices_spec.lua, settings_spec.lua (T7)                  MOD
```

The TOC grows from 62 to 72 files: `TOC OK (62 files)` after Tasks 1–2, 63 after Task 3, 66 after Task 4, 68 after Task 5, 69 after Tasks 6–8, 72 after Task 9.

## Schedule (week 7)

In the user's order, so the earlier picks ship first if time runs out. The user plays keys daily and the Venomstone patch is live 2026-10-13 (the crest cap lifts the week of 2026-10-20).

| Day | Tasks | User in game? |
|---|---|---|
| 1 | 1, 2 | after the merge: session SN1 (sets, Venomstones, about 10 minutes) |
| 1 | 3 | after the merge: session LN1 (with Task 8) |
| 2 | 4, 5 | after the merge: session VN1 (vendor, locks, about 15 minutes) |
| 3 | 6, 7 | after the merge: session BK1 (bank and vendor, about 15 minutes) |
| 3 | 8 | after the merge: session LN1 (glow and star, about 10 minutes) |
| 4 | 9 | after the merge: session PF1 (profiles, about 10 minutes); **Week 7 exit check** |

Cumulative `scripts/check.sh` test totals (from 1281 on `a1f7f86`). Each was produced by replaying this file's blocks in order on a fresh clone of `a1f7f86`:
- T1 1285 passed, 0 failed (+4)
- T2 1292 passed, 0 failed (+7)
- T3 1298 passed, 0 failed (+6)
- T4 1314 passed, 0 failed (+16)
- T5 1325 passed, 0 failed (+11)
- T6 1334 passed, 0 failed (+9)
- T7 1339 passed, 0 failed (+5)
- T8 1343 passed, 0 failed (+4)
- T9 1356 passed, 0 failed (+13)

## How to read the code steps

- A **Create** step gives a complete new file.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point and its replacement. The block occurs exactly once in the file, and starts and ends on a non-blank line. When a step edits one file in several places, the places are numbered "(edit N of M)". Apply them in that order, top to bottom. Each find block is unique in the file as it is after the earlier edits.
- No step replaces a whole existing file.
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks (everything else, `.luacheckrc` and the TOC included). Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists its critical tests and, for each, the code change (mutation) that must make it fail. Every mutation was applied to the finished code of its task and the named test failed. A reviewer re-runs any of them with a one-line edit. In a mutation, ` ⏎ ` marks a line break and `∅` an empty replacement.
- A test that passes at Step 2 is named there with the reason.


---

### Task 1: An Equipment sets section for M+, Raid and Delves, never junk; v0.7.0

User pick 1. A built-in category `c_sets` "Equipment sets" (`equipped`, priority 92, right after Gear, `after = "c_gear"`; D1) joins the default section sets of the M+, Raid and Delves modes (D2). The junk coin skips a gray piece in a set (D3). The `SmallBags` fixture's helm leaves its equipment set, so the existing window tests keep their sections (D4); every test that lists the category set, the priority order or a mode's default set gains `c_sets`. The version goes to 0.7.0.

**Files:**
- Modify: `SwagBag/Engine/CategoryDefaults.lua` (`c_sets`), `SwagBag/Core/Config.lua` (`focus.sections.mplus/raid/delves`), `SwagBag/Engine/OverlayData.lua` (junk skips set pieces), `SwagBag/Locale/enUS.lua` (`CAT_SETS`)
- Modify: `SwagBag/SwagBag.toc`, `SwagBag/Core/Init.lua` (0.7.0)
- Test: `spec/fixtures/items.lua` (the helm leaves its set), `spec/items_spec.lua`, `spec/keywords_spec.lua` (put the set flag on their own slot), `spec/categories_spec.lua`, `spec/categorizer_spec.lua`, `spec/focus_spec.lua`, `spec/settings_focus_spec.lua`, `spec/bagswindow_sections_spec.lua`, `spec/overlaydata_spec.lua`

**Interfaces:**
- Consumes: `Items.inEquipmentSet` and the `equipped` keyword (week 1), the `after` field (week 6, `Categories.Load`), `Focus.Sections`.
- Produces: the category id `c_sets` (Task 4's `Vendor.Protected` and Task 6's Sell all treat set pieces as never for sale through `record.inEquipmentSet`, not through the category); `L.CAT_SETS`; `SB.VERSION = "0.7.0"`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua` (edit 1 of 2), find:

```lua
		assert.equal("M+: on, active now - opens Consumables, Keystone & Crests, Gear", lines[6])
```

and replace it with:

```lua
		assert.equal("M+: on, active now - opens Consumables, Keystone & Crests, Gear, Equipment sets", lines[6])
```

In `spec/bagswindow_sections_spec.lua` (edit 2 of 2), find:

```lua
	end)

	-- Pins week-4 D10 for the new style: the grid view has no sections, only the title changes.
```

and replace it with:

```lua
	end)

	-- Week 7 (user pick 1). Mutation: give c_sets priority 60 (the set helm files under Gear).
	it("a set piece has its own section right after Gear, and a key moves it up with Gear", function()
		A.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true, inSet = true })
		A.Put(0, 7, Fixtures.SOULBOUND_HELM, 1, { isBound = true })
		W.Open()
		assert.same({ "- New (0)", "- Keystone & Crests (1)", "- Consumables (2)", "- Gear (1)", "- Equipment sets (1)",
			"- BoE gear (1)", "- Junk (1)", "- Free (9)" }, headers())
		F.SetSignal("challengeMode", true)
		assert.same({ "- New (0)", "- Consumables (2)", "- Keystone & Crests (1)", "- Gear (1)", "- Equipment sets (1)",
			"- BoE gear (1)", "- Junk (1)", "- Free (9)" }, headers())
	end)

	-- Pins week-4 D10 for the new style: the grid view has no sections, only the title changes.
```

In `spec/categories_spec.lua` (edit 1 of 7), find:

```lua
	c_boe = { "boe", "gear" }, c_wue = { "gear", "wue" }, c_tradegoods = { "reagent", "tradegoods" }, c_herbs = { "herb" }, c_ore = { "ore" },
```

and replace it with:

```lua
	c_sets = { "equipped" }, c_boe = { "boe", "gear" }, c_wue = { "gear", "wue" },
	c_tradegoods = { "reagent", "tradegoods" }, c_herbs = { "herb" }, c_ore = { "ore" },
```

In `spec/categories_spec.lua` (edit 2 of 7), find:

```lua
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_wue", "c_tradegoods", "c_herbs", "c_ore",
			"c_leathercloth", "c_enchanting", "c_cooking", "c_fish", "c_quest", "c_housing", "c_collect", "c_tools",
			"c_junk", "c_other", "free" }, C.SectionOrder())
```

and replace it with:

```lua
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_sets", "c_boe", "c_wue", "c_tradegoods", "c_herbs",
			"c_ore", "c_leathercloth", "c_enchanting", "c_cooking", "c_fish", "c_quest", "c_housing", "c_collect", "c_tools",
			"c_junk", "c_other", "free" }, C.SectionOrder())
		assert.equal("Equipment sets", C.Name("c_sets"))
```

In `spec/categories_spec.lua` (edit 3 of 7), find:

```lua
		assert.same({ "c_reagents", "c_keystone", "c_junk", "c_quest", "c_tools", "c_boe", "c_wue", "c_gear",
			"c_consumables" }, { unpack(p, 1, 9) })
```

and replace it with:

```lua
		assert.same({ "c_reagents", "c_keystone", "c_sets", "c_junk", "c_quest", "c_tools", "c_boe", "c_wue", "c_gear",
			"c_consumables" }, { unpack(p, 1, 10) })
```

In `spec/categories_spec.lua` (edit 4 of 7), find:

```lua
		SB.Config.db.categoryOrder = { "c_junk", "gone", "c_gear" }
		C.Load()
		assert.same({ "new", "c_junk", "c_gear", "c_keystone" }, { unpack(C.SectionOrder(), 1, 4) })
	end)
```

and replace it with:

```lua
		SB.Config.db.categoryOrder = { "c_junk", "gone", "c_gear" }
		C.Load()
		assert.same({ "new", "c_junk", "c_gear", "c_sets", "c_keystone" }, { unpack(C.SectionOrder(), 1, 5) })
	end)
```

In `spec/categories_spec.lua` (edit 5 of 7), find:

```lua
		assert.same({ "new", "c_keystone", "c_tradegoods", "c_boe", "c_wue", "c_consumables" },
			{ unpack(C.SectionOrder(), 1, 6) })
		SB.Config.db.categoryOrder = { "c_junk", "c_gear" } -- BoE gear not saved: WuE follows with the rest
		C.Load()
		assert.same({ "new", "c_junk", "c_gear", "c_keystone" }, { unpack(C.SectionOrder(), 1, 4) })
```

and replace it with:

```lua
		assert.same({ "new", "c_keystone", "c_tradegoods", "c_boe", "c_wue", "c_consumables", "c_gear", "c_sets",
			"c_herbs" }, { unpack(C.SectionOrder(), 1, 9) }, "Equipment sets (week 7) joins right after Gear")
		SB.Config.db.categoryOrder = { "c_junk", "c_gear" } -- BoE gear not saved: WuE follows with the rest
		C.Load()
		assert.same({ "new", "c_junk", "c_gear", "c_sets", "c_keystone" }, { unpack(C.SectionOrder(), 1, 5) })
```

In `spec/categories_spec.lua` (edit 6 of 7), find:

```lua
		assert.equal(20, total)
```

and replace it with:

```lua
		assert.equal(21, total)
```

In `spec/categories_spec.lua` (edit 7 of 7), find:

```lua
		assert.truthy(text:find("\nCategories: 19 (0 edited)  Broken: Fish & Lures", 1, true))
```

and replace it with:

```lua
		assert.truthy(text:find("\nCategories: 20 (0 edited)  Broken: Fish & Lures", 1, true))
```

In `spec/categorizer_spec.lua`, find:

```lua
	end

	it("files the fixture bag into the default sections, keystones and caged pets by link", function()
```

and replace it with:

```lua
	end

	-- Week 7 (user pick 1). Mutation: give c_sets priority 60 (below Gear, BoE gear and Junk).
	it("an item in an equipment set is filed under Equipment sets, never as Junk, BoE gear, WuE or Gear", function()
		A.AddItem(400100, { name = "Frayed Robe", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CHEST",
			quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 12 })
		A.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true, inSet = true })
		A.Put(0, 7, Fixtures.SOULBOUND_HELM, 1, { isBound = true })
		A.Put(0, 8, Fixtures.BOE_RING, 1, { inSet = true })
		A.Put(0, 9, Fixtures.BOE_RING, 1, { isWUE = true, inSet = true })
		A.Put(0, 10, 400100, 1, { inSet = true })
		A.Put(0, 11, 400100, 1)
		assert.same({ "c_sets", "c_gear", "c_sets", "c_sets", "c_sets", "c_junk" },
			{ at(4), at(7), at(8), at(9), at(10), at(11) })
	end)

	it("files the fixture bag into the default sections, keystones and caged pets by link", function()
```

In `spec/fixtures/items.lua` (edit 1 of 2), find:

```lua
-- A small backpack: 16 slots, 6 items.
```

and replace it with:

```lua
-- A small backpack: 16 slots, 6 items. The helm is in no equipment set (week 7: a set piece has its
-- own section); a test that needs one puts { inSet = true } on its own slot.
```

In `spec/fixtures/items.lua` (edit 2 of 2), find:

```lua
	m.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true, inSet = true })
```

and replace it with:

```lua
	m.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true })
```

In `spec/focus_spec.lua` (edit 1 of 6), find:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Front())
```

and replace it with:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Front())
```

In `spec/focus_spec.lua` (edit 2 of 6), find:

```lua
		assert.equal(1, withBoe, "only the market mode opens BoE gear")
```

and replace it with:

```lua
		assert.equal(1, withBoe, "only the market mode opens BoE gear")
	end)

	-- Week 7 (user pick 1): the modes that open Gear also open Equipment sets; the market mode never
	-- does (a set piece is never for sale). Mutation: drop c_sets from the raid default.
	it("M+, Raid and Delves open Equipment sets; AH/Vendor/Bank, Gathering and Fishing do not", function()
		local function has(mode)
			for _, v in ipairs(F.Sections(mode)) do
				if v == "c_sets" then
					return true
				end
			end
			return false
		end
		for _, mode in ipairs({ "mplus", "raid", "delves" }) do
			assert.truthy(has(mode), mode)
		end
		for _, mode in ipairs({ "market", "gathering", "fishing" }) do
			assert.falsy(has(mode), mode)
		end
```

In `spec/focus_spec.lua` (edit 3 of 6), find:

```lua
		assert.is_nil(SB.Config.db.settings.focus.sections.mplus)
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
```

and replace it with:

```lua
		assert.is_nil(SB.Config.db.settings.focus.sections.mplus)
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Sections("mplus"))
```

In `spec/focus_spec.lua` (edit 4 of 6), find:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
```

and replace it with:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Sections("mplus"))
```

In `spec/focus_spec.lua` (edit 5 of 6), find:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_fish", "c_cooking" }, F.Front())
		SB.Config.Set("focus.resolve", "priority")
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Front(), "priority: M+ only (mode order)")
```

and replace it with:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets", "c_fish", "c_cooking" }, F.Front())
		SB.Config.Set("focus.resolve", "priority")
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Front(), "priority: M+ only (mode order)")
```

In `spec/focus_spec.lua` (edit 6 of 6), find:

```lua
		assert.truthy(F.SetSections("mplus", { "c_consumables", "c_keystone", "c_gear" }))
```

and replace it with:

```lua
		assert.truthy(F.SetSections("mplus", { "c_consumables", "c_keystone", "c_gear", "c_sets" }))
```

In `spec/items_spec.lua`, find:

```lua
		A.Put(0, 10, Fixtures.TOY, 1, { isLocked = true })
```

and replace it with:

```lua
		A.Put(0, 10, Fixtures.TOY, 1, { isLocked = true })
		A.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true, inSet = true })
```

In `spec/keywords_spec.lua`, find:

```lua
	Fixtures.SmallBags(A)
```

and replace it with:

```lua
	Fixtures.SmallBags(A)
	A.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true, inSet = true }) -- in an equipment set (the fixture's is not)
```

In `spec/overlaydata_spec.lua`, find:

```lua
		assert.equal(false, O.For(SB.Items.Describe(0, 1)).junk)
```

and replace it with:

```lua
		assert.equal(false, O.For(SB.Items.Describe(0, 1)).junk)
	end)

	-- Week 7: a gray piece kept in an equipment set is not junk. Mutation: drop `and not record.inEquipmentSet`.
	it("no junk coin on a gray item in an equipment set", function()
		A.AddItem(400100, { name = "Frayed Robe", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CHEST",
			quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 12 })
		A.Put(0, 7, 400100, 1)
		A.Put(0, 8, 400100, 1, { inSet = true })
		assert.equal(true, O.For(SB.Items.Describe(0, 7)).junk)
		assert.equal(false, O.For(SB.Items.Describe(0, 8)).junk)
```

In `spec/settings_focus_spec.lua` (edit 1 of 6), find:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_junk" }, F.Sections("mplus"))
		assert.equal("Junk now opens in the M+ mode.", SW.lastStatus)
		click("Gear", L.SET_SECTION_CLOSED)
		assert.same({ "c_consumables", "c_keystone", "c_junk" }, F.Sections("mplus"))
```

and replace it with:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets", "c_junk" }, F.Sections("mplus"))
		assert.equal("Junk now opens in the M+ mode.", SW.lastStatus)
		click("Gear", L.SET_SECTION_CLOSED)
		assert.same({ "c_consumables", "c_keystone", "c_sets", "c_junk" }, F.Sections("mplus"))
```

In `spec/settings_focus_spec.lua` (edit 2 of 6), find:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "free" }, F.Sections("mplus"))
```

and replace it with:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets", "free" }, F.Sections("mplus"))
```

In `spec/settings_focus_spec.lua` (edit 3 of 6), find:

```lua
		click(L.SET_SECTIONS_DEFAULT_LABEL, L.SET_RESET_DEFAULT)
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
```

and replace it with:

```lua
		click(L.SET_SECTIONS_DEFAULT_LABEL, L.SET_RESET_DEFAULT)
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Sections("mplus"))
```

In `spec/settings_focus_spec.lua` (edit 4 of 6), find:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"), "M+ untouched")
```

and replace it with:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Sections("mplus"), "M+ untouched")
```

In `spec/settings_focus_spec.lua` (edit 5 of 6), find:

```lua
		assert.equal("c_consumables,c_keystone,c_gear,c_junk", SB.Config.charDB.overrides["focus.sections.mplus"])
```

and replace it with:

```lua
		assert.equal("c_consumables,c_keystone,c_gear,c_sets,c_junk", SB.Config.charDB.overrides["focus.sections.mplus"])
```

In `spec/settings_focus_spec.lua` (edit 6 of 6), find:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
```

and replace it with:

```lua
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_sets" }, F.Sections("mplus"))
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1263 passed, 22 failed`. The failures, exactly:

- `spec/bagswindow_sections_spec.lua :: BagsWindow focus modes (spec 6) > /swagbag mode answers every form (P2)`
- `spec/bagswindow_sections_spec.lua :: BagsWindow focus front style (week 6) > a set piece has its own section right after Gear, and a key moves it up with Gear`
- `spec/categories_spec.lua :: Categories > ships the spec 7.6 set in display order, with New first and Free last`
- `spec/categories_spec.lua :: Categories > orders rules by priority, ties by id, never by table order`
- `spec/categories_spec.lua :: Categories > a saved categoryOrder wins; unknown ids are skipped and the rest follow`
- `spec/categories_spec.lua :: Categories > a built-in added later joins a saved order right after the one it follows (WuE after BoE gear)`
- `spec/categories_spec.lua :: Categories > Counts reports totals, edited categories and broken ones`
- `spec/categories_spec.lua :: Categories > /swagbag report shows category counts and broken categories`
- `spec/categorizer_spec.lua :: Categorizer > an item in an equipment set is filed under Equipment sets, never as Junk, BoE gear, WuE or Gear`
- `spec/focus_spec.lua :: Focus > a character override or a reset of a focus setting updates the view (W4-10)`
- `spec/focus_spec.lua :: Focus > M+, Raid and Delves open Equipment sets; AH/Vendor/Bank, Gathering and Fishing do not`
- `spec/focus_spec.lua :: Focus > section sets are stored as text; reset removes the stored set so a new default applies`
- `spec/focus_spec.lua :: Focus > with a character override, reset puts the default into the override and keeps it`
- `spec/focus_spec.lua :: Focus front style (week 6) > merge: two modes move both sets up, each section once, the first mode's first`
- `spec/focus_spec.lua :: Focus front style (week 6) > a focus writer whose value is already in force emits nothing`
- `spec/overlaydata_spec.lua :: OverlayData (spec F9) > no junk coin on a gray item in an equipment set`
- `spec/settings_focus_spec.lua :: Settings: focus modes page > a section opened for M+ joins its set; the M+ mode then opens it`
- `spec/settings_focus_spec.lua :: Settings: focus modes page > the editor has a Free row; toggling it changes the mode's sections`
- `spec/settings_focus_spec.lua :: Settings: focus modes page > Reset to default brings the built-in set back`
- `spec/settings_focus_spec.lua :: Settings: focus modes page > picking another mode shows its sections`
- `spec/settings_focus_spec.lua :: Settings: focus modes page > AC15.1: "This character" makes every focus setting this character's own; back again clears them`
- `spec/settings_focus_spec.lua :: Settings: focus modes page > read-only settings: every focus change refuses with the reason`

Two edited tests pass already, as they should: `Items.Describe > fills the state flags` and `Keywords > state keywords` now put the set flag on their own slot, which the code has always read.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "an item in an equipment set is filed under Equipment sets, never as Junk, BoE gear, WuE or Gear": in `SwagBag/Engine/CategoryDefaults.lua`, `query = "equipped", priority = 92` → `query = "equipped", priority = 60`.
- "a set piece has its own section right after Gear, and a key moves it up with Gear": in `SwagBag/Engine/CategoryDefaults.lua`, `query = "equipped", priority = 92` → `query = "equipped", priority = 60`.
- "M+, Raid and Delves open Equipment sets; AH/Vendor/Bank, Gathering and Fishing do not": in `SwagBag/Core/Config.lua`, `raid = "c_consumables,c_gear,c_sets"` → `raid = "c_consumables,c_gear"`.
- "no junk coin on a gray item in an equipment set": in `SwagBag/Engine/OverlayData.lua`, `not record.hasNoValue and not record.inEquipmentSet` → `not record.hasNoValue`.
- "a built-in added later joins a saved order right after the one it follows (WuE after BoE gear)": in `SwagBag/Engine/CategoryDefaults.lua`, `, after = "c_gear" }` → `}`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Config.lua` (edit 1 of 2), find:

```lua
		-- (a mode collapses every section it does not open; week 4's behaviour). Week 6, user request.
```

and replace it with:

```lua
		-- (a mode collapses every section it does not open; week 4's behaviour). Week 6, user request.
		-- Equipment sets (c_sets, week 7) join every mode that opens Gear.
```

In `SwagBag/Core/Config.lua` (edit 2 of 2), find:

```lua
				mplus = "c_consumables,c_keystone,c_gear",
				raid = "c_consumables,c_gear",
				delves = "c_consumables,c_gear",
```

and replace it with:

```lua
				mplus = "c_consumables,c_keystone,c_gear,c_sets",
				raid = "c_consumables,c_gear,c_sets",
				delves = "c_consumables,c_gear,c_sets",
```

In `SwagBag/Core/Init.lua`, find:

```lua
SB.VERSION = "0.6.0"
```

and replace it with:

```lua
SB.VERSION = "0.7.0"
```

In `SwagBag/Engine/CategoryDefaults.lua`, find:

```lua
	{ id = "c_gear", name = L.CAT_GEAR, query = "gear", priority = 70, displayOrder = 30 },
```

and replace it with:

```lua
	{ id = "c_gear", name = L.CAT_GEAR, query = "gear", priority = 70, displayOrder = 30 },
	-- Week 7 (user pick 1): items in any of the character's equipment sets (the "equipped" keyword,
	-- Items.inEquipmentSet). Priority 92: above Junk (90), BoE gear (75) and Gear (70), so a set piece
	-- is never filed as junk or as gear to sell; below Keystone & Crests (95) and Reagents (100).
	{ id = "c_sets", name = L.CAT_SETS, query = "equipped", priority = 92, displayOrder = 35, after = "c_gear" },
```

In `SwagBag/Engine/OverlayData.lua` (edit 1 of 2), find:

```lua
--     junk      boolean         poor quality and a vendor pays for it
```

and replace it with:

```lua
--     junk      boolean         poor quality, a vendor pays for it, and not in an equipment set
```

In `SwagBag/Engine/OverlayData.lua` (edit 2 of 2), find:

```lua
	out.junk = record.quality == 0 and not record.hasNoValue
```

and replace it with:

```lua
	-- A gray piece in an equipment set is never marked as junk (week 7: set items are never sellable).
	out.junk = record.quality == 0 and not record.hasNoValue and not record.inEquipmentSet
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.CAT_BOE = "BoE gear"
```

and replace it with:

```lua
L.CAT_BOE = "BoE gear"
L.CAT_SETS = "Equipment sets"
```

In `SwagBag/SwagBag.toc`, find:

```text
## Version: 0.6.0
```

and replace it with:

```text
## Version: 0.7.0
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1285 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (62 files)`, `1285 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Config.lua \
	SwagBag/Core/Init.lua \
	SwagBag/Engine/CategoryDefaults.lua \
	SwagBag/Engine/OverlayData.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	spec/bagswindow_sections_spec.lua \
	spec/categories_spec.lua \
	spec/categorizer_spec.lua \
	spec/fixtures/items.lua \
	spec/focus_spec.lua \
	spec/items_spec.lua \
	spec/keywords_spec.lua \
	spec/overlaydata_spec.lua \
	spec/settings_focus_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 1: Equipment sets section (c_sets) for M+, Raid and Delves, never junk; v0.7.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 2: Season data: the Venomstones next to the crests, and a report line to confirm the IDs

User pick 2. `Engine/Crests.lua` becomes the season data file (D6): crest IDs and words, the season's currency words (now with `venomstone`, the probe if the live game makes it a currency), and the season's bag items (`items`: the Venomstone, item 280562, D5), which also file under Keystone & Crests by ID. The footer's crests entry adds each season item the bags hold, with its own tooltip; a Venomstone looted onto its stack refreshes the footer (the one exception to W4-26). `/swagbag report` gains `Season data: crest currencies ...; season items in bags ...` so the user confirms the IDs in game (SN1 step 8). A test pins the upgrade-track overlay on a Venomstone-boosted item (D7: no code change).

**Files:**
- Modify: `SwagBag/Engine/Crests.lua` (season data), `SwagBag/UI/Footer.lua` (`SeasonItems`, `SeasonText`, the crests entry, the item tooltip, the count refresh), `SwagBag/Core/Report.lua` (the Season data line), `SwagBag/Locale/enUS.lua`
- Test: `spec/footer_spec.lua`, `spec/report_spec.lua`, `spec/categorizer_spec.lua` (loads `Engine/Crests.lua`), `spec/overlaydata_spec.lua`

**Interfaces:**
- Consumes: `Footer.Crests`, `crestName`, `SB.Inventory.Iterate("bags")`, `Adapter.CurrencyList/GetItemInfo/GetItemInstant`, the crest keyword (`SB.Crests.ids`).
- Produces: `SB.Crests = { ids, words, currencyWords, currencies, items, ... }` (Task 3 adds `knowledge`); `Footer.SeasonItems() -> { { id, quantity, icon } }`; `Footer.SeasonText() -> currencies, items`; the tooltip kind `"item"`; `L.REPORT_SEASON`, `L.REPORT_SEASON_ENTRY`.

- [ ] **Step 1: Write the failing tests**

In `spec/categorizer_spec.lua` (edit 1 of 2), find:

```lua
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
```

and replace it with:

```lua
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Crests.lua", "SwagBag/Engine/Keywords.lua",
```

In `spec/categorizer_spec.lua` (edit 2 of 2), find:

```lua
			{ at(4), at(7), at(8), at(9), at(10), at(11) })
```

and replace it with:

```lua
			{ at(4), at(7), at(8), at(9), at(10), at(11) })
	end)

	-- Week 7 (user pick 2): Ascendant Venomstone is a consumable by class, an upgrade currency by use.
	-- Mutation: SB.Crests.ids = {} in Engine/Crests.lua.
	it("Ascendant Venomstones file under Keystone & Crests by item ID", function()
		A.AddItem(280562, { name = "Ascendant Venomstone", classID = A.ITEM_CLASS.Consumable, subclassID = 8, quality = 4,
			maxStack = 100, bind = "pickup" })
		A.Put(0, 7, 280562, 10)
		assert.equal("c_keystone", at(7))
```

In `spec/footer_spec.lua`, find:

```lua
		assert.same({ "123", "500", "900", "AKCE +12", "10 free" }, texts())
```

and replace it with:

```lua
		assert.same({ "123", "500", "900", "AKCE +12", "10 free" }, texts())
	end)

	-- Week 7 (user pick 2). Mutation: in Footer.Items, drop the F.SeasonItems() loop.
	it("crests: the Venomstones in the bags show after the crest currencies, counted over every stack", function()
		A.AddItem(280562, { name = "Ascendant Venomstone", classID = A.ITEM_CLASS.Consumable, subclassID = 8, quality = 4,
			maxStack = 100, bind = "pickup" })
		A.Put(0, 7, 280562, 6)
		A.SetBagSize(1, 10)
		A.Put(1, 2, 280562, 4)
		SB.Inventory.ScanAll()
		F.Refresh()
		assert.same({ "123", "500", "45", "10", "AKCE +12", "18 free" }, texts())
		assert.same({ entry = "crests", text = "10", icon = 280562, tip = { kind = "item", id = 280562 } }, F.items[4])
		Fake.Fire(F.widgets[4], "OnEnter")
		assert.same({ 280562 }, GameTooltip.calls.SetItemByID, "the item's own tooltip")
		A.Clear(0, 7)
		A.Clear(1, 2)
		SB.Inventory.ScanAll()
		F.Refresh()
		assert.same({ "123", "500", "45", "AKCE +12", "20 free" }, texts(), "none carried: nothing shows")
	end)

	-- Week 7: should the live game make Venomstones a currency, the season words find it. Mutation: drop
	-- "venomstone" from SB.Crests.currencyWords.
	it("crests: a currency named like the season's (Venomstone) shows when no currency IDs are confirmed", function()
		A.currencies[#A.currencies + 1] = { id = 3400, name = "Ascendant Venomstone", quantity = 30, icon = 5 }
		F.Refresh()
		assert.same({ "123", "500", "45", "30", "AKCE +12", "10 free" }, texts())
	end)

	-- Week 7. Mutation: in the Inventory listener, drop `or (Inv.Has(mask, Inv.R.COUNT) and seasonCount(changes))`.
	it("a Venomstone stack that grows refreshes the footer; other count changes still do not (W4-26)", function()
		A.AddItem(280562, { name = "Ascendant Venomstone", classID = A.ITEM_CLASS.Consumable, subclassID = 8, quality = 4,
			maxStack = 100, bind = "pickup" })
		A.Put(0, 7, 280562, 6)
		SB.Inventory.ScanAll()
		F.Refresh()
		local reads, items = 0, F.Items
		F.Items = function()
			reads = reads + 1
			return items()
		end
		local Inv = SB.Inventory
		Inv.Notify(Inv.R.COUNT, { { bag = 0, slot = 1, reasons = Inv.R.COUNT } })
		A.Advance(0.2)
		assert.equal(0, reads, "a potion used: no refresh")
		Inv.Notify(Inv.R.COUNT, { { bag = 0, slot = 7, reasons = Inv.R.COUNT } })
		A.Advance(0.2)
		assert.equal(1, reads, "a Venomstone looted onto its stack")
	end)

	-- Mutation: in Footer.SeasonText, skip the currencies loop.
	it("SeasonText names the season's currencies (with IDs) and its items' counts, for the report", function()
		A.AddItem(280562, { name = "Ascendant Venomstone", classID = A.ITEM_CLASS.Consumable, subclassID = 8, quality = 4,
			maxStack = 100, bind = "pickup" })
		A.Put(0, 7, 280562, 12)
		SB.Inventory.ScanAll()
		local currencies, items = F.SeasonText()
		assert.equal("Weathered Ethereal Crest (3107) 45, Carved Ethereal Crest (3108) 0", currencies)
		assert.equal("Ascendant Venomstone (280562) 12", items)
		A.currencies = {}
		SB.Crests.items = {}
		assert.same({ "none", "none" }, { F.SeasonText() })
```

In `spec/overlaydata_spec.lua`, find:

```lua
		assert.is_nil(O.For(gear("INVTYPE_HEAD", 280)).track)
```

and replace it with:

```lua
		assert.is_nil(O.For(gear("INVTYPE_HEAD", 280)).track)
	end)

	-- Week 7 (user pick 2, horizon research): an Ascendant Venomstone raises a fully upgraded item's level
	-- past its track. The overlay keeps reading the client's track (never a table of item levels), so a
	-- boosted item reads M6/6 with its new item level, and a level past the maximum still draws.
	it("a Venomstone-boosted item keeps its track text; a level past the maximum draws as it is", function()
		A.tracks["item:225001::boosted"] = { track = "Myth", level = 6, max = 6 }
		A.Put(0, 7, Fixtures.BOE_RING, 1, { link = "item:225001::boosted", ilvl = 344 })
		local d = O.For(SB.Items.Describe(0, 7))
		assert.same({ "M6/6", 344 }, { d.track, d.ilvl })
		A.tracks["item:225001::boosted"] = { track = "Myth", level = 7, max = 6 }
		assert.equal("M7/6", O.For(SB.Items.Describe(0, 7)).track)
```

In `spec/report_spec.lua`, find:

```lua
		assert.falsy(text:find("AdiBags", 1, true))
```

and replace it with:

```lua
		assert.falsy(text:find("AdiBags", 1, true))
	end)

	-- Week 7 (user pick 2). Mutation: delete the Season data line in Report.Build.
	it("names the season's currencies and items (Footer.SeasonText), so their IDs can be confirmed", function()
		SB.Checks.last = {}
		SB.Footer = { SeasonText = function() return "Weathered Ethereal Crest (3107) 45", "Ascendant Venomstone (280562) 12" end }
		assert.truthy(SB.Report.Build():find("\nSeason data: crest currencies Weathered Ethereal Crest (3107) 45; season"
			.. " items in bags Ascendant Venomstone (280562) 12", 1, true))
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1286 passed, 6 failed`. The failures, exactly:

- `spec/categorizer_spec.lua :: Categorizer > Ascendant Venomstones file under Keystone & Crests by item ID`
- `spec/footer_spec.lua :: Footer (ruling W4-14) > crests: the Venomstones in the bags show after the crest currencies, counted over every stack`
- `spec/footer_spec.lua :: Footer (ruling W4-14) > crests: a currency named like the season's (Venomstone) shows when no currency IDs are confirmed`
- `spec/footer_spec.lua :: Footer (ruling W4-14) > a Venomstone stack that grows refreshes the footer; other count changes still do not (W4-26)`
- `spec/footer_spec.lua :: Footer (ruling W4-14) > SeasonText names the season's currencies (with IDs) and its items' counts, for the report`
- `spec/report_spec.lua :: Report > names the season's currencies and items (Footer.SeasonText), so their IDs can be confirmed`

The new overlay test, "a Venomstone-boosted item keeps its track text; a level past the maximum draws as it is", passes already: it pins the week-3 overlay for the boosted items (D7).

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "crests: the Venomstones in the bags show after the crest currencies, counted over every stack": in `SwagBag/UI/Footer.lua`, `for _, it in ipairs(F.SeasonItems()) do` → `for _, it in ipairs({}) do`.
- "crests: a currency named like the season's (Venomstone) shows when no currency IDs are confirmed": in `SwagBag/Engine/Crests.lua`, `currencyWords = { "crest", "valorstone", "venomstone" }` → `currencyWords = { "crest", "valorstone" }`.
- "a Venomstone stack that grows refreshes the footer; other count changes still do not (W4-26)": in `SwagBag/UI/Footer.lua`, `or (Inv.Has(mask, Inv.R.COUNT) and seasonCount(changes))` → `∅`.
- "SeasonText names the season's currencies (with IDs) and its items' counts, for the report": in `SwagBag/UI/Footer.lua`, `for _, c in ipairs(A.CurrencyList()) do ⏎ if crestName(c.name) then ⏎ parts` → `for _, c in ipairs({}) do ⏎ if crestName(c.name) then ⏎ parts`.
- "names the season's currencies and items (Footer.SeasonText), so their IDs can be confirmed": in `SwagBag/Core/Report.lua`, `lines[#lines + 1] = L.REPORT_SEASON:format(SB.Footer.SeasonText())` → `∅`.
- "Ascendant Venomstones file under Keystone & Crests by item ID": in `SwagBag/Engine/Crests.lua`, `ids = { [VENOMSTONE] = true },` → `ids = {},`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Report.lua`, find:

```lua
	end
	if SB.Theme and SB.Config.db then
```

and replace it with:

```lua
	end
	if SB.Footer and SB.Footer.SeasonText then -- week 7: the season's currencies and items, to confirm their IDs
		lines[#lines + 1] = L.REPORT_SEASON:format(SB.Footer.SeasonText())
	end
	if SB.Theme and SB.Config.db then
```

In `SwagBag/Engine/Crests.lua`, find:

```lua
-- SwagBag crest data (spec 7.3 "crest", 13.2 item 4): what files into "Keystone & Crests"
-- besides the keystone. Per season, updated with patches.
--   ids    item IDs of the season's upgrade-currency items, confirmed in game
--   words  lower-case name words for the rest (never matched on gear, so a cloak named
--          "...Crest..." stays in Gear)
-- An item the user drops on the Keystone & Crests header joins it whatever this file says
-- (spec AC4.3); Claude moves confirmed IDs into `ids` when the user reports them.
local _, SB = ...

-- currencies: currency IDs of the season's crests, for the bags footer (UI/Footer.lua). Empty until
-- confirmed in game: the footer then shows every owned currency whose name has one of `words`.
SB.Crests = {
	ids = {},
	words = { "crest", "valorstone" },
	currencies = {},
```

and replace it with:

```lua
-- SwagBag season data (spec 7.3 "crest", 13.2 item 4; week 7, user pick 2): what files into
-- "Keystone & Crests" besides the keystone, and what the footer's crests entry shows. Per season,
-- updated with patches: a new season (12.2) is an edit of this file only.
--   ids            item IDs filed under Keystone & Crests (upgrade-currency items), by ID
--   words          lower-case name words for the rest of those items (never matched on gear, so a
--                  cloak named "...Crest..." stays in Gear)
--   currencyWords  lower-case name words of the season's currencies: while `currencies` is empty the
--                  footer shows every owned currency whose name has one of them
--   currencies     currency IDs of the season's crests, confirmed in game (empty: the words decide)
--   items          bag items the footer shows next to the crests, with how many the bags hold
-- An item the user drops on the Keystone & Crests header joins it whatever this file says (spec
-- AC4.3). /swagbag report's "Season data" line names what the game has, so Claude can move confirmed
-- IDs here when the user pastes it.
local _, SB = ...

-- Ascendant Venomstone (12.1.5, live 2026-10-13): item 280562 on the 12.1.5 PTR (Wowhead and
-- warcraft.wiki.gg: stacks to 100, binds when picked up). Should the live game make it a currency
-- instead, "venomstone" in currencyWords finds it in the Currency tab's list. Confirmed in game with
-- the report's "Season data" line (session SN1).
local VENOMSTONE = 280562

SB.Crests = {
	ids = { [VENOMSTONE] = true },
	words = { "crest", "valorstone" },
	currencyWords = { "crest", "valorstone", "venomstone" },
	currencies = {},
	items = { VENOMSTONE },
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.REPORT_LOOK = "Look: %s (setting %s)"
```

and replace it with:

```lua
L.REPORT_LOOK = "Look: %s (setting %s)"
L.REPORT_SEASON = "Season data: crest currencies %s; season items in bags %s"
L.REPORT_SEASON_ENTRY = "%s (%d) %d"
```

In `SwagBag/UI/Footer.lua` (edit 1 of 7), find:

```lua
--   crests      every crest currency the character owns (none owned: nothing shows)
```

and replace it with:

```lua
--   crests      every crest currency the character owns (none owned: nothing shows), then the season's
--               bag items (Engine/Crests.lua `items`, the Venomstones) with how many the bags hold
```

In `SwagBag/UI/Footer.lua` (edit 2 of 7), find:

```lua
--   Footer.Items() -> { { entry, text, icon, tip } }  what to draw, in order (reads the game)
```

and replace it with:

```lua
--   Footer.Items() -> { { entry, text, icon, tip } }  what to draw, in order (reads the game)
--   Footer.SeasonItems() -> { { id, quantity, icon } }  the season's bag items the bags hold
--   Footer.SeasonText() -> currencies, items   the report's "Season data" line (reads the game)
```

In `SwagBag/UI/Footer.lua` (edit 3 of 7), find:

```lua
	for _, w in ipairs(SB.Crests.words) do
```

and replace it with:

```lua
	for _, w in ipairs(SB.Crests.currencyWords or SB.Crests.words) do
```

In `SwagBag/UI/Footer.lua` (edit 4 of 7), find:

```lua
	end
	return out
end

-- The keystone in the bags, read like its overlay (OverlayData.For): { link, itemID, level, dungeon }.
```

and replace it with:

```lua
	end
	return out
end

-- How many of each item the bags hold (backpack, bags, reagent bag), from the live model.
local function bagCounts()
	local have = {}
	for _, _, snap in SB.Inventory.Iterate("bags") do
		if snap then
			have[snap.itemID] = (have[snap.itemID] or 0) + (snap.count or 1)
		end
	end
	return have
end

-- The season's bag items the character carries (week 7: the Venomstones), in the data file's order.
function F.SeasonItems()
	local A, have, out = SB.Adapter, bagCounts(), {}
	for _, id in ipairs(SB.Crests.items or {}) do
		if (have[id] or 0) > 0 then
			out[#out + 1] = { id = id, quantity = have[id], icon = (A.GetItemInstant(id) or {}).icon }
		end
	end
	return out
end

-- The report's "Season data" line: every currency in the Currency tab's list whose name has a season
-- word ("name (id) quantity"), and every season item with its count in the bags. So the user can
-- confirm the season's IDs in game (Engine/Crests.lua).
function F.SeasonText()
	local A, parts, items = SB.Adapter, {}, {}
	for _, c in ipairs(A.CurrencyList()) do
		if crestName(c.name) then
			parts[#parts + 1] = L.REPORT_SEASON_ENTRY:format(tostring(c.name), c.id, c.quantity)
		end
	end
	local have = bagCounts()
	for _, id in ipairs(SB.Crests.items or {}) do
		local info = A.GetItemInfo(id)
		items[#items + 1] = L.REPORT_SEASON_ENTRY:format(info and info.name or L.ITEM_N:format(id), id, have[id] or 0)
	end
	return #parts > 0 and table.concat(parts, ", ") or L.REPORT_NONE,
		#items > 0 and table.concat(items, ", ") or L.REPORT_NONE
end

-- The keystone in the bags, read like its overlay (OverlayData.For): { link, itemID, level, dungeon }.
```

In `SwagBag/UI/Footer.lua` (edit 5 of 7), find:

```lua
			currencies("crests", F.Crests())
```

and replace it with:

```lua
			currencies("crests", F.Crests())
			for _, it in ipairs(F.SeasonItems()) do
				add("crests", tostring(it.quantity), it.icon, { kind = "item", id = it.id })
			end
```

In `SwagBag/UI/Footer.lua` (edit 6 of 7), find:

```lua
		if not pcall(T.SetCurrencyByID, T, tip.id) then
```

and replace it with:

```lua
		if not pcall(T.SetCurrencyByID, T, tip.id) then
			T:SetText(item.text)
		end
	elseif tip.kind == "item" then
		if not pcall(T.SetItemByID, T, tip.id) then
```

In `SwagBag/UI/Footer.lua` (edit 7 of 7), find:

```lua
-- key) start no refresh (ruling W4-26).
SB.Inventory.OnChanged(function(mask)
	local Inv = SB.Inventory
	if Inv.Has(mask, Inv.R.ITEM) or Inv.Has(mask, Inv.R.SIZE) then
```

and replace it with:

```lua
-- key) start no refresh (ruling W4-26). One exception (week 7): a count change of a season item the
-- footer shows (a Venomstone looted onto its stack).
local function seasonCount(changes)
	local season, Inv = {}, SB.Inventory
	for _, id in ipairs(SB.Crests.items or {}) do
		season[id] = true
	end
	for _, c in ipairs(changes or {}) do
		local snap = Inv.GetSlot(c.bag, c.slot)
		if snap and season[snap.itemID] and Inv.Has(c.reasons, Inv.R.COUNT) then
			return true
		end
	end
	return false
end

SB.Inventory.OnChanged(function(mask, changes)
	local Inv = SB.Inventory
	if Inv.Has(mask, Inv.R.ITEM) or Inv.Has(mask, Inv.R.SIZE) or (Inv.Has(mask, Inv.R.COUNT) and seasonCount(changes)) then
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1292 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (62 files)`, `1292 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Report.lua \
	SwagBag/Engine/Crests.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/Footer.lua \
	spec/categorizer_spec.lua \
	spec/footer_spec.lua \
	spec/overlaydata_spec.lua \
	spec/report_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 2: season data (Venomstones next to the crests, Keystone & Crests by ID), Season data report line

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 3: The green glow on items to open or learn (Engine/Collections.lua)

User pick 3. The Adapter learns to ask the client's collections (`ToyKnown`, `MountKnown`, `PetKnown`, `DecorKnown`; true, false, or nil when it cannot say or the answer is secret) and passes on `hasLoot` from the slot. `Engine/Collections.lua` turns them into `Learn(record)`: `"open"` for a container with loot, `"learn"` for a toy, mount, pet or decor item not collected yet or a profession knowledge item (`SB.Crests.knowledge`), else nil (D8). Answers are cached per item and dropped when something is learned (`NEW_TOY_ADDED`, `NEW_MOUNT_ADDED`, `NEW_PET_ADDED`, then one re-draw) or an item leaves the bags. `UI/Overlays.lua` draws one whole-button glow region, tinted green; its switch is `overlays.learn` (on), on the Overlays page and in `/swagbag overlays`.

**Files:**
- Create: `SwagBag/Engine/Collections.lua` (TOC, after `Engine/OverlayData.lua`: 63 files)
- Modify: `SwagBag/Core/Adapter.lua` (`hasLoot` in `GetSlot`; `ToyKnown`, `MountKnown`, `PetKnown`, `DecorKnown`; six optional checks), `.luacheckrc` (`C_MountJournal`, `C_PetJournal`, `C_HousingCatalog`), `SwagBag/Engine/Items.lua` (`hasLoot`), `SwagBag/Engine/Crests.lua` (`knowledge`), `SwagBag/Engine/OverlayData.lua` (`learn`), `SwagBag/UI/Overlays.lua` (the glow), `SwagBag/UI/SettingsPages.lua` (the row), `SwagBag/Core/Config.lua` (`overlays.learn`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/collections_spec.lua` (new), `spec/adapter_spec.lua`, `spec/overlays_spec.lua`, `spec/mock_adapter.lua` (`hasLoot`, `m.collected`, the four Known fakes)

**Interfaces:**
- Consumes: `SB.Inventory.OnChanged`, `SB.Debounce`, `Overlays.RefreshAll`, record fields `isToy`, `isCagedPet`, `classID`, `subclassID`, `name`, `link`, `offline`.
- Produces: `A.ToyKnown/MountKnown/PetKnown(itemID, link)/DecorKnown -> true | false | nil`; `record.hasLoot`; `SB.Collections.Learn(record) -> "open" | "learn" | nil`, `Collections.Invalidate()`, `Collections.REFRESH`; `OverlayData.For(...).learn` with `ctx.learn`; the overlay region `glow`, `Ov.GLOW_ATLAS`, `Ov.LEARN_TINT`; `Ov.NAMES` gains `"learn"` (Task 5 adds `"lock"`, Task 8 `"uncollected"`). The mock's `m.collected = { toys, mounts, pets, decor }` and `m.collectionCalls`.

- [ ] **Step 1: Write the failing tests**

In `spec/adapter_spec.lua` (edit 1 of 2), find:

```lua
-- luacheck: globals Auctionator ColorManager ITEM_QUALITY_COLORS
```

and replace it with:

```lua
-- luacheck: globals Auctionator ColorManager ITEM_QUALITY_COLORS
-- luacheck: globals PlayerHasToy C_MountJournal C_PetJournal C_HousingCatalog
```

In `spec/adapter_spec.lua` (edit 2 of 2), find:

```lua
		assert.equal(false, A.IsInGuild())
	end)
end)
```

and replace it with:

```lua
		assert.equal(false, A.IsInGuild())
	end)
end)

-- Week 7 (user picks 3 and 9): the collection answers the "learn" glow and the uncollected marker use.
describe("Adapter collections (week 7)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		PlayerHasToy, C_MountJournal, C_PetJournal, C_HousingCatalog, issecretvalue = nil, nil, nil, nil, nil
	end)

	-- Mutation: in A.ToyKnown, return `ok and v` (a secret or a non-boolean passes through).
	it("toys and mounts: true, false, or nil without the API, for a non-mount item, or a secret", function()
		assert.is_nil(A.ToyKnown(1))
		PlayerHasToy = function(id) return id == 1 end
		assert.same({ true, false }, { A.ToyKnown(1), A.ToyKnown(2) })
		issecretvalue = function(v) return v == true end
		assert.is_nil(A.ToyKnown(1), "a secret answer is no answer")
		issecretvalue = nil
		assert.is_nil(A.MountKnown(5))
		C_MountJournal = { GetMountFromItem = function(id) return id == 5 and 77 or nil end,
			GetMountInfoByID = function() return "Horse", 1, 2, false, true, 0, false, false, 0, false, false end }
		assert.equal(false, A.MountKnown(5))
		assert.is_nil(A.MountKnown(6), "not a mount item")
	end)

	-- Mutation: in A.PetKnown, ignore the link (always ask GetPetInfoByItemID).
	it("pets: a caged pet's species comes from its link, a pet item's from the journal; decor from the catalog", function()
		local asked = {}
		C_PetJournal = { GetNumCollectedInfo = function(species)
			asked[#asked + 1] = species
			return species == 1387 and 1 or 0
		end, GetPetInfoByItemID = function() return "Pup", 1, 1, 1, "", "", false, true, true, false, true, 1, 42 end }
		assert.equal(true, A.PetKnown(82800, "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r"))
		assert.equal(false, A.PetKnown(12345, "item:12345"))
		assert.same({ 1387, 42 }, asked)
		assert.is_nil(A.DecorKnown(9))
		C_HousingCatalog = { GetCatalogEntryInfoByItem = function(id)
			if id == 9 then
				return { totalNumPlaced = 0, remainingRedeemable = 0, totalNumStored = 2 }
			elseif id == 10 then
				return { totalNumPlaced = 0, remainingRedeemable = 0, totalNumStored = 0 }
			end
			return id == 11 and {} or nil
		end }
		assert.same({ true, false }, { A.DecorKnown(9), A.DecorKnown(10) })
		assert.is_nil(A.DecorKnown(11), "no counts: the client cannot say")
		assert.is_nil(A.DecorKnown(12), "not decor")
	end)
end)
```

Create `spec/collections_spec.lua`:

```lua
-- Week 7 (user pick 3): which bag items to open or learn (Engine/Collections.lua). Real APIs only,
-- through the Adapter; cached per item, asked again only after something is learned or an item leaves.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Crests.lua",
	"SwagBag/Engine/Collections.lua",
}

describe("Collections (week 7)", function()
	local SB, A, Coll
	before_each(function()
		SB = Loader.New(FILES)
		A, Coll = SB.Adapter, SB.Collections
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		local C, MS = A.ITEM_CLASS, A.MISC_SUB
		A.AddItem(500001, { name = "Cache of Riches", classID = C.Miscellaneous, subclassID = 0, quality = 3, bind = "pickup" })
		A.AddItem(500002, { name = "Reins of the Test Drake", classID = C.Miscellaneous, subclassID = MS.Mount, quality = 4,
			bind = "pickup" })
		A.AddItem(500003, { name = "Lost Kitten", classID = C.Miscellaneous, subclassID = MS.CompanionPet, quality = 3,
			bind = "none" })
		A.AddItem(500004, { name = "Silvermoon Lamp", classID = C.Housing, subclassID = 0, quality = 2, bind = "none" })
		A.AddItem(500005, { name = "Thalassian Treatise on Alchemy", classID = C.Consumable, subclassID = 8, quality = 3,
			bind = "pickup" })
		A.Put(0, 7, 500001, 1, { hasLoot = true })
		A.Put(0, 8, 500002, 1)
		A.Put(0, 9, 500003, 1)
		A.Put(0, 10, 500004, 1)
		A.Put(0, 11, 500005, 1)
		A.Put(0, 12, Fixtures.TOY, 1)
		A.Put(0, 13, Fixtures.PET_CAGE, 1, { link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r" })
	end)

	local function learn(slot)
		return Coll.Learn(SB.Items.Describe(0, slot))
	end

	-- Mutations: in Collections.Learn, the mount answer's `== false` -> `~= true` (a silent client would
	-- make it glow); or drop the `if r.hasLoot` branch.
	it("open: a container with loot; learn: a toy, mount, pet or decor not collected yet; else nothing", function()
		A.collected.toys[Fixtures.TOY] = false
		A.collected.mounts[500002] = false
		A.collected.pets[500003] = false
		A.collected.decor[500004] = false
		A.collected.pets[1387] = true -- the caged pet's species is already collected
		assert.same({ "open", "learn", "learn", "learn", "learn", "learn" },
			{ learn(7), learn(8), learn(9), learn(10), learn(11), learn(12) })
		assert.is_nil(learn(13), "a caged pet whose species is collected")
		assert.is_nil(learn(1), "a potion")
		assert.is_nil(learn(4), "gear")
		Coll.Invalidate()
		A.collected.toys[Fixtures.TOY] = true
		A.collected.mounts[500002] = nil -- the client gives no answer: no glow, never a wrong one
		assert.same({ nil, nil }, { learn(12), learn(8) })
	end)

	-- Mutation: in knowledge(), drop the isGear check (a cloak named "Treatise..." would glow).
	it("knowledge items: by confirmed ID or the name word, never gear; an alt's saved item never glows", function()
		A.AddItem(500006, { name = "Treatise Cloak", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CLOAK",
			quality = 3, ilvl = 280, bind = "equip" })
		A.Put(0, 14, 500006, 1)
		assert.is_nil(learn(14))
		SB.Crests.knowledge.ids[Fixtures.QUEST] = true
		A.Put(0, 15, Fixtures.QUEST, 1)
		assert.equal("learn", learn(15))
		local saved = SB.Items.Describe(0, 11)
		saved.offline = true
		assert.is_nil(Coll.Learn(saved))
	end)

	-- Mutations: drop the Inventory listener's Invalidate; or register no NEW_TOY_ADDED handler.
	it("answers are cached per item; a toy learned or an item leaving asks again, and the windows re-draw", function()
		A.collected.toys[Fixtures.TOY] = false
		learn(12)
		learn(12)
		assert.equal(1, A.collectionCalls, "the second draw is a table lookup")
		A.collected.toys[Fixtures.TOY] = true
		local drawn = 0
		SB.Overlays = { RefreshAll = function() drawn = drawn + 1 end }
		SB.eventFrame:Fire("NEW_TOY_ADDED", Fixtures.TOY)
		A.Advance(Coll.REFRESH)
		assert.is_nil(learn(12), "learned: no glow on another copy")
		assert.same({ 2, 1 }, { A.collectionCalls, drawn })
		SB.Inventory.Notify(SB.Inventory.R.ITEM, { { bag = 0, slot = 12, reasons = SB.Inventory.R.ITEM } })
		learn(12)
		assert.equal(3, A.collectionCalls)
	end)
end)
```

In `spec/mock_adapter.lua` (edit 1 of 2), find:

```lua
			hasNoValue = s.hasNoValue == true,
```

and replace it with:

```lua
			hasNoValue = s.hasNoValue == true,
			hasLoot = s.hasLoot == true,
```

In `spec/mock_adapter.lua` (edit 2 of 2), find:

```lua
	end

	function m.IsQuestItem(bag, slot)
```

and replace it with:

```lua
	end

	-- Collections (week 7): m.collected.toys / .mounts / .decor [itemID] and .pets [species or itemID] =
	-- true (collected) | false (not yet); no entry = the client gives no answer. m.collectionCalls counts asks.
	m.collected, m.collectionCalls = { toys = {}, mounts = {}, pets = {}, decor = {} }, 0
	function m.ToyKnown(itemID)
		m.collectionCalls = m.collectionCalls + 1
		return m.collected.toys[itemID]
	end

	function m.MountKnown(itemID)
		m.collectionCalls = m.collectionCalls + 1
		return m.collected.mounts[itemID]
	end

	function m.PetKnown(itemID, link)
		m.collectionCalls = m.collectionCalls + 1
		local species = type(link) == "string" and tonumber(link:match("battlepet:(%d+)"))
		return m.collected.pets[species or itemID]
	end

	function m.DecorKnown(itemID)
		m.collectionCalls = m.collectionCalls + 1
		return m.collected.decor[itemID]
	end

	function m.IsQuestItem(bag, slot)
```

In `spec/overlays_spec.lua`, find:

```lua
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, pawn off, title on",
			SB.L.OVERLAYS_USAGE }, A.Lines())
		assert.equal(false, SB.Config.Get("overlays.bind"))
```

and replace it with:

```lua
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, learn on, pawn off, title on",
			SB.L.OVERLAYS_USAGE }, A.Lines())
		assert.equal(false, SB.Config.Get("overlays.bind"))
	end)

	-- Week 7 (user pick 3). Mutations: in Overlays.Apply, `local glow = on("learn") and d.learn ~= nil` ->
	-- `d.learn ~= nil` (the switch is ignored); or drop `learn = SB.Collections and ...` from the context.
	it("a green glow on an item to open or learn; overlays learn off hides it; an empty slot never glows", function()
		SB.Collections = { Learn = function(r)
			return r.slot == 1 and "open" or nil
		end }
		local _, r = draw(0, 1)
		assert.truthy(r.glow.shown)
		assert.same({ 0.35, 1, 0.35 }, r.glow.calls.SetVertexColor)
		local _, plain = draw(0, 2)
		assert.falsy(plain.glow.shown, "a flask: nothing to open or learn")
		SB.Slash.Dispatch("overlays learn off")
		local _, off = draw(0, 1)
		assert.falsy(off.glow.shown)
		local b = Fake.New("ItemButton")
		SB.Slash.Dispatch("overlays learn on")
		Ov.Apply(b, SB.Items.Describe(0, 1), 0)
		Ov.Apply(b, nil, 0)
		assert.falsy(Ov.regions[b].glow.shown, "the slot emptied: no glow")
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1291 passed, 7 failed`. The failures, exactly:

- `spec/adapter_spec.lua :: Adapter collections (week 7) > toys and mounts: true, false, or nil without the API, for a non-mount item, or a secret`
- `spec/adapter_spec.lua :: Adapter collections (week 7) > pets: a caged pet's species comes from its link, a pet item's from the journal; decor from the catalog`
- `spec/collections_spec.lua :: Collections (week 7) > open: a container with loot; learn: a toy, mount, pet or decor not collected yet; else nothing`
- `spec/collections_spec.lua :: Collections (week 7) > knowledge items: by confirmed ID or the name word, never gear; an alt's saved item never glows`
- `spec/collections_spec.lua :: Collections (week 7) > answers are cached per item; a toy learned or an item leaving asks again, and the windows re-draw`
- `spec/overlays_spec.lua :: Overlays (spec F9) > each overlay has its own switch; /swagbag overlays lists and switches them`
- `spec/overlays_spec.lua :: Overlays (spec F9) > a green glow on an item to open or learn; overlays learn off hides it; an empty slot never glows`

`Overlays > each overlay has its own switch` fails only because its list now names `learn`.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "open: a container with loot; learn: a toy, mount, pet or decor not collected yet; else nothing": in `SwagBag/Engine/Collections.lua`, `return A.MountKnown(id) ⏎ end) == false` → `return A.MountKnown(id) ⏎ end) ~= true`.
- "open: a container with loot; learn: a toy, mount, pet or decor not collected yet; else nothing": in `SwagBag/Engine/Collections.lua`, `if r.hasLoot then ⏎ return "open" ⏎ end` → `∅`.
- "knowledge items: by confirmed ID or the name word, never gear; an alt's saved item never glows": in `SwagBag/Engine/Collections.lua`, `if r.name == nil or isGear(r) then` → `if r.name == nil then`.
- "answers are cached per item; a toy learned or an item leaving asks again, and the windows re-draw": in `SwagBag/Engine/Collections.lua`, `if SB.Inventory.Has(mask, SB.Inventory.R.ITEM) then ⏎ Coll.Invalidate()` → `if false then ⏎ Coll.Invalidate()`.
- "answers are cached per item; a toy learned or an item leaving asks again, and the windows re-draw": in `SwagBag/Engine/Collections.lua`, `for _, event in ipairs({ "NEW_TOY_ADDED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED" }) do` → `for _, event in ipairs({ "NEW_MOUNT_ADDED", "NEW_PET_ADDED" }) do`.
- "a green glow on an item to open or learn; overlays learn off hides it; an empty slot never glows": in `SwagBag/UI/Overlays.lua`, `local glow = on("learn") and d.learn ~= nil` → `local glow = d.learn ~= nil`.
- "a green glow on an item to open or learn; overlays learn off hides it; an empty slot never glows": in `SwagBag/UI/Overlays.lua`, `learn = SB.Collections and SB.Collections.Learn }` → `learn = nil }`.
- "toys and mounts: true, false, or nil without the API, for a non-mount item, or a secret": in `SwagBag/Core/Adapter.lua`, `return known(pcall(fn, itemID))` → `local ok, v = pcall(fn, itemID) ⏎ return ok and v`.
- "pets: a caged pet's species comes from its link, a pet item's from the journal; decor from the catalog": in `SwagBag/Core/Adapter.lua`, `local species = type(link) == "string" and not isSecret(link) and tonumber(link:match("battlepet:(%d+)")) or nil` → `local species = nil`.

- [ ] **Step 3: Write the code**

In `.luacheckrc`, find:

```lua
	"C_RestrictedActions", "C_PartyInfo", "C_Spell", "C_NewItems", "C_CurrencyInfo",
```

and replace it with:

```lua
	"C_RestrictedActions", "C_PartyInfo", "C_Spell", "C_NewItems", "C_CurrencyInfo",
	"C_MountJournal", "C_PetJournal", "C_HousingCatalog",
```

In `SwagBag/Core/Adapter.lua` (edit 1 of 3), find:

```lua
		hasNoValue = info.hasNoValue == true,
```

and replace it with:

```lua
		hasNoValue = info.hasNoValue == true,
		hasLoot = info.hasLoot == true, -- a container to open (a cache, a lockbox): week 7, the "learn" glow
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 3), find:

```lua
	return ok and toyID ~= nil
```

and replace it with:

```lua
	return ok and toyID ~= nil
end

---------------------------------------------------------------------------
-- Collections (week 7, user picks 3 and 9): is this toy, mount, pet or decor item already the
-- account's? true = collected, false = not yet, nil = the client cannot say or the item is not that
-- kind (then no glow and no marker: never a wrong one). A secret answer is nil. Real APIs only (P7).
---------------------------------------------------------------------------
local function known(ok, v)
	if not ok or isSecret(v) or type(v) ~= "boolean" then
		return nil
	end
	return v
end

function A.ToyKnown(itemID)
	local fn = _G.PlayerHasToy
	if type(fn) ~= "function" then
		return nil
	end
	return known(pcall(fn, itemID))
end

function A.MountKnown(itemID)
	local J = C_MountJournal
	if not (J and J.GetMountFromItem and J.GetMountInfoByID) then
		return nil
	end
	local ok, mountID = pcall(J.GetMountFromItem, itemID)
	if not ok or type(mountID) ~= "number" or isSecret(mountID) then
		return nil -- not a mount item
	end
	return known(pcall(function()
		return (select(11, J.GetMountInfoByID(mountID))) -- isCollected
	end))
end

-- A caged pet's species is in its link (battlepet:<species>); a pet item asks the journal for it.
function A.PetKnown(itemID, link)
	local J = C_PetJournal
	if not (J and J.GetNumCollectedInfo) then
		return nil
	end
	local species = type(link) == "string" and not isSecret(link) and tonumber(link:match("battlepet:(%d+)")) or nil
	if not species and J.GetPetInfoByItemID then
		local ok, s = pcall(function()
			return (select(13, J.GetPetInfoByItemID(itemID))) -- speciesID
		end)
		species = ok and type(s) == "number" and not isSecret(s) and s or nil
	end
	if not species then
		return nil
	end
	local ok, n = pcall(J.GetNumCollectedInfo, species)
	if not ok or type(n) ~= "number" or isSecret(n) then
		return nil
	end
	return n > 0
end

-- Decor counts as collected once the account has one placed, in storage, or still to redeem.
function A.DecorKnown(itemID)
	local H = C_HousingCatalog
	if not (H and H.GetCatalogEntryInfoByItem) then
		return nil
	end
	local ok, info = pcall(H.GetCatalogEntryInfoByItem, itemID)
	if not ok or type(info) ~= "table" then
		return nil
	end
	local owned, seen = 0, false
	for _, field in ipairs({ "totalNumPlaced", "remainingRedeemable", "totalNumStored" }) do
		local v = info[field]
		if type(v) == "number" and not isSecret(v) then
			owned, seen = owned + v, true
		end
	end
	if not seen then
		return nil
	end
	return owned > 0
```

In `SwagBag/Core/Adapter.lua` (edit 3 of 3), find:

```lua
	{ path = "C_ToyBox.GetToyInfo", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "C_ToyBox.GetToyInfo", window = "bags", required = false },
	{ path = "PlayerHasToy", window = "bags", required = false },
	{ path = "C_MountJournal.GetMountFromItem", window = "bags", required = false },
	{ path = "C_MountJournal.GetMountInfoByID", window = "bags", required = false },
	{ path = "C_PetJournal.GetPetInfoByItemID", window = "bags", required = false },
	{ path = "C_PetJournal.GetNumCollectedInfo", window = "bags", required = false },
	{ path = "C_HousingCatalog.GetCatalogEntryInfoByItem", window = "bags", required = false },
```

In `SwagBag/Core/Config.lua`, find:

```lua
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = false,
			usePawn = false },
```

and replace it with:

```lua
		-- learn (week 7): a green glow on items to open or learn (caches, toys, mounts, pets, decor, knowledge).
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = false,
			learn = true, usePawn = false },
```

Create `SwagBag/Engine/Collections.lua`:

```lua
-- SwagBag collections (week 7, user picks 3 and 9): what an item in the bags is to the collection.
--   Collections.Learn(record) -> "open" | "learn" | nil
--     open    a container the client says holds loot (record.hasLoot: caches, bags of goods, lockboxes)
--     learn   a toy, mount, pet or decor item the account has not collected yet, or a profession
--             knowledge item (Engine/Crests.lua `knowledge`)
--   Collections.Invalidate()   drop the cached answers (something was learned, or an item left the bags)
-- Every answer comes from the client's collection APIs through the Adapter (spec P7: no tooltip
-- reading); one the client cannot give (nil, or secret) means "nothing to do", so an item never glows
-- by mistake. Answers are cached per item (a caged pet: per species) until something is learned or an
-- item leaves the bags, so drawing costs a table lookup. Nothing runs per frame and nothing polls.
local _, SB = ...

local Coll = { cache = {}, REFRESH = 0.2 }
SB.Collections = Coll

local UNKNOWN = "?" -- a cached "the client cannot say"

function Coll.Invalidate()
	Coll.cache = {}
end

-- A cached true / false / nil from ask().
local function cached(key, ask)
	local v = Coll.cache[key]
	if v == nil then
		v = ask()
		if v == nil then
			v = UNKNOWN
		end
		Coll.cache[key] = v
	end
	if v == UNKNOWN then
		return nil
	end
	return v
end

local function isGear(r)
	local C = SB.Adapter.ITEM_CLASS
	return r.classID == C.Armor or r.classID == C.Weapon
end

local function knowledge(r)
	local K = SB.Crests and SB.Crests.knowledge
	if not K then
		return false
	end
	if K.ids[r.itemID] then
		return true
	end
	if r.name == nil or isGear(r) then
		return false
	end
	local name = r.name:lower()
	for _, word in ipairs(K.words) do
		if name:find(word, 1, true) then
			return true
		end
	end
	return false
end

function Coll.Learn(r)
	if not r or r.offline then
		return nil -- an alt's saved item: not this character's to click
	end
	if r.hasLoot then
		return "open"
	end
	local A = SB.Adapter
	local C, MS = A.ITEM_CLASS, A.MISC_SUB
	local id, missing = r.itemID, nil
	if r.isToy then
		missing = cached("toy:" .. id, function()
			return A.ToyKnown(id)
		end) == false
	elseif r.classID == C.Miscellaneous and r.subclassID == MS.Mount then
		missing = cached("mount:" .. id, function()
			return A.MountKnown(id)
		end) == false
	elseif r.isCagedPet or r.classID == C.Battlepet or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet) then
		local species = type(r.link) == "string" and r.link:match("battlepet:(%d+)")
		missing = cached("pet:" .. (species and ("s" .. species) or id), function()
			return A.PetKnown(id, r.link)
		end) == false
	elseif r.classID == C.Housing then
		missing = cached("decor:" .. id, function()
			return A.DecorKnown(id)
		end) == false
	end
	if missing or knowledge(r) then
		return "learn"
	end
	return nil
end

-- Something was learned: drop the answers and re-draw the open windows once, after the burst. An item
-- that left the bags (learned items are used up) only drops the answers: the next draw asks again.
local function learned()
	Coll.Invalidate()
	SB.Debounce("collections.refresh", Coll.REFRESH, function()
		if SB.Overlays then
			SB.Overlays.RefreshAll()
		end
	end, "none")
end

for _, event in ipairs({ "NEW_TOY_ADDED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED" }) do
	SB.On(event, learned, "none")
end

SB.Inventory.OnChanged(function(mask)
	if SB.Inventory.Has(mask, SB.Inventory.R.ITEM) then
		Coll.Invalidate()
	end
end)
```

In `SwagBag/Engine/Crests.lua` (edit 1 of 2), find:

```lua
--   items          bag items the footer shows next to the crests, with how many the bags hold
```

and replace it with:

```lua
--   items          bag items the footer shows next to the crests, with how many the bags hold
--   knowledge      profession knowledge items, for the "learn" glow (Engine/Collections.lua): `ids`
--                  confirmed in game, else a lower-case name word (never matched on gear)
```

In `SwagBag/Engine/Crests.lua` (edit 2 of 2), find:

```lua
	items = { VENOMSTONE },
```

and replace it with:

```lua
	items = { VENOMSTONE },
	-- Week 7 (user pick 3): Midnight's knowledge books are expected to be named "... Treatise ..." as in the
	-- last two expansions; other knowledge items are added by ID once seen in game (session LN1).
	knowledge = { ids = {}, words = { "treatise" } },
```

In `SwagBag/Engine/Items.lua` (edit 1 of 3), find:

```lua
--   hasNoValue      boolean: a vendor pays nothing for it
```

and replace it with:

```lua
--   hasNoValue      boolean: a vendor pays nothing for it
--   hasLoot         boolean: a container to open (a cache, a lockbox; week 7)
```

In `SwagBag/Engine/Items.lua` (edit 2 of 3), find:

```lua
		hasNoValue = s.hasNoValue == true,
```

and replace it with:

```lua
		hasNoValue = s.hasNoValue == true,
		hasLoot = s.hasLoot == true,
```

In `SwagBag/Engine/Items.lua` (edit 3 of 3), find:

```lua
		hasNoValue = false,
```

and replace it with:

```lua
		hasNoValue = false,
		hasLoot = false,
```

In `SwagBag/Engine/OverlayData.lua` (edit 1 of 2), find:

```lua
--     upgrade   boolean         the arrow (AC9.3, see IsUpgrade) }
--   ctx = { equipped = { [invSlot] = { ilvl, equipLoc } }, canUse = fn(itemID) -> bool,
--           dungeonName = fn(mapID) -> name | nil, pawn = fn(record) -> true | false | nil }
```

and replace it with:

```lua
--     upgrade   boolean         the arrow (AC9.3, see IsUpgrade)
--     learn     "open" | "learn" | nil   an item to click: open it, or learn it (ctx.learn, week 7) }
--   ctx = { equipped = { [invSlot] = { ilvl, equipLoc } }, canUse = fn(itemID) -> bool,
--           dungeonName = fn(mapID) -> name | nil, pawn = fn(record) -> true | false | nil,
--           learn = fn(record) -> "open" | "learn" | nil (Engine/Collections.lua) }
```

In `SwagBag/Engine/OverlayData.lua` (edit 2 of 2), find:

```lua
	end
	-- Pawn replaces only the item-level rule: eligibility (loading, unusable, not worn gear) comes first.
```

and replace it with:

```lua
	end
	if ctx.learn then
		out.learn = ctx.learn(record)
	end
	-- Pawn replaces only the item-level rule: eligibility (loading, unusable, not worn gear) comes first.
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 3), find:

```lua
L.HELP_OVERLAYS = "overlays [name on|off]: list or switch item overlays (ilvl, track, upgrade, keystone, junk, bind, pawn)"
```

and replace it with:

```lua
L.HELP_OVERLAYS = "overlays [name on|off]: list or switch item overlays (ilvl, track, upgrade, keystone, junk, bind, learn,"
	.. " pawn)"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 3), find:

```lua
L.OVERLAYS_USAGE = "Use /swagbag overlays, or /swagbag overlays <ilvl|track|upgrade|keystone|junk|bind|pawn|title> <on|off>."
```

and replace it with:

```lua
L.OVERLAYS_USAGE = "Use /swagbag overlays, or /swagbag overlays <ilvl|track|upgrade|keystone|junk|bind|learn|pawn|title>"
	.. " <on|off>."
```

In `SwagBag/Locale/enUS.lua` (edit 3 of 3), find:

```lua
L.SET_OV_BIND = "BoE and WuE badge"
```

and replace it with:

```lua
L.SET_OV_BIND = "BoE and WuE badge"
L.SET_OV_LEARN = "Green glow on items to open or learn (caches, new toys, mounts, pets, decor, knowledge)"
```

In `SwagBag/SwagBag.toc`, find:

```text
Engine/OverlayData.lua
```

and replace it with:

```text
Engine/OverlayData.lua
Engine/Collections.lua
```

In `SwagBag/UI/Overlays.lua` (edit 1 of 6), find:

```lua
--                 (bottom left on gray gear, under its item level)
```

and replace it with:

```lua
--                 (bottom left on gray gear, under its item level)
--   whole button  a soft green glow on an item to open or learn  (overlays.learn, week 7)
```

In `SwagBag/UI/Overlays.lua` (edit 2 of 6), find:

```lua
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind" },
```

and replace it with:

```lua
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind", "learn" },
```

In `SwagBag/UI/Overlays.lua` (edit 3 of 6), find:

```lua
	ARROW_SIZE = 16, JUNK_SIZE = 16, JUNK_OUTLINE = 3, JUNK_TINT = { 1, 0.9, 0.35 } }
```

and replace it with:

```lua
	ARROW_SIZE = 16, JUNK_SIZE = 16, JUNK_OUTLINE = 3, JUNK_TINT = { 1, 0.9, 0.35 },
	-- Week 7: the whole-button glow, Blizzard's white bag glow tinted (green: open or learn).
	GLOW_ATLAS = "bags-glow-white", LEARN_TINT = { 0.35, 1, 0.35 } }
```

In `SwagBag/UI/Overlays.lua` (edit 4 of 6), find:

```lua
		}
```

and replace it with:

```lua
			glow = texture(button, 5, Ov.GLOW_ATLAS, 1, 1, 1, 0.25),
		}
		r.glow:SetAllPoints(button)
```

In `SwagBag/UI/Overlays.lua` (edit 5 of 6), find:

```lua
		local ctx = { equipped = A.EquippedItems(), canUse = A.CanUse, dungeonName = A.DungeonName }
```

and replace it with:

```lua
		local ctx = { equipped = A.EquippedItems(), canUse = A.CanUse, dungeonName = A.DungeonName,
			learn = SB.Collections and SB.Collections.Learn }
```

In `SwagBag/UI/Overlays.lua` (edit 6 of 6), find:

```lua
	show(r.reagent, reagentEmpty)
```

and replace it with:

```lua
	show(r.reagent, reagentEmpty)
	-- One glow per button (week 7): green for an item to open or learn.
	local glow = on("learn") and d.learn ~= nil
	if glow then
		r.glow:SetVertexColor(unpack(Ov.LEARN_TINT))
	end
	show(r.glow, glow)
```

In `SwagBag/UI/SettingsPages.lua`, find:

```lua
	{ "junk", "overlays.junk", L.SET_OV_JUNK }, { "bind", "overlays.bind", L.SET_OV_BIND },
```

and replace it with:

```lua
	{ "junk", "overlays.junk", L.SET_OV_JUNK }, { "bind", "overlays.bind", L.SET_OV_BIND },
	{ "learn", "overlays.learn", L.SET_OV_LEARN },
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1298 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (63 files)`, `1298 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add .luacheckrc \
	SwagBag/Core/Adapter.lua \
	SwagBag/Core/Config.lua \
	SwagBag/Engine/Collections.lua \
	SwagBag/Engine/Crests.lua \
	SwagBag/Engine/Items.lua \
	SwagBag/Engine/OverlayData.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/Overlays.lua \
	SwagBag/UI/SettingsPages.lua \
	spec/adapter_spec.lua \
	spec/collections_spec.lua \
	spec/mock_adapter.lua \
	spec/overlays_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 3: green glow on items to open or learn (caches, toys, mounts, pets, decor, knowledge)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 4: The mover, auto-sell junk and auto-repair (Engine/Mover.lua, Engine/Vendor.lua, Settings > Vendor)

User pick 4. `Engine/Mover.lua` is the one way SwagBag moves items (Global Constraints, "Moving items"): one at a time, `DELAY` (0.2 s) apart, out of combat, never while an item is on the cursor (it waits for as long as the vendor or bank stays open) or while the item's button is under the mouse (it waits up to `MAX_WAITS` retries, then leaves that item), only while the vendor or bank is open; after each move it checks the item really left (a locked, unanswered item is waited for; one that stays means the target refused it, and the run stops). `Engine/Vendor.lua` sells junk on `MERCHANT_SHOW` (D10–D13): gray, valued, loaded, not held by the client, not protected (in a set; Task 5 adds locks), at most 12 per run; then repairs (`own` by default, `guild` first, or `off`). A vendor opened in combat waits for combat's end. One line answers each run. `/swagbag sell [on|off|junk]` and `/swagbag repair [own|guild|off]`; Settings > Vendor (a new page, `UI/SettingsVendor.lua`).

**Files:**
- Create: `SwagBag/Engine/Mover.lua`, `SwagBag/Engine/Vendor.lua` (TOC, after `Engine/Consumables.lua`), `SwagBag/UI/SettingsVendor.lua` (TOC, after `UI/SettingsConsumables.lua`): 66 files
- Modify: `SwagBag/Core/Adapter.lua` (`SellItem`, `MoveToBank`, `RepairCost`, `Repair`, `GuildRepairMoney`; six optional checks), `SwagBag/Core/Config.lua` (`vendor.autoSell`, `vendor.repair`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/mover_spec.lua` (new), `spec/vendor_spec.lua` (new), `spec/mock_adapter.lua` (`m.used`, `m.onUse`, `m.useFails`, `SellItem`, `MoveToBank`, `m.repairCost`, `m.guildRepair`, `m.repairs`)

**Interfaces:**
- Consumes: `W.ButtonBusy(bag, slot)` and `W.IsOpen` (P5, through `SB.BagsWindow` when it exists), `Adapter.CursorItem/GetSlot/InCombat/After/Money/GetItemInfo`, `SB.OutOfCombat`, `SB.Inventory.Iterate`, `SB.Items.Describe`, `SB.SettingsWindow.RunCommand`.
- Produces (Tasks 5 and 6 rely on these):
  - `SB.Mover.Start(job) -> true | false, "busy" | "combat" | "empty"` with `job = { items = { { bag, slot, itemID, link, count, price? } }, act = fn(bag, slot) -> ok, err, still = fn() -> bool, done = fn(result) }` and `result = { moved = { item }, left, skipped, kept, why = nil | "combat" | "closed" | "stuck" | "error" }`; `Mover.Busy()`, `Mover.IsBusy(bag, slot)`, `Mover.Stop(why)`, `Mover.DELAY`, `Mover.RETRY`, `Mover.MAX_WAITS`;
  - `SB.Vendor.open`, `Vendor.Protected(record)`, `Vendor.Junk()`, `Vendor.Sell(list, kind, after) -> ok, why` (kind `"junk"` | `"section"`), `Vendor.Repair()`, `Vendor.Money(copper)`, `Vendor.BUYBACK` (12);
  - `A.SellItem(bag, slot)`, `A.MoveToBank(bag, slot, kind)` (Task 6), `A.RepairCost()`, `A.Repair(guild)`, `A.GuildRepairMoney()`;
  - `L.MOVER_BUSY`, `L.VENDOR_*` (Task 6 reuses `VENDOR_NOT_OPEN`, `VENDOR_STOP_COMBAT`, `VENDOR_KEPT_MOUSE`, `VENDOR_MORE`), `L.SET_PAGE_VENDOR`.

- [ ] **Step 1: Write the failing tests**

In `spec/mock_adapter.lua`, find:

```lua
	end

	function m.IsQuestItem(bag, slot)
```

and replace it with:

```lua
	end

	-- Selling and moving (week 7): every call is recorded in m.used = { { bag, slot, kind } } (kind "sell",
	-- "bank" or "warband"). m.onUse(bag, slot, kind) decides what happens; by default the slot empties at
	-- once (the item was sold or moved). m.useFails = true: the call throws (the client refused it).
	m.used = {}
	m.onUse = function(bag, slot)
		m.Clear(bag, slot)
	end
	local function use(bag, slot, kind)
		m.used[#m.used + 1] = { bag = bag, slot = slot, kind = kind }
		if m.useFails then
			return false, "refused"
		end
		m.onUse(bag, slot, kind)
		return true
	end

	function m.SellItem(bag, slot)
		return use(bag, slot, "sell")
	end

	function m.MoveToBank(bag, slot, kind)
		return use(bag, slot, kind)
	end

	-- Repairs: m.repairCost (nil: this vendor does not repair), m.guildRepair (nil: the guild does not pay;
	-- -1: no limit), m.repairs = { "own" | "guild" }.
	m.repairCost, m.guildRepair, m.repairs = nil, nil, {}
	function m.RepairCost()
		return m.repairCost
	end

	function m.Repair(guild)
		m.repairs[#m.repairs + 1] = guild and "guild" or "own"
		return true
	end

	function m.GuildRepairMoney()
		return m.guildRepair
	end

	function m.IsQuestItem(bag, slot)
```

Create `spec/mover_spec.lua`:

```lua
-- Week 7 (user picks 4 and 6): the mover sells or banks a list of items one at a time, a short delay
-- apart, out of combat, never while an item is on the cursor or the item's button is under the mouse
-- (spec 4.2 rule 5), and stops when the vendor or bank closes or the target refuses an item.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Mover.lua",
}

describe("Mover (week 7)", function()
	local SB, A, Mover, result, open, hovered
	before_each(function()
		SB = Loader.New(FILES)
		A, Mover = SB.Adapter, SB.Mover
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- 1 potion x5, 2 flask x2, 3 BoE ring, 4 helm, 5 keystone, 6 junk x3
		result, open, hovered = nil, true, {}
		SB.BagsWindow = { IsOpen = function() return true end, ButtonBusy = function(bag, slot)
			return hovered[bag .. ":" .. slot] == true
		end }
	end)

	local function items(...)
		local out = {}
		for i, slot in ipairs({ ... }) do
			local s = A.GetSlot(0, slot)
			out[i] = { bag = 0, slot = slot, itemID = s.itemID, link = s.link, count = s.count }
		end
		return out
	end

	local function start(list)
		return Mover.Start({ items = list, act = A.SellItem, still = function() return open end, done = function(r)
			result = r
		end })
	end

	local function usedSlots()
		local out = {}
		for i, u in ipairs(A.used) do
			out[i] = u.slot
		end
		return out
	end

	-- Mutation: in step, call `step(run)` instead of `later(run, Mover.DELAY)` after a move (all at once).
	it("moves one item per DELAY, in order, then reports what moved", function()
		assert.truthy(start(items(1, 2, 6)))
		assert.same({ 1 }, usedSlots(), "the first at once")
		A.Advance(Mover.DELAY)
		assert.same({ 1, 2 }, usedSlots())
		A.Advance(Mover.DELAY * 2)
		assert.same({ 1, 2, 6 }, usedSlots())
		assert.same({ 3, 0, nil }, { #result.moved, result.left, result.why })
		assert.falsy(Mover.Busy())
	end)

	-- P5. Mutation: in step, drop the Mover.IsBusy check.
	it("waits while an item is on the cursor or the item's button is under the mouse, then moves it", function()
		hovered["0:1"] = true
		start(items(1, 2))
		assert.same({}, usedSlots(), "the hovered potion waits")
		A.Advance(Mover.RETRY)
		assert.same({}, usedSlots())
		hovered["0:1"] = nil
		A.cursor = { itemID = 1, link = "x" }
		A.Advance(Mover.RETRY)
		assert.same({}, usedSlots(), "an item on the cursor holds every step")
		A.cursor = nil
		A.Advance(Mover.RETRY)
		assert.same({ 1 }, usedSlots())
	end)

	-- Mutation: in step, `if run.waits <= Mover.MAX_WAITS` -> `if true` (the run never ends). An item on the
	-- cursor is waited for without a limit (the vendor closing ends the run).
	it("an item the mouse never leaves stays where it is; the run goes on with the next", function()
		hovered["0:1"] = true
		start(items(1, 2))
		A.Advance(Mover.RETRY * (Mover.MAX_WAITS + 1))
		A.Advance(Mover.DELAY * 2)
		assert.same({ 2 }, usedSlots())
		assert.same({ 1, 1 }, { #result.moved, result.kept })
		assert.equal(1, result.left, "kept items count as left")
		A.cursor = { itemID = 1, link = "x" }
		start(items(6))
		A.Advance(Mover.RETRY * (Mover.MAX_WAITS + 5))
		assert.same({ 2 }, usedSlots(), "still waiting for the cursor")
		A.cursor = nil
		A.Advance(Mover.RETRY)
		assert.same({ 2, 6 }, usedSlots())
	end)

	-- Mutations: drop the A.InCombat() check in step; or drop the still() check.
	it("combat stops the run (nothing queued); a vendor or bank that closes stops it too", function()
		start(items(1, 2, 6))
		A.combat = true
		A.Advance(Mover.DELAY)
		assert.same({ 1 }, usedSlots())
		assert.same({ "combat", 1, 2 }, { result.why, #result.moved, result.left })
		A.combat = false
		start(items(2, 6))
		open = false
		A.Advance(Mover.DELAY)
		assert.same({ "closed", 1, 1 }, { result.why, #result.moved, result.left })
		A.combat = true
		assert.same({ false, "combat" }, { start(items(6)) }, "nothing starts in combat")
	end)

	-- Mutation: in step, drop the `if not same(item)` skip (the wrong item would be sold).
	it("a slot that no longer holds the item is skipped, never acted on", function()
		local list = items(1, 2)
		A.Put(0, 1, Fixtures.HERB, 20) -- the potion was used up and a herb took its slot
		start(list)
		A.Advance(Mover.DELAY)
		assert.same({ 2 }, usedSlots())
		assert.same({ 1, 1 }, { #result.moved, result.skipped })
	end)

	-- Mutation: in step, treat an item still there as moved (drop the `elseif there` branch).
	it("waits while the client holds a sent item; an item still there and free means refused: the run stops", function()
		A.onUse = function(bag, slot)
			A.slots[bag][slot].isLocked = true -- sent: the server has not answered yet
		end
		start(items(1, 2))
		A.Advance(Mover.DELAY * 2)
		assert.same({ 1 }, usedSlots(), "waits for the answer")
		A.slots[0][1].isLocked = false -- the target refused it (a full bank tab)
		A.Advance(Mover.DELAY)
		assert.same({ "stuck", 0, 2 }, { result.why, #result.moved, result.left })
	end)

	-- Mutation: Mover.Start does not check Mover.run.
	it("one run at a time; an empty list starts nothing", function()
		A.onUse = function() end -- nothing leaves: the first step waits
		hovered["0:1"] = true
		assert.truthy(start(items(1)))
		assert.same({ false, "busy" }, { start(items(2)) })
		Mover.Stop()
		assert.same({ false, "empty" }, { start({}) })
	end)
end)
```

Create `spec/vendor_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 7 (user pick 4): at a vendor SwagBag sells gray junk (12 at most per run: Blizzard's buyback
-- keeps 12), never items in an equipment set or held by the client, then repairs with the player's gold
-- (or the guild's, when chosen); nothing in combat; one chat line says what was sold.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local GRAY = 400200

describe("Vendor (week 7)", function()
	local SB, A, Mover
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Mover.lua"
		files[#files + 1] = "SwagBag/Engine/Vendor.lua"
		SB = Loader.New(files)
		A, Mover = SB.Adapter, SB.Mover
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- slot 6: Broken Tooth x3, gray
		A.items[Fixtures.JUNK].sellPrice = 1234 -- 12s 34c each
		A.AddItem(GRAY, { name = "Frayed Robe", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CHEST",
			quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 50 })
		A.money = 1000000
		SB.Inventory.ScanAll()
	end)

	local function visit()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		A.Advance(Mover.DELAY * 30)
	end

	local function sold()
		local out = {}
		for _, u in ipairs(A.used) do
			if u.kind == "sell" then
				out[#out + 1] = u.slot
			end
		end
		return out
	end

	-- Mutations: Vendor.Protected ignores r.inEquipmentSet; Vendor.Junk drops `not r.isLocked`.
	it("sells gray junk a vendor pays for; never a set piece, an item the client holds, or one worth nothing", function()
		A.Put(0, 7, GRAY, 1, { inSet = true })
		A.Put(0, 8, GRAY, 1, { isLocked = true })
		A.Put(0, 9, GRAY, 1, { hasNoValue = true })
		A.Put(0, 10, GRAY, 1)
		SB.Inventory.ScanAll()
		visit()
		assert.same({ 6, 10 }, sold())
		assert.same({ "Sold 2 junk items for 37s 52c." }, A.Lines(), "3 x 12s 34c + 50c, one chat line")
	end)

	-- Mutation: in Vendor.Sell, `math.min(#list, V.BUYBACK)` -> `#list`.
	it("sells at most 12 per run (the buyback tab keeps 12) and says how to sell the rest", function()
		A.SetBagSize(1, 20)
		for slot = 1, 15 do
			A.Put(1, slot, GRAY, 1)
		end
		SB.Inventory.ScanAll()
		visit()
		assert.equal(12, #sold())
		assert.same({ "Sold 12 junk items for 42s 52c. 4 more junk items wait (Blizzard's buyback keeps only the last 12):"
			.. " type /swagbag sell junk." }, A.Lines())
		SB.Slash.Dispatch("sell junk")
		A.Advance(Mover.DELAY * 10)
		assert.equal(16, #sold(), "the command sells the rest")
	end)

	-- P2: the command answers once, with the sale's line. Mutation: in Vendor.Visit, drop the vendor.autoSell check.
	it("auto-sell off: nothing is sold by itself; /swagbag sell junk sells at a vendor and refuses elsewhere", function()
		SB.Slash.Dispatch("sell off")
		visit()
		assert.same({}, sold())
		SB.Slash.Dispatch("sell junk")
		A.Advance(Mover.DELAY * 3)
		assert.same({ 6 }, sold())
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		SB.Slash.Dispatch("sell junk")
		assert.same({ SB.L.VENDOR_SELL_OFF, "Sold 1 junk item for 37s 2c.",
			SB.L.VENDOR_NOT_OPEN }, A.Lines())
	end)

	-- Mutation: in Vendor.Repair, skip the `money < cost` check (the call would fail at the vendor).
	it("repairs with your gold after the sale; says when gold is short; Off repairs nothing", function()
		A.repairCost = 52000
		visit()
		assert.same({ "own" }, A.repairs)
		assert.same({ "Sold 1 junk item for 37s 2c.", "Repaired everything for 5g 20s 0c." }, A.Lines())
		A.money = 100
		A.Put(0, 6, Fixtures.JUNK, 1)
		A.printed = {}
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		visit()
		assert.same({ "own" }, A.repairs, "no second repair")
		assert.equal("Repairs cost 5g 20s 0c, more than you carry, so nothing was repaired.", A.Lines()[2])
		SB.Slash.Dispatch("repair off")
		A.money = 1000000
		visit()
		assert.same({ "own" }, A.repairs)
	end)

	-- Mutation: in Vendor.Repair, drop the guild branch.
	it("Guild bank first: the guild pays when it allows enough (or has no limit), else your gold", function()
		SB.Slash.Dispatch("repair guild")
		A.repairCost = 52000
		A.guildRepair = -1
		SB.Slash.Dispatch("sell off")
		visit()
		A.guildRepair = 100 -- not enough today
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		visit()
		assert.same({ "guild", "own" }, A.repairs)
		local lines = A.Lines()
		assert.equal("Repaired everything for 5g 20s 0c from the guild bank.", lines[3])
		assert.equal("Repaired everything for 5g 20s 0c.", lines[4])
	end)

	-- Mutation: in Vendor.Visit, drop the A.InCombat() branch.
	it("a vendor opened in combat sells and repairs once combat ends, only if it is still open", function()
		A.combat = true
		A.repairCost = 100
		SB.eventFrame:Fire("MERCHANT_SHOW")
		assert.same({}, sold())
		assert.same({ SB.L.VENDOR_COMBAT }, A.Lines())
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(Mover.DELAY * 3)
		assert.same({ 6 }, sold())
		assert.same({ "own" }, A.repairs)
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.Put(0, 6, Fixtures.JUNK, 1)
		A.combat = true
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(Mover.DELAY * 3)
		assert.same({ 6 }, sold(), "the vendor closed during combat: nothing more")
	end)

	-- Mutation: in soldLine, drop the `result.why == "closed"` branch.
	it("a vendor closed mid-run: the line says how many sold and how many stayed", function()
		for slot = 7, 9 do
			A.Put(0, slot, GRAY, 1)
		end
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.Advance(Mover.DELAY * 5)
		assert.same({ 6 }, sold())
		assert.same({ "Sold 1 junk item for 37s 2c. The vendor closed, so 3 stayed in your bags." }, A.Lines())
	end)

	-- P2. Mutation: /swagbag repair accepts any word.
	it("/swagbag sell and /swagbag repair answer every form; read-only settings refuse", function()
		SB.Slash.Dispatch("sell")
		SB.Slash.Dispatch("sell maybe")
		SB.Slash.Dispatch("repair")
		SB.Slash.Dispatch("repair sometimes")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("repair off")
		SB.Slash.Dispatch("sell off")
		local L = SB.L
		assert.same({ L.VENDOR_SELL_STATE:format("on"), L.VENDOR_SELL_USAGE, L.VENDOR_REPAIR_STATE:format("own"),
			L.VENDOR_REPAIR_USAGE, L.SETTINGS_READONLY, L.SETTINGS_READONLY }, A.Lines())
		assert.equal("own", SB.Config.Get("vendor.repair"))
	end)
end)

describe("Settings: vendor page (week 7)", function()
	local SB, SW, ran
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		SB.Config.Init(nil, nil)
		Fake.Install()
		ran = {}
		for _, name in ipairs({ "sell", "repair" }) do
			SB.Slash.Register(name, "test", function(arg)
				ran[#ran + 1] = name .. " " .. arg
				return "ran " .. name .. " " .. arg
			end)
		end
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsVendor.lua")
		SW = SB.SettingsWindow
		SW.Show("vendor")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- P1 / P2. Mutation: in the repair row's apply, always run "repair own".
	it("defaults first (On; Your gold), each click runs the command and answers in the status line", function()
		local shown = {}
		for i = 1, SW.used.buttons do
			shown[i] = { SW.buttons[i].text, SW.selected[SW.buttons[i]] == true }
		end
		assert.same({ { "On", true }, { "Off", false }, { "Your gold", true }, { "Guild bank first", false },
			{ "Off", false } }, shown)
		Fake.Fire(SW.buttons[2], "OnClick")
		Fake.Fire(SW.buttons[4], "OnClick")
		assert.same({ "sell off", "repair guild" }, ran)
		assert.equal("ran repair guild", SW.lastStatus)
	end)
end)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1298 passed, 16 failed`. The failures, exactly:

- `spec/mover_spec.lua :: Mover (week 7) > moves one item per DELAY, in order, then reports what moved`
- `spec/mover_spec.lua :: Mover (week 7) > waits while an item is on the cursor or the item's button is under the mouse, then moves it`
- `spec/mover_spec.lua :: Mover (week 7) > an item the mouse never leaves stays where it is; the run goes on with the next`
- `spec/mover_spec.lua :: Mover (week 7) > combat stops the run (nothing queued); a vendor or bank that closes stops it too`
- `spec/mover_spec.lua :: Mover (week 7) > a slot that no longer holds the item is skipped, never acted on`
- `spec/mover_spec.lua :: Mover (week 7) > waits while the client holds a sent item; an item still there and free means refused: the run stops`
- `spec/mover_spec.lua :: Mover (week 7) > one run at a time; an empty list starts nothing`
- `spec/vendor_spec.lua :: Vendor (week 7) > sells gray junk a vendor pays for; never a set piece, an item the client holds, or one worth nothing`
- `spec/vendor_spec.lua :: Vendor (week 7) > sells at most 12 per run (the buyback tab keeps 12) and says how to sell the rest`
- `spec/vendor_spec.lua :: Vendor (week 7) > auto-sell off: nothing is sold by itself; /swagbag sell junk sells at a vendor and refuses elsewhere`
- `spec/vendor_spec.lua :: Vendor (week 7) > repairs with your gold after the sale; says when gold is short; Off repairs nothing`
- `spec/vendor_spec.lua :: Vendor (week 7) > Guild bank first: the guild pays when it allows enough (or has no limit), else your gold`
- `spec/vendor_spec.lua :: Vendor (week 7) > a vendor opened in combat sells and repairs once combat ends, only if it is still open`
- `spec/vendor_spec.lua :: Vendor (week 7) > a vendor closed mid-run: the line says how many sold and how many stayed`
- `spec/vendor_spec.lua :: Vendor (week 7) > /swagbag sell and /swagbag repair answer every form; read-only settings refuse`
- `spec/vendor_spec.lua :: Settings: vendor page (week 7) > defaults first (On; Your gold), each click runs the command and answers in the status line`

Both new spec files fail whole: `Engine/Mover.lua` and `Engine/Vendor.lua` do not exist yet.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "moves one item per DELAY, in order, then reports what moved": in `SwagBag/Engine/Mover.lua`, `run.sent = item ⏎ return later(run, Mover.DELAY)` → `run.sent = item ⏎ return step(run)`.
- "waits while an item is on the cursor or the item's button is under the mouse, then moves it": in `SwagBag/Engine/Mover.lua`, `if Mover.IsBusy(item.bag, item.slot) then` → `if false then`.
- "an item the mouse never leaves stays where it is; the run goes on with the next": in `SwagBag/Engine/Mover.lua`, `if run.waits <= Mover.MAX_WAITS then` → `if true then`.
- "combat stops the run (nothing queued); a vendor or bank that closes stops it too": in `SwagBag/Engine/Mover.lua`, `if A.InCombat() then ⏎ return finish(run, "combat") ⏎ end` → `∅`.
- "combat stops the run (nothing queued); a vendor or bank that closes stops it too": in `SwagBag/Engine/Mover.lua`, `if run.job.still and not run.job.still() then ⏎ return finish(run, "closed") ⏎ end` → `∅`.
- "a slot that no longer holds the item is skipped, never acted on": in `SwagBag/Engine/Mover.lua`, `if not same(item) then` → `if false then`.
- "waits while the client holds a sent item; an item still there and free means refused: the run stops": in `SwagBag/Engine/Mover.lua`, `elseif there then ⏎ run.index` → `elseif false then ⏎ run.index`.
- "one run at a time; an empty list starts nothing": in `SwagBag/Engine/Mover.lua`, `if Mover.run then ⏎ return false, "busy" ⏎ end` → `∅`.
- "sells gray junk a vendor pays for; never a set piece, an item the client holds, or one worth nothing": in `SwagBag/Engine/Vendor.lua`, `return r.inEquipmentSet == true or` → `return`.
- "sells gray junk a vendor pays for; never a set piece, an item the client holds, or one worth nothing": in `SwagBag/Engine/Vendor.lua`, `not r.hasNoValue and not r.isLocked and` → `not r.hasNoValue and`.
- "sells at most 12 per run (the buyback tab keeps 12) and says how to sell the rest": in `SwagBag/Engine/Vendor.lua`, `for i = 1, math.min(#list, V.BUYBACK) do` → `for i = 1, #list do`.
- "auto-sell off: nothing is sold by itself; /swagbag sell junk sells at a vendor and refuses elsewhere": in `SwagBag/Engine/Vendor.lua`, `if SB.Config.Get("vendor.autoSell") and not SB.Mover.Busy() then` → `if not SB.Mover.Busy() then`.
- "repairs with your gold after the sale; says when gold is short; Off repairs nothing": in `SwagBag/Engine/Vendor.lua`, `if money and money < cost then` → `if false then`.
- "Guild bank first: the guild pays when it allows enough (or has no limit), else your gold": in `SwagBag/Engine/Vendor.lua`, `if mode == "guild" then` → `if false then`.
- "a vendor opened in combat sells and repairs once combat ends, only if it is still open": in `SwagBag/Engine/Vendor.lua`, `if SB.Adapter.InCombat() then ⏎ SB.Print(L.VENDOR_COMBAT)` → `if false then ⏎ SB.Print(L.VENDOR_COMBAT)`.
- "a vendor closed mid-run: the line says how many sold and how many stayed": in `SwagBag/Engine/Vendor.lua`, `if result.why == "closed" then` → `if false then`.
- "/swagbag sell and /swagbag repair answer every form; read-only settings refuse": in `SwagBag/Engine/Vendor.lua`, `elseif not REPAIR_LINES[arg] then ⏎ return L.VENDOR_REPAIR_USAGE` → `elseif false then ⏎ return L.VENDOR_REPAIR_USAGE`.
- "defaults first (On; Your gold), each click runs the command and answers in the status line": in `SwagBag/UI/SettingsVendor.lua`, `return run("repair " .. v)` → `return run("repair own")`.
- "an item the mouse never leaves stays where it is; the run goes on with the next": in `SwagBag/Engine/Mover.lua`, `if A.CursorItem() ~= nil then ⏎ return later(run, Mover.RETRY)` → `if false then ⏎ return later(run, Mover.RETRY)`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
	return pcall(C_Container.SortBank, bankType)
```

and replace it with:

```lua
	return pcall(C_Container.SortBank, bankType)
end

---------------------------------------------------------------------------
-- Selling, repairing and moving items (week 7, user picks 4 and 6). C_Container.UseContainerItem is what
-- a right-click on a bag item runs: at an open vendor it sells the item, at an open bank it moves the
-- item into that bank. Addons call it out of combat (Baganator's transfers, EnhanceQoL's vendor and
-- warband bank; names read only); SwagBag calls it out of combat only (Engine/Mover.lua checks).
---------------------------------------------------------------------------
function A.SellItem(bag, slot)
	if not (C_Container and C_Container.UseContainerItem) then
		return false
	end
	return pcall(C_Container.UseContainerItem, bag, slot)
end

-- Move a bag item into the bank of that kind: "bank" (character) | "warband". The bank type is the
-- call's own argument (11.0+), so Blizzard's selected tab and bank type are neither read nor set.
function A.MoveToBank(bag, slot, kind)
	local BT = Enum and Enum.BankType
	local bankType = BT and ((kind == "bank" and BT.Character) or (kind == "warband" and BT.Account))
	if bankType == nil or not (C_Container and C_Container.UseContainerItem) then
		return false
	end
	return pcall(C_Container.UseContainerItem, bag, slot, nil, bankType, false)
end

-- What repairing everything costs at this vendor, in copper (0: nothing to repair); nil when this
-- vendor does not repair or the client cannot say.
function A.RepairCost()
	local can, cost = _G.CanMerchantRepair, _G.GetRepairAllCost
	if type(can) ~= "function" or type(cost) ~= "function" then
		return nil
	end
	local okC, yes = pcall(can)
	if not okC or isSecret(yes) or not yes then
		return nil
	end
	local ok, copper = pcall(cost)
	if not ok or type(copper) ~= "number" or isSecret(copper) then
		return nil
	end
	return copper
end

-- Repair everything; guild = true pays from the guild bank. true when the call went through.
function A.Repair(guild)
	local fn = _G.RepairAllItems
	if type(fn) ~= "function" then
		return false
	end
	return (pcall(fn, guild == true))
end

-- Copper the guild lets this character spend on repairs today (-1: no limit), or nil when it may not.
function A.GuildRepairMoney()
	local can, money = _G.CanGuildBankRepair, _G.GetGuildBankWithdrawMoney
	if type(can) ~= "function" or type(money) ~= "function" then
		return nil
	end
	local okC, yes = pcall(can)
	if not okC or isSecret(yes) or not yes then
		return nil
	end
	local ok, copper = pcall(money)
	if not ok or type(copper) ~= "number" or isSecret(copper) then
		return nil
	end
	return copper
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "C_Container.SortBank", window = "bank", required = false },
```

and replace it with:

```lua
	{ path = "C_Container.SortBank", window = "bank", required = false },
	{ path = "C_Container.UseContainerItem", window = "bags", required = false },
	{ path = "CanMerchantRepair", window = "bags", required = false },
	{ path = "GetRepairAllCost", window = "bags", required = false },
	{ path = "RepairAllItems", window = "bags", required = false },
	{ path = "CanGuildBankRepair", window = "bags", required = false },
	{ path = "GetGuildBankWithdrawMoney", window = "bags", required = false },
```

In `SwagBag/Core/Config.lua`, find:

```lua
			} },
```

and replace it with:

```lua
			} },
		-- At a vendor (week 7, user pick 4; Engine/Vendor.lua). autoSell: sell gray junk at every vendor (on).
		-- repair: "own" (repair with your gold, default) | "guild" (the guild bank first) | "off".
		vendor = { autoSell = true, repair = "own" },
```

Create `SwagBag/Engine/Mover.lua`:

```lua
-- SwagBag mover (week 7): moves a list of bag items one at a time, a short delay apart. The auto-sell
-- (Engine/Vendor.lua) and the section actions (UI/SectionActions.lua) use it. One run at a time.
--   Mover.Start(job) -> true | false, why   why: "busy" (a run is going) | "combat" | "empty"
--     job = { items = { { bag, slot, itemID, link, count } },
--             act = fn(bag, slot) -> ok, err    the move itself (an Adapter call)
--             still = fn() -> bool             false once the vendor or bank closed: the run stops
--             done = fn(result) }              result = { moved = { item... }, left = n, why = nil |
--                                              "combat" | "closed" | "stuck" | "error" }
--   Mover.Busy() -> bool
--   Mover.IsBusy(bag, slot) -> bool   spec 4.2 rule 5: an item is on the cursor, or that slot's button is
--                                     under the mouse in the open bags window
-- Each step runs out of combat only (combat stops the run: nothing is queued) and only while still()
-- says yes. The slot must still hold the same item (item ID and link), else it is skipped: it was used
-- or moved by hand. P5: while an item is on the cursor every step waits RETRY and tries again (for as long
-- as the vendor or bank stays open); while the item's own button is under the mouse it waits the same way
-- MAX_WAITS times, then that item is left where it is. After a move the next step first checks the item really left:
-- while the client holds it locked (the server has not answered) the run waits; an item still there
-- and unlocked means the target refused it (a full bank, a vendor that will not buy it): the run stops
-- ("stuck"). No OnUpdate: every wait is an Adapter.After timer.
local _, SB = ...

local Mover = { DELAY = 0.2, RETRY = 0.3, MAX_WAITS = 20, MAX_PENDING = 10, run = nil }
SB.Mover = Mover

function Mover.Busy()
	return Mover.run ~= nil
end

function Mover.IsBusy(bag, slot)
	if SB.Adapter.CursorItem() ~= nil then
		return true
	end
	local W = SB.BagsWindow
	return W ~= nil and W.IsOpen ~= nil and W.IsOpen() and W.ButtonBusy ~= nil and W.ButtonBusy(bag, slot) == true
end

local function same(item)
	local s = SB.Adapter.GetSlot(item.bag, item.slot)
	return s ~= nil and s.itemID == item.itemID and s.link == item.link, s
end

local function finish(run, why)
	if Mover.run ~= run then
		return
	end
	Mover.run = nil
	run.result.why = why
	run.result.left = #run.items - run.index + 1 + run.result.kept -- not reached, or kept under the mouse
	if run.job.done then
		SB.ErrorTrap.Run("mover.done", "none", run.job.done, run.result)
	end
end

local step

local function later(run, seconds)
	SB.Adapter.After(seconds, SB.ErrorTrap.Guard("mover.step", function()
		step(run)
	end, "none"))
end

step = function(run)
	if Mover.run ~= run then
		return
	end
	local A = SB.Adapter
	-- The previous move: wait while the server has not answered; stop if the target refused it.
	local last = run.sent
	if last then
		local there, s = same(last)
		if there and s.isLocked and run.pending < Mover.MAX_PENDING then
			run.pending = run.pending + 1
			return later(run, Mover.DELAY)
		elseif there then
			run.index = run.index - 1 -- that item is still in the bags: count it as left
			local closed = run.job.still and not run.job.still()
			return finish(run, closed and "closed" or "stuck")
		end
		run.result.moved[#run.result.moved + 1] = last
		run.sent, run.pending = nil, 0
	end
	if run.job.still and not run.job.still() then
		return finish(run, "closed")
	end
	if A.InCombat() then
		return finish(run, "combat")
	end
	local item = run.items[run.index]
	if not item then
		return finish(run, nil)
	end
	if not same(item) then
		run.index, run.waits = run.index + 1, 0 -- used or moved by hand: nothing to do
		run.result.skipped = run.result.skipped + 1
		return step(run)
	end
	if A.CursorItem() ~= nil then
		return later(run, Mover.RETRY) -- the user is moving an item by hand: wait, however long it takes
	end
	if Mover.IsBusy(item.bag, item.slot) then
		run.waits = run.waits + 1
		if run.waits <= Mover.MAX_WAITS then
			return later(run, Mover.RETRY)
		end
		run.index, run.waits = run.index + 1, 0 -- the mouse never left it: it stays
		run.result.kept = run.result.kept + 1
		return step(run)
	end
	local ok, err = run.job.act(item.bag, item.slot)
	run.index, run.waits = run.index + 1, 0
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("mover.act", "none", tostring(err), A.Stack())
		end
		run.index = run.index - 1
		return finish(run, "error")
	end
	run.sent = item
	return later(run, Mover.DELAY)
end

function Mover.Start(job)
	if Mover.run then
		return false, "busy"
	end
	if SB.Adapter.InCombat() then
		return false, "combat"
	end
	if not job.items or #job.items == 0 then
		return false, "empty"
	end
	local run = { job = job, items = job.items, index = 1, waits = 0, pending = 0,
		result = { moved = {}, skipped = 0, kept = 0, left = 0 } }
	Mover.run = run
	step(run)
	return true
end

-- Combat or a /reload ends nothing by itself: the next step sees combat and stops (P5, no queue).
function Mover.Stop(why)
	local run = Mover.run
	if run then
		finish(run, why or "closed")
	end
end
```

Create `SwagBag/Engine/Vendor.lua`:

```lua
-- SwagBag at a vendor (week 7, user pick 4): sell gray junk and repair, by themselves, on MERCHANT_SHOW.
--   Vendor.Protected(record) -> bool   never sold by SwagBag: in an equipment set, or locked by the user
--                                      (Engine/Locks.lua, Task 5)
--   Vendor.Junk() -> { item }          gray items a vendor pays for, not protected, not held by the client
--                                      (being moved or traded), loaded; bags order. item = { bag, slot,
--                                      itemID, link, count, price } (price: copper per unit)
--   Vendor.Sell(list, kind) -> ok, why sell up to BUYBACK of `list` through the mover (Engine/Mover.lua);
--                                      kind "junk" (auto or /swagbag sell junk) or "section" (UI/SectionActions.lua)
--   Vendor.Repair() -> line | nil      repair as vendor.repair says; the chat line, or nil (nothing to repair)
--   Vendor.Money(copper) -> "1g 23s 4c"
-- Settings: vendor.autoSell (default on) and vendor.repair: "own" (default, your gold) | "guild" (the guild
-- bank first when the guild allows it, else your gold) | "off". Commands: /swagbag sell [on|off|junk],
-- /swagbag repair [own|guild|off]; Settings > Vendor (UI/SettingsVendor.lua).
-- Safety: at most BUYBACK (12) items per run, because Blizzard's buyback tab keeps only the last 12 sold:
-- every item SwagBag sells can still be bought back during that visit. Nothing runs in combat: a vendor
-- opened in combat sells and repairs once combat ends, if it is still open. Each sale goes through the
-- mover, so nothing is sold while an item is on the cursor or its button is under the mouse (P5); a sold
-- item leaves a placeholder in the open bags (spec 4.3), so nothing else moves. One chat line per visit
-- says what was sold and for how much; the repair says its own.
local _, SB = ...

local L = SB.L
local V = { open = false, BUYBACK = 12 }
SB.Vendor = V

function V.Money(copper)
	copper = math.floor(copper or 0)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	if g > 0 then
		return L.VENDOR_MONEY_G:format(g, s, c)
	elseif s > 0 then
		return L.VENDOR_MONEY_S:format(s, c)
	end
	return L.VENDOR_MONEY_C:format(c)
end

function V.Protected(r)
	return r.inEquipmentSet == true or (SB.Locks ~= nil and SB.Locks.Has(r.itemID))
end

function V.Junk()
	local A, out = SB.Adapter, {}
	for bag, slot, snap in SB.Inventory.Iterate("bags") do
		if snap then
			local r = SB.Items.Describe(bag, slot)
			local info = r and not r.pending and A.GetItemInfo(r.itemID)
			local price = info and info.sellPrice or 0
			if r and r.quality == 0 and not r.hasNoValue and not r.isLocked and price > 0 and not V.Protected(r) then
				out[#out + 1] = { bag = bag, slot = slot, itemID = r.itemID, link = r.link, count = r.count or 1,
					price = price }
			end
		end
	end
	return out
end

-- A chat line for a finished sale. kind "junk": "Sold 3 junk items for 1g 2s 3c."; "section": "Sold 3
-- items for ...". waiting: items past the buyback limit that were not offered this run.
local function soldLine(result, kind, total, waiting)
	local n, copper = #result.moved, 0
	for _, it in ipairs(result.moved) do
		copper = copper + (it.price or 0) * (it.count or 1)
	end
	local junk = kind == "junk"
	local line
	if n == 1 then
		line = (junk and L.VENDOR_SOLD_JUNK_ONE or L.VENDOR_SOLD_ONE):format(V.Money(copper))
	else
		line = (junk and L.VENDOR_SOLD_JUNK or L.VENDOR_SOLD):format(n, V.Money(copper))
	end
	if result.why == "closed" then
		line = line .. " " .. L.VENDOR_STOP_CLOSED:format(total - n)
	elseif result.why == "combat" then
		line = line .. " " .. L.VENDOR_STOP_COMBAT:format(total - n)
	elseif result.why == "stuck" or result.why == "error" then
		line = line .. " " .. L.VENDOR_STOP_REFUSED:format(total - n)
	elseif result.kept > 0 then
		line = line .. " " .. L.VENDOR_KEPT_MOUSE:format(result.kept)
	end
	if waiting > 0 then
		line = line .. " " .. (junk and L.VENDOR_MORE_JUNK or L.VENDOR_MORE):format(waiting)
	end
	return line
end

-- after(result): runs once the sale is over (the auto-sell repairs then).
function V.Sell(list, kind, after)
	if not V.open then
		return false, "closed"
	end
	local batch = {}
	for i = 1, math.min(#list, V.BUYBACK) do
		batch[i] = list[i]
	end
	local waiting = #list - #batch
	return SB.Mover.Start({ items = batch, act = SB.Adapter.SellItem, still = function()
		return V.open
	end, done = function(result)
		SB.Print(soldLine(result, kind, #batch, waiting))
		if after then
			after(result)
		end
	end })
end

function V.Repair()
	local A = SB.Adapter
	local mode = SB.Config.Get("vendor.repair")
	if mode == "off" then
		return nil
	end
	local cost = A.RepairCost()
	if not cost or cost <= 0 then
		return nil
	end
	if mode == "guild" then
		local funds = A.GuildRepairMoney()
		if funds and (funds < 0 or funds >= cost) and A.Repair(true) then
			return L.VENDOR_REPAIRED_GUILD:format(V.Money(cost))
		end
	end
	local money = A.Money()
	if money and money < cost then
		return L.VENDOR_REPAIR_POOR:format(V.Money(cost))
	end
	if A.Repair(false) then
		return L.VENDOR_REPAIRED:format(V.Money(cost))
	end
	return L.VENDOR_REPAIR_FAILED
end

local function repairNow()
	local line = V.Repair()
	if line then
		SB.Print(line)
	end
end

-- The vendor opened (or combat ended while it stayed open): sell junk, then repair, so the junk's gold
-- helps pay for the repair.
function V.Visit()
	if not V.open then
		return
	end
	if SB.Adapter.InCombat() then
		SB.Print(L.VENDOR_COMBAT)
		SB.OutOfCombat(V.Visit, "vendor.visit", "none")
		return
	end
	if SB.Config.Get("vendor.autoSell") and not SB.Mover.Busy() then
		local junk = V.Junk()
		if #junk > 0 and V.Sell(junk, "junk", repairNow) then
			return
		end
	end
	repairNow()
end

SB.On("MERCHANT_SHOW", function()
	V.open = true
	V.Visit()
end, "none")

SB.On("MERCHANT_CLOSED", function()
	V.open = false
end, "none")

---------------------------------------------------------------------------
-- /swagbag sell and /swagbag repair (P2: every form answers)
---------------------------------------------------------------------------
local function onOff(on)
	return on and L.OVERLAY_ON or L.OVERLAY_OFF
end

local function startJunk()
	if not V.open then
		return L.VENDOR_NOT_OPEN
	end
	local junk = V.Junk()
	if #junk == 0 then
		return L.VENDOR_NO_JUNK
	end
	local ok, why = V.Sell(junk, "junk")
	if not ok then
		return why == "combat" and L.VENDOR_COMBAT_NOW or L.MOVER_BUSY
	end
	return {} -- P2: the sale's own line, when it ends, is the one answer
end

SB.Slash.Register("sell", L.HELP_SELL, function(arg)
	arg = (arg or ""):lower()
	if arg == "" then
		return L.VENDOR_SELL_STATE:format(onOff(SB.Config.Get("vendor.autoSell")))
	elseif arg == "junk" then
		return startJunk()
	elseif arg ~= "on" and arg ~= "off" then
		return L.VENDOR_SELL_USAGE
	end
	if not SB.Config.Set("vendor.autoSell", arg == "on") then
		return L.SETTINGS_READONLY
	end
	return arg == "on" and L.VENDOR_SELL_ON or L.VENDOR_SELL_OFF
end)

local REPAIR_LINES = { own = "VENDOR_REPAIR_OWN", guild = "VENDOR_REPAIR_GUILD", off = "VENDOR_REPAIR_OFF" }

SB.Slash.Register("repair", L.HELP_REPAIR, function(arg)
	arg = (arg or ""):lower()
	if arg == "" then
		return L.VENDOR_REPAIR_STATE:format(tostring(SB.Config.Get("vendor.repair")))
	elseif not REPAIR_LINES[arg] then
		return L.VENDOR_REPAIR_USAGE
	end
	if not SB.Config.Set("vendor.repair", arg) then
		return L.SETTINGS_READONLY
	end
	return L[REPAIR_LINES[arg]]
end)
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.V1_COMBAT = "Open the V1 strip out of combat; it can only be filled then."
```

and replace it with:

```lua
L.V1_COMBAT = "Open the V1 strip out of combat; it can only be filled then."

-- At a vendor (week 7, user pick 4): auto-sell junk, auto-repair (Engine/Vendor.lua), and the mover
L.HELP_SELL = "sell [on|off|junk]: sell gray junk by itself at every vendor (on), never (off), or now (junk)"
L.HELP_REPAIR = "repair [own|guild|off]: repair at vendors with your gold, the guild bank first, or not at all"
L.VENDOR_MONEY_G = "%dg %ds %dc"
L.VENDOR_MONEY_S = "%ds %dc"
L.VENDOR_MONEY_C = "%dc"
L.VENDOR_SOLD_JUNK = "Sold %d junk items for %s."
L.VENDOR_SOLD_JUNK_ONE = "Sold 1 junk item for %s."
L.VENDOR_SOLD = "Sold %d items for %s."
L.VENDOR_SOLD_ONE = "Sold 1 item for %s."
L.VENDOR_STOP_CLOSED = "The vendor closed, so %d stayed in your bags."
L.VENDOR_STOP_COMBAT = "Combat started, so %d stayed in your bags."
L.VENDOR_STOP_REFUSED = "The vendor would not take the next one, so %d stayed in your bags."
L.VENDOR_KEPT_MOUSE = "%d stayed because the mouse rested on it."
L.VENDOR_MORE_JUNK = "%d more junk items wait (Blizzard's buyback keeps only the last 12): type /swagbag sell junk."
L.VENDOR_MORE = "%d more wait (Blizzard's buyback keeps only the last 12): use Sell all again."
L.VENDOR_REPAIRED = "Repaired everything for %s."
L.VENDOR_REPAIRED_GUILD = "Repaired everything for %s from the guild bank."
L.VENDOR_REPAIR_POOR = "Repairs cost %s, more than you carry, so nothing was repaired."
L.VENDOR_REPAIR_FAILED = "The vendor did not repair: nothing was paid."
L.VENDOR_COMBAT = "In combat: selling junk and repairing wait until combat ends, if the vendor is still open."
L.VENDOR_COMBAT_NOW = "In combat: nothing was sold. Try again once combat ends."
L.VENDOR_NOT_OPEN = "Open a vendor first: SwagBag sells only while a vendor is open."
L.VENDOR_NO_JUNK = "No junk to sell: no gray items a vendor pays for (locked and equipment-set items are never sold)."
L.MOVER_BUSY = "SwagBag is still moving items: wait a moment and try again."
L.VENDOR_SELL_STATE = "Auto-sell junk at vendors: %s. Type /swagbag sell on, sell off, or sell junk (at a vendor)."
L.VENDOR_SELL_USAGE = "Use /swagbag sell, sell on, sell off, or sell junk."
L.VENDOR_SELL_ON = "Gray junk is now sold by itself at every vendor (never locked or equipment-set items)."
L.VENDOR_SELL_OFF = "Gray junk is no longer sold by itself. Type /swagbag sell junk at a vendor to sell it."
L.VENDOR_REPAIR_STATE = "Repair at vendors: %s. Type /swagbag repair own, repair guild, or repair off."
L.VENDOR_REPAIR_USAGE = "Use /swagbag repair, repair own, repair guild, or repair off."
L.VENDOR_REPAIR_OWN = "Vendors now repair your gear with your gold."
L.VENDOR_REPAIR_GUILD = "Vendors now repair from the guild bank when your guild allows it, else with your gold."
L.VENDOR_REPAIR_OFF = "Vendors no longer repair by themselves."
L.SET_PAGE_VENDOR = "Vendor"
L.SET_VENDOR_SELL = "Sell gray junk by itself at every vendor"
L.SET_VENDOR_SELL_TIP = "On: gray items a vendor pays for are sold when you open a vendor, 12 at most each time, so"
	.. " Blizzard's buyback tab still has every one of them. Locked items and items in an equipment set are never"
	.. " sold. Off: nothing is sold by itself; /swagbag sell junk sells now."
L.SET_VENDOR_REPAIR = "Repair at vendors"
L.SET_VENDOR_REPAIR_TIP = "Your gold: everything is repaired when you open a vendor that repairs. Guild bank first:"
	.. " the guild pays when it allows you to, else your gold. Off: you repair yourself."
L.SET_VENDOR_REPAIR_OWN = "Your gold"
L.SET_VENDOR_REPAIR_GUILD = "Guild bank first"
L.SET_VENDOR_NOTE = "Nothing is sold or repaired in combat. One chat line says what was sold and for how much."
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
Engine/Consumables.lua
```

and replace it with:

```text
Engine/Consumables.lua
Engine/Mover.lua
Engine/Vendor.lua
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
UI/SettingsConsumables.lua
```

and replace it with:

```text
UI/SettingsConsumables.lua
UI/SettingsVendor.lua
```

Create `SwagBag/UI/SettingsVendor.lua`:

```lua
-- SwagBag settings: the Vendor page (week 7, user pick 4). Auto-sell junk On (default) / Off, and the
-- repair: Your gold (default) / Guild bank first / Off. Every click runs the chat command, so the
-- window and the command never disagree (P2: the status line answers).
local _, SB = ...

local L = SB.L

local function rows()
	local run = SB.SettingsWindow.RunCommand
	return {
		{ kind = "choice", label = L.SET_VENDOR_SELL, tip = L.SET_VENDOR_SELL_TIP, get = function()
			return SB.Config.Get("vendor.autoSell")
		end, choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			return run(v and "sell on" or "sell off")
		end },
		{ kind = "choice", label = L.SET_VENDOR_REPAIR, tip = L.SET_VENDOR_REPAIR_TIP, width = 130, get = function()
			return SB.Config.Get("vendor.repair")
		end, choices = { { value = "own", text = L.SET_VENDOR_REPAIR_OWN }, { value = "guild", text = L.SET_VENDOR_REPAIR_GUILD },
			{ value = "off", text = L.SET_OFF } },
		apply = function(v)
			return run("repair " .. v)
		end },
		{ kind = "note", label = L.SET_VENDOR_NOTE },
	}
end

SB.SettingsWindow.AddPage({ id = "vendor", title = L.SET_PAGE_VENDOR, rows = rows })
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1314 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (66 files)`, `1314 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Core/Config.lua \
	SwagBag/Engine/Mover.lua \
	SwagBag/Engine/Vendor.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/SettingsVendor.lua \
	spec/mock_adapter.lua \
	spec/mover_spec.lua \
	spec/vendor_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 4: the mover, auto-sell junk (12 at most, never set items) and auto-repair; Settings > Vendor

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 5: Item locks: the Lock button, the lock mark, never sold, and a warning when sold by hand

User pick 5. `Engine/Locks.lua` keeps `SwagBagDB.locks` per item ID (D14), with `/swagbag lock [list|clear]`. `UI/LockButton.lua` puts a plain `Lock` button at the right end of the bags window's search row: drop an item on it (or click it holding one) to lock or unlock, and the item goes back; a click on an empty cursor says how (D15); the item tooltip gets a "Locked" line. The search box's error line keeps clear of the button (`rightInset`). `Vendor.Protected` already asks `SB.Locks`, so the auto-sell skips locked items; the vendor also watches locked items while it is open and warns once if one is sold by hand (D16). The keyword `locked` now means locked by the user, and the client's lock is `inuse` (D17). A padlock mark (`overlays.lock`, on). Settings > Vendor gets a drop row and List / Unlock all.

**Files:**
- Create: `SwagBag/Engine/Locks.lua` (TOC, before `Engine/Mover.lua`), `SwagBag/UI/LockButton.lua` (TOC, after `UI/SearchBox.lua`): 68 files
- Modify: `SwagBag/Engine/Keywords.lua` (`locked`, `inuse`), `SwagBag/Engine/Vendor.lua` (`WatchLocked`, the warning), `SwagBag/Core/Adapter.lua` (`BuybackLinks`; two optional checks), `SwagBag/Engine/OverlayData.lua` (`locked`), `SwagBag/UI/Overlays.lua` (the padlock), `SwagBag/UI/SearchBox.lua` (`rightInset`), `SwagBag/UI/SettingsPages.lua` (the row), `SwagBag/UI/SettingsVendor.lua` (the lock rows), `SwagBag/Core/Config.lua` (`overlays.lock`), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/locks_spec.lua` (new), `spec/vendor_spec.lua`, `spec/keywords_spec.lua`, `spec/overlays_spec.lua`, `spec/searchbox_spec.lua`, `spec/mock_adapter.lua` (`m.buyback`, `BuybackLinks`)

**Interfaces:**
- Consumes: `Vendor.Protected` (Task 4), `Adapter.CursorItem/ClearCursor/HookItemTooltip/TooltipLine`, `SB.BagsWindow.frame`, the settings `drop` row.
- Produces: `SB.Locks.Has(itemID)`, `Toggle(itemID) -> true, locked | false, "readonly" | "invalid"`, `List()`, `Clear()`, `Name(itemID)`, `TooltipLine(tooltip, itemID)`; the event `SB_LOCKS_CHANGED`; `SB.LockButton.Drop()`, `LockButton.button`, `LockButton.DROP_GUARD`; `Vendor.WatchLocked()`, `Vendor.lockedAt`; `A.BuybackLinks()`; `OverlayData.For(...).locked` with `ctx.locked`; the overlay region `lock`; `L.LOCK_*`, `L.SET_LOCK_*`.

- [ ] **Step 1: Write the failing tests**

In `spec/keywords_spec.lua`, find:

```lua
		assert.same({ 10 }, matching("locked", ALL))
```

and replace it with:

```lua
		assert.same({ 10 }, matching("inuse", ALL), "the client's lock (week 7: was `locked`)")
		assert.same({}, matching("locked", ALL), "no Engine/Locks.lua here: nothing is user-locked")
```

Create `spec/locks_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 7 (user pick 5): item locks. Per item ID, account-wide (SwagBagDB.locks), never sold by SwagBag,
-- found by the `locked` keyword, set by dropping an item on the bags window's Lock button.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Locks (week 7)", function()
	local SB, A, Locks, changed
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
		SB = Loader.New(files)
		A, Locks = SB.Adapter, SB.Locks
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		changed = 0
		SB.On("SB_LOCKS_CHANGED", function()
			changed = changed + 1
		end)
	end)

	-- Mutation: in Locks.Toggle, store under tostring(itemID) (Has would never find it).
	it("a lock is per item ID, stored account-wide; a second toggle removes it; every change is announced", function()
		assert.same({ true, true }, { Locks.Toggle(Fixtures.HEALING_POTION) })
		assert.truthy(Locks.Has(Fixtures.HEALING_POTION))
		assert.same({ [Fixtures.HEALING_POTION] = true }, SB.Config.db.locks)
		assert.same({ Fixtures.HEALING_POTION }, Locks.List())
		assert.same({ true, false }, { Locks.Toggle(Fixtures.HEALING_POTION) })
		assert.falsy(Locks.Has(Fixtures.HEALING_POTION))
		assert.same({}, SB.Config.db.locks)
		assert.equal(2, changed)
	end)

	-- Mutation: in Locks.Toggle, drop the readOnly check.
	it("read-only settings, a bad item ID and damaged saved data change nothing and never throw", function()
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { Locks.Toggle(Fixtures.HEALING_POTION) })
		SB.Config.readOnly = false
		assert.same({ false, "invalid" }, { Locks.Toggle("potion") })
		SB.Config.db.locks = "broken"
		assert.falsy(Locks.Has(Fixtures.HEALING_POTION))
		assert.same({}, Locks.List())
		SB.Config.db.locks = { [Fixtures.FLASK] = true, junk = true, [1.5] = true }
		assert.same({ Fixtures.FLASK }, Locks.List())
		assert.equal(0, changed)
	end)

	-- Mutation: register `locked` as flag("isLocked") again.
	it("the search keyword `locked` finds the user's locked items; `inuse` is the client's lock", function()
		Locks.Toggle(Fixtures.FLASK)
		A.Put(0, 7, Fixtures.HERB, 3, { isLocked = true })
		local function matches(query, slot)
			return SB.Query.Eval(SB.Query.Compile(query), SB.Items.Describe(0, slot)) == true
		end
		assert.same({ false, true, false }, { matches("locked", 1), matches("locked", 2), matches("locked", 7) })
		assert.same({ false, true }, { matches("inuse", 2), matches("inuse", 7) })
	end)

	-- P2. Mutation: /swagbag lock clear without the readOnly refusal (Locks.Clear's check removed).
	it("/swagbag lock says how, lists, unlocks all, and answers every form", function()
		Locks.Toggle(Fixtures.HEALING_POTION)
		Locks.Toggle(Fixtures.FLASK)
		SB.Slash.Dispatch("lock")
		SB.Slash.Dispatch("lock list")
		SB.Slash.Dispatch("lock what")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("lock clear")
		SB.Config.readOnly = false
		SB.Slash.Dispatch("lock clear")
		SB.Slash.Dispatch("lock list")
		local L = SB.L
		assert.same({ L.LOCK_STATE:format(2), "Locked: Algari Healing Potion, Flask of Alchemical Chaos.", L.LOCK_USAGE,
			L.SETTINGS_READONLY, "Unlocked all items (2).", L.LOCK_NONE }, A.Lines())
	end)

	-- Mutation: Locks.TooltipLine adds its line whatever Has says.
	it("a locked item's tooltip says it is locked; others get nothing", function()
		local tip = Fake.New("GameTooltip")
		Locks.Toggle(Fixtures.FLASK)
		Locks.TooltipLine(tip, Fixtures.HEALING_POTION)
		assert.is_nil(tip.calls.AddLine)
		Locks.TooltipLine(tip, Fixtures.FLASK)
		assert.equal(SB.L.LOCK_TOOLTIP, tip.calls.AddLine[1])
	end)
end)

describe("Lock button (week 7)", function()
	local SB, A, LB, button
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		Fake.Install()
		SB.BagsWindow = { frame = Fake.New("Frame", UIParent) }
		Loader.LoadFile(SB, "SwagBag/UI/LockButton.lua")
		LB = SB.LockButton
		button = LB.button
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- Mutation: in LB.Drop, drop A.ClearCursor() (the item would stay on the cursor).
	it("an item dropped on Lock is locked and goes back; again unlocks it; each answers once in chat", function()
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		Fake.Fire(button, "OnReceiveDrag")
		Fake.Fire(button, "OnClick", "LeftButton") -- the same press: ignored
		assert.truthy(SB.Locks.Has(Fixtures.FLASK))
		assert.is_nil(A.cursor, "the item went back")
		A.Advance(LB.DROP_GUARD)
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		Fake.Fire(button, "OnClick", "LeftButton")
		assert.falsy(SB.Locks.Has(Fixtures.FLASK))
		assert.same({ "Locked: Flask of Alchemical Chaos. SwagBag never sells it, and it shows a small lock.",
			"Unlocked: Flask of Alchemical Chaos." }, A.Lines())
	end)

	-- Mutation: in press(), drop the `elseif not guarded` branch (an empty click says nothing).
	it("a click with nothing on the cursor says how; read-only keeps the item on the cursor and says why", function()
		A.Advance(1)
		Fake.Fire(button, "OnClick", "LeftButton")
		SB.Config.readOnly = true
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		Fake.Fire(button, "OnClick", "LeftButton")
		assert.truthy(A.cursor, "refused: still on the cursor")
		assert.same({ SB.L.LOCK_STATE:format(0), SB.L.SETTINGS_READONLY }, A.Lines())
		assert.same({ "TOPRIGHT", SB.BagsWindow.frame, "TOPRIGHT", -8, -31 }, button.points[1], "right of the search box")
	end)
end)
```

In `spec/mock_adapter.lua`, find:

```lua
	end

	function m.IsQuestItem(bag, slot)
```

and replace it with:

```lua
	end

	-- The vendor's buyback tab: m.buyback = { link, ... } (week 7, the locked-item warning).
	m.buyback = {}
	function m.BuybackLinks()
		local out = {}
		for i, l in ipairs(m.buyback) do
			out[i] = l
		end
		return out
	end

	function m.IsQuestItem(bag, slot)
```

In `spec/overlays_spec.lua` (edit 1 of 2), find:

```lua
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, learn on, pawn off, title on",
```

and replace it with:

```lua
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, learn on, lock on, pawn off, title on",
```

In `spec/overlays_spec.lua` (edit 2 of 2), find:

```lua
		assert.falsy(Ov.regions[b].glow.shown, "the slot emptied: no glow")
```

and replace it with:

```lua
		assert.falsy(Ov.regions[b].glow.shown, "the slot emptied: no glow")
	end)

	-- Week 7 (user pick 5). Mutation: in Overlays.Apply, `show(r.lock, on("lock") and d.locked)` -> `d.locked`.
	it("a small lock on an item the user locked; overlays lock off hides it", function()
		SB.Locks = { Has = function(id) return id == Fixtures.FLASK end }
		local _, flask = draw(0, 2)
		local _, potion = draw(0, 1)
		assert.same({ true, false }, { flask.lock.shown, potion.lock.shown })
		assert.same({ "TOP", 14 }, { flask.lock.points[1][1], flask.lock.w })
		SB.Slash.Dispatch("overlays lock off")
		local _, off = draw(0, 2)
		assert.falsy(off.lock.shown)
```

In `spec/searchbox_spec.lua`, find:

```lua
		assert.same({ "TOPRIGHT", window.frame, "TOPRIGHT", -8, -26 }, errorLine.points[2])
```

and replace it with:

```lua
		assert.same({ "TOPRIGHT", window.frame, "TOPRIGHT", -62, -26 }, errorLine.points[2], "clear of the Lock button (week 7)")
```

In `spec/vendor_spec.lua` (edit 1 of 6), find:

```lua
		local files = { unpack(Env.ENGINE) }
```

and replace it with:

```lua
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
```

In `spec/vendor_spec.lua` (edit 2 of 6), find:

```lua
	end)

	-- P2. Mutation: /swagbag repair accepts any word.
```

and replace it with:

```lua
	end)

	-- Week 7 (user pick 5). Mutation: Vendor.Protected ignores SB.Locks.
	it("a locked junk item is never sold, by auto-sell or by /swagbag sell junk", function()
		A.Put(0, 7, GRAY, 1)
		SB.Inventory.ScanAll()
		SB.Locks.Toggle(Fixtures.JUNK)
		visit()
		assert.same({ 7 }, sold())
		SB.Slash.Dispatch("sell junk")
		assert.same({ 7 }, sold())
		assert.equal(SB.L.VENDOR_NO_JUNK, A.Lines()[2])
	end)

	-- Week 7: SwagBag cannot stop Blizzard's own right-click sale, so it says so at once. Mutations: drop
	-- the inBuyback check (an item merely moved would warn); or skip V.WatchLocked on MERCHANT_SHOW.
	it("a locked item sold by hand (it left the bags and is in the buyback tab) gets one warning", function()
		SB.Slash.Dispatch("sell off")
		SB.Locks.Toggle(Fixtures.BOE_RING)
		SB.Locks.Toggle(Fixtures.FLASK)
		visit()
		A.printed = {}
		A.Clear(0, 2) -- the flask moved elsewhere (not in the buyback)
		A.Clear(0, 3) -- the ring was sold by right-click
		A.buyback = { "item:225001::upgradable" }
		SB.Inventory.MarkDirty(0)
		SB.Inventory.Flush("test")
		assert.same({ "You sold Band of the Fallen, which you locked. Buy it back from the vendor's Buyback tab if that"
			.. " was a mistake." }, A.Lines())
	end)

	-- P2. Mutation: /swagbag repair accepts any word.
```

In `spec/vendor_spec.lua` (edit 3 of 6), find:

```lua
		for _, name in ipairs({ "sell", "repair" }) do
```

and replace it with:

```lua
		for _, name in ipairs({ "sell", "repair", "lock" }) do
```

In `spec/vendor_spec.lua` (edit 4 of 6), find:

```lua
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
```

and replace it with:

```lua
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/Locks.lua")
```

In `spec/vendor_spec.lua` (edit 5 of 6), find:

```lua
			{ "Off", false } }, shown)
```

and replace it with:

```lua
			{ "Off", false }, { "Drop an item here", false }, { "List them", false }, { "Unlock all", false } }, shown)
```

In `spec/vendor_spec.lua` (edit 6 of 6), find:

```lua
		assert.equal("ran repair guild", SW.lastStatus)
	end)
end)
```

and replace it with:

```lua
		assert.equal("ran repair guild", SW.lastStatus)
	end)

	-- Week 7 (user pick 5). Mutation: in lockDrop, drop the DROP_ECHO check (the click half of the press
	-- would replace the answer with "Pick up an item first").
	it("the lock drop row locks the item on the cursor; the click half of the same press keeps the answer", function()
		local A = SB.Adapter
		Fixtures.Install(A)
		Loader.LoadFile(SB, "SwagBag/UI/LockButton.lua")
		local drop
		for i = 1, SW.used.buttons do
			if SW.buttons[i].text == SB.L.SET_LOCK_DROP then
				drop = SW.buttons[i]
			end
		end
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		Fake.Fire(drop, "OnReceiveDrag")
		Fake.Fire(drop, "OnClick")
		assert.truthy(SB.Locks.Has(Fixtures.FLASK))
		assert.equal(SB.L.LOCK_ADDED:format("Flask of Alchemical Chaos"), SW.lastStatus)
		A.Advance(1)
		Fake.Fire(drop, "OnClick")
		assert.equal(SB.L.SET_WATCH_DROP_EMPTY, SW.lastStatus)
	end)
end)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1302 passed, 23 failed`. The failures, exactly:

- `spec/keywords_spec.lua :: Keywords (v1.0, week-1 families) > state keywords`
- `spec/locks_spec.lua :: Locks (week 7) > a lock is per item ID, stored account-wide; a second toggle removes it; every change is announced`
- `spec/locks_spec.lua :: Locks (week 7) > read-only settings, a bad item ID and damaged saved data change nothing and never throw`
- `spec/locks_spec.lua :: Locks (week 7) > the search keyword `locked` finds the user's locked items; `inuse` is the client's lock`
- `spec/locks_spec.lua :: Locks (week 7) > /swagbag lock says how, lists, unlocks all, and answers every form`
- `spec/locks_spec.lua :: Locks (week 7) > a locked item's tooltip says it is locked; others get nothing`
- `spec/locks_spec.lua :: Lock button (week 7) > an item dropped on Lock is locked and goes back; again unlocks it; each answers once in chat`
- `spec/locks_spec.lua :: Lock button (week 7) > a click with nothing on the cursor says how; read-only keeps the item on the cursor and says why`
- `spec/overlays_spec.lua :: Overlays (spec F9) > each overlay has its own switch; /swagbag overlays lists and switches them`
- `spec/overlays_spec.lua :: Overlays (spec F9) > a small lock on an item the user locked; overlays lock off hides it`
- `spec/searchbox_spec.lua :: SearchBox > the error line is top-aligned right of the box and never stretches over the items`
- `spec/vendor_spec.lua :: Vendor (week 7) > sells gray junk a vendor pays for; never a set piece, an item the client holds, or one worth nothing`
- `spec/vendor_spec.lua :: Vendor (week 7) > sells at most 12 per run (the buyback tab keeps 12) and says how to sell the rest`
- `spec/vendor_spec.lua :: Vendor (week 7) > auto-sell off: nothing is sold by itself; /swagbag sell junk sells at a vendor and refuses elsewhere`
- `spec/vendor_spec.lua :: Vendor (week 7) > repairs with your gold after the sale; says when gold is short; Off repairs nothing`
- `spec/vendor_spec.lua :: Vendor (week 7) > Guild bank first: the guild pays when it allows enough (or has no limit), else your gold`
- `spec/vendor_spec.lua :: Vendor (week 7) > a vendor opened in combat sells and repairs once combat ends, only if it is still open`
- `spec/vendor_spec.lua :: Vendor (week 7) > a vendor closed mid-run: the line says how many sold and how many stayed`
- `spec/vendor_spec.lua :: Vendor (week 7) > a locked junk item is never sold, by auto-sell or by /swagbag sell junk`
- `spec/vendor_spec.lua :: Vendor (week 7) > a locked item sold by hand (it left the bags and is in the buyback tab) gets one warning`
- `spec/vendor_spec.lua :: Vendor (week 7) > /swagbag sell and /swagbag repair answer every form; read-only settings refuse`
- `spec/vendor_spec.lua :: Settings: vendor page (week 7) > defaults first (On; Your gold), each click runs the command and answers in the status line`
- `spec/vendor_spec.lua :: Settings: vendor page (week 7) > the lock drop row locks the item on the cursor; the click half of the same press keeps the answer`

`spec/locks_spec.lua` and every test in `spec/vendor_spec.lua` fail because `Engine/Locks.lua` does not exist yet (the vendor specs now load it). `Keywords > state keywords` fails on `inuse`; `SearchBox > the error line ...` on the new inset; `Overlays > each overlay has its own switch` on the new `lock` name.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "a lock is per item ID, stored account-wide; a second toggle removes it; every change is announced": in `SwagBag/Engine/Locks.lua`, `t[itemID] = (t[itemID] ~= true) or nil` → `t[tostring(itemID)] = (t[tostring(itemID)] ~= true) or nil`.
- "read-only settings, a bad item ID and damaged saved data change nothing and never throw": in `SwagBag/Engine/Locks.lua`, `if SB.Config.readOnly then ⏎ return false, "readonly" ⏎ end ⏎ local t = store(true)` → `local t = store(true)`.
- "the search keyword `locked` finds the user's locked items; `inuse` is the client's lock": in `SwagBag/Engine/Keywords.lua`, `kw("locked", "volatile", function(r) ⏎ return SB.Locks ~= nil and SB.Locks.Has(r.itemID) ⏎ end)` → `kw("locked", "volatile", flag("isLocked"))`.
- "/swagbag lock says how, lists, unlocks all, and answers every form": in `SwagBag/Engine/Locks.lua`, `function Locks.Clear() ⏎ if SB.Config.readOnly then ⏎ return false, "readonly" ⏎ end` → `function Locks.Clear()`.
- "a locked item's tooltip says it is locked; others get nothing": in `SwagBag/Engine/Locks.lua`, `if Locks.Has(itemID) then ⏎ SB.Adapter.TooltipLine` → `if true then ⏎ SB.Adapter.TooltipLine`.
- "an item dropped on Lock is locked and goes back; again unlocks it; each answers once in chat": in `SwagBag/UI/LockButton.lua`, `A.ClearCursor() ⏎ return (locked` → `return (locked`.
- "a click with nothing on the cursor says how; read-only keeps the item on the cursor and says why": in `SwagBag/UI/LockButton.lua`, `elseif not guarded then ⏎ SB.Print(L.LOCK_STATE:format(#SB.Locks.List()))` → `∅`.
- "a locked junk item is never sold, by auto-sell or by /swagbag sell junk": in `SwagBag/Engine/Vendor.lua`, `or (SB.Locks ~= nil and SB.Locks.Has(r.itemID))` → `∅`.
- "a locked item sold by hand (it left the bags and is in the buyback tab) gets one warning": in `SwagBag/Engine/Vendor.lua`, `and inBuyback(was.link) then` → `then`.
- "a locked item sold by hand (it left the bags and is in the buyback tab) gets one warning": in `SwagBag/Engine/Vendor.lua`, `V.open = true ⏎ V.WatchLocked()` → `V.open = true`.
- "a small lock on an item the user locked; overlays lock off hides it": in `SwagBag/UI/Overlays.lua`, `show(r.lock, on("lock") and d.locked)` → `show(r.lock, d.locked)`.
- "the lock drop row locks the item on the cursor; the click half of the same press keeps the answer": in `SwagBag/UI/SettingsVendor.lua`, `if not A.CursorItem() and lastDrop and A.Now() - lastDrop < DROP_ECHO then` → `if false then`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
	end
	return copper
end

-- Repair everything; guild = true pays from the guild bank. true when the call went through.
```

and replace it with:

```lua
	end
	return copper
end

-- The links in the vendor's buyback tab (the last 12 items sold), oldest first; empty without the API.
function A.BuybackLinks()
	local num, link, out = _G.GetNumBuybackItems, _G.GetBuybackItemLink, {}
	if type(num) ~= "function" or type(link) ~= "function" then
		return out
	end
	local ok, n = pcall(num)
	if not ok or type(n) ~= "number" or isSecret(n) then
		return out
	end
	for i = 1, math.min(n, 12) do
		local okL, l = pcall(link, i)
		if okL and type(l) == "string" and not isSecret(l) then
			out[#out + 1] = l
		end
	end
	return out
end

-- Repair everything; guild = true pays from the guild bank. true when the call went through.
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "GetGuildBankWithdrawMoney", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "GetGuildBankWithdrawMoney", window = "bags", required = false },
	{ path = "GetNumBuybackItems", window = "bags", required = false },
	{ path = "GetBuybackItemLink", window = "bags", required = false },
```

In `SwagBag/Core/Config.lua`, find:

```lua
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = false,
			learn = true, usePawn = false },
```

and replace it with:

```lua
		-- lock (week 7): a small padlock on items the user locked (Engine/Locks.lua).
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = false,
			learn = true, lock = true, usePawn = false },
```

In `SwagBag/Engine/Keywords.lua`, find:

```lua
	kw("locked", "volatile", flag("isLocked"))
```

and replace it with:

```lua
	-- Week 7 (user pick 5): `locked` is the user's own lock (Engine/Locks.lua). The client's lock on an
	-- item being moved, traded or sold right now (spec 7.3's old `locked`) is `inuse`.
	kw("locked", "volatile", function(r)
		return SB.Locks ~= nil and SB.Locks.Has(r.itemID)
	end)
	kw("inuse", "volatile", flag("isLocked"))
```

Create `SwagBag/Engine/Locks.lua`:

```lua
-- SwagBag item locks (week 7, user pick 5): items the user never wants sold. A lock is per item ID
-- (every stack and copy of that item), account-wide, in SwagBagDB.locks = { [itemID] = true } (read
-- defensively: a damaged table is treated as empty; schema stays 2). A locked item is never sold by
-- SwagBag (Engine/Vendor.lua: auto-sell and Sell all skip it), wears a small lock (overlays.lock), says so
-- on its tooltip, and the search keyword `locked` finds it. Selling one by hand still works (SwagBag
-- cannot stop Blizzard's own right-click without hooking it, spec 5.3); a chat line then says so.
--   Locks.Has(itemID) -> bool
--   Locks.Toggle(itemID) -> true, locked | false, "readonly" | "invalid"
--   Locks.List() -> { itemID }  sorted
--   Locks.Clear() -> n | false, "readonly"
--   Locks.Name(itemID) -> the item's name (or "item 123" while it loads)
--   Locks.TooltipLine(tooltip, itemID)   the item tooltip's "Locked" line (UI/LockButton.lua hooks it)
-- Every change emits SB_LOCKS_CHANGED; the open windows re-draw their lock marks.
local _, SB = ...

local L = SB.L
local Locks = {}
SB.Locks = Locks

local function store(create)
	local db = SB.Config.db
	if not db then
		return nil
	end
	if type(db.locks) ~= "table" then
		if not create then
			return nil
		end
		db.locks = {}
	end
	return db.locks
end

local function valid(itemID)
	return type(itemID) == "number" and itemID >= 1 and itemID == math.floor(itemID) and itemID < math.huge
end

function Locks.Has(itemID)
	local t = store(false)
	return t ~= nil and valid(itemID) and t[itemID] == true
end

function Locks.Toggle(itemID)
	if not valid(itemID) then
		return false, "invalid"
	end
	if SB.Config.readOnly then
		return false, "readonly"
	end
	local t = store(true)
	t[itemID] = (t[itemID] ~= true) or nil
	SB.Emit("SB_LOCKS_CHANGED")
	return true, t[itemID] == true
end

function Locks.List()
	local out = {}
	for id, on in pairs(store(false) or {}) do
		if on == true and valid(id) then
			out[#out + 1] = id
		end
	end
	table.sort(out)
	return out
end

function Locks.Clear()
	if SB.Config.readOnly then
		return false, "readonly"
	end
	local n = #Locks.List()
	if SB.Config.db then
		SB.Config.db.locks = nil
	end
	SB.Emit("SB_LOCKS_CHANGED")
	return n
end

function Locks.Name(itemID)
	local info = SB.Adapter.GetItemInfo(itemID)
	return info and info.name or L.ITEM_N:format(itemID)
end

function Locks.TooltipLine(tooltip, itemID)
	if Locks.Has(itemID) then
		SB.Adapter.TooltipLine(tooltip, L.LOCK_TOOLTIP)
	end
end

-- /swagbag lock [list|clear]: how to lock, the locked items, or unlock them all (P2).
SB.Slash.Register("lock", L.HELP_LOCK, function(arg)
	arg = (arg or ""):lower()
	local list = Locks.List()
	if arg == "" then
		return L.LOCK_STATE:format(#list)
	elseif arg == "list" then
		if #list == 0 then
			return L.LOCK_NONE
		end
		local names = {}
		for i, id in ipairs(list) do
			names[i] = Locks.Name(id)
		end
		return L.LOCK_LIST:format(table.concat(names, ", "))
	elseif arg == "clear" then
		local n = Locks.Clear()
		if not n then
			return L.SETTINGS_READONLY
		end
		return L.LOCK_CLEARED:format(n)
	end
	return L.LOCK_USAGE
end)
```

In `SwagBag/Engine/OverlayData.lua` (edit 1 of 3), find:

```lua
--     learn     "open" | "learn" | nil   an item to click: open it, or learn it (ctx.learn, week 7) }
--   ctx = { equipped = { [invSlot] = { ilvl, equipLoc } }, canUse = fn(itemID) -> bool,
--           dungeonName = fn(mapID) -> name | nil, pawn = fn(record) -> true | false | nil,
--           learn = fn(record) -> "open" | "learn" | nil (Engine/Collections.lua) }
```

and replace it with:

```lua
--     learn     "open" | "learn" | nil   an item to click: open it, or learn it (ctx.learn, week 7)
--     locked    boolean         the user locked it (ctx.locked, week 7) }
--   ctx = { equipped = { [invSlot] = { ilvl, equipLoc } }, canUse = fn(itemID) -> bool,
--           dungeonName = fn(mapID) -> name | nil, pawn = fn(record) -> true | false | nil,
--           learn = fn(record) -> "open" | "learn" | nil (Engine/Collections.lua),
--           locked = fn(itemID) -> bool (Engine/Locks.lua) }
```

In `SwagBag/Engine/OverlayData.lua` (edit 2 of 3), find:

```lua
	local out = { junk = false, upgrade = false }
```

and replace it with:

```lua
	local out = { junk = false, upgrade = false, locked = false }
```

In `SwagBag/Engine/OverlayData.lua` (edit 3 of 3), find:

```lua
	end
	-- Pawn replaces only the item-level rule: eligibility (loading, unusable, not worn gear) comes first.
```

and replace it with:

```lua
	end
	if ctx.locked then
		out.locked = ctx.locked(record.itemID) == true
	end
	-- Pawn replaces only the item-level rule: eligibility (loading, unusable, not worn gear) comes first.
```

In `SwagBag/Engine/Vendor.lua` (edit 1 of 3), find:

```lua
-- says what was sold and for how much; the repair says its own.
```

and replace it with:

```lua
-- says what was sold and for how much; the repair says its own.
-- A locked item sold by hand (Blizzard's own right-click, which SwagBag does not hook) cannot be stopped:
-- while a vendor is open, a locked item that leaves the bags and shows up in the buyback tab gets one chat
-- line naming it and where to buy it back (Vendor.WatchLocked).
```

In `SwagBag/Engine/Vendor.lua` (edit 2 of 3), find:

```lua
SB.On("MERCHANT_SHOW", function()
	V.open = true
```

and replace it with:

```lua
-- Where the locked items are while a vendor is open: ["bag:slot"] = { itemID, link }.
V.lockedAt = {}
function V.WatchLocked()
	V.lockedAt = {}
	if not (V.open and SB.Locks) then
		return
	end
	for bag, slot, snap in SB.Inventory.Iterate("bags") do
		if snap and SB.Locks.Has(snap.itemID) then
			V.lockedAt[bag .. ":" .. slot] = { itemID = snap.itemID, link = snap.link }
		end
	end
end

local function inBuyback(link)
	for _, l in ipairs(SB.Adapter.BuybackLinks()) do
		if l == link then
			return true
		end
	end
	return false
end

SB.Inventory.OnChanged(function(mask, changes)
	if not (V.open and SB.Inventory.Has(mask, SB.Inventory.R.ITEM)) then
		return
	end
	for _, c in ipairs(changes) do
		local was = V.lockedAt[c.bag .. ":" .. c.slot]
		local now = SB.Inventory.GetSlot(c.bag, c.slot)
		if was and not (now and now.itemID == was.itemID) and inBuyback(was.link) then
			SB.Print(L.LOCK_SOLD:format(SB.Locks.Name(was.itemID)))
		end
	end
	V.WatchLocked()
end)

SB.On("MERCHANT_SHOW", function()
	V.open = true
	V.WatchLocked()
```

In `SwagBag/Engine/Vendor.lua` (edit 3 of 3), find:

```lua
	V.open = false
end, "none")
```

and replace it with:

```lua
	V.open = false
	V.lockedAt = {}
end, "none")

SB.On("SB_LOCKS_CHANGED", V.WatchLocked, "none")
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 3), find:

```lua
	.. " pawn)"
```

and replace it with:

```lua
	.. " lock, pawn)"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 3), find:

```lua
L.OVERLAYS_USAGE = "Use /swagbag overlays, or /swagbag overlays <ilvl|track|upgrade|keystone|junk|bind|learn|pawn|title>"
	.. " <on|off>."
```

and replace it with:

```lua
L.OVERLAYS_USAGE = "Use /swagbag overlays, or /swagbag overlays"
	.. " <ilvl|track|upgrade|keystone|junk|bind|learn|lock|pawn|title> <on|off>."
```

In `SwagBag/Locale/enUS.lua` (edit 3 of 3), find:

```lua
L.SET_VENDOR_NOTE = "Nothing is sold or repaired in combat. One chat line says what was sold and for how much."
```

and replace it with:

```lua
L.SET_VENDOR_NOTE = "Nothing is sold or repaired in combat. One chat line says what was sold and for how much."

-- Item locks (week 7, user pick 5): Engine/Locks.lua, UI/LockButton.lua
L.HELP_LOCK = "lock [list|clear]: how to lock items (drag one onto Lock), list the locked ones, or unlock them all"
L.BTN_LOCK = "Lock"
L.LOCK_TIP_TITLE = "Lock items"
L.LOCK_TIP_BODY = "Drag an item here (or click here while holding one) to lock it; do it again to unlock it. A"
	.. " locked item shows a small lock and is never sold by SwagBag. Selling it yourself still works."
L.LOCK_ADDED = "Locked: %s. SwagBag never sells it, and it shows a small lock."
L.LOCK_REMOVED = "Unlocked: %s."
L.LOCK_STATE = "Locked items: %d. Drag an item onto Lock (right of the search box) to lock or unlock it. Type"
	.. " /swagbag lock list or lock clear."
L.LOCK_NONE = "No item is locked."
L.LOCK_LIST = "Locked: %s."
L.LOCK_CLEARED = "Unlocked all items (%d)."
L.LOCK_USAGE = "Use /swagbag lock, lock list, or lock clear."
L.LOCK_TOOLTIP = "Locked in SwagBag: never sold by SwagBag"
L.LOCK_SOLD = "You sold %s, which you locked. Buy it back from the vendor's Buyback tab if that was a mistake."
L.SET_OV_LOCK = "Lock mark on locked items"
L.SET_LOCK_DROP_LABEL = "Lock or unlock an item (never sold by SwagBag)"
L.SET_LOCK_DROP = "Drop an item here"
L.SET_LOCK_COUNT = "Locked items: %d"
L.SET_LOCK_LIST = "List them"
L.SET_LOCK_CLEAR = "Unlock all"
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
Engine/Consumables.lua
```

and replace it with:

```text
Engine/Consumables.lua
Engine/Locks.lua
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
UI/SearchBox.lua
```

and replace it with:

```text
UI/SearchBox.lua
UI/LockButton.lua
```

Create `SwagBag/UI/LockButton.lua`:

```lua
-- SwagBag's Lock button (week 7, user pick 5): a small plain button at the right end of the bags
-- window's search row. Drag an item onto it (or click it while holding one) to lock or unlock that item;
-- the item goes back where it came from. A click with nothing on the cursor says how, and how many are
-- locked. This is the same drop pattern as a section header (AC4.3): SwagBag never hooks a click on an
-- item button (no click script or click hook of any kind: spec 5.3), so the item's own clicks stay
-- Blizzard's. The item tooltip gets a "Locked" line (Adapter.HookItemTooltip, taint-free).
--   LockButton.Drop() -> line   lock or unlock the item on the cursor (also the Settings > Vendor drop row)
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local LB = { DROP_GUARD = 0.3, WIDTH = 50 }
SB.LockButton = LB

local guardToken, guarded = 0, false

-- The item on the cursor: locked or unlocked, then put back. A refused change keeps it on the cursor.
function LB.Drop()
	local A, Locks = SB.Adapter, SB.Locks
	local itemID = A.CursorItem()
	if not itemID then
		return nil
	end
	local ok, locked = Locks.Toggle(itemID)
	if not ok then
		return locked == "readonly" and L.SETTINGS_READONLY or L.DROP_INVALID
	end
	A.ClearCursor()
	return (locked and L.LOCK_ADDED or L.LOCK_REMOVED):format(Locks.Name(itemID))
end

-- One press can fire OnReceiveDrag and OnClick together; the click right after a drop is ignored.
local function press()
	local line = LB.Drop()
	if line then
		guardToken = guardToken + 1
		local token = guardToken
		guarded = true
		SB.Adapter.After(LB.DROP_GUARD, Guard("lock.dropGuard", function()
			if token == guardToken then
				guarded = false
			end
		end, "bags"))
		SB.Print(line)
	elseif not guarded then
		SB.Print(L.LOCK_STATE:format(#SB.Locks.List()))
	end
end
LB.Press = press

local W = SB.BagsWindow
if W and W.frame then
	local b = CreateFrame("Button", nil, W.frame, "UIPanelButtonTemplate")
	b:SetSize(LB.WIDTH, 18)
	b:SetText(L.BTN_LOCK)
	b:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -8, -31)
	b:SetScript("OnClick", Guard("bags.lockButton", press, "bags"))
	b:SetScript("OnReceiveDrag", Guard("bags.lockDrop", press, "bags"))
	b:SetScript("OnEnter", Guard("bags.lockTip", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.LOCK_TIP_TITLE)
		GameTooltip:AddLine(L.LOCK_TIP_BODY, 1, 1, 1, true)
		GameTooltip:Show()
	end, "bags"))
	b:SetScript("OnLeave", Guard("bags.lockTipHide", function()
		GameTooltip:Hide()
	end, "bags"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	LB.button = b
end

-- Lock marks follow every change at once.
SB.On("SB_LOCKS_CHANGED", function()
	if SB.Overlays then
		SB.Overlays.RefreshAll()
	end
end, "none")

SB.On("SB_LOGIN", function()
	SB.Adapter.HookItemTooltip(Guard("tooltip.lock", SB.Locks.TooltipLine, "none"))
end, "none")
```

In `SwagBag/UI/Overlays.lua` (edit 1 of 6), find:

```lua
--   whole button  a soft green glow on an item to open or learn  (overlays.learn, week 7)
```

and replace it with:

```lua
--   whole button  a soft green glow on an item to open or learn  (overlays.learn, week 7)
--   top middle    a small padlock on an item the user locked      (overlays.lock, week 7)
```

In `SwagBag/UI/Overlays.lua` (edit 2 of 6), find:

```lua
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind", "learn" },
```

and replace it with:

```lua
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind", "learn", "lock" },
```

In `SwagBag/UI/Overlays.lua` (edit 3 of 6), find:

```lua
	GLOW_ATLAS = "bags-glow-white", LEARN_TINT = { 0.35, 1, 0.35 } }
```

and replace it with:

```lua
	GLOW_ATLAS = "bags-glow-white", LEARN_TINT = { 0.35, 1, 0.35 },
	-- The lock mark (week 7): Blizzard's pet-battle padlock, a plain texture file.
	LOCK_TEXTURE = "Interface\\PetBattles\\PetBattle-LockIcon", LOCK_SIZE = 14 }
```

In `SwagBag/UI/Overlays.lua` (edit 4 of 6), find:

```lua
		}
		r.glow:SetAllPoints(button)
```

and replace it with:

```lua
			lock = button:CreateTexture(nil, "OVERLAY", nil, 7),
		}
		r.glow:SetAllPoints(button)
		r.lock:SetTexture(Ov.LOCK_TEXTURE)
		r.lock:SetSize(Ov.LOCK_SIZE, Ov.LOCK_SIZE)
		r.lock:SetPoint("TOP", button, "TOP", 0, -1)
		r.lock:Hide()
```

In `SwagBag/UI/Overlays.lua` (edit 5 of 6), find:

```lua
			learn = SB.Collections and SB.Collections.Learn }
```

and replace it with:

```lua
			learn = SB.Collections and SB.Collections.Learn, locked = SB.Locks and SB.Locks.Has }
```

In `SwagBag/UI/Overlays.lua` (edit 6 of 6), find:

```lua
	show(r.glow, glow)
```

and replace it with:

```lua
	show(r.glow, glow)
	show(r.lock, on("lock") and d.locked)
```

In `SwagBag/UI/SearchBox.lua` (edit 1 of 3), find:

```lua
--     debounceKey, isOpen = fn() -> bool, forEachSlot = fn(fn), setDimmed = fn(button, dimmed) }
```

and replace it with:

```lua
--     debounceKey, isOpen = fn() -> bool, forEachSlot = fn(fn), setDimmed = fn(button, dimmed),
--     rightInset (optional: room kept free at the row's right end; the bags window's Lock button, week 7) }
```

In `SwagBag/UI/SearchBox.lua` (edit 2 of 3), find:

```lua
	errorLine:SetPoint("TOPRIGHT", o.parent, "TOPRIGHT", -8, -26)
```

and replace it with:

```lua
	errorLine:SetPoint("TOPRIGHT", o.parent, "TOPRIGHT", -(o.rightInset or 8), -26)
```

In `SwagBag/UI/SearchBox.lua` (edit 3 of 3), find:

```lua
	debounceKey = "search.bags",
```

and replace it with:

```lua
	debounceKey = "search.bags",
	rightInset = 62, -- the Lock button (UI/LockButton.lua) sits there
```

In `SwagBag/UI/SettingsPages.lua`, find:

```lua
	{ "learn", "overlays.learn", L.SET_OV_LEARN },
```

and replace it with:

```lua
	{ "learn", "overlays.learn", L.SET_OV_LEARN }, { "lock", "overlays.lock", L.SET_OV_LOCK },
```

In `SwagBag/UI/SettingsVendor.lua` (edit 1 of 3), find:

```lua
-- window and the command never disagree (P2: the status line answers).
```

and replace it with:

```lua
-- window and the command never disagree (P2: the status line answers). Item locks (user pick 5): a drop
-- target that locks or unlocks the item on the cursor (as the bags' Lock button), and Unlock all.
```

In `SwagBag/UI/SettingsVendor.lua` (edit 2 of 3), find:

```lua
local L = SB.L
```

and replace it with:

```lua
local L = SB.L

local DROP_ECHO = 0.2 -- one press can fire OnReceiveDrag and OnClick together (as on the Consumables page)
local lastDrop

local function lockDrop()
	local A = SB.Adapter
	if not A.CursorItem() and lastDrop and A.Now() - lastDrop < DROP_ECHO then
		return SB.SettingsWindow.lastStatus -- the second half of one press: keep the answer
	end
	local line = SB.LockButton and SB.LockButton.Drop()
	if not line then
		return L.SET_WATCH_DROP_EMPTY
	end
	lastDrop = A.Now()
	return line
end
```

In `SwagBag/UI/SettingsVendor.lua` (edit 3 of 3), find:

```lua
		{ kind = "note", label = L.SET_VENDOR_NOTE },
```

and replace it with:

```lua
		{ kind = "note", label = L.SET_VENDOR_NOTE },
		{ kind = "drop", label = L.SET_LOCK_DROP_LABEL, text = L.SET_LOCK_DROP, tip = L.LOCK_TIP_BODY, onDrop = lockDrop },
		{ kind = "actions", label = L.SET_LOCK_COUNT:format(SB.Locks and #SB.Locks.List() or 0), actions = {
			{ text = L.SET_LOCK_LIST, run = function()
				return run("lock list")
			end },
			{ text = L.SET_LOCK_CLEAR, run = function()
				return run("lock clear")
			end },
		} },
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1325 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (68 files)`, `1325 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Core/Config.lua \
	SwagBag/Engine/Keywords.lua \
	SwagBag/Engine/Locks.lua \
	SwagBag/Engine/OverlayData.lua \
	SwagBag/Engine/Vendor.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/LockButton.lua \
	SwagBag/UI/Overlays.lua \
	SwagBag/UI/SearchBox.lua \
	SwagBag/UI/SettingsPages.lua \
	SwagBag/UI/SettingsVendor.lua \
	spec/keywords_spec.lua \
	spec/locks_spec.lua \
	spec/mock_adapter.lua \
	spec/overlays_spec.lua \
	spec/searchbox_spec.lua \
	spec/vendor_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 5: item locks (Lock button, lock mark, 'locked' keyword), never sold by SwagBag, warning when sold by hand

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 6: Section actions: Shift+right-click a header to Send all to a bank or Sell all at a vendor

User pick 6. `UI/SectionActions.lua` (D18–D21): a Shift+right-click on a bags-window section header opens a small menu beside it. At a bank: `Send all to bank (N)` and `Send all to warband bank (N)` (the warband entry leaves out what the warband bank does not take), through the mover with `Adapter.MoveToBank`, which passes the bank type to the call. At a vendor: `Sell all (N)`, after a confirmation, through `Vendor.Sell` (never locked, set, held or worthless items; 12 at most). In combat a click refuses before any question. Elsewhere one line says where actions work. The header tooltip names the gesture while an action is available. `SectionHeaders` passes the header to `onClick` and gains optional `onEnter`/`onLeave`; the bags window adds `W.SectionSlots(id)` (the items drawn in a section, never a placeholder).

**Files:**
- Create: `SwagBag/UI/SectionActions.lua` (TOC, after `UI/BagsWindow.lua`): 69 files
- Modify: `SwagBag/UI/BagsWindow.lua` (Shift+right-click, the hint, `W.SectionSlots`), `SwagBag/UI/SectionHeaders.lua` (`onClick(id, button, header)`, `onEnter`, `onLeave`), `SwagBag/Core/Adapter.lua` (`AllowedInBank`, `ShiftDown`; one optional check), `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/sectionactions_spec.lua` (new), `spec/bagswindow_sections_spec.lua`, `spec/mock_adapter.lua` (`m.shift`, `m.notAllowed`, `ShiftDown`, `AllowedInBank`)

**Interfaces:**
- Consumes: `SB.Mover.Start` (Task 4), `SB.Vendor.open/Sell/Protected/Money/BUYBACK` (Tasks 4–5), `A.MoveToBank` (Task 4), `SB.BankWindow.interaction`, `W.state`, `W.records`, `SB.Categories.Name/FREE`, `StaticPopupDialogs`, `StaticPopup_Show`.
- Produces: `SB.SectionActions.Entries(id) -> { { text, run } }`, `Open(id, header)`, `Hint(id, header)`, `Available()`, `Sellable(id)`, `Bankable(id, kind)`, `ConfirmSell(id, list)`, `SellConfirmed()`, `SA.menu`; `StaticPopupDialogs.SWAGBAG_SELL_ALL`; `W.SectionSlots(id) -> { { bag, slot, record } }`; `A.AllowedInBank(bag, slot, kind)`, `A.ShiftDown()`; `L.SECTION_*`.

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_sections_spec.lua`, find:

```lua
	end)

	-- Pins week-4 D10 for the new style: the grid view has no sections, only the title changes.
```

and replace it with:

```lua
	end)

	-- Week 7 (user pick 6). Mutation: in SectionHeaders.onClick, drop the Shift+right-click branch.
	it("Shift+right-click on a header opens its section actions; a plain right-click still collapses", function()
		local opened
		SB.SectionActions = { Open = function(id, h) opened = { id, h } end }
		W.Open()
		A.shift = true
		click("c_gear", "RightButton")
		assert.same({ "c_gear", header("c_gear") }, opened)
		assert.equal("- Gear (1)", header("c_gear").text.text, "nothing collapsed")
		A.shift = false
		click("c_gear", "RightButton")
		assert.equal("+ Gear (1)", header("c_gear").text.text)
	end)

	-- Week 7. Mutation: in W.SectionSlots, drop `not c.placeholder` (a used item's ghost would be sold).
	it("SectionSlots lists the items drawn in a section, never a placeholder", function()
		W.Open()
		assert.same({ { 0, 1 }, { 0, 2 } }, (function()
			local out = {}
			for i, c in ipairs(W.SectionSlots("c_consumables")) do
				out[i] = { c.bag, c.slot }
			end
			return out
		end)())
		A.Put(0, 1, Fixtures.HERB, 5) -- the potions went and a herb took the slot: a placeholder holds the cell
		bagUpdate()
		assert.same({ 0, 2 }, { W.SectionSlots("c_consumables")[1].bag, W.SectionSlots("c_consumables")[1].slot })
		assert.equal(1, #W.SectionSlots("c_consumables"), "the herb in slot 1 is in New, not under its ghost")
		assert.same({}, W.SectionSlots("c_nothing"))
	end)

	-- Pins week-4 D10 for the new style: the grid view has no sections, only the title changes.
```

In `spec/mock_adapter.lua`, find:

```lua
	end

	-- The vendor's buyback tab: m.buyback = { link, ... } (week 7, the locked-item warning).
```

and replace it with:

```lua
	end

	-- Section actions (week 7): m.shift (Shift held); m.notAllowed[kind][itemID] = true (that bank refuses it).
	m.shift, m.notAllowed = false, { bank = {}, warband = {} }
	function m.ShiftDown()
		return m.shift == true
	end

	function m.AllowedInBank(bag, slot, kind)
		local s = m.slots[bag] and m.slots[bag][slot]
		return not (s and m.notAllowed[kind][s.itemID])
	end

	-- The vendor's buyback tab: m.buyback = { link, ... } (week 7, the locked-item warning).
```

Create `spec/sectionactions_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip StaticPopupDialogs StaticPopup_Show YES NO
-- Week 7 (user pick 6): Shift+right-click a section header for Sell all (at a vendor, asks first) or
-- Send all to the bank / warband bank (at a bank). Moves go through the mover: out of combat, one at a
-- time, never under the mouse; one chat line when an action ends.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local GRAY = 400200

describe("Section actions (week 7)", function()
	local SB, A, SA, Mover, sections, shown
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		for _, f in ipairs({ "SwagBag/Engine/Locks.lua", "SwagBag/Engine/Mover.lua", "SwagBag/Engine/Vendor.lua" }) do
			files[#files + 1] = f
		end
		SB = Loader.New(files)
		A, Mover = SB.Adapter, SB.Mover
		SB.Config.Init(nil, nil)
		SB.Config.Set("vendor.autoSell", false)
		Fixtures.SmallBags(A)
		A.AddItem(GRAY, { name = "Frayed Robe", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CHEST",
			quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 50 })
		A.items[Fixtures.HERB].sellPrice = 10
		A.SetBagSize(1, 10)
		for slot = 1, 5 do
			A.Put(1, slot, Fixtures.HERB, 20)
		end
		SB.Inventory.ScanAll()
		Fake.Install()
		shown = nil
		StaticPopupDialogs, YES, NO = {}, "Yes", "No"
		StaticPopup_Show = function(which)
			shown = which
		end
		-- The bags window as the actions read it: the Trade Goods section holds bag 1's herbs.
		sections = { c_tradegoods = { 1, 2, 3, 4, 5 } }
		SB.BagsWindow = { SectionSlots = function(id)
			local out = {}
			for _, slot in ipairs(sections[id] or {}) do
				if A.GetSlot(1, slot) then
					out[#out + 1] = { bag = 1, slot = slot, record = SB.Items.Describe(1, slot) }
				end
			end
			return out
		end }
		SB.BankWindow = { interaction = false }
		Loader.LoadFile(SB, "SwagBag/UI/SectionActions.lua")
		SA = SB.SectionActions
	end)

	after_each(function()
		Fake.Uninstall()
		StaticPopupDialogs, StaticPopup_Show, YES, NO = nil, nil, nil, nil
	end)

	local function used(kind)
		local out = {}
		for _, u in ipairs(A.used) do
			if u.kind == kind then
				out[#out + 1] = u.slot
			end
		end
		return out
	end

	local function texts()
		local out = {}
		for i, e in ipairs(SA.Entries("c_tradegoods")) do
			out[i] = e.text
		end
		return out
	end

	-- Mutation: in SA.Sellable, drop `not SB.Vendor.Protected(r)` (locked and set items would be sold).
	it("at a vendor Sell all asks first, then sells what a vendor pays for, never locked or set items", function()
		A.Put(1, 2, GRAY, 1, { inSet = true })
		A.Put(1, 3, Fixtures.HERB, 20, { hasNoValue = true })
		SB.Locks.Toggle(GRAY) -- also locks nothing else: the herbs stay sellable
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		assert.same({ "Sell all (3)" }, texts())
		SA.Entries("c_tradegoods")[1].run()
		assert.equal("SWAGBAG_SELL_ALL", shown)
		assert.equal("Sell 3 items from Trade Goods for about 6s 0c? Locked items and items in an equipment set stay.",
			StaticPopupDialogs.SWAGBAG_SELL_ALL.text)
		assert.same({}, used("sell"), "nothing before the answer")
		StaticPopupDialogs.SWAGBAG_SELL_ALL.OnAccept()
		A.Advance(Mover.DELAY * 5)
		assert.same({ 1, 4, 5 }, used("sell"))
		assert.same({ "Sold 3 items for 6s 0c." }, A.Lines())
	end)

	-- Mutation: SA.SellConfirmed skips the atVendor() check.
	it("No sells nothing; a vendor closed before Yes sells nothing and says so", function()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SA.Entries("c_tradegoods")[1].run()
		StaticPopupDialogs.SWAGBAG_SELL_ALL.OnCancel()
		StaticPopupDialogs.SWAGBAG_SELL_ALL.OnAccept()
		SA.Entries("c_tradegoods")[1].run()
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		StaticPopupDialogs.SWAGBAG_SELL_ALL.OnAccept()
		A.Advance(Mover.DELAY * 5)
		assert.same({}, used("sell"))
		assert.same({ SB.L.VENDOR_NOT_OPEN }, A.Lines())
	end)

	-- Mutations: SA.Bankable ignores AllowedInBank; or send() passes "bank" whatever the kind.
	it("at a bank: Send all to the bank or the warband bank, leaving out what the warband bank refuses", function()
		A.notAllowed.warband[Fixtures.HERB] = true
		A.Put(1, 2, Fixtures.ORE, 10)
		SB.Inventory.ScanAll()
		SB.BankWindow.interaction = true
		assert.same({ "Send all to bank (5)", "Send all to warband bank (1)" }, texts())
		SA.Entries("c_tradegoods")[2].run()
		A.Advance(Mover.DELAY * 3)
		assert.same({ 2 }, used("warband"))
		assert.same({}, used("bank"))
		assert.same({ "Sent 1 item from Trade Goods to the warband bank." }, A.Lines())
	end)

	-- Mutation: in send()'s done, drop the `result.why == "stuck"` branch.
	it("a bank that stops taking items (full) ends the run and says how many stayed", function()
		SB.BankWindow.interaction = true
		local n = 0
		A.onUse = function(bag, slot)
			n = n + 1
			if n <= 2 then
				A.Clear(bag, slot)
			end -- the third stays: the tab is full
		end
		SA.Entries("c_tradegoods")[1].run()
		A.Advance(Mover.DELAY * 10)
		assert.same({ 1, 2, 3 }, used("bank"))
		assert.same({ "Sent 2 items from Trade Goods to the bank. The bank did not take the next one (full, or a tab"
			.. " that does not take it), so 3 stayed." }, A.Lines())
	end)

	-- P2. Mutations: in SA.Open, return false without a chat line when there are no entries; or drop the
	-- combat check in SA.ConfirmSell (a question would come first, and nothing could sell).
	it("nowhere to act: one line says where actions work; Free has none; in combat nothing moves", function()
		SA.Open("c_tradegoods")
		SB.BankWindow.interaction = true
		SA.Open("free")
		A.combat = true
		SA.Entries("c_tradegoods")[1].run()
		SB.eventFrame:Fire("MERCHANT_SHOW") -- in combat: the auto-sell says it waits for combat's end
		SA.Entries("c_tradegoods")[1].run() -- Sell all
		assert.is_nil(shown, "no question in combat")
		assert.same({}, used("bank"))
		local L = SB.L
		assert.same({ L.SECTION_WHERE, L.SECTION_NOTHING:format("Free"), L.SECTION_COMBAT, L.VENDOR_COMBAT, L.SECTION_COMBAT },
			A.Lines())
	end)

	-- Mutation: the menu button's OnClick runs without hiding the menu first.
	it("the menu: a button per action and Cancel, beside the header; a click runs it and closes the menu", function()
		SB.BankWindow.interaction = true
		local header = Fake.New("Button", UIParent)
		assert.truthy(SA.Open("c_tradegoods", header))
		local m = SA.menu
		assert.same({ "Send all to bank (5)", "Send all to warband bank (5)", "Cancel" },
			{ m.buttons[1].text, m.buttons[2].text, m.buttons[3].text })
		assert.same({ "TOPLEFT", header, "BOTTOMLEFT", 24, 0 }, m.points[1])
		Fake.Fire(m.buttons[3], "OnClick")
		assert.falsy(m.shown, "Cancel closes")
		SA.Open("c_tradegoods", header)
		Fake.Fire(m.buttons[1], "OnClick")
		assert.falsy(m.shown)
		assert.same({ 1 }, used("bank"), "the first move at once")
		SA.Open("c_tradegoods", header)
		SB.Emit("SB_BAGS_CLOSED")
		assert.falsy(m.shown, "closing the bags closes the menu")
	end)

	-- Mutation: SA.Hint skips the SA.Available() check (every header gets a tooltip).
	it("a header's tooltip names Shift+right-click only while a vendor or bank is open", function()
		local header = Fake.New("Button", UIParent)
		SA.Hint("c_tradegoods", header)
		assert.is_nil(GameTooltip.calls.SetOwner, "no vendor, no bank: no tooltip")
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SA.Hint("c_tradegoods", header)
		assert.equal("Trade Goods", GameTooltip.text)
		assert.equal(SB.L.SECTION_HINT_VENDOR, GameTooltip.calls.AddLine[1])
	end)
end)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1325 passed, 9 failed`. The failures, exactly:

- `spec/bagswindow_sections_spec.lua :: BagsWindow focus front style (week 6) > Shift+right-click on a header opens its section actions; a plain right-click still collapses`
- `spec/bagswindow_sections_spec.lua :: BagsWindow focus front style (week 6) > SectionSlots lists the items drawn in a section, never a placeholder`
- `spec/sectionactions_spec.lua :: Section actions (week 7) > at a vendor Sell all asks first, then sells what a vendor pays for, never locked or set items`
- `spec/sectionactions_spec.lua :: Section actions (week 7) > No sells nothing; a vendor closed before Yes sells nothing and says so`
- `spec/sectionactions_spec.lua :: Section actions (week 7) > at a bank: Send all to the bank or the warband bank, leaving out what the warband bank refuses`
- `spec/sectionactions_spec.lua :: Section actions (week 7) > a bank that stops taking items (full) ends the run and says how many stayed`
- `spec/sectionactions_spec.lua :: Section actions (week 7) > nowhere to act: one line says where actions work; Free has none; in combat nothing moves`
- `spec/sectionactions_spec.lua :: Section actions (week 7) > the menu: a button per action and Cancel, beside the header; a click runs it and closes the menu`
- `spec/sectionactions_spec.lua :: Section actions (week 7) > a header's tooltip names Shift+right-click only while a vendor or bank is open`

`spec/sectionactions_spec.lua` fails whole (the file does not exist yet); the two window tests fail on the missing branch and `W.SectionSlots`.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "at a vendor Sell all asks first, then sells what a vendor pays for, never locked or set items": in `SwagBag/UI/SectionActions.lua`, `and it.price > 0 and not SB.Vendor.Protected(r) then` → `and it.price > 0 then`.
- "No sells nothing; a vendor closed before Yes sells nothing and says so": in `SwagBag/UI/SectionActions.lua`, `if not atVendor() then ⏎ SB.Print(L.VENDOR_NOT_OPEN) ⏎ return ⏎ end ⏎ local ok, why = SB.Vendor.Sell` → `local ok, why = SB.Vendor.Sell`.
- "at a bank: Send all to the bank or the warband bank, leaving out what the warband bank refuses": in `SwagBag/UI/SectionActions.lua`, `and A.AllowedInBank(c.bag, c.slot, kind) ~= false then` → `then`.
- "at a bank: Send all to the bank or the warband bank, leaving out what the warband bank refuses": in `SwagBag/UI/SectionActions.lua`, `return SB.Adapter.MoveToBank(bag, slot, kind)` → `return SB.Adapter.MoveToBank(bag, slot, "bank")`.
- "a bank that stops taking items (full) ends the run and says how many stayed": in `SwagBag/UI/SectionActions.lua`, `if result.why == "stuck" or result.why == "error" then ⏎ line = line .. " " .. L.SECTION_FULL:format(L[KIND_NAME[kind]], total - n) ⏎ elseif` → `if`.
- "nowhere to act: one line says where actions work; Free has none; in combat nothing moves": in `SwagBag/UI/SectionActions.lua`, `SB.Print(SA.Available() and L.SECTION_NOTHING:format(SB.Categories.Name(id)) or L.SECTION_WHERE) ⏎ return false` → `return false`.
- "the menu: a button per action and Cancel, beside the header; a click runs it and closes the menu": in `SwagBag/UI/SectionActions.lua`, `f:Hide() ⏎ if self.run then` → `if self.run then`.
- "a header's tooltip names Shift+right-click only while a vendor or bank is open": in `SwagBag/UI/SectionActions.lua`, `if not (GameTooltip and SA.Available()) or id == SB.Categories.FREE then` → `if not GameTooltip or id == SB.Categories.FREE then`.
- "Shift+right-click on a header opens its section actions; a plain right-click still collapses": in `SwagBag/UI/BagsWindow.lua`, `elseif mouseButton == "RightButton" and SB.SectionActions and SB.Adapter.ShiftDown() then ⏎ SB.SectionActions.Open(id, header)` → `∅`.
- "SectionSlots lists the items drawn in a section, never a placeholder": in `SwagBag/UI/BagsWindow.lua`, `local r = c and c.bag and not c.placeholder and W.records[c.bag]` → `local r = c and c.bag and W.records[c.bag]`.
- "nowhere to act: one line says where actions work; Free has none; in combat nothing moves": in `SwagBag/UI/SectionActions.lua`, `if SB.Adapter.InCombat() then -- nothing would sell` → `if false then -- nothing would sell`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
	return pcall(C_Container.UseContainerItem, bag, slot, nil, bankType, false)
```

and replace it with:

```lua
	return pcall(C_Container.UseContainerItem, bag, slot, nil, bankType, false)
end

-- true / false: whether the bank of that kind takes the bag item; nil when the client cannot say.
function A.AllowedInBank(bag, slot, kind)
	local BT = Enum and Enum.BankType
	local bankType = BT and ((kind == "bank" and BT.Character) or (kind == "warband" and BT.Account))
	if bankType == nil or not (C_Bank and C_Bank.IsItemAllowedInBankType) then
		return nil
	end
	local ok, yes = pcall(function()
		return C_Bank.IsItemAllowedInBankType(bankType, location(bag, slot))
	end)
	if not ok or isSecret(yes) or type(yes) ~= "boolean" then
		return nil
	end
	return yes
end

-- true while Shift is held (the section actions' Shift+right-click, week 7).
function A.ShiftDown()
	local fn = _G.IsShiftKeyDown
	if type(fn) ~= "function" then
		return false
	end
	local ok, yes = pcall(fn)
	return ok and yes == true
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "GetNumBuybackItems", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "GetNumBuybackItems", window = "bags", required = false },
	{ path = "IsShiftKeyDown", window = "bags", required = false },
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SET_LOCK_CLEAR = "Unlock all"
```

and replace it with:

```lua
L.SET_LOCK_CLEAR = "Unlock all"

-- Section actions (week 7, user pick 6): UI/SectionActions.lua
L.SECTION_BANK = "bank"
L.SECTION_WARBAND = "warband bank"
L.SECTION_SELL_ALL = "Sell all (%d)"
L.SECTION_SEND_ALL = "Send all to %s (%d)"
L.SECTION_CANCEL = "Cancel"
L.SECTION_SELL_CONFIRM = "Sell %d items from %s for about %s? Locked items and items in an equipment set stay."
L.SECTION_SENT = "Sent %d items from %s to the %s."
L.SECTION_SENT_ONE = "Sent 1 item from %s to the %s."
L.SECTION_FULL = "The %s did not take the next one (full, or a tab that does not take it), so %d stayed."
L.SECTION_CLOSED = "The bank closed, so %d stayed."
L.SECTION_COMBAT = "In combat: nothing was moved. Try again once combat ends."
L.SECTION_NOTHING = "Nothing in %s can be sold or sent here."
L.SECTION_WHERE = "Section actions work at a vendor (Sell all) or a bank (Send all). Open one, then Shift+right-click a"
	.. " section's header."
L.SECTION_HINT_VENDOR = "Shift+right-click: Sell all (asks first; locked and equipment-set items stay)"
L.SECTION_HINT_BANK = "Shift+right-click: Send all to the bank or the warband bank"
```

In `SwagBag/SwagBag.toc`, find:

```text
UI/BagsWindow.lua
```

and replace it with:

```text
UI/BagsWindow.lua
UI/SectionActions.lua
```

In `SwagBag/UI/BagsWindow.lua` (edit 1 of 3), find:

```lua
SB.SectionHeaders.onClick = function(id, mouseButton)
```

and replace it with:

```lua
-- Week 7 (user pick 6): Shift+right-click opens the section actions (UI/SectionActions.lua).
SB.SectionHeaders.onClick = function(id, mouseButton, header)
```

In `SwagBag/UI/BagsWindow.lua` (edit 2 of 3), find:

```lua
		W.DropOnSection(id)
	elseif mouseButton == "RightButton" then
```

and replace it with:

```lua
		W.DropOnSection(id)
	elseif mouseButton == "RightButton" and SB.SectionActions and SB.Adapter.ShiftDown() then
		SB.SectionActions.Open(id, header)
	elseif mouseButton == "RightButton" then
```

In `SwagBag/UI/BagsWindow.lua` (edit 3 of 3), find:

```lua
		W.DropOnSection(id)
	end
end
```

and replace it with:

```lua
		W.DropOnSection(id)
	end
end
SB.SectionHeaders.onEnter = function(id, header)
	if SB.SectionActions then
		SB.SectionActions.Hint(id, header)
	end
end
SB.SectionHeaders.onLeave = function(_, header)
	if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(header) then
		GameTooltip:Hide()
	end
end

-- The items drawn in a section now: { { bag, slot, record } } (placeholders and empty slots left out).
function W.SectionSlots(id)
	local out = {}
	local sec = W.state and W.state.sections[id]
	for i = 1, sec and sec.size or 0 do
		local c = sec.cells[i]
		local r = c and c.bag and not c.placeholder and W.records[c.bag] and W.records[c.bag][c.slot]
		if r then
			out[#out + 1] = { bag = c.bag, slot = c.slot, record = r }
		end
	end
	return out
end
```

Create `SwagBag/UI/SectionActions.lua`:

```lua
-- SwagBag section actions (week 7, user pick 6): Shift+right-click a section header in the bags window
-- for a small menu of what can be done with the whole section here and now:
--   at a bank     "Send all to bank (N)" and "Send all to warband bank (N)": each item goes into that bank
--                 (Adapter.MoveToBank gives the bank type to the call, so Blizzard's selected tab is
--                 never changed); items the warband bank does not take are left out
--   at a vendor   "Sell all (N)", after a confirmation: items a vendor pays for, never locked, in an
--                 equipment set, or held by the client; 12 at most per run (Blizzard's buyback keeps 12)
-- Nowhere else (and in Free) there is nothing to do, and one chat line says where it works. Mail is left
-- out: attaching items to a letter is not a single safe call. Moves go through the mover
-- (Engine/Mover.lua): one item each 0.2 s, out of combat only, never while an item is on the cursor or the
-- item's button is under the mouse (P5). A moved item leaves a placeholder (spec 4.3), so nothing else in
-- the bags moves. Each action answers once (P2): one chat line when it ends.
-- Why Shift+right-click: a left-click collapses (AC3.2), a right-click pins in the collapse style (AC8.3)
-- and collapses in the front style (week 6), so both are taken; Shift+right-click is free, needs no new
-- frame on every header, and a header's tooltip names it whenever an action is available.
--   SA.Entries(id) -> { { text, run } }   SA.Open(id, header)   SA.Hint(id, header)
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local SA = { WIDTH = 210, ROW = 22 }
SB.SectionActions = SA

local function atBank()
	return SB.BankWindow ~= nil and SB.BankWindow.interaction == true
end

local function atVendor()
	return SB.Vendor ~= nil and SB.Vendor.open == true
end

function SA.Available()
	return atBank() or atVendor()
end

local function item(bag, slot, r)
	local info = SB.Adapter.GetItemInfo(r.itemID)
	return { bag = bag, slot = slot, itemID = r.itemID, link = r.link, count = r.count or 1,
		price = info and info.sellPrice or 0 }
end

-- The section's items a vendor pays for and SwagBag may sell.
function SA.Sellable(id)
	local out = {}
	for _, c in ipairs(SB.BagsWindow.SectionSlots(id)) do
		local r = c.record
		local it = item(c.bag, c.slot, r)
		if not r.pending and not r.hasNoValue and not r.isLocked and it.price > 0 and not SB.Vendor.Protected(r) then
			out[#out + 1] = it
		end
	end
	return out
end

-- The section's items that bank kind takes (an unknown answer counts as yes: the mover stops if refused).
function SA.Bankable(id, kind)
	local A, out = SB.Adapter, {}
	for _, c in ipairs(SB.BagsWindow.SectionSlots(id)) do
		if not c.record.isLocked and A.AllowedInBank(c.bag, c.slot, kind) ~= false then
			out[#out + 1] = item(c.bag, c.slot, c.record)
		end
	end
	return out
end

local KIND_NAME = { bank = "SECTION_BANK", warband = "SECTION_WARBAND" }

local function send(id, kind, list)
	local name = SB.Categories.Name(id)
	local ok, why = SB.Mover.Start({ items = list, act = function(bag, slot)
		return SB.Adapter.MoveToBank(bag, slot, kind)
	end, still = atBank, done = function(result)
		local n, total = #result.moved, #list
		local line = n == 1 and L.SECTION_SENT_ONE:format(name, L[KIND_NAME[kind]])
			or L.SECTION_SENT:format(n, name, L[KIND_NAME[kind]])
		if result.why == "stuck" or result.why == "error" then
			line = line .. " " .. L.SECTION_FULL:format(L[KIND_NAME[kind]], total - n)
		elseif result.why == "closed" then
			line = line .. " " .. L.SECTION_CLOSED:format(total - n)
		elseif result.why == "combat" then
			line = line .. " " .. L.VENDOR_STOP_COMBAT:format(total - n)
		elseif result.kept > 0 then
			line = line .. " " .. L.VENDOR_KEPT_MOUSE:format(result.kept)
		end
		SB.Print(line)
	end })
	if not ok then
		SB.Print(why == "combat" and L.SECTION_COMBAT or L.MOVER_BUSY)
	end
end

-- Sell all asks first (StaticPopup), naming how many, from where, and roughly for how much.
SA.pending = nil
function SA.ConfirmSell(id, list)
	if SB.Adapter.InCombat() then -- nothing would sell: say so now rather than after a question
		SB.Print(L.SECTION_COMBAT)
		return
	end
	local copper, n = 0, math.min(#list, SB.Vendor.BUYBACK)
	for i = 1, n do
		copper = copper + list[i].price * list[i].count
	end
	SA.pending = { id = id, list = list }
	if StaticPopupDialogs and StaticPopup_Show then
		StaticPopupDialogs.SWAGBAG_SELL_ALL.text = L.SECTION_SELL_CONFIRM:format(n, SB.Categories.Name(id),
			SB.Vendor.Money(copper))
		StaticPopup_Show("SWAGBAG_SELL_ALL")
	end
end

function SA.SellConfirmed()
	local p = SA.pending
	SA.pending = nil
	if not p then
		return
	end
	if not atVendor() then
		SB.Print(L.VENDOR_NOT_OPEN)
		return
	end
	local ok, why = SB.Vendor.Sell(p.list, "section")
	if not ok then
		SB.Print(why == "combat" and L.SECTION_COMBAT or L.MOVER_BUSY)
	end
end

if StaticPopupDialogs then
	StaticPopupDialogs.SWAGBAG_SELL_ALL = {
		text = "",
		button1 = YES,
		button2 = NO,
		OnAccept = Guard("sections.sellAll", SA.SellConfirmed, "bags"),
		OnCancel = function()
			SA.pending = nil
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
end

function SA.Entries(id)
	local out = {}
	if id == SB.Categories.FREE then
		return out
	end
	if atVendor() then
		local list = SA.Sellable(id)
		if #list > 0 then
			out[#out + 1] = { text = L.SECTION_SELL_ALL:format(#list), run = function()
				SA.ConfirmSell(id, list)
			end }
		end
	end
	if atBank() then
		for _, kind in ipairs({ "bank", "warband" }) do
			local list = SA.Bankable(id, kind)
			if #list > 0 then
				out[#out + 1] = { text = L.SECTION_SEND_ALL:format(L[KIND_NAME[kind]], #list), run = function()
					send(id, kind, list)
				end }
			end
		end
	end
	return out
end

-- The menu: a plain frame (allowed in combat) with one button per entry and Cancel, beside the header.
local function menuFrame()
	if SA.menu then
		return SA.menu
	end
	local f = CreateFrame("Frame", "SwagBagSectionMenu", UIParent, "BackdropTemplate")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
	f:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
	f:Hide()
	f.buttons = {}
	table.insert(UISpecialFrames, "SwagBagSectionMenu")
	SA.menu = f
	return f
end

local function menuButton(f, i)
	local b = f.buttons[i]
	if not b then
		b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(SA.WIDTH - 12, SA.ROW - 2)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6 - (i - 1) * SA.ROW)
		b:SetScript("OnClick", Guard("sections.menu", function(self)
			f:Hide()
			if self.run then
				self.run()
			end
		end, "bags"))
		if SB.Theme then
			SB.Theme.Button(b)
		end
		f.buttons[i] = b
	end
	b:Show()
	return b
end

function SA.Open(id, header)
	local entries = SA.Entries(id)
	if #entries == 0 then
		SB.Print(SA.Available() and L.SECTION_NOTHING:format(SB.Categories.Name(id)) or L.SECTION_WHERE)
		return false
	end
	local f = menuFrame()
	for i, e in ipairs(entries) do
		local b = menuButton(f, i)
		b:SetText(e.text)
		b.run = e.run
	end
	local cancel = menuButton(f, #entries + 1)
	cancel:SetText(L.SECTION_CANCEL)
	cancel.run = nil
	for i = #entries + 2, #f.buttons do
		f.buttons[i]:Hide()
	end
	f:SetSize(SA.WIDTH, 12 + (#entries + 1) * SA.ROW)
	f:ClearAllPoints()
	if header then
		f:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 24, 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	f:Show()
	return true
end

-- A header's tooltip names the gesture while an action is available (P1: easy to find).
function SA.Hint(id, header)
	if not (GameTooltip and SA.Available()) or id == SB.Categories.FREE then
		return
	end
	GameTooltip:SetOwner(header, "ANCHOR_TOP")
	GameTooltip:SetText(SB.Categories.Name(id))
	GameTooltip:AddLine(atVendor() and L.SECTION_HINT_VENDOR or L.SECTION_HINT_BANK, 1, 1, 1, true)
	GameTooltip:Show()
end

local function hideMenu()
	if SA.menu then
		SA.menu:Hide()
	end
end
SB.On("SB_BAGS_CLOSED", hideMenu, "bags")
SB.On("MERCHANT_CLOSED", hideMenu, "bags")
SB.On("BANKFRAME_CLOSED", hideMenu, "bags")
```

In `SwagBag/UI/SectionHeaders.lua` (edit 1 of 2), find:

```lua
--   Headers.onClick(sectionId, mouseButton)  left- or right-click ("LeftButton" | "RightButton"):
--                               collapse/expand, peek or pin (focus modes), or drop the cursor item
```

and replace it with:

```lua
--   Headers.onClick(sectionId, mouseButton, header)  left- or right-click ("LeftButton" | "RightButton"):
--                               collapse/expand, peek or pin (focus modes), drop the cursor item, or
--                               (Shift+right-click, week 7) the section actions menu beside `header`
--   Headers.onEnter(sectionId, header) / Headers.onLeave(sectionId, header)   optional: a hint tooltip
```

In `SwagBag/UI/SectionHeaders.lua` (edit 2 of 2), find:

```lua
				o.onClick(self.sectionId, mouseButton)
```

and replace it with:

```lua
				o.onClick(self.sectionId, mouseButton, self)
			end
		end)
	end)
	h:SetScript("OnEnter", function(self)
		local o = owners[self]
		SB.ErrorTrap.Run("header.enter", o and o.window or "bags", function()
			o = o or H
			if o.onEnter then
				o.onEnter(self.sectionId, self)
			end
		end)
	end)
	h:SetScript("OnLeave", function(self)
		local o = owners[self]
		SB.ErrorTrap.Run("header.leave", o and o.window or "bags", function()
			o = o or H
			if o.onLeave then
				o.onLeave(self.sectionId, self)
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1334 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (69 files)`, `1334 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/BagsWindow.lua \
	SwagBag/UI/SectionActions.lua \
	SwagBag/UI/SectionHeaders.lua \
	spec/bagswindow_sections_spec.lua \
	spec/mock_adapter.lua \
	spec/sectionactions_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 6: section actions (Shift+right-click: Send all to bank / warband bank, Sell all with a confirmation)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 7: The gold glow at the bank on items worth money

User pick 7. `Prices.WorthThreshold(values, mode, gold, percent)` (pure) gives the stack value from which an item glows: `fixed` gold × 10000, or the value of the last stack in the top percent; nil for off or nothing valued (D22). `UI/Overlays.lua` works the line out once per bank visit (`BANKFRAME_OPENED`, debounced; again on a price change, a setting change or a bags layout during the visit), over the bags and both banks, and tints the same glow region **gold**, which wins over green (D9). `BANKFRAME_CLOSED` ends it. `/swagbag worth [<gold>|top <percent>|off]` and a row on Settings > Bank & guild (100g first, 500g, 1000g, Your top N%, Off).

**Files:**
- Modify: `SwagBag/Engine/Prices.lua` (`WorthThreshold`), `SwagBag/UI/Overlays.lua` (`IsWorth`, `RefreshWorth`, the events, `/swagbag worth`), `SwagBag/UI/SettingsPages.lua` (the row), `SwagBag/Core/Config.lua` (`prices.worth`, `worthGold`, `worthTop`), `SwagBag/Locale/enUS.lua`
- Test: `spec/prices_spec.lua`, `spec/overlays_spec.lua`, `spec/settings_spec.lua`

**Interfaces:**
- Consumes: `Prices.Value/Bound` (secret and missing prices are nil there), `SB.BankWindow.interaction/IsOpen/view.ForEachSlot`, `SB.BagsWindow.IsOpen/ForEachSlot`, the glow region (Task 3).
- Produces: `SB.Prices.WorthThreshold`; `Ov.worthMin`, `Ov.IsWorth(record)`, `Ov.RefreshWorth()`, `Ov.WorthState()`, `Ov.WORTH_TINT`, `Ov.WORTH_DELAY`; `L.WORTH_*`, `L.SET_WORTH*`.

- [ ] **Step 1: Write the failing tests**

In `spec/overlays_spec.lua`, find:

```lua
		assert.falsy(off.lock.shown)
```

and replace it with:

```lua
		assert.falsy(off.lock.shown)
	end)

	-- Week 7 (user pick 7). Mutations: Ov.IsWorth ignores Ov.worthMin (always nil: no glow); or the
	-- BANKFRAME_CLOSED handler keeps Ov.worthMin.
	it("at the bank items worth 100g or more glow gold (their stack value); closing the bank ends it", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Prices.lua")
		A.items[Fixtures.HEALING_POTION].sellPrice = 300000 -- 30g each, 5 in the stack: 150g
		A.items[Fixtures.FLASK].sellPrice = 400000 -- 40g each, 2: 80g
		local drawn = {}
		SB.BankWindow = { interaction = true, IsOpen = function() return false end }
		SB.BagsWindow = { IsOpen = function() return true end, RefreshTitle = function() end, ForEachSlot = function(fn)
			for slot = 1, 2 do
				drawn[slot] = drawn[slot] or Fake.New("ItemButton")
				fn(drawn[slot], SB.Items.Describe(0, slot), 0, slot)
			end
		end }
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		A.Advance(Ov.WORTH_DELAY)
		assert.equal(1000000, Ov.worthMin)
		assert.same({ true, false }, { Ov.regions[drawn[1]].glow.shown, Ov.regions[drawn[2]].glow.shown })
		assert.same({ 1, 0.82, 0 }, Ov.regions[drawn[1]].glow.calls.SetVertexColor)
		SB.BankWindow.interaction = false
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.falsy(Ov.regions[drawn[1]].glow.shown)
	end)

	-- Week 7. Mutation: in Overlays.Apply, the tint `worth and Ov.WORTH_TINT or Ov.LEARN_TINT` ->
	-- `d.learn and Ov.LEARN_TINT or Ov.WORTH_TINT` (green would win at the bank).
	it("gold at the bank wins over green; a price the game will not give (secret, missing) never glows", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Prices.lua")
		SB.Collections = { Learn = function() return "learn" end }
		A.items[Fixtures.HEALING_POTION].sellPrice = 300000
		Ov.worthMin = 1000000
		local _, potion = draw(0, 1)
		assert.same({ true, { 1, 0.82, 0 } }, { potion.glow.shown, potion.glow.calls.SetVertexColor })
		local _, flask = draw(0, 2)
		assert.same({ true, { 0.35, 1, 0.35 } }, { flask.glow.shown, flask.glow.calls.SetVertexColor }, "no price: green")
		Ov.worthMin = nil
		local _, after = draw(0, 1)
		assert.same({ 0.35, 1, 0.35 }, after.glow.calls.SetVertexColor)
	end)

	-- P2. Mutation: /swagbag worth top accepts 0 (no item would ever be the top 0%).
	it("/swagbag worth shows, sets a gold amount, a top percent or off; wrong forms and read-only refuse", function()
		SB.Slash.Dispatch("worth")
		SB.Slash.Dispatch("worth 250")
		SB.Slash.Dispatch("worth top 5")
		SB.Slash.Dispatch("worth top 0")
		SB.Slash.Dispatch("worth lots")
		SB.Slash.Dispatch("worth off")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("worth 100")
		local L = SB.L
		assert.same({ L.WORTH_STATE:format("items worth 100g or more a stack"), "Gold glow at the bank: items worth 250g or"
			.. " more a stack.", "Gold glow at the bank: your most valuable 5% of items.", L.WORTH_USAGE, L.WORTH_USAGE,
			"Gold glow at the bank: off.", L.SETTINGS_READONLY }, A.Lines())
		assert.same({ "off", 250, 5 }, { SB.Config.Get("prices.worth"), SB.Config.Get("prices.worthGold"),
			SB.Config.Get("prices.worthTop") })
```

In `spec/prices_spec.lua`, find:

```lua
			{ P.Money(12), P.Money(3550), P.Money(12400000), P.Money(1234567890), P.Money(10000), P.Money(0) })
```

and replace it with:

```lua
			{ P.Money(12), P.Money(3550), P.Money(12400000), P.Money(1234567890), P.Money(10000), P.Money(0) })
	end)

	-- Week 7 (user pick 7). Mutation: in WorthThreshold, math.ceil -> math.floor (top 10% of 5 values: none).
	it("worth-money line: a fixed gold amount, or the top percent of the valued stacks; off or nothing valued: none", function()
		assert.equal(1000000, P.WorthThreshold({}, "fixed", 100, 10))
		assert.equal(60, P.WorthThreshold({ 10, 20, 30, 40, 50, 60, 70, 0 }, "top", 100, 20), "20% of 7 rounds up to 2")
		assert.equal(500, P.WorthThreshold({ 5, 500, 50, 0, 1 }, "top", 100, 10), "at least one item")
		assert.is_nil(P.WorthThreshold({ 0, 0 }, "top", 100, 10))
		assert.is_nil(P.WorthThreshold({ 10 }, "off", 100, 10))
```

In `spec/settings_spec.lua`, find:

```lua
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
```

and replace it with:

```lua
	end)

	-- Week 7 (user pick 7), P1. Mutation: in the worth row's apply, run "worth top 10" whatever the setting.
	it("bank page: the gold glow row, 100g first and selected; each choice runs /swagbag worth", function()
		SB.Slash.Register("worth", "test", function(arg)
			ran[#ran + 1] = "worth " .. arg
			return "ran worth " .. arg
		end)
		SB.Config.Set("prices.worthTop", 15)
		SW.Show("bank")
		assert.truthy(SW.selected[button("100g or more")])
		click("500g or more")
		click("Your top 15%")
		assert.same({ "worth 500", "worth top 15" }, ran)
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1334 passed, 5 failed`. The failures, exactly:

- `spec/overlays_spec.lua :: Overlays (spec F9) > at the bank items worth 100g or more glow gold (their stack value); closing the bank ends it`
- `spec/overlays_spec.lua :: Overlays (spec F9) > gold at the bank wins over green; a price the game will not give (secret, missing) never glows`
- `spec/overlays_spec.lua :: Overlays (spec F9) > /swagbag worth shows, sets a gold amount, a top percent or off; wrong forms and read-only refuse`
- `spec/prices_spec.lua :: Prices (spec F10, 3.3) > worth-money line: a fixed gold amount, or the top percent of the valued stacks; off or nothing valued: none`
- `spec/settings_spec.lua :: Settings window > bank page: the gold glow row, 100g first and selected; each choice runs /swagbag worth`

Every new test fails; nothing passes early.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "at the bank items worth 100g or more glow gold (their stack value); closing the bank ends it": in `SwagBag/UI/Overlays.lua`, `return Ov.worthMin ~= nil and stackValue(record) >= Ov.worthMin and stackValue(record) > 0` → `return false`.
- "at the bank items worth 100g or more glow gold (their stack value); closing the bank ends it": in `SwagBag/UI/Overlays.lua`, `SB.On("BANKFRAME_CLOSED", function() ⏎ Ov.worthMin = nil` → `SB.On("BANKFRAME_CLOSED", function()`.
- "/swagbag worth shows, sets a gold amount, a top percent or off; wrong forms and read-only refuse": in `SwagBag/UI/Overlays.lua`, `tonumber(b) >= 1 and tonumber(b) <= 50` → `tonumber(b) >= 0 and tonumber(b) <= 50`.
- "bank page: the gold glow row, 100g first and selected; each choice runs /swagbag worth": in `SwagBag/UI/SettingsPages.lua`, `return run("worth top " .. SB.Config.Get("prices.worthTop"))` → `return run("worth top 10")`.
- "worth-money line: a fixed gold amount, or the top percent of the valued stacks; off or nothing valued: none": in `SwagBag/Engine/Prices.lua`, `return list[math.max(1, math.ceil(#list * (tonumber(percent) or 0) / 100))]` → `return list[math.max(1, math.floor(#list * (tonumber(percent) or 0) / 100))]`.
- "gold at the bank wins over green; a price the game will not give (secret, missing) never glows": in `SwagBag/UI/Overlays.lua`, `unpack(worth and Ov.WORTH_TINT or Ov.LEARN_TINT)` → `unpack(d.learn and Ov.LEARN_TINT or Ov.WORTH_TINT)`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Config.lua`, find:

```lua
		prices = { headerTotals = true },
```

and replace it with:

```lua
		-- worth (week 7, user pick 7; spec v1.1 "worth-money highlight"): while the bank is open, a gold glow
		-- on items worth "fixed" (worthGold gold or more a stack, default 100) | "top" (your most valuable
		-- worthTop percent) | "off". Prices: Auctionator, else the vendor (Engine/Prices.lua).
		prices = { headerTotals = true, worth = "fixed", worthGold = 100, worthTop = 10 },
```

In `SwagBag/Engine/Prices.lua` (edit 1 of 2), find:

```lua
--   Prices.Money(copper) -> "1,240g" | "35s" | "12c"
```

and replace it with:

```lua
--   Prices.Money(copper) -> "1,240g" | "35s" | "12c"
--   Prices.WorthThreshold(values, mode, gold, percent) -> copper | nil   the worth-money glow's line (week 7,
--                                      user pick 7): "fixed" gold x 10000; "top" the stack value of the
--                                      last item in the top `percent` of `values` (stack values above 0);
--                                      nil for "off" or when nothing has a value
```

In `SwagBag/Engine/Prices.lua` (edit 2 of 2), find:

```lua
end

-- The built-in fallback: what a vendor pays.
```

and replace it with:

```lua
end

function P.WorthThreshold(values, mode, gold, percent)
	if mode == "fixed" then
		return (tonumber(gold) or 0) * 10000
	elseif mode ~= "top" then
		return nil
	end
	local list = {}
	for _, v in ipairs(values) do
		if v > 0 then
			list[#list + 1] = v
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, function(a, b)
		return a > b
	end)
	return list[math.max(1, math.ceil(#list * (tonumber(percent) or 0) / 100))]
end

-- The built-in fallback: what a vendor pays.
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SECTION_HINT_BANK = "Shift+right-click: Send all to the bank or the warband bank"
```

and replace it with:

```lua
L.SECTION_HINT_BANK = "Shift+right-click: Send all to the bank or the warband bank"

-- Worth money at the bank (week 7, user pick 7): UI/Overlays.lua
L.HELP_WORTH = "worth [<gold>|top <percent>|off]: the gold glow at the bank on items worth money"
L.WORTH_FIXED = "items worth %dg or more a stack"
L.WORTH_TOP = "your most valuable %d%% of items"
L.WORTH_OFF = "off"
L.WORTH_STATE = "Gold glow at the bank: %s (Auctionator prices, else what a vendor pays). Type /swagbag worth <gold>,"
	.. " worth top <percent>, or worth off."
L.WORTH_SET = "Gold glow at the bank: %s."
L.WORTH_USAGE = "Use /swagbag worth, worth <gold> (1 to 10000000), worth top <percent> (1 to 50), or worth off."
L.SET_WORTH = "Gold glow at the bank on items worth"
L.SET_WORTH_GOLD = "%dg or more"
L.SET_WORTH_TOP = "Your top %d%%"
L.SET_WORTH_TIP = "While a bank is open, items worth that much (a whole stack, by Auctionator's price, else the"
	.. " vendor's) glow gold in your bags and the bank. Your top: the most valuable part of what you carry and"
	.. " store. /swagbag worth sets any amount or percent."
```

In `SwagBag/UI/Overlays.lua` (edit 1 of 5), find:

```lua
--   top middle    a small padlock on an item the user locked      (overlays.lock, week 7)
```

and replace it with:

```lua
--   top middle    a small padlock on an item the user locked      (overlays.lock, week 7)
--   whole button  a gold glow while the bank is open on items worth money (prices.worth, week 7;
--                 at the bank it wins over the green glow). /swagbag worth sets it.
```

In `SwagBag/UI/Overlays.lua` (edit 2 of 5), find:

```lua
	GLOW_ATLAS = "bags-glow-white", LEARN_TINT = { 0.35, 1, 0.35 },
```

and replace it with:

```lua
	GLOW_ATLAS = "bags-glow-white", LEARN_TINT = { 0.35, 1, 0.35 }, WORTH_TINT = { 1, 0.82, 0 }, WORTH_DELAY = 0.1,
```

In `SwagBag/UI/Overlays.lua` (edit 3 of 5), find:

```lua
	-- One glow per button (week 7): green for an item to open or learn.
	local glow = on("learn") and d.learn ~= nil
	if glow then
		r.glow:SetVertexColor(unpack(Ov.LEARN_TINT))
```

and replace it with:

```lua
	-- One glow per button (week 7): gold at the bank for an item worth money, else green for an item to
	-- open or learn.
	local worth = Ov.IsWorth(record)
	local glow = worth or (on("learn") and d.learn ~= nil)
	if glow then
		r.glow:SetVertexColor(unpack(worth and Ov.WORTH_TINT or Ov.LEARN_TINT))
```

In `SwagBag/UI/Overlays.lua` (edit 4 of 5), find:

```lua
end

-- Re-draw the buttons of every open window (equipment or settings changed).
```

and replace it with:

```lua
end

---------------------------------------------------------------------------
-- Worth money at the bank (week 7, user pick 7): Ov.worthMin is the stack value (copper) from which an
-- item glows gold; nil while the bank is closed or the glow is off. Worked out once when the bank opens
-- (and again when prices, the setting or the bags' layout change during the visit), never per button.
-- A missing or secret price is no price (Engine/Prices.lua): such an item never glows.
---------------------------------------------------------------------------
local function stackValue(record)
	if not record or record.pending or record.offline then
		return 0
	end
	local P = SB.Prices
	local v = P and P.Value(record.link, record.itemID, P.Bound(record))
	return (v or 0) * (record.count or 1)
end

function Ov.IsWorth(record)
	return Ov.worthMin ~= nil and stackValue(record) >= Ov.worthMin and stackValue(record) > 0
end

local function atBank()
	return SB.BankWindow ~= nil and SB.BankWindow.interaction == true
end

-- Work the threshold out over the bags and both banks, then re-draw.
function Ov.RefreshWorth()
	Ov.worthMin = nil
	if atBank() and SB.Prices then
		local values = {}
		local function collect(forEach)
			forEach(function(_, record)
				values[#values + 1] = stackValue(record)
			end)
		end
		local bags, bank = SB.BagsWindow, SB.BankWindow
		if bags and bags.IsOpen() then
			collect(bags.ForEachSlot)
		end
		if bank and bank.IsOpen() then
			collect(bank.view.ForEachSlot)
		end
		local C = SB.Config
		Ov.worthMin = SB.Prices.WorthThreshold(values, C.Get("prices.worth"), C.Get("prices.worthGold"),
			C.Get("prices.worthTop"))
	end
	Ov.RefreshAll()
end

local function worthSoon()
	SB.Debounce("overlays.worth", Ov.WORTH_DELAY, Ov.RefreshWorth, "none")
end
SB.On("BANKFRAME_OPENED", worthSoon, "none")
SB.On("BANKFRAME_CLOSED", function()
	Ov.worthMin = nil
	Ov.RefreshAll()
end, "none")
SB.On("SB_PRICES_CHANGED", function()
	if atBank() then
		worthSoon()
	end
end, "none")
SB.On("SB_BAGS_LAYOUT", function()
	if atBank() then
		worthSoon()
	end
end, "none")

-- Re-draw the buttons of every open window (equipment or settings changed).
```

In `SwagBag/UI/Overlays.lua` (edit 5 of 5), find:

```lua
	return line
end)
```

and replace it with:

```lua
	return line
end)

-- /swagbag worth                   what glows gold at the bank, and how to change it
-- /swagbag worth <gold>            items worth that much gold or more a stack (1 to 10,000,000)
-- /swagbag worth top <percent>     your most valuable percent of items (1 to 50)
-- /swagbag worth off               no gold glow
local function worthState()
	local C = SB.Config
	local mode = C.Get("prices.worth")
	if mode == "fixed" then
		return L.WORTH_FIXED:format(C.Get("prices.worthGold"))
	elseif mode == "top" then
		return L.WORTH_TOP:format(C.Get("prices.worthTop"))
	end
	return L.WORTH_OFF
end
Ov.WorthState = worthState

SB.Slash.Register("worth", L.HELP_WORTH, function(arg)
	local a, b = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	local C = SB.Config
	if a == "" then
		return L.WORTH_STATE:format(worthState())
	end
	local ok
	if a == "off" and b == "" then
		ok = C.Set("prices.worth", "off")
	elseif a == "top" and tonumber(b) and tonumber(b) >= 1 and tonumber(b) <= 50 then
		local n = math.floor(tonumber(b))
		ok = C.Set("prices.worthTop", n) and C.Set("prices.worth", "top")
	elseif b == "" and tonumber(a) and tonumber(a) >= 1 and tonumber(a) <= 10000000 then
		local n = math.floor(tonumber(a))
		ok = C.Set("prices.worthGold", n) and C.Set("prices.worth", "fixed")
	else
		return L.WORTH_USAGE
	end
	if not ok then
		return L.SETTINGS_READONLY
	end
	if atBank() then
		Ov.RefreshWorth()
	end
	return L.WORTH_SET:format(worthState())
end)
```

In `SwagBag/UI/SettingsPages.lua`, find:

```lua
			end },
		{ kind = "note", label = L.SET_BANK_NOTE },
```

and replace it with:

```lua
			end },
		-- Week 7 (user pick 7): the gold glow at the bank; every click runs /swagbag worth.
		{ kind = "choice", label = L.SET_WORTH, tip = L.SET_WORTH_TIP, width = 90, get = function()
			local mode = SB.Config.Get("prices.worth")
			if mode == "fixed" then
				return SB.Config.Get("prices.worthGold")
			end
			return mode
		end, choices = { { value = 100, text = L.SET_WORTH_GOLD:format(100) },
			{ value = 500, text = L.SET_WORTH_GOLD:format(500) }, { value = 1000, text = L.SET_WORTH_GOLD:format(1000) },
			{ value = "top", text = L.SET_WORTH_TOP:format(SB.Config.Get("prices.worthTop")) },
			{ value = "off", text = L.SET_OFF } },
		apply = function(v)
			if v == "top" then
				return run("worth top " .. SB.Config.Get("prices.worthTop"))
			end
			return run("worth " .. v)
		end },
		{ kind = "note", label = L.SET_BANK_NOTE },
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1339 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (69 files)`, `1339 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Config.lua \
	SwagBag/Engine/Prices.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/Overlays.lua \
	SwagBag/UI/SettingsPages.lua \
	spec/overlays_spec.lua \
	spec/prices_spec.lua \
	spec/settings_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 7: gold glow at the bank on items worth money (100g a stack, or your top 10%); /swagbag worth

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 8: The uncollected star: appearances, and toys, mounts and pets not learned

User pick 9. `A.AppearanceKnown(link)` asks `C_TransmogCollection` (true / false; nil with no appearance, one the account cannot collect, or a secret). `Collections.Uncollected(record)` returns `"appearance"` for gear whose look is missing (cached per link) and `"toy"`, `"mount"`, `"pet"` from the Task 3 answers (shared through one `teaches` helper; decor stays with the green glow). `TRANSMOG_COLLECTION_UPDATED` drops the answers and re-draws. A purple `*` at the right middle of the button (a font string, D23), shown on gear always, and on toys, mounts and pets only while the green glow is off (D9). The keyword `uncollected`. Switch `overlays.uncollected`, on.

**Files:**
- Modify: `SwagBag/Core/Adapter.lua` (`AppearanceKnown`; three optional checks), `.luacheckrc` (`C_TransmogCollection`), `SwagBag/Engine/Collections.lua` (`teaches`, `Uncollected`, the event), `SwagBag/Engine/Keywords.lua` (`uncollected`), `SwagBag/Engine/OverlayData.lua` (`uncollected`), `SwagBag/UI/Overlays.lua` (the star), `SwagBag/UI/SettingsPages.lua` (the row), `SwagBag/Core/Config.lua` (`overlays.uncollected`), `SwagBag/Locale/enUS.lua`
- Test: `spec/collections_spec.lua`, `spec/adapter_spec.lua`, `spec/overlays_spec.lua`, `spec/mock_adapter.lua` (`m.collected.looks`, `AppearanceKnown`)

**Interfaces:**
- Consumes: Task 3's cache and Adapter answers, `isGear`, the glow and `on("learn")`.
- Produces: `A.AppearanceKnown(link)`; `SB.Collections.Uncollected(record) -> "appearance" | "toy" | "mount" | "pet" | nil`; `OverlayData.For(...).uncollected` with `ctx.uncollected`; the overlay region `star`, `Ov.STAR`, `Ov.STAR_SIZE`, `Ov.STAR_COLOR`; `L.SET_OV_UNCOLLECTED`.

- [ ] **Step 1: Write the failing tests**

In `spec/adapter_spec.lua` (edit 1 of 3), find:

```lua
-- luacheck: globals PlayerHasToy C_MountJournal C_PetJournal C_HousingCatalog
```

and replace it with:

```lua
-- luacheck: globals PlayerHasToy C_MountJournal C_PetJournal C_HousingCatalog C_TransmogCollection
```

In `spec/adapter_spec.lua` (edit 2 of 3), find:

```lua
		PlayerHasToy, C_MountJournal, C_PetJournal, C_HousingCatalog, issecretvalue = nil, nil, nil, nil, nil
```

and replace it with:

```lua
		PlayerHasToy, C_MountJournal, C_PetJournal, C_HousingCatalog, issecretvalue = nil, nil, nil, nil, nil
		C_TransmogCollection = nil
```

In `spec/adapter_spec.lua` (edit 3 of 3), find:

```lua
		assert.is_nil(A.DecorKnown(12), "not decor")
	end)
end)
```

and replace it with:

```lua
		assert.is_nil(A.DecorKnown(12), "not decor")
	end)

	-- Week 7 (user pick 9). Mutation: in A.AppearanceKnown, drop the AccountCanCollectSource check.
	it("appearances: collected or not; nil with no source, one the account cannot collect, or a secret", function()
		assert.is_nil(A.AppearanceKnown("item:1"))
		C_TransmogCollection = {
			GetItemInfo = function(link) return 7, ({ ["item:1"] = 101, ["item:2"] = 102, ["item:3"] = 103 })[link] end,
			AccountCanCollectSource = function(source) return true, source ~= 103 end,
			PlayerHasTransmogItemModifiedAppearance = function(source) return source == 101 end,
		}
		assert.same({ true, false }, { A.AppearanceKnown("item:1"), A.AppearanceKnown("item:2") })
		assert.is_nil(A.AppearanceKnown("item:3"), "the account cannot collect it")
		assert.is_nil(A.AppearanceKnown("item:4"), "no appearance (a ring)")
		issecretvalue = function(v) return v == false end
		assert.is_nil(A.AppearanceKnown("item:2"), "a secret answer")
	end)
end)
```

In `spec/collections_spec.lua`, find:

```lua
	end)

	-- Mutations: drop the Inventory listener's Invalidate; or register no NEW_TOY_ADDED handler.
```

and replace it with:

```lua
	end)

	-- Week 7 (user pick 9). Mutations: in Coll.Uncollected, `== false` -> `~= true` for looks (a silent
	-- client would star every piece); or drop TRANSMOG_COLLECTION_UPDATED from the events.
	it("Uncollected: gear whose look is missing, toys, mounts and pets not yet collected; cached per link", function()
		local link = "item:225001::upgradable" -- the fixture's BoE ring, slot 3
		A.collected.looks[link] = false
		A.collected.toys[Fixtures.TOY] = false
		A.collected.mounts[500002] = true
		local function kind(slot)
			return Coll.Uncollected(SB.Items.Describe(0, slot))
		end
		assert.same({ "appearance", "toy" }, { kind(3), kind(12) })
		assert.is_nil(kind(8), "a mount already collected")
		assert.is_nil(kind(4), "the client gives no answer for the helm's look: no star")
		assert.is_nil(kind(10), "decor: the learn glow only")
		local calls = A.collectionCalls
		kind(3)
		assert.equal(calls, A.collectionCalls, "cached")
		A.collected.looks[link] = true
		SB.Overlays = { RefreshAll = function() end }
		SB.eventFrame:Fire("TRANSMOG_COLLECTION_UPDATED")
		assert.is_nil(kind(3), "collected now")
	end)

	-- Week 7: the `uncollected` keyword (spec 7.3). Mutation: register it as always false.
	it("the search keyword `uncollected` finds the same items", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Query/Lexer.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/Query/Parser.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/Query/Query.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/Keywords.lua")
		A.collected.toys[Fixtures.TOY] = false
		local q = SB.Query.Compile("uncollected")
		assert.same({ true, false }, { SB.Query.Eval(q, SB.Items.Describe(0, 12)), SB.Query.Eval(q, SB.Items.Describe(0, 1)) })
	end)

	-- Mutations: drop the Inventory listener's Invalidate; or register no NEW_TOY_ADDED handler.
```

In `spec/mock_adapter.lua`, find:

```lua
	end

	function m.DecorKnown(itemID)
```

and replace it with:

```lua
	end

	-- Appearances: m.collected.looks[link] = true | false (no entry: no appearance, or the client cannot say).
	m.collected.looks = {}
	function m.AppearanceKnown(link)
		m.collectionCalls = m.collectionCalls + 1
		return m.collected.looks[link]
	end

	function m.DecorKnown(itemID)
```

In `spec/overlays_spec.lua` (edit 1 of 2), find:

```lua
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, learn on, lock on, pawn off, title on",
```

and replace it with:

```lua
			"Overlays: ilvl off, track on, upgrade on, keystone on, junk on, bind off, learn on, lock on, uncollected on, pawn"
				.. " off, title on",
```

In `spec/overlays_spec.lua` (edit 2 of 2), find:

```lua
			SB.Config.Get("prices.worthTop") })
```

and replace it with:

```lua
			SB.Config.Get("prices.worthTop") })
	end)

	-- Week 7 (user pick 9). Mutations: in Overlays.Apply, drop `not (on("learn") and d.learn ~= nil)` (a toy
	-- would show the star and the glow); or `show(r.star, on("uncollected") and star)` -> `show(r.star, star)`.
	it("a star on gear whose look is not collected; on a toy, mount or pet only while the learn glow is off", function()
		SB.Collections = { Learn = function(r)
			return r.slot == 2 and "learn" or nil
		end, Uncollected = function(r)
			return (r.slot == 3 and "appearance") or (r.slot == 2 and "toy") or nil
		end }
		local _, ring = draw(0, 3)
		local _, toy = draw(0, 2)
		local _, potion = draw(0, 1)
		assert.same({ true, false, false }, { ring.star.shown, toy.star.shown, potion.star.shown })
		assert.same({ "RIGHT", "*" }, { ring.star.points[1][1], ring.star.text })
		SB.Slash.Dispatch("overlays learn off")
		local _, toyNoGlow = draw(0, 2)
		assert.truthy(toyNoGlow.star.shown, "the glow is off: the star says it instead")
		SB.Slash.Dispatch("overlays uncollected off")
		local _, off = draw(0, 3)
		assert.falsy(off.star.shown)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1338 passed, 5 failed`. The failures, exactly:

- `spec/adapter_spec.lua :: Adapter collections (week 7) > appearances: collected or not; nil with no source, one the account cannot collect, or a secret`
- `spec/collections_spec.lua :: Collections (week 7) > Uncollected: gear whose look is missing, toys, mounts and pets not yet collected; cached per link`
- `spec/collections_spec.lua :: Collections (week 7) > the search keyword `uncollected` finds the same items`
- `spec/overlays_spec.lua :: Overlays (spec F9) > each overlay has its own switch; /swagbag overlays lists and switches them`
- `spec/overlays_spec.lua :: Overlays (spec F9) > a star on gear whose look is not collected; on a toy, mount or pet only while the learn glow is off`

`Overlays > each overlay has its own switch` fails only because its list now names `uncollected`.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "Uncollected: gear whose look is missing, toys, mounts and pets not yet collected; cached per link": in `SwagBag/Engine/Collections.lua`, `return SB.Adapter.AppearanceKnown(link) ⏎ end) == false then` → `return SB.Adapter.AppearanceKnown(link) ⏎ end) ~= true then`.
- "Uncollected: gear whose look is missing, toys, mounts and pets not yet collected; cached per link": in `SwagBag/Engine/Collections.lua`, `, "TRANSMOG_COLLECTION_UPDATED" }) do` → `}) do`.
- "the search keyword `uncollected` finds the same items": in `SwagBag/Engine/Keywords.lua`, `return SB.Collections ~= nil and SB.Collections.Uncollected(r) ~= nil` → `return false`.
- "a star on gear whose look is not collected; on a toy, mount or pet only while the learn glow is off": in `SwagBag/UI/Overlays.lua`, `or (d.uncollected ~= nil and not (on("learn") and d.learn ~= nil))` → `or d.uncollected ~= nil`.
- "a star on gear whose look is not collected; on a toy, mount or pet only while the learn glow is off": in `SwagBag/UI/Overlays.lua`, `show(r.star, on("uncollected") and star)` → `show(r.star, star)`.
- "appearances: collected or not; nil with no source, one the account cannot collect, or a secret": in `SwagBag/Core/Adapter.lua`, `if not okC or isSecret(canCollect) or canCollect ~= true then ⏎ return nil ⏎ end` → `∅`.

- [ ] **Step 3: Write the code**

In `.luacheckrc`, find:

```lua
	"C_MountJournal", "C_PetJournal", "C_HousingCatalog",
```

and replace it with:

```lua
	"C_MountJournal", "C_PetJournal", "C_HousingCatalog", "C_TransmogCollection",
```

In `SwagBag/Core/Adapter.lua` (edit 1 of 2), find:

```lua
	return owned > 0
```

and replace it with:

```lua
	return owned > 0
end

-- Whether the account has collected an item's appearance (week 7, user pick 9): true / false, or nil
-- when the item has no appearance, the account cannot collect it, or the client cannot say. Read from
-- C_TransmogCollection only (no armor-type rule of SwagBag's own: 12.2.5 lifts those restrictions).
function A.AppearanceKnown(link)
	local T = C_TransmogCollection
	if type(link) ~= "string" or isSecret(link) or not (T and T.GetItemInfo and T.PlayerHasTransmogItemModifiedAppearance) then
		return nil
	end
	local ok, _, sourceID = pcall(T.GetItemInfo, link)
	if not ok or type(sourceID) ~= "number" or isSecret(sourceID) then
		return nil
	end
	if T.AccountCanCollectSource then
		local okC, _, canCollect = pcall(T.AccountCanCollectSource, sourceID)
		if not okC or isSecret(canCollect) or canCollect ~= true then
			return nil
		end
	end
	return known(pcall(T.PlayerHasTransmogItemModifiedAppearance, sourceID))
```

In `SwagBag/Core/Adapter.lua` (edit 2 of 2), find:

```lua
	{ path = "C_HousingCatalog.GetCatalogEntryInfoByItem", window = "bags", required = false },
```

and replace it with:

```lua
	{ path = "C_HousingCatalog.GetCatalogEntryInfoByItem", window = "bags", required = false },
	{ path = "C_TransmogCollection.GetItemInfo", window = "bags", required = false },
	{ path = "C_TransmogCollection.AccountCanCollectSource", window = "bags", required = false },
	{ path = "C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance", window = "bags", required = false },
```

In `SwagBag/Core/Config.lua`, find:

```lua
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = false,
			learn = true, lock = true, usePawn = false },
```

and replace it with:

```lua
		-- uncollected (week 7): a star on gear whose look is not collected, and on new toys, mounts, pets.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = false,
			learn = true, lock = true, uncollected = true, usePawn = false },
```

In `SwagBag/Engine/Collections.lua` (edit 1 of 4), find:

```lua
--             knowledge item (Engine/Crests.lua `knowledge`)
```

and replace it with:

```lua
--             knowledge item (Engine/Crests.lua `knowledge`)
--   Collections.Uncollected(record) -> "appearance" | "toy" | "mount" | "pet" | nil   (user pick 9)
--     appearance  gear whose look the account has not collected (C_TransmogCollection)
--     toy / mount / pet   an item that teaches one the account does not have yet
```

In `SwagBag/Engine/Collections.lua` (edit 2 of 4), find:

```lua
end

function Coll.Learn(r)
```

and replace it with:

```lua
end

local function teaches(r)
	local A = SB.Adapter
	local C, MS = A.ITEM_CLASS, A.MISC_SUB
	local id = r.itemID
	if r.isToy then
		return "toy", cached("toy:" .. id, function()
			return A.ToyKnown(id)
		end)
	elseif r.classID == C.Miscellaneous and r.subclassID == MS.Mount then
		return "mount", cached("mount:" .. id, function()
			return A.MountKnown(id)
		end)
	elseif r.isCagedPet or r.classID == C.Battlepet or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet) then
		local species = type(r.link) == "string" and r.link:match("battlepet:(%d+)")
		return "pet", cached("pet:" .. (species and ("s" .. species) or id), function()
			return A.PetKnown(id, r.link)
		end)
	elseif r.classID == C.Housing then
		return "decor", cached("decor:" .. id, function()
			return A.DecorKnown(id)
		end)
	end
	return nil, nil
end

function Coll.Uncollected(r)
	if not r or r.offline or r.pending then
		return nil
	end
	if isGear(r) then
		local link = r.link
		if type(link) == "string" and cached("look:" .. link, function()
			return SB.Adapter.AppearanceKnown(link)
		end) == false then
			return "appearance"
		end
		return nil
	end
	local kind, collected = teaches(r)
	if collected == false and kind ~= "decor" then
		return kind
	end
	return nil
end

function Coll.Learn(r)
```

In `SwagBag/Engine/Collections.lua` (edit 3 of 4), find:

```lua
	local A = SB.Adapter
	local C, MS = A.ITEM_CLASS, A.MISC_SUB
	local id, missing = r.itemID, nil
	if r.isToy then
		missing = cached("toy:" .. id, function()
			return A.ToyKnown(id)
		end) == false
	elseif r.classID == C.Miscellaneous and r.subclassID == MS.Mount then
		missing = cached("mount:" .. id, function()
			return A.MountKnown(id)
		end) == false
	elseif r.isCagedPet or r.classID == C.Battlepet or (r.classID == C.Miscellaneous and r.subclassID == MS.CompanionPet) then
		local species = type(r.link) == "string" and r.link:match("battlepet:(%d+)")
		missing = cached("pet:" .. (species and ("s" .. species) or id), function()
			return A.PetKnown(id, r.link)
		end) == false
	elseif r.classID == C.Housing then
		missing = cached("decor:" .. id, function()
			return A.DecorKnown(id)
		end) == false
	end
	if missing or knowledge(r) then
```

and replace it with:

```lua
	local _, collected = teaches(r)
	if collected == false or knowledge(r) then
```

In `SwagBag/Engine/Collections.lua` (edit 4 of 4), find:

```lua
for _, event in ipairs({ "NEW_TOY_ADDED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED" }) do
```

and replace it with:

```lua
for _, event in ipairs({ "NEW_TOY_ADDED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "TRANSMOG_COLLECTION_UPDATED" }) do
```

In `SwagBag/Engine/Keywords.lua`, find:

```lua
	kw("inuse", "volatile", flag("isLocked"))
```

and replace it with:

```lua
	kw("inuse", "volatile", flag("isLocked"))
	-- Week 7 (user pick 9, spec 7.3 "uncollected"): an appearance, toy, mount or pet the account lacks.
	kw("uncollected", "volatile", function(r)
		return SB.Collections ~= nil and SB.Collections.Uncollected(r) ~= nil
	end)
```

In `SwagBag/Engine/OverlayData.lua` (edit 1 of 3), find:

```lua
--     locked    boolean         the user locked it (ctx.locked, week 7) }
```

and replace it with:

```lua
--     locked    boolean         the user locked it (ctx.locked, week 7)
--     uncollected "appearance" | "toy" | "mount" | "pet" | nil   (ctx.uncollected, week 7) }
```

In `SwagBag/Engine/OverlayData.lua` (edit 2 of 3), find:

```lua
--           locked = fn(itemID) -> bool (Engine/Locks.lua) }
```

and replace it with:

```lua
--           locked = fn(itemID) -> bool (Engine/Locks.lua),
--           uncollected = fn(record) -> kind | nil (Engine/Collections.lua) }
```

In `SwagBag/Engine/OverlayData.lua` (edit 3 of 3), find:

```lua
	end
	-- Pawn replaces only the item-level rule: eligibility (loading, unusable, not worn gear) comes first.
```

and replace it with:

```lua
	end
	if ctx.uncollected then
		out.uncollected = ctx.uncollected(record)
	end
	-- Pawn replaces only the item-level rule: eligibility (loading, unusable, not worn gear) comes first.
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 3), find:

```lua
	.. " lock, pawn)"
```

and replace it with:

```lua
	.. " lock, uncollected, pawn)"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 3), find:

```lua
	.. " <ilvl|track|upgrade|keystone|junk|bind|learn|lock|pawn|title> <on|off>."
```

and replace it with:

```lua
	.. " <ilvl|track|upgrade|keystone|junk|bind|learn|lock|uncollected|pawn|title> <on|off>."
```

In `SwagBag/Locale/enUS.lua` (edit 3 of 3), find:

```lua
	.. " store. /swagbag worth sets any amount or percent."
```

and replace it with:

```lua
	.. " store. /swagbag worth sets any amount or percent."

-- Uncollected marker (week 7, user pick 9)
L.SET_OV_UNCOLLECTED = "Star on gear whose look you have not collected (and new toys, mounts, pets)"
```

In `SwagBag/UI/Overlays.lua` (edit 1 of 6), find:

```lua
--   top middle    a small padlock on an item the user locked      (overlays.lock, week 7)
```

and replace it with:

```lua
--   top middle    a small padlock on an item the user locked      (overlays.lock, week 7)
--   right middle  a purple star on gear whose look the account lacks, and on a toy, mount or pet not
--                 collected yet while the green glow is off (one signal per item)  (overlays.uncollected)
```

In `SwagBag/UI/Overlays.lua` (edit 2 of 6), find:

```lua
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind", "learn", "lock" },
```

and replace it with:

```lua
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind", "learn", "lock",
	"uncollected" },
```

In `SwagBag/UI/Overlays.lua` (edit 3 of 6), find:

```lua
	LOCK_TEXTURE = "Interface\\PetBattles\\PetBattle-LockIcon", LOCK_SIZE = 14 }
```

and replace it with:

```lua
	LOCK_TEXTURE = "Interface\\PetBattles\\PetBattle-LockIcon", LOCK_SIZE = 14,
	-- The uncollected mark (week 7): a text star, so no texture can go missing.
	STAR = "*", STAR_SIZE = 18, STAR_COLOR = { 0.85, 0.55, 1 } }
```

In `SwagBag/UI/Overlays.lua` (edit 4 of 6), find:

```lua
		}
```

and replace it with:

```lua
			star = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"),
		}
		r.star:SetFont((r.star:GetFont()) or Ov.FONT, Ov.STAR_SIZE, Ov.FONT_FLAGS)
		r.star:SetPoint("RIGHT", button, "RIGHT", -2, 0)
		r.star:SetTextColor(unpack(Ov.STAR_COLOR))
		r.star:SetText(Ov.STAR)
		r.star:Hide()
```

In `SwagBag/UI/Overlays.lua` (edit 5 of 6), find:

```lua
			learn = SB.Collections and SB.Collections.Learn, locked = SB.Locks and SB.Locks.Has }
```

and replace it with:

```lua
			learn = SB.Collections and SB.Collections.Learn, locked = SB.Locks and SB.Locks.Has,
			uncollected = SB.Collections and SB.Collections.Uncollected }
```

In `SwagBag/UI/Overlays.lua` (edit 6 of 6), find:

```lua
	show(r.lock, on("lock") and d.locked)
```

and replace it with:

```lua
	show(r.lock, on("lock") and d.locked)
	-- A toy, mount or pet already glows green while the learn glow is on: the star is for the rest.
	local star = d.uncollected == "appearance" or (d.uncollected ~= nil and not (on("learn") and d.learn ~= nil))
	show(r.star, on("uncollected") and star)
```

In `SwagBag/UI/SettingsPages.lua`, find:

```lua
	{ "learn", "overlays.learn", L.SET_OV_LEARN }, { "lock", "overlays.lock", L.SET_OV_LOCK },
```

and replace it with:

```lua
	{ "learn", "overlays.learn", L.SET_OV_LEARN }, { "lock", "overlays.lock", L.SET_OV_LOCK },
	{ "uncollected", "overlays.uncollected", L.SET_OV_UNCOLLECTED },
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1343 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (69 files)`, `1343 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add .luacheckrc \
	SwagBag/Core/Adapter.lua \
	SwagBag/Core/Config.lua \
	SwagBag/Engine/Collections.lua \
	SwagBag/Engine/Keywords.lua \
	SwagBag/Engine/OverlayData.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/Overlays.lua \
	SwagBag/UI/SettingsPages.lua \
	spec/adapter_spec.lua \
	spec/collections_spec.lua \
	spec/mock_adapter.lua \
	spec/overlays_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 8: uncollected star (appearances; toys, mounts and pets while the green glow is off), 'uncollected' keyword

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 9: Settings profiles and share strings (Engine/Profiles.lua, the share box, Settings > Profiles)

User pick 12. `Engine/Profiles.lua`: named profiles (copies of the account settings the user set, without Safe Mode and the quick-setup flag; D24), load with one step of undo, back to defaults, delete; the share string (D25: `SWAGBAG:1:` + percent-escaped `key=value` entries, optionally with the categories), its parser (patterns only, D26), a preview of every change and the import (D27). After a load, an import or a reset the open windows follow at once (`Profiles.Follow`, as quick setup does). `UI/ShareBox.lua` is the copy / paste box (Preview, then Import). `UI/SettingsProfiles.lua` is the new page. `/swagbag profile [save|load|delete <name>|reset|undo|export [categories]|import]`.

**Files:**
- Create: `SwagBag/Engine/Profiles.lua` (TOC, after `Engine/Vendor.lua`), `SwagBag/UI/SettingsProfiles.lua`, `SwagBag/UI/ShareBox.lua` (TOC, after `UI/SettingsVendor.lua`): 72 files
- Modify: `SwagBag/Locale/enUS.lua`, `SwagBag/SwagBag.toc`
- Test: `spec/profiles_spec.lua` (new)

**Interfaces:**
- Consumes: `Config.db/Copy/Defaults/Get/readOnly`, `SB.Emit("SB_CONFIG_CHANGED", nil)`, `Categories.Load/Name/Get/SectionOrder`, `Overlays.context/RefreshAll`, `W.RequestLayout/RefreshTitle`, `Theme.Apply(id, false)`, `Adapter.Time`.
- Produces: `SB.Profiles.List/Save/Load/Delete/Reset/Undo/Export/Parse/Preview/Import/Follow/KnownPaths`, `Profiles.VERSION`, `Profiles.HEADER`, the limits `MAX_TEXT`, `MAX_ENTRIES`, `MAX_STRING`, `MAX_NAME`, `MAX_CATEGORIES`, `MAX_LIST`, `MAX_WATCH`; `SB.ShareBox.ShowExport/ShowImport/Preview/Import`, `ShareBox.frame/data/mode`; the saved `SwagBagDB.profiles`, `.profile`, `.backups.profile`; `L.PROFILE_*`, `L.SHARE_*`, `L.SET_PROFILE*`.

- [ ] **Step 1: Write the failing tests**

Create `spec/profiles_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip ChatFontNormal loadstring load
-- Week 7 (user pick 12): named profiles (account-wide copies of the settings the user set) and a
-- versioned share string that is read with patterns only, previewed before it changes anything, and
-- refused whole when it is damaged, too long, from a newer SwagBag, or has a wrong value.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

local function load(withUI)
	local files = { unpack(Env.ENGINE) }
	files[#files + 1] = "SwagBag/Engine/Profiles.lua"
	local SB = Loader.New(files)
	SB.Config.Init(nil, nil)
	SB.Categories.Load()
	if withUI then
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsProfiles.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ShareBox.lua")
	end
	return SB
end

describe("Profiles (week 7)", function()
	local SB, A, Pr, C, changed
	before_each(function()
		SB = load(false)
		A, Pr, C = SB.Adapter, SB.Profiles, SB.Config
		changed = 0
		SB.On("SB_CONFIG_CHANGED", function(_, path)
			if path == nil then
				changed = changed + 1
			end
		end)
	end)

	-- Mutation: in replace(), drop the loop that keeps KEEP's keys (Safe Mode would travel with a profile).
	it("save, change, load: the profile's settings come back; Safe Mode and quick setup stay this machine's", function()
		C.Set("bags.columns", 14)
		C.Set("safeMode.bags", true)
		assert.same({ true, "M+" }, { Pr.Save(" M+ ") })
		assert.is_nil(SB.Config.db.profiles["M+"].settings.safeMode, "never saved")
		C.Set("bags.columns", 10)
		C.Set("setup.done", true)
		assert.truthy(Pr.Load("M+"))
		assert.same({ 14, true, true }, { C.Get("bags.columns"), C.Get("safeMode.bags"), C.Get("setup.done") })
		assert.same({ "M+" }, Pr.List())
		assert.equal("M+", SB.Config.db.profile)
		assert.equal(1, changed, "one SB_CONFIG_CHANGED(nil): every engine follows")
	end)

	-- Mutation: Pr.Undo returns true without restoring d.backups.profile.
	it("undo brings back the settings before a load or a reset, once", function()
		C.Set("bags.columns", 16)
		Pr.Save("A")
		C.Set("bags.columns", 10)
		Pr.Load("A")
		assert.truthy(Pr.Undo())
		assert.equal(10, C.Get("bags.columns"))
		assert.same({ false, "none" }, { Pr.Undo() })
		assert.truthy(Pr.Reset())
		assert.equal(12, C.Get("bags.columns"), "the default")
		Pr.Undo()
		assert.equal(10, C.Get("bags.columns"))
	end)

	-- Mutation: cleanName accepts any length.
	it("bad names, unknown profiles and read-only settings change nothing and say why", function()
		assert.same({ false, "name" }, { Pr.Save("") })
		assert.same({ false, "name" }, { Pr.Save(("x"):rep(25)) })
		assert.same({ false, "unknown" }, { Pr.Load("nope") })
		assert.same({ false, "unknown" }, { Pr.Delete("nope") })
		Pr.Save("A")
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { Pr.Load("A") })
		assert.same({ false, "readonly" }, { Pr.Delete("A") })
		SB.Config.readOnly = false
		assert.truthy(Pr.Delete("A"))
		assert.same({}, Pr.List())
		SB.Config.db.profiles = "broken"
		assert.same({}, Pr.List(), "damaged saved data reads as none")
	end)

	-- Mutation: in esc(), let "%" through unescaped (a value with % would come back wrong).
	it("a share string round-trips the settings you set: text with ; = % |, booleans, numbers, the watch list", function()
		C.Set("bags.footer.entries", "gold;=%|,-free")
		C.Set("overlays.junk", false)
		C.Set("bags.scale", 1.25)
		C.Set("consumables.watch", { { query = "flask & lvl>=80", threshold = 2, name = "WATCH_FLASK" },
			{ itemID = 211880, threshold = 5 } })
		C.Set("safeMode.bank", true)
		local text = Pr.Export(false)
		assert.equal("SWAGBAG:1:", text:sub(1, 10))
		assert.falsy(text:find("safeMode", 1, true))
		assert.falsy(text:find("|", 1, true), "no pipe: chat and edit boxes would read it as a code")
		local data = assert(Pr.Parse(text))
		assert.same({ ["bags.footer.entries"] = "gold;=%|,-free", ["overlays.junk"] = false, ["bags.scale"] = 1.25 },
			data.settings)
		assert.same({ { query = "flask & lvl>=80", threshold = 2, name = "WATCH_FLASK" }, { itemID = 211880, threshold = 5 } },
			data.watch)
	end)

	-- Mutation: in Pr.Parse, `elseif tonumber(version) > Pr.VERSION` -> `elseif false` (a newer string read anyway).
	it("refuses a string that is not ours, from a newer SwagBag, damaged, too long or with a wrong value", function()
		assert.same({ nil, "notours" }, { Pr.Parse("hello") })
		assert.same({ nil, "newer" }, { Pr.Parse("SWAGBAG:2:s.bags.columns=n14") })
		assert.same({ nil, "damaged", "s.bags.columns=x14" }, { Pr.Parse("SWAGBAG:1:s.bags.columns=x14") })
		assert.same({ nil, "damaged", "s.bags.view=s%ZZ" }, { Pr.Parse("SWAGBAG:1:s.bags.view=s%ZZ") })
		assert.same({ nil, "type", "bags.columns" }, { Pr.Parse("SWAGBAG:1:s.bags.columns=strue") })
		assert.same({ nil, "toolong" }, { Pr.Parse("SWAGBAG:1:" .. ("s.bags.view=ssections;"):rep(2000)) })
		assert.same({ nil, "damaged", "w" }, { Pr.Parse("SWAGBAG:1:w=sq%252A0") })
		assert.same({ nil, "empty" }, { Pr.Parse("  ") })
	end)

	-- Mutation: in Pr.Parse, an unknown setting path is stored in data.settings (then imported as junk).
	it("never runs what it reads; settings this version does not know are skipped and named", function()
		local loads = 0
		local realLoad, realLoadstring = load, loadstring
		load = function(...) loads = loads + 1 return realLoad(...) end
		loadstring = function(...) loads = loads + 1 return realLoadstring(...) end
		local data = Pr.Parse("SWAGBAG:1:s.bags.columns=n14;s.bags.sparkles=b1;s.os.execute=sx;zz=b1")
		load, loadstring = realLoad, realLoadstring
		assert.equal(0, loads)
		assert.same({ ["bags.columns"] = 14 }, data.settings)
		assert.same({ "bags.sparkles", "os.execute", "zz" }, data.skipped)
	end)

	-- Mutation: Pr.Preview lists every setting in the string, changed or not.
	it("the preview names each change (old -> new), the watch list, categories and skipped settings", function()
		C.Set("bags.columns", 14)
		local data = Pr.Parse("SWAGBAG:1:s.bags.columns=n14;s.bags.view=slist;s.bags.sparkles=b1;w=s")
		assert.same({ "bags.view: sections -> list", "Consumables watch list: 0 entries",
			"Not known by this version (skipped): bags.sparkles" }, Pr.Preview(data))
		assert.same({ SB.L.PROFILE_PREVIEW_NOTHING }, Pr.Preview(Pr.Parse("SWAGBAG:1:s.bags.columns=n14")))
	end)

	-- Mutation: Pr.Import skips data.edits.
	it("with categories: your categories, built-in edits and the order travel; import loads them, undo keeps settings", function()
		SB.Config.db.categories.u_mats = { name = "Mats", query = "herb | ore", priority = 58, displayOrder = 55,
			itemList = { include = { [211880] = true } } }
		SB.Config.db.userEdits.c_junk = { name = "Trash" }
		SB.Config.db.categoryOrder = { "c_junk", "u_mats" }
		local text = Pr.Export(true)
		SB.Config.db.categories, SB.Config.db.userEdits, SB.Config.db.categoryOrder = {}, {}, nil
		SB.Categories.Load()
		local data = assert(Pr.Parse(text))
		assert.same({ true, 3 }, { Pr.Import(data) })
		assert.same({ "Mats", "Trash" }, { SB.Categories.Name("u_mats"), SB.Categories.Name("c_junk") })
		assert.same({ "new", "c_junk", "u_mats" }, { unpack(SB.Categories.SectionOrder(), 1, 3) })
		assert.truthy(SB.Categories.Get("u_mats").itemList.include[211880])
	end)

	-- P2. Mutation: /swagbag profile load ignores Load's answer (always says loaded).
	it("/swagbag profile answers every form", function()
		SB.Slash.Dispatch("profile save Raid")
		SB.Slash.Dispatch("profile")
		SB.Slash.Dispatch("profile load Nope")
		SB.Slash.Dispatch("profile load Raid")
		SB.Slash.Dispatch("profile undo")
		SB.Slash.Dispatch("profile delete Raid")
		SB.Slash.Dispatch("profile dance")
		local L = SB.L
		assert.same({ L.PROFILE_SAVED:format("Raid"), L.PROFILE_STATE:format("Raid", "Raid"), L.PROFILE_UNKNOWN:format("Nope"),
			L.PROFILE_LOADED:format("Raid"), L.PROFILE_UNDONE, L.PROFILE_DELETED:format("Raid"), L.PROFILE_USAGE }, A.Lines())
	end)
end)

describe("Share box and Profiles page (week 7)", function()
	local SB, A, SX, SW
	before_each(function()
		SB = load(true)
		A, SX, SW = SB.Adapter, SB.ShareBox, SB.SettingsWindow
		ChatFontNormal = {}
	end)

	after_each(function()
		Fake.Uninstall()
		ChatFontNormal = nil
	end)

	-- Mutation: SX.Import imports without a preview (SX.data nil -> Parse inline).
	it("import: Preview first; a typed change needs a new preview; Import applies and answers in chat", function()
		SB.Slash.Dispatch("profile import")
		local f = SX.frame
		f.edit:SetText("SWAGBAG:1:s.bags.columns=n16")
		assert.falsy(SX.Import())
		assert.equal(SB.L.SHARE_PREVIEW_FIRST, f.status.text)
		assert.truthy(SX.Preview())
		assert.equal("Import would change:\nbags.columns: 12 -> 16", f.status.text)
		Fake.Fire(f.edit, "OnTextChanged", true)
		assert.falsy(SX.Import(), "changed since the preview")
		SX.Preview()
		assert.truthy(SX.Import())
		assert.equal(16, SB.Config.Get("bags.columns"))
		assert.falsy(f.shown)
		assert.same({ SB.L.PROFILE_IMPORT_OPENED, SB.L.PROFILE_IMPORTED:format(1) }, A.Lines())
	end)

	-- Mutation: SX.Preview keeps SX.data from an earlier good string when the new one is refused.
	it("a refused string says why in the box and can never be imported", function()
		SX.ShowImport()
		SX.frame.edit:SetText("SWAGBAG:1:s.bags.columns=n16")
		SX.Preview()
		SX.frame.edit:SetText("SWAGBAG:9:s.bags.columns=n10")
		assert.falsy(SX.Preview())
		assert.equal(SB.L.SHARE_ERR_NEWER, SX.frame.status.text)
		assert.falsy(SX.Import())
		assert.equal(12, SB.Config.Get("bags.columns"))
	end)

	-- Mutation: ShowExport skips HighlightText.
	it("export shows the string selected, read-only, without import buttons", function()
		SB.Config.Set("bags.columns", 14)
		SB.Slash.Dispatch("profile export")
		local f = SX.frame
		assert.equal(SB.Profiles.Export(false), f.edit.text)
		assert.truthy(f.edit.calls.HighlightText)
		assert.same({ false, false }, { f.preview.shown, f.import.shown })
		f.edit.text = "typed"
		Fake.Fire(f.edit, "OnTextChanged", true)
		assert.equal(SB.Profiles.Export(false), f.edit.text, "typing puts the string back")
	end)

	-- Mutation: the page's Save button runs "profile save Profile 1" every time (the second would overwrite).
	it("the Profiles page saves under a free name, loads and deletes through /swagbag profile", function()
		SW.Show("profiles")
		local function click(text, nth)
			local seen = 0
			for i = 1, SW.used.buttons do
				if SW.buttons[i].text == text then
					seen = seen + 1
					if seen == (nth or 1) then
						Fake.Fire(SW.buttons[i], "OnClick")
						return
					end
				end
			end
			error("no button " .. text)
		end
		click(SB.L.SET_PROFILES_SAVE_BUTTON)
		click(SB.L.SET_PROFILES_SAVE_BUTTON)
		assert.same({ "Profile 1", "Profile 2" }, SB.Profiles.List())
		click(SB.L.SET_PROFILE_DELETE, 1)
		assert.same({ "Profile 2" }, SB.Profiles.List())
		assert.equal(SB.L.PROFILE_DELETED:format("Profile 1"), SW.lastStatus)
	end)
end)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1343 passed, 13 failed`. The failures, exactly:

- `spec/profiles_spec.lua :: Profiles (week 7) > save, change, load: the profile's settings come back; Safe Mode and quick setup stay this machine's`
- `spec/profiles_spec.lua :: Profiles (week 7) > undo brings back the settings before a load or a reset, once`
- `spec/profiles_spec.lua :: Profiles (week 7) > bad names, unknown profiles and read-only settings change nothing and say why`
- `spec/profiles_spec.lua :: Profiles (week 7) > a share string round-trips the settings you set: text with ; = % |, booleans, numbers, the watch list`
- `spec/profiles_spec.lua :: Profiles (week 7) > refuses a string that is not ours, from a newer SwagBag, damaged, too long or with a wrong value`
- `spec/profiles_spec.lua :: Profiles (week 7) > never runs what it reads; settings this version does not know are skipped and named`
- `spec/profiles_spec.lua :: Profiles (week 7) > the preview names each change (old -> new), the watch list, categories and skipped settings`
- `spec/profiles_spec.lua :: Profiles (week 7) > with categories: your categories, built-in edits and the order travel; import loads them, undo keeps settings`
- `spec/profiles_spec.lua :: Profiles (week 7) > /swagbag profile answers every form`
- `spec/profiles_spec.lua :: Share box and Profiles page (week 7) > import: Preview first; a typed change needs a new preview; Import applies and answers in chat`
- `spec/profiles_spec.lua :: Share box and Profiles page (week 7) > a refused string says why in the box and can never be imported`
- `spec/profiles_spec.lua :: Share box and Profiles page (week 7) > export shows the string selected, read-only, without import buttons`
- `spec/profiles_spec.lua :: Share box and Profiles page (week 7) > the Profiles page saves under a free name, loads and deletes through /swagbag profile`

`spec/profiles_spec.lua` fails whole (the files do not exist yet).

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "save, change, load: the profile's settings come back; Safe Mode and quick setup stay this machine's": in `SwagBag/Engine/Profiles.lua`, `for k in pairs(KEEP) do ⏎ new[k] = SB.Config.Copy(old[k]) ⏎ end` → `∅`.
- "undo brings back the settings before a load or a reset, once": in `SwagBag/Engine/Profiles.lua`, `local back = d.backups.profile ⏎ replace(back) ⏎ d.backups.profile = nil` → `d.backups.profile = nil`.
- "bad names, unknown profiles and read-only settings change nothing and say why": in `SwagBag/Engine/Profiles.lua`, `or #name > Pr.MAX_NAME or` → `or`.
- "a share string round-trips the settings you set: text with ; = % |, booleans, numbers, the watch list": in `SwagBag/Engine/Profiles.lua`, `gsub("[^%w%._%-]", function(c)` → `gsub("[^%w%._%-%%]", function(c)`.
- "refuses a string that is not ours, from a newer SwagBag, damaged, too long or with a wrong value": in `SwagBag/Engine/Profiles.lua`, `elseif tonumber(version) > Pr.VERSION then` → `elseif false then`.
- "never runs what it reads; settings this version does not know are skipped and named": in `SwagBag/Engine/Profiles.lua`, `if known[path] == nil then ⏎ data.skipped[#data.skipped + 1] = path` → `if known[path] == nil then ⏎ data.settings[path] = value`.
- "the preview names each change (old -> new), the watch list, categories and skipped settings": in `SwagBag/Engine/Profiles.lua`, `if now ~= new then ⏎ lines[#lines + 1]` → `if true then ⏎ lines[#lines + 1]`.
- "with categories: your categories, built-in edits and the order travel; import loads them, undo keeps settings": in `SwagBag/Engine/Profiles.lua`, `for id, def in pairs(data.edits) do ⏎ d.userEdits` → `for id, def in pairs({}) do ⏎ d.userEdits`.
- "/swagbag profile answers every form": in `SwagBag/Engine/Profiles.lua`, `local ok, r = Pr.Load(rest) ⏎ return ok and L.PROFILE_LOADED:format(rest) or why(r, rest)` → `Pr.Load(rest) ⏎ return L.PROFILE_LOADED:format(rest)`.
- "import: Preview first; a typed change needs a new preview; Import applies and answers in chat": in `SwagBag/UI/ShareBox.lua`, `if not SX.data then ⏎ f.status:SetText(L.SHARE_PREVIEW_FIRST) ⏎ return false ⏎ end` → `SX.data = SX.data or SB.Profiles.Parse(f.edit:GetText())`.
- "a refused string says why in the box and can never be imported": in `SwagBag/UI/ShareBox.lua`, `if not data then ⏎ SX.data = nil ⏎ f.status` → `if not data then ⏎ f.status`.
- "export shows the string selected, read-only, without import buttons": in `SwagBag/UI/ShareBox.lua`, `f:Show() ⏎ f.edit:SetFocus() ⏎ f.edit:HighlightText()` → `f:Show() ⏎ f.edit:SetFocus()`.
- "the Profiles page saves under a free name, loads and deletes through /swagbag profile": in `SwagBag/UI/SettingsProfiles.lua`, `return run("profile save " .. nextName())` → `return run("profile save Profile 1")`.

- [ ] **Step 3: Write the code**

Create `SwagBag/Engine/Profiles.lua`:

```lua
-- SwagBag profiles and share strings (week 7, user pick 12). Account-wide, in SwagBagDB (read
-- defensively; the schema stays 2): profiles = { [name] = { settings = <copy>, saved = epoch } },
-- profile = the name last saved or loaded (shown only), backups.profile = the settings before the last
-- load, import or reset (one step of undo). A profile is a copy of the account settings the user set
-- (SwagBagDB.settings: only values somebody chose, Config.Get falls back to the defaults); Safe Mode and
-- the quick-setup flag are this machine's state and never travel. Character overrides stay as they are.
--   Profiles.List() -> { name }              Profiles.Save(name) / Load(name) / Delete(name) -> ok, why
--   Profiles.Reset() / Undo() -> ok, why     why: "readonly" | "name" | "unknown" | "none"
--   Profiles.Export(withCategories) -> text  "SWAGBAG:1:" then key=value entries joined by ";"
--   Profiles.Parse(text) -> data | nil, error, detail   never runs anything it reads (no load, no
--                                            loadstring): patterns only; every value is checked
--   Profiles.Preview(data) -> { line }        what an import would change
--   Profiles.Import(data) -> n               apply (current settings kept for Undo); n changes
-- Share string, version 1. Values: b1 / b0 (boolean), n<number>, s<text> with every character other
-- than letters, digits, "." "_" "-" written %XX (so spaces and line breaks a paste adds are dropped). Keys:
--   s.<setting path>            a setting the user set (a known path; the default's type)
--   w                           the consumables watch list: entries "q<query>*<n>*<name>" or "i<itemID>*<n>"
--                               joined by "," (each part escaped again)
--   cu.<id>.<field> / ce.<id>.<field>   a category of the user's / a built-in's edit (with categories):
--                               name (s), query (s), priority (n), displayOrder (n), enabled (b), inc / exc (s:
--                               item IDs joined by ",")
--   co                          the category order (s: ids joined by ",")
-- A string from a newer SwagBag, a damaged one, or one with a known setting of the wrong type is refused
-- whole; settings this version does not know are skipped and named in the preview.
local _, SB = ...

local L = SB.L
local Pr = { VERSION = 1, HEADER = "SWAGBAG:", MAX_TEXT = 30000, MAX_ENTRIES = 1500, MAX_STRING = 500,
	MAX_NAME = 24, MAX_CATEGORIES = 100, MAX_LIST = 2000, MAX_WATCH = 50 }
SB.Profiles = Pr

local KEEP = { safeMode = true, setup = true } -- this machine's state: never saved, loaded or shared
local FIELD_TYPES = { name = "string", query = "string", priority = "number", displayOrder = "number",
	enabled = "boolean", inc = "list", exc = "list" }

local function db()
	return SB.Config.db
end

local function profiles()
	local d = db()
	if type(d.profiles) ~= "table" then
		d.profiles = {}
	end
	return d.profiles
end

local function cleanName(name)
	name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
	if name == "" or #name > Pr.MAX_NAME or name:find("[%c|]") then
		return nil
	end
	return name
end

-- The settings without this machine's state, copied.
local function shareable(settings)
	local out = {}
	for k, v in pairs(type(settings) == "table" and settings or {}) do
		if not KEEP[k] then
			out[k] = SB.Config.Copy(v)
		end
	end
	return out
end

-- Replace the account settings by `settings`, keeping this machine's state; the old ones become the undo.
local function replace(settings)
	local d = db()
	local old = type(d.settings) == "table" and d.settings or {}
	d.backups = type(d.backups) == "table" and d.backups or {}
	d.backups.profile = SB.Config.Copy(old)
	local new = shareable(settings)
	for k in pairs(KEEP) do
		new[k] = SB.Config.Copy(old[k])
	end
	d.settings = new
	SB.Emit("SB_CONFIG_CHANGED", nil)
	Pr.Follow()
end

-- The open windows follow at once, as after quick setup (UI/QuickSetup.lua): categories, totals,
-- overlays, the bags' layout and title, and the look.
function Pr.Follow()
	if SB.Categories then
		SB.Categories.Load()
	end
	SB.Emit("SB_PRICES_CHANGED")
	if SB.Overlays then
		SB.Overlays.context = nil
		SB.Overlays.RefreshAll()
	end
	local W = SB.BagsWindow
	if W and W.IsOpen and W.IsOpen() then
		W.RequestLayout("profile")
		W.RefreshTitle()
	end
	if SB.Theme and SB.Theme.Apply then
		SB.Theme.Apply(SB.Config.Get("theme.name"), false)
	end
end

function Pr.List()
	local out = {}
	for name, p in pairs(type(db().profiles) == "table" and db().profiles or {}) do
		if type(name) == "string" and type(p) == "table" and type(p.settings) == "table" then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

function Pr.Save(name)
	name = cleanName(name)
	if not name then
		return false, "name"
	elseif SB.Config.readOnly then
		return false, "readonly"
	end
	profiles()[name] = { settings = shareable(db().settings), saved = SB.Adapter.Time() }
	db().profile = name
	return true, name
end

function Pr.Load(name)
	local p = type(db().profiles) == "table" and db().profiles[name]
	if type(p) ~= "table" or type(p.settings) ~= "table" then
		return false, "unknown"
	elseif SB.Config.readOnly then
		return false, "readonly"
	end
	replace(p.settings)
	db().profile = name
	return true
end

function Pr.Delete(name)
	if type(db().profiles) ~= "table" or db().profiles[name] == nil then
		return false, "unknown"
	elseif SB.Config.readOnly then
		return false, "readonly"
	end
	db().profiles[name] = nil
	if db().profile == name then
		db().profile = nil
	end
	return true
end

function Pr.Reset()
	if SB.Config.readOnly then
		return false, "readonly"
	end
	replace({})
	db().profile = nil
	return true
end

function Pr.Undo()
	local d = db()
	if SB.Config.readOnly then
		return false, "readonly"
	elseif type(d.backups) ~= "table" or type(d.backups.profile) ~= "table" then
		return false, "none"
	end
	local back = d.backups.profile
	replace(back)
	d.backups.profile = nil
	return true
end

---------------------------------------------------------------------------
-- The share string
---------------------------------------------------------------------------
local function esc(text)
	return (tostring(text):gsub("[^%w%._%-]", function(c)
		return ("%%%02X"):format(c:byte())
	end))
end

local function unesc(text)
	if text:find("%%[^%x]") or text:find("%%%x[^%x]") or text:find("%%%x?$") then
		return nil
	end
	return (text:gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end))
end

local function encode(v)
	local t = type(v)
	if t == "boolean" then
		return v and "b1" or "b0"
	elseif t == "number" then
		return "n" .. tostring(v)
	end
	return "s" .. esc(v)
end

-- The scalar leaves of the defaults: { [path] = type } (consumables.watch is its own entry).
local function knownPaths()
	local out = {}
	local function walk(t, prefix)
		for k, v in pairs(t) do
			local path = prefix and (prefix .. "." .. k) or k
			if type(v) == "table" then
				walk(v, path)
			elseif not KEEP[path:match("^[^%.]+")] then
				out[path] = type(v)
			end
		end
	end
	walk(SB.Config.Defaults.settings, nil)
	return out
end
Pr.KnownPaths = knownPaths

local function leaves(t, prefix, out)
	for k, v in pairs(t) do
		local path = prefix and (prefix .. "." .. tostring(k)) or tostring(k)
		if type(v) == "table" then
			leaves(v, path, out)
		else
			out[path] = v
		end
	end
	return out
end

local function idList(t)
	local ids = {}
	for id, on in pairs(type(t) == "table" and t or {}) do
		if on and type(id) == "number" then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	for i, id in ipairs(ids) do
		ids[i] = tostring(id)
	end
	return table.concat(ids, ",")
end

local function categoryEntries(entries, prefix, id, def)
	for field, kind in pairs(FIELD_TYPES) do
		if kind == "list" then
			local which = field == "inc" and "include" or "exclude"
			local list = type(def.itemList) == "table" and idList(def.itemList[which]) or ""
			if list ~= "" then
				entries[#entries + 1] = prefix .. "." .. id .. "." .. field .. "=s" .. esc(list)
			end
		elseif type(def[field]) == kind then
			entries[#entries + 1] = prefix .. "." .. id .. "." .. field .. "=" .. encode(def[field])
		end
	end
end

function Pr.Export(withCategories)
	local d, known, entries = db(), knownPaths(), {}
	for path, v in pairs(leaves(shareable(d.settings), nil, {})) do
		if known[path] and type(v) == known[path] then
			entries[#entries + 1] = "s." .. path .. "=" .. encode(v)
		end
	end
	local watch = type(d.settings) == "table" and type(d.settings.consumables) == "table" and d.settings.consumables.watch
	if type(watch) == "table" then
		local parts = {}
		for _, e in ipairs(watch) do
			if type(e) == "table" and type(e.threshold) == "number" then
				if type(e.itemID) == "number" then
					parts[#parts + 1] = esc("i" .. e.itemID .. "*" .. e.threshold)
				elseif type(e.query) == "string" then
					parts[#parts + 1] = esc("q" .. esc(e.query) .. "*" .. e.threshold .. "*" .. esc(e.name or ""))
				end
			end
		end
		entries[#entries + 1] = "w=s" .. esc(table.concat(parts, ","))
	end
	if withCategories then
		for id, def in pairs(type(d.categories) == "table" and d.categories or {}) do
			if type(def) == "table" then
				categoryEntries(entries, "cu", id, def)
			end
		end
		for id, def in pairs(type(d.userEdits) == "table" and d.userEdits or {}) do
			if type(def) == "table" then
				categoryEntries(entries, "ce", id, def)
			end
		end
		if type(d.categoryOrder) == "table" then
			entries[#entries + 1] = "co=s" .. esc(table.concat(d.categoryOrder, ","))
		end
	end
	table.sort(entries)
	return Pr.HEADER .. Pr.VERSION .. ":" .. table.concat(entries, ";")
end

local function decode(raw)
	local kind, body = raw:sub(1, 1), raw:sub(2)
	if kind == "b" and (body == "1" or body == "0") then
		return true, body == "1"
	elseif kind == "n" then
		local n = tonumber(body)
		if n and n == n and n ~= math.huge and n ~= -math.huge and body:match("^%-?[%d%.]+$") then
			return true, n
		end
	elseif kind == "s" then
		local s = unesc(body)
		if s then
			return true, s
		end
	end
	return false
end

local function numbers(text)
	local out = {}
	for part in text:gmatch("[^,]+") do
		local n = tonumber(part)
		if not n or n < 1 or n ~= math.floor(n) or n == math.huge or not part:match("^%d+$") then
			return nil
		end
		out[n] = true
	end
	return out
end

local function parseWatch(text)
	local out = {}
	for part in text:gmatch("[^,]+") do
		local e = unesc(part)
		if not e then
			return nil
		end
		local id, n = e:match("^i(%d+)%*(%d+)$")
		local entry
		if id then
			entry = { itemID = tonumber(id), threshold = tonumber(n) }
		else
			local q, n2, name = e:match("^q([^%*]*)%*(%d+)%*([^%*]*)$")
			q, name = q and unesc(q), name and unesc(name)
			if not q or q == "" or #q > 200 or (name ~= "" and not name:match("^[%u_]+$")) then
				return nil
			end
			entry = { query = q, threshold = tonumber(n2), name = name ~= "" and name or nil }
		end
		if entry.threshold < 1 or entry.threshold > 200 or #out >= Pr.MAX_WATCH then
			return nil
		end
		out[#out + 1] = entry
	end
	return out
end

-- data = { settings = { [path] = value }, watch, users = { [id] = def }, edits = { [id] = def }, order,
--          skipped = { path } }
function Pr.Parse(text)
	if type(text) ~= "string" then
		return nil, "empty"
	end
	text = text:gsub("%s+", "")
	if text == "" then
		return nil, "empty"
	end
	local version, body = text:match("^SWAGBAG:(%d+):(.*)$")
	if not version then
		return nil, "notours"
	elseif tonumber(version) > Pr.VERSION then
		return nil, "newer"
	elseif #text > Pr.MAX_TEXT then
		return nil, "toolong"
	end
	local known = knownPaths()
	local data = { settings = {}, users = {}, edits = {}, skipped = {} }
	local count, cats = 0, {}
	for entry in body:gmatch("[^;]+") do
		count = count + 1
		if count > Pr.MAX_ENTRIES then
			return nil, "toolong"
		end
		local key, raw = entry:match("^([%w_%.]+)=(.+)$")
		local ok, value = false, nil
		if key then
			ok, value = decode(raw)
		end
		if not ok then
			return nil, "damaged", entry:sub(1, 40)
		end
		local path = key:match("^s%.(.+)$")
		local prefix, id, field = key:match("^(c[ue])%.([%w_]+)%.(%a+)$")
		if path then
			if known[path] == nil then
				data.skipped[#data.skipped + 1] = path
			elseif type(value) ~= known[path] or (type(value) == "string" and #value > Pr.MAX_STRING) then
				return nil, "type", path
			else
				data.settings[path] = value
			end
		elseif key == "w" then
			data.watch = type(value) == "string" and parseWatch(value)
			if not data.watch then
				return nil, "damaged", "w"
			end
		elseif key == "co" then
			if type(value) ~= "string" then
				return nil, "damaged", "co"
			end
			data.order = {}
			for oid in value:gmatch("[^,]+") do
				if not oid:match("^[%w_]+$") then
					return nil, "damaged", "co"
				end
				data.order[#data.order + 1] = oid
			end
		elseif prefix and FIELD_TYPES[field] and #id <= 40 then
			local into = prefix == "cu" and data.users or data.edits
			if not into[id] then
				cats[#cats + 1] = id
				if #cats > Pr.MAX_CATEGORIES then
					return nil, "toolong"
				end
				into[id] = {}
			end
			local kind = FIELD_TYPES[field]
			if kind == "list" then
				local ids = type(value) == "string" and numbers(value)
				if not ids then
					return nil, "type", key
				end
				into[id].itemList = into[id].itemList or {}
				into[id].itemList[field == "inc" and "include" or "exclude"] = ids
			elseif type(value) ~= kind then
				return nil, "type", key
			else
				into[id][field] = value
			end
		else
			data.skipped[#data.skipped + 1] = key
		end
	end
	table.sort(data.skipped)
	return data
end

local function show(v)
	if type(v) == "boolean" then
		return v and L.OVERLAY_ON or L.OVERLAY_OFF
	end
	return tostring(v)
end

function Pr.Preview(data)
	local lines, paths = {}, {}
	for path in pairs(data.settings) do
		paths[#paths + 1] = path
	end
	table.sort(paths)
	for _, path in ipairs(paths) do
		local now, new = SB.Config.Get(path), data.settings[path]
		if now ~= new then
			lines[#lines + 1] = L.PROFILE_PREVIEW_LINE:format(path, show(now), show(new))
		end
	end
	if data.watch then
		lines[#lines + 1] = L.PROFILE_PREVIEW_WATCH:format(#data.watch)
	end
	local nu, ne = 0, 0
	for _ in pairs(data.users) do
		nu = nu + 1
	end
	for _ in pairs(data.edits) do
		ne = ne + 1
	end
	if nu + ne > 0 or data.order then
		lines[#lines + 1] = L.PROFILE_PREVIEW_CATEGORIES:format(nu, ne, data.order and L.REPORT_YES or L.REPORT_NO)
	end
	if #data.skipped > 0 then
		lines[#lines + 1] = L.PROFILE_PREVIEW_SKIPPED:format(table.concat(data.skipped, ", "))
	end
	if #lines == 0 then
		lines[1] = L.PROFILE_PREVIEW_NOTHING
	end
	return lines
end

local function setPath(t, path, value)
	local parts = {}
	for p in path:gmatch("[^%.]+") do
		parts[#parts + 1] = p
	end
	for i = 1, #parts - 1 do
		if type(t[parts[i]]) ~= "table" then
			t[parts[i]] = {}
		end
		t = t[parts[i]]
	end
	t[parts[#parts]] = value
end

function Pr.Import(data)
	if SB.Config.readOnly then
		return false, "readonly"
	end
	local d = db()
	local settings = shareable(d.settings)
	local n = 0
	for path, value in pairs(data.settings) do
		if SB.Config.Get(path) ~= value then
			n = n + 1
		end
		setPath(settings, path, value)
	end
	if data.watch then
		settings.consumables = type(settings.consumables) == "table" and settings.consumables or {}
		settings.consumables.watch = data.watch
		n = n + 1
	end
	for id, def in pairs(data.users) do
		d.categories = type(d.categories) == "table" and d.categories or {}
		d.categories[id] = def
		n = n + 1
	end
	for id, def in pairs(data.edits) do
		d.userEdits = type(d.userEdits) == "table" and d.userEdits or {}
		d.userEdits[id] = def
		n = n + 1
	end
	if data.order then
		d.categoryOrder = data.order
		n = n + 1
	end
	replace(settings) -- Follow() loads the categories again
	return true, n
end

---------------------------------------------------------------------------
-- /swagbag profile ...
---------------------------------------------------------------------------
local REASON = { readonly = "SETTINGS_READONLY", name = "PROFILE_BAD_NAME", unknown = "PROFILE_UNKNOWN",
	none = "PROFILE_NO_UNDO" }

local function why(reason, name)
	return L[REASON[reason] or "PROFILE_USAGE"]:format(tostring(name or ""))
end

SB.Slash.Register("profile", L.HELP_PROFILE, function(arg)
	local verb, rest = (arg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	verb = verb:lower()
	if verb == "" or verb == "list" then
		local list = Pr.List()
		return L.PROFILE_STATE:format(#list > 0 and table.concat(list, ", ") or L.REPORT_NONE,
			tostring(db().profile or L.REPORT_NONE))
	elseif verb == "save" then
		local ok, r = Pr.Save(rest)
		return ok and L.PROFILE_SAVED:format(r) or why(r, rest)
	elseif verb == "load" then
		local ok, r = Pr.Load(rest)
		return ok and L.PROFILE_LOADED:format(rest) or why(r, rest)
	elseif verb == "delete" then
		local ok, r = Pr.Delete(rest)
		return ok and L.PROFILE_DELETED:format(rest) or why(r, rest)
	elseif verb == "reset" then
		local ok, r = Pr.Reset()
		return ok and L.PROFILE_RESET or why(r)
	elseif verb == "undo" then
		local ok, r = Pr.Undo()
		return ok and L.PROFILE_UNDONE or why(r)
	elseif verb == "export" and (rest == "" or rest:lower() == "categories") then
		local text = Pr.Export(rest ~= "")
		if SB.ShareBox then
			SB.ShareBox.ShowExport(text)
		end
		return rest ~= "" and L.PROFILE_EXPORTED_CATEGORIES or L.PROFILE_EXPORTED
	elseif verb == "import" and rest == "" then
		if SB.ShareBox then
			SB.ShareBox.ShowImport()
		end
		return L.PROFILE_IMPORT_OPENED
	end
	return L.PROFILE_USAGE
end)
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.SET_OV_UNCOLLECTED = "Star on gear whose look you have not collected (and new toys, mounts, pets)"
```

and replace it with:

```lua
L.SET_OV_UNCOLLECTED = "Star on gear whose look you have not collected (and new toys, mounts, pets)"

-- Profiles and share strings (week 7, user pick 12): Engine/Profiles.lua, UI/ShareBox.lua, UI/SettingsProfiles.lua
L.HELP_PROFILE = "profile [save|load|delete <name>|reset|undo|export [categories]|import]: settings profiles and share strings"
L.PROFILE_STATE = "Profiles: %s (last used: %s). Type /swagbag profile save <name>, load <name>, delete <name>, reset,"
	.. " undo, export, or import."
L.PROFILE_USAGE = "Use /swagbag profile, profile save <name>, load <name>, delete <name>, reset, undo, export"
	.. " [categories], or import."
L.PROFILE_BAD_NAME = "A profile name is 1 to 24 characters: \"%s\" can't be used."
L.PROFILE_UNKNOWN = "There is no profile named \"%s\". Type /swagbag profile to list them."
L.PROFILE_NO_UNDO = "There is nothing to undo: no profile was loaded or imported since the last undo."
L.PROFILE_SAVED = "Saved your current settings as the profile \"%s\"."
L.PROFILE_LOADED = "Loaded the profile \"%s\". Your previous settings are kept: /swagbag profile undo brings them back."
L.PROFILE_DELETED = "Deleted the profile \"%s\". Your current settings are unchanged."
L.PROFILE_RESET = "Your settings are back to SwagBag's defaults. /swagbag profile undo brings yours back."
L.PROFILE_UNDONE = "Your settings are back as they were before the last load, import or reset."
L.PROFILE_EXPORTED = "Your settings' share string is in the box: press Ctrl+C to copy it."
L.PROFILE_EXPORTED_CATEGORIES = "Your settings' and categories' share string is in the box: press Ctrl+C to copy it."
L.PROFILE_IMPORT_OPENED = "Paste a share string into the box, then press Preview."
L.PROFILE_IMPORTED = "Imported %d changes. Your previous settings are kept: /swagbag profile undo brings them back."
L.PROFILE_AUTO_NAME = "Profile %d"
L.PROFILE_PREVIEW_LINE = "%s: %s -> %s"
L.PROFILE_PREVIEW_WATCH = "Consumables watch list: %d entries"
L.PROFILE_PREVIEW_CATEGORIES = "Categories: %d of yours, %d changed built-ins, order %s"
L.PROFILE_PREVIEW_SKIPPED = "Not known by this version (skipped): %s"
L.PROFILE_PREVIEW_NOTHING = "Nothing would change: your settings already match."
L.SHARE_EXPORT_TITLE = "SwagBag share string"
L.SHARE_EXPORT_HINT = "Press Ctrl+C to copy. Anyone can import it with /swagbag profile import."
L.SHARE_IMPORT_TITLE = "Import a SwagBag share string"
L.SHARE_IMPORT_HINT = "Paste a string (Ctrl+V), then press Preview. Nothing changes until you press Import."
L.SHARE_PREVIEW = "Preview"
L.SHARE_IMPORT = "Import"
L.SHARE_PREVIEW_HEAD = "Import would change:"
L.SHARE_MORE = "...and %d more"
L.SHARE_PREVIEW_FIRST = "Press Preview first: SwagBag shows what changes before it changes anything."
L.SHARE_ERR_EMPTY = "Paste a share string first."
L.SHARE_ERR_NOTOURS = "That is not a SwagBag share string (they start with SWAGBAG:)."
L.SHARE_ERR_NEWER = "That string was made by a newer SwagBag. Update SwagBag, then import it."
L.SHARE_ERR_TOOLONG = "That string is too long for a share string; nothing was read."
L.SHARE_ERR_DAMAGED = "That string is damaged near \"%s\"; nothing was read. Copy it again."
L.SHARE_ERR_TYPE = "That string has a wrong value for %s; nothing was read."
L.SET_PAGE_PROFILES = "Profiles"
L.SET_PROFILES_NOTE = "A profile is a saved copy of your SwagBag settings (account-wide). Load one to switch; your"
	.. " previous settings are kept for Undo. A share string carries your settings (and, if you choose, your"
	.. " categories) to someone else; importing shows what changes first."
L.SET_PROFILES_SAVE = "Save your current settings"
L.SET_PROFILES_SAVE_BUTTON = "Save as a new profile"
L.SET_PROFILE_CURRENT = "%s (last used)"
L.SET_PROFILE_LOAD = "Load"
L.SET_PROFILE_DELETE = "Delete"
L.SET_PROFILES_SHARE = "Share"
L.SET_SHARE_EXPORT = "Copy settings"
L.SET_SHARE_EXPORT_CATS = "Copy with categories"
L.SET_SHARE_IMPORT = "Import"
L.SET_PROFILES_BACK = "Go back"
L.SET_PROFILES_UNDO = "Undo last load or import"
L.SET_PROFILES_DEFAULTS = "Defaults"
```

In `SwagBag/SwagBag.toc` (edit 1 of 2), find:

```text
Engine/Vendor.lua
```

and replace it with:

```text
Engine/Vendor.lua
Engine/Profiles.lua
```

In `SwagBag/SwagBag.toc` (edit 2 of 2), find:

```text
UI/SettingsVendor.lua
```

and replace it with:

```text
UI/SettingsVendor.lua
UI/SettingsProfiles.lua
UI/ShareBox.lua
```

Create `SwagBag/UI/SettingsProfiles.lua`:

```lua
-- SwagBag settings: the Profiles page (week 7, user pick 12). Save the current settings as a profile,
-- load or delete one, undo the last load or import, go back to the defaults, and share: a copyable
-- string (with or without the categories) and an import that previews first. Every click runs
-- /swagbag profile, so the window and the command never disagree (P2: the status line answers).
local _, SB = ...

local L = SB.L

local function nextName()
	local taken = {}
	for _, name in ipairs(SB.Profiles.List()) do
		taken[name] = true
	end
	local n = 1
	while taken[L.PROFILE_AUTO_NAME:format(n)] do
		n = n + 1
	end
	return L.PROFILE_AUTO_NAME:format(n)
end

local function rows()
	local run = SB.SettingsWindow.RunCommand
	local out = {
		{ kind = "note", label = L.SET_PROFILES_NOTE },
		{ kind = "actions", label = L.SET_PROFILES_SAVE, actions = {
			{ text = L.SET_PROFILES_SAVE_BUTTON, width = 160, run = function()
				return run("profile save " .. nextName())
			end },
		} },
	}
	for _, name in ipairs(SB.Profiles.List()) do
		local current = SB.Config.db.profile == name
		out[#out + 1] = { kind = "actions", label = current and L.SET_PROFILE_CURRENT:format(name) or name, actions = {
			{ text = L.SET_PROFILE_LOAD, width = 80, run = function()
				return run("profile load " .. name)
			end },
			{ text = L.SET_PROFILE_DELETE, width = 80, run = function()
				return run("profile delete " .. name)
			end },
		} }
	end
	out[#out + 1] = { kind = "actions", label = L.SET_PROFILES_SHARE, actions = {
		{ text = L.SET_SHARE_EXPORT, run = function()
			return run("profile export")
		end },
		{ text = L.SET_SHARE_EXPORT_CATS, width = 160, run = function()
			return run("profile export categories")
		end },
		{ text = L.SET_SHARE_IMPORT, run = function()
			return run("profile import")
		end },
	} }
	out[#out + 1] = { kind = "actions", label = L.SET_PROFILES_BACK, actions = {
		{ text = L.SET_PROFILES_UNDO, width = 160, run = function()
			return run("profile undo")
		end },
		{ text = L.SET_PROFILES_DEFAULTS, run = function()
			return run("profile reset")
		end },
	} }
	return out
end

SB.SettingsWindow.AddPage({ id = "profiles", title = L.SET_PAGE_PROFILES, rows = rows })
```

Create `SwagBag/UI/ShareBox.lua`:

```lua
-- SwagBag share box (week 7, user pick 12): one window for a profile's share string. Export: the string,
-- selected, ready for Ctrl+C. Import: paste a string, Preview says what would change (nothing changes
-- yet), Import applies it and keeps the old settings for /swagbag profile undo. A string is read with
-- patterns only (Engine/Profiles.lua): nothing in it ever runs. Plain frames only (opens in combat).
--   ShareBox.ShowExport(text)   ShareBox.ShowImport()   ShareBox.Preview() -> ok   ShareBox.Import() -> ok
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local SX = { MAX_LINES = 8 }
SB.ShareBox = SX

local ERRORS = { empty = "SHARE_ERR_EMPTY", notours = "SHARE_ERR_NOTOURS", newer = "SHARE_ERR_NEWER",
	toolong = "SHARE_ERR_TOOLONG", damaged = "SHARE_ERR_DAMAGED", type = "SHARE_ERR_TYPE" }

local function button(f, text, onClick)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(110, 22)
	b:SetText(text)
	b:SetScript("OnClick", Guard("share.click", onClick, "none"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	return b
end

local function build()
	local f = CreateFrame("Frame", "SwagBagShareBox", UIParent, "BackdropTemplate")
	f:SetSize(560, 380)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
	f:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
	f:EnableMouse(true)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOPLEFT", 10, -8)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -30)
	scroll:SetPoint("BOTTOMRIGHT", -30, 120)
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(510)
	edit:SetScript("OnEscapePressed", Guard("share.escape", function()
		f:Hide()
	end, "none"))
	edit:SetScript("OnTextChanged", Guard("share.textChanged", function(self, userInput)
		if not userInput then
			return
		end
		if SX.mode == "export" then -- read-only: typing puts the string back
			self:SetText(SX.text or "")
			self:HighlightText()
		else
			SX.data = nil -- a changed string must be previewed again
		end
	end, "none"))
	scroll:SetScrollChild(edit)
	f.edit = edit
	f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.status:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 10, 112)
	f.status:SetPoint("RIGHT", f, "RIGHT", -10, 0)
	f.status:SetJustifyH("LEFT")
	f.status:SetJustifyV("TOP")
	f.status:SetWordWrap(true)
	f.preview = button(f, L.SHARE_PREVIEW, function()
		SX.Preview()
	end)
	f.preview:SetPoint("BOTTOMLEFT", 10, 10)
	f.import = button(f, L.SHARE_IMPORT, function()
		SX.Import()
	end)
	f.import:SetPoint("LEFT", f.preview, "RIGHT", 8, 0)
	if SB.Theme then
		SB.Theme.Window(f, "dialog")
		SB.Theme.Text(f.title, "title")
		SB.Theme.Text(f.status, "small")
	end
	table.insert(UISpecialFrames, "SwagBagShareBox")
	f:Hide()
	return f
end

local function frame()
	SX.frame = SX.frame or build()
	return SX.frame
end

function SX.ShowExport(text)
	local f = frame()
	SX.mode, SX.text, SX.data = "export", text, nil
	f.title:SetText(L.SHARE_EXPORT_TITLE)
	f.status:SetText(L.SHARE_EXPORT_HINT)
	f.preview:Hide()
	f.import:Hide()
	f.edit:SetText(text)
	f:Show()
	f.edit:SetFocus()
	f.edit:HighlightText()
end

function SX.ShowImport()
	local f = frame()
	SX.mode, SX.text, SX.data = "import", nil, nil
	f.title:SetText(L.SHARE_IMPORT_TITLE)
	f.status:SetText(L.SHARE_IMPORT_HINT)
	f.preview:Show()
	f.import:Show()
	f.edit:SetText("")
	f:Show()
	f.edit:SetFocus()
end

-- What the pasted string would change, in the status area; nothing changes yet.
function SX.Preview()
	local f = frame()
	local data, err, detail = SB.Profiles.Parse(f.edit:GetText())
	if not data then
		SX.data = nil
		f.status:SetText(L[ERRORS[err] or "SHARE_ERR_DAMAGED"]:format(tostring(detail or "")))
		return false
	end
	SX.data = data
	local lines, shown = SB.Profiles.Preview(data), {}
	for i = 1, math.min(#lines, SX.MAX_LINES) do
		shown[i] = lines[i]
	end
	if #lines > SX.MAX_LINES then
		shown[#shown + 1] = L.SHARE_MORE:format(#lines - SX.MAX_LINES)
	end
	f.status:SetText(L.SHARE_PREVIEW_HEAD .. "\n" .. table.concat(shown, "\n"))
	return true
end

-- Import only what was previewed; the chat line is the answer (P2).
function SX.Import()
	local f = frame()
	if not SX.data then
		f.status:SetText(L.SHARE_PREVIEW_FIRST)
		return false
	end
	local ok, n = SB.Profiles.Import(SX.data)
	if not ok then
		f.status:SetText(L.SETTINGS_READONLY)
		return false
	end
	SX.data = nil
	f:Hide()
	SB.Print(L.PROFILE_IMPORTED:format(n))
	return true
end
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1356 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (72 files)`, `1356 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Profiles.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/SettingsProfiles.lua \
	SwagBag/UI/ShareBox.lua \
	spec/profiles_spec.lua
git -c user.email="294288393+Sharpened-Banana@users.noreply.github.com" -c user.name="lonezebra" commit -m "Week 7 Task 9: settings profiles (save, load, undo, defaults) and share strings with preview and validation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---


---
## In-game sessions

Five short sessions: SN1, LN1, VN1, BK1 and PF1. All five run on the **final merged build** (every task done, reviewed and fixed), as week 6's ruling P1 set; the "checks Task N" in each heading only says which task's work it checks. Then the week-7 exit check. They never block the build: findings come back as fixes.

Before every session:
- Claude installs the build first. The game currently runs an older copy, and the login line must say `v0.7.0`.
- If anything shows a red error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After the session, reply "<session> done" and the numbers of any steps that didn't match.

Chat lines start with `SwagBag: `. Amounts like `12s 34c` are examples: yours will differ.

### Session SN1: Equipment sets and the season's Venomstones (checks Tasks 1 and 2; about 10 minutes)

You need: an equipment set in Blizzard's Equipment Manager (the character window, C) with at least one of its pieces in your bags (an off-spec piece is ideal). Steps 7–9 need Ascendant Venomstones (from 12.1.5, live 2026-10-13); without any, do steps 7 and 8 anyway and skip step 9.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.7.0 loaded. Type /swagbag help for commands.`
3. Press **B**. Expected: a section `Equipment sets`, right under `Gear`, holding the pieces of your sets that are in your bags. A gray piece in a set (if you keep one) is there too, with no junk coin. If no section `Equipment sets` shows, none of your set pieces is in your bags: put one there (take it off in the character window) and press B twice.
4. Click the bags' search box and type `equipped`. Expected: only the items in `Equipment sets` stay bright; everything else dims.
5. Press **Esc** once to leave the search box, then clear it with its small x. Expected: everything is bright again.
6. Type `/swagbag mode list`. Expected: among the lines, `SwagBag: M+: on - opens Consumables, Keystone & Crests, Gear, Equipment sets`, `SwagBag: Raid: on - opens Consumables, Gear, Equipment sets` and `SwagBag: Delves: on - opens Consumables, Gear, Equipment sets`. (If you changed a mode's sections before, yours are kept: tell Claude.)
7. Look at the bottom of your bags (no click). Expected: after your crests, a Venomstone icon with how many your bags hold (for example `10`), if you carry any. None carried: no Venomstone entry, which is right.
8. Type `/swagbag report`. Expected: the box has a line that starts with `Season data: crest currencies` and goes on with `; season items in bags Ascendant Venomstone (280562)` and a number. Press Ctrl+C, paste the whole report to Claude (this line confirms the Venomstone's ID and whether the game made it a currency), then press **Esc**.
9. If you carry Venomstones: look at them in your bags. Expected: they are in `Keystone & Crests`. If you have used ten on a necklace, trinket or weapon (from 2026-10-20), look at that item. Expected: its item level top left is the new, higher level, and its track bottom left still reads like `M6/6`. Tell Claude what the item shows.

### Session LN1: the green "open or learn" glow and the uncollected star (checks Tasks 3 and 8; about 10 minutes)

You need: any of these in your bags, as many as you have: a cache or bag to open, a toy or mount or pet you have not learned, a decor item, a profession knowledge book ("... Treatise ..."), and a piece of gear whose appearance you do not have (a transmog vendor or a dungeon drop).

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.7.0 loaded. Type /swagbag help for commands.`
3. Press **B**. Expected: a soft green glow over each cache, each toy, mount or pet you have not learned, each decor item you own none of, and each knowledge book. Nothing else glows green.
4. Look at your knowledge items (no click). Expected: each one glows. If one does not, rest the mouse on it, note its name, and tell Claude (it is added by name or ID).
5. Look at gear whose look you have not collected (no click). Expected: a small purple `*` at the middle of its right edge. Gear whose look you have does not have one.
6. Learn one green item: right-click a toy (or a pet, or a mount) you have not learned. Expected: it is learned and leaves your bags. If you carried two of it, the other one stops glowing within a second.
7. Move the mouse off the bags. Type `/swagbag overlays learn off`. Expected: `SwagBag: Overlay learn is now off.`, the green glows are gone, and an unlearned toy, mount or pet now shows the purple `*` instead.
8. Type `/swagbag overlays learn on`. Expected: `SwagBag: Overlay learn is now on.` and the glows are back; the `*` on toys, mounts and pets is gone again (gear keeps its `*`).
9. Click the bags' search box and type `uncollected`. Expected: only items with a `*` (and unlearned toys, mounts and pets) stay bright. Press **Esc**, then clear the box with its small x.
10. Type `/swagbag settings overlays`. Expected: the Overlays page has the rows `Green glow on items to open or learn (caches, new toys, mounts, pets, decor, knowledge)`, `Lock mark on locked items` and `Star on gear whose look you have not collected (and new toys, mounts, pets)`, each with `On` highlighted first and `Off` next to it.
11. Close the settings window with its X.
12. Look at a lockbox if you carry one (no click). Expected: it glows green too (it holds loot even if you cannot open it yet). Tell Claude whether that is fine for you.

### Session VN1: selling junk, repairing and locking items (checks Tasks 4 and 5; about 15 minutes)

You need: a vendor who repairs (a blacksmith or armorer); a few gray junk items (more than 12 is a bonus); gear that is a little damaged; one item you never want to sell (a gray one is best for step 10).

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.7.0 loaded. Type /swagbag help for commands.`
3. Type `/swagbag sell`. Expected: `SwagBag: Auto-sell junk at vendors: on. Type /swagbag sell on, sell off, or sell junk (at a vendor).`
4. Type `/swagbag repair`. Expected: `SwagBag: Repair at vendors: own. Type /swagbag repair own, repair guild, or repair off.`
5. Press **B**. Pick up the gray item you want to keep (left-click it), then drop it on the small `Lock` button right of the search box (or click `Lock` while you hold it). Expected: chat shows `SwagBag: Locked: <its name>. SwagBag never sells it, and it shows a small lock.`, the item is back in its slot, and it shows a small padlock at the top middle.
6. Move the mouse off the bags. Rest the mouse on the locked item. Expected: its tooltip has the line `Locked in SwagBag: never sold by SwagBag`. Move the mouse off it.
7. Click `Lock` with nothing on the cursor. Expected: `SwagBag: Locked items: 1. Drag an item onto Lock (right of the search box) to lock or unlock it. Type /swagbag lock list or lock clear.`
8. Move the mouse far from the bags. Right-click the vendor. Expected, within a few seconds:
   - your gray items leave the bags one by one (each leaves a dimmed placeholder; nothing else moves);
   - the locked gray item stays;
   - one chat line `SwagBag: Sold N junk items for ...` (for example `Sold 5 junk items for 1g 2s 3c.`); if you had more than 12, the same line goes on with `... more junk items wait (Blizzard's buyback keeps only the last 12): type /swagbag sell junk.`;
   - then `SwagBag: Repaired everything for ...` if your gear was damaged.
9. Click the vendor's **Buyback** tab. Expected: every item SwagBag sold is there. (If more than 12 waited, type `/swagbag sell junk` now. Expected: the next ones sell and one line says so.)
10. Right-click the **locked** gray item yourself. Expected: the vendor buys it (SwagBag cannot stop a right-click), and chat shows `SwagBag: You sold <its name>, which you locked. Buy it back from the vendor's Buyback tab if that was a mistake.`
11. Buy it back from the Buyback tab. Expected: it returns to your bags and still shows the padlock.
12. Put two or three gray items back into your bags (buy them back). Pick up any other item with a left-click and keep it on the cursor. Type `/swagbag sell junk` and press Enter. Expected: nothing is sold while the item is on the cursor. Put the item back with a left-click on its own slot and move the mouse off the bags. Expected: within a second the gray items sell one by one, then `SwagBag: Sold N junk items for ...`. (With no gray item left the answer is `SwagBag: No junk to sell: no gray items a vendor pays for (locked and equipment-set items are never sold).`)
13. Walk away until the vendor window closes. Type `/swagbag lock list`. Expected: `SwagBag: Locked: <its name>.`
14. Type `/swagbag settings vendor`. Expected: the Vendor page: `Sell gray junk by itself at every vendor` with `On` highlighted and `Off`; `Repair at vendors` with `Your gold` highlighted, `Guild bank first` and `Off`; a line about combat; `Lock or unlock an item (never sold by SwagBag)` with `Drop an item here`; `Locked items: 1` with `List them` and `Unlock all`.
15. Click `Off` in the first row. Expected: the status line reads `Gray junk is no longer sold by itself. Type /swagbag sell junk at a vendor to sell it.`
16. Click `On` in the first row. Expected: `Gray junk is now sold by itself at every vendor (never locked or equipment-set items).`
17. Close the settings window with its X.

### Session BK1: section actions and the gold glow at the bank (checks Tasks 6 and 7; about 15 minutes)

You need: a banker and a vendor; a few trade goods in your bags (a `Trade Goods` section); something worth 100 g or more (a stack of herbs or ore, a BoE). Auctionator helps but is not needed.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.7.0 loaded. Type /swagbag help for commands.`
3. Type `/swagbag worth`. Expected: `SwagBag: Gold glow at the bank: items worth 100g or more a stack (Auctionator prices, else what a vendor pays). Type /swagbag worth <gold>, worth top <percent>, or worth off.`
4. Press **B**. Shift+right-click the `Trade Goods` header. Expected: chat shows `SwagBag: Section actions work at a vendor (Sell all) or a bank (Send all). Open one, then Shift+right-click a section's header.` Nothing moves.
5. Move the mouse far from the bags. Right-click a banker. Expected: SwagBag's bank opens; in your bags and in the bank, stacks worth 100 g or more glow **gold**.
6. Type `/swagbag worth 1`. Expected: `SwagBag: Gold glow at the bank: items worth 1g or more a stack.`, and many more items glow gold.
7. Type `/swagbag worth 100`. Expected: `SwagBag: Gold glow at the bank: items worth 100g or more a stack.`, and only the valuable ones glow again.
8. Rest the mouse on the `Trade Goods` header in your bags. Expected: a tooltip `Trade Goods` with `Shift+right-click: Send all to the bank or the warband bank`.
9. Shift+right-click the `Trade Goods` header. Expected: a small menu below it with `Send all to bank (N)`, `Send all to warband bank (N)` and `Cancel` (N: how many it would move).
10. Click `Cancel`. Expected: the menu closes; nothing moved.
11. Shift+right-click the `Trade Goods` header again, then click `Send all to warband bank (N)`. Move the mouse far from both windows. Expected: the items move one by one into the **warband** bank group (placeholders stay in your bags), then chat shows `SwagBag: Sent N items from Trade Goods to the warband bank.` No red "Interface action failed" and nothing about "blocked". If they went to the character bank instead, tell Claude the exact line (D19's fallback).
12. Click Blizzard's bank tab that is **not** selected (in tiny mode the tabs hang under SwagBag's bank window). Then send a section to the other bank: Shift+right-click a section with items and click `Send all to bank (N)`. Expected: they go to the **character** bank, whichever tab you clicked.
13. Right-click any ordinary bag item. Expected: it goes into the bank group that says `deposits go here` (Blizzard's own deposit, unchanged).
14. Walk away until the bank closes. Expected: the gold glows are gone.
15. Right-click a vendor. Shift+right-click a section with something to sell (for example `Junk` or `Trade Goods`). Expected: a menu with `Sell all (N)` and `Cancel`.
16. Click `Sell all (N)`. Expected: a Blizzard-style dialog `Sell N items from <section> for about <amount>? Locked items and items in an equipment set stay.` with `Yes` and `No`.
17. Click `No`. Expected: nothing is sold.
18. Do step 15 and 16 again and click `Yes`. Move the mouse off the bags. Expected: the items sell one by one, and chat shows `SwagBag: Sold N items for <amount>.` (More than 12: the line says how many wait and to use Sell all again.)
19. Near a vendor with a training dummy (most capital cities have both), start combat with the dummy, open the vendor, Shift+right-click a section and click `Sell all (N)`. Expected: no question, and `SwagBag: In combat: nothing was moved. Try again once combat ends.` (The auto-sell also says `SwagBag: In combat: selling junk and repairing wait until combat ends, if the vendor is still open.`) Leave combat. If no dummy is near a vendor, skip this step.
20. Type `/swagbag settings bank`. Expected: a row `Gold glow at the bank on items worth` with `100g or more` highlighted, then `500g or more`, `1000g or more`, `Your top 10%` and `Off`.
21. Close the settings window with its X.

### Session PF1: profiles and share strings (checks Task 9; about 10 minutes)

You need: nothing special.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.7.0 loaded. Type /swagbag help for commands.`
3. Type `/swagbag profile save Main`. Expected: `SwagBag: Saved your current settings as the profile "Main".`
4. Type `/swagbag free all`. Expected: `SwagBag: Every free slot is shown again.` Press **B**: every empty slot shows in Free. Press **B** again to close the bags. (Any setting works; this one is easy to see.)
5. Type `/swagbag profile load Main`. Expected: `SwagBag: Loaded the profile "Main". Your previous settings are kept: /swagbag profile undo brings them back.` Press **B**: Free shows one slot with a number again.
6. Type `/swagbag profile undo`. Expected: `SwagBag: Your settings are back as they were before the last load, import or reset.`, and the open bags show every empty slot again.
7. Type `/swagbag profile load Main`. Expected: the same line as step 5; Free shows one slot with a number. Press **B** to close the bags.
8. Type `/swagbag profile export`. Expected: chat shows `SwagBag: Your settings' share string is in the box: press Ctrl+C to copy it.`, and a box titled `SwagBag share string` shows a long line starting with `SWAGBAG:1:`, selected.
9. Press **Ctrl+C**, then press **Esc**. Expected: the box closes.
10. Type `/swagbag profile import`. Expected: `SwagBag: Paste a share string into the box, then press Preview.`, and a box titled `Import a SwagBag share string` with `Preview` and `Import` buttons.
11. Click into the box and press **Ctrl+V**. Click `Import`. Expected: the box says `Press Preview first: SwagBag shows what changes before it changes anything.`
12. Click `Preview`. Expected: `Nothing would change: your settings already match.` (it is your own string).
13. Click into the box, delete the first few characters (so it no longer starts with `SWAGBAG:`), and click `Preview`. Expected: `That is not a SwagBag share string (they start with SWAGBAG:).`
14. Close the box with **Esc**. Type `/swagbag settings profiles`. Expected: the Profiles page: a note, `Save your current settings` with `Save as a new profile`, a row `Main (last used)` with `Load` and `Delete`, `Share` with `Copy settings`, `Copy with categories` and `Import`, and `Go back` with `Undo last load or import` and `Defaults`.
15. Click `Save as a new profile`. Expected: the status line reads `Saved your current settings as the profile "Profile 1".`, and a row `Profile 1 (last used)` appears.
16. Click `Delete` in the `Profile 1` row. Expected: `Deleted the profile "Profile 1". Your current settings are unchanged.`
17. Close the settings window with its X.

## Week 7 exit check

1. Claude installs the week-7 build, at the end of Task 9 (after review and fixes), and you fully restart the game.
2. Play normally for a day, with keys, a vendor and a bank visit. Expected: no red errors; junk sells and gear repairs at vendors; nothing locked is sold by SwagBag; nothing moves under your mouse.
3. Type `/swagbag report` and paste it to Claude. Expected:
   - `Safe Mode: bags=off bank=off`;
   - `Failed checks: none` (an optional new check that failed, like `C_HousingCatalog.GetCatalogEntryInfoByItem`, only switches its feature off: copy the line to Claude);
   - a `Season data:` line.


## Spec updates at week end

Recorded in the week-7 ledger and applied to `docs/superpowers/specs/2026-09-30-swagbag-design.md` at week end (this plan commits only the plan file):
- **§1.3 Non-goals / §5.2:** "Send all to bank / warband bank" (Task 6) chooses the bank type on the user's click through `UseContainerItem`'s own argument and neither reads nor writes Blizzard's selected type, like Deposit warbound (AC2.8). Right-click deposits still follow the selected tab. "Paste-string import of Syndicator/Baganator-syntax category strings" stays planned; SwagBag's own share strings (§8 new subsection, Task 9) are a separate, versioned format.
- **§2.1:** new features F17 Auto-sell junk and auto-repair (D10–D13), F18 Item locks (D14–D17), F19 Section actions (D18–D21), F20 Profiles and share strings (D24–D27), each with ACs from this plan's tests. **F9 / AC9.1** gains the green "open or learn" glow, the lock mark and the uncollected star, each with its switch (AC9.2). **F10** gains the worth-money glow at the bank (D22), moved from v1.1.
- **§2.2:** v1.1 "worth-money highlight" and "uncollected transmog", and v1.2 "uncollected pet/toy" are delivered in week 7 (decor: the green glow only).
- **§4.2 rule 5 / §4.3:** SwagBag's own item moves (the mover) follow rule 5: an item on the cursor holds every step without a limit while the vendor or bank is open; an item's button under the mouse holds it up to 20 retries, then it stays; a moved item leaves a placeholder.
- **§6.3:** the M+, Raid and Delves default sets include Equipment sets (`c_sets`); `c_sets` joins every mode set that opens Gear.
- **§7.3:** `locked` means locked by the user (Engine/Locks.lua); the client's lock is `inuse`; `uncollected` (appearances, toys, mounts, pets) is registered; `equipped` feeds the new category.
- **§7.6:** the default set gains `Equipment sets` (`c_sets`, `equipped`, priority 92, right after Gear).
- **§8.2:** `SwagBagDB.locks`, `.profiles`, `.profile`, `.backups.profile` (schema stays 2, read defensively); settings `vendor.autoSell`, `vendor.repair`, `prices.worth`, `prices.worthGold`, `prices.worthTop`, `overlays.learn`, `overlays.lock`, `overlays.uncollected`.
- **§10.4:** the report's `Season data` line. **§10.5:** `sell [on|off|junk]`, `repair [own|guild|off]`, `lock [list|clear]`, `worth [<gold>|top <percent>|off]`, `profile [save|load|delete <name>|reset|undo|export [categories]|import]`.
- **§13.2 item 4:** the season data file holds crest IDs and words, currency words, season items (Ascendant Venomstone 280562, to be confirmed in SN1) and knowledge items.
- **§1.4 P2:** "answers exactly once": a run that takes time answers when it ends.

## Spec coverage (week-7 scope → task)

| Requirement (from the user's picks) | Task |
|---|---|
| Pick 1: an Equipment sets category; placement and priority vs Gear/BoE/WuE; M+/Raid/Delves use it; never junk or sellable | T1 (D1–D4); T4 `Vendor.Protected`; T6 Sell all |
| Pick 2: Venomstones in the footer next to the crests; the ID researched, with a data-driven list and a capability probe, and how the user confirms | T2 (D5, D6); SN1 steps 7–8 |
| Pick 2: the upgrade-track / item-level overlay on Venomstone-boosted items | T2 test (D7); SN1 step 9 |
| Pick 2: season data data-driven where hard-coded | T2 (D6: crests, currencies, items; dungeons and teleports already were) |
| Pick 3: a glow on items to open, learn (knowledge, toys, mounts, pets, decor); C_* via the Adapter; its own switch, on | T3 (D8, D9) |
| Pick 4: auto-sell grays (never locked, never set items), buyback-safe, one chat line; auto-repair with own gold, guild option off; nothing in combat; settings and commands; MERCHANT_SHOW via the Adapter; the vendor mode and P5 | T4 (D10–D13), T5 (locked) |
| Pick 5: lock / unlock gesture within the constraints, per item, account-wide, a lock mark, never auto-sold or sold-all, the manual-sale answer, keyword `locked` | T5 (D14–D17), T6 |
| Pick 6: header menu (Send all to bank / warband bank at a bank; Sell all with a confirmation at a vendor); bank type researched; no conflict with week-4/6 header clicks; small steps, out of combat, never under the mouse; Mail all decided | T6 (D18–D21), T4 (the mover) |
| Pick 7: the worth-money glow at the bank in bags and bank windows; 100 g fixed default, top-X % alternative; Auctionator, vendor fallback; a Settings row and a command | T7 (D22) |
| Pick 9: an uncollected marker on gear, pets, toys, mounts; own switch, on; secret-safe, cached, no per-frame cost | T8 (D23), T3 (shared cache) |
| Pick 12: named profiles (save, switch, delete, reset), account-wide; export with optional categories; import with preview and validation; never load code; a versioned compact format; schema 2 | T9 (D24–D27, D30) |
| Version 0.7.0 | T1 |

## How this plan was checked (while writing it)

- Every task was first built on a scratch clone at `/tmp/sb7` (outside the repo), one commit per task, test-first. Every block in this file was then generated from those commits' diffs by a script: each find block is grown line by line until it occurs exactly once in the file as it is after the earlier edits, and starts and ends on a non-blank line; the script re-applied every block to the old file and compared the result with the commit's file.
- **Replay.** A fresh clone of `a1f7f86` at `/tmp/sbr` was driven by a script that reads this file: for each task it applies the Step 1 blocks, runs the suite, applies the Step 3 blocks, runs the suite and `scripts/check.sh`. Every Step 2 count and FAIL list, every Step 4 total and every Step 5 `ALL CHECKS PASSED` and TOC count above is that script's output. The replayed tree was compared file by file with the scratch build (`SwagBag/`, `spec/`, `.luacheckrc`): identical. Final total: **1356 passed, 0 failed**.
- **Mutations.** Every mutation listed under a Step 2 (87 in all) was applied, one at a time, to its own task's finished tree (an export of that task's commit), and the full suite run: every one made its named test fail.
- Greps on the final tree:
  - no `C_`/`Enum.` outside `SwagBag/Core/Adapter.lua`;
  - none of the forbidden tokens (a draft comment in `UI/LockButton.lua` that named the forbidden click scripts was reworded; check.sh caught it);
  - no `OnUpdate`; no `load`/`loadstring` anywhere in `SwagBag/` (the share string is parsed with patterns only);
  - no `Config` call at load (the load-order tests stay green);
  - no `%s` given a boolean (format51 runs on every spec).
- API names and IDs: see "What the week relies on"; the installed addons were read for names and call shapes only.

## Self-review

1. **Pick coverage.** Each of the nine picks maps to a task in "Spec coverage", in the user's order, and every question in the brief has a decision row: placement and priority (D1), modes (D2), never sellable (D3); the Venomstone ID, the probe and how to confirm (D5, G1), the overlay (D7); the glow's sources and switch (D8); the auto-sell's safety, the repair, combat, MERCHANT_SHOW, the vendor mode and P5 (D10–D13); the lock key, gesture, manual-sale answer (not feasible, so a chat warning) and keyword (D14–D17); the header gesture, the bank-type research and routing, confirmations, Mail all (D18–D21); the worth line (D22); the star (D23); profiles, the string format, validation and the import flow (D24–D27).
2. **Placeholder scan.** No "TBD", "TODO", "similar to", or test-free step. Every code step is a complete block (the replay applies them as written). The in-game expectations quote Locale strings verbatim; where a line holds the player's own numbers (counts, amounts, names) the step says so.
3. **Type and name consistency.** These names are the same in every task that uses them: `c_sets` (T1; Tasks 4 and 6 read `inEquipmentSet`); `SB.Crests.ids/words/currencyWords/currencies/items/knowledge` (T2 → T3); `Collections.Learn/Uncollected/Invalidate/REFRESH`, `m.collected` (T3 → T8); `Mover.Start/Busy/IsBusy/Stop/DELAY/RETRY/MAX_WAITS`, `result.moved/left/kept/skipped/why` (T4 → T5, T6); `Vendor.open/Protected/Junk/Sell/Repair/Money/BUYBACK/WatchLocked` (T4 → T5, T6); `A.SellItem/MoveToBank/AllowedInBank/ShiftDown/BuybackLinks` and the mock's `m.used/m.onUse/m.notAllowed/m.shift/m.buyback` (T4–T6); `SB.Locks.*`, `SB_LOCKS_CHANGED`, `LockButton.Drop` (T5); `W.SectionSlots`, `SectionHeaders.onClick(id, button, header)/onEnter/onLeave` (T6); `Prices.WorthThreshold`, `Ov.worthMin/IsWorth/RefreshWorth` (T7); the overlay regions `glow`, `lock`, `star` and `Ov.NAMES` (T3, T5, T8); `Profiles.*`, `ShareBox.*` (T9). The Locale keys quoted in SN1, LN1, VN1, BK1 and PF1 were checked against the blocks.
4. **Review Focus.** Each of the seven lines names its pinning tests, and each of those tests is in its owning task's Step 1.
5. **Global Constraints.** No `C_`/`Enum.` or another addon's global outside the Adapter (StaticPopup and GameTooltip are UI globals SwagBag already used). No click script or hook on an item button: locking is a drop on SwagBag's own button, and section actions start from a header. Every new script runs under `ErrorTrap.Guard` or `Run` with the labels listed in P6. Every user-visible string is in `enUS.lua`. Every new setting has a default; new saved tables are read defensively; the schema stays 2. No `OnUpdate`; collection answers are cached; the worth line is worked out once per bank visit.
6. **Known limits, stated in the plan.** A locked item can still be sold by hand (D16); lockboxes glow green (D8, G13); knowledge items other than "... Treatise ..." need their IDs (G9); the Venomstone ID is PTR data until SN1 (G1); `UseContainerItem`'s routing argument is documented, not yet seen by SwagBag (G4, with D19's fallback).
