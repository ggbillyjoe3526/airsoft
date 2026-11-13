"""The first-person arms' holds as data (HA1): where each replica sits, where each hand's marks lie on it, and the
costs and limits the solver (`hold_solve.py`) weighs. `arms.py` builds the model from them.

GUARD, SNIPER_GUARD, SMG_GUARD and SHOTGUN_PUMP are the left hand's holds on a rifle with no foregrip; VERTICAL_LEFT
and ANGLED_LEFT its fist round a foregrip; SUPPORT its wrap over the right hand on a pistol; RIGHT and the tables made
from it the right hand's on each replica's grip. HOLDS lists every replica's. A hold's values can be tried from the
environment without editing this file (`tuned`: BL_G_<KEY>, BL_S_<KEY>, BL_F_<KEY>).
"""

import math
import os
import sys

import bpy  # noqa: F401  first: it brings mathutils with it
from mathutils import Matrix, Vector

import magazine
import preview
from pose import Rig

# The repository (the script's last argument, else where it is run from) and the replicas' models in it.

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
REPLICAS = os.path.join(ROOT, "assets/models/replicas")
PARTS = os.path.join(ROOT, "assets/models/replicaParts")

# The shoulders, bladed as a right-handed shooter stands: the left one forward, the right one back (eye space: +X
# right, +Y forward, +Z up).
SHOULDER = {"L": Vector((-0.140, 0.100, -0.215)), "R": Vector((0.170, -0.120, -0.215))}
# How far below its shoulder each elbow hangs at least (m): tucked, not winged out.
ELBOW_DROP = {"R": 0.10, "L": 0.06}
# How far each elbow may come in across the body from its shoulder (m): the right not at all, the left a little
# (reaching across to a pistol).
ACROSS = {"R": 0.0, "L": 0.10}
# Per degree a forearm lies off its hold's `plan` angle (seen from above), as costly as this many degrees of wrist.
PLAN_COST = 1.0
# A pistol hand's palm faces the grip's right side at least this much (cosine), and each metre a placement passes into
# the grip, to be pushed back out of it, costs this many degrees of wrist bend while it is rolled into place.
PALM_FACING = 0.5
ROLL_STEP = 6
# A pistol's support hand (`support_pose`): the step of its turn about the upright line (degrees), and every which
# of the palm's sampled points measures how close it lies.
YAW_STEP = 5
PALM_SPARSE = 4
# How much further from the trigger (m) the trigger finger's second search may leave its pad and still be kept.
TRIGGER_SLACK = 0.001
# The points across and down the grip's bare side that a pistol's support hand is measured from (`support_pose`).
BARE_GRID = (4, 2)
# The AEG's handguard: its centre line (x, z in the rifle's space) and radius (m), measured from the model; a support
# hand's finger knuckles want to sit between CUP_GAP of its surface (their joints' centres, a finger's half thickness
# out) to wrap it; the search's step (degrees), and what each degree off the forearm's rise and each metre of loose
# knuckle cost against a degree of wrist bend.
GUARD_AXIS = (0.0015, 0.047)
GUARD_RADIUS = 0.025
CUP_GAP = (0.010, 0.015)
CUP_STEP = 10
RISE_COST = 1.0
LOOSE_COST = 500.0
# A hold's spec may cap the wrist (`bend_most`, degrees): each degree past it costs this many (BP8: the angled grip's).
BEND_COST = 50.0
# The best CUP_TRIES turns try their fingers, which should come to rest round it curled WRAP degrees at their roots;
# each degree outside that costs WRAP_COST.
CUP_TRIES = 16
WRAP = (25.0, 80.0)
WRAP_COST = 0.5
OVER_COST = 4.0
# How far the support forearm's axis keeps from the replica (its sleeve's radius, m) and the cost per mm closer.
FOREARM_CLEAR = float(os.environ.get("BL_FOREARM_CLEAR", "0.045"))
CLEAR_COST = 20.0
# How far a resting finger's last joint bends for each degree of its middle one (relaxed fingers curl together).
TIP_COUPLE = 0.7
# The most a resting finger's knuckle and middle joint bend reaching its mark on a handguard, unless its spec says
# (`tip_most`).
TIP_MOST = (90.0, 100.0)
# Round a grip with a `thumb_at` mark (the pistols', and the rifle's: the owner, 2026-11-05, its thumb round the
# grip) the thumb turns further at its root (degrees): across the back strap to the grip's far side, twisted so its
# tip joint bends in toward it (the web's weights are smoothed for this, glove.smooth_web); that tip joint may bend up
# to THUMB_TIP (a support hand's thumb up to 45).
THUMB_WIDE = 60
THUMB_TWISTS = tuple(range(-135, 61, 15))
THUMB_TIP = 60
# The knuckle bends a grip's thumb tries with each turn at its root, so it can come round the back strap's corner and
# lie along the grip's side (degrees).
THUMB_BENDS = (0, 20, 40, 60)
MOVE_COST = 1000.0
# With a mark for the little finger's knuckle: its cost per metre off that mark (against degrees of bend), unless the
# hold gives its own (`pinky_cost`).
PINKY_COST = 600.0


def godot_to_eye(x: float, y: float, z: float) -> Vector:
    """A point in the camera's space as the game writes it (x right, y up, -z forward) in the eye space here."""
    return Vector((x, -z, y))


