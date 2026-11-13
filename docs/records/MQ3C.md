# MQ3C · The figures' faces drawn as real ones

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Fable 5.2 (model quality thread) | pass | Retry 7/8 | Against the reference photo the eyes were too small and too far apart (a gap of 1.6 eye widths, the photo's about 1.0), the brows too thin and too high, the pupils grey (66 of 255) with no glint, a white line along the lower lid, no inner corner, and the lids' 14 sides showed |
| 2026-11-13 | 2 | Fable 5.2 (model quality thread) | pending | pending | – |

## What changed

Owner, 2026-11-13: "Has the players face been improved? If not then add that to the list of models to work on".
It had not: MQ3B left the face as FA1 made it, a clean stylised one in a 256 x 128 cell of the heads' atlas (about
0.56 mm a pixel: an eye 36 pixels wide), with even skin, brows drawn as a block, a drawn lash line and round, wide
eyes. This is the face in the model quality pass: "more realistic detail and surfaces".

Still only the strip round the eyes is modelled (FA1's ruling stands: every head covers the rest). The heads keep
their budgets (9,000 / 3,200 / 900): the eyes were reshaped and the lids rounded inside them.

- **A map of its own.** `Face` draws from `human_face_{col,nrm,orm}` (2048 x 1024, four looks side by side, each
  1024 x 512: four times the old cell each way, 0.14 mm a pixel, and a pixel as high as it is wide). The figure
  keeps its eight materials; `FigureConfig.face_offsets` are now half a map apart. The old cells in the heads' atlas
  are empty.
- **Painted as a face** (`tools/blender/figures/face_paint.py`, numpy, from each pixel's place in metres):

| Part | Before | Now |
|---|---|---|
| Skin | one even colour, a soft flush | uneven tone in broad and fine lumps, redder patches, warmer over the nose, darker and cooler on the upper lids and in the hollow under the eyes; pores and a finer grain in the normal map; freckles on the fair look |
| Brows | a tapered dark block, high over the eye | 1,800 to 2,400 single hairs a brow, each a tapered stroke 3 to 5 mm long: upright and leaning out at the head, then lying along the brow, lower hairs pointing up and out, upper ones down and out, over the soft shade of the hairs beneath; low and heavy over the eye as the photo's, the fair brow a darker brown |
| Lids | a thick dark lash line with a flick, a pink lower rim | a thin line of roots with 120 short lashes fanning from it, 44 shorter ones under the lower lid, a dull skin-pink lower margin, the fold over the upper lid, two shallow lines under the lower lid and four fine ones at the outer corner |
| Iris | a flat disc lighter at the middle, a grey pupil | fibres running out from the pupil, a lighter jagged ring round the pupil in its own colour (gold in the blue eye, amber in the green), darker pits, a dark rim fading into the white through a soft grey band; a black pupil (20 of 255 in the studio) with a small glint beside it |
| Whites | one off-white, shaded at the corners | a warmer, less bright white, pinker toward the corners, a few fine vessels, shaded under the upper lid; a pink caruncle at the inner corner; the outer corner in the skin's shade |

- **The eyes' shape** (`face.py`), measured against the reference photo:

| Measure (of the eye's width) | The photo | Attempt 1 | Now |
|---|---|---|---|
| Gap between the inner corners | about 1.0 | 1.52 | 1.03 (29.6 mm; the eyes 28.8 mm wide) |
| The opening's height | 0.33 | 0.29 | 0.33 (9.5 mm) |
| Iris | about 0.45 (anatomy 0.39) | 0.54 | 0.40 (11.6 mm) |
| Brow's lower edge over the upper lid | about 0.27 | 0.32 | 0.22 (6.3 mm) |
| Brow's thickness at its middle | about 0.27 | 0.13 | 0.21 (6.1 mm; the goggles' frame hides its top on the two helmets) |

  Attempt 1's column is the critic's, measured in its pictures; "now" is the model's own sizes, the brows measured
  in `mq3c-1-eyes-front.jpg`. FA1's eyes were 20 mm wide, a gap of nearly two eye widths.
  The upper lid rests 1.7 mm over the iris and the lower lid 0.4 mm (the old eyes stared: an 11.2 mm iris in a
  20 x 8 mm opening is a doll's).
- **Rounder lids, within the budget.** The lids are 20 sided at full detail (14 before), 21 to 24 on the denser
  heads (`LID_SEG_FULL`, `LID_SEG_GAIN`), paid for by the eyeball: a polar cap of four rings in place of five, and
  no triangle of it hidden behind the lids. So the owner did not have to be asked for a bigger budget.
- **Each eyeball draws from a patch of its own** under the strip (`face.EYE_PATCH`), at 1.15 times the scale, so
  the lids' paint no longer bleeds onto it (the white line along the lower lid). The skin's part keeps a flat copy
  of each eye for the lowest level.
- **Black pupils and a glint.** The grey pupil was not the eye: the goggles' lens was a pale tint (alpha 0.24) that
  laid a haze over everything behind it. The lens is now a thin dark tint (`splice_heads.LENS_TINT`, alpha 0.11:
  over Godot's 0.1, under which a lens stops shading the face). The map carries occlusion (the `Face` material reads
  it): the pupil and the lids' inner walls give no sky light back. The glint is a small mirror facet painted beside
  each pupil (the map's metal channel), on the same side of both eyes.
- **The four looks differ as people do**, not only in colour: brow width and hair count, freckles, how deep the fine
  lines are, how much the iris's fibres show.

Reference photos (owner's `ref_images.zip`, folder `figure`): `45243d77-4f0a-49ca-904b-409532d87a26.png` (eyes in a
balaclava's opening: low heavy brows of visible hairs, lids resting on the iris, the skin darker round the eyes;
the table's "photo" column) and `298750539_1772449736426341_6415112433916665141_n.jpg` (eyes behind goggles). They
show an eye about 25 pixels wide, so they set the proportions and the tone; the fine detail (hair, lashes, iris,
vessels) is drawn at its real size from anatomy, the sizes in `face_paint.py`'s constants.

Files: `tools/blender/figures/face_paint.py` (new), `face.py` (the map's layout, the looks, the eyes' shape and
their patches; its painter removed), `headkit.py` (`Atlas` of any size, with occlusion and metal; the noise helpers
moved here from `head_textures.py`), `head_textures.py`, `headwear.py`, `splice_heads.py` (the `Face` material on
its own images, its occlusion, the lens's tint), `game/config/figure_config.gd` (`face_offsets`),
`tools/model_studio.gd` (a shot can name a face look, `#hex@2`, and turn the model, `yaw,pitch,turn`),
`assets/models/characters/human.glb` and the extracted `human_face_*`, `human_headwear_*`,
`tests/unit/test_face_map.gd` (new), `tests/unit/test_mq3c_qa.gd` (QA), `tests/unit/test_figure_body.gd` (counts).

Pictures (before from main's file, after from this one, same camera): `art/model-quality/mq3c/` in the project
files, `mq3c-1-eyes-front.jpg` to `mq3c-5-side-and-far-levels.jpg`.

## Budgets

- Triangles: heads 8,988 / 8,968 / 8,984 / 8,960 at full detail (high cut, cap, boonie, full cut; budget 9,000),
  3,130 / 3,140 / 3,188 / 3,154 (3,200), 896 / 880 / 896 / 874 (900). The figure with the high cut: 59,058 /
  19,416 / 5,639 (budget 60,000).
- Materials: eight, as before (a test holds it). Textures: three more (2048 x 1024 colour and normal, the roughness
  map packed at 1024 x 512), all within the 2K rule; about 4.5 MB of video memory packed, once for all figures.
- Files: `human.glb` 17.4 MB (14.75 before, cap 20: the face's maps are stored without loss, as the atlas's are);
  the extracted maps 1.2, 1.1 and 0.4 MB.

## Decisions

- **The face is drawn as a real one** (owner's ask; `docs/DECISIONS.md` › Art direction): FA1's "stylised, clean"
  face is superseded.
- **The lenses are a thin dark tint** (`docs/DECISIONS.md`, same entry): it changes how all four heads' eyewear
  reads (clearer, a little darker), so the play checks ask the owner about it.
- **The eye is moist, not a mirror** (roughness 0.42; FA1's 0.10 is dropped): at 0.10 the studio's lamp panel
  reflected as a hard block on the iris and the eye wore a white rim in profile. The glint facet gives the
  catchlight instead, at any light.
- **Skin is dry** (roughness 0.6; under the lower lid and up the nose's side 0.9 with the pores nearly flat): at
  0.52 a lamp overhead lit single pores on those steep faces as streaks of white sparks.
- **No light is painted** but the hem's and the lids' own shade and the glint.
- **A hair is never finer than a pixel**: brow hairs and lashes are drawn 0.6 to 1 pixel wide with part cover, so they
  hold together when the map is packed and at the first smaller levels.
- **The skin's fine grain also moves the colour a little** (about 2 %): with nothing fine in it the packed map
  (S3TC) showed smooth tone as squares (MQ3B's lesson).
- **The lids' outer loop is placed where the carved skin lies** (`face.skin_s`), not by the head's azimuth: the
  skin round an eye is deeper than the head's surface, and the loop fell 2 mm short at the outer corner and folded
  under the lid (a pale wedge).
- **Studio pictures of a face front on** are taken level, with the figure turned 45 degrees and the camera with it:
  the studio's tall lamp panel otherwise reflects on each pupil, and from above the goggles' frame hides the brows.
- No wiki page describes the bots' faces or the lenses' tint, so no wiki change.

## Known issues

- The lids are 20 to 24 sided: at 6 cm across (closer than play shows) the corners are still a little angular.
- Lashes are painted on the lids, not standing off them: from the side they do not show.
- Under the inner corner the skin climbs steeply forward to the cheek; on the two darker looks a lamp straight
  overhead can still draw a faint thin line of light along that step. A gentler step needs the socket's shape
  redone under the hem.
- The brows' thickness is 0.21 of the eye's width against the photo's 0.27: thicker brows ran under the goggles'
  frame on the two helmets.

## Play checks

`docs/PLAYTEST.md` › Faces up close (MQ3C); the Dev 3 checklist has the same entry.
