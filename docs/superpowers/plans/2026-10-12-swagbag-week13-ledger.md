# SDD ledger — plan: docs/superpowers/plans/2026-10-12-swagbag-week13-bank-ux.md

Branch week13 from main a0c68f1 (v0.12.0, 1709 tests). Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md.

## Preflight scan

| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T1 -> T2 | `cfg.onHeaders(list)`, `cfg.groupInset(gid)` -> deposit controls placed on warband header | Consistent (y negative from child top; T2 offsets -2). |
| T1 -> T4 | `cfg.groupClosed`, `cfg.toggleGroup` (true => Restack only), `cfg.groupTip` -> BW.Folded / peek flip / tips | Consistent. |
| T2 -> T3 | T2 makes `frame.deposit` run to `TOPRIGHT -8`; T3 re-anchors it (no right anchor in tiny, `-8` in beside) | Sequential, consistent. |
| T2 -> T5 | T2 strings say "open ... and pick Show Blizzard's bank"; T5 entry text `Show Blizzard's bank (buy tabs, gold)` | Words match the entry's start; plan accepts the one-task gap. |
| T2 -> T5 | T5 menu "Deposit all warbound items" calls `BW.DepositWarband` (unchanged by T2) | Consistent. |
| T3 -> T4 | T3 `RefreshTarget` sets bar text, `BANK_GROUP_TARGET`; T4 swaps `Relabel()` for `Restack()` on change and adds folded suffix | Consistent. |
| T3 -> T5 | `BW.HEADER = 90`, `BW.MIN_WIDTH = 440`; T5 title row Sort + "..." | Consistent (title row unaffected by header height). |
| T4 -> T6 | Slash `bank`: T4 adds one/both, keeps `BANK_USAGE:format(BW.Mode())`; T6 changes usage to two %s and adds hidden/shown | See ruling P1. |
| T5 removes `BW.ToggleView` | other users: only GuildBankWindow/BagsWindow own their own ToggleView; bank specs re-pointed to `BW.SetView` | Consistent. |
| T1 self | tests vs hooks; guild bank unchanged test | Agrees. |
| T2 self | controls on `child` must sit above header frames | See ruling P2. |
| T3 self | `bags.bankTarget` label vs `SB.On` auto-labels | See ruling P3. |
| T4 self | count "(2)" in folded label = 2 warband fixture items (ORE, BOE_RING) | Agrees. |
| T5 self | removed-button tests re-pointed, removals listed | Agrees. |
| T6 self | usage format `("hidden", "one")` needs mapping tiny->hidden | Agrees (implementer maps). |

Ruling P1: Task 4 leaves `L.BANK_USAGE` one-%s until Task 6 rewrites it with two — keeps each task's diff to its own words — costs nothing if wrong (T6 owns the final text).
Ruling P2: Task 2's deposit button, box and label take a frame level above the warband header's (header level + 2) — header frames are acquired later in child and would eat clicks otherwise — if wrong, clicks hit the header (caught by V13-3).
Ruling P3: the bags title listener uses `SB.On`'s own guard label (`event:SB_BANK_TARGET`), not a separate `bags.bankTarget` — matches every other listener — costs only a label name in /swagbag report.

