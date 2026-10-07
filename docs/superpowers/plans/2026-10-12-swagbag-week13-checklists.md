# SwagBag week 13: in-game test checklists

Five sessions, in this order: V13-1 (tabs in the header, the first check), V13-2 (one bank), V13-3 (menu and header), V13-4 (bags and tooltips), V13-5 (narrow and combat).

## Before you start

- Week 13 needs the week-13 build. Claude installs the build first: say "install week 13".
- After that, fully quit the game and start it again (new files; a `/reload` is not enough). The login line must say v0.13.0.
- If anything shows a red error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude.
- After each session, reply "<session> done" plus the numbers of any steps that didn't match. For example: `V13-1 done, steps 4 and 7 didn't match`.

Chat lines in these checklists start with `SwagBag: `.

You need for all sessions: a banker to stand next to, a character with the Warband bank unlocked, one warbound item and one soulbound item in your bags. Session V13-5 also needs a training dummy.

---

## Session V13-1: the tabs in the header (the first check)

Purpose: Blizzard's real Bank and Warband Bank tabs now sit inside SwagBag's bank window, and right-click deposits must still work with no taint. If this session fails, nothing else this week matters.

If anything goes wrong, type `/swagbag report`, press Ctrl+C, and paste the result to Claude.

1. Quit the game completely and start it again. Expected: the login screen.
2. Log in. Expected: chat shows `SwagBag: v0.13.0 loaded. Type /swagbag help for commands.`
3. Open the bank at the banker. Expected: SwagBag's bank window opens, and Blizzard's own bank is not visible.
4. Look at the line under the search box. Expected: it reads `Right-click deposits to:` and, right after it, two tabs: `Bank` and `Warband Bank`, inside the window's header. They do not overlap the search box or the first group.
5. Click `Warband Bank`. Expected: the tab lights up, the Warband bank opens, and the Character bank folds to one line.
6. Right-click a warbound item in your bags. Expected: it lands in the Warband bank, in its `New` section.
7. Click `Bank`. Expected: the tab lights up, the Character bank opens, and the Warband bank folds.
8. Right-click an item in your bags that can go in your own bank. Expected: it lands in the Character bank.
9. Type `/reload`, then open the bank again. Expected: the tabs are in the header again.
10. Right-click an item in your bags. Expected: it still lands in the bank whose tab is lit. This means there is no taint.
11. Close the bank and use your Hearthstone. Expected: it works, with no red error and no "blocked action" message.

If the tabs overflow the header or don't click (steps 4, 5, 7): tell Claude. The fallback is to keep the bar text and move the tabs back under the window (a one-line `placeTabs` change, ruled in the ledger).

---

## Session V13-2: one bank at a time

Purpose: the window shows only the bank you deposit into, and the other one folds to one line.

1. Open the bank and click `Warband Bank`. Expected: the Warband bank is open and the Character bank is one line.
2. Look at the folded line. Expected: it ends with `click to show`.
3. Click the folded line. Expected: the Character bank opens too, once, with no other message.
4. Click `Bank`, then `Warband Bank` again. Expected: each switch folds the other bank again; your earlier click is forgotten.
5. Type a word that matches items in the folded bank into SwagBag's search box. Expected: the folded line ends with `N found` (for example `3 found`).
6. Clear the search box. Expected: the `found` words go away.
7. Open Settings (`/swagbag settings`) and go to `Bank & guild`. Find `SwagBag's bank window shows` and pick `Both banks`. Expected: with the bank open, both banks are open.
8. Fold the Character bank by clicking its header, close the bank, and open it again. Expected: it is still folded (your own fold is remembered in "both" mode).
9. Pick `The bank you deposit into` again. Expected: one bank is open and the other is folded again.
10. Type `/swagbag bank both`. Expected: chat shows `SwagBag: Bank: SwagBag's bank window shows both banks.`
11. Type `/swagbag bank one`. Expected: chat shows `SwagBag: Bank: SwagBag's bank window shows the bank you deposit into; the other folds to one line.`

---

## Session V13-3: the menu and the header

Purpose: the slim header (Sort, `...`, close) and the `...` menu.

