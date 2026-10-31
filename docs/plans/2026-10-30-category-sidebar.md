# Category sidebar (0.17.0)

User request (2026-10-30): "I would like a sidebar that goes over all of the categories (and amount in each).
Once clicked it brings up that category and that's it." Agreed with the user the same day.

## What the player sees

- A slim column (150 px) beside the bags window and the bank window, as tall as the window.
- Bags: one line per section as drawn (New first, Free last, a focus mode's "front" order when one applies):
  `Consumables (12)`, the same count as the header; a folded section reads `+ Consumables (12)`.
- Bank: a `Character bank (n)` heading and a `Warband bank (n)` heading, each with its categories under it,
  also those of the bank that "one bank at a time" folds.
- Shown in the Categories and List views only; in Grid and per-bag (Bags) it hides.
- Left of the window; on the right when the left has no room at opening (the window's left edge is nearer the
  screen edge than the sidebar is wide), and always on the right in the bank's "shown" mode (Blizzard's bank is
  on the left). The side is chosen only when the window opens.
- A small handle at the window side of its top edge shrinks it to a thin strip; a click on the strip brings
  it back. Saved per character and per window (SwagBagCharDB ui.sidebarShrunk[bags|bank]).
- Longer than the window: the mouse wheel scrolls the sidebar's own list.
- One setting for both windows, on by default: `bags.sidebar` (Settings > Bags, `/swagbag sidebar on|off`).

## What a click does, and nothing else

1. Something on the cursor: nothing (the bags never move while an item is held).
2. Bank: the entry's bank is folded: open it exactly as a click on its header does (GroupView's group click).
3. The section is drawn folded: unfold it exactly as a left-click on its header does (bags: W.ClickSection, so a
   focus mode's fold is a peek; bank: v.ToggleSection).
4. If that unfold landed (it was not held), scroll the window so the header is at the top, clamped
   (GridLayout.ClampOffset). A held unfold scrolls nothing; the title flash already says what happened.

No filter, no dimming, no other state. The pointer is on the sidebar, outside the item area, so the window's
own hover guards allow the move. The bags window's grow-upward rule (W4-25) also counts the sidebar as "under
the pointer", because the sidebar hangs on the window and would move with its top edge.

## Nothing moves under the mouse

- Counts and the `+` change in place (same rows, same places).
- When the list of entries itself changes (a section appears or goes) while the mouse is over the sidebar, the
  redraw waits and retries every 300 ms (SB.Debounce), like every other move (spec 4.2 rule 5).
- Plain frames and buttons only, so it works in combat.

## Code

- `UI/CategorySidebar.lua` (new, TOC after SectionHeaders): pure helpers `Side`, `Label`, `ScrollOffset`, and
  `S.New(cfg)` -> sidebar `{ Update(entries), Place(), IsMouseOver(), frame }`; `/swagbag sidebar`.
- `UI/BagsWindow.lua`: entries from `W.pos.headers` in `renderExtras`; empty in Grid/Bags; click handler;
  W4-25 guard counts the sidebar; Place on open.
- `UI/GroupView.lua`: `pos.folded` (a folded group's section headers with counts), `v.ClickGroup(gid)` (the group
  header click), `v.GroupClosed(gid)`.
- `UI/BankWindow.lua`: entries from `v.pos` in `onHeaders`; click handler; side "beside" -> right.
- `Core/Config.lua` `bags.sidebar = true`; `UI/SettingsPages.lua` row; `Locale/enUS.lua` texts; `CHANGELOG.md`.

## In-game checks (the fakes cannot show these)

- CS1 Open the bags: the sidebar is beside the window, as tall as it, and each line's count matches its header.
  Drag the bags window to the left edge, close and reopen: the sidebar is on the right.
- CS2 Fold a category with its header, then click it in the sidebar: it unfolds and comes to the top. With bags
  taller than the screen allows (scrolling), a click on a category near the bottom scrolls it to the top.
- CS3 Keep the mouse on the sidebar while looting: no line jumps under the mouse; counts change in place.
- CS4 The arrow at the sidebar's top shrinks it to a strip; a click on the strip brings it back; /reload keeps it.
  Try each theme (Settings > Look): the strip and the arrow read well.
- CS5 Bank: both banks listed; a click on a Warband category while the character bank tab is selected opens
  the Warband bank and scrolls to it. With Blizzard's bank shown ("..." > Show Blizzard's bank) it is on the right.
- CS6 In combat (a training dummy): clicks still work. `/swagbag sidebar off` hides it in both windows, `on` brings
  it back.

## Tests (first)

`spec/sidebar_spec.lua`: pure helpers; bags window entries/order/counts, `+` for folded, hidden in grid/bags views,
click unfolds then scrolls, click with an item on the cursor does nothing, held redraw under the mouse, shrink
saved per character, setting off hides it, slash command; bank entries for both groups incl. a folded one, click on
a folded bank's category opens the bank and scrolls, beside mode puts it on the right.
