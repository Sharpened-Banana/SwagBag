# SwagBag week 3: in-game test checklists

These are the checklists for the week 3 sessions (banks, guild bank, overlays, free count, prices). Work through them in the order given here.

**Before the first session, do a FULL game restart.** Quit World of Warcraft completely and start it again. Week 3 added new files, so `/reload` is not enough. After that, `/reload` is fine only where a session says so.

**If anything goes wrong at any point,** type `/swagbag report`, press Ctrl+C, and paste the output to Claude.

Each session ends with a reply line for Claude. Steps that give "(note it)" or "tell Claude" are things the code could not check on its own: say what you saw.

Session order: O1, F1, V2, B1, G1, G2, P1, S3.

---

## Session O1: bags overlays and the title item level

Purpose: check the item-level, track, bind, upgrade-arrow, keystone and junk overlays on your bags, and the item level in the bags title. Bags only: the bank and guild bank are checked later in G2. About 10 minutes.

You need:
- some gear, including one piece better than what you wear if you have one;
- your keystone;
- a gray item;
- some crafting materials;
- a reagent bag with empty slots, if you have one;
- Pawn, if you use it (optional).

1. Quit the game completely and start it again (new files). Log in. Press **B**. Expected: the bags window opens.
2. Look at the bags window's title. Expected: it reads `SwagBag — ilvl` and a number with one decimal, for example `SwagBag — ilvl 279.4`. Press **C**: the character window's item level is the same number (the character window may round it). Press **C** again to close it.
3. Look at your gear. Expected: gear shows its item level in the top left corner (for example `285`). Gear with an upgrade track shows it in the bottom left (for example `H3/6`). If **no** gear shows a track, tell Claude: the game's track information may be missing.
4. Look for a BoE item and a warbound-until-equipped item. Expected: a BoE item shows `BoE` on its left side, and a warbound-until-equipped item shows `WuE`.
5. Look for gear that beats what you wear in that slot. Expected: it shows a small green arrow in its top right corner. For rings and trinkets, "what you wear" means the weaker of your two. If no arrow shows at all on gear that clearly beats yours, tell Claude. Also note whether Blizzard's own upgrade arrow shows next to SwagBag's (a doubled-up arrow).
6. Right-click an item that has an arrow to equip it. Expected: within a moment its arrow is gone, the piece you took off shows an arrow only if it beats what you now wear, and **the number in the title changes**. Move the mouse off it. (No arrow anywhere? Equip any piece with a different item level than the one it replaces: the number in the title changes all the same. Put your usual piece back afterwards.)
7. Hold **Ctrl** and turn the mouse wheel up one notch over the items. Expected: the title says `SwagBag 105%` for a moment, then `SwagBag — ilvl …` again. Turn the wheel down one notch to go back to your size.
8. Click `Reflow`. Expected: the title says `Regrouped` for a moment, then `SwagBag — ilvl …` again.
9. Look at your keystone. Expected: it shows `+` and its level in the top left (for example `+12`) and a short dungeon name in the bottom left.
10. Look at a gray item. Expected: it shows a small coin. If no coin shows, tell Claude. Also note whether Blizzard's own junk coin shows next to SwagBag's (a doubled-up coin).
11. If you have a reagent bag with empty slots, look at the empty reagent-bag slots shown in `Free`. Expected: they have a faint green tint. (Once Task 5 is in, that is the single reagent slot with a number; session F1 checks it.)
12. Type `/swagbag overlays`. Expected: chat says `Overlays: ilvl on, track on, upgrade on, keystone on, junk on, bind on, pawn off, title on`.
13. Type `/swagbag overlays ilvl off`. Expected: chat says `Overlay ilvl is now off.`, and the item levels on the items disappear. Type `/swagbag overlays ilvl on`: they come back.
14. Type `/swagbag overlays title off`. Expected: chat says `Overlay title is now off.`, and the title reads just `SwagBag`. Type `/swagbag overlays title on`: the item level is back in the title.
15. If you use Pawn, type `/swagbag overlays pawn on`. Expected: chat says `SwagBag: Overlay pawn is now on.`, and the arrows now follow Pawn wherever Pawn has an opinion; an item Pawn has no opinion on keeps the item-level arrow. Without Pawn (or before Pawn has finished loading), chat also says `SwagBag: Pawn is not loaded or not ready yet, so the item-level rule decides the upgrade arrow.` Either way, type `/swagbag overlays pawn off` afterwards. (Updated by week 4 Task 11, ruling W4-15.)
16. Look at every crest or valorstone item you carry. Expected: each is in `Keystone & Crests`. If one is somewhere else, drop it on the `Keystone & Crests` header and tell Claude its exact name.
17. If you carry a wand or another ranged weapon, look at it. Note whether it shows an arrow and whether that makes sense against the weapon you wield, and tell Claude what you see. (Skip if you have none.)
18. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Expected: Claude sees no new errors and `Blocked actions: none`.

