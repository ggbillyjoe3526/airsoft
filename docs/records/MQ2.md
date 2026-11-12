# MQ2 · Attachments, magazines and barrels made of what the real ones are

**Review:** 3 attempts · critic PENDING · qa PENDING · performance PENDING

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | qa Pass after one fix (a barrel's inside), performance Pass | Retry 6/8 | Only the materials changed: no part gained detail, the polished crown was mottled, the hi-cap could not be told from the low-cap, the record claimed a play check the repository did not hold |
| 2026-11-12 | 2 | Fable 5.2 (model quality thread) | qa Pass (two more tests), performance Pass, one old barrel test updated | Retry 7/8 | The magazines' BBs were faceted (the low-cap's made coarser to pay for its mould line), the tight bore's crown showed polygon steps along its bright rim |
| 2026-11-12 | 3 | Fable 5.2 (model quality thread) | PENDING | PENDING | – |

## What changed

Owner, 2026-11-12: "Also go over all the attachment and accessory models and improve their quality and make them look
more realistic and detailed." And: "When modelling the vertical grip can you make it a little longer?"

MQ1 drew the five replicas as steel, aluminium and polymer under any paint; the parts fitted to them still drew as
flat paint. Now each part in `assets/models/replicaParts/` is made of something too, in the hands and on the
Customise turntable:

