# The figures' head gear (BL11)

The human figure's four heads, built from the owner's photos (`ref_images.zip` › `clothes/highcut_helmet`,
`baseball_cap`, `boonie_hat`, `goggles`, `mesh_face_mask`) and spliced into `assets/models/characters/human.glb`.

| Script | What it holds |
|---|---|
| `headwear.py` | The heads (`Head_HighCut`, `Head_Cap`, `Head_Boonie`, `Head_FullCut`, each with `_LOD1` and `_LOD2`): what each wears, the levels of detail and the budget check. Run it to rebuild. |
| `face.py` | The face in the balaclava's eye opening (FA1): the knit's hole, the skin (constrained Delaunay round the lids), the lids, the eyeballs and the knit hem; and the eyes' shape. |
| `face_paint.py` | The face's own map (MQ3C: 2048 x 1024, four looks side by side, about 0.14 mm a pixel), painted with numpy from where a pixel lies on the face in metres: skin with uneven tone and pores, brows and lashes as single tapered hairs, the lids' fold and fine lines, an iris of fibres, veined whites. |
| `head_shapes.py` | The head and the helmet shells as formulas: the head's radius by azimuth and height, the shells' superellipsoid and rim curves. |
| `head_textures.py` | The 2048 px atlas (colour, normal, ORM) painted with numpy: the knit, loop, mesh, shells, brims and straps, each drawn as used kit from where a pixel lies on the part in metres (MQ3B: peel and scratches in paint, a moulded grain, faded cloth, chipped mesh), and the tiles of the ear cups, cushions, goggle frame, the mask's binding and the headset's band. The maps are saved lossless: lossy colour bled one tile's edge into the next. |
| `headkit.py` | Shared helpers: mesh building (`Part`), draping on the head (`Drape`), the atlas (`Atlas`, `Tile`). |
| `splice_heads.py` | Replaces the `Head_*` meshes, the `Headwear`, `TeamHeadwear` and `Lens` materials and the atlas inside `human.glb`, skinned to the `Head` bone but for the neck inside the collar, which takes the collar's weights (CN1); leaves every other node alone. |

Rebuild (pip `bpy`, see `tools/blender/bot-figure/README.md` › `headless.py`):

```
python3 tools/blender/figures/headwear.py            # rebuild and splice into human.glb
python3 tools/blender/figures/headwear.py --out x.glb  # splice into a copy instead
HEADWEAR_PARTS=1 python3 tools/blender/figures/headwear.py  # also print each part's triangles
```

then `godot --headless --import`, and update `HUMAN_HIGH` in `tests/unit/test_figure_body.gd` if the largest head's
count changed.

- **Budget:** the largest head 9,000 / 3,200 / 900 triangles (LOD0 / 1 / 2), the head's share of the figure's 60k,
  agreed with the body (BL10) and carrier (BL12) work; the face (FA1) took the split's spare 1,000 / 600 / 100. The build stops if a head goes over. Every head aims at 95 to
  100 % of each level's budget (owner, 2026-11-05): `DENSITY` scales a head's counts per level; after changing a
  part, retune it (`HEADWEAR_DENSITY=Head_Cap:1:1.2 HEADWEAR_PARTS=1 ... --out x.glb` tries a value).
- **Tiles that go round a part** (a shell, a cup, a cushion) must meet themselves where their ends meet: paint them
  from `_st(t)` (a pixel's place as the UVs reach it) with a `wrap`. **Strips** swept along a path (the mask's
  binding, the headset's band) draw from a short tile laid back and forth (`strip_s`), so the tile's two ends never
  meet and any length is covered. A part moved off a swatch onto a tile changes UVs only, never the triangle counts.
  A part's middle is laid flat on a square tile, never unrolled to a point (the ear cups' faces `cup_face_*`, the
  boonie's top `boonie_top`): unrolled, the tile is far finer round the part than across it, and a grain or a weave
  comes out as rings or a starburst. Paint both tiles from a pixel's place on the part (`_cup_place`) and they
  meet without a mark. A smooth even part keeps an even colour: the game's block compression turns a faint tone
  into squares.
- **Team marks:** every surface on `TeamHeadwear` is tinted in game (the high cut's back patch, the full cut's band,
  the cap's front patch, the boonie's band).
- **Face looks:** `Face` surfaces draw from the face's own map (`face.FACE_MAP`, MQ3C; its old cells above the
  atlas's swatches are empty); four looks (skin, brows, eyes) are painted in its cells (`face.FACE_CELLS`, `LOOKS`,
  `face_paint.py`) and the game offsets the material's UVs per figure (`FigureConfig.face_offsets`, `face_look`). A
  new look is a new cell, a `LOOKS` entry and an offset; the mesh doesn't change. Nothing of the face stands out of
  the knit's surface but the lids (1.5 mm at most), so gear fitted to the head clears it. The extracted
  `human_face_*.webp` are packed like the atlas's (their `.import` files: compressed, the normal map marked as one,
  the roughness map at half size); a hair or a pore is drawn at its real size, so nothing is finer than a pixel.
