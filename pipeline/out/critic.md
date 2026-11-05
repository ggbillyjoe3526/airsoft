Task: GT1 · Bots show the bomb in hand and throw it
Attempt: 1 of 4 · Head: 5cf0d31
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 6/8 → Retry (near miss)
1. [judgment] "Coming over" doesn't read as a throw: the hand and bomb pass across the goggles and face (a straight line
   cocked → release, figure_throw.gd:83-85); the armpit swells past the vest under the raised arm in close-up.
8. [judgment] KNOWN_ISSUES still says the figure has no throw animation; no rows for the armpit or the deferred
   first-person hands.
Must fix: a key beside and above the ear between cocked and release, with a test keeping Hand_R and Grip_R over
0.15 m from Head through shares 0.6..1.0 on both kinds; elbow at or below the shoulder; KNOWN_ISSUES rows; new
close-ups for the owner before the pull request; check.sh on the new head.
Advisory: a bomb held in hand (MC1) snaps to hanging as the throw starts (weight 1 → 0 at share 0); at "pin out" the
left hand never comes near the bomb.
