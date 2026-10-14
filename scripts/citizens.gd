extends Node3D

const NEWBORN_SCALE := 0.45
const FULL_SIZE_AGE := 16.0

# One visible figure per settler. Animation illustrates aggregate simulation;
# these travel cycles do not create extra resource deliveries.
var world: Node3D
var people: Array = []
var clock := 0.0
var skin: Array[Material] = []
var clothes: Array[Material] = []
var leather: Material
var refresh_timer := 1.0
var obstacles: Array[Dictionary] = []

func refresh_obstacles() -> void:
    obstacles.clear()
    # Trees are direct children of the settlement scene and expose their
    # generated scale, which provides a conservative trunk/canopy clearance.
    for node in world.get_children():
        if node is Node3D and node.has_meta("explorable") and node.is_visible_in_tree():
            var tree := node as Node3D
            obstacles.append({"point": Vector2(tree.position.x, tree.position.z), "radius": maxf(tree.scale.x * 1.35, 0.9)})
    for id in world.sim.STARTING_OBJECTS:
        if world.sim.camp_object_present(id):
            var item: Dictionary = world.sim.STARTING_OBJECTS[id]
            obstacles.append({"point": Vector2(item.point[0], item.point[1]), "radius": float(item.radius)})
    # Building footprints use the same hex centers as the rendered structures.
    for b in world.sim.buildings:
        var center := Vector2(3.0 * b.q, sqrt(3.0) * 2 * (b.r + b.q * 0.5))
        obstacles.append({"point": center, "radius": 2.05})

func routed_point(start: Vector2, finish: Vector2, progress: float, side: float) -> Vector2:
    # Work points can fall on the center of a field or training ground. Stop at
    # the edge of that footprint instead of walking through the structure.
    for obstacle in obstacles:
        var center: Vector2 = obstacle.point
        var clearance: float = obstacle.radius + 0.48
        var start_offset := start - center
        if start_offset.length() < clearance:
            start = center + (finish - center).normalized() * clearance
        var finish_offset := finish - center
        if finish_offset.length() < clearance:
            finish = center + (start - center).normalized() * clearance
    var direction := finish - start
    var length := direction.length()
    if length < 0.01: return finish
    var axis := direction / length
    var normal := Vector2(-axis.y, axis.x) * side
    var detours: Array[Dictionary] = []
    for obstacle in obstacles:
        var center: Vector2 = obstacle.point
        var along := (center - start).dot(axis)
        if along <= 0.25 or along >= length - 0.25: continue
        var lateral := (center - (start + axis * along)).dot(normal)
        var clearance: float = obstacle.radius + 0.48
        if absf(lateral) < clearance:
            detours.append({"along": along, "point": start + axis * along + normal * (clearance + absf(lateral))})
    detours.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.along < b.along)
    var route: Array[Vector2] = [start]
    for detour in detours:
        var point: Vector2 = detour.point
        if route[-1].distance_to(point) > 0.25: route.append(point)
    route.append(finish)
    var total := 0.0
    var lengths: Array[float] = []
    for i in range(route.size() - 1):
        var segment := route[i].distance_to(route[i + 1])
        lengths.append(segment)
        total += segment
    var remaining := clampf(progress, 0.0, 1.0) * total
    for i in range(lengths.size()):
        if remaining <= lengths[i]: return route[i].lerp(route[i + 1], remaining / maxf(lengths[i], 0.001))
        remaining -= lengths[i]
    return finish

func setup(scene: Node3D) -> void:
    world = scene
    for color in [Color("ba8c68"), Color("95684f"), Color("d2ac84")]:
        skin.append(world.textured_material(color, 3.0))
    for color in [Color("8c7857"), Color("748779"), Color("a08b67"), Color("807a91"), Color("8a6551")]:
        clothes.append(world.textured_material(color, 3.0))
    leather = world.textured_material(Color("504334"), 2.0)
    sync_people()
    update_people(0)

func limb(parent: Node3D, location: Vector3, length: float, material: Material) -> Node3D:
    var pivot := Node3D.new()
    parent.add_child(pivot)
    pivot.position = location
    world.cylinder(pivot, Vector3(0, -length * 0.25, 0), 0.055, 0.07, length * 0.5, material, 8)
    var joint := Node3D.new()
    joint.position.y = -length * 0.5
    pivot.add_child(joint)
    world.cylinder(joint, Vector3(0, -length * 0.25, 0), 0.045, 0.055, length * 0.5, material, 8)
    pivot.set_meta("joint", joint)
    return pivot