- **Space:** Blender metres, +Z up, the figure facing -Y, +X its left, at the rest pose. Everything sits on the whole
  LOD0 head, so the gear lands in the same place at every level.

## The shirt's collar and the neck (CN1)

`collar.py` holds the shirt's mock-neck collar as numbers (its rings round the heads' neck axis, higher at the back):
`body.py` grows it from the shirt's neckline and `headwear.py` lays the boonie's scarf over it. `splice_heads.py`
gives each head's neck inside the collar the weights of the collar vertex nearest it, so the neck bends with the
collar instead of swinging out behind it: after the body is rebuilt, run `headwear.py` **last**, after `pads.py`,
`gear.py` and `body_weights.py`.

## Knee and elbow pads (BL13)

Parts of the human figure built apart from its body and spliced into `assets/models/characters/human.glb` by node
name (BL13, 2026-11-05), so a part and the body can each be rebuilt without the other.

| Script | What it does |
|---|---|
| `pads.py` | The knee and elbow pads, `Kit_Pads` with `_LOD1` and `_LOD2` (budget 3,000 / 1,000 / 300 triangles), from the owner's knee pad photos: imports `human.glb`, fits the pads to its `Body` in the rest pose, paints their maps (the 1024 square at the top left of the 2048 `human_pads_*` maps, whose rest `figure-gear/gear.py` fills with the gear's charts, MQ3), exports them with a copy of the figure's armature, splices them in and lists them in `human.json`'s parts |
| `body_weights.py` | Plain Python with numpy (BP6): the gloves' hard plates (the back plate and its border, the knuckle domes, the finger guards: small shells of the full-detail `Body` led by hand bones) each on one set of weights, so a bent finger turns a plate whole instead of shearing it. Nothing else changes: the shoulders keep body.py's weights (owner, 2026-11-07). Run last |
| `splice_part.py` | Plain Python (no Blender): copies every node whose name starts with a prefix from one glTF binary into the figure's, with its mesh, materials and textures, the joints mapped to the figure's skin by bone name after checking both rest poses match; everything else in the figure file is kept |

Run from the repository root with Blender 5.2's Python module (`pip install bpy==5.2.3`), then reimport in Godot:

    python -I tools/blender/figures/pads.py .
    godot --headless --import

After the body is rebuilt, run `pads.py` again: it refits the pads to the new body's surface; then
`tools/blender/figure-gear/gear.py` (`pads.py` writes the pads' maps afresh, with the pads' square and the gear's
swatch strip at `gear.PADS_AT` only; `gear.py` then bakes its charts into the rest, MQ3),
and last `python -I tools/blender/figures/body_weights.py assets/models/characters/human.glb` (the body's splice brings
back the blended weights on the gloves' plates). `human_pads_col.webp` imports with high-quality compression (BC7): BC1
darkened the gear's flat swatches.

## The arm bands and the boots (MQ3B)

| Script | What it does |
|---|---|
| `body_surfaces.py` | Plain Python with numpy and Pillow: paints the team arm bands (ribbed elastic, hems, the sewn overlap) and the boots (brushed suede, creases across the vamp, scuffed toe caps, lugs on the sole's side) over the body's three baked maps inside `human.glb`, from where each pixel lies in space, and gives the band's material the body's colour map (white under the game's team colour). No mesh, UV or weight changes. |

    python3 -I tools/blender/figures/body_surfaces.py            # paint human.glb in place
    python3 -I tools/blender/figures/body_surfaces.py --report   # also print each part's pixels and measurements

Run it once after the body's splice (before or after the pads, gear and heads: they leave the body's maps alone). It
tells a painted file by the arm band's colour map and stops, so a second run cannot paint twice. It tells the boots'
parts by the roughness `body.py` gave them (`PART_ROUGH` there follows `body.ROUGH`); the body itself is not rebaked,
because a rebuild does not give the committed mesh, UV layout and weights back.