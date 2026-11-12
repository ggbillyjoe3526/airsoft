Task: SM3 · Subway ticket hall and concourse models (#19-26)
Attempt: 4 of 4
Head: 2f1f95d (checks passed on it: check.sh exit 0, 5,901/5,903 passing, none failing)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment). This was attempt 4 and check 1 failed, so no auto-accept: stop and report to the owner (pipeline/README.md › Verdict and attempts)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Gate against photo 120140, on sheet 15-v3b (in game, street side, shut). Pixel luma, 5th/50th/95th percentile:
   - Paddles, street side: 10/12/16 (two blades). Platform side: 20/25/70. Photo: 17/21/25 and 20/26/32. Attempt 3
     asked for 15-35 with a visible gradient. From the street, where the player meets them, they are still flat black
     cut-outs with no shading across the blade. PADDLE slab*0.8 and roughness 0.45 (ticket_gate.py:37,
     gate_paddles_config.gd:25) moved the median from about 6 to 12. That is not enough.
   - End column: round now (ticket_gate.py:47, 24 sides, r 0.211). In game it measures 15/34/46; the photo's measures
     132/158/171. STAINLESS is concrete*0.8 (stationkit.py:20), so it reads as a dark grey drum, not bright steel.
     Flat shading shows each of the 24 facets as a vertical stripe in the close-up: faceting on a curve, a fail
     under (b).
   - The column still stops at TOP + 0.012 (ticket_gate.py:48). In the photo it runs up to the reader head, about
     paddle mid-height, and the head sits on it. Here a wide dark slab of a head overhangs a short drum. Ratio
     column height / paddle top: photo about 0.75, build about 0.53 (0.75/1.42). That is more than 10 % off.
   - The reader heads in game are dark slabs. The yellow reader seen in the Blender render can't be seen from the
     street side. In the photo it is the most legible part of the gate.
   - Paddle neck: one outline now (ticket_gate.py:140-143). Its root corners are sharp (radius 0.0) and in game it
     sticks out of the blade's side as a black square tab beside the pedestal, not into a slot. It reads as a tab.
   - (d) Bar: next to 120140 this does not pass as finished work. The photo's identity, bright steel columns with
     yellow readers between dark paddles, is lost in game.
   Checks 2-8: the changes since attempt 3 are constants, the Blender script and one .tres sub-resource
   (play_tuning.tres:336, new ids, existing ones kept). QA (attempt 2, re-checked Pass on 7b9859a) and performance
   (Pass) stand.
Must-fix (for the owner's call on the next step):
- STAINLESS on the gate column much brighter and metallic (luma 130+ in game), with smooth shading on the cylinder.
- Column from the floor up to the reader head (about 1.05 m), with the head seated on it, narrower than the drum.
- Paddles 15-35 from the street with a visible gradient (a lighter rim or a rougher tone that catches the lamp).
- The neck's root goes into a visible slot in the pedestal housing, with filleted root corners.
- The yellow reader lit or emissive enough to read from 3 m.
Owner should test in the game (at most 6, one line each):
- From the street, do the gates read as the photo's: bright steel posts, yellow readers, dark paddles?
- Walk and sprint through a 1 m lane; watch bots pass the gate line: no snag, queue or jam.
- Paddle swing (0.35 s): opens in time, no pop with two people, no blade through a pedestal.
- A BB through a shut look-only paddle: readable, or does it feel like a bug?
- The booking counter under its light: old wood or a black cabinet?
- The 14-gate line as cover at the Street start: does it still play as a fight space?
