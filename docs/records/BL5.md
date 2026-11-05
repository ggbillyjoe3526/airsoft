# BL5 · The Sniper Rifle's model

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | targeted tests pass (11 files) | pending | – |

## What changed

The Sniper Rifle's own model (`assets/models/replicas/sniper.glb`, built by `tools/blender/replicas/sniper.py`),
from the owner's pick of his sniper photos (2026-11-05: the grey chassis, `ref_images.zip` › `replicas/sniper_rifle`,
"Screenshot 2026-11-04 130204"), replacing the AEG-with-a-longer-barrel placeholder (SN1):

- **Traced from the photo.** The photo turned 0.92° so its rail is level, at 1.66 px per mm (the rail's teeth, 10 mm
  apart, confirm it); its side outline matches the photo's within a pixel or two along the barrel, chassis, grip and
  stock. The origin is placed so the grip's front at the hand's height sits where the AEG Rifle's does: the figures'
  rifle hold (human.json `replicaOnGrip.rifle`) lands on this grip too. 107 cm long.
- **The chassis** (`Furniture`, grey in the file): one loft from the forend's nose to the butt, its sides flat, its top
  edge chamfered (wide along the stock, as the photo's), a lower facet leaning in; the barrel's channel along the
  forend's top; a recessed panel with five M-LOK slots a side (dark inside, as holes) and two underneath; the sling
  socket's boss at the nose; the grip a rounded slab under the wrist; the cheek piece a proud panel; the stock's two
  screws a side; a rubber butt pad on a spacer.
- **The action** (`Body`): a round receiver with a top rail (21 teeth), the photo's flat on its left (into the
  chassis's top edge), a port on its right, the barrel's nut, a barrel tapering 28 to 24 mm to a rounded thread cap
  (`FlashHider`, hidden by the silencer).
- **The bolt** (`Bolt`, bone `bolt` on the bore): its shroud behind the receiver, its body inside the receiver until
  it is drawn, and its handle on the right (the photo shows the rifle's left; a right-handed bolt suits the view),
  resting in a pocket in the chassis; the left pocket holds the bolt release.
- **Underneath:** the box magazine (`Magazine`, a window either side with the follower's spine, a BB at its lips), the
  bottom metal and trigger guard as the photo's, the paddle release in front of the guard (`MagRelease`), the trigger
  (`Trigger`), the safety's small lever behind the shroud (`Selector`).
- **Iron sights:** low flip-ups on the rail's ends (`FrontSightLeaf`, `RearSightLeaf`, clamp and leaf on their bones,
  so the game hides them whole while an optic is fitted); the sight line 16 mm over the rail.
- **Clips (60 fps):** `Fire` 1.0 s: the trigger, then the bolt turned up 70° (0.15 to 0.29 s), drawn 68 mm back (to
  0.48 s), pushed home (0.55 to 0.72 s) and turned down (to 0.88 s); `Reload` 1.8 s, the AEG's phases (the paddle
  forward, the magazine down and back); `Inspect` 3.0 s, the bolt lifted and drawn 45 mm, held, closed; `Selector`
  0.5 s, the safety forward by half way; `SightsFold` 0.3 s.
- **Mounts:** `OpticMount` on the rail (the scope's rings on it, its eyepiece over the shroud), `GripMount` under a
  short rail under the forend, `TorchMount` on a short rail on its right, `BarrelEnd` behind the cap.
- **The parts file** (`replicaParts/sniper.glb`): the AEG Rifle's optics, grips, torch and silencer moved from the
  AEG's mounts onto these; no barrels, no magazines.
- 29,656 triangles in the hands (budget 40,000), the figure version 156; 7 materials.

## Decisions

- The bolt handle is on the right, though the photo shows it on the rifle's left: the game shows the rifle's right
  side, and most players are right-handed. The left pocket gets the bolt release the photo's dark lever suggests.
- The photo has no iron sights; low flip-ups on the rail's ends stand in, hidden while an optic is fitted (the rifle
  comes with the 2x Scope).
- The chassis's file colour is the photo's grey; the game paints it in its scheme's furniture colour as any replica's.
- The grip is a separate rounded slab joined to the chassis, not a boolean union: its sides stand 0.5 mm in from the
  wrist's, which reads as a moulded parting line.

## Known issues

- The cocking sound was timed to the old charging handle's clip; the bolt's cycle keeps the same phases (drawn back
  about 0.5 s, home about 0.7 s), so it should still line up; check by ear.
