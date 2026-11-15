# RM2 · The Range's props rebuilt rounder, Woodland's woodpiles mixed

**Review:** REVIEW_LINE

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
ATTEMPT_ROWS

## Decisions

- **Asked for by the owner.** His yes to the Range's sandbags, toilet ribs and tote bars rebuilt rounder (AUD1,
  2026-11-14; `docs/DECISIONS.md`); AUD1's rebuild failed the models rule and stayed out (KNOWN_ISSUES). On
  2026-11-15 he asked for "the props rebuilt as needed" and, on the pictures ("Looks good"), for better stacks of wood
  logs too.
- **Built against his photos** (`reference.zip`, `art/references/maps/william-2026-11-09/`; Woodland's reference 13).
  The sandbag wall keeps four courses: his real wall's close-up (photo 4) and the two stacks (photos 3 and 5) give a
  bag 2.6 to 3 times as long as it stands on the face; at 0.225 m a course a 0.6 m bag is 2.67 times. (His first
  photo's long wall, about 5 times, would need six courses and 24 bags, past a prop's 5,000 triangles.)
- **The sandbags, bag by bag** (second pass, after the critic's attempt 1): each a filled sack laid flat, a pillow
  full in its belly and thinning to its ends, each end a flat seam about 0.3 of the belly high whose corners stand
  out as ears, the seam's middle drawn in 2.6 cm; the sacking lumped and creased in from the ears; 14 points round;
  a tied corner on 55 % of the ends inside a section (a tail gathered on the ear on the wall's face, bound with cord,
  frayed). Bags inside a section run 5 cm into each other; each bag's height, bed (2 to 4 cm into the bags under it)
  and lean are its own, so the bed joints wander.
- **The sections lock into each other:** the 2nd and 4th courses' bag over the section's +x end runs on into the
  next section, which carries the rest of the same bag at its -x end (one random stream a bag, seeded by its place,
  so both parts are one bag; cut flush, closed flat inside); the 1st and 3rd courses end at the section's ends,
  pressed full against the next section's bags so no light shows. The cut bags' corners take one colour, the mean of
  both sides' bakes, and the AO is baked with the neighbouring sections beside it. PropLayout lays sandbags unturned
  (`grid_unturned`) and closes each wall with its own end models (`PropDressConfig.grid_ends`: `sandbags_start` at
  the -x end, `sandbags_end` at the +x end, a header 0.34 m wide across the wall in the running-on courses, the bags
  there pinched and eared, not pressed); a closed line keeps one shade. A line one cell long would take the start
  model (none exists). 4,800 / 4,740 / 4,632 triangles.
- **Each bag keeps one shade of its own** (`range_kit.tint`, a paint `name~k`), not bake's random shade per piece,
  so the two parts of a split bag match; the tops a little paler (sun).
- **Creases baked in** (`range_kit.occlude`): Cycles' ambient occlusion baked to the corners, 0.6 of the colour kept at
  most shut in for the sandbags, 0.5 the toilet, 0.45 the tote; the lowest 12 cm of the wall a little darker (soil).
  The cord is a dull weathered jute (`807868`, was `8a7a5a`): darkened, the old one's 8-bit colours came within 20°
  of Beta's orange.
- **The sacking is matt:** `PropDressConfig.model_roughness` sandbags and its two end models 0.97, as `SiteLook`'s
  fabric; one more prop material on the Range.
- **The toilet:** the side and back panels laid 2.5 cm out over the shell, moulded with scoops pressed in (photo 1),
  each a crescent deepest just under its upper edge (a shadow line along the top), its tips eased out well short of
  the posts, so no rib end meets a post; the door's raised panel the same with two shallower ones; the round boss low
  on each side is gone (photo 1 has none). The roof a firm moulding: a square-edged 8 cm lip all round, a crisp
  shoulder, a quarter-ellipse dome. 4,636 triangles (was 1,926).
- **The tote:** the valve back in a recess moulded into the tank's foot (0.22 m wide, 7.5 cm deep), wholly behind the
  cage's front and under its lowest row (a real IBC's valve sits so); the cage's top and bottom frames bent round at
  the corners (5 cm), the corner posts bent into them; the rows 13.5 mm, thicker than the uprights, welded outside
  them and run round the corners; the tank's corners rounded in 6 steps and bellied 6 mm; the water's line through the
  milky tank at 0.74 m (`tank_water`, grey, no team hue), which reads from 10 m. 4,662 triangles (was 1,372).
- **The woodpiles** (`cordwood.py`): wedges from 55 to 125° at the heart (were 75 to 100), a tenth half logs, 7 % small
  rounds (were 3 %), 30 % free to lie on their side (were 12 %) and up to 24° off square (were 14°), each 0.68 to 1 of
  a row high (were 0.86 to 1), so the rows of scales break up; no square heart pieces; a piece may run up to 35 % of
  its width past the section's end, cut flush there and drawn as a sawn face without a bark rim, so no dark seam runs
  up a stack where two sections meet; each bark arc in about 24° steps (3 to 6); the sawn ends weighted to the deep
  tans with a brown added (their hue is already at the team-hue limit, 37° linear, so warmer means deeper, not more
  orange); the stack's ends built from the end pieces' own round bark sides (a pale split side 15 % of the time),
  from the face to the middle, set 5 cm in, the dark of the stack between. The same 3,200 triangles a section
  (3,164 / 3,011 / 3,024): Woodland draws no more.
- **Picture tools:** `prop_pictures.gd` draws each model at its own roughness; `woodland_pictures.gd` has the west
  camp's woodpile (`woodpile_near`, `woodpile_along`); `range_pictures.gd` (new) shows the Range's props in the game.
  Pictures: `art/blender/range-rm2/` in the shared files (v1 the first pass, v2 the second).

## Known issues left

- The Range's props still carry no weave or grain texture (KNOWN_ISSUES row updated).
