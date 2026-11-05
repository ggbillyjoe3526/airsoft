Task: IN1 (none in TASKS.md) · QA commit 0d3a38e re-verified · Verdict: Pass

Blocking: none. Both earlier bugs are fixed and pinned by tests that now pass:
- Y while the order wheel or map is open is no longer latched (test_in1_qa.gd:107).
- The slide lock no longer replaces the Inspect clip while inspecting (test_in1_qa.gd:32).

Advisory: none open. The no-Fire-clip shot cut, the switch ease-back bleed and the press during the ease-back are fixed by the worker
(the last by dropping the press). Dry-firing an empty magazine does not end an inspect; this matches the brief.

Tests: test_in1_qa 7/7, test_in1_inspect 16/16, test_mc1 19/19, test_mc1_qa 16/16, test_ki2_qa 15/15 (slide lock). The worker edited
test_a_reload_after_a_cut_inspect_poses_the_reload_clip_to_its_end to wait out the ease-back before the second press;
that matches the new rule and still pins the Reload clip posing to its end.
Not run by me: tools/check.sh (running in the tree). Not testable here: how it looks and sounds in a real window (owner's list).

Agent: qa
