# Art bible

The look every visual change is measured against, on every map: Depot, Woodland and every map after them (owner,
2026-10-31). Read it before changing how anything looks. The look is shared code, so a new map gets it by using the
shared light and palette (A map in the look, below), not by copying a map's settings.

## The target

**Sunlit Concrete: Counter-Strike-leaning naturalism** (owner, 2026-11-09, game-wide). He asked for "more realistic and
gritty with less bold vibrant colours. Think Valorant or Counterstrike and less marathon/breath of the wild" and
picked direction B of three Depot concepts (project files `art/concepts/depot-gritty-v1/`, `notes.md` beside them). It
sets the **colour, light and materials, not what may appear** (owner, 2026-10-31, still true).

- **Light:** real daylight. A warm sun with real shadow shapes, surfaces darkening smoothly as they turn from it (no
  cel bands), a dark neutral shade under the ambient and bounce light, and almost no rim.
- **Colour:** natural and muted. Colour comes from real materials (plywood, concrete, painted steel, tarp, foliage)
  and a few weathered paint accents. Every paint is drawn at 60 % of its colour (`LookConfig.paint_saturation`).
- **Materials:** real grain and light wear. Plywood and concrete grain, scuffed wall feet, floor stains; no candy
  gloss, and the lit bevel is only a hint.
- **Readability beats realism.** The team colours stay the strongest blue and orange on screen, players stay lighter
  or darker than what is behind them, and safety yellow still reads.
- **Not:** grimdark, gory, military or dark. It is a sunny weekend at an airsoft site, just a real one.
- **Still true:** toy replicas and no gore (BBs leave dust, never marks or blood); airsoft, not military.

The Dev 2 look (Valorant's forms with Breath of the Wild's light, clean vibrant paint) is history: `docs/DECISIONS.md`.
Built in steps: SL1 the light, grade and paint; SL2 material wear in the shared shaders; SL3 Depot's roof and hall
frames repainted (galvanised grey steel, a pale grey liner, red sprinkler mains) and the map pictures rendered again;
SL4 the menus, HUD and replica paint toned to match (the figures' kit already was).

## The field kit

The kind of props that make a site read as an airsoft site: a list of ideas, not a limit (owner, 2026-10-31). Each is
drawn in the look (Surfaces, Colour).

- **Plywood and OSB barricades.** The main cover: tall sheet walls on timber frames with visible screws and edge
  battens, and plywood crates. A pale tan, with darker knots and OSB flecks, kept off Beta's orange hue (owner,
  2026-10-23).
- **Zone letters and arrows.** Big stencilled letters and numbers ("A", "B", "A1", "2") with an arrow on the walls that
  face a route. They name a field's zones, so they match the minimap's names and the bots' callouts; they are never
  decoration. Ink stencil paint, crisp.
- **Shipping containers.** Stacked one or two high, some open with a walkway inside, in the six site colours (Colour),
  each with the site's white chevron mark, the same on every container whatever its colour.
- **Hard cases.** Olive polymer cases with black latches, stacked on pallets, some under an olive tarp.
- **Drums and tanks.** Steel drums (crimson and teal on Depot) and cream IBC tanks in a steel cage, on pallets.
- **Sandbags and Jersey barriers.** Sandbags along wall tops and tower parapets; concrete barriers with a yellow
  band.
- **Fabric overhead.** Camo netting over towers and nests, cream shade sails, tarps, bunting along perimeter walls.
- **Structures.** Floodlight masts (four or six heads on a steel pole), a concrete watch tower and a timber one,
  yellow-railed steel walkways and stairs, an open steel-framed warehouse roof.
