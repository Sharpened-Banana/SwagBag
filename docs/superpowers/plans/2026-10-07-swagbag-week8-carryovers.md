# SwagBag Week 8: Carry-overs (the list view in the bank and guild bank, the guild bank's late items, Syndicator loaded mid-session, and the week-7 polish). Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ] `) syntax for tracking.

**Goal:** the items the week-5, week-6 and week-7 ledgers deferred, in this order of priority, so the earlier ones ship first if time runs out:
1. **List view in the bank and guild bank windows** (week-5 ledger "Final: deferred → week 6: list view for bank/guild windows (D9)"). The bags have had it since week 5 (`UI/ListRows.lua`, `Engine/Sort.lua`, the column bar). The bank and the guild bank get the same rows, columns, order and settings model, inside their groups (Character bank / Warband bank; one group per guild tab). Their item buttons are only scaled (`SetScale`, as in the bags, with the F6 self-check and fallback), never reparented or created in combat; deposit, withdraw and right-click are unchanged.
2. **The guild bank's late items** (week-5 Task 9 "guild bank has the same pending-item gap"): an item whose data the client has not loaded yet waits in New; when its data arrives the guild window regroups promptly, held while a button that would move is under the mouse or an item is on the cursor (P5), as the alt viewer has done since week 5 (F22).
3. **Syndicator loaded mid-session** (week-5 ledger): if Syndicator loads after login, SwagBag registers its callbacks then, and the tooltip counts and an open alt viewer follow the provider that answers now, without `/reload`.
4. **Week-7 polish** (week-7 ledger, minors and the FINAL lines): gray rings, necklaces and trinkets (no appearance) sell as junk again; `L.VENDOR_KEEPS` mentions gear whose look the game cannot tell; the junk coin's protection check is cached on the draw path; the collections' draw path is secret-safe (the T3 FINAL item); "1 lock" strings read as one; an imported category priority of 90 or more is lowered, never refused; the `|cn` escape rule no longer refuses `herb|cname`; "your top X %" is worked out again when the bank's contents change.
5. **Not this week:** the week-6 bank-speed part 2. It waits on session TF1's in-game numbers (`/swagbag report`'s bank layout phases, week 6 D20), which have not come back yet.

Tests go from 1394 to **1424**.

**Architecture:**
- (1) `UI/GroupView.lua` (the bank's, the guild bank's and the alt viewer's contents) learns the bags window's list: a third view `"list"` with one column of 24 px rows per section, each slot's own button scaled to the row (`SetScale`; offsets divided by the scale, as `Buttons.Place` does), the row's texts from `UI/ListRows.lua` (`cfg.rows`), each section in `Engine/Sort.lua`'s order, ghost rows for placeholders, free-tile rows, the row under the mouse holding its button (P5), and the F6 check before a list is drawn (a scale that does not take: that layout draws as categories, recorded under `"none"`, said once per opening). `UI/ListRows.lua` gains per-window texts and tooltip (`opts`), `ListRows.ColumnBar` and `ListRows.SortedText`. `Sort.Save` announces `SB_LIST_SORTED`: one shared order (`bags.list`), every drawn list regroups. `UI/BankWindow.lua` and `UI/GuildBankWindow.lua` cycle categories → list → grid and show the column bar under their deposit line.
- (2) `UI/GuildBankWindow.lua` remembers pending items (`GW.pending`) and lays the window out again through `GroupView.RequestLayout("loaded")` when `ITEM_DATA_LOAD_RESULT` / `GET_ITEM_INFO_RECEIVED` names one.
- (3) `Providers/Syndicator.lua` registers Syndicator's callbacks once (`P.Hook`), at login or on `ADDON_LOADED` for Syndicator (`Adapter.IsSyndicatorAddon`), and announces `SB_ALTDATA_CHANGED` at once when it hooks late; `UI/OfflineWindow.lua` re-reads its character when the answering provider is no longer the one it read from.
- (4) `Engine/Collections.lua` (`NO_LOOK`, a `plain()` secret guard, `LookUnknown(r, fast)`), `Engine/Vendor.lua` (`Protected(r, fast)`), `UI/Overlays.lua` (the cached form on the draw path; `SB_BANK_CHANGED` for the top-% line), `Engine/Locks.lua` and `Engine/Profiles.lua` (the clamp and the narrower `|cn` rule), `UI/BankWindow.lua` (`SB_BANK_CHANGED`), `Locale/enUS.lua`.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105; 12.1.5 goes live 2026-10-13). LuaJIT 2.1 for tests. The in-repo runner `spec/runner.lua`. luacheck. bash `scripts/check.sh`. git.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`. Executors read the spec alongside this plan. This plan implements:
- spec §2.2 v1.3 (the list view) for the bank (F2) and guild bank (F16) windows, under §4 (the button and placeholder contract: §4.1 buttons never reparented or created in combat, §4.2 rule 5, §4.3 placeholders) and the week-5 F6 rule;
- §4.3 for the guild bank's pending items (the alt viewer's F22 rule, week 5);
- §3.3 (providers: Syndicator becomes available during a session);
- AC17.2 (what is never sold) and AC10.4 (the worth glow) refinements, §7 profile/share-string validation (week 7 F20), and P2 wording.
The spec text is updated at week end (see "Spec updates at week end").

Ledgers (binding rulings W3-*, W4-*, W5-*, week 6, week 7 R1–R22): `docs/superpowers/plans/2026-10-02-swagbag-week3-ledger.md`, `2026-10-03-swagbag-week4-ledger.md`, `2026-10-04-swagbag-week5-ledger.md`, `2026-10-05-swagbag-week6-ledger.md`, `2026-10-06-swagbag-week7-ledger.md`. Week-7 plan (style and interfaces): `docs/superpowers/plans/2026-10-06-swagbag-week7-research-picks.md`.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag`. The path contains a space, so always quote it. Run every command in this plan from the repo root:

```bash
cd "/Users/lonezebra/Local Documents/AI-Projects/SwagBag"
```

**Branch:** `week8` is already checked out. It was made from `main` at `ab9d5a2` (v0.7.0, week 7 merged). The suite has 1394 tests. No task creates or switches branches.

**The code at `ab9d5a2` is the source of truth.** Every anchor below was read from it and replayed (see "How this plan was checked"). These interfaces are used as they are on `ab9d5a2`:
- `SB.On`, `SB.Emit`, `SB.Debounce(key, delay, fn, window)`, `SB.OutOfCombat(fn, label, window)`, `SB.ErrorTrap.Run/Guard/OnError(label, window, message, stack)`, `SB.Print`, `SB.Slash.Register/Dispatch`.
- `SB.Config.Get/Set/readOnly/db/UI()`; `Config.Set` emits `SB_CONFIG_CHANGED(path)` and returns false while read-only.
- `SB.GroupView.New(cfg)` and its view `v` (`Layout`, `RequestLayout`, `Changes`, `Retry`, `Restack`, `Relabel`, `RefreshTotals`, `ForEachSlot`, `Record`, `SetRecord`, `GroupOf`, `Size`, `IsOpen`, `Clear`, `stats`), `GV.SLOT/GAP/PAD/RETRY`.
- `SB.ListRows.New/Columns/Texts`, rows `Place/Paint/Ghosts/HideAll/SetDimmed/IsMouseOver`; `SB.Sort.COLUMNS/Spec/Save/Next/Value/DisplayOrder`; the bags window's `W.SortList`, `W.RefreshColumns`, `W.columnButtons`, `W.LIST_ROW` (24), `W.LIST_WIDTH` (480), `W.LIST_NEW_ROWS` (8), `W.ROW_TEXT_GAP` (4), `W.SCALE_EPSILON`.
- `SB.BankWindow` (`BW.view`, `BW.Layout`, `BW.Reflow`, `BW.ToggleView`, `BW.Flash`, `BW.searchBox`, `BW.HEADER` 80) and `SB.GuildBankWindow` (`GW.view`, `GW.cache`, `GW.Refresh`, `GW.Flash`, `GW.BAG_BASE` 100, `GW.HEADER` 80); `SB.GuildButtons.Get/Paint`; `SB.Buttons.Get/Place/SetDimmed/SetFreeCount/AcquirePlaceholder/DIM_ALPHA`.
- `SB.Items.DescribeLink` (`pending`), `SB.AltData.Source/Characters/Container/RegisterProvider`, `SB.SyndicatorProvider`, `SB.Adapter.SyndicatorOnUpdate/SyndicatorAPI/GuildTooltip/SlotTooltip/IsSecret/AppearanceKnown`, `SB.OfflineWindow` (`OW.Layout`, `OW.key`, `OW.scroll`).
- `SB.Collections.Learn/Uncollected/LookUnknown`, `SB.Vendor.Protected`, `SB.Overlays.Context/RefreshWorth/worthMin/WORTH_DELAY`, `SB.AtBank`, `SB.Locks`, `SB.Profiles.Parse/Preview/Export` (`MAX_PRIORITY` 90).
- Test helpers: `spec/helpers/loader.lua`, `fakeframe.lua` (`Fake.New`, `Fake.Fire`, `Fake.Strict`, `Fake.created`, `Fake.Install/Uninstall`), `uienv.lua` (`Env.ENGINE`, `Env.LoadBank`, `Env.LoadGuild`, `Env.PaintGlobals`), `spec/fixtures/items.lua`, `spec/mock_adapter.lua`, and `format51` (installed by the runner).



## Global Constraints

- Target: World of Warcraft Retail 12.1.x only. TOC `## Interface: 120100, 120105`. English only. This week's version is `0.8.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
- License: `## X-License: All Rights Reserved`. Clean-room: no code is copied from any other addon. No new Blizzard API is used this week; the only new name is the folder name Syndicator loads under (`"Syndicator"`, an `ADDON_LOADED` argument), kept in the Adapter.
- TOC metadata: `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## OptionalDeps: Auctionator, Syndicator, ElvUI`. No file is added or removed this week: the TOC stays at 72 files.
- All addon code is Lua 5.1: no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets a string or a number, never a boolean or nil. Every spec runs under `spec/helpers/format51.lua`, which makes the tests as strict as WoW.
- `SwagBag/Core/Adapter.lua` is the only file that may name a `C_*` namespace, `Enum`, ElvUI or Syndicator globals, **comments included**. `scripts/check.sh` fails on `C_X.`/`Enum.` and on a bare `C_X` name outside the Adapter (week 7, ruling R5); other addons' globals stay review-enforced. Every other file calls `SB.Adapter.*`. This week adds `A.SYNDICATOR_ADDON` and `A.IsSyndicatorAddon(name)` (Task 4). Files under `spec/` may name them as test data.
- Forbidden anywhere in `SwagBag/`, comments included (spec §5.3, `scripts/check.sh`): `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`. `SetCurrentGuildBankTab` is never called.
- **Secure item buttons** (`ContainerFrameItemButtonTemplate`, the bags' and the bank's) are never reparented, never created in combat, never re-`SetID`'d, and get **no** click script or click hook of any kind. The bank list only **scales** them (`SetScale`, legal in combat: spec §4.1, as the bags' list since week 5) and moves them (`ClearAllPoints` + `SetPoint`); the guild bank's buttons are SwagBag's own plain `ItemButton`s (week 3) and are scaled the same way. **F6 / ruling W5-1:** a list row never shows a full-size button: every button is scaled before a list is drawn, and if a scale does not take, that layout draws as categories instead (recorded under `"none"`, one chat line per opening); a button whose scale changes later is hidden, row and all, until a held layout follows.
- P1: every setting ships with a chosen default, and its alternative sits next to it in the same place. Options are phrased as choices, never as abstract toggles. This week's views keep their defaults (`bank.view` and `guildBank.view` stay `"sections"`); `"list"` is the next choice on the same view button.
- P2: every command, button and settings choice answers **exactly once**, with a chat line, a title flash or the settings window's status line. A column click answers in its own window's title; the other open lists regroup silently (they were not clicked).
- P5 / spec §4.2 rule 5: nothing moves under the mouse or while an item is on the cursor. In a list a row under the mouse holds its button too. Held moves retry 300 ms later through `SB.Debounce`, never `OnUpdate`.
- **P6.** Every WoW entry point runs inside `SB.ErrorTrap.Run` or `Guard`. The window labels this week:
  - `"bank"`: the bank's and the guild bank's column bars (`bank.listColumn`, `guild.listColumn`), the guild bank's item-data listener (`ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED`) and its debounced regroup (`guild.loaded`), the `SB_LIST_SORTED` listeners of both windows;
  - `"bags"`: the bags window's `SB_LIST_SORTED` listener;
  - `"none"` (recorded, never Safe Mode): every list row script (`list.rowTip`, `list.rowClick`, as since week 5), the list's F6 records (`bank.listScale`, `guild.listScale`), the Syndicator hook and its `ADDON_LOADED` listener, the alt viewer's `SB_ALTDATA_CHANGED` listener and its 300 ms retry (`offline.source`), and the Overlays' `SB_BANK_CHANGED` listener.
- P8: every user-visible string lives in `SwagBag/Locale/enUS.lua`. `spec/locale_spec.lua` fails on an undefined `L.KEY`.
- **Plain frames only, may be created in combat:** list rows (a `Frame` with font strings), the column bars (`Frame` with plain `Button`s). Themes restyle them through `SB.Theme.Text/Row`.
- **Settings and saved data (schema stays 2):** no new settings key. `bank.view` and `guildBank.view` may now hold `"list"` (their defaults stay `"sections"`; the profile validator accepts the new word). The list's order is the existing `bags.list.sort` / `bags.list.desc`, now shared by all three windows. No new saved table. Only values somebody wrote are stored, so no migration. Every writer refuses while `Config.readOnly` and says `L.SETTINGS_READONLY`.
- No file calls `Config` at load time (the load-order tests stay green). Every `OnHide` handler starts with `if self:IsShown() then return end`.
- No `OnUpdate` anywhere. Idle CPU with every window closed is 0. A list paints row texts only for slots it draws; the look answers the junk coin needs are cached per link (Task 5).
- Every critical test names the mutation that must make it fail. Each task lists its mutations under Step 2.
- **Tooling (binding, as in weeks 1–7):** tests run with `luajit spec/runner.lua spec/*_spec.lua` on the in-repo runner (`describe`, `it`, `before_each`, `after_each`, `assert.equal/same/truthy/falsy/is_nil/has_error`). Where a test fakes a frame method WoW has, it fakes it the way WoW behaves. CI is the local `scripts/check.sh`. Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
- Test totals are cumulative from 1394 (see "Schedule").
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

1. **A full-size secure bank button inside a 24 px row.** The click area of a bank slot would cover the next row, so a right-click there could take or deposit the wrong item. Expected: every button of the layout is scaled before a list is drawn; one that does not take makes that layout categories (one chat line per opening, recorded, never Safe Mode). Pinned by Task 1: "F6: a bank button whose scale does not take: the bank shows categories, says so once, records it" and Task 2: "F6: a guild button whose scale does not take: categories, said once per opening".
2. **Re-sorting or regrouping under the mouse.** A column click, a sort saved in another window, a late item's data and a provider switch all lay a window out again. Expected: each waits while a button that would move (or, in a list, its row) is under the mouse or an item is on the cursor. Pinned by Task 1: "a column click sorts every list by it (saved, answered); the bank's list regroups once the mouse leaves its row"; Task 3: "that regroup waits while a guild button that would move is under the mouse, then lands"; Task 4: "an open alt viewer reads its character again when the answering provider switches; held under the mouse".
3. **Anything touching the secure bank buttons beyond a scale and a point.** Expected: never made, reparented or re-ID'd for the list, also in combat; rows and bars are plain frames. Pinned by Task 1: "in combat too, the list only scales and places the secure bank buttons: never made, reparented or re-ID'd".
4. **A deposit or a withdrawal in the list.** Expected: the spec §4.3 rules hold in rows too: an arrival lands in New with its row beside it, a departure leaves a row-size placeholder and a ghost row, nothing else moves. Pinned by Task 1: "a deposit lands in New as a row; a withdrawal leaves a row-size placeholder and a ghost row" and Task 2: "a withdrawal leaves a ghost row that says the guild bank regroups when closed; search dims rows".
5. **Selling something a gold-maker keeps.** This week loosens one rule (gray rings, necklaces and trinkets sell again) and caches another on the draw path. Expected: only those three equipment slots change; other gray gear whose look is unknown still stays, and the sell path still asks the client right before every sale. Pinned by Task 5: "gray rings, necklaces and trinkets have no look: sold as junk; a gray robe the client cannot say about stays" and "a draw asks the client about a gray piece's look once per link; every sale check asks again".
6. **A secret value on the draw path.** The overlays run under the `"bags"` trap: an error there would switch the bags to Safe Mode. Expected: a secret link or name is no answer: no glow, no star, no error. Pinned by Task 5: "a secret link or name is no answer: no glow, no star, never an error".
7. **A share string the user made themselves being refused, or a hostile one getting through.** Expected: a priority of 90 or more comes in at 89 and is named in the preview; `herb|cname` is a query; `|cnIQ4:` and `|cnGREEN_FONT_COLOR:` are still refused. Pinned by Task 6: "a category priority of 90 or more comes in just below Junk, named in the preview; never refused", "an OR right before a word starting with n is a query, not a colour code", and the week-7 test "refuses hostile or malformed categories whole" (narrowed lines).



## Decisions (every product default chosen this week, read before Task 1)

| # | Question | This plan (the default) | The alternative, and where it is | Why |
|---|---|---|---|---|
| D1 | List view in the bank and guild bank: the same model as the bags? | **Yes.** A third view `"list"` on each window's view button, which now cycles **Categories → List → Grid → Categories** like the bags' (the button names the view a click shows next). The settings are the existing `bank.view` and `guildBank.view`; their default stays **Categories**, so nobody's bank changes until they click. Same row height (24 px), list width (480 px), columns (Name, Count, ilvl, Value), New's 8 list rows, ghost rows and free-tile rows as the bags' list. | Categories or Grid on the same button, as before. | The user asked for the bags' list "in the bank and guild bank windows"; one model means one thing to learn. |
| D2 | One sort order or one per window? | **One shared order** (`bags.list.sort` / `bags.list.desc`, the bags' since week 5). A column click in any window saves it, answers in that window's title, and every drawn list regroups (`SB_LIST_SORTED`), each held by P5. Each window's bar shows the marker (`Value v`). | — (a per-window order would need two more settings and two more Settings rows). | Simpler and predictable: "sorted by value" means the same everywhere. |
| D3 | How the list treats the bank's secure buttons | Only `SetScale` (to 24/37) and `SetPoint` (offsets divided by the scale), exactly as the bags' list. Every button of a layout is scaled **before** the list is drawn; one that does not take (F6) makes that layout categories, recorded as `bank.listScale` / `guild.listScale` under `"none"`, with one chat line per opening (`L.LIST_SCALE_FALLBACK_BANK` / `_GUILD`). | — | Item safety (week 5 F6, W5-1): a full-size button in a row covers the next row's click area. |
| D4 | The guild bank's empty slots in the list | **One free row per tab** (`N free - drop items here`): the free tile, list only (family "any": guild tabs have no bag family). Categories and Grid still show every empty slot, as before. A drop on the free row's icon puts the item in that slot (Blizzard's own pickup/drop, `GW.DropSlot`). | — | A 98-slot tab would otherwise be up to 98 rows of `Empty slot`. |
| D5 | The bank's list and the free tile | Follows `bags.freeTile` as the bank's categories do (one tile per group by default; `/swagbag free all` shows every empty slot). | `/swagbag free all`. | Same rule in every view of the bank. |
| D6 | What a bank or guild row says | Its own texts: hover = the slot's tooltip (the bank: Blizzard's bag slot tooltip plus `Right-click the icon on the left to take this item, or drag the icon.`; the guild bank: the guild slot's tooltip); a click on a row's text answers in the title (`Right-click the icon on the left to take the item.` / `... (from the tab Blizzard has selected).`); a ghost row says `(moved or used - regroups when you close the bank)` / `(moved - regroups when you close the guild bank)`. | — | The bags' row texts say "bag" and "use, sell or move": wrong at a bank. P2: the row's text click still answers. |
| D7 | Guild bank items whose data arrives late (week-5 gap) | As the alt viewer (F22): a pending item waits in New; `ITEM_DATA_LOAD_RESULT` / `GET_ITEM_INFO_RECEIVED` for one of them lays the guild window out again **0.3 s after the last one** (`GW.LOADED_DELAY`), held while a button that would move is under the mouse or an item is on the cursor (P5). Closing forgets them. **Accepted cost:** that regroup is a full layout, so it also clears the visit's placeholders, like a Reflow; it only happens while a late item is shown (after a patch, the first visit). | Reflow by hand (the old behaviour: the item stayed in New until the next visit). | "Make it regroup promptly, obeying P5"; the alt viewer's tested pattern. |
| D8 | Syndicator loaded mid-session | Its callbacks are registered **once**: at login, or on `ADDON_LOADED` for Syndicator if it loads later; a late hook announces `SB_ALTDATA_CHANGED` at once (tooltip counts forget their memo; the provider list is asked again). An **open alt viewer** reads its character again only when the provider that answers is no longer the one it read from (held while the mouse is over its items or an item is on the cursor); Syndicator's ordinary saves still do not redraw it (week-5 rule: it shows what was saved when it opened). | `/reload` (still works). | Without `/reload`, as asked; the viewer's "shows what was saved when it opened" stays true for saves. |
| D9 | Gray rings, necklaces and trinkets | **Sold as junk again** (unless another protection applies): `INVTYPE_FINGER`, `INVTYPE_NECK` and `INVTYPE_TRINKET` have no appearance at all, so "the client cannot say the look" is "cannot collect" for them (`Collections.NO_LOOK`). Every other gray armor or weapon whose look the client cannot say still stays (week-7 final review). | Sell them by hand. | The week-7 final fix made them "unknown look" by accident (week-7 ledger: "could treat no-appearance equip slots as cannot-collect later"). |
| D10 | What every "never sold" line says | `L.VENDOR_KEEPS` gains "(or the game cannot tell yet)": `locked items, equipment-set items, gear whose look you have not collected (or the game cannot tell yet), items to open or learn, and gray BoE items worth more at auction`. | — | The week-7 re-review minor: the unknown-look rule was not mentioned. |
| D11 | The junk coin's protection check | The draw path asks `Vendor.Protected(record, true)`: the look answer `Collections.Uncollected` already cached for the link is reused (one client call per link, then a table lookup). The **sell path** never passes it: right before each sale an unknown look is asked again (week-7 final review). | — | "No uncached AppearanceKnown per draw" (week-7 re-review minor). |
| D12 | Secret values on the collections' draw path (week-7 T3 FINAL) | A link or name the client made secret is **no answer**: `Collections` reads `r.link` / `r.name` only through `plain()` (`Adapter.IsSecret`), so a secret caged pet, knowledge item or gear piece gets no green glow, no star and never an error (an error there runs under `"bags"` and would mean Safe Mode). | — | Spec §9 secret-value rule. |
| D13 | "all 1 locks" | One lock reads as one: `This removes your 1 lock. ...`, `Unlocked the 1 locked item.`, `Lock restored: 1.` Two or more keep the plural lines. | — | Week-7 re-review minor. |
| D14 | A share string whose category priority is 90 or more (week-7: refused whole, so a user's own export could fail to import) | **Lowered, never refused:** such a category (yours, or an edit of a built-in other than the four below) comes in at **89**, just below Junk (90), Equipment sets (92), Keystone & Crests (95) and Reagents (100); the preview names it: `Ranked just below Junk (an imported category never outranks Junk, Equipment sets, Keystone & Crests or Reagents): <names>`. The priority of those four built-ins is never imported at all (ruling Q6); the preview names them: `Rank not imported (Junk, Equipment sets, Keystone & Crests and Reagents keep their rank): <names>`. Export is unchanged. | Refuse (week 7), or clamp on export: rejected. Export clamping cannot fix strings 0.7.0 already exported, and refusing breaks "your own string always imports"; a string cannot prove who made it, so the safety cap stays. | A hostile string still cannot make an arbitrary query outrank the categories that keep junk, set pieces and keys apart; your own string always imports and the preview says what moved. (No SwagBag UI sets a priority today: only hand-edited saved data or old strings reach 90.) |
| D15 | The `|cn` rule refused `herb|cname` (an OR before a word starting with n) | Refuse `|cn` / `|cN` only when it opens a real named colour: an upper-case letter or `_`, then upper-case letters, digits or `_`, then `:` (`|cnIQ4:`, `|cnGREEN_FONT_COLOR:`). | — | The narrowest rule that still catches every named-colour escape WoW draws (its names are upper-case globals and `IQ<n>`); queries are lower-case words. |
| D16 | "Your top X %" at the bank | Worked out again whenever the bank's contents change while it is open (`SB_BANK_CHANGED`: a layout, an arrival, a departure or a count change), 0.1 s after the last change; a fixed gold amount does not depend on contents and is not recomputed. | — | Week-7 deferred (BK1): the line could be computed from the bags alone if the bank filled 0.1 s after opening. |
| D17 | Version | `0.8.0` (Task 1). | — | — |
| D18 | Bank speed part 2 (week-6 TF1 diagnostics) | **Not this week.** It waits on session TF1's numbers (`/swagbag report`'s bank layout phases). | — | No measurements yet; guessing would risk the bank's correctness for an unmeasured gain. |



## What the week relies on

No new Blizzard API. Everything this week uses was already in the Adapter and checked in game in earlier weeks:

| What | Name | Since | Confidence |
|---|---|---|---|
| Drawing a slot button smaller | `Frame:SetScale`, `GetScale` on `ContainerFrameItemButtonTemplate` buttons; offsets in the frame's own scale | week 5 (the bags' list; spec §4.1: the buttons are not protected) | The bags' list is in daily use; the bank's tabs use the same template. Session BL1 checks the bank's (G1, G2). |
| The guild slot tooltip | `GameTooltip:SetGuildBankItem` (`Adapter.GuildTooltip`) | week 3 | — |
| Item data arriving | `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED` (itemID, success) | week 5 (alt viewer, F22) | The alt viewer relies on them. |
| An addon loading later | `ADDON_LOADED` (folder name) | week 1 (Boot) | Syndicator's folder name is `Syndicator` (installed copy). |
| Syndicator's callbacks | `Syndicator.CallbackRegistry:RegisterCallback(event, fn, owner)`, events in `A.SYNDICATOR_EVENTS` | week 5 | — |
| Equipment slots | `INVTYPE_FINGER`, `INVTYPE_NECK`, `INVTYPE_TRINKET` (`record.equipLoc`) | week 1 | Rings, necklaces and trinkets have no transmog appearance (warcraft.wiki.gg "Transmogrification"). |


## Needs in-game confirmation (what could not be verified at the desk)

Each item names the session step that checks it. None blocks the build; a wrong answer comes back as a fix.

| # | What | Why it is uncertain | Checked in |
|---|---|---|---|
| G1 | A bank slot button drawn at 24/37 scale still deposits, withdraws and splits with Blizzard's own clicks, in tiny and beside mode, also right after combat | The bags' buttons do (week 5, L1); the bank's tabs are a different bag range and live in the tiny host | BL1 steps 6–9 |
| G2 | The click area of a scaled bank button is the icon, not the full 37 px square (no click reaches the row below) | Hit rectangles scale with the frame in WoW; never seen for the bank | BL1 step 8 |
| G3 | SwagBag's own guild slot buttons scale and click the same way | Plain `ItemButton`s; scale untested in game | GL1 steps 5–7 |
| G4 | A drop on a guild tab's free row puts the item in that tab | `PickupGuildBankItem` on an empty slot (week 3's drop) now on the tile slot | GL1 step 7 |
| G5 | After the 12.1.5 patch (2026-10-13), guild items whose data was not cached show in New briefly, then move to their categories without a click | Item data arrival after a patch cannot be staged at will | GL1 step 10 (patch day, or any first visit after the item cache was cleared) |
| G6 | Syndicator's late load | Syndicator is not load-on-demand, so it normally loads before SwagBag (OptionalDeps); the late path happens when another addon loads it on demand or a future Syndicator build makes it load-on-demand. Not reproducible by hand. | Covered by the unit tests; SY1 checks that the normal path still answers from Syndicator, and that disabling it falls back to SwagBag's own data |
| G7 | A gray ring, necklace or trinket sells at a vendor; a gray robe the game cannot tell about stays | Desk-modelled; the client's "no source" answer for jewelry | VP1 steps 4–6 |
| G8 | "Your top 10%" glows on the bank's most valuable stacks a second after the bank opens and after a deposit | Timing of the bank's first fill | BL1 steps 11–13 |
| G9 | A full bank (several hundred items) opens in the list view without a visible stutter | The list adds a row frame per drawn slot (the bags have up to ~200; a bank can have 1,290 slots, most of them spares with the free tile); `/swagbag free all` plus the list on a full bank creates one row frame per empty slot, so that is the worst case | BL1 step 16 (the user says if it stutters; `/swagbag report` shows `Last bank layout: ... ms`) |



