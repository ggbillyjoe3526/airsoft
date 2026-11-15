# AF1 · AEG ring all round, gaps between the handguard's rails, larger angled forward assist

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (AEG ring and rails thread) | ✓ | 6/8 Retry (QA Pass, performance Pass) | Measured, check 1: the photo's lower corners have shorter oval slots, not round holes (the round dots are the side rail's own holes); judgment: the bots' copy tore the side rail's teeth; check 8: PLAYTEST said the bots' rifle shows the same handguard |
| 2026-11-15 | 2 | Opus 5.5 (AEG ring and rails thread) | pending | pending | – |

## What changed

Owner, 2026-11-15, marking up the AEG Rifle's all-angles sheet (/mnt/project-files/art/replica-views/aeg-all-angles.jpg)
against an M4 quad-rail photo: "the green highlighted part of the model is the retention spring, it should go around
the full body. currently the top of it is covered by the rail. the red highlighted part should have gaps in between
the rails (not the rails themselves) ... the white highlighted part shows the bolt pusher. this is currently too
small and recessed. it should be slightly larger and stick out at more of an angle."

Only `tools/blender/replicas/aeg.py` and what it writes (`assets/models/replicas/aeg.glb`, `aeg_wear.png`) change; the
contract (empties, bones, clips, materials) and the parts files are untouched.

- **Delta ring:** the upper's top rail stops 0.3 mm short of the ring's back and the handguard's top rail starts at its
  front, so the ribbed ring shows all the way round, as on the photo (BL3's single rail over the ring is gone).
- **Handguard gaps:** the body is hollow (1.8 mm wall), its 45-degree corners wider (7.8 mm in, each flat face just
  wider than a rail's foot); a row of seven oval slots through each corner between two rails, 15 x 8.4 mm in the top
  corners and 12.8 x 7.2 mm in the lower ones (about 0.85 of the top's length, as on the photo), with the barrel and a
  new gas tube seen through them. The left rail's ribbed cover is now a rail's height, so the gaps show on the left as
  well. The body is bevelled before the cut and the slots' rims left sharp to keep within the budget.
- **Forward assist:** the housing's axis turns 18 degrees out toward the back, so its front sinks into the side and
  its back stands out; the plunger is a short neck and an 8 mm radius grooved head with a domed end standing 13.5 mm
  out of the housing (it was 7.5 mm, parallel to the side).
- **Bots' copy:** cut down to its 3,000 triangles, the slotted handguard frayed into spikes, so the copy is made from
  a solid stand-in of the handguard's outside (`GuardStandIn`, the old 4.5 mm corners). Attempt 1 still tore the side
  rail's teeth: cut down from the angled forward assist's full detail, the copy spent its triangles there (with the
  old forward assist the same build was clean). So the upper and forward assist are swapped too, for a copy with
  12-sided rings and a plain plunger (`UpperStandIn`, `ForwardAssistStandIn`); the real pieces join the body after
  the copy is made. The bots' handguard is solid, without gaps.

Triangles in the hands 37,864 -> 39,364 of 40,000 (98 %); the figure's copy 2,998 of 3,000. Optics, grips and the
torch still fit as before (studio pictures with the Variable Scope and grip, 2x Scope, Red Dot); the first-person hip
hold's right hand clears the forward assist. Model tests (37 scripts that load the AEG): 411/411 pass.

Pictures: /mnt/project-files/art/replica-views/aeg-ring-gaps-fa/ (before/after close-ups, after all-angles sheet).

## Decisions

- The lower corners' slots are shorter and narrower than the top ones, as on the photo; the side rail's own small
  mounting holes (the photo's round dots between its markings) are left out (budget: 636 triangles left).
- A gas tube inside the handguard: through the top slots the photo shows more than a bare barrel.
- The left rail cover narrowed to a rail's height: the owner asked for gaps between all rails, and a real ladder cover
  clips onto the rail only.
- Forward assist angle 18 degrees: enough to stand clear in the top view without reaching the stock or the hand.
- The bots' copy keeps a solid handguard: 28 slots in a 2,400-triangle copy fray, and at a bot's distance they don't
  read.
