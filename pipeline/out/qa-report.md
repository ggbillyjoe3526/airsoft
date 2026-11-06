Task: CZ1 (no task block) · QA commit none (no tests added) · Verdict: Pass

Checked on f1685e8's committed glbs (extracted from git, since the working tree holds uncommitted sight edits by the main thread) with bpy 5.2.3.

Blocking: none.
Advisory:
- docs/ASSETS.md says 37,802 triangles in the hands; the glb has 37,800 (Body 29,080 + Magazine 4,576 + Slide 3,036 + Selector 576 + Trigger 532). Under the 40k budget either way; fix the figure.
- Body/Magazine mesh overlap pairs rose 677 to 1,123 (nested parts, expected; the magazine is inside the grip, x 14.2 vs body 15.6, only the pad is wider at 16.1 below the body).

Findings per ask:
- Torch: TorchMount empty z -22.7, rail underside z -22.34 (Body), torch top z -22.4 (replicaParts/cyber.glb): sits on the rail within 0.3 mm; torch y 35.6..99.9 inside body front 101.5, UnderLaser at mount y 69.4.
- Clip keys: all Fire/Inspect/Reload/Selector curves start and end at rest (magazine, slide, trigger unchanged at the ends); reload drop 193.5 mm (old 230 x 0.84), inspect 12.9, slide recoil 12.5 (old 14), trigger pull rotation unchanged (17 degrees). Rest pose puts the magazine in the well.
- Trigger: bone at y -7.6 (GBB reach), mesh y -16.3..-3.9, z -30.9..-8.5; zero triangle overlap with Body at rest. Could not verify the pulled pose or slide-back clearance (the imported pose did not drive the evaluated mesh headlessly); check by eye in the viewer.
- Poke-through: Selector 14.4 wide vs body 15.6 (inside); Slide x 10.1; no part exceeds the body outline except the magazine pad. Owner renders (cz1/ 1, 3) show no stray geometry.
- Sizes: Body y -102.2..101.5, z -105.8..31.3, x +-15.6; GBB y -104.7..98.9, z -105.7..4.1 (slide 26.1), x +-15.5. Matches the brief. Empties as reported (Muzzle, Rear/FrontSight z 28.8, MagWell -72.9,-101.6).
- Rear-sight test: new expectation (0, 0.0288, 0.06835) matches the RearSight empty (28.8, -68.4 mm) within 1e-4.

Tests added or changed: none by QA. tests/unit/test_cyber_pistol.gd:78 (changed by the worker) · rear sight at the GBB's size · fails against the old value (0.04, 0.0768) since the empty moved.
Ran: test_cyber_pistol.gd 8/8 pass; with the untracked test_cyber_sights.gd 10 tests, 56 asserts, all pass. Note: -gtest alone runs the whole suite (.gutconfig.json); pass -gdir= as tools/unit_tests.sh does. Run on the working tree, whose sight edits are uncommitted; the cyber.glb differs by 192 bytes from the commit, empties identical.
Not run: tools/check.sh (the main thread owns it).
Owner's list: how the hands grip the pistol in the first-person view (needs a display); torch light on the rail; trigger pull and slide recoil clearance in motion.
