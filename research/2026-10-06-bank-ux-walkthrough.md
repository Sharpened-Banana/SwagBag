# The bank, as a player sees it: UX walkthrough (v0.12.0)

Date: 2026-10-06. Read-only audit of `main` (v0.12.0). Nothing in the code was changed.
Question from the user: "the bank is very hard to understand. How can we make it easier to understand and navigate?"
Binding principle: as easy and simple as possible out of the box, with full power underneath.

The user picked four pain points. Everything below is organised around them:

1. **Where deposits go.** Does a right-click put the item in the character bank or the warband bank, and how do you switch?
2. **Too many buttons and things** in the window.
3. **Finding items.** It is hard to tell what is where: character or warband, which tab, which section inside each group.
4. **Tabs and modes.** Blizzard's tabs hang under the window, "tiny" vs "beside", and the "Blizzard bank" toggle.

Section 1 maps the screen. Section 2 lists what a player has to learn. Section 3 covers the four pain points: what confuses, the evidence, the single best fix, and other ideas. Section 4 lists the Blizzard limits that decide what is possible. Section 5 gives a suggested order of work.

---

## 1. Screen map: what the player sees at a banker (default settings)

Defaults (`SwagBag/Core/Config.lua:41`): `bank = { blizzardFrame = "tiny", view = "sections", columns = 14 }`, free tile on (`bags.freeTile = true`), 2 rows kept for New (`bags.newRows = 2`), gold glow `prices.worth = "fixed"` at 100g (line 53), sort mode `blizzard` (line 89).

### 1.1 The SwagBag bank window

It opens by itself on `BANKFRAME_OPENED` (`UI/BankWindow.lua:779-794`). It is a dark box with a 1px border. Default position is the top-left of the screen (x 60, y -120, `BankWindow.lua:135`), and it can be dragged. Width = 14 slots, which makes about 586 px (8 + 14x37 + 13x4). Height fits the content up to **75 % of the screen**, then the content scrolls (`BankWindow.lua:38, 355-356`).

The header is 80 px tall, plus 18 px more in List view (`BankWindow.lua:34-35, 288-290`).

**Row 1, the title row (y -5 to -8), left to right:**