| Part | Made of |
|---|---|
| Red dot, 2x scope, Variable Scope, silencer, Weapon Torch | anodised aluminium bodies, steel screws and clamps, rubber caps and pads |
| Laser | a polymer housing, steel screws |
| Vertical and angled grips | polymer, rubber pads, a steel clamp |
| Hi-Cap Magazine | a steel shell |
| Low-Cap and Extended magazines | polymer (the Extended's metal parts steel) |
| Long barrel, tight bore | dark steel outside, a polished brass or stainless crown |

- **How a part names its kinds.** A part is one kind a material, so it carries no kind per face (the 8 bytes a vertex
  that cost a replica would take the AEG's parts file past its 4 MiB cap). Each mesh carries a small table, material
  to kind, in its glTF `extras` (`surfaces`): `surface.name` in `tools/blender/replicas/surface.py` writes it from the
  build script's `SURFACES` table, `hardsurface.export` keeps extras, and `ReplicaSurfaces.named` reads it in the
  game. `ReplicaPaint.apply` draws a painted material on its named kind and a part's own named materials (rubber, a
  brass crown) on theirs in their own colour. Glass, fibre, lit LEDs and the laser's lens stay as the file has them.
  The figures' copies name nothing and stay flat.
- **A new kind, `polished`** (index 7, after `coated`): bright bare metal in its own colour, for a crown, its colour
  lifted as bare metal's is (all metal reads dark wherever the sky it mirrors is dull). The order of `KINDS` is
  unchanged.
- **New detail on the parts that were bare** (attempt 2, each within its 10,000 triangles):
  - *Silencers* (rifle 9,068, pistol 8,778): six wrench flats milled round the back cap ahead of its seam, the front
    edge chamfered as turned where the back is rounded, four pin-spanner holes in the front cap's face.
  - *Weapon Torch* (9,626; the Cyber's 9,158): two cooling grooves round the head, a ridged bezel on every rail (the
    Cyber's alone had one), a battery door at the back with a hinge along its foot and a ribbed latch.
  - *Laser* (9,376 on a rifle's rail, 9,408 on the pistol's): a window let into the front face round the emitter, the
    front cap's four screws, a battery cap with a coin slot in the back face. The emitter stays flush (owner,
    2026-11-05).
  - *Hi-Cap Magazine* (9,782): a pressed steel shell, so four narrow pressed ribs a side where the polymer ones have
    five wide ones, a lapped seam down its back with seven spot welds, folded steel feed lips.
  - *Low-Cap Magazine* (9,494): the mould's parting line, a fine ridge down its front and back.
  - *The magazines' BBs* (attempt 3) are true balls, 32 sides round on the Hi-Cap, 34 on the Low-Cap and 24 on the
    Extended (9,948), half as many bands each: the old ones had six bands at exactly the bevel's 30 degrees, so the
    bevel bit into some of their edges and left them lumpy. Paid for by the ribs: a part's ribs are now finished
    apart with their crowns rounded in their own sections, where a bevel spent about 2,000 triangles a magazine on
    each rib's two edges sunk inside the body.
  - *Barrels* (tight bore 9,822 with its inside, long 9,930): the crown is a recessed target crown inside a guarding
    rim, its outer edge chamfered, a turned groove behind it on the tight bore. A crown is 104 points round on the
    tight bore and 64 on the long barrel (48 and 40 before, attempt 3), so its rim's highlight is one ring; the
    inside (the Loadout's picture only) pays: the barrel behind the spacer 24 round, the O-rings 20, the spacer 40,
    the hop-up's sleeves 28.
  - *Angled grip* (9,852): grip ridges across its foot and two cross bolts in its clamp bar, inside the outline traced
    from the owner's photo.
  - The red dot and the two scopes keep their shapes: the owner ruled on them one by one (lower, "more
    minimalistic", a clean objective housing; the notes in `attachments.py`, 2026-11-05 and BP8), so they change in
    what they are made of only.
- **The vertical grip is a little longer:** 64 mm under the rail (53 before), on the AEG Rifle and the Sniper Rifle,
  with more rows in its panels and ribs (9,260 triangles of 10,000). Measured against the owner's side-on photo
  (`ref_images.zip` › `vertical_grip/Double-Bell-…-BK1`, 1,780 px tall, its clamp 1,284 px long, its waist about
  895 px): the photo's grip is 1.39 clamps tall and 1.98 waists; the old model was 1.43 and 2.0 (57.9 mm over all on
  a 40.4 mm clamp and a 29 mm waist), the new one 1.70 and 2.37 (68.8 mm over all). So it is a fifth longer than the
  photo's stubby grip, at the owner's word: three fingers' hold, still short of a full-length grip's 80 mm or more.
- **The barrels' pictures:** a barrel's inside (the Loadout's part picture only) names its kinds too, so its inner
  barrel is the same polished brass or stainless as its crown, its chamber polymer and its bucking rubber, in their own
  colours whatever the paint; the bore and the etched marks stay as the file has them (`test_barrel_models.gd`).
- **The GBB Pistol's silencer** sits on the pistol's muzzle as MQ1 left it (1.4 mm up, 1 mm forward of where the old
  file had it): the rebuild read the mount afresh.
- **Files:** `aeg.glb` 4.03 MB (cap 4 MiB), every part within 10,000 triangles (`attachments.py` and
  `magazines.py` now stop on one over, as `barrels.py` does) and the figures' copies within 600. Part names, mounts
  and materials' names are unchanged. The exporter writes no custom property but the tables (`surface.only_tables`).
- **Tests** (`tests/unit/test_part_surfaces.gd`): every hands' part names a known kind for each paint it wears; the
  table above; a part wears its paint on its kind and its rubber on rubber; lit and mirrored materials stay; a plain
  apply and a figure's copy stay flat; the Cyber Pistol's torch in its own colours; a crown is polished metal; a
  missing or wrong table names nothing; the vertical grip's length. `test_attachment_models.gd` no longer expects
  rubber to stay flat, and `test_ba1_qa.gd` lets a barrel's inner material wear its own colour on its surface (it
  still fails if the paint reaches one). QA's `test_mq2_qa.gd`: every file in every paint, plain and surfaced, leaves no lens or light
  surfaced and no stale override. Attempt 3: each magazine part's BBs are whole, apart, finely turned and every
  corner of one on a 6 mm ball.
- **Docs:** `docs/CC0_ASSETS.md` › Surfaces (the parts' contract), `docs/ART.md`, the vertical grip's ruling in
  `docs/DECISIONS.md`, the wiki's Replicas › Colours, `docs/PLAYTEST.md` › What the parts are made of (MQ2), the
  grip holds' row in `docs/KNOWN_ISSUES.md`. The owner's own list, `playtest/0.1-dev3-checklist.md`, is in the shared
  project files, not in this repository; it carries the same check.
- **Pictures:** `art/model-quality/mq2/` in the project files: every part alone before and after in Wolf grey (the
  lightest paint a part wears), the AEG Rifle in first person, and the magazines' tops and the crowns close up
  (`mq2-pass3-bbs-crowns.jpg`).

## Decisions

- **A table a mesh, not a kind a face** (default): see above; it also survives the Blender round trips the Sniper's
  and SMG's fits and the figures' copies make.
- **The laser is polymer, the torch aluminium** (default): as the common real ones are; both keep their paint.
- **Own-coloured materials are surfaced only when named** (default): a mesh with a table surfaces exactly what the
  table names, so glass and lights can never be drawn as paint by mistake.
- **Detail where the parts were bare, none on the owner-ruled optics** (default, after the critic's first verdict):
  see above. Each addition is something the real part has (flats to tighten it by, a door to change its battery by),
  and the owner's photos show their kind (`ref_images.zip`: `weapon_torch/51-NSNEkN3S` a ridged bezel and grooved
  head, `silencer/wey027-03` a knurled back cap and a turned front edge, `red_laser/` cap screws). The laser keeps
  its owner-ruled box with a flush emitter, not the photos' tubes.
- **A magazine part's ribs, feed tower and BBs are joined after its cuts** (default, attempt 3): the exact boolean
  dropped whole shells no cutter touched (the low-cap's tower and a BB) once the ribs left the cut body, so the cut
  body is now the shell and plate alone, and `magazines.py` stops if a cut ever loses a shell or a part goes over
  10,000 triangles.
- **`polished` has no grain and no clouding** (default): the first value (relief 0.03, cloud 0.1) made the highlight
  mottled, as hammered metal's.
- **The red dot's faint bands in the Loadout picture** are the aluminium kind's clouding (MQ1's look, as on the AEG's
  receiver) in a dark 8-bit picture; a side-on studio picture of the hood is even, so nothing in the mesh. Left.

## Known issues left

- The first-person holds on the vertical grip (`aeg_grip_vertical_*`, `sniper_grip_vertical_*`) were posed on the
  53 mm grip; the FP arms thread owns them and is told (`docs/KNOWN_ISSUES.md`, Graphics).
- The left hand's reload hold was posed on the wide-ribbed magazine; the hi-cap's sides are now 1 mm flatter between
  its ribs. Too small to see; the FP arms thread is told with the grip.
- Grenades and power sources (the menu pictures and the grenade in the hand) follow in MQ2B.
