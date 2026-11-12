Task: SM3 · Subway ticket hall and concourse models (#19-26)
Attempt: 3 of 4
Head: cb5c74e (check.sh partly green per the brief: unit parts 1-5; the rest still running, to be re-run in full on this head)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Gate and paddle (v3 sheet 14 vs 19-ticket-gates 120140, 120146). Ratios, photo / build:
   - paddle height / width: about 3.0 / 2.8 (0.96 x 0.34 m). Pass.
   - paddle top / box top: about 1.2-1.3 after perspective / 1.42. Borderline; let it stand.
   - paddle foot / box top: about 0.4 / 0.46. Pass.
   - body top / box top: about 0.84 / 0.74 (TOP, ticket_gate.py:30). About 12 % low; a minor item.
   - screen post: about paddle-top height / capped at the 1 m box. Accepted, since the owner's notes.txt says the
     gate is "1 m tall" and the record states the reason.
   - In game the shut paddles are flat black cut-outs. Pixels on sheet 14 read 3-9 of 255 across every blade, with
     no gradient. The pedestals next to them read 4-34, though their paint is nearly the same (slab*0.62 against
     PADDLE slab*0.6, ticket_gate.py:32,37). The photos' paddles read 15-32 with their shape shading. So the
     relight (gate_paddles.gd:144, LIGHT_LIFT 0.9 at :12) still under-lights them. Attempt 2's must-fix
     ("not pure black … so it shades") is not met.
   - Construction: the end column is not round. rounded_rect(BW+0.006, COL_R, COL_R) (ticket_gate.py:46) is a
     0.42 x 0.26 m stadium with a flat 0.16 m face toward the street, and in game it reads as a grey box. In
     120140 it is a bright cylinder.
   - Construction: the paddle's arm is a flat 0.16 x 0.24 m plate on the blade's side (ticket_gate.py:137-138).
     In the close-up it reads as a tag stuck on, not a neck. The stadium ends show their facets
     (fillet 6 a corner, :135).
   Booking counter: low-chroma dark brown in game (HSV hue 0.03-0.10, saturation about 0.3). No longer plum. Pass.
Must-fix for the next attempt (the last):
- Paddles: in game they must take about the same light as their pedestal and show their shape. Either fix the
  relight sample/instance colour or lighten PADDLE (about slab*0.8), and add a lighter rim on the top curve. Check by
  pixel: 15-35 on the blade with a visible gradient, as in the photo.
- End column: a true cylinder, radius about the body's half-width, floor to the reader head, bright stainless.
- Paddle arm: a tapered neck that grows out of the blade's edge into the slot (one outline, not a second plate). Move
  the arm's triangles to the fillet (8 a corner) so the ends read round in close-up.
- Optional: raise TOP to about 0.82 so the body and head match the photo's split.
- Re-render sheet 14: the same angles, plus a 1.5 m close-up of one lane in game.
Owner should test in the game (at most 6, one line each):
- Walk and sprint through a 1 m lane, and watch bots pass the gate line: no snag, queue or jam.
- Paddle swing (0.35 s): it should open in time, with no pop when two people pass and no blade through a pedestal.
- Under the hall light: do the paddles read as dark grey doors, or as black holes in the gate line?
- Look-only paddles: a BB passes a shut paddle. Is that readable, or does it feel like a bug?
- The booking counter under its light: does it read as old wood, or as a black cabinet?
- The 14-gate line as cover at the Street start: does it still play as a fight space?
