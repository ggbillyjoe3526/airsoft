"""What the game's eye sees of a rifle's support hand (HA1): the owner, 2026-11-12, of the view at the hip: "You can
still see the players fingers on the right side of the AEG. They should not be visible: only the thumb of the left
hand". `pose.Hand.onto` counts both measures here against a finger's pose; hold_solve.left_on_guard sets what they
read (`Hand.eyes`, `screen`, `far`, `front`)."""

# A point of a finger counts as hidden when the replica stands in the way at least this far (m) short of it.
SEEN_SKIN = 0.002
# Only the glove this far (m) or more to the replica's far side of its middle is judged (`Hand.far`).
SEEN_FAR = 0.005
# Each hundredth of a finger's glove that shows costs as much as its pad lying SEEN_COST / 10 m off its mark (it
# counts with the height limit, tenfold).
SEEN_COST = 0.5


def ahead(hand, name: str) -> float:
    """How far the finger's glove reaches past `hand.front` (m; 0 when behind it or no limit)."""
    if hand.front is None or name == "Thumb":
        return 0.0
    way, most = hand.front
    far = max((hand.rig.pose[b] @ q).dot(way) for b in ("%s%d_%s" % (name, k, hand.side) for k in (2, 3))
              for q in hand.points[b])
    return max(0.0, far - most)


def seen(hand, name: str) -> float:
    """The share of the finger's glove an eye in `hand.eyes` sees past `hand.screen` (the replica); 0 with no eyes
    set."""
    if not hand.eyes or name == "Thumb":
        return 0.0
    total = shown = 0
    for b in ("%s%d_%s" % (name, k, hand.side) for k in (1, 2, 3)):
        m = hand.rig.pose[b]
        for q in hand.points[b]:
            p = m @ q
            total += 1
            # The far side's alone: the index finger's root by the thumb is on the near side, with the hand the eye
            # may see.
            if hand.far is not None and (p - hand.far[1]).dot(hand.far[0]) < SEEN_FAR:
                continue
            for eye in hand.eyes:
                way = p - eye
                reach = way.length - SEEN_SKIN
                if all(part.tree.ray_cast(eye, way, reach)[0] is None for part in hand.screen.parts):
                    shown += 1
                    break
    return shown / max(1, total)
