# Search: armor types and "everything in an item is searchable" (2026-10-26)

Agreed with the user in writing on 2026-10-26 (grilling rounds Q1-Q14). Target version 0.16.0. Retail and the
Forever flavor both keep working; Forever gates use `A.Has` / `A.Allows`, never the Interface number.

## What the user agreed

| # | Decision |
|---|---|
| Q1 | Bare `cloth` and `leather` match BOTH the crafting material and that armor type. `cloth armor`, `leather armor`, `mail armor`, `plate armor` match the armor only. Bare `mail` and `plate` are armor. `shield`, `libram`, `idol`, `totem`, `sigil`, `relic` too (they simply match nothing where the client has none). |
| Q2 | `armor` and `gear` keep their meaning (the whole armor class; armor or weapon). |
| Q3 | Every fact with a real API is searchable (list in Q9). |
| Q4 | Plain words never read tooltips. |
| Q5 | Secret (Midnight, in an instance) values are unknown (`nil`) and dim; never guessed. |
| Q6 | A fact the Forever client lacks never matches there, and its keywords are hidden from the Forever editor. |
| Q7 | `text:fire` (alias `tip:fire`), with quotes for phrases (`text:"fire damage"`), searches tooltip text. The only free tooltip search. |
| Q8 | `text:` matches the whole tooltip body, case-insensitive substring. Secret lines -> unknown. |
| Q9 | Stats `crit`, `haste`, `mastery`, `vers`, `leech`, `avoidance`, `speed`, `str`, `agi`, `int`, `stam` (bare = has it, numeric = `crit>200`); `sockets` (any socket), `socketed` (all filled), `sockets>1`; expansion names (`classic` ... `tww`, `midnight`) and `expansion=N`; `set`; `transmog` (appearance not collected); `bonus=N`; `dps` (alias `damage`, numeric). Unavailable -> skipped silently, hidden on Forever. |
| Q10 | (Fact, no change) item-level forms `>=620`, `600-640` already exist. |
| Q11 | `fire damage` / `damage fire` (either order) for fire, frost, nature, shadow, arcane, holy, physical; bare `damage` = any of them. Reads the tooltip for these phrases only, gear only; fills in as tooltips load; help says so. |
| Q12 | No other built-in tooltip phrases for now; `text:` covers the rest. |
| Q13 | `text:` and damage phrases work in saved categories, with a per-item cached tooltip result; the editor marks them "reads tooltips". |
| Q14 | New `cloth material` / `leather material` (crafting goods only). The default "Leather & Cloth" category switches to them. A one-time login note names the user's own saved rules that use bare `cloth`/`leather`; nothing is rewritten. |

Also applied (follow from Q4): tooltip-reading keywords never join the search box's prefix expansion (`fire` must
not turn into `fire damage`). Expectation set in the help: on Retail few modern items carry "+X Fire Damage" lines.

## Design notes

- **Recorded exception to P7** (design doc section 2): tooltip text is read only for `text:` and the damage phrases,
  through `C_TooltipInfo` (feature-detected, secret-guarded), never for core fields. The design doc gets this line.
- **Where facts come from** (all in `Core/Adapter.lua`):
  - armor subclasses: `A.ARMOR_SUB` gains Generic, Cloth, Leather, Mail, Plate, Shield, Libram, Idol, Totem, Sigil,
    Relic with 12.1 numbers, overridden from `Enum.ItemArmorSubclass` as today.
  - `A.GetItemInfo` also returns `setID` (the return it skips today); the record gains `expansionID`, `setID`.
  - `A.ItemStats(link)` -> `{ crit, haste, mastery, vers, leech, avoidance, speed, str, agi, int, stam, dps,
    emptySockets }` from `C_Item.GetItemStats` (or the global `GetItemStats`), `nil` when unavailable or secret.
  - `A.ItemGemCount(link)` filled sockets (`C_Item.GetItemGem` 1..4); `A.BonusIDs(link)` pure link parse.
  - `A.TooltipLines(record)` -> list of lower-cased lines | `nil` (not loaded, secret) | `false` (no API), from
    `C_TooltipInfo.GetBagItem` (bag items) or `GetHyperlink` (guild, alt items).
  - expansion: a new `A.FEATURES.expansion` (forever = false until verified) and a new surface `keyword`, so
    `A.Allows("keyword", word)` hides those words on Forever.
