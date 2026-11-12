# EC2 · A softer Subway echo

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The owner heard EC1's samples and played it, then asked: "That's a bit too much. Decrease reverb a little."**
  Room 0.72 to 0.62 and wet 0.28 to 0.2 (samples `audio/william/preview/ec1-softer/`); of those: "That's still too
  much reverb. Decrease a little more". Now room 0.5 and wet 0.14 (`ShotEcho`): a light slap and about half a second
  of tail (was about a second). The 2 dB louder shots, the pre-delay, damping and high-pass stay. Samples:
  `audio/william/preview/ec1-softest/` in the shared files. The existing unreleased changelog note was corrected in
  place rather than adding a second, contradicting one.
