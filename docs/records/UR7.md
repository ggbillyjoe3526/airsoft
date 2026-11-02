# UR7 · The HUD as concept B v2

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | ✓ | Retry 7/8 | mag boxes at the left; score bar's departure not recorded |
| 2026-11-02 | 2 | Opus 5.5 (build thread) | ✓ | Accept 8/8 | – |

## Goal

The last of the pull requests for the owner's UI redesign (UR1 has the asks and the concepts): the HUD as concept B v2
`hud.png`, with his v2 changes "a square minimap" and "larger grenade icons, the equipped one bigger".

## Approach

- **Bombs as icons** (`ReplicaPanel`): the smoke and the flash are `GrenadeGlyph` icons (the Loadout's, UR3) with how
  many are left, at the panel's top right. The one in hand (`Grenades.Hand.readied`) grows from 28 to 40 px on a light
  chip; a bomb with none left dims. The bombs' row is always as tall as a bomb in hand, so readying one never moves
  the panel. They are rebuilt only when a count or the bomb in hand changes.
- **Replica panel**: a rounded glass panel (no teal rule), set to its right edge as the concept: the bombs, the count,
  the magazine gauges (right-aligned under the count), then the replica's name beside the S / B / A chips.
- **Score bar** (`HudScore`): one rounded glass plate behind the whole bar (no separate dark side boxes) and rounded
  team blocks inset in it. The blocks are outlines (`HudStyle.rounded_rect`), built once, so Beta's gauge-pattern
  stripes follow the rounded block.
- **Hit feed** (`HudFeedRow`): each line is a rounded pill with the team bar inside its left end; your lines' teal
  frame and the HIT tag are rounded too. The pill, frame and tag boxes are made once per row.
- **Minimap**: already square (UR1 kept the HUD's square panel), so it is unchanged.

## Decisions

- **The score bar keeps its colour blocks and slanted pips.** The concept floats white digits over team-coloured dashes
  with a small clock chip. The blocks carry the ATK / DEF tags, and Beta's gauge-pattern stripes (Accessibility) need
  a filled shape to read without colour, which a thin dash can't give; so the bar keeps them, rounded, on one glass
  plate. A departure from the concept, told to the owner; easy to change if he wants the digits and dashes.
- **The fire modes stay as S / B / A chips.** The concept shows only the mode in use; the chips also say which modes
  the replica has, which the owner's tuning relies on, and they fit beside the name.
- **The panel keeps a glass backing.** The concept floats the numbers on the scene; over a bright sky or a white wall
  they would wash out. The HUD tab's panel opacity (50 to 100 %) still sets how dark the glass is.
- **The minimap stays square-cornered.** Rounding it would mean clipping the field picture each frame (a second
  pass); the square panel already matches the ask.

## Known issues left

- None known.

## Checks

- gdlint clean; HUD suites 272/272 (with `test_ur7_hud.gd` and QA's `test_ur7_qa.gd`); the full suite runs in CI.
- QA: Pass. Its advisory (the ATK / DEF tags floating 7 px over the inset blocks) is fixed: they rest on the blocks.
- Performance: Pass (no per-frame allocation; the plates and boxes are made once, redrawn only on a change).
- Critic: Retry 7/8 (mag boxes, score-bar decision), then Accept 8/8. Its note on the panel growing 12 px with a bomb
  in hand is fixed after the review.
