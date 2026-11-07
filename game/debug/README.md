# game/debug

Developer tooling that ships in every build but costs nothing until switched on (CLAUDE.md › Code Standards). Reads the
simulation's state; writes none of it. The debug keys F3, F4 and F5 are the `debug_*` input actions and
`KeyBindings.UNBINDABLE`, so settings can't rebind them.

| File | What |
|---|---|
| `debug_perf.gd` | `DebugPerf`: the F3 overlay (FPS, frame time, draw calls, nodes, orphans) and, in a match (`watch`), its seed, your position and the entity count; `--perf` logs |
| `debug_view.gd` | `DebugView`: F4 draws each BB's recent flight, F5 the hit volumes of characters in play; its buffers and meshes exist only while a draw is on, and nothing processes while both are off |
| `bb_trails.gd` | `BBTrails`: a ring buffer of recent positions per BB slot, cleared when the BB dies or the slot gets another |
| `hit_shapes.gd` | `HitShapes`: wireframe capsules and spheres for a `Hitbox.Volume` |
| `debug_lines.gd` | `DebugLines`: an ImmediateMesh of coloured lines redrawn per frame (the F5 hit volumes) |
| `debug_ribbons.gd` | `DebugRibbons`: the F4 trails as camera-facing ribbons a few pixels wide, one ArrayMesh surface built per frame from kept packed arrays |
| `launch_seed.gd` | `LaunchSeed`: the `--seed <n>` launch option, and a fresh seed otherwise |

Tuning: `DebugViewConfig` (`game/config/debug_view_config.gd`). Tests: `test_debug_view.gd`, `test_bb_trails.gd`,
`test_launch_seed.gd`.
