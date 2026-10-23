# SwagBag on World of Warcraft: Forever — go/no-go report

Date: 2026-10-22. Forever launches 2026-11-04 (13 days out). Its beta ends 2026-10-23 (tomorrow).
Scope: research only. No addon code was changed.

## Recommendation: GO, in two stages. Do not upload a Forever build until it has run in a Forever client.

SwagBag is much closer to Forever than "Retail-only" suggests. Forever is built on the **Midnight (12.1.x) client**, not on Classic Era. Its bag and bank API is the same `C_Container` / `C_Bank` / `Enum.BankType` API SwagBag already uses.

The costs are real but small:

1. Forever's bag IDs differ from Retail's, and SwagBag hardcodes Retail's.
2. About a dozen Retail-only features must be hidden.
3. Forever's bank is a Classic-style bank-bag bank drawn on top of the Retail bank frame, which needs a design decision (section 4).

| Stage | What | When | Effort |
|---|---|---|---|
| A. Prepare | Interface list, Enum-derived bag IDs, Forever detection, feature gating, tests. Ships nothing new to Retail players. | Now, before launch | ~1 week (3–5 working days of coding) |
| B. Verify and ship | Run it in a Forever client, fix what the client disagrees with, then upload to CurseForge as a Forever file. | Launch week (from 2026-11-04) | ~1 week, mostly waiting on in-game checks |

**Total: about 2 weeks to a verified release, 1 week if the in-game checks go cleanly.**

Why not "don't": the biggest risk (the API being different) turned out not to be real.
Why not "ship at launch regardless": Forever's TOC number, game type and bank behavior are still moving, and the product principle is "never break". A broken first impression on a new client is worse than a one-week wait. SafeMode would catch a missing API, but it cannot catch the wrong bag IDs.

---

## 1. Forever's client

Evidence: Blizzard's FrameXML mirror `Gethe/wow-ui-source`, branch **`forever`**, commit `ca8368f`, build **1.60.1.70532**, committed 2026-10-22. The `live` branch at the same time is 12.1.5 (70529). This is the strongest source in the report.

| Fact | Value | Source quality |
|---|---|---|
| Beta Interface number | **16001** (client version 1.60.1) | warcraft.wiki.gg TOC page; matches `version.txt` 1.60.1.70532 |
| Live Interface number | **Not listed** on the wiki. Unknown until launch. Assume 160xx. | Horizon-Suite issue #492 warns launch may use a different number |
| Project ID | `WOW_PROJECT_CAMELOT = 18`, and `WOW_PROJECT_ID = WOW_PROJECT_CAMELOT` | Blizzard source (`Blizzard_ProjectConstants/Camelot/ProjectConstants.lua`) |
| Game type | `camelot` (alias `forever`). Blizzard has said the internal name may be renamed before launch. | Wiki + fan guides |
| Base API generation | **Midnight 12.1.x**. The `forever` branch has the same Blizzard add-on set as `live` plus Classic-style overrides in `Camelot/` folders. Midnight's secret values apply. | Blizzard source; fan guides say the same |
| Not Classic Era | Classic Era is 11509 with the old API. Forever has `C_Container`, `C_Item`, `C_Bank` and `Enum.BankType`. | Blizzard source |
| Experience preset | `C_GameRules.GetForeverExperiencePreset()` returns `Classic` (0) or `Modern` (1). Blizzard's UI reads it only for graphics and nameplate defaults. | Blizzard source |

Cautions:

- The fan sites (wowforeverguides.com, wofwforever.com and others) give conflicting numbers for builds 69913, 70170 and 70338 (project ID 1 vs 18). Treat them as hints. The Blizzard source is the authority.
- 16001 is the beta number. If launch uses another number, the addon shows "out of date" on launch day unless it lists the right one. That is cosmetic: players can tick "Load out of date AddOns", but it reads as "broken" to many players.

### TOC rules for multi-flavor addons (warcraft.wiki.gg/wiki/TOC_format)

