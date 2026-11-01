# Assets

The register of every external asset in the game: name, source URL, licence and author. Only CC0 or clearly permissive
licences. No real brand names or trademarked replica designs.

## External assets

The menus' fonts, Depot's two photo texture sets (its temporary site dress, DD1) and its five CC0 prop models (DR2)
are the only external files. The game's own models and sounds (made for it, listed below) are the only other asset
files; there are no external sounds yet. The rest is greybox geometry and materials made in Godot.

CC0 models and textures can replace parts of this later. Record each one here, one row per file, in the format below
([CC0_ASSETS.md](CC0_ASSETS.md) is the how-to). A player model goes in `assets/models/characters/`, a replica's in
`assets/models/replicas/<replica id>.glb`.

| File | Asset | Source URL | Licence | Author |
|---|---|---|---|---|
| `assets/fonts/Inter-500.woff2`, `Inter-600.woff2`, `Inter-700.woff2`, `Inter-800.woff2` | Inter (Medium, SemiBold, Bold, ExtraBold; latin subset, from @fontsource/inter 5.3.0), the menus' and the HUD's face for all text and numbers (M100; replaces Barlow and Barlow Condensed, owner 2026-10-07) | https://github.com/rsms/inter | SIL OFL 1.1 (`assets/fonts/OFL.txt`) | Rasmus Andersson, The Inter Project Authors |
| `assets/textures/site/concrete_floor_02_diff_1k.jpg`, `concrete_floor_02_nor_gl_1k.jpg` | Concrete Floor 02, 1K colour and OpenGL normal: the photo in Depot's slab and loading dock (DD1; VRAM compressed with mipmaps, 2.1 MB imported). Fetched from a GitHub mirror (github.com/hakyong-tae/game-asset-library-3d, `packs/ph`) as the cloud can't reach the site; noted in `assets/textures/site/LICENSE.txt` | https://polyhaven.com/a/concrete_floor_02 | CC0 1.0 | Poly Haven |
| `assets/textures/site/plywood_diff_1k.jpg`, `plywood_nor_gl_1k.jpg` | Plywood, 1K colour and OpenGL normal: the grain in Depot's plywood walls (DD1; as above, 2.1 MB imported) | https://polyhaven.com/a/plywood | CC0 1.0 | Poly Haven |
| `assets/models/props/barrel.glb`, `drum.glb` | Barrel (Kenney Survival Kit, `survival/barrel.glb`, 412 triangles): Depot's raspberry steel barrels and teal fibre drums (DR2), recoloured by `tools/props/build_props.py` into vertex colours (no texture; 31 KB each). Fetched from the Kenney library's GitHub mirror at commit 3694c68 (kenney.nl is blocked in the cloud); its `LICENSE.txt` is `assets/models/props/License-Kenney.txt` | https://kenney.nl/assets/survival-kit (mirror: https://github.com/shorepine/kenney) | CC0 1.0 | Kenney |
| `assets/models/props/pallet.glb` | Pallet (Kenney Retro Urban Kit, `retro-urban/pallet.glb`, 84 triangles): under Depot's drums, recoloured as above (9 KB) | https://kenney.nl/assets/retro-urban-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/sofa.glb` | Lounge Sofa (Kenney Furniture Kit, `furniture/loungeSofa.glb`, 128 triangles): the Lounge's sofa, recoloured as above (18 KB) | https://kenney.nl/assets/furniture-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/shelf.glb` | Shelf with boxes (Kenney Mini Market, `mini-market/shelf-boxes.glb`, 436 triangles): the shelving lining Depot's racking, recoloured as above (41 KB) | https://kenney.nl/assets/mini-market (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/trunk.glb`, `log.glb` | Log (Kenney Nature Kit, `nature/log.glb`, 200 triangles): Woodland's tree trunks (stood on end) and its fallen logs (WR3), recoloured as above (28 KB each) | https://kenney.nl/assets/nature-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/logstack.glb` | Large log stack (Kenney Nature Kit, `nature/log_stackLarge.glb`, 310 triangles): Woodland's log piles and cordwood (WR3), recoloured as above (48 KB) | https://kenney.nl/assets/nature-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/pine.glb` | Tall pine (Kenney Nature Kit, `nature/tree_pineTallA.glb`, 78 triangles): the spruces of Woodland's thickets (WR3), recoloured as above (13 KB) | https://kenney.nl/assets/nature-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/tyre.glb` | Debris tire (Kenney Car Kit, `car/debris-tire.glb`, 288 triangles): Woodland's tyres and tyre stacks (WR3), laid flat, recoloured as above (24 KB) | https://kenney.nl/assets/car-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/crate.glb` | Large box (Kenney Survival Kit, `survival/box-large.glb`, 124 triangles): Woodland's crates (WR3), recoloured as above (12 KB) | https://kenney.nl/assets/survival-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/truck.glb` | Truck (Kenney Car Kit, `car/truck.glb`, 2,082 triangles): Woodland's truck (WR3), violet body, recoloured as above (153 KB) | https://kenney.nl/assets/car-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/car_crimson.glb`, `car_lilac.glb`, `car_grey.glb` | Sedan (Kenney Car Kit, `car/sedan.glb`, 2,032 triangles): The Street's parked cars (ST2), body repainted over the source's orange in a palette colour, sea-green glass, grey trim, dark tyres, recoloured as above (about 150 KB each) | https://kenney.nl/assets/car-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/car_teal.glb`, `car_yellow.glb` | Sports hatchback (Kenney Car Kit, `car/hatchback-sports.glb`, 2,088 triangles): The Street's parked cars (ST2), recoloured as the sedans (about 170 KB each) | https://kenney.nl/assets/car-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/car_cream.glb`, `car_green.glb` | SUV (Kenney Car Kit, `car/suv.glb`, 2,474 triangles): The Street's parked cars (ST2), recoloured as the sedans (about 180 KB each) | https://kenney.nl/assets/car-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/van_cream.glb`, `van_plaster.glb`, `van_teal.glb`, `van_grey.glb` | Van (Kenney Car Kit, `car/van.glb`, 2,082 triangles): The Street's vans (ST2), body repainted over the source's blue, recoloured as the sedans (about 155 KB each) | https://kenney.nl/assets/car-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/lorry_crimson.glb`, `lorry_teal.glb`, `lorry_cream.glb` | Delivery truck (Kenney Car Kit, `car/delivery.glb`, 2,476 triangles): The Street's box lorries (ST2), box repainted over the source's green, a cream cab, recoloured as the sedans (about 205 KB each) | https://kenney.nl/assets/car-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/bin_green.glb`, `bin_steel.glb`, `bin_teal.glb` | Trashcan (Kenney Furniture Kit, `furniture/trashcan.glb`, 68 triangles): The Street's bins (ST2), two a bin block, recoloured as above (12 KB each) | https://kenney.nl/assets/furniture-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/skip.glb` | Closed dumpster (Kenney Retro Urban Kit, `retro-urban/detail-dumpster-closed.glb`, 22 triangles): The Street's skips (ST2), yellow, recoloured as above (8 KB) | https://kenney.nl/assets/retro-urban-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/lamp.glb` | Square street light (Kenney City Kit Roads, `city-roads/light-square.glb`, 60 triangles): The Street's lamp posts (ST2), steel, recoloured as above (8 KB) | https://kenney.nl/assets/city-kit-roads (mirror as above) | CC0 1.0 | Kenney |
| `assets/models/props/settee.glb`, `table.glb`, `units.glb`, `fridge.glb` | Lounge Sofa, Table, Kitchen Cabinet and Kitchen Fridge (Kenney Furniture Kit, `furniture/loungeSofa.glb`, `table.glb`, `kitchenCabinet.glb`, `kitchenFridge.glb`; 128, 120, 114 and 250 triangles): the House's settees, dining table, kitchen units and fridge on The Street (ST2), recoloured as above (12 to 44 KB each) | https://kenney.nl/assets/furniture-kit (mirror as above) | CC0 1.0 | Kenney |
| `assets/fonts/Inter-marks-500.woff2`, `Inter-marks-600.woff2`, `Inter-marks-700.woff2`, `Inter-marks-800.woff2` | Inter's three symbols the latin subset lacks, ← → ✓ (about 0.6 KB a weight; cut from the same four weights of Inter 4.1.1 in the `inter-ui` npm package, because `@fontsource/inter` 5.3.0 has no subset with them), a fallback for the four weights above (M100) | https://github.com/rsms/inter | SIL OFL 1.1 (`assets/fonts/OFL.txt`) | Rasmus Andersson, The Inter Project Authors |

