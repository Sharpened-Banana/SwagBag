# SwagBag Week 13: A bank you can read at a glance. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the user said the bank "is very hard to understand" and named four problems: where right-click deposits go, too many buttons, finding items, and the tabs and modes. Week 13 fixes all four. Every capability stays; what changes is where things live and what they are called. The user's picks, in build order:

1. **Deposit warbound sits on the Warband bank's header.** It moves there with its "With reagents" box (Task 2). This frees row 3 for:
2. **The deposit bar.** Blizzard's own two tabs move from under the window into the header, after the words "Right-click deposits to:". The bags title at the bank says where right-click goes. A bag item's tooltip says it too (Task 3).
3. **One bank at a time.** The window shows the bank whose tab is selected. The other bank folds to one line ("+ Warband bank (312) - click to show"). During a search that line says how many matches are hidden there. A setting, "Both banks", brings back today's layout (Task 4).
4. **A slim header and a "..." menu.** The title row keeps only Sort, "..." and the close button. Sort sorts the bank you're depositing into. The "..." menu holds the view choice, sorting either bank, Regroup now, Show/Hide Blizzard's bank, Deposit all warbound items, and Bank settings. Every bank button gets a tooltip. "Bank still open" becomes "Show bank" (Task 5).
5. **Plain words for the modes.** `/swagbag bank hidden|shown` replaces tiny/beside, and the old words still work. Help, answers and Settings use the same words (Task 6).

The version goes to 0.13.0 (Task 1).

**The user's principle (binding, memory `product-principle-simple-surface-deep-power`):** "out of the box as easy and simple as possible, under the hood an insane amount of customization and power."
- **Simple half:** the default bank window shows one bank, one deposit switch, one Sort and one menu.
- **Power half:** both banks, sorting either bank, every view, regroup, Blizzard's bank and every setting stay one click away (the "..." menu, Settings, slash commands, share strings). Nothing is removed.

**Research behind every decision:**
- `research/2026-10-06-bank-ux-walkthrough.md` (the audit of v0.12.0, with line references);
- `research/2026-10-06-bank-ux-competitors.md` (how other bag addons do banks).

**Architecture:**
- `UI/GroupView.lua` gains four optional cfg hooks, which the guild bank does not use:
  - `groupClosed(gid)`: a view-only fold that overrides the saved collapse set without changing it;
  - `toggleGroup(gid)`: a header click the window handles itself;
  - `groupInset(gid)`: room kept free at the right end of a group header;
  - `groupTip(gid, header)`: a header tooltip;
  - and one callback, `onHeaders(groupHeaders)`, called after the headers are drawn, so a window can put its own controls on a group header.
- `UI/BankWindow.lua` uses them for the one-bank fold and for the deposit controls on the Warband header.
- The tabs re-host into the header through the existing `TinyHost.Rehost`; only `placeTabs` changes.
- The menu is a new file, `UI/BankMenu.lua` (`SB.BankMenu`). It is a plain frame like `SectionActions`' menu, and its entries call the functions the old title buttons called.
- `UI/BagsWindow.lua` listens to `SB_BANK_TARGET` for its title.
- `UI/TooltipCounts.lua`-style tooltip hooking adds the right-click line (a new small function in `UI/BankWindow.lua`, hooked through `Adapter.HookItemTooltip`).

**Tech Stack:**
- Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105).
- LuaJIT 2.1 for tests, with the in-repo runner `spec/runner.lua`.
- luacheck, and `scripts/check.sh` for the full gate.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`.
- This plan changes how F2 / §5 (the bank window) presents itself: §5.1 layout, §5.4 tiny/beside wording, and AC2.8 (Deposit warbound's place).
- It keeps every rule in §5.2/§5.3: the deposit target is read, never set.
- The spec text is updated in Task 6.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag` (quote it: it contains a space). Run every command from there.

**Branch:**
- Make it before Task 1: `git checkout -b week13` from `main` at `a0c68f1` (v0.12.0, 1709 tests).
- No task creates or switches branches.
- Leave the untracked `.venv/` alone.

**Interfaces used as they are on `a0c68f1`:**
- **Core:** `SB.On/Emit/Debounce/Print`, `SB.ErrorTrap.Guard/Run`, `SB.Slash.Register`, `SB.Config.Get/Set/UI/Defaults`, `SB.AtBank()`.
- **Bank window:** `SB.BankWindow` (`frame`, `view`, `target`, `RefreshTarget`, `ApplyMode`, `ToggleVisit`, `VisitMode`, `Mode`, `Sort(kind)`, `Reflow(reason)`, `ToggleView`, `DepositWarband`, `RefreshReagents`, `Flash(text, seconds, toChat)`, `GroupName(kind)`, `TitleButton`, `host`, `searchBox`).
- **Shared UI:**
  - `SB.TinyHost` (`Rehost(frame, onto, place)` saves and restores the anchors);
  - `SB.GroupView` (see its header for every cfg field);
  - `SB.SectionHeaders` (`Acquire(parent, id, label, x, y, width, owner)`, owner `onEnter/onLeave/onClick/onDrop`, `inUse`);
  - `SB.SearchBox` (`box.Apply()`; `search.IsActive()`);
  - `SB.SettingsWindow.Show(pageId)`;
  - `SB.BagsWindow` (`Title`, `RefreshTitle`, `BoundTitle`, `sortButton`).
- **Adapter:** `SB.Adapter` (`ActiveBankType`, `AllowedInBank(bag, slot, kind)`, `HookItemTooltip(fn)`, `TooltipLine`, `InCombat`).
- **Engine:** `SB.Profiles`' key table (`Engine/Profiles.lua:85-115`).
- **Test helpers:** `spec/helpers/loader.lua`, `fakeframe.lua`, `uienv.lua` (`Env.LoadBank`), `spec/mock_adapter.lua` (`m.activeBankType`, `m.combat`), and the `blizzardBank()` fake with `TabSystem.tabs` (`spec/bankwindow_groups_spec.lua:11-17`).

## Global Constraints

