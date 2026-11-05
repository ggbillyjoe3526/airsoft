Task: BL6 (none in TASKS.md) · QA commit none (no tests added; read-only check) · Verdict: Pass

Checked: git diff origin/main...HEAD, old vs new cyber.glb compared by parsing the glTF JSON and binary with python
(no Godot, no check.sh run, as instructed).

Contract kept (all verified against the old file):
- Armature CyberPistol, one skin, joints root, magazine, selector, slide, trigger: same local transforms as before.
- Clips Fire (0.1333 s, 8 frames), Selector (0.2 s, 12), Reload (1.1 s, 66), Inspect (2.0 s, 120): same lengths, key
  counts and sampled first/mid/last values on every channel (slide Fire 9 keys, trigger Fire rotation 9, selector 13,
  magazine Reload 67, Inspect 121). Only node indices shifted.
- Empties Muzzle, FrontSight, RearSight, MagWell, SlideBack, TorchMount: identical translations.
- Meshes Body, Slide, Trigger, Selector, Magazine, Figure present; materials CyberSlab, CyberFrame, CyberLine,
  CyberCore, CyberMetal with identical colours, metal, roughness and emissive (material order differs; lookups are by
  name).
- Budget: hands 31,594 triangles (<= 40,000), Figure 236 (<= 3,000), 5 materials (<= 6), no textures, 880 KB (<= 6 MB).
  No NaN positions. Mesh extents stay inside the old envelope (Body y -0.126..0.042, z -0.114..0.115; Muzzle at the
  front face z -0.114; sights below the body top).

Blocking findings: none.

Advisory:
1. The old Figure node carried a translation of (0, -0.3, 0); the new one has none. The other replicas (aeg, pistol,
   sniper) have none either, and the new Figure mesh sits where the old mesh did, so it is probably the old
   file's leftover, but docs/records/BL6.md does not mention it. The owner's playtest line "a bot carrying it shows its
   outline" covers it; worth one sentence in the record.
2. Body is a single mesh of 24,422 triangles (4 primitives). Fine for the budget; the performance agent owns frame cost
   in the hands view and the menu turntable.
3. Rear block reaches 0.115 m, 25 mm past the SlideBack empty (0.09); the doc contract allows this, and a pistol's
   figure uses the empty's depth, so the figure's grip alignment is unchanged.
4. docs/records/BL6.md still says check.sh pending and Review pending (expected until the gates finish).

Tests added or changed: none (the change is a binary asset; the existing GUT tests that load the Cyber Pistol passed
317/317 per the caller). I did not run the suite.

Could not test: how it looks and feels in hands, iron-sight alignment, torch clearance with the teeth, the slide and
cell not clipping in motion, paint and Realistic-colour look. These are on docs/PLAYTEST.md > BL6 for the owner.
Not run: tools/check.sh, smoke test, Blender rebuild determinism (the record claims two runs match).

Verdict: Pass
