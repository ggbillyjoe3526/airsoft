Task: GT1 attempt 2 · head de57ad5 · Verdict: Pass
Run: none (static reading of `git diff 2287c84..HEAD -- game`; no bench run, check.sh was running) · budget: pipeline/perf-budget.json does not exist, no baseline yet, judged against targets and the diff (judgment)
Metrics: not measured (judgment only)
Regressions (> 10 % worse): none measured
Blocking findings: none
- Allocations: right_pole, the extra left_key lerp and the throw_over branch in right_key (figure_throw.gd) add Vector3 lerps, a smoothstep and clampf: value types and float math, no Array, Dictionary, String, lambda or Callable (judgment).
- Extra weight() call: the left arm's weight(share, false, config) is a static call of a few float compares, once per throw pose per skeleton update (judgment).
- Idle cost: unchanged. FigureBend still tests one float and one bool, and pose returns at weight <= EPSILON; a held bomb skips the left arm (judgment).
- FigurePose.read_throw: one more bool local and a bool expression, no allocation; throw_from_hand is reset on every no-bomb return, so the flag cannot stick (judgment).
- FigureHands.set_bomb_meshes: now also sets mesh = null and visible = false, no new node or resource; it runs once per figure at set_bombs and on set_body, not per frame, and show_bomb reassigns on the next change of kind (judgment).
- Nodes, resources, draw calls, prewarm: unchanged from attempt 1; no new material, shader or node.
Advisory: none new. Still no measured baseline; tools/figure_bench.gd does not throw a bomb.
Fixes: none needed.
