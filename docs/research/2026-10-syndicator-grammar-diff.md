# Desk spike F: SwagBag vs Syndicator search grammar

Date: 2026-10-01. Clean-room note: Syndicator is GPL. It was read only to understand behaviour. Nothing below is copied code. Behaviour is described in our own words, and only single keywords/tokens are quoted.

## Sources

| ID | Source | Status |
|---|---|---|
| S1 | `hippuli/Syndicator` mirror, `Search/CheckItem.lua` (2494 lines), commit `bc404b4` (2026-09-28), TOC Version 284. `main` and `master` are identical | read |
| S2 | same mirror, `Locales.lua` (English keyword strings at lines 58-152) | read |
| S3 | same mirror, `Search/SearchEverywhere.lua` (search term lower-cased at line 427) | read |
| S4 | CurseForge Syndicator page, https://www.curseforge.com/wow/addons/syndicator (search help: `&`, `\|`, `!`, `155`, `<250`, `>150`, `110-140`) | read |
| S5 | CurseForge Baganator page, https://www.curseforge.com/wow/addons/baganator (defers to Syndicator for syntax) | read |
| S6 | Wago Baganator category exports `afKmnD5mg`, `-io95A_tu` (raw JSON via data.wago.io) | read |
| S7 | Upstream `TheMouseNest/Baganator` and `TheMouseNest/Syndicator` GitHub repos and wikis | **unreachable** (API returned nothing). Verdicts rely on S1-S5 |

Line numbers below refer to S1 unless stated otherwise.

## How Syndicator evaluates a search (summary, own words)

1. **Tokeniser** (`ProcessTerms`, ~2040-2078). It trims the string. If none of the characters `~ & | ( ) !` appear, the whole string is a single term. Otherwise it splits only on those characters, trimming the whitespace around each one. `||` is folded to `|`. Spaces, `#`, `<`, `>`, `=`, `-` and `"` are **not** separators.
2. **Combiner** (`ApplyTokens` / `BlendOperations`, ~1927-2038) uses three levels: `|` (0), `&` (1), `!`/`~` (2). In practice this gives fixed precedence `!` > `&` > `|`, with parentheses as sub-groups. An unbalanced `)` silently ends parsing, a missing `)` is tolerated, and an empty search matches everything. **No errors are ever raised.**
3. **Term resolution** (`ApplyKeyword`, ~1851-1925), applied in this order:
   - (a) **Prefix keyword lookup.** Every registered keyword that *starts with* the term is collected (`BinarySmartSearch`, ~1571-1590). If there is at least one, the item matches when its **name/tooltip text contains the term**, or when **any** of the collected keywords is true. For example, `key` also hits `keystone`, and `pot` hits `potion`.
   - (b) **Patterns** (table ~1735-1742), used only when no keyword prefix matched. The item's name contains the term, or one of these holds:
     - `N`, `=N`, `<N`, `>N`: item level
     - `N-M`: item-level range
     - `Ng|s|c` with an optional `<`/`>`/`=`: auction value
     - `Ng-Mg`: auction value range
     - `#word`: exact keyword
   - (c) Otherwise the term is a plain text search over the item name **and** selected tooltip lines (`GetTooltipSpecialTerms` / `MatchesText`, ~1756-1816). Those lines are coloured lines, "Use:"/"Equip:" lines, the upgrade-track line, the "Requires" line and equipment-set names.
4. **Tri-state.** Every check may return nil when data is not loaded. `&` and `|` pass nil through, and `!` leaves nil as nil (~1927-1966).

## Verdicts

