# The figures' head gear (BL11)

The human figure's four heads, built from the owner's photos (`ref_images.zip` › `clothes/highcut_helmet`,
`baseball_cap`, `boonie_hat`, `goggles`, `mesh_face_mask`) and spliced into `assets/models/characters/human.glb`.

| Script | What it holds |
|---|---|
| `headwear.py` | The heads (`Head_HighCut`, `Head_Cap`, `Head_Boonie`, `Head_FullCut`, each with `_LOD1` and `_LOD2`): what each wears, the levels of detail and the budget check. Run it to rebuild. |
| `face.py` | The face in the balaclava's eye opening (FA1): the knit's hole, the skin (constrained Delaunay round the lids), the lids, the eyeballs and the knit hem; its four looks painted in the atlas. |
| `head_shapes.py` | The head and the helmet shells as formulas: the head's radius by azimuth and height, the shells' superellipsoid and rim curves. |
| `head_textures.py` | The 2048 px atlas (colour, normal, ORM) painted with numpy: the knit, loop, mesh, shells, brims and straps. |
| `headkit.py` | Shared helpers: mesh building (`Part`), draping on the head (`Drape`), the atlas (`Atlas`, `Tile`). |
| `splice_heads.py` | Replaces the `Head_*` meshes, the `Headwear`, `TeamHeadwear` and `Lens` materials and the atlas inside `human.glb`, skinned whole to the `Head` bone; leaves every other node alone. |

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
- **Team marks:** every surface on `TeamHeadwear` is tinted in game (the high cut's back patch, the full cut's band,
  the cap's front patch, the boonie's band).
- **Face looks:** `Face` surfaces share the atlas; four looks (skin, brows, eyes) are painted in cells above the
  swatches (`face.FACE_CELLS`, `LOOKS`) and the game offsets the material's UVs per figure (`FigureConfig.face_offsets`,
  `face_look`). A new look is a new cell, a `LOOKS` entry and an offset; the mesh doesn't change. Nothing of the face
  stands out of the knit's surface but the lids (1.5 mm at most), so gear fitted to the head clears it.
- **Space:** Blender metres, +Z up, the figure facing -Y, +X its left, at the rest pose. Everything sits on the whole
  LOD0 head, so the gear lands in the same place at every level.

## Knee and elbow pads (BL13)

Parts of the human figure built apart from its body and spliced into `assets/models/characters/human.glb` by node
name (BL13, 2026-11-05), so a part and the body can each be rebuilt without the other.

| Script | What it does |
|---|---|
| `pads.py` | The knee and elbow pads, `Kit_Pads` with `_LOD1` and `_LOD2` (budget 3,000 / 1,000 / 300 triangles), from the owner's knee pad photos: imports `human.glb`, fits the pads to its `Body` in the rest pose, paints their 1024 maps, exports them with a copy of the figure's armature, splices them in and lists them in `human.json`'s parts |
| `body_weights.py` | Plain Python with numpy (BP6): two fixes to the `Body` levels' weights, rewritten in place. The chest's side under each arm comes off the upper arm (it swung up over the shoulder strap with the arm raised); each hard plate of the gloves (the back plate and its border, the knuckle domes, the finger guards: small shells of the full-detail `Body` led by hand bones) moves whole, so a bent finger turns a plate instead of shearing it. Run last |
| `splice_part.py` | Plain Python (no Blender): copies every node whose name starts with a prefix from one glTF binary into the figure's, with its mesh, materials and textures, the joints mapped to the figure's skin by bone name after checking both rest poses match; everything else in the figure file is kept |

Run from the repository root with Blender 5.2's Python module (`pip install bpy==5.2.3`), then reimport in Godot:

    python -I tools/blender/figures/pads.py .
    godot --headless --import

After the body is rebuilt, run `pads.py` again: it refits the pads to the new body's surface; then
`tools/blender/figure-gear/gear.py` (its swatch strip lives in the pads' maps, painted by `pads.py` at `gear.PADS_AT`),
and last `python -I tools/blender/figures/body_weights.py assets/models/characters/human.glb` (the body's splice brings
back the blended weights under the arms and on the gloves' plates). `human_pads_col.webp` imports with high-quality
compression (BC7): BC1 darkened the gear's flat swatches.
