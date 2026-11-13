# PB2 · The bomb and the wire cutters

**Review:** 8 attempts · critic pending · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Opus 5.5 (build thread) | ✓ | Retry 7/8 | 1 (proportions against the photo, cutters floating, carry not attached, pale in game) |
| 2026-11-13 | 2 | Opus 5.5 (build thread) | partial | Retry 7/8 | 1 (the cutters: needle triangles at the jaw, a striped pivot side, the grip panel read as a crack, blunt tips) |
| 2026-11-13 | 3 | Opus 5.5 (build thread) | partial | Retry 7/8 | 1 (the cutters: open edges and T-junctions where the lap was cut, a hairline at the pivot) |
| 2026-11-13 | 4 | Opus 5.5 (build thread) | partial | Retry 7/8 | 1 (a hairline where the ground strip clipped the jaw's chamfer) |
| 2026-11-13 | 5 | Opus 5.5 (build thread) | ✓ | Retry 7/8 | 1 (specks along the seam where the closed jaws met) |
| 2026-11-13 | 6 | Opus 5.5 (build thread) | ✓ | Retry 7/8 | 1 (a pinhole of light through the pivot below the screw) |
| 2026-11-13 | 7 | Opus 5.5 (build thread) | partial | Retry 7/8 | 1 (a bright hairline down the crease where the lap begins) |
| 2026-11-13 | 8 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **The bomb follows the owner's grey-green photo for its shape** (four soft blocks two by two, the keypad timer, the
  antenna); his other two photos give the silver duct tape (the black one) and the wires looping into plugs at the front
  (the tan one). Grey-green, not black or tan: it reads on every field's floor and is neither team's colour. No words
  anywhere: the LCD shows ghost seven-segment digits.
- **The cutters follow the teal flush cutters**, not the red wire stripper: the photo is of a wire snipper, its pointed
  head reads at the wire, and teal stays clear of Beta's orange and the red wire. Plain grips: no maker's panel, which read as a crack.
- **10,000 triangles a file** (docs/CC0_ASSETS.md › Size limits), a replica part's budget: one bomb and one pair of cutters
  in a match, seen close while keyed in or defused. Plain colours, painted in the shared light like the other props.
- **The cutters lie open on the floor by the wires' end while anyone defuses** (a decision card offered the owner this,
  hidden until hands, or floating and snipping; this went in meanwhile): nothing floats, and no arm holds them until
  the first-person arms work (FP1/HA1) gives the defuse its hands. Each half open 0.18 rad.
- **Measured against the photo** (attempt 2): keypad 0.55 of the bundle's width with green either side, blocks a little
  taller than wide end on (53 x 57 mm), bands 32 mm wide set 35 mm in from each end, the keypad 0.37 of the length;
  cutters' jaws 0.15 of the length, head 0.09, grips 0.69. Blocks a darker grey-green and the tape a duller silver,
  checked under Depot's light.
- **The cutting edges are ground into the steel on both faces** (1 mm wide, 0.15 mm deep at the edge), not laid on as
  a strip, polished, each edge 0.03 mm past the centre line so the closed jaws overlap in a shallow V with no seam.
  Every flat face of the steel is shaded flat.
- **The halves lap at the pivot like real cutters** (attempt 7): each half's outline is cut where it crosses the other
  half's pivot disc, the lap walls sit a hair inside that disc and its roof 0.02 mm under the centre line, with radial
  normals on the walls and roof, so no light shows through the pivot and no edge pokes past the other half's arc.
  Where the lap begins, its end (0.02 mm wide) is shaded as the side it ends, so it does not light up as a line.
- **Carried, it rides on its side at the left hip, keypad out, strapped to the belt**: the model's `Carry` node (a
  webbing strap over each band, a belt loop from each, snapped) shows only while carried (`carry_at` 0.19, 0.9, 0.04 m;
  0.3 m lower fully crouched, `carry_crouch_drop`).
- **Keyed in, its front faces whoever keys it in**, so the LCD reads the right way up from where they knelt.

## Known issues left

- No hands hold the cutters or the bomb in your own view: the first-person arms work (FP1/HA1) owns those animations.
