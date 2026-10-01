# WoW Bag Addon Landscape — Research Synthesis

*Compiled 2026-09-30 from 5 parallel research passes (major addons, niche addons, cross-character data + API, player sentiment, source-code internals). Game state: Retail 12.1.x (Midnight), MoP Classic, Classic Era/TBC, and WoW: Forever (launches 2026-11-04).*

**Gaps in sourcing:** Reddit was unreachable (blocked). Baganator/Syndicator official repos are private — code facts come from WowUp mirrors (hippuli/*). CurseForge comments are login-gated. Nothing was benchmarked in-game.

---

## 1. The field

### Major all-in-ones

| Addon | Downloads (CF) | Maintainer / cadence | UI model | Categorization | Cross-char | Standout |
|---|---|---|---|---|---|---|
| **Bagnon** (+BagBrother engine) | ~167M | Jaliborc, part-time; reputation for slow patch-day fixes, now improved | One bag + sidebar filter tabs (hide non-matching) | Lua "macro" rules / ItemSearch queries; no sections | Yes (BagBrother), no AH | Biggest install base, formal Skins/Rules/Sort APIs, plugin ecosystem |
| **Bagnonium** (ex-Combuctor) | ~2.1M | Jaliborc, lockstep with Bagnon | Tabbed filter views | Same engine | Yes | Testbed for richer tab UI |
| **Baganator** (+Syndicator) | ~38M (Syndicator 28M) | plusmouse, near-daily releases | **Single OR Category view, toggled per bags/bank** | Every category = a search string, priority + manual items, drag-to-assign | Yes — best-in-class (bags, banks, warband, guild, mail, AH, currencies) | Separate data/search backend with public API; widest integrations; Wago category marketplace |
| **ArkInventory** | ~13.9M | Arkayenro, monthly-ish | "Virtual bars" per window; bag or category layout | Real rule language (sandboxed Lua, ~50 fns, priority order) | Yes, all locations incl. mounts/pets/toys as "locations" | Deepest config; also most complex, heavier memory, recent taint/queue bugs |
| **AdiBags** | ~9.8M | **EOL** (2024) | Auto-sectioned single bag | Priority filter modules (Lua plugins) | No | Invented the smart-section model; drag-to-section override |
| **BetterBags** | ~4.6M | Cidan, very active, has unit tests | Category-first "section grid" | Search-query categories + item lists + Lua API | **No** | Most expressive field query language; header bulk actions; Recent Items |
| **Inventorian** | ~730K | Nevcairiel, maintenance mode | Minimal one-bag, Blizzard look | None | Basic | Stable, tiny |

### Niches the big ones don't fill
- **List/spreadsheet view** — Sorted. (only real one; stalled since Jan 2026).
- **"Enhance Blizzard bags, don't replace"** — LiteBag, MyBags, TheBag. Most patch-resilient approach.
- **Multiple rule-based floating bags** — Baggins.
- **Legacy clients (1.12/3.3.5a)** — Bagshui (archived Aug 2025, forks only).
- **UI-suite bags** — ElvUI, NDui (cargBags), GW2 UI, OneWoW (notable: *user-defined custom overlays*).
- **Modular stack** — BagSync (data), BankStack (sort), Scrap/Vendor/Peddler (junk; Vendor has shareable keep/sell/destroy rule language), Simple Item Level / CanIMogIt / Pawn (overlays).
- **New-flavor land rush** — WoW: Forever spawned ForeverBags, ForeverForge (Ctrl+Shift+Click auto-picks disenchant/prospect/mill), BagSmith.
- **Newest serious entrant** — Bagforge (Kkthnx), Midnight-only, already does button pooling, batched layout, slot locks, secret-value handling.

### Cross-character data layers
| | Bags | Banks | Warband | Guild | Mail | AH | Public API | Storage note |
|---|---|---|---|---|---|---|---|---|
| Syndicator | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **Documented** (`Syndicator.API`, callbacks) | Full hyperlinks per slot + precomputed tooltip summaries |
| BagSync | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | None documented | Compact `link;count;opts` strings |
| DataStore/Altoholic | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Full service layer | One addon per domain |
| BagBrother | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | Internal | Saves bank on close |
| EllesmereUI Alts | benchmark: **~200 KB for 20 characters** | | | | | | | |

---

## 2. What they all have in common (table stakes)
1. Replace or wrap Blizzard bag + bank frames; combined view at minimum.
2. Item search with dimming of non-matches.
3. Sorting (own client-side engine and/or delegate to `C_Container.SortBags`).
4. Bank + warband bank support (quality varies wildly).
5. Quality borders, new-item glow.
6. Secure item buttons built on `ContainerFrameItemButtonTemplate`, parented to per-bag frames with `SetID(bagID)`.
7. BAG_UPDATE coalescing (most of them) and combat lockdown deferral.
8. Multi-flavor support (Retail + Classic families, now Forever).
9. Essentially **one maintainer each** — bus factor of 1 everywhere.

## 3. Where they differ (the real axes)
| Axis | Spectrum |
|---|---|
| **View model** | Single grid (Bagnon, Inventorian) ↔ switchable (Baganator) ↔ category sections (BetterBags, AdiBags) ↔ virtual bars/bags (ArkInventory, Baggins) ↔ list (Sorted) ↔ restyle-Blizzard (LiteBag) |
| **Rule power** | None → search-string categories (Baganator/BetterBags) → Lua macros (Bagnon) → full sandboxed rule language (ArkInventory/Bagshui) |
| **Data scope** | Live bags only (BetterBags, AdiBags) ↔ full account/alt/guild/AH DB (Baganator, ArkInventory, Bagnon) |
| **Feature delivery** | Built-in (ArkInventory, BetterBags) ↔ plugins (Bagnon family) ↔ third-party integrations (Baganator) |
| **Layout stability** | Live reflow (old BetterBags — caused wrong-item vendoring) ↔ gaps/placeholders until close (Baganator, BetterBags now) ↔ staging strip (AdiBags) ↔ dry-run + "Resort" button (Bagshui) |
| **Config depth** | Zero-config (Baganator, Inventorian) ↔ deep layered profiles (ArkInventory: style/layout/catset) |

---

## 4. What players want (and don't get)
**Top complaints:** breaks on patch day (#1 reason people switch — Bagnon→Baganator), taint blocking item use in combat, lag on open/login, CPU while closed, warband bank bugs, items reflowing under cursor, categories lost on reload, plugins that crash the bag.

**Unmet / poorly-met:**
1. **Category-first UI *with* full alt/guild/warband data** — nobody does both well.
2. **Visual rule builder** — power without ArkInventory's learning cliff.
3. **Category management that scales** (100+ imported categories, priorities, profiles).
4. **Per-physical-bag view** as a third mode.
5. **Toggle addon on/off without /reload**, separately for bags vs bank.
6. **Built-in overlays** (ilvl, BoE/WuE, upgrade, uncollected transmog/pet/toy/decor, junk) so users don't depend on fragile plugins.
7. **Readable search** — fully dim non-matches including glows.
8. Category bulk transfer (bank/warband/mail/vendor), partial-stacks-first sort for TSM, reagent-aware sort.
9. **Import from AdiBags/BetterBags/Baganator** — migration path.
10. List view (abandoned niche).

**By persona:** gold-makers → alt counts, TSM/price categories, bulk transfer, low memory. Raiders → zero taint, zero idle CPU, ilvl/upgrade overlays, never break queues. Collectors → uncollected overlays incl. housing decor. Casuals → zero config, reliable, movable, junk sell. Altoholics → everything everywhere.

---

## 5. Technical ground truth (Retail 12.1.x)
- **Containers:** `Enum.BagIndex` — backpack 0, bags 1–4, reagent bag 5, character bank tabs 6–11, warband tabs 12–16. Reagent bank & void removed on Retail (11.2). **Never hardcode tab counts** — iterate `C_Bank.FetchPurchasedBankTabIDs(bankType)` (Forever differs).
- **12.1.5 removed deprecated global item functions** (`GetItemInfo`, etc.) — `C_Item.*` only.
- **Midnight secret values** don't touch C_Container/C_Bank, but do hit tooltips — guard with `issecretvalue()`, prefer `C_TooltipInfo`.
- **Taint rules (the #1 engineering risk):**
  - Item use only through `ContainerFrameItemButtonTemplate` secure path.
  - Pre-create max slot buttons at startup and before combat; one permanent button per slot (Bagnon 12.1.5 fix); never create/reparent secure buttons in combat.
  - Never write `BankFrame.bankType`; never touch BankPanel/`CloseBankFrame()` in ESC-triggered OnHide — use `BANKFRAME_CLOSED`.
  - No insecure PreClick on secure buttons; don't call `OpenAllBags()`; never assign global `_`; replace tooltip MoneyFrame.
  - Sort/transfer/stack only out of combat; queue to `PLAYER_REGEN_ENABLED`.
  - `PurchaseBankTab` must be untainted — leave it to Blizzard UI.
- **Events:** BAG_UPDATE → dirty set; BAG_UPDATE_DELAYED → flush; failsafe timer. Don't rescan on BAG_UPDATE_COOLDOWN (crowd lag).
- **Unverified, test on live:** whether addon-button `SortBags/SortBank` calls are truly allowed; `PlayerInteractionFrameManager` removal in 12.1.

---

## 6. Architecture ideas worth stealing
1. **Engine/UI split** (Syndicator/Baganator, BagBrother/Bagnon) — data + search as a separate layer.
2. **One expression engine, two front-ends** — categories are `{query, priority, itemList}`; search box and category editor share one grammar; sandboxed Lua escape hatch for power users.
3. **Priority separate from display order** (Baganator).
4. **Manual item lists checked before rules**; drag item onto section header to assign.
5. **Bulk categorize per unique item key** with a key→category cache.
6. **Tri-state evaluation** (true/false/nil=not-loaded) propagating through `& |`, retried later.
7. `ContinuableContainer` load before categorizing; `GetItemInfoInstant` for type/slot.
8. Tooltip data cached by GUID, invalidated on `TOOLTIP_DATA_UPDATE`.
9. Real binding APIs (`C_Item.IsBound`, `IsBoundToAccountUntilEquip`) not tooltip text; `C_Item.GetCurrentItemLevel` not tooltip ilvl.
10. Compile query once → closure tree; memoize per item.
11. Keywords registered localized + English; `#kw` exact.
12. **Layout never moves under the cursor**: placeholders until close + optional "Resort" indicator.
13. Escalating dirty levels / refresh-reason bit flags; time-sliced coroutines (5–16 ms) with cancellation token.
14. Sort orders as data (ordered key list + direction), deterministic tiebreak.
15. Physical sort as idempotent single pass returning status + retry driver; special bags first; keep already-correct items in place.
16. Validate rules before save (force-true/force-false run); auto-disable damaged rules.
17. Compact offline storage (BagSync-style strings) + precomputed tooltip totals.

## 7. Pitfalls to avoid
1. Ambiguous query precedence — use `! > & > |`, parentheses, visible parse errors.
2. `pairs()`-order nondeterminism anywhere in matching/sorting.
3. Not re-categorizing when item data arrives (items stuck in Misc).
4. Recompiling rules per evaluation; rebuilding full index every event.
5. **Unsandboxed `loadstring` on imported strings** (BagBrother) — code-exec risk.
6. Unbounded caches; caches persisted to SavedVariables.
7. Tooltip parsing for core fields.
8. Category state spread across multiple tables (orphan bugs).
9. Big per-frame budgets (100 ms = visible hitch).
10. Shipping untested grammar branches (Syndicator's undefined gold-range check).
11. Hard-coded expansion/locale literals.