## Carry-overs: what this week takes, and what stays deferred

Taken (the task that does it): week-5 "list view for bank/guild windows (D9)" (Tasks 1, 2); week-5 "guild bank pending-item relayout gap" (Task 3); week-5 "Syndicator loaded mid-session callbacks" (Task 4); week-7 re-review minors "VENDOR_KEEPS doesn't mention unknown-look gray gear", "gray jewelry never auto-sold", "own priority >= 90 refused on import", "|c[nN] also refuses unspaced 'herb|cname'", "Protected on draw path", "all 1 locks plural" (Tasks 5, 6); week-7 Task 3 "FINAL MUST CONSIDER: Collections secret guard" (Task 5); week-7 Task 7 "top-N worth line may be computed from bags only" and "IsWorth calls stackValue twice" (Task 7).

Checked and already done (no task): week-7 Task 2 "SeasonText unguarded inside Report.Build" (the final wave pcalls it: `Core/Report.lua`); week-6 Task 7 "stale toggleClosedUsers" (reset in the week-6 final wave, `UI/SafeModeHooks.lua`); week-6 "MODE_STATUS without style", "SET_MODE_TIP master switch", "SET_FOCUS_STYLE_TIP nothing is collapsed" (fixed in the week-6 final wave: `L.MODE_STATUS` lists `style`, `L.SET_MODE_TIP` names `Switch by themselves`, `L.SET_FOCUS_STYLE_TIP` says `The mode collapses nothing`).

