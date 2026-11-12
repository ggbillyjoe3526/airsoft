Task: SM3 · Subway ticket hall and concourse models (#19-26)
Attempt: 7 of 4 (past the cap; the thread fixes until the critic passes)
Head: a8566f3 (checks passed on it: check.sh exit 0, 5,945/5,947 passing, none failing)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence for check 1 (the two attempt-6 must-fixes), from photo 120140 and ig12 (gates2, close, 21-v3e-gates.jpg):
- Head slope: ticket_gate.py:91 runs 0.13 m over 0.13 m rise (45°), 0.16 m along the lane (:88), back 0.15 m.
  The disc's ellipse in gates2, three gates measured: height/width 0.91, 0.87, 0.86 against the photo's 0.88.
  Reads as the photo's wedge facing the walker, no longer a lid. Pass.
- Reader colour, measured by me: gates2 discs at sat 0.28 and 0.26 (p90 0.32), value 0.45-0.51, hue 47-48. The
  station's yellow tactile strip (fl1/concourse.jpg) is at sat 0.29, value 0.54, hue 51. The 0.4 target from
  attempt 6 can't be reached by paint under the owner's art direction (docs/ART.md:124, paint_saturation 0.6,
  look_light.gdshaderinc:21-23). A prop emission path would change the shader for every prop, which is outside
  SM3's scope. The reader now matches the station's own yellows and reads as the gate's yellow accent in gates2
  and 21-v3e. Pass against the look's limit, recorded in SM3.md › Decisions:61-64.
- Proportions from attempt 6 stand (column top 0.74, foot 0.49, head 0.11, column width 0.14, head/column 1.2,
  all within 10 % of photo 120146). Gate 1,929/2,000 triangles.
Checks 2-8: compared with 37711b2, after the rebase on TB1 the same file set changed. The only differences are
ticket_gate.py's reader_head (constants and outline, :85-104), the two .glb files, SM3.md and this run's records.
build_map/layout/station_dress hunks are identical. QA (attempt 2) and performance (Pass) stand.
Notes, not failed:
- In the close-up (close.jpg, value 0.35) the disc reads khaki more than yellow. This is the look's cap in shadow.
  If the owner wants vivid readers, a backlit emission for props is a separate look task (docs/IDEAS.md).
- The shut blades are about 1.3:1 against the photo's 2.7:1, forced by the owner's 1 m lane (as in attempt 6).
Must-fix for the next attempt: none.
Owner should test in the game (at most 6, one line each):
- From the street at 3 m and close up: do the readers read yellow enough, or do they need a glow?
- Walk and sprint through a lane; watch bots pass the gate line: no snag, queue or jam.
- Paddle swing (0.35 s): opens in time, no pop with two people, no blade through a pedestal.
- A BB through a shut look-only paddle: readable, or does it feel like a bug?
- The squarish paddles in 1 m lanes: do they read as gate paddles?
- The 14-gate line as cover at the Street start: does it still play as a fight space?
