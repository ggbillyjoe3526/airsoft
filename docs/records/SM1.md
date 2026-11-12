# SM1 · Subway's trains in their models

**Review:** 4 attempts · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | pass | Retry 7/8 | judgment: proportions against the photos (doors too short and narrow, sills too high), open window corners, banding on the white paint, flat seat-end screens, a black gangway edge, a black frame round the cab fronts |
| 2026-11-12 | 2 | Opus 5.5 (build thread) | pass | Retry 7/8 | judgment: the cab ends (a tiled card round each cab under the platform vault, notches at its top corners, a white sliver and a dark ledge at the open cab) |
| 2026-11-12 | 3 | Opus 5.5 (build thread) | pass | Retry 7/8 | judgment: a pale strip beside the open cab in the running tunnel |
| 2026-11-12 | 4 | Opus 5.5 (build thread) | pass | Accept 7/8 | – (judgment miss fixed before merge: QA had overwritten main's `test_sm1_qa.gd`; restored, its test moved to `test_sm1_trains_qa.gd`) |

## Decisions

- **The trains are drawn by `TrainView`, not as props.** The map's `dressing.trains` (written by `build_map.py` from
  `layout.TRAINS`) gives each train's box, its cars (middle, turn, the platform side's open door slots, what stands at
  each end) and its open gangways. `TrainView` lays each car's body, lamp strips, shut door pairs and ends, and each
  gangway, in one MultiMesh a model; `StationSurface` leaves the walls, slabs and car ends inside a train's box to them
  when every model loads (else the boxes are drawn as before, warned once).
- **What you see is what you hit.** The models fill the train's boxes exactly (a test lays every instance inside its
  train's box). The seats are real
  0.45 m `furniture` blocks named `train_seat`/`train_seat_short` (low cover, FIT); the bays beside the two tool carts
  have none, keeping a metre of aisle each side. The poles, rails, cove, seat-end screens and handles are look only.