class Grip:
    """A pistol grip in its replica's space: the top of its back strap (where the hand's web sits), its rake back
    from upright (degrees), its depth back to front and its half width."""

    def __init__(self, top: tuple, rake: float, depth: float, half_width: float):
        self.top = Vector(top)
        r = math.radians(rake)
        self.down = Vector((0.0, -math.sin(r), -math.cos(r)))
        self.fwd = Vector((0.0, math.cos(r), -math.sin(r)))
        self.depth = depth
        self.hw = half_width

    def at(self, d: float, f: float, x: float) -> Vector:
        """The point `d` down the back strap from its top, `f` forward of it and `x` to the right."""
        return self.top + self.down * d + self.fwd * f + Vector((x, 0.0, 0.0))


class Hold:
    """How one replica is held: where it sits (its origin in eye space), its grip, the right hand's knuckles on it
    (down the grip, forward of the back strap) and the palm's roll, and the left hand's kind and place; `tip` turns
    it in the hand about its origin (eye space; a bomb, as GrenadeView tips it)."""

    def __init__(self, file: str, at: Vector, grip: Grip, right: dict, left: dict, tip: Matrix = None):
        self.file, self.at, self.grip, self.right, self.left = file, at, grip, right, left
        self.tip = tip if tip is not None else Matrix.Identity(3)

    def to_eye(self) -> Matrix:
        """The replica's own space (its model's) into eye space."""
        return Matrix.Translation(self.at) @ self.tip.to_4x4()


# The right hand on every grip (metres, degrees): its index finger's knuckle `d` down the back strap from its top,
# `f` forward of it and `x` out from the grip's side (the knuckle's joint, inside the hand); the knuckles' line slanted
# `slant` forward from the grip's line (the grip lies across the palm on a diagonal, which keeps the wrist straight);
# the palm facing the grip's side, turned `wrap` toward its front (negative: round its back).
RIGHT = {"d": 0.006, "f": 0.038, "x": 0.012, "slant": 30.0, "wrap": -30.0, "thumb_d": 0.030, "thumb_f": 0.030,
         "thumb_hug": 0.0, "thumb_pull": 3.0, "thumb_aim": 1.0, "swing": (0.0, 0.0, 0.0),
         "fingers": {"Middle": (60, 60, 45), "Ring": (60, 60, 45), "Pinky": (55, 55, 40)},
         "thumb": ((-45.0, 0.0, 30.0), (35.0, 25.0))}
# The left hand under a rifle's handguard (the owner's photos 123627, 123646, 123656): `y` along it (rifle +Y), its
# palm centre placed with the handguard's centre line `forward` toward the fingers (far enough that the fingers rest on
# its right side rather than reaching over its top: the owner, 2026-11-05; the hand a little further right, its
# wrist less turned in: 19:41) and `depth` out of the palm, seated
# on it and held `standoff` off; its turn found by `cup` over `search` ((yaw), (pitch), (roll) ranges, degrees: the
# fingers' line yawed from forward toward the right and pitched up, the palm rolled either way from facing up). The
# owner (2026-11-06): the hand holds under the rifle, the thumb slightly forward and almost relaxed, and the forearm
# meets the rifle at an angle seen from above (`plan`), not square across it. HA1 (the owner, 2026-11-12: "the
# forearm/wrist for the rifle hold is bent in an unnatural way. The arm and wrist should be straight", and "try angle
# the left arm/hand on the rifle close to the replica"): the forearm lies on the hand's own line, the wrist straight
# (`upper`: the shoulder goes the upper arm's length from the straight-wrist elbow, along that eye-space line from
# elbow to shoulder; the view never shows the shoulder, `shoulder_behind`), and the hand sits 5 cm further forward on
# the handguard (`y`), turned 25 degrees off the bore, pitched 15 and rolled -10: from there the forearm runs up
# beside the rifle 30 degrees off the bore, was 40 with the wrist bent 50, and its sleeve still passes the magazine
# (`cup` keeps it FOREARM_CLEAR off the replica; with the hand where it was, nothing under 45 degrees cleared it).
# The fingers run diagonally forward up the right side, their tips below the rail (aimed at `tip_at`), the palm under
# the handguard. Without `upper` the arm comes from `shoulder` (eye space), the forearm rising toward `rise` degrees,
# the elbow at least `drop` below the shoulder and at most `across` in toward the body. The thumb lies forward along
# the handguard's left side, pressed onto its side face a little above the centre line, toward (thumb_x, y + thumb_f, thumb_z)
# (`thumb_pull`, held lightly: `thumb_hug`; it closes at most `thumb_curl` degrees); the palm only 26 mm (`forward`)
# to the right of the handguard's centre line, so the thumb's base sits under its left side and the whole thumb
# presses on it (the owner, 2026-11-06: "the hand gripping it", not the rifle "just sitting in the hand"). No
# finger's glove rises above `tips_below` (replica space; the rail's top is 0.0735): the fingers rest on the right side
# and none stands over the top from the left (the owner's 16:30 note, the critic). HA1 (the owner, 2026-11-12, of the
# view from the eye: "You can still see the players fingers on the right side of the AEG. They should not be visible:
# only the thumb of the left hand"): the hand is pitched up 15 degrees, was 40, and the fingertips aim low on the right
# side (`tip_at`, `tips_below` 2 cm under the rail's top), so the fingers close under the handguard and neither they
# nor their middle joints stand above its top edge as the eye sees it, at the hip or aimed. His fourth look, of the
# thumb reaching 55 mm forward along the handguard's lower left edge, its tip past the handguard's front: "The thumb
# should be resting against the replica": it lies 35 mm forward and 5 mm higher, up on the side face, held closer
# along its length (`thumb_hug` 4, was 2). His fifth look (2026-11-13 00:26): "With no grip Move the left hand back
# and closer to the magazine on the rifles. If you need to move more of the forearm out of view that's ok": the hand
# sits 4 cm further back (`y` 0.200, its cuff at the magazine well's front), turned 30 degrees off the bore, the
# least that passes the sleeve by the magazine from there (at 25 the forearm passes into it), the elbow hung 12
# degrees under the wrist's straight line (`sag`, as a hand carrying a rifle's weight has it), which drops the
# forearm lower in the view; and each fingertip aims 3 cm ahead of its knuckle, low on the right side (`tip_at`),
# never above `tips_below` (`Hand.onto` holds them under it): turned further across, fingers aimed level with their
# knuckles hooked up past the handguard's far side, where the eye saw their tips. The critic, from the far side
# (2026-11-13): the ring and little fingers reached that mark knotted, their knuckles straight and their middle joints
# shut to 100 degrees. So a knuckle may bend back a little (`tip_back`, degrees) and a middle joint closes no further
# than `tip_most`'s second figure (TIP_MOST where a hold gives none): the fingers lie open along the handguard's
# underside, each joint well under a right angle, their tips still under `tips_below`.
GUARD = {"kind": "guard", "y": 0.200, "forward": 0.026, "depth": 0.034, "standoff": 0.0,
         "search": ((30, 30), (15, 15), (-10, -10)), "rise": 8.0, "shoulder": (-0.06, 0.04, -0.06), "drop": 0.06,
         "across": 0.25, "thumb_x": -0.030, "thumb_f": 0.035, "thumb_z": 0.060, "thumb_hug": 4.0,
         "thumb_pull": 30.0, "thumb_wide": 0.0, "tips_below": 0.050, "plan": 30.0,
         "upper": (-0.5, -0.8, 0.4), "sag": 12.0, "tip_at": (0.0275, 0.030, 0.030), "tip_swing": 8.0,
         "tip_back": 15.0, "tip_most": (90.0, 45.0),
         "fingers": {"Index": (35, 35, 20), "Middle": (40, 45, 30), "Ring": (40, 45, 30), "Pinky": (35, 40, 25)},
         "thumb": ((20.0, 0.0, 10.0), (10.0, 10.0))}
