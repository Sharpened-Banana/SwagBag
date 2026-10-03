# Preflight: week 7 research picks (plan `docs/superpowers/plans/2026-10-06-swagbag-week7-research-picks.md`)

Read-only scan, 2026-10-03. Branch `week7-picks`, plan commit 482c315. Nothing in the repo was changed.

## How it was checked

- The plan was read in full (8029 lines) against the spec and the code at `a1f7f86`.
- **Independent replay.** I made a fresh clone at `/tmp/sb7` (outside the repo, branch `replay` from `a1f7f86`). A script parsed every Create and find/replace block from the plan and applied them task by task: Step 1, then the suite (red), then Step 3, then the suite (green) and `scripts/check.sh`. One commit per task. The results:
  - Every find block occurred exactly once when it was applied.
  - Every spec/ block is in Step 1 and every code block is in Step 3.
  - Every red/green count, every FAIL list (compared name by name), every `TOC OK (N files)` and every `ALL CHECKS PASSED` matches the plan:

| Task | Red (plan = replay) | Green | TOC | FAIL list | Commit `git add` list = files changed | Files section = files changed |
|---|---|---|---|---|---|---|
| 1 | 1263 / 22 | 1285 | 62 | 22 = 22 | 15 = 15 | yes |
| 2 | 1286 / 6 | 1292 | 62 | 6 = 6 | 8 = 8 | yes |
| 3 | 1291 / 7 | 1298 | 63 | 7 = 7 | 15 = 15 | yes |
| 4 | 1298 / 16 | 1314 | 66 | 16 = 16 | 10 = 10 | yes |
| 5 | 1302 / 23 | 1325 | 68 | 23 = 23 | 19 = 19 | yes |
| 6 | 1325 / 9 | 1334 | 69 | 9 = 9 | 9 = 9 | yes |
| 7 | 1334 / 5 | 1339 | 69 | 5 = 5 | 8 = 8 | yes |
| 8 | 1338 / 5 | 1343 | 69 | 5 = 5 | 13 = 13 | yes |
| 9 | 1343 / 13 | 1356 | 72 | 13 = 13 | 6 = 6 | yes |

- **Mutations.** All 87 listed mutations were applied, one at a time, to their own task's commit. Each one made its named test fail.
- **Probes** (temporary specs in `/tmp/sb7`, then deleted) confirmed findings 4, 5 and 9 below.
- The per-task briefs contain their plan sections verbatim, and `global-constraints.md` contains plan lines 59-97 verbatim (see finding 22 for the task-9 brief).

## 1. Task pairs: shared files and interfaces (36 rows; `Locale/enUS.lua` is shared by all nine tasks)

