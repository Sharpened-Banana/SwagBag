# Warband bank gold: deposit and withdraw from an addon (2026-10-13)

Question: can SwagBag's own plain buttons deposit and withdraw gold to and from the Warband (account) bank safely, with no taint and no "Interface action failed"?

Sources are read from clones of the live repos on 2026-10-13. Blizzard source is Gethe/wow-ui-source at "12.1.5 (70391)". The addon repos were cloned at HEAD on the same day.

## Verdict

- The API calls are callable by addons. Nothing marks them protected, and nothing requires a hardware event. Confidence: high that they are not protected, medium-high that they work from an addon click handler (never run in-game here).
- Blizzard's own popups "BANK_MONEY_DEPOSIT" and "BANK_MONEY_WITHDRAW" are safe to reuse. ElvUI, BetterBags and Baganator all do exactly this. This is the proven route.
- A custom popup that calls `C_Bank.DepositMoney` or `C_Bank.WithdrawMoney` directly looks equally fine on paper. No shipping addon does it, so it is untested.
- The character bank has no gold storage. Confirmed from the patch notes only by absence, plus the code path in section 4. Needs a 10-second in-game look.

## 1. Blizzard API

Source: `Interface/AddOns/Blizzard_APIDocumentationGenerated/BankDocumentation.lua` (Gethe/wow-ui-source, live branch):
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/BankDocumentation.lua

| Function | Args | Returns | Restriction in the docs |
|---|---|---|---|
| `C_Bank.DepositMoney` | `bankType`, `amount` (WOWMONEY, copper) | none | `SecretArguments = "AllowedWhenUntainted"` |
| `C_Bank.WithdrawMoney` | `bankType`, `amount` | none | same |
| `C_Bank.CanDepositMoney` | `bankType` | bool | same |
| `C_Bank.CanWithdrawMoney` | `bankType` | bool | same |
| `C_Bank.FetchDepositedMoney` | `bankType` | amount | same |
| `C_Bank.DoesBankTypeSupportMoneyTransfer` | `bankType` | bool | same |

Facts:

- `Enum.BankType` is `Character=0`, `Guild=1`, `Account=2`. Source: `ItemConstantsDocumentation.lua`, line 6 onward.
- `SecretArguments = "AllowedWhenUntainted"` is about the 12.0 "secret values" system. It only matters if you pass a secret value as an argument. Plain numbers are fine. Wiki pages say the same and list no other restrictions: https://warcraft.wiki.gg/wiki/API_C_Bank.DepositMoney , https://warcraft.wiki.gg/wiki/API_C_Bank.WithdrawMoney , https://warcraft.wiki.gg/wiki/API_C_Bank.CanDepositMoney
- There is no "Protected", "HardwareEvent" or "NotInCombat" marker on any of these functions in the generated docs. Confidence: high. Caveat: the docs generator does not always expose server-side rules, such as the bank needing to be open, so "not marked" is not proof it works anywhere.
- The wiki pages are stubs: no notes section and no stated patch. 11.2.0 added `DoesBankTypeSupportMoneyTransfer`, `DoesBankTypeSupportAutoDeposit` and `FetchBankLockedReason`: https://warcraft.wiki.gg/wiki/Patch_11.2.0/API_changes
- Event `ACCOUNT_MONEY`: synchronous, no payload. Fired when Warband gold changes. Source: `CurrencyInfoDocumentation.lua` line 589, and https://warcraft.wiki.gg/wiki/ACCOUNT_MONEY . Blizzard's bank panel registers it (`BankFrame.lua`, around line 597). `PLAYER_MONEY` covers the character's own gold.
- I found no `BANK_MONEY_UPDATE` event for the account bank. Treat that name as nonexistent.
- Does the bank need to be open? Not documented. Blizzard only shows the buttons inside the bank panel, so the in-game behaviour when the bank is closed is unknown. Likely the server rejects it and the game prints an error. Open doubt, see below.

## 2. How Blizzard's UI does it

Files are in `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/` at https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline

`BankFrame.lua`:

