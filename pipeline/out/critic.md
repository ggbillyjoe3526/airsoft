Task: ST2 · The Street's CC0 dress (no task block; judged against the brief and docs/records/ST2.md)
Attempt: 2 of 4
Head: 37731e1 (= HEAD; QA Pass at 37731e1; performance Pass at 4718e15, still valid because 4718e15..37731e1 changes only changelog.d, FEATURES and a test file)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none. Attempt 1's check 8 is fixed:
- changelog.d/the-street.md:12, which said cars were still blocks, is gone.
- changelog.d/the-street-dressed.md:1-6 says what is modelled and what stays a block (railings, fences, hedges, kiosks,
  the bus shelter, the roadworks).
- docs/FEATURES.md:36 credits ST2.
The rest stands from attempt 1:
1. build_map.py +56-59, +209-214 and prop_dress_config.gd +31-54 dress 79 blocks with 23 models. Each block keeps its
   box: QA measured the props filling 95% of the footprint and 97% of the height (test_st2_qa.gd:50).
2. No contract changed.
3. Load-time build only. Performance: 113 instances in 24 MultiMeshes, 107k triangles, a 26 ms build, draw calls +5.4%,
   no orphans. The Street is the lightest dressed map.
4. test_props.gd +281 fails without the dress names. test_st2_qa.gd :24, :50 and :92 pin each mesh, the fill and the
   grids.
5. Typed config data. Colours live in the build tool's recipes.
6. CC0 Kenney models, recoloured from the look's palette, all passing the team-hue rule (test_props.gd:199). The
   colour reads below go to the owner rather than into changes.
7. Advisory only: 14 GLBs repeat the same geometry with only the colour changed (about 2.2 MB), the existing recolour
   pipeline's cost.
8. Dev scope. KNOWN_ISSUES, the Maps wiki page, ASSETS, ROADMAP, FEATURES, the changelog note and the record are all
   updated.
Must-fix for the next attempt: none. Advisory: the lorries' windscreens are painted plaster, so no glass reads.
Owner should test in the game:
- The yellow cars in shade: car-park-b.jpg renders one at #dfad34, 14° from Beta's orange.
- The far crimson lorry renders saturated red (#d51135) at both road ends.
- Steel bins and lamp posts read near-black navy outdoors.
- The skip (a 6x by 4x stretch) and the long 3.2 m settee: do they look right?
- Vehicles as cover: does what you see match where a BB stops, including under the bodies and past the roof lines?
- Settees and cars under the night lamps: does any read as a team colour?
