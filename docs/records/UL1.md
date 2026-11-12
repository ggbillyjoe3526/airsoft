# UL1 · Subway lit as underground

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

The owner (2026-11-12): "Does the new art direction and ultra settings work in Subway map?" Renders of Subway, Depot
and Woodland on Low, Medium, High and Ultra (lavapipe Forward+, a whole PlaySession; pictures in the project files,
`art/graphics/ul1/`) found Ultra already right (lamps as real lights, no sun, SDFGI bounce), but High and Low took a
cold blue cast from the outdoor sky (45 % of the ambient and every reflection), Medium drew one flat shade (the stand-in
sun's shadow can't reach under the storeys) and footsteps kicked up the white default dust.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **`roof.underground`** (MapData.roof_underground; Subway only): no sky in the ambient light
  (`ambient_light_sky_contribution` 0) or the reflections (source disabled; the area probes and screen reflections
  still give the sheen from Medium up), and the sun never casts a shadow there (`GraphicsApply.sun_shadows`). A
  sky-share-0 test render alone took most of the blue out on High; turning the sky reflections off took the rest.
- **Medium on Subway** is lit by the stand-in sun without shadows, as Low is: it reads, but flat next to High. Real lamp
  lights on Medium would give it depth (the critic's note); not done, the Lamp light row is game-wide.
- **Footstep dust** grey 0xB0AEA8 at 0.9 size (Depot's is 0xB9B8B0 at 1).
- **Low on Subway** reflects no sky, so metal and polymer look matte there (no probes on Low).

## Known issues left

- `GraphicsApply.torch_mode` still reads the preset's Sun shadows, not the underground-aware one; harmless while no
  underground map has a night (KNOWN_ISSUES).
