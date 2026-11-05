Task: BL9 · head 7f7b7e2 · Verdict: Pass
Run: judged by reading (grenade files only; the other files in the range, bb.glb, bb_view.gd and the sniper, come from main merged in and are not BL9) · budget: no baseline yet, judged against targets and origin/main
Metrics: flash.glb 5,120 tris, 113,988 B / 5,500 tris, 200 KB (ok); smoke.glb unchanged, 5,292 tris, 152,544 B (ok). Earlier --perf run on 0f115be matched origin/main (nodes 1339, orphans 879).
Regressions (> 10 % worse): none measured. Flash triangles are 2,812 -> 5,120 (+82 %), vertex-only cost, judgment: negligible at 13 bombs (about 66k triangles worst case, no shadow pass).
Blocking findings: none. No code change in grenade_view.gd; mesh is still loaded once and shared, prewarm and frees unchanged.
Advisory (judgment): flash surface count (6) unchanged, so draw calls are as before; a rendered check on Low is still worth doing.
Fixes: none required. Unexplained: none.
