Task: SM4 · head b3a3812 · Verdict: Pass
Run: none (judged from the diff, as briefed; check.sh was running) · budget: no baseline yet, judged against targets and the attempt-3 pass at 15144d7
Metrics: not measured this round (no run). Draw calls, node counts, orphans and memory only from the attempt-3 numbers.
Regressions (> 10 % worse): none measured; none expected from the diff.
Blocking findings: none
 - Diff touches no GDScript runtime code: only 6 work-vehicle .glb files, data/maps/subway.json, tools/subway/layout.py, Blender build scripts and docs. No new per-frame or per-tick allocation, no new node/resource lifecycle (judgment).
 - Works vehicles: each is still one vertex-coloured mesh (1,100-2,840 tris); glb sizes move -4 % to +9 % (ballast_wagon 143->156 KB, skip_wagon 157->161 KB, trolleys ~-6 %). Hidden rail pieces replace the old works track, so net faces fall (judgment). No new material, so no new prewarm entry needed.
 - Five more signal_cabinet blocks (layout.py:193-200, subway.json): an existing model at 780 tris, drawn with the shared props material. +3,900 tris and +5 draw instances at most, no new material or shader, no prewarm gap (judgment). They share one mesh, so the renderer can batch or instance them; the cost is small against the budget.
 - Blocks moved onto the track centres: a position change only, so no change to the collider count or the nav grid size beyond the five cabinet colliders (judgment).
Advisory:
 - tools/subway/layout.py:193-200, five extra cabinets add five more static bodies and five more prop nodes. If the owner's Low-preset run shows draw-call pressure in the tunnel, these are the first thing to merge into a MultiMesh (judgment).
 - Re-measure the node count, orphans and draw calls once check.sh and a rendered run are available; the subway map now has more prop nodes than at 15144d7.
Fixes: none needed.
Unexplained: none
