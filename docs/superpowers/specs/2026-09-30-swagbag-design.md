# SwagBag — Design Specification

*Date: 2026-09-30. Status: **definitive**. Supersedes `docs/plans/2026-09-30-swagbag-plan-draft.md`. Inputs: `research/bag-addon-landscape.md`, the draft plan, `docs/plans/2026-09-30-swagbag-plan-critique.md`, `spikes/README.md` and the in-game spike results (WoW 12.1.0.69933, 0 Lua errors, 0 blocked actions across runs). This document is the input to the implementation plan. Where it conflicts with the draft plan, this document wins.*

**Target:** World of Warcraft Retail 12.1.x (Midnight). TOC `## Interface: 120100, 120105`. Retail only. English only at launch.

**License:** All rights reserved. No code is copied from any other addon (GPL or otherwise). Ideas and public API facts are fair game; code is clean-room.

**Who builds it:** Claude writes and maintains all code via Claude Code, including patch-day fixes. The user (an M+ player and beginning gold-maker, currently a Baganator user, no coding background) tests in-game a few evenings per week, reports via `/swagbag report`, and makes product decisions.

---

## 1. Overview

### 1.1 One line

**SwagBag is a bag addon that sets itself up, shows you only what matters for what you are doing right now, tells you what your stuff is worth, and never breaks your bags.**

### 1.2 Goals

1. **Zero-effort setup.** A first-run wizard turns "what do you play?" into categories, focus modes, layout and gold settings. The default result is good enough that most users never open the settings again.
2. **Focus modes (headline feature).** The bag automatically collapses every section except the ones relevant to the current activity — M+ shows consumables and the keystone; a fishing trip shows fish and lures; the AH shows what's worth selling.
3. **Gold awareness without an AH scanner.** Auctionator prices (when installed) on items and per-category totals; "worth money" highlight at the bank.
4. **M+ first-class.** Consumables on top, keystone with level and dungeon, ilvl and upgrade-track overlays, crests in the bag, a low-consumables warning on dungeon entry and portal use.
5. **Never breaks your bags.** Any Lua error or failed feature check flips the addon to Blizzard bags instantly (proven to work even in combat) and prints one line pointing to `/swagbag report`.
6. **No hard dependencies.** Syndicator and Auctionator are optional providers behind internal interfaces. The addon is fully functional without either.
7. **Layout you can trust.** Nothing moves under the cursor while a window is open.

### 1.3 Non-goals (explicit)

