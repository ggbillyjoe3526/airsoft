# MB2 · Woodland's Long road, cleared

**Review:** critic @@CRITIC@@ · qa @@QA@@ · performance @@PERF@@

MB1 laid three fallen trees and a log stack across Woodland's Long road, the stack a gate screen's 2.8 m, and put its
height to the owner on a decision card. The owner (2026-11-12): "Lower it to 1.8 m". The first build of this task did
that and stood young spruce behind the stack (attempt 1 below; pushed, reviewed, never merged). Shown it, the owner
(2026-11-13, 00:31): "I don't want woodpiles over the road. Also, are the trees on the road? The road should be
clear." This record is the cleared road.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ | 7/8 Accept | the owner's ruling: nothing on the road (the stack and spruce stood on it) |
| 2026-11-13 | 2 | build thread | @@CHECKS@@ | @@CRITIC@@ | – |

## What changed

- `tools/woodland/layout.py`, `world.py`, `check.py`, `build_map.py`, `data/maps/woodland.json` (@@BLOCKS@@ blocks,
  945 on `main`):
  - **Nothing on the road.** The three fallen trees and the stack across the road are gone (`tag="roadblock"` with
    them), and attempt 1's Culvert stand. `ROAD_HALF = 2.5`: no piece reaches inside the 5 m gravel strip.
    `ROAD_CLEAR = 3.5`: a thicket's cells keep that far off the centre line, so its 1 m blocks and its boughs stay
    off the gravel (`world.py` clips every thicket; `check.py` fails on either). The pickup and one verge stack,
    0.1 to 0.2 m inside the strip's edge on `main`, moved 0.3 m off it.
  - **The road bends.** `ROAD` swings south round one stand of spruce and back north round another west of the
    Culvert ("the Road stands", `THICKETS`), 7 m between them. The Road hump moved 5 m west and dropped 0.2 m; the
    road climbs round its south side. One hand-placed pine stood on the new bend and moved 5 m east.
  - **Pieces beside it.** One fallen tree lies on the north verge at the bend's east mouth (the west end's cover
    over the dip); the stack that stood across the road stands inside the road's bend east of the Culvert (the
    east's cover); the Truck bend's tyre stack and south verge stack moved clear of the new line.
  - **The south lane** keeps to the road. Its two stops are 2.6 and 2.5 m either side of the field's middle, at the
    bend's east mouth and the Culvert's west head.
  - **Flag B.** The sawn boards stand along the shed's east end, not its north side beside the pole. The verge
    stack west of the road mouth is turned across the verge.
  - **Place names:** the Truck bend's and the Long road's areas reach the road's south bend. **Tyre tracks:** the
    pickup's follow the new road, in two arcs.
- `tests/unit/test_mb2_qa.gd`: nothing stands within 2.5 m of the road's centre line between the camps; the road
  is walked end to end on its strip; only the six camp gate screens stand taller than a woodpile.
- `tests/unit/test_mb1_layouts.gd`: the road's strip west of the Culvert (its centre line and 2 m either side)
  sees no chest in flag B's pole ring or at its posts; attempt 1's stack test is gone with the stack.
- `docs/wiki/Maps.md`, `docs/DECISIONS.md` › Maps and modes, `docs/KNOWN_ISSUES.md` (the two Woodland rows; the
  tight-passage row is gone with the passage).

## What a clear road does, measured

Seeded 6v6 bot matches at Normal (`tools/map_heat.gd`) and the game's ray. Bands: Elimination's ends 45 to 55 %,
Attack / Defend's attackers 40 to 65 %. The first and last rows are the same 32 seeds.

| Layout | Elimination, west end | Attack / Defend, attackers | Round flag B, attackers to defenders |
|---|---|---|---|
| MB1 on `main`: fallen trees and a 2.8 m stack across the road | 48 % ±3 (239 rounds, 32 seeds) | 62 % ±3 (236, 32) | 285 to 161 |
| Attempt 1: the stack at 1.8 m, spruce behind it | 47 % ±3 (235, 32) | 54 % ±4 (130, 16) | 156 to 127 |
| Clear and straight, pieces on the verges | 42 % ±5 (16 seeds) | 67 % ±4 (16) | 158 to 71 |
| Clear, bent between the stands (the first bend) | 48 % ±5 (107, 16) | 64 % ±4 (129, 16) | 167 to 87 |
| **Built** | **47 % ±3 (241, 32)** | **69 % ±3 (247, 32)** | **269 to 167** |

