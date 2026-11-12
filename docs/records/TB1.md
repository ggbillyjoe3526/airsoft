# TB1 · Subway's platforms like the Tube

**Review:** 1 attempt · critic pending · qa Pass · performance pending

Owner's ask (2026-11-12): "curved ceilings for the platforms. The yellow mind the gap line should only be on platform
edges. The wall opposite a platform should be back (same as in the tunnel). I want the map to look more realistic like
the London tube stations." After the first pictures: "Give the tiles a more white/grey look. Also, the far side track
black wall not be black anymore. It should be white and almost match the rest of the station design. There can be
larger posters on the walls."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | ✓ | – | – |

## Decisions

- **One tunnel a platform.** Each platform and its track share a deep-level tunnel (`layout.VAULTS`, x -52 to 50,
  7 m across) under a barrel vault springing from both walls at the old ceiling's height (game 4.1 m) and rising
  `VAULT_RISE` 2.5 m. Nothing below the springing moved: walls, openings, cover, climb ledges and sight lines are
  the greybox's. Vault rooms (`room(vault=True)`) have no ceiling slab; their walls stop at the springing.
- **Colliders hug the curve.** `build_map.vault_pieces` cuts the arc into pieces (41 a vault) whose bounding boxes,
  run up to the vault's top, stand at most `VAULT_PROUD` 8 cm in front of the drawn arc and never behind it, so a BB
  never slips into the tiles. Side walls close the trackside over the car roofs (3.6 to 4.1 m); end caps close the
  vault's ends over the walls and the tunnel mouths. `vault_air` opens the space over the standing cars into the
  vault (the old lintels there are gone): a BB or a bomb can now cross over a car roof.
- **Drawn curved.** StationSurface skips every block inside a vault's lid (`StationDressing.in_vault`) and draws the
  arc in 32 strips with smooth normals plus its two end caps, 1 cm proud of the shell's ends. Lamps in the vault rooms
  hang under the arc, low enough that the panel's wall side clears it.
- **The edge.** A 0.45 m pale coping, MIND THE GAP in white block capitals (`PlatformWords`, a 5 x 5 pixel font, one
  every 12 m, reading from the platform), and a 0.1 m painted yellow line behind it; the 0.4 m tactile strip went.
  The yellow is the one safety colour: `StationLook.safety_finishes` lets its tint be saturated, checked to lie in
  the yellow band.
- **White tiles.** `wall_tile` is white, faintly cool (was cream), everywhere in the station; the vault wears its own
  `vault_tile`, a shade cooler, because the warm light from below turns a down-facing white tan. The trackside wall
  (style `track`) wears the same tiles. The first pictures read "back" as "black" and gave it the tunnels' lining:
  the owner turned that down, and a dark wall also darkened its area's reflection probe, blacking out the vault's track
  half.
- **Posters** on the trackside walls are the lamps and extras thread's (SM5): three 3 x 1.5 m on the north wall, four
  on the south, centred 2.3 m up.

## Known issues

- The station's light is mostly area probe ambient; a down-facing surface still reads a little warmer than the walls.