func make_person(index: int) -> Dictionary:
    var root := Node3D.new()
    add_child(root)
    var body := Node3D.new()
    root.add_child(body)
    var cloth: Material = clothes[index % clothes.size()]
    var face: Material = skin[index % skin.size()]
    world.cylinder(body, Vector3(0, 0.79, 0), 0.20, 0.15, 0.51, cloth, 10)
    world.cylinder(body, Vector3(0, 0.94, 0), 0.16, 0.16, 0.035, leather, 10)
    world.sphere(body, Vector3(0, 1.25, 0), Vector3(0.13, 0.17, 0.13), face)
    world.sphere(body, Vector3(0, 1.36, -0.025), Vector3(0.14, 0.09, 0.14), world.mats.dark)
    world.sphere(body, Vector3(0, 1.24, 0.126), Vector3(0.035, 0.045, 0.035), face)
    var left_arm := limb(body, Vector3(-0.20, 1.02, 0), 0.46, face)
    var right_arm := limb(body, Vector3(0.20, 1.02, 0), 0.46, face)
    var left_leg := limb(body, Vector3(-0.085, 0.57, 0), 0.50, cloth)
    var right_leg := limb(body, Vector3(0.085, 0.57, 0), 0.50, cloth)
    world.box(left_leg.get_meta("joint"), Vector3(0, -0.24, 0.04), Vector3(0.13, 0.10, 0.23), leather)
    world.box(right_leg.get_meta("joint"), Vector3(0, -0.24, 0.04), Vector3(0.13, 0.10, 0.23), leather)
    var tool := Node3D.new()
    right_arm.get_meta("joint").add_child(tool)
    tool.position = Vector3(0, -0.20, 0)
    var shield := Node3D.new()
    left_arm.get_meta("joint").add_child(shield)
    shield.position = Vector3(0, -0.18, 0.09)
    var cargo := Node3D.new()
    body.add_child(cargo)
    world.cylinder(cargo, Vector3(0, 0.77, -0.25), 0.16, 0.22, 0.35, world.mats.wood, 10)
    cargo.visible = false
    return {"node": root, "body": body, "la": left_arm, "ra": right_arm, "ll": left_leg, "rl": right_leg, "tool": tool, "shield": shield, "cargo": cargo, "job": "", "index": index}

func sync_people() -> void:
    while people.size() > world.sim.population:
        var person: Dictionary = people.pop_back()
        person.node.queue_free()
    while people.size() < world.sim.population: people.append(make_person(people.size()))
    world.sim.prepare_roster(world.sim.effective_assignments())
    var roles: Dictionary = {}
    for job in world.sim.JOBS:
        for person in world.sim.job_roster[job]: roles[int(person.id)] = job
    for army in world.sim.armies:
        for id in army.soldiers: roles[int(id)] = army.unit
    for id in world.sim.emergency_defenders: roles[int(id)] = "Militia"
    for i in range(people.size()):
        var p: Dictionary = people[i]
        var person: Dictionary = world.sim.people[i]
        var scout_mission: Dictionary = world.sim.scout_mission_for_unit(int(person.id))
        var role: String = "Scouting" if not scout_mission.is_empty() else roles.get(int(person.id), "Resting")
        if p.node.is_in_group("inspectable"): p.node.remove_from_group("inspectable")
        if p.node.has_meta("inspection"): p.node.remove_meta("inspection")
        if role == "Scouting":
            world.inspectable(p.node, {"kind": "Scouting party", "mission_started": scout_mission.started, "mission_units": scout_mission.units.duplicate()})
        for army in world.sim.armies:
            if int(person.id) in army.soldiers:
                world.inspectable(p.node, {"kind": "Army", "own": true, "army": int(army.id)})
                break
        if p.job != role:
            p.job = role
            equip(p)

