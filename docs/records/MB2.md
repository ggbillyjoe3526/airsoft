# MB2 · Woodland's Long road, cleared

**Review:** 2 attempts · critic Accept 7/8 · qa Pass · performance Pass

MB1 laid three fallen trees and a log stack across Woodland's Long road, the stack a gate screen's 2.8 m, and put its
height to the owner on a decision card. The owner (2026-11-12): "Lower it to 1.8 m". The first build of this task did
that and stood young spruce behind the stack (attempt 1 below; pushed, reviewed, never merged). Shown it, the owner
(2026-11-13, 00:31): "I don't want woodpiles over the road. Also, are the trees on the road? The road should be
clear." This record is the cleared road.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ | 7/8 Accept | the owner's ruling: nothing on the road (the stack and spruce stood on it) |
| 2026-11-13 | 2 | build thread | ✓ | 7/8 Accept | – |
| 2026-11-13 | 2, after CI | build thread | ✓ | – | a night guard failed on the push: one hazel moved (Verified) |

## What changed

- `tools/woodland/layout.py`, `world.py`, `check.py`, `build_map.py`, `data/maps/woodland.json` (960 blocks,
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
- `tests/unit/test_mb2_qa.gd`: nothing stands within 2.5 m of the road's centre line between the camps, and no bush
  reaches the strip; the road is walked end to end on its strip; only the six camp gate screens stand taller than a
  woodpile; the tyre tracks start on the road; every point along the road has a place name; a seeded match in each
  of the three modes finishes with no bot held up (the last four are QA's).
- `tests/unit/test_mb1_layouts.gd`: the road's strip west of the Culvert (its centre line and 2 m either side)
  sees no chest in flag B's pole ring or at its posts; attempt 1's stack test is gone with the stack.
- `tests/unit/test_map_areas.gd`: Woodland has 246 area boxes (244), from the two redrawn road areas.
- `tools/map_heat.gd` (dev only): `bomb` is a third mode name, and a round's record carries when and where the bomb
  was armed.
- `docs/wiki/Maps.md`, `docs/DECISIONS.md` › Maps and modes, `docs/KNOWN_ISSUES.md` (the two Woodland rows; the
  tight-passage row is gone with the passage).

## What a clear road does, measured

Seeded 6v6 bot matches at Normal (`tools/map_heat.gd`) and the game's ray. Bands: Elimination's ends 45 to 55 %,
Attack / Defend's attackers 40 to 65 %. The first and last rows are the same 32 seeds.

| Layout | Elimination, west end | Attack / Defend, attackers | Knock-outs within 12 m of flag B's pole, attackers' to defenders' |
|---|---|---|---|
| MB1 on `main`: fallen trees and a 2.8 m stack across the road | 48 % ±3 (239 rounds, 32 seeds) | 62 % ±3 (236, 32) | 285 to 161 |
| Attempt 1: the stack at 1.8 m, spruce behind it | 47 % ±3 (235, 32) | 54 % ±4 (130, 16) | 156 to 127 |
| Clear and straight, pieces on the verges | 42 % ±5 (16 seeds) | 67 % ±4 (16) | 158 to 71 |
| Clear, bent between the stands (the first bend) | 48 % ±5 (107, 16) | 64 % ±4 (129, 16) | 167 to 87 |
| **Built** | **47 % ±3 (241, 32)** | **69 % ±3 (247, 32)** | **269 to 167** |

- **A straight clear road is out of band both ways.** With nothing on it the only things that end its line are its
  own bends between solid stands: a 1.8 m piece on the verge in the dip hides nobody from the higher west side. The
  south lane's median knock-out went to 32 m, and the west end, shot crossing the open, took 42 %.
- **The double bend ends the line, and Elimination is even again** (47 % ±3: the west end won 114 of 241 rounds,
  the east 126, one was drawn; the south lane 329 knock-outs to 336, at a median 15 m). No two points of the strip either side of the bend see each other. The longest lines left along
  the strip: 63 m from the west camp's gate down to the bend, 57 m from the Sawmill's road mouth to it (MB1's road
  was one 60 m line from the Truck bend to flag B before its pieces).
- **Attack / Defend is outside its band: 69 % ±3, and 62 % ±3 for `main` on the same seeds.** Seven points ±4. `main`'s
  figures follow in brackets.
  - The attackers win by a flag: 165 of 247 rounds end with one raised and held (143 of 236) and 5 by knock-outs
    alone (4). The match tally follows flag A's height only (`RoundState.flag`): A was fully up in 84 of the 165
    (74 of the 143), which leaves about 81 won at flag B (69), a third of all rounds at each site on both layouts.
  - Knock-outs by where the target stood, a hundred rounds, the attackers' to the defenders': within 12 m of flag
    B's pole 109 to 68 (121 to 68); within 12 m of flag A's 102 to 92 (100 to 90); on the east ground outside both
    rings (east of x 20) 116 to 213 (85 to 244). The attackers' gain is on that ground, on the way to the sites,
    not at the poles.
  - The attackers' knock-outs from within 4 m of flag B's pole come 2 to 4 s sooner (their 10th, 50th and 90th
    percentile 35, 42 and 53 s; 37, 46 and 55 s).
- **Ten layouts of flag B's cover were played, 16 seeds each and the last two 32** (`pipeline/out/mb1/rc5` to
  `rc16`, kept out of the repository): cover for the forward defender's flank, a wider view for the defenders coming
  back round the thicket,
  less cover for the attackers at the road mouth, at the bend and beside the pole. They read 61 to 70 %, and a
  16-seed reading is ±4, so none is shown to help. One change is kept on its own evidence: the sawn boards. Beside
  the pole they hid the raiser from the defenders coming back, and the defender who stood behind them lost his duel
  with the pole 10 to 18 a hundred rounds on `main` (the defender in the 4 m square behind the boards against
  attackers within 4 m of the pole: 24 knock-outs to 43 in 236 rounds); with the boards at the shed's east end he
  stands at the Back track's corner and wins it 15 to 13 (38 to 32 in 247).
- **Plant The Bomb is unmoved:** the attackers win 40 % ±4 (125 rounds, seeds 1 to 16; armed in 67 %) on the built
  layout and 41 % ±5 (117; 76 %) on `main`'s, the same seeds (PB1 merged while this was measured; `tools/map_heat.gd`
  takes `bomb` as a mode for it). The Elimination and Attack / Defend records above were played before that merge:
  eight seeds of each played again after it give the same rounds and the same knock-outs, to the position.
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
  (`docs/KNOWN_ISSUES.md`). Next, as MB3: a 9 s flag raise on Woodland alone (the owner's pick, 2026-11-13; 7 s
  elsewhere). More seeds after the reviews showed both poles fall equally often, so flag B's posts are not it.