Triaged and left deferred (cheap but not user-visible, or needing an in-game look first):
- week-6 Task 7: the reopen branch ignores `W.Open()`'s result and always traces "reopened"; no test pins the trace for a failed reopen (trace accuracy only; revisit with TF1's trace);
- week-6 Task 5/6: mock `DepositWarband` failure field, `adapter_bank_spec` `before_each` cleanup, deposit `pcall` error branch untested, refusal tests not asserting chat silence (test-only);
- week-6 Task 6: the reagents box can be stale in beside mode if Blizzard's own box changes (shown again on every deposit click since week 6);
- week-6 Task 9: the gold thousands separator is "," (enUS only); `Snap.Bytes` builds a table per call (save time only);
- week-7 Task 5: the bind badge (off by default) and the padlock share the left middle when both are on (needs the user's eye first); false-positive hand-sold warning when a same-link locked stack moves after an earlier hand sale; partial stack sales undetected;
- week-7 Task 6: stale menu counts / the section menu not closed at combat start; the header hint when a section has nothing to act on;
- week-7 Task 7: `/swagbag worth 250` shows no selected button on the Settings row;
- week-7 Task 9: the preview names replaced categories only by count;
- week-7 Task 2: `SeasonText` `ITEM_N` fallback and the no-icon footer entry untested (test-only);
- week-7 Task 4: lag can undercount one sale past `MAX_PENDING`; a run straddling two `MERCHANT_SHOW`s (no report of it happening);
- the week-6 bank-speed part 2 (D18): waits on TF1.

The week-6 checklists' open in-game checks (L1 step 14, TH1, OF1, DP1, TF1) and the week-7 sessions (SN1, LN1, VN1, BK1, PF1) are unchanged by this plan.


---

## File structure (end of week 8)

New and changed files only. Everything else is as on `ab9d5a2`.

```
SwagBag/UI/GroupView.lua               MOD  (T1) the list view: rows, scale, F6, sort, ghost and tile rows, P5 rows,
                                            SetRecord repaints a row, RefreshRows, SetDimmed, cfg.family, freeTile(view)
SwagBag/UI/ListRows.lua                MOD  (T1) opts (tip and texts per window), COLUMN_NAMES, SortedText, ColumnBar
SwagBag/Engine/Sort.lua                MOD  (T1) Sort.Save announces SB_LIST_SORTED
SwagBag/UI/BagsWindow.lua              MOD  (T1) regroups on SB_LIST_SORTED (from any window)
SwagBag/UI/BankWindow.lua              MOD  (T1) the list: rows, column bar, view cycle, SortList, prices, F6 line;
                                            (T7) SB_BANK_CHANGED
SwagBag/UI/GuildBankWindow.lua         MOD  (T2) the list: rows, column bar, view cycle, SortList, free row per tab;
                                            (T3) pending items regroup when their data arrives
SwagBag/Providers/Syndicator.lua       MOD  (T4) P.Hook: callbacks once, at login or when Syndicator loads later
SwagBag/Core/Adapter.lua               MOD  (T4) SYNDICATOR_ADDON, IsSyndicatorAddon
SwagBag/UI/OfflineWindow.lua           MOD  (T4) re-reads its character when the answering provider switches
SwagBag/Engine/Collections.lua         MOD  (T5) NO_LOOK, plain() (secret guard), LookUnknown(r, fast)
SwagBag/Engine/Vendor.lua              MOD  (T5) Protected(r, fast)
SwagBag/UI/Overlays.lua                MOD  (T5) the cached check on the draw path; (T7) top-% follows SB_BANK_CHANGED,
                                            IsWorth reads the stack value once
SwagBag/Engine/Locks.lua               MOD  (T6) one lock reads as one
SwagBag/Engine/Profiles.lua            MOD  (T1, T2) "list" for bank.view / guildBank.view; (T6) priority clamp, |cn rule
SwagBag/Locale/enUS.lua                MOD  (T1, T2, T5, T6)
SwagBag/SwagBag.toc, SwagBag/Core/Init.lua  MOD  (T1) 0.8.0
spec/bankwindow_list_spec.lua (T1), spec/guildbank_list_spec.lua (T2)                                       NEW
spec/helpers/uienv.lua (T1: LoadBank and LoadGuild load UI/ListRows.lua), bagswindow_list_spec.lua (T1),
spec/profiles_spec.lua (T1, T2, T6), guildbank_spec.lua (T3), syndicator_spec.lua, offline_spec.lua (T4),
spec/vendor_spec.lua (T5, T6), collections_spec.lua, overlays_spec.lua (T5), locks_spec.lua (T6),
spec/bankwindow_groups_spec.lua (T7)                                                                        MOD
```

No file is added to `SwagBag/`: `TOC OK (72 files)` after every task.


## Schedule (week 8)

In priority order, so the earlier items ship first if time runs out. 12.1.5 goes live on 2026-10-13: Task 3's in-game check (G5) is easiest that day.

| Day | Tasks | User in game? |
|---|---|---|
| 1 | 1 | after the merge: session BL1 (the bank's list, about 15 minutes) |
| 1 | 2, 3 | after the merge: session GL1 (the guild bank's list, about 10 minutes) |
| 2 | 4 | after the merge: session SY1 (about 5 minutes) |
| 2 | 5, 6, 7 | after the merge: session VP1 (vendor, locks and a share string, about 10 minutes; BL1 covers Task 7) |
| 3 | final review, fixes | **Week 8 exit check** |

Cumulative `scripts/check.sh` test totals (from 1394 on `ab9d5a2`). Each was produced by replaying this file's blocks in order on a fresh clone of `ab9d5a2`:
- T1 1404 passed, 0 failed (+10)
- T2 1410 passed, 0 failed (+6)
- T3 1413 passed, 0 failed (+3)
- T4 1416 passed, 0 failed (+3)
- T5 1420 passed, 0 failed (+4)
- T6 1423 passed, 0 failed (+3)
- T7 1424 passed, 0 failed (+1)

## How to read the code steps

- A **Create** step gives a complete new file.
- An **In `path`, find … and replace it with …** step gives an exact block of the file as it is at that point and its replacement. The block occurs exactly once in the file, and starts and ends on a non-blank line. When a step edits one file in several places, the places are numbered "(edit N of M)". Apply them in that order, top to bottom. Each find block is unique in the file as it is after the earlier edits.
- No step replaces a whole existing file.
- Copy every block verbatim, tabs included.
- Step 1 holds a task's test blocks (everything under `spec/`). Step 3 holds its code blocks (everything else). Apply Step 1, run Step 2 (red), then apply Step 3.
- **Critical tests and their mutations.** Under Step 2, each task lists its critical tests and, for each, the code change (mutation) that must make it fail. Every mutation was applied to the finished code of its task and the named test failed. A reviewer re-runs any of them with a one-line edit. In a mutation, ` ⏎ ` marks a line break and `∅` an empty replacement; leading tabs are left out.
- A test that passes at Step 2 is named there with the reason.


### Task 1: The list view in the bank window (GroupView learns the list); v0.8.0

Week-5 deferred item D9, the user's first priority. `UI/GroupView.lua` gains the bags window's list view (D1–D3, D5): with `cfg.view()` returning `"list"` and `cfg.rows` (a `UI/ListRows.lua` object) set, each group's sections are one column of 24 px rows; each slot's own button is scaled to the row (`SetScale` only, offsets divided by the scale) and its texts sit beside it; each section lists its items in `Engine/Sort.lua`'s order; placeholders get ghost rows and the free tile its row; a row under the mouse holds its button (P5); live repaints (`v.SetRecord`), prices (`v.RefreshRows`) and search (`v.SetDimmed`) reach the rows. Every button is scaled before a list is drawn (F6): a scale that does not take makes that layout categories (`cfg.onListFailed`). `UI/ListRows.lua` gets per-window texts and tooltip (`opts`), the shared `ColumnBar` and `SortedText`; `Sort.Save` announces `SB_LIST_SORTED` and every window regroups its drawn list on it (the bags' `W.SortList` now relies on it, D2). The bank window cycles Categories → List → Grid, shows the column bar under its deposit line while a list is drawn, and says the F6 fallback once per opening (D6 texts). `bank.view` may hold `"list"` in a share string. The version goes to 0.8.0.

**Files:**
- Modify: `SwagBag/UI/GroupView.lua`, `SwagBag/UI/ListRows.lua`, `SwagBag/Engine/Sort.lua`, `SwagBag/UI/BagsWindow.lua`, `SwagBag/UI/BankWindow.lua`, `SwagBag/Engine/Profiles.lua`, `SwagBag/Locale/enUS.lua`
- Modify: `SwagBag/SwagBag.toc`, `SwagBag/Core/Init.lua` (0.8.0)
- Create: `spec/bankwindow_list_spec.lua`
- Test: `spec/helpers/uienv.lua` (the bank and guild loaders load `UI/ListRows.lua`), `spec/bagswindow_list_spec.lua`, `spec/profiles_spec.lua`

**Interfaces:**
- Consumes: `ListRows.New/Columns/Texts` and rows `Place/Paint/Ghosts/HideAll/SetDimmed/IsMouseOver` (week 5), `Sort.Spec/Next/Save/Value/DisplayOrder/COLUMNS`, `Layout.Build/Position` (`freeTile`, `family`), `Buttons.SetDimmed/SetFreeCount/AcquirePlaceholder`.
- Produces: GroupView cfg `rows`, `onListFailed`, `family`, `freeTile(view)`; view `v.drawn`, `v.RowWidth()`, `v.RefreshRows()`, `v.SetDimmed(button, dimmed)`; `GV.LIST_ROW/LIST_GAP/LIST_WIDTH/LIST_NEW_ROWS/ROW_TEXT_GAP/SCALE_EPSILON`; `ListRows.New(parent, window, flash, opts)` with `opts = { tip, click, emptyClick, emptyTip, gone }`, `ListRows.COLUMN_NAMES`, `ListRows.SortedText(spec)`, `ListRows.ColumnBar(parent, width, height, onClick, window, label) -> { frame, buttons, Refresh }`; the event `SB_LIST_SORTED(by, desc)`; `BW.rows`, `BW.columnsBar`, `BW.SortList(by)`, `BW.HeaderHeight()`, `BW.COLUMNS_H`, `BW.scaleWarned`; `L.BANK_VIEW_LIST`, `L.LIST_BANK_*`, `L.LIST_SCALE_FALLBACK_BANK`; `SB.VERSION = "0.8.0"` (Task 2 reuses all of the GroupView and ListRows interfaces).

- [ ] **Step 1: Write the failing tests**

In `spec/bagswindow_list_spec.lua` (edit 1 of 3), find:

```lua
	-- Mutation: in W.SortList, drop the W.RequestLayout("listsort") call.
```

and replace it with:

```lua
	-- Week 8: one order for every list. Mutation: delete the bags window's SB_LIST_SORTED listener's
	-- W.RequestLayout("listsort") call.
	it("a sort saved anywhere (the bank's column bar) regroups the bags' list and moves its marker", function()
		W.Open()
		SB.Sort.Save("name", false)
		assert.equal("Name ^", W.columnButtons.name.label.text)
		assert.truthy(B.Get(0, 1).y > B.Get(0, 2).y, "Algari Healing Potion above Flask of Alchemical Chaos")
	end)

	-- Mutation: in the SB_LIST_SORTED listener, drop the W.RequestLayout("listsort") call.
```

In `spec/bagswindow_list_spec.lua` (edit 2 of 3), find:

```lua
	-- P5: re-sorting never moves a row under the mouse. Mutation: in W.SortList, call W.Layout
	-- instead of W.RequestLayout.
```

and replace it with:

```lua
	-- P5: re-sorting never moves a row under the mouse. Mutation: in the SB_LIST_SORTED listener
	-- (week 8), call W.Layout instead of W.RequestLayout.
```

In `spec/bagswindow_list_spec.lua` (edit 3 of 3), find:

```lua
	-- Fix round 1, item 3: the order is saved, but only a drawn list regroups. Mutation: in W.SortList,
	-- request the layout whenever the window is shown (drop the isList() check).
```

and replace it with:

```lua
	-- Fix round 1, item 3: the order is saved, but only a drawn list regroups. Mutation: in the
	-- SB_LIST_SORTED listener (week 8), request the layout whenever the window is shown (drop the isList() check).
```

Create `spec/bankwindow_list_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 8: the bank window's list view (spec 2.2 v1.3, the bags window's since week 5) over the real
-- engine, button pool and GroupView: each group's sections, one row per slot, the slot's own secure
-- button scaled to the row (never made, reparented or re-ID'd), the shared column order, P5 and F6.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local function blizzardBank()
	local bf = Fake.New("Frame", UIParent)
	bf.TabSystem = Fake.New("Frame", bf)
	bf.TabSystem.tabs = { Fake.New("Button", bf.TabSystem), Fake.New("Button", bf.TabSystem) }
	return bf
end

describe("BankWindow list view (week 8)", function()
	local SB, A, BW, B, GV
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		Fake.Install()
		Env.PaintGlobals()
		A.frames.BankFrame = blizzardBank()
		A.activeBankType = "bank"
		BW = Env.LoadBank(SB)
		B, GV = SB.Buttons, SB.GroupView
		SB.Emit("SB_LOGIN")
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.items[Fixtures.HEALING_POTION].sellPrice = 100 -- the stack of 5: 500
		A.items[Fixtures.FLASK].sellPrice = 1000 -- one: 1000
		A.Put(6, 1, Fixtures.HEALING_POTION, 5)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(6, 3, Fixtures.FLASK, 1)
		A.Put(12, 1, Fixtures.ORE, 10)
		A.Put(12, 2, Fixtures.BOE_RING, 1)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openBank()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	local function bankUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function labels()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	local function round(v)
		return math.floor(v * 1000 + 0.5) / 1000
	end

	-- Where a button sits in the scroll child: its point's offsets are in its own scale.
	local function on(bag, slot)
		local b = B.Get(bag, slot)
		local p = b.points[#b.points]
		return { round(p[4] * b.scale), round(p[5] * b.scale) }
	end

	local function row(bag, slot)
		return BW.rows.rows[B.Get(bag, slot)]
	end

	local function lastTopLeft(f)
		local found
		for _, p in ipairs(f.points) do
			if p[1] == "TOPLEFT" then
				found = p
			end
		end
		return found
	end

	-- Mutations: in GroupView's build(), drop the SB.Sort.DisplayOrder call; in its place(), offset by x, y
	-- (not x / scale, y / scale).
	it("each group's sections, one row per slot: the slot's own button at row size, its texts beside it", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		assert.equal("list", BW.view.drawn)
		assert.same({ "- Character bank (3)  - deposits go here", "- Warband bank (2)",
			"- New (0)", "- Consumables (2) - 15s vendor", "- Herbs (1)", "- Free (5)",
			"- New (0)", "- BoE gear (1)", "- Ore (1)", "- Free (6)" }, labels())
		assert.equal(GV.LIST_ROW / GV.SLOT, B.Get(6, 1).scale, "drawn at the row's height")
		local potion, flask = on(6, 1), on(6, 3)
		assert.equal(GV.PAD, potion[1], "every button sits at the row's left edge")
		assert.equal(GV.LIST_ROW + GV.LIST_GAP, flask[2] - potion[2], "flask (1000) one row above potion (500)")
		assert.equal(potion[2], row(6, 1).points[1][5], "the row's texts sit beside its button")
		assert.equal(GV.PAD + GV.LIST_ROW + GV.ROW_TEXT_GAP, row(6, 1).points[1][4])
		assert.same({ "Algari Healing Potion", "5", "285" }, { row(6, 1).name.text, row(6, 1).count.text,
			row(12, 2).ilvl.text })
		assert.equal(SB.L.LIST_FREE:format(5), row(6, 4).name.text, "the free tile's row says how many are free")
		assert.equal(GV.LIST_WIDTH, BW.child.w)
		assert.truthy(BW.columnsBar.frame.shown)
		assert.equal("Value v", BW.columnsBar.buttons.value.label.text)
		assert.equal(-(BW.HEADER + BW.COLUMNS_H), lastTopLeft(BW.scroll)[5], "the items start under the column bar")
	end)

	-- Mutation: in BankWindow.lua, VIEW_NEXT's `sections = "list"` -> `sections = "grid"`.
	it("the view button shows categories, list and grid in turn, each answered in the title", function()
		openBank()
		assert.equal(SB.L.VIEW_TO_LIST, BW.viewButton.text)
		Fake.Fire(BW.viewButton, "OnClick")
		assert.same({ "list", "list", SB.L.BANK_VIEW_LIST, SB.L.VIEW_TO_GRID },
			{ SB.Config.Get("bank.view"), BW.view.drawn, BW.frame.title.text, BW.viewButton.text })
		assert.truthy(row(6, 1).shown)
		Fake.Fire(BW.viewButton, "OnClick")
		assert.same({ "grid", "grid", SB.L.BANK_VIEW_GRID, SB.L.VIEW_TO_SECTIONS },
			{ SB.Config.Get("bank.view"), BW.view.drawn, BW.frame.title.text, BW.viewButton.text })
		assert.equal(1, B.Get(6, 1).scale, "full size again")
		assert.falsy(row(6, 1).shown)
		assert.falsy(BW.columnsBar.frame.shown)
		assert.equal(-BW.HEADER, lastTopLeft(BW.scroll)[5])
		Fake.Fire(BW.viewButton, "OnClick")
		assert.same({ "sections", "sections", SB.L.VIEW_TO_LIST }, { SB.Config.Get("bank.view"), BW.view.drawn,
			BW.viewButton.text })
	end)

	-- One order for every list (bags.list). Mutations: in GroupView's busyCheck, drop the rows.IsMouseOver
	-- check (the list re-sorts under the mouse); delete the bank window's SB_LIST_SORTED RequestLayout.
	it("a column click sorts every list by it (saved, answered); the bank's list regroups once the mouse leaves its row",
		function()
			SB.Config.Set("bank.view", "list")
			openBank()
			row(6, 1).mouseOver = true
			Fake.Fire(BW.columnsBar.buttons.name, "OnClick")
			assert.same({ "name", false }, { SB.Config.Get("bags.list.sort"), SB.Config.Get("bags.list.desc") })
			assert.equal("Sorted by Name, A to Z", BW.frame.title.text)
			assert.equal("Name ^", BW.columnsBar.buttons.name.label.text)
			assert.truthy(on(6, 3)[2] > on(6, 1)[2], "held: nothing moved under the row")
			row(6, 1).mouseOver = false
			A.Advance(GV.RETRY)
			assert.truthy(on(6, 1)[2] > on(6, 3)[2], "Algari Healing Potion above Flask of Alchemical Chaos")
			assert.equal("listsort", BW.view.stats.lastLayoutReason)
			SB.Sort.Save("value", true) -- a sort saved elsewhere (the bags' bar, /swagbag list)
			assert.truthy(on(6, 3)[2] > on(6, 1)[2], "the bank's list follows")
		end)

	-- Spec 4.3 in the list. Mutations: in GroupView's renderExtras, drop the rows.Ghosts call; in its showAt,
	-- drop the rows.Place call.
	it("a deposit lands in New as a row; a withdrawal leaves a row-size placeholder and a ghost row", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		local herb, ore = on(6, 2), on(12, 1)
		A.Put(6, 5, Fixtures.JUNK, 3)
		bankUpdate(6)
		assert.equal(on(6, 5)[2], row(6, 5).points[1][5], "its row is beside it")
		assert.same({ "Broken Tooth", "3" }, { row(6, 5).name.text, row(6, 5).count.text })
		A.Clear(6, 2)
		bankUpdate(6)
		assert.equal(1, #B.placeholdersInUse)
		assert.equal(GV.LIST_ROW, B.placeholdersInUse[1].w)
		local ghost = BW.rows.ghosts[1]
		assert.same({ SB.L.LIST_BANK_GONE, herb[2], true }, { ghost.name.text, ghost.points[1][5], ghost.shown })
		assert.same(ore, on(12, 1), "nothing else moved")
	end)

	-- F6 (item safety). Mutation: in GroupView's commit, `if b.view == "list" and not scaleAll(b, listScale())`
	-- -> `if false` (a full-size secure button would be drawn in a 24 px row).
	it("F6: a bank button whose scale does not take: the bank shows categories, says so once, records it", function()
		openBank()
		B.Get(12, 2).SetScale = function() end
		Fake.Fire(BW.viewButton, "OnClick")
		assert.equal("list", SB.Config.Get("bank.view"))
		assert.equal("sections", BW.view.drawn)
		assert.equal(1, B.Get(6, 1).scale, "every button back at full size")
		assert.falsy(BW.columnsBar.frame.shown)
		assert.same({ SB.L.LIST_SCALE_FALLBACK_BANK }, A.Lines())
		assert.equal("bank.listScale", SB.ErrorTrap.Recent()[1].label)
		assert.falsy(SB.SafeMode.IsOn("bank"))
		BW.Reflow("reflow")
		assert.equal(1, #A.Lines(), "said once per opening")
	end)

	-- Spec 4.1. Mutation: in ListRows' create(), make the row an "ItemButton" from ContainerFrameItemButtonTemplate.
	it("in combat too, the list only scales and places the secure bank buttons: never made, reparented or re-ID'd",
		function()
			openBank()
			local made = #Fake.created
			local strict = {}
			for _, bag in ipairs({ 6, 12 }) do
				for slot = 1, 8 do
					strict[#strict + 1] = Fake.Strict(B.Get(bag, slot))
				end
			end
			A.combat = true
			Fake.Fire(BW.viewButton, "OnClick")
			assert.equal("list", BW.view.drawn)
			for i = made + 1, #Fake.created do
				local f = Fake.created[i]
				assert.truthy(f.kind == "Frame" or f.kind == "Button", f.kind)
				assert.falsy(f.template == "ContainerFrameItemButtonTemplate")
			end
			local scaled = 0
			for _, b in ipairs(strict) do
				for _, call in ipairs(b.log) do
					assert.falsy(call.name == "SetParent" or call.name == "SetID", call.name)
					scaled = scaled + (call.name == "SetScale" and 1 or 0)
				end
			end
			assert.equal(16, scaled)
		end)

	-- AC5.1. Mutation: the bank search box's setDimmed back to SB.Buttons.SetDimmed (rows stay bright).
	it("the bank's search dims a non-matching row with its button", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		BW.searchBox.editBox:SetText("ore")
		Fake.Fire(BW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
		assert.same({ B.DIM_ALPHA, B.DIM_ALPHA }, { row(6, 1).alpha, B.Get(6, 1).alpha })
		assert.equal(1, row(12, 1).alpha)
	end)

	-- F8. Mutations: in GroupView's v.SetRecord, drop the rows.Paint call; in the bank window's SB_PRICES_CHANGED
	-- handler, drop BW.view.RefreshRows().
	it("a count change and new prices repaint the bank's rows in place; nothing moves", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		local potion, reason = on(6, 1), BW.view.stats.lastLayoutReason
		A.Put(6, 1, Fixtures.HEALING_POTION, 3)
		bankUpdate(6)
		assert.equal("3", row(6, 1).count.text)
		A.auctionator = { prices = { [A.GetSlot(6, 2).link] = 90000 } }
		A.auctionatorCallback()
		A.Advance(0.5)
		assert.equal("180g", row(6, 2).value.text)
		assert.same({ potion, reason }, { on(6, 1), BW.view.stats.lastLayoutReason })
	end)
end)
```

In `spec/helpers/uienv.lua` (edit 1 of 2), find:

```lua
		"SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua", "SwagBag/UI/Overlays.lua" }) do
```

and replace it with:

```lua
		"SwagBag/UI/ListRows.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua",
		"SwagBag/UI/Overlays.lua" }) do
```

In `spec/helpers/uienv.lua` (edit 2 of 2), find:

```lua
		"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/GuildButtons.lua",
```

and replace it with:

```lua
		"SwagBag/UI/SearchBox.lua", "SwagBag/UI/ListRows.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua",
		"SwagBag/UI/GuildButtons.lua",
```

In `spec/profiles_spec.lua`, find:

```lua
			{ Pr.Parse("SWAGBAG:1:cu.u_x.inc=s" .. ("1%2C"):rep(Pr.MAX_LIST) .. "1") })
```

and replace it with:

```lua
			{ Pr.Parse("SWAGBAG:1:cu.u_x.inc=s" .. ("1%2C"):rep(Pr.MAX_LIST) .. "1") })
	end)

	-- Week 8. Mutation: drop "list" from bank.view's words in VALID (Engine/Profiles.lua).
	it("the bank's list view travels in a share string", function()
		C.Set("bank.view", "list")
		local data = assert(Pr.Parse(Pr.Export(false)))
		assert.equal("list", data.settings["bank.view"])
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1394 passed, 10 failed`. The failures, exactly:

- `spec/bagswindow_list_spec.lua :: BagsWindow list view > a sort saved anywhere (the bank's column bar) regroups the bags' list and moves its marker`
- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > each group's sections, one row per slot: the slot's own button at row size, its texts beside it`
- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > the view button shows categories, list and grid in turn, each answered in the title`
- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > a column click sorts every list by it (saved, answered); the bank's list regroups once the mouse leaves its row`
- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > a deposit lands in New as a row; a withdrawal leaves a row-size placeholder and a ghost row`
- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > F6: a bank button whose scale does not take: the bank shows categories, says so once, records it`
- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > in combat too, the list only scales and places the secure bank buttons: never made, reparented or re-ID'd`
- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > the bank's search dims a non-matching row with its button`
- `spec/bankwindow_list_spec.lua :: BankWindow list view (week 8) > a count change and new prices repaint the bank's rows in place; nothing moves`
- `spec/profiles_spec.lua :: Profiles (week 7) > the bank's list view travels in a share string`

The bags-list spec's two edited comments change no assertion. `spec/helpers/uienv.lua` now loads `UI/ListRows.lua` for the bank and guild windows; at Step 2 the old windows never use it, so every existing bank and guild test stays green.

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "each group's sections, one row per slot: the slot's own button at row size, its texts beside it": in `SwagBag/UI/GroupView.lua`, `slots = SB.Sort.DisplayOrder(slots, SB.Sort.Spec(), SB.Sort.Value)` → ∅.
- "each group's sections, one row per slot: the slot's own button at row size, its texts beside it": in `SwagBag/UI/GroupView.lua`, `button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x / scale, y / scale)` → `button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x, y)`.
- "the view button shows categories, list and grid in turn, each answered in the title": in `SwagBag/UI/BankWindow.lua`, `local VIEW_NEXT = { sections = "list", list = "grid", grid = "sections" }` → `local VIEW_NEXT = { sections = "grid", list = "grid", grid = "sections" }`.
- "a column click sorts every list by it (saved, answered); the bank's list regroups once the mouse leaves its row": in `SwagBag/UI/GroupView.lua`, `(b:IsMouseOver() or (isList() and rows.IsMouseOver(b)))` → `b:IsMouseOver()`.
- "a column click sorts every list by it (saved, answered); the bank's list regroups once the mouse leaves its row": in `SwagBag/UI/BankWindow.lua`, `BW.view.RequestLayout("listsort")` → ∅.
- "a deposit lands in New as a row; a withdrawal leaves a row-size placeholder and a ghost row": in `SwagBag/UI/GroupView.lua`, `rows.Ghosts(ghosts, rowWidth(), GV.LIST_ROW)` → ∅.
- "a deposit lands in New as a row; a withdrawal leaves a row-size placeholder and a ghost row": in `SwagBag/UI/GroupView.lua`, `rows.Place(button, shown and c.x + GV.LIST_ROW + GV.ROW_TEXT_GAP, c.y, rowWidth(), GV.LIST_ROW, shown)` → ∅.
- "F6: a bank button whose scale does not take: the bank shows categories, says so once, records it": in `SwagBag/UI/GroupView.lua`, `if b.view == "list" and not scaleAll(b, listScale()) then` → `if false then`.
- "in combat too, the list only scales and places the secure bank buttons: never made, reparented or re-ID'd": in `SwagBag/UI/ListRows.lua`, `local row = CreateFrame("Frame", nil, parent)` → `local row = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")`.
- "the bank's search dims a non-matching row with its button": in `SwagBag/UI/BankWindow.lua`, `return BW.view.SetDimmed(button, dimmed)` → `return SB.Buttons.SetDimmed(button, dimmed)`.
- "a count change and new prices repaint the bank's rows in place; nothing moves": in `SwagBag/UI/GroupView.lua`, `if button and not v.tiled[button] then ⏎ rows.Paint(button, bag, slot, record)` → `if button and not v.tiled[button] then`.
- "a count change and new prices repaint the bank's rows in place; nothing moves": in `SwagBag/UI/BankWindow.lua`, `BW.view.RefreshTotals() ⏎ BW.view.RefreshRows()` → `BW.view.RefreshTotals()`.
- "the bank's list view travels in a share string": in `SwagBag/Engine/Profiles.lua`, `["bank.view"] = words("sections", "grid", "list")` → `["bank.view"] = words("sections", "grid")`.
- "a sort saved anywhere (the bank's column bar) regroups the bags' list and moves its marker": in `SwagBag/UI/BagsWindow.lua`, `W.RefreshColumns() ⏎ if frame:IsShown() and isList() then ⏎ W.RequestLayout("listsort") ⏎ end` → `W.RefreshColumns()`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Init.lua`, find:

```lua
SB.VERSION = "0.7.0"
```

and replace it with:

```lua
SB.VERSION = "0.8.0"
```

In `SwagBag/Engine/Profiles.lua`, find:

```lua
	["bank.blizzardFrame"] = words("tiny", "beside"), ["bank.view"] = words("sections", "grid"), ["bank.columns"] = COLUMNS,
```

and replace it with:

```lua
	["bank.blizzardFrame"] = words("tiny", "beside"), ["bank.view"] = words("sections", "grid", "list"), ["bank.columns"] = COLUMNS,
```

In `SwagBag/Engine/Sort.lua` (edit 1 of 2), find:

```lua
--   Sort.Save(by, desc) -> ok        false (nothing written) while the settings are read-only
```

and replace it with:

```lua
--   Sort.Save(by, desc) -> ok        false (nothing written) while the settings are read-only; saved:
--                                    SB_LIST_SORTED(by, desc), so every list (the bags, the bank and the
--                                    guild bank: one shared order, week 8) redraws its bar and regroups
```

In `SwagBag/Engine/Sort.lua` (edit 2 of 2), find:

```lua
	return SB.Config.Set("bags.list.sort", by) and SB.Config.Set("bags.list.desc", desc == true)
```

and replace it with:

```lua
	if not (SB.Config.Set("bags.list.sort", by) and SB.Config.Set("bags.list.desc", desc == true)) then
		return false
	end
	SB.Emit("SB_LIST_SORTED", by, desc == true)
	return true
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 2), find:

```lua
L.BANK_VIEW_SECTIONS = "SwagBag bank - category view"
```

and replace it with:

```lua
L.BANK_VIEW_SECTIONS = "SwagBag bank - category view"
L.BANK_VIEW_LIST = "SwagBag bank - list view"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 2), find:

```lua
L.LIST_EMPTY_TIP = "An empty bag slot: drop an item on the icon on the left."
```

and replace it with:

```lua
L.LIST_EMPTY_TIP = "An empty bag slot: drop an item on the icon on the left."
-- The bank's list (week 8): what its rows say (its icons are Blizzard's own bank slots).
L.LIST_BANK_ROW_TIP = "Right-click the icon on the left to take this item, or drag the icon."
L.LIST_BANK_ROW_CLICK = "Right-click the icon on the left to take the item."
L.LIST_BANK_EMPTY_TIP = "An empty bank slot: drop an item on the icon on the left."
L.LIST_BANK_GONE = "(moved or used - regroups when you close the bank)"
L.LIST_SCALE_FALLBACK_BANK = "The list view could not size the bank's item buttons, so the bank shows the category view."
```

In `SwagBag/SwagBag.toc`, find:

```text
## Version: 0.7.0
```

and replace it with:

```text
## Version: 0.8.0
```

In `SwagBag/UI/BagsWindow.lua` (edit 1 of 3), find:

```lua
-- through a full layout held while the mouse is over the items or an item is on the cursor (P5).
```

and replace it with:

```lua
-- (SB_LIST_SORTED, below) through a full layout held while the mouse is over the items or an item is
-- on the cursor (P5).
```

In `SwagBag/UI/BagsWindow.lua` (edit 2 of 3), find:

```lua
	W.RefreshColumns()
	W.Flash(L.LIST_SORTED:format(COLUMN_NAMES[spec.by], direction(spec.by, spec.desc)), quiet)
```

and replace it with:

```lua
	W.Flash(L.LIST_SORTED:format(COLUMN_NAMES[spec.by], direction(spec.by, spec.desc)), quiet)
	return true
end

-- Week 8: one order for every list (the bags, the bank, the guild bank). A sort saved from any of
-- them (Sort.Save) redraws this bar's marker and regroups the bags' list while it is drawn.
SB.On("SB_LIST_SORTED", function()
	W.RefreshColumns()
```

In `SwagBag/UI/BagsWindow.lua` (edit 3 of 3), find:

```lua
	end
	return true
end

---------------------------------------------------------------------------
```

and replace it with:

```lua
	end
end, "bags")

---------------------------------------------------------------------------
```

In `SwagBag/UI/BankWindow.lua` (edit 1 of 13), find:

```lua
-- reports. The receiving group is tinted and says "deposits go here". Items move only into
```

and replace it with:

```lua
-- reports, as categories, a list (week 8: one row per slot, the bags window's columns and order,
-- UI/ListRows.lua) or a grid. The receiving group is tinted and says "deposits go here". Items move only into
```

In `SwagBag/UI/BankWindow.lua` (edit 2 of 13), find:

```lua
	HEADER = 80, -- title row, search row, deposit line
```

and replace it with:

```lua
	HEADER = 80, -- title row, search row, deposit line
	COLUMNS_H = 18, -- the list's column bar under the deposit line (week 8), shown while a list is drawn
	scaleWarned = false, -- the list's F6 fallback was said this opening
```

In `SwagBag/UI/BankWindow.lua` (edit 3 of 13), find:

```lua
function BW.View()
	return SB.Config.Get("bank.view") == "grid" and "grid" or "sections"
end
```

and replace it with:

```lua
-- The view button's order, as in the bags window: each click shows the next one.
local VIEW_NEXT = { sections = "list", list = "grid", grid = "sections" }
local VIEW_BUTTON = { sections = L.VIEW_TO_SECTIONS, list = L.VIEW_TO_LIST, grid = L.VIEW_TO_GRID }
local VIEW_FLASH = { sections = L.BANK_VIEW_SECTIONS, list = L.BANK_VIEW_LIST, grid = L.BANK_VIEW_GRID }

function BW.View()
	local v = SB.Config.Get("bank.view")
	if v == "grid" or v == "list" then
		return v
	end
	return "sections"
end

-- The title, search and deposit rows, plus the column bar while a list is drawn (the drawn view,
-- never the setting: a view change held under the mouse keeps the old header room, W4-1).
function BW.HeaderHeight()
	return BW.HEADER + ((BW.view and BW.view.drawn == "list") and BW.COLUMNS_H or 0)
end

-- The list's rows (week 8). A click on a row's text answers in the title (F24); the texts say what
-- the bank's icons do (a right-click takes the item).
BW.rows = SB.ListRows and SB.ListRows.New(child, "bank", function(text)
	BW.Flash(text)
end, { click = L.LIST_BANK_ROW_CLICK, emptyTip = L.LIST_BANK_EMPTY_TIP, gone = L.LIST_BANK_GONE,
	tip = function(row, bag, slot)
		SB.Adapter.SlotTooltip(row, bag, slot, L.LIST_BANK_ROW_TIP)
	end }) or nil
```

In `SwagBag/UI/BankWindow.lua` (edit 4 of 13), find:

```lua
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * BW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - BW.HEADER - BW.FOOTER) + BW.HEADER + BW.FOOTER)
```

and replace it with:

```lua
	local header = BW.HeaderHeight()
	if BW.columnsBar then -- the bar shows above a drawn list only (an F6 fallback draws none)
		BW.columnsBar.frame:SetShown(BW.view.drawn == "list")
		BW.columnsBar.Refresh()
	end
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -header)
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * BW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - header - BW.FOOTER) + header + BW.FOOTER)
```

In `SwagBag/UI/BankWindow.lua` (edit 5 of 13), find:

```lua
	end,
})

searchBox = SB.SearchBox.New({
```

and replace it with:

```lua
	end,
	rows = BW.rows,
	onListFailed = function() -- F6: said once per opening; the bank shows categories
		if not BW.scaleWarned then
			BW.scaleWarned = true
			SB.Print(L.LIST_SCALE_FALLBACK_BANK)
		end
	end,
})

-- The list's column bar: Name, Count, ilvl, Value over the rows' texts (where the bags window's
-- sits: x 4 + PAD + LIST_ROW + ROW_TEXT_GAP, the rows' own columns). A click sorts every list by
-- that column (again: the other way round; one shared order, saved in bags.list).
if SB.ListRows then
	local GV = SB.GroupView
	BW.columnsBar = SB.ListRows.ColumnBar(frame, BW.view.RowWidth(), BW.COLUMNS_H, function(id)
		BW.SortList(id)
	end, "bank", "bank.listColumn")
	BW.columnsBar.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4 + GV.PAD + GV.LIST_ROW + GV.ROW_TEXT_GAP, -BW.HEADER)
end

