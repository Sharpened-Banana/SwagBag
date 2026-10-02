# SwagBag week 4: in-game test checklists

## Before you start

- Week 4 needs the week-4 build installed. Your game currently has the stable week-3 copy. Ask Claude to "install week 4" and Claude installs it. After an install you must fully restart the game (quit it completely and start it again; /reload is not enough).
- If anything shows a red error, type `/swagbag report`, press Ctrl+C and paste the output to Claude.
- After each session, reply "<session> done" (for example "FM1 done") plus the numbers of any steps that didn't match.
- A step marked "(note it)" asks for something the code cannot check: say what you saw.
- With the item level on (the default), the bags title is `SwagBag — <mode> — ilvl <number>`. A long title may end in `...`; only its start matters.
- "(updated)" marks text taken from a later fix round that replaced the plan's original.

Order: O2, FM1, S1, Q1, FT1, W1, DR1, K1, the daily focus check, the exit check.

---

## Session O2: the O1 fixes (about 10 minutes)

Purpose: rechecks week 3's O1 overlays (Pawn, bigger overlays), New hidden while empty, and no blue glow.

You need:
- some gear, including one piece better than what you wear if you have one;
- a gray item (a gray weapon or armor piece too, if you have one);
- a stack of two or more of the same item (potions, food or reagents);
- at least two free slots in your bags;
- Pawn, if you use it (optional);
- a training dummy for step 21 (optional).