## Tasks
Task 1: implementer DONE a6031b7 (1721 tests); review: 1 Important (onHeaders unguarded in draw path)
Task 1: minor (deferred): groupTip-error test asserts nothing (assert.truthy(true))
Task 1: minor (deferred): groupTip test mutates GameTooltip.GetOwner/shown without restore
Task 1: minor (deferred): onHeaders runs before v.pos = pos (stale v.pos for callers)
Task 1: minor (deferred): guild-unchanged test's OnEnter-nil assertion is weak
Task 1: minor (deferred): groupInset larger than width not clamped
Task 1: fix round 1/5 (2 addressed, 0 open — onHeaders trapped after v.pos; groupTip test asserts; commits a6031b7..4423cf3)
Task 1: complete (commits a0c68f1..4423cf3, review clean)
Task 2: implementer DONE_WITH_CONCERNS a98aa3f (1730 tests); concerns: sizeFrame calls v.Relabel when control room changes (extra); label is a FontString of the button
Task 2: review: 1 Important (sizeFrame Relabel re-fires every resize when no warband header drawn: insetDrawn stale)
Task 2: minor (deferred): no test resizes an open window across the DEPOSIT_W+HEADER_LABEL_MIN threshold
Task 2: minor (deferred): BW.insetDrawn public field could be file-local
Task 2: minor (deferred): HEADER_LEVEL = 3 hard-codes GroupView level arithmetic
Task 2: minor (deferred): depositTip helper placed mid-file
Task 2: fix round 1/5 (2 addressed, 0 open — relabel only when warband header drawn; insetDrawn local; columns test; commits a98aa3f..3a362af)
Task 2: complete (commits 4423cf3..3a362af, review clean)
Task 3: implementer DONE_WITH_CONCERNS 8efb9e8 (1749 tests); concerns: tests written after code (stash RED), tooltip hooked at load not SB_LOGIN, BW.target not cleared on close
Task 3: review: 1 Important (plan-mandated): BANK_MODE_TINY and BankWindow.lua:4 comment still say tabs hang under the window
Task 3: Ruling: BANK_MODE_TINY stale text — Task 6 already rewrites it with exact copy ("...tabs are at the top of SwagBag's bank window") and rewrites the header comment; fixing it here would duplicate T6's diff — costs one task's worth of a stale /swagbag bank tiny answer on an unreleased branch
Task 3: minor (deferred): item tooltip hook installed at load (siblings hook at SB_LOGIN); return value ignored — V13-4 checks the line shows in game
Task 3: minor (deferred): BW.target not cleared on close (check REPORT_BANK "last deposit target" before changing)
Task 3: minor (deferred): stale "deposits go here" comment BankWindow.lua:203; DepositTooltipLine signature (tooltip) vs brief (tooltip, itemID)
Task 3: minor (deferred): no test pins bar relabel on bank.columns change; short-width test checks point names only
Task 3: complete (commits 3a362af..8efb9e8, 1 plan-mandated finding ruled to Task 6)
Task 4: implementer DONE_WITH_CONCERNS a279093 (1762 tests); concerns: 14 old tests set bank.show=both; searchBox.Apply = BW.ApplySearch override; no click line for saved-set folds in both mode
Task 4: minor (deferred): "both" mode tab-click tint now waits for the cursor to clear (Restack held) — Relabel in both mode, Restack in one mode
Task 4: minor (deferred): BW.peek survives a one->both->one switch in one visit (clear on mode change)
Task 4: minor (deferred): no test of the tint/TARGET label in "one" mode
Task 4: minor (deferred): duplicated GroupHeaders() lookup in GroupTip/ApplySearch (drawnCollapsed helper)
Task 4: minor (deferred): folded target's tooltip says "show it here until you switch tabs"; no click line for saved-folded groups in both mode
Task 4: complete (commits 8efb9e8..a279093, review clean)
Task 5: implementer DONE_WITH_CONCERNS 84fa2b7 (1780 tests); concerns: no captured RED (mutations instead); menu parented to BW.frame; 260px row width unverified in client
Task 5: minor (deferred): one Esc closes both the menu and the bank window (both in UISpecialFrames)
Task 5: minor (deferred): click elsewhere leaves the menu open; rows not refreshed on target switch while open
Task 5: minor (deferred): no test of Sort tooltip with nil target
Task 5: minor (deferred): depositTip helper reused for "..." tooltip (rename plainTip); long header comment lines
Task 5: complete (commits a279093..84fa2b7, review clean)
Task 6: implementer DONE_WITH_CONCERNS b6bd667 (1784 tests); concerns: SET_BANK_NOTE grammar awkward; spec §5.2 still 'tabs below'; some checklist steps from code
Task 6: review: 3 Important (checklist view-entry strings wrong; V13-5 "Bank slots per row" setting doesn't exist; spec §5.2/AC2.3/§5.4 stale lines)
Task 6: Ruling: bank.columns has no Settings row or slash (only share strings), so V13-5's narrow-window steps are removed from the user checklist and marked "covered by automated tests" — Review Focus 4 has two tests — costs an unchecked in-game narrow layout
Task 6: Ruling: SET_BANK_NOTE reworded (plan-mandated phrase reads wrong) to "...use the ... menu's Show Blizzard's bank entry in SwagBag's bank window, or the Blizzard guild bank buttons." — user-visible sentence must parse — costs nothing
Task 6: minor (deferred): help test find("one") is a bare substring; "tiny and beside still work" passes before the change
Task 6: fix round 1/5 (5 addressed, 0 open — checklist strings, V13-5 narrow steps removed, spec staleness, SET_BANK_NOTE, plain steps; commits b6bd667..42d73cb)
Task 6: complete (commits 84fa2b7..42d73cb, review clean)
Final review (42d73cb): With fixes — 1 Important (checklist V13-4 steps 6-7 expect title/tooltip to clear after X; they clear only on walking away), 7 minors
Final: Ruling: one fix wave = Important #1 + minors 1 (one mode, nil target -> both open, clicks peek not saved), 2 (labels from drawn folds), 3 (Sort tooltip nil target), 4 (Clear onHeaders trapped), 5 (AC2.7), 7 (report shows bank.show) + clear BW.peek on one/both — all small, user-facing or diagnostic — minor 6 (profile import doesn't restack an open bank) left: follows next open
Final: fix wave 6834af9 (1790 tests); re-review: all 8 addressed, no new breakage (restackHeld cannot stick except on an ErrorTrap'd positionAll throw, cleared at Clear)
