# Bank / Warband bank UX: how other bag addons do it (2026-10-06)

Method: web search + page fetches only. Read-only; no code touched.

## Evidence quality (read this first)
- Reached: BetterBags README + issues, Bagnon issues and CurseForge changelog, ArkInventory issues, AdiBags issues (via search), Blizzard forum threads, Blizzard Watch (11.2 bank article), Warcraft Wiki (Warband Bank), CurseForge pages for Baganator, Bagnon, Sorted.
- NOT reached: Baganator GitHub issues/README (every github.com/Baganator or TheMouseNest URL returned 404 to the fetcher; only search-engine snippets and issue titles were available), Reddit (no mirror surfaced), YouTube, any screenshots. Everything below about Baganator's bank layout is therefore thin and partly inferred from titles. No screenshots were viewable; descriptions are text only.
- Sorted. and ElvUI: only store-page blurbs and search snippets. Treat as low confidence.
- Several fetch summaries came from a small model; issue numbers/dates are as reported by the fetch and worth a spot check before quoting.
- I could not find a Midnight (12.0/12.1)-specific Blizzard bank redesign. What exists is the 11.2 tabbed bank, which still applies. Do not assume Midnight changed it.

## 1. Blizzard's own bank UI (11.2 tabbed bank, carried into Midnight)
- Character bank and Warband bank are two separate views of one bank frame, switched by a tab/selector. Both have purchasable 98-slot tabs. Character bank: up to 6 tabs (1g up to 5,000g). Warband: 5 tabs (1,000g up to 2,500,000g; ~3.1M total). Sources: Blizzard Watch 2025-07-15, warcraft.wiki.gg Warband_Bank.
- Reagent Bank and Void Storage removed in 11.2; "any bank tab can now serve as a reagents tab"; migrated items got labelled tabs (Blizzard Watch).
- Tabs are renamed/iconed and given deposit filters (Equipment, Consumables, Profession Goods, Reagents, Junk, expansion) via right-click on the tab (Blizzard forum "Why do Warband bank tabs function as one", Aug 2024).
- Right-click deposit: before 11.2 it always went to the first available slots regardless of selected tab. Complaints: forum "Warband Bank Deposit Items UX Very Confusing" (2024-08-18, follow-up 2024-09-10, no Blizzard reply); "PLEASE Fix Warband Bank Deposit Bug" (2025-05-04, some replies say it is intentional category routing). After 11.2 Blizzard says right-click deposits into the current tab if possible (Blizzard Watch). The wiki still says right-click "goes based on the type of items in each tab", so the rule is genuinely murky even to players.
- "Deposit All Warbound Items" button, and a bank-type API so addons can detect which bank (Player vs Warband) is currently shown (search snippet citing wiki/BankItems PR; moderately reliable).
- Player complaints about the 11.2 design: "New Banking" thread 2025-08-05 (20 replies, mostly negative): loss of compartmentalisation, items scattered across tabs on migration, filters limited to Blizzard presets.

## 2. Per-addon findings