1. Open the bank. Expected: the title row reads `SwagBag bank`, then `Sort`, then `...`, then the close X.
2. Hover `Sort`. Expected: a tooltip, for example `Sorts your Warband bank (the bank you deposit into). The ... menu sorts either bank.`
3. Hover `...`. Expected: a tooltip: `More: the view, sorting either bank, regroup, Blizzard's bank, Deposit warbound and settings.`
4. Click `Warband Bank`, then hover `Deposit warbound` on the Warband bank's header. Expected: a tooltip that begins `Moves every warbound item in your bags into the Warband bank, whichever tab is selected.`
5. Hover the `With reagents` box. Expected: a tooltip: `Blizzard's own setting: Deposit warbound takes reagents too. Right-click deposits don't change.`
6. Click `...`. Expected: a menu opens with, in order: the view choices (`View: Categories (now)`, `View: List`, `View: Grid`; the current one has `(now)` inside), `Sort Character bank`, `Sort Warband bank`, `Regroup now`, `Show Blizzard's bank (buy tabs, gold)`, `Deposit all warbound items`, `Bank settings...`.
7. Hover each menu entry. Expected: each one shows a tooltip.
8. Click `View: List`. Expected: the bank redraws as a list and the menu closes.
9. Click `...` and click `View: Categories`. Expected: the category view is back.
10. Click `...` and click `Sort Warband bank`. Expected: the Warband bank sorts, and the answer shows once.
11. Click `...` and click `Regroup now`. Expected: items regroup into their sections, with one answer.
12. Click `...` and click `Deposit all warbound items`. Expected: the same answer as the `Deposit warbound` button gives.
13. Click `...` and click `Bank settings...`. Expected: Settings opens on `Bank & guild`.
14. Click `...` and click `Show Blizzard's bank (buy tabs, gold)`. Expected: Blizzard's own bank appears, SwagBag's window moves beside it, and the answer reads `Blizzard's bank is shown for this visit`.
15. Look at the bar. Expected: it reads `Right-click deposits to: Warband bank - switch with the tabs on Blizzard's bank` (or `Character bank`).
16. Click `...` and click `Hide Blizzard's bank`. Expected: Blizzard's bank goes away, the window goes back to where it was, the tabs are in the header again, and the answer reads `Blizzard's bank is hidden again`.
17. Click `Show bank` in the bags title if SwagBag's window is closed. Expected: SwagBag's bank window is back.

Known behaviour (not a bug): with the `...` menu open, pressing Esc once closes the menu and SwagBag's bank window together, Blizzard's bank comes back for the visit, and the bags show `Show bank`.

---

## Session V13-4: bags and tooltips

Purpose: SwagBag's bags window and item tooltip say where a right-click will go.

1. Open the bank, click `Warband Bank`, and look at the bags window title. Expected: `SwagBag — right-click to Warband bank`.
2. Click `Bank`. Expected: the title changes to `SwagBag — right-click to Character bank`.
3. Click `Warband Bank` again, and hover a warbound item in your bags. Expected: the tooltip has the line `Right-click: into your Warband bank`. If the line does not show, tell Claude (the tooltip hook is installed at file load and has not been seen in game before).
4. Hover a soulbound item in your bags, with the Warband tab selected. Expected: the tooltip has the line `Right-click: your Warband bank won't take this`.
5. Click `Bank` and hover the same soulbound item. Expected: the line reads `Right-click: into your Character bank`.
6. Close the bank with the X. Expected: the bags window title goes back to its normal title, and shows a `Show bank` button.
7. Hover an item in your bags with the bank closed. Expected: no `Right-click:` line.

---

## Session V13-5: narrow window and combat

Purpose: the window stays usable when small, and in combat.

1. Type `/swagbag bank`. Expected: chat shows `SwagBag: Use /swagbag bank hidden or shown (Blizzard's bank, now: hidden), one or both (banks shown, now: one).` The words `tiny` and `beside` do not appear.
2. Type `/swagbag bank shown`. Expected: chat shows `SwagBag: Bank: Blizzard's bank is shown, with SwagBag's bank window beside it.`
3. Type `/swagbag bank hidden`. Expected: chat shows `SwagBag: Bank: Blizzard's bank is hidden; its Bank and Warband Bank tabs are at the top of SwagBag's bank window.`
4. Type `/swagbag bank tiny`. Expected: the same line as step 3 (old macros still work).
5. Narrow bank window: covered by automated tests (no in-game step).
6. Stand next to the banker and the training dummy. Attack the dummy to enter combat, then open the bank. Expected: Blizzard's own bank stays visible, SwagBag's window opens beside it, and the bar reads `Right-click deposits to: ...` followed by `switch with the tabs on Blizzard's bank` (or `Right-click deposits: pick Bank or Warband Bank on Blizzard's bank`). It never shows `Right-click deposits to:` with no tabs next to it.
7. Click `...` and click `Show Blizzard's bank (buy tabs, gold)` (or `Hide Blizzard's bank`). Expected: the answer reads `Leave combat first`, and nothing moves.
8. Click `Sort` in the header. Expected: a refusal, no sorting, and nothing runs later when combat ends.
9. Leave combat. Close the bank and open it again. Expected: the tabs are in the header and everything works as in V13-1.
