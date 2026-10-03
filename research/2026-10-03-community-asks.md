# Community asks for bag addons (Midnight era, Oct 2025 - Oct 2026)

Compiled 2026-10-03. Web research only; no code touched. Complements `bag-addon-landscape.md` (not repeated here).

## How reliable is this? Read first

- **Reddit was reachable only through the PullPush archive API** (api.pullpush.io). old.reddit.com, www.reddit.com and Reddit JSON were all blocked. PullPush is a third-party mirror: it can miss posts, scores are snapshots taken at ingest (many show 1 and are stale), and search is fuzzy.
- Everything fetched went through a summarizing model, so **quotes are paraphrase-grade, not verbatim**. I re-derived every Reddit date from the raw `created_utc` epoch myself, because the summarizer's own date conversions were wrong. Dates below are real calendar dates.
- **GitHub data is solid** (REST API): BetterBags (Cidan), Bagnon (Jaliborc), ArkInventory (Arkayenro). Reactions on all of them are near zero, so "strength" there means distinct issues and comment counts, not votes.
- **Baganator/Syndicator have no public issue tracker** (the author points users to a private GitHub and Discord). The largest single source of Baganator opinion is therefore Reddit.
- Thin or absent: WoWInterface, Blizzard forums (only a Dec 2024 thread, out of window), Wowhead, MMO-Champion, CurseForge/Wago comments (login-gated or not rendered), YouTube comments, Discord. See the last section.
- Counts are "distinct threads/issues I actually found", not a census. M+ and gold-maker evidence in particular is **sparse**; I say so where it applies.

---

## Top 10 asks SwagBag does NOT have or plan, ranked by evidence

