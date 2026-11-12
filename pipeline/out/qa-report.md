Task: EC1 · QA commit pending · Verdict: Pass

Blocking: none.
Advisory:
- game/play/sim_audio.gd:521 (_exit_tree set_echo(null)) resets the global Shots bus when ANY SimAudio leaves the tree. If a new Subway SimAudio were set up before the old one is freed (overlap), the old one's exit would silence the new echo. Not reproducible via the current scene change/restart order (old exits first); no test pins it.
- The echo is global AudioServer state; tests that call setup with a Subway map must reset it (the EC1 test does in after_each).

Checked (all hold): Shots is bus 3 under Effects; Power, Muffled, ShotsHalf, ShotsFull send to Shots; every bus sends to a lower index; reverb is Shots' effect 0, off by default, bus 0 dB. Only &"subway" has an echo; range, depot, woodland, kingsmere (old id), unknown and no map set the bus dry. Occlusion levels for Shots equal Effects' at 0.3/0.5/0.8/1.0; Effects/Footsteps/Power mapping unchanged; silenced shot open stays on Muffled, occluded goes to ShotsHalf/Full. Leaving the tree restores 0 dB / reverb off; repeated set_echo keeps one effect. Settings volume buses (Master/Effects/Power/Ambience/Interface) untouched.

Tests added (tests/unit/test_ec1_shot_echo.gd, after the existing six):
- :105 every bus sends to a lower index; Shots children wired right. Fails if a send is reordered/wrong (checked by reading old layout: Power/Muffled sent to Effects).
- :117 other maps incl. kingsmere/unknown dry after a Subway echo. Fails if setup skipped set_echo(null).
- :125 silenced shot open/occluded bus. Fails with the old EffectsHalf mapping.
- :130 set_echo twice / null twice leaves one effect. Guards effect duplication.
Existing six EC1 tests reviewed, they exercise the criteria.

Suite (individual files, no check.sh per instructions): test_ec1_shot_echo 10/10, sound_mix 8, sound_occlusion 13, au1_qa 27, sp2_qa 9, parts_in_play 15, subway_rename 3: all pass. gdlint clean. Raw: pipeline/out/qa/ec1_test.txt.
Not tested: how the reverb sounds, real audio output, smoke match (check.sh running elsewhere); owner to listen on Subway vs Woodland.
