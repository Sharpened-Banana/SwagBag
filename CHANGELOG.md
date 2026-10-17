# SwagBag changelog

Newest first. Each "## <version>" section is the changelog CurseForge shows for that upload (scripts/release.sh reads it).

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