- **Landmarks.** The aircraft fuselage, the watch towers and the city skyline are the kind of landmark that lets a
  player say where they are from anywhere on the field. They are scenery out of reach, not part of a field's layout
  (owner, 2026-10-18). Depot's rework kept them out (DP1, 2026-10-24): a concrete watch tower beyond the north wall,
  the fuselage beyond the east wall and four floodlight masts join its skyline (DP3: greybox in `SkylineConfig`'s
  site colours and greys, the masts' lights waiting for step 26).
- **Ground and safety paint.** A concrete slab with expansion joints, yellow floor lines and bay markings,
  yellow-black hazard stripes on posts and edges, yellow traffic cones, coiled hose, a little grass in the joints.

## The wood

Woodland's look in placeholders (WL4, `WoodsView` from `WoodsConfig`), until the owner's models (step 32):

- **Crowns.** Every tree a cone in one of the palette's four bright greens (canopy, green, pine, fern), from about
  0.38 of its trunk (never under 2.6 m, over every head) to 1.4 m over the trunk's top, on every preset. No collider:
  sight, BBs and the nav grid see trunks only.
- **Beyond the fence.** The skyline's treelines (cones along their points in bands, faded to the horizon) and hills,
  and a forest of 2,000 cones in the 12 to 118 m ring round the field, standing on the hills, a share of it from
  Medium, all on Ultra.
- **On the ground** (from Medium). Grass tufts on the grass squares, never over the map's 0.34 m, shrinking away by
  30 to 60 m; puddles and mud as a darker, glossier skin on the slope (water glossy, mud duller, both off the team
  hues); leaf drifts by the trunks, fallen branches, twigs and short logs by the feet of blocks (out of lanes and
  spawns), moss on the top and north side of half the logs.
- **Bushes** (WL5, `BushView`). Each of the map's bushes a low sphere stretched to its size, a seeded pick of four
  mid greens up to 10 % lighter or darker, all in one draw on every preset; a BB stopped in one throws a pale green
  puff and 4 to 6 yellow-green leaves that fall to its foot, one through an edge a leaf or two. The minimap marks each
  as a muted green disc.
- **The night air.** Fireflies by the logs and water, and pale motes round the eye, self-lit, the Wind dust row's
  share; still and steady under Reduced motion.
- **Colours** are the look's palette's (WA1): the crowns canopy, green, pine and fern; the far forest forest, spruce
  and pine; the bushes fern, green, olive and canopy; bark, timber and umber wood with heartwood ends; the meadow,
  litter, earth and pebble underfoot; pond water and mud; leaf drifts in yellow, olive, umber, sand, crimson, moss and
  timber. Every one is more than 20 degrees from a team's hue or greyer than 0.3: the palette in
  `tests/unit/test_look.gd`, the woods' own colours in `test_woods_view.gd`.
- **In the shared light** (WA1): the greybox and the ground (clean, no metre grid), the crowns, the forest, the floor
  pieces, the bushes, the CC0 props and (BP7) the skyline and the flag poles on `look_vertex.gdshader`
  (`LookMaterials.paint` for a mesh in one colour), the doors on `door_leaf.gdshader`, the puddles on
  `look_clear.gdshader`. On a baked map the doors, poles and props take the bake's light near them
  (`BakedLightNear`), a door's each face its own side's. The grass tufts keep their
  own light (two-sided blades would take the rim on every back face).

## Colour

The look's palette is `LookConfig.palette` (`game/config/look_config.gd`, in `play_tuning.tres`), sRGB:

| Name | Hex | Use |
|---|---|---|
| crimson | `#c23874` | site colour: containers, barrels, exit doors, sprinkler mains |
| violet | `#7658aa` | site colour: containers, wall bands, the sofa |
| yellow | `#e4ca46` | site colour, and all safety paint (lines, hazard stripes, pillars, cones) |
| teal | `#2a9c90` | site colour: containers, drums, inner wall bands |
| green | `#58904e` | site colour: containers, netting, cases |
| cream | `#f4ecda` | site colour: containers, walls, sails, film |
| concrete | `#d2cec8` | precast, docks, light concrete |
| floor | `#b9b4ae` | an outdoor slab |
| plywood | `#dccaa8` | plywood barricades |
| timber | `#a0947c` | timber, sandbags |
| crate | `#c2b698` | crates, cartons |
| steel | `#6c6a7a` | steel, racking, ramps |
| ink | `#3a2f5a` | stencils, hazard stripes' dark, a shelf's backing |
| slab | `#7c7670` | Depot's hall floor, darker than `floor` so the cover stands off it |
| sand, pebble, stone | `#b9ae98`, `#a09a92`, `#8c8478` | open ground, gravel, gabion stone |
| plaster | `#ece2cf` | outer walls |
| grey | `#8c8a96` | ramps, pallets, IBC frames, the barrels' lids, Depot's trusses and hall frames (galvanised) |
| ceiling | `#524a72` | the Dev 2 roof's underside (Depot's liner is concrete since SL3) |
| umber, moss | `#61594f`, `#b3b891` | the gaps between slats, the sofa's feet; grass on open ground |
| bark, heartwood | `#7b6f62`, `#e4dccd` | Woodland's trunks and their cut ends (WA1) |
| canopy, fern, olive | `#5c9a50`, `#79a650`, `#8c9a48` | Woodland's crowns and bushes; olive the logs' moss |
| pine, spruce, forest | `#3d7a4a`, `#2f6e55`, `#2b5c48` | spruces, thicket cores and the far forest |
| meadow, litter, earth | `#8aa860`, `#7c7a58`, `#8a8070` | a light meadow, Woodland's leaf litter and bare earth |
| grass | `#5f8a3a` | sloping ground's grass and the ground beyond a field's walls (SL1) |
| rubber | `#3d3b45` | tyres and wheels |
| pond, mud, mud_wet | `#4a6f6c`, `#554e44`, `#403b34` | puddles and mud (wet mud also the wet skin) |