- `StaticPopupDialogs["BANK_MONEY_WITHDRAW"]` is at lines 156-179. `OnAccept` reads `MoneyInputFrame_GetCopper(dialog.MoneyInputFrame)` and calls `C_Bank.WithdrawMoney(data.bankType, amount)`. `EditBoxOnEnterPressed` does the same, then hides the dialog.
- `StaticPopupDialogs["BANK_MONEY_DEPOSIT"]` is at lines 181-204, with the same shape using `C_Bank.DepositMoney`.
- Both use `hasMoneyInputFrame = 1`, `timeout = 0` and `hideOnEscape = 1`. The only data they need is `data.bankType`.
- `BankPanelWithdrawMoneyButtonMixin:OnClick` (about line 1224) does: `PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)`; hide the other popup; if this popup is already visible, hide it and return; otherwise `StaticPopup_Show("BANK_MONEY_WITHDRAW", nil, nil, { bankType = self:GetActiveBankType() })`. The deposit button mirrors it.
- Enable logic: each button's `Refresh()` shows it if `C_Bank.DoesBankTypeSupportMoneyTransfer(bankType)`, and enables it if `C_Bank.CanWithdrawMoney(bankType)` or `C_Bank.CanDepositMoney(bankType)`. It sets a disabled tooltip of `ACCOUNT_BANK_ERROR_NO_LOCK` when the active bank type is locked.
- The money display is `BankPanelMoneyFrameMixin` (XML: `BankFrame.xml` lines 186-225). Its `MoneyDisplay` is a `SmallMoneyFrameTemplate` whose type is "ACCOUNT" or "PLAYER". The "ACCOUNT" type reads `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` and registers `ACCOUNT_MONEY` (`Blizzard_MoneyFrame/Shared/MoneyFrame.lua`, around line 50-62).
- Blizzard disables the click-to-popup on the coin buttons in the bank panel (`DisableMoneyPopupFunctionality`).

Reusing the popups from an addon: this works in practice because the popup table entries are Blizzard code, and the call to `C_Bank.*` happens from Blizzard's untainted `OnAccept`. Addons only call `StaticPopup_Show` with a `data` table. Confidence: high, since three major addons ship it (below).

Risk to know: `StaticPopup_Show` from addon code is a common taint path in general, because it allocates one of the shared popup frames. If an addon taints the popup frame, other popups can break. The proven addons show these particular popups without reported problems in their issue trackers, but I could not verify absence of taint reports exhaustively (see section 3).

## 3. Other bag addons

| Addon | Warband gold buttons | Call | Evidence |
|---|---|---|---|
| ElvUI | Yes, deposit and withdraw, plus a gold text updated by `FetchDepositedMoney` | `StaticPopup_Show('BANK_MONEY_WITHDRAW' / 'BANK_MONEY_DEPOSIT', nil, nil, { bankType = WARBANDBANK_TYPE })`. It guards with `StaticPopup_FindVisible` of the opposite popup. | https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/Modules/Bags/Bags.lua lines 2350-2370, 1670, 3908 (`ACCOUNT_MONEY`) |
| BetterBags | Yes, via a click on the warband money frame: left = withdraw, right = deposit | `StaticPopup_Show("BANK_MONEY_WITHDRAW" / "BANK_MONEY_DEPOSIT", nil, nil, {bankType = Enum.BankType.Account})` | https://github.com/Cidan/BetterBags/blob/main/frames/money.lua lines 52-65 |
| Baganator (doneykoo/Baganator) | Yes, real Withdraw and Deposit buttons, skinned, enabled by `C_Bank.CanDepositMoney` and `C_Bank.CanWithdrawMoney` (Enum.BankType.Account). The handlers copy Blizzard's button logic. | `StaticPopup_Show("BANK_MONEY_DEPOSIT" / "BANK_MONEY_WITHDRAW", nil, nil, { bankType = Enum.BankType.Account })` | https://github.com/doneykoo/Baganator/blob/main/ItemViewCommon/BankViewWarbandView.lua lines 166-167, 313-340 |
| Bagnon | Its changelog says "Retail: Added support for Warband Money deposit/withdrawal" (11.0.4). I did not find the code with a text search, so the exact call is unknown. | unknown | https://github.com/tullamods/Bagnon/blob/master/Changelog.md |
| ArkInventory | No evidence found. A search of its change history for warband/account money found nothing. | n/a | https://github.com/arkayenro/arkinventory |

