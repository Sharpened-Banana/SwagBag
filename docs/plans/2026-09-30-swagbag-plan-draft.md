# SwagBag — Product & Technical Plan (Draft)

*Date: 2026-09-30. Status: draft for review. Source of truth for every claim below: `research/bag-addon-landscape.md` (cited as §N / item N). Anything not traceable to the research is marked **[assumption]** or **[verify on live]**.*

---

## 0. Two open decisions and the defaults this plan assumes

| Decision | Default assumed here | Why | Where the plan changes under alternatives |
|---|---|---|---|
| **Goal** | **Mix: build as a personal-use addon first, with public release as the explicit second milestone.** The MVP is scoped as "I would daily-drive this"; v1 is "I'd put this on CurseForge next to Baganator." | A one-dev project needs a motivating daily-use loop before it earns a user base. The research's #1 switching reason is "breaks on patch day" (§4) — credibility there is earned over months, not at launch. | **(A) personal only:** drop import/migration, plugin API, localization, Wago/CurseForge pipeline; keep CI. **(B) public from day one:** pull localization keywords (§6 item 11) and the import path (§4 item 9) into MVP; add a public beta gate. **(C) learning project:** keep the architecture, but build the query engine and layout engine *first* and test-driven; the UI can stay ugly. |
| **Flavors** | **Retail (12.1.x) only for MVP. WoW: Forever as the first additional flavor in v1. Classic Era / MoP Classic deferred to "later" and only if the goal is public.** | Retail is where every taint/API fact in §5 is verified. Forever launches 2026-11-04 and is a "land rush" with immature competitors (§1 niches) — a real opening for a public release. Classic families are table stakes for incumbents (§2 item 8) but add adapter surface with no differentiation. | **Retail only, forever:** delete the flavor adapter's indirection (keep the module boundary, drop the second implementation). **Add Classic families:** adapter grows a `classic` implementation (no warband, no reagent bag, keyring, different bank API); expect ~25% more test-matrix work per release. **Forever first:** risky — nothing in §5 is verified for Forever; its bank differs (§5 item 1). Don't. |

**[assumption]** WoW: Forever runs on the modern client API family (C_Container/C_Item/C_Bank) with different bank tab enumeration. Verify when its PTR/API dump exists; the adapter layer isolates the blast radius either way.

---

## 1. Vision & positioning

**One line:** *A category-first bag addon that knows what all your characters own, never moves an item under your cursor, and never breaks your bags.*

### 1.1 Differentiators (why someone switches)

