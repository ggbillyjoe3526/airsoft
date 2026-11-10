Task: RW1 · Replica wear (AEG Rifle, GBB Pistol): realistic, slightly used
Attempt: 3 of 4
Head: cbf89f6 (wear and paint suites 44/44; gdlint, notes, wiki, unit parts 1-2 passed on attempt 2's tree, no .gd changed since)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (conditional on the full tools/check.sh on this head passing)
1. Attempt 2's must-fixes met: the pistol's rail slot is a faint broken grey with no light lip (LIP_RUB_CUT,
   NARROW_GRIME, rub² bare metal); serrations crisp with no tan fill; no stripe at the whole-pistol distance; grime
   neutral; the AEG's patches broken up (one faint handling haze left on the black upper receiver). Shapes and
   triangles unchanged; no clipping. In game: faint scuffing, within "keep it subtle".
2. No contract touched. 3. No runtime code changed; QA and performance Pass stand. 4. test_replica_wear fails
   without the feature; the bake has no unit test (acceptable for a Blender tool). 5. Shader uniforms typed and
   documented; bake thresholds are build-tool constants. 6. Grey, toy-first wear, no brand marks; fits Sunlit
   Concrete. 7. arms.glb not rebuilt on purpose, recorded. 8. Scope AEG and pistol only; record updated; changelog due.
Advisory: a four-stroke parallel scratch cluster on the slide reads a little like a drawn hatch (vary length and
angle in a cluster); the AEG magazine's ticks are evenly sized; the next arms rebuild (the SMG's) takes the under-1°
curl change.
Owner should test: the pistol's rail slot in Ghost and grey under sun; the black AEG's receiver for any smudge; the
slide's scratch clusters on inspect; repaint worn → plain → worn on the turntable; Low preset; first person in Depot
and outdoors (visible at all, still subtle).
