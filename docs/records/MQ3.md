# MQ3 · The figures' gear drawn as what it is made of

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | ✓ | Retry 7/8 | The contact shade read as a wavy, blotchy band (12 rays at every second pixel, two passes of blur); the rolled dump pouch's paint was stretched round its flat facets; a light wedge on the pack's side; the whole figure hardly differed from before at a few metres; no reference photos named |
| 2026-11-13 | 2 | Fable 5.2 (model quality thread) | ✓ | Accept 8/8 | – |

## What changed

Owner, 2026-11-12: "Also do this for figure and cloth models. This means the human face, helmets, goggles, plate
carriers, etc. Basically every single 3D model in the game." MQ1 and MQ2 did the replicas and their parts. This is
the first of the figure: the gear every human wears (the plate carrier, its pouches, the battle belt and holster,
the pack and the radio). Until now each of its parts was one flat colour from a strip of swatches.

The full-detail pieces (`Kit`, `Kit_Pack`, `Kit_Radio`) are now unwrapped into charts and painted from the model
itself, each pixel knowing where on the gear it lies:

| Made of | Drawn as |
|---|---|
| Cordura (carrier, pouches, pack) | a plain weave, a faint mottle, the cloth swelling a little between seams |
| Webbing (MOLLE rows, straps, the belt) | a finer rib along the strap with a tick across it every 2.4 mm |
| Loop panels | a short random pile |
| Edges | a bound tape 3 mm wide, a shade lighter and standing proud, with a row of stitches beside it |
| Polymer (buckles, the holster, the radio) | a fine moulded grain, a worn lighter edge |
| Cord and zips | a twist along the cord, teeth along the zip (a new `zip` swatch on the pack's three zips) |

Every chart also carries the shade of what lies on it (a pouch on the carrier, the pack on the back), measured from
the model with 32 rays at every second pixel, the set of rays turned by its own angle at each pixel and the answers
softened within each chart (ten passes), and a normal map made from the same heights as the colour.

- **References:** the owner's photos the gear was modelled from (BL12): `ref_images.zip` › `player/plate_carrier`
  (`DCSPlateCarrierBaseblk_0003_Layer9`, `IMG_0641-scaled-1`, `v1-1200x1200`, `v3-1200x1200`, one screenshot),
  `pouches` (six, among them `VPELMG-0031`, `sta-pounch1-tan_1_` and `britishvirtusutilitypouch-01_grande`) and
  `backpack` (five). What the paint takes from them: the plain cordura weave, webbing sewn in rows with a bar tack
  between the loops, a loop panel's pile, edges bound in tape with a stitch row beside it, zips with teeth and a
  cord pull, cloth a shade dustier toward its seams and faded where it faces the sky. No print, label or maker's
  mark is taken from any of them.
- **Laid flat without stretch.** A chart that bends (the rolled dump pouch, a pouch's rounded lid, a strap round a
  corner) is eased until each of its triangles has its true shape (as rigid as possible, Liu 2008: a rotation fitted
  to each triangle, then all corners solved together, up to 60 passes), so the weave keeps one size round a curve.
  Before, a bent chart was projected onto its first face's plane and its far faces were drawn at as little as a
  twelfth of their true area; now no chart's face is under 0.81 of its true area. The paint reads its pattern from these flat
  coordinates in metres, so a weave thread is as wide on a roll as on a plate bag.
- **Tone that reads from a few metres** (the critic's fourth point): broad sun-and-dust patches 17 cm across
  (7.5 % either way), a wider, fainter band of dust toward each sewn panel's edges (28 mm, 15 %), each sewn panel
  a hashed shade off its neighbour (5 % either way), and cloth, webbing and loop faded lighter where they face the
  sky and dirtier where they face the ground (10 %). Each swatch is still levelled to its plain colour, so the
  team cue and the step between detail levels are as they were.
- **The rolled dump pouch** is rounder (its outline's corners in five steps, its roll's edge in three) and its
  roll is smooth shaded with no bound edge across it: its faces are marked soft, a soft bend is never a panel
  edge. This is the one mesh that changed: `Kit` 10,288 triangles at full detail (10,098 before; budget 10,300).

- **Where it is drawn.** The team-colour parts (`TeamGear`) have 2048 maps of their own, `human_teamgear_col`,
  `_nrm` and `_orm` (233 charts at 0.42 mm a pixel). The rest (`Pads` material, which the gear has shared with the
  knee pads since BP6) fills the pads' maps, now 2048, round the pads' own 1024 square at the top left (1,111
  charts at 0.72 mm a pixel). The figure keeps its eight materials.
- **The lower levels are unchanged in look**: `_LOD1` and `_LOD2` still draw plain colours from a 256 by 32 strip of
  swatches, now placed in the same maps, so a figure at range and the team cue are as they were.
- **No step where the detail drops.** The weave, the grime and the shade together leave each swatch its colour:
  the painter lifts a swatch until its mean over the faces that show is the plain colour the lower levels draw
  (QA measured the first build a third darker up close than at range). The team colour map imports at high quality
  (BC7), as the pads' does since BP6: BC1 darkened the flat strip.
- **No other mesh changed** but the gear's own corners (a new UV each) and the pads' UVs (rescaled to their
  square): `Kit` 10,288 / 3,276 / 760 triangles, `Kit_Pack` 2,836 / 834 / 188, `Kit_Radio` 764 / 240. A chart's
  border splits its corners, so the three full-detail pieces have 16,029 vertices (13,265 before; the whole figure
  at full detail about 6.8 % more).
- **No game code changed.** The materials keep their names; the figures' paint, fade and team colour read them as
  before.
- **The build** (`tools/blender/figure-gear/`): `atlas.py` (numpy only) cuts charts where faces turn or change
  swatch, lays each flat, shrinks the ones nothing can see (the plates' inner faces), packs them at one scale with
  a 3 pixel gutter and paints them; `gear.py` gathers the faces, measures cover and shade with Blender's ray
  tree and writes the maps as WebP; `splice.py` writes WebP and normal maps and repaints the pads' material;
  `pads.py` writes its maps as 2048 canvases and `splice_part.py` can take a named material from the part. A
  second run gives the same file, byte for byte.
- **Files:** `human.glb` 12.5 MB (was 9.7). The colour and normal maps import at their full 2048 (no size limit; BC7 and
  RGTC), the roughness and metal map limited to 1024, as the body's and the heads' are.
- **Tests** (`tests/unit/test_gear_surfaces.gd`): both families draw 2048 colour and normal maps; the full-detail
  pieces lie in charts, off the pads' square and off the strips, and cover a least share of the maps; the lower
  levels stay on the strips; the pads stay in their square; the normal maps carry relief where the charts are and
  none on the strips; the figure has at most eight materials. QA's `test_mq3_qa.gd`: the team strip is the
  swatches main had and stays neutral under the team paint; each piece's mean colour at full detail is its lower
  level's; no chart overlaps another or samples empty canvas; the pads sample their own painting at every level;
  the six maps' import settings; (attempt 2) no chart face shrunk or stretched beyond 0.7 of its chart's scale
  (worst 0.825), no UV triangle flipped against its chart, `Kit` within its 10,300 triangles, every gear normal
  of unit length and outward of its face.
- **Docs:** `docs/ASSETS.md`, `docs/ART.md` › Figures, `assets/models/characters/README.md`,
  `tools/blender/figures/README.md`, `docs/PLAYTEST.md` › What the figures' gear is made of (MQ3).
- **Pictures:** `art/model-quality/mq3/` in the project files: the carrier, the belt and pack, and the whole
  figure, before and after, in Alpha's blue and Beta's orange (`mq3-1` to `mq3-3`); the dump pouch in the first
  and the second pass (`mq3-4`); the chest with and without the studio lamp's shadow (`mq3-5`); the pack on the
  figure and alone (`mq3-6`).
- **The studio** (`tools/model_studio.gd`, dev only): a shot can show named meshes only (`+Body+Kit`) and paint
  the team materials (`#3b87f5`), for pictures of the figure.

## Decisions

- **Baked into maps, not a shader** (default): the figures are drawn by the dozen with the engine's standard
  material, their fade and team paint built on it. A bake costs nothing a frame and changes no code.
- **The lower levels stay plain** (default): past a few metres the weave is under a pixel; the strips keep the
  colour and the team cue exactly as they were, and the test holds the strips flat in the normal maps.
- **Two 2048 map sets** (default): the owner's limit is 2K a texture. One shared set gave 0.9 mm a pixel, too
  coarse for a weave; the team-colour parts on their own set get 0.40 mm.
- **Patterns never finer than 3.2 pixels** (default): a finer weave than the map can hold turns to noise, so the
  `Pads` family's weave is drawn a little coarser than life (2.3 mm) with its contrast turned down to match.
- **No print, no labels, no brand marks** (BL9's rule).
- **Two of the critic's marks were the studio lamp's shadows, and the pictures say so** (attempt 2): the wavy edge
  under the chest's loop panel and the light wedge on the pack's side are both in the pictures of main's figure,
  and both go when the lamp's shadow is off (`mq3-5`) or the pack stands alone (`mq3-6`): the wedge is lamp light
  past the back plate. Neither is in the maps, so neither was painted out. What was wrong in the maps under the
  loop panel is fixed: too few rays, too little softening, and a face half hidden under a pouch shaded lighter all
  over than its neighbours.
- **Every pixel is shaded by how shut in it is** (attempt 2): the half shade a hidden face kept is gone; it drew
  light face-shaped patches where a pouch only half covered a face.
- **The soft roll has no binding** (attempt 2): a rolled-up pouch is one piece of cloth, so its bends are not panel
  edges; the binding stays on its lid.
- **Gear first; headwear, face and body next (MQ3B)** (default): the heads already carry painted atlases (BL11), and
  the hands, gloves and sleeves in first person belong to the arms thread.

## Known issues left

- Texture memory for the figure grows by 15 to 23 MB by the card's format (two 2048 sets where there was a 512
  colour map, a 1024 normal map and a strip), and no graphics preset draws the figures' maps smaller: the lever, if
  Low needs one on a modest card, is a size limit on these maps' import (performance advisory; a play check asks
  for the frame rate).
- The studio lamp's shadow of the chest's loop panel has a wavy edge (in main's pictures too); the game's sun may
  draw the same on a figure up close. It is the lamp's shadow on the bag, not the maps.
- `Kit` is 12 triangles under its budget; another piece of gear needs the budget raised or a piece thinned.
- Very close (a 30 cm view) the dump roll's ends still show their five-step corners (critic advisory); rounder
  needs the owner to raise `Kit`'s budget.
- The weave is painted in each chart's own direction; across a seam between two charts it can turn. Seams lie on
  bound edges, where real kit turns its cloth too.
