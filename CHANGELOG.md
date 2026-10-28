# SwagBag changelog

Newest first. Each "## <version>" section is the changelog CurseForge shows for that upload (scripts/release.sh reads it).

## 0.17.0

- **Every character's gold and currencies, in a tooltip:** hover the gold in your bags footer to see the gold of all your characters, the Warband bank (as last seen) and the total. Hover a currency or a crest to see how many each character has. With Syndicator your characters show at once; without it, log in on each character once with 0.17 and it joins the list. The footer itself looks the same.
- **Colored item levels (off until you ask):** turn on "Color item levels" in Settings > Overlays, or type `/swagbag ilvlcolors on`. The first time, SwagBag fills in four steps from your equipped item level: green at your level, blue 10 above, purple 20 above. Item levels on icons and in the list view take the color of the step they have reached. You can change the levels and pick from six colors in the same place; `/swagbag ilvlcolors off` turns them white again and keeps your steps.
- **One section per bag, or per bank tab:** the view button on the bags window now cycles Categories, List, Grid and Bags (or type `/swagbag view bags`). In the bank, open the `...` menu and pick Bags to get one section per bank tab, named as in Blizzard's bank. Each header shows the bag's name, slots and free slots. Click a header to fold it; it stays folded.

## 0.16.1

- **Deposit warbound asks instead of refusing:** when SwagBag can't tell whether an item in your bags can still be refunded, a window asks whether to deposit anyway. Yes deposits; No leaves everything in your bags. If SwagBag knows an item can still be refunded, it still refuses without asking, so you never lose a refund by accident.

## 0.16.0

- **Search by armor type:** `plate`, `mail`, `cloth armor`, `leather armor`, `shield` (and `libram`, `idol`, `totem`, `sigil`, `relic` where the game has them).
- **`cloth` and `leather` now find both** the crafting material and that armor. For the material only, use `cloth material` or `leather material`. The built-in Leather & Cloth section uses those, so it never collects armor. If one of your own saved rules uses `cloth` or `leather`, SwagBag names it once in chat at your next login. Your rules are not changed.
- **Search by stats:** `crit`, `haste`, `mastery`, `vers`, `leech`, `avoidance`, `speed`, `str`, `agi`, `int`, `stam`. A bare word finds gear that has the stat, and a number compares it: `crit>200`, `haste & mastery`.
- **Weapons and sockets:** `dps>500` (or `damage>500`), `sockets` (any socket), `socketed` (every socket filled), `sockets>1`.
- **Expansion, sets, appearances and bonus IDs:** `midnight`, `tww`, `dragonflight`, `legion` and the other expansions, or `expansion=11`. `set` finds set pieces, `transmog` finds gear whose look you haven't collected, and `bonus=1540` matches a bonus ID.
- **Damage types:** `fire damage` (or `damage fire`) finds gear whose tooltip has a fire damage line. Frost, nature, shadow, arcane, holy and physical work the same way, and `damage` finds any of them. Few modern items have these lines, so expect mostly older gear.
- **Search a tooltip's text:** `text:fire`, or `text:"deals 50"` for a phrase. Plain words still only search item names, so everyday searches stay fast and predictable. Both work in your categories too. The category editor has a "Tooltip text contains..." rule and marks the rules that read tooltips.
- Inside an instance, the game sometimes hides an item's details. Until they come back, a search can't check those items and dims them.
- On WoW Forever the expansion keywords match nothing and are left out of the category editor.
- Groundwork for WoW Forever. Nothing else changes on Retail: your bags, bank and settings work exactly as before.

## 0.14.5

- **Auto repair is now opt-in:** vendors no longer repair your gear by themselves until you ask. Turn it on in Settings > Vendor ("Repair at vendors": Your gold or Guild bank first) or with `/swagbag repair own` or `/swagbag repair guild`.
- If you had already picked Your gold or Guild bank first, nothing changes for you.
- **New look: Classic.** SwagBag's windows can wear the original game's style: the gold-trimmed border, the dark stone background, gold titles and the old empty bag-slot squares. Pick it in Settings > Look or with `/swagbag theme classic`.

## 0.14.4

- **Closing a window starts it fresh:** your bags, bank (character and Warband) and guild bank clear their search and scroll back to the top when you close them, so the next open shows everything from the top.

## 0.14.3

- **Focus modes no longer switch by themselves until you ask:** your sections stay where you put them when a key starts, you open the vendor or the bank, or you go fishing. To have SwagBag bring up the sections you need, turn on "Switch by themselves" in Settings > Focus modes, or in step 2 of the setup wizard (`/swagbag setup`). It starts Off.
- If you had already turned it on, nothing changes for you.
- Modes of your own that you switch on by hand (`/swagbag mode on <name>`) work either way.
- The tour, the setup wizard and the Focus modes page now say that this is opt-in.

## 0.14.2

- **Warband gold in SwagBag's bank:** your Warband balance at the bottom of the bank window, with Deposit and Withdraw buttons (Blizzard's own gold boxes). Also in the "..." menu; hide it in Settings > Bank & guild or with `/swagbag bank gold off`.
- **Fixed:** on the first bank visit after starting the game, the Warband bank no longer shows everything as New. Real deposits still land in New.
- `/swagbag report` now says why items are in New, to help with bug reports.

## 0.14.0

- **One icon per item:** split stacks of the same item show as one icon with the total, in your bags and both banks. Hover it to see each stack. Turn it off in Settings > Bags or with `/swagbag stacks all`.
- **Search:** partial words find item types too (`trink` finds trinkets, `brac` finds bracers), and a bank search opens the bank that holds the matches.
- **Fixed:** after a full game restart, items whose details load late no longer stay stuck in New.
- New is hidden in the bank and guild bank while it's empty, and the two banks get a faint colour each.