# A pistol is held in the right hand alone, as the game's look draws it: the left arm hangs at the side, out of view
# (the game doesn't draw it), its hand's knuckles this far from its shoulder (eye space) and loosely curled.
DOWN = {"kind": "down", "at": (0.0, 0.06, -0.40),
        "fingers": {"Index": (20, 25, 15), "Middle": (25, 30, 20), "Ring": (30, 35, 20), "Pinky": (35, 40, 25)},
        "thumb": ((0.0, 0.0, 10.0), (10.0, 10.0))}
# The right hand high on a pistol's grip (the owner's photos, one-handed: 123843, 123830, 123816), in the replica's own
# space (x right, y forward, z up): the thumb's root joint (deep in the heel of the thumb) behind the back strap, the
# index finger's knuckle on the grip's right side under the trigger guard and the little finger's knuckle near the
# front strap low down (`pinky`: the hand turned to lay all three nearest their marks, then rolled about the first two
# to keep the wrist straightest and the little finger's knuckle near its mark); so the web of the hand wraps the back
# strap under the beavertail, the fingers close up under the trigger guard (swung `swing` toward the index) with the
# little finger on the grip too, and the thumb comes round the back strap's corner and lies forward along the frame's
# left side (its tip toward `thumb_at`, drawn there by `thumb_pull`, held lightly to the frame by `thumb_hug`; its
# knuckle and tip close onto the frame at most `thumb_curl` degrees). On the GBB the thumb is drawn forward and up
# toward the raised catch behind the trigger guard (the owner, 2026-11-06: "more forward and resting on the pistol
# ... a slight bump where the thumb should go"), each pose checked on the skinned glove (`thumb_verify`): from the
# web behind the back strap's right corner, a thumb reaching further forward than the grip's top swell cuts into
# the frame's top rear corner at its root, so it lies along the frame there, 5 mm higher than the Cyber's and
# touching all along; the web 3 mm further back and 1 mm lower than the Cyber's, which sets it there and keeps the
# fingers closed round the grip. The arm comes up to it from below (the owner, 2026-11-06, with Valorant's pistols as
# the look: only the hand and a little of the wrist on screen, never the forearm, the wrist bent little): the hold
# sits nearer the middle and higher at the hip (ViewModelConfig.hip, matched in HOLDS), the forearm rising about 13
# degrees to it (wrist about 16 degrees), so at the hip the wrist meets the screen's bottom edge and aimed the forearm
# drops out of view under the hand; its shoulder moved `shoulder` (eye space), its elbow at least `drop` below it.
# The hand sits 3 mm lower than the owner approved at 09:41 (his note, 15:39: the trigger finger "looks broken" from
# behind, bowed up at its knuckle): from there the finger lies nearly straight to the trigger, its base never bent back
# (`index_from`), its bends limited (`index_bends`). HA1 (the owner, 2026-11-12: "the right hand index finger ... looks
# unnatural", of that straight finger): it curls onto the trigger as a finger does, bent most at its middle joint
# (`index_arc`), its tip passing through the guard past the trigger's far side (`index_left`, m past the trigger's
# middle), where the pad, not the tip, then lies on the trigger.
PISTOL_RIGHT = dict(RIGHT, web=(0.014, -0.100, -0.051), index=(0.018, -0.042, -0.043), pinky=(0.018, -0.058, -0.101),
                    thumb_at=(-0.024, -0.035, -0.032), thumb_hug=2.0, thumb_pull=80.0, thumb_curl=(40.0, 60.0),
                    thumb_verify=1.0,
                    shoulder=(-0.07, -0.15, 0.085), drop=0.04, swing=(-15.0, -15.0, -15.0),
                    rolls=(-6.0, -6.0), thumb_turn=(-20.0, 40.0, -100.0, 0.0), index_left=0.022,
                    index_bends=(70.0, 75.0, 35.0), index_from=0.0, index_arc=(40.0, 0.0005))