- **Paint is weathered.** The light draws every paint at `paint_saturation` (0.6) of its colour, toward its own
  grey, so the hexes above are the paint as bought and the screen shows it weathered (SL1). Sloping ground's grass is
  `grass`, a darker natural green (`#5f8a3a`), so it stays green once muted.
- **Spread the six evenly.** No site colour covers much more of a map than another; big repeated props (racking,
  walls) take a neutral (steel, plywood, cream) so they never make one colour dominate.
- **Team colours** (Alpha blue, Beta orange) appear **only** on players and the flag, never on props. No palette colour
  or prop paint is within 20° of a team's hue unless it is dull (greyer than 0.3): tested for the palette
  (`tests/unit/test_look.gd`), Depot's paint (`test_site_dress.gd`) and the props (`test_props.gd`). Safety paint is
  yellow, never orange.
- **Readability beats detail.** Silhouettes first, then value, then colour. A figure is always lighter or darker than
  what is behind it. Shade is dark but never black: the ambient and bounce light fill it. Night and golden hour tint
  the light, never a team colour.

## Surfaces

Every surface is paint or material in the shared light, drawn weathered (The target). A material gives a colour (or a vertex colour), a roughness and a
metalness; the light does the rest.

- **Paint, polymer and fabric** are matte (roughness 0.8 to 1.0, metalness 0). **Painted steel** (containers,
  drums, pillars) is semi-gloss (roughness 0.4 to 0.5) with at most 0.2 metalness, so it keeps its colour under the
  cel light and gets the look's small soft highlight. A hall floor is a little smooth (0.6), so the probes give it a
  faint reflection of the room.
- **The vertical gradient.** Every side is up to 30 % darker at its foot, full paint 2.6 m up
  (`SiteLook.gradient`), the way the approved picture grounds its walls and cover.
- **The lit edge.** Every box a player sees has a faint lighter bevel (8 % lighter, 4 cm), a hint of the "CS edge
  highlight".
- **Grit is real (SL1).** `SiteLook.grit` (0.6) scales the stains, chips, rust feet, grime bands and the plywood's
  photo grain on the map's own surfaces; the floor's slab set, Depot's floated concrete, draws at full grain
  (`SiteLook.slab_grain` 1).
