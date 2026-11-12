# MQ3 · The figures' gear drawn as what it is made of

**Review:** 1 attempt · critic PENDING · qa PENDING · performance PENDING

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | PENDING | PENDING | – |

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
the model with 12 rays at every second pixel, and a normal map made from the same heights as the colour.

- **Where it is drawn.** The team-colour parts (`TeamGear`) have 2048 maps of their own, `human_teamgear_col`,
  `_nrm` and `_orm` (233 charts at 0.40 mm a pixel). The rest (`Pads` material, which the gear has shared with the
  knee pads since BP6) fills the pads' maps, now 2048, round the pads' own 1024 square at the top left (1,111
  charts at 0.71 mm a pixel). The figure keeps its eight materials.
- **The lower levels are unchanged in look**: `_LOD1` and `_LOD2` still draw plain colours from a 256 by 32 strip of
  swatches, now placed in the same maps, so a figure at range and the team cue are as they were.
- **No step where the detail drops.** The weave, the grime and the shade together leave each swatch its colour:
  the painter lifts a swatch until its mean over the faces that show is the plain colour the lower levels draw
  (QA measured the first build a third darker up close than at range). The team colour map imports at high quality
  (BC7), as the pads' does since BP6: BC1 darkened the flat strip.
- **No mesh changed** but the gear's own corners (a new UV each) and the pads' UVs (rescaled to their square):
  `Kit` 10,098 / 3,276 / 760 triangles, `Kit_Pack` 2,836 / 834 / 188, `Kit_Radio` 764 / 240, as before. A chart's
  border splits its corners, so the three full-detail pieces have 15,927 vertices (13,265 before; the whole figure
  at full detail about 6.5 % more).
- **No game code changed.** The materials keep their names; the figures' paint, fade and team colour read them as
  before.
- **The build** (`tools/blender/figure-gear/`): `atlas.py` (numpy only) cuts charts where faces turn or change
  swatch, lays each flat, shrinks the ones nothing can see (the plates' inner faces), packs them at one scale with
  a 3 pixel gutter and paints them; `gear.py` gathers the faces, measures cover and shade with Blender's ray
  tree and writes the maps as WebP; `splice.py` writes WebP and normal maps and repaints the pads' material;
  `pads.py` writes its maps as 2048 canvases and `splice_part.py` can take a named material from the part. A
  second run gives the same file, byte for byte.
- **Files:** `human.glb` 12.1 MB (was 9.7). The colour and normal maps import at 2048 (BC7 and RGTC), the roughness
  and metal map at 1024, as the body's and the heads' do.
- **Tests** (`tests/unit/test_gear_surfaces.gd`): both families draw 2048 colour and normal maps; the full-detail
  pieces lie in charts, off the pads' square and off the strips, and cover a least share of the maps; the lower
  levels stay on the strips; the pads stay in their square; the normal maps carry relief where the charts are and
  none on the strips; the figure has at most eight materials. QA's `test_mq3_qa.gd`: the team strip is the
  swatches main had and stays neutral under the team paint; each piece's mean colour at full detail is its lower
  level's; no chart overlaps another or samples empty canvas; the pads sample their own painting at every level;
  the six maps' import settings.
- **Docs:** `docs/ASSETS.md`, `docs/ART.md` › Figures, `assets/models/characters/README.md`,
  `tools/blender/figures/README.md`, `docs/PLAYTEST.md` › What the figures' gear is made of (MQ3).
- **Pictures:** `art/model-quality/mq3/` in the project files: the carrier, the belt and pack, and the whole
  figure, before and after, in Alpha's blue and Beta's orange.
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
- **Gear first; headwear, face and body next (MQ3B)** (default): the heads already carry painted atlases (BL11), and
  the hands, gloves and sleeves in first person belong to the arms thread.

## Known issues left

- Texture memory for the figure grows by 15 to 23 MB by the card's format (two 2048 sets where there was a 512
  colour map, a 1024 normal map and a strip), and no graphics preset draws the figures' maps smaller: the lever, if
  Low needs one on a modest card, is a size limit on these maps' import (performance advisory; a play check asks
  for the frame rate).
- A face nothing can see (a plate bag's inner side) keeps half the baked shade, so what shows of one past an edge
  is dim, not black.
- The weave is painted in each chart's own direction; across a seam between two charts it can turn. Seams lie on
  bound edges, where real kit turns its cloth too.
