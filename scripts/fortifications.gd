extends RefCounted

const NEIGHBORS = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

static func center(b: Dictionary) -> Vector2:
    return Vector2(3.0 * b.q, sqrt(3.0) * 2.0 * (b.r + b.q * 0.5))

static func segments(b: Dictionary, buildings: Array) -> Array:
    var origin := center(b)
    var axis := Vector2.RIGHT.rotated(int(b.get("rotation_step", 0)) * PI / 6.0)
    var result: Array = [[origin - axis * 1.5, origin + axis * 1.5]]
    for other in buildings:
        if other.kind not in ["Wall", "Palisade"] or other.progress < 1: continue
        var offset := Vector2i(int(other.q) - int(b.q), int(other.r) - int(b.r))
        if offset in NEIGHBORS:
            # Each tile owns half the link so breaches remove its own material.
            result.append([origin, (origin + center(other)) * 0.5])
    return result
