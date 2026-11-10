# MT2 · Kingsmere's working lifts

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | ✓ | Retry 7/8 | the golden angle and the beep's reach were unnamed numbers; the performance report was missing |
| 2026-11-10 | 2 | thread | ✓ | Accept 8/8 | – |

## Goal

The owner's concept v2 feedback (2026-11-10): "working lifts". MT1 left Kingsmere's two lift shafts by the ticket hall
shut; MT2 makes them work for players and bots: two cars, each serving the platforms (0.9), the concourse (8.9) and
the ticket hall (18.9).

## Approach

- **The map.** `tools/kingsmere/layout.py` names the shaft, its two cars and their stops; `build_map.py` cuts the
  whole shaft out of the station's shell and builds its walls, a partition and the pit's floor with a doorway a car a
  stop on the north face, and writes a `lifts` list (each car's well, door, stops, names and start stop) that
  `MapData` reads and checks (a malformed lift is left out with a warning).
- **The rules** (`game/sim/lifts.gd`, `LiftState` in `GameState.lifts`, `LiftConfig`): calls kept as bits; a car rides
  to the nearest called stop ahead of it, stopping on the way; doors open, dwell, shut and only then does it move.
  Use (G) presses a lift button first: the landing's call button in reach, or the car's panel button nearest the
  view; bots name theirs in the command. Doors stay open on a body in the doorway, with a hit player aboard (who
  walks off rather than rides), or over capacity (the buzzer). The car carries its riders before they move, so they
  ride with no jitter. Each cue is a `LIFT` event: heard by bots and on the minimap as a door is, played by SimAudio.
- **Colliders.** `MapLevel` adds a car's floor and roof as one static body moved each tick with `body_set_state` (Jolt
  sees the new place at once, so a rider never sinks a tick) and a doorway shape a stop, solid unless the car stands
  open there; BoxWorld does the same for tests.
- **Bots.** `NavLifts` links every two stops' landings of each lift both ways, priced as the ride's time at a run plus a
  wait, joined into the vault regions; walk-offs never take a link. `BotLifts` walks a link as a player would: call,
  wait, board to its own spot, press its stop, ride, walk out; it gives up and walks after `lift_patience` (20 s). A
  route asked for inside a car starts at its landing. In an over-full car the highest ids step back out (QA).
- **The view** (`LiftView`): a greybox car (painted steel, a ceiling strip, its lamp and stop names), the landings' and
  cars' leaves sliding into the walls, call and panel buttons lit warm white while called. The shafts lie outside every
  area's reflection probe, so each car carries an interior probe of its own (without it the car mirrored the sky's
  blue); the steel is not metallic for the same reason.
- **Sounds:** placeholders synthesised by `tools/lift_sounds.py`: a two-note chime, the doors, the motor, a button's
  beep, the buzzer.

## Defaults taken

- 4 a car, 1.5 s doors, 4 s a floor, 2 s open at each stop; a car with no calls stands open where it stopped.
- The west car waits at the ticket hall and the east one at the platforms as each round starts.
- The car's panel is pressed by looking at a button (no menu), the same G as doors; the HUD names the stop.
- Lit buttons are warm white: amber read as Beta's orange (the colour vision check).
- Bots ride when the ride is quicker than the stairs (a 4 s wait priced in); walk-offs always walk.
- The sounds are toy-like placeholders until the owner records a real lift (`audio/record-next.md`).

## Checks and balance

- `tools/check.sh`: gdlint, changelog notes, wiki, unit tests (all seven parts), smoke and licence notices pass.
- Balance (8 seeds, Normal, `pipeline/runs/MT2/attempt-1/balance-report.md` in the shared files, the reviews'
  reports beside it and in `attempt-2/`): Attack / Defend attackers 46.9 % ±6.2 (MT1: 67.7 %), in band;
  Elimination's west end 57.1 % ±6.2, within noise; no round ran out the clock.

## Known issues left

- The lifts' sounds are synthesised placeholders (KNOWN_ISSUES, Maps).
- A car is a greybox box; its model comes with the station's models.
- Can wait (QA): someone standing on a car's roof isn't carried (Kingsmere's shafts can't be reached above a car); Use
  presses a lift button before a hinged door, so a door within reach of a call button would need its own key (no map
  has one). A doorway is solid from the moment its doors start to shut until they are fully open again, so a BB
  through a half-open gap stops on it for up to 1.5 s (critic).
