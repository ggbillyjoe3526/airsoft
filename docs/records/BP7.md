# BP7 · Fix as many of the remaining known issues as possible

**Review:**

- part 1: critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-07 | part 1: 1 | Opus 5.5 | green | Retry 6/8 | doors and poles outside the bake's light, the Lounge not dim, rows 68/78, changelog |
| 2026-11-07 | part 1: 2 | Opus 5.5 | green | Accept 8/8 | – |

## The pass

Asked by the owner on 2026-11-07 09:47, after BP6: "Fix as many of them as you can. If you have to ask me a question
then ask." The 92 rows of `docs/KNOWN_ISSUES.md` were sorted into fixable now (51), the owner's decision (10, asked on
cards; his picks are in `docs/DECISIONS.md` where they bind later work), his play (22) and limits kept on purpose (10).
Five workers took one area each in their own worktree (bots, graphics, maps, menus, figures). Each area goes out as its
own pull request with the critic, QA and performance agents; pictures of visual changes are in
`/mnt/project-files/playtest/bp7/<area>/`.

### Part 1: graphics and performance

Branch `bp7-graphics` (from origin/main 5004551), commits 6718f6a and 3fa357f (the critic's retry), squashed into this
pull request. Rows from triage A2: 24, 32, 48, 53, 63, 72, 79, 80. Rows 68 (the scope's view cone) and 78 (a probe light
for the figures and puffs) are A2's too but went to the figures part (part 2 or later), which fixes 68 and narrows 78.

#### What changed

- **Occlusion culling (row 72).** A new Graphics row `occlusion_culling` (off on Low, on from Medium; Cost 0; all
  renderers) sets the root viewport's `use_occlusion_culling` (`GraphicsApply.apply`). `MapOccluders`
  (`game/play/map_occluders.gd`) builds one ArrayOccluder3D a match from the tall solid plain blocks
  (`MapStyle.occluder_kinds`: plywood, crate, container, wall, house, brick, hoarding, shed, hedge; no ramp, no prop,
  at least 1.8 m tall and 1.2 m long, inset 0.03 m): Depot 98 boxes, Woodland 37, the Street 100. Label and tooltip in
  `en.po`; the row on the Light and detail column (`settings_graphics_page.gd`, two lines). Compatibility does cull
  (checked under Xvfb: 201 draws to 1 behind a wall), so the old row's "Compatibility does no occlusion culling" was
  wrong.
- **Smoke puffs on the presets (row 48).** `EffectsConfig.smoke_puffs` by Mesh detail, 12 / 20 / 28 / 28;
  `GrenadeView.set_puffs` draws that many of each cloud's 28, each sqrt(28 / n) wider so the cloud covers as much.
- **Shared light (row 24).** Doors (`DoorView`), both flag views' poles, bases and ropes, and the skyline's pieces
  draw on `look_vertex.gdshader` (`LookMaterials.paint` for a one-colour mesh). The grass tufts keep their own light
  (by design, ART.md).
- **Depot's dim Lounge (row 32).** `bakedLight.dim` in a map file (MapData `baked_dim_boxes`, `baked_light_at`):
  the bake's sky share and bounce in the box are its `light` share (the Lounge 0.35, `tools/depot/build_map.py`
  `DIM_LIGHT`, written from layout.py's `light="dim"` zones). Part of the bake's hash. Depot rebaked.
- **Hidden vertices (row 79, part).** `bake_light.gd` `fill_hidden`: a vertex whose rays start strictly inside
  another block takes the light of the nearest open vertex on its face (breadth first over the face's grid,
  `GreyboxFaces.Tiles.grids`); the joint vertex keeps its own shade. `BakeConfig.VERSION` 2; Depot and the Range
  rebaked.
- **Skyline sight (row 80).** Pieces are tried nearest the field's middle first; each one built hides what stands
  beyond it through its solid boxes (`SkylineShapes.hides_of`: shed, containers, each silo drum's square, a hill's
  core under its mound; none for the thin or open kinds), `SkylineSight.add_box`. Only built pieces hide.
- **Woodland's draws (row 53).** Often-laid props (trunks, spruces, cordwood) chunk at `PropDressConfig.many_chunk`
  40 m; the tiled shelving keeps `chunk` 20 m.
- `tools/eye_pictures.gd` also draws the map's doors and Attack / Defend poles.
- **Retry: the doors, poles and props in the bake's light (rows 24, 32).** `BakedLightNear` (`game/map/`, made by
  `MapLevel.baked_lights` while the bake is drawn): the mean light of the baked vertices within 0.75 m, facing a way
  or any, from a 0.75 m grid built once. DoorView draws on its own `door_leaf.gdshader`: each face of a leaf takes the
  light of the wall's face on its side, 0.4 m past the jamb (instance colour one side, custom data the other), so a
  Lounge door is dim on the Lounge's side and lit on the hall's. FlagView and OvertimeFlagView tint the pole, fittings
  and rope by the floor's light at the foot (the overtime flag where it goes up); PropDress multiplies each prop's
  shade by the light 0.5 m over its foot. PlaySession relights them when Baked light switches; off, all draw as
  before.
