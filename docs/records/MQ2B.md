# MQ2B · Bombs and power sources made of what the real ones are

**Review:** 3 attempts · critic PENDING · qa PENDING · performance PENDING

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | ✓ (after a prewarm count fix) | Retry 7/8 | the first-person pictures hardly differed, the print read as a ruler, the lever's ribs as slots and its bend as a mirror, the gas bottle's shoulder was short and its label nearly empty |
| 2026-11-12 | 2 | Fable 5.2 (model quality thread) | QA's nine files 75 of 75 (the full gate was stopped when the verdict came) | Retry 7/8 | the smoke lever's beads read as slits and its arm as three boxes, the gas bottle's emblem was stair-stepped and its mark a letter H, the gas bottle's proportions were off the photo, the flash's word was hidden at rest |
| 2026-11-12 | 3 | Fable 5.2 (model quality thread) | PENDING | PENDING | – |

## What changed

Owner, 2026-11-12: "Also go over all the attachment and accessory models and improve their quality and make them look
more realistic and detailed." MQ2 did the parts fitted to a replica; this is the rest of the accessories: the smoke
and flash bombs and the four power sources' menu pictures.

Each file now names what its materials are made of (the `surfaces` table MQ2 gave the parts), and the bomb in your
hand and the menus' pictures draw them on those surfaces in their own colours:

| Model | Made of |
|---|---|
| Smoke bomb | a glossy printed film sleeve, a moulded cap and foot, a lever in matte black paint, dark steel wire |
| Flash bomb | a matte card tube, a paper band and cap |
| Gas bottle | an aluminium can and its print under a baked coat |
| LiPo and Standard Battery | glossy shrink film, paper stickers, matte leads, moulded plugs |
| Spring | painted steel wire |

- **A new kind, `card`** (index 8, after `polished`; the order of `KINDS` is unchanged): card and paper in their own
  colour, dead matte with a fine tooth. Nothing else is as dull as a wound card tube.
- **New detail, against the owner's photos** (`ref_images.zip` › `grenades/`, `gas_bottle/`, `11.1v_lipo_battery/`):
  the real ones are covered in print, and the models' labels were blank. They now carry print where the photos
  have it, never letters, logos or symbols: a word is a row of bold stencil glyphs, each a few bars that spell
  nothing (`GLYPHS_ROUND`, `GLYPHS_UP` in `grenades.py`), and small print is lines and blocks, as the Standard
  Battery's stickers have had since BL7. The print sits where your hand leaves the bomb in view.
  - *Smoke bomb* (5,282 triangles of 5,500): under your thumb a word in the smoke's own colour (the photos' "SMOKE
    / RED" line is in the smoke's colour) and a second in pale grey; above them two maker's blocks, a heavy line
    and a fine one; a line at the foot; beside the lever (the side the menus' picture sees) a block and three lines
    of small print. The lever's arm is one plain sheet (its nicks are on its two edges only; they were grooves
    right across it, which made it three boxes) with three pressed beads down it, each one smooth swell six tenths
    of the arm's width and 1.3 mm proud, running out to nothing; the lever is matte black paint, not bare steel.
  - *Flash bomb* (5,308 of 5,500): a pale band under the cap's coloured one, as the photos'; running up the tube
    beside the ring a five-glyph word that ends just under that band, so its last glyphs show over your thumb
    at rest, a block of the bomb's own colour and a maker's square at its foot and a line of small print beside
    it; next to the ring a column of seven square pictogram tiles; on the side the
    menus' picture sees three lines of small print and a square of the bomb's colour; on the cap six vents round
    the hole (the photos' perforated cap) and six pale printed ticks between them.
  - *Gas bottle* (4,688 of 6,000, 117 KB of 120): its cap, shoulder and print are fitted to the main photo by
    measuring both pictures row by row (the table below); under the chevron the label is filled as the photo's
    is: a round emblem (a pale ring round a disc of the gas's colour, 32 points round, laid on the can's curve), a
    heavy mark of three slanted bars, a bar of the gas's colour, three bulleted lines, a paragraph of fine lines
    and a pale caution panel with a block of the gas's colour and two dark lines; the pale band at the foot
    starts on the rolled corner.

    | Of the can's height, but the first two | Photo | Model | Before MQ2B |
    |---|---|---|---|
    | Height to width | 4.2 at the top, 4.7 at the foot (the photo narrows 11 % down its length) | 4.55 | 4.55 |
    | Cap's width to the body's | 0.539 | 0.541 | 0.563 |
    | Cap, top to its skirt's foot | 0.150 | 0.148 | 0.136 |
    | Shoulder, skirt's foot to 99 % of the width | 0.100 | 0.103 | 0.089 |
    | Solid print ends, from the top | 0.328 | 0.330 | 0.304 |

    The shoulder's curve was fitted at seven heights (the photo's width there against the model's: 0.624 / 0.628,
    0.712 / 0.703, 0.798 / 0.790, 0.868 / 0.862, 0.925 / 0.919, 0.962 / 0.961, 0.984 / 0.983 of the body).
  - *LiPo* (3,012 of 6,000, 91 KB): a heading and three lines in white and a red caution block with a white bar.
  - *Standard Battery* (2,858 of 6,000, 68 KB): a yellow caution sticker with three dark bars by its lead end, as
    real packs carry, beside the two it had.
  - The spring (5,764, at its budget) changes in what it is made of only.
