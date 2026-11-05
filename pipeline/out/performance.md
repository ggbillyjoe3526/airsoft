Task: GT1 · head 2287c84 · Verdict: Pass
Run: none (static reading of `git diff 06e75ef..HEAD`; no bench run, check.sh was running) · budget: pipeline/perf-budget.json does not exist, no baseline yet, judged against targets and the diff (judgment)
Metrics: not measured (no frame, node or memory numbers; judgment only)
Regressions (> 10 % worse): none measured
Blocking findings: none
- Allocations: FigureThrow.pose/_reach (figure_throw.gd:41-156) use only Basis/Quaternion/Transform3D/Vector3 values, no Array, Dictionary, String, lambda or Callable; the `push_warning` strings are in _init only (once a figure). FigurePose.read_throw (figure_pose.gd:135-150) is a few branches and float math, no allocation (judgment).
- Idle cost: FigureBend (figure_bend.gd:56) is one float and one bool compare when no bomb is thrown or held; FigureThrow.pose returns early at weight <= EPSILON (judgment).
- Active cost: a throw (~0.45 s) or a held bomb is two-bone IK on two arms (one on a held bomb) plus a spine twist, about 30 get/set_bone_global_pose calls and some quaternion math per figure per skeleton update; at 15 figures all throwing at once this is tens of microseconds in GDScript, and a typical match has one or two at a time. Fine (judgment).
- Nodes and resources: one MeshInstance3D "Bomb" per figure, a child of FigureHands (figure_hands.gd:153-165), freed with the body (`_body.free()` in set_body); set_bomb_meshes makes it once (guarded by `_bomb == null`), so no orphans. The Mesh is GrenadeView's shared one, never copied; no per-instance material, so no new material or resource to free (judgment).
- Draw calls: the bomb is visible only while thrown or held, no shadow (SHADOW_CASTING_SETTING_OFF); at most +15 draw calls and only in a throw or while a bomb is held. Hidden figures and fades call show_bomb(NONE), which hides it (figure_view.gd:343, 407). `show_bomb` assigns mesh/visible only on a change of kind, and `place` sets the transform only while visible (figure_hands.gd:247) (judgment).
- Prewarm and presets: no new material or shader; the bomb meshes use GrenadeView.materials(), already in the first_use prewarm list (play_session.gd:723-724). No preset bypass.
- Wiring: set_bombs runs after _figures exist (play_session.gd:720) and again on a new body in set_body (figure_view.gd:122-125), so no figure is left without meshes.
Advisory:
- figure_hands.gd:10-11 doc comment line runs past the line limit (style, not performance).
- No measured baseline: if the owner wants numbers, tools/figure_bench.gd never throws a bomb, so it does not cover the active path. A bench variant with every figure in `hand.throwing` would measure the worst case; not required for this verdict.
Fixes: none needed.
