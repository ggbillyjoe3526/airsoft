# BW2 · The Sniper Rifle's bolt worked with a straight wrist

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-06 | 1 | thread | arms (13), BW1 QA (3), grenade arms (15), model pictures (7) pass; full arms build clean | Retry 7/8 | the scope's clearance unshown (the hand's new turn about the handle; scopes are not in the build's collision check) |
| 2026-11-06 | 2 | thread | as attempt 1; in-game pictures with the 2x and Variable Scopes fitted | Accept 8/8 | – |

## What the owner asked (2026-11-06 17:37)

"what's the issue with the sniper's bent wrist? fix it." BW1's bolt clip kept the hand's grip on the knob fixed (it
turned only half the bolt's turn), so as the bolt came back the wrist bent to about 53 degrees, the hand cocked over the
receiver (BW1's critic; KNOWN_ISSUES).

The owner, 17:55, on the pictures (review23): "perfect".

## What changed

- **On the knob** (`tools/blender/arms/cycle.py`, `BoltWork.straightest`): each key, the hand turns about the knob's
  centre (about the handle's line and the bolt's axis) to the turn that bends the wrist least, with the glove clear of
  the replica and the arm's skin clear of the stock; at most `SPIN_STEP` (10 degrees) from the last key, so it eases
  round, and `SPIN_MOST` (70, 40) either way. The knob stays in the curl of the index finger.
- **On the way** there and back (`BoltWork.way`): the elbow bends where the wrist is straightest for the hand there,
  eased in from the hold's, and mid-way the hand turns part way (`STRAIGHTEN`, half at the middle, none at either end)
  toward lying in line with the forearm.
- The wrist's greatest bend through the clip: 28 degrees (was 53 on the knob, 35 on the way); the hold's own is 24. The
  greatest turn used on the knob: 40 degrees about the handle, -30 about the bolt's axis (`BL_BOLT_TRACE=1` prints
  each key's).
- With either scope fitted the glove stays right of and below it through the cycle, in game at the hip (review23
  pictures 5 and 6); the scopes are still not in the build's collision check (KNOWN_ISSUES).
- The changelog bullet joins BW1's note (`sniper-bolt-by-hand.md`): BW1 isn't released yet.

## Known issues

- At the hip the hand is half off the screen's right edge mid-cycle (KNOWN_ISSUES).
