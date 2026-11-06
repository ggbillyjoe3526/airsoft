Task: none (BP5 bug pass part 1) · head c8a6146 · Verdict: Pass

Run: no `--perf` bot match (the diff read, test_bp5 8/8 and test_bp5_qa 9/9 run). No baseline: judged against the
targets and the diff.

Blocking findings: none.

Per-tick sim path:
- Grenades' held-trigger rule: one bool check per character per tick; while the pull is held it copies the command
  into the simulation's preallocated buffer (PlayerCommand.copy_from assigns scalars only). No allocation.
- take_torch_back is a bool read and write; Torch.step gains one default parameter and one branch.
- simulation.gd adds one local bool.

Freed nodes and resources:
- loadout_gear.gd: two Labels, children of the key chips, freed with the panel; refresh() adds two key-name lookups
  when the page shows, not per frame. No signals added.
- sim_audio.gd: one push_warning per bed at the ambience's start; records.gd: one comparison on load.

Assets: the six human_bot_human_v12_* textures go, nothing references them (install size and VRAM down).

Advisory: the old pipeline/out/qa logs deleted in a code PR (harmless).

Verdict: Pass