# The Cyber Pistol takes the GBB's hold (HA1; the owner, 2026-11-12: "Cyber pistol should have same grip as gbb
# pistol", and of its thumb, which lay flat across the back: "it should stick out like the thumb in the gbb shot"):
# its grip was reshaped to the GBB's sections (MQ1B), so the same marks seat the same hand, 7 mm higher: its trigger
# hangs that much higher over the grip, and from the GBB's height the finger lay under the guard, 18 mm short of it.
# The finger's bends are left free to find it (the GBB's limits hold it out of this taller guard), and so is the
# thumb's turn in the one-handed hold (`thumb_turn`): the Cyber's frame keeps its full width ahead of the grip where
# the GBB's narrows to the trigger guard, so at the GBB's turn the thumb closed into the frame and was eased 20
# degrees out into the air. Its own marks (CZ1) and the thumb pinned under the old slab's raised edge are gone with
# that slab.
CYBER_LIFT = 0.007
CYBER_RIGHT = dict(PISTOL_RIGHT, index_left=None, index_bends=None, index_from=None, thumb_turn=None,
                   **{k: (PISTOL_RIGHT[k][0], PISTOL_RIGHT[k][1], PISTOL_RIGHT[k][2] + CYBER_LIFT)
                      for k in ("web", "index", "pinky", "thumb_at")})
# The AEG Rifle's grip: the same three marks, the hand high on the short grip with the little finger wholly on it, its
# knuckle above the grip's flared foot (the owner, 2026-11-05; the critic: half of it hung below), the knuckles' line
# raked back with the grip, the web closer in over the back strap so the thumb reaches round onto the grip's left
# side, high at its top under the receiver (`thumb_at`, drawn there hard: the owner, 2026-11-06, the thumb too
# low); the shoulder drawn in, back and a
# little down to keep the wrist straighter (about 22 degrees).
AEG_RIGHT = dict(RIGHT, web=(0.042, -0.103, -0.056), index=(0.030, -0.031, -0.036), pinky=(0.024, -0.068, -0.078),
                 pinky_cost=2000.0, swing=(-10.0, -10.0, -10.0), shoulder=(-0.04, -0.08, -0.02),
                 thumb_at=(-0.022, -0.050, -0.026), thumb_hug=2.0, thumb_pull=30.0, rolls=(0.0, 0.0),
                 thumb_turn=(-60.0, 60.0, -80.0, 20.0), index_turn=(-18.0, -13.0, 33.0, 60.0))
# The pistols' and the AEG's right hands are held as the owner approved them (2026-11-06 04:28: the AEG "about as good
# as it's going to get", the Cyber "good"; 09:41 the GBB): their roll on the grip (`rolls`) and their thumb's turn
# (`thumb_turn`) are fixed where the solve found them then, as `Collider.inside` now reads the replica's corners truly; the
# AEG's trigger finger too (`index_turn`: its swing and three bends).
# The Sniper Rifle (a chassis rifle): the right hand round its stock's wrist, raked about 54 degrees, the marks set by
# its front strap (the index knuckle at its top, level with the trigger guard's back, the little finger's knuckle
# 5.5 cm down and back along it, the thumb's root behind and right as on the AEG's grip) and the thumb over the
# wrist's top onto its left side (the owner's photo 2, 2026-11-06); the shoulder higher than the AEG's (the
# raked wrist otherwise bends the hand's wrist past 30 degrees). HA1: its thumb's turn is fixed where the solve found
# it on the hand before its proportions changed (`thumb_turn`): searched afresh on the new hand it lay 2 mm less far
# round the wrist, and a bot's thumb fell short of the grip's left side (tests/unit/test_hands_on_replica.gd).
SNIPER_RIGHT = dict(AEG_RIGHT, web=(0.042, -0.100, -0.035), index=(0.030, -0.030, -0.016),
                    pinky=(0.024, -0.085, -0.058), thumb_at=(-0.028, -0.060, 0.0), shoulder=(-0.04, -0.08, 0.03),
                    rolls=(-180.0, 174.0), thumb_turn=(-10.0, -10.0, 20.0, 40.0), index_turn=None,
                    press=("Ring", "Pinky"))