- `## Interface:` takes a comma list, for example `120105, 16001`. If none match the client, the addon is flagged out of date. Comma lists work since 10.2.7.
- File-name suffixes, most specific first:
  - **`SwagBag_Forever.toc` or `SwagBag_Camelot.toc`**: Forever only.
  - **`SwagBag_Mainline.toc`**: family fallback covering standard, forever, camelot, plunderstorm and wowhack.
  - **`SwagBag.toc`**: used if neither of the above exists.
- Note the trap: `_Mainline.toc` also matches Forever. Today's plain `SwagBag.toc` would also load on Forever.
- The wiki recommends one TOC with comma Interface values over several TOC files.
- **Recommended for SwagBag:** keep a single `SwagBag.toc` and set `## Interface: 120105, 16001` (add the launch number when known). The file list is the same for both clients, and the code decides at runtime. A `SwagBag_Forever.toc` is only needed if Forever must load a different file list. It would then have to be kept in sync by hand (`scripts/check.sh` checks the TOC).
- The BigWigs packager maps the prefix `16???` to "forever", and `--game-type forever` and `camelot` are both accepted.

---

## 2. Bag, bank and item APIs on Forever

Method: diffed the `forever` and `live` branches of `Gethe/wow-ui-source`: the generated API documentation, the Camelot bank frame, the TOCs, and Blizzard's `LoadOnDemand` add-on game-type rules. **The API docs describe the API surface; they do not prove each call works at runtime on a Forever client.** Items marked ✔ below are "present in Blizzard's own Forever source".

| Area | Forever | Notes |
|---|---|---|
| `C_Container.*` | ✔ identical to Retail. `ContainerDocumentation.lua` has **no diff** between the branches. | `SortBags`, `SortBank`, `SortBankBags`, `SortAccountBankBags`, `UseContainerItem` (with the bank-type argument), `PickupContainerItem` and `Get/SetSortBagsRightToLeft` all exist |
| `C_Item` | ✔ a superset. Forever adds `DeleteItem`, `ConfirmDeleteItem` and `GetWeaponEnchantInfo`. | Global `GetItemInfo` was reported missing on beta build 69913 (fan guide, unverified). SwagBag already uses `C_Item.GetItemInfo`. |
| `C_NewItems` | ✔ no diff | |
| `TooltipDataProcessor` | Not checked in this pass. The Midnight tooltip system is part of the shared base. | In-game check |
| `C_Bank` | ✔ same as Retail, plus 3 additions: `FetchMaxNumBankTabs(bankType)`, `BankBagTypeAndIDToInvSlot(bankType, slot)` and **`ShouldUsePlayerBagsInBank()`** | The last one is new and decides how the bank looks (below) |
| Bank types | `Enum.BankType.Character` and `Enum.BankType.Account` both exist. The Warband bank is present with "account bank page N" tabs. | |
| **Bag IDs** | **Different from Retail** (see below) | **Biggest code impact** |
| Reagent bag | `Enum.BagIndex.ReagentBag = 5`, same as Retail | |
| Keyring | `Enum.BagIndex.Keyring = -1` exists on both | |
| Guild bank | `Blizzard_GuildBankUI` loads under the `mainline` family rule, which includes Forever. The old `GetGuildBank*` API is documented. | Whether guilds have a bank in Forever's rules is an in-game check |
| Auction House | `Blizzard_AuctionHouseUI` is `mainline`, so it loads | Auctionator and TSM may work, in-game check |
| Secret values | ✔ active (Blizzard said so; fan guides report `UnitHealth` secrets on beta). `issecretvalue` exists. | SwagBag's `A.IsSecret` and `pcall` pattern already covers this |
| Taint / protected actions | The Camelot bank frame is Blizzard's Retail `BankFrameMixin` with `BankPanel`, `TabSystem` and secure item buttons. `SetTab` writes frame state exactly as on Retail. | SwagBag's "never call `SetTab`, never write Blizzard's bank frame" rule carries over unchanged |

### The bag ID change (affects `A.BagKind`, `A.GetBagIDs`, three `Enum.*` checks)

