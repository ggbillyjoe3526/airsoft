Task: none (BL8) · head 61dc3d6 · Verdict: Pass
Run: no match run (asset-only change, no gameplay code; the container has no GPU, so no draw-call or frame-time run) · budget: no baseline yet, judged against docs/CC0_ASSETS.md > Size limits, the targets and origin/main's files
Metrics (measured, read from the glTF JSON of each .glb):
- Parts file size: aeg 1.18 MB, sniper 1.09 MB, pistol 0.31 MB, cyber 0.11 MB / 2 MB limit (ok). Total up about 1.9 MB of a 500 MB install.
- Triangles per part in the hands: max 9,912 (optic_scopeVar) / 10,000 (ok, 0.9 % margin); redDot 5,948, scope2x 6,228, grips 3,360-3,520, torch 3,400, silencer 1,886-2,484, aeg magazines 380-648, pistol magazine 2,020, laser 2,334.
- Figure copies: 12-104 triangles, 1 surface each (ok; the 3,000 figure-replica cap is far off).
- No textures (0 images), so no VRAM or import-compression cost.
- Surfaces per part: 2-6 (scopeVar 6, magazine_hiCap 5, torch 4, optics 4). Transparent surfaces: 1 per optic (the Lens was already BLEND on main), none elsewhere. LensDot/Fibre add a surface only inside the optics.
- Worst-case first-person fit on the AEG (scopeVar + vertical grip + torch + hiCap mag + silencer + tightBore barrel): about 19.4k part triangles, 23 part surfaces (about 23 extra draw calls, 1 blended), plus the replica body. Under the 40,000 hands-model cap only if the body is under about 20k (judgment: the body was not counted here).
Regressions (> 10 % worse): none measurable at runtime. Asset growth is by design (aeg 355 -> 1,208 KB, pistol 123 -> 322 KB, cyber 21 -> 109 KB).
Blocking findings: none.
Advisory:
- game/config/viewmodel_config.gd (3 optic dictionaries): constants only, read at setup; no per-frame cost (judgment).
- assets/models/replicaParts/*.glb: each optic is now 4-6 draw calls in the hands (judgment). A hands scene carrying scope + torch + grip + mag is about 20+ calls for attachments. Cheap on Ultra, worth a rendered check on the Low preset.
- LensDot (alpha blended) and Fibre (emissive) are new materials. replica_view.gd:100 prewarm_glass() covers only the window material; play_session.gd:737 view.materials() may or may not include the part meshes' own materials. If it does not, the first show of an optic compiles a blended pipeline mid-match (judgment; not verified, no GPU). Lens was already blended on main, so the risk is only the new LensDot/Fibre variants.
- The optic_scopeVar part sits 88 triangles under the 10,000 cap; any further detail needs a trim.
- Diff adds no GDScript allocation per frame or tick, no nodes, timers or connections to free (measured by reading the diff: only the three constants in viewmodel_config.gd, a unit test and Blender build scripts).
Fixes: none required. If the Low preset shows a hitch on first optic draw, add the optic parts' materials to the prewarm list.
Unexplained: none. Frame time and draw calls need the owner's rendered run (F3 overlay) with the Sniper scopeVar and every part fitted.
