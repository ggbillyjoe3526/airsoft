Task: BA1 · The barrel models (brief, no TASKS block)
Attempt: 3 of 4
Head: 50710d0 (= HEAD; targeted tests pass, 143 + QA's 41; full tools/check.sh still running on f8bea33). QA (50710d0)
and performance (c173a5b) both Pass on this code.
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Fixed since attempt 2, checked on the images: the extension reads on the card (card_long_full.png x 284-368 averages
54-66,60-72,70-82 on bg ~32: about +30); chamber 0x5c6068; no crack at the flats' end (ext_close x≈300, fit_long_close
x≈520: a clean milled step); hop sleeve and nose round (hop_close left end); long crown 52; thread 4 grooves (accepted:
inside the 4 to 5 first asked, the cap allows no 5th). Fill light test (test_ba1_qa.gd:150) fails without PART_FILL.
(a) Proportions, unchanged, pass: inner barrel 345 mm vs a real M4 363 (-5 %); long/tight 452/345 = 1.31 vs 1.25 (+5 %);
hop unit/barrel 52/345 = 0.151 vs 0.152; bore/OD 6.03/8.9 vs 6.03/9 (+1 %); extension OD = rifle barrel OD (17.2).
Failed checks, with evidence:
1. [judgment] (b) Construction, the inner barrel has no bore at its back. barrels.py:172 starts the barrel's profile
   at (BARREL_REAR, 0.0), a solid cap at hop -25 mm; the bucking's dark bore disc is at -24.0 (:329), in front of
   that cap, so it is never seen. Through the bucking's lip the eye meets a flat lit face: white in the tight bore
   (tight_alone.png at 260,560; v3_cards_full.png at 80,110: a white dot in the red ring) and pale gold in the long
   (long_alone.png at 215,575). The card turns the hop-up end toward the viewer, so this is the most prominent detail
   on both barrel cards: it reads as a red-and-white cap, not the nozzle's way in.
Must-fix for the next attempt:
1. Make the bore dark from the bucking's lip. Either move the Bore lens behind the barrel's rear (y about -25.2,
   r 3.0, inside the lip) or start the barrel's rear profile at (BARREL_REAR, BORE_R) and put the Bore disc 1 to 2 mm
   down it. Costs 0 to 36 triangles; the long barrel has 46 left (it is 20 points there). Re-capture tight_alone,
   long_alone and the cards at 3x: the bucking's centre is near-black on both.
Advisory (not blocking):
- The coupling's back is open (lathe from r 8.4, :402) and the material is double-sided, so the card shows the
  extension's inside through it as grey (v3_cards_full.png x≈800-840); an inner wall at r 8.4 for a few mm would close
  it if triangles allow.
- The fill light's angle (replica_pictures.gd:258, -20, 90) repeats the camera's yaw (:282) by hand; tie it to the camera.
Owner should test in the game:
- Customise › Barrel: the bucking's centre is dark on both cards, not white or gold.
- Customise › Barrel: the hop dial's teeth still read under the fill light (not blown out white).
- Long barrel fitted, aimed: no line or flicker where the flats meet the round shoulder.
- Long barrel fitted: the extension takes each paint like the rifle's barrel.
- Tight bore fitted: the crown sits centred in the flash hider; the hider's own facets are the rifle's, not this task's.
- First open of the Barrel tab: no hitch from loading inside/aeg.glb.
