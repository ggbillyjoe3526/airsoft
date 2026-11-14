# Archive

Files nothing in the game, the tests or the tools uses any more, kept in case they are wanted again (the Dev 3 audit,
`AUDIT_REPORT.md`). Each keeps its folder path from the repository root, so moving it back restores it. Godot skips
this folder (`.gdignore`) and no export includes it. To delete a file for good, remove it and its line here.

| Moved | File | Was | Why it is not used |
|---|---|---|---|
| 2026-11-14 | `game/play/replica_wear.gdshader` (and its `.uid`) | The worn-paint shader on painted replica surfaces (RW1) | Replaced by `game/play/replica_surface.gdshader` in MQ1 (steel, aluminium and polymer under any paint, the wear mask read there); no script, scene or resource names its path or its uid since. `docs/records/MQ1.md` left it for the pre-release sweep |