Notes:

- No addon calls `C_Bank.DepositMoney` or `C_Bank.WithdrawMoney` directly. Every one of them goes through Blizzard's popups.
- Baganator's `WithdrawMoney` handler in the cloned source passes `textArg1, textArg2` that are never defined (they are nil globals), which is harmless.
- Issue search: I searched GitHub issues in Baganator, BetterBags and ElvUI for "warband gold", "deposit", "BANK_MONEY" and "DepositMoney taint". All returned zero hits. That is weak evidence of no known taint problems; GitHub's search is coarse, so treat it as "none found", not "none exist". Confidence: low-medium.
- Hidden risk: the three addons show the popup only while their bank frame is open (buttons live in the bank view). Nobody shows them away from the bank, so closed-bank behaviour is not exercised by their code.

## 4. Character bank has no gold

- Patch 11.2.0 API changes list no character-bank money API, and they removed the old reagent-bank/bank-slot globals: https://warcraft.wiki.gg/wiki/Patch_11.2.0/API_changes . This is absence of evidence, not an explicit statement.
- In Blizzard's code, the Withdraw and Deposit buttons only show when `C_Bank.DoesBankTypeSupportMoneyTransfer(bankType)` is true. The character-bank panel's money display uses type "PLAYER" (your own gold). `BankFrame.lua` `BankPanelMoneyFrameMoneyDisplayMixin:GetBestMoneyType` returns "ACCOUNT" only for the account bank, otherwise "PLAYER".
- The user's premise (character bank has no gold storage since 11.2) fits all of this. I could not confirm that `DoesBankTypeSupportMoneyTransfer(Enum.BankType.Character)` returns false. Confidence: medium-high.
- Implication for SwagBag: only call the money functions with `Enum.BankType.Account`, and gate on `C_Bank.DoesBankTypeSupportMoneyTransfer(Enum.BankType.Account)` and the `CanDeposit`/`CanWithdraw` functions.

## Recommended approach (facts only, not code)

1. Show a Warband gold readout using `C_Bank.FetchDepositedMoney(Enum.BankType.Account)`; refresh on `ACCOUNT_MONEY` and `PLAYER_MONEY`.
2. Make plain Deposit and Withdraw buttons. Enable each from `C_Bank.CanDepositMoney` or `C_Bank.CanWithdrawMoney` with `Enum.BankType.Account`, and refresh them on `ACCOUNT_MONEY` and when the bank opens or closes.
3. On click, copy Blizzard's pattern: hide the opposite popup, toggle this one with `StaticPopup_Visible`, then `StaticPopup_Show("BANK_MONEY_DEPOSIT" or "BANK_MONEY_WITHDRAW", nil, nil, { bankType = Enum.BankType.Account })`. A popup is needed if you want a typed amount; Blizzard's popup supplies the money input for free.
4. Do not use a hardware-event workaround, a secure template or `SetAttribute`. Nothing in the docs asks for it.

## Open doubts needing an in-game check

1. Does the popup's Accept work, with no taint or "Interface action failed", when SwagBag's button opens it while the bank is closed? Expected: it errors or does nothing, so keep the buttons disabled when `CanDepositMoney` / `CanWithdrawMoney` is false, and confirm those return false when the bank is closed.
2. Does calling the popup from SwagBag's frame leave any `ADDON_ACTION_FORBIDDEN` or "blocked from an action" message in `/console taintLog 2` after use? ElvUI/BetterBags/Baganator working suggests not, but confirm in 12.1.5.
3. Does `C_Bank.DoesBankTypeSupportMoneyTransfer(Enum.BankType.Character)` return false, and are Withdraw and Deposit absent in the character bank tab?
4. Do the money functions work from a plain (non-secure) button click handler, and does a custom popup calling them directly also work? Only worth testing if the Blizzard popups are unwanted.
5. Bagnon's and ArkInventory's actual behaviour was not confirmed.
