# Art bible

The look every visual change is measured against. Read it before changing how anything looks; the owner's art pass
(`docs/ROADMAP.md` › Build order, step 28) and Depot's rework (steps 25 and 28) build to it.

## The target

The owner's six reference pictures (owner, 2026-10-18) are the target look, and his arm and hand study the target
for arms and hands (Arms and hands, below). They live in
[`docs/art/references/`](art/references/); the original PNGs are in the project's shared files (not the repository)
under `art/references/`.

| Picture | What it shows |
|---|---|
| [`depot-day-pistol.jpg`](art/references/depot-day-pistol.jpg) | Midday, pistol in two bare hands. Zone "2" and "A" barricades, a camo-netted tower with a player in it, the aircraft fuselage, an IBC tank, a traffic cone, bunting |
| [`depot-day-figures.jpg`](art/references/depot-day-figures.jpg) | Midday, pistol. Three players at range in cover, the "A1" wall, stacked containers, a walkway, the tower, a city skyline |
| [`depot-tower-wide.jpg`](art/references/depot-tower-wide.jpg) | No replica. The concrete watch tower marked "A1", a yellow-railed walkway, Jersey barriers, hard cases, floodlight masts |
| [`warehouse-interior-aeg.jpg`](art/references/warehouse-interior-aeg.jpg) | Midday under an open steel roof with shade sails. AEG in gloved hands with a hi-vis sleeve band, containers on mezzanines |
| [`depot-sunset-aeg.jpg`](art/references/depot-sunset-aeg.jpg) | Golden hour. AEG, the "B" wall, blue drums, blue and red containers, a timber watch tower with a flag, wet ground |
| [`depot-night-aeg.jpg`](art/references/depot-night-aeg.jpg) | Night. AEG, cool moonlight and warm floods, the "B" wall, a red container, hazard-striped posts, wet ground |
| [`arm-hand-anatomy.jpg`](art/references/arm-hand-anatomy.jpg) | Arm and hand study: bones, muscles, skin, veins and tendons, hand range of motion, and natural grips on everyday objects |

What still holds from before, and what the pictures confirm:

- **Stylised and readable.** Counter-Strike and Valorant, not Call of Duty or Battlefield: clean shapes, good
  materials and light, a little grit (art direction v3, `docs/DECISIONS.md` › Art direction and graphics).
- **Toy replicas, no gore.** BBs leave dust, never marks or blood.
- **A warm, sunny weekend site,** not a base: plywood, concrete and painted steel, built by a site crew.
- **Quality levels.** Low keeps its cost: the look is built for Medium, High and Custom, and Low draws figures at
  their middle detail.

The pictures set the look, the props and the light. They don't change a field's layout: Depot's routes and cover come
from its map data and the field checklist (step 24).

## The field kit

The props that make a site read as an airsoft site. Each is one of the four material families below.

- **Plywood and OSB barricades.** The main cover: tall sheet walls on timber frames with visible screws and edge
  battens, and plywood crates. A pale tan, with darker knots and OSB flecks, kept off Beta's orange hue (owner,
  2026-10-23).
- **Zone letters and arrows.** Big stencilled letters and numbers ("A", "B", "A1", "2") with an arrow on the walls that
  face a route. They name a field's zones, so they match the minimap's names and the bots' callouts; they are never
  decoration. Charcoal stencil paint with soft overspray.
- **Shipping containers.** Stacked one or two high, some open with a walkway inside. Oxide red, navy and olive
  (Colour and readability), each with the site's white chevron mark, the same on every container whatever its
  colour.
- **Hard cases.** Olive polymer cases with black latches, stacked on pallets, some under an olive tarp.
- **Drums and tanks.** Steel drums (blue and olive in the pictures) and white IBC tanks in a steel cage, on pallets.
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

- **Crowns.** Every tree a dark-green cone, from about 0.38 of its trunk (never under 2.6 m, over every head) to
  1.4 m over the trunk's top, on every preset. No collider: sight, BBs and the nav grid see trunks only.
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
- **Colours** are greens, browns and greys, every one more than 20 degrees from a team's hue or greyer than 0.3
  (tested by day and night); the leaf plum #7d3b52 sits 22 degrees from HC Beta.

## Colour and readability

- **The field** is warm concrete greys, sand, cream and off-white for the ground and walls, tan plywood for cover,
  and olive for cases and tarps.
