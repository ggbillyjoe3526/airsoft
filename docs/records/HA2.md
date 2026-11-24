# HA2 · Pistols at the rifles' place, no arm ends on Inspect

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

The owner's playtest notes of 2026-11-15, items 3 and 4, and his note on the pictures: "make the pistol take up less space on screen. it should
roughly be same scale/angle as rifle" and "when inspecting rifles the player can see the end of the arm models".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The pistols sit low on the right, 35 cm from the eye, turned 0.15 rad in** (`ViewModelConfig.hip`, the new
  `hip_turn`, which fades out as the sight comes up). Picked from five places drawn beside the AEG and the Compact SMG
  at the hip at FOV 87 (the new default another thread is setting): at 34 to 42 cm with the hands lower, only the
  tops of the hands showed; at 32 cm it still read large; 35 cm with the hip 9 cm down showed both hands and no
  forearm. It replaces HA1's 25 cm (`docs/DECISIONS.md`, HA2).
- **The reload follows the new place.** The reload's move is the 34 cm move scaled to 35 cm, as HA1 scaled it to 25.
- **Inspected, both shoulders stay where your body has them.** ReplicaView hands ArmsView the transform that carries
  a point at rest with the replica to where the inspect's turn takes it; ArmsTuck (now for either side) sets each
  shoulder back to its place at rest and finds the elbow again from the clip's elbow direction as the body sees it,
  each hand kept on its hold. A hand the arm can't reach from there (the right hand on a rifle, turned 1.2 rad and
  moved 20 cm in) draws the shoulder after it along the arm's line: it moves up to 18 cm, still off screen.
- **Checked at the widest view the game draws** (FOV 110 on a 21:9 screen) in `test_ha2_hold_place.gd`: neither
  shoulder (the sleeve's cut-off end) comes within 5 % of the view's edge on any frame of any replica's inspect; with
  the fix taken out the AEG's and the SMG's come to 55 % and 25 % of the way out from the middle.
- **Aimed, a pistol's hands are drawn whole** (the owner, 11:50, on the pictures: "perfect. however, the pistol ADS
  shows the hand fading, it shouldn't do this"). `aim_hands_hint` is empty; the fade stays as a knob (its tests put
  the pistols in it), and `test_ha2_hold_place.gd` checks the pistols aimed wear their own materials. The aimed place
  is unchanged (25 cm, `aim_forward`): pictures at 21 and 30 cm read no better.
- **The pistols' inspect is the one he saw.** The shift and turn tried in code were never drawn (the saved
  `play_tuning.tres` holds the inspect poses), so the pictures he called "perfect" were the old shift and turn from
  the new hip; the code keeps those, and the pistols turn 0.15 rad further side on than before.
- **`tools/render_fp.gd`** takes `:inspect=<share>` and `fov:<deg>`, and a `set:` now changes the shots after it
  only, so one run draws several tries side by side.

## Known issues left

- None. How it feels in the hands is on the owner's checklist (N13) and `docs/archive/0.1-dev/PLAYTEST-dev3-beta1.md` ›
  HA2; pictures in the shared files under `art/fp-arms-ha2/`.
