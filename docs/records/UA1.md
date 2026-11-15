# UA1 · The UI highlight is blue, and the player can pick its colour (UA2)

**Review:** REVIEW_LINE

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ | CRITIC_ROW | – |

## Goal

The owner (2026-11-15): "the interface/UI should have a blue highlight instead of the current beige/cream" (UA1);
after the pictures, "perfect. add a setting in display settings that let the player pick different colours of the
UI. blue, beige, red, green, pink, orange, violet" (UA2).

## Approach

1. **One accent.** Every highlight in the menus and HUD already read `GameTheme.ACCENT` and `ACCENT_INK` (the main
   buttons, picked and focused items, the rail marker, the XP bar, the comms wheel's lit button); the only other one was
   the wheel's pale yellow lit edge. UA1 turned the accent cornflower `#8fb0f0` with ink `#141a24`.
2. **The palette** is `game/config/ui_colours.gd` (`UiColours`): seven accents and their inks, in the order the
   swatches show, and their names. `GameTheme.accent` and `accent_ink` became static vars; `GameTheme.use_colour`
   sets them and redoes the shared Theme's buttons, panels and inputs in place (the slider knob's texture is made
   again), so everything drawn through the Theme changes at once.
3. **The setting** is `Settings.ui_colour` (saved as `ui_colour`, clamped; a save without it gets blue, so no version
   step), applied by `SettingsApply.apply_ui_colour` (also in `apply_all`, at boot). Settings › Display › Interface ›
   Colour is a `MenuSwatches` row, each swatch's name its tooltip.
4. **Restyling.** A page keeps the colours it was built with, so a pick in the menus has Main build the menus again
   (deferred, as after a match) and reopen the settings on Display with the keyboard on the swatch. From the pause
   menu, `PauseMenu.restyle` dresses Resume again and builds its settings again; the match's HUD follows from the next
   match (`docs/KNOWN_ISSUES.md`). The wheel's lit edge is the accent made paler (`HudOrderWheel.lit_edge`).
5. `tools/ui_colour_pictures.gd` draws Display and the Match page in each colour through the real click.

## Decisions

- **Cornflower `#8fb0f0` for blue (the thread's default).** Paler and greyer than Alpha's `#3b87f5` (RGB distance
  0.37) so a lit button never reads as a team; it sits nearer High contrast's sky `#8ccfff` (0.14), but that set is
  much lighter and more cyan. Pictured beside the score blocks; the owner said "perfect".
- **Soft, light shades for every colour** with a dark ink tinted to it, so words read on all of them (WCAG contrast
  6.6 for red, 8 to 11 for the rest): red `#ec7a74`, orange an apricot `#f5b97f` paler than Beta's `#fa8c29`,
  green `#86d39a`, pink `#f4a6cb`, violet `#b8a2f2`, beige the old bone `#d8ccb2`.
- **Swatches, not words** (the HUD tab's crosshair colours are swatches too); the names are in the tooltips.
- **Its own section, Interface,** under View on the Display tab, as the owner named Display.
- **Rebuild the menus on a pick** rather than repaint each page: every page reads the accent as it builds, and the
  menus are already built again after each match, so one path covers them all.
- **The HUD in a running match is not rebuilt** (it is built with the match); see Known issues left.

## Known issues left

- Picked from the pause menu, the rest of that match's HUD keeps the old colour until the next match
  (`docs/KNOWN_ISSUES.md`, can wait).
