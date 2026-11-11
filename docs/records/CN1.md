# CN1 · The shirt collar at the back of the neck

**Review:** pending

Owner's report (2026-11-10, screenshot): from behind, the figures' neck showed a dark V above the carrier, "glitched";
it should look like a natural clothing collar. Every human figure (player and bots) wears the same `Body` and heads.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **Cause.** BL10's mock-neck collar was a ring round the figure's axis, 12 mm ahead of the heads' neck
  (`head_shapes.NECK`), so behind it stood 5 to 9 mm inside the neck and the balaclava's knit cut through it in a V.
  And the heads were skinned whole to `Head` while the collar is about half `Neck`, half `Head`: when the head turned
  or pitched against the neck (aiming, the cheek on the stock) the neck's foot swung out behind the collar.
- **The collar** (`tools/blender/figures/collar.py`, shared by `body.py` and `headwear.py`) is two half ellipses round
  the neck's own axis: the front exactly as BL10 cut it (the zip pull stays), the back 7 mm clear of the neck inside
  (as the sides), and 10 mm higher at the back, as a shirt's collar stands. Same vertex count: the body's 33,458
  triangles are unchanged.
- **The neck bends with the collar** (`splice_heads.py`): each head vertex within 108 mm of the neck's axis behind
  (88 mm ahead, so the chin, ear cups and brims stay whole on `Head`) takes the weights of the nearest collar vertex,
  easing to `Head` alone between 1.525 and 1.565 m behind (1.455 to 1.48 m ahead, under the chin).
- **The boonie's scarf** lies 7 mm over the collar (it used to lie over the old, smaller collar; the new one took its
  tail inside), easing back onto the neck 15 mm above the collar's top.
- **Rebuild order** (README): `body.py` and its splice, `pads.py`, `gear.py`, `body_weights.py`, then `headwear.py` last
  (its neck reads the body's collar weights). The carrier's and pack's shoulder straps refit up to 8 mm round the
  collar's new back; nothing else in the file moved.
- **The glove plates' tie** (`body_weights.py`, `test_bp6_models.gd`): the right wrist strap's tab has points where
  the hand's and the forearm's weights tie, which go to the arm; the rebuild left float noise there, so the tab read
  as a 29th plate and went rigid on the hand. Weights within `TIE` (1e-3) are now a tie in the tool and the test alike.

## Known issues left

- None.
