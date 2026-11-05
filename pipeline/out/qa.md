# QA: HS1 (681450b..HEAD, back rest)

Verdict: Pass. No test added (nothing found that a test catches and a real asset triggers).

Ran (targeted, headless): test_figure_hands 24/24, test_figure_hands_qa 21/21, test_figure_view 9/9,
test_lo3_qa 7/7, test_replica_paint 13/13. Note: without `-gdir=` GUT loads the whole suite and a single file
takes 3-4 minutes; with it each file takes seconds.

Probed FigureModels.rest_on_back / _back_rest directly (scratch script, not committed):
- null mesh, empty ArrayMesh (no faces), unknown kind, robot kind: all return 0.0; the robot's back_rest is empty
  (no Kit_Pack part), so it keeps back_depth_robot. In hold the `if r != null` guard also covers a missing replica.
- A mesh that misses the kit (far away): 0.0, cached.
- The four real figure meshes (aeg, cyber, pistol, sniper): 1-6 ms each on first ask, lift about -0.040 to -0.043 m
  (small, tested < 0.06). The cache is hit afterwards, so LOD swaps and set_body re-holds cost nothing.
- Mesh sharing: FigureView loads the replica .glb through load(), so every figure of a replica id shares one Mesh
  resource; the per-kind cache is keyed correctly, stays at one entry per replica id and per kind, and is freed
  with FigureModels. `middle` comes from the same mesh's AABB, so a cached lift is never reused with another middle.
- 874 kit cells built for the human; chest bind found by name or by bone name, so a skin with unnamed binds still
  resolves through get_bind_bone. A skin with neither skips the part (no crash); a mesh with no skin is skipped.
- Re-holding after set_body: release() resets on_back/in_holster, hold() recomputes from the cache; covered by the
  existing test_lo3_qa and test_replica_paint changes, which pass.

Findings (all low, none block):
1. A corrupt mesh with a NaN vertex gives lift = NaN (probe: "nan"), which would make the replica transform NaN
   and the rifle vanish. Real assets are fine; a `is_finite` guard on lift would close it.
2. The sampling loop is unbounded in mesh size: a 50 m box took 26 s on first ask. Replicas are 0.2-1.1 m, so
   no real cost; a cap on `steps` would make it safe against a bad import. Also a back_rest_cell of 0 or less
   in a tuned config would hang (division by zero gives huge steps); config-only.
3. hold() also computes (and caches) a lift for pistol meshes, which are never carried on the back by the
   rule "rifles only". Harmless: about 1 ms, once. The pistol's lift is -0.040 like the rifles', so nothing visible.
4. The view test counts worn replicas from the hands' own slots, so it would still pass if on_back and in_holster
   both showed the same slot; test_figure_hands pins the slots separately, so this is covered.

Not verified: how the rifle looks resting on the pack (clipping through the pack in the crouch or the walk-off
pose). Owner to look at a bot standing, crouching and walking off with the rifle on the back, and at the robot,
whose rifle should sit 0.17 m behind the chest with no pack.
