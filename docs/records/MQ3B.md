# MQ3B · The figures' headwear, arm bands and boots drawn as what they are made of

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Fable 5.2 (model quality thread) | pending | pending | – |

## What changed

Owner, 2026-11-12: "Also do this for figure and cloth models. This means the human face, helmets, goggles, plate
carriers, etc. Basically every single 3D model in the game." MQ3 did the gear. This is the rest of the human figure:
its four heads and what they wear, and the two parts of its body the bake had left plain, the team arm bands and the
boots. It is a pass over surfaces. The figure has 732 triangles to spare of its 60,000 and its eight materials, so no
mesh changed; what changed is what the maps hold and which parts draw from them.

**The heads** (one 2048 atlas, `tools/blender/figures/head_textures.py`). Every tile was drawn new and clean; each
is now drawn used, from where a pixel lies on the part in metres:

| Part | Before | Now |
|---|---|---|
| High-cut helmet's shell | even grey paint | a fine peel in the paint, the crown rubbed, some seventy scratches, dust low down and round the vents' rims |
| Rails and shroud | flat dark polymer | a moulded grain, corners and slot lips worn paler |
| Full-cut helmet's cover | even coyote ripstop | faded on top and in broad patches, dust beside its seams and along the hem, pale scuffs |
| Cap and boonie | even ripstop with stitching | unevenly faded cloth, paler on top, a sweat mark with its salt line above the band, the brims' edges worn pale |
| Boonie's band | a flat team colour | woven ribs and weft with relief |
| Loop patches (team and plain) | a faint speckle | a deeper pile, matted in patches, a little lint |
| Balaclava and shemagh | even knit and weave | uneven dye, pilling |
| Mesh mask | evenly painted wire | paint chipped to bare steel at crossings here and there and in small round patches where BBs struck |
| Ear cups (both kinds) | one flat colour | moulded polymer on tiles of their own: a pebble grain, the joint to the back plate, a panel line, the shoulder rubbed, a few scratches |
| Ear cushions | one flat colour | soft leatherette with fine creases, a welded seam, a duller outer edge |
| Goggles' frame | one flat colour | matte rubber with a grain, its lip rubbed lighter, dust toward the face |
| Mesh mask's binding | one flat olive | twill tape folded over the mesh's edge with a row of stitches, its folds rubbed paler |
| Headset's band | one flat grey | padded leatherette quilted every 30 mm, a stitch row inside each edge, the pads' crowns rubbed |

The last five were the largest parts still drawn from flat swatches. They draw from six new tiles (`cup_defender`,
`cup_headset`, `cushion`, `goggle_frame`, `binding`, `headband`: the two strips are short tiles laid back and forth
along the part, so a 12 cm tile covers the whole binding with no seam). What is left on swatches is small and hard
(buckles, screws, the microphone, the rims' rubber trim: at most 15 % of a head's area that shows) and the inside of a
helmet's shell, which nothing sees.

**The body** (`tools/blender/figures/body_surfaces.py`, new: numpy and Pillow, no Blender). A pass over the body's
three baked maps inside `human.glb`. It draws every body triangle into the atlas to learn where each pixel is in
space, tells the arm bands by their material and the boots' parts by height and the roughness the bake gave them,
and paints only those pixels (270,156 of the 2048 square):

| Part | Before | Now |
|---|---|---|
| Team arm bands | one flat team colour, lit by the sleeve's normals | elastic webbing: ten ribs round the arm, a folded hem with a stitch row at each edge, the sewn overlap at the back of the arm, puckers; the ribs' valleys and handled patches a shade darker |
| Boots' suede uppers | smooth, one roughness | the nap lying this way and that, brushed in streaks, three creases across the vamp where the foot bends, dark rubbed patches low at the toe |
| Toe caps and heel counters | smooth | scuffed paler in soft patches, a few scratches fore and aft |
| Soles | a plain slab | lugs cut into the tread's side all round, a paler worn bottom edge, dried dust |