- **The road test's criterion is unchanged** (no chest in the ring or at the posts from the road west of the
  Culvert); what it samples is the new road's strip, not a box round the old one.
- **The road's puddle stays** (west of the Truck bend, 1.1 m off the centre line, on `main` before MB1): it is the
  gravel's own surface, walked through, and hides nobody.
- **The map card is not rendered again:** it looks north-east from (35, -25), away from the road.

## Verified

- `python3 tools/woodland/build_map.py` writes the committed JSON (960 blocks); `python3 tools/woodland/check.py`:
  `TOTAL 0`, with its new road rules (no piece inside 2.5 m of the centre line, no thicket inside 3.5 m).
- `tools/check.sh`'s gates on the head with PB1's `main` merged in: gdlint, the changelog notes, the wiki check, the
  seven unit test parts (6,437 tests, none failing, two pending for want of a display as on `main`), the smoke test
  and the licence notices. After the last merge of `main` (SH2, MQ3B: models only) the gates but the full unit suite
  ran again, with the tests that read the road, the areas, the props and the wear marks; CI runs the whole suite.
- The play records after merging PB1's `main`: eight seeds of Elimination and of Attack / Defend give the same
  rounds and knock-outs as before it.
- QA: Pass. It added four tests to `tests/unit/test_mb2_qa.gd` (no bush on the strip, the tyre tracks on the road,
  a place name along the whole road, a seeded match in each of the three modes with no bot held up) and scanned the
  JSON against the whole road: only the culvert's own deck, walls and kerbs are within 2.5 m of the centre line.
- Performance: Pass. `team_bench`, Woodland 8v8, 120 s a run, seeds 1 to 4, one run at a time: tick and views
  4.63 ms a frame against `main`'s layout's 4.56 (+1.5 %). Its first reading, 30 s of seed 1, was +19 %; seed 1 is
  the one seed where the new layout is dearer (+12 % at 120 s), seeds 2 and 3 are cheaper.
- Critic: 7/8 Accept. It recounted the records (170 of 247, 147 of 236, 114 of 240 decided, 50 of 125) and ran its
  own sight check: 250 eye points on the strip west of the bend against 265 east of it see no pair, and 910 strip
  points see none of flag B's ring or post chests. Its failed check was the docs' figures: one count stated two
  ways, and MB1's unreleased note still saying the road is blocked. Both are fixed in this push (the recount found
  that "a flag goes up in 40 % of rounds" had read flag A's height alone; the bullet above gives the rounds won by
  a flag).
- **After the first push, a night guard failed** (Woodland, Elimination at Normal, seed 14: 16 bot seconds held up
  against 10 allowed). Two opposing bots stood inside MB1's Brow hazel at (-16.3, -40.5), 0.7 m off the north lane
  where the squads first meet, each with no shot through the leaves and each walking into the other. The bush moved
  2.3 m north along its row to (-16.3, -38.2), 2.5 m off the lane; the bots' rule is unchanged and is a known issue
  (Bots). Run again on the moved bush, all passing: the five night guard
  jobs (56 matches; Elimination at Normal 123 rounds over 16 seeds), Plant The Bomb's Woodland guard, the callout
  guards, the low-BBs guard, the smoke test and the 117 unit test files that use Woodland (1,472 tests); QA read it
  (the map's one change is that bush; its edge is 2.53 m off the lane; no test or rule forbids its place).
  The performance agent and the critic read the head before it (one bush, no code).
  The figures above were measured with the bush in its old place; MB3 measures the field again.
- **Not verified, for the owner's play:** how the bend looks and plays from the eye, and whether flag B falls too
  easily. The play checks are on the Dev 3 checklist.

## Known issues left

- Woodland's Attack / Defend is outside its band at 69 % ±3 (`docs/KNOWN_ISSUES.md`, Maps). Next as MB3: the 9 s raise.
- The match tally's flag height follows the first pole only (`MatchRunner`'s `top_flag` reads `RoundState.flag`), so
  on a field with two poles "how often a flag went up" must be read from the rounds won by a flag, and which pole it
  was is not recorded. MB1's record and its DECISIONS entry quote the first pole's figure as "a flag goes up";
  recount with MB3, where the tally can name the pole. Can wait.
- Two opposing bots inside one bush hold their fire and walk into each other (`docs/KNOWN_ISSUES.md`, Bots). The
  one bush where it showed has moved off the lane; any other bush can still do it. A bots task, not a map's.
- The two road tests carry their own copies of `layout.py`'s `ROAD` (the critic's advisory): when the road moves,
  they move with it by hand. Can wait.
