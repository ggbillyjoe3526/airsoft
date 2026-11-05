Task: HS1 · Replicas worn on the figure: the pistol in the holster, the rifle on the back (no task block; judged against the owner's 16:18, 18:01 and 19:14 words)
Attempt: 3 of 4
Head: 6a13fa9. Full check.sh last ran on d0d26b5. Since then, targeted runs pass; I reran test_figure_hands myself: 24/24, 540 asserts. QA Pass, performance Pass, both run on 9252cee. This Accept holds only once tools/check.sh is green on the final head. Do not merge before that.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
Round-2 must-fixes:
- Sniper past the pack: the owner ruled on it at 19:14 ("keep as is, ends stick out"). It is recorded in DECISIONS.md:177-178, KNOWN_ISSUES.md:127 and HS1.md:62. Settled.
- Fit reads only the corners: fixed. _back_rest now rasterises every triangle whose corners are all on the chest (figure_models.gd:393-407).
  - Measured at load: the human's kit cells went from 730 (9252cee) to 874 (head). So the vertex-only fit did leave holes.
- Test pinning the fit: test_figure_hands.gd:240-271 poses the figure and samples the AEG's and sniper's faces against the posed pack.
  - It asserts the nearest gap is > -4 mm and < gap + 1 cm.
  - Without the fit, the lift is about -4 cm (QA), so the gap would be about 4.3 cm and the test would fail. A flipped sign would also fail it.
- QA and performance reports exist and both pass. Their low findings are fixed:
  - NaN lift: figure_models.gd:141.
  - cell <= 0: :123 and :356.
  - Pistol lift: figure_hands.gd:140.
- Round-2 nits fixed: the bare 0.5 (now back_rest_share, figure_config.gd:170), "flat" in the wiki and changelog, DECISIONS wrapped at 120.
Non-blocking (fix in the records commit):
- performance.md is stale for the triangle fit. My measurement of load_kinds on the same machine (3 runs each):
  - 9252cee: 67-85 ms. 6a13fa9: 103-107 ms.
  - About +30 ms, once at start-up and never per frame. Update performance.md's 55-61 ms line.
- HS1.md:46 still gives the round-2 numbers ("0.5 to 2.5 cm … touches it at 5 mm"). The brief's probe after the triangle fit says 0.6-3 cm, nearest 6 mm. Update them.
- The st10 renders (18:11) predate 5b70048. Re-render the AEG side and back views on the head before the PR, so the sheet shows what ships.
- The new test treats the whole pack as rigid on Chest (test_figure_hands.gd:264), while the fit uses only triangles rigged to the chest. It only checks standing. Crouch and run are untested.
- QA low finding 2 is still open: steps in rest_on_back/_back_rest are uncapped for a huge or bad import. Can wait.
Must-fix for the next attempt: none.
Owner should test in the game (at most 6, one line each):
- A bot with the AEG on its back, from behind and the side, standing and running: does it read as resting on the pack?
- A bot crouching or looking up: does the AEG's stock touch the helmet or sink into the pack's top?
- A bot running: does the left arm swing through the AEG's muzzle or the sniper's barrel below the pack?
- A bot vaulting with the pistol holstered: does the pistol stay in the holster? (There is still no Vault render.)
- The Cyber Pistol holstered up close while crouched: is the speck at the holster's foot acceptable?