The arm band now draws the body's colour map (white under the team colour the game paints), so its ribs, grime and
the body's baked occlusion show on it; before it had no colour map. The map is neutral grey there (red, green and
blue equal), so the hue is Alpha's blue and Beta's orange as before, and the ribs' crests in the open are the full
team colour. Its mean is 0.88 of white in the map (0.77 in linear light): on average the band is about a fifth
darker than the flat colour it was, which is the ribs' valleys, the grime and the shade the bake put under the arm.

- **References:** the owner's photos these parts were modelled from (BL10, BL11), `ref_images.zip` ›
  `clothes/highcut_helmet` (eleven, among them `Helmet-MICH-High-Cut-Tactical(4)`), `clothes/baseball_cap` (five,
  among them `Screenshot 2026-11-04 122905`), `clothes/boonie_hat` (seven, among them `boonie_olive_3`),
  `clothes/goggles` (six), `clothes/mesh_face_mask` (six, among them `6031-tn_1___43521`) and `player/figure`
  (seventeen, among them `EK7A5361` and `bbqhqxirl3db1`). What the paint takes from them: the mask's edge bound in
  woven tape and sewn through; the cap's and the boonie's ripstop with rows of stitching round the brim; moulded
  rails and cups against a painted shell; suede boots with a rubber toe cap and a lugged sole; an elastic band round
  the upper arm. The wear (fade, sweat, dust, scuffs, chips) is what a season's use leaves on such kit and is in none
  of the product photos. No print, label or maker's mark is taken from any of them.
- **The face is unchanged** (FA1's four looks, in their cells of the atlas, byte for byte from the same painter).
  It is small on screen behind goggles or glasses; the critic's and the owner's notes on it are in FA1.
- **No mesh changed**: the heads' triangles (the largest 8,992 / 3,192 / 896), the body's (33,458), every UV island
  of the body and every weight are as they were. On the heads only the UVs of the five moved parts changed; their
  new seams split 391 vertices over the nine head meshes (105,576 in the file, 105,185 before), with no triangle
  added. `tests/unit/test_figure_body.gd`'s counts hold.
- **No game code changed.** The band's material keeps its name; `FigureModels.team_material` copies it and sets its
  colour as before, and the copy keeps the map (a test holds this).
- **Lower detail levels** draw the same maps, so the body's far levels show the band's and boots' paint as far as a
  mip level carries it; at range it averages to the colours they had.
- **The build.** `python3 -I tools/blender/figures/headwear.py` (heads, as before), then
  `python3 -I tools/blender/figures/body_surfaces.py` (8 s). The second runs once on a freshly built body: it tells a
  painted file by the arm band's colour map, which only it adds, and stops. Both builds give the same file byte for
  byte on a second run from main's file.
- **Files:** `human.glb` 14.8 MB (was 12.5). The heads' three maps are now stored lossless (1.09, 1.83 and 0.08 MB;
  0.20, 0.69 and 0.01 before): lossy colour smeared one tile's edge into the next, which showed as a line where a
  tile that goes round a part meets itself. The body's maps go back as lossy WebP at quality 95 (0.65, 0.93 and
  0.14 MB; 0.57, 0.86 and 0.09): the cloth round the painted parts differs from before by 0.5 of 255 in colour and
  1.7 in the normal map on average, which no picture shows. What the game loads is the imported textures, whose
  sizes and formats are unchanged (the same six `.ctex` sizes), so texture memory and the install size are as they
  were.
- **Tests** (`tests/unit/test_head_body_surfaces.gd`, seven): the cups, cushions, goggle frames, binding and band
  draw from their tiles on the heads that wear them; each new tile is painted (its colours spread) and carries
  relief; little of a head that shows is left on flat swatches; the arm band shares the body's colour map, is white
  under the team paint and the game's team material keeps the map; the band is near white, neutral, ribbed in colour
  and in the normal map; the boots carry relief and more than one roughness; the figure keeps its eight materials.