| Element | Text | Size | Source |
|---|---|---|---|
| Title | `SwagBag bank`. Every button's answer flashes here for 1.5 s (3 s for the Blizzard bank toggle). A flash too long to fit is cut with "..." and also goes to chat | ~120 px left | `:67-69, 115-127, 542-544`; `enUS.lua:176` |
| Button | `Sort bank` | 76 | `:536-539`; `enUS:195` |
| Button | `Sort warband` | 96 | `:532-535`; `enUS:196` |
| Button | `Reflow` | 60 | `:528-531`; `enUS:113` |
| Button | View button. It names the **next** view, not the current one: `List` while you are looking at Categories, then `Grid`, then `Categories` | 72 | `:524-527, 505-515`; `GroupView.lua:61-62` |
| Button | `Blizzard bank` | 104 | `:266-269`; `enUS:180` |
| X | Close (hides only SwagBag's window) | | `:80-81` |

None of these buttons has a tooltip. `BankWindow.lua` has no `OnEnter` anywhere. In the bags window, by contrast, `Pause` has a three-line tooltip (`BagsWindow.lua:1363-1384`).

**Row 2 (y -30):** a search box, 200x20, at the left (`SearchBox.lua:20-21`). Its error line sits to its right. There is **no Lock button** on the bank window; the bags window has one.

**Row 3 (y -54 / -58):**
- Left: the deposit line, `Deposits go to Character bank - switch with the tabs below` (or `Warband bank`) (`:71-72, 167-175`; `enUS:179`). It is blank when the game will not say (`:170`).
- Right, reading right to left: the `Deposit warbound` button (128 px, `:597-600`; `enUS:197`), the words `With reagents` (`:604-606`), and a 22 px tick box (`:607-609`). The box and its label are hidden when the game cannot report the setting (`:614-619`).

**Row 4, List view only:** a column bar (`Name`, `Count`, `ilvl`, `Value`). A click sorts every list (`:414-420`).

**The content (scrolls), top to bottom** (`GroupView.lua`):
- **Group header** `- Character bank (N)` (22 px; `GV.GROUP_HEADER`; `enUS:193`). When this bank receives deposits, the header is tinted green (`GroupView.lua:159-160`, RGBA 0.25/0.85/0.35/0.3) and ends with `  - deposits go here` (`enUS:194`). A left-click folds the whole group.
  - **Section headers** (20 px), in the bags' format: `- New (0)`, then each category, for example `- Herbs (12) - 1,234g` (value from Auctionator or TSM, `HEADER_VALUE`), then `- Free (N)`. New is always shown in the bank (`BagsWindow.lua:846` comment), with 2 rows reserved.
  - **Slots**: 37 px with a 4 px gap. Each one is a real Blizzard item button.
  - **Free**: **one tile** showing the number of free slots for each bag family, so reagent-only tabs get their own tile (plan D19; `GroupView.lua:179-198`).
  - **Placeholders**: a faded icon stays where an item left, until the window regroups. The tooltip reads "This item moved or was used - items regroup when you close the bank." (`enUS:726`).
  - **Gold glow**: items worth 100g or more a stack glow gold, in both the bank and the bags, only while at the bank (`Overlays.lua:206-276`). Nothing in the window says what the glow means.
- 8 px gap, then **Group header** `- Warband bank (N)`, with the same structure below it.
- Tabs inside a bank are **not shown at all**. All purchased character tabs merge into one group. Categories mix items from every tab. Grid view runs all tabs as one continuous grid with no break between tabs (`GridLayout.lua:1-25`). Names and icons you gave your tabs in Blizzard's UI appear nowhere.
- Hovering a group or section header shows **no hint**. GroupView defines no `onEnter`; compare the bags headers, which show the Shift+right-click hint (`SectionActions.lua:258-264`).

**Under the window, outside it:** Blizzard's real tab buttons (`BankFrame.TabSystem`), labelled by Blizzard as **`Bank`** and **`Warband Bank`**. They are anchored to the window's **bottom-left corner**, 12 px in, hanging below the edge (`BankWindow.lua:194-196`; labels from the V2 checklist, `week3-checklists.md:91`). The window can be up to 75 % of the screen tall, so these tabs can sit **most of a screen below** the line that tells you to use them.

**No footer:** `FOOTER = 6` is just padding. No gold total, no free-slot summary, no help text.

### 1.2 The bags window at the same time
- It opens alongside, as Blizzard's does (spec §5.1).
- Title: `SwagBag — AH/Vendor/Bank — ilvl 279.4`. The built-in "market" focus mode switches on at the bank and **expands every section** (`Focus.lua:83-87`; `enUS:303, 308`).
- Title buttons, right to left: View, `Reflow`, `Pause`, `Sort`. While the visit is live but SwagBag's bank window is hidden, a fifth button appears: **`Bank still open`** (110 px, left of Sort; `BankWindow.lua:722-739`; `enUS:185`).
- **Right-click on a bag item** runs Blizzard's own code and deposits into whichever bank Blizzard's selected tab names (spec AC2.3). Nothing in the bags window says which bank that is.
- **Shift+right-click on a bags section header** opens `Send all to bank (N)` / `Send all to warband bank (N)` / `Cancel`. The header tooltip names this: "Shift+right-click: Send all to the bank or the warband bank" (`SectionActions.lua:1-20`; `enUS:925-945`). These moves pick the bank on the click itself and **ignore the selected tab** (`Adapter.lua:837-844`; spec §5.2).
- The gold glow also shows on bag items.

### 1.3 In "beside" mode, or after clicking `Blizzard bank`
Blizzard's whole bank frame shows where Blizzard puts it, with its own tabs, tab-settings sidebar, gold and `Deposit All Warbound Items` / `Include Reagents`. SwagBag's window **jumps** to its right (`BankWindow.lua:198-201, 243-252`). The deposit line still says "switch with the tabs **below**", but the tabs are now at the bottom of *Blizzard's* window, to the left (`enUS:179`, used in every mode).

### 1.4 Closing
- **Esc**: hides SwagBag's window. Blizzard's own Esc handling then ends the visit (spec §5.6).
- **X**: hides only SwagBag's window. **Blizzard's bank becomes visible** for the rest of the visit (item-safety rule W3-11; `BankWindow.lua:766-777`), and the bags window shows `Bank still open`.
- **Walking away**: everything closes.

### 1.5 The guild bank, for comparison (`UI/GuildBankWindow.lua`)
- Title `SwagBag guild bank` with only **three** buttons: Reflow, View, `Blizzard guild bank` (`:285-288, 614-623`).
- The tabs sit on the **right edge of the window, next to the groups**, one button per tab (`:209-211`). The line reads `Deposits go to Tab 2 - switch with the tabs on the right`.
- **One group per tab.** Each group header shows withdrawals left and `deposits go here` (`enUS:220-226`).

This is much easier to read. The tab you click, the group that lights up and the place the item goes are one and the same thing. The personal bank breaks that link: two groups, two Blizzard tabs far away, and N real tabs that are not shown.

---

## 2. Concepts a player must learn, and where SwagBag explains them

| # | Concept | Where it is explained today | Verdict |
|---|---|---|---|
| C1 | Right-click deposits into whichever bank **Blizzard's** selected tab names; SwagBag only reads it | Deposit line (`enUS:179`), green header + "deposits go here" | Partly. It never says "right-click". The line points to tabs that may be far away |
| C2 | You switch the target **only** with Blizzard's two tabs, labelled `Bank` / `Warband Bank` | Same line ("tabs below") | Weak. The tab labels don't match SwagBag's group names (`Character bank`). The line is wrong in beside mode |
| C3 | Character bank = this character only; warband bank = shared by all your characters | Nowhere | Missing |
| C4 | The two groups are **not** tabs; each group merges all of that bank's purchased tabs | Nowhere | Missing |
| C5 | New / categories / Free inside each group; deposits land in **that group's New** | Bags tour (`enUS:645-646`) covers sections in bags only; no bank tour | Missing at the bank |
| C6 | Free shows one tile with a count, not every slot | `/swagbag free` help only | Missing in window |
| C7 | Faded icons are placeholders and regroup on close | Placeholder tooltip (`enUS:726`) | OK if hovered |
| C8 | Two sort buttons, one per bank; Sort mode "partial stacks first" | Settings > Bags; flash `Sorting...` | Button names are OK; mode unexplained here |
| C9 | `Reflow` = regroup now | Flash `Regrouped` | Jargon, no tooltip |
| C10 | View button names the **next** view | Flash after click (`enUS:211-213`) | Confusing before you click |
| C11 | `Deposit warbound` moves *all* warbound items from bags to the **warband** bank, whatever the selected tab is | Flash after click (`enUS:199-209`) | Jargon ("warbound"); no tooltip; the "ignores the tab" rule is invisible |
| C12 | `With reagents` is Blizzard's own setting and affects only Deposit warbound, **not** right-click | Flash after click (`enUS:208-209`) | Missing before the click |
| C13 | `Blizzard bank` shows Blizzard's real bank (tab purchase, tab settings, warband gold) and moves SwagBag's window | Flash + chat after click; Settings note (`enUS:466`) | Weak: the label says nothing about why you'd click it |
| C14 | Tiny vs beside (setting `Hidden` / `Shown beside`, slash `/swagbag bank tiny/beside`) | `/swagbag help`, Settings > Bank & guild (`enUS:186-190, 454-456`) | Slash words are jargon; Settings words are fine |
| C15 | X vs Esc: X leaves the visit open, Blizzard's bank appears, and `Bank still open` appears on the bags | Nowhere until it happens | Surprising |
| C16 | Shift+right-click a **bags** header to "Send all" to a chosen bank, ignoring the tab | Bags header tooltip (`enUS:945`) | Hidden power. Fine, but "bank" vs "Character bank" naming differs |
| C17 | Gold glow = worth 100g+ a stack (at the bank only) | Settings tooltip (`enUS:956-961`), `/swagbag worth` | Missing in window |
| C18 | Dropping an item on a **bank section header** files it into that category; it does **not** deposit | Bags tour line about dragging onto headers | A trap (see 3.3) |
| C19 | Tab purchase, tab names/icons and per-tab deposit filters live only in Blizzard's frame | Settings note (`enUS:466`) | Missing in window |

That is about 19 things, against roughly 4 for the guild bank. Most are explained only *after* a click (the flash) or not at all. Section 3 covers the four the user picked.

---

## 3. The four pain points: evidence, the single best fix, and other ideas

Ranked by how much each one costs this user. #1 risks an item going to the wrong place. #3 is about finding things every visit. #4 and #2 are about clutter and jargon.

### 3.1 Pain point 1: "Where does my right-click deposit go, and how do I switch?" (rank 1)

**What confuses (evidence):**
- The only explanation is one small line in row 3 (`GameFontHighlightSmall`, `BankWindow.lua:71`) that never mentions right-click: `Deposits go to Character bank - switch with the tabs below` (`enUS:179`).
- The switch is two Blizzard tabs **hanging under the bottom edge** (`BankWindow.lua:195`). In a tall window they are far from the line and easy to miss, or hidden behind action bars.
- The tab labels (`Bank`, `Warband Bank`) don't match SwagBag's names (`Character bank`, `Warband bank`, and `bank` in Send all). The player has to work out that "Bank" means "Character bank".
- Three different routes send items to the bank, and they follow **different rules**:
  - right-click follows the selected tab;
  - `Deposit warbound` always goes to warband;
  - Send all (Shift+right-click a bags header) goes to whatever you pick.

  Only the first rule is shown anywhere.
- The "deposits go here" mark is on a header that may be scrolled out of view. When the warband bank is the target and the character bank is long, the warband header sits below the fold.
- The bags window, where the player actually right-clicks, shows **nothing** about the target. Its title says `AH/Vendor/Bank` (`enUS:303`), not "→ Warband bank".
- In beside mode the line's "tabs below" is wrong (§1.3).
- When the game won't say the target, the line is simply blank (`BankWindow.lua:170`).

**Single best fix: a "Right-click deposits to: [Bank] [Warband Bank]" bar at the top of the window, built from Blizzard's real tabs.**

Move the re-hosted `BankFrame.TabSystem` from under the window up into row 3, right after the words `Right-click deposits to:`. Today's `placeTabs` already only sets anchors (`BankWindow.lua:194-196`); TinyHost.Rehost exists for exactly this and puts the anchors back on close. The player sees one obvious two-way switch at the top. It is Blizzard's own button, so a click still runs Blizzard's code and the deposit stays correct. Nothing hangs off the window any more. Keep the green group tint and change its text to `← right-clicked items land here (in New)`.

Add a matching cue where the right-click happens. The bags title at the bank reads `SwagBag — Bank → Warband` (or `→ Character`) instead of `AH/Vendor/Bank`. It updates from the `SB_BANK_TARGET` signal that `RefreshTarget` already emits (`BankWindow.lua:174`).

Check in game first: does the TabSystem lay out and click correctly when anchored mid-window (inside the header, above the scroll frame) instead of below? The anchor change is SwagBag's own; no Blizzard state is written. If Blizzard's tab widths overflow the header, fall back to placing the bar just above the scroll area with the tabs at their natural size.

**Other ideas (all within the rules):**
- **Item-tooltip line at the bank**: `Right-click: deposit into Warband bank`. Tooltip hooks are allowed (spec §5.3; `Adapter.HookItemTooltip` is already used by Locks). This puts the answer on the item itself.
- Rename the in-window strings so they match Blizzard's tabs wherever possible: `Character bank` → keep, but put "(Bank tab)" in the deposit bar's tooltip, or call the group `Character bank (Blizzard tab: Bank)` once. Make Send all say `Character bank`, not `bank` (`enUS:925`).
- Tooltips on `Deposit warbound`: "Moves every warbound item in your bags into the Warband bank, whatever tab is selected. Uses Blizzard's own deposit." On `With reagents`: "Blizzard's own setting: Deposit warbound also takes reagents. Right-click deposits are not affected."
- An empty-target fallback: when `ActiveBankType()` is nil, say `Click Bank or Warband Bank to choose where right-click deposits go` instead of a blank line.
- In beside mode, use a different string: `... - switch with the tabs at the bottom of Blizzard's bank`.
- One-time first-visit note (see 3.4): three short notes pointing at the deposit bar, the green group, and `Blizzard bank`.

**Not possible (the Blizzard limit):** a SwagBag-owned toggle cannot drive right-click. Right-click on a bag item is Blizzard's handler, and it reads `BankFrame:GetActiveBankType()`. The only way to change that is `BankFrame:SetTab`, which the taint probe proved breaks item use until `/reload` (spec §5.3, AC2.5). SwagBag also may not hook item clicks (§5.3: no PreClick/PostClick). So the switch must be Blizzard's tab button. SwagBag can only move it and label around it.

What SwagBag *can* do from its own clicks: move items to a bank type of its choosing, because `C_Container.UseContainerItem(bag, slot, nil, bankType)` takes the bank type as an argument (`Adapter.lua:837-844`; proven in BK1 step 12). A SwagBag-only "Send to" switch could therefore steer Send all and Deposit warbound, but never the plain right-click. Two switches would be worse than one, so don't build a second toggle.

### 3.2 Pain point 3: "I can't tell what's where" (rank 2)

**What confuses (evidence):**
- Two long groups are stacked in one scrolling column. With 6 character tabs (98 slots each, `week1-ledger.md:16`), the Character bank alone is hundreds of slots, so the Warband group starts below the 75 % height cap and the player may never scroll to it.
- Inside each group, all tabs are merged into categories. "Which tab is it in?" cannot be answered in Categories view. Grid view runs every tab as one continuous grid with no breaks (`GridLayout.lua:1-25`). Tab names and icons the player set in Blizzard's UI appear nowhere.
- Section names repeat across the two groups (`New`, `Herbs`, `Free` appear twice). Only the group header 30 rows up says which bank you're in.
- Nothing explains what the warband bank *is* (shared across characters), or why some items can't go there.
- The gold glow appears with no legend (`Overlays.lua:206-213`).
- **Trap:** dragging an item onto a bank **section header** does not deposit it. It files the item into that category and prints `Added X to Y...` or `Items can't be added to New...` (`BankWindow.lua:398-400` → `BagsWindow.DropOnSection`, `BagsWindow.lua:1253-1273`; `enUS:119-120`).

**Single best fix: show one bank at a time, following the deposit tab.**

The group for the selected tab is open. The other folds to a single slim header line, for example `+ Warband bank (312 items) - click to show`. Clicking Blizzard's `Warband Bank` tab then means *both* "show me the warband bank" and "deposit there". That is exactly how Blizzard's own bank works, and how Baganator shows one bank at a time (from memory; not checked in code here). It removes the scrolling, the duplicate section names and most of the "which bank am I looking at" question, and it reinforces fix 3.1.

Power stays one click away. Clicking the folded header opens it for a peek, and a setting `Bank shows: The selected bank (default) / Both banks` keeps today's layout for anyone who wants it.

It uses only what SwagBag already does: read `ActiveBankType()` (`BankWindow.lua:167-175`) and fold a group (`GroupView.ToggleGroup`). It must be a view-only fold that is not saved, because the per-character collapse set is the player's own (`GroupView.lua:44-45, 99-104`). It also needs the same held-layout rules as any regroup (P5: nothing moves under the mouse).

**Other ideas:**
- Group header subtitles: `Character bank - this character only` / `Warband bank - shared by all your characters`.
- **Tab markers**:
  - In Grid view, start each tab on a new row under a thin label `Tab 2: Herbs`. Names come from the read-only `C_Bank.FetchPurchasedBankTabData`; check the client field names first.
  - In Categories view, add a tooltip line on bank items, `In: Warband bank, tab 3`.
- Make a drop on a bank section header deposit the item into that group, or at minimum refuse with `Drop items on the Free tile to deposit them; drop on a header in your bags to change its category.` Depositing into a chosen group from a drag is allowed: a drop onto an empty bank slot is Blizzard's own pickup and drop, and the Free tile is a real empty slot button.
- A tiny legend line or tooltip for the gold glow: `Gold glow: worth 100g+ a stack (Settings > Bank & guild)`.
- Search already spans both banks. Add `Found in: Character bank 2, Warband bank 1` in the deposit or status line while searching.

### 3.3 Pain point 4: "Tabs hanging under the window, tiny vs beside, the Blizzard bank toggle" (rank 3)

**What confuses (evidence):**
- The tabs hang below the window (`BankWindow.lua:195`). They look like they belong to whatever is underneath, and they move every time the window's height changes.
- `tiny` / `beside` are the slash-command words (`enUS:186-190`); Settings says `Hidden` / `Shown beside` (`enUS:454-456`). The underlying idea, that Blizzard's bank is secretly open, invisible, at 0.001 scale (`TinyHost.lua:1-10`), is an implementation detail the player should never need to know.
- The `Blizzard bank` button gives no reason to press it (no tooltip). Pressing it makes SwagBag's window **jump** beside Blizzard's (`BankWindow.lua:243-252`; ruling D17 made the answer longer and copied it to chat precisely because the jump surprised). The tabs then switch to Blizzard's frame.
- **X vs Esc** behave differently. After X, Blizzard's bank pops up (W3-11, `BankWindow.lua:766-777`) and a new `Bank still open` button appears on the bags (`:722-739`). To the player, "I closed the bank and the old bank appeared."

**Single best fix: no hanging tabs, and one plainly named door to Blizzard's bank.**

With fix 3.1 the tabs live in the header, so nothing hangs. Rename `Blizzard bank` to **`Buy tabs & gold`** (or `Blizzard's bank...`). Give it the tooltip "Opens Blizzard's own bank next to this one: buy tabs, change tab settings, warband gold. Click again to hide it." Move it into the overflow menu (fix 3.4).

"Tiny/beside" then disappears from the surface. It stays in Settings as `Blizzard's bank while SwagBag's bank is open: Hidden / Shown beside` (already the wording), and the slash command accepts `hidden` / `shown` as aliases of `tiny` / `beside`.

**Other ideas:**
- X tooltip: `Hide this window - Blizzard's bank shows until you walk away or press Esc`. Better: a one-line flash in the bags title when it happens (`Bank still open: click to bring SwagBag's bank back`). Don't make X end the visit: that needs `CloseBankFrame` or hiding Blizzard's frame from addon code, which spec §5.3 / AC2.5 forbid.
- Rename `Bank still open` to `Show bank` (it is a button, and that's what it does).
- When the toggle shows Blizzard's bank, keep SwagBag's window where it is and anchor nothing. Only if it overlaps, move it, and say so once.

### 3.4 Pain point 2: "Too many buttons and things" (rank 4)

**What confuses (evidence):**
- Row 1 has five buttons plus X (`Sort bank`, `Sort warband`, `Reflow`, view, `Blizzard bank`) and no tooltips.
- Row 3 has a line, a tick box, a label and a button.
- Ten controls before a single item, against three in the guild bank window (§1.5).
- The view button's label names the *next* view (`GroupView.lua:61-62`), so `List` while looking at categories reads like a status, not an action.
- `Reflow` is jargon. Regrouping already happens on close (P5), and the bags window has its own Reflow.
- Two sort buttons named after banks that are named differently elsewhere (`Sort bank` vs `Character bank`).

**Single best fix: a slim header with three things (Search, the deposit bar, `Sort`) and a `⋯` menu for the rest.**

- **Row 1:** `SwagBag bank` ... `[Sort]` `[⋯]` `[X]`.
  - `Sort` sorts **the bank you're looking at / depositing into**. With fix 3.2 that is the open group, so one button is enough and always means the visible bank.
  - Shift-click sorts both. Tooltip: "Sorts the Warband bank (Blizzard's sort). Shift-click: both banks."
- **Row 2:** search box (wider), then the deposit bar from fix 3.1: `Right-click deposits to: [Bank][Warband Bank]`.
- **`⋯` menu**, plain words, each with a one-line description:
  - `View: Categories / List / Grid` (radio, showing the current one);
  - `Deposit all warbound items` (with `Include reagents` tick);
  - `Regroup now`;
  - `Show Blizzard's bank (buy tabs, gold)`;
  - `Bank settings...`.

**Keep Deposit warbound visible?** It was a user request (week 6, request 3; spec AC2.8), so ask the user. A good middle ground is to put it on the **Warband bank group header** as a small `+ Warbound` button, where its target is self-evident, rather than in the menu.

**Other ideas:**
- If buttons stay in the title row, add tooltips to every one (P2 already gives an answer after a click; a tooltip answers *before* it).
- The view button shows the current view (`Categories ▾`) instead of the next.
- Consistent order with the bags window: the bags have View rightmost and Sort leftmost (`BagsWindow.lua:459-463, 1386-1389`); the bank has the reverse. Pick one order for both.

**API note:** a dropdown or menu is SwagBag's own frame. It may call the same functions the buttons call today (`BW.Sort`, `BW.DepositWarband`, `BW.ToggleVisit`, `BW.ToggleView`, `BW.Reflow`), because those already run from SwagBag's own clicks. Two cautions:
- `Sort` from a menu entry is still an addon click, as today.
- "Shift-click sorts both" makes two `C_Container.SortBank` calls back to back. Check in game that the second isn't refused while the first runs (spec §5.5 measured one call). If it is, chain the second after the first settles (`BW.sortPending` already tracks this).

### 3.5 Other confusions worth noting (outside the four)
- **No bank tour.** `/swagbag tour` covers only the bags (`enUS:645-653`; `Tour.lua:20`). Add a three-step bank leg the first time the bank opens (deposit bar, green group, `⋯`), offered once and repeatable with `/swagbag tour` at the bank.
- **No empty-state text.** A bank with no purchased warband tabs shows a `Warband bank (0)` group with nothing in it. Say `No warband bank tabs yet - buy one with Buy tabs & gold`. A first visit with an empty character bank should say how to deposit.
- **Combat:** the window opens beside Blizzard's and flashes `In combat: Blizzard's bank stays visible for this visit` (`enUS:183`). That's fine, but it is a third layout the player may meet.

---

## 4. Blizzard and taint limits (why some "obvious" fixes are off the table)

From spec §5.2-5.3, AC2.5 and the week-3 ledger:

| Wanted | Allowed? | Why |
|---|---|---|
| SwagBag's own Character/Warband toggle that sets where **right-click** goes | **No** | Needs `BankFrame:SetTab` or writing `.bankType`. One call taints `UseContainerItem` until `/reload` (spike taint probe). Permanently forbidden; enforced by a CI grep |
| Moving Blizzard's real tab buttons anywhere on SwagBag's window | **Yes** | SwagBag changes only their parent and anchors (TinyHost.Rehost) and restores them exactly. A click is still Blizzard's own code |
| Changing the tab buttons' text (to say "Character bank") | Avoid | That writes Blizzard frame state. Label *around* them instead |
| Hooking clicks on item buttons (to steer a right-click) | **No** | §5.3: no PreClick/PostClick or click hooks on slot buttons |
| Item tooltip lines ("Right-click: deposit into Warband bank") | **Yes** | Tooltip hooks are allowed (§5.3); Locks already add a line |
| SwagBag-initiated moves to a **chosen** bank (Send all, drag targets, menu actions) | **Yes** | `UseContainerItem(bag, slot, nil, bankType)` takes the type as an argument; proven in BK1 |
| X closing the whole bank visit | **No** | Needs `C_Bank.CloseBankFrame` / `CloseBankFrame(` or hiding Blizzard's frame from addon code: forbidden (§5.3) |
| Hiding Blizzard's bank outright | **No** | Hiding it ends the visit and makes `GetActiveBankType()` return nil; that's why tiny mode keeps it shown at 0.001 scale |
| Buying tabs or changing tab settings from SwagBag | **No** | `PurchaseBankTab` is forbidden (§5.3). Leave it in Blizzard's frame behind one clearly named button |
| Reading tab names/icons for labels | Likely yes | `C_Bank.FetchPurchasedBankTabData` is a read; the Adapter must guard it and check secret values |
| Folding the non-selected group (fix 3.2) | **Yes** | SwagBag's own layout state, driven by a read of `ActiveBankType()` |

---

## 5. Suggested order of work (smallest change, biggest relief first)

1. **Deposit bar** (3.1): move the real tabs into the header after `Right-click deposits to:`, fix the beside-mode and blank-target text, and add the bags-title cue `Bank → Warband`. Needs one in-game check (tabs lay out and click correctly mid-header).
2. **Tooltips everywhere** in the bank window, plus the item-tooltip line `Right-click: deposit into ...`. Pure text, no risk.
3. **One bank at a time, following the tab** (3.2), with the `Both banks` setting kept.
4. **Slim header + `⋯` menu** (3.4); rename `Blizzard bank` → `Buy tabs & gold`, `Bank still open` → `Show bank`, `Reflow` → `Regroup now`; the view button shows the current view.
5. **Bank leg of the tour**, empty states, tab markers in Grid view, and a drop-on-header refusal that explains.

Each step keeps every current capability; only where it lives and what it's called changes. That fits the principle: a simple surface, with the full power one click away.
