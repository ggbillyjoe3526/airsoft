"""What the game's eye sees of a rifle's support hand (HA1): the owner, 2026-11-12, of the view at the hip: "You can
still see the players fingers on the right side of the AEG. They should not be visible: only the thumb of the left
hand". `pose.Hand.onto` counts both measures here against a finger's pose; hold_solve.left_on_guard sets what they
read (`Hand.eyes`, `screen`, `far`, `front`). `crowd` is the third: the far side as a bot beside the player shows it
(the critic's third look: neighbouring fingers pinched into one another)."""

# A point of a finger counts as hidden when the replica stands in the way at least this far (m) short of it.
SEEN_SKIN = 0.002
# Only the glove this far (m) or more to the replica's far side of its middle is judged (`Hand.far`).
SEEN_FAR = 0.005
# Each hundredth of a finger's glove that shows costs as much as its pad lying SEEN_COST / 10 m off its mark (it
# counts with the height limit, tenfold).
SEEN_COST = 0.5
# Where along each of a finger's last two bones `crowd` measures (shares of the bone's length).
CROWD_AT = (0.0, 0.5, 1.0)
# A fingertip lies no further than a finger's width and this (m) from its neighbour's.
TIP_SLACK = 0.004


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


def lines(hand, name: str) -> list:
    """The finger's last two bones as it is posed: each one's two ends."""
    out = []
    for b in ("%s%d_%s" % (name, k, hand.side) for k in (2, 3)):
        m = hand.rig.pose[b]
        out.append((m.translation.copy(), m.translation + m.to_3x3().col[1] * hand.rig.length[b]))
    return out


def crowd(hand, name: str) -> float:
    """How far (m) the finger strays from the row the fingers laid before it make (`hand.laid`, each bone's two ends,
    the last bone's last): its last two bones nearer than `hand.apart` to theirs (fingers lie side by side, never
    through one another), its tip further than `hand.apart` + TIP_SLACK from the tip of the finger laid just before
    it (no gap between neighbours), and its tip further back along the handguard than its own knuckle (no finger
    hooked back over its root; `hand.front`'s way). 0 with none laid and no row asked for."""
    if hand.apart <= 0.0:
        return 0.0
    mine = lines(hand, name)
    tip = mine[-1][1]
    out = 0.0
    if hand.front is not None:
        way = hand.front[0]
        out += max(0.0, (hand.rig.pose["%s1_%s" % (name, hand.side)].translation - tip).dot(way))
    if not hand.laid:
        return out
    least = hand.apart
    for a, b in mine:
        for t in CROWD_AT:
            p = a.lerp(b, t)
            for c, d in hand.laid:
                along = d - c
                q = c + along * min(1.0, max(0.0, (p - c).dot(along) / along.length_squared))
                least = min(least, (p - q).length)
    return out + hand.apart - least + max(0.0, (tip - hand.laid[-1][1]).length - hand.apart - TIP_SLACK)
