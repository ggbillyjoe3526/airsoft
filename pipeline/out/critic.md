Task: BA1 · The barrel models (brief, no TASKS block)
Attempt: 1 of 4
Head: dc67076 (brief named c5964de; dc67076 adds only changelog.d/barrel-models.md and FEATURES.md). Targeted tests
294/294 and gdlint, changelog and wiki gates pass; full tools/check.sh still running on 7e3b7a5. QA Pass, perf Pass.
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 6/8 → Retry (not a near miss)
Proportions (a), side renders (3.69 and 2.92 px/mm) against real M4 AEG parts. All are within 10 %, so (a) passes:
  barrel L/OD 39.0 vs 40.3 (-3 %) · hop length/barrel 0.141 vs ~0.143 · hop height/length 0.59 vs ~0.62 (-5 %) ·
  bore/OD 0.68 vs 0.67 · extension tube/rifle barrel OD 17.5/17.2 mm · long/tight length 1.29 vs 1.25 (+3 %).
Failed checks, with evidence:
1. [measured] Criterion 6, card legibility. card_tightBore_shown.png is 170x14 px, mean RGB 20,20,22, and the
   "polished steel" barrel draws black. Steel is metallic 1.0 and roughness 0.16 (barrels.py:58), with no reflections
   in the picture. Brass reads dark brown (mean RGB 33,32,31). The barrel is 2-3 px thick. The dial, O-rings and
   bucking can't be read, and the old placeholders were 24 px tall. PLAYTEST.md:1326 promises what the card can't show.
1. [judgment] (b) Construction:
   - crown_close.png has a dashed white crack round the barrel where the crown (-3 mm) meets the inner barrel
     (barrels.py:136, :379; two objects with mismatched rings, 48 vs 52 segments).
   - ext_close.png has a dark seam where the wrench flats meet the taper at y 23 (barrels.py:342 vs :346). The taper
     lathe starts at full radius 10.45 behind 8.9 mm flats.
   - ext_close.png has another seam at the taper and flutes join at y 28: 32 segments meet 56 (:338, :340).
   - Visible facets on the hop unit's rear sleeve and round underside (24 segments, hop_close.png left end). Visible
     facets on the centring spacer (36 segments, crown_close.png).
1. [judgment] (d) Bar:
   - HOP_BEVEL = 0.0 (barrels.py:98) leaves a moulded chamber with razor-cut edges. It reads as a flat grey extrusion,
     not an AAA part.
   - The hop arm sits 3.6 mm under the window's top, so the window reads empty (hop_close.png).
   - The 14 mm thread is a plain 3 mm stub (EXT_THREAD, :79) and is bare in the alone picture.
   - 3-fitted.jpg ships with an empty fourth panel.
8. [measured] ASSETS.md row says 9,740 and 9,890 triangles. The glb has 9,882 (814+9,048+20) and 9,886
   (4,898+4,968+20).
Must-fix for the next attempt:
1. Steel, Brass and Etch: metallic ≤ 0.75 and roughness ≥ 0.3, as the rifle's Metal (0.75/0.38). Or give the picture
   viewport an environment. Target: steel pixels' mean luminance ≥ 120 on card_tightBore_full.png, and brass with a
   visibly gold hue.
2. Barrel cards ≥ 24 px tall in the Customise barrel tab. Either scale the barrel tab on the longest barrel's length
   only with a 24 px minimum height, or frame each card on its hop-up end. Re-capture card_*_shown.png.
3. Weld the crown into the inner barrel's mesh with the same segment count, and give the extension's lathes, flats and
   flutes matching ring counts. Chamfer the taper's start down to the flats' 8.9 mm. Then show no seam in
   crown_close.png or ext_close.png.
4. Raise the hop unit to ≥ 48 segments and the spacer to ≥ 52. Set HOP_BEVEL to about 0.0004 m (0.4 mm) with 2
   segments. Pay for it from the long barrel's hidden length (20 segments → 16 between the O-rings), staying ≤ 10,000.
5. Raise the hop arm so its top is within 1 mm of the window's top, cut 4 to 5 thread grooves into a 10 mm, 14 mm
   thread, fill or drop the empty panel, and correct the ASSETS counts.
Owner should test in the game:
- Customise › Barrel: both cards read as steel and brass, and the long one is visibly longer.
- Tight bore fitted: the crown ring is visible in the flash hider at viewmodel distance, with no flicker.
- Long barrel: the extension sits flush on the barrel behind the front sight, and the silencer starts at its end.
- Each paint on the long barrel: the extension matches the rifle's barrel.
- First fit on the Low preset: any hitch from the new materials (performance's prewarm note).