# Its left hand as the AEG's, under the fore-end (narrower and lower than the AEG's handguard: `axis`, `radius`,
# its top at 0.056) near its back, as far forward as the arm reaches, its turn searched (the fore-end is lower); the
# owner, 2026-11-06: the ring and little fingers "pressed against the rifle", the thumb pressing on it. So the palm
# sits further right than on the AEG (`forward`; the narrow fore-end leaves the knuckles 14-21 mm off its right side),
# the fingertips reach higher up that side (`tip_at`), the little finger's lower (`tip_drop`, m below the others',
# curled in under the fore-end rather than clawed out from it), and the thumb presses on the left side face just
# above its centre line. The fifth look: 28 mm further back, just ahead of the magazine's housing (the magazine's
# front at y 0.171); any further and the housing holds the palm 1 cm off the fore-end. Under so narrow a fore-end a
# middle joint closes no further than 25 degrees (`tip_most`): at the AEG's 45 the little finger still looped.
SNIPER_GUARD = dict(GUARD, y=0.232, axis=(0.0, 0.030), radius=0.025, tips_below=0.036,
                    tip_at=(0.0255, 0.030, 0.022), thumb_x=-0.028, thumb_z=0.045, forward=0.034,
                    tip_drop={"Pinky": 0.015}, tip_most=(90.0, 25.0))
# The Compact SMG (CS1): its grip raked 30 degrees as the AEG's and its front where the AEG's is at the hand's height
# (smg.py), but 12 mm deeper, so the web and the little finger's knuckle sit that much further back and the thumb
# reaches round onto the grip's left side a little further back; its roll, thumb and trigger finger searched.
SMG_RIGHT = dict(AEG_RIGHT, web=(0.042, -0.113, -0.056), pinky=(0.024, -0.074, -0.078),
                 thumb_at=(-0.022, -0.058, -0.026), rolls=None, thumb_turn=None, index_turn=None)
# Its left hand under the slim handguard behind its side rails, as the AEG's (the handguard's centre line higher, its
# top under the cocking tube at 0.096, so the fingertips stay under the tube and the right rail starts 2 cm ahead).
# HA1: the handguard is short (it narrows from y 0.26 and ends at 0.27) and the magazine stands 6 cm behind the
# hand, so the hand sits further back than the AEG's with the arm 37 degrees off the bore (`search`: nearer the
# bore the forearm passes into the magazine, further forward a fingertip shows past the handguard's front), and the
# elbow hangs under the wrist's straight line (`sag`), which keeps the upper arm out of the view. The fifth look:
# 7 mm further back, the cuff against the magazine's housing (any further and the arm turns 46 degrees and more off
# the bore to pass it, across the view).
SMG_GUARD = dict(GUARD, y=0.205, axis=(0.0, 0.072), radius=0.022, tips_below=0.074,
                 tip_at=(0.0275, 0.030, 0.056), thumb_x=-0.028, thumb_z=0.080)
# The Pump Shotgun (SH2): its pistol grip is the AEG Rifle's own, in the AEG's place (shotgun.py builds it from
# aeg.grip()), so the right hand holds it as the AEG's; its trigger sits in its own guard, so the trigger finger is
# searched, and rests low on the blade (`trigger_at`): the blade's upper half is up inside the receiver's foot, and a
# finger sent to its middle stuck out 40 degrees from the others on a bot's hand (the critic, SH2). HA1: on the
# re-proportioned hand the search reached the blade with a straighter finger (its three bends 87 degrees together,
# 112 before), so the finger is asked to arch as it did (`index_arc`: 45 degrees at its middle joint and a fifth more
# at its tip, where the pad still finds the blade). The left hand holds the pump (a ribbed tube of 20 mm radius under the barrel, its centre line 30 mm over
# the origin, from 0.279 to 0.449 ahead of it) at its back end, 13 cm further forward than the AEG's handguard hold. So
# the replica is held 5 cm nearer you and 2 cm lower than the other rifles (its own hip place, the same in
# ViewModelConfig.hip): from the rifles' place the arm reached out to the pump with the shoulder pushed forward and
# 11 cm of forearm on screen, where the house rule is the glove and the cuff only (the critic, SH2); from here it shows
# 5 cm, as the Sniper Rifle's, and the wrist bends 8 degrees. The fingers go up the pump's right side, their tips
# under the barrel (its underside at 0.057), the thumb along its left side. cycle.work_pump slides the hand back 62 mm
# and home with the pump after each shot, the build failing if the wrist bends past cycle.PUMP_WRIST.
SHOTGUN_RIGHT = dict(AEG_RIGHT, web=(0.042, -0.093, -0.038), index=(0.030, -0.026, -0.018),
                     pinky=(0.024, -0.060, -0.060), thumb_at=(-0.026, -0.044, -0.008), thumb_turn=None,
                     index_turn=None, trigger_at=0.82, index_arc=(45.0, 0.0002, 1.2))
SHOTGUN_PUMP = dict(GUARD, y=0.325, axis=(0.0, 0.030), radius=0.0203, tips_below=0.054,
                    tip_at=(0.0228, 0.005, 0.038), thumb_x=-0.024, thumb_z=0.038, thumb_f=0.050,
                    tip_back=0.0, tip_most=TIP_MOST,
                    search=((40, 80), (20, 50), (-40, 0)))