### Baganator (low confidence, see gaps)
- CurseForge blurb: single or category view for bags AND bank; browse any character's bags/bank/guild bank from anywhere; search operators (& | !), item level, keywords.
- Bank has a Character view and a separate Warband view with a switch between them (inferred from CaerdonWardrobe issue #58 "when switching between Character and Warband tabs", May 2026, and addon-integration chatter about CharacterView vs WarbandView). There is also an "Everything" bank tab view (Baganator issue #536 title; failed to update when switching alts).
- Transfer button in bank: moves only the currently searched items into the bank (CurseForge). Good for a "search then move" flow.
- Right-click on a category header deposits that whole category; issue #332 (title seen via search): header right-click made new stacks instead of merging, while per-stack right-click merged correctly. Another issue: "Blacklist Auto-deposit Items" (#337), "Warbank Money deposit" (#325), key bindings to toggle bank and switch character/warband tabs (#206). Dates unverified.

### BetterBags
- README: "displays the different types of bank as tabs along the bottom of the bank window": Main Bank, Warbank Tab 1-5, optional Character Bank tabs, Reagent Bank with purchase option.
- Tabs renamed / filter-assigned by right-clicking the bottom tab, which opens Blizzard's native dialog. Deposits "use Blizzard's rules" (README). So the addon explicitly punts the deposit-routing explanation to Blizzard.
- Buying bank slots: enable "Show Bags" and click red slots (README) - a hidden, awkward step.
- Gold: hover the gold, left/right click to deposit/withdraw (README) - discoverability relies on docs.
- Complaints: #813 (2025-08-28) items go to character bank instead of stacking onto warband bank; #807 warband shows 2 of 3 tabs; #775 purchased tab not recognised; #687 tabs not showing until reload; #818 bank tab not working; #798 (2025-08-08) category right-click to warband errors; #982 (open, 2026-06-30) all bank slots merge into one view and all warbank slots into one, users who organise tabs by purpose lose their structure, asks for per-tab combining.

### Bagnon (+ BagBrother)
- Bank frame shows character bank, and Warband bank bags as an additional bag row/tabs; user hides/shows "bag" buttons to switch views. Issue #2125 (2025-10-20): user could not find warband bank, tabs "behind normal tabs", content vanished when toggling others (closed invalid = user confusion). #2147 (2026-01-27): can't hide warband bag.
- Deposit routing is the biggest complaint cluster. History from changelog: shift-right-click deposits to warband (11.0.17); "deposit items" button added (11.0.13); right-click sort button = deposit all reagents; 11.2.18 "using an item from bags while viewing Warband tab deposits to warband". Then: #2081 (2025-08-07) right-click went to character bank, shift-right-click workaround; #2133 (2026-01-15) user asks how to deposit to the regular bank while on the Warband tab; #2167 (2026-03-05) shift-right-click behaviour flipped in 12.0.7 and contradicts the addon's own help text; #2129 right-click sent to player bank instead of the displayed bank; #1942 (2024-08-28) asked for a "Deposit all warband items" button (had to disable Bagnon to use Blizzard's).
- Lesson: modifier-key routing is undiscoverable and fragile; users want routing to follow what is displayed, and want to override it visibly.

### ArkInventory
- Warband deposit/withdraw gold via an action button; right-click bank-bag context menu has auto-deposit options. Issue #1960 (2024-08-04): deposit entries buried far up a crowded context menu; asks for buttons or bottom placement.
- #1975 (2024-08-12): bank remembered last tab, so reopening showed Warbank UI but right-click deposited into personal bank (displayed bank != deposit target). Exactly the user's pain point (1).
- Highly configurable, complex; no first-time hints found.

### AdiBags (and forks)
- Original AdiBags: PSA #1020 and #1019 (2024-08-22): Warband would not open unless you disabled AdiBags' Bank module. Effectively abandoned; community points to BetterBags or AdibagsEx (fork with full Warband support on CurseForge). I found no details of AdibagsEx's navigation UI.

### ElvUI bags
- Unified frame with warband tab navigation; options "Split" bank bags and disable all-in-one (Blizzard forum "Warband bank elvui", deepwiki summary). No specific UX complaints retrieved. Low confidence.

### Sorted.
- List/table view; Bank, Reagent Bank, Guild Bank in one UI, bank caching, alts. Store text mentions no Warband bank (as of the page I saw; could be stale). Incompatible with other bag addons. 1.3k comments on CurseForge not retrievable.

## 3. Patterns that make a bank window understandable (weighted to the four pain points)

Pain point 1: where does right-click deposit go, and how do I switch
1. Make the destination the visible mode: the window is ALWAYS in exactly one mode (Character bank or Warband bank), the mode is stated in a big header/label, and right-click deposit follows that mode and nothing else. Evidence: Blizzard 11.2 fixed the same complaint by following the current tab (Blizzard Watch); Bagnon #2133/#2129 and ArkInventory #1975 are bugs where displayed bank != deposit target.
2. Echo the destination at the point of action: a persistent line like "Right-click sends items to: Warband bank, tab 2" and a tooltip on bag items while the bank is open. No addon found does this well; BetterBags defers to "Blizzard's rules" and the wiki itself is wrong/ambiguous about tab routing.
3. Do not rely on modifier keys as the only way to reach the other bank. Bagnon's shift-right-click flipped between versions and contradicted its own help (#2167, #2081, #1942). If a modifier exists, it should be a shortcut for a visible control.
4. Reset or re-announce mode on bank open (ArkInventory #1975: remembered tab caused mismatch).

Pain point 2: too many buttons
5. One primary action per mode. Blizzard exposes "Deposit All Warbound Items"; Bagnon users asked for exactly that one button (#1942). Hide rarely used actions (cleanup options, gold, reagent deposit, tab settings) in one overflow/menu rather than separate buttons. Evidence against clutter: ArkInventory #1960 (deposit actions buried in a long menu) and Bagnon hiding "deposit all reagents" on right-click of the sort button (undiscoverable).
6. Do not keep Reagent-bank-era buttons; the Reagent Bank no longer exists (Blizzard Watch 11.2). BetterBags still lists a Reagent Bank tab with purchase and Bagnon "deposit reagents" text; legacy concepts add confusion.

Pain point 3: finding items across character / warband / tabs / sections
7. Search is global and its results say where: highlight matches in the current view and show "also in Warband bank, tab 3" counts for the other bank. Baganator's search plus cross-character tooltips is the strongest model found; its "transfer searched items" button is a great search-then-move flow.
8. A merged "Everything" view as an option for finding, but keep per-tab structure available. BetterBags #982 shows users who organise by tab dislike all-slots-merged; Baganator has an Everything view (#536) but it had staleness bugs.
9. Show tab names/icons/filters as the player set them (Blizzard right-click tab menu) rather than renaming them differently.

Pain point 4: tab hosting and display modes
10. Offer very few display modes (e.g. Categories vs Tabs) with plain-language names and a one-line description each; show purchased and unpurchased tabs distinctly with price in tooltip. Evidence of confusion when tab ownership is unclear: BetterBags #807/#775/#687 (missing or unrecognised tabs), Bagnon #2125 (warband tabs "behind" normal ones).
11. Tab purchase must be a visible "+" tab or button, not a hidden mode (BetterBags needs "Show Bags" then click red slots).

## 4. Anti-patterns (with evidence)
- Deposit target that differs from what is displayed (ArkInventory #1975, Bagnon #2129, BetterBags #813).
- Modifier-key-only routing, undocumented or contradicting help text (Bagnon #2167, #2081).
- Silent mode memory across bank opens (ArkInventory #1975).
- Legacy "reagent bank" concept shown after removal (Blizzard 11.2 notes).
- Category-header "deposit all" that behaves differently from stack deposit (Baganator #332: new stacks vs merging).
- Everything merged into one grid with no per-tab hint (BetterBags #982), or tabs hidden until reload (BetterBags #687).
- Buttons buried in context menus (ArkInventory #1960).
- Explaining routing by "uses Blizzard's rules" with no visible rule (BetterBags README; Blizzard's own forum threads show nobody can state the rule).

## 5. Impossible or unsafe for SwagBag (taint rule: cannot switch Blizzard's selected bank tab from code)
Caveat: the bank-API facts below come from search summaries, not primary API docs; verify against the live 12.1 client before building.
- Cannot programmatically select a Blizzard bank tab or force the Blizzard bank frame to the Character/Warband view. So a SwagBag "switch to Warband" control cannot drive Blizzard's own tab selection. A SwagBag-owned view toggle is fine for DISPLAY only; it must not imply the right-click destination changed unless deposit is done via an explicit API call that targets that bank.
- Safe-ish route: deposit via C_Bank (AutoDepositItemsIntoBank / bank type argument) or Blizzard's own "deposit all warbound" call from a hardware click, rather than hooking UseContainerItem. Bagnon's #2206 (Classic Era) shows right-clicking a bag item at the bank can taint UseContainerItem; BetterBags #798 and #813 show routing code failing. So SwagBag should pick destination explicitly and label it, not infer it from Blizzard's selected tab.
- Cannot reliably set which Blizzard tab an item lands in (Blizzard filters/category routing decides). Any "send to tab N" UI promise would be false; show "Warband bank" as destination, not a specific tab, unless using documented slot-targeted moves (pickup/place) which can fail in combat or when locked.
- A bank-type query API reportedly exists so addons can read which bank is currently shown; safe to read for labelling, not to set.
- Tab purchase, rename, icon and filter editing: must open Blizzard's own dialogs (BetterBags does this); SwagBag cannot reproduce the secure purchase flow.
- Anything done in combat or on protected frames must be guarded; Bagnon #2203 (items unusable in combat) is the failure pattern.

## 6. Sources
- https://blizzardwatch.com/2025/07/15/banks-void-storage/
- https://warcraft.wiki.gg/wiki/Warband_Bank
- https://us.forums.blizzard.com/en/wow/t/warband-bank-deposit-items-ux-very-confusing/1921158
- https://us.forums.blizzard.com/en/wow/t/why-do-warband-bank-tabs-function-as-one/1910627
- https://us.forums.blizzard.com/en/wow/t/please-fix-warband-bank-deposit-bug/2102264
- https://us.forums.blizzard.com/en/wow/t/new-banking/2142911
- https://github.com/Cidan/BetterBags (README), issues 982, 813, 807, 798, 775, 687
- https://github.com/Jaliborc/Bagnon/issues/2167, 2133, 2147, 2125, 2081, 1942, 2206
- https://www.curseforge.com/wow/addons/bagnon/files/7669390 (changelog)
- https://github.com/arkayenro/arkinventory/issues/1975, 1960
- https://github.com/AdiAddons/AdiBags/issues/1019, 1020
- https://github.com/Caerdon/CaerdonWardrobe/issues/58 (Baganator Character/Warband tabs)
- https://www.curseforge.com/wow/addons/baganator, /sorted, /adibagsex
- Baganator issue titles (#206, #261, #325, #332, #337, #536, #607) seen only in search results; pages 404 to fetcher.