### Q1. What does `#` mean? **Verdict: same** (keep `#`, do not move to `=word`)
Evidence: `ExactKeywordCheck` ~1726-1733 and the `^#.*$` pattern ~1741. `#word` looks up `word` as an **exact** keyword name, with no prefix expansion and no tooltip text. An unknown `#word` is silently false. The pattern wrapper also ORs in a name-substring test for the literal text including the `#`, which in practice never matches.
- Our `#` (keyword-only) has the same meaning. **One difference:** we raise a compile error (`KEYWORD`) for an unknown `#word`, while Syndicator silently returns false. Real Wago strings OR together keyword spellings that do not all exist (e.g. `#tradeable loot | #tradable loot`), so our strictness invalidates whole imported categories (see Wago table).
- `#` also takes multi-word phrases there (`#battle pet`, `#item enhancement`). Ours accepts the phrase too (Parser.lua `HASH` then `phrase()`).

### Q2. Adjacent words: phrase or implicit AND? **Verdict: same (phrase)**
Evidence: `ProcessTerms` ~2040-2078 splits only on operator characters, so `healing potion` is a single term. `epic boe` becomes one term `epic boe`. No keyword starts with that, so it falls through to a text search and in practice matches nothing. This matches our behaviour. Our §7.5 item 1 wrongly implies a divergence.

### Q3. `gear<N` / `ilvl<N`. **Verdict: diverges**
Evidence: `ItemLevelPatternCheck` ~1651-1669, patterns ~1736, keyword `gear` = equipment (S2 line 73; registration ~1098).
- Syndicator has **no** `ilvl`, `lvl` or `gear<N` syntax. An item-level test is a **bare number term**: `536` (equal), `=536`, `<536`, `>536`. To combine it with gear you write `#gear & <536` (seen on Wago).
- **`<` and `>` are inclusive** in Syndicator: `<536` means item level <= 536, and `>150` means >= 150. S4 states the same in prose. There is no `<=`/`>=`.
- A bare number also matches item names containing that number.
- `gear<210` in Syndicator is a single term (`<` is not a separator). It matches no keyword prefix or pattern, so it becomes a name search and in practice matches nothing.
- **Ours:** `ilvl>250` and `gear<210` are extensions. A bare `<536` is a **parse error** (`VALUE`): the lexer emits `OP` first, and `parsePrimary` needs a WORD. **This breaks common Wago strings.**
- Item level source: on retail, Syndicator reads it from the tooltip "Item Level" line, so non-gear items with an item level also count. On classic it uses armor/weapon only (~1594-1648).

### Q4. Ranges. **Verdict: diverges** (they have ranges, we do not)
Evidence: `ItemLevelRangePatternCheck` ~1671-1678 and the `^%d+%-%d+$` pattern; S4 example `110-140`.
- Syntax: `N-M` as a whole term with no spaces and no keyword prefix. It is **inclusive on both ends**. There is no `ilvl 400-450` form, and `200<ilvl<250` does not exist either.
- Gold: `Ng-Mg` (also `s`/`c`) needs an auction price source (`AHValuePatternCheck` ~1701-1724 and the range pattern ~1740).
- **Ours:** `400-450` lexes as a single WORD and becomes a **name-text match**. It silently means something different, with no error shown. This is worse than an error.

### Q5. Comparison after multi-word text (`a b ilvl>5`). **Verdict: diverges (benign)**
Syndicator does not split at `<`/`>`, so `a b >5` is one term. It matches no keyword or pattern and becomes a text search that in practice matches nothing. There is no error. Our positioned `AND_BEFORE_COMPARISON` error is stricter and more helpful. Keep it, but make sure the suggested fix `a b & >5` parses once bare comparisons exist.

### Q6. Operators, precedence, quoting. **Verdict: mostly same; three gaps**
- `&`, `|`, `!`, `( )`: same, with fixed precedence `!` > `&` > `|` (levels ~1974-1978). Our §7.5 item 2 suggests Syndicator might be left-to-right. It is not. Verdict: same.
- `~` is a **synonym for `!`** in Syndicator (~2002, ~1957). We lack it. Verdict: diverges.
- `||` is accepted as `|` (~2050). We would see an empty operand and raise an error. Verdict: diverges.
- Repeated `!!a` is a single NOT there, a double NOT for us. This is an edge case; ignore it.
- Quoting: Syndicator has **no quotes**, so `"` is a literal character. Ours: `"..."` is text. No Wago sample used quotes, so the impact is low. Note it only.
- Error handling: Syndicator is lenient and never errors. Ours shows errors (deliberate, keep).
- nil in `|`: Syndicator returns nil at the first nil operand even if a later operand is true. Ours: **unknown**. Check Query.lua `build` and decide; both are defensible.