1. **Category sections + full alt/warband/guild data in one UI.** The research calls this the top unmet need: "nobody does both well" (§4 unmet #1). BetterBags/AdiBags have sections but no cross-character data; Baganator has the data but category view is a mode, not the design center (§1 table). SwagBag is section-first *and* every item shows "you own 14 across 3 characters" without a second addon.
2. **Never-break guarantee: Safe Mode + per-window toggle without /reload.** Patch-day breakage is the #1 reason players switch addons (§4 complaints; §1 Bagnon reputation). SwagBag ships (a) feature detection for every API it touches (§5 item 1, §7 item 11), (b) a one-click "fall back to Blizzard bags" per window — bags vs bank separately (§4 unmet #5), and (c) an in-game self-test that reports what's broken instead of erroring.
3. **One query grammar everywhere, with a visual builder on top.** Search box, category rules, and sort filters share one compiled expression engine (§6 item 2). Power users get ArkInventory-class expressiveness; everyone else gets a rule builder that round-trips to the same text (§4 unmet #2, #3).
4. **Layout you can trust.** No reflow while the window is open or the cursor is over it, placeholders until close, explicit "Reflow" affordance (§6 item 12; §3 layout-stability axis; the BetterBags wrong-item-vendoring incident). Search fully dims non-matches *including* glows and overlays (§4 unmet #7).
5. **Built-in overlays, no fragile plugins.** ilvl, BoE/WuE, upgrade, uncollected transmog/pet/toy/decor, junk — using real APIs (`C_Item.IsBound`, `C_Item.GetCurrentItemLevel`), not tooltip scraping (§4 unmet #6, §6 item 9, §7 item 7).

### 1.2 Non-goals (YAGNI — explicit)

- **No auction-house or mailbox scanning** in core. Syndicator/BagSync already do this; it's the most expensive, least bag-shaped data (§1 cross-char table). Revisit only via a data provider (see §4.3).
- **No TSM/price-based categories in core.** Gold-maker persona wants it (§4 personas), but it's a plugin after the plugin API exists.
- **No skins marketplace / theme engine.** One good default look plus ElvUI/Masque-compatible button skinning hook. Bagnon's Skins API is a maintenance tax, not a differentiator.
- **No sandboxed Lua in MVP or v1.** ArkInventory's learning cliff is the thing we're avoiding (§4 unmet #2). The grammar must be expressive enough first; Lua is a "later" escape hatch with strict sandboxing (§7 item 5).
- **No replacement of Blizzard's bank-tab purchase UI.** `PurchaseBankTab` must stay untainted (§5 taint rules).
- **No legacy clients (1.12 / 3.3.5a).** Bagshui's niche; archived (§1).
- **No vendor keep/sell/destroy rule engine.** Consume Vendor/Scrap/Peddler via their APIs instead (§1 modular stack).
- **No guild-bank editing or deposit UI.** Read-only guild snapshot only.
- **No "enhance Blizzard bags" mode.** That's LiteBag's niche and is incompatible with a category layout.

---

## 2. Personas

| Persona | Needs (from §4 personas) | MVP serves with | v1 adds |
|---|---|---|---|
| **Rae the raider** | Zero taint, zero idle CPU, ilvl/upgrade overlays, never break queues | Secure button pool, combat freeze, idle CPU = 0 | ilvl/upgrade overlays |
| **Goldie the gold-maker** | Alt counts, partial-stacks-first sort, bulk transfer, low memory | Partial-stacks-first sort option, compact memory | Alt counts in tooltip and section headers, category bulk transfer to bank/warband |
| **Alta the altoholic** | Everything everywhere | Warband bank view | Cross-character store, offline bag/bank browsing |
| **Cole the collector** | Uncollected overlays incl. housing decor | — | Uncollected transmog/pet/toy/decor overlay |
| **Cas the casual** | Zero config, reliable, movable, junk sell | Sensible default categories, movable window, Safe Mode | One-click junk sell, "Blizzard look" preset |
| **Pat the power user** (ex-ArkInventory/BetterBags) | Expressive rules, 100+ categories, profiles, import | Text grammar, priorities, profiles | Visual rule builder, import from AdiBags/BetterBags/Baganator |

Pat is deliberately *not* the MVP target even though they're loudest. The research shows the depth-first addon (ArkInventory) is "also most complex, heavier memory, recent taint/queue bugs" (§1). We earn Pat after Rae and Cas trust us.

---

## 3. Feature scope

### 3.1 MVP — "I daily-drive this on Retail" (one developer, no release pressure)

| Feature | Rationale |
|---|---|
| Replace bags + character bank + warband bank frames; combined view | Table stakes 1, 4 (§2) |
| Two view modes per window: **single grid** and **category sections**, toggled live | Baganator proved per-window toggle is the right shape (§1); sections are differentiator #1's foundation |
| Search box with full dim (icon, glow, overlay, quality border) | Table stakes 2 + unmet #7 |
| Query grammar v1 (text only) powering search *and* categories | Differentiator #3; one engine (§6 item 2) |
| Default category set (~15 categories) + user categories with `{query, priority, itemList}` | §6 items 2–4 |
| Drag item onto section header to assign to manual list | §6 item 4 |
| Sorting: delegate physical sort to `C_Container.SortBags/SortBankBags`; client-side section order as data; partial-stacks-first option | Table stakes 3; §6 items 14–15; Goldie **[verify on live]** whether addon-triggered `SortBags` is permitted (§5 unverified) |
| Layout stability: placeholders + Reflow button | Differentiator #4 |
| Quality borders, new-item glow, junk coin icon | Table stakes 5 |
| Combat safety: pre-created secure pool, combat freeze, deferred sort | §5 taint rules — non-negotiable |
| Safe Mode toggle per window (bags / bank) without /reload | Differentiator #2 |
| Config: window scale/columns, category enable/order, one profile, `/swagbag` slash | Minimum to be usable |
| `/swagbag selftest` reporting API presence | Differentiator #2; cheap |
| CI: luacheck + busted on pure modules | §8 — must exist before the engine grows |

**Cut line rationale:** everything in MVP is needed for the addon to replace the author's current bag addon *without regressing* on table stakes. Nothing in MVP requires persistent cross-character data, tooltip caching, or a second flavor — the three biggest sources of complexity and bugs in the field (§1 ArkInventory, §4 warband bugs).

### 3.2 v1 — "I'd publish this" (public release candidate)

| Feature | Rationale |
|---|---|
| Cross-character store: bags, bank, warband, guild bank snapshot; alt counts in tooltip; offline character view | Differentiator #1 (§4 unmet #1); storage target per §1 benchmark |
| Overlays: ilvl, BoE/WuE, upgrade track, uncollected (transmog/pet/toy/decor), junk | Differentiator #5 (§4 unmet #6) |
| Visual rule builder (round-trips to grammar text) | Differentiator #3 (§4 unmet #2) |
| Category management at scale: search/filter categories, bulk enable, folders, import/export strings | §4 unmet #3 |
| Import from AdiBags / BetterBags / Baganator | §4 unmet #9 |
| Profiles (per-character / global), category sets shareable as strings | §3 config-depth axis, §4 unmet #3 |
| WoW: Forever flavor via adapter | §0 flavors decision |
| Localization scaffold; keywords registered localized + English | §6 item 11, §7 item 11 |
| Release pipeline to CurseForge/Wago/GitHub | §8 |
| Category bulk actions on headers (move to bank/warband, sell junk) | §4 unmet #8; BetterBags precedent (§1) |

### 3.3 Later — only with evidence of demand

- Plugin API (overlays, categories, data providers, sort keys) — after v1 stabilizes; design in §4.11 now, ship later.
- Per-physical-bag view as a third mode (§4 unmet #4).
- List/spreadsheet view (§4 unmet #10; Sorted. is stalled).
- Sandboxed Lua escape hatch (§6 item 2, §7 item 5).
- Syndicator/BagSync as optional data provider for AH/mail (§4.3).
- Classic Era / MoP Classic flavors.
- TSM price keywords via plugin.
- Reagent-aware sort for crafters (§4 unmet #8).

---

## 4. Architecture

Guiding rule (from §6 item 1): **engine/UI split.** Everything left of the dotted line below is pure Lua with no frame dependencies and is unit-tested outside the game. Everything right of it is thin.

```
 ┌──────────────── pure Lua (busted-tested) ────────────────┐ ┊ ┌──────── WoW-only ────────┐
 │ Query/Rules Engine ─► Categorizer ─► Layout Engine        │ ┊ │ Views (Bag/Bank/Warband)  │
 │        ▲                  ▲              │                │ ┊ │ Secure Button Pool        │
 │   Item Model/Cache ◄── Live Inventory Model              │ ┊ │ Config UI / Rule Builder  │
 │        ▲                  ▲                               │ ┊ │ Overlays                  │
 │   Cross-Char Store    Game API Adapter (interface only)   │ ┊ │ Adapter impl (retail/…)   │
 │   Sort Engine         Config/Profiles   Event Bus         │ ┊ │ Importers (read other SV) │
 └──────────────────────────────────────────────────────────┘ ┊ └──────────────────────────┘
```

### 4.1 Game API Adapter (`SwagBag.API`)
- **Purpose:** the only module allowed to call `C_Container`, `C_Item`, `C_Bank`, `C_TooltipInfo`, `Enum.BagIndex`. Flavor-specific files (`api_retail.lua`, `api_forever.lua`) implement one interface; capability flags are computed at load by feature detection, never by TOC version alone (§5 item 1, §7 item 11).
- **Interface (sketch):** `GetBagIDs(kind)` → ordered list (iterates `C_Bank.FetchPurchasedBankTabIDs(bankType)`; never hardcodes tab counts, §5); `GetSlotInfo(bag, slot)` → normalized record; `GetItemInstant(itemID|link)`; `RequestItemLoad(itemID, cb)` (wraps `Item:ContinueOnItemLoad` / `ContinuableContainer`, §6 item 7); `IsBound(bag, slot)`, `IsWuE(bag, slot)` (real binding APIs, §6 item 9); `GetCurrentItemLevel`; `SortBags(kind)`; `Caps` table (`hasWarband`, `hasReagentBag`, `hasGuildBank`, `secretValues`).
- **Dependencies:** none internal. Guards every tooltip-derived value with `issecretvalue()` (§5 secret values).
- **Testing:** the interface has a mock implementation in `spec/` so every module above it runs under busted.

### 4.2 Live Inventory Model (`SwagBag.Inventory`)
- **Purpose:** in-memory, authoritative state of the current character's containers: `slots[bagID][slot] = {itemID, link, count, quality, locked, guid, ...}`. Owns event coalescing.
- **Interface:** `GetSlot(bag, slot)`, `IterateBags(kind)`, `OnChanged(callback)` with a **refresh-reason bitfield** (`COUNT_ONLY`, `ITEM_CHANGED`, `BAG_SIZE`, `LOCK_STATE`, `COOLDOWN`) so consumers can skip work (§6 item 13).
- **Event policy:** `BAG_UPDATE` → add bagID to dirty set, no scan; `BAG_UPDATE_DELAYED` → flush; failsafe `C_Timer` at 0.25 s if DELAYED never arrives; `BAG_UPDATE_COOLDOWN` updates cooldown overlays only, never rescans (§5 events). `ITEM_LOCK_CHANGED` → `LOCK_STATE` reason only.
- **Dependencies:** API Adapter, Event Bus.

### 4.3 Cross-Character Store (`SwagBag.Vault`) — build vs consume

**Options considered:**
- (a) **Consume Syndicator's documented API** (`Syndicator.API`, callbacks; best-in-class coverage, §1 table).
- (b) **Build our own store.**
- (c) Provider interface with (b) as default and (a) as optional provider.

**Recommendation: (b) for bags/bank/warband/guild, behind a provider interface that *could* accept Syndicator later, but with no Syndicator code in MVP or v1.**

Reasoning, tied to research:
- Differentiator #1 is "category UI *with* alt data." If that data comes from a competitor's backend whose repo is private and maintained by one person (§1 gaps, §2 item 9), our headline feature has a bus factor we don't control. Baganator's own near-daily cadence (§1) means the API surface can move under us.
- The expensive parts of Syndicator are AH and mail (§1 table) — exactly the things we declared non-goals. Bags/bank/warband/guild snapshots are cheap: we already hold the live model; persisting a compact copy on bank close / guild bank close is a small module (BagBrother does exactly this, §1 table "saves bank on close").
- Storage is bounded: BagSync-style `link;count` strings and the EllesmereUI benchmark (~200 KB for 20 characters, §1) give a concrete target — **≤ 12 KB per character, ≤ 300 KB total at 25 characters** (§6 item 17, §7 item 6).
- Under **goal (A) personal**, this is still right: a personal user wants alt counts, not an AH scanner. Under **(B) public**, a later Syndicator *provider* lets Baganator refugees keep their AH/mail data without us owning it.

- **Interface:** `Record(characterKey, kind, snapshot)`, `Counts(itemKey)` → `{bags=, bank=, warband=, guild=, byCharacter={...}}` precomputed and cached per item key (§6 item 17), `IterateCharacters()`, `GetSnapshot(characterKey, kind)` for offline view. Provider interface: `RegisterProvider(name, {counts=fn, characters=fn, priority=n})`.
- **Dependencies:** Live Inventory Model (source), SavedVariables. Nothing above it depends on the storage format.

### 4.4 Item Model / Cache (`SwagBag.Items`)
- **Purpose:** per-slot derived fields the engine queries (type, subtype, equip slot, ilvl, bind, expansion, quality, isJunk, isReagent, uncollected flags...) and the **unique item key** used for memoization (`itemID:bindState:ilvl:suffix` **[assumption]** — tune after measuring collisions).
- **Interface:** `Describe(slotRecord)` → item record or `nil` + `pending` if data not yet loaded; `Invalidate(guid)`; `OnLoaded(callback)`.
- **Caching:** bounded LRU (target 2,000 entries, **[assumption]**), in memory only, never persisted (§7 item 6). Tooltip-derived fields (only where no API exists, e.g. uncollected decor) cached by GUID and invalidated on `TOOLTIP_DATA_UPDATE` (§6 item 8). `GetItemInfoInstant` for type/slot before full load (§6 item 7).
- **Dependencies:** API Adapter.

### 4.5 Query / Rules Engine (`SwagBag.Query`) — see §5 for the language
- **Purpose:** parse text → AST → compiled closure tree; evaluate tri-state against an item record.
- **Interface:** `Compile(text)` → `{fn, keywords, errors}` (errors are positioned, surfaced in UI — §7 item 1); `Evaluate(compiled, itemRecord)` → `true | false | nil`; `RegisterKeyword(name, localizedNames, evaluator, argType)`; `Validate(compiled)` runs force-true/force-false passes to catch broken branches (§6 item 16, §7 item 10).
- **Dependencies:** none (keywords are injected). Fully busted-tested.

### 4.6 Categorizer (`SwagBag.Categories`)
- **Purpose:** map every slot to exactly one category id given the active category set.
- **Data model (single table — §7 item 8):** `category = {id, name, query (text), compiled (runtime), priority, itemList = {include = {[itemKey]=true}, exclude = {...}}, displayOrder, enabled, color, icon, source = "builtin|user|imported:<addon>"}`.
- **Algorithm:** for each slot: (1) manual include lists, highest priority first (§6 item 4); (2) rules by `priority` desc, then stable by `id` (no `pairs()` order anywhere — §7 item 2); (3) fallback "Other". Result memoized per unique item key (§6 item 5); the memo is dropped when any category changes. Items that evaluate `nil` go to a **Pending** set and are re-run when `Items.OnLoaded` fires (§7 item 3).
- **Interface:** `Assign(slotRecord)` → categoryId, `AssignAll(iter)` → `{categoryId → ordered slots}`, `Invalidate(reason)`.
- **Dependencies:** Query Engine, Items. Pure Lua.

### 4.7 Sort Engine (`SwagBag.Sort`)
- **Purpose:** (a) *display order* within sections, (b) *physical* bag sort.
- **Display sort:** sort orders as data — ordered key list + direction (`{"quality desc", "ilvl desc", "name asc", "count desc"}`), deterministic tiebreak on `bag,slot` (§6 item 14, §7 item 2).
- **Physical sort (MVP):** delegate to `C_Container.SortBags()` queued to out-of-combat (§5). Own single-pass idempotent mover with retry driver (§6 item 15) is **later**, gated on whether the Blizzard call is sufficient and permitted **[verify on live]**.
- **Dependencies:** Items, Inventory, API.

### 4.8 Layout Engine (`SwagBag.Layout`)
- **Purpose:** turn `{category → ordered slots}` into a stable grid of `{bag, slot → x, y, sectionId}` without moving anything under the cursor. Details in §7.
- **Interface:** `Compute(prevLayout, assignments, constraints)` → `newLayout, diff, needsReflow`; `Reflow()`.
- **Dependencies:** none. Pure Lua, the most heavily tested module.

### 4.9 Secure Button Pool (`SwagBag.Buttons`)
- **Purpose:** exactly one `ContainerFrameItemButtonTemplate` button per physical `(bagID, slot)`, created at login (and when a bank first opens, out of combat), parented to a per-bag frame with `SetID(bagID)` (§2 item 6, §5 taint rules). Never created, destroyed, or reparented in combat.
- **Interface:** `Get(bag, slot)` → button (never nil after init), `EnsureCapacity(bag, size)` (no-op in combat; schedules on `PLAYER_REGEN_ENABLED`), `Place(button, x, y, parentSection)`, `Hide(button)`.
- **Dependencies:** API Adapter. See §6.

### 4.10 Views (`SwagBag.Views.*`)
- Bags, Bank, Warband windows. Each has `mode = "grid" | "sections"`, a search box, header with Safe Mode toggle. Hook `ToggleAllBags`/`OpenBag`/`CloseAllBags`/`ToggleBackpack` with a `enabled` guard checked *inside* the hook (hooks can't be removed, so the toggle flips the guard — this is what makes "disable without /reload" possible). We never call `OpenAllBags()` ourselves (§5). Bank: we open our window on `BANKFRAME_OPENED` and close on `BANKFRAME_CLOSED`; we never write `BankFrame.bankType` or call `CloseBankFrame()` from OnHide (§5).
- **Dependencies:** everything.

### 4.11 Config / Profiles (`SwagBag.Config`) and Plugin API (`SwagBag.Plugins`, later)
- Config uses AceDB-style profiles **[assumption: embed AceDB-3.0 only; avoid AceConfig's weight for the main UI]**. Category sets are a separate profile dimension (ArkInventory's style/layout/catset split is the right idea, §1).
- Plugin API surface (designed now, shipped later): `RegisterOverlay`, `RegisterKeyword`, `RegisterCategoryPreset`, `RegisterDataProvider`, `RegisterSortKey`. Plugins run inside `pcall` wrappers and are auto-disabled after N errors — "plugins that crash the bag" is a listed complaint (§4).

### 4.12 Event Bus (`SwagBag.Events`)
- Tiny pub/sub with refresh-reason bitflags; the only `OnUpdate` in the addon lives here and is **unregistered when no window is visible** (idle CPU = 0, §4 complaints "CPU while closed").

---

## 5. Query / rule language

### 5.1 Goals
One grammar for search box, categories, and sort filters (§6 item 2). Unambiguous precedence with visible parse errors (§7 item 1). Tri-state evaluation (§6 item 6). Compiled once (§6 item 10, §7 item 4).

### 5.2 Grammar sketch (EBNF)

```
expr      := or
or        := and ( "|" and )*             -- also the word "or"
and       := not ( "&" not )*             -- also "and"; adjacent terms are implicit AND
not       := "!" not | primary            -- also "not"
primary   := "(" expr ")" | term
term      := keyword | exact | text
keyword   := NAME op VALUE                -- ilvl>500  quality>=rare  type:armor  slot:head
           | NAME                         -- bare predicate: boe  junk  reagent  new
exact     := "#" NAME [":" VALUE]         -- #boe exact keyword, no fuzzy/localized match
text      := WORD | '"' ... '"'           -- name substring, case-insensitive
op        := ":" | "=" | "!=" | "<" | "<=" | ">" | ">="
```

**Precedence:** `!` > `&` > `|`, parentheses override (§7 item 1). Implicit AND between adjacent terms, so `potion healing` works like every other bag search. Parse errors return the character offset; the UI underlines it and the category is marked invalid, never silently dropped (§6 item 16).

### 5.3 Keyword set (MVP)

| Family | Keywords | Notes |
|---|---|---|
| Identity | `name`, `id`, `type`, `subtype`, `slot`, `set` | `type`/`subtype` match Blizzard class/subclass; localized + English (§6 item 11) |
| Numbers | `ilvl`, `level` (required), `quality`, `count`, `stack`, `expansion` | `quality` accepts names (`epic`) or numbers; `expansion:current` resolved via API caps, never a literal (§7 item 11) |
| Binding | `boe`, `bop`, `wue`, `bound`, `warbound`, `soulbound` | `C_Item.IsBound` / `IsBoundToAccountUntilEquip` (§6 item 9) |
| State | `new`, `junk`, `locked`, `cooldown`, `usable`, `equipped`-set, `reagent`, `quest`, `tradeskill` | |
| Location | `bag:backpack|1-4|reagent|bank|warband|guild`, `tab:N` | |
| Collection (v1) | `uncollected`, `uncollected:transmog|pet|toy|mount|decor`, `upgrade` | tooltip-derived where no API exists; cached by GUID (§6 item 8) |
| Meta | `cat:<name>` (is-in-category — forbidden inside category rules to prevent cycles), `alt:<char>` (v1) | |

### 5.4 Tri-state evaluation

Each leaf returns `true`, `false`, or `nil` (= "item data not loaded yet"). Combinators: `nil & false = false`, `nil & true = nil`, `nil | true = true`, `nil | false = nil`, `!nil = nil`. A `nil` result at the root puts the item in Pending; the categorizer re-evaluates on load (§6 item 6, §7 item 3). Search treats `nil` as "don't dim yet."

### 5.5 Compilation and memoization

`Compile(text)` produces a closure tree once per category edit or search keystroke (debounced 150 ms). Evaluation is memoized per `(compiledId, uniqueItemKey)`; the memo is bounded and flushed on category-set change (§6 items 5, 10; §7 item 4, 6).

### 5.6 Categories = `{query, priority, itemList}`

Exactly the Baganator/BetterBags-proven shape (§1, §6 items 2–4). **Priority is separate from display order** (§6 item 3): priority decides *which* category wins, display order decides *where* it draws. Manual includes beat every rule; manual excludes are checked before rules too. Editing a category never touches another category's table (§7 item 8).

### 5.7 Sandboxed Lua escape hatch — decision: **not in MVP/v1**

When added (later), it's a `lua:` leaf whose body runs in a `setfenv` sandbox with a frozen environment of ~30 pure functions (no `_G`, no `loadstring`, no frame access, instruction-count hook). **Imported category strings containing `lua:` are stored disabled** until the user opens and re-saves them — the BagBrother unsandboxed `loadstring` risk (§7 item 5) is not acceptable for a public addon.

### 5.8 Visual rule builder (v1)

The builder edits the **AST**, not the text: rows of `[keyword] [op] [value]`, grouped into AND/OR blocks with a NOT toggle. "Advanced" reveals the text; both directions round-trip losslessly because the pretty-printer is canonical. Anything the builder can't represent (there shouldn't be anything — the grammar is small by design) falls back to text with a warning. This is how we deliver ArkInventory power without its cliff (§4 unmet #2).

---

## 6. Taint / combat safety strategy

Every rule in §5 of the research becomes a concrete mechanism:

| Research rule | Mechanism |
|---|---|
| Item use only via the secure template path | All item interaction is the button's own secure handlers. No `PreClick`, no insecure click wrappers (§5). Our tooltip/overlay logic hooks `OnEnter`/`OnLeave` only. |
| One permanent button per slot; pre-create before combat | `Buttons.EnsureCapacity` at `PLAYER_LOGIN` for backpack + bags 1–4 + reagent bag (Enum.BagIndex), and on first `BANKFRAME_OPENED` for every id from `FetchPurchasedBankTabIDs`. Bank tab purchase → `EnsureCapacity` deferred if in combat. Buttons never destroyed, never reparented after creation (§5). |
| Nothing structural in combat | `InCombatLockdown()` gate on: button creation, bag-size changes, physical sort, bulk transfers. Queued to `PLAYER_REGEN_ENABLED` with a single drain function. |
| Layout freeze in combat | In combat the layout engine returns `prevLayout` unchanged; only icon/count/cooldown/lock textures update. Items appearing in combat show in their *existing* slot button, appended to an "Incoming" strip. **[verify on live]** that `Show/Hide/SetPoint` on these non-protected secure buttons is legal in combat; if not, new items simply stay hidden until regen. |
| Never write `BankFrame.bankType`; never `CloseBankFrame()` from OnHide | Bank window closes via `BANKFRAME_CLOSED` only. ESC on our window hides our frame and calls nothing. Tab purchase button opens the Blizzard panel. |
| Don't call `OpenAllBags()`; never assign global `_` | luacheck rule `globals = {}` + a custom check that fails CI on `_ =` at file scope and on `OpenAllBags(`. |
| Replace tooltip MoneyFrame | Our tooltip footer uses our own money string, not `GameTooltip`'s MoneyFrame (§5). |
| Secret values | Adapter wraps every `C_TooltipInfo` read with `issecretvalue()` and returns `nil` (tri-state) when secret (§5). |
| Sort/transfer/stack only out of combat | Sort engine's public entry points are all `Queue.outOfCombat(fn)`. |

Verification: an in-game `/swagbag taint` command toggles `taintLog` and runs a scripted open/close/sort sequence, then greps `SavedVariables/taint.log` for `SwagBag`. This becomes a manual pre-release checklist item.

---

## 7. Layout stability model

Rules (from §6 item 12 and the §3 layout axis):

1. **While a window is visible, no item moves.** Removed items leave an empty placeholder in their section. New items append to the end of their section (or to a "New" staging strip if the section is collapsed — AdiBags' staging idea, §3).
2. **Sections never reorder, resize, or collapse on their own while visible.** A section can grow by one row at its bottom; it never shrinks.
3. **Reflow happens on close** (default), or when the user clicks the "Reflow" indicator that appears in the header when `needsReflow` is true (Bagshui's "Resort" idea, §6 item 12).
4. **Hover guard:** even an explicit Reflow is delayed while the cursor is over any item button, to the next `OnLeave` — closing the loop on the "wrong item vendored" incident (§3).
5. **Search never reflows** — it dims. Optional "filter mode" (hide non-matches) exists only in grid mode and is clearly a different mode.
6. In combat, rule 1 is absolute (see §6).

The engine takes `prevLayout` and returns a diff; the view applies only the diff, so a count change on one slot touches one button.

---

## 8. Performance budget & strategy

| Budget | Target | Mechanism |
|---|---|---|
| Idle CPU, windows closed | **0 ms/frame** — no OnUpdate, no scans | Event bus unregisters its frame; `BAG_UPDATE` only toggles dirty bits (§4 complaint "CPU while closed") |
| Open after login (cold), 200 slots | ≤ 30 ms total, no single frame > 8 ms | Time-sliced coroutine, 4 ms/frame budget with cancellation token (§6 item 13, §7 item 9) |
| Open, warm | ≤ 8 ms | Category memo + layout diff |
| Single-slot change | ≤ 1 ms | Refresh-reason bits route `COUNT_ONLY` straight to the button |
| Search keystroke | ≤ 4 ms after 150 ms debounce | Compiled query + memo |
| Memory, 25 characters | SavedVariables ≤ 300 KB; runtime ≤ 3 MB | Compact strings (§6 item 17); bounded in-memory caches, never persisted (§7 item 6) |
| Event storms (loot, crowds) | one layout pass per `BAG_UPDATE_DELAYED` | Dirty set + failsafe timer; ignore `BAG_UPDATE_COOLDOWN` for rescans (§5 events) |

Measurement: `/swagbag perf` prints last open/refresh timings and cache hit rates; busted benchmarks for Compile/Evaluate/Layout on a 500-slot synthetic inventory keep regressions visible.

---

## 9. Patch-day resilience & maintainability

- **Feature detection, not version checks.** `API.Caps` is computed by probing (`C_Bank and C_Bank.FetchPurchasedBankTabIDs`, `C_Item.IsBoundToAccountUntilEquip`, ...). A missing capability degrades a feature, never errors (§5 item 1; 12.1.5's removal of `GetItemInfo` family is exactly the kind of change this absorbs).
- **No hardcoded tab counts, expansion ids, or locale strings** (§5, §7 item 11). Multi-TOC (`SwagBag_Mainline.toc`, later `SwagBag_Forever.toc`) only selects which adapter file loads.
- **Safe Mode:** on any Lua error inside a view's refresh path (pcall-wrapped), the window flips to Safe Mode (Blizzard bags), shows one non-spammy message, and `/swagbag selftest` explains what failed. This directly targets the #1 switching reason (§4).
- **Testing outside the game:** busted + luacheck in GitHub Actions on every push. Pure modules (Query, Categorizer, Layout, Sort, Vault, Items-without-API) get real unit tests; the API adapter interface has a mock (`spec/mock_api.lua`) with fixture inventories (500-slot synthetic, warband edge cases, unloaded items). BetterBags is the only competitor with unit tests (§1) — this is cheap credibility.
- **In-game checks:** `/swagbag selftest` (API probes), `/swagbag taint` (§6), `/swagbag perf` (§8).
- **Release pipeline (v1):** BigWigs packager via GitHub Actions on tag → CurseForge + Wago + GitHub Releases; changelog from commits; version in TOC from tag. Public repo from day one (lesson from the Baganator/Syndicator private-repo sourcing gap, §gaps).
- **Bus factor:** every competitor has a bus factor of 1 (§2 item 9). Mitigations: public repo with permissive license; `docs/ARCHITECTURE.md` kept in sync with module list above; `CONTRIBUTING.md` with the taint checklist; release fully automated so a co-maintainer can ship without the author; this plan and the research committed in-repo.

---

## 10. Migration / import

Goal: a Baganator, BetterBags, or AdiBags user keeps their categories on day one (§4 unmet #9).

| Source | Where categories live | Translation | Lossy parts |
|---|---|---|---|
| **Baganator** | Per-category search string + priority + manual item list (§1); Wago marketplace strings | Grammar is close to ours; map keyword names, keep priority and item list 1:1 | Keywords we don't support become a flagged text term; undefined-behavior branches (§7 item 10) are rejected with a message |
| **BetterBags** | Search-query categories + item lists (§1); field query language | Field→keyword map; AND/OR/NOT map directly | Lua-API-defined categories can't be imported (they're code) |
| **AdiBags** | Built-in filter modules + user "custom filters" (item lists / name patterns) | Built-ins map to our presets; custom filters become `itemList` + `name:` terms | Priority semantics differ (modules, not numbers) — importer assigns priorities by original order and says so |

Mechanism: importers read the other addon's SavedVariables tables **only if that addon is loaded**, run under `pcall`, and produce a preview ("24 categories, 3 with warnings") before writing. Also: paste-string import for Baganator/Wago strings. Imported categories carry `source = "imported:baganator"` so users can bulk-remove them (§4 unmet #3).

---

## 11. Milestone roadmap (relative sizes: S < M < L)

| # | Milestone | Size | Contents | Exit criteria |
|---|---|---|---|---|
| M0 | Foundations | S | Repo, TOC, luacheck, busted + API mock, CI, Event Bus, API adapter (Retail) with `Caps` | CI green on a no-op addon; `/swagbag selftest` works |
| M1 | Live model + secure pool + grid view | M | Inventory model with coalescing; Buttons pool; Bags window in grid mode; Safe Mode toggle | Bags usable in and out of combat; taint log clean |
| M2 | Query engine + search | M | Grammar, compiler, tri-state, keyword registry, search box with full dim | 100+ busted cases; search on a 200-slot bag ≤ 4 ms |
| M3 | Categories + sections + stable layout | L | Categorizer, default set, layout engine with placeholders/Reflow, drag-to-assign | No item moves while open (scripted test); pending items resolve |
| M4 | Bank/warband + sort + config → **MVP** | M | Bank and warband windows via `FetchPurchasedBankTabIDs`; SortBags delegation; display sort as data; profiles; slash config | Author daily-drives it; all §6 rules verified in-game |
| M5 | Cross-character store | M | Vault with compact snapshots; alt counts in tooltip and headers; offline view | ≤ 12 KB/character measured |
| M6 | Overlays | M | ilvl, BoE/WuE, upgrade, uncollected, junk; GUID tooltip cache | No tooltip parsing for bind/ilvl |
| M7 | Visual rule builder + category management | L | AST editor, round-trip, folders, bulk ops, export strings | Builder covers 100% of grammar |
| M8 | Importers | S | Baganator, BetterBags, AdiBags adapters with preview | Import of a 100-category set without data loss warnings beyond documented ones |
| M9 | Forever flavor + release pipeline → **v1** | M | `api_forever.lua`, multi-TOC, packager, CurseForge/Wago listings, localization scaffold | Published |
| Later | Plugin API, per-bag view, list view, Lua sandbox, Syndicator provider, Classic | — | Demand-driven | — |

Sequencing notes: M2 before M3 because categories are queries (§6 item 2). M3 is the largest and riskiest UI milestone; do it before bank (M4) so bank reuses a proven layout engine. M5 before M6 because overlays like "alt owns this" need the Vault. Under goal **(C) learning**, swap M1 and M2 (engine first).

---

## 12. Risks register

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| Taint blocks item use in combat (the #1 technical risk, §5) | Med / Critical | §6 mechanisms; `/swagbag taint` checklist before every release; one-button-per-slot invariant tested |
| Bank/warband API churn (reagent bank removed 11.2, tab enumeration differs on Forever, §5) | High / High | Adapter + `FetchPurchasedBankTabIDs` only; capability degradation; Safe Mode for bank separately |
| `SortBags` from addon code disallowed or unreliable (§5 unverified) | Med / Med | Own idempotent mover (§6 item 15) is already designed as "later"; MVP ships delegation with a visible fallback message |
| Layout engine too clever → items stuck/invisible | Med / High | Pure-Lua, heavily tested; placeholder invariant ("every slot with an item has a visible button") asserted in debug builds |
| Cross-character SavedVariables bloat | Med / Med | Hard size budget (§8), compact strings, no caches persisted (§7 item 6), per-character purge UI |
| Grammar ambiguity / untested branches (§7 items 1, 10) | Low / Med | Fixed precedence, positioned errors, `Validate` force-true/false passes, busted coverage per keyword |
| Scope creep toward ArkInventory (§1 "most complex") | High / High | Non-goals list; "later" tier requires evidence; Pat is not the MVP persona |
| One maintainer (every competitor, §2 item 9) | Certain / Med | §9 bus-factor mitigations; automated release |
| Forever assumptions wrong (modern API family) | Med / Med | Isolated to `api_forever.lua`; Forever slips out of v1 without affecting Retail |
| Secret values poison tooltip-derived fields (§5) | Med / Low | `issecretvalue()` guard → tri-state `nil`; uncollected overlays degrade gracefully |
| Competitor momentum (Baganator near-daily releases, Bagforge new entrant, §1) | High / Med (only under goal B) | Differentiate on the five points in §1.1 rather than feature parity; ship Forever support early |

---

## 13. Open questions for the user

1. **Goal:** personal, public, learning, or mix? (Default assumed: personal-first, public second — see §0.)
2. **Flavors:** Retail only, +Forever, +Classic families? (Default: Retail MVP, Forever v1.)
3. Which bag addon do you use today, and which categories/rules would you be sad to lose? (Shapes importer priority in M8 and the default category set in M3.)
4. Is embedding Ace3 libraries (AceDB for profiles, LibDataBroker, CallbackHandler) acceptable, or do you want zero external libs? **[assumption: embed AceDB-3.0 and CallbackHandler only.]**
5. License preference for a public repo (MIT vs GPL-3 — GPL matters if we later borrow from GPL'd addons like ArkInventory).
6. Do you want Masque/ElvUI button-skin compatibility in MVP, or is the default look enough until v1?
7. Appetite for a "Blizzard-look" theme preset for the casual persona vs. a single custom look?
8. Should the default category set be opinionated (≈15 sections) or minimal (≈6) on first run?
9. Do you own/raid on characters where combat testing is realistic (needed to validate §6 before MVP)?
10. Is TSM integration something *you* need (affects whether the plugin API moves from "later" to v1)?
11. Would you accept Syndicator as an optional provider for AH/mail data later, or should SwagBag stay fully self-contained?
12. Housing decor "uncollected" detection may require tooltip parsing until an API exists — acceptable as a tooltip-derived, GUID-cached exception?
