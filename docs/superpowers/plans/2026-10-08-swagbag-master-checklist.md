# SwagBag 0.13.6: the master in-game checklist

One list for everything built in weeks 6 to 13 that you have not tried in the game yet. The sessions are in risk order: the first ones protect your items and your clicks, then the M+ flow, then gold-making, then setup and looks. Sessions 1 to 7 fit in one evening, 8 to 11 in a second, 12 to 15 in a third.

Chat lines start with `SwagBag: `. Words in angle brackets, like `<its name>` or `N`, stand for your own item names and numbers. After each session, tell Claude "Session N done" and the numbers of any steps that didn't match.

## Session 1: Bank tabs and right-click deposits (~15 min)

Why: Blizzard's own Bank and Warband Bank tabs now sit inside SwagBag's bank window. If they break your right-clicks or your Hearthstone, nothing else matters.
Have ready: a banker; your Warband bank unlocked; in your bags one warbound item, one soulbound item and one ordinary trade good; your Hearthstone off cooldown.

1. Fully restart the game first: quit completely, start it again and log in. Expected: chat shows `SwagBag: v0.13.6 loaded. Type /swagbag help for commands.`, and no setup window opens by itself. (W12, W13)
2. Right-click the banker and leave the mouse resting over the bank's items while it fills. Expected: SwagBag's bank opens and Blizzard's bank is not visible. If some items first show in `New` while their data loads, they stay put while the mouse rests there, and move to their own sections about half a second after you move the mouse away. (W13, 0.13.3)
3. Look at the line under the search box. Expected: it reads `Right-click deposits to:`, followed by two tabs, `Bank` and `Warband Bank`, inside the window's header. They do not overlap the search box or the first group. (W13)
4. Click `Warband Bank`. Expected: the tab lights up, the Warband bank opens, the Character bank folds to one line, and your bags' title reads `SwagBag — right-click to Warband bank`. (W13)
5. Rest the mouse on the warbound item in your bags. Expected: its tooltip has the line `Right-click: into your Warband bank`. (W13)
6. Rest the mouse on the soulbound item. Expected: its tooltip has the line `Right-click: your Warband bank won't take this`. (W13)
7. Right-click the warbound item. Expected: it lands in the Warband bank, in its `New` section. Nothing else in the bank moves, there is no red error, and there is no "blocked" message. (W13)
8. Click `Bank`. Expected: the tab lights up, the Character bank opens, the Warband bank folds, and your bags' title reads `SwagBag — right-click to Character bank`. (W13)
9. Right-click the trade good. Expected: it lands in the Character bank, whose header ends with `- right-clicked items land here`. (W13)
10. Click `Warband Bank`, then click `Deposit warbound` on the Warband bank's header. Expected: the bank's title shows `Depositing warbound items into the warband bank` (or `Depositing warbound items and reagents into the warband bank`). Within a second your warbound items leave your bags and appear in the Warband bank's `New`. There is no "Interface action failed" message. If a line about refunds or a locked warband bank shows instead, copy it exactly to Claude. (W6, W13)
11. Type `/reload`, then open the bank again. Expected: the `Bank` and `Warband Bank` tabs are in the header again. (W13)
12. Right-click any item in your bags. Expected: it lands in the bank whose tab is lit, with no "blocked" message. (W13)
13. Walk away from the banker until the bank closes, then rest the mouse on an item in your bags. Expected: your bags' title is back to normal, and the tooltip has no `Right-click:` line. (W13)
14. Use your Hearthstone. Expected: it casts normally, with no red error and no "Interface action failed" or "blocked" message. (W13)
15. Type `/swagbag report`. Expected: the box has the lines `Safe Mode: bags=off bank=off`, `Failed checks: none` and `Blocked actions: none`. Press Esc. (W6-W12 exit checks)

## Session 2: Items land in the right bank, and you take the item you clicked (~15 min)

Why: "Send all" moves many items at once, and the bank's list view takes items by a small icon. Both must hit the bank and the item you meant.
Have ready: a banker; a few cheap trade goods in your bags (a `Trade Goods` section) plus one other section with items; a few items already in your bank.

1. Type `/swagbag bank both`. Expected: `SwagBag: Bank: SwagBag's bank window shows both banks.` (W13)
2. Open the bank and click the `Bank` tab. Then Shift+right-click the `Trade Goods` header in your bags. Expected: a small menu with `Send all to bank (N)`, `Send all to warband bank (N)` and `Cancel`. (W7)
3. Click `Cancel`. Expected: the menu closes and nothing moves. (W7)
4. Shift+right-click `Trade Goods` again, click `Send all to warband bank (N)`, and move the mouse away from both windows. Expected: the items move one by one into the Warband bank, even though the `Bank` tab is lit. Chat shows `SwagBag: Sent N items from Trade Goods to the warband bank.` There is no red error or "blocked" message. (W7, W13)
5. Click the `Warband Bank` tab. Shift+right-click another section's header and click `Send all to bank (N)`. Expected: the items go into the Character bank, and chat shows `SwagBag: Sent N items from <section> to the bank.` (W7, W13)
6. Click `...` in the bank's title row, then `View: List`. Expected: the bank's title shows `SwagBag bank - list view`, and each item is a row with a small icon, its name, count, item level and value. A bar `Name  Count  ilvl  Value v` sits under the deposit line. (W8, W13)
7. Rest the mouse on the name text of a bank row, not its icon. Expected: the item's tooltip, ending with `Right-click the icon on the left to take this item, or drag the icon.` (W8)
8. Click that name text. Expected: the title shows `Right-click the icon on the left to take the item.` and nothing is taken. (W8)
9. Right-click the small icon of a row in the middle of a section. Expected: exactly the item named on that row comes to your bags. A dimmed icon stays, its row reads `(moved or used - regroups when you close the bank)`, and no other row moves. (W8)
10. Right-click any item in your bags. Expected: it appears as a row in `New` of the bank whose tab is lit, and no other row moves. (W8, W13)
11. Click `...`, then `View: Categories`. Expected: the title shows `SwagBag bank - category view`. (W8, W13)
12. Walk away from the banker, then type `/swagbag bank one`. Expected: `SwagBag: Bank: SwagBag's bank window shows the bank you deposit into; the other folds to one line.` (W13)