| Container | Retail 12.1.5 | Forever (build 70532) |
|---|---|---|
| Character bank tabs | `CharacterBankTab_1..6` = **6–11** | `CharacterBankTab_1..9` = **6–14** |
| Warband bank tabs | `AccountBankTab_1..5` = **12–16** | `AccountBankTab_1..9` = **15–23** |
| Extra names | none | `Characterbanktab = -2`, `Accountbanktab = -3` (used by the bank-bag slot buttons) |

`A.BagKind` currently hardcodes `6..11` as bank and `12..16` as warband. On Forever that would mislabel Warband tab 1 as character bank tab 7 and break the checks `Enum.BagIndex.AccountBankTab_1 == 12` (a **required** check, so SafeMode would switch the bank window off on Forever). It is a contained fix: derive the ranges from `Enum.BagIndex` names instead of numbers. `A.BANK_TAB_CAPACITY = 98` (slots per tab) should also be re-checked: Forever's bank frame shows 88 slots per page.

---

## 3. SwagBag's dependencies, mapped to Forever

Source: `SwagBag/Core/Adapter.lua` (2011 lines) and its `A.CHECKS` list (about 120 paths). I also ran every `C_*` path in `A.CHECKS` against Forever's API docs.

Result: **all but four** `C_*` paths are present in Forever's docs. The four that are not are `C_PartyInfo.IsDelveInProgress` (a name lookup miss; the doc exists), `C_PetJournal.GetNumCollectedInfo`, `C_PetJournal.GetPetInfoByItemID` and `C_ToyBox.GetToyInfo`. The last three are missing from Retail's docs too, so they already fall back today.

Key: ✅ works as is · 🔧 needs a change or alternative · 🚫 switch off on Forever.

### Adapter functions

