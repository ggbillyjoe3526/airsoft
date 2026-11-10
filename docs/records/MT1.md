# MT1 · Kingsmere, the metro station, as a Dev-only greybox map

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | ✓ | Retry 7/8 | flag A's letter stood half inside the south car's roof |
| 2026-11-10 | 2 | thread | ✓ | Accept 8/8 | – |

## Goal

The owner (2026-11-10 07:13): "Add this to the game as a dev only map", the metro station of concept v2
(`/mnt/project-files/concepts/metro/v2/`): a ticket hall at street level, a booking hall and concourse below, two
platforms with abandoned trains and running tunnels at the bottom; one spiral stair and one normal stair, each one
level; tunnels just above the trains; close quarters until the platforms; the Street team starting in the ticket hall
and the Tunnel team in a tunnel.

## Approach

- **Built by a script.** `tools/kingsmere/layout.py` holds the rooms (boxes of air with a floor, ramps for the
  escalators and steps), the cover and the spots; `tools/kingsmere/build_map.py` walls, floors and roofs every room,
  cuts the openings between them and writes `data/maps/kingsmere.json` (854 blocks, 56 areas, three storeys). The
  game's y is the concept's plus 18.9 m: track 0, platforms 0.9, landing 4.9, concourse 8.9, ticket hall 18.9.
- **Dev content:** its row in `data/maps.md` is tagged dev, standard 6v6, semi-auto start (indoors).
- **Low poles** (`poleHeight` 2.1 m): FlagView draws the pole, cloth and letter scaled down so flag A fits inside the
  south car (2.4 m inside); the letter sits on the pole's top (critic, attempt 1).
- **Light:** a plain roof (`roof.plain`) draws no bays or trusses; each lamp names its own ceiling (`lamps[].y`), a
  strip panel on every room's ceiling (106); each lamp's light reaches only 2.5 m past the floor under it
  (`RoofView.plain_reaches`, `MapData.floor_under`), so no level lights the one below. Reflection probes on a map in
  storeys span each area's floor band, captured from eye height over that floor (the probes at y 0 inside the slabs
  tinted High green).
- **Bots:** the lanes end at the flags, so the Tunnel team's defenders hold the stair under B, B's landing, the south
  platform's end and train A (they held the tunnel and lost 97 % of Attack / Defend rounds on the first run).

## Defaults taken

- The Street team attacks first; teams swap at half time.
- The lift shafts stand shut until MT2 makes the lifts work; bots don't use lifts yet.
- Poles 2.1 m tall (a car is 2.4 m inside).
- The south platform's 58 m sight line is the field checks' one exception for Kingsmere (60 m; 34 m elsewhere).
- Greybox look: plain boxes and strip lamps; the station's models, tiles and signs come later.
- Medium draws underground in flat shade (the lamps light only High and Ultra; see Known issues).

## Checks and balance

- `tools/check.sh`: gdlint, changelog notes, wiki, unit tests (all seven parts), smoke and licence notices pass.
- Balance (8 seeds, Normal, `pipeline/runs/MT1/attempt-1/balance-report.md` in the shared files): Attack / Defend
  attackers 67.7 % ±5.8, Elimination's east end 56.7 % ±6.4, both within noise; no round ran out the clock.

## Known issues left

- Kingsmere's balance needs a 32-seed run before tuning (KNOWN_ISSUES, Maps).
- The lifts are shut until MT2; the station is a greybox (KNOWN_ISSUES, Maps).
- Medium draws the station in flat shade (KNOWN_ISSUES, Graphics).
