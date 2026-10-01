# Week 1 final-review fix list (apply all, in order)

1. ErrorTrap must never throw — SwagBag/Core/ErrorTrap.lua
   - In the xpcall handler (~lines 94-97): `local okS, st = pcall(SB.Adapter.Stack)`; use `stack = okS and st or ""`.
   - After the xpcall (~line 100): `caught = caught or { message = "error in error handler", stack = "" }`.
   - (~line 101) call `pcall(ET.OnError, label, window, caught.message, caught.stack)` instead of a direct call.
   - Attach (~lines 36-42): `if type(list) ~= "table" then return end` at the top.
   - Tests (spec/errortrap_spec.lua): Run returns false (no throw) when Adapter.Stack throws; Run returns false (no throw) when SB.Print throws AND the window still flips to Safe Mode; Attach(nil) keeps the ring working.

2. Only auto-close a window the game auto-opened — SwagBag/UI/SafeModeHooks.lua (~60-69, onBagKey ~40-50)
   - OpenAllBags hook (frame): if the window was closed and SB.BagsWindow.Open() returns true, set `Hooks.autoOpenedBy = (frame and frame.GetName and frame:GetName()) or true`; if it was already open, leave autoOpenedBy unchanged.
   - CloseAllBags hook (frame): if frame == nil → close and clear autoOpenedBy; otherwise close only if autoOpenedBy is set and (== frame's name or == true), then clear it.
   - onBagKey clears Hooks.autoOpenedBy.
   - Tests (spec/safemodehooks_spec.lua; give the fake BagsWindow IsOpen and an Open returning true): user-opened window stays open after CloseAllBags(MerchantFrame); OpenAllBags(F)-opened window closes on CloseAllBags(F); CloseAllBags() with no frame closes.

3. Search error must not be cut off — SwagBag/UI/SearchBox.lua (~21-25)
   - SetWordWrap(true) plus `if errorLine.SetMaxLines then errorLine:SetMaxLines(2) end`; anchor TOPLEFT to the box's TOPRIGHT (+8, +4) and RIGHT to the frame (-8).
   - Extend the searchbox test to assert word wrap is on.

4. Bag-bar icons work — SwagBag/UI/SafeModeHooks.lua (~52-59)
   - `if ToggleBag then hooksecurefunc("ToggleBag", Guard("hook:ToggleBag", function(id) if SB.Buttons.KindOf(id) == "bags" then onBagKey() end end, "bags")) end` — must not react to bank/warband IDs.
   - Add `{ path = "ToggleBag", window = "bags", required = false }` to Adapter.CHECKS (SwagBag/Core/Adapter.lua near ~344) in the same style as existing entries.
   - Add ToggleBag to .luacheckrc read_globals if needed.
   - Tests: ToggleBag(1) toggles once; ToggleBag(6) does nothing; ToggleBag + ToggleBackpack in the same frame toggles once.

5. Login failure must be loud — SwagBag/Core/Boot.lua (~39)
   - PLAYER_LOGIN handler window "none" → nil (both windows). Update spec/boot_spec.lua if it asserts "none".

6. V1 strip guards — SwagBag/UI/DebugV1.lua (~25-30)
   - Pass "none" as the window argument to both drag Guard calls.

7. Client position cache — SwagBag/UI/BagsWindow.lua (after frame creation ~25)
   - `if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end`

Finally: scripts/check.sh must print ALL CHECKS PASSED.
