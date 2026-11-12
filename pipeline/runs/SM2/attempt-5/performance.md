Task: SM2 · head db1ceb9 · Verdict: Pass
Run: no headless run (delta is instance colours on one static MultiMesh and model tweaks; no GPU in the cloud) · budget: no baseline yet, judged against targets and attempt 4 (70f791f)
Metrics: draw calls unchanged vs attempt 4 (LandingLights was already one MultiMesh draw; judgment, not rendered); nodes unchanged; lit model 114 / 200 tris (ok); leaf half pane 44 tris; escalators 7,412 and 6,764 of 8,000 (counts unchanged, ok).
Regressions (> 10 % worse): none measured
Blocking findings: none
 - lift_view.gd:105 LandingLights now uses use_colors=true; the shared _button_material already has vertex_color_use_as_albedo (line 78), so no new material and the prewarm list (line 176) still covers it (judgment).
 - Instance colours are set once in the build loop (set_instance_color), no per-frame or per-tick work, no new allocation in a hot path; the one Color glow is built once per view (judgment).
 - HDR colour above 1 (lit x 2.5, lift_view_config.gd landing_lit_gain): instance colour is a per-instance float attribute, so >1 costs nothing extra on the unshaded material. Visible glow past the tone map only if the Environment/preset has HDR/tonemap; if a Low preset uses a clamped 8-bit target it just saturates, no cost (judgment).
 - No nodes, timers, tweens or connections added; the MultiMesh is freed with the view.
Advisory: instance colour buffer adds 16 bytes per landing instance (negligible). Escalators are still 93 % of the tri cap. Glow bloom, if the owner later adds it, would be a preset item.
Unexplained: none