Pass: steps 2–17 behave as described. Report every crest name from step 16: Claude adds their item IDs to `Engine/Crests.lua`.

Reply to Claude with: O1 done, and the numbers of any steps that didn't match

---

## Session F1: free slot count

Purpose: check that `Free` shows one slot with the number of free slots, and that it behaves while you move items and in combat. About 5 minutes.

You need:
- `/reload` is enough (no new files);
- a stack of at least two of the same item (potions, food or reagents);
- at least two free slots in your bags;
- a training dummy (for steps 8 and 9);
- an empty bag to swap for a different bag of the SAME size (for step 9; optional).

1. Type `/reload`. Press **B**. Expected: at the bottom of the window, under `Free`, there is one empty slot with a large white number in it. The number is how many free slots your bags have; your reagent bag is not counted in it. If you have a reagent bag with free slots, there is a second empty slot with its own number and a faint green tint.
2. Note the number on the first slot.
3. Hold **Shift** and click your stack of two or more. In the small box that opens, click **Okay**. Expected: one item from the stack is now on your mouse cursor, and the stack stays where it was.
4. Click the slot with the number. Expected: the item goes into that slot. While your mouse stays on it, the slot shows the item and no number.
5. Move the mouse off it. Expected: the item moves to `New`. An empty slot with the number **one lower** than in step 2 now shows exactly where the item went in.
6. Type `/swagbag free all`. Expected: chat says `Every free slot is shown again.` Move the mouse off the window if it is over it. `Free` now shows all your empty slots, with no number.
7. Type `/swagbag free tile`. Expected: chat says `Free slots now show as one slot with the number of free slots.` `Free` shows the one slot with the number again.
8. Leave one free slot showing the count. Start a fight with a training dummy. While in combat, use or delete the item that sits right before the count so a slot empties. Expected: no red error and no "blocked" message; the count goes up by one. Leave combat.
9. Swap an empty bag in a bag slot for a different bag of the SAME size (skip if you do not have one). Move the mouse off the bags. Expected: within a second, the free count is right. If not, click the Reflow button at the top of the bags window and note "swap needed reflow".
10. If you have a reagent bag with free slots, look at its tinted slot again, and note whether the faint green tint stays on the reagent slot after steps 6 to 9 (in `Free all` mode and in tile mode). Tell Claude if it is missing in either.
11. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Expected: Claude sees no new errors and `Blocked actions: none`.

Pass: steps 1 and 4–9 behave as described.

If it fails: tell Claude which step. Until it is fixed, type `/swagbag free all`: `Free` shows every free slot, as before this task.

Reply to Claude with: F1 done, and the numbers of any steps that didn't match

---

## Session V2: the SwagBag bank window (deposits, Blizzard's bank button, tabs)

Purpose: check that the SwagBag bank window replaces Blizzard's, deposits go to the right bank, and nothing is blocked. About 10 minutes.

You need:
- a banker nearby;
- two cheap gray (junk) items in your bags that you do not mind moving;
- your Hearthstone in your bags;
- your Hearthstone is not on cooldown;
- not to be in a group.

