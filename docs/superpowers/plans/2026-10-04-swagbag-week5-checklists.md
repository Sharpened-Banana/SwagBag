# SwagBag week 5: in-game test checklists

Five sessions, in this order: L1 (list view), TH1 (themes), A1 (alt counts in tooltips), OF1 (alt viewer), then the week-5 exit check.

## Before you start

- Week 5 needs the week-5 build. Your game currently runs week 4 (0.4.0).
- Say "install week 5" and Claude installs the week-5 build. After that, fully quit the game and start it again. The login line must say v0.5.0.
- If anything shows a red error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After each session, reply "<session> done" plus the numbers of any steps that didn't match. For example: `L1 done, steps 14 and 29 didn't match`.
- If you haven't run the week-4 checklists yet, run those first.

Chat lines in these checklists start with `SwagBag: `.

---

## Session L1: list view

Purpose: check the new list view, its sortable column bar, and that items still work in it (use, sell, move, loot, combat).

You need:
- a stack of something (more than 1);
- a healing potion or food you can use in combat, and a training dummy;
- at least 9 empty bag slots and some mobs to loot (step 18);
- a vendor (step 34; also steps 22-25 if you have a gray item);
- a banker (optional, steps 28-31).

If anything goes wrong, type `/swagbag report`, press Ctrl+C, and paste the result to Claude.

1. Quit the game completely and start it again (new files). Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.5.0 loaded. Type /swagbag help for commands.`
3. Press **B**. Expected: the bags open in the category view, as before. The buttons at the top read, from left to right: `Sort`, `Pause`, `Reflow`, `List`.
4. Click `List`. Expected:
   - the title shows `SwagBag - list view` for a moment, and the button now says `Grid`;
   - a bar under the search box reads `Name`, `Count`, `ilvl`, `Value v`, each word over its column of the rows below;
   - each item is one row: a small icon on the left, then its name in its quality colour, then its count (blank for a single item), its item level (gear only) and its value;
   - the sections are the same as in the category view (`Consumables`, `Gear`, `Junk`, ...), each with its header.
5. Look at a section with several items (no click). Expected: the item worth the most is on top (`Value v` means highest first).
6. Click `Value v` in the bar. Expected:
   - the title shows `Sorted by Value, lowest first`. If the title is cut short with `...`, the whole line is also in chat: `SwagBag: Sorted by Value, lowest first`;
   - the bar reads `Value ^`;
   - in every section the cheapest item is now on top.
7. Click `Name` in the bar. Expected: the title shows `Sorted by Name, A to Z`, the bar reads `Name ^` and `Value` (no marker), and each section is in A-to-Z order.
8. Rest the mouse on an item's **name** (not its icon). Expected: the item's tooltip, with a white line at the bottom: `Click the icon on the left to use, sell or move this item.`
9. Move the mouse off the row. Expected: the tooltip closes and nothing moves.
10. Go to a training dummy and attack it. Expected: you are in combat. Stay in combat until step 16.
11. Click `Grid`. Expected: the title briefly shows `SwagBag - grid view`, the items are full-size squares, the column bar is gone, and the button now says `Categories`.
12. Click `Categories`. Expected: the title briefly shows `SwagBag - category view`, and the button now says `List`.
13. Click `List`. Expected:
    - the title briefly shows `SwagBag - list view`;
    - the column bar is back, reading `Name ^`;
    - each small icon sits inside its own row, and no icon overlaps the row below it.
14. Right-click the small **icon** of your healing potion's (or food's) row. Expected:
    - you use it (the count on the row drops by one);
    - no red `Interface action failed because of an AddOn` message, and nothing about "blocked";
    - no chat line `SwagBag: The list view could not size the item buttons, so the bags show the category view. Close and reopen the bag to try again.`

    If any of these showed, stop here and tell Claude.
15. Move the mouse off the row. Expected: nothing moves.
16. Walk away from the dummy until combat ends. Expected: you are out of combat.
17. Move the mouse off the bag window, and keep it off during step 18. Expected: nothing changes.
18. Loot 5 or more items (from mobs or a dungeon). Expected:
    - a `New` section appears at the top, and each looted item gets its own row there;
    - New shows at most 8 rows. If you loot more, the extra items are at the end of the `Free` section, and New's header ends with `+1 more below` (or a higher number).
19. Shift-click the icon of a stack. Expected: Blizzard's small split box opens.
20. Press **Esc**. Expected: the split box closes.
21. Move the mouse off the icon. Expected: nothing moves.
22. (Gray item, optional) Open a vendor. Expected: the vendor window opens.
23. (Optional) Right-click the icon of a gray item. Expected:
    - it is sold;
    - its row now reads `(moved or used - regroups when you close the bag)` with a faded icon;
    - no other row moves.
