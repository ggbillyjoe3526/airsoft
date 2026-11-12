Task: SM4 · Subway works gear, booths and plant-room models (#6-13, #27-30)
Attempt: 3 of 4
Head: 15144d784b89060a71b50dc799440b92098c8a03 (checks passed on it)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment); the main fault needs an owner ruling on the boxes.

1. [judgment]
- The vehicles don't stand on their track: in game each wagon's own short rails lie about 0.65 m beside the running rails (track-2-tunnel.jpg, track-1-platform.jpg), reading as a third, misaligned track. Only moving the boxes onto the rails fixes it: a play change, the owner's call.
- The ballast load reads as a camouflage print on a smooth dome (v3_ballast_wagon.jpg); the skip's rubble passes.
- No pictures of the vehicles after ec4c175 took the works track's sleepers off.
Passing now: tarp, trolley wheels, cable drum, hoarding, fan housing outlet; buffer stop, booths, cabinets, segments.
Passed: 2 look data only; 3 _add_track once at build, fewer boxes; 4 the new sleepers test fails on the old code; 8 the track change is the owner's ask, recorded.
Must-fix: put the boxes-onto-the-rails question to the owner (if yes: centre the six vehicle boxes on the running rails, drop the works track, wheels on the 1.5 m gauge; if no: record his ruling); ballast with relief and mostly dark stones; re-render the vehicles' sheets from the head .glb files.
Owner to test: the vehicle boxes ruling; grey rails and wagons lit on a real GPU; plant room lit; loads at 6-15 m; booth blinds; F3 overlay on Subway at Low.
