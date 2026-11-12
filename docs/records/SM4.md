# SM4 · Subway's works gear, booths and plant-room models

**Review:** pending

The owner (2026-11-12): "Begin work on subway models now." SM4 covers models 6-13 and 27-30 of
`art/subway-model-list.md`: the skip wagon, the engineering wagon, the ballast wagon, the platelayer trolley, the buffer
stop, the cable drum, the tunnel segments, the signal cabinet, the staff booth, the works hoarding, the fan housing and
the switch cabinet. Each is built from the owner's photos in `art/references/maps/subway/<NN-name>/`.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | Pass | Retry 6/8 | Loads, tarp, trolley wheels, buffer stop, drum and hoarding short of the photos; black plant-room props unlogged |
| 2026-11-12 | 2 | build thread | – | – | – |

## What changed

- **The models** (`tools/blender/maps/`, one script each, a shared `works_kit.py`): every one is a single
  vertex-coloured mesh that fills its block's box exactly, weathered per corner (grime from the foot, dust on top faces,
  rust in patches and streaks), with no writing, logos or liveries. Each stays within its model-list budget:

  | Model | Budget | Triangles | Notes |
  |---|---|---|---|
  | Skip wagon | 2,500 | 2,484 | A tipping skip of spoil on its cradle, stones in the heap |
  | Engineering wagon | 3,000 | 2,812 | Concrete sleepers under a strapped tarp on a flat wagon |
  | Ballast wagon | 2,500 | 2,464 | Plank sides and a speckled ballast heap |
  | Platelayer trolley | 1,200 | 1,170-1,188 | Three sizes, the size picked by the box; spoked wheels |
  | Buffer stop | 1,500 | 1,378 | Yellow and black, on two pedestals, round buffers |
  | Cable drum | 1,000 | 972 | Two sizes, the cable in ridged turns |
  | Tunnel segments | 1,500 | 1,424 | Two stacks of lining segments on bearers |
  | Signal cabinet | 800 | 780 | Shut |
  | Staff booth | 3,000 | 1,748-2,732 | Three sizes, blinds down; the small one has less wall to dress |
  | Works hoarding | 1,500 | 1,320-1,500 | Three sizes, a closed compound with a padlocked gate |
  | Fan housing | 3,000 | 2,666 | Four fans in its end, a duct on its roof |
  | Switch cabinet | 800 | 750 | Two bays, shut |

- **Defaults taken** (the owner's DEFAULTS RULE):
  - The vehicles' boxes stand about 0.65 m off the station's rails, so each wagon and trolley sits on its own short
    900 mm works track inside its box. Moving the boxes onto the rails would be a play change.
  - The trolley is works yellow. The photos show red, but every red tried read as a team's hue.
  - The engineering wagon is a loaded flat wagon, the model list's gap default.
  - The cabinets are shut and the booth blinds are down, because the station is abandoned.
- **Facing** (shared with SM3's benches): a block may name `facing` (`+x`, `-x`, `+z` or `-z`), the world direction its
  model's front points. FIT then turns the model that way, its width across the front, instead of toward the field's
  middle (`MapData.Block.facing`, `PropLayout._fit_facing`, `tests/unit/test_sm4_facing.gd`). The booths face the
  platform's edge, and the buffer stops face their track.

## Decisions

- Coplanar faces render black in Cycles, so the hoarding's walls stop at its corner posts instead of running under
  them.
- Browns and rust stay under 0.3 saturation, because warmer ones read as a team's hue in linear space.
- The blocks' boxes are kept as they are, so some models are squatter or longer than their photos (the drums, the
  buffer stop, the wagons). Resizing a box is a play change, offered to the owner.
- `works_kit.finish` turns every face outward (rays cast from outside the box), because hand-built pieces had 2-4% of
  faces backwards and the face test caught them.
- Details that reached past a box were moved inside it, since clamping them flat made degenerate triangles.
- The plant-room props draw black in the cloud's renders, whatever model stands there (a booth did too), so it is the
  room's light, not the models. Logged in `docs/KNOWN_ISSUES.md` and on the Dev 3 checklist.