Blizzard's bank tabs carry Blizzard's own labels, not SwagBag's: the character bank tab is labelled Bank and the warband tab is labelled Warband Bank.

1. Log in. (You already did the full restart before the first session; if not, quit the game completely and restart it now, because `/reload` is not enough.) Expected: chat shows `SwagBag: v0.3.0 loaded. Type /swagbag help for commands.`
2. Talk to the banker. Expected: Blizzard's bank window does **not** appear. A small dark window titled `SwagBag bank` appears instead, with a `Blizzard bank` button at its top right. It is empty for now (the bank's items come later this week). Blizzard's own bank tabs hang under its bottom edge, and your SwagBag bags open too.
3. Read the second line of the SwagBag bank window. Expected: it says `Deposits go to Character bank - switch with the tabs below` (or `Deposits go to Warband bank - switch with the tabs below` if the warband tab was selected last time).
4. Click the tab labelled Warband Bank under the SwagBag bank window. Expected: the line now says `Deposits go to Warband bank - switch with the tabs below`. (If the tabs are not under the window, or do not respond, tell Claude.)
5. In your SwagBag bags, right-click one gray item. Expected: it leaves your bags (a faded copy stays where it was), and no red error message appears at the top of the screen. Move the mouse off it.
6. Click `Blizzard bank`. Expected: the SwagBag bank window's title says `Blizzard's bank is shown for this visit` for a moment, and Blizzard's bank window appears, open on the warband bank. **The gray item is in the warband bank.**
7. With Blizzard's bank window still showing, click the tab labelled Bank at the bottom of Blizzard's bank window. Expected: Blizzard's bank switches to the character bank, and the second line of the SwagBag bank window now says `Deposits go to Character bank - switch with the tabs below`. Click the tab labelled Warband Bank: the line says `Deposits go to Warband bank - switch with the tabs below` again.
8. Click `Blizzard bank` again. Expected: Blizzard's bank window disappears, the title says `Blizzard's bank is hidden again` for a moment, and the tabs are back under the SwagBag bank window.
9. Click the tab labelled Bank under the SwagBag bank window. Expected: the line says `Deposits go to Character bank - switch with the tabs below`. Right-click the second gray item in your bags. Expected: it leaves your bags, and no red error message appears at the top of the screen. Move the mouse off it.
10. Click `Blizzard bank`. Expected: **the second gray item is in the character bank.** Click `Blizzard bank` again.
11. Click the **X** of the SwagBag bank window. Expected: only that window closes. Your bags window now shows a `Bank still open` button in its title row. Click it: the SwagBag bank window comes back.
12. Press **Esc** once. Expected: the SwagBag bank window closes. Press **B**: your bags window has **no** `Bank still open` button (the Esc ended the bank visit).
13. Walk a few steps away from the banker. Right-click your Hearthstone in the SwagBag bags, then move the mouse off it. Expected: the cast bar appears. There is **no** red error message at the top of the screen; Blizzard's message would read: Interface action failed because of an AddOn. Move to cancel the cast if you want to stay.
14. Type `/swagbag bank beside`. Expected: chat says `Bank: Blizzard's bank is shown, with SwagBag's bank window beside it.` Talk to the banker: Blizzard's bank appears as usual, and the SwagBag bank window sits to its right. Press **Esc**.
15. Type `/swagbag bank tiny`. Expected: chat says `Bank: Blizzard's bank is hidden; its tabs are under SwagBag's bank window.`
16. Type `/swagbag report`, press Ctrl+C, and paste it into Claude Code. Claude checks:
    - the first line starts `SwagBag 0.3.0`;
    - `Blocked actions: none` and no new errors;
    - a line `Bank: setting tiny, last visit beside, last deposit target …`.

Pass: in steps 6 and 10 each item landed in the bank that the line named, step 7 updated the line from Blizzard's own tabs, step 13 cast with no red message, and the report is clean.

