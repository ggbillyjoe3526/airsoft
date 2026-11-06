Task: BA1 · The barrel models (brief, no TASKS block)
Attempt: 4 of 4
Head: 6f9022d (= HEAD; targeted tests pass, QA's 41; full tools/check.sh still running on 6f9022d, so this verdict
holds only once it or CI is green there). QA (50710d0) and performance (c173a5b) Pass; the diff since is one lens
position in the glb and one light-angle line, neither on a hot path.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Fixed since attempt 3, checked on the images: barrels.py:331 moves the Bore lens to hop -25.2, r 3.02, in front of the
barrel's rear cap at -25 as seen from the rear and inside the lip (the lip's inner radius there is about 3.01, so the
disc's rim tucks into the wall with no ring of light). Bucking centre, 7x7 samples: v4_cards_full.png tight (80,105)
54-57 and long (70,305) 54-63 on a card ground of about 32, so it reads as a dark hole (attempt 3 had white there);
tight_alone.png (260,565) min 43 and long_alone.png (213,578) min 45, a clean dark way in past a lit red lip wall.
The 3x card hole is a few pixels ragged; that is the card's resolution, not the mesh.
replica_pictures.gd:260 now takes the fill light from shot.camera.rotation_degrees (:284, 0/90/0) plus FILL_PITCH
(:24, a named -20): the same angle as before, now tied to the camera. Built once per picture, not per frame.
(a) Proportions, unchanged, pass: inner barrel 345 mm vs a real M4's 363 (-5 %); long/tight 452/345 = 1.31 vs 1.25
(+5 %); hop unit/barrel 0.151 vs 0.152; bore/OD 6.03/8.9 vs 6.03/9 (+1 %); extension OD = the rifle barrel's (17.2).
(b) Construction passes: hop_close.png shows the dial teeth, the window, the arm and the nose seated with no gap. The
attempt-3 close-ups (ext_close, fit_long_close, crown_close, fit_tight_muzzle) still match this geometry.
Budget: 9,454 and 9,954 of 10,000 (94.5 % and 99.5 %), as the brief asks.
Failed checks: none.
Must-fix: none.
Advisory (not blocking):
- The coupling's open back (barrels.py:402) is recorded as a known issue in docs/records/BA1.md, but that row is not
  committed at 6f9022d (only in the working tree). Put it in the records push. On v4_cards_full.png (x 790-850,
  y 280-330) it reads as a flat grey rear face, which is fine at card size.
Owner should test in the game:
- Customise › Barrel: the bucking's centre reads as a dark hole on both cards, inside the red lip.
- Customise › Barrel: the hop dial's teeth still read under the fill light (not blown out white).
- Long barrel fitted, aimed: no line or flicker where the flats meet the round shoulder.
- Long barrel fitted: the extension takes each paint like the rifle's barrel.
- Tight bore fitted: the crown sits centred in the flash hider.
- First open of the Barrel tab: no hitch from loading inside/aeg.glb.