### Q7. Keyword vocabulary. **Verdict: diverges (many aliases missing)**
Syndicator keywords come from S2 (lines 58-152). Its dynamic keywords (~2106-2470) are item class names (`consumable container weapon gem armor reagent tradeskill item enhancement recipe quest key miscellaneous glyph battle pets profession housing`), every subclass name for the trade goods, armor, weapon, recipe, consumable, profession and housing classes, socket types, stats, expansions and qualities. A keyword name may be registered several times (e.g. `leather` = trade-goods leather OR leather armor). Any one being true matches.

| Concept | Syndicator (enUS) | SwagBag | Action |
|---|---|---|---|
| equippable | `gear`, `equipment` | `gear` | add alias `equipment` |
| BoE | `boe`, `bwe` | `boe` | add `bwe` |
| bind on use | `bou` | – | add `bou` (nice) |
| soulbound | `soulbound`, `bop` (both = currently bound) | `soulbound`, `bound`, `bop` (= bind type) | **semantics differ for `bop`**: document it, or make `bop` = bound |
| account | `boa`, `account bound`, `warbound`, `wue`, `warbound until equipped` | `boa`, `warbound`, `wue` | add `account bound`, `warbound until equipped` |
| tradeable | `tradeable loot`, `tradable loot` | `tradeable` | add both phrases |
| junk | `junk`, `trash` (poor AND has a vendor price) | `junk` (quality 0) | add `trash`. Small semantic difference |
| trade goods | `tradeskill` (retail class name), `trade goods` (classic), subclasses `parts elemental metal & stone meat herb cloth leather enchanting fish …` | `tradegoods`, `trade goods`, `herb ore leather cloth enchanting` | add `tradeskill`, `elemental`, `parts`, `meat`, `fish`, `metal stone`-style alias |
| reagents | `reagent` (class), `crafting reagent`, `optional reagents`, `finishing reagents` (subclass names) | `reagent`, `crafting reagent` | add `optional reagents`, `finishing reagents` |
| pets | `pet`, `battle pet`, `battle pets` | `pet` | add `battle pet(s)` |
| slots | `one-hand two-hand main hand off hand off-hand held in off-hand helm cloak bracers gloves belt boots` | `mainhand offhand twohand head back wrist hands waist feet` | add the spaced/hyphenated aliases |
| prof. gear | `profession` (class), `profession tool`, `profession equipment` | `profession tool`, `profession gear` | add `profession`, `profession equipment` |
| consumable subclasses | `potion elixir flask scroll food & drink item enhancement bandages explosives devices` | `potion flask elixir food drink rune` | add `item enhancement`, `bandages`, `scroll` |
| recipe subclasses | profession names (`alchemy`, `inscription`, `leatherworking`, `tailoring`, `cooking`, `fishing`, `first aid` …) | `recipe`, `cooking`, `enchanting` | add the profession names (nice) |
| upgrade | `upgrade` = "is an upgrade for you" (external hook) | `upgrade` = has an upgrade track | **same word, different meaning**: document it |
| other item details | `set`, `equipment set`, `set bonus`, `socket`, `socketed`, `use`, `usable`, `open`, `read`, `stacks`, `stackable`, `unique`, `conjured`, `refundable`, `crafted`, `pvp`, `my class`, `collected`, `uncollected`, `catalyst`, `tier token`, `knowledge`, `active season`, `vendor`, `currency`, `objective`, `azerite`, `anima` | `equipped` (in set), `usable`, `locked`, `cooldown`, `collected`, `uncollected` (v1.1) | add `open`, `socket`, `set`/`equipment set`, `pvp` first |
| expansion | `classic vanilla bc tbc wrath wotlk cata mop wod draenor legion bfa sl shadowlands df dragonflight tww war within midnight`, `current expansion` | `expansion=current` | add the words (static, cheap) |
| quality | `poor common uncommon rare epic legendary artifact heirloom wow token` | same, plus colour aliases | same |
| ours only | – | `ilvl lvl level count stack tab new cooldown partial equipped bags backpack reagentbag bank warband value questitem decor ore rune` | keep. These are SwagBag extensions |

