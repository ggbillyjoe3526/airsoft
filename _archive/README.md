# Archive

Files nothing in the game, the tests or the tools uses any more, kept in case they are wanted again (the Dev 3 audit,
`AUDIT_REPORT.md`). Each keeps its folder path from the repository root, so moving it back restores it. Godot skips
this folder (`.gdignore`) and no export includes it. To delete a file for good, remove it and its line here.

| Moved | File | Was | Why it is not used |
|---|---|---|---|
| 2026-11-14 | `game/play/replica_wear.gdshader` (and its `.uid`) | The worn-paint shader on painted replica surfaces (RW1) | Replaced by `game/play/replica_surface.gdshader` in MQ1 (steel, aluminium and polymer under any paint, the wear mask read there); no script, scene or resource names its path or its uid since. `docs/records/MQ1.md` left it for the pre-release sweep |
| 2026-11-15 | `assets/models/props/escalator_upper.glb` (and its `.import`) | Subway's upper escalator bank, ticket hall to concourse (SM2) | SW1 put the ticket hall on the concourse's level (the owner, 2026-11-15), so the upper escalators' room and its model's dress went; `tools/blender/maps/escalator.py` builds only the lower bank now (the upper one's `build("esc_up", "escalator_upper")` call and an `esc_up` room in `tools/subway/layout.py` bring it back) |
| 2026-11-22 | `tools/thicket_opacity.gd` (and its `.uid`) | The thickets' colliders against their spruces as drawn (TV1), what TV1's tier reaches were picked from | WH1's `tools/sight_truth.gd` measures every plant on Woodland as drawn, its leaf cards cut out of their sheet (WQ1), and picked the tiers since; this one counts the cards' whole quads as boughs |