**Made for the game** (original work, no external source; licensed with the game's code):

| File | Asset | Made with | Author |
|---|---|---|---|
| `assets/ui/title-backdrop.jpg` | The title's backdrop (MN1): a 1920x1080 still of the current build's Depot, blurred and darkened; our own render, no outside asset (re-render: play the build, capture a frame, blur it by hand; `docs/records/MN1.md`) | Godot 4.7 (the game's own render), blurred in the concept step | Claude for William (owner) |
| `assets/maps/depot.jpg`, `assets/maps/woodland.jpg`, `assets/maps/street.jpg`, `assets/maps/range.jpg` | The Match page's map cards and the loading screen's backdrop (MN2, RG4): each field from a high three-quarter camera, the range from its firing line looking downrange with its targets and markings standing, 700x400, JPEG quality 0.85; our own render, no outside asset. To re-render after a map or the greybox changes: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/map_pictures.gd` (optionally `-- <folder> <map id>`), then `godot --headless --path . --import` and commit the pictures with their `.import` files. A map that can't load is skipped | Godot 4.7 (the game's own render), `tools/map_pictures.gd` | Claude for William (owner) |
| `assets/maps/bakes/depot.res`, `assets/maps/bakes/range.res` | Each map's baked light (DP2): per vertex of its greybox cut into 0.5 m tiles, the sky it sees and the sun's one bounce (Depot 48 KB, the range 7 KB, compressed); our own bake, no outside asset. To rebake after a map's blocks, MapStyle's colours, the sun or BakeConfig's bake settings change: `godot --headless --path . -s res://tools/bake_light.gd` (optionally `-- <map id>`), and commit the files; `tests/unit/test_baked_light.gd` fails a stale one | Godot 4.7 (TriangleMesh rays), `tools/bake_light.gd` | Claude for William (owner) |
| `assets/models/replicas/cyber.glb` | The Cyber Pistol redesigned from the owner's reference pictures (RM5, 2026-10-12; first made in M101, RM1, 2026-10-10): in the hands (2,688 triangles) with its magazine, slide, trigger and fire selector, its figure version (148 triangles), and its fire, selector, reload and inspect animations | Blender 5.2, built through the owner's Blender connection; source `cyber_pistol_v2.blend` kept by the owner | Claude for William (owner) |
| `assets/models/replicas/aeg.glb` | The AEG rifle redesigned from the owner's reference photos (RM6, 2026-10-12; first made in RM1, 2026-10-10): in the hands (8,090 triangles) with its magazine and flash hider, its figure version (252 triangles), and eight moving parts with their animations: trigger, fire selector, folding sights, magazine release, charging handle, dust cover, hop-up dial | Blender 5.0, built from scripts in a separate Blender (not the owner's); source `aeg_rifle_v2.blend` kept by the owner | Claude for William (owner) |
| `assets/models/replicas/pistol.glb` | The GBB Pistol redesigned from the owner's six reference photos (RM7, 2026-10-12; first made as the gas pistol in RM1, 2026-10-10): in the hands (3,190 triangles) with its magazine, slide, trigger and magazine release, its figure version (180 triangles), and its fire (the blowback), reload, inspect and slide-lock animations | Blender 5.2, as above; source `gbb_pistol.blend` kept by the owner | Claude for William (owner) |
| `assets/models/powerSources/standardBattery.glb`, `lipoBattery.glb`, `gasBottle.glb` | The menus' pictures of the Standard Battery (744 triangles), the 11.1 V LiPo Battery (484) and the gas bottle (808; its `Label` is painted per gas: Green, Red and Black Gas) in Customise, the Loadout and the Armory (RM3, 2026-10-10) | Blender 5.2, as above | Claude for William (owner) |
| `assets/models/characters/human.glb`, `robot.glb`, with `human.json`, `robot.json` | The rigged bot figures (BF1, approved by the owner 2026-10-12): a human player, redesigned from the owner's reference photos (RM9, approved 2026-10-13: 19,966 triangles with the largest of its four heads, a texture atlas baked from procedural materials in Blender) and a bare robot (19,308, team-colour panels; its textures, canvas, ripstop and stipple weaves, generated in Blender), each with LOD1 and LOD2 meshes, a 65-bone skeleton and 32 clips (moving, aiming, reloads, the switch, the hit call, the walk-off, the trigger press, resting on cover, the vault); the browser game's packed files unpacked once for Godot | Blender 5.2, from the scripts in `tools/blender/bot-figure/` | Claude for William (owner) |
| `assets/models/replicaParts/aeg.glb`, `pistol.glb`, `cyber.glb` | The fittable parts: the AEG's red dot, 2x scope, two foregrips, long and tight-bore barrels, silencer, weapon torch, low-cap and hi-cap magazines; the GBB Pistol's laser, torch, silencer and extended magazine (RM1, 2026-10-10; refitted to the GBB Pistol in RM7, 2026-10-12); the red dot, 2x scope, silencers and torches redesigned and the Cyber Pistol's torch added (RM8, 2026-10-12, built headless in Blender 5.0; source `attachments_v1.blend` in the project files); the 2x scope given a dark core behind its glass (PT1, 2026-10-13; source `attachments_v2.blend`) | Blender 5.2, as above | Claude for William (owner) |

The font ships inside the game's export. Its licence ships in `THIRD_PARTY_NOTICES.txt` (Libraries and add-ons, below).

## Made by the project

- **Sounds:** 78 sounds (372 variants) and 4 ambience loops rendered once from the browser game's synthesis recipes, in
  `assets/audio/` (`assets/audio/README.md`). No outside source; same licence as the code. They are replaced with CC0
  or recorded sounds later.
- **The referee's whistle:** `assets/audio/cues/whistle_short_1.wav` to `_3` and `whistle_long_1.wav` to `_3`, the
  browser game's live pea whistle rendered by our own `tools/render_whistle.gd` from SoundConfig's whistle numbers
  (SP3, 2026-10-22), and `ping_pip_1.wav`, the ping's pip from the same tool (PN2, 2026-10-26). No outside source; same licence as the code. To re-render after those numbers change:
  `godot --headless --path . -s res://tools/render_whistle.gd`, then `godot --headless --path . --import`, and commit
  the files with their `.import` files.
- **The smoke and flash bombs' sounds:** `assets/audio/cues/grenade_pin_1.wav` to `_3`, and the same three of
  `grenade_bounce`, `smoke_pop` and `flash_bang`, synthesised by our own `tools/render_grenades.gd` (SF1, 2026-10-30).
- **The doors' sounds:** `assets/audio/cues/door_open_1.wav` to `_3` and `door_shut_1.wav` to `_3`, synthesised by our
  own `tools/render_doors.gd` (DO1, 2026-10-31).
  No outside source; same licence as the code. Re-render them the same way as the whistle, with that tool.
- **Art references:** the owner's six reference pictures of the target look and his arm and hand study
  (owner-supplied, 2026-10-18), in `docs/art/references/` (`docs/ART.md` › The target). Not game assets: Godot
  ignores the folder and no export ships it.
- **Map layouts:** the range, exported as data from the browser game's map code to `data/maps/*.json`; Depot,
  Woodland and The Street, the owner's concepts written to that folder by `tools/depot/`, `tools/woodland/` and
  `tools/street/` (DR1, WR1, ST1). Same licence as the code.

## Libraries and add-ons

| Name | Version | Licence | Use |
|---|---|---|---|
| Godot Engine | 4.7.2 | MIT | The engine |
| GUT (Godot Unit Test) | 9.7.1 | MIT | Unit tests, in `addons/gut/`; tests only, never exported |
| gdtoolkit (gdlint) | 4.5.0 | MIT | Lint; CI only, installed with pip, not in the repo |
| Inno Setup | 6 | Inno Setup License (permissive) | Builds the Windows installer; CI only, not in the repo |

Every export ships `THIRD_PARTY_NOTICES.txt`, written by `tools/make_notices.gd` from the licence files in its
`SHIPPED` list (each font, asset licence and add-on that ships); CI fails if it is stale. The credits screen shows Godot's
own licence and its third-party notices from `Engine.get_license_text()` and `Engine.get_copyright_info()`. Dev and
test add-ons never ship, so they aren't in it.

## Adding a library or tool

Every third-party add-on, tool or asset follows these rules (owner, 2026-10-18).

1. **Named source, pinned version.** Godot add-ons come from the Godot Asset Library or a pinned upstream release.
   Copy only the add-on's own folder, whole, into `addons/<name>/`, never the whole repo or a submodule.
2. **Licence file inside the folder.** Keep the add-on's `LICENSE` in `addons/<name>/` (copy it in if the repo keeps it
   at the root).
