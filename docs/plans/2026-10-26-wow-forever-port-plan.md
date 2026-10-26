# SwagBag on WoW: Forever — port plan

*Date: 2026-10-26. Source: `research/2026-10-22-wow-forever-port.md` (cited as R§N). Status: ready to execute.*

## Decisions this plan assumes (change them and the plan changes)

| Decision | Default | Effect if different |
|---|---|---|
| Scope | **"Works and is honest."** No category or default tuning for Forever items. | Tuning adds ~1 week, after launch. |
| Timing | Code now, **upload only after an in-game check in a Forever client**. Target: launch week (from 2026-11-04). | No client access means the upload waits for launch day, or for someone who has one. |
| Beta | Ended 2026-10-23. No beta data is available beyond Blizzard's source (R§1). | — |
| Upload | One CurseForge file carrying both Retail and Forever versions. | A separate file only if Forever needs a different file list. |

## Ground rules

- All game API access stays in `SwagBag/Core/Adapter.lua`. Everything else asks `A.*`.
- Gate by **project constant plus feature check, never by Interface number** (R§3).
- A failed required check must never take the Retail build down. Retail behavior and numbers stay identical; every task needs a spec for both layouts.
- Nothing is uploaded, pushed or tagged by the plan's tasks. Release is step 10 and needs the user's go.

## Tasks (in order; each is one commit)

### 1. Detect Forever (`Core/Adapter.lua`)
- `A.IsForever()`: true when `WOW_PROJECT_CAMELOT` exists and equals `WOW_PROJECT_ID`; else fall back to `C_Bank.ShouldUsePlayerBagsInBank ~= nil and not C_ChallengeMode-UI present` (feature check, R§5 unknown 2).
- `A.Client()` returns `"retail"` or `"forever"`, for the report box (`Core/Report.lua`) and logs.
- Specs: fake globals for both; the fallback path; neither.
- **Done when:** `scripts/check.sh` is green and Retail behavior is unchanged.

### 2. TOC
- `## Interface: 120105, 16001`. Keep one `SwagBag.toc`; do not add `_Forever` or `_Mainline` files (R§1).
- Check `scripts/check.sh`'s TOC rule accepts the list. Add the launch number when it is known.

### 3. Bag IDs from `Enum` (R§2)
- `A.BagKind` and `A.GetBagIDs` read `Enum.BagIndex.CharacterBankTab_1..N` and `AccountBankTab_1..N` by name and build the ranges at load. No numeric constants.
- `A.CHECKS`: drop the `value = 12` and `value = 6` expectations; require the names to exist instead.
- `A.BANK_TAB_CAPACITY`: size from `GetContainerNumSlots` per container, with 98 as the pool floor.
- Specs for **both layouts**: Retail 6–11 / 12–16 and Forever 6–14 / 15–23. Add a regression spec that Warband tab 1 is never read as a character tab.
- **Done when:** both layouts classify every ID the same way Blizzard's `Enum` does.

### 4. Feature gates
- One table in `Adapter.lua`, `A.FEATURES`, each entry true or false from detection: `keystones`, `crests`, `delves`, `upgrades`, `housing`, `warbandBank`, `warbandGold`, `warbandBind`, `guildBank`, `scrapper`.
- Rules (R§3): `keystones`/`crests`/`delves`/`housing` are off on Forever. `warbandBank`/`warbandGold` follow `C_Bank.CanViewBank(Enum.BankType.Account)` and `DoesBankTypeSupportMoneyTransfer`. `guildBank` and `scrapper` follow their API. `upgrades` follows `C_Item.GetItemUpgradeInfo` returning data.
- Hook every consumer (`Engine/Crests.lua`, `Engine/Signals.lua`, `Engine/OverlayData.lua`, `UI/Overlays.lua`, `UI/SettingsPages.lua` and friends) to `A.FEATURES`. Hide the settings pages and menu rows of an off feature; no dead controls.
- Specs: each gate off and on.

### 5. Bank window (R§4)
- `UI/BankWindow.lua`, `UI/GroupView.lua`, `UI/BankMenu.lua`: Warband group only when `A.FEATURES.warbandBank`. Keep merging all purchased containers into one group; do **not** add page tabs.
- Add the line "Buy more bank slots in Blizzard's bank" with a button that uses the existing "beside" path to show Blizzard's frame. One new string in `Locale/enUS.lua`.
- Never call `SetTab`, never write Blizzard's bank frame (unchanged rule).
- Specs in `spec/bankwindow_*`: fewer purchased containers than the maximum; Warband absent; both present.

### 6. Check and conflict review
- `scripts/check.sh` green; `luacheck` globals for `WOW_PROJECT_CAMELOT`.
- Review `A.OTHER_BAG_ADDONS` against what loads on Forever (Baganator, Syndicator, Bagnon, ElvUI).

### 7. `scripts/release.sh` (R§6)
- Add `FOREVER_TYPE=88568`. Map each TOC Interface (`16???` to Forever, else Retail), convert `16001` to version name `1.60.1`, send both groups in one upload's `gameVersions`.
- `--dry-run` only. It must show whether CurseForge already lists `1.60.1`; if not, say so and stop.

### 8. In-game verification round (needs a Forever client; one checklist, results written to `research/`)
Each item is yes/no and ends with a fix or a "known limit":
1. `/dump select(4, GetBuildInfo())`, `WOW_PROJECT_ID`, `A.IsForever()`.
2. Bags open, items correct, sort works (`C_Container.SortBags`).
3. Bank bag IDs and `C_Bank.ShouldUsePlayerBagsInBank()` value.
4. Bank window with Blizzard's frame hidden and shown; the tab buttons host cleanly (`UI/TinyHost.lua`).
5. Buying a bank slot works from Blizzard's frame.
6. Warband: exists, deposits, gold.
7. Guild bank exists or not.
8. Item tooltips and overlays; no errors in `/swagbag report`.
9. Secret values inside an instance (`A.SlotIsSecret` path).
10. Any other bag add-on conflict.

### 9. Fix round
Whatever step 8 finds. Each fix gets a spec. Anything that cannot be fixed in launch week becomes a feature gate and a note in the changelog.

### 10. Ship (the user's go required)
Version bump, `CHANGELOG.md` entry, CurseForge description mentioning Forever, `scripts/release.sh` as a full release (current default). Public GitHub push as lonezebra per the repo memory.

## Time

Steps 1–7: about 6–8 working days. Step 8: 1–3 days, depending on client access. Step 9: 1–3 days. Realistic: a verified release 2 weeks after step 1 starts, or launch week if step 1 starts now and a Forever client is available on launch day.

## Open items that block nothing now

- The live Interface number; add it to the TOC when it is known.
- Whether CurseForge lists the Forever game version before launch (decides when `--dry-run` can pass).
- Whether the user has Forever access before launch day.
