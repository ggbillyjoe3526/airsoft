# Critic, SM2 attempt 6 (766fc02)

Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓ · Score 7/8 → Accept

- Yellow reads yellow (esc-on edge hue 45°, sat 0.59 to 0.69; was 0.27); the rest is the game-wide AgX grade (ART.md).
- Decks and rims smooth, no bands; drum tops bright (218); plumb fronts ~92-100, near the photo's housings (100-133).
- Landing display seated on the architrave head; spiral and platform stair nosings yellow; changelog matches.
- Check 4: test_sm2_full_colour fails without keep_by_alpha. Check 3: material keys built once in build().
7. (non-blocking) look_vertex.gdshader's keep_by_alpha comment named only the skyline; test loops untyped.
   Fixed after the verdict: comment updated, loops and `seen` typed.

Advisory: decks render matte off-white (the props' shader, game-wide); each bank end is one bullnosed slab where the
photos show separate drums and a panelled housing. Owner checks went to the Dev 3 checklist.
