Task: UB1 · head cd11836 · Verdict: Pass
Run: none (not run; diff is UI-only, the full check.sh was running elsewhere) · budget: no baseline yet, judged against targets and origin/main (86ee6c4) by reading the diff
Metrics: not measured (no --perf run this pass); all findings are judgment
Regressions (> 10 % worse): none measured
Blocking findings: none
Advisory:
- game/ui/button_press.gd:36-42 (judgment) node_added runs per node during play; non-buttons cost one cast and return, no allocation. Only buttons bind a Callable (menu construction, not hot play). Same cost class as TooltipWrap.
- game/ui/button_press.gd:46-52 (judgment) per press: ring built once per button (one StyleBoxFlat, one Control) and freed with the button; one Tween per press, the previous killed first (line 83). No get_children, no teardown leak: the button_down connection lives on the button.
- game/ui/button_press.gd:41 (judgment) is_connected on a fresh bind relies on Callable equality (bound target and args); the test in tests/unit/test_button_press.gd should cover re-add, so no duplicate connections.
- game/ui/button_press.gd:32-34 (judgment) install does one find_children walk at boot (main.gd), one-off.
- game/ui/nav_rail.gd:135-146 (judgment) set_level adds a theme override and sets a tooltip per call, only on menu events; negligible.
- No new shader or particle, so no prewarm entry needed. No quality-preset bypass.
Fixes: none required. Optional: cache the bound Callable not needed; skip.
Unexplained: none