searchBox = SB.SearchBox.New({
```

In `SwagBag/UI/BankWindow.lua` (edit 6 of 13), find:

```lua
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
```

and replace it with:

```lua
	setDimmed = function(button, dimmed) -- the button, and in the list its row
		return BW.view.SetDimmed(button, dimmed)
```

In `SwagBag/UI/BankWindow.lua` (edit 7 of 13), find:

```lua
function BW.ToggleView()
	local view = BW.View() == "grid" and "sections" or "grid"
```

and replace it with:

```lua
-- Categories -> list -> grid -> categories, like the bags window's view button.
function BW.ToggleView()
	local view = VIEW_NEXT[BW.View()]
```

In `SwagBag/UI/BankWindow.lua` (edit 8 of 13), find:

```lua
	BW.viewButton:SetText(view == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	BW.Flash(view == "grid" and L.BANK_VIEW_GRID or L.BANK_VIEW_SECTIONS)
```

and replace it with:

```lua
	BW.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[view]])
	BW.Flash(VIEW_FLASH[view])
```

In `SwagBag/UI/BankWindow.lua` (edit 9 of 13), find:

```lua
-- Config is not initialized while this file loads, so the view label is set in BW.Open().
BW.viewButton = titleButton(L.VIEW_TO_GRID, "bank.viewButton", function()
```

and replace it with:

```lua
-- A click on a column of the list: sort every list by it (Engine/Sort.lua), answered in the title (P2).
-- The drawn lists regroup through SB_LIST_SORTED (below), held while the mouse is over the items.
function BW.SortList(by)
	local spec = SB.Sort.Next(SB.Sort.Spec(), by)
	if not SB.Sort.Save(spec.by, spec.desc) then
		BW.Flash(L.SETTINGS_READONLY)
		return false
	end
	BW.Flash(SB.ListRows.SortedText(spec))
	return true
end

-- Config is not initialized while this file loads, so the view label is set in BW.Open().
BW.viewButton = titleButton(L.VIEW_TO_LIST, "bank.viewButton", function()
```

In `SwagBag/UI/BankWindow.lua` (edit 10 of 13), find:

```lua
	BW.viewButton:SetText(BW.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
```

and replace it with:

```lua
	BW.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[BW.View()]])
```

In `SwagBag/UI/BankWindow.lua` (edit 11 of 13), find:

```lua
	BW.view.Clear()
	BW.sortPending, BW.sortSawUpdate = false, false
```

and replace it with:

```lua
	BW.view.Clear()
	BW.sortPending, BW.sortSawUpdate, BW.scaleWarned = false, false, false
```

In `SwagBag/UI/BankWindow.lua` (edit 12 of 13), find:

```lua
-- Auctionator reported new prices: the section totals follow, in place.
```

and replace it with:

```lua
-- Auctionator reported new prices: the section totals and the list's Value column follow, in place.
```

In `SwagBag/UI/BankWindow.lua` (edit 13 of 13), find:

```lua
		BW.view.RefreshTotals()
```

and replace it with:

```lua
		BW.view.RefreshTotals()
		BW.view.RefreshRows()
	end
end, "bank")

-- The list's order changed (a column click in any window, /swagbag list): the bar's marker follows
-- and a drawn list regroups, held while the mouse is over the items (P5).
SB.On("SB_LIST_SORTED", function()
	if BW.columnsBar then
		BW.columnsBar.Refresh()
	end
	if frame:IsShown() and BW.view.IsOpen() and BW.view.drawn == "list" then
		BW.view.RequestLayout("listsort")
```

In `SwagBag/UI/GroupView.lua` (edit 1 of 28), find:

```lua
-- slots in physical order.
```

and replace it with:

```lua
-- slots in physical order. In the list view (week 8, spec 2.2 v1.3, like the bags window's) each
-- group's sections show one row per slot: the slot's own button scaled to the row's height
-- (SetScale only: a button is never made, reparented or re-ID'd for it), then its name, count,
-- item level and value (UI/ListRows.lua, cfg.rows), each section in Engine/Sort.lua's order. A
-- button whose scale does not take is never drawn in a row (F6): that layout draws as categories
-- instead, recorded under "none" and said once per opening (cfg.onListFailed).
```

In `SwagBag/UI/GroupView.lua` (edit 2 of 28), find:

```lua
--   v.Clear()                           window closed: hide the buttons, forget the layout
```

and replace it with:

```lua
--   v.Clear()                           window closed: hide the buttons, forget the layout
--   v.drawn                             the view the current layout was drawn in ("sections" |
--                                       "list" | "grid"); the setting may differ while a layout waits
```

In `SwagBag/UI/GroupView.lua` (edit 3 of 28), find:

```lua
--   view() -> "sections" | "grid";  columns() -> n;  newRows() -> n,
```

and replace it with:

```lua
--   view() -> "sections" | "list" | "grid";  columns() -> n;  newRows() -> n,
--   rows optional: a ListRows object (UI/ListRows.lua) over cfg.child; without it "list" draws as
--   "sections";  onListFailed() optional: a list fell back to categories (F6),
--   family(bag) optional -> a bag family for the free tile (default Adapter.BagFamily),
```

In `SwagBag/UI/GroupView.lua` (edit 4 of 28), find:

```lua
--   freeTile() optional -> true: each group's Free shows one tile per bag family with its
--   number of free slots (Engine/Layout.lua, plan D19; families from Adapter.BagFamily),
```

and replace it with:

```lua
--   freeTile(view) optional -> true: each group's Free shows one tile per bag family with its
--   number of free slots (Engine/Layout.lua, plan D19; families from cfg.family),
```

In `SwagBag/UI/GroupView.lua` (edit 5 of 28), find:

```lua
	RETRY = 0.3, DROP_GUARD = 0.3 }
```

and replace it with:

```lua
	RETRY = 0.3, DROP_GUARD = 0.3,
	-- the list view (week 8): the bags window's sizes (UI/BagsWindow.lua), so every list looks the same
	LIST_ROW = 24, LIST_GAP = 2, LIST_WIDTH = 480, LIST_NEW_ROWS = 8, ROW_TEXT_GAP = 4, SCALE_EPSILON = 0.001 }
```

In `SwagBag/UI/GroupView.lua` (edit 6 of 28), find:

```lua
		redrawPending = false, stats = {}, tiled = {} }
```

and replace it with:

```lua
		redrawPending = false, stats = {}, tiled = {}, drawn = "sections" }
	local rows = cfg.rows

	-- The view a layout is built for: the setting, with "list" only when there are rows to draw it.
	local function wanted()
		local view = cfg.view()
		if view == "list" and not rows then
			return "sections"
		end
		return view
	end

	local function isList()
		return v.drawn == "list"
	end

	-- A row's texts start right of its icon and end at the list's right edge.
	local function rowWidth()
		return GV.LIST_WIDTH - 2 * GV.PAD - GV.LIST_ROW - GV.ROW_TEXT_GAP
	end
	v.RowWidth = rowWidth
```

In `SwagBag/UI/GroupView.lua` (edit 7 of 28), find:

```lua
	local function positionOpts(top)
```

and replace it with:

```lua
	local function positionOpts(top, list)
		if list then -- one column of rows, each as tall as its (scaled) button
			return { columns = 1, size = GV.LIST_ROW, gap = GV.LIST_GAP, padding = GV.PAD, header = GV.SECTION_HEADER,
				sectionGap = GV.SECTION_GAP, top = top }
		end
```

In `SwagBag/UI/GroupView.lua` (edit 8 of 28), find:

```lua
	-- groups/records default to the view's own (a full layout positions a candidate first).
	local function positionAll(groups, records)
		groups, records = groups or v.groups, records or v.records
		local cols = cfg.columns()
		local all = { cells = {}, byKey = {}, placeholders = {}, headers = {}, groupHeaders = {}, tiles = {},
			width = GV.PAD * 2 + cols * GV.SLOT + (cols - 1) * GV.GAP }
```

and replace it with:

```lua
	-- groups/records/view default to the view's own (a full layout positions a candidate first).
	local function positionAll(groups, records, view)
		groups, records, view = groups or v.groups, records or v.records, view or v.drawn
		local list = view == "list"
		local cols = cfg.columns()
		local all = { cells = {}, byKey = {}, placeholders = {}, headers = {}, groupHeaders = {}, tiles = {},
			width = list and GV.LIST_WIDTH or (GV.PAD * 2 + cols * GV.SLOT + (cols - 1) * GV.GAP) }
```

In `SwagBag/UI/GroupView.lua` (edit 9 of 28), find:

```lua
				pos = SB.Layout.Position(g.state, positionOpts(y), col)
```

and replace it with:

```lua
				pos = SB.Layout.Position(g.state, positionOpts(y, list), col)
```

In `SwagBag/UI/GroupView.lua` (edit 10 of 28), find:

```lua
	---------------------------------------------------------------------------
	local function place(button, x, y)
```

and replace it with:

```lua
	---------------------------------------------------------------------------
	-- A point's offsets are in the button's own scale, so a button drawn smaller (the list) is
	-- offset by x / scale, y / scale to land on the same spot of the scroll child (as Buttons.Place).
	local function place(button, x, y)
```

In `SwagBag/UI/GroupView.lua` (edit 11 of 28), find:

```lua
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x, y)
			v.placed[button] = at
		end
```

and replace it with:

```lua
			local scale = button:GetScale() or 1
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x / scale, y / scale)
			v.placed[button] = at
		end
	end

	local function scaleIs(button, scale)
		return math.abs((button:GetScale() or 1) - scale) < GV.SCALE_EPSILON
	end

	-- Buttons are drawn at row size in the list and at full size elsewhere (not protected, spec 4.1:
	-- legal in combat). A button whose scale changes is placed again. False when the scale did not take.
	local function setScale(button, scale)
		if not scaleIs(button, scale) then
			button:SetScale(scale)
			v.placed[button] = nil
		end
		return scaleIs(button, scale)
	end

	local function listScale()
		return GV.LIST_ROW / GV.SLOT
```

In `SwagBag/UI/GroupView.lua` (edit 12 of 28), find:

```lua
	local function showAt(button, c)
		if c.shown and inSize(c) then
```

and replace it with:

```lua
	-- Ruling W5-1 for the bank and guild lists (F6): a list row never shows a full-size button. One whose
	-- scale is not the row's stays hidden, row and all, and a full layout follows when the mouse allows.
	local function showAt(button, c)
		local shown = c.shown and inSize(c)
		if shown and isList() and not scaleIs(button, listScale()) then
			shown = false
			SB.Debounce(cfg.key .. ".scale", GV.RETRY, function()
				v.RequestLayout("scale")
			end, window)
		end
		if shown then
```

In `SwagBag/UI/GroupView.lua` (edit 13 of 28), find:

```lua
			button:Hide()
		end
```

and replace it with:

```lua
			button:Hide()
		end
		if isList() then -- a spare (hidden, no position) has no row either
			rows.Place(button, shown and c.x + GV.LIST_ROW + GV.ROW_TEXT_GAP, c.y, rowWidth(), GV.LIST_ROW, shown)
		end
```

In `SwagBag/UI/GroupView.lua` (edit 14 of 28), find:

```lua
		for _, p in ipairs(pos.placeholders) do
			if p.shown then
				B.AcquirePlaceholder(child, p.icon, GV.SLOT, p.x, p.y, window)
			end
