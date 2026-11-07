# GT3 · Your arms pull the pin and throw the bomb in first person

**Review:** 3 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-06 | 1 | Opus 5.5 (build thread) | – | 6/8 Retry (QA Fail, performance Pass) | the pin never visibly left the bomb; the windup went empty for half its time with the bomb off screen; the release wrist was bent back on a straight arm and the follow-through lingered; a throw cut off mid-windup lowered the arms frozen mid-throw (QA) |
| 2026-11-06 | 2 | Opus 5.5 (build thread) | – | 7/8 Retry (QA's bug fixed, performance Pass) | the pin never showed: the ring sat inside the curled fist |
| 2026-11-06 | 3 | Opus 5.5 (build thread) | 8/8 | 8/8 Accept | – |

## What changed

GT2's known issue (KNOWN_ISSUES, the bombs row), at the owner's ask of 2026-11-06: in first person your left hand now
pulls the pin, and your right arm throws the bomb, where before the bomb in hand only rose a little through the windup.

- **ArmsThrow** (`game/play/arms_throw.gd`): your arms posed over the bomb's hold (BL4's `<id>_Hold` clip) by two-bone
  IK, `share` running 0..1 over the windup and 1..2 over the recovery, as FigureThrow measures a figure's throw. The
  left hand comes up from below to the pin's ring by `bomb_pin_grab` (0.3), turned to grip it (fingers to the ring, palm
  down and ahead) and its fingers curled round it, draws the pin out sideways clear of the bomb by `bomb_pull_at` (0.45,
  while the right hand carries the bomb the other way), then takes it down out of view by `bomb_pin_out` (0.6), where
  the left arm is hidden again. From the grip the right hand goes out aside and up to the view's top-right corner
  (`bomb_aside`, `bomb_cocked`: the bomb stays in sight through the windup), its wrist cocked back, then, quickening,
  over the top and out ahead to the release with the elbow still bent and the wrist snapping forward, its shoulder
  turning back and then forward into the throw; its fingers open off the bomb by `bomb_let_go_by` (1.15) and it follows
  through down across out of view by `bomb_follow_by` (1.4), where the arms are gone at once (no second lowering). A
  throw cut off mid-windup (a hit, the round over, other eyes) lowers the hand on the hold. Keys and timings are
  ViewModelConfig's `bomb_*` (the eyes' frame). Nothing is rebuilt in Blender: arms.glb is unchanged.
- **ArmReach** (`game/play/arm_reach.gd`): FigureThrow's two-bone IK moved out to be shared; FigureThrow's pose is
  the same (its upper arm's roll still blended from the rest pose; ArmsThrow keeps the hold's).
- **The pin drawn apart** (`GrenadeView.PIN_MATERIALS`: the smoke's `Wire` pin and ring, the flash's `Steel` split
  ring and hook): the bomb in your hand draws its body and its pin as two meshes (made once at `setup_arms`), the bomb
  in the right hand's fist (`ArmsView.bomb_moved`), the pin with it until the left hand grips the ring and then in the
  left hand (`pin_moved`). The thrown bombs and the figures' keep the whole model.
- **Timing unchanged** (default): the windup stays 0.3 s and the recovery 0.15 s (GrenadeConfig), so the pin pull is
  about a tenth of a second at full speed; a bomb waiting in hand (MC1) keeps its pin until the throw, as the sim's
  GRENADE_PIN event says. The view reads the throw between ticks (`GrenadeView.throw_share`, the tick's fraction).
- `HELD_LIFT` (GT2's rise through the windup) is gone: the arm's swing replaces it.
- `tools/render_held_bomb.gd` pictures each step of the throw, or every frame of one (`clip`) for a moving picture.

## Decisions

- **IK in game, not baked clips.** Posing the throw over the hold at run time keeps arms.glb untouched (the arms
  thread is re-fitting the AEG and sniper holds in it), reuses the figures' IK, and keeps every key tunable as data.
- **The left hand grips the ring's middle** (the pin surface's bounds' middle), the same offset for both bombs.
- **Thrown bombs keep their pin** (SF1's whole model, shared with the figures): seen at 13 m/s spinning; noted in
  KNOWN_ISSUES.

## Known issues left

- The bomb still leaves from the eyes, not the hand (SF1), and a thrown bomb keeps its pin (KNOWN_ISSUES).
- The over-the-top swing shows the forearm and sleeve for a few frames: an overhand throw passes the arm over the
  eyes, unlike the owner's hand-and-wrist rule for holds.
- A throw cut off mid-swing snaps to the hold in one frame before lowering; a short blend back would hide it (can
  wait; fixed in GT4). The ring's hang slides in the model's frame, not the fist's, which reads fine at 4 cm.