- **Target and versions:**
  - WoW Retail 12.1.x only, TOC `## Interface: 120100, 120105`, English only.
  - Version `0.13.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
  - TOC metadata is unchanged. One file is added: `UI/BankMenu.lua`, right after `UI/BankWindow.lua` (Task 5).
- **Lua 5.1 only:** no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets only strings or numbers.
- **Adapter rule:** `SwagBag/Core/Adapter.lua` is the only file that may name `C_*`, `Enum`, ElvUI, Syndicator, `TSM_API` or `LibStub`, comments included. **No Adapter change this week.**
- **Forbidden anywhere in `SwagBag/`, comments included:** `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`.
  - **SwagBag never chooses where right-click goes:** it reads `Adapter.ActiveBankType()` and moves Blizzard's tab buttons (parent and anchors only, through `TinyHost.Rehost`, restored exactly).
  - It never changes a Blizzard tab's text, size or scale.
- **Plain frames only:**
  - The "..." menu, the Sort button, the deposit controls on the Warband header and the bar label are plain `Button`/`CheckButton`/`FontString`/`Frame`. They may be created, shown and hidden in combat.
  - Secure item buttons are never reparented or created in combat (unchanged).
  - Blizzard's TabSystem is re-hosted out of combat only (`Rehost` refuses in combat).
- **No glyphs the game font may lack:** no `⋯`, `→`, `←`, `…` in any string. The menu button reads `...` (three ASCII dots). The em dash `—` already used by `BAGS_TITLE_*` is fine.
- **P2 (exactly one answer per click and command):**
  - A menu entry answers as its old title button did (the same `BW.Flash` text). Opening or closing the menu answers by the menu itself.
  - A click on a folded group header answers by the group opening.
  - `/swagbag bank ...` answers every form.
- **P5 (nothing moves under the mouse or cursor):**
  - Every fold or unfold, including the automatic one when the target switches, goes through `GroupView`'s `v.Restack()`, which holds while a button that would move is under the mouse or anything is on the cursor.
  - Changing the view from the menu uses `RequestLayout("view")` as today.
- **P6:** every entry point runs inside `SB.ErrorTrap.Guard`/`Run`, with window `"bank"` for bank-window code. New labels:
  - `bank.sortButton`, `bank.moreButton`, `bank.menu`, `bank.menuEntry`, `bank.groupTip`, `bank.depositTip`, `bank.barTip`;
  - `tooltip.deposit` (under `"none"`, like `tooltip.counts`);
  - `bags.bankTarget` (the bags title listener, window `"bags"`).
- **P8:** every user-visible string is in `SwagBag/Locale/enUS.lua`, with the exact copy given in the tasks. Removed keys are deleted from enUS.lua and from every spec. `spec/locale_spec.lua` must stay green.
- **Saved data (schema stays 2, no migration):**
  - One new setting, `bank.show = "one" | "both"`, default `"one"`, added to `Config.Defaults` next to `bank.blizzardFrame`.
  - It is shareable through Profiles: `words("one", "both")`, label `SET_BANK_SHOW`.
  - The per-character collapse set `ui.collapsed["bank:#"]` is untouched by the one-bank fold: it is read only in "both" mode.
  - The one-bank peek state is in memory and forgotten at every target change and every close.
- **Idle and load time:** no `OnUpdate`. No file calls `Config` at load time. Idle CPU with every window closed stays 0.
- **Tests:**
  - Every critical test names the mutation that must make it fail; each task lists its mutations at its test step.
  - Tests run with `luajit spec/runner.lua spec/*_spec.lua`.
  - Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
  - The suite starts at 1709. Each task states the minimum number of new tests; the ledger records the actual totals.
- **Commits:**
  - One commit per task: `git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit`.
  - The message ends with exactly:
    `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
    `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`
- **Existing tests that drive the removed title buttons** (`sortBankButton`, `sortWarbandButton`, `reflowButton`, `viewButton`, `blizzardButton`, the row-3 `depositButton`, the `BANK_DEPOSITS_TO` text) are **re-pointed**, not deleted:
  - to the same `BW.*` function;
  - or to the new control that now carries that action (the menu entry, `BW.sortButton`, or the deposit button on the Warband header).
  - A test may be removed only when the behaviour it pinned no longer exists (for example, the view button's "next view" label). The task's report lists each removal with its reason.

## Review Focus

The five uncovered inputs most likely to hurt a player. Each has a test in the task named.

1. **The game won't say the deposit target** (`ActiveBankType()` returns nil at open or after a tab click).
   - Expected: both banks show open, the target tint is on neither, and in beside mode the bar reads the "pick" line.
   - Never fold everything; never leave a blank bar. (Task 4 test "no known target shows both banks"; Task 3 test "beside with no target asks to pick".)
2. **The target switches while the mouse is over a bank item, or an item is on the cursor.**
   - Expected: the fold waits (P5) and lands when the mouse leaves. (Task 4 test "a target switch under the mouse waits".)
3. **A visit that starts in combat** (beside forced, tabs stay on Blizzard's frame).
   - Expected: the bar shows the beside line, not "Right-click deposits to:" with no tabs next to it.
   - The menu's Show/Hide Blizzard's bank answers "Leave combat first".
   - (Task 3 test "a visit started in combat shows the beside line"; Task 5 test "Blizzard's bank entry refuses in combat".)
4. **A narrow window** (`bank.columns` 4, the minimum shareable value).
   - Expected: the window is never narrower than `BW.MIN_WIDTH`.
   - The Warband header's deposit controls hide when they would cover the header's name, and Deposit warbound stays reachable in the "..." menu.
   - (Task 2 test "narrow bank hides the header controls"; Task 3 test "the window keeps its minimum width".)
5. **"Both banks" with a saved collapsed group.**
   - Expected: switching from "one" back to "both" shows exactly the player's own saved folds again; "one" never wrote them.
   - (Task 4 test "one-bank folds never touch the saved collapse set".)

---

### Task 1: GroupView hooks for window-owned folds, header room, header tooltips and header controls; version 0.13.0

**Files:**
- Modify: `SwagBag/UI/GroupView.lua` (cfg doc header lines 35-51; `groupClosed` 121-123; `owner.onClick` 288-304; `renderExtras` 341-366; `v.ToggleGroup` 799-803)
- Modify: `SwagBag/SwagBag.toc` (`## Version: 0.13.0`), `SwagBag/Core/Init.lua` (`SB.VERSION = "0.13.0"`)
- Test: `spec/groupview_spec.lua`

**Interfaces:**
- Produces, as new optional cfg fields (document each in the header comment):
  - `cfg.groupClosed(gid) -> true | false | nil`: when it returns a boolean, that decides whether the group is folded. `nil` falls back to the saved set `ui.collapsed[key .. ":#"]`.
  - `cfg.toggleGroup(gid) -> bool`: called by a group-header click before the saved set is touched. `true` means the window handled it, and GroupView only calls `v.Restack()`. `false` means GroupView toggles the saved set as today.
  - `cfg.groupInset(gid) -> px`: the header for `gid` is acquired `px` narrower (default 0), so window controls on its right never overlap the label.
  - `cfg.groupTip(gid, header)`: runs on `OnEnter` of a group header. Its `OnLeave` hides `GameTooltip` when `GameTooltip:GetOwner() == header`.
  - `cfg.onHeaders(list)`: called at the end of every `renderExtras` with `pos.groupHeaders` (`{ id, y, count, collapsed }`, `y` negative from the child's top). It is also called with `{}` from `v.Clear()`.
- Produces `v.GroupHeaders() -> list`: the last drawn `pos.groupHeaders`, or `{}`.

- [ ] **Step 1: Write the failing tests** in `spec/groupview_spec.lua`. Build each view with the file's existing two-group fixture.
  - `it("groupClosed decides a fold without touching the saved set")`:
    - `cfg.groupClosed = function(gid) return gid == "warband" end`;
    - after `v.Layout("open")`, every warband cell is hidden, bank cells are shown, and `next(v.Collapsed("#")) == nil`.
    - Mutation: ignoring `cfg.groupClosed` in `positionAll`.
  - `it("groupClosed nil falls back to the saved set")`:
    - `groupClosed` returns nil and the saved set has `warband = true`;
    - the warband cells are hidden.
    - Mutation: treating nil as false.
  - `it("a header click the window handles restacks without saving")`:
    - `cfg.toggleGroup` records its gid and returns true;
    - firing the warband group header's click calls it with `"warband"`, the saved set stays empty, and a restack ran (the group's cells change visibility when `groupClosed` flips inside `toggleGroup`).
    - Mutation: also toggling the saved set.
  - `it("a header click the window declines toggles the saved set")`: `toggleGroup` returns false, and the saved set gets `warband = true`.
  - `it("groupInset narrows that header only")`: `groupInset` returns 200 for warband, so the warband header's width is 200 less than the bank header's.
  - `it("onHeaders gets every group header after each draw")`:
    - the callback receives two entries with ids `bank`, `warband` and a negative `y` for the second;
    - after `v.ToggleSection` it is called again;
    - after `v.Clear()` it is called with an empty list.
  - `it("groupTip runs on enter and the tooltip hides on leave")`.
  - `it("the guild bank's views are unchanged")`: a view with none of the new fields behaves as before (the existing guild specs stay green; this test asserts the header width equals `pos.width - 2*PAD`).
  - At least 8 new tests.

- [ ] **Step 2: Run them and see them fail**: `luajit spec/runner.lua spec/groupview_spec.lua`. Expected: the new tests FAIL (nil cfg fields are never called).

- [ ] **Step 3: Implement the hooks in `SwagBag/UI/GroupView.lua`.**
  - `groupClosed(gid)` consults `cfg.groupClosed` first.
  - `owner.onClick` for a group id calls `cfg.toggleGroup` first; when it returns true, call `v.Restack()` only.
  - `renderExtras` uses `width - (cfg.groupInset and cfg.groupInset(g.id) or 0)` for group headers. It sets `owner.onEnter/onLeave` for `#` ids when `cfg.groupTip` exists (section headers keep their behaviour), and calls `cfg.onHeaders(pos.groupHeaders)` last.
  - Wrap the window callbacks (`groupTip`, `onHeaders`) inside the existing owner guard. Do not add a second ErrorTrap layer.
  - Bump the version in the TOC and in `SB.VERSION`.

- [ ] **Step 4: Run the gate**: `scripts/check.sh`. Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Week 13 Task 1: GroupView hooks for window folds, header room, tips and controls; 0.13.0`.

---

### Task 2: Deposit warbound and With reagents move onto the Warband bank's header

**Files:**
- Modify: `SwagBag/UI/BankWindow.lua` (the deposit section, lines 546-633; the GroupView cfg, lines 361-409)
- Modify: `SwagBag/Locale/enUS.lua` (the deposit strings, lines 197-210)
- Test: `spec/bankwindow_spec.lua` (re-point the deposit tests), `spec/bankwindow_groups_spec.lua`

**Interfaces:**
- Consumes `cfg.onHeaders` and `cfg.groupInset` (Task 1).
- Produces:
  - `BW.depositButton`, `BW.reagentsBox`, `BW.reagentsLabel`: the same fields, now children of `BW.child`, placed on the Warband group header.
  - `BW.DEPOSIT_W = 236`: the room they take, given to `groupInset("warband")`.
  - `BW.HEADER_LABEL_MIN = 160`.
  - `BW.DepositControlsShown() -> bool`.
- Unchanged: `BW.DepositWarband()` and `BW.RefreshReagents()`.

- [ ] **Step 1: Write the failing tests.**
  - `it("Deposit warbound sits on the Warband bank's header")`:
    - after the bank opens, `BW.depositButton:GetParent() == BW.child`;
    - its `TOPRIGHT` point's y equals the warband group header's y (as given to `onHeaders`), plus or minus 2;
    - it is shown.
    - Mutation: anchoring it to the frame's row 3.
  - `it("the controls follow the header when the group above folds")`: fold the Character bank (`v.ToggleGroup("bank")` in "both" mode or a saved fold), and the button's y follows the new header y.
  - `it("the warband header leaves room for the controls")`: the warband header is `BW.DEPOSIT_W` narrower than the bank header.
  - `it("narrow bank hides the header controls")`:
    - `bank.columns = 4` gives a group width below `BW.DEPOSIT_W + BW.HEADER_LABEL_MIN`;
    - the button, box and label are hidden, `groupInset("warband")` is 0, and `BW.DepositControlsShown()` is false.
    - Mutation: always showing them.
  - `it("the controls hide with the window and come back on reopen")`.
  - `it("Deposit warbound's tooltip says where it goes")`:
    - `OnEnter` on the button puts `L.BTN_DEPOSIT_WARBAND` and `L.TIP_DEPOSIT_WARBAND` in `GameTooltip`;
    - the reagents box's `OnEnter` gives `L.TIP_DEPOSIT_REAGENTS`.
    - Use the tooltip fake as `spec/sectionactions_spec.lua` does.
  - Re-point every existing Deposit warbound test to the moved button. The click behaviour, refusals and answers are unchanged, and those tests must pass untouched apart from where they find the button.
  - At least 6 new tests.

- [ ] **Step 2: Run them**: `luajit spec/runner.lua spec/bankwindow_spec.lua spec/bankwindow_groups_spec.lua`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - Create the three controls on `child` (not `frame`). Place them in `cfg.onHeaders`:
    - find the `warband` entry;
    - when it exists and `BW.DepositControlsShown()`, set `depositButton`'s `TOPRIGHT` to `child`'s `TOPRIGHT` at (`-GV.PAD`, `entry.y - 2`), and chain the label and box to its left as today;
    - otherwise hide all three.
  - `BW.DepositControlsShown()` is `child:GetWidth() - 2*GV.PAD >= BW.DEPOSIT_W + BW.HEADER_LABEL_MIN` and the reagents box follows `RefreshReagents` (a hidden box stays hidden).
  - `cfg.groupInset` returns `BW.DEPOSIT_W` for `"warband"` while the controls show, otherwise 0.
  - Remove the row-3 anchors (`frame.deposit:SetPoint("RIGHT", BW.reagentsBox, ...)`): the deposit line now runs to the frame's right edge, at `-8`.
  - Tooltips go through `Guard("bank.depositTip", ...)`, with the title in the button's own text and the body wrapped.
  - Strings (exact):
    - `L.TIP_DEPOSIT_WARBAND = "Moves every warbound item in your bags into the Warband bank, whichever tab is selected. It uses Blizzard's own deposit."`
    - `L.TIP_DEPOSIT_REAGENTS = "Blizzard's own setting: Deposit warbound takes reagents too. Right-click deposits don't change."`
    - In `L.DEPOSIT_REFUNDABLE`, `L.DEPOSIT_UNSURE` and `L.DEPOSIT_REAGENTS_FAILED`, replace `click Blizzard bank` with `open ... and pick Show Blizzard's bank`. Task 5 makes that entry real; until then the words describe the next task's menu, which is accepted (the branch ships whole).

- [ ] **Step 4: Run the gate**: `scripts/check.sh`. Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Week 13 Task 2: Deposit warbound and With reagents on the Warband bank's header`.

---

### Task 3: The deposit bar: Blizzard's tabs in the header, the bags title and the item tooltip say where right-click goes

**Files:**
- Modify: `SwagBag/UI/BankWindow.lua` (`placeTabs` 194-196, `RefreshTarget` 167-175, `HEADER` 34, `sizeFrame` 347-358, `OnBankClosed` 785-790, `groupLabel` 373-379)
- Modify: `SwagBag/UI/BagsWindow.lua` (`W.Title` 138-150, one `SB.On("SB_BANK_TARGET", ...)` listener)
- Modify: `SwagBag/Locale/enUS.lua`
- Test: `spec/bankwindow_spec.lua`, `spec/tinyhost_spec.lua` (only if it pins the old anchor), `spec/bagswindow_spec.lua`, `spec/tooltip_spec.lua`

**Interfaces:**
- Produces:
  - `BW.BarText() -> text`: what the bar label shows.
  - `frame.deposit`: the same FontString, now the bar label.
  - `BW.MIN_WIDTH = 440`.
  - `BW.HEADER = 90`: title, search and the bar row, which is tall enough for Blizzard's tab buttons. In-game check V13-1 confirms both numbers.
  - `BW.TabsInHeader() -> bool`: true while the visit is tiny and the TabSystem is re-hosted.
  - `BW.DepositTooltipLine(tooltip, itemID)`, hooked once at load through `SB.Adapter.HookItemTooltip(Guard("tooltip.deposit", ..., "none"))`.
  - `SB_BANK_TARGET` is now also emitted with `nil` from `BW.OnBankClosed()`.
- Produces in BagsWindow: `W.bankTarget` (`"bank" | "warband" | nil`).

- [ ] **Step 1: Write the failing tests.**
  - `it("Blizzard's tabs sit in the header after the bar's words")`:
    - after a tiny open, the TabSystem's parent is the frame and its first point is `LEFT` on `frame.deposit`'s `RIGHT`, at x 6;
    - after the visit closes, its parent and points are Blizzard's again.
    - Mutation: the old `BOTTOMLEFT` anchor.
  - `it("the bar reads the plain words in tiny mode")`: `frame.deposit:GetText() == L.BANK_DEPOSIT_BAR`, for target `bank` and for target `warband`.
  - `it("beside names the target and where the tabs are")`: with `bank.blizzardFrame = "beside"`, the text equals `L.BANK_DEPOSIT_BESIDE:format(L.BANK_GROUP_WARBAND)`.
  - `it("beside with no target asks to pick")`: `A.activeBankType = nil` gives `L.BANK_DEPOSIT_PICK`. Never `""`. Mutation: the old blank text.
  - `it("a visit started in combat shows the beside line")`: `A.combat = true` at `BANKFRAME_OPENED` gives the beside line, and `BW.TabsInHeader()` is false.
  - `it("the window keeps its minimum width")`: with `bank.columns = 4`, `frame:GetWidth() >= BW.MIN_WIDTH`.
  - `it("the bar's tooltip explains the two tabs")`: `OnEnter` on the bar's hit frame shows `L.TIP_DEPOSIT_BAR_TITLE` and `L.TIP_DEPOSIT_BAR`.
  - `it("the target group says right-clicked items land there")`: its label ends with `L.BANK_GROUP_TARGET`.
  - `it("the bags title says where right-click goes at the bank")`:
    - in bagswindow_spec, emit `SB_BANK_TARGET` with `"warband"`, and `W.Title()` equals `L.BAGS_TITLE_BANK:format(L.BANK_GROUP_WARBAND)`;
    - emit `nil`, and the usual title comes back.
    - Mutation: no listener.
  - `it("closing the bank clears the bags title")`: `BANKFRAME_CLOSED` emits `SB_BANK_TARGET` with nil, and `W.bankTarget` is nil.
  - `it("a bag item's tooltip names the right-click bank")`:
    - in tooltip_spec, at the bank with target warband, hovering a pool button of bag 0 adds `L.TIP_RIGHT_CLICK_DEPOSIT:format(L.BANK_GROUP_WARBAND)`;
    - with `A.AllowedInBank` returning false, it adds `L.TIP_RIGHT_CLICK_REFUSED:format(L.BANK_GROUP_WARBAND)` instead.
  - `it("no right-click line away from the bank, over a bank item, or with no target")`: three asserts.
  - At least 12 new tests.

- [ ] **Step 2: Run them.** Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - **Tabs:**
    - `placeTabs(ts)`: `ts:SetPoint("LEFT", frame.deposit, "RIGHT", 6, 0)`.
    - `frame.deposit` sits at `TOPLEFT 14, -62`, and has no right anchor while the tabs are in the header (its text is short).
    - In beside or forced-beside it runs to `TOPRIGHT -8` and may wrap to one line (`SetWordWrap(false)`, cut with "..." as the title is).
  - **Hit frame:** a plain `Frame` over `frame.deposit`, with `EnableMouse(true)`, carries the bar tooltip. It must not cover the tabs: it is anchored to the label's own bounds.
  - **`BW.BarText()`:**
    - tiny with tabs in the header: `L.BANK_DEPOSIT_BAR`;
    - otherwise target known: `L.BANK_DEPOSIT_BESIDE:format(groupName(target))`;
    - otherwise: `L.BANK_DEPOSIT_PICK`.
    - `RefreshTarget` sets it.
  - **Sizes:** `sizeFrame` uses `math.max(width + 8, BW.MIN_WIDTH)` for the frame width (the child keeps the content width). `BW.HEADER = 90`. The column bar moves with `BW.HEADER` (already relative).
  - **Tooltip line:** `BW.DepositTooltipLine`:
    - only while `BW.interaction`, `BW.target ~= nil`, and bank Safe Mode is off;
    - the owner is `tooltip:GetOwner()`; continue only when `owner:GetParent()` has `GetID`, and the bag `owner:GetParent():GetID()` is of kind `"bags"` (`SB.Buttons.KindOf`), and `SB.Buttons.Get(bag, owner:GetID()) == owner`;
    - then `A.AllowedInBank(bag, slot, BW.target) == false` gives the refused line, anything else the deposit line, through `A.TooltipLine`.
  - **Bags title:** `SB.On("SB_BANK_TARGET", function(_, target) W.bankTarget = target; W.RefreshTitle() end, "bags")`. While `W.bankTarget` is set, `W.Title()` returns `L.BAGS_TITLE_BANK:format(...)`, ahead of mode and ilvl. Look up the name through `L.BANK_GROUP_BANK/WARBAND`; BagsWindow loads before BankWindow, so do not call `SB.BankWindow` at load.
  - **Strings** (exact; remove `L.BANK_DEPOSITS_TO`):
    - `L.BANK_DEPOSIT_BAR = "Right-click deposits to:"`
    - `L.BANK_DEPOSIT_BESIDE = "Right-click deposits to: %s - switch with the tabs on Blizzard's bank"`
    - `L.BANK_DEPOSIT_PICK = "Right-click deposits: pick Bank or Warband Bank on Blizzard's bank"`
    - `L.TIP_DEPOSIT_BAR_TITLE = "Where right-click deposits go"`
    - `L.TIP_DEPOSIT_BAR = "Right-clicking an item in your bags puts it in the bank whose tab is selected. Bank is your Character bank (this character only). Warband Bank is shared by all your characters. Deposit warbound and Send all pick their own bank."`
    - `L.BANK_GROUP_TARGET = "  - right-clicked items land here"`
    - `L.BAGS_TITLE_BANK = "SwagBag — right-click to %s"`
    - `L.TIP_RIGHT_CLICK_DEPOSIT = "Right-click: into your %s"`
    - `L.TIP_RIGHT_CLICK_REFUSED = "Right-click: your %s won't take this"`

- [ ] **Step 4: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Week 13 Task 3: the deposit bar: Blizzard's tabs in the header; bags title and item tooltip name the target`.

---

### Task 4: One bank at a time, following the selected tab ("Both banks" in Settings)

**Files:**
- Modify: `SwagBag/UI/BankWindow.lua` (GroupView cfg; `RefreshTarget`; `OnHide`; `searchBox` setup; slash `bank`)
- Modify: `SwagBag/Core/Config.lua` (defaults line 41: `show = "one"`), `SwagBag/Engine/Profiles.lua` (keys and labels), `SwagBag/UI/SettingsPages.lua` (`bankRows`), `SwagBag/Locale/enUS.lua`
- Test: `spec/bankwindow_groups_spec.lua`, `spec/settings_spec.lua`, `spec/profiles_spec.lua`, `spec/slash_spec.lua` (or wherever `/swagbag bank` is tested)

**Interfaces:**
- Consumes `cfg.groupClosed`, `cfg.toggleGroup` and `cfg.groupTip` (Task 1), and `BW.target` (Task 3).
- Produces:
  - `BW.Show() -> "one" | "both"` (the setting, with anything else read as `"one"`).
  - `BW.peek`: `{ [gid] = true }`, the group whose default fold the player flipped this target. It is in memory only, and cleared when the target changes and on close.
  - `BW.Folded(gid) -> true | false | nil`:
    - in "one" mode with a known target: `(gid ~= BW.target) ~= (BW.peek[gid] == true)`;
    - in "both" mode or with no target: `nil`, so the saved set decides.
  - `BW.found`: `{ bank = n, warband = n }` while a search is active, else nil.
  - `/swagbag bank one|both`.

- [ ] **Step 1: Write the failing tests.**
  - `it("only the bank you deposit into is open")`:
    - target `bank`: the bank cells are shown and every warband cell is hidden;
    - the warband header reads `L.BANK_GROUP_LABEL:format("+", L.BANK_GROUP_WARBAND, 2) .. L.BANK_GROUP_FOLDED`.
    - Mutation: `groupClosed` returning nil.
  - `it("switching the tab switches the open bank")`:
    - set `A.activeBankType = "warband"`, fire the tab's `OnClick` and `A.Advance(0)`;
    - the warband cells are shown and the bank's are hidden.
  - `it("a target switch under the mouse waits")`:
    - mark a bank button that would hide as mouse-over, then switch the target;
    - the cells stay; after the mouse leaves and `A.Advance(0.3)`, the fold lands.
    - Mutation: calling `v.Layout` instead of `Restack`.
  - `it("clicking the folded bank shows it until the tab changes")`:
    - a header click opens warband with bank still open;
    - the saved set is unchanged;
    - after a tab switch and back, warband is folded again.
  - `it("clicking the open bank folds it")`.
  - `it("no known target shows both banks")`: `A.activeBankType = nil` gives both open and neither tinted. Mutation: folding the non-nil comparison.
  - `it("Both banks brings back today's layout")`: `bank.show = "both"` gives both open, and the saved fold of warband is respected.
  - `it("one-bank folds never touch the saved collapse set")`:
    - with saved `warband = true` in "one" mode and target warband, warband is open (the target wins);
    - switch to "both", and warband is folded again from the saved set;
    - `ui.collapsed["bank:#"]` is identical before and after.
  - `it("a search counts matches hidden in the folded bank")`:
    - search for the ORE fixture with target bank;
    - the warband header ends with `L.BANK_GROUP_FOUND:format(1)`, and nothing unfolds;
    - clearing the search removes the count.
  - `it("group headers explain the two banks")`:
    - hovering the warband header shows `L.BANK_GROUP_WARBAND`, `L.TIP_GROUP_WARBAND` and `L.TIP_GROUP_CLICK_SHOW` while it is folded;
    - the bank header shows `L.TIP_GROUP_BANK` and `L.TIP_GROUP_CLICK_HIDE` while it is open.
  - `it("/swagbag bank one and both save and answer")`: they return `L.BANK_SHOW_ONE` / `L.BANK_SHOW_BOTH`, and an open window restacks. A read-only DB returns `L.SETTINGS_READONLY`.
  - `it("Settings > Bank & guild has the choice")`: the row `L.SET_BANK_SHOW` with `L.SET_BANK_SHOW_ONE` / `L.SET_BANK_SHOW_BOTH`, applied through `run("bank one|both")`.
  - `it("bank.show travels in share strings")`: export, then import, round-trips `"both"`, and `"sideways"` is refused by the key's `words`.
  - At least 13 new tests.

- [ ] **Step 2: Run them.** Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - **GroupView cfg hooks:**
    - `cfg.groupClosed = BW.Folded`.
    - `cfg.toggleGroup(gid)`: returns false unless `BW.Folded(gid) ~= nil`; then it flips `BW.peek[gid]` and returns true.
    - `cfg.groupTip` builds the tooltip from the strings below, wrapped in `Guard("bank.groupTip", ...)`.
  - **Group label:**
    - a group folded by `BW.Folded` adds `L.BANK_GROUP_FOLDED`, plus `L.BANK_GROUP_FOUND:format(n)` when `BW.found` has n > 0 for it;
    - the target keeps `L.BANK_GROUP_TARGET`;
    - the `+`/`-` sign follows the drawn fold.
  - **`RefreshTarget`:** when the target changed, clear `BW.peek` and call `BW.view.Restack()` instead of `Relabel()`. Restack redraws the headers too, and holds under the mouse.
  - **`OnHide`:** clears `BW.peek`.
  - **`BW.ApplySearch()`** replaces the window's direct `searchBox.Apply()` calls:
    - it counts, per group, records whose `setDimmed(button, false)` was called while `searchBox.search.IsActive()` (wrap `setDimmed` and `forEachSlot`; `ForEachSlot` already visits folded cells);
    - it stores `BW.found`, and calls `BW.view.Relabel()` only when a folded group's count changed.
  - **Slash `bank`:** accepts `one` and `both` (set `bank.show`, restack an open window, answer). The tiny/beside words stay as they are until Task 6.
  - **Strings** (exact):
    - `L.BANK_GROUP_FOLDED = "  - click to show"`
    - `L.BANK_GROUP_FOUND = "  - %d found"`
    - `L.TIP_GROUP_BANK = "This character's own bank."`
    - `L.TIP_GROUP_WARBAND = "Shared by all your characters."`
    - `L.TIP_GROUP_CLICK_SHOW = "Click to show it here until you switch tabs."`
    - `L.TIP_GROUP_CLICK_HIDE = "Click to fold it."`
    - `L.SET_BANK_SHOW = "SwagBag's bank window shows"`
    - `L.SET_BANK_SHOW_ONE = "The bank you deposit into"`
    - `L.SET_BANK_SHOW_BOTH = "Both banks"`
    - `L.BANK_SHOW_ONE = "Bank: SwagBag's bank window shows the bank you deposit into; the other folds to one line."`
    - `L.BANK_SHOW_BOTH = "Bank: SwagBag's bank window shows both banks."`

- [ ] **Step 4: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Week 13 Task 4: one bank at a time, following the selected tab; Both banks in Settings`.

---

### Task 5: A slim header: Sort, "..." and close; every other action in the "..." menu

**Files:**
- Create: `SwagBag/UI/BankMenu.lua` (`SB.BankMenu`); add it to `SwagBag/SwagBag.toc` right after `UI/BankWindow.lua`
- Modify: `SwagBag/UI/BankWindow.lua` (the title buttons, lines 266-269 and 523-544; `ToggleView` 505-515; `stillOpenButton` 719-739)
- Modify: `SwagBag/Locale/enUS.lua`
- Test: `spec/bankmenu_spec.lua` (new), `spec/bankwindow_spec.lua`, `spec/bankwindow_list_spec.lua`

**Interfaces:**
- Consumes `BW.Sort(kind)`, `BW.Reflow(reason)`, `BW.ToggleVisit()`, `BW.VisitMode()`, `BW.DepositWarband()`, `BW.target`, `BW.Flash`, `SB.SettingsWindow.Show("bank")`.
- Produces in BankWindow:
  - `BW.sortButton` (`L.BTN_SORT`, width 52): sorts `BW.SortKind()`.
  - `BW.SortKind() -> "bank" | "warband"`: `BW.target or "bank"`.
  - `BW.moreButton` (text `"..."`, width 30): toggles the menu.
  - `BW.SetView(view)`: saves `bank.view`, answers with `VIEW_FLASH`, and calls `RequestLayout("view")`. It replaces `BW.ToggleView`; remove `ToggleView` and its button.
- Produces in BankMenu:
  - `SB.BankMenu.Entries() -> { { text, tip, run } }` in display order.
  - `SB.BankMenu.Toggle(anchor) -> bool` (shown after the call).
  - `SB.BankMenu.Hide()`.
  - `SB.BankMenu.frame` (named `SwagBagBankMenu`, in `UISpecialFrames`).
  - The entries, in order:
    1. three view rows (the current one named with `L.BANK_MENU_NOW`);
    2. `Sort` Character bank;
    3. `Sort` Warband bank;
    4. Regroup now;
    5. Show/Hide Blizzard's bank (by `BW.VisitMode()`);
    6. Deposit all warbound items;
    7. Bank settings...

- [ ] **Step 1: Write the failing tests** (`spec/bankmenu_spec.lua` loads the bank as `bankwindow_spec.lua` does).
  - `it("the title row has only Sort, ... and close")`:
    - `BW.sortBankButton`, `sortWarbandButton`, `reflowButton`, `viewButton` and `blizzardButton` are nil;
    - `BW.sortButton` and `BW.moreButton` exist, and are shown with the window.
    - Mutation: leaving any old button.
  - `it("Sort sorts the bank you deposit into")`:
    - target warband: the click calls `A.SortBank` with `"warband"`;
    - target nil: it calls it with `"bank"`.
  - `it("Sort's tooltip names that bank")`: it shows `L.TIP_BANK_SORT:format(L.BANK_GROUP_WARBAND)`.
  - `it("... opens and closes the menu")`: two clicks give shown, then hidden. Esc hides it (the frame name is in `UISpecialFrames`).
  - `it("the menu lists every bank action in order")`: `Entries()` texts equal, in order:
    - `L.BANK_MENU_VIEW:format(L.BANK_MENU_NOW:format(L.BANK_MENU_VIEW_SECTIONS))`
    - `L.BANK_MENU_VIEW:format(L.BANK_MENU_VIEW_LIST)`
    - `L.BANK_MENU_VIEW:format(L.BANK_MENU_VIEW_GRID)`
    - `L.BANK_MENU_SORT:format(L.BANK_GROUP_BANK)`
    - `L.BANK_MENU_SORT:format(L.BANK_GROUP_WARBAND)`
    - `L.BANK_MENU_REGROUP`
    - `L.BANK_MENU_SHOW_BLIZZARD`
    - `L.BANK_MENU_DEPOSIT`
    - `L.BANK_MENU_SETTINGS`
  - `it("picking a view saves it, answers once and hides the menu")`: List gives `bank.view == "list"`, the title is `L.BANK_VIEW_LIST`, and the menu is hidden.
  - `it("each menu entry runs its action")`: sort either bank, regroup (flash `L.REFLOW_DONE`), deposit (refusal paths unchanged), settings (`SB.SettingsWindow.Show` called with `"bank"`).
  - `it("Blizzard's bank entry flips its words")`: after it runs, the entry reads `L.BANK_MENU_HIDE_BLIZZARD`.
  - `it("Blizzard's bank entry refuses in combat")`: `A.combat = true` flashes `L.BANK_NOT_IN_COMBAT` and the mode is unchanged.
  - `it("every menu row has a tooltip")`: each entry has a non-empty `tip` that is an `L` value.
  - `it("the menu closes with the bank")`: `BANKFRAME_CLOSED` and the window's `OnHide` both hide it.
  - `it("Show bank brings the window back")`: `L.BANK_STILL_OPEN == "Show bank"`, and the button still calls `BW.Open`.
  - Re-point the existing tests of the removed buttons to `BW.Sort/Reflow/ToggleVisit/SetView` or to the menu entries, and list any removals in the report (see Global Constraints).
  - At least 12 new tests.

- [ ] **Step 2: Run them.** Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - **Title row:** `BW.moreButton` at `TOPRIGHT -26, -5`, then `BW.sortButton` left of it. The title's `RIGHT` anchors to `BW.sortButton`'s `LEFT` (W3-26 kept).
  - **Tooltips:**
    - Sort: title `L.BTN_SORT`, body `L.TIP_BANK_SORT:format(groupName(BW.SortKind()))`.
    - "...": `L.TIP_BANK_MORE`.
    - Both go through `Guard`.
  - **Menu frame:** a plain `BackdropTemplate` frame at `DIALOG` strata, `SB.Theme.Window(f, "dialog")`, with one `UIPanelButtonTemplate` row per entry (width 260, row 22).
    - A row's click hides the menu, then runs the entry under `Guard("bank.menuEntry", ..., "bank")`.
    - A row's `OnEnter` shows its `tip`.
    - It is anchored `TOPRIGHT` to `BW.moreButton`'s `BOTTOMRIGHT`.
    - The rows are rebuilt from `Entries()` at every open, so the view mark and the Blizzard words are current.
  - **The rename:** `L.BANK_STILL_OPEN = "Show bank"`, and the button width is 80.
  - **Strings** (exact; remove `L.BTN_BLIZZARD_BANK`, `L.BTN_SORT_BANK` and `L.BTN_SORT_WARBAND` if nothing else uses them, checked by grep):
    - `L.TIP_BANK_SORT = "Sorts your %s (the bank you deposit into). The ... menu sorts either bank."`
    - `L.TIP_BANK_MORE = "More: the view, sorting either bank, regroup, Blizzard's bank, Deposit warbound and settings."`
    - `L.BANK_MENU_VIEW = "View: %s"`
    - `L.BANK_MENU_NOW = "%s (now)"`
    - `L.BANK_MENU_VIEW_SECTIONS = "Categories"`
    - `L.BANK_MENU_VIEW_LIST = "List"`
    - `L.BANK_MENU_VIEW_GRID = "Grid"`
    - `L.BANK_MENU_SORT = "Sort %s"`
    - `L.BANK_MENU_REGROUP = "Regroup now"`
    - `L.BANK_MENU_SHOW_BLIZZARD = "Show Blizzard's bank (buy tabs, gold)"`
    - `L.BANK_MENU_HIDE_BLIZZARD = "Hide Blizzard's bank"`
    - `L.BANK_MENU_DEPOSIT = "Deposit all warbound items"`
    - `L.BANK_MENU_SETTINGS = "Bank settings..."`
    - `L.TIP_MENU_VIEW = "How the bank's items are drawn: in category sections, as a list with prices, or in tab order."`
    - `L.TIP_MENU_SORT = "Blizzard's sort for that bank (or SwagBag's partial-stacks-first sort if you chose it in Settings > Bags)."`
    - `L.TIP_MENU_REGROUP = "Puts items that arrived or moved into their sections now. This also happens by itself when you close the bank."`
    - `L.TIP_MENU_BLIZZARD = "Opens Blizzard's own bank next to this one: buy tabs, tab settings, warband gold. SwagBag's window moves beside it."`
    - `L.TIP_MENU_DEPOSIT = "The same as the Deposit warbound button on the Warband bank's header."`
    - `L.TIP_MENU_SETTINGS = "Settings > Bank & guild: which banks show, Blizzard's bank, the gold glow, prices."`

- [ ] **Step 4: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Week 13 Task 5: slim bank header (Sort, ..., close) and the ... menu; tooltips; Show bank`.

---

### Task 6: Plain words for the modes; the spec and the in-game checks

**Files:**
- Modify: `SwagBag/UI/BankWindow.lua` (slash `bank`; header comment lines 1-22), `SwagBag/Locale/enUS.lua` (`HELP_BANK`, `BANK_USAGE`, `BANK_MODE_TINY`, `BANK_MODE_BESIDE`, `SET_BANK_NOTE`), `SwagBag/UI/SettingsPages.lua` (only if a label key changes)
- Modify: `docs/superpowers/specs/2026-09-30-swagbag-design.md` (§5.1, §5.4, AC2.8, and a v1.3 change-log line)
- Create: `docs/superpowers/plans/2026-10-12-swagbag-week13-checklists.md`
- Test: `spec/bankwindow_spec.lua` (slash tests), `spec/locale_spec.lua` (unchanged, must stay green)

**Interfaces:**
- Produces `/swagbag bank hidden|shown|one|both`.
  - `tiny` and `beside` still work as aliases (old macros keep working), but appear in no help or answer text.
  - The saved values stay `"tiny"`/`"beside"`, so no migration.

- [ ] **Step 1: Write the failing tests.**
  - `it("hidden and shown set Blizzard's bank")`: they save `"tiny"`/`"beside"` and answer `L.BANK_MODE_TINY`/`L.BANK_MODE_BESIDE`.
  - `it("tiny and beside still work")`: the same results.
  - `it("the usage line uses the plain words")`:
    - `/swagbag bank` alone returns `L.BANK_USAGE:format("hidden", "one")` by default;
    - it contains neither "tiny" nor "beside".
    - Mutation: the old usage.
  - `it("help names the plain words only")`: `L.HELP_BANK` contains "hidden" and "one", and not "tiny".
  - At least 4 new tests.

- [ ] **Step 2: Run them.** Expected: the new tests FAIL.

- [ ] **Step 3: Implement the words.** Strings (exact):
  - `L.HELP_BANK = "bank hidden|shown: Blizzard's bank hidden, or shown beside SwagBag's; bank one|both: which banks SwagBag's window shows"`
  - `L.BANK_USAGE = "Use /swagbag bank hidden or shown (Blizzard's bank, now: %s), one or both (banks shown, now: %s)."`
  - `L.BANK_MODE_TINY = "Bank: Blizzard's bank is hidden; its Bank and Warband Bank tabs are at the top of SwagBag's bank window."`
  - `L.BANK_MODE_BESIDE = "Bank: Blizzard's bank is shown, with SwagBag's bank window beside it."`
  - `L.SET_BANK_NOTE`: replace its "use the Blizzard bank" wording with `"use ... > Show Blizzard's bank in SwagBag's bank window"`, keeping the rest of the sentence. The implementer reads the current two-line value and changes only that phrase.
  - Rewrite the BankWindow header comment so it describes the week-13 layout:
    - the bar row with the tabs;
    - one bank at a time;
    - the Sort / "..." title row;
    - Deposit warbound on the Warband header.

- [ ] **Step 4: Update the spec.**
  - §5.1: the window's layout as built.
  - §5.4: "hidden / shown" as the user-facing words, with tiny/beside as the stored values.
  - AC2.8: Deposit warbound lives on the Warband bank's header and in the "..." menu.
  - A change-log line: "v1.3 (week 13): bank window simplified: deposit bar, one bank at a time, slim header and menu."

- [ ] **Step 5: Write the in-game checklist** `docs/superpowers/plans/2026-10-12-swagbag-week13-checklists.md`, in the user's style:
  - "Claude installs the build first", then a full game restart;
  - numbered steps, one action each, each saying what the user should see;
  - quoted strings exactly as in enUS.lua;
  - chat lines start with `SwagBag: `.

  The sessions:
  - **V13-1 (tabs in the header, the first check):**
    - Open the bank. "Right-click deposits to:" is followed by Blizzard's "Bank" and "Warband Bank" tabs, inside the window's header, not overlapping the search box or the first group.
    - Click "Warband Bank": the tab lights up, the Warband bank opens and the Character bank folds to one line.
    - Right-click a warbound item in your bags: it lands in the Warband bank's New.
    - Click "Bank" and right-click an item: it lands in the Character bank.
    - Then `/reload`, reopen the bank, and right-click again. It still works, which means no taint.
    - If the tabs overflow or don't click: the fallback is to keep the bar text and move the tabs back under the window (one-line `placeTabs` change, ruled in the ledger).
  - **V13-2 (one bank):**
    - The folded bank's "click to show" opens it.
    - A tab switch folds it again.
    - Typing a search shows "N found" on the folded line.
    - Settings > Bank & guild > "Both banks" shows both.
  - **V13-3 (menu and header):**
    - Hover Sort, "...", Deposit warbound and the "With reagents" box: each shows a tooltip.
    - Every menu entry works.
    - Show Blizzard's bank moves SwagBag's window beside Blizzard's. The bar then reads the beside line, and Hide puts the window back.
  - **V13-4 (bags and tooltips):**
    - At the bank, the bags title reads "SwagBag — right-click to Warband bank" (or Character bank).
    - Hovering a bag item shows "Right-click: into your Warband bank".
    - Hovering a soulbound item with the Warband tab selected shows "Right-click: your Warband bank won't take this".
    - Close the bank with X: the bags show "Show bank".
  - **V13-5 (narrow and combat):**
    - `/swagbag bank` shows the plain-words usage line.
    - Set bank slots per row to 4: the window stays wide enough for the bar, and Deposit warbound moves off the header (still in the menu).
    - Enter combat (training dummy), open the bank: the bar reads the beside line, and Show Blizzard's bank answers "Leave combat first".

- [ ] **Step 6: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 7: Commit** `Week 13 Task 6: plain words for the bank modes; spec and in-game checks`.

---

## Schedule

| Task | Files (main) | New tests (at least) |
|---|---|---|
| 1 GroupView hooks, 0.13.0 | GroupView.lua | 8 |
| 2 Deposit controls on the Warband header | BankWindow.lua | 6 |
| 3 Deposit bar, bags title, tooltip line | BankWindow.lua, BagsWindow.lua | 12 |
| 4 One bank at a time | BankWindow.lua, Config, Profiles, SettingsPages | 13 |
| 5 Slim header + "..." menu | BankMenu.lua (new), BankWindow.lua | 12 |
| 6 Plain words, spec, checklist | BankWindow.lua, enUS.lua, spec | 4 |

From 1709 to at least **1764**.

## Not in this week (named so nobody adds them)

- A bank leg of `/swagbag tour`.
- Empty-state text for a bank with no tabs.
- Tab markers in Grid view.
- A drop on a bank section header that deposits instead of categorising.
- The guild bank window: unchanged.
- Bank speed part 2: waits for the TF1 numbers.