If it fails: tell Claude which step. Until it is fixed, type `/swagbag bank beside`: Blizzard's bank stays visible and deposits are Blizzard's own.

Reply to Claude with: V2 done, and the numbers of any steps that didn't match

---

## Session B1: the bank contents (groups, sections, sort, search, snapshots)

Purpose: check that the SwagBag bank window shows the character bank and the warband bank as two groups with sections, and that items, sorting, search and the saved snapshot work. About 15 minutes.

You need:
- a banker to stand at;
- some items in both the character bank and the warband bank;
- an item in your bags that the bank does not already hold (for steps 4 and 5);
- a reagents-only bank tab, if you have one (for step 14; optional).

1. Log in. (You already did the full restart before the first session; if not, quit the game completely and restart it now.) Expected: chat shows `SwagBag: v0.3.0 loaded. Type /swagbag help for commands.`
2. Talk to the banker (this is the first bank visit since the restart). Expected: the `SwagBag bank` window now shows two groups:
   - `- Character bank (N)` on top. If it is the selected tab, its header is green and ends with `  - deposits go here`.
   - `- Warband bank (N)` below.
   Each group has its own sections: `- New (0)`, your categories, and `- Free (N)`. If a group shows no items or puts everything in `Free` until you close and reopen the bank, tell Claude.
3. Click the warband tab under the window. Expected: the green header and `  - deposits go here` move to `Warband bank`. Nothing else moves.
4. Right-click an item in your SwagBag bags that the bank does not already hold. Expected: it appears in the first cell of `New` in the Warband bank group, and nothing else in the bank window moves. Move the mouse off it.
5. Right-click an item in the Character bank group. Move the mouse off it. Expected: it goes to your bags, a faded copy stays where it was, and the button moves to the end of that group's `Free`.
6. Click a section header in the bank window (for example `- Herbs (N)`). Expected: it turns into `+ Herbs (N)`, and the sections below move up. The header you clicked does not move. Click it again: every item returns to the same place.
7. Click the `- Warband bank (N)` header. Expected: the whole warband group folds into `+ Warband bank (N)`. Click it again to open it.
8. Click the bank window's search box and type `ore`. Expected: the bank items that are not ore dim, and your bags window is not dimmed. Clear the box with its small x.
9. Click `Sort bank`. Expected: the title says `Sorting...`, Blizzard sorts the character bank, and about half a second after it stops the bank window regroups (the title says `Regrouped`, and the faded copies are gone). Click `Sort warband`: the same for the warband bank. (If a bank was already sorted, nothing moves. That is fine.)
10. Click `Grid`. Expected: the title says `SwagBag bank - grid view` (if the text is too long for the space it is cut short with an ellipsis and never runs under the buttons), each group shows its slots in bank order, and the button now says `Categories`. Click `Categories` to go back.
11. Type `/swagbag snapshot`. Expected: chat shows four lines:
    - `Bags: …`;
    - `Bank: just now` (or `1 min ago`);
    - `Warband bank: just now` (or `1 min ago`);
    - `Saved: N characters, N KB in all`.
12. Walk away from the banker, then talk to the banker again (a fresh open). Expected: the item you deposited in step 4 is no longer in `New` (it sits in its category). Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks:
    - `Last bank layout: … ms (open)` is at or below 80 ms;
    - `Snapshots: 1 characters, 0 guilds, … KB` (for check V10: at or below about 30 KB for this character);
    - `Bank: setting tiny, last visit tiny, …`;
    - no new errors and `Blocked actions: none`.
13. Walk away from the banker. Right-click your Hearthstone. Expected: the cast bar appears, with no red message.
14. If you have a reagents-only bank tab: talk to the banker and look at the Character bank group. Note whether that reagents-only tab's free slots are counted in the Character bank's `Free (N)` number and shown in its `Free` section, or whether it behaves separately, and tell Claude what you see. (Skip if you have none.)
15. Stand at the bank and type `/reload`. Then type `/swagbag snapshot`. Expected: `Bank: just now` does not update until your next bank visit. This is expected.

