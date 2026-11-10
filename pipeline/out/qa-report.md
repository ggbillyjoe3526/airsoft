Task: UG3 · QA commit (see git log) · Verdict: Pass  (head under test 9b71816)

Blocking: none. Advisory: none found.
- Old saves / Custom rows: a save without the row takes the base preset's column; a bad value is dropped alone; override round trip works.
- Compatibility drawable() greys the row to off, Mobile and Forward+ keep it; renderer switch clears and restores the eyes.
- Freed field: no orphan growth over 5 build/toggle/free cycles; the eyes resource is reused, not rebuilt.
- Map without a lighting override uses the day preset's eye_lift; zero/huge lift and drop stay finite and min <= max.
- en.po label and note resolve. Glass camera gets its own plain attributes (optic_glass.gd:88); not render-checkable headless.

Tests added: tests/unit/test_ug3_qa.gd (9, all pass, 0.56 s). Each fails without the feature (EYE_ADAPTATION row, eye_adaptation field, set_eye_adaptation and the en.po keys do not exist; they error or assert false).
Targeted run (ug3_qa, eye_adaptation, graphics_table, graphics_apply, settings_screen, bp6/bp7_graphics, graphics_pick): 123 pass, 0 fail, 121 s.
Not tested (needs display): the Settings page layout at small window sizes with the extra Effects row, actual exposure look, scope glass pixels. tools/check.sh and smoke not run (as asked).