```

and replace it with:

```lua
		local ghosts = {}
		for _, p in ipairs(pos.placeholders) do
			if p.shown then
				B.AcquirePlaceholder(child, p.icon, isList() and GV.LIST_ROW or GV.SLOT, p.x, p.y, window)
				ghosts[#ghosts + 1] = { x = p.x + GV.LIST_ROW + GV.ROW_TEXT_GAP, y = p.y }
			end
		end
		if isList() then -- a placeholder's row says the item moved or was used
			rows.Ghosts(ghosts, rowWidth(), GV.LIST_ROW)
```

In `SwagBag/UI/GroupView.lua` (edit 15 of 28), find:

```lua
	-- really is empty (a drop held under the mouse shows the item); other numbers are cleared.
```

and replace it with:

```lua
	-- really is empty (a drop held under the mouse shows the item); other numbers are cleared.
	-- In the list a tile's row says how many are free (and for what); a button that stops being a tile
	-- gets its row's texts back from its record.
```

In `SwagBag/UI/GroupView.lua` (edit 16 of 28), find:

```lua
				now[button] = true
			end
		end
		for button in pairs(v.tiled) do
			if not now[button] then
				SB.Buttons.SetFreeCount(button, nil)
```

and replace it with:

```lua
				now[button] = t
				if isList() then
					rows.Paint(button, t.bag, t.slot, nil, t.count, t.tile)
				end
			end
		end
		for button, t in pairs(v.tiled) do
			if not now[button] then
				SB.Buttons.SetFreeCount(button, nil)
				if isList() then
					rows.Paint(button, t.bag, t.slot, v.records[keyOf(t.bag, t.slot)])
				end
```

In `SwagBag/UI/GroupView.lua` (edit 17 of 28), find:

```lua
			if not pos.byKey[k] then
				local button = cfg.button(c.bag, c.slot)
				if button then
					button:Hide()
				end
			end
		end
```

and replace it with:

```lua
			if not pos.byKey[k] then
				local button = cfg.button(c.bag, c.slot)
				if button then
					button:Hide()
					if rows then
						rows.Place(button, 0, 0, 0, 0, false)
					end
				end
			end
		end
```

In `SwagBag/UI/GroupView.lua` (edit 18 of 28), find:

```lua
			return b ~= nil and b:IsShown() and b:IsMouseOver()
```

and replace it with:

```lua
			-- in the list a row under the mouse holds its button too (P5: its text would move with it)
			return b ~= nil and b:IsShown() and (b:IsMouseOver() or (isList() and rows.IsMouseOver(b)))
```

In `SwagBag/UI/GroupView.lua` (edit 19 of 28), find:

```lua
	local function build()
		local A = SB.Adapter
		local b = { groups = {}, byId = {}, records = {}, sizes = {}, groupOf = {},
			ms = { groups = 0, read = 0, categories = 0, positions = 0, drawing = 0 } }
		local sections = cfg.view() ~= "grid"
```

and replace it with:

```lua
	-- view: the view to build (default: the setting's, wanted()); b.view says which.
	local function build(view)
		local A = SB.Adapter
		view = view or wanted()
		local b = { groups = {}, byId = {}, records = {}, sizes = {}, groupOf = {}, view = view,
			ms = { groups = 0, read = 0, categories = 0, positions = 0, drawing = 0 } }
		local sections = view ~= "grid"
		local list = view == "list"
```

In `SwagBag/UI/GroupView.lua` (edit 20 of 28), find:

```lua
					if cfg.button(bag.bag, slot) then
```

and replace it with:

```lua
					local button = cfg.button(bag.bag, slot)
					if button then
```

In `SwagBag/UI/GroupView.lua` (edit 21 of 28), find:

```lua
						slots[#slots + 1] = { bag = bag.bag, slot = slot, record = record }
```

and replace it with:

```lua
						slots[#slots + 1] = { bag = bag.bag, slot = slot, record = record }
						if list then
							rows.Paint(button, bag.bag, slot, record)
						end
```

In `SwagBag/UI/GroupView.lua` (edit 22 of 28), find:

```lua
				g.state = SB.Layout.Build(slots, SB.Categorizer.Assign, order, { columns = cfg.columns(),
					newRows = cfg.newRows(), freeTile = cfg.freeTile and cfg.freeTile() or nil,
					family = SB.Adapter.BagFamily, hideEmptyNew = cfg.hideEmptyNew })
```

and replace it with:

```lua
				if list then -- each section lists its items in the list's order (Engine/Sort.lua)
					slots = SB.Sort.DisplayOrder(slots, SB.Sort.Spec(), SB.Sort.Value)
				end
				g.state = SB.Layout.Build(slots, SB.Categorizer.Assign, order, { columns = list and 1 or cfg.columns(),
					newRows = list and GV.LIST_NEW_ROWS or cfg.newRows(), freeTile = cfg.freeTile and cfg.freeTile(view) or nil,
					family = cfg.family or SB.Adapter.BagFamily, hideEmptyNew = cfg.hideEmptyNew })
```

In `SwagBag/UI/GroupView.lua` (edit 23 of 28), find:

```lua
		local pos = positionAll(b.groups, b.records)
		b.ms.positions = SB.Adapter.ProfileMs() - t
		return pos
```

and replace it with:

```lua
		local pos = positionAll(b.groups, b.records, b.view)
		b.ms.positions = SB.Adapter.ProfileMs() - t
		return pos
	end

	-- Every button of a candidate at one scale (F6: sized before the list is drawn). False when a
	-- scale did not take for any button.
	local function scaleAll(b, scale)
		local ok = true
		for _, g in ipairs(b.groups) do
			for _, bag in ipairs(g.bags) do
				for slot = 1, bag.size do
					local button = cfg.button(bag.bag, slot)
					if button and not setScale(button, scale) then
						ok = false
					end
				end
			end
		end
		return ok
	end

	-- F6: a full-size button in a 24 px row would cover the next row, so a click there could take or
	-- deposit the wrong item. That layout draws as categories instead: recorded (never Safe Mode), and
	-- the window says it once per opening (cfg.onListFailed).
	local function listFailed(b)
		scaleAll(b, 1)
		SB.ErrorTrap.OnError(cfg.key .. ".listScale", "none", "a slot button's SetScale did not take", nil)
		if cfg.onListFailed then
			cfg.onListFailed()
		end
```

In `SwagBag/UI/GroupView.lua` (edit 24 of 28), find:

```lua
		local t1 = SB.Adapter.ProfileMs()
```

and replace it with:

```lua
		local t1 = SB.Adapter.ProfileMs()
		if b.view == "list" and not scaleAll(b, listScale()) then
			listFailed(b)
			b = build("sections")
			pos = positionTimed(b)
		elseif b.view ~= "list" then
			scaleAll(b, 1)
		end
```

In `SwagBag/UI/GroupView.lua` (edit 25 of 28), find:

```lua
			b.groupOf, false
```

and replace it with:

```lua
			b.groupOf, false
		v.drawn = b.view
```

In `SwagBag/UI/GroupView.lua` (edit 26 of 28), find:

```lua
			hideGone(old, pos)
```

and replace it with:

```lua
			hideGone(old, pos)
		end
		if rows then -- the rows drawn now are placed again by render (a list), or stay hidden
			rows.HideAll()
```

In `SwagBag/UI/GroupView.lua` (edit 27 of 28), find:

```lua
	function v.SetRecord(bag, slot, record)
		v.records[keyOf(bag, slot)] = record
```

and replace it with:

```lua
	-- A live repaint (count, lock, loaded data, an item that arrived or left): in the list the row's texts
	-- follow, in place (nothing moves).
	function v.SetRecord(bag, slot, record)
		v.records[keyOf(bag, slot)] = record
		if isList() and v.pos then
			local button = cfg.button(bag, slot)
			if button and not v.tiled[button] then
				rows.Paint(button, bag, slot, record)
			end
		end
	end

	-- Prices changed (F8): each row's Value follows, texts only; nothing moves and nothing re-sorts.
	function v.RefreshRows()
		if not (isList() and v.pos) then
			return
		end
		v.ForEachSlot(function(button, record, bag, slot)
			if record then
				rows.Paint(button, bag, slot, record)
			end
		end)
	end

	-- Search dimming: the button, and in the list its row (AC5.1).
	function v.SetDimmed(button, dimmed)
		SB.Buttons.SetDimmed(button, dimmed)
		if rows then
			rows.SetDimmed(button, dimmed)
		end
```

In `SwagBag/UI/GroupView.lua` (edit 28 of 28), find:

```lua
		SB.SectionHeaders.ReleaseAll(cfg.child)
```

and replace it with:

```lua
		SB.SectionHeaders.ReleaseAll(cfg.child)
		if rows then
			rows.HideAll()
		end
```

In `SwagBag/UI/ListRows.lua` (edit 1 of 8), find:

```lua
--   ListRows.New(parent, window, flash) -> rows  window: kept for the caller's signature (the rows'
--                                              scripts always trap as "none", F3); flash(text): the
--                                              window's title flash, called on a click on a row's text
```

and replace it with:

```lua
--   ListRows.New(parent, window, flash, opts) -> rows  window: kept for the caller's signature (the
--                                              rows' scripts always trap as "none", F3); flash(text): the
--                                              window's title flash, called on a click on a row's text;
--                                              opts (week 8, the bank and guild bank lists), each optional:
--                                              tip(row, bag, slot) the item's tooltip (default: the bag
--                                              slot's, with L.LIST_ROW_TIP), click / emptyClick / emptyTip /
--                                              gone: the texts a row says (default: the bags window's)
```

In `SwagBag/UI/ListRows.lua` (edit 2 of 8), find:

```lua
--   ListRows.Texts(record, freeCount, family) -> { name, count, ilvl, value } pure
```

and replace it with:

```lua
--   ListRows.Texts(record, freeCount, family) -> { name, count, ilvl, value } pure
--   ListRows.SortedText(spec) -> "Sorted by Value, highest first"   pure
--   ListRows.ColumnBar(parent, width, height, onClick, window, label) -> bar   (week 8) the column
--                                              header bar over a list's row texts: plain buttons Name, Count, ilvl, Value,
--                                              each calling onClick(id) under ErrorTrap (window, label);
--                                              bar.frame, bar.buttons[id], bar.Refresh() (the sorted column's
--                                              marker, Sort.Spec())
```

In `SwagBag/UI/ListRows.lua` (edit 3 of 8), find:

```lua
SB.ListRows = LR
```

and replace it with:

```lua
SB.ListRows = LR
LR.COLUMN_NAMES = { name = L.LIST_COL_NAME, count = L.LIST_COL_COUNT, ilvl = L.LIST_COL_ILVL, value = L.LIST_COL_VALUE }
```

In `SwagBag/UI/ListRows.lua` (edit 4 of 8), find:

```lua
end

local function hideTip()
```

and replace it with:

```lua
end

-- How an order reads: "Sorted by Value, highest first" (names A to Z, numbers highest first).
function LR.SortedText(spec)
	local dir
	if spec.by == "name" then
		dir = spec.desc and L.LIST_Z_TO_A or L.LIST_A_TO_Z
	else
		dir = spec.desc and L.LIST_HIGH_FIRST or L.LIST_LOW_FIRST
	end
	return L.LIST_SORTED:format(LR.COLUMN_NAMES[spec.by], dir)
end

-- Week 8: the column bar of the bank's and the guild bank's lists (the bags window keeps its own, the
-- same shape). The bar is as wide as the rows' texts, so each header sits over its column.
function LR.ColumnBar(parent, width, height, onClick, window, label)
	local bar = { frame = CreateFrame("Frame", nil, parent), buttons = {} }
	bar.frame:SetSize(width, height)
	bar.frame:Hide()
	local cols = LR.Columns(width)
	for _, id in ipairs(SB.Sort.COLUMNS) do
		local b = CreateFrame("Button", nil, bar.frame)
		b:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", cols[id].x, 0)
		b:SetSize(cols[id].width, height)
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.label:SetAllPoints(b)
		b.label:SetJustifyH(id == "name" and "LEFT" or "RIGHT")
		b.label:SetText(LR.COLUMN_NAMES[id])
		if SB.Theme then
			SB.Theme.Text(b.label, "small")
		end
		b:SetScript("OnClick", SB.ErrorTrap.Guard(label, function()
			onClick(id)
		end, window))
		bar.buttons[id] = b
	end
	function bar.Refresh()
		local spec = SB.Sort.Spec()
		for id, b in pairs(bar.buttons) do
			if id == spec.by then
				b.label:SetText((spec.desc and L.LIST_COL_DOWN or L.LIST_COL_UP):format(LR.COLUMN_NAMES[id]))
			else
				b.label:SetText(LR.COLUMN_NAMES[id])
			end
		end
	end
	return bar
end

local function hideTip()
```

In `SwagBag/UI/ListRows.lua` (edit 5 of 8), find:

```lua
function LR.New(parent, _window, flash)
```

and replace it with:

```lua
function LR.New(parent, _window, flash, opts)
	opts = opts or {}
```

In `SwagBag/UI/ListRows.lua` (edit 6 of 8), find:

```lua
			SB.Adapter.SlotTooltip(row, s.bag, s.slot, L.LIST_ROW_TIP)
		elseif GameTooltip then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.LIST_EMPTY_TIP, 1, 1, 1, 1, true)
```

and replace it with:

```lua
			if opts.tip then
				opts.tip(row, s.bag, s.slot)
			else
				SB.Adapter.SlotTooltip(row, s.bag, s.slot, L.LIST_ROW_TIP)
			end
		elseif GameTooltip then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:SetText(opts.emptyTip or L.LIST_EMPTY_TIP, 1, 1, 1, 1, true)
```

In `SwagBag/UI/ListRows.lua` (edit 7 of 8), find:

```lua
		answer((s and s.filled) and L.LIST_ROW_CLICK or L.LIST_EMPTY_CLICK)
```

and replace it with:

```lua
		answer((s and s.filled) and (opts.click or L.LIST_ROW_CLICK) or (opts.emptyClick or L.LIST_EMPTY_CLICK))
```

In `SwagBag/UI/ListRows.lua` (edit 8 of 8), find:

```lua
			setTexts(row, { name = L.LIST_GONE, count = "", ilvl = "", value = "" })
```

and replace it with:

```lua
			setTexts(row, { name = opts.gone or L.LIST_GONE, count = "", ilvl = "", value = "" })
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1404 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (72 files)`, `1404 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Init.lua \
	SwagBag/Engine/Profiles.lua \
	SwagBag/Engine/Sort.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/SwagBag.toc \
	SwagBag/UI/BagsWindow.lua \
	SwagBag/UI/BankWindow.lua \
	SwagBag/UI/GroupView.lua \
	SwagBag/UI/ListRows.lua \
	spec/bagswindow_list_spec.lua \
	spec/bankwindow_list_spec.lua \
	spec/helpers/uienv.lua \
	spec/profiles_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 8 Task 1: the list view in the bank window (GroupView list, shared column order, F6); v0.8.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 2: The list view in the guild bank window

The guild bank gets the same list (D1–D4, D6): its view button cycles Categories → List → Grid, its column bar sits under the deposit line, a row's tooltip is the guild slot's (`Adapter.GuildTooltip`, not a bag slot's), its texts say what the guild bank's icons do, and each tab's empty slots are one free row in the list only (`freeTile(view)`, family `"any"`). A button whose scale does not take makes that layout categories, said once per opening. `guildBank.view` may hold `"list"` in a share string.

**Files:**
- Modify: `SwagBag/UI/GuildBankWindow.lua`, `SwagBag/Engine/Profiles.lua`, `SwagBag/Locale/enUS.lua`
- Create: `spec/guildbank_list_spec.lua`
- Test: `spec/profiles_spec.lua`

**Interfaces:**
- Consumes: everything Task 1 produced in GroupView and ListRows; `SB_LIST_SORTED`; `GW.view`, `GW.Flash`, `SB.GuildButtons.Get`, `Adapter.GuildTooltip`.
- Produces: `GW.rows`, `GW.columnsBar`, `GW.SortList(by)`, `GW.HeaderHeight()`, `GW.COLUMNS_H`, `GW.scaleWarned`; `L.GUILD_VIEW_LIST`, `L.LIST_GUILD_ROW_CLICK`, `L.LIST_GUILD_EMPTY_TIP`, `L.LIST_GUILD_GONE`, `L.LIST_SCALE_FALLBACK_GUILD`.

- [ ] **Step 1: Write the failing tests**

Create `spec/guildbank_list_spec.lua`:

```lua
-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 8: the guild bank window's list view over the real engine and GroupView: one group per tab, one row per
-- slot beside SwagBag's own guild slot button (scaled, never made for it), each tab's empty slots as one free
-- row, the guild slot's tooltip, the shared column order, search and F6.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("GuildBankWindow list view (week 8)", function()
	local SB, A, GW, GV
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		Fake.Install()
		Env.PaintGlobals()
		A.frames.GuildBankFrame = Fake.New("Frame", UIParent)
		A.guild.tabs = { { tab = 1, name = "Mats", withdrawals = 5 }, { tab = 2, name = "Pots", withdrawals = 5 } }
		A.items[Fixtures.HEALING_POTION].sellPrice = 100 -- the stack of 5: 500
		A.items[Fixtures.FLASK].sellPrice = 1000 -- one: 1000
		A.guild.slots = { [1] = { [1] = { itemID = Fixtures.HERB, count = 20 }, [2] = { itemID = Fixtures.ORE, count = 5 } },
			[2] = { [1] = { itemID = Fixtures.HEALING_POTION, count = 5 }, [2] = { itemID = Fixtures.FLASK, count = 1 } } }
		A.guild.current = 1
		GW = Env.LoadGuild(SB)
		GV = SB.GroupView
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openVault()
		SB.eventFrame:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "GuildBanker")
		for _ = 1, 4 do -- the client answers each tab's query
			SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
			A.Advance(0.06)
		end
		A.Advance(GV.RETRY)
	end

	local function button(tab, slot)
		return SB.GuildButtons.Get(tab, slot)
	end

	local function row(tab, slot)
		return GW.rows.rows[button(tab, slot)]
	end

	local function y(tab, slot)
		local b = button(tab, slot)
		local p = b.points[#b.points]
		return math.floor(p[5] * b.scale * 1000 + 0.5) / 1000
	end

	local function labels()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	-- Mutation: in the guild window's GroupView cfg, freeTile returns false (98-slot tabs: one row per empty slot).
	it("each tab's sections, one row per slot beside its button at row size; a tab's empty slots are one free row",
		function()
			SB.Config.Set("guildBank.view", "list")
			openVault()
			assert.equal("list", GW.view.drawn)
			assert.same({ "- New (0)", "- Herbs (1)", "- Ore (1)", "- Free (96)" }, { unpack(labels(), 3, 6) })
			assert.equal(GV.LIST_ROW / GV.SLOT, button(1, 1).scale)
			assert.equal(y(1, 1), row(1, 1).points[1][5])
			assert.same({ "Mycobloom", "20" }, { row(1, 1).name.text, row(1, 1).count.text })
			assert.equal(SB.L.LIST_FREE:format(96), row(1, 3).name.text, "the first empty slot is the free row")
			assert.falsy(button(1, 4).shown, "every other empty slot is a hidden spare")
			assert.truthy(GW.columnsBar.frame.shown)
		end)

	-- Mutation: in GuildBankWindow.lua, drop the rows' `tip = function ... end` (the row would ask for a bag slot's
	-- tooltip at bag 101).
	it("a row's tooltip is the guild slot's; a click on its text says to right-click the icon", function()
		SB.Config.Set("guildBank.view", "list")
		openVault()
		Fake.Fire(row(1, 2), "OnEnter")
		assert.same({ 1, 2 }, { A.tooltip.tab, A.tooltip.slot })
		assert.is_nil(A.slotTip)
		Fake.Fire(row(1, 2), "OnMouseUp")
		assert.equal(SB.L.LIST_GUILD_ROW_CLICK, GW.frame.title.text)
	end)

	-- Mutation: in GuildBankWindow.lua, VIEW_NEXT's `sections = "list"` -> `sections = "grid"`.
	it("the view button shows categories, list and grid in turn; a list sorts by a column click (one shared order)",
		function()
			openVault()
			assert.equal(SB.L.VIEW_TO_LIST, GW.viewButton.text)
			Fake.Fire(GW.viewButton, "OnClick")
			assert.same({ "list", SB.L.GUILD_VIEW_LIST, SB.L.VIEW_TO_GRID },
				{ GW.view.drawn, GW.frame.title.text, GW.viewButton.text })
			assert.truthy(y(2, 2) > y(2, 1), "flask (1000) above potion (500)")
			Fake.Fire(GW.columnsBar.buttons.name, "OnClick")
			assert.equal("Sorted by Name, A to Z", GW.frame.title.text)
			assert.truthy(y(2, 1) > y(2, 2), "Algari Healing Potion above Flask of Alchemical Chaos")
			Fake.Fire(GW.viewButton, "OnClick")
			assert.same({ "grid", 1 }, { GW.view.drawn, button(2, 1).scale })
			assert.falsy(GW.columnsBar.frame.shown)
		end)

	-- Spec 4.3. Mutation: in GuildBankWindow.lua, drop `gone = L.LIST_GUILD_GONE` (the ghost would name the bag).
	it("a withdrawal leaves a ghost row that says the guild bank regroups when closed; search dims rows", function()
		SB.Config.Set("guildBank.view", "list")
		openVault()
		local herb = y(1, 1)
		A.guild.slots[1][1] = nil
		SB.eventFrame:Fire("GUILDBANKBAGSLOTS_CHANGED")
		A.Advance(0.06)
		local ghost = GW.rows.ghosts[1]
		assert.same({ SB.L.LIST_GUILD_GONE, herb }, { ghost.name.text, ghost.points[1][5] })
		GW.searchBox.editBox:SetText("ore")
		Fake.Fire(GW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
		assert.same({ SB.Buttons.DIM_ALPHA, 1 }, { row(2, 1).alpha, row(1, 2).alpha })
	end)

	-- F6. Mutation: in the guild window's onListFailed, drop `SB.Print(L.LIST_SCALE_FALLBACK_GUILD)`.
	it("F6: a guild button whose scale does not take: categories, said once per opening", function()
		openVault()
		button(2, 2).SetScale = function() end
		Fake.Fire(GW.viewButton, "OnClick")
		assert.same({ "sections", 1 }, { GW.view.drawn, button(1, 1).scale })
		GW.Reflow("reflow")
		assert.same({ SB.L.LIST_SCALE_FALLBACK_GUILD }, A.Lines())
	end)
end)
```

In `spec/profiles_spec.lua`, find:

```lua
		assert.equal("list", data.settings["bank.view"])
```

and replace it with:

```lua
		assert.equal("list", data.settings["bank.view"])
	end)

	-- Week 8. Mutation: drop "list" from guildBank.view's words in VALID.
	it("the guild bank's list view travels in a share string", function()
		C.Set("guildBank.view", "list")
		local data = assert(Pr.Parse(Pr.Export(false)))
		assert.equal("list", data.settings["guildBank.view"])
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1404 passed, 6 failed`. The failures, exactly:

- `spec/guildbank_list_spec.lua :: GuildBankWindow list view (week 8) > each tab's sections, one row per slot beside its button at row size; a tab's empty slots are one free row`
- `spec/guildbank_list_spec.lua :: GuildBankWindow list view (week 8) > a row's tooltip is the guild slot's; a click on its text says to right-click the icon`
- `spec/guildbank_list_spec.lua :: GuildBankWindow list view (week 8) > the view button shows categories, list and grid in turn; a list sorts by a column click (one shared order)`
- `spec/guildbank_list_spec.lua :: GuildBankWindow list view (week 8) > a withdrawal leaves a ghost row that says the guild bank regroups when closed; search dims rows`
- `spec/guildbank_list_spec.lua :: GuildBankWindow list view (week 8) > F6: a guild button whose scale does not take: categories, said once per opening`
- `spec/profiles_spec.lua :: Profiles (week 7) > the guild bank's list view travels in a share string`

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "each tab's sections, one row per slot beside its button at row size; a tab's empty slots are one free row": in `SwagBag/UI/GuildBankWindow.lua`, `freeTile = function(view) ⏎ return view == "list"` → `freeTile = function(view) ⏎ return view == false`.
- "a row's tooltip is the guild slot's; a click on its text says to right-click the icon": in `SwagBag/UI/GuildBankWindow.lua`, `tip = function(row, bag, slot) ⏎ SB.Adapter.GuildTooltip(row, tabOf(bag), slot) ⏎ end })` → `})`.
- "the view button shows categories, list and grid in turn; a list sorts by a column click (one shared order)": in `SwagBag/UI/GuildBankWindow.lua`, `local VIEW_NEXT = { sections = "list", list = "grid", grid = "sections" }` → `local VIEW_NEXT = { sections = "grid", list = "grid", grid = "sections" }`.
- "a withdrawal leaves a ghost row that says the guild bank regroups when closed; search dims rows": in `SwagBag/UI/GuildBankWindow.lua`, `gone = L.LIST_GUILD_GONE,` → ∅.
- "F6: a guild button whose scale does not take: categories, said once per opening": in `SwagBag/UI/GuildBankWindow.lua`, `SB.Print(L.LIST_SCALE_FALLBACK_GUILD)` → ∅.
- "the guild bank's list view travels in a share string": in `SwagBag/Engine/Profiles.lua`, `["guildBank.view"] = words("sections", "grid", "list")` → `["guildBank.view"] = words("sections", "grid")`.

- [ ] **Step 3: Write the code**

In `SwagBag/Engine/Profiles.lua`, find:

```lua
	["guildBank.mode"] = words("full", "view"), ["guildBank.view"] = words("sections", "grid"),
```

and replace it with:

```lua
	["guildBank.mode"] = words("full", "view"), ["guildBank.view"] = words("sections", "grid", "list"),
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 2), find:

```lua
L.GUILD_VIEW_SECTIONS = "SwagBag guild bank - category view"
```

and replace it with:

```lua
L.GUILD_VIEW_SECTIONS = "SwagBag guild bank - category view"
L.GUILD_VIEW_LIST = "SwagBag guild bank - list view"
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 2), find:

```lua
L.LIST_SCALE_FALLBACK_BANK = "The list view could not size the bank's item buttons, so the bank shows the category view."
```

and replace it with:

```lua
L.LIST_SCALE_FALLBACK_BANK = "The list view could not size the bank's item buttons, so the bank shows the category view."
-- The guild bank's list (week 8): its icons are SwagBag's own guild slot buttons (UI/GuildButtons.lua).
L.LIST_GUILD_ROW_CLICK = "Right-click the icon on the left to take the item (from the tab Blizzard has selected)."
L.LIST_GUILD_EMPTY_TIP = "An empty guild bank slot: drop an item on the icon on the left."
L.LIST_GUILD_GONE = "(moved - regroups when you close the guild bank)"
L.LIST_SCALE_FALLBACK_GUILD = "The list view could not size the guild bank's item buttons, so it shows the category view."
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 1 of 14), find:

```lua
-- withdrawals left in the header (AC16.2) and its own category sections or grid; the window
```

and replace it with:

```lua
-- withdrawals left in the header (AC16.2) and its own category sections, list (week 8: one row per
-- slot, the bags window's columns and order, each tab's empty slots as one free row) or grid; the window
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 2 of 14), find:

```lua
	HEADER = 80,
```

and replace it with:

```lua
	HEADER = 80,
	COLUMNS_H = 18, -- the list's column bar under the deposit line (week 8), shown while a list is drawn
	scaleWarned = false, -- the list's F6 fallback was said this opening
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 3 of 14), find:

```lua
function GW.View()
	return SB.Config.Get("guildBank.view") == "grid" and "grid" or "sections"
```

and replace it with:

```lua
-- The view button's order, as in the bags and bank windows: each click shows the next one.
local VIEW_NEXT = { sections = "list", list = "grid", grid = "sections" }
local VIEW_BUTTON = { sections = L.VIEW_TO_SECTIONS, list = L.VIEW_TO_LIST, grid = L.VIEW_TO_GRID }
local VIEW_FLASH = { sections = L.GUILD_VIEW_SECTIONS, list = L.GUILD_VIEW_LIST, grid = L.GUILD_VIEW_GRID }

function GW.View()
	local v = SB.Config.Get("guildBank.view")
	if v == "grid" or v == "list" then
		return v
	end
	return "sections"
end

-- The title, search and deposit rows, plus the column bar while a list is drawn (the drawn view, W4-1).
function GW.HeaderHeight()
	return GW.HEADER + ((GW.view and GW.view.drawn == "list") and GW.COLUMNS_H or 0)
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 4 of 14), find:

```lua
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * GW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - GW.HEADER - GW.FOOTER) + GW.HEADER + GW.FOOTER)
	clampScroll()
end
```

and replace it with:

```lua
	local header = GW.HeaderHeight()
	if GW.columnsBar then -- the bar shows above a drawn list only (an F6 fallback draws none)
		GW.columnsBar.frame:SetShown(GW.view.drawn == "list")
		GW.columnsBar.Refresh()
	end
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -header)
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * GW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - header - GW.FOOTER) + header + GW.FOOTER)
	clampScroll()
end

-- The list's rows (week 8). Guild slots are not bag slots: a row's tooltip is the guild slot's, and its
-- texts say what the guild bank's icons do.
GW.rows = SB.ListRows and SB.ListRows.New(child, "bank", function(text)
	GW.Flash(text)
end, { click = L.LIST_GUILD_ROW_CLICK, emptyTip = L.LIST_GUILD_EMPTY_TIP, gone = L.LIST_GUILD_GONE,
	tip = function(row, bag, slot)
		SB.Adapter.GuildTooltip(row, tabOf(bag), slot)
	end }) or nil
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 5 of 14), find:

```lua
	end,
	onResize = sizeFrame,
```

and replace it with:

```lua
	end,
	-- The list shows each tab's empty slots as one free row (a 98-slot tab would be 98 rows); categories
	-- and the grid show every empty slot, as before. Guild tabs have no bag family.
	freeTile = function(view)
		return view == "list"
	end,
	family = function()
		return "any"
	end,
	onResize = sizeFrame,
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 6 of 14), find:

```lua
	end,
})

searchBox = SB.SearchBox.New({
```

and replace it with:

```lua
	end,
	rows = GW.rows,
	onListFailed = function() -- F6: said once per opening; the guild bank shows categories
		if not GW.scaleWarned then
			GW.scaleWarned = true
			SB.Print(L.LIST_SCALE_FALLBACK_GUILD)
		end
	end,
})

-- The list's column bar, as the bank window's: a click sorts every list (one shared order).
if SB.ListRows then
	local GV = SB.GroupView
	GW.columnsBar = SB.ListRows.ColumnBar(frame, GW.view.RowWidth(), GW.COLUMNS_H, function(id)
		GW.SortList(id)
	end, "bank", "guild.listColumn")
	GW.columnsBar.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4 + GV.PAD + GV.LIST_ROW + GV.ROW_TEXT_GAP, -GW.HEADER)
end

searchBox = SB.SearchBox.New({
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 7 of 14), find:

```lua
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
```

and replace it with:

```lua
	setDimmed = function(button, dimmed) -- the button, and in the list its row
		return GW.view.SetDimmed(button, dimmed)
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 8 of 14), find:

```lua
function GW.ToggleView()
	local view = GW.View() == "grid" and "sections" or "grid"
```

and replace it with:

```lua
-- Categories -> list -> grid -> categories, like the bags and bank windows.
function GW.ToggleView()
	local view = VIEW_NEXT[GW.View()]
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 9 of 14), find:

```lua
	GW.viewButton:SetText(view == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	GW.Flash(view == "grid" and L.GUILD_VIEW_GRID or L.GUILD_VIEW_SECTIONS)
```

and replace it with:

```lua
	GW.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[view]])
	GW.Flash(VIEW_FLASH[view])
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 10 of 14), find:

```lua
GW.viewButton = titleButton(L.VIEW_TO_GRID, "guild.viewButton", function()
```

and replace it with:

```lua
-- A click on a column of the list: sort every list by it, answered in the title (P2). The drawn lists
-- regroup through SB_LIST_SORTED (below), held while the mouse is over the items.
function GW.SortList(by)
	local spec = SB.Sort.Next(SB.Sort.Spec(), by)
	if not SB.Sort.Save(spec.by, spec.desc) then
		GW.Flash(L.SETTINGS_READONLY)
		return false
	end
	GW.Flash(SB.ListRows.SortedText(spec))
	return true
end

GW.viewButton = titleButton(L.VIEW_TO_LIST, "guild.viewButton", function()
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 11 of 14), find:

```lua
	GW.viewButton:SetText(GW.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
```

and replace it with:

```lua
	GW.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[GW.View()]])
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 12 of 14), find:

```lua
	GW.queue, GW.querying = {}, nil
```

and replace it with:

```lua
	GW.queue, GW.querying, GW.scaleWarned = {}, nil, false
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 13 of 14), find:

```lua
-- Auctionator reported new prices: the section totals follow, in place.
```

and replace it with:

```lua
-- Auctionator reported new prices: the section totals and the list's Value column follow, in place.
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 14 of 14), find:

```lua
		GW.view.RefreshTotals()
```

and replace it with:

```lua
		GW.view.RefreshTotals()
		GW.view.RefreshRows()
	end
end, "bank")

-- The list's order changed (a column click in any window, /swagbag list): the bar's marker follows
-- and a drawn list regroups, held while the mouse is over the items (P5).
SB.On("SB_LIST_SORTED", function()
	if GW.columnsBar then
		GW.columnsBar.Refresh()
	end
	if frame:IsShown() and GW.view.IsOpen() and GW.view.drawn == "list" then
		GW.view.RequestLayout("listsort")
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1410 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (72 files)`, `1410 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Profiles.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/GuildBankWindow.lua \
	spec/guildbank_list_spec.lua \
	spec/profiles_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 8 Task 2: the list view in the guild bank window (a free row per tab, the guild slot's tooltip)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 3: The guild bank regroups an item when its data arrives

The week-5 gap (D7): a guild item whose data the client has not loaded yet is described as pending and waits in New; until now it stayed there for the whole visit. As the alt viewer has done since week 5 (F22), the guild window remembers pending items (`GW.pending`, from every full layout and every live refresh) and, when `ITEM_DATA_LOAD_RESULT` or `GET_ITEM_INFO_RECEIVED` names one while the window is open, lays itself out again `GW.LOADED_DELAY` (0.3 s) after the last one through `GroupView.RequestLayout("loaded")`: held while a button that would move is under the mouse or an item is on the cursor (P5), the search re-applied when it lands. Closing forgets them.

**Files:**
- Modify: `SwagBag/UI/GuildBankWindow.lua`
- Test: `spec/guildbank_spec.lua`

**Interfaces:**
- Consumes: `Items.DescribeLink` (`pending`), `GW.view.RequestLayout`, `SB.Debounce`.
- Produces: `GW.pending`, `GW.LOADED_DELAY`; the guild window's `ITEM_DATA_LOAD_RESULT` / `GET_ITEM_INFO_RECEIVED` listeners (`"bank"`).

- [ ] **Step 1: Write the failing tests**

In `spec/guildbank_spec.lua`, find:

```lua
		assert.equal(reason, GW.view.stats.lastLayoutReason)
	end)