Pass: steps 2–13 behave as described, and no item moved while the mouse was on it.

Reply to Claude with: B1 done, and the numbers of any steps that didn't match

---

## Session G1: the SwagBag guild bank window (moving items)

Purpose: check that the SwagBag guild bank window replaces Blizzard's, items move in and out with no blocked-action error, and the guild tab rules work. About 10 to 15 minutes.

You need:
- a guild vault;
- a guild bank tab you may both deposit into and withdraw from (at least two withdrawals left today), with at least one free slot;
- a second tab you may withdraw from (for steps 7 to 10);
- one cheap item you do not mind putting in the guild bank;
- at least three free slots in your bags;
- your Hearthstone in your bags;
- your Hearthstone is not on cooldown.

The guild bank tabs are Blizzard's own tab buttons, not SwagBag's: small square buttons, each showing the picture your guild chose for that tab, stacked top to bottom. Hover one to see the tab's name. In this session they sit along the right edge of the SwagBag guild bank window instead of Blizzard's guild bank window. (Their exact look in 12.1 is not yet confirmed: if they look different, tell Claude what you see.)

1. Log in. (You already did the full restart before the first session; if not, quit the game completely and restart it now, because `/reload` is not enough.) Expected: chat shows `SwagBag: v0.3.0 loaded. Type /swagbag help for commands.`
2. Open the guild vault. Expected: Blizzard's guild bank window does **not** appear. A dark window titled `SwagBag guild bank` appears instead, with a `Blizzard guild bank` button at its top right and Blizzard's square tab buttons down its right edge. Each tab you may view has a line such as `Mats - 5 withdrawals left today (loading...)` (or `Mats - unlimited withdrawals (loading...)`, or `Mats - no withdrawals left today (loading...)`). The lines are gold, except the selected tab's line, which is green. Within a few seconds `(loading...)` goes away and the tab's items appear in a grid under its line.
3. Read the window's second line. Expected: it says `Deposits go to <tab name> - switch with the tabs on the right`. That tab's line ends with `- deposits go here` and is green.
4. Click the square tab button on the right for the tab you may deposit into and withdraw from (hover the buttons to find it by name). Expected: the second line now names that tab, and that tab's line is the green one ending with `- deposits go here`.
5. In your SwagBag bags, right-click the cheap item, then move the mouse off it. Expected: it leaves your bags, and no red error message appears at the top of the screen. Within a second it shows in the grid under the tab named on the second line.
6. In the SwagBag guild bank window, right-click that item, then move the mouse off it. Expected: it comes back to your bags, and no red error message appears at the top of the screen. If the tab is not unlimited, its `withdrawals left today` number goes down by one.
7. Right-click an item in your second tab's grid (not the green one), then move the mouse off it. Expected: nothing moves, and chat says `Click the <tab> tab on the right first, then right-click the item again.` with that tab's name in place of `<tab>`.
8. Type `/swagbag guild anytab on`. Expected: chat says `Guild bank: a right-click now withdraws from any tab, not only the selected one.`
9. Remember which item you will click, then right-click it in your second tab's grid (not the green one), then move the mouse off it. Expected: the SAME item you clicked lands in your bags, no red error message appears at the top of the screen, and nothing disappears from the green tab's grid. If a different item arrives, or something leaves the green tab, tell Claude, and do step 10 right away.
10. Type `/swagbag guild anytab off`. Expected: chat says `Guild bank: a right-click withdraws only from the selected tab.`
11. Drag an item from the green tab's grid in the SwagBag guild bank window onto an empty slot of your SwagBag bags, then move the mouse off it. Expected: it is in your bags, and no red error message appears at the top of the screen. Drag it back onto an empty slot in the green tab's grid, then move the mouse off it. Expected: it is back in the guild bank, and no red error message appears at the top of the screen.
12. Press **Enter** to open the chat box, then shift-click an item in the SwagBag guild bank window, then move the mouse off it. Expected: the item's link appears in the chat box. Press **Esc** to clear the chat box.
13. Click `Blizzard guild bank`. Expected: the SwagBag guild bank window's title says `Blizzard's guild bank is shown for this visit (gold, log, permissions)` for a moment, and Blizzard's guild bank window appears, with the SwagBag guild bank window to its right. Right-click an item in the SwagBag guild bank window, then move the mouse off it. Expected: chat says `SwagBag's guild bank is view-only now: move items in Blizzard's guild bank window.` Nothing moves.
14. Click `Blizzard guild bank` again. Expected: Blizzard's guild bank window disappears, the title says `Blizzard's guild bank is hidden again` for a moment, and the square tab buttons are back on the right edge of the SwagBag guild bank window.
15. Press **Esc** once. Expected: the SwagBag guild bank window closes. Blizzard's guild bank window does **not** appear. If it appears, tell Claude.
16. Walk about 20 steps away, until the vault is out of reach. Right-click your Hearthstone in the SwagBag bags, then move the mouse off it. Expected: the cast bar appears. There is **no** red error message at the top of the screen; Blizzard's message would read: Interface action failed because of an AddOn. Move to cancel the cast if you want to stay.
17. Type `/swagbag report`, press Ctrl+C, and paste it into Claude Code. Claude checks:
    - the first line starts `SwagBag 0.3.0`;
    - `Blocked actions: none` and no new errors;
    - a line `Guild bank: setting full, last visit full`.