3. **A reason in the pull request.** Say why it is needed (CLAUDE.md §8). The fixed stack (CLAUDE.md §3), the nav grid
   and the sounds change only with the owner.
4. **A row here.** Add it to Libraries and add-ons (name, version, licence, use) in the same pull request. If it ships,
   add its licence file to `SHIPPED` in `tools/make_notices.gd` and regenerate `THIRD_PARTY_NOTICES.txt`.
5. **Dev-only code stays out of the release.** Debug and test add-ons are excluded in every export preset's
   `exclude_filter` (`export_presets.cfg`), so they never reach players and need no notice.
6. **Tools stay out of the repo.** MCP servers, editors, Blender add-ons and asset tools are installed on the owner's
   PC. Only what they make (models, textures, sounds) comes into the repo.
7. **No GPL or LGPL code in the game.** GPL programs are fine as tools, but none of their code is in the game: GPL
   would make the whole game GPL, and LGPL can't practically be complied with in an exported game.
8. **Assets carry their own licences.** CC0 or clearly permissive only (CLAUDE.md §4), each with its source URL,
   licence and author in External assets. For anything an AI model made (a mesh, a voice, music), the trained model's
   licence decides, not the repo's.
9. **Within the budgets.** Anything that ships fits the install size budget the owner sets and passes the performance
   agent.

