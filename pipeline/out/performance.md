Task: MB3 · head a63ac0e + uncommitted tree · Verdict: Pass
Run: no bench (judgment from the diff and call sites; the machine is shared with measuring jobs, so any frame time would be noise) · budget: pipeline/perf-budget.json does not exist (no baseline yet), judged against targets and the diff against origin/main

Per-frame / per-tick paths in game/: none changed (judgment, from `git diff -- game/`).
- game/map/map_catalog.gd:29-65,139: new "Raise (s)" column read in parse(), once per catalog load (MapCatalog.shared() caches it). Entry.raise_time is one float.
- game/ui/match_options.gd:111-144: match_tuning and the new raise_time are static and plain; the Entry is read, no per-frame call.
- Call sites of match_tuning: game/play/play_session.gd:384 (_load_map, once per match load) and game/ui/match_page.gd:571 (a Match-page preview, on a pick, not per frame). The per-tick reader of the value is game/sim/flag.gd:100 (dt / cfg.raise_time), which is unchanged and reads a float from the same FlagConfig.
- Not re-made per round: _load_map runs once per match. The sim's round start does not call match_tuning.

Freed resources (judgment):
- match_tuning duplicates SimTuning and FlagConfig only when the field's raise differs, and RoundConfig only when size or length differ. All are Resource (RefCounted): no Node, Timer, Tween or connection involved. PlaySession._tuning holds the copy for the match; it is released with the session. The loaded shared tuning is never written (checks `t == base`, `t.flag == base.flag`).
- Allocation count: at most 3 small resources (SimTuning, RoundConfig, FlagConfig) per match load, plus one more SimTuning/RoundConfig at play_session.gd:388-389 (existing code, only when the countdown differs). Nothing grows.

Test support (never exported): tests/support/match_runner.gd sized_for adds one FlagConfig duplicate per call (not per tick). watch_flags (:569-574, called from _watch :581) loops one or two flags per tick with no allocation. It is not in the game and costs less than a microsecond per tick.
Tools: tools/map_heat.gd (+1 line), tools/wiki.py are dev tools, outside the game's frame.

Metrics: not measured (no GPU in the container; the frame-time, draw-call, node-count, orphan and memory figures are unchanged by construction, because no scene, node or per-frame code changed).
Regressions (> 10 % worse): none found (none measured)
Blocking findings: none
Advisory: none. (Shader prewarm and presets: no new material, particle or quality setting.)
Unexplained: none. Left unmeasured: a --perf run on head vs main, skipped by instruction under shared load; the diff shows nothing for it to find.
