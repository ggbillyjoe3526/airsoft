# BL7 · The power sources from the owner's photos

**Review:** critic Retry 7/8 on attempt 1 (in progress)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | touched tests pass (44); local part 1 timed out (exit 124, test_dd1_qa, not touched) | Retry 7/8 (QA Pass, performance Pass) | bottle's solid print ran to a V at half height; battery leads short and thin, stickers read as holes; LiPo balance plug small and hidden; spring coils 12-sided; black label and spring invisible |

## What changed

The four power-source menu models, rebuilt by scripts in `tools/blender/power/` from the owner's photos
(`ref_images.zip` › `gas_bottle`, `11.1v_lipo_battery`, `standard_battery`, `springs`):

- **Gas bottle** (`gas_bottle.py`): a 1 litre can 300 mm by 66 mm, its shoulder `r = R(1 - 0.42(1 - d)²)` measured
  on the main photo (within 1 %); a cap 0.58 of the body across with 60 fine ribs between a plain skirt and a rounded
  top; a rolled base round a dome; solid `Label` print down to a level line 30 % from the top, then two `Label`
  chevron stripes (level round the back, dipping 34 mm on the front, black inside), and a pale print band at the foot.
- **11.1 V LiPo** (`lipo_battery.py`): the Vapex-style black stick (124 x 19 x 21 mm) with pillowed, crinkled ends,
  faint cell waists and a red print band; main lead (red over black) to a tan mini plug, a four-wire balance lead
  inside its loop to a white 12.4 mm balance plug.
- **Standard Battery** (`standard_battery.py`): a red 9.6 V NiMH brick, two rows of four 2/3A cells, the shrink in
  the groove; two raised off-white stickers with faint grey bars; red and black leads, separate, to a lime mini plug at
  the pack's far end.
- **Spring** (`spring.py`): a painted 20 cm main spring, 40 turns (closed end coils, a progressive end), the whole
  wire the `Label`.
- Wires and plugs shared in `leads.py`. QA's `tests/unit/test_power_models.gd` checks the budget, the `Label` and the
  orientations.

## Decisions

- The owner's folders mix photos: `standard_battery/` holds one red 9.6 V NiMH brick and three small 7.4 V LiPos,
  `11.1v_lipo_battery/` two NiMH sticks, a round stick and one 11.1 V LiPo stick. Default: Standard Battery = the red
  NiMH brick (the folder's first photo, and the game's standard NiMH), 11.1 V LiPo = the LiPo stick.
- Budget raised to 6,000 triangles and 120 KB a power-source file (from 1,500 and 60 KB): menu pictures only, drawn
  once; the critic found the spring's coils faceted at 4,000. Owner rule: never wait, take the default and say so.
- Black Gas's and the M150 Spring's picture colour is gunmetal `5b6069` (was `2a2b30`): black on the black can and
  the dark card did not show.
- The gas can is black with the gas's colour on its cap and print (three of his four photos are dark cans).
- No text or logos anywhere: stickers and print are plain shapes.

## Known issues

- The spring's wire is five-sided: round from the menu's distance, faceted in a close render.
