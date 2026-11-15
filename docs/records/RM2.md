# RM2 · The Range's props rebuilt rounder, Woodland's woodpiles mixed

**Review:** 14 attempts · critic 7/8, accepted by the owner (William, 2026-11-15: "Don't try again. This model
is good so add it to the game.") · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the models rule (its report was not kept in the shared runs) |
| 2026-11-15 | 2 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the sandbags' proportions against photo 4 |
| 2026-11-15 | 3 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the sandbags' proportions against photo 4 |
| 2026-11-15 | 4 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the sandbag headers at a wall's end broke into hard planes |
| 2026-11-15 | 5 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the bags' outlines still polygons end on |
| 2026-11-15 | 6 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: split pieces stood on their points over the woodpile's top |
| 2026-11-15 | 7 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the spike rule could not fire; spikes stayed |
| 2026-11-15 | 8 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: a black slot ran up the woodpile's end corners |
| 2026-11-15 | 9 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the end logs were hard-faceted grey prisms |
| 2026-11-15 | 10 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the end logs' joints showed as flat tan flaps |
| 2026-11-15 | 11 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the end read as hexagonal planks or bricks |
| 2026-11-15 | 12 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: a straight line showed where two sections met |
| 2026-11-15 | 13 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the end read as boards and pipes, not split firewood |
| 2026-11-15 | 14 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: the end read as stacked blocks; owner accepted it (below) |

## Decisions

- **Shipped at the fourteenth woodpile pass, the owner's call.** The critic's attempt 14 was 7/8 (the end pieces still
  too straight); William ruled "Don't try again. This model is good so add it to the game." (2026-11-15), so the v14
  woodpiles ship as they are. A fifteenth pass begun before his word (pieces twisted and tapered) was dropped.
- **Asked for by the owner.** His yes to the Range's sandbags, toilet ribs and tote bars rebuilt rounder (AUD1,
  2026-11-14; `docs/DECISIONS.md`); AUD1's rebuild failed the models rule and stayed out (KNOWN_ISSUES). On
  2026-11-15 he asked for "the props rebuilt as needed" and, on the pictures ("Looks good"), for better stacks of wood
  logs too.
