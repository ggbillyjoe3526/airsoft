# RF1 · Retro filter: a 1990s console look (owner request, 2026-11-10)

William: "Can you redesign the dev retro pixel filter? I want it to look less like Doom and more like PS1 graphics.
Also rename it to Retro filter."

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | build thread | pending | pending | – |

## Decisions

Defaults taken without waiting (owner's defaults rule); each is a constant in `RetroFilter` or a slider.

- **Renamed Retro filter**, everywhere players and code see it (`RetroFilter`, `retro_filter.gd`/`.gdshader`, the Dev
  row, the wiki). An old save's Retro pixels switch is read as Retro filter's; its block size and 6 shades are not
  (another look: they would bring the Doom palette back), so the new keys start at the new defaults.
- **240 lines of square pixels** by default (the console's height), whole screen pixels each (1080p: 5 px, about 216
  lines; 4K: 9 px). The Lines slider runs 120 to 480 in steps of 24, replacing Pixel size (pixels on screen depend on
  the resolution; lines don't).
- **15-bit colour with the console's own 4x4 dither** (-4 to +3 eighths of a step) on the pixel grid, rounded to the
  nearest shade: 32 shades a channel by default, so gradients get a fine stipple instead of Doom's hard 6-shade
  bands. Shades runs 4 to 32.
- **Wobbling corners**: the props, racks, crates, containers, roof, doors, trees, bushes and flag cloth snap each
  corner to the retro screen's pixels through one global (`retro_snap`, `look/retro_vertex.gdshaderinc`); shadows are
  cast from the true shape. Off, it is one branch on a global per vertex. Not the level's blocks and ground, the site
  surfaces (floors, walls) or puddles: they are big faces laid a few cm over one another (the ground 2 cm under the
  floors), and a snapped corner tens of metres off tilts its face by more than that, so the ground showed through
  Depot's office floor as a flat tan (tried first, seen in the pictures).
- **Swimming textures**: the site surfaces' world-space canvases are laid straight across the screen, not in
  perspective, but at most 0.4 m from the true point. Unbounded (tried first), a floor, one big face, smeared into long
  streaks and the A SITE lettering broke up; the console's games cut big faces small, so their swim stayed local too.
- **Haze from 12 m to 70 m**, at most 85 %, in the map's haze colour (its night haze, else its horizon) at 55 %:
  depth cueing, through the map's own environment (FieldLighting.retro_haze), so it covers everything drawn. Off, the
  map's own haze is back.

## Known issues

- The replicas, arms, figures, BBs and puffs keep steady corners: they are glTF or code-made StandardMaterial3D
  materials, not the look's shaders. Snapping them would need their materials converted; not done (a Dev look).
- The haze dims the far end of Depot's 65 m hall line while it is on (a look only; Dev).
