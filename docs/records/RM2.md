# RM2 · The Range's props rebuilt rounder, Woodland's woodpiles mixed

**Review:** REVIEW_LINE

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
ATTEMPT_ROWS

## Decisions

- **Asked for by the owner.** His yes to the Range's sandbags, toilet ribs and tote bars rebuilt rounder (AUD1, 2026-11-14;
  `docs/DECISIONS.md`); AUD1's rebuild failed the models rule and stayed out (KNOWN_ISSUES). On 2026-11-15 he asked
  for "the props rebuilt as needed" and, on the pictures ("Looks good"), for better stacks of wood logs too.
- **Built against his photos** (`reference.zip`, `art/references/maps/william-2026-11-09/`; Woodland's reference 13).
  The sandbag wall keeps four courses: his real wall's close-up (photo 4) and the two stacks (photos 3 and 5) give a
  bag 2.6 to 3 times as long as it stands on the face; at 0.225 m a course a 0.6 m bag is 2.67 times. (His first
  photo's long wall, about 5 times, would need six courses and 24 bags, past a prop's 5,000 triangles.)
- **The sandbags, bag by bag:** each a loaf 16 points round (15 on its sides and crown, one under it), flatter where it
  sits, its sides lumped up to 7 mm in two soft waves of its own; bedded 3 cm into the course below; the bags end to
  end in a course 6 cm into each other, the two rows' joints 10 cm apart so no crease runs straight through; one end
  a flat sewn seam, the other folded under or, on the bags laid across, gathered to a round neck (16 points) bound
  with cord and a frayed tuft standing 4 cm proud. 4,864 triangles (was 2,304).
- **Creases baked in** (`range_kit.occlude`): Cycles' ambient occlusion baked to the corners, 0.6 of the colour kept at
  most shut in for the sandbags, 0.5 the toilet, 0.45 the tote; the lowest 12 cm of the wall a little darker (soil).
  The cord is a dull weathered jute (`807868`, was `8a7a5a`): darkened, the old one's 8-bit colours came within 20°
  of Beta's orange.
- **The sacking is matt:** `PropDressConfig.model_roughness` sandbags 0.97, as `SiteLook`'s fabric; one more prop
  material on the Range.
- **The toilet's ribs** are moulded swooshes 0.2 m tall and 35 mm proud, a steep lower edge and a long slope back,
  running out into the wall by the corner posts (photo 1); the door's two swoops in the door's colour; the roof a
  dome of nine rings with a rolled rim; the round boss low on each side, which the lowest rib crossed, is gone (photo
  1 has none). 4,698 triangles (was 1,926).
- **The tote's cage** tubes 10 sides (the frame 12), the rows welded outside the uprights (two equal tubes crossing in
  one plane showed a black point where their faces met); the tank's corners rounded in 6 steps and bellied 6 mm; the
  pallet's and plate's edges chamfered 4 mm. 4,828 triangles (was 1,372).
- **The woodpiles** (`cordwood.py`): wedges from 55 to 125° at the heart (were 75 to 100), a tenth half logs, 7 % small
  rounds (were 3 %), 30 % free to lie on their side (were 12 %) and up to 24° off square (were 14°), each 0.68 to 1 of
  a row high (were 0.86 to 1), so the rows of scales break up; a piece may run up to 35 % of its width past the
  section's end, cut flush there and drawn as a sawn face without a bark rim, so no dark seam runs up a stack where two
  sections meet; the stack's ends in bark of every shade and pale split sides, rows of uneven height. The same 3,200
  triangles a section (the bark arcs in 4 segments, were 5): Woodland draws no more.
- **Picture tools:** `prop_pictures.gd` draws each model at its own roughness; `woodland_pictures.gd` has the west
  camp's woodpile (`woodpile_near`, `woodpile_along`). Pictures: `art/blender/range-rm2/` in the shared files.

## Known issues left

- The Range's props still carry no weave or grain texture (KNOWN_ISSUES row updated).
