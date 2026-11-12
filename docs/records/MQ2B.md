# MQ2B · Bombs and power sources made of what the real ones are

**Review:** 1 attempt · critic PENDING · qa PENDING · performance PENDING

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | PENDING | PENDING | – |

## What changed

Owner, 2026-11-12: "Also go over all the attachment and accessory models and improve their quality and make them look
more realistic and detailed." MQ2 did the parts fitted to a replica; this is the rest of the accessories: the smoke
and flash bombs and the four power sources' menu pictures.

Each file now names what its materials are made of (the `surfaces` table MQ2 gave the parts), and the bomb in your
hand and the menus' pictures draw them on those surfaces in their own colours:

| Model | Made of |
|---|---|
| Smoke bomb | a glossy printed film sleeve, a moulded cap and foot, a sheet steel lever, dark steel wire |
| Flash bomb | a matte card tube, a paper band and cap |
| Gas bottle | an aluminium can and its print under a baked coat |
| LiPo and Standard Battery | glossy shrink film, paper stickers, matte leads, moulded plugs |
| Spring | painted steel wire |

- **A new kind, `card`** (index 8, after `polished`; the order of `KINDS` is unchanged): card and paper in their own
  colour, dead matte with a fine tooth. Nothing else is as dull as a wound card tube.
- **New detail, against the owner's photos** (`ref_images.zip` › `grenades/`, `gas_bottle/`, `11.1v_lipo_battery/`):
  the real ones are covered in print, and the models' labels were blank. They now carry print as blocks and bars
  where the photos have words, never letters, logos or symbols, as the Standard Battery's stickers have had since BL7.
  - *Smoke bomb* (5,488 triangles of 5,500): a small heading, two heavy lines and a third in the smoke's own colour
    (the photos' "SMOKE / RED" line is in the smoke's colour), a fine line at the foot, and beside the lever (the
    side the menus' picture sees) a block and three lines of small print; three short pressed ribs down the lever's
    arm, between its edge notches.
  - *Flash bomb* (5,196 of 5,500): running up the tube as the photos' label does, a block in the bomb's own colour,
    a long pale one and a row of eight small squares where the photos have their pictograms, and on the side the
    menus' picture sees three lines of small print and a square of the bomb's colour; six vents round the hole in
    the cap (the photos' perforated cap).
  - *Gas bottle* (4,402 of 6,000, 105 KB of 120): under the chevron a heading block in the gas's colour, four lines
    and a pale caution panel with a block of the gas's colour in it.
  - *LiPo* (3,012 of 6,000, 91 KB): a heading and three lines in white and a red caution block with a white bar.
  - *Standard Battery* (2,858 of 6,000, 68 KB): a yellow caution sticker with three dark bars by its lead end, as
    real packs carry, beside the two it had.
  - The spring (5,764, at its budget) changes in what it is made of only.
- **In the game.** `ReplicaPaint.own_surface` draws one of a model's own materials on a kind's surface.
  `GrenadeView` uses it for the bomb in your hand (its depth pressed by the shader's own uniform, as the replica's
  is); `ReplicaPictures` for the bombs' and power sources' pictures, the `Label` and `Kind` materials still painted
  in the item's colour. A bomb thrown, lying or in a figure's hand stays plain, as the figures' replicas do.
- **Tests** (`tests/unit/test_accessory_surfaces.gd`): `card` after the others; the table above; each file names
  only its own materials, kinds the game knows and no other custom property; the bomb in hand on its surfaces in
  its own colours, depth pressed; thrown and lying plain; the surfaced materials reach the prewarm once each; the
  menu pictures on their surfaces with the label's colour; `own_surface` leaves glass alone and shares what it
  builds. `test_grenade_arms.gd`'s depth check reads a surfaced material's uniform.
- **Docs:** `docs/CC0_ASSETS.md` (Surfaces, Power-source models, Grenade models), `docs/ART.md`, `docs/ASSETS.md`,
  `docs/PLAYTEST.md` › What the bombs and power sources are made of (MQ2B), the wiki's Grenades page.
- **Pictures:** `art/model-quality/mq2b/` in the project files: each model alone before and after, and each bomb in
  first person.

## Decisions

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