- **The north gangways widen 10 cm to 1.2 m**, matching the south's (the only collision change).
- **The south train's west end is an uncoupled end** (its outside face, end door, tail lamps and underframe drawn);
  its east end is the open cab, the way out onto the track, **climbed into from the track with no steps** (owner,
  2026-11-12: "shouldn't have a ramp"; the cab's ramp room is gone, the south tunnel runs on to the end). Merged
  with TB2's arched running tunnels, whose detrainment steps (`cab_steps`, there until SM1 landed) go the same way:
  the south tunnel is one vault room from the cab on. A room's end opening into a vault room's now opens up to the
  arch over it (`build_map.arch_over`), so the cab door no longer warns it is walled (the doorway was open to the
  car's roof before and after: no block changed).
- **The wheels** (owner, 2026-11-12): under each train's two ends a space 0.75 m tall runs in 3.85 m over the track
  (its own track room, `layout.UNDER_ENDS`, opening into the track however low, `opens`), and in it the bogie stands
  on the rails as a block of its own (`cabinet`, 2.7 x 0.64 x 2.4 m from its flanges' foot, 3 cm under the rails'
  top, to the car's underside; named `train_bogie`, FIT): low cover nobody walks into, BBs fly in under the coupler.
  Its model (2,920 of a 3k budget, set here: the list has no bogie) has four wheels with flanges inside the rails,
  axles and axle boxes, two coil springs a box, dropped side frames with an air spring each, two transoms, a motor
  and gearbox an axle and a tread brake a wheel; 0.56 m wheels so the flanges clear the car's underside. The ends
  draw the underframe over it (its underside, sole bars, pipes and conduits, the slab's end behind the bogie) and the
  coupler hanging in the mouth on its draft gear, look only. Bogies sit under the four train ends only, not under
  each car's middle joints, where the floor slab stays solid.
- **The roof is round** (owner, 2026-11-12: "more curved on top"): from the door heads (1.95 m) the side curves in on
  a quarter ellipse to a crown at the top of the train's box (2.7 m over the floor, the ceiling slab's top), so it
  shows under the tunnel's vault from a platform. The cab and end faces are cut to that outline, and nothing is
  drawn across the box's corners beside it: past a cab's corner the eye goes on down the tunnel, as at a real train
  (attempt 1's critic: a black frame; attempt 2's: a tiled card). Where the box's sides, top and foot meet the ground,
  the station lines them facing in (`StationSurface.lining`) in the finish of the tunnel round the train: the trackside
  wall in the track's tiles, the south train's last 10 m (in its running tunnel) in the tunnel's concrete, sides and
  roof; over the crown under a platform's vault nothing is drawn, the vault (TB1) showing over the train. A wall's
  face standing flush past the box and looking into the cars (the running tunnel's ends at the box's edge) is drawn in
  that lining too, never the cars' inside paint (attempt 3's pale strip by the open cab was one of those, 30 cm wide).
  The station's lamps inside the cars light the cars and whoever is in them, not the station's surface (its own
  render layer, `StationSurface.LAYER`), so beyond the eye's near lamps (unshadowed) they never light the tunnel walls
  through a car's sides. The box stays square: the curve leaves its corners open to the eye but solid.
- **The cars are round all over** (owner, 2026-11-12: "more round and less boxy"; "the carriage doors should also
  slightly curve as the roof curves up"): one cross-section (`train.py z_at`) for every side, door, end and cab: the
  foot curves in 12 cm under the side (a quarter ellipse up to 0.4 m), the side stands upright to 0.55 m, then leans
  in, 20 cm by the door heads, and the roof rounds on over on a superellipse (power 2.2) to the same crown. The doors'
  skins follow it, so their heads lean in as the roof begins; the inside walls lean with it (7 cm in from the skin,
  never further out than before), the cove and ceiling a little narrower (the ceiling's edge 1.15 m from the middle,
  was 1.30), and the end walls are cut to the inside's outline so their corners never poke out through the roof. The
  gap under the curved foot to the box's edge looks down onto the station's lining (above), no dark strip (attempt 2's
  critic: a ledge wider than the car under the cab); the floor slab's edge under an end stops at the foot. The
  cross-section went to the platforms thread for the tunnels' arch.
- **The seats are 7 cm deeper** (owner, 2026-11-12: "slightly longer (not the back rest)"): the seat blocks are 0.52 m
  deep (was 0.45), the padded backs unchanged; the aisle stays 2.16 m between them.
- **A train holds no floor more than 0.5 m under its cars' floor** (`TrainDressing.BED_DROP`): the track bed under an
  end is the station's to draw.
- **The fields' walks follow the bots' routes, climbs and vaults included** (`FieldMeasure.walk`, the layout test
  links the grid's vaults): with the ramp gone the Tunnel team's walk on foot to flag A ran round by the north tunnel
  (67 m, under the 1.6 head start), though bots and players climb into the open cab (55 m, 1.94 times, as with the
  ramp). Depot's and Woodland's figures are unchanged by it.
- **A climb finds a ledge over open space at its lip** (`VaultConfig.overhang_probe`, 0.85 m): where nothing stands
  at the face probe (0.4 m), the face is looked for again higher, so the open cab's floor over the bogie's space is
  climbed as a platform's edge is, by the player and the bots. Nothing else in the maps floats with open space under
  it in reach.
- **The station's ceiling lamp fittings are hidden inside the cars** (`RoofView.hide_lamps_in`), their lights kept
  and shone in the cars' cool white (owner, 2026-11-12: "the interior lighting should be cool white"): each car's own
  lamp strips glow in it (`TrainLook.lamp_colour` 0.88, 0.94, 1.0).
- **Some lights flicker** (owner, 2026-11-12), read as the cars' lamps (the LEDs stay steady): three of the trains'
  station lamps are marked `flicker` (`layout.py FLICKER`: the north train's second car's west half and third car's
  east half, the south train's first car's east half), so their lights flicker as Depot's worn lamps do, and the strips
  of the half car under each step with them (`TrainView`, the same pure `RoofView.flicker_level`). The strips are a half
  car's model laid twice a car so each half can flicker on its own.
- **White LED lamps at both ends** (owner, 2026-11-12): the cab's side strips, headlamps (seven emitters each) and
  marker lamps, and on the uncoupled end two round lamps and a running-light strip set into the end sheet (inside its
  box), are their own models (`train_cab_leds.glb`, `train_end_leds.glb`) drawn glowing (`TrainLook.led_colour`,
  `led_energy` 4). They glow only: no real light shines from them (no extra lights to pay for).
- **Budgets** (art/subway-model-list.md): a car is 22k (12k outside, 10k inside) for its body (14,952: the curved
  sides' rows and the see-through windows' reveals, their corners 5 segments, was 6; the body's own cap 16.4k out of the
  car's), its window glass (220), its eight door pairs (602 each the far side's, 610 a glazed one, with 56 of glass;
  640 each, was 600, for the taller doors' rows) and its seats (up to about 1,400 a car): about 98%. A blank end 1,331
  of 1.5k; the gangway, two car ends, 2,856 of 3k; a cab front 3,784 of 4k (open 3,232); the uncoupled end
  2,438 of 2.6k (the end's 1.5k and its underframe; 100 more than the
  first 2.5k for its curved outline and the recessed lamps); the tool cart 1,366 of 1.5k; the bogie 2,920 of 3k; the
  LEDs 256 of 270 a cab and 172 of 180 an uncoupled end.
- **An orange stripe** (owner, 2026-11-12: "give the trains an orange stripe") runs 0.66 to 0.84 m over the car floor,
  just under the windows, along the sides and doors and round the ends and cab corners, in a worn burnt orange
  (#c0652f), darker than Beta's bright #fa8c29. Orange can't keep clear of Beta's hue, so it is the one colour let near
  a team's (the owner's ask over the team colour rule); everything else stays worn grey with no logo, the cab mask a
  neutral near-black (a test checks every other train colour). If it is ever mistaken for a Beta player, a golden amber
  (40 degrees or more off) would clear it.

- **The platform side's windows are see-through** (owner, 2026-11-12: "Can the player see through them? If not then
  make this change."): each window between the doors and each shut door's two leaf windows is a `glass` block through
  the side's wall (`layout.py WIN_Y`, `car_windows`, `DOOR_WIN`; `build_map.py train_glass` cuts the wall round it),
  which stops BBs and bodies but not the eye, so players and bots see into and out of the cars (64 panes). The models
  draw the glass: the body's and the platform doors' windows open through to a reveal, their panes their own models
  (`train_windows.glb`, `train_door_glass.glb`) drawn in the clear material at 0.3 opacity (`TrainLook.glass_opacity`;
  the clear shader's new `opacity`), and MapLevel leaves the trains' glass blocks to them. The far side's windows and
  doors stay dark glass: the cars stand against the tunnel wall there. The cab windscreens and end door windows stay
  dark (nothing past them to see). New sight lines into the cars change how the flag in the south train is held; the
  checklist asks for a play check.
- **The cars are clean white** (owner, 2026-11-12: "more clean white than the grey"): the body paint is #e6e6e2 (low
  sides #d6d6d2, seams #9a9a96), and the outsides' baked grime is 40% of what the grey cars wore (`train.py CLEAN`).
  The stripe, rubber, skirt and underframe keep their colours.

- **The doors and windows follow the photos' proportions** (attempt 1's critic, against
  `art/references/maps/subway/01-train-car-outside`): the side doors are 1.6 m wide (was 1.4; `layout.py DOOR_HW` 0.8,
  the door gaps in the sides with them) and 2.25 m tall (was 1.95), running up into the roof's curve, the leaves
  curving with it and the hole cut up through the cove inside (a next-stop screen in the cove over it, a grab bar
  across its head); the windows' sills are 0.85 m (was 0.95) and their heads 1.95 m, the door windows 0.95 to 2.0 m.
  Door width to height 0.71 (the photo's 0.75), car to door height 1.2 (about 1.1), sill 0.38 of the door (0.38),
  window 0.49 (0.54). The end doors stay 1.95 m (`END_DOOR_H`). The seats' bays are 20 cm shorter with the wider doors.
- **Finish** (attempt 1's critic): every window's frame closes its square corner (`squared` puts a point on each
  corner, so an odd count of segments leaves no gap); the cars' world-space wear is 0.3 (`TrainLook.wear`, was 1) and
  the outsides' baked streaks are gone, so the white has no vertical bands; the seat-end screens are 4.5 cm thick; the
  gangway's passage is lined pale grey (`gang_in`), its black bellows showing only in the gap outside.

## Known issues left

- The round cars leave the train box's edges open to the eye but solid: beside the leaning sides (up to 20 cm by the
  door heads), over them beside the roof, and under the tucked-in foot (12 cm), and past a train end's corners. A BB
  aimed into that sliver stops on air a few centimetres short of the car (or, past an end's corner, on air level with
  the end); you can't reach it to walk into.


- A BB at a platform-side window stops on its glass block, the side wall's box, up to about 5 cm outside the drawn pane
  (the pane follows the leaning side; the block is the wall's straight thickness), and the block is 5 cm larger than the
  pane all round (the pane sits in its frame's rubber). Not visible in play. A shut door's panes, flush in the door
  leaf, stand about 8 cm further into the car than the 15 cm block (from inside, a BB passes the drawn pane and stops on
  the block just beyond it; not visible in play).

- The door-edge poles stand over open floor in the two seatless bays beside the tool carts (look only; you walk
  through them there).