| Adapter function(s) | Status | Note |
|---|---|---|
| `GetSlot`, `NumSlots`, `SlotIsSecret`, `GetItemInstant`, `GetItemInfo`, `GetIlvl`, `GetLinkIlvl`, `RequestLoad`, `CursorItem`, `CursorBusy`, `ClearCursor`, `SpellTargeting`, `MoveStack`, `SellItem`, `Repair`, `RepairCost`, `BuybackLinks`, `Money`, `MoneyText`, `IsOnCooldown`, `InEquipmentSet`, `IsQuestItem`, `ShiftDown`, `ModifiedClick`, tooltip helpers, `ClassColour`, `QualityColor` | ✅ | Same API, same signatures |
| `SortBags` | ✅ | Identical. In-game: does the sort order match Classic's expectations? |
| `ClearNewItem(s)` | ✅ | `C_NewItems` is unchanged |
| `ITEM_CLASS`, `*_SUB` tables, `BindKind` | ✅ | Already read from `Enum`. In-game: check class IDs, `Housing = 20` may not exist. |
| `BagKind`, `GetBagIDs`, `BagFamily` | 🔧 | Hardcoded Retail ranges. Derive from `Enum.BagIndex` (section 2). |
| `BANK_TAB_CAPACITY`, `BAG_CAPACITY` | 🔧 | Check Forever's maximum bag and bank-container sizes |
| `SortBank(kind)`, `MoveToBank`, `AllowedInBank` | ✅ for `"bank"` · 🔧 for `"warband"` | Same call and bank-type argument. Verify the warband sort button works. |
| `ActiveBankType` | ✅ | `BankFrame:GetActiveBankType()` is `BankFrameBaseMixin`, which Forever keeps |
| `WarbandDepositState`, `RefundableForWarband`, `DepositWarband`, `DepositReagents`, `SetDepositReagents` | ✅ if Warband is on · 🚫 if not | Same `C_Bank` API. Gate on a Warband check (below). |
| `WarbandMoneyState`, `WarbandMoney`, popups | 🔧 | `C_Bank.FetchDepositedMoney` is present, so Warband gold may exist. Gate on `DoesBankTypeSupportMoneyTransfer` and `CanViewBank(Account)`. |
| `Guild*` functions, `GuildBankMoney`, `IsGuildBanker`, `GuildTabFrames` | 🔧 | The Blizzard UI loads on Forever. Keep it feature-detected: hide it if `Enum.PlayerInteractionType.GuildBanker` or the API is absent. |
| `HookItemTooltip`, `SlotTooltip`, `TooltipLine` | 🔧 | In-game check that the item tooltip hook fires on Forever |
| `UpgradeInfo`, `IsWarboundUntilEquip` | 🚫 | Upgrade tracks and Warbound items are Retail-only. `Blizzard_ItemUpgradeUI` does load (mainline rule), so the data may exist. In-game check. |
| `BackpackCurrencies`, `CurrencyInfo`, `CurrencyList` | 🔧 | `Blizzard_TokenUI` is present. Forever's currency set differs. In-game check. |
| `IsToy`, `ToyKnown`, `MountKnown`, `PetKnown`, `DecorKnown`, `AppearanceKnown` | 🔧 / 🚫 | `Blizzard_Collections` loads, `Blizzard_Transmog` and `Blizzard_Wardrobe` are in the Camelot lists. `DecorKnown` (housing) is 🚫. Everything else is feature-detected and falls back to "no data". |
| `DungeonName`, `InstanceInfo`, `ChallengeModeActive`, `IsChallengeModeRestriction`, `InDelve` | 🚫 | `Blizzard_ChallengesUI` loads for `standard, mists` only. `Blizzard_DelvesDifficultyPicker` and `Blizzard_HousingDashboard` are `standard` only. No M+ or Delves on Forever. |
| `IsScrapper`, `ScrapperItemIDs` | 🔧 | `Blizzard_ScrappingMachineUI` has no game-type rule, so it loads. Gate on the API. |
| `IsFishingLoot`, `LootSourceType`, `GatheringProfessions` | ✅ | |
| `AuctionatorAvailable`, `TSM*`, `MasqueAvailable`, `Syndicator*` | ✅ if the add-on is present | Baganator, Syndicator and Bagnon list Forever files (third-party guide, unverified). Syndicator's own bank-bag layout is their problem. |
| `ElvUIBagsOn`, `OtherBagAddons` | ✅ | Add Forever-relevant names if any appear |
| `PawnUpgrade`, `HasPawn` | ✅ if present | |

### A.CHECKS that will fail on Forever

Each failed `required = true` check turns on SafeMode for its window, which falls back to Blizzard's bags or bank. That is the designed behavior but not what we want on a supported client.

| Check | Forever result | Fix |
|---|---|---|
| `Enum.BagIndex.AccountBankTab_1 == 12` (required, bank) | **Fails** (value 15) | Remove the numeric expectation, or make the expected value per-client |
| `Enum.BagIndex.CharacterBankTab_1 == 6` | Passes | |
| `BankFrame.TabSystem` (required, bank) | Probably passes (Forever keeps `BankFrameBaseMixin`), **in-game check** | |
| `BankFrame.GetActiveBankType` (required, bank) | Probably passes | |
| `C_ChallengeMode.IsChallengeModeActive`, `C_PartyInfo.IsDelveInProgress` | Non-required. Present as API, but the feature is off. | Gate on client, not on the API |
| `C_HousingCatalog.GetCatalogEntryInfoByItem` | Non-required | Gate off |

### Features that must be hidden or switched off on Forever

| Feature | Why | Where in SwagBag |
|---|---|---|
| M+ keystone and crest handling | No Challenges UI. No Mythic+. | `Engine/Crests.lua`, keystone category and signals, `A.IsChallengeModeRestriction` |
| Delves signals | `standard` only | `A.InDelve`, `A.DELVE_DIFFICULTY` |
| Upgrade tracks and upgrade overlays | Retail's upgrade system. May partly exist. | `A.UpgradeInfo`, overlay data |
| Housing / decor | `standard` only | `A.DecorKnown`, `C_HousingCatalog` |
| Warbound / WUE bind kinds, Warband gold | Warband bank exists in the Forever bank frame, but whether the rest of the account-wide system is on is unknown. Gate by API. | `A.BindKind`, `A.WarbandMoney*` |
| Warband bank (group and tab) | Present in Blizzard's source; in-game check whether it is *enabled* | `UI/BankWindow.lua`, `UI/GroupView.lua`, `UI/BankMenu.lua` |
| Profession-quality / crafting-quality overlays | Midnight-only crafting | Overlays |
| Expansion-specific category defaults | Midnight item IDs | `Engine/CategoryDefaults.lua`, `Engine/Consumables.lua`, `Engine/Keywords.lua` |

