# SM5B · Subway's signs and posters in every room

**Review:** passed (critic 8/8 at attempt 2, QA Pass, performance Pass)

SM5's second pass, at William's asks in the hall and escalator threads (2026-11-12): "Add more signs, posters and other
environmental details to the areas" and "Add posters and signs to all the environments. Maybe only one sign in the
elevator. Posters down the walls beside the escalator." The split agreed between threads: this one does every sign and
poster; the hall thread (SM3) the rest of the detail (skirting, vents, pipes, hatches); the lifts thread (SM2) one
wordless pictogram plate in each lift car.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ | 7/8 Retry | the departure boards' printed face 13% wider than its cell |
| 2026-11-12 | 2 | build thread | ✓ | 8/8 Accept | |

## What it adds

- **Escalator posters:** rows of small posters (the 13 designs at 0.6 x 0.9 m) down both side walls of both escalator
  shafts, 2 m apart, clear of the first and last 2 m (28 in all). A fixture may now carry a `scale`
  (`StationDressing.Fixture.scale`, StationFixtures scales its instance), so the small ones are the same models.
- **Signs over the mouths:** "Platforms" over the escalators' and the stair's mouths on the way down (not where a
  hanging sign already stands in front of one), "Way out" over the platforms' doors to the lower hall
  (`wall_sign_platforms`, `wall_sign_out`: the hanging signs' faces on wall plates; the arrow points ahead).
- **Notices:** "Hold the handrail / Stand on the right" at each escalator's head and foot, "No smoking" in the hall,
  the concourse, the lift landing and the plant room, "CCTV in use" by the cameras.
- **Information panels** in the ticket hall, the concourse and the lower hall; **the line's strip map** (the
  Copperhill Line: Ashby Road, Mill Lane, Copperhill, Lido, Harbour, Pier, all invented) on both platforms' back walls;
  **departure boards** (dot-matrix yellow on black) hung over both platforms between the strip lamps.
- **More posters** in the lower hall, the mid and east passages and the lift landing.
- All from the same 2048 x 2048 sheet (its free corners: no growth): 9 new models, 33 to 40 triangles each.

## Decisions

- **Every printed face keeps its cell's shape** (a test: each printed triangle's world edges over its sheet edges,
  within 2%): the departure boards grew to 0.445 m tall (face 4 to 1), and SM5's way-out sign, 7% wide, to 0.3 m.
- **The escalator posters stand level, not along the slope** (the Tube's are often level in their frames); their
  middles 2.1 m over the pitch line (1.7 on the lower, lower ceiling), clear of the decks (1.0 m) and the ceiling.
- **The departure boards read along the platform** (yaw 90) and hang 0.3 to 0.7 m under the ceiling, between strip
  lamps; north trains to Pier and Harbour, south to Ashby Road and Mill Lane, as on the line map.
- **Line colour green** (palette green), off both team hues; the notices' red is the posters' crimson.
- A spot the build finds in a block or over an opening is moved by hand, not left out: every spot named here places.

## Known issues left

- None yet.
