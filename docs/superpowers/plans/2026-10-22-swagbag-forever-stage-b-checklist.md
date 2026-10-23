# SwagBag on WoW Forever: Stage B in-game checklist

For the user, on the Forever client, in launch week. Nothing is offered to Forever players until every step here passes.

Claude installs the build first; then restart the game fully. The TOC does not list Forever yet, so on the character screen open AddOns and tick "Load out of date AddOns".

## F-1 Client facts

Type each line and note the answers for Claude.

1. `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT, WOW_PROJECT_MAINLINE`. You should see `18, 18, 1`.
2. `/dump select(4, GetBuildInfo())`. You should see the launch Interface number (16001 or new).
3. `/dump C_Bank.ShouldUsePlayerBagsInBank()`. Note the answer.
4. At the bank, `/dump C_Bank.FetchPurchasedBankTabIDs(0)`. You should see 6 upwards.
5. `/dump C_Bank.CanViewBank(2)`. Note the answer: it tells whether the warband bank is on.

## F-2 Report

1. Type `/swagbag report`. You should see "WoW Forever: Interface 16001 | bags 0-5 | bank tabs 6-14 | warband tabs 15-23".
2. In the same report you should see "bank=on (WoW Forever, ...)". The bags must say off.

## F-3 Checks

1. Type `/swagbag check`. It should end with "0 required" failed.
2. If any line says FAIL, copy it to Claude.

## F-4 Bags

1. Press B. SwagBag's bags open with your items in sections; reagent-bag items are in Reagents.
2. Hover three items. The tooltips look normal.

## F-5 Nothing Retail-only

1. Open Settings > Overlays. There is no "Upgrade track" or "Keystone" row.
2. Open Settings > Footer. It lists Gold, Currencies and Free slots only.
3. Open Settings > Focus modes. There is no M+ or Delves mode.
4. Type `/swagbag setup`. It offers four styles, with no M+.
5. Strings to reword for Forever before launch, because they still name Retail-only things:
   - `HELP_OVERLAYS` (the `/swagbag help` line for overlays)
   - `OVERLAYS_USAGE` (the answer to a mistyped `/swagbag overlays`)
   - `FOOTER_USAGE` (the answer to a mistyped `/swagbag footer`)
   - `FOOTER_NOTE` (the note under the footer list, which mentions crests)

## F-6 Bank

1. Talk to a banker. Blizzard's bank opens.
2. The chat shows once: "On WoW Forever, Blizzard's own bank and guild bank are used for now: SwagBag's bank windows wait until they have been checked there. Your bags still use SwagBag."
3. Close the bank and open it again. There is no second line.
4. Open Settings > Bank & guild. It still shows the price source, the TSM price and the header totals rows, and says "On WoW Forever, Blizzard's own bank and guild bank are used for now. These settings come back once SwagBag's bank windows have been checked there."

## F-7 Bank, opt-in (testing only)

1. Type `/swagbag safe bank`, then talk to the banker again. SwagBag's bank opens.
2. Look in the Character bank group. Every item from every bank bag you bought is there. None of it is in Warband or New.
3. Look at SwagBag's header. Blizzard's Bank / Warband Bank tabs sit there and switch where right-click deposits go.
4. Buy a bank bag slot in Blizzard's frame (Settings > Bank & guild, "shown"). It still works.
5. Note anything that looks wrong. The next login turns it back to Blizzard's bank.

## F-8 Guild bank

If your guild has one: open it. Blizzard's guild bank opens, with no second chat line.

## F-9 In an instance

Open your bags inside a dungeon. There is no Lua error and items stay visible.

## F-10 Other bag addons

If Baganator or Bagnon is installed, SwagBag's login line names it.

## After the checklist passes

Claude appends 16001 and the launch Interface number to the single `SwagBag/SwagBag.toc`, sets `FOREVER_READY = true` in `scripts/toc_check.lua`, updates the `REQUIRED` header line there, and uploads with `scripts/release.sh --forever`.
