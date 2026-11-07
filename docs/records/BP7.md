# BP7 · Fix as many of the remaining known issues as possible

**Review:**

- part 1: critic Accept 8/8 · qa Pass · performance Pass
- part 2: critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-07 | part 1: 1 | Opus 5.5 | green | Retry 6/8 | doors and poles outside the bake's light, the Lounge not dim, rows 68/78, changelog |
| 2026-11-07 | part 1: 2 | Opus 5.5 | green | Accept 8/8 | – |
| 2026-11-07 | part 2: 1 | Opus 5.5 | green | Retry 5/8 | row 85's stale rule, bus layout order, full-size map cards, heartbeat on the main thread |
| 2026-11-07 | part 2: 2 | Opus 5.5 | green | Accept 7/8 | – (the ping test made to reach its line, e1194c9) |

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

### Part 2: menus, HUD, controls and reports

Branch `bp7-menus` (from origin/main 5004551), head e1194c9, 22 commits (20, then retry 1 after the critic's 5/8 and
QA's and performance's notes, then the ping test), squashed into this pull request. Rows from triage A4: 25, 26, 33, 43,
46, 59, 62, 65, 66, 67, 83, 84, 85, 89, 90, 93, 96, 102, plus the owner's picks 22 (B5) and 61 (B8), each in its own
commit.

#### What changed

- **Bottomless (66).** Switching it on tops up the magazine in hand (`Armament.top_up_in_hand`, `DevCheats`).
- **Report scrub (84).** An IPv4 address after "(driver " is scrubbed: only the real driver version
  (`ReportFacts.DRIVER_TEXT`, passed in by `for_this_machine`) is kept; IPv6 lost the Capital-then-lowercase C++ name
  exemption.
- **Run record (83, 85).** A heartbeat (every 10 s from `main.gd`, in play too; stale after 60 s) tells a copy still
  running from a crashed run whose process id another copy now holds. Retry: the beat is `RunBeat`, two small files
  beside the record written in turn on a WorkerThreadPool task (a write cut short leaves the other to read; a beat is
  skipped while the last one is still writing), so no atomic record write on the main thread every 10 s (performance's
  1–2 ms hitch); the record is no longer rewritten each beat. The graphics' safe start (`GraphicsGuard`) now keeps the
  same rule: STARTING saves when it began (`at`), and a start older than 60 s whose run has not beaten since is a
  crash even if another copy holds its id; a record from before BP7 (no `at`) is decided by its id alone (tests).
  A start whose own write failed leaves the run before it on disk, and its clean quit marks that run. The first write
  of a newer run sweeps every closed mark.
- **Tests (25, 26, 46, 67).** `MatchRunner` plays in its own SubViewport world, so a test's own level is out of its
  physics space (the Woodland door workaround is gone); the silenced-shot test reads its own voice by serial; a new
  check fails on any shipped map with a one-way nav step; the hit-area probe measures 6 more poses (25), each branch
  asserted.
