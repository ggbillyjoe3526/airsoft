# Critic, SM2 attempt 5 (7b85ac5)

Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗ · Score 6/8 → Retry (judgment)

1. Lift passes (five ratios within 10 % of ref 115640; chevrons read lit). Escalators fail:
   - safety yellow renders cream on screen (esc-on 227,208,166, hue 41°, sat 0.27; ref 243,213,41); also the spiral's
     and platform stair's nosings;
   - deck bolster tops show five flat bands;
   - deck fronts and newel ends dark slabs (~79), not bright stainless rounded drums;
   - (minor) landing display floats ~20 px over the architrave.
8. changelog line 6 "show the floor" is wrong (chevrons); line 2 "yellow edges" not what renders.

Must-fix: yellow reaching the screen (hue ~50°, sat > 0.7) on escalators, spiral, platform stair; smooth bolsters;
bright stainless rounded newels; seat the display in the frame head; changelog lines 2 and 6.