## Session 3: Guild bank deposits and withdrawals (optional) (~8 min)

Why: the guild bank's list view takes and drops items by a small icon. It must take exactly the item you clicked and drop into the tab you meant.
Have ready: a guild bank tab you may deposit into and withdraw from; any spare item in your bags. Skip this session if you have no guild bank.

1. Right-click the guild vault. Expected: SwagBag's guild bank opens, and its view button reads `List`. (W8)
2. Click `List`. Expected: the title shows `SwagBag guild bank - list view`, and each tab's empty slots are one row like `40 free - drop items here`. (W8)
3. Pick up an item from your bags (left-click it), then left-click the small icon of the `... free - drop items here` row in the tab that says `deposits go here`. Expected: the item goes into that tab and shows as a row in its `New`. Nothing else moves. (W8)
4. Right-click the icon of an item row in that same tab. Expected: exactly that item comes to your bags, and its row reads `(moved - regroups when you close the guild bank)`. Nothing else moves. (W8)
5. Click the name text of another row. Expected: the title shows `Right-click the icon on the left to take the item (from the tab Blizzard has selected).` and nothing is taken. (W8)
6. Click `Grid`, then `Categories`. Expected: the title shows `SwagBag guild bank - grid view`, then `SwagBag guild bank - category view`. (W8)
7. Walk away until the guild bank closes. Expected: it closes with no red error. (W8)

## Session 4: Combat: item use, the bank, and windows that step aside (~15 min)

Why: in a fight, nothing SwagBag does may block a potion, an ability or your keyboard.
Have ready: a training dummy near a banker (capital cities have both); a healing potion in your bags.

1. Attack the dummy. While in combat, right-click the healing potion in SwagBag's bags. Expected: you drink it, with no "Interface action failed because of an AddOn" message. (W9)
2. Still in combat, right-click the banker. Expected: Blizzard's own bank stays visible and SwagBag's window opens beside it. The bar reads `Right-click deposits to: <bank> - switch with the tabs on Blizzard's bank` or `Right-click deposits: pick Bank or Warband Bank on Blizzard's bank`. It never shows `Right-click deposits to:` with no tabs next to it. (W13)
3. Click `...`, then `Show Blizzard's bank (buy tabs, gold)` (or `Hide Blizzard's bank`). Expected: the bank's title shows `Leave combat first`, and nothing moves. (W13)
4. Click `Sort` in the bank's title row. Expected: the title shows `Sort after combat ends`, nothing sorts, and nothing sorts later when combat ends. (W13)
5. Stop attacking and wait until you are out of combat (about 5 seconds). Close the bank and open it again. Expected: the tabs are back in the header, and right-clicks work as in Session 1. (W13)
6. Type `/swagbag settings categories`, click `New category`, then click into the box under `Name` without typing. Attack the dummy by pressing one of your ability keys. Expected: the ability is used, and nothing is typed in the box. (W11)
7. After the fight, click `Cancel`. Expected: the status line at the bottom of the settings window reads `Nothing was changed.` Close the settings window. (W11)
8. Type `/swagbag tour`, then attack the dummy. Expected: the tour's note disappears at once, and chat shows `SwagBag: Tour ended because combat started. Type /swagbag tour after the fight.` (W12)
9. Still in combat, type `/swagbag tour`. Expected: `SwagBag: The tour waits until you are out of combat. Type /swagbag tour again then.` and no note. (W12)
10. Leave combat. Type `/swagbag setup` and click `Next`. Expected: `Step 2 of 4: What that turns on`. (W12)
11. Attack the dummy. Expected: the setup window disappears, and chat shows `SwagBag: Setup steps aside during the fight; it comes back where you were when combat ends.` (W12)
12. Stop attacking and wait until you are out of combat. Expected: the setup window is back at `Step 2 of 4: What that turns on`. (W12)
13. Click `Skip (keep my settings)`. Expected: chat shows `SwagBag: SwagBag keeps your current settings. Type /swagbag to change anything.`, the window closes, and no tour is offered. (W12)

## Session 5: Sorting and moving: nothing lost, nothing moves under the mouse (~20 min)

Why: SwagBag's own stacking moves your items one by one, and focus modes re-order sections. Nothing may get lost, be left on your cursor, or jump away from under your mouse.
Have ready: a stackable item (potions, herbs, cloth) with at least one full stack and some spare; three empty bag slots; a banker; a vendor; some gray junk or trade goods.

