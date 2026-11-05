# GT1 · Bots show the bomb in hand and throw it

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## What changed

A bot throwing a smoke or flash bomb (SF2) used to put its replica down and stand with its arms hanging until the bomb
appeared in the air at its eyes. Now its figure throws it:

- **The bomb in hand** (`FigureHands`): the bomb's own model (BL9, `GrenadeView.meshes`, shared, never copied) sits in
  the right hand on `Grip_R`, centred on the grip and turned as a pistol's grip is held there, from the pin to the
  release; gone after it. A bomb held in hand (MC1) shows too.
- **The throw** (`FigureThrow`, run by `FigureBend` after the high ready): over the holster's hanging arms, the right
  hand goes from the chest out to the side, up by the ear (cocked, `throw_cock` of the windup), over and out high ahead
  at the release, and down across the body over the recovery; the left hand points ahead while the right cocks and
  tucks in as it comes over; the upper chain turns away and back across with it. Two-bone IK per arm, the elbow towards
  a pole, the hand turning with the forearm. Its keys and timings are `FigureConfig.throw_*`.
- **The timing** comes from the simulation's own throw (`Grenades.Hand`: `windup_left`, `released`, `recover_left`) read
  by `FigurePose.read_throw` against `GrenadeConfig.windup` and `recover`, so the bomb leaves the hand on the tick the
  simulation releases it. Presentation only: the bomb still leaves from the eyes.
- `tools/render_throw.gd` renders both figure kinds through the throw from four sides (dev only).

## Decisions

- **Overhand, elbow low.** The upper arm turns the shortest way from its rest pose carried by the chest, not from the
  holster clip's hanging arm, and the cocked elbow stays out under the shoulder: from hanging, or with the upper arm
  above level, the body's skin dragged at the armpit into a visible flap (renders before and after in
  `/mnt/project-files/art/animation/throw/`).
- **No shoulder shrug.** Raising the clavicle with the arm made the flap worse, so the shoulder is left as the clip
  poses it.
- **First-person hands wait for BL4.** Your own view still shows the bomb on its own while you hold or throw it; the
  first-person arms (#204) are not merged yet. Holding it with your arms is the follow-up in this thread.

## Known issues left

- With the arm over the shoulder, the body's skin still bulges a little at the armpit for about a tenth of a second
  (the body's weights; BL10 owns the body).
