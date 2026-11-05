# GT1 · Bots show the bomb in hand and throw it

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Opus 5.5 (build thread) | ✓ (part 4 local time limit) | 6/8 Retry (QA Pass, performance Pass) | the hand and bomb passed across the face coming over; the armpit swelled past the vest under the raised arm; KNOWN_ISSUES still said figures had no throw |
| 2026-11-05 | 2 | Opus 5.5 (build thread) | pending | pending | – |

## What changed

A bot throwing a smoke or flash bomb (SF2) used to put its replica down and stand with its arms hanging until the bomb
appeared in the air at its eyes. Now its figure throws it:

- **The bomb in hand** (`FigureHands`): the bomb's own model (BL9, `GrenadeView.meshes`, shared, never copied) sits in
  the right hand on `Grip_R`, centred on the grip and turned as a pistol's grip is held there, from the pin to the
  release; gone after it. A bomb held in hand (MC1) shows too. Over the first `throw_pin_until` of the windup the
  left hand meets the right at the bomb, pulling the pin.
- **The throw** (`FigureThrow`, run by `FigureBend` after the high ready): over the holster's hanging arms, the right
  hand goes from the chest out to the side, back by the ear (cocked, `throw_cock` of the windup), up beside the head
  (`throw_over`, the elbow swinging ahead to lead, so the hand never crosses the face) and out ahead at head height at
  the release, and down across the body over the recovery; the left hand points ahead while the right cocks and
  tucks in as it comes over; the upper chain turns away and back across with it. Two-bone IK per arm, the elbow towards
  a pole, the hand turning with the forearm. Its keys and timings are `FigureConfig.throw_*`.
- **The timing** comes from the simulation's own throw (`Grenades.Hand`: `windup_left`, `released`, `recover_left`) read
  by `FigurePose.read_throw` against `GrenadeConfig.windup` and `recover`, so the bomb leaves the hand on the tick the
  simulation releases it. Presentation only: the bomb still leaves from the eyes.
- `tools/render_throw.gd` renders both figure kinds through the throw from four sides (dev only).

## Decisions

- **Overhand, elbow low.** The upper arm turns the shortest way from its rest pose carried by the chest, not from the
  holster clip's hanging arm, and the cocked elbow stays out under the shoulder: from hanging, or with the upper arm
  above level, the body's skin dragged at the armpit into a visible flap (renders in
  `/mnt/project-files/art/animation/throw/`).
- **The elbow leads coming over** (`throw_over_pole`): with the elbow out to the side there, the upper arm stood out
  over the shoulder and the skin under it swelled past the vest (critic round 1). A test keeps the hand and the bomb
  over 0.15 m from the head's middle through the second half of the windup on both kinds.
- **A throw from a bomb held in hand keeps the arm up** (`FigurePose.throw_from_hand`), rather than dropping it to the
  holster's hang and raising it again.
- **No shoulder shrug.** Raising the clavicle with the arm made the flap worse, so the shoulder is left as the clip
  poses it.
- **First-person hands wait for BL4.** Your own view still shows the bomb on its own while you hold or throw it; the
  first-person arms (#204) are not merged yet. Holding it with your arms is the follow-up in this thread.

## Known issues left

- None of the throw's own: no armpit swell shows in the close-ups (`bot-throw-closeup.jpg`). The first-person hands
  are the follow-up (KNOWN_ISSUES, waiting on BL4).
