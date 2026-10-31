Task: WR3 · Woodland's CC0 dress (no TASKS.md block; judged against the brief, the owner's ask and docs/records/WR3.md)
Attempt: 2 of 4
Head: 29f8d52 (= git rev-parse HEAD; diff 10095c1..29f8d52; test_props 17/17, test_wr3_qa 7/7, test_map_level 15/15 re-run here)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (QA's one blocking item, the changelog note, is in changelog.d/woodland-cc0-props.md; performance Pass on 10095c1, the later diff is build-time only)
Evidence for the first pass's fixes:
- Cores: map_level.gd:365-377 core_box runs a side flush when _touched (:381-390, a 5 cm slab against the other cored boxes) finds a thicket, else insets min(0.7 m, 20 % of the width); cored list built once (:340-344). test_props.gd:327-348 walks every touching pine pair and asserts no gap; the old inset_of insets every side, so it would fail.
- Lined (TILE) blocks keep their box: map_level.gd:349; the old b.dress guard is gone, so a site-less map's kind-dressed blocks are now hidden too (the latent issue closed).
- A ramp keeps its box: prop_dress_config.gd:92-93; test_props.gd:394-405.
- Changelog note: player-facing, four lines, no dev content. Record attempt 2: WR3.md:57-71, with QA's and performance's findings.
- Check 3: core_box/_touched are greybox build-time (O(n²) over 197 thickets, once); nothing new per frame or tick.
Failed checks: none.
Should fix before merge (non-blocking, not scored):
- prop_dress_config.gd:5 is still 198 columns: the wrap moved the overflow instead of breaking it (the record's "two lines wrapped" is half true). tests/unit/test_wr3_qa.gd:44 is 130.
Owner should test in the game:
1. Woodland's staircase thicket clumps (x -68..-40): any glimpse of a bot through a seam you can't shoot through?
2. Thickets read as uncrossable hedges; 1.6-1.8 m trunks as trees, not posts.
3. Shoot round a trunk's edge: is the square hit box "a little wide" or unfair?
4. The violet truck and teal crates: readable as cover, never a team colour?
5. F3 frame rate on High by day and on Low, looking across the woods.
