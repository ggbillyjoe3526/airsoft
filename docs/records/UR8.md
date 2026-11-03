# UR8 · Magazine boxes at the HUD panel's left

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Goal

The owner, looking at the HUD after UR7: "Move the magazine count (the blocks not numbers) to the left of the square."

## Approach

- `ReplicaPanel`: the magazine boxes (`MagGauges`, still as wide as its boxes) sit at the panel's left edge, in line
  with the replica's name under them, instead of at its right under the count. The bombs, the count and the chips stay
  at the right.

## Decisions

- **"The square" is the replica panel.** The boxes stay inside it, on their own row, at its left edge; moving them
  out beside the panel would leave them over the scene with no backing.
- **HUD opacity was already there.** He also asked for a HUD opacity setting "if there isn't already": Settings › HUD
  › HUD opacity (50 to 100 %, the panels only; text stays solid) has been there since the HUD tab was built, so
  nothing is added.

## Checks

- pending