| # | Ask | Evidence strength |
|---|---|---|
| 1 | **Equipment-set / off-spec gear category and an accurate "old gear" category** (including freshly crafted gear) | Medium. The most-upvoted bag threads of the year are Baganator category setups (213, 160, 32, 17 points). Their comments ask for this and complain about it. |
| 2 | **Auto-sell junk with a protect list** (plus "mark junk") | Medium. Not asked directly, but 3 new Midnight bag addons ship it as a headline feature, and Bagnon #2207 is a user complaint about broken "mark junk". |
| 3 | **Bulk transfer by category to warband bank / right-click header transfer** | Medium. 1 Reddit thread (12 comments, 3 users point to Baganator's transfer and workarounds); BetterBags #805 (6 reactions), #813 and #809 are about wrong routing. |
| 4 | **Customizable item-level colors and borders** (thresholds, border style) | Medium. BetterBags #937, #952, #1111 and #1084; Bagnon #2195. |
| 5 | **Partial-stacks-first sort (TSM-friendly)** | Low-medium, but it is a gold-maker ask. Bagnon #2200 (2026-08-10). Also on the landscape wish list. |
| 6 | **Controller / ConsolePort / Steam Deck friendliness** | Low-medium. 3 Reddit threads (2026-06 to 2026-08). |
| 7 | **Cross-alt currency tracking and currency QoL** | Low-medium. 1 thread (9 comments, 2026-02-13), BetterBags #856, plus alt-tracker addon threads. |
| 8 | **Tab groups, bank window sizing, multi-row group layout** | Low-medium. BetterBags #804, #935, #947, #982, #983, #852. |
| 9 | **"Use / open / learn now" highlight** (Midnight profession knowledge items, openables, toys, mounts, decor) | Low-medium. Learn Alert (14 points), LearnItAll, and the Baganator plugin Libs-ItemHighlighter. SwagBag plans only uncollected overlays (v1.1+). |
| 10 | **Skin and conflict compatibility (Masque, Skinner, ElvUI icon styles)** | Low. BetterBags #1085 (Masque), #1084 (ElvUI icons); Baganator vs Skinner (blocked settings button). |

Narrower asks I excluded from the ranking because the evidence is one-off:
- ATT (All The Things) data in categories (1 comment).
- Stack-splitting tool (Item Splitter, 6 points).
- Tooltip-ID search.

---

## Themed table

Legend for SwagBag column: Yes / Planned / No / Partial. "Solved by" lists addons that already do it.

| Theme | The ask in plain words | Strength | Example sources (date) | Solved by | SwagBag |
|---|---|---|---|---|---|
| **A. Easy setup / curated defaults** | "Just give me a good category layout." People share and import someone else's setup instead of building one. | **Strongest signal in the dataset.** ~8 threads, led by 4 posts at 213 / 160 / 32 / 17 points. Comments: "how do I install this?", "what's the difference vs default?", "band-aidy" custom categories, requests for English version. | reddit.com/comments/1rum5nw (r/wowaddons, 2026-03-15, 213 pts, 25 comments); 1rulyg5 (r/WowUI, 2026-03-15, 160 pts); 1rubyhj (2026-03-15, 31 pts, 32 comments); 1tswop0 (2026-05-31, 32 pts); 1tvfdfv (2026-06-03, 12 pts) | Baganator + Wago imports; BetterBags "does this by default" (a commenter, scored -2); BetterBags Midnight Module | **Planned** (setup wizard, presets, Baganator string import). Strongly validated. |
| **B. Category accuracy** | "Old gear" must mean old, and crafted gear must land correctly. | 3 heavily upvoted comments (4, 3, 1 pts) on one thread | 1rulyg5 comments (2026-03-15): old-armor category queries seasonal status so new crafts are misplaced and current gear shows as "old"; crafted items drop into the wrong category until equipped | No addon cleanly | **No** (equipment-set category: No). Opportunity: ship accurate default rules. |
| **C. Equipment sets / off-spec gear** | A separate category for gear-set items. | 2 mentions | 1rubyhj comment (2026-03-15); BetterBags #946 "categories don't show contents" (2026-04-29); r/wowaddons 1uakzi5 "BetterBags used to sort armour into type, now it doesn't" (2026-06-20) | Baganator (gear-set tag), ArkInventory | **No** |
| **D. Vendor/sell safety** | Bags must not jump while I sell. Auto-sell junk, protect valuable items, don't delete the wrong thing. | BetterBags #930 (3 comments, 2026-03-02); #1000; Bagnon #2207 "mark junk" broken (2026-10-02). VoidBags, Bagforge and Scrap all ship auto-sell / protect / delete-cheapest. | github.com/Cidan/BetterBags/issues/930; github.com/bughatti/voidbags; github.com/Kkthnx-Wow/Bagforge | Scrap, Vendor, Bagforge, VoidBags, Baganator junk category | Hover guard and "nothing moves" **Yes**; auto-sell junk and protect list **No** |
| **E. Gold-maker asks** | TSM-friendly sorting, bulk warband transfer, AH value, price plugins. Hard to find direct M+/gold-maker threads. | Bagnon #2200 (partial stacks first, 2026-08-10, PR offered); r/WowUI 1vtqkt5 (2026-08-20, "Move items to Warband bank?"); Baganator_CheapestItem plugin (2026-09-29); VoidBags AH overlay | github.com/Jaliborc/Bagnon/issues/2200 | BankStack, TSM Warehousing, Baganator transfer button/categories | AH value + per-section totals **Yes**; partial-first sort **No**; per-category bank transfer **No**; TSM prices **Later** |
| **F. Bank / warband bank** | Right-click should go to the tab I have open. Don't break the bank. Show all tabs. Disable the addon for the bank only. | The single biggest bug cluster in BetterBags Aug-Sep 2025: #805 (6 reactions), #807, #809 (10 comments), #810, #811, #813, #814, #815, #817. Still alive: Bagnon #2125, ArkInventory #2149/#2165 | github.com/Cidan/BetterBags/issues/805; /809; Bagnon #2125 (2025-10-20) | Baganator (works, Transfer button) | Bank + warband window **Yes**; "Blizzard bank" toggle **Yes**; deposit warbound **Planned (Week 6)**; deposit routing to open tab: **verify** |
| **G. Guild bank** | Guild bank must open and not break. | Bagnon #2204 (2026-08-15); ArkInventory #2158 (6 comments, 2026-08-17); r/classicwowtbc comment, 20 pts, 2026-08-09: "most bag addons interact very poorly with the guild bank" | github.com/Jaliborc/Bagnon/issues/2204 | Baganator guild view | **Yes** (full replacement) |
| **H. Search readability** | Fully dim non-matches, including glows and borders. | Bagnon #2195 (closed 2026-09-21), #2199 | github.com/Jaliborc/Bagnon/issues/2195 | Baganator | **Yes** (dims). Verify glows/borders also drop. |
| **I. Item-level / border customization** | Color ilvl by my own thresholds; custom border colors; suppress new-item blink. | BetterBags #937 (5 comments), #952, #938, #1111, #1084 | github.com/Cidan/BetterBags/issues/1111 (2026-09-24), /937 (2026-03-22) | Baganator widgets; plugins like wow-addon-itemtier (upgrade-track badge, 2026-08-17) | ilvl + upgrade track overlays **Yes**; threshold colors **No**; suppress glow: **verify** |
| **J. Collection / learnable overlays** | Tell me when an item has an unlearned appearance, mount, toy, pet or decor, and let me learn it from the bag. Filter bags by unique appearance. | Transmog Loot Helper (r/wowaddons 1qkseqb, 2026-01-23, 22 pts, 10 comments); Learn Alert (1rq70jm, 2026-03-10, 14 pts, 12 comments); ATT wish (2026-03 comment) | reddit.com/comments/1qkseqb; 1rq70jm | Transmog Loot Helper, CanIMogIt, Learn Alert, Libs-ItemHighlighter | **Planned** (v1.1+ overlays). "Learn now" list: **No** |
| **K. Midnight consumable-style items** | One-button use of profession knowledge items; track globs, remnants and crests. | LearnItAll (2026-09-06); r/wowaddons 1r3j2ci (2026-02-13, 6 comments) asks for crest/glob display (answers: Titan Panel, Goblin Toolbox) | reddit.com/comments/1r3j2ci | Titan Panel, GTB, WeakAura-style HUDs | Footer crests/currencies **Yes** |
| **L. Alt currency / alt data** | Sync tracked currencies across alts; alt overviews without relogging. | r/wowaddons 1r3xp5p (2026-02-13, 9 comments); Vaultloom (22 pts / 25 comments, 2026-08-09); Warband Nexus (18 pts, 2026-07-24); Exquisite 4.0 (22 pts, 2026-08-11). These are alt trackers, not bag addons. | reddit.com/comments/1r3xp5p; 1vjyspx; 1v5jxum | WoWthing, Warband Nexus, Vaultloom, BagSync | Item alt data **Yes**; alt currencies **No** |
| **M. Performance / memory** | Light on memory and CPU; no hitches on open or loot. | BetterBags #893 "less memory" (2026-02-18), #1112 (quadratic tooltip index, 100+ ms spikes), #1061 (Pawn stalls 63-64 ms/render, 2026-08-22); Reddit 1utvad7 (2026-07-11): micro-stutter on looting traced to Baganator categories mode (the Baganator dev: categories cost more than single view) | github.com/Cidan/BetterBags/issues/1061; reddit.com/comments/1utvad7 | Baganator single view; Bagforge pooling | Week 6 bank perf **In progress**; budget Pawn calls (see #1061) |
| **N. Layout and window control** | Don't make the bank taller than my screen; scroll; multiple group rows; anchor usability; tab groups. | BetterBags #935, #947, #852, #857, #982, #983 (groups vanished on update), #804 | github.com/Cidan/BetterBags/issues/935 (2026-03-12) | Baganator, Bagnon tabs | Stacked groups + collapsible sections **Yes**; window-height cap/scroll: **verify**; tab groups **No** |
| **O. Controller / Steam Deck** | Bag cursor navigation that does not jump; scaling, bag separation. | r/WowUI 1w2wss0 (2026-08-30); 1uhe83q (2026-06-27, 42 pts); r/wowaddons 1utvad7: ConsolePort users say Baganator cursor jumps and Bagnon navigates better | reddit.com/comments/1w2wss0 | Bagnon (preferred by ConsolePort users) | **No** |
| **P. Skin / UI-suite compat** | Work with Masque, ElvUI, Skinner, EllesmereUI. | BetterBags #1085 Masque (2026-09-15), #1084; Baganator vs Skinner (blocked settings button); r/WowUI 1to2tea: another addon's bag module (EQoL) silently running alongside Baganator (score 8 "do you have multiple bag addons?") | github.com/Cidan/BetterBags/issues/1085 | Baganator Skins API; EllesmereUI skin | ElvUI-match theme **Yes**; Masque **No**; detect a second active bag addon: **No** |
| **Q. Recent / new items** | A "Recent" section with a clear button; stop the blink. | BetterBags #858, #1021, #938 | github.com/Cidan/BetterBags/issues/858 | BetterBags, Baganator | "New" section **Yes**; one-click clear: **verify** |
| **R. Disable per container** | Use the addon for bags but Blizzard for bank. | BetterBags #809, #811 | as above | BetterBags (added), Baganator | **Yes** |
| **S. Stack splitting** | Fast split of stacks. | Item Splitter (1qexmg1, 2026-01-17, 6 pts) | reddit.com/comments/1qexmg1 | Item Splitter | **No** |

---

## Personas

**M+ players.** Direct M+ asks about bags are rare in what I could reach. Baganator shows up in M+ players' addon lists (r/wow comment 2026-05-11, r/wowaddons 2026-02-24 "40+ addons for M+ prep"), and a Feb 2026 r/wow comment (5 pts) recommends a Baganator profile that "auto sorts your bags so you don't have a giant square of mess". The M+-relevant bug class is **taint blocking item use**: Bagnon #2168, #2188, #2203 (item use blocked in combat, 2026-08-13), #2186 (delve treasure), BetterBags #827, #831, #850, #855 (potions and food blocked). SwagBag's Focus modes and consumable warnings are not asked for anywhere I found; they are differentiation, not demand. Treat as unvalidated.

**Gold-makers / AH players.** The evidence is TSM partial-stack sorting (Bagnon #2200), bulk warband transfer (TSM Warehousing and BankStack as workarounds, 2026-08), alt tracking via WoWthing, and price add-ons (Baganator_CheapestItem plugin, VoidBags AH overlay). No direct "show me item AH value in the bag" request surfaced, but competitors ship it.

**Switchers away from Bagnon (strong evidence).** In PullPush results, top comments in r/classicwow (122 pts, 2026-01-14; 60 pts; 48 pts), r/wowhardcore (86 pts, 2025-10-21; 156 pts, 2026-07-25) and r/classicwowtbc (15 pts, 2026-03-18) say "Baganator >>> Bagnon". Reasons given: breaks on patch day and slow fixes ("couldn't use my health pot on bars OR bag"), "haven't worked properly since the Anniversary release", killed hardcore characters. The Bagnon issue tracker backs this up: 2025-10-17 update broke Classic/Retail refresh (#2114 to #2123), Midnight launch (#2140, 2026-01-21), a syntax error that stopped load (#2178), 12.0.11 (#2188), 12.0.19 (#2198). Counterpoint: some keep Bagnon because it is non-combat so Midnight restrictions do not hit it.

**Switchers away from Baganator (weak evidence; no mass exodus found).** Sentiment toward Baganator is overwhelmingly positive. Documented reasons to leave or complain:
- Categories mode costs more CPU than single view (dev quote, 2026-07-11).
- ConsolePort cursor jumps.
- "Recent" tab slow (comment, 2025-10-19).
- Transfer button missing or confusing (2026-08-20).
- Category setup is labor-intensive: users build 30-40 category profiles and share them (see theme A). This is the opening for SwagBag's "opinionated default".

**From BetterBags to Baganator** (r/wowaddons 1n1ju6e, 2025-08-27, outside the 12-month window but relevant): "Baganator does what BetterBags does but better ... doesn't need plugins". BetterBags users also describe breakage on updates and bank invisibility (r/WowUI threads, 2025-08/09).

---

## Top complaints about existing addons (with evidence)

1. **Patch-day / update breakage.** Bagnon: #2114-#2123 (2025-10-17, Retail and Classic), #2140 (2026-01-21 Midnight), #2178 (2026-03-29 syntax error), #2188 (2026-05-21), #2198 (2026-08-03), #2202 (toc bump 2026-08-13), #2204 (guild bank, 2026-08-15). BetterBags #1060 (bag opens once per reload since 12.1, 2026-08-13, open), #879, #1100, #1108. ArkInventory #2154 (12.1 Lua error, 2026-08-12). Reddit: "doesn't work until nearly the 2nd season of the new xpac". The WoW: Forever launch (2026-11-04 target) is generating a new wave (BetterBags #1100-#1117, ArkInventory #2162/#2164).
2. **Taint / blocked actions.** Bagnon #2168, #2186, #2188, #2203, #2205; BetterBags #827, #831 (still open), #850, #855; ArkInventory #2149 (buying a bank tab blocked) and #2161 (kicked from queues). The common pattern is item use failing after bank open/close or in combat.
3. **Performance.** BetterBags #893, #1061 (63 ms stalls), #1112 (100+ ms spikes); Reddit stutter thread (2026-07-11).
4. **Bank and warband routing bugs.** See theme F; the biggest cluster found.
5. **Layout jumps during use.** BetterBags #930 (bags resort ~2 s after a sale).
6. **Lost configuration.** BetterBags #983 (groups gone after 0.4.9), #1107 (pinned categories vanish on reload), #946; Bagnon #2196 (Reverse Order not saved on alts).
7. **Setup complexity.** Reddit 1rum5nw / 1rulyg5 / 1rubyhj comments; "BetterBags Plugins" confusion (2025-08-27).
8. **Stale display / refresh** (mostly Classic): Bagnon #2115 (17 comments), #2121, #2122, #2123.
9. **Two bag addons or modules running at once** (r/wowaddons 1to2tea, 2026-05-26): users blame Baganator for a stray bag window that was another addon's module.
10. **Obsolescence / maintainer risk.** Bagforge, VoidBags and BetterBags Midnight Module are all new in this period, which suggests users still want alternatives.

---

## Sources

GitHub REST API (fetched 2026-10-03):
- https://api.github.com/repos/Cidan/BetterBags/issues (pages 1-4, plus search queries for feature/bug labels)
- https://api.github.com/repos/Jaliborc/Bagnon/issues (and search from 2025-10-01; issues #2195, #2200)
- https://api.github.com/repos/Arkayenro/ArkInventory/issues
- https://api.github.com/search/repositories?q=Baganator (third-party Baganator plugins)
- https://github.com/bughatti/voidbags and https://github.com/Kkthnx-Wow/Bagforge

Reddit (via https://api.pullpush.io, thread permalinks are reddit.com/comments/<id>): 1rum5nw, 1rulyg5, 1rubyhj, 1tswop0, 1tvfdfv, 1utvad7, 1vtqkt5, 1w2wss0, 1to2tea, 1n1ju6e, 1qkseqb, 1rq70jm, 1r3j2ci, 1r3xp5p, 1vjyspx, 1v5jxum, 1vm8kz1, 1qexmg1, 1uakzi5, 1uhe83q, 1o6by9l, plus score-ranked comment searches for "baganator", "betterbags", "syndicator", "bagnon" (r/classicwow, r/wowhardcore, r/classicwowtbc, r/wow).

Other: https://us.forums.blizzard.com/en/wow/t/better-than-bagnon/2033543 (Dec 2024, out of window); CurseForge Baganator page (38.3M downloads, updated 2026-10-01); web-search snippets for Medium and noobtoboss guides.

## What I could not reach

- old.reddit.com, www.reddit.com, Reddit JSON and search (all blocked). PullPush results are incomplete; Reddit comment scores are stale.
- Baganator / Syndicator issue tracker and Discord (private). This is the largest hole: Baganator users' real feature requests live there.
- CurseForge and Wago comment sections (not rendered), WoWInterface (no recent bag threads surfaced), Wowhead and MMO-Champion (nothing relevant surfaced), YouTube comments (only titles seen).
- Search engine results were mostly noise for this niche; no Blizzard UI & Macro forum threads from 2026 were found.
- Not verified in-game: any "verify" cell above is a question for SwagBag's own feature list, not a confirmed gap.