- **Settings Gameplay tab (61, owner's pick).** Second tab, after Controls. Moved there: **Crouch** (hold/toggle),
  **Aim down sights** (hold/toggle), **Reload** (manual/auto) from Controls, and **What got you** from HUD. Kept: the
  Order wheel (hold/click) in Controls, beside its key; every HUD display row (sizes, colours, minimap) in HUD; key
  bindings in Controls. Saved settings are the same keys, so nothing moves on disk (test). Wiki: Settings, Controls,
  HUD and Minimap, How to Play.
- **Skip bar (22, owner's pick).** The skip cover shows a bar of how far the rest of the round has played (honest skip).
- **Exe icon (102).** `application/modify_resources` on with `installer/icon.ico`; the release workflow checks the
  built exe's icon with `tools/exe_icon.py`, and now stamps the exe's version too (`NUMBER`, the four Windows numbers from `tools/version.sh`, a sed of
  `file_version`/`product_version` in `export_presets.cfg` before the export). AppId untouched. Signing not done
  (owner: not now).
- **Retry, small.** `default_bus_layout.tres` committed in the order Godot writes it (the Panner sub-resources moved;
  buses, effects and sends unchanged; a fresh `--import` leaves it clean). `settings_screen.gd`'s header names its ten
  tabs.
- **Undo Replace (89).** Replace on the Loadout strip offers Undo for 6 s (`SavedLoadouts.undo_replace`).
- **Armory XP (90).** The earn note's numbers come from the levels table (`ArmorySummary.win_xp`).
- **PLAY focus (96).** The menus open with PLAY focused and its ring hidden (`grab_focus(true)`).
- **Spoken names (62).** `MenuCard` names itself by its visible words as the screen reader asks, unless its builder
  named it; every MenuChoice outside Settings has a name.
- **Ping declutter (43).** On-field ping markers that meet each other or Hold here's plate step apart up and down,
  eased (`HudConfig.ping_clear_gap` 4 px, `ping_clear_rate` 14/s), fixed arrays, no allocation. Retry (QA): the push
  is limited by the screen as it is made, so one marker against the top or bottom edge leaves the whole step to the
  other, and a marker with no room above the plate goes under it (test at the top edge: the plate sits under the ping's
  middle with less room above than the push needs, and the test fails with the under-the-plate line removed, checked).
- **Ambience pair (59).** Each bed is two copies half a loop apart (`copy_offset` more) on new buses AmbienceLeft and
  AmbienceRight (into Ambience), whose panners take the set's width; the copies' gains reproduce the browser's
  equal-power StereoPanner exactly in each ear (Godot's panner measured: left 1 - pan, right 1 + pan of a mono voice),
  so the level is unchanged. The row's "3 dB under" was the pair summed without the pan law: Godot's single centred
  copy was already at the browser's level, and still is.
- **Sightline search (65).** Seeded on a quarter of the stand points, and each stand bucket's recent blocking boxes
  (`WorldQuery.block_centers`, cores 5 cm in) are box-tested with `AABB.intersects_segment` before a Jolt ray. Same
  line on every field (64.583 / 161.204 / 81.789 m stretched, to the mm). On this loaded machine: Depot 90 s to 14 s,
  Woodland 30 s to 6.5 s, The Street 133 s to 17 s; Jolt rays on Depot 12.7 M to 0.4 M. `test_field_layout` 73 s.
- **Map pictures (93).** `tools/eye_pictures.gd card` renders at 1920x1080 on Forward+ and dresses the range (targets,
  markings, `fov=40`); `tools/map_pictures.gd` is gone. Depot's spot moved to 3,0 (0,0 now faces a wall). Imported
  lossy at 0.85 with mipmaps. Retry: it also writes `assets/maps/cards/<id>.jpg` at 480x270 (Lanczos; the cards draw
  at most about 272x152 at 4K), which the Match page and the menus' backdrop load; only the loading screen loads the
  full 1920x1080 picture, in its `setup()` when shown. Measured (menus' first open, `MenuScreen.new()` plus 5 frames,
  llvmpipe on a loaded machine): before 504–640 ms and +35.0 MB texture memory, three full pictures cached; after
  294–340 ms and +5.3 MB, no full picture cached.
- **Wiki numbers (33).** New markers `wiki:key <action>` and `wiki:count <dir.file.CONST>`; the squad keys, the
  minimap's step/shot reach, the late push and the restore points are generated. The flat ranges are checked against
  the simulation by `test_hop_up.gd`, which found the AEG Rifle's at 39 m, not 38 (fixed).

#### Rows fixed and deleted

22, 25, 26, 43, 46, 59, 62, 65, 66, 67, 84, 85 (the run and the safe start), 93 (rows deleted from KNOWN_ISSUES); 61
done (the planned-group row narrowed to what's left).

#### Rows added

- **Graphics, range floor:** on High the range draws its floor plain under its bake, where the unbaked render showed
  the concrete texture; its new pictures show it so. Not looked into (site dress or bake material), can wait.

#### Rows left

- **83, narrowed:** a save folder that takes no file at all still shows the last crash on each start; nothing can be
  written to say the run closed.
- **33, narrowed:** Patch Notes' features added and later replaced need CHANGELOG.md edits, which no pull request
  makes (the release checklist could). Keys outside the squad orders are still typed.
- **89, 90, 96 narrowed** to the real-display checks (4K, mouse, typing a rename, focus order).
- **102, narrowed** to signing: the owner's B10 default is not now.

#### Defaults

- Gameplay is the second tab; the Order wheel's hold/click stays in Controls beside its key; What got you moved.
- Undo lasts 6 s; the skip bar reads full in overtime; PLAY's ring stays hidden for every `focus_play`.
- Heartbeat every 10 s, stale at 60 s.
- Ping plates 4 px apart, easing at 14/s, snapping on a marker's first frame and under Reduced motion.
- Each ambience set pans one width (tested); a set whose beds differ warns and uses its first bed's.
- Map pictures lossy at 0.85. VRAM: the first pass's line ("about 8 MB each while shown") left out that the Match
  page held all four full pictures (about 35 MB measured); now the menus hold the four 480x270 copies (about 5 MB with
  the backdrop's blur) and the loading screen one full picture (about 8 MB with mipmaps) only while shown.
- Card copies 480x270 (twice the card's 1080p size, the 4K size).

#### Checks

- Retry, GUT targeted: run record, run record real process, graphics guard, ping markers, PN2, match page, BP6 menus,
  title and menus, UR1, NR1, ambience pair, SP1, card names, model pictures: 211 tests pass. gdlint on every changed
  script, `tools/changelog.sh check`, `python3 tools/wiki.py check`: pass. `godot --import` leaves the tree clean.
- GUT, targeted: ping markers, PN2, SO4 (2), ambience pair (new), ambient calls, AU1 loudness and QA, SP4, UF1,
  ambience config, SP1, FC2 (2 new), ST1, field rules, field layout, match page, BP6 menus, hop-up, and per earlier
  row its own files (settings gameplay, card names, exe icon, nav one-way steps, run record, report scrub, dev cheats,
  loadout, armory, title and menus, WG1, UI1, HO1, HUD prefs, woods, figure hit area, parts in play): all pass.
- gdlint on every changed script; `tools/changelog.sh check`; `python3 tools/wiki.py check`: pass.
- Not run: tools/check.sh (the lead's), an export (no templates here; the release dry run checks the exe icon).
- Pictures in /mnt/project-files/playtest/bp7/menus/: row61-settings-* (before/after), row22-skip-cover-*,
  row89-loadout-after-replace-*, row96-menus-open-play-focus-* and row96-play-ring crop,
  row43-pings-and-hold-close_before/after (1920x1080 and crops), row93-map-pictures_old-700x400-left_new-1920x1080-right,
  row93-range-picture_after_1920x1080. UI only, no models.

#### For the owner to test

- Settings › Gameplay with a keyboard and a pad; NVDA on the Match page and the Loadout.
- PLAY's ring as the menus open, then after a key or pad press.
- The skip bar's feel; Undo after Replace.
- Two pings close together and a ping on Hold here's sign: they part, gently.
- The ambience's width on headphones on each field (it should feel wider, no louder).
- The loading screen's picture on a 1080p and a 4K screen; the range's picture: on High the range draws its floor
  plain under its bake, where the old greybox render showed the concrete texture (worth a look in game).
- Airsoft.exe's icon in Explorer after the next CI build.
