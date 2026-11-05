Task: BA1 · The barrel models (brief, no TASKS block)
Attempt: 2 of 4
Head: 2ec0305 (= HEAD; targeted tests pass, full tools/check.sh still running). QA (c5964de) and performance (7e3b7a5)
reports predate this head's insides file and ReplicaParts.inside(); they describe a fit-time free that no longer exists.
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, measured and judgment; also Retry until QA and performance re-run on this head)
Fixed since attempt 1: steel reads 126,135,150 and brass gold on the card; crown seam gone (crown_close.png); arm in the
window; ASSETS counts match the glbs (882+8,948+20 = 9,850; 4,830+4,980+20 = 9,830); proportions (a) unchanged, pass.
Failed checks, with evidence:
1. [measured] Card legibility (cards_shown.png, card bg 30,32,36). The long barrel's extension, its one visible
   difference, draws 32-37,37-42,46-51: a silhouette, no knurl or flutes. The hop body is about 35,37,44. Only the
   bucking, dial and inner barrel read. Chamber is 0x2a2c30 (barrels.py:67), the card's own colour.
1. [judgment] (b) Construction:
   - Dark crack round the extension at the flats' end, in ext_close.png x≈300 and in hand in fit_long_close.png
     x≈520. barrels.py:401 starts the shoulder at r 8.9 at y 23, but the flats prism's round arcs end at r 10.45, so a
     0.4 mm-wide, 1.5 mm-deep slot runs round them.
   - The hop unit's rear sleeve is visibly faceted (28 points, barrels.py:250; hop_close.png left end, x 315-380).
1. [judgment] (d) Bar:
   - The budget reason for 28 points doesn't hold. The tight-bore inside spends about 5,500 of its 8,948 triangles on a
     9 mm tube at 52 points that is hidden when fitted and 3 px tall on the card. The sleeve and nose lathes cost
     about 8 triangles per point each.
   - The long crown is 20 points (SEG["long"], :113) and shows in hand inside the hider. It is in aeg.glb, apart from
     its inside, so the weld no longer ties its count.
   - The thread has 3 grooves (:87); 4 to 5 were asked for.
Must-fix for the next attempt:
1. Chamber to a mid grey (about 0x5c6068). Make the extension read on the card: luminance ≥ 25 above the card's, via a
   fill or rim light on the barrel slot's picture (as PART_TURN is per slot). Re-capture cards_shown.png.
2. Start the shoulder at (23.0, COUPLING_R) and chamfer the flats prism's own end instead. Show no line at y 23 in
   ext_close.png and fit_long_close.png.
3. Hop sleeve and nose lathes ≥ 48 points (body keeps 28 if needed). Long crown 52 points. Pay for it by taking the
   tight-bore inner barrel to about 32 points behind the spacer (change the count under it). Stay ≤ 10,000.
4. Thread: 5 grooves. Then QA and performance re-run on the new head.
Owner should test in the game:
- Customise › Barrel: hop unit and the long barrel's extension read against the dark card, not only the red bucking.
- Long barrel fitted, aimed: no dark ring between the knurled coupling's flats and the fluted tube.
- Long barrel fitted: the brass crown in the flash hider is round, not polygonal.
- Each paint on the long barrel: the extension matches the rifle's barrel.
- First open of the Barrel tab: no hitch from loading inside/aeg.glb.
