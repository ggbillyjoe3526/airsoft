Task: BL8b · head 823d6eb · Verdict: Pass
Run: none (static analysis; Godot busy with tools/check.sh) · budget: no baseline yet (pipeline/perf-budget.json has no lines)

Scope: runtime code is game/config/viewmodel_config.gd only (three scopeVar optic constants). The rest is four .glb
files, the Blender build script (dev code, never ships), tests and docs. No new per-frame or per-tick work, nodes,
signals or materials.

Metrics
- File sizes (measured): aeg.glb 2,003,184 of 2,097,152 (95.5%, 94 KB headroom); sniper.glb 1,912,476 (91.2%);
  pistol.glb 848,632 (40%); cyber.glb 206,284 (10%). Growth against main: aeg +46%, sniper +49%, pistol +59%,
  cyber +116%: load-time and disk, about 5 MB for all four.
- Triangles per part: 8,508 to 9,984 of 10,000.
- Frame time (judgment): static meshes, only fitted parts instanced, at most about 10k triangles each in first
  person; shadow pass negligible.
- Bots: the _Figure copies are separate few-primitive meshes, untouched by the detail; per-bot cost unchanged.

Regressions over 10%: none in game metrics (file growth is not a budget line).

Advisory
- aeg.glb at 95.5% of its cap, sniper.glb (a copy of its parts) at 91%: one more detail pass on an AEG part breaks
  the cap. Next step quantised positions and normals or a split file, the owner's budget call (recorded in BL8b).
- Triangle margins as small as 16 (variable scope): re-count after any geometry change.
- Shader prewarm unchanged: no new materials (the BL8 advisory on parts' own materials stands).

Verdict: Pass
