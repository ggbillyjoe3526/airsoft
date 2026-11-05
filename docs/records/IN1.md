# IN1 · Inspect your replica

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

The owner asked in chat (2026-11-05) whether the game had an inspect weapon button, then "Ok do that". Every replica
model already carried an Inspect clip (BL1, BL2, BL5, BL6) that nothing played; the browser game had the key (RM2).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Opus 5.5 (build thread) | – | 8/8 Retry | QA's report still read Fail (its two bugs already fixed) and no performance report on disk; advisory: a press during the ease-back snapped to the first key |
| 2026-11-05 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **Y.** The browser game's key, free since MC1 moved the bombs to 4 and 5. A save from before takes Y unless the
  player's own key holds it, then Inspect starts keyless (never two actions on one key).
- **Presentation only.** The press is a frame's latch (`PlayerInput.take_inspect`), never in PlayerCommand: nothing in
  the simulation changes, and bots don't inspect.
- **Poses from the browser game, re-tuned for the Godot hold.** The rifles turn 1.2 rad (was 1.0) and sit 0.18 m
  further out (0.3 m for the longer sniper) so the whole replica stays in view; the pistols 3 cm further in. Lengths
  are the models' own clips: 3 s rifles, 2 s pistols.
- **Sounds re-timed to the Godot clips,** from cues the game already has (selector, torchClick, the replica's own dry
  fire and magazine in); no new files.
- **What ends it:** a shot, a hit, a reload, a draw, a switch, the holster (a bomb in hand too), a sprint or the sight
  past 5 % raised. The pose eases back over 0.15 s; the parts go to rest at once. A press during that ease-back is
  dropped, not snapped. Dry-firing an empty replica (no shot) doesn't end it.
- **Reduced motion draws the full turn:** the player asked for it, and it moves the replica, not the camera.
- **Not behind the order wheel or the map:** a press there is dropped.
- **The poses are written into `play_tuning.tres`** as well as the script's defaults: an export reads the saved file,
  where `InspectPose.make` never runs (`test_saved_configs`).

## Known issues left

- The first-person arms (BL4, PR #204) don't follow the inspect pose yet; that thread owns the hand poses.
