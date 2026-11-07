# GT4 · A cut-off throw eases back to the hold

**Review:** 1 attempt · critic pending · qa pending · performance pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-07 | 1 | Opus 5.5 (build thread) | – | 7/8 Retry (QA Pass, performance Pass) | the changelog note wasn't committed; the frame-rate test passed without the feature; the unwind's limit to the hand's way down was only a comment |
| 2026-11-07 | 2 | Opus 5.5 (build thread) | – | pending | – |

## What changed

GT3's known issue, at the owner's ask of 2026-11-07 (a small polish fix for 0.1 Dev 2): a first-person throw cut off in
its windup (a hit, the round's end, other eyes) snapped your arms to the bomb's hold in one frame before the hand went
down. Now they ease back from where the throw left them.

- **ArmsThrow** (`game/play/arms_throw.gd`): `capture` also keeps the windup's first pose (`START`: the right hand on
  the hold, the left down at `bomb_left_in`, open). `cut` keeps the moved bones' pose at the cut; `unwind(w)` blends
  each bone's place and turn from the cut to that start, eased out (quick at first, as the throw was moving, then
  settling). Preallocated arrays: nothing allocated per frame.
- **ArmsView** (`cut_throw`, `unwind_throw`): the left arm stays shown while it eases down if it showed at the cut
  (pulling the pin), then hides as before.
- **GrenadeView** (`_unwind`): on the cut it takes the pose and eases over `ViewModelConfig.bomb_unwind_time` while
  the hand goes down (`bomb_raise_time`, unchanged; the ease is held to that at most). A new throw mid-ease starts from the hold; a bomb of another kind
  puts the hold back first.
- `tools/render_held_bomb.gd` `cut<share>` renders every frame of a throw cut off at that share.

## Decisions

- **0.15 s, eased out** (default): under the hand's 0.2 s way down, so the arms are home before it is gone, and as quick
  as the cut feels. Easing out keeps the arm's speed at the cut instead of pausing first.
- **Blended to the windup's start, not the hold:** the right hand's start is the hold, and the left goes down to where
  it came up from (out of view), instead of to the hold's hidden left arm.
- **A cut in the recovery is unchanged:** the bomb has gone and the hand was already leaving view; it goes at once.
- **The bomb still goes from the hand at the cut** (GT2's put-back rule, tested): the empty hand eases back.

## Known issues left

- None new. The hand still goes at once if a throw is cut off in its follow-through (the bomb already gone).