Detection rule: **gate on the project constant plus the specific API, never on the Interface number.** Use `WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`, then `A.CHECKS`-style feature checks for each feature. The Interface number is for logs only, because its launch value is unknown. Put the detection in `Adapter.lua` (`A.IsForever()`), the only file that touches the game API.

---

## 4. Bank window design on a Classic-style bank

What Blizzard's Forever bank actually is (`Blizzard_UIPanels_Game/Camelot/BankFrame.lua`):

- It is Retail's `BankFrame`, `BankPanel` and `TabSystem` with a Camelot skin: `[Game]\BankFrame.lua [AllowLoadGameType camelot]`, 88 slots per page.
- The character bank is bought as **"bank bag slots"**: `RefreshBagButtons` draws buttons for bank bags 2 to `FetchMaxNumBankTabs`, with a cost label and a purchase button. Slot 1 is free and bought automatically (`PurchaseFirstSlot`).
- When `C_Bank.ShouldUsePlayerBagsInBank()` is true, the per-tab side buttons are not built. All purchased containers are shown as **one continuous grid split into pages** (`GetTotalSlotsInAllTabs`, `RefreshPageTabs`, page tabs on the right of the frame). Retail has no such function; it is new in Forever.
- The Character and Warband (`Enum.BankType.Account`) choice stays as the `TabSystem` tabs, so `BankFrame:GetActiveBankType()` still works.

Compared with `UI/BankWindow.lua`, which hosts the real `TabSystem` buttons inside SwagBag's header and never calls `SetTab`:

| Retail design | Forever |
|---|---|
| Groups are "Character bank" and "Warband bank", each made of purchased tabs from `FetchPurchasedBankTabIDs` | ✅ **Keep.** The same API returns Forever's purchased containers (IDs 6–14, 15–23). SwagBag already merges all tabs of a bank into one set of category sections, so it already shows the combined view that Blizzard's pages imitate. |
| Header shows Blizzard's real tab buttons (Bank / Warband Bank) | ✅ **Keep.** `BankFrame.TabSystem` exists on Forever. Check the button sizes against the Camelot skin. |
| Never call `SetTab` (the taint rule) | ✅ **Keep, unchanged.** The Camelot `SetTab` also writes frame state that a secure click reads. |
| "Show Blizzard's bank" / "beside" mode, with tab purchase in Blizzard's frame | ✅ **Keep, and now more needed.** Bank-bag slots are bought in Blizzard's frame (`BankFramePurchaseButton`), and SwagBag does not buy them. |
| A tab-strip in SwagBag's header for individual tabs | n/a. SwagBag has none; it shows every tab together. Do not add one for Forever. |
| Per-tab capacity `BANK_TAB_CAPACITY = 98` | 🔧 Forever pages at 88. Size the button pool from `GetContainerNumSlots` per container, not a constant. |
| "Free" and "New" tiles (items only move into New or Free) | ✅ Keep. Check that profession-bag families in the bank behave (`GetContainerNumFreeSlots` family). |

**Proposed behavior on Forever:** the same window as Retail. Character bank group on top, all purchased bank-bag slots merged into it. The Warband group is shown only if `CanViewBank(Account)` is true. No page tabs, because SwagBag has its own scroll area. When the player has bought fewer than the maximum bank bags, the header shows a short "Buy more bank slots in Blizzard's bank" line with a button to show Blizzard's frame. This reuses the "beside" path. It adds one new string, not new machinery.

