# SwagBag Feature Gap Research (2026-10-03)

Scope: features other bag addons and bag-adjacent addons offer that SwagBag (main 0.5.0 + week 6 + planned/later list in `swagbag-features.md`) neither has nor plans. Ideas only. No code was read or copied (SwagBag is all-rights-reserved, so GPL code must not be reused). Builds on `bag-addon-landscape.md` (2026-09-30), which is not repeated here.

Confidence key: [V] = stated on the addon's own CurseForge/GitHub page fetched 2026-10-03. [S] = search-snippet only. [?] = inference or unverified. Popularity numbers are CurseForge download totals as reported on 2026-10-03 pages or the earlier landscape file.

## 1. Top 10 highest-fit gaps (ranked)

1. **Item lock / favorites (protect from sale, DE, destroy, sort)** - High. Five separate addons exist just for this, and Sorted. and GudaBags build it in.
2. **Auto-sell junk + auto-repair (with safe rules)** - High. Baganator integrates 4 junk sellers, so ex-Baganator users expect it. SwagBag only shows a junk coin overlay.
3. **Header bulk actions (vendor / mail / bank / destroy a whole section)** - High. Baganator's Transfer button and BetterBags' right-click headers do this; it is what makes categories useful for gold-makers.
4. **Equipment-set awareness (set category, set icons, auto-protect set gear)** - High. M+ players swap sets constantly; Baganator, Sorted., LiteBag, GudaBags, ElvUI_BagCategories all handle sets.
5. **Window layout controls (columns, icon size, scale, resize, lock position)** - High [?]. This is table stakes for switchers; the feature list does not mention it, so verify it exists.
6. **Pinned / tracked item bar (consumables, quest items) outside the bag window** - Medium-High. GudaBags ships a Tracked Item Bar and a Quest Item Bar. It fits the focus-mode idea (keep pots/flasks one click away in M+).
7. **Settings profiles + category/config export-share** - Medium-High. BetterBags and GudaBags have profiles and import/export; Baganator has a Wago category marketplace. SwagBag plans import only.
8. **Warband-bank tools: gold deposit/withdraw, tab rename, item-type-to-tab assignment** - Medium-High. BetterBags has all three. It matters to warband gold-makers.
9. **More sort options (type / quality / expansion, partial stacks first)** - Medium. Baganator has multiple orderings; SwagBag only calls Blizzard sort.
10. **Alt data breadth: mail and AH contents, realm-wide gold, per-location tooltip breakdown** - Medium [?]. Syndicator, BagSync and GudaBags all track mail/AH. SwagBag's alt data scope for mail/AH is unspecified.

## 2. Full gap table

