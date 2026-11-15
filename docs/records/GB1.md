# GB1 · GBB rear serrations and the back of the slide

**Review:** 3 attempts · critic Accept 8/8 (Opus) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | wear marks in the recess's inside corners; the recess read flat, not a hollow; the plate's lines read as ribs |
| 2026-11-15 | 2 | Opus 5.5 (build thread) | targeted ✓ | 7/8 Retry | the recess floor (Detail, polymer) no darker than the slide in Black paint (0.89 of the back face) |
| 2026-11-15 | 3 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

Agents' tokens: QA 34k + 34k, performance 16k + 24k, critic 61k + 44k + 54k, changelog 20k.

## What the owner asked (2026-11-15)

- The rear slide serrations showed small grey squares at their feet; they should look like the front ones.
- The back of the slide redesigned to his three Gen5 photos as closely as possible.

## Cause of the grey squares

The frame's walls rose 2.7 mm into the slide under the rear serrations, 0.35 mm outside the grooves' floor, so the
frame filled the bottom of each groove. `frame_upper()` now trims them inside the floor (`SERRATION_CLEAR`) over the
rear serrations' span; the slide covers the trim everywhere else.

## Decisions

- **The back, measured on the square-on photo** (0.0468 mm a pixel at x3, the slide 25.5 mm wide): the cover plate
  16.8 mm wide, its top 5.1 mm under the slide's, its foot 7.9 mm up, top corners rounded 4 mm, set 1 mm in with a
  0.15 mm gap; five hairline lines (0.2 mm, 0.15 mm deep, 0.97 mm apart) right across it; under it an open recess
  15.6 mm wide and 5.5 mm deep, the plate's tongue down its middle and two blocks set 2.2 mm in. The slide's own
  outline (its top's rounding) is unchanged: the owner circled the plate, not the slide.
- **The recess floor is its own near-black material, `Cavity`** (0x0d0e10, metallic so it reflects nothing; the game
  leaves it unpainted), so the recess reads as the photos' dark hollow in every paint (floor 0.11 of the back face's
  brightness in Black). It takes the GBB to 8 materials against the budget of 6 a replica (its known row in
  `docs/KNOWN_ISSUES.md`, was 7): one more draw in the hands only, since the bots' copy drops it
  (`figure_copy.DROP`). The other way, the floor in the painted Detail colour, read no darker than the slide in Black.
- **The blocks ride with the slide** (joined into the Slide mesh), so firing opens no gap at the back.
- **No wear in the recess:** `wear.apply()` takes opt-in `clean` boxes; the pistol's box covers the recess, its rim
  0.5 mm round and the plate's lowest 1.2 mm, which so get no edge rub either (their inside corners gathered grime that
  read as marks). No other replica changes.
- **The parts file is unchanged** (`replicaParts/pistol.glb`): nothing in it changes with the slide's back.
- **Triangles:** 39,960 of 40,000 in the hands (was 39,590), so the next GBB detail change needs savings first.

## Known issues left

- The GBB's material count, 8 against 6 (the existing row in `docs/KNOWN_ISSUES.md`, updated).