- **Docs:** `docs/ASSETS.md`, `docs/ART.md` › Figures, `assets/models/characters/README.md`,
  `tools/blender/figures/README.md`, `docs/PLAYTEST.md` › Headwear, arm bands and boots up close (MQ3B).
- **Pictures:** `art/model-quality/mq3b/` in the project files, the bot figure in the studio, before and after:
  the high-cut helmet (`mq3b-1`), the full-cut helmet and the mesh mask (`mq3b-2`), the cap and the boonie
  (`mq3b-3`), from the front (`mq3b-4`), the arm band (`mq3b-5`), the boots (`mq3b-6`), the whole figure (`mq3b-7`).

## Decisions

- **Surfaces, not meshes** (default): 732 triangles are free in the figure's 60,000 and the heads are at 99.9 % of
  theirs, so more modelled detail needs the owner to raise a budget. The maps had room for more.
- **The body is painted over its bake, not rebaked** (default): a rebuild of the body does not give the committed
  mesh back (other vertex order, another UV layout, one vertex fewer at the far level), and with it would go the
  weights the owner approved on the shoulders (BP6) and every map made against that layout. A pass over the baked
  maps touches only the pixels of the parts it paints. After any later rebuild of the body, run it again.
- **The arm band takes the body's colour map** (default): without one it could only be lit, never shaded or
  dirtied. No ninth material and no new map: it is the map the cloth beside it already draws.
- **The band's mean is 0.88 of white, no brighter** (default): white is the map's ceiling, so a brighter mean
  flattens the ribs (at 0.88, 6 % of the band's pixels are at white; at 0.92, 21 %; at 0.94, 29 %). The team
  colours stay full at the crests; if the owner finds the bands dim in play, `BAND_MEAN` lifts them at the ribs'
  cost.
- **Patterns no finer than the map can hold** (MQ3's rule): the body's atlas is 1.3 mm a pixel there, so the band's
  ribs are 4.3 mm apart (a real band's are nearer 2) and its stitches are a dotted row.
- **The heads' maps are lossless** (default): the line down the back of the high cut came from three things, fixed
  in turn: a tile's pattern not meeting itself where its ends meet (each pixel's place is now taken as the UVs
  reach it), lossy colour bleeding in from the next tile, and the slope across a tile's edge taken from the next
  tile's heights (each tile's slopes now come from its own heights).
- **Cloth hats are worn, not ruined** (default): the fade, sweat mark and frayed edges are strong enough to see in
  the close pictures and no stronger; these are a weekend player's hats.
- **The studio's streaky lit patch on the back of the high cut** is the lamp on a faceted shell (the colour, normal
  and roughness maps are clean there, checked as crops); it is in main's picture too.
- **Bots' gloves, the first-person hands and sleeves** are the arms thread's (HA1) and are left alone.
- **No print, no labels, no brand marks** (BL9's rule).

## Known issues left

- The body's maps also changed in the empty atlas within 4 px of the painted parts (the margin a mip level needs)
  and, by more than 30 of 255, in 330 normal-map pixels at the painted parts' borders under the cloth beside them
  (QA); neither shows.
- At the farthest level the high cut's and the cap's mesh masks keep no triangle on the binding's tile (decimation),
  so the tape is not drawn there.
- The whole figure from far off reads as before (`mq3b-7`): this is a pass for a figure within a few metres.
- The band's ribs and the boots' creases are coarse beside the gear's weave (1.3 mm a pixel against 0.42): the body
  shares one 2048 atlas. Finer needs the body's atlas split in two, which is a rebake.
- The rims' rubber trim, buckles, screws and the microphone still draw flat swatches.
- `body_surfaces.py` tells the boots' parts by the roughness the bake gave them; if `body.py`'s `ROUGH` changes,
  `PART_ROUGH` there changes with it (the build's report prints how many pixels each part got).
