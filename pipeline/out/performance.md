Task: bp6-shoulder · Verdict: Pass
human.glb: 9574920 bytes on origin/main and on HEAD (no size change; content differs, hash changed, skin weights only).
No other asset changed (no .import, texture or png in the diff); only human.glb, tests, docs, changelog and blender scripts.
Tri/material budget: test_bp6_models (material limits, 8 a figure) and figure tests pass; vertex/index data unchanged in structure (weights only).
No runtime code changed; no new allocations, nodes or resources.