Pass: steps 5, 6 and 11 moved the items as described with no red error message, step 7 refused with the message, step 16 cast with no red message, and the report is clean.

If it fails: tell Claude which step. If step 5, 6 or 11 failed, or the report lists a blocked action, type `/swagbag guild view`. Chat says `Guild bank: Blizzard's window is shown; SwagBag's window beside it is view-only.` SwagBag's window then only shows the guild bank, and you move items in Blizzard's window.

Reply to Claude with: G1 done, and the numbers of any steps that didn't match

---

## Session G2: the guild bank on the new layout (groups, overlays, snapshot)

Purpose: check the guild bank's tab groups, sections and overlays, the bank overlays, and the saved guild snapshot. About 15 minutes.

You need:
- `/reload` is enough (no new files);
- a guild with vault access;
- a banker too (steps 1 and 2);
- one piece of gear better than what you wear if you have one;
- a BoE item or any gear in the bank beforehand, if you can;
- a cheap item in your bags that the guild bank does not hold (for steps 6 and 7);
- your Hearthstone in your bags and not on cooldown.

1. Type `/reload`. Talk to a banker. Expected: in the `SwagBag bank` window, gear shows its item level in the top left corner (for example `285`), a BoE item shows `BoE` on its left side, gear that beats what you wear shows the small green arrow, and gray items show the coin, just as in your bags.
2. Right-click a piece of gear in your bags to equip it while the bank window is open. Expected: within a moment the arrows in the bank window follow your new gear, and the number in your bags window's title changes. Move the mouse off it. Press **Esc**.
3. Open the guild vault, and rest the mouse on the guild window while the tabs load. Expected: sections appear anyway. Every tab you may view is a group, for example `- Mats (12) - 5 withdrawals left today`. Under each header are its own sections: `- New (0)`, your categories, `- Free (N)`. For a moment some tab headers may end with `(loading...)`.
4. Look at the guild gear. Expected: it shows its item level in the top left and `BoE` where it applies, as in your bags. Gear that beats what you wear shows the green arrow. Also note whether guild gear that has an upgrade track (for example `H3/6`) shows it in the bottom left, and tell Claude if it does not.
5. Look at the selected tab's header. Expected: it is green and ends with `  - deposits go here`. Click another tab icon on the right: the green header follows.
6. Right-click the cheap item in your bags. Move the mouse off it. Expected: it appears in the first cell of `New` in the selected tab's group.
7. Right-click that item in the guild window. Move the mouse off it. Expected: it goes back to your bags, its slot in the guild window becomes empty (no faded copy, because it was in New), and nothing else moves.
8. Click a tab's header, for example `- Mats (12) …`. Expected: the whole tab folds into `+ Mats (12) …`. Click it again to open it.
9. Type `herb` (or any word) in the guild window's search box. Expected: the guild items that do not match dim, and your bags are not dimmed. Clear the box.
10. Click `Grid`. Expected: the title says `SwagBag guild bank - grid view`. Click `Categories` to go back.
11. Press **Esc**. Open the vault again. Expected: the tabs' items show at once, with no `(loading...)`. If an empty guild tab says `(loading...)` for the whole visit, note it and tell Claude which tab (this is a known watch point, not necessarily a fault).
12. If any tab still says `(loading...)`, click or right-click an item in it. Expected: nothing moves, and chat says `Still loading <tab> - try again in a moment.` with that tab's name. (Skip if no tab is loading.)
13. Press **Esc**, walk away, and right-click your Hearthstone. Expected: the cast bar appears, with no red message.
14. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks `Snapshots: … 1 guilds …`, `Guild bank: setting full, last visit full`, no new errors and `Blocked actions: none`.