end)
```

and replace it with:

```lua
		assert.equal(reason, GW.view.stats.lastLayoutReason)
	end)

	-- Week 8 (the week-5 gap, as the alt viewer's F22). Mutation: in GuildBankWindow.lua, drop the
	-- SB.On("ITEM_DATA_LOAD_RESULT", onItemLoaded, "bank") registration (the item stays in New).
	it("a guild item whose data has not loaded waits in New and moves to its category once it loads", function()
		A.guild.slots[1][3] = { itemID = Fixtures.UNLOADED }
		openVault()
		answerQueries()
		A.Advance(0.3)
		assert.equal("- New (1)", header("tab1:new").text.text, "pending: New")
		A.items[Fixtures.UNLOADED] = { name = "Chest of Tests", classID = A.ITEM_CLASS.Armor, subclassID = 4,
			equipLoc = "INVTYPE_CHEST", quality = 3, ilvl = 270, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		assert.equal("- New (1)", header("tab1:new").text.text, "debounced: not yet")
		A.Advance(GW.LOADED_DELAY)
		assert.equal("- New (0)", header("tab1:new").text.text)
		assert.equal("- BoE gear (1)", header("tab1:c_boe").text.text)
		assert.equal("loaded", GW.view.stats.lastLayoutReason)
	end)

	-- P5. Mutation: in onItemLoaded's debounced function, call GW.view.Layout instead of GW.view.RequestLayout.
	it("that regroup waits while a guild button that would move is under the mouse, then lands", function()
		A.guild.slots[1][3] = { itemID = Fixtures.UNLOADED }
		openVault()
		answerQueries()
		A.Advance(0.3)
		button(1, 3).mouseOver = true
		A.items[Fixtures.UNLOADED] = { name = "Chest of Tests", classID = A.ITEM_CLASS.Armor, subclassID = 4,
			equipLoc = "INVTYPE_CHEST", quality = 3, ilvl = 270, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("GET_ITEM_INFO_RECEIVED", Fixtures.UNLOADED, true)
		A.Advance(GW.LOADED_DELAY + SB.GroupView.RETRY)
		assert.equal("- New (1)", header("tab1:new").text.text, "held under the mouse")
		button(1, 3).mouseOver = false
		A.Advance(SB.GroupView.RETRY)
		assert.equal("- New (0)", header("tab1:new").text.text, "landed once the mouse left")
	end)

	-- Mutation: in the guild window's OnHide handler, drop the GW.pending reset.
	it("closing the guild bank forgets the items it was waiting on; data for another item lays nothing out", function()
		A.guild.slots[1][3] = { itemID = Fixtures.UNLOADED }
		openVault()
		answerQueries()
		assert.truthy(GW.pending[Fixtures.UNLOADED])
		local reason = GW.view.stats.lastLayoutReason
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", Fixtures.HERB, true)
		A.Advance(GW.LOADED_DELAY)
		assert.equal(reason, GW.view.stats.lastLayoutReason)
		GW.Close()
		assert.same({}, GW.pending)
	end)
end)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1410 passed, 3 failed`. The failures, exactly:

- `spec/guildbank_spec.lua :: GuildBankWindow (check G1) > a guild item whose data has not loaded waits in New and moves to its category once it loads`
- `spec/guildbank_spec.lua :: GuildBankWindow (check G1) > that regroup waits while a guild button that would move is under the mouse, then lands`
- `spec/guildbank_spec.lua :: GuildBankWindow (check G1) > closing the guild bank forgets the items it was waiting on; data for another item lays nothing out`

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "a guild item whose data has not loaded waits in New and moves to its category once it loads": in `SwagBag/UI/GuildBankWindow.lua`, `SB.On("ITEM_DATA_LOAD_RESULT", onItemLoaded, "bank")` → ∅.
- "that regroup waits while a guild button that would move is under the mouse, then lands": in `SwagBag/UI/GuildBankWindow.lua`, `GW.view.RequestLayout("loaded")` → `GW.view.Layout("loaded")`.
- "closing the guild bank forgets the items it was waiting on; data for another item lays nothing out": in `SwagBag/UI/GuildBankWindow.lua`, `GW.pending = {} -- item data arriving while closed lays nothing out` → ∅.

- [ ] **Step 3: Write the code**

In `SwagBag/UI/GuildBankWindow.lua` (edit 1 of 7), find:

```lua
-- visible again; nothing re-shrinks it until the next visit.
```

and replace it with:

```lua
-- visible again; nothing re-shrinks it until the next visit.
-- Items whose data the client has not loaded yet (after a patch the item cache is empty) are
-- described as pending and wait in New. Week 8 (the week-5 gap, as the alt viewer's F22): while the
-- window is open, item data arriving for one of them lays the window out again (debounced,
-- LOADED_DELAY) through GroupView's RequestLayout, held while a button that would move is under the
-- mouse or an item is on the cursor (P5), so they move into their categories. Closing forgets them.
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 2 of 7), find:

```lua
	SNAPSHOT_DELAY = 1,
```

and replace it with:

```lua
	SNAPSHOT_DELAY = 1,
	LOADED_DELAY = 0.3, -- item data arriving for a pending item: regroup this long after the last one
	pending = {}, -- [itemID] = true: an item shown while its data had not loaded (it waits in New)
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 3 of 7), find:

```lua
	end }) or nil

local function describe(bag, slot)
```

and replace it with:

```lua
	end }) or nil

-- A guild slot's record; one whose item data has not loaded yet is remembered (it waits in New).
local function recordOf(info, bag, slot, tab)
	local record = info and SB.Items.DescribeLink(info, bag, slot, tab) or nil
	if record and record.pending then
		GW.pending[record.itemID] = true
	end
	return record
end

local function describe(bag, slot)
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 4 of 7), find:

```lua
	end
	local record = info and SB.Items.DescribeLink(info, bag, slot, tab) or nil
```

and replace it with:

```lua
	end
	local record = recordOf(info, bag, slot, tab)
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 5 of 7), find:

```lua
						local record = b and SB.Items.DescribeLink(b, bag, slot, tab) or nil
```

and replace it with:

```lua
						local record = recordOf(b, bag, slot, tab)
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 6 of 7), find:

```lua
	GW.queue, GW.querying, GW.scaleWarned = {}, nil, false
```

and replace it with:

```lua
	GW.queue, GW.querying, GW.scaleWarned = {}, nil, false
	GW.pending = {} -- item data arriving while closed lays nothing out
```

In `SwagBag/UI/GuildBankWindow.lua` (edit 7 of 7), find:

```lua
end, "bank")

SB.On("GUILDBANK_ITEM_LOCK_CHANGED", function()
```

and replace it with:

```lua
end, "bank")

-- Item data arriving for a pending item (week 8): the tabs as read, laid out again so it leaves New for
-- its category; RequestLayout holds it (retrying every 300 ms) while a button that would move is under
-- the mouse or an item is on the cursor (P5). The search follows through onUpdated.
local function onItemLoaded(_, itemID, success)
	if success == false or not GW.pending[itemID] or not GW.view.IsOpen() then
		return
	end
	GW.pending[itemID] = nil
	SB.Debounce("guild.loaded", GW.LOADED_DELAY, function()
		if frame:IsShown() and GW.view.IsOpen() then
			GW.view.RequestLayout("loaded")
		end
	end, "bank")
end
SB.On("ITEM_DATA_LOAD_RESULT", onItemLoaded, "bank")
SB.On("GET_ITEM_INFO_RECEIVED", onItemLoaded, "bank")

SB.On("GUILDBANK_ITEM_LOCK_CHANGED", function()
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1413 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (72 files)`, `1413 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/UI/GuildBankWindow.lua \
	spec/guildbank_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 8 Task 3: the guild bank regroups a late item when its data arrives (held under the mouse)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 4: Syndicator loaded mid-session: hook its callbacks then, and follow the provider that answers

The week-5 deferred item (D8). `Providers/Syndicator.lua` registered Syndicator's callbacks only at `SB_LOGIN`: if Syndicator loaded later, SwagBag never heard of its updates and the tooltip memo kept SwagBag's own counts until a bag update. Now `P.Hook` registers them once, at login or on `ADDON_LOADED` for Syndicator (`Adapter.IsSyndicatorAddon`), and a late hook announces `SB_ALTDATA_CHANGED` at once (AltData's generation moves; the tooltip memo forgets). An open alt viewer remembers the provider it read from (`OW.source`) and reads its character again when another one answers now, held while the mouse is over its items or an item is on the cursor (P5); Syndicator's ordinary saves still do not redraw it.

**Files:**
- Modify: `SwagBag/Providers/Syndicator.lua`, `SwagBag/Core/Adapter.lua`, `SwagBag/UI/OfflineWindow.lua`
- Test: `spec/syndicator_spec.lua`, `spec/offline_spec.lua`

**Interfaces:**
- Consumes: `Adapter.SyndicatorOnUpdate`, `AltData.Source/Characters`, `SB_ALTDATA_CHANGED`, `OW.Layout`, `OW.scroll`.
- Produces: `SB.SyndicatorProvider.Hook(late) -> bool`, `.hooked`; `A.SYNDICATOR_ADDON`, `A.IsSyndicatorAddon(name)`; `OW.source`.

- [ ] **Step 1: Write the failing tests**

In `spec/offline_spec.lua`, find:

```lua
	end)

	-- Task 9 deferred minor. Mutation: in GroupView.RequestLayout, drop the onUpdated call after commit.
```

and replace it with:

```lua
	end)

	-- Week 8: Syndicator loaded mid-session. Mutations: drop the alt viewer's SB_ALTDATA_CHANGED registration;
	-- in followSource, drop the scroll:IsMouseOver() hold.
	it("an open alt viewer reads its character again when the answering provider switches; held under the mouse",
		function()
			OW.Open("Abby-ArgentDawn")
			assert.equal("Own", OW.source)
			local available = false
			SB.AltData.RegisterProvider({ name = "Syndicator", priority = 10, available = function() return available end,
				characters = function() return { { key = "Abby-ArgentDawn", name = "Abby", realm = "Argent Dawn" } } end,
				container = function(_, kind)
					if kind == "bags" then
						return { containers = { [0] = { size = 16, slots = { [1] = { link = "item:210796", count = 9 } } } } }
					end
				end })
			SB.Emit("SB_ALTDATA_CHANGED", "Syndicator")
			assert.equal("open", OW.view.stats.lastLayoutReason, "the same provider answers: nothing is read again")
			available = true
			OW.scroll.mouseOver = true
			SB.Emit("SB_ALTDATA_CHANGED", "Syndicator")
			assert.equal("open", OW.view.stats.lastLayoutReason, "held while the mouse is over the items")
			OW.scroll.mouseOver = false
			A.Advance(SB.GroupView.RETRY)
			assert.same({ "source", "Syndicator" }, { OW.view.stats.lastLayoutReason, OW.source })
			assert.equal(SB.L.OFFLINE_SOURCE:format("Syndicator"), OW.frame.source.text)
			assert.equal(9, SB.DisplayButtons.Get(0, 1).count)
		end)

	-- Task 9 deferred minor. Mutation: in GroupView.RequestLayout, drop the onUpdated call after commit.
```

In `spec/syndicator_spec.lua`, find:

```lua
		assert.equal(1, n)
```

and replace it with:

```lua
		assert.equal(1, n)
	end)

	-- Week 8 (week-5 deferred). Mutation: delete the provider's SB.On("ADDON_LOADED", ...) registration.
	it("Syndicator loaded after login: its callbacks are registered then, and the switch is announced at once",
		function()
			A.globals.Syndicator = nil
			local n = 0
			SB.On("SB_ALTDATA_CHANGED", function() n = n + 1 end)
			SB.Emit("SB_LOGIN")
			assert.equal("Own", AD.Source())
			A.globals.Syndicator = { API = api, CallbackRegistry = reg }
			SB.eventFrame:Fire("ADDON_LOADED", "SomethingElse")
			assert.is_nil(reg.events.BagCacheUpdate)
			SB.eventFrame:Fire("ADDON_LOADED", "Syndicator")
			assert.truthy(reg.events.BagCacheUpdate and reg.events.Ready)
			assert.equal("Syndicator", AD.Source())
			A.Advance(0.6)
			assert.equal(1, n, "tooltip counts and the alt viewer hear of the switch without waiting")
			reg.events.BagCacheUpdate("x")
			A.Advance(0.6)
			assert.equal(2, n, "and of Syndicator's later updates")
		end)

	-- Mutation: in P.Hook, drop `if P.hooked then return true end` (every ADDON_LOADED would register again).
	it("Syndicator's callbacks are registered once: at login, never again on a later ADDON_LOADED", function()
		local registered = 0
		local register = reg.RegisterCallback
		reg.RegisterCallback = function(...)
			registered = registered + 1
			return register(...)
		end
		SB.Emit("SB_LOGIN")
		local once = registered
		assert.truthy(once > 0)
		SB.eventFrame:Fire("ADDON_LOADED", "Syndicator")
		assert.equal(once, registered)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1414 passed, 2 failed`. The failures, exactly:

- `spec/offline_spec.lua :: Alt viewer: the character picker and the ways in > an open alt viewer reads its character again when the answering provider switches; held under the mouse`
- `spec/syndicator_spec.lua :: Syndicator provider > Syndicator loaded after login: its callbacks are registered then, and the switch is announced at once`

One new test passes already, as it should: "Syndicator's callbacks are registered once: at login, never again on a later ADDON_LOADED" (the old code had no `ADDON_LOADED` listener at all; the test pins Step 3's once-only guard, see its mutation).

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "Syndicator loaded after login: its callbacks are registered then, and the switch is announced at once": in `SwagBag/Providers/Syndicator.lua`, `SB.On("ADDON_LOADED", function(_, name) ⏎ if SB.Adapter.IsSyndicatorAddon(name) then ⏎ P.Hook(true) ⏎ end ⏎ end, "none")` → ∅.
- "Syndicator's callbacks are registered once: at login, never again on a later ADDON_LOADED": in `SwagBag/Providers/Syndicator.lua`, `if P.hooked then ⏎ return true ⏎ end` → ∅.
- "an open alt viewer reads its character again when the answering provider switches; held under the mouse": in `SwagBag/UI/OfflineWindow.lua`, `SB.On("SB_ALTDATA_CHANGED", followSource, "none")` → ∅.
- "an open alt viewer reads its character again when the answering provider switches; held under the mouse": in `SwagBag/UI/OfflineWindow.lua`, `if SB.Adapter.CursorItem() or scroll:IsMouseOver() then` → `if SB.Adapter.CursorItem() then`.

- [ ] **Step 3: Write the code**

In `SwagBag/Core/Adapter.lua`, find:

```lua
	"EquippedCacheUpdate", "AuctionsCacheUpdate", "VoidCacheUpdate", "CharacterDeleted", "GuildDeleted" }

-- Syndicator's API table while Syndicator is loaded, has every function above and says it is
```

and replace it with:

```lua
	"EquippedCacheUpdate", "AuctionsCacheUpdate", "VoidCacheUpdate", "CharacterDeleted", "GuildDeleted" }

-- The folder name Syndicator loads under (ADDON_LOADED's argument): it may load mid-session (week 8).
A.SYNDICATOR_ADDON = "Syndicator"
function A.IsSyndicatorAddon(name)
	return name == A.SYNDICATOR_ADDON
end

-- Syndicator's API table while Syndicator is loaded, has every function above and says it is
```

In `SwagBag/Providers/Syndicator.lua`, find:

```lua
SB.On("SB_LOGIN", function()
	SB.Adapter.SyndicatorOnUpdate(SB.ErrorTrap.Guard("altdata.syndicator", function()
		SB.Debounce("altdata.changed", P.DEBOUNCE, function()
			SB.Emit("SB_ALTDATA_CHANGED", "Syndicator")
		end, "none")
	end, "none"))
end, "none")
```

and replace it with:

```lua
local function announce()
	SB.Debounce("altdata.changed", P.DEBOUNCE, function()
		SB.Emit("SB_ALTDATA_CHANGED", "Syndicator")
	end, "none")
end

-- Register Syndicator's callbacks once (P.hooked): at login, or when Syndicator loads later in the
-- session (week 8: another addon loads it, or it is enabled and loaded without a /reload). A late hook
-- also announces at once: the answering provider may have switched, so the tooltip counts and an open
-- alt viewer follow without waiting for Syndicator's next update.
P.hooked = false
function P.Hook(late)
	if P.hooked then
		return true
	end
	P.hooked = SB.Adapter.SyndicatorOnUpdate(SB.ErrorTrap.Guard("altdata.syndicator", announce, "none")) == true
	if P.hooked and late then
		announce()
	end
	return P.hooked
end

SB.On("SB_LOGIN", function()
	P.Hook(false)
end, "none")

SB.On("ADDON_LOADED", function(_, name)
	if SB.Adapter.IsSyndicatorAddon(name) then
		P.Hook(true)
	end
end, "none")
```

In `SwagBag/UI/OfflineWindow.lua` (edit 1 of 2), find:

```lua
	local _, source = SB.AltData.Characters()
```

and replace it with:

```lua
	local _, source = SB.AltData.Characters()
	OW.source = source -- the provider this layout was read from (a switch re-reads it, week 8)
```

In `SwagBag/UI/OfflineWindow.lua` (edit 2 of 2), find:

```lua
end

SB.On("ITEM_DATA_LOAD_RESULT", onItemLoaded, "none")
```

and replace it with:

```lua
end

-- Week 8: Syndicator became available (or stopped answering) while the window is open: the window reads
-- the same character again from the provider that answers now. Saves alone never re-read it (see
-- OW.Layout). P5: it waits while the mouse is over the items or an item is on the cursor.
local function followSource()
	if not (frame:IsShown() and OW.key) or SB.AltData.Source() == OW.source then
		return
	end
	if SB.Adapter.CursorItem() or scroll:IsMouseOver() then
		SB.Debounce("offline.source", SB.GroupView.RETRY, followSource, "none")
		return
	end
	OW.Layout("source")
end
SB.On("SB_ALTDATA_CHANGED", followSource, "none")

SB.On("ITEM_DATA_LOAD_RESULT", onItemLoaded, "none")
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1416 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (72 files)`, `1416 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Core/Adapter.lua \
	SwagBag/Providers/Syndicator.lua \
	SwagBag/UI/OfflineWindow.lua \
	spec/offline_spec.lua \
	spec/syndicator_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 8 Task 4: Syndicator loaded mid-session (callbacks hooked then; tooltips and the alt viewer follow)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 5: Selling and drawing: gray jewelry, the cached junk-coin check, secret-safe collections

Week-7 minors and the T3 FINAL item (D9–D12). A gray ring, necklace or trinket has no appearance, so "the client cannot say its look" means "cannot collect": it sells as junk again (`Collections.NO_LOOK`); every other gray armor or weapon the client cannot say about still stays. Every "never sold" line now says so (`L.VENDOR_KEEPS`). The overlays' junk coin asks `Vendor.Protected(record, true)`, which reuses the look answer `Uncollected` cached for the link (one client call per link); the sell path never passes it and still asks before every sale. `Collections` reads an item's link and name only through `plain()`: a secret one is no answer (no glow, no star, no error on the `"bags"` draw path).

**Files:**
- Modify: `SwagBag/Engine/Collections.lua`, `SwagBag/Engine/Vendor.lua`, `SwagBag/UI/Overlays.lua`, `SwagBag/Locale/enUS.lua`
- Test: `spec/vendor_spec.lua`, `spec/overlays_spec.lua`, `spec/collections_spec.lua`

**Interfaces:**
- Consumes: `Adapter.IsSecret`, `Adapter.AppearanceKnown`, `Adapter.PetKnown`, the Collections cache (`cached`).
- Produces: `Collections.NO_LOOK`, `Collections.LookUnknown(r, fast)`, `Vendor.Protected(r, fast)`; `L.VENDOR_KEEPS` (new text).

- [ ] **Step 1: Write the failing tests**

In `spec/collections_spec.lua`, find:

```lua
		assert.is_nil(Coll.Learn(saved))
```

and replace it with:

```lua
		assert.is_nil(Coll.Learn(saved))
	end)

	-- Week 8 (week-7 final review, T3: the draw path runs under "bags", so an error there would mean Safe Mode).
	-- A text the client made secret is no answer. Here a secret is a string the Adapter calls secret whose reads
	-- error, as the client's do. Mutations: in teaches(), `local link = plain(r.link)` -> `local link = r.link`;
	-- in knowledge(), `local name = plain(r.name)` -> `local name = r.name`.
	it("a secret link or name is no answer: no glow, no star, never an error", function()
		local link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r"
		local name = "Thalassian Treatise on Alchemy"
		A.Put(0, 13, Fixtures.PET_CAGE, 1, { link = link })
		local cage, treatise = SB.Items.Describe(0, 13), SB.Items.Describe(0, 11)
		A.collected.pets[1387] = false
		A.IsSecret = function(v) return v == link or v == name end
		local match, lower = string.match, string.lower
		rawset(string, "match", function(s, ...)
			if s == link then
				error("attempt to read a secret value")
			end
			return match(s, ...)
		end)
		rawset(string, "lower", function(s)
			if s == name then
				error("attempt to read a secret value")
			end
			return lower(s)
		end)
		local ok, a, b, c = pcall(function()
			return Coll.Learn(cage), Coll.Learn(treatise), Coll.Uncollected(cage)
		end)
		rawset(string, "match", match)
		rawset(string, "lower", lower)
		assert.truthy(ok, tostring(a))
		assert.same({ nil, nil, nil }, { a, b, c })
```

In `spec/overlays_spec.lua`, find:

```lua
	end)

	it("a gear change re-draws the arrows of the open windows, once after the last slot event", function()
```

and replace it with:

```lua
	end)

	-- Week 8. Mutation: in Overlays.Context, call SB.Vendor.Protected(record) without `true`.
	it("the junk coin asks the vendor's rule in its cached form (no collection call per draw)", function()
		local fast
		SB.Vendor = { Protected = function(_, f) fast = f return false end }
		draw(0, 6)
		assert.equal(true, fast)
	end)

	it("a gear change re-draws the arrows of the open windows, once after the last slot event", function()
```

In `spec/vendor_spec.lua`, find:

```lua
	end)

	-- Week 7 (user pick 5). Mutation: Vendor.Protected ignores SB.Locks.
```

and replace it with:

```lua
	end)

	-- Week 8 (week-7 re-review minor): a ring, necklace or trinket has no look at all, so a gray one is junk
	-- again; other gray gear the client cannot say about stays. Mutation: in Collections.LookUnknown, drop
	-- `or Coll.NO_LOOK[r.equipLoc or ""]`.
	it("gray rings, necklaces and trinkets have no look: sold as junk; a gray robe the client cannot say about stays",
		function()
			for i, loc in ipairs({ "INVTYPE_FINGER", "INVTYPE_NECK", "INVTYPE_TRINKET" }) do
				A.AddItem(400300 + i, { name = "Dull Bauble " .. i, classID = A.ITEM_CLASS.Armor, subclassID = 0,
					equipLoc = loc, quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 30 })
				A.Put(0, 6 + i, 400300 + i, 1)
			end
			A.Put(0, 10, GRAY, 1)
			A.collected.defaultLook = nil -- the client has no source for any of them
			SB.Inventory.ScanAll()
			visit()
			assert.same({ 6, 7, 8, 9 }, sold())
			assert.truthy(SB.L.VENDOR_KEEPS:find("cannot tell", 1, true), "what is kept says so")
		end)

	-- Week 8 (week-7 re-review minor: Protected on the draw path). Mutation: in Collections.LookUnknown, drop
	-- the `if fast then ... end` branch (every draw of a gray piece would ask the client again).
	it("a draw asks the client about a gray piece's look once per link; every sale check asks again", function()
		A.Put(0, 7, GRAY, 1, { link = "item:400200::a" })
		A.collected.looks["item:400200::a"] = "unknown"
		SB.Inventory.ScanAll()
		local r = SB.Items.Describe(0, 7)
		local before = A.collectionCalls
		for _ = 1, 3 do
			assert.truthy(SB.Vendor.Protected(r, true))
		end
		assert.equal(before + 1, A.collectionCalls, "three draws, one question")
		assert.truthy(SB.Vendor.Protected(r))
		assert.truthy(SB.Vendor.Protected(r))
		assert.equal(before + 3, A.collectionCalls, "the sell path never trusts a cached unknown")
	end)

	-- Week 7 (user pick 5). Mutation: Vendor.Protected ignores SB.Locks.
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1416 passed, 4 failed`. The failures, exactly:

- `spec/collections_spec.lua :: Collections (week 7) > a secret link or name is no answer: no glow, no star, never an error`
- `spec/overlays_spec.lua :: Overlays (spec F9) > the junk coin asks the vendor's rule in its cached form (no collection call per draw)`
- `spec/vendor_spec.lua :: Vendor (week 7) > gray rings, necklaces and trinkets have no look: sold as junk; a gray robe the client cannot say about stays`
- `spec/vendor_spec.lua :: Vendor (week 7) > a draw asks the client about a gray piece's look once per link; every sale check asks again`

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "gray rings, necklaces and trinkets have no look: sold as junk; a gray robe the client cannot say about stays": in `SwagBag/Engine/Collections.lua`, `or not isGear(r) or Coll.NO_LOOK[r.equipLoc or ""] then` → `or not isGear(r) then`.
- "a draw asks the client about a gray piece's look once per link; every sale check asks again": in `SwagBag/Engine/Collections.lua`, `if fast then -- the draw path: the answer Uncollected cached for this link (asked once per link) ⏎ return cached("look:" .. link, function() ⏎ return SB.Adapter.AppearanceKnown(link) ⏎ end) == nil ⏎ end` → ∅.
- "the junk coin asks the vendor's rule in its cached form (no collection call per draw)": in `SwagBag/UI/Overlays.lua`, `SB.Vendor.Protected(record, true) == true` → `SB.Vendor.Protected(record) == true`.
- "a secret link or name is no answer: no glow, no star, never an error": in `SwagBag/Engine/Collections.lua`, `local link = plain(r.link) ⏎ local species` → `local link = r.link ⏎ local species`.
- "a secret link or name is no answer: no glow, no star, never an error": in `SwagBag/Engine/Collections.lua`, `local name = plain(r.name)` → `local name = r.name`.

- [ ] **Step 3: Write the code**

In `SwagBag/Engine/Collections.lua` (edit 1 of 6), find:

```lua
--   Collections.LookUnknown(record) -> bool   gray gear whose look the client cannot say (the sell path:
--     such a piece is protected; the answer is never cached, so the next sale asks again)
```

and replace it with:

```lua
--   Collections.LookUnknown(record, cached) -> bool   gray gear whose look the client cannot say (the sell
--     path: such a piece is protected; the answer is never cached there, so the next sale asks again).
--     Rings, necklaces and trinkets have no look at all: "cannot collect", never unknown (week 8). cached =
--     true (the overlays' junk coin, week 8): the answer Uncollected already cached for the link, so a
--     draw costs a table lookup, never a collection call
```

In `SwagBag/Engine/Collections.lua` (edit 2 of 6), find:

```lua
end

local function knowledge(r)
```

and replace it with:

```lua
end

-- Equipment slots with no appearance (week 8): a gray ring, necklace or trinket has no look to collect.
Coll.NO_LOOK = { INVTYPE_FINGER = true, INVTYPE_NECK = true, INVTYPE_TRINKET = true }

-- A text the draw path may use: a string the client did not make secret (it may in M+ and raids;
-- spec 9); a secret is no answer, never an error (week 8, the week-7 final review's T3 item).
local function plain(v)
	return type(v) == "string" and not SB.Adapter.IsSecret(v) and v or nil
end

local function knowledge(r)
```

In `SwagBag/Engine/Collections.lua` (edit 3 of 6), find:

```lua
	if r.name == nil or isGear(r) then
		return false
	end
	local name = r.name:lower()
```

and replace it with:

```lua
	local name = plain(r.name)
	if name == nil or isGear(r) then
		return false
	end
	name = name:lower()
```

In `SwagBag/Engine/Collections.lua` (edit 4 of 6), find:

```lua
		local species = type(r.link) == "string" and r.link:match("battlepet:(%d+)")
		return "pet", cached("pet:" .. (species and ("s" .. species) or id), function()
			return A.PetKnown(id, r.link)
```

and replace it with:

```lua
		local link = plain(r.link)
		local species = link and link:match("battlepet:(%d+)")
		return "pet", cached("pet:" .. (species and ("s" .. species) or id), function()
			return A.PetKnown(id, link)
```

In `SwagBag/Engine/Collections.lua` (edit 5 of 6), find:

```lua
		local link = r.link
		if type(link) == "string" and cached("look:" .. link, function()
```

and replace it with:

```lua
		local link = plain(r.link)
		if link and cached("look:" .. link, function()
```

In `SwagBag/Engine/Collections.lua` (edit 6 of 6), find:

```lua
function Coll.LookUnknown(r)
	if not r or r.offline or r.pending or r.quality ~= 0 or not isGear(r) then
		return false
	end
	return type(r.link) ~= "string" or SB.Adapter.AppearanceKnown(r.link) == nil
```

and replace it with:

```lua
function Coll.LookUnknown(r, fast)
	if not r or r.offline or r.pending or r.quality ~= 0 or not isGear(r) or Coll.NO_LOOK[r.equipLoc or ""] then
		return false
	end
	local link = plain(r.link)
	if not link then
		return true
	end
	if fast then -- the draw path: the answer Uncollected cached for this link (asked once per link)
		return cached("look:" .. link, function()
			return SB.Adapter.AppearanceKnown(link)
		end) == nil
	end
	return SB.Adapter.AppearanceKnown(link) == nil
```

In `SwagBag/Engine/Vendor.lua` (edit 1 of 2), find:

```lua
--   Vendor.Protected(record) -> bool   never sold by SwagBag (ruling R19): in an equipment set, locked by the
```

and replace it with:

```lua
--   Vendor.Protected(record, fast) -> bool   never sold by SwagBag (ruling R19): in an equipment set, locked by the
```

In `SwagBag/Engine/Vendor.lua` (edit 2 of 2), find:

```lua
function V.Protected(r)
	return r.inEquipmentSet == true or (SB.Locks ~= nil and SB.Locks.Has(r.itemID))
		or (SB.Collections ~= nil and (SB.Collections.Learn(r) ~= nil or SB.Collections.Uncollected(r) ~= nil
			or SB.Collections.LookUnknown(r)))
```

and replace it with:

```lua
-- fast = true: a draw (the overlays' junk coin, week 8) may use cached look answers; the sell path never
-- passes it, so an unknown look is asked again right before each sale.
function V.Protected(r, fast)
	return r.inEquipmentSet == true or (SB.Locks ~= nil and SB.Locks.Has(r.itemID))
		or (SB.Collections ~= nil and (SB.Collections.Learn(r) ~= nil or SB.Collections.Uncollected(r) ~= nil
			or SB.Collections.LookUnknown(r, fast)))
```

In `SwagBag/Locale/enUS.lua`, find:

```lua
L.VENDOR_KEEPS = "locked items, equipment-set items, gear whose look you have not collected, items to open or learn,"
	.. " and gray BoE items worth more at auction"
```

and replace it with:

```lua
L.VENDOR_KEEPS = "locked items, equipment-set items, gear whose look you have not collected (or the game cannot tell"
	.. " yet), items to open or learn, and gray BoE items worth more at auction"
```

In `SwagBag/UI/Overlays.lua`, find:

```lua
				return SB.Vendor ~= nil and SB.Vendor.Protected(record) == true
```

and replace it with:

```lua
				return SB.Vendor ~= nil and SB.Vendor.Protected(record, true) == true -- cached looks (week 8)
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1420 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (72 files)`, `1420 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Collections.lua \
	SwagBag/Engine/Vendor.lua \
	SwagBag/Locale/enUS.lua \
	SwagBag/UI/Overlays.lua \
	spec/collections_spec.lua \
	spec/overlays_spec.lua \
	spec/vendor_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 8 Task 5: gray jewelry sells again, the junk coin's check is cached, collections are secret-safe

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 6: One lock reads as one; share strings: priorities are lowered, never refused; a narrower |cn rule

Week-7 re-review minors (D13–D15). `/swagbag lock clear`, `Unlock all` and `/swagbag lock undo` say "1 lock" in the singular. In a share string, a category priority of 90 or more (yours, or an edit of a built-in) is imported at 89, just below Junk, and the preview names it (`L.PROFILE_PREVIEW_LOWERED`), so a string you exported always imports. A query is refused for `|cn` only when it opens a real named colour (`|cnNAME:`), so `herb|cname` is a query again. The week-7 hostile-categories test loses its three priority refusals (they are the new test's) and gains one named-colour line.

**Files:**
- Modify: `SwagBag/Engine/Locks.lua`, `SwagBag/Engine/Profiles.lua`, `SwagBag/Locale/enUS.lua`
- Test: `spec/locks_spec.lua`, `spec/profiles_spec.lua`, `spec/vendor_spec.lua`

**Interfaces:**
- Consumes: `Locks.AskClear/Undo`, `Profiles.Parse/Preview/Export`, `Categories.Name`.
- Produces: `L.LOCK_CLEAR_ASK_ONE`, `L.LOCK_CLEARED_ONE`, `L.LOCK_UNDONE_ONE`, `L.PROFILE_PREVIEW_LOWERED`; parsed data's `lowered = { id }`.

- [ ] **Step 1: Write the failing tests**

In `spec/locks_spec.lua`, find:

```lua
	end)

	-- Final review fix 2: a lock made between the two presses starts the question over.
