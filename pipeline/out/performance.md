# Performance · CZ1 · head f1685e8 · Pass

No runtime code changed (a Blender build script, two rebuilt .glb files, tests and docs), so no bot match was run.

- In-hands triangles 37,824 (glTF count) of the 40,000 replica limit, about 94.5 % (the owner's ~95 % rule); main had
  31,326. Figure copy 240 and the torch part 3,066, both unchanged. Meshes 6, materials 5, no textures.
- replicas/cyber.glb 954,708 B against 870,868 B on main (+9.6 %); replicaParts/cyber.glb unchanged in size.
- Regressions over 10 %: triangles +20.7 %, intended and under budget.
- Blocking: none. No per-frame allocations, unfreed nodes or new materials or particles.
- Unexplained: none.