func equip(p: Dictionary) -> void:
    p.tool.reparent(p.la.get_meta("joint") if p.job == "Archers" else p.ra.get_meta("joint"), false)
    p.tool.position = Vector3(0, -0.20, 0)
    p.tool.rotation = Vector3.ZERO
    p.body.rotation = Vector3.ZERO
    for joint in [p.la, p.ra, p.ll, p.rl]:
        joint.rotation = Vector3.ZERO
        joint.get_meta("joint").rotation = Vector3.ZERO
    for child in p.shield.get_children():
        p.shield.remove_child(child)
        child.queue_free()
    for child in p.tool.get_children():
        p.tool.remove_child(child)
        child.queue_free()
    match p.job:
        "Militia", "Spearmen":
            world.beam(p.tool, Vector3(0, -0.3, 0), Vector3(0, 1.0, 0), 0.024, world.mats.wood)
            world.box(p.tool, Vector3(0, 1.0, 0), Vector3(0.08, 0.2, 0.08), world.mats.stone)
            if p.job == "Spearmen":
                world.box(p.shield, Vector3.ZERO, Vector3(0.40, 0.55, 0.075), world.mats.wood)
                world.box(p.shield, Vector3(0, 0, 0.045), Vector3(0.055, 0.52, 0.025), leather)
        "Archers":
            world.beam(p.tool, Vector3(0, -0.2, 0), Vector3(0.18, 0.2, 0), 0.023, world.mats.wood)
            world.beam(p.tool, Vector3(0.18, 0.2, 0), Vector3(0, 0.6, 0), 0.023, world.mats.wood)
            world.beam(p.tool, Vector3(0, -0.2, 0), Vector3(0, 0.6, 0), 0.005, world.mats.cloth)
        "Logging", "Quarrying", "Construction", "Farming":
            world.beam(p.tool, Vector3(0, -0.17, 0), Vector3(0, 0.47, 0), 0.025, world.mats.wood)
            var size := Vector3(0.28, 0.09, 0.12) if p.job == "Quarrying" else Vector3(0.18, 0.14, 0.06)
            world.box(p.tool, Vector3(0.06, 0.43, 0), size, world.mats.stone)
        "Fishing":
            world.beam(p.tool, Vector3.ZERO, Vector3(0, 0.1, 1.7), 0.018, world.mats.wood)
            world.beam(p.tool, Vector3(0, 0.1, 1.7), Vector3(0, -0.5, 1.7), 0.003, world.mats.cloth)

func target_for(p: Dictionary) -> Vector2:
    var index: int = p.index
    var spread := Vector2((index % 3 - 1) * 0.55, (index % 4 - 1.5) * 0.6)
    match p.job:
        "Militia", "Spearmen", "Archers":
            for b in world.sim.buildings:
                if b.progress >= 1 and b.kind == "Training Grounds":
                    return Vector2(3.0 * b.q, sqrt(3.0) * 2 * (b.r + b.q * 0.5)) + spread + Vector2(1.5, 1.5)
            return Vector2(-5, -3) + spread
        "Scouting":
            var mission: Dictionary = world.sim.scout_mission_for_unit(int(world.sim.people[index].id))
            return world.sim.mission_position(mission) + Vector2((index % 3 - 1) * 0.45, 0.3)
        "Fishing":
            var z := -5.0 + (index % 6) * 1.7
            return Vector2(10 + sin(z * 0.095) * 3 - 3.7, z)
        "Logging": return world.resource_deposits.work_point("wood") + spread
        "Quarrying": return world.resource_deposits.work_point("stone") + spread
        "Gathering": return Vector2(-13.0, 9.0) + spread
        "Construction", "Farming":
            if p.job == "Construction":
                var jobs: Array = []
                for id in world.sim.camp_dismantling:
                    if world.sim.camp_object_present(id): jobs.append(id)
                if not jobs.is_empty():
                    var item: Dictionary = world.sim.STARTING_OBJECTS[jobs[int(index / 3) % jobs.size()]]
                    return Vector2(item.point[0], item.point[1]) + spread
            var sites: Array = []
            for b in world.sim.buildings:
                if (p.job == "Construction" and b.progress < 1) or (p.job == "Farming" and b.kind == "Field" and b.progress >= 1):
                    sites.append(b)
                    if p.job == "Construction": break
            if not sites.is_empty():
                var b: Dictionary = sites[index % sites.size()]
                return Vector2(3.0 * b.q, sqrt(3.0) * 2 * (b.r + b.q * 0.5)) + spread
    return Vector2(-4, 3) + spread * 2

func has_task(p: Dictionary) -> bool:
    if p.job == "Resting": return false
    if p.job == "Logging" and world.sim.forest <= 0 and "Forestry" not in world.sim.technologies: return false
    if p.job == "Quarrying" and world.sim.quarry <= 0: return false
    if p.job == "Gathering" and world.sim.wildlife <= 0: return false
    if p.job == "Farming" and int(world.sim.day / 90) % 4 == 3: return false
    if p.job == "Construction":
        for id in world.sim.camp_dismantling:
            if world.sim.camp_object_present(id): return true
    if p.job in ["Construction", "Farming"]:
        for b in world.sim.buildings:
            if p.job == "Construction" and b.progress < 1: return true
            if p.job == "Farming" and b.kind == "Field" and b.progress >= 1: return true
        return false
    return true