- **Site colours** (container red, olive, mustard yellow, slate, teal) go on containers, skips, drums and paint. The
  container red is an oxide or brick red, darker and duller than Beta orange, so it never reads as a team; its exact
  value is tuned side by side with a Beta figure when Depot is dressed (step 28).
- **Team colours** (Alpha blue, Beta orange) appear **only** on players and the flag, never on props (owner,
  2026-10-18, on the references). No orange on any prop: cones and safety paint are yellow. A blue prop (a container,
  drum or tarp) is a navy or steel blue, darker and duller than Alpha's. Flags and bunting that aren't the objective
  use site colours.
- **Readability beats detail.** Silhouettes first, then value contrast, then colour. A figure is always lighter or
  darker than what is behind it. Shaded sides stay warm, never black. Golden hour and night tint the light, never a
  team colour: a Beta figure stays orange against a sunset sky, an Alpha figure stays blue under moonlight.

## Material families

Four families carry the whole game, and every asset is one of them.

- **Toy polymer.** Replicas, hard cases, cones, IBC tanks. Matte, roughness 0.5–0.6, zero metalness, a faint uniform
  sheen from the environment map. Saturated, clean colour, with a hairline lighter edge on every bevel.
- **Painted steel.** Containers, drums, masts, walkways and railings. Roughness 0.35–0.45, metalness 0.6–0.8, picks up
  the sky in the environment map. Paint chips only where a BB would hit (plate centres, rail tops), never rust.
- **Fabric and rubber.** Sandbags, netting, sails, tarps, bunting, clothing, gloves. Roughness 0.9–1.0, no specular.
  Folds and seams are drawn as geometry and as a 1–2 shade darker vertex-colour band, never as texture noise.
- **Site surfaces** (concrete, block, plywood and OSB, corrugated). Procedural canvases with a low-frequency tint
  variation so no two metres repeat. Dirt only as a foot-of-wall grime band and a soft baked occlusion in corners.

## Edges and wear

- **Edges** are what make the game look stylised instead of flat. Every box a player sees within 10 m has a 5–12 mm
  bevel or chamfer with a lighter vertex colour on the bevel face (the "CS edge highlight"). Nothing has a razor edge,
  and nothing has a decal that pretends to be geometry.
- **Wear** is restrained and friendly: scuffed polymer on grip edges, a worn rail top, weathered plywood, faded
  stencils, lane paint on the floor. No battle damage, no blood, no bullet holes (BBs leave dust, never marks).

## Light

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
  pictures set the finish and how much of the screen the replica takes.

## Figures

- **Clothing.** The figures take the references' silhouettes and gear (vests, pouches, caps, eye protection) in
  lighter, mixed clothing a weekend player would wear, never all-dark kit and masks. Every figure keeps its
  team-colour plate carrier, the strongest team cue at range (AX1; owner, 2026-10-18).
- **Detail.** This is a desktop game, so figures, arms and replicas are modelled at high quality, with LODs carrying
  less at range (owner, 2026-10-18). The budgets are in `docs/CC0_ASSETS.md` › Size limits.

## Where it lives in the code

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
  cumulus and haze. Re-render the map cards with `tools/map_pictures.gd`.
- **CC0 props** (DR2). `PropDress` (`game/play/site/prop_dress.gd`, built by SiteDress) draws the kinds
  `PropDressConfig` (`game/config/prop_dress_config.gd`, SiteLook's `props`) dresses: drums four to a pallet, barrels
  two a block, the sofa, and the tall racks lined with shelving, where `PropLayout` (`prop_layout.gd`, pure, seeded)
  lays them, one MultiMesh a model in one vertex-coloured material. Every prop stays inside its block's box; the box
  draws nothing (or, behind shelving, a dark backing half a row in: `SiteSurface.core_of`) and leaves the baked
  shadow caster. The models are Kenney's, recoloured off the teams' hues into `assets/models/props/` by
  `tools/props/build_props.py` (vertex colours, no textures).

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
the treelines; `BushView` (`game/play/bush_view.gd`) draws the bushes the simulation reads (`MapData.foliage`). Pictures: `tools/map_pictures.gd` renders `assets/maps/woodland.jpg` with it on High.

The browser game's version is in `legacy/browser/docs/ART.md`.
