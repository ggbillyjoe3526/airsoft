Task: SL4 · head 3e9bf5e · Verdict: Pass
Run: no --perf run made (see Unexplained) · budget: no baseline yet, judged against targets and origin/main's diff
Metrics: not measured. A headless --perf pair (head plus an origin/main worktree, each needing a full project import) would compete with the two `godot --import` processes already running in this box (load ~1, 5 % RAM each) and would skew script-time comparison. The diff adds no node, process or tick code, so node, orphan and memory counts cannot change from it.
Regressions (> 10 % worse): none measured
Blocking findings: none
Advisory (judgment):
- game/play/replica_paint.gd: new drawn() / paint_saturation() (a ProjectSettings read, a Color lerp) run only when a paint's material is built, and at game/ui/customise_view.gd:675 once per swatch when the screen builds. Materials stay cached and shared (ReplicaPaint.clear() at play_session.gd:1615 is unchanged). No per-frame or per-tick path calls them.
- Roughness 0.5 to 0.64 and 0.4 to 0.48 are constants; no new material, particle or shader, so no prewarm entry is needed.
- game/ui/game_theme.gd: Color constants only (DEEP, PLATE added); the navy_box to dark_box rename is a rename. No new allocation, node or connection; no preset bypass.
- Tests only otherwise.
Fixes: none needed
Unexplained: none; the measured run is skipped for the contention above, not for a failure. Run `godot --headless --path . -- --smoke --perf` (and F3 in game) on the owner's PC if wanted.
