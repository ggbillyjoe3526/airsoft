# SW2 · Subway from the 0.1 Beta 2 playtest

**Review:** QA Pass, Performance Pass (attempt 1, `pipeline/runs/SW2/attempt-1/`), Critic 8/8 Accept (attempt 4,
`pipeline/runs/SW2/attempt-4/critic-report.md`)

The owner's 0.1 Beta 1 playtest (2026-11-17, notes and screenshots for 0.1 Beta 2): Subway's items 2 ("make Subway
public"), 18 ("make the elevator sound of it moving louder. I can't hear it"), 19 ("doors closing should play when the
button is pressed"), 20 (a poster over a lift door), 21 (the spiral stair's wall glitched, "at the bottom level there
is an open space under the stairs, block this off"), 22 ("add some more benches" in the ticket hall), 23 ("create a
tunnel that curves into the distance and continues the train tunnels instead of having just a wall. Block it off with a
object model so players can't access it"), 24 ("Platforms have ramps. remove them"), 26 ("tunnel wall is glitching
around the train", his 6.png) and 27 (the trains' front and end models need refining, his 7.png).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-17 | 1 | Opus 5.5 (build thread) | ✓ (lint, wiki, flat faces, ~60 touched unit files; the rest in CI) | 6/8 Retry | check 1: hairline seams still on the mouth wall; the cab's proportions not checked against references, a plain outer end; check 8: two known issues with no row |
| 2026-11-17 | 2 | Opus 5.5 (build thread) | ✓ (lint, wiki, flat faces, touched unit files 105/105 and the 150-test map batch; the rest in CI) | 7/8 Retry | check 1: a thin line round the south mouth; the cab's mask short of the photo's, its door window small; the end's bellows narrow and square |
| 2026-11-17 | 3 | Opus 5.5 (build thread) | ✓ (lint, wiki, flat faces, touched unit files 80/80) | 7/8 Retry | check 1: ragged slivers where the cab's mask meets the rim's round; the door's glass a pale slab in the mask |
| 2026-11-17 | 4 | Opus 5.5 (build thread) | ✓ (lint, flat faces, touched unit files 75/75 with the new hole test; the rest in CI) | 8/8 Accept | – |

## What changed

- **Subway is public** (`data/maps.md`): off the dev list, in the match page's map list for everyone; its wiki page
  (`docs/wiki/Maps.md` › Subway).
- **The lift's motor is louder and rides with the car** (`SoundConfig.lift_motor_gain` 1.4, `lift_motor_rise` 1.2 m):
  it was played at the lift's gain from the floor the car left, so a rider rode away from it under the car's roof;
  now it follows the car (`SimAudio`), about 6 dB up (twice `lift_gain`'s 0.7). It stops as a round ends, as the
  next round puts every car back at its start stop.
- **A press inside the car shuts its doors at once** (`LiftConfig.panel_dwell` 0 s): the closing sound plays as the
  button is pressed. The doors still never shut on a body in the doorway. A bot pressing from inside waits for a
  teammate still walking in (at most the car's dwell, `BotLifts._boarding`) before it presses.
- **The poster by the east lift** moved east of its door and button (`tools/subway/fixtures.py`); a test checks no
  wall fixture stands in front of any lift door.
- **The spiral stair:** its foot's doorway now runs up to the platform's back wall (`TUNNEL_H`) with the seal's wall
  over it, so no slit shows; a wall closes the east side under the last flight, so the space under the flights is shut.
- **Four more benches in the ticket hall** (`HALL_BENCHES`), backs to the walls, out of the lanes.
- **The running tunnels go on round a bend** (`BEND`: radius 40 m, 60°, each turning away from the other): the
  station's surface sweeps walls, arch, track bed and rails round it from the old end wall at x 82
  (`StationDressing.TunnelBend`, `StationSurface.add_bend`), with two tunnel lamps on its outer wall. A new steel
  grille (`tools/blender/maps/tunnel_grille.py`, 1,100 triangle budget: works-yellow frame fitted to the arch,
  galvanised bars, a padlocked wicket gate with a hazard plate) stands where the wall was. The wall itself is still
  there for bodies and BBs, undrawn (`TunnelVault.shut_end`).
- **The north platform runs level to its end:** its end ramp and the ramp's foot are gone. The east team climbs out of
  the tunnels over a platform's edge, as everywhere else along the track since CL1 (the owner removed the trackside
  stairs then); bots take the same climb links.
- **The tunnel wall round the train** (6.png): the cars' sides stood flush with the tunnel lining at 1.75 m, so the two
  fought; the cars are now 1.72 m a side (`train.py OUT_Z`). The mouth's wall pieces that straddled the vault's lid are
  split at it (`build_map.py at_mouths`), so the lid hides whole pieces and no stepped edges show round the arch. A
  typed-array slip in `StationSurface.add_vault` that drew no vault at all on a straight tunnel is fixed. The dotted
  lines across the mouth's wall (attempt 1's critic, and the white dashes in 6.png) were hairlines between the wall's
  pieces: each piece's centre and size were rounded to the millimetre apart, so two pieces that met could stand half a
  millimetre apart. Each face is now put on the millimetre and the centre and size taken from the two (`build_map.py
  span`), and the pieces one box was cut into are joined again wherever two meet face to face (`joined`, never
  across a mouth's split): Subway is 1,219 blocks (1,365 in attempt 1, 1,333 on main). Underground, what shows where
  no face is drawn is near black, not the sky's blue (`LookConfig.underground_background`, `FieldLighting
  .set_underground`), so any hairline left where two faces meet reads as shade. The last thin line round the mouth
  (attempt 2's critic) was where a tunnel's end face and a mouth's face stand 1 cm out from the shell
  (`vault_proud`) and the wall behind their edge is the vault's, undrawn: a look past the edge met nothing. A strip
  in the wall's own finish now backs each such edge in the shell's plane (`StationSurface._add_backing`,
  `StationLook.vault_backing` 0.15 m).
- **The trains' fronts and ends** (7.png), against the owner's reference photos (`subway-model-references.zip` in
  the shared files, `04-cab-front/`, four photos of the same front, and `03-car-end-gangway/`; ratios below): the cab
  front has a rounded rim (0.12 m) round its face instead of square corners that stuck out past it. Its dark glass
  mask runs from just over the step (0.14 m) up into the roof's round (2.54 m), its sides following the body's lean
  and the roof 3 cm inside the rim, so it fills the front as one sweep of glass, as the photos' does; the lamp strips
  (longer, 0.4 to 2.12 m), headlamps and marker lamps follow it out. The door is a glass leaf with its window from
  0.42 to 1.94 m, its glass a shade off the mask's so the front reads as one sweep with the door's frame lines in it, the destination screen over it at the mask's head. The outer car end has its own rounded rim and a
  wide, round-headed bellows round its door, as the reference's gangway (2.3 m across, about two thirds of the end,
  to 2.35 m high): seven pleats folding in from a rubber reveal to the doorway, each rising to a crest just under the
  end sheet and back into a 5.5 cm recess, its outer slope pale and its inner one in shade; the door set back in
  them with a kick plate, a seam over the bellows and dark marker lamps high in the corners, the tail lamps moved out
  to clear the bellows. The slivers up the mask's sides (attempt 3's critic) were holes: `clip` cut each face cell with every edge of the
  car's outline, whose side steps in where its lean meets the roof's round (at CANT), so one edge's whole line cut away
  the cells beside the mask from there down and the rim's round showed through. `clip` now cuts a cell only with the
  outline's edges beside it and splits it at any such step, and the mask's outline and the face beside it share every
  point; the same fix closed a crack round the outer end's bellows head and its lower corners, and the open cab's
  left pane, which crossed itself. A test casts rays at each front and finds no hole
  (`test_the_cab_fronts_and_outer_ends_have_no_holes_in_their_faces`). `train_end_outer` is 3,603 triangles (budget
  2,600 to 3,700), `train_cab` 4,056 of 4,200.

- **The tunnel mouths, the owner's follow-up** (2026-11-17, after the PR opened: "the tunnel mouth needs to have
  slightly more gap on the sides between it and the train. it should be smooth. maybe add a subtle pattern around the
  edge of the tunnel"): each running tunnel is 3.9 m across (was 3.6 m), centred on its track (`layout.py RUN_Z0`,
  `RUN_Z1`), so a car has about 0.23 m clear each side through the mouth and along the tunnel (5 cm on the platform
  side before). The south train stands half in its tunnel, so two slots run beside it there (`run_s_in`, `run_s_out`).
  The cross passage and the grille (`tunnel_grille.py LINING` 1.95) follow. A band 0.24 m wide in the frieze's tiles,
  a few shades lighter (`mouth_ring`, green-grey #7a8983), runs round each mouth's arch and down its platform side,
  2 cm off the wall with its edges drawn back (`StationSurface._add_mouth_ring`, `StationLook.mouth_ring_*`). Pictures
  `09` to `09e` and `13-mouths-overview.jpg`.

## The models against their references

The owner's photo `04-cab-front/Screenshot 2026-11-11 113653.png` (front-on) against `train_cab`'s dimensions,
checked on the game's straight-on render (`11-cab-front-left.jpg` in `art/sw2-subway/`), each a share of the front's
width or of its height from the body's foot to the roof (2.7 m):

| Ratio | Photo | Attempt 1 | Attempt 2 | Now |
|---|---|---|---|---|
| The glass mask's width / the front's | 0.92 | 0.83 | 0.92 | 0.91 |
| The mask's height / the front's | 0.88 | 0.72 | 0.72 | 0.89 |
| The white cap over the mask (at its middle) / the front's height | 0.04 | 0.19 | 0.19 | 0.06 |
| The white band under the mask / the front's height | 0.05 | 0.08 | 0.08 | 0.06 |
| A lamp strip's length / the front's height | 0.60 | 0.57 | 0.57 | 0.64 |
| The door's window / the front's height | 0.55 | 0.25 | 0.36 | 0.56 |

Every ratio is within 10 % of the photo's but the white cap, which the rim's own round (0.12 m, the roof rounding
over onto the face) keeps at 0.06: the photo's glass runs on into the roof's curve, where the game's front must stay
inside the car's box; and the band under the mask (0.06, 0.14 m), which the door's step under it sets (the photo's
is about 14 px, inside the measure's own error). The outer end follows `03-car-end-gangway/` (the folded bellows round the gangway, about 0.7 of
the end's width and round-headed in the photos, 0.67 here, seven pleats where the photos show more, finer ones, at a
fifth of their depth to keep the end inside its box). The grille has no reference photo (the owner asked for "a
object model"); it is sized from the running tunnel's arch.

## What the bots showed

Bot matches, 6v6 (`tools/balance.sh subway`, Normal, seeds 1 to 16, every mode, the field's 22 s fuse), on this
layout (the east team climbing out of the tunnels):

| Figure | Before (SW1, Normal 32 seeds) | SW2 (Normal 16 seeds) |
|---|---|---|
| Elimination: the west end's share | 48.5 % ±3.2 | 46.1 % ±4.6 (53 of 115) |
| Attack / Defend: the attackers' share | 57.3 % ±3.2 | 47.9 % ±4.6 (56 of 117) |
| Plant The Bomb: the attackers' share | 49.3 % ±3.3 | 47.5 % ±4.6 (56 of 118) |
| Plant The Bomb: armed / armed gone off | 72 % / 10 of 161 | 65 % / 4 of 77 |
| Rounds that run out the clock | 0 | 0 in every mode |

Every figure is in its band (Elimination's "near an edge" is the 16 seeds' wide error, not its value), so nothing was
tuned: the fuse stays 22 s. Reports: the shared files' `pipeline/runs/SW2/attempt-1/`.

## Decisions

- **The east team climbs out of the tunnels:** the owner asked for no ramps and, in CL1, no trackside stairs; a climb
  over the platform's edge is the way up everywhere else, so it is the way up here too. The route tests
  (`test_mb1_layouts`, `test_sw1_qa`) now build the climb and vault links as play does.
- **The bend turns outwards and is 60° at 40 m**, enough that the grille's bars show the tunnel curving away out of
  sight with no straight look down it.
- **The cab's triangle budget is 4,200** (was 4,000): the closed face beside the mask needs its cells; the attempt 2
  critic said to raise it rather than skimp. Two cabs stand in Subway.
- **The running tunnels widen, not the cars narrow:** the cars stay 1.72 m a side (their platform doors meet the
  platforms' edges); the tunnels past the mouths are look and cover only for the east team's start, so 0.3 m more
  width there changes no lane.
- **Only the cars' sides moved in** (1.75 to 1.72 m): the tunnel's lining stays where the platform edges and the
  trains' doors meet it.

## Known issues left

- `train.py`'s tool trolley fails to build in this Blender (a material lookup), before this change too; its model
  was not rebuilt (a row in `docs/KNOWN_ISSUES.md`).