- **Built against his photos** (`reference.zip`, `art/references/maps/william-2026-11-09/`; Woodland's reference 13).
  The sandbag wall keeps four courses: his real wall's close-up (photo 4) and the two stacks (photos 3 and 5) give a
  bag 2.6 to 3 times as long as it stands on the face; at 0.225 m a course a 0.6 m bag is 2.67 times. (His first
  photo's long wall, about 5 times, would need six courses and 24 bags, past a prop's 5,000 triangles.)
- **The sandbags, bag by bag** (third and fourth passes, after the critic's attempts 2 and 3): each a filled sack laid flat, a pillow
  full in its belly and thinning to its ends, each end a flat seam 0.6 of the belly high whose corners stand out as
  ears, the seam's middle drawn in 2.6 cm; two bags end to end run 3 cm into each other and meet about 0.68 of their
  bellies high, a V between them (photo 4); the sacking lumped and creased in from the ears; 13 points round, the
  foot a flat chord; a tied corner on 60 % of a section's own bags' ends, its tail drooping along the face (a tail
  run out of the face was pressed flat against the model's box and drew black). Each bag's crown stands 4.5 cm under
  to 4 cm over its course's line, it falls up to 8 cm a metre along its length and leans up to 5 cm a metre, its
  widest line 0.36 to 0.43 of it up (slumped); it sits 2 to 4 cm into the lowest crown under it, so it never stands
  off one. The bed joints wander -17 to +24 % of a course; the bags run 0.49 to 0.74 m (2.2 to 3.3 times a course).
  Drawn smooth up to 100 degrees, so a seam's flat end and a header's end shade round, and the corners where a
  shared bag is cut take the whole bag's normals there (built whole once), so no line shows where it is cut.
- **The bond runs through every section's ends** (third pass): every course's two joints lie inside the section, so
  each course's bag over the +x end runs on into the next section, which carries the rest of it at its -x end (cut
  flush there, closed inside, one random stream a bag seeded by its place, so both parts are one bag; the cut ring
  is the bag's own profile there). Joints sit half a bag over the course under them and the two rows a quarter of a
  bag apart, each wandering up to 10 cm, drawn together until no two come nearer than 8 cm (two rows in a course),
  12 cm (a row over and under) or 6 cm (the other row over and under), and 4 cm from a section's end: a ray test
  square on, 15 degrees up or down and 20 degrees along finds no hole. Nothing ends flat at a section's end. The
  shared bags' bellies stand 3 mm past the wall's face, pressed flat there, so every model fills its box's depth.
- **Three main sections take turns** (`sandbags`, `sandbags_b`, `sandbags_c`, `PropDressConfig.variants`): they
  share the bags over their ends and differ in their own bags (height, tilt, lean, shade, tied corners: only a
  section's own bags are tied, so the knots never repeat every 1.2 m). A bag shared over an end sits on the lowest
  crowns of every section that may lie under it. PropLayout lays sandbags unturned (`grid_unturned`) and closes each
  wall with its own end models (`PropDressConfig.grid_ends`: `sandbags_start` at the -x end, `sandbags_end` at the
  +x end): in the 1st and 3rd courses a header 0.34 m wide (1.5 times a course) lies across the wall, the stretchers
  against it pressed full and 3.5 cm into it; in the 2nd and 4th, each row runs to the wall's end, a closing bag
  0.2 m or longer, else the bag by it longer. A closed line keeps one shade. A line one cell long takes `sandbags_single` (fifth pass, the third `grid_ends` entry), closed at both
  ends: headers at both ends of the 1st and 3rd courses, closing bags at both ends of the 2nd and 4th, its longest top
  bag a row standing to the top in place of the shared ones (falls back to `sandbags_start` when not loaded). A bag
  seen end on (a header, or a bag closing the wall's end: sixth pass) has 20 points over its crown from ear to ear
  (the others 9), so its outline is round at 1 m; its end there a pillow's (its rings each inside the next towards
  the belly, so no flat seam's ring stands out past the belly as a corner), closed by a low dome 4 cm out at its
  middle; it pays with three stations an end, not four, and no belly station under 0.62 m. A bag laid on a header
  sits down on its rounded sides (its top falls away to half its height at its edges), so no light shows between
  them. 4,538 / 4,484 / 4,700 / 4,922 / 4,760 / 4,712 triangles.
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
  tans with a brown added, and (third pass) every end colour 14 % darker, as the photo's warm brown at eye height
  (their hue is already at the team-hue limit, 37° linear, so warmer means deeper, not more orange; each nudged back
  to 37 to 38°). The stack's ends (third and fourth passes): the end pieces' own round bark sides, each its own:
  set up to 3.5 cm further in, bulging 45 to 100 % of 6 cm out of the dark end (a pale split side 15 % of the time,
  flatter), a wedge's edge or a flatter face, uneven, twisting up to 15° and narrowing or swelling along it, starting
  out with the face's sawn ends (1.2 cm past the core) or up to 1.8 cm in, and stopping short of the middle or running
  up to 12 cm past it, so the front and back halves stagger; one bark a log with a darker streak here and there, 6
  facets round, drawn smooth. The core's top stops at the end (no slab over it); no loose pieces on top (they read as
  planks along the top edge); a piece cut at the section's end shows bark on its cut side, not a pale strip. The sawn
  ends (fourth pass): a darker heart at each wedge's point (`EndHeart`, 0.3 of the way to its bark) and more drying
  checks (a third of the pieces have one or more, was 30 %); to pay for them the bark arcs step 28°, not 24°, and a
  section draws as many hearts as its 3,200 triangles leave room for (built once with all, then again with that share;
  the hearts draw from a stream of their own, so the pieces stay put). Fifth pass: hearts reach 0.45 of the way to the bark
  (were 0.3); a piece cut at the section's end stands flush. Sixth and seventh passes (the critic's attempts 5
  and 6): the stack's top the top course's logs lying front to back, each its own width (0.5 to 1.5 of 13 cm), a
  few askew, each its own bark, full-shouldered across and rising up to 0.22 of its width between the faces to a
  crown off its middle here and there (at the faces they meet the core's sides, so no slit), a crease between them
  (was a near-black lid, then strips that read as roofing); the core's top read at the face pieces' tops (was 2 cm
  under) from three points about each column and, at the ends, every piece out to the end; a face piece standing
  more than 4 cm over it (a wedge on its point) is taken off and the top read again; one still over it has a bark
  back and its upper sides. The end logs are round (one bark each, drawn smooth under 45 degrees, was 34), each
  closed by its sawn end at the face and the stack's dark inside, never past the core's face, 0.44 to 0.5 of the
  depth long so no edge runs further, their inner ends up to 2.5 cm higher or lower so the joints slant, widened to
  meet the next from the ground up, a thin one taken into the one under it, the top one up to the crest (no
  notch); none pale split (read as planks). Paid for: bark arcs in 34 degree steps (were 28), end logs 5 facets
  round (were 6), fewer drying checks (a quarter of the pieces, was a third), no rim of bark on a piece under
  8.5 cm (a hairline) and, in section A, a dark heart on about two thirds of the wedges. Eighth pass (the critic's
  attempt 7): the top line near level (at most 10 cm under the cell's top, 5 cm from one of nine points to the next;
  was up to 45 cm); the face's crown read every 2 cm and opened over 10 cm each way, and a piece standing more than
  4 cm over that cut level there (a point broken off, its end plain) or taken off when less than 0.45 of it is left,
  so nothing stands up out of the top and no hole opens; a notch narrower than 16 cm bridged by the top's pieces. Ninth
  pass (the critic's attempt 8): the face's pieces stop 12 cm short of each end (none cut there, so no card shows edge
  on); the end courses of logs the face's pieces' size (11.5 to 15 cm high, 12 to 15 a column), each course a front
  and a back log lying front to back and meeting in front of or behind the middle by turns (8 to 30 % of the way to a
  face), drawn in to 0.7 where they meet, each its own bark with a darker furrow beside a crease, one closed shell
  with the end's dark behind it (no middle panel, no straight dark slot); each log closed at its face by its sawn end
  (a bark rim round a sawn face, the flat side split, drawn in to the face's last piece), so every corner shows a
  column of log ends and no dark seam; the core's sides stop at the end (no flap). The top two rows of pieces meeting
  along a wandering line about the middle, each row's joints its own, 0.5 to 1.5 of 16 cm wide: four in ten point up
  (two pale split faces meeting at a ridge, 0.22 to 0.32 of their width high), the rest bark up and rounded (up to 0.4
  of their width, dark barks never the same as the one beside); each the same along its length and closed at both
  ends by a sawn end, its face end at the core's face, behind the face's pieces (no lip); three in ten stop 10 to 20
  cm short of their face over a paler piece's back. Paid for: the core's top read at 20 places (were 30) and fewer
  drying checks (22 %). Tenth pass (the critic's attempt 9): the end logs round (4 segments a side, every edge
  between them drawn smooth, so no facet steps); each course tilted 1 to 3 degrees front to back by turns (the ground
  course level), each log set in 0 to 5 cm its own way, so the end is ragged; at the joint the fuller log shows its
  sawn end and the other is drawn in a fifth, a real step; half the logs show a pale split side between barked edges;
  the end bark warm grey-brown (no neutral grey); each log's sawn end a half round of 8 sides with a bark rim 14 % of
  its radius, flush with the face's sawn ends (drawn in to the face's last piece, at most 7 cm). The top: one set of
  edges across the depth, each turned up to 10 degrees (at least 4 cm apart at the faces); a third of the pieces the
  whole depth long, the rest two meeting 0 to 40 % off the middle; ridge pieces solid wedges closed by sawn ends
  (none in the end columns, where the pieces are lower), bark pieces 0.4 to 1.1 of their full rise. Paid for: each
  core side one polygon, fewer drying checks (15 %) and fewer hearts. Eleventh pass (the critic's attempt 10): the
  end's pieces are split wood, not pipes, each its own kind (a quarter round logs, bark all round and smooth; a
  third logs split down one side, a flat pale face out between bark edges; a quarter wedges point out, two flat split
  faces; the rest quarters, a split face and a bark round), split faces crisp, bark a warmer grey-brown (`EndBark`,
  `EndBarkDark`, `EndBarkLight`, just off Beta orange's hue); each course lies on the one under it (the lines between
  courses tilted 1 to 3 degrees, so no course stands into the next and no slot opens under one at a face); the front
  and back pieces meet 1 to 3 cm apart, each closed there by its own sawn end (a round log's a half round of 8 sides
  with a bark rim); each piece's sawn end at the face lies in the face's plane, just behind the face's pieces, drawn in
  to the face's nearest piece at its foot, middle and top (up to 16 cm), so no straight dark seam runs up a corner;
  the end's top piece stands 3 cm over the crest, its inside closed, and the top's end pieces lie low under it. The
  top: pieces 0.45 to 1.6 of 16 cm wide, turned up to 12 degrees; none stops short of a face (no flat backs showing);
  two or three pieces lie over the course turned 20 to 40 degrees. 3,193 / 3,189 / 3,044 triangles (hearts on about
  a fifth of the wedges in A and B, all in C): Woodland draws no more. Twelfth pass (the critic's attempt 11): a
  stack's middle sections are cut flush at both ends, their face pieces clipped at the cut (one paint, square on), so
  a join reads as one stack; only its first and last sections (`cordwood_start`, `cordwood_end`, and
  `cordwood_single` for a one-section stack, through `grid_ends`; woodpiles are now laid unturned) have end courses.
  A piece cut at a section's end keeps its own kind, paint and bark rim, the rim and its side along the cut drawn
  flush, so the two sections' pieces meet as pieces do. The end courses are 8 to 20 cm high, each set in or out up to
  4 cm and turned up to 8 degrees from above, sharing their lines so no two overlap; one piece in four is a long one,
  a log split down one side pushed 10 to 15 cm out with its bark top and foot running out to its split face (long
  wedges read as pale blades and slabs from above); a wedge's point stands out at most 1.3 of its course's half
  height (`END_WEDGE`); every split face has a crease; a chip under 7.5 cm near a closed end is dropped; the end's
  top piece no longer stands over the crest. The top's pieces lie apart (1.5 to 3 cm) about a third of the time and
  a fifth ride half on a neighbour; the crossing pieces stay inside the end courses. 2,915 / 2,844 / 2,585 triangles
  the middle sections, 2,791 / 2,924 / 2,974 the end ones, all hearts drawn. Thirteenth pass (the critic's attempt
  12): the joins share their pieces. One column of face pieces stands across every join (`join_column`, seeded by
  `JOIN_SEED` alone, so it is the same in every section, each piece 30 to 70 % of its width either side, drawn the
  same way in both: paint, depth, tilt, heart); each section draws its part of each (`piece_end`'s clip) and lays its
  own pieces round them, so the two halves meet as one whole piece and the join runs piece by piece; one top piece
  lies across each join the same way, and the core's top meets at the join column's crown. No slice, no rim along a
  cut. A face piece's split sides are a shaded tan (`SplitSide`), so none shows as a pale sliver edge on. The end
  courses are 10 to 20 cm high; their long pieces (one in five) are round logs pushed 10 to 15 cm out (their run
  back dark, a round sawn end with a bark rim on it), the top course round logs; a round log's sides have 5
  segments (were 4), a log split down one side two bark steps a side, half the wedges one bark side, every split face
  creased 2.5 cm. The top: no two neighbouring columns lie point up. Every section is stretched to its box alike
  (QA's attempt 13: each was stretched by its own bounds, so the shared pieces missed by 1 to 2 cm): a piece stands
  at most 5 cm out, and four specks facing down under the stack's foot corners and one over its top (1.5 mm, `PIN`,
  `TOP_PIN` 1.83 m) pin every section's bounds to the same box. A new test checks every pair of sections meets at
  its join (`test_woodpile_sections_meet_piece_by_piece_at_every_join`, failing on the twelfth pass's models).
  3,142 / 3,073 / 2,890 the middle sections, 3,046 / 3,196 / 3,180 the end ones (hearts thinned to fit).
- **Fourteenth woodpile pass (critic attempt 13: the end read as boards and pipes):** the end courses are split
  pieces like the face's: a log split down one side (at most 6 cm of split face, `END_SPLIT_W`), wedges (three in four
  with a bark back), quarters, and a whole round log at most one course in two. Each piece is drawn through a middle
  profile of its own (a little fuller or slimmer, its creases moved), so no split face is one plane its whole length;
  a third of them stand 2 to 5 cm past the face (`END_STICK`), so the ends are not flush; their long split faces are
  mostly a weathered mid tan (`EndSplit` #9C8C62), a few fresh. The top course is bark up, rounded in four steps and
  closed (4 mm between its front and back pieces), and the top pieces beside an end are round logs in the end's warm
  bark, bedded down a little (`TOP_BED`), not flat grey boards. Round sawn ends have 10 sides; the long round logs
  (and the stubs they made at the single section's sides) are gone. 3,142 / 3,073 / 2,890 the middle sections
  (unchanged), 3,185 / 3,199 / 3,189 the end ones.
- **Picture tools:** `prop_pictures.gd` draws each model at its own roughness; `woodland_pictures.gd` has the west
  camp's woodpile (`woodpile_near`, `woodpile_along`); `range_pictures.gd` (new) shows the Range's props in the game.
  Pictures: `art/blender/range-rm2/` in the shared files (v1 the first pass, v2 the second, v3 the third, v4 the
  fourth, v5 the fifth, v6 the sixth, v7 the seventh, v8 the eighth, v9 the ninth, v10 the tenth, v11 the eleventh, v12 the twelfth, v13 the thirteenth and v14 the
  fourteenth: the woodpiles).

## Known issues left

- The Range's props still carry no weave or grain texture (KNOWN_ISSUES row updated).
