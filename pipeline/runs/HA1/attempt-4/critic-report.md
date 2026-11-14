Task: HA1 · First-person arms and grips, made realistic
Attempt: 4 of 4
Head: 04497dc (checks passed on it; = git rev-parse HEAD)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment: check 1 alone; QA Pass, performance Pass)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] (b)/(c) SMG far side, attempt 3's named must-fix "no finger hooked back (SMG index)" not met. In ha1-round4-far-side.jpg "NOW: Compact SMG, fingers side by side" the index still rises, folds back at the middle joint and points its tip down at its own root: a closed loop with daylight inside it, then a gap of about a finger's width to the middle finger. It reads the same as BEFORE. The record (docs/records/HA1.md:199-204) and the brief say "the SMG's index stands with the others"; the picture says it doesn't (hold_tables.py:318 SMG_GUARD).
1. [judgment] (b)/(c) Sniper far side: the pinch is gone, but now the index leans back with its tip pointing at the butt, the far side of a V of daylight from the middle finger (about two finger widths apart at the tips). Middle, ring and little fingers are closed together. A hand on a fore-end doesn't splay its index back like that (hold_tables.py:299 SNIPER_GUARD, tip_at forward 0.050 and tip_apart). The 16 mm spacing (test_ha1_qa3.gd LEAST_APART 12 mm, `sight.crowd`) only measures the last two bones of neighbours, so it can't catch a finger that folds back on itself or splays away.
1. Passes: AEG's far side as the owner set it (21:21, "Keep it as approved"). The record says so honestly (HA1.md:199-212, Known issues left; KNOWN_ISSUES Graphics row; DECISIONS First-person hands), and the test holds it to 15 mm. Front end: test_ha1_rifle_hold.gd:+287-314 covers Sniper and SMG at 5 mm. Hip view, Sniper right hand, palm, nails and thumb unchanged as passed. From below all three palms show flat, with the palm not under the handguard; the record says the palm can't move, as attempt 3 allowed.
2-6. No runtime code in attempt 4's delta. It touches arms.glb, build scripts, tests and docs. The game/ files come from the PB3/AU11 merge, reviewed by their own threads. Performance: 38,900/34,452 triangles, index counts identical. The front-end test fails on attempt 3's AEG (little finger past the end), and the spacing test is shown to fail on attempt 3's Sniper (9.0 mm).
Non-blocking notes (check 7 passes): tests/unit/test_ha1_qa3.gd:66's name says "a finger past it would fail", but the test only asserts that surface exists. hold_tables.py:199 says "fifteen trial solves", HA1.md:209 says "Sixteen". GUARD_SIDE is declared in both test files. ha1-final-hip.jpg's title still reads "attempt 3". HA1.md:19 still holds the ATTEMPT_ROWS placeholder (the records commit fills it).
Must-fix for the next attempt (or for the owner's call, attempt 4 being the last):
- SMG index: no loop. Lay it with the middle finger, middle joint at 60 degrees or less, tip pointing up the side face toward the bore, not down at its root. Close the gap to the middle finger to touching.
- Sniper index: lay it beside the middle finger, tip pointing up or a little forward, not at the butt. No V of daylight between index and middle from the side-on camera.
- Add a test that would have caught both: for each far-side finger on Sniper/SMG, the tip is no further back than its knuckle (along the bore) and stands within FINGER_APART + 4 mm of its neighbour's tip. Prove it fails on this model.
- Re-render the far side side-on and from below, and state in the record what the pictures show, not what the solver aimed for.
Owner should test in the game (at most 6, one line each):
- Stand beside a bot holding a Compact SMG: does its left index read as a hook or loop?
- Stand beside a bot holding a Sniper: does its left index stick out backwards from the other three?
- Beside a bot's AEG: is the fingertip past the handguard's end noticeable at play distance (your 21:21 ruling)?
- AEG, Sniper, SMG at the hip, gloves and bare: still only the left thumb while walking, firing and turning?
- Raise and lower the sight fast on each rifle: any pop of the left hand?
- Bare hands at 1440p: nails and tendons still as you approved them ("Perfect")?