24. (Optional) Move the mouse off it. Expected: nothing moves.
25. (Optional) Close the vendor. Expected: the vendor window closes.
26. Drag an item's icon onto the icon of the row that reads `<number> free - drop items here`, and let go. Expected: the item is no longer on your cursor.
27. Move the mouse off the bags. Expected: within half a second the item shows under the `New` header, and the number on the free row is one lower.
28. (Bank, optional) Open your bank. Expected: the bank opens.
29. (Optional) Right-click an item's icon in the bags' list. Expected: it goes into the bank, into the tab Blizzard's bank tabs have selected, exactly as in the category view.
30. (Optional) Move the mouse off it. Expected: nothing moves.
31. (Optional) Close the bank. Expected: the bank closes.
32. Type `/swagbag search potion`. Expected:
    - chat shows a line starting `SwagBag: Search "potion":`;
    - every row that is not a potion is faded, icon and text together.
33. Type `/swagbag search` (nothing after it). Expected: `SwagBag: Search cleared.`, and nothing is faded.
34. Open a vendor. Expected:
    - the title starts with `SwagBag — AH/Vendor/Bank`;
    - only `New`, `BoE gear`, `Trade Goods` and `Junk` start with `-` (those you have items in), the same as in the category view.
35. Close the vendor. Expected: your own sections are back.
36. Type `/swagbag list`. Expected: `SwagBag: List view: sorted by Name, A to Z.`
37. Type `/swagbag list value`. Expected: exactly one chat line, `SwagBag: Sorted by Value, highest first`, and the list goes back to most valuable first.
38. Type `/swagbag`. Expected: the `SwagBag settings` window opens, and chat shows `SwagBag: Settings opened.`
39. Click `Bags` on the left. Expected:
    - the `Bag view` row shows `Categories`, `List` (highlighted) and `Grid`;
    - near the bottom, `The list view sorts by` shows `Value` highlighted, then `Name`, `Count`, `ilvl`;
    - `The list view's order` shows `Highest first` highlighted, then `Lowest first`.
40. Click `Count`. Expected: the bottom line says `Sorted by Count, highest first`, `Count` is highlighted, and no chat line appears.
41. Click the X at the top right of the settings window. Expected:
    - the settings window closes and the bags stay open;
    - the bar reads `Count v`, and the largest stacks are on top.
42. Click a section header with several items (for example `Consumables`). Expected: its rows hide, its header starts with `+`, and the window gets shorter.
43. Drag the bags window by its title straight down as far as it goes, and let go. Expected: the window sits at the bottom of the screen, its bottom edge on the screen's edge, nothing cut off.
44. Click the same header again, and keep the mouse on the header. Expected:
    - the section opens (its header starts with `-`);
    - the window stays in the same place and at the same height, because it has no room to grow downward and the mouse is on it;
    - the list now scrolls.
45. Keeping the mouse on the window, drag the window by its title a little to the left, and let go. Expected: the window moves left, keeps the same height, and stays at the bottom of the screen.
46. Move the mouse off the window. Expected:
    - within half a second the window grows upward, so the whole list fits without scrolling;
    - its bottom edge stays on the screen.

    If your bags are very full, it grows to about three quarters of the screen height and still scrolls.
47. Click `Grid`. Expected: the title briefly shows `SwagBag - grid view`, full-size icons in bag order, and no column bar.
48. Type `/swagbag`. Expected: the `SwagBag settings` window opens, and chat shows `SwagBag: Settings opened.`
49. Click `Bags` on the left. Expected: the Bags page, with the `Slots per row` row.
50. In the `Slots per row` row, click `10`. Expected: the bottom line says `Bags: 10 slots per row.`, and the grid behind it is narrower (10 icons per row).
51. Click the X at the top right of the settings window. Expected: the settings window closes, and the bags stay open in the narrow grid.
52. Type `/swagbag view list`. Expected:
    - **exactly one** chat line: `SwagBag: SwagBag - list view`;
    - the title shows `SwagBag - list view` for a moment, and it may be cut short with `...` (the narrow grid left little room);
    - the bags show the list.
