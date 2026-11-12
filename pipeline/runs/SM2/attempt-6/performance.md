Task: SM2 · head f450d2b · Verdict: Pass
Run: smoke test (headless, GPU-less); diff 7b85ac5..f450d2b reviewed · budget: no baseline yet (perf-budget.json absent), judged against targets and attempt 5
Metrics: smoke ok (819 frames, zero script errors); glb triangle counts unchanged (7412, 6764, 5854, 1968, landing 732, lit 114); escalator glbs ~10 KB smaller each (judgment: shared-vertex deck strip). Draw calls/frame times: not measurable here.
Regressions (> 10 % worse): none
Blocking findings: none
Advisory:
- game/play/site/prop_dress.gd:104-109 materials() returns every keyed material, built once per model at build() time (cached in _materials), so the new full_colour variant (key z=1) is included in the warm-up list (judgment). keep_by_alpha is a uniform, not a shader define, so no new pipeline compile; the warm-up of the variant is cheap insurance.
- prop_dress.gd:105 builds one Vector3 key per model at build time only, not per frame: no hot-path allocation (judgment).
- One extra ShaderMaterial on Subway (4 full_colour models share it): small, one more draw-state change only (judgment).
- prop_dress_config.gd:373 full_colour.has() is a 4-entry array scan at build time only.
Fixes: none needed
Unexplained: none
Pass
