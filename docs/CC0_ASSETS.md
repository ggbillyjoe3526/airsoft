# Using CC0 models and textures

How to bring free CC0 assets (public domain: free to use, change and ship, no credit required) into the game. Most of
the game is greybox or the project's own Blender models; this is the path for replacing parts of it with downloaded
art.

## Getting files into the repository

The cloud environment that builds the game can't reach the asset sites (its network policy blocks Kenney, ambientCG,
Poly Haven and Quaternius). A file reaches the repository one of two ways:

1. **Download it and commit it** (or upload it to the project and ask Claude to commit it). This always works.
2. **Allow the asset sites in the environment's network policy.** Then Claude can fetch, convert and commit files
   itself. Open Project settings › Cloud environment › the gear beside the environment › Network access, choose Custom
   and add `kenney.nl`, `ambientcg.com`, `polyhaven.com`, `quaternius.com` and their download hosts under Allowed
   domains. Steps: <https://code.claude.com/docs/en/cloud-environments#network-access>.

## Where to find CC0 assets

| Source | What's there | Good for | Notes |
|---|---|---|---|
| [Quaternius](https://quaternius.com) | Low-poly characters, many rigged and animated, plus props | **Player models** (the "Ultimate Modular Characters", "Universal Base Characters" packs) | glTF / FBX; small, stylised, fits the toy-like tone |
| [Kenney](https://kenney.nl/assets) | Low-poly kits: characters, props, crates, barriers, buildings | Props, map dressing, simple figures ("Blocky Characters", "Mini Characters") | glTF in most packs; tiny files |
| [Kay Lousberg](https://kaylousberg.com/game-assets) | Stylised low-poly packs (the free tiers are CC0) | Characters and props with a clean, toy look | Check each pack says CC0 |
| [Poly Haven](https://polyhaven.com) | Photo-scanned models, PBR textures, HDRI skies | Realistic props, surface textures, a sky | Heavy at 4K: take 1K or 2K |
| [ambientCG](https://ambientcg.com) | PBR texture sets (concrete, metal, wood, ground) | Surface textures for walls, floors, crates | Take the 1K or 2K JPG set |
| [OpenGameArt](https://opengameart.org) (CC0 filter) | Mixed | Odd one-offs | Licences vary per item: only take ones marked CC0 |

- **Prefer stylised low-poly** (Quaternius, Kenney, Kay Lousberg) to photo-scans. It matches the game's look, stays
  readable at a distance and keeps the install small.
- **No real brands or trademarked replica designs**, whatever the licence (CLAUDE.md §4).

## Formats

- **Models:** glTF binary (`.glb`), one file with the meshes, materials and textures inside. If a pack only has FBX or
  OBJ, open it in Blender (free) and export glTF 2.0, format "glTF Binary".
- **Compression:** export plain glTF, with no mesh compression (Draco or meshopt). Godot compresses the textures itself
  on import. The browser game's packed figures were unpacked once for Godot.
- **Textures:** the PBR metal-roughness set glTF uses.
  - Base colour (albedo), sRGB.
  - Normal map, OpenGL style (+Y up): ambientCG's `_NormalGL`, not `_NormalDX`.
  - ORM: ambient occlusion, roughness and metalness packed in the R, G and B channels (or separate roughness and
    metalness maps, which Blender packs on export).
  - 1K (1024 px) for props and figures, 2K at most for large surfaces. Power-of-two sizes. JPG for colour, PNG for
    normal maps.

## Folders and what Godot does with the files

```
assets/models/characters/             human.glb and robot.glb, the rigged figures, with their sidecars human.json
                                      and robot.json
assets/models/replicas/<id>.glb       a replica's model, by replica id: aeg, pistol and cyber
assets/models/replicaParts/<id>.glb   that replica's fittable parts, by replica id: aeg, pistol and cyber
assets/models/powerSources/<file>.glb the menus' battery, LiPo and gas bottle pictures
assets/models/props/                  the site's CC0 props (DR2), made by tools/props/build_props.py
assets/textures/                      loose surface textures (planned: not created yet)
assets/fonts/                         Inter and its OFL.txt
assets/audio/                         the sounds
tools/blender/bot-figure/             the Blender scripts that build the figures
```

- **Import.** Put the `.glb` in its folder. Godot imports it when the editor opens the project (or
  `godot --headless --import` in a cloud session) and writes a `.import` file beside it. Commit the `.import` (and
  `.uid`) files with the model; never the `.godot/` cache.
- **Collision.** Give collision its own mesh in Blender and name it with Godot's import suffix: `-colonly` for a
  collision box or mesh that isn't drawn, `-convcolonly` for a convex one (cheaper; use it for anything that isn't a
  wall or floor). The figures' hit shapes are set in the game's data, not from the mesh.
- **Textures.** Import as VRAM compressed, so a texture costs its compressed size in memory.
- **Sidecars.** The `.json` files beside the figures stay beside them: clip lengths, loops and speeds, `fitTo`, the
  first-person parts to hide, `replicaOnGrip` (where each replica sits on `Grip_R`) and `magazineInHand`.

The browser game's loader settings for every model (scale, facing, budgets) are in
`legacy/browser/src/config/assets.ts`.

### Figures

- **The rigged figures.** `human.glb` and `robot.glb` share a 65-bone skeleton, each with LOD1 and LOD2 meshes and 32
  clips. A new figure uses the same skeleton and clip names (`tools/blender/bot-figure/README.md`).
- **Scale and facing.** A figure stands as tall as the hit volume (1.73 m, feet to the top of the head; the hitbox
  doesn't change), measured on `body` and the legs when it has them, so a raised hand doesn't shrink it. Its feet sit
  on the ground. glTF models face +Z and the figures face -Z, so a model is turned a half turn unless it already faces
  -Z.
- **Team colours.** Any material whose name starts with `team` (for example `TeamTape`, `team_vest`) is painted in each
  figure's team colour (including the colour-blind palettes). Name the armband, vest or tape that way in Blender. The
  colour multiplies the material's texture, so give a team material a white or light grey base colour map (or none), or
  the team colour comes out dark and muddy.
- **A CC0 figure in parts.** A figure from a pack, without the rig, is split in Blender into objects named exactly as
  below, each moved like the part it replaces:

| Node name | What it is | Pivots at |
|---|---|---|
| `body` | Torso, head and kit: everything above the hips | Hips (drops when crouching, rolls when leaning) |
| `legL`, `legR` | Each leg, hip to boot (the model's left is `legL`) | Its hip (swings when walking) |
| `aimRifle` | Arms holding the rifle | The shoulder line (pitches with the aim) |
| `aimPistol` | Arms holding the pistol | The shoulder line |
| `hitPose` | Hit calling: one hand up, the replica hanging | Hips |

- **Authoring.** Author the parts in place, in one scene, standing as they would on the figure: metres, feet at the
  origin, +Y up. Parts can be nested (arms parented to the body in Blender is fine).
- **Leftover meshes.** Join any mesh in no named part (a head, hair or eyes kept as separate objects) into the part it
  should move with.
- **T-pose arms.** Pack characters often keep their T-pose arms as separate meshes. Delete them, or they show beside
  the aiming arms.

### Replica models

A replica's file is its model in the hands, on the menus' pictures and on the figures.

- **Space.** Metres, life size. The bore points along Blender's +Y (the game's -Z), up is +Z. The origin is where the
  frame meets the slide, above the trigger. The grip stays where the built-in pistols' is (raked back about 22°): the
  hands are posed in code.
- **Objects.** `Body` (needed), `Magazine` (drops out on a reload), `FlashHider` (shown while no muzzle device is
  fitted), `Figure` (the figures' cut-down version), and the empties `RearSight` and `FrontSight` (the iron sights'
  tops: aimed, the sight line runs through the eye), `Muzzle` (needed: the centre of the muzzle's face, where BBs
  leave), `TorchMount` and `SlideBack`. A rifle's figure is scaled so its butt-to-muzzle length is the
  figures' rifle length; a pistol's keeps its size, the back of the slide at the figures' grip: the `SlideBack` empty's
  depth, else the body's rearmost point at the bore's height or above (mark it when the frame reaches back past the
  slide, as the Cyber Pistol's rear block does).
- **Moving parts (RM1).** Objects the file's animations move hang from one bone (the armature's root) and are drawn in
  the body's own meshes, so they cost no draw call. The game poses them from its state, never on a clock: `Fire` (the
  trigger, and a pistol's slide kicking back and home, each shot), `Selector` (safe at 0, semi at half its length,
  burst at three quarters, auto at the end), `SightsFold` (while an optic is fitted), `Reload` (through the reload),
  `Inspect` (on the Inspect key, RM2) and `SlideLock` (RM7: held at its end while the magazine is empty, a GBB's slide
  caught back; put it after the others, as a later animation wins a part two of them move). The magazine is never a
  bone: the game moves it (and the hand holding it).
- **Parts.** `replicaParts/<id>.glb`: one top-level object per part named `<kind>_<id>` (`optic_redDot`,
  `magazine_hiCap`, `muzzle_silencer` …), in the replica's space where it fits; a child `<name>_Figure` is ignored. Two
  child empties are read (RM8): an optic's `<name>_SightLine` on its sight line (aimed, the replica is raised so it
  runs through the eye) and a torch's `<name>_UnderLaser`, where the torch moves while the laser is fitted too (both
  clip to the same rail).
- **Materials,** by name: `CyberSlab`, `CyberFrame`, `CyberLine`, `CyberCore`, `CyberMetal`, or a replica material's own
  name (`polymer`, `furniture`, `detail`, `metal`, `rubber`, `stipple`, `accent`). Plain colours: the game draws in its
  own materials, so Realistic colours, the glow and the High finish apply. No textures needed.
- **Budget.** As Size limits, below: the hands model is the detailed one, the figure version its LOD. Textures are
  allowed (2K); plain colours still work.
- **Muzzle.** Leave it plain: the orange-tip setting adds the tip.

### Power-source models

Menu pictures only (RM3): a power source never shows in a match (gas is full at the start, batteries sit inside the
replicas). Each power source, by its pool ID, is drawn from one file.

- **Space.** Metres, life size, any way up: the picture frames whatever shows, from the same studio view as the
  replicas'. A file can be tipped for its picture (the stick batteries are tipped up their lead end).
- **Materials.** Plain colours, drawn as the file sets them but kept low in metalness (the studio has no reflections).
  A material named `Label` is painted in the power source's own `label` colour, so one gas bottle draws Green, Red and
  Black Gas.
- **Budget.** 60 KB a file, about 1,500 triangles. No textures.

## Blender, step by step

For a Quaternius or Kenney character.

1. File, Import, glTF 2.0 (or FBX). Apply the pose you want as rest pose if it's rigged.
2. Separate the mesh into the parts above (Edit Mode, select, `P`, Selection) and rename each object in the Outliner.
   Hands can stay with `body` if you don't make the aim parts.
3. Rename the team-coloured material to start with `Team`.
4. Check the size limits below; decimate (Modifier, Decimate) if the triangle count is high.
5. File, Export, glTF 2.0: format glTF Binary, Include "Selected Objects" off, Apply Modifiers on, Compression off.
6. Save it in `assets/models/characters/` and open the project in the Godot editor, so it imports. Its Output panel
   says if anything was wrong with the file.
7. Add a line to `docs/ASSETS.md` and commit the `.glb`, its `.import` file and the line together.

## Size limits

The install stays within the size budget, 500 MB installed (`docs/DECISIONS.md` › Performance budgets and technical
foundations).

| What | Budget |
|---|---|
| A figure model | ≤ 20 MB; LOD0 ≤ 60,000 triangles (within 8 m), LOD1 ≤ 20,000, LOD2 ≤ 6,000; ≤ 8 materials; 2K textures |
| First-person arms | ≤ 8 MB, ≤ 40,000 triangles, ≤ 4 materials, 2K textures |
| A replica model | ≤ 6 MB, ≤ 40,000 triangles in the hands, ≤ 3,000 on a figure, ≤ 6 materials, 2K textures |
| A replica's parts file | ≤ 2 MB, ≤ 10,000 triangles a part |
| A prop | ≤ 1 MB, ≤ 5,000 triangles (a landmark ≤ 30,000 with LODs), sharing texture sets with other props |
| A surface texture set | ≤ 6 MB at 2K (colour, normal, ORM) |
| Everything external | ≤ 25 MB |

These are desktop budgets (owner, 2026-10-18). Every figure on the field (six in a 3v3) shares the model's geometry,
so the model's triangle count, not the team size, sets the cost, and LODs keep distant figures cheap. Low draws
figures at LOD1 at most.

## Licences and attribution

CC0 needs no credit, but **every external file is still recorded in [`ASSETS.md`](ASSETS.md)**: name, source URL,
licence and author, plus the file it went into. That keeps the repository auditable (proof each file was CC0 when
taken), lets the game credit the authors anyway, and makes a file easy to swap out.

- Keep a copy of the pack's `License.txt` next to the file if the pack ships one.
- Never take an asset whose page doesn't say CC0 (or a clearly permissive licence agreed in `DECISIONS.md`).

## What isn't wired up yet

Nothing is wired into a scene yet: the models, fonts and sounds are in `assets/`, but no scene draws or plays them.
