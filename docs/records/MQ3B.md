# MQ3B · The figures' headwear, arm bands and boots drawn as what they are made of

**Review:** 3 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Fable 5.2 (model quality thread) | pass (6,442 tests) | Retry 7/8 (near miss, judgment) | – |
| 2026-11-13 | 2 | Fable 5.2 (model quality thread) | pass (6,443 tests) | Retry 7/8 (near miss, judgment) | check 1, four surfaces: the boots' creases ran down the sides as streaks and the suede was blotchy; the ear cups read as turned rings; the boonie's sweat mark sat 3 cm above the band as a blotch |
| 2026-11-13 | 3 | Fable 5.2 (model quality thread) | pass (6,445 tests) | Accept 8/8 | check 1, three surfaces (the boots passed): the boonie's weave met at the crown's middle as a starburst; faint rings still showed round the ear cups; the boonie's sweat line could not be seen |

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
| Cap and boonie | even ripstop with stitching | unevenly faded cloth, paler on top, the brims' edges worn pale; a sweat mark above the cap's hem, a sweat-dark band 15 mm deep above the boonie's hat band; the boonie's weave at one scale up its wall, and its top a flat panel with a square weave and a seam round it |
| Boonie's band | a flat team colour | woven ribs and weft with relief |
| Loop patches (team and plain) | a faint speckle | a deeper pile, matted in patches, a little lint |
| Balaclava and shemagh | even knit and weave | uneven dye, pilling |
| Mesh mask | evenly painted wire | paint chipped to bare steel at crossings here and there and in small round patches where BBs struck |
| Ear cups (both kinds) | one flat colour | moulded polymer on tiles of their own: an even colour, the mould's shallow orange peel in the relief and the sheen, the joint to the back plate, the shoulder rubbed smoother in patches, a few scratches on the face |
| Ear cushions | one flat colour | soft leatherette with fine creases, a welded seam, a duller outer edge |
| Goggles' frame | one flat colour | matte rubber with a grain, its lip rubbed lighter, dust toward the face |
| Mesh mask's binding | one flat olive | twill tape folded over the mesh's edge with a row of stitches, its folds rubbed paler |
| Headset's band | one flat grey | padded leatherette quilted every 30 mm, a stitch row inside each edge, the pads' crowns rubbed |

The last five were the largest parts still drawn from flat swatches. They draw from eight new tiles (`cup_defender`
and `cup_headset` for the cups' side walls, `cup_face_defender` and `cup_face_headset` for their shoulders and faces
laid flat, `cushion`, `goggle_frame`, `binding`, `headband`: the two strips are short tiles laid back and forth
along the part, so a 12 cm tile covers the whole binding with no seam). The boonie's top panel has a flat tile of
its own too (`boonie_top`), cut with the cups' faces from the upper half of the crown's old tile. What is left on swatches is small and hard
(buckles, screws, the microphone, the rims' rubber trim: at most 15 % of a head's area that shows) and the inside of a
helmet's shell, which nothing sees.

**The body** (`tools/blender/figures/body_surfaces.py`, new: numpy and Pillow, no Blender). A pass over the body's
three baked maps inside `human.glb`. It draws every body triangle into the atlas to learn where each pixel is in
space, tells the arm bands by their material and the boots' parts by height and the roughness the bake gave them,
and paints only those pixels (270,156 of the 2048 square):

| Part | Before | Now |
|---|---|---|
| Team arm bands | one flat team colour, lit by the sleeve's normals | elastic webbing: ten ribs round the arm, a folded hem with a stitch row at each edge, the sewn overlap at the back of the arm, puckers; the ribs' valleys and handled patches a shade darker |
| Boots' suede uppers | smooth, one roughness | the nap lying this way and that in soft patches (its brushed streaks in the sheen more than the colour), three creases across the top of the vamp where the foot bends, bowed and gone before the sides, dark rubbed patches low at the toe |
| Toe caps and heel counters | smooth | scuffed paler in soft patches, a few scratches fore and aft |
| Soles | a plain slab | lugs cut into the tread's side all round, a paler worn bottom edge, dried dust |

The arm band now draws the body's colour map (white under the team colour the game paints), so its ribs, grime and
the body's baked occlusion show on it; before it had no colour map. The map is neutral grey there (red, green and
blue equal), so the hue is Alpha's blue and Beta's orange as before, and the ribs' crests in the open are the full
team colour. Its mean is 0.88 of white in the map (0.77 in linear light): on average the band is about a fifth
darker than the flat colour it was, which is the ribs' valleys, the grime and the shade the bake put under the arm.