- **Cost:** stats, gems, bonus IDs and tooltip lines are read lazily, only when a query uses such a keyword, and
  cached per instance key (`Items.Key(record, "instance")`) in a new `Engine/ItemFacts.lua`; the cache drops on
  the existing item-info-received / inventory-changed signals so "fills in as tooltips load" works.
- **Query engine:**
  - Parser: a WORD starting `text:` or `tip:` (the lexer already keeps `:` in words) becomes
    `{ type = "tip", value }`; `text:` followed by a quoted STRING takes the string; `text:` with nothing -> error
    `TIP_VALUE`. `Query.Pretty` prints `text:"value"`; Parse(Pretty) round-trips.
  - Keyword defs gain `tooltip = true` (damage phrases); prefix expansion skips them.
  - A `value` may return a list of numbers (bonus IDs): a comparison is true when any number passes.
  - `Rows` gains row kind `tip` (editor: "Tooltip text contains"), `Problem` rules for it, lossless as today.
  - `Rows.FAMILIES`: armor types join Type; new families Stats (numbers), Sockets & sets, Expansion, Damage type.
    On Forever the editor filters words through `A.Allows("keyword", word)`.
- **Search dimming:** unknown (`nil`) dims, as today, including glows and overlays; verify with a spec on the
  search path for a tooltip keyword that is still loading.
- **Login note (Q14):** generalise the `locked` note pattern (`Engine/Locks.lua` KeywordNote) for `cloth`/`leather`
  with its own `SwagBagDB.notes.clothLeatherKeyword` flag.

## Tasks (test-first; `scripts/check.sh` green after each)

1. **Adapter facts.** `ARMOR_SUB`, `setID`, `ItemStats`, `ItemGemCount`, `BonusIDs`, `TooltipLines` (secret and
   missing-API cases), `FEATURES.expansion` + `keyword` surface. Specs: `adapter_spec`, `adapter_forever_spec`;
   `spec/mock_adapter.lua` gains the same.
2. **Records and fact cache.** `expansionID`, `setID` on both record builders; `Engine/ItemFacts.lua` with lazy
   reads and invalidation. Specs: `items_spec`, new `itemfacts_spec`. TOC load order.
3. **Armor keywords and the cloth/leather change.** Armor-type words and phrases, broadened `cloth`/`leather`,
   `cloth material`/`leather material`, default category query, login note. Specs: `keywords_spec`,
   `categories_spec` (defaults), note spec.
4. **Structured fact keywords.** Stats, `dps`/`damage`, sockets, expansion names + `expansion=N`, `set`,
   `transmog`, `bonus=N` (list values in Query). Specs: `keywords_spec`, `query_spec`.
5. **Tooltip search.** Parser/Query/Pretty/Validate for `text:`; damage phrases with `tooltip = true`; prefix
   expansion skip; Rows `tip` kind; editor row and "reads tooltips" note in `UI/SettingsCategories.lua`. Specs:
   parser, query, `query_rows_spec`, `settings_categories_spec`, dimming spec.
6. **Families, help, docs.** `Rows.FAMILIES` + Locale labels, Forever filtering, keyword help and the tour's
   search line (`L.TOUR_SEARCH`), design doc (P7 exception, 7.3 table, 7.5 #7), `CHANGELOG.md` 0.16.0 entry.
   Final `scripts/check.sh`.

Not in scope: pushing, CurseForge upload, the TOC version bump (release time), committing (only when asked).