Unknown: if `ShouldUsePlayerBagsInBank()` is **false** on a Forever preset (Classic vs Modern), Forever shows Retail-style tabs instead and everything in the Retail column already applies. Both cases work with SwagBag's merged view, so this is a "does it look right" check, not a blocker.

---

## 5. Effort and risk

### Estimate

| Step | Work | Time |
|---|---|---|
| 1 | `A.IsForever()` plus project/feature detection; tests with fake `WOW_PROJECT_*` | 0.5 day |
| 2 | `Interface` list in the TOC; `scripts/check.sh` and `luacheck` globals for `WOW_PROJECT_CAMELOT` | 0.5 day |
| 3 | Derive bag-ID ranges from `Enum.BagIndex`; fix `A.CHECKS` numeric expectations; capacity from slot counts | 1 day |
| 4 | Gate features: M+/keystone/crests, Delves, upgrade, housing, Warband gold and bind kinds | 1–2 days |
| 5 | Bank window: Forever-only text (buy more bank slots), width and skin checks, Warband group gating | 1–2 days |
| 6 | Defaults review: category, consumable and keyword lists on Forever item sets | 1 day, mostly data |
| 7 | In-game verification round (needs a Forever client) | 1–3 days wall-clock |
| 8 | `scripts/release.sh`: add the Forever type (section 6); changelog and CurseForge description | 0.5 day |

**Total ≈ 6–8 working days of code plus verification, calendar ≈ 2 weeks.** SwagBag has about 82 spec files, so most of steps 1–5 gets a regression test.

### Biggest unknowns (need an in-game Forever client)

1. **Is the TOC number at launch still 16001?** Unknown until launch. Mitigation: list both and add the launch number in a point release.
2. **Does `WOW_PROJECT_ID` really equal 18 on launch?** Blizzard said the Camelot name will change. Mitigation: detect by *feature* (`C_Bank.ShouldUsePlayerBagsInBank` exists and `Blizzard_ChallengesUI` does not) as well as by constant.
3. **`ShouldUsePlayerBagsInBank()` value** and whether bank containers fill 6–14 in order.
4. **Does the Warband bank exist and work on launch?** And Warband gold.
5. **Does Forever's `BankFrame.TabSystem` host cleanly in SwagBag's header** (`UI/TinyHost.lua` hosting a different skin)?
6. **Secret values in bags:** does Forever return secret item data inside instances? Midnight does. SwagBag's `SlotIsSecret` path exists but was only tested against Retail.
7. **Tooltips and Overlays:** the item tooltip hook, upgrade and bind lines.
8. **Guild bank:** does Forever have one? The Blizzard UI loads, the game rules are unknown.
9. **Other bag add-ons** loading on Forever (Baganator, Syndicator, Bagnon, ElvUI): `OtherBagAddons` needs a conflict check.

### Biggest risks

- **Access.** I cannot say whether the user has a Forever beta key. Beta ends tomorrow, and launch is 11 days later. If there is no beta access, the first look at a real client is launch day.
- **Scope creep.** Forever is a different game with different loot. Do not tune categories for Classic item sets in this port. Ship "works and is honest" first.
- **A "Forever" release of an untested bank window.** Mitigation: SafeMode already falls back to Blizzard's bank on a failed required check. Keep that, and run the first Forever build behind a documented opt-in (a `/swagbag` flag) if the verification round turns up surprises.

---

## 6. CurseForge