- **In the game.** `ReplicaPaint.own_surface` draws one of a model's own materials on a kind's surface: a new one
  each call, the caller's to keep, never in the store the replicas' paints share (a picture's or a view's own paint
  would stay there after it, and the round's prewarm counts that store).
  `GrenadeView` uses it for the bomb in your hand (its depth pressed by the shader's own uniform, as the replica's
  is); `ReplicaPictures` for the bombs' and power sources' pictures, the `Label` and `Kind` materials still painted
  in the item's colour. A bomb thrown, lying or in a figure's hand stays plain, as the figures' replicas do.
- **Tests** (`tests/unit/test_accessory_surfaces.gd`): `card` after the others; the table above; each file names
  only its own materials, kinds the game knows and no other custom property; the bomb in hand on its surfaces in
  its own colours, depth pressed; thrown and lying plain; the surfaced materials reach the prewarm once each; the
  menu pictures on their surfaces with the label's colour; `own_surface` leaves glass alone and keeps what it
  builds out of the shared store. `test_grenade_arms.gd`'s depth check reads a surfaced material's uniform.
- **Docs:** `docs/CC0_ASSETS.md` (Surfaces, Power-source models, Grenade models), `docs/ART.md`, `docs/ASSETS.md`,
  `docs/PLAYTEST.md` › What the bombs and power sources are made of (MQ2B), the wiki's Grenades page.
- **Pictures:** `art/model-quality/mq2b/` in the project files: each model alone before and after, and each bomb in
  first person; the `mq2b-pass2` sheets show the second attempt and the `mq2b-pass3` sheets the third (the bombs
  alone, in your hand, the gas bottle and its label close up, each model beside the owner's photo at the same
  angle and the smoke's lever close up, before and after).

## Decisions

- **The smoke's lever is drawn as matte paint (`polymer`), not `steel` or `coated`** (default, attempt 2): real
  spoons are sheet steel under a matte black finish. Both metal kinds mirrored the sky off the flat bend at the
  lever's top as a white patch (the critic's finding); the matte film is what the eye sees of it.
- **The gas bottle is measured, not judged by eye** (default, attempt 3): the first two verdicts gave the shoulder
  as too short and then too tall, from ratios read off the picture by eye. The photo and a flat picture of the
  model are now measured by the same script, row by row (the cap's foot is where the width first passes the cap's
  by 5 %, the shoulder's end where it reaches 99 % of the body's), and the table above is its output.
- **The lever's nicks are on its edges only** (default, attempt 3): the photo shows them from the side, as V cuts
  in the two flanges' edges. Cut across the web as well they split the arm into three boxes.
- **The emblem and the mark are laid on the can's curve, not on its facets** (default, attempt 3): a round outline
  on the facet grid was stair-stepped. Each is cut into columns at the can's own facets and stands 0.08 mm proud.
- **Glyphs, not letters** (default, attempt 2): the critic found the first print read as a ruler and a dashed
  line. A label needs words to read as a label, and the rule is no letters, so a word is stencil glyphs that spell
  nothing in any alphabet's order.
- **The hard line down the flash tube in the studio pictures is the studio lamp's shadow edge**, not the model: the
  before pictures, in flat paint, show the same line (`mq2b-pass2` sheets). The tube's 64 sides are smooth shaded.
- **The bright wire stays as the file has it** (default): the smoke's rivet and the flash's key ring are under a
  millimetre thick, and the `polished` kind's mirror on them sparkled in the hand. They were already metal.
- **The bomb in your hand takes shadows as the replica does** (default): the surface shader has no unshadowed
  variant and the replica it was written for takes them. The arms beside it still take none (BL4). A play check
  covers a hard patch crossing the bomb.
- **Leads are `polymer`, not `rubber`** (default): the rubber kind's coarse grain read as a braided sleeve on a wire.
- **Print as blocks, no letters** (default): the files stay unbranded (BL9's rule), and the Standard Battery's
  stickers set the house way of doing it.
- **Budgets unchanged** (default): 5,500 triangles a bomb, 6,000 and 120 KB a power source. The detail was chosen
  to fit: flat print on the models' own facets costs two triangles a facet.
- **Thrown bombs stay plain** (default): seen from metres off, drawn by the dozen, and the figures' replicas set the
  rule.

## Known issues left

- The spring's wire is four-sided (its budget is full at 40 turns); it reads round at the menu's size.
