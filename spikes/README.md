# SwagBag feasibility spikes (THROWAWAY)

This folder holds a **throwaway test addon** called `SwagBagSpikes`. It is not SwagBag. It answers one question before any real code is written: can the original, larger MVP be built? That MVP is bags + character bank + warband bank, a grid and sections toggle, Safe Mode without /reload, a layout that never moves items under the cursor, and focus modes.

You run it in the game by following a short on-screen guide (about 15–20 minutes). It writes its results to a file that Claude reads afterwards. You never need to read code or debug anything.

---

## Part 1: Your checklist

### Before you start (5 minutes, at your computer)

1. **Install the test addon.** Open the Terminal app and paste this one line, then press Return:

   ```
   "/Users/lonezebra/Local Documents/AI-Projects/SwagBag/spikes/install.sh"
   ```

   It shows what it will do and asks "Proceed? [y/N]". Type `y` and press Return. This puts a *link* in your WoW AddOns folder:
   `/Applications/World of Warcraft/_retail_/Interface/AddOns/SwagBagSpikes`
   (Your game is installed at `/Applications/World of Warcraft`.)
   If the game is running, restart it so it notices the new addon.

2. **Pick a character and turn off other bag addons for that character only.** On the character-select screen:
   - Click **AddOns** (bottom-left).
   - In the dropdown at the top of the list, choose **that character** (not "All characters"). That way your other characters keep their setup.
   - **Untick** each of these that is ticked: `Baganator`, `BetterBags_BetterSort`, `BetterBags_SnipersFilters`, `EllesmereUIBags`, `EnhanceQoLBags`, `Narcissus_BagFilter`, `TradeSkillMaster`, and `ElvUI` (only if you use ElvUI's bags).
   - Make sure these are **ticked**: `SwagBag Spikes (THROWAWAY TEST)`, `Auctionator`, and optionally `!BugGrabber` / `BugSack`.
   - Click **Okay**.

   Why: other bag addons also hide Blizzard's bags and bank, which would spoil the results. The test addon warns you in chat if it still sees one.

3. **Bring these, if you have them:** a Hearthstone, some food or drink, one combat potion (healing potion or healthstone), and 1–3 **cheap gray junk items or cheap trade goods**. Your bank and warband bank each need **one free slot**.

### In the game (about 15–20 minutes)

4. Log in. After 3 seconds a window called **"SwagBag Spikes – step 1 of 29"** appears at the top-left. If it doesn't, type `/sbs` in chat and press Enter.
5. **Just follow the guide window.** Each step says what to do. When the addon notices you did it, a green **DONE** appears. Then click **Next**. If you can't do a step, click **Skip**. The steps come in four stops:
   - **Stop 1, anywhere in a city (about 6 min):** open the "spike bag", use an item from it, try the "A2 strip", switch to *Sections view* and drag an item, sort your bags, then hide and restore Blizzard's bags.
   - **Stop 2, a training dummy (about 4 min):** fight the dummy. While in combat, use a potion from the spike bag, drag an item, switch views, and hide/restore Blizzard's bags.
   - **Stop 3, a banker (about 6 min):** right-click test items into the warband bank and the character bank, try "Tiny mode", sort both banks, take one item back out, press ESC, then use your Hearthstone a few steps away.
   - **Stop 4, optional (about 3 min):** fish once, gather one herb or ore node, and run the advanced "taint probe".
6. **Finish:** on the last step click **"Reload UI now"**, or type `/reload`, or just log out. **This step matters, because the results file is only written on reload or logout.**
7. Tell Claude: **"spikes done"**.

Afterwards (optional), you can remove the test addon with
`"/Users/lonezebra/Local Documents/AI-Projects/SwagBag/spikes/install.sh" --remove`,
and re-tick your normal bag addons for that character. Removing the addon does **not** delete the results.

### Things you might see (all fine)
- A red **"Interface action failed because of an AddOn"** or "**[SBS] BLOCKED**" message. That is a *result*, not a problem. Keep going. A `/reload` clears it.
- The bags or bank get **sorted**, the same as Blizzard's broom button does.
- Up to **3 cheap test items move into your bank or warband bank**. You take item 1 back out during the test. Items 2 and 3 stay in your character bank and warband bank. Take them out whenever you like, or leave them.
- "Tiny mode" makes Blizzard's bank window vanish while the bank stays open. It switches back automatically when the bank closes.

### Useful chat commands (optional)
| Command | What it does |
|---|---|
| `/sbs` | open/close the guide |
| `/sbs status` | one line per spike: PASS / FAIL / MIXED / INFO / NOT RUN |
| `/sbs step 16` | jump to step 16 (e.g. straight to the bank part) |
| `/sbs pool` | show/hide the spike bag |
| `/sbs safe` | hide/restore Blizzard bags (Safe Mode test) |
| `/sbs focus` | print what the addon thinks you're doing (world / dungeon / M+ / fishing…) |
| `/sbs help` | all commands |

---

## Part 2: Where the results go (for Claude)

```
/Applications/World of Warcraft/_retail_/WTF/Account/LONEZEBRA/SavedVariables/SwagBagSpikes.lua
```

`SwagBagSpikesDB.runs[SwagBagSpikesDB.lastRunIndex]` is the newest run (the last 5 are kept). Each run contains:
- `build` (client version/TOC), `char`
- `spikes[ID]`: `status`, `summary`, `checks{name = {pass, detail, combat}}`, `data{}`
- `blocked[]`: every ADDON_ACTION_BLOCKED/FORBIDDEN, with `mine`, the function name, `lastOp` (the user's last action), and the frame under the mouse
- `errors[]`: Lua errors (captured through a wrapped `seterrorhandler` and `xpcall` around every spike action)
- `uses[]`: item-use attempts from spike buttons, A2 buttons, and Blizzard bag buttons (`strong` means the item's own spell was sent)
- `events[]`: a ring buffer of the last 800 marks and measurements
- `guide{}`: when each step was entered, done, or skipped

---

## Part 3: The spikes, and what each one decides

The letters follow the critique's §5 table. F (grammar diff) and G (Bagforge read-through) are desk research, not in-game tests, so they are not in this addon. Spikes S, P and F2 are additions.

| ID in results | Critique | Hypothesis | GO means | NO-GO means | Unblocks |
|---|---|---|---|---|---|
| `A_POOL` | A | ~1,300 `ContainerFrameItemButtonTemplate` buttons (backpack 20 + 5 bags × 38 + 11 bank tabs × 98 = 1,288) can be created at login, parented to per-bag frames (`SetID(bag)`) under one scroll child, cheaply enough. | `createUnder250ms` PASS (hidden by the loading screen) and `getBagIDResolvesFromParent` PASS. Also look at `per100ms`, `memKBPerButton` and `firstBankGridMs`. | Over 250 ms, or any single 100 over ~25 ms. | Pre-create everything at login, *or* time-slice creation, *or* create bank buttons on first bank open. |
| `A_USE` | A | Right-clicking an item in an addon-made button uses it, in and out of combat, with no block. This is tested two ways: per-bag-parent buttons (`pool`) and buttons that use the new `SetBagID()` attribute (`attr`). | `use_pool_outOfCombat` and `use_pool_inCombat` PASS. | Any FAIL means that construction can't use items, and the button model has to change. | The core button contract. If `attr` also passes, **buttons don't need per-bag parents**, which makes sections layout much easier (critique Issue 1). |
| `A_COMBAT` | A | Pool buttons can be re-anchored, shown, hidden and alpha'd during combat, and new template buttons can even be created then. | `battery_noErrors`, `battery_noBlockedActions` and `visibleButtonsMovableInCombat` all PASS. | Any block means layout must freeze in combat, and the "Incoming" strip is impossible. | Rule 6 of the layout model and the Incoming strip. |
| `D_LAYOUT` | D | A sections view on real slot-bound buttons stays stable. When an item leaves, a non-secure placeholder holds its spot, and the real button moves to Free or New. No button in a section ever shows a different item. This works in combat too, and grid ⇄ sections can be toggled live. | `noWrongItemInSection`, `movesOutOfCombatWork`, `movesInCombatWork`, `toggleViewInCombat` and `placeholderClickIsHarmless` all PASS. | `noWrongItemInSection` FAIL or combat moves blocked. | The placeholder contract the critique asked for. Whether the "category + grid toggle" MVP and "never move under cursor" are feasible. `hoverGuardDeferred` / `staleUnderCursor` show the remaining edge case. |
| `S_SAFEMODE` | B (frames) | Blizzard's bag frames can be hidden (hook OnShow → Hide, or reparent to a hidden frame) and restored live, in and out of combat, without breaking item use from Blizzard bags afterwards. | `suppressed*`, `restored*` and `toggleInCombat_*` PASS, plus `A_USE.use_blizzard_inCombat` PASS after restoring. | Blocks or errors when toggling in combat, or a blocked potion from the Blizzard bag afterwards (taint). | Safe Mode without /reload for **bags**: yes, out-of-combat only, or no. |
| `B_BANK` | B (bank) | Without ever writing bank state, right-click deposit from an addon bag goes to the bank type selected in Blizzard's own tabs. Hiding Blizzard's bank by reparenting it to a 0.001-scale frame ("tiny mode", Bagnon's method) keeps the bank open and routing correct, and Blizzard's real tab buttons still work after being moved onto our frame. ESC really closes the bank. | `readActiveBankTypeWithoutWriting`, `step_bank_dep_warband`, `step_bank_dep_char`, `depositMatchesActiveTab_*`, `step_bank_tiny`, `escClosesBankInteraction` and `itemUseAfterBankTests` all PASS. | Wrong landing, a block after tiny mode, or the bank still open after ESC. | Whether **character + warband bank stay in the MVP**, and the "one bank window driven by Blizzard's tabs" model. The optional `itemUseAfterTaintProbe` confirms that writing `BankFrame:SetTab()` from addon code taints item use. |
| `C_SORT` | C | `C_Container.SortBags()` and `C_Container.SortBank(Enum.BankType.Character / .Account)` work when called from an addon button click. The older `SortBankBags` / `SortAccountBankBags` presence is recorded too. | Each check PASS: no error, no block, and contents changed. "INFO, nothing moved" means it was already sorted; re-run it on a messy bag. | Error or block. | Whether SwagBag ships a Sort button that delegates to Blizzard. |
| `E_STORAGE` | E | Measures real string sizes for this character: full item links per slot vs aggregated `itemID:count`, for bags, character bank and warband. | No pass or fail. The numbers replace the 12 KB / 300 KB guesses. | No numbers. | The cross-character store format and budget. |
| `P_PRICE` | new | `Auctionator.API.v1.GetAuctionPriceByItemLink(callerID, link)` returns prices to another addon, and it's fast. TSM presence is noted too. | `auctionatorApiPresent`, `pricesReturned` and `fastEnough` (avg < 0.2 ms/call) PASS. | API missing or erroring. | An "AH value" overlay, value sort, and junk/value categories as an optional Auctionator integration. |
| `F_FOCUS` | new (focus modes) | Activity can be detected cheaply from events: M+ from `C_ChallengeMode.IsChallengeModeActive()` / `CHALLENGE_MODE_START` / the `C_RestrictedActions` ChallengeMode restriction; instance type from `IsInInstance`; fishing from the channel spell or `IsFishingLoot()`; gathering from loot whose source GUID is a `GameObject`. | `fishingDetected*`, `gatheringDetected` and `cheap` PASS. `mplusDetected` + `frameOpsAllowedDuringMplus` only appear if you run a key with the addon on. | Not detectable, or too costly. | Whether focus modes can switch automatically, and which signals to use (the logged `loots[].spellBefore` gives us gathering spell IDs). |
| `API` | H (adapted) | Every C_* API and Blizzard frame the plan relies on exists in this build. Deprecated globals are logged. Other bag addons that would spoil the results are detected. | `requiredApisPresent` and `noOtherBagFrameAddons` PASS. | Something is missing, or a bag addon was loaded (which makes the S/B results suspect). | The API adapter list. The same dump can run on WoW: Forever once it launches (2026-11-04). |

**Desk spikes not covered here:** F (grammar diff vs Syndicator syntax) and G (Bagforge read-through) are research tasks Claude can do without the game. H's Forever half has to wait for Forever to launch.

### What "go" for the full original MVP looks like
- **A_USE (pool, in combat), A_COMBAT, D_LAYOUT (in combat), S_SAFEMODE (out of combat), B_BANK (deposit routing + ESC) are all PASS:** the original MVP is technically feasible.
- **S_SAFEMODE fails only in combat:** Safe Mode becomes "applies when combat ends".
- **B_BANK deposit routing fails, or tiny mode taints:** the bank drops out of the MVP (bags-only first), as the critique suggested.
- **D_LAYOUT combat moves are blocked:** the layout freezes in combat (new items show only after combat or on close).

---

## Part 4: Verified vs assumed (as of 2026-09-30)

**Verified** against Blizzard's UI source mirror (Gethe/wow-ui-source, `live` = 12.1.0.69933, `ptr2` = 12.1.5.70077) and warcraft.wiki.gg:
- TOC `## Interface: 120100, 120105`. Live is 12.1.0 (120100), 12.1.5 is on PTR (120105), and comma-separated Interface values are supported.
- `ContainerFrameItemButtonTemplate` (an `ItemButton`, hidden by default). `ContainerFrameItemButtonMixin:GetBagID()` returns `self.bagID or self:GetParent():GetID()`. `SetBagID()` sets a `"bagid"` *attribute* (commented "Prevent bagID from tainting"). This is why the A2 strip test exists.
- Right-click deposit is `C_Container.UseContainerItem(bag, slot, nil, BankFrame:GetActiveBankType(), false)`. `BankFrame:GetActiveBankType()` returns **nil unless `BankPanel:IsShown()`**. That is why tiny mode keeps BankFrame shown instead of hiding it. `BankFrame:OnHide()` calls `C_Bank.CloseBankFrame()`. These code paths are identical on 12.1.5 PTR (one unrelated line differs).
- `BankFrame.TabSystem`, `BankFrame:SetTab()`, `characterBankTabID` / `accountBankTabID`, and BankPanel registered through `RegisterPlayerInteraction` (so the PlayerInteraction manager still exists in 12.1).
- `C_Container.SortBags`, `SortBank(bankType)`, `SortBankBags`, `SortAccountBankBags` are all in the 12.1 API docs. Blizzard's own bank sort button calls `C_Container.SortBank(activeBankType)`.
- `Enum.BagIndex` 0–5 bags, 6–11 character tabs, 12–16 warband tabs. `Enum.BankType` Character=0, Account=2.
- `C_ChallengeMode.IsChallengeModeActive / GetActiveChallengeMapID / GetActiveKeystoneInfo`. `C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.ChallengeMode)` (new in Midnight). `ADDON_ACTION_BLOCKED / FORBIDDEN (isTainted, function)`. `GetAddOnMemoryUsage` / `UpdateAddOnMemoryUsage` are still globals.
- Auctionator: `Auctionator.API.v1.GetAuctionPriceByItemLink(callerID, itemLink)` (from source mirrors of Auctionator).
- Bagnon/BagBrother's current approach: bag frames reparented to a hidden frame, and the bank panel reparented to a `SetScale(0.001)` frame with hooks on ToggleAllBags/ToggleBackpack/ShowUIPanel.

**Assumed / unverified (the spikes measure these):**
- Bank tab size 98 (recorded as `A_POOL.realBankTabSizes`). Bag max 38 (the pool grows if bigger).
- Whether moving `BankFrame.TabSystem` onto our frame keeps Blizzard's tab clicks working and untainted.
- Fishing spell ID 131474. The test also matches by spell name, and `IsFishingLoot()` is a backup.
- `GetProfessions`, `IsFishingLoot` and `GetLootSourceInfo` are legacy globals, not in the generated API docs. They are feature-detected.
- WoW following a symlinked addon folder on macOS. If the addon doesn't show up in the AddOns list, run `install.sh --copy` instead.
- `GetAddOnMemoryUsage` counts Lua memory only. The C-side memory for frames and textures is invisible to addons.

The code was checked with `luac -p` (syntax) and `luacheck` (0 warnings, using `spikes/.luacheckrc`). Claude also ran the whole flow, including every guide button, against a stubbed WoW environment: no Lua errors. Nothing has run in the real game yet. That is what this test is for.