## Do not use

They look free, but their terms conflict with releasing the game. Never recommend or install them.

| Repo or source | Why not |
|---|---|
| coqui-ai/TTS's XTTS-v2 voices | The model is under the Coqui Public Model License: non-commercial use of it and its output only, and Coqui has shut down, so no other licence can be bought |
| Piper voices (OHF-Voice/piper1-gpl) | Each voice has its own licence in its `MODEL_CARD`, some restrictive; use one only after checking that voice's licence |
| microsoft/TRELLIS and TRELLIS.2 | The repo is MIT, but it depends on nvdiffrast, licensed for research and evaluation only |
| Tencent-Hunyuan/Hunyuan3D-2 and 2.1 | The licence excludes the EU, the UK and South Korea; this includes the Blender connection's Hunyuan3D option |
| facebookresearch/audiocraft (MusicGen) | The code is MIT, but the trained models are CC BY-NC 4.0 (non-commercial) |
| Sketchfab and Poly Pizza models | Licences vary per model: some need credit, some ban commercial use; use one only after checking that model's licence |

## Licences: what each asks

What a licence needs in the repo and in the shipped game. A guide, not legal advice.

| Licence | In the repo | In the shipped game |
|---|---|---|
| MIT, ISC | Keep the add-on's `LICENSE` inside its folder | Its copyright line and licence text in `THIRD_PARTY_NOTICES.txt` |
| Apache-2.0 | Mark any file you change | As MIT, plus the project's `NOTICE` text if it has one |
| SIL OFL 1.1 | Keep `OFL.txt` beside the font files | Its text in `THIRD_PARTY_NOTICES.txt`; never sell the font alone, and rename it if modified |
| Zlib, CC0, Unlicense | Keep any notice already in the source | Nothing; credit is optional |
| CC BY | A row in External assets | Credit the creator |
| GPL, LGPL | Tools only; never copy their code in | Nothing, as long as none of their code is in the game |