### Q8. Unknown words and case. **Verdict: diverges (scope), same (case)**
- Unknown word: Syndicator matches name **plus tooltip lines** (coloured lines, Use:/Equip:, upgrade track, Requires, set names; ~1756-1816). S5 advertises searches like "reputation" this way. Ours: **name only**. Also, a bare word that is a keyword *prefix* matches the keyword(s) **or** the text in Syndicator. For us, a bare keyword means the keyword only.
- Case: Syndicator lower-cases the search (S3 line 427) and the item text, and keywords are stored lower-case. Search is case-insensitive, same as ours.

## Wago examples (S6)

"Parses?" uses our current grammar and registry. "Same meaning?" assumes it parses.

| # | Search string | Parses in SwagBag? | Same meaning? |
|---|---|---|---|
| 1 | `#key` | yes | yes (theirs also includes keyring-family items) |
| 2 | `#tradeable loot \| #tradable loot` | parses, **compile error** (unknown `#` keyword) | – |
| 3 | `#toy` | yes | yes |
| 4 | `#gear & <536` | **no** (bare comparison) | – (theirs: ilvl <= 536) |
| 5 | `#gear&<80` | **no** | – |
| 6 | `#armor` | yes | yes |
| 7 | `#profession` | compile error | – |
| 8 | `#elemental` | compile error | – |
| 9 | `#finishing reagents \| #optional reagents \| #crafting reagent \| #reagent` | compile error (2 unknown) | – |
| 10 | `#food` | yes | yes |
| 11 | `!gear & (#leather \| #leatherworking)` | compile error (`leatherworking`) | `leather` is narrower for us (trade goods only?) |
| 12 | `#battle pet \| #battle pets` | compile error | – |
| 13 | `#open` | compile error | – |
| 14 | `#cooking \| #fish ` | compile error (`fish`) | – |
| 15 | `#boe \| #bwe` | compile error (`bwe`) | – |
| 16 | `#consumable` / `#recipe` / `#gem` / `#weapon` | yes | yes |
| 17 | `#herb \| #alchemy \| #inscription` | compile error | – |
| 18 | `soulbound` | yes | yes in practice (theirs also ORs a tooltip-text match) |
| 19 | `boa` / `boe` (bare) | yes | yes |
| 20 | `open` (bare) | yes, but as a **name** search | **no** (theirs = openable keyword) |
| 21 | `#tradeskill \| #reagent` | compile error (`tradeskill`) | – |
| 22 | `#weapon \| #off-hand` | compile error (`off-hand`) | – |
| 23 | `#tabard \| #shirt`, `#quest`, `#junk`, `#trinket`, `#wue`, `#housing` | yes | yes (`#junk` minor difference) |
| 24 | `hearthstone` | yes (name) | yes in practice |

Result: about 11 of the 24 rows import cleanly today. Every failure has one of two causes: bare item-level comparisons, or `#` keywords we have not registered.

## Proposed spec §7.5 updates (replacement text)

