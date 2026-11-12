# MQ1 · Replicas made of steel, aluminium, polymer and wood

**Review:** 1 attempt · critic Accept N/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | ✓ | N/8 Accept (QA Pass, performance Pass) | – |

## What changed

Owner, 2026-11-12: "go over all the replica models to improve the quality. Give them more realistic detail and
surfaces. They should be made out of metal (steel/aluminium), polymer, wood. ... Pistol slides are metal and body's
made of polymer/plastic. Rifles should be mostly metal and sniper rifle barrel is metal. The body can be polymer or
wood." This task is the five replicas; the attachments and accessories (MQ2) and the figure and its gear (MQ3) follow.

Until now a paint was a flat colour with one roughness, and only the `Metal` part was metallic, so a blue slide, a
blue polymer frame and a blue stock were the same stuff. Now the paint picks the colour and the part's **surface kind**
says how it behaves in the light. Shapes, triangles, sizes, grip points and gameplay are unchanged.

- **Surface kinds** (`game/config/replica_surfaces.gd`): polymer, steel, aluminium, wood, rubber, bare (unpainted
  bright metal) and coated (metal under a thick baked coat), each a row of finish (metallic, roughness, sheen, how far wear bares it), grain (repeat, stretch along
  the bore, relief, wood figure) and tone. One table, read by one shader.
- **One shader for the hands' replicas** (`game/play/replica_surface.gdshader`, `.gdshaderinc`): RW1's wear shader
  grown into the surface shader. The grain is one shared 512 px tiling texture (`tools/textures/replica_grain.py`:
  pebble slope, a slow sheen cloud, wood figure with growth rings) read on the model's own space from three sides, so
  no model needs texture coordinates for it; stretched along the bore it is a brushed steel finish or a wood grain.
  Its relief fades with distance (no shimmer). The wear mask works as before, and metal under wear now shows metal.
- **Each face says what it is made of** (`tools/blender/replicas/surface.py`): the kind rides in the vertex colour's
  alpha (`index / 8`, RGB white), written by the build scripts from a table per replica (`SURFACES`) and per part
  (`PART_SURFACES`), or face by face through alias materials (`Body@polymer`). The file's materials are the five it
  always had. A face of an unpainted material (a lens, rubber) says none.
- **The five replicas**, rebuilt with their kinds:

  | Replica | Steel | Aluminium | Polymer | Bare metal |
  |---|---|---|---|---|
  | GBB Pistol | slide, barrel, frame pins and rails, magazine body | – | frame and grip, sights, trigger, controls, magazine base | – |
  | AEG Rifle | barrel, flash hider, front sight base, sights, dust cover, pins, selector, trigger | receiver, handguard and rails, buffer tube, charging handle, magazine | pistol grip, stock, rail cover | port floor |
  | Compact SMG | receiver, cocking tube, barrel, sights, magazine, trigger | – | lower and grip, handguard, stock, selector | bolt in the port |
  | Sniper Rifle | action, barrel, muzzle brake, bolt, magazine, trigger | top and M-LOK rails | chassis stock and grip, cheek piece, inserts | bolt handle |
  | Cyber Pistol | bars and metal trim | – (its slab sides are coated metal) | frame, lines, core | – |

  The AEG's pistol grip is moulded into the lower by a boolean union; `hardsurface.cut(..., keep_materials=True)`
  lets a union keep its part's material, so the grip stays polymer inside the aluminium lower.

- **Paint on a surface** (`game/play/replica_paint.gd`): in the hands every painted surface is the surface shader with
  its paint's colour (shared per paint, mask and part, as RW1's were); the Cyber's own colours go on their surfaces
  too, and its lines still glow. Bots' copies keep the flat paints (HeldMerge merges plain materials), with no kinds
  in their meshes.
- **Menu pictures and the turntable** (`game/ui/studio_sky.gd`): a small studio sky (a soft room, an overhead box,
  two strips) as the reflection source, so metal has something to reflect in the Customise pictures.
- **A studio for model pictures** (`tools/model_studio.gd`, dev tool): any glb in any paint from any side, for review
  sheets.
- **Tests** (`test_replica_surfaces.gd`): the kinds' order matches the build side's; every hands' mesh carries white
  colours and a known kind; the figures' copies carry none; the owner's materials (pistol slide steel, frame polymer,
  rifle receiver aluminium, barrels steel, sniper stock polymer); the hands' paint is the surface shader with its
  tables; a plain apply stays flat; the Cyber's glow and Realistic colours; the grain tiles and is flat on average.

## Decisions

- **The sniper's stock is polymer** (default): the model is the modern chassis rifle from the owner's reference photo,
  and those stocks are polymer over aluminium. Wood is built (the kind and its figure) and one switch away
  (`BL_SNIPER_STOCK=wood` when running `sniper.py`); a picture of it went to the owner to choose.
- **Shapes unchanged** (default): the owner approved each replica's shape in its own task and every one is within 6 %
  of the 40k budget; this pass spends on surfaces. Invented markings are left as a follow-up.
- **Kinds in the vertex colour's alpha, RGB white**: Godot's importer multiplies a material's colour by COLOR_0 when a
  mesh has one, so white leaves every material as it was and alpha 1 ("none") keeps a lens as clear as it was.
- **Wear bares coated metal only part way** (`bares` 0.45 steel, 0.5 aluminium): full bright metal on every rubbed
  edge read as heavy use against RW1's "lightly used".
- **The Cyber's white shell is `coated`, not aluminium**: as coloured metal it reflected its surroundings and read
  grey indoors; the owner's design is white. A coat keeps the colour and still shines a little.
- **Wood is a walnut stain the paint tints by a fifth** (`WOOD_STAIN`, `WOOD_STAIN_SHARE` 0.8): wood in a paint's
  own colour (cream, blue) read as striped plastic.
- **Bots' copies flat**: at their distance the grain is under a pixel, and HeldMerge needs `BaseMaterial3D` paints.
- **`game/play/replica_wear.gdshader` is no longer used** and is left in place for the owner's pre-release sweep
  (threads don't delete repo files).

## Known issues left

- Attachments, magazines and barrels in the parts files carry no kinds yet, so they draw as plain polymer (their
  `Metal` as steel) under the paint until MQ2.