- **A straight clear road is out of band both ways.** With nothing on it the only things that end its line are its
  own bends between solid stands: a 1.8 m piece on the verge in the dip hides nobody from the higher west side. The
  south lane's median knock-out went to 32 m, and the west end, shot crossing the open, took 42 %.
- **The double bend ends the line, and Elimination is even again** (47 % ±3; the south lane 329 knock-outs to 336,
  at a median 15 m). No two points of the strip either side of the bend see each other. The longest lines left along
  the strip: 63 m from the west camp's gate down to the bend, 57 m from the Sawmill's road mouth to it (MB1's road
  was one 60 m line from the Truck bend to flag B before its pieces).
- **Attack / Defend is outside its band: 69 % ±3, and 62 % ±3 for `main` on the same seeds.** Seven points ±4. A
  flag goes up in 40 % of rounds (37 %), and of the rounds where none does the attackers win 56 % (49 %). Round
  flag B itself the count is `main`'s (118 knock-outs to 73 a hundred rounds; 123 to 75); the attackers' gain is on
  the east ground between the two sites (96 to 62; 70 to 83), where the defenders coming back to B meet them. The
  one thing the records show of why: on the clear road the attackers shoot from the pole 1 to 2 s sooner (the 10th,
  50th and 90th percentile of their shots from it 34, 42 and 51 s; 35, 44 and 53 s on `main`).
- **Ten layouts of flag B's cover were played, 16 seeds each and the last two 32** (`pipeline/out/mb1/rc5` to
  `rc16`, kept out of the repository): cover for the forward defender's flank, a wider view for the defenders coming
  back round the thicket,
  less cover for the attackers at the road mouth, at the bend and beside the pole. They read 61 to 70 %, and a
  16-seed reading is ±4, so none is shown to help. One change is kept on its own evidence: the sawn boards. Beside
  the pole they hid the raiser from the defenders coming back, and the defender who stood behind them lost his duel
  with the pole 10 to 18 a hundred rounds on `main`; with the boards at the shed's east end he stands at the Back
  track's corner and wins it 15 to 13.
- **The eight-seed blocks of one layout ran from 59 to 74 %** in Attack / Defend, so the built layout and `main` are
  each read from 32 seeds, and attempt 1's 54 % was as much luck as layout.

## Decisions

- **The road bends; no piece screens it.** The owner's ruling leaves the road's own shape and what stands beside it.
  Spruce is the field's one solid screen and is already its edge and its thickets: no new model, no new sound.
- **Spruce keeps off the gravel as well,** 3.5 m from the centre line, though the ruling named woodpiles and trees
  on the road: boughs over the strip would read as trees on it.
- **The boards moved, not removed:** `test_props` holds every Woodland model to a place on the field, and the east
  end of the shed is out of every line onto the pole from the defenders' side.
- **The bend's two apexes are 13 m apart across the road's line and 7 m of clear ground runs between the stands:**
  the least that shuts the diagonal through it with the spruce off the gravel (at 11 m a 68 m line ran through).
- **Attack / Defend goes to the owner as a known issue, not as a blocker.** The road he rejected, with a stack
  across it, is what `main` has now; the cleared road is his ruling, and flag B was the softer site before it
  (`docs/KNOWN_ISSUES.md`). Next: flag B's defender posts or its pole, measured at 32 seeds from the start.
- **The road test's criterion is unchanged** (no chest in the ring or at the posts from the road west of the
  Culvert); what it samples is the new road's strip, not a box round the old one.
- **The map card is not rendered again:** it looks north-east from (35, -25), away from the road.

## Verified

@@VERIFIED@@

## Known issues left

@@KNOWN@@