func _process(delta: float) -> void:
    if not is_instance_valid(world): return
    refresh_timer += delta
    if refresh_timer >= 0.4:
        refresh_timer = 0
        sync_people()
        refresh_obstacles()
    if world.running or (is_instance_valid(world.session) and world.session.active): clock += delta
    update_people(delta)

func update_people(_delta: float) -> void:
    for p in people:
        if p.index >= world.sim.people.size():
            p.node.hide()
            continue
        # Follow the citizen's actual age, including loaded and shared-world ages.
        # Reach adult size continuously, without a size jump at adulthood.
        var growth := clampf(float(world.sim.people[p.index].age) / FULL_SIZE_AGE, 0.0, 1.0)
        p.node.scale = Vector3.ONE * lerpf(NEWBORN_SCALE, 1.0, growth)
        var deployed := false
        var person_id: int = world.sim.people[p.index].id
        for army in world.sim.armies:
            if person_id in army.soldiers and army.status in ["Marching", "Fighting", "Returning", "Holding"]: deployed = true
        p.node.visible = not deployed
        if deployed: continue
        var phase := fmod(clock / 24.0 + p.index * 0.137, 1.0)
        var home := Vector2(-8.0 + (p.index % 6) * 0.7, 1.4 + int(p.index / 6) * 0.75)
        var target := target_for(p)
        # Visual rest illustrates the rest already included in daily work rates.
        # Scouts and soldiers retain their duties through the night.
        var on_guard := false
        if world.sim.is_night():
            for army in world.sim.armies:
                if person_id in army.soldiers and army.status in ["Ready", "Defending"]: on_guard = true
        var resting_at_night: bool = world.sim.is_night() and p.job != "Scouting" and not on_guard
        var active := has_task(p) and not resting_at_night
        var walking := active and (phase < 0.3 or (phase >= 0.72 and phase < 0.94))
        var working := active and phase >= 0.3 and phase < 0.72
        var point := home
        var facing := Vector2(0, 1)
        if resting_at_night:
            # Most settlers are inside shelters; a few sit beside the hearth.
            p.node.visible = p.index % 6 == int(world.sim.day) % 6
            var angle: float = p.index * 2.4
            point = Vector2(-3, 1.5) + Vector2(cos(angle), sin(angle)) * 1.6
            facing = Vector2(-3, 1.5) - point
        elif on_guard:
            var angle: float = clock * 0.06 + p.index * 0.8
            point = Vector2(-4, 1.5) + Vector2(cos(angle), sin(angle)) * 6
            facing = Vector2(-sin(angle), cos(angle))
            walking = true
            working = false
        elif p.job == "Scouting":
            point = target
            var mission: Dictionary = world.sim.scout_mission_for_unit(int(world.sim.people[p.index].id))
            var direction: Vector2 = world.sim.mission_direction(mission)
            walking = not direction.is_zero_approx() and (world.running or (is_instance_valid(world.session) and world.session.active))
            working = false
            # Preserve the arrival heading while surveying or waiting to return.
            facing = direction if not direction.is_zero_approx() else Vector2(sin(p.node.rotation.y), cos(p.node.rotation.y))
        elif active:
            if phase < 0.3:
                var route_progress := phase / 0.3
                point = routed_point(home, target, route_progress, -1.0 if p.index % 2 == 0 else 1.0)
                var ahead := routed_point(home, target, minf(route_progress + 0.02, 1.0), -1.0 if p.index % 2 == 0 else 1.0)
                facing = ahead - point
            elif phase < 0.72:
                point = target
                facing = Vector2(1, 0) if p.job == "Fishing" else Vector2(0, -1)
            elif phase < 0.94:
                var route_progress := (phase - 0.72) / 0.22
                point = routed_point(target, home, route_progress, -1.0 if p.index % 2 == 0 else 1.0)
                var ahead := routed_point(target, home, minf(route_progress + 0.02, 1.0), -1.0 if p.index % 2 == 0 else 1.0)
                facing = ahead - point
        p.node.position = world.pos(point.x, point.y, 0.04)
        p.node.rotation.y = atan2(facing.x, facing.y)
        if p.job not in ["Militia", "Spearmen", "Archers"] or resting_at_night:
            var swing := sin(clock * 7.0 + p.index) * 0.48 if walking else 0.0
            p.ll.rotation.x = swing
            p.rl.rotation.x = -swing
            p.la.rotation.x = -swing
            p.ra.rotation.x = swing
            p.body.position.y = absf(sin(clock * 7 + p.index)) * 0.035 if walking else 0.0
            p.body.rotation.x = 0
        if resting_at_night:
            p.body.position.y = -0.25
            p.ll.rotation.x = -0.8
            p.rl.rotation.x = -0.8
            p.la.rotation.x = -0.4
            p.ra.rotation.x = -0.4
        p.tool.visible = not resting_at_night and (working or p.job in ["Militia", "Spearmen", "Archers"])
        p.cargo.visible = active and phase >= 0.72 and phase < 0.94 and p.job in ["Logging", "Gathering", "Quarrying", "Farming"]
        if p.job in ["Militia", "Spearmen", "Archers"] and not resting_at_night:
            animate_soldier(p, "Marching" if walking else "Training" if working else "Idle", clock, _delta)
        elif working:
            if p.job == "Fishing":
                p.ra.rotation.x = -0.9 + sin(clock * 1.5 + p.index) * 0.07
                p.la.rotation.x = -0.5
            elif p.job == "Gathering":
                p.body.rotation.x = 0.42
                p.ra.rotation.x = -0.65 + sin(clock * 3 + p.index) * 0.2
            else:
                p.ra.rotation.x = -1.0 + sin(clock * 4 + p.index) * 0.8
                p.la.rotation.x = -0.45
                p.body.rotation.x = 0.1 + sin(clock * 4 + p.index) * 0.08


