Task: SM3 · Subway ticket hall and concourse models (#19-26)
Attempt: 6 of 4 (past the cap; the thread fixes until the critic passes)
Head: 37711b2 (checks passed on it: check.sh exit 0, 5,934/5,936 passing, none failing)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Gate against photos 120140/120146 and ig11 (reader, gates2, close). Fixed since attempt 5, ratios to
   the paddle top, photo 120146 vs build: column top 0.73 vs 0.74 (ticket_gate.py:30), foot 0.49 vs 0.49 (:43),
   screen post 1.0 vs 0.93 (:27, the box limit in SM3.md › Decisions, accepted), head 0.10-0.12 vs 0.11 (:91),
   column width 0.14 vs 0.14 (:28); head width / column width 1.2 vs 1.2 (:38). All within 10 %. Neck root filleted
   (:146). Still failing:
   - Reader colour, even against the look's cap: in game the disc measures saturation 0.18, luma 178-192, hue 44
     (reader.jpg, gates2.jpg); attempt 5 measured 0.22, so it got paler. The palette yellow 0xE4CA46 (sat 0.69) at
     paint_saturation 0.6 should land about 0.4, and the kiosk's green keeps 0.54 of its paint (0.25 of 0.46) in the
     same frame; the yellow keeps 0.26. The bright paint is being washed toward white by the light and tonemap, so
     the cap doesn't explain it (ticket_gate.py:99-100). In game it reads cream (v3d close-up), the photo's reader
     sat 0.62-0.70: still not the gate's most legible part.
   - Reader face too flat: the slope is 23° off horizontal (head outline :92, 0.196 m run over 0.085 m rise), so the
     disc reads as a squashed ellipse, height/width 0.67 in gates2 against 0.88 in photo 120140 from a like angle
     (24 % off); with the head's 0.27 m length on the body's top, it still reads as a lid, not the photo's steep
     wedge facing the walker.
   - (d) Bar: posts, body and paddles now sit right next to the photo; the reader, the gate's focal point, does not.
   Note (not failed): the shut blades are about 1.3 tall to 1 wide against the photo's 2.7; the owner's 1 m lane
   forces this (real wide lanes have squarer paddles).
   Checks 2-8: since attempt 5 only ticket_gate.py constants and geometry, both .glb, SM3.md and ASSETS.md. Counts
   1,913/2,000 and 392/400. QA (attempt 2) and performance (Pass) stand.
Must-fix for the next attempt:
- Reader at median saturation 0.4 or more and hue 45-55 in reader.jpg's framing: a deeper, more saturated reader
  paint (it reads paler as it gets brighter; try a lower value with full chroma), or a lit disc. Real readers are
  backlit (photo 120140), so a soft emission is fair if paint can't reach it. Re-measure after.
- Steepen the head's slope to about 40-45°: shorter along the lane (about 0.16 m), its back about 0.15 m tall, so
  the disc faces the walker (aim for an ellipse of 0.8 or more at eye height).
Owner should test in the game (at most 6, one line each):
- From the street at 3 m: do the readers read yellow, and the slim posts as steel?
- Walk and sprint through a lane; watch bots pass the gate line: no snag, queue or jam.
- Paddle swing (0.35 s): opens in time, no pop with two people, no blade through a pedestal.
- A BB through a shut look-only paddle: readable, or does it feel like a bug?
- The squarish paddles in 1 m lanes: do they read as gate paddles?
- The 14-gate line as cover at the Street start: does it still play as a fight space?