| # | Gap (one line) | Who has it (source) | Popularity / evidence | Fit | Why |
|---|---|---|---|---|---|
| 1 | Item lock/favorites: protect from vendor, DE, destroy; optional lock position vs sort | Sorted. (8 favourite icons) [V] https://www.curseforge.com/wow/addons/sorted ; GudaBags [V] https://www.curseforge.com/wow/addons/gudabags ; ItemLock (54K+ DL) [S], Item Locker (updated 2026-06-18, works with Baganator/ArkInventory) [V] https://www.curseforge.com/wow/addons/item-locker ; iGuard, Set Lock [S] ; Vendor safeguards https://www.curseforge.com/wow/addons/vendor | Many single-purpose addons plus Vendor's built-in Keep rules = clear demand; individual addons are small (1.7K-54K DL) | High | Gold-makers hold BoEs/transmog; one wrong vendor click is costly, and it pairs with auto-sell. |
| 2 | Auto-sell junk on merchant open + auto-repair (incl. guild repair) | Scrap (32M DL) [V] https://www.curseforge.com/wow/addons/scrap ; Vendor [V] ; Peddler [V] https://www.curseforge.com/wow/addons/peddler ; NDui infobar [S] ; GudaBags [V] ; ArkInventory [V] https://github.com/arkayenro/arkinventory ; Sorted. mark-trash [V] ; Baganator lists Dejunk/SellJunk/Scrap/Vendor integrations [S] https://www.curseforge.com/wow/addons/baganator | Scrap 32M DL is the strongest signal in this whole study | High | Everyone wants it; ex-Baganator users currently run a separate junk addon. Opinionated default: sell greys only, never uncollected transmog/BoE/sets. |
| 2a | Sell safeguards and visibility: tooltip says why item will sell, buyback-safe limit (12 at a time), audit log | Vendor [V] ; Peddler 12-item limit [V] | Vendor has shareable rules | Medium | Sub-feature of #2; cheap trust-builder. |
| 3 | Header/section bulk actions: right-click header to move/vendor/mail/scrap the group; transfer button | BetterBags [V] https://github.com/Cidan/BetterBags ; Baganator Transfer button (bulk move/vendor/mail/scrap) [V] | Baganator 38M DL; transfer is on its headline feature list | High | Section totals already exist in SwagBag headers; actions on the same header are a natural extension. Deposit-all-warbound (week 6) is a first instance. |
| 4 | Equipment-set categories/overlays/auto-protect | Baganator (set categories, set search) [V] ; Sorted. [V] ; LiteBag (up to 9 colored set icons) [V] https://www.curseforge.com/wow/addons/litebag ; GudaBags auto set protection [V] ; ElvUI_BagCategories via ItemRack [V] https://github.com/ludvigaf/ElvUI_BagCategories ; Outfitter via AdiBags module [V] | Present in nearly every major addon | High | SwagBag has ~18 categories; verify whether a set category exists, and add set icon + protection. |
| 5 | Layout controls: columns, icon size, scale, resize by dragging, movable/locked frames, snap | LiteBag [V] ; GudaBags (5-22 columns bags, 36 bank, icon/font size, opacity) [V] ; BetterBags column options [V] | Table stakes | High [?] | Not mentioned in the feature file; if missing, switchers will bounce on day one. |
| 6 | Pinned/tracked item bar and quest-item bar outside the bag | GudaBags Tracked Item Bar (Ctrl+Alt+Click) and Quest Item Bar [V] | Single-addon evidence (GudaBags is new; DL count not seen) | Medium-High | Maps to M+/Delves: keep health pot, flask, healthstone clickable without opening bags. Overlaps with the low-consumables warning. |
| 7 | Settings profiles + config/category export & share strings; marketplace | BetterBags (profiles, category import/export strings) [V] ; GudaBags (profiles import/export) [V] ; Baganator + Wago category imports [S] https://wago.io/browse/baganator (page would not load) | Baganator has an active Wago share scene (count not obtained) | Medium-High | SwagBag plans import from Baganator strings only; export and per-spec/char profiles let a streamer or guild share a setup and aid support (`/swagbag report` already exists). |
| 8 | Warband bank tools: gold deposit/withdraw, rename tabs, assign item types to tabs | BetterBags [V] ; LiteBag drag items to specific bank tabs [V] | Warband is new-ish; BetterBags 4.6M DL | Medium-High | Gold-makers move gold and mats across the warband all day; SwagBag already hosts both banks. |
| 9 | Own sort engine with selectable orders (type, quality, expansion), partial-stacks-first | Baganator (multiple ordering options) [V] ; Bagnon Sort API [landscape] ; BankStack/SortBags/tdPack2 as add-on sorters (Baganator integration list) [S] | Landscape file lists "partial stacks first for TSM" as an unmet want | Medium | Blizzard sort is fine for most; cost is high (taint risk), so keep it optional or LATER. |
| 10 | Mail and AH contents in alt data; realm-wide gold total; location breakdown in tooltip | Syndicator (bags, banks, mails, auctions, guilds, gold) [V] https://www.curseforge.com/wow/addons/syndicator ; BagSync (+void, tokens) [V] https://www.curseforge.com/wow/addons/bagsync ; GudaBags offline mailbox [V] | Syndicator 28M DL | Medium [?] | Gold-makers want to know what is in transit or on the AH; verify what SwagBag's snapshots cover. |
| 11 | Bulk mail to alts / Open-All mail / mail quick attach | GudaBags bulk mail (Shift+Right-click) [V] ; Postal (OpenAll, QuickAttach, Express, Rake) [V] https://www.curseforge.com/wow/addons/postal ; Baganator transfer-to-mail [V] | Postal is a long-time staple (DL not fetched) | Low-Medium | Send-to-alt mail was deliberately scrapped; keep scrapped. Open-All is Postal's job. Revisit only via #3 transfer-to-mail. |
| 12 | Auto open/close bags at vendor, mail, bank | GudaBags [V] | Single source | Low | SwagBag's AH/Vendor/Bank focus modes probably already cover this [?]. |
| 13 | Disenchant/mill/prospect quick action from the bag | TSM Destroying [S] https://support.tradeskillmaster.com/ ; ForeverForge (Ctrl+Shift+Click) [landscape] | TSM core module | Medium | Matches the planned Disenchant focus mode; a one-click button would make that mode real. Secure-action constraints apply. |
| 14 | Masque (button skin) support and icon-border/glow tuning | Baganator Masque [S] ; BetterBags glow intensity slider 0-100 [V] ; LiteBag thicker borders [V] | Niche but vocal | Low | SwagBag ships three themes already; Masque adds taint/maintenance surface. |
| 15 | Special-bag handling: sections for reagent/profession bags, empty-slot glyphs by bag family | Baganator sections for special containers [V] ; BetterBags empty-slot glyphs [V] | Minor | Low-Medium | Matters if players use profession bags; SwagBag has a single free-slot tile [?]. |
| 16 | Category management: hide/pin/disable categories, category groups/tabs, per-category title color | BetterBags [V] ; ElvUI_BagCategories drag-reorder + nested subcategories + running gold/slot counts [V] | Landscape: "category management that scales" is unmet | Medium | Pairs with the planned rule builder; at minimum hide/disable built-ins. |
| 17 | Catalyst/upgrade info in tooltip | CanIMogIt "can catalyze" [V] https://www.curseforge.com/wow/addons/can-i-mog-it ; Transmog Upgrade Master (Baganator integration) [S] | Niche | Low-Medium | Useful to crest-capped M+ players; tooltip-only and costly. |
| 18 | Missing enchant/gem warnings | Simple Item Level [V] https://www.curseforge.com/wow/addons/simple-item-level | Simple Item Level is widely installed (DL not fetched) | Low | Character panel concern, not bags. |
| 19 | Per-bag / split / freeform views | GudaBags split view [V] ; ArkInventory virtual bars [V] ; Baggins virtual bags [V] ; Sorted. grid toggle [V] | Niche | Low-Medium | Already in SwagBag LATER. |
| 20 | Pet/mount summon from bags | ArkInventory [V] | Niche | Low | Off-mission. |
| 21 | Hide items from tooltip counts (blacklist); professions/recipes across alts | BagSync [V] | Niche | Low | Nice for altoholics; not core to SwagBag. |
| 22 | Auctionator/TSM price source choice in bag | Baganator community plugin "Auctionator, TSM and Vendor price in Baganator" [S] https://www.curseforge.com/wow/addons/auctionator-tsm-and-vendor-price-in-baganator ; ElvUI_BagCategories supports Auctionator, AHDB, Auctioneer, TSM [V] ; Sorted. TSM/Auctionator plugins [V] | Exists because Baganator lacks it | Medium-High | SwagBag has Auctionator; TSM is on LATER. For gold-makers TSM is common, so consider promoting it (this one is planned, see section 2b). |

