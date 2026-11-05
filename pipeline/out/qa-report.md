Task: IN1 (none in TASKS.md) · QA commit c896649 · Verdict: Fail

Blocking
1. Order wheel / map: Y pressed while the wheel or map is open is not consumed (_wheel_input and _map_input return false
   for it) and falls through to the latch, game/input/player_input.gd:243. The replica turns over behind the wheel and
   the press is not dropped. Fix: ignore the latch when _wheel.open or _map.open (or consume Inspect in both handlers).
2. Slide lock stomps the Inspect clip: game/play/replica_view.gd:316-320 (_pose_slide, `cycling` only knows the Fire
   clip). Trigger (a 0.05 s window): gas pistol, last BB fired, press Y while the Fire clip is still before slide_lock_after, so
   _start_inspect plays Inspect and _pose_slide then _seek()s SlideLock, replacing it. The pose and sounds run but the
   parts do not move. Same for a magazine emptied during an inspect by anything but a shot. Fix: skip the lock's seek
   (flag only) while inspecting(), or treat an inspect as cycling.

Advisory
- on_shot cuts the inspect only inside the has_animation(Fire) branch (replica_view.gd:140-143): a model with no Fire
  clip would keep inspecting through a shot. All shipped models have one; move _cut_inspect above the if.
- Switch: the old replica's turn/shift fade (inspect_cancel_time) is applied to the new replica for that time.
- Dry-firing an empty magazine (no SHOT event) does not end an inspect; matches the brief's list, noted.

Checked, no bug
- Saves: layout 1 and 2 without "inspect" get Y; a layout-1 throw_flash-on-Y is dropped by LAYOUT_1_MOVED so Y is free;
  Y held by another action leaves inspect keyless, no shared key (test_in1_inspect covers, test_mc1_qa edit is right).
- Selector stays at its mode through the Inspect clip (SelectorPose modifier) and the locked slide stays back through
  it (SlideLockPose hold).
- Reload after a cut inspect poses Reload and ends at its end; inspect again afterwards works; Fire clip plays after a
  cut. Bomb in hand (holstered) blocks and ends it. Spectating / out of play: take_inspect is consumed before the
  and-chain, so no press is kept for later. release() drops the latch.

Tests added: tests/unit/test_in1_qa.gd (7 tests)
- :32 last-shot slide lock keeps the Inspect clip · FAILS now (bug 2); passes once the lock skips while inspecting.
- :43 locked slide position unchanged through an inspect · passes; fails if the hold is removed.
- :54 selector bone unchanged through an inspect · passes; guards the modifier's hold.
- :68 reload after cut inspect, then re-inspect · passes; fails without the cut (clip would stay Inspect).
- :88 shot after cut plays Fire · passes. :97 bomb/holster ends it · passes.
- :107 Y with the wheel open is not latched · FAILS now (bug 1).
Suite: test_in1_qa 5 pass / 2 fail (the two bugs); test_in1_inspect 15 pass. Full check.sh not run by me (running in the
background). Not testable here: how the inspect looks and sounds in a real window (owner's list).

Agent: qa