# A foregrip fitted under the handguard (BP8, the owner's playtest note 6: "If a weapon has a grip attachment the
# players left hand should hold it"): the left hand wraps the grip as the right hand wraps a pistol's, mirrored: its
# palm on the grip's left side, the thumb's root (`web`) behind its back face, the index finger's knuckle high under
# the rail by its front face and the little finger's knuckle below it (`pinky`; on these short grips the little
# finger curls in under the grip's foot), the fingers closed round the front onto the right side, and the thumb round
# the back over them, forward along the right side toward `thumb_at`. The marks are in the grip part's own space
# (x right, y forward, z up, its origin on the replica's GripMount: tools/blender/parts/attachments.py), so one spec
# serves every replica that takes the grip; the shoulder comes forward with the hand (`shoulder`, `drop` as the
# guard's) while the hand is laid, then goes where the wrist is straight (`upper`, as the guard's: HA1). A fist
# round an upright grip with a straight wrist has its forearm level and along the bore, through the magazine, so the
# whole hand is turned about the grip's middle (`turn`, degrees): tilted 30, as a hand holds a hammer, so the forearm
# rises to it, and swung 35 so the forearm comes from the left, 22 degrees off the bore. Without a grip the
# handguard hold stays as it is.
# The owner's fourth look (2026-11-12 22:37), of that fist tilted 30 with the index finger's knuckle 18 mm under the
# rail, where the finger could not close under the handguard and lay open up its side: "With a vertical or angled
# grip the hand is very bad. With a vertical grip the index finger should be under the replica and around the grip.
# Angled grip should be held similar to the vertical grip". So the fist sits lower and further out (the index
# knuckle about 30 mm under the rail and 12 mm off the grip's side, a finger's thickness, so the finger has room to
# turn round its front), tilted 20 not 30 (the finger's sweep rises less toward the rail), and the index and middle
# fingers close until they touch (`press`).
# His fifth look (2026-11-13 00:26): "Move the hand up the vertical grip a bit more so more fingers grip it" (the
# fist 10 mm higher, tilted 8 degrees); his sixth (04:22): "The previous version was better, so go back to that but
# the hand should be further up the grip (with fingers wrapped around the grip and the thumb resting on the near
# side)" (the fourth look's fist 10 mm higher, the thumb forward along the grip's left side); his seventh (05:28), on
# that one's pictures: "That is still bad. Go back to the previous one". So the vertical grip's hold is the fourth
# look's exactly, and stays there: neither a higher fist nor a thumb on the near side was better.
GRIP_LEFT = {"kind": "grip", "pinky_cost": 300.0, "thumb_hug": 2.0, "thumb_pull": 30.0, "thumb_curl": (40.0, 45.0),
             "swing": (8.0, 8.0, 8.0), "shoulder": (-0.06, 0.04, -0.06), "drop": 0.06, "across": 0.25,
             "upper": (-0.5, -0.8, 0.4), "turn": (20.0, 35.0), "sag": 0.0, "press": ("Index", "Middle"),
             "fingers": {"Index": (60, 60, 40), "Middle": (60, 60, 45), "Ring": (60, 60, 45), "Pinky": (55, 55, 40)},
             "thumb": ((20.0, 0.0, 10.0), (10.0, 10.0))}
# The vertical grip (its body 29 mm fore and aft, 24 mm across, 16 to 64 mm under the rail's face below its flared
# top; MQ2 made it 64 mm from 53): the index and middle fingers round it, the ring finger at its foot. `pivot` is
# the middle of the grip where the hand holds it (the grip part's space), which `turn` turns the hand about.
VERTICAL_LEFT = dict(GRIP_LEFT, web=(-0.018, -0.027, -0.042), index=(-0.024, 0.012, -0.033),
                     pinky=(-0.024, 0.006, -0.090), thumb_at=(0.014, -0.012, -0.032), pivot=(0.0, 0.0, -0.045))
# The angled handstop (its tall end in front, 26 mm fore and aft, 21 mm across, down to 48 mm under the rail; the
# swept face behind it): held as the vertical grip is (the owner, above), the fist round its tall end, the web of
# the thumb behind it under the swept face and the thumb round its back.
# Its raked front and the rail plate over it leave the index finger less room than the vertical grip's flared top:
# tilted 20 the finger caught the plate and lay open, so this fist is tilted 12 (the forearm rises 12 degrees to it).
ANGLED_LEFT = dict(GRIP_LEFT, web=(-0.0165, -0.009, -0.039), index=(-0.0245, 0.032, -0.030),
                   pinky=(-0.0245, 0.026, -0.087), thumb_at=(0.012, 0.004, -0.036), pivot=(0.0, 0.018, -0.039),
                   turn=(12.0, 35.0))
GRIP_HOLDS = {"grip_vertical": VERTICAL_LEFT, "grip_angled": ANGLED_LEFT}
# The Sniper Rifle's grip sits further forward than its fore-end hold (GripMount 6 cm ahead of the hand): the
# shoulder comes further forward to reach it.
GRIP_SHOULDER = {"sniper": (-0.06, 0.10, -0.06)}
# A smoke or flash bomb in the right hand alone (GT1), as a fist holds a pistol's grip: its lever under the palm on its
# right side (the model's +X), the web of the hand round its back, the fingers closed round its front onto its left
# side and the thumb along that side; the left arm down (the game hides it: ViewModelConfig.one_hand). The marks
# are in the bomb's own space (Blender's: z up its length, origin at its middle), scaled to each body's radius
# (smoke 27.5 mm, flash 20 mm). Each bomb sits where GrenadeView draws it in hand (HELD_AT, HELD_TIP: the same
# numbers in the game's camera space, x right, y up, -z forward), so its top leans in toward the screen's middle and
# back toward the eye.
HELD_AT = godot_to_eye(0.12, -0.12, -0.32)
HELD_TIP = (Matrix.Rotation(-0.45, 3, Vector((0.0, 1.0, 0.0))) @ Matrix.Rotation(0.35, 3, Vector((1.0, 0.0, 0.0))))
BOMB_FINGERS = {"Index": (60, 60, 45), "Middle": (60, 60, 45), "Ring": (60, 60, 45), "Pinky": (55, 55, 40)}
SMOKE_RIGHT = dict(PISTOL_RIGHT, rolls=None, thumb_turn=None, index_left=None, index_bends=None, index_from=None,
                   index_arc=None,
                   web=(0.016, -0.042, 0.010), index=(0.030, 0.016, 0.022),
                   pinky=(0.028, 0.012, -0.036), thumb_at=(-0.014, -0.030, 0.024), thumb_verify=0.0,
                   fingers=BOMB_FINGERS, swing=(0.0, 0.0, 0.0), shoulder=(-0.02, -0.06, 0.10), drop=0.03)
