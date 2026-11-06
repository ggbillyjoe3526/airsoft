Task: HS1 · Replicas worn on the figure: the pistol in the holster, the rifle on the back (port onto main after BL12, confirmation round)
Attempt: 3 of 4 (Accept kept)
Head: c822910 (figure tests 24/21/19/17/9/13/7 pass on it per the brief; I reran test_figure_hands: 24/24, 565 asserts). Full tools/check.sh still running: the Accept holds only once it is green on this head.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Port fidelity, with evidence:
- Same 24 files as 6340d2b..032ac0e. The +/- lines match line for line in every file except the four below.
- figure_hands.gd / figure_body.gd: only the doc comments differ. They keep main's GT1 bomb and empty-well sentences and add HS1's back/holster wording.
- figure_hands.gd:180 uses main's `site_class` instead of the old inline classes[i] expression. It has the same meaning.
- KNOWN_ISSUES.md: HS1's "rifle on the back, pistol in the belt holster" is applied to main's row, which had already dropped the magazine-in-well clause. Both sides are kept.
- No `sling`/`slung` remains in any code path: grep over game/, tests/ and tools/ finds only comments and the sim's unrelated "on the sling".
- gear.py:939 `seat = cant @ Matrix.Translation(PISTOL_SEAT_AT)` is the one real change. The seat follows the shell's cant, not the level mount (the comment at :938 says so). HS1.md:38-40 records it.
- human.glb: the binary chunk is byte-identical to main's (8953144 B). The JSON differs only by the added root node PistolHolster (node 92, scene list 92→93 entries).
- st11 renders: both pistols sit in the moved holster's mouth when standing, crouched and running. The slide is on the shell's line, with no clipping or gap. The running hand clears the grip. The AEG lies across the pack as in st10.
Failed checks: none.
Non-blocking:
- game/play/figures/README.md:14,19 still say "slung"/"slung on Chest". This predates the port (HS1 never touched it). Update it in the records commit: "on the back / in the holster".
Must-fix for the next attempt: none.
Owner should test in the game (at most 6, one line each):
- A bot with the pistol holstered, running and crouching: does the pistol stay in the moved, canted holster?
- A bot switching rifle↔pistol: does the draw from the forward hip look right?
- The AEG on the pack from the side: does it read as resting on the pack rather than floating behind it?
