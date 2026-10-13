# SwagBag 0.14.0 stack grouping: in-game checklist

Claude installs the build first: say "install 0.14.0". After that, fully quit the game and start it again (new files; a `/reload` is not enough). The login line must say v0.14.0.

If anything shows a red error, type `/swagbag report`, press Ctrl+C, and paste the output to Claude. After each check, reply "<check> done" plus the numbers of any steps that didn't match, for example `S-3 done, step 2 didn't match`.

Chat lines start with `SwagBag: `. You need: a vendor, a banker with the Warband bank unlocked, a training dummy, and a trade good you can split into two partial stacks (for example 45 and 7).

## S-1 Bags

1. Put two partial stacks of one trade good in your bags (Shift-click one, take part of it, drop the part in an empty slot). Close and reopen the bags. Expected: one icon with the total, for example `52`.
2. Rest the mouse on it. Expected: the tooltip shows `2 stacks: 45 + 7` and `Clicks use the stack of 45`.

## S-2 Split

1. Shift-click the icon. Expected: Blizzard's split box lets you take at most 45, not 52. Press Esc.

## S-3 Vendor

1. At a vendor, right-click the icon. Expected: the 45 sells and the slot looks empty while your mouse stays there.
2. Move the mouse away from the items. Expected: the 7 appears in the same place.

## S-4 Things that must stay apart

1. Look at two copies of one ring with different item levels, a keystone, and two caged pets. Expected: each one stays its own icon.

## S-5 New

1. Loot one more of that trade good. Expected: it shows in `New` on its own.
2. Hover it, close and reopen the bags. Expected: it joins the group.

## S-6 Bank

1. At the bank, look at two stacks of one item in the Warband bank. Expected: one icon.
2. Put one stack of an item in the Character bank and one in the Warband bank. Expected: two icons, one in each bank.

## S-7 List view

1. Switch the bags to the list view. Expected: the Count column shows the total.
2. Click the `Count` header until it reads `Sorted by Count, highest first`. Expected: the group sits where its total belongs.

## S-8 Sell all

1. At a vendor, Shift+right-click a section header and choose `Sell all (N)`, then accept the question. Expected: both stacks are sold, and the chat line counts both.

## S-9 Off switch

1. Type `/swagbag stacks all`. Expected: `SwagBag: Every stack is shown again.`, and the window shows both stacks once the mouse leaves the items.
2. Open Settings > Bags, find `Same item in several stacks (bags and banks)` and click `One icon with the total`. Expected: the one icon is back.
3. Type `/swagbag stacks`. Expected: `SwagBag: Use /swagbag stacks one or /swagbag stacks all (now: one).`

## S-10 Combat

1. At a training dummy, in combat, drink a potion from a grouped icon until its stack runs out. Expected: the next stack appears in its place after you move the mouse away, and there is no "Interface action failed" message.
