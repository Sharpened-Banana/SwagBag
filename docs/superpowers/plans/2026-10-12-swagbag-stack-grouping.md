# SwagBag: one icon per item ("stack grouping"). Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the user saw the same item twice, as two partial stacks (45 and 7), in both the bags and the bank. They asked for this: "Show as one icon: display identical items as a single icon with the total (52), like Baganator's grouping. Your bags aren't changed; clicking uses one of the real stacks. A setting turns it off."

The feature is display-only. No item ever moves because of it.
- The largest stack is the one icon shown. Its number reads the total.
- Its tooltip lists the stacks ("2 stacks: 45 + 7") and says which one a click uses.
- The other stacks' buttons are hidden, but they stay in the layout. Every consumer that reads slots (search, totals, Sell all / Send all, overlays, the gold glow, locks, the mover, the stacker) still sees each real stack.
- When the shown stack is used up, the next stack takes its place. This waits, like every other move, until the mouse leaves and the cursor is empty (P5).

The version goes to 0.14.0 (Task 1).

**The user's principle (binding, memory `product-principle-simple-surface-deep-power`):** "out of the box as easy and simple as possible, under the hood an insane amount of customization and power."
- **Simple half:** it is on by default, in the bags and in both banks, in the category and list views.
- **Power half:**
  - Settings > Bags has the row "Same item in several stacks (bags and banks)", with the choices "One icon with the total" / "Every stack".
  - `/swagbag stacks one|all` does the same.
  - The setting is shareable in profiles.
  - The grid view is unchanged: it is the physical order.

**Architecture:**
- **New pure file `Engine/Stacks.lua` (`SB.Stacks`).** It holds:
  - the merge key (`Stacks.Key`);
  - the totals used to sort the list (`Stacks.Totals`);
  - the number's text (`Stacks.CountText`);
  - the tooltip line (`Stacks.Line`);
  - a stack's counts from records (`Stacks.Of`);
  - the setting (`Stacks.Enabled`).
- **`Engine/Layout.lua` learns hidden stack members, mirroring the free tile's spares.**
  - `Build` takes `opts.stackKey`. Inside one category section, a second stack with the same key becomes a member of the first instead of getting a cell.
  - The representative is the largest stack. Its cell sits where the group's first stack in input order sits.
  - `Position` reports members as `shown = false` with no x/y, like spares, so `Moves`, `ForEachSlot` and every slot consumer keep working. It adds `pos.stacks`.
  - `Apply` gains the member transitions. When the representative leaves, its first member takes the cell instead of a placeholder. That swap waits while either button is busy, through the existing `partner()` hold.
- **`UI/Buttons.lua`:**
  - `SetStack(button, stack)` draws the total with method calls on the template's own `Count` font string. Blizzard's `button.count` field is never written with the total.
  - `Paint` re-applies the total after Blizzard's count is drawn, and clears it on an empty slot.
  - It adds one item-tooltip post-hook (`tooltip.stacks`).
- **The windows** (`UI/BagsWindow.lua`, and `UI/GroupView.lua` for the bank, opted in through a new `cfg.stacks`) each get `paintStacks(pos)`, a twin of `paintTiles`. It runs after every render and every live repaint, and it is also where list rows get the total.
- **`Engine/Prices.SectionTotals` and `BagsWindow.SectionSlots`** add the members.
- **`Sort.DisplayOrder`** sorts a group by its total.
- **`UI/SearchBox.lua`** gets an `afterApply` hook. The windows use it to un-dim a shown stack when one of its hidden stacks matches.

**Tech Stack:**
- Lua 5.1 (WoW Retail 12.1.x, Interface 120100/120105).
- LuaJIT 2.1 for tests, with the in-repo runner `spec/runner.lua`.
- luacheck, and `scripts/check.sh` for the full gate.

