# SG1 · The scope's glass at the hip looks straight ahead (Dev 3 bug)

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | tools/check.sh green | Accept 8/8 | – |

## What it was

- **Seen (the owner, 2026-11-10):** with the 2x Scope or the Variable Scope held at the hip, the glass "looks good but
  it's showing slightly off angle. The player should be able to see what is directly in front of the optic."
- **Cause:** BP8 drew the hip glass as a crop of the main view: the patch of the field behind the glass as the eye
  sees it. The glass sits low and right of the eye (about 0.14 m right, 0.09 m down, 0.3 m ahead on the rifles), so
  that patch lies about 25 to 30 degrees down and right of where the scope points: mostly floor.
- **Fix:** the glass's camera looks straight down the scope's own axis (the replica model's -z, the sight line's),
  at the main view's own scale (no magnification at the hip, as BP8), upright as the eye sees. It sits on the axis
  where the axis passes nearest the eye, so a thing straight ahead of the scope lands on the glass's middle near and
  far. Aimed (the magnified view and reticle) is unchanged: before and after pictures are identical to the pixel.

## Decisions

- **The camera stays within `hip_glass_eye_reach` (0.25 m) of the eye.** The axis passes about 0.17 to 0.2 m from the
  eye at the hip; the clamp keeps the camera inside the body's 0.32 m radius less the near plane, so a replica pressed
  over a wall never shows what is behind it. Leaning keeps the eye at least `lean_wall_clearance` (0.2 m) from a wall
  beside it, and the camera sits about 0.14 m to the side and looks forward, its near plane a few millimetres across,
  so a lean into a wall can't put it through one either (the critic's advisory; a play check on the checklist). Held
  further out (only in tests), the view shifts a few centimetres off the axis, still looking down it.
- **Upright by the eye's up, the optic's own up when it points within 2.6 degrees of straight up or down**, so the
  picture never rolls against the screen and never builds a degenerate basis.
- **The glass's camera is never eased between ticks** (`physics_interpolation_mode` off): it is placed by hand every
  rendered frame, now off the eye; the match tree already set this, a test tree did not.
- **The glass's camera follows the eye's near and far** each update (once a change), as BP8's crop did.

## Review

- QA Pass (tests/unit/test_sg1_hip_glass_qa.gd: the vertical axis, a scaled model, the reach, aimed to the hip and
  back, near and far, interpolation off, the red dot, Low, 200 random poses). Performance Pass by reading (no GPU: the
  hip camera now looks out rather than at the floor, so it may draw more far geometry; the open BP8 row covers it).
  Critic Accept 8/8.

## Known issues left

- None new. The hip glass's Medium frame time stays the open BP8 row in `docs/KNOWN_ISSUES.md`.