- **Retry: the Lounge dim (row 32).** MapLevel now draws a dim room's open share at its light too (the bake already
  dims its sky and bounce), so the Lounge's whole light is 0.35 of the hall's; no rebake (the hash is the bake's
  inputs). `build_map.py` `roof()` hangs no lamps over a dim room: Depot's 4 Lounge lamps go (97 to 93).
- **Retry: prewarm.** `FlagView.materials()` and `OvertimeFlagView.materials()` add the pole, fittings and rope
  paints (5 and 4 materials).

#### Rows fixed and deleted

- 24 (doors, poles, skyline in the shared light; on Depot the doors and poles in the bake's light too), 32 (the
  Lounge dim: its whole light 0.35, its doors and props in it, no lamps over it).

#### Rows left

- 48, narrowed: the puff count is on the presets; the GPU cost inside a cloud on Low and at 4K is still the owner's
  check (no GPU here).
- 53, rewritten: re-measured on the new wood (Compatibility, Xvfb, 1920x1080, 5v5 seed 7, 64 frames, occlusion off):
  336 draws a frame (510 peak, 649K triangles) before, 303 (467 peak, 748K triangles) after the 40 m chunks. Still
  over 150: in a frame of 371 the props are 93 (167 in 20 m chunks), the sun's shadows about 85, the figures 100, so
  the line needs the figures (A5's) or the shadows, and Forward+'s own count on the owner's PC first. Class document.
- 63, unchanged: spreading the ticks above 100 % needs every drawn thing's state two ticks back (Character, BBs,
  grenades, targets, tossed magazines in game/sim) and every view reading prev values to use it, the HUD's markers and
  minimap among them (game/ui, another worker's this pass); and kept-two-ticks still stalls for some rates between 1
  and 2 (three are needed for none). Dev-only speeds; left for a pass that can touch game/ui and game/sim together.
- 72, rewritten as a playtest row: draws measured (below); the cull's CPU cost and the GPU gain on Forward+ are the
  owner's check, comparing the row off and on.
- 79, narrowed to the ground beyond the walls (one quad, no contact shade at the outer walls' foot): baking it needs a
  tiled strip round the field in the bake's mesh and format; the hidden-vertex half is fixed.
- New rows: Depot's site details (crate lids and battens, container frames, plywood caps, sandbags, stencils) and
  the flag's cloth and ring take no bake; and on Compatibility the site's faces draw darker and more saturated than a
  flat paint in the same light (below), so doors and poles stand out there. Both can wait.
- 80, narrowed to the owner's Forward+ look check (now in the shared light). Note: on today's maps no piece hides
  another (Woodland 8 of 8 built, the Street 4 of 4, the old yard 39 of 40 as before), so the gain is for later maps.

#### Defaults

- Occlusion culling Cost 0 (it costs the GPU nothing; its CPU cost is in the row's note) and on from Medium.
- Smoke puffs 12 / 20 / 28 / 28; width grows sqrt(28 / n) so the cloud's coverage holds.
- Dim share 0.35 for the Lounge, now its whole light; no roof lamps over a dim room (removing, not dimming: the lamp
  panels are self-lit with no light of their own, so a dimmer panel would change nothing below it).
- A door samples the wall 0.4 m past its jamb at mid height; a pole the floor (facing up) at its foot; a prop every
  face within 0.75 m of a point 0.5 m over its foot.
- Hidden vertex test strict (inside, not on a boundary), so a wall's foot keeps its contact shade.
- Woodland's often-laid props in 40 m chunks: about 10 % fewer draws for about 15 % more triangles (still half the
  1.5 million target).
- Touching game/ui: the new row needs its label and tooltip (`en.po`) and its place on the page
  (`settings_graphics_page.gd`); four short additions, no other UI change.

#### Checks

- GUT (targeted, headless): test_bp7_graphics (new: the row, the viewport switch, the occluder rules and boxes on all
  three maps, the Lounge's bake, the dim hash and parsing, the 40 m chunks), test_skyline (+2: a far piece hidden by a
  near one, only solid kinds hide and the hill's core stays in its mound), test_sf1_qa (+1: fewer, larger puffs),
  test_baked_light (under the crate takes an open neighbour's light; the wall's foot keeps its shade), and the
  graphics, settings, look, doors, flags, play session, props, bake and site suites: all pass (550 tests, 592,488 asserts, 0 failures in the last combined run).
- gdlint on every changed file: clean. `tools/changelog.sh check`: OK. `python3 tools/wiki.py check`: OK.
- Measured under Xvfb (Compatibility, llvmpipe, 4 shared cores, 1920x1080, High, a whole 5v5 bot match, seed 7,
  occlusion alternated every 10 frames, 64 frames each): Depot 286.6 to 254.1 draws (peak 435 to 389), Woodland 302.7
  to 293.9 (467 to 406), the Street 165.4 to 169.5 (noise). The render CPU times there are the software rasteriser's
  (0.8 to 1.8 s a frame) and say nothing about the cull's cost.
- Bakes: depot 117,801 vertices in about 50 s, range 15,412 in 3 s.
- Pictures (Compatibility, Xvfb, High, eye height; map models, not a figure or the arms), before | after, in
  `/mnt/project-files/playtest/bp7/graphics/`: woodland-door, woodland-pole, woodland-skyline, depot-door,
  depot-pole, depot-lounge, depot-lounge-edge, depot-joints, depot-joints-yard.

- Retry, measured: the critic's 1.5x doors were the simpler renderer's. On Forward+ (llvmpipe under Xvfb,
  1600x900, High) a door in the plywood's own paint draws 214,195,167 by the wall's 204,185,156, so a flat paint and
  the site sit in the same light; on Compatibility the same door draws 239,226,207 by 216,185,136 (the site's faces
  darker and warmer there, a new row). The bake at the doors outside the Lounge is 0.95 to 1.12 (headless), so it
  barely changes them; on the Lounge's side 0.33 to 0.45. Before | after on Forward+ (main 5004551 | the retry):
  the Shoot House door 36,66,35 | 64,114,60 (paint 56,102,69; main's StandardMaterial3D drew it at about 0.65 of its
  paint while the wall drew 0.93 of its own), the Lounge's left wall 191,169,144 | 136,109,81, crate 190,173,143 |
  136,114,80, sofa 136,108,173 | 81,65,107, floor 156,145,134 | 108,99,91, its doors 31,56,31 | 28,49,28 and
  21,38,20 | 19,35,22 (no longer its brightest paint), pole A 113,105,97 | 143,141,136. Props' light: the sofa 0.30,
  the shelving 0.77 on average, the drums 0.89.
- Retry, cost (headless): the grid 91 ms once when Baked light comes on (on the loading screen), the props' relight
  14 ms (430 props), the doors' under 1 ms; about 5 MB kept while the bake is drawn; nothing a frame.
- Retry, checks: test_bp7_graphics +4 (the light near a point and on a side, Depot's doors dim on the Lounge's side
  only, the props and poles in the bake and the five and four prewarmed materials, no lamp over a dim room);
  test_flag_play and test_overtime_flag_play's prewarm counts now 5 and 4 (the paints added, as asked). 27 targeted
  files (bake, doors, flags, props, site, Depot, look, skyline, smoke, BP2, BP5, BP6) 339 tests, 587,100 asserts,
  then the two prewarm counts fixed (32 of 32); test_play_session and test_graphics_apply 24 of 24; the headless
  smoke match (Depot, then the range) passes with no script errors. gdlint clean, changelog check OK, wiki check OK.
- Retry pictures (Forward+, the game's renderer; labelled before | after, main 5004551 | the retry) replace the four
  Depot pairs: depot-door, depot-pole, depot-lounge, depot-lounge-edge. The joints pairs' captions now say "a small
  lift". The Woodland pairs stay Compatibility's.

#### For the owner to test

- Settings › Graphics › Occlusion culling, on Depot behind the Shoot House walls: off and on, the FPS overlay's draws
  and frame time; it should never pop a bot in late round a corner.
- Stand inside a smoke cloud on Low and on Ultra at 4K: frame time, and whether Low's bigger puffs look as thick.
- Depot's Lounge with Baked light on, walking in from the Chrono hall: does it read as a dim room, not murky? Its
  doors from inside and outside: dim on its side, lit on the hall's? Switch Baked light off and on: the doors, poles
  and props follow.
- The green doors and the flag poles on both maps: do they sit in the walls round them, or look pasted on? (On the
  simpler renderer they stand out: a known row.) Woodland's far treeline, paler toward the horizon.
- Woodland on High with the overlay: draws (Forward+'s count) against the 150 line.
