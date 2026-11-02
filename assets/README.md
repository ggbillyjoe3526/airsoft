# Assets

| Folder | Holds |
|---|---|
| `models/characters/` | The rigged human and robot figures with their sidecars (`tools/blender/bot-figure/` builds them) |
| `models/replicas/`, `models/replicaParts/` | The AEG, GBB Pistol and Cyber Pistol, and their fittable parts |
| `models/powerSources/` | The batteries and the gas bottle shown in the loadout |
| `fonts/` | Inter (SIL OFL 1.1, `fonts/OFL.txt`), the HUD and menu font |
| `ui/` | The title's backdrop, `title-backdrop.jpg`: a blurred, darkened still of Depot, our own render of the build |
| `maps/` | One picture of each match field for the Match page and the loading screen, each field from a player's eye height by `tools/eye_pictures.gd`, the range by `tools/map_pictures.gd` (our own renders; see `docs/ASSETS.md` for re-running them) |
| `maps/bakes/` | Each map's baked light (`BakedLight`, binary `.res`), written by `tools/bake_light.gd` (our own bake; `docs/ASSETS.md`) |
| `audio/` | The rendered sounds and ambience loops (`audio/README.md`) |

All from the browser game at `0.1-beta.1` (2026-10-18). Every file is logged in `docs/ASSETS.md`; commit each one's
`.import` file with it.
