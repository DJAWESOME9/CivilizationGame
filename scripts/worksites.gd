extends RefCounted

const HOME := Vector2(-4, 0)
const JOBS := ["Gathering", "Logging", "Quarrying"]
const WALK_SPEED := 8.0

static func point(building: Dictionary) -> Vector2:
    return Vector2(3.0 * building.q, sqrt(3.0) * 2.0 * (building.r + building.q * 0.5))

static func allocations(sim) -> Dictionary:
    var result: Dictionary = {}
    for job in JOBS:
        var roster: Array = sim.job_roster.get(job, [])
        var offset := 0
        for b in sim.buildings:
            if b.kind != "Outpost" or b.progress < 1: continue
            var quota := maxi(0, int(b.get("workers", {}).get(job, 0)))
            for person in roster.slice(offset, mini(offset + quota, roster.size())):
                result[int(person.id)] = b
            offset = mini(offset + quota, roster.size())
    return result

static func order(sim, args: Array) -> String:
    if args.size() != 4 or not args[0] is int or not args[1] is int or args[2] not in JOBS or not args[3] is int or args[3] < 0: return "Invalid outpost assignment."
    var selected: Dictionary = {}
    var reserved := 0
    for b in sim.buildings:
        if b.kind != "Outpost" or b.progress < 1: continue
        if b.q == args[0] and b.r == args[1]: selected = b
        else: reserved += int(b.get("workers", {}).get(args[2], 0))
    if selected.is_empty(): return "Complete this outpost first."
    if reserved + args[3] > int(sim.effective_assignments()[args[2]]): return "Increase the total %s workforce first, or release workers from another outpost." % args[2]
    if not selected.has("workers"): selected.workers = {}
    selected.workers[args[2]] = args[3]
    return "Outpost assignment updated within your total workforce."

static func target(sim, resource: String, origin: Vector2) -> Dictionary:
    var cache_key := str([resource, origin, sim.forest, sim.quarry, sim.exploration_revision])
    if sim.resource_target_cache.has(cache_key): return sim.resource_target_cache[cache_key]
    if sim.resource_target_cache.size() > 128: sim.resource_target_cache.clear()
    var best: Dictionary = {}
    var distance := INF
    for node in sim.resource_nodes(resource):
        if sim.resource_node_remaining(resource, node) <= 0.000001 or not sim.explored.has(sim.cell_key(node.point)): continue
        if sim.route_crosses_river(origin, node.point): continue
        var length: float = origin.distance_squared_to(node.point)
        if length < distance:
            best = node
            distance = length
    sim.resource_target_cache[cache_key] = best
    return best

static func efficiency(distance: float) -> float:
    # A work shift plus the round trip between the workplace and deposit.
    return 1.0 / (1.0 + 2.0 * distance / WALK_SPEED)

static func harvest(sim, job: String, resource: String, rate: float, dt: float) -> float:
    var assigned := allocations(sim)
    var groups: Dictionary = {}
    for person in sim.job_roster.get(job, []):
        var b: Dictionary = assigned.get(int(person.id), {})
        var origin := HOME if b.is_empty() else point(b)
        var key := str(origin)
        if not groups.has(key): groups[key] = {"origin": origin, "labor": 0.0}
        groups[key].labor += sim.person_labor(person, job)
    var total := 0.0
    for group in groups.values():
        var remaining_time: float = dt
        while remaining_time > 0.000001:
            var node := target(sim, resource, group.origin)
            if node.is_empty(): break
            var output_rate: float = group.labor * rate * efficiency(group.origin.distance_to(node.point))
            if output_rate <= 0: break
            var amount := minf(sim.resource_node_remaining(resource, node), remaining_time * output_rate)
            var key: String = node.key
            sim.resource_extracted[key] = float(sim.resource_extracted.get(key, 0.0)) + amount
            sim.resource_extracted[resource + ":total"] = float(sim.resource_extracted.get(resource + ":total", 0.0)) + amount
            if resource == "wood": sim.forest -= amount
            else: sim.quarry -= amount
            total += amount
            remaining_time -= amount / output_rate
    return total

static func gathering_labor(sim) -> float:
    var assigned := allocations(sim)
    var amount := 0.0
    for person in sim.job_roster.get("Gathering", []):
        var b: Dictionary = assigned.get(int(person.id), {})
        var distance := HOME.distance_to(Vector2(-13, 9)) if b.is_empty() else 5.0
        amount += sim.person_labor(person, "Gathering") * efficiency(distance)
    return amount

static func restore(sim, resource: String, amount: float) -> void:
    var left := amount
    var keys: Array = sim.resource_extracted.keys()
    keys.reverse()
    for key in keys:
        if not str(key).begins_with(resource + ":") or str(key).ends_with(":total"): continue
        var returned := minf(left, float(sim.resource_extracted[key]))
        sim.resource_extracted[key] -= returned
        sim.resource_extracted[resource + ":total"] = maxf(0, float(sim.resource_extracted.get(resource + ":total", 0.0)) - returned)
        left -= returned
        if left <= 0.000001: break
    sim.resource_target_cache.clear()
