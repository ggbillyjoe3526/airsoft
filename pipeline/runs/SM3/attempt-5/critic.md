Task: SM3 · Subway ticket hall and concourse models (#19-26)
Attempt: 5 of 4 (past the cap; the thread fixes until the critic passes)
Head: dd0152d (checks passed on it: check.sh exit 0, 5,923/5,925 passing, none failing)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Gate against photos 120140 and 120146 (ig10/gates2.jpg and reader.jpg, after the reader fix). Fixed since
   attempt 4: paddles now 27/32/38 luma (5th/50th/95th) with shading; the column is bright and smooth (32 sides).
   Still failing:
   - Reader is cream, not yellow: disc 99/155/159 luma, median saturation 0.22; the photo's is 113/195/224, sat 0.64.
     yellow*0.62/0.8/0.4 (ticket_gate.py:94-97) darkens it toward beige; it still isn't the gate's most legible part.
   - Proportions, measured on 120146 (left gate, floor y 297, paddle top y 42) against the build (paddle top 1.22):
     column top / paddle top 0.73 vs 0.62 (ticket_gate.py:49, TOP+0.012), 15 % off; screen post top / paddle top
     1.0 vs 0.82 (H=1.0, :105-107), 18 % off; paddle bottom / paddle top 0.49 vs 0.33 (BLADE_Z0 0.4, :41), 33 % off;
     column width / paddle top about 0.14 vs 0.35 (COL_R 0.211, :28): a fat drum, not the photo's slim post;
     head height / paddle top 0.10 vs 0.12 (ok). Four of five are more than 10 % off.
   - The column is still capped at body height and the head is a flat lid (0.15 m tall on 0.39 m wide, :85); in the
     photos the slim post runs up to the head and the screen tower rises to the paddles' tops.
   - Neck root corners still radius 0.0 (ticket_gate.py:141): in gates2 the arm reads as a square dark bar between
     each pair at the pedestal, not a neck into a slot.
   - Column on the middle gate (shadowed) is 43/71/89 against the photo's 134/163/175; the lit ones read steel.
   - (d) Bar: closer, but not yet the photo's gate next to it.
   Checks 2-8: since attempt 4 only ticket_gate.py constants, gate_paddles_config.gd defaults (post_off -0.03,
   roughness 0.45) and the hallkit.py rename (imports and README updated; stationkit.py is SM5's). QA (attempt 2)
   and performance (Pass) stand.
Must-fix for the next attempt:
- Reader saturated yellow (sat 0.5+, luma 180+ in game): raise the paint to yellow*1.0 or more, or emissive.
- Slim column (about 0.07 m radius) from the floor up to about 0.9 m, the head seated on its top.
- Screen post up to about the paddle top (1.2 m), its screen near the top.
- Blade bottom near 0.6 m (keep the top at 1.22), keeping the arm inside the blade's height.
- Neck root corners filleted (0.02 or more) at (0.0, ARM_Z), the root going into the housing's slot.
Owner should test in the game (at most 6, one line each):
- From the street at 3 m: do the readers read yellow, and the posts as steel?
- Walk and sprint through a lane; watch bots pass the gate line: no snag, queue or jam.
- Paddle swing (0.35 s): opens in time, no pop with two people, no blade through a pedestal.
- A BB through a shut look-only paddle: readable, or does it feel like a bug?
- The 14-gate line as cover at the Street start: does it still play as a fight space?
