# HD1 · The HUD in the menus' look

**Review:** 1 attempt · critic Accept 7/8 (Sonnet; the one miss was the changelog note, added after) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-19 | 1 | Sonnet (worker) | pass, 675 tests | 7/8 Accept | – |

## Decisions

- **Restyled in place, same places.** The score bar stays top centre, the replica panel bottom right (corner margin 32 px,
  the concept's, was 40), the banners and the HIT! call above the crosshair. The crosshair, hit marker, HIT! call and the
  vault prompt keep their looks and now read `GameTheme.TEXT`.
- **New parts, each one job:** `HudStyle` (HUD-only sizes, backings and the pure helpers: pip fill, clock text, banner
  words), `HudScore` (blocks, pips, clock, round), `HudBanner` (slanted panel with the yellow top rule),
  `ReplicaPanel` (framed panel, chips, notes), beside the existing `Hud` and `MagGauges`. `GameTheme` is untouched.
- **Colours only from `GameTheme` and `TeamConfig`.** `HudConfig`'s colour fields (text, muted, warn, gauge colours and
  backing) are gone; the HUD's backings are `GameTheme.BG` at the concept's opacities. The low-magazine and status
  warning colour is `GameTheme.YELLOW` (the palette has no amber; the old warn colour was an off-palette orange).
- **Nothing per frame.** Pips and panels draw in `_draw` of `HudScore` / `HudBanner` / `MagGauges`, which redraw only when
  a value changes; labels retype only on change (the score, clock and round moved into `HudScore` with their guards).
  The pip polygons are built once in `setup`.
- **One pip per win needed** (`RoundConfig.wins_needed`), filled left to right up to the wins, clamped.
- **"FIRST TO N" moved out of the round banner.** It is a permanent line under the clock now, so the round start banner
  has no second line, except on the round after the half, where it says "HALF TIME · ENDS SWAPPED" (the concept's; the
  rule exists in `RoundConfig.half_time_after`, so the line is true).
- **Draw banner split in two** ("DRAW" over "THE ROUND IS PLAYED AGAIN") so the 72 px capitals stay short; the keys
  `HUD_ROUND_DRAW` and `HUD_ROUND_DRAW_SUB`. The round and match won banners keep the team's colour on the big line.
- **Replica panel width 176 px** (the UI2 record's), inside a 340 px lane for the hop-up note. The replica's name is not
  shown (the concept and UI2 omit it); "Holstered" is a status note above the panel. Chips show only the modes the
  replica offers, S / B / A from `HUD_CHIP_*`, the one in use lit (none lit while holstered).
- **Magazine boxes** are the concept's 11 by 18 px, 1.5 px outline, 6 px apart, with a 10 px gap after the loaded one
  (UI2: the next reload's magazine sits beside it), still filled from the bottom by BBs left, left aligned.
- **The hop-up readout and status line** became small dark notes above the panel; the hop line keeps its sentence case
  (its "m" is metres, capitals would read as mega).
- **Left out:** the hit feed (step 14).

## Known issues left

Each has a row in `docs/KNOWN_ISSUES.md`.

- The replica panel is about 8 px taller than the concept's, and shows no replica name.
- No hit feed until step 14.
