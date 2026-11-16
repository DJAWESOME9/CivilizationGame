extends RefCounted

# Partition existing reserves without adding resources or changing old saves.
# The deterministic scenery and ordering reconstruct depletion after reloads.
var groups: Dictionary = {"wood": [], "stone": []}
var work_points: Dictionary = {}
const RESERVES = {"wood": 1200.0, "stone": 1500.0}

func rebuild(world: Node3D) -> void:
    groups = {"wood": [], "stone": []}
    for node in world.scenery_nodes:
        if not node.has_meta("inspection"): continue
        var kind: String = node.get_meta("inspection").get("kind", "")
        var resource := "wood" if kind == "Oak tree" else "stone" if kind in ["Stone deposit", "River stone"] else ""
        if resource.is_empty(): continue
        groups[resource].append(node)
    for resource in groups:
        var nodes: Array = groups[resource]
        nodes.sort_custom(func(a, b):
            var pa := Vector2(a.position.x, a.position.z)
            var pb := Vector2(b.position.x, b.position.z)
            var da := pa.distance_squared_to(Vector2(-4, 0))
            var db := pb.distance_squared_to(Vector2(-4, 0))
            if not is_equal_approx(da, db): return da < db
            if not is_equal_approx(pa.x, pb.x): return pa.x < pb.x
            return pa.y < pb.y)
        var total_weight := 0.0
        for node in nodes:
            total_weight += node.scale.x * node.scale.y * node.scale.z
        var offset := 0.0
        var node_index := 0
        for node in nodes:
            var weight: float = node.scale.x * node.scale.y * node.scale.z
            var capacity: float = float(RESERVES[resource]) * weight / maxf(total_weight, 0.001)
            var info: Dictionary = node.get_meta("inspection")
            info["resource_key"] = resource + ":" + str(node_index)
            node_index += 1
            info["resource"] = resource
            info["resource_capacity"] = capacity
            info["resource_offset"] = offset
            node.set_meta("inspection", info)
            node.set_meta("resource_scale", node.scale)
            var ground: float = world.surface_height(node.position.x, node.position.z)
            node.set_meta("resource_ground", ground)
            node.set_meta("resource_height", node.position.y - ground)
            offset += capacity
    refresh(world)

func remaining(sim, info: Dictionary) -> float:
    var resource: String = info.get("resource", "")
    if resource.is_empty(): return 0.0
    return sim.resource_node_remaining(resource, {"capacity": info.resource_capacity, "offset": info.resource_offset, "key": info.get("resource_key", "")})

func refresh(world: Node3D) -> void:
    work_points.clear()
    for resource in groups:
        for node in groups[resource]:
            var info: Dictionary = node.get_meta("inspection")
            var amount := remaining(world.sim, info)
            var exhausted := amount <= 0.000001
            if not exhausted and not work_points.has(resource):
                work_points[resource] = Vector2(node.position.x, node.position.z)
            node.set_meta("resource_depleted", exhausted)
            # Keep transforms invertible even while the exhausted node is hidden.
            var fraction := amount / maxf(float(info.resource_capacity), 0.001)
            var size_factor := maxf(0.01, pow(fraction, 1.0 / 3.0))
            node.scale = node.get_meta("resource_scale") * size_factor
            node.position.y = float(node.get_meta("resource_ground")) + float(node.get_meta("resource_height")) * size_factor
            var point := Vector2(node.position.x, node.position.z)
            node.visible = not exhausted and world.sim.explored.has(world.sim.cell_key(point))

func work_point(resource: String) -> Vector2:
    return work_points.get(resource, Vector2(-4, 0))