FLASH_RIGHT = dict(SMOKE_RIGHT, web=(0.012, -0.033, 0.004), index=(0.023, 0.012, 0.016),
                   pinky=(0.021, 0.009, -0.040), thumb_at=(-0.010, -0.022, 0.018))
# A pistol held in both hands (HA1; the owner, 2026-11-12, with his reference shots: "the player should hold the pistol
# with two hands"): the right hand as approved, and the left wrapped round it, thumbs forward. Its marks are the
# pistol's own space, as the right hand's: the thumb's root (`web`) low behind the grip's left side, under the right
# thumb; the index finger's knuckle (`index`) at the grip's front left corner under the trigger guard and the little
# finger's (`pinky`) down the front strap's rake from it, so the fingers close round the front over the right hand's
# and the heel of the hand fills the left side of the grip the right hand leaves bare; the thumb forward along the
# frame's left side under the slide, ahead of the right thumb (`thumb_at`). It is solved against the pistol and the
# right arm as posed, and rests on both without passing into either. The bots keep the one-handed hold (`<id>_Hold`,
# which FigureArmsHold reads); this one is keyed as `<id>_two_Hold`, which ArmsView takes when the model has it.
# Its turn is searched (`support_pose`) between the rolls and yaws that leave its thumb a clear place flat on the
# frame: rolled under 4 degrees the palm lies a little closer on the grip's bare side (`bare`: the part of that side
# behind the right hand's fingertips, down to where the eye over the sights still sees it), but the thumb then
# stands off the frame in an arch and the gap the owner saw between hand and grip opens under it.
SUPPORT_LEFT = {"kind": "support", "web": (-0.030, -0.088, -0.068), "index": (-0.043, -0.020, -0.064),
                "pinky": (-0.043, -0.035, -0.130), "thumb_at": (-0.024, 0.0, -0.040), "pinky_cost": 300.0,
                "thumb_hug": 2.0, "thumb_pull": 80.0, "thumb_curl": (40.0, 45.0), "swing": (0.0, 0.0, 0.0),
                "shoulder": (0.04, -0.30, 0.095), "drop": 0.06, "across": 0.10, "rolls": (4.0, 16.0),
                "yaws": (10.0, 25.0), "gap_cost": 1000.0, "bare_cost": 6000.0, "bend_cost": 0.5,
                "bare": ((-0.088, -0.056), (-0.080, -0.050)), "side": -0.015,
                "right_thumb": (0.5, 0.004),
                "right_thumb_curl": (40.0, 60.0), "right_thumb_hug": 2.0, "right_thumb_pull": 80.0,
                "fingers": {"Index": (35, 50, 30), "Middle": (35, 50, 30), "Ring": (35, 50, 30), "Pinky": (35, 50, 30)},
                "curl_more": 0, "thumb": ((20.0, 0.0, 10.0), (10.0, 10.0))}
# The Cyber's grip is the GBB's (MQ1B): the same support hand on it at the GBB's turn (`yaws`, `rolls`), lifted with
# the right hand (CYBER_LIFT). Its sides are flat to square back corners where the GBB's round off, so the hand sits
# CYBER_OUT further out and back (m: x, y); on the GBB's marks the thumb's root lay in the corner and the thumb,
# finding no clear place along the frame, stood out sideways, with the right thumb laid flat across after it.
CYBER_OUT = (-0.003, -0.003)
CYBER_SUPPORT = dict(SUPPORT_LEFT, yaws=(15.0, 15.0), rolls=(4.0, 4.0),
                     thumb_at=(SUPPORT_LEFT["thumb_at"][0], SUPPORT_LEFT["thumb_at"][1],
                               SUPPORT_LEFT["thumb_at"][2] + CYBER_LIFT),
                     **{k: (SUPPORT_LEFT[k][0] + CYBER_OUT[0], SUPPORT_LEFT[k][1] + CYBER_OUT[1],
                            SUPPORT_LEFT[k][2] + CYBER_LIFT) for k in ("web", "index", "pinky")})
SUPPORT = {"pistol": SUPPORT_LEFT, "cyber": CYBER_SUPPORT}
# The two-handed hold's name in its clips (`<id>_two_Hold`, `<id>_two_Reload`; ArmsView.TWO_HANDS).
TWO = "two"
# The right arm as the hold poses it, a still copy the left hand rests on.
RIGHT_HELD = "RightHeld"
# The left arm as the hold in both hands poses it, a still copy the right thumb is laid on; and that thumb's two outer
# sections, which the left hand is placed without (`solve_support`).
LEFT_HELD = "LeftHeld"
RIGHT_THUMB = ("Thumb2_R", "Thumb3_R")
# Where a rifle sits as its hold is solved: the hip place the owner approved the holds at (BL4, BP8), its arms'
# shoulders with it (BL_HIP=x,y,z solves at another place, as the game writes it). In the game the replica sits nearer
# and lower (HA1, the owner: at the hip only the left hand shows; ViewModelConfig.hip, GAME_HIP here) and the arms ride
# it as solved, so the hands on it and the bots' copies of them are the approved ones, hold for hold.
RIFLE_HIP = godot_to_eye(*(float(v) for v in os.environ.get("BL_HIP", "0.12,-0.19,-0.26").split(",")))
# Where the game draws each replica at the hip (ViewModelConfig.hip), where it is not where its hold is solved: the
# build's pictures are taken from there (BL_PREVIEW).
GAME_HIP = {rid: godot_to_eye(*at) for rid, at in (
    (rid, magazine.listed(magazine.exported(magazine.VIEWMODEL)["hip"], rid)) for rid in ("aeg", "sniper", "smg")) if at}