Pass: steps 1–14 behave as described, and no item moved while the mouse was on it.

Reply to Claude with: G2 done, and the numbers of any steps that didn't match

---

## Session P1: prices in section headers

Purpose: check that section headers show a total value (Auctionator or vendor), and that the `value` search works in bags, bank and guild windows. About 5 minutes.

You need:
- some crafting materials and a few consumables;
- Auctionator, if you have it (say whether it was on or off when you reply);
- a banker and a guild vault to stand at.

1. Quit the game completely and start it again (new files, if you have not done the restart for this week). Log in. Press **B**. Expected: the bags window opens.
2. Look at the section headers. Expected: they end with a value. With Auctionator: for example `- Trade Goods (12) - 1,240g`. Without it: for example `- Trade Goods (12) - 35g vendor`. A section worth nothing shows no value. Note: `Free`'s total includes items that overflowed `New`, which is expected. Warbound-until-equipped gear is priced at its vendor price, so it can show a low value.
3. Click the bags window's search box and type `value>1`. Expected: items worth 1 gold or less each, and items with no price, dim. Clear the box with its small x.
4. Talk to a banker. Expected: the bank window's section headers show values the same way. Press **Esc**.
5. Open the guild vault. Expected: the guild window's section headers show values too. Press **Esc**.
6. If you have Auctionator, run an Auctionator scan or let it update its prices, with the bags window open. Expected: within about a second the header values change in place, without the window regrouping. (Skip without Auctionator.)
7. Type `/swagbag report`, press Ctrl+C and paste it into Claude Code. Claude checks `Prices: Auctionator, … cached` (or `Prices: Vendor, … cached` without Auctionator), no new errors and `Blocked actions: none`.

Pass: steps 2–7 behave as described.

Reply to Claude with: P1 done (Auctionator on or off), and the numbers of any steps that didn't match

---

## Session S3: resizing the window and where it stays

Purpose: check that resizing the bags window keeps its top-left corner in place, and that using up a stack does not shuffle the window. About 2 minutes.

You need:
- `/reload` is enough (no new files);
- an item stack you can use up (for example your last food).

1. Type `/reload`. Press **B**. Move the window somewhere easy to see.
2. Hold **Ctrl** and turn the mouse wheel up two notches over the items. Expected: the window grows, and its top-left corner stays exactly where it was.
3. Press **B** twice (close, open). Expected: the window opens at the same place and size as in step 2.
4. Hold **Ctrl** and turn the wheel down two notches. Expected: the window shrinks back, and its top-left corner stays put.
5. Use up the last item of a stack (for example eat your last food), then move the mouse off it. Expected: a faded copy stays where it was, and nothing else in the window moves.

Pass: steps 2–5 behave as described.

Reply to Claude with: S3 done, and the numbers of any steps that didn't match
