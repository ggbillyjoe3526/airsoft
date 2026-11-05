# BL5 · The Sniper Rifle's model

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | targeted tests pass (11 files) | Retry 7/8 (QA Pass, performance Pass) | a dark slit where the receiver's flat met the chassis; the nose's sling socket lost; a dark band under the forend; a seam across the grip; facets on the comb; a cheek piece too flat; the guard's opening too square; small photo details |
| 2026-11-05 | 2 | Claude (build thread) | targeted tests pass (3 files) | Retry 7/8 | a black patch where the guard's front post shared its opening's wall; streaks round the rear screw's pocket (a boolean in the stock's side); a hard step where the grip meets the stock |
| 2026-11-05 | 3 | Claude (build thread) | targeted tests pass (1 file) | pending | – |

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
  socket's boss at the nose, a raised hex ring and a hole either side; the grip a rounded slab joined to the wrist by
  a boolean union, flush with it; the tang, comb and wrist line smoothed along a curve through the traced points; the
  cheek piece a panel 2 mm proud; the stock widening from the wrist's 35 mm to 40 mm on a smooth ramp behind the
  grip; a hex screw in a washer and a hex pocket in a low boss a side; a rubber butt pad on a spacer.
- **The action** (`Body`): a round receiver with a top rail (21 teeth), the photo's flat on its left (into the
  chassis's top edge), a port on its right, the barrel's nut, a barrel tapering 28 to 24 mm to a rounded thread cap
  (`FlashHider`, grooved, hidden by the silencer).
- **The bolt** (`Bolt`, bone `bolt` on the bore): its shroud behind the receiver, its body inside the receiver until
  it is drawn, and its handle on the right (the photo shows the rifle's left; a right-handed bolt suits the view),
  resting in a pocket in the chassis; the left pocket holds the ribbed bolt release; a bright ring on the shroud's
  front.
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
- 36,054 triangles in the hands (budget 40,000), the figure version 156; 7 materials.

## Decisions

- The bolt handle is on the right, though the photo shows it on the rifle's left: the game shows the rifle's right
  side, and most players are right-handed. The left pocket gets the bolt release the photo's dark lever suggests.
- The photo has no iron sights; low flip-ups on the rail's ends stand in, hidden while an optic is fitted (the rifle
  comes with the 2x Scope).
- The chassis's file colour is the photo's grey; the game paints it in its scheme's furniture colour as any replica's.
- The grip is rounded by a bevel alone before its union with the chassis: custom normals carried through the boolean
  streaked the whole chassis's shading.
- The rear screw's hex pocket sits in a boss 1.2 mm proud of the stock, built as rings, not cut into the stock's
  side: the boolean's long thin triangles streaked the flat side.

## Known issues

- The cocking sound was timed to the old charging handle's clip; the bolt's cycle keeps the same phases (drawn back
  about 0.5 s, home about 0.7 s), so it should still line up; check by ear.