Claude installs the week-4 build first (the installed copy is week 3's).

1. Quit the game completely and start it again. Log in. Expected: chat shows `SwagBag: v0.4.0 loaded. Type /swagbag help for commands.`
2. Press **B**. Expected:
   - the bags open, and the title starts with `SwagBag — ilvl`;
   - there is **no** `New` header (you have looted nothing since logging in): the first header is another section, for example `- Keystone & Crests (`;
   - no item has a blue glow.
3. Look at your gear (O1 step 3). Expected: the item level in the top left and the upgrade track in the bottom left (for example `H3/6`). Both are bigger than last week, with a thick black outline, and stay inside the slot. Say whether they are easy to read now (note it).
4. Look for a BoE or warbound-until-equipped item (O1 step 4). Expected: `BoE` or `WuE` on its left side, readable, between the item level and the track.
5. Look for gear that beats what you wear (O1 step 5). Expected: a green arrow in its top right corner, bigger than last week. Say whether it is big enough (note it).
6. Look at a gray item (O1 step 10). Expected: a gold coin with a dark outline, bigger than last week, in its top left corner. On gray gear the item level is top left and the coin is in the bottom left corner. Say whether the coin stands out enough (note it).
7. Look at your stack of two or more. Expected: Blizzard's stack count in the bottom right corner is fully visible; nothing covers it.
8. If you use Pawn (O1 step 15), type `/swagbag overlays pawn on`. Expected: chat shows `SwagBag: Overlay pawn is now on.` and nothing else. Without Pawn, a second line shows: `SwagBag: Pawn is not loaded or not ready yet, so the item-level rule decides the upgrade arrow.` (If you use Pawn and this second line shows, tell Claude.)
9. Look at your gear. Expected: the arrows follow Pawn. A piece Pawn has no opinion on still shows an arrow when its item level beats what you wear. Say whether the arrows look right to you (note it).
10. Type `/swagbag overlays pawn off`. Expected: chat shows `SwagBag: Overlay pawn is now off.`
11. Hold **Shift** and click your stack. In the small box that opens, click **Okay**. Expected: one item from the stack is on your mouse cursor.
12. Click the slot with the large white number in `Free`, and keep the mouse on it. Expected: the item goes into that slot, and nothing else in the window moves while the mouse stays over the items.
13. Move the mouse off the bags window. Expected:
    - within half a second a `- New (1)` header appears at the top, with the item in it;
    - every section below moved down together with its header.
14. Move the mouse onto that item in `New`, then off it again. Expected: no blue glow on it, now or after.
15. Click that item to pick it up, then click the stack it came from. Expected:
    - the item joins the stack;
    - once the mouse is off the slot the item came from, `New` still sits at the top, reading `- New (0)`, with its empty rows;
    - nothing else moves.
16. (updated) Move the mouse off the items, then click `Reflow` in the title bar. Expected:
    - the title says `Regrouped` for a moment;
    - `New` is gone, and the first header is another section again.
17. Type `/swagbag new always`. Expected:
    - chat shows `SwagBag: New now keeps its rows at the top even when it is empty.`;
    - `- New (0)` and two empty rows are back at the top. If the mouse is over the bags, move it off first.
18. (updated) Type `/swagbag new auto`. Expected: chat shows `SwagBag: New is now hidden while it is empty. When something new arrives it shows, and it stays until you next open the bags or click Reflow.`, and `New` is gone again. If the mouse is over the bags, move it off first.
19. Type `/swagbag`. Expected: the window `SwagBag settings` opens at `Bags`. In the row `The New section when it is empty`, `Hidden` is highlighted and `Always shown` is right next to it. Press **Esc**.
20. Type `/reload`. Press **B**. Expected: no item has a blue glow (the O1 bug). If any item glows blue, tell Claude which (note it).
21. (Optional, at a training dummy) Start a fight. While in combat, move the mouse slowly over several items. Expected: no red error and no "blocked" message. Leave combat.
22. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 2, 7, 8 (or its no-Pawn line), 10–20, and 21 if you tried it. Steps 3, 5, 6 and 9 are your call: say "too small", "fine" or "too big".

Reply to Claude with: O2 done, the numbers of any steps that didn't match, and your call on steps 3, 5, 6 and 9

---

## Session FM1: focus modes in town, at the vendor and the bank, while fishing and gathering (about 15 minutes)

Purpose: checks that sections open and close by themselves as you move between town, vendor, bank, fishing and gathering, plus peek, keep-open and pause.

You need:
- a vendor and a banker nearby;
- an item in Junk, or any gray item;
- for steps 18–20: a fishing pole and water (optional);
- for steps 21–23: a gathering profession and a node or a skinnable creature (optional).

1. Quit the game completely and start it again (new files). Log in. Expected: chat shows `SwagBag: v0.4.0 loaded. Type /swagbag help for commands.`
2. Press **B**. Expected: the bags open and the title starts with `SwagBag — ilvl`. The buttons at the top read, from left to right: `Sort`, `Pause`, `Reflow`, `Grid`. Keep the bags open for the whole session; if they close, press **B** again.
3. Click the `Junk` header. Expected: it reads `+ Junk (` and a number. This is your own choice, and SwagBag keeps it.
4. Right-click a vendor to open the vendor window. Expected:
   - the title starts with `SwagBag — AH/Vendor/Bank`;
   - `New`, `BoE gear`, `Trade Goods` and `Junk` start with `-` (those you have items in);
   - every other section header starts with `+`.
5. Close the vendor window. Expected: the title starts with `SwagBag — ilvl` again, and `Junk` is back to `+` (your choice from step 3).
6. Click the `Junk` header. Expected: it reads `- Junk (`.
7. Open the vendor window again. Rest the mouse on an item in `Junk` and keep it still.
8. With the mouse still on that item, walk away from the vendor with the keyboard until the vendor window closes. Expected:
   - the title starts with `SwagBag — ilvl`;
   - the item under your mouse does **not** move while the mouse stays on it.
9. Move the mouse off the item. Expected: within half a second the other sections open, and the Junk items move down together with their header.
10. Open the vendor window again. Click the `+ Consumables` header. Expected: it reads `- Consumables (`, a number, then `)  (peek - right-click keeps it open)`.
11. Press **B** twice (close and open the bags). Expected: `Consumables` reads `+ Consumables (` again (a peek ends when the bags close).
12. Right-click the `Consumables` header. Expected: it reads `- Consumables (`, a number, then `)  (kept open)`.
13. Press **B** twice. Expected: `Consumables` still ends in `(kept open)`.
13a. (updated) Pick up any item from your bags (click it once so it sits on the mouse pointer), then right-click the `Consumables` header. Expected: chat shows `SwagBag: Added <item name> to Consumables. It moves there when you reopen your bags or press Reflow.`, and the item is no longer on the pointer. Move the mouse off the header.
14. Click `Pause`. Expected:
    - chat shows `SwagBag: Focus modes are paused for this session: sections stay as you set them. Click Resume, or type /swagbag mode resume.`;
    - the button now says `Resume`;
    - the title starts with `SwagBag — Paused`;
    - no section is collapsed (none starts with `+`).
15. Click `Resume`. Expected:
    - chat shows `SwagBag: Focus modes are back on: sections follow what you are doing again.`;
    - the title starts with `SwagBag — AH/Vendor/Bank`;
    - `Consumables` reads `+ Consumables (` (a resume starts the mode fresh).
16. Close the vendor window. Walk to a banker and open the bank. Expected:
    - the title starts with `SwagBag — AH/Vendor/Bank`;
    - every bags section is open (at the bank everything stays open);
    - the bank window looks exactly as it did last week.
17. Close the bank. Type `/swagbag mode list`. Expected: six chat lines, each with `- opens` and a list of sections. They start `SwagBag: M+: on`, `SwagBag: Raid: on`, `SwagBag: Delves: on`, `SwagBag: Gathering: on`, `SwagBag: Fishing: on` and `SwagBag: AH/Vendor/Bank: on`.
17a. (updated) Open the bank. Right-click a section header in the bank window. Expected: it collapses (it now reads `+`); right-click it again and it opens. A right-click on a guild bank header does the same. (Before this week a right-click there did nothing.)
18. (Fishing, optional) Stand at water and cast Fishing once. Expected:
    - within a second the title starts with `SwagBag — Fishing`;
    - only `New`, `Fish & Lures` and `Cooking` start with `-` (the ones that have items).
19. Stop fishing, and stand still for 2 minutes.
20. Look at the title. Expected: it starts with `SwagBag — ilvl` again (about 90 seconds after your last cast).
21. (Gathering, optional) Gather one herb, ore or skin. Expected: the title starts with `SwagBag — Gathering`. Open sections: `New`, the materials of your gathering professions (`Herbs`, `Ore` and/or `Leather & Cloth`), and `Teleports & Tools`.
22. Wait 2 minutes. Expected: the title starts with `SwagBag — ilvl` again.
23. (Optional) Open a treasure chest. Expected: the title does **not** say `Gathering`.
24. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: Claude sees:
    - a `Focus:` line and a `Spells before loot (last 5):` line. The spell numbers let Claude add your gathering spells to the list;
    - no new errors;
    - `Blocked actions: none`.

Pass: steps 2–17 (including 13a and 17a) behave as described, and steps 18–23 for whatever you could try.
If step 18 or 21 shows no mode: tell Claude. The report's `Spells before loot` line gives the missing spell number.

Reply to Claude with: FM1 done, and the numbers of any steps that didn't match

---

## Session S1: the settings window (about 12 minutes)

Purpose: checks the settings window pages (Bags, Focus modes, Consumables, Bank & guild) and the Pause button's tooltip.

You need:
- a consumable you have (a potion or similar) for steps 13, 14 and 21;
- your bags open for step 4.

Claude installs the week-4 build first.

1. Quit the game completely (a full restart, not /reload, because files were added) and start it again. Log in. Expected: chat shows `SwagBag: v0.4.0 loaded. Type /swagbag help for commands.`
2. Type `/swagbag`. Expected: a window titled `SwagBag settings` opens at the `Bags` page, and chat shows `SwagBag: Settings opened.`
3. Look at the row `Free slots`. Expected: `One with the count` is highlighted, and `Every free slot` is right next to it.
4. Press **B** to open your bags. In the settings, click `14` under `Slots per row`. Expected: the line at the bottom of the settings says `Bags: 14 slots per row.` Move the mouse off the bags: they regroup 14 slots wide.
5. Click `12`. Expected: `Bags: 12 slots per row.`, and the bags go back.
6. Click `Focus modes` on the left. Expected: `Switch by themselves`, `Open both sets`, `Peeks`, `Quiet` and `All characters` are highlighted.
7. Scroll down to `Edit the sections of` and click `M+`. In the row `Junk`, click `Open`. Expected: the bottom line says `Junk now opens in the M+ mode.`
8. Click `Reset to default` (row `Back to SwagBag's choice for this mode`). Expected: `The M+ mode opens its default sections again.`
9. Scroll up and click `This character` (row `These focus settings are for`). Expected: `This character now has its own focus settings; the others keep theirs.`
10. Click `All characters`. Expected: `This character uses the account-wide focus settings again.`
11. Click `Consumables` on the left. Expected: the line `Low-consumables warning` with `On` highlighted, a wrapped paragraph starting `It checks your bags when a key starts`, and rows `Flask: warn below 1`, `Potions: warn below 5` and `Food: warn below 5`.
12. Click `+` in the `Potions` row. Expected: the bottom line says `Potions: warns when you have fewer than 6.`, and the row reads `Potions: warn below 6`. Then click `-`. Expected: `Potions: warns when you have fewer than 5.`
13. Take any potion or other consumable you have (one that is not Flask, Potions or Food by name does not matter). In your bags, left-click it once so it sticks to your mouse cursor. Move the mouse to the settings window and left-click `Drop an item here` (or let go of the item over it). Expected: the bottom line says `Now watching`, the item's name, then `(warns below 1; use + to raise it).`; the item is no longer on your cursor (the cursor is an ordinary arrow again) and is back in its bag slot. Wait 2 seconds: the `Now watching` line is still shown, not replaced by `Pick up an item first (click it in your bags), then click here or drop it here.`
14. Click `Remove` in that item's row. Expected: the item's name, then `is no longer watched.`
15. Click `Check now`. Expected: the bottom line says `Checked: the result is in chat.`, and chat shows a `SwagBag: Low: ...` line (it also flashes on screen), or `SwagBag: All watched consumables are stocked.`
16. Click `Bank & guild` on the left. Expected: `Hidden`, `SwagBag's window`, `Selected tab` and `Show` are highlighted.
17. Press **Esc**. Expected: the settings window closes (Esc may close your bags too; that is fine).
18. Press **B** to open your bags, then hover over `Pause` without clicking. Expected: a tooltip `Focus modes` with `Left-click: pause or resume for this session` and `Right-click: choose the sections this mode opens`.
19. Right-click `Pause`. Expected: the settings open at `Focus modes`, and the bottom line says `Editing the sections the M+ mode opens (below).` (in town no mode is active, so the page opens at the last mode you edited, M+).
20. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Optional steps (open `Consumables` first):

21. Pick up the same consumable again, click `Drop an item here` twice with it (first adds it, then pick it up again and click once more). Expected the second time: `That item is already on the watch list. Your item stays on the cursor.` and the item is still on your cursor; put it back in your bag.
22. Click `-` in the `Flask` row. Expected: `That is already the threshold.`
23. Click `Reset to default` (row `Test or start over`). Expected: `The consumables watch list is back to the default: Flask 1, Potions 5, Food 5.`
24. Click `Remove` on `Food`, keep the settings open, and type `/swagbag consumables reset` in chat. Expected: the `Food: warn below 5` row comes back at once, and chat shows `SwagBag: The consumables watch list is back to the default: Flask 1, Potions 5, Food 5.`

Pass: steps 1–19 (20 for errors; 21–24 optional).

Reply to Claude with: S1 done, and the numbers of any steps that didn't match

---

## Session Q1: the quick setup screen (about 3 minutes)

Purpose: checks the first-login quick setup screen, its Esc and Apply behaviour, and the tour command.

You need: nothing special. Claude installs the week-4 build first. Do not press Apply or Skip before step 1.

1. Quit the game completely and start it again (new file). Log in and wait 3 seconds after the loading screen. Expected:
   - a window `Welcome to SwagBag` with `M+`, `Raid`, `Gold-making`, `Casual` and `Collector`;
   - `10`, `12` and `14` under `Slots per row`;
   - `Skip (use defaults)` and `Apply`.
2. Press **Esc**. Expected: chat shows `SwagBag: Quick setup closed without changes; it opens again at your next login, or type /swagbag setup.`
3. Type `/swagbag setup`. Expected: the window opens, and chat shows `SwagBag: Quick setup opened.`
4. Click `Apply` without picking anything. Expected: the window stays open and its bottom line says `Pick at least one of the buttons first, or press Skip.` (chat says the same).
5. Click `M+`. Expected: `M+` turns green.
6. Click `Apply`. Expected: chat shows `SwagBag: Set up for M+. Change anything later: type /swagbag.`, and the window closes.
7. Type `/swagbag tour`. Expected: chat shows `SwagBag: The guided tour arrives with the full setup wizard in November. Until then, /swagbag help lists every command.`
8. Type `/reload`. Wait 5 seconds. Expected: no quick setup window. (updated) Note: `/reload` shows the quick setup again until you press Apply or Skip; that is expected (Esc only means "later"). You pressed Apply in step 6, so it stays away.
9. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors.

Pass: steps 1–8. (Gold-making moves Trade Goods and BoE gear up in your bags. Try it with `/swagbag setup` only if you want that order.)

Reply to Claude with: Q1 done, and the numbers of any steps that didn't match

---

## Session FT1: the footer at the bottom of the bags (about 5 minutes)

Purpose: checks the footer bar (gold, currencies, crests, keystone, free slots), its tooltips, the `/swagbag footer` commands and the Footer settings page.

You need:
- your keystone;
- at least one currency ticked "Show on backpack" in Blizzard's Currency tab (optional);
- some crests (optional);
- a vendor nearby, for step 15 (optional);
- a training dummy, for step 16 (optional).

Claude installs the week-4 build first (the installed copy is week 3's).

1. Quit the game completely and start it again (new file). Log in. Press **B**. Expected: a bar along the bottom of the bags window, under `Free`, shows from left to right:
   - your gold, with coin icons;
   - your backpack currencies (if you ticked any);
   - your crests (if you own any);
   - your keystone as a short dungeon name and its level (for example `AKCE +12`);
   - a number and `free` (for example `10 free`).

   No item is hidden behind the bar: scroll down to the last row of `Free` if the window scrolls.
2. Look at the number before `free`. Expected: it is the same as the number on the free slot in `Free`.
3. Rest the mouse on your gold. Expected: a tooltip `Gold on this character` with the amount.
4. Rest the mouse on a crest or a currency. Expected: Blizzard's currency tooltip, with its maximum where the currency has one. Say whether the maximum shows (note it).
5. Rest the mouse on your keystone. Expected: the keystone's tooltip, the same as hovering it in the bags.
6. Rest the mouse on the `free` entry. Expected: a tooltip `Free bag slots` with a line `Bags:` and a number.
7. Type `/swagbag footer`. Expected: chat shows `SwagBag: Footer, left to right: Gold on, Backpack currencies on, Crests on, Keystone on, Free slots on`.
8. Type `/swagbag footer gold off`. Expected: chat shows `SwagBag: Footer: Gold is now off.`, and the gold is gone from the bar.
9. Type `/swagbag footer gold on`. Expected: chat shows `SwagBag: Footer: Gold is now on.`, and the gold is back on the left.
10. Type `/swagbag footer free up`. Expected: chat shows `SwagBag: Footer: Free slots is now number 4.`, and `free` is now left of the keystone.
11. Type `/swagbag`, then click `Footer` on the left. Expected: rows `1. Gold`, `2. Backpack currencies`, `3. Crests`, `4. Free slots` and `5. Keystone`, each with `Show` highlighted, then `Hide`, `Move up` and `Move down`.
12. In the row `4. Free slots`, click `Move down`. Expected: the bottom line says `Footer: Free slots is now number 5.`, and in the bags `free` is the last entry again.
13. Click `Bags` on the left, then `10` under `Slots per row`. Move the mouse off the bags. Expected:
    - the bags window gets narrower;
    - if the entries no longer fit on one line, the ones that don't fit continue on a second line under the first;
    - nothing overlaps, and no item is hidden behind the bar.
14. (updated) Click `12` under `Slots per row`, then click the **X** in the top right corner of the settings window. Expected: the settings window closes, the bags stay open, and they go back to their width, with the bar on one line if it fits.
15. (Optional) Buy or sell anything at a vendor. Expected: the gold in the bar changes within a moment.
16. In combat (at a training dummy, optional), press **B** twice and rest the mouse on the bar's entries. Expected: no red error and no "blocked" message.
17. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 1–14, and 15–16 if you tried them. If a crest you own does not show in step 1, tell Claude its exact name.

Reply to Claude with: FT1 done, and the numbers of any steps that didn't match

---

## Session W1: guild bank header drag and the logout snapshot (about 3 minutes)

Purpose: checks that dropping an item on a guild bank header does nothing harmful, and that SwagBag saves its snapshot on /reload.

You need:
- access to a guild vault (guild bank) and an item in a guild tab;
- a banker.

`/reload` is enough here if you restarted the game for Q1; otherwise Claude installs the week-4 build first and you restart the game.

1. `/reload` is enough if you restarted for Q1 (otherwise quit and restart the game). Open the guild vault. Expected: SwagBag's guild bank window opens.
2. Press and hold the left mouse button on an item in a guild tab, move the mouse onto a section header of the guild bank window (for example `- Herbs (`), and let go. Expected: the item stays on your mouse cursor (the guild bank takes no drops on headers).
3. Click that same header at once. Expected: it collapses (`+`). If nothing happens, tell Claude.
4. Click the empty slot the item came from (the guild tab's grid). Expected: the item goes back. Move the mouse off it.
5. Leave the vault. Visit a banker and open the bank.
6. Type `/reload` while the bank is open. Then type `/swagbag snapshot`. Expected: chat shows `SwagBag: Bags: just now`, `SwagBag: Bank: just now` and `SwagBag: Warband bank: just now` (any of them may say `1 min ago`), then a `SwagBag: Saved:` line.
7. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 2–6.

Reply to Claude with: W1 done, and the numbers of any steps that didn't match

---

## Session DR1: delve and raid (about 5 minutes)

Purpose: checks that the Delves and Raid modes switch on inside a delve and a raid and off again when you leave.

You need: a delve and a raid (any difficulty) to enter.

1. `/reload` is enough if you did FM1 since the last restart (otherwise quit and restart the game). Enter a delve. Press **B**. Expected: the title starts with `SwagBag — Delves`; only `New`, `Consumables` and `Gear` start with `-`.
2. Leave the delve. Expected: the title starts with `SwagBag — ilvl`, and your own sections are back.
3. Enter a raid (any difficulty). Press **B**. Expected: the title starts with `SwagBag — Raid`; only `New`, `Consumables` and `Gear` start with `-`.
4. Leave the raid. Expected: the title starts with `SwagBag — ilvl`.
5. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 1–4. If step 1 shows no `Delves`, tell Claude.

Reply to Claude with: DR1 done, and the numbers of any steps that didn't match

---

## Session K1: a real Mythic+ key (updated)

Purpose: checks the M+ mode in a real key and the low-consumables warning.

You need: your keystone, a dungeon teleport you know ("Path of …"), and your usual consumables. To test the warning, carry fewer than 5 food or fewer than 5 potions (or no flask).

1. Quit the game completely and start it again (new file). Log in. Type `/swagbag consumables`. Expected: chat shows `SwagBag: Consumables warning on. Watching: Flask 1, Potions 5, Food 5`.
2. Type `/swagbag consumables check`. Expected: either `SwagBag: All watched consumables are stocked.`, or a line in the middle of the screen and in chat; the chat line starts `SwagBag: Low:` (for example `SwagBag: Low: Food (2/5)`). Note: a `Low:` line right after logging in can be a false alarm while your items are still loading; if you see one, note it and tell Claude.
3. Cast your dungeon teleport. Expected: if something is low, one `Low:` line in the middle of the screen and in chat; nothing if everything is stocked. The middle-of-screen line may be hidden by the loading screen; the chat line is the one to check. If step 2 said `Low:` but nothing shows here, tell Claude the teleport's name (note it).
4. Walk into the dungeon with your keystone, before starting it. Press **B**. Expected:
   - the title starts with `SwagBag — M+`;
   - only `New`, `Keystone & Crests`, `Consumables` and `Gear` start with `-`;
   - if something is low, one `Low:` line showed when you zoned in.

   If the title has no `M+`, tell Claude.
5. Start the key. Expected: the title still starts with `SwagBag — M+`. If something is still low, the `Low:` line shows once more (starting the key checks again).
6. In combat during the key, press **B** to close the bags, then **B** to open them. Expected: they work, with no red error and no "blocked" message.
7. In combat, click a `+` header (for example `+ Junk`). Expected: it opens and ends in `(peek - right-click keeps it open)`. Move the mouse off it.
8. Finish the key and leave the dungeon. Expected: the title starts with `SwagBag — ilvl`, and your own sections are back.
9. Start another key (or re-enter a running one), and with something still low type `/reload` inside the dungeon. Expected: no new `Low:` line after the reload (a reload is not a zone-in). Note it if one appears.
10. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Expected: no new errors; `Blocked actions: none`.

Pass: steps 1–9.

Reply to Claude with: K1 done, and the numbers of any steps that didn't match

---

## Daily focus check (from day 3 of the week, about 2 minutes)

Purpose: at the end of each day's play, a short questionnaire on whether modes switched correctly in real play.

You need: a day of normal play (keys, delves, raids, fishing or gathering as you like).

1. Which modes did you see today (M+, Raid, Delves, Gathering, Fishing, AH/Vendor/Bank)?
2. Did a mode ever switch on when it should not have (for example Gathering after opening a chest, or Fishing when you did not fish)? (yes/no; what were you doing)
3. Did a mode ever fail to switch on (a key with no `M+` in the title, a delve with no `Delves`)? (yes/no; where)
4. Did any item move while your mouse was on it? (yes/no; what were you doing)
5. Did the `Low:` warning show when you were low, and stay quiet when you were not? (yes/no)
6. After a mode ended, were your own collapsed sections as you left them? (yes/no)
7. Type `/swagbag report`, press Ctrl+C and paste it to Claude. Claude checks for no new errors, `Blocked actions: none`, and the `Focus:` and `Spells before loot` lines.

Any "yes" to questions 2 or 4, and any "no" to questions 3, 5 or 6, is a bug report.

---

## Week 4 exit check (day 7)

Purpose: the final sign-off. You tick these in game on day 7 and paste the final `/swagbag report` to Claude.

You need: the sessions above done, plus at least two keys played.

1. [ ] Sessions FM1, K1, S1, Q1, W1, O2 and FT1 passed, or every failure was fixed and its step re-run. DR1 passed if you play delves or raids.
2. [ ] V5: at least two keys had `SwagBag — M+` in the title from entering the dungeon to leaving it.
3. [ ] V11: the `Low:` warning showed once when low (on teleport, entry or key start) and stayed quiet when stocked.
4. [ ] V6 and V8: fishing and gathering switched on within a second, and off within about 2 minutes. A chest never switched Gathering on (or you could not test it: say so).
5. [ ] V7: a delve showed `Delves` (or you did no delve: say so).
6. [ ] The daily focus check had no bug answers, or every one was fixed.
7. [ ] Claude ran `scripts/check.sh` on the branch: `ALL CHECKS PASSED`, with 884 or more passed and 0 failed. The branch is merged (or kept), as you choose. (This one is Claude's to do, not yours.)

If a line fails, paste the report, and Claude fixes it before week 5 starts.
