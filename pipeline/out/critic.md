Task: BL8 · Attachments modelled from the owner's photos (nine parts, unbranded)
Attempt: 3 of 4
Head: 319a75e. Full tools/check.sh not run on it: it last passed on f1dc779, 4,752/4,752. On 4a17278, 144/144 part
tests pass and gdlint, the changelog and the wiki checks pass; the coordinator stopped the run. The Accept holds only
once tools/check.sh is green on the rebased head; do not merge before. Models in 4a17278. QA Pass (03dc1ca).
Performance Pass, re-measured on 4a17278.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
Attempt-2 must-fixes, measured with pixel scans of the full-size photos against the cmp/r2 renders at the same angle:
- Pistol silencer (attachments.py:888, :907), against wey027-02 side-on:
  - Tube and collar L/D 4.68 → 4.43 (-5 %). Overall L/D 5.13 → 4.70 (-8 %).
  - Collar 1.00 → 1.00 of the tube. Spigot 0.39 → 0.35 (-10 %, at the limit). Collar length 0.21 → 0.25 D (±3 px).
  - Met. Fitted in ctx.jpg, it sits flush on the slide.
- Torch (attachments.py:987): the head is 0.435 of the length, against 0.40 to 0.46 in the X300 photos. Met.
  - The body lofts onto the head with no step or gap. The saddle meets the head's top line.
  - The Cyber variant's flush clamp is a fit constraint (:1021), not a defect.
- Vertical grip (attachments.py:797, :849), against the Double-Bell side photo:
  - Flare to waist 1.43 → 1.35 (-6 %). Height to waist 1.90 → 2.05 (+8 %). Foot 1.01 → 1.06.
  - Flare zone 0.30 → 0.27 of the height (-10 %). Stipple panel 0.72 → 0.65 of the face (-10 %).
  - The studs are seeded and scattered, and no longer read as a grid. Met.
- The other six parts are unchanged since attempt 2, where they passed. The laser's windage wheel (c_lz right side) is
  joined and knurled.
- Checks 2 to 5 are unchanged from attempt 2: build script and .glb only, with no game code, per-frame path or contract.
  test_attachment_models.gd fails on the base config (QA: 2 of 11).
Must-fix for the next attempt: none. Before the records commit (non-blocking):
- attachments.py:867 is a stale duplicate comment line ("The clamp, its cross bolt and nut."). Delete it.
- Polish, if BL8 is reopened:
  - Round the vertical grip's clamp top edges, at about a 3 mm radius. In the photo, at 4 % below the top the width is
    0.78 of the maximum; in the render it is 1.00.
  - The pistol silencer's collar knurl is about twice the photo's pitch, and its step is a 1 mm washer where the photo
    has a 5 mm neck.
Owner should test in the game:
- The pistol with the silencer and the torch at viewmodel distance: proportions against the slide.
- ADS through the red dot: the deck sits below the window and the glass is clear (QA's half-moon advisory).
- The vertical grip's flared top and stipple in first person: does the boxy clamp top show under the handguard?
- The torch and laser beams leave their emitters on the pistol and the Cyber, and re-check the torch once the Cyber
  rebuild merges.
- The variable scope and a first slot swap on the Low preset: any hitch on first draw (performance's prewarm note).