### 2b. Planned items the evidence says to prioritize

- **Uncollected transmog/pet/toy/mount/decor overlays** (planned v1.1): CanIMogIt covers transmog, sets, arsenals, toys, pets, mounts, housing decor, with bind colors, in bags/banks/vendors/AH/mail/loot [V]; OneWoW has collection-status overlays plus custom overlay rules [V] https://www.curseforge.com/wow/addons/onewow ; Syndicator exposes mount/pet collection status [V]. This is the most widely duplicated overlay set. Pull toward v1.0 if cheap, since gold-makers flip BoEs and unlearned appearances.
- **TSM prices** (LATER): see gap 22.
- **Worth-money highlight and AH value overlay** (planned): no competitor found with this as a built-in. See differentiators.

## 3. Differentiators (SwagBag has, nobody else found to have)

Evidence is absence from the feature lists fetched on 2026-10-03; absence is not proof. Treat all as "not found in any list I could read".

1. **Activity-aware focus modes** (auto-detect M+/Raid/Delves/Gathering/Fishing/AH/Vendor/Bank, bring relevant sections to the front). None of Baganator, BetterBags, ArkInventory, AdiBags, Bagnon, Sorted., LiteBag, Baggins, GudaBags, ElvUI_BagCategories, NDui, OneWoW pages mention context-driven layout. Strongest differentiator.
2. **Low-consumables warning at M+ start / M+ teleport** with an editable watch list. No bag addon found does this; closest is GudaBags' Tracked Item Bar (manual pin, no thresholds) [V].
3. **Keystone level + dungeon overlay and upgrade-track overlay** (H5/6 etc). Not listed by Baganator, BetterBags, Simple Item Level, CanIMogIt, or OneWoW (OneWoW has custom overlay rules, so it could be built there) [?].
4. **Per-section value totals in headers** from Auctionator with vendor fallback. ElvUI_BagCategories shows per-category counts and an optional running gold total, and supports AH price sources, so this is partly covered there [V]; the section-level AH total looks unique among current Retail bags [?].
5. **Footer ordered with crests + keystone + backpack currencies**. BetterBags tracks up to 7 currencies [V], but crest/keystone in the bag footer was not found elsewhere.
6. **Safe Mode auto-fallback to Blizzard bags on error + `/swagbag report`.** No competitor found offering automatic fallback (Baganator advertises "no taint" but not a fallback) [?].
7. **Full guild bank replacement with remaining-withdrawal display** is shared with Baganator/GudaBags, so not unique. The *stacked character + warband bank groups with Blizzard tab buttons re-hosted* is the distinctive piece [?].
8. **Playstyle setup presets** aimed at removing Baganator's setup burden. Not found elsewhere.

