# RF1 · Retro filter: a 1990s console look (owner request, 2026-11-10)

William: "Can you redesign the dev retro pixel filter? I want it to look less like Doom and more like PS1 graphics.
Also rename it to Retro filter."

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | build thread | ✓ (touched files; full run cut short for the fixes) | 5/8 Retry | the map's own day haze lost after on/off; specks from self-shadowing; lettering broken; snap grid centred, not top-left; names, KNOWN_ISSUES, ART.md |
| 2026-11-10 | 2 | build thread | ✓ (touched files) | 8/8, Retry until QA and performance cover the new head | the lamps' shadow maps are kept while nothing moves, so a snap in their pass would go stale |
| 2026-11-10 | 3 | build thread | pending | pending | – |

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
- **Wobbling corners**: the props, racks, crates, containers, roof, doors, trees, bushes and flag cloth move each
  corner in the world so the main camera sees it on a corner of the filter's pixels, counted from the screen's top
  left as the filter's are (`look/retro_vertex.gdshaderinc`; RetroFilter sets `retro_snap` and the camera's view
  projection every frame while on). It moves VERTEX, not POSITION, so the engine's shadow bias and projections are
  untouched and off it is one branch per vertex. The colour, depth and sun shadow passes move it alike: snapping only
  the drawn pass (attempt 1) left surfaces shadowing themselves in black specks and dashes. A lamp's shadow keeps the
  true shape (attempt 3): Godot keeps a still lamp's shadow map, which could not follow the camera's snap. Not the level's blocks and ground, the site surfaces (floors, walls) or puddles: they are big faces laid a few
  cm over one another (the ground 2 cm under the floors), and a snapped corner tens of metres off tilts its face by more
  than that, so the ground showed through Depot's office floor as a flat tan (tried first, seen in the pictures).
- **Swimming textures**: the site surfaces' world-space canvases are laid straight across the screen, not in
  perspective, but at most 0.2 m from the true point (0.4 m still read A SITE as A BITE, critic). Unbounded (tried first), a floor, one big face, smeared into long
  streaks and the A SITE lettering broke up; the console's games cut big faces small, so their swim stayed local too.
- **Haze from 12 m to 70 m**, at most 85 %, in the map's own haze colour (the night's, or the site sky's by day; else
  its horizon) at 55 %: depth cueing, through the map's environment (FieldLighting.retro_haze), so it covers everything
  drawn. Off, the haze as it was is put back exactly (attempt 1 rebuilt it from the preset and lost the site sky's).
- **Small lettering breaks up at 240 lines** (A SITE reads A 8I7 at 1600x900): its strokes are about one retro pixel,
  as the old filter's were; the swim's reach was cut to 0.2 m to keep it from adding to that. Lines 360 or more read it.
  The black dots on Depot's cladding in the pictures are its screw heads, a whole retro pixel each.

## Known issues

Both are rows in docs/KNOWN_ISSUES.md: the replicas, arms, players, BBs, puffs and the level's big faces keep steady
corners; the haze dims Depot's 65 m hall line while it is on.
