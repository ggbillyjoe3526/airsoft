# GT2 · Your arms hold the bomb in first person

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-06 | 1 | Opus 5.5 (build thread) | – | – | – |

## What changed

GT1's follow-up, once the first-person arms (BL4, #204) merged. A smoke or flash bomb in your hand used to float on its
own before your eyes. Now your gloved right hand holds it:

- **The holds** (`tools/blender/arms/arms.py` `HOLDS["smoke"]`, `HOLDS["flash"]`): each bomb's own model, held in a
  fist like a pistol's grip, the lever under the palm on its right side, the web of the hand round its back, the
  fingers (the index too: no trigger) closed round its front and the thumb round its back; the marks scaled to each
  body (smoke 27.5 mm, flash 20 mm radius). The solver's trigger steps are skipped for a replica with no `Trigger`
  part. Wrists bend 9 degrees; no face passes into the bomb. The four replicas' clips come out of the rebuild
  unchanged (compared key by key), built with `BL_FIT_AEG` on the pre-GS2 AEG (`git show d19c079^:...`).
- **Where it sits.** `GrenadeView.HELD_AT` moves from (0.26, -0.3, -0.6) to (0.15, -0.14, -0.36) m, the same
  direction from the eye (about 22 degrees right and down) but within an arm's reach; `HELD_LIFT` 0.08 to 0.05 with
  it. arms.py mirrors HELD_AT and HELD_TIP; a test checks each hold's mark against HELD_AT.
- **In game** (`GrenadeView.setup_arms`): the bomb now hangs under a square-to-view node (`Held`) with its tip in the
  bomb's own node (`Bomb`), so a second ArmsView rides `Held` (the pose's eye frame) while the bomb tips in the fist.
  The bomb in hand draws its depth pressed as the arms do (its own material copies, made once) and on the hands'
  layer. `GrenadeView.in_hand` is the one rule for a bomb in hand; while it holds, ReplicaView hides its arms
  (`ArmsView.set_shown`), so the replica goes down without them and there are never two right hands. Both bombs are
  one-handed (`ViewModelConfig.one_hand`). A robot player's arms wear the robot's colours.
- `tools/render_held_bomb.gd` renders the view on Depot with each bomb in hand and at the end of the windup (dev only).

## Decisions

- **One-handed, no throwing swing.** The default: the left hand doesn't come up to pull the pin, and the arm only
  lifts with the bomb through the 0.3 s windup (GrenadeView's existing lift), as the replica's arms follow their
  replica. Both are KNOWN_ISSUES row 82's remaining gap.
- **A second ArmsView** under GrenadeView rather than moving ReplicaView's: the replica keeps its hold through the
  holster and draw, and the bomb's arms need nothing from ReplicaView but its hiding its own.

## Known issues left

- No left hand at the pin and no throwing swing in first person (KNOWN_ISSUES).
