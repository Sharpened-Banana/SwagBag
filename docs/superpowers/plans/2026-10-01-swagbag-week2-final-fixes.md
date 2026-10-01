# Week 2 final-review fix list (apply all, in order)

1. C1 (CRITICAL) — window resizes around a bottom anchor, shifting everything under the mouse.
   SwagBag/UI/BagsWindow.lua: sizeFrame (~132-139), callers ~336 (W.Layout), ~384 (Restack), ~611 (ApplyChanges), savePosition (~118-121), default position (~114).
   - sizeFrame(width, height, keepTop): read left/top BEFORE SetSize; if keepTop and both present, after SetSize do frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top).
   - Pass keepTop=true from Restack and ApplyChanges; pass (reason ~= "open") from W.Layout.
   - savePosition stores {"TOPLEFT","BOTTOMLEFT",frame:GetLeft(),frame:GetTop()}; restoring a saved position must still accept old saved formats (do not crash on a week-1/early-week-2 saved table).
   - Test in spec/bagswindow_sections_spec.lua: after a collapse that changes height, the last anchor is TOPLEFT at the previous top/left; same for an ApplyChanges that adds a Free row. Extend the mock frame (~28-49) with GetLeft/GetTop.
2. I1 — SwagBag/Engine/Layout.lua ~247: in the Free→New branch call clearOverflow(st, key) before take. Test in spec/layout_spec.lua: collapse New → arrival (overflow 1) → expand → re-arrival → overflow 0 and slot in New.
3. I2 — docs/superpowers/plans/2026-10-01-swagbag-week2-categories.md checklist text:
   - ~657 E0 step 1: "Quit the game completely and start it again" (new files need a full restart, not /reload).
   - ~659 E0 step 3: add "and it does not overlap the X close button".
   - ~5940 E1 step 4: add "The Consumables header itself stays exactly where it is."
   - ~5959 E1 step 23: "Right-click it until only one is left (the number on the icon disappears), and stand up. Then right-click the last one and keep the mouse still."
   - ~5960 E1 step 24: "Keep the SwagBag window open while the run ends (when the key level changes). The keystone stays in Keystone & Crests and does not jump to New."
   - ~6322 E2 step 12: add "then move the mouse off it".
   - ~6324-6327 E2 step 14: the report after reopening shows (open) — check "(open) ≤ 25 ms" there; add a `/swagbag report` paste right after step 8 to check "(sort) ≤ 40 ms".
   - ~6351 exit item 4: "E1 steps 12–13" → "E1 steps 17–18".
   - Add to E1 (near the collapse step) one step that catches C1 explicitly: "Collapse a section near the top: the header you clicked does not move and no item slides under your mouse."
4. I3 — docs/superpowers/specs/2026-09-30-swagbag-design.md:
   - §6.4 (~427): replace "never moves item buttons" with "never moves a button relative to its own section header; sections below a collapsed one shift as a whole, and the hover guard holds the restack" (W10).
   - §4.3 table: add row "Same item, changed link (keystone level, enchant, gem): repaint only; re-categorized at the next open or Reflow" (W12); Reflow/sort row (~306): Sort refused in combat with feedback, Reflow allowed; regroup 0.3 s after the last bag update; New overflow row (~302): New's rows are always reserved.
   - §8.2 (~567): note category fields arrive in schema 2.
5. M1 — SwagBag/Core/Commands.lua ~53-57: after reset, `if SB.Categories then SB.Categories.Load() end` and close the bags window (SB.BagsWindow.Close() if present). Test in commands_spec.

Finally: scripts/check.sh must print ALL CHECKS PASSED.
