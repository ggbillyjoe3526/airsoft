# Assets

| Folder | Holds |
|---|---|
| `models/characters/` | The rigged human and robot figures with their sidecars (`tools/blender/bot-figure/` builds them) |
| `models/replicas/`, `models/replicaParts/` | The AEG, GBB Pistol and Cyber Pistol, and their fittable parts |
| `models/powerSources/` | The batteries, gas bottle and springs shown in the loadout and the Armory |
| `models/grenades/` | The smoke and flash bombs, shown in a match and as the Loadout's and the HUD's bomb icons |
| `models/props/` | Map props, every one our own, built in Blender by `tools/blender/maps/` (the flagpole every map stands too) |
| `models/skyline/` | The Range's skyline buildings beyond the walls, drawn into the skyline's one mesh (`tools/blender/maps/skyline.py`; the shed in three sizes) |
| `fonts/` | Inter (SIL OFL 1.1, `fonts/OFL.txt`), the HUD and menu font |
| `ui/` | The crash screen's backdrop, `title-backdrop.jpg`: Depot's field picture blurred and darkened, no replica in it |
| `maps/` | One picture of each match field for the Match page and the loading screen, each from a player's eye height by `tools/eye_pictures.gd`, 1920x1080 (our own renders; see `docs/ASSETS.md` for re-running them) |
| `maps/bakes/` | Each map's baked light (`BakedLight`, binary `.res`), written by `tools/bake_light.gd` (our own bake; `docs/ASSETS.md`) |
| `audio/` | The rendered sounds and ambience loops (`audio/README.md`) |

The UI draws every replica, part, power source and bomb picture from these model files when it runs, so a new or
rebuilt model shows at once. A new model folder must be listed in `tests/unit/test_model_pictures.gd` (pictured, or
shown only in a match), or the build fails. Props show in the field pictures in `maps/`: re-render those after a prop
changes (`docs/ASSETS.md`).

All from the browser game at `0.1-beta.1` (2026-10-18). Every file is logged in `docs/ASSETS.md`; commit each one's
`.import` file with it.