1. Type `/swagbag view grid` and press B. Expected: `SwagBag: SwagBag - grid view`, and your bags show every slot in the game's order. (W9)
2. Split the stack twice into two empty slots: hold Shift, left-click the stack, type 3, press Enter, then left-click an empty slot. Expected: one full stack and three partial stacks of that item. (W9)
3. Type `/swagbag sort stacks`. Expected: `SwagBag: Sort now merges partial stacks, then puts each item's partial stack in front of its full ones. Nothing else moves.` (W9)
4. Move the mouse off the bags and click `Sort` in the bags' title row. Expected: the title shows `Stacking...` for a moment, the partial stacks join one by one, and the one partial stack left sits before the full stacks. Chat shows `SwagBag: Stacking done. Stacks merged: N. Partial stacks moved first: N.` (W9)
5. Rest the mouse on each stack of that item in turn. Expected: the counts add up to what you had, and nothing is on your cursor. (W9)
6. Click `Sort` again. Expected: the title shows `Nothing to stack: each item has at most one partial stack, and it is already first.` and nothing moves. (W9)
7. At the banker, split two small stacks of one item in your bags and drag each onto a different empty slot of the Character bank (drag, don't right-click). Move the mouse off the windows. (W9)
8. Click `...`, then `Sort Character bank`. Expected: `Stacking...` in the bank's title, then the two small stacks become one. Chat shows `SwagBag: Stacking done. Stacks merged: 1. Partial stacks moved first: 0.` (or similar numbers), and the Warband bank is not touched. (W9, W13)
9. Make two or three small stacks in the Character bank again. Click `...`, then `Sort Character bank`, and at once walk away from the banker. Expected: chat shows `SwagBag: Stacking stopped: the window closed (stacks merged: N, moved first: N).`, nothing is on your cursor and nothing is lost. (W9, W13)
10. Type `/swagbag settings bags`. Expected: the row `The Sort buttons` has `Partial stacks first` selected. Click the one you want to keep (`Blizzard's sort` answers `Sort now runs Blizzard's own sort.`) and close the window. (W9)
11. Type `/swagbag view sections`. Expected: `SwagBag: SwagBag - category view`. (W9)
12. Click the `Junk` header (or another header, not `New`) to collapse it, and move the mouse off the bags. Right-click the vendor. Expected: the bags' title starts with `SwagBag — AH/Vendor/Bank`, and `Junk`, `Trade Goods` and `BoE gear` (the ones you carry) move to the top, right under `New` if it shows. `Junk` stays collapsed. (W6)
13. Rest the mouse on any item in your bags and keep it still. Walk away from the vendor with the S key until its window closes. Expected: the title goes back to normal, and no section moves while the mouse rests on the item. (W6)
14. Move the mouse off the bags. Expected: within half a second the sections go back to your usual order, and `Junk` is still collapsed. Click its header to open it again. (W6)

## Session 6: Your settings are safe: profiles, import, reset and undo (~15 min)

Why: a reset or an import must never lose your settings or your own categories, and undo must bring them back.
Have ready: a few herbs in your bags (for step 10).

1. Type `/swagbag profile save Backup`. Expected: `SwagBag: Saved your current settings as the profile "Backup".` This is your safety net for this session. (W7)
2. Type `/swagbag profile reset`. Expected: `SwagBag: Your settings are back to SwagBag's defaults. /swagbag profile undo brings yours back.` Open bags may change, for example the number of slots per row. (W7)
3. Type `/swagbag profile undo`. Expected: `SwagBag: Your settings are back as they were before the last load, import or reset. Your categories stay as they are.` Your bags look as before step 2. (W7, W11)
4. Type `/swagbag profile load Backup`. Expected: `SwagBag: Loaded the profile "Backup". Your previous settings are kept: /swagbag profile undo brings them back.` Nothing visible changes. (W7)
5. Type `/swagbag profile export`. Expected: chat shows `SwagBag: Your settings' share string is in the box: press Ctrl+C to copy it.`, and a box titled `SwagBag share string` shows a long line starting with `SWAGBAG:1:`. Press Ctrl+C, then Esc. (W7)
6. Type `/swagbag profile import`. Expected: `SwagBag: Paste a share string into the box, then press Preview.` and a box titled `Import a SwagBag share string`. (W7)
7. Click into the box, press Ctrl+V, and click `Import`. Expected: the box says `Press Preview first: SwagBag shows what changes before it changes anything.` (W7)
8. Click `Preview`. Expected: `Nothing would change: your settings already match.` (W7)
9. Click into the box, press Ctrl+A, type `SWAGBAG:1:s.bags.columns=n0` and click `Preview`. Expected: `That string has a wrong value for Slots per row; nothing was read.` (W7)
10. Press Ctrl+A, type exactly `SWAGBAG:1:cu.u_week8.name=sWeek8;cu.u_week8.query=sherb%7Ccname;cu.u_week8.priority=n95` (no spaces) and click `Preview`. Expected: `Import would change:`, then `Categories: 1 of yours, 0 changed built-ins, order no`, then `Ranked just below Junk (an imported category never outranks Junk, Equipment sets, Keystone & Crests or Reagents): Week8`. (W8)
11. Click `Import`. Expected: the box closes and chat shows `SwagBag: Imported 1 changes. Your previous settings are kept: /swagbag profile undo brings them back.` Press B twice: a `Week8` section holds your herbs. (W8)
12. Type `/swagbag profile undo`. Expected: `SwagBag: Your settings, categories and category order are back as they were before the last import.` Press B twice: `Week8` is gone and your herbs are back in their usual section. (W8, W11)
13. Type `/swagbag settings categories`. Expected: every category of your own is still listed, and there is no `Week8`. Close the settings window. (W11)
14. Type `/swagbag profile delete Backup` (or keep it). Expected: `SwagBag: Deleted the profile "Backup". Your current settings are unchanged.` (W7)

## Session 7: Safe Mode and a second bag addon (~10 min)

Why: if SwagBag ever misbehaves, Safe Mode must hand your bags back to Blizzard at once, and running Baganator alongside must not fight silently.
Have ready: Baganator installed but disabled in the AddOns list.

1. Type `/swagbag report`. Expected: the line `Other bag addons on: none`. Press Esc. (W9)
2. Type `/swagbag safe on`. Expected: `SwagBag: Safe Mode is ON for bags: Blizzard's frames are used. Type /swagbag safe off to switch back.` and the same line for bank. (W9)
3. Press B. Expected: Blizzard's own bags open, not SwagBag's. (W9)
4. Type `/swagbag safe off`. Expected: `SwagBag: Safe Mode is OFF for bags: SwagBag handles them again.` and the same line for bank. Press B: SwagBag's bags are back. (W9)
5. Log out, enable Baganator in the AddOns list, and log in. Expected: chat shows `SwagBag: Another bag addon is on too: Baganator. Two bag addons fight over the same bags. Keep one: type /swagbag safe on to let it handle your bags and bank, or disable one in the AddOns list. SwagBag switches nothing off by itself. (/swagbag otherbags off stops this line.)` Baganator is still enabled. (W9)
6. Type `/swagbag otherbags off`, then `/reload`. Expected: first `SwagBag: No more warning at login about other bag addons. /swagbag report still names them.`, then no warning line after the reload. (W9)
7. Type `/swagbag otherbags on`. Expected: `SwagBag: SwagBag warns at login while another bag addon is on too.` (W9)
8. Log out, disable Baganator again, and log in. Expected: no line about another bag addon. (W9)

## Session 8: The Mythic+ flow (~10 min, plus your next key)

Why: in a key you need consumables, the keystone and your gear sets up front, without hunting.
Have ready: an equipment set (character window, C) with at least one of its pieces in your bags; your next Mythic+ key.

1. Press B. Expected: a section `Equipment sets`, right under `Gear`, holding the set pieces in your bags. (W7)
2. Click the bags' search box and type `equipped`. Expected: only the items in `Equipment sets` stay bright. Press Esc and clear the box with its small x. (W7)
3. Type `/swagbag mode list`. Expected: among the lines, `SwagBag: M+: on - opens Consumables, Keystone & Crests, Gear, Equipment sets`. If you once edited M+'s sections, `Equipment sets` may be missing: tell Claude. (W7)
4. Type `/swagbag mode style`. Expected: `SwagBag: Focus style: front (a mode moves its sections to the top). Type /swagbag mode style front or /swagbag mode style collapse.` (or `collapse (a mode collapses the rest)` if you chose that). (W6)
5. Rest the mouse on the `Pause` button at the top of your bags. Expected: a tooltip `Pause focus modes`, then `Sections stop opening, closing and moving by themselves until you click Resume (or log in again).` and `Right-click: choose the sections this mode uses`. (W6)
6. (From 13 October, with Ascendant Venomstones in your bags.) Type `/swagbag report`. Expected: a line starting `Season data: crest currencies` that names `Ascendant Venomstone`. Copy the report to Claude. The Venomstones sit in `Keystone & Crests`. (W7)
7. Before your next key, click the `Consumables` header to collapse it, and move the mouse off the bags. (W6)
8. When the key starts, press B. Expected: the title starts with `SwagBag — M+`, and `Consumables`, `Keystone & Crests`, `Gear` and `Equipment sets` come to the top, right under `New` if it shows. `Consumables` is still collapsed, because you collapsed it yourself. (W6, W7)
9. During the key, loot something new while your bags are closed, then open them. Expected: it shows in `New` at the top, and it does not move while the mouse rests on it. (W9)
10. After the key, type `/swagbag report`. Expected: `Failed checks: none` and `Blocked actions: none`. (W12 exit check)

## Session 9: Selling at a vendor: junk, repairs, locks and Sell all (~20 min)

Why: auto-sell must never sell what you locked or still need, and every sale must be buyable back.
Have ready: a vendor who repairs; a few gray junk items; slightly damaged gear; one gray item you want to keep; a cheap section you are happy to sell (or skip step 10).

1. Type `/swagbag sell`. Expected: `SwagBag: Auto-sell junk at vendors: on. Type /swagbag sell on, sell off, or sell junk (at a vendor).` (W7)
2. Press B. Pick up the gray item you want to keep and drop it on the small `Lock` button right of the search box. Expected: `SwagBag: Locked: <its name>. SwagBag never sells it, and it shows a small lock.` A small padlock shows at the item's left edge and covers neither the item level nor the track text. (W7)
3. Move the mouse off the bags, then rest it on the locked item. Expected: its tooltip has the line `Locked in SwagBag: never sold by SwagBag`. (W7)
4. With your bags open, move the mouse far from them and right-click the vendor. Expected: your gray items leave one by one (each leaves a dimmed placeholder, nothing else moves), the locked one stays, and chat shows `SwagBag: Sold N junk items for ...`, then `SwagBag: Repaired everything for ...` if your gear was damaged. (W7)
5. Click the vendor's Buyback tab. Expected: every item SwagBag sold is there. (W7)
6. Right-click the locked gray item yourself. Expected: the vendor buys it, and chat shows `SwagBag: You sold <its name>, which you locked. Buy it back from the vendor's Buyback tab if that was a mistake.` (W7)
7. Buy it back from the Buyback tab. Expected: it returns to your bags, still with its padlock. (W7)
8. Shift+right-click the header of the cheap section. Expected: a menu with `Sell all (N)` and `Cancel`. (W7)
9. Click `Sell all (N)`. Expected: a dialog `Sell N items from <section> for about <amount>?`, then the line `Never sold: locked items, equipment-set items, gear whose look you have not collected (or the game cannot tell yet), items to open or learn, and gray BoE items worth more at auction.`, with `Yes` and `No`. Click `No`: nothing is sold. (W7)
10. (Only if you are happy to sell them.) Do step 8 and 9 again, click `Yes`, and move the mouse off the bags. Expected: the items sell one by one, and chat shows `SwagBag: Sold N items for <amount>.` (W7)
11. Move the mouse off the bags and walk away from the vendor with the S key. Expected: your bags, which you opened yourself, stay open. (W6)
12. Press B to close your bags and right-click the vendor. Expected: your bags open by themselves. Walk away: they close with the vendor. (W6)
13. Type `/swagbag lock clear`. Expected: `SwagBag: This removes your 1 lock. Press Unlock all again (or type /swagbag lock clear again) within 10 seconds to confirm.` (or `This removes all N locks. ...` if you have more). Nothing is unlocked yet. (W7, W8)
14. Within 10 seconds, type `/swagbag lock clear` again. Expected: `SwagBag: Unlocked the 1 locked item.` (or `SwagBag: Unlocked all items (N).`). (W7, W8)
15. Type `/swagbag lock undo`. Expected: `SwagBag: Lock restored: 1.` (or `SwagBag: Locks restored: N.`), and `/swagbag lock list` names your locked items again. (W7, W8)

## Session 10: Prices, the gold glow and the list view (~12 min)

Why: the prices and the gold glow tell you what to post and what to keep in the bank.
Have ready: Auctionator and/or TradeSkillMaster with prices loaded; a banker; a stack worth 100g or more.

1. Type `/swagbag price`. Expected: `SwagBag: Prices: auto (Auctionator, else TSM, else what a vendor pays). Answering now: Auctionator.` followed by the commands (`Answering now: TSM (DBMarket).` without Auctionator). (W9)
2. (With TSM.) Type `/swagbag price tsm`. Expected: `SwagBag: Prices now come from: TSM's DBMarket (else what a vendor pays).` In the bags' list view (`/swagbag view list`) the Value column matches TSM's market value times the count. (W9)
3. Type `/swagbag price auto`. Expected: `SwagBag: Prices now come from: auto (Auctionator, else TSM, else what a vendor pays).` (W9)
4. Type `/swagbag worth`. Expected: `SwagBag: Gold glow at the bank: items worth 100g or more a stack (by your price source: /swagbag price). Type /swagbag worth <gold>, worth top <percent>, or worth off.` (W7)
5. Open the bank. Expected: stacks worth 100g or more glow gold, in your bags and in the bank. (W7)
6. Type `/swagbag worth top 10`. Expected: `SwagBag: Gold glow at the bank: your most valuable 10% of items.`, and within a second your most valuable stacks glow gold. (W8)
7. Right-click a valuable stack from your bags into the bank. Expected: within a second the glow is worked out again, with that stack included. (W8)
8. Type `/swagbag worth 100`. Expected: `SwagBag: Gold glow at the bank: items worth 100g or more a stack.` (W7)
9. Click `...`, then `View: List`, then click `Name` on the bar. Expected: the title shows `Sorted by Name, A to Z`, and each section lists its items A to Z. (W8, W13)
10. Click `Value` on the bar. Expected: `Sorted by Value, highest first`, and the most valuable stacks come first. (W8)
11. Click `...`, then `View: Categories`, and walk away until the bank closes. Expected: the gold glows are gone. (W7)
12. Type `/swagbag settings bank`. Expected: the `Bank & guild` page has the rows `Item prices come from`, `TSM price (when TSM answers)` and `Gold glow at the bank on items worth`, with `100g or more` selected. Close the window. (W7, W9)

## Session 11: Warnings before a locked item is destroyed (~12 min)

Why: SwagBag can't stop Blizzard's delete, disenchanting or the scrapper, but it must warn you loudly before a locked item is lost.
Have ready: a gray item you don't mind losing; Enchanting and a green item it can disenchant (or Milling with herbs, Prospecting with ore); optionally a scrapping machine and a piece of gear you don't need.

1. Type `/swagbag lock warn`. Expected: `SwagBag: Warnings before a locked item is destroyed (a spell waiting for a target, the scrapper, Blizzard's delete box): on. SwagBag never stops these itself. Type /swagbag lock warn on or lock warn off.` (W10)
2. Lock the gray item: drop it on `Lock`. Expected: `SwagBag: Locked: <its name>. SwagBag never sells it, and it shows a small lock.` (W10)
3. Pick up the gray item and click on the ground, away from every window. Expected: Blizzard's delete box opens and works as always. Chat shows in red `SwagBag: <its name> is locked in SwagBag. SwagBag can't stop Blizzard's delete: click No (or press Esc) to keep it.`, and a small dark bar above the box says in red `This item is locked in SwagBag.` (W10)
4. Click No. Expected: the box and the dark bar close, and the item is back in your bags. (W10)
5. Do step 3 again and click Yes (type DELETE first if asked). Expected: the item is destroyed, the bar goes, and there is no "Interface action failed" message. (W10)
6. Lock the green item. Cast Disenchant and rest the targeting hand on it without clicking. Expected: the tooltip has `Locked in SwagBag: never sold by SwagBag` and, in red under it, `Locked by you. SwagBag can't stop this spell: press Esc to cancel it.` (W10)
7. Press Esc. Expected: the targeting hand is gone, and the tooltip has no red line. (W10)
8. Cast Disenchant again and rest the hand on an unlocked item. Expected: no red line. Press Esc. (W10)
9. (Optional, at a scrapping machine.) Lock the gear you don't need, open the scrapper, and rest the mouse on that gear. Expected: in red, `Locked by you. SwagBag can't stop the scrapper: a right-click can put this item in it.` (W10)
10. (Optional.) Right-click that gear. Expected: it goes into the scrapper, and chat shows in red `SwagBag: <its name> is locked in SwagBag and is now in the scrapper. SwagBag can't stop it: click it in the scrapper to take it out before you press Scrap.` Do not press Scrap. Click it in the scrapper to take it back. (W10)
11. Unlock the items you locked for this session by dropping each on `Lock` again. Expected: `SwagBag: Unlocked: <its name>.` (W10)

## Session 12: The setup wizard and the tour (~15 min)

Why: this is what a new player sees first. Keep your own values on steps 3 and 4 of the wizard, so your settings stay as they are.
Have ready: nothing special; your bags open.

1. Type `/swagbag setup`. Expected: chat shows `SwagBag: Setup opened.`, and a window `Welcome to SwagBag` shows `Step 1 of 4: What do you play?` with the buttons `M+`, `Raid`, `Gold-making`, `Casual` and `Collector`, plus `Skip (keep my settings)` and `Next`. (W12)
2. Make sure `M+` and `Gold-making` are green (click them if not), then click `Next`. Expected: `Step 2 of 4: What that turns on`, with two columns of lines like `M+ mode: On`. No text is cut off and no buttons overlap. Finish applies these lines, so click any line you normally keep off until it reads `Off`. (W12)
3. Click `Fishing mode: On`. Expected: it now reads `Fishing mode: Off`, and nothing else changes. Click it again to set it back. (W12)
4. Click `Back`. Expected: step 1, with your picks still green. Click `Next` to return to step 2. (W12)
5. Click `Next`. Expected: `Step 3 of 4: How your bags look`, with `Slots per row`, `Bag window size` and `The look of SwagBag's windows`, your own choices highlighted. Change nothing. (W12)
6. Click `Next`. Expected: `Step 4 of 4: Gold`, with `SwagBag found Auctionator: your items' prices come from it.` (or TSM), the row `Gold glow at the bank on items worth`, the row `Sell gray junk by itself at every vendor`, and a `Finish` button. (W12)
7. Click `Finish`. Expected: chat shows `SwagBag: Set up for M+, Gold-making. Change anything later: type /swagbag. Settings are saved when you log out or /reload.`, and a small window asks `All set. Want a short tour of your bags? It takes a minute, and you can stop it any time.` (W12)
8. Click `Show me around`. Expected: chat shows `SwagBag: Tour started: the notes next to your bags show you around. Esc or End tour stops it.`, and a note `1 of 7` sits by your first section header, which has a thin gold frame. (W12)
9. Click `Next` five times, reading each note. Expected: notes `2 of 7` to `6 of 7` point at a header, the search box, the `Pause` button and the `Sort` button. None is off screen or hard to read. (W12)
10. Click `Next`. Expected: `7 of 7`, which starts `If your bags ever act up, type /swagbag safe on`, and the button now reads `Done`. (W12)
11. Click `Done`. Expected: chat shows `SwagBag: That's the tour. Type /swagbag tour to see it again, or /swagbag for every setting.`, and nothing in your bags moved. (W12)
12. Type `/swagbag tour`, then press B to close your bags. Expected: one line, `SwagBag: Tour ended because your bags closed. Type /swagbag tour to see it again.`, and no note left on screen. (W12)

## Session 13: Your own categories and your own focus mode (~20 min)

Why: this is the deep power. A broken rule must never mess up your bags, and your own mode must come and go cleanly.
Have ready: a few potions in your bags; some herbs or ore.

1. Type `/swagbag settings categories`. Expected: chat shows `SwagBag: Settings opened.`, and the page starts with `Categories decide which section of your bags each item goes to.`, then the row `Your own` with `New category` and `Paste a Baganator search`. (W11)
2. Click `New category`, click into the box under `Name`, type `My potions` and press Enter. Expected: the status line reads `Name: My potions (click Save to keep it).`, and typing a "b" did not close your bags. (W11)
3. Click `Add a rule`, then `potion` in the `Item type` list. Expected: `Rule now: potion (click Save to keep it).`, and below the rules `Matches N of the M items in your bags right now.` (W11)
4. Click `Show matches in the bags`. Expected: everything but your potions dims in your bags, and nothing moves. (W11)
5. Click `Save`. Expected: `Saved My potions. Your bags use it at their next full layout (when you open them or press Reflow), never moving an item under your mouse.` Your open bags have not changed. Press B twice: a `My potions` section holds your potions. (W11)
6. Click `Edit` next to `My potions (yours), priority 88`, then `Show the rule as text`. Change the text to `potion |` and press Enter. Expected: `The rule has an error: Expected a value after "|" at character N. It can still be saved; your bags keep sorting by the rule before it until it is fixed.` (W11)
7. Click `Save`, then press B twice. Expected: the list shows `My potions (your change has an error: the rule before it is used), priority 88`, and `My potions` still holds your potions. (W11)
8. Click `Edit` next to it, then `Back to the working rule`, then `Delete`, then `Delete: sure?`. Expected: `Deleted My potions. Its items go to the other categories the next time you open your bags.` (W11)
9. Click `Paste a Baganator search`, click into the box, type `#gear & >100g` and press Enter. Expected: `Read as: #gear & value>=100. Check what it matches, name it, then click Make category.` Click `Cancel`: `Nothing was made.` (W11)
10. Click `Focus modes` on the left, then `New mode`. Expected: `A new mode: type its name, pick when it switches on, then click Make mode.` (W12)
11. Click into the box under `Its name (press Enter or Apply)`, type `Herb run`, press Enter, then click `Make mode`. Expected: `Made the Herb run mode. Pick the sections it brings up below; switch it on with /swagbag mode on Herb run or in the list above.` (W12)
12. Click `Open` next to `Herbs`. Expected: `Herbs now opens in the Herb run mode.` Close the settings window and open your bags. (W12)
13. Type `/swagbag mode on herb run`. Expected: `SwagBag: Herb run is on until you switch it off (/swagbag mode off), log out or reload.`, the title starts with `SwagBag — Herb run`, and `Herbs` moves to the top. (W12)
14. Type `/swagbag mode off`. Expected: `SwagBag: Switched off: Herb run.`, and the sections go back to where they were. (W12)
15. Type `/swagbag settings focus`, click `Herb run` in the row `Edit the sections of`, scroll to `Remove this mode`, click `Delete`, then `Delete: sure?`. Expected: `Deleted the Herb run mode.` (W12)

## Session 14: The bank's menu, folding and colours (~15 min)

Why: the slim bank header puts everything else in one `...` menu. Every entry must answer once and leave the window where it was.
Have ready: a banker; a word that matches something in your Character bank (for example a herb name).

1. Open the bank and click `Warband Bank`. Expected: the Character bank is one line ending with `click to show`. (W13)
2. Click that folded line. Expected: the Character bank opens too. Click `Bank`, then `Warband Bank`: each switch folds the other bank again. (W13)
3. Type your word into SwagBag's search box (it matches something only in the Character bank, which is folded). Expected: the Character bank opens by itself with the matching items lit, and its header ends with `N found`, for example `3 found`. Clear the box: the Character bank folds back to one line. (0.13.5)
4. Click the `Bank` tab, then type just the start of a slot word, for example `trink` (or `brac` for bracers). Expected: trinkets light up wherever they are; if they are in the Warband bank, it opens by itself. Typing the full `trinket` gives the same result. Clear the box, then click `Warband Bank` again. (0.13.5, 0.13.6)
5. Rest the mouse on `Sort`. Expected: `Sorts your Warband bank (the bank you deposit into). The ... menu sorts either bank.` (W13)
6. Rest the mouse on `...`. Expected: `More: the view, sorting either bank, regroup, Blizzard's bank, Deposit warbound and settings.` (W13)
7. Rest the mouse on the `With reagents` box. Expected: `Blizzard's own setting: Deposit warbound takes reagents too. Right-click deposits don't change.` (W6, W13)
8. Click `...`. Expected: a menu with, in order, `View: Categories (now)`, `View: List`, `View: Grid`, `Sort Character bank`, `Sort Warband bank`, `Regroup now`, `Show Blizzard's bank (buy tabs, gold)`, `Deposit all warbound items` and `Bank settings...`. Each entry shows a tooltip when the mouse rests on it. (W13)
9. Click `Regroup now`. Expected: items regroup into their sections, and the title shows `Regrouped` (or `Regroups when the mouse leaves the items`). (W13)
10. Click `...`, then `Show Blizzard's bank (buy tabs, gold)`. Expected: Blizzard's bank appears, SwagBag's window moves beside it, the title shows `Blizzard's bank is shown for this visit`, and the bar reads `Right-click deposits to: Warband bank - switch with the tabs on Blizzard's bank`. (W6, W13)
11. Click `...`, then `Hide Blizzard's bank`. Expected: Blizzard's bank goes away, the window goes back where it was, the tabs are in the header again, and the title shows `Blizzard's bank is hidden again`. (W6, W13)
12. Click `...`, then `Bank settings...`. Expected: Settings opens on `Bank & guild`, with the rows `SwagBag's bank window shows` and `Colour the two banks`. Close it. (W13, 0.13.1)
13. Type `/swagbag bank colors off`. Expected: `SwagBag: Bank: both banks use the same plain background.`, and the faint gold and blue bands go away. (0.13.1)
14. Type `/swagbag bank colors on`. Expected: `SwagBag: Bank: the Character bank and the Warband bank have their own faint colour.`, and the bands are back. (0.13.1)
15. Close the bank with its X. Expected: the window hides, your bags' title still reads `SwagBag — right-click to Warband bank`, and the bags show a `Show bank` button. Click `Show bank`: the bank window is back. (W13)
16. Type `/swagbag bank`. Expected: `SwagBag: Use /swagbag bank hidden or shown (Blizzard's bank, now: hidden), one or both (banks shown, now: one), colors on or off (a faint colour per bank).` (W13, 0.13.1)

## Session 15: Item marks, skins and alt counts (~12 min)

Why: the small marks on items must be readable and never hide each other. This is polish, so skip any step you have no item for.
Have ready: if you have them, a cache, a toy, mount or pet you have not learned, gear whose look you have not collected, warbound-until-equipped gear; Masque and Syndicator if you use them; an item you also have on another character.

1. Press B. Expected: a soft green glow on caches, unlearned toys, mounts and pets, and knowledge books. Nothing else glows green. (W7)
2. Look at gear whose look you have not collected. Expected: a small purple `*` at the right edge, touching neither the green upgrade arrow nor the stack count. (W7)
3. Type `/swagbag overlays learn off`. Expected: `SwagBag: Overlay learn is now off.`, and the green glows are gone. Type `/swagbag overlays learn on`: `SwagBag: Overlay learn is now on.` and they are back. (W7)
4. Look at your BoE and warbound-until-equipped gear. Expected: no `BoE` or `WuE` text on them, and warbound-until-equipped gear sits in `Warbound until equipped`, right below `BoE gear`. (W6)
5. Look at the bottom of your bags. Expected: your gold shows as a full-size gold coin and the gold amount with commas, with no silver or copper. Rest the mouse on it: a tooltip `Gold on this character` with the full amount. (W6)
6. (With Masque.) Type `/masque`, pick a clearly different skin for SwagBag, and close Masque's options. Expected: SwagBag's item icons wear it, and the padlock, the star, the green glow and the item levels still show on top. Switch back to your usual skin. (W9)
7. (With Syndicator.) Rest the mouse on an item you also have on another character. Expected: the tooltip shows SwagBag's count lines, including the other character. (W8)
8. (With Syndicator.) Type `/swagbag alts`. Expected: the alt viewer opens and says `Saved data from Syndicator. Nothing here can be used or moved.` Close it. (W8)
9. Type `/swagbag report`. Expected: `Failed checks: none`, `Blocked actions: none`, and a line starting `Categories:` that ends with `Broken: none`. Press Ctrl+C and paste the whole report to Claude. (W9-W12 exit checks)

## Session 16: One icon per item (~15 min)

Why: several stacks of one item now show as one icon with the total, in the bags and both banks. Clicks must still hit the right stack and nothing may move under your mouse.
Have ready: a trade good you can split into two partial stacks (for example 45 and 7); a vendor; a banker; a training dummy and a potion with at least two partial stacks; two copies of one ring with different item levels, a keystone and two caged pets (if you have them).

1. Fully restart the game first: quit completely, start it again and log in. Expected: chat shows `SwagBag: v0.14.0 loaded. Type /swagbag help for commands.`. (0.14.0)
2. Put two partial stacks of one trade good in your bags (Shift-click one, take part of it, drop the part in an empty slot). Close and reopen the bags. Expected: one icon with the total, for example `52`. (0.14.0)
3. Rest the mouse on that icon. Expected: the tooltip shows `2 stacks: 45 + 7` and `Clicks use the stack of 45`. (0.14.0)
4. Shift-click the icon. Expected: Blizzard's split box lets you take at most 45, not 52. Press Esc. (0.14.0)
5. At a vendor, right-click the icon. Expected: the 45 sells and the slot looks empty while your mouse stays there. (0.14.0)
6. Move the mouse away from the items. Expected: the 7 appears in the same place. (0.14.0)
7. Look at two copies of one ring with different item levels, a keystone, and two caged pets. Expected: each one stays its own icon. (0.14.0)
8. Loot one more of that trade good. Expected: it shows in `New` on its own. Hover it, close and reopen the bags: it joins the group. (0.14.0)
9. At the bank, look at two stacks of one item in the Warband bank. Expected: one icon. (0.14.0)
10. Put one stack of an item in the Character bank and one in the Warband bank. Expected: two icons, one in each bank. (0.14.0)
11. Switch the bags to the list view. Expected: the Count column shows the total. Click the `Count` header until it reads `Sorted by Count, highest first`. Expected: the group sits where its total belongs. (0.14.0)
12. Shift+right-click a section header and choose `Sell all (N)`, then accept the question. Expected: both stacks are sold, and the chat line counts both. (0.14.0)
13. Type `/swagbag stacks all`. Expected: `SwagBag: Every stack is shown again.`, and the window shows both stacks once the mouse leaves the items. (0.14.0)
14. Open Settings > Bags, find `Same item in several stacks (bags and banks)` and click `One icon with the total`. Expected: the one icon is back. (0.14.0)
15. At a training dummy, in combat, drink a potion from a grouped icon until its stack runs out. Expected: the next stack appears in its place after you move the mouse away, and there is no "Interface action failed" message. (0.14.0)
16. Type `/swagbag stacks`. Expected: `SwagBag: Use /swagbag stacks one or /swagbag stacks all (now: one).`. (0.14.0)

## If something goes wrong

- **A red error, or anything odd:** type `/swagbag report`, press Ctrl+C, paste the whole report to Claude, then press Esc. Chat first says `SwagBag: Report opened. Press Ctrl+C to copy it, then paste it into Claude Code.`
- **Your bags or bank act up and you need them working now:** type `/swagbag safe on`. Blizzard's own bags and bank come back at once (`SwagBag: Safe Mode is ON for bags: Blizzard's frames are used. Type /swagbag safe off to switch back.`). Type `/swagbag safe off` to bring SwagBag back, and `/swagbag safe` to see which windows are in Safe Mode.
- **New is full of items you have already seen:** type `/swagbag new seen`. Chat says `SwagBag: New is cleared: N items went back to their sections.`
- **A setting change went wrong:** type `/swagbag profile undo` to go back to before the last load, import or reset.
