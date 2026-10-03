# SDD ledger — plan: docs/superpowers/plans/2026-10-05-swagbag-week6-user-requests.md
Spec: docs/superpowers/specs/2026-09-30-swagbag-design.md
Plan commits: 76293b0 (Tasks 1-6), e9d09c4 (Tasks 7-9). Branch week6-requests from main 3d2421d. Expected tests 1226 -> 1274.
User decisions (2026-10-03 "go for week 6"): own Deposit button via Adapter (not re-hosting Blizzard's); 'front' style header clicks = user's own collapse, no peek/pin.
Preflight: dispatched (output -> preflight.md)
Preflight: complete — table in preflight.md (29 pair rows, 9 task rows). Rulings:
- P1 Ruling: FS1/DP1 (and OV1, TF1) all run on the final merged build, not mid-week — the vendor walk-away (T7) and bank flash (T7) fixes then precede them — cost if wrong: none (user tests after merge anyway).
- P2 Ruling: FS1 step 16 "second row" wording becomes "the row under the intro" — fixed in the checklist at week end (sessions doc), not by implementers — cost: a confusing step.
- P3 Ruling: Task 9 implements Snap.Bytes() as the sum of Snap.BytesByKind() (no duplicated traversal) — carried into the Task 9 dispatch — cost: none, equality test still holds.
- P4 Ruling: Task 4 implementer adds and runs a mutation for the c_wue rename-diff test (e.g. C.Load ignoring userEdits.c_wue) and records it — cost: none.
- P5 Ruling: Task 2 implementer rewords the "Pause draws the user's order again" test comment to match its actual red/green role — cost: none.
- P6 Ruling: user strings reworded: MODE_STYLE_COLLAPSE must not promise peeks (peek setting may be "keep"); SET_FOCUS_INTRO must be true for the default front style (e.g. "...move the sections you need for what you're doing — a key, the vendor, fishing — to the top. They switch by themselves."). Carried into Task 3 / Task 8 dispatches; checklist quotes (FS1 step 13, TF1 step 14) updated at week end — cost: wording only.
- P7 Ruling: c_wue joins exactly the focus-mode section sets that contain c_boe (it sits "next to BoE gear"; consistent behaviour in collapse and front) — carried into Task 4 — cost if wrong: WuE gear opens/moves in a mode the user didn't expect; easy to edit in the mode editor.
- P8 Ruling: spec week-end update list gains §10.5 (`mode style`), §5.2/§1.3 (Deposit warbound picks warband type at the user's click and `With reagents` mirrors Blizzard's own user-facing bankAutoDepositReagents option — accepted because the user asked for the button), §8.6 (one-version downgrade: repeated stacks read as unknown until re-saved — accepted), §6.3 (c_wue per P7). Budgets §8.4 30 KB/§9 80 ms remain OPEN, measured in TF1 — cost if wrong: spec drift until week end.
Task 1: dispatched (BASE e9d09c4, implementer sonnet)
Task 1: implemented 5c90a75 (1234 tests); review dispatched
Task 1: minor (deferred): Focus.lua header comment "writer whose value is already in force" splits API list — move below ListLines
Task 1: minor (deferred): SetStyle `if not write(...) then return false,"readonly"` unreachable after readOnly check
Task 1: minor (deferred): no test that Front() refreshes after plain Config.Set of focus.sections / across Pause→Resume
Task 1: complete (commits e9d09c4..5c90a75, review clean)
Task 2: dispatched (BASE 5c90a75, sonnet)
Task 2: implemented 0f9e1bd (1242 tests, mutations run); review dispatched (opus)
Task 2: minor (deferred): W.EffectiveOrder builds a list on every Restack even on M1 shortcut (negligible)
Task 2: minor (deferred): M1 comment in W.Restack could say "(same collapsed view and same order)"
Task 2: minor (deferred): specs hardcode "SwagBag — AH/Vendor/Bank" title literal (existing pattern)
Task 2: complete (commits 5c90a75..0f9e1bd, review clean)
Task 3: dispatched (BASE 0f9e1bd, sonnet)
Task 3: implemented 9e3efd7 (1244 tests, mutations run, P6 applied); review dispatched (sonnet)
Task 3: minor (deferred): style answer ternary duplicated Focus.lua:95 / SettingsFocus.lua:235
Task 3: minor (deferred): L.MODE_STATUS still lists "pause, resume or list" without style
Task 3: minor (deferred): SettingsFocus.lua:186-188 header comment wrap
Task 3: complete (commits 0f9e1bd..9e3efd7, review clean)
Task 4: dispatched (BASE 9e3efd7, sonnet)
Task 4: implemented 43e3cb5 (1249 tests = brief+1 for P7; later task totals shift +1); review dispatched (sonnet)
Task 4: minor (deferred): categories_spec lines past ~120 cols (plan-mandated text)
Task 4: minor (deferred): P4 rename-test mutation is broad (fails 15 tests); a narrower one (strip `after`) would be more targeted
Task 4: minor (deferred): C.Load `after` chain / id collisions untested (single user today)
Task 4: complete (commits 9e3efd7..43e3cb5, review clean)
Task 5: dispatched (BASE 43e3cb5, sonnet)
Task 5: implemented 157b159 (1253 tests); review dispatched (opus)
Task 5: ⚠️ resolved: in-combat refusal lives in Task 6 BW.DepositWarband (brief lines 80-85, 273) — confirmed by controller
Task 5: Ruling: "locked" maps every non-nil FetchBankLockedReason (incl. BankDisabled), so Task 6's DEPOSIT_LOCKED must not claim "another character" — reword to e.g. "The warband bank is locked right now (another character of your account may be using it): nothing was deposited." and fix the Adapter comment — carried into Task 6 — cost if wrong: misleading message only
Task 5: minor (deferred): secret-value test covers only DoesItemExist path, not allowed/refund secret checks
Task 5: minor (deferred): mock DepositWarband always succeeds (no failure field)
Task 5: minor (deferred): adapter_bank_spec before_each doesn't clear C_Bank/C_Item/C_CVar
Task 5: minor (deferred): RED evidence lacks quoted FAIL lines
Task 5: complete (commits 43e3cb5..157b159, review clean)
Task 6: dispatched (BASE 157b159, sonnet)
Task 6: implemented afa3324 (1259 tests); review dispatched (sonnet)
Task 6: ⚠️ resolved: A.Stack exists in Adapter (controller grep)
Task 6: minor (deferred): DepositWarband pcall error branch untested (ErrorTrap record, one DEPOSIT_UNAVAILABLE, no Safe Mode)
Task 6: minor (deferred): refusal/success tests don't assert nothing reached chat (P2 chat side)
Task 6: minor (deferred): reagents box refreshed only on Open/click — stale in beside mode if Blizzard's box changes
Task 6: minor (deferred): deposit doesn't check cursor item (P5) — call doesn't move cursor; low risk
Task 6: complete (commits 157b159..afa3324, review clean)
Task 7: dispatched (BASE afa3324, sonnet)
Task 7: implemented 0178c18 (1265 tests); review dispatched (opus)
Task 7: minor (deferred): stale toggleClosedUsers in onBagKey "auto" branch can make trace say "opened again" falsely (SafeModeHooks.lua:105-109) — matters for TF1 trace accuracy
Task 7: minor (deferred): reopen branch ignores W.Open() result, always traces "reopened" (:182)
Task 7: minor (deferred): no test pins `frame ~= nil` guard in reopen condition (:178)
Task 7: minor (deferred): didText builds lookup table per call (report only)
Task 7: complete (commits afa3324..0178c18, review clean)
Task 8: dispatched (BASE 0178c18, sonnet)
Task 8: implemented 10af7bb (1269 tests); review dispatched (sonnet)
Task 8: review Needs fix (1 Important: SET_FOCUS_INTRO "the row below" points at focus.auto row, not the style row)
Task 8: Ruling: the stale Pause tooltip after a click (minor) joins fix round 1 — the Pause tooltip is the exact thing the user reported unclear in FM1, and a tooltip that keeps saying "Pause" after pausing defeats the fix — cost: one small extra change
Task 8: minor (deferred): SET_MODE_TIP doesn't mention master "Switch by themselves" must be on
Task 8: minor (deferred): new tests hard-code English strings instead of L.*
Task 8: minor (deferred): SET_FOCUS_STYLE_TIP "nothing is collapsed" → "the mode collapses nothing"; omits New always open
Task 8: minor (deferred): QuickSetup pauseNote (-160) may touch status line — check in game (TF1)
Task 8: fix round 1 dispatched (resume implementer)
Task 8: fix round 1 implemented 6efaa73 (1270 tests); re-review dispatched (haiku)
Task 9: dispatched (BASE 6efaa73, sonnet) — in parallel with Task 8 re-review (read-only)
Task 8: fix round 1/5 (2 addressed, 0 open — intro names style row; Pause tooltip refresh on click; commits 10af7bb..6efaa73)
Task 8: complete (commits 0178c18..6efaa73, review clean after fix round 1)
Task 9: implemented 3e78957 (1276 tests); review dispatched (opus)
Task 9: minor (deferred): count-only repaint single-read path (BankWindow.lua:592-595) untested
Task 9: minor (deferred): downgrade to 0.5.0 loses repeated stacks until next save (record in release notes; P8)
Task 9: minor (deferred): gold thousands separator hard-coded "," (enUS only)
Task 9: minor (deferred): Snap.Bytes builds a table per call in Enforce trim loop (save-time only)
Task 9: complete (commits 6efaa73..3e78957, review clean)
Final review: dispatched (opus) over 3d2421d..3e78957
Final review: With fixes — 0 Critical, 1 Important (SET_FOCUS_STYLE_TIP/SET_FOCUS_PEEK_TIP "nothing is collapsed" false in front style), 5 Minor. check.sh 1276 pass.
Final: Ruling: one fix wave covers Important #1 + cheap minors (MODE_STATUS style, SET_MODE_TIP master switch, MODE_TIP_RIGHT wording, Overlays bind row Off-first, RefreshReagents at deposit start, clear Focus.overrides on style change, Task 7 toggleClosedUsers reset + frame~=nil test) + week-end doc updates (sessions text, spec P8 list) — all small, user-facing, low risk — cost: a slightly larger fix diff
Final: fix wave dispatched (sonnet)
Final: fix wave done 7f3ae83..0aa6702 (1281 tests); scoped re-review dispatched (sonnet)
Final: re-review — all 10 addressed, no new Critical/Important; minors: Focus.lua overridesStyle module-local never reset (harmless); settings_spec test title says 'Show BoE/WuE' vs label.
Final: complete (week 6 HEAD 0aa6702, 1281 tests)
