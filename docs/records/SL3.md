# SL3 · Sunlit Concrete: Depot's roof repainted, the map pictures again

**Review:** 1 attempt · critic pending · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **The roof is a real warehouse's** (`tools/blender/maps/roof_truss.py`): trusses and gussets galvanised grey
  (`grey`), purlins `concrete`, the liner `concrete` at 92 % (an insulated liner panel, a pale grey under the warm
  light; plaster read yellow-beige), the rooflight strip `cream`, the sprinkler mains `crimson` (their real red, a
  small accent muted by the look's paint) and the heads `yellow`. `RoofConfig`'s fallback colours follow (truss
  `grey`, ceiling `concrete`). The lamp model is unchanged.
- **The hall's portal frames** (`hall_wall.py` `Frame`) match the trusses in grey. The exit doors, the fire point and
  the extinguisher stay crimson: real fire kit is red, and the look mutes it.
- **Edge scuffs moved out** (they were planned here): painting them into the models means rebuilding every map model
  with `weathering.py`; SL2's world-space wear already gives the grime. Left as a `can wait` row
  (`docs/KNOWN_ISSUES.md` › Art).
- **The map pictures again:** the three map cards (`assets/maps/`, with `cards/`) from their `docs/ASSETS.md` spots,
  and the wiki's hall picture (`docs/wiki/images/depot-chrono-hall.jpg`) at eye height from the hall's south end, in
  the new light, paint, wear and roof. The pictures grew (the Range's most, its wall and sky in the new grain), so
  docs/ASSETS.md says about 0.95 MB for the three now (The Street's went with the map); its old 0.4 MB was already
  short of what main held.

## Known issues left

- Edge scuffs and the doors' and lamps' wear wait for a polish pass (`docs/KNOWN_ISSUES.md` › Art).
