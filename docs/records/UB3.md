# UB3 · Beta 2 playtest: Remove beside the menu, one tap spots, ACTION [KEY] prompts, haze on or off

**Review:** 2 attempts · critic Accept 8/8 · qa Pass (attempt 1, 14 tests in test_ub3_qa) · performance Pass (attempt 1)

The owner's Beta 2 playtest notes (2026-11-20), items 1, 2, 4 and 8. Other threads own items 3, 5, 6 and 7 (Woodland
hits, Subway's darkness, bots vanishing, the lift's sounds).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-20 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | No changelog note; the performance report not in pipeline/out; comment wrap nits |
| 2026-11-20 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

CI after review (unit part 6, not run locally): test_so4_orders_hud still held 0.25 s as "past a tap", now read from
`wheel_tap`; and the Remove panel's glass had been set on every `PopupPanel`, which widened the tooltips 8 px off the
screen's edge, so it is a theme variation (`GameTheme.MENU_PANEL`) the Remove panel alone uses.

## What changed

- **1. Remove beside the menu.** The question ("Remove <name>?", then Remove and Keep, the owner's words: they were
  "Remove it" and "Keep it") was a line at the loadout strip's far right. It is now a small panel (`LoadoutStrip`
  `RemoveConfirm`, the menu's own glass style) beside the right-click menu, its foot level with the menu's, so it sits
  by the Remove row; it flips to the menu's left where the window has no room. The menu stays up while it asks. Keep,
  Esc or a click off the panel keeps the loadout and shuts both. Remove asked with no menu up opens it under the
  carried card. The owner asked for a picture first: it was posted to the thread (`playtest/ui-b2-remove/` in the
  project's files) and the work went on without waiting.
- **2. One tap spots.** Two causes found; both fixed. A tap had to be let go within 0.2 s; a relaxed tap often runs
  longer, and then the wheel came up and letting go gave whatever the pointer was on (an order if the mouse had moved
  while tracking someone). `ControlsConfig.wheel_tap` is 0.3 s. And Spotted looked for the enemy only up to the first
  surface the view met, so a view on the crate someone peeks over, or the trunk beside them, marked nobody (measured:
  a view 0.1 m under a 1.1 m crate's top missed the head showing over it). `Spots.place` now looks out to the ping's
  reach; the bots' sight rules (`BotSenses.visible_part`) still want them seen, so someone wholly behind a wall is
  never spotted.
- **4. Prompts.** Every prompt is the action, then the key in brackets, in capitals (`HudStyle.prompt_words`): OPEN
  DOOR [G], CLOSE DOOR [G], CALL LIFT [G], GO TO TICKET HALL [G], VAULT [SPACE], CLIMB [SPACE], RELOAD [R], PICK UP
  BOMB [HOLD G], PLANT BOMB [HOLD G], DEFUSE BOMB [HOLD G]. This replaces UB2's key-alone vault prompt. The reload
  prompt is one line on its plate (the key cap is gone).
- **8. Volumetric haze, off or on.** VF1's Low, Medium and High looked the same to the owner. The row is one switch;
  On draws VF1's High (80 m, 128 x 128 grid, smoothed), the haze as it was when it was last one switch.
  `LookConfig.fog_grid` and `fog_filtered` replace the per-level fields; `FieldLighting.set_fog_reach` is gone (the
  reach is `fog_length` always). Settings version 7 reads a saved Custom level (low, medium or high) as On; the HUD
  defaults' move (version 6) no longer runs again on a version 6 file.

## Decisions

- **Owner rulings:** `docs/DECISIONS.md` › Beta 2 playtest, prompts, Remove, Spotted and haze.
- **On is VF1's High.** It is the haze the owner last signed off as "on" (Ultra), and the levels differed only in
  reach and grid.
- **Haze on from the High preset up; Low and Medium off.** Medium had Low's 30 m haze for five days; the owner sees no
  difference between levels, so Medium's frame time (the laptop tier) keeps the cost instead. High now pays High's
  haze rather than Medium's (VF1's lavapipe figures: +21 to 46 % against +12 to 31 % of a Low frame; on a graphics card
  a fraction of a millisecond).
- **Hold actions read "[HOLD G]".** The key in brackets with how it is pressed, so the format stays "ACTION [KEY]".
- **Lift panel: "GO TO <STOP> [G]".** The stop's name in capitals, as the action.
- **Tap 0.3 s.** Long enough for a relaxed tap; the wheel shows 0.1 s later when held, which nobody waits on.
- **Focus rings clear of the words (owner, 2026-11-20: "make sure any other buttons/options are fixed too").** A probe
  over every focusable control in the menus, Customise, the Armory, Settings, Report and the pause menu found three
  rings within 3 px of their words: the quiet links, Customise's Realistic colours switch and the rail's QUIT. They use
  `GameTheme.focus_clear`, drawn 6 px across and 4 px up and down outside the control (QUIT: up and down only, the
  rail's edge leaves no room across).
- **Not changed:** the out-of-play hints (the skip-the-round line and the Range's Loadout line) keep their key chips;
  they are hints, not prompts at a thing in reach.

## Known issues left

- None.
