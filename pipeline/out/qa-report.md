Task: UL2 · QA commit (see git log, "UL2 QA") · Verdict: Pass

Blocking: none.
Advisory:
- game/play/field_lighting.gd:305 doc comment line is 159 chars (gdlint passes; tidy when next touched).
- A flicker lamp (BAKE_DYNAMIC) contributes no baked SDFGI bounce, so flicker lamps on Subway add less ceiling light than the working ones; by design (roof_lamps.gd comment), only visible on Ultra.
Interplay checked by reading: set_underground is the only writer of sdfgi_energy/bounce after build (_grade runs once in build, field_lighting.gd:346; set_gi_quality in graphics_apply.gd:111 only sets RenderingServer ray/frame counts; set_effects only toggles sdfgi_enabled). So GraphicsApply re-apply and preset change keep the underground values. OpticGlass duplicates the env after set_underground (play_session order), so aimed/hip envs carry them. Lift car lamps and Subway lamps go through RoofLamps.build (roof_view.gd:79); Depot is not plain, keeps 1.0 (pinned).

Tests (tests/unit/test_ul2_underground_bounce.gd):
- :13,:22 underground/above-ground/restore bounce values; fail if set_underground did not set sdfgi_* (old code leaves 1.0/0.5).
- :34,:42 plain lamps get plain_lamp_indirect, hall lamps stay 1.0; fail without the roof_lamps.gd line (default 1.0).
- :49 Subway plain, Depot not.
- added: dim/flicker/dead plain lamps keep indirect energy after set_flicker and flicker stays dynamic (fails if the indirect line were only on working lamps).
Result: 6 pass, 0.5 s. Raw output pipeline/out/qa/ul2.txt. Full suite not run (running elsewhere).
Not testable headless: the actual Ultra render (needs a display/GPU); owner to look at Subway on Ultra, incl. flicker lamps and the lift.