- The BigWigs packager maps `forever` to **game-version type ID `88568`** (`release.sh`'s `case $type in … forever) game_id=88568`). Its other values match what we see for the older types: classic 67408, bcc 73246, wrath 73713, cata 77522, mists 79434, titan 81212, and the default **517** for Retail.
- The packager derives the version name from the TOC: Interface `16001` becomes version name **`1.60.1`**, which matches the client's own 1.60.1 build number.
- It looks the name up in `GET <site>/api/game/wow/versions` and picks the entry whose `gameVersionTypeID` equals the type ID.
- **Not verified:** I did not call CurseForge, because that needs the Keychain token. Whether `1.60.1` (and the launch version) already exist in that list is unknown. If CurseForge adds the Forever version only at launch, an upload before 2026-11-04 may fail the lookup.
- **How `scripts/release.sh` must change:**
  1. Add `FOREVER_TYPE=88568` next to `RETAIL_TYPE=517`.
  2. Map each TOC Interface number to a type: `16???` goes to the Forever type, everything else to Retail.
  3. Convert the number to a version name (`16001` to `1.60.1`; the Retail code does the same for `120105`).
  4. Send both type groups in one upload's `gameVersions`. The packager does this too.
  5. `--dry-run` already does the lookup, so run it first at launch and read what it says about `1.60.1`.
- One file with both Retail and Forever versions attached is the simplest. A separate file is only needed if the Forever build ever has a different file list.

---

## Step list (could become a plan)

1. **Detection.** `A.IsForever()` in `Core/Adapter.lua` (project constant, then feature fallback). Specs with a fake `WOW_PROJECT_CAMELOT`.
2. **TOC.** `## Interface: 120105, 16001`. Add the launch number when it is known.
3. **Bag IDs.** `A.BagKind`, `A.GetBagIDs` and `A.CHECKS` read `Enum.BagIndex.*` names, not numbers. Specs for both layouts (Retail 6–11 / 12–16, Forever 6–14 / 15–23).
4. **Capacity.** Bank button pools sized from `GetContainerNumSlots`, not `BANK_TAB_CAPACITY`.
5. **Gating.** Put M+/keystones/crests, Delves, upgrades, housing, Warband gold and bind kinds behind `A.CHECKS`-style feature flags. Hide their Settings pages on Forever.
6. **Bank window.** Warband group only when `CanViewBank(Account)`. Add the "buy more bank slots" line and the Blizzard-frame button.
7. **Specs and check.** `scripts/check.sh` green on both client profiles.
8. **Release script.** Add type 88568 and the Interface-to-type mapping. `--dry-run`.
9. **In-game round** (Forever client): each unknown in section 5, one by one. Fix what fails.
10. **Ship.** Changelog entry, version bump, CurseForge description mentions Forever. Upload as a full release only after step 9 is clean.

## Sources

Primary (Blizzard's own source, build 1.60.1.70532 on 2026-10-22):
- [Gethe/wow-ui-source `forever` branch](https://github.com/Gethe/wow-ui-source/tree/forever): `Blizzard_UIPanels_Game/Camelot/BankFrame.lua`, `Blizzard_APIDocumentationGenerated/BagIndexConstantsDocumentation.lua`, `BankDocumentation.lua`, `ContainerDocumentation.lua`, `Blizzard_ProjectConstants/Camelot/ProjectConstants.lua`, and the add-on TOCs for ChallengesUI, GuildBankUI, ItemUpgradeUI and others
- [Gethe/wow-ui-source `live` branch](https://github.com/Gethe/wow-ui-source/tree/live) (12.1.5, 70529), for the diff

Secondary:
- [Warcraft Wiki: TOC format](https://warcraft.wiki.gg/wiki/TOC_format): Interface table, `_Forever` / `_Camelot` / `_Mainline` suffix rules
- [BigWigsMods/packager `release.sh`](https://github.com/BigWigsMods/packager/blob/master/release.sh): the `16???` to forever mapping and CurseForge type 88568
- [Horizon-Suite issue #492: Forever launch day: TOC interface and platform detection](https://github.com/Tacit-Labs/Horizon-Suite/issues/492)

Fan sites (unverified, mixed builds, used only for context): [wowforeverguides.com API cheat sheet](https://wowforeverguides.com/addons/api-cheatsheet), [wowforeverguides.com patterns](https://wowforeverguides.com/addons/patterns), [wowforeverguides.com addons](https://wowforeverguides.com/addons), [wow4ever.quest addons](https://wow4ever.quest/en/addons).

What I did not find: a Forever-specific beta addon-notes or bug thread from Blizzard on bags or bank, and any statement of the launch Interface number.