- **The models wear too (SL2).** Every map model drawn in vertex colours (Depot's walls, crates, containers and
  racking, Woodland's kit and trunks, the CC0 props) is worn in world space by `look_vertex.gdshader`: dark-earth grime
  climbs up to 0.9 m from its foot, ragged; thin streaks run down its sides; broad faint stains; pale dust settles on
  its tops. A material's `wear` (`PropDressConfig.wear` 1, `model_wear`: the racking 0.35, tree crowns and the earth bank 0) times the
  look's (`LookConfig.wear`, `grime`, `dust`). The greybox, bushes, woods, skyline and flags draw clean. Edge scuffs are
  the models' own paint (SL3).
- **Replicas are lightly used (RW1).** The AEG Rifle and the GBB Pistol in your hands, in the menus' pictures and the
  Customise turntable carry a baked mask (`tools/blender/replicas/wear.py`): faint scratches (most along the length,
  some in small parallel clusters, the magazine and slide handled most), rubbed outer edges and a few rubbed patches,
  and dirt in the recesses. `replica_wear.gdshader` scuffs whichever paint is on towards a worn mid grey in
  square-root light (black greys up, white dirties down, a bold colour dulls), polishes the rubs and mattes the
  scratches and dirt; a metal part wears to bare metal. Times `LookConfig.wear`. Bots' copies, the Cyber Pistol and the
  Sniper Rifle draw clean.
- **Marks that stay:** zone stencils in ink, joints, seams, screws, sheet panels, bay lines and hazard stripes in
  yellow and ink, the white chevron on containers.

## Light

**The shared light** (`game/play/look/look_light.gdshaderinc`, values in `LookConfig`'s Light group) is one `light()`
for every material in the look: a natural falloff with no cel band (the light centred on a 0.42 cosine and spread
0.55 either side, so a surface darkens smoothly as it turns from the sun), the sun's far side adding only a dark warm
grey `#292826` so it falls to the ambient and bounce light, a faint warm rim (`#fff2d9`, 3 %) on an edge seen against
the light, a small soft highlight on smooth paint, and every paint at `paint_saturation` (0.6) of its colour
(`look_paint`). Its values are global
shader uniforms (`project.godot` [shader_globals], pushed by `LookConfig.push_globals` at the start of a match), so
tuning it once changes every map; the colours are sent linear, since a colour global reaches the shader unconverted. Ambient light, bounce light and reflections are the engine's and come on top.

**The grade** (LookConfig's Picture group) is on every preset: AgX with its contrast at 1.35, then 0.95 saturation and
1.12 contrast, a natural, slightly contrasty picture with the team colours still the loudest. **The day** (LightingConfig)
has a warm sun (`1.0, 0.92, 0.8`, energy 2.0), less flat fill (ambient 0.55) and exposure 0.9 (SL1).

**The graphics scale the light, never the look** (owner, 2026-10-31). Low draws the same shared light, palette and
grade with none of the dearer effects; each preset up adds real light on top (`data/graphics.md`):

| Effect | Low | Medium | High | Ultra |
|---|---|---|---|---|
| Sun shadows | off (a contact disc) | 2048 | 4096 | 8192, contact-hardening (the sun 0.6° wide) |
| Ambient occlusion | off | off | half | full |
| Bounce light | off | off | screen (SSIL) | scene (SDFGI with occlusion, plus SSIL at full size) |
| Reflections | sky | probes | probes | probes and screen-space |
| Glow | off | on | on | on |
| Volumetric haze | off | off | off | on, lit by the sun and the bounce light |

The reflection probes (`AreaProbes`) are one over the field and one in each named area of 60 m² or more (24 at most),
box-projected from eye height and captured once at the start; under a roof they are interiors. Volumetric haze is
faint (density 0.006) so it gives light depth without hiding a player.

Three lighting presets, each shared by every map that uses it and each as readable as the others.

- **Day.** A single warm sun high in a blue sky with soft cumulus, a cool sky fill and a warm ground bounce. Shadows
  are crisp but short, with dappled leaf shadow where trees overhang.
- **Golden hour.** A low sun behind the field, a pink-to-orange sky, long warm light on plywood and cool shade. The
  sky glows; figures and BBs keep their contrast.
- **Night.** Cool blue moonlight and sky, with warm white floodlight pools from the masts and small warm lamps under
  walkways. Dark between pools, never black: every route stays lit enough to read a figure.

**Night as built (WL3).** `game/config/night_lighting.tres`, from the browser's preset as first guesses: a cool moon
18° up (turned toward a map's `moonOver`: Woodland's hangs over the Knoll), a navy sky with stars and the moon's disc
and halo on every quality preset (its own sky shader, `FieldLighting.NIGHT_SKY`), a grey-blue horizon (a bluer one
reads as Alpha where the skyline fades into it), haze from 20 m, a cool fill and AgX. A map's overrides scale it
(Woodland: moon 1.35, fill 1.4, exposure 1.55 of the browser's 1.3). Fires (255, 228, 160) and lanterns (255, 232,
180) are yellow-white pools on the ground with a glow where they hang; the nearest two (Medium) or four (High) are real
lights. Depot's mast lamps glow (255, 238, 200) with no light of their own. Under night a figure's team paint never
glows. The swatch test (`tests/unit/test_night_light.gd`) holds earth, wood, skin and team paint readable against the
night ground; the record (`docs/records/WL3.md`) gives its figures.

**Wet ground.** Puddles sit in low spots and by joints on dry concrete in all three presets, with sharp reflections of
lights and sky. A puddle is a roughness change on the slab, never a separate surface, and never hides a BB. Its
reflections come from the sky's environment map and reflection probes, not per-puddle screen-space or planar
reflections; Low gets a darker, glossier patch with no screen-space reflection. A fully wet slab belongs to a rain
weather, not to every match.

The environment map that gives polymer and steel their sheen is **the game's own sky**, so the look stays consistent at
every quality level, and a night or golden-hour sky changes everything at once.

## A map in the look

Every map takes the look this way (Depot did, AD1; Woodland, WA1):

1. **Draw every surface in the shared light.** A shader includes `look_light.gdshaderinc`; a vertex-coloured model
   uses `LookMaterials.vertex_colour`. A `StandardMaterial3D` doesn't get the look's shade or rim.
2. **Paint from the palette.** Every colour a map paints is a palette entry: a new colour goes into the palette
   first, then into the map's paint. Spread the six site colours evenly and put big repeated props on a neutral. A
   model is painted from it by name (`tools/blender/maps/prop.py` writes vertex colours). `tests/unit/test_look.gd` holds
   Depot's and Woodland's paint and props to the palette; a new map adds its own to that test.
3. **Keep surfaces clean.** No noise, stains or photo grain; the gradient and lit edges carry the shape.
4. **Light it with a preset.** The map's `lighting` overrides tune the sun, fill and exposure; a roofed map's sun hangs
   nearly overhead (Depot). Check it on Low and on Ultra: Low must read as well, Ultra only adds light.
5. **Name its areas.** The reflection probes go in its named areas, so a map with them gets its probes for free.
6. **Picture it.** `tools/eye_pictures.gd` renders it at eye height on any preset (`preset=ultra`), with the Vulkan
   renderer under xvfb (lavapipe in a cloud session: slow, but every effect draws).

## Arms and hands

The owner's arm and hand study, [`arm-hand-anatomy.jpg`](art/references/arm-hand-anatomy.jpg) (owner, 2026-10-18), is
the target for every arm and hand in the game: your first-person arms and the figures' (players and bots). They are
realistic and drawn in the game's own style (owner, 2026-10-18): true anatomy and full detail, with the same clean
shapes, colour and material treatment as everything else. Matching the style never means a lower-quality model. It
guides his Blender art pass (step 28) and the shared rig standard that first-person
arms, figures and replicas use (steps 23 and 28).

- **Anatomy.** Correct proportions from shoulder to fingertip: humerus, radius and ulna, a wrist that turns from the
  forearm, not the hand, and three finger joints plus a thumb that opposes from the palm. Muscle masses (deltoid,
  biceps and triceps, the forearm flexors and extensors, the thenar pad at the thumb) shape the silhouette.
- **Surface.** Skin with knuckle creases, palm lines, nails and forearm veins; extensor tendons show on the back of the
  hand when it grips. The detail lives in normal and roughness maps, not in extra triangles.
- **Rig.** Every finger gets three bones and the thumb its own chain from the wrist, so poses can bend each joint the
  way the study's range of motion shows (open, fist, spread, pinch, point).
- **Grips.** The study's natural grips are the reference for handling poses: the power grip for a pistol grip and the
  AEG's grip, the cylindrical or support grip for a foregrip or handguard, the pinch grip for a magazine, a
  charging handle or the hop-up dial, the precision grip for a selector or a magazine release. Fingers wrap and touch
  the replica; nothing floats or clips.

## First person

- **Arms.** Your arms are always on screen with the replica; your body never is. They follow Arms and hands above
  and match your figure and the skin you have equipped: bare arms, or sleeves and gloves, whichever that figure or
  skin wears (owner, 2026-10-18). A team-colour armband shows your team either way, the way sites mark teams. Gloves
  fit a correctly built hand, so knuckles, tendons and finger joints still read through them.
- **Replicas.** Two-tone toy polymer: the AEG in tan with black furniture and yellow accents on the controls (magazine
  release, selector), the pistol in black with green fibre-optic sights. Shapes are the owner's own designs; the
  pictures set the finish and how much of the screen the replica takes. In Sunlit Concrete (SL4) a paint is matte
  polymer with a soft sheen (roughness 0.64, the metal parts 0.48) and is drawn at the look's paint saturation
  (`ReplicaPaint.drawn`, as `look_paint()` draws the maps), so a bold scheme still reads two-tone but sits in the muted
  world; the Loadout's swatches show the paint as drawn. The Cyber Pistol keeps its own lit lines.

## Figures

- **Clothing.** The figures take the references' silhouettes and gear (vests, pouches, caps, eye protection) in
  lighter, mixed clothing a weekend player would wear, never all-dark kit and masks. Every figure keeps its
  team-colour plate carrier, the strongest team cue at range (AX1; owner, 2026-10-18). Their kit is already
  Sunlit Concrete's realistic multicam, khaki and olive (about a quarter saturation, SL4), so SL4 left it as it is.
- **Detail.** This is a desktop game, so figures, arms and replicas are modelled at high quality, with LODs carrying
  less at range (owner, 2026-10-18). The budgets are in `docs/CC0_ASSETS.md` › Size limits.

## Menus and HUD

- **Sunlit Concrete (SL4):** `GameTheme`'s palette is charcoal panels (`BG` `#131311`), off-white words (`TEXT`
  `#f2eee6`) and one bone accent (`ACCENT` `#d8ccb2`, charcoal ink on it) for the main button and the selection, so the
  team colours are the only strong colours on screen. Signal yellow (`WARN`), better and worse (`GOOD`, `BAD`) are a
  little quieter. Every dark ink derives from the palette: `BG` (markers' ink, the map's backdrop), `DEEP` `#0c0c0b`
  (the rail, the shades over a match or page) and `PLATE` `#1f1e1b` (notices, report boxes, the Armory's picked card).

## Where it lives in the code

The look (AD1): `LookConfig` (`game/config/look_config.gd`, PlayTuning's `look`) holds the light's values, the grade,
the effects' strengths and the palette; `game/play/look/` holds the shared light (`look_light.gdshaderinc`), the
vertex-colour shader and `LookMaterials`, `AreaProbes`, and Dev › Retro filter's corner snap and texture swim
(`retro_vertex.gdshaderinc`, RF1); `FieldLighting.set_effects` and `GraphicsApply.apply_field`
switch the effects by the Graphics rows. The site surface, the roof, the CC0 props and the sandbags are drawn in it.

Depot's temporary site dress (DD1, until the owner's models; Depot and the range, by day):

- **Data.** A map opts in with `dressing.site` (`SiteDressing`, `game/map/site_dressing.gd`): its zone stencils (an
  area's name on a wall face), shade sails and the slab's bay lines (up to 16 rectangles, painted by the shader).
  `SiteLook` (`game/config/site_look.gd`, in `play_tuning.tres`) holds
  every finish (canvas, paint, accent, band, roughness), the container paints and split, the photo sets, the sky and
  haze, and the details' sizes.
- **Blocks.** `MapLevel` draws the greybox's faces, baked or not, in `SiteSurface`'s one material
  (`game/play/site/site_surface.gdshader`): each vertex carries its box and finish, its colour the bake's light alone.
  Canvases are procedural in world space with two tiling noise textures; the slab and plywood mix in Poly Haven
  photos. Low drops the photo relief, corrugation and tread.
- **Details.** `SiteDress` (`game/play/site/site_dress.gd`): container frames, crate battens, caps and coping, the
  skip's rim, the watch tower's net and flag, the sails, as one mesh in the same material; the sandbags as one
  MultiMesh within 60 m; the stencils as Label3D, charcoal, or light on a dark wall. `dress_sky` gives the day its
  cumulus and haze. Re-render the field pictures at eye height with `tools/eye_pictures.gd` (spots in `docs/records/UR2.md`).
- **CC0 props** (DR2). `PropDress` (`game/play/site/prop_dress.gd`, built by SiteDress) draws the kinds
  `PropDressConfig` (`game/config/prop_dress_config.gd`, SiteLook's `props`) dresses: drums nine stacks of two to a
  pallet, barrels two a block, the sofa, the tall racks lined with pallet racking, and any block that names its own
  prop (`dress`: Depot's desks and lockers, the Range's kit rack), where `PropLayout` (`prop_layout.gd`, pure, seeded)
  lays them, one MultiMesh a model in one vertex-coloured material. Every prop stays inside its block's box; the box
  draws nothing (or, behind shelving, a dark backing half a row in: `SiteSurface.core_of`) and leaves the baked
  shadow caster. Every map's models are our own, built in Blender by `tools/blender/maps/` (RK1, WT1, WG2 to WG4; the
  last Kenney props went in Dev 3), all in `assets/models/props/` (vertex colours, no textures).

The figures (step 23, FI1-FI7; every bot on every preset, DECISIONS BD1):

- **Models.** `assets/models/characters/human.glb` and `robot.glb` with their sidecars (`human.json`, `robot.json`:
  clips, parts, grips, the magazine in hand), built by `tools/blender/bot-figure/`. `FigureModels`
  (`game/play/figures/figure_models.gd`) loads both once a session, as PlaySession builds its views behind the loading
  screen, and makes each team's paint once a kind, team and glow.
- **One figure.** `FigureBody` (`figure_body.gd`): one head by id (the human's four, RM9), the levels of detail by
  distance on the Mesh detail's lines, one shadow twin from LOD2, the Team* paint, the fade through
  `GeometryInstance3D.transparency`. `FigureView` (`game/play/figure_view.gd`) places it, holds its replicas (the
  models' figure versions, ReplicaPaint and ReplicaParts) and its "HIT!" sign.
- **Motion.** `FigurePose` reads the Character between ticks; `FigureGraph` is the kind's AnimationTree graph (gait,
  crouch, jump, vault, the hit call, the walk-off, the upper body's aim, holster, switch, reload and fire);
  `FigureBend` lowers the crouch, leans, flinches and pitches the aim after it, and at a wall `FigureReady` brings the
  replica to a high ready, muzzle up (FB5); `FigureHands` puts the replicas and a reload's magazines on the bones;
  `ThrownMagazines` throws the old ones.
- **Shaders.** `ShaderPrewarm` draws every figure material, solid and fading, as specks in the first frames
  of a match (`FigureModels.materials`).
- **The hit area.** Hitbox's volume is the same for both kinds and is measured against the drawn figure by
  `tests/support/hit_area_probe.gd` (FI7, `docs/records/FI7.md`); step 28 fits it to the final figures (HV1).
- **The bench.** `tools/figure_bench.gd`: 11 figures on Depot, the animation and skeleton time per figure, and the
  frame time with `--perf` (dev only, never exported).

The wood (WL4): `WoodsShapes` (`game/play/woods_shapes.gd`) places every part from `MapData`'s `dressing` with
seeded order and colours, as plain data; `WoodsView` draws it (instanced cones, tuft tiles, one puddle mesh of two
surfaces, one floor mesh, one night-air draw) and follows the Mesh detail and Wind dust rows; `SkylineShapes` builds
the treelines; `BushView` (`game/play/bush_view.gd`) draws the bushes the simulation reads (`MapData.foliage`). Pictures: `tools/eye_pictures.gd` renders Woodland's at eye height with it on High (UR2).

The browser game's version is in `legacy/browser/docs/ART.md`.