Not differentiators (others have them): list view (Sorted.), search dimming with Syndicator syntax (Baganator), no-move-under-cursor (Baganator/BetterBags placeholders), alt tooltips and viewer (Syndicator/BagSync/Bagnon), upgrade arrows (Baganator/BetterBags/Simple Item Level), BoE/WuE labels (LiteBag/CanIMogIt/Simple Item Level), ElvUI-matching theme (BetterBags auto-detects ElvUI/GW2).

## 4. Sources

Fetched 2026-10-03 unless noted:
- Baganator https://www.curseforge.com/wow/addons/baganator (38.3M DL; latest file 833 on 2026-10-01; 2,027 files)
- Syndicator https://www.curseforge.com/wow/addons/syndicator
- BetterBags https://github.com/Cidan/BetterBags and /releases (2026 notes: perf work, Forever support, glow slider, Pawn/Simple Item Level precedence)
- BetterBags Midnight Module https://addon-radar.com/addon/betterbags-midnight-module
- ArkInventory https://github.com/arkayenro/arkinventory
- BagSync https://www.curseforge.com/wow/addons/bagsync
- Vendor https://www.curseforge.com/wow/addons/vendor ; Scrap https://www.curseforge.com/wow/addons/scrap ; Peddler https://www.curseforge.com/wow/addons/peddler
- OneWoW https://www.curseforge.com/wow/addons/onewow
- Bagnon https://github.com/Jaliborc/Bagnon ; AdiBags https://www.curseforge.com/wow/addons/adibags ; Sorted. https://www.curseforge.com/wow/addons/sorted ; LiteBag https://www.curseforge.com/wow/addons/litebag ; Baggins https://www.curseforge.com/wow/addons/baggins
- CanIMogIt https://www.curseforge.com/wow/addons/can-i-mog-it ; Simple Item Level https://www.curseforge.com/wow/addons/simple-item-level ; Postal https://www.curseforge.com/wow/addons/postal ; Auctionator https://www.curseforge.com/wow/addons/auctionator
- GudaBags https://www.curseforge.com/wow/addons/gudabags ; ElvUI_BagCategories https://github.com/ludvigaf/ElvUI_BagCategories ; Item Locker https://www.curseforge.com/wow/addons/item-locker
- Search snippets only: NDui bag features, ElvUI bags (deepwiki), TSM modules (support.tradeskillmaster.com), Item-lock addon family (ItemLock, iGuard, Set Lock), Baganator integration list.

## 5. Gaps in sourcing

- Reddit, Patreon (Baganator author's update posts returned 403), and CurseForge comments were not reachable. **There is no direct player-request evidence** in this pass; "popularity" is inferred from download counts and from how many addons implement a feature.
- Baganator release changelogs failed to load on GitHub (error shown on the page) and the TheMouseNest repo and wiki returned 404 (private, per the earlier landscape note). Baganator's last ~6 months of release notes were therefore **not** read. Only version/date list: 831 (2026-09-26/28), 832 (09-29), 833 (10-01) [V]. Features Baganator added recently may be missing from this list.
- ArkInventory and ElvUI bag option lists are thin: ArkInventory's wiki and ChangeHistory.md were not read; ElvUI's deepwiki page hit a 429 rate limit, so ElvUI details are from a snippet.
- Not reachable or not found: ArkInventory CurseForge page (404 under the guessed slug), BankStack (404), Bagforge (404; the earlier landscape claim about it is unverified here), GW2 UI bags, Wago category counts, TSM bag-integration docs beyond a snippet, Auctionator's bag integration specifics.
- Download counts for Postal, Simple Item Level, CanIMogIt, Vendor and GudaBags were not retrieved.
- SwagBag-side uncertainty: whether it already has equipment-set categories, layout controls, mail/AH in snapshots, auto-sell or auto-repair is inferred from the short feature file. The week-6 commit message mentions a "vendor walk-away" task, so some vendor behavior may already be in progress. Confirm in code before scheduling.