- No auction-house or mailbox scanning of our own. Prices come from Auctionator, TSM or the vendor (a user choice; F10).
- No guild bank *money* management UI (deposit/withdraw gold stays in Blizzard's frame) and no guild bank tab purchase/permission editing. One accepted exception (week 7, ruling R22): the optional "Guild bank first" repair (F17) spends guild money through Blizzard's own repair call; it is not a money UI, it is off by default (the default is your own gold), only the user chooses it, and it is never exported or imported in a share string.
- No "send to alt" feature (scrapped in the grilling).
- No sandboxed Lua rule language. The visual rule builder plus the query grammar is the ceiling.
- No importers for other addons' SavedVariables in v1.0. Paste-string import of Syndicator/Baganator-syntax category strings is sufficient because the grammar is compatible.
- No Classic, MoP Classic or WoW: Forever flavors. Retail only, by decision.
- No replacement of Blizzard's bank tab purchase/settings UI (`PurchaseBankTab` stays untainted). We re-host Blizzard's real tab buttons and never emulate them.
- No writing of any Blizzard bank state, ever (`BankFrame:SetTab`, `BankPanel.bankType`, `CloseBankFrame()` from our OnHide). See §5. The one accepted exception is the include-reagents option of the "Deposit warbound" button (AC2.8): it is a user-facing game option, not bank state.
- No tooltip parsing for core fields (bind state, ilvl, quality, type). Tooltip data is used only where no API exists and is always `issecretvalue()`-guarded.

### 1.4 Design principles (binding on every feature)

| # | Principle | What it means in practice |
|---|---|---|
| P1 | **Opinionated default + easy-to-find alternative** | Every setting ships with a chosen default. The alternative is one click away in the same place, never buried. Options are phrased as choices ("Peek / Keep open"), not as abstract toggles. |
| P2 | **Every command and button gives feedback** | Every slash command and every button prints or shows a confirmation or an explanation of why it did nothing. Silence is a bug. It answers exactly once: a run that takes time (a sale, a send) answers when it ends; an automatic action with nothing to do says nothing. |
| P3 | **Ease of setup over power** | When power and simplicity conflict, simplicity wins in v1.x. Power features go behind an "Advanced" disclosure or into a later tier. |
| P4 | **No hard dependencies** | Syndicator (alt data), Auctionator and TradeSkillMaster (prices; TSM read only through its public `TSM_API`, week 9) are detected at load and used through internal provider interfaces; Masque (skins) gets each item button through `AddButton` only. Absence degrades a feature, never errors. Other bag addons are detected and named (one login line, the report), never disabled (week 9). |
| P5 | **Layout never moves under the cursor** | Placeholders hold spots; new items go to a "New" section and stay there until hovered (AC3.3); reflow happens on close. |
| P6 | **Fail to Blizzard, loudly once** | One Lua error in our refresh path → Safe Mode → one chat line → `/swagbag report`. |
| P7 | **Real APIs over tooltip parsing** | `C_Item.IsBound`, `C_Item.GetCurrentItemLevel`, `C_Item.IsBoundToAccountUntilEquip`, `C_TooltipInfo` with secret-value guards only as a last resort. |
| P8 | **All UI strings live in one table** | `Locale/enUS.lua` defines `L["..."]`. No literal UI strings elsewhere. Keyword matching is registered English + (later) localized; nothing depends on `string.lower` of non-ASCII. |

### 1.5 Personas

| Persona | Needs | v1.0 serves with |
|---|---|---|
| **The user** (M+ player, learning gold-making, ex-Baganator, "too complicated to set up") | Works out of the box, M+ mode, know what to sell, never breaks a key | Wizard, M+ focus mode, consumables warning, Auctionator totals, Safe Mode |
| **Rae the raider** | Zero taint, zero idle CPU, ilvl/upgrade overlays, never break queues | Proven secure pool, combat-safe layout, overlays, Raid mode |
| **Goldie the gold-maker** | What's worth money, per-category value, alt data | Auctionator per-category totals, AH/Vendor/Bank modes; worth-money highlight (v1.1) |
| **Cas the casual** | Zero config, movable, junk sell | Wizard "casual" preset, Blizzard-like look, Vendor mode |
| **Alta the altoholic** | Everything everywhere | Offline snapshots of bags/bank/warband for every alt; Syndicator provider (v1.2) |
| **Pat the power user** | Rules, priorities, many categories | Full query grammar, visual rule builder, priorities, paste-string import |

Pat is served, not targeted. Every Pat feature is behind "Advanced".

---

## 2. Feature specification by release tier

### 2.1 v1.0 — public release

Each feature has acceptance criteria (AC). An AC is a statement the user can verify in-game or that a busted test asserts.

#### F1. Bag window (backpack + bags 1–4 + reagent bag)
- AC1.1 Pressing the bag key (B / ToggleAllBags / ToggleBackpack) opens SwagBag's bag window and Blizzard's bag frames do not appear.
- AC1.2 Right-clicking a usable item uses it, in and out of combat, with no "Interface action failed because of an AddOn" message (verified by the spike for the per-bag-parent construction).
- AC1.3 Left-click, shift-click (split/link), drag, and drop behave exactly as in Blizzard bags (they are Blizzard's own handlers).
- AC1.4 The reagent bag's items are mixed into categories by default; the "Show reagent bag separately" option puts them in their own section instead.
- AC1.5 The window is movable, scalable (50–200 %), remembers its position, and closes on ESC without closing the bank interaction.
- AC1.6 The footer's gold entry is a gold-coin icon (the size of the currency icons) and the whole gold with thousands separators, no silver or copper; its tooltip, "Gold on this character", gives the full amount with coins (D22).

#### F2. Bank window (character bank + warband bank, stacked)
- AC2.1 Visiting a banker opens one SwagBag bank window with two stacked groups of sections: "Character bank" and "Warband bank". Blizzard's bank frame is invisible but still open (tiny mode).
- AC2.2 Blizzard's real tab buttons (`BankFrame.TabSystem`) appear on SwagBag's window. Clicking them switches Blizzard's active bank type.
- AC2.3 Right-click on a bag item deposits into whichever bank type is Blizzard's active tab. The section group that will receive deposits is highlighted (header tint + "deposits go here").
- AC2.4 ESC or walking away closes the bank interaction; subsequent item use (e.g. Hearthstone) works.
- AC2.5 SwagBag never calls `BankFrame:SetTab`, writes `BankPanel.bankType`, or calls `C_Bank.CloseBankFrame()` from any OnHide. (A luacheck rule and a grep in CI enforce this.)
- AC2.6 If the first in-dev check "deposit lands correctly while Blizzard's bank is in tiny mode" fails, the fallback "Blizzard bank visible beside ours" setting becomes the default without code changes elsewhere.
- AC2.7 Sort buttons for bags, character bank and warband bank call `C_Container.SortBags()` / `C_Container.SortBank(bankType)` and reflow the view afterwards. Week 9: with `sort.mode = "stacks"` ("Partial stacks first"; Blizzard's sort stays the default) they run SwagBag's stacker instead (§5.5).
- AC2.8 A "Deposit warbound" button on SwagBag's bank window runs the game's own warband-bank deposit, with the warband bank type chosen on the user's click (it never sets Blizzard's selected bank type), refuses in combat, while the warband bank is locked, and when a refund could be lost, and answers once each time (P2). A "With reagents" box beside it mirrors and writes Blizzard's own include-reagents option (`bankAutoDepositReagents`), the one game setting SwagBag writes (accepted, week 6: the user asked for the button); it re-reads the option when the button is used. Both stay on SwagBag's window in tiny and beside mode. See §5.2.

#### F3. Category view (default) and grid view
- AC3.1 A header toggle switches between category sections and a flat grid without /reload, in and out of combat.
- AC3.2 Every section header is collapsible; collapse state persists per section per window.
- AC3.3 A "New" section at the top holds items that came into the bags and were not hovered yet, and items not yet loaded. Final week-9 rule (the user's): an item that comes into the bags (loot, a purchase, mail, a trade, a bank withdrawal, crafting: a slot gains a stack and the bags hold more of that item than before), whether the window is open or closed and in combat too, stays in New, at the top, in every focus mode and both focus styles (a mode never collapses New), until its button (or its list row) is hovered; after that it joins its real category on the next open (or explicit Reflow), never while the window is open. A move or split inside the bags and Blizzard's sort add nothing to New; an unseen item moved inside the bags stays unseen. An item whose ID was secret when it came (an instance) counts from when it becomes readable; a secret link or name never keeps an item out of New. Hotfix 0.11.1 (the user's report: `New (133)` after a fresh client start): what is in the bags when the player gets control is never new. From the login scan, and from every loading screen (PLAYER_ENTERING_WORLD: login, /reload, zoning into or out of an instance), the bags *settle*: until 3 s pass with no bag change (at most 15 s after the world loads), slots that read empty and fill again add nothing to New, and an unseen item that reads empty and comes back stays unseen (the `new` search keyword likewise). Outside a settle, one bag update that would bring in 20 stacks or more, and more than half the stacks then in the bags, is the client's late login data and adds nothing (a mailbox Take-All or a vendor spree never fills half the bags). A slot whose item ID reads secret is not empty: it keeps its last known item, so reading again with that item adds nothing; what came while it was secret arrives when it reads, even during a settle and even if the slot reads empty for a moment in the loading screen, unless the slot was already secret at the login scan or a settle (then it holds what was there before). A bag whose size first reads holds nothing new (a bag can be put on only when empty), and a bag size that reads 0 while the bag holds items keeps its items. An item that truly arrives within the settle (rare: a loading screen just ended) is not put in New. Session only (a login or /reload starts empty); the bags and the reagent bag only, never the banks. SwagBag keeps its own "unseen" set: Blizzard's new-item flag is cleared when the bags close (W4-15), so it cannot carry an item to the next open. New grows past its reserved rows at a full layout; arrivals while open keep the "+N more below" cap (§4.3).
- AC3.4 While a window is open, no item button changes position except into "New" or "Free". A removed item leaves a dimmed placeholder. (Busted test on the layout engine plus the spike's `noWrongItemInSection` invariant re-run as an in-game check.)
- AC3.5 Empty slots render in a "Free" section of real slot buttons, which is a valid drop target.
- AC3.6 The grid view is the physical slot order of the bags (bag 0, 1–4, 5; then bank tabs) in a single scrolling grid.
- AC3.7 Scroll offset is clamped when content shrinks (bank close), so the view is never scrolled past the end.

#### F4. Default categories and the categorizer
- AC4.1 First run ships ~18 built-in categories (see §7.6) that place every item in a sensible section; "Other" is the fallback.
- AC4.2 Categories are `{query, priority, itemList}`; manual item lists win over rules; priority decides which rule wins; display order is separate from priority.
- AC4.3 Dragging an item onto a section header adds it to that section's manual list, with a confirmation ("Added Healing Potion to Consumables").
- AC4.4 Items whose data is not yet loaded go to "New" and are re-categorized when loaded; they move only on the next open or Reflow, after they were hovered, like every arrival (AC3.3).

#### F5. Search
- AC5.1 A search box per window accepts the query grammar (§7). Non-matching items are fully dimmed (icon, border, overlays, glows). Matching ones are untouched.
- AC5.2 Search never moves items. It dims.
- AC5.3 Parse errors show inline under the box with the offending position underlined; the previous valid search stays applied.
- AC5.4 A keystroke after the 150 ms debounce re-evaluates 200 slots in ≤ 4 ms.

#### F6. Visual rule builder (category editor)
- AC6.1 A category can be created/edited with rows of `[keyword] [operator] [value]`, grouped in AND/OR blocks with a NOT toggle. "Advanced" reveals the text; both round-trip losslessly. Week 11 (v0.11.0): the rows are two levels (groups of rows; All of these / Any of these; Not on a row and on a group; with several groups, all or any); a rule nested deeper, a double Not, more than 40 rows or 10 groups opens as text only with the reason; "losslessly" means the same tree (`Query.Pretty`'s spelling) both ways, and a rule not changed in the rows is saved as typed; the keyword lists are the §7.3 families; a name typed in a row is always quoted. Advanced (the rule as text) takes the whole query language and is saved as typed (the rows never limit a power user). Text typed but not read is read first by any click on the rows, and never lost.
- AC6.2 Saving runs `Validate` and says its warnings for a changed rule (§7.9). A rule with an error is never dropped. A category whose rule works keeps it in use, and on (§7.5 #3), and the broken text is kept as its draft: said at Save, shown in the list as `(your change has an error: the rule before it is used)`, opened in the editor with its error and "Back to the working rule"; a fix replaces the rule. A category with no rule that works (a new one) is saved with `enabled = false`, said at Save, shown as `(off: its rule has an error)` in the list and in the report's Broken list (§7.10). Fixed and saved, it is on again, also when the editor sends no On/Off (Reagents). A Save never regroups the open bags: they use the change at their next full layout (an open or Reflow), never moving an item under the mouse (§4.2 #5), and the Save answer says so. Save refuses while a row the user changed is not finished, naming it.
- AC6.3 Paste-string import accepts a Syndicator/Baganator-syntax string and previews what it matches before saving. Week 11: the paste mapping (the week-11 plan's table: gold amounts, `!!`, an open `(` translated; unknown `#keywords`, name words, `upgrade`/`bop`, keywords that others start with, item levels noted; quotes, chat codes, unreadable syntax and over 500 characters refused whole, positioned in the pasted text, and a paste its gold amounts grow past 500 refused with its own message; never a partial save); the result is previewed (count and Show matches) and made a new user category "From Baganator" (the next free "From Baganator 2", ...; `source = "import"`, priority 88).
- AC6.4 (week 11) Settings > Categories (after the everyday settings pages; nothing new in the bag window or the quick setup) lists every category in display order with its priority, Edit, Up and Down, and New category; a new category is On, priority 88, first; names have 1–30 characters, no `|`, unique (also against New and Free and every built-in's own name, any case, even after that built-in is renamed); rules at most 500 characters (one constant, `Query.MAX_QUERY`), no chat code, and the text boxes take more than their limit so a longer text is refused with its length, never cut; priorities 1–89 in steps, none for the four pinned built-ins (Junk, Equipment sets, Keystone & Crests, Reagents); Delete (user categories only) asks once more and takes the id out of the order, every focus mode (account and this character) and this character's collapsed sections, without re-stacking the open bags, and the id is never given again; Reset to default asks once more, removes a built-in's whole diff, dragged items included, and goes back to the list; Show matches' search is taken out of the bags when the settings window closes, if it is still theirs; every SwagBag text box lets the keyboard go when combat starts.

#### F7. First-run wizard and tour
- AC7.1 On first login with SwagBag, a 4-step wizard runs: playstyle (M+ / Raid / Gold / Casual / Collector, multi-select) → preset categories and focus modes → layout (columns, scale, look) → gold settings (Auctionator detected or not; threshold). Week 12 (v0.12.0): the wizard is the quick setup screen grown in place (one window; the done flag is `settings.setup.done`, account-wide). Four steps, one screen each (What do you play? / What that turns on / How your bags look / Gold), Back, Next and Skip on every step, Finish on the last; nothing is written before Finish. A first run starts from the defaults, a re-run from the settings as they are and last time's styles (`setup.styles`). Step 2 lists every built-in focus mode, the picked styles' switches and category moves; step 3 slots per row, size, and the looks whose addon is loaded; step 4 the price source found (or vendor prices), the gold glow (Off / 50g / 100g / 500g / 1000g, or the top % set) and selling junk. Combat makes it step aside and come back as it was (inside an instance, when the player leaves it). A user who finished the quick setup is never shown it by itself. Deferred to v1.1: seeding the consumables watch list per role (AC11.2).
- AC7.2 "Skip" applies the defaults and says so. Week 12: Skip is on every step and writes only `setup.done`; on a re-run it says the current settings are kept.
- AC7.3 `/swagbag tour` runs an interactive tour of the bag window (headers, collapse, peek, search, modes, sort, Safe Mode) at any time. Week 12: seven notes (headers, collapse and drag, focus modes and peek, search, the mode title and Pause, Sort, Safe Mode), each next to its part with a gold frame (beside the window when the part is not drawn); Back, Next, End tour, Esc; it opens the bags, refuses in combat or Safe Mode, ends with one line when the bags close or combat starts, and never moves, sorts or lays out anything. Finish offers it once ("Show me around" / "No thanks"; any other close says how to get it later): after each Finish, not after Skip, not in combat, not in Safe Mode and not inside an instance. `/swagbag tour` or `/swagbag setup` while the offer shows answers it.
- AC7.4 `/swagbag setup` re-runs the wizard.

#### F8. Focus modes (6 core)
- AC8.1 Built-in modes M+, Raid, Delves, Gathering, Fishing, and AH/Vendor/Bank are ON by default and switch automatically.
- AC8.2 Entering a Mythic+ dungeon moves the M+ mode's sections to the top, right under New, within one `BAG_UPDATE_DELAYED` or `PLAYER_ENTERING_WORLD` cycle, and leaves every section open or collapsed as the user set it (the default `front` style, D15). With the `collapse` style it collapses every section except the M+ mode's set instead. Leaving restores the previous order or state.
- AC8.3 With the `collapse` style, clicking a collapsed header in a mode peeks it (expanded until the window closes or mode changes). A small pin on the peeked header, or the option "Keep open until mode changes", makes it sticky. Default is peek. In the `front` style a header click is the user's own collapse or expand, saved as such; there is no peek or pin.
- AC8.4 Overlapping modes expand the union of their sections (default). The option "Strict priority" uses combat > activity > location; week 12: a mode of the user's own that they switched on by hand (AC8.7) comes first of all (manual > combat > activity > location).
- AC8.5 The current mode is shown in the window title ("SwagBag — M+") and a click on it opens the mode's section list for editing.
- AC8.6 Gathering detection uses a spell-ID allowlist; opening a chest or archaeology never triggers it.
- AC8.7 Users can create a custom mode: name, trigger (manual, or any built-in signal), and section set. Week 12: up to 10 modes of your own, named 1 to 24 characters (not a built-in mode's name or id, unique in any case, no chat codes); the trigger is "only when I switch it on" or one of in a Mythic+ key, a dungeon, a raid, a delve, a battleground or arena, fishing, gathering, at a vendor, the auction house, the bank; sections with the built-ins' editor. A manual mode is on for the session only (`/swagbag mode on <name>`, `off [<name>]`, or its line in Settings > Focus modes; its switch is session state, not a setting), needs no "Switch by themselves", and Pause stops it. Merge as the built-ins; strict priority manual > combat > activity > location. Delete asks once more and its id is never given again; "This character only" covers them. Share strings never carry them (F20).

#### F9. Core overlays
- AC9.1 ilvl, upgrade track and an **upgrade arrow** on gear; keystone level and dungeon on the keystone; stack count; junk coin; BoE / Warbound badge. All from `C_Item` / `C_Container` APIs; no tooltip parsing.
- AC9.2 Each overlay has an on/off switch; the wizard's playstyle sets the defaults. Week 12: a picked style's settings are written as explicit values at Finish (so they hold even when they equal the default); Gold's glow only when it is off.
- AC9.4 (week 7) Three more marks, each with its switch: a soft green glow on an item to open or learn (`overlays.learn`: caches, toys, mounts, pets, decor not yet owned, profession knowledge items); a small padlock on an item the user locked (`overlays.lock`); a purple `*` on gear whose look the account has not collected, and on a toy, mount or pet while the green glow is not drawn (`overlays.uncollected`). The `*` sits at the right edge between the upgrade arrow and the stack count, and the padlock at the left edge between the item-level and track texts: no mark covers another. The junk coin is never drawn on an item SwagBag will not sell (locked, in an equipment set, to open or learn, an uncollected or unknown look, worth more at auction).
- AC9.3 Upgrade arrow: shown on equippable gear the character can use whose item level (`C_Item.GetCurrentItemLevel`) is higher than the lowest-ilvl item currently equipped in the matching slot(s) (both rings/trinkets compared; two-hand vs main+off-hand compared by summed ilvl). If Pawn is installed, an optional "Use Pawn" setting replaces the ilvl rule with `PawnIsContainerItemAnUpgrade`. Re-evaluated on `PLAYER_EQUIPMENT_CHANGED`.

#### F10. Price sources (Auctionator, TSM, vendor) (prices + per-category totals)
- AC10.1 With Auctionator loaded, each section header shows the category's total AH value ("Trade Goods — 1,240g"); items show AH value on hover and optionally as an overlay.
- AC10.2 Without an auction price source loaded (or with Vendor chosen), totals use the vendor price and the header says "vendor".
- AC10.5 (week 9) Providers: Auctionator (priority 10), TSM (5: TradeSkillMaster's public addon API, price strings DBMarket, DBMinBuyout, DBRegionMarketAvg, DBRegionSaleAvg only, an answer above 0 counts) and the vendor (0). `prices.source` "auto" (the default: by priority) or one of them (the vendor fills in what it has no price for); `prices.tsm` picks TSM's string (DBMarket default). TSM refreshes by the cache age (no callback); a TSM "no price" is kept 30 s only. `/swagbag price [auto|auctionator|tsm [<price>]|vendor|string <price>]`; Settings > Bank & guild. Header totals, the Value column and the gold glow follow the choice.
- AC10.3 Price lookups are cached per link for the session, invalidated on Auctionator's price-update callbacks or every 10 min.
- AC10.4 (week 7) At the bank, an item whose stack is worth money glows gold: 100 g a stack by default, a gold amount, or your top 10% (`prices.worth`, `prices.worthGold`, `prices.worthTop`; `/swagbag worth`). A missing or secret price never glows. "Your top X %" is worked out again when the bank's contents change during a visit. A secret item link prices by its item ID (never used as a cache key).

#### F11. Low-consumables warning
- AC11.1 On `CHALLENGE_MODE_START` (and on entering an M+ instance) and on using an M+ teleport spell, SwagBag compares configured consumables against thresholds and prints one on-screen line ("Low: Flask (0), Healing Potion (2/5)"). Nothing prints when all thresholds are met.
- AC11.2 The watch list is editable (drag item onto the list; set threshold) and the wizard seeds it per role (deferred to v1.1: the week-12 wizard does not seed it).

#### F12. Safe Mode and diagnostics
- AC12.1 Any Lua error inside a SwagBag refresh/layout/event path switches that window (bags or bank) to Blizzard's frames immediately, including in combat, and prints one line: "SwagBag hit an error and switched to Blizzard bags. Type /swagbag report."
- AC12.2 `/swagbag safe on|off` toggles manually with confirmation.
- AC12.3 `/swagbag report` opens one copyable box with version, build, errors (last 10 from the ring buffer), failed feature checks, and loaded bag-related addons.
- AC12.4 `/swagbag check` runs all feature checks and prints PASS/FAIL per check.

#### F13. Offline snapshots
- AC13.1 Bags are snapshotted on logout and on every `BAG_UPDATE_DELAYED` flush (debounced to 5 s); character bank and warband bank are snapshotted on every bank visit (open and close).
- AC13.2 Any alt's bags, bank, and the warband bank can be viewed offline via the character dropdown, with an "as of 2 days ago" stamp.
- AC13.3 Item tooltips show "You have N (Bags 3, Bank 2 on Alt)" from snapshots.

#### F14. Blizzard-like look
- AC14.1 Default theme uses Blizzard's bag atlases/fonts and quality borders. Section headers match Blizzard's header style.

#### F15. Settings
- AC15.1 Settings are account-wide; focus modes and professions-dependent settings can be overridden per character via "Use character-specific settings" on the relevant page.
- AC15.2 Every setting has a default and shows its alternative(s) next to it.

#### F16. Guild bank window (full replacement)
- AC16.1 Opening a guild vault shows SwagBag's guild bank window instead of Blizzard's: all viewable tabs stacked as groups (or one tab at a time, option), with category sections or grid, search (full dim), and per-category AH value totals.
- AC16.2 Withdraw: right-click (or drag) a guild bank item moves it to the bags, respecting Blizzard's withdraw limits; the remaining daily withdrawals per tab are shown in the tab header.
- AC16.3 Deposit: right-click a bag item while the guild vault is open deposits it into the selected guild bank tab; the target tab is highlighted ("Deposits go to Tab 2").
- AC16.4 Tab contents load on demand (`QueryGuildBankTab`), are cached for the session, and a snapshot is saved per guild for viewing away from the vault ("as of 3 days ago").
- AC16.5 Gold deposit/withdraw, tab purchase, permissions and the log stay in Blizzard's frame, reachable by a "Blizzard guild bank" button on our window.
- AC16.6 First in-dev check **G1** (§11.3) verifies withdraw, deposit, tab switching and Hearthstone use afterwards, with no blocked actions. If any of these fail, the fallback is **view + search**: SwagBag's window shows contents/search/totals read-only, and Blizzard's guild bank frame stays visible beside it for moving items. This fallback is a setting switch (`guildBank.mode = "full" | "view"`), not a redesign.
- AC16.7 SwagBag never writes Blizzard's guild bank frame state; tab switching uses `SetCurrentGuildBankTab` only if G1 proves it untainted, otherwise via Blizzard's own tab buttons re-hosted on our window (the bank approach, §5.2).
- AC16.8 (week 8) A guild item whose data arrives late moves from New to its category by a held full layout, as the alt viewer's does; the regroup waits while the mouse is over the window or an item is on the cursor, and clears that visit's placeholders.

#### F17. Auto-sell junk and auto-repair (week 7)
- AC17.1 At a vendor, SwagBag sells gray items a vendor pays for, one at a time, never more than 12 per vendor visit (Blizzard's Buyback tab keeps 12; the auto-sell, `/swagbag sell junk` and Sell all share the count); selling past 12 needs a second, explicit yes that says the earlier sales leave the Buyback tab. Default on (`vendor.autoSell`); one chat line says what was sold.
- AC17.2 Never sold: a locked item, a piece of an equipment set, an item to open or learn, a gray BoE worth more than twice its vendor price at auction, gray gear whose look the account has not collected, and gray gear whose look the client cannot tell (no appearance source, no data yet, a secret answer: asked again at every sale, never remembered). Gear the account can never collect (the client says so) is ordinary junk and sells; rings, necklaces and trinkets have no appearance at all (the NO_LOOK slots) and always sell as junk unless another protection applies. The junk coin on a gray piece may use the look answer cached for its link; a sale check never does. Nothing is sold or repaired in combat. Week 9, ruling R0: "worth more than twice at auction" asks every loaded auction source (Auctionator, TSM) whatever `prices.source` says, and any one above twice keeps the item; Sell all's Auction House sentence uses the same value. Right before a sale the auction sources are asked again (a cached "no price" is never trusted on the sell path; the junk coin may use it). A vendor opened during a stacking run sells and repairs when the run ends, if still open (D19).
- AC17.3 Repair (`vendor.repair`: `own` default, `guild`, `off`) runs after the sale, out of combat; `guild` pays from the guild bank only when its limit and balance cover the cost, else falls back to own gold and says so. The setting never travels in a share string (F20).

#### F18. Item locks (week 7)
- AC18.1 Dropping an item on the small Lock button (or Settings > Vendor) locks every copy of that item ID, account-wide; again unlocks it. A locked item shows a padlock, says so on its tooltip, is found by `locked`, and is never sold by SwagBag. Selling it by hand still works; one chat line then names it and the Buyback tab.
- AC18.2 Unlocking everything asks first: the first press of Unlock all (or `/swagbag lock clear`) says how many locks it removes and waits for the same press again within 10 seconds; only the second clears. The cleared set is kept one step: `/swagbag lock undo` puts it back.
- AC18.3 (week 10) Warnings, never blocks: while a spell waits for its target (`SpellIsTargeting()`, any spell), a locked item's tooltip shows a red line under its "Locked" line (`Locked by you. SwagBag can't stop this spell: press Esc to cancel it.`); while the scrapper is open, a red line that a right-click can put it in; at Blizzard's delete box for a locked item, one red chat line and SwagBag's own note above the box (the box is never touched); a locked item landing in a scrapper slot, one red chat line (again only after it was taken out and put back). SwagBag never cancels, clicks, hides or changes Blizzard's spells, buttons or dialogs; other addons' one-click destroy buttons cast with no targeting and are not covered.
- AC18.4 (week 10) One switch, `locks.warn` (default on): Settings > Vendor > "Warn before destroying locked items", `/swagbag lock warn [on|off]`; the report's `Locks: N locked; destroy warnings on|off`.

#### F19. Section actions (week 7)
- AC19.1 Shift+right-click a section header opens a small menu: at a bank, "Send all to bank" and "Send all to warband bank"; at a vendor, "Sell all" after a confirmation (same protections and 12-a-visit limit as F17). Nothing moves in combat or under the mouse.

#### F20. Profiles and share strings (week 7)
- AC20.1 Named profiles save and load the account settings, with one step of undo (`/swagbag profile undo`) and a Defaults button. Share strings (`SWAGBAG:1:...`, text only) export settings, optionally with categories; import is Preview first, then Import; a string that is not ours, from a newer version, damaged, too long, or holding a value outside its setting's range or words is refused whole with the reason. Nothing in a string is ever run.
- AC20.2 Never in a share string, either way: `guildBank.withdrawAnyTab` and `vendor.repair` (the preview names them as never imported). An imported category must compile, may not carry a chat escape (`|T |H |A |K`, `|c` plus eight hex digits, `|cn`), and never outranks Junk, Equipment sets, Keystone & Crests or Reagents: a priority of 90 or more comes in at 89 and the preview names it (never refused); the priority of those four built-ins is never imported (the preview names it). `|cn` is refused only before an upper-case name and `:` (`herb|cname` is a query).
- AC20.6 (week 12) Share strings do not carry modes of your own: an export names them as left out; an import skips their entries (`m.` entries, `focus.*.m_` paths) and never makes a mode; the preview names them as skipped. The preview's "Ranked just below Junk" line names a category by the name it comes in under (AC20.4).
- AC20.3 (week 11) An export with categories leaves out a rule an import would refuse (broken, or holding a chat code) and names its category, so the user's own string is never refused; a string from elsewhere holding a broken category is still refused at import. One chat-code check (`Query.EscapeCode`) and one pinned list serve share strings and the category editor.
- AC20.4 (week 11, data safety) **An import never replaces a user category.** An imported category whose id is one the user has, as a category or as a deleted one's (never given again), comes in under a fresh id, and the string's category order and focus sections follow it; one whose name a category already has (any case, a built-in's own name, New, Free) comes in as "Name (2)", "Name (3)"... within the 30-character limit. The preview names them ("Added as new, next to yours (yours stay as they are): ...").
- AC20.5 (week 11, data safety) **Undo brings the categories back only if nothing changed them since.** The one step of undo after an import with categories holds the categories, built-in edits and order from before it; any later change to them (the category editor's Create, Save, Delete, Move, Reset to default, a drag onto a header, quick setup's order) drops that part, so Undo then brings back the settings only and never undoes what the user made since. Its answer says which: settings only (`Your categories stay as they are.`), or settings, categories and category order.

### 2.2 v1.1 – v1.3 (roughly monthly)

| Version | Contents |
|---|---|
| **v1.1** | Remaining focus modes batch 1: PvP, Vendor and AH split into separate modes, Crafting, Cooking, Questing, Leveling, Travel. Worth-money highlight on bank open (fixed threshold default 100 g, or top-X %; delivered week 7, AC10.4). Remaining overlays batch 1: AH value overlay, uncollected transmog (delivered week 7, AC9.4). |
| **v1.2** | Syndicator provider for alt data (replaces own store when present). Focus modes batch 2: Disenchanting/Salvage, Gear upgrade/Catalyst, Transmog farming, Pet battles, Profession knowledge, Housing. Overlays batch 2: uncollected pet/toy/decor (pet and toy delivered week 7; decor has the green glow only). |
| **v1.3** | List view (Sorted-style rows with name, count, ilvl, AH value column, sortable; delivered for the bags in week 5 and for the bank and the guild bank in week 8: the same rows and columns, one shared order (`bags.list`), a view button that cycles categories, list, grid in every window; the guild bank's list shows each tab's empty slots as one free row). Themes: modern flat; ElvUI-matching (auto-detect ElvUI, use its media). |

### 2.3 Later (demand-driven)

Per-bag view; freeform drag layout; i18n (localized keywords and UI strings); Wago distribution. (TSM price source and Masque skins shipped in week 9.)

### 2.4 Publish bar

v1.0 ships to CurseForge only after: 2 consecutive weeks of the user daily-driving it including M+ keys with zero Lua errors and zero Safe Mode triggers, plus at least 3 friends/guild testers for a week with no blocking reports.

---

## 3. Architecture

### 3.1 Engine/UI split

```
 ┌──────────────────── pure Lua (busted) ─────────────────────┐   ┌────────── WoW-only ──────────┐
 │ Query (parser, compiler, tri-state)                        │   │ Adapter.Retail (C_* calls)    │
 │ Categorizer (priority, item lists, memo, pending)          │   │ Buttons (secure pool)         │
 │ Layout (sections/grid, placeholders, diff)                 │   │ Views: Bags, Bank, Offline    │
 │ Focus (signal → mode set → expanded sections)              │   │ Signals (events → Focus)      │
 │ Snapshots (serialize/deserialize, migrations)              │   │ Overlays                      │
 │ Prices (provider interface, cache)                         │   │ Providers: Auctionator, Syndi │
 │ AltData (provider interface, own store)                    │   │ Settings UI, Wizard, Tour     │
 │ Config (schema, defaults, migrations)                      │   │ SafeMode, Report, ErrorTrap   │
 │ Locale table                                               │   │ Theme                         │
 └────────────────────────────────────────────────────────────┘   └───────────────────────────────┘
```

Rule: a module on the left may `require`/reference only other left modules and the `Adapter` **interface** (never `C_*` directly). Every left module runs under busted with `spec/mock_adapter.lua`.

### 3.2 Module catalogue

| Module | Purpose | Interface (sketch) | Depends on |
|---|---|---|---|
| `Core` | Addon table, namespace, event bus, out-of-combat queue, timers | `SB.On(event, fn)`, `SB.OutOfCombat(fn)`, `SB.Debounce(key, delay, fn)` | — |
| `Locale` | All UI strings | `L["key"]` with English fallback | — |
| `Adapter` | The only module calling `C_Container`, `C_Item`, `C_Bank`, `C_TooltipInfo`, `C_ChallengeMode`, `C_RestrictedActions`, frame globals | `GetBagIDs(kind)`, `NumSlots(bag)`, `GetSlot(bag, slot)` → normalized record, `GetItemInstant(link)`, `RequestLoad(itemID, cb)`, `IsBound(bag, slot)`, `IsWarbound(bag, slot)`, `GetIlvl(bag, slot)`, `GetUpgradeInfo(bag, slot)`, `SortBags()`, `SortBank(type)`, `ActiveBankType()`, `Caps` | — |
| `Checks` | Feature detection at load and on demand | `Checks.Run()` → `{name = {pass, detail}}`, `Checks.Required` | Adapter |
| `Inventory` | Live model of all containers; event coalescing with refresh reasons | `GetSlot`, `Iterate(kind)`, `OnChanged(fn)` with bitflags `COUNT`, `ITEM`, `SIZE`, `LOCK`, `COOLDOWN`, `LOADED` | Adapter, Core |
| `Items` | Derived item record + item key + bounded in-memory cache | `Describe(slot)` → record or `nil, "pending"`; `Key(record, class)`; `Invalidate(guid)` | Adapter |
| `Query` | Grammar → AST → closure; tri-state; keyword registry; validation | `Compile(text)` → `{fn, cacheClass, keywords, errors}`, `Eval(compiled, record)` → `true|false|nil`, `RegisterKeyword(def)`, `Validate(compiled)`, `Pretty(ast)` | — |
| `Categorizer` | Slot → category id; manual lists; priority; memo by cache class; pending set | `Assign(record)` → id or `nil`; `AssignAll(iter)` → `{id → ordered records}`; `Invalidate(reason)` | Query, Items |
| `Layout` | Assignments + previous layout → positions, placeholders, diff | `Compute(prev, assignments, opts)` → `{layout, diff, needsReflow}`; `Reflow(...)`; pure | — |
| `Focus` | Signals → active modes → expanded sections; peek/pin; merge/priority | `SetSignal(name, value)`, `ActiveModes()`, `ExpandedSections(windowId)`, `Peek(section)`, `Pin(section)`, `OnChange(fn)` | Config |
| `Signals` | WoW events → `Focus.SetSignal` | registers events listed in §6.2 | Adapter, Focus |
| `Snapshots` | Serialize/deserialize container state; schema; migrations | `Capture(kind)`, `Load(charKey, kind)`, `Migrate(db)` | Inventory, Config |
| `AltData` | Provider interface for cross-character counts and offline view | `RegisterProvider(name, impl, priority)`, `Counts(itemKey)`, `Characters()`, `GetContainer(charKey, kind)` | Snapshots |
| `Prices` | Provider interface for item values | `RegisterProvider(name, impl, priority)`, `Value(link)` → copper or `nil`, `Source()` | — |
| `Providers.Auctionator` | `Auctionator.API.v1.GetAuctionPriceByItemLink("SwagBag", link)` behind `Prices` | — | Prices |
| `Providers.Syndicator` (v1.2) | `Syndicator.API` behind `AltData` | — | AltData |
| `Config` | Account DB + per-character overrides; defaults; schema version; migrations | `Get(path)`, `Set(path, v)`, `CharOverride(path, on)`, `Defaults` | — |
| `Buttons` | One `ContainerFrameItemButtonTemplate` per physical slot; per-bag parent frames; placeholder pool | `Get(bag, slot)`, `EnsureCapacity(bag, n)`, `Place(button, x, y)`, `Placeholder()` | Adapter |
| `Views.Bags`, `Views.Bank`, `Views.GuildBank`, `Views.Offline` | Windows; sections and grid; search box; mode title; headers | `Open()`, `Close()`, `Refresh(reason)`, `SetMode(sections|grid)` | all |
| `Overlays` | Per-button overlay widgets driven by item records | `Apply(button, record)`, `Clear(button)` | Items, Prices |
| `Sort` | Display order as data; physical sort delegation | `DisplayOrder(records, spec)`, `Physical(kind)` | Adapter, Core |
| `SafeMode` | Suppress/restore Blizzard frames; auto-fallback | `Enable(window)`, `Disable(window)`, `IsOn(window)` | Core |
| `ErrorTrap` | pcall wrappers; ring buffer; report builder | `Guard(label, fn)`, `Recent()`, `Report()` | SafeMode |
| `Wizard`, `Tour`, `SettingsUI`, `RuleBuilder` | Setup and editing UI | — | Config, Query, Categorizer |
| `Theme` | Blizzard-like default; theme registry | `Apply(name)` | — |

### 3.3 Provider interfaces

```lua
-- Prices
provider = { name = "Auctionator", priority = 10,
  available = function() return Auctionator and Auctionator.API and Auctionator.API.v1 ~= nil end,
  value = function(link) return copper or nil end,        -- nil = unknown
  onUpdate = function(cb) end }                           -- optional invalidation hook
-- Built-in fallback provider "Vendor" (priority 0) uses sell price from `C_Item.GetItemInfo` (the global `GetItemInfo` was removed in 12.1.5).
-- Week 9: "TSM" (priority 5, missAge = 30: its "no price" is kept 30 s) through Adapter.TSMAvailable / TSMPrice.
-- Prices.AuctionValue(link, itemID, recheck) (ruling R0): the highest answer of every loaded auction source,
-- whatever prices.source says; recheck = true (the sell path) never trusts a cached "no price" and works the
-- sources out again.

-- AltData
provider = { name = "Syndicator", priority = 10,
  available = function() ... end,
  counts = function(itemKey) return { bags=, bank=, warband=, byChar = {...} } end,
  characters = function() return { {key=, name=, realm=, class=, lastSeen=}, ... } end,
  container = function(charKey, kind) return { slots = { {link=, count=}, ... } } or nil end }
-- Built-in provider "Own" (priority 0) reads Snapshots.
```

Syndicator's callbacks are registered when it becomes available, at login or later in the session (week 8; a hook that fails at its load is tried once more a moment later); a late hook announces `SB_ALTDATA_CHANGED`, and the alt viewer re-reads its character only when the answering provider changes (its "shows what was saved when it opened" rule otherwise stands). The highest-priority available provider wins per call. Providers are wrapped in `ErrorTrap.Guard`; three errors in a session disable a provider with one chat line.

### 3.4 Testability

`spec/mock_adapter.lua` implements the `Adapter` interface over fixture inventories (`spec/fixtures/`: 200-slot bags, 1,290-slot bags+bank, caged pets, keystones, unloaded items, Midnight ilvl ranges). All left-column modules are tested with busted; `Buttons`, `Views`, `SafeMode` are tested in-game via `/swagbag check` and the verification checklist (§11).

---

## 4. Button and placeholder contract

This page resolves critique Issue 1 using the construction proven in spikes A, A_COMBAT and D.

### 4.1 Objects

| Object | Type | Count | Created | Parent | Moves by |
|---|---|---|---|---|---|
| **Bag frame** | plain `Frame`, `SetID(bagID)`, `IsCombinedBagContainer = false` | one per bag ID 0–5, and one per purchased bank tab ID (6–11, 12–16) | login | window scroll child | never |
| **Slot button** | `ItemButton` with `ContainerFrameItemButtonTemplate`, `SetID(slot)` | one per physical (bag, slot); capacity = max(current size, 38 for bags, 98 for bank tabs) → ≈1,290 | login (≈55 ms measured, hidden by loading screen) | its bag frame, **permanently** | `ClearAllPoints` + `SetPoint` only (the list views of the bank and the guild bank also `SetScale` them, legal in combat) |
| **Placeholder** | plain `Frame` with desaturated icon texture, `EnableMouse(true)` | pooled, created on demand | out of combat preferred; allowed in combat (plain frame) | window scroll child | `SetPoint` |
| **Section header** | plain `Button` | pooled | on demand | window scroll child | `SetPoint` |

Slot buttons are **never** reparented, destroyed, or re-`SetID`'d after creation. Week 9, Masque: each button joins a Masque group (Bags, Bank, Guild bank, Alt viewer) once, through `group:AddButton(button, nil, "Item")`, out of combat only; there is no SwagBag setting (Masque's own options switch each group off). The hover post-hook on each slot button (`HookScript("OnEnter")`, never a click script or hook) clears Blizzard's glow flag and marks the item seen (AC3.3). `GetBagID()` resolves through the parent's ID (verified). Buttons report `IsProtected() == false` (verified), so `SetPoint`, `Show`, `Hide`, `SetAlpha` are legal in combat (verified across three combat batteries). We nevertheless defer `CreateFrame` and `EnsureCapacity` growth to `PLAYER_REGEN_ENABLED` by policy.

### 4.2 Invariants

1. **Identity:** a slot button always shows whatever is physically in its (bag, slot). We never pretend otherwise.
2. **Section truth:** every slot button drawn inside a category section shows the item that section was built for, or it is not in that section. (The spike asserted this after every incremental update with zero violations.)
3. **Placeholder honesty:** a placeholder never responds to item interaction. Its click shows a tooltip "This item moved or was used — items regroup when you close the bag" and does nothing else. (Spike check `placeholderClickIsHarmless` is the first in-dev verification; see §11.3.)
4. **Free is real:** empty slots are drawn as their real buttons in the "Free" section, so dropping an item onto Free is a real drop into that slot.
5. **No motion under the cursor:** a button is never moved while `IsMouseOver()`, while `GetCursorInfo()` holds an item, or while a modifier key relevant to the button is down. Deferred moves retry 300 ms later. SwagBag's own item moves (the mover, week 7) follow it too: an item on the cursor holds every step while the vendor or bank is open; an item whose button is under the mouse holds up to 20 retries, then stays; a moved item leaves a placeholder (§4.3). In a list a row under the mouse holds its button too, and a list that falls back to categories (below) waits like any layout. Week 8, all windows: a list row never shows a full-size button, so every button is scaled before a list is drawn; if a scale does not take, that layout draws as categories instead, said once per opening, recorded under "none" (never Safe Mode). Week 9: "anything on the cursor" means any `GetCursorInfo()` answer (an item, even one with a secret ID, money, a spell, a merchant's item) **or a spell waiting for its target** (`SpellIsTargeting()`), all through `Adapter.CursorBusy()`; it holds every move of the stacker, `Adapter.MoveStack` and the week-7 mover. Week 10: the same rule, through `Adapter.CursorBusy()`, now guards every layout of the bags, bank and guild bank windows (not only the moves); the drops that need the item itself (a section header, the Lock button, the Consumables page) read the item; the alt viewer keeps the item rule (no spell targets a snapshot). **Recorded exception (week 9, F6 / ruling W5-1):** a held F6 fallback rescales the drawn categories' buttons to full size at once, even while the mouse may rest on one (leaving them small is worse: a shrunk button slides under the mouse anyway and its click target stays small).

### 4.3 State transitions while a window is open

| Event at (bag, slot) | Out of combat | In combat |
|---|---|---|
| **Item leaves** (used, vendored, moved) and the button is in a category section | Placeholder is placed at the button's position with the old icon; the button moves to the next cell of Free. `needsReflow = true`. | Same (verified legal). |
| **Item leaves** and the button is in Free or New | Repaint only. With the free tile on (default, D19 / W3-13), a button emptied in New joins Free instead (as its family's hidden spare, or as the tile when the family had none), so the tile's number is always the real free count. | Same. |
| **Different item arrives** in a slot whose button is in a section | Placeholder at old position; button moves to the next cell of **New**. | Same. |
| **Item arrives** in a Free slot | Button moves to New. | Same. |
| **Item hovered** (its button or list row; week 9, AC3.3) | Nothing moves: it stays in New while the window is open and joins its category at the next open or Reflow. An item never hovered stays in New at every open, whatever the focus mode. | Same. |
| **Count changes** | Repaint (`COUNT` reason). | Same. |
| **Same item, changed link** (keystone level, enchant, gem) | Repaint only; re-categorized at the next open or Reflow. | Same. |
| **Lock/cooldown changes** | Repaint only. | Same. |
| **New overflows** its 2 rows | Further arrivals go to the end of Free (never shifting others); header shows "+N more below". New's rows are always reserved. | Same. |
| **Bag size grows** (new bag equipped) | `EnsureCapacity` creates buttons; they appear in Free. | Logged; buttons created on `PLAYER_REGEN_ENABLED`; until then the slot is invisible (acceptable — equipping a bag in combat is not possible anyway). |
| **Item data loads** (`ITEM_DATA_LOAD_RESULT`) for a pending item | Stays in New until hovered; re-categorized for the next layout after that. | Same. |
| **Window closes** | Placeholders released; `needsReflow` cleared; the next open does a full layout. | Reflow deferred to `PLAYER_REGEN_ENABLED` plus next open. |
| **Reflow button / sort button** | Full layout, guarded by rule 5 (retries until cursor is clear). Sort regroups 0.3 s after the last bag update. | Sort is refused with feedback; Reflow is allowed (verified), still guarded by rule 5. |
| **Placeholder clicked** | Tooltip only. | Tooltip only. |

### 4.4 Scrolling

All bag frames and placeholders live under one scroll child per window. Section positions are absolute within the scroll child. After any layout, `ClampScroll()` ensures `offset ≤ max(0, childHeight − viewHeight)` (spike found the bank close case).

### 4.5 Why not the `SetBagID()` attribute construction

The attribute path (buttons without per-bag parents) would simplify layout but was not exercised in combat during the spike. It is the first in-dev check (§11.3, V1). If it passes in combat on three separate occasions, v1.1 may switch to it behind a flag; v1.0 ships the per-bag-parent construction.

---

## 5. Bank design

### 5.1 Model

One SwagBag bank window, opened on `BANKFRAME_OPENED`, closed on `BANKFRAME_CLOSED`. Contents: a "Character bank" group and a "Warband bank" group, each containing the category sections (or grid) for the tabs enumerated from `C_Bank.FetchPurchasedBankTabIDs(bankType)` — never hardcoded counts. The bag window opens alongside, as Blizzard does.

### 5.2 Tiny mode (default)

On `BANKFRAME_OPENED`, out of combat:
1. `BankFrame:SetParent(tinyParent)` where `tinyParent` is a 1×1 frame at `SetScale(0.001)`. `BankFrame` stays **shown**, so `BankFrame:GetActiveBankType()` keeps returning a value (it returns nil when `BankPanel` is hidden — verified from Blizzard source).
2. `BankFrame.TabSystem` is reparented onto SwagBag's bank window header and re-anchored there. These are Blizzard's real tab buttons; a click runs Blizzard's own secure code. SwagBag only reads the result.
3. On `BANKFRAME_CLOSED`, both reparents are restored (deferred to out of combat if needed). Only `BankFrame`'s **parent** is saved and restored, never its anchors (W3 Task 1 review: restoring anchors could leave it invisible); anchors are set only on the re-hosted TabSystem.

Deposit target: SwagBag never chooses it. Right-click on a bag item runs Blizzard's handler, which uses `BankFrame:GetActiveBankType()`. SwagBag reads the same value (read-only) to highlight the receiving group and to label the header ("Deposits go to Warband bank - switch with the tabs below"; the re-hosted tabs sit under the title row). Verified in the spike: deposit followed the active tab in normal mode with zero writes.

Deposit warbound (AC2.8): the button runs the game's deposit for the warband bank type on the user's own click, so the selected bank type (`BankFrame:GetActiveBankType()`) is neither read nor written for it. Right-click deposits still follow the active tab as above.

Send all to bank / warband bank (week 7, F19): the bank type is chosen on the user's click and passed to the game's own item-use call as its argument; SwagBag neither reads nor writes Blizzard's selected type for it.

### 5.3 Taint rules (enforced by CI grep + luacheck)

Forbidden anywhere in SwagBag source: `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`. The spike's taint probe proved that one `BankFrame:SetTab()` call from addon code taints `UseContainerItem` until /reload; this is a NO-GO, permanently.

Also: no `PreClick`/`PostClick` scripts on slot buttons; no insecure wrappers around item use; overlays and tooltips hook `OnEnter`/`OnLeave`/`OnUpdate` only. Week 10: reading Blizzard's delete box (`StaticPopup_FindVisible`) and the scrapper's slots is allowed; writing `StaticPopupDialogs`, calling any method on a Blizzard dialog, and every `C_ScrappingMachineUI` call that changes something are not.

### 5.4 Fallback

The first in-dev check V2 (§11.3) is "deposit lands in the active bank type while Blizzard's bank is in tiny mode, and a Hearthstone works afterwards". If it fails on the first run, the setting `bank.blizzardFrame = "beside"` becomes the shipped default: Blizzard's bank frame stays visible exactly where Blizzard puts it, with its own tabs, and SwagBag's window positions itself beside it (SwagBag never moves Blizzard's frame); SwagBag's window still shows both groups and highlights the receiving one. The user can choose either in Settings → Bank ("Hide Blizzard's bank (tiny) / Show it beside SwagBag").

### 5.5 Sorting at the bank

Sort buttons call `C_Container.SortBank(Enum.BankType.Character)` / `(Enum.BankType.Account)` (verified 46 ms, from addon click) and then schedule a full reflow after the next `BAG_UPDATE_DELAYED`, respecting the hover guard.

Week 9, optional SwagBag sort mode (`sort.mode = "stacks"`, "Partial stacks first"; "Blizzard's sort" stays the default; `/swagbag sort [stacks|blizzard]`, Settings > Bags): the stacker merges each item's partial stacks, then puts the item's one partial stack in front of its full ones; nothing else moves. One scope per button (the bags with the reagent bag, the character bank, the warband bank), never across, so no item changes bank type. Locked, equipment-set, single, not-loaded and secret-link items stay put; a stack the game holds locked for another reason (an auction, a letter, a trade) is left out. Out of combat only, one move per 0.2 s through the game's own pickup calls (`Adapter.MoveStack`, which never starts while `Adapter.CursorBusy()` and puts back what did not fit), P5 (anything on the cursor waits however long; a slot under the mouse up to 20 retries, then that item stays). A move that changes nothing, or a moved slot still locked after 10 checks, stops the run ("stuck"); combat or a closed window stops it before the next move, nothing queued; an error stops it with its own line (recorded under "none", never Safe Mode). The stacker and the week-7 mover never run at once. The click answers once in the window's title; the outcome is one chat line.

### 5.6 ESC

SwagBag's windows are in `UISpecialFrames`. ESC hides SwagBag's bank window and does nothing else; Blizzard's own ESC handling closes the bank interaction (verified: `escClosesBankInteraction`). Whenever SwagBag's bank or guild bank window hides while the interaction is still live (ESC, the X, Safe Mode), Blizzard's frame is restored and visible (W3-11): an invisible open bank or vault would swallow bag right-clicks, so this is an item-safety rule. If the interaction is still open after SwagBag's window is hidden (user hit ESC on another frame first), the title bar of the bag window shows "Bank still open" with a button that calls nothing but shows SwagBag's bank window again.

### 5.7 Snapshots

Because the character bank is unreadable away from a banker (0 slots, measured), the bank snapshot is captured on `BANKFRAME_OPENED` (+0.3 s), on every `BAG_UPDATE_DELAYED` while open, and on `BANKFRAME_CLOSED`. The offline view (§8) is what the user sees anywhere else.

---

## 6. Focus mode engine

### 6.1 Concepts

- **Signal:** a named boolean or enum fact about the world, set by `Signals` from events (e.g. `instanceType = "party"`, `challengeMode = true`, `fishing = true`, `merchantOpen = true`).
- **Mode:** `{id, name, enabled, class = "combat"|"activity"|"location", trigger = predicate over signals, sections = set of category ids, order = optional section ordering override, builtin = bool}`.
- **Active set:** modes whose trigger is true. Re-evaluated on every signal change (cheap: a handful of table lookups).
- **Style (`focus.style`, D15):** `front` (default) or `collapse`. In `front` an active mode moves its sections to the top, right under New, in the mode's order, and collapses nothing; sections the user collapsed stay collapsed (also a mode section moved to the top), and New always stays open. In `collapse` an active mode collapses every section it does not use (New always open). Changing the style drops peeks and pins. The same choice is `/swagbag mode style [front|collapse]` and a Settings → Focus modes row.
- **Resolution:** active set → expanded section set, by **merge** (union; default) or **strict priority** (`combat` > `activity` > `location`; within a class, user order). "No active mode" → all sections expanded (normal browsing).
- **Peek** (`collapse` style only): clicking a collapsed header while a mode is active expands it until the window closes or the active set changes. **Pin:** a pin icon on a peeked header, or the option "Keep open until mode changes", keeps it until the active set changes. Default: peek.
- **Manual override:** the mode title in the window header offers "Pause modes for this session" (one click, with a visible "Paused" badge and a resume button).

### 6.2 Signals and detection

| Signal | Events | Read | Notes |
|---|---|---|---|
| `combat` | `PLAYER_REGEN_DISABLED/ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` (Combat = 0) | `InCombatLockdown()` | class: combat |
| `encounter` | `ENCOUNTER_START/END`, restriction Encounter (1) | `C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Encounter)` | class: combat |
| `challengeMode` | `CHALLENGE_MODE_START/COMPLETED/RESET`, `PLAYER_ENTERING_WORLD`, restriction ChallengeMode (2) | `C_ChallengeMode.IsChallengeModeActive()` or the restriction | M+ |
| `instanceType` | `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA` | `IsInInstance()` → `"party"|"raid"|"pvp"|"arena"|"scenario"|nil` | |
| `delve` | same + `SCENARIO_UPDATE` | `instanceType == "scenario"` and (feature-detected `C_DelvesUI`/`C_PartyInfo.IsDelveInProgress` if present, else `GetInstanceInfo()` difficulty name matching the delve difficulty IDs table) | verify in-game (V5) |
| `pvpMatch` | restriction PvPMatch (3), `PLAYER_ENTERING_WORLD` | `instanceType in {pvp, arena}` or the restriction | |
| `fishing` | `UNIT_SPELLCAST_CHANNEL_START` (player), `LOOT_READY` | channel spell ID in `FISHING_SPELLS` (seeded with 131474, name-matched as backup) or `IsFishingLoot()`; decays 90 s after the last signal | verify (V6) |
| `gathering` | `UNIT_SPELLCAST_SUCCEEDED` (player) then `LOOT_READY` with `GetLootSourceInfo(1)` GUID type `GameObject` or `Creature` (skinning) | last successful spell ID in `GATHER_SPELLS` allowlist (herbalism, mining, skinning families, per expansion skill lines), within 6 s; decays 120 s | allowlist is a data file seeded from the spike's `loots[].spellBefore` log; chests ("Opening") and archaeology ("Digging") are explicitly not listed |
| `professions` | `SKILL_LINES_CHANGED`, login | `GetProfessions()`/`GetProfessionInfo()` (feature-detected) | Gathering mode adapts its section set to owned professions |
| `merchantOpen` | `MERCHANT_SHOW/CLOSED` | | location |
| `auctionOpen` | `AUCTION_HOUSE_SHOW/CLOSED` | | location |
| `bankOpen` | `BANKFRAME_OPENED/CLOSED` | | location |
| `tradeSkillOpen` (v1.1) | `TRADE_SKILL_SHOW/CLOSE` | profession ID | Crafting/Cooking |
| `mapRestricted` | restriction Map (4) | informational only | |

All handlers are `O(1)` table writes plus one `Focus.Recompute()` that touches at most ~30 modes. The spike measured average handler cost well under 0.1 ms.

### 6.3 Built-in modes (v1.0 set in bold)

| Mode | Class | Trigger | Default expanded sections |
|---|---|---|---|
| **M+** | activity | `challengeMode` or (`instanceType == "party"` and a keystone is in bags and difficulty is Mythic) | Consumables, Keystone & Crests, Gear (with ilvl/track), Equipment sets, New |
| **Raid** | activity | `instanceType == "raid"` | Consumables, Gear, Equipment sets, New |
| **Delves** | activity | `delve` | Consumables, Gear, Equipment sets, Delve items (keys/curios via query), New |
| **Gathering** | activity | `gathering` | the profession's materials sections for owned gathering professions (Herbs / Ore / Leather / Cloth), Tools, New |
| **Fishing** | activity | `fishing` | Fish & Lures, Cooking materials, New |
| **AH/Vendor/Bank** | location | `auctionOpen` or `merchantOpen` or `bankOpen` | Junk, Trade Goods, BoE gear, Warbound until equipped, Sellables (worth-money rule), New; at the bank: everything expands by default (bank mode is about highlighting, not collapsing) |
| PvP (v1.1) | activity | `pvpMatch` | Consumables, PvP gear, New |
| Vendor / AH split (v1.1) | location | separate triggers | — |
| Crafting, Cooking, Profession knowledge (v1.1/1.2) | location | `tradeSkillOpen` + profession | Materials for that profession, Knowledge items |
| Questing, Leveling, Travel (v1.1) | activity | quest log / level < max / taxi or mount channel | Quest items, Gear upgrades, Travel items |
| Disenchanting/Salvage, Gear upgrade/Catalyst, Transmog farming, Pet battles, Housing (v1.2) | activity/location | enchanting window / upgrade NPC / instance with `PLAYER_TARGET` in legacy raid / pet battle events / housing zone | per mode |

`c_wue` (Warbound until equipped, §7.6) joins every mode set that contains `c_boe` (today only AH/Vendor/Bank). `c_sets` (Equipment sets, §7.6) joins every mode set that contains Gear. A mode whose sections the user edited before week 7 keeps their choice (only explicit values are stored): add Equipment sets in the mode editor.

Every built-in mode's section set is editable; "Reset to default" is next to it (P1). Users create custom modes with the same editor: name, trigger (choose from the signal list, or "manual only"), sections (AC8.7). A mode of your own's class follows its trigger (manual > combat > activity > location in strict priority).

### 6.4 State machine

```
            signal change
 IDLE ──────────────────────► RECOMPUTE ──► active set unchanged ──► IDLE
                                  │
                                  ▼ changed
                           APPLY (window visible?)
                              │ yes               │ no
                              ▼                   ▼
                     collapse/expand headers    store; apply on next Open
                     clear peeks (keep pins
                     only if same mode set)
                              │
                              ▼
                     print one line if the user enabled
                     "announce mode changes" (default off)
```

Style `front` does not collapse or expand anything: it re-orders whole sections (each with its header and its cells) under New. A re-order the world starts (a key, a vendor, a bank visit) waits while the mouse is anywhere over the items, then applies once; loot that arrives meanwhile lands in the order still drawn (P5). The diagram above is the `collapse` style.

Applying a mode never moves a button relative to its own section header; sections below a collapsed one shift as a whole, and the hover guard holds the restack. Collapsing a section hides its buttons and placeholders and re-stacks section headers below it; the hover guard still applies (a collapse that would move the hovered button is deferred to `OnLeave`). Re-expanding uses the stored layout, so items return to the same cells.

### 6.5 Cost budget

- Signal handler: ≤ 0.1 ms average, ≤ 2 ms worst.
- `Recompute`: ≤ 0.5 ms for 30 modes (week 12: measured by the suite with the six built-ins and ten modes of your own).
- `Apply` with the window open: ≤ 5 ms (header restack only).
- Zero cost while no window is open and no signal fires. No polling, no `OnUpdate`.

### 6.6 Low-consumables warning (part of M+ mode)

Triggers: `CHALLENGE_MODE_START`; `PLAYER_ENTERING_WORLD` into an M+ instance; `UNIT_SPELLCAST_SUCCEEDED` with a spell ID in the M+ teleport allowlist (data file; Blizzard's dungeon teleports). Checks each watched entry `{query or itemID, threshold}` against live counts and prints one line through `UIErrorsFrame` (on-screen) and chat. Rate-limited to once per 60 s per trigger.

---

## 7. Query language

### 7.1 Goals and compatibility stance

One grammar for the search box, categories, focus-mode section queries and consumables watch lists. **Syntax is Syndicator/Baganator-compatible**: a category string pasted from Baganator or a Wago category should parse and match the same items for every keyword both support. Our implementation is clean-room and stricter: fixed precedence, positioned errors, tri-state semantics. Where Syndicator's behaviour is undefined (e.g. the gold-range quirk noted in research), we define it and document the divergence.

Desk spike F (grammar diff against the Syndicator v284 mirror and 24 published Wago/Baganator strings) ran on 2026-10-01: `docs/research/2026-10-syndicator-grammar-diff.md`. Its findings are folded into §7.2 and §7.5. Any divergence found there is listed under "Known divergences", never silently absorbed.

### 7.2 Grammar

```
expr     := or
or       := and ( ("|" | "||") and )*
and      := not ( "&" not )*               -- explicit & only; adjacent words are NOT implicit AND (see 7.5)
not      := ("!" | "~") not | primary
primary  := "(" expr ")" | term
term     := keyword | numeric | level | range | exact | text
keyword  := WORD                            -- registered keyword: boe, junk, potion, reagent, ...
numeric  := WORD op NUMBER                  -- ilvl>250, lvl<80, gear<210, count>=5 (strict < >)
level    := op NUMBER | DIGITS              -- Syndicator item level: <536 = ilvl<=536, >150 = ilvl>=150, 536 = ilvl=536
range    := DIGITS "-" DIGITS               -- one word: 400-450 = ilvl>=400 & ilvl<=450 (either order)
exact    := "#" WORD                        -- keyword only; never a name-text match; unknown = warning, false
text     := WORD | '"' chars '"'            -- item-name substring (case-insensitive, ASCII-folded in enUS)
op       := "=" | "<" | "<=" | ">" | ">="
```

Precedence: `!` > `&` > `|`; parentheses override. `~` is a synonym for `!` and `||` for `|` (Syndicator spellings). Whitespace around operators is ignored. A bare term is resolved in this order: a single all-digit word `N` or a single `N-M` word is an item-level test (`level`, `range`); otherwise a registered keyword if one exists (keyword match); **else** a name-text match. `#word` forces keyword. A quoted string is always text. The parser records the character span of every node for error display.

Unknown-keyword policy: a bare word that is not a registered keyword is a text match (Syndicator behaviour); the rule builder shows a hint "matching item names containing 'potin' — did you mean `potion`?" when it is within edit distance 1 of a keyword **or two neighbouring letters swapped** (`flsk` → `flask`, `ptoion` → `potion`; week 11, in the category editor).

### 7.3 Keyword table (v1.0)

| Family | Keywords | Cache class | Source |
|---|---|---|---|
| Type | `armor`, `weapon`, `gear` (= armor or weapon), `consumable`, `potion`, `flask`, `food`, `drink`, `elixir`, `rune`, `reagent`, `tradegoods`, `trade goods` (as `"trade goods"`), `herb`, `ore`, `leather`, `cloth`, `enchanting`, `gem`, `recipe`, `questitem`, `quest`, `key`, `keystone`, `pet` (caged), `mount`, `toy`, `housing` / `decor`, `cosmetic`, `container`, `miscellaneous`, `junk` (quality 0), `profession tool`, `profession gear` | static (type/subtype from `C_Item.GetItemInfoInstant`); `keystone` and `pet` instance | `C_Item.GetItemInfoInstant` class/subclass IDs |
| Slot | `head`, `neck`, `shoulder`, `back`, `chest`, `wrist`, `hands`, `waist`, `legs`, `feet`, `finger`, `trinket`, `mainhand`, `offhand`, `twohand`, `ranged`, `shirt`, `tabard`, `bag` | static | equip location |
| Quality | `poor`, `common`, `uncommon`, `rare`, `epic`, `legendary`, `artifact`, `heirloom` | instance | link quality |
| Binding | `boe`, `bop`, `boa`, `warbound`, `wue` (warbound until equipped), `bound`, `soulbound`, `tradeable` | instance | `C_Item.IsBound`, `C_Item.IsBoundToAccountUntilEquip`, bind type from `C_Item.GetItemInfo` |
| Numeric | `ilvl` (`ilvl>250`), `lvl`/`level` (required level), `gear` with op (`gear<210` = equippable gear under ilvl), `count`, `stack`, `expansion` (`expansion=current` resolved from `C_Item.GetItemInfo` expansion ID vs. `GetExpansionLevel()`), `gold`/`value` (price per unit from `Prices`, in gold: `value>50`) | ilvl/gear/level/expansion: instance; count/stack: **volatile**; value: volatile (session cache) | APIs listed |
| State | `new` (session-new set), `locked` (locked by the user, week 7; the client's own lock is `inuse`; a one-time login note names saved queries that use the word), `cooldown`, `usable`, `equipped` (in an equipment set), `upgrade` (upgrade track present), `partial` (count < stack) | **volatile** | container info, `C_Container`, `C_Item.GetItemUpgradeInfo`-family (feature-detected) |
| Location | `bags`, `backpack`, `reagentbag`, `bank`, `warband`, `tab=N` | volatile (slot-bound) | bag ID |
| Crafting (Midnight) | `crafting reagent`, `quality1`..`quality5` (crafting quality tier) | instance | `C_TradeSkillUI.GetItemReagentQualityByItemInfo` (feature-detected) |
| Collection (v1.1+) | `uncollected`, `transmog`, `collected` | instance; `uncollected` (week 7: appearances, toys, mounts, pets) is registered **volatile**, since its answer changes when the account learns something, not with the item's link; tooltip-derived where no API, `issecretvalue()`-guarded → `nil` | `C_TransmogCollection`, `C_PetJournal`, `C_ToyBox`, `C_Housing*` (feature-detected) |
| Currency-like | `crest`, `upgrade currency` | static | item ID allowlist in data file (per season; updated with patches) |

Keywords are registered English-only in v1.0 through `Query.RegisterKeyword{name, aliases, class, eval}`. The registry is the single place localization will plug in later (register localized aliases alongside English; `#` exact remains English). Matching never lowercases non-ASCII; the enUS implementation ASCII-folds and lowercases; a UTF-8-aware fold is a documented i18n task.

### 7.4 Examples (Midnight-squished item levels)

- `gear & ilvl>280 & !bound` — BoE gear worth selling.
- `(potion | flask | food) & lvl>=80` — current consumables.
- `keystone | crest` — M+ section.
- `junk | (gray & !quest)` — vendor trash (`gray` is an alias of `poor`).
- `"Healing Potion"` — exact name phrase.
- `#rune` — the keyword only, not items named "Runecloth".
- `value>100 & tradegoods` — trade goods worth more than 100 g each.

### 7.5 Known divergences from Syndicator (documented, surfaced in the editor)

Verified against Syndicator v284 by desk spike F (`docs/research/2026-10-syndicator-grammar-diff.md`, 2026-10-01).

1. **Adjacent words are one phrase in both.** `healing potion` is one term; use `&` for conjunction. (Not a divergence; kept for clarity. The builder auto-quotes values containing operators, which handles the critique's `Metal & Stone` case.)
2. **Precedence is the same** (`!` > `&` > `|`, parentheses group). `~` is accepted as a synonym for `!`, and `||` for `|`.
3. **Errors are shown, not swallowed.** Syndicator silently ignores unbalanced parentheses and stray operators; we mark the category invalid and keep the previous compiled version active. Week 11: this holds for the category editor too: a broken change of a rule that works keeps that rule in use, and on, and is stored as the category's `draft` until fixed or dropped ("Back to the working rule"). Exception: an **unknown `#keyword` is a warning, not an error**. It evaluates `false`, as in Syndicator, so imported OR-lists of alternative spellings keep working.
4. **Undefined branches are defined.** Numeric comparisons on items lacking the field (ilvl on a potion) evaluate `false`, not `nil`.
5. **Tri-state**: items with unloaded data evaluate `nil` and are held in New rather than mis-filed (Syndicator also passes "unknown" through).
6. **`#` is keyword-only in both** (exact keyword: no prefix expansion, no name text). Confirmed by spike F; the `=word` fallback is dropped.
7. **Bare words search item names only.** Syndicator also searches selected tooltip lines and treats a bare word as a keyword *prefix* (`pot` finds potions). We match whole keywords, else the name. The editor hints at the nearest keyword.
8. **Item-level syntax.** Syndicator's bare forms are accepted: `<N`, `>N`, `=N`, `N` and the range `N-M`. Bare `<`/`>` **include** N as in Syndicator (`<536` = `ilvl<=536`), and the range includes both ends. Our named forms `ilvl>N`, `gear<N`, `lvl<N` are SwagBag extensions with **strict** `<`/`>`. A bare number is an item-level test only; it does not also match item names. Our `ilvl` counts equippable gear only; Syndicator reads the tooltip item level of any item.
9. **Quotes** are a SwagBag extension (always name text). In Syndicator `"` is a literal character.
10. **Same word, different meaning:** `upgrade` (ours: has an upgrade track; theirs: is an upgrade for this character) and `bop` (ours: bind type; theirs: currently bound). Both are explained in the editor's keyword help.
11. **A comparison after a multi-word phrase** (`a b ilvl>5`) is a positioned `AND_BEFORE_COMPARISON` error for us; Syndicator treats the whole string as a name search that matches nothing.
12. **Keyword vocabulary.** Syndicator's English spellings used by published category strings are registered as aliases: `equipment`, `bwe`, `tradeable loot`, `tradable loot`, `tradeskill`, `profession`, `profession equipment`, `battle pet(s)`, `off-hand`/`off hand`/`held in off-hand`, `main hand`, `two-hand`, `one-hand`, `trash`, `account bound`, `warbound until equipped`, `helm`, `cloak`, `bracers`, `gloves`, `belt`, `boots`. Subclass and detail keywords we do not have yet (`elemental`, `optional reagents`, `finishing reagents`, `crafting reagent`, `open`, `socket`, expansion and profession names) are unknown `#keywords` (rule 3) until they are registered.
13. **At paste** (week 11, AC6.3): a Baganator search pasted into Settings > Categories is translated where the two differ (gold amounts, `!!`, an open `(`), and every other difference above is named in the paste view before anything is made.

### 7.6 Default category set (first run, display order)

New · Keystone & Crests · Consumables · Gear · Equipment sets (`c_sets`, `equipped`, priority 92, right after Gear) · BoE gear · Warbound until equipped (`c_wue`, `gear & wue`, priority 74, just below BoE gear) · Trade Goods · Herbs · Ore · Leather & Cloth · Enchanting · Cooking · Fish & Lures · Quest · Housing · Pets & Mounts & Toys · Teleports & Tools · Reagents (only when "reagent bag separate" is on) · Junk · Other · Free.

The wizard's playstyle hides or reorders these (e.g. "Gold" promotes Trade Goods and BoE gear; "Collector" adds Transmog/Collectibles sections when overlays arrive in v1.1).

### 7.7 Categories: data and evaluation

```lua
category = { id = "c_gear", name = L["Gear"], query = "gear", compiled = <runtime>,
             priority = 50, itemList = { include = { [itemKey] = true }, exclude = { ... } },
             displayOrder = 30, enabled = true, builtin = true, color = nil, icon = nil,
             source = "builtin" | "user" | "import" }
```

A category made by importing a share string (F20) is stored with `source = "import"`; so is one made from a pasted Baganator search (week 11). A user category's id is `u_<name>` (`_2`, `_3`... when taken), never one a category has or a deleted category had (AC20.4).

Assignment for one slot record:
1. Manual **exclude** lists are consulted first (an excluded item cannot land in that category).
2. Manual **include** lists, highest priority first.
3. Rules by `priority` descending, ties by `id` (deterministic; no `pairs()`).
4. **Tri-state rule:** evaluate rules in priority order; the first `true` wins; a `nil` **blocks**: the item is marked pending and goes to New (first open) or stays where it was (already open). Lower-priority rules are not consulted past a `nil`. Pending items are re-evaluated on `ITEM_DATA_LOAD_RESULT`/`GET_ITEM_INFO_RECEIVED` (through `Inventory` reason `LOADED`), and move only at the next open or Reflow.
5. Fallback: Other.

### 7.8 Cache classes and memoization (resolves critique Issue 5)

Every keyword declares a class. A compiled query's class is the strongest class of its keywords:

| Class | Key | Memoized? |
|---|---|---|
| `static` | `itemID` | yes, per (compiledId, itemID) |
| `instance` | full hyperlink (covers caged pets 82800 with `battlepet:` links, keystones with `keystone:` links, bonus IDs, bind state via `IsBound` folded into the key as a suffix) | yes, per (compiledId, link + bindSuffix) |
| `volatile` | — | **never**; re-evaluated every pass |

The categorizer's per-item memo is keyed by the category set's strongest class; a category set containing any volatile rule degrades only those rules to per-pass evaluation, not the whole set (rules are evaluated individually, memoized individually). Memo tables are bounded (4,000 entries, LRU by insertion order) and dropped whenever any category changes. Nothing memoized is ever persisted.

### 7.9 Validation

`Validate(compiled)` runs the closure tree with three synthetic leaf behaviours — all leaves `true`, all `false`, all `nil` — and asserts the combinators return without error and produce a value in `{true,false,nil}`. It also walks the AST for unknown keywords (flagged as text), operators without numbers, and empty groups. Results are shown in the editor before save. Week 11: Save runs `Validate`, and the editor's preview lists every warning, not only the first.

### 7.10 Error display

Parse errors return `{position, expected, got}`. The search box underlines the span in red and shows "Expected a value after `>` at character 12". The rule builder marks the row. A category that fails to compile is saved with `enabled = false` and `error = "..."`, is marked in the list with **text**, `(off: its rule has an error)`, not a warning triangle (week 11: no icon to depend on), and never affects other categories. A category whose saved change has an error while its rule before it stays in use reads `(your change has an error: the rule before it is used)`. "The rule builder marks the row": a row with an empty value, a quote in a name or a non-number shows a note under it; a rule with an error opens as text with its error.

---

## 8. Data model and SavedVariables

### 8.1 Files

- `SwagBagDB` (account-wide, `## SavedVariables`): settings, categories, modes, snapshots for all characters, warband snapshot.
- `SwagBagCharDB` (`## SavedVariablesPerCharacter`): per-character overrides and per-character UI state only (window positions, collapse state). The setup-done flag is account-wide: `settings.setup.done` in `SwagBagDB` (this machine's state, never shared by a profile or share string).

### 8.2 Schema (v1)

Note: the category fields (`categories`, `categoryOrder`, user edits) arrive in schema 2; the block below shows the overall shape.

```lua
SwagBagDB = {
  schemaVersion = 1,
  settings = { ... defaults overlaid ... },
  categories = { [id] = category },        -- §7.7, without `compiled`
  categoryOrder = { "c_new", "c_keystone", ... },
  modes = { [id] = mode },                 -- §6.1
  modeOrder = { ... },
  consumableWatch = { { itemID = 191380, threshold = 5 }, ... },
  chars = {
    ["Name-Realm"] = { class = "MAGE", level = 80, lastSeen = 1790000000, race = ..., faction = ...,
                        bags = snapshot, bank = snapshot, money = copper, professions = { ... } },
  },
  warband = snapshot,                      -- one for the account
  errors = { ring of last 10 {time, build, version, message, stack} },
}
-- Week 7 (schema stays 2; every one read defensively, a damaged value reads as empty):
--   locks = { [itemID] = true }, profiles = { [name] = { settings, saved } }, profile = "name" (shown only),
--   backups = { profile = one step of undo, locks = the set the last Unlock all removed }, notes = { lockedKeyword = true }
-- and the settings vendor.autoSell, vendor.repair, prices.worth, prices.worthGold, prices.worthTop,
-- overlays.learn, overlays.lock, overlays.uncollected.
-- Week 9 (schema stays 2, only explicit values stored, share-string words in Profiles.VALID):
--   sort.mode = "blizzard" | "stacks", prices.source = "auto" | "auctionator" | "tsm" | "vendor",
--   prices.tsm = "DBMarket" | "DBMinBuyout" | "DBRegionMarketAvg" | "DBRegionSaleAvg", bags.warnOtherAddons = true.
-- Week 10 (schema stays 2): locks.warn = true (explicit default; a boolean in share strings).
-- Week 11 (schema stays 2, no new key): the category editor writes categories, userEdits and categoryOrder only,
--   with two optional values inside them, read defensively: a category's draft (a change of its rule saved with an
--   error while the rule before it stays in use) and categories[id] = false (a deleted user category: its id is never
--   given again). backups.profile drops its categories part when they change after an import (AC20.5).
-- Week 12 (schema stays 2, no migration, all read defensively): settings.setup.styles (a string such as "mplus,gold", written
--   at Finish; under setup, like setup.done, so profiles never save, load or share it); SwagBagDB.modes[id] = { name, trigger, n }
--   or false (a deleted mode: its id is never given again; damaged entries skipped, an unknown trigger reads as manual, ten at
--   most); a mode of your own's focus.on.<m_id> and focus.sections.<m_id> are ordinary settings.
SwagBagCharDB = { schemaVersion = 1, overrides = { ["modes.enabled.mplus"] = false, ... },
                  ui = { positions = {}, collapsed = {} } }
```

### 8.3 Snapshot format

```lua
snapshot = { v = 1, at = <epoch>, containers = {
  [bagID] = { size = 36, s = "1:|cff...|Hitem:191380::::::::80:::::|h[Healing Potion]|h|r;5\n7:...;1\n" } } }
```

One string per container: `slot:link;count\n` lines, full hyperlinks, no derived values (ilvl, quality, type are recomputed from the link when displayed, which survives squishes and API changes). Links are stored verbatim so caged pets, keystones and bonus IDs round-trip. A link that an earlier slot of the same container holds is written once, as `slot:=thatSlot;count` (D21); `Deserialize` reads both forms, `v` stays 1 and the schema stays 2.

### 8.4 Size budgets (from measured numbers)

Measured: ≈22 KB per character with full links (bags + character bank), ≈2.2 KB aggregated. Warband bank ≈ 490 slots; budgeted at 30 KB.

| Item | Budget |
|---|---|
| Per character | ≤ 30 KB (22 KB measured + 35 % file overhead) |
| 25 characters + warband + settings | ≤ 900 KB |
| Hard cap | 1.5 MB: when exceeded, the oldest-seen characters' bank snapshots are dropped first, with one chat line and a "manage snapshots" button |
| Warning | at 1 MB: Settings → Alt data shows a size bar and per-character delete buttons |

Open: the 30 KB per-character aim and the warband budget are not promised; the `=slot` form (D21) and the report's `Snapshot sizes` line exist to measure them, in session TF1.

Decision: full links (needed for the offline view and ilvl overlays). Aggregated counts are derived at load into an in-memory index (`itemID → {char → count}`) and never stored.

### 8.5 Schema versioning and migrations

- `schemaVersion` on both DBs. On load: if `db.schemaVersion > CURRENT`, SwagBag refuses to touch the DB, prints "SwagBag: settings are from a newer version; update the addon or type /swagbag reset", and runs in Safe Mode. If lower, migrations `M[v]` run in sequence inside `pcall`; a failed migration backs the DB up to `SwagBagDB_backup_v<N>` and resets to defaults with one chat line. This addresses the research complaint "categories lost on reload".
- Built-in categories and modes are **not** stored unless the user edits them (store a diff: `userEdits[id] = {...}`); so a new default set in an update applies cleanly, and "Reset to default" removes the diff.
- SavedVariables persist only on reload/logout (measured); the wizard and settings UI remind the user with "Saved on logout/reload" the first time.

### 8.6 Uninstall and rollback

- Disabling SwagBag returns the user to unmodified Blizzard bags with no residue (we hook via `hooksecurefunc` guarded by `enabled`, reparent only while loaded, and restore on `PLAYER_LOGOUT` as well).
- Downgrading one minor version is safe because migrations are additive and the newer-schema guard prevents corruption. One caveat (accepted, week 6): version 0.5.0 reads a repeated stack written in the `=slot` form (§8.3) as an unknown item until the snapshot is saved again.
- `/swagbag reset` (with a confirmation popup) wipes both DBs after a backup copy.

---

## 9. Performance budgets and event handling

| Budget | Target | Mechanism | Evidence |
|---|---|---|---|
| Idle CPU, windows closed | 0 ms/frame; no `OnUpdate` anywhere | `BAG_UPDATE` → dirty bits only; signal handlers O(1) | spike F handler costs |
| Button pool creation at login | ≤ 150 ms total, ≤ 10 ms per 100 | create all at login behind the loading screen; grow out of combat | 1,290 in ≈55 ms, worst 100 = 4.3 ms |
| First bag open (≈210 slots) | ≤ 25 ms, frame hidden until layout completes | full layout + categorize memo | grid 212 buttons measured well under bank's 60 ms |
| First bank open (≈700 slots) | ≤ 80 ms, hidden until complete (open: measured in session TF1 with the report's `Last bank layout` and `Bank layout parts` lines) | same | 702 buttons in 60 ms |
| Warm open | ≤ 10 ms | memo + stored layout | — |
| Incremental update (one `BAG_UPDATE_DELAYED`) | ≤ 5 ms for ≤ 10 changed slots | diff only | spike incremental |
| Reflow after sort | ≤ 40 ms | full layout; sort moved 195 items in the spike | — |
| Search keystroke | ≤ 4 ms after 150 ms debounce | compiled query + memo | — |
| Focus switch | ≤ 5 ms | header restack | — |
| Lua heap | ≤ 25 MB total (pool is 13.6 MB measured) | bounded caches | — |
| SavedVariables | §8.4 | — | measured |
| Auctionator lookups | ≤ 0.01 ms/call, ≤ 2 ms per layout | session cache per link | 0.005 ms measured |

Event policy:
- `BAG_UPDATE(bag)` → mark dirty. `BAG_UPDATE_DELAYED` → flush once (debounce 50 ms); failsafe `C_Timer` 250 ms if DELAYED never follows.
- `ITEM_LOCK_CHANGED(bag, slot)` → repaint that button (`LOCK`).
- `BAG_UPDATE_COOLDOWN` → cooldown repaint of visible buttons only; never a rescan.
- `ITEM_DATA_LOAD_RESULT` / `GET_ITEM_INFO_RECEIVED` → `LOADED` for pending keys.
- `PLAYER_EQUIPMENT_CHANGED` → invalidate `equipped`/`upgrade` memos.
- `BANKFRAME_OPENED/CLOSED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYERBANKBAGSLOTS_CHANGED`, `BANK_TAB_SETTINGS_UPDATED` (feature-detected; registered via `pcall(frame.RegisterEvent)`) → bank model.
- `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` are logged for diagnostics only (the manager still exists in 12.1, verified); week 10 also reads them for the scrapper (open between SHOW and HIDE of its interaction).
- Week 10 (lock warnings, all under "none"): `DELETE_ITEM_CONFIRM` (one chat line and SwagBag's note for a locked item; the note goes on `ITEM_LOCK_CHANGED` / `BAG_UPDATE_DELAYED`, no `CURSOR_CHANGED` listener) and `SCRAPPING_MACHINE_PENDING_ITEM_CHANGED` (one chat line per locked item landing in a slot, only while the scrapper is open).
- Secret values: every read from `C_TooltipInfo` is wrapped; `issecretvalue()` → `nil`. The collections' draw path treats a secret link or name as no answer (no glow, no star, no error); a secret link is never a table key (week 8); nor is a secret item ID: it has no price, nothing is cached under it (week 9).
- Combat: no `CreateFrame`, no `EnsureCapacity` growth, no physical sort, no snapshot writes; everything else proceeds (verified legal). Plain frames (no secure template) may be created in combat: the delete note is one, made at `SB_LOGIN` through `SB.OutOfCombat`.

`/swagbag perf` prints last open/layout/search timings and memo hit rates (P2: always prints something).

---

## 10. Safe Mode, diagnostics, error capture

### 10.1 Safe Mode mechanics (proven in spike S)

- Suppression method: `HookScript("OnShow", Hide)` on `ContainerFrame1..NUM_CONTAINER_FRAMES` and `ContainerFrameCombinedBags` while `SafeMode.IsOn("bags") == false`; plus `hooksecurefunc` on `ToggleAllBags`, `ToggleBackpack`, `OpenAllBags`, `CloseAllBags` that open/close SwagBag's window only while SwagBag is active. The hooks check a flag; flipping the flag is the toggle. Verified: live toggle in and out of combat with no blocked actions. Not yet verified: item use from Blizzard bags in combat after a toggle (check V3, §11.3).
- Who opened the window decides (D16): a window the user opened (B, a bag icon) is closed only by the user (B, Esc, the X); no `CloseAllBags` closes it, with a frame or without one. A window the game opened (its open call named a frame) closes with that frame's `CloseAllBags`, or with one that names no frame; when the open call named no frame, any `CloseAllBags` closes it. A bag toggle that runs inside a frame's `CloseAllBags` and closed the user's window opens it again in the same frame; `CloseAllBags()` with no frame inside the bag key itself changes nothing. The last five hook calls are in `/swagbag report` (`Bag hooks (last 5)`).
- Bank: Safe Mode for the bank restores `BankFrame` and `TabSystem` parents (deferred to out of combat if necessary — reparenting Blizzard's bank frame in combat is the one thing we did not test) and stops opening SwagBag's bank window.
- Per window: `bags` and `bank` have independent Safe Mode flags.

### 10.2 Auto-fallback

Every entry point from WoW into SwagBag (event handlers, hooks, OnClick of our own non-secure buttons, timers) runs inside `ErrorTrap.Guard(label, fn)`. On error: record `{time, label, message, stack}` into the ring buffer (memory + `SwagBagDB.errors`), set Safe Mode for the window whose path failed (or both if unknown), print exactly one line per session per window: *"SwagBag hit an error and switched to Blizzard bags. Type /swagbag report."* Further errors in Safe Mode are recorded silently. `/swagbag safe off` re-enables with confirmation; if the next refresh errors again within 10 s, it says "Still failing — stay in Safe Mode and send the report."

### 10.3 Feature checks

`Checks.Run()` at login (and via `/swagbag check`) verifies: every required API path (list from spike H: `C_Container.*`, `C_Bank.FetchPurchasedBankTabIDs`, `C_Item.*`, `BankFrame.GetActiveBankType`, `BankFrame.TabSystem`, `ContainerFrameItemButtonMixin`, `SetItemButton*`, …), enum values (`Enum.BagIndex`, `Enum.BankType`, `Enum.AddOnRestrictionType`), and the frames we hook. A failed required check turns on Safe Mode for the affected window before anything is shown and lists the failures in the report. Optional checks (Auctionator, Syndicator, `C_ChallengeMode`, profession APIs) only degrade features. Week 10 adds four optional checks: `SpellIsTargeting`, `StaticPopup_FindVisible`, `C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex`, `C_Item.GetItemID`.

### 10.4 `/swagbag report`

Opens a frame with a read-only multi-line EditBox (select-all on focus, Ctrl+C) containing:

```
SwagBag 1.0.3 | WoW 12.1.0 (69933) | enUS | 2026-11-14 21:03
Safe Mode: bags=off bank=on (auto, 21:01)
Failed checks: BankFrame.TabSystem (missing)
Errors (last 10):
 21:01:12 Views.Bank.Refresh: attempt to index nil 'TabSystem' <stack 6 lines>
Bag-related addons: Auctionator 12.1.3, Syndicator (not loaded), ElvUI 14.02 (bags off)
Settings hash: 7f3a…  Categories: 21 (3 user)  Modes: 6 on
Season data: crest currencies ...; season items in bags ...   (week 7: confirms the season's IDs; a failure reading it prints "unavailable" and never blanks the report)
```

Week 10 adds `Locks: N locked; destroy warnings on|off`. Week 9 adds `Other bag addons on: <names> | none`, `Masque: N buttons skinned` and `Prices:` naming TSM's string (`TSM (DBMarket), N cached`). Another bag addon on at login gives one chat line (silent in Safe Mode or with `bags.warnOtherAddons` off; `/swagbag otherbags [on|off]`); it is never disabled; UI suites' bag modules are not detected (ElvUI only while its own bags are on).

This is what the user pastes into Claude Code. BugGrabber/BugSack compatibility: if present, we do not install our own `seterrorhandler`; we read errors through our own `Guard` wrappers only.

### 10.5 Slash commands (all with feedback, P2)

`/swagbag` (opens settings), `help`, `setup`, `tour`, `safe [on|off|bags|bank]`, `report`, `check`, `perf`, `reset`, `mode [pause|resume|list|style [front|collapse]]`, `snapshot` (prints snapshot ages), `search <query>` (applies to the open window and reports match count); week 7: `sell [on|off|junk]`, `repair [own|guild|off]`, `lock [list|clear|undo|warn [on|off]]` (clear asks first; one lock is answered in the singular; `warn` says or switches the destroy warnings), `worth [<gold>|top <percent>|off]`, `profile [save|load|delete <name>|reset|undo|export [categories]|import]`, `overlays` (learn, lock, uncollected added); week 9: `sort [stacks|blizzard]`, `price [auto|auctionator|tsm [<price>]|vendor|string <price>]`, `otherbags [on|off]`; week 11: `settings categories` opens Settings > Categories; week 12: `setup` runs the wizard, `tour` runs the tour, `mode on <name>`, `mode off [<name>]` switch the modes of your own that you switch by hand.

---

## 11. Testing strategy, CI, packaging

### 11.1 Unit tests (busted)

- `Query`: ≥ 150 cases: every keyword, precedence, quoting, errors with positions, tri-state tables, `Validate`, round-trip through `Pretty`, 20 Wago/Baganator strings from desk spike F.
- `Categorizer`: priorities, item lists, exclude-before-include, `nil` blocking, memo classes (static/instance/volatile), caged pets and keystones by link, determinism (shuffled input → same output).
- `Layout`: placeholder transitions for every row in §4.3; hover guard deferral; New overflow; collapse/expand returns same cells; scroll clamp math; 1,290-slot fixture ≤ 20 ms in plain Lua.
- `Focus`: signal → active set; merge vs. strict; peek/pin lifecycle; custom modes; gathering allowlist (chest spell → no).
- `Snapshots` + `Config`: serialize/deserialize round-trip for pets/keystones; migrations v0→v1 and a synthetic v1→v2; newer-schema refusal; size accounting.
- `Prices`/`AltData`: provider priority, failure disablement after 3 errors.
- Benchmarks (not asserted in CI, printed): compile, evaluate 1,290 records, layout.

### 11.2 Static checks

luacheck with a WoW globals `std` (read-only list of API globals) and `globals = {"SwagBagDB", "SwagBagCharDB"}`; custom CI grep failing on the forbidden tokens from §5.3 (and, from week 7, on a bare `C_*` name outside `SwagBag/Core/Adapter.lua`, the only file that may name a `C_*` namespace, `Enum` or another addon's globals; from week 9 also `TSM_API` and `LibStub` as a word, comments included); `luac -p` on every file; a TOC/file-list consistency check.

### 11.3 In-game verification checklist (first in-dev checks, in this order)

Run through `/swagbag check` plus a scripted guide (reuse the spike's guide framework pattern, written fresh for SwagBag).

| # | Check | Pass criterion | Fallback if it fails |
|---|---|---|---|
| V1 | `SetBagID()`-attribute buttons use items in combat | 3 uses from attr buttons in combat, no block | Stay on per-bag parents (shipped default) |
| V2 | Deposit while Blizzard bank is in tiny mode; Hearthstone afterwards | lands in active tab type; hearth works | `bank.blizzardFrame = "beside"` becomes default |
| V3 | Item use from Blizzard bags in combat after Safe Mode toggles | no block | Safe Mode toggle deferred to out of combat (auto-fallback still hides ours immediately) |
| V4 | Placeholder click is harmless | tooltip only, no use, no pickup | make placeholders `EnableMouse(false)` (lose the tooltip) |
| V5 | M+ detection and layout ops during ChallengeMode restriction | mode switches on key start; no blocks | fall back to `instanceType == "party"` + keystone present |
| V6 | Fishing detection by channel spell and `IsFishingLoot` | mode on within 1 s of cast | name match / loot-only |
| V7 | Delve detection | mode on inside a delve | difficulty-ID table |
| V8 | Gathering allowlist | herb, ore, skin trigger; chest and archaeology do not | tighten list |
| V9 | Auto-fallback in combat | injected error (`/swagbag debug error`) flips to Blizzard bags mid-combat; item use works | — |
| V10 | Snapshot sizes for the user's real characters | ≤ budget §8.4 | adjust budget or drop bank snapshots for low-level alts |
| V11 | Consumables warning on key start and on portal use | one line, correct counts | — |
| G1 | Guild bank: withdraw, deposit, tab switch, Hearthstone afterwards, at a guild vault | items move correctly; no blocked actions; hearth works | `guildBank.mode = "view"` (read-only window + Blizzard frame beside) |
| V12 | No item moves while open: loot, use, vendor, split, drag to bank, sort | zero `noWrongItemInSection` violations | — |

Each check is re-run before every release on a tagged "release checklist" guide. V1–V4 run in the first week of M1/M4 respectively.

### 11.4 Patch-day procedure

1. User logs in; if Safe Mode triggered, pastes `/swagbag report` into Claude Code.
2. Claude updates `Checks`/`Adapter`, bumps TOC, runs busted + luacheck, tags.
3. CI packages and uploads to CurseForge as a beta; user verifies with the release checklist; promote to release.
Target: a fix within 48 hours of a breaking patch; the addon stays usable (Blizzard bags) in the meantime.

### 11.5 CI and packaging

GitHub Actions on push: luacheck, busted, forbidden-token grep. On tag `v*`: BigWigs packager → CurseForge (project created first), GitHub release with changelog from `CHANGELOG.md`. Wago added later with the same packager. The repository is private (all rights reserved); CurseForge receives the packaged zip only. TOC metadata: `## X-License: All Rights Reserved`, `## OptionalDeps: Auctionator, Syndicator`, `## SavedVariables: SwagBagDB`, `## SavedVariablesPerCharacter: SwagBagCharDB`, `## IconTexture:` our own icon.

---

## 12. Roadmap

**Target set by the user (2026-09-30): a daily-driver build by 2026-10-31**, with the user testing in-game every day. Publishing on CurseForge follows in November after the rule builder, full wizard/tour and offline alt view land and the publish bar (§2.4) is met.

### 12.1 October build (daily driver) — what is in and out

| In (by Oct 31) | Deferred to November (v1.0 publish) |
|---|---|
| F1 bags, F2 bank + warband, **F16 guild bank (full, with view fallback)**, F3 category + grid + collapse, F4 default categories + drag-to-assign, F5 search, F8 six core focus modes (+ pause), F9 overlays incl. upgrade arrow, F10 Auctionator totals, F11 consumables warning, F12 Safe Mode + report, F14 Blizzard look, F15 simple settings, a **one-screen quick setup** (playstyle → preset), **F6 visual rule builder** (moved in: delivered in week 11, v0.11.0), **F7 full wizard + interactive tour** (moved in: delivered in week 12, v0.12.0, with AC8.7 and AC9.2) | F13 offline alt bags/banks view and tooltip alt counts (bank snapshots are still *captured* in October so data exists when the view lands) |

### 12.2 Schedule (daily testing; each week ends with a working build)

| Week | Dates | Milestones | Daily in-game checks | Exit criteria |
|---|---|---|---|---|
| 1 | Oct 1–7 | M0 foundations (repo, CI, Adapter, Checks, Config, ErrorTrap, report) · M1 button pool + grid bags + Safe Mode · M2 query engine (busted, parallel) | V1, V3, V4, V9 | User plays with SwagBag grid bags + search all day; Safe Mode proven |
| 2 | Oct 8–14 | M3 categorizer + default categories + sections layout + placeholders/New/Free + collapse + drag-to-assign + sort/reflow | V12 every day | Category view is the user's default bag; no item ever moves under the cursor |
| 3 | Oct 15–21 | M4 bank + warband (V2 first day) · **M4G guild bank (G1 first day)** · M6 overlays + upgrade arrow + Auctionator totals | V2, G1, overlay spot-checks | Bank and guild bank used for real; fallback decided by day 2 if a check fails |
| 4 | Oct 22–28 | M5 focus modes + signals + pause + consumables warning · quick setup screen · settings pages | V5–V8, V11 in real keys, delves, raid, fishing, gathering | Modes switch correctly in real play |
| 5 | Oct 29–31 | Hardening: bug fixes from the month, perf pass (§9 budgets), patch-day drill | full checklist | **Daily driver: zero Lua errors for 3 consecutive days** |

The bank-speed part 2 (week 6) is scheduled after session TF1's numbers come back.

### 12.3 November → v1.0 on CurseForge

M7 rule builder + full wizard + tour (≈2 weeks) · M8 offline alt view + tooltip counts (≈1 week) · M9 publish bar: 2 weeks daily-driving incl. M+ with zero errors + 3 friends/guild testers for a week (overlaps M7/M8 where possible). **Realistic publish: early-to-mid December 2026.**

**Honest risk on the October date:** it holds only if the four first-day checks (V1–V4, V2, G1) pass or their fallbacks are accepted within a day, and if 12.1.5 does not land mid-month. Each failed check without a quick fallback costs about 2–3 days. Claude will report schedule slip at the end of each week, not at the end of the month.

---

## 13. Risks, mitigations, open items

### 13.1 Risks

| Risk | L / I | Mitigation |
|---|---|---|
| Taint from an unforeseen path blocks item use in combat | Low (spikes passed) / Critical | Per-bag-parent construction; forbidden-token CI; V1/V3/V9 checks; auto-fallback works in combat |
| Tiny-mode deposit fails (untested) | Med / High | V2 is the first bank check; "beside" fallback is a settings default switch, not a redesign |
| Placeholder/slot identity confusion → wrong item used | Low / Critical | Contract §4; invariant check in debug builds; V4, V12 |
| 12.1.5 removes/renames an API mid-build | High / Med | Adapter + Checks; Safe Mode; 48 h fix loop |
| Focus-mode false positives annoy users (mode flips while browsing) | Med / Med | Decays on fishing/gathering signals; "Pause modes" one click; announce off by default; every mode editable |
| Gathering allowlist incomplete per expansion | Med / Low | Data file; `/swagbag report` includes last 5 loot spell IDs when gathering detection is suspected |
| Rule builder UI is too large for M7 | Med / Med | Ship keyword picker + text with validation first; nested groups second; both in M7 but ordered |
| SavedVariables bloat on many alts | Low / Med | Measured budget; cap + purge UI |
| Schema migration bug loses categories | Med / High | Backup before migrate; diff-based built-ins; newer-schema refusal; busted migration tests |
| A share string or a profile Undo overwrites the user's categories (week 11) | Med / High | An import never replaces a user category or revives a deleted id (AC20.4); Undo brings categories back only if nothing changed them since (AC20.5); an export leaves out a rule an import would refuse and names it (AC20.3) |
| Baganator's gold amounts differ from SwagBag's (week 11 paste) | Med / Low | Compared per item with SwagBag's price (auction, else vendor), said in the paste view; checked in-game (G6) |
| Other addons touching our buttons (CanIMogIt, Pawn, TSM) | Med / Low | Buttons are standard `ContainerFrameItemButtonTemplate`; we expose nothing special; overlays in our own frame level |
| Secret values poison tooltip-derived collection overlays (v1.1+) | Med / Low | `issecretvalue()` → `nil`; overlay hidden |
| Developer loop stalls (user availability) | Med / High | Milestones are testing-sized; Claude prepares scripted guides so each evening is productive |
| Guild bank full replacement taints or breaks (12.1 changed guild bank opening; Bagnon reported breakage) | Med / Med | G1 on day one of week 3; `view` fallback is a setting; never write Blizzard guild bank state |
| October date slips | Med / Med | Week-by-week exit criteria; slip reported weekly; deferrals already moved to November |
| 12.1.x renames Blizzard's delete box, or changes the scrapper's events or slot numbering | Low / Low | Delete box: only the chat line comes, no error. Scrapper: the tooltip line only. Both under "none" |
| Blizzard ships native category bags | Low / High | Focus modes, gold features and setup ease remain differentiators |

### 13.2 Open items (to be resolved during the named milestone)

1. ~~Desk spike F: exact Syndicator semantics of `#`, `gear<N`, and whether adjacent words are phrase or AND; update §7.5 (M2).~~ Resolved 2026-10-01: see §7.2, §7.5 and `docs/research/2026-10-syndicator-grammar-diff.md`.
2. Delve detection API (`C_DelvesUI` / difficulty IDs) — V7 (M5).
3. M+ teleport spell ID list source (data file; Blizzard dungeon teleports by season) (M5).
4. Crest/upgrade-currency item IDs per season (data file) (M6). Week 7 adds season items (Ascendant Venomstone 280562, to be confirmed in session SN1) and profession knowledge items to the same data file.
5. Whether reparenting `BankFrame` back to `UIParent` is legal in combat; until tested, restoration is deferred to out of combat (M4).
6. Exact `BANK_TAB_SETTINGS_UPDATED` event name/signature on tab purchase (feature-detected registration) (M4).
7. CurseForge project slug and icon (M9).

---

## 14. Decision log

| User decision | Implemented in |
|---|---|
| Opinionated default + easy-to-find alternative | §1.4 P1; every settings page §2.1 F15; §6.1 peek/pin; §6.1 merge/strict |
| Every command/button gives feedback | §1.4 P2; §10.5 |
| Ease of setup over power | §1.4 P3; §2.1 F7 wizard/tour; Pat behind "Advanced" §1.5 |
| No hard dependency on other addons | §1.4 P4; §3.3 provider interfaces |
| Public release, user daily-drives first | §2.4 publish bar; §12 M9 |
| Name SwagBag; CurseForge first, Wago later | §11.5; §2.3 |
| Retail only, English only, strings in one table, keyword matching locale-safe | §1 header; §1.4 P8; §7.3 registry |
| All rights reserved, clean-room | §1 header; §11.5 private repo |
| Category sections default + grid toggle; collapsible | §2.1 F3; §4 |
| List view, per-bag, freeform later | §2.2 v1.3; §2.3 |
| Focus modes: automatic, peek default / keep-open option, merge default / strict option, all ON, custom modes, full built-in list | §6 |
| Gathering via spell-ID allowlist; restriction API signals | §6.2 |
| Wizard + optional tour; visual rule builder; drag onto header | §2.1 F6, F7; §7.10; §2.1 AC4.3 |
| Syndicator-compatible syntax, own implementation; categories {query, priority, itemList}; manual before rules; priority ≠ display order | §7.1, §7.7 |
| Critique grammar/cache fixes: precedence, errors, tri-state blocking, cache classes, full-link keys, squished ilvl examples | §7.2, §7.4, §7.7 step 4, §7.8, §7.10 |
| Auctionator prices, per-category totals, worth-money rule (100 g default / top-X %), no own scanning; send-to-alt scrapped | §2.1 F10; §2.2 v1.1; §1.3 |
| M+: consumables top, keystone level/dungeon, ilvl/track, crests, consumables warning on entry and portal | §6.3 M+; §6.6; §2.1 F9, F11 |
| All overlays available, real APIs | §2.1 F9; §2.2; §1.4 P7 |
| Guild bank: full window replacement in v1.0, view+search fallback | §2.1 F16; §11.3 G1; §12 |
| Daily-driver by 2026-10-31, user tests daily; publish after (Nov) | §12 |
| Upgrade arrow moved into v1.0 (spec review) | §2.1 AC9.1, AC9.3; §12 M6 |
| Blizzard-like default look; themes later; ElvUI auto-detect | §2.1 F14; §2.2 v1.3 |
| Account-wide settings with per-character overrides | §8.1, §2.1 F15 |
| Syndicator if installed, else own compact store; bank snapshot every visit; offline view for all alts | §3.3; §8.3; §5.7; §2.1 F13 |
| Bank: both banks stacked, Blizzard tiny mode, real tab buttons re-hosted, deposit follows Blizzard, highlight target, never SetTab; fallback beside | §5 |
| Breakage: auto Safe Mode + one line + `/swagbag report` | §10 |
| New section on top; join real category on next open; layout never moves under cursor | §4.3; §2.1 AC3.3–3.4 |
| (Week 9) A new item stays in New in every mode until hovered, then joins its category at the next open | §2.1 AC3.3; §4.3 |
| (Week 9) TSM as a price source, user's choice of source; Masque skins; stack partial stacks first | §2.1 F10, AC2.7; §5.5; §4.1 |
| Reagent bag mixed by default, option separate | §2.1 AC1.4 |
| Release tiers v1.0 / v1.1–1.3 / later; publish bar | §2 |
| Spike GO/NO-GO results drive the design; untested items are first checks with fallbacks | §4, §5, §11.3 |

### Appendix A — Critique issues and where they are resolved

| Critique issue | Resolution |
|---|---|
| 1 Secure-button vs layout model (blocker) | §4 contract; per-bag parents proven; placeholders separate; Free of real buttons; scroll child; combat table |
| 2 Safe Mode and bank asserted, not designed (blocker) | §10.1 proven suppression; §5 one window driven by Blizzard tabs; read-only `GetActiveBankType`; ESC §5.6; auto-fallback in combat proven |
| 3 MVP too large, v1 hides multi-month work | §12 sized milestones with a calendar; rule builder ordered inside M7; importers cut to paste-string |
| 4 Importers and grammar "close by assertion" | §7.1 compatibility stance + desk spike F; §7.5 divergences; no SavedVariables importers |
| 5 Memo key wrong for volatile keywords; nil semantics | §7.8 cache classes; full-link keys; §7.7 step 4 nil blocks and item stays put |
| 3.1 Forever | Out of scope by decision |
| 3.2 Differentiation | §1.1–1.2: focus modes, setup, gold, reliability |
| 3.5 Missing events; creation cost | §9 event list; measured 55 ms |
| 3.6 Implicit AND / phrase; localization; pre-squish examples; Validate nil pass; `cat:` | §7.5 (1); §7.3 registry + P8; §7.4; §7.9; `cat:` not in v1.x |
| 3.7 `/swagbag taint` cannot read logs | Replaced by `/swagbag check`, `report`, and the ADDON_ACTION_BLOCKED listener in the in-game checklist |
| 3.8 Pending moves; dead placeholder rows; drag/modifier guard; time-sliced first render | §7.7 step 4; §4.3 (reflow on close, New overflow); §4.2 rule 5; §9 hidden until complete |
| 3.9 Storage budget misread; runtime memory; schema versioning | §8.4 measured budgets; §9 Lua heap stated; §8.5 |
| 3.10 Report command; uninstall/rollback | §10.4; §8.6 |
| 3.11 Riskiest unknowns first | §11.3 V1–V4 in M1/M4 |
| 3.12 Missing risks | §13.1 |
| 4.1 Consume Syndicator | §3.3: Syndicator preferred when present (v1.2), own store default |
| 4.2 Syndicator-compatible syntax | §7.1 adopted |