func animate_soldier(p: Dictionary, mode: String, time: float, delta: float) -> void:
    # Shared by soldiers at home and regional expedition figures.
    var marching := mode == "Marching"
    var fighting := mode in ["Fighting", "Training"]
    var phase: float = time * (5.6 if marching else 2.4) + p.index * 1.73
    var stride := sin(phase) * 0.36 if marching else 0.0
    var pulse := pow(maxf(0, sin(phase)), 3.0) if fighting else 0.0
    var left := Vector3(-stride * 0.45, 0, -0.08)
    var right := Vector3(stride * 0.45 - 0.12, 0, 0.08)
    var left_elbow := 0.15
    var right_elbow := 0.2
    var tool_angle := 0.0
    var lean := 0.035 if marching else 0.0
    if p.job == "Spearmen":
        left.x = -0.45
        left_elbow = -0.35
    if p.job == "Archers":
        left = Vector3(-0.55, -0.22, -0.16)
        left_elbow = -0.25
        right = Vector3(-0.35, 0.15, 0.1)
        right_elbow = -0.65
        if fighting:
            left.x = -1.15
            right = Vector3(-0.9, 0.3 + pulse * 0.35, 0.22)
            right_elbow = -0.65 - pulse * 0.6
            lean = 0.04
    elif fighting:
        right.x = -0.55 - pulse * 0.32
        right_elbow = -0.25 + pulse * 0.3
        tool_angle = 2.0 if p.job == "Spearmen" else 1.4 + pulse * 0.35
        lean = pulse * 0.08
    var blend := 1.0 - exp(-delta * 12.0)
    p.la.rotation = p.la.rotation.lerp(left, blend)
    p.ra.rotation = p.ra.rotation.lerp(right, blend)
    p.ll.rotation = p.ll.rotation.lerp(Vector3(stride - (0.10 if fighting else 0.0), 0, 0), blend)
    p.rl.rotation = p.rl.rotation.lerp(Vector3(-stride, 0, 0), blend)
    p.ll.get_meta("joint").rotation.x = lerpf(p.ll.get_meta("joint").rotation.x, maxf(0, sin(phase)) * 0.55 if marching else 0.08, blend)
    p.rl.get_meta("joint").rotation.x = lerpf(p.rl.get_meta("joint").rotation.x, maxf(0, -sin(phase)) * 0.55 if marching else 0.08, blend)
    p.la.get_meta("joint").rotation.x = lerpf(p.la.get_meta("joint").rotation.x, left_elbow, blend)
    p.ra.get_meta("joint").rotation.x = lerpf(p.ra.get_meta("joint").rotation.x, right_elbow, blend)
    p.tool.rotation.x = lerpf(p.tool.rotation.x, tool_angle, blend)
    p.body.rotation = p.body.rotation.lerp(Vector3(lean, sin(phase) * 0.015 if marching else 0, 0), blend)
    p.body.position.y = lerpf(p.body.position.y, absf(sin(phase)) * 0.02 if marching else sin(time * 1.6 + p.index) * 0.008, blend)
    p.tool.show()
    p.cargo.hide()