53. Type `/swagbag`. Expected: the `SwagBag settings` window opens, and chat shows `SwagBag: Settings opened.`
54. Click `Bags` on the left. Expected: `Slots per row` shows `10` highlighted.
55. Click `12`. Expected: the bottom line says `Bags: 12 slots per row.`
56. Click the X at the top right of the settings window. Expected: the settings window closes.
57. Click `Grid`. Expected: the title briefly shows `SwagBag - grid view`, with 12 full-size icons per row and no column bar.
58. Click `Categories`. Expected: the category view as at the start, full-size icons.
59. Type `/swagbag report`. Expected: chat shows `SwagBag: Report opened. Press Ctrl+C to copy it, then paste it into Claude Code.`, and a window titled `SwagBag report - press Ctrl+C to copy, Esc to close` opens.
60. Press Ctrl+C, and paste the copied text to Claude. Expected: Claude sees no new errors and `Blocked actions: none`.

Pass: steps 1-21, 26, 27 and 32-60, plus 22-25 and 28-31 if you tried them. Any title message cut short with `...` should also be in chat, exactly once (note it).

Reply to Claude with: L1 done, and the numbers of any steps that didn't match.

---

## Session TH1: themes

Purpose: check the `Blizzard`, `Modern flat` and `Matches ElvUI` looks, switching between them (also in combat), and that the choice is saved.

