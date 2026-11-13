Task: SM1 · head 66f718e (since 865ea19) · Verdict: Pass
Run: static diff review plus GUT test_field_layout (15/15, 31 s, includes field_measure routes with vaults); no GPU, no `pipeline/perf-budget.json` yet, so judged against DECISIONS.md › Performance budgets (150 draw calls High, 1.5M triangles, 60 FPS Low) and the earlier Pass.

Metrics (judgment unless noted): new triangles worst case on Subway: bogies 4 x 2,920 = 11.7k; ends grew by about 1k to 1.5k each (cab 3,909, open cab 3,356, outer 2,361, end 1,316, gangway 2,702); bodies 14,742 x 6 = 88k (down from 15.5k x 6 = 93k). Net train total about 140k, unchanged (about 9% of 1.5M). Draw calls: +1 MultiMesh (bogie, via PropDress FIT, 4 instances), well under 150. Nodes: +1 once at build. Frame time: reported only, owner's hardware.

Regressions (> 10 % worse): none.

Blocking findings: none.
- No per-frame or per-tick work added: bogies are static PropDress instances; TrainView still has no `_process`.
- game/sim/vault.gd:66-67: one extra `_cast` only when the first face ray misses, on Jump presses and in NavVaults.link at load. The sim is allocation-free (scratch reused), and the extra ray is a level ray with no allocation. Load cost is bounded (about one extra ray per probed edge); the 31 s field-layout test shows no load blow-up, but the link time alone was not isolated (judgment).
- game/map/train_dressing.gd:62-68: `holds()` loops the cars through `_floor_y()` only for floor blocks inside a train box, once per block at StationSurface build (876 blocks, a few cars each): negligible, no allocation, load-time only.
- train_bogie is in prop_dress_config.gd's prop list, so it goes through the existing PropDress path and the shared material and prewarm; no new material or shader.
- tests/support/field_measure.gd is test-only.

Advisory:
- Car bodies (88k) and ends still cast shadows; check Low on the owner's hardware, with a preset shadow switch for the bodies as the first fix if it misses 60 FPS (unchanged from attempt 1).
- `_floor_y()` could be cached in a field if cars ever grow; not needed now.
- Record Subway's first rendered draw-call and triangle baseline on the owner's hardware.

Unexplained: none
