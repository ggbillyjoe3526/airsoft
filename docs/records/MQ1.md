# MQ1 · Replicas made of steel, aluminium and polymer

**Review:** 2 attempts · critic Accept N/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | ✓ | 6/8 Retry (QA Pass, performance Pass) | Judgment, checks 1 and 7: the before and after pictures were too alike (metal too soft to read as metal), the pistol's brushed slide smeared over its serrations and turned silver in Ghost, the sniper's barrel took the paint, the wood option read as a decal; `_worn` names, a dead constant, the grain's import had no written reason |
| 2026-11-12 | 2 | Fable 5.2 (model quality thread) | ✓ | N/8 Accept (QA Pass, performance Pass) | – |

## What changed

Owner, 2026-11-12: "go over all the replica models to improve the quality. Give them more realistic detail and
surfaces. They should be made out of metal (steel/aluminium), polymer, wood. ... Pistol slides are metal and body's
made of polymer/plastic. Rifles should be mostly metal and sniper rifle barrel is metal. The body can be polymer or
wood." This task is the five replicas; the attachments and accessories (MQ2) and the figure and its gear (MQ3) follow.

Until now a paint was a flat colour with one roughness, and only the `Metal` part was metallic, so a blue slide, a
blue polymer frame and a blue stock were the same stuff. Now the paint picks the colour and the part's **surface kind**
says how it behaves in the light. Shapes, triangles, sizes, grip points and gameplay are unchanged.

- **Surface kinds** (`game/config/replica_surfaces.gd`): polymer, steel, aluminium, wood, rubber, bare (unpainted
  bright metal) and coated (metal under a thick baked coat), each a row of finish (metallic, roughness, sheen, how
  far wear bares it), shine (specular, how much of its metal a light paint keeps, the darkest it reflects), grain
  (repeat, stretch along the bore, relief, wood figure) and tone. One table, read by one shader.
- **One shader for the hands' replicas** (`game/play/replica_surface.gdshader`, `.gdshaderinc`): RW1's wear shader
  grown into the surface shader. The grain is one shared 512 px tiling texture (`tools/textures/replica_grain.py`:
  pebble slope, a slow sheen cloud, wood figure with growth rings) read on the model's own space from three sides, so
  no model needs texture coordinates for it; stretched along the bore it is a wood grain, or the brushing of a bare
  bolt.
  Its relief fades with distance (no shimmer). The wear mask works as before, and metal under wear now shows metal.
- **Each face says what it is made of** (`tools/blender/replicas/surface.py`): the kind rides in the vertex colour's
  alpha (`index / 16`, RGB white), written by the build scripts from a table per replica (`SURFACES`) and per part
  (`PART_SURFACES`), or face by face through alias materials (`Body@polymer`). The file's materials are the five it
  always had. A face of an unpainted material (a lens, rubber) says none.
- **The five replicas**, rebuilt with their kinds:

  | Replica | Steel | Aluminium | Polymer | Bare metal |
  |---|---|---|---|---|
  | GBB Pistol | slide, barrel, frame pins and rails, magazine body | – | frame and grip, sights, trigger, controls, magazine base | – |
  | AEG Rifle | barrel, flash hider, front sight base, sights, dust cover, pins, selector, trigger | receiver, handguard and rails, buffer tube, charging handle, magazine | pistol grip, stock, rail cover | port floor |
  | Compact SMG | receiver, cocking tube, barrel, sights, magazine, trigger | – | lower and grip, handguard, stock, selector | bolt in the port |
  | Sniper Rifle | action, barrel (dark steel in any paint), muzzle brake, bolt, magazine, trigger | top and M-LOK rails | chassis stock and grip, cheek piece, inserts | bolt handle |
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

- **The sniper's stock is polymer** (owner, 2026-11-12, on the pictures: "I don't like the wooden sniper rifle so
  remove that and keep polymer"): the wood switch built for attempt 1 is gone from `sniper.py`. Wood stays a surface
  kind (the owner's material list names it; its row and its figure in the grain cost nothing a frame), on no replica.
- **Black polymer is darker, white polymer less bright** (owner, 2026-11-12: "Black polymer should be darker but not
  as dark as the black metals. Also, the white polymer should be less bright"): polymer draws its paint at 0.72
  (`gain`) with a duller highlight (`specular` 0.25), so a black grip sits between the old grey and the black metal
  beside it, and a Ghost frame is an off-white. Steel (0.64) and aluminium (0.72) follow, so metal still reads a
  shade deeper than polymer in the same paint.
- **Shapes unchanged** (default): the owner approved each replica's shape in its own task and every one is within 6 %
  of the 40k budget; this pass spends on surfaces. Invented markings are left as a follow-up.
- **Metal reads as metal, and a paint stays its colour** (attempt 2): a dark paint on steel or aluminium is metal
  nearly all the way (blued, anodised), a shade deeper than the polymer beside it (`gain`) and never darker than
  `floor`, so it has something to reflect with. A light paint (Ghost's white, Tan) keeps only `light_keeps` of the
  metal, as a baked coat does: the colour stays and the shine is a satin one. Before, a white slide was a silver one.
- **Only bare metal is brushed**: the stretch along the bore smeared over the pistol's serrations (critic), and a
  real coated slide is matte. Steel and aluminium now have a fine even grain; the bolt in a port keeps the brushing.
- **The sniper's barrel and thread cap take the `Metal` paint** (dark gunmetal in every scheme), not `Body`: the
  owner's "sniper rifle barrel is metal" reads as dark steel in Tan too.
- **Sixteen slots for kinds** (`index / 16`): seven are used; eight left one spare, and the glb files hold the index.
- **The grain is imported Lossless** (`replica_grain.png.import`): its four channels are unrelated data, and block
  compression bands the slopes into steps on a smooth slide. One 512 px texture for the whole game, about 1.4 MB.
- **The wiki's "lightly used" line names the AEG and the pistol only**: the third worn replica is Dev content, which
  the wiki names only on its Development page (`tools/wiki.py check`).
- **Kinds in the vertex colour's alpha, RGB white**: Godot's importer multiplies a material's colour by COLOR_0 when a
  mesh has one, so white leaves every material as it was and alpha 1 ("none") keeps a lens as clear as it was.
- **Wear bares coated metal only part way** (`bares` 0.45 steel, 0.5 aluminium): full bright metal on every rubbed
  edge read as heavy use against RW1's "lightly used".
- **The Cyber's white shell is `coated`, not aluminium**: as coloured metal it reflected its surroundings and read
  grey indoors; the owner's design is white. A coat keeps the colour and still shines a little.
- **Wood is a walnut stain the paint tints by a fifth** (`WOOD_STAIN`, `WOOD_STAIN_SHARE` 0.8): wood in a paint's
  own colour (cream, blue) read as striped plastic. Its rings arch and thin out unevenly (attempt 2); evenly spaced
  straight ones read as a decal.
- **Bots' copies flat**: at their distance the grain is under a pixel, and HeldMerge needs `BaseMaterial3D` paints.
- **`game/play/replica_wear.gdshader` is no longer used** and is left in place for the owner's pre-release sweep
  (threads don't delete repo files).

## Known issues left

- The surface shader reads the grain seven times a fragment on the replica in your hands (performance, advisory):
  not measurable without a GPU here; a play check is on the Dev 3 checklist. No quality preset turns it down yet.

- Attachments, magazines and barrels in the parts files carry no kinds yet, so they draw as plain polymer (their
  `Metal` as steel) under the paint until MQ2.