You need:
- a training dummy (steps 12-13);
- ElvUI turned on, only if you want steps 16-18 to test the real ElvUI look (otherwise step 16 shows a message that ElvUI isn't loaded);
- your bank (optional, step 23).

1. Quit the game completely, then start it and log in.
2. Press **B**. Expected: a dark navy-black background with a grey edge, the title in Blizzard's gold font, and headers with a faint light tint. Leave the bags open; this is the "Blizzard look" to compare against later.
3. Type `/swagbag theme`. Expected: a line starting `SwagBag: Look: Blizzard. Looks: blizzard (Blizzard), flat (Modern flat), elvui (Matches ElvUI`. If ElvUI is off it ends `elvui (Matches ElvUI, not available now).`
4. Type `/swagbag theme flat`. Expected: `SwagBag: Look: Modern flat. Only SwagBag's own windows change.`
5. Look at the bags. Expected, with no reload: a lighter flat background with a black edge, a white title, flatter section headers and flat slot squares behind the items. Icons, quality borders and counts look the same as before.
6. Look at the `Sort`, `Pause`, `Reflow` and `List` buttons. Expected: flat dark buttons with no red art showing. If any red art shows, say which button (note it).
7. Click `List`. Expected: the rows have a faint stripe behind them.
8. Click `Grid`.
9. Click `Categories`.
10. Type `/swagbag`. Expected: the settings window is flat too.
11. Click `Look` on the left. Expected: the row `The look of SwagBag's windows` shows `Blizzard`, `Modern flat` (highlighted) and `Matches ElvUI`.
12. Go to a training dummy.
13. Attack it to start combat.
14. Click `Blizzard` in the Look row. Expected: every SwagBag window changes back at once; the bottom line says `Look: Blizzard. Only SwagBag's own windows change.`; no error and no "blocked" message.
15. Leave combat.
16. Click `Matches ElvUI`. If ElvUI is on, expected: the bottom line says `Look: Matches ElvUI. Only SwagBag's own windows change.` and the windows use ElvUI's font and colours (note how it looks). If ElvUI is off, expected: `The ElvUI look needs ElvUI, which is not loaded. The look stays Blizzard.` and `Blizzard` stays highlighted.
17. REQUIRED whenever ElvUI is on (F13): click `Blizzard` straight away, from `Matches ElvUI`.
18. REQUIRED whenever ElvUI is on (F13): compare the title, headers and button text with step 2. Expected: the same font and size, nothing left from ElvUI.
19. Click `Modern flat`.
20. Press **Esc**.
21. Type `/reload`.
22. Press **B**. Expected: still the Modern flat look (saved).
23. (Optional) Open your bank. Expected: flat too, and the deposit group keeps its green tint. Close the bank.
24. Type `/swagbag theme blizzard`. Expected: `SwagBag: Look: Blizzard. Only SwagBag's own windows change.` and the bags look as in step 2.
25. Type `/swagbag report`.
26. Press Ctrl+A then Ctrl+C in the report window.
27. Paste it to Claude. Expected: a line `Look: blizzard (setting blizzard)`, no new errors, `Blocked actions: none`.

Pass: steps 1-22, 24-27 (17-18 whenever ElvUI is on), 23 if tried. Say whether you like the looks at steps 5 and 16.

Reply to Claude with: TH1 done, the numbers of steps that didn't match, and what you thought of the looks.

---

## Session A1: alt counts in tooltips

Purpose: check the "how many of this item do my other characters have" lines SwagBag adds under item tooltips, and the `/swagbag tooltip` setting.

You need:
- an item you have both in your bags and somewhere else (your bank, the warband bank, or another character you have logged in on since week 3);
- an item that is only in your bags;
- a piece of gear in your bags that you could wear in place of what you have on;
- a pet cage (a caged battle pet) in your bags;
- a training dummy (steps 22-25).

1. Claude installs the build first (`scripts/install.sh --remove`, then `scripts/install.sh --copy --yes`).
2. Quit the game completely.
3. Start the game again.
4. Log in.
5. Type `/swagbag report`.
6. Press Ctrl+C.
7. Paste it to Claude. Expected: a line `Alt data: Syndicator, <number> characters` (Syndicator is on) or `Alt data: Own, <number> characters`, and no line `Tooltip counts: hook unavailable`.
8. Type `/swagbag tooltip`. Expected: `SwagBag: Tooltip counts: shown unless Syndicator shows them. Use /swagbag tooltip auto, on or off.`
9. Open your bags.
10. Only if Syndicator is loaded: rest the mouse on the item from "You need". Expected: Syndicator's own count lines show and SwagBag adds none (no `SwagBag: <total> in all` line).
11. Move the mouse off the item.
12. Type `/swagbag tooltip on`. Expected: `SwagBag: Tooltip counts: always shown.`
13. Rest the mouse on the item from "You need" again. Expected, at the bottom of the tooltip: `SwagBag: <total> in all`, a line `<your name> (this character)` with where it is on the right (for example `Bags 3, Bank 2`), a line per other character that has it in its class colour, and `Warband bank` with a number if it is there. If Syndicator is on, note whether the numbers match Syndicator's lines.
14. Move the mouse off the item.
15. Rest the mouse on a pet cage in your bags. Expected: `SwagBag: <total> in all` and a line per character that has it. If the cage shows no SwagBag lines, note it.
16. Move the mouse off the pet cage.
17. Rest the mouse on an item that is only in your bags. Expected: no SwagBag lines.
18. Move the mouse off the item.
19. Hold Shift and rest the mouse on a piece of gear in your bags. Expected: the tooltip beside it (the one for the item you are wearing) has no `SwagBag: <total> in all` line.
20. Let go of Shift.
21. Move the mouse off the gear.
22. Start combat at a training dummy.
23. Rest the mouse on the item from step 13. Expected: the same lines as step 13, no error.
24. Move the mouse off the item.
25. Leave combat.
26. Type `/swagbag`.
27. Click `Alt data` on the left. Expected: the row `Other characters' counts on item tooltips` with the buttons `Shown (not twice with Syndicator)`, `Always shown` (highlighted) and `Hidden`, and a line under it starting `Alt data comes from`.
28. Click `Hidden`. Expected: the bottom line says `Tooltip counts: hidden.`
29. Press **Esc** to close the window.
30. Rest the mouse on the item from step 13. Expected: no SwagBag lines.
31. Move the mouse off the item.
32. Type `/swagbag`.
33. Click `Alt data`.
34. Click `Shown (not twice with Syndicator)`. Expected: the bottom line says `Tooltip counts: shown unless Syndicator shows them.`
35. Press **Esc**.
36. Type `/swagbag report`.
37. Press Ctrl+C.
38. Paste it to Claude. Expected: no new errors, `Blocked actions: none`.

Pass: steps 7, 8, 12, 13, 17, 19, 23, 27, 28, 30, 34, 38, and step 10 if Syndicator is on. Step 15 is informational (the pet-cage tooltip path).

Reply to Claude with: A1 done, the numbers of any steps that didn't match, and whether SwagBag's numbers matched Syndicator's.

---

## Session OF1: alt viewer

Purpose: check the alt viewer (`/swagbag alts`): browsing another character's saved items, the character picker, search, section headers, and the Settings button that opens it. About 12 minutes.

You need: another character that has logged in at least once since week 3, preferably one carrying an equip-once (bind on equip) item that is not yet bound (with Syndicator on, any character Syndicator knows). A training dummy for step 31.

1. Claude installs the build first (scripts/install.sh --remove, then scripts/install.sh --copy --yes).
2. Quit the game completely.
3. Start the game again (new files).
4. Log in.
5. Move one item in your bags.
6. Wait 10 seconds.
7. Type `/swagbag alts`. Expected: chat `SwagBag: Showing the saved items of <your name>.`; a window titled `SwagBag — <your name> (saved)`; group headers such as `- Bags (<number>) - just now`, `- Bank (<number>) - <age>`, `- Warband bank (<number>) - <age>` (and `- Guild bank: <guild> (<number>) - <age>` if you opened the guild vault since week 3). With Syndicator on, a header may end in `- from Syndicator`.
8. Look at the line `Saved data from SwagBag's own saved bags. Nothing here can be used or moved.` (or `from Syndicator`). Expected: it is fully readable and does not run under the button on its right.
9. Look at the button `Character: <your name>`. Expected: it sits at the right end of that same line, clear of the search box and its red error text.
10. Click the `Character: <your name>` button. Expected: a list of your characters, yours first and highlighted, each line like `<name> (<realm>) - just now` or `<name> (<realm>) - 2 days ago`, in class colours.
11. Click the `Character: <your name>` button again. Expected: the list closes.
12. Click the `Character: <your name>` button once more.
13. Click another character. Expected: the list closes, the title reads `SwagBag — <that name> (saved)`, the button reads `Character: <that name>`, and the groups show that character's items.
14. Rest the mouse on one named equip-once item of that character that is not bound (for example its unbound BoE gear). Expected: no `BoE` badge on the item, and the tooltip's sell price is the vendor price. Move the mouse off it.
15. Rest the mouse on another of its items. Expected: the item's tooltip (with the SwagBag count lines if tooltip counts are on). Move the mouse off it.
16. Right-click that item. Expected: the title shows `Saved items can't be used from here. Shift-click links one in chat.` and nothing else happens. Move the mouse off it.
17. Shift-click that item. Expected: its link appears in the chat box.
18. Clear the chat box.
19. Type `ore` in the alt viewer's own search box. Expected: everything that is not ore is faded.
20. Clear the search box.
21. Click a section header in the alt viewer (for example `- Consumables`). Expected: it collapses to `+ Consumables`.
22. Click the same header again. Expected: it opens again.
23. Type `/swagbag alts Nobody`. Expected: `SwagBag: No saved character named "Nobody". Saved: ` and your characters' names.
24. Type `/swagbag alts <name>` with the name of one of your other characters. Expected: `SwagBag: Showing the saved items of <name>.` and the title `SwagBag — <name> (saved)`.
25. Type `/swagbag alts <name>-<realm>` for a character on a realm whose name has a space (for example `/swagbag alts Abby-Argent Dawn`). Expected: `SwagBag: Showing the saved items of <name>.` If none of your characters is on a realm whose name has a space, write "no space realm" and go on.
26. Press **Esc**. Expected: the alt viewer closes.
27. Type `/swagbag`.
28. Click `Alt data` on the left. Expected: a row `Browse a character's saved bags, bank, warband bank and guild bank` with a button `Open the alt viewer`.
29. Click `Open the alt viewer`. Expected: the alt viewer opens on your character, and the settings window's bottom line says `Showing the saved items of <your name>.`
30. Press **Esc** twice.
31. At a training dummy, in combat, type `/swagbag alts`. Expected: it opens, with no error and no "blocked" message.
32. Press **Esc**.
33. Type `/swagbag report`.
34. Press Ctrl+C.
35. Paste it to Claude. Expected: no new errors, `Blocked actions: none`.

Pass: steps 1-35. If a character you expected is missing from the list in step 10, tell Claude its name (note it).

Reply to Claude with: OF1 done, and the numbers of any steps that didn't match.

---

## Week 5 exit check

Purpose: confirm week 5 is finished, after L1, TH1, A1 and OF1.

You need:
- the results of the four sessions above;
- a final `/swagbag report`, pasted to Claude.

Tick these in game after OF1, and paste the final `/swagbag report` to Claude.

1. [ ] Sessions L1, TH1, A1 and OF1 passed, or every failure was fixed and its step re-run.
2. [ ] The list view was used for at least one real play session (a key or a farming route) with no item used, sold or moved other than the one clicked.
3. [ ] A potion or food was used from a list row in combat (L1 step 14) without a "blocked" message. If one showed, Claude applied D4's fallback and the step was re-run.
4. [ ] The Blizzard look was unchanged from week 4 (TH1 steps 2 and 24).
5. [ ] Tooltip counts matched where the items are (A1 step 13), and the alt viewer showed another character's items (OF1 step 13).
6. [ ] Claude ran `scripts/check.sh` on the branch: `ALL CHECKS PASSED` with 0 failed. The branch is merged (week 4 first, then week 5) or kept, as the user chooses.

If a line fails, paste the report, and Claude fixes it before week 6 starts.