**Spec:** `docs/superpowers/specs/2026-09-30-swagbag-design.md`.
- This plan adds a recorded exception to §4.2 invariant 1 ("Identity": a grouped icon's number is the total) and two rows to the §4.3 table.
- It widens AC3.4: a hidden stack of the same item may take its group's cell.
- It adds AC3.8, and one F15 settings entry.
- §4.1 is unchanged: buttons are moved with `SetPoint`, shown and hidden only.
- Task 5 updates the spec text.

**Repo root:** `/Users/lonezebra/Local Documents/AI-Projects/SwagBag` (quote it: it contains a space). Run every command from there.

**Branch:**
- Make it before Task 1: `git checkout -b stack-grouping` from `main` at `c4a2ea1` (v0.13.6, 1851 tests).
- No task creates or switches branches.
- Leave the untracked `.venv/` alone.

**Interfaces used as they are on `c4a2ea1`:**
- **Core:** `SB.On/Emit/Debounce/Print`, `SB.ErrorTrap.Guard/Run`, `SB.Slash.Register/Run`, `SB.Config.Get/Set/Defaults`.
- **Adapter:** `SB.Adapter` (`HookItemTooltip(fn)`, `TooltipLine`, `IsSecret`, `CursorBusy`, `InCombat`).
- **Engine:**
  - `SB.Items.Key(record, "instance")` (`Engine/Items.lua:177-186`);
  - `SB.Layout` (`Key`, `Build`, `Position`, `Moves`, `Apply`, `ToFamily`, `NEW`, `FREE`);
  - `SB.Sort` (`DisplayOrder`, `Value`, `Spec`);
  - `SB.Prices.SectionTotals`;
  - `SB.Inventory.IsUnseen`.
- **UI:**
  - `SB.Buttons` (`Paint`, `SetFreeCount`, `Get`, `KindOf`, `SetDimmed`);
  - `SB.ListRows` (`Texts`, `rows.Paint`);
  - `SB.SearchBox.New(o)`;
  - `SB.BagsWindow` (`ForEachSlot`, `SectionSlots`, `SetDimmed`, `RequestLayout`, `RefreshRows`);
  - `SB.GroupView.New(cfg)` (see its header);
  - `SB.BankWindow` (`view`, `ApplySearch`);
  - `SB.SectionActions` (`Sellable`, `Bankable`).
- **Test helpers:**
  - `spec/helpers/loader.lua` and `uienv.lua` (FILES list, lines 10-18);
  - `spec/mock_adapter.lua` (`m.Put(bag, slot, itemID, count, { link = ... })`, `m.combat`);
  - `spec/fixtures/items.lua` (`HERB`, `ORE`: `maxStack = 1000`; `HEALING_POTION`: 20; `BOE_RING`: 1; `KEYSTONE`; `PET_CAGE`);
  - `spec/fixtures/big.lua`;
  - the fake pools in `spec/bagswindow_sections_spec.lua:88-110` and `spec/bagswindow_list_spec.lua`.

## Global Constraints

- **Target and versions:**
  - WoW Retail 12.1.x only, TOC `## Interface: 120100, 120105`, English only.
  - Version `0.14.0` (TOC `## Version` and `SB.VERSION`, checked by `scripts/toc_check.lua`; Task 1).
  - TOC metadata is unchanged. One file is added: `Engine/Stacks.lua`, right after `Engine/Layout.lua` (TOC line 41; Task 1). It is also added to the FILES list in `spec/helpers/uienv.lua`.
- **Lua 5.1 only:** no `goto`, no `//`, no bitwise operators. `string.format("%s", v)` gets only strings or numbers.
- **Adapter rule:** `SwagBag/Core/Adapter.lua` is the only file that may name `C_*`, `Enum`, ElvUI, Syndicator, `TSM_API` or `LibStub`, comments included. **No Adapter change in this plan.**
- **Forbidden anywhere in `SwagBag/`, comments included:** `BankFrame:SetTab`, `BankFrame.SetTab`, `.bankType =`, `C_Bank.CloseBankFrame`, `CloseBankFrame(`, `OpenAllBags(`, `PurchaseBankTab`, assignments to global `_`, `PreClick`, `PostClick`.
- **Display-only, taint-free (new for this plan):**
  - Grouping never calls an item API. No item moves, splits or merges because of it.
  - A slot button is only shown, hidden and moved (`SetPoint`), as in spec §4.1. Those calls are legal in combat because the buttons report `IsProtected() == false`.
  - No secure attribute is read or set. No click script or hook is added to a slot button.
  - **No Blizzard field on a slot button is written with the total.**
    - `button.count` keeps the real stack: Blizzard's Shift-click split reads it, and only `SetItemButtonCount` from `Buttons.Paint` writes it, as today.
    - The total is drawn with `button.Count:SetText(...)` / `:Show()`, method calls on the template's font string.
    - SwagBag's own state lives in a weak side table (`Buttons.stacks`), like `Buttons.freeCounts`.
- **Plain frames only:** no frame is created for this feature. The tooltip line is a post-hook through `Adapter.HookItemTooltip`.
- **No glyphs the game font may lack:** no `⋯`, `→`, `←`, `…` in any string. The stacks line uses ` + ` (ASCII).
- **P2 (exactly one answer per click and command):**
  - `/swagbag stacks` answers every form.
  - The Settings row answers through the command it runs.
  - The windows regroup silently, through their held layouts, as `/swagbag free` does today.
- **P5 (nothing moves under the mouse or cursor):**
  - Every button that appears, hides or moves because of grouping goes through `Layout.Apply`'s existing hold: `isBusy(bag, slot)` for the button itself and for its swap partner, and `CursorBusy` for everything. Or it goes through a held full layout (`W.RequestLayout`, `v.RequestLayout`).
  - The total's text and the tooltip change in place, like any count repaint today.
  - The shown stack is chosen only at a full layout. A live change never re-chooses it, except when it leaves.
- **P6:** every entry point runs inside `SB.ErrorTrap.Guard`/`Run`. New labels:
  - `tooltip.stacks` (window `"none"`, like `tooltip.deposit`);
  - `bags.stacksChanged` (window `"bags"`) and `bank.stacksChanged` (window `"bank"`), the `SB_STACKS_CHANGED` listeners.
- **P8:** every user-visible string is in `SwagBag/Locale/enUS.lua`, with the exact copy given in the tasks. `spec/locale_spec.lua` must stay green.
- **Saved data (schema stays 2, no migration):**
  - One new setting, `bags.stacks = "one" | "all"`, default `"one"`, in `Config.Defaults.settings.bags` next to `freeTile`.
  - It is shareable through Profiles: `words("one", "all")`, label `SET_STACKS`.
  - One setting covers the bags and both banks.
- **Idle and load time:** no `OnUpdate`. No file calls `Config` at load time. Idle CPU with every window closed stays 0.
- **Performance (spec §9):**
  - Grouping costs one pass inside each full `Layout.Build`, plus one `Stacks.Totals` pass in the list view only. Live changes are O(members of the touched group).
  - `paintStacks` is O(groups).
  - The 1,290-slot build-and-position test stays under 20 ms with grouping on (Task 2).
- **Tests:**
  - Every critical test names the mutation that must make it fail; each task lists its mutations at its test step.
  - Tests run with `luajit spec/runner.lua spec/*_spec.lua`.
  - Every task ends with `scripts/check.sh` printing `ALL CHECKS PASSED`.
  - The suite starts at 1851. Each task states the minimum number of new tests.
  - **An existing test whose fixture holds two stacks of one stackable item in one section, and that pins per-slot visibility or positions, gets `SB.Config.Set("bags.stacks", "all")` in that test** (the `bags.newAlways` precedent, `spec/bagswindow_sections_spec.lua:128`). It is never deleted. The task's report lists each one.
  - Windows test for `SB.Stacks` before grouping (`SB.Stacks and SB.Stacks.Enabled()`), so spec files whose own FILES lists lack `Engine/Stacks.lua` behave as before.
- **Commits:**
  - One commit per task: `git -c user.email="lonezebra@protonmail.com" -c user.name="lonezebra" commit`.
  - The message ends with exactly:
    `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
    `Claude-Session: https://claude.ai/code/session_0118QqxrirrDAhG3ciVZpDAx`

## Review Focus

The five uncovered inputs most likely to hurt a player. Each has a test in the task named.

1. **The shown stack is sold or used up while the mouse is on it** (a vendor right-click). The emptied button stays put, nothing appears under the mouse, and the 7 takes the cell once the mouse leaves and the cursor is empty. (Task 2 "a used-up shown stack hands its cell over only when nothing is busy"; Task 3 "selling the shown stack under the mouse waits".)
2. **Shift-click split on a grouped icon.** Blizzard's split frame must offer at most the real 45, never 52: `button.count` is never the total. (Task 3 "the total never reaches Blizzard's count field".)
3. **Same itemID, different item.** Gear with another item level or bonus IDs, keystones, caged pets, bound versus unbound copies, and unseen New items never merge. (Task 1 Key tests; Task 2 "New never groups"; Task 3 "an unseen stack stays separate in New".)
4. **Sell all / Send all and section totals with hidden stacks.** They act on and count every real stack. (Task 2 "section totals count hidden stacks"; Task 3 "Sell all includes the hidden stack".)
5. **A hidden stack matches a search, the shown one does not** (`stack`, `count>40`, `reagentbag`). The icon stays lit. (Task 3 "a hidden stack's match keeps the icon lit"; Task 4 the same in the bank.)

---

### Task 1: `Engine/Stacks.lua`, the setting, `/swagbag stacks`, the Settings row; version 0.14.0

**Files:**
- Create: `SwagBag/Engine/Stacks.lua`
- Modify: `SwagBag/SwagBag.toc` (line 5 `## Version: 0.14.0`; add `Engine/Stacks.lua` after line 41), `SwagBag/Core/Init.lua:6` (`SB.VERSION = "0.14.0"`)
- Modify: `SwagBag/Engine/Items.lua:177-186` (factor out `Items.BindSuffix`, no behaviour change)
- Modify: `SwagBag/Core/Config.lua:20-29` (default and comment), `SwagBag/Engine/Profiles.lua:81-95` (VALID), `:104-106` (LABELS)
- Modify: `SwagBag/Core/Commands.lua:96-107` (add `stacks` after `free`), `SwagBag/UI/SettingsPages.lua:81-85` (a row after "Free slots")
- Modify: `SwagBag/Locale/enUS.lua` (after the `FREE_*` lines 332-335 and the `SET_FREE*` lines 485-487)
- Modify: `spec/helpers/uienv.lua:10-18` (add `"SwagBag/Engine/Stacks.lua"` after Layout)
- Test: `spec/stacks_spec.lua` (new), `spec/commands_spec.lua`, `spec/settings_spec.lua`, `spec/profiles_spec.lua`

**Interfaces:**
- Produces `SB.Stacks`:
  - `Stacks.Key(record) -> string | nil`: nil unless all of these hold:
    - `record` is not `pending`;
    - `maxStack > 1`;
    - not `isKeystone` and not `isCagedPet`;
    - neither `link` nor `itemID` is secret (`Adapter.IsSecret`).
    - Otherwise the key is the normalised item string, then `Items.BindSuffix(record)`. To normalise:
      - take the `item:...` part of the link (`link:match("|H(item:[^|]+)|h")`, or the link itself when it starts with `item:`; `tostring(itemID)` when there is no link);
      - blank its 10th and 11th colon fields (linkLevel and specializationID, which describe the viewer, not the item).
  - `Stacks.Totals(slots, keyOf) -> { [key] = count }`: `keyOf(s)` returns a key or nil, and nil slots are skipped.
  - `Stacks.CountText(n) -> string`: `tostring(n)` up to 9999, else `math.floor(n / 1000) .. "k"`.
  - `Stacks.Line(counts) -> string`: `L.STACKS_TIP:format(#counts, list)`. `list` is the counts joined by `" + "`. With more than `Stacks.MAX_LISTED = 6` counts it lists the first 5, then `" + "` and `L.STACKS_TIP_MORE:format(#counts - 5)`.
  - `Stacks.Of(entry, recordOf) -> { total, counts } | nil`:
    - `entry` is a `pos.stacks` entry `{ bag, slot, members = { { bag, slot } } }`;
    - `counts` has the shown stack's count first, then each member that has a record, in order;
    - it is nil when the shown stack has no record or fewer than 2 counts remain.
  - `Stacks.Enabled() -> bool`: `Config.Get("bags.stacks") == "one"`.
- Produces `Items.BindSuffix(record) -> "#b" | "#uw" | "#?" | "#u"`. `Items.Key` uses it, and its output is unchanged.
- Produces the setting `bags.stacks` and the command `/swagbag stacks one|all`. The command emits `SB_STACKS_CHANGED`. Listeners come in Tasks 3 and 4.

- [ ] **Step 1: Write the failing tests.**
  - `spec/stacks_spec.lua` (loads Items, Layout, Stacks over the mock adapter and `Fixtures.Install`):
    - `it("two stacks of a trade good share a key")`: two `HERB` records with the same link give equal non-nil keys.
    - `it("a link that differs only in the viewer's level and spec still merges")`: `item:H::::::::70:250::...` and `item:H::::::::80:62::...` give the same key. Mutation: not blanking fields 10-11.
    - `it("other bonus IDs never merge")`: the same itemID with bonus lists `1:9001` and `1:9002` gives different keys. Mutation: keying on itemID only.
    - `it("gear, keystones and caged pets never group")`: `BOE_RING` (maxStack 1), `KEYSTONE` and a `battlepet:` link all give nil. Mutation: dropping the maxStack test.
    - `it("a pending item never groups")`: `pending = true` gives nil.
    - `it("bound and unbound copies stay apart")`: `isBound` true and false give different keys.
    - `it("a secret link never becomes a key")`: with `m.secret[link] = true` (use the mock's secret switch), it gives nil.
    - `it("no link falls back to the itemID")`.
    - `it("CountText shows 4 digits, then thousands")`: 52 gives "52", 9999 gives "9999", 12345 gives "12k".
    - `it("Line lists the stacks")`: `{45, 7}` gives `"2 stacks: 45 + 7"`; 8 counts give `"8 stacks: a + b + c + d + e + 3 more"`.
    - `it("Of totals a shown stack and its members")`:
      - records 45 and 7 give `{ total = 52, counts = {45, 7} }`;
      - with the shown stack's record nil it gives nil;
      - with the member's record nil it gives nil (fewer than 2).
    - `it("Totals sums by key and skips nil keys")`.
  - `spec/commands_spec.lua`:
    - `it("stacks one|all sets the setting and answers")`: it saves the value, returns `L.STACKS_MODE_ONE` / `L.STACKS_MODE_ALL`, and emits `SB_STACKS_CHANGED` once.
    - `it("stacks with no word gives the usage")`: it returns `L.STACKS_USAGE:format("one")` by default.
    - `it("stacks refuses while read-only")`: it returns `L.SETTINGS_READONLY`.
  - `spec/settings_spec.lua`: `it("the stacks row runs /swagbag stacks")`. Choosing "Every stack" runs `stacks all`, and the status line shows `L.STACKS_MODE_ALL`.
  - `spec/profiles_spec.lua`: `it("bags.stacks is shareable and checked")`. "one" and "all" are accepted, "some" is refused, and the label is `L.SET_STACKS`.
  - At least 16 new tests.

- [ ] **Step 2: Run them and see them fail**: `luajit spec/runner.lua spec/stacks_spec.lua spec/commands_spec.lua spec/settings_spec.lua spec/profiles_spec.lua`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - `Engine/Stacks.lua` is pure: no frames and no `Config` at load.
  - Default: `bags = { ..., freeTile = true, newAlways = false, stacks = "one", ... }`, with a comment: `-- stacks: "one" shows several stacks of one item as one icon with the total (display only); "all" every stack.`
  - Profiles: `["bags.stacks"] = words("one", "all")` and `["bags.stacks"] = "SET_STACKS"`.
  - The command follows `free` exactly (lower-case the argument; on a bad word, the usage with the current value; `Config.Set` fails, then `L.SETTINGS_READONLY`; `SB.Emit("SB_STACKS_CHANGED")`; the answer).
  - The Settings row is `{ kind = "choice", label = L.SET_STACKS, get = get("bags.stacks"), choices = { { value = "one", text = L.SET_STACKS_ONE }, { value = "all", text = L.SET_STACKS_ALL } }, apply = function(v) return run("stacks " .. v) end }`.
  - Strings (exact):
    - `L.HELP_STACKS = "stacks one|all: show several stacks of the same item as one icon with the total (one) or every stack (all)"`
    - `L.STACKS_USAGE = "Use /swagbag stacks one or /swagbag stacks all (now: %s)."`
    - `L.STACKS_MODE_ONE = "Stacks of the same item now show as one icon with the total. Your bags are not changed."`
    - `L.STACKS_MODE_ALL = "Every stack is shown again."`
    - `L.SET_STACKS = "Same item in several stacks (bags and banks)"`
    - `L.SET_STACKS_ONE = "One icon with the total"`
    - `L.SET_STACKS_ALL = "Every stack"`
    - `L.STACKS_TIP = "%d stacks: %s"`
    - `L.STACKS_TIP_MORE = "%d more"`
    - `L.STACKS_TIP_CLICK = "Clicks use the stack of %d"`
  - Bump the version in the TOC and `SB.VERSION`. Add the TOC line and the uienv FILES entry.

- [ ] **Step 4: Run the gate**: `scripts/check.sh`. Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Stack grouping Task 1: Engine/Stacks, the stacks setting and command; 0.14.0`.

---

### Task 2: Layout groups stacks (Build, Position, Apply); section totals and list order count every stack

**Files:**
- Modify: `SwagBag/Engine/Layout.lua`:
  - header comment (lines 1-73: add the stacks paragraph);
  - `Build` 190-233;
  - `Position` 246-317;
  - `take` 334-351;
  - `applyTile` 379-437;
  - `applyOne` 439-507;
  - `partner` 511-521.
- Modify: `SwagBag/Engine/Prices.lua:227-245` (`SectionTotals`), `SwagBag/Engine/Sort.lua:94-141` (`rawKey`, `DisplayOrder`)
- Test: `spec/layout_spec.lua`, `spec/prices_spec.lua`, `spec/sort_spec.lua`

**Interfaces:**
- Consumes `Stacks.Key` only through the caller's `opts.stackKey`. Layout itself stays free of `SB.Stacks`.
- Produces:
  - `Layout.Build(slots, assign, order, opts)`, where `opts.stackKey(record) -> key | nil` is optional:
    - It is called once per filled slot assigned to a category section (never New, never Free).
    - The first stack of a key in a section gets the cell.
    - A later stack with a larger `record.count` (strictly) takes over that same cell, and the old one becomes a member.
    - `st.stacks = { [repKey] = { members = { key, ... } } }`: only groups with at least one member; members ordered by count, highest first (ties keep input order).
    - `st.where[memberKey] = { section = id, stackOf = repKey }`.
    - The representative's `where` is unchanged (`{ section, index }`).
  - `Layout.MembersOf(st, key) -> { key } | nil`.
  - `Layout.Position(...)`:
    - right after the representative's entry, each member gives a cell entry `{ bag, slot, shown = false, stackOf = repKey }` (in `pos.cells` and `pos.byKey`, no x/y);
    - `pos.stacks = { { bag, slot, key, members = { { bag, slot } }, shown } }` (shown is the representative's).
    - Header counts (`countButtons`) are unchanged: a group counts once.
  - `Layout.Apply` transitions (the header comment's table gets these rows):
    - **member `left`**: it leaves its group with no placeholder, then goes to Free like any emptied button (`ToFamily` with the tile, else Free's end). `moved = { key }`.
    - **member `arrived`** (another item): it leaves its group and goes to New (or Free's end with `+N more below` when New is full). `moved = { key }`.
    - **member `removed`**: it leaves its group. `moved = { key }`.
    - **representative `left` / `arrived` / `removed` with members**: the first member takes the representative's cell (shown); the rest re-point to it (`st.stacks[newRep]`, or no entry when none remain). The old representative then does what it does today, but **leaves no placeholder** (its cell is taken). `moved = { rep, member }`. With no members, it behaves exactly as today.
    - `partner(st, ch)` also returns the first member for a representative's `left` / `arrived` / `removed`, so the swap waits while either button `isBusy` (spec 4.2 rule 5).
  - `Prices.SectionTotals(state, recordOf)` adds `Layout.MembersOf(state, key)`'s records for every representative cell.
  - `Sort.DisplayOrder(slots, spec, valueOf, totalOf)`, where `totalOf(s) -> n | nil` is optional:
    - for `by = "count"` the key is `totalOf(s) or record.count`;
    - for `"value"` it is `valueOf(record) * totalOf(s) / record.count`;
    - name and ilvl are unchanged.

- [ ] **Step 1: Write the failing tests.**
  - `spec/layout_spec.lua` (the records carry `count` and a `key` field; `opts.stackKey = function(r) return r.key end`):
    - `it("two stacks of one item in a section take one cell; the larger one is shown")`:
      - (0,1) count 7 and (0,5) count 45, both key "h", section a;
      - `slotsOf(a) == { "0:5" }` at index 1;
      - `st.where[Key(0,1)] == { section = "a", stackOf = Key(0,5) }`.
      - Mutation: keeping the first stack as the representative.
    - `it("the group keeps the first stack's place in its section")`: a, then b(key x), then the two h stacks (7 first): the h cell is index 2.
    - `it("stacks in different sections never group")`: same key, sections a and b: two cells.
    - `it("New and Free never group")`: two pending or unseen records (assign nil) with the same key are both in New. Mutation: grouping in New.
    - `it("Position reports members hidden, with no position, and lists the group")`: the member's `pos.byKey` entry has `shown == false` and `x == nil`; `pos.stacks[1].members` is `{ {0,1} }`.
    - `it("collapsing and expanding never moves a member")`: `Moves(pos, posCollapsed)` contains no member key.
    - `it("a used-up shown stack hands its cell over only when nothing is busy")`:
      - `left` at the representative with `isBusy` true for it: deferred, nothing moved;
      - the next `Apply(st, {})` with `isBusy` false moves both;
      - the member is now at index 1 of a, shown;
      - there are no placeholders;
      - the old representative is in Free.
      - Mutation: not returning the member from `partner`.
    - `it("a shown stack leaving with no members left behaves as today")`: placeholder plus Free.
    - `it("a hidden stack used up goes to Free; the group shrinks")` (with and without `freeTile`): `MembersOf` is nil afterwards and the representative does not move.
    - `it("a hidden stack that gets another item goes to New")`.
    - `it("a different item arriving at the shown stack: the next stack takes the cell, the arrival goes to New")`.
    - `it("a bag removal of the shown stack promotes the next stack")`.
    - `it("three stacks: the next largest is promoted and keeps the third")`.
    - `it("the cursor holds a hidden stack's move")`: `isBusy` returns true for everything (cursor), so the member `left` is deferred.
    - `it("builds and positions the 1,290-slot fixture with stack keys in under 20 ms")`: the existing Big test with `stackKey = function(r) return r.link end` and `r.count`.
  - `spec/prices_spec.lua`: `it("section totals count hidden stacks")`. Price 10 each, stacks 45 + 7: the total is 520. Mutation: iterating cells only.
  - `spec/sort_spec.lua`:
    - `it("a group sorts by its total count")`: group 45+7 (total 52) comes before a single 50 in "count, highest first".
    - `it("a group sorts by its total value")`.
    - `it("without totalOf nothing changes")`.
  - At least 19 new tests.

- [ ] **Step 2: Run them**: `luajit spec/runner.lua spec/layout_spec.lua spec/prices_spec.lua spec/sort_spec.lua`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - In `Build`, keep a build-local `index[id][key] = { repKey, repCount, cellIndex }`. The swap replaces `sec.cells[i]`'s bag and slot and updates both `where` entries. Members are inserted by count.
  - `take()` handles `w.stackOf` by removing the key from the group's members, then returns `w, { bag, slot }`.
  - Add one local `vacate(st, key, old, ch, result)`. It is used by the four "placeholder in its cell" sites (`applyTile` left and arrived-from-a-category, `applyOne` left and arrived) and by the `removed` paths.
    - When `MembersOf(st, key)` is non-empty, it promotes the first member into `old.index` and returns the member's key.
    - Otherwise it leaves a placeholder as today (`removed`: a hole, as today).
  - Member changes are handled first in `applyOne` / `applyTile`, before the Free/New branches.
  - Every grouping change sets `st.needsReflow = true`.

- [ ] **Step 4: Run the gate**: `scripts/check.sh`. Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Stack grouping Task 2: Layout shows one cell per item; totals and list order count every stack`.

---

### Task 3: The bags window: the total on the icon, the tooltip line, list rows, Sell all, search

**Files:**
- Modify: `SwagBag/UI/Buttons.lua`: `Paint` 193-205; add `SetStack`, `StackOf` and `StackTooltipLine` after `SetFreeCount` (234-251); one `HookItemTooltip` at load.
- Modify: `SwagBag/UI/ListRows.lua`: doc 20-23; `Texts` 88-112; `R.Paint` 296-305.
- Modify: `SwagBag/UI/BagsWindow.lua`:
  - the `W` fields (17-45: `stacked = {}`, `dimmed = {}`);
  - `paintTiles` 621-642 (add `paintStacks` beside it);
  - `layoutGrid` 645-661;
  - `RefreshRows` 753-762;
  - `render` 780-795, `renderMoved` 801-825;
  - `layoutSections` 844-872;
  - `SetDimmed` 963-968;
  - `SectionSlots` 1330-1341;
  - the inventory handler 1571-1648;
  - a `SB_STACKS_CHANGED` listener beside `SB_FREE_TILE_CHANGED` (1663-1665).
- Modify: `SwagBag/UI/SearchBox.lua`: `Box.Apply` 75-89 (`o.afterApply`); the bags box 112-125.
- Test: `spec/buttons_spec.lua`, `spec/tooltip_spec.lua`, `spec/listrows_spec.lua`, `spec/bagswindow_sections_spec.lua`, `spec/bagswindow_list_spec.lua`, `spec/sectionactions_spec.lua`, `spec/searchbox_spec.lua`

**Interfaces:**
- Consumes `Stacks.Key/Totals/Of/Line/CountText/Enabled` (Task 1), and `opts.stackKey`, `pos.stacks`, `Layout.MembersOf` and `Sort.DisplayOrder(..., totalOf)` (Task 2).
- Produces:
  - `Buttons.SetStack(button, stack | nil)`:
    - `stack = { total, counts }`. It is stored in the weak table `Buttons.stacks`.
    - With a stack: `button.Count:SetText(Stacks.CountText(total))`, then `:Show()`.
    - With nil: it forgets the stack and redraws Blizzard's own number with `SetItemButtonCount(button, Buttons.realCount[button] or 0)`.
    - It is nil-safe when `button.Count` is missing (fakes).
  - `Buttons.Paint(button, info)` records `Buttons.realCount[button] = info and info.count or 0`.
    - When `info == nil` it forgets the stack.
    - Otherwise, when a stack is set, it re-applies the total's text after `SetItemButtonCount`.
  - `Buttons.StackOf(button) -> stack | nil`.
  - `Buttons.StackTooltipLine(tooltip)`, hooked as `SB.Adapter.HookItemTooltip(SB.ErrorTrap.Guard("tooltip.stacks", Buttons.StackTooltipLine, "none"))`.
    - When `tooltip:GetOwner()` has a stack, it adds `Stacks.Line(counts)` and `L.STACKS_TIP_CLICK:format(counts[1])` through `Adapter.TooltipLine`.
  - `ListRows.Texts(record, freeCount, family, total)` and `rows.Paint(button, bag, slot, record, freeCount, family, total)`:
    - with a number `total`, the Count column shows `total`;
    - Value shows `Sort.Value(record) * total / record.count`.
  - `SearchBox.New(o)` with `o.afterApply()` (optional). It runs after a successful `search.Apply`.
  - `W.stacked`, `W.dimmed`, `W.RelightStacks()`, `W.StackKey(record) -> key | nil` (nil while the setting is "all" or `SB.Stacks` is absent).
  - `W.SectionSlots(id)` includes each representative's members.

- [ ] **Step 1: Write the failing tests.**
  - `spec/buttons_spec.lua` (fake button with a fake `Count` font string; `SetItemButtonCount` as uienv's, which sets `b.count`):
    - `it("the total never reaches Blizzard's count field")`:
      - after `Paint(b, {count = 45})` and `SetStack(b, {total = 52, counts = {45, 7}})`, `b.count == 45` and `b.Count.text == "52"`;
      - after another `Paint(b, {count = 44})`, `b.count == 44` and the text is still the stack's.
      - Mutation: `SetItemButtonCount(button, total)`.
    - `it("an empty paint forgets the stack")`: `Paint(b, nil)`, then `StackOf(b) == nil`.
    - `it("clearing a stack gives back Blizzard's number")`: `SetStack(b, nil)` gives `b.count == 45` (redrawn from `realCount`).
    - `it("SetStack works in combat and writes no field on the button")`:
      - with `m.combat = true`, snapshot `pairs(b)` keys before and after;
      - the only differences are the ones `SetItemButtonCount` makes.
      - Mutation: storing `b.swagStack`.
  - `spec/tooltip_spec.lua`:
    - `it("a grouped icon's tooltip lists the stacks and says which one a click uses")`: lines `"2 stacks: 45 + 7"` and `"Clicks use the stack of 45"`.
    - `it("an ungrouped item gets no stacks line")`.
  - `spec/listrows_spec.lua`: `it("a row with a total shows it in Count and values the total")`.
  - `spec/bagswindow_sections_spec.lua` (two `HERB` stacks, 45 at (0,7) and 7 at (0,8), seen; add `B.SetStack`/`B.StackOf` to the fake pool):
    - `it("two stacks show as one icon with the total")`:
      - (0,8)'s button is hidden;
      - (0,7)'s button is shown with stack total 52;
      - the section header counts it once.
      - Mutation: `stackKey` not passed.
    - `it("every stack shows with stacks all")`: `/swagbag stacks all`, then (once the held layout runs) both are shown and no stack is set.
    - `it("the setting regroups only once the mouse leaves")`: with `scroll.mouseOver = true`, `SB_STACKS_CHANGED` changes nothing; after the mouse leaves and `Advance(0.3)` it does.
    - `it("selling the shown stack under the mouse waits")`:
      - the 45's button has `mouseOver = true`; clear (0,7) and fire the inventory change;
      - (0,8) is still hidden and the 45's button has no stack;
      - after the mouse leaves and 300 ms, (0,8) is shown at (0,7)'s old x/y, and no placeholder is drawn.
    - `it("a count change updates the total in place")`: (0,8) goes to 9, so the total is 54 and nothing moves (`placed` counts unchanged).
    - `it("an unseen stack stays separate in New")`: a third `HERB` arrives in a Free slot and goes to New, not into the group.
    - `it("the grid view never groups")`.
    - `it("ForEachSlot still visits hidden stacks")`: both keys are visited.
    - `it("Sell all includes the hidden stack")` (in `spec/sectionactions_spec.lua`): `SA.Sellable(id)` lists both (0,7) and (0,8). Mutation: `SectionSlots` iterating cells only.
    - `it("a hidden stack's match keeps the icon lit")` (in `spec/searchbox_spec.lua` or the sections spec): search `stack` (partial stacks; the 45 of 1000 matches too). Make the 45 a full stack instead (1000) and the 7 partial: the shown 1000 stays undimmed. Mutation: no `afterApply`.
    - `it("in combat a promotion still lands")`: `m.combat = true` for the "selling" path; the same result.
  - `spec/bagswindow_list_spec.lua`:
    - `it("a group is one row with the total in Count")`.
    - `it("a group sorts by its total")`: 45+7 is above a single 50 by count, highest first.
  - At least 18 new tests.

- [ ] **Step 2: Run them.** Expected: the new tests FAIL.

- [ ] **Step 3: Implement.**
  - `W.StackKey(record)`: when `SB.Stacks and SB.Stacks.Enabled()` and the view is not the grid, return `SB.Stacks.Key(record)`; otherwise nil.
  - `layoutSections` passes `stackKey = W.StackKey`.
  - In the list, it first builds `totals = SB.Stacks.Totals(slots, keyOf)`, where `keyOf(s)` is nil for an empty slot or an `Inventory.IsUnseen` one. It then passes `totalOf = function(s) return totals[keyOf(s)] end` to `DisplayOrder`.
  - `paintStacks(pos)`, the twin of `paintTiles`:
    - for each shown `pos.stacks` entry, `s = Stacks.Of(e, recordOf)`; when `s` is set, call `B.SetStack(button, s)` and, in the list, `W.rows.Paint(..., s.total)`;
    - every button in `W.stacked` that is not grouped now gets `SetStack(nil)` and its row back from its record.
    - Call it in `render`, in `renderMoved`, with nil in `layoutGrid`, at the end of `RefreshRows`, and in the inventory handler next to `paintTiles(W.pos)` (always while `W.state`, also after a rendered apply).
  - `W.SetDimmed` records `W.dimmed[button]`. `W.RelightStacks()` un-dims a shown representative when any member's button is not dimmed. The bags box gets `afterApply = W.RelightStacks`.
  - `SB.On("SB_STACKS_CHANGED", function() W.RequestLayout("stacks") end, "bags")`.
  - Existing tests over fixtures with duplicate stacks: apply the Global Constraints rule.

- [ ] **Step 4: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Stack grouping Task 3: one icon with the total in the bags, its tooltip line, list rows, Sell all and search`.

---

### Task 4: The character and warband banks group too (GroupView opt-in); the guild bank and the alt viewer stay as they are

**Files:**
- Modify: `SwagBag/UI/GroupView.lua`:
  - header doc 37-56 (the `cfg.stacks` line, and `v.PaintStacks`, `v.RelightStacks`);
  - `positionAll` 167-218 (merge `pos.stacks` into `all.stacks`, as tiles are merged);
  - `paintTiles` 472-493 (add `paintStacks` beside it);
  - `render` 495-507, `renderMoved` 523-537;
  - `build` 588-640;
  - `v.SetRecord` 970-978;
  - `v.RefreshRows` 981-990, `v.SetDimmed` 993-998;
  - `v.Clear` 1012-1031 (forget `v.stacked`, clear the stacks).
- Modify: `SwagBag/UI/BankWindow.lua`:
  - the GroupView cfg 450-545 (`stacks = function() ... end`);
  - the search box 563-587 (`afterApply`);
  - the inventory handler 980-1022 (`v.PaintStacks()` when touched);
  - a `SB_STACKS_CHANGED` listener beside 1159-1163.
- Test: `spec/groupview_spec.lua`, `spec/bankwindow_groups_spec.lua`, `spec/bankwindow_list_spec.lua`, `spec/guildbank_spec.lua`, `spec/offline_spec.lua`

**Interfaces:**
- Consumes everything from Tasks 1-3.
- Produces:
  - `cfg.stacks() -> bool`, optional, read at every build. When true, each group's `Layout.Build` gets `stackKey = SB.Stacks.Key`, and in the list `DisplayOrder` gets the group's `totalOf`. Groups never mix: one `Layout` state per group.
  - `v.PaintStacks()`, `v.RelightStacks()`, `v.stacked`.
  - The bank passes `stacks = function() return SB.Stacks ~= nil and SB.Stacks.Enabled() end`.
  - The guild bank and the alt viewer pass nothing.

- [ ] **Step 1: Write the failing tests.**
  - `spec/groupview_spec.lua`:
    - `it("a view with cfg.stacks shows one icon per item in a group")`.
    - `it("stacks never merge across groups")`: the same `HERB` in the bank (45) and in the warband (7) gives two shown icons and no stack. Mutation: one shared key index.
    - `it("a view without cfg.stacks never groups")`: the guild view's contract.
    - `it("a group header still counts every used slot")`: the bank header count includes the hidden stack.
    - `it("a withdrawn shown stack hands its cell over once the mouse leaves")`: the same as Task 3 through `v.Changes`, with `redraw`'s hold.
    - `it("hidden stacks are visited by ForEachSlot and counted in section totals")`.
  - `spec/bankwindow_groups_spec.lua`:
    - `it("the bank shows one icon with the total")`.
    - `it("stacks all shows every bank stack after a held layout")`.
    - `it("a deposit that tops up a hidden stack updates the total in place")`.
    - `it("a bank search counts and lights a hidden stack's match")`: the folded-group "n found" counts both stacks, and the shown icon is lit. Mutation: no `afterApply` on the bank box.
  - `spec/bankwindow_list_spec.lua`: `it("a bank list row shows the total")`.
  - `spec/guildbank_spec.lua`: `it("the guild bank never groups")`: two identical guild stacks are both shown, with no stack text.
  - `spec/offline_spec.lua`: `it("the alt viewer never groups")`.
  - At least 12 new tests.

- [ ] **Step 2: Run them.** Expected: the new tests FAIL.

- [ ] **Step 3: Implement**, mirroring Task 3 inside GroupView:
  - `paintStacks(pos)` uses `cfg.button`, `v.records` and `rows`, and is called wherever `paintTiles` is (render, renderMoved, the not-drawn path of `v.Changes`);
  - `v.PaintStacks()` runs it on `v.pos`;
  - `v.RefreshRows` ends with it;
  - `v.SetRecord` leaves grouped rows to `paintStacks`.
  - The bank's handler calls `v.PaintStacks()` next to `v.RefreshTotals()`.
  - Add `SB.On("SB_STACKS_CHANGED", function() if frame:IsShown() then BW.view.RequestLayout("stacks") end end, "bank")`.

- [ ] **Step 4: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit** `Stack grouping Task 4: the character and warband banks show one icon per item`.

---

### Task 5: The spec text and the in-game checks

**Files:**
- Modify: `docs/superpowers/specs/2026-09-30-swagbag-design.md`:
  - §4.2 invariant 1;
  - §4.3 table;
  - AC3.4;
  - a new AC3.8;
  - F15;
  - the v1.x change log in §2.2.
- Create: `docs/superpowers/plans/2026-10-12-swagbag-stack-grouping-checklists.md`
- Modify: `SwagBag/Engine/Layout.lua` and `SwagBag/UI/Buttons.lua` header comments, only if Tasks 2-3 left them incomplete.

- [ ] **Step 1: Update the spec.**
  - §4.2 #1, the recorded exception: "With `bags.stacks = "one"` (default, 0.14.0) the shown stack of a group draws the group's total as its number; its tooltip lists every stack and says which one a click uses. `button.count`, the split, every click and drag act on that real stack only."
  - §4.3, the new rows:
    - "The shown stack of a group leaves, gets another item, or its slot is removed": the group's next stack takes its cell (no placeholder) and the button does what the existing row says. This waits while either button is busy.
    - "A hidden stack leaves or gets another item": to Free / New as for any button; the total updates.
  - AC3.4: "... except into New or Free, or a hidden stack of the same item taking its group's cell."
  - AC3.8: one icon per item in the category and list views of the bags and both banks; the key; the grid, the guild bank and the alt viewer unchanged; New never groups; the setting and the command.
  - F15: the Bags page row.
  - Change log: "v1.4 (0.14.0): several stacks of one item show as one icon with the total (bags and banks); Settings > Bags or /swagbag stacks all turns it off."

- [ ] **Step 2: Write the checklist file** from the section below, in the user's style:
  - "Claude installs the build first", then a full game restart;
  - numbered steps, one action each, each saying what the user should see;
  - quoted strings exactly as in enUS.lua.

- [ ] **Step 3: Run the gate.** Expected: `ALL CHECKS PASSED`.

- [ ] **Step 4: Commit** `Stack grouping Task 5: spec and in-game checks`.

---

## In-game checklist (for the user)

Claude installs the build first; then restart the game fully.

- **S-1 Bags.**
  1. Put two partial stacks of one trade good in your bags (split one with Shift-click, then drop the part in an empty slot), and close and reopen the bags. You see one icon with the total (for example 52).
  2. Hover it. The tooltip shows "2 stacks: 45 + 7" and "Clicks use the stack of 45".
- **S-2 Split.** Shift-click the icon. Blizzard's split box lets you take at most 45, not 52.
- **S-3 Vendor.**
  1. At a vendor, right-click the icon. The 45 sells and the slot looks empty while your mouse stays there.
  2. Move the mouse away. The 7 appears in the same place.
- **S-4 Things that must stay apart.** Two copies of one ring with different item levels, a keystone, and two caged pets each stay separate icons.
- **S-5 New.** Loot one more of that trade good. It shows in New on its own, and after you hover it and reopen the bags it joins the group.
- **S-6 Bank.**
  1. At the bank, two stacks of one item in the Warband bank show as one icon.
  2. One stack in the Character bank and one in the Warband bank stay two icons.
- **S-7 List view.** In the list view the Count column shows the total, and "Count, highest first" puts the group where its total belongs.
- **S-8 Sell all.** Shift+right-click the section header and choose Sell all. Both stacks are sold (the chat line counts both).
- **S-9 Off switch.**
  1. `/swagbag stacks all` answers "Every stack is shown again." and the window shows both stacks once the mouse leaves the items.
  2. Settings > Bags, "Same item in several stacks (bags and banks)" > "One icon with the total" brings it back.
- **S-10 Combat.** At a training dummy, in combat, drink a potion from a grouped icon until its stack runs out. The next stack appears in its place after you move the mouse away, with no "Interface action failed" message.

## Decisions

- **Key = normalised item string + bind suffix, stackable items only (`maxStack > 1`)**: gear, keystones and pets are never stackable, and different bonus IDs, quality ranks or bind states are different items. Blanking linkLevel and specID removes viewer noise only.
- **Pending items never group**: their `maxStack` is unknown, and they are in New anyway.
- **Representative = the largest stack (ties: the first in input order), chosen only at a full layout**: clicks stay on one stable button, and nothing re-picks under the mouse.
- **The group's cell sits where its first stack in input order sits**: in sections that is the physical order; in the list it is the sorted order.
- **The list sorts groups by their total** (`Sort.DisplayOrder` `totalOf`): a "52" row must not sort below a "50". If the same item sits in two category sections, the sort uses the combined total (a known, harmless nit).
- **Category sections only. New never groups**: unseen arrivals must each be visible until hovered (AC3.3), and live arrivals land in New one by one anyway.
- **Free never groups**: the free tile already counts empty slots.
- **The grid never groups**: it is the physical order (AC3.6).
- **Bags plus both banks, never across banks**: one `Layout` state per bank group makes that structural.
- **The guild bank is excluded**: guild withdrawals are limited per stack per day, so a "52" icon would hide a cost. Other players change its slots, and its buttons are not the pool.
- **The alt viewer is excluded for now**: the user's report is the bags and the bank. It stays one `cfg.stacks` line away.
- **Right-click, drag and split act on the shown stack only, and the tooltip says so ("Clicks use the stack of 45")**: feeding the next stack would mean moving a button or changing secure state under the mouse (P5, taint). Sell all covers selling everything.
- **When the shown stack leaves, the next stack takes its cell instead of a placeholder**: the same item stays in the same place (section truth). The swap waits while either button is busy or the cursor holds anything.
- **When a hidden stack leaves, it goes to Free or New like any button**: this reuses the existing §4.3 rules. The total updates in place.
- **The section header counts icons; a bank group header counts used slots**: each says what it already said; the group count stays a capacity number.
- **The gold glow stays per real stack**: the shown stack is the largest, so it glows whenever any of its stacks would. No Overlays change.
- **Search evaluates every real stack; the shown icon is lit when any of its stacks matches**: per-slot facts (`stack`, `count`, `locked`, `reagentbag`) can differ inside a group.
- **The total is drawn on Blizzard's own `Count` font string by method calls, never through `button.count`**: Masque keeps styling it, and the split frame keeps the real maximum.
- **Totals above 9999 read "12k"**: they fit a 37 px button, like Blizzard's own cap.
- **On by default, one setting for the bags and banks, with a slash command that follows `/swagbag free`**: the user's principle and the existing pattern.
- **Windows check `SB.Stacks` before grouping**: old spec FILES lists keep working, and a load failure degrades to "every stack".

## Schedule

| Task | Files (main) | New tests (at least) |
|---|---|---|
| 1 Engine/Stacks, setting, command, 0.14.0 | Stacks.lua (new), Commands, Config, Profiles, SettingsPages | 16 |
| 2 Layout groups; totals; list order | Layout.lua, Prices.lua, Sort.lua | 19 |
| 3 Bags: icon total, tooltip, rows, Sell all, search | Buttons, ListRows, BagsWindow, SearchBox | 18 |
| 4 Banks (GroupView opt-in) | GroupView, BankWindow | 12 |
| 5 Spec and checks | design spec, checklist | 0 |

From 1851 to at least **1916**.

## Not in this plan (named so nobody adds them)

- Grouping in the guild bank or the alt viewer.
- Grouping identical non-stackable items (gear copies).
- A right-click that feeds the next stack, or any physical merge (the stacker's "Partial stacks first" sort already does that).
- Re-choosing the shown stack while the window is open.
- A per-window or per-section switch.

### Critical Files for Implementation
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/SwagBag/Engine/Layout.lua
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/SwagBag/UI/BagsWindow.lua
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/SwagBag/UI/GroupView.lua
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/SwagBag/UI/Buttons.lua
- /Users/lonezebra/Local Documents/AI-Projects/SwagBag/SwagBag/Engine/Stacks.lua (new)