```

and replace it with:

```lua
	end)

	-- Week 8 (week-7 re-review minor: "all 1 locks"). Mutation: in the lock command, drop
	-- `count == 1 and L.LOCK_CLEAR_ASK_ONE or `.
	it("one lock reads as one: the question, the answer and the undo", function()
		Locks.Toggle(Fixtures.FLASK)
		SB.Slash.Dispatch("lock clear")
		SB.Slash.Dispatch("lock clear")
		SB.Slash.Dispatch("lock undo")
		assert.same({ SB.L.LOCK_CLEAR_ASK_ONE, "Unlocked the 1 locked item.", "Lock restored: 1." }, A.Lines())
		assert.truthy(Locks.Has(Fixtures.FLASK))
	end)

	-- Final review fix 2: a lock made between the two presses starts the question over.
```

In `spec/profiles_spec.lua` (edit 1 of 2), find:

```lua
		-- Final review fix 9. Mutation: drop the `field == "priority" and value >= Pr.MAX_PRIORITY` branch.
		refused("cu.u_x.name=sOK;cu.u_x.priority=n90")
		refused("cu.u_x.name=sOK;cu.u_x.priority=n100")
		refused("ce.c_other.priority=n95")
		assert.equal(89, assert(Pr.Parse("SWAGBAG:1:cu.u_x.name=sOK;cu.u_x.priority=n89")).users.u_x.priority)
		-- Final review fix 8. Mutation: drop `or text:find("|c[nN]")` from escapeCode.
		refused("cu.u_x.query=sx%7CcnIQ4%3Aok%7Cr")
		refused("cu.u_x.query=sx%7CcNIQ4%3Aok%7Cr")
```

and replace it with:

```lua
		-- Final review fix 8, narrowed in week 8: a named colour |cnNAME: is refused.
		refused("cu.u_x.query=sx%7CcnIQ4%3Aok%7Cr")
		refused("cu.u_x.query=sx%7CcNIQ4%3Aok%7Cr")
		refused("cu.u_x.query=sx%7CcnGREEN_FONT_COLOR%3Aok%7Cr")
```

In `spec/profiles_spec.lua` (edit 2 of 2), find:

```lua
		assert.same({ nil, "notours" }, { Pr.Parse("SWAGBAG:0:s.bags.columns=n14") })
