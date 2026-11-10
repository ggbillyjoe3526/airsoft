Task: RW1 · head 532010e · Verdict: Pass
Run: no --perf run (static review while tools/check.sh ran) · budget: no baseline yet, judged against targets and origin/main
Metrics: not measured (no GPU). No new nodes. Triangles unchanged (replica 40k budget holds; AEG vertices 40,051 ->
~45,000 from UV seams; figure copy 3,000). Install about +5 MB glb and +3.4 MB png of 500 MB. Two 2048 BPTC masks,
about 10.6 MB VRAM.
Regressions (> 10 % worse): none measured.
Blocking findings: none.
- replica_wear.gdshader: one texture sample per fragment, a few mix and sqrt, no loops, discard or depth write (judgment).
- ReplicaPaint.apply / _worn_of run on setup and repaint, not per frame; one shared ShaderMaterial per (paint, mask);
  cache bounded (MAX_WORN 160) and cleared with clear(); views keep their own references, nothing leaks (judgment).
- ReplicaView._pressed_copy is cached per source material: one duplicate per view, no per-frame work (judgment).
- Bots' figure copies and mag tosses stay plain StandardMaterial3D: figure draw cost unchanged.
- play_session.gd prewarms worn_materials(); every replica and paint shares the one shader.
Advisory:
- A paint chosen later in a match builds a new ShaderMaterial on the compiled shader; check for no hitch on first swap
  to the AEG Rifle or GBB Pistol on the owner's hardware (judgment).
- replica_view.gd _pressed / _pressed_from never cleared (pre-existing), bounded by distinct materials.
- On Low the mask is still sampled with look_wear 0.
- Masks embedded in the glbs duplicate the PNGs (install size only).
Fixes: none required.
Unexplained: none. A --perf pair on the owner's machine would confirm node, orphan and static memory counts.