- **References:** the owner's photos these parts were modelled from (BL10, BL11), `ref_images.zip` ›
  `clothes/highcut_helmet` (ten, among them `Helmet-MICH-High-Cut-Tactical(4)`), `clothes/baseball_cap` (four,
  among them `Screenshot 2026-11-04 122905`), `clothes/boonie_hat` (six, among them `boonie_olive_3`),
  `clothes/goggles` (five), `clothes/mesh_face_mask` (five, among them `6031-tn_1___43521`) and `player/figure`
  (sixteen, among them `EK7A5361` and `bbqhqxirl3db1`). What the paint takes from them: the mask's edge bound in
  woven tape and sewn through; the cap's and the boonie's ripstop with rows of stitching round the brim; moulded
  rails and cups against a painted shell; suede boots with a rubber toe cap and a lugged sole; an elastic band round
  the upper arm. The wear (fade, sweat, scuffs, chips) is what a season's use leaves on such kit and is in none of
  the product photos; one of the players' photos, `EK7A5361`, shows a helmet mottled brown all over (dust,
  or a rough coat of paint), and the dust low on the shells and beside the covers' seams is kept well short of it. No print, label or maker's mark is taken from
  any of them.
- **The face is unchanged** (FA1's four looks, in their cells of the atlas, byte for byte from the same painter).
  It is small on screen behind goggles or glasses; the critic's and the owner's notes on it are in FA1.
- **No mesh changed**: the heads' triangles (the largest, the boonie's, 8,958 / 3,192 / 896), the body's (33,458), every UV island
  of the body and every weight are as they were. On the heads only UVs changed: the five moved parts', and the
  boonie crown's (its wall's rings laid by their distance over the cloth, its top laid flat). The new seams split
  339 vertices over the head meshes (105,524 in the file, 105,185 before), with no triangle added. `tests/unit/test_figure_body.gd`'s counts hold.
- **No game code changed.** The band's material keeps its name; `FigureModels.team_material` copies it and sets its
  colour as before, and the copy keeps the map (a test holds this).
- **Lower detail levels** draw the same maps, so the body's far levels show the band's and boots' paint as far as a
  mip level carries it; at range it averages to the colours they had.
- **The build.** `python3 -I tools/blender/figures/headwear.py` (heads, as before), then
  `python3 -I tools/blender/figures/body_surfaces.py` (8 s). The second runs once on a freshly built body: it tells a
  painted file by the arm band's colour map, which only it adds, and stops. Both builds give the same file byte for
  byte on a second run from main's file.
- **Files:** `human.glb` 14.8 MB (was 12.5). The heads' three maps are now stored lossless (1.07, 1.79 and 0.11 MB;
  0.20, 0.69 and 0.01 before): lossy colour smeared one tile's edge into the next, which showed as a line where a
  tile that goes round a part meets itself. The body's maps go back as lossy WebP at quality 95 (0.64, 0.92 and
  0.15 MB; 0.57, 0.86 and 0.09): the cloth round the painted parts differs from before by 0.5 of 255 in colour and
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
  (the boonie also close from the side and from above, `mq3b-3`), from the front (`mq3b-4`), the arm band
  (`mq3b-5`), the boots from the side, the toe and above (`mq3b-6`), the whole figure (`mq3b-7`), the ear cups up
  close (`mq3b-8`).

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
- **A part's middle is laid flat, never unrolled to a point** (attempts 2 and 3): unrolled to its middle, a tile
  is far finer round the part than across it. On the ear cups a 0.7 mm grain came out as rings, and so did a 3.6 mm
  one, because a height's slopes then show across the rings and not along them, and the game's block compression
  bands a faint tone the same way. On the boonie the weave's lines met at the middle as a starburst. So a cup's
  shoulder and face lie flat on a square tile (0.75 mm a pixel every way), its side wall alone is unrolled, and
  both are painted from a pixel's place on the cup, so they meet without a mark; the boonie's top panel lies flat on
  its own tile inside the seam ring.
- **An ear cup's colour is even** (attempt 3): in the block-compressed map a 3 % tone on so smooth a part came out
  as squares, and rubbed patches 15 % lighter as stains. A moulded cup shows wear in its sheen: the orange peel is
  relief and roughness, a rub is smoother, only the joint and the scratches change the colour.
- **The suede's colour stays quiet** (attempt 2): the imported maps are block-compressed, and fine low-contrast
  colour noise at 1.3 mm a pixel came out as blotches and blocks. The nap is in broad soft patches of colour and in
  the roughness; the creases lie across the top of the vamp only (within 3 cm of the boot's middle line), as a
  boot's flex creases do.
- **The boonie crown's rings are laid by their distance over the cloth** (attempt 2): its tile's rows were spaced by
  ring, so the weave tightened up the wall, the top's last rings ran off the tile's edge as a smear, and the sweat
  mark meant for the band's edge landed 3 cm above it. Now one scale from the band to the seam round the top, at
  every level. The sweat mark is a band from the hat band's top edge to 15 mm above it, a quarter darker, with
  2 mm of wander (attempt 3: at 11 mm and 15 % it could not be seen).
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
- The critic's notes on the accepted cups, left for the owner's eye in play: one scratch on a cup's face reads as a
  dotted line, the smoother rubbed patches reach onto the face as soft clouds under a hard light, and a cup's
  outline is faceted up close (the mesh, which this pass could not touch).
- `body_surfaces.py` tells the boots' parts by the roughness the bake gave them; if `body.py`'s `ROUGH` changes,
  `PART_ROUGH` there changes with it (the build's report prints how many pixels each part got).