```

and replace it with:

```lua
		assert.same({ nil, "notours" }, { Pr.Parse("SWAGBAG:0:s.bags.columns=n14") })
	end)

	-- Week 8 (week-7 re-review minor: your own priority of 90 or more was refused). Mutation: in Pr.Parse, the
	-- priority branch returns nil, "type", key again (a string you exported would be refused whole).
	it("a category priority of 90 or more comes in just below Junk, named in the preview; never refused", function()
		local data = assert(Pr.Parse("SWAGBAG:1:cu.u_x.name=sMine;cu.u_x.priority=n95;ce.c_gear.priority=n100"))
		assert.same({ 89, 89, { "c_gear", "u_x" } }, { data.users.u_x.priority, data.edits.c_gear.priority, data.lowered })
		assert.equal(89, assert(Pr.Parse("SWAGBAG:1:cu.u_x.name=sOK;cu.u_x.priority=n89")).users.u_x.priority)
		assert.equal(0, #assert(Pr.Parse("SWAGBAG:1:cu.u_x.name=sOK;cu.u_x.priority=n89")).lowered)
		local lines = Pr.Preview(data)
		assert.equal(SB.L.PROFILE_PREVIEW_LOWERED:format("Gear, Mine"), lines[2])
		SB.Config.db.categories = { u_y = { name = "Herbs first", query = "herb", priority = 99 } }
		local own = assert(Pr.Parse(Pr.Export(true)), "your own export is never refused")
		assert.equal(89, own.users.u_y.priority)
	end)

	-- Week 8 (week-7 re-review minor). Mutation: in escapeCode, `"|c[nN][%u_][%u%d_]*:"` -> `"|c[nN]"` (the
	-- week-7 rule: "herb|cname" was refused).
	it("an OR right before a word starting with n is a query, not a colour code", function()
		for _, q in ipairs({ "herb%7Ccname", "ore%7CcNuts", "cloth%7Ccn" }) do
			local data = assert(Pr.Parse("SWAGBAG:1:cu.u_x.query=s" .. q), q)
			assert.truthy(SB.Query.Compile(data.users.u_x.query).fn, q)
		end
```

In `spec/vendor_spec.lua`, find:

```lua
		assert.same({ true, SB.L.LOCK_CLEAR_ASK:format(1) }, { SB.Locks.Has(Fixtures.FLASK), SW.lastStatus })
		Fake.Fire(unlock, "OnClick")
		assert.same({ false, SB.L.LOCK_CLEARED:format(1) }, { SB.Locks.Has(Fixtures.FLASK), SW.lastStatus })
```

and replace it with:

```lua
		assert.same({ true, SB.L.LOCK_CLEAR_ASK_ONE }, { SB.Locks.Has(Fixtures.FLASK), SW.lastStatus })
		Fake.Fire(unlock, "OnClick")
		assert.same({ false, SB.L.LOCK_CLEARED_ONE }, { SB.Locks.Has(Fixtures.FLASK), SW.lastStatus })
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1419 passed, 4 failed`. The failures, exactly:

- `spec/locks_spec.lua :: Locks (week 7) > one lock reads as one: the question, the answer and the undo`
- `spec/profiles_spec.lua :: Profiles (week 7) > a category priority of 90 or more comes in just below Junk, named in the preview; never refused`
- `spec/profiles_spec.lua :: Profiles (week 7) > an OR right before a word starting with n is a query, not a colour code`
- `spec/vendor_spec.lua :: Settings: vendor page (week 7) > Unlock all asks first; the second press within 10 seconds unlocks; each press answers once`

One edited test passes already, as it should: "refuses hostile or malformed categories whole" (its |cn lines are refused by the old, broader rule too; its priority lines moved to the new test).

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "one lock reads as one: the question, the answer and the undo": in `SwagBag/Engine/Locks.lua`, `return count == 1 and L.LOCK_CLEAR_ASK_ONE or L.LOCK_CLEAR_ASK:format(count)` → `return L.LOCK_CLEAR_ASK:format(count)`.
- "a category priority of 90 or more comes in just below Junk, named in the preview; never refused": in `SwagBag/Engine/Profiles.lua`, `into[id][field] = Pr.MAX_PRIORITY - 1 ⏎ data.lowered[#data.lowered + 1] = id` → `return nil, "type", key`.
- "an OR right before a word starting with n is a query, not a colour code": in `SwagBag/Engine/Profiles.lua`, `text:find("|c[nN][%u_][%u%d_]*:")` → `text:find("|c[nN]")`.

- [ ] **Step 3: Write the code**

In `SwagBag/Engine/Locks.lua` (edit 1 of 3), find:

```lua
		if n == "ask" then
			return L.LOCK_CLEAR_ASK:format(count)
```

and replace it with:

```lua
		if n == "ask" then -- one lock reads as one (week 8)
			return count == 1 and L.LOCK_CLEAR_ASK_ONE or L.LOCK_CLEAR_ASK:format(count)
```

In `SwagBag/Engine/Locks.lua` (edit 2 of 3), find:

```lua
		return L.LOCK_CLEARED:format(n)
```

and replace it with:

```lua
		return n == 1 and L.LOCK_CLEARED_ONE or L.LOCK_CLEARED:format(n)
```

In `SwagBag/Engine/Locks.lua` (edit 3 of 3), find:

```lua
		return L.LOCK_UNDONE:format(n)
```

and replace it with:

```lua
		return n == 1 and L.LOCK_UNDONE_ONE or L.LOCK_UNDONE:format(n)
```

In `SwagBag/Engine/Profiles.lua` (edit 1 of 6), find:

```lua
-- A real chat escape opener in a query: |T |H |A |K, |c with eight hex digits, or |cn / |cN (a named colour,
-- |cnNAME:). Every other "|" is the OR operator ("herb|cloth").
local function escapeCode(text)
	return text:find("|[THAK]") ~= nil or text:find("|c%x%x%x%x%x%x%x%x") ~= nil or text:find("|c[nN]") ~= nil
```

and replace it with:

```lua
-- A real chat escape opener in a query: |T |H |A |K, |c with eight hex digits, or a named colour: |cn (or |cN)
-- followed by an upper-case name and ":" (|cnIQ4:, |cnGREEN_FONT_COLOR:; week 8, the narrowest rule that
-- still catches it). Every other "|" is the OR operator ("herb|cloth", "herb|cname").
local function escapeCode(text)
	return text:find("|[THAK]") ~= nil or text:find("|c%x%x%x%x%x%x%x%x") ~= nil
		or text:find("|c[nN][%u_][%u%d_]*:") ~= nil
```

In `SwagBag/Engine/Profiles.lua` (edit 2 of 6), find:

```lua
--          skipped = { path }, ignored = { path } (NEVER settings) }
```

and replace it with:

```lua
--          skipped = { path }, ignored = { path } (NEVER settings), lowered = { id } (a priority of 90 or
--          more, imported as MAX_PRIORITY - 1, week 8) }
```

In `SwagBag/Engine/Profiles.lua` (edit 3 of 6), find:

```lua
	local data = { settings = {}, users = {}, edits = {}, skipped = {}, ignored = {} }
```

and replace it with:

```lua
	local data = { settings = {}, users = {}, edits = {}, skipped = {}, ignored = {}, lowered = {} }
```

In `SwagBag/Engine/Profiles.lua` (edit 4 of 6), find:

```lua
				return nil, "type", key -- an imported category never outranks Junk, Sets, Keystone or Reagents
```

and replace it with:

```lua
				-- an imported category never outranks Junk, Sets, Keystone or Reagents (week 7), but a string the
				-- user exported is never refused for it either (week 8): it comes in just below them, and the
				-- preview names it
				into[id][field] = Pr.MAX_PRIORITY - 1
				data.lowered[#data.lowered + 1] = id
```

In `SwagBag/Engine/Profiles.lua` (edit 5 of 6), find:

```lua
	table.sort(data.ignored)
```

and replace it with:

```lua
	table.sort(data.ignored)
	table.sort(data.lowered)
```

In `SwagBag/Engine/Profiles.lua` (edit 6 of 6), find:

```lua
		lines[#lines + 1] = L.PROFILE_PREVIEW_CATEGORIES:format(nu, ne, data.order and L.REPORT_YES or L.REPORT_NO)
```

and replace it with:

```lua
		lines[#lines + 1] = L.PROFILE_PREVIEW_CATEGORIES:format(nu, ne, data.order and L.REPORT_YES or L.REPORT_NO)
	end
	if #data.lowered > 0 then
		local names = {}
		for i, id in ipairs(data.lowered) do
			local def = data.users[id]
			names[i] = (def and def.name) or (SB.Categories and SB.Categories.Name(id)) or id
		end
		lines[#lines + 1] = L.PROFILE_PREVIEW_LOWERED:format(table.concat(names, ", "))
```

In `SwagBag/Locale/enUS.lua` (edit 1 of 2), find:

```lua
L.LOCK_CLEAR_ASK = "This removes all %d locks. Press Unlock all again (or type /swagbag lock clear again) within 10 seconds"
	.. " to confirm."
L.LOCK_UNDONE = "Locks restored: %d."
```

and replace it with:

```lua
L.LOCK_CLEARED_ONE = "Unlocked the 1 locked item."
L.LOCK_CLEAR_ASK = "This removes all %d locks. Press Unlock all again (or type /swagbag lock clear again) within 10 seconds"
	.. " to confirm."
L.LOCK_CLEAR_ASK_ONE = "This removes your 1 lock. Press Unlock all again (or type /swagbag lock clear again) within 10"
	.. " seconds to confirm."
L.LOCK_UNDONE = "Locks restored: %d."
L.LOCK_UNDONE_ONE = "Lock restored: 1."
```

In `SwagBag/Locale/enUS.lua` (edit 2 of 2), find:

```lua
L.PROFILE_PREVIEW_CATEGORIES = "Categories: %d of yours, %d changed built-ins, order %s"
```

and replace it with:

```lua
L.PROFILE_PREVIEW_CATEGORIES = "Categories: %d of yours, %d changed built-ins, order %s"
L.PROFILE_PREVIEW_LOWERED = "Ranked just below Junk (an imported category never outranks Junk, Equipment sets, Keystone &"
	.. " Crests or Reagents): %s"
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1423 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (72 files)`, `1423 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/Engine/Locks.lua \
	SwagBag/Engine/Profiles.lua \
	SwagBag/Locale/enUS.lua \
	spec/locks_spec.lua \
	spec/profiles_spec.lua \
	spec/vendor_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 8 Task 6: singular lock lines; imported priorities lowered, never refused; a narrower |cn rule

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---

### Task 7: "Your top X %" follows the bank's contents

Week-7 Task 7 deferred (D16). The gold glow's "your top X %" line was worked out 0.1 s after the bank opened and again on the bags' layout, so a bank whose contents arrived later (or changed during the visit) kept a line computed without them. The bank window now announces `SB_BANK_CHANGED` after each full layout, after a held layout lands, and after any live change it repaints; the overlays work the line out again (0.1 s after the last one) when the mode is "top" (a fixed amount does not depend on contents). `Ov.IsWorth` reads a stack's value once.

**Files:**
- Modify: `SwagBag/UI/BankWindow.lua`, `SwagBag/UI/Overlays.lua`
- Test: `spec/bankwindow_groups_spec.lua`

**Interfaces:**
- Consumes: `Ov.RefreshWorth`, `Ov.WORTH_DELAY`, `SB.AtBank`, `prices.worth`.
- Produces: the event `SB_BANK_CHANGED` (bank window → overlays).

- [ ] **Step 1: Write the failing tests**

In `spec/bankwindow_groups_spec.lua`, find:

```lua
		assert.equal(stats, BW.view.pos, "no layout ran, no redraw: the position table is the same")
```

and replace it with:

```lua
		assert.equal(stats, BW.view.pos, "no layout ran, no redraw: the position table is the same")
	end)

	-- Week 8 (week-7 deferred: the top-% line was worked out before the bank's contents arrived). Mutations:
	-- delete the SB.Emit("SB_BANK_CHANGED") in the bank's BAG_UPDATE handler; or delete the Overlays'
	-- SB_BANK_CHANGED listener.
	it("'your top X %' is worked out again when the bank's contents change during the visit", function()
		SB.Config.Set("prices.worth", "top")
		SB.Config.Set("prices.worthTop", 10) -- three stacks: the most valuable one
		A.items[Fixtures.HERB].sellPrice = 1000 -- 20: 20000
		A.items[Fixtures.ORE].sellPrice = 100 -- 10: 1000
		A.items[Fixtures.HEALING_POTION].sellPrice = 100 -- 5: 500
		A.items[Fixtures.FLASK].sellPrice = 900000
		openBank()
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(20000, SB.Overlays.worthMin, "the herbs")
		A.Put(6, 2, Fixtures.HERB, 40) -- a stack grows: nothing moves
		bankUpdate(6)
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(40000, SB.Overlays.worthMin, "the bigger herb stack")
		A.Put(6, 5, Fixtures.FLASK, 1) -- a deposit
		bankUpdate(6)
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(900000, SB.Overlays.worthMin, "the flask")
		assert.truthy(SB.Overlays.regions[B.Get(6, 5)].glow.shown)
```


- [ ] **Step 2: Run the tests and see them fail**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1423 passed, 1 failed`. The failures, exactly:

- `spec/bankwindow_groups_spec.lua :: BankWindow contents > 'your top X %' is worked out again when the bank's contents change during the visit`

Critical tests and the mutation that must make each fail (each was applied to this task's finished code; the named test failed):

- "'your top X %' is worked out again when the bank's contents change during the visit": in `SwagBag/UI/BankWindow.lua`, `searchBox.Apply() ⏎ SB.Emit("SB_BANK_CHANGED") ⏎ end ⏎ end, "bank"))` → `searchBox.Apply() ⏎ end ⏎ end, "bank"))`.
- "'your top X %' is worked out again when the bank's contents change during the visit": in `SwagBag/UI/Overlays.lua`, `SB.On("SB_BANK_CHANGED", function() ⏎ if SB.AtBank() and SB.Config.Get("prices.worth") == "top" then ⏎ worthSoon() ⏎ end ⏎ end, "none")` → ∅.

- [ ] **Step 3: Write the code**

In `SwagBag/UI/BankWindow.lua` (edit 1 of 4), find:

```lua
		searchBox.Apply()
	end,
```

and replace it with:

```lua
		searchBox.Apply()
		SB.Emit("SB_BANK_CHANGED") -- a held layout landed: what the bank shows changed
	end,
```

In `SwagBag/UI/BankWindow.lua` (edit 2 of 4), find:

```lua
-- Full layout of both groups, then the search dimming.
```

and replace it with:

```lua
-- Full layout of both groups, then the search dimming. SB_BANK_CHANGED (week 8): the bank's contents as
-- drawn changed (a layout, or items that arrived, left or changed while open); the worth glow's "your top
-- X %" line follows it (UI/Overlays.lua).
```

In `SwagBag/UI/BankWindow.lua` (edit 3 of 4), find:

```lua
	searchBox.Apply()
end
```

and replace it with:

```lua
	searchBox.Apply()
	SB.Emit("SB_BANK_CHANGED")
end
```

In `SwagBag/UI/BankWindow.lua` (edit 4 of 4), find:

```lua
		searchBox.Apply()
	end
```

and replace it with:

```lua
		searchBox.Apply()
		SB.Emit("SB_BANK_CHANGED")
	end
```

In `SwagBag/UI/Overlays.lua` (edit 1 of 3), find:

```lua
-- (and again when prices, the setting or the bags' layout change during the visit), never per button.
```

and replace it with:

```lua
-- (and again when prices, the setting or the bags' layout change during the visit, and for "top" when the
-- bank's contents change, week 8), never per button.
```

In `SwagBag/UI/Overlays.lua` (edit 2 of 3), find:

```lua
	return Ov.worthMin ~= nil and stackValue(record) >= Ov.worthMin and stackValue(record) > 0
```

and replace it with:

```lua
	if Ov.worthMin == nil then
		return false
	end
	local value = stackValue(record)
	return value > 0 and value >= Ov.worthMin
```

In `SwagBag/UI/Overlays.lua` (edit 3 of 3), find:

```lua
SB.On("SB_BAGS_LAYOUT", function()
	if SB.AtBank() then
		worthSoon()
```

and replace it with:

```lua
SB.On("SB_BAGS_LAYOUT", function()
	if SB.AtBank() then
		worthSoon()
	end
end, "none")
-- Week 8 (week-7 deferred): the bank's contents arrive or change while it is open. Only "your top X %"
-- depends on them (a fixed amount does not), so only that line is worked out again, once after the burst.
SB.On("SB_BANK_CHANGED", function()
	if SB.AtBank() and SB.Config.Get("prices.worth") == "top" then
		worthSoon()
```


- [ ] **Step 4: Run the tests and see them pass**

```bash
luajit spec/runner.lua spec/*_spec.lua
```

Expected: `1424 passed, 0 failed`.

- [ ] **Step 5: Run the local CI**

```bash
scripts/check.sh
```

Expected: `TOC OK (72 files)`, `1424 passed, 0 failed`, and the last line `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add SwagBag/UI/BankWindow.lua \
	SwagBag/UI/Overlays.lua \
	spec/bankwindow_groups_spec.lua
git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit -m "Week 8 Task 7: the top-percent worth line follows the bank's contents

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx"
```

---


## In-game sessions

Four short sessions: BL1, GL1, SY1 and VP1. All four run on the **final merged build** (every task done, reviewed and fixed), as week 6's ruling P1 set; the "checks Task N" in each heading only says which task's work it checks. Then the week-8 exit check. They never block the build: findings come back as fixes.

Before every session:
- Claude installs the build first. The game currently runs an older copy, and the login line must say `v0.8.0`.
- If anything shows a red error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After the session, reply "<session> done" and the numbers of any steps that didn't match.

Chat lines start with `SwagBag: `. Names and amounts like `<its name>` or `1g 2s 3c` are examples: yours will differ.

### Session BL1: the bank's list view and the gold glow's top 10% (checks Tasks 1 and 7; about 15 minutes)

You need: a banker; a few items in your bank and in your bags; a stack worth something (herbs, ore, a BoE).

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.8.0 loaded. Type /swagbag help for commands.`
3. Move the mouse far from where the bank window opens. Right-click a banker. Expected: SwagBag's bank opens as before (categories), and the view button in its title row reads `List`.
4. Click `List`. Expected: the title shows `SwagBag bank - list view` for a moment, the button now reads `Grid`, and a bar `Name  Count  ilvl  Value v` sits under the `Deposits go to ...` line. In both groups (`Character bank` and `Warband bank`) each section lists one row per item: a small icon on the left, then the name in its quality colour, the count, the item level (gear only) and the stack's value. Each group's empty slots are one row like `12 free - drop items here`.
5. Rest the mouse on the **name text** of a bank row (not the icon). Expected: the item's tooltip, ending with `Right-click the icon on the left to take this item, or drag the icon.`
6. Click that name text. Expected: the title shows `Right-click the icon on the left to take the item.`; nothing moves and nothing is taken.
7. Right-click the **small icon** of that row. Expected: the item goes to your bags; a dimmed small icon stays where it was and its row reads `(moved or used - regroups when you close the bank)`; no other row moves. Move the mouse off the bank.
8. Right-click the icon of the row just **below** another item's row (any row with an item). Expected: exactly the item named on that row is taken, never the one above or below it. Move the mouse off the bank.
9. In your bags, right-click any item. Expected: it appears as a row in the `New` section of the bank group that says `deposits go here`; no other bank row moves.
10. Click `Name` on the bar. Move the mouse off the bank. Expected: the title shows `Sorted by Name, A to Z`, the bar reads `Name ^`, and each section lists its items A to Z. (If your bags are open in their list view, they follow.)
11. Click `Value` on the bar. Expected: `Sorted by Value, highest first`, the bar reads `Value v`, and the most valuable stacks come first in each section.
12. Type `/swagbag worth top 10`. Expected: `SwagBag: Gold glow at the bank: your most valuable 10% of items.`, and within a second the most valuable stacks in the bank and the bags glow gold.
13. Right-click a valuable stack in your bags (it goes to the bank). Expected: within a second the gold glows are worked out again with it: if it is among your most valuable tenth it glows gold in the bank.
14. Type `/swagbag worth 100`. Expected: `SwagBag: Gold glow at the bank: items worth 100g or more a stack.`
15. Click `Grid` in the bank's title row. Expected: `SwagBag bank - grid view`, full-size icons in slot order, no bar; the button now reads `Categories`. Click `Categories`. Expected: `SwagBag bank - category view`; the button reads `List`.
16. Click `List` again. Walk away until the bank closes, then right-click the banker again. Expected: the bank opens in the list straight away, without a noticeable stutter. (If it stutters, type `/swagbag report` and paste the line `Last bank layout: ... ms` to Claude.)
17. (Only if chat showed `SwagBag: The list view could not size the bank's item buttons, so the bank shows the category view.` at any point.) Expected: the title showed `SwagBag bank - category view`, not the list title, and the bank drew categories; this should not happen, so type `/swagbag report` and paste it to Claude.
18. Walk away until the bank closes.

### Session GL1: the guild bank's list view, and late items (checks Tasks 2 and 3; about 10 minutes)

You need: a guild bank you can open, with at least one tab you may deposit into and withdraw from; any item in your bags. Step 10 is for patch day (2026-10-13) or later.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.8.0 loaded. Type /swagbag help for commands.`
3. Right-click the guild vault. Expected: SwagBag's guild bank opens as before (categories); its view button reads `List`.
4. Click `List`. Expected: the title shows `SwagBag guild bank - list view`; each tab is a group whose sections list one row per item, and each tab's empty slots are one row like `40 free - drop items here`; a bar `Name  Count  ilvl  Value v` sits under the deposit line.
5. Rest the mouse on the name text of an item row. Expected: that guild item's tooltip.
6. Click the name text. Expected: the title shows `Right-click the icon on the left to take the item (from the tab Blizzard has selected).`; nothing is taken.
7. Left-click an item in your bags to pick it up, then left-click the small icon of the `... free - drop items here` row of the tab that says `deposits go here`. Expected: the item goes into that tab and shows as a row in its `New`; nothing else moves. Move the mouse off the windows.
8. Right-click the icon of an item row in that same tab. Expected: the item comes to your bags; its row reads `(moved - regroups when you close the guild bank)`; nothing else moves.
9. Click `Grid`. Expected: `SwagBag guild bank - grid view` and full-size icons; click `Categories`. Expected: `SwagBag guild bank - category view`. Click `List` to keep the list, or leave it as you like.
10. (Patch day, 2026-10-13, or any first visit after the game's item cache was emptied.) Open the guild bank and watch the `New` sections without moving the mouse over the window. Expected: items that first show in `New` move to their own sections within a second or so, without a click. Then rest the mouse over the guild bank's item area (where the items are, not the title) while this happens: a late item waits in `New` while the mouse rests there, and moves to its own section once the mouse leaves the item area.
11. Walk away until the guild bank closes.

### Session SY1: Syndicator still answers (checks Task 4; about 5 minutes)

You need: Syndicator installed and enabled, and an item you also have on another character.

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.8.0 loaded. Type /swagbag help for commands.`
3. Press **B** and rest the mouse on the item you also have on another character. Expected: the tooltip shows SwagBag's count lines, including the other character. Move the mouse off.
4. Type `/swagbag settings alts`. Expected: the Alt data page says `Alt data comes from Syndicator: ...` (with your numbers). Close the settings window with its X.
5. Type `/swagbag alts`. Expected: the alt viewer opens and says `Saved data from Syndicator. Nothing here can be used or moved.` Close it with its X.

(Syndicator loading in the middle of a session cannot be staged by hand: it normally loads before SwagBag. The unit tests cover that path; this session checks that nothing else changed.)

### Session VP1: gray jewelry, one lock, and a share string (checks Tasks 5 and 6; about 10 minutes)

You need: a vendor; a gray ring, necklace or trinket if you have one (steps 3–4); any item you can lock; some herbs in your bags (step 12).

0. Claude installs the build first.
1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.8.0 loaded. Type /swagbag help for commands.`
3. (Only with a gray ring, necklace or trinket.) Press **B**. Expected: it shows the yellow junk coin like other gray junk.
4. (Only with one.) Move the mouse far from the bags. Right-click a vendor. Expected: it is sold with your other gray junk, and one line `SwagBag: Sold N junk items for ...`.
5. With no gray item left in your bags (sell them by hand first if needed), type `/swagbag sell junk` at the vendor. Expected: `SwagBag: No junk to sell: no gray items a vendor pays for (never sold: locked items, equipment-set items, gear whose look you have not collected (or the game cannot tell yet), items to open or learn, and gray BoE items worth more at auction).`
6. Walk away from the vendor. Type `/swagbag lock list`. Expected: `SwagBag: No item is locked.` (If items are listed, unlock them all first with `/swagbag lock clear` typed twice, then continue.)
7. Pick up any item in your bags (left-click) and drop it on the small `Lock` button right of the search box. Expected: `SwagBag: Locked: <its name>. SwagBag never sells it, and it shows a small lock.`
8. Type `/swagbag lock clear`. Expected: `SwagBag: This removes your 1 lock. Press Unlock all again (or type /swagbag lock clear again) within 10 seconds to confirm.`
9. Within 10 seconds, type `/swagbag lock clear` again. Expected: `SwagBag: Unlocked the 1 locked item.`
10. Type `/swagbag lock undo`. Expected: `SwagBag: Lock restored: 1.`
11. Type `/swagbag profile import`. Expected: `SwagBag: Paste a share string into the box, then press Preview.` and the `Import a SwagBag share string` box.
12. Click into the box and type exactly `SWAGBAG:1:cu.u_week8.name=sWeek8;cu.u_week8.query=sherb%7Ccname;cu.u_week8.priority=n95` (it has no spaces). Click `Preview`. Expected: the box shows `Import would change:`, then `Categories: 1 of yours, 0 changed built-ins, order no`, then `Ranked just below Junk (an imported category never outranks Junk, Equipment sets, Keystone & Crests or Reagents): Week8`.
13. Click `Import`. Expected: the box closes and chat shows `SwagBag: Imported 1 changes. Your previous settings are kept: /swagbag profile undo brings them back.` Press **B**: a section `Week8` holds your herbs.
14. Type `/swagbag profile undo`. Expected: `SwagBag: Your settings are back as they were before the last load, import or reset.`, and the `Week8` section is gone (the herbs are back in their usual section).
15. Unlock the item from step 7: drop it on `Lock` again. Expected: `SwagBag: Unlocked: <its name>.`

## Week 8 exit check

1. Claude installs the week-8 build, at the end of Task 7 (after review and fixes), and you fully restart the game.
2. Play normally for a day, with keys, a vendor, a bank visit and (if you can) a guild bank visit, in whichever view you like. Expected: no red errors; nothing moves under your mouse; deposits and withdrawals land where you click.
3. Type `/swagbag report` and paste it to Claude. Expected:
   - `Safe Mode: bags=off bank=off`;
   - `Failed checks: none`;
   - the `Last bank layout: ... ms` line (for TF1's bank-speed work).



## Spec updates at week end

Recorded in the week-8 ledger and applied to `docs/superpowers/specs/2026-09-30-swagbag-design.md` at week end (this plan commits only the plan file):
- **§2.2 v1.3 (list view):** delivered for the bank (F2) and the guild bank (F16) windows too: the same rows, columns and one shared order (`bags.list`), a view button that cycles categories → list → grid in every window; the guild bank's list shows each tab's empty slots as one free row. Add ACs from Tasks 1–2's tests (F2/F16).
- **§4.1 / §4.2:** the list scales the bank's secure buttons (`SetScale` only, legal in combat) and the guild bank's own buttons; the F6 / W5-1 rule (a list row never shows a full-size button; fallback to categories, said once per opening, recorded under `"none"`) applies to every window; in a list a row under the mouse holds its button (rule 5).
- **§4.3 / F16:** a guild bank item whose data arrives late moves from New to its category by a held full layout (as the alt viewer's F22), at the cost of that visit's placeholders (D7).
- **§3.3:** Syndicator's callbacks are registered when it becomes available, at login or later in the session; a late hook announces `SB_ALTDATA_CHANGED`; the alt viewer re-reads its character only when the answering provider changes (its "shows what was saved when it opened" rule otherwise stands).
- **AC17.2:** gray rings, necklaces and trinkets have no appearance and sell as junk (unless another protection applies); every other gray gear whose look the client cannot tell stays; the draw path (the junk coin) may use the cached look answer, the sell path never does. `L.VENDOR_KEEPS` text.
- **§9 (secret values):** the collections' draw path treats a secret link or name as no answer (no glow, no star, no error).
- **F20 (share strings, week 7):** an imported category priority of 90 or more is imported at 89 and named in the preview (never refused); the named-colour rule refuses `|cn`/`|cN` only before an upper-case name and `:`.
- **AC10.4:** "your top X %" is worked out again when the bank's contents change during a visit.
- **§10.5:** `/swagbag lock clear|undo` answers in the singular for one lock (wording only).
- **§12.2:** the bank-speed part 2 is scheduled after session TF1's numbers come back.

## Spec coverage (week-8 scope → task)

| Requirement (from the brief) | Task |
|---|---|
| 1. List view in the bank and guild bank windows: same columns, sort and settings model; the bank's two groups and the guild tabs; secure buttons never reparented or created in combat (SetScale, F6 self-check and fallback); deposit, withdraw and right-click unchanged | T1 (D1–D3, D5, D6; GroupView, the bank), T2 (D4, D6; the guild bank) |
| 2. Guild bank pending-item regroup, obeying P5 | T3 (D7) |
| 3. Syndicator loaded mid-session: AltData switches; tooltip counts and the alt viewer follow without /reload | T4 (D8) |
| 4a. Gray jewelry (no appearance) is "cannot collect": auto-sold again, only for those equip slots | T5 (D9) |
| 4b. `L.VENDOR_KEEPS` mentions gear whose look is unknown | T5 (D10) |
| 4c. Singular "1 lock" strings; LOCK_CLEAR_ASK plural | T6 (D13) |
| 4d. Profiles: own priority >= 90 must round-trip (decided: lowered to 89 on import, named in the preview); `|cn` refuses only a named colour (`herb|cname` is a query) | T6 (D14, D15) |
| 4e. Vendor.Protected on the draw path: cached | T5 (D11) |
| 4f. Collections secret-link guard on the draw path (T3 FINAL); Report.SeasonText already guarded | T5 (D12); "Carry-overs" (checked) |
| 4g. The top-10% worth line recomputes when the bank's contents arrive | T7 (D16) |
| 4h. Week-6 minors: verify and triage | "Carry-overs" |
| 5. Bank-speed part 2 not planned: waits on TF1 | D18 |
| Version 0.8.0 in Task 1 | T1 |

## How this plan was checked (while writing it)

- Every task was first built on a scratch clone at `/tmp/sb8` (outside the repo), one commit per task, test-first: each task's tests were run against the previous task's code (red) and then against its own (green). Every block in this file was then generated from those commits' diffs by a script: each find block is grown line by line until it occurs exactly once in the file as it is after the earlier edits, and starts and ends on a non-blank line; the script re-applied every block to the old file and compared the result with the commit's file.
- **Replay.** A fresh clone of `ab9d5a2` (`/tmp/sb8b`) was driven by a script that reads this file: for each task it applies the Step 1 blocks, runs the suite, applies the Step 3 blocks, runs the suite and `scripts/check.sh`, then commits. Every find block occurred exactly once when applied; every Step 2 count and FAIL list (name by name), every Step 4 total, every Step 5 `ALL CHECKS PASSED` and TOC count, and every Step 6 `git add` list (equal to the files the task changed, and to its Files section) above is that script's output. Final total: **1424 passed, 0 failed**.
- **Mutations.** Every mutation listed under a Step 2 (37 in all) was applied, one at a time, to its own task's replayed commit, and the whole suite run: every one made its named test fail.
- Greps on the final tree:
  - no `C_`/`Enum.` outside `SwagBag/Core/Adapter.lua`, and no bare `C_*` name either (check.sh); the Syndicator folder name lives in the Adapter (`A.SYNDICATOR_ADDON`);
  - none of the forbidden tokens; no `SetParent`/`SetID` on a slot button in any new code (the bank list test logs every call on the 16 bank buttons in combat);
  - no `OnUpdate`; no `Config` call at load (the bank and guild load-order tests stay green with `UI/ListRows.lua` loaded);
  - no `%s` given a boolean (format51 runs on every spec).

## Self-review

1. **Scope coverage.** Every item of the brief maps to a task or a named decision in "Spec coverage", in the brief's priority order (the list view first, the bank before the guild bank; the guild bank's late items; Syndicator; the polish; TF1 waits). Each open question has a decision row: the list's model and settings (D1, D2, D5), the secure buttons and F6 (D3), the guild's empty slots (D4), row texts (D6), late items (D7), Syndicator (D8), jewelry (D9), the keeps line (D10), the cached check (D11), secrets (D12), singular locks (D13), the priority cap (D14, decided and justified), the `|cn` rule (D15), the top-% line (D16).
2. **Placeholder scan.** No "TBD", "TODO", "similar to", or test-free step. Every code step is a complete block (the replay applies them as written). The in-game expectations quote Locale strings verbatim; where a line holds the player's own numbers or names the step says so.
3. **Type and name consistency.** These names are the same in every task that uses them: GroupView cfg `rows`, `onListFailed`, `family`, `freeTile(view)`; `v.drawn`, `v.RowWidth`, `v.RefreshRows`, `v.SetDimmed`, `GV.LIST_*` (T1 → T2); `ListRows.New(parent, window, flash, opts)`, `ListRows.ColumnBar`, `ListRows.SortedText`, `ListRows.COLUMN_NAMES` (T1 → T2); `SB_LIST_SORTED` (T1: Sort, bags, bank → T2: guild); `GW.pending`, `GW.LOADED_DELAY` (T3); `SyndicatorProvider.Hook`, `A.IsSyndicatorAddon`, `OW.source` (T4); `Collections.NO_LOOK`, `LookUnknown(r, fast)`, `Vendor.Protected(r, fast)` (T5); `L.LOCK_*_ONE`, `L.PROFILE_PREVIEW_LOWERED`, `data.lowered` (T6); `SB_BANK_CHANGED` (T7). The Locale keys quoted in BL1, GL1, SY1 and VP1 were checked against the blocks.
4. **Review Focus.** Each of the seven lines names its pinning tests, and each of those tests is in its owning task's Step 1 (or, for the narrowed week-7 test, edited there).
5. **Global Constraints.** No `C_`/`Enum.` or another addon's global outside the Adapter. Secure buttons are only scaled and placed (pinned by Task 1's strict-log test); rows and bars are plain frames. Every new script and listener runs under `ErrorTrap.Guard`/`SB.On` with the labels in P6. Every user-visible string is in `enUS.lua`. No new setting; `"list"` is a new allowed word for two existing ones; the schema stays 2. No `OnUpdate`.
6. **Known limits, stated in the plan.** The late-item regroup clears that visit's placeholders (D7). Syndicator's late load cannot be staged in game (G6). A share string's priority of 90 or more is lowered, not kept (D14). The list's hit area and speed for a full bank are in-game checks (G2, G9). The week-6 bank-speed part 2 waits on TF1 (D18).
