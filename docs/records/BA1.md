# BA1 · The barrel models

**Review:** 4 attempts · critic PENDING · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | targeted tests pass (294) | Retry 6/8 (QA Pass, performance Pass) | steel and brass drew black on the cards; cards 14 px tall; seams at the crown, flats and flutes; razor-edged chamber; hop arm low in its window; bare thread stub; ASSETS counts stale |
| 2026-11-05 | 2 | Claude (build thread) | tools/check.sh: gdlint, changelog, wiki green; targeted tests pass (68) | Retry 7/8 (QA Pass) | the long barrel's extension and the dark chamber drew as silhouettes on the card; a crack where the flats meet the shoulder; the hop sleeve faceted; the long crown 20 points; a 3-groove thread |
| 2026-11-05 | 3 | Claude (build thread) | targeted tests pass (143, QA's 41) | Retry 7/8 (QA Pass, performance Pass) | the barrel's solid rear end showed white or gold through the bucking's lip, the most prominent detail on the turned cards |
| 2026-11-05 | 4 | Claude (build thread) | PENDING | PENDING | – |

## What changed

The AEG Rifle's two barrel upgrades, Tight-Bore and Long Barrel, were text only. Each is now a Blender model built by
`tools/blender/parts/barrels.py` from the AEG model's own barrel (no photos, owner ruling 2026-11-03).

- **Tight-Bore:** a polished steel 6.03 mm inner barrel, 34.5 cm, in a rotary hop-up unit. The unit has a grey
  chamber, a 24-tooth dial, a hop arm in its window and a red bucking. O-rings and a centring spacer sit along the
  barrel. Fitted, only its crown shows in the flash hider, as on a real AEG.
- **Long Barrel:** a brass inner barrel 10 cm longer, through a 10 cm outer extension with a knurled coupling, wrench
  flats, 8 ball-end flutes, a lock ring and a 10 mm thread. Fitted, the extension shows, and the flash hider and
  muzzle move out 0.1 m (its `_BarrelEnd`).
- **A new part contract:** what a part puts inside the replica is `<slot>_<key>_Inside` in
  `assets/models/replicaParts/inside/<replica>.glb`, placed where its part sits. `ReplicaParts.inside()` loads it for
  the part's own picture only, so a fit never loads it. It counts toward the part's 10,000 triangles.
- **Barrel cards are turned 60°** about the up axis (`ReplicaPictures.PART_TURN`), with the hop-up end toward the
  viewer, so a 15-to-1 barrel draws about 26 px tall instead of a 14 px line.
- **Barrel cards get a fill light** from the viewer's side (`ReplicaPictures.PART_FILL`), so the long barrel's
  extension, which is in the rifle's dark paint, shows its knurl and flutes on the dark card.
- Triangles, all included: Tight-Bore 9,454 (882 drawn fitted), Long 9,954 (5,014 drawn fitted).

## Decisions

- **Defaults taken** (owner's defaults rule): each part is the inner barrel in its hop-up unit, since that's what a
  real barrel upgrade is. Tight bore = polished steel, long = brass, so the two read apart on their cards. The long
  barrel's outer extension matches the rifle's 8.6 mm barrel radius.
- **The insides have their own file:** in aeg.glb they took it to 1.98 MB of its 2 MB budget, with the magazines
  thread still to add. Split out, aeg.glb is 1.52 MB and a fit loads less.
- **No bevel modifier on the hop unit:** a 0.45 mm end chamfer is modelled instead. A 2-segment bevel took both
  parts over 10,000 triangles.
- **Where the triangles went** (attempt 3): the hop unit's sleeve and nose and both crowns at 48 to 52 points, paid
  for by the tight bore's inner barrel at 36 points behind its centring spacer (hidden when fitted, a thin line on its
  card), the extension at 32 points (the rifle's own barrel is 20), a coarser knurl (36 round, 1.5 mm pitch), a
  4-groove thread and one O-ring on the long barrel.
- **Own materials** (Steel, Brass, Etch, Chamber, Bucking, Bore) keep their look under every paint. The extension's
  Metal takes the paint like the rifle's barrel.

## Known issues left

- The long barrel sits 46 triangles under its cap: any detail added must come out elsewhere.
- The insides' materials are not in the shader prewarm. They draw only in the Customise picture, so a first open of
  the barrel tab might hitch once (performance, advisory).
- Whichever of this task and the magazines task merges second reruns the other's script over the shared aeg.glb.
