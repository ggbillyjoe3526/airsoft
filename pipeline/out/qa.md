Task: BP6 menus · QA (read-only, no commit) · Verdict: Pass

Scope: git diff origin/main...HEAD (71 files) in worktree agent-a112c05c41620d0ad, plus the record draft.

Targeted tests: the 19 test files the diff touches or adds, run together headless.
Result: 351 of 351 tests passed, 6299 asserts, 201 s, no script or parse errors.
tools/check.sh (the full gate) was already running elsewhere and was not repeated.

Blocking findings: none.

Reviewed hunks, no bug found:
- run_record.gd and save_file.gd: save_closed tries the write, then the closed mark, then removes the record. load_file
  turns a RUNNING record with a mark beside it into CLOSED and removes the mark. SaveFile.touch respects hold, so a held
  path is refused. A missing file reads as closed.
- report_scrub.gd: cut() trims a split multi-word name at the end (spaces and tabs). common_names are skipped for names.
  IPV4 excludes "v1.2.3.4" and "(driver ". The WSL /mnt/c/Users path and the 48-character cap on a spaced folder are
  in USER_FOLDER. The IPv6 capital-then-small-letters guard keeps C++ names.
- key_bindings.gd: _keep_moved_keys runs before the essential-action check, so an essential action left keyless still
  resets to the defaults. keyless is cleared in reset().
- key_names.gd: the KEY_WORDS, NUM_MARKS and printing-ASCII branches run before the generic name lookup. The minus key
  is a word, so it cannot be mistaken for NO_KEY.
- hud_minimap.gd on_field: centres an axis where the field is narrower than the panel, and returns the input when the
  field size or scale is unknown. The arrow still uses the unclamped position.
- armory_dots.gd: keys past either end return without accepting the event, so focus moves on to the next control.
- replica_turntable.gd: the size_changed connection is guarded on enter and exit tree, so no duplicate connections.
  Interpolation is off. _size_port returns early when there is no model.
- hud.gd and play_session.gd: set_paused hides the crosshair and the team markers, and the skip pairs it true and false.
  The skip live label is turned off and cleared at the end. The intent labels are hidden under the wheel, the map and
  the scope.

Advisory (non-blocking, not in the record):
1. play_session.gd (skip start): HUD set_paused(true) is reused for the skip, so a skip also hides the team markers and
   the crosshair. This looks intended (the cover is up), but it depends on skip and the pause menu never overlapping.
   I did not exercise the skip-then-Esc path.
2. The record names "F3 follows a resize" and the "turntable 1080p to 4K" case. test_debug_view and
   test_replica_turntable cover these headless only. Layout on a real window, the on-screen position of the F3 panel,
   and the look of the ribbons and the Customise 3/4 view need a display.

Not tested here (owner's list, needs a display or real window):
- F3 panel seat and F4 ribbons and labels in play, depth-tested label stacking.
- Customise turntable zoom in windowed, borderless and fullscreen modes, and after a resize.
- Minimap clamp at the field edge in play, and "Ranger green" fitting at its 10 px floor.
- Focus ring on the Armory dots with a controller, and a real screen reader reading the new names.
- Key-mark text on a non-US keyboard layout (keyboard_get_keycode_from_physical returns nothing under headless).

Record cross-check: the claims in the record about tests (test_run_record, test_report_scrub 6 new, test_mc1_qa,
test_debug_view, test_replica_turntable, test_bp6_menus) match files in the diff, and all of them pass.
