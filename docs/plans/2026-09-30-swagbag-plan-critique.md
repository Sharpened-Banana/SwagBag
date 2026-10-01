# SwagBag Plan: Adversarial Critique

*Reviewing: `docs/plans/2026-09-30-swagbag-plan-draft.md` against `research/bag-addon-landscape.md`. Date: 2026-09-30. Severity labels: **blocker** (the plan can't proceed as written), **major** (likely to cost weeks or sink a headline feature), **minor** (fix it while drafting).*

*How I verified things: I checked a few facts against warcraft.wiki.gg and Blizzard/GitHub sources, and each one is marked **(verified)** or **(unverified)**. I could not verify anything about WoW: Forever's API surface beyond one wiki note (see §3.9). Nothing here was tested in-game.*

---

## 1. Verdict

The plan is well organized and mostly faithful to the research. Its weakness is underneath: the hardest technical promises (placeholder layout on top of slot-bound secure buttons, Safe Mode without /reload, separate bank and warband windows) rest on mechanisms that conflict with how `ContainerFrameItemButtonTemplate` and the Blizzard bank frame actually work. It sequences them *after* the parts that are easy to unit-test. The MVP is several months of solo work disguised as a "daily driver". v1 adds at least two multi-month projects as single bullets (the visual rule builder, and importers for three addons). The headline differentiator, "category UI + alt data", is something Baganator + Syndicator users already have, so it won't make them switch. As written, I would not commit to the roadmap. Run the four spikes in §5 first, cut the MVP to a grid view plus search, and rebuild the differentiation story around layout trust and reliability. Neither of those is a feature list; both are earned in-game.

---

## 2. Top 5 issues that must change

### Issue 1: The secure-button model contradicts the layout model (**blocker**)

**Evidence.**
- §4.9 defines `Place(button, x, y, parentSection)`. §6 and the research (§5) say buttons are "never reparented after creation", and they must stay parented to a per-bag frame with `SetID(bagID)`.
- Blizzard's click path reads the bag through the button's parent. `ContainerFrameItemButton_OnClick` uses `self:GetBagID()` and `self:GetID()`, and reparenting a button makes it query the wrong parent and causes taint (verified via the LiteBag source and AdiBags GetBagID issue #728). An addon that reparents a button to a section frame either uses the wrong bag's item or taints.
- Sections mode also needs things the plan never specifies:
  - **Placeholders.** A placeholder can't be the slot's own button, because that button now shows whatever item Blizzard put in that slot. Looting fills the first empty slot, which may be the "placeholder" left by a potion you just used. Placeholders therefore have to be separate, non-secure dummy frames, and the plan never says so.
  - **Empty slots.** Sections views normally collapse empty slots. Where do they render, and what does a drop onto a placeholder do?
  - **Scrolling.** A bank of more than 1,000 slots needs a scroll frame, and the per-bag parents must live inside the scroll child.
- In combat, the plan's "Incoming strip" depends on `SetPoint`/`Show` on these buttons being legal. The plan admits this is unverified (§6). If it fails, newly looted items in sections mode are invisible for the whole fight, which is exactly when a raider needs a potion they just picked up.

**Fix.** Write a one-page "button and placeholder contract" before M1:
- Buttons are permanently parented to per-bag frames, which are parented to one scroll child. Only `SetPoint` moves them.
- Placeholders are a separate insecure pool.
- Empty slots render in an explicit "Free" section made of real slot buttons, which is also the drop target.
- Define what happens in combat for each case: item arrives, item leaves, a placeholder is clicked.

Then prove the contract with Spike A (§5) before writing the layout engine.

### Issue 2: Safe Mode without /reload and the bank model are asserted, not designed (**blocker for the bank, major for bags**)

**Evidence.**
- Research §4 lists "toggle without /reload" as a *player wish*. Nothing in the research says it is achievable. The plan promotes it to differentiator #2 and an MVP feature.
- Bags are the tractable half: a guard inside a `hooksecurefunc` hook works. But the plan never says how Blizzard's own bag frames are *suppressed* while SwagBag is on. With post-hooks, Blizzard's frames still open, so you must hide or reparent `ContainerFrame*` / `ContainerFrameCombinedBags`, and you must un-suppress them to fall back. Doing that from addon code in combat is the classic taint path.
- The bank is worse. Blizzard's item click handler consults `BankFrame:GetActiveBankType()`, and an addon writing `BankPanel.bankType` blocks hearthstone and every other item use (verified, Blizzard forum thread "Warbank and taint"). That handler is what decides whether a right-click deposits to the character bank or the warband bank. The plan has **separate Bank and Warband windows** but no untainted way to tell Blizzard which one is active. So right-click-to-deposit in SwagBag's warband window may silently deposit into the character bank, or the reverse.
- ESC behavior: "ESC hides our frame and calls nothing" (§6) leaves the bank interaction open. A later right-click on a bag item then deposits it into a bank the user believes is closed.
- §9 auto-flips a window to Safe Mode on any Lua error. If that happens in combat, the addon is calling Blizzard bag-opening code from a tainted path. The fallback creates the taint it was meant to avoid.

**Fix.**
- Downgrade Safe Mode to "per-window fallback, applied out of combat; bank fallback may require /reload until Spike B proves otherwise." Queue auto-fallback to `PLAYER_REGEN_ENABLED`.
- Model the bank as *one* window whose character/warband tab switch is driven by Blizzard's own tab control (left visible or proxied), not by SwagBag state.
- Make "how does right-click know the destination?" Spike B's exit criterion.
- Move the bank out of MVP if Spike B fails. Bags-only is still a daily driver.

### Issue 3: The MVP is not a "personal daily driver" scope, and v1 hides multi-month projects (**major**)

**Evidence.** The MVP contains:
- a new grammar, compiler and tri-state evaluator;
- a diffing layout engine with placeholders;
- two view modes;
- secure pooling for about 1,280 slots (backpack + 4 bags + reagent ≈ 200, plus 6 character tabs × 98 = 588, plus 5 warband tabs × 98 = 490);
- bank and warband;
- Safe Mode;
- profiles;
- CI.

M3 alone is rated "L", and it is the part Issue 1 shows is underspecified.

v1 then adds:
- **The visual rule builder.** WoW has no tree or table widget. An AST editor with nested AND/OR groups, keyword pickers, value editors, a canonical pretty-printer and "100% grammar coverage" is easily the biggest UI build in the project.
- **Three importers.** Each one means reverse-engineering another addon's SavedVariables format and query semantics (see Issue 4).
- **A cross-character store.**
- **Overlays.**
- **Localization.**
- **A Forever port.**

There is no time estimate anywhere, and the user's experience level is unknown.

**Fix.**
- Re-cut the MVP to: bags only, grid mode, search with full dim, combat-safe pool, one-click fallback, and the CI and self-test pieces.
- Make sections + stable layout the second milestone, and ship nothing to anyone until it has survived two weeks of daily play.
- Move the visual builder to "Later". In v1, ship a *keyword picker with autocomplete* instead.
- Cut importers to paste-string import of Baganator/Wago category strings only.
- Put rough calendar ranges on milestones once the user states hours per week.

### Issue 4: Importers can't read what the plan says they read, and the grammar is "close to Baganator's" by assertion (**major**)

**Evidence.**
- §10 reads other addons' SavedVariables "only if that addon is loaded". A user who is switching has usually *disabled* the old bag addon, and a disabled addon's SavedVariables aren't loaded. Non-LoadOnDemand addons can't be loaded mid-session. The supported flow is therefore "run two bag addons at once for a session", and the plan doesn't design for that.
- "Grammar is close to ours" (Baganator) isn't in the research. The research says only that every Baganator category is a search string.
- The plan's `#` means "exact keyword, no fuzzy/localized match". In Syndicator-style search, `#` is a common keyword prefix (unverified in detail; worth confirming on the Syndicator mirror). Same-looking syntax with different meaning is the worst outcome: imported strings parse cleanly and match the wrong items.
- BetterBags categories defined in Lua can't be imported at all, which the plan does acknowledge.
- AdiBags is end-of-life, and its filters are modules rather than data, so its import value is low.

**Fix.** Settle the grammar question before M2 (see §4.2 below). If SwagBag keeps its own grammar, import becomes paste-string only, plus a documented "migration session" for SavedVariables import. Drop AdiBags import outright.

### Issue 5: The memoization key is wrong for half the keyword set (**major**)

**Evidence.**
- §4.4 and §4.6 memoize category assignment per `itemID:bindState:ilvl:suffix`. But the MVP keyword table includes slot-state and volatile predicates: `new`, `locked`, `cooldown`, `count`, `stack`, `usable`, `bag:`, `tab:`, `equipped`-set, and in v1 `upgrade` and `uncollected`. Any category rule using one of these returns stale results from the memo.
- Example: "Partial stacks" (`count<stack`) or "New" puts every copy of an item in the same category regardless of the slot.
- Caged battle pets all share item ID 82800 and differ only by link (`battlepet:` hyperlink). Keystones use `keystone:` links. Under this key, every pet collapses to one memo entry.
- §5.4 doesn't say whether a `nil` from a higher-priority rule *blocks* lower-priority rules. If it doesn't, an item lands in a lower category, then jumps once its data loads, which breaks the plan's own "no item moves while open" rule. If it does, Pending items need a place to draw while the window is open, and the plan never says where.

**Fix.**
- Tag each keyword as `static` (depends only on the item), `instance` (depends on link, GUID or bind state) or `volatile` (depends on slot or time).
- Memoize by the strongest key the compiled query requires, and never memoize volatile queries.
- Use the full hyperlink (or GUID) for battlepet and keystone links.
- State the rule "first `nil` in priority order blocks; the item draws in its *previous* category, or in Pending on first open".

---

## 3. Section-by-section challenges

### 3.1 §0 Defaults
- **Forever reasoning contradicts its sequencing (major).** §0 calls the Forever launch a "land rush" and "a real opening", then schedules Forever as the *last* v1 milestone (M9), after the rule builder and importers. Forever launches 2026-11-04. By the time M9 lands, the land rush is over. Either drop the land-rush argument, or make a thin Forever grid build an early side quest once the API dump exists.
- **Small Forever evidence (unverified).** warcraft.wiki.gg lists `C_Bank.FetchPurchasedBankTabIDs` with a "1.60.1 (Forever version)" patch entry. That partly supports the [assumption] about the modern API family. Community Forever addons (tweaks-forever, AKForeverBags) also mention Blizzard's combined bag and reagent bag on Forever. That contradicts nothing, but it suggests Forever has a reagent bag, so the `Caps` defaults matter.
- **The "~25% more test-matrix work" figure is invented (minor).** Mark it [assumption] or remove it.

### 3.2 §1 Vision and differentiators
- **Differentiator #1 doesn't create switchers (major).** Baganator already pairs a category view with Syndicator's alt, warband, guild, mail and AH data. The research says nobody does both "well", but gives no evidence for what "badly" means. The plan's phrase "category view is a mode, not the design center" is its own embellishment and isn't in the research. A Baganator user gains nothing they can name. A BetterBags user gains alt counts, which BetterBags could add in a weekend by consuming `Syndicator.API`.
- **What is copyable in a weekend:** the full-dim search, built-in junk and ilvl overlays, a "Reflow" button (Baganator and BetterBags already use placeholders, research §3), and a selftest command.
- **What is not copyable:** a track record of not breaking on patch day, and *provably* never moving an item under the cursor or blocking item use. Both are reputational and need months of uptime. For a public release the real moat is responsiveness plus trust, not features. Say so, and add a "patch-day response SLA you can actually keep" to §9.
- **Bagforge is not analyzed (major omission).** The research says Bagforge is Midnight-only and "already does button pooling, batched layout, slot locks, secret-value handling". That is the closest competitor to SwagBag's technical thesis, and the plan mentions it only as "momentum" in the risk table. Someone should read Bagforge's source before M1. It may answer Spikes A and C for free.
- **"Built-in overlays, no fragile plugins".** "Uncollected decor" is admitted to need tooltip parsing (§13 Q12). In Midnight that is exactly the secret-values exposure zone, so the "no fragile" promise and that one overlay are in tension.

### 3.3 §1.2 Non-goals
- These are good. One gap: no "No guild-bank *frame replacement*" line. The v1 guild snapshot also needs every tab queried (`QueryGuildBankTab`), and snapshots are partial unless the user clicks through each tab. State that the guild snapshot is "tabs viewed this session".
- "No vendor rule engine" is right, but the "junk coin icon" (MVP) and "one-click junk sell" (v1) need a source of truth. Is it quality == poor only, or does it consume Scrap/Vendor? Decide.

### 3.4 §3 Scope
- **Two view modes in MVP doubles the layout surface (major).** See Issue 3.
- **"Partial-stacks-first sort option" for Goldie is ambiguous (minor).** `SortBags` can't do it physically, so it can only be a display sort. Is that what a TSM user means? Ask.
- **Physical sort is low-value in sections mode (minor).** Physical order is invisible there except for stack consolidation. Consider "Stack" (consolidate) instead of "Sort" as the MVP verb.
- **Function names don't match (minor).** The plan says `SortBankBags`. The research says `SortBags/SortBank`. Since the 11.2 bank rework the bank sort entry point(s) are unverified. The wiki page for `C_Container.SortBags` is a stub with no protection info (checked). Spike C.

### 3.5 §4 Architecture
- **The engine/UI split is sound,** but the busted-tested half is the *low-risk* half. Every blocker above lives in the WoW-only column. CI green will create false confidence. Add an in-game scripted harness for the frame column (the `/swagbag` commands go some way).
- **§4.2 events.** These are missing:
  - `GET_ITEM_INFO_RECEIVED` / `ITEM_DATA_LOAD_RESULT` (Pending resolution);
  - `PLAYER_EQUIPMENT_CHANGED` (`equipped` keyword, upgrade overlay);
  - `BANK_TAB_SETTINGS_UPDATED`, or whatever fires on tab purchase or rename;
  - `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE`.

  The research flags "`PlayerInteractionFrameManager` removal in 12.1" as unverified, and the plan relies on `BANKFRAME_OPENED` without mentioning that open question at all.
- **§4.3 Vault.** It has a cold-start problem (see §4.1 below). Also, what happens to stored snapshots after a squish or a `GetItemInfo`-style API change? Store links, never derived values like ilvl, so they can be recomputed.
- **§4.9 Buttons.** Creation cost is never estimated. About 1,280 template buttons, each with a dozen or more regions, created on first bank open will very likely blow the "no frame > 8 ms" budget (unverified, measure it in Spike A). Time-slice creation per tab after login, out of combat, and make the bank tolerate tabs whose buttons aren't ready yet.
- **§4.10 Views.** "Hooks can't be removed, so the toggle flips the guard." Correct, but incomplete. See Issue 2: the hard part is suppressing and restoring Blizzard's frames, not the hook.
- **§4.11.** "Embed AceDB only" combined with "category sets are a separate profile dimension" means building a custom multi-dimensional profile system on top of AceDB, which AceDB doesn't do natively. That is medium-sized work, not a config footnote.

### 3.6 §5 Query language
- **Implicit AND contradicts phrase search (major).** `potion healing` as two ANDed terms is fine. But do `healing potion` and `"Healing Potion"` behave differently? Subtype names contain spaces and operators (`Metal & Stone`, `Cloth`, `Trade Goods`). With `&` as an operator, `type:Metal & Stone` mis-parses. Word operators (`and/or/not`) collide with item names ("Not-So-Secret ...", "Ore").
- **Localization is under-planned (major for public).** These are missing:
  - Lua's `string.lower` is byte-wise, so case-insensitive name match fails for Cyrillic and accented capitals (deDE, frFR, ruRU). Verify whether the client exposes a UTF-8 lowercase.
  - zhCN, zhTW and koKR have no word spacing, so implicit AND on whitespace is meaningless.
  - Localized quality names (`épique`) must parse.
  - Operator words need to be either English-only or localized. Decide which.

  None of this can wait until v1 if the grammar is fixed in M2.
- **The example values are pre-squish (minor, but telling).** `ilvl>500` is a dead example. Midnight's 12.0 squish compressed ~700 to ~100, and current item levels are roughly 100–300 (verified, Icy Veins). Use `ilvl:current-track` or relative keywords, and audit every numeric example.
- **`Validate` force-true/force-false passes (§4.5).** Explain what this means for tri-state. Does force-nil also need a pass? It probably does, because the Syndicator gold-range bug the research cites (§7 item 10) was an *undefined* branch, not a true/false one.
- **`cat:` forbidden in categories.** Defensible, but it removes a feature BetterBags users rely on (category composition). At minimum, allow `cat:` with cycle detection at compile time. A DAG check is cheap.

### 3.7 §6 Taint
- **`/swagbag taint` can't work as described (major).** Addons can't read files. `taint.log` is written to the client's `Logs/` folder, not to SavedVariables, and in-game Lua can't grep it. The command can set the CVar and run a scripted sequence. A human, or an out-of-game script, has to inspect the log. Rewrite this as a documented manual or tooling step.
- **"luacheck `globals = {}`"** needs a WoW globals read list (e.g. a `std` that includes WoW API globals), or it will flag every API call. This is a minor detail but it will cost a day.
- **Tooltip hooks.** Alt counts (v1) will hook `TooltipDataProcessor.AddTooltipPostCall` globally. That runs while the bags are closed (breaking the "idle CPU = 0" claim in spirit) and touches secret-value-bearing tooltips in combat. Specify "no tooltip additions in combat" or guard with `issecretvalue()` on every read, and budget for it.
- **The plan omits the item-click bank-type coupling,** which is the most relevant taint fact for this design. See Issue 2.

### 3.8 §7 Layout stability
- **Rule 1 vs Pending.** If Pending items resolve while the window is open, they move. Define it.
- **Rule 2 vs placeholders.** "A section can grow by one row; it never shrinks" means a session of looting and vending can leave a bag view with many dead placeholder rows, with no auto-cleanup until close. Ask whether that's acceptable UX (Baganator users tolerate gaps, but the plan should say so explicitly).
- **Rule 4 hover guard.** It also needs a *drag* guard (cursor holding an item) and a *modifier* guard (Shift held for split-stack).
- **Time-sliced cold open (§8) vs stability.** A 4 ms/frame time-sliced first render means items pop in over several frames, so the first open visibly assembles itself. That's fine if the frame is hidden until complete. Say which.

### 3.9 §8 Performance and storage
- **The ≤ 12 KB/character target misreads the research (major).** EllesmereUI's ~200 KB for 20 characters is an unknown scope ("Alts", not necessarily bank + warband + full links). The plan's v1 store holds roughly 200 bag slots + 588 bank slots per character, plus a shared 490-slot warband. The offline view and ilvl overlays need full item links, which run 60–150 bytes each for gear with bonus IDs. Aggregated `itemID:count` fits 12 KB. Full links for an offline view almost certainly don't. Pick one: an aggregated counts store (cheap), or an offline view (expensive), or separate budgets for each.
- **"Runtime ≤ 3 MB" (minor).** That's Lua heap only. Frame and texture memory for about 1,280 buttons isn't counted by `GetAddOnMemoryUsage` and isn't free. Say what is being measured.
- **Missing: SavedVariables schema versioning and migrations,** plus a "reset corrupted DB" path. Not optional for a public addon with a compact string format that *will* change.

### 3.10 §9–10
- **Bus factor (§9).** "Release fully automated so a co-maintainer can ship" is fine, but there is no co-maintainer. Don't count hypothetical people as mitigation.
- **Telemetry-free bug reporting is missing.** Add `/swagbag report`, which produces a copyable text block (version, flavor, Caps, selftest result, last 5 errors from a ring buffer, settings hash), and BugGrabber/BugSack compatibility.
- **Uninstall/rollback is missing.** Confirm that disabling SwagBag returns the user to unmodified Blizzard bags with zero residue, and that downgrading one version doesn't corrupt SavedVariables (store `schemaVersion` and refuse to load newer schemas).

### 3.11 §11 Roadmap
- **M1 says "taint log clean" as an exit criterion** with nothing to read the log with (see §3.7).
- **The riskiest unknowns aren't tested first.** Spikes A–C (secure buttons in combat, frame suppression and restore, bank right-click semantics) are the only things that can invalidate the architecture, and they sit inside M1/M4.
- **The M5-before-M6 rationale is wrong:** "overlays like 'alt owns this' need the Vault." That isn't one of the listed overlays (ilvl, bind, upgrade, uncollected, junk). M6 has no Vault dependency and could ship first. It's arguably more valuable to Rae, the MVP's primary persona.

### 3.12 §12 Risks: missing or underweighted
| Missing risk | Suggested rating |
|---|---|
| Bank deposit routing (character vs warband) depends on Blizzard state SwagBag can't write | High / High |
| Placeholder/slot-button identity confusion leading to wrong-item use or vendoring (the incident the plan cites) | Med / Critical |
| Button creation hitch on first bank open (~1,280 buttons) | High / Med |
| Developer time and motivation (solo, unknown hours) | High / Critical |
| Localization breaks the grammar (UTF-8 case, CJK tokenization) | High / Med (public) |
| SavedVariables schema migration bugs wipe user categories (a research §4 complaint: "categories lost on reload") | Med / High |
| Interaction with other bag-touching addons (TSM's bank UI, Scrap, Vendor, CanIMogIt overlays on *our* buttons) | Med / Med |
| Gamepad/controller mode: custom frames lack Blizzard's gamepad cursor navigation | Med / Low |
| Blizzard ships native category bags (they have been iterating on bag UI) | Low / High |
| Taint is underweighted at "Med" likelihood | High, until Spike A passes |

---

## 4. Steelmanned alternatives the plan dismissed

### 4.1 Consume Syndicator (optional dependency) instead of building the Vault
The plan's best argument is bus factor. But SwagBag's own bus factor is also 1, and its maintainer is newer to this problem. The arguments the plan didn't weigh:
- **Cold start.** An own store shows *nothing* for each alt until the user logs into that alt and visits its bank. Syndicator, at 28M installs, is already on most Baganator refugees' machines, full of years of alt data. Day-one alt counts are the switching hook, and only consumption delivers them.
- **Coverage for free.** Mail and AH, which the plan calls non-goals but which an altoholic sees as missing counts.
- **Effort.** Collapses M5 to a provider adapter, maybe a week.

Steelmanned design: **(c) inverted.** Syndicator is the preferred provider when present. A minimal built-in store (aggregated counts only) covers users without it. The provider interface the plan already sketches makes this cheap, so the only disagreement is the default.

### 4.2 Adopt Syndicator-compatible search syntax
- Users' muscle memory and every Wago category string work on day one, and import becomes trivial.
- The plan's real requirements are precedence, positioned errors and tri-state. They can be implemented as a *stricter parser for a compatible surface*: accept Syndicator syntax, and warn where its semantics are undefined.
- New keywords go in as a superset.
- The cost is inheriting some quirks. The benefit is deleting most of M8 and the `#`-collision risk.

At minimum, the plan should explicitly compare its EBNF with Syndicator's syntax (from the WowUp mirrors the research used) before freezing M2.

### 4.3 Build on Baganator instead of beside it
Baganator exposes an API for custom layouts, corner widgets and categories (verify the extent). For goal (A), personal use, the fastest path to "category-first, stable, with alt data" may be a Baganator plugin or skin plus upstream PRs. Zero secure-button risk and zero patch-day risk, because those are plusmouse's problem. The plan should at least say why this loses under each goal.

### 4.4 Grid-only MVP (Bagnon-shaped), sections later
This proves the dangerous 20% (secure pool, bank, combat, fallback) with the simplest layout, so you're daily-driving within weeks, not months. Sections then get built on a proven foundation, with real usage data on what the author actually wants categorized.

### 4.5 "Enhance Blizzard bags" for Forever
The plan dismisses LiteBag's model as "incompatible with category layout". For a Forever land-rush entry it's the most patch-resilient approach (research §1 niches), and Blizzard's combined bag on Forever is already the base. A small enhance-mode Forever addon shipped in November could build the audience and reputation the main product needs.

---

## 5. Recommended spikes (each 1–3 evenings, throwaway code)

| Spike | Question | Exit criterion |
|---|---|---|
| **A. Secure button lifecycle** | Can `ContainerFrameItemButtonTemplate` buttons parented to per-bag frames under a scroll child be `SetPoint`/`Show`/`Hide`/`SetAlpha`'d in combat? What does creating 1,280 of them cost? | Use a potion that arrived mid-combat from a moved button with no block popup. Creation time measured per 100 buttons. |
| **B. Blizzard frame suppression and bank routing** | Hide and restore `ContainerFrameCombinedBags` / `ContainerFrame*` / `BankFrame` without /reload. Does right-click from bags deposit to the tab the user is viewing (character vs warband) without writing `bankType`? What happens on ESC? | Toggle on/off 5× including once just before combat, then use hearthstone in combat with no block. Deposit lands in the intended bank type. |
| **C. Sort APIs** | Which of `SortBags` / bank sort entry points exist on 12.1.x and are callable from an addon button? | Each works from an addon click out of combat, or is documented as not working. |
| **D. Placeholder UX paper prototype** | Run loot, vendor, use, split-stack, drag-to-bank and drag-onto-placeholder in sections mode. Any ambiguity is a design bug. | A written state table with no "?" cells. |
| **E. Storage measurement** | Real SavedVariables size for your actual characters with links vs aggregated counts. | Numbers replace the 12 KB/300 KB assumptions. |
| **F. Grammar diff** | Syndicator syntax vs the draft EBNF, with 20 popular Wago strings run through both. | Decision: compatible surface or new grammar. |
| **G. Bagforge read-through** | How does Bagforge pool, place, and handle combat and the bank? | List of facts adopted or rejected. |
| **H. Forever API dump** (when available) | Bank enumeration, reagent bag, combined bag, sort APIs. | Go/no-go for Forever in v1. |

A, B and D should gate M1. E and F should gate M2/M5.

---

## 6. Questions the plan should put to the user

1. **What specifically is wrong with your current bag addon?** Name the moment it annoyed you most. If the answer is "nothing much", goal (A) is better served by §4.3.
2. **How many hours per week, and for how long?** Have you shipped a WoW addon before, or worked with secure templates and taint? This decides whether the MVP is 6 weeks or 6 months.
3. **Do you play WoW: Forever at launch?** If so, should a small Forever release come *first* (§4.5) rather than last?
4. **Would you accept Syndicator as an *optional* dependency for alt data,** given it's probably already installed and full of data?
5. **Do you use the bank and warband bank via right-click deposit?** If yes, Spike B's result decides whether the bank is in the MVP.
6. **Is bags-only grid view acceptable as the first daily driver,** with sections second?
7. **Do you want your existing Baganator/BetterBags/Wago category strings to work as-is?** If yes, that settles the grammar question.
8. **Which locale is your client?** If not enUS, localization moves into MVP.
9. **Do you play with a gamepad, or need colorblind-safe quality indication** (shape or letter, not just border color)?
10. **For public release: what patch-day response time can you actually commit to** (24h? a week?), given that's the stated #1 switching reason?
11. **How many characters do you have, and do you care about an offline item view** or only "you own N across alts" counts? This decides the storage design.

---

*Sources consulted beyond the two repo documents:*
- [warcraft.wiki.gg: C_Bank.FetchPurchasedBankTabIDs](https://warcraft.wiki.gg/wiki/API_C_Bank.FetchPurchasedBankTabIDs)
- [warcraft.wiki.gg: C_Container.SortBags](https://warcraft.wiki.gg/wiki/API_C_Container.SortBags) (stub)
- [Blizzard forums: Warbank and taint](https://us.forums.blizzard.com/en/wow/t/warbank-and-taint/2146874)
- [LiteBag BagButton.lua](https://github.com/xod-wow/LiteBag/blob/main/BagButton.lua)
- [AdiBags issue #728 (GetBagID)](https://github.com/AdiAddons/AdiBags/issues/728)
- [tweaks-forever PR #66](https://github.com/cjber/tweaks-forever/pull/66)
- [Icy Veins: Midnight stat squish](https://www.icy-veins.com/wow/news/the-midnight-stat-squish-will-make-your-numbers-look-absurdly-small/)
