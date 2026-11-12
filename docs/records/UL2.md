# UL2 · Subway's ceilings on Ultra

**Review:** 1 attempt · critic pending · qa pending · performance pending

The owner (2026-11-12, after UL1's pictures): "Ultra on subway looks broken? The shadows are very dark and the ceilings
are black." It was so before UL1 too: on Ultra the scene's bounce light (SDFGI) replaces the ambient light, and
underground nothing but the lamps' bounce reaches a ceiling, since every lamp is a light shining down.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | ✓ | – | – |

## Decisions

- **Stronger bounce underground:** SDFGI energy 1.5 and bounce 1.0 under an underground roof
  (`LookConfig.sdfgi_*_underground`, set by FieldLighting.set_underground), against 1.0 and 0.5 above ground.
- **Strip lamps feed the bounce 5x** (`RoofConfig.plain_lamp_indirect`, a plain roof's lamps only): a tube lights
  the ceiling round it, which a light shining down can't. Depot's high bays keep the engine's 1.
- Tried on lavapipe, Ultra, the ticket hall's top fifth: 8 of 255 before, 13 with the stronger SDFGI alone, 27 with
  the lamps' 3x bounce alone, 57 with both at 1.5 / 1.0 / 5x (High's is 81). The shade under the hall's pillar stays
  the darkest part, softer. Ultra only: High's screen bounce doesn't read a light's bounce share.

## Known issues left

- The running tunnels' ceilings stay near black on Ultra (their lamps are fixtures with no light of their own; TB2's
  tunnel lamps bring their own lights).
