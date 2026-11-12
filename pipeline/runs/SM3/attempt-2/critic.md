Task: SM3 · Subway ticket hall and concourse models (#19-26)
Attempt: 2 of 4
Head: 4d5b994 (check.sh partly green per the brief: gdlint, notes, wiki, unit parts 1-4; smoke and licences not yet reported)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Gate and paddle against 19-ticket-gates (120140, 120146 vs v2 sheets 10 and 12), ratios:
   - paddle top / pedestal top: photo about 1.6-1.7, render about 1.0 (paddles stop flush with the body top). Over 10 % off.
   - paddle height / width: photo about 3:1 (tall, round-topped lozenge, narrow neck at the hinge); render 1.3:1
     (a square plate with one chamfered corner on an exposed pole). Over 10 % off.
   - screen post above the body: photo it rises to about paddle-top height; render a short stub about 1.15x. Over 10 % off.
   - reader head: photo an angled box (face about 30 degrees) on a round stainless end column; render a flat cap.
   - lane / pedestal width: photo about 2.8, build 2.04 (1 m / 0.49 m). Accepted: the owner's one-person lane and the
     nav cell (record, Decisions).
   - Body: access doors, louvres and rivets make the pedestal read as a utility cabinet or bin in game (sheet 12,
     panels 1-3); the photos show a plain dark upper body on a brushed steel skirt, nothing else.
   - In game the shut paddles render as flat pure black slabs with no shading, making a near-solid black wall
     across the gate line (sheet 12, panel 1).
   Booking counter (#23): mahogany 0x501c38 reads as plum or aubergine with no grain (sheet 11); it does not read as wood.
   To keep clear of the team hue, lower the saturation rather than turning the hue: a dark, low-chroma brown.
   Bench, machines, office, barrier, kiosk, help point: attempt 1's fixes landed. Nothing blocking left there.
Must-fix for the next attempt:
- gate_paddle (tools/blender/maps/ticket_gate.py): tall rounded-top lozenge, about 0.35-0.4 m wide and about 3x as tall
  as wide. Top about 1.5 m off the floor, well over the 1 m body. Narrow neck into a hinge housing hidden in the
  pedestal, with no bare pole. Not pure black: dark grey rubber with a lighter edge so it shades.
- ticket_gate: drop the cabinet doors, louvres and rivets. Plain dark upper body on a brushed steel skirt. Rounded
  stainless end column carrying an angled reader head with a yellow pad. Screen post tall, up to paddle-top height.
- booking_counter: desaturated dark brown, a light grain or panel-edge highlight; re-run test_props.
- Re-render sheets 10-12 from the photos' angles (front-quarter row view like 120146) and the in-game gate line.
Owner should test in the game (at most 6, one line each):
- Walk and sprint through a 1 m lane; check it never snags, and that bots don't queue or jam at the gate line.
- The paddles swing as you walk up: timing (0.35 s) and the 1.6 m reach feel right, with no pop when two people pass.
- Look-only paddles: a BB passes through a shut paddle, and a crouched player behind one is still hittable. Is that
  readable (decision card)?
- The 14-gate line as cover at the Street start: does it still play as a fight space and not a wall?
- Counter colour under the booking hall's light: wood, or purple?