| Pair | Shared | Produced by one / consumed by the other | Verdict |
|---|---|---|---|
| T1-T2 | `spec/categorizer_spec.lua`, `spec/overlaydata_spec.lua`, enUS | T2's categorizer edit 2 anchors on T1's new `{ at(4), ... at(11) })` line (plan 957). Venomstones file under `c_keystone` (95) above `c_sets` (92). | consistent |
| T1-T3 | `Config.lua`, `OverlayData.lua`, TOC, enUS | T1 changes the junk line (857); T3 adds `ctx.learn` (2091). TOC: T1 sets the version line, T3 adds Collections. | consistent |
| T1-T4 | `Config.lua`, enUS; record `inEquipmentSet` | `Vendor.Protected` reads `inEquipmentSet` (3082), as the T1 Produces line (304) says. The junk coin (857) and `Vendor.Junk` (3092) both skip set pieces. | consistent |
| T1-T5 | `Config.lua`, `OverlayData.lua`, `spec/keywords_spec.lua`, enUS | T1 puts the set flag on the test's own slot (629); T5 renames `locked` to `inuse` on fixture slot 10. The junk coin still shows on a user-locked gray item (finding 11). | consistent (UX nit) |
| T1-T6 | `spec/bagswindow_sections_spec.lua`, enUS | Both insert before the "Pins week-4 D10" anchor; T6's anchor (4619) is unique after T1. Sell all drops set pieces through `Vendor.Protected`, so the Equipment sets section answers "Nothing ... can be sold". | consistent |
| T1-T7 | `Config.lua`, enUS | Different keys (focus vs prices). | consistent |
| T1-T8 | `Config.lua`, `OverlayData.lua`, enUS | Separate edits. | consistent |
| T1-T9 | enUS; Config defaults | `KnownPaths` covers `focus.sections.*`. A user's own saved set is kept (D2). | consistent |
| T2-T3 | `Engine/Crests.lua`, enUS | T2 creates `items`; T3 adds `knowledge` after the `items = { VENOMSTONE },` anchor (2011). Collections reads `SB.Crests.knowledge`. | consistent |
| T2-T4 | enUS | None beyond enUS. | consistent |
| T2-T5 | enUS | None. | consistent |
| T2-T6 | enUS | None. | consistent |
| T2-T7 | enUS | None. Footer gold and Prices are separate. | consistent |
| T2-T8 | enUS | None. | consistent |
| T2-T9 | enUS | `footer.entries` is a known string path; it round-trips (test 6691). | consistent |
| T3-T4 | `Adapter.lua` (code and CHECKS), `Config.lua`, `spec/mock_adapter.lua`, TOC, enUS | Both mock edits anchor on `end\n\n\tfunction m.IsQuestItem`; it is unique at each step (replayed). | consistent |
| T3-T5 | `Overlays.lua` (regions table, `Ov.NAMES`, ctx), `OverlayData.lua`, `SettingsPages.lua`, `Config.lua`, overlays_spec, enUS | T5's lock region anchors on T3's `}\n r.glow:SetAllPoints`. The "each overlay has its own switch" list string is updated in order by T3, T5 and T8. | consistent |
| T3-T6 | `Adapter.lua`, mock, TOC, enUS | None beyond these files. | consistent |
| T3-T7 | `Overlays.lua` glow region, `Ov.LEARN_TINT`, `on("learn")`, `Config.lua`, overlays_spec, `SettingsPages.lua` | T7 replaces T3's tint block (5712); gold wins over green (D9). | consistent |
| T3-T8 | `Collections.lua` (cache, `cached`, `isGear`, Learn refactored into `teaches`), `Adapter.lua` `known()`, adapter_spec, collections_spec, mock, `.luacheckrc`, `Config.lua`, `Overlays.lua`, `SettingsPages.lua`, `OverlayData.lua` | T8 edit 3 anchors on T3's Learn body verbatim (6306-6327). The `m.collected` table gains `looks`. | consistent. The star vs gold rule conflicts with D9 (finding 10). |
| T3-T9 | enUS; Config defaults | `overlays.learn` is a known boolean. | consistent |
| T4-T5 | `Engine/Vendor.lua`, `UI/SettingsVendor.lua`, `Adapter.lua`, `Config.lua`, `spec/vendor_spec.lua`, mock, TOC, enUS | `Vendor.Protected` already calls `SB.Locks` (forward reference, nil-guarded). T5's anchors (4118, 3851, 3890, 4213) are T4 lines. TOC puts Locks before Mover. | consistent. The lock is checked at list time only (finding 2). |
| T4-T6 | Mover job contract (`items` with `price`, `act`, `still`, `done`, `result.moved/kept/why`); `Vendor.Sell(list,"section")`, `.open`, `.Protected`, `.Money`, `.BUYBACK`; `A.MoveToBank` (made in T4, used in T6); L.VENDOR_* reuse; mock `used` and `onUse` | Shapes match (`SA` builds items with `price`, 5121-5125). | consistent. Buyback cap is per run, not per visit (finding 1). |
| T4-T7 | `Config.lua`, enUS | None. | consistent |
| T4-T8 | `Adapter.lua`, `Config.lua`, mock, enUS | None. | consistent |
| T4-T9 | enUS, TOC (T9 anchors on `Engine/Vendor.lua`, `UI/SettingsVendor.lua`) | `vendor.repair` is imported without checking the allowed values (finding 3). | consistent (validation gap) |
| T5-T6 | `Adapter.lua` (T6 anchors on T5's CHECKS line), mock (T6 anchors on T5's buyback comment), TOC, enUS (anchors on `SET_LOCK_CLEAR`); `Vendor.Protected` | Sell all drops locked items. The Lock-button drop and the header gesture do not collide. | consistent. The lock race (finding 2) applies to Sell all too. |
| T5-T7 | `Overlays.lua` (T7 anchors on T5's lock line), overlays_spec (anchors `assert.falsy(off.lock.shown)`), `SettingsPages.lua`, `Config.lua`, enUS | No overlap in logic. | consistent |
| T5-T8 | `Keywords.lua` (T8 anchors on T5's `inuse`), `Overlays.lua` (anchors on `LOCK_TEXTURE`, the lock `show`), `OverlayData.lua`, `SettingsPages.lua`, `Config.lua`, enUS (`" lock, pawn)"`) | Applied in order. | consistent |
| T5-T9 | enUS, TOC | Locks live in `SwagBagDB.locks`, so they never travel with a profile (D24). | consistent |
| T6-T7 | enUS (T7 anchors on `SECTION_HINT_BANK`); `BankWindow.interaction` | `atBank()` is duplicated in both files (finding 13). | consistent |
| T6-T8 | `Adapter.lua`, mock, enUS | None. | consistent |
| T6-T9 | enUS, TOC | None. | consistent |
| T7-T8 | `Overlays.lua` (glow and star), overlays_spec (T8 anchors on T7's `worthTop") })`), `SettingsPages.lua`, `Config.lua`, enUS (anchors on `SET_WORTH_TIP`'s tail) | The star condition ignores the gold glow (finding 10). | conflict (minor) |
| T7-T9 | `prices.worth*` known paths; `Pr.Follow` emits `SB_PRICES_CHANGED`, which re-works the worth line at the bank | Import accepts `worthTop=0`, which the command refuses (5849, mutation-pinned) (finding 3). | conflict (validation) |
| T8-T9 | enUS (T9 anchors on `SET_OV_UNCOLLECTED`); `overlays.uncollected` | None. | consistent |

## 2. Per task: does its text agree with itself?

| Task | Tests vs code | Created vs touched | Red/green vs tests added | Commit list vs changed | Verdict |
|---|---|---|---|---|---|
| 1 | +4 tests; 5 mutations kill | 0 created, 15 touched | 22 red = 4 new + 18 edited | 15 = 15 | consistent |
| 2 | +7 tests (1 passes at once, as the plan says at 1110); 6 mutations kill | 0 / 8 | 6 red | 8 = 8 | consistent |
| 3 | +6 tests; 9 mutations kill | Collections and collections_spec created | 7 red (6 new + 1 edited) | 15 = 15 | consistent |
| 4 | +16 tests; 18 mutations kill | Mover, Vendor, SettingsVendor and 2 specs created | 16 red | 10 = 10 | consistent. Text nit: the mock comment says `useFails` makes the call throw (2323), but it returns `false, "refused"` (2330). |
| 5 | +11 tests; 12 mutations kill | Locks, LockButton and locks_spec created | 23 red (every vendor test, because the vendor spec now loads Locks) | 19 = 19 | consistent |
| 6 | +9 tests; 11 mutations kill | SectionActions and its spec created | 9 red | 9 = 9 | consistent |
| 7 | +5 tests; 6 mutations kill | 0 / 8 | 5 red | 8 = 8 | consistent. Text nit: the intro (5426) says the line is worked out again "on a setting change", but there is no `SB_CONFIG_CHANGED` listener; only `/swagbag worth` and `Profiles.Follow` (`SB_PRICES_CHANGED`) refresh it. |
| 8 | +4 tests; 6 mutations kill | 0 / 13 | 5 red | 13 = 13 | consistent |
| 9 | +13 tests; 13 mutations kill | Profiles, ShareBox, SettingsProfiles and profiles_spec created | 13 red | 6 = 6 | consistent, but one test is partly hollow (finding 4) |

## 3. Things a code reviewer would treat as defects

**Forbidden tokens.** None of `BankFrame:SetTab`, `.bankType =`, `CloseBankFrame(`, `PurchaseBankTab`, `OpenAllBags(`, `PreClick` or `PostClick` appears in the final tree (`check.sh` passed after every task).

**Adapter-only rule.** One breach: finding 5.

Items 4, 5, 12, 13, 14, 15, 16, 17 and 18 in the list below.

## 4. Spec conflicts and UX/safety risks

Items 1-3, 6-11 and 19-21 in the list below.

---

## Numbered findings, with a suggested fix for each

**Fix before execution (safety or a broken promise):**

1. **The buyback guarantee holds per run, not per visit** (D10, plan 136; `V.Sell` 3136; strings 3290-3291). The auto-sell sells 12. Its own line then tells the user to type `/swagbag sell junk`, and `VENDOR_MORE` says "use Sell all again". Either one sells 12 more in the same visit, which pushes the first 12 out of the 12-slot Buyback tab. Hand sales do the same. *Fix:* keep `V.soldThisVisit` (reset on `MERCHANT_SHOW`) and cap each run at `BUYBACK - soldThisVisit`. When the budget is used up, the line and the Sell all question should say that selling more pushes the earlier items out of Buyback (an explicit second "Yes"). Add a test for a second run in the same visit.
2. **A lock set mid-run does not stop the sale.** `Protected` is checked only when the list is built (3092, 5133), and the mover's `act` is the bare `A.SellItem` (3140). Dragging the item onto Lock during a run puts it on the cursor, so the mover waits. The drop then locks the item and puts it back, and the mover resumes and sells it. *Fix:* in `V.Sell`, make `act` re-describe the slot and skip it if it is now `Protected` (or no longer sellable) before calling `SellItem`. Add a test.
3. **Profile import checks only the value's type, never its range or allowed values** (`Pr.Parse` 7294-7299, `Pr.Import` 7409-7414). Probe on the replayed tree: `s.bags.columns=n0;s.bags.scale=n-3;s.prices.worthTop=n0;s.guildBank.withdrawAnyTab=b1;s.theme.name=sbogus` imports as 7 changes. Effects:
   - `bags.columns=0` gives `i % 0` and `i / 0` in `GridLayout.Compute`/`Layout`: errors, then the bags go into Safe Mode.
   - `worthTop=0` is a value the command refuses (5849).
   - `withdrawAnyTab` is the W3-10 safety flag, off until check G1.
   - The string checks are bypassed because `Config.Set` has no validators: the only guards were the fixed UI choices.

   *Fix:*
   - Add a per-path validator table in `Profiles.lua`: integer ranges for columns, newRows and the worth values; scale 0.5-2; the allowed words for view, theme, repair, worth, blizzardFrame, guildBank.mode, focus.resolve/peek/style and tooltip.counts.
   - Refuse the whole string with the `type` reason when a value fails.
   - Never import `guildBank.withdrawAnyTab` (a machine-state or no-import list).
   - Add tests.
4. **A test asserts half of what it claims** (`spec/profiles_spec.lua`). The file defines `local function load(withUI)` (6614), which shadows the global `load`. The "never runs what it reads" test (6724-6728) therefore swaps the local function. Probe: adding `load("return 1")` inside `Pr.Parse` leaves the test passing (13/13); a `loadstring` call is caught. *Fix:* rename the helper (for example `loadSB`) and intercept `_G.load`.
5. **Adapter-only rule broken in a comment.** `Engine/Collections.lua` says "(C_TransmogCollection)" (plan 6238). `check.sh` misses it because no dot follows the name. *Fix:* "the account's transmog collection (Adapter.AppearanceKnown)".
6. **Undo does not undo categories after "Import with categories".** `Pr.Import` overwrites `d.categories[id]`, `d.userEdits[id]` and `d.categoryOrder` (7420-7433); only the settings go into `backups.profile`. Yet `PROFILE_IMPORTED` (7514) promises that undo brings everything back. *Fix:* back up and restore those three tables with the settings, or say in the preview and the chat line that categories cannot be undone. Add a test.
7. **"Nothing would change" is never shown to a user with a custom consumables watch list.** `Pr.Preview` (7366) and `Pr.Import` (7415) list and count the watch list even when it is identical. Probe: a user's own export previews as "Consumables watch list: 1 entries". So PF1 step 12 (7960) fails for that user, and "1 entries" is also bad grammar. *Fix:* compare with the current list (deep equal) first; add a singular string.

**Minor (fix in review or record in the ledger):**

8. **A run that just finished reports "so 0 stayed".** `Mover.step` checks `still()` and combat before "no next item" (2976-2984). A vendor that closes, or combat that starts, within 0.2 s of the last sale gives "The vendor closed, so 0 stayed in your bags." Also, `total - n` (3116, 5162) counts skipped items (used by hand) as having stayed. *Fix:* finish with `nil` when `run.items[run.index]` is nil before those checks, and drop the suffix when the count is 0.
9. **P2: a vendor opened in combat always prints a line.** `V.Visit` prints `VENDOR_COMBAT` (3190) even with no junk and nothing to repair. Global Constraint line 70 says automatic actions stay silent when there is nothing to do. *Fix:* print only when `#V.Junk() > 0` or there is a repair cost.
10. **Star versus gold glow.** The star condition (6530) uses `on("learn") and d.learn ~= nil`, not the glow actually drawn. At the bank, an uncollected toy, mount or pet worth 100g or more shows gold and no star, which contradicts D9 ("star ... while the green glow is off", 135). *Fix:* use `greenShown = glow and not worth`.
11. **The junk coin shows on a gray item the user locked** (`OverlayData` 857). The coin says "sell me", but the item is never sold. *Fix:* skip the coin when `ctx.locked` is true, or accept it and record the decision.
12. **Duplicated logic.**
    - `Pr.Follow` (6985-7002) is `QuickSetup.lua`'s `refresh()` (lines 95-109) nearly verbatim, plus `Theme.Apply`. *Fix:* QuickSetup calls `SB.Profiles.Follow`, or both use one helper.
    - `atBank()` is defined identically in `SectionActions` (5109) and `Overlays` (5761).
    - `A.RepairCost` and `A.GuildRepairMoney` (2817-2857) are near-identical bodies; a local helper would serve both.
13. **Unused exports.**
    - `Pr.MAX_LIST` (6930) is never enforced: the item lists in `numbers()` (7218) are unbounded except by `MAX_TEXT`.
    - `LB.Press` (4322) and `Ov.WorthState` (5838) are exported but never used.

    *Fix:* enforce `MAX_LIST`, and drop or use the other two.
14. **The section menu frame is not themed** (5258-5263). Global Constraint line 77 says themes restyle it, and the OfflineWindow menu does `Theme.Window(menu, "dialog")`. *Fix:* add that call.
15. **P6 windows.**
    - The `lock.dropGuard` timer traps under `"bags"` (4312-4316), so a cosmetic timer could put the bags in Safe Mode. *Fix:* use `"none"`.
    - The Vendor (4148) and Collections (1987) Inventory listeners run under `Inventory.Notify`'s `"bags"` trap, not `"none"` as line 74 states. *Fix:* record this in the ledger.
16. **Wrong wording.** `LB.Drop`'s invalid branch reuses `L.DROP_INVALID`, "This item can't be added to a category" (4299). *Fix:* add `L.LOCK_INVALID`.
17. **Possibly stale label.** Settings > Vendor's "Locked items: N" is built with the rows (4544). After "Unlock all", confirm that `RunCommand` re-renders the page; otherwise refresh on `SB_LOCKS_CHANGED`.
18. **Raw setting values in chat.** `/swagbag repair` prints the stored word `own` or `guild` (3254, VN1 step 4) instead of "Your gold" or "Guild bank first". The share preview also prints raw dotted paths ("focus.sections.mplus: c_consumables,..."), which a non-coder will find cryptic. *Fix:* map the values to their labels.

**UX/safety decisions for the user (the plan is internally fine; these are product risks):**

19. **Auto-sell and Sell all versus a gold-maker.**
    - The auto-sell sells gray gear whose appearance is uncollected (Task 8 already knows which) and gray BoEs worth far more on the AH.
    - Sell all sells any quality at vendor price. Its question shows only the vendor amount ("for about 6s"). It also includes caches and unlearned mounts, toys and pets (green-glow items).

    *Fix:* add to `Vendor.Protected` (or to Sell all only):
    - appearance-uncollected items;
    - items whose Auctionator price is well above the vendor price (or at least the worth line);
    - items with the green glow.

    And name the AH value in the question.
20. **Calling `UseContainerItem` with no vendor or bank open uses the item**: equips gray gear, opens caches, drinks potions. The mover checks `still()` in the same step, just before `act`, so the window is tiny. *Hardening at no cost:* make the act itself re-check `V.open` or `BankWindow.interaction` immediately before the call.
21. **The `locked` keyword rename.** A grep of the code, the locale and the built-in categories and focus sets finds no use of the old meaning (D17 holds). Two things remain:
    - User-written category queries and consumables watch queries containing `locked` would change meaning silently. *Fix:* one login line if any saved query contains the word.
    - A live `locked` search does not re-run on `SB_LOCKS_CHANGED`. *Fix:* re-run it.

    Spec items to add to "Spec updates at week end" (7985):
    - §7.3 gives the collection keywords cache class `instance`, but the plan registers `uncollected` as `volatile` (6360).
    - Guild-funded repair touches §1.3's "no guild bank money" non-goal (it is a setting, off by default).
    - Imported categories are stored as plain user categories, not with spec line 538's `source = "import"`.
22. **Task 9 brief.** It also carries the plan's trailing sections (In-game sessions through Self-review; brief lines 1259-1442), so the Task 9 implementer could act on "Spec updates at week end". *Fix:* trim it, or mark those sections as not for Task 9.

Eye checks, not defects:
- The 14 px padlock at top-middle may overlap the top-left item level and the top-right upgrade arrow on gear (VN1 step 5: lock a gear piece too).
- An imported `cu.c_junk.*` is silently dropped by `Categories.Load` but still counted "of yours" in the preview and in Import's count.
- BK1 step 19 should also expect the queued auto-sell to run after combat if the vendor is still open.
