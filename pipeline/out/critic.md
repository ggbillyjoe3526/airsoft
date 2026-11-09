Task: WT1 · Woodland's trees from the owner's photos (no TASKS.md block: judged against the brief and the model list rows 01, 02, 03, 09, 22)
Attempt: 1 of 4
Head: 9b43306 (check.sh still running, no passed head given; working tree dirty: oak.py, treekit.py, oak.glb modified, changelog note untracked). QA and performance reports for WT1 missing (pipeline/out holds FL1's): Retry whatever the score.
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 6/8 → Retry
Failed checks, with evidence:
1. [measured] Ratios, photo → front render (limit 10 %):
   Oak (02/130609 vs oak_front): overall width/height 1.50 → 1.12 (-25 %); crown edge over ground / height 0.14 → 0.35 (+150 %); bole to first split / height 0.24 → 0.34 (+40 %). oak_foot.png: a plain cylinder, no roots at the foot (model list row 2 asks for them).
   Old pine (01/130505): width/height ~0.40 → 0.73 (+80 %); crown depth 0.50 → 0.35 (-30 %); clear bole 0.50 → 0.65 (+30 %): reads as an umbrella pine or acacia, not a Scots pine.
   Young pine (01/130448): foliage depth 0.85 → 0.50 (-41 %); width/height 0.31 → 0.52 (+66 %): a round lollipop of blobs, not the photo's open whorls of long upright tufts.
   Grown pine (01/130430): width/height 0.39 → 0.42 (ok), crown depth 0.78 → 0.70 (-10 %, edge), but the crown is regular tiers of flat hexagonal pads on bare twigs, not the photo's dense, ragged, drooping mass.
   Spruce (03/130700): width/height 0.51 → 0.27 (-47 %).
   Construction (b): every crown's pads and blobs show hard hexagonal facets (pine_*_front, oak_front); grown pine and birch pads float on near-invisible twigs. Bar (d): next to the photos these read as generic low-poly asset-pack trees, not AAA finished work.
   In game it gets worse: PropLayout.tree_fit (game/play/site/prop_layout.gd +78..86) stretches across by box half-width/tree_feet and up by height independently, so each crown's width/height drifts from the model by 0.64x to 1.43x (pine_grown 124 of 213 trees, oaks 11 of 16 more than 10 % off; oaks median 15 % narrower again).
8. [judgment] changelog.d/woodland-trees.md is untracked, not in the commit; record's "Play this" names 0.1-dev3-checklist.md, which is not in the repo.
Must-fix for the next attempt (priority order):
1. game/play/site/prop_layout.gd tree_fit + prop_dress.gd: stop the non-uniform crown stretch. Export trunk and crown as two meshes (or two surfaces laid by two transforms): the trunk keeps across/up to fill the box, the crown scales uniformly by `up`. Add a GUT case: a laid crown's width/height equals the model's within 2 %.
2. tools/blender/maps/oak.py: CROWN_R to about 10.5 x 5.0 x 10.5 (overall width ~1.5x height); bring the crown's outer skirt down to CROWN_FLOOR (3.1 to 3.7 m) at the rim, not ~4.9 m; SPLIT from 3.9 to ~3.3; real buttress roots (4-5 lobes, flare 1.5x BOLE_R, visible in oak_foot.png). The uncommitted lumpier blobs help; keep them.
3. tools/blender/maps/pine.py old: narrow the crown to ~0.4 of height, deepen it to ~0.5 (from height*0.55 up), clear bole ~0.5; irregular, slightly lopsided clouds, a trunk with a slight lean or kink as in 130505; lower bark a darker grey-brown (no team hue), tan only in the upper third.
4. pine.py young: conical, ~0.3 width/height, open whorls of elongated upright tufts (not blobs) from CLEAR_YOUNG to the top, a leader tuft at the tip.
5. pine.py grown and treekit.py pad/tuft: break the regular tiers (vary whorl spacing, droop the tips, fill between tiers so no bare twig shows); smooth the pad rims (more rim points or bevelled normals) so no hexagon reads.
6. spruce.py: the photos' 0.5 width/height can't fit a 1.5 m cell of a ~6 m thicket: ask the owner (wider spruces whose tips overlap neighbours inside the thicket's box, or keep narrow). Don't decide it silently in Defaults.
7. Ask the owner now (criterion conflicts): the 2.6 m crown clearance vs the young pine's foliage to the ground, and the box-sized trunks (a young pine's 0.32-0.5 m stem against the photo's ~0.1 m).
8. Commit changelog.d/woodland-trees.md; fix or drop the checklist reference; get QA and performance reports for WT1.
Owner should test in the game:
- Walk the Ridge and the Clearing on Low with F3: FPS at or above 60; draw calls rose ~20 % (123 vs 103).
- Stand under an oak and a young pine: no leaves or branches at head height, nothing seen through that stops BBs, or the reverse.
- Shoot the trunks edge-on: BBs stop at the bark, not in the air beside it.
- Birch stand: do the birches read as birches (white with dark marks) at 20 m?
- Thickets: no bright gaps; nothing visible through them that a bot can't see.
- Compare each tree's silhouette with your photos from 30 m.
