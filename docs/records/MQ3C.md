# MQ3C · The figures' faces drawn as real ones

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Fable 5.2 (model quality thread) | pending | pending | – |

## What changed

Owner, 2026-11-13: "Has the players face been improved? If not then add that to the list of models to work on".
It had not: MQ3B left the face as FA1 made it, a clean stylised one in a 256 x 128 cell of the heads' atlas (about
0.56 mm a pixel: an eye 36 pixels wide), with even skin, brows drawn as a block, a drawn lash line and round, wide
eyes. This is the face in the model quality pass: "more realistic detail and surfaces".

Still only the strip round the eyes is modelled (FA1's ruling stands: every head covers the rest), and the heads had
no triangles to spare, so the gain is in what is painted and in the eyes' shape:

- **A map of its own.** `Face` draws from `human_face_{col,nrm,orm}` (2048 x 1024, four looks side by side, each
  1024 x 512: four times the old cell each way, 0.14 mm a pixel, and a pixel as high as it is wide). The figure
  keeps its eight materials; `FigureConfig.face_offsets` are now half a map apart. The old cells in the heads' atlas
  are empty.
- **Painted as a face** (`tools/blender/figures/face_paint.py`, numpy, from each pixel's place in metres):

| Part | Before | Now |
|---|---|---|
| Skin | one even colour, a soft flush | uneven tone in broad and fine lumps, redder patches, warmer over the nose, darker and cooler on the upper lids and in the hollow under the eyes; pores and a finer grain in the normal map; the nose's bridge a little glossier; freckles on the fair look |
| Brows | a tapered dark block | 950 to 1,250 single hairs a brow, each a tapered stroke 3 to 5 mm long: nearly upright at the head, then lying along the brow, lower hairs pointing up and out, upper ones down and out, over the soft shade of the hairs beneath; a little thicker (up to 7.4 mm) |
| Lids | a thick dark lash line with a flick, a pink lower rim | a thin line of roots with 95 short lashes fanning from it, 36 shorter ones under the lower lid, a paler less glossy rim, the fold over the upper lid, two shallow lines under the lower lid and four fine ones at the outer corner |
| Iris | a flat disc lighter at the middle | fibres running out from the pupil, a lighter jagged ring round the pupil in its own colour (gold in the blue eye, amber in the green), darker pits, a dark rim fading into the white through a soft grey band; the dark eyes' fibres hardly show, as in life |
| Whites | one off-white, shaded at the corners | a warmer, less bright white, pinker toward the corners, a few fine vessels running in from them, shaded under the upper lid |

- **The eyes' shape** (`face.py`, no triangle added): 23 mm wide (20 before), the upper lid resting 1.4 mm over the
  iris and the lower 1.5 mm (the eyes stared: an 11.2 mm iris in a 20 x 8 mm opening is a doll's), the eyeball a
  little larger (radius 13.2 mm) so its cap still fills the wider opening, the carve and the lids' outer loop moved
  out with it. The skin's fill came out four triangles lighter on each head's top two levels.
- **The four looks differ as people do**, not only in colour: brow width and hair count, freckles, how deep the fine
  lines are, how much the iris's fibres show.

Reference photos (owner's `ref_images.zip`, folder `figure`): `45243d77-4f0a-49ca-904b-409532d87a26.png` (eyes in a
balaclava's opening: low heavy brows of visible hairs, lids resting on the iris, the skin darker round the eyes)
and `298750539_1772449736426341_6415112433916665141_n.jpg` (eyes behind goggles). They show an eye about 25 pixels
wide, so they set the proportions and the tone; the fine detail (hair, lashes, iris, vessels) is drawn at its real
size from anatomy, the sizes in `face_paint.py`'s constants.

Files: `tools/blender/figures/face_paint.py` (new), `face.py` (the map's layout, the looks, the eyes' shape; its
painter removed), `headkit.py` (`Atlas` of any size; the noise helpers moved here from `head_textures.py`),
`head_textures.py`, `headwear.py`, `splice_heads.py` (the `Face` material on its own images),
`game/config/figure_config.gd` (`face_offsets`), `tools/model_studio.gd` (a shot can name a face look, `#hex@2`,
and turn the model, `yaw,pitch,turn`), `assets/models/characters/human.glb` and the extracted `human_face_*`,
`human_headwear_*`, `tests/unit/test_face_map.gd` (new), `tests/unit/test_figure_body.gd` (counts).

## Budgets

- Triangles: heads 8,984 / 8,988 / 8,978 / 8,954 at full detail (high cut, cap, boonie, full cut; budget 9,000),
  3,134 / 3,140 / 3,188 / 3,154 (3,200), 896 / 880 / 896 / 874 (900). Four fewer than before on each head's top two
  levels. The figure with the high cut: 59,054 / 19,420 / 5,639.
- Materials: eight, as before (a test holds it). Textures: three more (2048 x 1024 colour and normal, the roughness
  map packed at 1024 x 512), all within the 2K rule; about 4.5 MB of video memory packed, once for all figures.
- Files: `human.glb` 18.3 MB (14.75 before: the face's maps are stored without loss, as the atlas's are); the
  extracted maps 1.1, 1.7 and 0.8 MB.

## Decisions

- **The face is drawn as a real one** (owner's ask; `docs/DECISIONS.md` › Art direction): FA1's "stylised, clean"
  face is superseded.
- **Texture first, and the shape only where it cost no triangles.** The eyes' opening, lids and carve moved; the
  mesh's rings, segments and budget stayed.
- **No light is painted** but the hem's and the lids' own shade. The eyes' glint is the game's lights on a smooth
  surface (roughness 0.10 as FA1 had it; the corners' folds duller, so a glint there does not read as a white wedge).
- **A hair is never finer than a pixel**: brow hairs and lashes are drawn 0.6 to 1 pixel wide with part cover, so they
  hold together when the map is packed and at the first smaller levels.
- **The skin's fine grain also moves the colour a little** (about 2 %): with nothing fine in it the packed map
  (S3TC) showed smooth tone as squares (MQ3B's lesson).
- **Studio pictures of a face front on** are taken with the figure turned 45 degrees and the camera with it: the
  studio's tall lamp panel otherwise reflects as a grey block on each pupil (it did in FA1's pictures too).
- No wiki page describes the bots' faces, so no wiki change.

## Known issues

- The lids' outline is 14 segments round: at 6 cm across (closer than play shows) the upper lid's edge over the
  iris is a straight run and the corners are angular. Rounder needs triangles the heads do not have.
- Lashes are painted on the lids, not standing off them: from the side they do not show.

## Play checks

`docs/PLAYTEST.md` › Faces up close (MQ3C); the Dev 3 checklist has the same entry.