### 7.5 Known divergences from Syndicator (documented, surfaced in the editor)
Verified against Syndicator v284 by desk spike F (`docs/research/2026-10-syndicator-grammar-diff.md`).
1. **Adjacent words are a phrase in both.** `healing potion` is one term. Use `&` for conjunction. (Not a divergence; kept for clarity.)
2. **Precedence is the same** (`!` > `&` > `|`, parentheses group). `~` is accepted as a synonym for `!`, and `||` as `|`.
3. **Errors are shown, not swallowed.** Syndicator silently ignores unbalanced parentheses and stray operators. We mark the category invalid and keep the previous compiled version. The single exception is that an **unknown `#keyword` is a warning, not an error**: it evaluates `false`, as in Syndicator, so imported OR-lists of alternative spellings keep working.
4. **Undefined branches are defined.** Numeric comparisons on items lacking the field evaluate `false`.
5. **Tri-state:** unloaded data gives `nil` (same idea as Syndicator).
6. **`#` is exact keyword in both** (no prefix expansion, no text). Confirmed; the `=word` fallback is dropped.
7. **Bare words search names only.** Syndicator also searches selected tooltip lines and treats a word as a keyword *prefix* (`pot` finds potions). We match whole keywords, else the item name. The editor hints at the nearest keyword.
8. **Item-level syntax.** Syndicator-style bare terms are accepted: `N`, `=N`, `<N`, `>N` (Syndicator's `<`/`>` are **inclusive**, so bare `<N` means `ilvl<=N`), and `N-M` (inclusive range). Our named forms `ilvl>N`, `gear<N`, `lvl<N` are SwagBag extensions with **strict** `<`/`>`. A bare number does not also match item names.
9. **Quotes** are a SwagBag extension. In Syndicator `"` is a literal character.
10. **Same word, different meaning:** `upgrade` (ours: has an upgrade track; theirs: "is an upgrade for this character") and `bop` (ours: bind type; theirs: currently bound). These are shown in the editor's keyword help.
11. **`a b >5`** is a positioned `AND_BEFORE_COMPARISON` error for us. Syndicator treats it as a text search that matches nothing.

## Proposed plan actions for week 2

**Must for compatibility**
1. Lexer/parser: accept a bare comparison `OP NUMBER` as an item-level test with inclusive `<`/`>`. Accept a bare `NUMBER` as `ilvl=N`.
2. Range: accept a whole-term `N-M` as an inclusive item-level range. Today it is silently a name search, which is a correctness bug.
3. Unknown `#keyword`: downgrade from a compile error to a warning that evaluates `false`.
4. Accept `~` as NOT and `||` as OR.
5. Add the aliases needed by the Wago sample: `equipment`, `bwe`, `tradeable loot`, `tradable loot`, `tradeskill`, `profession`, `profession equipment`, `battle pet`, `battle pets`, `off-hand`, `off hand`, `main hand`, `two-hand`, `one-hand`, `held in off-hand`, `trash`, `account bound`, `warbound until equipped`, `elemental`, `fish`, `parts`, `optional reagents`, `finishing reagents`, `item enhancement`, `open`.
6. Spec §7.5: replace with the text above. Add tests: one fixture per Wago row with the expected AST.

**Nice to have**
1. Gold terms `>100g`, `10g-20g` mapped to our `value` keyword (needs `Prices`).
2. Expansion words (`tww`, `midnight`, `df`, `current expansion` …) as static keywords.
3. Profession-name recipe/subclass keywords (`alchemy`, `inscription`, `leatherworking`, `tailoring`, `first aid`, `fishing` …), plus `socket`, `set`, `equipment set`, `pvp`, `bou`, `stackable`, `unique`, `crafted`.
4. Optional tooltip-text matching for unknown words (volatile/instance cost). Defer until after M2.
5. Decide nil-in-`|` semantics explicitly (Syndicator: first nil wins). Verify in-game with Baganator: `boe | <nonloaded item>`.
6. Verify in-game with Baganator (S7 was unreachable): that `#tradeable loot` still exists, and that `<N` is inclusive in the current release.