# And a pistol (BL_PISTOL_HIP likewise).
PISTOL_HIP = godot_to_eye(*(float(v) for v in os.environ.get("BL_PISTOL_HIP", "0.05,-0.07,-0.34").split(",")))
HOLDS = {
    "aeg": Hold("aeg.glb", RIFLE_HIP, Grip((0.0, -0.073, -0.026), 31.0, 0.046, 0.0155),
                AEG_RIGHT, GUARD),
    "pistol": Hold("pistol.glb", PISTOL_HIP, Grip((0.0, -0.070, -0.016), 27.0, 0.046, 0.0130),
                   PISTOL_RIGHT, DOWN),
    "cyber": Hold("cyber.glb", PISTOL_HIP, Grip((0.0, -0.074, -0.024), 17.0, 0.048, 0.0128),
                  CYBER_RIGHT, DOWN),
    "sniper": Hold("sniper.glb", RIFLE_HIP, Grip((0.0, -0.090, 0.008), 54.0, 0.050, 0.021),
                   SNIPER_RIGHT, SNIPER_GUARD),
    "smg": Hold("smg.glb", RIFLE_HIP, Grip((0.0, -0.0847, -0.026), 30.0, 0.050, 0.0145),
                SMG_RIGHT, SMG_GUARD),
    "shotgun": Hold("shotgun.glb", godot_to_eye(0.12, -0.21, -0.21), Grip((0.0, -0.073, -0.026), 31.0, 0.046, 0.0155),
                    SHOTGUN_RIGHT, SHOTGUN_PUMP),
    "smoke": Hold("../grenades/smoke.glb", HELD_AT, Grip((0.0, -0.0275, 0.03), 0.0, 0.055, 0.0275), SMOKE_RIGHT,
                  DOWN, HELD_TIP),
    "flash": Hold("../grenades/flash.glb", HELD_AT, Grip((0.0, -0.020, 0.03), 0.0, 0.040, 0.020), FLASH_RIGHT,
                  DOWN, HELD_TIP),
}


# How far ahead of the eye each replica sits aimed (ViewModelConfig.aim_forward), for the build's pictures (BL_PREVIEW).
AIM_FORWARD = {"aeg": 0.2, "pistol": 0.25, "cyber": 0.25, "sniper": 0.2, "smg": 0.15}


def pictures(name: str, hold: Hold, rid: str, rig: Rig, objects: list) -> None:
    """With BL_PREVIEW naming a folder, pictures of the hold posed now there, as `name` (preview.py)."""
    if os.environ.get("BL_PREVIEW"):
        preview.hold(os.environ["BL_PREVIEW"], name, hold.to_eye(), rig, objects, AIM_FORWARD.get(rid, 0.25),
                     eye=hold.at - GAME_HIP.get(rid, hold.at))


def aim(base: Vector, yaw: float, pitch: float) -> Vector:
    """`base` pitched up `pitch` degrees round X, then yawed `yaw` degrees toward -X round Z."""
    return Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "X") @ base


def roll_about(v: Vector, axis: Vector, deg: float) -> Vector:
    return Matrix.Rotation(math.radians(deg), 3, axis.normalized()) @ v


def tuned(spec: dict) -> dict:
    """`spec` with any value overridden from the environment (BL_<KEY>=value; BL_THUMB=across,twist,bend,tip1,tip2;
    BL_SEARCH=yaw0,yaw1,pitch0,pitch1,roll0,roll1; BL_G_<KEY> for a rifle's support hand's spec alone, BL_S_<KEY>
    for a pistol's, BL_F_<KEY> for a foregrip's),
    for tuning a hold by eye."""
    out = dict(spec)
    for k, v in spec.items():
        env = os.environ.get("BL_" + k.upper())
        if spec.get("kind") == "guard":
            env = os.environ.get("BL_G_" + k.upper(), env)
        elif spec.get("kind") == "support":
            # A pistol's support hand shares its keys' names with the right hand's: BL_S_<KEY> alone tunes it.
            env = os.environ.get("BL_S_" + k.upper())
        elif spec.get("kind") == "grip":
            # A foregrip's too: BL_F_<KEY>.
            env = os.environ.get("BL_F_" + k.upper())
        if env is not None and isinstance(v, float):
            out[k] = float(env)
        elif env is not None and isinstance(v, tuple) and all(isinstance(c, float) for c in v):
            out[k] = tuple(float(x) for x in env.split(","))
        elif env is not None and k == "search":
            f = [int(x) for x in env.split(",")]
            out[k] = ((f[0], f[1]), (f[2], f[3]), (f[4], f[5]))
        elif env is not None and k == "thumb":
            f = [float(x) for x in env.split(",")]
            out[k] = (tuple(f[:3]), tuple(f[3:5]))
    return out
